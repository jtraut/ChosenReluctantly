# Playtest 2026-10-28: Polish 1 Slice 4 (skill visuals, targeting) and Slice 3b (attack rework)

## Build and setup
Godot 4.7.2, RTX 3080, real window 1280x720 through `tools/capture_screenshot.ps1`. I looked at every screenshot cited below (all in `screenshots/`, which is gitignored, so the paths are local to this machine). I cannot click, move or aim by hand in this environment, and a still cannot show timing, hit-stop, shake or the feel of the wind-up slow. Anything about feel is listed at the end as "needs the director live". Scenarios give the player 9999 HP, so they say nothing about danger. Time-to-kill figures come from the numbers in `docs/DECISIONS.md`, not from watching a fight, and are labelled that way.

## Smoke result: PASS, no blocker
- Launches cleanly in all six runs (`card_cast`, `attacks`, `targeted_aoe`, `stun_crowd`, `hp_bars`, normal). The console showed only the engine banner, the screenshot-saved lines and the scenario slot-cooling checks (all "OK"). No errors or warnings.
- The world is visible: green floor, lighting and shadows, blue player, red and purple enemies, a camera that frames the player. HUD is sensible: HP 30/30 in a normal run (9999 in scenarios), LMB and RMB meters, five slot cards with "Next:" lines.
- Normal run: HP 30/30 at 1 s (`p4run_0.png`), 26/30 at 4 s with the purple ranged enemy visibly shooting (`p4run_1.png`), 4/30 at 8 s (`p4run_2.png`), and the Game Over screen at 14 s ("Well. That went badly." / "Try again", Enter or Space) (`p4run_3.png`). A player who stands still dies in roughly 10 to 14 s, so damage and the death screen both work.
- Slot cooling bars: confirmed working. Every scripted cast showed the slot dimming with a draining bar (`p4cc_*`), and the scenario's own cooling check printed OK each time. This was unobserved in earlier reports.
- NOT verified by me: live input (movement, mouse aim, real clicks, keys 1 to 5, dodge). The scenarios push casts through the real slot code, which is as close as I can get.
- Caveat on the normal run: the capture has no mouse, so the aim is frozen pointing away from the enemies. The auto light never fired in `p4run_*`, so I could not get a real time-to-kill from a normal run.

## Slice 4: can I tell what was cast, where it went, what it hit?
Short answer: yes for aoe, Burn, buff, stun and the heavy. Marginal for the plain projectile, dash and heal. The cone is easy to miss in a still.

| Template | Screenshot (under `screenshots/`) | What it shows | Readable? |
|---|---|---|---|
| Projectile, physical (Pointy Stick) | `p4cc_0.png` | A few cream dots near the player and small "6" numbers over the golems | Weak. I can see the hits but not the bolt. |
| Projectile, fire (Flaming Nonsense) | `p4cc_7.png` | Orange blob with an orange trail along a long orange lane, white aim reticle ahead | Good. Colour says fire, the lane says where it went. The lane runs off the arena into the dark void. |
| Cone (Overhand) | `p4cc_1.png` | Pale grey-cream wedge in front of the player, "12" over two chasers | OK in a still, low contrast, lasts only 0.25 s. I expect a flicker at speed. |
| AoE (Shrug Bomb) | `p4cc_2.png` | Big cream disc with an inner ring centred on the player; slot 2 dims with a cooling bar | Good: clear radius and origin. |
| Cone plus Burn (Ember) | `p4cc_3.png` | Dark orange-brown wedge, flame caps appearing on the chasers, a small orange triangle by their HP bars | Good. The best "I set them on fire" moment. |
| Burn, persistent | `p4cc_4.png` to `p4cc_6.png` | Orange flame blobs on both chasers, orange triangle icon, orange "2" tick numbers | Good, readable for several seconds. |
| Heal (Healing Potion) | `p4cc_4.png` | Small green dots and a green ring at the player's feet, HP 9939 to 9955 | Readable but subtle. Could be missed in a fight at low HP. |
| Buff (Hot Head) | `p4cc_5.png` | Gold ring at the player's feet; slot 3 dims | Readable, clearly different from the heal's green. |
| Dash (Ugh, Fine, Moving) | `p4cc_6.png` | Pale smear and puffs behind the dash, camera follows | Marginal: faint grey trail. Dodge roll still has no trail (known). |
| Aim reticle and markers | all of the above | White ring at the aim point, dotted line from the player towards it | Good. Quiet, always there, hides nothing. Tall golems can cover it (known, Slice 5). |
| Death cue | `p4run_3.png` | Desaturated, dimmed world and HUD, player toppled, then the Game Over text | The capture only caught the end state, not the white-then-red flash. The end state is clear and the line lands the tone. |

