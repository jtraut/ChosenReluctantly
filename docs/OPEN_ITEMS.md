# Director open items

Last updated: 2026-11-05 (BD2 closed; latest tag `playtest-2026-11-05-BD2`)
**Status: nothing waiting on a decision; 4 things to look at (49 new, 48, 47, 35), plus the round 2 vision check, which is now due. Next: MAP1 (map, treasure chests) -> MAP2 (merchant, shop-only relics) -> MAP3 (three acts, save and resume, rare/legendary cards, boss relics) -> MAP4 (events, curse cards, sacrifices, rest dig; probably two sittings) -> 3d (loadouts, starter relic).**

Only active items live here. Everything you've answered or acknowledged is in `docs/RESOLVED.md` (newest first). Owned by game-lead. Answer in chat with the ID, for example "D31 = A".

## How to playtest

- **Latest known-good build:** `git checkout playtest-2026-11-05-BD2`, play, then `git checkout main`. The one before it is `playtest-2026-11-04-BD1`.
- **Relics:** `-- --relics=pyre_insurance+heavy_sigh` starts with relics; `-- --relic-cap=1` tries the give-one-up step. Older tags are in `docs/RESOLVED.md`.
- **Normal run:** `godot --path .` (10 rooms). Extras: `-- --run-seed=5`, `-- --run-room=10` (boss), `-- --class=wizard`.
- **Preset decks:** `godot --path . -- --list-decks`, then for example `-- --deck=fire-heavy-rogue --full-deck --run-room=10`.
- **Keys (since H3):** WASD move · mouse aims · left click light (also auto-fires) · right click heavy · **Space dodges** · **Q, E, F, Ctrl, R** cast Attack, Area, Utility, Movement, Recovery (hold to aim, release to cast; Q/E/F/R still work while Ctrl is held) · Shift + the same key swaps · Esc pause · F3 debug. On Windows with several keyboard layouts, Ctrl+Shift may switch layout.
- **The boss volley on its own:** `godot --path . -- --scenario=boss_volley`.
- **Test scenarios** (9999 HP): `godot --path . -- --scenario=<name>`; the list is in `data/scenarios.json`.

## Needs your decision

Nothing right now. Your D39 = A (the dodge doesn't count as a Movement cast) is recorded in GDD §4a. Next new number: D40.

## Needs your eyes

Reply with the number and a word or two.

49. **Try the relics (BD2).** A normal run (`godot --path .`) now has a relic room (no fight) somewhere in rooms 3-9, and the elite gives a relic instead of cards. Six relics: Pyre Insurance, Smoldering Grudge, Lingering Embers, Second Wind (Unwillingly), Spite Knuckles (Rogue only) and Heavy Sigh.
    - **Quick start:** `godot --path . -- --relics=pyre_insurance+heavy_sigh+spite_knuckles` (Rogue). Hit Burning enemies with heavies and watch the top-left chips flash.
    - **When something explodes, can you tell which relic did it?** Today only the corner chip says so; the playtester wants a label at the blast.
    - **Do relics change how you play,** or are they silent numbers? The playtester guessed Heavy Sigh and Spite Knuckles do, and Pyre Insurance and Smoldering Grudge don't.
    - **The relic room can land on room 9, just before the boss** (about 1 run in 3). Too late? The playtester would say "by room 7". The map (MAP1) replaces this room, so I'll apply your answer there.
    - **Spite Knuckles' "every 4th light hit" restarts each room.** OK, or should it carry over?
    - **The give-one-up step:** `-- --relic-cap=1`, then take a second relic. Cancel is focused first, so Enter backs out.
    - **BD1 fixes nobody has checked in play yet:**
      - the bigger primed marker and its "USED" flash;
      - the dim "Needs Burn" reason on a slot that isn't ready;
      - the gold "Keystone + Payoff" chip.
    - **Changed from the plan:** Exit Strategy slipped to BD3 (it needs new placement code).

48. **Try the BD1 archetype decks** (new cards and combo cues). Launch with `godot --path . -- --deck=<id>`, adding `--run-room=10` for the boss.
    - **rogue-hit-and-run:** dash with Ctrl, watch Drive-By light up yellow ("LIVE"), and cast it. Then press Space instead and see how long it takes to work out why it stays dark. The dodge doesn't count, per your D39 = A.
    - **wizard-controlled-burn:** check that Heat Sink lights while your Zone is out. qa's sim says this deck is strong: about 59% of the standard boss time.
    - **wizard-departure-lounge:** do you end up in melee range? The playtester's bot did, at 3/22 HP.
    - **rogue-kindling:** does Burn feel like a plan?
    - **A plain run:** your random starting slots can now roll the new cards. Does that confuse you?
    - **What to look for:** does the yellow glow read at a glance mid-fight? Do you notice the small cyan bolt when a slot is primed? Does a Keystone offer on the reward screen feel exciting? The playtester thinks the primed marker and Keystone chip are too quiet; ux fixed those in BD2 (see 49).
    - **A correction:** I called them "8 new Fire cards" earlier. By pool they're 4 Fire, 2 Rogue and 2 Wizard.

47. **My numbers for your relic and card tiers** (`docs/MAP.md` §4.5). Say if any feel off; they're all data.
    - Relic tier odds: act 1 80/20/0, act 2 15/70/15, act 3 5/25/70 (tier 1/2/3). They apply to every relic source (elite, relic stage, merchant), not just elites.
    - Card odds per offer slot: act 2 20% rare; act 3 30% rare and 8% legendary.
    - The boss-relic pick can't be skipped, and you can't give up a boss relic at the cap, so you always end with 2.
    - Mini-bosses still give gold, and their rare/legendary card offer can be rejected with a reject token.
    - Ballpark: a relic hunter ends with about 14-17 relics, a route that ignores relics with about 6-8 (both include the 2 boss relics).
    - Cost to know about: this needs about 6 boss relics, 5 rare and 4 legendary cards per class, so MAP3 may split in two.
35. **Builds (BD2 is in, so this can be played now; whenever you have time).** Build the same class and element twice with different plans. Do the two runs feel different? Does removing a keystone card hurt?

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
