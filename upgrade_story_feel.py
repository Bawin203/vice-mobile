# 1. Upgrade mission_manager.gd with [J] Mission Journal, Live Crew Radio Comms, & AI Crew Wingmen
open("mission_manager.gd", "w").write("""extends Node3D

var cash: int = 500
var bank_balance: int = 1000
var marker: Area3D

# Story Stages:
# 0 = Ch 1: Repo & Madrazo's Debt
# 1 = Ch 2: Vangelico Heist
# 2 = Ch 2 Escape: Lose the 3-Star FIB/Police Pursuit
# 3 = Ch 3: Triad Ambush Rescue
# 4 = Ch 4: The Union Depository Big Score
# 5 = Ch 4 Escape: Lose 4-Star SWAT/FIB Pursuit
# 6 = Ch 5: Franklin's Phone Ultimatum (Option A / B / C)
# 7 = Ch 5 Final Showdown
# 8 = Story Complete / Free Roam
var story_stage: int = 0
var story_elapsed: float = 0.0
var chosen_ending: String = "C"

var protagonists = [
	{"name": "FRANKLIN", "shirt": Color(0.16, 0.68, 0.32), "pants": Color(0.14, 0.16, 0.22)},
	{"name": "MICHAEL", "shirt": Color(0.18, 0.38, 0.72), "pants": Color(0.18, 0.18, 0.22)},
	{"name": "TREVOR", "shirt": Color(0.78, 0.76, 0.72), "pants": Color(0.26, 0.22, 0.18)}
]
var active_protag_idx: int = 0

var mission_targets: Array[Node3D] = []
var wingmen: Array[Node3D] = []
var targets_total: int = 0
var targets_killed: int = 0

var last_brief_title: String = ""
var last_brief_story: String = ""
var last_brief_task: String = ""

var briefing_panel: PanelContainer = null
var briefing_title: Label = null
var briefing_story: Label = null
var briefing_task: Label = null

var objective_panel: PanelContainer = null
var obj_header: Label = null
var obj_detail: Label = null

var comms_panel: PanelContainer = null
var comms_label: Label = null
var comms_timer: float = 0.0

var ultimatum_panel: PanelContainer = null
var victory_panel: PanelContainer = null
var stats_label: Label = null

const REPO_DROP_POS = Vector3(18.0, 0.5, -18.0)
const VANGELICO_POS = Vector3(-36.0, 0.5, 14.0)
const TRIAD_AMBUSH_POS = Vector3(54.0, 0.5, 54.0)
const UNION_DEPO_POS = Vector3(-54.0, 0.5, -18.0)
const FINALE_POS = Vector3(18.0, 0.5, 54.0)

var free_roam_waypoints = [
	Vector3(0, 0.5, -36),
	Vector3(36, 0.5, -72),
	Vector3(-36, 0.5, -72),
	Vector3(-118, 0.5, -128),
	Vector3(-118, 0.5, 128)
]
var wp_idx: int = 0

func _ready() -> void:
	create_checkpoint_beacon()
	build_story_ui()
	marker.global_position = REPO_DROP_POS

func start_heist_campaign() -> void:
	if story_stage == 0:
		apply_protagonist(0, false)
		marker.visible = true
		marker.global_position = REPO_DROP_POS
		set_gps_target(REPO_DROP_POS, "REPO DROP-OFF")
		show_chapter_briefing(
			"CHAPTER 1: REPO & MADRAZO'S DEBT",
			"FRANKLIN: 'Simeon's got me boosting rides across town—and Michael just tore down cartel boss Martin Madrazo's deck. We owe $2,500 fast.'",
			"1. Walk up to the red Sports Car (or any street car) and press [F] to get in.\\n2. Follow the glowing purple GPS road line to the YELLOW REPO BEACON.\\n(Tip: Press [J] anytime during gameplay to re-read your current task!)"
		)

func show_chapter_briefing(title_txt: String, story_txt: String, task_txt: String) -> void:
	last_brief_title = title_txt
	last_brief_story = story_txt
	last_brief_task = task_txt
	if briefing_panel == null: return
	briefing_title.text = title_txt
	briefing_story.text = story_txt
	briefing_task.text = "YOUR TASK:\\n" + task_txt
	briefing_panel.visible = true
	get_tree().paused = true

func push_radio_comms(speaker: String, line: String, col: Color = Color(0.3, 0.92, 1.0)) -> void:
	if comms_panel == null or comms_label == null: return
	comms_label.text = "%s: \"%s\"" % [speaker, line]
	comms_label.add_theme_color_override("font_color", col)
	comms_panel.visible = true
	comms_timer = 5.2

func apply_protagonist(idx: int, announce: bool = true) -> void:
	active_protag_idx = idx % protagonists.size()
	var data = protagonists[active_protag_idx]
	var root = get_parent()
	if root == null: return
	var p = root.get_node_or_null("Player")
	if p and p.human_node and p.human_node.has_method("build_human"):
		p.human_node.build_human(data["shirt"], data["pants"], true)
	if announce:
		push_radio_comms(data["name"], "Taking point! ([H] Switch Crew | [J] View Task)", Color(1.0, 0.85, 0.25))

func set_gps_target(world_pos: Vector3, label_name: String) -> void:
	var root = get_parent()
	if root == null: return
	var mm_ui = root.get_node_or_null("HUD/Minimap")
	if mm_ui:
		mm_ui.waypoint_world = world_pos
		mm_ui.has_waypoint = true
		mm_ui.waypoint_title = label_name

func on_bank_robbed() -> void:
	if story_stage == 1:
		story_stage = 2
		set_gps_target(Vector3(36.0, 0.5, 14.0), "PAY 'N' SPRAY (ESCAPE)")
		show_chapter_briefing(
			"CHAPTER 2: HEAT ON THE STREETS",
			"LESTER: 'Alarms tripped! Corrupt FIB agent Dave Norton just put a 3-star APB on your plates. Lose the cops before we plan the next move!'",
			"1. Sprint to your getaway car and press [F] to drive.\\n2. Drive into PAY 'N' SPRAY ('G' on map) OR outrun police sightlines until all 3 stars vanish."
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			deposit_to_buckme()
		elif event.keycode == KEY_H:
			var unlocked_count = 1 if story_stage < 1 else (2 if story_stage < 3 else 3)
			apply_protagonist((active_protag_idx + 1) % unlocked_count, true)
		elif event.keycode == KEY_J:
			if briefing_panel and not briefing_panel.visible and last_brief_title != "":
				show_chapter_briefing(last_brief_title, last_brief_story, last_brief_task)

func deposit_to_buckme() -> void:
	if cash <= 0:
		push_radio_comms("BUCKME APP", "Wallet is empty ($0 to deposit).", Color(0.8, 0.85, 0.9))
		return
	var amt = cash
	bank_balance += amt
	cash = 0
	push_radio_comms("BUCKME APP", "Deposited $%d! Safe Bank Balance: $%d" % [amt, bank_balance], Color(0.3, 0.95, 0.5))

func create_checkpoint_beacon() -> void:
	marker = Area3D.new()
	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 4.5
	cyl.height = 6.0
	col.shape = cyl
	marker.add_child(col)

	var mesh = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 3.6
	cm.bottom_radius = 3.6
	cm.height = 16.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.1)
	cm.material = mat
	mesh.mesh = cm
	mesh.position.y = 8.0
	marker.add_child(mesh)

	marker.body_entered.connect(_on_checkpoint_reached)
	add_child(marker)

func spawn_crew_wingmen(indices: Array[int]) -> void:
	clear_wingmen()
	var root = get_parent()
	if root == null: return
	var p = root.get_node_or_null("Player")
	if p == null: return
	var rig_script = load("res://human_rig.gd")

	var side = -2.2
	for idx in indices:
		var data = protagonists[idx % protagonists.size()]
		var ally = CharacterBody3D.new()
		ally.name = "Wingman_%s" % data["name"]
		var col = CollisionShape3D.new()
		var cap = CapsuleShape3D.new()
		cap.radius = 0.5
		cap.height = 1.8
		col.shape = cap
		col.position.y = 0.9
		ally.add_child(col)

		var rig = Node3D.new()
		rig.set_script(rig_script)
		ally.add_child(rig)
		rig.build_human(data["shirt"], data["pants"], false)

		var sc = GDScript.new()
		sc.source_code = "extends CharacterBody3D\\nvar fire_cd = 0.8\\nfunc _physics_process(delta):\\n\\tfire_cd = max(0.0, fire_cd - delta)\\n\\tvar main = get_tree().current_scene\\n\\tif main == null: return\\n\\tvar p = main.get_node_or_null(\\"Player\\")\\n\\tif p == null: return\\n\\tvisible = p.visible\\n\\tif not visible: return\\n\\tvar to_p = p.global_position - global_position\\n\\tto_p.y = 0\\n\\tif to_p.length() > 32.0:\\n\\t\\tglobal_position = p.global_position + Vector3(2.2, 0.2, 2.2)\\n\\telif to_p.length() > 3.6:\\n\\t\\tvelocity.x = to_p.normalized().x * 6.5\\n\\t\\tvelocity.z = to_p.normalized().z * 6.5\\n\\telse:\\n\\t\\tvelocity.x = 0\\n\\t\\tvelocity.z = 0\\n\\tif not is_on_floor(): velocity.y -= 9.8 * delta\\n\\tmove_and_slide()\\n\\tif fire_cd == 0.0:\\n\\t\\tfor n in main.get_children():\\n\\t\\t\\tif n.name.begins_with(\\"StoryTarget_\\") and n.global_position.distance_to(global_position) < 24.0:\\n\\t\\t\\t\\tfire_cd = 1.1\\n\\t\\t\\t\\tif n.has_method(\\"take_damage\\"): n.take_damage(25)\\n\\t\\t\\t\\tbreak\\n"
		sc.reload()
		ally.set_script(sc)
		root.add_child(ally)
		ally.global_position = p.global_position + Vector3(side, 0.2, -1.5)
		side += 4.4
		wingmen.append(ally)

func clear_wingmen() -> void:
	for w in wingmen:
		if is_instance_valid(w):
			w.queue_free()
	wingmen.clear()

func spawn_mission_enemies(center: Vector3, count: int, shirt_col: Color) -> void:
	clear_mission_enemies()
	targets_total = count
	targets_killed = 0
	var root = get_parent()
	if root == null: return

	var offsets = [Vector3(-4.0, 0.5, 4.0), Vector3(4.0, 0.5, 4.0), Vector3(0.0, 0.5, -3.5), Vector3(5.0, 0.5, -2.0)]
	for i in range(count):
		var enemy = CharacterBody3D.new()
		enemy.name = "StoryTarget_%d" % i
		var col = CollisionShape3D.new()
		var cap = CapsuleShape3D.new()
		cap.radius = 0.55
		cap.height = 1.85
		col.shape = cap
		col.position.y = 0.92
		enemy.add_child(col)

		var rig_script = load("res://human_rig.gd")
		var rig = Node3D.new()
		rig.set_script(rig_script)
		enemy.add_child(rig)
		rig.build_human(shirt_col, Color(0.1, 0.1, 0.14), false)

		var sc = GDScript.new()
		sc.source_code = "extends CharacterBody3D\\nvar hp = 85\\nvar shoot_cd = 1.2\\nfunc _physics_process(delta):\\n\\tshoot_cd = max(0.0, shoot_cd - delta)\\n\\tvar main = get_tree().current_scene\\n\\tif main == null: return\\n\\tvar p = main.get_node_or_null(\\"Player\\")\\n\\tif p == null: return\\n\\tvar d = global_position.distance_to(p.global_position)\\n\\tif d < 26.0 and shoot_cd == 0.0:\\n\\t\\tshoot_cd = 1.35\\n\\t\\tvar hud = main.get_node_or_null(\\"HUD\\")\\n\\t\\tif hud and p.visible:\\n\\t\\t\\thud.damage_player(5)\\nfunc take_damage(dmg):\\n\\thp -= dmg\\n\\tif hp <= 0:\\n\\t\\tvar mm = get_tree().current_scene.get_node_or_null(\\"MissionManager\\")\\n\\t\\tif mm and mm.has_method(\\"on_story_target_killed\\"):\\n\\t\\t\\tmm.on_story_target_killed(self)\\n\\t\\tqueue_free()\\n"
		sc.reload()
		enemy.set_script(sc)
		root.add_child(enemy)
		enemy.global_position = center + offsets[i % offsets.size()]
		mission_targets.append(enemy)

func clear_mission_enemies() -> void:
	for e in mission_targets:
		if is_instance_valid(e):
			e.queue_free()
	mission_targets.clear()

func on_story_target_killed(enemy: Node3D) -> void:
	targets_killed += 1
	mission_targets.erase(enemy)
	var rem = targets_total - targets_killed
	if rem > 0:
		push_radio_comms("CREW", "Target down! %d remaining—keep pushing!" % rem, Color(1.0, 0.45, 0.35))
	if story_stage == 3 and targets_killed >= targets_total:
		advance_story_beacon()
	elif story_stage == 7 and targets_killed >= targets_total:
		advance_story_beacon()

func _process(delta: float) -> void:
	if comms_timer > 0.0:
		comms_timer -= delta
		if comms_timer <= 0.0 and comms_panel:
			comms_panel.visible = false

	if story_stage < 8:
		story_elapsed += delta
	var root = get_parent()
	if root == null: return
	var hud = root.get_node_or_null("HUD")
	if hud == null: return

	hud.get_node("TopRight/SpeedLabel").text = "$%05d  |  BANK $%05d" % [cash, bank_balance]

	var p = root.get_node_or_null("Player")
	var active_pos = p.global_position if p else Vector3.ZERO
	for c in root.get_children():
		if c is VehicleBody3D and c.get("is_driven") == true:
			active_pos = c.global_position
			break

	update_objective_tracker(active_pos, hud.wanted_level)

	if story_stage == 2 and hud.wanted_level == 0:
		story_stage = 3
		apply_protagonist(2, false)
		spawn_crew_wingmen([0])
		marker.visible = true
		marker.global_position = TRIAD_AMBUSH_POS
		set_gps_target(TRIAD_AMBUSH_POS, "TRIAD AMBUSH SITE")
		spawn_mission_enemies(TRIAD_AMBUSH_POS, 3, Color(0.85, 0.15, 0.15))
		show_chapter_briefing(
			"CHAPTER 3: TRIAD AMBUSH RESCUE",
			"TREVOR: 'Michael's been grabbed by Wei Cheng's Triad hit squad! Franklin's riding shotgun with me—grab your piece and let's go!'",
			"1. Drive to the TRIAD AMBUSH SITE (54, 54) following the purple GPS line.\\n2. Aim with your crosshair and shoot ([Right-Click] or [R]) with Franklin to wipe out all 3 Triad Guards!"
		)

	elif story_stage == 5 and hud.wanted_level == 0:
		story_stage = 6
		clear_wingmen()
		open_ultimatum_phone()

	if marker.visible and story_stage in [0, 4]:
		if Vector2(active_pos.x, active_pos.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z)) < 8.5:
			advance_story_beacon()

func update_objective_tracker(active_pos: Vector3, wanted: int) -> void:
	if obj_header == null or obj_detail == null: return
	var protag = protagonists[active_protag_idx]["name"]
	var dist = int(Vector2(active_pos.x, active_pos.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z)))

	match story_stage:
		0:
			obj_header.text = "CH 1: THE REPO  •  %s  [J] Info" % protag
			obj_detail.text = "Drive any car ([F]) to the Yellow Repo Beacon (%dm)" % dist
		1:
			var b_dist = int(Vector2(active_pos.x, active_pos.z).distance_to(Vector2(VANGELICO_POS.x, VANGELICO_POS.z)))
			obj_header.text = "CH 2: VANGELICO HEIST  •  %s  [J] Info" % protag
			obj_detail.text = "Enter Pacific Bank/Jewelry ('$') & step on vault pad (%dm)" % b_dist
		2:
			obj_header.text = "CH 2: ESCAPE THE HEAT  •  %s  [J] Info" % protag
			obj_detail.text = "Lose all %d Wanted Stars (Evade cops or visit Pay 'n' Spray 'G')" % wanted
		3:
			obj_header.text = "CH 3: TRIAD RESCUE  •  %s  [J] Info" % protag
			obj_detail.text = "Eliminate Triad Guards at Ambush (%d/%d Killed • %dm)" % [targets_killed, targets_total, dist]
		4:
			obj_header.text = "CH 4: THE BIG SCORE  •  %s  [J] Info" % protag
			obj_detail.text = "Reach Union Depository Gold Vault Beacon (%dm)" % dist
		5:
			obj_header.text = "CH 4: ESCAPE SWEEP  •  %s  [J] Info" % protag
			obj_detail.text = "Escape the %d-Star SWAT/FIB Blockade to unlock Finale!" % wanted
		6:
			obj_header.text = "CH 5: THE ULTIMATUM  •  FRANKLIN"
			obj_detail.text = "Choose Option A, B, or C on Franklin's Phone"
		7:
			obj_header.text = "CH 5: ENDING %s SHOWDOWN  •  %s  [J] Info" % [chosen_ending, protag]
			obj_detail.text = "Eliminate Final Targets at Showdown (%d/%d Killed • %dm)" % [targets_killed, targets_total, dist]
		8:
			obj_header.text = "FREE ROAM  •  %s ([H] Switch | [J] Journal)" % protag
			obj_detail.text = "Story Complete! Collect Checkpoints (%dm) or fly Jets/Tanks" % dist

func _on_checkpoint_reached(body: Node3D) -> void:
	var is_player = body.name == "Player" or (body is VehicleBody3D and body.get("is_driven") == true)
	if not is_player:
		return
	if story_stage == 8:
		cash += 500
		wp_idx = (wp_idx + 1) % free_roam_waypoints.size()
		marker.global_position = free_roam_waypoints[wp_idx]
	elif story_stage in [0, 4]:
		advance_story_beacon()

func advance_story_beacon() -> void:
	var root = get_parent()
	var hud = root.get_node_or_null("HUD") if root else null

	if story_stage == 0:
		story_stage = 1
		cash += 2500
		apply_protagonist(1, false)
		spawn_crew_wingmen([0])
		marker.visible = false
		set_gps_target(VANGELICO_POS, "VANGELICO / BANK ($)")
		show_chapter_briefing(
			"CHAPTER 2: THE VANGELICO JEWELRY HEIST",
			"MICHAEL: 'Madrazo's off our backs, now we need real score money. Franklin's backing me up—let's hit the Vangelico / Pacific Bank vault.'",
			"1. Follow the purple GPS line to PACIFIC BANK ('$' on map at -36, 14).\\n2. Walk or drive inside the open glass front doors onto the glowing yellow pad."
		)

	elif story_stage == 3:
		story_stage = 4
		cash += 3500
		apply_protagonist(0, false)
		spawn_crew_wingmen([1, 2])
		marker.visible = true
		marker.global_position = UNION_DEPO_POS
		set_gps_target(UNION_DEPO_POS, "UNION DEPOSITORY")
		show_chapter_briefing(
			"CHAPTER 4: THE UNION DEPOSITORY BIG SCORE",
			"LESTER: 'Michael's safe and the full trio is reunited! One final job: $20,000 in unmarked gold bullion sitting in the Union Depository vault.'",
			"1. Follow the purple GPS road line to the UNION DEPOSITORY (-54, -18).\\n2. Drive or walk into the yellow vault beacon with Michael & Trevor!"
		)

	elif story_stage == 4:
		story_stage = 5
		cash += 20000
		marker.visible = false
		if hud:
			hud.add_wanted(4, true)
		set_gps_target(Vector3(36.0, 0.5, 14.0), "PAY 'N' SPRAY (ESCAPE)")
		show_chapter_briefing(
			"CHAPTER 4: 4-STAR FIB & SWAT BLOCKADE",
			"MICHAEL: 'We got the gold! Every cruiser in the city is converging—shake this 4-star heat to trigger the final showdown!'",
			"1. Outrun the police cruisers or hit PAY 'N' SPRAY ('G' on map) to clear all 4 Wanted Stars."
		)

	elif story_stage == 7:
		story_stage = 8
		clear_wingmen()
		marker.visible = true
		marker.global_position = free_roam_waypoints[0]
		var mm_ui = root.get_node_or_null("HUD/Minimap")
		if mm_ui and mm_ui.has_method("clear_waypoint"):
			mm_ui.clear_waypoint()
		show_victory_screen()

func open_ultimatum_phone() -> void:
	if ultimatum_panel == null: return
	ultimatum_panel.visible = true
	get_tree().paused = true

func select_ending(opt: String) -> void:
	chosen_ending = opt
	if ultimatum_panel:
		ultimatum_panel.visible = false
	get_tree().paused = false
	story_stage = 7
	marker.visible = true
	marker.global_position = FINALE_POS
	set_gps_target(FINALE_POS, "FINAL SHOWDOWN")

	if opt == "A":
		apply_protagonist(0, false)
		spawn_crew_wingmen([1])
		cash += 10000
		spawn_mission_enemies(FINALE_POS, 1, Color(0.78, 0.76, 0.72))
		show_chapter_briefing(
			"CHAPTER 5 — ENDING A: SOMETHING SENSIBLE",
			"STEVE HAINES (FIB): 'Smart choice, kid. Michael's backing you up—take Trevor out at the Foundry and split his cut.'",
			"1. Drive to the FINAL SHOWDOWN beacon (18, 54).\\n2. Shoot and eliminate Trevor to complete Ending A."
		)
	elif opt == "B":
		apply_protagonist(0, false)
		clear_wingmen()
		spawn_mission_enemies(FINALE_POS, 1, Color(0.18, 0.38, 0.72))
		show_chapter_briefing(
			"CHAPTER 5 — ENDING B: THE TIME'S COME",
			"DEVIN WESTON: 'Trevor refused to help you, Franklin. Put Michael down yourself and you're set for life.'",
			"1. Drive to the FINAL SHOWDOWN beacon (18, 54).\\n2. Shoot and eliminate Michael to complete Ending B."
		)
	else:
		apply_protagonist(2, false)
		spawn_crew_wingmen([0, 1])
		spawn_mission_enemies(FINALE_POS, 3, Color(0.12, 0.14, 0.20))
		show_chapter_briefing(
			"CHAPTER 5 — ENDING C: THE THIRD WAY (CANON)",
			"FRANKLIN: 'Screw Haines and screw Weston—nobody's dying tonight except them! Full trio's rolling together!'",
			"1. Drive to the FOUNDRY SHOWDOWN (18, 54) with Franklin, Michael & Trevor.\\n2. Eliminate all 3 antagonists (Steve Haines, Wei Cheng & Devin Weston)!"
		)

func build_story_ui() -> void:
	var hud = get_parent().get_node_or_null("HUD")
	if hud == null: return

	# Always-visible Top-Left Objective Card
	objective_panel = PanelContainer.new()
	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.offset_left = 22
	objective_panel.offset_top = 46
	objective_panel.offset_right = 490
	objective_panel.offset_bottom = 104
	var ost = StyleBoxFlat.new()
	ost.bg_color = Color(0.05, 0.07, 0.12, 0.88)
	ost.border_color = Color(1.0, 0.82, 0.2, 0.85)
	ost.set_border_width_all(2)
	ost.set_corner_radius_all(6)
	ost.set_content_margin_all(8)
	objective_panel.add_theme_stylebox_override("panel", ost)

	var ov = VBoxContainer.new()
	ov.add_theme_constant_override("separation", 2)
	objective_panel.add_child(ov)

	obj_header = Label.new()
	obj_header.add_theme_font_size_override("font_size", 13)
	obj_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	ov.add_child(obj_header)

	obj_detail = Label.new()
	obj_detail.add_theme_font_size_override("font_size", 12)
	obj_detail.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	ov.add_child(obj_detail)
	hud.add_child(objective_panel)

	# Live Top-Center Crew Radio Comms Toast
	comms_panel = PanelContainer.new()
	comms_panel.visible = false
	comms_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	comms_panel.offset_left = -240
	comms_panel.offset_top = 18
	comms_panel.offset_right = 240
	comms_panel.offset_bottom = 54
	var cst = StyleBoxFlat.new()
	cst.bg_color = Color(0.05, 0.07, 0.12, 0.92)
	cst.border_color = Color(0.25, 0.9, 1.0, 0.85)
	cst.set_border_width_all(2)
	cst.set_corner_radius_all(8)
	cst.set_content_margin_all(6)
	comms_panel.add_theme_stylebox_override("panel", cst)

	comms_label = Label.new()
	comms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comms_label.add_theme_font_size_override("font_size", 13)
	comms_panel.add_child(comms_label)
	hud.add_child(comms_panel)

	# Mission Journal / Chapter Briefing Modal ([J] anytime)
	briefing_panel = PanelContainer.new()
	briefing_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	briefing_panel.visible = false
	briefing_panel.set_anchors_preset(Control.PRESET_CENTER)
	briefing_panel.offset_left = -285
	briefing_panel.offset_top = -185
	briefing_panel.offset_right = 285
	briefing_panel.offset_bottom = 185

	var bst = StyleBoxFlat.new()
	bst.bg_color = Color(0.04, 0.05, 0.10, 0.96)
	bst.border_color = Color(0.2, 0.88, 1.0)
	bst.set_border_width_all(3)
	bst.set_corner_radius_all(12)
	bst.set_content_margin_all(20)
	briefing_panel.add_theme_stylebox_override("panel", bst)

	var bv = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 12)
	briefing_panel.add_child(bv)

	briefing_title = Label.new()
	briefing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	briefing_title.add_theme_font_size_override("font_size", 21)
	briefing_title.add_theme_color_override("font_color", Color(0.25, 0.92, 1.0))
	bv.add_child(briefing_title)

	briefing_story = Label.new()
	briefing_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_story.add_theme_font_size_override("font_size", 14)
	briefing_story.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	bv.add_child(briefing_story)

	briefing_task = Label.new()
	briefing_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing_task.add_theme_font_size_override("font_size", 14)
	briefing_task.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))
	bv.add_child(briefing_task)

	var go_btn = Button.new()
	go_btn.text = "RESUME / START OBJECTIVE"
	go_btn.custom_minimum_size = Vector2(230, 44)
	go_btn.pressed.connect(func():
		briefing_panel.visible = false
		get_tree().paused = false
	)
	bv.add_child(go_btn)
	hud.add_child(briefing_panel)

	# Option A / B / C Phone Ultimatum Overlay
	ultimatum_panel = PanelContainer.new()
	ultimatum_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	ultimatum_panel.visible = false
	ultimatum_panel.set_anchors_preset(Control.PRESET_CENTER)
	ultimatum_panel.offset_left = -265
	ultimatum_panel.offset_top = -185
	ultimatum_panel.offset_right = 265
	ultimatum_panel.offset_bottom = 185

	var u_style = StyleBoxFlat.new()
	u_style.bg_color = Color(0.05, 0.06, 0.11, 0.96)
	u_style.border_color = Color(1.0, 0.78, 0.15)
	u_style.set_border_width_all(3)
	u_style.set_corner_radius_all(12)
	u_style.set_content_margin_all(18)
	ultimatum_panel.add_theme_stylebox_override("panel", u_style)

	var uv = VBoxContainer.new()
	uv.add_theme_constant_override("separation", 10)
	ultimatum_panel.add_child(uv)

	var utitle = Label.new()
	utitle.text = "FRANKLIN'S PHONE — THE ULTIMATUM"
	utitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	utitle.add_theme_font_size_override("font_size", 22)
	utitle.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	uv.add_child(utitle)

	var udesc = Label.new()
	udesc.text = "The Union Depository gold is yours, but Steve Haines (FIB) and Devin Weston\\ndemand you betray your crew. Choose how the story ends:"
	udesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	udesc.add_theme_font_size_override("font_size", 13)
	uv.add_child(udesc)

	for item in [
		{"opt": "A", "txt": "OPTION A: SOMETHING SENSIBLE (Kill Trevor — Split his cut)"},
		{"opt": "B", "txt": "OPTION B: THE TIME'S COME (Kill Michael — Side with Weston)"},
		{"opt": "C", "txt": "OPTION C: DEATHWISH / THE THIRD WAY (Canon — Save Trio & Eliminate Villains)"}
	]:
		var btn = Button.new()
		btn.text = item["txt"]
		btn.custom_minimum_size = Vector2(470, 44)
		btn.pressed.connect(select_ending.bind(item["opt"]))
		uv.add_child(btn)

	hud.add_child(ultimatum_panel)

	# Victory Summary Overlay
	victory_panel = PanelContainer.new()
	victory_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	victory_panel.visible = false
	victory_panel.set_anchors_preset(Control.PRESET_CENTER)
	victory_panel.offset_left = -255
	victory_panel.offset_top = -165
	victory_panel.offset_right = 255
	victory_panel.offset_bottom = 165

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	style.border_color = Color(0.2, 0.95, 0.45)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	victory_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	victory_panel.add_child(vbox)

	var hdr = Label.new()
	hdr.text = "STORY COMPLETE!"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 32)
	hdr.add_theme_color_override("font_color", Color(0.25, 0.95, 0.45))
	vbox.add_child(hdr)

	stats_label = Label.new()
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(stats_label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var roam_btn = Button.new()
	roam_btn.text = "CONTINUE FREE ROAM"
	roam_btn.custom_minimum_size = Vector2(185, 44)
	roam_btn.pressed.connect(func():
		victory_panel.visible = false
		get_tree().paused = false
	)
	btn_row.add_child(roam_btn)

	var replay_btn = Button.new()
	replay_btn.text = "REPLAY STORY"
	replay_btn.custom_minimum_size = Vector2(150, 44)
	replay_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	btn_row.add_child(replay_btn)

	hud.add_child(victory_panel)

func show_victory_screen() -> void:
	if victory_panel == null: return
	var mins = int(story_elapsed) / 60
	var secs = int(story_elapsed) % 60
	var total = cash + bank_balance
	var end_desc = {
		"A": "Ending A: Something Sensible (Trevor Eliminated)",
		"B": "Ending B: The Time's Come (Michael Eliminated)",
		"C": "Ending C: The Third Way — Canon (All 3 Protagonists Survive!)"
	}[chosen_ending]
	if stats_label:
		stats_label.text = "%s\\nCompletion Time: %02d:%02d\\nFinal Net Worth: $%d\\n\\nAll Free-Roam Events & Military Hardware Unlocked!" % [end_desc, mins, secs, total]
	victory_panel.visible = true
	get_tree().paused = true
""")

