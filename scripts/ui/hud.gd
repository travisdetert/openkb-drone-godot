extends CanvasLayer

var telemetry_panel: TelemetryPanel
var engineering_panel: EngineeringPanel
var motor_panel: MotorPanel
var attitude_indicator: AttitudeIndicator
var stick_display: StickDisplay
var config_panel_ui: ConfigPanelUI

var status_active_label: Label
var status_camera_label: Label
var status_input_label: Label
var status_speed_label: Label
var status_crash_label: Label

var _crash_overlay: Label
var _proximity_label: Label

signal config_changed(config: DroneConfig)

func _ready() -> void:
	layer = 10

	# Background panels
	_build_hud()

func _build_hud() -> void:
	# Telemetry (top-left)
	telemetry_panel = TelemetryPanel.new()
	add_child(telemetry_panel)

	# Engineering panel (below telemetry)
	engineering_panel = EngineeringPanel.new()
	add_child(engineering_panel)

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

	# Crash overlay (centered)
	_crash_overlay = Label.new()
	_crash_overlay.name = "CrashOverlay"
	_crash_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crash_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crash_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_crash_overlay.add_theme_font_size_override("font_size", 24)
	_crash_overlay.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	_crash_overlay.visible = false
	add_child(_crash_overlay)

	# Proximity warning (top-center)
	_proximity_label = Label.new()
	_proximity_label.name = "ProximityWarning"
	_proximity_label.text = "! PROXIMITY !"
	_proximity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_proximity_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_proximity_label.offset_top = 40
	_proximity_label.add_theme_font_size_override("font_size", 20)
	_proximity_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	_proximity_label.visible = false
	add_child(_proximity_label)

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

	status_active_label = _make_label("STANDBY", Color(1, 0.3, 0.3))
	hbox.add_child(status_active_label)

	hbox.add_child(_make_separator())

	status_camera_label = _make_label("CHASE", Color(0.0, 1.0, 0.533))
	hbox.add_child(status_camera_label)

	hbox.add_child(_make_separator())

	status_input_label = _make_label("KB", Color(0.8, 0.8, 0.8))
	hbox.add_child(status_input_label)

	hbox.add_child(_make_separator())

	status_speed_label = _make_label("NORMAL", Color(1.0, 0.8, 0.0))
	hbox.add_child(status_speed_label)

	hbox.add_child(_make_separator())

	status_crash_label = _make_label("0 CRASHES", Color(0.8, 0.8, 0.8))
	hbox.add_child(status_crash_label)

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

func update_status(active: bool, camera_mode: String, input_source: String, speed_name: String, cam_tilt_deg: float = -1.0) -> void:
	if status_active_label:
		status_active_label.text = "READY" if active else "STANDBY"
		status_active_label.add_theme_color_override("font_color",
			Color(0.0, 1.0, 0.533) if active else Color(1.0, 0.3, 0.3))
	if status_camera_label:
		if cam_tilt_deg >= 0.0:
			status_camera_label.text = "%s %d°" % [camera_mode, int(cam_tilt_deg)]
		else:
			status_camera_label.text = camera_mode
	if status_input_label:
		status_input_label.text = input_source
		# Highlight ESP32 input in cyan
		if input_source == "ESP32":
			status_input_label.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
		else:
			status_input_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
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

func update_crash_count(count: int) -> void:
	if status_crash_label:
		status_crash_label.text = "%d CRASHES" % count if count != 1 else "1 CRASH"
		status_crash_label.add_theme_color_override("font_color",
			Color(1.0, 0.3, 0.3) if count > 0 else Color(0.8, 0.8, 0.8))

func show_crash(speed: float, obstacle_type: String = "") -> void:
	if _crash_overlay:
		var text := "CRASHED @ %.1f m/s" % speed
		if obstacle_type != "" and obstacle_type != "unknown":
			text += "\n[%s]" % obstacle_type.to_upper()
		_crash_overlay.text = text
		_crash_overlay.visible = true

func hide_crash() -> void:
	if _crash_overlay:
		_crash_overlay.visible = false

func update_proximity(is_close: bool) -> void:
	if _proximity_label:
		_proximity_label.visible = is_close
