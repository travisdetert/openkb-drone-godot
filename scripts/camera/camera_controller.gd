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

# FPV cam
var fpv_cam_tilt := deg_to_rad(30.0)  # upward tilt angle (real FPV range 15-45°)
var fpv_fov := 120.0                   # wide FOV for FPV mode
var _default_fov := 60.0

# Speed data for vignette
var _current_speed := 0.0
var _max_speed := 1.0
var _vignette_rect: ColorRect

# Crash flash
var _crash_flash: ColorRect
var _crash_flash_timer := 0.0

# Mouse orbit control
var _is_mouse_down := false
var _mouse_pos := Vector2.ZERO

# Target tracking
var target_position := Vector3(0.0, 1.0, 0.0)
var target_quaternion := Quaternion.IDENTITY

func _ready() -> void:
	fov = _default_fov
	near = 0.1
	far = 1000.0
	_setup_vignette()

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
			elif mode == CameraMode.FPV:
				fpv_cam_tilt = clampf(fpv_cam_tilt + deg_to_rad(delta * 2.0), 0.0, deg_to_rad(60.0))

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
			fov = fpv_fov
		CameraMode.FPV:
			mode = CameraMode.CHASE
			fov = _default_fov
	return get_mode_name()

func get_mode_name() -> String:
	match mode:
		CameraMode.CHASE: return "CHASE"
		CameraMode.ORBIT: return "ORBIT"
		CameraMode.FPV: return "FPV"
	return "CHASE"

func get_fpv_tilt_degrees() -> float:
	return rad_to_deg(fpv_cam_tilt)

func set_speed_data(speed: float, max_speed: float) -> void:
	_current_speed = speed
	_max_speed = maxf(max_speed, 1.0)

func update_camera(dt: float) -> void:
	match mode:
		CameraMode.CHASE:
			_update_chase(dt)
		CameraMode.ORBIT:
			_update_orbit(dt)
		CameraMode.FPV:
			_update_fpv(dt)
	_update_vignette()
	_update_crash_flash(dt)

func _update_chase(dt: float) -> void:
	# Use only yaw for camera offset — no wobble from cosmetic pitch/roll tilt
	var euler := target_quaternion.get_euler()
	var yaw_only := Quaternion.from_euler(Vector3(0.0, euler.y, 0.0))
	var rotated_offset := yaw_only * chase_offset
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
	# Mount at front of drone body, near front LED position
	var fpv_offset := target_quaternion * Vector3(0.0, 0.02, -0.1)
	global_position = target_position + fpv_offset
	# Apply full drone quaternion (yaw + cosmetic tilt)
	quaternion = target_quaternion
	# Tilt camera up relative to drone frame — compensates for forward pitch
	rotate_object_local(Vector3.RIGHT, fpv_cam_tilt)

func _setup_vignette() -> void:
	_vignette_rect = ColorRect.new()
	_vignette_rect.name = "SpeedVignette"
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(0.4, 1.4, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	_vignette_rect.material = mat

	# Crash flash overlay
	_crash_flash = ColorRect.new()
	_crash_flash.name = "CrashFlash"
	_crash_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crash_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crash_flash.color = Color(1.0, 0.0, 0.0, 0.0)

	# Attach to a CanvasLayer so it renders as screen overlay
	var canvas := CanvasLayer.new()
	canvas.name = "VignetteLayer"
	canvas.layer = 100
	canvas.add_child(_vignette_rect)
	canvas.add_child(_crash_flash)
	add_child(canvas)

func _update_vignette() -> void:
	if not _vignette_rect or not _vignette_rect.material:
		return
	var intensity := 0.0
	if mode == CameraMode.FPV:
		# Ramp from 0 at 50% speed to 0.3 at max speed
		intensity = clampf((_current_speed / _max_speed - 0.5) * 0.6, 0.0, 0.3)
	(_vignette_rect.material as ShaderMaterial).set_shader_parameter("intensity", intensity)

func trigger_crash_flash() -> void:
	_crash_flash_timer = 0.5
	if _crash_flash:
		_crash_flash.color = Color(1.0, 0.0, 0.0, 0.7)

func _update_crash_flash(dt: float) -> void:
	if _crash_flash_timer <= 0.0:
		return
	_crash_flash_timer -= dt
	if _crash_flash_timer <= 0.0:
		_crash_flash_timer = 0.0
		if _crash_flash:
			_crash_flash.color = Color(1.0, 0.0, 0.0, 0.0)
		return
	# Fade alpha
	var alpha := clampf(_crash_flash_timer / 0.5 * 0.7, 0.0, 0.7)
	if _crash_flash:
		_crash_flash.color = Color(1.0, 0.0, 0.0, alpha)
	# Screen shake proportional to remaining timer
	var shake_intensity := _crash_flash_timer * 0.4
	h_offset = randf_range(-shake_intensity, shake_intensity)
	v_offset = randf_range(-shake_intensity, shake_intensity)
	if _crash_flash_timer <= 0.01:
		h_offset = 0.0
		v_offset = 0.0
