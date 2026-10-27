# Handoff State

Last updated: 2026-10-26, during Milestone 2 kickoff.

## What's done
- Godot 4.7.2 installed (winget), confirmed running headless with zero errors/warnings (`godot --headless --path . --quit`).
- Project scaffold complete: `project.godot`, `/src /scenes /data /assets /tests /tools /docs`, `.gitignore`/`.gitattributes` for Godot 4, `docs/GDD.md` moved from repo root.
- gdUnit4 v6.2.2 vendored into `addons/gdUnit4`, enabled as an editor plugin, one smoke test passing headless via `tools/run_tests.ps1`.
- `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/ASSETS.md`, root `CLAUDE.md`, and all six `.claude/agents/*.md` role files written.
- `README.md` not yet filled in (next step).
- Nothing committed to git yet in this session.

## In progress
Nothing mid-implementation right now — about to make the first commit of the scaffold, then start Milestone 2 feature work (camera/player first).

## Exact next step
1. Finish `README.md` (what the game is, how to open/run it, how to test).
2. `git add` + commit the scaffold (project files, docs, agents, test framework) as one commit.
3. Start Milestone 2 vertically: 3D isometric camera + player capsule + WASD + mouse-ground-raycast aim + camera follow, as its own scene/script, committed on its own once it runs clean.
4. Then basic attack + dodge roll, then the card slot system (the architectural core — card JSON schema + loader + validation + effect-template registry come before authoring the 12-15 starter cards), then enemies/spawner, then Burn + resistance math, then HUD/debug overlay, then the juice pass. Commit after each vertical slice.
5. QA role reviews each feature (tests + a manual read against the GDD) before `docs/ROADMAP.md` marks it done.

## Open questions for the director
None blocking right now — all Milestone 2 ambiguities were pre-resolved in the kickoff prompt and logged in `docs/DECISIONS.md`. Will surface anything that comes up as it's found.
