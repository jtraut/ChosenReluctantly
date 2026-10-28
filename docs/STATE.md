# Handoff State

Last updated: 2026-10-27. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- "0 / 30" investigated: it is player HP; the player never handles `Health.died`, so it keeps acting at 0 HP. Fix is in Slice 1.

## In progress
**Slice 1 (death and game over):** gameplay half done (9744135: `Player.player_died`, `Main.game_over_ready`, `Main.restart_arena()`, `Main.is_game_over()`, 11 tests, suite green). UI half done too (Game Over screen, "HP x / y" label, `game_over` scenario, `-Resolution` on capture tool). **qa PASS** (1f24ceb, `docs/reviews/2026-10-27-polish1-slice1-qa.md`; real 5x reload soak `tools/run_reload_cycle.ps1` clean). **playtester delegated** for smoke check + death/Game Over report. If cut off: check `docs/playtests/` for a Slice 1 report; if none, re-run playtester. Then (must do a real windowed 5x death/restart cycle) -> playtester -> close. Slot bar clipped at 720p (pre-existing) is Slice 2 scope. Known gaps carried to qa: in-flight projectiles still hit after death; enemies idle (no wander); Burn component keeps ticking on dead player (ignored by Health).

## Exact next step
Run **gameplay-dev** on Slice 1 with the roadmap brief. Then ux-designer (Game Over screen + HUD "HP" label) -> qa -> playtester -> game-lead close. Then slices 2, 3, 4, 5 in order, then the whole-pass playtester report. After the pass: **Milestone 3a (run structure)**.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead delegates gameplay-dev on Slice 1 and runs the loop. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
None blocking. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-idle-smoke-check.md` (idle smoke check only).
