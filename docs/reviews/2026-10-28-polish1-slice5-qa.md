# QA review: Post-milestone polish 1, Slice 5 (wave density, enemy readability, HP bars)

Date: 2026-10-28. Reviewer: qa. Commits reviewed: 3af4538..642b1ee (5a 3af4538-8e05395, 5b 058d3dd-642b1ee), HEAD c128871 at start.

## Verdict: FAIL (one blocker, fix is two lines)

Everything the slice set out to build works and is well tested: the cap is never exceeded, waves come from data, the wedge and lane telegraphs are exactly the real hit (verified against live physics), the walls hold at 80 m/s, the golem capsule leaves no corner gap, and all three wave-sim modes are clean. The FAIL is one required check: **the old `run_bot_sim.ps1` has been broken since 058d3dd (5b) and printed "Bot-sim OK" with exit 0 while the script did not even compile** (S5-1). The brief lists the old bot-sim as a required test, so the slice cannot pass. The fix is small and I proved it works (below). Re-check after it lands should be a PASS with the should-fix items listed.

**Suite state, stated plainly so nobody "fixes" it by deleting a test:** at HEAD c128871 the suite was **378/378 green**. After qa it is **412 tests, 411 pass, exactly 1 fails on purpose**: `slice5_qa_test.gd::test_old_bot_sim_script_compiles_and_runs_without_script_errors` is the regression test for S5-1 (fails before the fix, passes after). It goes green when S5-1 is fixed. Do not delete or weaken it.

## Definition of done
| Check | Command | Result |
|---|---|---|
| Editor load | `godot --headless --editor --quit --path .` | 0 error/warning lines |
| Startup | `godot --headless --path . --quit` | banner only |
| 20 s headless run | `--quit-after 1200` | 0 lines matching error, warning, bug |
| Scenarios, 600 frames each, `--fixed-fps 60 -- --scenario=` | waves, bar_modes, pointy_shot, stun_cancel, attacks, stun_crowd, card_cast, targeted_aoe, hp_bars | 0 lines for all nine (all four new 5a/5b scenarios included) |
| Full suite | `powershell -File tools\run_tests.ps1` | **PASS at c128871: 378/378.** After qa: 412 tests, 411 pass, 1 intentional red (S5-1), 0 errors, 0 orphans, exit 100 |
| SceneSelfCheck | runs on every `Main._ready`; also `main_scene_smoke_test`; now also checks every enemy id in the wave table has a scene | silent at startup, smoke test green |
| Reload soak | `tools\run_reload_cycle.ps1 -Cycles 5` | RELOAD CYCLE OK: objects 1845, nodes 93, orphans 0, time_scale 1.0, lag 6.5 to 13.5 ms. Constant across cycles |
| Old bot-sim | `tools\run_bot_sim.ps1 -Rooms 200` | **BROKEN since 058d3dd** (see S5-1). Printed OK before my change to the script; now exits 1 |
| Wave bot-sim | `tools\run_wave_sim.ps1` | OK in all modes (numbers below) |

**Expected ERROR lines in suite output** (so a grep does not surprise anyone): the known runner pair (`The remote port number must be between 1 and 65535`, `Remote Debugger: Unable to connect`), plus two intentional ones from my failure-path asserts (`EnemyConfig: enemy id 'nope_enemy' has no scene...` and `data/ui.json hp_bars invalid: visibility_mode must be one of [...]`), each caught by `assert_error`. At c128871 the suite also had a third, a real engine ERROR (`!is_inside_tree()` from `damage_numbers_5b_test.gd::test_merge_hit_sums_and_extends_life`); I fixed it (see test changes).

