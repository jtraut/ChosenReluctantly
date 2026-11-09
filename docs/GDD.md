# LegendsCards (working title): Game Design Document (v0.2)

Status: v0.2, rebuilt from the director's design interview (2026-10-26). Engine, perspective, and slice classes and elements are now decided.
Updated 2026-10-27 with director decisions: reward offer format (section 9), density principle (section 1), light/heavy attack controls (section 3), and a parked-ideas section (section 15).
Updated 2026-11-02 with the director's notes of 10/31-11/2: key labels follow the bindings (§3), no-card runs not viable (§3), the build-depth section (§4a), passives linked to loadouts and free respec (§8), the pressure pass and loadout changes (§9).
Items marked **[OPEN]** are undecided. Items marked **[PROPOSED]** are suggestions awaiting approval.
This file is the source of truth. If it is not here, it is not decided.

---

## 1. Vision

A fast, isometric action RPG where your skills are cards. Combat is live and animated like an ARPG, but each skill slot draws from a deck you build, giving the depth of a deck-builder with the pace of real-time combat. Characters combine a **class** and an **element** (for example Fire Rogue, Dark Rogue), and runs are short, randomly generated roguelite sessions backed by deep between-run progression.

Passion project. Targets: playable by the director, fiancee, family, and friends. Steam is a possible far-future goal, not a driver.

### Pillars (non-negotiables, in priority order)
1. **Deep theorycrafting.** Class + element combinations, subclass choices, passives, and equipment must create real build decisions.
   - **[DIRECTOR DECISION, 2026-11-02]** This pillar is behind and is the top priority before more screens, art or staging. Card choice must change how a run plays: a player should be able to go into runs with wildly different plans on the same class and element, repeatedly, and removing a card the plan depends on must hurt. See §4a.
2. **No two runs alike.** Randomly generated runs with meaningful variance in rooms, rewards, and card availability.
3. **A unique blend of ARPG and deck-builder.** Real-time combat driven by typed card slots.

Story and lore are the lowest priority. Light flavor only until everything else works.

### Density principle **[DIRECTOR DECISION]**
Fewer, more impactful enemies. Telegraphed attacks, readable danger, and dodge skill over chaotic hordes.

### Reference games
| Game | What we take from it |
|---|---|
| Grim Dawn | Combat pace and feel |
| Slay the Spire | Deck-building structure and card drafting |
| Path of Exile 2 | Build depth |
| Tower of Babel: Survivors of Chaos | Smaller-scale model of per-class passive trees and equipment loot between roguelite runs |

---

## 2. Core Loop

**Run (target 30 to 60 minutes):** enter a procedurally generated run, fight through rooms, gain cards and rewards, pick two subclasses along the way, defeat elites and bosses, face a final boss.

**Between runs (meta):** spend earned currency on passive trees (one per class, one per element) and gather equipment, becoming gradually stronger and more tuned to a playstyle.

**Later, possible second mode:** a persistent character that progresses deeply (classic ARPG track). The roguelite run mode comes first and is the only mode in scope for the prototype and first release.

---

## 3. Controls and Camera
- **Perspective:** 3D with a fixed isometric camera. **[DECIDED]**
- **Movement:** WASD.
- **Aim:** mouse.
- **Light attack:** fires automatically on a short timer toward the aim direction, and also fires immediately on left click (which restarts the timer). Always available, unaffected by card slots. **[DIRECTOR DECISION]**
- **Heavy attack:** right click. Manual by default, with its own longer cooldown, a visible wind-up, a wider arc, more damage and knockback. Whether either attack is automatic is a data setting. **[DIRECTOR DECISION]**
- **Role of basic attacks [DIRECTOR DECISION, 2026-10-28]:**
  - **Clicking is an early-game crutch.** Manual attacks should feel underwhelming and unnecessary once the build and cards take shape, unless the player deliberately builds into light or heavy attacks with boosters. The spam-click advantage is capped as a ratio of the auto light rate (1.5x), so attack-speed boosts scale both.
  - **Basic attacks are weaker than active card plays.** Cards are the heart of the game. A card should always feel better than the free attack it competes with.
  - **Heavy attacks trade sustained damage for burst and utility.** A heavy attack may have lower single-target DPS than the light attack, but offers burst, a larger area, and class and element flavor (for example stun, a boosted element status chance, or a ranged targeted area for casters). Heavy attacks are defined per class in data and support different shapes (wide melee arc, targeted ranged area). **[PROPOSED]** Rogue heavy: wide arc, burst, brief stun on hit. **[PROPOSED]** Wizard heavy: targeted ranged area at the mouse point.
  - **Heavy wind-up slows the player slightly. It never roots.**
  - **[DIRECTOR DECISION, 2026-11-02]** A run won with no cards at all (light and heavy attacks, dodge and rest rooms only) should not be possible. The director did exactly that with the Wizard on 2026-10-31 (10 rooms, no cards, no healing, 5:25). The one future exception is a deliberate build that invests in light and heavy attacks through deep build mechanics (relics, passives); see §4a. **[DIRECTOR DECISION, 2026-11-02]** No-card runs shouldn't be easy to complete, regardless of how long they take: a slow no-card win still counts as too easy.
- **Card slots:** five card keys, read from `data/input_bindings.json`. Defaults **[DIRECTOR DECISION, 2026-11-01/02]:** Q, E, 1, 2, R for slots 1-5 (Attack single, Attack AoE, Utility, Movement, Recovery). **[DIRECTOR DECISION, 2026-11-02] While the dodge is off (dodge-off trial below):** Movement on **Space** and Utility on **F**, so the slots are Q, E, F, Space, R and no slot sits on a number key. Shift + the same key still swaps. **[DIRECTOR DECISION, 2026-11-02] (D29 = B), the dodge is back:** the dodge returns to **Space** and the Movement slot moves to **Ctrl**, so the slots are **Q, E, F, Ctrl, R**. Utility stays on F. Shift + the same key still swaps (Shift+Ctrl for Movement).
- **Key labels follow the bindings [DIRECTOR DECISION, 2026-11-02]:** whatever is in `data/input_bindings.json` is what the UI shows, so the screen and the keys can never disagree. No UI text may hardcode a key. Two actions may not share the exact same key plus modifiers; a conflict fails loudly at startup.
  - **[DIRECTOR DECISION, 2026-11-02] (D26 = A):** fixed menu keys (Enter, the arrow keys, and 1 / 2 on the class pick) may be named on screen without coming from the bindings file. Every gameplay key still comes from the bindings.
