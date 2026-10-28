# Handoff State

Last updated: 2026-10-27. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- "0 / 30" investigated: it is player HP; the player never handles `Health.died`, so it keeps acting at 0 HP. Fix is in Slice 1.

## In progress
**Slice 1 (death and game over): gameplay-dev delegated** by game-lead (2026-10-27). Scope: gameplay half only (death handling, `player_died` signal, input/enemy lockout, death beat, `Main.restart_arena()` via scene reload). Game Over screen + HUD "HP" label are ux-designer's, after. If cut off here: check `git log` for a gameplay-dev Slice 1 commit; if none, re-run gameplay-dev on Slice 1. Repo ran at 64e10ac.

## Exact next step
Run **gameplay-dev** on Slice 1 with the roadmap brief. Then ux-designer (Game Over screen + HUD "HP" label) -> qa -> playtester -> game-lead close. Then slices 2, 3, 4, 5 in order, then the whole-pass playtester report. After the pass: **Milestone 3a (run structure)**.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead delegates gameplay-dev on Slice 1 and runs the loop. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
None blocking. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-idle-smoke-check.md` (idle smoke check only).
