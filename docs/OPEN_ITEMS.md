# Director open items

Last updated: 2026-11-23 (TL4 and UX1c done)
**Status:** **Milestone 3 is done; UX1a, UX1b, HP1, SIM2a, SIM2a-4 TL3 (tool cleanup: agent sims no longer touch the game's log folder) TL4 (the watched test bot now plays at full strength at any speed) and UX1c (small display fixes, eyes 68-70) are done.** The build-aware test bot now plays sensibly (human-like Wizard 25/36, Rogue 22/36). Nothing else can move without you: BAL1 and the Battlemage rework (BD3c) wait for your play. **Play the new tag `playtest-2026-11-23-M4a`, not the old BD3b one:** the BD3b tag predated the max HP relics (Mandatory Wellness Pack, Performance Review) and the HUD and run-screen readability work, and BAL1 will tune those relics. A smoke check on it found no blocker. See "The one ask" below.

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Play while no agent is running, or from a separate copy** (your run closed on its own on 2026-11-20 while bot sims ran from the same folder; the cause is unknown): `git worktree add ../cr-play playtest-2026-11-23-M4a`, then `godot --path ../cr-play`.
- **The one ask (it unblocks BAL1, BD3c and the vision check):** check out `playtest-2026-11-23-M4a` (BD3b plus the max HP relics and the readability work). Then:
  1. Play one normal three-act run, `godot --path .`, and, if you can, note how long it took on a clock (the 15-20 minute target).
  2. Try the Battlemage deck: `godot --path . -- --class=wizard --deck=wizard-ward-battlemage --full-deck --run-room=10`.
  3. Answer the vision check round 2 below.
- **Latest known-good build:** `git checkout playtest-2026-11-23-M4a`, play, then `git checkout main`. The one before it is `playtest-2026-11-20-BD3b`. Try the new Wizard decks with `-- --class=wizard --deck=wizard-thesis --full-deck` or `--deck=wizard-ward-battlemage`. Older tags are in `docs/RESOLVED.md`.
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

Added by UX1c (on main, not in the M4a tag yet). Pictures are in `docs/playtests/img/ux1c/`. Each has a before and an after shot.

- **68. Getting hit now flashes violet** (it was pink-red, which looked like an enemy colour; both classes flash violet now). See `hit-after-1366x768.png`. Is violet OK? **Default: keep violet.** The fallback is dark navy.
- **69. When 6+ enemies bunch up, their HP bars stack into rows** instead of overlapping (at most 5 rows). See `crowd-after-1366x768.png`. Does the stack read clearly, and is its height OK? **Default: keep.** The fallback is at most 3 rows, or off.
- **70. The card strip's backing is darker**, so an enemy walking under it no longer fights the card text. The enemy is dimmed, not hidden. See `strip-after-1366x768.png`. **Default: keep.** Keeping enemies out from under the strip would mean moving the camera; that's a feel change for after your play. (The playtester notes that ready and cooling cards now look closer; cooling shows through dimmed text and the bar. Say "70 stronger cue" if you want that boosted.)

## Later, optional

- **A second boss per act?** Every run meets the same three bosses (Brute, Corporate Raider, Guardian). That's within the slice scope (§10: "2 to 3 plus a final boss"), and endless mode already shuffles bosses (§9a). No default needed: it matters at content planning after Milestone 4.

- **Modern class names?** The Wizard may become the "IT Wizard" (your lean) and the others get modern names too (GDD §11 "Setting"). No default needed: names change in a naming pass when story work is scheduled. Send other name ideas whenever you have them.

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
