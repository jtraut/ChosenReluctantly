# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-12. Latest tag `playtest-2026-11-12-MAP3b`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- Nothing. MAP3b closed 2026-11-12. The repo runs.

## Exact next step
1. **MAP4 (events). game-lead writes the detailed brief** in the ROADMAP MAP4 entry, split into sittings of one agent session each (under about 150 tool calls), and tags it `safe to chain` or `needs your play first`. Expected tag: `safe to chain`. Its tuning (Raider, D49) comes from the director's own MAP3b play.
2. **gameplay-dev, first sitting:** the MAP3b carry-overs (ROADMAP MAP3b "Carry-overs to MAP4"): Raider HP 120 -> 180, the eyes-56 default, D49 = B, the small fixes. Run length is settled (D50 = B), so there's no length pass.
3. Then DF1 (difficulty bump, D51 = C; ROADMAP), then 3d, then BD3b, then the Milestone 3 close: the milestone playtest, then game-lead's own review of the report and screenshots (ROADMAP).

**Next role:** game-lead (the MAP4 brief), then gameplay-dev.

## Current baselines (MAP3b close)
- Suite 2273 (1 skipped: the open `-RelicCap` qa test), 0 orphans.
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471.
- SIM1 `-Route first`: human Rogue 27/36, Wizard 23/36; off 33/36, 35/36.
- Relic medians `relic` 15/15, `safe` 6.5/6. Exactly 2 boss relics per won run. Late Bleed share 11.8% (Fire 31.3%).

## Pending for the next docs pass (tech-writer, MAP4)
- **RESOLVED:**
  - D49 (the question text is in 5b412e5, `docs/OPEN_ITEMS.md`);
  - D50 (in e038fa5);
  - D51 (in 6dec638);
  - eyes 53 plus the answered parts of 55, 52 and 56, with his words (in b0222f9).
- **CHANGELOG:**
  - `[Director decision]` D49: pruning or rejecting had no effect on offers; now each one multiplies that status's offer weight by 0.8, floor 0.4.
  - `[Director decision]` D50: target run length 30-45 min -> about 15-20 min of real time, decisions included.
  - The director-feedback entry for MAP3b (Bleed Rogue holds up, run under 7 min of fight time, Raider too easy).
  - The Raider change, old -> new, once built.
  - `[Director decision]` game modes and difficulty, 2026-11-12 (GDD §9a, §8): a hard campaign (3-5 tries average, 2-3 advanced, 1-2 pro), endless mode unlocked by the first final-boss clear, an account-wide power layer with minor player-level scaling, and the tier ladder Normal -> ... -> Torment II-X (was Normal, Hard, Torment).
  - `[Director decision]` D51 = C: a modest difficulty bump after MAP4 (DF1), final calibration with upgrades; no Easy tier (was: today's tuning is "Easy"), everyone starts on Normal and the next tier unlocks only after clearing the highest unlocked one.
  - `[Director decision]` process, 2026-11-12 (c5f5879): sessions stop at about 150 tool calls with a `Remaining:` list, smaller briefs, `safe to chain` / `needs your play first` tags, eyes items expire one slice later at their default, each answer is recorded once, STATE trimmed; plus the milestone playtest and game-lead review at each milestone boundary, and the playtester's pacing target fixed from 30-60 min to about 15-20 min (later commit, same day).

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D50 answered (D49 = B, D50 = B on 2026-11-12). D51 = C (2026-11-12). Next free: D52.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions open; eyes 56, 55, 54, 52, 51, 50, 49, 48, 47 and 35, all expiring at MAP4's close; the round 2 vision check.
