extends CanvasLayer

var wanted_level = 0
var police_spawned = false
var hp = 100
var max_hp = 100
var is_wasted = false
var bust_progress: float = 0.0
var bust_bar: ProgressBar
var police_scene = preload("res://police_car.tscn")

# GTA VI Police Perception & Focus Stats
var knows_face: bool = false
var knows_car: bool = false
var knows_cctv: bool = false
var known_car_name: String = ""
var evasion_timer: float = 0.0
var dispatch_delay: float = 0.0
var hitmarker_timer: float = 0.0
var hitmarker_lbl: Label = null
var focus_energy: float = 100.0
var focus_active: bool = false

@onready var stars_label = $TopRight/StarsLabel
@onready var speed_label = $TopRight/SpeedLabel
@onready var hp_bar = $TopRight/HPBar
@onready var wasted_panel = $WastedOverlay
@onready var hint_label = $BottomHint

var weapon_label: Label
var perception_label: Label
var veh_speedo: Label
var fuel_bar: ProgressBar
var focus_bar: ProgressBar

func _ready():
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
	add_child(hitmarker_lbl)
	style_gta_hud()
	update_hud()
	call_deferred("spawn_initial_patrol")

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			toggle_focus_mode()
		elif event.keycode == KEY_C:
			swap_outfit()

func toggle_focus_mode():
	if is_wasted: return
	if not focus_active and focus_energy > 20.0:
		focus_active = true
		Engine.time_scale = 0.42
		if hint_label:
			hint_label.text = "FOCUS MODE ACTIVE: Slow-Motion Tactical Aiming ([V] to Exit)"
	else:
		focus_active = false
		Engine.time_scale = 1.0

func swap_outfit():
	var main = get_parent()
	if main == null: return
	var p = main.get_node_or_null("Player")
	if p == null or not p.visible:
		if hint_label:
			hint_label.text = "EXIT VEHICLE FIRST to grab spare clothes from trunk ([C])!"
		return
	var outfits = [
		[Color(0.92, 0.25, 0.45), Color(0.12, 0.14, 0.2)],
		[Color(0.15, 0.78, 0.65), Color(0.92, 0.90, 0.85)],
		[Color(0.95, 0.65, 0.15), Color(0.16, 0.18, 0.24)],
		[Color(0.22, 0.48, 0.95), Color(0.14, 0.16, 0.22)]
	]
	var pick = outfits[randi() % outfits.size()]
	if p.human_node and p.human_node.has_method("build_human"):
		p.human_node.build_human(pick[0], pick[1], true)
	knows_face = false
	update_hud()
	if hint_label:
		hint_label.text = "OUTFIT CHANGED: Police lost your [FACE] description!"

func on_vehicle_switched(car_name: String):
	if car_name != known_car_name:
		knows_car = false
		update_hud()

