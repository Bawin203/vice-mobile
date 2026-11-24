extends CharacterBody3D

@export var vehicle_type: String = "JET" # "JET" or "TANK"
var is_driven: bool = false
var driver: Node3D = null
var camera_pivot: Node3D
var cam: Camera3D
var turret: Node3D
var barrel_tip: Node3D
var fire_cd: float = 0.0
var speed: float = 0.0
var cam_yaw: float = 0.0

func _ready():
	build_vehicle()

func build_vehicle():
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(3.6, 2.2, 6.5) if vehicle_type == "JET" else Vector3(3.4, 2.1, 5.4)
	col.shape = bs
	col.position.y = 1.1
	add_child(col)

	if vehicle_type == "JET":
		var hull_mat = StandardMaterial3D.new()
		hull_mat.albedo_color = Color(0.94, 0.95, 0.98)
		hull_mat.metallic = 0.65
		hull_mat.roughness = 0.2
		var trim_mat = StandardMaterial3D.new()
		trim_mat.albedo_color = Color(0.05, 0.55, 0.95)
		trim_mat.emission_enabled = true
		trim_mat.emission = Color(0.05, 0.55, 0.95)

		add_box(Vector3(1.6, 1.5, 8.2), hull_mat, Vector3(0, 1.2, 0))
		add_box(Vector3(10.5, 0.16, 2.0), hull_mat, Vector3(0, 1.1, -0.4))
		add_box(Vector3(3.6, 0.14, 1.1), hull_mat, Vector3(0, 1.8, -3.5))
		add_box(Vector3(0.2, 1.8, 1.3), trim_mat, Vector3(0, 2.2, -3.4))
	else:
		var armor_mat = StandardMaterial3D.new()
		armor_mat.albedo_color = Color(0.20, 0.26, 0.16)
		armor_mat.roughness = 0.6
		armor_mat.metallic = 0.35
		var tread_mat = StandardMaterial3D.new()
		tread_mat.albedo_color = Color(0.09, 0.10, 0.11)

		# Heavy armored hull + dual side treads
		add_box(Vector3(2.5, 1.05, 5.2), armor_mat, Vector3(0, 0.78, 0))
		add_box(Vector3(0.55, 0.85, 5.4), tread_mat, Vector3(1.45, 0.45, 0))
		add_box(Vector3(0.55, 0.85, 5.4), tread_mat, Vector3(-1.45, 0.45, 0))

		# Rotating Turret + Main 120mm Cannon Barrel
		turret = Node3D.new()
		turret.position = Vector3(0, 1.48, -0.1)
		add_child(turret)

		var t_mesh = MeshInstance3D.new()
		var tm = BoxMesh.new()
		tm.size = Vector3(2.2, 0.85, 2.6)
		tm.material = armor_mat
		t_mesh.mesh = tm
		turret.add_child(t_mesh)

		var barrel = MeshInstance3D.new()
		var bm = CylinderMesh.new()
		bm.top_radius = 0.14
		bm.bottom_radius = 0.17
		bm.height = 3.9
		bm.material = armor_mat
		barrel.mesh = bm
		barrel.rotation.x = PI * 0.5
		barrel.position = Vector3(0, 0.05, 2.45)
		turret.add_child(barrel)

		barrel_tip = Node3D.new()
		barrel_tip.position = Vector3(0, 0.05, 4.45)
		turret.add_child(barrel_tip)

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 2.7, 0)
	add_child(camera_pivot)
	var arm = SpringArm3D.new()
	arm.spring_length = 12.0 if vehicle_type == "JET" else 9.0
	arm.rotation_degrees = Vector3(-16, 180, 0)
	camera_pivot.add_child(arm)
	cam = Camera3D.new()
	arm.add_child(cam)

	var zone = Area3D.new()
	var zc = CollisionShape3D.new()
	var zs = SphereShape3D.new()
	zs.radius = 5.0
	zc.shape = zs
	zone.add_child(zc)
	zone.body_entered.connect(func(b):
		if b.name == "Player":
			b.nearby_car = self
			var hud = get_tree().current_scene.get_node_or_null("HUD")
			if hud and hud.get_node_or_null("BottomHint"):
				hud.get_node("BottomHint").text = "Press [F] to Board %s" % ("LAPWING JET" if vehicle_type == "JET" else "RHINO TANK")
	)
	zone.body_exited.connect(func(b):
		if b.name == "Player" and b.nearby_car == self:
			b.nearby_car = null
	)
	add_child(zone)

func add_box(sz: Vector3, mat: Material, pos: Vector3):
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	bm.material = mat
	m.mesh = bm
	m.position = pos
	add_child(m)

func _unhandled_input(event: InputEvent):
	if not is_driven:
		return
	if event is InputEventMouseMotion and vehicle_type == "TANK":
		cam_yaw -= event.relative.x * 0.005
		if camera_pivot:
			camera_pivot.rotation.y = cam_yaw

func enter_vehicle(p: Node3D):
	is_driven = true
	driver = p
	driver.visible = false
	driver.set_physics_process(false)
	driver.get_node("CollisionShape3D").disabled = true
	cam.current = true
	cam_yaw = 0.0
	if camera_pivot:
		camera_pivot.rotation.y = 0.0
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		if vehicle_type == "TANK":
			hud.add_wanted(4, true)
		if hud.get_node_or_null("BottomHint"):
			hud.get_node("BottomHint").text = "JET: W/S Thrust | Space/Ctrl Pitch | A/D Yaw | F Exit" if vehicle_type == "JET" else "RHINO TANK: WASD Drive | Mouse Aim Turret | [RMB]/[R] Fire 120mm Cannon | F Exit"

