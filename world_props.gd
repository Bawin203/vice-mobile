extends Node3D

var rig_script = preload("res://human_rig.gd")

func _ready():
	spawn_barrels()
	spawn_npcs()
	spawn_pickups()
	spawn_gangsters()

func spawn_barrels():
	var spots = [Vector3(-4, 0.7, -5), Vector3(10, 0.7, -4), Vector3(0, 0.7, -12), Vector3(-8, 0.7, 6)]
	for pos in spots:
		var barrel = RigidBody3D.new()
		barrel.mass = 30.0
		var col = CollisionShape3D.new()
		var cs = CylinderShape3D.new()
		cs.radius = 0.45
		cs.height = 1.2
		col.shape = cs
		barrel.add_child(col)

		var mesh = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 1.2
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.12, 0.12)
		cm.material = mat
		mesh.mesh = cm
		barrel.add_child(mesh)

		var sc = GDScript.new()
		sc.source_code = "extends RigidBody3D\nvar hp = 40\nfunc take_damage(dmg):\n\thp -= dmg\n\tif hp <= 0:\n\t\tapply_central_impulse(Vector3(randf_range(-150,150), 450, randf_range(-150,150)))\n\t\tvar mm = get_tree().current_scene.get_node_or_null(\"MissionManager\")\n\t\tif mm: mm.cash += 100\n\t\tawait get_tree().create_timer(0.6).timeout\n\t\tqueue_free()\n"
		sc.reload()
		barrel.set_script(sc)
		add_child(barrel)
		barrel.global_position = pos

func spawn_npcs():
	var spots = [Vector3(-6, 1.1, -8), Vector3(12, 1.1, -12), Vector3(-12, 1.1, 4), Vector3(6, 1.1, 10), Vector3(24, 1.1, 12), Vector3(-24, 1.1, -12), Vector3(48, 1.1, 14), Vector3(-48, 1.1, -14), Vector3(14, 1.1, 48), Vector3(-14, 1.1, -48), Vector3(182, 1.1, -20), Vector3(184, 1.1, 20), Vector3(180, 1.1, 60)]
	var outfits = [Color(0.85, 0.2, 0.25), Color(0.2, 0.75, 0.4), Color(0.9, 0.65, 0.15), Color(0.55, 0.25, 0.8)]
	for i in range(spots.size()):
		var npc = CharacterBody3D.new()
		var col = CollisionShape3D.new()
		col.shape = CapsuleShape3D.new()
		npc.add_child(col)

		var rig = Node3D.new()
		rig.set_script(rig_script)
		npc.add_child(rig)
		rig.build_human(outfits[i % outfits.size()], Color(0.18, 0.2, 0.25))

		var sc = GDScript.new()
		sc.source_code = "extends CharacterBody3D\nvar hp = 70\nvar dir = Vector3(1, 0, 0)\nvar timer = 0.0\nfunc _physics_process(delta):\n\ttimer -= delta\n\tif timer <= 0.0:\n\t\ttimer = randf_range(1.5, 3.5)\n\t\tvar a = randf() * TAU\n\t\tdir = Vector3(cos(a), 0, sin(a))\n\tvelocity.x = dir.x * 2.5\n\tvelocity.z = dir.z * 2.5\n\tif not is_on_floor(): velocity.y -= 9.8 * delta\n\tmove_and_slide()\n\tvar r = get_child(1)\n\tif r and r.has_method(\"animate_walk\"):\n\t\tr.rotation.y = lerp_angle(r.rotation.y, atan2(dir.x, dir.z), 8.0 * delta)\n\t\tr.animate_walk(2.5, delta)\nfunc take_damage(dmg):\n\thp -= dmg\n\tif hp <= 0:\n\t\tvar mm = get_tree().current_scene.get_node_or_null(\"MissionManager\")\n\t\tif mm: mm.cash += 250\n\t\tvar hud = get_tree().current_scene.get_node_or_null(\"HUD\")\n\t\tif hud: hud.add_wanted(1)\n\t\tqueue_free()\n"
		sc.reload()
		npc.set_script(sc)
		add_child(npc)
		npc.global_position = spots[i]

