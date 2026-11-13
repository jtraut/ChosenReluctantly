# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-13. Latest tag `playtest-2026-11-12-MAP3b`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **MAP4 (events), briefed 2026-11-13** in ROADMAP MAP4 and BUILD_DEPTH §13 (design pass). Tag `safe to chain`. Five gameplay-dev sittings: A -> B1 -> B2 -> C -> D, then ux, qa, playtest, docs. Nothing built yet. The repo runs.

## Exact next step
1. **Sittings A (6cd1c44..b2ae51b), B1 (6c49bd0..7fecaae) B2 (866ac63..fc444cd), C (5b85aad..eeae97c) and D (fa94a97..33eff21) done; events are live in three-act runs.** **ux-designer, MAP4 ux** (ROADMAP MAP4 "ux").
2. Then each a fresh agent, then ux, qa, playtest, tech-writer, close.
3. Then DF1 (difficulty bump, D51 = C; ROADMAP), then 3d, then BD3b, then the Milestone 3 close: the milestone playtest, then game-lead's own review of the report and screenshots (ROADMAP).

**Next role:** ux-designer (MAP4 ux).

## Current baselines (MAP4 sitting A, 2026-11-13; qa re-gates at MAP4's qa)
- Suite 2425 after D (one test fixed after the last full run; qa re-runs), 0 skipped, 0 orphans (about 18 min).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged).
- SIM1 `-Route first` (after D, events on): human Rogue 21/36, Wizard 20/36; off 36/36, 35/36. Losses cluster in rooms 13-15 (act 2 start and the Raider).
- Relic medians (after D) `relic` 14/14.5, `safe` 5/5.5, `first` 9/8.5; event visits median 2-3 per route. Exactly 2 boss relics per won run. Late shares for a Bleed Rogue with D49 as refined: Bleed 12.5%, Fire 22.8%, Burn 10.0%.

## Pending for the next docs pass (tech-writer, MAP4)
- **RESOLVED:**
  - D49 (the question text is in 5b412e5, `docs/OPEN_ITEMS.md`);
  - D50 (in e038fa5);
  - D51 (in 6dec638);
  - eyes 53 plus the answered parts of 55, 52 and 56, with his words (in b0222f9).
- **MAP4 sitting A (6cd1c44..b2ae51b), from gameplay-dev's hand-back:** MAP.md §11.3 already updated by game-lead. README: suite 2281, `run_tests.ps1` about 18 min, SIM1 numbers above, the `offer_report` line mentions D49. CHANGELOG: Raider `max_health` 120 -> 180 and phase 2 gap 0.9 -> 0.75; Non-Compete refund 0.5 -> 0.3 s (eyes-56 default); D49 built with the shares above; Knuckle Sandwich text; the `-RelicCap` and forced `--relic-offer` fixes.
- **RESOLVED (eyes 57, text in 69c8b0d `docs/OPEN_ITEMS.md`):** director 2026-11-13: "I don't like that dynamic, so let's try rejecting only pushes away cards not currently in your deck". Recorded in GDD §9 (D49 refinement); built at the start of MAP4 B2.
- **CHANGELOG `[Director decision]`:** D49 refined: a reject discounts only offered cards not already in your deck (was every offered card).
- **MAP4 sitting B1 (6c49bd0..7fecaae):** README: suite 2334, `--event=<id>` (refused until D ships events; never saves), the save-boundary rule now includes the event choice screen and its relic offer, the `event` node (rooms 3-9, weight 0, `?`) replacing curse/buff rooms, `data/events` and the event format. ARCHITECTURE: `src/events/` (EventSchema, EventDatabase, EventEngine), new RunState fields, `RunSave.choice_is_savable`. CHANGELOG: event node and engine, off at weight 0.
- **MAP4 sitting B2 (866ac63..fc444cd):** README: suite 2374, SIM1 numbers, the `offer_report` line for the D49 refinement (shares 12.2/22.8/9.9 -> 12.5/22.8/10.0), the new outcomes and sacrifice flow, save boundaries now include the event give-up step and an event fight's start. ARCHITECTURE: RunState `event_fight`, `run_mods`, `merchant_discount`, `sacrifice_picks`, `sacrificed_tier`; controller `event_fight_active()`, `confirm_relic_giveup()`, `confirm_purchase_giveup()`; EventEngine `fight_won`, `pick_fight_wave`, `sacrifice_candidates`. CHANGELOG: B2 outcomes, sacrifice relics (none shipped yet).
- **MAP4 sitting C (5b85aad..eeae97c):** README: suite 2413, the curse card format, the `rest_dig` stat, `curses.max_cleanses`. ARCHITECTURE: `RunState.cleanses`, `PENDING_EVENT_REMOVE`; `RunChoices` `is_curse_id`, `curse_ids`, `cleanses_left`, `cleanses_at_cap`, `remove_from_deck`, `dig_enabled`, `dig_offer_ids`; `EventEngine` `outcome_block_reason`, `curse_pool`; `CardSchema.is_curse`, `DeckRules.slot_map_of`, `RouteBot.removal_choice`. CHANGELOG: curses and the Dig built (none shipped until D).
- **MAP4 sitting D (fa94a97..33eff21):** README: suite 2425, `--run-curses=id+id`, `multi_act.types` in map.json, `run_map_print -Routes` events column, `run_wave_sim` EVENT SUMMARY / BOSS RELICS lines and curse-offer ERROR scan, capture presets `event_screen`, `event_screen_requires`, `rest_dig`, `curse_hud`, the event table, SIM1 numbers. ARCHITECTURE: `MapConfig.for_act` `multi_act.types`, `RouteBot.plan` relic tie-break toward events, `RunSession.start_curses`. CHANGELOG: events on (three-act only: event weight 0 -> 28, relic_room 14 -> 18), the 8 events, 3 curses, 6 event-only and 4 sacrifice relics; safe-route relic target 6-8 -> 5-8. MAP.md already updated by game-lead. Assets: none.
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
