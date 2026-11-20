# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-20 (TL1 qa PASS ad617bf; TL2 next). Latest tag `playtest-2026-11-20-BD3b`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- TL1 built (77e3c9d), qa PASS ad617bf with TL1-1: **ad617bf commits a red test** (`tl1_qa_test.gd` mid-hold release), fixed first in TL2. TL1 closes with TL2. BD3b closed 2026-11-20 (ROADMAP; docs pass c84792b..bd45c08). The repo runs.

## Exact next step
1. **TL2, watch-the-bot mode** (ROADMAP, under TL1; `safe to chain`): gameplay-dev, one sitting, TL1-1 fix as its first commit. Then qa (short), a playtester smoke check of the mode, one tech-writer docs pass for TL1+TL2, close. Eyes 61 expires at TL2's close.
2. Then the Milestone 3 close: milestone playtest (a full three-act run per class; this report is the baseline), docs pass including the ARCHITECTURE trim (540 lines, target about 400), then a fresh game-lead session reads the report and screenshots before the Milestone 4 brief. BD3c (Battlemage rework, D54) and BAL1 come after the milestone playtest.

**Next role:** gameplay-dev (TL2).

## Current baselines (BD3b qa 664bfec, 2026-11-19)
- Suite 2796 (202 suites), 0 failures; a full run takes about 23 minutes, so run it in the background.
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 untouched).
- SIM1 `-Route first`: human Rogue 19/36, Wizard 20/36 (at the ceiling); off 35/36, 31/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). SIM1's human preset presses slots at random (no PlanPolicy).
- Fingerprint 0.79 with relics, 0.45 without (Rogue). W-B vs W-A 0.71 with relics; W-B parity 79%, removal pain +22% to +28%. W-D informational (D54 = A). Boss parity 92% / 109% / 106%.
- Relic medians (per seed 1/13/25): Rogue `relic` 14.5/14/14, `safe` 6/5/5.5, `first` 8.5/10/7.5; Wizard `relic` 14.5/13.5/14. Exactly 2 boss relics. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%. Relic Burn share 21.1% (4 of 19). Thesis Wizard late Fire share about 26%.

## Pending for the next docs pass
- None from BD3b (all covered in c84792b..bd45c08). Carry: the ARCHITECTURE trim at the Milestone 3 close.
- TL1 (77e3c9d): README `--press` row gets the new grammar (gameplay-dev's exact text is in the TL1 commit's hand-back, copied here): `<t>:<action>` taps, `<t>:<action>:<hold>` holds 0 < hold <= 120 s, same-t holds make diagonals, `<t>:aim_nearest` until `<t>:aim_off`; InputMap names move_forward/back/left/right, attack_light, attack_heavy, slot_1..slot_5, dodge; a debug flag; bad steps exit 2 "Launch refused: ..."; the console logs the player's (x, z) per step; example `-- --class=rogue --no-map --run-room=1 --press=0.5:aim_nearest,0.5:move_forward:1.2,2:attack_light,3:slot_1`. `capture_screenshot.ps1 -Actions` takes the same grammar. Add `tests/unit/tl1_press_test.gd`. CHANGELOG: TL1 entry, incl. the save-gap fix. ARCHITECTURE: `ScriptedInput` holds and aim, `Player.aim_point_override`, `CaptureArgs` `press_error`.

## Known issues
- Next ux polish (from BD3b qa and playtest): "Swap: free" shows permanently, so hide it on ready cards; two-letter relic badges are unreadable in combat; hide "Swap: free" and the curse swap line while swaps are locked; add a non-colour Fire mark for Kindling and Hot Head; capture the 3+ starter relic label and 1366x768.
- Thin margins to carry into BAL1: SIM1 human Wizard exactly at its ceiling (20/36), off Wizard 1 above its floor (31/30), Wizard `relic` median 14.0, W-B removal pain +22% to +28%.
- `w1a_test.gd` `test_the_wizard_bolt_does_not_reach_past_its_12_m_range...` failed once in a full run (32 s) and passes alone; qa re-runs it on a quiet machine.
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- An old git stash (`stash@{0}`, from 85cd564) is still in the repo; the director decides whether to drop it.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D54 answered. Next free: D55. Next eyes number: 62.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions; eyes 61 (Thesis's hit; expires at TL2's close); the round 2 vision check; and, under "Later, optional", Battlemage as a Wizard subclass (GDD §6).
