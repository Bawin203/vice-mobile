extends VehicleBody3D

const CarBuilder = preload("res://car_builder.gd")
const OfficerScript = preload("res://police_officer.gd")

@export var chase_force = 3800.0
@export var max_steer = 0.65
var siren_timer = 0.0
var attack_cd = 0.0
var stuck_timer = 0.0
var reverse_timer = 0.0
var officers_deployed = false

@onready var light_bar = $SirenMesh

func _ready():
	mass = 1420.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.58, 0.05)
	for w in [$WheelFL, $WheelFR, $WheelRL, $WheelRR]:
		w.wheel_friction_slip = 3.8
		w.suspension_travel = 0.22
		w.suspension_stiffness = 38.0
	for child in get_children():
		if child is MeshInstance3D and child != light_bar:
			child.visible = false
	add_child(CarBuilder.build_sculpted_car(Color(0.08, 0.10, 0.14), true))
	CarBuilder.style_wheels(self)

func _physics_process(delta):
	attack_cd = max(0.0, attack_cd - delta)
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	var wanted = hud.wanted_level if hud else 0

	var mat = light_bar.get_active_material(0) as StandardMaterial3D
	if wanted > 0:
		siren_timer += delta * 14.0
		if mat:
			var red = sin(siren_timer) > 0
			mat.albedo_color = Color(1, 0.1, 0.1) if red else Color(0.1, 0.35, 1)
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 4.0
	else:
		officers_deployed = false
		if mat:
			mat.albedo_color = Color(0.15, 0.25, 0.45)
			mat.emission_energy_multiplier = 0.4
		steering = 0.0
		engine_force = 1100.0 if linear_velocity.length() < 12.0 else 0.0
		brake = 0.0
		if abs(global_position.z) > 135.0:
			global_position.z = -sign(global_position.z) * 130.0
		return

	if hud and hud.get("dispatch_delay") != null and hud.dispatch_delay > 0.0:
		engine_force = 0.0
		brake = 40.0
		return
	var target = get_active_target()
	if target == null:
		return

	var to_target = target.global_position - global_position
	var dist = to_target.length()
	to_target.y = 0
	var forward = global_transform.basis.z
	forward.y = 0
	var angle = forward.signed_angle_to(to_target.normalized(), Vector3.UP)

	if dist > 45.0:
		officers_deployed = false

	if reverse_timer > 0.0:
		reverse_timer -= delta
		steering = -clamp(angle * 1.5, -max_steer, max_steer)
		engine_force = -2800.0
		brake = 0.0
		return

	if linear_velocity.length() < 1.2 and dist > 8.5:
		stuck_timer += delta
		if stuck_timer > 1.0:
			stuck_timer = 0.0
			reverse_timer = 1.0
			return
	else:
		stuck_timer = 0.0

	steering = clamp(angle * 1.75, -max_steer, max_steer)
	var top_chase_speed = 28.0 + wanted * 3.5

	if dist < 18.0 and not officers_deployed:
		deploy_officers()

	if dist < 9.0 and officers_deployed:
		engine_force = 0.0
		brake = 100.0
	elif dist < 5.5:
		brake = 0.0
		engine_force = chase_force * 0.7
	else:
		brake = 0.0
		engine_force = chase_force if linear_velocity.length() < top_chase_speed else 0.0

	if dist < 4.6 and attack_cd == 0.0:
		attack_cd = 1.1
		if hud:
			hud.damage_player(10)

	var target_speed = target.linear_velocity.length() if target is VehicleBody3D else target.velocity.length()
	if dist < 4.4 and target_speed < 2.2 and hud and hud.has_method("advance_bust"):
		hud.advance_bust(delta)

func deploy_officers():
	officers_deployed = true
	var main = get_tree().current_scene
	if main == null:
		return
	var right_vec = global_transform.basis.x
	for side in [-1.0, 1.0]:
		var cop = CharacterBody3D.new()
		cop.set_script(OfficerScript)
		main.add_child(cop)
		cop.global_position = global_position + right_vec * (2.4 * side) + Vector3(0, 0.9, 0)

func get_active_target():
	var main = get_tree().current_scene
	for child in main.get_children():
		if child is VehicleBody3D and child.get("is_driven") == true:
			return child
	var city = main.get_node_or_null("CityGenerator")
	if city:
		for child in city.get_children():
			if child is VehicleBody3D and child.get("is_driven") == true:
				return child
	return main.get_node_or_null("Player")
