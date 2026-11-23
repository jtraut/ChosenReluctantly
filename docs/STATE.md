# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-23 (TL3 briefed; TL3a with gameplay-dev; still waiting for the director's BD3b play). Latest tag `playtest-2026-11-20-BD3b`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **TL3a, sim logs and log nits** (ROADMAP "TL3", `safe to chain`, tools only): briefed 2026-11-23, handed to gameplay-dev. Nothing committed for it yet. The repo runs.

## Exact next step
1. gameplay-dev builds TL3a (ROADMAP "TL3" brief). Then qa (short), then TL3b (gameplay-dev), qa, a playtester smoke of the fixed capture presets, one tech-writer docs pass, close.
2. In parallel, waiting: the director's BD3b play ("The one ask" in OPEN_ITEMS). It unblocks BAL1 and BD3c (both `needs your play first`). When he has played, game-lead records his notes and writes the BAL1 brief. Inputs: the human Rogue 25/36 over its 21 ceiling, the DF1 ceiling text, leftover gold (median 496-535 even for the formulated bot).

**Next role:** gameplay-dev (TL3a).

## Current baselines (SIM2a-4 qa f6c9db1, 2026-11-21)
- Suite 2913 expected (2911 measured at SIM2a-4 qa plus its 2 cases; f6c9db1), 0 failures; a full run takes about 27 minutes, so run it in the background.
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 untouched).
- Formulated (`-BotProfile formulated`, pooled 36, SIM2a-4 ba86ffc..bbdcb09): human Rogue 22, Wizard 25; off 36, 34. `-Route first` human 24 / 17; shop off human 26 / 25; Wizard removals off 24.
- SIM1 `-Route first`: human Rogue 25/36 (over its 21 ceiling, waived for HP1, to BAL1), Wizard 19/36 (re-measured 87b944b and 1c5250f); off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). SIM1's human preset presses slots at random (no PlanPolicy).
- Fingerprint 0.79 with relics, 0.45 without (Rogue). W-B vs W-A 0.71 with relics; W-B parity 79%, removal pain +22% to +28%. W-D informational (D54 = A). Boss parity 92% / 109% / 106%.
- Relic medians (per seed 1/13/25): Rogue `relic` 14.5/14/14, `safe` 6/5/5.5, `first` 8.5/10/7.0; Wizard `relic` 15/14/14. Exactly 2 boss relics. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%. Relic Burn share 21.1% (4 of 19). Thesis Wizard late Fire share about 26%.

## Pending for the next docs pass
- None.

## Known issues
- **The game closed on its own during the director's run (2026-11-20, about 21:44), while gameplay-dev's SIM2a-3 sims ran from the same working tree.** The cause is unknown. Suspects: (a) the headless sims rewriting the shared `.godot` import cache while the game loads a room; (b) machine load from many parallel sims; (c) a real crash. The evidence is gone: the sims share `user://logs`, and Godot keeps only 5 log files, so his log rotated out. Fixes to schedule (a TL follow-up): the sims log to their own folder or disable file logging, and the director plays from a separate worktree of the tag (`git worktree add ../cr-play <tag>`) or while no agent runs.
- Tool header comments in `tools/run_wave_sim.ps1` and `tools/pool_formulated.ps1` don't mention `-FormulatedOff` or the `route=`/`off=` fields (qa and tech-writer, SIM2a-4); fix in the next gameplay-dev tooling sitting.
- Capture tooling gaps (UX1b playtest 2ae2d92), for a TL follow-up: the `act_transition` preset stalls on the boss relic screen (`relic_skip+skip` never advances; `relic:<id>+skip` does); there is no starting-HP flag (to shoot the act heal line hurt); there is no timed key press during a capture (to prove the map beat skip); `-AtBossAttack` takes `smash`/`slam`, not `ground_pound`.
- Next ux polish: a "now +N" readout for Performance Review (HP1); the Rogue's pink-red hit flash briefly reads as an enemy colour; a 6+ pile's HP bars and pips overlap each other (UX1b playtest).
- **Watch mode at `-Scale 4` makes the bot much weaker than headless** (off preset 2/4 wins in watch vs 35/36 and 31/36 in SIM1; human Wizard 0/3 vs 20/36). Don't read difficulty from fast watch runs: the next milestone playtest uses `-Scale 1-2` or headless SIM for difficulty. Fix the fidelity if it's cheap (TL2 follow-up).
- TL2 watch log nits (qa d2218fb): a bare `--watch-shots` is ignored; "HP at end" is stale on a loss; CROWD/BOSS lines use act-local room numbers; `crowded-fight.png` is overwritten. Fix when convenient.
- In `docs/playtests/img/ux1b/crowd-1152x648_0.png` an enemy overlaps the top edge of the bottom-right card strip (camera framing or card layering). Not fixed in UX1b; a later ux polish item.
- **BAL1: the SIM1 human Rogue is 25/36 after HP1, over its 21 ceiling** (waived for HP1, DECISIONS "HP1 build triage"). Thin margins to carry into BAL1: SIM1 human Wizard exactly at its ceiling (20/36), off Wizard 1 above its floor (31/30), Wizard `relic` median 14.0, W-B removal pain +22% to +28%.
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- An old git stash (`stash@{0}`, from 85cd564) is still in the repo; the director decides whether to drop it.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D55 answered. Next free: D56. No eyes open. Next eyes number: 68.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: the BD3b play; the round 2 vision check; and, under "Later, optional", a second boss per act and Battlemage as a Wizard subclass.
