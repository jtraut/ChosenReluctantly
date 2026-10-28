# QA review: Post-milestone polish 1, Slice 3b (attack rework)

Date: 2026-10-28. Reviewer: qa. Commits reviewed: 961d7c6..ad9ee04 (3b-1 961d7c6-4fb5b57, 3b-2 7192e13-ee9adbe, 3b-3 8a9c704-ad9ee04).

## Verdict: PASS (with should-fix items)

No blockers. Every acceptance item in the 3b brief is met in code and covered by a meaningful test, the balance table in DECISIONS matches the data files exactly, and the Definition of Done is green. One real balance problem sits underneath the rule (S3B-1, the pre-existing Burn refresh bug): the "cards beat light" rule is satisfied as the brief defines it, but one shipped card does not beat the light in actual cycling play. That is a should-fix for gameplay-dev and a flag for game-lead, not a reason to hold the playtest.

## Definition of done
| Check | Command | Result |
|---|---|---|
| Editor load | `godot --headless --editor --quit --path .` | 0 ERROR/WARNING lines |
| Startup | `godot --headless --path . --quit` | banner only |
| 20 s headless run | `godot --headless --path . --quit-after 1200` | 0 lines matching error, warning, bug |
| Scenarios in the real scene (600 frames each) | `--fixed-fps 60 -- --scenario=<attacks, targeted_aoe, stun_crowd, card_cast, hp_bars>` | 0 error/warning lines for all five |
| Full suite | `powershell -File tools\run_tests.ps1` | **326/326, 0 errors, 0 failures, 0 orphans**, exit 0. Baseline at HEAD before my tests: 306/306 |
| SceneSelfCheck | `Main._ready` runs it on every start (push_error on any problem); `main_scene_smoke_test` runs it too | silent at startup, smoke test green |
| Reload soak | `tools\run_reload_cycle.ps1 -Cycles 5`, run 4 times | RELOAD CYCLE OK each time. Objects 1869, nodes 104 constant across cycles, orphans 0, time_scale 1.0, lag 7 ms |
| Bot-sim | `tools\run_bot_sim.ps1 -Rooms 200` (and 20) | `Bot-sim OK`. Now seeded and now covers attacks and stun (see Housekeeping) |

**"Remote Debugger" lines.** The suite output has exactly two lines: `ERROR: The remote port number must be between 1 and 65535` and `ERROR: Remote Debugger: Unable to connect to host '127.0.0.1:0'`. They come only from the runner: `tools/run_tests.ps1` line 36 passes `--remote-debug tcp://127.0.0.1:0`. Baseline: I ran the suite in a temporary worktree at 961d7c6^ (before any 3b code, 247/247) and got the same two lines. Not seen in any plain game run, scenario run, soak or bot-sim. Not a 3b regression; non-blocking.

