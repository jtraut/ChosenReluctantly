# Build depth: design plan (BD0)

Owner: game-lead. Written 2026-11-02 for ROADMAP slice BD0. Status: **[PROPOSED]** until the director approves it (GDD §4a). Everything here is a plan; nothing is built yet.

**Assumption:** D29 is unanswered, so this doc uses its default A: **the dodge stays off**, and the Movement slot is the player's only escape. Section 12 says what changes if he picks B or C.

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

**Precondition: a plan-aware bot.** Today's bots press cards at random (H2 noted it). With random presses, a keystone looks no better than any other card and every check below reads as noise. BD1 adds a **plan policy**: the bot casts a card when its condition is live (or after a hold limit, default 1.5 s), uses the dead-card swap on a card whose condition can't come true soon, and **keeps one Movement card for escape** (it casts Movement offensively only when HP is above 50% or the Movement slot's next card is also ready). The policy reads hints from the card data (the `condition` block), not a per-card script.

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
- The max stack count is read through `StatModifiers` (`status_max_stacks.burn`), so a relic or keystone can raise it (D25 asks whether Burn and Bleed should stack in the base game).
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

### 4.1 Sources and count (defaults; D22 asks the director)

Today's run is 10 rooms: 7 combat, 1 elite (rooms 3-8), 1 rest (rooms 2-8) and the boss last. A boss relic only means something once runs have more than one act, so it's reserved, not used.

| Source | Default | Notes |
|---|---|---|
| **Elite room cleared** | A relic choice: pick 1 of 3 or skip. Replaces that room's card offer. | Always. The elite becomes the room you want. |
| **Rest room** | Choose: heal 30% (today) **or** pick 1 of 2 relics. | A real trade-off, and it fits the director's note that the rest heal may go later. |
| **Card reward screen** | In 1 of every 4 reward rooms (seeded), one of the 3 card slots shows a relic instead. Picking it takes the relic. | Keeps relics showing up in a straight-line run. Reject still declines the whole offer. |
| Boss (multi-act later) | Reserved: `boss` source, rarer relics. | Not used while the boss ends the run. |
| Map nodes (later, §4.6) | Reserved: `merchant`, `curse_room`, `buff_room`, `mini_boss`. | Data only now, so the map needs no relic rework. |

**Count per run:** about **3-4** in a 10-room run (1 elite, 1 rest if taken, 1-2 reward swaps). That's enough to steer a build and few enough that each one matters. No starting relic for now. All of these numbers are data in `run.json` (`relics` block).

### 4.2 Data format (`data/relics/*.json`, one file per relic, like cards)

```json
{
  "id": "pyre_insurance",
  "name": "Pyre Insurance",
  "pool": "fire",
  "rarity": "common",
  "sources": ["elite", "rest", "reward", "merchant", "mini_boss"],
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
- `rarity`: `common`, `uncommon`, `rare`, `boss`. The weights live in `run.json`.
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

- **`sources`** already names the future map nodes (`merchant`, `curse_room`, `buff_room`, `mini_boss`), so a node only has to call the same "offer relics from source X" function the elite and rest rooms use.
- **`rarity`** lets harder nodes (mini-bosses) roll better relics: "the hardest path is the most rewarding".
- **`curse`** is reserved for curse/buff rooms ("usually both at once"): a curse room offers a strong relic with a curse block attached (a downside modifier or trigger). It uses the same format, so there's no rework.
- **Merchant:** relics carry no price yet. When gold exists, a price comes from `rarity` in `run.json`, not per relic.
- The offer function takes (source, count, rng), filters by pool, source and owned relics, and weights by rarity. Elite, rest and reward rooms use it in BD2, and the map uses it later.

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
- **Slots pull against each other.** In Hit and Run, the Movement slot is both offense and the only escape (§12). In Kindling, the Utility slot feeds Burn instead of shortening cooldowns.
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

## 12. Dodge-off: what it means for Movement cards (D29 default A)

With the dodge off, **the Movement slot is the only escape**. That shapes every archetype:

1. **Every archetype deck keeps at least one pure escape card** (`neutral_backward_leap`, `wizard_sideways_blink` or `wizard_tactical_hover`). The legal decks above all do.
2. **Offensive Movement is a real risk**, not a free bonus. Hit and Run and Departure Lounge spend escapes for damage. That's the tension that makes the slot a decision. Second Wind and Controlled Panic are the relics that soften it, and they're optional.
3. **Movement cooldowns stay as they are in BD1.** H2's bots died early, but they press cards at random and never save Movement to escape (H2 playtest). BD1's plan-aware bot keeps one Movement for escape; its numbers show whether Movement cooldowns really need a look. D29's sub-question ("should Movement cooldowns be looked at?") waits for that.
4. **The bot policy must model it** (§2): no offensive Movement cast below 50% HP unless the next Movement card is ready too.

**If D29 comes back B or C** (the dodge returns), Movement cards can lean more offensive: Hit and Run's Momentum could drop its escape value, and the "one pure escape per deck" rule becomes a recommendation, not a deck-design rule. Nothing else in this doc changes.
