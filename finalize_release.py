import os, shutil

# 1. Archive unused 50MB-150MB .glb files outside res:// so Godot exports stay lean (<100 MB)
backup_dir = os.path.expanduser("~/vice-mobile-unused-models")
os.makedirs(backup_dir, exist_ok=True)
unused_glbs = ["gangster.glb", "cop.glb", "walk.glb", "run.glb", "npc2.glb", "human_player.glb", "character.glb"]
moved = []
for fname in unused_glbs:
	src = os.path.join("models", fname)
	if os.path.exists(src):
		shutil.move(src, os.path.join(backup_dir, fname))
		moved.append(fname)
	if os.path.exists(src + ".import"):
		shutil.move(src + ".import", os.path.join(backup_dir, fname + ".import"))

print(f"Archived unused GLBs to {backup_dir}: {moved}")

# 2. Inject user://save.json persistence ([K] Quick-Save + Auto-Save + Auto-Load) into mission_manager.gd
mm = open("mission_manager.gd").read()

save_methods = """const SAVE_PATH = "user://vice_mobile_save.json"

func save_progress(announce: bool = false) -> void:
	var save_stage = story_stage
	# Snap mid-chase/mid-combat sub-stages back to the start of that chapter so resuming never strands the player
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
			queue_banter([{"speaker": "SYSTEM", "line": "Progress saved! (Stage %d • Total $%d)" % [save_stage, cash + bank_balance], "col": Color(0.3, 0.95, 0.5)}])

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
"""

assert "const SAVE_PATH" not in mm, "Save system already injected"
mm = mm.replace("func _ready() -> void:", save_methods + "\nfunc _ready() -> void:")

# Update start_heist_campaign() to restore saved chapter state if user://vice_mobile_save.json exists
old_start = """func start_heist_campaign() -> void:
	if story_stage == 0:
		apply_protagonist(0, false)
		setup_stage_0_lamar()"""

new_start = """func start_heist_campaign() -> void:
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
		queue_banter([{"speaker": "SYSTEM", "line": "Welcome back! Free Roam & Ending %s loaded ($%d)." % [chosen_ending, cash + bank_balance], "col": Color(0.3, 0.95, 0.5)}])
	else:
		setup_stage_0_lamar()"""

assert old_start in mm, "start_heist_campaign not found"
mm = mm.replace(old_start, new_start)

# Bind [K] to manual save + auto-save on deposits, chapter advances, and ending selection
mm = mm.replace(
	"elif event.keycode == KEY_B:\n\t\t\tdeposit_to_buckme()",
	"elif event.keycode == KEY_B:\n\t\t\tdeposit_to_buckme()\n\t\telif event.keycode == KEY_K:\n\t\t\tsave_progress(true)"
)
mm = mm.replace(
	'queue_banter([{"speaker": "BUCKME APP", "line": "Deposited $%d! Safe Bank Balance: $%d" % [amt, bank_balance], "col": Color(0.3, 0.95, 0.5)}])',
	'save_progress(false)\n\tqueue_banter([{"speaker": "BUCKME APP", "line": "Deposited $%d & Saved! Safe Bank Balance: $%d" % [amt, bank_balance], "col": Color(0.3, 0.95, 0.5)}])'
)
mm = mm.replace(
	"func advance_story_beacon() -> void:",
	"func advance_story_beacon() -> void:\n\tcall_deferred(\"save_progress\", false)"
)
mm = mm.replace(
	"func select_ending(opt: String) -> void:",
	"func select_ending(opt: String) -> void:\n\tcall_deferred(\"save_progress\", false)"
)
mm = mm.replace(
	"get_tree().reload_current_scene()",
	"clear_save()\n\t\tget_tree().reload_current_scene()"
)
open("mission_manager.gd", "w").write(mm)

# 3. Create .gitignore & GitHub README.md
open(".gitignore", "w").write("""# Godot 4+ ignores
.godot/
*.translation
export_presets.cfg
*.dmg
*.zip
*.app/
.DS_Store
""")

open("README.md", "w").write("""# Vice Mobile — 3D Open-World Action Sandbox (Godot 4.7)

A 3D open-world crime & heist vertical slice built in **Godot Engine 4.7 (GDScript)** featuring a 5-chapter story campaign, three playable protagonists (**Franklin, Michael, and Trevor**), street-aligned GPS pathfinding, dynamic wanted levels, and military hardware.

## Features
- **5-Chapter Story Campaign & Interactive Contacts:** Talk (`[E]`) to **Lamar**, **Lester**, and **Trevor**, choose between **Smart** and **Loud** heist approaches, and decide the finale with **Option A (Something Sensible)**, **Option B (The Time's Come)**, or **Option C (The Third Way)**.
- **Three Playable Protagonists (`[H]` Switch | `[V]` Special Ability):**
  - **Franklin:** *Driving Focus* (`0.45x` slow-motion handling in vehicles)
  - **Michael:** *Bullet-Time* (tactical slow-motion aim & gunfire)
  - **Trevor:** *Red Mist Rage* (`75%` incoming damage reduction)
- **Procedural City & Street-Aligned GPS:** Grid-based metropolis with enterable interiors (**Vangelico / Pacific Bank**, **Pay 'n' Spray**, **Safehouse**), **Mile Zero Military Base** (watchtowers, armed guards, **Rhino Tank** with rotating 120mm turret), and **VCIA Airfield** (**Lapwing Jet**).
- **Save System (`user://vice_mobile_save.json`):** Automatic chapter & bank save plus instant manual save via `[K]`.

## Controls
| Key | Action |
|---|---|
| `W A S D` | Move / Drive / Steer |
| `Shift` | Sprint / Turbo Boost |
| `Space` | Jump / Handbrake / Jet Climb |
| `Right-Click` / `R` | Aim & Fire Weapon / Rhino Tank 120mm Cannon |
| `F` | Enter / Exit Car, Jet, or Rhino Tank |
| `E` | Talk to Story Contacts (`Lamar`, `Lester`, `Trevor`) |
| `H` | Switch Protagonist (`Franklin` / `Michael` / `Trevor`) |
| `V` | Activate Character Special Ability |
| `Q` | Cycle Car Radio Stations |
| `J` | Open Story Log & Current Objective |
| `B` | Deposit Cash to BuckMe Bank |
| `K` | Quick-Save Progress |

## Running Locally
1. Open **Godot Engine 4.7+** and import `project.godot`.
2. Press **Play (`Cmd + B` on macOS / `F5` on Windows/Linux)**.
""")

print("Injected Save/Load ([K] + Auto-Save), cleaned unused models, and generated README.md & .gitignore OK!")
