# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-10-30. Run order (game-lead 2026-10-30, after the director's checklist answers): PL2 -> F1 -> P-dodge -> W1b -> 3d (W1b moved after P-dodge so the Wizard is tuned once). Each slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag plus an update to OPEN_ITEMS "While you were away". Done so far: A1, T-decks, W1a, PL2, F1, P-dodge.

## What's done
- Milestone 2, and **Post-milestone polish 1** (all slices). **Content slice C1** and the **capture-tooling task** closed on 2026-10-29: qa PASS 76bca75 (696/696), playtest d94676a, docs pass 4c7b490. Tag **`playtest-2026-10-29-C1`**. **Milestone 3a** closed (tag `playtest-2026-10-29-3a`). **Milestone 3b** closed (tag `playtest-2026-10-29-3b`). **Milestone 3c** closed (tag `playtest-2026-10-29-3c`). **Slice A1 (armor)** closed (tag `playtest-2026-10-29-A1`). **T-decks** closed (tag `playtest-2026-10-29-T-decks`). **W1a** closed (tag `playtest-2026-10-30-W1a`). **PL2** closed (tag `playtest-2026-10-30-PL2`). **F1** closed (tag `playtest-2026-10-30-F1`). **P-dodge** closed (tag `playtest-2026-10-30-P-dodge`).
- Director answers D1-D18 and checklist items 11-24 (2026-10-30) are recorded in the GDD and scheduled into F1, P-dodge and W1b.
- Director answers D1-D17 are recorded (D13 = B and D16 = B are built in P-dodge; D17 = card frame colours by family, built in PL2, GDD §4).
- The repo runs. Suite 1147/1147. Arena hash baseline 2484586390 (30 s seed 1; 90 s 3255493562).

## In progress
- **Slice A1: Armor** closed 2026-10-29 (tag `playtest-2026-10-29-A1`, 968/968). Docs 28587a9.
- **T-decks** closed 2026-10-29 (tag `playtest-2026-10-29-T-decks`, 996/996). Docs cddab25.
- **W1a (a playable Wizard)** closed 2026-10-30 (tag `playtest-2026-10-30-W1a`, 1053/1053). Docs 031f321.
- **PL2** closed 2026-10-30 (tag `playtest-2026-10-30-PL2`, 1082/1082). Docs d175b51.
- **F1** closed 2026-10-30 (tag `playtest-2026-10-30-F1`, 1102/1102). Docs 47fde95.
- **P-dodge** closed 2026-10-30 (tag `playtest-2026-10-30-P-dodge`, 1147/1147). Docs ee18b08.
- **W1b**: IN PROGRESS. Content DONE aaa933a..45ed585 (1151/1151). Step: gameplay-dev tuning run (item 6, 5a, 5c, Ward duration).

## Exact next step
1. **W1b**: gameplay-dev (content first: items 1-4, 5b, 5d's pellet-dodge check and `--boss-log`; then tuning item 6 incl. 5a cliff) -> ux-designer (5e banner overlap) -> qa (independent 10+ seed re-run, both bot policies) -> playtester -> tech-writer -> close. Baseline: Rogue boss 64.3 s mean (band 45.0-83.6 s).
2. Then **3d** (loadouts).
3. Waiting on the director: D19 (dodge in the post-dash ghost window; default A, as built). Doesn't block.
4. Housekeeping idea (not scheduled): docs have mixed CRLF/LF line endings; a one-time normalisation (tech-writer offered) plus a `.gitattributes` would stop whole-file diffs.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`.
