extends Node3D

var race_active = false
var rival: VehicleBody3D
var cp_area: Area3D
var cp_idx = 0
var route = [
	Vector3(0, 0.5, -72),
	Vector3(72, 0.5, -72),
	Vector3(72, 0.5, 0),
	Vector3(0, 0.5, 0)
]

func _ready():
	build_start_gate()

func build_start_gate():
	var gate = Area3D.new()
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(7.0, 4.0, 5.0)
	col.shape = bs
	gate.add_child(col)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.55, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 1.0)

	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(7.0, 0.25, 5.0)
	bm.material = mat
	m.mesh = bm
	gate.add_child(m)

	gate.body_entered.connect(_on_start_gate)
	add_child(gate)
	gate.global_position = Vector3(0, 0.1, -22)

func _on_start_gate(body):
	if race_active: return
	if body is VehicleBody3D and body.get("is_driven") == true:
		start_race()

func start_race():
	race_active = true
	cp_idx = 0
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud: hud.get_node("BottomHint").text = "STREET RACE STARTED! Hit the Blue Checkpoints to Win $1,000!"

	rival = VehicleBody3D.new()
	rival.mass = 1200.0
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(2.0, 0.8, 4.2)
	col.shape = bs
	rival.add_child(col)

	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(2.0, 0.8, 4.2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.95, 0.25)
	bm.material = mat
	mesh.mesh = bm
	mesh.position.y = 0.4
	rival.add_child(mesh)

	for wx in [-1.0, 1.0]:
		for wz in [-1.3, 1.3]:
			var w = VehicleWheel3D.new()
			w.position = Vector3(wx, 0.3, wz)
			w.wheel_radius = 0.4
			w.use_as_traction = true
			w.use_as_steering = wz > 0
			rival.add_child(w)

	add_child(rival)
	rival.global_position = Vector3(-3.2, 0.8, -22)
	rival.rotation.y = PI

	cp_area = Area3D.new()
	var cc = CollisionShape3D.new()
	var cs = SphereShape3D.new()
	cs.radius = 5.5
	cc.shape = cs
	cp_area.add_child(cc)

	var cm = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 4.5
	cyl.bottom_radius = 4.5
	cyl.height = 16.0
	var cmat = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.1, 0.65, 1.0, 0.45)
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.emission_enabled = true
	cmat.emission = Color(0.1, 0.6, 1.0)
	cyl.material = cmat
	cm.mesh = cyl
	cm.position.y = 8.0
	cp_area.add_child(cm)
	cp_area.body_entered.connect(_on_cp_hit)
	add_child(cp_area)
	cp_area.global_position = route[0]

func _physics_process(_delta):
	if not race_active or not is_instance_valid(rival): return
	var target = route[cp_idx]
	var to_t = target - rival.global_position
	to_t.y = 0
	var fwd = rival.global_transform.basis.z
	fwd.y = 0
	rival.steering = clamp(fwd.signed_angle_to(to_t.normalized(), Vector3.UP), -0.5, 0.5)
	rival.engine_force = 2400.0 if rival.linear_velocity.length() < 21.0 else 0.0
	if to_t.length() < 7.0:
		if cp_idx == route.size() - 1:
			finish_race(false)

func _on_cp_hit(body):
	if not race_active: return
	if body is VehicleBody3D and body.get("is_driven") == true:
		cp_idx += 1
		if cp_idx >= route.size():
			finish_race(true)
		else:
			cp_area.global_position = route[cp_idx]

func finish_race(player_won):
	race_active = false
	if is_instance_valid(rival): rival.queue_free()
	if is_instance_valid(cp_area): cp_area.queue_free()
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	var mm = get_tree().current_scene.get_node_or_null("MissionManager")
	if player_won:
		if mm: mm.cash += 1000
		if hud: hud.get_node("BottomHint").text = "YOU WON THE STREET RACE! +$1,000!"
	else:
		if hud: hud.get_node("BottomHint").text = "RIVAL WON THE RACE! Drive to Blue Gate to Retry."
