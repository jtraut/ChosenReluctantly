# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-10-29. Director is away until evening with an autonomous run order: finish C1 and Polish 1, then Milestone 3 (3a run structure, 3b rewards, 3c boss, 3d loadouts), each slice with the full loop and a `playtest-YYYY-MM-DD-<slice>` tag at close. Part 1 housekeeping is done (fe3c785). **Milestone 2 is done.** We're running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`). This is NOT Milestone 3.

## What's done (Polish 1)
- Slices 0-5, 3b (attack rework), 5d (crowd readability) and 6 (hold-to-preview casting, settings/pause screen, D7 bars, player occlusion cue) are all **done**. Each one passed qa, playtest where applicable, and (from Slice 6 on) a tech-writer docs pass. Details are in ROADMAP, the reviews in `docs/reviews/`, and the playtests in `docs/playtests/`.
- Director answers D1-D7 are recorded (GDD §3, DECISIONS, CHANGELOG).
- Process:
  - `docs/OPEN_ITEMS.md` and `docs/CHANGELOG.md` exist.
  - The tech-writer role joined on 2026-10-28.
  - The feature loop is now build -> qa -> playtester -> tech-writer docs pass -> game-lead close (see CLAUDE.md, Process).
- Suite: 542/542 at 57be0a1. The repo runs.

## In progress
- **Tooling task:** built (7a372b9) and **qa PASS** (b5a796a, 552/552). It closes with C1 once the C1-h docs pass is done.
- **C1-a** built 2a985e4..73c8e72 (571/571). **C1-b1** built 4236e5a..87dbb87 (596/597). **C1-t** done da1115a (597/597, 3 of 3 runs). **C1-b2** built 4b1820a..a393470 (630/630). **C1-c** built 87ede1f..de9f916 (666/666). **C1-d** (story) is next.
- **Director answered D8-D12.** D8 = C (dodge about 5 m) is applied in C1-a by setting `data/player.json` `dodge.speed` 28 -> 20.

## Exact next step
1. **C1-d** story (names and flavor in data). **On resume:** check `git log` for story commits.
2. Then -> C1-e ux-designer -> C1-f qa -> C1-g playtester (merged with the pass close-out report) -> C1-h tech-writer (also covers the tooling docs) -> game-lead closes C1, the tooling task and the pass.
3. Then **Milestone 3a** (brief in ROADMAP), then 3b, 3c, 3d. Tag each closed slice `playtest-2026-10-29-<slice>` and update the OPEN_ITEMS "While you were away" section.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass"; game-lead resumes at the step above. Run roles one at a time (shared working tree and git), and each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`. Nothing needs a decision right now; there are 12 "needs your eyes" checks.
