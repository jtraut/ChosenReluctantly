# Build depth: design plan (BD0)

Owner: game-lead. Written 2026-11-02 for ROADMAP slice BD0. Status: **[PROPOSED]** until the director approves it (GDD §4a). Everything here is a plan; nothing is built yet.

**Director answers (2026-11-02):** D22 = C in his own wording (relic sources and count, §4.1), D24 = A (relics in BD2, §9), D25 = A plus passive nodes (§3.4), D29 = B (the dodge is back, §8). This doc was first written assuming the dodge stayed off; §8 now describes the dodge-on version.

Card ids below are real ids from `data/cards/`. Cards marked **NEW** don't exist yet. Numbers are starting values for tuning, not final.

---

## 1. Diagnosis: why cards are interchangeable today

Every card today is "do X damage in shape Y" or "heal Z" or "shorten slot S for 6 s". Nothing reads the board, nothing reads the deck, and no card makes another card better. So any card in a slot does roughly what any other card in that slot does, and losing one costs nothing.

| Cause | What it looks like in data | Example cards | Why it kills build depth |
|---|---|---|---|
| **Flat damage, no conditions** | `cone`/`aoe`/`projectile` with a fixed `damage` | `rogue_quick_slash` (5), `rogue_overhand_whatever` (12), `neutral_pointy_stick` (6), `wizard_overqualified_bolt` (10.5) | A card is worth its damage per second and nothing else. Two cards with similar DPS are the same card. |
| **Status applied, never read** | `apply_status` burn/bleed, and no card checks for it | `fire_ember_whatever`, `fire_fine_burn_then`, `fire_fireball`, `rogue_bleed_slash` | Burn is just extra damage over time. "Set them on fire, then..." has no "then". |
| **No tags** | Cards have `slot_type` and `pool` only | all 32 | Nothing can say "your Projectile cards" or "per Burn card in your deck". A deck has no identity beyond its pools. |
| **Statuses don't stack** | Burn refreshes on recast (`CardDamageRule` notes it) | every Burn card | Applying Burn twice is wasted, so piling on Burn isn't a plan. |
| **Buffs are generic cooldown cuts** | `buff` on `slot_cooldown.*` | `fire_hot_head`, `rogue_not_my_problem`, `wizard_borrowed_focus`, `neutral_deep_sigh`, `wizard_footwork_allegedly` | "Your next few casts come sooner" helps any deck equally, so it's never a plan piece. The Rogue has exactly 3 Utility cards, the minimum, so every Rogue deck runs the same Utility slot. |
| **No cross-slot interaction** | Slots only talk through cooldown buffs | (all) | Pressing slots in any order gives the same result, which is the director's "spam blindly" symptom. |
| **One-use effects, no lingering state** | Effects resolve and vanish (Zones last 4 s but nothing cares that they exist) | `fire_wall` | No "while X is active" windows, so timing doesn't matter. |
| **Nothing run-scoped beyond cards** | No relics, no passives yet | — | Two runs on the same class and element differ only by which near-identical cards showed up. |
| **Basic attacks can carry a run** | Light auto-fires, heavy is free, and nothing scales them | `data/attacks.json` | The no-card win (GDD §3). The pressure pass and the dodge-off trial make it harder, but nothing makes cards *necessary* by design. |

**Engine facts that shape the plan (checked in code 2026-11-02):**
- **There is no shared event bus.** Hooks are per-node signals: `Health.damaged/died`, `Player.damage_dealt(target, amount, type, kind)`, `StatusEffectManager.status_applied/expired/refreshed/resisted`, `CardSlotController.card_cast(slot_type, card_id)`, `ZoneManager.zone_started/ended`, `RunController.room_started/room_cleared/run_won`. The autoloads are InputBindings, Juice, Settings and GamePause.
- **`status_expired` never fires when the owner dies** (`StatusEffectManager.gd:238`: the node is freed). No status signal carries a position or a source.
- **A damage event can't tell where it came from.** `kind` is only `hit`, `echo` (hit 2..N of a multi-hit) or `dot`. A light hit, a heavy hit and a card hit all look alike, and no event carries a card id.
- **`CardDamageRule`** requires every Attack-slot card to deal at least 1.5x a light hit per cast and to beat light-attack DPS while cycling, unless the card has a `rule_exception`.
- **Deck rules:** at least 3 unique cards in every slot, a deck of at least 15 (`data/deck_rules.json`).

---

## 2. Goals as measurable checks

These become sim reports in BD1 (informational) and gates once tuned (BD3). Each uses the bot sim (`tools/run_bot_sim.ps1`) over 12+ seeds and 10-room runs.

**Precondition: a plan-aware bot.** Today's bots press cards at random (H2 noted it). With random presses, a keystone looks no better than any other card and every check below reads as noise. BD1 adds a **plan policy**: the bot casts a card when its condition is live (or after a hold limit, default 1.5 s), uses the dead-card swap on a card whose condition can't come true soon, and **uses its dodge charges to escape** (dodge back since D29 = B; the earlier "keep one Movement for escape" rule is dropped, §8). The policy reads hints from the card data (the `condition` block), not a per-card script.

