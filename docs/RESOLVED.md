# Resolved items

The archive of the director's answered, received and acknowledged items, moved here from `docs/OPEN_ITEMS.md`. Owned by tech-writer (director, 2026-11-02). Newest dated section first; IDs (D19, call 16, checklist item 33) are kept so they can be searched. Old entries change only to fix a factual error.

## 2026-11-05

### Feedback recorded in fe10173 (item 49, general part; the old "Try the relics (BD2)" item)

The old item 49 text is in `git show 9cde725:docs/OPEN_ITEMS.md`. The trimmed item 49 stays in OPEN_ITEMS with its two specific questions (the relic room on room 9, and whether Spite Knuckles' "every 4th light hit" count carries over between rooms); those are not archived here.

| Item | What it asked | Your reply | Where it went |
|---|---|---|---|
| 49 (general part) | Try the relics (BD2): do relics change how you play, or are they silent numbers? Can you tell which relic did an explosion? | General feedback, 2026-11-05: "Relics feel fun so far, builds are starting to get more exciting and strategy starting to fold in." | DECISIONS "MAP1 relic nodes on rooms 3-8" (recorded as feedback, not a decision); `docs/CHANGELOG.md` 2026-11-05 as a human-playtest note. He did not answer the two sub-questions separately; MAP1 ux built the playtester's requested relic cue (a floating name and ring at the trigger point) anyway. |

## 2026-11-04

### Answer recorded in a4802ab (D39)

Removed from OPEN_ITEMS after commit 7503569; the full question text is in `git show 7503569:docs/OPEN_ITEMS.md`.

| ID | Question | Your answer | Where it went |
|---|---|---|---|
| D39 | Does the dodge roll (Space) count as a Movement cast for card combos ("if you used Movement in the last 2 s")? **A** (default, what was built): no, only Movement cards (Ctrl) count; the dodge stays a pure escape. **B**: yes, every dodge also sets up the combo. | **A**. | GDD §4a (a4802ab); DECISIONS "BD1-A engine calls". Code: `data/player.json` `dodge.counts_as_movement_cast` is false; flipping it to true gives B, in one place (`CombatEventsRelay.notify_dodge`). |

### Answers recorded in c1754cd (D37, D38)

Removed from OPEN_ITEMS after commit 863b15b; the full question text is in `git show 863b15b:docs/OPEN_ITEMS.md`. Neither is needed before MAP4.

| ID | Question | Your answer | Where it went |
|---|---|---|---|
| D37 | Can a rest site give a relic through a "dig" relic (the Shovel idea)? You said in D30 that rest sites shouldn't offer "heal or a relic". **A** (default): allow it, only through the dig relic; digging replaces both the heal and the card removal at that rest. **B**: keep rest sites relic-free and drop the dig idea. | **A**. A dig relic adds a rest Dig action that replaces both heal and removal. | GDD §4a; BUILD_DEPTH §4.7/§4.8; ROADMAP MAP4; DECISIONS "Applying D37 = A, D38 = A". |
| D38 | What is a curse? **A** (default): curse **cards**, a useless or harmful card shuffled into one slot's mini-deck that you dead-card swap past; removed like any card; they don't count toward slot minimums. **B**: curse relics, a downside-only relic outside the cap of 20. | **A**. Curses are cards you swap past; they don't count toward slot minimums and are removed like any card. | GDD §4a; BUILD_DEPTH §4.2/§4.6/§4.7/§4.8; ROADMAP MAP4; DECISIONS "Applying D37 = A, D38 = A" (curse cards carry a `curse` flag, are never offered, and `can_remove` always allows removing them). |

### Replies recorded in dc53d29 (items 39, 40, 41 and 42)

Removed from OPEN_ITEMS after commit 648dbd4; the full text is in `git show 648dbd4:docs/OPEN_ITEMS.md`. He numbered them 43-46 in his reply (his 43 = item 41, 44 = 40, 45 = 39, 46 = 35). His reply on item 35 was "not played yet, he may circle back", so item 35 stays active.

| Item | What it asked | Your reply | Where it went |
|---|---|---|---|
| 42 | My reading of D34 = C: do "later tiers" mean acts 2-3 (not difficulty tiers), and is the relic count target right? | Confirmed "tiers" means acts 2-3, then revised D34. **Relic tiers are 1/2/3/boss, with odds rising per act.** Elites always give a relic and never cards. Act-end mini-bosses are the only source of boss-tier relics (2 per run); act 1's mini-boss also offers 3 rare cards, act 2's 3 legendary cards. Rare cards come from act 2, legendary from act 3. | GDD §4a/§9; MAP.md §2/§4.4/§4.5/§10; BUILD_DEPTH §4.1/§4.2/§4.6/§11; ROADMAP (BD2 gets the relic tier values; MAP3 gets rarity and boss relics, with a possible MAP3b split); DECISIONS "Applying the director's revised relic and card tiers". My numbers for it became item 47, still active. |
| 41 | Knockback is shorter now (PL3 bug fix); say if hits feel too soft or any PL3 visual reads badly. | "Knockback fix good": he "always found it strange to be flung across the room". | Recorded as acknowledged; no change. |
| 40 | H3 and H1 pace, the Wizard side: does the 1-dodge Wizard get time to react to the boss's Fan of regrets? | The 1-dodge Wizard "still seemed fine". | Recorded as acknowledged; no change. |
| 39 | H1 boss length: the Rogue's boss fight runs about 6 s longer (about 66 s). Fine? | Boss length is fine. | Recorded as acknowledged; no change. |

### Answers recorded in 96802ba (D34, D35, D36)

Removed from OPEN_ITEMS after commit 81ff8e4; the full question text is in `git show 81ff8e4:docs/OPEN_ITEMS.md`.

| ID | Question | Your answer | Where it went |
|---|---|---|---|
| D34 | How many relics over a 30-room run? **A** (default): keep 6-8 per run, cap 10; relics get scarcer per act and mini-bosses give no relic. **B**: let it grow with the run, about 15-20 for a hunter, cap about 25, and mini-bosses give a relic. | **C**, his own option: relics grow with the run, a hard cap of 20 that is hard to reach, a swap at the cap, no duplicates. Mini-bosses always give gold and a rare card offer; elites in later acts a smaller chance of a rare card offer too (this last part was replaced when he answered item 42: elites give relics only). | GDD §4a/§5/§9/§14; MAP.md §2/§4.4/§4.5/§10; BUILD_DEPTH §4.1/§11; ROADMAP BD2/MAP2/MAP3 (BD2 builds the at-cap swap, cap 20); DECISIONS "Applying D34 = C, D35 = A, D36 = A". |
| D35 | How many card rejects over a 30-room run? **A** (default): still 3 per run. **B**: 3 per act (9 per run). | **A**: 3 rejects per run. | Same places as D34 (GDD §4a/§5/§9/§14, MAP.md, ROADMAP, DECISIONS "Applying D34 = C, D35 = A, D36 = A"). |
| D36 | The boss volley up close, for the Wizard. **A** (default): leave it; up close is the risky place and the dodge is the answer. **B**: the boss only uses the volley from at least 8 m. **C**: widen the spread so a gap exists up close. | **A**: the volley stays. | DECISIONS (same entry): PL3 item 13 closed as "the volley stays; the bot's pellet blind spot is a bot issue". No code change. |

### Answers recorded in 6c020cf (D31, D32, D33)

Removed from OPEN_ITEMS after commit 9532409; the full question text is in `git show 9532409:docs/OPEN_ITEMS.md`.

#### Decisions

| ID | Question | Your answer | Where it went |
|---|---|---|---|
| D31 | What does a rest stop offer, now that relics aren't there (D30) and you may drop the heal? **A** (default): keep heal 30% or remove a card; **B**: no heal, a rest stop is "remove a card" and rest stops get rarer; **C**: no rest stops, card removal only at the merchant. | **A**. | GDD §9; MAP.md; BUILD_DEPTH §4.1; ROADMAP (6c020cf). |
| D32 | Map shape. **A** (default): 4 lanes, mostly 2 choices per step, whole map visible, left to right, every route 10 rooms; **B**: 3 lanes; **C**: only the next 2 rooms visible. | **A**, plus: a run becomes three acts of 10 rooms (30 rooms). Acts 1 and 2 end in a mini-boss, act 3 in the final boss. Target run length 30-45 min (was 30-60 min). Save progress and return later (autosave between rooms, built in MAP3). Until MAP3 a run is one 10-room act. | GDD §9; MAP.md; BUILD_DEPTH §4.1; ROADMAP (6c020cf). New questions D34 (relics over 30 rooms), D35 (rejects over 30 rooms), D36 (boss volley up close for the Wizard) are active in OPEN_ITEMS. |
| D33 | When do mini-bosses and curse/buff rooms come? **A** (default): after loadouts (3d), before BD3; **B**: before loadouts, straight after the merchant; **C**: after BD3. | **B**. Slices are now MAP3 (three acts, mini-bosses, act scaling, save/resume) and MAP4 (curse/buff rooms). Run order: PL3 -> BD1 -> BD2 -> MAP1 -> MAP2 -> MAP3 -> MAP4 -> 3d -> BD3. | GDD §9; MAP.md; ROADMAP (6c020cf). |

## 2026-11-03

### Answer recorded in 98efccd (D30)

Removed from OPEN_ITEMS in 0cf2a09. The full question text is in `git show b332971:docs/OPEN_ITEMS.md`.

#### Decisions

| ID | Question | Your answer | Where it went |
|---|---|---|---|
| D30 | Do rest rooms and card reward screens still offer relics? Options: **A** (my default): no, only the merchant, the relic stage and elites; **B**: keep the rest-room heal-or-relic as a fourth source; **C**: keep both the rest-room choice and an occasional relic on a card reward screen. | **A**. Reason: heal-or-relic is too obvious a choice, and Recovery already heals. The rest-room heal may be removed altogether; MAP0 will propose. | GDD §4a and §9 (note); BUILD_DEPTH §4.1 and §11; ROADMAP BD2 and MAP0 (98efccd). |

## 2026-11-02

### Answers recorded in c475c58 (D22, D24, D25, D26, D28, D29; checklist items 40-42; what's-new notes)

Removed from OPEN_ITEMS in c475c58. Their full original text is in the parent commit: `git show c065762:docs/OPEN_ITEMS.md`.

#### Decisions

| ID | Your answer | Where it went |
|---|---|---|
| D29 | **B**: the dodge is back. Rogue 2 charges, Wizard 1, dodge on Space, Movement on Ctrl; enemy attacks and the volley a little faster. Its two sub-questions (win rate on Easy; Movement cooldowns) are moot now that the dodge is back. | GDD §3 and §5; ROADMAP H3. |
| D28 | **A**: MAP0 design doc first, then the first map build after BD2 and before 3d. | GDD §9; ROADMAP. |
| D26 | **A**: fixed menu keys (Enter, arrows, class-pick 1/2) may be named on screen; gameplay keys still come from the bindings. | GDD §3. |
| D25 | **A**, plus passive nodes: Burn and Bleed don't stack in the base game; stacking comes only from relics, keystone cards and potential passive-tree nodes. | GDD §4a; BUILD_DEPTH §3.4. |
| D24 | **A**: relics in their own slice BD2, after BD1 and before 3d. | GDD §4a; ROADMAP. |
| D22 | **C**: a relic-hunting player can reach about 6-8 relics per run, hard cap 10. Sources: a merchant (buy several at once with gold), a dedicated relic stage, and elites. | GDD §4a; BUILD_DEPTH §4.1. |

#### Needs-your-eyes items
- **40** (H2 with cards, no dodge): answered by D29. The game felt less fluid and fun but was very winnable, and the Rogue had no trouble.
- **41** (H2 no cards, no dodge): retired, superseded by H3, whose close will ask about a no-card run again.
- **42** (H2 keys Space/F): superseded. Movement moves to Ctrl; Utility stays on F.

#### "What's new" notes
- H2 and BD0 notes: played and read. The director answered BD0's questions (D22, D24, D25).

### H1 "What's new" note acknowledged

You played the H1 build (enemies +25% speed) before H2. The note from OPEN_ITEMS ("What's new since you last played"): "**H1 (tag `playtest-2026-11-02-H1`):** every normal and elite enemy is 25% faster (chaser 5.0 against your walk of 6.0), and attack speed is unchanged. The boss's own speed is unchanged, but its adds are faster. You've already played this build; your answer (with cards good, no cards still winnable) is what started H2." game-lead removes it from OPEN_ITEMS at close.


Source: the director's OPEN_ITEMS pass, verbatim in `docs/playtests/2026-11-02-director-open-items-pass.md` (recorded in commit 3befb9d). game-lead's readings are in `docs/DECISIONS.md` ("2026-11-02 - Director's OPEN_ITEMS pass").

### Process request: RESOLVED.md

He said: "I thought OPEN_ITEM.md would literally just be the active open items but now the doc is getting rather large, so can all resolved / received input / acknowledged by director items on that get moved to RESOLVED.md instead and keep that process going forward as well. That way when I open OPEN_ITEMS.md it's always easy to see exactly what currently needs input on." Tech-writer owns RESOLVED.md. **Recorded** in `CLAUDE.md` (Doc ownership). This file is the result: everything resolved up to the 3befb9d version of OPEN_ITEMS is below.

### Decisions (D19, D20, D21, D23, D27)

| ID | Question | Your answer | Where it went |
|---|---|---|---|
| D19 | The dodge right after a movement card ends inside an enemy: may a dodge in that short ghost window pass through enemies? | **A**, keep it. | GDD section 3 (a dodge in the post-dash ghost window may pass through enemies). |
| D20 | Wizard HP: 26 (no one-shot from full) or squishier? | **B**, 22 HP: "a player realistically shouldn't be hit by a full volley, only partial, and if they do that's their fault and deserve to die". | GDD section 5. Wizard HP 26 -> 22, built in H2. |
| D21 | Run order: housekeeping in PL3 after BD0, or only the housekeeping now? | **B**: housekeeping before H2, rest of PL3 unchanged. | Done: `docs/.gdignore` (642d546), `.uid` files tracked (c3f5ac1), `.gitattributes` extended (98595d4). |
| D23 | What "flag cards that are only available later" means for loadouts. | **A**: every current card is `starter`. He added: "so far no advanced 'high-level' cards exist, but once they do and they are in your chosen loadout, you will only start the run with the 'starter' cards and when a stage rewards (and or eventually a merchant) offers a card that was in your original full-deck loadout that you don't already have, it would let you know with some indicator". | GDD section 9; built in 3d. |
| D27 | Enemy attack speed, and what to try if the Wizard still doesn't bite (from H1). | **Not answered directly; read as A by game-lead** (speed +25%, attack speed unchanged), because he said "Wizard with cards is good" (item 33) and named his own next lever, the dodge-off trial (item 34). Stated so he can object. | `docs/DECISIONS.md` (D27 read as A). |

### Calls 1-16 (calls game-lead made)

Each row: the call as written in OPEN_ITEMS, then his one-line answer.

| # | Call | His answer |
|---|---|---|
| 1 | Enemies are solid to you (from C1). | "Solid enemies, good." |
| 2 | Runs are a straight line of rooms, no branching map yet. | Wants branching maps "if it's already available, start giving that traditional roguelite feel sooner": Merchant stop, Curses/Buffs (typically simultaneously, some rooms only Buff), enemy difficulty and mini bosses for better loot, rewards and XP. "The most rewarding run that gains the most gold, XP, points to spend between runs etc, tends to be the most difficult path taken." Recorded in GDD section 9; when to build it is D28 (open). |
| 3 | Runs are 10 rooms: 7 combat, 1 elite, 1 rest, boss last. | "Good with 10 stages for now." |
| 4 | The rest room heals 30% of max HP. | "30% heal OK (may eventually remove this completely since the player already has their own means of healing which most roguelites don't allow easily besides the between stages rewards)." Kept for now. |
| 5 | Elite enemies resist every element at least 25%. | "Elite resis good." |
| 6 | The starting deck is 15 cards, 3 per slot. | "Starting deck is good." |
| 7 | Three rejects per run; starter is exactly 3 per slot. | "3 rejects good." |
| 8 | A normal launch starts a run; scenarios and the wave sim keep the endless arena. | "Normal launch good." |
| 9 | Armor formula (armor / (armor + 50), capped at 50%). | "Armor formula feels good." |
| 10 | Elite and boss HP cut to keep fight lengths. | "Elite & boss HP good for now, may change as builds get stronger." |
| 11 | Boss-tier resistance floor 25% -> 35%. | "Resis floor good, should be similar to armor on physical/magical damage." Floors confirmed. |
| 12 | Damage over time: Bleed through armor, Burn through resistance, heals never reduced. | "DoT mechanics good." |
| 13 | A build with no damage cards (superseded 2026-11-02). | "Good, no-card runs shouldn't be easy to complete, regardless of duration." |
| 14 | Wizard Recovery 14 s vs the Rogue's 12 s. | "Recovery time good." |
| 15 | Run order: F1 and P-dodge before W1b. | "Order good." |
| 16 | Menu number keys pick by position (K1). | "Can drop the number keys on the reward screens, mouse selection is sufficient, so no clash." Reward and removal screens drop their number keys; mouse, arrows and Enter remain. Built in PL3. |

### Play-session checklist answers (2026-11-02)

| # | Item | His answer | Follow-up |
|---|---|---|---|
| 22 | Loadouts (after 3d). | "Loadouts seems good." | None. |
| 25 | Frame colours (fire, bronze, grey). | "Frame colors are good." | None. |
| 26 | Highlighted grey reward card. | "Highlighted grey is good." | None. |
| 27 | Rogue melee arc. | "Rogue arc seems obvious enough." | None. |
| 28 | Dodge pips. | "Pips are good." | None. |
| 29 | Boss stagger. | "Boss stagger is a nice opening or breather." | None. |
| 30 | Key labels. | "Key labels match." | None. |
| 31 | Casting on the new keys. | "Can still hold to preview." | None. |
| 32 | Swap. | "Swap still works." | None. |
| 33 | H1 Wizard: does it bite now? | "Wizard with cards is good, without cards just takes awhile but can still win." | Led to H2. |
| 34 | H1 no cards: do you lose before the boss? | "It's taking awhile I stopped at stage 8 but felt like would eventually beat the boss with no cards or heals." | Led to H2, the dodge-off trial. He said: "I'd like to see what happens when dodge is removed entirely (keep the code plumbing around so easy to bring back on a data switch for example), and in the mean time with no dodge I'd like the movement card slot to use 'Space' instead. Which leaves utility as the last 'number' card making it awkward so change that to 'F'." Decided: dodge removed behind a data switch; Movement 2 -> Space, Utility 1 -> F. Built in H2. |
| 36 | Wizard cards. | "Wizard offers different playstyle and ward seems worthwhile." | None. |
| 37 | Wizard risk. | "Risk, got hit a handful of times, nothing too concerning, never felt like was about to die." | None. |

Item 35 (BD1 builds) is still to come and stays in OPEN_ITEMS.

### H1 outcome (for the record)

The H1 gates were met (standard runs still clear, Rogue boss time in band), but the goal was missed in his hands: a no-card Wizard still looks winnable at enemy speed x1.25, just slowly. His follow-up lever is the dodge-off trial (H2). See `docs/CHANGELOG.md` 2026-11-02 and `docs/DECISIONS.md` "2026-11-02 - H1".

## Earlier history (moved from OPEN_ITEMS.md, version at 3befb9d)

The text below is as it stood in `docs/OPEN_ITEMS.md` at commit 3befb9d, with CR bytes removed and headings demoted one level. Entries may still say "waiting" or "next"; they are history. Section order follows the original file.

### While you were away (every per-slice entry, W1a through K1)

_Updated at every slice close._

- **Latest playtest tag:** `playtest-2026-11-02-K1` (qa PASS, 1190/1190). Earlier tags: `playtest-2026-11-02-W1b`, `playtest-2026-10-30-P-dodge`, `playtest-2026-10-30-F1`, `playtest-2026-10-30-PL2`, `playtest-2026-10-30-W1a`, `playtest-2026-10-29-T-decks`, `-A1`, `-3c`, `-3b`, `-3a`, `-C1`.
- **New in K1 (since the W1b tag), from Luke's playtest and your binding change:**
  - **The screen now shows your keys:** the card strip reads **Q E 1 2 R**, the meters LMB/RMB, the dodge Space. Reward cards say "Recovery (R) now: ...", the remove screen's columns say "Utility (1)", "Movement (2)", and the pause screen says "Escape also resumes".
  - **Recovery moved from 3 to R** (Shift+R swaps it). Movement stays on 2; moving it to F is a one-line edit in `data/input_bindings.json`.
  - **Bug fixed:** pressing Q, E or R behind an open reward panel could cast a card. The panel now blocks every card key.
  - **Playtester's notes (scripted):** you can tell which key casts which card at a glance. Two small confusions are queued for PL3: on reward screens the option number (1-4) sits near a "Key 1" chip, and on the remove screen pressing 1 jumps to the first column even though "Utility (1)" is the third. Also for PL3: mashing Space as you die might hit "Try again" on the game-over screen.
- **Try first in K1:** checklist items 30-32.
- **New in W1b (since the P-dodge tag):**
  - **Keys:** your binding change is in this tag: cards on Q, E, 1, 2, 3, and Shift + the same key swaps. The strip and prompts still *label* them 1-5; K1 fixes that and moves the last slot to R.
  - **4 Wizard cards:** a bolt volley ("Three Bolts, Reluctantly"), a heavy bolt ("Overqualified Bolt"), a nova ("Personal Space, Enforced") and a ward ("Ward, Technically": +25 armor for 4 s). The Wizard's starting deck is rebuilt around them, with no melee cards.
  - **Wizard tuning:** light bolt 2.4 -> 1.5, heavy 8.5 -> 5.5, card numbers trimmed, Ward 6 -> 4 s. HP stays 26, so one full boss volley (25) can't kill you from full. Whether that's "squishier" enough is **D20**.
  - **Test presets:** `--deck=fire-heavy-wizard`, `mixed-wizard` and `arcane-heavy-wizard`.
  - **Playtester's notes (bot):** the caster cards make the Wizard play differently. A Wizard who kites spends rooms 1-9 nearly unhurt, so the boss is the only threat; H1 (harder enemies) is the fix. The Fan of regrets is fair but its lanes run off screen (PL3).
- **Try first in W1b:** checklist items 36-37.
- **New in P-dodge (since the F1 tag):**
  - **Dodge charges:** Rogue 3, Wizard 2, each recharging in 1.2 s, shown as pips under the attack meters (with an EMPTY state).
  - **Recovery cooldown 12 s** (your D13); the Wizard's is 14 s.
  - **The boss staggers** at each phase change (your D16): it reels for 0.8 s, its attack is cancelled, the bar says STAGGERED / "Hit it now", and your hits count. It can't skip phase 3.
  - The rare "flung into the air" bug is fixed. The stress-test flake was a test mistake, not an invulnerability bug.
- **Try first in P-dodge:** checklist items 28-29, and fight the boss with each class. **Playtester's notes (bot and stills):** the pips read but sit away from your eyes; the stagger reads as a reward; the Wizard's boss deaths come from back-to-back "Fan of regrets" volleys (W1b looks at this).
- **New in F1 (since the PL2 tag), your checklist answers:**
  - **Runs are 10 rooms** (7 fights, 1 elite, 1 rest, boss in room 10: `--run-room=10`).
  - **Wall of Mild Fire is 1.5x** (7.5 x 1.8 m).
  - **Every Movement card goes through enemies;** the dodge doesn't (see D19 for one edge case). Reluctant Lunge now hits everything on its line.
  - **Dead-card swap is Shift+1-5.**
  - The boss's head clears the top-left meter; the reward focus ring has no notch; dashes no longer flash the ghost look.
- **Try first in F1:** a full 10-room run; dash out of a crowd with each movement card; drop a Wall in front of walking enemies. **Playtester's notes (stills and bot only):** the Wizard is safe until the boss, which can kill it fast (W1b fixes this); a bot clears 10 rooms in about 5 minutes.
- **New in PL2 (since the W1a tag):**
  - **Card frames in your colours:** Fire orange, class cards light bronze (Rogue and Wizard alike), neutral grey, on the card slots, reward offers and the rest-room removal list. "Ready" is now shown by a bright plate and green bar instead of the border, so the frame always keeps its colour. The card strip is 8 px taller.
  - **The boss starts fully on screen** in room 8.
  - **Rogue melee cue:** a faint pale-blue arc at light-attack reach, only when nothing is in range; it flashes when you click and miss.
  - The class pick screen no longer shows the old HUD behind it. A bad `--class` / `--deck` prints one clean "Launch refused" line.
- **Try first in PL2:** checklist items 25-27. **Playtester's notes (stills only):** the three frame colours read as three families without labels; bronze vs grey is the closest pair; the melee arc may read as "range" more than "swing".
- **New in W1a (since the T-decks tag), your "add the mage sooner" request:**
  - Every run starts with a **class pick**: Rogue or Wizard. 1/2 or the arrows choose, Enter starts, and your last pick is preselected.
  - The **Wizard** has 26 HP and a purple body.
    - Its left click is an auto-firing cyan bolt that flies where you aim (12 m, about 80% of the Rogue's damage).
    - Its right click is a blast at the reticle; the meter says CAST.
  - It has 4 cards of its own, 2 cooldown buffs and 2 escape blinks. Its attack cards come in W1b, so for now its attack slots are Fire and Neutral cards.
  - Launch straight in with `godot --path . -- --class=wizard`.
- **Try first in W1a:** checklist item 24. **Playtester's notes (scripted, no hands):** the pick screen answers your fiancée's confusion directly ("Melee. Hits what is in front of it, up close" vs "Ranged. Fires a bolt at the cursor"). The bolt reads clearly. In the bot sim the Wizard is safe: about 77% of the Rogue's boss time, and it ends almost every room at full HP (see D18). Some starter cards sound melee (Pointy Stick); W1b replaces them with caster cards.
- **New in T-decks (since the A1 tag), your preset-deck request:** `--deck=<name>` and `--list-decks`, with three Rogue presets (fire-heavy, physical, mixed). See "How to playtest" above. `physical-rogue` has to keep 2 Fire cards: without them there are only 2 Utility and 2 area cards, and each slot needs 3 different ones. A 12-seed bot re-check puts fire-heavy at 1.02x and physical at 1.07x of the standard deck's boss time, well inside your 70-130% band.
- **New in A1 (since the 3c tag), your armor request:**
  - Elites and the boss now have **armor**. It cuts physical and neutral hits about as much as their resistance cuts fire, so a fire deck and a physical deck kill the boss in similar time. In the bot sim each family lands inside your 70-130% band of the standard deck.
  - **Visible cues:**
    - the boss bar shows "Armor 50% - Resists all elements 50%";
    - elite bars have a small shield pip;
    - armor-reduced hits show as muted `[9]`, resisted hits as `<4>`;
    - F3 lists the nearest enemy's armor and resistance, plus yours.
  - To keep fights the same length, elites went from x2.5 to x2.0 HP, and the boss from 280 to 195 HP.
  - The boss bar now fits a 1024x768 window.
- **Try first in A1:** checklist item 23 (armor). Fight an elite and the boss once with fire cards and once with Slash, Lunge and the attacks. **Playtester's notes (scripted, no hands):** the cues read fine one at a time, but in a clump of 4 enemies the `[9]` / `<4>` / plain numbers blur together (queued for ux). Nothing on a card says whether it's physical or fire (D17, answered 2026-10-30: frame colours, being built in PL2).
- **New in 3c (since the 3b tag):** room 8 is a real boss, "The Overly Enthusiastic Guardian" (placeholder name). It has 3 phases with an invulnerable roar between them; smash, slam, volley and charge attacks, each telegraphed; adds in phases 2 and 3; and a boss HP bar at the top with the phase and the attack name. The room indicator moved to the top right. Reward cards show "Slot N now: A / B / C" and plain effect lines. **Your scrolling complaint is fixed:** reward offers never scroll down to 1024x600, including your 1150x680 window. Jump straight to the boss with `godot --path . -- --run-room=8`.
- **Try first in 3c:** fight the boss (checklist item 21) and answer D16 (should it ever stagger?).
- **New in 3b (since the 3a tag):** after each won fight you pick 1 of 3 cards or reject the whole offer (3 rejects per run). Rest rooms let you heal or remove a card (you can't remove one that would break the 3-per-slot rule). **Your starting deck is now 15 cards, 3 per slot;** the other 9 cards come from rewards. Launch with `-- --full-deck` to start with all 24. A "Next: Room N of 8" line shows what's coming. HP now drops across a run (the bot averages about 85% at each room's end).
- **Try first in 3b:** play one whole run (checklist items 19 and 20). Do the offers feel like real choices? Is removal being locked early (every starter card is needed for the 3-per-slot rule) annoying?
- **New in 3a (since the C1 tag):** pressing Play now starts a **run**: 8 rooms in a row (5 fights, 1 elite, 1 rest, then a boss), with "Room X of 8" and a shape for the room type at the top. Clearing a room shows a panel with Continue. Your HP carries over between rooms. There's a win screen, and Game Over now says how far you got. Elites (diamond sign) and the boss (star sign) have more HP. The boss is a stand-in until 3c. Try again starts a new run with a new seed.
- **Try first in 3a:** play one whole run (checklist item 19). Note the boss room's length and where your HP drops.
- **Built since your last session (C1):**
  - 9 new Fire Rogue cards, all in your starting deck: Slash, Then Bleed · Four Quick Stabs · Fireball, Incoming · Wall of Mild Fire · Walk Through Everyone · Reluctant Lunge · Nope, Leaping Away · Heal By Hurting · Eventual Healing.
  - New card abilities under the hood: placed fire zones, dashes that hit along the path, a backward leap, walking through enemies, bleed, regeneration, life-steal.
  - Every slot needs at least 3 different cards, and the game refuses to start a run with a deck that doesn't (F3 shows the counts).
  - **Enemies are now solid:** you can't walk or dodge through them. Walk Through Everyone and Nope, Leaping Away are your ways out. (My call; one flag to undo, see "Calls I made".)
  - New visual cues: a bleed drip, a regen ring, a life-steal bead, green "+N" heal numbers, a ghosted look while walking through enemies, a Fire Wall burn-down timer, and a range ring for placed cards.
  - Dodge is 5 m (your D8).
- **What to try first:** checklist items 12 (every new card) and 13 (solid enemies): push into a crowd for a minute, and see whether being blocked feels fair and whether the escape cards feel good.
- **Playtester's headline (scripted, no hands):** Fireball and the backward leap are the standouts. Fire Wall is weak against one enemy. Healing may be too strong for 30 HP (D13). In big crowds you can lose sight of yourself and of enemy shots.

### Your feedback in progress

- **2026-11-02: Difficulty. "The Wizard never seems to take damage. Slightly raise all enemy movement speed, at least until Wizard test runs take some damage. If speed alone is not enough, follow up with attack speed."** You also said the pace could be a bit faster. (Your note says "face"; I read it as "pace" and logged that reading.) **Recorded** in GDD §9 as your decision, as the one exception to "no retune before the tiers". **Scheduled as H1**, right after K1: enemy speed first (+10/20/25% tested), attack rate only if needed, behind shared data knobs the future tiers reuse.

- **2026-11-02: 10/31 Wizard playtest. "I beat the 10-room run as the Wizard without using a single card (no healing either), only light attacks, heavy attacks and dodging. The run took 5:25. This should not be possible, except later, once deep build mechanics exist that let a player build specifically into maximizing light and heavy attack damage."** **Recorded** in GDD §3 and in `docs/playtests/2026-10-31-director-wizard-no-cards.md`. **H1** targets it: a no-cards run should clear at most about 25% of the time on either class. BD0 sketches 5 relics for a deliberate light/heavy build. It supersedes my old call 13 below.


- **2026-11-02: Build depth (your main concern). "Card selection does not make much of a difference yet. There are not enough themes or unique features to build into. I feel behind on the theorycrafting and deep build customization pillar."** **Recorded** in GDD §1 (pillar 1) and a new GDD §4a "Build depth and synergy" (your goals as decisions, the mechanics as proposals). **Scheduled:** BD0 (my design doc, `docs/BUILD_DEPTH.md`) after H1, then BD1 (the engine and first archetypes) after PL3. Your inputs are noted in §4a: the burst-around-you AoE cards feel strongest, and the Wall felt weak before its 1.5x boost (size kept).

- **2026-11-02: "Loadouts screen before a run."** At least 5 named loadouts per class, flags on cards only available later, an empty passive-tree field per loadout. **Recorded** in GDD §9 and the 3d brief in ROADMAP. **Scheduled** last in your order, after BD1. My reading of the card flags is D23 below.

- **2026-11-02: "Relics/enchants found during a run, reset between runs."** Like Slay the Spire's relics and The Last Flame; your example: "Burns now explode in an AoE when they expire and/or on death." Leaning into them should give deep synergies or specialisations. **Recorded** in GDD §4a. **Designed in BD0**, first ones built in BD1 (your burn explosion included).

- **2026-11-02: "Respec should be cheap, preferably free."** It's available between runs, so a player who went deep can switch completely with no penalty, which makes loadouts the natural way to hold several builds. **Recorded** in GDD §8, with passive choices linked to loadouts. Nothing to build until the passive tree exists; 3d reserves the field.

- **2026-11-02: Dead-card swap "feels pointless right now because nothing makes a card worth saving."** **Recorded** in GDD §4: no change now; BD0 designs synergies that make a card worth saving.

- **2026-10-29: "No scrolling by default on the round-end reward selection."** **Fixed** in `playtest-2026-10-29-3c`. Cause: the panel's shrink-to-fit was being undone by its container. Offers now fit with no scrollbar from 1024x600 up; only the rest-room removal list can scroll.

- **2026-10-29: "No cooldown indicator for the dodge; dodge should have 3 charges (maybe 2) and a slightly longer cooldown."** Recorded in GDD §3 as your decision. It's scheduled right after the boss slice closes and before loadouts. I'm setting each charge's recharge to **1.2 s** (was 0.8 s); the charge count and cooldown are both data values (`data/player.json` `dodge.charges`, `dodge.cooldown`). There will be a pip indicator near the attack meters. Also recorded: passives may raise or lower the charges as a trade-off, level-ups never touch them, and the hard limits are 0 and 4. The code gets the hook now; the passives come later.

- **2026-10-29: Armor for elites and bosses** (non-elemental damage mitigated about as much as elemental). **Built** in `playtest-2026-10-29-A1`; see "While you were away" and checklist item 23. It also answers D15 (fire against the boss), so D15 is withdrawn.

- **2026-10-29: Debug preset decks** (`--deck=<name>`, `--list-decks`, presets in `data/debug_decks/`). **Built** in `playtest-2026-10-29-T-decks`; see "How to playtest". The wave sim uses the same presets, with no rule bypass.

- **2026-10-30: checklist answers 11-24 and D18.** Recorded in GDD §3, §4, §5 and §9 and scheduled: F1 (Wall 1.5x, movement pass-through, Shift+1-5, 10 rooms), P-dodge (Wizard 2 charges, Rogue 3, Wizard Recovery 14 s), W1b (Wizard squishier, tuned to D18 = A). See the table under "Your checklist answers (2026-10-30)".

- **2026-10-30: "Card frame colours show the family"** (fire red/orange, class light bronze, neutral grey). Recorded in GDD §4 as your decision (answers D17). **In progress** in PL2; Wizard cards are class cards, so they'll be bronze too.

- **2026-10-29: "On pause, expand the active and next-up cards in every slot so I can read what they do."** Logged in ROADMAP under "Later" as unscheduled, as you said it can wait. Tell me when to schedule it.

- **2026-10-29: "Add the mage sooner, with ranged light and heavy attacks"** (your fiancée expected left click to hit where the reticle is). Recorded in GDD §5 as your decision; it replaces your earlier "don't start the Wizard" for the Wizard only, and Water stays in Milestone 4. Planned as **W1: Fire Wizard** with:
  - a class pick at run start;
  - an auto-firing bolt that flies to the reticle;
  - a targeted blast heavy;
  - 6-8 Wizard cards;
  - 26 HP.

  **Status:** **W1a built** (`playtest-2026-10-30-W1a`: class pick, ranged bolt and blast, 26 HP, 4 Wizard cards). **W1b next:** Wizard attack cards, a caster starter, Wizard presets and balance (see D18). After that: dodge charges plus D13/D16, then loadouts. Also logged: a small Rogue cue so new players can tell the light attack is melee (in W1b).

### Calls I made while you were away (easy to change)

Each entry says what I chose and the one-line way to change it.

1. **Enemies are solid to you (from C1; you confirmed it 2026-10-30).** The dodge doesn't go through bodies; from F1 every Movement card does (today only Shadow Step). **Change:** set `data/player.json` `body.collide_with_enemies` to false.
2. **Runs are a straight line of rooms (3a), no branching map yet.** Routing choices come later. **Change:** ask for a branching map (it's a generator change).
3. **Runs become 10 rooms in F1 (your call: at least 10). My mix: 7 combat, 1 elite, 1 rest, boss last** (the smallest change; harder runs come from the difficulty tiers). **Change:** edit the room counts in `data/run.json`, or say "2 elites".
4. **The rest room heals 30% of max HP.** **Change:** `data/run.json` rest heal value.
5. **Elite enemies resist every element at least 25%** (they keep their own if it's higher, e.g. the fire golem), capped at 50%, per GDD §7. **Change:** the elite resistance value in `data/run.json`.
6. **Your starting deck will shrink to 15 cards (3 per slot) in 3b,** so rewards have new cards to offer. It's the original starters plus Nope, Leaping Away (an escape) and Eventual Healing; the other 9 cards come from rewards. **Change:** edit `data/run.json` `starting_deck`. To play with every card, launch with `--full-deck` (from 3b).
7. **Three rejects per run stays fixed, and the starter is exactly 3 per slot,** so removal is locked until you own a 4th card in a slot. **Change:** add cards to `data/run.json` `starting_deck` (4 per slot unlocks early removal); rejects are `rejects_per_run`.
8. **A normal launch now starts a run; test scenarios and the wave sim keep the old endless arena.** **Change:** none needed; scenarios are for looking at one thing.
9. **Armor formula (A1).** Armor cuts damage by armor / (armor + 50), capped at 50%: elite armor 17 = 25%, boss 50 = 50%. **Change:** `data/armor.json` `k` and `armor_reduction_cap`; tier values are in `data/run.json` and `data/bosses.json` (a load check keeps armor matched to resistance).
10. **Elite and boss HP cut to keep fight lengths (A1).** Elite HP x2.5 -> x2.0; boss 280 -> 195 HP (the boss fight stays near 1 minute in the bot sim). **Change:** `data/run.json` elite `hp_multiplier`, `data/bosses.json` `max_health`.
11. **Boss-tier resistance floor 25% -> 35% (A1),** to match GDD §7's boss value and the armor. **Change:** `data/run.json` `tiers.boss.resistance_floor`.
12. **Damage over time (A1):** Bleed goes through armor, Burn through resistance, and heals are never reduced. **Change:** ask; it's a rule in the damage code.
13. ~~**A build with no damage cards (only light and heavy attacks) stays slow against the boss (about 3x).**~~ **Superseded 2026-11-02:** your no-card Wizard win on 10/31 shows slow isn't the same as losing. H1 makes no-card runs unsafe; BD0 designs the deliberate basic-attack build.
14. **Wizard Recovery 14 s vs the Rogue's 12 s** (your "slightly longer"; built in P-dodge). **Change:** the Wizard's Recovery override in data.
15. **Run order changed: F1 and P-dodge now come before W1b,** so the Wizard is tuned once, after everything that changes its risk (10 rooms, charges, Recovery). **Change:** say "W1b first".
16. **Menu number keys pick by position (K1).** On reward and remove screens, 1 is the first option or column, even where a card's own key is also a number (Utility is on 1, but it's the third column). The two clashes the playtester saw (option badge "1" next to a "Key 1" chip, and the "Utility (1)" header) get a visual fix in PL3. **Change:** ask for menu numbers to follow the card keys, or to drop the number keys on those screens.

### Your checklist answers (2026-10-30)

| # | Item | Your answer | Follow-up |
|---|---|---|---|
| 11 | Area cards vs light | Area cards should excel against groups; slightly better on one enemy is fine. | No change. |
| 12 | New cards | Feel nice. Wall of Mild Fire underperforms: enemies barely touch it. Try 1.5x size. | **F1:** length 5 -> 7.5 m, width 1.2 -> 1.8 m. |
| 13 | Solid enemies | Feels nice. Dodge should not go through; movement cards should. | **F1:** every Movement card passes through. GDD §3. |
| 14 | Recovery slot | Up plenty; not challenged yet with either class. | No change (Recovery 8 -> 12 s still lands in P-dodge, your D13). |
| 15 | Dead-card swap | More useful once decks have synergies. Ctrl+1-5 is a stretch: use Shift+1-5. | **F1:** Shift+1-5. GDD §4. |
| 16 | Death | Nice. | None. |
| 17 | Pause screen | Good and functional. | None. |
| 18 | Pause tone | Good. | None. |
| 19 | Full run | Getting fun, not very challenging: call today's tuning "Easy", with Normal, Hard and a top tier ("Torment"?) later; names open. A run should be at least 10 stages. | Tiers recorded in GDD §9 (ROADMAP "Later"). **F1:** 10-room runs. |
| 20 | Card rewards | Good so far. | None. |
| 21 | Boss | Looks nice, feels good, not too hard yet. | None (the tiers will cover difficulty). |
| 22 | Loadouts | Unsure what "saving a deck" meant. | Reworded above; it's for 3d. |
| 23 | Armor | No strong favouritism between fire and physical. | None. |
| 24 | Wizard | Alright; should be slightly harder / squishier, not the easy way out. Wizard 2 dodge charges, Rogue 3. Wizard slightly longer Recovery. | D18 = A. GDD §5. Charges and Recovery in **P-dodge**; HP and tuning in **W1b**. |

### Your checklist answers (2026-10-29)

| # | Item | Your answer | Follow-up |
|---|---|---|---|
| 1 | Opening wave | Feels good, not too hard. You'd lean toward making the whole run harder. | Difficulty tiers (Easy / Normal / Hard) logged in ROADMAP "Later". No retune now. |
| 2 | Busy waves | Never overwhelmed. | Same as 1. |
| 3 | Enemy warnings | Look good. | None. |
| 4 | Finding yourself | Easy. | None. |
| 5 | Enemy HP bars | Look good. | None. |
| 6 | Aim reticle | Looks good. | None. |
| 7 | Light attack | Auto-fires; clicking makes a noticeable difference. | None. |
| 8 | Heavy attack | Feels good. You may later weaken it or raise its cooldown. | Noted in ROADMAP "Later"; no change now. |
| 9 | Dodge | Feels nice. | The dodge-charges slice is still queued (your earlier request). |
| 10 | Hold-to-preview | Good. | None. |

### FYI, no action needed

- **Dodge distance (corrected note).** Before Slice 6 the dodge was set to 3.5 m (speed 14 x 0.25 s) but slid on to about 7.1 m because of a bug. The S6-2 fix made it stop at its set distance (3.5 m). Your D8 answer set it to about 5 m: `data/player.json` `dodge.speed` 20 x `dodge.duration` 0.25 s = **5.0 m**, with no slide. To tune it, change `dodge.speed` (no code needed).
- **Temporary:** the first-run deck holds every Fire Rogue card so you can try them all. Unlock rules come with the run loop.

### Recently resolved

- **2026-11-02: 11/1, Luke's playtest. "His only suggestion so far was friendlier keybindings, using Q and E. I already changed data/input_bindings.json (commit 24530e4). The UI still shows 1-5."** Also: Recovery on R rather than 3; Movement may move to F later. **Recorded** in GDD §3 (the UI shows whatever the bindings say; no hardcoded keys) and in `docs/playtests/2026-11-01-luke-keybinds.md`. **Built in K1** (tag `playtest-2026-11-02-K1`): the screen shows Q E 1 2 R, and Recovery is on R.

#### Vision check, round 1 (answered 2026-11-02)

Your answers come from your 10/31-11/2 notes; the right column says which note answers each.

| # | Question | Your answer | Where it went |
|---|---|---|---|
| 1 | Does moment-to-moment combat feel good? | Not answered directly. Closest note: the pace could be a bit faster, and the Wizard never seems to take damage. | H1 (pressure pass). Asked again in round 2. |
| 2 | Do the five slots create interesting decisions in real time? | No: "The slots do not create synergy or real decisions yet. I can spam each slot blindly and get the same kind of outcome." | GDD §4a; BD0, BD1. |
| 3 | Does the same deck feel different fight to fight and run to run? | No: "Decks lack variability. Every run of the same class and element feels the same." Also: "I can add or remove almost any card without suffering and still win easily." | GDD §4a goals; BD0's removal-pain and fingerprint checks. |
| 4 | Do you use the dead-card swap? | It "feels pointless right now because nothing makes a card worth saving." Don't change it yet. | GDD §4; BD0 slot decisions. |
| 5 | Which cards are great, which dull, what's missing? | The AoE cards that burst around the character feel strongest. Wall of Mild Fire felt underwhelming before the 1.5x boost. Missing: themes and unique features to build into; relics/enchants. | GDD §4a balance inputs and relics; BD0. |
| 6 | Fun enough to keep building on, or change something first? | Keep building, but build depth comes first: "cards and decks do not yet change how a run plays", settled "before more screens, art or staging". | Run order K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d (D21). |

#### Decisions

| ID | Question | Your answer | Date |
|---|---|---|---|
| D18 | Should the Wizard be the "easy class"? | A: its rooms cost some HP, less than the Rogue's. Also: squishier, 2 dodge charges (Rogue 3), slightly longer Recovery. GDD §5. | 2026-10-30 |
| D17 | Show each card's damage type? | Your own answer: colour the card frames by family. Fire cards red/orange, class cards light bronze, neutral cards grey. The pause card details still come later. Recorded in GDD §4; being built in PL2. Starting colours: Fire `#ff6a1f`, bronze `#d9b48a`, grey `#9a9a9a` (ux may nudge them for contrast). | 2026-10-30 |
| D13 | Is healing too strong? | B: Recovery cooldown 8 s -> 12 s (built in the P-dodge slice). | 2026-10-29 |
| D16 | Should the boss ever stagger? | B: a short stagger at each phase threshold, which interrupts its attack or action (built in the P-dodge slice). | 2026-10-29 |
| D14 | Wall of Mild Fire on a single enemy? | A: keep it as a crowd card. | 2026-10-29 |
| D15 | Fire against the boss (fire resisted 50%, physical not)? | Superseded by your armor request (Slice A1, GDD §7 Armor). | 2026-10-29 |
| D8 | How far should the dodge go? | C: about 5 m. It may go lower later, so keep it easy to tune. Critical survival moves should come from Movement cards. | 2026-10-28 |
| D9 | Should Stealth also drop enemy aggro? | A: pass-through only for this pass. Aggro drop is planned for later. | 2026-10-28 |
| D10 | Duplicate cards in a deck? | A: allowed (they never count toward the unique minimum). | 2026-10-28 |
| D11 | Neutral card colours? | A: neutral palette. | 2026-10-28 |
| D12 | Order: tooling task, then C1, then the end-of-pass playtest? | A: as planned. | 2026-10-28 |
| - | Add the tech-writer role? | Yes. It owns README, CHANGELOG, ASSETS and ARCHITECTURE, and does one docs pass per slice before close. | 2026-10-28 |
| D1 | Run stats on the Game Over screen? | A: not now; revisit with the run structure. | 2026-10-28 |
| D2 | Hold-to-preview casting? | C: build it as the default, with a setting to cast on press instead. Scheduled as Slice 6. | 2026-10-28 |
| D3 | Tint shots by team? | A: yes (already built). | 2026-10-28 |
| D4 | Light attack cut to 3? | A: keep it; you will playtest, and it stays easily tunable. | 2026-10-28 |
| D5 | Heavy's 50% Burn beats some area cards? | A: keep as built. | 2026-10-28 |
| D6 | Golem wind-up 0.7 s? | A: yes (already applied). | 2026-10-28 |
