# QA review: Polish 1, Slice 6 (6a, 6b) and the 5d re-check

Date: 2026-10-28. Reviewer: qa. HEAD at start a9d1fe0. Commits: 5d fixes c3d244f, 6e8c3e6, 344cdff, a23a960, f3e8c42, b1383f0; 6a 37c42b6..4f5220e; 6b efaf164..567cdc4.

## Verdicts

**Part 1, 5d re-check: PASS.** S5d-1, S5d-2, F3 RESOLVED. F1 RESOLVED as I defined it in the 5d review (steering no longer depends on the instance id). One caveat for game-lead: the broader "same seed gives the same simulated run twice" is NOT true (finding S6-4). The cause is outside 5d (see below), so I do not hold 5d for it, but game-lead should decide that explicitly.

**Part 2, Slice 6: FAIL (two blockers, both small).**
- **S6-1:** an attack click latched before a pause survives it and fires after resume.
- **S6-2:** the dash preview shows the drive distance (4.0 m) but the player comes to rest about 8.1 m away. The preview is not "where the card really goes."

Everything else in the brief passes. Two qa tests are red on purpose (S6-1, S6-2). Do not delete or weaken them; they go green when the fixes land.

## Counts
| Run | Result |
|---|---|
| Full suite, run 1 (no qa file yet) | 512 run, 0 fail, exit 0 |
| Full suite, run 2 (no qa file yet) | 512 run, 0 fail, exit 0 |
| Full suite, run 3 (included a first draft of my file) | every one of the 512 existing tests passed; the only failures were in my draft file (`separation_5d_test::test_steering_never_exceeds_own_move_speed` passed in all 3 runs, in the final run too) |
| Final full suite | **537 run (512 + 25 new), 535 pass, 2 fail on purpose** (S6-1, S6-2), exit 100 |

Expected ERROR lines in the final run: runner port pair, `nope_enemy`, `data/ui.json hp_bars`, `Settings: settings file ... unreadable` (existing test), and `ConfigFile parse error ... 'press'` (my unquoted-value fixture; the store reports it and falls back, which is the wanted loud path). Unexpected: 4x `Parameter "material" is null` from `ux_6b_test::after_test` (finding S6-6).

## Part 1: 5d re-check
| Item | Verdict | Evidence |
|---|---|---|
| S5d-1 slide clamp | RESOLVED | `slice5d_qa_test::test_crowd_around_the_player_never_exceeds_move_speed_on_any_frame` passes unmodified (13 s) in all 3 full runs and the final run. Code: slide scaled to `move_speed` in the in-range branch (c3d244f) |
| S5d-2 stats validation | RESOLVED | `slice5d_qa_test::test_s5d_2_whole_config_validate_rejects_missing_or_bad_stats` passes unmodified in all runs. `validate_enemies` calls `validate_stats` (6e8c3e6) |
| F3 uid files | RESOLVED | `enemy_stats_5d_test.gd.uid`, `separation_5d_test.gd.uid`, `slice5d_qa_test.gd.uid` exist and are committed. Opening the editor creates no new uid except for my new file |
| F1 | RESOLVED (as scoped) | `get_instance_id` is gone from `Enemy.gd`; swirl side is `spawn_index` parity and the on-top push is `spawn_index * golden angle`. My test `test_f1_steering_depends_on_spawn_index_not_on_the_instance_id` shows the same spawn_index gives an identical velocity with 0, 7 and 41 junk nodes allocated first, and odd and even indices swirl opposite ways. Separately, `test_f1_same_seed_crowd_is_bit_identical_across_runs_and_shifted_instance_ids` runs a 10-chaser crowd 300 physics frames from an aligned start and asserts under 1e-6 m difference across three runs and 53 shifted instance ids (a different seed must differ). A throwaway diagnostic showed the same with steering off. `separation_5d_test::test_steering_never_exceeds_own_move_speed` passed 3 of 3 full runs, plus the final run |
| 344cdff fixture edits | No weakening | Only `heavy_3b2_test` and `slice5_qa_test` valid fixtures gained a real `stats` block (`EnemyConfig.stats_for("melee_chaser")`). Their positive assertions (`is_empty`) are unchanged; negative fixtures still fail for their own reason (bad scene or rank) |
| Two qa regression tests unmodified | Yes | `git diff 8751371 HEAD -- tests/unit/slice5d_qa_test.gd` is empty |

