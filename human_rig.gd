extends Node3D

var anim_player: AnimationPlayer = null
var model_inst: Node3D = null
var walk_phase: float = 0.0

static var cached_scenes: Dictionary = {}

func get_cached_human(res_path: String) -> Node3D:
	if cached_scenes.has(res_path) and is_instance_valid(cached_scenes[res_path]):
		return cached_scenes[res_path].duplicate()
	var scene: Node = null
	if ResourceLoader.exists(res_path):
		var packed = load(res_path)
		if packed is PackedScene:
			scene = packed.instantiate()
	if scene == null and FileAccess.file_exists(res_path):
		var bytes = FileAccess.get_file_as_bytes(res_path)
		if bytes.size() > 0:
			var doc = GLTFDocument.new()
			var state = GLTFState.new()
			if doc.append_from_buffer(bytes, res_path.get_base_dir() + "/", state) == OK:
				scene = doc.generate_scene(state)
	if scene:
		cached_scenes[res_path] = scene
		return scene.duplicate()
	return null

func fix_and_tint_materials(node: Node, shirt_color: Color, is_player: bool):
	if node is MeshInstance3D and node.mesh:
		for s in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(s)
			if mat is StandardMaterial3D:
				var m = mat.duplicate()
				m.metallic = 0.0
				m.roughness = clamp(m.roughness, 0.55, 0.9)
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				if m.albedo_texture == null:
					m.albedo_color = shirt_color
				elif not is_player:
					# Tint NPCs/Cops/Gangsters/Guards by role while preserving human skin/clothes
					m.albedo_color = Color(1.05, 1.05, 1.05).lerp(shirt_color, 0.35)
				else:
					# Tint player outfit subtly for Franklin (green), Michael (blue), Trevor (grey)
					m.albedo_color = Color(1.08, 1.08, 1.08).lerp(shirt_color, 0.25)
				node.set_surface_override_material(s, m)
	for c in node.get_children():
		fix_and_tint_materials(c, shirt_color, is_player)

func build_human(shirt_color: Color, _pants_color: Color, is_player: bool = false):
	for c in get_children():
		c.queue_free()

	# Player uses real human idle.glb (cached once); NPCs/Cops/Guards use real human npc1.glb (cached once)
	var path = "res://models/idle.glb" if is_player else "res://models/npc1.glb"
	model_inst = get_cached_human(path)
	if model_inst == null:
		model_inst = get_cached_human("res://models/idle.glb")
	if model_inst == null:
		return

	fix_and_tint_materials(model_inst, shirt_color, is_player)
	var pivot = Node3D.new()
	add_child(pivot)
	pivot.add_child(model_inst)

	var aabb = get_combined_aabb(model_inst)
	if aabb.size.y > 0.001 and aabb.size.y < 500.0:
		var s = 1.78 / aabb.size.y
		model_inst.scale = Vector3(s, s, s)
		var cx = (aabb.position.x + aabb.size.x * 0.5) * s
		var cz = (aabb.position.z + aabb.size.z * 0.5) * s
		var min_y = aabb.position.y * s
		model_inst.position = Vector3(-cx, -0.90 - min_y, -cz)
	else:
		# Safe fallback scale if bone AABB is uninitialized
		model_inst.scale = Vector3(0.01, 0.01, 0.01)
		model_inst.position = Vector3(0, -0.90, 0)

	anim_player = find_anim_player(model_inst)
	if anim_player:
		var list = anim_player.get_animation_list()
		for anim_name in list:
			var lower = str(anim_name).to_lower()
			if "tpose" in lower or "take 001" in lower:
				continue
			var a = anim_player.get_animation(anim_name)
			if a and a.length > 0.1:
				var dup = a.duplicate()
				dup.loop_mode = Animation.LOOP_LINEAR
				strip_horizontal_root_motion(dup)
				var lib = anim_player.get_animation_library("")
				if lib == null:
					lib = AnimationLibrary.new()
					anim_player.add_animation_library("", lib)
				lib.add_animation("idle_loop", dup)
				anim_player.play("idle_loop")
				break

func strip_horizontal_root_motion(anim: Animation):
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var path_str = str(anim.track_get_path(t)).to_lower()
			if "hips" in path_str or "root" in path_str or "pelvis" in path_str:
				if anim.track_get_key_count(t) > 0:
					var first_pos: Vector3 = anim.track_get_key_value(t, 0)
					for k in range(anim.track_get_key_count(t)):
						var pos: Vector3 = anim.track_get_key_value(t, k)
						anim.track_set_key_value(t, k, Vector3(first_pos.x, pos.y, first_pos.z))

func get_combined_aabb(node: Node) -> AABB:
	var box = AABB()
	var first = true
	var stack = [node]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is VisualInstance3D:
			var a = n.get_aabb()
			if first:
				box = a
				first = false
			else:
				box = box.merge(a)
		for c in n.get_children():
			stack.append(c)
	return box

func find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for c in node.get_children():
		var found = find_anim_player(c)
		if found: return found
	return null

func animate_walk(speed: float, delta: float, _holding_gun: bool = false):
	if speed > 0.2:
		walk_phase += delta * speed * 2.2
		position.y = abs(sin(walk_phase)) * 0.045
		rotation.z = sin(walk_phase) * 0.035
	else:
		position.y = lerp(position.y, 0.0, 10.0 * delta)
		rotation.z = lerp(rotation.z, 0.0, 10.0 * delta)
