# Director open items

Last updated: 2026-11-02 (H2 closed)
**Status: 3 waiting on a decision. D29 (should the dodge stay off?) is the one I'd like answered before BD0, so I've paused there: say "continue" and I start BD0 assuming the dodge stays off. D26 and D28 don't block. 5 things to look at when you play (38-42), plus item 35 after BD1.** Next: **BD0** (build-depth design doc), then PL3 -> BD1 -> 3d.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D28 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-02-H2`, play, then `git checkout main`. The one before it is `playtest-2026-11-02-H1` (dodge on). Older tags are in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H2):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Q, E, F, Space, R** cast Attack, Area, Utility, Movement, Recovery · Shift + the same key swaps · Esc pause · F3 debug. **No dodge** (trial). To bring it back: set `dodge.enabled` to `true` in `data/player.json`, and give `dodge` a free key in `data/input_bindings.json` (for example G); Space now belongs to Movement.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## What's new since you last played

- **H2 (tag `playtest-2026-11-02-H2`), your dodge-off request:**
  - **The dodge is off,** and its row under the attack meters is gone. The code is kept behind the switch above.
  - **Movement is on Space and Utility on F,** so the strip reads Q E F Space R.
  - **The Wizard has 22 HP** (your D20 = B), so a full boss volley (25) can kill from full.
  - **Game over waits 0.4 s and ignores Space,** so a mashed Space can't hit Try again.
  - **The bots:** with cards, the Rogue clears 3 of 16 runs, the kiting Wizard 8 of 16 and the walk-in Wizard 7 of 16, down from 16 of 16 each with the dodge on. No-card runs now die in room 1. The Wizard's 22 HP on its own cost only 1 run in 16. **Nothing was retuned to soften it.** The bots press cards at random and never use Space-Movement as a planned escape, so you'll do better than they do.
  - **Playtester's notes (bot and stills; it can't press keys):** runs fall apart early to mid-run (rooms 2-3 for the Rogue), not as a slow slide. A boss charge plus a smash (18) nearly kills a 22 HP Wizard. The Movement card is your only escape, and whether it's ready depends on which card is up and its cooldown.

## Needs your decision

Until you answer, I use my default. **D29 is the exception:** I paused before BD0 for it (BD0 designs the Movement cards, which depend on it). "Continue" means "use the default". **D22, D24 and D25 are reserved** for BD0's questions. Next new number: D30.

- **D29: Should the dodge stay off? (new, from H2; please play first, items 40-42.)** With the dodge off the bots lose most runs even with cards (above), and you were winning comfortably with it on. Two questions behind it: how often should a careful player win a run with cards on today's "Easy" tier? And with Movement as your only escape, is "sometimes you have no escape" the point, or should Movement cooldowns be looked at?
  - **A (my default until you play):** keep it off for now. BD0 designs Movement cards as the escape slot.
  - **B:** bring it back with fewer charges (for example 1 for both classes) on a key other than Space.
  - **C:** bring it back as it was (Rogue 3, Wizard 2 charges), on a key other than Space. Movement stays on Space.
  - Any of these is a data change; say which key you'd want for the dodge if it returns.

- **D28: When to build the branching map.** You want routes (merchant, curse/buff rooms, harder rooms and mini-bosses for better rewards) soon; it's recorded in GDD §9. It needs a design pass, and its rewards need gold, XP and between-run points, which don't exist yet.
  - **A (my default):** a map design doc (MAP0, docs only) right after BD0, then the first map build after BD1 and before loadouts (3d).
  - **B:** build a simple map now, right after H2 and before BD0, with card rewards only until the currencies exist.
  - **C:** after 3d.

- **D26 (narrowed): Can two menu hints stay written out?** Your rule (GDD §3) says no UI text hardcodes a key. Your call-16 answer drops the number keys on the reward and remove screens (built in PL3). Two hints are left, and both menus read their keys in code rather than from `data/input_bindings.json`:
  - Game over: "Enter" (since H2; Space no longer confirms it).
  - Class pick: "1 / 2 or the arrow keys".
  - **A (my default):** fixed menu keys (Enter, arrows, class-pick 1/2) may be named on screen. Every gameplay key comes from the bindings.
  - **B:** move them into the bindings file too (a small job in PL3).

## Needs your eyes

Reply with the number and a word or two.

38. **H1 pace.** Do rooms feel quicker with the faster enemies, or only more crowded? (Playtester's question; the bot can't tell.)
39. **H1 boss length.** The Rogue's boss fight runs about 6 s longer (about 66 s). Fine?
40. **H2 with cards, no dodge.** Play one run per class. Does danger read as fair? Watch rooms 1-3 especially, and one boss "Fan of regrets" volley.
41. **H2 no cards, no dodge.** Do you lose before the boss now?
42. **H2 keys.** Does Space feel right for Movement, and F for Utility?
35. **BD1 builds (after BD1).** Build the same class and element twice with different plans. Do the two runs feel different? Does removing a keystone card hurt?

## Vision check, round 2 (answer after playing BD1)

Your round-1 answers are in `docs/RESOLVED.md`.

1. Does moment-to-moment combat feel good?
2. Do the five card slots create interesting decisions in real time, or do you mostly ignore them?
3. Does the same deck feel different from fight to fight, and from run to run? Which slots feel samey?
4. Do you use the dead-card swap (Shift + the slot's key), and does it feel good or like a chore?
5. Which cards are great, which are dull, and what is missing?
6. Is the game fun enough to keep building on, or does something need to change first?
7. Could you win with a deck you built on purpose in a different style from last run?