## Bot-sim numbers (headless, seeded, shipped `waves.json`, cap 12)
| Mode | Command | Result |
|---|---|---|
| Normal (real HP, bot kites and fights) | `-Seed 300 -Seconds 180 -Runs 3` (time scale 3) | all 3 survived. HP lost 54 / 32 / 48. Kills 72 / 87 / 75. **Alive peak 11 / 12 / 12, mean 6.2 / 6.0 / 6.6.** Stages opened 14 / 16 / 15. Max stall 18 / 8 / 16 s |
| God (9999 HP, exercises the whole table) | `-Seed 400 -Seconds 240 -Runs 2 -God` | **Alive peak 11 / 11, mean 6.6 / 6.1.** Kills 100 / 102. Stages opened 19 / 19. Max stall 14 / 16 s |
| Idle (never moves, real time) | `-Seed 500 -Seconds 60 -Runs 3 -Idle -Scale 1` | died at 7.7 / 8.6 / 7.6 s, alive peak 4, 0 kills (auto light attack alone does not reach) |
| Old bot-sim | `-Rooms 200` | **does not compile** (S5-1) |

No crash, NaN, cap violation, out-of-arena position, or soft lock in any wave run (the tool fails on any ERROR/WARNING line and on its own checks; all exit 0). Stall is "time with no stage opening and no kill", at most 18 s, well under the 45 s alarm. CPU frame cost with 12 alive: process 4.3 ms, physics 3.8 ms per rendered frame (headless, excludes rendering); `_attack_has_target` 7.4 us per call. The cap binds at peaks (12 reached in 4 of 5 competent runs), so the "never over the cap" check is not vacuous in play. An idle player dies in 8 s, a competent bot survives: this is an upper bound for a human, so the density feel needs the director live.

