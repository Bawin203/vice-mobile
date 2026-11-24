extends Control

var move_vector: Vector2 = Vector2.ZERO
var gas_pressed: bool = false
var brake_pressed: bool = false
var stick_touch_idx: int = -1
var look_touch_idx: int = -1

@onready var stick_bg: Panel = $StickBG
@onready var stick_knob: Panel = $StickBG/Knob

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if stick_bg.get_global_rect().grow(30).has_point(event.position) and stick_touch_idx == -1:
				stick_touch_idx = event.index
				update_stick(event.position)
			elif event.position.x > size.x * 0.45 and look_touch_idx == -1:
				look_touch_idx = event.index
		else:
			if event.index == stick_touch_idx:
				stick_touch_idx = -1
				move_vector = Vector2.ZERO
				stick_knob.position = (stick_bg.size - stick_knob.size) * 0.5
			elif event.index == look_touch_idx:
				look_touch_idx = -1
	elif event is InputEventScreenDrag:
		if event.index == stick_touch_idx:
			update_stick(event.position)
		elif event.index == look_touch_idx:
			rotate_active_camera(event.relative)

func update_stick(touch_pos: Vector2) -> void:
	var center = stick_bg.global_position + stick_bg.size * 0.5
	var delta = touch_pos - center
	var max_r = stick_bg.size.x * 0.5
	if delta.length() > max_r:
		delta = delta.normalized() * max_r
	stick_knob.position = (stick_bg.size - stick_knob.size) * 0.5 + delta
	move_vector = delta / max_r

func rotate_active_camera(rel: Vector2) -> void:
	var main = get_tree().current_scene
	var player = main.get_node_or_null("Player")
	if player and player.nearby_car and player.nearby_car.is_driven:
		player.nearby_car.camera_pivot.rotate_y(-rel.x * 0.006)
	elif player:
		player.camera_pivot.rotate_y(-rel.x * 0.006)
		player.camera_pivot.rotation.x = clamp(player.camera_pivot.rotation.x - rel.y * 0.006, deg_to_rad(-60), deg_to_rad(45))

func _on_gas_down() -> void: gas_pressed = true
func _on_gas_up() -> void: gas_pressed = false
func _on_brake_down() -> void: brake_pressed = true
func _on_brake_up() -> void: brake_pressed = false

func _on_jump_pressed() -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player and player.is_on_floor() and player.visible:
		player.velocity.y = player.jump_velocity

func _on_car_btn_pressed() -> void:
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player and player.nearby_car:
		player.nearby_car.exit_vehicle() if player.nearby_car.is_driven else player.nearby_car.enter_vehicle(player)

func _process(_d):
	if get_node("FireBtn").button_pressed:
		var w = get_tree().current_scene.get_node_or_null("Player/MeshInstance3D/WeaponMount")
		if w: w.shoot(get_tree().current_scene.get_node("Player"))

func _ready():
	get_node("GunSwitchBtn").pressed.connect(func():
		var w = get_tree().current_scene.get_node_or_null("Player/MeshInstance3D/WeaponMount")
		if w: w.cycle_weapon()
	)
