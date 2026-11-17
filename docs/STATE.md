# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-17. Latest tag `playtest-2026-11-17-DF1`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- Nothing. **DF1 closed 2026-11-17**, tag `playtest-2026-11-17-DF1` (ROADMAP DF1; DECISIONS "DF1 close"). The repo runs.

## Exact next step
1. **game-lead: write 3d's detailed brief** (ROADMAP 3d, loadouts). Its first gameplay-dev sitting takes the DF1 carry-overs (ROADMAP DF1 "Carry-overs to 3d"): the curse swap penalty 1 s -> 2 s with a SIM1 re-check, plus the tooling items. Size it under 150 tool calls per sitting. Tag it `safe to chain` or `needs your play first`: the swap penalty is now a default from an expired eyes item, so it doesn't wait on the director.
2. Then BD3b, then the Milestone 3 close (milestone playtest).

**Next role:** game-lead (3d brief).

## Current baselines (DF1 qa, 2026-11-17)
- Suite 2490 (178 suites), 0 failures, 0 skipped, 0 orphans (about 21 min).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 is untouched).
- SIM1 `-Route first`: human Rogue 18/36, Wizard 16/36; off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). Rogue losses in rooms 13-15: 8 of 18.
- Fingerprint 0.79 with relics (qa's BUILD_DEPTH relic sets, now canonical), 0.45 without. Boss parity 92% / 109% / 106%.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass
- Nothing yet. DF1 was covered by 6cdbfd3. The DF1 close moved eyes 58 to RESOLVED (6cdbfd3) and added eyes 59.

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- Tooling: no flag puts a curse first in a slot, and `--run-auto-choose` doesn't reach the sacrifice give-up step. Both go to 3d.
- The Wizard three-act sim prints "HP at each room end" 22.0 against a header max of 20.0. Undiagnosed; goes to 3d.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D51 answered. Next free: D52. Next eyes number: 60.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions open; eyes 59 (play DF1; expires at 3d's close); the round 2 vision check.
