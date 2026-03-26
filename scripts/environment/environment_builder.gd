class_name EnvironmentBuilder
extends Node3D

func build() -> void:
	_create_ground()
	_create_grids()
	_create_helipad()
	_create_buildings()
	_create_trees()
	_create_gates()
	_create_hoops()
	_create_slalom_poles()
	_create_floating_platforms()
	_create_tunnel()
	_create_pillars()
	_create_poles()
	_create_pole_wires()
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

			# StaticBody3D wrapper for collision
			var body := StaticBody3D.new()
			body.name = "Building"
			body.position = Vector3(x, h / 2.0, z)
			body.collision_layer = 1
			body.collision_mask = 0
			body.set_meta("obstacle_type", "building")

			var col_shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(w, h, d)
			col_shape.shape = box_shape
			body.add_child(col_shape)

			var bld_mesh := BoxMesh.new()
			bld_mesh.size = Vector3(w, h, d)
			var bld_mat := StandardMaterial3D.new()
			bld_mat.albedo_color = color
			bld_mesh.material = bld_mat
			var bld := MeshInstance3D.new()
			bld.mesh = bld_mesh
			body.add_child(bld)

			add_child(body)

			# Window strips (cosmetic, direct children of environment)
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

		# StaticBody3D wrapper for collision
		var body := StaticBody3D.new()
		body.name = "Tree"
		body.position = Vector3(x, 0, z)
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("obstacle_type", "tree")

		var tree_height: float = (3.2 + 1.5) * tree_scale
		var col_shape := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = 1.5 * tree_scale
		cyl_shape.height = tree_height
		col_shape.shape = cyl_shape
		col_shape.position.y = tree_height / 2.0
		body.add_child(col_shape)

		var tree := Node3D.new()
		tree.name = "TreeVisual"

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

		body.add_child(tree)
		add_child(body)

