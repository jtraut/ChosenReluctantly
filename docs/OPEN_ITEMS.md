# Director open items

Last updated: 2026-10-28
**Status: Nothing is blocked.** Slices 4, 3b and 5 are done. The team is fixing chaser crowding (5d), then the screenshot tool and the end-of-pass check.

Owned by game-lead. Answer in chat with the ID, for example "D1 = A".

## Needs your decision

| ID | Question | Why it matters | Options | Recommended | If you don't answer | How to answer |
|---|---|---|---|---|---|---|
| D1 | Should the Game Over screen show run stats (time survived, kills)? | It's a small motivation hook. It becomes more useful once runs have rooms. | A: not now, revisit with the run structure (Milestone 3a). B: add time + kills now. | A | A | "D1 = A" or "D1 = B" |
| D2 | Hold-to-preview: should holding a card key show its exact hit area and cast on release? (Proposal only, nothing built.) | It helps players aim area cards precisely, but it costs input complexity. | A: park it until after Milestone 3a. B: build it as a Settings option. C: build it as the default. | A | A | "D2 = A/B/C" |
| D4 | The light attack dropped from 8 to 3 damage per hit so every damage card beats it. Is that the "crutch" feel you want? | Light alone now takes about 3x longer to kill (a golem goes from about 4 s to 10 s). Two area cards had to jump a lot: Shrug Bomb 5 to 12, Everyone Calm Down 8 to 16. | A: keep light 3 as built. B: light 4 and slow its auto timer (0.6 s to about 0.9 s), so cards need smaller bumps. C: lower the area slot's base cooldown (2.5 s) instead. | A (feel it first; B is a data-only change) | A | "D4 = A/B/C" |
| D5 | The new heavy attack does slightly less direct damage per second than light (4.7 vs 5.0), but its 50% Burn chance brings it to about 6.0 (measured 5.97 after a Burn bug fix). That beats light and the three area cards in a single-target fight. OK? | You said heavy should trade damage-per-second for burst and flavour. Burn is the element flavour you asked for, but with it the free heavy edges past some area cards on a single target. Area cards still win when several enemies are hit. The playtester asks the same question: must every card always beat the free heavy? | A: keep as built. B: lower the Burn chance on heavy to 20%, so every card beats it (about 5.2). C: lower heavy damage instead. | A (Burn is the flavour you asked for; B is a one-number data change) | A | "D5 = A/B/C" |
| D6 | The fire-resistant golem hits hard (9 damage) but warns you for only 0.45 s, the same as the small chaser. Give it a longer wind-up (0.7 s)? | Your density principle says danger should be readable and punishable. A hard hit with a short warning feels unfair. | A: 0.7 s wind-up. B: keep 0.45 s. | A | **A has now been applied** (acc26a4). Reply B to revert it. | "D6 = A/B" |
| D7 | (The playtester also recommends B after side-by-side screenshots.) Enemy HP bars: keep showing every bar always (your 2026-10-27 answer), or only show bars on damaged enemies, plus elites and bosses always? | With 12 enemies, always-on bars pile into overlapping red strips. Damaged-only cuts the clutter, but you can't see a fresh enemy's toughness until you hit it. | A: keep always visible. B: damaged-only, plus elites and bosses always. | B (ux-designer's pick; the playtester compares both next) | A stays (your earlier answer) | "D7 = A/B" |
| D3 | Enemy shots and the player's physical shots are the same cream colour. Should shots be tinted by team (enemy = red-ish)? | You currently have to tell incoming from outgoing shots by position. Fixing it is a small code change. | A: tint by team, in Slice 5. B: leave as is. | A | A, in Slice 5 | "D3 = A/B" |

The heavy redesign is built with these defaults: a 0.6 s stun, a 50% Burn chance, a 35% wind-up slow, and 8.5 damage. If any of them feels wrong, it's a one-number data change.

## Needs your eyes in the game

Play a normal run (not a test scenario: scenarios give the player 9999 HP).

1. **Death slow-motion.** Die once. Look for: you can clearly tell you died (white then red flash, grey-out, topple), and the slow-mo is long enough without dragging. Tell us "longer", "shorter" or "fine".
2. **Aim reticle.** Move the mouse around fast, at your normal resolution and at 1440p if you can. Look for: the ring follows the mouse without lag, the dots trail slightly during fast turns, and everything vanishes when you die.
3. **Enemy HP bars near the player.** Look for: bars over or next to your character never hide what you need to see.
4. **Heavy attack** (right click). Look for:
   - Does the stun (yellow stars) visibly freeze enemies, and does 0.6 s feel worth it?
   - Does the wind-up slow feel like commitment without being sluggish?
   - Does the area feel bigger and worth pressing?
   - About half of heavies set enemies on fire. Does that feel like a fun surprise or a letdown?
5. **Light attack vs cards** (feeds D4). Look for:
   - Does every damage card feel clearly better than the free auto attack?
   - The three area cards are only about 7-10% better than light on a single enemy. Do they still feel worth casting on one?
6. **New wave density** (Slice 5). Up to 12 enemies at once, arriving in four stages. Look for:
   - Is 12 at once too many for you? A perfect-aim test bot survives, but takes heavy damage.
   - Is the first wave of 4 chasers too hard to start with? We can drop it to 2 or 3 (data).
   - Is the golem's 0.7 s warning fair? Our captures never caught it attacking.
   - Can you always find yourself when enemies crowd you? Chaser spacing is being fixed next.
   - Can you read every enemy's warning: the red-pink ground wedge for chasers, and the lane strip for shooters?
   - Enemy shots are now pink, so they look different from yours.
7. **1.5x click cap.** Look for: spam-clicking helps a bit early but doesn't feel mandatory, and holding back feels fine.
8. **Light flash and heavy telegraph.** Look for: the light swing reads at full speed, and the heavy wind-up looks clearly different from its impact.

## FYI, no action needed

- The training dummy (the dark-red cylinder next to you at the start) is being removed from normal runs. It was a test aid that reads as an enemy. Scenarios keep it.
- The dark area at the top-left edge of the screen is the empty space past the arena floor (by design since 4b). It is not a bug.

- **Slice 5 changes you'll notice:**
  - The golem is now a capsule shape instead of a box, so its ground markers show its true hit area.
  - Invisible walls stop anything falling off the arena edge. A test bot found that bug.
  - Enemy HP bars are slightly smaller (width 1.4 to 1.2), as the Slice 5 brief asked, and are hidden behind enemies in front of them.

- **P5:** a bug fix made projectile cards use their real hit size. Flaming Nonsense now hits at 0.3 (it was 0.25).
- **P6:** the same fix made ranged enemy shots 20% wider (0.25 to 0.3). That was always the intended value; we kept it.
- Against the big golem, ground markers show about 20-30 cm less reach than the attack really has. It errs the safe way, and gets reviewed in Slice 5.
- The restart test used to fail about 1 run in 8. It was a harmless one-frame timing gap; the test now measures the gap and is stable.
- The GDD still has 10 long-term open design questions (section 14). None block current work; they come back as their milestones approach.
- A parked idea: show enemy HP as a number on the bar. Not scheduled.

## Recently resolved

| ID | Question | Your answer | Date |
|---|---|---|---|
| P1 | Spam-click gave 2.4x auto damage. Lower it? | Cap at 1.5x the auto rate, as a data ratio. | 2026-10-28 |
| P2 | Heavy attack DPS is below light. Give it a reason? | Heavy trades DPS for burst, area, stun and element flavour; heavy attacks are defined per class. | 2026-10-28 |
| P3 | Root or slow during the heavy wind-up? | A slight slow, never a root. | 2026-10-28 |
| P4 | Auto light beats cheap cards. Intended? | No. Cards must always beat the free attack: lower light, raise cheap damage cards. | 2026-10-28 |
| - | Clicking's role overall | An early-game crutch; it should feel unnecessary once the build takes shape. | 2026-10-28 |
| - | Polish pass before Milestone 3 | Approved: slices 0-5. | 2026-10-27 |
| - | Card reward offer format | Pick 1 of 3, or reject all (3 rejects per run). | 2026-10-27 |
| - | Enemy HP bar visibility and size | Always visible while alive; size is fine. | 2026-10-27 |
| - | Resistance marker reads as "armoured" | Acceptable for now. | 2026-10-27 |
| - | Who runs the team loop | game-lead orchestrates. | 2026-10-27 |
