# Director open items

Last updated: 2026-11-02
**Status: 6 waiting on a decision (D19, D20, D21, D23, D26, D27; none blocks). 10 things to look at when you play (items 25-32, 36-37), plus items 22 and 33-35 once their slices land.** Done: C1, Polish 1, 3a, 3b, 3c (the boss), A1 (armor), T-decks, W1a (a playable Fire Wizard), PL2 (frame colours), F1 (your checklist answers), P-dodge (dodge charges, Recovery, boss stagger), W1b (Wizard cards and tuning) and **K1** (key labels follow your bindings; Recovery on R; tag `playtest-2026-11-02-K1`). Next is H1. Then, in your 2026-11-02 order: ~~K1~~ -> **H1** (harder enemies) -> **BD0** (build-depth design doc) -> **PL3** (polish and housekeeping) -> **BD1** (first build-depth engine slice) -> **3d** (loadouts).

Owned by game-lead. Answer in chat with the ID, for example "D13 = A".

## How to playtest

- **Play the latest known-good build:** `git checkout <tag>` (the tag is named in "While you were away" below), play, then `git checkout main` when you're done. If there's no tag yet, `main` runs too.
- **Normal run:** `godot --path .` (or open `project.godot` and press Play). This starts a 10-room run. Useful extras: `godot --path . -- --run-seed=5` (replay a seed), `-- --run-room=10` (jump to the boss room), `-- --class=wizard` (skip the class pick). Test scenarios give you 9999 HP and the old endless arena.
- **Preset test decks (from T-decks):** `godot --path . -- --list-decks` shows them. Fight the boss with one: `godot --path . -- --deck=fire-heavy-rogue --full-deck --run-room=10`, or swap in `physical-rogue`, `mixed-rogue`, `fire-heavy-wizard`, `mixed-wizard` or `arcane-heavy-wizard`. Drop `--full-deck` to use the preset's 15-card starter, The elite room is somewhere in rooms 3-6 depending on the seed: fix the seed with `--run-seed=1` and check the room indicator to find it. A preset lasts the whole launch, including Try again. To add your own, copy a file in `data/debug_decks/` and rename it.
- **Keys (your bindings, Recovery on R since K1):** WASD move · mouse aims · left click = light attack (it also fires on its own) · right click = heavy attack · Space = dodge · **Q, E, 1, 2, R** = cast the card in Attack, Area, Utility, Movement, Recovery · **Shift + the same key** = dead-card swap (throw away that slot's card and draw the next one, with a short cooldown) · Esc = pause and settings · F3 = debug overlay. Every key label on screen comes from `data/input_bindings.json`, so if you change a key there the screen follows. A duplicate key is reported as an error at startup.
- **Hold-to-preview (the default):** hold a card key to see its hit area in your element colour, aim with the mouse, and let go to cast.
- **Settings:** press Esc. The pause screen has the "Cast cards on: Release (preview) / Press" toggle. It saves at once.
- **Test scenarios** (9999 HP, for looking at one thing): `godot --path . -- --scenario=<name>` with `waves`, `attacks`, `card_cast`, `c1_status`, `c1_placed`, `c1_moves`, `cast_preview`, `targeted_aoe`, `stun_crowd`, `hp_bars`, `bar_modes`, `game_over`, `settings_open`, and others in `data/scenarios.json`.

## While you were away

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

## Vision check, round 2 (answer after playing BD1)

Your round-1 answers are under "Recently resolved". Best asked after BD1, when the first synergies and relics exist.

1. Does moment-to-moment combat feel good?
2. Do the five card slots create interesting decisions in real time, or do you mostly ignore them?
3. Does the same deck feel different from fight to fight, and from run to run? Which slots feel samey?
4. Do you use the dead-card swap (Shift + the slot's key), and does it feel good or like a chore?
5. Which cards are great, which are dull, and what is missing?
6. Is the game fun enough to keep building on, or does something need to change first?
7. Could you win with a deck you built on purpose in a different style from last run?

## Your feedback in progress

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

## Needs your decision

None blocks work. Until you answer, I use my default. **D22, D24 and D25 are reserved** for BD0's questions (at most 3); D23 is taken by the loadout card flags below. Next new number: D28.

- **D27: Enemy attack speed, and what to try if the Wizard still doesn't bite (new, from H1).** You said: raise enemy speed until the Wizard takes damage, then attack speed if that's not enough. H1 raised enemy speed 25% (the chaser is now 5.0 against your walk of 6.0, the most it can be without outrunning you). In the sim, the kiting Wizard still takes **zero** damage, even with enemies attacking twice as often. Faster attacks did hurt the Rogue: at +25% attack speed, his clear rate fell from 100% to about 56%. So I shipped speed +25% and left attack speed unchanged. The bot is weaker than you are, so your hands decide (checklist item 33).
  - **A (default):** keep speed +25% and attack speed unchanged.
  - **B:** add +25% attack speed anyway and accept a harder Rogue.
  - **C:** after you play, if the Wizard still doesn't bite, approve a different lever for a follow-up: enemy HP, more enemies per wave, or longer shooter range. This one isn't built; it's outside H1.
  - Any of these is a one-line data change, so none blocks work.
- **D21: Run order after W1b.** You set K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d. I agree with it. The one thing I'd move: **PL3's housekeeping** (the untracked `.uid` files, `docs/.gdignore` and the one-time line-ending fix with a `.gitattributes`). It takes minutes, and until it's done every slice's commits risk sweeping in stray files and showing whole-file diffs on docs that mix line endings. BD0 alone will rewrite large parts of the docs. The polish items in PL3 stay where you put them.
  - **A (my default, your order):** housekeeping stays in PL3, after BD0.
  - **B:** do only the housekeeping now, before H1 (K1 is already done). The rest of PL3 is unchanged.

- **D26: Can menu keys stay written out on screen? (new, from K1)** Your rule (GDD §3) says no UI text may hardcode a key. K1 made every *game* key (cards, attacks, dodge, pause) come from `data/input_bindings.json`. Three menu hints still name keys directly, because the menus read those keys in code rather than from the bindings file:
  - Game over: "Enter or Space".
  - Class pick: "1 / 2 or the arrow keys".
  - Reward and remove screens: "Keys 1-4 highlight" and "Keys 1-5 jump to a column".

  Since those keys are fixed in code, the screen and the keys can't disagree today. They just aren't rebindable.
  - **A (my default):** menu navigation keys that aren't in `input_bindings.json` are exempt. Proposed GDD §3 addition: "Menu navigation keys (Enter, arrows, number keys to pick an option) are fixed and may be named in UI text. Every gameplay key comes from the bindings." The scan test already allows exactly these three.
  - **B:** move menu navigation into the bindings file too, so those hints come from it like everything else. That's a small extra job, which I'd fold into PL3.

- **D23: What "flag cards that are only available later" means for loadouts.** You suggested: each card gets an availability (starter, reward, or locked until a condition), the editor shows a badge, a loadout can list reward and locked cards as a "plan", reward screens mark "On your plan", and the starting deck holds only starter cards. I'm building that, with **one catch I found in the data:** today each class's starting deck is exactly 15 cards, 3 per slot, and every slot needs 3 different cards. If only the default decks' cards counted as "starter", each class could add just 3 more cards (the other class's Fire and Neutral starters, none for Utility) plus copies, so the loadout screen would have almost nothing to customise.
  - **A (my default, the simpler option):** "starter" means "allowed in a loadout's starting deck", not "in the class's default deck". **Every card that exists today is tagged starter**, as the old 3d plan had it. "Reward" and "Locked" are for new cards from BD1 on (for example a keystone you must find in a run). Badges, the plan list and "On your plan" are all built, and start showing once such cards exist.
  - **B:** the cards in today's two default decks are starter and the rest are reward-only. Loadouts can then swap in only 3 extra cards per class (Rogue: Flaming Nonsense, Fireball, Leech; Wizard: Ember Whatever, Shrug Bomb, Blaze and Bail) until more starter cards exist.
  - **C:** you meant something else; tell me and I'll take the simpler reading.

- **D20: Wizard HP: squishier, or safe from a one-shot?** You asked for a squishier Wizard. The boss's "Fan of regrets" volley does 25 damage if all 5 pellets hit, so at 25 HP or less one full volley from full health can kill it.
  - **What the tuning did:** it made the Wizard harder through about 40% less damage (bolt 2.4 -> 1.5, blast 8.5 -> 5.5, its cards slightly weaker), 2 dodge charges and a 14 s Recovery.
  - **Result in the bot sim:** Wizard rooms cost about 75% of the Rogue's HP, and its boss fight is 72-103% of the Rogue's length. No deaths in 48 boss fights, even at 22 HP.
  - **FYI, the tuning's other numbers:** the Wizard's auto bolt now does 50% of the Rogue's light-attack damage per second (was 80%), and its right-click blast does 5.5 (was 8.5). That's the price of range I chose; say so if it feels too weak in your hands.
  - **A (as built now, my default):** keep 26 HP, so no single attack kills from full. The Wizard is harder, but not lower HP.
  - **B:** 22 HP, truly squishier. A full volley from full HP could kill it; it never happened in the bot runs (12% of pellets hit).
  - **C:** 22 HP, and the volley drops to 4 damage per pellet (20 total), which also makes the Rogue's boss slightly easier.

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
13. ~~**A build with no damage cards (only light and heavy attacks) stays slow against the boss (about 3x).**~~ **Superseded 2026-11-02:** your no-card Wizard win on 10/31 shows slow isn't the same as losing. H1 makes no-card runs unsafe; BD0 designs the deliberate basic-attack build.
14. **Wizard Recovery 14 s vs the Rogue's 12 s** (your "slightly longer"; built in P-dodge). **Change:** the Wizard's Recovery override in data.
15. **Run order changed: F1 and P-dodge now come before W1b,** so the Wizard is tuned once, after everything that changes its risk (10 rooms, charges, Recovery). **Change:** say "W1b first".
16. **Menu number keys pick by position (K1).** On reward and remove screens, 1 is the first option or column, even where a card's own key is also a number (Utility is on 1, but it's the third column). The two clashes the playtester saw (option badge "1" next to a "Key 1" chip, and the "Utility (1)" header) get a visual fix in PL3. **Change:** ask for menu numbers to follow the card keys, or to drop the number keys on those screens.

