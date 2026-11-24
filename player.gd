extends CharacterBody3D
var rage_overlay: ColorRect = null

@export var walk_speed = 5.5
@export var sprint_speed = 10.0
@export var jump_velocity = 5.5
@export var rotation_speed = 10.0
@export var mouse_sensitivity = 0.005

@onready var camera_pivot = $CameraPivot
@onready var mesh = $MeshInstance3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var nearby_car = null
var rig_script = preload("res://human_rig.gd")
var human_node = null

func _ready():
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		rage_overlay = ColorRect.new()
		rage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		rage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rage_overlay.color = Color(1.0, 0.25, 0.05, 0.0)
		hud.add_child(rage_overlay)
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)
	global_position = Vector3(2.5, 1.2, 2.5)
	mesh.mesh = null
	for c in mesh.get_children():
		if c.name != "WeaponMount":
			c.queue_free()
	human_node = Node3D.new()
	human_node.set_script(rig_script)
	mesh.add_child(human_node)
	human_node.build_human(Color(0.12, 0.45, 0.95), Color(0.14, 0.16, 0.22), true)
	var wm = mesh.get_node_or_null("WeaponMount")
	if wm:
		for wc in wm.get_children():
			if wc is MeshInstance3D: wc.scale = Vector3(0.35, 0.35, 0.35)

func _input(event):
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			turn_camera(event.relative)
	elif event is InputEventScreenDrag:
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.35:
			turn_camera(event.relative)

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and nearby_car:
		if nearby_car.is_driven:
			nearby_car.exit_vehicle()
		else:
			nearby_car.enter_vehicle(self)

func turn_camera(rel):
	if nearby_car and nearby_car.is_driven:
		nearby_car.camera_pivot.rotate_y(-rel.x * mouse_sensitivity)
	else:
		camera_pivot.rotate_y(-rel.x * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x - rel.y * mouse_sensitivity, deg_to_rad(-60), deg_to_rad(45))

func _physics_process(delta):
	if Input.is_key_pressed(KEY_Q):
		turn_camera(Vector2(-8.0, 0.0))
	if Input.is_key_pressed(KEY_E):
		turn_camera(Vector2(8.0, 0.0))

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var x_in = Input.get_axis("ui_left", "ui_right")
	var z_in = Input.get_axis("ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): x_in -= 1.0
	if Input.is_key_pressed(KEY_D): x_in += 1.0
	if Input.is_key_pressed(KEY_W): z_in -= 1.0
	if Input.is_key_pressed(KEY_S): z_in += 1.0

	var tc = get_parent().get_node_or_null("HUD/TouchUI")
	if tc and tc.move_vector.length() > 0.1:
		x_in = tc.move_vector.x
		z_in = tc.move_vector.y

	var cam_basis = camera_pivot.global_transform.basis
	var forward = Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
	var right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
	var direction = (forward * z_in + right * x_in).normalized()
	var speed = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(direction.x, direction.z), rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()
	if human_node and human_node.has_method("animate_walk"):
		human_node.animate_walk(Vector2(velocity.x, velocity.z).length(), delta, true)

func _on_car_detect_body_entered(body):
	if body == self:
		nearby_car = get_parent().get_node("SportsCar")
		get_parent().get_node("HUD/BottomHint").text = "Press [F] or Tap [CAR] to Enter"

func _on_car_detect_body_exited(body):
	if body == self and nearby_car and not nearby_car.is_driven:
		nearby_car = null
		get_parent().get_node("HUD/BottomHint").text = "WASD: Move | Click+Drag or Q/E: Turn Camera | F: Enter Car"
