# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first).**

Last updated: 2026-10-28. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- **Polish 1, Slice 3 (attacks) - done**: `data/attacks.json`, auto light (LMB), manual heavy (RMB) with wind-up, LMB/RMB meters, slot ready/cooling state.
- **Polish 1, Slice 2 (HUD layout) - done**: fixed slots, TextFit, safe margins, HP bar contrast; true-size HUD capture via `tools/vp_capture.gd` (no waves).
- **Polish 1, Slice 1 (death and game over) - done** (7ad85ee): `Player.player_died`, `Main.game_over_ready` / `restart_arena()` (scene reload), Game Over screen, "HP x / y" label, reload soak tool `tools/run_reload_cycle.ps1`.

## In progress
**Slice 5 qa fix pass DONE (gameplay-dev, 2026-10-28): S5-1..S5-8 and S5-10, D6 default A (golem wind-up 0.7 s) and the .uid files are committed; suite green including the old bot-sim test; details in DECISIONS "Slice 5 fix pass". Next: qa re-check of Slice 5 (5c), then the playtester. Not touched: S5-9 (ux, low), D7 (director).**
**5c qa verdict: FAIL (one blocker, 2026-10-28), review `docs/reviews/2026-10-28-polish1-slice5-qa.md`.** S5-1: `run_bot_sim.ps1` has not compiled since 058d3dd (UiConfig -> EnemyHpBar -> Enemy -> Juice autoload under `-s`) and used to print OK; proven fix is moving the mode list into `UiConfig` (ux-designer). Suite is 412 tests, 411 pass, **1 red on purpose** (`test_old_bot_sim_script_compiles_and_runs_without_script_errors`; goes green with the fix, do not delete it). Everything else passed; should-fix S5-2..S5-5 (gameplay-dev, ux-designer). Wave sim clean (alive peak 11 to 12, mean 6.0 to 6.6).
**5b BUILT (ux-designer, 2026-10-28), qa at 5c:** HP bar visibility modes as data (candidate default elite_boss_always, shipped value unchanged), damage numbers from data with merge/cap, IMMUNE on top, cone/heal/dash/projectile reads in data, stun-cancel cue; see DECISIONS "Slice 5b".
**5a BUILT (gameplay-dev, 2026-10-28), qa not yet run:** data-driven staged waves (`data/waves.json`, cap 12), spawn grace, golem capsule hurtbox (N1), depth-tested smaller HP bars, enemy team tint, enemy wind-up wedge and shot lane, arena walls, `tools/run_wave_sim.ps1`; details and numbers in DECISIONS "Slice 5a"; next is 5b (ux-designer).
**Slices 4 and 3b are DONE (closed 2026-10-28).** The director prompt's Parts A-C are complete, and the changelog exists. **Now: Slice 5, split into 5a/5b/5c (ROADMAP). 5a built (8e05395). 5b built (642b1ee). 5c: qa FAIL c13a43a, blocker S5-1 (bot-sim tool doesn't compile; the suite has one intentionally red test until it's fixed). Fix pass handed to gameplay-dev. Then the qa re-check, then the playtester.** Pending: D6 default A (golem wind-up 0.45 -> 0.7 s) goes to gameplay-dev at the start of the capture-tooling task, if the director hasn't answered.

## Exact next step
5a (gameplay-dev) -> 5b (ux-designer) -> 5c qa (incl. bot-sim) -> playtester -> game-lead picks the HP bar default and closes. Then the true-size capture tooling task (gameplay-dev -> qa), then the pass close-out (whole-pass playtester report). Then **Milestone 3a (run structure)**. Re-run the reload soak whenever Main, Juice, Player or the autoloads change. Update OPEN_ITEMS and CHANGELOG at every slice end.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead resumes the loop at the slice named above. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
Not blocking, need a feel check in a real window: balance proposals P1-P4 under Slice 3 in ROADMAP (spam-click 2.4x auto DPS; heavy DPS below light; root during heavy wind-up; auto light vs cheap cards). Proposed defaults: P1 and P4 keep as is unless they feel off live (data-only, cheap to reverse); P2 and P3 are design changes, director's call. Defaults unchanged until decided. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-polish1-slice3-attacks.md`. Director: please watch the death slow-mo once in a real window (follow-up s1-a: beat may be too subtle).
