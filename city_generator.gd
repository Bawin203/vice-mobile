extends Node3D

@export var grid_size = 4
@export var block_spacing = 36.0
@export var road_width = 10.0

var traffic_scene = preload("res://traffic_car.tscn")
const AircraftScript = preload("res://aircraft_and_tank.gd")
var tower_styles: Array[Dictionary] = []

func _ready():
	init_building_materials()
	build_city()
	build_road_markings()
	build_streetlamps()
	build_leonida_outposts()
	spawn_traffic()

func make_window_texture(wall_col: Color, glass_col: Color, lit_col: Color, seed_offset: int) -> ImageTexture:
	var w = 64
	var h = 128
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(wall_col)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9001 + seed_offset
	for y in range(4, h - 4, 8):
		for x in range(4, w - 4, 8):
			var lit = rng.randf() < 0.34
			var c = lit_col if lit else glass_col
			for dy in range(5):
				for dx in range(5):
					img.set_pixel(x + dx, y + dy, c)
	return ImageTexture.create_from_image(img)

func init_building_materials():
	var palettes = [
		# 0: Ocean-Blue Glass Financial Tower
		{"wall": Color(0.14, 0.20, 0.28), "glass": Color(0.18, 0.45, 0.68), "lit": Color(0.85, 0.94, 1.0), "neon": Color(0.0, 0.88, 1.0), "metal": 0.55, "rough": 0.22},
		# 1: Vice City Art-Deco Pastel & Warm Gold Windows
		{"wall": Color(0.86, 0.80, 0.72), "glass": Color(0.22, 0.28, 0.35), "lit": Color(1.0, 0.84, 0.45), "neon": Color(1.0, 0.25, 0.72), "metal": 0.12, "rough": 0.55},
		# 2: Obsidian & Gold Executive High-Rise
		{"wall": Color(0.10, 0.11, 0.14), "glass": Color(0.22, 0.26, 0.32), "lit": Color(1.0, 0.80, 0.35), "neon": Color(1.0, 0.75, 0.12), "metal": 0.65, "rough": 0.20},
		# 3: Coral Sunset Resort Tower
		{"wall": Color(0.84, 0.58, 0.52), "glass": Color(0.16, 0.36, 0.46), "lit": Color(1.0, 0.90, 0.68), "neon": Color(0.18, 0.95, 0.75), "metal": 0.15, "rough": 0.48}
	]
	for i in range(palettes.size()):
		var p = palettes[i]
		var tex = make_window_texture(p["wall"], p["glass"], p["lit"], i * 17)
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.uv1_scale = Vector3(3.0, 5.0, 3.0)
		mat.uv1_triplanar = true
		mat.metallic = p["metal"]
		mat.roughness = p["rough"]
		mat.emission_enabled = true
		mat.emission_texture = tex
		mat.emission_energy_multiplier = 0.45

		var trim = StandardMaterial3D.new()
		trim.albedo_color = p["neon"]
		trim.emission_enabled = true
		trim.emission = p["neon"]
		trim.emission_energy_multiplier = 2.2
		tower_styles.append({"facade": mat, "neon": trim, "base_col": p["wall"]})

func build_city():
	var sidewalk_mat = StandardMaterial3D.new()
	sidewalk_mat.albedo_color = Color(0.56, 0.57, 0.60)
	sidewalk_mat.roughness = 0.82
	var curb_mat = StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.38, 0.40, 0.44)
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.76, 0.73, 0.68)
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.84, 0.80, 0.74)

	for x in range(-grid_size, grid_size + 1):
		for z in range(-grid_size, grid_size + 1):
			var pos = Vector3(x * block_spacing, 0.0, z * block_spacing)
			if x == 0 and z == 0:
				continue

			# Sidewalk + outer curb border
			var pad_w = block_spacing - road_width
			add_wall(pos + Vector3(0, 0.12, 0), Vector3(pad_w, 0.24, pad_w), sidewalk_mat)

			var bw = pad_w - 4.2
			var b_height = randf_range(18.0, 42.0)

			if (abs(x) + abs(z)) % 2 == 1 and abs(x) <= 2 and abs(z) <= 2:
				build_enterable_shop(pos + Vector3(0, 0.24, 0), bw, b_height, wall_mat, floor_mat, x, z)
			else:
				build_detailed_skyscraper(pos + Vector3(0, 0.24, 0), bw, b_height, abs(x * 7 + z * 13))

			# Sculpted Street Palm Trees on sidewalk corners
			if abs(x) <= 2 and abs(z) <= 2:
				build_street_palm(pos + Vector3(10.8, 0.24, 10.8))
				build_street_palm(pos + Vector3(-10.8, 0.24, -10.8))

