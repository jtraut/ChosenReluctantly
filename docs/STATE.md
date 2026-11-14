# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-13. Latest tag `playtest-2026-11-12-MAP3b`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- Nothing. **MAP4 closed 2026-11-13**, tag `playtest-2026-11-13-MAP4`. The repo runs.

## Exact next step
1. **game-lead writes the DF1 brief** (ROADMAP DF1). Its one gameplay-dev sitting starts with the MAP4 carry-overs in ROADMAP MAP4: the map-generator headroom and the act-change "win" on failure, curse casts not firing `card_cast`, the two debug flags missing from `RunSave.DEBUG_FLAG_PREFIXES`, and the three tooling bugs. Then the enemy knobs. **DF1 is `safe to chain` for its enemy tuning** (D51 = C is the director's ask), but the curse swap penalty 1 s -> 2 s waits for his eyes-58 play.
2. MAP4's ux readability carry-overs (ROADMAP MAP4) need a ux pass: fold into DF1's loop if it has room, else 3d's.
3. Then 3d, then BD3b, then the Milestone 3 close: the milestone playtest, then game-lead's own review of the report and screenshots (ROADMAP).

**Next role:** game-lead (DF1 brief), then gameplay-dev.

## Current baselines (MAP4 close, 2026-11-13)
- Suite 2478 (last full run 2477), 0 skipped, 0 orphans (about 22 min).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471.
- SIM1 `-Route first`: human Rogue 21/36 (on its 21 floor), Wizard 20/36; off 36/36, 35/36. Losses cluster in rooms 13-15.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act 278 / 312 / 568 (act 3 seeds 1001-4000: 751 of 1000).
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass (tech-writer, DF1)
- Nothing yet.

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.
- `--run-curses` and `--run-discount` don't count as debug flags yet, so a launch with only those can touch the real run save (fix at DF1's start).
- A map-generator failure at an act change ends the run as a win (no seed fails today; fix at DF1's start).

**D-numbers:** D21-D51 answered. Next free: D52. Next eyes number: 59.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions open; eyes 58 (play MAP4; expires at DF1's close); the round 2 vision check.
