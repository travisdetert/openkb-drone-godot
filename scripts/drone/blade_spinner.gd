class_name BladeSpinner
extends RefCounted

# Updates blade rotation and blur disc visibility for all motors on a drone model

static func update_blades(drone_model: Node3D, motor_rpms: Array[float], dt: float) -> void:
	for blade_group in drone_model.get_children():
		if not blade_group.name.begins_with("Blades_"):
			continue

		var motor_index: int = blade_group.get_meta("motor_index", 0)
		var spin_direction: int = blade_group.get_meta("spin_direction", 1)

		var rpm: float = 0.0
		if motor_index < motor_rpms.size():
			rpm = motor_rpms[motor_index]

		var angle_per_frame := (rpm / 60.0) * TAU * dt * spin_direction
		var norm := minf(rpm / 6000.0, 1.0)

		for child in blade_group.get_children():
			if child.name == "BlurDisc":
				# Fade in blur disc at high RPM
				var disc := child as MeshInstance3D
				if disc and disc.mesh:
					var mat := disc.mesh.material as StandardMaterial3D
					if mat:
						mat.albedo_color.a = maxf(0.0, (norm - 0.3) * 0.35)
			elif child.name.begins_with("Blade_"):
				# Rotate individual blades
				child.rotation.y += angle_per_frame
				# Hide individual blades when spinning fast
				child.visible = norm < 0.7
