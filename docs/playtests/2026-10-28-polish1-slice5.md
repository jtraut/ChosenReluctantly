# Playtest 2026-10-28: Polish 1 Slice 5 (wave density, enemy readability, HP bars)

## Build and setup
Godot 4.7.2, RTX 3080, real window 1280x720 through `tools/capture_screenshot.ps1`. Every screenshot below was looked at. They are in `screenshots/` (gitignored, so paths are local to this machine). I cannot click, move or aim by hand, and a still shows no timing, motion, hit-stop or shake. In the "normal run" capture the player stands still with aim frozen, so the auto light never fires and I cannot say how fast a real player clears a wave.

Scenarios give the player 9999 HP, so they say nothing about danger. Danger comes only from the normal run, and that is a stand-still player, which is a worst case.

The `waves` scenario is a STRESS CASE: ungated and fast, with a 9999 HP player. It is not the shipped pacing. The shipped pacing is gated (a stage opens only when enough enemies are dead). I use it for "what does the cap look like", not "how hard is the game".

For the HP bar comparison I edited `hp_bars.visibility_mode` in `data/ui.json` locally, captured, and restored it to `always_alive`. `git diff data/ui.json` is empty (content identical to HEAD; `git status` shows a stale stat flag only). Nothing in `data/` is committed.

## Smoke result: PASS, no blocker
- Launches cleanly in all runs (normal, `waves`, `bar_modes` x2, `stun_crowd`, `stun_cancel`, `pointy_shot`, `hp_bars`). Console showed only the engine banner, screenshot-saved lines and the scenario's own lines. No errors or warnings.
- World visible: green floor, lighting and shadows, blue player, red, indigo and grey enemies, camera frames the player. HUD sane: HP 30/30 in a normal run, five slot cards with "Next:" lines, LMB and RMB meters.
- Normal run (stand-still player): 30/30 at 0.5 s, still 30/30 at 4.6 s, 25/30 at 5.4 s, 20/30 at 6.5 s, 15/30 at about 8 s, 5/30 at about 10 s. HP drops and the HUD tracks it.
- NOT verified (cannot drive input here): live movement, mouse aim, real clicks, keys 1 to 5, dodge.

## First 10 seconds of a normal run
| Time | Screenshot | What I see |
|---|---|---|
| 0.5 s | `screenshots/p5e_0.png` | Calm. Player, one dark-red cylinder with an HP bar, nothing else. HP 30/30. |
| 3.2 s | `screenshots/p5e_1.png` | First wave has just begun: one chaser far away on the right. |
| 3.8 s | `screenshots/p5e_2.png` | Two chasers on screen, still far out. |
| 4.6 s | `screenshots/p5e_3.png` | Four chasers around me. None attacking yet. Still 30/30. |
| 5.4 s | `screenshots/p5e_4.png` | First hit lands: HP 25. A pink ground wedge is visible next to the player, and a "5". |
| 6.5 s | `screenshots/p5e_5.png` | Pink wedge plus my gold light wedge overlapping; HP 20. |
| 8 s, 10 s | `screenshots/p5n_4.png`, `p5n_5.png` | HP 15, then 5. Three chasers pressed against me. |

Pacing opinion: the 3 s lead-in, the 9 to 13 m spawns and the 1.5 s grace give a calm, readable opening. First damage at about 5.4 s is about 2.4 s after the first spawn. That is a big improvement on last report's contact at about 1 s. Seeing enemies walk in from the edge before anything hurts is what I wanted. Four chasers arriving together as the very first wave will be a lot for a player who stands still; I cannot say if it is too hard for someone who moves and dodges.

One odd thing: a stationary dark-red cylinder with an HP bar (the TrainingDummy from `Main.tscn`) is in every normal run. See finding 3.

## Density (waves, stress case)
Screenshots: `screenshots/p5w_0.png` (2.5 s), `p5w_1.png` (5 s), `p5w_2.png` (8 s).
- `p5w_0.png`: about 12 enemies spread around me in the open, each separate, each with a bar. At this moment it reads as "a lot, but I can see every one and where it is". Not a horde. Indigo shooters are clearly different from red chasers at a glance.
- `p5w_1.png` and `p5w_2.png`: as soon as they close in, the chasers line up and stack into one red blob on top of me. At 5 s and 8 s the player is partly or wholly hidden behind bodies, and 8 or more bars pile up on one spot. This looks like a mob, not "fewer, more impactful". That is the known F-E3 (no separation steering). In motion they may spread more, which I cannot see.
- Verdict, honest: 6 to 12 alive reads as a crowd, not a Vampire Survivors horde, as long as they are spread out. Once they stack, the visual density is higher than the count suggests. The gating (a stage waits until few are alive) is the right idea. The fix for the blob is separation, not a lower cap.
- Types: chaser = red capsule, shooter = indigo capsule, golem = bigger grey-brown capsule (`bar_modes` and `hp_bars` shots). All three are readable by colour and size. Shape is the same for all three (capsules), so it is colour-only.
- The golem did not appear in my `waves` shots (it is stage 3, and I captured only to 8 s). I did not see its 0.7 s wedge.

