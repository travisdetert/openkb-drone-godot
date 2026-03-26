class_name DronePhysics
extends RefCounted

const GRAVITY := 9.81
const VERTICAL_GAIN := 10.0
const COSMETIC_TILT_SPEED := 6.0

# Command filter
const CMD_FILTER_TAU := 0.1  # 100ms exponential smoothing

# Damping
const DAMP_ACTIVE := 2.0
const DAMP_PASSIVE := 6.0
const DAMP_BLEND_TAU := 0.25  # 250ms transition

# Yaw torque model
const YAW_TORQUE_GAIN := 15.0
const YAW_ANGULAR_DAMP := 5.0

# Turbulence
const TURB_FORCE_MAG := 0.15
const TURB_DRIFT_RATE := 0.3
const TURB_YAW_MAG := 0.02
const TURB_MIN_ALT := 0.3

# G-force
const GFORCE_FILTER_TAU := 0.1

# State
var position := Vector3(0.0, 0.1, 0.0)
var velocity := Vector3.ZERO
var drone_quaternion := Quaternion.IDENTITY
var angular_velocity := Vector3.ZERO
var mass: float = 1.2

# Commands (raw input)
var pitch_command: float = 0.0
var roll_command: float = 0.0
var yaw_command: float = 0.0
var throttle_command: float = 0.0

# Exposed state
var g_force: float = 1.0
var last_vspeed_error: float = 0.0

# Internal
var _cosmetic_pitch: float = 0.0
var _cosmetic_roll: float = 0.0
var _config: DroneConfig
var _rotor_physics: RotorPhysics
var _drone_radius: float = 0.37

# Command filter state
var _filtered_throttle: float = 0.0
var _filtered_pitch: float = 0.0
var _filtered_roll: float = 0.0
var _filtered_yaw: float = 0.0

# Smooth damping state
var _smooth_damp: float = DAMP_PASSIVE

# Yaw angular velocity (internal)
var _yaw_rate: float = 0.0

# Turbulence state
var _turb_drift: Vector3 = Vector3.ZERO
var _turb_time: float = 0.0

# G-force tracking
var _prev_velocity: Vector3 = Vector3.ZERO
var _g_force_raw: float = 1.0

func _init(config: DroneConfig) -> void:
	_config = config
	mass = config.mass
	_rotor_physics = RotorPhysics.new(config)
	_drone_radius = config.arm_length + config.blade_radius

var rotor_physics: RotorPhysics:
	get: return _rotor_physics

func update_config(config: DroneConfig) -> void:
	_config = config
	mass = config.mass
	_rotor_physics.update_config(config)
	_drone_radius = config.arm_length + config.blade_radius

func get_speed_profile() -> DroneConfig.SpeedProfile:
	return _config.get_speed()

