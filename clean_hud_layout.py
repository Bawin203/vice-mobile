mm = open("mission_manager.gd").read()

# 1. Replace build_mobile_action_dock() with a sleek collapsible Phone/Menu Drawer + context-aware bottom buttons
old_dock_start = mm.find("func build_mobile_action_dock() -> void:")
old_dock_end = mm.find("func build_story_ui() -> void:")
assert old_dock_start != -1 and old_dock_end != -1, "Could not locate build_mobile_action_dock"

new_dock_code = """var menu_drawer: PanelContainer = null
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

"""

mm = mm[:old_dock_start] + new_dock_code + mm[old_dock_end:]

# 2. Make Objective Card compact (380px wide, subtle dark glass) so it never crowds the screen
mm = mm.replace(
"""	objective_panel.offset_left = 22
	objective_panel.offset_top = 46
	objective_panel.offset_right = 520
	objective_panel.offset_bottom = 104
	var ost = StyleBoxFlat.new()
	ost.bg_color = Color(0.05, 0.07, 0.12, 0.88)""",
"""	objective_panel.offset_left = 22
	objective_panel.offset_top = 44
	objective_panel.offset_right = 400
	objective_panel.offset_bottom = 92
	var ost = StyleBoxFlat.new()
	ost.bg_color = Color(0.05, 0.07, 0.12, 0.72)"""
)

# 3. Contextually toggle CAR vs EXIT and hide FIRE when driving a normal car
mm = mm.replace(
"""	if radio_btn:
		radio_btn.visible = driving_car""",
"""	if radio_btn:
		radio_btn.visible = driving_car
	if car_btn:
		car_btn.text = "EXIT" if driving_car else "CAR"
	if fire_btn:
		fire_btn.visible = not driving_car"""
)

# 4. Compact subtitle banter box positioned cleanly above the bottom edge
mm = mm.replace(
"""	comms_panel.offset_left = -330
	comms_panel.offset_top = -124
	comms_panel.offset_right = 330
	comms_panel.offset_bottom = -74""",
"""	comms_panel.offset_left = -280
	comms_panel.offset_top = -102
	comms_panel.offset_right = 280
	comms_panel.offset_bottom = -62"""
)

open("mission_manager.gd", "w").write(mm)
print("Cleaned HUD layout: collapsible [≡ MENU] drawer, compact Objective pill & context-aware action buttons OK!")
