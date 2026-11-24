# 1. Fix character ground height offset in human_rig.gd so soles always rest cleanly on y = 0.0
hr = open("human_rig.gd").read()
hr = hr.replace(
	"model_inst.position = Vector3(-cx, -0.88 - min_y, -cz)",
	"model_inst.position = Vector3(-cx, -0.90 - min_y, -cz)"
)
hr = hr.replace(
	"model_inst.position = Vector3(0, -0.88, 0)",
	"model_inst.position = Vector3(0, -0.90, 0)"
)
open("human_rig.gd", "w").write(hr)

# 2. Fix NPC/Pedestrian ground spawn heights in city_generator.gd so nobody spawns sunk into the street
cg = open("city_generator.gd").read()
cg = cg.replace("Vector3(-6.0, 0.5, 16.0)", "Vector3(-6.0, 0.95, 16.0)")
cg = cg.replace("Vector3(6.0, 0.5, 16.0)", "Vector3(6.0, 0.95, 16.0)")
cg = cg.replace("Vector3(-10.0, 0.5, -4.0)", "Vector3(-10.0, 0.95, -4.0)")
cg = cg.replace("Vector3(10.0, 0.5, -4.0)", "Vector3(10.0, 0.95, -4.0)")
open("city_generator.gd", "w").write(cg)

# 3. Add Character-Specific Special Abilities (Franklin/Michael/Trevor) + Screen Tint to player.gd
pl = open("player.gd").read()
if "protag_ability_active" not in pl:
	pl = pl.replace(
		"var focus_energy: float = 100.0",
		"var focus_energy: float = 100.0\nvar rage_overlay: ColorRect = null"
	)
	pl = pl.replace(
		"func _ready():",
		"""func _ready():
	var hud = get_parent().get_node_or_null("HUD")
	if hud:
		rage_overlay = ColorRect.new()
		rage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		rage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rage_overlay.color = Color(1.0, 0.25, 0.05, 0.0)
		hud.add_child(rage_overlay)"""
	)
	pl = pl.replace(
		"Engine.time_scale = 0.45 if is_focus else 1.0",
		"""var mm = get_parent().get_node_or_null("MissionManager")
		var p_idx = mm.active_protag_idx if mm and mm.get("active_protag_idx") != null else 0
		if is_focus:
			if p_idx == 2:
				# Trevor: Red Mist Rampage (normal speed, 75% damage reduction, fiery screen tint)
				Engine.time_scale = 1.0
				if rage_overlay: rage_overlay.color = Color(1.0, 0.22, 0.05, 0.18)
			else:
				# Franklin (Driving Focus) & Michael (Bullet-Time)
				Engine.time_scale = 0.45
				if rage_overlay: rage_overlay.color = Color(0.1, 0.65, 1.0, 0.10)
		else:
			Engine.time_scale = 1.0
			if rage_overlay: rage_overlay.color = Color(1.0, 0.25, 0.05, 0.0)"""
	)
	open("player.gd", "w").write(pl)

# Trevor 75% damage reduction in game_manager.gd
gm = open("game_manager.gd").read()
if "Trevor Red Mist" not in gm:
	gm = gm.replace(
		"func damage_player(amount: int):",
		"""func damage_player(amount: int):
	# Trevor Red Mist cuts incoming damage by 75%
	var p = get_parent().get_node_or_null("Player")
	var mm = get_parent().get_node_or_null("MissionManager")
	if p and p.get("is_focus") == true and mm and mm.get("active_protag_idx") == 2:
		amount = max(1, int(amount * 0.25))"""
	)
	open("game_manager.gd", "w").write(gm)

print("Fixed ground heights, added Franklin/Michael/Trevor [V] Special Abilities OK")
