# Director open items

Last updated: 2026-11-04 (your D31-D33 recorded; D34, D35 added; PL3 in progress)
**Status: 2 waiting on a decision (D34, D35, not blocking until MAP3), 2 things to look at now (40, 39; item 35 waits for BD2). H3 is done: the dodge is back on Space (Rogue 2, Wizard 1), Movement is on Ctrl, enemies and the boss volley are a bit faster. MAP0 is done too: the map plan is in `docs/MAP.md` (a relic route reaches 6-8 relics but gets fewer cards). PL3 is in progress. Then BD1 -> BD2 -> MAP1 (map) -> MAP2 (merchant) -> MAP3 (three acts, save and resume) -> MAP4 (curse/buff rooms) -> 3d.**

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-03-H3`, play, then `git checkout main`. The one before it is `playtest-2026-11-02-H2` (dodge off). Older tags are in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Your D31 = A, D32 = A (three acts, 30 rooms, save and return) and D33 = B are recorded in GDD §9, `docs/MAP.md` and the ROADMAP (MAP3 is now three acts with save/resume, MAP4 curse/buff rooms, both before loadouts). Your three acts raise two numbers you set for a 10-room run. Until you answer, I use my default; neither blocks work (both matter at MAP3). Next new number: D36.

- **D34: How many relics over a 30-room run?** You said 6-8 for a relic hunter, cap 10, when a run was 10 rooms.
  - **A (my default):** keep 6-8 per run, cap 10. Relics get scarcer per act: about 1 elite and 1 relic stage per route in each act, mini-bosses give gold and a rare card offer but no relic, and merchant relics cost more (150-260 gold) because gold adds up over three acts.
  - **B:** let it grow with the run: about 15-20 for a hunter, cap about 25, and mini-bosses give a relic.
- **D35: How many card rejects over a 30-room run?** Today: 3 per run, with about 8 card offers. Thirty rooms give about 20.
  - **A (my default):** still 3 per run, so deck noise builds up more.
  - **B:** 3 per act (9 per run).

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