func spawn_pickups():
	var spots = [
		Vector3(6, 0.8, 4),
		Vector3(-18, 0.8, -18),
		Vector3(18, 0.8, 18),
		Vector3(36, 0.8, -36),
		Vector3(-36, 0.8, 36)
	]
	for i in range(spots.size()):
		var area = Area3D.new()
		area.name = "CashPickup_%d" % i
		var col = CollisionShape3D.new()
		var cs = SphereShape3D.new()
		cs.radius = 1.4
		col.shape = cs
		area.add_child(col)

		var mesh = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.45, 0.16, 0.24)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.95, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.8, 0.25)
		bm.material = mat
		mesh.mesh = bm
		area.add_child(mesh)

		var sc = GDScript.new()
		sc.source_code = "extends Area3D\nfunc _ready():\n\tbody_entered.connect(_on_collect)\nfunc _process(delta):\n\trotate_y(2.5 * delta)\nfunc _on_collect(body):\n\tif body.name == \"Player\" or (body is VehicleBody3D and body.get(\"is_driven\") == true):\n\t\tvar mm = get_tree().current_scene.get_node_or_null(\"MissionManager\")\n\t\tif mm: mm.cash += 250\n\t\tvar sfx = get_tree().current_scene.get_node_or_null(\"SFX\")\n\t\tif sfx: sfx.play_sound(\"cash\")\n\t\tvar hud = get_tree().current_scene.get_node_or_null(\"HUD\")\n\t\tif hud: hud.damage_player(-25)\n\t\tqueue_free()\n"
		sc.reload()
		area.set_script(sc)
		add_child(area)
		area.global_position = spots[i]

func spawn_gangsters():
	var spots = [Vector3(-42, 1.1, -36), Vector3(48, 1.1, -42), Vector3(-48, 1.1, 42), Vector3(-84, 1.1, 42), Vector3(84, 1.1, -42), Vector3(-108, 1.1, -108)]
	for pos in spots:
		var g = CharacterBody3D.new()
		var col = CollisionShape3D.new()
		col.shape = CapsuleShape3D.new()
		g.add_child(col)
		var rig = Node3D.new()
		rig.set_script(rig_script)
		g.add_child(rig)
		rig.build_human(Color(0.85, 0.1, 0.1), Color(0.1, 0.1, 0.12), true)

		var sc = GDScript.new()
		sc.source_code = "extends CharacterBody3D\nvar hp = 100\nvar shoot_cd = 1.2\nfunc _physics_process(delta):\n\tshoot_cd = max(0.0, shoot_cd - delta)\n\tvar p = get_tree().current_scene.get_node_or_null(\"Player\")\n\tif p and p.visible:\n\t\tvar to_p = p.global_position - global_position\n\t\tvar dist = to_p.length()\n\t\tif dist < 14.0:\n\t\t\tvar r = get_child(1)\n\t\t\tr.rotation.y = atan2(to_p.x, to_p.z)\n\t\t\tif shoot_cd == 0.0:\n\t\t\t\tshoot_cd = 1.4\n\t\t\t\tvar hud = get_tree().current_scene.get_node_or_null(\"HUD\")\n\t\t\t\tif hud: hud.damage_player(6)\n\t\t\t\tvar sfx = get_tree().current_scene.get_node_or_null(\"SFX\")\n\t\t\t\tif sfx: sfx.play_sound(\"shoot\")\n\tif not is_on_floor(): velocity.y -= 9.8 * delta\n\tmove_and_slide()\nfunc take_damage(dmg):\n\thp -= dmg\n\tif hp <= 0:\n\t\tvar mm = get_tree().current_scene.get_node_or_null(\"MissionManager\")\n\t\tif mm: mm.cash += 500\n\t\tvar sfx = get_tree().current_scene.get_node_or_null(\"SFX\")\n\t\tif sfx: sfx.play_sound(\"cash\")\n\t\tqueue_free()\n"
		sc.reload()
		g.set_script(sc)
		add_child(g)
		g.global_position = pos
