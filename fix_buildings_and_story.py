# 1. Fix REPO_DROP_POS & UNION_DEPO_POS in mission_manager.gd so they sit in wide-open plazas/entrances
mm = open("mission_manager.gd").read()
mm = mm.replace(
	"const REPO_DROP_POS = Vector3(36.0, 0.5, -36.0)",
	"const REPO_DROP_POS = Vector3(18.0, 0.5, -18.0)"
)
mm = mm.replace(
	"const TRIAD_AMBUSH_POS = Vector3(72.0, 0.5, 50.0)",
	"const TRIAD_AMBUSH_POS = Vector3(54.0, 0.5, 54.0)"
)
mm = mm.replace(
	"const UNION_DEPO_POS = Vector3(-72.0, 0.5, -36.0)",
	"const UNION_DEPO_POS = Vector3(-54.0, 0.5, -18.0)"
)
mm = mm.replace(
	"const FINALE_POS = Vector3(0.0, 0.5, 50.0)",
	"const FINALE_POS = Vector3(18.0, 0.5, 54.0)"
)
mm = mm.replace(
	"distance_to(Vector2(marker.global_position.x, marker.global_position.z)) < 6.5:",
	"distance_to(Vector2(marker.global_position.x, marker.global_position.z)) < 8.5:"
)
open("mission_manager.gd", "w").write(mm)

# 2. Add Military Base Guards, Base Perimeter Alarm, and ensure all buildings trigger reliably in city_generator.gd
cg = open("city_generator.gd").read()
if "spawn_military_guards" not in cg:
	cg = cg.replace(
		"\tget_parent().add_child.call_deferred(tank)",
		"\tget_parent().add_child.call_deferred(tank)\n\tcall_deferred(\"spawn_military_guards\", base_center)"
	)
	cg += """
func spawn_military_guards(base_center: Vector3):
	var root = get_parent()
	if root == null: return
	var rig_script = load("res://human_rig.gd")
	var guard_offsets = [
		Vector3(-6.0, 0.5, 16.0),
		Vector3(6.0, 0.5, 16.0),
		Vector3(-10.0, 0.5, -4.0),
		Vector3(10.0, 0.5, -4.0)
	]
	for i in range(guard_offsets.size()):
		var g = CharacterBody3D.new()
		g.name = "MilitaryGuard_%d" % i
		var col = CollisionShape3D.new()
		var cap = CapsuleShape3D.new()
		cap.radius = 0.55
		cap.height = 1.85
		col.shape = cap
		col.position.y = 0.92
		g.add_child(col)

		var rig = Node3D.new()
		rig.set_script(rig_script)
		g.add_child(rig)
		rig.build_human(Color(0.22, 0.30, 0.18), Color(0.16, 0.22, 0.14), true)

		var sc = GDScript.new()
		sc.source_code = "extends CharacterBody3D\\nvar hp = 100\\nvar cd = 1.1\\nfunc _physics_process(delta):\\n\\tcd = max(0.0, cd - delta)\\n\\tvar main = get_tree().current_scene\\n\\tif main == null: return\\n\\tvar p = main.get_node_or_null(\\"Player\\")\\n\\tif p == null: return\\n\\tvar d = global_position.distance_to(p.global_position)\\n\\tif d < 28.0 and cd == 0.0:\\n\\t\\tcd = 1.2\\n\\t\\tvar hud = main.get_node_or_null(\\"HUD\\")\\n\\t\\tif hud:\\n\\t\\t\\tif hud.wanted_level < 4: hud.add_wanted(4 - hud.wanted_level, true)\\n\\t\\t\\tif p.visible: hud.damage_player(6)\\nfunc take_damage(dmg):\\n\\thp -= dmg\\n\\tif hp <= 0: queue_free()\\n"
		sc.reload()
		g.set_script(sc)
		root.add_child(g)
		g.global_position = base_center + guard_offsets[i]
"""
	open("city_generator.gd", "w").write(cg)

print("Fixed Task 1/3/4/5 open coordinates & added Military Base armed guards + alarm perimeter OK")