func _create_gates() -> void:
	# Per-gate definitions with varied sizes
	var gate_defs := [
		{"pos": Vector3(15, 0, 0), "rot": 0.0, "w": 5.0, "h": 6.0},
		{"pos": Vector3(20, 0, -18), "rot": PI / 4.0, "w": 4.0, "h": 5.0},
		{"pos": Vector3(10, 0, -30), "rot": PI / 2.0, "w": 3.5, "h": 4.5},
		{"pos": Vector3(-15, 0, -20), "rot": -PI / 4.0, "w": 3.0, "h": 4.0},
		{"pos": Vector3(-25, 0, 5), "rot": -PI / 2.0, "w": 3.0, "h": 4.0},
		{"pos": Vector3(-10, 0, 20), "rot": PI, "w": 5.0, "h": 6.0},
	]

	# Ground ring material (orange translucent)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.6, 0.0, 0.3)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var pole_radius := 0.15
	var crossbar_height := 0.15

	for i in range(gate_defs.size()):
		var gd: Dictionary = gate_defs[i]
		var gate_width: float = gd["w"]
		var pole_height: float = gd["h"]

		# Color by difficulty: green >= 4.5m, orange medium, red <= 3.0m
		var gate_color: Color
		if gate_width >= 4.5:
			gate_color = Color(0.0, 1.0, 0.3)
		elif gate_width <= 3.0:
			gate_color = Color(1.0, 0.15, 0.1)
		else:
			gate_color = Color(1.0, 0.6, 0.0)

		var gate_mat := StandardMaterial3D.new()
		gate_mat.albedo_color = gate_color
		gate_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gate_mat.emission_enabled = true
		gate_mat.emission = gate_color
		gate_mat.emission_energy_multiplier = 1.5

		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = pole_radius
		pole_mesh.bottom_radius = pole_radius
		pole_mesh.height = pole_height
		pole_mesh.radial_segments = 8
		pole_mesh.material = gate_mat

		var crossbar_mesh := BoxMesh.new()
		crossbar_mesh.size = Vector3(gate_width, crossbar_height, crossbar_height)
		crossbar_mesh.material = gate_mat

		var gate_group := Node3D.new()
		gate_group.name = "Gate_%d" % (i + 1)
		gate_group.position = gd["pos"]
		gate_group.rotation.y = gd["rot"]

		# Left pole
		var left_body := StaticBody3D.new()
		left_body.name = "GatePoleL"
		left_body.position = Vector3(-gate_width / 2.0, pole_height / 2.0, 0)
		left_body.collision_layer = 1
		left_body.collision_mask = 0
		left_body.set_meta("obstacle_type", "gate")
		var left_col := CollisionShape3D.new()
		var left_shape := CylinderShape3D.new()
		left_shape.radius = pole_radius
		left_shape.height = pole_height
		left_col.shape = left_shape
		left_body.add_child(left_col)
		var left_mesh := MeshInstance3D.new()
		left_mesh.mesh = pole_mesh
		left_body.add_child(left_mesh)
		gate_group.add_child(left_body)

		# Right pole
		var right_body := StaticBody3D.new()
		right_body.name = "GatePoleR"
		right_body.position = Vector3(gate_width / 2.0, pole_height / 2.0, 0)
		right_body.collision_layer = 1
		right_body.collision_mask = 0
		right_body.set_meta("obstacle_type", "gate")
		var right_col := CollisionShape3D.new()
		var right_shape := CylinderShape3D.new()
		right_shape.radius = pole_radius
		right_shape.height = pole_height
		right_col.shape = right_shape
		right_body.add_child(right_col)
		var right_mesh := MeshInstance3D.new()
		right_mesh.mesh = pole_mesh
		right_body.add_child(right_mesh)
		gate_group.add_child(right_body)

		# Crossbar
		var cross_body := StaticBody3D.new()
		cross_body.name = "GateCrossbar"
		cross_body.position = Vector3(0, pole_height, 0)
		cross_body.collision_layer = 1
		cross_body.collision_mask = 0
		cross_body.set_meta("obstacle_type", "gate")
		var cross_col := CollisionShape3D.new()
		var cross_shape := BoxShape3D.new()
		cross_shape.size = Vector3(gate_width, crossbar_height, crossbar_height)
		cross_col.shape = cross_shape
		cross_body.add_child(cross_col)
		var cross_mesh_inst := MeshInstance3D.new()
		cross_mesh_inst.mesh = crossbar_mesh
		cross_body.add_child(cross_mesh_inst)
		gate_group.add_child(cross_body)

		# Ground ring below gate
		var ground_ring := _make_ring(1.8, 2.2, 24, ring_mat)
		ground_ring.position.y = 0.04
		ground_ring.name = "GateGroundRing"
		gate_group.add_child(ground_ring)

		# Gate number label above crossbar
		var label := Label3D.new()
		label.text = str(i + 1)
		label.font_size = 72
		label.position = Vector3(0, pole_height + 0.8, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1.0, 1.0, 1.0)
		label.outline_modulate = Color(0, 0, 0)
		label.outline_size = 8
		label.no_depth_test = true
		label.name = "GateLabel"
		gate_group.add_child(label)

		add_child(gate_group)

func _make_hoop(pos: Vector3, opening_diam: float, y_rot: float, tilt: float, color: Color, label_text: String) -> Node3D:
	var group := Node3D.new()
	group.name = label_text
	group.position = pos
	group.rotation.y = y_rot

	var tube_radius := 0.25
	var inner_r := opening_diam / 2.0
	var outer_r := inner_r + tube_radius * 2.0
	var ring_center_r := (inner_r + outer_r) / 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2

	# Ring container — rotated so hole faces Z (flythrough direction)
	var ring_node := Node3D.new()
	ring_node.rotation.x = PI / 2.0 + tilt

	var torus := TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 24
	torus.ring_segments = 12
	torus.material = mat

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = torus
	ring_node.add_child(mesh_inst)

	# 12 collision spheres around the tube circumference
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var body := StaticBody3D.new()
		body.name = "HoopCol_%d" % i
		body.position = Vector3(cos(angle) * ring_center_r, 0, sin(angle) * ring_center_r)
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("obstacle_type", "hoop")
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = tube_radius * 1.5
		col.shape = sphere
		body.add_child(col)
		ring_node.add_child(body)

	group.add_child(ring_node)

	# Label above hoop
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 48
	label.position = Vector3(0, inner_r + tube_radius * 2.0 + 0.8, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0)
	label.outline_size = 8
	label.no_depth_test = true
	label.name = "HoopLabel"
	group.add_child(label)

	return group

