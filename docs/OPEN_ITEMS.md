# Director open items

Last updated: 2026-10-28
**Status: Nothing is blocked.** Your card-expansion request is queued as Content slice C1, right after the tooling task now in progress. Slices 4, 3b and 5 are done. Next: chaser crowding (5d), then hold-to-preview casting plus a small settings screen (Slice 6, your D2 answer), then the screenshot tool and the end-of-pass check.

Owned by game-lead. Answer in chat with the ID, for example "D1 = A".

## Needs your decision

| ID | Question | Why it matters | Options | Recommended | If you don't answer | How to answer |
|---|---|---|---|---|---|---|
| D9 | Should Stealth (Shadow Step) also make enemies lose track of you, or only let you pass through them? | Losing aggro is much stronger and needs enemy AI work. Pass-through alone is cheap. | A: pass-through only. B: also drop aggro for its duration. | A | A | "D9 = A/B" |
| D10 | Allow duplicate copies of a card in a deck? (Copies never count toward the unique minimum.) | Later rewards may grant copies. Banning them would limit reward design. | A: allow. B: one copy per card id. | A | A | "D10 = A/B" |
| D11 | Neutral cards (Backward Leap, Leech, Regeneration): neutral colours, or your element's colour? | Neutral cards work for every class and element. Owner colour makes them feel like yours; neutral colour makes them recognisable as neutral. | A: neutral palette. B: owner's element colour. | A (simplest; one data value later) | A | "D11 = A/B" |
| D12 | Order: your note said "ahead of Slice 5", but Slice 5 is already done. Plan: finish the tooling task in progress, then C1, then one end-of-pass playtest that covers C1 too. OK? | It avoids interrupting a task midway, and saves a separate playtest run. | A: as planned. B: C1 first, then pause the tooling task. | A | A | "D12 = A/B" |
| D8 | A bug fix halved the dodge roll. It used to slide about 7 m; now it stops at its set 3.5 m. Which do you want? | Our test bot now takes about 2.5x more damage with the same seed. Dodge is your main defence against telegraphs. The safe window (0.25 s) is the same either way. | A: keep 3.5 m (as originally set). B: restore about 7 m by doubling dodge speed (same safe window). C: about 5 m, in between. | B (keeps the feel you've been testing; one value) | B, applied in the next gameplay task (dodge values also move into data) | "D8 = A/B/C" |

## Needs your eyes in the game

Play a normal run (not a test scenario: scenarios give the player 9999 HP).

0. **New cards (after C1 lands).** Try every new card: Bleed Slash, Flurry, Fireball, Fire Wall, Shadow Step, Lunge Strike, Backward Leap, Leech and Regeneration (working names). Tell us which feel great, which feel dull, and which to cut or rework. Also: does the full deck feel different from run to run?

1. **Death slow-motion.** Die once. Look for: you can clearly tell you died (white then red flash, grey-out, topple), and the slow-mo is long enough without dragging. Tell us "longer", "shorter" or "fine".
2. **Aim reticle.** Move the mouse around fast, at your normal resolution and at 1440p if you can. Look for: the ring follows the mouse without lag, the dots trail slightly during fast turns, and everything vanishes when you die.
3. **Enemy HP bars near the player.** Look for: bars over or next to your character never hide what you need to see.
4. **Heavy attack** (right click). Look for:
   - Does the stun (yellow stars) visibly freeze enemies, and does 0.6 s feel worth it?
   - Does the wind-up slow feel like commitment without being sluggish?
   - Does the area feel bigger and worth pressing?
   - About half of heavies set enemies on fire. Does that feel like a fun surprise or a letdown?
5. **Light attack vs cards** (your D4 playtest; light damage is one value in `data/attacks.json`). Look for:
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
9. **Hold-to-preview casting** (Slice 6, your D2 answer). Hold a card key, aim, and let go. Look for:
   - Does it feel natural rather than slow?
   - Is the outline (in your element colour) clear over enemies without being too loud?
   - Esc opens the pause/settings screen; try switching to "Press" and back.
10. **Your outline through enemies.** When enemies crowd in front of you, a pale blue silhouette of you shows through them. Look for: you can always find yourself, and the colour works against your blue body (it's `player_outline` in `data/ui.json` if it wants a warmer colour or lower alpha).
11. **Pause screen text.** "Paused", "The world will wait. It is very patient and very cheerful.", "Esc also resumes". Is the tone right? (Placeholder; the story role is dormant.)
8. **Light flash and heavy telegraph.** Look for: the light swing reads at full speed, and the heavy wind-up looks clearly different from its impact.

## FYI, no action needed

- **Example minimum config (not active):** an attack group of 10, utility 5, movement 3 and recovery 3 would mean a 21-card minimum deck. That would limit deck-clean rewards if it were ever adopted. It lives only as a test fixture.
- **Pool note:** after C1, the Neutral pool gives 3 Recovery cards (Healing Potion, Leech, Regeneration) and 1 Movement card (Backward Leap). So any future class + element combination needs at least 2 Movement cards of its own to meet 3 per slot. Content validation will flag it automatically.
- **Temporary:** the first-run preset deck will contain every Fire Rogue card, so you can test everything. Unlock rules come with the run loop.

- **Dash and dodge distance.** Dash cards and the dodge roll kept sliding after the move ended, travelling about twice their set distance (Blaze and Bail went about 8 m, not 4 m). They will now stop at the distance set in data, so the hit-area preview tells the truth. Dodge went from about 7.1 m to 3.5 m (its intended distance), and Blaze and Bail from about 8.1 m to 4.0 m. If the dodge feels too short, tune `dodge_speed` or `dodge_duration`; no new code needed.

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
| - | Add the tech-writer role? | Yes. It owns README, CHANGELOG, ASSETS and ARCHITECTURE, and does one docs pass per slice before close. | 2026-10-28 |
| D1 | Run stats on the Game Over screen? | A: not now; revisit with the run structure. | 2026-10-28 |
| D2 | Hold-to-preview casting? | C: build it as the default, with a setting to cast on press instead. Scheduled as Slice 6. | 2026-10-28 |
| D3 | Tint shots by team? | A: yes (already built). | 2026-10-28 |
| D4 | Light attack cut to 3? | A: keep it; you will playtest, and it stays easily tunable. | 2026-10-28 |
| D5 | Heavy's 50% Burn beats some area cards? | A: keep as built. | 2026-10-28 |
| D6 | Golem wind-up 0.7 s? | A: yes (already applied). | 2026-10-28 |
| D7 | HP bar visibility? | B: damaged enemies only, plus elites and bosses always. Applied in Slice 6. | 2026-10-28 |
| P1 | Spam-click gave 2.4x auto damage. Lower it? | Cap at 1.5x the auto rate, as a data ratio. | 2026-10-28 |
| P2 | Heavy attack DPS is below light. Give it a reason? | Heavy trades DPS for burst, area, stun and element flavour; heavy attacks are defined per class. | 2026-10-28 |
| P3 | Root or slow during the heavy wind-up? | A slight slow, never a root. | 2026-10-28 |
| P4 | Auto light beats cheap cards. Intended? | No. Cards must always beat the free attack: lower light, raise cheap damage cards. | 2026-10-28 |
| - | Clicking's role overall | An early-game crutch; it should feel unnecessary once the build takes shape. | 2026-10-28 |
