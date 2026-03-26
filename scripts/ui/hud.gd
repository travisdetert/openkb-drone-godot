extends CanvasLayer

var telemetry_panel: TelemetryPanel
var motor_panel: MotorPanel
var attitude_indicator: AttitudeIndicator
var stick_display: StickDisplay
var config_panel_ui: ConfigPanelUI

var status_armed_label: Label
var status_camera_label: Label
var status_input_label: Label
var status_speed_label: Label

signal config_changed(config: DroneConfig)

func _ready() -> void:
	layer = 10

	# Background panels
	_build_hud()

func _build_hud() -> void:
	# Telemetry (top-left)
	telemetry_panel = TelemetryPanel.new()
	add_child(telemetry_panel)

	# Motor panel (top-right)
	motor_panel = MotorPanel.new()
	add_child(motor_panel)

	# Attitude indicator (bottom-left)
	attitude_indicator = AttitudeIndicator.new()
	add_child(attitude_indicator)

	# Stick display (bottom, right of attitude)
	stick_display = StickDisplay.new()
	add_child(stick_display)

	# Status bar (bottom-center)
	_build_status_bar()

	# Config panel (right side)
	config_panel_ui = ConfigPanelUI.new()
	config_panel_ui.config_changed.connect(func(c: DroneConfig): config_changed.emit(c))
	add_child(config_panel_ui)

func _build_status_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "StatusBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -30
	bar.offset_bottom = 0
	bar.offset_left = 200
	bar.offset_right = -200

	var bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	bg.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	status_armed_label = _make_label("DISARMED", Color(1, 0.3, 0.3))
	hbox.add_child(status_armed_label)

	hbox.add_child(_make_separator())

	status_camera_label = _make_label("CHASE", Color(0.0, 1.0, 0.533))
	hbox.add_child(status_camera_label)

	hbox.add_child(_make_separator())

	status_input_label = _make_label("KB", Color(0.8, 0.8, 0.8))
	hbox.add_child(status_input_label)

	hbox.add_child(_make_separator())

	status_speed_label = _make_label("NORMAL", Color(1.0, 0.8, 0.0))
	hbox.add_child(status_speed_label)

	bg.add_child(hbox)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -36
	center.offset_bottom = -4
	center.name = "StatusBarCenter"
	center.add_child(bg)
	add_child(center)

func _make_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_separator() -> Label:
	var sep := Label.new()
	sep.text = "|"
	sep.add_theme_font_size_override("font_size", 13)
	sep.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	return sep

func update_status(armed: bool, camera_mode: String, input_connected: bool, speed_name: String) -> void:
	if status_armed_label:
		status_armed_label.text = "ARMED" if armed else "DISARMED"
		status_armed_label.add_theme_color_override("font_color",
			Color(0.0, 1.0, 0.533) if armed else Color(1.0, 0.3, 0.3))
	if status_camera_label:
		status_camera_label.text = camera_mode
	if status_input_label:
		status_input_label.text = "GAMEPAD" if input_connected else "KB"
	if status_speed_label:
		status_speed_label.text = speed_name.to_upper()

func toggle_config() -> void:
	if config_panel_ui:
		config_panel_ui.toggle()

func cycle_preset(direction: int) -> void:
	if config_panel_ui:
		config_panel_ui.cycle_preset(direction)

func adjust_blade_count(delta: int) -> void:
	if config_panel_ui:
		config_panel_ui.adjust_blade_count(delta)

func select_speed(index: int) -> void:
	if config_panel_ui:
		config_panel_ui.select_speed(index)