func style_gta_hud():
	var tr = get_node_or_null("TopRight")
	if tr:
		tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tr.offset_left = -390
		tr.offset_top = 18
		tr.offset_right = -22
		tr.offset_bottom = 135
	var mm = get_node_or_null("Minimap")
	if mm:
		mm.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		mm.offset_left = 22
		mm.offset_top = -172
		mm.offset_right = 232
		mm.offset_bottom = -42

	if hp_bar:
		hp_bar.get_parent().remove_child(hp_bar)
		add_child(hp_bar)
		hp_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		hp_bar.offset_left = 22
		hp_bar.offset_top = -38
		hp_bar.offset_right = 90
		hp_bar.offset_bottom = -26
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.78, 0.35)
		hp_bar.add_theme_stylebox_override("fill", sb)

		var armor_bar = ProgressBar.new()
		armor_bar.name = "ArmorBar"
		armor_bar.show_percentage = false
		armor_bar.value = 100
		armor_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		armor_bar.offset_left = 93
		armor_bar.offset_top = -38
		armor_bar.offset_right = 161
		armor_bar.offset_bottom = -26
		var ab = StyleBoxFlat.new()
		ab.bg_color = Color(0.18, 0.72, 0.92)
		armor_bar.add_theme_stylebox_override("fill", ab)
		add_child(armor_bar)

		focus_bar = ProgressBar.new()
		focus_bar.name = "FocusBar"
		focus_bar.show_percentage = false
		focus_bar.value = 100
		focus_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		focus_bar.offset_left = 164
		focus_bar.offset_top = -38
		focus_bar.offset_right = 232
		focus_bar.offset_bottom = -26
		var fb = StyleBoxFlat.new()
		fb.bg_color = Color(0.95, 0.75, 0.15)
		focus_bar.add_theme_stylebox_override("fill", fb)
		add_child(focus_bar)

	if speed_label:
		speed_label.add_theme_font_size_override("font_size", 20)
		speed_label.add_theme_color_override("font_color", Color(0.32, 0.88, 0.42))
		speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		speed_label.add_theme_constant_override("outline_size", 4)
		speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if stars_label:
		stars_label.add_theme_font_size_override("font_size", 20)
		stars_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		stars_label.add_theme_constant_override("outline_size", 4)
		stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	perception_label = Label.new()
	perception_label.text = ""
	perception_label.add_theme_font_size_override("font_size", 13)
	perception_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	perception_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	perception_label.add_theme_constant_override("outline_size", 3)
	perception_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$TopRight.add_child(perception_label)

	weapon_label = Label.new()
	weapon_label.text = "PISTOL  |  [V] FOCUS  |  [B] BUCKME"
	weapon_label.add_theme_font_size_override("font_size", 14)
	weapon_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	weapon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	weapon_label.add_theme_constant_override("outline_size", 3)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$TopRight.add_child(weapon_label)

	bust_bar = ProgressBar.new()
	bust_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bust_bar.offset_left = -130
	bust_bar.offset_top = 52
	bust_bar.offset_right = 130
	bust_bar.offset_bottom = 74
	bust_bar.show_percentage = false
	bust_bar.visible = false
	var bb_fill = StyleBoxFlat.new()
	bb_fill.bg_color = Color(0.15, 0.45, 1.0)
	bust_bar.add_theme_stylebox_override("fill", bb_fill)
	var bust_lbl = Label.new()
	bust_lbl.text = "BUSTED IN PROGRESS..."
	bust_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bust_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bust_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bust_lbl.add_theme_font_size_override("font_size", 12)
	bust_bar.add_child(bust_lbl)
	add_child(bust_bar)

	veh_speedo = Label.new()
	veh_speedo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	veh_speedo.offset_left = -240
	veh_speedo.offset_top = -78
	veh_speedo.offset_right = -24
	veh_speedo.offset_bottom = -38
	veh_speedo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	veh_speedo.add_theme_font_size_override("font_size", 24)
	veh_speedo.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	veh_speedo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	veh_speedo.add_theme_constant_override("outline_size", 4)
	veh_speedo.visible = false
	add_child(veh_speedo)

	fuel_bar = ProgressBar.new()
	fuel_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fuel_bar.offset_left = -190
	fuel_bar.offset_top = -34
	fuel_bar.offset_right = -24
	fuel_bar.offset_bottom = -22
	fuel_bar.show_percentage = false
	fuel_bar.visible = false
	var ff = StyleBoxFlat.new()
	ff.bg_color = Color(0.95, 0.55, 0.12)
	fuel_bar.add_theme_stylebox_override("fill", ff)
	add_child(fuel_bar)

	if hint_label:
		hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		hint_label.offset_top = 14
		hint_label.offset_bottom = 42
		hint_label.add_theme_font_size_override("font_size", 15)
		hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		hint_label.add_theme_constant_override("outline_size", 3)

	var tc = get_node_or_null("TouchUI")
	if tc:
		for child in tc.get_children():
			if child is Button:
				child.modulate = Color(1, 1, 1, 0.45)

