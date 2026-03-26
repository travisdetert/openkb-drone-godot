class_name CrashEffects
extends Node3D

# Manages all crash visual effects: debris scatter, ghost drone, smoke markers

var _debris_pieces: Array[Dictionary] = []
var _latest_ghost: Node3D = null
var _smoke_markers: Array[Node3D] = []
var _time: float = 0.0

const DEBRIS_COUNT_MIN := 12
const DEBRIS_COUNT_MAX := 16
const DEBRIS_LIFETIME := 1.5
const DEBRIS_FADE_START := 1.0  # Start fading at this time (last 0.5s)
const DEBRIS_VELOCITY_MIN := 2.0
const DEBRIS_VELOCITY_MAX := 6.0
const GRAVITY := 9.8

func _process(dt: float) -> void:
	_time += dt
	_update_debris(dt)
	_update_smoke_markers(dt)

# --- Debris scatter ---

func spawn_debris(pos: Vector3, velocity: Vector3, quat: Quaternion) -> void:
	var count := DEBRIS_COUNT_MIN + randi() % (DEBRIS_COUNT_MAX - DEBRIS_COUNT_MIN + 1)
	var colors := [
		Color(0.933, 0.933, 0.933),  # white body
		Color(0.267, 0.267, 0.267),  # dark gray arms
		Color(0.2, 0.2, 0.267),      # motor gray
	]

	for i in range(count):
		var piece := _create_debris_mesh(colors[i % colors.size()])
		add_child(piece)
		piece.global_position = pos

		# Random outward + upward velocity, plus fraction of crash velocity
		var rand_dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.3, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()
		var rand_speed := randf_range(DEBRIS_VELOCITY_MIN, DEBRIS_VELOCITY_MAX)
		var piece_vel := rand_dir * rand_speed + velocity * 0.3

		# Random rotation speed
		var rot_speed := Vector3(
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0)
		)

		_debris_pieces.append({
			"node": piece,
			"velocity": piece_vel,
			"rot_speed": rot_speed,
			"age": 0.0,
			"material": piece.get_meta("material"),
		})

func _create_debris_mesh(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Alternate between box and cylinder pieces
	if randi() % 2 == 0:
		var mesh := BoxMesh.new()
		var s := randf_range(0.05, 0.15)
		mesh.size = Vector3(s, s * 0.5, s * 0.7)
		mesh.material = mat
		mi.mesh = mesh
	else:
		var mesh := CylinderMesh.new()
		mesh.top_radius = randf_range(0.02, 0.06)
		mesh.bottom_radius = mesh.top_radius
		mesh.height = randf_range(0.08, 0.2)
		mesh.radial_segments = 5
		mesh.material = mat
		mi.mesh = mesh

	mi.set_meta("material", mat)
	return mi

func _update_debris(dt: float) -> void:
	var to_remove: Array[int] = []
	for i in range(_debris_pieces.size()):
		var piece: Dictionary = _debris_pieces[i]
		var node: MeshInstance3D = piece["node"]
		var vel: Vector3 = piece["velocity"]
		var rot_speed: Vector3 = piece["rot_speed"]
		var age: float = piece["age"] + dt
		piece["age"] = age

		if age >= DEBRIS_LIFETIME:
			to_remove.append(i)
			node.queue_free()
			continue

		# Gravity
		vel.y -= GRAVITY * dt
		piece["velocity"] = vel

		# Move
		node.global_position += vel * dt

		# Ground clamp
		if node.global_position.y < 0.05:
			node.global_position.y = 0.05
			vel.y = 0.0
			vel.x *= 0.8
			vel.z *= 0.8
			piece["velocity"] = vel

		# Rotate
		node.rotation += rot_speed * dt

		# Fade alpha in final 0.5s
		if age > DEBRIS_FADE_START:
			var mat: StandardMaterial3D = piece["material"]
			var fade_t := (age - DEBRIS_FADE_START) / (DEBRIS_LIFETIME - DEBRIS_FADE_START)
			mat.albedo_color.a = lerpf(1.0, 0.0, fade_t)

	# Remove expired (reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		_debris_pieces.remove_at(to_remove[i])

# --- Ghost drone ---

func spawn_ghost(pos: Vector3, quat: Quaternion, config: DroneConfig) -> void:
	clear_latest_ghost()

	var builder := DroneBuilder.new()
	var ghost := builder.build(config)
	ghost.name = "CrashGhost"

	# Recolor all meshes to red translucent
	_recolor_recursive(ghost)

	ghost.global_position = pos
	# The drone model has SCALE applied inside build(), so set the rotation on inner level
	# Ghost is already scaled by DroneBuilder, just set position at crash point
	# We need to apply the drone's rotation: ghost root is at world pos,
	# the model inside is already at origin, so we rotate the ghost root
	ghost.quaternion = quat

	add_child(ghost)
	_latest_ghost = ghost

func clear_latest_ghost() -> void:
	if _latest_ghost and is_instance_valid(_latest_ghost):
		_latest_ghost.queue_free()
		_latest_ghost = null

func _recolor_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			# Override all surface materials
			for s in range(mesh.get_surface_count()):
				var ghost_mat := StandardMaterial3D.new()
				ghost_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.3)
				ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				ghost_mat.no_depth_test = true
				mi.set_surface_override_material(s, ghost_mat)

	for child in node.get_children():
		_recolor_recursive(child)

# --- Smoke markers ---

func spawn_smoke_marker(pos: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "SmokeMarker"
	marker.position = Vector3(pos.x, 0.0, pos.z)

	# Smoke column (translucent gray cylinder)
	var col_mesh := CylinderMesh.new()
	col_mesh.top_radius = 0.3
	col_mesh.bottom_radius = 0.5
	col_mesh.height = 3.0
	col_mesh.radial_segments = 8
	var col_mat := StandardMaterial3D.new()
	col_mat.albedo_color = Color(0.4, 0.4, 0.4, 0.25)
	col_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	col_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	col_mat.no_depth_test = true
	col_mesh.material = col_mat
	var column := MeshInstance3D.new()
	column.mesh = col_mesh
	column.position.y = 1.5
	column.name = "SmokeColumn"
	marker.add_child(column)

	# Ground sphere (red-orange)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.6
	sphere_mesh.height = 1.2
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 6
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.5)
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(1.0, 0.3, 0.1)
	sphere_mat.emission_energy_multiplier = 0.5
	sphere_mesh.material = sphere_mat
	var sphere := MeshInstance3D.new()
	sphere.mesh = sphere_mesh
	sphere.position.y = 0.3
	sphere.name = "GroundGlow"
	marker.add_child(sphere)

	marker.set_meta("base_y", 1.5)
	add_child(marker)
	_smoke_markers.append(marker)

func _update_smoke_markers(dt: float) -> void:
	for marker in _smoke_markers:
		if not is_instance_valid(marker):
			continue
		# Gentle vertical oscillation on the smoke column
		var column := marker.get_node_or_null("SmokeColumn")
		if column:
			var base_y: float = marker.get_meta("base_y")
			column.position.y = base_y + sin(_time * 1.5) * 0.15
		# Slow rotation for "rising smoke" effect
		marker.rotation.y += dt * 0.5
