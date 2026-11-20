# Director open items

Last updated: 2026-11-20 (Milestone 3 closed after the review; latest tag `playtest-2026-11-20-BD3b`)
**Status:** **Milestone 3 is done.** The milestone playtest found no blocker, and I've reviewed its report and screenshots. Next come three slices that don't need your play: UX1a (combat readability), UX1b (run screens) and SIM2a (a bot that drafts toward a build). BAL1 and the Battlemage rework (BD3c) wait for you to play BD3b. **One play session unblocks most of it:** see "The one ask" below.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **The one ask (it unblocks BAL1, BD3c, the vision check and eyes 62):** check out `playtest-2026-11-20-BD3b`. Then:
  1. Play one normal three-act run, `godot --path .`, and **time it on a clock** (eyes 62).
  2. Try the Battlemage deck: `godot --path . -- --class=wizard --deck=wizard-ward-battlemage --full-deck --run-room=10`.
  3. Answer the vision check round 2 below.
- **Latest known-good build:** `git checkout playtest-2026-11-20-BD3b`, play, then `git checkout main`. The one before it is `playtest-2026-11-18-3d`. Try the new Wizard decks with `-- --class=wizard --deck=wizard-thesis --full-deck` or `--deck=wizard-ward-battlemage`. Older tags are in `docs/RESOLVED.md`.
- **Relics:** `-- --relics=pyre_insurance+heavy_sigh` starts with relics; `-- --relic-cap=1` tries the give-one-up step.
- **Normal run:** `godot --path .` (three acts of 10 rooms on a branching map; Continue on the class pick resumes a saved run). Extras: `-- --run-seed=5`, `-- --run-room=10` (act 1 mini-boss), `-- --run-room=30` (final boss), `-- --acts=1` (the old one-act run), `-- --no-map` (straight run), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Next new number: D56.

None right now.

## Needs your eyes

Reply with the number and a word or two. **Each item has a default. If it's still unanswered when the slice after the one that added it closes, the default applies and it moves to `docs/RESOLVED.md` (your rule, 2026-11-12).**

- **62. How long does a real run take?** Your target is 15-20 minutes including decisions (D50). The bot's two wins took about 11 minutes of fighting, and the playtester estimates 20-28 minutes with a human's thinking time. Please time one run on a clock. **Default:** keep the target and change nothing until it's measured. (Added at the Milestone 3 close; expires at UX1a's close.)
- **63. Leftover gold.** The bot runs ended with 200-600 unspent gold. Your §4a rule is that gold income goes up rather than relic prices coming down, so I won't cut income. The bot rarely visits a merchant, though, so this may be the bot, not the game. **Default:** no change until SIM2a's build-aware bot measures it. One idea for when the between-run currency (§8) is designed: leftover gold could carry over into it. (Added at the Milestone 3 close; expires at UX1a's close.)

- **65. Can you tell which relic fired?** In a fight, a relic that fires now pulses its own badge (a cream frame and its name under the row) instead of floating its name over the action. The bot playtester thinks that may be easy to miss in a burst. When you play, does it work for you? **Default:** keep it as built. (Added at UX1a's close; expires at UX1b's close.)
- **64. Map: auto-advance when there's only one way forward.** My call, which you can veto: when the map has only one room to go to next, it shows for about a second and then moves on by itself (any key skips). That's about 10 fewer button presses a run. It's built in UX1b. **Default:** build it as described. (Added at the Milestone 3 close; expires at UX1a's close.)

## Later, optional

- **A second boss per act?** Every run meets the same three bosses (Brute, Corporate Raider, Guardian). That's within the slice scope (§10: "2 to 3 plus a final boss"), and endless mode already shuffles bosses (§9a). No default needed: it matters at content planning after Milestone 4.

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
