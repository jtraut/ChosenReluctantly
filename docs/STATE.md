# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**

Last updated: 2026-10-28. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- **Polish 1, Slice 3 (attacks) - done**: `data/attacks.json`, auto light (LMB), manual heavy (RMB) with wind-up, LMB/RMB meters, slot ready/cooling state.
- **Polish 1, Slice 2 (HUD layout) - done**: fixed slots, TextFit, safe margins, HP bar contrast; true-size HUD capture via `tools/vp_capture.gd` (no waves).
- **Polish 1, Slice 1 (death and game over) - done** (7ad85ee): `Player.player_died`, `Main.game_over_ready` / `restart_arena()` (scene reload), Game Over screen, "HP x / y" label, reload soak tool `tools/run_reload_cycle.ps1`.

## In progress
**3b-2 (heavy redesign) BUILT by gameplay-dev: heavy 8.5 / 1.8 s, Rogue arc + stun + 50% Burn, Wizard targeted_aoe (data, test, scenario), generic Stun with rank and DR, wind-up slow; 292/292 tests. Next: 3b-3 ux-designer. See DECISIONS 2026-10-28 "Slice 3b-2".**
**Director prompt 2026-10-28 (attack decisions + OPEN_ITEMS) is being executed.**
- Part A (decisions recorded in GDD/DECISIONS): done.
- Part C (`docs/OPEN_ITEMS.md`, CLAUDE.md rule): done.
- **Part B is the new Slice 3b (ROADMAP). 3b-1 built (4fb5b57). 3b-2 built (ee9adbe). 3b-3 (ux: stun cue, targeted_aoe telegraph, stun DR window data change) handed to ux-designer.**
- Slice 4: built, qa PASS and re-check PASS (8cc7b92). Its playtest is folded into the Slice 3b playtest. Not closed yet.

## Exact next step
3b-1 (gameplay-dev) -> 3b-2 (gameplay-dev) -> 3b-3 (ux-designer) -> 3b-4 qa -> playtester (one report for Slice 4 + 3b) -> game-lead closes Slice 4 and 3b and updates OPEN_ITEMS. Then Slice 5 (full loop), the true-size capture tooling, and the pass close-out. After the pass: **Milestone 3a (run structure)**. Re-run the reload soak `tools/run_reload_cycle.ps1` whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead resumes the loop at the slice named above. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
Not blocking, need a feel check in a real window: balance proposals P1-P4 under Slice 3 in ROADMAP (spam-click 2.4x auto DPS; heavy DPS below light; root during heavy wind-up; auto light vs cheap cards). Proposed defaults: P1 and P4 keep as is unless they feel off live (data-only, cheap to reverse); P2 and P3 are design changes, director's call. Defaults unchanged until decided. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-polish1-slice3-attacks.md`. Director: please watch the death slow-mo once in a real window (follow-up s1-a: beat may be too subtle).
