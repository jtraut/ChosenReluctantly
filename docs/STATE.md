# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **History: closed slices are in `docs/ROADMAP.md` and `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`. Full STATE history before the 2026-11-12 trim: `git show dca0975:docs/STATE.md`.**

Last updated: 2026-11-19 (BD3b-C2 recorded; D next). Latest tag `playtest-2026-11-18-3d`. STATE holds only what's live (CLAUDE.md "Cost controls").

## In progress
- **BD3b brief written 2026-11-18** (ROADMAP, BD3b entry below 3d; BUILD_DEPTH §14; DECISIONS "BD3b brief"). BD3b-0 done (bc463f5..ddb0d1b); BD3b-A done (0436585..e9dfacf); BD3b-B done (070ffd6..23370fe); BD3b-C1 done (1865109..97acc3d), but the SIM1 human Wizard is 27/36, over its ceiling of 20; D fixes it. The repo runs.
- BD3b-C2 done 2026-11-19 (65be0d9..8fe0560, verified in 069f3ef).

## Exact next step
1. **ux-designer runs BD3b-ux** (ROADMAP). `safe to chain`; it runs while D54 waits. D3 done 16b1e81..76001b1: W-B passes, W-D goes to the director as D54 (default A: W-D informational, fixed in BAL1). If D54 = B or C, a gameplay-dev D4 sitting comes before qa.
2. Then BD3b-ux, qa, playtester, tech-writer, close. One sitting per agent; a `Remaining:` list gets a fresh agent.
3. Then the Milestone 3 close and milestone playtest (CLAUDE.md, milestone boundary).

**Next role:** ux-designer (BD3b-ux).

