extends Node3D

var drone_controller: DroneController
var input_manager: InputManager
var camera_ctrl: CameraController3D
var hud_layer: CanvasLayer
var environment_builder: EnvironmentBuilder
var drone_overlays: DroneOverlays
var udp_telemetry: UDPTelemetry
var crash_effects: CrashEffects

var _hud_timer: float = 0.0
var _config: DroneConfig

# Engineering state
var _flight_timer: float = 0.0
var _max_altitude: float = 0.0
var _max_speed: float = 0.0
var _battery_mah_consumed: float = 0.0

const BATTERY_CAPACITY_MAH := 1500.0
const MOTOR_IDLE_AMPS := 0.5
const MOTOR_MAX_AMPS := 15.0

func _ready() -> void:
	# Set physics tick rate
	Engine.physics_ticks_per_second = 120

	_config = DroneConfig.create_quad()

	# Build environment
	environment_builder = EnvironmentBuilder.new()
	environment_builder.name = "Environment"
	add_child(environment_builder)
	environment_builder.build()

	# Set up world environment (sky, fog, lighting)
	_setup_world_environment()

	# Create drone
	drone_controller = DroneController.new()
	drone_controller.name = "DroneController"
	add_child(drone_controller)
	drone_controller.setup(_config)

	# Camera
	camera_ctrl = CameraController3D.new()
	camera_ctrl.name = "Camera"
	add_child(camera_ctrl)
	camera_ctrl.current = true

	# Input
	input_manager = InputManager.new()
	input_manager.name = "InputManager"
	add_child(input_manager)

	# HUD
	hud_layer = load("res://scripts/ui/hud.gd").new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	hud_layer.config_changed.connect(_on_config_changed)

	# Set initial motor count on HUD
	hud_layer.motor_panel.set_motor_count(_config.motor_count)

	# Dev overlays (shadow, thrust lines, velocity vector, etc.)
	drone_overlays = DroneOverlays.new()
	drone_overlays.name = "DroneOverlays"
	add_child(drone_overlays)
	drone_overlays.setup_thrust_lines(_config.motor_count)

	# Crash effects
	crash_effects = CrashEffects.new()
	crash_effects.name = "CrashEffects"
	add_child(crash_effects)

	# UDP telemetry for ESP32
	udp_telemetry = UDPTelemetry.new()
	udp_telemetry.name = "UDPTelemetry"
	add_child(udp_telemetry)

	# Crash system signals
	drone_controller.drone_crashed.connect(_on_drone_crashed)
	drone_controller.drone_reset.connect(_on_drone_reset)

func _setup_world_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()

	# Sky
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.55, 0.7, 0.9)
	sky_mat.ground_bottom_color = Color(0.25, 0.35, 0.2)
	sky_mat.ground_horizon_color = Color(0.55, 0.7, 0.9)
	sky.sky_material = sky_mat
	env.sky = sky

	# Fog
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	env.fog_density = 0.002
	env.fog_aerial_perspective = 0.5

	# Tonemap
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0

	# Ambient light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.867, 0.933)
	env.ambient_light_energy = 0.5

	we.environment = env
	we.name = "WorldEnvironment"
	add_child(we)

	# Sun (DirectionalLight3D)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	sun.name = "Sun"
	add_child(sun)

	# Fill light
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.4
	fill.light_color = Color(0.8, 0.867, 1.0)
	fill.rotation_degrees = Vector3(-30, -150, 0)
	fill.name = "FillLight"
	add_child(fill)

func _physics_process(dt: float) -> void:
	# Input
	input_manager.poll()
	_handle_events()

	# Check for external ESP32 commands via UDP
	udp_telemetry.poll_commands()
	udp_telemetry.check_timeout()

	# Physics — use ESP32 commands if available, otherwise gamepad/keyboard
	var commands: Dictionary
	if udp_telemetry.has_external_commands:
		commands = udp_telemetry.get_external_commands()
	else:
		commands = input_manager.get_commands()
	drone_controller.update_physics(dt, commands)

	# Send telemetry to ESP32
	udp_telemetry.send_telemetry(drone_controller.physics, _config, drone_controller.activated, dt)

	# Proximity data (cached once per tick)
	var proximity_data := drone_controller.get_proximity_data()

	# Overlays
	drone_overlays.update_overlays(drone_controller.physics, _config, proximity_data)

	# Camera
	camera_ctrl.set_target(
		drone_controller.physics.position,
		drone_controller.physics.drone_quaternion
	)
	camera_ctrl.set_speed_data(
		drone_controller.physics.velocity.length(),
		_config.get_speed().max_speed
	)
	camera_ctrl.update_camera(dt)

	# Engineering state tracking
	_update_engineering_state(dt)

