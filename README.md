# Vice Mobile — 3D Open-World Action Sandbox (Godot 4.7)

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
