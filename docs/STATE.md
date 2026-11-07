# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-07 (MAP3 detailed brief written; MAP3 split into MAP3 structure + MAP3b content). **Run order:** MAP1, MAP2 (done) -> **MAP3 (next: gameplay-dev sitting A)** (three acts, mini-bosses, save/resume) -> **MAP3b** (rarity, tier 3 and boss relics, final gold tuning) -> MAP4 (events) -> 3d -> BD3. All briefs are in ROADMAP. Each build slice gets the full loop and a `playtest-YYYY-MM-DD-<slice>` tag. OPEN_ITEMS holds active items only; tech-writer archives answered ones in `docs/RESOLVED.md`. Done so far: A1, T-decks, W1a, PL2, F1, P-dodge, W1b, K1, H1, H2, BD0, H3, MAP0, PL3, BD1, BD2, MAP1, MAP2.

## What's done
- **MAP3 brief and split 2026-11-07 (game-lead, docs only):** ROADMAP MAP3 "Detailed brief" plus a new MAP3b item; DECISIONS "MAP3 split and the detailed brief"; OPEN_ITEMS status line, items 47 and 51. Reason: 13 relics, tier 1-2 only, no boss relics, no card rarity, so the relic targets and the mini-boss reward can't be built yet. Interim calls: the mini-boss gives gold plus a normal relic offer and card offer; an exhausted pool keeps BD2's card-offer fallback; no free heal between acts; the bot 30-45 min gate is replaced by 8/12 wins and per-act time within ±30% of act 1 (human length goes to the playtest). **For tech-writer at the MAP3 docs pass:** a CHANGELOG process note on the split and the restated acceptance.
- **D41 = B, D42 = A recorded 2026-11-06 (game-lead, docs only):**
  - **His answers:**
    - D41 = B: keep relic prices 60/90/130 and raise gold income instead. Cards are tiered by rarity too, and a card is always cheaper than the equivalent relic tier.
    - D42 = A: no merchant guarantee on a route.
  - **Where recorded:** GDD §4a and §9, MAP.md §3/§4.4/§4.5, ROADMAP MAP3 fold-ins, DECISIONS "Applying D41 = B and D42 = A".
  - **Built in MAP3,** as gameplay-dev's first step. Until then main and the MAP2 tag still sell relics at 30/45/65.
  - **Pending for tech-writer (MAP3 docs pass):**
    - Archive D41 and D42 in RESOLVED with his answers and where they're recorded. The old OPEN_ITEMS text is in commit e6908f2.
    - Add CHANGELOG `[Director decision]` entries:
      - D41: relic prices, shipped 30/45/65 -> 60/90/130 with more gold income (values from the MAP3 sim); card price 40 flat -> tiered by rarity, always below the matching relic tier.
      - D42: no merchant guarantee, unchanged from the shipped default.
- **MAP2 closed 2026-11-06:** split into MAP2-A and MAP2-B (DECISIONS "MAP2 split").
  - **Commits:**
    - gameplay-dev 66ba317..9321820 (A), 5801fe7..6a3e780 (B);
    - ux 8897701..accf46f (shop panel; turned the merchant on in 8994863);
    - qa PASS with carry-overs bbac2e0..38f20bd;
    - playtest d503d36 (no blocker);
    - docs 05b7999.
  - Tag `playtest-2026-11-06-MAP2`.
  - **Shipped:** the merchant (3 relics with a shop-only slot, cards at 40, removal 50 +25), 7 new relics (13 total), and D40 = A (`min_rest` 1).
  - **Baselines now:**
    - suite 1843 (143 suites, 2 skipped MAP3 carry-overs);
    - arena 1897787086 / 4207041509 / `-Plan` 1160207333;
    - bot sim 846850403;
    - `-NoMap` 12/12 57.5 s / 12/12 63.3 s;
    - map-on route table (relic median 6, at the floor): ROADMAP MAP2 qa note.
  - **Carry-overs:** MAP3 (housekeeping list, ux polish, D42); BD3 (Request for Quotation dominance, Liquidate Assets weak/hidden, Paperwork Fire rarely fires, Severance chains, Rogue safe 10/12).
  - **Answered 2026-11-06:** D41 = B and D42 = A (see the entry above).
- **MAP1 closed 2026-11-05:** split into MAP1-A and MAP1-B (DECISIONS "MAP1 split").
  - **Commits:**
    - gameplay-dev afdf30d..ed4e2aa (MAP1-A), 2181b9b..3a2d9d8 (MAP1-B) and 3841b41..0226ec9 (post-flip test fixes);
    - ux a1a4155..ac7baa2 (the map screen; turned the map on);
    - qa PASS with carry-overs 19272da..e1c7c5d;
    - playtest e1e31b5 (no blocker);
    - docs c4bda37.
  - Tag `playtest-2026-11-05-MAP1`. The map ships on; `--no-map` gives the old straight run.
  - **Baselines now:**
    - suite 1737 (137 suites, 3 skipped carry-over tests);
    - arena 1897787086 / 4207041509 / `-Plan` 1160207333;
    - bot sim 846850403;
    - run sim `-Run -Seed 1 -Runs 12` (first route): Rogue 12/12 66.2 s, Wizard 10/12 60.6 s;
    - `-Route relic`: 12/12 52.1 s, 11/12 63.2 s;
    - `-Route safe`: 12/12 58.4 s, 12/12 65.0 s;
    - `-NoMap`: 12/12 57.3 s, 12/12 62.5 s.
  - **Carry-overs:**
    - MAP2 (gameplay-dev and ux lists, folded into the MAP2 brief);
    - MAP3 save robustness (`from_dict` node-pending soft lock, negative gold, the large chest `min_tier` 2 back once tier 3 relics exist);
    - BD3 (the Wizard on elite-heavy routes).
  - **New director question D40:** a rest on every route (answered A on 2026-11-06).
  - **Director feedback 2026-11-05:** "relics feel fun so far, builds are starting to get more exciting". It's recorded in the CHANGELOG, and item 49 is archived in RESOLVED; c4bda37 did both.