func _process(delta):
	bust_progress = max(0.0, bust_progress - delta * 0.35)
	if bust_bar:
		bust_bar.visible = bust_progress > 0.02 and wanted_level > 0 and not is_wasted
		bust_bar.value = bust_progress * 100.0

	# Focus energy drain/recharge
	if focus_active:
		focus_energy = max(0.0, focus_energy - (delta / max(Engine.time_scale, 0.1)) * 22.0)
		if focus_energy <= 0.5:
			toggle_focus_mode()
	else:
		focus_energy = min(100.0, focus_energy + delta * 10.0)
	if focus_bar:
		focus_bar.value = focus_energy

	var main = get_parent()
	if main == null: return
	var w = main.get_node_or_null("Player/MeshInstance3D/WeaponMount")
	if w and weapon_label:
		weapon_label.text = "%s  |  [V] FOCUS  |  [B] BANK" % w.unlocked_weapons[w.current_idx]

	# Check active vehicle speedometer + fuel
	var driving = false
	var active_target: Node3D = main.get_node_or_null("Player")
	for c in main.get_children():
		if (c is VehicleBody3D or c.name == "Helicopter") and c.get("is_driven") == true:
			driving = true
			active_target = c
			var mph = int(c.linear_velocity.length() * 2.237) if c is VehicleBody3D else int(c.velocity.length() * 2.237)
			var f_val = c.get("fuel")
			veh_speedo.text = "%03d MPH%s" % [mph, "  |  FUEL %d%%" % int(f_val) if f_val != null else ""]
			if fuel_bar:
				fuel_bar.visible = f_val != null
				if f_val != null: fuel_bar.value = f_val
			break
	if veh_speedo: veh_speedo.visible = driving
	if not driving and fuel_bar: fuel_bar.visible = false

	dispatch_delay = max(0.0, dispatch_delay - delta)
	# Active Sightline Evasion Cooldown
	if wanted_level > 0 and active_target and not is_wasted:
		var spotted = false
		for c in main.get_children():
			if (c.name.begins_with("PoliceCar") or c.name.begins_with("PoliceOfficer")) and c.global_position.distance_to(active_target.global_position) < 42.0:
				spotted = true
				break
		if spotted:
			evasion_timer = 0.0
		else:
			var decay_mult = 1.8 if (not knows_face and not knows_car) else 1.0
			evasion_timer += delta * decay_mult
			if evasion_timer >= 6.5:
				evasion_timer = 0.0
				wanted_level = max(0, wanted_level - 1)
				if wanted_level == 0:
					knows_face = false
					knows_car = false
					knows_cctv = false
					if hint_label:
						hint_label.text = "EVADED POLICE! Regional Heat Cooled Down."
				update_hud()

func get_safe_road_spawn(near_pos: Vector3) -> Vector3:
	var best_spot = Vector3(0.0, 0.75, -36.0)
	var best_score = 999999.0
	var main = get_parent()
	for gx in range(-3, 4):
		for gz in range(-3, 4):
			var pt = Vector3(gx * 36.0, 0.75, gz * 36.0)
			var d = pt.distance_to(near_pos)
			if d < 52.0 or d > 95.0:
				continue
			var occupied = false
			for child in main.get_children():
				if child is VehicleBody3D and child.global_position.distance_to(pt) < 8.0:
					occupied = true
					break
			if not occupied and abs(d - 64.0) < best_score:
				best_score = abs(d - 64.0)
				best_spot = pt
	return best_spot

func spawn_initial_patrol():
	var patrol = police_scene.instantiate()
	patrol.name = "PoliceCar_Patrol"
	patrol.position = Vector3(0.0, 0.75, -48.0)
	get_parent().add_child(patrol)

func add_wanted(stars = 1, is_cctv = false):
	if is_wasted: return
	wanted_level = clamp(wanted_level + stars, 0, 6)
	evasion_timer = 0.0
	if is_cctv:
		knows_cctv = true
	var main = get_parent()
	var driving_car = null
	for c in main.get_children():
		if c is VehicleBody3D and c.get("is_driven") == true:
			driving_car = c
			break
	if driving_car:
		knows_car = true
		known_car_name = driving_car.name
	else:
		knows_face = true
	update_hud()
	if wanted_level > 0:
		dispatch_delay = 4.5
		get_tree().create_timer(4.5).timeout.connect(func():
			if wanted_level > 0 and not is_wasted:
				spawn_police()
		)

func spawn_police():
	var main = get_parent()
	var active_cops = 0
	for c in main.get_children():
		if c.name.begins_with("PoliceCar"):
			active_cops += 1
	var target_cops = min(wanted_level + 1, 5)
	while active_cops < target_cops:
		var cop = police_scene.instantiate()
		cop.name = "PoliceCar_%d_%d" % [Time.get_ticks_msec(), active_cops]
		var p = main.get_node_or_null("Player")
		var base = p.global_position if p else Vector3.ZERO
		cop.position = get_safe_road_spawn(base)
		main.add_child(cop)
		active_cops += 1

