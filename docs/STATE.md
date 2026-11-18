# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-18 (3d closed). Latest tag `playtest-2026-11-18-3d`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- Nothing in flight. **3d closed 2026-11-18**, tag `playtest-2026-11-18-3d`. The repo runs.

## Exact next step
1. **game-lead writes the BD3b brief** in ROADMAP (BD3 entry, line ~853; BUILD_DEPTH §9a). Fold in:
   - **BD3b-0**, a ux polish sitting with the list in DECISIONS "3d playtest triage";
   - D53 (default A: the four starter relics become `["starter"]`-only, then re-check SIM1 and the hashes);
   - N2 ("Preset deck" text to data);
   - Filing Cabinet zeroing both swap penalties;
   - the ARCHITECTURE trim (tech-writer, 520 lines against ~400).
   - Tag each sitting `safe to chain` or `needs your play first`. DF1's balance is unplayed by the director (59 expired), so judge whether BD3b's relic tuning waits.
2. BD3b, then the Milestone 3 close and milestone playtest (CLAUDE.md, milestone boundary).

**Next role:** game-lead (BD3b brief).

## Current baselines (DF1 qa, 2026-11-17)
- Suite 2623 (186 suites), 0 failures, 0 orphans (3d qa).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 is untouched).
- SIM1 `-Route first`: human Rogue 18/36, Wizard 16/36; off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). Rogue losses in rooms 13-15: 8 of 18.
- Fingerprint 0.79 with relics (qa's BUILD_DEPTH relic sets, now canonical), 0.45 without. Boss parity 92% / 109% / 106%.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass
- Nothing. The 3d pass (38092f0, b061b42) covered everything.
- When BD3b-0 ships, tech-writer removes the 3d polish list from the "Known issues" in CHANGELOG and ARCHITECTURE.

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D52 answered; D53 open (starter relics, default A in BD3b). Next free: D54. Next eyes number: 61.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: D53 (starter relics); eyes 60 (play 3d; expires at BD3b's close); the round 2 vision check.
