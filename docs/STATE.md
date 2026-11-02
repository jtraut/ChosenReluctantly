# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-02. **Run order (director, 2026-11-02):** W1b and K1 are closed. Next: **H1 -> BD0 -> PL3 -> BD1 -> 3d**. Briefs for all six are in ROADMAP ("Run order after W1b"). Each build slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag plus an update to OPEN_ITEMS "While you were away" and the tag list. BD0 is docs only (game-lead alone, no tag). Done so far: A1, T-decks, W1a, PL2, F1, P-dodge, W1b, K1.

## What's done
- Milestone 2, Post-milestone polish 1, C1, 3a, 3b, 3c, A1, T-decks, W1 (W1a + W1b), PL2, F1, P-dodge (tags `playtest-2026-10-29-C1`, `-3a`, `-3b`, `-3c`, `-A1`, `-T-decks`, `playtest-2026-10-30-W1a`, `-PL2`, `-F1`, `-P-dodge`, `playtest-2026-11-02-W1b`, `playtest-2026-11-02-K1`).
- **K1 closed 2026-11-02:** gameplay-dev 04ac813/7f4b136, ux 6204f2a/81abc85, qa PASS 8752a1c, playtest 2c0d185, docs 9e77aae. The UI's key text now comes from `InputLabels` (live InputMap), Recovery is on R, and a duplicate binding errors at startup. The reward prompt no longer lets slot keys cast behind it. Playtest findings went to PL3 items 7-10. DECISIONS "2026-11-02 - K1".
- **W1b closed 2026-11-02:** content aaa933a .. playtest d74e0df; docs ab00c50 + d6a449a. The director's keybind commit 24530e4 left 3 stale input tests failing; qa fixed them test-only in 0119999 (tests now read slot keys from the InputMap). Carry-overs: kiting Wizard nearly unhurt in rooms 1-9 (H1); Fan of regrets telegraph added to PL3 as item 6.
- Director answers D1-D18 and checklist items 11-24 are recorded and built.
- **2026-11-02, Part 0 of the director's 10/31-11/2 notes (docs only, game-lead):** GDD §1, §3, §4, new §4a, §8, §9, §14 items 11-12; ROADMAP briefs for K1, H1, BD0, BD1, PL3 housekeeping, 3d changes A-F; OPEN_ITEMS updates; human playtest entries; DECISIONS "2026-11-02 - Recording the director's 10/31-11/2 notes". All 2026-11-02 director decisions are in the CHANGELOG (ab00c50).
- The repo runs. Suite 1190/1190 at 8752a1c (K1). Arena hash baseline 2484586390 (30 s seed 1; 90 s 3255493562). **H1 will change the sim hashes; re-baseline and record them here at its close.**

## In progress
- **H1: gameplay-dev DONE (0c834a0..e4f4cbe); qa next.** Ships `pressure` block in `data/enemies.json`: speed_scale 1.25, attack_rate_scale 1.0; boss unscaled; `-LightHeavyOnly` fixed to press no slot. Candidate hashes pending qa: arena 30 s seed 1 **2816045921**, 90 s **3667433295**; bot sim `-Rooms 20 -Seed 3` 2281795515 unchanged (spawns no enemies). Suite 1193/1193. Wizard kiting HP-loss target missed (0% at every variant); final targets in DECISIONS "2026-11-02 - H1"; D27 raised.
- Untracked on disk, not ours to commit: `tools/ux_capture.gd.uid` (ux) and `docs/playtests/img/*.import` (Godot imports; PL3 adds `docs/.gdignore`). Don't sweep them into other commits.

## Exact next step
1. **H1, qa next** (gameplay-dev done), per the H1 brief in ROADMAP: enemy speed first (+10/20/25% tested), attack rate only if needed, behind shared data knobs. Then qa -> playtester (short) -> tech-writer -> close, tag `playtest-YYYY-MM-DD-H1`. **H1 changes the sim hashes; re-baseline at close** (today: arena 2484586390 for 30 s seed 1, 3255493562 for 90 s; bot sim `-Rooms 20 -Seed 3` 2281795515).
2. Then BD0 (game-lead alone, docs only), PL3, BD1, 3d per ROADMAP.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-number reservation:** D21 = run order, D23 = loadout card flags (director-assigned). **D22, D24, D25 are reserved for BD0's questions** (at most 3). D26 = menu key text (K1). D27 = H1 attack speed / next lever. Next free: D28.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md` (D19, D20, D21, D23, D26 waiting; none blocks).
