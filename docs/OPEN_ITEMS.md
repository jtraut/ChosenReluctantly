# Director open items

Last updated: 2026-11-04 (D34-D36 answered; latest tag `playtest-2026-11-04-PL3`)
**Status: nothing waiting on a decision. Your D34 = C, D35 = A and D36 = A are recorded (2026-11-04). 4 things to look at now (42, 41, 40, 39; item 35 waits for BD2). Next: BD1 (cards start to work together) -> BD2 (relics) -> MAP1 (map) -> MAP2 (merchant) -> MAP3 (three acts, save and resume) -> MAP4 (curse/buff rooms) -> 3d.**

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-04-PL3`, play, then `git checkout main`. The one before it is `playtest-2026-11-03-H3`. Older tags are in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Nothing right now. Your D34 = C, D35 = A and D36 = A are recorded in GDD §4a/§5/§9, `docs/MAP.md` §4.5 and the ROADMAP. Next new number: D37.

## Needs your eyes

Reply with the number and a word or two.

42. **My reading of your D34 = C.** Please check two readings. (1) "Later tiers like 2-3 elites" I read as **elites in acts 2 and 3** get a 25% chance of a rare card offer on top of their relic (act 1 elites: relic only). If you meant the difficulty tiers (Normal, Hard), say so; it's one data value. (2) "Difficult to reach 20" I set as a relic hunter ending about 14-17 relics and a no-relic route about 4-6, with the best possible path about 18-19 (MAP.md §4.5; the MAP3 sim tunes it). Also: the swap at the cap is built with relics in BD2, and a relic you give up won't be offered again that run.
41. **Knockback is shorter now (PL3 bug fix).** Every shove on you was being re-applied each frame, so the boss smash threw the Wizard about 20 m instead of the intended 2 m. Fixed for all hits on the player. It changes the feel a bit: tell me if hits now feel too soft. Also new in PL3: a ring and bubble while Ward is up, a big white Overqualified Bolt, green safe-gap strips in the boss volley (only where standing there is really safe, so none up close), a brighter dodge-pip flash, and no number keys on the reward screens. Say if any of it reads badly.
40. **H3 and H1 pace, the Wizard side.** Rogue: recorded ("still felt good, never overwhelmed"). When you next play the Wizard: do rooms feel quicker with the faster enemies, or only more crowded? Does the 1-dodge Wizard get time to react to the boss's Fan of regrets (0.75 s wind-up, lanes brighten toward the fire moment)? Is Ctrl comfortable for Movement while you move with WASD? A no-card run should still lose. The bots say the volley does all of the Wizard's boss damage; I'm checking whether that's the bot or the volley (PL3 item 13). (This replaces old item 38, H1 pace.)
39. **H1 boss length.** The Rogue's boss fight runs about 6 s longer (about 66 s). Fine?
35. **Builds (after BD2).** Build the same class and element twice with different plans. Do the two runs feel different? Does removing a keystone card hurt?

## Later, optional

- **Research digest.** BD0 used no web research, so it marks some ideas from Erannorth Chronicles, Gwent and Monster Train as "unsure". If you'd like, a later task can research your four favourite games and firm those up. Say "digest" to schedule it; otherwise I won't.

## Vision check, round 2 (answer after playing BD2)

Your round-1 answers are in `docs/RESOLVED.md`.

1. Does moment-to-moment combat feel good?
2. Do the five card slots create interesting decisions in real time, or do you mostly ignore them?
3. Does the same deck feel different from fight to fight, and from run to run? Which slots feel samey?
4. Do you use the dead-card swap (Shift + the slot's key), and does it feel good or like a chore?
5. Which cards are great, which are dull, and what is missing?
6. Is the game fun enough to keep building on, or does something need to change first?
7. Could you win with a deck you built on purpose in a different style from last run?
