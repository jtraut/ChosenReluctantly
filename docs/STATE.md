# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-17. Latest tag `playtest-2026-11-13-MAP4`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **DF1** (ROADMAP DF1; DECISIONS "DF1 brief" and the triage entries). Sitting A, sitting B and ux are done. **qa PASS** (re-check 4026720, after a FAIL with 3 blockers fixed in a66b470, d67276f and f9f5c58). The repo runs.

## Exact next step
1. **playtester, DF1:** one three-act run per class, plus the smoke check (ROADMAP DF1 "Playtester").
2. Then tech-writer's docs pass (the list below), then the close: tag `playtest-YYYY-MM-DD-DF1`; eyes 58 expires with the default kept, and its 2 s curse swap penalty goes to 3d.
3. Then 3d (it starts with the curse swap penalty), then BD3b, then the Milestone 3 close.

**Next role:** playtester (DF1).

## Current baselines (DF1 qa, 2026-11-17)
- Suite 2490 (178 suites), 0 failures, 0 skipped, 0 orphans (about 21 min).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 is untouched).
- SIM1 `-Route first`: human Rogue 18/36, Wizard 16/36; off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). Rogue losses in rooms 13-15: 8 of 18.
- Fingerprint 0.79 with relics (qa's BUILD_DEPTH relic sets, now canonical), 0.45 without. Boss parity 92% / 109% / 106%.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass (tech-writer, DF1)
- DF1 sitting A (9c69a58..5da7427): debug flags `--run-curses`, `--run-discount`, `--merchant` never touch the save; `--merchant` alone jumps to the first merchant node; `--run-room` + `--event` opens the event; `-BossLog` fixed; curse casts skip `card_cast` and cast history; act-change map failure is a loss; `max_attempts` 1000 -> 2000 (sweep 1001-4000 worst 421/341/751). Drop the ARCHITECTURE known issue.
- DF1 sitting B (57b0a83..e3e1ac1): `data/run.json` `acts` damage 1.0/1.0/1.0 -> 1.0/1.05/1.1; SIM1 human Rogue 21 -> 18/36, Wizard 20 -> 16/36; off 36 -> 34/36, 35 -> 34/36; README SIM1 "Current" figures and floors (qa sets the new ones).
- DF1 ux (1fb09b3..6b12a6d): a curse swap hint pill (`slot_condition.curse_swap`); curse event lines say "(a dud card in one slot)"; the curse removal list gets its own title and line; the merchant-discount line says a merchant must be ahead; the "Give up N relics" sentence is dropped from four sacrifice relics; "Bleed detonated" shows once per cast (`detonate_word_window` 0.3 s); the sacrifice give-up step focuses the first relic.
- DF1 qa (83d06d3, 604466d, 4026720) and fixes (a66b470 Game Over on `run_lost` with the player alive; d67276f mb1b follows act 2 x1.05; f9f5c58 keyless curse-removal line, `Juice.reset` clears the detonate memory): suite 2490; the new SIM1 floors and ceiling; canonical fingerprint relic sets (qa review); [game-lead] Raider at act 2 x1.05, where three combos in a row now kill a full-HP Rogue by 0.45 (MAP.md §11.3).

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D51 answered. Next free: D52. Next eyes number: 59.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions open; eyes 58 (play MAP4; expires at DF1's close); the round 2 vision check.
