# Director open items

Last updated: 2026-11-13 (MAP4 closed; latest tag `playtest-2026-11-13-MAP4`)
**Status:** 0 decisions waiting. 1 thing to look at (58: play MAP4), plus the round 2 vision check. **MAP4 (events) is done**, tag `playtest-2026-11-13-MAP4`. Items 35-56 expired at MAP4's close with their defaults kept (`docs/RESOLVED.md`). Next: DF1 (difficulty bump) -> 3d -> BD3b.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-13-MAP4`, play, then `git checkout main`. The one before it is `playtest-2026-11-12-MAP3b`. Older tags are in `docs/RESOLVED.md`.
- **Relics:** `-- --relics=pyre_insurance+heavy_sigh` starts with relics; `-- --relic-cap=1` tries the give-one-up step.
- **Normal run:** `godot --path .` (three acts of 10 rooms on a branching map; Continue on the class pick resumes a saved run). Extras: `-- --run-seed=5`, `-- --run-room=10` (act 1 mini-boss), `-- --run-room=30` (final boss), `-- --acts=1` (the old one-act run), `-- --no-map` (straight run), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Next new number: D52.

Nothing right now.

## Needs your eyes

Reply with the number and a word or two. **Each item has a default. If it's still unanswered when the slice after the one that added it closes, the default applies and it moves to `docs/RESOLVED.md` (your rule, 2026-11-12).** 

58. **Play MAP4: events, curses, sacrifice relics. Tag `playtest-2026-11-13-MAP4`.** `godot --path .` and play a full three-act run; events are the "?" bubbles on the map. `-- --event=<id>` opens a given event at the next "?" (ids in `data/events/`, for example `supply_closet`, `performance_altar`, `sympathetic_coworker`).
    - **Are the trade-offs clear before you click?** Costs are in one colour and gains in another, and greyed choices say why.
    - **Curses:** you swap past one with Shift + the slot's key, which costs about 1 s on that slot. The playtester thinks that's too cheap ("players will take every curse"). **Default: after your run, the swap penalty on a curse goes from 1 s to 2 s** (curses only). Say "58 leave" to keep 1 s, or "58 harsher".
    - **The Raider (act 2 mini-boss) has 180 HP now, was 120.** Is it an act-ending fight? The Rogue bot still kills it in about 15 s. Any change goes into DF1, the difficulty bump, next.
    - **Small looks, each kept as is unless you say:** the purple curse frame next to the violet relic band; the give-up step's highlight starts on Cancel, so a first Enter cancels (safe; it moves to the first relic in the next ux pass); the Loyalty Pledge event is a toll with no upside (rare, on purpose).
    - **Default:** no change beyond the curse swap penalty above. Expires at DF1's close.

## Later, optional

- **Research digest.** BD0 used no web research, so it marks some ideas from Erannorth Chronicles, Gwent and Monster Train as "unsure". If you'd like, a later task can research your four favourite games and firm those up. Say "digest" to schedule it; otherwise I won't.

## Vision check, round 2 (due now: answer after playing BD2)

Your round-1 answers are in `docs/RESOLVED.md`.

1. Does moment-to-moment combat feel good?
2. Do the five card slots create interesting decisions in real time, or do you mostly ignore them?
3. Does the same deck feel different from fight to fight, and from run to run? Which slots feel samey?
4. Do you use the dead-card swap (Shift + the slot's key), and does it feel good or like a chore?
5. Which cards are great, which are dull, and what is missing?
6. Is the game fun enough to keep building on, or does something need to change first?
7. Could you win with a deck you built on purpose in a different style from last run?
