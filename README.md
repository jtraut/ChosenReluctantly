# Chosen, Reluctantly

A 3D isometric action RPG where your skills are cards: real-time combat driven by typed card slots, each with its own shuffled mini-deck. Built around deep class/element build combinations and roguelite runs with persistent between-run progression. Currently a placeholder-visuals combat prototype — see `docs/GDD.md` for full design and `docs/ROADMAP.md` for current status.

Project history in plain language, newest first: `docs/CHANGELOG.md`.

## Running the project
Requires [Godot 4.7+](https://godotengine.org/download). Open `project.godot` in the Godot editor and press Play, or run headless/windowed from the command line:

```
godot --path . --quit   # smoke-check with no window
godot --path .          # play it
```

If `godot` isn't on your PATH, set `GODOT_BIN` to the full path of the Godot executable, or pass it explicitly: `"C:\path\to\Godot.exe" --path .`.

## Screenshots and scripted scenarios
Capture is built into the game and enabled only by user args after `--` (nothing runs in normal play). It needs a renderer, so it must run windowed; `--headless` cannot capture.

```
powershell -File tools\capture_screenshot.ps1                                  # hp_bars scenario, 1 shot at 3.0s -> screenshots\shot.png
powershell -File tools\capture_screenshot.ps1 -After "2.0,2.9,3.6" -Out screenshots\hp.png   # several shots -> hp_0.png, hp_1.png, ...
godot --path . -- --screenshot-after=3.0 --screenshot-out=shots/a.png --scenario=hp_bars
godot --path . -- --screenshot-count=3 --screenshot-interval=2.0          # shots at 2s, 4s, 6s
godot --path . -- --scenario=hp_bars                                      # play the scenario by hand, no capture
```
The game quits itself after the last shot. `screenshots/` is gitignored. Scenarios live in `data/scenarios.json` (`hp_bars`: 9 enemies near the player at mixed HP, 2 with Burn, 3 hit at 2.4s so the ghost trail drains, player has huge HP). Useful capture times for it: 2.0 to 3.6s. Scenario `attacks` shows the auto light attack and a scripted heavy click at 2.2s (wind-up telegraph, then hit); use `-Scenario attacks -After "0.75,2.4,2.7"`. Scenario `targeted_aoe` forces the Wizard heavy (data only, no class built) at a locked ground target: `-Scenario targeted_aoe -After "1.3,1.7,2.0"` shows the ground telegraph during the wind-up, then the burst. Scenario `waves` runs the real spawner at a fast, ungated pace with a 9999 HP player (use `-Scenario waves -After "2.5,5,8"` for a density shot at the data cap). Scenario `stun_crowd` stuns 6 of 9 idle enemies (one is a boss and shows IMMUNE): `-Scenario stun_crowd -After "0.45,0.85,1.6"`. Scenario `card_cast` casts one of each card type (projectile, cone, aoe, Burn, heal, buff, dash) and prints a slot-cooling check for each; use `-Scenario card_cast -After "0.9,1.9,3.2,4.4,5.5,6.1,6.8,7.8"`. 5b scenarios: `bar_modes` (12 idle enemies, mixed HP, two bosses; edit `hp_bars.visibility_mode` in `data/ui.json` between runs to compare bar modes: `always_alive`, `after_damage`, `hidden_at_full`, `elite_boss_always`), `pointy_shot` (a neutral bolt in flight, `-After "0.62,0.78,0.9"`), `stun_cancel` (stun lands mid wind-up, `-After "0.1,0.23,0.32"`).

## Running tests
Tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4), vendored in `addons/gdUnit4`. Run the full suite headless with:

```
powershell -File tools\run_tests.ps1
```

This resolves the Godot binary from `$env:GODOT_BIN` (set it first if `godot` isn't on PATH), runs every suite under `/tests`, and exits non-zero on any failure. Reports are written to `reports/` (gitignored). It automatically prefers the console-subsystem `*_console.exe` build if one sits next to the resolved binary — PowerShell can't reliably wait on or read output from the windowed build, which otherwise makes failures look like passes (see `docs/DECISIONS.md`).

> Note: new global-class scripts (addons, autoloads) aren't picked up by a plain headless run. If tests fail with "Could not find type X in current scope" after adding one, run `godot --headless --editor --quit --path .` once to rebuild the class cache, then re-run the tests.

## Headless bot-sim
A stub balance/crash-sim (will grow in a later milestone): drives a bot through N "rooms" with random card draws/swaps and reports NaN creeping into cooldowns or health.

```
powershell -File tools\run_bot_sim.ps1 -Rooms 20
```

## Wave density bot-sim (Slice 5a)
Plays the real Main scene (spawner, enemies, player) with a bot that uses the real input actions, then reports crashes, NaN, cap violations, enemies or player leaving the arena, stalls, damage taken, alive counts and rough CPU frame cost. Runs as a scene (autoloads), headless, seeded. `-Seconds` is game time, `-Scale` is `Engine.time_scale` (1 = real time and most faithful; 3 = quick), `-God` keeps the player alive to exercise the whole wave table, `-Idle` is a player who never moves.

```
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 150 -Runs 3
powershell -File tools\run_wave_sim.ps1 -Seed 1 -Seconds 120 -God
powershell -File tools\run_wave_sim.ps1 -Seed 20 -Seconds 60 -Runs 3 -Idle -Scale 1
```
The wave table and the simultaneous-enemy cap live in `data/waves.json` (validated by `WaveConfig`; enemy ids and scenes in `data/enemies.json`). Headless frame times exclude rendering.

## Death / restart soak (real scene reload)
Kills the player in the real Main scene, waits for `game_over_ready`, calls `restart_arena()` (twice, on purpose), and repeats; also restarts mid slow-mo. Checks HP, `Engine.time_scale`, enemy count, wave timer, Game Over screen state, orphan/object/node counts, and fails on any engine ERROR/WARNING line in the output.

```
powershell -File tools\run_reload_cycle.ps1 -Cycles 5
```
(Runs `tools/ReloadCycle.tscn` headless; it must be a scene so autoloads resolve.)
