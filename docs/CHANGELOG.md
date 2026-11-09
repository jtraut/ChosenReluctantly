# Changelog: Chosen, Reluctantly

A plain-language history of the project for the director, grouped by date (from git commit dates). **Newest entry first:** new entries are always added directly under this header, never at the bottom. Hashes in parentheses are short git commit IDs.

## 2026-11-09 (Slice MAP3: three acts, mini-bosses, scaling, save and resume; D41 = B built; director decisions D43 and dual-class)

### Slice MAP3: three acts, mini-bosses, scaling, save and resume

Commit range 05b7999..602210a. gameplay-dev sitting A 239c856..da739de (2026-11-07) and sitting B 5d85ee4..cd17992; ux 5a75570..96bbdeb; qa 890c9eb (PASS with carry-overs, `docs/reviews/2026-11-09-map3-qa.md`); playtest 02a8c5f (no blocker, `docs/playtests/2026-11-09-map3-short.md`); game-lead triage 40d64ee. Plan: `docs/MAP.md` sections 4.5 and 8; calls: `docs/DECISIONS.md`, the "MAP3 split", "MAP3 sitting A calls", "MAP3 sitting B calls", "MAP3 ux calls", "MAP3 qa calls" and "MAP3 playtest triage" entries. **A normal run is now 30 rooms in 3 acts.** The playtest used captures and bot runs, no hand play; a human run's length is not measured yet (OPEN_ITEMS 52).

#### Added
- **Three acts of 10 rooms** (30 in all). Each act is its own generated map, seeded from the run seed and the act number, with the same path rules per act plus two multi-act changes (`data/map.json` `multi_act`: relic route [4, 6] per act and at most 2 relic stages per path per act). Gold, HP, deck, relics and rejects carry from act to act. **There is no free heal between acts** (a game-lead interim call, now a director question, D45). `data/map.json` `acts` is the count (1 plays as MAP2).
- **Act-end mini-bosses** in acts 1 and 2 (room 10); act 3 ends in the existing boss. A mini-boss is a golem with its own tier entry plus adds (`data/run.json` `rooms.mini_boss`: `mini_boss_act1`, `mini_boss_act2`; no new AI; tier `tiers.mini_boss`; gold `gold.mini_boss`). **Interim reward (until MAP3b):** gold, a normal relic offer (pick 1 of 3 or skip) at the next act's tier odds, then a normal card offer. MAP3b replaces it with a boss-tier relic and rare or legendary cards.
- **Act scaling** (`data/run.json` `acts`, new: before this every room was x1): per-act multipliers for enemy HP, damage and gold. **Act 1 x1 / x1 / x1; act 2 HP x1.1, act 3 HP x1.2; damage x1 and gold x1 in every act.** The brief's starting values were act 2 HP x1.35 / damage x1.15 and act 3 HP x1.7 / damage x1.3; the run sim met its gates with the lighter ones (the new wave lists already add difficulty).
- **Wave lists for acts 2 and 3:** 4 combat and 2 elite lists per act from existing enemies (bigger mixes, more golems and shooters). Lists carry an `acts` field; act 1 keeps its lists.
- **Save and resume** (`RunSave`, `src/run/RunSave.gd`): one slot, `user://run_save.json`, versioned and validated. It is written at the map screen and at each room start, and deleted on a win or a loss. Quitting mid-fight and resuming restarts that room. A bad or old file is ignored with a warning, never a crash. Runs with a debug launch flag (including `--acts`) and headless runs never read, write or delete it. Straight (`--no-map`) runs are never saved, but by code reading a windowed one that ends in a win or loss still deletes an existing save (reported to game-lead). API: `RunSave.has_save()`, `load_save()`, `delete_save()`, `summary()`.
- **Continue** on the class pick screen when a save exists (it shows class, act and room, starts focused, and the class cards then say "(replaces your saved run)"). **The act transition screen** (`ActScreen`: "Act 2", a one-line summary of HP, gold and relics, a dry line and Continue; the map pick waits behind it).
- **UI wording and look:** a two-line HUD plate on multi-act runs ("Act 2 of 3" and "Room 14 of 30 - Type"; one-act runs are unchanged); whole-run room numbers on the reward, merchant, cleared, Game Over and win screens (`ActText`); the map shows act titles, rooms 11-20 and 21-30 in acts 2 and 3, and mini-boss node and "only way on" text; the merchant's coin on the map legend, the HUD plate and the shop title (`RunTypeIcon.coin`).
- **Launch and tools:**
  - `--acts=N` (debug: the run has N acts, 1 to 9; `--acts=1` is the MAP2 run; refused with exit 2 on a bad or repeated value; never saves). `--run-room=N` now takes 1 to 30 on a three-act run (31 exits 2).
  - `tools\run_wave_sim.ps1 -Acts N` (the run sim plays N acts; the report adds ACT lines and an ACTS TOTAL line), `tools\run_map_print.ps1 -Act N [-Acts M]` (print or sweep one act's map).
  - Capture presets `mini_boss_act1`, `final_boss_act3`, `act_transition`, `map_mini_boss`, `map_act2`; the one-act presets are pinned with `--acts=1`. `UxCapture` mode `continue_pick`.
- Tests: 1843 -> 1954 test cases (1 skipped: a deliberate bug probe for a hand-edited save), 143 -> 149 suites. New suite `map3_qa_test.gd` (act-boundary resume, 364 hostile save files, truncated files, determinism over 3 acts, exhausted pool in acts 2 and 3). Test `.uid` files are now tracked.

#### Changed
- **[Director decision] D41 = B, built here: relic prices and gold income, old -> new.**
  - Relic prices (tier 1 / 2 / 3, `data/run.json` `relics.prices`): 30 / 45 / 65 (MAP2) -> **60 / 90 / 130** on a one-act run (sitting A) -> **80 / 120 / 170** with three acts (sitting B).
  - Gold income doubled (`data/run.json` `gold`, combat / elite / mini-boss): combat 12-18 -> **24-36**, elite 30-40 -> **60-80**, mini-boss 45-55 -> **90-110**. `map.json` `estimate.gold_mean` 15 / 35 / 50 -> **30 / 70 / 100**; `estimate.merchant_prices` [30, 30, 45] -> **[60, 60, 90]** (one act) and **[80, 80, 120]** with three acts (`multi_act`). Every generated map, the golden-map hash and the capture presets stayed valid. Gold went up more than the brief's "only as far as needed" (25/55/80 would have failed the sweep's headroom); MAP3b does the final gold tuning.
  - Card price stays 40 flat until MAP3b adds rarity.
- **Strings, old -> new** (`data/run.json` `ui`):
  - merchant tile reason "No card can go: deck minimums" -> "No card can go. Add a card first.";
  - removal-screen text "Every card is needed to meet the deck minimums" -> "Every card is needed to meet the deck minimums. Add a card first, then come back.";
  - map line "Spend your gold at the merchant (the square)." -> "Spend your gold at the merchant (the square with the coin).";
  - act summary "HP %d of %d, %d gold, %d relics" -> "HP %d of %d, %d gold, relics: %d" (so it never says "1 relics").
  - New: the act screen's flavor line, button and hint; the map's per-act title and "Pick the next room. Every route ends at the mini-boss."; the mini-boss "only way on" lines; the class pick's Continue lines.
- The shop shrinks instead of scrolling when it is up to 4% too tall (`data/ui.json` `run_ui.shop_scroll_slack` 0.04). This fixes the 4 px overflow at 1280x720 when every tile says "Need N more gold".
- Relic offers in act 3 draw tier 1 and 2 at 5:25 for now (there are no tier 3 relics yet). An exhausted pool keeps the BD2 fallback: an elite or relic room with nothing left to offer gives a card offer.
- **`--run-node` now refuses a non-integer value with exit 2** (it was silently ignored; a MAP2 qa carry-over). `--run-node=999` still only logs an error.
- Save robustness (sitting A): `RunState.from_dict` no longer crashes on wrongly-typed `offer`, `deck` or `choice_log` entries or a null, array or object offer entry; a stale `offer` is cleared when nothing is pending; a damaged map drops `pending: "node"` (a soft lock); negative gold is clamped to 0; overlapping, over-cap and unknown relic ids are refused; `BossConfig.validate` no longer script-errors on a non-object attack. MAP1's two skipped save tests were un-skipped.
- Other MAP2 housekeeping (sitting A): run-arg refusals with tests, Liquidate Assets refreshing on every purchase, `Merchant.items()` at the relic cap, stale comments.

#### Verification (qa, 890c9eb)
- PASS with carry-overs. Per-act 1000-seed sweeps: 0 failures (worst 79 / 86 / 126 of 1000 attempts). Reload soak OK four ways. No-card gate 0/12 for both classes.
- **Unchanged:** arena `state_hash` 1897787086 (30 s) and 4207041509 (90 s), `-Plan` 1160207333, bot sim 846850403, `-NoMap` Rogue 12/12 at 57.5 s and Wizard 12/12 at 63.3 s.
- **Acceptance** (`-Run -Seed 1 -Runs 12 -Route first`, three acts): Rogue 9/12 and Wizard 10/12 wins (gate: 8/12); every act within +13% of act 1's bot time. Final boss median 47.0 s (Rogue) and 56.9 s (Wizard). Median relics at the end of acts 1 / 2 / 3: 3.0 / 5.5 / 7.0 (Rogue), 3.5 / 6.0 / 7.5 (Wizard). Median gold at the end of each act: 328 / 611 / 902 (Rogue), 333 / 611 / 835 (Wizard).
- **Other baselines (not gated):** `relic` route Rogue 10/12 at 43.3 s with 11 relics, Wizard 10/12 at 52.4 s with 11; `safe` Rogue 8/12 at 54.4 s with 5 relics, Wizard 10/12 at 63.5 s with 5. The old relic targets (`relic` 14 to 17, `safe` 6 to 8) are not met; they moved to MAP3b.
- Carry-overs: BD3a sitting A housekeeping (a hand-edited save with `hp` 0 or above max, or a bad `rejects_remaining`, still loads: a skipped probe; `GamePause.reset()` does not unpause the tree; the Wizard `-Run` sim that gave the playtester no output after 15 min); MAP3b (bots hoard 835 to 902 gold by the end of act 3; no tier 3 relics).

#### Playtest (02a8c5f, no blocker; captures and sim only)
- Smoke pass. The structure reads clearly (HUD, map titles, rooms 11-30, mini-boss node text) and the Act 2 screen's tone and single button work. Bot act times 246 / 288 / 251 s (Rogue, seed 300).
- Findings routed by game-lead (40d64ee): acts 2 and 3 feel like "act 1 with more" and the mini-boss does not look like an act-ender (director question D44, plus a named bar and a bigger marker for BD3a ux); the missing heal between acts is invisible (D45, plus an act-screen line "Your HP carries over. Rests are on the map." and low HP in red for BD3a ux); gold has no job in acts 2 and 3 (259 / 629 / 960 median) and goes to MAP3b's design pass; the win rate swings by seed (Rogue seed 300 won 2 of 6, against seed 1's 9 of 12). Human run length is unmeasured (the playtester guesses 20 to 30 min against the 30 to 45 target).

### Director decisions and feedback (2026-11-09)
- **[Director decision] D43 = B: card offers lean toward the statuses your deck applies.** It replaces the even draw across pools (GDD section 9). Built in BD3a. The starting rule is a game-lead default in `docs/DECISIONS.md`: weight x (1 + 0.25 per owned card that applies the status), capped at x3, tuned by data. Archived in `docs/RESOLVED.md`.
- **[Director decision] Class and element are a dual-class system; there is no "no element" option.** A player leans toward either side or stays hybrid. Recorded in GDD section 5 "Character creation".
- **[Director decision] Reprioritisation: non-Fire build variety is a priority.** BD3 is split: **BD3a** (physical Rogue: stacking, `detonate_status`, Bleed Out and Grudge Brawler cards, non-Fire relics) runs after MAP3 and before MAP3b; **BD3b** (Wizard depth) stays after 3d. MAP3b's relics and rare and legendary cards must cover Bleed and basic attacks as well as Burn.
- **Director feedback (his three-act physical/Bleed Rogue run, on the sitting B build):** "It felt good mostly." Problems: far too few physical and Bleed cards (1 card applies Bleed); about half his relics were Fire or Burn and no use to his build; he kept rejecting and pruning Fire offers; he felt trapped into Fire. game-lead's data: about 37% of a Fire Rogue's card offers are Fire, and 5 of the 8 elite and relic-room relics the Rogue can see need Burn, including Spite Knuckles. This is the only hand-play input on MAP3 so far.

### Docs and process
- **MAP3 split (2026-11-07):** MAP3 (structure: acts, mini-bosses, scaling, save and resume) and **MAP3b** (content: card rarity, rare and legendary cards, tier 3 and boss-tier relics, final gold tuning), each with its own tag. Reason: there were 13 relics (tier 1 and 2 only), no boss relics and no card `rarity`, so the 14 to 17 relic target and the mini-boss reward could not be built or tested.
- **MAP3 acceptance restated:** the bot's 30 to 45 min gate is replaced by 8 of 12 three-act wins per class on the `first` route and bot time per act within about 30% of act 1's. A human run of 30 to 45 min (GDD section 9) goes to the playtest and the director. Relic counts and "2 boss relics per run" moved to MAP3b.
- BD3 split into BD3a and BD3b on 2026-11-09 (see above). The README, ARCHITECTURE, CHANGELOG and RESOLVED updates are the MAP3 docs pass.

## 2026-11-06 (Slice MAP2: the merchant; D40 = A)

### Director answers on relic prices and merchants (D41, D42; answered 2026-11-06 after the MAP2 playtest)
- **[Director decision] D41 = B: keep the relic prices at 60 / 90 / 130 and raise gold income instead.** The shipped 30 / 45 / 65 was a game-lead default. Cards are tiered by rarity too, and a card is always cheaper than the equivalent relic tier (card price 40 flat -> by rarity in MAP3b). Built in MAP3 (see 2026-11-09). Recorded in GDD sections 4a and 9 and `docs/MAP.md` sections 3, 4.4 and 4.5; archived in `docs/RESOLVED.md`.
- **[Director decision] D42 = A: no merchant guarantee on a route** (the shipped behaviour, unchanged). A skipped merchant costs less from MAP3 on, because gold carries between acts.

### Slice MAP2: the merchant

Commit range ca5574a..110cc45. game-lead docs 4145235, b050aab, 1b43709, 1bf9eb6, a9c4f52, 46065c1, 110cc45; gameplay-dev MAP2-A 66ba317, bf80b35, 9321820 and MAP2-B 5801fe7..6a3e780; ux 8897701..accf46f (the merchant was turned on in 8994863); qa bbac2e0..38f20bd (PASS with carry-overs, `docs/reviews/2026-11-06-map2-qa.md`); playtest d503d36 (no blocker, `docs/playtests/2026-11-06-map2-short.md`). Plan: `docs/MAP.md` section 4.4. Calls: `docs/DECISIONS.md`, the four "2026-11-06 - MAP2" entries and the qa and playtest triage entries. **The merchant is on in shipped data.** Nobody has hand-played the shop yet (the playtest used captures and bot runs).

#### Added
- **The merchant node** (weight 8, at most 1 on any route (`max_merchants` is a path rule), rooms 4 to 9; some routes pass none). A merchant room has no fight. What it sells (amounts are `data/run.json` `merchant` and `relics.prices`):
  - 3 relics: 2 normal merchant-source slots plus a third slot that holds only shop-only relics (it falls back to normal stock when none is eligible);
  - 3 cards at 40 gold each (drawn by the reward weights);
  - card removal at 50 gold, then +25 for each removal bought at the merchant (rest-room removals do not raise the price). It goes through the same deck-minimum guard as the rest room;
  - relic prices by tier: 30 / 45 / 65. Boss-tier relics are never sold.
  - Stock is seeded from the run seed and node id, with no owned or given-up relics and no duplicates. Buy any number of items in any order, then Leave. Gold never goes negative.
  - **At the relic cap** a relic is still buyable: you give one up first (the BD2 step); Cancel charges nothing.
  - **Rerolls** only come from the relic Request for Quotation. A reroll redraws only the unsold slots.
  - **You can save mid-visit:** the open visit (stock, what is sold, rerolls used) is part of `RunState`, so a restore gives the same stock. Three pending screens: the shop, the removal list and the give-one-up step.
- **7 new relics (13 in total in `data/relics/`).**
  - Pool relics (sources elite, relic room, merchant): ASAP Notice [neutral, tier 1], Severance Package [rogue, tier 2], Paperwork Fire [wizard, tier 1], Grading Curve [wizard, tier 2].
  - Shop-only relics (`sources` exactly `["merchant"]`): Liquidate Assets [neutral, tier 2], Request for Quotation [neutral, tier 1], As Per the Attached Document [neutral, tier 2]. Each class now has 11 eligible relics (6 were not enough for a relic hunter to reach the merchant with a full pool).
  - Why Liquidate Assets is tier 2, not the documented tier 3: act 1's tier weights are 80/20/0 and a weight-0 tier is never stocked. Re-tier it in MAP3.
  - Rules are in the files (`rule_text`); numbers are not repeated here.
