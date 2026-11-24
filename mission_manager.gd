extends Node3D

var cash: int = 500
var bank_balance: int = 1000
var marker: Area3D

# Story Stages:
# 0 = Ch 1A: Talk to Lamar [E] at Dealership Plaza (18, -18)
# 1 = Ch 1B: Steal & Deliver any car to Repo Drop (18, -18)
# 2 = Ch 2A: Meet Lester [E] outside Vangelico (-36, 22) -> Choose Smart vs. Loud Approach
# 3 = Ch 2B: Storm Vangelico / Bank (-36, 14) & grab the jewels
# 4 = Ch 2C: Escape the FIB/Police APB
# 5 = Ch 3A: Talk to Trevor [E] (0, 22)
# 6 = Ch 3B: Eliminate 3 Triad Hitmen at (54, 54) with Trevor & Franklin
# 7 = Ch 4A: Meet Lester [E] (-54, -10) -> Choose Smart vs. Loud Big Score Approach
# 8 = Ch 4B: Grab Union Depository Gold (-54, -18) & survive SWAT/FIB Blockade
# 9 = Ch 5A: Franklin's Phone Ultimatum (Option A / B / C)
# 10 = Ch 5B: Final Showdown at (18, 54)
# 11 = Story Complete / Free Roam
var story_stage: int = 0
var story_elapsed: float = 0.0
var chosen_ending: String = "C"
var chase_started: bool = false
var heist_loud: bool = false

var protagonists = [
	{"name": "FRANKLIN", "ability": "DRIVING FOCUS", "shirt": Color(0.16, 0.68, 0.32), "pants": Color(0.14, 0.16, 0.22)},
	{"name": "MICHAEL", "ability": "BULLET-TIME", "shirt": Color(0.18, 0.38, 0.72), "pants": Color(0.18, 0.18, 0.22)},
	{"name": "TREVOR", "ability": "RED MIST RAGE", "shirt": Color(0.78, 0.76, 0.72), "pants": Color(0.26, 0.22, 0.18)}
]
var active_protag_idx: int = 0

var contact_npc: Node3D = null
var contact_name: String = ""
var contact_lines: Array = []
var near_contact: bool = false

var dialogue_queue: Array = []
var dialogue_timer: float = 0.0

var mission_targets: Array[Node3D] = []
var wingmen: Array[Node3D] = []
var targets_total: int = 0
var targets_killed: int = 0

# Car Radio ([Q] or RADIO button)
var radio_stations = [
	{"name": "NON-STOP POP FM", "bpm": 124.0, "base": 220.0},
	{"name": "LOS SANTOS ROCK", "bpm": 136.0, "base": 164.8},
	{"name": "WEST COAST CLASSICS", "bpm": 96.0, "base": 110.0},
	{"name": "RADIO OFF", "bpm": 0.0, "base": 0.0}
]
var radio_idx: int = 0
var radio_player: AudioStreamPlayer = null
var radio_playback: AudioStreamGeneratorPlayback = null
var radio_phase: float = 0.0
var radio_banner_timer: float = 0.0

# Random World Event: Armored Cash Van
var armored_van: Node3D = null
var van_hp: int = 120
var van_dir: Vector3 = Vector3(1, 0, 0)

var last_brief_title: String = ""
var last_brief_story: String = ""
var last_brief_task: String = ""

var briefing_panel: PanelContainer = null
var briefing_title: Label = null
var briefing_story: Label = null
var briefing_task: Label = null

var manual_panel: PanelContainer = null
var approach_panel: PanelContainer = null
var approach_title: Label = null

var objective_panel: PanelContainer = null
var obj_header: Label = null
var obj_detail: Label = null

var comms_panel: PanelContainer = null
var comms_label: Label = null

var radio_panel: PanelContainer = null
var radio_label: Label = null

var talk_btn: Button = null
var radio_btn: Button = null

var ultimatum_panel: PanelContainer = null
var victory_panel: PanelContainer = null
var stats_label: Label = null

const SAVE_PATH = "user://vice_mobile_save.json"

const DEALERSHIP_POS = Vector3(18.0, 0.5, -18.0)
const VANGELICO_DOOR_POS = Vector3(-36.0, 0.5, 22.0)
const VANGELICO_VAULT_POS = Vector3(-36.0, 0.5, 14.0)
const TREVOR_MEET_POS = Vector3(0.0, 0.5, 22.0)
const TRIAD_AMBUSH_POS = Vector3(54.0, 0.5, 54.0)
const UNION_DOOR_POS = Vector3(-54.0, 0.5, -10.0)
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

