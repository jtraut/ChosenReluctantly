# Handoff State

Last updated: 2026-10-27. **Milestone 2 is done.** Now running **Post-milestone polish 1** (director-approved, see `docs/ROADMAP.md`), slices 0-5. This is NOT Milestone 3.

## What's done
- Milestone 2 (combat feel prototype), the camera fix, HP bars above enemies, screenshot tooling (`tools/capture_screenshot.ps1`). Details in `git log`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- **Polish 1, Slice 0 (docs) - done** (a941ddd): GDD §9 reward offer (pick 1 of 3 or reject all, 3 rejects/run, offer size is data), §1 density principle, §3 light (auto + left click) / heavy (right click) attacks, new §15 parked survivor-style level-up idea (DO NOT IMPLEMENT). Roadmap has full briefs for slices 1-5.
- **Polish 1, Slice 2 (HUD layout) - done**: fixed slots, TextFit, safe margins, HP bar contrast; true-size HUD capture via `tools/vp_capture.gd` (no waves).
- **Polish 1, Slice 1 (death and game over) - done** (7ad85ee): `Player.player_died`, `Main.game_over_ready` / `restart_arena()` (scene reload), Game Over screen, "HP x / y" label, reload soak tool `tools/run_reload_cycle.ps1`.

## In progress
**Slice 1 done** (closed 2026-10-27; follow-ups s1-a..f in ROADMAP). **Slice 2 done** (closed 2026-10-27). **Slice 3 (auto light / manual heavy attack):** gameplay half done (1c12fd9, de415be; `data/attacks.json`, `AttackController`, Player API `get_attack_progress/is_attack_ready/get_attack_interval` + signals `attack_started/fired/ready/cancelled`, ids `&"light"`/`&"heavy"`; 149 tests green; reload soak OK). UI half done (AttackMeter LMB/RMB under HP bar, slot ready/cooling state, preview min font 10, whole HUD tree mouse IGNORE; 157 tests). **qa PASS** (ed0bf58; static-string BUG lines are pre-existing and only on `timeout` kills). **playtester delegated** (feel report). If cut off: check `docs/playtests/` for a Slice 3 report; if none, re-run playtester. Then game-lead close; carry qa's reach gap (hit reaches range + 0.45 hurtbox radius, wedge drawn to range) into Slice 4 criterion 4. True-size capture tooling task is in ROADMAP (gameplay-dev, before pass close-out). Repo runs at the latest commit.

## Exact next step
Slice 3 loop: gameplay-dev -> ux-designer (timer indicators, slot ready state, min font 10) -> qa -> playtester -> game-lead close. Then slices 4, 5, the capture tooling task, then the whole-pass playtester report. After the pass: **Milestone 3a (run structure)**. Re-run reload soak `tools/run_reload_cycle.ps1` whenever Main/Juice/Player/autoloads change.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead resumes the loop at the slice named above. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
None blocking. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-polish1-slice2-hud.md`. Director: please watch the death slow-mo once in a real window (follow-up s1-a: beat may be too subtle).
