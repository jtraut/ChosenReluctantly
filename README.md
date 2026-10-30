# Chosen, Reluctantly

A 3D isometric action RPG where your skills are cards: real-time combat driven by typed card slots, each with its own shuffled mini-deck. Built around deep class/element build combinations and roguelite runs with persistent between-run progression. Currently a placeholder-visuals prototype: one Fire Rogue, a seeded 8-room run (combat, elite, rest, boss) with card rewards after fights, a deck-clean choice in the rest room, and a three-phase final boss, The Overly Enthusiastic Guardian (placeholder name). See `docs/GDD.md` for the design and `docs/ROADMAP.md` for status.

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
data/           JSON game content and tuning (cards, armor, enemies, waves, run structure, statuses, zones, deck rules, player, UI, VFX, scenarios, input bindings); data/debug_decks/ holds the debug preset decks
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

A normal launch starts a **run**: 8 rooms in a row (5 combat, 1 elite, 1 rest, boss last), built from a seed; see `data/run.json` and `docs/ARCHITECTURE.md` section 2. The room indicator at the top right shows "Room X of Y - Type" with a shape per type (circle combat, diamond elite, plus rest, star boss). After a won combat or elite room you pick a reward card (see below); a rest room offers heal or remove a card; any other room shows a "Room cleared" panel with Continue. The last room is the boss (`data/bosses.json`): its HP bar shows at the top centre with its name, phase notches and the attack it is winding up. Killing it ends with a short death beat, then the stats screen; Game Over shows "Reached room X of Y". Try again and New run start a new seed. `scenes/main/Main.tscn` is the endless arena, still used by tests, scenarios, the wave sim and VpCapture without `--run`.

### Launch options
Game args go after `--`, for example `godot --path . -- --run-seed=7 --run-room=8`. Options marked "run" are read only by a normal run launch (RunMain) and are ignored with `--scenario` or in the endless arena. "First run" means Try again and New run do not repeat it; "whole launch" means they do. Parsed in `src/run/RunController.gd` (`_apply_launch_args`), `src/run/DebugDecks.gd`, `src/ui/RunPromptScreen.gd` and `src/debug/CaptureArgs.gd`.

| Option | What it does | Example |
|---|---|---|
| `--run-seed=N` | Run: seed for the first run only. Later runs get random seeds. | `godot --path . -- --run-seed=7` |
| `--run-room=K` | Run: start at room K (1-based), first run only. | `godot --path . -- --run-seed=1 --run-room=8` (boss room) |
| `--run-clear-after=S` | Run: clear the first room after S seconds (debug, for captures). | `godot --path . -- --run-clear-after=1` |
| `--run-auto-choose=<id>[,<id>...]` | Run: the choice screen picks those option ids in turn, skipping the arm delay (debug). | `godot --path . -- --run-room=3 --full-deck --run-auto-choose=remove_menu` |
| `--full-deck` | Run: start with the full card list instead of the starter (all 24 cards of the character's pools, or the preset's `full` list with `--deck`). Whole launch. | `godot --path . -- --full-deck` |
| `--deck=<name>` | Run: start with debug preset deck `<name>` (its `starter` list). Whole launch (Try again keeps it). Presets are in `data/debug_decks/`. | `godot --path . -- --deck=fire-heavy-rogue` |
| `--deck=<name> --full-deck` | Run: the preset's `full` list. | `godot --path . -- --deck=mixed-rogue --full-deck` |
| `--list-decks` | Run launch: print the preset names and descriptions and quit. Exit 0; exit 2 if a preset file is broken (verified). | `godot --headless --path . -- --list-decks` |
| `--scenario=<id>` | Play a scripted scenario in the endless arena (ids in `data/scenarios.json`, table below). Unknown id: error, exit 1. | `godot --path . -- --scenario=hp_bars` |
| `--screenshot-after=T[,T...]` | Capture a PNG at each time (seconds), then quit. Needs a renderer. | `godot --path . -- --screenshot-after=3.0,6.0 --screenshot-out=screenshots/a.png` |
| `--screenshot-count=N` with `--screenshot-interval=S` | N shots at S, 2S, ... (interval default 1.0). Ignored if `--screenshot-after` is given. | `godot --path . -- --screenshot-count=3 --screenshot-interval=2.0` |
| `--screenshot-out=<path>` | Output PNG path (default `user://screenshot.png`); several shots insert `_<n>` before the extension. | `--screenshot-out=screenshots/c.png` |