func save_progress(announce: bool = false) -> void:
	var save_stage = story_stage
	if save_stage == 1: save_stage = 0
	elif save_stage in [3, 4]: save_stage = 2
	elif save_stage == 6: save_stage = 5
	elif save_stage == 8: save_stage = 7
	elif save_stage == 10: save_stage = 9

	var data = {
		"story_stage": save_stage,
		"cash": cash,
		"bank_balance": bank_balance,
		"active_protag_idx": active_protag_idx,
		"chosen_ending": chosen_ending,
		"heist_loud": heist_loud
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		if announce:
			queue_banter([{"speaker": "SYSTEM", "line": "Progress saved! (Chapter Stage %d • Net Worth $%d)" % [save_stage, cash + bank_balance], "col": Color(0.3, 0.95, 0.5)}])

func load_progress() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	story_stage = int(parsed.get("story_stage", 0))
	cash = int(parsed.get("cash", 500))
	bank_balance = int(parsed.get("bank_balance", 1000))
	active_protag_idx = int(parsed.get("active_protag_idx", 0))
	chosen_ending = str(parsed.get("chosen_ending", "C"))
	heist_loud = bool(parsed.get("heist_loud", false))
	return true

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _ready() -> void:
	create_checkpoint_beacon()
	build_story_ui()
	build_mobile_action_dock()
	setup_car_radio()
	spawn_armored_cash_van()
	marker.global_position = DEALERSHIP_POS

func setup_car_radio() -> void:
	radio_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.25
	radio_player.stream = gen
	radio_player.volume_db = -14.0
	add_child(radio_player)

func update_car_radio(driving: bool) -> void:
	if radio_player == null: return
	var st = radio_stations[radio_idx]
	if not driving or st["bpm"] == 0.0:
		if radio_player.playing:
			radio_player.stop()
		return
	if not radio_player.playing:
		radio_player.play()
		radio_playback = radio_player.get_stream_playback()
	if radio_playback == null: return

	var frames = radio_playback.get_frames_available()
	var sr = 22050.0
	var beat_hz = st["bpm"] / 60.0
	var base_freq = st["base"]
	for _i in range(frames):
		radio_phase += 1.0 / sr
		var beat = fmod(radio_phase * beat_hz, 1.0)
		var kick = sin(2.0 * PI * 55.0 * beat) * exp(-beat * 14.0) * 0.45
		var note_mult = 1.0 if int(radio_phase * beat_hz) % 4 < 2 else (1.25 if int(radio_phase * beat_hz) % 4 == 2 else 1.5)
		var bass = sign(sin(2.0 * PI * base_freq * note_mult * radio_phase)) * 0.14 * (1.0 - beat * 0.5)
		var s = clamp(kick + bass, -0.8, 0.8)
		radio_playback.push_frame(Vector2(s, s))

func cycle_radio_station() -> void:
	radio_idx = (radio_idx + 1) % radio_stations.size()
	if radio_panel and radio_label:
		radio_label.text = "RADIO: %s" % radio_stations[radio_idx]["name"]
		radio_panel.visible = true
		radio_banner_timer = 3.2

func spawn_armored_cash_van() -> void:
	var root = get_parent()
	if root == null: return
	armored_van = StaticBody3D.new()
	armored_van.name = "GruppeSechsVan"
	var mesh = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(2.5, 2.3, 5.4)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.42, 0.24)
	mat.metallic = 0.5
	bm.material = mat
	mesh.mesh = bm
	mesh.position.y = 1.15
	armored_van.add_child(mesh)

	var col = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(2.5, 2.3, 5.4)
	col.shape = bs
	col.position.y = 1.15
	armored_van.add_child(col)

	var tag = Label3D.new()
	tag.text = "GRUPPE SECHS ARMORED VAN ($1,500)"
	tag.position = Vector3(0, 2.8, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 36
	tag.modulate = Color(0.3, 0.95, 0.45)
	armored_van.add_child(tag)

	var sc = GDScript.new()
	sc.source_code = 'extends StaticBody3D\nfunc take_damage(dmg):\n\tvar mm = get_tree().current_scene.get_node_or_null("MissionManager")\n\tif mm and mm.has_method("damage_armored_van"):\n\t\tmm.damage_armored_van(dmg)\n'
	sc.reload()
	armored_van.set_script(sc)

	armored_van.position = Vector3(-54.0, 0.1, 54.0)
	root.add_child.call_deferred(armored_van)

func damage_armored_van(dmg: int) -> void:
	if not is_instance_valid(armored_van): return
	van_hp -= dmg
	if van_hp <= 0:
		cash += 1500
		save_progress(false)
		queue_banter([{"speaker": "WORLD EVENT", "line": "Armored Van breached! Grabbed $1,500 in cash!", "col": Color(0.3, 0.95, 0.45)}])
		var hud = get_parent().get_node_or_null("HUD")
		if hud:
			hud.add_wanted(2, true)
		armored_van.queue_free()
		armored_van = null

func start_heist_campaign() -> void:
	if load_progress() and story_stage > 0:
		apply_protagonist(active_protag_idx, false)
		resume_saved_stage()
		return
	if story_stage == 0:
		apply_protagonist(0, false)
		setup_stage_0_lamar()

func resume_saved_stage() -> void:
	if story_stage == 2:
		story_stage = 1
		advance_story_beacon()
	elif story_stage == 5:
		story_stage = 4
		chase_started = true
		var hud = get_parent().get_node_or_null("HUD")
		if hud: hud.wanted_level = 0
	elif story_stage == 7:
		story_stage = 6
		advance_story_beacon()
	elif story_stage == 9:
		open_ultimatum_phone()
	elif story_stage >= 11:
		story_stage = 11
		marker.visible = true
		marker.global_position = free_roam_waypoints[0]
		queue_banter([{"speaker": "SYSTEM", "line": "Save Loaded! Free Roam & Ending %s unlocked ($%d)." % [chosen_ending, cash + bank_balance], "col": Color(0.3, 0.95, 0.5)}])
	else:
		setup_stage_0_lamar()

func setup_stage_0_lamar() -> void:
	story_stage = 0
	marker.visible = true
	marker.global_position = DEALERSHIP_POS
	set_gps_target(DEALERSHIP_POS, "TALK TO LAMAR")
	spawn_contact_npc("LAMAR", DEALERSHIP_POS, Color(0.15, 0.55, 0.25), [
		{"speaker": "LAMAR", "line": "Yo Franklin! Simeon needs that Sports Car repo'd—and some rich guy named Michael just wrecked a cartel mansion!", "col": Color(0.3, 0.95, 0.45)},
		{"speaker": "FRANKLIN", "line": "Cartel mansion? Man, that sounds like serious heat. Where's the ride parked?", "col": Color(0.95, 0.95, 1.0)},
		{"speaker": "LAMAR", "line": "Right down the block! Hop in ANY car (tap CAR button or [F]) and bring it back to this drop zone.", "col": Color(0.3, 0.95, 0.45)}
	])
	last_brief_title = "CHAPTER 1: THE REPO & MADRAZO'S DEBT"
	last_brief_story = "Franklin & Lamar run car repossessions in Los Santos—until a job connects them with retired bank robber Michael De Santa, who owes $2,500 to cartel boss Martin Madrazo."
	last_brief_task = "1. Walk up to LAMAR at the yellow beacon (18, -18) and tap TALK ([E]).\n2. Get in any car (tap CAR or [F]) and drive it into the Yellow Repo Drop."
	queue_banter([
		{"speaker": "FRANKLIN", "line": "Lamar's waiting over by the yellow beacon. Walk up and tap TALK!", "col": Color(0.35, 0.95, 0.5)}
	])

func queue_banter(lines: Array) -> void:
	for item in lines:
		dialogue_queue.append(item)
	if dialogue_timer <= 0.0:
		advance_banter()

func advance_banter() -> void:
	if dialogue_queue.is_empty():
		if comms_panel:
			comms_panel.visible = false
		return
	var entry = dialogue_queue.pop_front()
	if comms_panel and comms_label:
		comms_label.text = '%s: "%s"' % [entry["speaker"], entry["line"]]
		comms_label.add_theme_color_override("font_color", entry.get("col", Color(0.3, 0.92, 1.0)))
		comms_panel.visible = true
	dialogue_timer = 4.6

func spawn_contact_npc(npc_name: String, pos: Vector3, shirt_col: Color, lines: Array) -> void:
	clear_contact_npc()
	contact_name = npc_name
	contact_lines = lines
	near_contact = false
	var root = get_parent()
	if root == null: return

	var npc = Node3D.new()
	npc.name = "Contact_%s" % npc_name
	var rig_script = load("res://human_rig.gd")
	var rig = Node3D.new()
	rig.set_script(rig_script)
	npc.add_child(rig)
	rig.build_human(shirt_col, Color(0.14, 0.16, 0.2), false)

	var tag = Label3D.new()
	tag.text = "TALK TO %s [E]" % npc_name
	tag.position = Vector3(0, 1.35, 0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 44
	tag.modulate = Color(1.0, 0.88, 0.2)
	npc.add_child(tag)

	root.add_child(npc)
	npc.global_position = Vector3(pos.x + 1.8, 0.95, pos.z + 1.8)
	contact_npc = npc

func clear_contact_npc() -> void:
	if is_instance_valid(contact_npc):
		contact_npc.queue_free()
	contact_npc = null
	contact_name = ""
	near_contact = false

func interact_with_contact() -> void:
	if contact_npc == null: return
	queue_banter(contact_lines)
	clear_contact_npc()

	if story_stage == 0:
		story_stage = 1
		set_gps_target(DEALERSHIP_POS, "DELIVER CAR TO REPO DROP")
		last_brief_task = "Get inside any car (tap CAR or [F]) and drive it straight into the YELLOW REPO BEACON (18, -18)!"

	elif story_stage == 2:
		open_approach_picker("VANGELICO JEWELRY HEIST — CHOOSE APPROACH")

	elif story_stage == 5:
		story_stage = 6
		apply_protagonist(2, false)
		spawn_crew_wingmen([0])
		marker.visible = true
		marker.global_position = TRIAD_AMBUSH_POS
		set_gps_target(TRIAD_AMBUSH_POS, "TRIAD AMBUSH SITE")
		spawn_mission_enemies(TRIAD_AMBUSH_POS, 3, Color(0.85, 0.15, 0.15))
		last_brief_task = "Drive to the TRIAD AMBUSH (54, 54) with Franklin and shoot all 3 Triad Hitmen to save Michael!"

	elif story_stage == 7:
		open_approach_picker("THE BIG SCORE (UNION DEPOSITORY) — CHOOSE APPROACH")

func open_approach_picker(title_txt: String) -> void:
	if approach_panel == null: return
	if approach_title:
		approach_title.text = title_txt
	approach_panel.visible = true
	get_tree().paused = true

func confirm_heist_approach(is_loud: bool) -> void:
	heist_loud = is_loud
	if approach_panel:
		approach_panel.visible = false
	get_tree().paused = false

	if story_stage == 2:
		story_stage = 3
		marker.visible = false
		set_gps_target(VANGELICO_VAULT_POS, "VANGELICO VAULT ($)")
		var mode_txt = "LOUD (+$3,000 Bonus, 4-Star Heat)" if is_loud else "SMART (Gas Loop, 2-Star Heat)"
		queue_banter([{"speaker": "LESTER", "line": "%s locked in! Step inside Vangelico ('$') onto the vault pad!" % mode_txt, "col": Color(0.75, 0.55, 1.0)}])
	elif story_stage == 7:
		story_stage = 8
		chase_started = false
		spawn_crew_wingmen([1, 2])
		marker.visible = true
		marker.global_position = UNION_DEPO_POS
		set_gps_target(UNION_DEPO_POS, "UNION DEPOSITORY VAULT")
		var mode_txt = "LOUD (+$5,000 Bonus)" if is_loud else "SMART (Subtle Drill)"
		queue_banter([{"speaker": "LESTER", "line": "%s locked in! Storm the Union Depository gold vault behind me!" % mode_txt, "col": Color(0.75, 0.55, 1.0)}])

func show_chapter_briefing(title_txt: String, story_txt: String, task_txt: String) -> void:
	last_brief_title = title_txt
	last_brief_story = story_txt
	last_brief_task = task_txt
	if briefing_panel == null: return
	briefing_title.text = title_txt
	briefing_story.text = story_txt
	briefing_task.text = "CURRENT OBJECTIVE:\n" + task_txt
	briefing_panel.visible = true
	get_tree().paused = true

func toggle_manual() -> void:
	if manual_panel == null: return
	manual_panel.visible = not manual_panel.visible
	get_tree().paused = manual_panel.visible

func apply_protagonist(idx: int, announce: bool = true) -> void:
	active_protag_idx = idx % protagonists.size()
	var data = protagonists[active_protag_idx]
	var root = get_parent()
	if root == null: return
	var p = root.get_node_or_null("Player")
	if p and p.human_node and p.human_node.has_method("build_human"):
		p.human_node.build_human(data["shirt"], data["pants"], true)
	if announce:
		queue_banter([{"speaker": data["name"], "line": "Taking point! Ability: %s" % data["ability"], "col": Color(1.0, 0.85, 0.25)}])

func set_gps_target(world_pos: Vector3, label_name: String) -> void:
	var root = get_parent()
	if root == null: return
	var mm_ui = root.get_node_or_null("HUD/Minimap")
	if mm_ui:
		mm_ui.waypoint_world = world_pos
		mm_ui.has_waypoint = true
		mm_ui.waypoint_title = label_name

func on_bank_robbed() -> void:
	if story_stage == 3:
		story_stage = 4
		chase_started = false
		var stars = 4 if heist_loud else 2
		if heist_loud:
			cash += 3000
		var hud = get_parent().get_node_or_null("HUD")
		if hud:
			var diff = stars - hud.wanted_level
			if diff > 0:
				hud.add_wanted(diff, true)
			chase_started = hud.wanted_level > 0
		set_gps_target(Vector3(36.0, 0.5, 14.0), "PAY 'N' SPRAY (LOSE COPS)")
		last_brief_title = "CHAPTER 2: THE VANGELICO GETAWAY"
		last_brief_story = "Michael dropped his signature movie quote during the robbery—putting both the FIB and Trevor Philips on his trail."
		last_brief_task = "Escape the %d-Star Police/FIB pursuit! Drive into PAY 'N' SPRAY ('G') or break police sightlines." % stars
		queue_banter([
			{"speaker": "MICHAEL", "line": "'You forget a thousand things every day, pal—make sure this is one of 'em!'", "col": Color(0.35, 0.75, 1.0)},
			{"speaker": "LESTER", "line": "You quoted yourself on live TV! Lose those %d stars NOW!" % stars, "col": Color(1.0, 0.45, 0.35)}
		])

func trigger_key_action(keycode: int) -> void:
	var ev = InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.08).timeout
	var ev_up = InputEventKey.new()
	ev_up.keycode = keycode
	ev_up.pressed = false
	Input.parse_input_event(ev_up)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and near_contact:
			interact_with_contact()
		elif event.keycode == KEY_Q:
			cycle_radio_station()
		elif event.keycode == KEY_B:
			deposit_to_buckme()
		elif event.keycode == KEY_K:
			save_progress(true)
		elif event.keycode == KEY_M:
			toggle_manual()
		elif event.keycode == KEY_H:
			var unlocked_count = 1 if story_stage < 2 else (2 if story_stage < 6 else 3)
			apply_protagonist((active_protag_idx + 1) % unlocked_count, true)
		elif event.keycode == KEY_J:
			if briefing_panel and not briefing_panel.visible and last_brief_title != "":
				show_chapter_briefing(last_brief_title, last_brief_story, last_brief_task)

func deposit_to_buckme() -> void:
	if cash <= 0:
		queue_banter([{"speaker": "BUCKME APP", "line": "Wallet is empty ($0 to deposit).", "col": Color(0.8, 0.85, 0.9)}])
		return
	var amt = cash
	bank_balance += amt
	cash = 0
	save_progress(false)
	queue_banter([{"speaker": "BUCKME APP", "line": "Deposited $%d & Saved! Safe Bank Balance: $%d" % [amt, bank_balance], "col": Color(0.3, 0.95, 0.5)}])

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

func spawn_crew_wingmen(indices: Array) -> void:
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
		sc.source_code = 'extends CharacterBody3D\nvar fire_cd = 0.8\nfunc _physics_process(delta):\n\tfire_cd = max(0.0, fire_cd - delta)\n\tvar main = get_tree().current_scene\n\tif main == null: return\n\tvar p = main.get_node_or_null("Player")\n\tif p == null: return\n\tvisible = p.visible\n\tif not visible: return\n\tvar to_p = p.global_position - global_position\n\tto_p.y = 0\n\tif to_p.length() > 32.0:\n\t\tglobal_position = Vector3(p.global_position.x + 2.2, 0.95, p.global_position.z + 2.2)\n\telif to_p.length() > 3.6:\n\t\tvelocity.x = to_p.normalized().x * 6.5\n\t\tvelocity.z = to_p.normalized().z * 6.5\n\telse:\n\t\tvelocity.x = 0\n\t\tvelocity.z = 0\n\tif not is_on_floor(): velocity.y -= 9.8 * delta\n\tmove_and_slide()\n\tif fire_cd == 0.0:\n\t\tfor n in main.get_children():\n\t\t\tif n.name.begins_with("StoryTarget_") and n.global_position.distance_to(global_position) < 24.0:\n\t\t\t\tfire_cd = 1.1\n\t\t\t\tif n.has_method("take_damage"): n.take_damage(25)\n\t\t\t\tbreak\n'
		sc.reload()
		ally.set_script(sc)
		root.add_child(ally)
		ally.global_position = Vector3(p.global_position.x + side, 0.95, p.global_position.z - 1.5)
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

	var offsets = [Vector3(-4.0, 0.0, 4.0), Vector3(4.0, 0.0, 4.0), Vector3(0.0, 0.0, -3.5), Vector3(5.0, 0.0, -2.0)]
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
		sc.source_code = 'extends CharacterBody3D\nvar hp = 85\nvar shoot_cd = 1.2\nfunc _physics_process(delta):\n\tshoot_cd = max(0.0, shoot_cd - delta)\n\tvar main = get_tree().current_scene\n\tif main == null: return\n\tvar p = main.get_node_or_null("Player")\n\tif p == null: return\n\tvar d = global_position.distance_to(p.global_position)\n\tif d < 26.0 and shoot_cd == 0.0:\n\t\tshoot_cd = 1.35\n\t\tvar hud = main.get_node_or_null("HUD")\n\t\tif hud and p.visible:\n\t\t\thud.damage_player(5)\nfunc take_damage(dmg):\n\thp -= dmg\n\tif hp <= 0:\n\t\tvar mm = get_tree().current_scene.get_node_or_null("MissionManager")\n\t\tif mm and mm.has_method("on_story_target_killed"):\n\t\t\tmm.on_story_target_killed(self)\n\t\tqueue_free()\n'
		sc.reload()
		enemy.set_script(sc)
		root.add_child(enemy)
		enemy.global_position = Vector3(center.x, 0.95, center.z) + offsets[i % offsets.size()]
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
		queue_banter([{"speaker": "CREW", "line": "Target eliminated! %d more to go!" % rem, "col": Color(1.0, 0.45, 0.35)}])
	if story_stage == 6 and targets_killed >= targets_total:
		advance_story_beacon()
	elif story_stage == 10 and targets_killed >= targets_total:
		advance_story_beacon()

func _process(delta: float) -> void:
	if dialogue_timer > 0.0:
		dialogue_timer -= delta
		if dialogue_timer <= 0.0:
			advance_banter()

	if radio_banner_timer > 0.0:
		radio_banner_timer -= delta
		if radio_banner_timer <= 0.0 and radio_panel:
			radio_panel.visible = false

	if is_instance_valid(armored_van) and armored_van.is_inside_tree():
		armored_van.global_position += van_dir * 7.5 * delta
		if armored_van.global_position.x > 126.0:
			van_dir = Vector3(0, 0, -1)
		elif armored_van.global_position.z < -126.0:
			van_dir = Vector3(-1, 0, 0)
		elif armored_van.global_position.x < -126.0:
			van_dir = Vector3(0, 0, 1)
		elif armored_van.global_position.z > 126.0:
			van_dir = Vector3(1, 0, 0)

	if story_stage < 11:
		story_elapsed += delta
	var root = get_parent()
	if root == null: return
	var hud = root.get_node_or_null("HUD")
	if hud == null: return

	hud.get_node("TopRight/SpeedLabel").text = "$%05d  |  BANK $%05d" % [cash, bank_balance]

	var p = root.get_node_or_null("Player")
	var active_pos = p.global_position if p else Vector3.ZERO
	var driving_car = false
	for c in root.get_children():
		if c is VehicleBody3D and c.get("is_driven") == true:
			active_pos = c.global_position
			driving_car = true
			break

	update_car_radio(driving_car)
	if radio_btn:
		radio_btn.visible = driving_car
	if car_btn:
		car_btn.text = "EXIT" if driving_car else "CAR"
	if fire_btn:
		fire_btn.visible = not driving_car

	if is_instance_valid(contact_npc):
		var c_dist = Vector2(active_pos.x, active_pos.z).distance_to(Vector2(contact_npc.global_position.x, contact_npc.global_position.z))
		near_contact = c_dist < 7.5
		if talk_btn:
			talk_btn.visible = near_contact
			talk_btn.text = "TALK %s" % contact_name
		if near_contact and hud.get_node_or_null("BottomHint"):
			hud.get_node("BottomHint").text = "Tap TALK button or press [E] to speak with %s" % contact_name
	elif talk_btn:
		talk_btn.visible = false

	update_objective_tracker(active_pos, hud.wanted_level, driving_car)

	if story_stage == 4:
		if hud.wanted_level > 0:
			chase_started = true
		elif chase_started and hud.wanted_level == 0:
			chase_started = false
			story_stage = 5
			marker.visible = true
			marker.global_position = TREVOR_MEET_POS
			set_gps_target(TREVOR_MEET_POS, "TALK TO TREVOR")
			spawn_contact_npc("TREVOR", TREVOR_MEET_POS, Color(0.78, 0.76, 0.72), [
				{"speaker": "TREVOR", "line": "I heard that movie quote on the news, Mikey! Nine years after North Yankton—you faked your death with the FIB!", "col": Color(1.0, 0.65, 0.25)},
				{"speaker": "MICHAEL", "line": "Trevor, keep your voice down—Wei Cheng's Triads are gunning for me because of your meth war!", "col": Color(0.35, 0.75, 1.0)},
				{"speaker": "TREVOR", "line": "Nobody touches Mikey except me! Franklin, grab your gun—let's wipe out those Triad hitmen at (54, 54)!", "col": Color(1.0, 0.65, 0.25)}
			])
			last_brief_title = "CHAPTER 3: THE TRUTH & TRIAD RESCUE"
			last_brief_story = "Recognizing Michael's signature quote from the Vangelico heist, Trevor tracks him down—only for Chinese Triad gangsters to ambush them."
			last_brief_task = "Walk or drive to TREVOR at (0, 22) and tap TALK ([E])."
			queue_banter([
				{"speaker": "FRANKLIN", "line": "Heat's off! Trevor just showed up looking for Michael at (0, 22).", "col": Color(0.35, 0.95, 0.5)}
			])

	elif story_stage == 8 and not marker.visible:
		if hud.wanted_level > 0:
			chase_started = true
		elif chase_started and hud.wanted_level == 0:
			chase_started = false
			story_stage = 9
			clear_wingmen()
			open_ultimatum_phone()

	if marker.visible:
		var m_dist = Vector2(active_pos.x, active_pos.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z))
		if story_stage == 1 and driving_car and m_dist < 8.5:
			advance_story_beacon()
		elif story_stage == 8 and m_dist < 8.5:
			var stars = 4 if heist_loud else 2
			cash += (25000 if heist_loud else 20000)
			marker.visible = false
			chase_started = false
			var diff = stars - hud.wanted_level
			if diff > 0:
				hud.add_wanted(diff, true)
			chase_started = hud.wanted_level > 0
			set_gps_target(Vector3(36.0, 0.5, 14.0), "PAY 'N' SPRAY (ESCAPE)")
			last_brief_task = "Gold Bullion secured! Escape the %d-Star SWAT/FIB blockade to reach the Finale." % stars
			queue_banter([
				{"speaker": "MICHAEL", "line": "Gold bullion secured! Shake those %d wanted stars!" % stars, "col": Color(0.35, 0.75, 1.0)},
				{"speaker": "TREVOR", "line": "Hit Pay 'n' Spray or outrun 'em! We're rich, boys!", "col": Color(1.0, 0.65, 0.25)}
			])

