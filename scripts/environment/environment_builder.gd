class_name EnvironmentBuilder
extends Node3D

func build() -> void:
	_create_ground()
	_create_grids()
	_create_helipad()
	_create_buildings()
	_create_trees()
	_create_clouds()

func _create_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2000, 2000)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.416, 0.667, 0.333)  # #6aaa55
	mesh.material = mat
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.name = "Ground"
	add_child(ground)

func _create_grids() -> void:
	# Fine grid near center
	var fine_grid := _make_grid(40.0, 40, Color(0.333, 0.533, 0.29, 0.4))
	fine_grid.position.y = 0.02
	fine_grid.name = "FineGrid"
	add_child(fine_grid)

	# Coarse grid for large area
	var coarse_grid := _make_grid(1000.0, 100, Color(0.333, 0.6, 0.267, 0.15))
	coarse_grid.position.y = 0.01
	coarse_grid.name = "CoarseGrid"
	add_child(coarse_grid)

func _make_grid(grid_size: float, divisions: int, color: Color) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var step := grid_size / divisions
	var half := grid_size / 2.0

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(divisions + 1):
		var offset := -half + i * step
		# Lines along X
		im.surface_add_vertex(Vector3(offset, 0, -half))
		im.surface_add_vertex(Vector3(offset, 0, half))
		# Lines along Z
		im.surface_add_vertex(Vector3(-half, 0, offset))
		im.surface_add_vertex(Vector3(half, 0, offset))
	im.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = im
	return mi

func _create_helipad() -> void:
	# Gray circle pad
	var pad_mesh := PlaneMesh.new()
	pad_mesh.size = Vector2(6.0, 6.0)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.4, 0.4, 0.4)
	pad_mesh.material = pad_mat
	var pad := MeshInstance3D.new()
	pad.mesh = pad_mesh
	pad.position.y = 0.03
	pad.name = "HeliPad"
	add_child(pad)

	# Use a cylinder for the circle shape
	var circle_mesh := CylinderMesh.new()
	circle_mesh.top_radius = 3.0
	circle_mesh.bottom_radius = 3.0
	circle_mesh.height = 0.01
	circle_mesh.radial_segments = 32
	circle_mesh.material = pad_mat
	var circle := MeshInstance3D.new()
	circle.mesh = circle_mesh
	circle.position.y = 0.035
	circle.name = "HeliCircle"
	add_child(circle)

	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color(0.933, 0.933, 0.0)
	h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# H left bar
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.3, 0.02, 2.0)
	bar_mesh.material = h_mat
	var left_bar := MeshInstance3D.new()
	left_bar.mesh = bar_mesh
	left_bar.position = Vector3(-0.6, 0.04, 0.0)
	left_bar.name = "H_Left"
	add_child(left_bar)

	# H right bar
	var right_bar := MeshInstance3D.new()
	right_bar.mesh = bar_mesh
	right_bar.position = Vector3(0.6, 0.04, 0.0)
	right_bar.name = "H_Right"
	add_child(right_bar)

	# H cross bar
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(1.2, 0.02, 0.3)
	cross_mesh.material = h_mat
	var cross_bar := MeshInstance3D.new()
	cross_bar.mesh = cross_mesh
	cross_bar.position = Vector3(0.0, 0.04, 0.0)
	cross_bar.name = "H_Cross"
	add_child(cross_bar)

	# Yellow ring
	var ring := _make_ring(2.5, 2.7, 32, h_mat)
	ring.position.y = 0.04
	ring.name = "HeliRing"
	add_child(ring)

func _make_ring(inner_r: float, outer_r: float, segments: int, mat: StandardMaterial3D) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)

	for i in range(segments + 1):
		var angle := (float(i) / segments) * TAU
		var cos_a := cos(angle)
		var sin_a := sin(angle)
		im.surface_add_vertex(Vector3(inner_r * cos_a, 0, inner_r * sin_a))
		im.surface_add_vertex(Vector3(outer_r * cos_a, 0, outer_r * sin_a))

	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	return mi