## Per-criterion table
| Criterion / required item | Result | Evidence |
|---|---|---|
| 1. Spawner holds about 6 to 15, staged, cap and table are data | PASS | `waves.json` validated by `WaveConfig` (cap range 6 to 15). **Added** fuzz test: 120 random valid tables x 3000 steps with random kills: alive never over cap, at most one spawn per step, queued enemies never vanish. Also shipped table over 10 minutes, one kill per 2.5 s: peak stays within cap. Blocked queue keeps exact stage composition (2 chasers, 3 shooters, 1 golem) after unblocking. Stage content follows the data for each enemy id. Shipped first three stage openings match the file. Observed mean alive is about 6 to 6.6 with peaks 11 to 12: it "holds about 6 to 15" only at peaks (see director question) |
| 2. Each enemy reviewed vs the density principle | PASS | DECISIONS 5a has per-type telegraph, role, punish window; cheap fixes done (wedge, lane); F-E1 to F-E5 listed. No gap found |
| 3. Enemy damage vs player HP and dodge window | PASS | table in DECISIONS matches scene values (chaser 5, shooter 4, golem 9; player 30 HP; roll 0.25 s i-frames). No balance edits. Idle bot dies at 7.7 to 8.6 s, matching the logged 8.5 to 9.4 s |
| 4. HP bar default as data, depth-tested, smaller, consistent size | PASS | modes in data; shipped `always_alive`; width 1.2, height 0.16; shader has no `depth_test_disabled`, writes no ALPHA (opaque pass); ortho camera pins constant size. **Added** exhaustive truth table: 8 modes (4 shipped + 4 bogus) x dead x damaged x 5 fills x 4 ranks = 640 cases vs an independent oracle; invalid mode falls back loudly (asserted via `assert_error`); live rank test; dead enemy hides the bar in every mode. Director call D7 (default) pending |
| 5. Bot-sim at new density | **FAIL for the old sim, PASS for the new** | wave sim clean (above). `run_bot_sim.ps1` broken by 5b (S5-1) |
| Spawn grace: no attack for the first 1.5 s | PASS | **Added** live test: chaser inside melee range and shooter inside preferred range, 87 physics ticks (1.45 s): no wind-up starts, no HP lost, no projectile; after the grace the chaser attacks |
| Spawn ring clamp: nobody inside walls or the player | PASS for walls, **NOT MET for the player in a corner** | 12,000 samples over 8 player positions: always inside +-19 and finite. But with the player in an arena corner a spawn can come out 0.54 m from the player (about 0.6% of spawns come under `spawn_distance_min`). Hit-safe thanks to grace, still overlapping bodies. S5-4, PINned |
| Arena walls hold, incl. dash and knockback at speed | PASS | **Added**: forced move 80 m/s into the east wall for 1 s, enemy knockback 120 m/s into two other walls, and ten dashes into a corner: nothing past 20, nothing fell. (Projectiles have mask HURTBOX only, so shots pass through walls: harmless.) |
| Golem capsule hurtbox matches its real hits (N1) | PASS | existing test pins capsule numbers and a live sphere test at the drawn edge (+-3 cm). **Added** corner probe below |
| Capsule hurtbox inside box collider: missed corner hits? | PASS | Worst case is a player pressed into the box CORNER (half diagonal 0.85 + player radius 0.4 = 1.25 m from the centre). The shortest melee in data (light 1.8, shortest card cone 1.8, shortest aoe 2.2) reaches sqrt((1.8+0.45)^2 - 0.45^2) = 2.2 m. Margin about 0.9 m. Test reads the real scene shapes and the data, so a smaller card range would fail it |
| HP bars: opaque pass, no z-fight, correct on reload | PASS (stills and code) | shader code check; reload soak clean, bars come from a static shared material; one windowed 1280x720 capture of the stress `waves` scenario at 5 s shows bars layered cleanly in the clump, no flicker in the still. Z-fighting in motion not verified |
| Bar rank read live | PASS | rank set after `_ready` is read by `rank()`; visibility updates on the next health event (not at the moment the rank changes: no real case today) |
| `render_priority` order: numbers, then IMMUNE above bars | PASS | **Added**: bar 10 < numbers 20 < IMMUNE 21, IMMUNE outline above number text, within -128..127. Note the bar is opaque so it always draws before the transparent labels regardless of priority |
| Damage numbers: merge and cap 16 | PASS | **Added**: merge sums (3+4 -> 7), same place and different type does NOT merge, a 1000 killing blow is added into the total, 100 far-apart hits never exceed 16 in the list or in the tree |
| Juice reset clears the list; no leak over a long run | PASS | reset empties the list; 3000 hits with forced expiry and frame passes: list peak <= 16, tree nodes <= 16, no errors from freed nodes in the typed-loop prune. Edge values (0, 0.0001, -5, 1e6, 1e12) show no error |
| Merging never hides a killing blow or mixes types | **PASS on mixing, FAIL on a rare eviction** | S5-5: at the cap the oldest-created number is evicted even if it was just merged into. Repro in `test_pin_cap_eviction_can_free_a_number_that_just_took_a_killing_blow` |
| Telegraphs end on stun, enemy death, player death | PASS | **Added**, live: melee wedge hidden after stun and after player death; ranged lane `is_running` false after stun, player death and enemy death. (Reload: freed with the scene, soak clean.) |
| Wedge and lane are the real hit | PASS | **Added**, live physics: wedge drawn to `lateral_reach_vs_player`, and a player 4 cm inside is hit while 4 cm outside is not, straight ahead and at +-(60 deg -/+ 3 deg); the fan mesh AABB equals the reach and the half-angle width. Shooter lane: a shot with the player 4 cm inside the lane half-width hits, 4 cm outside misses, both sides. No lying telegraph |
| Stun-cancel ring | PASS | **Added**: no ring when stunning an idle enemy, exactly one ring when stunning a live wind-up, none on a refresh |
| Team tint: player never tinted; enemy elemental shots blended | PASS | player colour equals the plain element colour; enemy shot differs for physical and fire; element blend equals `lerp(plain, tint, element_mix)` (existing); player and unknown team have no tint |
| Performance: per-frame allocations in new code | PASS with two nits | Telegraph update (`show_windup`) and `DamageNumber._process` allocate nothing. **`WavePlan.step` returns a new `Array[String]` every call and `EnemySpawner._process` calls it every frame** (follow-up S5-6). `UiConfig.damage_numbers()` deep-duplicates and validates on every hit (per hit, not per frame, follow-up S5-7) |
| Data validation fails loud | PASS with gaps | waves.json: 25 more bad shapes plus an empty config, all rejected. enemies.json `scene`: 7 bad values reject. ui.json `damage_numbers`: every key x 5 bad values. vfx.json: every `MARKER_KEYS` key x 5 bad values, alpha > 1, new hurtbox keys, team tints. Scenario schema: `dense_waves`, `wave_seed` bad fixtures; all 10 shipped scenarios validate. Gaps: S5-2, S5-3 below |

