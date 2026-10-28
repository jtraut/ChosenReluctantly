# QA review: Post-milestone polish 1, Slice 4 (skill visuals and targeting readability)

Date: 2026-10-28. Reviewer: qa. Commits reviewed: 42f4599..51fc5b0 (4a 42f4599-91587d5, 4b ba993b4-7755fbf, 4c 7d8817e-51fc5b0).

## Verdict: PASS (with should-fix items)

No blockers. The pool, visuals, Burn flame lifecycle, aim indicator and data validation all hold up under real-scene tests. Two items are real deviations from the criteria text and are listed as should-fix: the projectile lane overstates the real hit width by 0.15 m, and Burn/aim/status data has gaps in validation. A third, an unlogged hit-radius change for ranged enemy shots, needs game-lead acknowledgement. None of them stops 4d moving to playtester.

## Commands run and results
| Check | Command | Result |
|---|---|---|
| Full suite (baseline, HEAD) | `powershell -File tools\run_tests.ps1` | 221/221, 0 errors, 0 failures, 0 orphans |
| Full suite (after my tests) | same, run 3 times | **236 test cases, 0 errors, 0 failures, 0 orphans**, three consecutive runs |
| Editor load | `godot --headless --editor --quit --path .` | no ERROR/WARNING lines |
| Plain run | `godot --headless --path . --quit-after 1200` | engine banner only; no ERROR, WARNING, BUG |
| Bot-sim | `powershell -File tools\run_bot_sim.ps1 -Rooms 20` | `Bot-sim OK: no NaN detected across 20 rooms`. Caster is inside the tree, so casts do go through the pool. |
| Scenario in the real scene | `godot --headless --path . --fixed-fps 60 --quit-after 1200 -- --scenario=card_cast` | all 8 casts print `cooling a -> b OK` (0.6 s to 7.6 s), no ERROR/WARNING |
| Reload soak, HEAD | `tools\run_reload_cycle.ps1 -Cycles 5` x3 plus 35 raw runs | all OK. Objects 1859 and nodes 104 constant from cycle 1 to 5, orphans 0, time_scale 1.0 |

Harness noise: the suite output has two `ERROR: Remote Debugger ... 127.0.0.1:0` lines. They come from `--remote-debug tcp://127.0.0.1:0` in `tools/run_tests.ps1` (gdUnit launch arguments), not from the game, and they are not new in Slice 4. Non-blocking.

## Soak flake (risk 1): pre-existing, benign race, grace is not hiding a bug
- **Before 4b** (worktree at 4c2bfef, `git worktree add`, removed afterwards): 40 runs of 5 cycles, **8 failed (20 percent)**, every one `time_scale 0.25 after beat` at cycle 4 or 5. So the flake predates 4b and 4a/4c.
- **After 4b/4c** (HEAD, grace 250 ms): 40 of 40 passed.
- **Cause**: `Main` starts a real-time `create_timer(duration, ignore_time_scale=true)`, which accumulates frame deltas. `Juice` resets `time_scale` from `Time.get_ticks_msec()` in its own `_process`. The timer can fire one or two frames before Juice's clock check. Restarting inside that gap is safe because `restart_arena()` calls `Juice.reset()` first (`Main._prepare_for_restart`).
- **I replaced the blind grace with a measurement** in `tools/reload_cycle.gd`: it now prints the lag between `game_over_ready` and `time_scale == 1.0` each cycle and fails if it exceeds 50 ms (was 250 ms). Over 35 runs (175 cycles): lag was 0 ms, 6.6 to 7.5 ms (one frame) or 13.5 to 13.8 ms (two frames), **flat across cycles 1 to 5**, never above 14 ms, 0 failures. No accumulation, no stuck scale. If the lag ever grows or exceeds 50 ms the soak will fail.

