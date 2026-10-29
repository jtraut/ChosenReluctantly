# Playtest: Milestone 3a, run structure

Date: 2026-10-29. Build: HEAD of main (c386a0d). Playtester.

## Build and setup
I cannot hold a mouse or key. Everything comes from windowed captures of the real normal launch (`capture_screenshot.ps1 -Scenario ""`, 1280x720, `--run-seed/--run-room/--run-clear-after`) and the whole-run sim (`run_wave_sim.ps1 -Run -Scale 1`, real HP, seeds 3 and 5-10 by me; qa ran 1-12). Captures use an idle player, so combat feel is not judged here; "observed" means a screenshot or sim line. Hand feel of an elite or boss fight is theory plus numbers. Screenshots (gitignored): `screenshots/m3a/` (`r1_*`, `clear1`, `rest3_*`, `elite6_*`, `elite9_*`, `boss_*`, `win`).

## Smoke check: PASS
- `godot --path . --headless --quit-after 600`: version banner only, exit 0, zero error or warning lines.
- All 10 capture launches ran with zero error or warning lines.
- Normal launch shows green floor, blue player, red chasers, HP "30 / 30", five card slots with "Next:" lines, and "Room 1 of 8 - Combat" top centre with a circle icon, clear of the HP bar and cards (`screenshots/m3a/r1_1.png`).
- Scenarios still open the arena (qa verified all 19; I did not repeat it).
- Not tested by hand: real WASD, dodge, click, 1-5 presses. The sim bot uses the real actions and clears 8 rooms, so the input paths work.
- No blocker.

## Run flow verdict: reads clearly; transitions look fine on paper
| Beat | Observed |
|---|---|
| Room indicator | "Room N of 8 - Type" with a shape icon (circle combat, diamond elite, plus rest, star boss), colour-coded. Always visible. Good. |
| Cleared panel | Dims the world; title "Room cleared", the room's icon, "Room 1 of 8 - Combat", HP 30 / 30, Time, big Continue, "Enter or Space" hint (`clear1.png`). Clean. |
| Rest room | "Room 3 of 8 - Rest", green plus icon, "Healed +0" (`rest3_0.png`). At full HP the rest room is a button press that says nothing happened. See issue 1. The "You rest. It helps a little" line was not visible in my shot. |
| Elite | Diamond in the indicator and a diamond sign above the elite's HP bar, seen on the dimmed Game Over frame (`elite9_3.png`). In the lit frames only plain chasers had spawned (idle player, elites arrive after the first stage), so I did not see the sign in live light. One elite spawned at the bottom edge, partly under the card row. |
| Boss | Star in the indicator (`boss_0.png`). I did not capture the golem boss spawning. |
| Win screen | "Run complete", star, "Somehow, you finished. Nobody is more surprised than you.", three stats, New run (`win.png`). Tone lands. Its "1 / 8" is the known debug-launch artefact. |
| Game Over | "Well. That went badly." plus "Reached room 4 of 8." and Try again (`elite9_3.png`, `boss_1.png`). Good, minimal. |
| Try again, New run | Buttons present; the new-seed reload is qa-verified (soak). I did not play it by hand. |

Transitions: I cannot see animation. The cleared panel appears over the frozen room and Continue swaps in a fresh scene, with no fade, preview or intro beat. Likely abrupt but short. See issue 3.

## Pacing numbers (sim, real time, bot, full 24-card deck)
All runs won, none soft-locked, 259-291 sim seconds (about 4.5 to 5 minutes).

| Seed (types) | Room seconds | Lowest HP in each room |
|---|---|---|
| 3 (c,c,r,c,c,e,c,b) | 22.8 28.8 0 35.8 26.2 48.7 28.4 **97.5** | 30 26 30 10 24 24 18 18 |
| 5 (c,c,r,e,c,c,c,b) | 25.8 27.1 0 56.4 30.4 23.4 29.6 65.8 | 25 26 30 21 22 26 26 30 |
| 9 (c,c,c,e,c,c,r,b) | 22.6 28.1 32.4 49.8 33.7 32.1 0 68.7 | 26 21 22 28 18.8 **8** 30 17 |
| 6, 7, 8, 10 | boss room 97.8, 81.4, 95.1, 85.8 | in-room lows 8 to 30 |

