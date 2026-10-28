# Playtest 2026-10-27: Polish 1 Slice 2, HUD text overflow and safe layout

## Build and setup
Commit 612a0b6, Godot 4.7.2, RTX 3080. Screenshots (gitignored), all opened and looked at:
- Real window, normal run (no scenario), 1280x720: `screenshots/s2_720_0.png` (1 s), `screenshots/s2_720_2.png` (8 s).
- True-size SubViewport via `tools/vp_capture.gd`: `screenshots/s2_vp1080.png` (1920x1080), `screenshots/s2_vp1440.png` (2560x1440). Waves do not spawn in this mode, so only one enemy shows. I judged the HUD only.
I did not play by hand. Input (move, dodge, cards) is still unverified by me, and I cannot judge cooldown behaviour from stills.

## 1. Smoke check
PASS, no blocker. Capture output showed no errors or warnings (the vp_capture errors the task warned about were not printed in my filtered check, and I did not rely on them). The 720p run shows a lit floor, a blue player, enemies with HP bars, and a framed camera. The HUD reads "HP 30 / 30" at 1 s and "HP 10 / 30" at 8 s, so damage lands and the numbers are sensible.

## 2. Slot bar
- 1280x720: five slots in a row, evenly spaced, aligned, centred, about 35 px above the bottom edge. Numbers 1 to 5, names, cooldown bars and "Next:" lines all sit on the same baselines. "Everyone Calm Down" wraps to two lines and the other four slots do not shift. This is the exact case that clipped last time, and it is now fixed. Nothing touches an edge.
- 1920x1080: aligned. All five names fit on one line. "Next: Healing Potion (Lukewarm)" wraps to two lines and the second line hangs below the other "Next:" lines. It is about 26 px from the bottom edge, so it is not clipped.
- 2560x1440: same layout, same proportions (the bar is about 62% of screen width at both 1080p and 1440p). The long "Next:" wraps and hangs about 37 px above the bottom edge. Nothing is clipped.
- Readability: names are comfortable at every size. The 9 px "Next:" text at 720p is small, but it was legible in `s2_720_0.png` (white on mid-green). I would not call it uncomfortable, but it is the weakest text on screen. should-fix (minor): "Next:" is the GDD's key info (§4), so I would want it at least 10 to 11 px at 720p if there is room. The slot has spare space.
- nice-to-have: the two-line "Next:" hangs lower than its neighbours, so the row's bottom edge looks ragged. Reserving two lines of height for all slots would make it uniform.
- nice-to-have: the slot bar is the same relative size at 1440p, so it is small relative to the screen. That is fine for now.
- should-fix, carried over: I cannot see any cooldown or ready state on the bars. They are dark grey at 1 s, 8 s and at every resolution. I cannot tell whether that is "ready", "empty", or just not exercised, because I did not cast. The director should check this by hand.

## 3. HP bar
Much better than before. It is red and wide, with a white border, and the empty part is near-black. At 10 / 30 I read the amount from the bar without reading the number (`s2_720_2.png`). The label "HP 30 / 30" sits above it at a readable size. nice-to-have: the fill stays the same red at low HP, so a low-health colour shift or pulse would add urgency. nice-to-have: red on a green floor is fine, but the player HP bar and the enemy HP bars use the same red, so they compete for attention.

## 4. Overall HUD clutter and readability
Clean. The HUD is two blocks (HP top left, slots bottom centre), and neither covers the play area. The world stays the focus. Nothing pulls attention badly. One oddity: in `s2_720_2.png` a pale blue triangle covers the top-left corner behind the HP label. I assume it is a hit or damage flash, but it looked like a stray shape and made the label slightly harder to read. Please confirm this is intentional. (observed fact: it is present in that shot only.)

## 5. Out-of-scope follow-ups
- should-fix (carried over): first contact is fast. By 8 s the player had lost 20 of 30 HP, with three enemies on top of it.
- nice-to-have: the overlapping damage number over the player ("5" stacked on an enemy bar) is tiny.
- nice-to-have: the slot widgets show no card type, element or effect hint, only a name. That is a design question for later.

## Top 3 things that work
1. The slot bar is stable: fixed size, aligned, nothing shifts when a name wraps.
2. Nothing is clipped at 720p, 1080p or 1440p, and the layout scales proportionally.
3. The HP bar now reads at a glance, and the HUD stays out of the way of the arena.

## Top problems, ranked
1. should-fix: no visible cooldown or ready state on the slot bars (carried over, unverified).
2. should-fix (minor): "Next:" text is 9 px at 720p, the smallest text on screen.
3. nice-to-have: two-line "Next:" hangs below its neighbours.
4. nice-to-have: HP fill has no low-HP cue, and shares its red with enemy bars.
5. nice-to-have: unexplained blue triangle in the top-left corner in one shot (confirm it is a hit flash).

## Questions for the director
- Is the blue top-left shape in `s2_720_2.png` an intended damage flash?
- Is a dark cooldown bar "ready" or "empty"? Should it show a clearer ready state?

## Suggested next playtest focus
Play by hand: cast all five slots and watch the cooldown bars and the "Next:" line update. Then pacing of the first 10 seconds.
