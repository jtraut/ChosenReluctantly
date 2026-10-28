# QA review: Post-milestone polish 1, Slice 3 (auto light attack, manual heavy attack)

Date: 2026-10-27. Reviewer: qa. Commits reviewed: 1c12fd9, de415be (gameplay), b4011aa (UI).

## Verdict: PASS

No blocking issues. Three non-blocking findings (wedge reach vs hitbox, one flaky pre-existing test that I fixed, debug panel STOP filter) and one logged follow-up.

## Commands run and results
| Check | Command | Result |
|---|---|---|
| Editor load | `godot --headless --editor --quit --path .` | Exit clean. Only output: asset reimport progress for `logo.png`. No ERROR/WARNING lines. |
| 20 s run | `godot --headless --path . --quit-after 1200` (run twice, output captured) | Exit 0, only the engine banner. No ERROR, WARNING or `BUG:` lines. Wall time about 9 s (1200 frames headless run faster than 60 fps, so "20 s" is frame count, not seconds). |
| Kill-style run | `timeout 8 godot --headless --path .` (killed mid-run) | Prints `ERROR: BUG: Unreferenced static string to 0: _exit_world / servers / Physics3DConstraintSolveIslands` (core/string/string_name.cpp:118). Reproduced identically on commit 42c9d8c (checked out in a worktree), so **pre-existing and caused by killing the process, not by Slice 3**. They do not appear with a clean `--quit-after` exit. |
| Full suite | `powershell -File tools\run_tests.ps1` | After my changes: **168 test cases, 0 errors, 0 failures, 0 orphans**, rc 0 (3 consecutive runs at 167, then 168 after the last test). Baseline before my changes: 157/157 on the first run (see flake below). |
| Reload soak | `powershell -File tools\run_reload_cycle.ps1 -Cycles 5` | `RELOAD CYCLE OK`, orphans 0, objects 1817 stable across cycles 1-5, nodes 89, time_scale 1.0. |

Not claimed: ordinary GDScript lint warnings do not print in any CLI mode on 4.7.2 (DECISIONS 2026-10-26), so "no warnings" only covers what the commands above surface.

## Criteria 1-10
1. **Attack data**: PASS. `data/attacks.json` has auto, stat, interval, manual_min_gap, damage, range, arc, wind_up, knockback, hit-stop, shake, color, flash. `AttackDatabase` validates every field (bool, strings, numeric ranges, NaN/inf, colour, both ids required); tests cover missing keys, bad values, NaN, missing `heavy`, non-object entry. Invalid attacks are `push_error`'d and not built.
2. **Light auto only with a target in range/arc**: PASS. `test_no_auto_fire_without_target` (stays ready, swings the tick a target appears); real-scene `test_light_auto_hits_enemy_in_front_and_not_behind`; my arc-edge test places a target at half angle -4 deg (hit) and +4 deg (not hit) using the real physics query.
3. **Click resets timer, same-tick fires once**: PASS. `test_manual_click_mid_timer_resets_auto_timer` is not vacuous (comment explains the auto swing would otherwise land in the second window). `test_click_on_same_tick_as_auto_fires_once` is real but weak: the 0.25 s `manual_min_gap` also prevents a double, so it would survive an ordering regression. Non-blocking.
4. **Heavy**: PASS. Wind-up, cooldown, light blocked during wind-up, data `auto: true` switches it to auto (and obeys the target rule). Manual heavy defaults to false. Real-scene wind-up then hit test passes.
5. **StatModifiers**: PASS. Light halved by a multiplicative modifier (real fire timing), heavy `attack_cooldown.heavy` additive, floor at 0.05 s. I added a heavy multiplicative test that checks readiness at 50% and 60% of the halved cooldown (`test_heavy_cooldown_resolves_through_modifier_in_real_timing`).
6. **Shared templates, no slots**: PASS by inspection. Fires the existing `cone` template via `EffectTemplates.execute`; no `CardSlot` access in `AttackController`/Player attack code.
7. **Nothing while dead / blocking**: PASS. `can_act()` gates `tick`; death cancels wind-up (`attack_cancelled`), visual hidden. I added: no fire after 60 frames post-death-mid-wind-up; dead player with held left+right click and an enemy in front deals zero damage over 120 frames; cooldown does not bank while cannot-act.
8. **Bindings**: PASS. `attack_light` LEFT, `attack_heavy` RIGHT in `input_bindings.json`; `attack_basic` removed (tested).
9. **Indicators**: PASS (functional). `AttackMeter` reads progress/ready/winding-up; layout inside the safe area at three resolutions (test). Visual taste is playtester territory.
10. **DECISIONS**: PASS. Placeholder numbers, rules and the input-polling gap are logged (2026-10-27, both halves).

