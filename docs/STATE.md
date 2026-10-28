# Handoff State

Last updated: 2026-10-27. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- "0 / 30" investigated: it is player HP; the player never handles `Health.died`, so it keeps acting at 0 HP. Fix is in Slice 1.

## In progress
Nothing is half-built. Slice 1 (death and game over) is briefed in `docs/ROADMAP.md` but no code has been started. Repo runs as of a941ddd.

## Exact next step
Run **gameplay-dev** on Slice 1 with the roadmap brief. Then ux-designer (Game Over screen + HUD "HP" label) -> qa -> playtester -> game-lead close. Then slices 2, 3, 4, 5 in order, then the whole-pass playtester report. After the pass: **Milestone 3a (run structure)**.

**Blocker for orchestration:** this session couldn't launch role agents (no subagent tool, and nested `claude -p --agent` was denied by the permission check; see DECISIONS.md). Until that changes, the director runs each role directly, e.g. `claude --agent gameplay-dev` with the prompt: "Implement Post-milestone polish 1, Slice 1 per its brief in docs/ROADMAP.md. Commit when done and update docs/STATE.md." Then the same for ux-designer, qa, and playtester, then `claude --agent game-lead` to close the slice and brief the next.

## Open questions for the director
None blocking. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-idle-smoke-check.md` (idle smoke check only).