## Telegraphs
- **Chaser ground wedge (observed):** a pale-pink outline with a darker pink fill in front of the chaser (`p5e_4.png`, `p5e_5.png`, `p5cx_0.png`). Clear that "something is about to hit this patch". It is hidden by bodies when several chasers stack (`p5bw_elite_boss_always_0.png`), so with 3 or more on you the wedges merge into a pink mess. Fair for one or two, hard to read for four.
- **Shooter lane (observed):** a wide dusty pink-brown strip along the shot path (`p5w_1.png`, `p5w_2.png`, `p5bw_elite_boss_always_0.png`). Long, runs across the arena, easy to see, and you can tell where to step out of. It is a bit wide; when several shooters fire the strips cross and the floor goes brown. Still readable.
- **Enemy shots are now hot pink with a pink trail (observed):** `p5w_2.png` shows two pink blobs with fading dotted trails. They are clearly different from my cream shots (`p5ps_0.png`). D3: yes, distinct.
- **Golem 0.7 s wedge:** NOT directly observed (no golem attacking in any capture). By the numbers it is now a 0.7 s warning for a 9 damage hit, against 0.45 s for the chaser. A good proportional tell.
- **Stun-cancel ring (observed):** `p5cx_1.png` and `p5sc_0.png` show a pink ring at a stunned enemy's feet, plus yellow stars and a pink-brown tint. The ring reads as "that one stopped" next to its stars, and the wedge is gone. It is quick (I would not catch it in a busy fight), but the stars and tint already tell me it is stunned.
- **Fairness:** no single enemy looks unfair or unreadable from stills. The one to watch live is the golem with 9 damage in a clump, because tall golems still hide ground shapes behind them (s4-b). The unreadable thing is not one enemy but the pile-up: four chasers' wedges overlapping while I am hidden behind them.

## HP bars: always_alive vs elite_boss_always
Screenshots (all 1280x720):
- `screenshots/p5bm_always.png` vs `screenshots/p5bm_elite_boss_always.png` (`bar_modes`, 12 idle enemies, mixed HP, 2 bosses, 1.5 s).
- `screenshots/p5bw_always_alive_0.png` vs `screenshots/p5bw_elite_boss_always_0.png` (`waves`, about 5 s).
- `screenshots/p5bw_always_alive_1.png` vs `screenshots/p5bw_elite_boss_always_1.png` (`waves`, about 8 s).

Caveat: the `waves` scenario gives me a different random deck and spawn timing per run, so the two `waves` pairs are similar but not frame-identical. The `bar_modes` pair is identical in layout.

What I see:
- `always_alive` at density: a bar over every one of 12 heads. In the clump they stack into 10 or more overlapping red strips (`p5bm_always.png`, `p5bw_always_alive_1.png`). A few bars are clipped by bodies in front of them (`p5bw_always_alive_1.png`, lower clump). The bar-on-bar pile hides which enemy is which, and tells me nothing, because nearly all are full.
- `elite_boss_always` (damaged-only look): in the same kind of shot only the hurt enemies carry bars (`p5bw_elite_boss_always_0.png` shows one; `p5bm_elite_boss_always.png` shows about five). The picture is much cleaner, my damage numbers ("3", "5", "9") are easier to see, and a bar now means "this one is hurt".
- Cost: a fresh enemy has no bar, so I cannot tell a 14 HP shooter from a 50 HP golem until I hit it. The three types already differ by colour and size, so the cost is small. Bosses keep a bar from the start by rule (the `bar_modes` capture has two).
- Bars hidden behind bodies: yes, a few in `always_alive` clumps. Not a problem in `elite_boss_always` because there are so few bars.
- Bar-on-bar clutter: severe in `always_alive` at 8 plus enemies in a clump, absent in `elite_boss_always`.
- `after_damage` and `hidden_at_full` I treated as the same look as `elite_boss_always` for normal enemies (ux says they are identical today). I did not capture them separately.

**D7 recommendation: B (`elite_boss_always`).** It is clearly more readable at 10 plus enemies, it costs almost nothing now because the three types are told apart by colour and size, and it keeps the bar where it matters (bosses, and anyone I am hurting). The director said "always show" on 2026-10-27, so this is a director call. A hybrid (all bars while 5 or fewer are alive, damaged-only above that) is possible but is code, and I did not test it.

