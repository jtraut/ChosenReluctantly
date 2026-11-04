# Director open items

Last updated: 2026-11-04 (D34-D36 answered, D34 revised; latest tag `playtest-2026-11-04-PL3`)
**Status: nothing waiting on a decision; 1 thing to look at (47). Item 35 waits until you have time for a repeat run. D37 = A and D38 = A are recorded. Next: BD1 -> BD2 (relics) -> MAP1 (map, treasure chests) -> MAP2 (merchant, shop-only relics) -> MAP3 (three acts, save and resume, rare/legendary cards, boss relics) -> MAP4 (events, curse cards, sacrifices, rest dig; probably two sittings) -> 3d (loadouts, starter relic).**

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-04-PL3`, play, then `git checkout main`. The one before it is `playtest-2026-11-03-H3`. Older tags are in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Nothing right now. Your D37 = A (dig relic at rest) and D38 = A (curse cards) are recorded in GDD §4a and BUILD_DEPTH §4.7. Next new number: D39.

## Needs your eyes

Reply with the number and a word or two.

47. **My numbers for your relic and card tiers** (`docs/MAP.md` §4.5). Say if any feel off; they're all data.
    - Relic tier odds: act 1 80/20/0, act 2 15/70/15, act 3 5/25/70 (tier 1/2/3). They apply to every relic source (elite, relic stage, merchant), not just elites.
    - Card odds per offer slot: act 2 20% rare; act 3 30% rare and 8% legendary.
    - The boss-relic pick can't be skipped, and you can't give up a boss relic at the cap, so you always end with 2.
    - Mini-bosses still give gold, and their rare/legendary card offer can be rejected with a reject token.
    - Ballpark: a relic hunter ends with about 14-17 relics, a route that ignores relics with about 6-8 (both include the 2 boss relics).
    - Cost to know about: this needs about 6 boss relics, 5 rare and 4 legendary cards per class, so MAP3 may split in two.
35. **Builds (after BD2; you said you'd circle back when you have time).** Build the same class and element twice with different plans. Do the two runs feel different? Does removing a keystone card hurt?

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
