# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-10-30. Run order (game-lead 2026-10-30, after the director's checklist answers): PL2 -> F1 -> P-dodge -> W1b -> 3d (W1b moved after P-dodge so the Wizard is tuned once). Each slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag plus an update to OPEN_ITEMS "While you were away". Done so far: A1, T-decks, W1a.

## What's done
- Milestone 2, and **Post-milestone polish 1** (all slices). **Content slice C1** and the **capture-tooling task** closed on 2026-10-29: qa PASS 76bca75 (696/696), playtest d94676a, docs pass 4c7b490. Tag **`playtest-2026-10-29-C1`**. **Milestone 3a** closed (tag `playtest-2026-10-29-3a`). **Milestone 3b** closed (tag `playtest-2026-10-29-3b`). **Milestone 3c** closed (tag `playtest-2026-10-29-3c`). **Slice A1 (armor)** closed (tag `playtest-2026-10-29-A1`). **T-decks** closed (tag `playtest-2026-10-29-T-decks`). **W1a** closed (tag `playtest-2026-10-30-W1a`).
- Director answers D1-D18 and checklist items 11-24 (2026-10-30) are recorded in the GDD and scheduled into F1, P-dodge and W1b.
- Director answers D1-D17 are recorded (D13 = B and D16 = B are built in P-dodge; D17 = card frame colours by family, built in PL2, GDD §4).
- The repo runs. Suite 1053/1053.

## In progress
- **Slice A1: Armor** closed 2026-10-29 (tag `playtest-2026-10-29-A1`, 968/968). Docs 28587a9.
- **T-decks** closed 2026-10-29 (tag `playtest-2026-10-29-T-decks`, 996/996). Docs cddab25.
- **W1a (a playable Wizard)** closed 2026-10-30 (tag `playtest-2026-10-30-W1a`, 1053/1053). Docs 031f321.
- **PL2 (small polish, before W1b)**: IN PROGRESS (started 2026-10-30). Brief in ROADMAP, now including the director's card frame colours (items 6a and 9) and a short playtester pass. gameplay-dev DONE 3b8359e..5079a2a (1064/1064). ux DONE ad77847 (1079/1079). qa FAIL b7ba7fe (B1: MeleeReachCue orphan leak on Wizard; one-line fix). Step: ux fixes B1 -> qa delta re-review -> playtester.
- **F1 (director feedback batch)**: brief in ROADMAP; runs after PL2.
- **W1b (Wizard cards, presets, balance)**: brief in ROADMAP; runs after P-dodge.

## Exact next step
1. **PL2**: gameplay-dev (items 1-6a) -> ux-designer (items 7-9) -> qa (including the 10+ seed Rogue boss baseline and frame-colour captures) -> playtester (short) -> tech-writer -> close.
2. Then **F1**, then **P-dodge** (D13, D16, per-class charges, Wizard Recovery, the soak flake; sets the Rogue baseline), then **W1b** (tunes Wizard data toward D18 = A), then **3d**.
3. Nothing waiting on the director.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`.