## Needs your eyes: play-session checklist (about 20-30 minutes)

Play a normal run, not a test scenario. Reply with the item number and a word or two ("3: fine", "8: too short").

_Items 1-21, 23 and 24 are answered (see "Your checklist answers" below)._

**G. PL2 (new)**
25. **Frame colours.** Look for: at a glance in a fight, can you tell orange (fire), bronze (class) and grey (neutral) apart on the card strip, especially bronze vs grey?
26. **Highlighted grey reward card.** Look for: the white ring around a highlighted grey card is easy to see. (A small notch in it is a known bug, fixed in F1.)
27. **Rogue melee arc.** Look for: does the faint arc tell you the light attack is melee, or would a first run need a hint?

**H. P-dodge (new)**
28. **Dodge pips.** The charges show as small pips under the attack meters, top-left. Look for: can you keep track of your charges mid-fight, or do you want a small "charge back" flash near your character too?
29. **Boss stagger.** Look for: the reel plus "STAGGERED / Hit it now" feels like a real opening, and the stagger-then-roar pause (2 s) isn't too long.

**J. W1b (new)**
36. **Wizard cards.** Play a Wizard run. Look for: do the caster cards make it feel like a different class from the Rogue, and is Ward worth casting?
37. **Wizard risk.** Look for: do rooms 1-9 cost you anything, and does the boss feel dangerous without feeling like a sudden one-shot? (This feeds D20 and H1.)

