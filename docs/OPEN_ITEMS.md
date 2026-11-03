# Director open items

Last updated: 2026-11-02 (H1 closed)
**Status: 2 waiting on a decision (D26, D28; neither blocks). 2 quick things to look at when you play (38-39), plus item 35 after BD1.** Next: **H2** (the dodge-off trial, Movement on Space, Utility on F, Wizard 22 HP), then BD0 -> PL3 -> BD1 -> 3d.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D28 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-02-H1`, play, then `git checkout main`. Earlier tags are listed in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys today (until H2):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · Space dodge · **Q, E, 1, 2, R** cast Attack, Area, Utility, Movement, Recovery · Shift + the same key swaps · Esc pause · F3 debug. **After H2:** the dodge is off, Movement is **Space** and Utility is **F**.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## What's new since you last played

- **H1 (tag `playtest-2026-11-02-H1`):** every normal and elite enemy is 25% faster (chaser 5.0 against your walk of 6.0), and attack speed is unchanged. The boss's own speed is unchanged, but its adds are faster. You've already played this build; your answer (with cards good, no cards still winnable) is what started H2.

## Needs your decision

None blocks work. Until you answer, I use my default. **D22, D24 and D25 are reserved** for BD0's questions. Next new number: D29.

- **D28: When to build the branching map.** You want routes (merchant, curse/buff rooms, harder rooms and mini-bosses for better rewards) soon; it's recorded in GDD §9. It needs a design pass, and its rewards need gold, XP and between-run points, which don't exist yet.
  - **A (my default):** a map design doc (MAP0, docs only) right after BD0, then the first map build after BD1 and before loadouts (3d).
  - **B:** build a simple map now, right after H2 and before BD0, with card rewards only until the currencies exist.
  - **C:** after 3d.

- **D26 (narrowed): Can two menu hints stay written out?** Your rule (GDD §3) says no UI text hardcodes a key. Your call-16 answer drops the number keys on the reward and remove screens (built in PL3), so only two hints are left, and the menus read both keys in code rather than from `data/input_bindings.json`:
  - Game over: "Enter or Space". Space becomes the Movement key in H2, so H2 also adds a short arm delay there.
  - Class pick: "1 / 2 or the arrow keys".
  - **A (my default):** fixed menu keys (Enter, arrows, class-pick 1/2) may be named on screen. Every gameplay key comes from the bindings.
  - **B:** move them into the bindings file too (a small job in PL3).

## Needs your eyes

Reply with the number and a word or two.

38. **H1 pace.** Do rooms feel quicker with the faster enemies, or only more crowded? (Playtester's question; the bot can't tell.)
39. **H1 boss length.** The Rogue's boss fight runs about 6 s longer (about 66 s). Fine?
35. **BD1 builds (after BD1).** Build the same class and element twice with different plans. Do the two runs feel different? Does removing a keystone card hurt?

Coming with H2 (I'll say when it lands): play once with cards and once without, with no dodge. Do you lose a no-card run now? Do Space for Movement and F for Utility feel right? Should the dodge stay off?

## Vision check, round 2 (answer after playing BD1)

Your round-1 answers are in `docs/RESOLVED.md`.

1. Does moment-to-moment combat feel good?
2. Do the five card slots create interesting decisions in real time, or do you mostly ignore them?
3. Does the same deck feel different from fight to fight, and from run to run? Which slots feel samey?
4. Do you use the dead-card swap (Shift + the slot's key), and does it feel good or like a chore?
5. Which cards are great, which are dull, and what is missing?
6. Is the game fun enough to keep building on, or does something need to change first?
7. Could you win with a deck you built on purpose in a different style from last run?
