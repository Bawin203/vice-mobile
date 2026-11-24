extends Node3D

func _ready():
	build_beach()
	build_weapon_shop()

func build_beach():
	# Golden Sand Strip along East Coast (X = 175 to 235)
	var sand_mat = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.92, 0.82, 0.56)
	var sand = CSGBox3D.new()
	sand.size = Vector3(60, 0.25, 360)
	sand.position = Vector3(205, 0.05, 0)
	sand.use_collision = true
	sand.material = sand_mat
	add_child(sand)

	# Shimmering Turquoise Ocean (X = 235 to 420)
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.04, 0.62, 0.78, 0.88)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.15
	water_mat.metallic = 0.3
	var ocean = CSGBox3D.new()
	ocean.size = Vector3(180, 0.1, 420)
	ocean.position = Vector3(325, -0.05, 0)
	ocean.material = water_mat
	add_child(ocean)

	# Palm Trees along the beachfront
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.30, 0.18)
	var leaf_mat = StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.15, 0.65, 0.22)
	for z in range(-140, 150, 28):
		var tx = 185.0 + sin(z * 0.1) * 4.0
		var trunk = CSGBox3D.new()
		trunk.size = Vector3(0.55, 7.5, 0.55)
		trunk.position = Vector3(tx, 3.75, z)
		trunk.use_collision = true
		trunk.material = trunk_mat
		add_child(trunk)

		var crown = CSGBox3D.new()
		crown.size = Vector3(4.2, 0.6, 4.2)
		crown.position = Vector3(tx, 7.6, z)
		crown.material = leaf_mat
		add_child(crown)

func build_weapon_shop():
	var shop = Area3D.new()
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(5.0, 3.5, 5.0)
	col.shape = bs
	shop.add_child(col)

	var gold = StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.75, 0.1)
	gold.emission_enabled = true
	gold.emission = Color(0.95, 0.7, 0.05)

	var pad = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(4.5, 0.18, 4.5)
	bm.material = gold
	pad.mesh = bm
	shop.add_child(pad)

	var roof = MeshInstance3D.new()
	var rm = BoxMesh.new()
	rm.size = Vector3(4.8, 0.35, 4.8)
	rm.material = gold
	roof.mesh = rm
	roof.position = Vector3(0, 3.6, 0)
	shop.add_child(roof)

	shop.body_entered.connect(_on_shop_entered)
	add_child(shop)
	shop.global_position = Vector3(8, 0.1, -10)

func _on_shop_entered(body):
	if body.name != "Player": return
	var mm = get_tree().current_scene.get_node_or_null("MissionManager")
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	var w = body.get_node_or_null("MeshInstance3D/WeaponMount")
	if mm == null or hud == null or w == null: return

	if "SHOTGUN" not in w.unlocked_weapons and mm.cash >= 300:
		mm.cash -= 300
		w.unlocked_weapons.append("SHOTGUN")
		w.select_weapon(1)
		hud.get_node("BottomHint").text = "AMMU-NATION: Bought HEAVY SHOTGUN! ([G] to Switch)"
	elif "RPG" not in w.unlocked_weapons and mm.cash >= 600:
		mm.cash -= 600
		w.unlocked_weapons.append("RPG")
		w.select_weapon(2)
		hud.get_node("BottomHint").text = "AMMU-NATION: Bought RPG LAUNCHER! ([G] to Switch)"
	else:
		hud.get_node("BottomHint").text = "AMMU-NATION: Shotgun ($300) | RPG Launcher ($600)"
