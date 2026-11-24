extends CharacterBody3D

var is_driven = false
var driver = null
var rotor: MeshInstance3D
var camera_pivot: Node3D
var cam: Camera3D

func _ready():
	build_heli()

func build_heli():
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(2.2, 1.8, 4.5)
	col.shape = bs
	add_child(col)

	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.12, 0.14, 0.18)
	body_mat.metallic = 0.7
	var glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.1, 0.65, 0.9, 0.7)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rotor_mat = StandardMaterial3D.new()
	rotor_mat.albedo_color = Color(0.85, 0.85, 0.9)

	add_part(Vector3(2.0, 1.4, 3.2), body_mat, Vector3(0, 0.9, 0))
	add_part(Vector3(1.8, 1.0, 1.4), glass_mat, Vector3(0, 1.0, 1.6))
	add_part(Vector3(0.45, 0.45, 3.4), body_mat, Vector3(0, 1.1, -2.8))

	rotor = add_part(Vector3(7.5, 0.08, 0.35), rotor_mat, Vector3(0, 1.85, 0))

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 2.2, 0)
	add_child(camera_pivot)
	var arm = SpringArm3D.new()
	arm.spring_length = 9.0
	arm.rotation_degrees = Vector3(-18, 180, 0)
	camera_pivot.add_child(arm)
	cam = Camera3D.new()
	arm.add_child(cam)

	var zone = Area3D.new()
	var zc = CollisionShape3D.new()
	var zs = SphereShape3D.new()
	zs.radius = 4.0
	zc.shape = zs
	zone.add_child(zc)
	zone.body_entered.connect(func(b):
		if b.name == "Player":
			b.nearby_car = self
			get_tree().current_scene.get_node("HUD/BottomHint").text = "Press [F] or [CAR] to Fly Helicopter"
	)
	zone.body_exited.connect(func(b):
		if b.name == "Player" and b.nearby_car == self and not is_driven:
			b.nearby_car = null
	)
	add_child(zone)

func add_part(sz, mat, pos):
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	bm.material = mat
	m.mesh = bm
	m.position = pos
	add_child(m)
	return m

func _physics_process(delta):
	if is_driven:
		rotor.rotate_y(26.0 * delta)
		var tc = get_tree().current_scene.get_node_or_null("HUD/TouchUI")
		var fwd = Input.get_axis("ui_down", "ui_up")
		var turn = Input.get_axis("ui_right", "ui_left")
		if Input.is_key_pressed(KEY_W): fwd = 1.0
		if Input.is_key_pressed(KEY_S): fwd = -1.0
		if Input.is_key_pressed(KEY_A): turn = 1.0
		if Input.is_key_pressed(KEY_D): turn = -1.0
		if tc and tc.move_vector.length() > 0.1:
			fwd = -tc.move_vector.y
			turn = -tc.move_vector.x

		rotate_y(turn * 1.8 * delta)
		var lift = 0.0
		if Input.is_action_pressed("ui_accept") or (tc and tc.gas_pressed): lift = 12.0
		elif Input.is_key_pressed(KEY_SHIFT) or (tc and tc.brake_pressed): lift = -10.0

		var dir = global_transform.basis.z * fwd * 22.0
		velocity.x = lerp(velocity.x, dir.x, 4.0 * delta)
		velocity.z = lerp(velocity.z, dir.z, 4.0 * delta)
		velocity.y = lerp(velocity.y, lift, 4.0 * delta)
		move_and_slide()
	else:
		if not is_on_floor():
			velocity.y -= 9.8 * delta
		velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
		move_and_slide()

func enter_vehicle(player_node):
	is_driven = true
	driver = player_node
	driver.visible = false
	driver.set_physics_process(false)
	driver.get_node("CollisionShape3D").disabled = true
	cam.current = true
	get_tree().current_scene.get_node("HUD/BottomHint").text = "HELI: Space/GAS = Ascend | Shift/BRAKE = Descend | WASD = Fly | F = Exit"

func exit_vehicle():
	if not is_driven or driver == null: return
	is_driven = false
	driver.global_position = global_position + Vector3(2.5, 0.5, 0)
	driver.visible = true
	driver.set_physics_process(true)
	driver.get_node("CollisionShape3D").disabled = false
	driver.velocity = Vector3.ZERO
	driver.get_node("CameraPivot/SpringArm3D/Camera3D").current = true
	driver = null