- **Engine** (66ba317, b521aeb): `Merchant` (stock, buying, reroll; pure), `RunMerchant` (turns it into the choice model and builds the panel's `view`), `MerchantConfig` (the `run.json` `merchant` block), `MerchantSwitch` (the all-or-nothing on switch, with `shipped_problems` checking the data lines flip together) and `MerchantPolicy` (the bots' choices). `RunState` gained `merchant_removals`, `gold_spent_merchant` and `merchant_visit`, all in the save round trip. The UI hook is `RunController.merchant_view()`.
- **New relic engine pieces** (5801fe7): a `damage_mult` stat (multiplies a source's hits before armor, and scales damage-over-time ticks), relic modifiers that scale with a run stat (`per_run_stat` and `per`; today `gold_spent_merchant`), a `merchant.free_rerolls` modifier, and a `tag` filter on the `hit_landed` relic event.
- **The shop panel** (ux 335f7bb..accf46f): two columns (relics left, cards right), Remove, Reroll and Leave in the footer, price pills, "Need N more gold", "Only sold here", a gold-left line and a give-one-up cost line. The tile reasons are short, with the full text in the tooltip. It fits 1024x600. Look values: `data/ui.json` `run_ui` (`shop_*`); words: `data/run.json` `ui.merchant`.
- **Launch flags and tools:**
  - `--run-node=N` (start a map run at node N) and `--run-gold=N` (start with N gold), for captures. `--run-auto-choose` now also splits ids on `+` (merchant ids hold a colon, and `capture_screenshot.ps1` splits `-Extra` on commas).
  - `--merchant`: turns the merchant on for one launch from `data/merchant_on.json`. Now redundant, because the shipped data has it on.
  - `tools\run_wave_sim.ps1 -Merchant` (same patch, for the sim), `tools\run_map_print.ps1 -Merchant -Routes -From N -Set "path=JSON"` (`-Routes` prints per-route medians in a sweep, `-From` starts the sweep at a seed, `-Set` overrides one config value and may repeat). `-Seed` map prints now list node ids per type.
  - `data/merchant_on.json`: the patch that holds exactly the values the merchant switch changes.
  - Capture presets `merchant_shop`, `merchant_shop_poor` and `merchant_removal` (qa). The wave sim reports merchant spending and a relic-trigger counter (`relic triggers fired:`) (qa).
- Tests: 1737 -> 1843 test cases (2 skipped), 137 -> 143 suites.

#### Changed
- **[Director decision] D40 = A (2026-11-06): every route has at least 1 rest.** `data/map.json` `path_rules.min_rest` none -> 1 (a new rule, validated, checked on every path and by the sweep). The other options were B (no guarantee) and C (a fixed rest on room 9). Recorded in GDD section 9 and `docs/MAP.md` section 3; archived in `docs/RESOLVED.md`.
- **Data values forced by `min_rest` (MAP2-A, accepted by game-lead), old -> new:**
  - `types.rest.weight` 10 -> 25 (20 and 30 were tried: a worst case of 905 attempts, or no better). Cost: more rest nodes. `max_rest` 2 and `min_fights` 6 still cap them per path.
  - `max_attempts` 200 -> 1000 (the allowed ceiling). At 200, 351 of 1000 seeds failed.
  - `MapGenerator` `TYPE_DRAWS_PER_GRID` (code) 10 -> 40, plus a one-pass rest pre-check. About 3x faster (a 1000-seed sweep took about 305 s at 10). Seeds that succeeded within 10 draws on their first grid keep their map; the rest generate different maps.
- **Switching the merchant on (ux, 8994863), old -> new:**
  - `types.merchant.weight` 0 -> 8.
  - `path_rules.relic_route` [5, 7] -> [6, 8] (the director's 6 to 8 relics for a relic hunter).
  - `estimate`: `merchant_price` 60 and `merchant_stock` 3 replaced by `merchant_prices` [60, 60, 90], then set to [30, 30, 45] with the prices below.
  - **Relic prices (new): none -> 30 / 45 / 65 for tier 1 / 2 / 3.** MAP0 had planned 60 / 90 / 130. With 60/90 the relic route's median was 5 relics, with 40/60 also 5, with 30/45 it is 6. With the old estimate and `relic_route` [6, 8], 284 of 1000 seeds failed to generate. **This is D41, a game-lead default waiting on the director, not a director decision** (the playtest added option D, 45/65/90, which qa's numbers say drops the relic route below 6). Cost: a tier 1 relic (30) is cheaper than a card (40) or a removal (50). The relic route sits exactly on the floor of 6.
  - The four lines flip together; `MerchantSwitch.shipped_problems` checks it.
- **The safe-route bot target** changed from a median of 2 to 3 relics to **at most 3** (the median is now 1 with the merchant on). The safe bot buys a removal, then a card, never a relic. `first` and `random` shop the same way.
- **Run sim baselines, old -> new:**
  - The straight run (`-NoMap`) moved because the 7 new relics widen the offers: Rogue 12/12, 57.3 s -> 57.5 s; Wizard 12/12, 62.5 s -> 63.3 s.
  - The arena hashes (1897787086, 4207041509, `-Plan` 1160207333) and the bot sim (846850403) did not move.
  - Map-on route numbers (`-Run -Seed 1 -Runs 12`, merchant on, median relics in brackets; qa's re-baseline). MAP1 values in the last column are for comparison:

    | Route | Rogue | Wizard | MAP1 (Rogue / Wizard) |
    |---|---|---|---|
    | first | 11/12, 58.1 s (3) | 11/12, 70.9 s (3) | 12/12, 66.2 s / 10/12, 60.6 s |
    | relic | 12/12, 56.4 s (6) | 12/12, 54.6 s (6) | 12/12, 52.1 s / 11/12, 63.2 s |
    | safe | 10/12, 57.6 s (1) | 12/12, 67.3 s (1) | 12/12, 58.4 s / 12/12, 65.0 s |

- **Capture presets re-pinned** (9321820): `map_mid`, `map_room9` and `map_chest_medium` to seed 54, `map_chest_large` to seed 157, because the generator change moved their maps. `removal_screen` and `bd2_relic_*` now pass `--no-map` (MAP1 carry-over fixed).
- **UI text and layout, old -> new** (ux; full list in DECISIONS "MAP2 ux calls" and `git diff ca5574a..110cc45 -- data/run.json data/ui.json`):
  - The room 9 to boss pick is now labelled "Face the boss" (title, line) instead of a bare one-option pick.
  - The relic-room offer title shows the chest size: "Relic room" -> `room_title_chest` "%s (%s chest)".
  - Relic Skip line: "Take nothing. It is free and leaves your card rejects alone." -> "Take nothing. Free: your card rejects stay as they are."
  - Map merchant hover: "Merchant: spend gold" -> "Merchant: spend gold on relics, cards or a card removal".
  - Map legend font 15 -> 18 and hint font 15 -> 17 (`data/ui.json` `map_screen`); the small-chest dots and Spite Knuckles' pips were enlarged for 1024x600.
  - New: a gold line on the map ("Spend your gold at the merchant (the square)."), shown only while a merchant can still be reached; the merchant node has a coin. The legend's merchant icon is still a plain square (cosmetic, open).

#### Fixed
- **`MapGenerator` script error when no node type is a candidate** (the `:59` carry-over): fixed in 66ba317 and its test un-skipped.
- **Capture presets landing on the wrong rooms with the map on** (`removal_screen`, `bd2_relic_elite`, `bd2_relic_room`, `bd2_relic_swap`): they now pass `--no-map`.
- **The dead `RelicProgress._triggers` fallback** was removed (8897701).
- The suite was ready for the switch before it happened: it ran green with the merchant off and on (e59a25f), so there was no red-suite return trip like MAP1's.

#### Docs and process
- **qa verdict: PASS with carry-overs** (no blocker). The sweeps found 0 failures on seeds 1 to 1000 (worst 479 of 1000 attempts) and on 9000 to 9999 (worst 410). The no-card gate is 0/12. Every number that must not move did not move. qa wrote 22 independent cases (shop fuzz, stock, determinism, prices, removal guard, swap, reroll, saves). Carry-overs are routed: gameplay-dev MAP3 housekeeping (`--run-node` and `--run-gold` accept bad values silently and have no unit tests; a stale "ships off" comment in `RunController.gd`; Liquidate Assets' stat refreshes only on a relic buy; `Merchant.items()` shows a relic as buyable at the cap when nothing can be given up, unreachable until boss relics exist), and BD3 (Request for Quotation is in about 79% of shops because the shop-only slot is tier-weighted; the Rogue safe route went from 12/12 to 10/12; Paperwork Fire rarely fires in real runs; watch Severance Package chains).
- **Playtest: no blocker** (captures and 40 bot runs, seed 200; nobody played by hand). Rests do not make runs too safe (about 1.1 to 1.4 per run, still 6 to 7 combat rooms). Findings routed: the shop opens focused on a purchase and stays that way (the 0.4 s arm delay already catches a carried-over Enter; eyes item 51 asks the director); **D42** (should every route pass a merchant? 5 of 8 first/safe routes reached one; default A, no guarantee) goes to the director; D41 got option D.
- Open director questions after this slice: D41 (relic prices) and D42 (a merchant on every route); see `docs/OPEN_ITEMS.md`.

## 2026-11-05 (Slice MAP1: the branching map)

### Slice MAP1: the branching map

Commit range 9cde725..bb328ed. gameplay-dev MAP1-A afdf30d..ed4e2aa, MAP1-B 2181b9b..3a2d9d8 and the post-flip fixes 3841b41..0226ec9; ux a1a4155..ac7baa2 (map turned on); qa 19272da..e1c7c5d (PASS with carry-overs, `docs/reviews/2026-11-05-map1-qa.md`); playtest e1e31b5 (no blocker, `docs/playtests/2026-11-05-map1-short.md`). Plan: `docs/MAP.md`. Calls: `docs/DECISIONS.md`, entries "MAP1 relic nodes on rooms 3-8" to "MAP1 qa: correction and carry-overs routed". The map is on by default.

#### Added
- **The run is a branching map of 10 rooms, on by default** (`data/map.json` `enabled` true; turned on in 9dd161b).
  - The map is generated from the run seed (its own RNG stream, so the spawner and player streams are untouched) and checked against every path rule (`MapRules`). A map that cannot meet the rules after `max_attempts` fails loudly.
  - You pick each next room on the map screen. A view-only map opens from the pause screen.
  - **Node types and what they pay:**
    - combat: a card offer and gold (12 to 18);
    - elite: a relic offer and gold (30 to 40);
    - relic stage (`relic_room`): a treasure chest, small, medium or large (weights 50/35/15), no fight, on rooms 3 to 8;
    - rest: heal or remove a card;
    - boss: room 10, pays nothing.
  - Merchant, mini-boss, curse and buff nodes are in the schema with weight 0 (not generated yet; MAP2 to MAP4).
  - **Gold is earned only**; spending comes in MAP2. It is paid once, when the room is finished (`_finish_room`), rolled from the run seed and node id so a reload cannot pay twice. Gold shows on the HUD, with a "+N" when a fight pays. Amounts: `data/run.json` `gold`.
  - `--no-map` gives the old straight run unchanged (verified by qa: Rogue 12/12 at 57.3 s, Wizard 12/12 at 62.5 s, the BD2 numbers exactly).
- **Engine** (afdf30d, ed4e2aa, 2181b9b): `MapConfig` (loader and validator, unknown keys rejected at every level), `MapGraph` (pure helpers), `MapRules` (path rules and the relic estimate), `MapGenerator` (seeded grid walks), `RunNodes` (the pick-next-node choice, gold rolls, chest odds, hover text; pending choice `PENDING_NODE`), `MapLaunch` (`--map` / `--no-map`) and `RouteBot` (route policies for the sim). A run is a map run when its `RunState` holds a map; `RunState` also gained `map`, `path`, `gold` and `xp_earned`. Chest sizes are assigned in a post-pass with their own stream, so map layouts did not change when chests were added.
- **Launch flags:** `--map` and `--no-map` (give both, repeat one, or give either a value and the launch exits 2 with "Launch refused: ..."). `--run-room=N` now lays the path along the first route (no gold for the skipped rooms).
- **Map screen and gold UI** (ux a1a4155..ac7baa2): `MapScreen`, `MapCanvas`, `MapNodeButton`, `MapLayout` (pure geometry and focus order), `GoldBadge` (HUD and map header). Default focus lands on a plain fight, so a reflexive Enter never takes an elite or a chest. Only reachable nodes take focus while picking. The pick swallows Space and the slot keys. New node shapes: merchant square, mini-boss triangle, curse X, buff up-arrow; chest size shows as hexagon size plus 1 to 3 dots. The legend lists only the types on the current map. The gold badge steps aside for the class pick and Game Over.
- **BD2 playtest readability carry-overs** (b6a76cf): `RelicCueLayer` and `RelicCues` (a floating relic name and ring where it triggered; repeats merge into "x3", at most 6 cues), `RelicProgress` (pips on a chip of an every-Nth relic; reads the new `RelicManager.trigger_progress`, 1958843), distinct chip marks within the held set, the pause relic list on an opaque plate, clearer Skip text that explains rejects, and an "After Move (Ctrl)" tag of 12 px or more above the slot.
- **Tools:**
  - `tools\run_map_print.ps1` (`-Seed`, `-Route`, `-Sweep N`): prints a seed's map and path-rule scores, or sweeps seeds 1..N for failures. Exit 1 on a rule break.
  - Wave sim: `-Route first|relic|safe|random`, `-Map`, `-NoMap`, and per-run route lines plus a ROUTE SUMMARY. Route bots live in the run sim because `bot_sim` builds no rooms.
  - Reload soak: `-Map` adds a map pass; without it the soak pins the straight run.
  - Capture presets `map_start`, `map_mid`, `map_room9`, `map_chest_large` and `map_chest_medium`.
- Tests: 1591 -> 1737 test cases (3 skipped, the carry-over tests below), 130 -> 137 suites.

#### Changed
- **Data and design values, old -> new:**
  - `data/map.json` `path_rules.min_branching` 0.6 -> 0.4. Four random walks gave no valid grid in 20,000 draws at 0.6. Revisit if routes do not feel like decisions (a merge-biased walk is the fix).
  - Type weights: combat 50 -> 40, elite 14 -> 16, relic_room 10 -> 14, rest 10 -> 10. Cost: fewer combat nodes, so fewer card offers and less gold per route; more elites and relic stages.
  - Relic node window (rooms) 3-9 -> 3-8, so room 9 never holds one (the BD2 playtest said a relic on room 9 gets one fight of use). The straight run's relic room is unchanged.
  - Large chest `min_tier` 2 -> 1 until tier 3 relics exist (with 2 tier 2 relics and no tier 3, a large chest with the floor would offer at most 2 relics, then fall back to cards). Restore 2 in MAP3.
  - `data/run.json` gained a required `gold` block (combat, elite and mini-boss ranges; boss, rest and relic stage pay 0).
  - The `rooms.relic_room: []` stopgap in `data/run.json` is removed.
  - `ui.relic.swap_line_one` is now validated by `RunConfig` when present.
- **Map screen layout values, old -> new** (ux; table in DECISIONS "MAP1 ux calls"): room plate 280 -> 304, relic chip 26 -> 30, relic font 12 -> 15, condition font 11 -> 13, `relic_list_max_height` 150 -> 320 (new min 90), `relic_list_width` 560 -> 640. The boss bar width is now floored to whole pixels.
- **Run sim baselines with the map on** (`-Run -Seed 1 -Runs 12`; plain `-Run` follows the first route): Rogue 12/12 at 66.2 s boss median, Wizard 10/12 at 60.6 s. Other routes are in the README. The map-off run (`-NoMap`) keeps the BD2 numbers.
- Elites and the relic stage on the map reuse the BD2 relic offer; the class pick still comes first and only at the start of a map run (788eca8).

#### Fixed
- **c1e ghost-look flake root-caused and fixed** (eee5813, qa): a test setup race (the pass-through grant landed after depenetration had already separated the bodies under load). 24/24 under CPU load, was 7/24 failing. The flake the README listed as known and unfixed is gone.
- **The suite was briefly red after the map flip** (49 of 1709 cases fail, 3b78f46): tests about the straight run now pin it with `RunSession.map_override = 0` (3841b41, ac7baa2, 19272da); old-data pins were updated to the shipped data.
- The reload soak runs with the straight run pinned and gained a map pass (1958843).

#### Docs and process
- MAP1 ran as two gameplay-dev sittings: A (engine, shipped with the map off) then B (run flow), then ux turned the map on and qa re-baselined. Route bots live in the run sim, not the bot sim; this corrects MAP.md section 8 (DECISIONS, "MAP1 split into two gameplay-dev sittings").
- **qa verdict: PASS with carry-overs** (no blocker). Independent generator sweep: 1000 seeds the dev sweep never used (5000..5999), all pass; maps identical across processes. qa corrected a dev baseline: Rogue relic route is 12/12 at 52.1 s, not 11/12 at 52.9 s (the README has the corrected number). Carry-overs routed: the `bd2_relic_elite`, `bd2_relic_room`, `bd2_relic_swap` and `removal_screen` presets land on the wrong rooms with the map on, the generator script error and the dead `_triggers` fallback (all MAP2); the `from_dict` node-pending soft lock and negative gold (MAP3, before any save file exists). None is reachable from play or shipped data.
- **Playtest: no blocker** (bot sim and captures only; nobody played by hand). Findings: both room-1 nodes are plain combat, so the first choice is cosmetic; the "safe" route often is not safer (3 of 4 Rogue routes had no rest); gold has no use until MAP2; the bot runs are far shorter than the GDD's 30 to 60 minute target (a pacing question, not a MAP1 regression).
- **New director question D40: should every map route have a rest?** Options A (default: at least 1 rest on every path, a new `min_rest` rule, built in MAP2), B (no guarantee), C (a fixed rest before the boss). Open, no decision yet (`docs/OPEN_ITEMS.md`).
- **Human-playtest note, 2026-11-05 (director feedback, recorded):** "Relics feel fun so far, builds are starting to get more exciting and strategy starting to fold in." Archived with the answered part of item 49 in `docs/RESOLVED.md`.

## 2026-11-04 (Slice BD2: relics; Slice BD1: synergy core; director decisions D34-D39; Slice PL3 below)

### Slice BD2: relics

Commit range de84af1..eb290e1. gameplay-dev BD2-A 3b1ac07..fe051cc (engine) and BD2-B 673db13..1af42c5 (content and run flow); ux 4040259..92e4a31 and the fix 9901776; qa 9f9a241..1d9d3b9 and the addendum 1b53f62 (PASS with carry-overs, `docs/reviews/2026-11-04-bd2-qa.md`); playtest no blocker (`docs/playtests/2026-11-04-bd2-short.md`, 87116a8). Planned tag: `playtest-2026-11-04-BD2`. Plan: `docs/BUILD_DEPTH.md` section 4. No director decisions were made in this slice.

#### Added
- **Six relics** (673db13), one file each in `data/relics/`: Pyre Insurance, Smoldering Grudge, Lingering Embers, Second Wind (Unwillingly), Spite Knuckles and Heavy Sigh. Rules and numbers are in the files. Exit Strategy slipped to BD3 (a line of fire along the dash path needs new zone placement code).
- **Elite rooms now offer a relic** (pick 1 of 3, or a free Skip that spends no reject) instead of a card offer; with nothing eligible the elite gives its card offer (0273b65).
- **A relic room** (0273b65, aa6be14): once per straight run, with no fight, offering the same. It turns one combat room into the relic room (the run stays 10 rooms), on on-screen rooms 3 to 9 (`first: 2, last: 8` in `data/run.json`), never beside the rest room, the elite or another relic room. Its plate reads "Relics". MAP1 replaces it with a map node.
- **Relic cap 20 and the give-one-up step** (0273b65; the rule is D34 = C, decided earlier in BD1 and built here): at the cap, taking a relic first asks which owned relic to give up. Cancel keeps everything (and, since 9901776, is focused by default). Boss-tier relics can't be given up. No duplicates, and a given-up relic never returns that run. Tier odds per act are in `data/run.json` `relics.tier_weights` (act 1: 80/20/0, act 2: 15/70/15, act 3: 5/25/70; the straight run uses act 1). `relics.enabled` false gives the pre-BD2 run exactly.
- **The full CombatEvents relay** (93abb5c): `hit_landed`, `enemy_killed`, `status_applied`, `status_ended` (reasons `expired`, `owner_died`, `consumed`), `attack_fired`, `dash_ended`, `player_damaged`, `zone_started/ended`, `room_started/cleared`, with an `origin` string on every hit and status (`light`, `heavy`, `card:<id>`, `status:<id>`, `relic:<id>`, `enemy`). On a kill the order is `hit_landed`, `enemy_killed`, `status_ended(owner_died)`, then the enemy's own died handler.
- **`RelicManager`** (c51c718, fe051cc): a per-room child of the run, not an autoload. Relic effects run deferred (end of frame) because Godot blocks spawning a projectile or dash inside a physics callback. A recursion guard ignores relic-origin events unless a trigger sets `allow_relic_origin`, and chains stop at depth 1. Counters and internal cooldowns reset every room.
- **Relic loader and validator** (c51c718): `RelicSchema`, `RelicDatabase`, `RelicConfig`, `RelicOffer`. Reserved `sources` values (`starter`, `event`, `altar`, ...) and `sacrifice_cost` are accepted but unused; `rule_text` and `flavor_text` are required (673db13). A missing or empty `data/relics/` means no relics.
- **New stats and effect template** (673db13): `card_damage_mult_vs_status.<id>` (card-origin damage only), `zone_duration_mult` (clamped to the zone cap) and `zone_status_chance` (additive, capped at 1); the effect template `reduce_cooldown {slot_type, seconds}` (used by Second Wind).
- **`JsonDataTable.get_raw`** (7d11d75), for validators that must see a non-object entry.
- **HUD and screens** (ux 4040259, e1a216f, 2d04186, 6ffff7b):
  - a relic chip row under the dodge pips (two-letter mark, pool-colour frame); a trigger lights the chip and shows a name tag, and rapid repeats stay lit with an "xN" count instead of strobing (`RelicRow`, `RelicFlash`);
  - relic offer cards (a "Relic" band, tier, pool, keyword chips, rule text, flavour) and a green "Free" Skip tile;
  - the give-one-up screen (a "Taking: X" plate, the list to give up, a "Cannot be given up" row for boss relics, Cancel);
  - the pause screen lists owned relics (name, rule, flavour) and notes given-up ones; the list scrolls with Up and Down.
- **Launch flags** (0273b65): `--relics=a+b`, `--relic-offer=a+b+c` and `--relic-cap=N`. Bad input (unknown or repeated id, an offer longer than `relics.offer_count`, a cap below 1) exits 2 with "Launch refused: ...".
- **Capture tooling** (2ccbc73, 92e4a31): presets `bd2_relic_elite`, `bd2_relic_room`, `bd2_relic_swap` and `bd2_pyre_explosion`; a scenario `relics` key; the scenario `bd2_pyre_explosion`.
- **Sim tooling** (2ccbc73, 1f74ff6, 1aff708): wave sim `-Relics`, `-RelicCap`, `-Swap`, `-NoRelics`, damage by source (including relics), fingerprint spread, relic pick/skip/swap counts, a `BOSS TIMES` line with timed-out fights apart, and a soft-lock detail line; bot sim `-Swap` (with `-Plan -Deck`); the bot relic policy `RelicPolicy`.
- Tests: 1413 -> 1591 test cases, 121 -> 130 suites (gameplay-dev's BD2 suites, ux's, and qa's `bd2_qa_test`; 1591 verified by a full run in the docs pass).

#### Changed
- **`chip_keyword_color` `#d8c8ff` -> `#b8dcff`** in `data/ui.json` (ux 6ffff7b), so keyword chips don't clash with the relic violet.
- **BD1 readability fixes from the playtest** (ux 3bf739a): the primed marker has a 12 px font floor and flashes "USED" or "GONE" when the prime ends; an unlit slot shows a dim condition line such as "Needs Burn" (it honours its font floor, 6ffff7b); a card that is both Keystone and Payoff gets one gold "Keystone + Payoff" chip; reward cards that need a Movement cast note that the dodge doesn't count; "3 s" no longer breaks across a line.
- **`status_damage_mult` validator floor** (7d11d75): a buff or relic modifier at or below -1 is rejected. The factor stats added in 673db13 have the same floor.
- **Run baselines with relics on** (wave sim `-Run -Seed 1 -Runs 12`, verified by tech-writer): Rogue and Wizard each won 12 of 12; boss-time medians are 57.3 s (Rogue) and 62.5 s (Wizard); relic damage is about 1% of all damage (Rogue 0.45%, Wizard 1.15%, from qa). The bot sim can't carry relic baselines (it builds no rooms), so these are `wave_sim -Run` numbers. With relics off (`-NoRelics`) the run line matches the pre-BD2 repo.
- **No seeded hash moved.** Arena `-Seed 1` 30 s 1897787086 and 90 s 4207041509, arena `-Plan` 1160207333, bot sim 846850403 and every `-Plan` checksum are unchanged from BD1.
- Relics roll their chances on the player's `status_rng`, so holding relics shifts card status rolls (expected; only relic runs).

#### Fixed
- The seed 7 no-card Rogue "soft lock" (`-Run -LightHeavyOnly -Class rogue -Seed 7`) was a bot deadlock, not a game bug: after 45 s with no kill and one enemy left, the bot stopped dodging. It now reads LOST (1aff708).
- `JsonDataTable.get_entry` no longer crashes on a non-object entry; it errors loudly and returns `{}` (7d11d75).
- The `slice6_qa_test` same-seed crowd flake is mitigated by one discarded warm-up crowd run (7120158 found the cause: the first crowd run in a suite differs from the rest from tick 73; qa applied the patch in b770c4c). About 1 failure in 10 isolated runs before, 0 in 15 after.
- Give-one-up screen (9901776): it opens with Cancel focused, and the text is singular for a cap of 1 ("You hold 1 relic").
- BD1 qa carry-overs (qa b55f5e8): Fan the Flames' cooldown is asserted on the first card line, `w1b_content_test` skips the four BD1 Fire cards by id instead of tag, an escaped newline in `m3c_qa_test`.

#### Docs and process
- BD2 ran as two gameplay-dev sittings, BD2-A (engine, no visible change) and BD2-B (content and run flow), then one ux, qa, playtest and docs pass (3b1ac07).
- Correction to the BD2 plan: the bot sim can't move with relics (see Changed); relic baselines are the `wave_sim -Run` numbers (DECISIONS "BD2-B").
- The relic room keeps on-screen rooms 3 to 9 for now (about 31% of seeds put it on room 9); MAP1 replaces it. 3d item 6a (save robustness: `RunState.from_dict` crashes on a null, array or object `offer` entry) moved into MAP3, before the save file ships.
- Known issues, not fixed in BD2 (full list: `docs/reviews/2026-11-04-bd2-qa.md`, "Carry-overs"): `c1e_cues_test` "ghost look lasts until the player is clear" is a flake that predates BD2 (about 1 in 5 isolated runs), routed to qa with MAP1; the chain-depth cap covers only work inside the deferred flush (a relic-spawned projectile or zone that hits later runs at depth 0; nothing shipped does this); `from_dict` doesn't check that owned and given-up relics are disjoint, fit the cap or exist; `RunConfig._validate_relic_text` doesn't format-check `swap_line_one`; the pause relic list has no backing panel at 1024x600; the `rooms.relic_room: []` stopgap in `data/run.json` goes with MAP1.
- Playtest findings (`docs/playtests/2026-11-04-bd2-short.md`): no blocker; captures and scripted input only, no hand play. Fixed before close: the give-one-up focus and plural. Not faults: the Wizard offered Spite Knuckles (only through `--relic-offer`, which skips the pool filter), and "20 held" (the cap is 20). Carried to MAP1's ux step: a floating relic name or ring at the trigger point, a Spite Knuckles counter, hard-to-tell-apart chip initials, the pause list showing 2 of 3 relics in a short box, "Reject" unexplained on the relic offer, and "After Move" naming the key. Kept as built (game-lead): the relic room up to room 9, and Spite Knuckles counting per room. Balance signal for BD3: with relics on, the Controlled Burn `-Plan` boss median drops 73.4 s -> 54.2 s (6 runs, noisy).
- Director note, not a decision: a playtester (the director's brother) suggested making the game free to play and charging only for cosmetics. The director isn't on board: in a single-player game cosmetics probably sell poorly, since they sell mostly where players want to look good in front of others. Recorded in GDD section 15 (de84af1), not scheduled.
- README (tech-writer): new Relics section, the `--relics`, `--relic-offer` and `--relic-cap` flags, the four BD2 capture presets and the pause capture command, the wave sim and bot sim BD2 options, and a rewritten Last verification block. ARCHITECTURE: the Relics section (relay, `RelicManager`, offers, `RunController` relic API, UI pieces), "A relic" checklist and the new sharp edges.

### Slice BD1: cards start to work together

Commit range c1754cd..33765f0. gameplay-dev BD1-A a141865..7c5a66b (engine), BD1-B 3e297d5..49b117b (content and tooling); ux b61c388..1d3cbda; qa PASS with carry-overs (`docs/reviews/2026-11-04-bd1-qa.md`, 2796aa4); playtest no blocker (`docs/playtests/2026-11-04-bd1-short.md`, 433ca0b). Planned tag: `playtest-2026-11-04-BD1`. Plan: `docs/BUILD_DEPTH.md` sections 3 and 5 to 7.

#### Added
- **Tags and keywords** (a141865). A card's tags are derived from its effects (Projectile, Melee, Area, Zone, Dash, Heal, Burn, Bleed, Buff) by `src/cards/CardTags.gd`, so nobody writes them by hand. Authored `keywords` (Primer, Payoff, Keystone) are validated against the new `data/keywords.json` (`src/cards/KeywordDatabase.gd`). `CardDatabase.tags_for(card_id)` is the API.
- **The CombatEvents relay** (6ca48f0). A new autoload, `src/core/CombatEvents.gd` (class `CombatEventsRelay`). It holds a game-time clock and a short cast history (`src/cards/CastHistory.gd`) and announces each card cast. BD2's relics will listen here. Code that must also compile in an `-s` script reaches it through `CombatLink.events()`.
- **Effect conditions** (6ca48f0). Any card effect can carry an optional `condition` next to `template` and `params`; the effect is skipped when it is false. Types built: `target_has_status`, `cast_within` and `zone_active` (`src/combat/EffectCondition.gd`). The later BUILD_DEPTH condition types are rejected by the validator until they exist.
- **Primed buffs** (6ca48f0, 7c5a66b). A `buff` with `consume_on_cast` and optional `charges` is used up by the next matching casts, or when its duration ends. A primed cooldown skip is the stat `slot_cooldown_skip.<slot>`. A card never uses up its own prime.
- **`status_damage_mult`** (6ca48f0): a stat (`status_damage_mult.<status>`) that scales the damage a caster's damage-over-time statuses deal. Only status ticks read it.
- **aoe `anchor: "caster"`** (6ca48f0): a delayed blast stays where the caster stood when the card was cast (Parting Gift uses it). It can't be combined with `max_range`.
- **8 new cards** (3e297d5): Fan the Flames, Heat Sink, Kindling and Slow Burn (Fire pool), Drive-By and Momentum, Unfortunately (Rogue pool), Parting Gift and Well, Actually (Wizard pool). They carry the new keywords and conditions. Numbers are in `data/cards/`.
- **4 archetype debug decks** (3e297d5): `rogue-kindling`, `rogue-hit-and-run`, `wizard-controlled-burn`, `wizard-departure-lounge` in `data/debug_decks/`. `--list-decks` shows them. The five older presets were updated for the new cards (the `mixed-*` decks' `full` lists now include them).
- **Plan-aware bot** (3e297d5, 5be84e9, 22ee886). `src/debug/PlanPolicy.gd` plays the card slots from the `condition` data: it casts a payoff when its condition is live, swaps a card that can't pay off soon, and spends Movement to set up a combo. Both sims take it: `tools\run_wave_sim.ps1 -Plan` and `tools\run_bot_sim.ps1 -Plan`; the bot sim also takes `-Deck <preset>` with `-Plan`. Without `-Plan` the standard policy runs unchanged. The bot sim uses a stand-in caster (`tools/sim_caster.gd`).
- **HUD cues for the new rules** (ux b61c388, ba8c9ad):
  - tag chips on every slot (up to 3; keywords filled, derived tags outlined; `src/ui/ChipRow.gd`);
  - a **LIVE glow** (yellow rings, corner brackets and a LIVE pill) on a slot whose condition is true now, eased so it doesn't flicker (`src/ui/SlotCues.gd`);
  - a **primed marker** (a cyan bolt, "xN" for several charges, and a drain bar) on a slot with a primed buff.
  - The data for all three comes from `src/cards/SlotSynergyView.gd` and `SlotSynergy.gd`; look values are in `data/ui.json` `hud`.
- **Keystone chips on rewards and removal** (ba8c9ad): the card offers and the removal grid show the same chips; a keyword's rule text is a tooltip only.
- **Capture and launch tooling** (17fbe44): `tools\capture_screenshot.ps1 -Preset <name>` runs a named capture from `tools/capture_presets.json` (`reward_screen`, `removal_screen`, `boss_smash`, `bd1_reward_keystone`, `bd1_reward_keystone_wizard`, `bd1_glow_target`, `bd1_primed`, `pl3_heavy_bolt`). `--run-offer=a+b+c` forces the first reward offer (capture only). Scenarios take two new keys, `deck` (a fixed card list) and `_note`. New capture scenarios `bd1_glow_target` and `bd1_primed`; the `pl3_*` ones now use fixed decks.
- Tests: 1289 -> 1413 test cases, 111 -> 121 suites (gameplay-dev's BD1 suites, ux's, and qa's `bd1_qa_test`).

#### Changed
- **HUD card slot height 134 -> 142 px** (ux 4c8ffb6) to make room for the chip row (`data/ui.json` `hud`). The `pl3_qa_test` pin moved with it.
- `CardSummary.effect_line` puts condition lines after the cooldown, each on its own line (ux ba8c9ad).
- Card buff wording now covers the primed cooldown skip and `status_damage_mult` (3e297d5).
- **Seeded baselines rebaselined.** The new cards fill the sim slots, because the arena player and the bot sim fill slots from every card in the owned pools; qa proved the 8 new cards are the only cause (taking them out restores the old hashes).
  - arena wave sim, seed 1, 30 s `state_hash`: 2333565009 -> 1897787086;
  - arena, 90 s: 1212800 -> 4207041509;
  - bot sim `-Rooms 20 -Seed 3`: 2281795515 -> 846850403.
  - New plan baselines (`-Plan`, bot sim `-Rooms 20 -Seed 3`): standard 2387448677, `rogue-kindling` 3642396276, `rogue-hit-and-run` 212612574, `wizard-controlled-burn` 1247966865, `wizard-departure-lounge` 1255552678. Wave sim arena `-Plan`, 30 s, seed 1: 1160207333 (DECISIONS "BD1-B").
  - Side effect: a new run can now roll the new cards into its random starting slots, as any pool card can. The preset decks are unchanged. Availability control is 3d item B (D23).
- **New `data/player.json` key `dodge.counts_as_movement_cast`** (false): the one switch for D39 (below).
- **[Director decision, D34 = C]** Relics over a 30-room run: relics grow with the run, with a hard cap of **20** that is hard to reach, no duplicates, and a swap at the cap. Old: 6-8 relics for a hunter, cap 10 (D22). The at-cap fallback changed from "a card offer instead" to "give a relic up" (the swap). BD2 builds it.
- **[Director decision, D35 = A]** Card rejects stay at 3 per run.
- **[Director decision, D36 = A]** The boss volley is unchanged up close for the Wizard.
- **[Director decision]** Relic tiers are 1/2/3/boss, with odds that rise per act (numbers in `docs/MAP.md` section 4.5, all data).
- **[Director decision]** Elites always give a relic and never cards.
- **[Director decision]** Boss-tier relics come only from the act-end mini-bosses (2 per run).
- **[Director decision]** Mini-bosses also offer rare cards (act 1) and legendary cards (act 2).
- **[Director decision]** Card rarity by act: rare cards from act 2, legendary cards from act 3.
- **[Director decision]** The knockback fix is good ("always found it strange to be flung across the room").
- **[Director decision]** Relic sources follow the Slay the Spire / The Last Flame model (plan in `docs/BUILD_DEPTH.md` section 4.7).
- **[Director decision]** The starter relic is chosen in the loadout from the unlocked tier 1 starter relics, with no random restarts. This reverses the BD0 default "no starting relic for now".
- **[Director decision, D37 = A]** A dig relic adds a rest Dig action that replaces both the heal and the card removal at a rest site (MAP4).
- **[Director decision, D38 = A]** Curses are cards: a useless or harmful card in a slot's mini-deck that you swap past, removed like any card. They don't count toward slot minimums (MAP4).
- **[Director decision, D39 = A]** The dodge roll doesn't count as a Movement cast for card combos; only Movement cards do. It is built that way. Switch: `data/player.json` `dodge.counts_as_movement_cast` (false = A).
- Director feedback, not decisions: boss length is fine, and the 1-dodge Wizard still seemed fine.
- Director note, not a decision: an idea for a corporate-office setting. The run would be a 30-floor skyscraper with elevators between rooms, matching three acts of 10 rooms. It is an idea in GDD section 15, not scheduled.

#### Fixed
- The 1024x600 card-strip row overflow (3.3 px -> 0.3 px) and the Next line sitting under the slot frame (ux b61c388, 4c8ffb6).
- **PL3 carry-overs** (17fbe44, 22ee886): a scenario with its own `character` plus a different `--class` is now refused with exit 2 (as `--deck` is); `-StartRoom` past the last room prints a plain "note:", because the PowerShell wrappers fail on any WARNING line; capture scenarios use fixed decks so a capture shows the same cards every time; new capture presets (above); the dodge input is released in `DodgeSwitch.reset()` so a press can't leak between test suites.

#### Docs and process
- README (tech-writer): the corrupted `toolsun_wave_sim.ps1` command lines are `tools\run_wave_sim.ps1` again (a lone carriage return in the file had also made git treat README as binary); the contradictory `--class` lines are one rule; `--full-deck` counts are 30 Rogue / 28 Wizard (were 24 / 22); the removal example uses room 6; new sections for `-Plan`, `-Deck`, `-Preset`, `--run-offer`, the `deck` and `_note` scenario keys and the HUD cues; the Last verification block is rewritten with this pass's runs.
- BD1 was split into two gameplay-dev sittings (BD1-A engine, BD1-B content and tooling), with one ux, qa, playtest and docs pass after both (b66bc0a).
- The relic candidate lists from the director's two Gemini rounds are adapted, unscheduled, in `docs/BUILD_DEPTH.md` sections 4.5 and 4.8.
- Still open in `docs/OPEN_ITEMS.md`: item 47 (my numbers for the relic and card tiers) and item 35 (builds, after BD2). D34 to D39 and items 39 to 42 are archived in `docs/RESOLVED.md`.
- Known issues from qa, not fixed in BD1 (full list: `docs/reviews/2026-11-04-bd1-qa.md`, "Carry-overs"): the `slice6_qa_test` same-seed crowd test is flaky (1 failure in 6 isolated runs at the PL3 close, 2 in 6 at BD1; it predates BD1); `JsonDataTable.get_entry` crashes loudly on a non-object entry; the Rogue with no cards soft-locks on seed 7 room 1 in the wave sim (`-Run -LightHeavyOnly -Class rogue -Seed 7`, predates BD1); balance signals left for BD3 (Controlled Burn reaches 59% of the standard Wizard's boss time against a 70% floor; removing Drive-By helps Hit and Run by 23%).

### Slice PL3: playtest fixes; director decisions D31-D33 (earlier the same day)


Commit range 9532409..7f21afb. Planned tag: `playtest-2026-11-04-PL3`. qa: PASS (`docs/reviews/2026-11-04-pl3-qa.md`, 16387bf, e38bdd2). Playtest: no blocker (`docs/playtests/2026-11-04-pl3-short.md`, 7f21afb).

#### Added
- Ward aura: while an armor buff is up the player shows a pulsing ground ring and a faint bubble. Look is data: `data/vfx.json` `buff_cues`, keyed by the buffed stat (`TemplateVfx.buff_aura`, `VfxConfig.buff_cue`).
- Card projectile `look` ({color, scale, ball_scale}, validated by `EffectTemplates.validate_look`): Three Bolts is lime, Overqualified Bolt is white, ball 1.9x and trail 2.4x. The hit radius is unchanged.
- Volley safe-gap tint is now drawn only where a gap is really clear (`src/effects/VolleyGaps.gd`, new `boss_volley_gap_*` keys in `data/vfx.json`; minimum half width `boss_volley_gap_min_half_width`).
- New tooling (see README): capture `--press=<t>:<action>` (`-Actions`) via `src/debug/ScriptedInput.gd`; `--at-boss-attack=<id>` (`-AtBossAttack`); `--class` now applies to scenarios (`-Class`); wave sim `-StartRoom N` (with `-Run`); `tools/VolleyProbe.tscn`. New capture-only scenarios `pl3_ward`, `pl3_bolts`, `pl3_heavy_bolt`.
- Tests: 1244 -> 1289 test cases, 108 -> 111 suites.

#### Changed
- **[Director decision, D31 = A]** The rest stop stays "heal 30% or remove a card". The heal is one number in data.
- **[Director decision, D32 = A, plus his additions]** Map shape as proposed (4 lanes, whole map visible, left to right). Also, a run becomes **three acts of 10 rooms (30 rooms)**. Acts 1 and 2 end in a mini-boss, act 3 in the final boss. Target run length is 30-45 min (old: 30-60 min, with a 15-25 min prototype note). A player can save progress and return later (autosave between rooms, built in MAP3). Until MAP3 a run stays one 10-room act.
- **[Director decision, D33 = B]** Mini-bosses and curse/buff rooms come before loadouts. Slices are now MAP3 (three acts, mini-bosses, act scaling, save/resume) and MAP4 (curse/buff rooms). Run order: PL3 -> BD1 -> BD2 -> MAP1 -> MAP2 -> MAP3 -> MAP4 -> 3d -> BD3 (old: ... MAP2 -> 3d -> MAP3 -> BD3).
- Damage numbers move below the boss bar while it shows (`data/ui.json` `damage_numbers.boss_bar_gap`; `BossHpBar.occupied_bottom()`).
- Dodge return pulse: 0.3 s -> 0.6 s, with a swell.
- Reward and removal screens: **[Director decision, 2026-11-02]** the number keys, number hints and badges are gone. The hint now reads "Arrow keys move, Enter or click confirms". "Key Q" chips are key caps. The reward line "Recovery (R) now: A" became "In slot: A" (`data/run.json` `ui.option`).
- HUD card slots 126 -> 134 px, preview row 38 -> 46 px.
- Seeded baselines (wave sim, qa's figures): arena 90 s `state_hash` 819020947 -> 1212800. The 30 s hash (2333565009) and bot sim checksum (2281795515) are unchanged.

#### Fixed
- Knockback on the player: a 9 m/s hit carried the Wizard 19.6 m, now 2.25 m. The cause was the walking velocity being read back with last tick's knockback still in it (`Player._applied_knockback`). It applied to every hit on the player.

#### Docs and process
- **New director questions** (waiting in `docs/OPEN_ITEMS.md`): D34 (relics over 30 rooms), D35 (rejects over 30 rooms), D36 (the boss volley up close for the Wizard).
- Volley fairness measurement (`tools/VolleyProbe.tscn`): mostly a bot blind spot. There is no safe gap at 6 m or closer. Nothing was retuned.
- Director decisions recorded in GDD §9, `docs/MAP.md`, BUILD_DEPTH §4.1 and the ROADMAP (6c020cf). Answers archived in `docs/RESOLVED.md`.

## 2026-11-03 (Slice H3: dodge return and enemy speed-up; MAP0: map design doc; director decision D30)

Commit range 0cf2a09..305b13b (D30 records from 98efccd). Planned tag: `playtest-2026-11-03-H3`. qa: PASS (`docs/reviews/2026-11-03-h3-qa.md`). Playtest: no blocker (`docs/playtests/2026-11-03-h3-short.md`).

### Added
- **MAP0 (design only, docs, no code, no tag; commits 1db347a, ee38ac0, e77653d, adf6468):** new `docs/MAP.md` (owner game-lead), the [PROPOSED] branching map plan:
  - Grid of 10 rooms x 4 columns, read left to right, whole map visible. Every path is 10 rooms with at least 6 fights.
  - Node types: combat, elite (relic), relic stage, rest, merchant. Later: mini-boss, curse room, buff room.
  - Gold (run-only): combat 12-18, elite 30-40, mini-boss 45-55. Prices: relics 60/90/130 by rarity, cards 40, card removal 50 (+25 each time).
  - Route arithmetic: a relic-hunter route gets 6-8 relics but about 3 card offers. An ignore-relics route gets 2-3 relics.
  - A `map.enabled` switch. XP and between-run points are reserved only.
  - Build plan: MAP1 (map, gold), MAP2 (merchant), MAP3 (mini-bosses, curse and buff rooms).
  - GDD §9 summary and §14 items 12-13 updated. New director questions D31 (rest stop), D32 (map shape), D33 (MAP3 timing), each with default A, waiting in `docs/OPEN_ITEMS.md`.
  - Run order is now H3 -> MAP0 -> PL3 -> BD1 -> BD2 -> MAP1 -> MAP2 -> 3d -> MAP3 -> BD3.
- Dodge is back on **Space**. This is the build of the D29 = B decision from 2026-11-02 (the values below are game-lead's) (cee653d).
- New scenario `boss_volley`: a boss with 9999 HP that only throws Fan of regrets, for wind-up and mid-flight captures (d22b08d).
- New `pressure.telegraph_scale` in `data/enemies.json` (optional, default 1.0), shipped at 0.85 (783d552).
- New `data/vfx.json` keys `boss_volley_lane_alpha_start`, `boss_volley_lane_alpha_end` and `boss_volley_lane_max_length`, and a `ramp` parameter on `TemplateVfx.enemy_shot_lane` (6f89eea).
- Tests: Ctrl-held E/F/R casts, swap binding flags, the phase-3 lane ramp, boss add telegraph scale, volley threat tip (3dc74fb, 44eff31, f1a3f88). Suite now 1244 test cases in 108 suites.

### Changed
- **[Director decision, D30 = A]** Relics come only from the merchant, the relic stage and elites. Rest rooms and card reward screens do not offer relics. Old plan: rest room "heal 30% or a relic", and 1 in 4 reward screens showing a relic. His reason: heal-or-relic is too obvious a choice, and Recovery already heals. His note: the rest-room heal may be removed altogether; MAP0 will propose. Recorded in GDD §4a and §9, BUILD_DEPTH §4.1 and §11, ROADMAP BD2 and MAP0 (98efccd).
- Dodge (cee653d), values from D29 = B:
  - `dodge.enabled` in `data/player.json`: false -> **true**.
  - Default charges: 3 -> **2**. Rogue 3 -> **2**, Wizard 2 -> **1** (`dodge_charges` in `data/characters.json`).
  - Movement slot key: Space -> **Ctrl**. Movement swap: Shift+Space -> **Shift+Ctrl**. The dodge action is bound to Space.
  - Slot keys Q/E/F/R now still cast while Ctrl is held. Old: Ctrl+key did nothing. Shift pressed after Ctrl still swaps (`Player._swap_by_late_modifier`).
  - Windows caveats, not fixed: Ctrl+Shift is the layout-switch hotkey on multi-layout machines, and Ctrl+Space toggles the IME on some CJK setups.
- Enemy speed-up (783d552):
  - `pressure.attack_rate_scale`: 1.0 -> **1.1**.
  - New `pressure.telegraph_scale`: 1.0 -> **0.85**, applied to non-boss telegraphs, boss adds included. Telegraph durations: 0.45 -> 0.38, 0.7 -> 0.6, 0.9 -> 0.77.
  - Fan of regrets wind-up: 0.9 -> **0.75** (phase 3: **0.64**).
- Fan of regrets lanes now ramp in alpha from 0.22 to 0.9 across the wind-up, capped at 14 m. Old: the lanes started at 0.5 and faded to 0 (6f89eea).
- Bot clear rates, 20 seeds, H3 as shipped: Rogue 17/20, Wizard kite 15/20, Wizard no-kite 18/20. Every `-LightHeavyOnly` config 0/20 (no-card gate passes).
- Arena sim hashes moved: seed 1, 30 s: 2816045921 -> 2333565009 (as recorded in the README before H3); 90 s: 3667433295 -> 819020947. Bot sim `-Rooms 20 -Seed 3` is unchanged at 2281795515.

### Fixed
- `Boss.in_threat` measured the volley lane from the boss centre, 0.6 m short of the drawn lane and the pellets' reach. It now measures from the muzzle (`BossRules.MUZZLE`), which fixes the bot's and the threat check's view of the volley (d22b08d). A new test traces every pellet of a real volley against the drawn lanes (within 0.03 m).

### Docs and process
- CLAUDE.md now lists `docs/MAP.md` under game-lead's docs.
- Director feedback on H3 (2026-11-03): one Rogue run "still felt good, never overwhelmed, let's keep going." OPEN_ITEMS item 38 (H1 pace) was merged into item 40 (Wizard side still open). It was not resolved, so nothing was added to RESOLVED.md.
- docs/RESOLVED.md gains D30. README controls, scenario list and last-verification block updated. ARCHITECTURE updated for the dodge, `telegraph_scale` and the lane ramp.

## 2026-11-02 (Slice BD0: build-depth design doc; Slice H2: dodge-off trial; Slice H1: enemy pressure pass; Slice K1: key labels follow the bindings; director decisions: build depth, pressure pass, loadouts, run order, OPEN_ITEMS pass)

### Director answers: dodge return (D29), relics (D22, D24), stacking (D25), menu keys (D26), map (D28)

Docs only: no code, no new commands, no new assets. Commit range a6c33e6..c475c58 (touched GDD, BUILD_DEPTH, ROADMAP, DECISIONS, OPEN_ITEMS, STATE). **Nothing in the game has changed yet:** the dodge change is built in the upcoming slice H3.

#### Changed
- **[Director decision, D29 = B: the dodge is back]** Recorded in GDD §3 and §5, built in H3. His reason: without the dodge the game didn't feel as fluid or fun, though it was still very winnable. Old -> new:
  - `dodge.enabled` false -> **true**.
  - Dodge charges: Rogue 3 -> **2**, Wizard 2 -> **1** (the `data/player.json` default 3 -> **2**).
  - Dodge key: none -> **Space**. Movement slot: Space -> **Ctrl**. Movement swap: Shift+Space -> **Shift+Ctrl**. Utility stays **F**.
  - Enemy attacks and telegraphs get "a little faster", especially the boss's Fan of regrets.
- Game-lead starting values for that speed-up, **not** a director decision, all planned for H3: `pressure.attack_rate_scale` 1.0 -> **1.1**; new `pressure.telegraph_scale` **0.85** on non-boss telegraphs; volley windup 0.9 -> **0.75**.
- **[Director decision, D22 = C]** Relics (GDD §4a, BUILD_DEPTH §4.1). In his words: a relic-hunting player can reach about 6-8 relics per run, hard cap 10. Sources: a merchant (buy several at once with gold), a dedicated relic stage, and elites. Old plan (BD0 default A): elite relic choice, rest room heal-or-relic, 1 in 4 reward screens, about 3-4 per run.
  - Game-lead interim, not a director decision: BD2 adds one relic room to the straight run (about 2 per run until the map exists). Rest and reward relics are dropped pending the new question D30.
- **[Director decision, D24 = A]** Relics get their own slice BD2, after BD1 and before 3d.
- **[Director decision, D25 = A]** Burn and Bleed don't stack in the base game. Stacking comes only from relics, keystone cards and potential passive-tree nodes (he added the passive nodes).
- **[Director decision, D26 = A]** Fixed menu keys (Enter, arrows, class-pick 1/2) may be named on screen. Gameplay keys still come from the bindings.
- **[Director decision, D28 = A]** The MAP0 design doc comes first, then the first map build after BD2 and before 3d.

#### Docs and process
- New slice H3 (dodge return) is next, then MAP0, PL3, BD1, BD2, the map build, 3d and BD3. PL3 item 6 (Fan of regrets lanes) moved into H3.
- BUILD_DEPTH §8 was rewritten for the dodge-on case: one pure escape card per deck is now a recommendation.
- New director question D30 added to OPEN_ITEMS.
- Answered items moved from OPEN_ITEMS to `docs/RESOLVED.md`.

### Slice BD0: build-depth design doc

Docs only: no code, no tag. Commit range 81fb65e..0ddd630. Everything here is [PROPOSED]; the director has not approved it. The director's own directives for BD0 were recorded earlier (ab00c50).

#### Added
- `docs/BUILD_DEPTH.md` (game-lead doc, 6784049): why cards are interchangeable today; measurable checks (removal pain, run fingerprint spread, archetype parity, no-card runs at most 25%), which need a plan-aware bot; a synergy framework (derived tags, Primer/Payoff/Keystone keywords, effect conditions, primed buffs, stacking statuses); relics (sources, data format, a new `CombatEvents` relay because there is no event bus today, 15 sketches including the burn explosion "Pyre Insurance", map-node hooks); 4 Fire archetypes per class with a keystone and a full legal deck; readability; Movement with the dodge off; slices BD1, BD2, BD3; sources; 3 questions.
- Open questions for the director in `docs/OPEN_ITEMS.md`, each with default A: D22 (relic sources and count), D24 (relics in their own BD2 slice before 3d), D25 (Burn/Bleed stacking in the base game). BD0 ran on D29's default A (the dodge stays off) because D29 was unanswered. An optional research digest is offered. (0ddd630)

#### Changed
- GDD §4a "Mechanics [PROPOSED]" now holds a summary of BUILD_DEPTH; §14 item 12 points at D22/D25. (3b10461)
- ROADMAP: the BD1 brief was rewritten from BUILD_DEPTH; BD2 (relics) and BD3 were added. Run order after BD0: MAP0, PL3 (rest), BD1, BD2, first map build, 3d, BD3. (50cc867)

#### Docs and process
- `docs/DECISIONS.md` "2026-11-02 - BD0" logs game-lead's defaults. `CLAUDE.md` lists BUILD_DEPTH.md as a game-lead doc. (db20d6b)
- README docs table lists `docs/BUILD_DEPTH.md`.

### Slice H2: dodge-off trial

Commit range d88bf9e..ebde769 (gameplay-dev 120bfef..dacc680; ux e155c3e, ff3ef4f). qa review: PASS (`docs/reviews/2026-11-02-h2-qa.md`, 4aa7141). Playtester (short): no blocker (`docs/playtests/2026-11-02-h2-short.md`, ebde769). Decisions: `docs/DECISIONS.md` "2026-11-02 - H2".

**Outcome, plainly:** the dodge is off in the shipped data and the game is much harder without it. The bots' numbers are pessimistic (they press cards at random and never escape on purpose). Nothing was retuned to compensate. The director decides whether the dodge stays off.

#### Added
- `dodge.enabled` in `data/player.json` (shipped false; a missing value reads as false). While off, the dodge never fires, charges freeze, and the HUD dodge row is hidden. Code: `PlayerConfig.dodge_enabled()` / `set_dodge_enabled`, `Player.get_dodge_state()["enabled"]`, `DodgePips` visibility.
- To restore the dodge: set `dodge.enabled` to true and give `dodge` a non-clashing key in `data/input_bindings.json` (it is `[]` now; for example G). With the dodge on and no key, startup logs an error (`InputLabels.find_missing_required`).
- Tests: `tests/unit/h2_test.gd`, `tests/unit/h2_qa_test.gd`, helper `tests/support/dodge_switch.gd` (`DodgeSwitch.enable()` binds the dodge to F9 for tests). Suite 1197 -> **1220**, 103 -> 105 suites.

#### Changed
- **[Director decision, dodge-off trial]** Keys (old -> new): Movement `slot_4` 2 -> **Space** (swap Shift+2 -> Shift+Space); Utility `slot_3` 1 -> **F** (swap Shift+1 -> Shift+F); dodge Space -> unbound. The card strip now reads Q E F Space R.
- **[Director decision, D20 = B]** Wizard max HP 26 -> **22** (`data/characters.json`).
- Game over screen: a 0.4 s arm delay (reuses `run_ui.prompt_option_arm_delay`), Space is swallowed, and the hint "Enter or Space" -> "Enter".
- The binding validator now allows an action bound to an empty list.
- Sim baselines moved: arena seed 1, 30 s `state_hash` 2816045921 -> **2591372848**; 90 s 3667433295 -> **4009010406**. With the dodge on, the arena hashes equal H1's. Bot sim `-Rooms 20 -Seed 3` checksum 2281795515 is unchanged.

#### Trial result (bots, 16 seeds, 10-room runs)
- Standard-deck clears, dodge on -> off: Rogue 16/16 -> 3/16; kiting Wizard 16/16 -> 8/16; non-kiting Wizard 16/16 -> 7/16.
- Wizard at 22 HP alone, dodge on: kiting Wizard 15/16.
- No-card runs clear 0/16 in every column, and now die in room 1.

#### Fixed
- `tests/unit/w1a_test.gd` waits are bounded in physics ticks (flake fix). (4aa7141)

### Earlier on 2026-11-02 (H1, K1 and the director's decisions)


### Slice H1: enemy pressure pass

Commit range 36d7315..98595d4. qa review: PASS (`docs/reviews/2026-11-02-h1-qa.md`, 42cdb13). Playtester (short): no blocker (`docs/playtests/2026-11-02-h1-short.md`, a8123b5). Decisions: `docs/DECISIONS.md` "2026-11-02 - H1".

**Outcome, plainly:** the gates were met (standard runs still clear; Rogue boss time 66.1 s), but the goal was missed in the director's hands. A Wizard with no cards still looked winnable at enemy speed x1.25, only slower. The follow-up is H2, the dodge-off trial (below).

#### Added
- `pressure` block in `data/enemies.json` with two shared knobs, `speed_scale` and `attack_rate_scale`. Each is validated to 0.25-4.0 and unknown keys are rejected (`EnemyConfig.validate_pressure`). Applied in `Enemy._apply_stats`: move speed is multiplied by `speed_scale`, attack cooldown is divided by `attack_rate_scale`. The boss is not scaled; its adds are. The future difficulty tiers reuse these knobs. (0c834a0)
- Tests: `tests/unit/h1_qa_test.gd` (elites, boss adds, boss unscaled, validation edges), knob tests in `tests/unit/enemy_config_test.gd`, and updates to `enemy_stats_5d_test.gd` and `slice5d_qa_test.gd`. Suite 1190 -> **1197**. (0c834a0, 4e72dda, 42cdb13)

#### Changed
- **[Director decision, 2026-11-02] Slightly raise all enemy movement speed, then attack speed only if needed.** Balance (old -> new): `pressure.speed_scale` 1.0 -> 1.25, so chaser 4.0 -> 5.0, shooter 3.0 -> 3.75, golem 2.0 -> 2.5. The boss is unscaled (2.6 / 3.0 / 3.4). `attack_rate_scale` stays 1.0: at 1.25 or more it dropped the Rogue's standard clear rate from 100% to 50-62% and still did not touch the kiting Wizard. (4e72dda)
- Sim baselines moved: arena seed 1, 30 s `state_hash` 2484586390 -> **2816045921**; 90 s 3255493562 -> **3667433295**. Bot sim `-Rooms 20 -Seed 3` checksum 2281795515 is unchanged. (4e72dda)
- `tools/wave_sim.gd` `-LightHeavyOnly` now presses no card slot at all (it used to skip only slots 1 and 2, which left Ward, blinks and heals in play). RNG draws are unchanged. (e4f4cbe)

### Director decisions on his OPEN_ITEMS pass (2026-11-02)

Verbatim in `docs/playtests/2026-11-02-director-open-items-pass.md`, recorded in 3befb9d; answers archived in `docs/RESOLVED.md`.

#### Changed
- **[Director decision, D19 = A, GDD section 3]** A dodge in the post-dash ghost window may pass through enemies. The "dodge does not go through enemies" rule keeps this one exception.
- **[Director decision, D20 = B, GDD section 5]** Wizard HP 26 -> 22 ("a player realistically shouldn't be hit by a full volley, only partial"). Decided now, built in H2.
- **[Director decision, D21 = B]** Housekeeping before H2 (done, see Docs and process below).
- **[Director decision, D23 = A, GDD section 9]** Every current card is `starter`. Reward and merchant offers flag a loadout-plan card you don't own. Built in 3d.
- **[Director decision, dodge-off trial]** The dodge is removed behind a data switch (code kept, easy to bring back). Movement moves 2 -> Space, Utility 1 -> F. Decided now, built in H2.
- **[Director decision, call 16]** Reward and removal screens drop their number keys; mouse, arrows and Enter remain. Built in PL3 (not yet built; the screens still have number keys today).
- **[Director decision]** A branching map is wanted soon (GDD section 9). When to build it is open as D28.
- **[Director decision]** Rest heal of 30% is kept (it may be removed later). Resistance floors confirmed, to stay similar to armor. No-card runs shouldn't be easy to complete, regardless of duration.
- D27 (enemy attack speed) was not answered directly. game-lead read it as A: speed x1.25, attack rate unchanged (`docs/DECISIONS.md`).

#### Docs and process
- **[Director decision]** `docs/OPEN_ITEMS.md` holds only active items. Resolved, received and acknowledged items move to `docs/RESOLVED.md`, owned by tech-writer (`CLAUDE.md`). New file `docs/RESOLVED.md` created with the history up to 3befb9d.
- Housekeeping (D21): `docs/.gdignore` so Godot stops importing playtest PNGs (642d546); missing `.uid` files tracked (c3f5ac1); `.gitattributes` extended: `text=auto`, LF for text types, binaries marked (98595d4). No renormalisation commit was needed; the index was already LF.
- README: removed 4 stray CR bytes that made git treat it as binary (they had turned `tools\run_*.ps1` into `toolsun_*.ps1` in the "Last verification" list), updated the test count, hashes and `-LightHeavyOnly` description, and added notes on LF and `docs/.gdignore`. ARCHITECTURE: added the pressure knobs and the `-LightHeavyOnly` fix.

### Slice K1: key labels follow the bindings

Commit range a848395..2c0d185. qa review: PASS (`docs/reviews/2026-11-02-k1-qa.md`). Playtester smoke: PASS (`docs/playtests/2026-11-02-k1-short.md`).

#### Added
- `src/core/InputLabels.gd`, a static helper that turns the live bindings into UI text: "Q", "Shift+Q", "LMB", or "?" for an unbound action. Slot helpers (`slot_name`, `slot_key`, `slot_label`, `slot_swap_key`, and `_at(i)` variants) take names from `data/slot_types.json`, so Recovery shows as "Recovery (R)". Physical keycodes are shown as the player's keyboard layout names them. (04ac813, 7f4b136)
- `InputBindings.bindings_changed` signal and `InputBindings.last_conflicts`. No new autoload. (04ac813)
- A binding validator, `InputLabels.find_conflicts`: two actions with the same key plus modifiers (or the same mouse button) are reported by `InputBindings.load_bindings` with `push_error` at startup. It does not quit the game. Plain R and Shift+R are not a conflict. (04ac813)
- `HudLayout.key_label_width`, so longer key labels (for example "Shift+Q") fit their label slot. (6204f2a)
- Tests: `tests/unit/input_labels_test.gd`, `k1_ux_test.gd`, `k1_qa_test.gd`, and `k1_key_hint_scan_test.gd`, which fails if a hardcoded slot, mouse or modifier key hint appears in `src/` or `data/`. The suite is now 1190 of 1190 (was 1156); qa's reload soak is OK and the arena hashes are unchanged (2484586390 for 30 s seed 1, 3255493562 for 90 s). (04ac813, 6204f2a, 8752a1c)
- Captures `docs/playtests/img/k1-*.png` (HUD strip, reward, removal grid, pause) and `k1-pt-*.png` (playtest). (81abc85, 2c0d185)

#### Changed
- **[Director decision, GDD section 3] Key labels follow `data/input_bindings.json`; no UI text may hardcode a key.** Recorded 2026-11-02 and built here. The HUD slot keys, the LMB and RMB meters and the dodge label are read from InputLabels and refresh on `bindings_changed`. (04ac813, 6204f2a)
- **[Director decision, GDD section 3] The Recovery slot moved from 3 to R.** `slot_5`: 3 -> R. `dead_card_swap_5`: Shift+3 -> Shift+R. Default slot keys are now Q, E, 1, 2, R (were Q, E, 1, 2, 3). (04ac813)
- **[Director decision, GDD section 3] Duplicate key plus modifier bindings fail loudly at startup** (see the validator above).
- UI text values (old -> new):
  - `data/ui.json` `dodge_label`: "Space" -> removed; the label comes from InputLabels.
  - `data/ui.json` pause hint: "Esc also resumes" -> template "%s also resumes" (now reads "Escape also resumes").
  - `data/run.json` option `slot_now`: "Slot %d now: %s" -> "%s now: %s" (for example "Recovery (R) now: ...").
  - `data/run.json` option `slot_key`: "Slot %d" -> "Key %s".
  - `data/run.json` option `slot_label`: new, "%s (%s)".
  - `data/run.json` option `remove_list_hint`: "Keys 1-%d jump to that slot column, Enter confirms" -> "Keys 1-%d jump to a column, Enter confirms" (menu digits are positional and are allowed by the scan test). (6204f2a)

#### Fixed
- **Slot and swap keys leaked through an open reward prompt.** `RunPromptScreen` did not stop Q, E, R (and Shift plus them) from reaching the Player, so a card could cast behind the reward screen. It now swallows press and release of every slot and swap action (`RunPromptScreen.swallows_slot_action`, via `event.is_action`). (6204f2a)

#### Docs and process
- The 2026-11-02 decision entry below says K1 is "not built yet", and the 2026-11-01 entry says the UI shows 1-5 "until K1"; both were true when written and are now superseded by this slice.
- Replaced the notes saying the UI "still shows 1-5 until K1" in `README.md` and `docs/ARCHITECTURE.md`; the K1 rules are now in ARCHITECTURE section 4 (HUD and UI).
- No new commands and no new third-party assets.

### Director decisions of 2026-10-31 to 2026-11-02 (no code)

Recorded by game-lead in 0e2e60c and fe1bf72 from the director's notes of 2026-10-31 to 2026-11-02. Design lives in `docs/GDD.md`; these are decisions, not builds.

### Docs and process
- **[Director decision, 2026-11-02] Run order after W1b: K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d.** Reason: cards and decks do not yet change how a run plays, and that comes before more screens, art or staging. game-lead's one reorder suggestion (move the PL3 housekeeping earlier) is D21, open; the default is the director's order. (`docs/ROADMAP.md`)
- **[Director decision, 2026-11-02] Build depth and synergy are the top pillar-1 priority (new GDD section 4a).** A player should be able to enter runs with very different plans on the same class and element, and removing a card the plan depends on should hurt. Relics and enchants reset every run. The dead-card swap stays as is until synergies give a card a reason to be saved.
- **[Director decision, 2026-11-02] A no-card run should not be able to win.** The director won a 10-room Wizard run with no cards and no healing in 5:25 on 2026-10-31 (`docs/playtests/2026-10-31-director-wizard-no-cards.md`). One future exception: a deliberate build that invests in light and heavy attacks through relics and passives.
- **[Director decision, 2026-11-02] Pressure pass (slice H1):** an explicit exception to "do not retune the base game until the tiers exist". First raise all enemy movement speed slightly; if that is not enough, raise attack rate. It sits behind two shared data knobs (an enemy speed scale and an attack-rate scale). Player stats, card numbers and boss mechanics are not changed. No numbers are changed yet.
- game-lead's default for H1 (a judgment call in `docs/DECISIONS.md`, not a director directive): telegraphs never shorter than 0.45 s; boss attacks keep their 0.6 s minimum.
- **[Director decision, 2026-11-02] Key labels follow the bindings (slice K1).** Whatever is in `data/input_bindings.json` is what the UI shows; no UI text may hardcode a key; two actions with the same key and modifiers must fail loudly at startup. K1 also moves Recovery (slot 5) from 3 to R. Not built yet.
- **[Director decision, 2026-11-02] Loadouts and passives:** at least 5 named loadouts per class (a data value), card availability flags (default under D23: every existing card is `starter`), and an empty versioned `passive_allocation` field on each loadout. Passive allocations are linked to loadouts, and respeccing is free between runs. Scheduled with the loadout screen in 3d, the last slice in the run order; nothing built.
- Open decisions for the director are D19, D20, D21 and D23; D22, D24 and D25 are reserved for BD0's questions (`docs/OPEN_ITEMS.md`).

## 2026-11-01

### Fixed
- The three failing assertions in `tests/unit/cast_input_6a_test.gd` (see the known side effect below) are fixed. Test-only change by qa: the tests now read slot keys from the InputMap instead of hardcoding `KEY_1`/`KEY_2`, three tests were renamed, and `tests/unit/slice6_qa_test.gd` was hardened the same way. The suite is green again at 1156 of 1156 (98 suites) and arena hash 2484586390 is unchanged. (0119999)

### Changed
- **[Director decision] Card slot keys are Q, E, 1, 2, 3** (slots 1 to 5 in order), and the dead-card swap is Shift plus the same key. Old: 1-5 and Shift+1-5. The director changed `data/input_bindings.json` himself after Luke's playtest, whose only suggestion was friendlier keys (`docs/playtests/2026-11-01-luke-keybinds.md`). The HUD slot hints and the "Slot N" text on reward screens still show 1-5 until K1. (24530e4)
- **Known side effect:** the keybind change broke three assertions in `tests/unit/cast_input_6a_test.gd` (two test cases), which send `KEY_1` and `KEY_2` and expect slots 1 and 2. The full suite is 1156 cases with 3 failures at fe1bf72 (it was green at qa's W1b review). Found in the W1b docs pass. Fixed in 0119999; the suite was red between 24530e4 and 0119999.

## 2026-10-30 (Slice W1b: Wizard content and balance; Slice P-dodge: dodge charges, boss stagger, dodge pips; Slice F1: director feedback batch; Slice PL2: small polish; Slice W1a: a playable Fire Wizard; decisions for F1, P-dodge and W1b)

### Slice W1b: Wizard content and balance

Commits aaa933a..ecec528, game-lead doc commits excluded. Content aaa933a; tooling 8b1778a, 45ed585; tuning 2128ae4, 0754483; ux 245d8e3; qa d531102 and review 6f26ff9 (PASS, `docs/reviews/2026-10-30-w1b-qa.md`, suite 1156 of 1156); playtest d74e0df (`docs/playtests/2026-10-30-w1b-wizard-cards.md`, smoke PASS, no blocker).

#### Added
- **Four Wizard cards in the `wizard` pool (now 8 cards), all data, no new template.** Three Bolts, Reluctantly (`wizard_bolt_volley`, Attack: Single, a 3-hit projectile), Overqualified Bolt (`wizard_overqualified_bolt`, Attack: Single), Personal Space, Enforced (`wizard_arcane_nova`, Attack: AoE with knockback) and Ward, Technically (`wizard_ward`, Utility, a `buff` of additive armor). They deal `neutral` damage, so armor applies. (aaa933a)
- **Ward, Technically is the first player armor source.** It is in the pool but not in the starter. Its duration is kept below its own cycle so two copies cannot give permanent armor. (aaa933a, 2128ae4)
- **A caster starter for the Wizard** (still 15 cards, 3 per slot). Out: Pointy Stick, Ember Whatever, Shrug Bomb, Blaze and Bail. In: Three Bolts, Overqualified Bolt, Personal Space, Tactical Hover. About 58% of reward offers are now duplicates, against 86% before (gameplay-dev, 12 seeds). (aaa933a)
- **Three Wizard debug presets** with a `"class": "wizard"` key: `fire-heavy-wizard`, `arcane-heavy-wizard`, `mixed-wizard` (`--list-decks` shows six presets now). (aaa933a)
- **Wave sim flags** `-WizardNoKite` (a non-kiting Wizard bot policy), `-DodgePellets` (the bot dodges projectiles in flight; off by default) and `-BossLog` (per boss attack: thrown, hits, HP cost; needs `-Run`). (8b1778a)
- **`wall_crossing` scenario:** walking enemies cross a Fire Wall, to check the Wall buff by eye (the F1 playtest could not). No automated check. (8b1778a)
- **`Health.last_source_id`:** the instance id of the last damage source, used only as sim telemetry (a test pins it). (8b1778a, 45ed585)
- qa tests: a live Ward path test, an invariant that an armor buff survives a recast, and a volley invariant over every class. (d531102)

#### Changed
- **Card text:** an additive armor stat reads "+25 armor" in `CardSummary`. (aaa933a)
- **Balance, Wizard tuning (2128ae4), old -> new:**
  - Wizard max HP 26 -> 22, then 22 -> 26 again in 0754483, so the net change from before W1b is none (see below).
  - Wizard auto light 2.4 -> 1.5 damage per hit (about 50% of the Rogue's light DPS; it was about 80%, a W1a test pin rather than a GDD rule).
  - Wizard heavy 8.5 -> 5.5.
  - Three Bolts, Reluctantly damage per hit 2.5 -> 2.2; Overqualified Bolt 12 -> 10.5; Personal Space, Enforced 11 -> 10.5. (These three cards were new in aaa933a; the old values are their first values.)
  - Ward, Technically duration 6 s -> 4 s (its cycle is 5 s).
  - Card cooldown modifiers and enemy data did not change. Exact values: `data/attacks.json`, `data/cards/wizard_*.json`.
- **Wizard max HP 22 -> 26 (0754483).** One full "Fan of regrets" boss volley is 5 pellets x 5 = 25 physical damage, and the player has no armor. At 26 HP a volley cannot kill from full HP. A test pins "max HP above one full volley" for every class from data. The Wizard's HP is therefore the same as before W1b, which does not match the GDD line that the Wizard should be "squishier". That conflict is **D20**, open with the director (`docs/OPEN_ITEMS.md`); it is a one-value change in `data/characters.json` (the test then has to be relaxed or the volley changed).
- **Sim findings that shaped the tuning (gameplay-dev and qa, pellet-dodging bot, 12 seeds):** the bot used to never dodge pellets, so about two thirds of the Wizard's "boss cliff" was a sim artefact. After tuning, the Wizard's boss fight takes about 103% of the Rogue's time when kiting and about 72% when walking in; every run was won and rooms cost HP, less than the Rogue's. qa's 24-seed re-run puts the non-kiting boss time at 70.7-73.1%, on the 70% floor (N1, accepted for now). A pellet-blind kiting bot died in 3 of 12 runs on seeds 13-24 (two volleys, not one-shots); with pellet dodging, 0 of 48 died (N2). Playtest, 72 runs on seeds 31-42: no Wizard deaths, non-kiting boss at about 77%.
- **STAGGERED banner vs boss bar (ux 5e, 245d8e3), checked, no fix needed:** there was no real overlap. The playtest overlap was a world-space damage number over the boss's head. The stagger capture now uses a normal-sized hit so the shot is representative. Damage numbers drawing over the boss bar when the boss stands under it stay in the backlog.

#### Fixed
- qa: the `w1a` bolt auto-fire tests were flaky under load; they now poll on real time (up to 4 s). (d531102)

#### Docs and process
- Open after W1b: the Ward cast has no visible cue, the new bolt cards look alike, the boss smash knockback is long, and volley damage numbers are hard to read. They go to a new polish slice PL3, not a W1b reopen (ecec528). The Wizard's auto bolt stays at 50% until the director has played it.
- Generated files (`*.uid`, `docs/playtests/img/*.import`) are untracked; housekeeping goes to PL3.

### Slice P-dodge: dodge charges, boss stagger, dodge pips

Commits fd49ca5..60d86fd, game-lead doc commits excluded. Gameplay 0209de4, 96bae8c, 3d74345, a8d0b71, 1fdca8a, 4986db4, 6243785, bc976ca; ux 8566b9e, 74a972c; qa review 14eadd1 (PASS, `docs/reviews/2026-10-30-p-dodge-qa.md`); short playtest 60d86fd (`docs/playtests/2026-10-30-p-dodge-short.md`, smoke PASS, no blocker).

#### Added
- **[Director decision, 2026-10-29] Dodge charges.** New `src/player/DodgeCharges.gd` (pure logic). Each dodge spends a charge; charges come back one at a time. `data/player.json` `dodge` has new required keys `charges` 3, `min_charges` 0, `max_charges` 4. The count is clamped to that range after `StatModifiers`. A lowered maximum clamps the current count at once and `Player.dodge_charges_changed` fires. (96bae8c, 1fdca8a)
- **[Director decision, 2026-10-30] Per-class dodge counts:** Rogue 3, Wizard 2, through the new optional `characters.json` key `dodge_charges`. (96bae8c)
- **[Director decision, D16 = B] The boss staggers at each phase threshold.** New `bosses.json` `transition.stagger` (optional, default 0.8 s, 0 = off). The stagger drops the boss's current attack, comes before the roar, and adds a `STAGGER` state plus `stagger_started` / `stagger_ended` signals on `Boss`. Player damage counts during it: the HP floor drops to the next threshold, so one hit cannot pass two thresholds. The stagger into the last phase keeps a 1 HP floor, so the boss cannot die in it. (3d74345, bc976ca)
- **Dodge pips on the HUD** (`src/ui/DodgePips.gd`, `dodge_*` keys in `data/ui.json` `hud`): under the LMB and RMB meters, a "Space" label and one pip per charge, a recharge fill, and an EMPTY state (word plus red frame at 0 charges, NO DODGE at a maximum of 0). (8566b9e)
- **Boss bar stagger cue:** a STAGGERED label, the phase line reads "Hit it now", and the phase notch counts as crossed from the stagger start. "Invulnerable" shows only in the roar. (8566b9e)
- `tools/UxCapture.tscn` + `tools/ux_capture.gd`: HUD state captures, `-- --size=WxH --class= --mode=pips|pips_recharge|pips_empty|stagger --out=`; needs a renderer. (74a972c)
- Tests: 1102 -> 1147. New: `tests/unit/p_dodge_test.gd`, `p_dodge_boss_test.gd`, `p_dodge_ux_test.gd`, `tests/support/boss_stagger.gd`. (96bae8c, 3d74345, 8566b9e)

#### Changed
- **[Director decision, 2026-10-29] Dodge cooldown is now a per-charge recharge:** `data/player.json` `dodge.cooldown` 0.8 -> 1.2 s per charge. (96bae8c)
- **[Director decision, D13 = B] Recovery base cooldown** 8 -> 12 s (`data/slot_types.json`). (96bae8c)
- **[Director decision] Wizard's Recovery is slightly longer:** 14 s (game-lead's number), through the new optional `characters.json` key `slot_base_cooldowns`. (96bae8c)
- `rules.max_transition` 1.5 -> 2.0 s in `data/bosses.json`, so the 0.8 s stagger plus the 1.2 s roar fit. The validator rejects a total over the cap. Not a director decision (gameplay-dev call, accepted by game-lead). (3d74345)
- Wave sim bot dodges whenever a charge is ready, throttled to the roll length (it was one dodge per 0.9 s). (6243785)
- Arena hash baselines changed (seed 1). 30 s: 3513335656 -> 1867641457 (Recovery 12 s) -> 2484586390 (charge-aware bot). 90 s: 2081798188 -> 3255493562. (96bae8c, 6243785)

#### Fixed
- Upward launch when a pass-through move ends concentric with an enemy: `Enemy.clearing_offset` plus a horizontal nudge out of the body. A stale "Ctrl" comment was fixed too. (96bae8c, 1fdca8a)
- The reload soak "damage immunity leaked" flake was a wrong assumption in the soak, not a game bug: a rest room is immune by design while its choice is open, and Try again picks a random seed, so about 1 in 7 landed on a rest room. The soak now expects immunity in rest rooms only and prints the room type and seed on failure. 8 of 8 soak runs clean in qa (before: about 1 in 5 failed). (0209de4)
- The soak waits for the boss roar by state, not frame count. (a8d0b71)

#### Docs and process
- qa baseline for W1b (10 rooms, seeds 1-12, charge-aware bot): Rogue 12 of 12 won, boss fight mean 64.3 s (47.8 to 81.3). Wizard (kiting bot) 11 of 12 won, boss fight mean 55.0 s; its one loss died in the boss room (the "boss cliff" for W1b). Do not read charge balance from the 60 s arena sim: the bot's dodge use is a behaviour artefact.
- The playtester committed 7 capture PNGs in `docs/playtests/img/` (our own captures, no third-party license). (60d86fd)
- Not verified by qa: the roar frame of the boss bar visually (unit test only) and interactive play at a window.
- README and `docs/ARCHITECTURE.md` updated: test count, dodge and boss data keys, hashes, UxCapture, dodge controls, DodgeCharges, boss stagger, DodgePips. No new third-party assets, so `docs/ASSETS.md` is unchanged.

### Slice F1: director feedback batch

Commits 937a388..4904390. Gameplay efb0516, cef82c5; ux a1504cc; qa review c4c93ff, f305fae (PASS, `docs/reviews/2026-10-30-f1-qa.md`); short playtest 027d65a (`docs/playtests/2026-10-30-f1-short.md`, no blocker).

#### Added
- **[Director decision] Movement cards pass through enemies while they move.** New optional `dash` template param `pass_through` (bool, `src/combat/EffectTemplates.gd`). Set on the six movement dash cards: `fire_blaze_and_bail`, `neutral_backward_leap`, `rogue_lunge_strike`, `rogue_ugh_fine_moving`, `wizard_sideways_blink`, `wizard_tactical_hover`. Shadow Step (a buff) is unchanged. The dodge still does not pass through. `Player.start_forced_move` takes a new `pass_through` argument; the grant lasts exactly the move. A dash that ends inside a body reuses Shadow Step's restore (ghosted for up to 3 s until clear). Reluctant Lunge on 3 enemies in a line: damage [8, 0, 0] -> [8, 8, 8], travel 0.73 m -> 3.0 m. (efb0516)
- `ghost_show_delay` in `data/vfx.json` (0.35 s): the ghost look shows only after pass-through has lasted that long, so short dashes do not flicker. (a1504cc)
- Tests: 1082 -> 1102. New: `tests/unit/f1_movement_test.gd`, `tests/unit/f1_qa_test.gd`. (efb0516, c4c93ff)

#### Changed
- **[Director decision] Wall of Mild Fire is bigger** (`data/cards/fire_wall.json`): length 5.0 -> 7.5 m, width 1.2 -> 1.8 m. The preview and burn-down follow. (efb0516, cef82c5)
- **[Director decision] Dead-card swap key:** Ctrl+1-5 -> Shift+1-5 (`data/input_bindings.json`). Shift+N only swaps; Ctrl+N does nothing. (efb0516)
- **[Director decision] Runs are 10 rooms, not 8** (`data/run.json`): composition 5 combat / 1 elite / 1 rest / 1 boss -> 7 / 1 / 1 / 1. Placement ranges: elite [3, 6] -> [3, 8], rest [2, 6] -> [2, 8]. The boss is room 10 (`--run-room=10`). "of 10" strings, fixtures and comments updated. (efb0516, a1504cc)
- Boss spawn box `screen_up` 2.2 -> 1.5 (`data/bosses.json`) so the boss's head clears the HUD at 1024x600. Not a director decision. The fallback sweep is finer: `BOSS_SWEEP_ANGLES` 72, tried at three distances (`src/enemies/EnemySpawner.gd`). (efb0516)
- Arena sim hash baselines changed. The Wall change caused it (bisected). 30 s seed 1: 2792856473 -> 3513335656. 90 s seed 1: 4120250839 -> 2081798188. (efb0516)

#### Fixed
- The focus ring on reward cards is no longer clipped by the scroll area (`RunOptionCard.focus_ring_width` helper). (a1504cc)

#### Docs and process
- Open item: D19 (should the dodge work during the post-dash ghost window?) waits on the director. As built, the dodge passes through enemies in that window. A launch quirk was routed to P-dodge. (eb8b3ad)
- README: run length, `--run-room=10`, swap key, test count, arena hashes, and two `tools\run_...` paths that had lost a backslash (a literal carriage return) are fixed.

### Slice PL2: small polish before W1b

Commits 351840f..fab00a7. Gameplay 6a2c573, c29aa9d, 5079a2a, 3b8359e; ux ad77847, cb2be67; qa review b7ba7fe, delta re-review PASS 8a99ce4 (`docs/reviews/2026-10-30-pl2-qa.md`, FAIL on a Wizard node leak, then PASS); playtest 4dd2eaa, no blocker (`docs/playtests/2026-10-30-pl2-polish.md`). Tests 1053 -> 1082.

#### Added
- **[Director decision] Card frame colours by family (D17).** `frame_color` on every pool in `data/pools.json` (fire `#ff6a1f`, Rogue and Wizard class pools `#d9b48a` light bronze, neutral `#9a9a9a` grey), validated on load. Accessor `PoolDatabase.frame_color_for_card(card_id)` / `frame_color_for_pool(pool_id)`. Frames are drawn on `CardSlotWidget` (active card frame and next-up swatch), `RunOptionCard` reward offers and rest-room removal cells; the reject tile keeps its own border. (3b8359e, ad77847)
- **Rogue melee reach cue:** new `src/ui/MeleeReachCue.gd` and a `melee_cue` block in `data/ui.json`. A faint pale-blue arc at light-attack reach, shown only when nothing is in reach, brighter on a whiffed click. It keys on the light attack's `arc` shape, so the Wizard never shows it. (ad77847, leak fix cb2be67)
- New tests: `pool_frame_color_test.gd`, `boss_spawn_pl2_test.gd`, `projectile_first_hit_test.gd`, `pl2_ux_test.gd`, `pl2_qa_test.gd`; fixture `tests/fixtures/pools_noframe/`.

#### Changed
- **Boss spawns fully on screen in room 8.** New optional `spawn` block on `boss_guardian` in `data/bosses.json` (`distance_min` 7, `distance_max` 9, `screen_half_width` 9, `screen_up` 2.2, `screen_down` 3.6), used by `EnemySpawner._boss_spawn_position`. Old: a plain ring 9 to 13 m from the player. A test pins the box to `scenes/camera/CameraRig.tscn`. (6a2c573, 5079a2a)
- **Slot ready cue moved off the border** to the plate and text brightness. Removed `slot_ready_border_color` and `slot_ready_border_width`; new keys `slot_frame_width`, `slot_frame_keyline_*`, `slot_plate_ready_color`, `slot_plate_cooling_color`, `slot_next_swatch_width`, `option_frame_width`, `option_card_focus_color`. (ad77847)
- **HUD slot strip 8 px taller:** `hud.slot_size` [150, 118] -> [150, 126], `key_height` 20 -> 24, `preview_height` 34 -> 38. (ad77847)
- The class pick screen now hides the HUD behind it (it showed the previous class's HUD). (ad77847)
- Scenario `character` now also sets the body look, so `wizard_bolt` shows a purple Wizard. (3b8359e)
- `SlotStateCapture` rewritten: `godot --path . res://tools/SlotStateCapture.tscn -- 1280 720 <out.png>`. (ad77847)

#### Fixed
- A projectile can no longer damage two hurtboxes in the same physics step (all projectiles; `_spent` guard). (c29aa9d)
- A bad `--class` or `--deck` now prints only "Launch refused: ..." on stderr and exits 2, with no stack trace. (3b8359e)
- Wizard node leak in `MeleeReachCue` (qa B1): the band is created only when the cue is armed. (cb2be67)

#### Docs and process
- qa measured a Rogue boss baseline over 12 seeds: mean 66.7 s (range 49.7 to 75.6). Recorded for the later difficulty work.
- Removed junk `scratch_suite.txt`. (3b8359e)
- **[Director decision] Run order changed to PL2 -> F1 -> P-dodge -> W1b -> 3d** (game-lead call). Director decisions below are recorded but not built yet.
- README fixes: the stack-trace note and the `wizard_bolt` known issue are gone (both fixed), three command paths that had `tools
...` mangled into a carriage return are repaired, the removal-capture example now uses `--run-seed=1 --run-room=5` (seed 1's rest room is room 5; the old `--run-room=3` example without a seed depended on the seed), and `frame_color` and `melee_cue` are documented. ARCHITECTURE gains the frame-colour accessor and data, `MeleeReachCue` and the boss spawn box.
- No new third-party assets, so `docs/ASSETS.md` is unchanged.

### Director decisions recorded, not yet built

All are `[Director decision]`. Each is scheduled in the slice named; none is in the code yet.
- **D18 = A: Wizard rooms cost some HP, less than the Rogue's.** The Wizard is squishier than today's 26 HP (the final value is set when built). Scheduled in P-dodge.
- **Dodge charges:** Wizard 2, Rogue 3. Scheduled in P-dodge.
- **Wizard Recovery slightly longer than the Rogue's.** game-lead set 14 s against the Rogue's 12 s. Scheduled in P-dodge.
- **Wall of Mild Fire x1.5:** length 5 -> 7.5, width 1.2 -> 1.8. Scheduled in F1.
- **Movement cards pass through enemies; the dodge does not.** Old: both are the same. Scheduled in F1.
- **Dead-card swap key:** Ctrl+1-5 -> Shift+1-5. Scheduled in F1. (README controls still say Ctrl until it is built.)
- **Runs are at least 10 rooms:** 8 -> 10 (7 combat, 1 elite, 1 rest, boss). Scheduled in F1.
- **Difficulty tiers:** today's tuning becomes "Easy"; later tiers Normal, Hard and a top tier are planned (names open). Scheduled in W1b.

### Slice W1a: a playable Fire Wizard

Commits 451eaf3..HEAD. Gameplay 0c9704e and 39fe0c6; ux 7d93d1c, 82bce4e and 672622f; qa PASS b799153 (1053 of 1053; `docs/reviews/2026-10-30-w1a-qa.md`); playtest b5f2e02, no blocker (`docs/playtests/2026-10-30-w1a-wizard.md`). Judgment calls are in `docs/DECISIONS.md` under 2026-10-30 ("W1a gameplay build", "W1a ux"); the W1 split is under 2026-10-29.

#### Added
- **[Director decision] A second playable class, the Fire Wizard** (GDD section 5, "Wizard moved earlier"). New `data/characters.json` (read by `CharacterDatabase`): per class id, name, description, pools, starting deck, max HP and body colour. (0c9704e)
- **Wizard stats:** 26 HP (Rogue 30), purple body. Light attack: an auto-firing bolt, 2.4 neutral damage every 0.6 s = 4.0 DPS (80% of the Rogue's 5.0), range 12 m, speed 24 m/s, drawn cyan `#3fd9ff` via `attacks.json` `light_variants.wizard.bolt_look`. Heavy (`heavy.wizard`): a 2.0 m disc at up to 7 m, damage type physical -> neutral. (0c9704e, 7d93d1c)
- **Four Wizard cards** (pool `wizard`): Borrowed Focus, Footwork Allegedly, Sideways Blink, Tactical Hover. The Wizard starter is 15 cards; `--full-deck` gives 18 cards for the Wizard (24 for the Rogue). (0c9704e)
- **Class pick screen** (`ClassPickScreen`, `ClassPickCard`): opens on every run, including Try again and New run, and pauses the room behind it. 1/2 or the arrows highlight, Enter or a click confirms, Space is ignored during the arm delay, and the last pick is preselected. It is skipped when `--class` or `--deck` is given, headless, and in the arena. The last pick is remembered in `user://last_class.json` in windowed play only (`CharacterPick`). New `ui.json` blocks: `class_pick`, and `hud.meter_windup_words` / `hud.meter_ready_word`. (82bce4e)
- **The heavy meter says CAST for a targeted heavy (Wizard) and SWING for the Rogue's arc**, from data. (672622f)
- **Launch options** `--class=rogue|wizard` and `--show-class-pick` (forces the screen, for captures). Presets may carry `"class"`, and `--deck` alone sets the class. A `--class`/`--deck` mismatch, a bare `--class`, `--class` twice or an unknown class exits 2 with "Launch refused: ...". (0c9704e, 82bce4e)
- **Tools:** `run_wave_sim.ps1 -Class wizard` (whole runs, with `-Run`) and `run_reload_cycle.ps1 -Class wizard`; a `-Deck`/`-Class` clash is refused. (0c9704e, 39fe0c6)
- **Scenario** `wizard_bolt` and the new scenario key `character`. Known issue: the scenario body stays Rogue-coloured. (672622f)
- The projectile effect template gains the code-only params `direction`, `lane` and `look`. (0c9704e, 7d93d1c)

#### Changed
- **`starting_deck` and `character_pools` moved from `data/run.json` to `data/characters.json`** (per class). The Rogue's starter is unchanged. (0c9704e)
- **`RunState` saves a `character`;** a save without it loads as the Rogue. (0c9704e)
- `Player.owned_pools` is no longer a fixed export default: it is filled from the character unless a test or capture sets its own. (0c9704e)
- Captures should always pass `--class`, because the last pick persists in windowed play.

#### Docs and process
- **Process:** W1a's docs pass followed the per-slice rule (game-lead runs tech-writer once at the end of each slice, as in `CLAUDE.md`; the rule dates from 2026-10-28). *Correction (PL2 docs pass): this rule dates from 2026-10-28, not from W1a; W1a only followed it. Correction (W1b docs pass): the bullet is reworded; it used to say the docs pass "now happens per slice", which read as if W1a introduced it.*
- Docs pass for W1a: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- README: fixed two mangled command paths (`tools\run_wave_sim.ps1` and `tools\run_tests.ps1` in the examples and "Last verification" had a stray carriage return).
- Test count 996 -> 1053 across W1a (qa's figure; this pass re-ran it, see README).

## 2026-10-29 (Slice T-decks debug preset decks; Slice A1 armor; Milestone 3c boss encounter; Milestone 3b rewards and deck-clean; Milestone 3a run structure; content slice C1: deck rules, nine Fire Rogue cards, solid enemies, status cues)

### Slice T-decks: debug preset decks

Commits e7b0029..HEAD; build 9b6e8a6. qa passed (deb6ff1; `docs/reviews/2026-10-29-t-decks-qa.md`): 987 tests on HEAD plus 9 qa tests in `tests/unit/t_decks_qa_test.gd`.

#### Added
- **[Director decision] Debug preset decks for launches.** Named decks in `data/debug_decks/<name>.json` (`name` equals the file name, `description`, `full`, `starter` a sub-multiset of `full`). Adding a preset is one file, no code. Both lists must pass the deck rules; there is no bypass. Shipped: `fire-heavy-rogue`, `physical-rogue` (has 2 Fire cards, the minimum the rules allow) and `mixed-rogue`. New `src/run/DebugDecks.gd` and `RunSession.debug_deck`. (9b6e8a6)
- **Launch options** `--deck=<name>` (the preset's `starter`), `--deck=<name> --full-deck` (its `full` list) and `--list-decks` (prints names and descriptions, exits 0; exits 2 if a preset file is broken). The preset applies to the whole launch, so Try again keeps it. `--deck` is ignored with `--scenario` and in the arena. An unknown name, `--deck` twice, a bare `--deck` or an invalid preset exits 2 with "Launch refused: ...". (9b6e8a6)
- **Wave sim `-LightHeavyOnly`:** a bot policy that never presses card slots 1 and 2, so only light and heavy attacks hit. Not a deck; the random stream is unchanged. (9b6e8a6)
- README: a "Launch options" table listing every launch option with an example.

#### Changed
- **Wave sim `-Deck` now takes a preset name or `standard`** (passed to the game as `--sim-deck=`). Old: `standard|fire|physical|lightheavy`, test families that fixed the two attack slots. New: real, legal preset decks. A preset is only the starting deck; rewards change it during the run. (9b6e8a6)
- **`RunSession.skip_deck_minimums` is removed.** Nothing can start a run below the deck minimums any more. (9b6e8a6)

#### Docs and process
- 12-seed boss-fight result, `-Run -God`, median as a multiple of the standard deck: fire-heavy 1.02x, physical 1.07x, both inside the director's 70 to 130% band, so no retune. The A1 numbers (fire 0.93x, physical 1.04x) were seed noise. Details in `docs/DECISIONS.md`, "T-decks qa PASS". (43b7e35)
- Known: the reload soak (`tools/reload_cycle.gd`, "damage immunity leaked into a new room") flaked 2 of 3 under load before T-decks; it is assigned to P-dodge. Re-run once and note it until then.
- Docs pass for T-decks: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.

### Slice A1: armor

Commits b23d7df..HEAD. Director decision b6f85bd (GDD section 7, "Armor"). Gameplay b23d7df..e141dfe; ux 1604f6b..bcf13a5; readability fix f0cb109. qa passed at 965 of 965 (9292e4b; `docs/reviews/2026-10-29-a1-armor-qa.md`), and the readability fix at 966 of 966 plus 2 qa tests (70a761f; `docs/reviews/2026-10-29-a1-uxfix-qa.md`). Playtest found no blocker (ff6e7f6; `docs/playtests/2026-10-29-a1-armor.md`).

#### Added
- **[Director decision] Armor, a non-elemental mitigation channel** (GDD section 7). Physical and neutral damage is reduced by armor: reduction = armor / (armor + K), K 50, capped at 50%. Elemental damage still goes through resistance, and armor never touches it. Before A1, physical was skipped by a hardcoded check, so the boss took 0% from physical and 50% from fire. Settings are in the new `data/armor.json`, read by `ArmorConfig`; which damage types count as non-elemental is data (`non_elemental_types`). (735bda7, b6f85bd)
- **`Health.take_damage` is the single choke point** for both channels. Penetration is flat, read from the attacker's `armor_penetration` stat through `StatModifiers`. The player has armor 0 for now. Bleed ticks go through armor, Burn ticks through resistance, heals are untouched. (735bda7)
- **Armor values (new):** elite tier 17, `tiers.boss` 27 (unused by the real boss), `boss_guardian` 50 (`data/run.json`, `data/bosses.json`). Armor and resistance of one tier must give reductions within 2 points; checked at load and by tests. (735bda7)
- **Boss bar:** a shield pip and "Armor N% - Resists ..." text next to the resistance line. (1604f6b)
- **Elite bars:** a shield pip left of the resistance diamond; size is `hp_bars.pip_scale` in `data/ui.json`. (62463d8, f0cb109)
- **Damage numbers:** an armor-reduced hit shows `[9]` in muted grey at 85% size; a resisted hit shows `<4>`. The style appears only above a minimum reduction (`armor_min_reduction`, `resist_min_reduction`). Values under 1 show one decimal, never "0". (f67c317)
- **F3 overlay "Defense" block:** armor and resistance of the enemy under the cursor (else the nearest), plus the player's armor. (4d22904)
- **Scenarios** `boss_f3`, `elite_f3`, `armor_numbers` (new key `elite_indices`) for captures. (4d22904)
- **Wave sim `-Deck <standard|fire|physical|lightheavy>`:** fixed test decks for armor comparisons. The decks are not legal (a tool-only flag skips the run-start minimums). (62fa964)
  - Correction (T-decks docs pass): this wording is out of date. In T-decks (9b6e8a6) `-Deck` became a preset name or `standard`, the `fire`/`physical`/`lightheavy` families and the minimums skip (`skip_deck_minimums`) were removed, and the decks are legal.

#### Changed
- **Balance (re-tune to keep fight length, whole-run sim, 16 seeds):** elite `hp_multiplier` 2.5 -> 2.0; boss `max_health` 280 -> 195. Armor alone had stretched the median elite room from 41.9 s to 56.9 s and the boss fight from 63.7 s to 85.9 s; after the re-tune they are 40.6 s and 63.4 s. (e141dfe)
- **`tiers.boss.resistance_floor` 0.25 -> 0.35**, so its armor 27 passes the parity check and matches GDD section 7's 35% for bosses. (735bda7)
- **Boss bar width 480 -> 560 px** (`boss_bar_size` is now 560 x 104). At 1024x768 the bar fits and the blocks stack. (1604f6b, f0cb109)
- **Boss "all elements" text** is judged against the game's element list, not only the listed keys. (f0cb109)
- Deck families against the standard deck, real HP (bot, god mode, 8 seeds): fire 0.93x, physical 1.04x boss fight time (before armor: 1.08x and 0.85x), both inside the director's 70 to 130% band. Details in `docs/DECISIONS.md`.

#### Fixed
- A `BossHpBar` error when the boss is freed while the bar is binding (seen in long light/heavy-only runs; also present on the 3c tag). (1604f6b)

#### Docs and process
- Docs pass for A1: README, ARCHITECTURE (new "Armor and mitigation" part, `armor.json`, sharp edges) and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- Test count 907 -> 968 across A1.
- Known and logged: a light and heavy only bot is about 3.2x slower on the boss (was 3.5x); game-lead judged it a bot limit, not a director question. `armor_reduction(INF)` returns NaN (not reachable from data).


### Milestone 3c: the boss encounter, and the reward-screen scroll fix

Commits a35501d..8bc7241 (a35501d is the gameplay follow-up commit; gameplay a35501d..2234dc8; ux b8af93f..5245779; fix pass 741c624..b7a6a01). qa passed 3c at 903 of 903 tests (64df947; `docs/reviews/2026-10-29-m3c-qa.md`) and the fix pass at 907 (8bc7241). Playtest found no blocker (81b03d8; `docs/playtests/2026-10-29-m3c-boss.md`).

#### Added
- **A real boss: "The Overly Enthusiastic Guardian" (placeholder name, per DECISIONS)** replaces the 3a placeholder (a golem with HP x7). Everything is data in `data/bosses.json`, read by `BossConfig` (validator) and `BossRules` (pure rules); the brain is `src/enemies/Boss.gd` on `scenes/enemies/BossGuardian.tscn`. The boss is 280 HP, resists every element by 50% (GDD section 7, final boss), cannot be stunned, and takes no knockback. (31fa26e, a5303c2, 72b7985)
- **Four telegraphed attacks:** smash (cone), slam (disc on where you stood), volley (5 shot lanes), charge (a lane). Wind-ups run 0.77 to 1.1 s; the data floor is `rules.min_telegraph` 0.6 s, and a test (not load-time validation) checks every attack can be escaped by walking or by the dodge. (31fa26e)
- **Three phases** at 66% and 33% of HP: faster, a shorter gap between attacks, more attacks (charge from phase 2). Each change is a 1.2 s invulnerable roar. Phase 2 summons 2 chasers and phase 3 summons 2 shooters, at most 3 adds alive; the boss kills its adds when it dies. `Health.hp_floor` holds each threshold, so one big hit cannot skip a phase or kill the boss before its last one. (31fa26e)
- **Pinning rule:** the boss is not solid to the player or other enemies while it charges, and turns solid again only once it no longer overlaps the player, so a charge cannot trap you against a wall. (31fa26e)
- **Death beat:** 1.6 s of slow-motion and a burst with the player immune, then the win screen. The beat counts game time when hit-stop is off, so seeded sims still repeat exactly. (31fa26e, 2234dc8)
- **Template params** (optional, used by the boss): projectile `yaw_degrees` (turns the shot about the vertical axis, a fan) and aoe `vfx: false` (skip the template's own impact visual). (31fa26e)
- **`RunController.boss_spawned(boss)` and `current_boss()`** (the boss bar does not use them; it finds the boss by class). (a5303c2)
- **Boss HP bar (ux),** top centre while a boss lives: name, fill with ghost trail, a notch and line at each phase threshold, "Phase N of 3: name", a striped "Invulnerable" look during the roar, the resistance line, and the current attack's label with a draining wind-up strip. It finds the boss by class, so it also works in scenarios. New: `BossHpBar`, `BossMeter`, `BossAttackStrip`, `HudLayout.boss_bar_rect` and `debug_overlay_top`. (b8af93f)
- **Debug scenarios `boss`, `boss_edge`, `boss_phase3`** (9999 HP for both sides) for captures. The boss room itself: `-Scenario "" -Extra "--run-seed=1","--run-room=8"`. (a5303c2, b8af93f)
- **Sim tooling:** the run-mode bot leaves wind-up areas and dodges, and `run_wave_sim.ps1 -Run` prints a `boss fight (spawn to death)` line per run. The reload soak covers the boss fight, a phase transition and the death beat. (a5303c2, 72b7985)
- Test count 826 -> 907 across 3c and its fix pass.

#### Changed
- **Room indicator moved from top centre to top right** to make room for the boss bar; the F3 overlay now sits under the boss bar block (`HudLayout.debug_overlay_top`). (b8af93f)
- **Boss telegraphs are bolder:** lane alpha 0.3 -> 0.5 for boss lanes (`boss_lane_alpha` in `data/vfx.json`), the slam gets an inner ring, and cone outlines and aoe rings draw over bodies. Sizes are unchanged. (b8af93f, b7a6a01)
- **Boss attack label font 15 -> 22 px** (`boss_bar.attack_font_size`), attack row 22 -> 30 px, bar block 96 -> 104 px (`boss_bar_size`). (b7a6a01)
- **Boss pacing** (bot, seeds 1-8, 15-card starter): fight 52 to 67 s, mean 61 s (about 80 s with the placeholder); the bot won 8 of 8. HP tuned 520 -> 280. (72b7985)
- **The boss spawns with no tier,** so `tiers.boss` in `data/run.json` (HP x7) is now unused; qa logged removing it for 3d. (31fa26e)
- **3b follow-ups (ux):**
  - Offers list the slot's cards: "Slot N now: A / B / C" (separator is " / " because card names contain commas; first version used ", "). (5245779, 5a85712)
  - Effect lines carry units, from data (status numbers come from `statuses.json`).
  - Reject tile width 188 -> 216 px (`option_reject_width`) so "Reject" fits on one line.
  - Locked removal reads "Get another card for the Utility slot first (minimum 3 different)" on both the tile and the grid (`ui.rest.remove_locked`).
  - Continue and New run now ignore input for the arm delay (0.4 s), Space no longer confirms them, and the hints say Enter.
  - The reward panel sits below the HUD band, clear of the HP label.
- **`RunState.from_dict` rejects a bad `pending` value** (closes the 3b qa note; it now drops an unknown value and logs an error). The choice model gained `owned`, `next_room_type` and per-option `slot_contents`. (a35501d)

#### Fixed
- **[Director decision] Reward selection scrolled and clipped** in windows near or under 720p. Cause: the container around the panel reset the panel's fit scale to 1 every time it sorted its children, undoing the shrink-to-fit. The scale is now re-applied after every sort. Offers never scroll (tests from 1024x600 to 2560x1440, including a live window resize); only the removal grid scrolls. New `run_ui.offer_min_fit_scale` 0.45 (the removal grid keeps `option_min_fit_scale` 0.8); panel padding 28 -> 22 px (`prompt_panel_padding`). (741c624, qa 8bc7241)

#### Docs and process
- **[Director decision] Planned, not built: dodge charges** (GDD section 3; scheduled as slice P-dodge after the 3c close). The dodge gets charges, 3 to start (maybe 2; a data value), each recharging on a slightly longer cooldown than the old single dodge, with a HUD indicator. Passives may raise or lower the baseline (for example fewer charges for a tankier build); level-ups must never change it. Hard limits 0 to 4 after all modifiers. Today the dodge is still a single dodge with one cooldown (`data/player.json`). (bef7a8c, 467383d)
- Docs pass for 3c: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- Known and logged (not fixed): the Game Over screen still accepts Space and says "Enter or Space"; the boss body can cover the resist text; a doubled cooldown in some buff lines; player card visuals are drawn against the 0.45 m enemy radius so they understate reach on the boss's larger body (safe direction, accepted). qa's save-robustness findings go to 3d.

### Milestone 3b: reward screen and deck-clean

Commits fd2f644..d2cd00a (gameplay fd2f644..b8564cd; ux 56a76f0..d2cd00a). qa passed it at 826 of 826 tests (0a19808; review in `docs/reviews/2026-10-29-m3b-qa.md`). Playtest found no blocker (f2a3283; `docs/playtests/2026-10-29-m3b-rewards.md`).

#### Added
- **Card rewards.** After each won combat or elite room (never the boss or the last room) you get 3 card offers (`rewards.offer_size` in `data/run.json`). Pick one, or reject the whole offer. [Director decision] (GDD section 9): pick 1 of 3 or reject all, with 3 rejects per run (`rejects_per_run`). At 0 rejects you must pick. (fd2f644)
- **Seeded, pool-limited offers.** The offer comes from the run seed, the room index and the current deck, on its own RNG stream. Candidates are only cards in the character's pools. Cards you do not own weigh 4 and owned ones 1 (`unowned_weight`, `owned_weight`), so duplicates are possible but rarer. The offer shrinks if fewer cards qualify. (fd2f644)
- **Optional card field `requires`** (`slot_types`, `pools`, `status_sources`): a card is only offered when the deck and character meet it. No shipped card uses it yet. Checked by `CardSchema`. (fd2f644)
- **Rest room is now a choice:** Heal (30% of max HP, `rest_heal_fraction`) or Remove a card, then a card list with Back. Removal goes through the deck rules (`can_remove`): a card whose removal would drop a slot below its minimum is greyed out with the reason, and the remove tile is disabled when nothing can go. (fd2f644)
- **Reusable choice model.** `RunChoices` turns the run state into a list of options and resolves one; `RunController` gained `choice_requested`, `choice_resolved` and `choose()`. The same model can serve a later level-up screen. (fd2f644)
- **Choice screen (ux).** Reward cards show a number badge, name, slot pill, effect line, flavor and "You own N". The reject tile is narrower and darker, with pips for rejects left. Rest has two action tiles. The removal list is a per-slot grid that scrolls; keys 1-5 jump to a slot column. Keys 1-N highlight, Enter or a click confirms. Effect lines are built from effect params by `CardSummary.effect_line`, with wording in `data/run.json` `ui.effect`. (56a76f0, d2cd00a)
- **"Next: Room N of 8 - Type"** line on the choice screen (`ui.next_line`). (d2cd00a)
- **Save format v2.** `RunState` gained `pending`, `offer` and `choice_log`. A reload mid-reward reopens the same offer without replaying the room; a v1 state still loads. (fd2f644)
- **Debug args:** `--full-deck` (all 24 cards for the whole launch, including Try again) and `--run-auto-choose=<option ids>` (picks those options in turn, skipping the arm delay; for captures). (fd2f644, d2cd00a)
- **Bot sim plays the choices.** `run_wave_sim.ps1 -Run` picks, rejects and removes with a seeded policy and prints HP at each room end, the final deck size and per-slot composition, picks, rejects used, removals and rest heals, plus the mean room-end HP share per room. The reload soak also covers a reload mid-reward and Try again from a reward state. (82bf5d9, 9043866)
- 60 more test cases: 766 at the end of 3a, 826 at the qa pass, including 17 adversarial qa tests (removal fuzz over 300 decks, offers, rejects, real key input, a `force` audit). (689f2fd, 0a19808)

#### Changed
- **Starter deck 24 -> 15 cards:** the full rogue + fire + neutral pool (7 + 5 + 3 + 5 + 4) is now 3 cards per slot (`starting_deck` in `data/run.json`). Reason: with the full pool every reward was a duplicate and every removal was blocked. `--full-deck` restores all 24. Consequence: with exactly 3 unique per slot, no starter card can be removed until a pick adds a duplicate or a 4th card in that slot, so early rest rooms are mostly heal. (fd2f644)
- **Rest text:** a rest at full HP no longer says "Healed +0"; the heal tile reads "HP is already full". (fd2f644)
- **Rest room no longer ends at once:** it opens the heal-or-remove menu and the next room loads when you choose. (fd2f644)
- **Input safety on the choice screen:** options ignore input for 0.4 s after the panel opens (`run_ui.prompt_option_arm_delay` in `data/ui.json`), because the player is usually still mashing keys after a fight. Number keys only move the highlight. Presses are ignored while paused. (b8564cd)
- **`RunController.continue_to_next_room(force)`:** while a choice is open it does nothing; `force = true` (tests and debug only) discards the choice. Only `choose()` ends a choice in play. (fd2f644)
- **Game-lead calls** (not director decisions, logged in `docs/DECISIONS.md`): reject gives no card (no reroll); 4:1 weights; boss rooms are not reward rooms (`reward_room_types`); offers regenerate from the seed, a reload resumes the saved offer.

#### Fixed
- **Space confirmed the focused option** on the choice screen (it is also dodge); it is now swallowed while options are open. Focus returns to the highlighted option after a pause. (d2cd00a)
- **Buff cards showed raw ids** in the effect line; they now read like "Attack: Single cooldown -0.5 s for 6 s", with wording from data. (56a76f0)

#### Docs and process
- Docs pass for 3b: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- **Correction to the 3a entry below and the 3a README:** the wave sim does not fail on card pick-rate outliers; it prints them as a NOTE (`wave_sim.gd`, `_print_pick_rates`). The README and ARCHITECTURE are corrected.
- Known and logged by qa (not fixed): an unknown `RunState.pending` string would load as a choice with no options (not reachable until real saves exist); a few effect lines read oddly ("dash 6.5"); the 1440p reward panel slightly overlaps the dimmed HP label; the Continue / New run button has no arm delay.

### Milestone 3a: run structure

Commits a7731e2..013e7d7. qa passed it at 766 of 766 tests (a6a5d68; review in `docs/reviews/2026-10-29-m3a-qa.md`). Playtest found no blocker (013e7d7; `docs/playtests/2026-10-29-m3a-run-structure.md`).

#### Added
- **A normal launch is now a run.** The project's main scene is `scenes/main/RunMain.tscn`: 8 rooms in a straight line (5 combat, 1 elite, 1 rest, boss last), built from a seed. The elite lands in rooms 4-7 and the rest in rooms 3-7, and the first room is always combat. `scenes/main/Main.tscn` stays the endless arena for tests, scenarios, the wave sim and VpCapture. A `--scenario` launch keeps the arena. (a7731e2)
- **Run state across rooms.** `RunState` holds seed, room index, HP, deck card ids, rejects (3 per run), and room history; it serializes to JSON. Each room is a fresh scene, so cooldowns, the shuffle bag, zones, statuses and timers reset per room while HP and the deck carry over. A room won makes the player damage-immune until Continue, so a shot still in the air can't kill a winner. (a7731e2)
- **Run data in `data/run.json`:** room composition and placement rules, rest heal fraction, rejects per run, the starting deck (the whole current pool), elite and boss tiers, finite wave lists per room type, and the UI wording. The wave schema gained `finite` (the table ends instead of looping) and a per-spawn `tier`. (a7731e2)
- **Elites and a placeholder boss.** Elite: HP x2.5. Boss: HP x7, cannot be stunned (3c replaces this boss). Both: resistance becomes the larger of the enemy's own and 25%, capped at 50%. A flat diamond (elite) or star (boss) sign floats above the HP bar. The shape carries the rank, and the body is not bigger. (a7731e2, 8b54b25, c560d83)
- **Rest room.** Heals 30% of max HP and ends at once. (a7731e2)
- **Run UI (ux).** A "Room X of Y - Type" indicator at the top centre with a shape per type: circle combat, diamond elite, plus rest, star boss. A "Room cleared" panel with Continue shows HP and time ("Healed +N" on a rest room). A win screen shows rooms cleared, total time and HP left, with New run. The panel is generic (`show_content`, `options_box`), so the 3b reward screen can reuse it. (0f4e317)
- **Game Over in a run** adds "Reached room X of Y." Try again and New run both start a new seed. (0f4e317)
- **Launch args:** `--run-seed=N` (first run only), `--run-room=K` (1-based), `--run-clear-after=S`. (f47ae2e, f00ee65)
- **Tooling:** `run_wave_sim.ps1 -Run` plays whole seeded runs and checks for soft locks (`-RoomTimeout`), an empty deck, a stuck cooldown, and card pick-rate outliers; it reports lowest HP per room and the room-type distribution over 1000 seeds. `capture_screenshot.ps1` gained `-Extra` (comma list of game args), `-Scenario ""` to capture the normal run, and `-TrueSize` with `-Scenario ""` hosts RunMain in VpCapture. The reload soak also covers run mode. (f47ae2e, f00ee65, c560d83)
- 70 more test cases: 696 at the end of C1, 766 at the qa pass. (a7731e2..a6a5d68)

#### Changed
- **Elite and boss body scale** is 1.0 in `data/run.json` (the marker is the cue; hit shapes keep their data size). (c560d83)
- **Game-lead calls** (not director decisions, logged in `docs/DECISIONS.md`): linear rooms, 8 rooms, rest heals 30%, elite resistance is the larger of own and 25% (cap 50%).
- **Run stats on Game Over (D1)** were deferred "until the run structure"; a minimal one-line version shipped: "Reached room X of Y." (0f4e317)

#### Fixed
- **qa N5:** `Main` and `GameOverScreen` no longer depend on `current_scene`, so scene transitions work inside VpCapture.
- **Flaky `slice6_qa_test` crowd test:** tolerance 1e-6 -> 0.01 m. The drift (about 1e-4 m) comes from physics-engine sensitivity to allocation history, not from non-deterministic game code. (a6a5d68)

#### Docs and process
- Docs pass for 3a: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.

### Content slice C1

Slice C1 ran 2026-10-28 to 2026-10-29 (commits 2a985e4..d94676a; C1-a, C1-b1 and C1-t were built on 10-28). qa passed it at 696 of 696 tests (76bca75). The tooling task (true-size capture, seeded sims, dodge values in data) is listed under 2026-10-28.

### Added
- **Deck rules (C1-a).** `data/deck_rules.json` sets how many different cards each slot needs: 3 by default, with optional per-slot overrides and named slot groups with a combined minimum. A checker (`DeckRules`, `DeckCheck`) counts unique cards. Copies never count twice ([Director decision] D10: duplicates are allowed). Removing or swapping a card is refused when it would drop a slot below its minimum (`can_remove`, `can_swap`). The F3 overlay shows each slot's count and shortfalls. The director's example (attack group 10, utility 5, movement 3, recovery 3 = a 21-card minimum) exists only as a test fixture. (2a985e4, 73c8e72)
- **A run with a short deck is blocked (C1-c).** At run start, a deck that misses the minimums logs an error, switches the spawner off and emits `Main.run_start_blocked`. In C1-a it only warned, because the shipped deck was short. The shipped deck now passes. (22c8321)
- **New generic card abilities (C1-b1, C1-b2), all driven by data:**
  - `apply_status` can have a `chance`, and `hits`/`hit_interval`; cone, aoe and projectile can repeat `hits` times, `hit_interval` apart. (4236e5a)
  - Three statuses: **Bleed** (damage over time), **Regeneration** (heal over time) and **Leech** (lifesteal: a share of the damage you deal comes back as HP, with a per-hit cap). A `damage_dealt` event feeds Leech. (4236e5a, 87dbb87)
  - New `zone` template: a circle or line on the ground that ticks damage and an optional status chance for a set time. `data/zones.json` caps live zones (`max_live`) and holds the look. (b60fbe6)
  - New `pass_through` template: for a time, the player walks through enemy bodies. (114a1b3)
  - Dash gets `direction_mode` (`forward` or `away_from_aim`) and optional path damage (each enemy hit once). (114a1b3)
  - aoe gets `max_range` (placed at the aim point, clamped) and `delay` (the centre locks at cast and the telegraph grows). (114a1b3, 22c8321)
  - Placed skills draw a range reticle, with its look in data. (114a1b3, 3079dc7)
- **Nine new cards (C1-c; names and flavor by story in C1-d).** The preset Fire Rogue deck is now the whole rogue + fire + neutral pool. Slots hold attack_single 7, attack_aoe 5, utility 3, movement 5 and recovery 4 cards. Numbers live in `data/cards/`. (22c8321, 1b35908)
  - Slash, Then Bleed (single): a direct hit plus Bleed.
  - Four Quick Stabs (single): four small hits in a row.
  - Fireball, Incoming (aoe): aimed, delayed, with Burn.
  - Wall of Mild Fire (aoe): a line zone that burns whoever stands in it.
  - Walk Through Everyone (movement): pass through enemies for a few seconds. [Director decision] D9: Stealth is pass-through only for now; dropping enemy aggro comes later.
  - Reluctant Lunge (movement): a short dash that damages the first enemy it meets and stops there.
  - Nope, Leaping Away (movement, neutral pool): a long dash away from the aim, not invulnerable.
  - Heal By Hurting (recovery, neutral pool): Leech.
  - Eventual Healing (recovery, neutral pool): Regeneration.
- **Status and skill cues (C1-e).** Bleed shows a droplet pip on the enemy HP bar (alternating with the Burn pip); Regeneration a green ring; Leech a ring and a drain bead on hits. Heals on the player show "+N" numbers, batched every 0.25 s. Shadow Step makes the player see-through with a pale ring (a ghost). The Fire Wall has a burn-down timer bar that empties as the zone ends and blinks near the end. Dashes preview with arrowheads. Placed skills show a range ring and a marker where the aim lands (a diamond with a link line when clamped to max range). The F3 overlay is styled. A new `PlayerCues` node, attached from Main, holds the player cues. [Director decision] D11: the neutral cards use the neutral palette. (31fece2, 3079dc7, 353070f)
- **New capture scenarios:** `c1_status`, `c1_status_crowd`, `c1_placed`, `c1_placed_near`, `c1_moves`, `c1_names`, `c1_overlay` (see the README). (3079dc7)
- **Test helpers and sim lines:** `tests/support/body_flag.gd`, `test_caster.gd` and `test_clock.gd`; the wave sim prints pinned-frame and max-feet-height lines. (de9f916, 87ede1f)

### Changed
- **[Director decision] D8 = C: dodge speed 28 -> 20** (distance 7.0 m -> 5.0 m; the 0.25 s duration and i-frames are unchanged). It is one number in `data/player.json`. The code fallbacks were aligned to 20 too. History: 3.5 m intended, about 7.1 m in practice (slide bug), 3.5 m after S6-2, 7.0 m under the D8 default, now 5.0 m. (73c8e72, 4b1820a)
- **Enemies are now solid bodies.** `data/player.json` `body.collide_with_enemies` is true; before, player and enemy bodies effectively never collided. Neither body can ride the other, and enemies spawn in place. This is game-lead's call, not a director decision (logged in `docs/DECISIONS.md`, kept on pending the playtest). In the seeded sim (seeds 1/2/3, 150 s) HP lost about doubled: 49/47/41 with the flag off and the new cards, 86/91/83 with it on. The bot never uses Shadow Step on purpose, so this overstates the cost for a human. Set the flag to false to restore the old behaviour. (fcc72af, de9f916)
- **Hit-stop and screen shake now fire only on direct hits.** Before, every damage event did, including Burn ticks. Burn, Bleed, zone ticks and follow-up hits now show the number and flash only. A multi-hit dash hit-stops once per enemy. (4236e5a, 114a1b3)
- **Status tuning:** Regeneration `heal_per_tick` 1.0 -> 2.0 (14 HP over 7 s). Leech `fraction` 0.3 -> 0.4 and `max_heal_per_hit` 2.0 -> 3.0. Bleed unchanged. (22c8321)
- **A one-card slot's "next" preview** now shows that card instead of being blank (side effect of the shuffle fix). (741816c)
- **Card name rows** use `fit_padding` 12 (was 2) and line spacing 0, so a two-line name fits. (16eecd9)

### Fixed
- **Shuffle bag.** The old shuffle ran while the last-drawn card was still in hand, so that card was missing from the next cycle (a 3-card deck could cycle c1, c1, c2). The bag now refills from all owned copies, and the first card of a new bag is never the card just drawn (when another unique card exists). (741816c)
- **Game Over beat was too short** (869 of 900 ms under slow-mo). It is now counted from `Time.get_ticks_usec()`, with paused time excluded. (4b1820a)
- **Card name rows clipped their second line** (found on "Walk Through Everyone"). A test now pins every card name at 720p, 1080p and 1440p. (16eecd9)
- **Lifesteal no longer heals at full HP,** and counts HP actually removed (no overkill). (87dbb87)
- **A player standing at the arena origin was popped onto a spawning enemy.** Enemies now spawn in place, and a Shadow Step that ends inside an enemy restores collision only once the player is clear (3 s cap). (de9f916)
- **Flaky tests (C1-t):** the pause and crowd-determinism tests used timers that Godot overcounts after a hit-stop (a 0.1 s timer fired after 76 ms) and unisolated hit-stop. They now wait with `TestClock.wait_real`; 597 of 597 passed in 3 of 3 runs. (da1115a)
- **Reload soak** now places a Fire Wall and a pass-through grant, reloads with the buff live, and checks the static pass-through flag and mask. The attack_meter and slice4 node-growth tests were hardened. (76bca75)

### Docs and process
- **C1-t test gate repair (qa).** Flaky tests were fixed before more content landed. (da1115a)
- **qa C1-f PASS** (76bca75, 696 of 696): review in `docs/reviews/2026-10-29-c1f-qa.md`. Known gap: the Lunge preview shows the full 3 m path even when a body will stop it short.
- **Playtest C1-g / Polish 1 close-out** (d94676a): `docs/playtests/2026-10-29-c1-and-polish1-closeout.md`.
- **[Director decision] D12:** the order of work was the tooling task, then C1, then the end-of-pass playtest.
- game-lead housekeeping (fe3c785): `docs/OPEN_ITEMS.md` restructured; `.claude/settings.local.json` added to `.gitignore`.
- **Docs pass C1-h** also covers the tooling task: README, ARCHITECTURE and this file updated. There are no new third-party assets, so `docs/ASSETS.md` got no new entries.

## 2026-10-28 (Polish 1: Slice 6 fix pass, Slice 5 waves and readability, Slice 4 skill visuals, Slice 3b attack rework, director open items)

### Added
- **Tooling task: true-size capture.** `capture_screenshot.ps1 -TrueSize WxH` runs the real game inside a SubViewport of exactly that size (`tools/VpCapture.tscn`), so 1920x1080 and 2560x1440 captures are no longer clamped to the monitor. A new `WorldRef` helper tells effects, popups and screens where the arena is when `current_scene` is null. Normal play and tests are unchanged. (c4a3747; qa PASS b5a796a, 552 of 552 tests)
- **Tooling task: seeded sims repeat exactly.** The same `-Seed` now gives the same wave-sim and bot-sim result on the same machine and build. This closes qa finding S6-4. Fixes: card shuffles, the player's status RNG and the camera-shake RNG are seeded, the sims run at a fixed 60 fps (`--fixed-fps 60`), hit-stop is off in the wave sim, and buff ids use a counter. `run_bot_sim.ps1` gained `-Seed` and prints a checksum. (3402446)
- **Dodge values are data.** New `data/player.json` holds dodge speed, duration, cooldown and the post-pause block ticks, read and checked by `PlayerConfig`. (3e9e02a)

- **Pause and settings screen (Slice 6b).** Esc pauses and opens a small screen with one toggle, "Cast cards on: Release (preview) / Press", which saves at once. It never opens over Game Over. The cast preview now uses the player's element colour, draws over the enemies it targets, and dims while the card is cooling down. When enemies hide the player, a pale silhouette shows through them. (9ff60d8, 98ee2ea, 2f44346, 567cdc4)
- **[Director decision] D7 applied:** enemy HP bars now show only on damaged enemies; elites and bosses always show theirs. Before, every bar was always visible. (efaf164)
- **Hold-to-preview casting (Slice 6a, director D2 = C).** Holding a card key shows its exact hit area on the ground (cone, area, projectile lane, dash path, or a small ring for self cards). The area follows your aim, and the card casts when you let go. A `cast_trigger` setting (`release` or `press`) switches back to casting on press. Settings now have a store (defaults in `data/settings.json`, your choices in `user://settings.cfg`), and the game can pause without breaking hit-stop or the death slow-mo. Attack and card keys are now read through input events, so an open screen can block them. (aecde4f, d2463f0, 7bfdb6f, 29656c2, 4f5220e)
- **Enemies spread out (5d).** Enemies steer away from each other, so chasers surround the player instead of stacking in one column. In the seeded sim, the share of frames where nearby chasers are readably apart went from about 33-48% to about 80-96% (depending on seed). Spacing values are data. Enemy combat stats (speed, damage, wind-up, cooldown, ranges) moved from scene files into `data/enemies.json`, with values unchanged. The training dummy no longer appears in normal runs. (6db688d, 13435db, 5e6ea32)
- **Staged enemy waves (Slice 5a).** Up to 12 enemies at once, arriving in four stages. Each stage opens after a delay and only while few enough enemies are alive. The wave table is data in `data/waves.json`. Enemies can't attack for their first 1.5 s, and the first wave arrives after 3 s. Before, first contact came about 1 s after spawn. (3af4538, 8e05395)
- **Enemy warnings.** Chasers show a ground wedge during their wind-up, and shooters show a lane strip where the shot will go. Enemy shots and wedges are tinted pink so they look different from the player's (D3, default A). (caab2c0, 079e1f4)
- **Arena walls.** Invisible walls stop the player and enemies falling off the floor edge, a bug found by the new wave simulator tool. (079e1f4)
- **Card-cast test scenario.** A capture scenario casts every card effect type in turn and confirms each slot really goes on cooldown, which is the first live check of slot cooling. Later it gained a fire projectile cast and a spread-out layout with idle enemies, so screenshots read clearly. (42f4599, 30d6d87)
- **Shared effect pool.** Visual effects come from one reusable pool with a cap on how many can show at once. The cap was 48, raised to 64 to leave room for Burn flames. The pool uses simple shapes instead of particles because that is cheapest and runs headless. (57c874f, ba993b4)
- **Element colours as data.** Fire is orange, and the neutral/physical look is cream. Adding Water later is a data entry only, and a test proves it. (993c6c8)
- **Visuals that match hit areas.** Cone, area and projectile visuals take their size from the same data as the hit check, and tests enforce it. (1d87756)
- **Visuals for every card effect.** Projectiles get a muzzle flash, trail and impact, and fizzle at max range. Cones sweep, area attacks charge then burst, dashes leave puffs and a trail, heals sparkle, buffs ring, and Burn puts a lasting flame on the enemy. (ba993b4, 7755fbf)
- **Aim indicator.** A quiet ring follows the mouse on the ground, and fading dots show the direction you face. Player projectiles and dashes leave a brief ground marker of their path. (7d8817e, 6aaa203, 51fc5b0)
- **Enemy data file.** `data/enemies.json` holds enemy shot size and cone angle (values unchanged), and later an enemy rank (normal/elite/boss). Every current enemy is normal. (ad3db20, 7192e13)
- **Data checks for status effects.** A typo in a status such as Burn now raises an error on load instead of silently showing nothing. (b5180a8)
- **Click cap as a ratio.** Spam-clicking the light attack is capped at 1.5x the automatic rate, so the minimum gap is 0.4 s at the current 0.6 s timer. It scales with any future attack-speed boost. (961d7c6)
- **"Cards beat the free attack" rule check.** Every attack card must deal at least 1.5x a light hit per cast and more damage per second than the auto light attack. A check at load and a test fail if a card drifts below. (961d7c6)
- **Heavy attack redesign.** Heavy attacks are defined per class in data, with two shapes: a wide melee arc, and a targeted area at the mouse point for casters. The Rogue heavy stuns on hit and has a 50% chance to Burn for 3 s. The Wizard's targeted area exists only as data plus a test scenario; no Wizard class was built. (7192e13, 5a45938, 89c9634, ee9adbe)
- **Stun status.** Stunned enemies don't move or attack. Repeat stuns within a short window get shorter, then stop working after the third. Elites take half-length stuns and bosses are immune. (7192e13)
- **Stun cue.** Three yellow stars orbit a stunned enemy and its body turns paler. A rate-limited "IMMUNE" popup shows when a stun doesn't land. The targeted-area telegraph now fills in as the wind-up charges. (7d58f95, ad9ee04)
- **More tests.** qa added real-scene tests for Slice 4 and 3b, and the bot simulator is now seeded so its failures can be reproduced. (6f82a4b, 8cc7b92, 552ef04)

### Changed
- **Dodge speed 14 -> 28 (distance 3.5 m -> 7.0 m)** in the tooling task, as the director-question D8 default while it was open. It was changed again on 2026-10-29 (see there). (3e9e02a)
- **Enemy shot lane tip padding.** The pink lane strip an enemy shooter draws now extends by the real reach against the player's capsule, matching its sides (it ended a few cm short). (968e9f0)
- **Feel change (S6-2): dash and dodge now stop at their data distance.** Before, a forced move kept sliding after it ended (friction carried it about twice as far, and the extra depended on frame rate). Now it ends exactly at speed x duration and stops, at any frame rate. Dodge roll: about 7.1 m -> 3.5 m (*correction 2026-10-29: the dodge values were Player exports at the time; they moved to `data/player.json` in the tooling task, see below*). Blaze and Bail dash: about 8.1 m -> 4.0 m. Ugh, Fine, Moving (data distance 4.5 m) uses the same code and shortened too; its old distance was not measured (unverified). Dodge i-frame time and cooldown are unchanged. In qa's seeded wave sim the bot lost about 2.5x more HP after this. The preview and the data distance already said 4.0 m, so the fix moved the player, not the preview. **D8 was open then** (*correction 2026-10-29: the director answered D8 = C; the final dodge is 5.0 m, see the 2026-10-29 entry*). (7b7a471)
- **Balance: golem wind-up** 0.45 s -> 0.7 s (director item D6, default A applied). Its attack cycle goes 2.25 s -> 2.5 s and its damage per second 4.0 -> 3.6. Hit damage is unchanged at 9. (acc26a4)
- **Damage numbers are bigger:** about 12 px -> 20 px at 720p, with an outline. Quick hits on the same spot merge into one number, and at most 16 show at once. **IMMUNE** now draws above HP bars. The cone, heal, dash and projectile trails read more strongly, and their timings are now data. A ring shows when a stun cancels an enemy's wind-up. Enemy HP bar visibility is now one data setting with four modes (shipped as "always" at the time; switched by director call D7 in 6b, see efaf164). (058d3dd, 3ae40b7, 39c03e6, b50aa0c, bff7581)
- **Enemy HP bars** are slightly smaller (1.4 x 0.19 -> 1.2 x 0.16) and hidden behind models in front of them. Before, they drew over everything. (caab2c0, 8e05395)
- **Golem shape.** Its hit area went from a box to a capsule (radius 0.45). Ground markers now show its true hit area; before, they understated it by about 20-30 cm. Its body went from a box to a capsule, and its movement collision is unchanged. (caab2c0)
- **Attack wedge size.** The light and heavy wedges are now drawn to where hits really land, about 0.45 past the old drawn edge. They were later trimmed 4-5 cm to the exact reach at floor height. The projectile path marker's half-width went from 0.75 to 0.60 (so the lane is 1.5 -> 1.2 wide). How attacks hit did not change. (1d87756, 5807412)
- **Light attack and heavy telegraph look.** The light flash went from pale yellow (#ffe27a) to saturated yellow (#ffcf1a) and from 0.12 s to 0.2 s. The heavy wind-up is now a pale pulsing outline, clearly different from the solid impact flash. (0e2646d)
- **Death cue.** Death now flashes white then red, greys and topples the player, with a burst, a ring and a camera shake. (e046cdd, 6583dbf)
- **Arena background.** The pale-blue sky past the floor edge became a dark void. The floor stays 40x40; a trial 60x60 floor was reverted. (888e37b, 7755fbf)
- **[Director decision] Basic attacks.** Clicking is an early-game crutch. Basic attacks are weaker than cards. Heavy trades sustained damage for burst and utility. The heavy wind-up slows and never roots. GDD §3 was updated; this resolves balance questions P1-P4. (5a3b998)
- **Balance: light attack** damage per hit 8 -> 3, which is 13.3 -> 5.0 damage per second. (961d7c6)
- **Balance: Shrug Bomb** 5 -> 12 damage. **Everyone Calm Down** 8 -> 16 damage. Both changes make them beat the new light attack. No other card changed. (961d7c6)
- **Balance: spam-click advantage** 2.4x -> 1.5x the auto rate (minimum click gap 0.25 s -> 0.4 s). (961d7c6)
- **Balance: Rogue heavy** 22 -> 8.5 damage per hit (1.8 s cooldown). Its area is 3x the light attack's. Direct damage per second is 12.2 -> 4.7, about 5.8 with Burn. (7192e13)
- **Balance: heavy wind-up** now slows movement by 35%. Before, it neither slowed nor rooted. (7192e13)
- **Balance: stun** is 0.6 s. The window in which repeat stuns shrink went 4 s -> 1.5 s, so every heavy swing gets the full stun. (7192e13, 8a9c704)
- **Balance: Fine, Burn Then** direct damage 7 -> 12, because after the Burn fix it really did less damage per second than the light attack (3.9 vs 5.0). It is now about 5.6. With the honest Burn count, Ember's credited figure fell from 11.8 to 6.4 DPS; how it actually plays did not change. The Rogue heavy's total with Burn is about 6.0. (9d91d7a)
- **Balance (side effect of a bug fix): projectile hit size** now really reads its data. Flaming Nonsense hits at 0.3 (was 0.25), and ranged enemy shots at 0.3 (was 0.25). (1d87756)

### Fixed
- **Slice 6 fix pass** (qa FAIL 957fa16, re-check PASS 57be0a1, 542 of 542 tests):
  - **S6-1:** an attack click latched just before a pause no longer fires when you resume. The latch is cleared on pause, death, focus loss and a cast-trigger change. (17b28a2)
  - **S6-3:** the projectile preview lane and ground marker now reach the true hit distance (they stopped short of the real hit reach; qa saw a hit still land 0.3 m past the drawn tip). (0e4d9b5)
  - **S6-5:** pressing Space on the focused Resume button no longer also dodges. Dodge is ignored for 2 physics ticks after a pause or resume (a code constant, `DODGE_BLOCK_TICKS_AFTER_PAUSE`). (6738109)
  - **S6-6 (test-only):** removed four stray engine error lines (`Parameter "material" is null`) from full test runs. Nothing changed in play. (1ed76f4, 5095be9)
  - **S6-7:** if the settings file can't be saved, the settings screen shows a note and logs an error instead of forgetting the choice silently. New `data/ui.json` keys `settings_screen.save_failed` and `settings_screen.save_failed_color`. (9e6c417)
  - **S6-4 is still open:** a seeded sim run does not repeat (see the README). It is a non-blocking item for a later capture and sim tooling task. *(Correction 2026-10-29: fixed in the tooling task, listed above; the same seed now repeats exactly.)*
- **5d fixes from qa:** a crowded enemy waiting to swing could slide faster than its top speed (now capped). A broken enemy stats block is now caught when the game loads. Enemy sidestep direction now comes from spawn order instead of an internal object id, so the steering itself repeats (a whole simulated run still does not repeat from a seed; see the 6c review). (c3d244f, 6e8c3e6, a23a960)
- **The old bot-sim tool had been silently broken since 5b.** It stopped compiling but still printed "OK". It is fixed, and now fails loudly on any error. (c13a43a, e100f09)
- **Slice 5 cleanups:**
  - Enemies can no longer spawn right next to a player standing in a corner (min 9 m).
  - A fresh killing-blow number is never the one dropped when 16 are showing.
  - Every HP bar setting is now checked on load.
  - The arena size check matches the real walls.
  - Less per-frame waste.
  - Broken characters in the README commands are fixed.

  (8634b2b, 24480cc, 6115702, 20483c7, c3c67f6, 1b6e725, c9925fb, 26c0c3a)
- **Burn did less damage than intended.** Recasting a Burn card restarted Burn's tick timer, so Burn often ticked only once. A refresh now keeps the timer, and the card rule only credits Burn damage that really lands. (9d91d7a)
- **Cleanups from the Slice 3b review:**
  - The heavy wind-up now sets its state before telling the rest of the game it started.
  - Re-stuns now signal.
  - Test scenarios are checked for typos on load.
  - Some per-frame waste removed before Slice 5 adds more enemies.
  - Damage values must be real numbers.

  (ffd14f3, 482031b, 5710d0d, 5f49c33, 9c7d874)
- **Projectiles ignored their hit-size data** and all used 0.25. They also shared one collision shape. (1d87756)
- **The player's hit and death colour flashes never showed.** The code read the wrong material, so only the topple ran. (9ef095a, 6583dbf)
- **The pale blue triangle in the top-left corner** was the sky colour showing past the floor edge on wide screens. (888e37b)
- **The restart test failed about 1 run in 8.** It was a harmless one-frame timing gap that predated this work. The test now measures the gap and allows up to 50 ms. (9ef095a, 6f82a4b)
- **DECISIONS.md had a stray non-UTF-8 character.** (cd60da8)

### Docs and process
- **Docs pass for the Slice 6 fix pass and the new reference docs.** New `docs/ARCHITECTURE.md` (code map, data flow from a card press to an applied effect, how-to-add checklists, gotchas). `docs/ASSETS.md` now lists everything in the repo: one third-party library (gdUnit4, MIT), no art, audio or fonts, and three project-authored files. README commands were run and the README corrected (6f67367). README rewritten after running every command: it now has a docs index, repo layout, controls, a table of all 12 capture scenarios with working capture times, the two extra capture helpers, the sim flags, and a truthful note on seeds. The wave sim prints "rerun with --seed=N" and the README called the sims "seeded"; that is only partly true: the wave plan and steering repeat, a whole run does not (S6-4). The bot sim wrapper `run_bot_sim.ps1` has no seed parameter, so its own "rerun with --seed" hint can't be followed through the wrapper. README capture example `--screenshot-out=shots/a.png` pointed outside the gitignored `screenshots/`; it now uses `screenshots/`. (6f67367)
- **[Director decision] tech-writer role added, and doc ownership split.** tech-writer owns `README.md`, `docs/CHANGELOG.md`, `docs/ASSETS.md` and `docs/ARCHITECTURE.md`. game-lead owns `docs/GDD.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/STATE.md`, `docs/OPEN_ITEMS.md` and `CLAUDE.md`. Other roles don't edit docs they don't own; they report needed changes in their hand-back. (b4c735a)
- **[Director decision] one docs pass per slice or multi-agent task.** game-lead runs tech-writer once at the end, between playtester and close, with a short doc handoff note. The loop is now build -> qa -> playtester -> tech-writer -> game-lead close; a slice can't be marked done until the docs pass is complete. Whoever adds a third-party asset gives tech-writer its source, author and license at that time. qa's slice review checks that the README commands work and the CHANGELOG has an entry. The changelog rule now names tech-writer as its owner. (b4c735a)
- **[Director decision] what goes in `docs/DECISIONS.md`.** Only assumptions, defaults and judgment calls that agents make on their own. Director directives are recorded in the GDD (design), `CLAUDE.md` (process), and this changelog with the `[Director decision]` tag. Existing DECISIONS entries stay as they are. (b4c735a)
- qa's Slice 6 re-check passed all six items (blockers S6-1 and S6-2; plus S6-3, 5, 6, 7) with 542 of 542 tests, plus two extra qa probes. qa flagged that the bot lost about 2.5x more HP with the shorter dodge, as a playtest call (see the S6-2 entry). (57be0a1)
- game-lead recorded the fix pass and the D8 question. (84abe1e, 44c5d73, dcdb043)
- game-lead corrected the 5b damage-numbers bullet the 5b damage-numbers bullet: the HP bar mode note had gone stale after D7 (fact fix, qa S6-9).
- **5d closed** (qa re-check PASS 957fa16). **Slice 6 qa FAIL** on two small blockers: an attack click latched before a pause fired after resume, and the dash preview showed 4 m while the dash really ends about 8 m away. A fix pass is in progress. (957fa16, 0d670df) **Correction (tech-writer, 2026-10-28):** the fix pass finished and qa's re-check passed (57be0a1, 542 of 542 tests); see the Slice 6 fix pass entries under Changed and Fixed above.
- **[Director decision] Answers to D1-D7.**
  - D1 A: no Game Over stats yet.
  - D2 C: hold-to-preview casting becomes the default, with a setting to cast on press. It is added to GDD §3 and scheduled as Slice 6.
  - D3 A: team tint confirmed.
  - D4 A: light stays at 3.
  - D5 A: heavy Burn stays at 50%.
  - D6 A: golem wind-up 0.7 s confirmed.
  - D7 B: HP bars are switching from always visible to damaged-only plus elites and bosses (applied in Slice 6).
- **Slice 5 closed.** qa first failed it on a broken tool, then passed it after a fix pass. The playtest found no blocker: the opening is calm (first damage at about 5.4 s), enemy shots are clearly pink, and the numbers and IMMUNE read well. The top issue is chasers stacking into one blob on the player, which goes to new step 5d along with removing the training dummy from normal runs. The HP bar look waits on director call D7. (c13a43a, 45ae002, f79455f)
- **Slices 4 and 3b closed.** The combined playtest found no blocker; the visuals and the stun read well. Should-fix items moved to Slice 5: tiny damage numbers, the faint Pointy Stick projectile, and weak reads on the cone, heal and dash. Balance questions went back to the director as D4 and D5. (68324d2)
- qa checked this file against git on 2026-10-28 and corrected three wording errors (projectile marker is a half-width; light flash start colour is pale yellow, not tan; camera basis was transposed, not flipped). All hashes and dates verified. (see docs/reviews/2026-10-28-changelog-qa.md)
- Slice 4 was split into four steps (4a-4d), and Slice 3b into four (3b-1 to 3b-4), so each step fits in one sitting. The Slice 4 playtest was folded into the 3b playtest. (0a8f929, 877a46c)
- Hold-to-preview was logged as a proposal only; nothing was built. (0a8f929)
- **New `docs/CHANGELOG.md`** (this file): backfilled from git history. It became a standing rule in CLAUDE.md, with pointers in README and STATE. Most of it landed inside commit 9d91d7a by accident, because a parallel commit picked up the files. (9d91d7a, d8cf75f)
- **New `docs/OPEN_ITEMS.md`**: one page listing everything waiting on the director. It became a standing rule in CLAUDE.md, with a pointer in STATE.md. (1d4a1fc)
- Director questions D4 (light attack cut) and D5 (heavy attack damage with Burn) were added. (493c1a3, 3ebe6c9)
- qa reviews: Slice 4 PASS, its re-check PASS, and Slice 3b PASS with should-fix items. A Burn bug found by the 3b review is being fixed before the playtest. (6f82a4b, 8cc7b92, 552ef04, 8501ce1)
- Hand-offs and status notes were kept up to date throughout the day. (6ce6189, 8566242, ebd0f0f, 0ac753b, 3a1aba1, b7ec0d0)

## 2026-10-27 (Camera fix, enemy HP bars, agent team, Polish 1 Slices 0-3)

### Added
- **Enemy HP bars.** Bars float above every enemy and show damage, a fading "ghost" segment, Burn and resistance markers. Settings live in `data/ui.json`. (b31cbde, 0309f86, bcbfe34, e60e515, 621cfa2)
- **Screenshot tooling.** A capture command plus test scenarios, so the team can see the game without a person playing it. Bad arguments fail loudly. (f468959, 96ca1a1, 083a8cf)
- **Startup self-check.** The game reports an error if the camera, player, floor, light or spawner is missing, or if the camera can't see the player. A smoke test covers it. (be64ea9)
- **Player death and Game Over (Polish 1, Slice 1).** At 0 HP the player dies once, input stops, and a slow-mo beat plays. A Game Over screen offers "Try again", which reloads the arena fresh. The HUD now reads "HP x / y". qa added a restart soak tool. (9744135, 99f6af2, 1f24ceb, d268f19, 7ad85ee)
- **Automatic light attack and manual heavy attack (Polish 1, Slice 3).** These replaced the old click-only basic attack. The light attack auto-fires at enemies in range and also fires on left click. The heavy is on right click, with a wind-up telegraph. Both are defined in `data/attacks.json`. The HUD gained LMB/RMB meters and slot ready/cooling states. (1c12fd9, de415be, b4011aa, ed0bf58, e8b7e45, 1fe89e5)
- **The agent team is in place**: game-lead, gameplay-dev, qa, ux-designer and playtester are active; art, audio and story are dormant. playtester and ux-designer were added on this date, and game-lead got the ability to run the other roles itself. (d6a6546, 112f5f0, 64e10ac)

### Changed
- **HUD layout (Polish 1, Slice 2).** Slots are fixed-size and long card names wrap, shrink, then truncate. The HUD has safe margins and a higher-contrast HP bar. Card names over 25 characters raise a warning. (f5b0c19, 88732cf, 366eabd, 60cd11e)
- **[Director decision] Polish 1 approved (Slice 0):**
  - Card rewards: pick 1 of 3 or reject all, with 3 rejects per run.
  - Density: fewer, more impactful enemies.
  - Controls: light attack (auto + left click), heavy attack (right click).
  - A survivor-style level-up idea was parked, with "do not implement".

  Recorded in the GDD. (a941ddd)
- **[Director decision] Enemy HP bars:** always visible while the enemy is alive, and the current size is fine. (edb92e4)
- **Balance: new attack numbers.**
  - Light: 8 damage every 0.6 s; clicks at most every 0.25 s.
  - Heavy: 22 damage, 1.8 s cooldown, 0.45 s wind-up.
  - Values before this are unclear from history; the old basic attack was a fixed-cooldown click arc.

  (1c12fd9)

### Fixed
- **The game showed only sky.** The camera's orientation was saved transposed (a file error), so it looked upward and the world never appeared; movement and aim were also wrong. (be64ea9)
- **Player kept moving and casting at 0 HP.** Death was never handled; fixed by Slice 1. (9744135)
- **HUD slots swallowed mouse clicks.** (b4011aa)
- **A flaky test** and a wrong README path. (ed0bf58)

### Docs and process
- Roadmap planning for HP bars and Polish 1 Slices 1-5, director answers logged, and balance questions P1-P4 raised for the director. (fe43425, edb92e4, b854bca, 1fe89e5, 4c2bfef)
- A session where role hand-offs were blocked was logged. The cause was that game-lead lacked the tool to run other roles, and it was fixed. (07aff8c, 64e10ac)
- Hand-off and status updates throughout. (43c8b48, bc5abb1, e34179e, afb47c8, 61d642c, 796542d, 612a0b6, 42c9d8c, 26d26f6, 9ec2e03, 7271aaa)

## 2026-10-26 (Milestone 1 GDD, project scaffold, Milestone 2 combat prototype)

### Added
- **Repository created** (3f3edce, an empty README). **GDD added** (c3ebd6d): the design document from the director's design interview, which is Milestone 1 (engine, 3D isometric view, Rogue/Wizard and Fire/Water for the first slice).
- **Project scaffold (Milestone 1.5).** Godot 4.7.2 project, gdUnit4 test framework, folder layout, working agreements, README, docs, and the first role agents: game-lead, gameplay-dev, qa, plus dormant art, audio and story. (5496508, 4fdcf86)
- **Milestone 2: combat feel prototype**, in one arena room:
  - Isometric camera, WASD movement and mouse aim. (4cb6e37)
  - Click basic attack, dodge roll with i-frames, and the health/damage foundation. (479a755)
  - Stat-modifier system for future passives and gear. (d6c266b)
  - Status effect system with Burn. (d031edd)
  - Seven reusable card effect templates: projectile, cone, area, dash, heal, apply status, buff. (f747a95)
  - Card data format and loader; slot types and card pools as data. (bfd3361)
  - The five card slots, each with a mini-deck, cooldowns and dead-card swap. (f613475, a82e756)
  - Three enemy types (melee chaser, ranged shooter, fire-resistant golem) and a wave spawner. (d311d28)
  - A 15-card Fire Rogue starter set. (4f27a16)
  - Bottom HUD and an F3 debug overlay. (680be9a)
  - Hit-stop, screen shake, damage numbers and hit flash. (1973fd1)
  - Headless bot-sim stub. (b6d370d)
  - Milestone 2 marked complete. (6c74bdc)

### Fixed
- **The test command could silently pass without running tests**, and a signal parameter shadowed a built-in name. (3432239)

### Docs and process
- Hand-off notes. (aed6cf9, 505ff8f) gitignore updates; the exact purpose of the second update is unclear from history. (5496508, 939e70b)
