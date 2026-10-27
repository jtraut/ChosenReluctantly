# Chosen, Reluctantly

A 3D isometric action RPG where your skills are cards: real-time combat driven by typed card slots, each with its own shuffled mini-deck. Built around deep class/element build combinations and roguelite runs with persistent between-run progression. Currently a placeholder-visuals combat prototype — see `docs/GDD.md` for full design and `docs/ROADMAP.md` for current status.

## Running the project
Requires [Godot 4.7+](https://godotengine.org/download). Open `project.godot` in the Godot editor and press Play, or run headless/windowed from the command line:

```
godot --path . --quit   # smoke-check with no window
godot --path .          # play it
```

If `godot` isn't on your PATH, set `GODOT_BIN` to the full path of the Godot executable, or pass it explicitly: `"C:\path\to\Godot.exe" --path .`.

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