func exit_vehicle():
	if not is_driven or driver == null:
		return
	is_driven = false
	driver.global_position = global_position + global_transform.basis.x * 3.4 + Vector3.UP * 0.8
	driver.visible = true
	driver.set_physics_process(true)
	driver.get_node("CollisionShape3D").disabled = false
	driver.velocity = Vector3.ZERO
	driver.get_node("CameraPivot/SpringArm3D/Camera3D").current = true
	driver = null

func _physics_process(delta: float):
	fire_cd = max(0.0, fire_cd - delta)
	if not is_driven:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
			move_and_slide()
		return

	if vehicle_type == "JET":
		var thrust = 0.0
		if Input.is_key_pressed(KEY_W): thrust = 1.0
		elif Input.is_key_pressed(KEY_S): thrust = -0.6
		speed = clamp(speed + thrust * 28.0 * delta, 0.0, 68.0)
		var yaw_in = 0.0
		if Input.is_key_pressed(KEY_A): yaw_in = 1.0
		if Input.is_key_pressed(KEY_D): yaw_in = -1.0
		rotate_y(yaw_in * 1.4 * delta)

		var climb = 0.0
		if Input.is_action_pressed("ui_accept") and speed > 16.0:
			climb = 14.0
		elif Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
			climb = -12.0
		elif not is_on_floor():
			climb = -1.5 if speed < 18.0 else 0.0

		var fwd = global_transform.basis.z
		velocity = fwd * speed + Vector3.UP * climb
		move_and_slide()
	else:
		# Rotate turret smoothly to match camera aim
		if turret:
			turret.rotation.y = lerp_angle(turret.rotation.y, cam_yaw, 10.0 * delta)

		var throttle = 0.0
		if Input.is_key_pressed(KEY_W): throttle = 1.0
		elif Input.is_key_pressed(KEY_S): throttle = -0.75
		var turn = 0.0
		if Input.is_key_pressed(KEY_A): turn = 1.0
		if Input.is_key_pressed(KEY_D): turn = -1.0
		rotate_y(turn * 1.35 * delta)

		var fwd = global_transform.basis.z
		velocity.x = fwd.x * throttle * 16.5
		velocity.z = fwd.z * throttle * 16.5
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		move_and_slide()

		# Heavy armor ramming: launch police/traffic cars out of the way on contact!
		if abs(throttle) > 0.1:
			var main = get_tree().current_scene
			if main:
				for node in main.get_children():
					if node is RigidBody3D and node.global_position.distance_to(global_position) < 4.5:
						var push = (node.global_position - global_position).normalized()
						node.apply_central_impulse(push * 1500.0 + Vector3.UP * 550.0)

		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_key_pressed(KEY_R)) and fire_cd == 0.0:
			fire_cd = 1.0
			fire_tank_cannon()

func fire_tank_cannon():
	var main = get_tree().current_scene
	if main == null: return
	var sfx = main.get_node_or_null("SFX")
	if sfx: sfx.play_sound("boom")

	var aim_dir = turret.global_transform.basis.z.normalized() if turret else global_transform.basis.z.normalized()
	var start = barrel_tip.global_position if barrel_tip else (global_position + Vector3(0, 1.6, 0) + aim_dir * 4.2)
	var end = start + aim_dir * 85.0

	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(start, end)
	q.exclude = [get_rid()]
	var hit = space.intersect_ray(q)
	if hit:
		end = hit.position

	spawn_cannon_blast(main, start, end)

	for node in main.get_children():
		if node is Node3D and node != self and node.name != "Player":
			if node.global_position.distance_to(end) < 12.0:
				if node.has_method("take_damage"):
					node.take_damage(300)
				if node is RigidBody3D:
					node.apply_central_impulse((node.global_position - end).normalized() * 1800.0 + Vector3.UP * 750.0)
	var city = main.get_node_or_null("CityGenerator")
	if city:
		for node in city.get_children():
			if node is RigidBody3D and node.global_position.distance_to(end) < 12.0:
				node.apply_central_impulse((node.global_position - end).normalized() * 1800.0 + Vector3.UP * 750.0)

func spawn_cannon_blast(main: Node, from_pt: Vector3, to_pt: Vector3):
	var mid = (from_pt + to_pt) * 0.5
	var dist = max(from_pt.distance_to(to_pt), 0.5)
	var shell = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.22, 0.22, dist)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.05)
	mat.emission_energy_multiplier = 5.0
	bm.material = mat
	shell.mesh = bm
	main.add_child(shell)
	shell.global_position = mid
	if dist > 0.3:
		shell.look_at(to_pt, Vector3.UP)

	var boom = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 3.2
	sm.height = 6.4
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(1.0, 0.4, 0.08, 0.78)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.emission_enabled = true
	bmat.emission = Color(1.0, 0.35, 0.05)
	bmat.emission_energy_multiplier = 4.5
	sm.material = bmat
	boom.mesh = sm
	main.add_child(boom)
	boom.global_position = to_pt

	await get_tree().create_timer(0.14).timeout
	if is_instance_valid(shell): shell.queue_free()
	if is_instance_valid(boom): boom.queue_free()
