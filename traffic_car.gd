extends VehicleBody3D

const CarBuilder = preload("res://car_builder.gd")

@export var ai_speed: float = 11.0
@export var max_engine_force: float = 2400.0
@export var max_brake_force: float = 110.0
@export var max_steer_angle: float = 0.45

var is_driven: bool = false
var is_hijacked: bool = false
var driver: CharacterBody3D = null

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var seat_exit: Marker3D = $ExitPoint
@onready var front_ray: RayCast3D = $FrontSensor

func _ready() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.45, 0)
	for w in [$WheelFL, $WheelFR, $WheelRL, $WheelRR]:
		w.wheel_friction_slip = 3.0
	var paints = [
		Color(0.82, 0.85, 0.90),
		Color(0.10, 0.36, 0.82),
		Color(0.95, 0.72, 0.10),
		Color(0.12, 0.56, 0.34),
		Color(0.16, 0.18, 0.22)
	]
	var col = paints[abs(int(global_position.x * 7.0 + global_position.z * 13.0)) % paints.size()]
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
	add_child(CarBuilder.build_sculpted_car(col, false))
	CarBuilder.style_wheels(self)

func _physics_process(delta: float) -> void:
	if is_driven:
		var throttle = Input.get_axis("ui_down", "ui_up")
		var tc = get_tree().current_scene.get_node_or_null("HUD/TouchUI")
		if tc:
			if tc.gas_pressed: throttle = 1.0
			if tc.brake_pressed: throttle = -1.0
		engine_force = throttle * max_engine_force
		var steer_input = Input.get_axis("ui_right", "ui_left")
		if tc and abs(tc.move_vector.x) > 0.1:
			steer_input = -tc.move_vector.x
		steering = move_toward(steering, steer_input * max_steer_angle, 3.5 * delta)
		brake = max_brake_force if Input.is_action_pressed("ui_accept") else 0.0
		camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, 0.0, 3.0 * delta)
	elif not is_hijacked:
		# Simple AI cruise along street & wrap around city edge
		if front_ray.is_colliding():
			engine_force = 0.0
			brake = 80.0
		else:
			brake = 0.0
			engine_force = 900.0 if linear_velocity.length() < ai_speed else 0.0
		if abs(global_position.x) > 135.0:
			global_position.x = -sign(global_position.x) * 130.0
		if abs(global_position.z) > 135.0:
			global_position.z = -sign(global_position.z) * 130.0
	else:
		engine_force = 0.0
		brake = 20.0

func enter_vehicle(player_node: CharacterBody3D) -> void:
	is_driven = true
	is_hijacked = true
	get_tree().current_scene.get_node_or_null("HUD").add_wanted(1)
	driver = player_node
	driver.visible = false
	driver.set_physics_process(false)
	driver.get_node("CollisionShape3D").disabled = true
	camera.current = true

func exit_vehicle() -> void:
	if not is_driven or driver == null:
		return
	is_driven = false
	driver.global_position = seat_exit.global_position
	driver.visible = true
	driver.set_physics_process(true)
	driver.get_node("CollisionShape3D").disabled = false
	driver.velocity = Vector3.ZERO
	driver.camera_pivot.rotation = Vector3(0, rotation.y + PI, 0)
	driver.get_node("CameraPivot/SpringArm3D/Camera3D").current = true
	driver = null

func _on_door_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		body.nearby_car = self

func _on_door_body_exited(body: Node3D) -> void:
	if body.name == "Player" and body.nearby_car == self and not is_driven:
		body.nearby_car = null
