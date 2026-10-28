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
**qa 6c (2026-10-28): 5d re-check PASS (S5d-1, S5d-2, F1, F3 resolved); Slice 6 FAIL on two small blockers: S6-1 (attack click latched before a pause fires on resume) and S6-2 (dash preview 4.0 m but the player coasts to about 8.1 m). Report `docs/reviews/2026-10-28-polish1-slice6-qa.md`; 2 qa tests in `tests/unit/slice6_qa_test.gd` are red on purpose until gameplay-dev fixes; also S6-4 (seeded sim runs do not repeat) for game-lead.**
**6b built (ux-designer, 2026-10-28): Esc settings screen (cast-trigger toggle), preview look (player-element outline, dims when not ready, over enemies), D7 applied, player occlusion cue; suite green, soak and 20 s run clean; waiting on 6c (qa). See DECISIONS "Slice 6b".**
**6a built (gameplay-dev, 2026-10-28): settings store (`Settings`, `data/settings.json`), press/hold/release card input latched in `_unhandled_input`, held cast preview (`CastPreview`, `get_preview_state()`), `GamePause` + Juice freeze/thaw; suite green, sims clean; waiting on 6b (ux) then 6c (qa). See DECISIONS "Slice 6a".**
**5d qa-FAIL fix pass done (gameplay-dev, 2026-10-28): S5d-1, S5d-2, F1, F3 fixed in 5 commits; 435/435 green x3; sims clean; waiting on qa re-check. F2 still open.**
**qa 5d (2026-10-28): FAIL, two small blockers (S5d-1 unclamped waiting-slide speed; S5d-2 `validate_stats` never called). Report `docs/reviews/2026-10-28-polish1-5d-qa.md`. 2 qa regression tests in `tests/unit/slice5d_qa_test.gd` are red on purpose; gameplay-dev fixes, then qa re-checks.**
**5d built (gameplay-dev, 2026-10-28): separation steering (`data/enemies.json` `separation`), TrainingDummy out of Main, enemy combat stats in data; 426/426, soaks and sims clean; waiting on qa (targeted). Follow-up: the player can still be partly hidden behind bodies in the iso view (a player outline is not built).**
**Slices 4, 3b and 5 are DONE (2026-10-28).** The director answered D1-D7 on 2026-10-28. D7 = B gets applied in 6b. **5d built (0ca0afb). qa FAIL 8751371: S5d-1, S5d-2 blockers, F1 should-fix (2 intentionally red qa tests until fixed). Fix pass done (b1383f0, 435/435 x3). The 5d re-check is folded into 6c qa. 6a built (4f5220e, 495/495). 6b built (567cdc4). 5d closed (re-check PASS). **Slice 6 qa FAIL (S6-1, S6-2), with 2 intentionally red tests. Fix pass handed to gameplay-dev**, then the qa re-check. Note: `.claude/agents/tech-writer.md` is untracked; it's the director's file, so it's left alone.

## Exact next step
5d gameplay-dev -> qa (targeted) -> **Slice 6 (hold-to-preview + settings, director D2 = C; 6b also applies D7 = B)** -> the true-size capture tooling task (gameplay-dev -> qa) -> pass close-out: one whole-pass playtester report (covering 5d too), DoD verified, OPEN_ITEMS/CHANGELOG updated, STATE pointed at **Milestone 3a (run structure)**. Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**Orchestration:** game-lead now has the `Agent` tool (`.claude/agents/game-lead.md`). Restart with `claude --agent game-lead` and say "continue Post-milestone polish 1"; game-lead resumes the loop at the slice named above. Don't run the per-role sessions on the same slice at the same time (shared working tree and git).

## Open questions for the director
Not blocking, need a feel check in a real window: balance proposals P1-P4 under Slice 3 in ROADMAP (spam-click 2.4x auto DPS; heavy DPS below light; root during heavy wind-up; auto light vs cheap cards). Proposed defaults: P1 and P4 keep as is unless they feel off live (data-only, cheap to reverse); P2 and P3 are design changes, director's call. Defaults unchanged until decided. Carried over from before: damage-number readability and ghost-segment visibility follow-ups (HP bars, ROADMAP follow-ups (e)/(f)) are unscheduled.

Latest playtest report: `docs/playtests/2026-10-27-polish1-slice3-attacks.md`. Director: please watch the death slow-mo once in a real window (follow-up s1-a: beat may be too subtle).