func update_objective_tracker(active_pos: Vector3, wanted: int, driving_car: bool) -> void:
	if obj_header == null or obj_detail == null: return
	var pdata = protagonists[active_protag_idx]
	var protag = pdata["name"]
	var dist = int(Vector2(active_pos.x, active_pos.z).distance_to(Vector2(marker.global_position.x, marker.global_position.z)))

	match story_stage:
		0:
			obj_header.text = "CH 1: THE REPO  •  %s (%s)" % [protag, pdata["ability"]]
			obj_detail.text = "Walk to LAMAR at Yellow Beacon (%dm) & tap TALK" % dist
		1:
			obj_header.text = "CH 1: DELIVER REPO CAR  •  %s" % protag
			obj_detail.text = ("Drive into Yellow Repo Beacon (%dm)" % dist) if driving_car else "Get in ANY car (tap CAR) & drive to Repo Beacon (%dm)" % dist
		2:
			obj_header.text = "CH 2: VANGELICO PREP  •  %s" % protag
			obj_detail.text = "Meet LESTER outside Vangelico (%dm) & tap TALK" % dist
		3:
			var b_dist = int(Vector2(active_pos.x, active_pos.z).distance_to(Vector2(VANGELICO_VAULT_POS.x, VANGELICO_VAULT_POS.z)))
			obj_header.text = "CH 2: VANGELICO HEIST  •  %s" % protag
			obj_detail.text = "Enter Pacific Bank/Jewelry ('$') & step on vault pad (%dm)" % b_dist
		4:
			obj_header.text = "CH 2: ESCAPE THE FIB  •  %s" % protag
			obj_detail.text = "Lose all %d Wanted Stars (Evade cops or visit Pay 'n' Spray 'G')" % wanted
		5:
			obj_header.text = "CH 3: NORTH YANKTON TRUTH  •  %s" % protag
			obj_detail.text = "Meet TREVOR at (0, 22) (%dm) & tap TALK" % dist
		6:
			obj_header.text = "CH 3: TRIAD RESCUE  •  %s" % protag
			obj_detail.text = "Eliminate Triad Hitmen with Franklin (%d/%d Killed • %dm)" % [targets_killed, targets_total, dist]
		7:
			obj_header.text = "CH 4: THE BIG SCORE PREP  •  %s" % protag
			obj_detail.text = "Meet LESTER at Union Depository (%dm) & tap TALK" % dist
		8:
			if marker.visible:
				obj_header.text = "CH 4: UNION DEPOSITORY  •  %s" % protag
				obj_detail.text = "Storm Gold Vault Beacon with Michael & Trevor (%dm)" % dist
			else:
				obj_header.text = "CH 4: ESCAPE THE BLOCKADE  •  %s" % protag
				obj_detail.text = "Lose all %d Wanted Stars to trigger Final Ultimatum!" % wanted
		9:
			obj_header.text = "CH 5: THE ULTIMATUM  •  FRANKLIN"
			obj_detail.text = "Choose Option A, B, or C on Franklin's Phone"
		10:
			obj_header.text = "CH 5: ENDING %s SHOWDOWN  •  %s" % [chosen_ending, protag]
			obj_detail.text = "Eliminate Final Targets at Foundry (%d/%d Killed • %dm)" % [targets_killed, targets_total, dist]
		11:
			obj_header.text = "FREE ROAM  •  %s" % protag
			obj_detail.text = "Story Complete! Collect Checkpoints (%dm) or rob Armored Vans" % dist

