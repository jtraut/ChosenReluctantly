# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-24 (director's M4b play notes recorded; UX1d briefed). Latest tag `playtest-2026-11-23-M4b`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **Nothing in progress.** UX1d closed 2026-11-24 (no map auto-start; docs pass 72f6478). The repo runs. After pulling, run `godot --headless --path . --import` once. The director's play build is still `playtest-2026-11-23-M4b`; UX1d rides in the next tag.

## Exact next step
1. **game-lead writes the BAL1 brief** (unblocked by the director's M4b play). Inputs: the human Rogue 25/36 over its 21 ceiling, the DF1 ceiling text, leftover gold (median 496-535 even for the formulated bot), HP1's relic numbers, BD3b's "Deferred" list. BAL1 must not tune the Battlemage deck away from how it plays now while D56 is open.
2. **BD3c waits on D56.** The TL4 qa nits, the hit-flash capture hook and retiring the stale `map_beat_skip` preset (with its `tl3b_capture_test` case; also fix the `map_mini_boss` preset description) wait for an optional tools sitting (`safe to chain`).

**Next role:** game-lead (BAL1 brief), then gameplay-dev.

## Current baselines (SIM2a-4 qa f6c9db1, 2026-11-21; suite from TL4 qa f072262)
- Suite 2966 in 221 suites measured (UX1d qa 1c2bee7), 0 failures; a full run takes about 23-27 minutes, so run it in the background.
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 untouched).
- Formulated (`-BotProfile formulated`, pooled 36, SIM2a-4 ba86ffc..bbdcb09): human Rogue 22, Wizard 25; off 36, 34. `-Route first` human 24 / 17; shop off human 26 / 25; Wizard removals off 24.
- SIM1 `-Route first`: human Rogue 25/36 (over its 21 ceiling, waived for HP1, to BAL1), Wizard 19/36 (re-measured 87b944b and 1c5250f); off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). SIM1's human preset presses slots at random (no PlanPolicy).
- Fingerprint 0.79 with relics, 0.45 without (Rogue). W-B vs W-A 0.71 with relics; W-B parity 79%, removal pain +22% to +28%. W-D informational (D54 = A). Boss parity 92% / 109% / 106%.
- Relic medians (per seed 1/13/25): Rogue `relic` 14.5/14/14, `safe` 6/5/5.5, `first` 8.5/10/7.0; Wizard `relic` 15/14/14. Exactly 2 boss relics. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%. Relic Burn share 21.1% (4 of 19). Thesis Wizard late Fire share about 26%.

## Pending for the next docs pass
- None. (README's older "Last verification" section still shows UX1c-era figures; refresh at BAL1's pass.)

## Known issues
- **The game closed on its own during the director's run (2026-11-20, about 21:44), while gameplay-dev's SIM2a-3 sims ran from the same working tree.** Cause unknown; the evidence rotated out. TL3a (293572a) stops tools writing to `user://logs`, so a future game log survives. The shared `.godot` import cache suspect remains: the director plays from a separate worktree of the tag (`git worktree add ../cr-play <tag>`) or while no agent runs.
- Next ux polish: a "now +N" readout for Performance Review (HP1).
- In `docs/playtests/img/ux1b/crowd-1152x648_0.png` an enemy overlaps the top edge of the bottom-right card strip (camera framing or card layering). Not fixed in UX1b; a later ux polish item.
- **BAL1: the SIM1 human Rogue is 25/36 after HP1, over its 21 ceiling** (waived for HP1, DECISIONS "HP1 build triage"). Thin margins to carry into BAL1: SIM1 human Wizard exactly at its ceiling (20/36), off Wizard 1 above its floor (31/30), Wizard `relic` median 14.0, W-B removal pain +22% to +28%.
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- An old git stash (`stash@{0}`, from 85cd564) is still in the repo; the director decides whether to drop it.
- ScreenshotCapture restarts its clock on a scene swap, so `map_beat_skip`'s 2.0 s shot fires about 2 s after the swap (TL4 note; not a blocker).
- Watch mode at `-Scale 4`: `_process`-driven systems (spawner, statuses, boss) still step once per rendered frame. That costs 1-2 `src` sittings, only if the numbers ever call for it (TL4).
- TL4 qa nits (f072262, non-blocking): the watch restore tests only grep the source (a try/finally or save-and-restore of the originals would be sturdier); parallel watched runs share `user://run_save.json` and log a warning, which can make a won batch exit 1 (run watched runs one at a time); `tools/run_tests.ps1` isn't job-guarded.
- UX1c smoke (76be1c5), minor: the ready and cooling card plates are now close in tone, so cooling reads only through dimmed text and the bar (a stronger cooling cue if players miss it); a live check of a Wizard hit right after its violet Heavy; a 7-pile bar tower under the status text near the top of the screen in a real fight; `ux1c_hit` captures can't time the 0.15 s flash (a capture hook to hold it).
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D55 answered; D56 open (BD3c rework). Next free: D57. No eyes open. Next eyes number: 71.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: D56; the round 2 vision check and a timed run; under "Later, optional", class names and the research digest.
