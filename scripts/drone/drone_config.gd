class_name DroneConfig
extends RefCounted

# --- Motor Mount ---
class MotorMount:
	var position: Vector3
	var spin_direction: int  # 1 = CW, -1 = CCW
	var arm_angle: float

	func _init(pos: Vector3, spin: int, angle: float) -> void:
		position = pos
		spin_direction = spin
		arm_angle = angle

# --- Speed Profile ---
class SpeedProfile:
	var profile_name: String
	var max_speed: float
	var accel: float
	var max_climb_rate: float
	var yaw_rate: float
	var tilt_angle: float

	func _init(n: String, ms: float, a: float, mcr: float, yr: float, ta: float) -> void:
		profile_name = n
		max_speed = ms
		accel = a
		max_climb_rate = mcr
		yaw_rate = yr
		tilt_angle = ta

# --- Speed Profiles (static data) ---
static var SPEED_PROFILES: Array[SpeedProfile] = [
	SpeedProfile.new("Slow", 8.0, 10.0, 3.0, 2.0, 0.15),
	SpeedProfile.new("Normal", 20.0, 25.0, 6.0, 3.5, 0.3),
	SpeedProfile.new("Fast", 40.0, 50.0, 12.0, 5.0, 0.45),
	SpeedProfile.new("Ludicrous", 80.0, 100.0, 25.0, 7.0, 0.6),
]

# --- Configuration ---
var config_name: String = "Quadcopter"
var motor_count: int = 4
var blades_per_motor: int = 2
var motors: Array[MotorMount] = []
var mass: float = 1.2
var arm_length: float = 0.25
var blade_radius: float = 0.12
var thrust_coeff: float = 1.0e-5
var torque_coeff: float = 1.0e-7
var drag_coeff: float = 0.3
var max_rpm: float = 12000.0
var motor_time_constant: float = 0.05
var speed_profile: int = 1

func get_speed() -> SpeedProfile:
	if speed_profile >= 0 and speed_profile < SPEED_PROFILES.size():
		return SPEED_PROFILES[speed_profile]
	return SPEED_PROFILES[1]

func duplicate_config() -> DroneConfig:
	var c := DroneConfig.new()
	c.config_name = config_name
	c.motor_count = motor_count
	c.blades_per_motor = blades_per_motor
	c.motors = []
	for m in motors:
		c.motors.append(MotorMount.new(m.position, m.spin_direction, m.arm_angle))
	c.mass = mass
	c.arm_length = arm_length
	c.blade_radius = blade_radius
	c.thrust_coeff = thrust_coeff
	c.torque_coeff = torque_coeff
	c.drag_coeff = drag_coeff
	c.max_rpm = max_rpm
	c.motor_time_constant = motor_time_constant
	c.speed_profile = speed_profile
	return c

# --- Factory Methods ---
static func make_motors(count: int, arm_len: float) -> Array[MotorMount]:
	var result: Array[MotorMount] = []
	for i in range(count):
		var angle := (2.0 * PI * i) / count - PI / 2.0
		var spin: int = 1 if (i % 2 == 0) else -1
		var pos := Vector3(
			arm_len * cos(angle),
			0.0,
			arm_len * sin(angle)
		)
		result.append(MotorMount.new(pos, spin, angle))
	return result

static func create_quad() -> DroneConfig:
	var c := DroneConfig.new()
	c.config_name = "Quadcopter"
	c.motor_count = 4
	c.blades_per_motor = 2
	var arm := 0.25
	c.arm_length = arm
	c.motors = [
		MotorMount.new(Vector3(arm, 0, -arm), 1, -PI / 4.0),
		MotorMount.new(Vector3(-arm, 0, -arm), -1, -3.0 * PI / 4.0),
		MotorMount.new(Vector3(-arm, 0, arm), 1, 3.0 * PI / 4.0),
		MotorMount.new(Vector3(arm, 0, arm), -1, PI / 4.0),
	]
	c.mass = 1.2
	c.blade_radius = 0.12
	c.thrust_coeff = 1.0e-5
	c.torque_coeff = 1.0e-7
	c.drag_coeff = 0.3
	c.max_rpm = 12000.0
	c.motor_time_constant = 0.05
	c.speed_profile = 1
	return c

static func create_hex() -> DroneConfig:
	var c := DroneConfig.new()
	c.config_name = "Hexacopter"
	c.motor_count = 6
	c.blades_per_motor = 2
	var arm := 0.30
	c.arm_length = arm
	c.motors = make_motors(6, arm)
	c.mass = 2.0
	c.blade_radius = 0.10
	c.thrust_coeff = 0.8e-5
	c.torque_coeff = 0.8e-7
	c.drag_coeff = 0.35
	c.max_rpm = 11000.0
	c.motor_time_constant = 0.06
	c.speed_profile = 1
	return c

static func create_octo() -> DroneConfig:
	var c := DroneConfig.new()
	c.config_name = "Octocopter"
	c.motor_count = 8
	c.blades_per_motor = 2
	var arm := 0.35
	c.arm_length = arm
	c.motors = make_motors(8, arm)
	c.mass = 3.5
	c.blade_radius = 0.09
	c.thrust_coeff = 0.6e-5
	c.torque_coeff = 0.6e-7
	c.drag_coeff = 0.4
	c.max_rpm = 10000.0
	c.motor_time_constant = 0.07
	c.speed_profile = 1
	return c

static var PRESET_NAMES: Array[String] = ["quad", "hex", "octo"]

static func create_preset(preset_name: String) -> DroneConfig:
	match preset_name:
		"quad": return create_quad()
		"hex": return create_hex()
		"octo": return create_octo()
		_: return create_quad()

func recalc_motor_positions() -> void:
	for m in motors:
		var angle := m.arm_angle
		m.position.x = arm_length * cos(angle)
		m.position.z = arm_length * sin(angle)
