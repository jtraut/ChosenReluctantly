# Chosen, Reluctantly

A 3D isometric action RPG where your skills are cards: real-time combat driven by typed card slots, each with its own shuffled mini-deck. Built around deep class/element build combinations and roguelite runs with persistent between-run progression. Currently a placeholder-visuals prototype: one Fire Rogue, a seeded 8-room run (combat, elite, rest, boss), no rewards yet. See `docs/GDD.md` for the design and `docs/ROADMAP.md` for status.

## Docs
| File | What it is |
|---|---|
| `docs/ARCHITECTURE.md` | How the code fits together. Start here if you are new to the code. |
| `docs/CHANGELOG.md` | Project history in plain language, newest first. |
| `docs/ASSETS.md` | Third-party assets and libraries, with licenses. |
| `docs/GDD.md` | Game design (source of truth). |
| `docs/DECISIONS.md` | Agents' own judgment calls and defaults. |
| `docs/ROADMAP.md`, `docs/STATE.md`, `docs/OPEN_ITEMS.md` | Plan, handoff state, and what is waiting on the director. |
| `docs/reviews/`, `docs/playtests/` | qa reviews and playtest reports. |
| `CLAUDE.md` | Working agreements for the main session and every role agent (`.claude/agents/`). |

## Repo layout
```
project.godot   Godot project (main scene: scenes/main/RunMain.tscn, the run; scenes/main/Main.tscn is the endless arena)
src/            GDScript, grouped by system (camera, cards, combat, core, debug, effects, enemies, main, player, run, ui)
scenes/         .tscn scenes
data/           JSON game content and tuning (cards, enemies, waves, run structure, statuses, zones, deck rules, player, UI, VFX, scenarios, input bindings)
assets/         icon and one shader (no art or audio yet)
addons/gdUnit4  vendored test framework
tests/          gdUnit4 suites (tests/unit), fixtures, helpers in tests/support (test_input.gd, body_flag.gd, test_caster.gd, test_clock.gd)
tools/          PowerShell wrappers and headless/capture tools
docs/           documentation
```

## Running the project
Requires Godot 4.7.x (developed on 4.7.2 stable). Open `project.godot` in the editor and press Play, or use the command line:

```
godot --path . --quit   # smoke-check with no window (verified: exits 0)
godot --path .          # play it: starts a run
```

A normal launch starts a **run**: 8 rooms in a row (5 combat, 1 elite, 1 rest, boss last), built from a seed; see `data/run.json` and `docs/ARCHITECTURE.md` section 2. The room indicator at the top shows "Room X of Y - Type" with a shape per type (circle combat, diamond elite, plus rest, star boss). After a room, a "Room cleared" panel offers Continue; winning shows a stats screen; Game Over shows "Reached room X of Y". Try again and New run start a new seed. `scenes/main/Main.tscn` is the endless arena, still used by tests, scenarios, the wave sim and VpCapture without `--run`.

Launch args for the run (after `--`, for example `godot --path . -- --run-seed=7 --run-room=8`; verified with `capture_screenshot.ps1 -Extra`):
- `--run-seed=N`: seed for the first run only. Later runs (Try again, New run) get random seeds.
- `--run-room=K`: start at room K (1-based), for the first run only.
- `--run-clear-after=S`: clear the first room after S seconds (debug).
- `--scenario=...` always keeps the endless arena, even on a normal launch.

Controls (from `data/input_bindings.json`): WASD move, mouse aim, Space dodge, left click light attack, right click heavy attack, 1-5 use a card slot, Ctrl+1-5 swap a dead card, Esc pause/settings, F3 debug overlay. Holding a slot key shows the card's hit area and releasing casts it (change with the `cast_trigger` setting in the pause screen).

`godot` must be on PATH, or set `GODOT_BIN` to the full path of the Godot executable, or call it directly: `"C:\path\to\Godot.exe" --path .`. All `tools\*.ps1` scripts resolve the binary from `GODOT_BIN` first, then `godot_console`/`godot` on PATH, and prefer a `*_console.exe` sibling.

## Running tests
Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), vendored in `addons/gdUnit4`. Run the full suite headless:

```
powershell -File tools\run_tests.ps1
```

