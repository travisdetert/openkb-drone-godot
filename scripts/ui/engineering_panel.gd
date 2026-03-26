class_name EngineeringPanel
extends PanelContainer

var _time_value: Label
var _pos_x_value: Label
var _pos_z_value: Label
var _verr_value: Label
var _mxalt_value: Label
var _mxspd_value: Label
var _batt_value: Label
var _g_value: Label
var _fps_value: Label

func _init() -> void:
	name = "EngineeringPanel"
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 12
	offset_top = 234
	offset_right = 170
	offset_bottom = 480

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
	title.text = "ENGINEERING"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0, 1, 0.533))
	vbox.add_child(title)

	var rows := [
		["TIME", ""],
		["POS X", "m"],
		["POS Z", "m"],
		["VERR", "m/s"],
		["MXALT", "m"],
		["MXSPD", "m/s"],
		["BATT", "%"],
		["G", ""],
		["FPS", ""],
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

	_time_value = value_labels[0]
	_pos_x_value = value_labels[1]
	_pos_z_value = value_labels[2]
	_verr_value = value_labels[3]
	_mxalt_value = value_labels[4]
	_mxspd_value = value_labels[5]
	_batt_value = value_labels[6]
	_g_value = value_labels[7]
	_fps_value = value_labels[8]

	add_child(vbox)

func update_engineering(data: Dictionary) -> void:
	# TIME — M:SS format
	var flight_time: float = data.get("flight_time", 0.0)
	var minutes := int(flight_time) / 60
	var seconds := int(flight_time) % 60
	_time_value.text = "%d:%02d" % [minutes, seconds]

	# POS X/Z
	_pos_x_value.text = "%.1f" % data.get("pos_x", 0.0)
	_pos_z_value.text = "%.1f" % data.get("pos_z", 0.0)

	# VERR
	_verr_value.text = "%.2f" % data.get("vspeed_error", 0.0)

	# MXALT / MXSPD
	_mxalt_value.text = "%.1f" % data.get("max_alt", 0.0)
	_mxspd_value.text = "%.1f" % data.get("max_speed", 0.0)

	# BATT — color-coded
	var batt_pct: float = data.get("battery_pct", 100.0)
	_batt_value.text = "%.0f" % batt_pct
	if batt_pct > 50.0:
		_batt_value.add_theme_color_override("font_color", Color(0.0, 1.0, 0.533))
	elif batt_pct > 20.0:
		_batt_value.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	else:
		_batt_value.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	# G-force
	_g_value.text = "%.2f" % data.get("g_force", 1.0)

	# FPS
	_fps_value.text = "%.0f" % data.get("fps", 0.0)
