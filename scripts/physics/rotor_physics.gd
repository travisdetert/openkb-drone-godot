class_name RotorPhysics
extends RefCounted

var motor_rpms: Array[float] = []
var motor_targets: Array[float] = []
var _config: DroneConfig

func _init(config: DroneConfig) -> void:
	_config = config
	_resize(config.motor_count)

func _resize(count: int) -> void:
	motor_rpms = []
	motor_targets = []
	for i in range(count):
		motor_rpms.append(0.0)
		motor_targets.append(0.0)

func update_config(config: DroneConfig) -> void:
	_config = config
	_resize(config.motor_count)

func set_motor_commands(commands: Array[float]) -> void:
	for i in range(_config.motor_count):
		var cmd: float = 0.0
		if i < commands.size():
			cmd = clampf(commands[i], 0.0, 1.0)
		motor_targets[i] = cmd * _config.max_rpm

func update(dt: float) -> void:
	var alpha := 1.0 - exp(-dt / _config.motor_time_constant)
	for i in range(_config.motor_count):
		motor_rpms[i] += (motor_targets[i] - motor_rpms[i]) * alpha

func get_normalized_rpms() -> Array[float]:
	var result: Array[float] = []
	for rpm in motor_rpms:
		result.append(rpm / _config.max_rpm)
	return result

func reset() -> void:
	for i in range(motor_rpms.size()):
		motor_rpms[i] = 0.0
		motor_targets[i] = 0.0
