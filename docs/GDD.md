# LegendsCards (working title): Game Design Document (v0.2)

Status: v0.2, rebuilt from the director's design interview (2026-10-26). Engine, perspective, and slice classes and elements are now decided.
Updated 2026-10-27 with director decisions: reward offer format (section 9), density principle (section 1), light/heavy attack controls (section 3), and a parked-ideas section (section 15).
Items marked **[OPEN]** are undecided. Items marked **[PROPOSED]** are suggestions awaiting approval.
This file is the source of truth. If it is not here, it is not decided.

---

## 1. Vision

A fast, isometric action RPG where your skills are cards. Combat is live and animated like an ARPG, but each skill slot draws from a deck you build, giving the depth of a deck-builder with the pace of real-time combat. Characters combine a **class** and an **element** (for example Fire Rogue, Dark Rogue), and runs are short, randomly generated roguelite sessions backed by deep between-run progression.

Passion project. Targets: playable by the director, fiancee, family, and friends. Steam is a possible far-future goal, not a driver.

### Pillars (non-negotiables, in priority order)
1. **Deep theorycrafting.** Class + element combinations, subclass choices, passives, and equipment must create real build decisions.
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
- **Card slots:** keys 1 to 5.
- **Hold-to-preview casting [DIRECTOR DECISION, 2026-10-28]:** by default, holding a card's key shows its exact hit area on the ground (drawn from the same data as the hitbox), and the card casts on release. A setting switches casting to trigger on press instead.
- **Dodge roll:** Space bar. **[OPEN]** how this relates to the Movement slot (see section 4).
  - **[DIRECTOR DECISION, 2026-10-28]** The dodge is a modest escape, about 5 m, and may be lowered later. Its distance must stay easy to tune (data). Critical survival manoeuvres should come from Movement cards, not the dodge.
  - **[DIRECTOR DECISION, 2026-10-29]** The dodge has **charges**: start with 3 (may drop to 2; data value). Each charge recharges on a slightly longer cooldown than the old single-dodge cooldown (0.8 s). The HUD must show the dodge charges and their cooldown.
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
- **[DIRECTOR DECISION, 2026-10-28]** Neutral cards use the neutral colour palette, not the owner's element colour.
- **Temporary testing default:** for the prototype, the preset first-run deck contains every available Fire Rogue card (class, element, neutral). Unlock and tuning rules come with the run loop.

### Open items
- **[OPEN]** Does Space dodge roll replace the Movement slot's basic function, or is the Movement slot only for special movement cards (blink, charge, leap)? **[PROPOSED]** dodge roll is a universal, always-available action with its own short cooldown; Movement cards are special movement abilities.
- ~~**[OPEN]** What happens when a mini-deck runs out?~~ Resolved: a shuffle bag with no back-to-back repeat across reshuffles (see Cycling rules).

---

## 5. Classes, Elements, and Card Pools

### Classes (initial list; more later)
Rogue, Wizard, Knight, Barbarian, Archer, Priest.

### Elements
Fire, Water, Earth, Wind, Light, Dark. Others may be added.

### Character creation
Pick one **class** and one **element** (for example Fire Rogue).

### Wizard moved earlier **[DIRECTOR DECISION, 2026-10-29]**
- The **Wizard** is added now, ahead of Milestone 4, as a ranged class: its **light and heavy attacks are ranged** and aimed at the reticle. Reason: an outside playtester expected left click to hit distant enemies under the reticle, and found the Rogue's melee swing confusing. Water and the subclasses stay in Milestone 4.

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

---

## 9. Run Structure

### Bosses **[DIRECTOR DECISION, 2026-10-29] (D16 = B)**
- At each phase threshold the boss **staggers briefly**. The stagger **interrupts its current attack or action**. The length is a data value.

- Target run length: 30 to 60 minutes. **[PROPOSED]** prototype shorter runs (15 to 25 minutes) for faster iteration.
- Procedurally generated room sequence with elites, bosses, and a final boss.
### Starting decks and loadouts **[DECIDED]**
- The very first run uses preset defaults: the chosen class, element, and neutral starter cards.
- From the second run on, the player can tune their starting deck and save it as a **loadout**.

### Card rewards during a run **[DECIDED, details open]**
- After each won room, the player is offered **3 cards** and either **picks one** or **rejects the whole offer**. **[DIRECTOR DECISION]**
- A reject token is spent only when the whole offer is declined. Each run allows only **3 rejects total**, so deck noise builds up over a run.
- **Offer size is a data value** (default 3) so boons, passives, and gear can later raise it or add rerolls.
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
1. Whether shops or drops exist alongside post-battle rewards. (Offer format resolved: pick 1 of 3 or reject all, see section 9.)
2. Space dodge roll vs the Movement slot.
3. Attack split into Single and AoE for the prototype?
4. Elementalist: all elements, or pick one extra?
5. Do elemental reactions exist, and when?
6. Passive point currency and pacing.
7. Final subclass lists (2 per class and element).
8. Subclass pick timing in a run.
9. Game name. Front-runner: **Chosen, Reluctantly** (also fits the "choose your cards carefully" mechanic).
10. Final tone: how far to push the satire.

Resolved: engine (Godot), perspective (3D isometric), slice classes and elements (Rogue, Wizard, Fire, Water), card offer format (pick 1 of 3 or reject all).

---

## 15. Ideas and Parked Concepts

Nothing in this section is scheduled. **DO NOT IMPLEMENT** anything here without a director decision moving it into the main sections.

### Stealth drops enemy aggro **[PLANNED, later]**
- **[DIRECTOR DECISION, 2026-10-28]** For now, Stealth (Shadow Step) only lets the player pass through enemies. Later, stealth should also make enemies lose track of the player for its duration. That needs enemy targeting/aggro work, so plan it with the enemy AI pass.

### Slot cooldown reset effects **[IDEA, not scheduled]**
- Utility cards that force-reset another slot's cooldown, for synergy with Recovery (the slot with the longest base cooldown).
- The effect system should make a `reset_slot_cooldown` effect easy to add later. Don't build it yet.

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