func _create_hoops() -> void:
	var hoop_defs := [
		{"pos": Vector3(30, 3, 15), "opening": 4.5, "tilt": 0.0, "tier": "easy"},
		{"pos": Vector3(40, 5, 0), "opening": 4.5, "tilt": 0.05, "tier": "easy"},
		{"pos": Vector3(35, 7, -20), "opening": 3.5, "tilt": 0.1, "tier": "medium"},
		{"pos": Vector3(20, 9, -40), "opening": 3.2, "tilt": -0.1, "tier": "medium"},
		{"pos": Vector3(0, 12, -55), "opening": 2.6, "tilt": 0.15, "tier": "hard"},
		{"pos": Vector3(-20, 10, -45), "opening": 2.4, "tilt": -0.15, "tier": "hard"},
		{"pos": Vector3(-35, 8, -30), "opening": 3.5, "tilt": 0.1, "tier": "medium"},
		{"pos": Vector3(-40, 6, -10), "opening": 3.2, "tilt": -0.05, "tier": "medium"},
		{"pos": Vector3(-30, 4, 10), "opening": 4.5, "tilt": 0.0, "tier": "easy"},
		{"pos": Vector3(-15, 3, 25), "opening": 4.5, "tilt": 0.0, "tier": "easy"},
	]

	var tier_colors := {
		"easy": Color(0.0, 0.9, 0.9),
		"medium": Color(1.0, 0.9, 0.0),
		"hard": Color(1.0, 0.35, 0.1),
	}

	for i in range(hoop_defs.size()):
		var hd: Dictionary = hoop_defs[i]
		var pos: Vector3 = hd["pos"]
		var next_pos: Vector3
		if i < hoop_defs.size() - 1:
			next_pos = hoop_defs[i + 1]["pos"]
		else:
			next_pos = hoop_defs[0]["pos"]

		# Y-rotation faces the next hoop
		var dir := next_pos - pos
		var y_rot := atan2(dir.x, dir.z)

		var color: Color = tier_colors[hd["tier"]]
		var hoop := _make_hoop(pos, hd["opening"], y_rot, hd["tilt"], color, "H%d" % (i + 1))
		add_child(hoop)

func _create_slalom_poles() -> void:
	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(0.9, 0.1, 0.1)
	red_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var white_mat := StandardMaterial3D.new()
	white_mat.albedo_color = Color(1.0, 1.0, 1.0)
	white_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i in range(8):
		var x: float = 50.0 + i * 7.0
		var z: float = -40.0 if i % 2 == 0 else -35.0

		var body := StaticBody3D.new()
		body.name = "SlalomPole_%d" % (i + 1)
		body.position = Vector3(x, 4.0, z)
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("obstacle_type", "slalom_pole")

		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.3
		shape.height = 8.0
		col.shape = shape
		body.add_child(col)

		# Barber-pole striping: 4 alternating red/white segments
		var seg_height := 2.0
		for s in range(4):
			var seg_mesh := CylinderMesh.new()
			seg_mesh.top_radius = 0.3
			seg_mesh.bottom_radius = 0.3
			seg_mesh.height = seg_height
			seg_mesh.radial_segments = 8
			seg_mesh.material = red_mat if s % 2 == 0 else white_mat
			var seg := MeshInstance3D.new()
			seg.mesh = seg_mesh
			seg.position.y = -3.0 + s * 2.0
			body.add_child(seg)

		# Red sphere cap on top
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.4
		cap_mesh.height = 0.8
		cap_mesh.material = red_mat
		var cap := MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.position.y = 4.3
		body.add_child(cap)

		add_child(body)