Not reproduced by seed (S6-4): `run_wave_sim.ps1 -Seed 300 -Seconds 40 -Scale 1` twice gave HP lost 4 vs 16, kills 13 vs 15, spread 84% vs 94%; `-Seconds 60 -Scale 3` twice gave HP lost 0 vs 8, kills 25 vs 24. Steering is ruled out (above). Candidate sources, none seeded by the sim: each `CardSlot` shuffle uses an unseeded `RandomNumberGenerator.new()`, `Player.status_rng.randomize()`, and Juice's hit-stop deadline uses the wall clock (`Time.get_ticks_msec`), so the number of physics steps in a slow-mo depends on wall time. I tried seeding the first two in the sim as an experiment and the runs still differed (so the wall clock or something else remains); I reverted that edit. This also makes the `rerun with --seed=N to reproduce` line in the sims and README only partly true.

## Part 2: Slice 6 per-requirement table
| Requirement | Verdict | Evidence |
|---|---|---|
| Preview size = hitbox, every shape and card in data | **PARTIAL** | Cone and aoe: PASS. `test_every_cone_and_aoe_card_hits_out_to_the_previewed_reach_and_not_beyond`: for every cone and aoe effect in `/data/cards`, a real hit lands at reach-0.05 and misses at reach+0.1. Projectile lateral: PASS (`test_projectile_lane_half_width_is_where_a_real_shot_stops_hitting`, real shot, half width -0.05 hit, +0.1 miss). **Dash: FAIL (S6-2).** Projectile tip: pinned, 0.3 m past the drawn tip is still hit (S6-3). Self ring: shown for heal, buff, status-only cards, switchable in data |
| Centred where the card really hits | PASS | Cone and aoe centred on the caster along the facing, the same origin the templates use; projectile starts `PROJECTILE_MUZZLE_OFFSET` ahead, same as the template (tests above). Aoe cards have no target point (only the Wizard heavy does) |
| Release casts exactly once | PASS | Real events: press 5 frames, 0 casts; release, 1 cast; 10 frames later still 1; a second release without a press, 1 |
| Press mode casts on press | PASS | Same test: 1 cast on press, no preview, release adds none |
| No cast on cooldown; slot ready during a hold casts on release | PASS | Dev tests (`cast_input_6a_test`) plus the above; `try_use` refuses a cooling slot |
| Cancel: death | PASS | `test_death_cancels_the_preview_without_casting` (dev) |
| Cancel: pause or settings open | PASS | Held key, real Esc, release while paused, Esc again: 0 casts, no preview. Hold, pause, resume, release: 0 casts. A key pressed while paused does nothing |
| Cancel: switching key, setting change mid-hold | PASS | Dev tests; mine: change `cast_trigger` mid-hold, release is not a cast |
| Cancel: focus-out | PASS in code and dev test; real OS focus loss **not verifiable headless** | `_notification` handles `APPLICATION_FOCUS_OUT` and `WM_WINDOW_FOCUS_OUT` |
| Dead-card swap never casts | PASS | Real Ctrl+1 key events: 0 casts, no preview (`test_dead_card_swap_with_real_ctrl_digit_never_casts`) |
| Setting persists across reload and save/load | PASS | Save, new store, new Main: the "press" button is selected and a card key really casts on press. There is no game-save system yet, so "through a save/load round trip" is the settings file round trip |
| Bad file or value is loud and falls back | PASS | 8 bad bodies (wrong value, wrong type, garbage, truncated section, empty value, unquoted value): all fall back to `release` and put a message in `problems`; the autoload `push_error`s them. A defaults file with an invalid default is caught. Minor: `Settings.save()` result is ignored by the screen (a failed write is silent, S6-7) |
| Tests never touch the real `user://settings.cfg` | PASS | Every suite injects a store with a temp path; `grep` of `tests/` finds no un-injected `save()`. After 3 full suites, all sims and the soaks, `%APPDATA%\Godot\app_userdata\Chosen, Reluctantly\` has no `settings.cfg`. (My in-suite check `test_the_real_user_settings_file_is_not_touched_by_this_suite` is weak because the store is injected in `before_test`; the directory listing is the real evidence) |
| Pause and resume restore time (hit-stop, death slow-mo) | PASS | Dev tests pass; mine: Esc during the death beat pauses at time_scale 1.0, Game Over does not appear while paused, appears once after resume, time_scale back to 1.0 |
| Pause refused over Game Over | PASS | Dev test and mine (real Esc after Game Over leaves the tree unpaused and the screen closed) |
| `PROCESS_MODE_ALWAYS` Esc handler does not double-toggle | PASS | Real `InputEventKey` Escape: one press toggles once; echo events ignored; release ignored; works with the Resume button focused. `paused_changed` fired exactly `[true, false]` |
| Bot still casts through real input | PASS | Wave sim card casts: 329/330/326 (normal), 444/440 (god), 0 in idle as expected |
| D7 applied in data | PASS | `data/ui.json` `hp_bars.visibility_mode = elite_boss_always`. The two bar tests that pin `always_alive` do it deliberately and restore the mode; the config-default test pins the new value. This is a one-line equal-strength change, not a weakening |
| Occlusion cue never shows when the player is visible | **Source-pinned only** | Headless has no renderer. Verified: the cue exists once under BodyMesh, colour, alpha and bias come from data, no shadows, shader is `depth_test_disabled`/`depth_draw_never`, and alpha is multiplied by a `step(depth_bias, scene_depth - body_depth)` factor that is 0 when the body is its own nearest surface. **Not verified:** actual pixels, depth precision at the bias, behaviour while the body topples. The windowed close-out capture should check this |

## Probes
| Probe | Result |
|---|---|
| Does a click on the settings screen leak into an attack or a cast? | **No.** Real left and right `InputEventMouseButton` presses with the screen open: both latches stay false, nothing starts when closing, and a fresh right click after closing starts the heavy. Note the tree pause is what stops them (the player does not process input while paused), not only the screen's Control |
| Does a latched edge survive pause and fire after resume? | **Card keys: no** (`_cast_queue` and the hold are cleared). **Attack clicks: yes (S6-1).** `cancel_cast_preview` does not clear `_attack_latch` |
| Hold a key, open settings, release while paused, resume | **Not a cast.** Pass (also with the key released again after resume) |
| 6a edits to existing qa tests injection-only | **Yes.** I diffed all of them: `attack_meter`, `heavy_3b2`, `player_attack`, `player_death`, `slice3_qa`, `slice3b_qa`, `stun_cue_3b3` swap `Input.action_press` for `TestInput.press` with identical assertions. `slice3_qa::test_main_ui_does_not_swallow_clicks` gained a `SettingsScreen` skip (modal on purpose, hidden until Esc; the real-click test above covers the open state) |
| Per-frame allocations | None found. `CastPreview._process` moves up to 3 pivots with value types and writes materials only on a ready flip; `CastInput` and `PlayerOcclusionCue` have no per-frame code; `SettingsScreen` has no `_process` and rebuilds styles only on resize. `get_state()` deep-copies parts but nothing in `src/` calls it per frame (tests only) |
| Space on the focused Resume button | **Starts a dodge (S6-5).** Space is `ui_accept` and `dodge`; the press closes the screen and the dodge poll sees the same press on the first tick |

## DoD
| Check | Command | Result |
|---|---|---|
| Startup | `godot --headless --path . --quit` | 0 error or warning lines |
| Run | `--quit-after 1200` | 10.4 s wall (about 120 fps, so about 10 sim seconds), 0 lines of error, warning or bug |
| True 20 s | `--fixed-fps 60 --quit-after 1200`; and `--quit-after 3600` for 60 s | 0 error or warning lines both |
| SceneSelfCheck | every Main load; `main_scene_smoke_test` | green, no SceneSelfCheck message in any run |
| Full suite | `tools\run_tests.ps1` | see Counts |
| Reload soak | `tools\run_reload_cycle.ps1 -Cycles 5` | RELOAD CYCLE OK, orphans 0, objects 1903 flat across cycles, time_scale 1.0. Also run windowed (real renderer) 3 cycles: OK, no errors |
| Bot sim | `run_bot_sim.ps1 -Rooms 20` | OK, no NaN |
| Wave sim normal | `-Seed 300 -Seconds 180 -Runs 3` | all survived; HP lost 32/41/39; kills 78/75/84; casts 329/330/326; alive peak 11/12/12, mean 6.3/7.2/5.9; max stall 13/12/14 s; spacing mean 1.83/1.96/1.89 m, worst 0.89/0.71/0.88 m, **80/82/84% of frames >= 1.2 m** |
| Wave sim god | `-Seed 400 -Seconds 240 -Runs 2 -God` | survived; kills 99/105; casts 444/440; alive peak 12/12, mean 7.0/7.1; stall 12/10 s; spacing 89/80% |
| Wave sim idle | `-Seed 500 -Seconds 60 -Runs 3 -Idle -Scale 1` | died at 7.7/8.6/7.5 s, HP lost 30 (unchanged from Slice 5); 0 casts (idle bot); spacing 100% |

No crash, NaN, cap violation or stall near the 45 s alarm. Compared with my 5d numbers (HP lost 40/56/40, kills 76/80/78, spacing 79-92%) nothing regressed.

## Findings
| ID | Severity | Owner | Finding |
|---|---|---|---|
| S6-1 | **Blocker** | gameplay-dev | `Player._attack_latch` is not cleared by `cancel_cast_preview()` or on pause, so a click latched before Esc fires on resume. Window is narrow: the latch is taken by the next physics tick, so in play it needs a click and an Esc inside one tick window (a hit-stop should widen it, but my probe showed a latched click was still consumed within 3 rendered frames of a 0.05-scale hit-stop, so I did NOT demonstrate a realistic in-play sequence). Severity is a blocker because the brief says a latched edge must not survive a pause and the fix is one line. Repro in the test: `TestInput.tap(&"attack_heavy")`, `GamePause.pause()`, `GamePause.resume()`, 3 frames. Fix: clear both latches in `cancel_cast_preview` (or `_on_pause_changed`). Red test: `slice6_qa_test::test_a_latched_heavy_click_does_not_fire_after_pause_and_resume` |
| S6-2 | **Blocker** (pre-existing dash behaviour the preview exposes) | gameplay-dev; game-lead to confirm which side moves | After the forced move ends the player keeps its dash velocity and coasts at friction 28, so Blaze and Bail (distance 4.0, speed 15) drives 4.0 to 4.5 m and comes to rest at about 8.1 m, while the preview path is 4.0 m. The dodge roll shares the code and also coasts (pinned: `test_pin_dodge_coasts_past_its_drive_distance_like_the_dash`, 14 m/s for 0.25 s = 3.5 m driven, rests about twice that). Fix belongs in the end of the forced move (zero or clamp the velocity so the dash ends at its distance), or the game-lead decides the coast is wanted and the path is drawn to it. Red test: `test_s6_2_dash_ends_where_the_preview_says` (drive-only distance test `test_dash_drive_distance_is_the_previewed_distance` passes with a 0.6 m tolerance of one frame at dash speed; it does not prove the preview matches where the player ends up) |
| S6-3 | Non-blocking | ux-designer / game-lead | The projectile lane tip understates the real hit: the drawn lane ends at muzzle + `max_range`, but the shot's hit sphere keeps its radius past the last position, so a target centre 0.3 m beyond the tip is still hit. The sides use the lateral reach, the tip does not. Same geometry as the existing in-flight lane marker. Pinned: `test_pin_projectile_lane_tip_understates_the_real_hit_by_the_lateral_reach` |
| S6-4 | Non-blocking | gameplay-dev, then qa | A seeded sim run does not repeat (numbers in Part 1). Seed `CardSlot` shuffle RNGs and `Player.status_rng` from the run seed through an API, and make Juice hit-stop deterministic (count physics ticks, not wall time) at least under a test flag. Until then "rerun with --seed" reproduces the setup, not the run. The 5d claim "a seed reproduces the same run" in CHANGELOG is corrected (below); DECISIONS 2026-10-28 F1 line says the same and could use a note |
| S6-5 | Non-blocking | ux-designer | Space on the focused Resume button closes the screen and also rolls (see Probes). Fix: focus a neutral control, make dodge latch from `_unhandled_input` too, or swallow the closing key. Pinned: `test_pin_space_on_the_focused_resume_button_also_starts_a_dodge` |
| S6-6 | Non-blocking | ux-designer | The full suite prints 4x `ERROR: Parameter "material" is null` (RD renderer material storage) from `ux_6b_test::after_test` line 30, the immediate `_root_main.free()` of a Main containing the occlusion cue's ShaderMaterial. It appears in every full run from 6b on, but not in the windowed reload soak (scene change) and not on startup or any sim. Likely teardown order in a synchronous free; try `queue_free` plus a frame in teardown, or hold the material on the cue differently. Does not appear in play |
| S6-7 | Non-blocking | ux-designer | `SettingsScreen._on_option_toggled` ignores the result of `Settings.save()`. A failed write (read-only user dir) changes the setting for this session and silently forgets it next launch. A `push_error` on false would make it loud |
| S6-8 | Note | ux-designer | A hand-edited unquoted value (`cast_trigger = press`) makes the engine print its own `ConfigFile parse error` in addition to the store's message: loud, falls back, but double. Fine |
| S6-9 | Note | game-lead | Stale wording in CHANGELOG 5b ("still 'always'; director call D7") now contradicts D7 applied. It is history; I left it |

## Changelog check
- **5d fixes line: inaccurate, fixed by me.** It said "so a seed reproduces the same run." The steering repeats; a run does not (S6-4). Now reads "so the steering itself repeats (a whole simulated run still does not repeat from a seed; see the 6c review)." Hashes c3d244f, 6e8c3e6, a23a960 match the commits. The S5d-1 and S5d-2 sentences are accurate.
- **6a entry: accurate.** Hashes match; claims about the store, press/hold/release, pause and input events hold. It omits 37c42b6 (sim counting casts), harmless.
- **6b entry: accurate.** Hashes 9ff60d8, 98ee2ea, 2f44346, 567cdc4 match. "Never opens over Game Over" verified. "Silhouette through them" cannot be verified headless (see table).
- **D7 entry: accurate** (efaf164). No elite or boss exists in the shipped waves, so "elites and bosses always show theirs" is not visible in play yet.

## Not verified, and why
- Occlusion cue pixels and the not-ready dimming: need a renderer; covered only by data and source pins. The windowed close-out playtest should look at it with the player behind a crowd and in the open.
- Real OS window focus loss: headless.
- Windowed visual of the settings screen at other resolutions: tested only at 720p by the dev's fit test.
- Whether the dash coast is intended: needs game-lead.

## Tests added (this review)
`tests/unit/slice6_qa_test.gd` (+ `.uid`), 25 tests: latch across pause (RED, S6-1); keys while paused; hold, open settings, release while paused, resume; release after resume; real mouse clicks on the open screen and a fresh click after; real Escape toggles once, ignores echo; Esc in the death beat and Game Over; real-hit boundary for every cone and aoe card; projectile lane width (real shot); PIN projectile tip; dash drive distance; dash rest distance (RED, S6-2); PIN Space on Resume; PIN dodge coast; release once and press mode with real events; setting change mid-hold; real Ctrl+1 never casts; settings save and fresh store and fresh scene; 8 bad settings files; bad defaults file; real settings file not touched; occlusion cue pins; F1 steering by spawn_index; F1 aligned same-seed 10-chaser crowd bit-identical across runs and 53 shifted ids; spawner numbering. All use an injected temp settings store and clean up their temp files.

## Director questions
None. Game-lead: S6-2 (is the dash coast intended; which side moves) and whether S6-4 holds 5d.

---

# Re-check 2026-10-28 (qa, targeted)

Range reviewed: 17b28a2, 7b7a471, 0e4d9b5, 6738109, 1ed76f4, 9e6c417, 5095be9, dcdb043 (HEAD 84abe1e at start).

## Verdicts
| Item | Verdict | Evidence |
|---|---|---|
| S6-1 attack latch across pause | **RESOLVED** | `test_a_latched_heavy_click_does_not_fire_after_pause_and_resume` passes, assertions unmodified (`git diff 0d670df HEAD -- slice6_qa_test.gd` touches only comments and the pin renames). `cancel_cast_preview()` now clears both attack latches; it is what pause, death, focus loss and a cast_trigger change call |
| S6-2 dash/dodge coast | **RESOLVED** | `test_s6_2_dash_ends_where_the_preview_says` passes, assertion unmodified (comment only). Forced move scales the last tick by `remaining/delta` and zeroes horizontal velocity on the tick it ends. `forced_move_s6_test` (30/60/120 Hz, dash 4.0 m driven and at rest within 0.02) passes; dodge i-frame ticks 15-16, `dodge_duration` 0.25 and `dodge_cooldown` 0.8 asserted, and the Player export defaults are not in the diff. Behaviour change: dodge about half as far (7.1 to 3.5 m), dash 8.1 to 4.0 m (see observation O1) |
| S6-3 projectile lane tip | **RESOLVED** | Lane length is now `max_range + lateral_reach`, used by both the cast marker and the hold preview. My former PIN became `test_projectile_lane_tip_is_where_a_real_shot_stops_hitting` (0.3 inside the tip is hit, 0.1 past it is not); passes. The dev notes the lane is an upper bound (a shot frees one tick short), which I accept: the rule is "nothing hit outside the drawn lane". The ranged-enemy lane tip (`enemy_shot_lane`) has the same understatement; out of this brief, already flagged to game-lead |
| S6-5 Space on Resume also dodges | **RESOLVED** | Former PIN became `test_space_on_the_focused_resume_button_closes_the_screen_and_does_not_dodge`, and now also asserts a later Space press dodges. Probes below |
| S6-6 null-material errors | **RESOLVED** | Two full runs: 0 occurrences of `Parameter "material" is null`. Fix is test-only (below) |
| S6-7 silent failed save | **RESOLVED** | `ux_6b_test::test_a_failed_save_shows_a_note_and_a_good_save_clears_it` passes: note hidden on open, shown after a failed save (text from data), hidden on re-open, hidden after a good save; one expected `push_error` line in the log. Scene file untouched |

**Overall Slice 6: PASS.** Both intentionally red tests are green; no assertion was weakened.

## Checks
- **Test file diff, no weakening:** the two red tests keep their assertions (S6-1 byte-identical; S6-2 comment only, tolerance 0.5 as before). The three PIN renames each invert a pin that asserted the bug, into an assertion that the bug is gone; the dodge one is stricter than needed (rest within 0.05 of 3.5 m), and the S6-5 one gained a positive "fresh press still dodges" check.
- **No gameplay or data change beyond the brief:** `git diff 0d670df HEAD --stat -- data scenes` is `data/ui.json` only (+2 keys `save_failed`, `save_failed_color` in `settings_screen`); no `.tscn` changed. Src changes: Player, SettingsScreen, UiConfig, VfxSizing, CastPreviewShapes, TemplateVfx only.
- **S6-6 test-only:** the S6-6 commit 1ed76f4 touches only `tests/unit/ux_6b_test.gd` (one assertion line). No production file.
- **S6-5 block does not eat a normal dodge.** Probe (`test_s6_5_probe_dodge_pressed_a_few_ticks_after_resume_still_works`, added by me): pause 3 frames, resume, wait N physics ticks, press dodge. Rolled for N = 0:no, 1:no, 2:yes, 3:yes, 4:yes, 5:yes (6 asserted yes). So the blocked window is the first 2 ticks (about 33 ms) after pause and after resume; a press there is dropped, not deferred (`is_action_just_pressed` is a one-frame edge). That is below human re-press time; acceptable. **Hit-stop does not block:** the block is set only from `GamePause.paused_changed`, which Juice hit-stop does not emit; `test_s6_5_hit_stop_does_not_block_a_dodge` passes. Minor: Resume via the Esc key then an immediate dodge within 33 ms is also dropped; same bound.
- **Frame rate independence:** also checked from the dev's numbers by running their suite in the full runs (30/60/120 all within 0.02 m of 4.0 driven and at rest).

## Runs (this re-check)
| Run | Result |
|---|---|
| Full suite | **542 run, 0 fail, 0 orphans, exit 0** (540 + my 2 probes), twice. ERROR lines, all expected: runner port pair, `nope_enemy`, `data/ui.json hp_bars` invalid mode, `Settings: settings file ... unreadable`, `ConfigFile parse error ... 'press'` (my fixture), and the new expected `Settings: could not save 'cast_trigger'...`. Zero `Parameter "material"` lines |
| 20 s headless | `--fixed-fps 60 --quit-after 1200`: 0 error/warning/bug lines; `--quit-after 1200` plain: clean |
| SceneSelfCheck | no message in any load; `main_scene_smoke_test` passes |
| Reload soak | `run_reload_cycle.ps1 -Cycles 5`: RELOAD CYCLE OK, orphans 0, objects 1903-1905, time_scale 1.0 |
| Bot sim | `-Rooms 20`: OK, no NaN |
| Wave sim normal | `-Seed 300 -Seconds 180 -Runs 3`: WAVE SIM OK, all survived; HP lost 79/96/103; kills 87/86/88; casts 343/343/336; alive peak 11/10/12; stall 7/7/8 s; spacing worst 0.89/0.89/0.85 m, 85/92/83% >= 1.2 m |
| Wave sim idle | `-Seed 500 -Seconds 60 -Runs 3 -Idle -Scale 1`: WAVE SIM OK, died at 7.7/8.6/7.5 s, HP lost 30 (unchanged), 0 casts |

## Observations
- **O1 (balance flag for game-lead, not a defect):** the bot dodges telegraphs, and with the dodge now half as far, HP lost in the same seeded sim went from 32/41/39 (my Slice 6 review) to 79/96/103, about 2.5x, with kills 78/75/84 to 87/86/88. Runs do not repeat from a seed (S6-4), but the shift is far outside the earlier spread, so treat it as real. The dev flagged the feel change and the tuning knobs (`dodge_speed`, `dodge_duration`, Player exports); the playtester should judge it. Dodge distance is a Player export, not data/JSON.
- **O2:** `DODGE_BLOCK_TICKS_AFTER_PAUSE` is a code constant, not data. Fine as a guard, noted.
- S6-4 remains open (capture-tooling task) and is not part of this re-check.

## Not verified
Windowed feel of the shorter dodge and of the lane tip; occlusion cue pixels (unchanged from the main review).

## Tests added in this re-check
Two in `tests/unit/slice6_qa_test.gd` (now 27): the S6-5 post-resume dodge probe (prints `S6-5 PROBE ...`) and the hit-stop non-block test.
