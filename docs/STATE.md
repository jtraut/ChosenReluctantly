# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-20 (UX1b fixes in; qa re-review next). Latest tag `playtest-2026-11-20-BD3b`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **UX1b: fixes in** (ux 69fafd7, 57660d4) after qa FAIL b7b102c. qa re-review is next. Nothing half done; the repo runs.

## Exact next step
1. qa re-reviews UX1b, with the full suite (StatusStackLabel and `tools/wave_sim.gd` changed).
2. Then playtester smoke check -> docs -> close (eyes 65 expires at UX1b's close). Then HP1, then SIM2a. BAL1 and BD3c wait for the director's play of BD3b.

**Next role:** qa (UX1b re-review).

## Current baselines (BD3b qa 664bfec, 2026-11-19)
- Suite 2847 (UX1b qa b7b102c), 0 failures; a full run takes about 23 minutes, so run it in the background.
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 untouched).
- SIM1 `-Route first`: human Rogue 19/36, Wizard 20/36 (at the ceiling); off 35/36, 31/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). SIM1's human preset presses slots at random (no PlanPolicy).
- Fingerprint 0.79 with relics, 0.45 without (Rogue). W-B vs W-A 0.71 with relics; W-B parity 79%, removal pain +22% to +28%. W-D informational (D54 = A). Boss parity 92% / 109% / 106%.
- Relic medians (per seed 1/13/25): Rogue `relic` 14.5/14/14, `safe` 6/5/5.5, `first` 8.5/10/7.5; Wizard `relic` 14.5/13.5/14. Exactly 2 boss relics. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%. Relic Burn share 21.1% (4 of 19). Thesis Wizard late Fire share about 26%.

## Pending for the next docs pass
- Setting and tone [Director decision, 2026-11-20]: GDD §11 "Tone" and "Setting", §14 item 10 resolved, §15 "Corporate setting" update, and the story and art role files. Eyes 66 added (the "lightly offensive" line).

## Known issues
- **Watch mode at `-Scale 4` makes the bot much weaker than headless** (off preset 2/4 wins in watch vs 35/36 and 31/36 in SIM1; human Wizard 0/3 vs 20/36). Don't read difficulty from fast watch runs: the next milestone playtest uses `-Scale 1-2` or headless SIM for difficulty. Fix the fidelity if it's cheap (TL2 follow-up).
- TL2 watch log nits (qa d2218fb): a bare `--watch-shots` is ignored; "HP at end" is stale on a loss; CROWD/BOSS lines use act-local room numbers; `crowded-fight.png` is overwritten. Fix when convenient.
- In `docs/playtests/img/ux1b/crowd-1152x648_0.png` an enemy overlaps the top edge of the bottom-right card strip (camera framing or card layering). Not fixed in UX1b; a later ux polish item.
- Thin margins to carry into BAL1: SIM1 human Wizard exactly at its ceiling (20/36), off Wizard 1 above its floor (31/30), Wizard `relic` median 14.0, W-B removal pain +22% to +28%.
- `w1a_test.gd` bolt-range flake: not reproduced in the UX1b full run or alone (qa b7b102c). Watch for it.
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- An old git stash (`stash@{0}`, from 85cd564) is still in the repo; the director decides whether to drop it.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D55 answered. Next free: D56. Eyes 65 and 66 open. Next eyes number: 67.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: eyes 65; the round 2 vision check; and, under "Later, optional", a second boss per act and Battlemage as a Wizard subclass.
