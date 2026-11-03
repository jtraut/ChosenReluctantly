# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-02 (H1 closed). **Run order (director, 2026-11-02, updated by his OPEN_ITEMS pass):** H1 done -> **H2 (next)** -> BD0 -> PL3 (rest) -> BD1 -> 3d; the branching map's place is D28. Briefs are in ROADMAP. Each build slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag. OPEN_ITEMS holds active items only; tech-writer archives answered ones in `docs/RESOLVED.md`. Done so far: A1, T-decks, W1a, PL2, F1, P-dodge, W1b, K1, H1.

## What's done
- **H1 closed 2026-11-02 (gates met, goal missed):** 0c834a0..e4f4cbe, qa PASS 42cdb13, playtest a8123b5, housekeeping 642d546/c3f5ac1/98595d4 (D21 = B; no renormalisation needed, index already LF), docs f8238c1 (incl. new `docs/RESOLVED.md`). Tag `playtest-2026-11-02-H1`. **Baselines now: suite 1197/1197 (103 suites); arena 30 s seed 1 = 2816045921, 90 s = 3667433295; bot sim `-Rooms 20 -Seed 3` = 2281795515.** H2 changes the sim hashes again.
- Milestone 2, Post-milestone polish 1, C1, 3a, 3b, 3c, A1, T-decks, W1 (W1a + W1b), PL2, F1, P-dodge (tags `playtest-2026-10-29-C1`, `-3a`, `-3b`, `-3c`, `-A1`, `-T-decks`, `playtest-2026-10-30-W1a`, `-PL2`, `-F1`, `-P-dodge`, `playtest-2026-11-02-W1b`, `playtest-2026-11-02-K1`).
- **K1 closed 2026-11-02:** gameplay-dev 04ac813/7f4b136, ux 6204f2a/81abc85, qa PASS 8752a1c, playtest 2c0d185, docs 9e77aae. The UI's key text now comes from `InputLabels` (live InputMap), Recovery is on R, and a duplicate binding errors at startup. The reward prompt no longer lets slot keys cast behind it. Playtest findings went to PL3 items 7-10. DECISIONS "2026-11-02 - K1".
- **W1b closed 2026-11-02:** content aaa933a .. playtest d74e0df; docs ab00c50 + d6a449a. The director's keybind commit 24530e4 left 3 stale input tests failing; qa fixed them test-only in 0119999 (tests now read slot keys from the InputMap). Carry-overs: kiting Wizard nearly unhurt in rooms 1-9 (H1); Fan of regrets telegraph added to PL3 as item 6.
- Director answers D1-D18 and checklist items 11-24 are recorded and built.
- **2026-11-02, Part 0 of the director's 10/31-11/2 notes (docs only, game-lead):** GDD §1, §3, §4, new §4a, §8, §9, §14 items 11-12; ROADMAP briefs for K1, H1, BD0, BD1, PL3 housekeeping, 3d changes A-F; OPEN_ITEMS updates; human playtest entries; DECISIONS "2026-11-02 - Recording the director's 10/31-11/2 notes". All 2026-11-02 director decisions are in the CHANGELOG (ab00c50).
- The repo runs. Baselines: see the H1 line above.

## In progress
- Nothing mid-build. Working tree clean after housekeeping.
- Known flaky: `tests/unit/w1a_test.gd:485` (auto-fire wait at time_scale 0.25) failed once under full-suite load, then passed alone and in the next full run. qa looks at it in H2.

## Exact next step
1. **H2, gameplay-dev first,** per the H2 brief in ROADMAP (dodge-off data switch, Movement = Space / Utility = F bindings, game-over arm delay, Wizard 22 HP in its own commit, bots obey the switch, three-column sim table). Then ux-designer -> qa (also the w1a flake, and confirm SceneSelfCheck in the 20 s run) -> playtester (short) -> tech-writer -> close, tag `playtest-YYYY-MM-DD-H2`, re-baseline hashes.
   - Tell tech-writer the latest suite result in its handoff, so it doesn't re-run the full suite.
2. Then BD0 (game-lead alone, docs only; include the map-hook and dodge-off notes in its brief), PL3 (rest), BD1, 3d.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-number reservation:** D21 = run order, D23 = loadout card flags (director-assigned). **D22, D24, D25 are reserved for BD0's questions** (at most 3). D26 = menu key text (K1). D27 = H1 attack speed (read as A). D28 = branching map placement. Next free: D29.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md` (D26 narrowed, D28 waiting; none blocks). Answered items are in `docs/RESOLVED.md`.