func _on_checkpoint_reached(body: Node3D) -> void:
	var is_player = body.name == "Player" or (body is VehicleBody3D and body.get("is_driven") == true)
	if not is_player:
		return
	if story_stage == 11:
		cash += 500
		wp_idx = (wp_idx + 1) % free_roam_waypoints.size()
		marker.global_position = free_roam_waypoints[wp_idx]

func advance_story_beacon() -> void:
	call_deferred("save_progress", false)
	if story_stage == 1:
		story_stage = 2
		cash += 2500
		apply_protagonist(1, false)
		spawn_crew_wingmen([0])
		marker.visible = true
		marker.global_position = VANGELICO_DOOR_POS
		set_gps_target(VANGELICO_DOOR_POS, "MEET LESTER")
		spawn_contact_npc("LESTER", VANGELICO_DOOR_POS, Color(0.45, 0.35, 0.65), [
			{"speaker": "LESTER", "line": "Michael, you tore down cartel boss Martin Madrazo's mansion—you owe him $2.5 million! That's why we're robbing Vangelico.", "col": Color(0.75, 0.55, 1.0)},
			{"speaker": "FRANKLIN", "line": "So that repo car led straight to you, OG. How are we hitting this place?", "col": Color(0.35, 0.95, 0.5)}
		])
		last_brief_title = "CHAPTER 2: MADRAZO'S DEBT & VANGELICO HEIST"
		last_brief_story = "Michael owes cartel boss Martin Madrazo $2.5M—forcing him out of retirement with Franklin and hacker Lester Crest."
		last_brief_task = "Drive to VANGELICO / PACIFIC BANK (-36, 22) and tap TALK to speak with Lester."
		queue_banter([
			{"speaker": "MICHAEL", "line": "Nice driving, kid. Madrazo wants $2.5M—meet Lester outside Vangelico.", "col": Color(0.35, 0.75, 1.0)}
		])

	elif story_stage == 6:
		story_stage = 7
		cash += 3500
		apply_protagonist(0, false)
		spawn_crew_wingmen([1, 2])
		marker.visible = true
		marker.global_position = UNION_DOOR_POS
		set_gps_target(UNION_DOOR_POS, "MEET LESTER")
		spawn_contact_npc("LESTER", UNION_DOOR_POS, Color(0.45, 0.35, 0.65), [
			{"speaker": "LESTER", "line": "You survived the Triads, and the trio is back together! Inside the Union Depository sits $20,000+ in gold bullion.", "col": Color(0.75, 0.55, 1.0)},
			{"speaker": "MICHAEL", "line": "One last score—choose our approach and let's finish this.", "col": Color(0.35, 0.75, 1.0)}
		])
		last_brief_title = "CHAPTER 4: THE UNION DEPOSITORY BIG SCORE"
		last_brief_story = "With Michael saved from the Triads, the trio reunites for their biggest job: robbing gold bullion from the Union Depository."
		last_brief_task = "Drive to the UNION DEPOSITORY (-54, -10) and tap TALK to speak with Lester."
		queue_banter([
			{"speaker": "TREVOR", "line": "Triads are toast! Now let's meet Lester at the Union Depository!", "col": Color(1.0, 0.65, 0.25)}
		])

	elif story_stage == 10:
		story_stage = 11
		clear_wingmen()
		marker.visible = true
		marker.global_position = free_roam_waypoints[0]
		var mm_ui = get_parent().get_node_or_null("HUD/Minimap")
		if mm_ui and mm_ui.has_method("clear_waypoint"):
			mm_ui.clear_waypoint()
		show_victory_screen()