| Check | Measure | Target (start; tune in BD3) |
|---|---|---|
| **Removal pain** | For each archetype deck: remove the keystone, replace it with an off-plan card of the same slot, and rerun. Then do the same with a random off-plan card instead of the keystone. | Keystone removal: median boss time **+25% or more**, or clear rate **down 25 points or more**. Random off-plan removal: boss time within **±8%** and clear rate within **10 points**. |
| **Run fingerprint spread** | Per run, the share of damage by source: light, heavy, each slot, each status (Burn ticks, Bleed ticks), relic. Compare two archetypes on the same class and element. | L1 distance between their median share vectors **at least 0.6** (out of 2.0), and their top damage source differs. |
| **Archetype parity** | Median Rogue/Wizard boss time per archetype vs the standard (preset) deck under the same policy. | Every archetype inside **70-130%** of the standard deck's boss time. Clear rate within 20 points of standard. |
| **No-card run not viable** | `-LightHeavyOnly`, both classes, no relics. | Clears at most **25%** of runs (H1's target; H2 gives 0/16 today). A deliberate light/heavy relic build (Grudge Brawler, §5) is exempt and has its own parity row. |

**What the sim can't tell us:** whether a condition *feels* good to set up, whether the glow reads in a crowd, and whether a human plays an archetype the way the bot does. The director's item-35 playtest is the real gate for "do the runs feel different".

---

## 3. Synergy framework

Rule of thumb: **new code only for a generic mechanic; everything a card or relic does is data on existing templates plus these mechanics.** Element visuals still come from the shared templates.

### 3.1 Tags and keywords

- **Derived tags** come from the card's effects, computed at load. Nobody writes them by hand, so they can't drift.
  - `Projectile` (a `projectile` effect), `Melee` (a `cone`, or a `dash` with `damage`), `Area` (an `aoe`), `Zone` (a `zone`), `Dash` (a `dash` or `pass_through`), `Heal` (a `heal`, or a status of type `heal_over_time`/`lifesteal`), `Burn` / `Bleed` (applies that status), `Buff` (a `buff`).
- **Authored keywords** go in an optional `"keywords": [...]` array, validated against a new `data/keywords.json` (id, display name, one-line rule text). Only for things the effects can't show:
  - `Primer` (sets up a condition for another card), `Payoff` (has a condition that pays off), `Keystone` (the card an archetype is built on; drives the removal-pain check and the reward screen's "On your plan").
  - Later, `Summon` and others, each added when a mechanic needs it.
- A card's tags = derived + authored. Conditions, relics and scaling can all filter by tag.

### 3.2 Conditions and payoffs (new generic mechanic: effect `condition`)

Any effect in a card's `effects` list may carry a `condition`. If the condition is false, that effect is skipped. A payoff card is a base effect plus a conditional extra. Target conditions are checked per target hit; caster conditions once per cast.

| Condition type | Params | Checks | Example |
|---|---|---|---|
| `target_has_status` | `status_id`, optional `min_stacks` | the hit target has it | "+8 fire to Burning targets" |
| `cast_within` | `slot_type` or `tag`, `seconds` | you cast a matching card within the last N s | "After a Movement card: +12 damage" (Hearthstone's Combo idea) |
| `zone_active` | optional `tag` | one of your Zones is alive | "While a Zone is active: cooldown -1 s" |
| `self_stacks_at_least` | `status_id`, `count` | you hold N stacks of a self-status | "With 5+ Charge: pierce" |
| `deck_count_at_least` | `tag`, `count` | your run deck holds N cards with the tag | "If your deck has 6+ Burn cards" |
| `hp_below` (caster) | `fraction` | your HP fraction is below it | Relic and Recovery hooks |

**Payoffs that scale** use an optional `scale` block on an effect's numeric param instead of a condition: `"scale": {"by": "self_stacks", "status_id": "charge", "per": 1.5, "consume": true}` or `{"by": "deck_count", "tag": "Burn", "per": 0.5, "max": 6}`. A generic resolver reads it.

**Data, not code:** a payoff card is `effects: [ {base}, {extra, "condition": {...}} ]`. No per-card script.

### 3.3 Cross-slot hooks (primes)

- **`cast_within`** (above) makes slot B care what slot A did a moment ago. That is the main cross-slot hook, and it needs only the cast history.
- **Primed buff (extension of the `buff` template):** a buff may have `"consume_on_cast": "<slot_type or tag>"` and `"charges": N`. It lasts until it runs out or expires. Example: a Movement card that makes your next Attack: Single cast within 3 s skip its cooldown. This is Slay the Spire's "your next Attack is played twice" idea (Double Tap) in real time.

### 3.4 Scaling stacks (new generic mechanic: stacking statuses)

- Statuses gain optional `"stacking": {"max_stacks": N, "decay_after": s}`. Today every status refreshes (`max_stacks` 1), so nothing changes until data says so.
  - `damage_over_time` multiplies its tick by stacks.
  - A self-status can carry `"per_stack": {"stat": "...", "value": ...}` through `StatModifiers`.
- The max stack count is read through `StatModifiers` (`status_max_stacks.burn`), so a relic, keystone or (later) passive-tree node can raise it. **Director, 2026-11-02 (D25 = A):** Burn and Bleed don't stack in the base game; only those special sources make them stack.
- **New self-status `charge`** (Wizard): stacks to 10, decays 4 s after the last gain. It powers the Bolt Barrage archetype through `scale`.
- Inspiration: Slay the Spire's Poison (stacks; Catalyst doubles it) and Strength (a stacking scaler). Confident.

### 3.5 What's new code vs data

| Piece | New code (generic, once) | Data on existing templates |
|---|---|---|
| Derived tags, keywords table | tag derivation, `keywords.json` loader + validator | `keywords` on cards |
| Effect conditions | condition evaluator (6 types), per-target filtering in cone/aoe/projectile/zone hit paths | `condition` blocks |
| Scaling params | `scale` resolver | `scale` blocks |
| Primed buffs | `consume_on_cast`/`charges` on `buff` | buff params |
| Stacking statuses | `stacking` in StatusEffectManager; DoT x stacks; `per_stack` stats | `stacking` on statuses |
| Cast history | a short ring buffer of (time, slot, tags) | — |
| **CombatEvents relay** (needed by relics, §4) | new autoload; adds a damage `origin` and a status-end event | — |
| New effect types (BD3) | `detonate_status` (consume a status for its remaining damage x mult), `spread_status` (copy a status to enemies nearby) | params |

`CardDamageRule` (decided, see DECISIONS "BD0"): **conditional and scaled damage doesn't count.** Every Attack-slot card must pass the rule on its unconditional damage alone, so a payoff is never a dead card when its condition isn't live. No new `rule_exception` for payoffs.

---

## 4. Relics (run-scoped, rule-changing)

A relic is a passive, run-scoped item that changes a rule. It's found during a run, kept for that run only, and reset when the run ends. (Slay the Spire's relics are the model: passive, from elites, chests and shops, some with a downside. Confident.) The director's example is the first one built: "Burns now explode in an AoE when they expire and/or on death."

### 4.1 Sources and count (director, 2026-11-02: D22 = C, his wording)

**The director's rule:** a player focused on relic hunting should be able to reach **about 6-8 relics per run**, with a **hard cap of 10**. Relics come from a **merchant** (buy several at once if you have the gold), a **dedicated relic stage** (pick a relic), and **elites**. GDD §4a. **Over the three-act run (D34 = C, director 2026-11-04):** the count grows with the run, **hard cap 20** (hard to reach), **swap at the cap** (remove a relic to take a new one), **no duplicates**; relic **tiers 1/2/3/boss** with odds rising per act; elites always give a relic and never cards; **act-end mini-bosses are the only source of boss-tier relics** (2 per run) and also offer 3 rare (act 1) or 3 legendary (act 2) cards (director, revised 2026-11-04). Numbers: `docs/MAP.md` §4.5.

Two of the three sources are map nodes, and gold doesn't exist yet. So relics arrive in two steps:

| Source | BD2 (today's straight 10-room run) | First map build (after MAP0) |
|---|---|---|
| **Elite room cleared** | A relic choice: pick 1 of 3 or skip. Replaces that room's card offer. | Same, on every elite node. |
| **Relic room** (the dedicated relic stage) | New room type in the straight run, like the rest room: 1 per run, rooms 2-8, never next to the rest room or the elite. No fight; pick 1 of 3 relics or skip. | A map node type. A relic-hunting route passes several. |
| **Merchant** | Not yet (needs gold). | A map node. Relics have a price from `rarity` (in `run.json`); the player can buy several if they have the gold. |
| Mini-boss, curse/buff rooms | Reserved `sources` values. | MAP0 decides. **All sources, including events, chests, rest dig, sacrifice and starter relics: §4.7 (director, 2026-11-04).** |
| Boss (multi-act later) | Reserved: `boss` source. | Not used while the boss ends the run. **Three acts from MAP3 (director, 2026-11-04):** act-end mini-bosses give gold, a **boss-tier relic** (pick 1 of 3, no skip; the only source) and 3 rare (act 1) or 3 legendary (act 2) cards; see `docs/MAP.md` §4.5. |
| ~~Rest room (heal or relic)~~, ~~1 in 4 reward screens~~ | **Dropped** (D30 = A, director 2026-11-03: heal-or-relic is too obvious a choice, since a relic is worth more and Recovery already heals). | Same. |

**Count per run:** BD2's straight run gives about **2** (1 elite, 1 relic room). The map is what makes 6-8 reachable for a relic hunter; MAP0 lays out routes so a relic route reaches 6-8 and a route that ignores relics ends with about 2-3. ~~Hard cap 10; at the cap, relic offers are skipped~~ **Hard cap 20** (`run.json` `relics.max_owned`, D34 = C). **At the cap, offers still appear; taking a relic first asks which owned relic to give up** (cancel keeps what you have). Built in BD2 with the offer panel (tested with a low cap), reused by the MAP2 merchant. A relic you gave up isn't offered again that run. ~~No starting relic for now.~~ Starter relics come with loadouts (3d, director 2026-11-04, §4.7). All numbers are data in `run.json` (`relics` block). **Over a 30-room run (three acts, director 2026-11-04):** `docs/MAP.md` §4.5 (D34 = C).

### 4.2 Data format (`data/relics/*.json`, one file per relic, like cards)

```json
{
  "id": "pyre_insurance",
  "name": "Pyre Insurance",
  "pool": "fire",
  "rarity": "tier1",
  "sources": ["elite", "relic_room", "merchant", "mini_boss"],
  "keywords": ["Burn"],
  "modifiers": [],
  "triggers": [
    {
      "event": "status_ended",
      "filter": { "status_id": "burn", "reason": ["expired", "owner_died"], "target_team": "enemy" },
      "at": "event_position",
      "internal_cooldown": 0.0,
      "effects": [ { "template": "aoe", "params": { "damage": 4, "damage_type": "fire", "radius": 2.0 } } ]
    }
  ],
  "curse": null,
  "flavor_text": "Covers fire damage caused by fire. Read the small print."
}
```

- `pool` uses the card pools (class, element, neutral), so a Fire Rogue only sees `rogue`, `fire` and `neutral` relics.
- `modifiers`: permanent `StatModifiers` entries for the run (same shape as `buff` params, without a duration).
- `triggers`: `event` + `filter` + `effects`. **`effects` uses the card effect format and templates**, so a relic is data on the existing templates. `at` picks the origin (`player`, `event_position`, `event_target`).
- `curse`: reserved for curse rooms (a downside modifier block). `null` for now.
- `rarity`: `tier1`, `tier2`, `tier3`, `boss` (shown as Tier 1/2/3 and Boss; director 2026-11-04, was `common`/`uncommon`/`rare`/`boss`). Odds per act live in `run.json` `relics.tier_weights`. `boss` relics are only valid with source `mini_boss` and are the build-changing ones (design pass before MAP3). The field keeps the name `rarity` because `tiers` already means enemy tiers in `run.json`.
- The validator works like the card validator: known events and filters, valid effects, a known pool, known sources, and an id that matches the filename.

### 4.3 Event hooks: the CombatEvents relay (new)

There's no event bus today (§1). BD1 adds a **`CombatEvents` autoload** (its cast history feeds `cast_within`), and BD2 adds the rest of the events. It only relays, and owns no state. Emitters call it next to their existing signals; nothing that connects to those signals changes.

| Relay event | Fired from | Payload | What's new |
|---|---|---|---|
| `hit_landed` | `Health.take_damage` | target, amount, damage_type, kind, **origin**, position | **`origin`**: `light`, `heavy`, `card:<id>`, `status:<id>`, `relic:<id>`, `enemy`. Passed down from AttackController, EffectTemplates and status ticks. |
| `enemy_killed` | `Health.died` on an enemy | target, position, last origin, statuses held at death | — |
| `status_applied` | StatusEffectManager | target, status_id, stacks, source, position | adds target/position |
| `status_ended` | StatusEffectManager | target, status_id, **reason** (`expired`, `owner_died`, `consumed`), position, source | **today there's no event on death**; it fires before the node frees |
| `card_cast` | CardSlotController | slot_type, card_id, tags | adds tags; also feeds the cast history (§3.3) |
| `attack_fired` | AttackController | `light` / `heavy`, aim point | — |
| `dash_ended` | Player | start, end position, card_id | new |
| `player_damaged` | Player Health | amount, origin | — |
| `zone_started/ended` | ZoneManager | zone id, shape, position | relay only |
| `room_started/cleared` | RunController | index, type | relay only |

- **`RelicManager`** (a child of the run, not an autoload) holds the run's relics, adds their `modifiers` at room start, and connects their triggers to the relay.
- **Recursion guard:** relic-triggered damage has `origin = relic:<id>`. Triggers ignore events whose origin is a relic unless the filter says `"allow_relic_origin": true`, and the chain depth is capped at 1. So a burn explosion that applies Burn can't loop forever.
- `internal_cooldown` per trigger stops a relic from firing 30 times in one frame when it doesn't need to.
- **Cards can use triggers too** (later): the same block on a buff ("for 6 s, when an enemy dies...") so one mechanic serves both.

### 4.4 Reset, saving, HUD

- **Reset:** relics live in `RunState.relics` (an array of ids, in save order). A new run starts empty, and the run save round-trips them. `RelicManager` rebuilds from `RunState` on load. Nothing persists between runs.
- **HUD:** a row of small relic chips (initials or icon, pool frame colour) top-left under the HP bar. Hover or the pause screen shows name, rule text and flavour. When a trigger fires, its chip flashes (readability: "why did that explode?").
- **Reward screen:** a relic option is drawn as a card-sized panel with a relic frame and the word "Relic", so it can't be mistaken for a card. ux owns the look.

### 4.5 Relic sketches

**Ten for Fire Rogue and Fire Wizard** (pool in brackets):

| # | Name | Rule | Hooks | Slice |
|---|---|---|---|---|
| 1 | **Pyre Insurance** [fire] | **The director's example.** When Burn on an enemy ends (expires or the enemy dies), it explodes: 4 fire, radius 2. | `status_ended` | BD2 |
| 2 | **Smoldering Grudge** [fire] | Your card hits deal +25% to Burning enemies. | modifier with condition | BD2 |
| 3 | **Lingering Embers** [fire] | Your Zones last 50% longer, and their Burn chance becomes 100%. | modifiers `zone_duration_mult`, `zone_status_chance` | BD2 |
| 4 | **Exit Strategy** [fire] | Movement cards leave a 2 s line of fire along the path (2 dmg/0.5 s). | `dash_ended` -> `zone` | BD2 |
| 5 | **Kindling Jar** [fire] | Burn stacks up to 3 (tick damage x stacks). | modifier `status_max_stacks.burn` | BD3 (needs stacking) |
| 6 | **Second Wind, Unwillingly** [neutral] | Killing a Burning or Bleeding enemy takes 1 s off your Movement cooldown. | `enemy_killed` | BD2 |
| 7 | **Hot Streak** [fire] | Three Fire-tag casts within 4 s reset your Attack: AoE cooldown. 8 s internal cooldown. | `card_cast` + cast history | BD3 |
| 8 | **Controlled Panic** [neutral] | The first time each room you drop below 30% HP, your Movement slot is ready at once and the cast releases a 6-fire nova. | `player_damaged` | BD3 |
| 9 | **Paperwork Fire** [wizard] | Every 5th card projectile hit sets the target Burning. | `hit_landed` origin `card:*`, Projectile tag | BD3 |
| 10 | **Thermal Ward** [wizard] | While you have bonus armor, enemies that hit you in melee start Burning. | `player_damaged` + condition | BD3 |

**Five that reward light and heavy attacks** (the basic-attack archetype only exists through these, GDD §4a goal 4):

| # | Name | Rule | Hooks | Slice |
|---|---|---|---|---|
| L1 | **Spite Knuckles** [rogue] | Every 4th light hit sets the target Burning (100%). | `hit_landed` origin `light` | BD2 |
| L2 | **Heavy Sigh** [neutral] | A heavy hit on a Burning enemy explodes: 6 fire, radius 2. | `hit_landed` origin `heavy` + `target_has_status` | BD2 |
| L3 | **Muscle Memory** [neutral] | Each light hit takes 0.15 s off the heavy attack's cooldown. | `hit_landed` origin `light` | BD3 |
| L4 | **Overtime (Unpaid)** [neutral] | Light attacks are 25% faster; card cooldowns are 10% longer. (A trade-off: the first relic with a built-in downside.) | modifiers `attack_interval.light`, `slot_cooldown.*` | BD3 |
| L5 | **Grading Curve** [wizard] | The Wizard's heavy (targeted area) leaves a 2 s burning zone where it lands. | `attack_fired` heavy -> `zone` | BD3 |

**BD2 builds seven:** 1 Pyre Insurance, 2 Smoldering Grudge, 3 Lingering Embers, 4 Exit Strategy, 6 Second Wind, L1 Spite Knuckles, L2 Heavy Sigh. If the slice runs long, Exit Strategy moves to BD3.

### 4.6 Branching map hooks (GDD §9; the map itself isn't designed here)

- **`sources`** already names the future map nodes (`merchant`, `curse_room`, `buff_room`, `mini_boss`), so a node only has to call the same "offer relics from source X" function the elite and relic rooms use.
- **`rarity`** (tier) lets later acts roll better relics, and act-end mini-bosses give the boss tier: "the hardest path is the most rewarding".
- **`curse`** is reserved for curse/buff rooms ("usually both at once"): a curse room offers a strong relic with a curse block attached (a downside modifier or trigger). It uses the same format, so there's no rework.
- **Merchant (director: several relics can be bought at once):** relics carry no price yet. When gold exists, a price comes from `rarity` in `run.json`, not per relic. MAP0 designs the merchant screen and gold income.
- The offer function takes (source, count, rng), filters by pool, source, owned relics and relics given up this run (no duplicates, D34 = C), and weights by rarity. Elite and relic rooms use it in BD2, and the map uses it later. At the cap (`relics.max_owned`) it still offers; the pick goes through the swap step.


### 4.7 All relic sources (director, 2026-11-04) [PROPOSED details]

**Director's direction (2026-11-04):** he likes the relic sources in Slay the Spire and The Last Flame, from his own summary:
- elites and bosses;
- the merchant, with shop-only relics;
- map events that trade something for a relic;
- treasure chests whose size changes the odds;
- rest-site and sacrifice options;
- a starting relic.

The idea for each source is credited to his summary. Anything about those games beyond it is "unsure". **All numbers and mechanics below are game-lead proposals**, logged in DECISIONS 2026-11-04.

**Starting relics, in his words:** he doesn't want players restarting runs until the RNG gives them what they hoped for. Once a player has **unlocked "starter" tier 1 relics**, they **choose one of the unlocked ones as part of their pre-run loadout**. There is no random opening offer.

| # | Source | How it works (proposal) | Exclusive relics? | Slice |
|---|---|---|---|---|
| 1 | **Elites, act-end mini-bosses** | Unchanged: elites give a tier 1-3 offer at the act's odds; act-end mini-bosses give the boss tier (MAP.md §4.5). | Boss tier: mini-bosses only. | BD2, MAP3 |
| 2 | **Merchant** | Stock is 3 relics. **The third slot only holds shop-only relics** (their `sources` is exactly `["merchant"]`); if none is eligible, it falls back to normal stock. A shop-expanding relic (+1 relic slot, or 1 free reroll per visit) is content, as a `merchant.*` modifier. The Last Flame's "spend trophies to research the shop" waits for between-run currency (GDD §8, open). | Yes: shop-only relics. | MAP2 |
| 3 | **Events ("?" node)** | A new data-driven node type `event`, in rooms 3-9. One event per visit, drawn from `data/events/*.json`, seeded and not repeated within a run. Each event is a short text with 2-3 choices. Every choice shows its costs plainly and is a list of outcomes from a closed set: `lose_hp`, `lose_max_hp`, `gain_max_hp`, `heal`, `gain_gold`, `lose_gold`, `gain_relic` (source and tier), `gain_curse`, `remove_curse`, `remove_card`, `sacrifice_relic`, `start_fight` (elite tier), `leave`. **The curse room and buff room become two event kinds** instead of separate room types. Text stays placeholder (the story role is dormant). | Yes: event-only relics (`sources` `["event"]`), usually with a trade-off. | MAP4 |
| 4 | **Treasure chests** | The relic stage (`relic_room`) gets a **chest size: small, medium or large** (weights 50/35/15). Size is shown on the map, so you can plan for it. Small uses the act's tier odds, medium the next act's row, and large is at least tier 2 using the act 3 row. Pick 1 of 3 or skip, as decided in D22. | No. | MAP1 |
| 5a | **Rest dig** (pending **D37**) | A relic (placeholder name "Gravedigger's Spade") adds a third rest action, **Dig**: pick 1 of 3 relics at the act's odds, instead of healing or removing a card. | The dig relic itself is event-only or shop-only. | MAP4 |
| 5b | **Sacrifice** | An **altar** event lets you give up a non-boss tier N relic, then pick 1 of 3 from tier N+1 (tier 3 stays tier 3). Some high-tier relics have a **`sacrifice_cost`** (1 or 2): to take one, you give up that many owned non-boss relics. Both reuse the BD2 give-one-up step and the "given-up relics never come back" rule. This lets you take weak relics early as fodder, which is his Last Flame point. | Some `sacrifice_cost` relics. | MAP4 |
| 6 | **Starter relic (loadout)** | Tier 1 relics with `sources` `["starter"]`, found nowhere else. The loadout (3d) gets one **starter relic slot**, filled from the starter relics the profile has unlocked. Run 1 and the preset start have none. Unlock rules wait for meta-progression (GDD §8, §14 item 11), so 3d ships 2 per class unlocked by default, and the rest `locked` with "TBD". | Yes: starter relics. | 3d |

**Shared rules:**
- **No duplicates and no return:** every source skips relics you own or gave up. Sacrifices count as giving a relic up.
- **Cap 20:** every source goes through the swap step at the cap. Boss-tier relics can't be given up.
- **Curses** are relics with only a downside (`curse` block). They **don't count toward the cap**, and the swap step can't discard them. They're removed by a `remove_curse` event outcome or at the merchant (a curse-removal price, like card removal).
- **Counts:** more sources mean more relics, so MAP.md §4.5's targets stay (hunter 14-17, ignore route 6-8, cap 20 hard to reach) and the sim lowers weights or raises prices to hold them. Starter relics count toward the cap.
- **Content to add over MAP2-3d:**
  - about 3 shop-only relics;
  - about 6 event-only relics;
  - 2-3 curses;
  - about 3 `sacrifice_cost` relics;
  - the dig relic;
  - about 4 starter relics per class.

  This comes on top of MAP.md §4.5's list.

---

## 5. Archetypes (Fire only, 4 per class)

Each archetype has a **core** (4-6 cards, the keystone marked), 2-3 relics that push it, and **one full legal deck** (at least 3 unique per slot, 15+ cards, only the class, Fire and Neutral pools). Those decks become `data/debug_decks/` presets (for example `--deck=rogue-kindling`), and the sim checks use them.

**Damage rule check for the new cards** (light hit 3, light DPS 5; Attack: Single base 1.0 s, Attack: AoE base 2.5 s; Burn = 2/s, counted over min(duration, cycle)). Every NEW Attack card passes on its **unconditional** damage:

| NEW card | Unconditional cast | Cooldown mod | Cycle | DPS | Pass? |
|---|---|---|---|---|---|
| `fire_fan_the_flames` | 10 + Burn (3 ticks, 6) | +0.5 | 3.0 s | 5.33 | yes |
| `fire_heat_sink` | 10 + Burn (3 ticks, 6) | +0.5 | 3.0 s | 5.33 | yes |
| `fire_slow_burn` (zone) | 2.5 x 8 ticks = 20 | +0.8 | 3.3 s | 6.06 | yes |
| `wizard_well_actually` | 13 | 0.0 | 2.5 s | 5.2 | yes |
| `rogue_drive_by` | 6 | +0.1 | 1.1 s | 5.45 | yes |
| `wizard_thesis_defense` | 7 | +0.3 | 1.3 s | 5.38 | yes |
| `wizard_footnotes` | 4 x 1.8 = 7.2 | +0.2 | 1.2 s | 6.0 | yes |
| `rogue_open_a_vein` | 6 | +0.1 | 1.1 s | 5.45 | yes |
| `rogue_paper_cuts` | 4 x 1.5 = 6 + Bleed (2 ticks, 2) | +0.3 | 1.3 s | 6.15 | yes |

These are the numbers worked out on paper; BD1/BD3's content test (`CardDamageRule`) is the real gate. The rule is the gate: BD1 sets the final numbers so every new Attack card passes **without** its conditional bonus. Area cards hit several enemies, which the single-target rule doesn't credit; that's an existing property of the rule, not something BD0 changes.

### Fire Rogue

**R-A. Kindling** ("set it alight, then make it worse"). *Plays like:* spread Burn wide with cheap area cards, then cash it in on clusters. Damage is mostly Burn ticks and the payoff. Slice: **BD1**.
- Core: `fire_fan_the_flames` **NEW, Keystone** (Attack: AoE, cooldown +0.5. Area r3.0, 10 fire, applies Burn 4 s. **If the target is Burning: +10 fire and its Burn refreshes to 5 s.**) · `fire_kindling` **NEW, Primer** (Utility. For 8 s, Burn you apply ticks for +50%. New stat `status_damage_mult.burn`.) · `fire_ember_whatever` · `fire_fine_burn_then` · `fire_wall` · `fire_blaze_and_bail`.
- Relics: Pyre Insurance, Smoldering Grudge, Kindling Jar.
- Deck (15): single `fire_ember_whatever`, `rogue_quick_slash`, `rogue_overhand_whatever` · AoE `fire_fan_the_flames`, `fire_fine_burn_then`, `fire_wall` · utility `fire_kindling`, `fire_hot_head`, `neutral_deep_sigh` · movement `fire_blaze_and_bail`, `rogue_ugh_fine_moving`, `neutral_backward_leap` · recovery `neutral_healing_potion`, `rogue_nap_time`, `neutral_regeneration`.

**R-B. Hit and Run** (Hearthstone's Combo idea, in real time). *Plays like:* dash in, hit hard in the 2 s after, dash out. Damage is mostly the Attack: Single slot. The risk: every offensive dash spends your escape. Slice: **BD1**.
- Core: `rogue_drive_by` **NEW, Keystone, Payoff** (Attack: Single. Cone 6 physical, cooldown +0.1. **If you cast a Movement card in the last 2 s: +12 physical and knockback 3.**) · `rogue_momentum` **NEW, Primer** (Movement. Dash 4 m, pass-through. **Primes: your next Attack: Single within 3 s has no cooldown.**) · `rogue_lunge_strike` · `rogue_ugh_fine_moving` · `rogue_quick_slash` · `rogue_not_my_problem`.
- Relics: Second Wind, Exit Strategy, Controlled Panic.
- Deck (16): single `rogue_drive_by`, `rogue_quick_slash`, `rogue_flurry` · AoE `rogue_everyone_calm_down`, `neutral_shrug_bomb`, `fire_fine_burn_then` · utility `rogue_not_my_problem`, `fire_hot_head`, `neutral_deep_sigh` · movement `rogue_momentum`, `rogue_lunge_strike`, `rogue_ugh_fine_moving`, `neutral_backward_leap` · recovery `neutral_healing_potion`, `rogue_nap_time`, `neutral_leech`.

**R-C. Bleed Out.** *Plays like:* many small cuts that stack Bleed, then one cut that cashes them all in. Physical, so armor matters, not resistance: the answer to the fire-resistant golem. Slice: **BD3** (needs stacking and `detonate_status`).
- Core: `rogue_open_a_vein` **NEW, Keystone** (Attack: Single. Cone 6 physical, cooldown +0.1. **Detonates Bleed: deals its remaining damage x2 at once.**) · `rogue_paper_cuts` **NEW** (Attack: Single. 4 hits of 1.5, cooldown +0.3, each adds a Bleed stack.) · `rogue_bad_influence` **NEW** (Utility. For 6 s your Bleeds tick 50% faster. It also gives the Rogue a 4th Utility card, so Rogue Utility slots can finally differ.) · `rogue_bleed_slash` · `rogue_flurry`.
- Relics: Second Wind, Serrated Excuse (**extra sketch**: Bleed stacks to 5), Smoldering Grudge's Bleed twin (later).
- Deck (16): single `rogue_open_a_vein`, `rogue_paper_cuts`, `rogue_bleed_slash`, `rogue_flurry` · AoE `rogue_everyone_calm_down`, `neutral_shrug_bomb`, `fire_fine_burn_then` · utility `rogue_bad_influence`, `rogue_not_my_problem`, `neutral_deep_sigh` · movement `rogue_lunge_strike`, `rogue_ugh_fine_moving`, `neutral_backward_leap` · recovery `neutral_leech`, `neutral_healing_potion`, `neutral_regeneration`.

**R-D. Grudge Brawler** (the basic-attack archetype; GDD §4a goal 4). *Plays like:* the light and heavy attacks do the work; cards keep you alive and buy windows. **Only viable with its relics**, by design: without them it's the no-card run the GDD rules out. Slice: **BD3**.
- Core: `rogue_warm_up` **NEW, Keystone** (Utility. For 6 s, light attacks 30% faster and heavy cooldown -30%.) · `rogue_everyone_calm_down` · `rogue_shadow_step` · `rogue_not_my_problem`.
- Relics: Spite Knuckles, Heavy Sigh, Muscle Memory, Overtime (Unpaid).
- Deck (15): single `rogue_quick_slash`, `rogue_overhand_whatever`, `fire_ember_whatever` · AoE `rogue_everyone_calm_down`, `neutral_shrug_bomb`, `fire_fine_burn_then` · utility `rogue_warm_up`, `rogue_not_my_problem`, `neutral_deep_sigh` · movement `rogue_shadow_step`, `rogue_ugh_fine_moving`, `neutral_backward_leap` · recovery `neutral_healing_potion`, `rogue_nap_time`, `neutral_regeneration`.

### Fire Wizard

**W-A. Controlled Burn** (zone control). *Plays like:* lay fire on the ground and fight inside it; area cards hit harder while a Zone is up. Damage is mostly Zones and Burn. Slice: **BD1**.
- Core: `fire_heat_sink` **NEW, Keystone, Payoff** (Attack: AoE at the aim point, max range 8. Area r2.5, 10 fire, Burn 4 s, cooldown +0.5. **While one of your Zones is active: +10 fire.**) · `fire_slow_burn` **NEW** (Attack: AoE. A circle Zone r2.5 at the aim point for 4 s, 2.5 fire every 0.5 s, Burn 100%, cooldown +0.8.) · `fire_wall` · `fire_fireball` · `wizard_borrowed_focus`.
- Relics: Lingering Embers, Pyre Insurance, Grading Curve.
- Deck (16): single `fire_flaming_nonsense`, `wizard_bolt_volley`, `wizard_overqualified_bolt` · AoE `fire_heat_sink`, `fire_slow_burn`, `fire_wall`, `fire_fireball` · utility `wizard_borrowed_focus`, `fire_hot_head`, `wizard_ward` · movement `wizard_sideways_blink`, `wizard_tactical_hover`, `neutral_backward_leap` · recovery `neutral_healing_potion`, `neutral_leech`, `neutral_regeneration`.

**W-B. Thesis** (stacking charge). *Plays like:* fast multi-shot cards build Charge, and one big bolt spends it. Damage is mostly Attack: Single, in spikes. Slice: **BD3** (needs stacking and `scale`).
- Core: `wizard_thesis_defense` **NEW, Keystone** (Attack: Single. Projectile 7 neutral, cooldown +0.3, **+1.5 per Charge, consumes all Charge** (max 10).) · `wizard_footnotes` **NEW, Primer** (Attack: Single. 4 hits of 1.8, cooldown +0.2; the cast gives you 2 Charge.) · `wizard_bolt_volley` · `fire_flaming_nonsense` · `wizard_borrowed_focus`.
- Relics: Paperwork Fire, Extra Credit (**extra sketch**: every 5th card projectile fires twice), Hot Streak.
- Deck (16): single `wizard_thesis_defense`, `wizard_footnotes`, `wizard_bolt_volley`, `fire_flaming_nonsense` · AoE `wizard_arcane_nova`, `fire_fireball`, `neutral_shrug_bomb` · utility `wizard_borrowed_focus`, `neutral_deep_sigh`, `wizard_footwork_allegedly` · movement `wizard_sideways_blink`, `wizard_tactical_hover`, `neutral_backward_leap` · recovery `neutral_healing_potion`, `neutral_leech`, `neutral_regeneration`.

**W-C. Departure Lounge** (blink-kiting). *Plays like:* every escape leaves a present behind, and area cards hit harder right after a blink. Damage is split between Movement leftovers and the AoE slot. Slice: **BD1**.
- Core: `wizard_parting_gift` **NEW, Keystone** (Movement. Blink 5 m, invulnerable. **Leaves a delayed blast at your start point**: area r2.2, 10 fire, 0.6 s telegraph.) · `wizard_well_actually` **NEW, Payoff** (Attack: AoE. Area r3.0 around you, 13 neutral, cooldown 0. **If you cast a Movement card in the last 1.5 s: +8 and knockback 6.**) · `wizard_footwork_allegedly` · `wizard_sideways_blink` · `wizard_tactical_hover`.
  - Engine note: a delayed `aoe` locks its centre at the aim point today (`EffectTemplates.gd:328`). Parting Gift needs a small generic `anchor: "caster"` param.
- Relics: Exit Strategy, Second Wind, Controlled Panic.
- Deck (16): single `wizard_overqualified_bolt`, `wizard_bolt_volley`, `fire_flaming_nonsense` · AoE `wizard_well_actually`, `wizard_arcane_nova`, `fire_fireball` · utility `wizard_footwork_allegedly`, `wizard_borrowed_focus`, `neutral_deep_sigh` · movement `wizard_parting_gift`, `wizard_sideways_blink`, `wizard_tactical_hover`, `neutral_backward_leap` · recovery `neutral_healing_potion`, `neutral_regeneration`, `neutral_leech`.

**W-D. Ward Battlemage** (a caster that stands in close). *Plays like:* armor up, stay in the crowd, punish what hits you. Damage is AoE plus retaliation. The squishy class fighting up close is the risk. Slice: **BD3** (needs card triggers).
- Core: `wizard_spiteful_ward` **NEW, Keystone** (Utility. +25 armor for 4 s; **while it lasts, each hit you take releases a 6-neutral nova r2.5**, 0.5 s internal cooldown.) · `wizard_ward` · `wizard_arcane_nova` · `neutral_leech` · `fire_fine_burn_then`.
- Relics: Thermal Ward, Heavy Sigh, Grading Curve.
- Deck (15): single `fire_ember_whatever`, `wizard_overqualified_bolt`, `fire_flaming_nonsense` · AoE `wizard_arcane_nova`, `fire_fine_burn_then`, `neutral_shrug_bomb` · utility `wizard_spiteful_ward`, `wizard_ward`, `fire_hot_head` · movement `wizard_sideways_blink`, `wizard_tactical_hover`, `neutral_backward_leap` · recovery `neutral_leech`, `neutral_healing_potion`, `neutral_regeneration`.

**Shared Fire cards.** Fire cards are in both classes' pools, so `fire_fan_the_flames`, `fire_kindling`, `fire_heat_sink` and `fire_slow_burn` show up for both. That's intended: a Wizard can drift into Kindling, and a Rogue into Controlled Burn.

**Availability (feeds 3d and D23):** today every card is `starter`. Default for the new cards: **keystones are `reward`, everything else `starter`.** Keystones are found during a run, or planned in a loadout (3d's plan list), and the debug decks give them to testers. 3d adds the field itself; until then it's a label in this doc.

---

## 6. Slot decisions: how timing, cooldowns and the swap start to matter

- **Timing.** A payoff is worth twice as much while its condition is live, so pressing it blindly wastes it. Kindling holds Fan the Flames until a group is Burning. Hit and Run casts Drive-By inside the 2 s after a dash. Controlled Burn lays a Zone before Heat Sink.
- **Reading cooldowns.** The next card is always visible (GDD §4). With primes, the player plans a pair ("Momentum is up next in Movement, and Drive-By in Single, so dash then stab"). The cooldown bar becomes a countdown to a combo, not to "more damage".
- **The dead-card swap earns its place** (the director's 2026-11-02 note): an off-plan card in front of the keystone is worth swapping past, and a payoff whose condition can't come true soon (no Zone up, nothing Burning) is worth cycling. No rule change is needed; the swap stays as it is (GDD §4 says don't change it yet).
- **Slots pull against each other.** In Hit and Run, the Movement slot is both offense and an escape, with only 1-2 dodge charges as backup (§8). In Kindling, the Utility slot feeds Burn instead of shortening cooldowns.
- **Scaling with the deck.** `deck_count_at_least` lets a later card say "if your deck holds 6+ Burn cards", which makes reward picks matter for the plan (Monster Train's clan-focused drafting is the feel I'm after; I'm unsure of its exact card wording).

---

## 7. Readability

- **Tag chips:** a card shows up to 3 tag chips (keywords first, then derived tags) under its name. In slots, a small icon row; in reward offers and the pause card view, text chips. Data: `keywords.json` gives the display names.
- **Condition line:** `CardSummary` gets one more line type: "If Burning: +9 fire". It's built from the `condition` block and the UI strings in `run.json` (`ui.effect.condition.*`), so no card text is hardcoded.
- **Live glow:** a slot glows when its card's condition is live: a target condition counts if at least one enemy inside the card's preview area meets it (the same shape the hold-to-preview draws); a caster condition when it's true. The glow uses the card frame colour, brighter. It's the "now!" cue.
- **Primed state:** a primed slot shows a small marker (an arrow chip) and the remaining window as a thin bar.
- **Stacks:** stacking statuses show a count next to the status cue on the enemy (BD3).
- **Relics:** the HUD chip row and trigger flash (§4.4).
- **Reward screen:** cards with the Keystone keyword get a "Keystone" chip; 3d's "On your plan" highlight sits next to it.
- All of this reuses `CardSummary` and the existing frame colours; ux-designer owns the look.

---

## 8. The dodge and Movement cards (director, 2026-11-02: D29 = B)

The dodge-off trial ended: the director found the game less fluid and fun without it. **The dodge is back on Space with Rogue 2 and Wizard 1 charges, Movement cards move to Ctrl, and enemy attacks and telegraphs get a little faster** (slice H3). What that means here:

1. **One pure escape card per deck is a recommendation, not a deck rule.** The legal archetype decks in §5 keep theirs anyway; nothing needs to change.
2. **Offensive Movement can lean harder into damage.** Hit and Run's Momentum and Departure Lounge's leftovers can be tuned as offense first; the dodge covers emergencies, with only 1-2 charges.
3. **Movement cooldowns stay as they are.** The D29 sub-question about them is moot with the dodge back.
4. **The plan-aware bot (§2) dodges** with its charges and can spend Movement offensively; the "no offensive Movement below 50% HP" rule is dropped.

(The first version of this section, written for the dodge-off trial, is in git history at commit 0ddd630.)

---

## 9. Content budget and slices

Each slice should fit one sitting and gets the full loop (gameplay-dev -> ux-designer -> qa -> playtester -> tech-writer -> close) and a `playtest-YYYY-MM-DD-<slice>` tag. Slices are tied to mechanics, not specific cards: if a card doesn't work, swap it for another card using the same mechanic.

| Slice | Engine | Content | Gate |
|---|---|---|---|
| **BD1: synergy core** | derived tags + `keywords.json`; effect `condition` (`target_has_status`, `cast_within`, `zone_active`); `CombatEvents` autoload with `card_cast` + cast history; primed buff (`consume_on_cast`, `charges`); stat `status_damage_mult.<id>`; `aoe` `anchor: "caster"` | 8 NEW cards (R-A, R-B, W-A, W-C); 4 debug decks; tag chips, condition line, live glow, primed marker (ux) | plan-aware bot; removal pain, fingerprint spread, parity reported (informational) |
| **BD2: relics** | rest of `CombatEvents` (`hit_landed` with origin, `status_ended` with reason incl. `owner_died`, `enemy_killed`, `attack_fired`, `dash_ended`, `player_damaged`); `RelicManager`; relic loader + validator; `RunState.relics` + save; relic offers (elite, relic room; cap 10); recursion guard | 7 relics incl. Pyre Insurance; HUD relic row, relic offer panel (ux) | relic-aware bot; checks rerun with relics; no-card check still holds |
| **BD3: depth 2** | stacking statuses + `per_stack`; `scale`; `detonate_status`; card triggers on buffs; conditions `self_stacks_at_least`, `deck_count_at_least`, `hp_below` | R-C, R-D, W-B, W-D (about 9 NEW cards); the other 8 relics; stack counts on enemies (ux) | checks become **gating** after tuning; Grudge Brawler parity row |
| BD4+ (later) | `spread_status`, cross-element hooks when Water lands (M4) | more archetypes, curse relics (with the map) | — |

**Budget so far:** about 17 new cards, 15 relics (+2 extra sketches), 2 new effect types, 6 condition types, 1 autoload, 1 manager.

**Order (director, 2026-11-02: D24 = A, D28 = A):** BD0 -> H3 (dodge return) -> MAP0 -> PL3 -> **BD1 -> BD2** -> first map build -> 3d -> BD3. BD2 sits before the map build so map nodes can offer relics from day one.

---

## 10. Sources

No web access was used. "Confident" means I know the mechanic well; "unsure" means I'm not certain how that game does it, so the idea is ours.

| Idea here | From | How sure |
|---|---|---|
| Relics: passive, run-scoped, from elites/rest/shops, some with downsides (Overtime, curse relics) | Slay the Spire | Confident |
| Payoff on a status (Fan the Flames: "if Burning, hit again") | Slay the Spire's Bane ("if the enemy is Poisoned, deal the damage again") | Confident |
| Stacking DoT, cashing it in (Kindling Jar, Open a Vein) | Slay the Spire's Poison and Catalyst | Confident; detonate is our twist |
| Stacking self-scaler (Charge) | Slay the Spire's Strength; also Hearthstone's Spell Damage (`status_damage_mult`) | Confident |
| "Next Attack" primes (Momentum) | Slay the Spire's Double Tap | Confident |
| `cast_within` (Drive-By, Well, Actually) | Hearthstone's Rogue Combo ("bonus if you played another card first this turn") | Confident |
| On-death triggers (Pyre Insurance, Second Wind) | Monster Train's death-triggered abilities | Fairly sure the keyword is "Harvest"; the trigger idea is certain |
| Clan-like focus: reward picks steer toward a plan (`deck_count_at_least`) | Monster Train's primary and allied clans | Confident about clans; unsure about specific card wording |
| Threshold statuses (a status that matters at N stacks) | Gwent's Bleeding/Poison-style statuses | Unsure of the exact rules |
| Gear-shaped decks, many small synergies | Erannorth Chronicles | Unsure; I don't know its mechanics well enough to borrow specifics |
| Burn explosion on expire or death | The director (citing The Last Flame) | The idea is his; unsure how The Last Flame does it |

**Optional:** a research digest on the director's four favourites (Erannorth Chronicles, Gwent, Slay the Spire, Monster Train) would firm up the "unsure" rows. It needs web access, which BD0 doesn't use. It's offered in OPEN_ITEMS, not scheduled.

---

## 11. Questions for the director (answered 2026-11-02)

- **D22 = C, in his wording:** 6-8 relics for a relic hunter, hard cap 10; sources are a merchant (several at once with gold), a dedicated relic stage, and elites. §4.1.
- **D34 = C (2026-11-04), over three acts:** grows with the run, hard cap 20, swap at the cap, no duplicates. **Revised the same day:** relic tiers 1/2/3/boss with odds rising per act; elites always a relic, never cards; boss-tier relics only from the act-end mini-bosses (2 per run), which also offer 3 rare / 3 legendary cards; rare cards from act 2, legendary from act 3. §4.1, `docs/MAP.md` §4.5.
- **D24 = A:** BD1 synergy core, then BD2 relics, before 3d. §9.
- **D25 = A:** no base stacking for Burn and Bleed; relics, keystones and potential passive nodes can allow it. §3.4.
- Follow-up **D30 = A** (director, 2026-11-03): rest rooms and card reward screens don't offer relics. He may also remove the rest-room heal altogether (GDD §9); MAP0 proposes what a rest node offers.

---

## Decided in this doc (game-lead defaults, logged in DECISIONS "2026-11-02 - BD0")

- Conditional and scaled damage doesn't count toward `CardDamageRule`; payoffs pass on base damage.
- Tags are derived from effects; only `Primer`, `Payoff`, `Keystone` (and later keywords) are authored.
- Relics use the card effect format; a relay autoload (`CombatEvents`) is the event bus, introduced in BD1 (cast history) and finished in BD2.
- New keystones are `reward`, other new cards `starter` (applied in 3d).
- ~~Every archetype deck keeps a pure escape Movement card while the dodge is off.~~ Now a recommendation (D29 = B, §8).
- The sim checks need a plan-aware bot; BD1 builds it.
