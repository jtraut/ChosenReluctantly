# Branching map design (MAP0)

Owner: game-lead. Status: **[PROPOSED]**, written 2026-11-03 for GDD §9 "Branching map". It has to meet the director's decisions in GDD §4a (relic sources, D22 = C, D30 = A) and §9 (D28 = A, rest-room note). The numbers are starting values, and all of them are data. Director answers 2026-11-04 (§10): D31 = A, D32 = A **with three acts (30 rooms)**, D33 = B. D34 = C and D35 = A (answered 2026-11-04, §4.5, §10).

## 1. Shape of the map

- **Three acts of 10 rooms: 30 rooms per run [DIRECTOR DECISION, 2026-11-04, with D32 = A].** Each act is its own map with the shape below. **Act 1 and act 2 end in a mini-boss; act 3 ends in the final boss.** Target: **30-45 minutes** per run, and the player can **save and come back later** (§8). Rooms are counted 1-30 overall ("Room 14 of 30", "Act 2").
- **MAP1 and MAP2 build one act** (10 rooms, ending in today's boss) with the numbers below. **MAP3 adds acts 2 and 3**, the mini-bosses, act scaling and save/resume; at that point the per-act numbers in §4.5 replace the single-act ones.
- Everything below describes **one act**.

- **A run is still 10 rooms along any path.** The map is a grid of **10 rooms (rows) by 4 columns**. Every path from start to boss is exactly 10 rooms long, so "Room N of 10", run length and today's tuning all carry over.
- **Room 1:** 2-4 combat nodes. The player picks one to start from, and that pick already chooses a side of the map.
- **Room 2:** combat only, as a warm-up, the same as today's start.
- **Rooms 3-9:** a mix of node types (§2).
- **Room 10:** one boss node. Every room-9 node leads to it.
- **Choices per step:** from any node you can go to 1-3 nodes in the next room, in neighbouring columns only. Most nodes offer 2. Routes can cross over at shared nodes, but their lines never cross on screen.
- **The whole map is visible from the start** (D32 default), so you can plan a route, for example "two elites, then the merchant".
- **Reading direction:** the map reads **left to right**, with room 1 on the left and the boss on the right. Ten columns fit a 16:9 screen better than ten rows.

```
Room:  1     2     3     4     5     6     7     8     9    10
       C --- C --- E --- R* -- C --- E --- M --- R* -- Rs -\
       C --- C --- C --- E --- R* -- C --- C --- E --- C ---- BOSS
             C --- R* -- C --- Rs -- M --- E --- C --- C --/
C combat · E elite · R* relic stage · M merchant · Rs rest · (mini-boss and curse/buff rooms come in MAP3)
```

## 2. Node types

| Node (`type`) | Fight? | What you get | Rooms | Slice |
|---|---|---|---|---|
| `combat` | yes | Card offer (pick 1 of 3 or reject), gold 12-18 | 1-9 | MAP1 |
| `elite` | yes, elite tier | **Relic** offer (pick 1 of 3 or skip; replaces the card offer, BD2 rule), gold 30-40. Never cards. Relic tier odds rise per act (director 2026-11-04, §4.5) | 3-9 | MAP1 |
| `relic_room` (the "dedicated relic reward stage", D22) | no | Treasure chest, small, medium or large and shown on the map; the size shifts the tier odds. Relic offer (pick 1 of 3 or skip) (BUILD_DEPTH §4.7) | 3-8 (was 3-9; game-lead 2026-11-05, BD2 playtest) | MAP1 |
| `rest` | no | Today's rest: heal 30% or remove a card (**D31 = A**, director 2026-11-04) | 5-9 | MAP1 |
| `merchant` | no | Spend gold: **several relics at once** if you can afford them, card removal, cards (§4.3) | 4-9 | MAP2 |
| **act-end mini-boss** (`mini_boss`, fixed) | yes, new `mini_boss` tier | Gold 60, a **boss-tier relic** offer (the only source), then a card offer: **3 rare** (act 1) or **3 legendary** (act 2) (director 2026-11-04, §4.5) | 10 of acts 1-2 | MAP3 |
| `mini_boss` (optional node inside an act) | yes, `mini_boss` tier | Gold and a relic offer using the next act's tier odds; **no boss-tier relic** (those come only from act-end mini-bosses) | 5-8 | MAP4, low weight |
| `event` ("?") | no (some choices start a fight) | A text event with 2-3 choices and trade-offs; event-only relics; the curse room, buff room and altar are event kinds (BUILD_DEPTH §4.7, director 2026-11-04) | 3-9 | MAP4 |
| ~~`curse_room`, `buff_room`~~ | | Folded into `event` (2026-11-04) | | |
| `boss` | yes | Ends the run, as today (act 3's final boss from MAP3) | 10 | MAP1 |

- **Relic source ids** are the ones BUILD_DEPTH §4.6 reserved: `elite`, `relic_room`, `merchant`, `mini_boss`, `curse_room`, `buff_room`. Each node calls BD2's offer function `(source, count, rng)`, which respects the cap.
- **Hardest path, best reward** (GDD §9): elites and mini-bosses give the most gold and relics, and they're also the dangerous fights. A relic route needs several elites (§4).
- **Mini-boss** is data only: a `mini_boss` tier in `run.json` `tiers` (starting values: HP x3.5, armor 22, resistance floor 0.3), applied to an existing enemy in a `rooms.mini_boss` wave list with adds. There is no new boss AI.

## 3. Generation rules and validation

The generator is seeded from the run seed, like `RunGenerator` today: **the same seed and the same data always give the same map.**

1. **Grid walks:**
   - Draw `walks` (4) random walks from room 1 to room 9. The first two start in different columns.
   - Each step moves to column c-1, c or c+1, clamped to the grid. A step whose edge would cross an existing edge between the same two rooms is redrawn.
   - Edges (a to b) and (c to d) cross if a < c and b > d, or a > c and b < d.
   - Every visited cell is a node, and the union of the walks gives the edges. Every room-9 node connects to the boss.
2. **Types:**
   - Rooms 1 and 2 are combat; room 10 is the boss.
   - Rooms 3-9 are a weighted pick per node from `types`, inside each type's room window.
   - `no_repeat` types (elite, relic_room, merchant, rest, mini_boss, curse_room, buff_room) can't follow a node of the same type along an edge.
3. **Path rules:** checked on **every path**. There are at most 3^8 = 6561 paths, so a depth-first enumeration is cheap.
   - `min_fights` 6: combat, elite, mini_boss and boss rooms make up at least 6 of the 10. So at most 4 rooms are non-fights, and run length stays close to today's 9 fights.
   - `max_elite_like` 3: elites plus mini-bosses on one path.
   - `max_merchants` 1 and `max_rest` 2 per path.
   - `min_rest` 1: every path has at least one rest (D40 = A, director 2026-11-06; built in MAP2-A).
   - **No `min_merchant`:** a path may pass no merchant (D42 = A, director 2026-11-06). `max_merchants` 1 stays.
   - **Relic estimate** (§4.1): the best path scores in `relic_route` [6, 8], and the worst path scores at most `ignore_route_max` 3.
4. **Shape rules:** rooms 2-9 each have 2-4 nodes. Every node has an outgoing edge, except the boss. At least `min_branching` (40%; was 60%, which 4 walks can't reach, MAP1-A 2026-11-05) of the nodes in rooms 1-8 have 2 or more next choices.
5. **If a rule fails,** the generator redraws the types; after every 10 failed type draws it redraws the grid. The same rng keeps running, so the result stays deterministic. It gives up after `max_attempts` (200) with a loud error. A test sweeps 1000 seeds and requires zero failures.

## 4. Relics and gold: the arithmetic

### 4.1 Relic estimate (used by the validator and the bot checks)

| Node | Relics counted |
|---|---|
| `elite`, `relic_room`, `mini_boss`, `curse_room`, `buff_room` | 1 each |
| `merchant` | floor(expected gold on arrival / 60, the tier 1 price), at most 3 (the stock) |
| others | 0 |

Expected gold uses the mean income: combat 15, elite 35, mini-boss 50. The start is 0, and this assumes nothing was spent before the merchant.

### 4.2 Three routes, worked out (MAP1 + MAP2 node set, no mini-boss yet)

**Relic hunter: 7 relics.** Columns: room, node, gold after the room, relics so far.

| Room | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Node | C | C | E | R* | E | C | E | R* | M | Boss |
| Gold | 15 | 30 | 65 | 65 | 100 | 115 | 150 | 150 | 30 | |
| Relics | 0 | 0 | 1 | 2 | 3 | 3 | 4 | 5 | **7** | |

- The merchant visit spends 120 of the 150 gold on 2 tier 1 relics.
- Fights: C, C, E, C, E, E, Boss = 7 (rule: at least 6). Elite-like: 3 (rule: at most 3).
- Swapping room 6's combat for a third relic stage reaches **8**, but the merchant then gets 135 gold, which is still 2 relics: 3 + 3 + 2 = 8. That path has 6 fights, still legal.

**Ignore relics: 2 relics.**

| Room | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Node | C | C | C | C | E | C | Rs | M | C | Boss |
| Gold | 15 | 30 | 45 | 60 | 95 | 110 | 110 | 50 | 65 | |
| Relics | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 2 | 2 | |

- At the merchant the player buys 1 relic (60 gold) and keeps 50 for a card removal or a card instead of a second relic.
- Skipping the merchant's relic leaves 1 relic. Fights: 8.

**Why cap 10 is hard to reach:**
- A path has at most 3 elite-like relics plus at most 4 non-fight rooms.
- The best mix is 3 relic stages and the merchant. With only 6 fights, gold on arrival is at most 15 + 15 + 3 x 35 = 135, or 150 with a mini-boss, so the merchant buys 2.
- That totals 3 + 3 + 2 = **8**. A curse or buff room (MAP3) only replaces one of the non-fight slots, so the total is still 8 at most.
- Cap 10 is a backstop for later sources, such as relics that grant relics, passives and tiers. The validator also enforces the 8. (One act only. From MAP3 the cap is 20 over the three-act run, D34 = C, §4.5.)

### 4.3 The main tension (said out loud)

- **The relic hunter gets few cards.** On the hunter route above, only rooms 1, 2 and 6 give card offers: 3 picks, against 7 on the ignore route and 8 on today's straight run (7 combat rooms plus the elite's card offer).
- A hunter's deck stays close to the 15-card starter deck, plus relics that change the rules. An ignore-relics deck grows wide.
- The hunter also takes 3 elite fights for those relics.
- This is the routing decision the map is for, and BD1/BD2's archetypes give it meaning: a few relics make a lean deck spike.
- The merchant's card stock (§4.4) lets a hunter buy back a card or two if their gold allows.

### 4.4 Gold and the merchant

- **Income (run.json `gold`):**
  - Start 0. Combat 12-18, elite 30-40, mini-boss 45-55; rolled from the run seed and room.
  - Non-fight rooms give 0.
  - Unspent gold is lost when the run ends, because there's no meta-progression yet.
- **Merchant stock (run.json `merchant`):**
  - **3 relics**, rarity-weighted from source `merchant`. Prices come from the relic's tier (run.json `relics.prices`): ~~tier 1 30, tier 2 45, tier 3 65~~ (shipped in MAP2 as the D41 default) **tier 1 60, tier 2 90, tier 3 130** (D41 = B, director 2026-11-06: keep the prices and raise gold income instead; rebuilt in MAP3). Old note: (MAP2-B sim, 2026-11-06, D41 default A; at 60/90 a relic hunter ends with 5, short of 6-8). Boss-tier relics are never sold.
  - **3 cards**, priced by rarity (D41 = B, director 2026-11-06): a card always costs less than the equivalent relic tier (common < tier 1, rare < tier 2, legendary < tier 3). Proposed from MAP3, when cards get `rarity`: common 40, rare 65, legendary 95 at the 60/90/130 scale (`run.json` `merchant.card_prices`). Until then every card is 40. Picked with the reward weights, including the "On your plan" highlight from 3d.
  - **Card removal** at 50, then +25 for each further removal in the run. It goes through the existing `can_remove` guard, so cards that would break a slot minimum are shown disabled with the reason, as at rest.
  - **Buy as many as you can afford, in any order** (the director: "several relics at once"). The panel stays open until you leave. At the relic cap (20 from MAP3, D34 = C), buying a relic first asks which owned relic to give up; the player can cancel.
- **A route that skips fights can't buy much:** with 4 non-fight rooms, gold on arrival at a room-9 merchant is at most about 135, while the hunter route above arrives with 150.

### 4.5 Over three acts (MAP3; D34 = C, revised by the director 2026-11-04)

**The director's rules (GDD §4a):**
- Relics grow with the run. **Hard cap 20**, and 20 should be **hard to reach**.
- At the cap, taking a new relic means **removing one you own**.
- **No duplicate relics.**
- **Relic tiers 1, 2, 3 and boss**, with odds rising per act.
- **Elites always offer a relic and never cards.**
- **Act-end mini-bosses** are the **only source of boss-tier relics**, so every run ends with **2**. They also offer **3 rare cards** (act 1) or **3 legendary cards** (act 2).
- **Card rarity by act:** rare cards from act 2, legendary from act 3.

Starting values below are game-lead proposals (DECISIONS 2026-11-04), all data, **set by the MAP3 sim**:
- **Relic tier odds** (`run.json` `relics.tier_weights` per act), used by the elite, relic room, merchant and buff room:

  | Act | Tier 1 | Tier 2 | Tier 3 |
  |---|---|---|---|
  | 1 | 80 | 20 | 0 |
  | 2 | 15 | 70 | 15 |
  | 3 | 5 | 25 | 70 |

  Single-act runs (BD2, MAP1, MAP2) use act 1's row. Boss tier is never in these weights.
- **Mini-boss reward, in order:**
  - gold 60;
  - a boss-tier relic: pick 1 of 3, **no skip**. Boss-tier relics count toward the cap but **can't be given up** in a swap, so the "2 per run" holds;
  - the card offer: pick 1 of 3 rare (act 1) or legendary (act 2) cards, or reject it with a reject token (normal rule).
- **Card rarity odds per offer slot** (`run.json` `cards.rarity_weights` per act):
  - act 1: common 100;
  - act 2: common 80, rare 20;
  - act 3: common 62, rare 30, legendary 8.

  A pool with too few cards of a rarity fills the slot from the next rarity down.
- **Targets per run:** a relic hunter's median about **14-17**, including the 2 boss relics. The best possible path gets about 18-19, so 20 stays a backstop that later sources (curse/buff rooms, passives) can push into. A route that ignores relics gets about **6-8**: the 2 boss relics plus about 1 elite per act plus 1-3 from the merchant.
- **Per-act path rules:** MAP0's single-act rules (§3) apply in each act, with two changes:
  - the best path's relic estimate per act is [4, 6] (it was [6, 8] for one act);
  - at most 2 relic stages per path per act.

  Gold carries across acts, so the per-act checks can't see the run total; the bot sim checks it.
- **Merchant prices by tier:**
  - 60 / 90 / 130 is the one-act base (D41 = B). MAP2 actually shipped 30 / 45 / 65 as the D41 default; that line was corrected 2026-11-06.
  - MAP3 starts from 80 / 120 / 170, because gold adds up over three acts. Card prices by rarity scale with them and stay below the matching relic tier.
  - **Which lever the sim pulls (D41 = B):** too few relics for a hunter means gold income goes up, never prices down. Too many means prices go up first.
  - The merchant never sells boss-tier relics.
- **Feasibility, hunter:**
  - Per act, about 2 elites + 2 relic stages = 4, so 12 over the run, plus 2 boss relics.
  - Gold over the run is roughly 18 fights x 15 + 6 elites x 35 + 2 mini-bosses x 60 = about 600. The merchants add about 2-4 at act 2-3 prices.
  - That gives **about 15-17**. If the sim lands higher, prices rise first.
- **At the cap:**
  - Every relic offer still appears. Picking a relic opens a "give one up" list of your owned relics, without the boss-tier ones. Cancelling keeps what you have.
  - Buying at the merchant at the cap works the same way.
- **No duplicates:**
  - Offers and merchant stock never include a relic you own.
  - A relic you gave up doesn't come back later in the same run.
- **Content needed (MAP3; split off as its own slice at MAP2's close if it's too big):**
  - Cards get a `rarity` field (`common` by default, `rare`, `legendary`). Legendary cards get a gold frame (ux).
  - Per class pool: about **5+ rare** and **4+ legendary** cards, so the mini-boss offers have 3 to choose from.
  - About **6 boss-tier relics per class** (class + element + neutral eligible), so the two mini-boss offers show 3 each with no repeats. These are build-changing, so they need a **design pass first** (BUILD_DEPTH, game-lead, docs only) and may need new effect code.
  - About **22 eligible tier 1-3 relics per class**, so a 14-17 hunter still sees 3 choices late in the run. BD2 + BD3 sketch 15 in total (BUILD_DEPTH §4).
  - If a pool runs short, an offer shows what's left. With none left, a relic source gives a card offer.
- **Run totals are checked by the bot sim:**
  - median `relic` route 14-17;
  - `safe` route 6-8;
  - every finished 3-act run has exactly 2 boss relics;
  - nobody hits the cap in the median run.

## 5. Currencies

- **Gold** is built in MAP1 (earned and shown) and spent in MAP2 (merchant). It lasts for the run only.
- **XP and between-run points** are tied to the passive tree and meta-progression, which are [OPEN] in GDD §8. Default: they are **reserved only**.
  - Nodes carry a `rewards.xp` value of 0.
  - The run summary keeps an `xp_earned` field of 0.
  - The map build designs no passive economy.
  - When §8 is decided, harder nodes already have a place to give more.

## 6. Data format

**`data/map.json`** (new; layout and generation):

```json
{
  "enabled": true,
  "rooms": 10,
  "columns": 4,
  "walks": 4,
  "max_attempts": 200,
  "fixed": { "1": "combat", "2": "combat", "10": "boss" },
  "types": {
    "combat":     { "weight": 40, "rooms": [1, 9] },
    "elite":      { "weight": 16, "rooms": [3, 9], "no_repeat": true },
    "relic_room": { "weight": 14, "rooms": [3, 8], "no_repeat": true },
    "rest":       { "weight": 10, "rooms": [5, 9], "no_repeat": true },
    "merchant":   { "weight": 0,  "rooms": [4, 9], "no_repeat": true },
    "mini_boss":  { "weight": 0,  "rooms": [5, 8], "no_repeat": true },
    "curse_room": { "weight": 0,  "rooms": [3, 8], "no_repeat": true },
    "buff_room":  { "weight": 0,  "rooms": [3, 8], "no_repeat": true }
  },
  "path_rules": {
    "min_fights": 6, "max_elite_like": 3, "max_merchants": 1, "min_rest": 1, "max_rest": 2,
    "relic_route": [6, 8], "ignore_route_max": 3, "min_branching": 0.4
  },
  "estimate": { "gold_mean": { "combat": 15, "elite": 35, "mini_boss": 50 }, "merchant_price": 60, "merchant_stock": 3 }
}
```

- **Weights 0 switch a type off.**
  - MAP2 turns the merchant on (weight about 8).
  - MAP3 turns on the mini-boss and the curse and buff rooms (about 4 each).
  - While the merchant is off (MAP1), `relic_route` is set to [5, 7] in data, because the hunter's best path is then about 3 elites + 3 relic stages = 6. MAP2 restores [6, 8].
- **`run.json` gains:**
  - `gold`: income ranges.
  - `merchant`: stock counts, card price, removal price and step.
  - `relics.prices`: by rarity, as BUILD_DEPTH §4.6 said.
  - `tiers.mini_boss` and `rooms.mini_boss` (MAP3).
- **Map in memory:** `{nodes: [{id, room, column, type, wave_id}], edges: [[from_id, to_id]]}`. A fight node's `wave_id` is picked the way `RunGenerator` picks it today: from the lists that allow that room index, avoiding a repeat along the edge when possible.
- **Validator:** checks known types, windows inside 1-10, weights of 0 or more, path rules in range and unknown keys. A content test generates 1000 seeds and checks every rule on every path.

## 7. Map screen (sketch for ux, built in MAP1)

- **When it shows:** after the room-cleared or reward panel, and before the next room. The "Next: Room N of 10 - Type" line becomes the node you pick. You can also open it view-only from the pause screen ("Map").
- **Layout:**
  - Left to right, one column per room.
  - Nodes use the existing room-type shapes from `RunIcons`, so shape carries meaning without colour. New shapes are needed for relic stage, merchant, mini-boss, curse and buff.
  - Lines join the nodes. The path you've taken is bright, the current node has a ring, and nodes you can pick next are highlighted. The rest of the map is dimmed but readable.
- **Hover or focus text:** the type and what it gives, from data, for example:
  - "Elite: a relic, 30-40 gold"
  - "Relic stage: pick 1 of 3 relics"
  - "Merchant: spend gold"
  - "Rest: heal 30% or remove a card"
- **Gold:** shown on the map and on the run HUD from MAP1.
- **Controls:** mouse click, plus arrows and Enter (fixed menu keys, D26 = A). There are no new bindings. A legend in one corner.
- **Readability check:** at 1024x600, 10 columns x 4 nodes, plus the legend and gold, fit without scrolling.

## 8. Saving, determinism, bots, the straight-run switch

- **Save and come back later [DIRECTOR DECISION, 2026-11-04] (MAP3):** an **autosave at every room boundary** (when the map screen shows), one save slot. Quitting mid-fight and resuming restarts that room from its start. The start screen shows **Continue** when a save exists; finishing or losing the run deletes it. The file lives in `user://` (versioned, validated, with an injectable path so tests never touch the real user folder, the same pattern as 3d's profile) and reuses RunState's `to_json` / `equals` round trip. Must ship no later than the slice that makes runs 30 rooms long. (game-lead defaults: room-boundary saves, one slot. [Saving mid-fight, which means serialising every enemy and projectile.])

- **RunState gains:**
  - `map`: the full node and edge list. It's small, and it survives data edits mid-run.
  - `path`: the node ids taken.
  - `gold`, and `merchant_removals` (MAP2).
  - All of it goes into the save round trip and `equals`. A mid-map save restores the position and the open choice.
- **Determinism:** the same run seed gives the same map and the same rolls (gold and offers are seeded from the run seed and node id). Tested.
- **Bots:** the run sim (`wave_sim -Run`; corrected 2026-11-05, since the bot sim builds no rooms) gets a route policy, `-Route first|relic|safe|random`:
  - `first`: the lowest column, the default for hash baselines.
  - `relic`: maximizes the relic estimate.
  - `safe`: fewest elite-like nodes; prefers rest.
- **Sim checks:**
  - Median relics on `relic` routes is 6-8, and on `safe` routes 2-3 (once the merchant exists).
  - Clear rates by route.
  - The no-card gate still holds.
- **Straight-run switch:** `map.json` `enabled` (like `dodge.enabled`).
  - With it off, the run is today's straight 10 rooms from `RunGenerator`, BD2's interim relic room included. Tests, scenarios, `--run-room=N` and the `-Rooms 20 -Seed 3` baseline keep working.
  - MAP1 ships it **on**, and qa re-baselines the hashes with `-Route first`.
  - `--run-room=N` jumps along the `first` route.

## 9. Slices

Each slice is one sitting, gets the full loop and a `playtest-YYYY-MM-DD-<slice>` tag. Briefs are in docs/ROADMAP.md.

| Slice | When | Builds |
|---|---|---|
| **MAP1: the map** | after BD2 | Generator, validator and `map.json`; RunState map, path and gold, plus save; the map screen (ux); the node types combat, elite, relic_room, rest and boss; gold income and the HUD gold; the bot `-Route` flag and the 1000-seed generation test; straight-run switch. |
| **MAP2: the merchant** | right after MAP1 | Merchant node, panel and stock (several relics at once, cards, removal through `can_remove`); `relics.prices`; merchant weight on, `relic_route` back to [6, 8]; bot buys (relic route: relics first). |
| **MAP3: three acts** | right after MAP2 (D33 = B) | Acts 2 and 3 (30 rooms), the 2 act-end mini-bosses (`mini_boss` tier on existing enemies, 2 encounters), act scaling (data multipliers per act, values from the sim), new wave lists for acts 2-3, act transition screen, **save and resume**, per-act numbers from §4.5. Acceptance: median bot run 30-45 min. |
| **MAP4: events** | after MAP3, before 3d (D33 = B) | The `event` node and data-driven events (BUILD_DEPTH §4.7), with curse, buff and altar as event kinds; curse cards (D38 = A); `sacrifice_cost`; the rest dig (D37 = A); event-only relics; optional `mini_boss` nodes at low weight. May split in two at MAP3's close. |

MAP1 and MAP2 together are the "first map build" that D28 places before 3d, with the merchant and the relic stage. D33 = B puts MAP3 and MAP4 before 3d too.

## 10. Questions for the director

**Answered 2026-11-04:** D31 = A (keep heal 30% or remove a card). D32 = A, plus **three acts of 10 rooms (30 total), mini-bosses ending acts 1 and 2, the final boss ending act 3, a 30-45 minute run, and save-and-return**. D33 = B (mini-bosses and curse/buff rooms before loadouts).

**Also answered 2026-11-04:** **D34 = C** (his own option): relics grow with the run, hard cap 20 and hard to reach; at the cap you remove a relic to take a new one; no duplicate relics. **D35 = A:** still 3 rejects per run over 30 rooms. **Revised the same day (item 42):** relic tiers 1/2/3/boss with odds rising per act; elites always give a relic and never cards; act-end mini-bosses are the only source of boss-tier relics (2 per run) and also offer 3 rare (act 1) or 3 legendary (act 2) cards; rare cards appear from act 2, legendary from act 3 (§2, §4.5).

No open questions in this doc.