func open_ultimatum_phone() -> void:
	if ultimatum_panel == null: return
	ultimatum_panel.visible = true
	get_tree().paused = true

func select_ending(opt: String) -> void:
	chosen_ending = opt
	call_deferred("save_progress", false)
	if ultimatum_panel:
		ultimatum_panel.visible = false
	get_tree().paused = false
	story_stage = 10
	marker.visible = true
	marker.global_position = FINALE_POS
	set_gps_target(FINALE_POS, "FINAL SHOWDOWN")

	if opt == "A":
		apply_protagonist(0, false)
		spawn_crew_wingmen([1])
		cash += 10000
		spawn_mission_enemies(FINALE_POS, 1, Color(0.78, 0.76, 0.72))
		queue_banter([
			{"speaker": "STEVE HAINES", "line": "Smart move, Franklin. Take Trevor out at the Foundry—Michael's backing you up.", "col": Color(1.0, 0.45, 0.35)}
		])
	elif opt == "B":
		apply_protagonist(0, false)
		clear_wingmen()
		spawn_mission_enemies(FINALE_POS, 1, Color(0.18, 0.38, 0.72))
		queue_banter([
			{"speaker": "DEVIN WESTON", "line": "Trevor wouldn't help you, kid. Eliminate Michael at (18, 54) and you're set for life.", "col": Color(1.0, 0.82, 0.25)}
		])
	else:
		apply_protagonist(2, false)
		spawn_crew_wingmen([0, 1])
		spawn_mission_enemies(FINALE_POS, 3, Color(0.12, 0.14, 0.20))
		queue_banter([
			{"speaker": "FRANKLIN", "line": "Screw Haines and screw Weston—nobody's dying tonight except them!", "col": Color(0.35, 0.95, 0.5)},
			{"speaker": "MICHAEL", "line": "All three of us together—let's finish Haines, Wei Cheng, and Devin Weston at (18, 54)!", "col": Color(0.35, 0.75, 1.0)}
		])