## Per-requirement table
| Requirement | Result | Evidence |
|---|---|---|
| 3b-1 click cap: ratio in data, gap = interval / ratio, scales with attack speed | PASS | `attacks.json` ratio 1.5, heavy 0. Existing `test_spam_click_never_exceeds_ratio_times_auto_rate` (10 ms step, 3 haste levels). **Added** `test_spam_click_cap_holds_at_other_frame_rates_with_a_target_and_with_haste` (4 haste levels x 30/60/144/240 fps x with and without a target, upper and lower bound), `test_attack_speed_floor_keeps_the_cap_finite` (interval at MIN_INTERVAL), `test_heavy_spam_never_beats_its_own_cooldown`, `test_spam_click_through_the_real_player_with_haste` (real Player, input actions, 6 s). |
| 3b-1 card rule, shipped cards pass, fails on bad fixtures | PASS | `card_damage_rule_test` (low cast, slow DPS, tie, bad exception, negative cooldown modifier, whole-tick Burn) plus boot `push_error`. **Added** a negative-damage fixture and a check that no shipped card uses `rule_exception`. |
| 3b-1 balance table in DECISIONS vs data | PASS | **Added** `test_decisions_balance_table_matches_the_data_files`: all 8 damage cards, cast, cycle cooldown and DPS match the table (to 0.01); a new damage card not in the table fails it. I also recomputed by hand from the JSON. Light 3 / 0.6 = 5.0 DPS. |
| 3b-2 heavy numbers (8.5 / 1.8 s, 2.83x burst, DPS under light, area 3x) | PASS | `test_heavy_numbers_burst_area_and_dps_against_light` |
| 3b-2 stun applies and expires | PASS | `test_stun_applies_then_expires`, `test_rogue_heavy_hits_for_damage_and_stuns` |
| Diminishing returns, window 1.5 s, Rogue heavy gets the full stun | PASS | data window 1.5 < heavy interval 1.8 (`test_stun_window_is_shorter_than_the_rogue_heavy_cooldown`); `test_rogue_heavy_at_its_own_cooldown_stuns_the_full_length_every_swing` (12 swings through the pure rules and 6 through the real manager); 0.6/0.3/0.15/immune/recover. **Added** history stays bounded after 5000 stuns, and zero, negative, 1e9 durations and an unknown rank. |
| Elite and boss rules | PASS | `test_stun_elite_halved_and_boss_immune`, `test_elite_stun_is_half_length`, `test_boss_resists_stun_and_nothing_happens` (only `status_resisted`), boss mid-wind-up is not cancelled |
| Stunned enemies neither move nor attack, including no projectile | PASS (gap closed) | Melee: existing. **Added** `test_stunned_ranged_enemy_spawns_no_projectile_but_a_free_one_does` (control shooter fires within 150 frames, a stunned one spawns 0 `Projectile` nodes over 150 frames) and `test_stun_mid_telegraph_for_a_ranged_enemy_cancels_the_shot`. |
| Status chance multiplier math, seeded | PASS | `test_element_chance_is_base_times_multiplier_clamped`, `test_seeded_rolls_are_deterministic_and_hit_the_chance` (seed 424242, same sequence twice, 900-1100 of 2000), `test_apply_on_hit_light_never_burns_heavy_burns_about_half` (seed 7, 150-250 of 400), dead targets and non-fire characters skipped |
| Wind-up slow applied, removed on release, death, interruption, reload; never a root | PASS | existing release, cancel (can_act false), death, fresh scene tests. **Added**: Arena freed mid wind-up then a new one starts at full speed; Wizard heavy slow and swapping class mid wind-up leaves none behind; data guard that no `wind_up_move_slow` reaches -1; slow stays above zero. Bot-sim also checks move speed is never 0 or NaN and is exactly 1.0x when idle, over 200 random rooms. |
| targeted_aoe range cap, no errors off arena | PASS | existing clamp tests plus the live Wizard test (disc lands exactly max_range away, hits inside, not outside). **Added** live test with the player at the arena corner aiming outward at (60, 60), and clamp edge values (zero range, INF, caster outside the arena, non-vector aim). No error lines in the output. |
| 3b-3 stars, tint, IMMUNE popup, telegraph = hitbox, DR 1.5 s | PASS | `stun_cue_3b3_test` (11 cases, data validation with bad fixtures, stars orbit, freed mid-stun, popup once then quiet, telegraph edge stays at `VfxSizing.aoe_reach`, driven by progress). |
| Content in data, typed GDScript | PASS | rank, DR, popup, tint, ratio, slow, shapes all in JSON, validated with loud failure. No untyped declarations seen in the diff. |
| Docs | PASS with nits | DECISIONS 3b-1, 3b-2, 3b-3 logged. See N-docs below. |

## Known gaps from the hand-backs: probed
| Gap | Finding |
|---|---|
| `attack_started` emitted before the wind-up state and slow | Confirmed, pinned by `test_pin_attack_started_is_emitted_before_the_wind_up_state`. Only consumer is Player, which tests `wind_up > 0` from data, so no player-visible bug. Follow-up S3B-3. |
| Burn refresh resets the tick timer | **Real and larger than the hand-back says.** See S3B-1. Heavy's 50% Burn: confirmed measured about 2.0 per proc (one tick per 1.8 s refresh), matching the logged 5.8 DPS, so the heavy is not mis-described. The damage is to the card rule's credit. |
| Re-stun emits no signal | Confirmed, pinned (`test_re_stun_emits_no_enemy_signal_pin`). The stars persist, which is the right visual. Follow-up S3B-4. |
| `Player._telegraphs` is private | Confirmed; existing tests and my new tests read it. Follow-up S3B-5 (a public `has_aoe_telegraph(id)`). |
| Scenario flags unvalidated (S4-4) | Worse than before: 3b added `heavy_class`, `aim_point_offset`, `status_seed`, `stun_indices`, `stun_at`, `stun_duration`, `boss_indices`, all read with raw casts. By inspection `aim_point_offset: [1]` is an index error in `Scenario._build`. Capture-only. Follow-up S3B-6 with S4-4. |
| IMMUNE popup behind HP bars | **Confirmed in a real capture** (`stun_crowd` at 0.85 s, 1280x720): the word renders as "IMMUE" with a red HP bar across it and bars of neighbours over it. Cause: `DamageNumber.tscn` is `no_depth_test` at default render priority, the HP bar material has `render_priority = 10`, so bars always draw over text. Follow-up S3B-2 (ux-designer, Slice 5 bar work). |
| Per-frame allocations in star orbit and telegraph | Star orbit (`PooledEffect.step`) and `set_progress`/`_apply` allocate nothing (Vector3 and float values only). The telegraph update reads stored arrays, no new ones. Two small per-frame costs found: `Player._update_aoe_telegraph` calls `EffectPool.for_world(get_parent())` every frame of the 0.45-0.6 s wind-up (builds a NodePath), and `StatusEffectManager.is_stunned()` iterates `_active.values()`, which allocates an Array on every call, and `Enemy._physics_process` calls it for every enemy every physics frame (also `_process` allocates `expired`/`keys()` while any status is active; pre-existing for Burn). At Slice 5 densities (15 enemies) that is roughly 900 small arrays per second. Follow-up S3B-7. |

