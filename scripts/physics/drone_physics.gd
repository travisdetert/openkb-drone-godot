class_name DronePhysics
extends RefCounted

const GRAVITY := 9.81
const VERTICAL_GAIN := 10.0
const COSMETIC_TILT_SPEED := 8.0

# State
var position := Vector3(0.0, 0.1, 0.0)
var velocity := Vector3.ZERO
var drone_quaternion := Quaternion.IDENTITY
var angular_velocity := Vector3.ZERO
var mass: float = 1.2

# Commands
var pitch_command: float = 0.0
var roll_command: float = 0.0
var yaw_command: float = 0.0
var throttle_command: float = 0.0

# Internal
var _cosmetic_pitch: float = 0.0
var _cosmetic_roll: float = 0.0
var _config: DroneConfig
var _rotor_physics: RotorPhysics
var _drone_radius: float = 0.37

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

	var sp := get_speed_profile()

	# --- Vertical: target velocity from left stick ---
	var target_vspeed := throttle_command * sp.max_climb_rate
	var vspeed_error := target_vspeed - velocity.y
	var vertical_force := Vector3(0.0, (vspeed_error * VERTICAL_GAIN + GRAVITY) * mass, 0.0)

	# --- Horizontal: right stick drives acceleration ---
	# Extract yaw angle from quaternion
	var qw := drone_quaternion.w
	var qx := drone_quaternion.x
	var qy := drone_quaternion.y
	var qz := drone_quaternion.z
	var yaw_angle := atan2(
		2.0 * (qw * qy + qx * qz),
		1.0 - 2.0 * (qy * qy + qx * qx)
	)

	var local_forward := -pitch_command
	var local_right := roll_command

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

	# Horizontal damping
	var damp_strength: float = 2.0 if stick_mag > 0.05 else 6.0
	var horiz_damp := Vector3(
		-velocity.x * damp_strength * mass,
		0.0,
		-velocity.z * damp_strength * mass
	)

	# Gravity
	var gravity_force := Vector3(0.0, -GRAVITY * mass, 0.0)

	# Net force
	var net_force := vertical_force + gravity_force + translation_force + horiz_damp

	# Linear integration
	var accel := net_force / mass
	velocity += accel * dt
	position += velocity * dt

	# --- Yaw rotation ---
	var yaw_rate_val := yaw_command * sp.yaw_rate
	angular_velocity = Vector3.ZERO
	var yaw_delta := yaw_rate_val * dt
	var yaw_quat := Quaternion(Vector3.UP, yaw_delta)
	drone_quaternion = yaw_quat * drone_quaternion

	# --- Cosmetic tilt ---
	var target_pitch := -pitch_command * sp.tilt_angle
	var target_roll := roll_command * sp.tilt_angle
	_cosmetic_pitch += (target_pitch - _cosmetic_pitch) * minf(1.0, COSMETIC_TILT_SPEED * dt)
	_cosmetic_roll += (target_roll - _cosmetic_roll) * minf(1.0, COSMETIC_TILT_SPEED * dt)

	# Build final orientation: yaw-only base + cosmetic tilt
	var euler := drone_quaternion.get_euler()  # YXZ order
	var yaw_only := Quaternion.from_euler(Vector3(0.0, euler.y, 0.0))
	var tilt_quat := Quaternion.from_euler(Vector3(_cosmetic_pitch, 0.0, _cosmetic_roll))
	drone_quaternion = yaw_only * tilt_quat
	drone_quaternion = drone_quaternion.normalized()

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
