class_name InputManager
extends Node

const DEADZONE := 0.08
const EXPO := 0.3
const KB_AXIS_STRENGTH := 0.6
const KB_THROTTLE_STRENGTH := 0.7

# Flight commands
var throttle: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0

# One-shot events (consumed after reading)
var arm_toggle: bool = false
var reset_position: bool = false
var toggle_camera: bool = false
var preset_up: bool = false
var preset_down: bool = false
var blade_left: bool = false
var blade_right: bool = false
var toggle_config: bool = false

# Raw stick values for HUD display
var raw_left_x: float = 0.0
var raw_left_y: float = 0.0
var raw_right_x: float = 0.0
var raw_right_y: float = 0.0

var gamepad_connected: bool = false
var gamepad_device: int = -1
var gamepad_name: String = ""

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Check if any gamepad is already connected
	_detect_gamepad()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_detect_gamepad()

func _detect_gamepad() -> void:
	var joypads := Input.get_connected_joypads()
	if joypads.size() > 0:
		gamepad_device = joypads[0]
		gamepad_connected = true
		gamepad_name = Input.get_joy_name(gamepad_device)
		print("Gamepad connected: ", gamepad_name, " (device ", gamepad_device, ")")
	else:
		gamepad_device = -1
		gamepad_connected = false
		gamepad_name = ""

func _input(event: InputEvent) -> void:
	# One-shot events from action presses
	if event.is_action_pressed("arm_toggle"):
		arm_toggle = true
	if event.is_action_pressed("reset_position"):
		reset_position = true
	if event.is_action_pressed("toggle_camera"):
		toggle_camera = true
	if event.is_action_pressed("preset_up"):
		preset_up = true
	if event.is_action_pressed("preset_down"):
		preset_down = true
	if event.is_action_pressed("blade_left"):
		blade_left = true
	if event.is_action_pressed("blade_right"):
		blade_right = true
	if event.is_action_pressed("toggle_config"):
		toggle_config = true

func poll() -> void:
	if gamepad_connected:
		_poll_gamepad()
	else:
		_poll_keyboard()

func _poll_gamepad() -> void:
	# Mode 2: Left stick = throttle + yaw, Right stick = pitch + roll
	var dev := gamepad_device
	raw_left_x = Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
	raw_left_y = Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
	raw_right_x = Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X)
	raw_right_y = Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)

	throttle = _apply_deadzone(-raw_left_y)   # up = climb
	yaw = _apply_expo(_apply_deadzone(-raw_left_x))
	pitch = _apply_expo(_apply_deadzone(-raw_right_y))  # up = forward
	roll = _apply_expo(_apply_deadzone(raw_right_x))

func _poll_keyboard() -> void:
	raw_left_x = 0.0
	raw_left_y = 0.0
	raw_right_x = 0.0
	raw_right_y = 0.0

	# Throttle: Space = climb, Shift = descend
	throttle = 0.0
	if Input.is_action_pressed("throttle_up"):
		throttle = KB_THROTTLE_STRENGTH
	if Input.is_action_pressed("throttle_down"):
		throttle = -KB_THROTTLE_STRENGTH

	# Pitch: W = forward (-), S = back (+)
	pitch = 0.0
	if Input.is_action_pressed("pitch_forward"):
		pitch = -KB_AXIS_STRENGTH
	if Input.is_action_pressed("pitch_back"):
		pitch = KB_AXIS_STRENGTH

	# Roll: A = left (-), D = right (+)
	roll = 0.0
	if Input.is_action_pressed("roll_right"):
		roll = KB_AXIS_STRENGTH
	if Input.is_action_pressed("roll_left"):
		roll = -KB_AXIS_STRENGTH

	# Yaw: Q = left/CCW (-), E = right/CW (+)
	yaw = 0.0
	if Input.is_action_pressed("yaw_left"):
		yaw = -KB_AXIS_STRENGTH
	if Input.is_action_pressed("yaw_right"):
		yaw = KB_AXIS_STRENGTH

	# Set raw values for keyboard stick display
	raw_left_x = -yaw / KB_AXIS_STRENGTH if yaw != 0 else 0.0
	raw_left_y = -throttle / KB_THROTTLE_STRENGTH if throttle != 0 else 0.0
	raw_right_x = roll / KB_AXIS_STRENGTH if roll != 0 else 0.0
	raw_right_y = -pitch / KB_AXIS_STRENGTH if pitch != 0 else 0.0

func consume_event(event_name: String) -> bool:
	match event_name:
		"arm_toggle":
			if arm_toggle:
				arm_toggle = false
				return true
		"reset_position":
			if reset_position:
				reset_position = false
				return true
		"toggle_camera":
			if toggle_camera:
				toggle_camera = false
				return true
		"preset_up":
			if preset_up:
				preset_up = false
				return true
		"preset_down":
			if preset_down:
				preset_down = false
				return true
		"blade_left":
			if blade_left:
				blade_left = false
				return true
		"blade_right":
			if blade_right:
				blade_right = false
				return true
		"toggle_config":
			if toggle_config:
				toggle_config = false
				return true
	return false

func get_commands() -> Dictionary:
	return {
		"throttle": throttle,
		"yaw": yaw,
		"pitch": pitch,
		"roll": roll,
	}

func _apply_deadzone(value: float) -> float:
	if absf(value) < DEADZONE:
		return 0.0
	var s := signf(value)
	return s * (absf(value) - DEADZONE) / (1.0 - DEADZONE)

func _apply_expo(value: float) -> float:
	return value * (1.0 - EXPO) + value * value * value * EXPO
