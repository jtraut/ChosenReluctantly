# Handoff State

Last updated: 2026-10-28. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- **Polish 1, Slice 3 (attacks) - done**: `data/attacks.json`, auto light (LMB), manual heavy (RMB) with wind-up, LMB/RMB meters, slot ready/cooling state.
- **Polish 1, Slice 2 (HUD layout) - done**: fixed slots, TextFit, safe margins, HP bar contrast; true-size HUD capture via `tools/vp_capture.gd` (no waves).
- **Polish 1, Slice 1 (death and game over) - done** (7ad85ee): `Player.player_died`, `Main.game_over_ready` / `restart_arena()` (scene reload), Game Over screen, "HP x / y" label, reload soak tool `tools/run_reload_cycle.ps1`.

## In progress
**4a DONE by gameplay-dev (2026-10-28), awaiting game-lead to mark ROADMAP:** all five items committed (card_cast scenario; EffectPool + `data/vfx.json`; element `visual` in `data/pools.json`; `VfxSizing` + visual-vs-hitbox tests; s3-a wedge to effective reach). Only aoe (disc + cosmetic burst) and cone cards (wedge) are wired through the pool; projectile is sized correctly but not pooled/recolored yet. Remaining visuals are 4b. Tests 187/187, reload soak OK.

**Slice 4 IN PROGRESS.** Split into 4a/4b/4c/4d (ROADMAP Slice 4 "Sub-steps", DECISIONS 2026-10-28). **4a built (91587d5). 4b (template visuals) handed to gameplay-dev 2026-10-28.** Check `git log` for 4a commits; if 4a is not marked done in ROADMAP, it may be half done: read the latest gameplay-dev commit/STATE note before resuming. Criterion 6 (hold-to-preview) proposal logged, no code. Repo runs at the latest commit.

## Exact next step
Finish 4a (gameplay-dev) -> 4b (gameplay-dev) -> 4c (gameplay-dev aim data if missing, then ux-designer) -> 4d qa (whole slice) -> playtester -> game-lead close. Then slice 5, the capture tooling task, then the whole-pass playtester report. After the pass: **Milestone 3a (run structure)**. Re-run reload soak `tools/run_reload_cycle.ps1` whenever Main/Juice/Player/autoloads change.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead resumes the loop at the slice named above. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
Not blocking, need a feel check in a real window: balance proposals P1-P4 under Slice 3 in ROADMAP (spam-click 2.4x auto DPS; heavy DPS below light; root during heavy wind-up; auto light vs cheap cards). Proposed defaults: P1 and P4 keep as is unless they feel off live (data-only, cheap to reverse); P2 and P3 are design changes, director's call. Defaults unchanged until decided. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-polish1-slice3-attacks.md`. Director: please watch the death slow-mo once in a real window (follow-up s1-a: beat may be too subtle).
