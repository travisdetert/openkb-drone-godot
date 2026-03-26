class_name DroneController
extends Node3D

# Attached to the drone root Node3D in the scene
# Manages the drone model, physics, and visual sync

var config: DroneConfig
var physics: DronePhysics
var drone_model: Node3D
var armed: bool = false

var _builder := DroneBuilder.new()

func setup(initial_config: DroneConfig) -> void:
	config = initial_config
	physics = DronePhysics.new(config)
	_build_model()

func _build_model() -> void:
	if drone_model:
		remove_child(drone_model)
		drone_model.queue_free()
	drone_model = _builder.build(config)
	add_child(drone_model)

func rebuild(new_config: DroneConfig) -> void:
	config = new_config
	physics.update_config(new_config)
	_build_model()
	armed = false

func update_physics(dt: float, commands: Dictionary) -> void:
	if armed:
		physics.throttle_command = commands.get("throttle", 0.0)
		physics.pitch_command = commands.get("pitch", 0.0)
		physics.roll_command = commands.get("roll", 0.0)
		physics.yaw_command = commands.get("yaw", 0.0)

		# Motor visuals: spin proportional to total effort
		var visual_rpm := 0.4 + absf(physics.throttle_command) * 0.3 \
			+ (absf(physics.pitch_command) + absf(physics.roll_command)) * 0.15
		var cmds: Array[float] = []
		for i in range(config.motor_count):
			cmds.append(minf(1.0, visual_rpm))
		physics.rotor_physics.set_motor_commands(cmds)
	else:
		physics.throttle_command = 0.0
		physics.pitch_command = 0.0
		physics.roll_command = 0.0
		physics.yaw_command = 0.0
		var zero_cmds: Array[float] = []
		for i in range(config.motor_count):
			zero_cmds.append(0.0)
		physics.rotor_physics.set_motor_commands(zero_cmds)

	physics.step(dt)

	# Sync transform
	if drone_model:
		drone_model.position = physics.position
		drone_model.quaternion = physics.drone_quaternion

		# Update blade visuals
		BladeSpinner.update_blades(drone_model, physics.rotor_physics.motor_rpms, dt)

func arm_toggle() -> void:
	armed = !armed

func reset_drone() -> void:
	physics.reset()
	armed = false