func _create_floating_platforms() -> void:
	var plat_defs := [
		{"pos": Vector3(-50, 6, -10), "size": Vector2(8, 6)},
		{"pos": Vector3(-50, 10, -10), "size": Vector2(8, 6)},
		{"pos": Vector3(20, 8, 45), "size": Vector2(10, 8)},
		{"pos": Vector3(45, 10, 55), "size": Vector2(7, 7)},
		{"pos": Vector3(60, 15, 50), "size": Vector2(6, 6)},
		{"pos": Vector3(-30, 12, 40), "size": Vector2(9, 5)},
	]

	var plat_mat := StandardMaterial3D.new()
	plat_mat.albedo_color = Color(0.5, 0.5, 0.55)

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.0, 0.8, 0.9)
	trim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(0.0, 0.8, 0.9)
	trim_mat.emission_energy_multiplier = 1.5

	var thickness := 0.3
	var trim_h := 0.08
	var trim_w := 0.1

	for i in range(plat_defs.size()):
		var pd: Dictionary = plat_defs[i]
		var pos: Vector3 = pd["pos"]
		var sz: Vector2 = pd["size"]

		var body := StaticBody3D.new()
		body.name = "Platform_%d" % (i + 1)
		body.position = pos
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("obstacle_type", "floating_platform")

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(sz.x, thickness, sz.y)
		col.shape = shape
		body.add_child(col)

		var mesh := BoxMesh.new()
		mesh.size = Vector3(sz.x, thickness, sz.y)
		mesh.material = plat_mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)

		# Cyan edge trim strips — front/back (along X)
		for side in [-1.0, 1.0]:
			var fb_mesh := BoxMesh.new()
			fb_mesh.size = Vector3(sz.x, trim_h, trim_w)
			fb_mesh.material = trim_mat
			var fb := MeshInstance3D.new()
			fb.mesh = fb_mesh
			fb.position = Vector3(0, -thickness / 2.0 - trim_h / 2.0, side * sz.y / 2.0)
			body.add_child(fb)

		# Left/right (along Z)
		for side in [-1.0, 1.0]:
			var lr_mesh := BoxMesh.new()
			lr_mesh.size = Vector3(trim_w, trim_h, sz.y)
			lr_mesh.material = trim_mat
			var lr := MeshInstance3D.new()
			lr.mesh = lr_mesh
			lr.position = Vector3(side * sz.x / 2.0, -thickness / 2.0 - trim_h / 2.0, 0)
			body.add_child(lr)

		add_child(body)

func _create_tunnel() -> void:
	var tunnel_origin := Vector3(70, 0, 30)
	var tunnel_angle := deg_to_rad(-30.0)
	var arch_spacing := 6.0
	var arch_width := 4.0
	var arch_height := 5.0
	var beam_thickness := 0.4

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.55, 0.6)

	var hazard_mat := StandardMaterial3D.new()
	hazard_mat.albedo_color = Color(0.9, 0.8, 0.0)
	hazard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hazard_mat.emission_enabled = true
	hazard_mat.emission = Color(0.9, 0.8, 0.0)
	hazard_mat.emission_energy_multiplier = 1.0

	var tunnel_group := Node3D.new()
	tunnel_group.name = "Tunnel"
	tunnel_group.position = tunnel_origin
	tunnel_group.rotation.y = tunnel_angle

	for i in range(5):
		var z_off := float(i) * arch_spacing

		# Left pillar
		_add_tunnel_beam(tunnel_group,
			Vector3(-arch_width / 2.0, arch_height / 2.0, z_off),
			Vector3(beam_thickness, arch_height, beam_thickness), wall_mat)

		# Right pillar
		_add_tunnel_beam(tunnel_group,
			Vector3(arch_width / 2.0, arch_height / 2.0, z_off),
			Vector3(beam_thickness, arch_height, beam_thickness), wall_mat)

		# Top lintel
		_add_tunnel_beam(tunnel_group,
			Vector3(0, arch_height, z_off),
			Vector3(arch_width + beam_thickness, beam_thickness, beam_thickness), wall_mat)

		# Hazard stripes on inner edges
		var stripe_h := 0.1
		var stripe_w := 0.05

		# Left inner stripe
		var v_stripe_mesh := BoxMesh.new()
		v_stripe_mesh.size = Vector3(stripe_w, arch_height, stripe_h)
		v_stripe_mesh.material = hazard_mat
		var left_stripe := MeshInstance3D.new()
		left_stripe.mesh = v_stripe_mesh
		left_stripe.position = Vector3(
			-arch_width / 2.0 + beam_thickness / 2.0 + stripe_w / 2.0,
			arch_height / 2.0, z_off)
		tunnel_group.add_child(left_stripe)

		# Right inner stripe
		var right_stripe := MeshInstance3D.new()
		right_stripe.mesh = v_stripe_mesh
		right_stripe.position = Vector3(
			arch_width / 2.0 - beam_thickness / 2.0 - stripe_w / 2.0,
			arch_height / 2.0, z_off)
		tunnel_group.add_child(right_stripe)

		# Bottom of lintel stripe
		var h_stripe_mesh := BoxMesh.new()
		h_stripe_mesh.size = Vector3(arch_width, stripe_w, stripe_h)
		h_stripe_mesh.material = hazard_mat
		var top_stripe := MeshInstance3D.new()
		top_stripe.mesh = h_stripe_mesh
		top_stripe.position = Vector3(0,
			arch_height - beam_thickness / 2.0 - stripe_w / 2.0, z_off)
		tunnel_group.add_child(top_stripe)

	add_child(tunnel_group)

