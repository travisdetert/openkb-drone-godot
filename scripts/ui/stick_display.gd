class_name StickDisplay
extends Control

var _left_x: float = 0.0
var _left_y: float = 0.0
var _right_x: float = 0.0
var _right_y: float = 0.0
var _commands: Dictionary = {"throttle": 0.0, "yaw": 0.0, "pitch": 0.0, "roll": 0.0}

func _init() -> void:
	name = "StickDisplay"
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 180
	offset_top = -130
	offset_right = 400
	offset_bottom = -20
	custom_minimum_size = Vector2(220, 110)

func _draw() -> void:
	var w := 220.0
	var h := 110.0
	var r := 40.0

	# Background
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(0, 0, w, h), Color(0, 1, 0.533, 0.3), false, 1.0)

	# Labels
	draw_string(ThemeDB.fallback_font, Vector2(20, 12), "L: THR/YAW",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 1, 0.533))
	draw_string(ThemeDB.fallback_font, Vector2(125, 12), "R: PITCH/ROLL",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 1, 0.533))

	# Left stick
	_draw_stick(55, 58, r, _left_x, _left_y)
	# Right stick
	_draw_stick(165, 58, r, _right_x, _right_y)

	# Command readouts
	var thr_text := "THR:%.2f  YAW:%.2f" % [_commands.get("throttle", 0.0), _commands.get("yaw", 0.0)]
	draw_string(ThemeDB.fallback_font, Vector2(4, h - 4), thr_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.8, 0))

	var pitch_text := "PIT:%.2f  ROL:%.2f" % [_commands.get("pitch", 0.0), _commands.get("roll", 0.0)]
	draw_string(ThemeDB.fallback_font, Vector2(w - 120, h - 4), pitch_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.8, 0))

func _draw_stick(cx: float, cy: float, r: float, x: float, y: float) -> void:
	# Outer circle
	draw_arc(Vector2(cx, cy), r, 0, TAU, 32, Color(0, 1, 0.533, 0.3), 1.0)

	# Crosshair
	draw_line(Vector2(cx - r, cy), Vector2(cx + r, cy), Color(1, 1, 1, 0.1), 1.0)
	draw_line(Vector2(cx, cy - r), Vector2(cx, cy + r), Color(1, 1, 1, 0.1), 1.0)

	# Dot at stick position
	var dot_x := cx + x * r
	var dot_y := cy + y * r
	draw_circle(Vector2(dot_x, dot_y), 5.0, Color(0, 1, 0.533))

func update_sticks(left_x: float, left_y: float, right_x: float, right_y: float, commands: Dictionary) -> void:
	_left_x = left_x
	_left_y = left_y
	_right_x = right_x
	_right_y = right_y
	_commands = commands
	queue_redraw()
