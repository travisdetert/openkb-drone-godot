class_name ConfigPanelUI
extends PanelContainer

signal config_changed(config: DroneConfig)

var _is_open := false
var _current_preset := "quad"
var _current_config: DroneConfig

var _preset_buttons: Dictionary = {}  # String -> Button
var _speed_buttons: Array[Button] = []
var _blade_slider: HSlider
var _blade_value: Label
var _mass_slider: HSlider
var _mass_value: Label
var _arm_slider: HSlider
var _arm_value: Label

func _init() -> void:
	name = "ConfigPanel"
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -230
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	visible = false

	_current_config = DroneConfig.create_quad()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.border_color = Color(0, 1, 0.533, 0.3)
	style.border_width_left = 1
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	add_theme_stylebox_override("panel", style)

	_build()

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Title
	var title := Label.new()
	title.text = "DRONE CONFIG"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0, 1, 0.533))
	vbox.add_child(title)

	# Presets
	vbox.add_child(_make_section_label("Preset"))
	var preset_box := HBoxContainer.new()
	preset_box.add_theme_constant_override("separation", 4)
	var presets := [
		["quad", "Quad (4)"],
		["hex", "Hex (6)"],
		["octo", "Octo (8)"],
	]
	for p in presets:
		var btn := Button.new()
		btn.text = p[1]
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_preset_selected.bind(p[0]))
		preset_box.add_child(btn)
		_preset_buttons[p[0]] = btn
	vbox.add_child(preset_box)
	_update_preset_buttons()

	# Speed profiles
	vbox.add_child(_make_section_label("Speed Profile"))
	var speed_box := VBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 3)
	for i in range(DroneConfig.SPEED_PROFILES.size()):
		var sp := DroneConfig.SPEED_PROFILES[i]
		var btn := Button.new()
		btn.text = "%s (%dm/s)" % [sp.profile_name, int(sp.max_speed)]
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_speed_selected.bind(i))
		speed_box.add_child(btn)
		_speed_buttons.append(btn)
	vbox.add_child(speed_box)
	_update_speed_buttons()

	# Blade count
	vbox.add_child(_make_section_label("Blades per Motor"))
	var blade_row := HBoxContainer.new()
	_blade_slider = HSlider.new()
	_blade_slider.min_value = 2
	_blade_slider.max_value = 6
	_blade_slider.step = 1
	_blade_slider.value = _current_config.blades_per_motor
	_blade_slider.custom_minimum_size.x = 120
	_blade_slider.value_changed.connect(_on_blade_changed)
	blade_row.add_child(_blade_slider)
	_blade_value = Label.new()
	_blade_value.text = str(_current_config.blades_per_motor)
	_blade_value.add_theme_font_size_override("font_size", 12)
	_blade_value.add_theme_color_override("font_color", Color.WHITE)
	blade_row.add_child(_blade_value)
	vbox.add_child(blade_row)

	# Mass
	vbox.add_child(_make_section_label("Mass (kg)"))
	var mass_row := HBoxContainer.new()
	_mass_slider = HSlider.new()
	_mass_slider.min_value = 0.5
	_mass_slider.max_value = 10.0
	_mass_slider.step = 0.1
	_mass_slider.value = _current_config.mass
	_mass_slider.custom_minimum_size.x = 120
	_mass_slider.value_changed.connect(_on_mass_changed)
	mass_row.add_child(_mass_slider)
	_mass_value = Label.new()
	_mass_value.text = "%.1f" % _current_config.mass
	_mass_value.add_theme_font_size_override("font_size", 12)
	_mass_value.add_theme_color_override("font_color", Color.WHITE)
	mass_row.add_child(_mass_value)
	vbox.add_child(mass_row)

	# Arm length
	vbox.add_child(_make_section_label("Arm Length (m)"))
	var arm_row := HBoxContainer.new()
	_arm_slider = HSlider.new()
	_arm_slider.min_value = 0.1
	_arm_slider.max_value = 0.8
	_arm_slider.step = 0.01
	_arm_slider.value = _current_config.arm_length
	_arm_slider.custom_minimum_size.x = 120
	_arm_slider.value_changed.connect(_on_arm_changed)
	arm_row.add_child(_arm_slider)
	_arm_value = Label.new()
	_arm_value.text = "%.2f" % _current_config.arm_length
	_arm_value.add_theme_font_size_override("font_size", 12)
	_arm_value.add_theme_color_override("font_color", Color.WHITE)
	arm_row.add_child(_arm_value)
	vbox.add_child(arm_row)

	# Help text
	vbox.add_child(_make_section_label("KEYBOARD"))
	var help := Label.new()
	help.text = "SPACE/SHIFT - Throttle\nWASD/Arrows - Pitch/Roll\nQ/E - Yaw\nENTER - Activate/Standby\nR - Reset\nC - Camera mode\n1/2 - Preset cycle\n3/4 - Blades -/+\nTAB - Toggle config"
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(help)

	scroll.add_child(vbox)
	add_child(scroll)