func step(dt: float) -> void:
	# Update rotor visuals
	_rotor_physics.update(dt)

	# --- Command low-pass filter ---
	var cmd_alpha := 1.0 - exp(-dt / CMD_FILTER_TAU)
	_filtered_throttle += (throttle_command - _filtered_throttle) * cmd_alpha
	_filtered_pitch += (pitch_command - _filtered_pitch) * cmd_alpha
	_filtered_roll += (roll_command - _filtered_roll) * cmd_alpha
	_filtered_yaw += (yaw_command - _filtered_yaw) * cmd_alpha

	var sp := get_speed_profile()

	# --- Vertical: target velocity from left stick ---
	var target_vspeed := _filtered_throttle * sp.max_climb_rate
	var vspeed_error := target_vspeed - velocity.y
	last_vspeed_error = vspeed_error
	var vertical_force := Vector3(0.0, (vspeed_error * VERTICAL_GAIN + GRAVITY) * mass, 0.0)

	# --- Horizontal: right stick drives acceleration ---
	var qw := drone_quaternion.w
	var qx := drone_quaternion.x
	var qy := drone_quaternion.y
	var qz := drone_quaternion.z
	var yaw_angle := atan2(
		2.0 * (qw * qy + qx * qz),
		1.0 - 2.0 * (qy * qy + qx * qx)
	)

	var local_forward := -_filtered_pitch
	var local_right := _filtered_roll

	# Stick magnitude (0..1)
	var stick_mag := minf(1.0, sqrt(local_forward * local_forward + local_right * local_right))

	# Rotate to world
	var cos_y := cos(yaw_angle)
	var sin_y := sin(yaw_angle)
	var world_x := local_right * cos_y + local_forward * sin_y
	var world_z := -local_right * sin_y + local_forward * cos_y

	# Current horizontal speed
	var horiz_speed := sqrt(velocity.x * velocity.x + velocity.z * velocity.z)

	# Target max speed scales with stick deflection
	var target_max_speed := stick_mag * sp.max_speed

	# Acceleration proportional to stick deflection
	var accel_mag := stick_mag * sp.accel

	# Translation force
	var translation_force := Vector3.ZERO
	if stick_mag > 0.01:
		var speed_factor := maxf(0.0, 1.0 - horiz_speed / maxf(target_max_speed, 0.1))
		var effective_accel := accel_mag * (0.3 + 0.7 * speed_factor)

		var dir_len := sqrt(world_x * world_x + world_z * world_z)
		if dir_len > 0.001:
			translation_force = Vector3(
				(world_x / dir_len) * effective_accel * mass,
				0.0,
				(world_z / dir_len) * effective_accel * mass
			)

	# --- Smooth damping transition ---
	var damp_blend := clampf(stick_mag / 0.3, 0.0, 1.0)
	var target_damp := lerpf(DAMP_PASSIVE, DAMP_ACTIVE, damp_blend)
	var damp_alpha := 1.0 - exp(-dt / DAMP_BLEND_TAU)
	_smooth_damp += (target_damp - _smooth_damp) * damp_alpha

	var horiz_damp := Vector3(
		-velocity.x * _smooth_damp * mass,
		0.0,
		-velocity.z * _smooth_damp * mass
	)

	# Gravity
	var gravity_force := Vector3(0.0, -GRAVITY * mass, 0.0)

	# --- Turbulence ---
	var turb_force := Vector3.ZERO
	if position.y > TURB_MIN_ALT:
		_turb_time += dt
		# Slow-varying drift
		var drift_x := sin(_turb_time * TURB_DRIFT_RATE * 2.7 + 1.3) * 0.5
		var drift_z := cos(_turb_time * TURB_DRIFT_RATE * 3.1 + 0.7) * 0.5
		_turb_drift = Vector3(drift_x, 0.0, drift_z) * TURB_FORCE_MAG * 0.5
		# Random jitter
		var jitter := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.3, 0.3),
			randf_range(-1.0, 1.0)
		) * TURB_FORCE_MAG
		turb_force = (jitter + _turb_drift) * mass

	# Net force
	var net_force := vertical_force + gravity_force + translation_force + horiz_damp + turb_force

	# Linear integration
	var accel := net_force / mass
	velocity += accel * dt
	position += velocity * dt

	# --- Yaw: torque model with inertia ---
	var target_yaw_rate := _filtered_yaw * sp.yaw_rate
	var yaw_torque := (target_yaw_rate - _yaw_rate) * YAW_TORQUE_GAIN
	var yaw_damp_torque := -_yaw_rate * YAW_ANGULAR_DAMP
	_yaw_rate += (yaw_torque + yaw_damp_torque) * dt

	# Yaw wobble from turbulence
	if position.y > TURB_MIN_ALT:
		_yaw_rate += sin(_turb_time * 4.3 + 2.1) * TURB_YAW_MAG * dt

	angular_velocity = Vector3(0.0, _yaw_rate, 0.0)
	var yaw_delta := _yaw_rate * dt
	var yaw_quat := Quaternion(Vector3.UP, yaw_delta)
	drone_quaternion = yaw_quat * drone_quaternion

	# --- Cosmetic tilt ---
	var target_pitch := -_filtered_pitch * sp.tilt_angle
	var target_roll := _filtered_roll * sp.tilt_angle
	_cosmetic_pitch += (target_pitch - _cosmetic_pitch) * minf(1.0, COSMETIC_TILT_SPEED * dt)
	_cosmetic_roll += (target_roll - _cosmetic_roll) * minf(1.0, COSMETIC_TILT_SPEED * dt)

	# Build final orientation: yaw-only base + cosmetic tilt
	var euler := drone_quaternion.get_euler()  # YXZ order
	var yaw_only := Quaternion.from_euler(Vector3(0.0, euler.y, 0.0))
	var tilt_quat := Quaternion.from_euler(Vector3(_cosmetic_pitch, 0.0, _cosmetic_roll))
	drone_quaternion = yaw_only * tilt_quat
	drone_quaternion = drone_quaternion.normalized()

	# --- G-force tracking ---
	var dv := velocity - _prev_velocity
	_g_force_raw = (dv / dt + Vector3(0.0, GRAVITY, 0.0)).length() / GRAVITY
	var gf_alpha := 1.0 - exp(-dt / GFORCE_FILTER_TAU)
	g_force += (_g_force_raw - g_force) * gf_alpha
	_prev_velocity = velocity

	# --- Ground collision ---
	_resolve_collision()

func _resolve_collision() -> void:
	var ground_offset := _drone_radius * 0.3
	if position.y < ground_offset:
		position.y = ground_offset
		if velocity.y < 0.0:
			velocity.y *= -0.2
		velocity.x *= 0.95
		velocity.z *= 0.95

func reset() -> void:
	position = Vector3(0.0, 0.1, 0.0)
	velocity = Vector3.ZERO
	drone_quaternion = Quaternion.IDENTITY
	angular_velocity = Vector3.ZERO
	_cosmetic_pitch = 0.0
	_cosmetic_roll = 0.0
	_filtered_throttle = 0.0
	_filtered_pitch = 0.0
	_filtered_roll = 0.0
	_filtered_yaw = 0.0
	_smooth_damp = DAMP_PASSIVE
	_yaw_rate = 0.0
	_turb_drift = Vector3.ZERO
	_turb_time = 0.0
	_prev_velocity = Vector3.ZERO
	g_force = 1.0
	_g_force_raw = 1.0
	last_vspeed_error = 0.0
	_rotor_physics.reset()

func get_euler_degrees() -> Vector3:
	var euler := drone_quaternion.get_euler()
	return Vector3(
		rad_to_deg(euler.x),  # pitch
		rad_to_deg(euler.y),  # yaw
		rad_to_deg(euler.z)   # roll
	)

func get_heading() -> float:
	var euler := drone_quaternion.get_euler()
	var yaw_deg := rad_to_deg(euler.y)
	return fmod(fmod(yaw_deg, 360.0) + 360.0, 360.0)

func get_horizontal_speed() -> float:
	return sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