## Criteria 1-6
| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Seven template visuals (projectile trail/muzzle/impact; cone sweep; aoe ground/flash/burst; dash trail/puffs; heal sparkles; buff rings; Burn flame) | PASS | `TemplateVfx` has every part; `template_vfx_test` covers each; `card_cast` scenario ran all card types with cooling OK. Dodge roll has no trail (logged, not in the criterion). |
| 2 | Element looks are recolor/rescale from data; Water is data only | PASS | `data/pools.json` `visual`. My `test_water_element_is_data_only_end_to_end` swaps in a fixture with Water: `ElementVisuals` returns the Water color, a Water card passes `CardSchema`, aoe and projectile pooled parts take the Water color, and hit-area parts ignore the 1.5 element scale. No code change needed. Residual hardcodes outside Slice 4: `DamageNumber._color_for` only knows `"fire"` (Water numbers would be white). |
| 3 | Aim reticle and direction line; ground markers for aimed skills | PASS | `AimIndicator`, `Player.get_aim_point/get_aim_direction` (read-only, `test_getters_do_not_change_player`), lane and dash path markers. Hidden when dead (also the Game Over state), tested; not leaked across arena frees (my node-count test). Visual taste is playtester territory. |
| 4 | Visuals match hitboxes; test for cone, aoe, projectile | PASS with one finding | `vfx_sizing_test` asserts visual == hit params for all three, and I added real-physics checks. **Finding S4-1**: the projectile *lane* is 0.75 m half-width but the real lateral reach of a floor-level shot is 0.60 m. See below. The ball and the cone/aoe shapes are correct. |
| 5 | Pooled, capped (data), no per-frame allocation, free themselves, no leak, no error if caster/target freed | PASS | Cap 64 from `data/vfx.json` (validated 1..512). My real-scene soak casts every shipped card 25 rounds with the cap forced to 14: active never above 14, created never above 14, no projectile left after 4 s, pool back to 0 and node count flat. Caster freed immediately after cone/aoe/projectile/heal, player freed mid-dash, enemy killed by its own Burn tick, Main freed with 4 burning enemies x3 arenas: no errors, no orphans, nodes flat. Persistent flames are not evicted by bursts (existing test); stale handles cannot stop recycled effects (existing test). `_process` loops (`EffectPool.advance`, `PooledEffect.step/_apply`, `AimIndicator._process`) build no arrays or dictionaries; only Vector3/Color value types. |
| 6 | Hold-to-preview: proposal only | PASS | DECISIONS 2026-10-28, no code. |

## Hidden behaviour changes (risk 2)
| Change | Verdict |
|---|---|
| Projectile hit radius now reads data | Confirmed and **broader than logged**. Flaming Nonsense 0.25 to 0.3 is logged. But `Enemy.gd` has always sent `"hit_radius": 0.3` (checked at 42f4599^) and the scene default is 0.25, so **ranged enemy shots also grew 20 percent** in hit radius. Not in DECISIONS. Pinned in `test_projectile_hit_radius_now_comes_from_data_for_cards_and_ranged_enemies`. Finding S4-2. |
| Player hit flash now works | Confirmed, visual only. Cosmetic change to the player material (duplicated, assigned as override). No damage path touched. |
| Lethal-hit tween killed on death | Confirmed. My test hits a dead player again (as the soak does), waits through the collapse, and asserts the body ends grey (0.25) with the aim indicator hidden. |
| `AttackController.set_auto` | Duplicates the def before writing; shared table not mutated (existing test). Only called by the scenario. |
| Two visual-only lines in `_execute_projectile`/`_execute_dash` | Confirmed visual only: projectile lane (player team only) and dash path/start. Damage, knockback and movement inputs are unchanged. `start_forced_move` gained an optional arg. |
| Dark void background, floor | Floor still `Vector3(40, 1, 40)` (`test_arena_floor_is_still_40_by_40`); only the Environment background color changed. |
| Hit queries untouched | `test_hit_queries_do_not_depend_on_visual_sizing` asserts `MeleeQuery`, `Hurtbox`, `AttackController` never reference `VfxSizing`, `VfxConfig` or `TemplateVfx`. |

## Pool and Burn (risk 3)
Cap 64, oldest non-persistent effect is recycled, persistent only when nothing else is running, generation counter guards stale handles. Burn flame ends on expiry, on `tree_exiting`, on owner freed (follow by instance id), and when the owner dies to its own tick (tested with a real MeleeChaser at 1 HP). On arena reload the pool is a child of Main and is freed with it (3 arenas with 4 burning enemies each, node count flat; the reload soak is also flat). Non-blocking nit: `Player._apply_forced_move` calls `EffectPool.for_world(get_parent())` every 0.04 s while dashing, which builds a NodePath each time; negligible.