This runs every suite under `/tests` and exits non-zero on any failure. Last recorded run (qa, 2026-10-29, `docs/reviews/2026-10-29-m3a-qa.md`): 766 of 766 test cases passed. Not re-run in the 3a docs pass. Reports go to `reports/` (gitignored). The script uses the console-subsystem `*_console.exe` build when one sits next to the resolved binary, because PowerShell cannot reliably wait on or read the windowed build, which made failures look like passes (see `docs/DECISIONS.md`).

> After adding a new global class (`class_name`) the plain headless run may fail with "Could not find type X in current scope". Run `godot --headless --editor --quit --path .` once to rebuild the class cache (verified: exits 0), then re-run the tests.

Tests and tools that press a card or attack key must send an `InputEventAction` (see `tests/support/test_input.gd`), because `Input.action_press` emits no event and the player reads input events.

Other helpers in `tests/support/`: `body_flag.gd` forces `body.collide_with_enemies` on or off for a test (tests that pin non-solid geometry turn it off), `test_caster.gd` is a test double for a damage dealer (so a test controls every hit), `test_clock.gd` (`TestClock.wait_real`) waits real seconds without the ignore-time-scale timer bug. The test log prints `ERROR:` lines from bad-data fixtures on purpose, so do not use "grep ERROR" as a pass/fail gate; the suite's exit code is the gate.

## Game data worth knowing
All content and tuning is JSON under `data/` (see `docs/ARCHITECTURE.md` section 6 for the full table).
- **Deck rules** (`data/deck_rules.json`, read by `src/cards/DeckRules.gd`): `min_unique_per_slot` (3 today), optional per-slot overrides under `slots` (for example `{"utility": {"min_unique": 5}}`) and `slot_groups` (a named set of slots with `min_unique_total`). Only different cards count; copies never do. At run start a deck that misses the minimums is blocked: an error is logged, the spawner stays off and `Main.run_start_blocked` is emitted. The F3 debug overlay shows each slot's unique count against its minimum and marks shortfalls `SHORT`. The shipped deck passes with the default rules.
- **Player** (`data/player.json`): dodge speed, duration, cooldown, and `body.collide_with_enemies` (true: player and enemies are solid to each other; false restores the old walk-through behaviour).
- **Zones** (`data/zones.json`): the `max_live` cap on ground zones (for example the Fire Wall) and their look.

## Screenshots and scripted scenarios
Capture is built into the game and runs only when user args follow `--` (nothing runs in normal play). It needs a renderer, so it must run windowed; `--headless` cannot capture. The game quits itself after the last shot. Output goes under `screenshots\` by default, which is gitignored.

```
powershell -File tools\capture_screenshot.ps1                                  # hp_bars scenario, 1 shot at 3.0 s -> screenshots\shot.png
powershell -File tools\capture_screenshot.ps1 -Scenario attacks -After "0.75,2.4,2.7" -Out screenshots\atk.png   # several shots -> atk_0.png, atk_1.png, ...
godot --path . -- --screenshot-after=3.0 --screenshot-out=screenshots/a.png --scenario=hp_bars
godot --path . -- --screenshot-count=3 --screenshot-interval=2.0 --screenshot-out=screenshots/c.png   # shots at 2 s, 4 s, 6 s
godot --path . -- --scenario=hp_bars                                          # play a scenario by hand, no capture
```

`capture_screenshot.ps1` parameters: `-After` (seconds, comma list, default "3.0"), `-Out` (default `screenshots\shot.png`), `-Scenario` (default `hp_bars`; `-Scenario ""` captures the normal run), `-Resolution` (default `1280x720`), `-Extra` (more game args, comma-split, for example `-Extra "--run-seed=7,--run-room=8"`). Without `--screenshot-out` the game writes to `user://screenshot.png`.

Scenarios are defined in `data/scenarios.json` and checked by `src/debug/ScenarioSchema.gd`. Capture times below are known-good starting points; every one of them was run and produced the listed number of shots.

