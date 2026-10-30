# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-10-30. Standing run order (director): A1 -> T-decks -> W1 (W1a, W1b) -> P-dodge -> 3d. Each slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag plus an update to OPEN_ITEMS "While you were away". Done so far: A1, T-decks, W1a.

## What's done
- Milestone 2, and **Post-milestone polish 1** (all slices). **Content slice C1** and the **capture-tooling task** closed on 2026-10-29: qa PASS 76bca75 (696/696), playtest d94676a, docs pass 4c7b490. Tag **`playtest-2026-10-29-C1`**. **Milestone 3a** closed (tag `playtest-2026-10-29-3a`). **Milestone 3b** closed (tag `playtest-2026-10-29-3b`). **Milestone 3c** closed (tag `playtest-2026-10-29-3c`). **Slice A1 (armor)** closed (tag `playtest-2026-10-29-A1`). **T-decks** closed (tag `playtest-2026-10-29-T-decks`). **W1a** closed (tag `playtest-2026-10-30-W1a`).
- Director answers D1-D16 are recorded (D13 = B and D16 = B are built in P-dodge). D17 is open and doesn't block.
- The repo runs. Suite 1053/1053.

## In progress
- **Slice A1: Armor** closed 2026-10-29 (tag `playtest-2026-10-29-A1`, 968/968). Docs 28587a9.
- **T-decks** closed 2026-10-29 (tag `playtest-2026-10-29-T-decks`, 996/996). Docs cddab25.
- **W1a (a playable Wizard)** closed 2026-10-30 (tag `playtest-2026-10-30-W1a`, 1053/1053). Docs 031f321.
- **PL2 (small polish, before W1b)**: brief written in ROADMAP; not started.
- **W1b (Wizard cards, presets, balance)**: brief written in ROADMAP; runs after PL2.

## Exact next step
1. **PL2**: hand the ROADMAP PL2 brief (items 1-6) to gameplay-dev, then ux-designer (items 7-8), qa (including the 10+ seed Rogue boss baseline), tech-writer, close.
   Then **W1b** (brief in ROADMAP; tunes Wizard data only, toward D18).
2. After W1b, **P-dodge** (carries D13 = B, D16 = B and the reload soak flake), then **3d**.
3. Waiting on the director: D17 (card damage-type cue; default B) and D18 (Wizard difficulty; default A). Neither blocks.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`.
