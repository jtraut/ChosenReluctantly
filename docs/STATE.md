# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-03 (D30 = A recorded; H3 build starting with gameplay-dev). **Run order (director D24 = A, D28 = A; H3 placement game-lead):** BD0 done -> **H3 (next; the dodge returns, D29 = B)** -> MAP0 (game-lead alone, docs only, no tag) -> PL3 (rest) -> BD1 -> BD2 (relics) -> first map build -> 3d -> BD3. All briefs are in ROADMAP. Each build slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag. OPEN_ITEMS holds active items only; tech-writer archives answered ones in `docs/RESOLVED.md`. Done so far: A1, T-decks, W1a, PL2, F1, P-dodge, W1b, K1, H1, H2, BD0.

## What's done
- **D30 = A recorded 2026-11-03 (game-lead, docs only):** 98efccd (GDD §4a bullet, GDD §9 director note on maybe removing the rest heal, BUILD_DEPTH §4.1/§11, ROADMAP BD2 wording + MAP0 rest-node question). OPEN_ITEMS: D30 removed. **For the H3 tech-writer handoff:** RESOLVED gets D30 (question text is in commit b332971's OPEN_ITEMS), CHANGELOG gets a `[Director decision]` 2026-11-03 entry for D30 = A and the rest-heal note.
- **Director answers recorded 2026-11-02 (game-lead, docs only):** a6c33e6 (GDD §3/§4a/§5/§9/§14), 803c42b (BUILD_DEPTH §3.4, §4.1, §8, §9, §11), 6bd0f70 (ROADMAP: H3 + MAP0 briefs, BD1/BD2 edits, PL3 item 6 -> H3), c065762 (DECISIONS "Applying the director's answers"), plus OPEN_ITEMS/STATE. D22 = C (merchant, relic stage, elites; 6-8 for a relic hunter, cap 10), D24 = A, D25 = A (+ passive nodes), D26 = A, D28 = A, D29 = B (dodge on Space, Rogue 2 / Wizard 1, Movement on Ctrl, enemies and boss volley a bit faster). New D30 (rest/reward relics; default A = no).
- **BD0 closed 2026-11-02 (docs only, no tag):** game-lead 81fb65e..0ddd630, docs 995befe. New `docs/BUILD_DEPTH.md` (game-lead owns it). GDD §4a [PROPOSED] summary. ROADMAP: BD1 rewritten, BD2 (relics) and BD3 added. DECISIONS "2026-11-02 - BD0". The director said "continue" without answering D29, so BD0 assumed D29 = A (dodge off); BUILD_DEPTH §8 says what changes for B/C. New questions D22, D24, D25 (defaults A).
- **H2 closed 2026-11-02 (dodge-off trial):** gameplay-dev 120bfef..dacc680, ux e155c3e/ff3ef4f, qa PASS 4aa7141, playtest ebde769, docs edef5c0/0e47a70. Tag `playtest-2026-11-02-H2`. Dodge off (`data/player.json` `dodge.enabled`), Movement Space, Utility F, Wizard 22 HP, game-over arm delay. Bot standard clears with the dodge off: Rogue 3/16, Wizard kite 8/16, no-kite 7/16 (16/16 each with it on); not retuned. D29 asks whether the dodge stays off. **Baselines now: suite 1220/1220 (105 suites); arena 30 s seed 1 = 2591372848, 90 s = 4009010406 (dodge-on copies still give H1's 2816045921 / 3667433295); bot sim `-Rooms 20 -Seed 3` = 2281795515.**
- **H1 closed 2026-11-02 (gates met, goal missed):** 0c834a0..e4f4cbe, qa PASS 42cdb13, playtest a8123b5, housekeeping 642d546/c3f5ac1/98595d4 (D21 = B; no renormalisation needed, index already LF), docs f8238c1 (incl. new `docs/RESOLVED.md`). Tag `playtest-2026-11-02-H1`. (H1 baselines, superseded by H2's above.)
- Milestone 2, Post-milestone polish 1, C1, 3a, 3b, 3c, A1, T-decks, W1 (W1a + W1b), PL2, F1, P-dodge (tags `playtest-2026-10-29-C1`, `-3a`, `-3b`, `-3c`, `-A1`, `-T-decks`, `playtest-2026-10-30-W1a`, `-PL2`, `-F1`, `-P-dodge`, `playtest-2026-11-02-W1b`, `playtest-2026-11-02-K1`).
- **K1 closed 2026-11-02:** gameplay-dev 04ac813/7f4b136, ux 6204f2a/81abc85, qa PASS 8752a1c, playtest 2c0d185, docs 9e77aae. The UI's key text now comes from `InputLabels` (live InputMap), Recovery is on R, and a duplicate binding errors at startup. The reward prompt no longer lets slot keys cast behind it. Playtest findings went to PL3 items 7-10. DECISIONS "2026-11-02 - K1".
- **W1b closed 2026-11-02:** content aaa933a .. playtest d74e0df; docs ab00c50 + d6a449a. The director's keybind commit 24530e4 left 3 stale input tests failing; qa fixed them test-only in 0119999 (tests now read slot keys from the InputMap). Carry-overs: kiting Wizard nearly unhurt in rooms 1-9 (H1); Fan of regrets telegraph added to PL3 as item 6.
- Director answers D1-D18 and checklist items 11-24 are recorded and built.
- **2026-11-02, Part 0 of the director's 10/31-11/2 notes (docs only, game-lead):** GDD §1, §3, §4, new §4a, §8, §9, §14 items 11-12; ROADMAP briefs for K1, H1, BD0, BD1, PL3 housekeeping, 3d changes A-F; OPEN_ITEMS updates; human playtest entries; DECISIONS "2026-11-02 - Recording the director's 10/31-11/2 notes". All 2026-11-02 director decisions are in the CHANGELOG (ab00c50).
- The repo runs. Baselines: see the H2 line above.

## In progress
- **H3: gameplay-dev done** (cee653d, d22b08d, 783d552, 3dc74fb; suite 1237/1237; arena 30 s seed 1 = 2333565009, 90 s = 819020947; bot sim `-Rooms 20 -Seed 3` = 2281795515 unchanged). Ctrl reliable (synthetic events). Volley lanes were already correct; `in_threat` muzzle fix. Bots, 20 seeds, H3 shipped: Rogue 17/20, Wizard kite 15/20, no-kite 18/20; every `-LightHeavyOnly` config 0/20 (no-card gate PASS). DECISIONS "2026-11-03 - H3 build".
- **Next role: ux-designer** (H3 ux part: dodge pips 2/1, Ctrl and Shift+Ctrl labels at min scale, volley telegraph look incl. whether lanes fade during the ~1.8 s pellet flight; base frames via `capture_screenshot.ps1 -Scenario boss_volley`). If cut off: check for ux commits after 3dc74fb.
- Known: wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320` (possible flakes).

## Exact next step
1. **H3, the dodge returns** (ROADMAP brief). Hand to **gameplay-dev** first: dodge on (Rogue 2, Wizard 1), Space dodge / Ctrl Movement / Shift+Ctrl swap (Ctrl reliability is an acceptance test; stop and report if it fails), the Fan of regrets lane check, then the speed-up in its own commit (`attack_rate_scale` 1.1, new `telegraph_scale` 0.85, volley windup 0.75), bots in three columns with the no-card gate, new hashes. Then ux-designer -> qa -> playtester (short) -> tech-writer -> close, tag `playtest-YYYY-MM-DD-H3`.
2. Then **MAP0** (game-lead alone, docs only; brief in ROADMAP; questions from D31).
3. Then **PL3** (rest), **BD1**, **BD2** (relic room + elites, cap 10; D30 = A: no rest or reward-screen relics), the first map build, **3d**, **BD3**.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-numbers:** D21-D29 answered (D22 = C, D24 = A, D25 = A, D26 = A, D28 = A, D29 = B on 2026-11-02). D30 = A (2026-11-03). Next free: D31.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions open; eyes 38, 39 (35 after BD2). Answered items are in `docs/RESOLVED.md` (D30 goes there in the H3 tech-writer pass).
