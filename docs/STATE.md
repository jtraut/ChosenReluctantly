# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-17. Latest tag `playtest-2026-11-13-MAP4`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **DF1 brief written 2026-11-16** (ROADMAP DF1; DECISIONS "DF1 brief"). Sittings: A (MAP4 carry-overs) -> B (data-only bump) -> ux -> qa -> playtest -> docs. Sitting A done (9c69a58..5da7427). Sitting B done (57b0a83..e3e1ac1): act damage 1.0/1.05/1.1; human Rogue 18/36, Wizard 16/36; off 34/36, 34/36; hashes unchanged. ux done (1fb09b3..6b12a6d). The repo runs.
- **qa DF1: FAIL** (83d06d3, 604466d; docs/reviews/2026-11-17-df1-qa.md; DECISIONS "DF1 qa FAIL triage"). Blockers:
  1. K1 key-hint scan: `event.remove_curse_line` hardcodes "(Shift + the slot key)" -> ux.
  2. mb1b duelist test assumes act 2 x1.0 -> gameplay-dev: derive from the act scale (MAP.md §11.3 updated).
  3. An act-change map failure leaves a dead screen; nothing listens to `run_lost` -> gameplay-dev (qa's red test in `df1_qa_test.gd`).
  - qa's Remaining: after the fixes, re-run `k1_key_hint_scan_test`, `mb1b_test`, `df1_qa_test`, then the full suite once.

## Exact next step
1. ~~gameplay-dev, DF1 fixes~~ done (a66b470, d67276f): blockers 2 and 3. qa confirms `map3b_acts_test` (gameplay-dev's run didn't finish).
2. ~~ux-designer, DF1 fixes~~ done (f9f5c58): blocker 1 (keyless line), `Juice.reset()` clears `_last_detonate_*`.
3. **qa re-check: stopped early, nothing committed (HEAD db7c2d3).** The diff was reviewed and looks right. A full-suite run was left going in the background (session task output `b22uubgoe.output`). qa's Remaining:
   1. Read the full-suite result. Expect about 2490 cases and 0 failures. If the result is missing, re-run `tools\run_tests.ps1`.
   2. Confirm that `df1_qa_test`, `k1_key_hint_scan_test`, `mb1b_test`, `df1_ux_test` and `map3b_acts_test` pass.
   3. Check that a real death shows Game Over once and that Try again works after `run_lost`. Add a test in `df1_qa_test.gd` if one is missing.
   4. Run the reload soak `-Cycles 3`, then `-Cycles 2 -Class wizard`, after the suite has finished.
   5. Confirm the four hashes.
   6. Append the re-check verdict to the review, including the SIM1 gate against MAP.md §11.4. Commit.
   Then the playtester, then the playtester, tech-writer, close.
3. Then 3d (it starts with the curse swap penalty, since eyes 58 wasn't answered before B), then BD3b, then the Milestone 3 close.

**Next role:** qa (DF1 re-check).

## Current baselines (MAP4 close, 2026-11-13)
- Suite 2478 (last full run 2477), 0 skipped, 0 orphans (about 22 min).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471.
- SIM1 `-Route first`: human Rogue 21/36 (on its 21 floor), Wizard 20/36; off 36/36, 35/36. Losses cluster in rooms 13-15.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act 278 / 312 / 568 (act 3 seeds 1001-4000: 751 of 1000).
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass (tech-writer, DF1)
- DF1 sitting A (9c69a58..5da7427): debug flags `--run-curses`, `--run-discount`, `--merchant` never touch the save; `--merchant` alone jumps to the first merchant node; `--run-room` + `--event` opens the event; `-BossLog` fixed; curse casts skip `card_cast` and cast history; act-change map failure is a loss; `max_attempts` 1000 -> 2000 (sweep 1001-4000 worst 421/341/751). Drop the ARCHITECTURE known issue.
- DF1 sitting B (57b0a83..e3e1ac1): `data/run.json` `acts` damage 1.0/1.0/1.0 -> 1.0/1.05/1.1; SIM1 human Rogue 21 -> 18/36, Wizard 20 -> 16/36; off 36 -> 34/36, 35 -> 34/36; README SIM1 "Current" figures and floors (qa sets the new ones).
- DF1 ux (1fb09b3..6b12a6d): a curse swap hint pill (`slot_condition.curse_swap`); curse event lines say "(a dud card in one slot)"; the curse removal list gets its own title and line; the merchant-discount line says a merchant must be ahead; the "Give up N relics" sentence is dropped from four sacrifice relics; "Bleed detonated" shows once per cast (`detonate_word_window` 0.3 s); the sacrifice give-up step focuses the first relic.

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D51 answered. Next free: D52. Next eyes number: 59.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions open; eyes 58 (play MAP4; expires at DF1's close); the round 2 vision check.
