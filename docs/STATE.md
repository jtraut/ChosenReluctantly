# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-18 (BD3b brief written). Latest tag `playtest-2026-11-18-3d`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **BD3b brief written 2026-11-18** (ROADMAP, BD3b entry below 3d; BUILD_DEPTH §14; DECISIONS "BD3b brief"). BD3b-0 done (bc463f5..ddb0d1b); BD3b-A done (0436585..e9dfacf). The repo runs.

## Exact next step
1. **gameplay-dev runs BD3b-B** (engine 2, fixtures only). `safe to chain`.
2. Then gameplay-dev C1, C2, D, then BD3b-ux, qa, playtester, tech-writer, close. One sitting per agent; a `Remaining:` list gets a fresh agent.
3. Then the Milestone 3 close and milestone playtest (CLAUDE.md, milestone boundary).

**Next role:** gameplay-dev (BD3b-B).

## Current baselines (DF1 qa, 2026-11-17)
- Suite 2686 (191 suites) expected after BD3b-A; last full green run 2680 (190). qa confirms.
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 is untouched).
- SIM1 `-Route first`: human Rogue 18/36, Wizard 16/36; off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). Rogue losses in rooms 13-15: 8 of 18.
- Fingerprint 0.79 with relics (qa's BUILD_DEPTH relic sets, now canonical), 0.45 without. Boss parity 92% / 109% / 106%.
- Relic medians `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass
- [Director decision] 2026-11-18: D53 = B. Starter relics may also drop as ordinary relics (the four 3d starters keep their elite, relic room and merchant sources; no data change). Recorded in GDD §4a and BUILD_DEPTH §4.7 row 6. CHANGELOG and ARCHITECTURE currently call it a conflict and should be updated. RESOLVED entry: the D53 text (options A/B/C, "if you don't answer: A, in BD3b") is in OPEN_ITEMS at 6c77cdf.
- BD3b-0 shipped (bc463f5..ddb0d1b): tech-writer removes the 3d polish list from "Known issues" in CHANGELOG and ARCHITECTURE; CHANGELOG entry for the 9 items (old/new: `plan_empty` text, editor columns 3:2 -> 5:4, default name "Loadout %d" -> "%s loadout %d", `TextFit.fit` gains `max_height`); README: new UxCapture modes and the one-row relic keys; ARCHITECTURE: TextFit, `RelicRow.show_start_tag`, `ConditionCue.curse_swap_text`.

- BD3b-A shipped (0436585..e9dfacf): ARCHITECTURE (conditions, `scale` block, `EffectScale`, `CasterStats`, `EffectContext.deck_card_ids`, `counter` effect type, `stacking.decay_after`, `CastPreview` "scaled", `EffectTemplates.execute` scale arg); CHANGELOG (Office Supplies and Bureaucratic Red Tape rule_text old -> new "(halved on elites)"; new keys `ui.start_screen.preset_title`, `ui.effect.scale`, three condition strings); README suite count.

## Known issues
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D53 answered. Next free: D54. Next eyes number: 61.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: eyes 60 (play 3d; expires at BD3b's close); the round 2 vision check.
