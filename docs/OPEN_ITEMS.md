# Director open items

Last updated: 2026-11-24 (your M4b play notes recorded)
**Status:** **Thanks for the play.** Your notes are recorded: the map won't start a room on its own any more (UX1d, next), eyes 68-70 are kept as they are, a larger boss rotation and a Battlemage subclass are in the GDD. BAL1 (balance) is unblocked and goes after UX1d. One new question: D56 (does the Battlemage rework still happen). Your play build is still `playtest-2026-11-23-M4b`.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Play while no agent is running, or from a separate copy** (your run closed on its own on 2026-11-20 while bot sims ran from the same folder; the cause is unknown): `git worktree add ../cr-play playtest-2026-11-23-M4b`, then `godot --path ../cr-play`.
- **Still useful when you next play:** time one full three-act run on a clock (the 15-20 minute target, GDD §9), and answer the vision check round 2 below.
- **Latest known-good build:** `git checkout playtest-2026-11-23-M4b`, play, then `git checkout main`. The one before it is `playtest-2026-11-23-M4a`, and before that `playtest-2026-11-20-BD3b`. Try the new Wizard decks with `-- --class=wizard --deck=wizard-thesis --full-deck` or `--deck=wizard-ward-battlemage`. Older tags are in `docs/RESOLVED.md`.
- **Relics:** `-- --relics=pyre_insurance+heavy_sigh` starts with relics; `-- --relic-cap=1` tries the give-one-up step.
- **Normal run:** `godot --path .` (three acts of 10 rooms on a branching map; Continue on the class pick resumes a saved run). Extras: `-- --run-seed=5`, `-- --run-room=10` (act 1 mini-boss), `-- --run-room=30` (final boss), `-- --acts=1` (the old one-act run), `-- --no-map` (straight run), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Next new number: D57.

- **D56. Does the Battlemage rework (BD3c) still happen?** On 2026-11-20 (D54) you asked for the Ward Battlemage to be reworked after your play into a melee "spellblade": it dives into packs, short-range bursts, a key relic that turns light and heavy attacks into melee. Now you've played it and said it's fun with working synergies, and that Battlemage is a good Wizard subclass. The rework is about four sittings and replaces today's deck.
  - **A (my suggestion):** keep today's `wizard-ward-battlemage` deck as it plays now. The melee spellblade ideas become the design of the Battlemage *subclass* (its cards and passive), built with the subclasses later in Milestone 4. BD3c is dropped as a separate slice.
  - **B:** run BD3c as planned now: rework the deck into the melee spellblade (after BAL1).
  - **C:** keep today's deck and add only the melee relic (light and heavy become melee) as a new relic, one or two sittings, after BAL1.

## Needs your eyes

None right now.

## Later, optional

- **Modern class names?** The Wizard may become the "IT Wizard" (your lean) and the others get modern names too (GDD §11 "Setting"). No default needed: names change in a naming pass when story work is scheduled. Send other name ideas whenever you have them.

- **Research digest.** BD0 used no web research, so it marks some ideas from Erannorth Chronicles, Gwent and Monster Train as "unsure". If you'd like, a later task can research your four favourite games and firm those up. Say "digest" to schedule it; otherwise I won't.

## Vision check, round 2 (still open: answer whenever you like)

Your round-1 answers are in `docs/RESOLVED.md`.

1. Does moment-to-moment combat feel good?
2. Do the five card slots create interesting decisions in real time, or do you mostly ignore them?
3. Does the same deck feel different from fight to fight, and from run to run? Which slots feel samey?
4. Do you use the dead-card swap (Shift + the slot's key), and does it feel good or like a chore?
5. Which cards are great, which are dull, and what is missing?
6. Is the game fun enough to keep building on, or does something need to change first?
7. Could you win with a deck you built on purpose in a different style from last run?
