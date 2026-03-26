extends Node3D

var drone_controller: DroneController
var input_manager: InputManager
var camera_ctrl: CameraController3D
var hud_layer: CanvasLayer
var environment_builder: EnvironmentBuilder

var _hud_timer: float = 0.0
var _config: DroneConfig

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

	# Physics
	var commands := input_manager.get_commands()
	drone_controller.update_physics(dt, commands)

	# Camera
	camera_ctrl.set_target(
		drone_controller.physics.position,
		drone_controller.physics.drone_quaternion
	)
	camera_ctrl.update_camera(dt)

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

	hud_layer.update_status(
		drone_controller.armed,
		camera_ctrl.get_mode_name(),
		input_manager.gamepad_connected,
		_config.get_speed().profile_name
	)

func _handle_events() -> void:
	if input_manager.consume_event("arm_toggle"):
		drone_controller.arm_toggle()

	if input_manager.consume_event("reset_position"):
		drone_controller.reset_drone()

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

func _on_config_changed(new_config: DroneConfig) -> void:
	_config = new_config
	drone_controller.rebuild(new_config)
	hud_layer.motor_panel.set_motor_count(new_config.motor_count)
