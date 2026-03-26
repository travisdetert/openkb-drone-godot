class_name DroneBuilder
extends RefCounted

const SCALE := 3.0

func build(config: DroneConfig) -> Node3D:
	var root := Node3D.new()
	root.name = "DroneModel"

	# Central body
	_create_body(root, config)

	# Arms + motors + blades
	for i in range(config.motor_count):
		var mount := config.motors[i]
		_create_arm(root, mount)
		_create_motor(root, mount, i)
		_create_blades(root, mount, config, i)

	# Landing gear
	_create_landing_gear(root, config)

	# Scale the whole drone up for visibility
	root.scale = Vector3.ONE * SCALE

	return root

func _create_body(root: Node3D, config: DroneConfig) -> void:
	var plate_size := config.arm_length * 0.6

	# Main body plate
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(plate_size, 0.03, plate_size)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.933, 0.933, 0.933)
	plate_mesh.material = plate_mat
	var plate := MeshInstance3D.new()
	plate.mesh = plate_mesh
	plate.name = "BodyPlate"
	root.add_child(plate)

	# Top dome
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = plate_size * 0.35
	dome_mesh.height = plate_size * 0.35
	dome_mesh.radial_segments = 8
	dome_mesh.rings = 6
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = Color(0.867, 0.867, 0.933)
	dome_mesh.material = dome_mat
	var dome := MeshInstance3D.new()
	dome.mesh = dome_mesh
	dome.position.y = 0.015 + plate_size * 0.175
	dome.name = "Dome"
	root.add_child(dome)

	# Front LED (red)
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.015
	led_mesh.height = 0.03
	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color(1.0, 0.133, 0.0)
	led_mat.emission_enabled = true
	led_mat.emission = Color(1.0, 0.133, 0.0)
	led_mat.emission_energy_multiplier = 2.0
	led_mesh.material = led_mat
	var front_led := MeshInstance3D.new()
	front_led.mesh = led_mesh
	front_led.position = Vector3(0, 0.02, -plate_size * 0.4)
	front_led.name = "FrontLED"
	root.add_child(front_led)

	# Rear LED (green)
	var rear_led_mat := StandardMaterial3D.new()
	rear_led_mat.albedo_color = Color(0.0, 1.0, 0.267)
	rear_led_mat.emission_enabled = true
	rear_led_mat.emission = Color(0.0, 1.0, 0.267)
	rear_led_mat.emission_energy_multiplier = 2.0
	var rear_led_mesh := SphereMesh.new()
	rear_led_mesh.radius = 0.015
	rear_led_mesh.height = 0.03
	rear_led_mesh.material = rear_led_mat
	var rear_led := MeshInstance3D.new()
	rear_led.mesh = rear_led_mesh
	rear_led.position = Vector3(0, 0.02, plate_size * 0.4)
	rear_led.name = "RearLED"
	root.add_child(rear_led)

func _create_arm(root: Node3D, mount: DroneConfig.MotorMount) -> void:
	var dx := mount.position.x
	var dz := mount.position.z
	var length := sqrt(dx * dx + dz * dz)
	var angle := atan2(dx, dz)

	var is_front := dz < 0
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.018, 0.014, length)
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.8, 0.8, 0.8) if is_front else Color(0.267, 0.267, 0.267)
	arm_mesh.material = arm_mat
	var arm := MeshInstance3D.new()
	arm.mesh = arm_mesh
	arm.position = Vector3(dx / 2.0, 0.0, dz / 2.0)
	arm.rotation.y = angle
	arm.name = "Arm"
	root.add_child(arm)

func _create_motor(root: Node3D, mount: DroneConfig.MotorMount, index: int) -> void:
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = 0.02
	bell_mesh.bottom_radius = 0.025
	bell_mesh.height = 0.03
	bell_mesh.radial_segments = 12
	var bell_mat := StandardMaterial3D.new()
	bell_mat.albedo_color = Color(0.2, 0.2, 0.267)
	bell_mat.metallic = 0.8
	bell_mat.roughness = 0.3
	bell_mesh.material = bell_mat
	var motor := MeshInstance3D.new()
	motor.mesh = bell_mesh
	motor.position = Vector3(mount.position.x, 0.015, mount.position.z)
	motor.name = "Motor_%d" % index
	root.add_child(motor)

func _create_blades(root: Node3D, mount: DroneConfig.MotorMount, config: DroneConfig, index: int) -> void:
	var blade_group := Node3D.new()
	blade_group.name = "Blades_%d" % index
	blade_group.position = Vector3(mount.position.x, 0.0, mount.position.z)
	blade_group.set_meta("spin_direction", mount.spin_direction)
	blade_group.set_meta("motor_index", index)

	# Individual blades
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.2, 0.2, 0.2)

	for i in range(config.blades_per_motor):
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(config.blade_radius - 0.01, 0.003, 0.012)
		blade_mesh.material = blade_mat
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		var angle := (2.0 * PI * i) / config.blades_per_motor
		blade.position = Vector3(
			cos(angle) * config.blade_radius * 0.5,
			0.035,
			sin(angle) * config.blade_radius * 0.5
		)
		blade.rotation.y = -angle
		blade.name = "Blade_%d" % i
		blade_group.add_child(blade)

	# Blur disc
	var disc_mesh := PlaneMesh.new()
	disc_mesh.size = Vector2(config.blade_radius * 2.0, config.blade_radius * 2.0)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.6, 0.733, 0.867, 0.0)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_mat.no_depth_test = true
	disc_mesh.material = disc_mat
	var disc := MeshInstance3D.new()
	disc.mesh = disc_mesh
	disc.position.y = 0.035
	disc.name = "BlurDisc"
	blade_group.add_child(disc)

	root.add_child(blade_group)

func _create_landing_gear(root: Node3D, config: DroneConfig) -> void:
	var gear_mat := StandardMaterial3D.new()
	gear_mat.albedo_color = Color(0.4, 0.4, 0.4)

	var spread := config.arm_length * 0.5
	var positions := [
		Vector3(-spread, -0.06, -spread),
		Vector3(spread, -0.06, -spread),
		Vector3(-spread, -0.06, spread),
		Vector3(spread, -0.06, spread),
	]

	for pos in positions:
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.005
		leg_mesh.bottom_radius = 0.005
		leg_mesh.height = 0.06
		leg_mesh.radial_segments = 4
		leg_mesh.material = gear_mat
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.position = pos
		leg.name = "LandingLeg"
		root.add_child(leg)

		var foot_mesh := SphereMesh.new()
		foot_mesh.radius = 0.01
		foot_mesh.height = 0.02
		foot_mesh.radial_segments = 4
		foot_mesh.rings = 3
		foot_mesh.material = gear_mat
		var foot := MeshInstance3D.new()
		foot.mesh = foot_mesh
		foot.position = Vector3(pos.x, pos.y - 0.03, pos.z)
		foot.name = "LandingFoot"
		root.add_child(foot)