## Findings
**Blocker**
- **S5-1 `run_bot_sim.ps1` broken by 5b, and it lied** (owner: ux-designer for the source fix, qa done for the tool). `UiConfig.validate_hp_bars` (058d3dd) references `EnemyHpBar.MODES`; `EnemyHpBar` references `Enemy` (5a); `Enemy` calls the `Juice` autoload. `tools/bot_sim.gd` runs as `-s`, where autoloads do not resolve at compile time, so the chain `bot_sim -> CardSlotController -> CardDatabase -> CardSchema -> UiConfig -> EnemyHpBar -> Enemy -> Juice` fails: "Identifier not found: Juice", then every UiConfig call returns Nil. The script then ran its rooms against a broken `CardSchema` and printed **"Bot-sim OK: no NaN detected"**, exit 0. Bisected in worktrees: clean at 3af4538^ and 8e05395, broken at 058d3dd. Repro: `powershell -File tools\run_bot_sim.ps1 -Rooms 2` at c128871 (before my script change). **Proven fix, not committed** (done in a throwaway worktree): add `const HP_BAR_MODES: Array[String] = ["always_alive", "after_damage", "hidden_at_full", "elite_boss_always"]` to `UiConfig`, use it in `validate_hp_bars`, and make `EnemyHpBar.MODES = UiConfig.HP_BAR_MODES`; with exactly that change `-s res://tools/bot_sim.gd -- --rooms=20` prints `Bot-sim OK` with no script errors. Guard rails I added: `run_bot_sim.ps1` now fails on any ERROR/WARNING line (it can no longer pass silently), and the regression test above runs the real `-s` script in a child process.

**Should-fix**
- **S5-4 corner spawns can land almost on the player** (owner: gameplay-dev; bundle with S5-1; PIN `test_pin_corner_spawn_can_land_almost_on_the_player`). With the player at a corner of the clamp, `_random_spawn_position` tries 8 angles and keeps the farthest, which can still be 0.54 to 3.7 m away (measured 0.54 / 3.37 / 3.74 / 5.7 m at the four corners, seed 11). The brief says nobody spawns inside the player; this is not met, but the 1.5 s grace keeps it harmless to HP. Fix: re-roll candidates under `spawn_distance_min`, or walk along the wall.
- **S5-5 the merge-at-cap eviction can free a number that just took a killing blow** (owner: ux-designer; PIN `test_pin_cap_eviction_can_free_a_number_that_just_took_a_killing_blow`). Juice evicts oldest-created and a merge does not reorder the list. Needs 16 live numbers (an AoE into a crowd can do that); the killing blow vanishes the same frame. Fix: move a merged number to the back of `_live_numbers`, or evict the most idle one.
- **S5-2 `validate_hp_bars` checks only `visibility_mode`** (owner: ux-designer; PIN `test_pin_hp_bar_block_validates_only_the_mode`). `hp_bars.render_priority: "x"` (becomes 0 through `int()`) and `width: 0` validate silently. Criterion "every new key fails loud" is not met for `hp_bars.render_priority`. Validate every key of `DEFAULT_HP_BARS` the way `validate_damage_numbers` does, and bound render priorities to -127..126 (IMMUNE adds 1).
- **S5-3 `waves.json` `arena_half_extent` accepts up to 200 but the walls are fixed at +-20 in `Main.tscn`** (owner: gameplay-dev; PIN `test_pin_arena_half_extent_is_not_checked_against_the_walls`). A typo spawns enemies outside the walls, unreachable. Cap the validator at 19.5 or read the wall box from the scene.