Note: enemy shots and the player's physical shots are both cream (known, D3).

## Heavy attack (3b)
- **Telegraph vs impact (observed).** `p4at_1.png` (2.4 s): a thin pale-pink outline of a wide arc with a faint fill, RMB meter reads SWING. `p4at_2.png` (2.7 s): a solid saturated orange arc with a white edge. They look very different now: outline while winding up, fill when it lands. This fixes last report's "muddy brown, can't tell telegraph from impact". Note the golems already show an orange flash in the 2.4 s shot, so some hit flash overlaps the telegraph in that frame; the timing of that is for the director to see live.
- **Stun (observed).** In `p4at_2.png` and `p4at_3.png` the golems carry yellow stars and a grey wash. In `p4st_1.png` six enemies have stars and a pinkish tint, three do not, and the boss shows an "IMMUNE" popup, partly hidden behind HP bars (known S3B-2). A stunned enemy is easy to spot even in a crowd of nine. Whether the 0.6 s freeze matters I cannot judge from stills; by numbers it is a third of each 1.8 s heavy cycle, which should matter more against melee chasers than golems.
- **Wind-up slow (not observable).** Needs live play. My only worry, from the numbers, is that -35% for 0.45 s is short enough that it may not read as commitment at all.
- **Burn on heavy (partly observed).** In `attacks` (seed 5) the golems were not set on fire by the heavy (they also have 50% fire resistance). In `targeted_aoe` (`p4ta_1.png`, `p4ta_2.png`) one of five chasers caught fire. That fits roughly 50% but is far too small a sample to confirm. When Burn lands it is very visible. Expect about half of heavies to show no fire at all.
- **Area (observed).** The heavy arc is about 3x the light wedge and sweeps both golems with room to spare (`p4at_2.png` vs the gold light wedge in `p4at_0.png`). It looks worth pressing against a group.
- **Wizard `targeted_aoe` telegraph (observed).** `p4ta_0.png` (1.3 s): purple ring and inner disc on the ground over the chaser cluster. `p4ta_1.png` (1.7 s): pale cream burst disc, "9" numbers on four chasers, one burning. `p4ta_2.png` (2.0 s): disc gone, HP bars drained, one still burning. The growing ring reads at a glance, and purple versus the Rogue's orange tells the two heavies apart. Chaser HP bars crowd the ring but stay readable.

## Light vs cards (D4)
- **Light visibility (observed):** the auto light is now a solid gold wedge (`p4at_0.png`), a big improvement on last report's pale tan flicker. Damage numbers ("3", "6", "9") are still tiny, around 8 to 10 px.
- **Cards vs light (theory, from DECISIONS):** light is 3 per 0.6 s = 5.0 DPS. Credited card DPS: Pointy Stick 6.0, Ember about 6.4 to 6.5, Quick 8.3, Overhand 9.2, Flaming Nonsense 7.5, Fine Burn Then 5.45 to 5.64, Shrug Bomb 5.45, Everyone Calm Down 5.33. Per cast the cards read as clearly better (5 to 16 against 3, with a big number and a dimmed slot). On single-target DPS, the three area cards are only about 7 to 10% above light, which I do not think a player will feel. They only win in crowds.
- **Light-only play (theory):** chaser 3.6 s, shooter 2.4 s, golem 9.6 s with light alone. That is the "crutch" feel the director described: slow but not dead. My D4 vote is A (keep light at 3). The real weakness is the thin AoE margin.
- Real time-to-kill from a watched run: not available (see smoke caveat).

## 1.5x click cap
Could not test (needs real clicks). By numbers: min gap 0.4 s, so at most 2.5 clicks per second, 7.5 light DPS if every click lands, against 5.0 auto. That is +2.5 DPS, less than any single card contributes, so clicking is worth doing early and clearly not mandatory. Whether it feels like a chore, I cannot say. The LMB meter still has no label and reads as a thin olive bar cycling (`p4at_0.png` to `p4at_3.png`); I could not tell what it shows.

