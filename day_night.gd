extends Node

@export var cycle_speed = 0.0008
var time_of_day = 0.25 # Starts in bright morning, smoothly transitions to sunset & neon night
var headlights = []

func _ready():
	attach_headlights("SportsCar")

func attach_headlights(car_name: String):
	var car = get_parent().get_node_or_null(car_name)
	if car == null:
		return
	for side in [-0.65, 0.65]:
		var spot = SpotLight3D.new()
		spot.position = Vector3(side, 0.55, 2.15)
		spot.rotation_degrees = Vector3(-8, 180, 0)
		spot.spot_range = 32.0
		spot.spot_angle = 35.0
		spot.light_energy = 0.0
		spot.light_color = Color(1.0, 0.96, 0.85)
		car.add_child(spot)
		headlights.append(spot)

func _process(delta):
	time_of_day = fmod(time_of_day + delta * cycle_speed, 1.0)
	var sun = get_parent().get_node_or_null("DirectionalLight3D")
	var env_node = get_parent().get_node_or_null("WorldEnvironment")
	if sun == null or env_node == null:
		return

	var sun_angle = time_of_day * TAU
	sun.rotation.x = -sin(sun_angle) * 1.2 - 0.2
	sun.rotation.y = cos(sun_angle) * 0.8

	var day_factor = clamp(sin(sun_angle) * 1.5 + 0.3, 0.0, 1.0)
	sun.light_energy = lerp(0.55, 1.65, day_factor)
	sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.98, 0.92), day_factor)

	var sky_mat = env_node.environment.sky.sky_material as ProceduralSkyMaterial
	if sky_mat:
		sky_mat.sky_top_color = Color(0.03, 0.04, 0.12).lerp(Color(0.22, 0.52, 0.88), day_factor)
		sky_mat.sky_horizon_color = Color(0.18, 0.08, 0.25).lerp(Color(0.65, 0.78, 0.92), day_factor)

	var night_on = day_factor < 0.35
	for h in headlights:
		if is_instance_valid(h):
			h.light_energy = 4.5 if night_on else 0.0

var storm_mode: bool = false

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		storm_mode = not storm_mode
		var main = get_tree().current_scene
		if main == null: return
		var we = main.get_node_or_null("WorldEnvironment")
		var hud = main.get_node_or_null("HUD")
		if we and we.environment:
			if storm_mode:
				we.environment.fog_light_color = Color(0.22, 0.28, 0.36)
				we.environment.fog_density = 0.0085
				we.environment.tonemap_exposure = 0.82
			else:
				we.environment.fog_light_color = Color(0.55, 0.68, 0.85)
				we.environment.fog_density = 0.0022
				we.environment.tonemap_exposure = 1.12
		if hud and hud.get_node_or_null("BottomHint"):
			hud.get_node("BottomHint").text = "WEATHER: %s ([T] to Toggle)" % ("LEONIDA TROPICAL STORM" if storm_mode else "CLEAR MIAMI SKIES")