Notes:
- `--deck` errors exit 2 with "Launch refused: ..." on stderr: unknown name, `--deck` given twice, a bare `--deck`, or a preset that is invalid (each verified except the invalid-preset case, which is covered by tests). There is no rule bypass: both lists of a preset must pass the deck rules.
- `--deck` is ignored with `--scenario` and in the arena, because only the run reads it. `--list-decks` needs the run too (a plain launch).
- Preset files (`data/debug_decks/<name>.json`): `name` (equals the file name), `description`, `full` (card ids, copies allowed) and `starter` (a sub-multiset of `full`). Adding a file needs no code. Shipped: `fire-heavy-rogue`, `physical-rogue` (has 2 Fire cards, the rules' minimum) and `mixed-rogue`; `--list-decks` prints the current set. A preset is only the starting deck: rewards and removals change it during the run.
- `tools/VpCapture.tscn` has its own args: `--size=WxH` (required) and `--run` (host the run instead of the arena). Everything else is the capture args above. `tools/capture_screenshot.ps1` builds these for you.
- To jump straight to the boss: `-- --run-seed=1 --run-room=8`, or capture it with `-Scenario "" -Extra "--run-seed=1","--run-room=8"`.
- `--scenario=...` always keeps the endless arena, even on a normal launch.

### Rewards and deck-clean (Milestone 3b)
- After each won **combat or elite** room (never the last): 3 card offers (`rewards.offer_size` in `data/run.json`). Pick one, or reject all (3 rejects per run, `rejects_per_run`). Offers are seeded, drawn only from the character's pools, and cards you do not own are weighted 4:1 over owned ones. A card may carry an optional `requires` filter.
- **Rest room:** Heal 30% of max HP, or remove a card. A card whose removal would break a deck minimum is greyed out with the reason; if none can go, the remove tile is disabled.
- **Starter deck:** 15 cards, 3 per slot (`starting_deck` in `data/run.json`). It was the full 24-card pool before 3b. The deck minimum is 3 unique per slot, so with the plain starter the removal menu is disabled until picks add cards.
- The choice screen shows card tiles, a reject tile with pips, and a "Next: Room N of 8 - Type" line. Keys 1-N highlight, Enter or a click confirms. Options ignore input for 0.4 s after opening (`prompt_option_arm_delay` in `data/ui.json`), and Space is swallowed (the Continue and New run buttons have the same delay, and Space no longer confirms them). The offer panel shrinks to fit the window and never scrolls (tested from 1024x600 up); only the removal grid scrolls. Card tiles show "Slot N now: A / B / C". A reload mid-reward resumes the same offer.

Controls (from `data/input_bindings.json`): WASD move, mouse aim, Space dodge, left click light attack, right click heavy attack, 1-5 use a card slot, Ctrl+1-5 swap a dead card, Esc pause/settings, F3 debug overlay. Holding a slot key shows the card's hit area and releasing casts it (change with the `cast_trigger` setting in the pause screen).

`godot` must be on PATH, or set `GODOT_BIN` to the full path of the Godot executable, or call it directly: `"C:\path\to\Godot.exe" --path .`. All `tools\*.ps1` scripts resolve the binary from `GODOT_BIN` first, then `godot_console`/`godot` on PATH, and prefer a `*_console.exe` sibling.

## Running tests
Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), vendored in `addons/gdUnit4`. Run the full suite headless:

```
powershell -File tools\run_tests.ps1
```

