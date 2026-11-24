extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var bg = get_node_or_null("BG")
	if bg:
		bg.color = Color(0.04, 0.03, 0.09, 0.88)

	var title = get_node_or_null("Title")
	if title:
		title.text = "VICE MOBILE"
		title.offset_top = -195
		title.offset_bottom = -125
		title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.78))
		title.add_theme_color_override("font_outline_color", Color(0.1, 0.85, 1.0))
		title.add_theme_constant_override("outline_size", 5)

	var sub = Label.new()
	sub.text = "3D OPEN-WORLD HEIST VERTICAL SLICE  •  GODOT ENGINE"
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.offset_left = -260
	sub.offset_top = -122
	sub.offset_right = 260
	sub.offset_bottom = -96
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.25, 0.9, 1.0))
	add_child(sub)

	var controls_box = PanelContainer.new()
	controls_box.set_anchors_preset(Control.PRESET_CENTER)
	controls_box.offset_left = -250
	controls_box.offset_top = -82
	controls_box.offset_right = 250
	controls_box.offset_bottom = 86
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.92)
	style.border_color = Color(0.25, 0.85, 1.0, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	controls_box.add_theme_stylebox_override("panel", style)

	var guide = Label.new()
	guide.text = "HEIST OBJECTIVE: 1. Rob Pacific Bank ($)  →  2. Lose 3-Star Police  →  3. Reach Safehouse\n\n" + \
		"WASD / Arrows: Move & Drive    |    Shift: Sprint / Nitro    |    F: Enter/Exit Vehicle\n" + \
		"Right-Click / R: Shoot & Drive-By    |    G: Switch Weapon    |    V: Focus Slow-Mo\n" + \
		"M / Click Radar: Expand Map & Set GPS Pin    |    C: Swap Outfit    |    B: Bank Cash"
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide.add_theme_font_size_override("font_size", 12)
	guide.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	controls_box.add_child(guide)
	add_child(controls_box)

	var play_btn = get_node_or_null("PlayBtn")
	if play_btn:
		play_btn.text = "START HEIST"
		play_btn.offset_left = -120
		play_btn.offset_top = 104
		play_btn.offset_right = 120
		play_btn.offset_bottom = 156

func _on_play_pressed():
	visible = false
	get_tree().paused = false
	var mm = get_tree().current_scene.get_node_or_null("MissionManager")
	if mm and mm.has_method("start_heist_campaign"):
		mm.start_heist_campaign()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		visible = not visible
		get_tree().paused = visible