func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	return lbl

func _update_preset_buttons() -> void:
	for key in _preset_buttons:
		var btn: Button = _preset_buttons[key]
		if key == _current_preset:
			btn.modulate = Color(0, 1, 0.533)
		else:
			btn.modulate = Color.WHITE

func _update_speed_buttons() -> void:
	for i in range(_speed_buttons.size()):
		if i == _current_config.speed_profile:
			_speed_buttons[i].modulate = Color(0, 1, 0.533)
		else:
			_speed_buttons[i].modulate = Color.WHITE

func _on_preset_selected(preset_name: String) -> void:
	_select_preset(preset_name)

func _select_preset(preset_name: String) -> void:
	_current_preset = preset_name
	_current_config = DroneConfig.create_preset(preset_name)
	_update_preset_buttons()
	_update_speed_buttons()
	_update_sliders()
	_emit_change()

func _on_speed_selected(index: int) -> void:
	select_speed(index)

func select_speed(index: int) -> void:
	_current_config.speed_profile = index
	_update_speed_buttons()
	_emit_change()

func _on_blade_changed(value: float) -> void:
	_current_config.blades_per_motor = int(value)
	_blade_value.text = str(int(value))
	_emit_change()

func _on_mass_changed(value: float) -> void:
	_current_config.mass = value
	_mass_value.text = "%.1f" % value
	_emit_change()

func _on_arm_changed(value: float) -> void:
	_current_config.arm_length = value
	_arm_value.text = "%.2f" % value
	_current_config.recalc_motor_positions()
	_emit_change()

func _update_sliders() -> void:
	if _blade_slider:
		_blade_slider.value = _current_config.blades_per_motor
		_blade_value.text = str(_current_config.blades_per_motor)
	if _mass_slider:
		_mass_slider.value = _current_config.mass
		_mass_value.text = "%.1f" % _current_config.mass
	if _arm_slider:
		_arm_slider.value = _current_config.arm_length
		_arm_value.text = "%.2f" % _current_config.arm_length

func _emit_change() -> void:
	config_changed.emit(_current_config.duplicate_config())

func toggle() -> void:
	_is_open = !_is_open
	visible = _is_open

func cycle_preset(direction: int) -> void:
	var names := DroneConfig.PRESET_NAMES
	var idx := names.find(_current_preset)
	var next_idx := (idx + direction + names.size()) % names.size()
	_select_preset(names[next_idx])

func adjust_blade_count(delta: int) -> void:
	var new_count := clampi(_current_config.blades_per_motor + delta, 2, 6)
	_current_config.blades_per_motor = new_count
	if _blade_slider:
		_blade_slider.value = new_count
		_blade_value.text = str(new_count)
	_emit_change()

func get_config() -> DroneConfig:
	return _current_config.duplicate_config()
