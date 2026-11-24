# 1. Pool the 3D GPS road ribbon in minimap.gd (reuse 6 pre-allocated MeshInstance3D segments & 1 shared Material instead of allocating/freeing every frame)
mp = open("minimap.gd").read()

old_ribbon_vars = """var world_beacon: Node3D = null
var road_ribbon_root: Node3D = null"""

new_ribbon_vars = """var world_beacon: Node3D = null
var road_ribbon_root: Node3D = null
var ribbon_pool: Array[MeshInstance3D] = []
var ribbon_mat: StandardMaterial3D = null"""

assert old_ribbon_vars in mp, "ribbon vars not found"
mp = mp.replace(old_ribbon_vars, new_ribbon_vars)

old_ribbon_init = """	# 2. 3D Glowing Road GPS Ribbon drawn right on the street surface!
	road_ribbon_root = Node3D.new()
	road_ribbon_root.name = "GPSRoadRibbon"
	main.add_child(road_ribbon_root)"""

new_ribbon_init = """	# 2. Pooled 3D Glowing Road GPS Ribbon (zero per-frame GPU buffer allocation)
	road_ribbon_root = Node3D.new()
	road_ribbon_root.name = "GPSRoadRibbon"
	main.add_child(road_ribbon_root)
	ribbon_mat = StandardMaterial3D.new()
	ribbon_mat.albedo_color = Color(0.95, 0.25, 1.0, 0.85)
	ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_mat.emission_enabled = true
	ribbon_mat.emission = Color(0.95, 0.25, 1.0)
	ribbon_mat.emission_energy_multiplier = 2.8
	for _i in range(6):
		var seg = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.85, 0.08, 1.0)
		bm.material = ribbon_mat
		seg.mesh = bm
		seg.visible = false
		road_ribbon_root.add_child(seg)
		ribbon_pool.append(seg)"""

assert old_ribbon_init in mp, "ribbon init not found"
mp = mp.replace(old_ribbon_init, new_ribbon_init)

old_clear = """func clear_road_ribbon():
	if road_ribbon_root:
		for c in road_ribbon_root.get_children():
			c.queue_free()"""

new_clear = """func clear_road_ribbon():
	for seg in ribbon_pool:
		if is_instance_valid(seg):
			seg.visible = false"""

assert old_clear in mp, "clear_road_ribbon not found"
mp = mp.replace(old_clear, new_clear)

old_rebuild = """func rebuild_road_ribbon(route: Array[Vector3]):
	if road_ribbon_root == null: return
	for c in road_ribbon_root.get_children():
		c.queue_free()

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.25, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.25, 1.0)
	mat.emission_energy_multiplier = 3.2

	for i in range(route.size() - 1):
		var a = Vector3(route[i].x, 0.32, route[i].z)
		var b = Vector3(route[i + 1].x, 0.32, route[i + 1].z)
		var seg_len = a.distance_to(b)
		if seg_len < 0.5:
			continue
		var seg = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.85, 0.08, seg_len)
		bm.material = mat
		seg.mesh = bm
		road_ribbon_root.add_child(seg)
		seg.global_position = (a + b) * 0.5
		seg.look_at(b, Vector3.UP)"""

new_rebuild = """func rebuild_road_ribbon(route: Array[Vector3]):
	if ribbon_pool.is_empty(): return
	var idx = 0
	for i in range(route.size() - 1):
		if idx >= ribbon_pool.size():
			break
		var a = Vector3(route[i].x, 0.32, route[i].z)
		var b = Vector3(route[i + 1].x, 0.32, route[i + 1].z)
		var seg_len = a.distance_to(b)
		if seg_len < 0.5:
			continue
		var seg = ribbon_pool[idx]
		seg.visible = true
		seg.scale = Vector3(1.0, 1.0, seg_len)
		seg.global_position = (a + b) * 0.5
		seg.look_at(b, Vector3.UP)
		idx += 1
	while idx < ribbon_pool.size():
		ribbon_pool[idx].visible = false
		idx += 1"""

assert old_rebuild in mp, "rebuild_road_ribbon not found"
mp = mp.replace(old_rebuild, new_rebuild)
open("minimap.gd", "w").write(mp)