func build_detailed_skyscraper(base_pos: Vector3, bw: float, b_height: float, style_seed: int):
	var st = tower_styles[style_seed % tower_styles.size()]
	var facade_mat: StandardMaterial3D = st["facade"]
	var neon_mat: StandardMaterial3D = st["neon"]

	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.18, 0.20, 0.24)
	roof_mat.roughness = 0.75

	# 1. Ground-floor podium lobby
	var podium_h = 4.2
	add_wall(base_pos + Vector3(0, podium_h * 0.5, 0), Vector3(bw, podium_h, bw), facade_mat)

	# Glowing architectural belt band above lobby
	var belt = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(bw + 0.35, 0.32, bw + 0.35)
	bm.material = neon_mat
	belt.mesh = bm
	belt.position = base_pos + Vector3(0, podium_h + 0.16, 0)
	add_child(belt)

	# 2. Main middle shaft (slightly inset for real skyscraper silhouette)
	var mid_h = (b_height - podium_h) * 0.72
	var mid_w = bw * 0.86
	add_wall(base_pos + Vector3(0, podium_h + mid_h * 0.5, 0), Vector3(mid_w, mid_h, mid_w), facade_mat)

	# 3. Upper stepped penthouse crown
	var top_h = (b_height - podium_h) * 0.28
	var top_w = mid_w * 0.72
	var top_tower = MeshInstance3D.new()
	var tm = BoxMesh.new()
	tm.size = Vector3(top_w, top_h, top_w)
	tm.material = facade_mat
	top_tower.mesh = tm
	top_tower.position = base_pos + Vector3(0, podium_h + mid_h + top_h * 0.5, 0)
	add_child(top_tower)

	# 4. Rooftop neon crown trim + spire / HVAC detail
	var crown = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = Vector3(top_w + 0.3, 0.38, top_w + 0.3)
	cm.material = neon_mat
	crown.mesh = cm
	crown.position = base_pos + Vector3(0, b_height, 0)
	add_child(crown)

	var spire = MeshInstance3D.new()
	var sm = CylinderMesh.new()
	sm.top_radius = 0.06
	sm.bottom_radius = 0.18
	sm.height = 4.5
	sm.material = roof_mat
	spire.mesh = sm
	spire.position = base_pos + Vector3(0, b_height + 2.25, 0)
	add_child(spire)

func build_street_palm(pos: Vector3):
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.42, 0.30, 0.18)
	var leaf_mat = StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.14, 0.58, 0.22)

	var trunk = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.14
	tm.bottom_radius = 0.24
	tm.height = 5.2
	tm.material = trunk_mat
	trunk.mesh = tm
	trunk.position = pos + Vector3(0, 2.6, 0)
	add_child(trunk)

	for i in range(4):
		var frond = MeshInstance3D.new()
		var fm = BoxMesh.new()
		fm.size = Vector3(2.8, 0.12, 0.55)
		fm.material = leaf_mat
		frond.mesh = fm
		frond.position = pos + Vector3(0, 5.2, 0)
		frond.rotation.y = i * (PI * 0.25)
		frond.rotation.z = 0.18 if (i % 2 == 0) else -0.18
		add_child(frond)

