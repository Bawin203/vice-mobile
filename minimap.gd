extends Control

var is_expanded: bool = false
var compact_scale: float = 0.95
var expanded_scale: float = 1.55
var has_waypoint: bool = false
var waypoint_world: Vector3 = Vector3.ZERO
var waypoint_title: String = "DESTINATION"

var world_beacon: Node3D = null
var road_ribbon_root: Node3D = null
var ribbon_pool: Array[MeshInstance3D] = []
var ribbon_mat: StandardMaterial3D = null
var nav_banner: PanelContainer = null
var nav_label: Label = null

const LANDMARKS = [
	{"pos": Vector3(36, 0, 14), "col": Color(0.0, 0.92, 1.0), "tag": "G", "name": "PAY 'N' SPRAY"},
	{"pos": Vector3(-36, 0, 14), "col": Color(1.0, 0.82, 0.12), "tag": "$", "name": "PACIFIC BANK"},
	{"pos": Vector3(0, 0, 50), "col": Color(0.95, 0.25, 0.85), "tag": "H", "name": "SAFEHOUSE / CASINO"},
	{"pos": Vector3(0, 0, -22), "col": Color(0.20, 0.95, 0.45), "tag": "+", "name": "MED-BAY"},
	{"pos": Vector3(8, 0, -10), "col": Color(1.0, 0.55, 0.15), "tag": "W", "name": "AMMU-NATION"},
	{"pos": Vector3(36, 0, -22), "col": Color(1.0, 0.65, 0.15), "tag": "F", "name": "GAS STATION"},
	{"pos": Vector3(-118, 0, 128), "col": Color(0.45, 0.75, 1.0), "tag": "A", "name": "VCIA AIRPORT"},
	{"pos": Vector3(-118, 0, -128), "col": Color(0.45, 0.85, 0.35), "tag": "M", "name": "MILE ZERO BASE"}
]

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	call_deferred("init_3d_gps_visuals")

func init_3d_gps_visuals():
	var main = get_tree().current_scene
	if main == null:
		return

	# 1. Tall glowing destination beam in 3D world
	world_beacon = Node3D.new()
	world_beacon.name = "GPSWorldBeacon"
	world_beacon.visible = false

	var beam = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 2.6
	cm.height = 55.0
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.95, 0.25, 1.0, 0.38)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.emission_enabled = true
	bmat.emission = Color(0.95, 0.25, 1.0)
	bmat.emission_energy_multiplier = 2.8
	cm.material = bmat
	beam.mesh = cm
	beam.position.y = 27.5
	world_beacon.add_child(beam)
	main.add_child(world_beacon)

	# 2. Pooled 3D Glowing Road GPS Ribbon (zero per-frame GPU buffer allocation)
	road_ribbon_root = Node3D.new()
	road_ribbon_root.name = "GPSRoadRibbon"
	main.add_child(road_ribbon_root)
	ribbon_mat = StandardMaterial3D.new()
	ribbon_mat.albedo_color = Color(0.95, 0.25, 1.0, 0.85)
	ribbon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_mat.emission_enabled = true
	ribbon_mat.emission = Color(0.95, 0.25, 1.0)
	ribbon_mat.emission_energy_multiplier = 2.8
	for _i in range(6):
		var seg = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.85, 0.08, 1.0)
		bm.material = ribbon_mat
		seg.mesh = bm
		seg.visible = false
		road_ribbon_root.add_child(seg)
		ribbon_pool.append(seg)

	# 3. Clean Turn-by-Turn GPS Banner at top-left above minimap
	var hud = main.get_node_or_null("HUD")
	if hud:
		nav_banner = PanelContainer.new()
		nav_banner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		nav_banner.offset_left = 22
		nav_banner.offset_top = -208
		nav_banner.offset_right = 315
		nav_banner.offset_bottom = -176
		nav_banner.visible = false
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0.06, 0.08, 0.14, 0.92)
		st.border_color = Color(0.92, 0.28, 1.0, 0.9)
		st.set_border_width_all(2)
		st.set_corner_radius_all(6)
		st.set_content_margin_all(5)
		nav_banner.add_theme_stylebox_override("panel", st)

		nav_label = Label.new()
		nav_label.add_theme_font_size_override("font_size", 12)
		nav_label.add_theme_color_override("font_color", Color(0.98, 0.85, 1.0))
		nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nav_banner.add_child(nav_label)
		hud.add_child(nav_banner)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		if not is_expanded:
			if event.button_index == MOUSE_BUTTON_LEFT:
				toggle_expand()
				accept_event()
		else:
			if event.button_index == MOUSE_BUTTON_LEFT:
				set_pin_from_screen(event.position)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				clear_waypoint()
				accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		if not is_expanded:
			toggle_expand()
		else:
			set_pin_from_screen(event.position)
		accept_event()