## Damage numbers and IMMUNE at density
- Numbers are readable now. `p5w_1.png` and `p5bw_always_alive_0.png` show "3", "5", "5", "5" at about 20 px, white with a dark outline. Merged numbers do not spam in these stills: four hits show four digits, not a wall.
- In a clump the numbers sit on top of the bar pile and each other (`p5w_1.png`), so in `always_alive` they are readable but crowded. With `elite_boss_always` they are cleaner (`p5bw_elite_boss_always_0.png`).
- The player's own damage taken ("5" over me in `p5e_4.png`) looks the same as damage I deal. Known (5-a); it matters because "what hurt me" is what I want to read.
- IMMUNE: `screenshots/p5sc_1.png` shows a large outlined "IMMUNE" word above the crowd, fully readable over bars and stars. This fixes S3B-2.
- Pointy Stick: `screenshots/p5ps_0.png` and `p5ps_1.png` show a pale cream ball with a clear dotted trail and a faint lane strip. Visible now, and easy to tell from pink enemy shots. Still a pale cream ball on a green floor, so a weak but acceptable read.

## Findings, ranked

### Blockers
None.

### Should-fix
1. **Enemies stack into one blob on top of the player (F-E3).** At 5 s and 8 s in `waves` the chasers pile into one red mass, wedges and bars overlap, and the blue player is partly hidden (`p5w_1.png`, `p5bw_elite_boss_always_0.png`). This turns "6 to 12" into "a horde" visually and is the thing most against the density principle. Suggest simple separation steering so chasers ring the player instead of lining up, and a player outline or marker when hidden behind a body.
2. **D7: bars at density.** `always_alive` produces 10 plus overlapping strips and some bars clipped by bodies. Recommend `elite_boss_always` (see above).
3. **A TrainingDummy is in every normal run.** A dark-red cylinder with an HP bar stands next to the player from 0 s (`p5e_0.png`). It never attacks, takes hits, gets knocked around, and counts as one more bar in the density shots. It looks like an enemy, and it is another tall silhouette next to the golem. Is it meant to ship? (Possible scene issue for QA; I am not diagnosing.)
4. **Overlapping chaser wedges in a clump are unreadable.** With 3 or more chasers on me the wedges merge into one pink area and I cannot tell who swings first (`p5e_5.png`). Not unfair, but "dodge skill" needs tells that stay separate. Separation steering (finding 1) would fix most of this.

### Nice-to-have
5. Damage-taken numbers should look different from damage-dealt (5-a). Suggest red or a "-5" form.
6. Stun-cancel ring is brief. Fine as is; the stars already carry the message.
7. A dark void edge showed up in the top-left at about 10 s in the normal run (`p5n_5.png`) and at 8 s in `waves` (`p5w_2.png`). I cannot tell if the player or camera moved, or whether it is the old "blue triangle" (s2-d). Needs a live look.
8. Shooter lanes are very wide and long; a slightly narrower strip would stop several shooters painting the whole floor.
9. Enemy types differ by colour and size only; if the roster grows, add a silhouette difference.

## Not verified (honest limits)
- Anything in motion: how fast chasers close, whether the blob forms the same way live, the real feel of the 0.7 s golem window.
- The golem's 0.7 s wedge and its hit.
- How hard the first wave is for a human who moves and dodges (the normal run is a stand-still worst case: HP 5 of 30 at 10 s).
- Real time-to-kill at density.

## Director calls (plain language)
1. **D7: bar default.** Every enemy's bar always showing (your earlier answer), or only hurt enemies plus bosses and elites? I recommend only hurt plus bosses: a busy fight is much cleaner and it costs little today, since enemy types already look different. A hybrid is possible but means new code.
2. **D6 is already applied (0.7 s golem warning).** I did not see it land in a capture. By the numbers it is the right proportion. Say B only if live play shows it feels too slow.
3. **Is the 12 enemy cap fine?** I think so; the blob is the problem, not the count. Do you agree we fix stacking before touching the cap?
4. **First wave: 4 chasers, or 2 or 3?** The opening is calm and readable (3 s lead-in, first hit about 5.4 s). Only a hand-played run can say whether 4 at once is harsh.
5. **Is the TrainingDummy meant to ship in the normal run?**

## Needs the director live
- Play 3 to 4 minutes of a normal run. Does 4 chasers in wave one feel fair? Do they stack into a blob while you move?
- Walk into a golem swing on purpose and see if 0.7 s feels fair and punishable.
- With real aim: can you find yourself in a clump, and do pink enemy shots read in motion?
- Compare `always_alive` and `elite_boss_always` while you fight (edit `hp_bars.visibility_mode` in `data/ui.json`) and say which one you stop looking at.
- Check the top-left void edge and the dummy.

## Suggested next playtest focus
Separation steering and the wave blob (re-capture `waves` at 5 s and 8 s), then a live golem encounter, then the Slice 5 pass close-out.
