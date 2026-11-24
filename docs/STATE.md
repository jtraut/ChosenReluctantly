# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-23 (TL4 briefed; gameplay-dev building, while the director plays M4a). Latest tag `playtest-2026-11-23-M4a`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **TL4, watch-mode fidelity and TL3b nits** (ROADMAP; DECISIONS "TL4 brief"). Optional `safe to chain` work while the director plays `playtest-2026-11-23-M4a`. The repo runs.
  - **Built:** gameplay-dev 0eeb22f, 3103566, 92e9342 (the cadence fix, nits 3 and 4) and the remainder sitting after f78f27c (nit 1: ScriptedInput replayed its presses after a scene swap, now carried across; nit 2 test; a kill-on-close Job Object in both wrappers). Watched off-preset `-Scale 4`: 2/4 before the fix (old cadence), 4/4 after. Hashes unchanged. Suite 2949, 0 failures. **qa PASS f072262** (`docs/reviews/2026-11-23-tl4-qa.md`): hashes and SIM1 25/19/34/34 unchanged after the job guard; watched off Rogue 4/4 at both `-Scale 1` and `-Scale 4`, about 60 decisions per game-second at both; suite 2952 / 218.

## Exact next step
1. tech-writer docs pass for TL4 (0eeb22f..f072262), then close. No tag.
2. Then UX1c, a ux polish sitting from Known issues (display only; brief not yet written).
3. **Still waiting on the director's play of `playtest-2026-11-23-M4a`** ("The one ask"). It unblocks BAL1 and BD3c (`needs your play first`). BAL1 inputs: the human Rogue 25/36 over its 21 ceiling, the DF1 ceiling text, leftover gold (median 496-535 even for the formulated bot), HP1's relic numbers.

**Next role:** tech-writer (TL4 docs pass).

## Current baselines (SIM2a-4 qa f6c9db1, 2026-11-21; suite from TL4 qa f072262)
- Suite 2952 in 218 suites (TL4 qa f072262), 0 failures; a full run takes about 23-27 minutes, so run it in the background.
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 untouched).
- Formulated (`-BotProfile formulated`, pooled 36, SIM2a-4 ba86ffc..bbdcb09): human Rogue 22, Wizard 25; off 36, 34. `-Route first` human 24 / 17; shop off human 26 / 25; Wizard removals off 24.
- SIM1 `-Route first`: human Rogue 25/36 (over its 21 ceiling, waived for HP1, to BAL1), Wizard 19/36 (re-measured 87b944b and 1c5250f); off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). SIM1's human preset presses slots at random (no PlanPolicy).
- Fingerprint 0.79 with relics, 0.45 without (Rogue). W-B vs W-A 0.71 with relics; W-B parity 79%, removal pain +22% to +28%. W-D informational (D54 = A). Boss parity 92% / 109% / 106%.
- Relic medians (per seed 1/13/25): Rogue `relic` 14.5/14/14, `safe` 6/5/5.5, `first` 8.5/10/7.0; Wizard `relic` 15/14/14. Exactly 2 boss relics. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%. Relic Burn share 21.1% (4 of 19). Thesis Wizard late Fire share about 26%.

## Pending for the next docs pass
- README "Last verification" and the "Running tests" suite count are stale (2869 / 2813; now 2952 in 218 suites). In the TL4 handoff.

## Known issues
- **The game closed on its own during the director's run (2026-11-20, about 21:44), while gameplay-dev's SIM2a-3 sims ran from the same working tree.** Cause unknown; the evidence rotated out. TL3a (293572a) stops tools writing to `user://logs`, so a future game log survives. The shared `.godot` import cache suspect remains: the director plays from a separate worktree of the tag (`git worktree add ../cr-play <tag>`) or while no agent runs.
- Next ux polish: a "now +N" readout for Performance Review (HP1); the Rogue's pink-red hit flash briefly reads as an enemy colour; a 6+ pile's HP bars and pips overlap each other (UX1b playtest).
- **(TL4 fixes this; drop it at close)** **Watch mode at `-Scale 4` makes the bot much weaker than headless** (off preset 2/4 watched vs 35/36 SIM1). TL3b finding (d6122ba): not reproduced headless at `-Scale 4` (4/4). Likely cause, unconfirmed: the windowed bot decides once per rendered frame (`tools/wave_sim.gd` `await process_frame`), so at scale 4 it reacts at about 15 Hz of game time. Next: a windowed A/B with vsync off; fix about 0.5-1 sitting (decision step on physics ticks, or a windowed-only tick), with a hash re-check. Until then, judge difficulty at `-Scale 1-2` or headless.
- In `docs/playtests/img/ux1b/crowd-1152x648_0.png` an enemy overlaps the top edge of the bottom-right card strip (camera framing or card layering). Not fixed in UX1b; a later ux polish item.
- **BAL1: the SIM1 human Rogue is 25/36 after HP1, over its 21 ceiling** (waived for HP1, DECISIONS "HP1 build triage"). Thin margins to carry into BAL1: SIM1 human Wizard exactly at its ceiling (20/36), off Wizard 1 above its floor (31/30), Wizard `relic` median 14.0, W-B removal pain +22% to +28%.
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- An old git stash (`stash@{0}`, from 85cd564) is still in the repo; the director decides whether to drop it.
- (TL4 fixes these; drop them at close) TL3b qa nits (5bcb17a): `press any_key` logs twice when the tap swaps the scene (harmless, F13 unbound; look if a bound action is pressed at a scene swap); the `act_transition` test checks the preset string only, not that seed 1 still offers `burnout_syndrome`; the `leveraged_dash` alias is unreachable; `-AtBossAttack` with no boss attack waits for ANCHOR_TIMEOUT and can orphan the Godot child if the wrapper is killed. Fix in the next tooling sitting.
- ScreenshotCapture restarts its clock on a scene swap, so `map_beat_skip`'s 2.0 s shot fires about 2 s after the swap (TL4 note; not a blocker).
- Watch mode at `-Scale 4`: `_process`-driven systems (spawner, statuses, boss) still step once per rendered frame. That costs 1-2 `src` sittings, only if the numbers ever call for it (TL4).
- TL4 qa nits (f072262, non-blocking): the watch restore tests only grep the source (a try/finally or save-and-restore of the originals would be sturdier); parallel watched runs share `user://run_save.json` and log a warning, which can make a won batch exit 1 (run watched runs one at a time); `tools/run_tests.ps1` isn't job-guarded.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D55 answered. Next free: D56. No eyes open. Next eyes number: 68.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: the BD3b play; the round 2 vision check; and, under "Later, optional", a second boss per act and Battlemage as a Wizard subclass.