func build_enterable_shop(base_pos: Vector3, w: float, h: float, wall_mat: Material, floor_mat: Material, gx: int = 0, gz: int = 0):
	var b_type = "CAFE"
	var sign_col = Color(0.1, 0.85, 1.0)
	var style_idx = 1
	if gx == 1 and gz == 0:
		b_type = "GARAGE"
		sign_col = Color(0.0, 0.92, 1.0)
		style_idx = 0
	elif gx == -1 and gz == 0:
		b_type = "BANK"
		sign_col = Color(1.0, 0.82, 0.12)
		style_idx = 2
	elif gx == 0 and gz == 1:
		b_type = "CASINO"
		sign_col = Color(0.95, 0.22, 0.85)
		style_idx = 3
	elif gx == 0 and gz == -1:
		b_type = "HOSPITAL"
		sign_col = Color(0.15, 0.95, 0.42)
		style_idx = 0

	var custom_neon = StandardMaterial3D.new()
	custom_neon.albedo_color = sign_col
	custom_neon.emission_enabled = true
	custom_neon.emission = sign_col
	custom_neon.emission_energy_multiplier = 2.6

	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.25, 0.72, 0.92, 0.35)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.1

	var t = 0.6
	var lobby_h = 5.2 if b_type == "GARAGE" else 4.6
	var door_w = 7.6 if b_type == "GARAGE" else 4.8
	add_wall(base_pos + Vector3(0, 0.05, 0), Vector3(w, 0.1, w), floor_mat)
	add_wall(base_pos + Vector3(0, lobby_h / 2.0, -w / 2.0 + t / 2.0), Vector3(w, lobby_h, t), wall_mat)
	add_wall(base_pos + Vector3(-w / 2.0 + t / 2.0, lobby_h / 2.0, 0), Vector3(t, lobby_h, w), wall_mat)
	add_wall(base_pos + Vector3(w / 2.0 - t / 2.0, lobby_h / 2.0, 0), Vector3(t, lobby_h, w), wall_mat)
	var side_w = (w - door_w) / 2.0
	# Storefront glass windows flanking entrance
	add_wall(base_pos + Vector3(-w / 2.0 + side_w / 2.0, 0.6, w / 2.0 - t / 2.0), Vector3(side_w, 1.2, t), wall_mat)
	add_wall(base_pos + Vector3(-w / 2.0 + side_w / 2.0, 2.7, w / 2.0 - t / 2.0), Vector3(side_w - 0.6, 2.8, 0.15), glass_mat)
	add_wall(base_pos + Vector3(w / 2.0 - side_w / 2.0, 0.6, w / 2.0 - t / 2.0), Vector3(side_w, 1.2, t), wall_mat)
	add_wall(base_pos + Vector3(w / 2.0 - side_w / 2.0, 2.7, w / 2.0 - t / 2.0), Vector3(side_w - 0.6, 2.8, 0.15), glass_mat)

	add_wall(base_pos + Vector3(0, lobby_h - 0.5, w / 2.0 - t / 2.0), Vector3(w, 1.0, t), wall_mat)
	add_wall(base_pos + Vector3(0, lobby_h - 0.5, w / 2.0 + 0.15), Vector3(door_w + 1.2, 0.62, 0.2), custom_neon)

	# Upper skyscraper tower with lit window facade above the enterable lobby
	var upper_h = h - lobby_h
	if upper_h > 2.0:
		var upper_mat = tower_styles[style_idx % tower_styles.size()]["facade"]
		add_wall(base_pos + Vector3(0, lobby_h + upper_h * 0.5, 0), Vector3(w * 0.9, upper_h, w * 0.9), upper_mat)
		var top_trim = MeshInstance3D.new()
		var ttm = BoxMesh.new()
		ttm.size = Vector3(w * 0.92, 0.35, w * 0.92)
		ttm.material = custom_neon
		top_trim.mesh = ttm
		top_trim.position = base_pos + Vector3(0, h, 0)
		add_child(top_trim)

	# Interior counter + task-specific props
	add_wall(base_pos + Vector3(0, 0.6, -w / 2.0 + 3.0), Vector3(6.4, 1.1, 1.2), wall_mat)
	if b_type == "BANK":
		# Gold bullion stacks behind vault counter
		add_wall(base_pos + Vector3(-2.0, 0.7, -w / 2.0 + 1.5), Vector3(1.4, 1.2, 0.9), custom_neon)
		add_wall(base_pos + Vector3(2.0, 0.7, -w / 2.0 + 1.5), Vector3(1.4, 1.2, 0.9), custom_neon)

	# Interactive Task Zone
	var zone = Area3D.new()
	zone.set_meta("b_type", b_type)
	zone.set_meta("cooldown_until", 0.0)
	var zcol = CollisionShape3D.new()
	var zbox = BoxShape3D.new()
	zbox.size = Vector3(6.5, 3.5, 6.5)
	zcol.shape = zbox
	zone.add_child(zcol)

	var pad_mesh = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 2.4
	pm.bottom_radius = 2.4
	pm.height = 0.14
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(sign_col.r, sign_col.g, sign_col.b, 0.65)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.emission_enabled = true
	pmat.emission = sign_col
	pmat.emission_energy_multiplier = 2.2
	pm.material = pmat
	pad_mesh.mesh = pm
	zone.add_child(pad_mesh)

	zone.position = base_pos + Vector3(0, 0.12, 0.5)
	zone.body_entered.connect(_on_building_task.bind(zone))
	add_child(zone)

	var light = OmniLight3D.new()
	light.position = base_pos + Vector3(0, 3.8, 0)
	light.light_color = sign_col.lerp(Color.WHITE, 0.55)
	light.omni_range = 16.0
	light.light_energy = 2.0
	add_child(light)

