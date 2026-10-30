# Director open items

Last updated: 2026-10-29
**Status: 3 small balance questions (D13, D14, D16), nothing blocked.** Done: C1, Polish 1, **3a (runs of 8 rooms)**, **3b (card rewards and deck-clean)** and **3c (the boss)**. Next: Slice A1 (armor), then dodge charges, then loadouts.

Owned by game-lead. Answer in chat with the ID, for example "D13 = A".

## How to playtest

- **Play the latest known-good build:** `git checkout <tag>` (the tag is named in "While you were away" below), play, then `git checkout main` when you're done. If there's no tag yet, `main` runs too.
- **Normal run:** `godot --path .` (or open `project.godot` and press Play). This starts an 8-room run. Useful extras: `godot --path . -- --run-seed=5` (replay a seed), `-- --run-room=8` (jump to the boss room). Test scenarios give you 9999 HP and the old endless arena.
- **Keys:** WASD move · mouse aims · left click = light attack (it also fires on its own) · right click = heavy attack · Space = dodge · 1-5 = cast the card in that slot · Ctrl+1-5 = dead-card swap (throw away that slot's card and draw the next one, with a short cooldown) · Esc = pause and settings · F3 = debug overlay.
- **Hold-to-preview (the default):** hold a card key to see its hit area in your element colour, aim with the mouse, and let go to cast.
- **Settings:** press Esc. The pause screen has the "Cast cards on: Release (preview) / Press" toggle. It saves at once.
- **Test scenarios** (9999 HP, for looking at one thing): `godot --path . -- --scenario=<name>` with `waves`, `attacks`, `card_cast`, `c1_status`, `c1_placed`, `c1_moves`, `cast_preview`, `targeted_aoe`, `stun_crowd`, `hp_bars`, `bar_modes`, `game_over`, `settings_open`, and others in `data/scenarios.json`.

## While you were away

_Updated at every slice close._

- **Latest playtest tag:** `playtest-2026-10-29-3c` (qa PASS, 907/907). Earlier tags: `playtest-2026-10-29-3b`, `-3a`, `-C1`.
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

- **2026-10-29: Armor for elites and bosses** (non-elemental damage mitigated about as much as elemental). Recorded in GDD §7 as your decision. Queued as **Slice A1** right after the boss slice closes, ahead of dodge charges and loadouts, in your order; I see no reason to change it. It also answers D15 (fire against the boss), so D15 is withdrawn.

## Needs your decision

Neither blocks work. Until you answer, I keep the current values.

- **D13. Is healing too strong?** The playtester estimates the Recovery slot is ready 5-6 times a minute. With a 30 HP pool that out-heals what the waves deal, so slow chip damage can't kill you. Options: **A** keep it (judge it in play first; my default); **B** Recovery cooldown 8 s -> 12 s; **C** smaller heals (e.g. the potion 16 -> 10). This matters more once runs are several rooms long (3a), because HP carries over.
- **D16. Should the boss ever stagger?** Right now nothing you do staggers it during the 60 s fight, which may make your hits feel weightless. Options: **A** keep it unstaggerable (my default); **B** a short stagger at each phase threshold; **C** a stagger meter that fills from heavy attacks.
- **D14. Wall of Mild Fire on a single enemy.** It only hurts while enemies stand in it, so a lone enemy walks out. Options: **A** keep it as a crowd card (my default); **B** it also slows enemies inside it; **C** raise its tick damage 2.5 -> 3.5.

## Calls I made while you were away (easy to change)

Each entry says what I chose and the one-line way to change it.

1. **Enemies are now solid to you (from C1).** Before, you could walk straight through enemies, which made Shadow Step's "pass through enemies" meaningless. Now bodies block you; Shadow Step lets you through and the dodge doesn't. **Change:** set `data/player.json` `body.collide_with_enemies` to false.
2. **Runs are a straight line of rooms (3a), no branching map yet.** Routing choices come later. **Change:** ask for a branching map (it's a generator change).
3. **A run is 8 rooms: 5 combat, 1 elite, 1 rest, and the boss last** (short prototype runs, per GDD §9). **Change:** edit the room counts in `data/run.json`.
4. **The rest room heals 30% of max HP.** **Change:** `data/run.json` rest heal value.
5. **Elite enemies resist every element at least 25%** (they keep their own if it's higher, e.g. the fire golem), capped at 50%, per GDD §7. **Change:** the elite resistance value in `data/run.json`.
6. **Your starting deck will shrink to 15 cards (3 per slot) in 3b,** so rewards have new cards to offer. It's the original starters plus Nope, Leaping Away (an escape) and Eventual Healing; the other 9 cards come from rewards. **Change:** edit `data/run.json` `starting_deck`. To play with every card, launch with `--full-deck` (from 3b).
7. **Three rejects per run stays fixed, and the starter is exactly 3 per slot,** so removal is locked until you own a 4th card in a slot. **Change:** add cards to `data/run.json` `starting_deck` (4 per slot unlocks early removal); rejects are `rejects_per_run`.
8. **A normal launch now starts a run; test scenarios and the wave sim keep the old endless arena.** **Change:** none needed; scenarios are for looking at one thing.

## Needs your eyes: play-session checklist (about 20-30 minutes)

Play a normal run, not a test scenario. Reply with the item number and a word or two ("3: fine", "8: too short").

**A. Start a run and fight**
1. **Opening wave.** The first wave is 4 chasers. Look for: is it a fair start, or too hard? (It can drop to 2 or 3 in data.)
2. **Busy waves.** Up to 12 enemies at once, arriving in four stages. Look for: is 12 at once too many for you?
3. **Enemy warnings.** Look for: you can read every warning before the hit. Chasers show a red-pink ground wedge, shooters a lane strip, and the golem has a 0.7 s wind-up. Enemy shots are pink, so they don't look like yours.
4. **Finding yourself in a crowd.** Enemies now spread around you instead of stacking in a line. When they're in front of you, a pale blue silhouette of you shows through them. Look for: you can always find yourself, and the colour works against your blue body.
5. **Enemy HP bars near you.** Look for: bars over or next to your character never hide anything you need to see.
6. **Aim reticle.** Move the mouse fast (at 1440p too, if you can). Look for: the ring follows without lag, and the dots trail slightly in fast turns.

**B. Try the attacks**
7. **Light attack.** It fires on its own; clicking speeds it up to 1.5x at most. Look for: the swing flash reads at full speed, and spam-clicking helps a bit but doesn't feel mandatory.
8. **Heavy attack (right click).** Look for:
   - the wind-up slow feels like commitment, not sluggishness;
   - the wind-up looks clearly different from the impact;
   - the area feels big enough to be worth pressing;
   - the 0.6 s stun (yellow stars) visibly freezes enemies;
   - about half of heavies set enemies on fire: a fun surprise or a letdown?
9. **Dodge (Space).** It now goes 5 m (your D8 answer). Look for: too short, too long, or fine?

**C. Try the cards**
10. **Hold-to-preview.** Hold a card key, aim, let go. Look for: it feels natural rather than slow, and the outline is clear over enemies without being loud.
11. **Cards vs the free light attack.** Look for: every damage card feels clearly better than the auto attack. The three area cards are only about 7-10% better than light on a single enemy: do they still feel worth casting on one?
12. **Every new card.** Try each one: Slash, Then Bleed · Four Quick Stabs · Fireball, Incoming · Wall of Mild Fire · Walk Through Everyone (Shadow Step) · Reluctant Lunge · Nope, Leaping Away · Heal By Hurting (Leech) · Eventual Healing (Regeneration). Also check the names and flavor lines fit the voice. Look for: which feel great, which feel dull, and which to cut or rework.
13. **Solid enemies.** Look for: you never get stuck or pinned with no way out, and Shadow Step feels like a real escape through a crowd. If it feels worse than walking through enemies, say so (one data flag).
14. **Recovery slot.** Look for: is it ready often enough to matter, without being something you can lean on?
15. **Dead-card swap.** Press Ctrl+1-5 to throw away a card you don't want right now. Look for: is it useful, or a chore? (This feeds Vision check question 4.)

**D. Die once**
16. **Death.** Let yourself die. Look for: you can clearly tell you died (white then red flash, grey-out, topple), the reticle vanishes, and the slow-mo feels "longer", "shorter" or "fine". Then press "Try again": the restart is clean.

**E. Settings and pause**
17. **Pause screen.** Press Esc, switch "Cast cards on" to Press, play a moment, then switch it back. Look for: it works both ways, and pressing Space on Resume doesn't make you dodge.
18. **Pause text tone.** "Paused" / "The world will wait. It is very patient and very cheerful." / "Esc also resumes". Is the tone right? (Placeholder text.)

**F. The run loop (only after each Milestone 3 slice lands; see "While you were away")**
19. **Full run (after 3a).** Play several rooms in a row. Look for: "Room X of Y" is clear, your HP and deck carry over, and the win and lose screens make sense.
20. **Card rewards (after 3b).** After each won room: pick 1 of 3, or reject the offer (3 rejects per run). Look for: offers fit your build, and the deck-clean option is clear.
21. **Boss (after 3c).** Look for: the phases and telegraphs are readable, and it's fair.
22. **Loadouts (after 3d).** On run 2, save and pick a starting deck. Look for: it's easy to understand.

## FYI, no action needed

- **Dodge distance (corrected note).** Before Slice 6 the dodge was set to 3.5 m (speed 14 x 0.25 s) but slid on to about 7.1 m because of a bug. The S6-2 fix made it stop at its set distance (3.5 m). Your D8 answer set it to about 5 m: `data/player.json` `dodge.speed` 20 x `dodge.duration` 0.25 s = **5.0 m**, with no slide. To tune it, change `dodge.speed` (no code needed).
- **Temporary:** the first-run deck holds every Fire Rogue card so you can try them all. Unlock rules come with the run loop.

## Recently resolved

| ID | Question | Your answer | Date |
|---|---|---|---|
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