var menu_drawer: PanelContainer = null
var car_btn: Button = null
var abil_btn: Button = null
var fire_btn: Button = null

func build_mobile_action_dock() -> void:
	var hud = get_parent().get_node_or_null("HUD")
	if hud == null: return

	# Single compact [ ≡ MENU ] pill next to the Objective Card (replaces 5 cluttered buttons)
	var menu_toggle = Button.new()
	menu_toggle.text = "≡ MENU"
	menu_toggle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_toggle.offset_left = 408
	menu_toggle.offset_top = 44
	menu_toggle.offset_right = 492
	menu_toggle.offset_bottom = 86
	menu_toggle.focus_mode = Control.FOCUS_NONE
	menu_toggle.pressed.connect(func():
		if menu_drawer:
			menu_drawer.visible = not menu_drawer.visible
	)
	hud.add_child(menu_toggle)

	# Collapsible Phone / Quick-Menu Drawer (hidden until tapped)
	menu_drawer = PanelContainer.new()
	menu_drawer.visible = false
	menu_drawer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_drawer.offset_left = 408
	menu_drawer.offset_top = 92
	menu_drawer.offset_right = 568
	menu_drawer.offset_bottom = 294
	var dst = StyleBoxFlat.new()
	dst.bg_color = Color(0.05, 0.07, 0.12, 0.92)
	dst.border_color = Color(0.25, 0.88, 1.0, 0.75)
	dst.set_border_width_all(2)
	dst.set_corner_radius_all(8)
	dst.set_content_margin_all(8)
	menu_drawer.add_theme_stylebox_override("panel", dst)

	var dv = VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	menu_drawer.add_child(dv)

	var add_drawer_btn = func(lbl: String, cb: Callable):
		var b = Button.new()
		b.text = lbl
		b.custom_minimum_size = Vector2(140, 32)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			menu_drawer.visible = false
			cb.call()
		)
		dv.add_child(b)

	add_drawer_btn.call("? PLAYER GUIDE", toggle_manual)
	add_drawer_btn.call("STORY LOG [J]", func():
		if last_brief_title != "":
			show_chapter_briefing(last_brief_title, last_brief_story, last_brief_task)
	)
	add_drawer_btn.call("SWITCH CREW [H]", func():
		var unlocked_count = 1 if story_stage < 2 else (2 if story_stage < 6 else 3)
		apply_protagonist((active_protag_idx + 1) % unlocked_count, true)
	)
	add_drawer_btn.call("BANK CASH [B]", deposit_to_buckme)
	add_drawer_btn.call("SAVE GAME [K]", func(): save_progress(true))
	hud.add_child(menu_drawer)

	# Slim, context-sensitive Bottom-Right Touch Action Pills
	var action_dock = HBoxContainer.new()
	action_dock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action_dock.offset_left = -350
	action_dock.offset_top = -54
	action_dock.offset_right = -16
	action_dock.offset_bottom = -16
	action_dock.alignment = BoxContainer.ALIGNMENT_END
	action_dock.add_theme_constant_override("separation", 6)

	talk_btn = Button.new()
	talk_btn.text = "TALK"
	talk_btn.visible = false
	talk_btn.custom_minimum_size = Vector2(88, 38)
	talk_btn.focus_mode = Control.FOCUS_NONE
	talk_btn.modulate = Color(1.0, 0.9, 0.25)
	talk_btn.pressed.connect(interact_with_contact)
	action_dock.add_child(talk_btn)

	radio_btn = Button.new()
	radio_btn.text = "RADIO"
	radio_btn.visible = false
	radio_btn.custom_minimum_size = Vector2(68, 38)
	radio_btn.focus_mode = Control.FOCUS_NONE
	radio_btn.pressed.connect(cycle_radio_station)
	action_dock.add_child(radio_btn)

	car_btn = Button.new()
	car_btn.text = "CAR"
	car_btn.custom_minimum_size = Vector2(64, 38)
	car_btn.focus_mode = Control.FOCUS_NONE
	car_btn.pressed.connect(func(): trigger_key_action(KEY_F))
	action_dock.add_child(car_btn)

	abil_btn = Button.new()
	abil_btn.text = "FOCUS"
	abil_btn.custom_minimum_size = Vector2(68, 38)
	abil_btn.focus_mode = Control.FOCUS_NONE
	abil_btn.pressed.connect(func(): trigger_key_action(KEY_V))
	action_dock.add_child(abil_btn)

	fire_btn = Button.new()
	fire_btn.text = "FIRE"
	fire_btn.custom_minimum_size = Vector2(64, 38)
	fire_btn.focus_mode = Control.FOCUS_NONE
	fire_btn.modulate = Color(1.0, 0.45, 0.45)
	fire_btn.pressed.connect(func(): trigger_key_action(KEY_R))
	action_dock.add_child(fire_btn)

	hud.add_child(action_dock)

