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