This runs every suite under `/tests` and exits non-zero on any failure. Last run (T-decks docs pass, 2026-10-29, about 5 min 19 s): 996 of 996 test cases passed, exit 0 (qa's T-decks numbers: 987 plus its 9 delta tests). Reports go to `reports/` (gitignored). The script uses the console-subsystem `*_console.exe` build when one sits next to the resolved binary, because PowerShell cannot reliably wait on or read the windowed build, which made failures look like passes (see `docs/DECISIONS.md`).

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

`capture_screenshot.ps1` parameters: `-After` (seconds, comma list, default "3.0"), `-Out` (default `screenshots\shot.png`), `-Scenario` (default `hp_bars`; `-Scenario ""` captures the normal run), `-Resolution` (default `1280x720`), `-Extra` (more game args, comma-split, for example `-Extra "--run-seed=7,--run-room=8"`). Without `--screenshot-out` the game writes to `user://screenshot.png`. Run-screen examples (both verified, each saved a PNG, exit 0; `-Extra` also accepts several quoted args):

```
powershell -File tools\capture_screenshot.ps1 -Scenario "" -After "3.0" -Out screenshots/reward.png -Extra "--run-seed=3","--run-room=1","--run-clear-after=1"   # reward screen
powershell -File tools\capture_screenshot.ps1 -Scenario "" -After "4.0" -Out screenshots/remove.png -Extra "--run-seed=3","--run-room=3","--full-deck","--run-auto-choose=remove_menu"   # removal grid (needs --full-deck: with the plain starter the menu is disabled)
```

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
| `boss` | the boss with 9999 HP for both sides, scripted through smash, slam, volley and charge (boss bar and telegraphs) `"2.0,5.0,9.0"` |
| `boss_edge` | the boss at 50% HP (bar and phase line) `"2.0"` |
| `boss_phase3` | the boss started in phase 3 (`boss_phase` 2) | `"1.2,3.0,5.5"` |
| `boss_f3` | the boss with the F3 overlay on at 0.5 s, to read its Defense block (armor and resistance) | `"0.8"` |
| `elite_f3` | elites and plain enemies with the F3 Defense block and the elite shield pips | `"0.8"` |
| `armor_numbers` | scripted hits on elites and plain enemies: armor `[n]` and resisted `<n>` damage numbers | `"1.5,3.5"` |

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
Plays the real Main scene (spawner, enemies, player) with a bot that uses the real input actions, then reports crashes, NaN, cap violations, enemies or player leaving the arena, stalls, damage taken, alive counts, spacing, and rough CPU frame cost. It runs as a scene (so autoloads exist), headless. `-Seconds` is game time, `-Scale` is `Engine.time_scale` (1 = real time and most faithful, default 3), `-God` keeps the player alive to exercise the whole wave table, `-Idle` is a player who never moves, `-Deck` (`standard` default, or the name of a preset in `data/debug_decks/`; passed to the game as `--sim-deck=`) starts every run with that legal preset deck, so armor comparisons are like for like. A preset is only the starting deck: rewards and removals change it as the run goes on. `-LightHeavyOnly` is a bot policy, not a deck: the bot never presses card slots 1 and 2, so only light and heavy attacks hit. `-Runs` repeats with consecutive seeds (verified: `-Seed 20 -Runs 2` ran seeds 20 and 21), `-Seed` sets the first seed. `-Run` plays whole seeded runs through `RunMain` instead (see below). The script launches Godot with `--fixed-fps 60` (one 60 Hz physics tick per frame) and turns hit-stop off in the sim; `-Scale` defaults to 1, and a `-Scale` above 1 drops `--fixed-fps` and the run no longer repeats.

```
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 150 -Runs 3
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 120 -God
powershell -File tools\run_wave_sim.ps1 -Seed 20 -Seconds 60 -Runs 3 -Idle -Scale 1
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 20 -God -Deck fire-heavy-rogue    # verified: WAVE SIM OK, exit 0
powershell -File toolsun_wave_sim.ps1 -Seed 1 -Seconds 20 -God -Deck physical-rogue -LightHeavyOnly    # verified: WAVE SIM OK, exit 0
```
```
powershell -File tools\run_wave_sim.ps1 -Run -Seed 1 -Runs 2    # whole runs; verified in the 3b pass: both runs WON, prints WAVE SIM OK
```
`-Run`: `-Seed` is the first run seed, `-Runs` the number of runs, `-RoomTimeout` (sim seconds, default 240, minimum 10) is how long a room may last before it counts as a soft lock. The bot also plays the choices with a seeded policy (rejects 25% of the time while any are left, else a random unowned card; it removes a card in rest rooms when allowed). It reports per room time and lowest HP, and for the boss room a `boss fight (spawn to death)` line (seconds, whether the boss died, the player's lowest HP; the bot steps out of wind-up areas and dodges), and fails on a soft lock, an empty deck or a stuck cooldown. Per run it prints `HP at each room end`, the final deck size and per-slot composition, and picks, rejects used, removals and rest heals; the summary adds `mean HP at room end, as a share of max` per room and `final deck sizes`. Card pick-rate outliers and never-cast cards are printed as a NOTE, not a failure (pick rates count all database cards, so cards outside the 15-card start show as never cast unless picked). A small `-RoomTimeout` (60 was tried) flags the boss room as a soft lock; that is the check working, not a bug.

All forms run and end with `WAVE SIM OK` (verified with shorter `-Seconds`; the 150 s and 120 s forms use the same code path). The wave table and the simultaneous-enemy cap live in `data/waves.json` (validated by `src/enemies/WaveConfig.gd`; enemy ids and scenes in `data/enemies.json`). Headless frame times exclude rendering.

**Seeds repeat exactly** on the same machine and build. The same `-Seed` (at `-Scale` 1) gives the same `result:` line: HP lost, kills, casts and a `state_hash` of final positions (verified: two runs of `-Seed 1 -Seconds 30` were identical, `state_hash` 2792856473; the default 90 s run of seed 1 gives 4120250839). A windowed run, a `-Scale` above 1, or another machine or Godot version can differ. Besides the `result:` line the sim prints a `pinned:` line (frames where the bot was commanded to move but the player barely moved, and the longest stretch) and a `climb:` line (the player's maximum feet height), which watch for solid enemies pinning or lifting the player.

## Death / restart soak (real scene reload)
Kills the player in the real Main scene, waits for `game_over_ready`, calls `restart_arena()` (twice, on purpose), repeats, and also restarts mid slow-mo. It also places a Fire Wall zone and a Shadow Step pass-through grant, and reloads with the buff live, then checks the zone manager, the static pass-through flag and the enemy mask. It checks HP, `Engine.time_scale`, enemy count, wave timer, Game Over screen state and orphan/object/node counts, and fails on any engine ERROR/WARNING line.

```
powershell -File tools\run_reload_cycle.ps1 -Cycles 5     # verified: prints "RELOAD CYCLE OK", exit 0
```
It runs `tools/ReloadCycle.tscn` headless; it must be a scene so autoloads resolve. Re-run it whenever `Main`, `Juice`, `Player` or the autoloads change.

## Last verification
T-decks docs pass, 2026-10-29, Windows, Godot 4.7.2 (console build via `GODOT_BIN`), HEAD 43b7e35:
- `toolsun_tests.ps1`: 996 of 996, exit 0.
- `godot --headless --path . -- --list-decks`: prints the three presets, exit 0. `--deck=nope`, a bare `--deck` and `--deck` twice: each exit 2 with "Launch refused: ...".
- `run_wave_sim.ps1 -Seed 1 -Seconds 20 -God -Deck fire-heavy-rogue` and `... -Deck physical-rogue -LightHeavyOnly`: WAVE SIM OK, exit 0.
- Not re-run in this pass: captures, the bot sim, the reload cycle (it has a known flake, see `docs/CHANGELOG.md`), `-Run` sims, `-TrueSize`, `SlotStateCapture`, and the seeded-hash checks (last verified in the 3a pass; qa reported the arena hash unchanged by A1). Not run interactively: plain `godot --path .` and a scenario without capture (they open a window and wait for a person).
