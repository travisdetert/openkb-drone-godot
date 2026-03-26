class_name DroneOverlays
extends Node3D

# Visual dev overlays: drop shadow, thrust lines, velocity vector, heading arrow

var _shadow: MeshInstance3D
var _shadow_mat: StandardMaterial3D
var _heading_arrow: MeshInstance3D
var _heading_mat: StandardMaterial3D
var _velocity_arrow: Node3D
var _vel_shaft: MeshInstance3D
var _vel_head: MeshInstance3D
var _vel_mat: StandardMaterial3D
var _thrust_lines: Array[MeshInstance3D] = []
var _thrust_mat_low: StandardMaterial3D
var _thrust_mat_mid: StandardMaterial3D
var _thrust_mat_high: StandardMaterial3D
var _altitude_rings: Array[MeshInstance3D] = []
var _proximity_ring: MeshInstance3D
var _proximity_ring_mat: StandardMaterial3D

const PROXIMITY_RING_RADIUS := 1.8
const PROXIMITY_RING_SEGMENTS := 32
const PROXIMITY_FAR_DIST := 8.0
const PROXIMITY_CLOSE_DIST := 1.5

func _ready() -> void:
	_build_shadow()
	_build_heading_arrow()
	_build_velocity_arrow()
	_build_altitude_markers()
	_build_proximity_ring()

func _build_shadow() -> void:
	# Dark circle projected on ground below drone
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.0, 2.0)
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.albedo_color = Color(0, 0, 0, 0.35)
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.no_depth_test = false
	mesh.material = _shadow_mat
	_shadow = MeshInstance3D.new()
	_shadow.mesh = mesh
	_shadow.name = "DropShadow"
	add_child(_shadow)

func _build_heading_arrow() -> void:
	# Triangle on the ground showing drone heading
	var im := ImmediateMesh.new()
	_heading_mat = StandardMaterial3D.new()
	_heading_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.6)
	_heading_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_heading_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Arrow shape: triangle pointing -Z (forward)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _heading_mat)
	im.surface_add_vertex(Vector3(0, 0, -1.5))   # tip
	im.surface_add_vertex(Vector3(-0.4, 0, 0.2))  # left
	im.surface_add_vertex(Vector3(0.4, 0, 0.2))   # right
	im.surface_end()

	_heading_arrow = MeshInstance3D.new()
	_heading_arrow.mesh = im
	_heading_arrow.name = "HeadingArrow"
	add_child(_heading_arrow)

func _build_velocity_arrow() -> void:
	_vel_mat = StandardMaterial3D.new()
	_vel_mat.albedo_color = Color(0.0, 0.8, 1.0, 0.8)
	_vel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_velocity_arrow = Node3D.new()
	_velocity_arrow.name = "VelocityArrow"

	# Shaft (stretched cylinder)
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.04
	shaft_mesh.bottom_radius = 0.04
	shaft_mesh.height = 1.0
	shaft_mesh.radial_segments = 6
	shaft_mesh.material = _vel_mat
	_vel_shaft = MeshInstance3D.new()
	_vel_shaft.mesh = shaft_mesh
	_velocity_arrow.add_child(_vel_shaft)

	# Arrowhead (cone)
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.12
	head_mesh.height = 0.25
	head_mesh.radial_segments = 6
	head_mesh.material = _vel_mat
	_vel_head = MeshInstance3D.new()
	_vel_head.mesh = head_mesh
	_velocity_arrow.add_child(_vel_head)

	add_child(_velocity_arrow)

func _build_altitude_markers() -> void:
	# Ring markers at key altitudes
	var altitudes := [5.0, 10.0, 25.0, 50.0]
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.08)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for alt in altitudes:
		var im := ImmediateMesh.new()
		var segments := 48
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, ring_mat)
		for i in range(segments + 1):
			var angle := (float(i) / segments) * TAU
			var radius := 8.0
			im.surface_add_vertex(Vector3(cos(angle) * radius, alt, sin(angle) * radius))
		im.surface_end()

		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.name = "AltRing_%dm" % int(alt)
		add_child(mi)
		_altitude_rings.append(mi)

func _build_proximity_ring() -> void:
	_proximity_ring_mat = StandardMaterial3D.new()
	_proximity_ring_mat.albedo_color = Color(0.0, 1.0, 0.0, 0.1)
	_proximity_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_proximity_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_proximity_ring_mat.no_depth_test = true

	var im := ImmediateMesh.new()
	var inner_r := PROXIMITY_RING_RADIUS - 0.15
	var outer_r := PROXIMITY_RING_RADIUS + 0.15

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _proximity_ring_mat)
	for i in range(PROXIMITY_RING_SEGMENTS + 1):
		var angle := (float(i) / PROXIMITY_RING_SEGMENTS) * TAU
		var cos_a := cos(angle)
		var sin_a := sin(angle)
		im.surface_add_vertex(Vector3(inner_r * cos_a, 0, inner_r * sin_a))
		im.surface_add_vertex(Vector3(outer_r * cos_a, 0, outer_r * sin_a))
	im.surface_end()

	_proximity_ring = MeshInstance3D.new()
	_proximity_ring.mesh = im
	_proximity_ring.name = "ProximityRing"
	_proximity_ring.visible = false
	add_child(_proximity_ring)

