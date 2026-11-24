extends RefCounted

static func build_sculpted_car(body_color: Color, is_police: bool = false) -> Node3D:
	var root = Node3D.new()
	root.name = "CustomCarBody"

	var paint_mat = StandardMaterial3D.new()
	paint_mat.albedo_color = body_color
	paint_mat.metallic = 0.55
	paint_mat.roughness = 0.22

	var dark_trim = StandardMaterial3D.new()
	dark_trim.albedo_color = Color(0.08, 0.09, 0.11)
	dark_trim.roughness = 0.6

	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.07, 0.12, 0.18, 0.85)
	glass_mat.metallic = 0.85
	glass_mat.roughness = 0.12

	var white_door = StandardMaterial3D.new()
	white_door.albedo_color = Color(0.95, 0.96, 0.98)
	white_door.roughness = 0.3

	# 1. Lower wide chassis body
	add_box(root, Vector3(1.92, 0.46, 4.35), Vector3(0, 0.12, 0), paint_mat)
	# Front splitter & rear diffuser
	add_box(root, Vector3(1.96, 0.14, 0.35), Vector3(0, -0.06, 2.08), dark_trim)
	add_box(root, Vector3(1.94, 0.18, 0.32), Vector3(0, -0.04, -2.06), dark_trim)
	# Side skirts
	add_box(root, Vector3(2.0, 0.12, 2.5), Vector3(0, -0.06, 0.0), dark_trim)

	# Police white side doors
	if is_police:
		add_box(root, Vector3(1.95, 0.42, 1.55), Vector3(0, 0.13, 0.05), white_door)

	# 2. Sleek tapered fastback cabin + tinted windows
	var cabin = add_box(root, Vector3(1.56, 0.44, 1.95), Vector3(0, 0.52, -0.18), glass_mat)
	cabin.rotation.x = 0.06
	# Roof panel
	add_box(root, Vector3(1.48, 0.08, 1.35), Vector3(0, 0.74, -0.22), white_door if is_police else paint_mat)

	# 3. Rear GT wing spoiler
	add_box(root, Vector3(0.08, 0.24, 0.18), Vector3(-0.62, 0.44, -1.92), dark_trim)
	add_box(root, Vector3(0.08, 0.24, 0.18), Vector3(0.62, 0.44, -1.92), dark_trim)
	add_box(root, Vector3(1.86, 0.06, 0.28), Vector3(0, 0.56, -1.95), dark_trim if is_police else paint_mat)

	# 4. Side mirrors
	add_box(root, Vector3(0.22, 0.10, 0.14), Vector3(-1.04, 0.42, 0.58), paint_mat)
	add_box(root, Vector3(0.22, 0.10, 0.14), Vector3(1.04, 0.42, 0.58), paint_mat)

	# 5. Glowing LED headlights & taillights
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(1.0, 0.98, 0.88)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.96, 0.82)
	head_mat.emission_energy_multiplier = 2.6

	var tail_mat = StandardMaterial3D.new()
	tail_mat.albedo_color = Color(1.0, 0.12, 0.12)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.08, 0.08)
	tail_mat.emission_energy_multiplier = 2.4

	add_box(root, Vector3(0.42, 0.11, 0.08), Vector3(-0.64, 0.18, 2.16), head_mat)
	add_box(root, Vector3(0.42, 0.11, 0.08), Vector3(0.64, 0.18, 2.16), head_mat)
	add_box(root, Vector3(1.68, 0.11, 0.08), Vector3(0.0, 0.22, -2.16), tail_mat)

	return root

static func style_wheels(car_node: Node):
	var rim_mat = StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.82, 0.85, 0.90)
	rim_mat.metallic = 0.85
	rim_mat.roughness = 0.2
	for child in car_node.get_children():
		if child is VehicleWheel3D:
			var rim = MeshInstance3D.new()
			var cyl = CylinderMesh.new()
			cyl.top_radius = 0.23
			cyl.bottom_radius = 0.23
			cyl.height = 0.28
			rim.mesh = cyl
			rim.rotation.z = PI * 0.5
			rim.material_override = rim_mat
			child.add_child(rim)

static func add_box(parent: Node3D, sz: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
