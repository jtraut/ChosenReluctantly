# Handoff State

Last updated: 2026-10-27. **Milestone 2 is done**, plus a post-milestone camera fix and HP bars above enemies (see below).

## What's done
Everything in `docs/ROADMAP.md`'s Milestone 2 list is checked off and verified: isometric camera + Player (movement/aim), basic attack + dodge roll, the full combat/status/effect-template/card architecture (`StatModifiers`, `Health`/`Hurtbox`/`CombatMath`/`MeleeQuery`, `StatusEffectManager`/`StatusDatabase`+Burn, all 7 `EffectTemplates`, `CardSchema`/`CardDatabase`/`SlotTypeDatabase`/`PoolDatabase`, `CardSlot`/`CardSlotController`), 3 enemy types + wave spawner, the 15-card Fire Rogue starter set, HUD + F3 debug overlay, the juice pass (hit-stop/shake/damage numbers/hit-flash/telegraphs), and a headless bot-sim stub. See `git log` for the full commit-by-commit sequence - each is one vertical slice with its own tests.

Final verification before marking the milestone done: fresh `--headless --editor --quit` (zero errors/warnings), a 20-second `--headless --path . --quit-after 1200` run (zero errors - long enough for enemy waves to spawn, chase, attack, and get hit by the player), full test suite (**62/62 passing**), and the bot-sim (20 rooms clean, no NaN).

Two real bugs were found and fixed along the way (both logged in `docs/DECISIONS.md` with detail): `tools/run_tests.ps1` was silently reporting exit 0 for a failing test (PowerShell doesn't reliably wait on a GUI-subsystem process); and the bot-sim's nodes weren't `is_inside_tree()` until the main loop ticked once, since it drives everything from `_initialize()`.

**What I cannot verify myself:** actually playing it. The DoD's "I can play a wave arena with the Fire Rogue using all 5 slots plus basic attack and dodge" needs the director at the keyboard - everything automatable says the systems are wired correctly and crash-free, but feel/fun is not something I can self-certify.

## Post-milestone fix (2026-10-27): empty 3D world
The director's first playtest showed only the HUD over a flat background. Cause: the Camera3D transform in `scenes/camera/CameraRig.tscn` was written with its basis transposed (wrong since commit `4cb6e37`), so the camera looked up into the sky - forward was (0.71, +0.41, -0.58). No errors were logged because every node existed and was wired correctly. Side effects: WASD directions and mouse-ground aim (both derived from the camera basis) were also wrong, and the unseen player was killed by wave 1 (spawns at t=0) within ~7s, so the HUD read "0 / 30".

Fixed the transform (now forward ~ (-0.58, -0.58, -0.58)). Added `SceneSelfCheck` (`src/main/SceneSelfCheck.gd`), run at the end of `Main._ready()`: it pushes one error if there's no current camera/player/visible mesh/floor/light/spawner, player HP <= 0, the camera isn't looking down, or the player/floor are outside the camera frustum. `tests/unit/main_scene_smoke_test.gd` loads `Main.tscn` and asserts the same; verified it fails on the old transform and passes on the fixed one. `Juice.screen_shake` now uses `is_instance_valid` so a freed camera rig can't error. Suite 63/63, 20s headless run clean, bot-sim clean, and a windowed screenshot shows the arena.

Lesson: "nodes exist" checks don't catch an empty world - the frustum checks are what matter.

## Post-milestone polish (2026-10-27): HP bars above enemies - done
Every enemy and the TrainingDummy now shows a world-space billboard HP bar (`scenes/ui/EnemyHpBar.tscn`, `src/ui/EnemyHpBar.gd`, shared shader `assets/shaders/enemy_hp_bar.gdshader`, config `data/ui.json` `hp_bars`). Signal-driven off `Health` and the new `StatusEffectManager.status_applied/status_expired`; one shared quad + material with instance uniforms, no SubViewport/Control per enemy. Visibility is data (`always_alive` default, or `after_damage`). Ghost trail and Burn flame pip included; resistant enemies get a tinted thick frame + diamond pip (not color-only). qa PASS (83/83 tests, editor check, 20s headless run, bot-sim 20 rooms clean). Playtester: no blockers; bars readable in a 9-enemy cluster at 1280x720 (~70x9 px). Not yet seen live: damaged/ghost state, Burn pip, overlap with damage numbers/telegraphs/player, `after_damage` mode. Follow-ups are listed under the item in `docs/ROADMAP.md`.

Director answered the follow-up questions (logged in `docs/DECISIONS.md`): keep always-visible, size fine, the "armoured" reading of the resistance marker is OK for now, HP-as-number is a deferred idea. **Screenshot tooling is built** (f468959, 96ca1a1, 083a8cf; qa PASS, 91/91 tests). **Agents: use `powershell -File tools\capture_screenshot.ps1 -Scenario hp_bars -After "2.0,2.9,3.6"` (see README) to check visuals** instead of ad-hoc captures. A capture review showed damaged fills, Burn pips, and resistant frames read well. The ghost segment is subtle at 720p, bars stack in tight clusters, and damage numbers (~10 px) are hard to read; small ux follow-ups were added.

## In progress
Nothing.

## Exact next step
**Next: the director playtests** before Milestone 3 (unchanged). During that playtest, also glance at HP bars over/near the player (the remaining part of follow-up (b)). Optional agent work if the director wants it meanwhile: **ux-designer** on damage-number readability (follow-up (e)), then the config-only ghost-visibility tweak (f), each verified with the capture tool and qa.

Director: re-playtest now that the world is visible - controls will feel different since movement/aim were camera-relative to a wrong camera. Then:
Wait for the director's playtest and design feedback before starting Milestone 3. If asked to proceed anyway: Milestone 3's first real decision is the two open questions it inherits from GDD §14 item 1 (single-card reward offer vs. choice of several; whether shops/drops exist alongside post-battle rewards) - resolve those via the GDD's own `[PROPOSED]` defaults if no new director input arrives, log in `docs/DECISIONS.md`, then start with the room-graph/run-structure data model before the reward screen, since the reward screen needs somewhere to fire between rooms.

## Open questions for the director
None blocking. Everything to actually look at and react to:
- Does the core loop (move/aim/basic-attack/dodge + 5 card slots) feel good? This is literally the only question Milestone 2 was scoped to answer.
- Are the enemy/card damage and cooldown numbers in the right neighborhood, or wildly off? They're placeholder tuning values, logged as such in `docs/DECISIONS.md`.
- Is the Ctrl+number dead-card-swap binding comfortable, or does it want a different default?
- Tone check on the card flavor text (dry/sarcastic, per GDD §11) - too much, too little, right amount?
- HP bars: while playing, do bars clash with the player or with telegraphs? This is the only part of the visual check a capture couldn't cover.
- Want the small ux follow-ups (damage-number readability, more visible ghost) done before Milestone 3, or folded into later polish?

Latest playtest report: `docs/playtests/2026-10-27-idle-smoke-check.md` (idle smoke check only; input untested, scripted-input tool proposed).