func advance_bust(delta: float):
	if is_wasted or wanted_level <= 0 or dispatch_delay > 0.0:
		return
	bust_progress += delta * 0.24
	if bust_progress >= 1.0:
		trigger_busted()

func trigger_busted():
	is_wasted = true
	bust_progress = 0.0
	focus_active = false
	if bust_bar: bust_bar.visible = false
	if wasted_panel:
		for ch in wasted_panel.get_children():
			if ch is Label:
				ch.set_meta("orig_text", ch.text)
				ch.text = "BUSTED!"
				ch.modulate = Color(0.25, 0.55, 1.0)
		wasted_panel.visible = true
	Engine.time_scale = 0.35
	await get_tree().create_timer(1.3, true, false, true).timeout
	Engine.time_scale = 1.0
	if wasted_panel:
		wasted_panel.visible = false
		for ch in wasted_panel.get_children():
			if ch is Label and ch.has_meta("orig_text"):
				ch.text = ch.get_meta("orig_text")
				ch.modulate = Color.WHITE
	var mm = get_parent().get_node_or_null("MissionManager")
	if mm:
		# Wallet cash is confiscated on arrest; BuckMe bank balance stays safe!
		mm.cash = 0
	wanted_level = 0
	knows_face = false
	knows_car = false
	knows_cctv = false
	police_spawned = false
	is_wasted = false
	update_hud()
	for c in get_parent().get_children():
		if c.name.begins_with("PoliceCar") or c.name.begins_with("PoliceOfficer"):
			c.queue_free()
	var p = get_parent().get_node_or_null("Player")
	if p:
		if p.nearby_car and p.nearby_car.is_driven:
			p.nearby_car.exit_vehicle()
		p.global_position = Vector3(2.5, 1.5, 2.5)
		p.velocity = Vector3.ZERO

func damage_player(amount):
	if is_wasted: return
	hp = clamp(hp - amount, 0, max_hp)
	if hp_bar: hp_bar.value = hp
	if hp <= 0:
		trigger_wasted()

func trigger_wasted():
	is_wasted = true
	focus_active = false
	wasted_panel.visible = true
	Engine.time_scale = 0.35
	await get_tree().create_timer(1.2, true, false, true).timeout
	Engine.time_scale = 1.0
	wasted_panel.visible = false
	hp = max_hp
	if hp_bar: hp_bar.value = hp
	var mm = get_parent().get_node_or_null("MissionManager")
	if mm:
		mm.cash = 0
	wanted_level = 0
	knows_face = false
	knows_car = false
	knows_cctv = false
	police_spawned = false
	is_wasted = false
	update_hud()
	for c in get_parent().get_children():
		if c.name.begins_with("PoliceCar") or c.name.begins_with("PoliceOfficer"): c.queue_free()
	var p = get_parent().get_node_or_null("Player")
	if p:
		if p.nearby_car and p.nearby_car.is_driven:
			p.nearby_car.exit_vehicle()
		p.global_position = Vector3(2.5, 1.5, 2.5)
		p.velocity = Vector3.ZERO

func update_hud():
	var s = ""
	for i in range(6):
		s += "★ " if i < wanted_level else "☆ "
	stars_label.text = s.strip_edges()
	stars_label.modulate = Color(1, 0.25, 0.25) if wanted_level > 0 else Color(1, 1, 1, 0.5)

	if perception_label:
		if wanted_level <= 0:
			perception_label.text = "CLEAR  |  [C] OUTFIT  |  [B] BANK"
			perception_label.modulate = Color(0.65, 0.75, 0.85, 0.8)
		else:
			var tags: Array[String] = []
			if knows_face: tags.append("[FACE]")
			if knows_car: tags.append("[CAR]")
			if knows_cctv: tags.append("[CCTV]")
			perception_label.text = "DISPATCH: " + (" ".join(tags) if tags.size() > 0 else "SEARCHING...")
			perception_label.modulate = Color(1.0, 0.78, 0.2)
