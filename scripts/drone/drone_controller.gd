class_name DroneController
extends Node3D

# Attached to the drone root Node3D in the scene
# Manages the drone model, physics, and visual sync

signal drone_crashed(speed: float, obstacle_type: String)
signal drone_reset()

var config: DroneConfig
var physics: DronePhysics
var drone_model: Node3D
var activated: bool = false

var crashed := false
var crash_timer := 0.0
var crash_speed := 0.0
var crash_count := 0
var crash_position := Vector3.ZERO
var crash_quaternion := Quaternion.IDENTITY
var crash_velocity := Vector3.ZERO
const CRASH_SPEED_THRESHOLD := 2.0   # m/s — below this, soft bounce
const CRASH_RESET_DELAY := 2.0       # seconds before auto-reset
const COLLISION_RADIUS := 1.11       # _drone_radius(0.37) * SCALE(3.0)
const PROXIMITY_RADIUS_MULT := 8.0   # proximity detection = 8x collision radius

var _collision_shape: SphereShape3D
var _proximity_shape: SphereShape3D

var _builder := DroneBuilder.new()

func setup(initial_config: DroneConfig) -> void:
	config = initial_config
	physics = DronePhysics.new(config)
	_build_model()
	_collision_shape = SphereShape3D.new()
	_collision_shape.radius = COLLISION_RADIUS
	_proximity_shape = SphereShape3D.new()
	_proximity_shape.radius = COLLISION_RADIUS * PROXIMITY_RADIUS_MULT

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
	activated = false

func update_physics(dt: float, commands: Dictionary) -> void:
	# If crashed, count down and auto-reset
	if crashed:
		crash_timer -= dt
		if crash_timer <= 0.0:
			reset_drone()
			drone_reset.emit()
		return

	if activated:
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

	# Check obstacle collisions
	var col := _check_collisions()
	if col["collided"]:
		var impact_speed: float = physics.velocity.length()
		if impact_speed > CRASH_SPEED_THRESHOLD:
			_trigger_crash(impact_speed, col.get("obstacle_type", "unknown"))
		else:
			# Soft bounce
			var normal: Vector3 = col["normal"]
			physics.velocity = physics.velocity.bounce(normal) * 0.3
			physics.position += normal * 0.1

	# Sync transform
	if drone_model:
		drone_model.position = physics.position
		drone_model.quaternion = physics.drone_quaternion

		# Update blade visuals
		BladeSpinner.update_blades(drone_model, physics.rotor_physics.motor_rpms, dt)

func activate_toggle() -> void:
	activated = !activated

func reset_drone() -> void:
	physics.reset()
	activated = false
	crashed = false
	crash_timer = 0.0
	if drone_model:
		drone_model.visible = true

func _check_collisions() -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return {"collided": false}

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _collision_shape
	params.transform = Transform3D(Basis.IDENTITY, physics.position)
	params.collision_mask = 1

	var results := space_state.intersect_shape(params, 1)
	if results.is_empty():
		return {"collided": false}

	var result := results[0]
	var collider: Object = result["collider"]
	var obstacle_type := "unknown"
	if collider is Node and collider.has_meta("obstacle_type"):
		obstacle_type = collider.get_meta("obstacle_type")

	# Estimate collision normal: direction from obstacle to drone
	var col_pos: Vector3 = collider.global_position if collider is Node3D else physics.position
	var normal := (physics.position - col_pos).normalized()
	if normal.length_squared() < 0.01:
		normal = Vector3.UP

	return {"collided": true, "normal": normal, "obstacle_type": obstacle_type}

func get_proximity_data() -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return {"near": false, "distance": 999.0, "direction": Vector3.ZERO}

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _proximity_shape
	params.transform = Transform3D(Basis.IDENTITY, physics.position)
	params.collision_mask = 1

	var results := space_state.intersect_shape(params, 8)
	if results.is_empty():
		return {"near": false, "distance": 999.0, "direction": Vector3.ZERO}

	# Find closest obstacle
	var closest_dist := 999.0
	var closest_dir := Vector3.ZERO
	for result in results:
		var collider: Object = result["collider"]
		if collider is Node3D:
			var to_obstacle: Vector3 = (collider as Node3D).global_position - physics.position
			var dist := to_obstacle.length()
			if dist < closest_dist:
				closest_dist = dist
				closest_dir = to_obstacle.normalized()

	return {"near": true, "distance": closest_dist, "direction": closest_dir}

func _trigger_crash(speed: float, obstacle_type: String) -> void:
	# Store crash state before zeroing
	crash_position = physics.position
	crash_quaternion = physics.drone_quaternion
	crash_velocity = physics.velocity

	crashed = true
	crash_timer = CRASH_RESET_DELAY
	crash_speed = speed
	crash_count += 1
	physics.velocity = Vector3.ZERO
	if drone_model:
		drone_model.visible = false
	drone_crashed.emit(speed, obstacle_type)
