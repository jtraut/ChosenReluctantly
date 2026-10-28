# Roadmap

Milestones match `docs/GDD.md` §13. Task status within a milestone is tracked here; design intent lives in the GDD; one-off technical/assumption calls live in `docs/DECISIONS.md`.

## Milestone 1 — GDD v0.2 — **Done**
Engine, perspective, and slice classes/elements decided (Godot, 3D isometric, Rogue/Wizard, Fire/Water).

## Milestone 1.5 — Project scaffold — **Done**
- [x] Move `GDD.md` to `docs/GDD.md`
- [x] Create `/src /scenes /data /assets /tests /tools /docs` layout
- [x] `project.godot`, `.gitignore`, `.gitattributes` for Godot 4
- [x] Install Godot 4.7.2, verify headless run with zero errors/warnings
- [x] Pick and wire up a headless-runnable test framework (gdUnit4)
- [x] Root `CLAUDE.md` working agreements
- [x] Role agents in `.claude/agents/`
- [x] `README.md` with run/test instructions

## Milestone 2 — Combat Feel Prototype — **Done**
Goal: one arena room where moving, aiming, and using card slots already feels good. The only question this milestone answers is "is the core combat fun?"

- [x] Camera and player: fixed isometric 3D camera, capsule player, WASD movement, mouse-raycast aim, smooth camera follow
- [x] Basic attack: left click, fixed cooldown, melee arc (see DECISIONS.md)
- [x] Dodge roll: Space, i-frames, own cooldown, universal (separate from Movement slot)
- [x] Generic stat-modifier system (stub values, data-driven hook for future passives/equipment)
- [x] Card data schema + loader + validation (fails loudly on malformed JSON)
- [x] Effect-template registry: projectile, cone, aoe, dash, heal, apply_status, buff
- [x] Card slot system: 5 data-driven slots, mini-decks, shuffle/reshuffle, cooldown = base + modifier, dead-card swap with penalty cooldown
- [x] Status effect system, generic, with Burn as the first implementation
- [x] Damage/resistance model: elemental-only resistance, caps per GDD §7
- [x] Enemies: melee chaser, ranged shooter, resistant elemental type; health, hit reactions, knockback, simple chase AI
- [x] Wave spawner for the arena
- [x] HUD: 5 slot widgets (name, cooldown sweep, next-card preview), health bar
- [x] Debug overlay (F3): FPS, slot cooldowns, deck contents
- [x] Starter card set: ~12-15 JSON cards for Fire Rogue (class/element/neutral pools)
- [x] Juice pass: hit-stop, screen shake, damage numbers, hit flash, enemy attack telegraphs
- [x] Unit tests: cooldown math, slot cycling/reshuffle, dead-card swap penalty, resistance math, Burn tick, card schema validation
- [x] Headless bot-simulation stub in `/tools`
- [x] QA pass over the milestone before marking done

## Post-milestone polish
Small director-requested items between milestones. Not Milestone 3 scope.