func _on_building_task(body: Node3D, zone: Area3D):
	var is_player = body.name == "Player"
	var is_driven_car = body is VehicleBody3D and body.get("is_driven") == true
	if not is_player and not is_driven_car:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now < float(zone.get_meta("cooldown_until")):
		return

	var root = get_tree().current_scene
	var mm = root.get_node_or_null("MissionManager")
	var hud = root.get_node_or_null("HUD")
	if mm == null or hud == null:
		return
	var hint = hud.get_node_or_null("BottomHint")
	var b_type = str(zone.get_meta("b_type"))

	if b_type == "GARAGE":
		zone.set_meta("cooldown_until", now + 5.0)
		var cost = 150 if mm.cash >= 150 else 0
		mm.cash -= cost
		hud.wanted_level = 0
		hud.knows_face = false
		hud.knows_car = false
		hud.knows_cctv = false
		hud.hp = hud.max_hp
		if hud.hp_bar: hud.hp_bar.value = hud.hp
		hud.update_hud()
		for c in root.get_children():
			if c.name.begins_with("PoliceCar") or c.name.begins_with("PoliceOfficer"):
				c.queue_free()
		if hint:
			hint.text = "PAY 'N' SPRAY: Wanted Stars Cleared & Full Repair! (-$%d)" % cost

	elif b_type == "BANK":
		zone.set_meta("cooldown_until", now + 25.0)
		mm.cash += 1200
		hud.add_wanted(3, true)
		if mm.has_method("on_bank_robbed"): mm.on_bank_robbed()
		if hint:
			hint.text = "BANK HEIST: Stole $1,200 Cash! CCTV Alerted — Escape the 2-Star Pursuit!"

	elif b_type == "CASINO":
		zone.set_meta("cooldown_until", now + 18.0)
		mm.cash += 600
		if hint:
			hint.text = "VICE CASINO: Collected +$600 Syndicate Payout!"

	elif b_type == "HOSPITAL":
		zone.set_meta("cooldown_until", now + 6.0)
		var med_cost = 100 if mm.cash >= 100 else 0
		mm.cash -= med_cost
		hud.hp = hud.max_hp
		if hud.hp_bar: hud.hp_bar.value = hud.hp
		var armor = hud.get_node_or_null("ArmorBar")
		if armor: armor.value = 100
		if hint:
			hint.text = "VICE MED-BAY: Full Health & Body Armor Restored! (-$%d)" % med_cost

	else:
		zone.set_meta("cooldown_until", now + 12.0)
		mm.cash += 250
		if hint:
			hint.text = "SAFEHOUSE STASH: Picked up +$250 Protection Cash!"

func add_wall(pos: Vector3, sz: Vector3, mat: Material):
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
	add_child(body)

func build_road_markings():
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.95, 0.85, 0.25)
	for g in range(-4, 5):
		var coord = g * block_spacing
		for d in range(-135, 140, 12):
			if abs(d % int(block_spacing)) > 6:
				var dash1 = MeshInstance3D.new()
				var bm1 = BoxMesh.new()
				bm1.size = Vector3(0.22, 0.03, 4.5)
				bm1.material = line_mat
				dash1.mesh = bm1
				dash1.position = Vector3(coord, 0.02, d)
				add_child(dash1)

				var dash2 = MeshInstance3D.new()
				var bm2 = BoxMesh.new()
				bm2.size = Vector3(4.5, 0.03, 0.22)
				bm2.material = line_mat
				dash2.mesh = bm2
				dash2.position = Vector3(d, 0.02, coord)
				add_child(dash2)

func build_streetlamps():
	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.14, 0.16, 0.20)
	pole_mat.metallic = 0.8
	var bulb_mat = StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.88, 0.62)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.82, 0.45)
	bulb_mat.emission_energy_multiplier = 3.2

	for gx in range(-2, 3):
		for gz in range(-2, 3):
			var corner = Vector3(gx * block_spacing + 5.6, 0.0, gz * block_spacing + 5.6)
			var pole = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.09
			pm.bottom_radius = 0.13
			pm.height = 5.4
			pm.material = pole_mat
			pole.mesh = pm
			pole.position = corner + Vector3(0, 2.7, 0)
			add_child(pole)

			var arm = MeshInstance3D.new()
			var am = BoxMesh.new()
			am.size = Vector3(1.6, 0.1, 0.12)
			am.material = pole_mat
			arm.mesh = am
			arm.position = corner + Vector3(-0.75, 5.35, 0)
			add_child(arm)

			var lamp = MeshInstance3D.new()
			var lm = BoxMesh.new()
			lm.size = Vector3(0.55, 0.12, 0.24)
			lm.material = bulb_mat
			lamp.mesh = lm
			lamp.position = corner + Vector3(-1.35, 5.28, 0)
			add_child(lamp)

			if gx == 0 and gz == 0:
				var omni = OmniLight3D.new()
				omni.position = corner + Vector3(-1.35, 4.9, 0)
				omni.light_color = Color(1.0, 0.84, 0.55)
				omni.omni_range = 18.0
				omni.light_energy = 1.4
				add_child(omni)

