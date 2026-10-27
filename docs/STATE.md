# Handoff State

Last updated: 2026-10-27. **Milestone 2 is done** (plus a post-milestone camera fix - see below).

## What's done
Everything in `docs/ROADMAP.md`'s Milestone 2 list is checked off and verified: isometric camera + Player (movement/aim), basic attack + dodge roll, the full combat/status/effect-template/card architecture (`StatModifiers`, `Health`/`Hurtbox`/`CombatMath`/`MeleeQuery`, `StatusEffectManager`/`StatusDatabase`+Burn, all 7 `EffectTemplates`, `CardSchema`/`CardDatabase`/`SlotTypeDatabase`/`PoolDatabase`, `CardSlot`/`CardSlotController`), 3 enemy types + wave spawner, the 15-card Fire Rogue starter set, HUD + F3 debug overlay, the juice pass (hit-stop/shake/damage numbers/hit-flash/telegraphs), and a headless bot-sim stub. See `git log` for the full commit-by-commit sequence - each is one vertical slice with its own tests.

Final verification before marking the milestone done: fresh `--headless --editor --quit` (zero errors/warnings), a 20-second `--headless --path . --quit-after 1200` run (zero errors - long enough for enemy waves to spawn, chase, attack, and get hit by the player), full test suite (**62/62 passing**), and the bot-sim (20 rooms clean, no NaN).

Two real bugs were found and fixed along the way (both logged in `docs/DECISIONS.md` with detail): `tools/run_tests.ps1` was silently reporting exit 0 for a failing test (PowerShell doesn't reliably wait on a GUI-subsystem process); and the bot-sim's nodes weren't `is_inside_tree()` until the main loop ticked once, since it drives everything from `_initialize()`.

**What I cannot verify myself:** actually playing it. The DoD's "I can play a wave arena with the Fire Rogue using all 5 slots plus basic attack and dodge" needs the director at the keyboard - everything automatable says the systems are wired correctly and crash-free, but feel/fun is not something I can self-certify.

## Post-milestone fix (2026-10-27): empty 3D world
The director's first playtest showed only the HUD over a flat background. Cause: the Camera3D transform in `scenes/camera/CameraRig.tscn` was written with its basis transposed (wrong since commit `4cb6e37`), so the camera looked up into the sky - forward was (0.71, +0.41, -0.58). No errors were logged because every node existed and was wired correctly. Side effects: WASD directions and mouse-ground aim (both derived from the camera basis) were also wrong, and the unseen player was killed by wave 1 (spawns at t=0) within ~7s, so the HUD read "0 / 30".

Fixed the transform (now forward ~ (-0.58, -0.58, -0.58)). Added `SceneSelfCheck` (`src/main/SceneSelfCheck.gd`), run at the end of `Main._ready()`: it pushes one error if there's no current camera/player/visible mesh/floor/light/spawner, player HP <= 0, the camera isn't looking down, or the player/floor are outside the camera frustum. `tests/unit/main_scene_smoke_test.gd` loads `Main.tscn` and asserts the same; verified it fails on the old transform and passes on the fixed one. `Juice.screen_shake` now uses `is_instance_valid` so a freed camera rig can't error. Suite 63/63, 20s headless run clean, bot-sim clean, and a windowed screenshot shows the arena.

Lesson: "nodes exist" checks don't catch an empty world - the frustum checks are what matter.

## In progress
Nothing. Milestone 2 is closed out. Milestone 3 (card system and run loop) hasn't been started - see `docs/ROADMAP.md` for its outline.

## Exact next step
Director: re-playtest now that the world is visible - controls will feel different since movement/aim were camera-relative to a wrong camera. Then:
Wait for the director's playtest and design feedback before starting Milestone 3. If asked to proceed anyway: Milestone 3's first real decision is the two open questions it inherits from GDD §14 item 1 (single-card reward offer vs. choice of several; whether shops/drops exist alongside post-battle rewards) - resolve those via the GDD's own `[PROPOSED]` defaults if no new director input arrives, log in `docs/DECISIONS.md`, then start with the room-graph/run-structure data model before the reward screen, since the reward screen needs somewhere to fire between rooms.

## Open questions for the director
None blocking. Everything to actually look at and react to:
- Does the core loop (move/aim/basic-attack/dodge + 5 card slots) feel good? This is literally the only question Milestone 2 was scoped to answer.
- Are the enemy/card damage and cooldown numbers in the right neighborhood, or wildly off? They're placeholder tuning values, logged as such in `docs/DECISIONS.md`.
- Is the Ctrl+number dead-card-swap binding comfortable, or does it want a different default?
- Tone check on the card flavor text (dry/sarcastic, per GDD §11) - too much, too little, right amount?
