# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-02 (BD0 closed). **Run order (D24 = A, D28 = A defaults):** BD0 done -> **MAP0 (next; game-lead alone, docs only, no tag)** -> PL3 (rest) -> BD1 -> BD2 (relics) -> first map build -> 3d -> BD3. Briefs are in ROADMAP (MAP0's brief is still to write). Each build slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag. OPEN_ITEMS holds active items only; tech-writer archives answered ones in `docs/RESOLVED.md`. Done so far: A1, T-decks, W1a, PL2, F1, P-dodge, W1b, K1, H1, H2, BD0.

## What's done
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
- Nothing in progress. Working tree clean.
- Known: wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320` (possible flakes; fix them the way w1a was fixed in 4aa7141 if they fire).

## Exact next step
1. **MAP0, game-lead alone, docs only** (D28 default A). Write its brief in ROADMAP first, then a `docs/MAP.md`. It covers node types (combat, elite, rest, merchant, curse/buff, mini-boss), choices per step, layout for a 10-room run, the reward currencies it needs (gold, XP, between-run points: GDD §8 [OPEN]), and how nodes call the relic offer function (BUILD_DEPTH §4.6). At most 3 director questions, numbered from D30. Then a tech-writer CHANGELOG pass. No tag.
   - If the director answers D28 = B or C first, skip MAP0 and go to PL3.
2. Then **PL3** (rest), per its ROADMAP brief. Full loop, tag.
3. Then **BD1** (brief rewritten at BD0), **BD2**, the first map build, **3d**, then **BD3**.
4. If the director answers D22/D24/D25/D29 differently from the defaults, update BUILD_DEPTH and the BD1/BD2 briefs before BD1 starts.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-numbers:** D21 = run order, D23 = loadout card flags. D22 = relic sources/count, D24 = relic slice placement, D25 = Burn/Bleed base stacking (BD0). D26 = menu key text (K1). D27 = H1 attack speed (read as A). D28 = branching map placement. D29 = dodge stays off? Next free: D30.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: D22, D24, D25 (new, BD0), D29 (dodge), D28 (map), D26 (menu keys); none blocks. Answered items are in `docs/RESOLVED.md`.