func build_leonida_outposts():
	var gas_mat = StandardMaterial3D.new()
	gas_mat.albedo_color = Color(1.0, 0.55, 0.12, 0.7)
	gas_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gas_mat.emission_enabled = true
	gas_mat.emission = Color(1.0, 0.55, 0.12)
	gas_mat.emission_energy_multiplier = 2.2

	var gas_zone = Area3D.new()
	var gcol = CollisionShape3D.new()
	var gbox = BoxShape3D.new()
	gbox.size = Vector3(7.0, 3.5, 7.0)
	gcol.shape = gbox
	gas_zone.add_child(gcol)

	var gpad = MeshInstance3D.new()
	var gm = CylinderMesh.new()
	gm.top_radius = 2.8
	gm.bottom_radius = 2.8
	gm.height = 0.16
	gm.material = gas_mat
	gpad.mesh = gm
	gas_zone.add_child(gpad)

	gas_zone.position = Vector3(36.0, 0.12, -22.0)
	gas_zone.body_entered.connect(func(body):
		if body is VehicleBody3D and body.get("is_driven") == true:
			body.set("fuel", 100.0)
			var root = get_tree().current_scene
			var mm = root.get_node_or_null("MissionManager")
			var hud = root.get_node_or_null("HUD")
			var cost = 40 if (mm and mm.cash >= 40) else 0
			if mm: mm.cash -= cost
			if hud and hud.get_node_or_null("BottomHint"):
				hud.get_node("BottomHint").text = "GAS STATION: Tank Refilled to 100%%! (-$%d)" % cost
	)
	add_child(gas_zone)

	var tarmac_mat = StandardMaterial3D.new()
	tarmac_mat.albedo_color = Color(0.14, 0.15, 0.18)
	add_wall(Vector3(-118.0, 0.11, 128.0), Vector3(68.0, 0.22, 24.0), tarmac_mat)

	var mil_mat = StandardMaterial3D.new()
	mil_mat.albedo_color = Color(0.22, 0.26, 0.19)
	var base_center = Vector3(-118.0, 0.0, -128.0)
	add_wall(base_center + Vector3(0, 0.12, 0), Vector3(56.0, 0.24, 46.0), mil_mat)

	# Perimeter Concrete Walls with South Entrance Gate
	var wall_m = StandardMaterial3D.new()
	wall_m.albedo_color = Color(0.32, 0.35, 0.30)
	add_wall(base_center + Vector3(0, 2.2, -22.5), Vector3(56.0, 4.4, 0.8), wall_m)
	add_wall(base_center + Vector3(-27.5, 2.2, 0), Vector3(0.8, 4.4, 46.0), wall_m)
	add_wall(base_center + Vector3(27.5, 2.2, 0), Vector3(0.8, 4.4, 46.0), wall_m)
	add_wall(base_center + Vector3(-17.5, 2.2, 22.5), Vector3(20.0, 4.4, 0.8), wall_m)
	add_wall(base_center + Vector3(17.5, 2.2, 22.5), Vector3(20.0, 4.4, 0.8), wall_m)

	# Dual Corner Watchtowers with Glowing Searchlights
	var beacon_m = StandardMaterial3D.new()
	beacon_m.albedo_color = Color(1.0, 0.2, 0.15)
	beacon_m.emission_enabled = true
	beacon_m.emission = Color(1.0, 0.2, 0.15)
	beacon_m.emission_energy_multiplier = 3.5
	for side in [-1.0, 1.0]:
		var tx = base_center.x + side * 25.0
		var tz = base_center.z + 20.0
		add_wall(Vector3(tx, 5.0, tz), Vector3(3.2, 10.0, 3.2), wall_m)
		add_wall(Vector3(tx, 10.4, tz), Vector3(4.2, 0.6, 4.2), beacon_m)

	# Military Hangar & Supply Crate Depot
	add_wall(base_center + Vector3(-15.0, 3.5, -12.0), Vector3(16.0, 7.0, 14.0), wall_m)
	var crate_m = StandardMaterial3D.new()
	crate_m.albedo_color = Color(0.28, 0.36, 0.20)
	add_wall(base_center + Vector3(16.0, 1.1, -14.0), Vector3(4.0, 2.2, 3.0), crate_m)

	# Spawn Flyable Lapwing Private Jet on VCIA Airport Runway
	var jet = CharacterBody3D.new()
	jet.set_script(AircraftScript)
	jet.name = "LapwingJet"
	jet.vehicle_type = "JET"
	jet.position = Vector3(-118.0, 0.4, 128.0)
	jet.rotation.y = PI * 0.5
	get_parent().add_child.call_deferred(jet)

	# Spawn Armored Rhino Tank at Mile Zero Military Base
	var tank = CharacterBody3D.new()
	tank.set_script(AircraftScript)
	tank.name = "RhinoTank"
	tank.vehicle_type = "TANK"
	tank.position = Vector3(-118.0, 0.4, -128.0)
	get_parent().add_child.call_deferred(tank)
	call_deferred("spawn_military_guards", base_center)