- **Hold-to-preview casting [DIRECTOR DECISION, 2026-10-28]:** by default, holding a card's key shows its exact hit area on the ground (drawn from the same data as the hitbox), and the card casts on release. A setting switches casting to trigger on press instead.
- **Reward and removal screens pick by mouse [DIRECTOR DECISION, 2026-11-02]:** the number keys that picked an option or jumped to a column are dropped ("mouse selection is sufficient"), so a number can't be mistaken for a card key.
- **Dodge roll:** Space bar. **[DIRECTOR DECISION, 2026-11-02] (D29 = B)** The dodge is a universal action with its own charges; Movement cards are separate special moves on their own key (Ctrl). This settles the old open question (§4).
  - **Dodge-off trial [DIRECTOR DECISION, 2026-11-02], ended the same day:** a no-card Wizard run still looked winnable after the H1 pressure pass, so the dodge was removed from play (slice H2). The code stayed behind a data switch.
  - **Trial result [DIRECTOR DECISION, 2026-11-02] (D29 = B):** without the dodge the game "didn't feel as fluid or fun", though runs were still very winnable (no trouble with the Rogue). **The dodge comes back with fewer charges: Rogue 2, Wizard 1.** Because the dodge returns, **enemy attacks get a little faster**: general enemy attack speed and especially the telegraphs, above all the boss's "Fan of regrets" fan-out volley. Data values, tuned in slice H3.
  - **[DIRECTOR DECISION, 2026-11-02] (D19 = A):** if a Movement card's dash ends overlapping an enemy, the player stays ghosted until clear (at most 3 s), and a dodge in that short window also passes through enemies. It is the only time the dodge passes through.
  - **[DIRECTOR DECISION, 2026-10-28]** The dodge is a modest escape, about 5 m, and may be lowered later. Its distance must stay easy to tune (data). Critical survival manoeuvres should come from Movement cards, not the dodge.
  - **[DIRECTOR DECISION, 2026-10-29]** The dodge has **charges**: start with 3 (may drop to 2; data value). Each charge recharges on a slightly longer cooldown than the old single-dodge cooldown (0.8 s). The HUD must show the dodge charges and their cooldown.
  - **[DIRECTOR DECISION, 2026-10-30]** The starting charge count is per class: ~~Rogue 3, Wizard 2~~ **Rogue 2, Wizard 1** since 2026-11-02 (D29 = B; see §5).
  - **[DIRECTOR DECISION, 2026-10-30]** The dodge **does not pass through enemies** (enemy bodies are solid). **Movement cards do** pass through enemies during their move.
  - **[DIRECTOR DECISION, 2026-10-29]** Passives (class and element trees, possibly subclass passives) may raise or lower the baseline dodge charges as a trade-off (for example a tankier Knight, Guardian or Paladin build with fewer charges). Level-up boosts must never change dodge charges, because a repeatable pick could stack them. **Hard limits: minimum 0, maximum 4 charges** after all modifiers.
- **Controller:** late stretch goal, not in scope.

---

## 4. Card Slot System

Each slot has a **type** and its own **mini-deck** drawn from the cards of that type that the player owns and has put into the deck.

### Slot types (up to 5)
1. Attack: Single target
2. Attack: AoE
3. Utility
4. Movement
5. Health / Recovery

Notes:
- The Attack slot may be split into Single and AoE if it plays better. Classes and builds can lean toward either. **[PROPOSED]** build the prototype with the split and merge later if it feels cluttered.
- Slot count and types are data-driven so they can change without code rewrites.
- **[DIRECTOR DECISION, 2026-10-29] (D13 = B)** Healing was too strong for a 30 HP pool: the Recovery slot's base cooldown goes from 8 s to 12 s (data). Recovery keeps the longest base cooldown of any slot.

### Cycling rules
- When a card is used, its slot goes on cooldown. When the cooldown ends, the slot reveals the next card from its mini-deck.
- **The next card in each slot is always visible**, so the player can plan.
- **Cooldown = slot base cooldown + card modifier.** The modifier can be negative, so fast cards (for example a quick slash) can shorten the slot's cooldown and be chained rapidly. This gives every card a built-in power budget.
- Slot base cooldowns can be modified by character passives, passive-tree nodes, and equipment.
- **Dead-card swap:** the player may discard the currently revealed card and draw the next one at the cost of a short penalty cooldown on that slot. Exact penalty is a tuning value.
  - **[DIRECTOR DECISION, 2026-10-30]** The input is **Shift + the slot's key** (was Ctrl + 1-5, too much of a stretch; with the 2026-11-02 bindings that is Shift+Q, Shift+E, Shift+1, Shift+2, Shift+R). The swap is expected to matter more once decks have real synergies.
  - **[DIRECTOR DECISION, 2026-11-02]** The swap feels pointless today because nothing makes a card worth saving. Don't change it yet; it should earn its place once synergies exist (§4a).
- **No resource system (mana, energy) in the initial version.** May be revisited much later depending on how gameplay feels.
- **Shuffle bag [DIRECTOR DECISION, 2026-10-28]:** every card in a slot is drawn once before any card repeats. After a reshuffle, the first card of the new cycle is never the same as the last card of the previous cycle, as long as the slot has more than one unique card.

### Unique-card minimums [DIRECTOR DECISION, 2026-10-28]
- Forcing deck variability is the point of the game, so each slot needs a minimum number of **unique** cards (distinct card ids). Copies of the same card don't add to the count. Because each card belongs to exactly one slot type, group totals never double count.
- Minimums are data and can be tuned per slot. A named **group** of slots can optionally carry a combined minimum.
- **Active values:** every slot needs at least **3 unique cards**. There are no per-slot overrides and no group minimums.
- The director may later set values such as a combined attack minimum of 10 or a higher utility minimum. These are **examples only, not active**.
- **Where it's enforced:**
  - Every deck that can start a run (preset starting deck, saved loadouts, the deck at run start) must satisfy every active rule. A deck that fails cannot start a run.
  - Any in-run removal or swap (for example a deck-clean reward) is blocked if it would break a rule. The reward reject mechanic (§9) is unaffected.
  - Content validation checks that every class + element combination, together with the neutral pool, can satisfy the rules.
