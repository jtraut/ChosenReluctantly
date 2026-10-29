# Chosen, Reluctantly

A 3D isometric action RPG where your skills are cards: real-time combat driven by typed card slots, each with its own shuffled mini-deck. Built around deep class/element build combinations and roguelite runs with persistent between-run progression. Currently a placeholder-visuals combat prototype (one arena, one Fire Rogue, staged enemy waves). See `docs/GDD.md` for the design and `docs/ROADMAP.md` for status.

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
project.godot   Godot project (main scene: scenes/main/Main.tscn)
src/            GDScript, grouped by system (camera, cards, combat, core, debug, effects, enemies, main, player, ui)
scenes/         .tscn scenes
data/           JSON game content and tuning (cards, enemies, waves, statuses, UI, VFX, scenarios, input bindings)
assets/         icon and one shader (no art or audio yet)
addons/gdUnit4  vendored test framework
tests/          gdUnit4 suites (tests/unit), fixtures, tests/support/test_input.gd
tools/          PowerShell wrappers and headless/capture tools
docs/           documentation
```

## Running the project
Requires Godot 4.7.x (developed on 4.7.2 stable). Open `project.godot` in the editor and press Play, or use the command line:

```
godot --path . --quit   # smoke-check with no window (verified: exits 0)
godot --path .          # play it
```

Controls (from `data/input_bindings.json`): WASD move, mouse aim, Space dodge, left click light attack, right click heavy attack, 1-5 use a card slot, Ctrl+1-5 swap a dead card, Esc pause/settings, F3 debug overlay. Holding a slot key shows the card's hit area and releasing casts it (change with the `cast_trigger` setting in the pause screen).

`godot` must be on PATH, or set `GODOT_BIN` to the full path of the Godot executable, or call it directly: `"C:\path\to\Godot.exe" --path .`. All `tools\*.ps1` scripts resolve the binary from `GODOT_BIN` first, then `godot_console`/`godot` on PATH, and prefer a `*_console.exe` sibling.

## Running tests
Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), vendored in `addons/gdUnit4`. Run the full suite headless:

```
powershell -File tools\run_tests.ps1
```

This runs every suite under `/tests` and exits non-zero on any failure. Last verified run: 542 test cases in 52 suites, all passed, about 3 minutes. Reports go to `reports/` (gitignored). The script uses the console-subsystem `*_console.exe` build when one sits next to the resolved binary, because PowerShell cannot reliably wait on or read the windowed build, which made failures look like passes (see `docs/DECISIONS.md`).

> After adding a new global class (`class_name`) the plain headless run may fail with "Could not find type X in current scope". Run `godot --headless --editor --quit --path .` once to rebuild the class cache (verified: exits 0), then re-run the tests.

Tests and tools that press a card or attack key must send an `InputEventAction` (see `tests/support/test_input.gd`), because `Input.action_press` emits no event and the player reads input events.

## Screenshots and scripted scenarios
Capture is built into the game and runs only when user args follow `--` (nothing runs in normal play). It needs a renderer, so it must run windowed; `--headless` cannot capture. The game quits itself after the last shot. Output goes under `screenshots\` by default, which is gitignored.

```
powershell -File tools\capture_screenshot.ps1                                  # hp_bars scenario, 1 shot at 3.0 s -> screenshots\shot.png
powershell -File tools\capture_screenshot.ps1 -Scenario attacks -After "0.75,2.4,2.7" -Out screenshots\atk.png   # several shots -> atk_0.png, atk_1.png, ...
godot --path . -- --screenshot-after=3.0 --screenshot-out=screenshots/a.png --scenario=hp_bars
godot --path . -- --screenshot-count=3 --screenshot-interval=2.0 --screenshot-out=screenshots/c.png   # shots at 2 s, 4 s, 6 s
godot --path . -- --scenario=hp_bars                                          # play a scenario by hand, no capture
```

`capture_screenshot.ps1` parameters: `-After` (seconds, comma list, default "3.0"), `-Out` (default `screenshots\shot.png`), `-Scenario` (default `hp_bars`), `-Resolution` (default `1280x720`). Without `--screenshot-out` the game writes to `user://screenshot.png`.

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