func _add_tunnel_beam(parent: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.name = "TunnelBeam"
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("obstacle_type", "tunnel_wall")

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)

	parent.add_child(body)

func _create_pillars() -> void:
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.6, 0.2, 0.3)

	var pillar_defs := [
		{"pos": Vector3(-5, 0, -65), "h": 15.0, "r": 0.5, "floating": false},
		{"pos": Vector3(5, 0, -70), "h": 18.0, "r": 0.4, "floating": false},
		{"pos": Vector3(-3, 0, -75), "h": 12.0, "r": 0.6, "floating": false},
		{"pos": Vector3(8, 0, -68), "h": 20.0, "r": 0.35, "floating": false},
		{"pos": Vector3(-8, 0, -72), "h": 14.0, "r": 0.45, "floating": false},
		{"pos": Vector3(2, 0, -78), "h": 10.0, "r": 0.55, "floating": false},
		{"pos": Vector3(0, 8, -67), "h": 6.0, "r": 0.4, "floating": true},
		{"pos": Vector3(-6, 10, -73), "h": 5.0, "r": 0.35, "floating": true},
	]

	for i in range(pillar_defs.size()):
		var pd: Dictionary = pillar_defs[i]
		var h: float = pd["h"]
		var r: float = pd["r"]
		var is_floating: bool = pd["floating"]
		var base_pos: Vector3 = pd["pos"]

		var body := StaticBody3D.new()
		body.name = "Pillar_%d" % (i + 1)
		if is_floating:
			body.position = base_pos
		else:
			body.position = Vector3(base_pos.x, h / 2.0, base_pos.z)
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("obstacle_type", "pillar")

		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = h
		col.shape = shape
		body.add_child(col)

		var mesh := CylinderMesh.new()
		mesh.top_radius = r
		mesh.bottom_radius = r
		mesh.height = h
		mesh.radial_segments = 10
		mesh.material = pillar_mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		body.add_child(mi)

		add_child(body)

