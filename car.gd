extends VehicleBody3D

const CarBuilder = preload("res://car_builder.gd")

@export var max_engine_force = 4600.0
@export var max_brake_force = 130.0
@export var max_steer_angle = 0.52
@export var anti_roll_stiffness = 9500.0

var is_driven = false
var driver = null
var fuel: float = 100.0
var max_fuel: float = 100.0

@onready var camera_pivot = $CameraPivot
@onready var car_cam = $CameraPivot/SpringArm3D/Camera3D

func _ready():
	mass = 1380.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.62, 0.08)
	for w in [$WheelFL, $WheelFR, $WheelRL, $WheelRR]:
		w.wheel_friction_slip = 3.6
		w.suspension_travel = 0.22
		w.suspension_stiffness = 38.0
		w.damping_compression = 2.6
		w.damping_relaxation = 3.2
	add_car_details()

func _physics_process(delta):
	apply_anti_roll()
	var speed = linear_velocity.length()
	# Aerodynamic downforce keeps tires planted at high speed
	apply_central_force(-global_transform.basis.y * speed * speed * 1.4)

	if is_driven:
		var tc = get_parent().get_node_or_null("HUD/TouchUI")
		var throttle = Input.get_axis("ui_down", "ui_up")
		var steer = Input.get_axis("ui_right", "ui_left")
		if Input.is_key_pressed(KEY_W): throttle = 1.0
		if Input.is_key_pressed(KEY_S): throttle = -1.0
		if Input.is_key_pressed(KEY_A): steer = 1.0
		if Input.is_key_pressed(KEY_D): steer = -1.0
		if tc:
			if tc.gas_pressed: throttle = 1.0
			elif tc.brake_pressed: throttle = -1.0
			if abs(tc.move_vector.x) > 0.1: steer = -tc.move_vector.x

		var nitro = 1.55 if (Input.is_key_pressed(KEY_SHIFT) and fuel > 1.0) else 1.0
		var drifting = Input.is_action_pressed("ui_accept")
		if abs(throttle) > 0.05 and fuel > 0.0:
			fuel = max(0.0, fuel - delta * (1.8 if nitro > 1.0 else 0.65))
		if fuel <= 0.1:
			throttle = clamp(throttle, -0.25, 0.25)

		# Torque curve: strong launch + high top speed (~58 m/s = ~130 MPH)
		var top_speed = 58.0 if nitro > 1.0 else 44.0
		var torque_mult = clamp(1.15 - (speed / top_speed) * 0.65, 0.25, 1.15)
		var forward_speed = linear_velocity.dot(global_transform.basis.z)

		if throttle < 0.0 and forward_speed > 2.5:
			# Active braking when moving forward
			engine_force = 0.0
			brake = max_brake_force
		else:
			engine_force = throttle * max_engine_force * torque_mult * nitro
			brake = 0.0

		# Handbrake drift physics (Spacebar): loosen rear grip + kick tail cleanly
		for rw in [$WheelRL, $WheelRR]:
			rw.wheel_friction_slip = lerp(rw.wheel_friction_slip, 1.15 if drifting else 3.6, 12.0 * delta)
		if drifting:
			brake = max_brake_force * 0.55
			if speed > 6.0 and abs(steer) > 0.1:
				apply_torque(global_transform.basis.y * steer * 2600.0)

		var speed_steer_limit = clamp(1.0 - (speed / 55.0), 0.32, 1.0)
		var steer_rate = 11.0 if abs(steer) > 0.05 else 7.5
		steering = lerp(steering, steer * max_steer_angle * speed_steer_limit, steer_rate * delta)

		# Smoothly auto-center chase camera behind car while driving
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_key_pressed(KEY_Q) and not Input.is_key_pressed(KEY_E):
			camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, 0.0, 2.8 * delta)
	else:
		engine_force = 0.0
		brake = 25.0

func apply_anti_roll():
	var up = global_transform.basis.y
	if up.y > 0.2:
		var right = global_transform.basis.x
		var roll_angle = asin(clamp(right.y, -1.0, 1.0))
		apply_torque(global_transform.basis.z * roll_angle * anti_roll_stiffness)

func enter_vehicle(player_node):
	is_driven = true
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud and hud.has_method("on_vehicle_switched"):
		hud.on_vehicle_switched(name)
	driver = player_node
	driver.visible = false
	driver.set_physics_process(false)
	driver.get_node("CollisionShape3D").disabled = true
	car_cam.current = true
	get_parent().get_node("HUD/BottomHint").text = "WASD: Drive | Space: Drift | Shift: Nitro | F: Exit"

func exit_vehicle():
	if not is_driven or driver == null:
		return
	is_driven = false
	driver.global_position = global_position + global_transform.basis.x * 2.2 + Vector3.UP * 0.5
	driver.visible = true
	driver.set_physics_process(true)
	driver.get_node("CollisionShape3D").disabled = false
	driver.velocity = Vector3.ZERO
	driver.get_node("CameraPivot/SpringArm3D/Camera3D").current = true
	driver = null
	get_parent().get_node("HUD/BottomHint").text = "WASD: Move | Click+Drag or Q/E: Turn Camera | F: Enter Car"

func add_car_details():
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = false
	var body = CarBuilder.build_sculpted_car(Color(0.88, 0.12, 0.18), false)
	add_child(body)
	CarBuilder.style_wheels(self)