| Scenario | Shows | Example `-After` |
|---|---|---|
| `hp_bars` | 9 enemies at mixed HP, 2 with Burn, 3 hit at 2.4 s so the ghost trail drains | `"2.0,2.9,3.6"` |
| `game_over` | player scripted to die at 1.0 s with 2 chasers nearby: death beat, then Game Over screen | `"3.0"` |
| `attacks` | auto light attack, scripted heavy click at 2.2 s | `"0.75,2.4,2.7"` |
| `targeted_aoe` | Wizard heavy (data only) at a locked ground target: wind-up telegraph, then burst | `"1.3,1.7,2.0"` |
| `card_cast` | one of each card type, with a slot-cooling check printed for each | `"0.9,1.9,3.2,4.4,5.5,6.1,6.8,7.8"` |
| `stun_crowd` | 6 of 9 idle enemies stunned (one boss shows IMMUNE) | `"0.45,0.85,1.6"` |
| `stun_cancel` | stun lands mid wind-up | `"0.1,0.23,0.32"` |
| `waves` | the real spawner at a fast, ungated pace, 9999 HP player | `"2.5,5,8"` |
| `bar_modes` | 12 idle enemies, two bosses; edit `hp_bars.visibility_mode` in `data/ui.json` between runs to compare modes | `"1.5"` |
| `pointy_shot` | a neutral bolt in flight | `"0.62,0.78,0.9"` |
| `cast_preview` | each card type's slot key held (real input events) then released | `"1.2,2.7,4.2,5.7,7.0,8.4"` |
| `settings_open` | presses Esc at 1.0 s: the pause / settings screen over the arena | `"1.8"` |
| `c1_status` | casts Leech, Bleed Slash, Flurry, Regeneration, Shadow Step: status cues and the ghosted player | `"0.8,1.5,2.2,2.9,3.8"` |
| `c1_status_crowd` | 9 enemies with Burn, Bleed and stun at mixed HP | `"3.0"` |
| `c1_placed` | holds Fireball, then Fire Wall: range reticle, delay telegraph, burn-down timer | `"1.1,4.8,6.6,8.2"` |
| `c1_placed_near` | the same two previews with enemies near the aim point | `"1.1,3.9"` |
| `c1_moves` | holds Lunge, then Backward Leap: dash previews with arrowheads | `"1.0,1.6,3.6,4.1"` |
| `c1_names` | holds many cards at once to check card name rows fit | `"0.8,2.0,3.2"` |
| `c1_overlay` | toggles the F3 debug overlay (deck counts) | `"1.5"` |

### True-size capture (`-TrueSize`)
The OS window is clamped to the monitor, so `-Resolution` cannot exceed it. `-TrueSize WxH` instead runs the real Main scene (with `-Scenario ""`, RunMain, via `--run`) inside a SubViewport of exactly that size (`tools/VpCapture.tscn`; Main registers with `src/core/WorldRef.gd` because `current_scene` is null there). Same scenarios and `-After` times as above. It needs a renderer (windowed), like all capture.

```
powershell -File tools\capture_screenshot.ps1 -Scenario c1_overlay -After "1.5" -TrueSize 2560x1440 -Out screenshots/t.png   # verified: saved one PNG, exit 0
godot --path . res://tools/VpCapture.tscn -- --size=1920x1080 --scenario=hp_bars --screenshot-after=2 --screenshot-out=screenshots/vp.png   # verified
```
Use forward slashes in `-Out`: backslashes and `$` get mangled when the command is typed in bash.

One more helper (needs a renderer; run and confirmed to save a file):
```
godot --path . res://tools/SlotStateCapture.tscn -- 1280 720 screenshots/slots.png   # HUD with ready and cooling slots
```
The old `godot --path . --script tools/vp_capture.gd -- 2560 1440 ...` form no longer works (it hung when tried); `tools/vp_capture.gd` is now the script of `VpCapture.tscn`.

## Headless bot-sim
A small crash/NaN check on the card and deck system (not a balance tool). It drives N "rooms" with random card use and swaps against an empty room and reports NaN in cooldowns or health.

```
powershell -File tools\run_bot_sim.ps1 -Rooms 20 -Seed 3      # verified: prints "Bot-sim OK" and a checksum, exit 0
```
Parameters: `-Rooms` (default 20) and `-Seed` (default 1). The same seed and rooms print the same checksum (verified: two runs of seed 3 both gave 2281795515).