- Combat rooms 20-35 s. Elite room 42-65 s. Boss room 65-98 s, about 25 to 35 percent of the run in the last room.
- Attrition: confirmed nil between rooms (HP at last room clear 29-30 in every run). Inside a room the bot dips to 8-18 HP, so there is real pressure that the Recovery cards erase by the next room.
- Run length: 4.5 to 5 minutes for a bot, so perhaps 8 to 12 by hand. Fine for a 3a prototype; well under the GDD 15-25 minute proposal, expected before rewards exist. 8 rooms is about right for now; more rooms of the same fight would only add repetition.
- Boss drag (theory, not felt): a 7x HP golem with 25% resistance, chipped by 3-damage light attacks and resisted fire cards, risks being "kite and wait for cooldowns".
- Elite distinct: yes by numbers (42-65 s vs 20-35 s) and by sign. Live it is the same capsule shape with more HP, so it is distinct by stats, not by feel.

## Top 3 things that work
1. The room indicator and shape language. Circle, diamond, plus and star read without colour, and the same shape appears in the HUD, the panel and over the enemy.
2. The cleared, win and lose panels. One big button, keyboard hint, and the tone ("Somehow, you finished", "Well. That went badly.") fits the cheerful world and weary hero.
3. Run shape. Combat, rest, elite, boss with seeded positions gives a recognisable roguelite rhythm, and an idle player still dies in about 10 s in rooms 4-8.

## Top 3 issues by player impact
1. **No attrition, so rest and healing mean nothing.** Every room ends at 29-30 HP and the rest room shows "Healed +0". It is the run's first promised decision and it is a dead beat. Suggestion: it is already D13 plus the 3b starter shrink; for 3a, to test it, trim 2-3 Recovery cards from `starting_deck` in `data/run.json` (data only) and re-run the sim to see if HP carries; and let the rest panel say "You are fine. The nap was lovely anyway." when healed is 0.
2. **The boss room drags and is just a bigger room.** 65-98 s, a third of the run, a 7x-HP resistant golem distinguished by a star sign. Suggestion: data-only, lower the boss HP multiplier from 7 to about 4 and the boss resistance floor, aiming for 45-60 s, and give it a visibly larger `scale`. 3c replaces it, so keep it cheap.
3. **Room changes are silent about what comes next, and the tier sign is small.** Continue goes straight into the next room with no preview. Suggestion: add "Next: Room 5 of 8 - Elite" with the shape under Continue, and a short room intro. Keep elites from spawning under the card row.

## Other observations
- Build variety is nil in a run: the starting deck is all 24 cards, so every run plays the same. 3b is the fix. Bot pick rates 0.9x-1.09x show the bag works.
- Death shows "Reached room X of 8" but not what killed you (known gap).
- The rest room says "Room cleared", odd for a room with nothing to clear.

## Questions for the director
1. Should a rest room appear when the player is at full HP, or only after damage? Today it is a no-op.
2. Is the 7x HP, 25%-resistant boss wanted for 3a, or is 65-98 s a placeholder 3c replaces?
3. Do you want a "Next room" preview on the Continue panel now, or only once the 3b reward screen exists?
4. Is about 5 bot minutes (8-12 by hand) acceptable for 3a, with the 15-25 minute target left to 3b and 3c?

## Suggested next playtest focus
3b: reward offers and the shrunken starter deck. Re-measure attrition and whether the rest room matters; check whether accept or reject tension exists and whether two runs feel different. Ideally the director plays one run by hand and reports boss room time and where HP dropped.