**Follow-up (non-blocking)**
- **S5-6** `WavePlan.step` allocates an `Array[String]` every frame (`EnemySpawner._process`). At most one spawn per step, so return one id or `""` (gameplay-dev).
- **S5-7** `UiConfig.damage_numbers()` merges, validates and duplicates on every hit (per hit, not per frame); cache it (ux-designer).
- **S5-8** `README.md` lines 51 to 53: the wave-sim commands read `tools<CR>un_wave_sim.ps1`, because `\r` in the text became a carriage-return byte. The commands do not run when copy-pasted, and git treats the file as binary (`i/-text`), so any fix shows as a 126-line whole-file diff. Not fixed by me (outside qa paths). Owner: whoever next edits README (gameplay-dev); replace the three `0x0D` bytes with `\r` and expect a one-time line-ending normalisation.
- **S5-9** `EnemyHpBar` visibility is recomputed only on health, death and init events, so a rank changed later shows on the next hit, not at once. No real case today (ux-designer, low).
- **S5-10** `EnemyConfig.validate_enemies` checks that a `scene` exists but not that its root is an `Enemy` (a wrong scene is an instantiate error at spawn). Low (gameplay-dev).
- Three `.uid` files are untracked and not mine: `tests/unit/damage_numbers_5b_test.gd.uid`, `tests/unit/slice5a_test.gd.uid`, `tools/wave_sim.gd.uid` (owners: ux-designer, gameplay-dev; commit them as `wave_plan_test.gd.uid` was).
- Remote Debugger noise from the runner (known).
- Observation, not a defect: the mean competent-bot alive count is 6.0 to 6.6, with the cap hit at peaks.

## Tests added or changed
- **New** `tests/unit/slice5_qa_test.gd`: 34 tests (+ `.uid`). Sections: cap and staging (7 incl. fuzz and shipped table), data validation (waves 25 bad shapes, enemies scene 7 bad values, ui damage numbers, vfx keys, scenarios), spawn ring, spawn grace, walls, N1 corner, telegraph truth and end-of-life, stun-cancel ring, bar truth table, invalid-mode fallback, live rank, render priority order, damage-number merge/cap/reset/long-run/edge values, and the bot-sim regression. Four PINs: S5-2, S5-3, S5-4, S5-5. One intentional red: S5-1.
- **Changed** `tests/unit/damage_numbers_5b_test.gd`: added one `add_child(number)` line in `test_merge_hit_sums_and_extends_life`. The test constructed a `Label3D` outside the tree and `show_amount` read `global_position`, logging a real engine ERROR in every suite run. Assertions are unchanged.
- **Truth-table oracle note:** my oracle says a bar shows for `elite_boss_always` when the rank is anything but "normal", matching the code (`rank != normal`). The code therefore fails open for an unknown rank string (`StatusEffectManager.rank` is a free string). Acceptable: ranks are validated to normal, elite, boss on load, so an unknown rank cannot occur from data.
- **Changed** `tools/run_bot_sim.ps1`: fails on any ERROR/WARNING in the output (see S5-1).
- **Changed** `docs/CHANGELOG.md`: see below.
- A test-writing trap worth remembering: a stopped pooled effect is recycled at once (the stun stars reuse the freed lane node), so assert `EffectPool.is_running(effect, generation)`, never `effect.active`.

