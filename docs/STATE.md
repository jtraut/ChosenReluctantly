# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-18 (3d C accepted). Latest tag `playtest-2026-11-17-DF1`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **3d, loadouts.** Detailed brief written 2026-11-17 (ROADMAP 3d "Detailed brief"; DECISIONS "3d brief"). Five build sittings: gameplay-dev A -> B -> C -> ux D -> ux E, then qa -> playtester -> tech-writer -> close. Sittings A (eea038b..dc39f28), B (41b6b01..501dcd0), C (221768b, 68e38d6..25b010d), D (0bc25be..a95c3ac) and E (9eef38b..4e7f104) done; qa PASS (7e22f98, 0f2a0a2; `docs/reviews/2026-11-18-3d-qa.md`). The repo runs.

## Exact next step
1. **playtester, 3d playtest** (ROADMAP 3d "Playtester" line, plus DECISIONS "3d sitting E triage": is the editor's effect line enough without keywords?).
2. Then tech-writer docs pass (handoff: the pending list below, plus qa's README notes in the review), close with tag `playtest-YYYY-MM-DD-3d`. At close, eyes 59 expires (default kept). Then BD3b (D53 default A folds in there; N2 "Preset deck" text to data) and the Milestone 3 close.

**Next role:** playtester (3d).

## Current baselines (DF1 qa, 2026-11-17)
- Suite 2623 (186 suites), 0 failures, 0 orphans (3d qa).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 is untouched).
- SIM1 `-Route first`: human Rogue 18/36, Wizard 16/36; off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). Rogue losses in rooms 13-15: 8 of 18.
- Fingerprint 0.79 with relics (qa's BUILD_DEPTH relic sets, now canonical), 0.45 without. Boss parity 92% / 109% / 106%.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass
- 3d sitting A (eea038b..dc39f28): curse swap penalty 1.0 -> 2.0 s (curses only; ordinary stays 1.0; both in `data/run.json` `curses`; expired eyes 58 default). New `--run-curse-first=<id>`; `--run-auto-choose` and `--run-curse-first` are in the never-saves list; `sacrifice_giveup` capture preset; `-Run` report shows max HP per room; `-BossLog` names scaled boss hits. ARCHITECTURE: `CardSlot.current_swap_penalty`, `reveal_first`, `RunConfig.swap_penalty()`/`curse_swap_penalty()`.
- 3d sitting B (41b6b01..501dcd0): card `availability` field (48 starter, 17 reward, curses none; D52 default A); `starter` source on chasing_paper, spite_knuckles, ergonomic_chair, paperwork_fire; `data/loadouts.json` (5 slots, 2 copies, 15-20 cards, names 24); `user://profile.json` and `user://loadouts.json`; ARCHITECTURE: the `src/loadouts/` group.
- 3d sitting C (221768b, 68e38d6..25b010d): new `src/loadouts/` LoadoutArgs, LoadoutChoices, LoadoutDraft, LoadoutSession (the isolation point: in-memory unless a real windowed launch with no debug flag), LoadoutStart; `src/ui/StartScreen.gd`, `src/ui/LoadoutEditorScreen.gd` (placeholders); `RunMain.tscn` StartScreen node; `RunSession.next_loadout`, `RunController.confirm_start_choice`, `start_chosen` signal; RunState `plan`, `on_plan` on offers. README: flags `--runs-finished=N`, `--profile-path=`, `--loadouts-path=`, `--loadout=<n|preset>` (needs `--loadouts-path`), all in the never-touch-save/profile list; bad values exit 2 "Launch refused". Tests `threed_c_test.gd`, `threed_c_plan_test.gd`.
- 3d sitting D (0bc25be..a95c3ac): `StartScreen` rewritten (`rows_for`, `notes_for`, `StartRow`); `RunOptionCard` "On your plan" pill (`plan_tag`, `is_on_plan`); `data/run.json` `ui.start_screen` and `ui.option.on_plan_tag`; `threed_d_test.gd`; `h2_test.gd` resets `LoadoutSession`/`StartScreen` in `before_test`. README: the scratch-file capture recipe for the start screen and badges.
- 3d sitting E (9eef38b..4e7f104): `LoadoutEditorScreen` replaced (static model `badge_for`/`tiles_for`/`chips_for`/`tabs_for`/`plan_lines_for`, inner classes `ChoiceButton`, `CardRow`; `request_slot`/`request_close`/`request_delete`/`select_relic`/`set_loadout_name`/`is_dirty`); `data/run.json` `ui.loadout_editor`; `tools/ux_capture.gd` modes `loadout_editor_legal`/`loadout_editor_blocked` (`godot --path . res://tools/UxCapture.tscn -- --size=1024x600 --class=rogue --mode=loadout_editor_legal --out=<png>`); editor keys (Up/Down, Enter/click add, Delete/Backspace/Minus/right-click remove, Left/Right panels, Esc back, Ctrl+S save); `threed_e_test.gd`. StartScreen hides while the editor is open.
- 3d qa (7e22f98, 0f2a0a2): `after()` reset of `LoadoutSession`/`StartScreen` in 33 suites plus the guard `threed_qa_test.test_every_suite_that_can_end_a_run_resets_the_session`; UxCapture mode `shop_plan_act2`; review report `docs/reviews/2026-11-18-3d-qa.md`; README needs the 3d flags (incl. `--run-curse-first=<id>`), start screen and editor keys, capture recipes, new test counts.
- DF1 was covered by 6cdbfd3. The DF1 close moved eyes 58 to RESOLVED (6cdbfd3) and added eyes 59.
- [Director decision] 2026-11-17: SIM2 decision-skill bots, a "winging it" (random) profile against a "formulated" (synergy-seeking, good routes) profile, with a noticeable win-rate gap. Recorded in GDD §12 "Automated QA" and ROADMAP Milestone 4 SIM2; the defaults are in DECISIONS "SIM2 defaults". No code yet.

- [Director decision] 2026-11-18: D52 = A. Common cards are `starter`, rare and legendary are `reward` (what sitting B already shipped; no data change). Recorded in GDD §9 Loadouts. RESOLVED entry: the D52 text (options A/B/C, "if you don't answer: A") is in OPEN_ITEMS at 221768b.

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D52 answered; D53 open (starter relics, default A in BD3b). Next free: D54. Next eyes number: 60.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: D53 (starter relics); eyes 59 (play DF1; expires at 3d's close); the round 2 vision check.
