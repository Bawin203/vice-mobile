extends Node3D

var turbo_level = 1
var panel: PanelContainer
var status_lbl: Label
var active_car: VehicleBody3D = null

var paints = [
	{"name": "MAGENTA", "col": Color(0.95, 0.12, 0.65)},
	{"name": "CYAN", "col": Color(0.08, 0.85, 0.98)},
	{"name": "BLACK", "col": Color(0.07, 0.07, 0.09)},
	{"name": "GOLD", "col": Color(0.95, 0.78, 0.15)},
	{"name": "GREEN", "col": Color(0.1, 0.8, 0.35)},
	{"name": "RED", "col": Color(0.9, 0.12, 0.12)}
]

func _ready():
	build_bay()
	build_menu_ui()

func build_bay():
	var bay = Area3D.new()
	bay.name = "PayNSpray"
	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(7.5, 4.5, 9.0)
	col.shape = bs
	bay.add_child(col)

	var neon = StandardMaterial3D.new()
	neon.albedo_color = Color(0.95, 0.15, 0.85)
	neon.emission_enabled = true
	neon.emission = Color(0.95, 0.15, 0.85)

	var pad_mat = StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.95, 0.15, 0.85, 0.45)
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_mat.emission_enabled = true
	pad_mat.emission = Color(0.85, 0.1, 0.8)

	add_box(bay, Vector3(7.0, 0.18, 8.5), pad_mat, Vector3(0, 0.09, 0))
	add_box(bay, Vector3(7.4, 0.4, 8.9), neon, Vector3(0, 4.4, 0))
	for px in [-3.2, 3.2]:
		for pz in [-3.8, 3.8]:
			add_box(bay, Vector3(0.4, 4.4, 0.4), neon, Vector3(px, 2.2, pz))

	bay.body_entered.connect(_on_enter_garage)
	add_child(bay)
	bay.global_position = Vector3(-12, 0.0, -4)

func add_box(parent, sz, mat, pos):
	var m = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	bm.material = mat
	m.mesh = bm
	m.position = pos
	parent.add_child(m)

func build_menu_ui():
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud == null: return

	var center_box = CenterContainer.new()
	center_box.name = "GarageCenter"
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_box.visible = false
	hud.add_child(center_box)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center_box.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "PAY N SPRAY MOD SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	status_lbl = Label.new()
	status_lbl.text = "Pick an upgrade:"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_lbl)

	var clear_btn = Button.new()
	clear_btn.text = "Clear Wanted Stars ($100)"
	clear_btn.pressed.connect(buy_clear_wanted)
	vbox.add_child(clear_btn)

	var grid = GridContainer.new()
	grid.columns = 3
	for p in paints:
		var b = Button.new()
		b.text = "%s
$150" % p["name"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(buy_paint.bind(p))
		grid.add_child(b)
	vbox.add_child(grid)

	var turbo_btn = Button.new()
	turbo_btn.text = "Twin-Turbo Engine ($350)"
	turbo_btn.pressed.connect(buy_turbo)
	vbox.add_child(turbo_btn)

	var repair_btn = Button.new()
	repair_btn.text = "Full Armor & HP ($200)"
	repair_btn.pressed.connect(buy_repair)
	vbox.add_child(repair_btn)

	var close_btn = Button.new()
	close_btn.text = "CLOSE MENU"
	close_btn.pressed.connect(func(): center_box.visible = false)
	vbox.add_child(close_btn)

func _process(_delta):
	var cb = get_tree().current_scene.get_node_or_null("HUD/GarageCenter")
	if cb and cb.visible and active_car:
		if active_car.global_position.distance_to(Vector3(-12, 0, -4)) > 11.0:
			cb.visible = false

func _on_enter_garage(body):
	if body is VehicleBody3D and body.get("is_driven") == true:
		active_car = body
		var mm = get_tree().current_scene.get_node_or_null("MissionManager")
		var cash_now = mm.cash if mm else 0
		status_lbl.text = "Your Cash: $%d" % cash_now
		get_tree().current_scene.get_node("HUD/GarageCenter").visible = true

func buy_clear_wanted():
	var mm = get_tree().current_scene.get_node_or_null("MissionManager")
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if mm == null or hud == null: return
	if mm.cash >= 100:
		mm.cash -= 100
		hud.wanted_level = 0
		hud.police_spawned = false
		hud.update_hud()
		for c in get_tree().current_scene.get_children():
			if c.name.begins_with("PoliceCar"): c.queue_free()
		status_lbl.text = "Wanted Cleared! Cash: $%d" % mm.cash
	else:
		status_lbl.text = "Need $100 (You have $%d)" % mm.cash

func buy_paint(p):
	var mm = get_tree().current_scene.get_node_or_null("MissionManager")
	if mm == null or active_car == null: return
	if mm.cash >= 150:
		mm.cash -= 150
		var m = StandardMaterial3D.new()
		m.albedo_color = p["col"]
		m.metallic = 0.88
		m.roughness = 0.12
		m.clearcoat = 1.0
		paint_recursive(active_car, m)
		status_lbl.text = "Painted %s! Cash: $%d" % [p["name"], mm.cash]
	else:
		status_lbl.text = "Need $150 (You have $%d)" % mm.cash

func buy_turbo():
	var mm = get_tree().current_scene.get_node_or_null("MissionManager")
	if mm == null or active_car == null: return
	if turbo_level >= 4:
		status_lbl.text = "Turbo MAX Lv.4!"
		return
	if mm.cash >= 350:
		mm.cash -= 350
		turbo_level += 1
		active_car.max_engine_force += 950.0
		status_lbl.text = "Turbo Lv.%d Installed! Cash: $%d" % [turbo_level, mm.cash]
	else:
		status_lbl.text = "Need $350 (You have $%d)" % mm.cash

func buy_repair():
	var mm = get_tree().current_scene.get_node_or_null("MissionManager")
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if mm == null or hud == null: return
	if mm.cash >= 200:
		mm.cash -= 200
		hud.damage_player(-100)
		status_lbl.text = "Full HP Restored! Cash: $%d" % mm.cash
	else:
		status_lbl.text = "Need $200 (You have $%d)" % mm.cash

func paint_recursive(node: Node, mat: Material):
	if node is MeshInstance3D and ("body" in node.name.to_lower() or "Mesh" in node.name):
		node.material_override = mat
	for c in node.get_children():
		paint_recursive(c, mat)
