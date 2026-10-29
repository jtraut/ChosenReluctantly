# Playtest: Content slice C1 (C1-g) merged with the Polish 1 close-out

Date: 2026-10-29. Build: HEAD of main (76bca75 plus docs). Playtester.

## Build and setup (what I could and could not do)
I cannot hold a mouse. Everything below comes from windowed screenshot captures of the real game (`tools/capture_screenshot.ps1`, scripted scenarios, `-TrueSize` for 1920x1080 and 2560x1440), seeded wave sims (`tools/run_wave_sim.ps1`) and the bot sim. Hand feel (hit-stop weight, stutter, being pinned by a real crowd) is therefore judged from numbers and stills and labelled as such. "Observed" means a screenshot or sim output.

Extra scenarios: the shipped `c1_*` scenarios only preview Fireball, Fire Wall, Lunge and Leap. I made a scratch copy of the project in the session scratchpad and added `pt_*` scenarios there (real casts of Fireball, Fire Wall, Lunge, Leap, Shadow Step then Lunge, Four Quick Stabs, Slash Then Bleed). Repo data and code untouched. Proposal: ship real-cast scenarios for these in `data/scenarios.json`.

Screenshots (gitignored): `screenshots/c1g/`. All README known-good `-After` times for the `c1_*` scenarios produced the expected shot counts. The README scenario table still lacks the `c1_*` rows (input for the docs pass).

## Smoke check: PASS
- `--headless --quit`, `--headless --quit-after 1200` and `--headless --editor --quit`: zero error and warning lines (CLI-visible only, per the roadmap note). Bot sim OK (20 rooms).
- Windowed captures: floor, player (blue capsule), enemies, lighting and camera framing are fine. HUD shows "HP 9999 / 9999" in scenarios and "HP 0 / 30" in game_over (real player max is 30). Five slots show names, cooldown bars and "Next:".
- The run is not blocked by the deck check (every scenario and wave sim runs the Main scene and plays).
- Input: the scenario harness sends real input actions for slot press, hold and release and for light and heavy attack; all responded (cast lines print `ok=true`, slots cool). I did not test WASD or dodge by hand; the wave-sim bot uses the real move and dash actions and moves.
- No blocker.

## Per-card verdicts
Baseline: light attack is 3 dmg / 0.6 s (5 DPS, free, auto). Cards are 117-129% of that on paper.

| Card (HUD name) | Slot | Name and flavor fit | Visuals readable | Matches what was hit | Worth casting vs light attack | Verdict |
|---|---|---|---|---|---|---|
| Slash, Then Bleed | single | Fits on one line | Cone flash same as light attack; Bleed is a small droplet pip on the enemy HP bar, alternating with Burn | Yes; 5 then small ticks | Marginal: 117% DPS and the bleed is easy to miss | Fine |
| Four Quick Stabs | single | Fits | Same cone flash; four small "2" numbers stack, hard to separate in a still | Yes | Slightly better burst, 123% | Fine |
| Fireball, Incoming | aoe | Great name, fits | Best telegraph in the game: orange disc grows over 0.4 s with a bright core, then fades. Hold preview shows a range ring plus a diamond when clamped | Yes by shape (my capture aimed at empty ground, see caveat) | Yes: aim plus delay make it a decision, 129% | Great |
| Wall of Mild Fire | aoe | Joke lands, fits | Orange rectangle with a centre timer bar that empties; clear | Rectangle matches the hit area | Only when enemies cross or stand in it; weakest on one target | Fine, leaning dull |
| Walk Through Everyone (Shadow Step) | movement | Wraps to two lines but now fits | Player turns see-through with a pale blue ring; very readable | n/a | Only matters because enemies are solid; no payoff otherwise | Fine |
| Reluctant Lunge | movement | Fits | Short pale path box and dust puffs; each enemy hit shows an "8" | Observed: stops at the first solid enemy; with Shadow Step first it passed through and hit two | Good gap closer, not an escape | Fine |
| Nope, Leaping Away | movement | Great, wraps to two lines, fits | Clear arrow preview, long dust trail | n/a | The one real escape tool | Great |
| Heal By Hurting (Leech) | recovery | Great | Weakest cue: green "+1", "+2" on hits and a small ring. Readable once known | Heals only while hitting; numbers show it | Good if you are fighting anyway | Fine |
| Eventual Healing (Regeneration) | recovery | Great | Green ring and "+2" ticks for 7 s; clear | n/a | Strong against chip damage: 14 HP over 7 s on a 30 HP player | Fine to great |