func spawn_traffic():
	var lanes = [
		{"pos": Vector3(2.2, 0.7, -54.0), "rot": 0.0},
		{"pos": Vector3(-2.2, 0.7, 54.0), "rot": PI},
		{"pos": Vector3(38.2, 0.7, -90.0), "rot": 0.0},
		{"pos": Vector3(33.8, 0.7, 36.0), "rot": PI},
		{"pos": Vector3(-33.8, 0.7, -36.0), "rot": 0.0},
		{"pos": Vector3(-38.2, 0.7, 72.0), "rot": PI},
		{"pos": Vector3(-72.0, 0.7, -33.8), "rot": PI * 0.5},
		{"pos": Vector3(72.0, 0.7, 38.2), "rot": -PI * 0.5},
		{"pos": Vector3(-54.0, 0.7, 2.2), "rot": PI * 0.5},
		{"pos": Vector3(54.0, 0.7, -2.2), "rot": -PI * 0.5}
	]
	for i in range(lanes.size()):
		var npc = traffic_scene.instantiate()
		npc.name = "TrafficCar_%d" % i
		npc.position = lanes[i]["pos"]
		npc.rotation.y = lanes[i]["rot"]
		add_child(npc)

func spawn_military_guards(base_center: Vector3):
	var root = get_parent()
	if root == null: return
	var rig_script = load("res://human_rig.gd")
	var guard_offsets = [
		Vector3(-6.0, 0.95, 16.0),
		Vector3(6.0, 0.95, 16.0),
		Vector3(-10.0, 0.95, -4.0),
		Vector3(10.0, 0.95, -4.0)
	]
	for i in range(guard_offsets.size()):
		var g = CharacterBody3D.new()
		g.name = "MilitaryGuard_%d" % i
		var col = CollisionShape3D.new()
		var cap = CapsuleShape3D.new()
		cap.radius = 0.55
		cap.height = 1.85
		col.shape = cap
		col.position.y = 0.92
		g.add_child(col)

		var rig = Node3D.new()
		rig.set_script(rig_script)
		g.add_child(rig)
		rig.build_human(Color(0.22, 0.30, 0.18), Color(0.16, 0.22, 0.14), true)

		var sc = GDScript.new()
		sc.source_code = "extends CharacterBody3D\nvar hp = 100\nvar cd = 1.1\nfunc _physics_process(delta):\n\tcd = max(0.0, cd - delta)\n\tvar main = get_tree().current_scene\n\tif main == null: return\n\tvar p = main.get_node_or_null(\"Player\")\n\tif p == null: return\n\tvar d = global_position.distance_to(p.global_position)\n\tif d < 28.0 and cd == 0.0:\n\t\tcd = 1.2\n\t\tvar hud = main.get_node_or_null(\"HUD\")\n\t\tif hud:\n\t\t\tif hud.wanted_level < 4: hud.add_wanted(4 - hud.wanted_level, true)\n\t\t\tif p.visible: hud.damage_player(6)\nfunc take_damage(dmg):\n\thp -= dmg\n\tif hp <= 0: queue_free()\n"
		sc.reload()
		g.set_script(sc)
		root.add_child(g)
		g.global_position = base_center + guard_offsets[i]