func set_pin_from_screen(click_pos: Vector2):
	var center = size * 0.5
	var rel = (click_pos - center) / expanded_scale
	var raw_world = Vector3(clamp(rel.x, -160.0, 220.0), 0.5, clamp(rel.y, -160.0, 160.0))

	waypoint_title = "CUSTOM PIN"
	for lm in LANDMARKS:
		if Vector2(raw_world.x, raw_world.z).distance_to(Vector2(lm["pos"].x, lm["pos"].z)) < 14.0:
			raw_world = lm["pos"]
			waypoint_title = lm["name"]
			break

	waypoint_world = raw_world
	has_waypoint = true
	toggle_expand()

func clear_waypoint():
	has_waypoint = false
	if world_beacon: world_beacon.visible = false
	if nav_banner: nav_banner.visible = false
	clear_road_ribbon()

func clear_road_ribbon():
	for seg in ribbon_pool:
		if is_instance_valid(seg):
			seg.visible = false

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_expand()

func toggle_expand():
	is_expanded = not is_expanded
	if is_expanded:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -290
		offset_top = -290
		offset_right = 290
		offset_bottom = 290
	else:
		set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		offset_left = 22
		offset_top = -172
		offset_right = 232
		offset_bottom = -42

func _process(_delta):
	update_3d_navigation()
	queue_redraw()

func update_3d_navigation():
	var main = get_tree().current_scene
	if main == null: return
	var ref_node = get_ref_node(main)
	if ref_node == null: return
	var player = main.get_node_or_null("Player")

	if not has_waypoint:
		if world_beacon: world_beacon.visible = false
		if nav_banner: nav_banner.visible = false
		clear_road_ribbon()
		return

	var dist_2d = Vector2(ref_node.global_position.x, ref_node.global_position.z).distance_to(Vector2(waypoint_world.x, waypoint_world.z))
	if dist_2d < 10.5:
		clear_waypoint()
		var hud = main.get_node_or_null("HUD")
		if hud and hud.get_node_or_null("BottomHint"):
			hud.get_node("BottomHint").text = "ARRIVED AT DESTINATION!"
		return

	if world_beacon:
		world_beacon.visible = true
		world_beacon.global_position = Vector3(waypoint_world.x, 0.2, waypoint_world.z)

	var route = build_street_route(ref_node.global_position, waypoint_world)
	rebuild_road_ribbon(route)

	# Compute relative turn instruction (STRAIGHT / LEFT / RIGHT / U-TURN) relative to camera look direction
	var next_pt = waypoint_world
	for pt in route:
		if Vector2(ref_node.global_position.x, ref_node.global_position.z).distance_to(Vector2(pt.x, pt.z)) > 6.5:
			next_pt = pt
			break

	var look_ang = get_look_angle(player, ref_node)
	var fwd = Vector2(sin(look_ang), -cos(look_ang))
	var to_next = Vector2(next_pt.x - ref_node.global_position.x, next_pt.z - ref_node.global_position.z).normalized()
	var cross = fwd.x * to_next.y - fwd.y * to_next.x
	var dot = fwd.dot(to_next)

	var dir_txt = "▲ STRAIGHT"
	if dot < -0.45:
		dir_txt = "▼ TURN AROUND"
	elif cross > 0.35:
		dir_txt = "▶ TURN RIGHT"
	elif cross < -0.35:
		dir_txt = "◀ TURN LEFT"

	if nav_banner and nav_label:
		nav_banner.visible = true
		nav_label.text = "%s  (%dm)  →  %s" % [dir_txt, int(dist_2d), waypoint_title]

