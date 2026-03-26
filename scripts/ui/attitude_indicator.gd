class_name AttitudeIndicator
extends Control

var _roll: float = 0.0
var _pitch: float = 0.0
var _size: float = 140.0

func _init() -> void:
	name = "AttitudeIndicator"
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 12
	offset_top = -200
	offset_right = 172
	offset_bottom = -40
	custom_minimum_size = Vector2(_size + 20, _size + 30)

func _draw() -> void:
	var cx := 10.0 + _size / 2.0
	var cy := 25.0 + _size / 2.0
	var r := _size / 2.0 - 2.0

	# Background label
	draw_string(ThemeDB.fallback_font, Vector2(cx - 30, 16), "ATTITUDE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 1, 0.533))

	# Clip region (draw circle background)
	draw_circle(Vector2(cx, cy), r, Color(0, 0, 0, 0.7))

	# Save transform and apply roll rotation
	var roll_rad := deg_to_rad(-_roll)
	var pitch_px := _pitch * 1.5

	# Sky (blue top half)
	# We'll draw rectangles rotated by roll, offset by pitch
	var center := Vector2(cx, cy)

	# Use draw_set_transform to rotate around center
	draw_set_transform(center, roll_rad, Vector2.ONE)

	# Sky rect (above horizon)
	draw_rect(Rect2(-r * 2, -r * 2, r * 4, r * 2 + pitch_px), Color(0.133, 0.4, 0.8))

	# Ground rect (below horizon)
	draw_rect(Rect2(-r * 2, pitch_px, r * 4, r * 2), Color(0.533, 0.4, 0.2))

	# Horizon line
	draw_line(Vector2(-r * 2, pitch_px), Vector2(r * 2, pitch_px), Color.WHITE, 2.0)

	# Pitch ladder
	for deg in range(-30, 31, 10):
		if deg == 0:
			continue
		var y := pitch_px - deg * 1.5
		var half_w := 25.0 if (deg % 20 == 0) else 15.0
		draw_line(Vector2(-half_w, y), Vector2(half_w, y), Color(1, 1, 1, 0.5), 1.0)

	# Reset transform
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Mask: draw circle outline to clean edges
	# Draw a thick ring in the background color to mask corners
	for i in range(36):
		var a1 := (i / 36.0) * TAU
		var a2 := ((i + 1) / 36.0) * TAU
		# Outer dark ring
	# End masking approach - just draw the fixed aircraft symbol

	# Fixed aircraft symbol (center crosshair)
	draw_line(Vector2(cx - 35, cy), Vector2(cx - 12, cy), Color(1, 0.8, 0), 2.5)
	draw_line(Vector2(cx - 12, cy), Vector2(cx - 12, cy + 6), Color(1, 0.8, 0), 2.5)
	draw_line(Vector2(cx + 35, cy), Vector2(cx + 12, cy), Color(1, 0.8, 0), 2.5)
	draw_line(Vector2(cx + 12, cy), Vector2(cx + 12, cy + 6), Color(1, 0.8, 0), 2.5)
	draw_circle(Vector2(cx, cy), 3.0, Color(1, 0.8, 0))

	# Outer ring
	draw_arc(Vector2(cx, cy), r, 0, TAU, 64, Color(0, 1, 0.533, 0.3), 2.0)

func update_attitude(roll_deg: float, pitch_deg: float) -> void:
	_roll = roll_deg
	_pitch = pitch_deg
	queue_redraw()