func _create_poles() -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.45, 0.35, 0.25)

	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color(0.45, 0.35, 0.25)

	var main_radius := 0.2
	var main_height := 12.0
	var arm_width := 4.0
	var arm_height := 0.15

	var main_mesh := CylinderMesh.new()
	main_mesh.top_radius = main_radius
	main_mesh.bottom_radius = main_radius
	main_mesh.height = main_height
	main_mesh.radial_segments = 8
	main_mesh.material = pole_mat

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(arm_width, arm_height, arm_height)
	arm_mesh.material = arm_mat

	# 8 poles in a line
	for i in range(8):
		var x: float = -60.0 + i * 10.0
		var z: float = 50.0

		var pole_group := Node3D.new()
		pole_group.name = "PowerPole"
		pole_group.position = Vector3(x, 0, z)

		# Main pole
		var main_body := StaticBody3D.new()
		main_body.name = "PoleMain"
		main_body.position = Vector3(0, main_height / 2.0, 0)
		main_body.collision_layer = 1
		main_body.collision_mask = 0
		main_body.set_meta("obstacle_type", "pole")
		var main_col := CollisionShape3D.new()
		var main_shape := CylinderShape3D.new()
		main_shape.radius = main_radius
		main_shape.height = main_height
		main_col.shape = main_shape
		main_body.add_child(main_col)
		var main_mesh_inst := MeshInstance3D.new()
		main_mesh_inst.mesh = main_mesh
		main_body.add_child(main_mesh_inst)
		pole_group.add_child(main_body)

		# Cross-arm at top
		var arm_body := StaticBody3D.new()
		arm_body.name = "PoleArm"
		arm_body.position = Vector3(0, main_height - 0.5, 0)
		arm_body.collision_layer = 1
		arm_body.collision_mask = 0
		arm_body.set_meta("obstacle_type", "pole")
		var arm_col := CollisionShape3D.new()
		var arm_shape := BoxShape3D.new()
		arm_shape.size = Vector3(arm_width, arm_height, arm_height)
		arm_col.shape = arm_shape
		arm_body.add_child(arm_col)
		var arm_mesh_inst := MeshInstance3D.new()
		arm_mesh_inst.mesh = arm_mesh
		arm_body.add_child(arm_mesh_inst)
		pole_group.add_child(arm_body)

		add_child(pole_group)

func _create_pole_wires() -> void:
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.15, 0.15, 0.15)
	wire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var main_height := 12.0
	var arm_width := 4.0
	var arm_y := main_height - 0.5

	# Wire attachment points relative to each pole position:
	# left arm tip, right arm tip, center top
	var attach_offsets := [
		Vector3(-arm_width / 2.0, arm_y, 0),  # left arm tip
		Vector3(arm_width / 2.0, arm_y, 0),   # right arm tip
		Vector3(0, main_height, 0),            # center top
	]

	# 8 poles in a line, wires connect consecutive poles (7 spans)
	var catenary_segments := 12
	var sag := 1.5  # meters of wire droop

	for span in range(7):
		var x_start: float = -60.0 + span * 10.0
		var x_end: float = x_start + 10.0
		var z: float = 50.0

		for wire_idx in range(3):
			var offset: Vector3 = attach_offsets[wire_idx]
			var start_pos := Vector3(x_start + offset.x, offset.y, z + offset.z)
			var end_pos := Vector3(x_end + offset.x, offset.y, z + offset.z)

			# Visual wire with catenary sag
			var im := ImmediateMesh.new()
			im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, wire_mat)
			for seg in range(catenary_segments + 1):
				var t := float(seg) / catenary_segments
				var p := start_pos.lerp(end_pos, t)
				# Parabolic sag: max at t=0.5
				p.y -= sag * 4.0 * t * (1.0 - t)
				im.surface_add_vertex(p)
			im.surface_end()
			var wire_mesh := MeshInstance3D.new()
			wire_mesh.mesh = im
			wire_mesh.name = "Wire_%d_%d" % [span, wire_idx]
			add_child(wire_mesh)

			# Collision: box along the wire span center
			var mid_pos := (start_pos + end_pos) * 0.5
			mid_pos.y -= sag  # sag at midpoint
			var span_len := start_pos.distance_to(end_pos)

			var wire_body := StaticBody3D.new()
			wire_body.name = "WireCollider_%d_%d" % [span, wire_idx]
			wire_body.position = mid_pos
			wire_body.collision_layer = 1
			wire_body.collision_mask = 0
			wire_body.set_meta("obstacle_type", "wire")
			var wire_col := CollisionShape3D.new()
			var wire_shape := BoxShape3D.new()
			wire_shape.size = Vector3(span_len, 0.3, 0.3)
			wire_col.shape = wire_shape
			wire_body.add_child(wire_col)
			add_child(wire_body)

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
