# Director open items

Last updated: 2026-11-20 (BD3b closed; latest tag `playtest-2026-11-20-BD3b`)
**Status:** No decisions waiting. 1 thing to look at (61: Thesis's big hit), plus the round 2 vision check and one optional question (Battlemage as a subclass). **BD3b (Wizard depth) is done**, tag `playtest-2026-11-20-BD3b`: two new Wizard builds, Thesis (Charge) and Ward Battlemage, 7 cards and 5 relics. Eyes 60 (play 3d) expired with its default, which BD3b shipped. Next: TL1 and TL2 (tools so the playtester can play and watch whole runs), then the Milestone 3 close and its full playtest.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-20-BD3b`, play, then `git checkout main`. The one before it is `playtest-2026-11-18-3d`. Try the new Wizard decks with `-- --class=wizard --deck=wizard-thesis --full-deck` or `--deck=wizard-ward-battlemage`. Older tags are in `docs/RESOLVED.md`.
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

61. **Thesis Defense's big hit, when you play BD3b.** A Thesis spend at 6 Charge does 67 base damage, and with the Reading List relic up to 157. That was needed for the card to matter. The playtester also asks whether the spender should share the Attack: Single slot with its builders (Footnotes), which means you swap between building and spending.
    - **Default:** keep both as built, and revisit them in BAL1 with your feel in hand. Expires at TL2's close (TL1 now closes together with TL2).

## Later, optional

- **Battlemage as a Wizard subclass?** (asked in chat 2026-11-20). GDD §6 gives each class two subclasses later. Should "Battlemage" be one of the Wizard's, which would give its defense passive a home? No default needed: it matters when subclasses are designed (after BD3c).

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
