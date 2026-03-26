class_name CameraController3D
extends Camera3D

enum CameraMode { CHASE, ORBIT, FPV }

var mode: CameraMode = CameraMode.CHASE

# Chase cam
var chase_offset := Vector3(0.0, 3.0, 8.0)
var chase_look_offset := Vector3(0.0, 0.5, 0.0)
var smoothing := 5.0

# Orbit cam
var orbit_radius := 10.0
var orbit_speed := 0.3
var orbit_phi := PI / 6.0  # vertical angle
var orbit_theta := 0.0     # horizontal angle

# Mouse orbit control
var _is_mouse_down := false
var _mouse_pos := Vector2.ZERO

# Target tracking
var target_position := Vector3(0.0, 1.0, 0.0)
var target_quaternion := Quaternion.IDENTITY

func _ready() -> void:
	fov = 60.0
	near = 0.1
	far = 1000.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_mouse_down = mb.pressed
			_mouse_pos = mb.position

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var delta := -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			if mode == CameraMode.ORBIT:
				orbit_radius = clampf(orbit_radius + delta * 0.5, 3.0, 30.0)
			elif mode == CameraMode.CHASE:
				chase_offset.z = clampf(chase_offset.z + delta * 0.5, 3.0, 20.0)

	elif event is InputEventMouseMotion and _is_mouse_down:
		var mm := event as InputEventMouseMotion
		if mode == CameraMode.ORBIT:
			orbit_theta -= mm.relative.x * 0.005
			orbit_phi = clampf(orbit_phi + mm.relative.y * 0.005, 0.05, PI / 2.0 - 0.05)

func set_target(pos: Vector3, quat: Quaternion) -> void:
	target_position = pos
	target_quaternion = quat

func cycle_mode() -> String:
	match mode:
		CameraMode.CHASE:
			mode = CameraMode.ORBIT
		CameraMode.ORBIT:
			mode = CameraMode.FPV
		CameraMode.FPV:
			mode = CameraMode.CHASE
	return get_mode_name()

func get_mode_name() -> String:
	match mode:
		CameraMode.CHASE: return "CHASE"
		CameraMode.ORBIT: return "ORBIT"
		CameraMode.FPV: return "FPV"
	return "CHASE"

func update_camera(dt: float) -> void:
	match mode:
		CameraMode.CHASE:
			_update_chase(dt)
		CameraMode.ORBIT:
			_update_orbit(dt)
		CameraMode.FPV:
			_update_fpv(dt)

func _update_chase(dt: float) -> void:
	var offset := chase_offset
	# Rotate offset by target orientation
	var rotated_offset := target_quaternion * offset
	var desired := target_position + rotated_offset

	var alpha := 1.0 - exp(-smoothing * dt)
	global_position = global_position.lerp(desired, alpha)

	var look_target := target_position + chase_look_offset
	look_at(look_target, Vector3.UP)

func _update_orbit(dt: float) -> void:
	if not _is_mouse_down:
		orbit_theta += orbit_speed * dt

	var x := target_position.x + orbit_radius * cos(orbit_phi) * sin(orbit_theta)
	var y := target_position.y + orbit_radius * sin(orbit_phi)
	var z := target_position.z + orbit_radius * cos(orbit_phi) * cos(orbit_theta)

	global_position = Vector3(x, y, z)
	look_at(target_position, Vector3.UP)

func _update_fpv(_dt: float) -> void:
	var fpv_offset := target_quaternion * Vector3(0.0, 0.05, -0.2)
	global_position = target_position + fpv_offset
	quaternion = target_quaternion
	rotate_x(-0.15)
