# BD3a re-check (qa, 2026-11-09)

Reviewer: qa. Build: HEAD f664be6 (ux a614f76; gameplay-dev e4ef264, a9d56fc, bf0d44c), plus my tests-only commit. Windows, Godot 4.7.2 console build via `GODOT_BIN`. Follows `docs/reviews/2026-11-09-bd3a-qa.md` (FAIL).

## Verdict: FAIL (one narrow blocker; everything else in scope passes)

**Blocker: ux's orphan fix (a614f76) logs an engine ERROR, and the full suite crashed once right after it.**
`EnemyHpBar._exit_tree` frees `_stacks` while the `_add_sibling_deferred.call_deferred(stacks)` call that carries that same label is still queued. When the queue runs, Godot logs `ERROR: Error calling deferred method: 'MeshInstance3D(EnemyHpBar.gd)::_add_sibling_deferred': Cannot convert argument 1 from Object to Object.` (a freed argument). The orphan count is now 0, but the error is new, and the project rule is zero errors in the console.
- Reproduction (isolated, deterministic): `godot --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/slice5d_qa_test.gd -c`. 9 cases pass, 0 orphans, exit 0, and the ERROR line prints once (at `test_pin_reparented_enemy_drops_out_of_roster`: the enemy leaves the tree with the deferred add still queued). It prints once per full-suite run too.
- Crash: my first full-suite run (with about 15 sim processes running beside it) ended **exit 139** (process crash) on that ERROR line, in `slice5d_qa_test`, with nothing after it in the log. The second run, on a quiet machine, passed (below). I did not prove the ERROR causes the crash, only that the crash came right after it. The suite gate is the exit code, so a crash is red.
- Fix direction (not mine to write): do not pass a pre-built node through the deferred call. Build the label inside `_add_sibling_deferred` (so nothing exists to leak or to free early). The probe `bd3a_qa_test > test_an_enemy_freed_in_its_spawn_frame_leaves_no_orphan_node` must keep passing, and the isolated command above must print no ERROR line. No gdUnit test can see an engine ERROR; `run_reload_cycle.ps1` fails on one, so a soak that frees enemies in their spawn frame would guard it.
- Owner: ux (with gameplay-dev). Re-check: qa, one isolated suite run plus one full run.

## Evidence

### Test runs

| Run | Result |
|---|---|
| `powershell -File tools\run_tests.ps1`, run 1 (beside about 15 sim processes) | **exit 139**, crashed after the ERROR line above, in `slice5d_qa_test`. No summary |
| Same command, run 2 (quiet machine, includes my 2 new cases) | **2082 cases, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit 0** (2080 as gameplay-dev reported, plus my 2). The ERROR line above is still in the log |
| `slice5d_qa_test` alone | 9 cases, 0 orphans, exit 0, ERROR line printed |
| Un-skipped probes (`bd3a_qa_test` orphan probe and physical-rogue probe) | both pass in the full run |

### The three fixes

- **ux a614f76.** Orphans fixed (0 in the full suite; was 71). `cast_preview_6a_test` now requires `status_id and hit_radius`, matching the code. Probe un-skipped with its assertions unchanged. New engine ERROR: see the blocker.
- **gameplay-dev e4ef264.** `data/debug_decks/physical-rogue.json` has 0 Fire cards in `starter` and `full` (Fine Burn Then became Cutting Corners) and an honest description. `t_decks_test` was tightened, not loosened: it asserts 0 Fire cards in both lists, that no card's pool is `fire`, and that both lists pass `DeckRules.check_shipped`. My probe is un-skipped with its assertion unchanged, and passes.
- **gameplay-dev a9d56fc.** `Player._apply_aim` reads `aim_point_override` first and only falls back to the mouse (the `camera == null` early return is kept for the no-override case). Real play: `aim_point_override` is assigned only in `tools/wave_sim.gd:619` and `src/debug/Scenario.gd:193` (scenario key `aim_point_offset`); no `.tscn`, `.tres` or `.json` sets it and it is not an `@export`. `sim_aim_test` (3 cases) passes. I added `tests/unit/bd3a_recheck_qa_test.gd` (2 cases, pass): a plain Main has a null override after 5 frames; clearing the override stops the turn. Scenarios: all 8 `aim_point_offset` entries in `data/scenarios.json` aim along -Z ([0,-6.6], [0,-12], [0,-5], [0,-1.6], [0,-8] four times), which is the body's default facing, so by reading the body does not turn for them. Existing suites that set the override (bd1b_tooling, bd1_ux, bd2a_relay, c1b2, c1e, heavy_3b2) pass. **No windowed capture was taken**, so the scenario captures were not looked at.

### Hashes (all four reproduce)