## Data (risk 4)
- Validated with tests: `data/vfx.json` (cap, reach, colors, marker ranges), `data/ui.json` `aim` (types, ranges, alpha, dot count), `data/pools.json` (element needs a visual, color, scale 0.1 to 5, neutral required). New in `slice4_qa_test`: the shipped files validate; 13 deliberately bad values (alpha 1.5, zero duration, negative width, string where number, bad color, cap 513, dot count 100, null, missing visual) each return a clear message. Invalid files push an error and fall back to defaults.
- **S4-3**: `statuses.json` burn `visual` (`kind`, `size`) has **no validation at all** (there is no status schema). A typo such as `"kind": "flam"` or `"size": "big"` silently shows no flame or a zero-size one. Breaks the fail-loud rule.
- **S4-4**: `data/scenarios.json` flags (`enemies_idle`, `disable_auto_attack`, `aim_preview_distance`) are read with `bool()`/`float()` coercion and no schema. Capture-only, low risk.
- `VfxConfig.DEFAULTS.max_simultaneous` is still 48 while the data says 64 (follow-up; only matters when the file is invalid).
- The ROADMAP hint that scenario flags are "schema-validated" is not accurate.

## Test counts
- Before: 221. After: **236** (+15 in `tests/unit/slice4_qa_test.gd`), 3 consecutive green runs, 0 orphans.
- New fixture: `tests/fixtures/pools_water/pools.json`. `tests/unit/cast_markers_test.gd.uid` was untracked (ux-designer omitted it); committed.
- Required tests per ROADMAP: visual-vs-hitbox (cone/aoe/projectile) exists in `vfx_sizing_test`, plus my real-physics lane check; pool cap and no leak over N casts (existing synthetic plus my real-card, real-scene soak); caster/target freed mid-effect (existing plus mine for 4 templates, dash and Burn); headless run clean (done above).
- Test pollution note: other suites leave `CardDatabase` pointed at fixture cards, so any suite using the shipped cards must call `CardDatabase.load_all()` first (mine does in `before_test`). Not a defect, a trap.

## Findings
**Blockers: none.**

**Should-fix**
- **S4-1 Projectile lane overstates the hit width** (owner: ux-designer/gameplay-dev, game-lead decides). `VfxSizing.projectile_lane_half_width(r) = r + 0.45`. Shots launch at the caster origin (y = 0) and the hurtbox capsule's lowest sphere centre is at y = 0.45, so the real lateral reach is sqrt((r + 0.45)^2 - 0.45^2): 0.60 for r = 0.3, lane draws 0.75. Reproduce: `test_projectile_lane_width_vs_real_lateral_hit_reach_is_pinned` (enemy at lateral 0.55 is hit, at 0.65 is not, lane is 0.75). Fix options: use the sqrt formula in `VfxSizing`, or launch projectiles at body height (gameplay change, also matters for hitting short enemies). Criterion 4 says a visual that lies is a bug; this is a small, low-alpha, 0.3 s marker, so I did not block. The test pins the current numbers and must be updated by whoever fixes it. The same sphere-vs-capsule effect makes cone/aoe shapes up to about 0.03 to 0.05 m generous at small radii; negligible.
- **S4-2 Ranged enemy shots hit 20 percent wider (0.25 to 0.3), unlogged** (owner: gameplay-dev to log in DECISIONS and ideally move the hardcoded 0.3 and the 60 degree cone angle in `Enemy.gd` into data; game-lead to acknowledge the balance shift; playtester to watch shooter difficulty).
- **S4-3 Status `visual` block unvalidated** (owner: gameplay-dev; add a `StatusDatabase` validator for `visual.kind` in {flame} and `size` > 0 plus a bad-fixture test).