Caveat: in my Fireball and Wall captures the frozen aim sits on empty ground, so I confirmed the telegraph, burst and zone shapes but not hit-for-hit numbers. Also: mid-fight the slot shows the next card, not what you just cast, and the cast has no label, so a new player cannot tell which card made which effect.

## Full preset deck (sims and stills, not hands-on)
Seeds 1-3, 150 s, real HP: HP lost 86 / 91 / 83, kills 72 / 71 / 68, about 280 casts. 600 s runs (2 seeds): HP lost 388 and 220, still alive, about 290 kills, 50 stages opened. Idle player: dead in 8 to 10 s with 0 kills. Observed: the bot never dies in 10 minutes on 30 max HP because healing outpaces damage.

- **Different fight to fight?** Partly. Slots shuffle, and slot 4 changes the shape of the next few seconds (hop away, lunge in, walk through). Slot 1 is the least differentiated: its cards are within 117-123% of each other and look alike. I cannot confirm the feel by hand.
- **Area cards on one enemy.** The older three (Shrug Bomb, Everyone Calm Down, Burn Then): yes, instant full damage. Fireball: yes, 14 up front plus Burn even on one target, though aiming costs tempo. Fire Wall: no. It only hurts while the target stands in it (2.5 per 0.5 s), and a lone chaser walks out; real crossings are 1 to 3 ticks, below the free light attack in practice.
- **Recovery readiness.** Cooldown is 8.0 to 8.5 s (Nap Time 6.5 s; Deep Sigh can cut 2 s for 8 s), so the ceiling is about 7 casts a minute and realistic play 5 to 6 (my estimate; the sim does not count per slot). Heal sizes: Potion 16, Regen 14, Nap 8, Leech about 1.6 to 2 HP/s. On 30 max HP that is roughly 50 to 90 HP a minute of healing against about 35 HP a minute lost in the sim. Too generous in theory.
- **Dash chain stutter.** Not expected. Observed: bodies are solid, so Lunge stops at the first enemy and only chains with Shadow Step active (each enemy showed one "8"). Light-hit hit-stop is 0.03 s at 0.2 scale (`data/attacks.json`), so four enemies is about 0.1 to 0.15 s total. Untested by hand.

## Solid enemies (key question)
Observed (3 seeds at 150 s, 2 at 600 s): pinned in 8 to 10 percent of move-commanded frames, longest stretch 110 frames (1.83 s) in two runs and 0.47 to 1.18 s in the rest; no stalls, no climbing, no NaN; melee spacing at least 1.2 m in 83 to 95% of frames. HP lost is about double the old non-solid value, yet the bot never died.

As a player: under 2 s reads as a stumble, not a trap. Dodge is blocked, but Backward Leap (6.5 m), Shadow Step (2.5 s) and killing the neighbour all exist. Risk: Shadow Step has a 4 s cooldown and the Movement slot can hold Lunge, which is no escape. In the full-density captures the player sits inside a ring of 8 to 12 bodies, half hidden (`screenshots/c1g/hud1440.png`), so being pinned is also an unreadable moment.
- Pinned with no way out? No full lock observed. Worst case is a few seconds with Movement cooling and the dodge useless.
- Verdict: fair on numbers, possibly frustrating by feel, not a blocker.
- **Recommendation: keep the flag on** (`body.collide_with_enemies`), provided the director pushes into a crowd live for a minute with Shadow Step on cooldown. Turning it off makes Shadow Step a no-op. If it feels sticky, lower Shadow Step cooldown (4.0 to about 3.0) before flipping the flag.

