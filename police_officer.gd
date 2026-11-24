extends CharacterBody3D

const RigScript = preload("res://human_rig.gd")

var hp: int = 90
var shoot_cd: float = 0.85
var rig: Node3D

func _ready():
	name = "PoliceOfficer_%d" % Time.get_ticks_msec()
	floor_max_angle = deg_to_rad(55)
	floor_snap_length = 0.4
	var col = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 1.85
	col.shape = cap
	col.position.y = 0.92
	add_child(col)

	rig = Node3D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.build_human(Color(0.08, 0.14, 0.28), Color(0.06, 0.08, 0.14), true)

func _physics_process(delta: float):
	shoot_cd = max(0.0, shoot_cd - delta)
	var main = get_tree().current_scene
	if main == null:
		return
	var hud = main.get_node_or_null("HUD")
	var wanted = hud.wanted_level if hud else 0
	if wanted <= 0:
		queue_free()
		return

	var target = get_active_target(main)
	if target == null:
		return

	var to_t = target.global_position - global_position
	to_t.y = 0.0
	var dist = to_t.length()

	if dist > 80.0:
		queue_free()
		return

	var dir = to_t.normalized() if dist > 0.05 else Vector3.FORWARD
	if rig:
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)

	var move_spd = 5.6 if dist > 2.8 else 0.0
	velocity.x = dir.x * move_spd
	velocity.z = dir.z * move_spd

	if is_on_wall() and is_on_floor():
		velocity.y = 5.5
	elif not is_on_floor():
		velocity.y -= 14.0 * delta

	move_and_slide()

	if rig and rig.has_method("animate_walk"):
		rig.animate_walk(move_spd, delta)

	# Close-range BUST / Arrest
	var t_spd = target.linear_velocity.length() if target is VehicleBody3D else target.velocity.length()
	if dist < 3.0 and t_spd < 2.2 and hud and hud.has_method("advance_bust"):
		hud.advance_bust(delta * 0.9)
	# Ranged police gunfire
	elif dist < 28.0 and shoot_cd == 0.0:
		shoot_cd = 1.05
		spawn_muzzle_tracer(global_position + Vector3(0, 1.35, 0) + dir * 0.6, target.global_position + Vector3(0, 1.1, 0))
		if hud:
			hud.damage_player(6)
		var sfx = main.get_node_or_null("SFX")
		if sfx:
			sfx.play_sound("shoot")

func spawn_muzzle_tracer(from_pt: Vector3, to_pt: Vector3):
	var main = get_tree().current_scene
	if main == null: return
	var mid = (from_pt + to_pt) * 0.5
	var length = max(from_pt.distance_to(to_pt), 0.25)
	var tracer = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, length)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.15)
	mat.emission_energy_multiplier = 3.5
	bm.material = mat
	tracer.mesh = bm
	main.add_child(tracer)
	tracer.global_position = mid
	if length > 0.3:
		tracer.look_at(to_pt, Vector3.UP)
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()

func get_active_target(main: Node) -> Node3D:
	for child in main.get_children():
		if child is VehicleBody3D and child.get("is_driven") == true:
			return child
	var city = main.get_node_or_null("CityGenerator")
	if city:
		for child in city.get_children():
			if child is VehicleBody3D and child.get("is_driven") == true:
				return child
	return main.get_node_or_null("Player")

func take_damage(dmg: int):
	hp -= dmg
	velocity += Vector3(randf_range(-2.0, 2.0), 3.0, randf_range(-2.0, 2.0))
	if rig:
		rig.scale = Vector3(1.15, 0.88, 1.15)
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(rig): rig.scale = Vector3.ONE
		)
	if hp <= 0:
		var main = get_tree().current_scene
		var mm = main.get_node_or_null("MissionManager")
		if mm: mm.cash += 250
		var hud = main.get_node_or_null("HUD")
		if hud:
			hud.add_wanted(1)
			if hud.get_node_or_null("BottomHint"):
				hud.get_node("BottomHint").text = "OFFICER DOWN! +$250 | Wanted Level Increased!"
		queue_free()