Two more capture helpers (both need a renderer, outputs are PNGs; run and confirmed to save a file):
```
godot --path . --script tools/vp_capture.gd -- 2560 1440 screenshots/vp.png     # real Main scene in an oversized SubViewport
godot --path . res://tools/SlotStateCapture.tscn -- 1280 720 screenshots/slots.png   # HUD with ready and cooling slots
```

## Headless bot-sim
A small crash/NaN check on the card and deck system (not a balance tool). It drives N "rooms" with random card use and swaps against an empty room and reports NaN in cooldowns or health.

```
powershell -File tools\run_bot_sim.ps1 -Rooms 20      # verified: prints "Bot-sim OK", exit 0
```
The script's only parameter is `-Rooms`. Its output suggests `--seed=1` to reproduce, but the wrapper does not pass a seed (the default is 1), so that hint cannot be followed through `run_bot_sim.ps1`. `tools/bot_sim.gd` itself reads a `--seed=N` user arg and seeds its own RNG from it; whether a rerun is then fully identical was not tested.

## Wave density sim
Plays the real Main scene (spawner, enemies, player) with a bot that uses the real input actions, then reports crashes, NaN, cap violations, enemies or player leaving the arena, stalls, damage taken, alive counts, spacing, and rough CPU frame cost. It runs as a scene (so autoloads exist), headless. `-Seconds` is game time, `-Scale` is `Engine.time_scale` (1 = real time and most faithful, default 3), `-God` keeps the player alive to exercise the whole wave table, `-Idle` is a player who never moves, `-Runs` repeats with consecutive seeds (verified: `-Seed 20 -Runs 2` ran seeds 20 and 21), `-Seed` sets the first seed.

```
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 150 -Runs 3
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 120 -God
powershell -File tools\run_wave_sim.ps1 -Seed 20 -Seconds 60 -Runs 3 -Idle -Scale 1
```
All forms run and end with `WAVE SIM OK` (verified with shorter `-Seconds`; the 150 s and 120 s forms use the same code path). The wave table and the simultaneous-enemy cap live in `data/waves.json` (validated by `src/enemies/WaveConfig.gd`; enemy ids and scenes in `data/enemies.json`). Headless frame times exclude rendering.

**Seeds are only partly reproducible.** The sim prints "rerun with --seed=N", and the same seed gives the same wave plan and the same enemy steering, but not the same whole run: HP lost and kills differ between reruns of one seed. Known causes (qa finding S6-4, still open): card slot shuffles and the player's status RNG are not seeded, and hit-stop uses the wall clock. Use seeds to reproduce a setup, not an outcome.

## Death / restart soak (real scene reload)
Kills the player in the real Main scene, waits for `game_over_ready`, calls `restart_arena()` (twice, on purpose), repeats, and also restarts mid slow-mo. It checks HP, `Engine.time_scale`, enemy count, wave timer, Game Over screen state and orphan/object/node counts, and fails on any engine ERROR/WARNING line.

```
powershell -File tools\run_reload_cycle.ps1 -Cycles 5     # verified: prints "RELOAD CYCLE OK", exit 0
```
It runs `tools/ReloadCycle.tscn` headless; it must be a scene so autoloads resolve. Re-run it whenever `Main`, `Juice`, `Player` or the autoloads change.

## Last verification
Commands above were run on 2026-10-28 (screenshot and sim forms with the listed scenarios; some with shorter durations or other output paths than shown) on Windows with Godot 4.7.2 (console build via `GODOT_BIN`). Not run interactively: plain `godot --path .` and `-- --scenario=hp_bars` without capture (they open a window and wait for a person; the same code path ran under capture).
