extends RefCounted

static func load_fitted_glb(res_path: String, target_height: float, bottom_y: float = 0.0, rot_y: float = 0.0, align_length_to_z: bool = false, tint_paint: Color = Color(-1, -1, -1)) -> Node3D:
	var raw: Node = null

	if ResourceLoader.exists(res_path):
		var packed = load(res_path)
		if packed is PackedScene:
			raw = packed.instantiate()

	if raw == null and FileAccess.file_exists(res_path):
		var bytes = FileAccess.get_file_as_bytes(res_path)
		if bytes.size() > 0:
			var doc = GLTFDocument.new()
			var state = GLTFState.new()
			if doc.append_from_buffer(bytes, "", state) == OK:
				raw = doc.generate_scene(state)

	if raw == null:
		return null

	var aabb = get_mesh_aabb(raw)
	if aabb.size.length() <= 0.001:
		return raw

	var final_rot_y = rot_y
	if align_length_to_z and aabb.size.x > aabb.size.z * 1.15:
		final_rot_y += PI * 0.5

	# For vehicles (align_length_to_z), scale by real car length (4.45m) so giant/tiny exports always match wheelbase
	var s = 1.0
	if align_length_to_z:
		var horiz_len = max(aabb.size.x, aabb.size.z)
		s = 4.45 / max(horiz_len, 0.001)
	else:
		s = target_height / max(aabb.size.y, 0.001)

	var pivot = Node3D.new()
	var holder = Node3D.new()
	holder.rotation.y = final_rot_y

	raw.scale = Vector3(s, s, s)
	var center_x = (aabb.position.x + aabb.size.x * 0.5) * s
	var center_z = (aabb.position.z + aabb.size.z * 0.5) * s
	var min_y = aabb.position.y * s
	raw.position = Vector3(-center_x, bottom_y - min_y, -center_z)

	fix_materials(raw, tint_paint)
	holder.add_child(raw)
	pivot.add_child(holder)
	return pivot

static func fix_materials(node: Node, tint_paint: Color):
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(i)
			if mat is StandardMaterial3D:
				var m = mat.duplicate()
				m.metallic = clamp(m.metallic, 0.0, 0.35)
				m.roughness = clamp(m.roughness, 0.25, 0.85)
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				if tint_paint.r >= 0.0 and m.albedo_texture == null:
					if m.albedo_color.get_luminance() > 0.18 and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
						m.albedo_color = tint_paint
				node.set_surface_override_material(i, m)
	for c in node.get_children():
		fix_materials(c, tint_paint)

static func get_mesh_aabb(root: Node) -> AABB:
	var box = AABB()
	var first = true
	var stack = [[root, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var item = stack.pop_back()
		var n: Node = item[0]
		var xform: Transform3D = item[1]
		if n is Node3D and n != root:
			xform = xform * n.transform
		if n is MeshInstance3D and n.mesh:
			var a = xform * n.get_aabb()
			if first:
				box = a
				first = false
			else:
				box = box.merge(a)
		for c in n.get_children():
			stack.append([c, xform])
	return box
