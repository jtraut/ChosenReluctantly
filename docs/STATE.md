# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-04 (BD1 qa PASS, playtest no blocker; tech-writer next). **Run order:** **BD1 (in progress)** -> BD2 (relics) -> MAP1 (map, gold) -> MAP2 (merchant) -> MAP3 (three acts, mini-bosses, save/resume) -> MAP4 (curse/buff rooms) -> 3d -> BD3. All briefs are in ROADMAP. Each build slice gets the full loop and a `playtest-YYYY-MM-DD-<slice>` tag. OPEN_ITEMS holds active items only; tech-writer archives answered ones in `docs/RESOLVED.md`. Done so far: A1, T-decks, W1a, PL2, F1, P-dodge, W1b, K1, H1, H2, BD0, H3, MAP0, PL3.

## What's done
- **D37 = A, D38 = A recorded 2026-11-04 (game-lead, docs only):**
  - **His answers:** D37 = A, a dig relic adds a rest Dig action that replaces both heal and removal. D38 = A, curses are cards you swap past; they don't count toward slot minimums and are removed like any card.
  - **Where recorded:** GDD §4a, BUILD_DEPTH §4.7, ROADMAP MAP4.
  - **Pending for tech-writer (BD1 docs pass):** archive D37 and D38 in RESOLVED (the text is in commit 863b15b), plus CHANGELOG `[Director decision]` entries for both.
- **Relic candidates 2026-11-04 (game-lead, docs only):** the director's two Gemini lists are adapted in BUILD_DEPTH §4.5 (round 1) and §4.8 (round 2: 20 relics, 6 boss, 6 starters, 6 events). They're unscheduled; slices pick from them. New D38 (curse cards).
- **Relic sources recorded 2026-11-04, third pass (game-lead, docs only):**
  - **His direction:** the relic sources from Slay the Spire and The Last Flame. The follow-up: a starter relic is chosen in the loadout from the unlocked tier 1 starter relics, with no random opening.
  - **Where recorded:** GDD §4a; the plan in BUILD_DEPTH §4.7; MAP.md §2/§9; ROADMAP (BD2 reserves values, MAP1 chests, MAP2 shop-only slot, MAP4 = events, 3d starter relic slot); DECISIONS "All relic sources and starter relics in the loadout".
  - **New:** D37 (rest dig vs D30). Item 47 is still open.
  - **Pending for tech-writer (BD1 docs pass):** CHANGELOG `[Director decision]` entries for the relic sources direction and for starter relics in the loadout (no RNG restarts).
- **Director replies recorded 2026-11-04, second pass (game-lead, docs only):**
  - **Item 42:** "tiers" confirmed as acts 2-3, then D34 revised. Relic tiers are 1/2/3/boss, with odds rising per act. Elites always give a relic and never cards. Act-end mini-bosses are the only source of boss-tier relics (2 per run); act 1's also offers 3 rare cards, act 2's 3 legendary. Rare cards come from act 2, legendary from act 3.
  - **Where recorded:** GDD §4a/§9, MAP.md §2/§4.4/§4.5/§10, BUILD_DEPTH §4.1/§4.2/§4.6/§11, ROADMAP (BD2 gets the relic tier values; MAP3 gets rarity and boss relics, with a possible MAP3b split) and DECISIONS "Applying the director's revised relic and card tiers".
  - **His other replies** (he renumbered them 43-46): 41 knockback fix good ("always found it strange to be flung across the room"); 40 the 1-dodge Wizard still seemed fine; 39 boss length fine; 35 not played yet, he may circle back.
  - **OPEN_ITEMS:** 39, 40, 41 and 42 removed; new 47 (my numbers).
  - **Pending for tech-writer (BD1 docs pass):**
    - Archive items 39, 40, 41 and 42 with his answers in RESOLVED. The old text is in commit 648dbd4.
    - Add CHANGELOG `[Director decision]` entries for:
      - relic tiers 1/2/3/boss with odds per act;
      - elites relic-only;
      - boss relics only from mini-bosses (2 per run);
      - mini-boss rare/legendary card offers;
      - card rarity by act;
      - knockback fix confirmed.
