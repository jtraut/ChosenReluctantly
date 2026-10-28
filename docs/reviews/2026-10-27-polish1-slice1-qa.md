# QA review: Post-milestone polish 1, Slice 1 (Death and game over)
Commits reviewed: 9744135, 99f6af2. Reviewer: qa, 2026-10-27. Godot 4.7.2.

## Verdict: PASS

## Checks run (by qa, not trusted from devs)
- `godot --headless --editor --quit`: only first-run reimport progress lines (logo.png); no ERROR / SCRIPT ERROR / WARNING lines.
- `godot --headless --quit-after 1200` (20 s): only the version banner; no errors or warnings.
- `powershell -File tools\run_tests.ps1`: 112 cases, 0 errors, 0 failures, 0 orphans, 17/17 suites, exit 0 (107 existing + 5 added by qa in `tests/unit/slice1_qa_test.gd`). The runner's own output has two ERROR lines ("remote port number must be between 1 and 65535", "Unable to connect to 127.0.0.1:0") caused by `--remote-debug tcp://127.0.0.1:0` in run_tests.ps1; pre-existing, harmless, not from this slice.
- Caveat per roadmap note: ordinary GDScript lint warnings do not print in any CLI mode in 4.7.2, so "no warnings" covers only what those three commands surface.
- New: `powershell -File tools\run_reload_cycle.ps1 -Cycles 5` (real `reload_current_scene()`, headless), exit 0.

## Real reload soak (5 cycles)
Each cycle: lethal hit, assert slow-mo 0.25 active, extra hit while dead, wait `game_over_ready`, assert Game Over screen visible, `restart_arena()` called twice, assert old Main freed, new scene fresh (HP full and > 0, not dead, `is_game_over()` false, `time_scale` 1.0, tree unpaused, enemy count == first wave, wave timer reset, current Camera3D, Game Over hidden).

| Point | orphans | objects | nodes | time_scale |
|---|---|---|---|---|
| baseline | 0 | 1747 | 85 | 1.0 |
| cycle 1 | 0 | 1762 | 85 | 1.0 |
| cycle 2-5 | 0 | 1762 | 85 | 1.0 |
| after mid-slow-mo restart | 0 | 1766 | 88 | 1.0 |

No growth after cycle 1 (+15 objects once, from first-time caches). Mid-slow-mo restart (restart called at time_scale 0.25 before `game_over_ready`): scene replaced, time_scale 1.0, and after waiting 1.3 s the stale 0.9 s beat timer did not announce game over on the new arena. Double `restart_arena()`: ignored, one reload. Zero ERROR/WARNING lines in output.
Harness note: the first Main instance is added before it is `current_scene`, so the tool binds its Game Over screen by hand for that instance only; cycles 1-5 use the real path and the screen showed correctly every time.

## Acceptance criteria
1. Dies once, input off, collapse, slow-mo beat, then screen: PASS (soak + player_death_test).
2. Idempotent (two hits, hit + Burn): PASS (existing tests plus qa tests for double lethal hits and fire after death; `game_over_ready` fires exactly once).
3. No damage/cards/dodge/attack after death; enemies stand down: PASS (Player._physics_process early-returns when dead, hurtbox invulnerable, `start_forced_move` refused; Enemy `_has_live_target`, spawner stops).
4. `Player.player_died` signal: PASS.
5. Clean restart: PASS (see soak). Scene reload choice is logged in DECISIONS.md.
6. Enemy death/effects cleanup: PASS (no regression in suite; orphan count 0 across cycles).
7. Game Over screen: PASS on code/behaviour (focused button, click/Enter/Space, root swallows mouse, data-driven text). Visual readability is playtester/ux scope; not judged here.
8. HP label "HP %d / %d": PASS (qa test).

## kill_player_at hook
Only read in `Scenario._process`; Scenario nodes are created only by `Main._setup_debug_capture` when `--scenario=<id>` is passed as a user arg, and only the `game_over` scenario defines the key. qa tests assert no Scenario node exists in a plain Main, the `hp_bars` def lacks the key, and the player survives 30 frames. Cannot fire in normal play. Side note (non-blocking): under `--scenario=game_over`, Try again reloads the scene and the scenario re-arms and kills the player again at 1 s; fine for capture tooling.

## Known gaps
- (a) Player projectiles in flight at death still damage enemies: acceptable, cosmetic, harmless during a 0.9 s beat; worth tidying when Milestone 3 run-end is built.
- (b) Enemies idle rather than wander: acceptable (criterion allows "idle or wander").
- (c) Burn keeps ticking on a dead player: acceptable; Health ignores it, verified by test (HP stays 0, one death).
- (d) Slot bar clipped at 720p: pre-existing, Slice 2.

## Non-blocking issues
- At the moment `game_over_ready` fires, `Engine.time_scale` is still 0.25 for up to one frame: the beat timer and `Juice._process` both key off the wall clock and the timer fires first. Harmless (restart resets it, and nothing is interactive for one frame). Documented in the soak by waiting 2 frames.
- `tools/run_tests.ps1` prints two harmless ERROR lines about remote debugger port 0 (pre-existing).
- No automated test can reload the scene inside gdUnit (it would reload the runner), so the real-reload check lives in `tools/run_reload_cycle.ps1` and is not part of the suite; re-run it after any change to Main, Juice, Player, or autoloads.

## Not verified
- Visual appearance of death beat and Game Over screen at any resolution (needs windowed capture; playtester).
- Windowed (non-headless) reload; the soak ran headless.

## Added by qa
`tools/reload_cycle.gd`, `tools/ReloadCycle.tscn`, `tools/run_reload_cycle.ps1`, README section, `tests/unit/slice1_qa_test.gd` (5 tests).
