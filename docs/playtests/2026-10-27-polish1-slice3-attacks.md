# Playtest 2026-10-27: Polish 1 Slice 3, automatic light and manual heavy attack

## Build and setup
Godot 4.7.2, RTX 3080, real window 1280x720 via `tools/capture_screenshot.ps1`. Screenshots (gitignored), all opened and looked at:
- `attacks` scenario, After "0.75,2.3,2.45,2.7": `screenshots/s3pt_0.png` to `s3pt_3.png`.
- Normal run, After "1,3,6,9": `screenshots/s3run_0.png`, `s3run_1.png`, `s3run_3.png` (`s3run_2.png` not opened, not cited).
I did not play by hand. I cannot judge feel (click response, hit-stop, shake, auto-fire rhythm) from stills. The capture runs show HP 9999 (apparently god mode for capture), so I cannot judge danger or fairness. Cards were not cast in any capture, so the slot "cooling" state is still unobserved.

## 1. Smoke check
PASS, no blocker. No errors or warnings in the capture output. Floor, lighting, blue player and enemies are visible, the camera frames the player, HP reads 9999/9999 (capture build). Light hits, heavy hit and enemy damage numbers appear, so attacks land. Input (movement, real clicks, 1 to 5) is unverified by me.

## 2. Auto light
Observed: in the normal run the player attacked without input. `s3run_1.png` shows a pale yellow wedge in front of the player and a yellow weapon block, and damage numbers "4/5/8" over enemies. In `s3pt_0.png` both golems show "8" (one light hit each).
Opinion: it does look like the player is doing something, but only barely. The wedge is a muted tan, low contrast against the green floor and it lasts 0.12 s, so at normal speed I expect it to read as a flicker. Damage numbers are tiny (about 8 px). The wedge also extends past nothing visible: it is drawn short of where hits land (known, Slice 4).
- should-fix: make the light flash a bit brighter or longer (about 0.15 to 0.2 s), and make the damage numbers larger. Needs the director to feel it live.

## 3. Heavy
Observed: the heavy wedge is large, saturated orange and clearly wider and longer than the light one (compare `s3run_1.png` with `s3pt_3.png`). At 2.7 s the 22 damage numbers show and the golems are gone (killed). The RMB meter swaps "READY" (bright orange) to "SWING" (black bar with a small red fill) to a refilling bar. The heavy is unmistakably different from the light in colour and size.
Not observed: the wind-up. In `s3pt_1.png` (2.3 s) and `s3pt_2.png` (2.45 s) the golems are already flashing yellow and a brownish wedge is on the ground, with SWING on the meter. I cannot tell from stills whether that wedge is a telegraph ahead of the hit or a lingering flash after it, and I cannot say if the 0.45 s wind-up is readable. The brown wedge colour is muddy compared with the final orange.
- should-fix: telegraph colour/shape should differ clearly from the impact flash, for example a thin outline that fills during the wind-up, then a bright flash on impact. Director to check live.
- nice-to-have: "SWING" label on the meter is good for the hint, but a held-still player during wind-up (if intended) should be confirmed.

## 4. Is clicking worth it? Balance (theory)
Numbers: auto light 8 / 0.6 s = 13.3 DPS. Spam clicking at the 0.25 s cap = 32 DPS, about 2.4x auto. Heavy 22 / 1.8 s = 12.2 DPS single target, but 85 degree half-arc and range 2.4 (vs 50 and 1.8), so it hits more enemies in a crowd and knocks back 8 vs 3.
- Cards for comparison: Quick, I Guess 5, Ember 5, Shrug Bomb 5, Pointy Stick 6, Blaze and Bail 6, Fine, Burn Then 7, Everyone Calm Down 8, Flaming Nonsense 9, Overhand 12. I did not read card cooldowns, so I cannot give card DPS. The free auto light (8) already out-hits most single cards per hit.
- Opinion 1: clicking is clearly worth it at 2.4x. That can feel good (active reward) or can become a "mash LMB" tax that makes cards secondary. The GDD pillar is the ARPG and deck-builder blend, so cards need to beat spam, not just add a bonus.
- Opinion 2: heavy is NOT worth pressing for single-target DPS (12.2 less than auto 13.3, far below spam 32). Its value is only crowd coverage, knockback and shake. A player spamming LMB can skip RMB. Because heavy also commits a 0.45 s wind-up, it looks strictly worse unless it hits 3 or more enemies or staggers.
- Opinion 3: auto light looks too strong compared with cheap cards (5 to 6 damage) and about right against Overhand. It needs live feel plus card cooldown numbers to judge.

## 5. Meters and slot states
- LMB/RMB meters under the HP bar are readable: small, labelled, out of the way. The RMB READY state (bright orange, white border) is very clear. nice-to-have: the LMB meter is a thin olive bar with no label state, so at a glance I could not tell what it showed (auto timer?). In the normal run it sits at 20% to 90% of the way at random times. A "tick" at the manual-cap boundary is not needed. Slight distraction: the LMB bar constantly cycles, but it is thin and low contrast, so I do not find it distracting.
- Slot bars: all five show a solid green strip at the bottom in every shot. I could not see a cooling state because no card was cast. Carried over from Slice 2: the director must check by hand. The numbers 1 to 5 and "Next:" lines are unchanged.
- In `s3run_3.png` a pale blue triangle covers the top-left HUD again (as last report). It is behind the HP label. Please confirm this is intended (seems to be a sky or flash overlay).

## Top 3 things that work
1. The heavy is visually distinct from the light: size, saturated orange colour, and bigger damage numbers.
2. The player visibly acts without input (auto light wedge, weapon block, damage numbers), which fixes the "dead moments" worry.
3. The RMB meter READY / SWING / refill states read clearly in the corner.

## Top problems, ranked
1. should-fix: the light flash and its damage numbers are faint and brief; auto light risks not "reading" at speed.
2. should-fix: heavy telegraph (0.45 s wind-up) not clearly distinguishable from its impact flash in stills; muddy brown colour.
3. design/balance: heavy has no DPS reason to press versus spam LMB (12.2 vs 32 DPS); spam also beats auto and many cards.
4. should-fix (carried): slot cooling state still unverified, and no way to tell LMB meter meaning without a label.
5. nice-to-have: top-left blue triangle shows again in one shot, confirm intent.

## Out-of-scope follow-ups
- Known: wedge drawn to `range` but hits reach about +0.45 (Slice 4). First contact is fast (Slice 5); I did not read danger here (HP 9999).
- In a crowd (`s3run_0.png`) many HP bars overlap into a cluster of red slabs; hard to tell which enemy is which. nice-to-have.

## Director calls (design/balance)
- Is a 2.4x spam-click bonus intended, or should the cap be lower (for example 0.4 s, 1.5x) so cards stay the star?
- Should heavy get a reason to press (stagger, armour break, bonus damage, bigger radius), or is "crowd clear" enough?
- Should the player be committed (rooted/slowed) during the heavy wind-up?
- Is auto light supposed to out-damage the cheapest cards (5 to 6)?

## Needs the director live
Click response, hit-stop and shake feel, whether auto light reads at normal speed, wind-up readability, slot cooling bar, and whether holding LMB feels like a chore.

## Suggested next playtest focus
Play by hand for one full wave: alternate auto-only, spam-only, and heavy-plus-cards, and compare time to clear. Then check the slot cooldown display.
