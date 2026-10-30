# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-10-30. The director is away until the evening with an autonomous run order: after C1 and Polish 1, go on to Milestone 3 (3a run structure, 3b rewards, 3c boss, 3d loadouts). Each slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag plus an update to OPEN_ITEMS "While you were away".

## What's done
- Milestone 2, and **Post-milestone polish 1** (all slices). **Content slice C1** and the **capture-tooling task** closed on 2026-10-29: qa PASS 76bca75 (696/696), playtest d94676a, docs pass 4c7b490. Tag **`playtest-2026-10-29-C1`**. **Milestone 3a** closed (tag `playtest-2026-10-29-3a`). **Milestone 3b** closed (tag `playtest-2026-10-29-3b`). **Milestone 3c** closed (tag `playtest-2026-10-29-3c`). **Slice A1 (armor)** closed (tag `playtest-2026-10-29-A1`). **T-decks** closed (tag `playtest-2026-10-29-T-decks`).
- Director answers D1-D16 are recorded (D13 = B and D16 = B are built in P-dodge). D17 is open and doesn't block.
- The repo runs. Suite 996/996.

## In progress
- **Slice A1: Armor** closed 2026-10-29 (tag `playtest-2026-10-29-A1`, 968/968). Docs 28587a9.
- **T-decks** closed 2026-10-29 (tag `playtest-2026-10-29-T-decks`, 996/996). Docs cddab25.
- **W1a (a playable Wizard)**: gameplay built 451eaf3..39fe0c6; ux built 0b540d6..672622f (1044/1044). qa PASS b799153 (1053/1053). Playtester next. **On resume:** look for `docs/playtests/2026-10-30-w1a-*.md`.

## Exact next step
1. **W1a**: playtester -> tech-writer -> close. Then **W1b** (cards, presets, balance).
2. Then **P-dodge** (carries D13 = B, D16 = B and the reload soak flake), then **3d**.
3. Waiting on the director: D17 (card damage-type cue; default B, doesn't block).

Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`.
