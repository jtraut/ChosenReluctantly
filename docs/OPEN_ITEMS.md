# Director open items

Last updated: 2026-10-28
**Status: Nothing is blocked.** The team is building your 2026-10-28 attack decisions, then finishing the polish pass.

Owned by game-lead. Answer in chat with the ID, for example "D1 = A".

## Needs your decision

| ID | Question | Why it matters | Options | Recommended | If you don't answer | How to answer |
|---|---|---|---|---|---|---|
| D1 | Should the Game Over screen show run stats (time survived, kills)? | It's a small motivation hook. It becomes more useful once runs have rooms. | A: not now, revisit with the run structure (Milestone 3a). B: add time + kills now. | A | A | "D1 = A" or "D1 = B" |
| D2 | Hold-to-preview: should holding a card key show its exact hit area and cast on release? (Proposal only, nothing built.) | It helps players aim area cards precisely, but it costs input complexity. | A: park it until after Milestone 3a. B: build it as a Settings option. C: build it as the default. | A | A | "D2 = A/B/C" |
| D3 | Enemy shots and the player's physical shots are the same cream colour. Should shots be tinted by team (enemy = red-ish)? | You currently have to tell incoming from outgoing shots by position. Fixing it is a small code change. | A: tint by team, in Slice 5. B: leave as is. | A | A, in Slice 5 | "D3 = A/B" |

More items will appear here when the heavy-attack redesign proposes its numbers: stun length, element status chances, wind-up slow, and the light-vs-card damage rule.

## Needs your eyes in the game

Play a normal run (not a test scenario: scenarios give the player 9999 HP).

1. **Death slow-motion.** Die once. Look for: you can clearly tell you died (white then red flash, grey-out, topple), and the slow-mo is long enough without dragging. Tell us "longer", "shorter" or "fine".
2. **Aim reticle.** Move the mouse around fast, at your normal resolution and at 1440p if you can. Look for: the ring follows the mouse without lag, the dots trail slightly during fast turns, and everything vanishes when you die.
3. **Enemy HP bars near the player.** Look for: bars over or next to your character never hide what you need to see.
4. **Heavy attack** (after the redesign lands). Look for: the stun visibly freezes enemies, the wind-up slow feels like commitment without feeling sluggish, Burn procs more often on heavy, and the area feels bigger and worth pressing.
5. **Light attack vs cards** (after the rebalance lands). Look for: every damage card feels clearly better than the free auto attack.
6. **1.5x click cap** (after it lands). Look for: spam-clicking helps a bit early but doesn't feel mandatory, and holding back feels fine.
7. **Light flash and heavy telegraph.** Look for: the light swing reads at full speed, and the heavy wind-up looks clearly different from its impact.

## FYI, no action needed

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