func _create_buildings() -> void:
	var building_colors := [
		Color(0.533, 0.565, 0.6),
		Color(0.502, 0.565, 0.627),
		Color(0.478, 0.522, 0.584),
		Color(0.584, 0.627, 0.667),
		Color(0.627, 0.667, 0.69),
		Color(0.467, 0.502, 0.533),
	]
	var window_color := Color(0.733, 0.867, 1.0, 0.4)

	var clusters := [
		{"cx": 40, "cz": -30, "count": 8, "spread": 20, "minH": 5, "maxH": 20},
		{"cx": -35, "cz": -40, "count": 6, "spread": 15, "minH": 4, "maxH": 15},
		{"cx": 80, "cz": 20, "count": 10, "spread": 30, "minH": 8, "maxH": 35},
		{"cx": -70, "cz": 40, "count": 8, "spread": 25, "minH": 6, "maxH": 25},
		{"cx": 50, "cz": 100, "count": 12, "spread": 40, "minH": 10, "maxH": 45},
		{"cx": -100, "cz": -60, "count": 10, "spread": 35, "minH": 8, "maxH": 40},
		{"cx": 120, "cz": -80, "count": 8, "spread": 30, "minH": 12, "maxH": 50},
		{"cx": -40, "cz": 120, "count": 6, "spread": 20, "minH": 5, "maxH": 30},
	]

	# Seeded random for consistent layout
	var seed_val := 42
	var rand_fn := func() -> float:
		seed_val = (seed_val * 16807 + 0) % 2147483647
		return float(seed_val) / 2147483647.0

	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = window_color
	window_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for cluster in clusters:
		for i in range(cluster["count"]):
			var w: float = 3.0 + rand_fn.call() * 6.0
			var d: float = 3.0 + rand_fn.call() * 6.0
			var h: float = cluster["minH"] + rand_fn.call() * (cluster["maxH"] - cluster["minH"])

			var x: float = cluster["cx"] + (rand_fn.call() - 0.5) * cluster["spread"]
			var z: float = cluster["cz"] + (rand_fn.call() - 0.5) * cluster["spread"]

			var color: Color = building_colors[int(rand_fn.call() * building_colors.size()) % building_colors.size()]
			var bld_mesh := BoxMesh.new()
			bld_mesh.size = Vector3(w, h, d)
			var bld_mat := StandardMaterial3D.new()
			bld_mat.albedo_color = color
			bld_mesh.material = bld_mat
			var bld := MeshInstance3D.new()
			bld.mesh = bld_mesh
			bld.position = Vector3(x, h / 2.0, z)
			bld.name = "Building"
			add_child(bld)

			# Window strips
			if h > 8:
				var window_rows := int(h / 3.0)
				var strip_mesh := PlaneMesh.new()
				strip_mesh.size = Vector2(w * 0.8, 0.8)
				strip_mesh.material = window_mat
				for row in range(window_rows):
					var y := 2.0 + row * 3.0

					var front := MeshInstance3D.new()
					front.mesh = strip_mesh
					front.position = Vector3(x, y, z - d / 2.0 - 0.01)
					front.rotation.x = PI / 2.0
					front.name = "Window"
					add_child(front)

					var back := MeshInstance3D.new()
					back.mesh = strip_mesh
					back.position = Vector3(x, y, z + d / 2.0 + 0.01)
					back.rotation.x = PI / 2.0
					back.rotation.y = PI
					back.name = "Window"
					add_child(back)

func _create_trees() -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.267, 0.133)

	var leaf_mat1 := StandardMaterial3D.new()
	leaf_mat1.albedo_color = Color(0.2, 0.533, 0.2)

	var leaf_mat2 := StandardMaterial3D.new()
	leaf_mat2.albedo_color = Color(0.165, 0.478, 0.165)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 5
	trunk_mesh.material = trunk_mat

	var leaf_mesh := CylinderMesh.new()
	leaf_mesh.top_radius = 0.0
	leaf_mesh.bottom_radius = 1.5
	leaf_mesh.height = 3.0
	leaf_mesh.radial_segments = 6

	var seed_val := 99
	var rand_fn := func() -> float:
		seed_val = (seed_val * 16807 + 0) % 2147483647
		return float(seed_val) / 2147483647.0

	for i in range(60):
		var angle: float = rand_fn.call() * TAU
		var dist: float = 8.0 + rand_fn.call() * 80.0
		var x: float = cos(angle) * dist
		var z: float = sin(angle) * dist

		if absf(x) < 5.0 and absf(z) < 5.0:
			continue

		var tree_scale: float = 0.7 + rand_fn.call() * 0.8
		var tree := Node3D.new()
		tree.name = "Tree"

		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.position.y = 1.0
		trunk.scale = Vector3.ONE * tree_scale
		tree.add_child(trunk)

		var use_mat2: bool = rand_fn.call() > 0.5
		var lm := leaf_mesh.duplicate() as CylinderMesh
		lm.material = leaf_mat2 if use_mat2 else leaf_mat1
		var leaves := MeshInstance3D.new()
		leaves.mesh = lm
		leaves.position.y = 3.2 * tree_scale
		leaves.scale = Vector3.ONE * tree_scale
		tree.add_child(leaves)

		tree.position = Vector3(x, 0, z)
		add_child(tree)

func _create_clouds() -> void:
	var cloud_defs := [
		{"x": 40, "z": -60, "y": 50, "sx": 30, "sz": 15},
		{"x": -80, "z": -30, "y": 55, "sx": 25, "sz": 12},
		{"x": 100, "z": 40, "y": 48, "sx": 35, "sz": 18},
		{"x": -30, "z": 80, "y": 60, "sx": 20, "sz": 10},
		{"x": 60, "z": 100, "y": 52, "sx": 28, "sz": 14},
		{"x": -120, "z": -80, "y": 58, "sx": 32, "sz": 16},
		{"x": 20, "z": -120, "y": 45, "sx": 22, "sz": 11},
		{"x": -60, "z": 50, "y": 65, "sx": 40, "sz": 20},
		{"x": 130, "z": -40, "y": 50, "sx": 26, "sz": 13},
		{"x": -100, "z": 120, "y": 55, "sx": 30, "sz": 15},
	]

	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.no_depth_test = true

	var rng := RandomNumberGenerator.new()
	rng.seed = 123

	for c in cloud_defs:
		var group := Node3D.new()
		group.name = "Cloud"
		var puff_count := 3 + rng.randi_range(0, 2)
		for _j in range(puff_count):
			var puff_mesh := PlaneMesh.new()
			puff_mesh.size = Vector2(
				c["sx"] * (0.5 + rng.randf() * 0.5),
				c["sz"] * (0.5 + rng.randf() * 0.5)
			)
			puff_mesh.material = cloud_mat
			var puff := MeshInstance3D.new()
			puff.mesh = puff_mesh
			puff.position = Vector3(
				(rng.randf() - 0.5) * c["sx"] * 0.6,
				(rng.randf() - 0.5) * 2.0,
				(rng.randf() - 0.5) * c["sz"] * 0.6
			)
			# PlaneMesh faces up by default in Godot (Y+), which is correct for clouds
			group.add_child(puff)

		group.position = Vector3(c["x"], c["y"], c["z"])
		add_child(group)