## Wave density sim
Plays the real Main scene (spawner, enemies, player) with a bot that uses the real input actions, then reports crashes, NaN, cap violations, enemies or player leaving the arena, stalls, damage taken, alive counts, spacing, and rough CPU frame cost. It runs as a scene (so autoloads exist), headless. `-Seconds` is game time, `-Scale` is `Engine.time_scale` (1 = real time and most faithful, default 3), `-God` keeps the player alive to exercise the whole wave table, `-Idle` is a player who never moves, `-Runs` repeats with consecutive seeds (verified: `-Seed 20 -Runs 2` ran seeds 20 and 21), `-Seed` sets the first seed. `-Run` plays whole seeded runs through `RunMain` instead (see below). The script launches Godot with `--fixed-fps 60` (one 60 Hz physics tick per frame) and turns hit-stop off in the sim; `-Scale` defaults to 1, and a `-Scale` above 1 drops `--fixed-fps` and the run no longer repeats.

```
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 150 -Runs 3
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 120 -God
powershell -File tools\run_wave_sim.ps1 -Seed 20 -Seconds 60 -Runs 3 -Idle -Scale 1
```
```
powershell -File tools
un_wave_sim.ps1 -Run -Seed 1 -Runs 2    # whole runs; verified: both runs WON, prints WAVE SIM OK
```
`-Run`: `-Seed` is the first run seed, `-Runs` the number of runs, `-RoomTimeout` (sim seconds, default 240, minimum 10) is how long a room may last before it counts as a soft lock. It reports per room time and lowest HP, and fails on a soft lock, an empty deck, a stuck cooldown or a card pick-rate outlier. A small `-RoomTimeout` (60 was tried) flags the boss room as a soft lock; that is the check working, not a bug.

All forms run and end with `WAVE SIM OK` (verified with shorter `-Seconds`; the 150 s and 120 s forms use the same code path). The wave table and the simultaneous-enemy cap live in `data/waves.json` (validated by `src/enemies/WaveConfig.gd`; enemy ids and scenes in `data/enemies.json`). Headless frame times exclude rendering.

**Seeds repeat exactly** on the same machine and build. The same `-Seed` (at `-Scale` 1) gives the same `result:` line: HP lost, kills, casts and a `state_hash` of final positions (verified: two runs of `-Seed 1 -Seconds 30` were identical, `state_hash` 2792856473; the default 90 s run of seed 1 gives 4120250839). A windowed run, a `-Scale` above 1, or another machine or Godot version can differ. Besides the `result:` line the sim prints a `pinned:` line (frames where the bot was commanded to move but the player barely moved, and the longest stretch) and a `climb:` line (the player's maximum feet height), which watch for solid enemies pinning or lifting the player.

## Death / restart soak (real scene reload)
Kills the player in the real Main scene, waits for `game_over_ready`, calls `restart_arena()` (twice, on purpose), repeats, and also restarts mid slow-mo. It also places a Fire Wall zone and a Shadow Step pass-through grant, and reloads with the buff live, then checks the zone manager, the static pass-through flag and the enemy mask. It checks HP, `Engine.time_scale`, enemy count, wave timer, Game Over screen state and orphan/object/node counts, and fails on any engine ERROR/WARNING line.

```
powershell -File tools\run_reload_cycle.ps1 -Cycles 5     # verified: prints "RELOAD CYCLE OK", exit 0
```
It runs `tools/ReloadCycle.tscn` headless; it must be a scene so autoloads resolve. Re-run it whenever `Main`, `Juice`, `Player` or the autoloads change.

## Last verification
3a docs pass, 2026-10-29, Windows, Godot 4.7.2 (console build via `GODOT_BIN`): `godot --path . --quit` (exit 0); `run_wave_sim.ps1 -Seed 1 -Seconds 30` (twice, hash 2792856473) and the default 90 s run (hash 4120250839); `run_wave_sim.ps1 -Run -Seed 1 -Runs 2` (both won); `-Run -RoomTimeout 60` (reports the boss-room soft lock, as expected); `capture_screenshot.ps1 -Scenario "" -Extra "--run-seed=7,--run-room=8"` and `-Scenario "" -TrueSize 1920x1080` (each saved a PNG, exit 0). Not re-run in this pass: the full test suite (766/766 per the qa report), the bot sim, the reload cycle, the scenario captures and `SlotStateCapture`. Earlier passes (2026-10-29, C1) verified those. Not run interactively: plain `godot --path .` and a scenario without capture (they open a window and wait for a person).
