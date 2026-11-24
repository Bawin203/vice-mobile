extends Node3D

var unlocked_weapons = ["PISTOL"]
var current_idx = 0
var cooldown = 0.0

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1: select_weapon(0)
		elif event.keycode == KEY_2 and unlocked_weapons.size() > 1: select_weapon(1)
		elif event.keycode == KEY_3 and unlocked_weapons.size() > 2: select_weapon(2)
		elif event.keycode == KEY_G or event.keycode == KEY_TAB: cycle_weapon()
		elif event.keycode == KEY_R:
			var p = get_parent().get_parent()
			if p and p.visible and cooldown == 0.0:
				shoot(p)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var p = get_parent().get_parent()
		if p and p.visible and cooldown == 0.0:
			shoot(p)

func cycle_weapon():
	select_weapon((current_idx + 1) % unlocked_weapons.size())

func select_weapon(idx):
	current_idx = idx % unlocked_weapons.size()
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud and hud.get_node_or_null("BottomHint"):
		hud.get_node("BottomHint").text = "EQUIPPED: %s ([RMB] or [R] to Shoot | [G] Switch)" % unlocked_weapons[current_idx]

func _process(delta):
	cooldown = max(0.0, cooldown - delta)
	var player = get_parent().get_parent()
	if player == null:
		return
	var shooter_node: Node3D = player
	if not player.visible:
		var main = get_tree().current_scene
		var found_car = null
		if main:
			for c in main.get_children():
				if c is VehicleBody3D and c.get("is_driven") == true:
					found_car = c
					break
			if found_car == null and main.get_node_or_null("CityGenerator"):
				for c in main.get_node("CityGenerator").get_children():
					if c is VehicleBody3D and c.get("is_driven") == true:
						found_car = c
						break
		if found_car == null:
			return
		shooter_node = found_car
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_R)) and cooldown == 0.0:
		shoot_from(shooter_node, player)

func shoot(player):
	shoot_from(player, player)

func shoot_from(origin_node: Node3D, player: Node3D):
	var w_name = unlocked_weapons[current_idx]
	cooldown = 0.20 if w_name == "PISTOL" else (0.55 if w_name == "SHOTGUN" else 0.90)
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return

	var aim_dir = -cam.global_transform.basis.z
	aim_dir.y = clamp(aim_dir.y, -0.35, 0.35)
	aim_dir = aim_dir.normalized()
	if origin_node == player: player.mesh.rotation.y = atan2(aim_dir.x, aim_dir.z)

	var main = get_tree().current_scene
	var sfx = main.get_node_or_null("SFX")
	if sfx:
		sfx.play_sound("boom" if w_name == "RPG" else "shoot")

	var muzzle_pos = origin_node.global_position + Vector3(0, 1.35, 0) + aim_dir * 1.45
	var pellets = 5 if w_name == "SHOTGUN" else 1
	var dmg = 45 if w_name == "PISTOL" else (32 if w_name == "SHOTGUN" else 150)
	var space = origin_node.get_world_3d().direct_space_state

	for i in range(pellets):
		var spread = Vector3.ZERO
		if pellets > 1:
			spread = Vector3(randf_range(-0.12, 0.12), randf_range(-0.05, 0.05), randf_range(-0.12, 0.12))
		var shot_dir = (aim_dir + spread).normalized()
		var end_pos = muzzle_pos + shot_dir * 70.0

		var query = PhysicsRayQueryParameters3D.create(muzzle_pos, end_pos)
		query.exclude = [player.get_rid(), origin_node.get_rid()] if origin_node is CollisionObject3D else [player.get_rid()]
		var hit = space.intersect_ray(query)
		if hit:
			end_pos = hit.position
			var body = hit.collider
			if body:
				if body.has_method("take_damage"):
					body.take_damage(dmg)
				elif body.get_parent() and body.get_parent().has_method("take_damage"):
					body.get_parent().take_damage(dmg)
				if w_name == "RPG":
					explode_at(main, end_pos)
				elif body is RigidBody3D:
					body.apply_central_impulse(shot_dir * 350.0)

		draw_tracer(main, muzzle_pos, end_pos, w_name == "RPG")

	var hud = main.get_node_or_null("HUD")
	if hud and hud.wanted_level == 0:
		hud.add_wanted(1)

func explode_at(main: Node, center: Vector3):
	for node in main.get_children():
		if node is Node3D and node.name != "Player":
			if node.global_position.distance_to(center) < 9.5:
				if node.has_method("take_damage"):
					node.take_damage(160)
				if node is RigidBody3D:
					var push = (node.global_position - center).normalized()
					node.apply_central_impulse(push * 1100.0 + Vector3.UP * 550.0)

func draw_tracer(main: Node, from_pt: Vector3, to_pt: Vector3, is_rocket: bool):
	var mid = (from_pt + to_pt) * 0.5
	var dist = max(from_pt.distance_to(to_pt), 0.25)
	var streak = MeshInstance3D.new()
	var bm = BoxMesh.new()
	var thick = 0.14 if is_rocket else 0.045
	bm.size = Vector3(thick, thick, dist)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.08) if is_rocket else Color(1.0, 0.92, 0.3)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 4.0
	bm.material = mat
	streak.mesh = bm
	main.add_child(streak)
	streak.global_position = mid
	if dist > 0.3:
		streak.look_at(to_pt, Vector3.UP)
	await get_tree().create_timer(0.07).timeout
	if is_instance_valid(streak):
		streak.queue_free()