- [x] **HP bars above enemies** — **Done** 2026-10-27 (qa PASS e60e515, 83/83 tests; playtester: no blockers)
  - **Shipped as:** `scenes/ui/EnemyHpBar.tscn`, `src/ui/EnemyHpBar.gd`, `src/ui/UiConfig.gd`, `assets/shaders/enemy_hp_bar.gdshader`, config in `data/ui.json` (`hp_bars`) - names differ from the brief's guesses below. Commits b31cbde, 0309f86, bcbfe34, e60e515. Ghost trail and Burn flame pip included; resistant enemies get a tinted thick frame + diamond pip.
  - **Goal:** every enemy shows a world-space health bar so the player can read fight state at a glance.
  - **Owner sequence:** gameplay-dev -> ux-designer -> qa -> playtester -> game-lead (close).
  - **Files likely touched:** new `scenes/ui/EnemyHealthBar.tscn` + `src/ui/EnemyHealthBar.gd`, `scenes/enemies/*.tscn`, `scenes/debug/TrainingDummy.tscn`, new data config (e.g. `data/enemy_health_bar.json`), `src/combat/Health.gd` (read-only unless a signal is missing), new tests in `tests/unit/`.
  - **GDD sections:** §3 (fixed isometric camera), §7 (elemental resistance), combat-feel/readability notes. Visibility default logged in `docs/DECISIONS.md` (2026-10-27).
  - **Acceptance criteria:**
    1. Every enemy (melee chaser, ranged shooter, fire-resistant golem) and the TrainingDummy shows a health bar floating above it in world space.
    2. The bar always faces the camera, has a consistent on-screen size under the fixed orthographic isometric camera, and stays readable when enemies are clustered.
    3. Fill is proportional to current/max HP and updates immediately on damage, healing, and Burn ticks. Ghost trail (lighter segment draining after the main bar drops) is nice-to-have, only if cheap.
    4. Visibility follows the config value (default: always visible while alive, hidden on death). Changing the rule (e.g. "show only after damage") must be a data change, not a code change.
    5. Enemy types are distinguishable where it helps (e.g. a subtle tint or marker for elemental resistance), never relying on color alone. Kept simple.
    6. Optional if trivial: a small Burn status indicator on the bar; otherwise logged as a follow-up item.
    7. Performance: no per-frame allocations, no SubViewport per enemy, no Control node per enemy. Lightweight billboard approach (billboard quad meshes with an unshaded material or one small shared shader).
    8. One reusable scene driven by `Health` signals (`health_changed`, `died`); no per-frame HP polling; no hardcoded enemy types inside the bar.
  - **Done requires:**
    - qa PASS: tests for ratio math, clamping at 0 and at max, updates on damage and heal, hidden on death, no errors when an enemy spawns or is freed mid-frame; full suite green; 20-second headless run; zero errors and warnings.
    - playtester report with no blockers: smoke check, a screenshot of a wave, readability notes.
  - **Follow-ups** (director answers 2026-10-27, logged in `docs/DECISIONS.md`):
    - [x] (a) gameplay-dev: screenshot tooling - **done** (f468959, 96ca1a1, 083a8cf; qa PASS on 083a8cf, 91/91 tests). `powershell -File tools\capture_screenshot.ps1 -Scenario hp_bars -After "2.0,2.9,3.6"` (see README).
    - [ ] (b) visual check - **partially covered** by an hp_bars capture: damaged fills, Burn triangles, and resistant frames read clearly; ghost segment is subtle at 720p; in a very tight cluster bars stack and are hard to match to bodies. **Remaining:** director's hands-on look at bars over/near the player while playing.
    - [ ] (c) ux-designer (later): resistance marker reads as "armoured", not "resists fire". Director: acceptable for now; tooltip/legend stays open for later.
    - ~~(d) size bump~~ - dropped; director says size is fine.
    - [ ] (e) ux-designer (small): damage-number readability - numbers are ~10 px at 720p and hard to read (pre-existing, not caused by the bars).
    - [ ] (f) ux-designer (optional, config-only in `data/ui.json`): make the ghost segment more visible at 720p.
  - **Deferred idea (not a task):** show HP as a number or % (e.g. "34/100") on or near the bar.

## Milestone 3 — Card system and run loop (next, outlined only)
Not started. Expected scope per GDD §13 milestone 3 and §9:
- Multi-room procedural run structure (room graph, not just one arena)
- Post-battle card reward screen (accept/reject, 3-reject cap per run)
- Deck-clean rewards / routing choices
- A boss encounter
- Loadout saving between runs (starting from run 2, per GDD §9)
- Resolve open question: single-card offer vs. choice of several (GDD §14 item 1)
- Resolve open question: shops/drops alongside post-battle rewards (GDD §14 item 1)
- Expand the headless bot simulator from a stub into a real multi-room balance tool

## Milestone 4 — Second class/element, subclasses, passive tree prototype, balance sim
Not started. Per GDD §13: Wizard + Water added, 2 subclasses each for Rogue/Wizard/Fire/Water, first passive tree prototype (30-40 nodes), headless balance simulation grown out.

## Milestone 5 — Art/audio pass, friends-and-family playtest
Not started.