func rebuild_road_ribbon(route: Array[Vector3]):
	if ribbon_pool.is_empty(): return
	var idx = 0
	for i in range(route.size() - 1):
		if idx >= ribbon_pool.size():
			break
		var a = Vector3(route[i].x, 0.32, route[i].z)
		var b = Vector3(route[i + 1].x, 0.32, route[i + 1].z)
		var seg_len = a.distance_to(b)
		if seg_len < 0.5:
			continue
		var seg = ribbon_pool[idx]
		seg.visible = true
		seg.scale = Vector3(1.0, 1.0, seg_len)
		seg.global_position = (a + b) * 0.5
		seg.look_at(b, Vector3.UP)
		idx += 1
	while idx < ribbon_pool.size():
		ribbon_pool[idx].visible = false
		idx += 1

func get_ref_node(main: Node) -> Node3D:
	var player = main.get_node_or_null("Player")
	for c in main.get_children():
		if (c is VehicleBody3D or c.name == "Helicopter") and c.get("is_driven") == true:
			return c
	var city = main.get_node_or_null("CityGenerator")
	if city:
		for c in city.get_children():
			if c is VehicleBody3D and c.get("is_driven") == true:
				return c
	return player

func get_look_angle(player: Node3D, ref_node: Node3D) -> float:
	var look_dir = Vector3.FORWARD
	if ref_node != player:
		var cam_piv = ref_node.get_node_or_null("CameraPivot")
		var yaw = ref_node.global_rotation.y + (cam_piv.rotation.y if cam_piv else 0.0)
		look_dir = Vector3(sin(yaw), 0.0, cos(yaw))
	else:
		var cam = get_viewport().get_camera_3d()
		if cam:
			look_dir = -cam.global_transform.basis.z
		elif player:
			var yaw = player.camera_pivot.global_rotation.y
			look_dir = Vector3(-sin(yaw), 0.0, -cos(yaw))
	look_dir.y = 0.0
	if look_dir.length_squared() < 0.0001:
		return 0.0
	look_dir = look_dir.normalized()
	return atan2(look_dir.x, -look_dir.z)

func snap_to_avenue(val: float) -> float:
	# Buildings are centered at k*36; open streets run halfway between them at k*36 + 18!
	return clamp(floor(val / 36.0) * 36.0 + 18.0, -162.0, 162.0)

func get_front_door_avenue(pos: Vector3) -> Vector2:
	var block_cx = round(pos.x / 36.0) * 36.0
	var block_cz = round(pos.z / 36.0) * 36.0
	# If pos is inside a building pad (within 14.5m of block center), its open door faces +Z (block_cz + 18)
	var rz = snap_to_avenue(pos.z)
	if abs(pos.x - block_cx) < 14.5 and abs(pos.z - block_cz) < 14.5:
		rz = clamp(block_cz + 18.0, -162.0, 162.0)
	var rx = snap_to_avenue(pos.x)
	return Vector2(rx, rz)

func build_street_route(start_pos: Vector3, end_pos: Vector3) -> Array[Vector3]:
	var pts: Array[Vector3] = [start_pos]
	var s_av = get_front_door_avenue(start_pos)
	var e_av = get_front_door_avenue(end_pos)

	# 1. Step straight out in Z onto the open avenue without clipping side walls
	if abs(start_pos.z - s_av.y) > 2.5:
		pts.append(Vector3(start_pos.x, 0.0, s_av.y))
	pts.append(Vector3(s_av.x, 0.0, s_av.y))

	# 2. Follow the open k*36 + 18 avenue grid strictly around all buildings
	if abs(s_av.x - e_av.x) > 0.5:
		pts.append(Vector3(e_av.x, 0.0, s_av.y))
	if abs(s_av.y - e_av.y) > 0.5:
		pts.append(Vector3(e_av.x, 0.0, e_av.y))

	# 3. Align directly with the front doorway on the open avenue, then step straight inside
	pts.append(Vector3(end_pos.x, 0.0, e_av.y))
	pts.append(end_pos)
	return pts

