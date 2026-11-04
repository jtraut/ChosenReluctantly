# Director open items

Last updated: 2026-11-03 (H3 closed, MAP0 written; questions D31-D33)
**Status: 3 waiting on a decision (D31-D33, not blocking; from the map plan), 2 things to look at now (40, 39; item 35 waits for BD2). H3 is done: the dodge is back on Space (Rogue 2, Wizard 1), Movement is on Ctrl, enemies and the boss volley are a bit faster. MAP0 is done too: the map plan is in `docs/MAP.md` (a relic route reaches 6-8 relics but gets fewer cards). Next: PL3 -> BD1 -> BD2 -> MAP1 -> MAP2 -> 3d.**

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-03-H3`, play, then `git checkout main`. The one before it is `playtest-2026-11-02-H2` (dodge off). Older tags are in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Until you answer, I use my default, and it doesn't block work (the map is built after BD2). The full map plan is in `docs/MAP.md`. Next new number: D34.

- **D31: What does a rest stop offer, now that relics aren't there (your D30) and you may drop the heal?**
  - **A (my default):** keep today's rest: heal 30% or remove a card. The heal is one number in data, so dropping it later costs nothing.
  - **B:** no heal. A rest stop becomes "remove a card", and rest stops get rarer.
  - **C:** no rest stops at all. Card removal is only at the merchant.
- **D32: Map shape.**
  - **A (my default):** 4 lanes, mostly 2 choices per step, the whole map visible from the start, reading left to right. Every route is 10 rooms.
  - **B:** 3 lanes: fewer, clearer choices.
  - **C:** only the next 2 rooms are visible: more surprise, less route planning.
- **D33: When do mini-bosses and curse/buff rooms come?** The map is built as MAP1 (the map and gold) and MAP2 (the merchant), both before loadouts as you asked (D28). Mini-bosses and curse/buff rooms are MAP3.
  - **A (my default):** after loadouts (3d), before BD3.
  - **B:** before loadouts, straight after the merchant.
  - **C:** after BD3.

## Needs your eyes

Reply with the number and a word or two.

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