- **[DIRECTOR DECISION, 2026-10-28]** Duplicate copies of a card are allowed in a deck, since later rewards may grant copies. Copies never count toward a unique minimum.
- **[DIRECTOR DECISION, 2026-10-28]** Neutral cards use the neutral colour palette, not the owner's element colour. (This is the effect/VFX palette. The card *frame* colour is the separate rule below.)
- **Card frame colours [DIRECTOR DECISION, 2026-10-30] (answers D17):** a card's frame (border) colour shows its family at a glance, and is the main cue for physical vs elemental damage:
  - **Element cards** use their element's colour (Fire: red/orange).
  - **Class cards** use a light bronze.
  - **Neutral cards** use grey.
  - This applies wherever a card is drawn (slots, reward offers, deck lists). The pause card-details view (later) shows more, but the frame is the quick read.
- **Temporary testing default:** for the prototype, the preset first-run deck contains every available Fire Rogue card (class, element, neutral). Unlock and tuning rules come with the run loop.

### Open items
- ~~**[OPEN]** Does Space dodge roll replace the Movement slot's basic function, or is the Movement slot only for special movement cards (blink, charge, leap)?~~ Resolved 2026-11-02 (D29 = B, §3): the dodge is universal on Space with its own charges; Movement cards are special moves on Ctrl.
- ~~**[OPEN]** What happens when a mini-deck runs out?~~ Resolved: a shuffle bag with no back-to-back repeat across reshuffles (see Cycling rules).

---

## 4a. Build depth and synergy

Added 2026-11-02 from the director's notes. The goals are director decisions. The mechanics are **[PROPOSED]** until the director approves the BD0 design doc (`docs/BUILD_DEPTH.md`, written by game-lead).

### The problem, in the director's words (2026-11-02)
- The slots don't create synergy or real decisions yet. Any slot can be spammed blindly with the same kind of outcome.
- Decks lack variability. Every run of the same class and element feels the same.
- Almost any card can be added or removed without suffering, and the run is still an easy win. That is the symptom to fix.

