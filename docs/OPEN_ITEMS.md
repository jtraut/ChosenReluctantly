# Director open items

Last updated: 2026-10-29
**Status: 2 small balance questions (D13, D14), nothing blocked.** Content slice C1, the capture-tooling task and Polish 1 are **done** (tag `playtest-2026-10-29-C1`). Now in progress: Milestone 3a, the run structure (rooms in a row, win and lose screens).

Owned by game-lead. Answer in chat with the ID, for example "D13 = A".

## How to playtest

- **Play the latest known-good build:** `git checkout <tag>` (the tag is named in "While you were away" below), play, then `git checkout main` when you're done. If there's no tag yet, `main` runs too.
- **Normal run:** `godot --path .` (or open `project.godot` and press Play). Play normal runs for the checklist. Test scenarios give you 9999 HP.
- **Keys:** WASD move · mouse aims · left click = light attack (it also fires on its own) · right click = heavy attack · Space = dodge · 1-5 = cast the card in that slot · Ctrl+1-5 = dead-card swap (throw away that slot's card and draw the next one, with a short cooldown) · Esc = pause and settings · F3 = debug overlay.
- **Hold-to-preview (the default):** hold a card key to see its hit area in your element colour, aim with the mouse, and let go to cast.
- **Settings:** press Esc. The pause screen has the "Cast cards on: Release (preview) / Press" toggle. It saves at once.
- **Test scenarios** (9999 HP, for looking at one thing): `godot --path . -- --scenario=<name>` with `waves`, `attacks`, `card_cast`, `c1_status`, `c1_placed`, `c1_moves`, `cast_preview`, `targeted_aoe`, `stun_crowd`, `hp_bars`, `bar_modes`, `game_over`, `settings_open`, and others in `data/scenarios.json`.

## While you were away

_Updated at every slice close._

- **Latest playtest tag:** `playtest-2026-10-29-C1` (C1 closed with qa PASS, 696/696 tests).
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

## Needs your decision

Neither blocks work. Until you answer, I keep the current values.

- **D13. Is healing too strong?** The playtester estimates the Recovery slot is ready 5-6 times a minute. With a 30 HP pool that out-heals what the waves deal, so slow chip damage can't kill you. Options: **A** keep it (judge it in play first; my default); **B** Recovery cooldown 8 s -> 12 s; **C** smaller heals (e.g. the potion 16 -> 10). This matters more once runs are several rooms long (3a), because HP carries over.
- **D14. Wall of Mild Fire on a single enemy.** It only hurts while enemies stand in it, so a lone enemy walks out. Options: **A** keep it as a crowd card (my default); **B** it also slows enemies inside it; **C** raise its tick damage 2.5 -> 3.5.

## Calls I made while you were away (easy to change)

Each entry says what I chose and the one-line way to change it.

1. **Enemies are now solid to you (from C1).** Before, you could walk straight through enemies, which made Shadow Step's "pass through enemies" meaningless. Now bodies block you; Shadow Step lets you through and the dodge doesn't. **Change:** set `data/player.json` `body.collide_with_enemies` to false.
2. **Runs are a straight line of rooms (3a), no branching map yet.** Routing choices come later. **Change:** ask for a branching map (it's a generator change).
3. **A run is 8 rooms: 5 combat, 1 elite, 1 rest, and the boss last** (short prototype runs, per GDD §9). **Change:** edit the room counts in `data/run.json`.
4. **The rest room heals 30% of max HP.** **Change:** `data/run.json` rest heal value.
5. **Elite enemies resist every element at least 25%** (they keep their own if it's higher, e.g. the fire golem), capped at 50%, per GDD §7. **Change:** the elite resistance value in `data/run.json`.
6. **A normal launch now starts a run; test scenarios and the wave sim keep the old endless arena.** **Change:** none needed; scenarios are for looking at one thing.

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