| Run | Hash |
|---|---|
| arena `-Seed 1 -Seconds 30 -Scale 1` | **3172486861** |
| arena `-Seed 1 -Seconds 90 -Scale 1` | **916264160** |
| `-Plan -Seed 1 -Seconds 30 -Scale 1` | **1317880580** |
| `run_bot_sim.ps1 -Rooms 20 -Seed 3` | **3476063471** (unchanged) |

Reload soak (`-Cycles 3`: plain, `-Class wizard`, `-Map`, `-Class wizard -Map`): RELOAD CYCLE OK, all four.

### Blocker 2 (Fire share), numbers only

`tools\run_offer_report.ps1` (1000 seeds, lean 0.25, skip-starter true) reproduces last review exactly. Bleed bot, Fire share early / mid / late: **29.9 / 31.7 / 31.6%**; the same bot under the pre-D47 rule: 30.8 / 35.9 / **39.1%**; neutral 30.0 / 30.8 / 29.8%; Burn bot 29.8 / 26.0 / 20.6%. Late 31.6% against 39.1% pre-D47 holds the re-scoped reading. The "about 37% before BD3a" in DECISIONS I did not re-measure (the offer report has no pre-BD3a mode).

### Boss-room parity (fixed bot; `-Run -Plan -NoMap -StartRoom 10 -Seed 1 -Runs 12 -Class rogue -Deck <d>`; 12/12 won every time)

| Deck | Boss median | vs standard | With its relics | vs standard |
|---|---|---|---|---|
| standard | 29.8 s | 100% | | |
| rogue-bleed-out | 27.3 s | **92%** | 23.5 s (Serrated Excuse, Salt in the Wound) | **79%** |
| rogue-grudge-brawler | 32.5 s | **109%** | 28.1 s (Spite Knuckles, Heavy Sigh, Muscle Memory, Overtime) | **94%** |
| rogue-kindling | 31.6 s | **106%** | 28.7 s (Pyre Insurance, Lingering Embers) | **96%** |

All eight inside 70-130%. (The old, aim-bugged numbers: 42.8 s standard; 117 / 111 / 98%.) The boss starts at full HP, so this does not test survival.

### Fingerprint, Kindling vs Bleed Out (L1 over share vectors: light, heavy, each slot type, each status, each relic; computed from the per-run `damage by source` lines)

