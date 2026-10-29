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
- **Tooling task built, waiting for qa** (gameplay-dev, 2026-10-28): true-size capture (`capture_screenshot.ps1 -TrueSize WxH`, `WorldRef`), dodge values in `data/player.json` with D8 default B (28 m/s, 7.0 m; the director's D8 = C, `speed` 20, is still to apply in C1-a), seeded wave and bot sims repeat exactly (`run_wave_sim.ps1` now `--fixed-fps 60`, `-Scale` default 1), enemy shot lane tip, Enemy.gd header. Suite 552/552. Details in DECISIONS (2026-10-28) and the hand-back.
Nothing is mid-build. The next task hasn't started.

## Exact next step
1. **Tooling task (gameplay-dev -> qa)**, brief in ROADMAP "Tooling: true-size capture". It also includes:
   - D8 dodge distance: default B is `dodge_speed` 14 -> 28 if the director hasn't answered. The dodge values move to data.
   - S6-4: make seeded wave and bot sims fully repeat, or document exactly what repeats. The bot-sim ps1 also needs a `-Seed` passthrough.
   - Follow-up 6-a: pad the enemy shot lane tip.
   - The stale header comment in `src/enemies/Enemy.gd`.
2. **Pass close-out:** one whole-pass playtester report covering 5d and Slice 6 live-ish checks, then a tech-writer docs pass, then DoD verified, OPEN_ITEMS and STATE updated.
3. Then **Milestone 3a (run structure)**.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass"; game-lead resumes at the step above. Run roles one at a time (shared working tree and git), and each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`. Right now that's D8 (dodge distance), plus the "needs your eyes" checks.
