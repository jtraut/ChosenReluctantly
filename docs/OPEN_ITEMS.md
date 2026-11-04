# Director open items

Last updated: 2026-11-03 (your answer D30 = A recorded; H3 starting)
**Status: nothing waiting on a decision, 2 things to look at now (38, 39; item 35 waits for BD2). Your answers are in the GDD and the plans. Next: H3 (the dodge comes back: Rogue 2, Wizard 1 charges, dodge on Space, Movement on Ctrl, enemies and the boss volley a bit faster), then MAP0 (map design doc, with your merchant and relic stage), then PL3 -> BD1 -> BD2.**

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D30 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-02-H2`, play, then `git checkout main`. The one before it is `playtest-2026-11-02-H1` (dodge on). Older tags are in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H2):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Q, E, F, Space, R** cast Attack, Area, Utility, Movement, Recovery · Shift + the same key swaps · Esc pause · F3 debug. No dodge in this build. **From H3 (next build):** Space dodges, Movement moves to Ctrl, so the strip reads Q E F Ctrl R.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Next new number: D31.

Nothing right now. D30 = A is recorded in GDD §4a (relics only from the merchant, the relic stage and elites). Your note that the rest-room heal may go altogether is in GDD §9; MAP0 will propose what a rest stop offers and ask you as a D31+ question.

## Needs your eyes

Reply with the number and a word or two.

38. **H1 pace.** Do rooms feel quicker with the faster enemies, or only more crowded? (Playtester's question; the bot can't tell.) You can answer this after H3, which speeds attacks up a little more.
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
