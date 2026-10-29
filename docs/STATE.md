# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-10-28. **Milestone 2 is done.** We're running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`). This is NOT Milestone 3.

## What's done (Polish 1)
- Slices 0-5, 3b (attack rework), 5d (crowd readability) and 6 (hold-to-preview casting, settings/pause screen, D7 bars, player occlusion cue) are all **done**. Each one passed qa, playtest where applicable, and (from Slice 6 on) a tech-writer docs pass. Details are in ROADMAP, the reviews in `docs/reviews/`, and the playtests in `docs/playtests/`.
- Director answers D1-D7 are recorded (GDD §3, DECISIONS, CHANGELOG).
- Process:
  - `docs/OPEN_ITEMS.md` and `docs/CHANGELOG.md` exist.
  - The tech-writer role joined on 2026-10-28.
  - The feature loop is now build -> qa -> playtester -> tech-writer docs pass -> game-lead close (see CLAUDE.md, Process).
- Suite: 542/542 at 57be0a1. The repo runs.

## In progress
- **Tooling task:** built (7a372b9, 552/552). qa review handed to qa. Its docs pass is folded into C1-h.
- **Director answered D8-D12.** D8 = C (dodge about 5 m) is applied in C1-a by setting `data/player.json` `dodge.speed` 28 -> 20.

## Exact next step
1. Tooling qa (in progress).
2. **Content slice C1**, brief in ROADMAP: C1-a -> C1-b1 -> C1-b2 -> C1-c (gameplay-dev) -> C1-d story -> C1-e ux-designer -> C1-f qa -> C1-g playtester (merged with the pass close-out report) -> C1-h tech-writer (also covers the tooling docs) -> game-lead closes C1, the tooling task and the pass.
3. Then **Milestone 3a**.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass"; game-lead resumes at the step above. Run roles one at a time (shared working tree and git), and each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`. Right now that's D8 (dodge distance), plus the "needs your eyes" checks.