| Reading | Median of per-run shares (BUILD_DEPTH wording) | Mean of shares (last review's method) | Top source, Bleed Out / Kindling |
|---|---|---|---|
| relics off | **0.45** | 0.49 (was 0.72) | slot:attack_single 28% / slot:attack_aoe 34% (differ) |
| with each deck's relics | **0.61** | 0.66 (was 0.80) | slot:attack_single 33% / slot:attack_aoe 35% (differ) |

- With-relics reading (game-lead's ruling): **0.61 by the BUILD_DEPTH wording, 0.66 by the mean: passes, narrowly, on 12 seeds.** The relics-off reading now fails 0.6 clearly.
- Top sources differ in both readings, but not for the reason DECISIONS gives: Bleed Out no longer tops at `status:bleed`. With the fixed bot Bleed ticks are 21% (23% with relics), third behind Attack: Single and Attack: AoE. The line is met on "differ"; the DECISIONS text is stale.

### No-card gate (`-Run -Seed 1 -Runs 12 -LightHeavyOnly -NoRelics`)

Rogue **0/12 won** (11 died in room 2, 1 in room 4); Wizard **0/12 won** (3 in room 1, 7 in room 2, 2 in room 4). Holds.

### Three-act `-Run -Seed S -Runs 12 -Class C -Route first` (map on, information only; floors suspended until SIM1)

| Seed | Rogue won | Rogue final boss median | Wizard won | Wizard final boss median |
|---|---|---|---|---|
| 1 | **12/12** | 30.7 s | **9/12** (lost in rooms 16, 23, 27) | 37.2 s |
| 13 | **11/12** (lost in room 24) | 30.1 s | **10/12** (lost in room 20 and one other) | 39.3 s |
| 25 | **12/12** | 27.6 s | **10/12** (lost in rooms 16, 25) | 38.6 s |
| **Pooled** | **35/36** | | **29/36** | |

Rogue act medians (seed 1 / 13 / 25): act 1 183 / 179 / 182 s, act 2 210 / 200 / 209 s, act 3 205 / 207 / 218 s; HP at every act end 100%; relics held at the end 7.5 / 8 / 7. Wizard: act 1 166 / 172 / 174 s, act 2 192 / 182 / 190 s, act 3 192 / 201 / 201 s; HP at act end 22 (100%), except 19 (86%) for act 3 on seed 25; relics 8 / 8 / 7. The Rogue 35/36 matches game-lead's figure and Wizard seed 1 is 9/12 as reported. These are fixed-bot numbers and not comparable with the old 17/36 or 29/36. The bot finishes every act at full HP, so they say little about difficulty for a human; that is SIM1's and the playtester's job.

## Non-blocking

1. The Wizard loses 2 to 3 of 12 per seed in acts 2-3 (rooms 16 to 27) where the Rogue loses 1 of 36. Not a defect on its own (22 HP against 30); flagged for SIM1 and the playtester.
2. The whole-run `rogue-bleed-out` check (my earlier 0/12): see the addendum at the end for the re-run.
3. The fingerprint margin (0.61) is thin; any rebalance of Bleed Out or Kindling can flip it.
4. README (tech-writer): line 82 still says `physical-rogue` "has 2 Fire cards"; hashes, "Last verification", case counts stale; `run_offer_report.ps1` still undocumented.
5. Windowed captures not taken this pass.

## Carry-overs

| Item | Owner |
|---|---|
| Fix the freed-argument ERROR in `EnemyHpBar` (and the exit 139 seen once); re-run isolated and full suite | ux with gameplay-dev; qa re-checks |
| Correct the DECISIONS wording "Bleed Out tops at status:bleed" (top is Attack: Single now; fingerprint 0.61 with relics, 0.45 without) | game-lead |
| Decide whether the thin fingerprint pass is acceptable | game-lead |
| Play `rogue-bleed-out` from room 1; look at scenario captures after the facing change | playtester |
| Re-baseline every bot number, set human-like floors | SIM1 (game-lead) |
| README/CHANGELOG: new hashes, 2082 cases, physical-rogue line, offer report | tech-writer |

## Added by qa

`tests/unit/bd3a_recheck_qa_test.gd` (2 cases): a plain Main has no aim override; clearing an override stops the body turning.

## Addendum: whole-run Bleed Out (my earlier 0/12)

`-Run -Plan -Seed 1 -Runs 12 -NoMap -NoRelics -Class rogue -Deck rogue-bleed-out`: **12/12 won** (was 0/12 with the aim bug), all 12 reached room 10, boss median 30.6 s (standard deck in the same form was 12/12 before). The carry-over is closed for the sim; the playtester still plays it from room 1 as a human.

## Final verdict (e51981e): PASS

BD3a is PASS. The one remaining blocker, the "Error calling deferred method" ERROR, is gone.

- **Diff review.** `_add_stack_label_deferred()` takes no argument and builds the `StatusStackLabel` inside the call. It returns early, building nothing, if the bar is out of the tree, `_status` is gone, or the host is missing or out of the tree. So no node crosses the deferred boundary, and nothing is built before a parent exists, so nothing can orphan. `_stacks` and `_exit_tree` are removed, and they are no longer needed.
- **Orphan guarantee.** `bd3a_qa_test` (20 enemies freed in their spawn frame, 0 orphans) passes in the full suite.
- **Label on live enemies.** There was no test for this, so I added `test_a_live_enemy_gets_its_status_stack_label_as_a_sibling_of_the_bar` to `tests/unit/bd3a_recheck_qa_test.gd` (3 cases now, all pass). A live MeleeChaser has a `StatusStackLabel` sibling after 3 frames.
- **`slice5d_qa_test` alone.** 9 cases, exit 0, 0 orphans, 0 "Error calling deferred" lines.
- **Full suite** (`tools\run_tests.ps1`, about 15.5 min). Exit 0, 157/157 suites, 2082/2082 cases, 0 errors, 0 failures, 0 orphans, 0 "Error calling deferred" lines, and no exit 139. This was before my added case; it is 2083 now.
- **`Condition "!is_inside_tree()"` ERROR.** It appears at `bd3a_ux_test > test_an_emphasized_number_is_larger...` (alone: 24 cases, exit 0) and also in `a1_qa_test > test_boss_phase_floor_still_holds...`. The second is a file unrelated to `EnemyHpBar`, and e51981e touches only `src/ui/EnemyHpBar.gd`, so it does not come from this fix. It is an engine "Returning: Transform3D()" log from a test node asking for a transform while out of the tree. It is harmless to results, but it is noise. I did not check it at cff56aa. Non-blocking, carry-over for ux/gameplay-dev.
- **Arena `-Seed 1 -Seconds 30`:** `state_hash 3172486861`, WAVE SIM OK, exit 0. Unchanged.

Carry-overs: the same list as above (tidy the `!is_inside_tree()` log; game-lead decides on the thin 0.61 fingerprint; SIM1 re-baseline; tech-writer README and CHANGELOG, now 2083 cases).