func _update_proximity_ring(pos: Vector3, proximity_data: Dictionary) -> void:
	var is_near: bool = proximity_data.get("near", false)
	if not is_near:
		_proximity_ring.visible = false
		return

	_proximity_ring.visible = true
	_proximity_ring.position = Vector3(pos.x, 0.07, pos.z)

	var dist: float = proximity_data.get("distance", PROXIMITY_FAR_DIST)
	# Normalize distance: 0.0 = at CLOSE_DIST, 1.0 = at FAR_DIST
	var t := clampf((dist - PROXIMITY_CLOSE_DIST) / (PROXIMITY_FAR_DIST - PROXIMITY_CLOSE_DIST), 0.0, 1.0)

	# Color gradient: red (close) -> yellow (mid) -> green (far)
	var color: Color
	if t < 0.5:
		# red -> yellow
		color = Color(1.0, t * 2.0, 0.0)
	else:
		# yellow -> green
		color = Color(1.0 - (t - 0.5) * 2.0, 1.0, 0.0)

	# Alpha ramps up as obstacle gets closer: 0.1 (far) -> 0.7 (close)
	color.a = lerpf(0.7, 0.1, t)
	_proximity_ring_mat.albedo_color = color

func setup_thrust_lines(motor_count: int) -> void:
	# Remove old
	for line in _thrust_lines:
		line.queue_free()
	_thrust_lines.clear()

	# Thrust color materials
	if not _thrust_mat_low:
		_thrust_mat_low = StandardMaterial3D.new()
		_thrust_mat_low.albedo_color = Color(0.0, 1.0, 0.5, 0.7)
		_thrust_mat_low.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_thrust_mat_low.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		_thrust_mat_mid = StandardMaterial3D.new()
		_thrust_mat_mid.albedo_color = Color(1.0, 0.8, 0.0, 0.7)
		_thrust_mat_mid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_thrust_mat_mid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		_thrust_mat_high = StandardMaterial3D.new()
		_thrust_mat_high.albedo_color = Color(1.0, 0.2, 0.1, 0.7)
		_thrust_mat_high.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_thrust_mat_high.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(motor_count):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.03
		mesh.bottom_radius = 0.03
		mesh.height = 1.0
		mesh.radial_segments = 4
		mesh.material = _thrust_mat_low
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = "ThrustLine_%d" % i
		mi.visible = false
		add_child(mi)
		_thrust_lines.append(mi)

func update_overlays(physics: DronePhysics, config: DroneConfig, proximity_data: Dictionary = {}) -> void:
	var pos := physics.position
	var quat := physics.drone_quaternion
	var vel := physics.velocity

	# --- Drop shadow ---
	# Position on ground directly below drone, size shrinks with altitude
	var alt := maxf(pos.y, 0.1)
	_shadow.position = Vector3(pos.x, 0.05, pos.z)
	# Shadow gets smaller and fainter the higher you go
	var shadow_scale := clampf(2.0 - alt * 0.02, 0.3, 2.5)
	_shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)
	_shadow_mat.albedo_color.a = clampf(0.4 - alt * 0.004, 0.05, 0.4)

	# --- Heading arrow on ground ---
	_heading_arrow.position = Vector3(pos.x, 0.06, pos.z)
	var euler := quat.get_euler()
	_heading_arrow.rotation.y = euler.y

	# --- Velocity vector arrow ---
	var horiz_vel := Vector3(vel.x, 0, vel.z)
	var speed := horiz_vel.length()
	if speed > 0.3:
		_velocity_arrow.visible = true
		# Position at drone, point in velocity direction
		_velocity_arrow.position = pos
		var arrow_len := clampf(speed * 0.3, 0.3, 5.0)

		# Orient the arrow group to point in velocity direction
		var dir := horiz_vel.normalized()
		var target := pos + dir
		_velocity_arrow.look_at(target, Vector3.UP)

		# Shaft: cylinder along -Z, so rotate it to lay along the look direction
		_vel_shaft.position = Vector3(0, 0, -arrow_len / 2.0)
		_vel_shaft.rotation = Vector3(PI / 2.0, 0, 0)
		_vel_shaft.scale = Vector3(1, arrow_len, 1)

		_vel_head.position = Vector3(0, 0, -arrow_len)
		_vel_head.rotation = Vector3(PI / 2.0, 0, 0)
	else:
		_velocity_arrow.visible = false

	# --- Thrust lines ---
	var rpms := physics.rotor_physics.motor_rpms
	var max_rpm := config.max_rpm
	var drone_scale := 3.0  # must match DroneBuilder.SCALE

	for i in range(mini(_thrust_lines.size(), config.motor_count)):
		var mount := config.motors[i]
		var norm_rpm := rpms[i] / max_rpm if max_rpm > 0 else 0.0

		if norm_rpm > 0.05:
			_thrust_lines[i].visible = true
			# Position at motor mount in world space (account for drone transform)
			var motor_local := mount.position * drone_scale
			var motor_world := pos + quat * motor_local
			var line_len := norm_rpm * 1.5  # max 1.5m long
			_thrust_lines[i].position = motor_world + Vector3(0, -line_len / 2.0, 0)
			_thrust_lines[i].scale = Vector3(1, line_len, 1)

			# Color by RPM
			var mesh := _thrust_lines[i].mesh as CylinderMesh
			if norm_rpm < 0.5:
				mesh.material = _thrust_mat_low
			elif norm_rpm < 0.8:
				mesh.material = _thrust_mat_mid
			else:
				mesh.material = _thrust_mat_high
		else:
			_thrust_lines[i].visible = false

	# --- Proximity ring ---
	if not proximity_data.is_empty():
		_update_proximity_ring(pos, proximity_data)