# 2. Add Camera Trauma Shake + Crosshair Hit-Marker flash to game_manager.gd & weapon.gd
gm = open("game_manager.gd").read()
if "hitmarker_timer" not in gm:
	gm = gm.replace(
		"var dispatch_delay: float = 0.0",
		"var dispatch_delay: float = 0.0\nvar hitmarker_timer: float = 0.0\nvar hitmarker_lbl: Label = null"
	)
	gm = gm.replace(
		"func _process(delta: float):",
		"""func flash_hitmarker():
	hitmarker_timer = 0.14
	if hitmarker_lbl:
		hitmarker_lbl.visible = true

func _process(delta: float):
	if hitmarker_timer > 0.0:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0 and hitmarker_lbl:
			hitmarker_lbl.visible = false"""
	)
	gm = gm.replace(
		"func _ready():",
		"""func _ready():
	hitmarker_lbl = Label.new()
	hitmarker_lbl.text = "✕"
	hitmarker_lbl.visible = false
	hitmarker_lbl.set_anchors_preset(Control.PRESET_CENTER)
	hitmarker_lbl.offset_left = -12
	hitmarker_lbl.offset_top = -14
	hitmarker_lbl.offset_right = 12
	hitmarker_lbl.offset_bottom = 14
	hitmarker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker_lbl.add_theme_font_size_override("font_size", 20)
	hitmarker_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	add_child(hitmarker_lbl)"""
	)
	open("game_manager.gd", "w").write(gm)

wpn = open("weapon.gd").read()
if "flash_hitmarker" not in wpn:
	wpn = wpn.replace(
		"collider.take_damage(",
		"var _h = get_tree().current_scene.get_node_or_null(\"HUD\")\n\t\t\tif _h and _h.has_method(\"flash_hitmarker\"): _h.flash_hitmarker()\n\t\t\tcollider.take_damage("
	)
	open("weapon.gd", "w").write(wpn)

print("Added [J] Mission Journal, AI Crew Wingmen, Radio Comms Toast & Hit-Markers OK")