- **Director answers recorded 2026-11-04 (game-lead, docs only):** D34 = C (his own option: relics grow with the run, hard cap 20 and hard to reach, swap at the cap, no duplicates, mini-bosses always give gold + a rare card offer, elites in later acts a smaller chance of a rare card offer too), D35 = A (3 rejects per run), D36 = A (volley stays). Recorded in GDD §4a/§5/§9/§14, MAP.md §2/§4.4/§4.5/§10, BUILD_DEPTH §4.1/§11, ROADMAP BD2/MAP2/MAP3 (BD2 now builds the at-cap swap, cap 20), DECISIONS "2026-11-04 - Applying D34 = C, D35 = A, D36 = A". New eyes item 42 (check my reading of D34). **Pending for tech-writer (BD1 docs pass):** archive D34, D35, D36 in RESOLVED (old OPEN_ITEMS text is in commit 81ff8e4) and add CHANGELOG `[Director decision]` entries: relic cap 10 -> 20 over three acts, at-cap fallback "card offer instead" -> "give a relic up", rejects 3 per run kept, volley unchanged.
- **PL3 closed 2026-11-04:** gameplay-dev 9a86757/fbfd86c, ux da418aa, qa PASS 16387bf/e38bdd2, playtest 7f21afb, docs e03c4b8 (also archived D31-D33 in RESOLVED). Tag `playtest-2026-11-04-PL3`. **Baselines now: suite 1289/1289 (111 suites); arena 30 s seed 1 = 2333565009, 90 s = 1212800; bot sim `-Rooms 20 -Seed 3` = 2281795515.** Carry-overs listed under the PL3 brief (do with BD1). New director items: D36 (volley up close), 41 (knockback feel + PL3 visuals).
- **Director answers recorded 2026-11-04 (game-lead, docs only):** D31 = A, D32 = A + three acts of 10 rooms (mini-bosses end acts 1-2, final boss act 3; 30-45 min; save and return later), D33 = B. GDD §9, MAP.md §1/§2/§4.5/§8/§9/§10, BUILD_DEPTH §4.1, ROADMAP (MAP3 = acts + save/resume, new MAP4 = curse/buff; run order), DECISIONS "2026-11-04". New D34 (relics over 30 rooms), D35 (rejects). Archived in RESOLVED and CHANGELOG by tech-writer (e03c4b8).
- **MAP0 closed 2026-11-03 (docs only, no tag):** game-lead ee38ac0, e77653d, adf6468; docs 2762144. `docs/MAP.md` (game-lead owns it); GDD §9 [PROPOSED]; ROADMAP MAP1/MAP2/MAP3; questions D31-D33 (defaults A). Director's H3 Rogue feedback in CHANGELOG; old item 38 merged into 40.
- **H3 closed 2026-11-03:** gameplay-dev cee653d..3dc74fb, ux 6f89eea, qa PASS 44eff31/f1a3f88, playtest 305b13b (no blocker), docs 8700a4d (incl. D30 in CHANGELOG/RESOLVED). Tag `playtest-2026-11-03-H3`. **Baselines now: suite 1244/1244 (108 suites); arena 30 s seed 1 = 2333565009, 90 s = 819020947; bot sim `-Rooms 20 -Seed 3` = 2281795515.** Playtest findings -> PL3 items 11-13 (volley gaps, pip flash, is the volley fair to the Wizard). OPEN_ITEMS 40 asks the director to play it.
- **D30 = A recorded 2026-11-03 (game-lead, docs only):** 98efccd (GDD §4a bullet, GDD §9 director note on maybe removing the rest heal, BUILD_DEPTH §4.1/§11, ROADMAP BD2 wording + MAP0 rest-node question). OPEN_ITEMS: D30 removed. Archived in RESOLVED and CHANGELOG by tech-writer (8700a4d).
- **Director answers recorded 2026-11-02 (game-lead, docs only):** a6c33e6 (GDD §3/§4a/§5/§9/§14), 803c42b (BUILD_DEPTH §3.4, §4.1, §8, §9, §11), 6bd0f70 (ROADMAP: H3 + MAP0 briefs, BD1/BD2 edits, PL3 item 6 -> H3), c065762 (DECISIONS "Applying the director's answers"), plus OPEN_ITEMS/STATE. D22 = C (merchant, relic stage, elites; 6-8 for a relic hunter, cap 10), D24 = A, D25 = A (+ passive nodes), D26 = A, D28 = A, D29 = B (dodge on Space, Rogue 2 / Wizard 1, Movement on Ctrl, enemies and boss volley a bit faster). New D30 (rest/reward relics; default A = no).
- **BD0 closed 2026-11-02 (docs only, no tag):** game-lead 81fb65e..0ddd630, docs 995befe. New `docs/BUILD_DEPTH.md` (game-lead owns it). GDD §4a [PROPOSED] summary. ROADMAP: BD1 rewritten, BD2 (relics) and BD3 added. DECISIONS "2026-11-02 - BD0". The director said "continue" without answering D29, so BD0 assumed D29 = A (dodge off); BUILD_DEPTH §8 says what changes for B/C. New questions D22, D24, D25 (defaults A).
- **H2 closed 2026-11-02 (dodge-off trial):** gameplay-dev 120bfef..dacc680, ux e155c3e/ff3ef4f, qa PASS 4aa7141, playtest ebde769, docs edef5c0/0e47a70. Tag `playtest-2026-11-02-H2`. Dodge off (`data/player.json` `dodge.enabled`), Movement Space, Utility F, Wizard 22 HP, game-over arm delay. Bot standard clears with the dodge off: Rogue 3/16, Wizard kite 8/16, no-kite 7/16 (16/16 each with it on); not retuned. D29 asks whether the dodge stays off. **Baselines now: suite 1220/1220 (105 suites); arena 30 s seed 1 = 2591372848, 90 s = 4009010406 (dodge-on copies still give H1's 2816045921 / 3667433295); bot sim `-Rooms 20 -Seed 3` = 2281795515.**
- **H1 closed 2026-11-02 (gates met, goal missed):** 0c834a0..e4f4cbe, qa PASS 42cdb13, playtest a8123b5, housekeeping 642d546/c3f5ac1/98595d4 (D21 = B; no renormalisation needed, index already LF), docs f8238c1 (incl. new `docs/RESOLVED.md`). Tag `playtest-2026-11-02-H1`. (H1 baselines, superseded by H2's above.)
- Milestone 2, Post-milestone polish 1, C1, 3a, 3b, 3c, A1, T-decks, W1 (W1a + W1b), PL2, F1, P-dodge (tags `playtest-2026-10-29-C1`, `-3a`, `-3b`, `-3c`, `-A1`, `-T-decks`, `playtest-2026-10-30-W1a`, `-PL2`, `-F1`, `-P-dodge`, `playtest-2026-11-02-W1b`, `playtest-2026-11-02-K1`).
- **K1 closed 2026-11-02:** gameplay-dev 04ac813/7f4b136, ux 6204f2a/81abc85, qa PASS 8752a1c, playtest 2c0d185, docs 9e77aae. The UI's key text now comes from `InputLabels` (live InputMap), Recovery is on R, and a duplicate binding errors at startup. The reward prompt no longer lets slot keys cast behind it. Playtest findings went to PL3 items 7-10. DECISIONS "2026-11-02 - K1".
- **W1b closed 2026-11-02:** content aaa933a .. playtest d74e0df; docs ab00c50 + d6a449a. The director's keybind commit 24530e4 left 3 stale input tests failing; qa fixed them test-only in 0119999 (tests now read slot keys from the InputMap). Carry-overs: kiting Wizard nearly unhurt in rooms 1-9 (H1); Fan of regrets telegraph added to PL3 as item 6.
- Director answers D1-D18 and checklist items 11-24 are recorded and built.
- **2026-11-02, Part 0 of the director's 10/31-11/2 notes (docs only, game-lead):** GDD §1, §3, §4, new §4a, §8, §9, §14 items 11-12; ROADMAP briefs for K1, H1, BD0, BD1, PL3 housekeeping, 3d changes A-F; OPEN_ITEMS updates; human playtest entries; DECISIONS "2026-11-02 - Recording the director's 10/31-11/2 notes". All 2026-11-02 director decisions are in the CHANGELOG (ab00c50).
- The repo runs. Baselines: see the H2 line above.

## In progress
- **BD1-A (engine) DONE 2026-11-04:** gameplay-dev a141865, 6ca48f0, 7a5f61c, 7c5a66b.
  - Suite 1352/1352 (63 new tests); the last full run was before 7c5a66b, which only re-ran the bd1 and touched suites. qa should do one full run.
  - The three hashes are unchanged (2333565009 / 1212800 / 2281795515).
  - Reload soak OK; it now asserts the cast history is empty after reload.
  - Calls are logged in DECISIONS "BD1-A engine calls". D39 = A answered by the director the same day (the dodge isn't a Movement cast; GDD §4a).
- **BD1-B (content and tooling) DONE 2026-11-04:** gameplay-dev 3e297d5..49b117b.
  - **Suite:** 1388/1388 at 17fbe44, plus one view test since (1389 expected); qa runs it in full.
  - **Standard hashes REBASELINED** (new cards fill arena/bot slots from the pools; DECISIONS "BD1-B"): arena 30 s seed 1 = 1897787086, 90 s = 4207041509, bot sim `-Rooms 20 -Seed 3` = 846850403. The plan baselines are in the same entry.
  - **ux API:** `src/cards/SlotSynergyView.gd` `infos(player)`. Its fields are `chips`, `keywords`, `keyword_rules`, `condition_text`, `condition_live`, `primed`, `primed_time_left`, `primed_duration` and `primed_charges`. The pure side is in `SlotSynergy.gd`, and `CardSummary.condition_text` handles the text.
  - **Captures:** `tools\capture_screenshot.ps1 -Preset <name>` with `reward_screen`, `removal_screen`, `boss_smash`, `bd1_reward_keystone`, `bd1_reward_keystone_wizard`, `bd1_glow_target`, `bd1_primed` or `pl3_heavy_bolt`.
  - **Sims, 12 seeds × 10 rooms:**
    - Every archetype deck clears 11-12/12, as well as or better than the standard deck.
    - No-card runs clear 0/12.
    - The no-card Rogue soft-locks on seed 7 room 1. That predates BD1 (it shows at a4802ab); qa should note it.
- **BD1 ux DONE 2026-11-04:** ux-designer b61c388..1d3cbda.
  - **Suite:** 1403/1403 (120 suites). Hashes unchanged.
  - **What's new:** chips, live glow, primed marker, condition lines, a Keystone chip on rewards, the strip-overflow fix and a 142 px slot. Calls are in DECISIONS "BD1 ux calls".
  - **Captures:** `docs/playtests/img/bd1-ux-*.png`.
  - ux edited three tests outside its suite: `bd1b_content_test`, `m3c_qa_test` and the `pl3_qa_test` pin 134 -> 142. qa should confirm those edits.
  - **Not run by ux:** the reload soak and SceneSelfCheck (no autoload changes). qa runs them anyway.
- **BD1 qa: PASS with carry-overs, 2026-11-04** (commit 2796aa4; review in `docs/reviews/2026-11-04-bd1-qa.md`).
  - **Suite:** 1413/1413 (121 suites).
  - **Hashes:** all reproduced, plan baselines included. The old-hash claim was confirmed.
  - **Carry-overs:** listed under the BD1 brief in ROADMAP.
- **Sim signals** (boss room only, 12 seeds):
  - Parity: Controlled Burn reaches 59% of the standard Wizard's boss time, under the 70% floor. The other decks are 89-124%.
  - Removal pain: only Controlled Burn meets +25%. Hit and Run is -23% without Drive-By.
  - BUILD_DEPTH §2 tunes this in BD3.
  - Fingerprint spread isn't measured yet (no tooling).
- **BD1 playtest: NO BLOCKER, 2026-11-04** (commit 433ca0b, `docs/playtests/2026-11-04-bd1-short.md`).
  - The smoke check passes.
  - The LIVE glow reads even in a busy fight.
  - Findings are readability items for ux, filed under the BD1 brief in ROADMAP.
- **tech-writer docs pass: next**, then close and tag `playtest-2026-11-04-BD1`.
- **For qa (BD1 review):**
  - `slice6_qa_test::test_f1_same_seed_crowd_is_bit_identical` failed in 2 of 3 full runs during BD1-A (documented as a ~1-in-3 physics flake; it passed 1 of 1 at baseline). Check whether BD1 made it worse.
  - Known gaps, by design until BD1-B and ux: CastPreview, CardSummary and the bot treat conditional effects as unconditional. A buff aura outlives its spent charge. A delayed aoe with no anchor and no `max_range` telegraphs at the cast spot but hits at the caster (pre-existing, pinned).
- **Draft BD1 doc handoff, the backlog for tech-writer (collected from the "Pending for tech-writer" notes above):**
  - RESOLVED: archive D34, D35, D36 (text in 81ff8e4); items 39, 40, 41, 42 (text in 648dbd4); D37, D38 (text in 863b15b); D39 = A (text in 7503569).
  - CHANGELOG `[Director decision]` entries:
    - relic cap 10 -> 20 over three acts, at-cap fallback "card offer instead" -> "give a relic up", no duplicates;
    - rejects 3 per run kept; volley unchanged;
    - relic tiers 1/2/3/boss with odds per act;
    - elites relic-only;
    - boss relics only from mini-bosses (2 per run);
    - mini-boss rare/legendary card offers;
    - card rarity by act;
    - knockback fix confirmed;
    - relic sources (Slay the Spire / The Last Flame model);
    - starter relic chosen in the loadout (no RNG restarts);
    - D37 = A (rest dig relic);
    - D38 = A (curse cards).
    - D39 = A (the dodge doesn't count as a Movement cast for combos).
    - corporate-setting idea noted in GDD §15 (director, 2026-11-04; an idea, not a decision; tag it as a director note, not a decision).
  - Plus BD1's own changes (gameplay-dev a141865..7c5a66b, 3e297d5..49b117b; ux and qa to come). README needs:
    - `-Plan` for both sims, and `-Deck` for the bot sim;
    - `-Preset`, `tools/capture_presets.json` and the new capture rows;
    - `--run-offer` with the `+` separator;
    - the scenario keys `deck` and `_note`;
    - the `--class` + `--scenario` refusal, which fixes two contradictory README lines;
    - `dodge.counts_as_movement_cast`;
    - `--full-deck` counts now 30 (Rogue) and 28 (Wizard);
    - the `mixed-*` description wording;
    - the removal example on room 6;
    - the "Last verification" hashes and test count.
    - ux behaviour (chips, glow, primed marker, the 142 px strip);
    - the corrupted `toolsun_wave_sim.ps1` lines (around 197-198) restored to `tools\run_wave_sim.ps1`.
  - ARCHITECTURE: new files `src/cards/CardTags.gd`, `KeywordDatabase.gd`, `CastHistory.gd`, `SlotSynergy.gd`, `SlotSynergyView.gd`, `src/core/CombatEvents.gd`, `src/combat/EffectCondition.gd`, `src/debug/PlanPolicy.gd`, `tools/sim_caster.gd`, `tools/capture_presets.json`, `src/ui/ChipRow.gd`, `src/ui/SlotCues.gd`, and `data/keywords.json`.
- Known: wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320` (possible flakes).

## Exact next step
1. **BD1, synergy core** (ROADMAP brief; BUILD_DEPTH §3, §5 R-A/R-B/W-A/W-C, §6, §7, §2). Order: gameplay-dev **BD1-A** (done) -> gameplay-dev **BD1-B** (done) -> ux-designer (done) -> qa PASS -> playtest no blocker -> **tech-writer (next)** -> ux-designer -> qa -> playtester -> tech-writer -> close, tag `playtest-YYYY-MM-DD-BD1`.
2. Then **BD2**, **MAP1**, **MAP2**, **MAP3**, **MAP4**, **3d**, **BD3**.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-numbers:** D21-D33 answered (D31 = A, D32 = A + three acts, D33 = B on 2026-11-04). D34 = C, D35 = A, D36 = A answered 2026-11-04. D37 = A (dig relic at rest), D38 = A (curse cards) answered 2026-11-04. D39 = A (dodge isn't a Movement cast) answered 2026-11-04. None open. Next free: D40.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions open; eyes 47 (35 when he has time). Answered items are in `docs/RESOLVED.md` (D30 archived in 8700a4d).