func _draw():
	var rect = Rect2(Vector2.ZERO, size)
	var w_scale = expanded_scale if is_expanded else compact_scale
	var font = ThemeDB.fallback_font

	draw_rect(rect, Color(0.05, 0.07, 0.11, 0.94))

	var main = get_tree().current_scene
	if main == null: return
	var player = main.get_node_or_null("Player")
	if player == null: return
	var ref_node = get_ref_node(main)
	if ref_node == null: return

	var origin = Vector3.ZERO if is_expanded else ref_node.global_position
	var center = size * 0.5
	var road_w = 8.5 if is_expanded else 5.5

	# Beach & Ocean on East side
	var beach_tl = world_to_map(center, origin, w_scale, Vector3(175, 0, -180))
	var beach_br = world_to_map(center, origin, w_scale, Vector3(235, 0, 180))
	var beach_rect = Rect2(beach_tl, beach_br - beach_tl).intersection(rect.grow(-2))
	if beach_rect.has_area():
		draw_rect(beach_rect, Color(0.82, 0.72, 0.45, 0.35))

	var sea_tl = world_to_map(center, origin, w_scale, Vector3(235, 0, -180))
	var sea_br = world_to_map(center, origin, w_scale, Vector3(360, 0, 180))
	var sea_rect = Rect2(sea_tl, sea_br - sea_tl).intersection(rect.grow(-2))
	if sea_rect.has_area():
		draw_rect(sea_rect, Color(0.06, 0.48, 0.68, 0.58))

	# City Block Footprints (centered at k * 36.0)
	for bx in range(-4, 5):
		for bz in range(-4, 5):
			var b_min = world_to_map(center, origin, w_scale, Vector3(bx * 36.0 - 13.0, 0, bz * 36.0 - 13.0))
			var b_max = world_to_map(center, origin, w_scale, Vector3(bx * 36.0 + 13.0, 0, bz * 36.0 + 13.0))
			var brect = Rect2(b_min, b_max - b_min).intersection(rect.grow(-2))
			if brect.has_area():
				draw_rect(brect, Color(0.11, 0.14, 0.19, 0.92))

	# City Road Grid (open avenues at k * 36.0 + 18.0)
	for g in range(-5, 5):
		var road_coord = g * 36.0 + 18.0
		var p1 = world_to_map(center, origin, w_scale, Vector3(road_coord, 0, -162))
		var p2 = world_to_map(center, origin, w_scale, Vector3(road_coord, 0, 162))
		draw_clipped_line(rect, p1, p2, Color(0.30, 0.35, 0.43, 0.98), road_w)
		var p3 = world_to_map(center, origin, w_scale, Vector3(-162, 0, road_coord))
		var p4 = world_to_map(center, origin, w_scale, Vector3(162, 0, road_coord))
		draw_clipped_line(rect, p3, p4, Color(0.30, 0.35, 0.43, 0.98), road_w)

	# GPS Route Line
	if has_waypoint:
		var route = build_street_route(ref_node.global_position, waypoint_world)
		var line_w = 5.0 if is_expanded else 4.0
		for i in range(route.size() - 1):
			var a = world_to_map(center, origin, w_scale, route[i])
			var b = world_to_map(center, origin, w_scale, route[i + 1])
			draw_clipped_line(rect, a, b, Color(0.95, 0.28, 1.0, 0.98), line_w)
		var wp_screen = clamp_rect(rect, world_to_map(center, origin, w_scale, waypoint_world))
		draw_circle(wp_screen, 7.5, Color(0.95, 0.28, 1.0, 0.45))
		draw_circle(wp_screen, 4.5, Color(1.0, 0.65, 1.0))

	# Landmarks
	for lm in LANDMARKS:
		var lp = clamp_rect(rect, world_to_map(center, origin, w_scale, lm["pos"]))
		var r = 8.5 if is_expanded else 6.0
		draw_rect(Rect2(lp - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), lm["col"])
		draw_rect(Rect2(lp - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), Color(0.05, 0.07, 0.1), false, 1.2)
		if font:
			draw_string(font, lp + Vector2(-4.0, 4.5), lm["tag"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.06, 0.08))
			if is_expanded:
				draw_string(font, lp + Vector2(11.0, 4.0), lm["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, lm["col"])

	# Police Cruisers & Foot Officers
	var flash_red = sin(Time.get_ticks_msec() * 0.018) > 0.0
	for node in main.get_children():
		if node is VehicleBody3D and node != ref_node:
			var vp = clamp_rect(rect, world_to_map(center, origin, w_scale, node.global_position))
			if node.name == "SportsCar":
				draw_circle(vp, 4.5, Color(0.2, 0.85, 1.0))
			else:
				var cop_col = Color(1.0, 0.18, 0.18) if flash_red else Color(0.2, 0.5, 1.0)
				draw_circle(vp, 5.2, cop_col)
		elif node.name.begins_with("PoliceOfficer"):
			var op = clamp_rect(rect, world_to_map(center, origin, w_scale, node.global_position))
			draw_circle(op, 3.6, Color(1.0, 0.25, 0.25))

	# Player Look Cursor + FOV Cone
	var p_screen = clamp_rect(rect, world_to_map(center, origin, w_scale, ref_node.global_position))
	var look_ang = get_look_angle(player, ref_node)
	var fwd2d = Vector2(sin(look_ang), -cos(look_ang))
	var right2d = Vector2(cos(look_ang), sin(look_ang))

	var cone_len = 26.0 if is_expanded else 20.0
	var cone_w = 13.0 if is_expanded else 10.0
	draw_colored_polygon([
		p_screen,
		p_screen + fwd2d * cone_len - right2d * cone_w,
		p_screen + fwd2d * cone_len + right2d * cone_w
	], Color(1.0, 1.0, 1.0, 0.2))

	var tip = p_screen + fwd2d * 9.5
	var left_wing = p_screen - fwd2d * 6.0 - right2d * 6.0
	var tail_notch = p_screen - fwd2d * 3.0
	var right_wing = p_screen - fwd2d * 6.0 + right2d * 6.0
	draw_colored_polygon([tip, left_wing, tail_notch, right_wing], Color(1.0, 1.0, 1.0))

	if font:
		draw_string(font, Vector2(size.x - 18, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.35, 0.35))
		var lbl = "[LMB] SET DESTINATION  |  [RMB] CLEAR" if is_expanded else "[M] MAP"
		draw_string(font, Vector2(8, size.y - 7), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.9, 0.98, 0.85))

	draw_rect(rect, Color(0.85, 0.88, 0.94, 0.85), false, 2.5)

func world_to_map(center: Vector2, origin: Vector3, w_scale: float, target_pos: Vector3) -> Vector2:
	var rel = target_pos - origin
	return center + Vector2(rel.x, rel.z) * w_scale

func clamp_rect(rect: Rect2, pt: Vector2) -> Vector2:
	return Vector2(clamp(pt.x, 9.0, rect.size.x - 9.0), clamp(pt.y, 9.0, rect.size.y - 9.0))

func draw_clipped_line(rect: Rect2, a: Vector2, b: Vector2, col: Color, w: float):
	var steps = 24
	for i in range(steps):
		var p1 = a.lerp(b, float(i) / steps)
		var p2 = a.lerp(b, float(i + 1) / steps)
		if rect.grow(-3).has_point(p1) and rect.grow(-3).has_point(p2):
			draw_line(p1, p2, col, w)
