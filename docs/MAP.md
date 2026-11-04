# Branching map design (MAP0)

Owner: game-lead. Status: **[PROPOSED]**, written 2026-11-03 for GDD §9 "Branching map". It has to meet the director's decisions in GDD §4a (relic sources, D22 = C, D30 = A) and §9 (D28 = A, rest-room note). The numbers are starting values, and all of them are data. Questions for the director are in §10 (D31-D33). Each has a default, and the plan below uses the defaults.

## 1. Shape of the map

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
| `elite` | yes, elite tier | **Relic** offer (pick 1 of 3 or skip; replaces the card offer, BD2 rule), gold 30-40 | 3-9 | MAP1 |
| `relic_room` (the "dedicated relic reward stage", D22) | no | Relic offer (pick 1 of 3 or skip) | 3-9 | MAP1 |
| `rest` | no | Today's rest: heal 30% or remove a card (D31 default A) | 5-9 | MAP1 |
| `merchant` | no | Spend gold: **several relics at once** if you can afford them, card removal, cards (§4.3) | 4-9 | MAP2 |
| `mini_boss` | yes, new `mini_boss` tier | Relic offer biased to uncommon and rare, **plus** a card offer, gold 45-55 | 5-8 | MAP3 |
| `curse_room` | no | A strong relic **with a curse attached** (BUILD_DEPTH §4.2 `curse` block), or leave | 3-8 | MAP3 |
| `buff_room` | no | A minor relic with no downside, or leave ("some rooms only buff") | 3-8 | MAP3 |
| `boss` | yes | Ends the run, as today | 10 | MAP1 |

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
   - **Relic estimate** (§4.1): the best path scores in `relic_route` [6, 8], and the worst path scores at most `ignore_route_max` 3.
4. **Shape rules:** rooms 2-9 each have 2-4 nodes. Every node has an outgoing edge, except the boss. At least `min_branching` (60%) of the nodes in rooms 1-8 have 2 or more next choices.
5. **If a rule fails,** the generator redraws the types; after every 10 failed type draws it redraws the grid. The same rng keeps running, so the result stays deterministic. It gives up after `max_attempts` (200) with a loud error. A test sweeps 1000 seeds and requires zero failures.

## 4. Relics and gold: the arithmetic

### 4.1 Relic estimate (used by the validator and the bot checks)

| Node | Relics counted |
|---|---|
| `elite`, `relic_room`, `mini_boss`, `curse_room`, `buff_room` | 1 each |
| `merchant` | floor(expected gold on arrival / 60, the common price), at most 3 (the stock) |
| others | 0 |

Expected gold uses the mean income: combat 15, elite 35, mini-boss 50. The start is 0, and this assumes nothing was spent before the merchant.

### 4.2 Three routes, worked out (MAP1 + MAP2 node set, no mini-boss yet)

**Relic hunter: 7 relics.** Columns: room, node, gold after the room, relics so far.

| Room | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Node | C | C | E | R* | E | C | E | R* | M | Boss |
| Gold | 15 | 30 | 65 | 65 | 100 | 115 | 150 | 150 | 30 | |
| Relics | 0 | 0 | 1 | 2 | 3 | 3 | 4 | 5 | **7** | |

- The merchant visit spends 120 of the 150 gold on 2 common relics.
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
- Cap 10 is a backstop for later sources, such as relics that grant relics, passives and tiers. The validator also enforces the 8.

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
  - **3 relics**, rarity-weighted from source `merchant`. Prices come from rarity (run.json `relics.prices`): common 60, uncommon 90, rare 130.
  - **3 cards** at 40 each, picked with the reward weights, including the "On your plan" highlight from 3d.
  - **Card removal** at 50, then +25 for each further removal in the run. It goes through the existing `can_remove` guard, so cards that would break a slot minimum are shown disabled with the reason, as at rest.
  - **Buy as many as you can afford, in any order** (the director: "several relics at once"). The panel stays open until you leave. Relics at the cap of 10 are shown disabled.
- **A route that skips fights can't buy much:** with 4 non-fight rooms, gold on arrival at a room-9 merchant is at most about 135, while the hunter route above arrives with 150.

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
    "combat":     { "weight": 50, "rooms": [1, 9] },
    "elite":      { "weight": 14, "rooms": [3, 9], "no_repeat": true },
    "relic_room": { "weight": 10, "rooms": [3, 9], "no_repeat": true },
    "rest":       { "weight": 10, "rooms": [5, 9], "no_repeat": true },
    "merchant":   { "weight": 0,  "rooms": [4, 9], "no_repeat": true },
    "mini_boss":  { "weight": 0,  "rooms": [5, 8], "no_repeat": true },
    "curse_room": { "weight": 0,  "rooms": [3, 8], "no_repeat": true },
    "buff_room":  { "weight": 0,  "rooms": [3, 8], "no_repeat": true }
  },
  "path_rules": {
    "min_fights": 6, "max_elite_like": 3, "max_merchants": 1, "max_rest": 2,
    "relic_route": [6, 8], "ignore_route_max": 3, "min_branching": 0.6
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

- **RunState gains:**
  - `map`: the full node and edge list. It's small, and it survives data edits mid-run.
  - `path`: the node ids taken.
  - `gold`, and `merchant_removals` (MAP2).
  - All of it goes into the save round trip and `equals`. A mid-map save restores the position and the open choice.
- **Determinism:** the same run seed gives the same map and the same rolls (gold and offers are seeded from the run seed and node id). Tested.
- **Bots:** the bot sim gets a route policy, `-Route first|relic|safe|random`:
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
| **MAP3: mini-bosses, curse and buff rooms** | D33 (default: after 3d, before BD3) | `mini_boss` tier and waves; `curse` block on relics (validator, and the panel shows the curse); curse and buff room panels; 2-3 cursed relics and 2 minor relics for Fire. |

MAP1 and MAP2 together are the "first map build" that D28 places before 3d. It includes the merchant and the relic stage, as he asked.

## 10. Questions for the director

- **D31: What does a rest stop offer, now that relics aren't there (D30 = A) and you may drop the heal?**
  - **A (default):** keep today's rest, heal 30% or remove a card. The heal is one data value, so dropping it later costs nothing.
  - **B:** no heal. Rest becomes "remove a card", and rest stops get rarer.
  - **C:** no rest stops at all. Card removal is only at the merchant.
- **D32: Map shape.**
  - **A (default):** 4 columns, mostly 2 choices per step, the whole map visible from the start, reading left to right.
  - **B:** 3 columns, so there are fewer and clearer choices.
  - **C:** only the next 2 rooms are visible. More surprise, less route planning.
- **D33: When do mini-bosses and curse/buff rooms (MAP3) come?**
  - **A (default):** after loadouts (3d), before BD3.
  - **B:** before 3d, straight after the merchant.
  - **C:** after BD3.
