class_name TelemetryPanel
extends PanelContainer

var _alt_value: Label
var _speed_value: Label
var _vspeed_value: Label
var _heading_value: Label
var _roll_value: Label
var _pitch_value: Label
var _throttle_value: Label

func _init() -> void:
	name = "TelemetryPanel"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 12
	offset_top = 12
	offset_right = 170
	offset_bottom = 230

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
	title.text = "TELEMETRY"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0, 1, 0.533))
	vbox.add_child(title)

	var rows := [
		["ALT", "m"],
		["SPD", "m/s"],
		["VS", "m/s"],
		["HDG", "°"],
		["ROLL", "°"],
		["PITCH", "°"],
		["THR", "%"],
	]

	var value_labels: Array[Label] = []
	for row_data in rows:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)

		var lbl := Label.new()
		lbl.text = row_data[0]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lbl.custom_minimum_size.x = 50
		hbox.add_child(lbl)

		var val := Label.new()
		val.text = "0"
		val.add_theme_font_size_override("font_size", 13)
		val.add_theme_color_override("font_color", Color(1, 1, 1))
		val.custom_minimum_size.x = 55
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(val)

		var unit := Label.new()
		unit.text = row_data[1]
		unit.add_theme_font_size_override("font_size", 11)
		unit.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		hbox.add_child(unit)

		vbox.add_child(hbox)
		value_labels.append(val)

	_alt_value = value_labels[0]
	_speed_value = value_labels[1]
	_vspeed_value = value_labels[2]
	_heading_value = value_labels[3]
	_roll_value = value_labels[4]
	_pitch_value = value_labels[5]
	_throttle_value = value_labels[6]

	add_child(vbox)

func update_telemetry(data: Dictionary) -> void:
	_alt_value.text = "%.1f" % data.get("altitude", 0.0)
	_speed_value.text = "%.1f" % data.get("speed", 0.0)
	_vspeed_value.text = "%.1f" % data.get("vspeed", 0.0)
	_heading_value.text = "%.0f" % data.get("heading", 0.0)
	_roll_value.text = "%.1f" % data.get("roll", 0.0)
	_pitch_value.text = "%.1f" % data.get("pitch", 0.0)
	_throttle_value.text = "%.0f" % (data.get("throttle", 0.0) * 100.0)