### Goals **[DIRECTOR DECISION, 2026-11-02]**
1. A player can go into a run with wildly different plans or playstyles, even on the same class and element, again and again.
2. Cards and decks must change how a run plays. A card the plan depends on should be painful to lose.
3. Variation also comes from **relics/enchants found during a run and reset between runs** (in the spirit of Slay the Spire's relics and The Last Flame). Leaning into them gives deep synergies or specialisations. Director's example: "Burns now explode in an AoE when they expire and/or on death."
4. Basic attacks become a real archetype only through deliberate investment (relics, later passives). Without it, a no-card run is not viable (§3).
5. This comes before refining graphics and staging.

### Relic sources and stacking **[DIRECTOR DECISION, 2026-11-02]**
- **(D22 = C, director's wording)** A player focused on relic hunting, trying to collect as many as possible, should be able to reach **about 6-8 relics per run**, with a **hard cap of about 10**. *(Superseded for the three-act run by D34 = C below; still the target for one 10-room act.)* Relics come from:
  - a **merchant** stage, where the player can buy **several relics at once** if they have enough gold;
  - a **dedicated relic reward stage** (pick a relic);
  - **elites** (a relic after an elite).
- **[DIRECTOR DECISION, 2026-11-03] (D30 = A)** Those three are the only relic sources. Rest rooms do **not** offer "heal or a relic", and card reward screens do **not** show a relic. Director's reason: heal-or-relic is too obvious a choice, because a relic is worth much more over a run while healing is already easy to get through the Recovery slot.
- **Relics over the three-act run [DIRECTOR DECISION, 2026-11-04] (D34 = C, the director's own option):**
  - The relic count **grows with the run**. **Hard cap 20**, and reaching 20 should be **difficult**.
  - **At the cap,** taking a new relic means **removing an existing one** first.
  - **No duplicate relics.**
  - ~~Mini-bosses always give gold and a rare card offer (no relic). Elites in acts 2-3 have a smaller chance to also offer rare cards.~~ Replaced the same day by the revision below.
- **Relic tiers and rewards by act [DIRECTOR DECISION, 2026-11-04] (revises D34 = C):**
  - **Relic tiers:** tier 1, tier 2, tier 3 and **boss tier**.
  - **Tier odds rise per act:**
    - Act 1: a high chance of tier 1 and a low chance of tier 2.
    - Act 2: a high chance of tier 2 and a low chance of tier 1 and tier 3.
    - Act 3: a high chance of tier 3, a lower chance of tier 2 and a much lower chance of tier 1.
  - **Elites always offer a relic, and never cards.** Their chance of higher-tier relics rises per act, as above.
  - **Boss-tier relics** are among the most powerful, offering build-changing synergies and mechanics. **The act-end mini-bosses always offer them and are the only source**, so every run ends with **2 boss-tier relics**.
  - **Mini-boss card offers:** the act 1 mini-boss also offers **3 rare cards**. The act 2 mini-boss offers a choice between **3 legendary ("gold") cards**.
  - **Card rarity by act:** rare cards start appearing in act 2. Legendary cards start having a chance to appear in act 3.
  - The numbers are proposals in `docs/MAP.md` §4.5, set by the MAP3 sim.
- **Merchant prices [DIRECTOR DECISION, 2026-11-06] (D41 = B):**
  - Relic prices stay tiered and high: **tier 1 60, tier 2 90, tier 3 130** for one act. If a relic hunter falls short of the target, **gold income goes up; relic prices don't come down.**
  - **Card prices are tiered by card rarity too** (common, rare, legendary), and a card is **always cheaper than the equivalent relic tier.**
  - Rejected: halving relic prices to 30/45/65 (A, what MAP2 shipped as the default), accepting about 5 relics (C), and 45/65/90 (D).
- **More relic sources [DIRECTOR DECISION, 2026-11-04]:** the director likes these relic sources from Slay the Spire and The Last Flame:
  - elites and bosses;
  - a merchant with shop-only relics;
  - map events that trade HP, gold or a curse for a relic;
  - treasure chests whose size changes the odds;
  - rest-site digging and relic sacrifices;
  - a starting relic.

  This widens D30's "only three sources".
  - **Rest dig [DIRECTOR DECISION, 2026-11-04] (D37 = A):** a rest site can give a relic **only through a dig relic** (the Shovel idea). With it, the rest stop gets a third action, **Dig**, which **replaces both** the heal and the card removal at that rest. Without the dig relic, rests stay as D31 = A: heal 30% or remove a card.
  - **Curses are cards [DIRECTOR DECISION, 2026-11-04] (D38 = A):**
    - A curse is a useless or harmful card shuffled into one slot's mini-deck, so you have to dead-card swap past it. This gives the swap a real job (§4).
    - You remove a curse like any card: at a rest stop, at the merchant, or through an event.
    - Curse cards don't count toward the slot minimums (§4).
    - Curses are not relics.
  - **Starting relic, in his words:** players shouldn't depend on restarting runs until the RNG gives them what they hoped for. Once they've unlocked "starter" tier 1 relics, they choose one of them as part of their pre-run loadout.
  - The details are [PROPOSED] in BUILD_DEPTH §4.7.
- **(D25 = A)** Burn and Bleed do **not** stack in the base game; a second application refreshes the first. Stacking the same status comes only from special conditions: **relics, keystone cards, and potential passive-tree nodes** (§8). The director likes this.
- **(D24 = A)** Relics are built in their own slice (BD2) straight after the synergy core (BD1), before loadouts (3d).

### Inspiration **[DIRECTOR DECISION, 2026-11-02]**
Ideas may come from: Slay the Spire, Across the Obelisk, Darkest Dungeon, Hearthstone, Gwent, Combo Card Clashers, Decktamer, The Elder Scrolls Legends, Eternal Card Game, Hadean Tactics, Hellcard, Lightseekers, Monster Train 1 and 2, Roguebook, Erannorth Chronicles. The director's favourites, to lean on most: **Erannorth Chronicles, Gwent, Slay the Spire, Monster Train.** Design docs say which idea comes from which game, and say "unsure" rather than invent details about a game.

### Balance inputs from the director (2026-11-02; inputs, not tasks)
- The AoE cards that burst around the character feel strongest.
- Wall of Mild Fire felt underwhelming before its 1.5x size boost. Keep the new size.

### Mechanics **[PROPOSED]**
Summary of BD0 (`docs/BUILD_DEPTH.md`, 2026-11-02). The full plan, numbers and card lists are there. All of it is data on the existing effect templates, with new code only for generic mechanics. Written assuming the dodge stayed off; the director brought it back (D29 = B), and BUILD_DEPTH §8 was updated for that. Where a bullet below conflicts with "Relic sources and stacking" above, the director's decision wins.
- **Tags:** derived from a card's effects (Projectile, Melee, Area, Zone, Dash, Heal, Burn, Bleed, Buff) plus a few authored keywords (Primer, Payoff, Keystone) from `data/keywords.json`.
- **Conditions and payoffs:** any card effect may carry a `condition` (target is Burning; you cast a Movement card in the last N s; one of your Zones is active; later: self stacks, deck tag count, low HP). Payoffs must still beat the free attack on their unconditional damage.
- **Cross-slot hooks:** `cast_within` conditions, and primed buffs ("your next Attack: Single within 3 s has no cooldown").
  - **[DIRECTOR DECISION, 2026-11-04] (D39 = A)** The dodge roll doesn't count as a Movement cast for `cast_within` or primes. Only Movement cards (Ctrl) count. The dodge stays a pure escape.
- **Scaling stacks:** statuses may stack (off by default), and a self-status like the Wizard's Charge can scale a payoff. Burn and Bleed don't stack in the base game; relics, keystones and later passive nodes can make them stack (D25 = A, above).
- **Relics:** run-scoped, reset between runs, one JSON file each, using the card effect format plus triggers on a new `CombatEvents` relay (there is no event bus today). Sources and count: see "Relic sources and stacking" above (elites, a relic stage, a merchant; 6-8 for a relic hunter in one act; over three acts it grows, hard cap 20, swap at the cap, no duplicates, D34 = C). Relic data already names future map nodes (merchant, curse/buff rooms, mini-bosses). 15 sketches, including the director's burn explosion ("Pyre Insurance") and 5 that reward light and heavy attacks.
- **Archetypes:** 4 per class on Fire, each with a keystone card and a full legal deck. Rogue: Kindling, Hit and Run, Bleed Out, Grudge Brawler (the light/heavy build, only viable with its relics). Wizard: Controlled Burn, Thesis, Departure Lounge, Ward Battlemage.
- **Movement cards:** with the dodge back (D29 = B), offensive Movement cards can lean harder into damage; keeping a pure escape card in a deck is a recommendation, not a deck rule.
- **Readability:** tag chips, a condition line in `CardSummary`, a slot glow when the condition is live, and a primed marker.
- **Measurable checks** (need a plan-aware bot, built in BD1): removal pain, run fingerprint spread, archetype parity (70-130% of the standard deck's boss time), and no-card runs at most 25% clears.
- **Slices:** BD1 synergy core with 2 archetypes per class; BD2 relics (D24 = A: before 3d); BD3 stacking, the other archetypes and relics.

---

## 5. Classes, Elements, and Card Pools

### Classes (initial list; more later)
Rogue, Wizard, Knight, Barbarian, Archer, Priest.

### Elements
Fire, Water, Earth, Wind, Light, Dark. Others may be added.

### Character creation
Pick one **class** and one **element** (for example Fire Rogue).
- **Class + element is a dual-class system [DIRECTOR DECISION, 2026-11-09]:** there is no "no element" option. A build is a matter of which side the player leans into more (the class side, for example physical and Bleed for the Rogue, or the element side, for example Burn), or keeping it hybrid and evenly balanced. Both sides must offer enough cards and relics to lean into (BD3a, BUILD_DEPTH §9a).

### Wizard moved earlier **[DIRECTOR DECISION, 2026-10-29]**
- The **Wizard** is added now, ahead of Milestone 4, as a ranged class: its **light and heavy attacks are ranged** and aimed at the reticle. Reason: an outside playtester expected left click to hit distant enemies under the reticle, and found the Rogue's melee swing confusing. Water and the subclasses stay in Milestone 4.
- **Wizard risk [DIRECTOR DECISION, 2026-10-30] (D18 = A):** the Wizard must not be the "easy way out". Its rooms should cost some HP, but less than the Rogue's. It should be squishier than it is today (HP is a tuning lever), starts with ~~2~~ **1 dodge charge** (the Rogue starts with ~~3~~ **2**; D29 = B, 2026-11-02), and has a slightly longer **Recovery** slot cooldown than the Rogue. All three are per-class data values.
- **Wizard HP 22 [DIRECTOR DECISION, 2026-11-02] (D20 = B):** truly squishier. A full boss "Fan of regrets" volley (25) from full HP can kill the Wizard, and that's acceptable: "a player realistically shouldn't be hit by a full volley, only partial, and if they do that's their fault."
- **The volley up close [DIRECTOR DECISION, 2026-11-04] (D36 = A):** leave the Fan of regrets as it is. At 6 m or closer its gaps are narrower than the player's body, so only the dodge saves you; up close is the risky place for a Wizard to be, and the dodge is the answer. No minimum range and no wider spread.

### Card pools
A character may only draw cards from:
1. Their class pool
2. Their element pool
3. The shared **Neutral** pool (for example Healing Potion, basic utility)

No off-class or off-element cards, with these planned exceptions:
- **Thief** (Rogue subclass): can steal cards from enemies or other pools.
- **Elementalist** (Wizard subclass): unlocks all non-Light/Dark elements, or lets the player pick one additional element. **[OPEN]** which.

**Implementation rule:** the pools a character can draw from are a **data field** on the character and subclass, not hardcoded logic. Exceptions like Thief and Elementalist are simply data.

---

## 6. Subclasses

- Each class has **2 subclasses**. Each element has **2 subclasses**.
- Each run, the player chooses **one class subclass and one element subclass** at milestones.
- Each subclass adds roughly **up to 10 unique cards** plus **one unique passive**.

### Examples (placeholders, to be refined)
| Source | Subclass | Concept |
|---|---|---|
| Rogue | Assassin | Burst single target. Passive: bonus damage from behind and/or crit damage |
| Rogue | Thief | Steal cards, extra gold. Passive: reduced Utility card cooldowns |
| Rogue | Shadow | Extra stealth (may be cut to hold 2 subclasses) |
| Fire | Destruction / Calamity | AoE burn that spreads |
| Fire | Smoke | Smoke screens, utility, stealth paths |
| Fire | Phoenix | Self-healing, possible revive |
| Water | Ice | Piercing damage, more defense options |
| Water | Holy Water | Healing and regeneration |
| Wizard | Elementalist | Access to extra elements |

Subclass lists above exceed 2 per source in some cases. They are brainstorm material. Final selection is **[OPEN]**.

---

## 7. Elements, Status Effects, Resistances, and Armor

### Elements work through status effects
Rather than a full strength/weakness wheel, elements apply status effects (for example Fire: Burn, Water: Soaked/Chilled, Dark: Weakened). **[OPEN]** whether cross-element reactions exist (for example Fire + Soaked produces steam). **[PROPOSED]** consider reactions after core combat feels good.

### Enemy resistances
- Enemies can have element resistances (for example a Fire Golem highly resistant to Fire).
- Resistances apply to **elemental damage only**. (The old [PROPOSED] reasoning, that class cards should lean physical so no build is shut down, is replaced by the parity principle under Armor below.)
- **Normal enemies:** per-enemy resistances as designed, with a **cap of 50%**.
- **Elites:** 25% resistance across elements.
- **Bosses:** 35% across elements.
- **Final boss:** 50% across all elements, equal, so no element or build is singled out as unplayable.
- **Fallback:** if resistances become hard to balance, drop them and use armor points only.
- **[DIRECTOR DECISION, 2026-11-02]** The elite and boss resistance floors are confirmed, and they should stay similar to armor's cut on physical and magical damage (the parity principle below).

### Armor **[DIRECTOR DECISION, 2026-10-29]**
1. **Two mitigation channels.** Elemental damage is reduced by elemental resistance. **Non-elemental damage (`physical`, `neutral`, and any future non-elemental type) is reduced by armor.** Armor never reduces elemental damage, and resistance never reduces non-elemental damage. This covers basic light and heavy attacks and class-based attacks.
2. **Parity principle:** at every enemy tier, armor and elemental resistance give comparable mitigation, so no damage source is a safe or superior choice against elites and bosses. Otherwise everyone would build class, single-target and heavy attacks instead of their chosen element.
3. **Formula (hyperbolic, diminishing returns):** `damage_taken = raw * K / (K + armor)`, i.e. `reduction = armor / (armor + K)`. It never reaches 100%; the reduction is 50% when armor = K.
4. **K is one data value.** [PROPOSED] K = 50 (hits are small, about 5-16, so armor numbers stay small and readable).
5. **Tier targets:** armor = K * r / (1 - r) for target reduction r. With K = 50: elites about 17 (25%), bosses about 27 (35%), final boss 50 (50%). Armor points are stored in data as designer numbers, with a test that proves parity with the tier's resistance.
6. **Hard cap:** `armor_reduction_cap` in data ([PROPOSED] 0.5, matching the resistance cap), so stacked armor modifiers can't exceed it.
7. **Normal enemies:** armor 0 by default; an optional per-enemy `armor` in data.
8. **Penetration (plumbing only):** armor is read through the stat-modifier system, and an `armor_penetration` stat (flat, subtracted before the formula, floored at 0) lets future passives and gear reduce enemy armor. No content uses it yet.
9. **Player armor (plumbing only):** the player has the same armor stat (default 0) so gear and passives can grant it later; enemy non-elemental attacks go through it.
10. **Damage over time:** non-elemental ticks (Bleed) are mitigated by armor on each tick; Burn is elemental and goes through resistance. [PROPOSED] No minimum-damage floor beyond the existing behaviour, unless tiny ticks round to zero (then a minimum goes in data and is logged).

---

## 8. Meta-Progression (between runs)

- **Passive skill trees** in the style of Path of Exile: one tree per class and one per element. Players grow stronger in the classes and elements they play, and tune them to a playstyle. **[DECIDED, non-negotiable]** This is the main source of excitement between runs and anticipation for the next run.
- **Equipment and loot** gathered between and during runs, with depth modeled loosely on Tower of Babel: Survivors of Chaos. Equipment can modify slot cooldowns and card behavior.
- **[OPEN]** what currency or XP earns passive points, and how fast.
- **[PROPOSED]** start each tree small (30 to 40 nodes) for the vertical slice, and design the tree format as data so it can grow.
- **Passive choices belong to loadouts [DIRECTOR DECISION, 2026-11-02]:** passive-tree allocations are linked to loadouts (§9), so each saved loadout can carry its own passive build. Until the tree exists, a loadout only reserves an empty, versioned `passive_allocation` field.
- **Respec is cheap, preferably free [DIRECTOR DECISION, 2026-11-02]:** respeccing passive choices is available between runs, so a player who went deep into the tree can switch completely with no penalty. Because it is free, loadouts with their own allocations are the natural way to hold several builds.

---

## 9. Run Structure

### Bosses **[DIRECTOR DECISION, 2026-10-29] (D16 = B)**
- At each phase threshold the boss **staggers briefly**. The stagger **interrupts its current attack or action**. The length is a data value.

- **Run length [DIRECTOR DECISION, 2026-10-30]:** a full run is **at least 10 rooms** (stages).
- **Three acts, 30 rooms [DIRECTOR DECISION, 2026-11-04] (with D32 = A):** a run is **three acts of 10 rooms (30 rooms)**. **Acts 1 and 2 end in a mini-boss; act 3 ends in the final boss.** In the director's words, games like these typically expect about a **30-45 minute** commitment per run, and the player is **allowed to save progress and return later**. Built in MAP3 (`docs/MAP.md` §1, §4.5, §8); until then a run is one 10-room act.
- **Each mini-boss and act has its own identity [DIRECTOR DECISION, 2026-11-09] (D44 = C):** the mini-bosses especially get **their own attacks and behaviours**, not a bigger copy of an existing enemy. The director's example: one mini-boss is **smaller, with less HP than the others, but quicker and hits harder, in a rogue style**. Each act also gets **visible changes** (for example a floor and light tint per act). This replaces MAP3's "existing enemies, no new AI" mini-boss. Built in slice MB1 (ROADMAP).
- **A partial heal at each act's start [DIRECTOR DECISION, 2026-11-09] (D45 = B):** at the start of acts 2 and 3 the player heals part of their max HP (starting value 30%, a data value). The director wants it **easy to change back** if runs get too easy: setting the value to 0 restores "HP carries over". Rejected: no heal (A) and a full heal (C).
- **Difficulty tiers [DIRECTOR DECISION, 2026-10-30]:** today's tuning is the **lowest tier ("Easy")**. Later tiers add more challenge: working names Normal, Hard, and a top tier such as "Torment". The names are not set; better ones that fit the cheerful-world, weary-hero tone are welcome. Tiers are data multipliers picked at run start. (game-lead, 2026-10-30: so the base game isn't retuned harder now; challenge comes from the tiers.)
- **Pressure pass on the base game [DIRECTOR DECISION, 2026-11-02]:** the one deliberate exception to "don't retune the base game until the tiers exist". The Wizard never seems to take damage, and a no-card run was won (§3). Raise all enemy movement speed slightly, at least until Wizard runs take some damage; if speed alone isn't enough, follow up with attack speed. The pace could be a bit faster. The change sits behind shared data knobs (an enemy speed scale and an enemy attack-rate scale) that the future tiers reuse. Player stats, card numbers and boss mechanics are not changed by it. (Scheduled as slice H1.)
- Target run length: **30 to 45 minutes [DIRECTOR DECISION, 2026-11-04]** (was 30 to 60, with a [PROPOSED] 15-25 minute prototype; today's one-act runs are the prototype length until MAP3).
- Procedurally generated room sequence with elites, bosses, and a final boss.
- **Rest-room heal [DIRECTOR DECISION, 2026-11-02]:** 30% of max HP is fine for now. It may be removed entirely later, because the player already has their own healing (the Recovery slot), which most roguelites don't allow outside between-stage rewards. **Director note, 2026-11-03 (with D30 = A):** the director repeated that the rest-room heal may be removed altogether, for the same reason (a rest choice of heal vs a relic would always go to the relic). **[DIRECTOR DECISION, 2026-11-04] (D31 = A):** keep the rest stop as it is: heal 30% or remove a card.
- **Branching map [DIRECTOR DECISION, 2026-11-02]:** wanted soon, for the traditional roguelite feel. The run becomes a map of routes with choices such as:
  - a merchant stop;
  - curse/buff rooms (usually both at once; some rooms only buff);
  - harder rooms and mini-bosses that give better loot, rewards and XP.

  The most rewarding path (most gold, XP and points to spend between runs) tends to be the most difficult. **[OPEN]** node types, how many choices per step, and the map layout. Gold, XP and between-run points don't exist yet (§8). Today's run is a straight line of 10 rooms.
  - **[DIRECTOR DECISION, 2026-11-02] (D28 = A):** a map design doc (MAP0, docs only) comes first, and the first map build comes after BD1 and BD2 and before loadouts (3d). The map must include the merchant (relics bought with gold, several at once) and a dedicated relic stage (D22, §4a).
  - **Map plan [PROPOSED] (MAP0, 2026-11-03; full plan in `docs/MAP.md`):** a grid of 10 rooms by 4 columns, read left to right, the whole map visible. Every path is exactly 10 rooms: rooms 1-2 combat, room 10 the boss, and at least 6 fights on any path. From each node you go to 1-3 nodes in the next room, mostly 2. Node types: combat, elite (a relic), relic stage, rest, merchant (several relics at once, cards, card removal), and later mini-boss, curse room (a strong relic with a curse) and buff room. Gold is earned per fight (combat 12-18, elite 30-40, mini-boss 45-55) and lasts for the run; relic prices come from rarity (60/90/130). A relic-hunting route reaches 6-8 relics but only about 3 card offers; a route that ignores relics ends with 2-3 relics and about 7 card offers. XP and between-run points are reserved only (§8 is open). The seeded generator checks these rules on every path. Built as MAP1 (map, gold), MAP2 (merchant), MAP3 (mini-bosses, curse/buff rooms). **Director answers 2026-11-04:** D31 = A (rest: heal 30% or remove a card); D32 = A (4 lanes, whole map visible), with three acts of 10 rooms as above; **D33 = B: mini-bosses and curse/buff rooms come before loadouts (3d)**, as MAP3 (acts, mini-bosses, save/resume) and MAP4 (curse/buff rooms). **Director answers 2026-11-04:** D34 = C (relics grow with the run, hard cap 20, swap at the cap, no duplicates, mini-bosses give gold and a rare card offer; §4a), D35 = A (3 rejects per run, below).  - **A rest on every route [DIRECTOR DECISION, 2026-11-06] (D40 = A):** every path from room 1 to the boss has at least 1 rest (map path rule `min_rest` 1; the limit of 2 stays). Rejected: no guarantee (B), and a fixed rest on room 9 (C).
  - **No merchant guarantee [DIRECTOR DECISION, 2026-11-06] (D42 = A):** a route may pass no merchant. Skipping it is part of the route choice, and from MAP3 gold carries over to the next act. Rejected: a merchant on every route in rooms 4-8 (B).

### Starting decks and loadouts **[DECIDED]**
- The very first run uses preset defaults: the chosen class, element, and neutral starter cards.
- From the second run on, the player can tune their starting deck and save it as a **loadout**.
- **Loadouts [DIRECTOR DECISION, 2026-11-02]:**
  - A loadout screen before each run (from run 2) customises the starting deck.
  - Each class has **at least 5 loadout slots** (a data value). The player names them freely, so one class can hold, for example, "Water Rogue", "Fire Rogue", "Dark Rogue", "Dark Rogue alt". Only Fire exists today, so names are free text and the element is not enforced yet.
  - Cards that are only available later are **flagged**, so the director can plan for them. **[DIRECTOR DECISION, 2026-11-02] (D23 = A):** in the director's words, once advanced cards exist and are in your chosen loadout, you start the run with only the `starter` cards; when a stage reward (or later a merchant) offers a card from the loadout's full plan that you don't already have, an indicator says so. Every card that exists today is `starter`. Details: each card has an `availability` in data: `starter` (can go in a loadout's starting deck), `reward` (found only as a run reward) or `locked` (until an unlock condition, **[OPEN]**). The editor shows a badge on each card. A loadout may list reward-only and locked cards as a **plan** next to its starting deck, and reward screens highlight plan cards ("On your plan"). The starting deck holds only `starter` cards and obeys the deck rules (§4).
  - Each loadout reserves an empty, versioned `passive_allocation` field for the passive tree (§8).

### Card rewards during a run **[DECIDED, details open]**
- After each won room, the player is offered **3 cards** and either **picks one** or **rejects the whole offer**. **[DIRECTOR DECISION]**
- A reject token is spent only when the whole offer is declined. Each run allows only **3 rejects total**, so deck noise builds up over a run. **Card rarity [DIRECTOR DECISION, 2026-11-04]:** common, rare and legendary. Act 1 offers are common only, rare cards start appearing in act 2, and legendary cards have a chance from act 3. The act-end mini-bosses offer 3 rare (act 1) or 3 legendary (act 2) cards (§4a). **[DIRECTOR DECISION, 2026-11-04] (D35 = A):** still 3 per run over the three-act, 30-room run (about 20 card offers), not 3 per act.
- **Offer size is a data value** (default 3) so boons, passives, and gear can later raise it or add rerolls.
- **Offers lean toward your build [DIRECTOR DECISION, 2026-11-09] (D43 = B):** an unowned card that applies a status (Bleed, Burn) gets a bonus to its offer weight, and the bonus grows with how many owned cards apply that status. Cards with no status aren't affected. Picking a status brings more of it, and pruning it shrinks the lean. Rejected: no change (A), and weighting the class pool above the element pool for everyone (C). The weight values are data (`run.json` `rewards`), set in BD3a.
- Rewards and path choices can offer ways to **clean the deck** (remove or swap cards), which creates meaningful routing decisions.
- **[OPEN]** Whether shops and enemy drops also exist alongside post-battle rewards.
- Subclass choices (class and element) occur at milestone points. **[OPEN]** exact timing.

---

## 10. Vertical Slice Scope

| Area | Slice target |
|---|---|
| Classes | 2: **Rogue, Wizard** **[DECIDED]** |
| Elements | 2: **Fire, Water** **[DECIDED]** |
| Cards | 25 to 30 per class and element, 15 to 20 neutral, 6 to 7 per subclass |
| Subclasses | 2 per class and element in the slice |
| Biomes | 1 |
| Bosses | 2 to 3 plus a final boss |
| Passive trees | 1 per slice class and element, 30 to 40 nodes each |

If the slice is fun, scale outward. Scaling should be mostly data entry.

---

## 11. Presentation

- Combat feel is a code-driven priority: hit-stop, screen shake, knockback, telegraphs, particles, and easing.
- Card animations and effects use reusable **effect templates** (projectile, cone, AoE, dash, buff aura, summon) recolored and rescaled per element.
- Art and audio start as placeholders and free (CC0 or licensed) assets. Custom or generated assets come after the combat is proven fun.
- **Art style:** whatever is easiest to produce and keep consistent. Low-poly 3D is the working direction. Pixel-art-inspired looks are acceptable if cheaper.
- **Tone (leaning, not final):** satire and humor. The world is bright, vibrant, and friendly, while the heroes are weary pessimists who find saving the world a total drag (think Shikamaru from Naruto). The contrast between cheerful world and reluctant heroes is the joke engine. **[OPEN]** how far to push it.
- Story and lore: minimal flavor text only, in that voice (card names, flavor lines, boss quips).
- **Setting idea (director, 2026-11-04, not decided):** a modern corporate office instead of a fantasy world. See §15 "Corporate setting".

---

## 12. Technical Direction

- **Engine:** **Godot** **[DECIDED]** (text-based scenes, headless runs, agent-friendly). The old Unity repo is abandoned. The project starts from scratch and nothing is migrated.
- **Perspective:** 3D with a fixed isometric camera **[DECIDED]**, using low-poly style and free rigged, animated character packs where possible.
- **Data-driven cards:** every card is a data file built from composable triggers, effects, modifiers, and statuses. No per-card custom code unless unavoidable.
- **Data-driven everything else:** slot types, card pools, subclasses, passive trees, enemies, and resistances.
- **Automated QA:** unit tests for card effects, and a headless simulation harness that runs many bot runs to detect crashes and balance outliers.

---

## 13. Production Approach

The director provides top-level design direction only. Roles are defined as documents and agent definitions in the repo and run one at a time to respect usage limits: Game Lead, Gameplay Developer, QA, Art, Audio, and Story. All design, decisions, and tasks live in the repo so work can resume at any session boundary.

### Milestones
1. GDD v0.2 (this document). Engine, perspective, and slice classes and elements decided. **Done.**
2. **Combat feel prototype:** one room, one class, placeholder visuals, basic attack plus a few cards in typed slots.
3. Card system and run loop: data-driven cards, draft screen, several rooms, a boss.
4. Second class and element, subclasses, passive tree prototype, headless balance sim.
5. Art and audio pass, then friends-and-family playtest.

---

## 14. Open Questions Summary
1. Whether shops or drops exist alongside post-battle rewards. (Offer format resolved: pick 1 of 3 or reject all, see section 9. A merchant stop is wanted as a branching-map node, §9; its details are open.)
2. ~~Space dodge roll vs the Movement slot.~~ Resolved 2026-11-02 (D29 = B, §3): dodge on Space, Movement cards on Ctrl.
3. Attack split into Single and AoE for the prototype?
4. Elementalist: all elements, or pick one extra?
5. Do elemental reactions exist, and when?
6. Passive point currency and pacing.
7. Final subclass lists (2 per class and element).
8. Subclass pick timing in a run.
9. Game name. Front-runner: **Chosen, Reluctantly** (also fits the "choose your cards carefully" mechanic).
10. Final tone: how far to push the satire.
11. Card unlock conditions for `locked` cards (§9 Loadouts).
12. ~~Relic sources and how many per run; whether Burn and Bleed stack.~~ Resolved 2026-11-02 (D22 = C, D25 = A, §4a). Merchant relic prices proposed in `docs/MAP.md` §4.4 (MAP0).
13. Branching map: node types, choices per step, layout, and the reward currencies (gold, XP, between-run points) (§9). Proposed in `docs/MAP.md` (MAP0, 2026-11-03); D31-D35 answered 2026-11-04. XP and between-run points stay open with §8.

Resolved: engine (Godot), perspective (3D isometric), slice classes and elements (Rogue, Wizard, Fire, Water), card offer format (pick 1 of 3 or reject all).

---

## 15. Ideas and Parked Concepts

Nothing in this section is scheduled. **DO NOT IMPLEMENT** anything here without a director decision moving it into the main sections.

### Stealth drops enemy aggro **[PLANNED, later]**
- **[DIRECTOR DECISION, 2026-10-28]** For now, Stealth (Shadow Step) only lets the player pass through enemies. Later, stealth should also make enemies lose track of the player for its duration. That needs enemy targeting/aggro work, so plan it with the enemy AI pass.

### Slot cooldown reset effects **[IDEA, not scheduled]**
- Utility cards that force-reset another slot's cooldown, for synergy with Recovery (the slot with the longest base cooldown).
- The effect system should make a `reset_slot_cooldown` effect easy to add later. Don't build it yet.

### Free to play with cosmetics only **[IDEA, very late, only if commercialized]** (2026-11-04)
- **The suggestion:** a playtester, the director's brother, proposed offering the game free to play and charging only for cosmetics.
- **The director's view:** he isn't on board. In a single-player game, cosmetics probably sell poorly. They sell mostly in multiplayer, where players want to look the coolest in front of others.
- Noted only. §1 says Steam is a possible far-future goal, not a driver. No pricing or monetization work is planned.

### Corporate setting **[IDEA, not scheduled]** (director, 2026-11-04)
The director's words: "just an idea to note, not a hard plan yet." It's a possible art and story direction, and it would replace the fantasy world in §11's tone.
- **Premise:** you play a reluctant worker who is good at his job. The company is corrupt and is plotting something that could end the world or the economy, for example an AI takeover. Leadership won't stop pushing the product because it makes them a lot of money. Stopping it falls to you, reluctantly.
- **Tone:** everyone else is still very jolly about their jobs and roles and keeps sucking up to leadership. This keeps the existing joke engine of a cheerful world and a weary hero (§11).
- **Enemy ladder mapped to the run (§9):**
  - regular enemies: hordes of suck-ups and brain-dead "zombies", and so on;
  - elites: management-level enemies;
  - mini-bosses (end of acts 1-2): chief and VP level;
  - final boss: the CEO or chairman.
- **The run is a skyscraper (director, 2026-11-04):** you work your way up the company's office tower. The run starts on floor 1 and ends with the final boss on floor 30. You enter and leave an elevator between rooms. This matches the run's three acts of 10 rooms (§9): the mini-bosses would sit on floors 10 and 20. Open: how the branching map (MAP.md) reads in the tower, for example a choice of departments on a floor or elevator buttons for the next stop.
- **Encounters:**
  - **Friends:** like-minded skeptics, still cheerful, who give you the tools to win and shut the company down. They're merchants (§9, MAP2) and helpful random events (MAP4).
  - **Corporate loyalists:** random encounters with people who sided with the company. They give a curse (D38) or make you pay a chunk of gold.
- **Not decided:** how classes (Rogue, Wizard), elements and card names map onto office life, for example job roles. This also stays open: whether it replaces the fantasy setting or becomes one flavour of it.
- **No work starts on this** until the director decides. The art, audio and story roles stay dormant. Mechanics are unaffected: friend and loyalist encounters fit the planned merchant, event and curse systems as they are.

### Survivor-style level-up layer **[IDEA, not scheduled]**
- Inside each room the player earns XP and levels up, choosing 1 of 3 power-up options (damage, cooldown reduction, movement speed, gold or XP gain, and so on).
- Card rewards still come only at the end of a won room.
- Level-up options must never change dodge charges (see section 3).
- Enemy density stays moderate. This is not Vampire Survivors-style hordes (see the density principle in section 1).
- **[PROPOSED]** level-ups come mainly from room completion and key kills, about one or two per room.
- Power-ups are generic stat boosts and stay distinct from cards (abilities) and the passive tree.
- The Milestone 3b card reward screen should be built so it can be reused for level-up choices.
- Open questions:
  1. How do power-ups differ from passive-tree nodes, so the two do not feel redundant?
  2. How often is a level-up pause acceptable in real-time combat?
  3. Can the 3-choice screen be shared with the card reward screen?
