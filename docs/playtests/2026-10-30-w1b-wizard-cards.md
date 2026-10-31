# Playtest: W1b, Wizard cards and risk (2026-10-30)

Playtester, HEAD 5ce0613 (qa PASS). No hands: I played through captures, scripted scenarios and the bot sim. Nothing below is "I played it and felt X". Facts I saw are marked as such; opinions are labeled.

## Build and setup
- Windows, Godot 4.7.2 console build. Screens captured windowed at 1280x720 with `tools\capture_screenshot.ps1`; scenario shots of the four new cards used a scratch copy of the project (in the scratchpad, not the repo) with four extra scenarios (`pt_volley`, `pt_overq`, `pt_nova`, `pt_ward`) that force one card cast on six chasers. **Tooling quirk:** scenarios give the Wizard body but the card row shows the Rogue's deck, so I draw no HUD or deck conclusions from those frames; HUD observations come from the real run frames.
- Sim: `run_wave_sim.ps1 -Run -Runs 12 -Seed 31 -Scale 1 -BossLog -Class <c>` for six configs, seeds 31-42 (a fresh seed block, independent of qa's 1-24): Rogue and Wizard kiting, each with and without `-DodgePellets`, plus Wizard `-WizardNoKite` with and without `-DodgePellets`. 72 runs, 0 engine errors or warnings in any output.
- Frames cited here are in `docs/playtests/img/w1b-*.png`.

## Smoke check: PASS, no blocker
- `--headless --quit-after 600 -- --run-seed=7 --class=rogue|wizard`: exit 0, 0 error or warning lines, both classes. `--list-decks` lists all 6 presets.
- Windowed Rogue run (`w1b-rogue-run.png`): floor, blue player, two chasers, "HP 30 / 30", 3 dodge pips, 5 card slots, room indicator "Room 1 of 10 - Combat". Camera frames the player.
- Windowed Wizard boss room (`w1b-boss_*`, `w1b-boss21_*`): purple player, boss, "HP 26 / 26", 2 dodge pips, boss bar with phase and "Armor 50% / Resists all elements 50%", Wizard card row with the new names ("Three Bolts, Reluctantly" and "Personal Space, Enforced" shown in the slots). No errors in capture output.
- Not verifiable here: real keyboard and mouse input. Card casting was verified only through the scenario's scripted casts (all four new cards cast `ok=true` and the slots cool down as the data says, 1.2 / 1.8 / 2.0 / 5.0 s).

## Top 3 things that work
1. **The Fan of regrets telegraph is clear and fair.** At wind-up the boss turns orange, five translucent lanes fan out from it, and the bar says "Fan of regrets" with a draining strip (`w1b-boss21_3.png`). Pellets are bright pink, large and trail-ed (`w1b-boss21_5.png`). A new player can tell what is coming, where, and how long they have.
2. **The nova reads as what it says.** "Personal Space, Enforced" is a wide pale ring that throws every neighbour outward, and it puts an 11 over each of six chasers at once (`w1b-pt_nova_2.png`). It is the clearest "oh nice, that was a good thing to press" moment among the four cards. The pale ring is the same colour whatever the element, so it does not look "fiery", but it is easy to see.
3. **The names and flavor lines hit the tone.** See problem 5 below for the nits; most of them are on target.

## Top 5 problems, ranked

**1. Ward, Technically has no visible cue while it is up.** (Observed.) On cast there is a faint gold ring under the Wizard for about half a second (`w1b-pt_ward_1.png`). One and a half seconds later, with 2.5 s of armor left, the Wizard looks identical to a Wizard with no Ward (`w1b-pt_ward_3.png`). The only buff cue in `TemplateVfx.buff` is that shared 0.5 s ring, and I found no player armor or buff readout on the HUD (armor shows only on enemy and boss bars). A player will press the card, see almost nothing, and not know whether it is on, whether it ended, or whether to keep playing "into" it. Because the whole point of the card is a 4 s window, the player needs to see the window. Suggestion: a persistent shimmer or tinted ring on the player for the duration, and a small buff pip with a draining bar next to the dodge pips. Also, the card's value is one third off physical and neutral only; fire from enemies is untouched. Worth one sentence on the card or in a tooltip so it does not feel broken when a fire hit goes through.

**2. A Wizard who kites well pays almost nothing, then the boss volley asks for a lot. Is that "not the easy way out"?** (Sim, labeled; my proxy for HP cost is the room's deepest dip below max HP, so it overstates the absolute numbers qa's per-room figure gives, but is the same for every config.)

| Config (seeds 31-42) | Won | Boss time | vs Rogue | Dip per combat/elite room | Boss-room dip | Boss-room HP taken per run |
|---|---|---|---|---|---|---|
| Rogue, default bot | 11/12 (seed 36 lost in room 2) | 59.9 s | 100% | 7.0 | 7.8 | 7.7 |
| Rogue, DodgePellets | 12/12 | 58.2 s | 100% | 4.6 | 4.8 | 4.5 |
| Wizard kiting, default | 12/12 | 70.1 s | 117% | 1.8 | 10.5 | 19.6 (88% volley) |
| Wizard kiting, DodgePellets | 12/12 | 72.2 s | 124% | 0.7 | 6.4 | 7.9 (76% volley) |
| Wizard non-kiting, default | 12/12 | 45.9 s | 77% | 5.3 | 5.6 | 5.1 (62% adds) |
| Wizard non-kiting, DodgePellets | 12/12 | 45.6 s | 78% | 3.0 | 2.4 | 2.1 |

   Reading it: the non-kiting Wizard (walks in like the Rogue) loses a quarter to a third less HP than the Rogue per room (24% and 35% less by my proxy) and dies faster to the boss than the Rogue, which matches D18 = A "costs some HP, less than the Rogue's". The kiting Wizard is different: rooms 1-9 cost 0.7-1.8 HP (14-25% of the Rogue), which is "almost free", and then the boss volley is the only thing that ever hurts. In my default-bot run the kiting bot paid 19.6 HP per boss fight on a 26 HP body and all 12 survived, but by margin. A player who can kite (6 m/s against the chaser's 4 m/s) will find rooms 1-9 a stroll. That is the thing D18 said it did not want. This echoes qa's findings (N1 and N2) from a different seed block; qa's three kiting-default deaths on seeds 13-24 did not repeat on 31-42 (0 of 12), so the cliff is real but not reliable. I would not tune against my 12 seeds alone. Suggestion: the lever to touch is how much a kiter is threatened in rooms 1-9, not the boss (no enemy changes were allowed in this slice, so this is a director/game-lead call; see questions).

**3. The Fan of regrets is fair in the capture, but the geometry leaves little room for a late reaction and the lanes fill the screen.** (Theory, from data, plus the capture.) Wind-up 0.9 s (about 0.77 s in phase 3), pellet 9 m/s, spread 48 degrees over 5 lanes, so lanes are 12 degrees apart. The gap between neighbouring lanes is about 0.21 x distance, so a body about 0.75 m wide (pellet 0.35 radius plus player) only fits between lanes beyond roughly 4-7 m; closer than that the lanes are one solid wedge and the only safe move is out of the 48 degree wedge, sideways, or a dodge. The Wizard walks at 6 m/s, so 0.9 s is about 5 m of sidestep: enough if you start at once, not if you read the label first and think second. The capture (`w1b-boss21_3.png`) shows the lanes cut off at the screen edge. The bot that does step out of pellets takes 2-4% of pellets; the one that does not takes 11-14% and loses 17 HP per boss fight to the volley. That is the size of the gap between "reads the telegraph" and "does not" (a human who reads it is much like the dodging bot). A human new to the game will take at least one volley (5 per pellet, one pellet landed in my idle capture, `w1b-boss21_5.png`). Not a blocker. Suggestions: cap lane length to what is on screen; make the lane brightness ramp up as the wind-up ends so the "now" moment is obvious.

**4. The new bolts are hard to tell apart from the auto bolt, and the Three Bolts promise is only half kept on screen.** (Observed.) "Three Bolts, Reluctantly" shows as three separate pale puffs spaced down one lane (`w1b-vburst_1.png`), which does read as a burst. But it is a single line, not a fan, and the puffs are the same white as the auto bolt's pebbles; "Overqualified Bolt" (`w1b-pt_overq_1.png`) I could not catch in flight at all, only the "11" it leaves. Both are pale, small, and white, while the boss's pellets are loud pink. The Wizard's cards do not look as dramatic as the boss's. Damage numbers help: 11 and 11 are big, white, outlined. Suggestion: give the Overqualified Bolt a larger, brighter head and a short flash on release, so a 1.8 s cooldown, 10.5 damage card feels weightier than three pebbles. The three hits of the volley also show as one grey "4" in one frame (`w1b-pt_volley_1.png` shows a white 4, the next frame a faded grey 4); I did not work out whether three hits of about 2 stack into one number or only one landed; I'd like gameplay-dev to confirm, but I am not calling it a bug.

**5. Auto bolt feel and the one boss knockback.** (Theory plus capture.) The Wizard's auto bolt is 1.5 per 0.6 s, which is 2.5 DPS against the Rogue's 5.0 (3.0 per 0.6 s); the heavy is 5.5 per 1.8 s. A 20 HP chaser takes 8 s to kill on auto alone and 4 s for the Rogue. The chaser walks 4 m/s; the bolt reaches 12 m, so a chaser closes the whole range in 3 s having taken about 7.5 damage, and arrives at about 12 HP. So auto alone cannot stop even one chaser; the card cooldowns, the heavy and kiting at 6 m/s have to do it. (I cannot say how it feels in the hand; the numbers say "weak but workable for a kiter, a grind for anyone else".) The non-kiting policy kills the boss 22% faster than the Rogue, so power is not a problem overall: it is the auto bolt specifically, and how the player gets there. Also seen: an idle Wizard hit by the boss's Overhead smash (8 damage) is knocked about 8 m, ends at the arena edge looking at the void with the boss off screen (`w1b-boss_9.png`, `w1b-boss_10.png`). I am logging this as a possible bug for QA, not diagnosing it: either it is the intended knockback of 9 and the camera needs to keep the boss in view, or the player can be knocked out of bounds.

   Honest summary of how I'd answer the director's question: "too weak to feel good": unknown without hands; likely fine because it is not the Wizard's main damage source, but flag it for the first human run.

## Do the 4 new cards make the Wizard feel distinct from the Rogue?
Theory plus captures; by role, yes. The Rogue's melee cone cards hit what is in front; the Wizard now has a bolt volley, a heavy single bolt, a knockback nova and an armor buff, and all of its attack cards use "neutral" damage, so armor and resistance on enemies matter for the Wizard (the boss's 50% armor and 50% elemental resistance are shown in the bar). The distinct feels:
- Volley is a "tap and keep walking" card (1.2 s cycle, 6.6 damage).
- Overqualified is a "line it up" card (1.8 s, 10.5).
- Nova is the panic button (2.0 s, 10.5 to everyone within 3.2 m, 7 knockback). The cooldown modifier -0.5 on the AoE slot is the easiest card to trust.
- Ward is the odd one: the only card that is not damage, and the least visible (problem 1).
On screen, only the nova looks different from a Rogue card. The two bolts look like the auto bolt, only bigger numbers (problem 4). Card damage margins over the Rogue's light (qa's table: 5.5, 5.83, 5.25 DPS against 5.0) are thin: the nova is only 5% above, so a player will not feel a strong reason to use a card over holding left click with a Rogue; for the Wizard the auto bolt is half of that, so cards matter more and the margins hold.

