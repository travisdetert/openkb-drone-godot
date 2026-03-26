class_name UDPTelemetry
extends Node

# Sends drone telemetry over UDP and receives commands from ESP32
# Telemetry OUT: port 4210 (broadcast)
# Commands IN:   port 4211 (listen)

const TELEMETRY_PORT := 4210
const COMMAND_PORT := 4211
const BROADCAST_ADDR := "255.255.255.255"
const SEND_INTERVAL := 0.05  # 20Hz

var _send_peer: PacketPeerUDP
var _recv_peer: PacketPeerUDP
var _send_timer: float = 0.0
var _enabled: bool = true

# Received commands from ESP32 (overrides gamepad when active)
var has_external_commands: bool = false
var ext_throttle: float = 0.0
var ext_yaw: float = 0.0
var ext_pitch: float = 0.0
var ext_roll: float = 0.0
var ext_activate: bool = false
var _last_ext_time: float = 0.0

func _ready() -> void:
	# Outbound telemetry
	_send_peer = PacketPeerUDP.new()
	_send_peer.set_broadcast_enabled(true)
	_send_peer.set_dest_address(BROADCAST_ADDR, TELEMETRY_PORT)

	# Inbound commands
	_recv_peer = PacketPeerUDP.new()
	var err := _recv_peer.bind(COMMAND_PORT)
	if err == OK:
		print("UDP telemetry: listening for commands on port ", COMMAND_PORT)
	else:
		print("UDP telemetry: failed to bind command port ", COMMAND_PORT, " (err ", err, ")")

	print("UDP telemetry: broadcasting on port ", TELEMETRY_PORT)

func send_telemetry(physics: DronePhysics, config: DroneConfig, active: bool, dt: float) -> void:
	if not _enabled:
		return

	_send_timer += dt
	if _send_timer < SEND_INTERVAL:
		return
	_send_timer = 0.0

	var pos := physics.position
	var vel := physics.velocity
	var euler := physics.get_euler_degrees()
	var rpms := physics.rotor_physics.motor_rpms

	# Compact JSON telemetry packet
	var data := {
		"t": Time.get_ticks_msec(),
		"pos": [snapped(pos.x, 0.01), snapped(pos.y, 0.01), snapped(pos.z, 0.01)],
		"vel": [snapped(vel.x, 0.01), snapped(vel.y, 0.01), snapped(vel.z, 0.01)],
		"att": [snapped(euler.x, 0.1), snapped(euler.y, 0.1), snapped(euler.z, 0.1)],
		"hdg": snapped(physics.get_heading(), 0.1),
		"spd": snapped(physics.get_horizontal_speed(), 0.01),
		"active": active,
		"preset": config.config_name,
		"motors": [],
	}
	for rpm in rpms:
		data["motors"].append(snapped(rpm, 1.0))

	var json_str := JSON.stringify(data)
	_send_peer.put_packet(json_str.to_utf8_buffer())

func poll_commands() -> void:
	if not _enabled:
		return

	while _recv_peer.get_available_packet_count() > 0:
		var packet := _recv_peer.get_packet()
		var json_str := packet.get_string_from_utf8()
		var json := JSON.new()
		var err := json.parse(json_str)
		if err != OK:
			continue

		var data: Dictionary = json.data
		if data.has("throttle"):
			ext_throttle = clampf(float(data["throttle"]), -1.0, 1.0)
		if data.has("yaw"):
			ext_yaw = clampf(float(data["yaw"]), -1.0, 1.0)
		if data.has("pitch"):
			ext_pitch = clampf(float(data["pitch"]), -1.0, 1.0)
		if data.has("roll"):
			ext_roll = clampf(float(data["roll"]), -1.0, 1.0)
		if data.has("activate"):
			ext_activate = bool(data["activate"])

		has_external_commands = true
		_last_ext_time = Time.get_ticks_msec() / 1000.0

func check_timeout() -> void:
	# If no commands received for 500ms, release external control
	if has_external_commands:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_ext_time > 0.5:
			has_external_commands = false
			ext_throttle = 0.0
			ext_yaw = 0.0
			ext_pitch = 0.0
			ext_roll = 0.0

func get_external_commands() -> Dictionary:
	return {
		"throttle": ext_throttle,
		"yaw": ext_yaw,
		"pitch": ext_pitch,
		"roll": ext_roll,
	}
