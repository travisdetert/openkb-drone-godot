class_name MotorPanel
extends PanelContainer

var _bars_container: VBoxContainer
var _bar_fills: Array[ColorRect] = []
var _bar_values: Array[Label] = []
var _motor_count: int = 4

func _init() -> void:
	name = "MotorPanel"
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -170
	offset_top = 12
	offset_right = -12
	offset_bottom = 200

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_color = Color(0, 1, 0.533, 0.3)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = "MOTORS"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0, 1, 0.533))
	vbox.add_child(title)

	_bars_container = VBoxContainer.new()
	_bars_container.add_theme_constant_override("separation", 3)
	vbox.add_child(_bars_container)

	add_child(vbox)

func set_motor_count(count: int) -> void:
	_motor_count = count
	_bar_fills.clear()
	_bar_values.clear()

	# Remove old bars
	for child in _bars_container.get_children():
		child.queue_free()

	# Build new bars
	for i in range(count):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var label := Label.new()
		label.text = "M%d" % (i + 1)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		label.custom_minimum_size.x = 25
		row.add_child(label)

		# Bar track
		var track := PanelContainer.new()
		var track_style := StyleBoxFlat.new()
		track_style.bg_color = Color(0.15, 0.15, 0.15)
		track_style.corner_radius_top_left = 2
		track_style.corner_radius_top_right = 2
		track_style.corner_radius_bottom_left = 2
		track_style.corner_radius_bottom_right = 2
		track.add_theme_stylebox_override("panel", track_style)
		track.custom_minimum_size = Vector2(70, 12)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var fill := ColorRect.new()
		fill.color = Color(0, 1, 0.533)
		fill.custom_minimum_size = Vector2(0, 10)
		fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		track.add_child(fill)
		row.add_child(track)

		var value := Label.new()
		value.text = "0"
		value.add_theme_font_size_override("font_size", 10)
		value.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		value.custom_minimum_size.x = 40
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)

		_bars_container.add_child(row)
		_bar_fills.append(fill)
		_bar_values.append(value)

func update_motors(rpms: Array[float], max_rpm: float) -> void:
	for i in range(mini(_bar_fills.size(), rpms.size())):
		var pct := minf(100.0, (rpms[i] / max_rpm) * 100.0)

		# Update fill width
		var track := _bar_fills[i].get_parent() as PanelContainer
		if track:
			_bar_fills[i].custom_minimum_size.x = (pct / 100.0) * track.custom_minimum_size.x

		_bar_values[i].text = str(roundi(rpms[i]))

		# Color coding: green -> yellow -> red
		if pct < 50:
			_bar_fills[i].color = Color(0, 1, 0.533)
		elif pct < 80:
			_bar_fills[i].color = Color(1, 0.8, 0)
		else:
			_bar_fills[i].color = Color(1, 0.267, 0.267)