func build_story_ui() -> void:
	var hud = get_parent().get_node_or_null("HUD")
	if hud == null: return

	objective_panel = PanelContainer.new()
	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.offset_left = 22
	objective_panel.offset_top = 44
	objective_panel.offset_right = 400
	objective_panel.offset_bottom = 92
	var ost = StyleBoxFlat.new()
	ost.bg_color = Color(0.05, 0.07, 0.12, 0.72)
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

	# Car Radio Banner
	radio_panel = PanelContainer.new()
	radio_panel.visible = false
	radio_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	radio_panel.offset_left = -165
	radio_panel.offset_top = 18
	radio_panel.offset_right = 165
	radio_panel.offset_bottom = 52
	var rst = StyleBoxFlat.new()
	rst.bg_color = Color(0.05, 0.08, 0.14, 0.92)
	rst.border_color = Color(0.95, 0.35, 0.85)
	rst.set_border_width_all(2)
	rst.set_corner_radius_all(8)
	rst.set_content_margin_all(6)
	radio_panel.add_theme_stylebox_override("panel", rst)

	radio_label = Label.new()
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_label.add_theme_font_size_override("font_size", 13)
	radio_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.94))
	radio_panel.add_child(radio_label)
	hud.add_child(radio_panel)

	# Bottom Subtitle Banter Box
	comms_panel = PanelContainer.new()
	comms_panel.visible = false
	comms_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	comms_panel.offset_left = -280
	comms_panel.offset_top = -102
	comms_panel.offset_right = 280
	comms_panel.offset_bottom = -62
	var cst = StyleBoxFlat.new()
	cst.bg_color = Color(0.04, 0.05, 0.09, 0.94)
	cst.border_color = Color(0.25, 0.9, 1.0, 0.85)
	cst.set_border_width_all(2)
	cst.set_corner_radius_all(8)
	cst.set_content_margin_all(8)
	comms_panel.add_theme_stylebox_override("panel", cst)

	comms_label = Label.new()
	comms_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comms_label.add_theme_font_size_override("font_size", 13)
	comms_panel.add_child(comms_label)
	hud.add_child(comms_panel)

	# Interactive In-Game Player Manual (? GUIDE)
	manual_panel = PanelContainer.new()
	manual_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	manual_panel.visible = false
	manual_panel.set_anchors_preset(Control.PRESET_CENTER)
	manual_panel.offset_left = -310
	manual_panel.offset_top = -220
	manual_panel.offset_right = 310
	manual_panel.offset_bottom = 220
	var mst = StyleBoxFlat.new()
	mst.bg_color = Color(0.04, 0.06, 0.11, 0.97)
	mst.border_color = Color(1.0, 0.82, 0.22)
	mst.set_border_width_all(3)
	mst.set_corner_radius_all(12)
	mst.set_content_margin_all(18)
	manual_panel.add_theme_stylebox_override("panel", mst)

	var mv = VBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	manual_panel.add_child(mv)

	var mtitle = Label.new()
	mtitle.text = "VICE MOBILE — PLAYER GUIDE & CONTROLS"
	mtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mtitle.add_theme_font_size_override("font_size", 20)
	mtitle.add_theme_color_override("font_color", Color(1.0, 0.84, 0.22))
	mv.add_child(mtitle)

	var mbody = Label.new()
	mbody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mbody.add_theme_font_size_override("font_size", 13)
	mbody.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	mbody.text = """HOW TO PLAY (MOBILE TAP BUTTONS OR LAPTOP KEYS):
• Follow the purple GPS road line & Top-Left Objective Box.
• When near Lamar, Lester, or Trevor, tap [TALK] (or press E) to advance the story.
• Tap [CAR / EXIT] (or press F) next to any Car, Jet (South Airfield), or Tank (Military Base 'M').
• Tap [FIRE] (or Right-Click / R) to shoot weapons or fire the Rhino Tank cannon.
• Tap [ABILITY] (or press V): Franklin = Driving Slow-Mo | Michael = Bullet-Time | Trevor = Red Mist (75% Armor).
• Tap [CREW] (H) to switch protagonists, [BANK $] (B) to protect cash, [SAVE] (K) to save anytime.
• Map Icons: '$' Vangelico Heist | 'G' Pay 'n' Spray (Clears Wanted Stars) | 'M' Military Base."""
	mv.add_child(mbody)

	var mclose = Button.new()
	mclose.text = "GOT IT — BACK TO GAME"
	mclose.custom_minimum_size = Vector2(220, 42)
	mclose.pressed.connect(toggle_manual)
	mv.add_child(mclose)
	hud.add_child(manual_panel)

	# Smart vs Loud Heist Approach Modal
	approach_panel = PanelContainer.new()
	approach_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	approach_panel.visible = false
	approach_panel.set_anchors_preset(Control.PRESET_CENTER)
	approach_panel.offset_left = -255
	approach_panel.offset_top = -135
	approach_panel.offset_right = 255
	approach_panel.offset_bottom = 135
	var ast = StyleBoxFlat.new()
	ast.bg_color = Color(0.05, 0.06, 0.11, 0.96)
	ast.border_color = Color(0.25, 0.9, 1.0)
	ast.set_border_width_all(3)
	ast.set_corner_radius_all(12)
	ast.set_content_margin_all(18)
	approach_panel.add_theme_stylebox_override("panel", ast)

	var av = VBoxContainer.new()
	av.add_theme_constant_override("separation", 12)
	approach_panel.add_child(av)

	approach_title = Label.new()
	approach_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	approach_title.add_theme_font_size_override("font_size", 19)
	approach_title.add_theme_color_override("font_color", Color(0.25, 0.92, 1.0))
	av.add_child(approach_title)

	var smart_btn = Button.new()
	smart_btn.text = "A) SMART / BUGSTARS APPROACH (Low 2-Star Police Heat)"
	smart_btn.custom_minimum_size = Vector2(450, 46)
	smart_btn.pressed.connect(confirm_heist_approach.bind(false))
	av.add_child(smart_btn)

	var loud_btn = Button.new()
	loud_btn.text = "B) LOUD / GUNS BLAZING (+$3,000-$5,000 Bonus, 4-Star SWAT Heat)"
	loud_btn.custom_minimum_size = Vector2(450, 46)
	loud_btn.pressed.connect(confirm_heist_approach.bind(true))
	av.add_child(loud_btn)
	hud.add_child(approach_panel)

	# Story Log Modal
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
	go_btn.text = "CLOSE STORY LOG"
	go_btn.custom_minimum_size = Vector2(220, 44)
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
	udesc.text = "The Union Depository gold is yours, but Steve Haines (FIB) and Devin Weston\ndemand you betray your crew. Choose how the story ends:"
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
		clear_save()
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
		stats_label.text = "%s\nCompletion Time: %02d:%02d\nFinal Net Worth: $%d\n\nAll Free-Roam Events & Military Hardware Unlocked!" % [end_desc, mins, secs, total]
	victory_panel.visible = true
	get_tree().paused = true