## Heavy total vs cards (D5)
Heavy 8.5 per 1.8 s = 4.72 DPS direct, 5.97 with the 50% Burn. Only Pointy Stick (6.0), Ember (about 6.5) and the faster single-target cards are above it. It beats light (5.0), Shrug Bomb (5.45), Everyone Calm Down (5.33) and Fine, Burn Then (5.64) on one target, and it has 3x burst, stun and an 0.45 s wind-up as its costs. My opinion: a mild breach of "a card always beats the free attack", and in practice a player pressing RMB every 1.8 s will outdamage three paid cards on one target. Area cards still win in crowds. If cards must always win, B (30% Burn, about 5.5) is not enough to get under Shrug Bomb (5.45) and Everyone Calm Down (5.33); about 20% Burn (about 5.2 total) would be. If the heavy is meant to be the Rogue's identity, A is fine.

## Findings, ranked

### Blockers
None.

### Should-fix
1. **Three area cards beat light by only about 7 to 10% on one target, and the free heavy (5.97) beats all three.** On one enemy there is no reason to pick them. Suggest D4 option C (lower the area slot base cooldown) or a small damage bump; leave light alone.
2. **Damage numbers are still tiny** in every shot. Impact is mostly told by the numbers, and at speed they will be lost. Suggest larger numbers, especially for the heavy. (Carried from last report.)
3. **Plain physical projectile (Pointy Stick) is nearly invisible** (`p4cc_0.png`). The fire projectile is excellent by comparison. Suggest a clearer trail or muzzle flash for neutral.
4. **IMMUNE popup is hidden by HP bars in crowds** (`p4st_1.png`). Known as S3B-2 (Slice 5). I confirm it matters: in the 9-enemy shot I can barely read it.

### Nice-to-have
5. LMB meter has no label (unchanged).
6. The fire projectile lane runs off the arena edge into the void (`p4cc_7.png`); a capture-aim artefact, but looks sloppy.
7. Cone wedge is faint and only 0.25 s.
8. Heal sparkles are subtle for something a player needs to notice at low HP.
9. Dash and dodge trails are still weak.
10. Enemy and player physical shots share a colour (D3, tracked).

## Top 3 things that work
1. The attack language reads now: gold light wedge, outline-then-fill heavy, and a visibly different purple Wizard ground ring.
2. Burn looks great: flame caps, an icon, orange tick numbers, readable for seconds. The fire projectile and fire cone read as fire.
3. Stun stars plus the grey tint make stunned enemies obvious even in a crowd of nine.

## Director calls (plain language)
- **D4 (light is 3):** I would keep it. Light-only kills a golem in about 10 s: slow, not dead. The problem is three area cards that barely beat it. Fix that with cooldown (option C), or leave it?
- **D5 (heavy beats three cards on one target):** Should the Rogue heavy be the strongest "free" thing, or should every card always beat it? If every card, 30% Burn is not enough; you would need about 20%, or lower direct damage.
- **Stun length:** is 0.6 s every 1.8 s enough to feel powerful, or do you want a clearer "free hit" window?
- **Neutral projectile look:** should the plain starting projectile get a stronger look even though neutral is meant to be plain?
- **Burn on heavy:** about half of heavies will show no fire. Is that a satisfying surprise or a letdown?

## Needs the director live (not judgable from stills)
- Light flash readability at full speed; hit-stop, shake and impact feel.
- Whether the 35% wind-up slow reads as commitment or is invisible.
- Whether the 1.5x click cap feels fine or like a chore.
- Real time-to-kill and real danger (scenarios are god mode, and my normal run had no mouse aim).
- The aim reticle with a real mouse and at 1440p; the white-then-red death flash and slow-mo length.
- Whether Burn procs on heavy feel frequent enough.
- Input: movement, keys 1 to 5, dodge.

## Suggested next playtest focus
A hands-on full wave with a real mouse: light-only, heavy-only, cards-only, then mixed, timing the kill of each enemy type. Then Slice 5 density and HP bars.

## Screenshot paths (local, gitignored)
`screenshots/p4cc_0.png` to `p4cc_7.png` (card_cast), `p4at_0.png` to `p4at_3.png` (attacks), `p4ta_0.png` to `p4ta_2.png` (targeted_aoe), `p4st_0.png` to `p4st_2.png` (stun_crowd; only `p4st_1.png` opened), `p4hp_0.png`, `p4hp_1.png` (hp_bars, captured but not opened), `p4run_0.png` to `p4run_3.png` (normal run).