## Specific checks
- **Visual vs hitbox**: wedge mesh max radius equals `range` and max angle equals `half_angle_degrees` for both attacks (test). Angular edge matches the real hit test. **Radial reach does not**: the hit test is a sphere overlap against the hurtbox capsule (radius 0.45), so an enemy whose centre is up to about `range + 0.45` is hit while the wedge is drawn only to `range` (light drawn 1.8, effective about 2.25; auto-fire triggers at that reach too). Pinned in `test_hitbox_radial_reach_exceeds_wedge_by_at_most_hurtbox_radius`. Same behaviour exists in `MeleeQuery` for cone cards. Non-blocking now; it is exactly what Slice 4 criterion 4 ("visuals match hitboxes") must resolve (either draw to range + radius or measure hits by distance to the hurtbox surface). Flagged to game-lead.
- **Heavy wind-up + dodge**: wind-up continues through a dodge, fires exactly once, no error (test). No exploit found beyond the logged design: swing resolves from the post-dodge position/facing and the player has i-frames during the roll, so "wind up, roll, hit" is possible. Cooldown is 1.8 s, so it is not spammable. Design call for game-lead/playtester, not a defect.
- **Capture-only keys** (`freeze_aim`, `heavy_at`): only read in `Scenario.gd`, which exists only when `--scenario=` is passed in user args. Test confirms plain Main has no Scenario node, camera is set, `attack_heavy` not pressed, and only the `attacks` scenario carries the keys.
- **4/s manual light cap**: confirmed, 600 ticks (10 s) of held click gives 38 to 41 swings.
- **s2-e HUD swallows clicks**: ux-designer's `test_new_hud_controls_ignore_mouse` is real. Mutation check: replacing `_ignore_mouse_recursive($Root)` in `Hud._ready` with `pass` made that test fail (that run had 3 failures total; the other two were the flaky player_attack tests below, not the mutation). I added a whole-Main walk (`test_main_ui_does_not_swallow_clicks`). It found that the F3 `DebugOverlay/Panel` has STOP filter (hidden by default, dev-only; exempted in the test with a comment). Whether a STOP panel could ever block attacks is moot only if polling ignores GUI handling; I believe `Input.is_action_just_pressed` is unaffected by GUI consumption but did not verify that, so I list it as unverified.
- **Game Over**: its root is STOP by design; the player is dead, `can_act()` is false, and I verified a dead player ignores held clicks. Safe. The logged gap (attacks poll `Input`, so clicks on a future full-screen UI such as the reward screen would still attack) is left as a follow-up for Milestone 3b: latch attack input in `_unhandled_input` or block via an explicit "UI modal" flag.

## Bugs / issues
Blocking: none.

Non-blocking:
1. **Wedge understates reach by about the hurtbox radius** (`src/combat/MeleeQuery.gd` `find_hurtboxes_in_sphere`, used by `Player._attack_has_target` and the `cone` template). Repro: `test_hitbox_radial_reach_exceeds_wedge_by_at_most_hurtbox_radius`. Slice 4.
2. **Flaky existing test** `tests/unit/player_attack_test.gd` `test_light_auto_hits_enemy_in_front_and_not_behind` (and the heavy/death tests). It sets `player.camera = null` to freeze aim but the player has usually already turned toward the headless mouse (observed rotation 68 deg) depending on first-frame timing, so "front" was outside the 50 deg half angle. It passed on my first full run (157/157) then failed 5 runs in a row with no code change. Fix, in the test only, not weakening it: reset `player.rotation = Vector3.ZERO` after nulling the camera (done). With the fix the suite is green on 5 consecutive runs. Gameplay is unaffected.
3. **DebugOverlay Panel mouse_filter STOP** (`scenes/ui/DebugOverlay.tscn`, node Panel). Dev-only, hidden by default. One-line fix if wanted: set `mouse_filter = 2`.
4. `test_click_on_same_tick_as_auto_fires_once` cannot detect an ordering regression (see criterion 3).
5. README `--quit-after 1200` "20 s" is frames; wall time was about 9 s. Cosmetic.

## Housekeeping done
- README death/restart soak command fixed to `tools\run_reload_cycle.ps1` (also normalised stray CRs so the diff is one line).
- `tools/vp_capture.gd.uid` was already tracked (committed in b4011aa); nothing to add.

## Tests added/changed
- New `tests/unit/slice3_qa_test.gd` (11 tests): heavy cooldown modifier, 4/s manual cap, no cooldown banking while cannot-act, wedge mesh vs data, arc edge vs real hit test, radial reach gap, heavy wind-up + dodge, death mid wind-up, dead player ignores clicks, capture keys inert, whole-Main mouse filter walk.
- `tests/unit/player_attack_test.gd`: deterministic facing (flake fix above).

## Not verified
- Windowed visual output and feel (headless only; ux-designer captures and playtester cover this).
- Whether GUI-consumed mouse events still register in `Input.is_action_just_pressed` (see s2-e note).
- Bot-sim (`tools/bot_sim.gd`) does not yet exercise attacks; not required by the roadmap qa line, noted for growth.