## Names and flavor (item 5 of scope)
- Land: "Three Bolts, Reluctantly" and its line "One would have been plenty. Rules say three."; "Personal Space, Enforced" with "A ring of arcane disapproval. Everyone steps back."; "Overqualified Bolt" with "A lot of education went into this. It shows on impact." These are dry, specific, and do not slow the player down. The existing "Tactical Hover: Not fleeing. Repositioning. Loudly." keeps the same register.
- Soft: "Ward, Technically" is a good name and "A thin shimmer between you and consequences." is a good line, but see problem 1: the card promises a shimmer and the game shows none. The joke is lost when the screen does not agree.
- The card row's long names ("Personal Space, Enforced", "Three Bolts, Reluctantly") wrap to two lines on the 1280x720 slots but stay readable.

## Questions for the director
1. **D20 (already filed):** this playtest agrees with qa: Wizard HP is 26 so it is not squishier than before. My sim says the HP does not drive the risk anyway: the risk is "kiter pays nothing in rooms 1-9, then the volley". Which do you want to fix: a lower HP (B/C), or a way for the room enemies to threaten a kiter (needs enemy changes)? The brief forbade enemy changes in W1b.
2. Is "a Wizard who kites well is nearly free until the boss" acceptable, or is that the easy way out you meant to prevent?
3. Auto bolt at 50% of the Rogue's DPS (and heavy 5.5): keep for a first human try, or tune now?
4. Ward needs a visible cue. Is a persistent player-side effect (ring, tint, pip) in scope for W1c or 3d?

## Code bugs to log (not diagnosed)
- Seed 36, Rogue, default bot, `-Run`: LOST in room 2 with lowest HP 1.0 (12 seeds, 31-42). qa had 24 of 24 Rogue wins on seeds 1-24, so this is a new data point; it did not happen with `-DodgePellets` (12/12).
- Idle Wizard knocked to the arena edge by the boss's smash with the boss off screen (frames above), see problem 5.
- Volley hits showing a single faded "4" (problem 4), unconfirmed.

## Suggested next playtest focus
1. A human first run as the Wizard (rooms 1-4 only): does the auto bolt feel good, and does a player understand what Ward did? That is the thing I cannot judge from here.
2. After any Ward cue is added: does a player notice when it ends?
3. Offer mix and deck variety once presets are used: `fire-heavy-wizard` against `arcane-heavy-wizard` boss runs under the same seeds.
4. Capture tooling: a scenario that gives the Wizard its own deck (the scenario row shows the Rogue's deck) and a `--screenshot-after` that can wait for "the boss started a volley" instead of a fixed time. I would like both from gameplay-dev.