## Findings
**Blockers: none.**

**Should-fix**
- **S3B-1 Burn refresh makes the card rule's credit false for Fire cards in real cycling** (owner: gameplay-dev to fix, game-lead to be told). A refresh builds a new `ActiveStatus` and restarts `time_to_next_tick` at 1.0 s, so a Burn refreshed before the second tick lands gets about one tick per cast. Measured through the real manager at 60 fps, steady state per cast: Ember (cast every 1.1 s, rule credits 4 ticks = 8) deals 2 Burn, real cycling DPS (5 + 2) / 1.1 = 6.4 (still above light 5.0); **Fine, Burn Then (3.3 s, credits 5 ticks = 10) deals 6 Burn, real cycling DPS (7 + 6) / 3.3 = 3.94, below the light's 5.0**; heavy 2.0 per proc as logged. The rule is satisfied as the brief defines it ("full duration, no resistance"), so this is a pre-existing defect surfacing, not a 3b-1 miss, but the director's intent ("a card should always feel better than the free attack") is not met for Fine, Burn Then against a single target (it wins on groups). Repro: `tests/unit/slice3b_qa_test.gd::test_pin_burn_refresh_resets_the_tick_timer_so_the_cards_credit_overstates_burn` (a PIN: it asserts the current wrong numbers, so whoever fixes it must update it to Ember 8, Fine Burn Then 10, heavy about 2 to 4). Suggested fix: on refresh keep `time_to_next_tick` (take the longer duration, keep tick phase). That also raises the heavy's Burn and DPS, so game-lead should re-check the 5.8 DPS and D5 after the fix.

**Follow-up (non-blocking)**
- **S3B-2** IMMUNE word clipped by HP bars in a crowd (ux-designer, Slice 5 bar work; set the popup's `render_priority` above the bar's 10 or draw bars depth-tested, which Slice 5 already plans).
- **S3B-3** `AttackController._start` emits `attack_started` before wind-up state and slow (gameplay-dev; pinned; flip the pin when reordered).
- **S3B-4** Re-stun emits no signal (gameplay-dev; only if ux needs it; pinned).
- **S3B-5** `Player._telegraphs` private; add an accessor so tests stop reaching in (gameplay-dev).
- **S3B-6** Scenario flags unvalidated, now including the 3b flags (gameplay-dev with S4-4; capture-only).
- **S3B-7** Two small per-frame allocations listed above (gameplay-dev; fix before Slice 5 density, for example a `_stun_count` int instead of `values()`).
- **S3B-8** `CardDamageRule` lets a NaN damage pass (comparisons with NaN are false). Unreachable from JSON, so low priority (gameplay-dev).
- **N-docs** The ROADMAP 3b-2 brief item 5 and DECISIONS "3b-2 / DR window" text still say a 4 s window and a "0.15 s from the third swing" steady state; the data is 1.5 s as superseded by "After 3b-2" and 3b-3. Add a note next to those lines (game-lead). The 3b-1 table row for the old heavy says "+0.45 wind-up"; dev already corrected it in 3b-2.
- Tinted Golem and cue readability, feel of the 35% slow, 1.5x cap and heavy: playtester territory.
- Remote Debugger noise from the test runner (known).

## Test counts
Before: 306. After: **326** (+20 in `tests/unit/slice3b_qa_test.gd`), three consecutive green full runs after the last test edit (326/326, exit 0), 0 orphans. Test pollution trap: `before_test` calls `CardDatabase.load_all()`. Note for test authors: enemy shots need `get_tree().current_scene` set to Main (a child of root); my helper `_spawn_root_main()` does this and `after_test` clears it.

## Housekeeping done
- `tools/bot_sim.gd`: was unseeded (non-reproducible failures). Now `--seed=N` (default 1), per-room seeds, prints the seed. New `_run_attack_room`: random clicks, haste, Rogue/Wizard heavy, can_act toggling, random stuns and Burn on a random rank; checks NaN and negative timers, click rate and heavy rate under their caps, no boss stun, no stun longer than base x rank, slow never a root and gone when idle, nothing stuck after 3 s idle. Sanity check: with the cap deliberately tightened it reports every room. 200 rooms clean.
- A reference cycle in my own first draft of the `attack_started` pin test leaked 13 objects at exit; fixed by disconnecting the lambda (found by bisecting each test in its own run).

## Not verified
- Windowed feel, readability of stars, tint, the slow, a real mouse (headless plus one 720p capture only; playtester).
- `Scenario` bad-flag crash (by inspection only, not run).
- No mutation testing against deliberately broken game code (I do not edit game source), except that I proved the new bot-sim check and the projectile test's control arm are not vacuous.