**K. K1 (new)**
30. **Key labels.** Look for: the labels on the card strip match the keys you press (Q, E, 1, 2, R).
31. **Casting on the new keys.** Look for: you can still hold to preview and cast on release with Q, E, 1, 2, R.
32. **Swap.** Look for: Shift+key still swaps the card without casting it.

22. **Loadouts (after 3d, not built yet).** This is about a feature still to come: from your second run on, you'll be able to build your own starting deck from your cards, save it under a name (5 per class), and pick it before a run. (The "Pick your hero" screen you saw is the class pick from W1a.) Look for, once it lands: it's easy to understand.

**I. Coming in your 2026-11-02 order (not built yet; I'll say when each lands)**
33. **H1 Wizard.** Play the Wizard again, once with cards and once without. Does it bite now?
34. **H1 no cards.** Run with no cards at all. Do you now lose before the boss?
35. **BD1 builds.** Build the same class and element twice with different plans. Do the two runs feel different? Does removing a keystone card hurt?

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

- **2026-11-02: 11/1, Luke's playtest. "His only suggestion so far was friendlier keybindings, using Q and E. I already changed data/input_bindings.json (commit 24530e4). The UI still shows 1-5."** Also: Recovery on R rather than 3; Movement may move to F later. **Recorded** in GDD §3 (the UI shows whatever the bindings say; no hardcoded keys) and in `docs/playtests/2026-11-01-luke-keybinds.md`. **Built in K1** (tag `playtest-2026-11-02-K1`): the screen shows Q E 1 2 R, and Recovery is on R.

### Vision check, round 1 (answered 2026-11-02)

Your answers come from your 10/31-11/2 notes; the right column says which note answers each.

| # | Question | Your answer | Where it went |
|---|---|---|---|
| 1 | Does moment-to-moment combat feel good? | Not answered directly. Closest note: the pace could be a bit faster, and the Wizard never seems to take damage. | H1 (pressure pass). Asked again in round 2. |
| 2 | Do the five slots create interesting decisions in real time? | No: "The slots do not create synergy or real decisions yet. I can spam each slot blindly and get the same kind of outcome." | GDD §4a; BD0, BD1. |
| 3 | Does the same deck feel different fight to fight and run to run? | No: "Decks lack variability. Every run of the same class and element feels the same." Also: "I can add or remove almost any card without suffering and still win easily." | GDD §4a goals; BD0's removal-pain and fingerprint checks. |
| 4 | Do you use the dead-card swap? | It "feels pointless right now because nothing makes a card worth saving." Don't change it yet. | GDD §4; BD0 slot decisions. |
| 5 | Which cards are great, which dull, what's missing? | The AoE cards that burst around the character feel strongest. Wall of Mild Fire felt underwhelming before the 1.5x boost. Missing: themes and unique features to build into; relics/enchants. | GDD §4a balance inputs and relics; BD0. |
| 6 | Fun enough to keep building on, or change something first? | Keep building, but build depth comes first: "cards and decks do not yet change how a run plays", settled "before more screens, art or staging". | Run order K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d (D21). |

### Decisions

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