- **BD2 closed 2026-11-05:** split into two gameplay-dev sittings (DECISIONS "BD2 split").
  - **Commits:**
    - gameplay-dev 3b1ac07..fe051cc (BD2-A, engine) and 673db13..1af42c5 (BD2-B, content and run flow);
    - ux 4040259..92e4a31, plus fix 9901776 (Cancel focused on give-one-up);
    - qa PASS with carry-overs 9f9a241..1d9d3b9, plus addendum 1b53f62;
    - playtest 87116a8 (no blocker);
    - docs 3a75162.
  - Tag `playtest-2026-11-05-BD2`. 6 relics shipped; Exit Strategy moved to BD3.
  - **Baselines now:**
    - suite 1591/1591 (130 suites);
    - arena 30 s seed 1 = 1897787086, 90 s = 4207041509, `-Plan` 1160207333;
    - bot sim `-Rooms 20 -Seed 3` = 846850403 (unchanged; the bot sim builds no rooms, so it can't see relics);
    - relic run baselines: `run_wave_sim.ps1 -Run -Seed 1 -Runs 12 -Class rogue|wizard`, 12/12 won each, boss medians 57.3 s / 62.5 s.
  - **Carry-overs** are under the BD2 brief in ROADMAP:
    - MAP1 gameplay-dev: the `rooms.relic_room` stopgap, and checking whether the bot sim `-Swap` is a no-op;
    - MAP1 ux: the playtest readability items and the pause list showing the scene through it;
    - MAP1 qa: the c1e flake;
    - MAP3: save robustness, moved from 3d 6a;
    - BD3: chain depth on delayed relic spawns, Exit Strategy, and the Controlled Burn-with-relics balance.
  - **Relic room placement:** MAP1's relic-node rules take the playtester's "by room 7" note, plus the director's answer to item 49.
- **GDD §15 note 2026-11-04 (game-lead, docs only):** the free-to-play, cosmetics-only idea, from a playtester (the director's brother). The director isn't on board: it's single player. CHANGELOG "director note, not a decision" entry added in 3a75162.
- **BD1 closed 2026-11-04:** gameplay-dev a141865..7c5a66b (BD1-A, engine) and 3e297d5..49b117b (BD1-B, content and tooling), ux b61c388..1d3cbda, qa PASS with carry-overs 2796aa4, playtest 433ca0b (no blocker), docs e254881. Tag `playtest-2026-11-04-BD1`.
  - **Baselines now:** suite 1413/1413 (121 suites); arena 30 s seed 1 = 1897787086, 90 s = 4207041509; bot sim `-Rooms 20 -Seed 3` = 846850403. These were rebaselined because the new pool cards fill the sim slots (DECISIONS "BD1-B"). The plan baselines are in the same entry.
  - **Carry-overs** are listed under the BD1 brief in ROADMAP. Do the gameplay-dev and ux items with BD2's steps, and the balance items with BD3.
  - The tech-writer backlog (D34-D39, items 39-42, the corporate idea) is archived in RESOLVED and CHANGELOG in e254881.
  - **Process lesson (tech-writer):** Bash heredocs turned `\r` in `tools\run_wave_sim.ps1` into a carriage return in README twice. Write edit scripts with the Write tool instead.
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
- **MAP3 sitting A handed to gameplay-dev 2026-11-07** (after b54a453). If the session was cut off: check `git log` for gameplay-dev commits after b54a453, then resume sitting A at the first unfinished step (robustness -> save file -> D41 prices/gold -> housekeeping). Each step is committed separately.
- Known: wall-clock test waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320` (possible flakes).

## Exact next step
1. **MAP3, gameplay-dev sitting A** (ROADMAP MAP3 "Detailed brief", sitting A): save robustness -> the save file (`has_save`/`load_save`/`delete_save`) -> D41 prices 60/90/130 plus a gold retune for the sweep -> MAP2 housekeeping. Still a one-act game at the end. Then **sitting B** (three acts, mini-bosses, scaling, act 2-3 waves, 3-act run sim) -> ux -> qa -> playtester -> tech-writer -> close. Tag `playtest-YYYY-MM-DD-MAP3`.
2. Then **MAP3b**. game-lead's BUILD_DEPTH design pass (boss relics, tier 3, rare/legendary cards) comes before its build. Then **MAP4**, **3d**, **BD3**.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-numbers:** D21-D33 answered (D31 = A, D32 = A + three acts, D33 = B on 2026-11-04). D34 = C, D35 = A, D36 = A answered 2026-11-04. D37 = A (dig relic at rest), D38 = A (curse cards) answered 2026-11-04. D39 = A (dodge isn't a Movement cast) answered 2026-11-04. D40 = A (a rest on every route) answered 2026-11-06. D41 = B (relic prices kept, more gold, cards by rarity) and D42 = A (no merchant guarantee) answered 2026-11-06. Next free: D43.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md`: no decisions waiting; eyes 51 (visit the merchant), 50 (play the map, new), 49, 48, 47 and 35; the round 2 vision check is due. Answered items are in `docs/RESOLVED.md`.