**Follow-up**
- S4-4 Validate scenario flags (low priority).
- `VfxConfig.DEFAULTS` 48 vs data 64.
- Water damage numbers: `DamageNumber._color_for` hardcodes fire only (pre-existing).
- Enemy shots and player physical shots share the neutral cream color (ux/playtester already noted s4-a); tall golems hide ground shapes (s4-b); cone sweep 0.25 s constant (s4-c); dodge roll has no trail (s4-d); real-mouse and 1440p reticle check (s4-e).
- `tools/run_tests.ps1` remote-debug port noise in the output.

## Housekeeping done
- `tools/reload_cycle.gd`: measured lag and a 50 ms limit instead of a blind 250 ms grace; prints lag per cycle.
- Committed `tests/unit/cast_markers_test.gd.uid`.

## Not verified
- Windowed visuals, readability, feel, a real mouse, resolutions other than the capture sizes (headless only; playtester and director).
- The earlier harness noise was not re-checked on commits before Slice 4 (cause is clear from the script arguments).
- No mutation testing of the new tests against deliberately broken game code (I do not edit game source).

## Re-check 2026-10-28 (targeted: S4-1, S4-2, S4-3)

Commits checked: 5807412, ad3db20, b5180a8. Suite after adding my pins: 247/247 pass, exit 0 (run via `tools\run_tests.ps1`). `tools\run_reload_cycle.ps1 -Cycles 5`: RELOAD CYCLE OK (orphans 0, time_scale 1.0, no engine ERROR/WARNING lines).

- **S4-1: RESOLVED.** `lateral_reach(0.3) = 0.60`; the existing physical pin now hits at 0.55 and misses at 0.65 (green). Added `tests/unit/slice4_recheck_test.gd`: real-physics pins for cone (range 1.8, drawn 2.205: hit at -0.05, miss at +0.05) and aoe (radius 2.5, drawn 2.9155: same). Both green. `git diff` of 5807412 touches no launch height and no hit query (only `VfxSizing`, `VfxConfig`, data/vfx.json cap, tests). Doc nit: DECISIONS says the aoe draws 2.906; the real value is 2.9155 (sqrt(2.95^2-0.45^2)). Code is right, the log number is a typo.
- **Known limit, measured:** one global dy = 0.45 (MeleeChaser). RangedShooter (r 0.4, low centre 0.4): the lane for a 0.3 shot is drawn 0.600 vs real 0.574, i.e. 2.6 cm too wide (cone range 1.8: about 3 cm). Negligible. **FireResistantGolem is not a capsule: it is a 1.2 x 1.9 x 1.2 box whose bottom is at the floor**, so a floor-level query touches the box face directly. Real reach is about q + 0.6 (face), so the 0.3 shot lane is drawn 0.60 vs real about 0.90 (30 cm too narrow), cone range 1.8 drawn 2.205 vs real about 2.4 (about 20 cm too narrow), aoe 2.5 drawn 2.9155 vs real about 3.1. This UNDERSTATES the hit area against golems (safer direction than before, but still a visual that does not match the hit). Not blocking; logged as new finding N1 below.
- **S4-2: RESOLVED.** `data/enemies.json` = 0.3 and 60.0 (unchanged); `EnemyConfig.validate` rejects missing/non-number/out-of-range values and falls back to DEFAULTS with push_error; `Enemy.gd` reads `EnemyConfig.projectile_hit_radius()` and `melee_half_angle_degrees()`; `enemy_config_test.gd` and the 0.3 pin test green.
- **S4-3: RESOLVED.** `StatusDatabase.validate_entry/validate_table` check the `visual` block (kind in {flame}, size number in (0,5], color hex). Bad fixture (6 entries incl. `kind: "flam"`, string size, zero size, bad color) all fail with entry-prefixed messages; bad entries are treated as missing (fail loud, not silent defaults). Shipped `burn` validates and the Burn flame tests in `slice4_qa_test.gd` still pass.

New findings (non-blocking):
- N1: ground-shape reach understates the hit area against the Golem box hurtbox (above). Suggest a per-enemy or per-shape-kind dy, or accept and note in the Slice 5 balance pass.
- N2: DECISIONS aoe example number typo (2.906 vs 2.9155).

**Overall Slice 4 verdict: PASS.** All three should-fix items RESOLVED.