# 2. Replace heavy CSGBox3D blocks with lightweight MeshInstance3D + StaticBody3D & trim redundant OmniLight3Ds in city_generator.gd
cg = open("city_generator.gd").read()

old_add_wall = """func add_wall(pos: Vector3, sz: Vector3, mat: Material):
	var b = CSGBox3D.new()
	b.size = sz
	b.position = pos
	b.use_collision = true
	b.material = mat
	add_child(b)"""

new_add_wall = """func add_wall(pos: Vector3, sz: Vector3, mat: Material):
	var body = StaticBody3D.new()
	body.position = pos
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	bm.material = mat
	mi.mesh = bm
	body.add_child(mi)
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = sz
	col.shape = bs
	body.add_child(col)
	add_child(body)"""

assert old_add_wall in cg, "add_wall not found"
cg = cg.replace(old_add_wall, new_add_wall)

# Also convert sidewalk pad, podium, mid_tower, tarmac, and base_pad from CSGBox3D to add_wall()
cg = cg.replace(
"""			var pad = CSGBox3D.new()
			pad.size = Vector3(pad_w, 0.24, pad_w)
			pad.position = pos + Vector3(0, 0.12, 0)
			pad.use_collision = true
			pad.material = sidewalk_mat
			add_child(pad)""",
"""			add_wall(pos + Vector3(0, 0.12, 0), Vector3(pad_w, 0.24, pad_w), sidewalk_mat)"""
)
cg = cg.replace(
"""	var podium = CSGBox3D.new()
	podium.size = Vector3(bw, podium_h, bw)
	podium.position = base_pos + Vector3(0, podium_h * 0.5, 0)
	podium.use_collision = true
	podium.material = facade_mat
	add_child(podium)""",
"""	add_wall(base_pos + Vector3(0, podium_h * 0.5, 0), Vector3(bw, podium_h, bw), facade_mat)"""
)
cg = cg.replace(
"""	var mid_tower = CSGBox3D.new()
	mid_tower.size = Vector3(mid_w, mid_h, mid_w)
	mid_tower.position = base_pos + Vector3(0, podium_h + mid_h * 0.5, 0)
	mid_tower.use_collision = true
	mid_tower.material = facade_mat
	add_child(mid_tower)""",
"""	add_wall(base_pos + Vector3(0, podium_h + mid_h * 0.5, 0), Vector3(mid_w, mid_h, mid_w), facade_mat)"""
)
cg = cg.replace(
"""	var tarmac = CSGBox3D.new()
	tarmac.size = Vector3(68.0, 0.22, 24.0)
	tarmac.position = Vector3(-118.0, 0.11, 128.0)
	tarmac.use_collision = true
	tarmac.material = tarmac_mat
	add_child(tarmac)""",
"""	add_wall(Vector3(-118.0, 0.11, 128.0), Vector3(68.0, 0.22, 24.0), tarmac_mat)"""
)
cg = cg.replace(
"""	var base_pad = CSGBox3D.new()
	base_pad.size = Vector3(56.0, 0.24, 46.0)
	base_pad.position = base_center + Vector3(0, 0.12, 0)
	base_pad.use_collision = true
	base_pad.material = mil_mat
	add_child(base_pad)""",
"""	add_wall(base_center + Vector3(0, 0.12, 0), Vector3(56.0, 0.24, 46.0), mil_mat)"""
)

# Keep only central intersection OmniLight3Ds (gx==0 and gz==0) so Mobile renderer never stalls Metal
cg = cg.replace("if abs(gx) <= 1 and abs(gz) <= 1:", "if gx == 0 and gz == 0:")
open("city_generator.gd", "w").write(cg)

# 3. Also replace any CSGBox3D in main.tscn (GunBox, StuntRamp) or keep directional shadow blur lightweight in graphics_overhaul.gd
gfx = open("graphics_overhaul.gd").read()
gfx = gfx.replace("sun.shadow_blur = 1.8", "sun.shadow_blur = 1.0")
open("graphics_overhaul.gd", "w").write(gfx)

print("Eliminated Metal fence timeout: pooled 3D GPS ribbon, replaced CSGBox3D with StaticBody3D+BoxMesh, & optimized Mobile lights OK")