## Changelog check
Slice 5 entries are present and accurate. I checked every claim against the commits: staged waves, cap 12, four stages, 3 s first wave, 1.5 s grace (3af4538, 8e05395); wedge and lane (079e1f4, caab2c0); walls found by the sim (079e1f4, which holds the Main.tscn walls); bar size and depth (caab2c0, 8e05395); golem capsule with the body and movement collision as described (caab2c0); damage number size, merge and cap, IMMUNE, cast reads, stun ring, bar modes with D7 (058d3dd, 3ae40b7, 39c03e6, b50aa0c, bff7581). All hashes exist and touch the described files. One factual nit fixed minimally: the date heading named only Slice 4 and 3b, so I added "Slice 5 waves and readability" to the 2026-10-28 section header. No other change.

## Not verified
- Z-fighting between overlapping bar quads at near-equal depth **in motion** (one still at 1280x720 only), 1080p or 1440p, windowed feel, a human fighting 12 enemies (playtester and director).
- Reload during a live telegraph (the soak reloads after player death, which already cancels telegraphs; scene teardown frees the pool, wedge and lane with it).
- No mutation testing against deliberately broken game code (I do not edit source). The bot-sim fix was verified in a throwaway worktree, not in the repo.

## Director questions
- **D7** HP bar default: still the director's call (`always_alive` shipped; ux suggests `elite_boss_always`). Nothing in QA changes that; today every enemy is rank normal, so three of the four modes look identical in real waves.
- **D6** golem wind-up 0.45 -> 0.7 s: unanswered, not applied.
- Does a competent-bot mean of 6.0 to 6.6 alive, with peaks of 11 to 12, count as "holds about 6 to 15"? The cap is a ceiling the stage gates reach only at peaks. If "about 6 to 15" should feel like 10 or more most of the time, that is a data change in `waves.json` (gates and stage sizes), not code.

## Re-check 2026-10-28 (targeted, after fix pass e100f09..b814bfd)

### Overall Slice 5 verdict: PASS
All blocker and should-fix items are resolved, the intentional red test is green through the real fix, and nothing else changed.

### Per-item
| Item | Commit | Verdict | Evidence |
|---|---|---|---|
| S5-1 old bot-sim compile | e100f09 | RESOLVED | `UiConfig.HP_BAR_MODES`, `EnemyHpBar.MODES = UiConfig.HP_BAR_MODES`. `run_bot_sim.ps1 -Rooms 20` prints "Bot-sim OK", exit 0, no ERROR lines. The script fails on any ERROR/WARNING line (my change from the review), so the OK is trustworthy. `test_old_bot_sim_script_compiles_and_runs_without_script_errors` PASSED in the real suite run (child `-s` process), 0 failures. |
| S5-2 hp_bars validation | 8634b2b | RESOLVED | `test_hp_bar_block_validates_every_key` covers 14 keys with bad values, requires a case for every key in `DEFAULT_HP_BARS`, and checks edges 126 / -127 pass, 127 / -128 fail. Correct new behaviour (rejects, was accepted). |
| S5-3 arena_half_extent | 24480cc | RESOLVED | Cap 19.5 (wall 20.0 minus 0.5). 19.5 passes, 19.6 and 60 fail; a second test reads the four wall boxes in Main.tscn and fails if the constant drifts. |
| S5-4 corner spawns | 6115702 | RESOLVED | Flipped test: 6 spots (4 corners, 2 edges) x 1500 spawns, closest >= spawn_distance_min (9.0); ring test now asserts exactly 0 under minimum. Both pass. |
| S5-5 merge eviction | 20483c7 | RESOLVED | Flipped test asserts the merged number survives and the second-oldest is freed. Correct new behaviour. |
| S5-7 damage_numbers cache | c3c67f6 | RESOLVED | `is_same` test; read-only by convention (no caller mutates it; a bad block errors once). |
| S5-6 per-frame allocation | 1b6e725 | RESOLVED | `step_one` returns one id or "", spawner uses it, `step` kept as wrapper with an equivalence test. Cap fuzz test still green. |
| S5-10 scene root check | c9925fb | RESOLVED | Main.tscn (both paths) rejected as an enemy scene; the shipped three still validate. |
| S5-8 README | 26c0c3a | RESOLVED | No CR bytes (0), `git ls-files --eol` = `i/lf w/lf`, text again. -w diff is 3 lines. The wave-sim commands pasted and ran (see below). |
| .uid files | f82b0a8 | RESOLVED | Tracked; `git status` clean before my edit. |
| D6 golem 0.7 s | acc26a4 | RESOLVED | See below. |
| enemy_hp_bar_test edit | 2669d26 | RESOLVED, assertion not weakened | It is strengthened. Because `validate_hp_bars` now needs a full block, the old `{"visibility_mode": x}` fixtures would fail for the wrong reason (missing keys). The new helper builds a full default block and varies only the mode, so valid modes still assert empty and bad modes ("sometimes", 3) assert non-empty for the right reason. Same assertion count. |