## Current baselines (DF1 qa, 2026-11-17)
- Suite 2767 (198 suites), 0 failures (BD3b-D3; the `w1a_test` flake didn't recur); a full run takes about 23 minutes, so run it in the background. SIM1 `-Route first` after D3: human Rogue 19/36, Wizard 20/36 (at the ceiling); off 35/36, 31/36. SIM1's human preset presses slots at random (no PlanPolicy).
- Hashes 3172486861 / 916264160 / 1317880580 / 3476063471 (unchanged; act 1 is untouched).
- SIM1 `-Route first`: human Rogue 18/36, Wizard 16/36; off 34/36, 34/36. Floors 12 / 10 / 31 / 30, ceiling 21 / 20 (MAP.md §11.4). Rogue losses in rooms 13-15: 8 of 18.
- Fingerprint 0.79 with relics (qa's BUILD_DEPTH relic sets, now canonical), 0.45 without. Boss parity 92% / 109% / 106%.
- Relic medians after C2 (per seed 1/13/25): Rogue `relic` 14.5/14/14, `safe` 6/5/5.5, `first` 8.5/10/7.5; Wizard `relic` 14.5/13.5/14. DF1: `relic` 14/14.5, `safe` 5/5.5 (target 5-8), `first` 9/8.5; exactly 2 boss relics; event visits median 2-3 per route. Map generator worst attempts per act over seeds 1001-4000: 421 / 341 / 751 of 2000.
- Late shares for a Bleed Rogue: Bleed 12.5%, Fire 22.8%, Burn 10.0% (unchanged by C2). Relic Burn share 21.1% (4 of 19).

## Pending for the next docs pass
- [Director decision] 2026-11-18: D53 = B. Starter relics may also drop as ordinary relics (the four 3d starters keep their elite, relic room and merchant sources; no data change). Recorded in GDD §4a and BUILD_DEPTH §4.7 row 6. CHANGELOG and ARCHITECTURE currently call it a conflict and should be updated. RESOLVED entry: the D53 text (options A/B/C, "if you don't answer: A, in BD3b") is in OPEN_ITEMS at 6c77cdf.
- BD3b-0 shipped (bc463f5..ddb0d1b): tech-writer removes the 3d polish list from "Known issues" in CHANGELOG and ARCHITECTURE; CHANGELOG entry for the 9 items (old/new: `plan_empty` text, editor columns 3:2 -> 5:4, default name "Loadout %d" -> "%s loadout %d", `TextFit.fit` gains `max_height`); README: new UxCapture modes and the one-row relic keys; ARCHITECTURE: TextFit, `RelicRow.show_start_tag`, `ConditionCue.curse_swap_text`.

- BD3b-A shipped (0436585..e9dfacf): ARCHITECTURE (conditions, `scale` block, `EffectScale`, `CasterStats`, `EffectContext.deck_card_ids`, `counter` effect type, `stacking.decay_after`, `CastPreview` "scaled", `EffectTemplates.execute` scale arg); CHANGELOG (Office Supplies and Bureaucratic Red Tape rule_text old -> new "(halved on elites)"; new keys `ui.start_screen.preset_title`, `ui.effect.scale`, three condition strings); README suite count.

- BD3b-B shipped (070ffd6..23370fe): ARCHITECTURE (`BuffTriggers` host, meta `buff_trigger_host`, signals `buff_triggers_started/ended`, `buff_trigger_fired`, `at: event_path`, static `CombatEventsRelay.chain_depth`, `reset_done`, public `RelicSchema.validate_trigger`, `MAX_ZONE_LINE_LENGTH`, `MAX_BUFF_TRIGGERS`); README suite count.

- BD3b-C1 shipped (1865109..97acc3d): CHANGELOG (7 Wizard cards; Hostile Feedback 12 -> 13 and Literature Review 13 -> 14.5 against the design sketch; Thesis late Fire share 32.7% -> 25.8%); README (14 presets incl. `wizard-thesis` and `wizard-ward-battlemage`; Wizard full pool 39 -> 46; the offer report's Wizard `thesis` bot).

- BD3b-C2 shipped (65be0d9..8fe0560, verified in 069f3ef): ARCHITECTURE (the 4-argument `player_damaged` with attacker and melee; `Health.last_melee` and the `melee` argument on `receive_damage`/`take_damage`; `RelicSchema.AT_ATTACKER`; trigger-level `condition`; `EffectCondition.HAS_BONUS_ARMOR`; `cast_within.count` and `CastHistory.count_within`; `EffectScale.EVENT_AMOUNT` and `EffectContext.event_amount`; `CardTags.POOL_TAGS`; the `swap_penalty_mult.<slot>` stat and `CardSlot.swap_card(stat_modifiers)`; `CasterStats.has_bonus_armor`). CHANGELOG (5 relics: Exit Strategy, Thorned Boundary, Reading List, Filing Cabinet, Hot Streak; relic Burn share 25.0% -> 21.1% (4/16 -> 4/19); Fire cards' tags gain "Fire"; the `map3b_content_test` relic upper bound goes 26 -> 32; §12.1's "about 22" is now a floor). README (suite 2745 / 195; the stale relic Burn share "28.6% (4 of 14)" becomes 21.1% (4 of 19); SIM1 human Wizard 20/36).
- BD3b-D1 shipped (b9b3687..0477a81): ARCHITECTURE (`PoolDatabase.tag_for_pool`/`all_pool_tags` and the pool `tag` field; `CardTags.POOL_TAGS` removed, which replaces the C2 note; `SimCaster` gains a Hurtbox, a StatusEffectManager, `step()` and `live_view_fields()`; `bot_sim.gd` plan view gains `self_stacks`, `hp_fraction` and `deck_card_ids`). CHANGELOG (the pool tag moves from code to data with behaviour unchanged; bot-sim plan mode now sees Charge and the live view fields; the melee audit found nothing missing). README (suite 2758 / 197; a full run takes about 23 minutes).
- BD3b-D2 shipped (7d1b197..c678b24): ARCHITECTURE (`PlanPolicy.spender_scale`, `has_trigger_buff`, `SPEND_AT_STACKS`, `SPEND_DECAY_MARGIN`, `TRIGGER_BUFF_RANGE`; `StatusEffectManager.decay_left_of`; view key `self_decay_left` in `SlotSynergyView.view_for` and `SimCaster.live_view_fields`; the wave sim's plan line prints spender casts). CHANGELOG (the plan bot plays Charge and Spiteful Ward; gate results). README (suite count; SIM1's human preset doesn't use PlanPolicy; Wizard fingerprint relic sets W-A `lingering_embers+pyre_insurance+grading_curve`, W-B `reading_list+cc_all_staff+office_supplies`, W-D `thorned_boundary+ergonomic_chair+heavy_sigh`).
- BD3b-D3 shipped (16b1e81..76001b1): CHANGELOG (Thesis Defense +1.5 -> +10 per Charge; Footnotes and Literature Review 2 -> 3 Charge per cast; cc:All Staff bolt 6 -> 3 and its rule_text; W-B gates pass, W-D's miss is D54). Tests: `bd3b_engine_test` reads `decay_after` from data.

## Known issues
- `w1a_test.gd` `test_the_wizard_bolt_does_not_reach_past_its_12_m_range...` failed once in a full run (32 s) and passes alone; qa re-runs it on a quiet machine.
- Wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`.
- Human-bot Kindling boss parity with relics is 67%, under 70% (qa DF1; not a DF1 regression).
- An old git stash (`stash@{0}`, from 85cd564) is still in the repo; the director decides whether to drop it.
- Re-run the reload soak whenever Main, Juice, Player or the autoloads change.

**D-numbers:** D21-D53 answered; D54 open. Next free: D55. Next eyes number: 61.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths. A role that stops with a `Remaining:` list gets a fresh agent, never a resumed one.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: D54 (Ward Battlemage; default A at BD3b's close); eyes 60 (play 3d; expires at BD3b's close); the round 2 vision check.