func _update_engineering_state(dt: float) -> void:
	if not drone_controller.activated:
		return

	var physics := drone_controller.physics

	# Flight timer
	_flight_timer += dt

	# Max altitude
	if physics.position.y > _max_altitude:
		_max_altitude = physics.position.y

	# Max speed
	var speed := physics.get_horizontal_speed()
	if speed > _max_speed:
		_max_speed = speed

	# Battery consumption: each motor draws idle + load*rpm_frac
	var total_amps := 0.0
	var rpms := physics.rotor_physics.motor_rpms
	for i in range(rpms.size()):
		var rpm_frac := rpms[i] / _config.max_rpm
		total_amps += MOTOR_IDLE_AMPS + MOTOR_MAX_AMPS * rpm_frac
	# mAh = amps * hours * 1000 = amps * (dt/3600) * 1000
	_battery_mah_consumed += total_amps * (dt / 3.6)

func _process(dt: float) -> void:
	# HUD throttled to ~20fps
	_hud_timer += dt
	if _hud_timer >= 0.05:
		_hud_timer = 0.0
		_update_hud()

func _update_hud() -> void:
	var physics := drone_controller.physics
	var euler := physics.get_euler_degrees()

	hud_layer.telemetry_panel.update_telemetry({
		"altitude": physics.position.y,
		"speed": physics.get_horizontal_speed(),
		"vspeed": physics.velocity.y,
		"heading": physics.get_heading(),
		"roll": euler.z,
		"pitch": euler.x,
		"throttle": input_manager.throttle,
	})

	hud_layer.motor_panel.update_motors(
		physics.rotor_physics.motor_rpms,
		_config.max_rpm
	)

	hud_layer.attitude_indicator.update_attitude(euler.z, euler.x)

	hud_layer.stick_display.update_sticks(
		input_manager.raw_left_x,
		input_manager.raw_left_y,
		input_manager.raw_right_x,
		input_manager.raw_right_y,
		input_manager.get_commands()
	)

	var input_source := "KB"
	if udp_telemetry.has_external_commands:
		input_source = "ESP32"
	elif input_manager.gamepad_connected:
		input_source = "GAMEPAD"

	var cam_tilt := -1.0
	if camera_ctrl.mode == CameraController3D.CameraMode.FPV:
		cam_tilt = camera_ctrl.get_fpv_tilt_degrees()
	hud_layer.update_status(
		drone_controller.activated,
		camera_ctrl.get_mode_name(),
		input_source,
		_config.get_speed().profile_name,
		cam_tilt
	)

	# Proximity warning
	var prox_data := drone_controller.get_proximity_data()
	hud_layer.update_proximity(prox_data.get("near", false))

	# Engineering panel
	var battery_pct := maxf(0.0, (BATTERY_CAPACITY_MAH - _battery_mah_consumed) / BATTERY_CAPACITY_MAH * 100.0)
	hud_layer.engineering_panel.update_engineering({
		"flight_time": _flight_timer,
		"pos_x": physics.position.x,
		"pos_z": physics.position.z,
		"vspeed_error": physics.last_vspeed_error,
		"max_alt": _max_altitude,
		"max_speed": _max_speed,
		"battery_pct": battery_pct,
		"g_force": physics.g_force,
		"fps": Engine.get_frames_per_second(),
	})

func _handle_events() -> void:
	if input_manager.consume_event("activate_toggle"):
		drone_controller.activate_toggle()

	if input_manager.consume_event("reset_position"):
		drone_controller.reset_drone()
		crash_effects.clear_latest_ghost()
		_reset_engineering_state()
		hud_layer.hide_crash()

	if input_manager.consume_event("toggle_camera"):
		camera_ctrl.cycle_mode()

	if input_manager.consume_event("preset_up"):
		hud_layer.cycle_preset(1)

	if input_manager.consume_event("preset_down"):
		hud_layer.cycle_preset(-1)

	if input_manager.consume_event("blade_right"):
		hud_layer.adjust_blade_count(1)

	if input_manager.consume_event("blade_left"):
		hud_layer.adjust_blade_count(-1)

	if input_manager.consume_event("toggle_config"):
		hud_layer.toggle_config()

func _reset_engineering_state() -> void:
	_flight_timer = 0.0
	_max_altitude = 0.0
	_max_speed = 0.0
	_battery_mah_consumed = 0.0

func _on_drone_crashed(speed: float, obstacle_type: String) -> void:
	camera_ctrl.trigger_crash_flash()
	hud_layer.show_crash(speed, obstacle_type)
	hud_layer.update_crash_count(drone_controller.crash_count)

	# Crash effects
	var pos := drone_controller.crash_position
	var quat := drone_controller.crash_quaternion
	var vel := drone_controller.crash_velocity
	crash_effects.spawn_debris(pos, vel, quat)
	crash_effects.spawn_ghost(pos, quat, _config)
	crash_effects.spawn_smoke_marker(pos)

func _on_drone_reset() -> void:
	hud_layer.hide_crash()
	crash_effects.clear_latest_ghost()
	_reset_engineering_state()

func _on_config_changed(new_config: DroneConfig) -> void:
	_config = new_config
	drone_controller.rebuild(new_config)
	hud_layer.motor_panel.set_motor_count(new_config.motor_count)
	drone_overlays.setup_thrust_lines(new_config.motor_count)