## Pass close-out (Polish 1 definition of done)
Screenshots in `screenshots/c1g/`, 1280x720 unless noted:

| Item | File |
|---|---|
| cone (Slash Then Bleed, Four Quick Stabs) | `bleed_*.png`, `stabs_*.png`, `status_1.png` |
| aoe (Fireball, Fire Wall) | `fireball_*.png`, `wall_*.png`, `cardcast_*.png` |
| projectile | `cardcast_*.png` (Pointy Stick) |
| dash | `lunge_*.png`, `leap_*.png` |
| heal | `status_*.png` (green +N), `cardcast_*.png` |
| apply_status | `statuscrowd.png`, `status_*.png` |
| buff | `cardcast_*.png` |
| zone | `wall_*.png`, `placed_*.png` |
| pass-through | `status_4.png`, `lungess_*.png` |
| auto light attack, heavy attack | `attacks_0.png`, `attacks_2.png` |
| death and Game Over | `gameover_0.png` to `gameover_3.png` |
| HUD 1280x720 / 1920x1080 / 2560x1440 | `hud720.png`, `hud1080.png`, `hud1440.png` (true size) |
| wave at full density | `waves_0..3.png`, `hud1440.png` |

- Death and Game Over: topple with a red ring, then a dimmed screen: "Well. That went badly. The world is still cheerful about it. You are not." and a large "Try again" with "Enter or Space". Tone lands, clear.
- HUD at three sizes: text and slots scale cleanly, nothing clipped. At 1080 and 1440 dark void shows at the arena corners.
- Any single enemy unfair or unreadable? No. The Golem (9 dmg, 0.7 s wind-up) is clearly telegraphed. The readability problem is crowds: the player capsule is hidden behind bodies and the ranged shooter's pink shots get lost in the pile. Watch the ranged enemy.
- Seen but not diagnosed: in the held-Fireball preview the slot showed "Next: Fireball, Incoming" with the current card also Fireball (probably the scenario forcing the card).

## Top 3 things that work
1. The "Next:" line and the dry card names; the slots read as a deck and no name clips after the fit fix.
2. Fireball's delayed telegraph and range reticle; Backward Leap and Shadow Step cues read instantly.
3. Game Over tone and the clean, toy-like read of shapes, colours and hit numbers.

## Top 5 problems, ranked
1. **Recovery on 30 HP means attrition cannot kill you.** The bot lives 10 minutes; the Potion alone is 16 HP of 30. Suggest healing about 60 percent or Recovery cooldown about 12 s, then watch a human's first deaths.
2. **Crowd readability.** Player hidden behind enemies; ranged shots vanish. Suggest an always-on-top player outline and a brighter enemy-projectile colour.
3. **Fire Wall is weak on one enemy.** Suggest higher tick damage, a slow, or a pin so targets stay in it.
4. **No "what did I just cast" feedback.** Suggest a brief card-name pop-up on cast and a stronger Bleed cue.
5. **Single-target slot is the blandest.** Slash Then Bleed and Four Quick Stabs look like the free attack. Suggest a distinct visual (four separate flashes for Flurry).

## Questions for the director
1. Keep solid enemies on? I say yes, pending one live minute by you.
2. Is the Recovery heal power on 30 HP intended? It decides how deaths feel in Milestone 3.
3. Should every Movement slot guarantee an escape card (Backward Leap), now that the dodge cannot pass bodies?
4. Is a card-name pop-up on cast acceptable?

## Suggested next playtest focus
A live human 5-minute run with the preset deck and solid flag on, counting Recovery casts per minute by hand and noting time pinned; then decision tension once Milestone 3 reward screens exist.

## Code bugs
None found. For QA to confirm only: the held-Fireball preview showing the same card as current and next (likely scenario-forced).
