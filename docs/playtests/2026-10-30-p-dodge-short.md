# Playtest: P-dodge (dodge pips, boss stagger, recovery) - short

Date: 2026-10-30. HEAD 7d3d966 (qa PASS). Tester: playtester, no hands: captures (`tools\UxCapture.tscn`, 1280x720), 20 s headless smoke, whole-run bot sim. Not played by a person at a window.

## Smoke check: PASS
- `--quit-after 1200 -- --run-seed=7 --class=rogue|wizard`: both exit 0, banner only, no ERROR/WARNING.
- Captures: Rogue 30/30 HP and Wizard 26/26 HP, player visible, camera frames the player, cards 1-5 show, no errors. Blocker: none.
- Not verified: live input (move, aim, dodge, slots 1-5) in a window; only bot-driven input.

Captures kept in `docs/playtests/img/pdodge-*.png` (rogue/wizard x pips, pips_recharge, pips_empty; stagger).

## Dodge pips (capture review)
- Rogue shows 3 pips, Wizard 2. A "Space" label sits under the LMB/RMB meters, in the same column and left edge. The cluster is small and tucked in: it does not crowd the meters or the HP bar. Good.
- Filled = bright cyan, recharging pip = partial fill, spent = dark. At a glance I could read "2 ready, 1 coming" on the Rogue.
- EMPTY: the frame turns red-pink and the word "EMPTY" appears. Clear, and not colour-only. Wizard 0 of 2 is unmistakable.
- Nitpicks (opinion): the pips are the smallest thing in the corner (about 36x22 px at 720p) while dodge is the most reflex-critical button. At the centre of the screen, where the eye is during a fight, they would not be seen; a player has to look top-left. A short flash or pop on the player when a charge returns would help (not built, not asked). In the Wizard EMPTY capture, the leftmost pip shows a thin sliver of recharge fill, readable but easy to miss; the word EMPTY does the job.

## Boss stagger (D16)
- Capture: the boss reels (tilted, pale-blue flash), "Hit it now" in blue under the name, and a sparkle-flanked "STAGGERED" banner with a draining bar. It reads as a reward window, and the wording tells a new player what to do. Good.
- Problem (small, capture only?): the STAGGERED banner sits directly on top of the boss's "Armor 50% - Resists all elements 50%" line, and the oversized 99999 damage number overlaps. QA already calls the number an artefact. The banner/armor overlap is real in this capture; worth a look at a real-sized hit.
- Flow in the bot sim (Wizard seed 4 and Rogue seed 4, log): stagger at 19.85 s, roar end 21.83 s = 1.98 s. Second transition: Rogue 36.90 to 38.88 = 1.98 s. That is 2.0 s with the boss not attacking. On paper that is OK: 0.8 s of "hit it" then 1.2 s of roar. Opinion: 2 s is the longest the boss should be passive; if W1b makes the boss tougher, keep it. The roar half is the weaker half (no reward, just waiting), but it also gives a breath to heal or reposition.
- Roar frame was never captured (qa noted it). I did not see "Invulnerable" visually either.

## Recovery at 12 s / 14 s (Wizard)
- Bot sim: HP at room end is back to full after most rooms, so Recovery is not what carries a run. Recovery cards were 5-8% of casts. Healing still matters in the boss: Wizard seed 4 went 8 HP to 18 HP in the 4 s after the first stagger (a Recovery card). That is a real "phew" moment, not something to lean on, since the cooldown is long. Verdict: right place, lean no. Caveat: the bot is not a person, and the director may want to watch whether a human feels 14 s as "I wait forever".

## Wizard boss "cliff" (data for W1b)
Reproduced seed 3 (Wizard, boss room: died at 11.6 s of boss time, 13.6 s room time). Instrumented the boss (temporary local patch to `tools/wave_sim.gd`, reverted, nothing committed) to log every telegraph:
- The boss chose Fan of regrets (volley) four times in a row (3.5 s, 6.4 s, 9.3 s, 12.2 s). HP before each: 26 -> 16 -> 6 -> 1. Each volley cost about 10 HP (two 5-damage pellets), then the last one finished it.
- It never reached the 66% threshold, so there was no stagger and no phase 2, and no heal in between.
- Why the Wizard: the kiting bot stays at range, where smash (reach 4.2) cannot hit but volley (min range 4, to 18) is the boss's only always-valid ranged option, so it fires a lot. Seed 4 also shows it: three volleys cost 26 -> 11 early, then it recovered after the stagger.
- Takeaway for W1b: the cliff is the volley in phase 1 against a kiter, not the charge or slam. Phase 1 at 5 dmg x 5 pellets = 25 max against 26 Wizard HP is a one-fan-from-dead window. Options: lower pellet damage or count for phase 1, a longer gap between volleys, or an easier-to-read pellet fan. This is a bot behaviour caveat: a human reads the fan and sidesteps. The bot's dodge may not be reacting to volley pellets.
- Rogue (30 HP, seed 4) took zero damage in the boss. The Rogue is trivial here; same-seed Wizard lost 18 HP. The classes are far apart in this room.
- Note the "hit=false" on volley "LANDED" is the fire event, not the hits; I could not tell per pellet hit counts.

## Top 3 things that work
1. The dodge pips: small, aligned with the meters, 3 vs 2 is visible, EMPTY is clear.
2. "STAGGERED / Hit it now" gives the new player the right instruction in the right moment.
3. The stagger-then-roar pacing is a clean 2.0 s beat; phase changes feel like events.

## Top 5 problems
1. Wizard boss phase 1: the volley alone can empty 26 HP in about 10 s with no heal window (seed 3). Suggest tuning volley damage/count/gap for phase 1, or check the bot is dodging pellets, before treating it as a real balance issue.
2. Rogue boss is nearly harmless (seed 4: no damage in 59 s, many slams in a row). Boss fights range from "nothing" to "dead" by class. Suggest W1b tune against both.
3. Pips sit far from the action (top-left). Suggest a return flash or sound cue when a charge refills; or an optional pip ring at the player.
4. STAGGERED banner overlaps the boss's Armor/Resists line; check with a normal hit, not 99999.
5. The roar half of the 2 s transition is dead air. Fine for now; watch it if the boss fight gets longer.

## Questions for the director
1. Is the Rogue's boss fight meant to be this easy (no damage taken) at 3 charges?
2. Do you want a charge-return cue (flash or sound) near the player, or are the top-left pips enough?

## Suggested next playtest focus
W1b after tuning: both classes, 12 seeds, per-attack cost in the boss room, and a human-in-window pass of dodge feel (does 1.2 s feel right, does the Wizard's 2 charges feel punished?).
