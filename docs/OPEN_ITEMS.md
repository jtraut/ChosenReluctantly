# Director open items

Last updated: 2026-11-18 (3d qa PASS, D53 added; latest tag `playtest-2026-11-17-DF1`)
**Status:** 1 decision waiting (D53, starter relics). Nothing to look at yet (59 expired at 3d's close, defaults kept), plus the round 2 vision check. **DF1 (difficulty bump) is done**, tag `playtest-2026-11-17-DF1`. Item 58 expired at DF1's close with its default kept: the curse swap penalty goes from 1 s to 2 s in 3d (`docs/RESOLVED.md`). Next: 3d (loadouts; all built, qa PASS, playtest next) -> BD3b -> the Milestone 3 close.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-17-DF1`, play, then `git checkout main`. The one before it is `playtest-2026-11-13-MAP4`. Older tags are in `docs/RESOLVED.md`.
- **Relics:** `-- --relics=pyre_insurance+heavy_sigh` starts with relics; `-- --relic-cap=1` tries the give-one-up step.
- **Normal run:** `godot --path .` (three acts of 10 rooms on a branching map; Continue on the class pick resumes a saved run). Extras: `-- --run-seed=5`, `-- --run-room=10` (act 1 mini-boss), `-- --run-room=30` (final boss), `-- --acts=1` (the old one-act run), `-- --no-map` (straight run), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Next new number: D54.

D53. **Starter relics: loadout only, or also found in runs?** Your rule (2026-11-04) was that starter relics are found nowhere else. In 3d I picked four existing relics as starters (Rogue Chasing Paper and Spite Knuckles, Wizard Ergonomic Chair and Paperwork Fire). They still drop from elites, relic rooms and the merchant too. That was my oversight, and qa caught it. Nothing is broken either way: you never get a relic you already own.
   - **A.** They become loadout-only, as you said. This is a data edit, but it takes 2 relics per class out of normal drops, so the bot win rates are re-checked. Done in BD3b, the relic slice.
   - **B.** Keep it as it is: they're starter picks and normal drops too. I update the plan doc.
   - **C.** Leave those four as normal drops and add four new starter-only relics in BD3b.
   - **If you don't answer: A, in BD3b.**

## Needs your eyes

Reply with the number and a word or two. **Each item has a default. If it's still unanswered when the slice after the one that added it closes, the default applies and it moves to `docs/RESOLVED.md` (your rule, 2026-11-12).** 

Nothing waiting. (59, play DF1, expired at 3d's close with its defaults kept.)

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
