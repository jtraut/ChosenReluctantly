# Handoff State

Last updated: 2026-10-27. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- **Polish 1, Slice 1 (death and game over) - done** (7ad85ee): `Player.player_died`, `Main.game_over_ready` / `restart_arena()` (scene reload), Game Over screen, "HP x / y" label, reload soak tool `tools/run_reload_cycle.ps1`.

## In progress
**Slice 1 done** (closed 2026-10-27; follow-ups s1-a..f in ROADMAP). **Slice 2 (HUD text overflow and safe layout): ux-designer delegated** (lead). If cut off: check `git log` for a ux-designer Slice 2 commit; if none, re-run ux-designer on Slice 2 with the roadmap brief plus follow-up s1-d (HP bar contrast). Repo runs at the latest commit.

## Exact next step
Slice 2 loop: ux-designer -> qa -> playtester -> game-lead close. Then slices 3, 4, 5, then the whole-pass playtester report. After the pass: **Milestone 3a (run structure)**. Re-run reload soak `tools/run_reload_cycle.ps1` whenever Main/Juice/Player/autoloads change.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead resumes the loop at the slice named above. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
None blocking. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-polish1-slice1-death.md`. Director: please watch the death slow-mo once in a real window (follow-up s1-a: beat may be too subtle).
