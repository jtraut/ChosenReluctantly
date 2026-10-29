# QA review: Tooling, true-size capture (c4a3747..7a372b9, 3402446, 968e9f0)

Verdict: **PASS**

## Evidence
- Full suite, `tools\run_tests.ps1`: 552/552, 0 errors, 0 failures, 0 orphans, exit 0 (55 suites).
- True-size capture, `capture_screenshot.ps1 -TrueSize WxH -Scenario hp_bars -After 3.0`: PNG IHDR sizes are 1280x720, 1920x1080 and 2560x1440 exactly. I opened the 2560x1440 PNG: floor, blue player, red/grey/blue enemies, HP bars, damage numbers, cast telegraphs, card HUD all visible, so waves spawn and the scenario works. `-Scenario attacks -After "0.75,2.4,2.7"` at 1920x1080 saved 3 shots. Console output had only the engine banner and the "saved" lines (no ERROR/WARNING, no RID leak), exit 0.
- Spawn parent: `src/core/WorldRef.gd` prefers `current_scene` when set (normal play and tests unchanged) and falls back to the registered Main only where it is null (VpCapture SubViewport). Covered by `world_ref_test.gd`.
- Dodge data: `data/player.json` holds speed 28, duration 0.25, cooldown 0.8, block_ticks_after_pause 2. `PlayerConfig.validate` is tested against bad types, ranges, missing and extra keys (`player_config_test.gd`), and a Player-travel test confirms 7 m.
- Seeded repeat: `run_bot_sim.ps1 -Rooms 20 -Seed 7` run twice gave byte-identical output (checksum 3894014494). Seed 8 gives a different checksum (3926447135). `run_wave_sim.ps1 -Seed 5 -Seconds 30` run twice gave identical `state_hash 460299206`, kills 10, casts 55. Only the wall-clock frame-ms line differs, which is expected.
- 6-a: `VfxSizing.enemy_shot_lane_length` is used by `TemplateVfx.enemy_shot_lane`, with a test in `cast_markers_test.gd`. The `Enemy.gd` header now says stats come from `data/enemies.json`.
- Reload soak, `run_reload_cycle.ps1`: "RELOAD CYCLE OK", orphans 0, nodes 114, time_scale 1.0.

## Blocking issues
None.

## Non-blocking
1. README capture and sim sections are stale (known, folded into C1-h). `-TrueSize`, `run_bot_sim.ps1 -Seed`, `run_wave_sim.ps1` fixed-fps, and the `tools/vp_capture.gd` usage need updating. The README claim that the wrapper cannot pass a seed is now false. For tech-writer.
2. `Main.gd:74` (`reload_current_scene`) and `GameOverScreen.gd:26` (`bind(get_tree().current_scene)`) still use `current_scene`. This is fine in normal play. Inside VpCapture, restart after death would not work, but capture does not exercise it.
3. Wave-sim wall-clock timing lines differ run to run, so a raw output diff is not a valid repeat check. Compare `state_hash`.
4. `run_wave_sim.ps1 -Scale >1` drops `--fixed-fps` and does not repeat (the script says so).

## Not verified
- Visual check of 1280x720 and 1920x1080 PNGs: dimensions only. I viewed 2560x1440 only.
- The windowed-capture path without `-TrueSize` was not re-run.

No new tests were added; existing coverage of the acceptance items was adequate. Director-facing questions: none.
