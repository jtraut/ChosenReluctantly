# Director open items

Last updated: 2026-11-20 (D54 answered; latest tag `playtest-2026-11-18-3d`)
**Status:** No decisions waiting. 2 things to look at (60: play 3d; 61: Thesis's big hit), plus the round 2 vision check. BD3b (Wizard depth) is built and in its docs pass. D54 = A is recorded: your melee "spellblade" Battlemage direction is in GDD §4a, and the rework is scheduled as BD3c, after you've played it in the Milestone 3 playtest. **3d (loadouts) is done**, tag `playtest-2026-11-18-3d`. Next: the BD3b close, TL1 (a playtester movement tool), then the Milestone 3 close.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-18-3d`, play, then `git checkout main`. The one before it is `playtest-2026-11-17-DF1`. Older tags are in `docs/RESOLVED.md`.
- **Relics:** `-- --relics=pyre_insurance+heavy_sigh` starts with relics; `-- --relic-cap=1` tries the give-one-up step.
- **Normal run:** `godot --path .` (three acts of 10 rooms on a branching map; Continue on the class pick resumes a saved run). Extras: `-- --run-seed=5`, `-- --run-room=10` (act 1 mini-boss), `-- --run-room=30` (final boss), `-- --acts=1` (the old one-act run), `-- --no-map` (straight run), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Next new number: D55.

None right now.

## Needs your eyes

Reply with the number and a word or two. **Each item has a default. If it's still unanswered when the slice after the one that added it closes, the default applies and it moves to `docs/RESOLVED.md` (your rule, 2026-11-12).** 

60. **Play 3d: loadouts. Tag `playtest-2026-11-18-3d`.** Your first run counts as run 1 and starts straight away. From run 2 on, a start screen lets you pick the preset deck or a saved loadout, or open the loadout editor. There you build a deck (15-20 cards, at most 2 copies each), add rare and legendary cards to a "plan", and pick a starter relic. Plan cards wear an "On your plan" badge when they're offered. Swapping past a curse now costs 2 s, and an ordinary swap still costs 1 s.
    - To try it without counting a real run: `godot --path . -- --class=rogue --runs-finished=1 --profile-path=C:/temp/p.json --loadouts-path=C:/temp/l.json`.
    - **Known rough edges, already queued for BD3b-0:**
      - the curse swap doesn't show its 2 s cost;
      - the starter relic shows only as a two-letter badge;
      - the editor doesn't explain "plan";
      - tabs read "Empty" while you're filling one;
      - there's no default name;
      - some text is cut off.
    - **Default:** the polish list above, nothing else. Expires at BD3b's close.

61. **Thesis Defense's big hit, when you play BD3b.** A Thesis spend at 6 Charge does 67 base damage, and with the Reading List relic up to 157. That was needed for the card to matter. The playtester also asks whether the spender should share the Attack: Single slot with its builders (Footnotes), which means you swap between building and spending.
    - **Default:** keep both as built, and revisit them in BAL1 with your feel in hand. Expires at TL1's close.

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