### Extra checks
- **No other value changes:** `git diff cdede75..HEAD -- data scenes` is exactly one line: `telegraph_duration = 0.7` in `scenes/enemies/FireResistantGolem.tscn`. No `data/` file changed. Chaser stays 0.45 (asserted).
- **Golem live check (new test, mine):** `slice5_qa_test.gd::test_golem_wedge_shows_for_the_whole_0_7_s_wind_up_and_the_hit_lands_at_0_7_s`. Real physics ticks in Main: wedge visible on every frame before the hit, HP drops at 0.7 s (within one tick). PASSES. The fix pass's own test only called `_update_wedge` once at 0.02 s remaining, so this closes the "hit lands at 0.7" gap.
- Full suite: **417/417** (416 from the fix pass + my 1 new), 0 errors, 0 failures, 0 orphans, exit 0. Only the four expected ERROR lines appear (runner remote-port pair, plus the two intentional `assert_error` ones).
- 20 s headless run (`--quit-after 1200`): 0 lines matching error, warning or bug. SceneSelfCheck runs on every Main._ready and is silent; `main_scene_smoke_test` is in the green suite.
- Reload soak `-Cycles 5`: RELOAD CYCLE OK, orphans 0, objects 1843 (baseline 1826), nodes 93, time_scale 1.0.
- `run_bot_sim.ps1 -Rooms 20`: OK, exit 0.
- Wave sim, all exit 0, "WAVE SIM OK", no ERROR/WARNING: normal `-Seed 300 -Seconds 180 -Runs 3`: survived, alive max 12, mean 5.7 to 7.4, stages opened 14 to 16, max stall 14 s (HP lost 64 / 20 / 20-class; kills 74 / 85). God `-Seed 400 -Seconds 240 -Runs 2 -God`: alive max 12, mean 6.7, stages opened 20, max stall 11 s, kills 110. Idle `-Seed 500 -Seconds 60 -Runs 3 -Idle -Scale 1`: died at 7.7 / 8.6 / 7.5 s, 0 kills (unchanged from before; the idle player is not affected by the golem change since it dies to chasers and shooters first).
- Changelog check: fix pass and D6 entries are present and accurate (D6 numbers 2.25 -> 2.5 s cycle and 4.0 -> 3.6 DPS match DECISIONS; "min 9 m" matches `waves.json`; hashes exist and touch the described files). No edit needed.

### New findings
None blocking. Non-blocking: the D6 golem wind-up remains a scene export while every other combat number for enemies is... also a scene export (so no inconsistency); the fix pass already flags moving them to `data/enemies.json` as a later pass. S5-9 (bar rank change shows on next hit) is still open by design (ux, low).

### Still unverified
Z-fighting in motion, 1080p+, and a human fighting 12 enemies (playtester / director), as before.

### Director questions
D7 (bar default) and the D6 revert option (reply B) remain with the director; no new ones.
