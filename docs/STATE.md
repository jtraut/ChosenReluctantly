# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-18 (3d C accepted). Latest tag `playtest-2026-11-17-DF1`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **3d, loadouts.** Detailed brief written 2026-11-17 (ROADMAP 3d "Detailed brief"; DECISIONS "3d brief"). Five build sittings: gameplay-dev A -> B -> C -> ux D -> ux E, then qa -> playtester -> tech-writer -> close. Sittings A (eea038b..dc39f28), B (41b6b01..501dcd0) and C (221768b, 68e38d6..25b010d) done. The repo runs.
- **The full suite hasn't been re-run since C's last fix** (25b010d; the h2 start-screen failure was checked on 3 suites only). ux D runs it first.

## Exact next step
1. **ux-designer sitting D** (ROADMAP 3d, ux sitting D): first run the full suite (expect about 2582, 0 failures). Then the real start screen, replacing `src/ui/StartScreen.gd`'s placeholder and reusing `LoadoutChoices.start_choices`, and the "On your plan" badge on reward, mini-boss and merchant tiles (`on_plan` flag). Reach the screen with `--class=rogue --runs-finished=1 --profile-path=<scratch> --loadouts-path=<scratch>`.
2. Then ux E (editor), qa, playtester, tech-writer, close. Then BD3b and the Milestone 3 close.

**Next role:** ux-designer (3d sitting D).

## Current baselines (DF1 qa, 2026-11-17)
- Suite 2581 (183 suites) at 3d C, 2 failures in one h2 test (fixed in 25b010d, full re-run pending); 2544 / 181 / 0 failures at 3d B (about 21 min).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 is untouched).
- SIM1 `-Route first`: human Rogue 18/36, Wizard 16/36; off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). Rogue losses in rooms 13-15: 8 of 18.
- Fingerprint 0.79 with relics (qa's BUILD_DEPTH relic sets, now canonical), 0.45 without. Boss parity 92% / 109% / 106%.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass
- 3d sitting A (eea038b..dc39f28): curse swap penalty 1.0 -> 2.0 s (curses only; ordinary stays 1.0; both in `data/run.json` `curses`; expired eyes 58 default). New `--run-curse-first=<id>`; `--run-auto-choose` and `--run-curse-first` are in the never-saves list; `sacrifice_giveup` capture preset; `-Run` report shows max HP per room; `-BossLog` names scaled boss hits. ARCHITECTURE: `CardSlot.current_swap_penalty`, `reveal_first`, `RunConfig.swap_penalty()`/`curse_swap_penalty()`.
- 3d sitting B (41b6b01..501dcd0): card `availability` field (48 starter, 17 reward, curses none; D52 default A); `starter` source on chasing_paper, spite_knuckles, ergonomic_chair, paperwork_fire; `data/loadouts.json` (5 slots, 2 copies, 15-20 cards, names 24); `user://profile.json` and `user://loadouts.json`; ARCHITECTURE: the `src/loadouts/` group.
- 3d sitting C (221768b, 68e38d6..25b010d): new `src/loadouts/` LoadoutArgs, LoadoutChoices, LoadoutDraft, LoadoutSession (the isolation point: in-memory unless a real windowed launch with no debug flag), LoadoutStart; `src/ui/StartScreen.gd`, `src/ui/LoadoutEditorScreen.gd` (placeholders); `RunMain.tscn` StartScreen node; `RunSession.next_loadout`, `RunController.confirm_start_choice`, `start_chosen` signal; RunState `plan`, `on_plan` on offers. README: flags `--runs-finished=N`, `--profile-path=`, `--loadouts-path=`, `--loadout=<n|preset>` (needs `--loadouts-path`), all in the never-touch-save/profile list; bad values exit 2 "Launch refused". Tests `threed_c_test.gd`, `threed_c_plan_test.gd`.
- DF1 was covered by 6cdbfd3. The DF1 close moved eyes 58 to RESOLVED (6cdbfd3) and added eyes 59.
- [Director decision] 2026-11-17: SIM2 decision-skill bots, a "winging it" (random) profile against a "formulated" (synergy-seeking, good routes) profile, with a noticeable win-rate gap. Recorded in GDD §12 "Automated QA" and ROADMAP Milestone 4 SIM2; the defaults are in DECISIONS "SIM2 defaults". No code yet.

- [Director decision] 2026-11-18: D52 = A. Common cards are `starter`, rare and legendary are `reward` (what sitting B already shipped; no data change). Recorded in GDD §9 Loadouts. RESOLVED entry: the D52 text (options A/B/C, "if you don't answer: A") is in OPEN_ITEMS at 221768b.

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D52 answered. Next free: D53. Next eyes number: 60.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: eyes 59 (play DF1; expires at 3d's close); the round 2 vision check.
