# Director open items

Last updated: 2026-10-30
**Status: 1 waiting on a decision (D19; doesn't block). 3 new things to look at when you play (items 25-27), plus item 22 once loadouts exist.** Done: C1, Polish 1, 3a (runs of 8 rooms), 3b (card rewards and deck-clean), 3c (the boss) and **A1 (armor)**, **T-decks (preset test decks)** and **W1a (a playable Fire Wizard)**. Done: **PL2** (tag `playtest-2026-10-30-PL2`). Next: **F1, in progress** (your 2026-10-30 checklist answers: bigger Fire Wall, movement cards pass through enemies, Shift+1-5 swap, 10-room runs), then **P-dodge** (dodge charges: Rogue 3, Wizard 2; Recovery cooldowns), then **W1b** (Wizard cards and tuning, now after the dodge work so it's tuned once), then loadouts.

Owned by game-lead. Answer in chat with the ID, for example "D13 = A".

## How to playtest

- **Play the latest known-good build:** `git checkout <tag>` (the tag is named in "While you were away" below), play, then `git checkout main` when you're done. If there's no tag yet, `main` runs too.
- **Normal run:** `godot --path .` (or open `project.godot` and press Play). This starts an 8-room run. Useful extras: `godot --path . -- --run-seed=5` (replay a seed), `-- --run-room=8` (jump to the boss room). Test scenarios give you 9999 HP and the old endless arena.
- **Preset test decks (from T-decks):** `godot --path . -- --list-decks` shows them. Fight the boss with one: `godot --path . -- --deck=fire-heavy-rogue --full-deck --run-room=8`, or swap in `physical-rogue` or `mixed-rogue`. Drop `--full-deck` to use the preset's 15-card starter, The elite room is somewhere in rooms 3-6 depending on the seed: fix the seed with `--run-seed=1` and check the room indicator to find it. A preset lasts the whole launch, including Try again. To add your own, copy a file in `data/debug_decks/` and rename it.
- **Keys:** WASD move · mouse aims · left click = light attack (it also fires on its own) · right click = heavy attack · Space = dodge · 1-5 = cast the card in that slot · Ctrl+1-5 = dead-card swap (throw away that slot's card and draw the next one, with a short cooldown) · Esc = pause and settings · F3 = debug overlay.
- **Hold-to-preview (the default):** hold a card key to see its hit area in your element colour, aim with the mouse, and let go to cast.
- **Settings:** press Esc. The pause screen has the "Cast cards on: Release (preview) / Press" toggle. It saves at once.
- **Test scenarios** (9999 HP, for looking at one thing): `godot --path . -- --scenario=<name>` with `waves`, `attacks`, `card_cast`, `c1_status`, `c1_placed`, `c1_moves`, `cast_preview`, `targeted_aoe`, `stun_crowd`, `hp_bars`, `bar_modes`, `game_over`, `settings_open`, and others in `data/scenarios.json`.

## While you were away

_Updated at every slice close._

- **Latest playtest tag:** `playtest-2026-10-30-PL2` (qa PASS, 1082/1082). Earlier tags: `playtest-2026-10-30-W1a`, `playtest-2026-10-29-T-decks`, `-A1`, `-3c`, `-3b`, `-3a`, `-C1`.
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

## Vision check (answer after playing)

1. Does moment-to-moment combat feel good?
2. Do the five card slots create interesting decisions in real time, or do you mostly ignore them?
3. Does the same deck feel different from fight to fight, and from run to run? Which slots feel samey?
4. Do you use the dead-card swap (Ctrl+1-5), and does it feel good or like a chore?
5. Which cards are great, which are dull, and what is missing?
6. Is the game fun enough to keep building on, or does something need to change first? (The run-loop work is kept loosely coupled to specific cards, so a card-system change won't strand it.)

## Your feedback in progress

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

## Needs your decision

Doesn't block work. Until you answer, I use my default.

- **D19: The dodge right after a movement card ends inside an enemy.** If a movement-card dash ends overlapping an enemy, you stay "ghosted" until you walk clear (at most 3 s), so you can't get stuck. A dodge during that short window also goes through enemies, which bends your "the dodge doesn't go through enemies" rule. qa found no way to chain it into a crowd exploit: the window ends as soon as you're clear, and the dodge can't extend it.
  - **A (my default, qa's pick):** keep it, and add a line to GDD §3 that the dodge can pass through only during that short window.
  - **B:** block the dodge in that window too (it can feel like the dodge "failed" right after a dash).

## Calls I made while you were away (easy to change)

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
13. **A build with no damage cards (only light and heavy attacks) stays slow against the boss (about 3x).** GDD §3 says cards beat basic attacks, so I didn't add a safety net. **Change:** ask for a basic-attack buff or a boss tweak.
14. **Wizard Recovery 14 s vs the Rogue's 12 s** (your "slightly longer"; built in P-dodge). **Change:** the Wizard's Recovery override in data.
15. **Run order changed: F1 and P-dodge now come before W1b,** so the Wizard is tuned once, after everything that changes its risk (10 rooms, charges, Recovery). **Change:** say "W1b first".

## Needs your eyes: play-session checklist (about 20-30 minutes)

Play a normal run, not a test scenario. Reply with the item number and a word or two ("3: fine", "8: too short").

_Items 1-21, 23 and 24 are answered (see "Your checklist answers" below)._

**G. PL2 (new)**
25. **Frame colours.** Look for: at a glance in a fight, can you tell orange (fire), bronze (class) and grey (neutral) apart on the card strip, especially bronze vs grey?
26. **Highlighted grey reward card.** Look for: the white ring around a highlighted grey card is easy to see. (A small notch in it is a known bug, fixed in F1.)
27. **Rogue melee arc.** Look for: does the faint arc tell you the light attack is melee, or would a first run need a hint?

22. **Loadouts (after 3d, not built yet).** This is about a feature still to come: from your second run on, you'll be able to build your own starting deck from your cards, save it, and pick it before a run. (The "Pick your hero" screen you saw is the class pick from W1a.) Look for, once it lands: it's easy to understand.

## Your checklist answers (2026-10-30)

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

## Your checklist answers (2026-10-29)

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

## FYI, no action needed

- **Dodge distance (corrected note).** Before Slice 6 the dodge was set to 3.5 m (speed 14 x 0.25 s) but slid on to about 7.1 m because of a bug. The S6-2 fix made it stop at its set distance (3.5 m). Your D8 answer set it to about 5 m: `data/player.json` `dodge.speed` 20 x `dodge.duration` 0.25 s = **5.0 m**, with no slide. To tune it, change `dodge.speed` (no code needed).
- **Temporary:** the first-run deck holds every Fire Rogue card so you can try them all. Unlock rules come with the run loop.

## Recently resolved

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
