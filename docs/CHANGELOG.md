# Changelog: Chosen, Reluctantly

A plain-language history of the project for the director, grouped by date (from git commit dates). **Newest entry first:** new entries are always added directly under this header, never at the bottom. Hashes in parentheses are short git commit IDs.

## 2026-10-28 (Polish 1: Slice 5 waves and readability, Slice 4 skill visuals, Slice 3b attack rework, director open items)

### Added
- **Pause and settings screen (Slice 6b).** Esc pauses and opens a small screen with one toggle, "Cast cards on: Release (preview) / Press", which saves at once. It never opens over Game Over. The cast preview now uses the player's element colour, draws over the enemies it targets, and dims while the card is cooling down. When enemies hide the player, a pale silhouette shows through them. (9ff60d8, 98ee2ea, 2f44346, 567cdc4)
- **[Director decision] D7 applied:** enemy HP bars now show only on damaged enemies; elites and bosses always show theirs. Before, every bar was always visible. (efaf164)
- **Hold-to-preview casting (Slice 6a, director D2 = C).** Holding a card key shows its exact hit area on the ground (cone, area, projectile lane, dash path, or a small ring for self cards). The area follows your aim, and the card casts when you let go. A `cast_trigger` setting (`release` or `press`) switches back to casting on press. Settings now have a store (defaults in `data/settings.json`, your choices in `user://settings.cfg`), and the game can pause without breaking hit-stop or the death slow-mo. Attack and card keys are now read through input events, so an open screen can block them. (aecde4f, d2463f0, 7bfdb6f, 29656c2, 4f5220e)
- **Enemies spread out (5d).** Enemies steer away from each other, so chasers surround the player instead of stacking in one column. In the seeded sim, the share of frames where nearby chasers are readably apart went from about 33-48% to about 80-96% (depending on seed). Spacing values are data. Enemy combat stats (speed, damage, wind-up, cooldown, ranges) moved from scene files into `data/enemies.json`, with values unchanged. The training dummy no longer appears in normal runs. (6db688d, 13435db, 5e6ea32)
- **Staged enemy waves (Slice 5a).** Up to 12 enemies at once, arriving in four stages. Each stage opens after a delay and only while few enough enemies are alive. The wave table is data in `data/waves.json`. Enemies can't attack for their first 1.5 s, and the first wave arrives after 3 s. Before, first contact came about 1 s after spawn. (3af4538, 8e05395)
- **Enemy warnings.** Chasers show a ground wedge during their wind-up, and shooters show a lane strip where the shot will go. Enemy shots and wedges are tinted pink so they look different from the player's (D3, default A). (caab2c0, 079e1f4)
- **Arena walls.** Invisible walls stop the player and enemies falling off the floor edge, a bug found by the new wave simulator tool. (079e1f4)
- **Card-cast test scenario.** A capture scenario casts every card effect type in turn and confirms each slot really goes on cooldown, which is the first live check of slot cooling. Later it gained a fire projectile cast and a spread-out layout with idle enemies, so screenshots read clearly. (42f4599, 30d6d87)
- **Shared effect pool.** Visual effects come from one reusable pool with a cap on how many can show at once. The cap was 48, raised to 64 to leave room for Burn flames. The pool uses simple shapes instead of particles because that is cheapest and runs headless. (57c874f, ba993b4)
- **Element colours as data.** Fire is orange, and the neutral/physical look is cream. Adding Water later is a data entry only, and a test proves it. (993c6c8)
- **Visuals that match hit areas.** Cone, area and projectile visuals take their size from the same data as the hit check, and tests enforce it. (1d87756)
- **Visuals for every card effect.** Projectiles get a muzzle flash, trail and impact, and fizzle at max range. Cones sweep, area attacks charge then burst, dashes leave puffs and a trail, heals sparkle, buffs ring, and Burn puts a lasting flame on the enemy. (ba993b4, 7755fbf)
- **Aim indicator.** A quiet ring follows the mouse on the ground, and fading dots show the direction you face. Player projectiles and dashes leave a brief ground marker of their path. (7d8817e, 6aaa203, 51fc5b0)
- **Enemy data file.** `data/enemies.json` holds enemy shot size and cone angle (values unchanged), and later an enemy rank (normal/elite/boss). Every current enemy is normal. (ad3db20, 7192e13)
- **Data checks for status effects.** A typo in a status such as Burn now raises an error on load instead of silently showing nothing. (b5180a8)
- **Click cap as a ratio.** Spam-clicking the light attack is capped at 1.5x the automatic rate, so the minimum gap is 0.4 s at the current 0.6 s timer. It scales with any future attack-speed boost. (961d7c6)
- **"Cards beat the free attack" rule check.** Every attack card must deal at least 1.5x a light hit per cast and more damage per second than the auto light attack. A check at load and a test fail if a card drifts below. (961d7c6)
- **Heavy attack redesign.** Heavy attacks are defined per class in data, with two shapes: a wide melee arc, and a targeted area at the mouse point for casters. The Rogue heavy stuns on hit and has a 50% chance to Burn for 3 s. The Wizard's targeted area exists only as data plus a test scenario; no Wizard class was built. (7192e13, 5a45938, 89c9634, ee9adbe)
- **Stun status.** Stunned enemies don't move or attack. Repeat stuns within a short window get shorter, then stop working after the third. Elites take half-length stuns and bosses are immune. (7192e13)
- **Stun cue.** Three yellow stars orbit a stunned enemy and its body turns paler. A rate-limited "IMMUNE" popup shows when a stun doesn't land. The targeted-area telegraph now fills in as the wind-up charges. (7d58f95, ad9ee04)
- **More tests.** qa added real-scene tests for Slice 4 and 3b, and the bot simulator is now seeded so its failures can be reproduced. (6f82a4b, 8cc7b92, 552ef04)

### Changed
- **Balance: golem wind-up** 0.45 s -> 0.7 s (director item D6, default A applied). Its attack cycle goes 2.25 s -> 2.5 s and its damage per second 4.0 -> 3.6. Hit damage is unchanged at 9. (acc26a4)
- **Damage numbers are bigger:** about 12 px -> 20 px at 720p, with an outline. Quick hits on the same spot merge into one number, and at most 16 show at once. **IMMUNE** now draws above HP bars. The cone, heal, dash and projectile trails read more strongly, and their timings are now data. A ring shows when a stun cancels an enemy's wind-up. Enemy HP bar visibility is now one data setting with four modes (still "always"; director call D7). (058d3dd, 3ae40b7, 39c03e6, b50aa0c, bff7581)
- **Enemy HP bars** are slightly smaller (1.4 x 0.19 -> 1.2 x 0.16) and hidden behind models in front of them. Before, they drew over everything. (caab2c0, 8e05395)
- **Golem shape.** Its hit area went from a box to a capsule (radius 0.45). Ground markers now show its true hit area; before, they understated it by about 20-30 cm. Its body went from a box to a capsule, and its movement collision is unchanged. (caab2c0)
- **Attack wedge size.** The light and heavy wedges are now drawn to where hits really land, about 0.45 past the old drawn edge. They were later trimmed 4-5 cm to the exact reach at floor height. The projectile path marker's half-width went from 0.75 to 0.60 (so the lane is 1.5 -> 1.2 wide). How attacks hit did not change. (1d87756, 5807412)
- **Light attack and heavy telegraph look.** The light flash went from pale yellow (#ffe27a) to saturated yellow (#ffcf1a) and from 0.12 s to 0.2 s. The heavy wind-up is now a pale pulsing outline, clearly different from the solid impact flash. (0e2646d)
- **Death cue.** Death now flashes white then red, greys and topples the player, with a burst, a ring and a camera shake. (e046cdd, 6583dbf)
- **Arena background.** The pale-blue sky past the floor edge became a dark void. The floor stays 40x40; a trial 60x60 floor was reverted. (888e37b, 7755fbf)
- **[Director decision] Basic attacks.** Clicking is an early-game crutch. Basic attacks are weaker than cards. Heavy trades sustained damage for burst and utility. The heavy wind-up slows and never roots. GDD §3 was updated; this resolves balance questions P1-P4. (5a3b998)
- **Balance: light attack** damage per hit 8 -> 3, which is 13.3 -> 5.0 damage per second. (961d7c6)
- **Balance: Shrug Bomb** 5 -> 12 damage. **Everyone Calm Down** 8 -> 16 damage. Both changes make them beat the new light attack. No other card changed. (961d7c6)
- **Balance: spam-click advantage** 2.4x -> 1.5x the auto rate (minimum click gap 0.25 s -> 0.4 s). (961d7c6)
- **Balance: Rogue heavy** 22 -> 8.5 damage per hit (1.8 s cooldown). Its area is 3x the light attack's. Direct damage per second is 12.2 -> 4.7, about 5.8 with Burn. (7192e13)
- **Balance: heavy wind-up** now slows movement by 35%. Before, it neither slowed nor rooted. (7192e13)
- **Balance: stun** is 0.6 s. The window in which repeat stuns shrink went 4 s -> 1.5 s, so every heavy swing gets the full stun. (7192e13, 8a9c704)
- **Balance: Fine, Burn Then** direct damage 7 -> 12, because after the Burn fix it really did less damage per second than the light attack (3.9 vs 5.0). It is now about 5.6. With the honest Burn count, Ember's credited figure fell from 11.8 to 6.4 DPS; how it actually plays did not change. The Rogue heavy's total with Burn is about 6.0. (9d91d7a)
- **Balance (side effect of a bug fix): projectile hit size** now really reads its data. Flaming Nonsense hits at 0.3 (was 0.25), and ranged enemy shots at 0.3 (was 0.25). (1d87756)

### Fixed
- **5d fixes from qa:** a crowded enemy waiting to swing could slide faster than its top speed (now capped). A broken enemy stats block is now caught when the game loads. Enemy sidestep direction now comes from spawn order, so a seed reproduces the same run. (c3d244f, 6e8c3e6, a23a960)
- **The old bot-sim tool had been silently broken since 5b.** It stopped compiling but still printed "OK". It is fixed, and now fails loudly on any error. (c13a43a, e100f09)
- **Slice 5 cleanups:**
  - Enemies can no longer spawn right next to a player standing in a corner (min 9 m).
  - A fresh killing-blow number is never the one dropped when 16 are showing.
  - Every HP bar setting is now checked on load.
  - The arena size check matches the real walls.
  - Less per-frame waste.
  - Broken characters in the README commands are fixed.

  (8634b2b, 24480cc, 6115702, 20483c7, c3c67f6, 1b6e725, c9925fb, 26c0c3a)
- **Burn did less damage than intended.** Recasting a Burn card restarted Burn's tick timer, so Burn often ticked only once. A refresh now keeps the timer, and the card rule only credits Burn damage that really lands. (9d91d7a)
- **Cleanups from the Slice 3b review:**
  - The heavy wind-up now sets its state before telling the rest of the game it started.
  - Re-stuns now signal.
  - Test scenarios are checked for typos on load.
  - Some per-frame waste removed before Slice 5 adds more enemies.
  - Damage values must be real numbers.

  (ffd14f3, 482031b, 5710d0d, 5f49c33, 9c7d874)
- **Projectiles ignored their hit-size data** and all used 0.25. They also shared one collision shape. (1d87756)
- **The player's hit and death colour flashes never showed.** The code read the wrong material, so only the topple ran. (9ef095a, 6583dbf)
- **The pale blue triangle in the top-left corner** was the sky colour showing past the floor edge on wide screens. (888e37b)
- **The restart test failed about 1 run in 8.** It was a harmless one-frame timing gap that predated this work. The test now measures the gap and allows up to 50 ms. (9ef095a, 6f82a4b)
- **DECISIONS.md had a stray non-UTF-8 character.** (cd60da8)

### Docs and process
- **[Director decision] Answers to D1-D7.**
  - D1 A: no Game Over stats yet.
  - D2 C: hold-to-preview casting becomes the default, with a setting to cast on press. It is added to GDD §3 and scheduled as Slice 6.
  - D3 A: team tint confirmed.
  - D4 A: light stays at 3.
  - D5 A: heavy Burn stays at 50%.
  - D6 A: golem wind-up 0.7 s confirmed.
  - D7 B: HP bars are switching from always visible to damaged-only plus elites and bosses (applied in Slice 6).
- **Slice 5 closed.** qa first failed it on a broken tool, then passed it after a fix pass. The playtest found no blocker: the opening is calm (first damage at about 5.4 s), enemy shots are clearly pink, and the numbers and IMMUNE read well. The top issue is chasers stacking into one blob on the player, which goes to new step 5d along with removing the training dummy from normal runs. The HP bar look waits on director call D7. (c13a43a, 45ae002, f79455f)
- **Slices 4 and 3b closed.** The combined playtest found no blocker; the visuals and the stun read well. Should-fix items moved to Slice 5: tiny damage numbers, the faint Pointy Stick projectile, and weak reads on the cone, heal and dash. Balance questions went back to the director as D4 and D5. (68324d2)
- qa checked this file against git on 2026-10-28 and corrected three wording errors (projectile marker is a half-width; light flash start colour is pale yellow, not tan; camera basis was transposed, not flipped). All hashes and dates verified. (see docs/reviews/2026-10-28-changelog-qa.md)
- Slice 4 was split into four steps (4a-4d), and Slice 3b into four (3b-1 to 3b-4), so each step fits in one sitting. The Slice 4 playtest was folded into the 3b playtest. (0a8f929, 877a46c)
- Hold-to-preview was logged as a proposal only; nothing was built. (0a8f929)
- **New `docs/CHANGELOG.md`** (this file): backfilled from git history. It became a standing rule in CLAUDE.md, with pointers in README and STATE. Most of it landed inside commit 9d91d7a by accident, because a parallel commit picked up the files. (9d91d7a, d8cf75f)
- **New `docs/OPEN_ITEMS.md`**: one page listing everything waiting on the director. It became a standing rule in CLAUDE.md, with a pointer in STATE.md. (1d4a1fc)
- Director questions D4 (light attack cut) and D5 (heavy attack damage with Burn) were added. (493c1a3, 3ebe6c9)
- qa reviews: Slice 4 PASS, its re-check PASS, and Slice 3b PASS with should-fix items. A Burn bug found by the 3b review is being fixed before the playtest. (6f82a4b, 8cc7b92, 552ef04, 8501ce1)
- Hand-offs and status notes were kept up to date throughout the day. (6ce6189, 8566242, ebd0f0f, 0ac753b, 3a1aba1, b7ec0d0)

## 2026-10-27 (Camera fix, enemy HP bars, agent team, Polish 1 Slices 0-3)

### Added
- **Enemy HP bars.** Bars float above every enemy and show damage, a fading "ghost" segment, Burn and resistance markers. Settings live in `data/ui.json`. (b31cbde, 0309f86, bcbfe34, e60e515, 621cfa2)
- **Screenshot tooling.** A capture command plus test scenarios, so the team can see the game without a person playing it. Bad arguments fail loudly. (f468959, 96ca1a1, 083a8cf)
- **Startup self-check.** The game reports an error if the camera, player, floor, light or spawner is missing, or if the camera can't see the player. A smoke test covers it. (be64ea9)
- **Player death and Game Over (Polish 1, Slice 1).** At 0 HP the player dies once, input stops, and a slow-mo beat plays. A Game Over screen offers "Try again", which reloads the arena fresh. The HUD now reads "HP x / y". qa added a restart soak tool. (9744135, 99f6af2, 1f24ceb, d268f19, 7ad85ee)
- **Automatic light attack and manual heavy attack (Polish 1, Slice 3).** These replaced the old click-only basic attack. The light attack auto-fires at enemies in range and also fires on left click. The heavy is on right click, with a wind-up telegraph. Both are defined in `data/attacks.json`. The HUD gained LMB/RMB meters and slot ready/cooling states. (1c12fd9, de415be, b4011aa, ed0bf58, e8b7e45, 1fe89e5)
- **The agent team is in place**: game-lead, gameplay-dev, qa, ux-designer and playtester are active; art, audio and story are dormant. playtester and ux-designer were added on this date, and game-lead got the ability to run the other roles itself. (d6a6546, 112f5f0, 64e10ac)

### Changed
- **HUD layout (Polish 1, Slice 2).** Slots are fixed-size and long card names wrap, shrink, then truncate. The HUD has safe margins and a higher-contrast HP bar. Card names over 25 characters raise a warning. (f5b0c19, 88732cf, 366eabd, 60cd11e)
- **[Director decision] Polish 1 approved (Slice 0):**
  - Card rewards: pick 1 of 3 or reject all, with 3 rejects per run.
  - Density: fewer, more impactful enemies.
  - Controls: light attack (auto + left click), heavy attack (right click).
  - A survivor-style level-up idea was parked, with "do not implement".

  Recorded in the GDD. (a941ddd)
- **[Director decision] Enemy HP bars:** always visible while the enemy is alive, and the current size is fine. (edb92e4)
- **Balance: new attack numbers.**
  - Light: 8 damage every 0.6 s; clicks at most every 0.25 s.
  - Heavy: 22 damage, 1.8 s cooldown, 0.45 s wind-up.
  - Values before this are unclear from history; the old basic attack was a fixed-cooldown click arc.

  (1c12fd9)

### Fixed
- **The game showed only sky.** The camera's orientation was saved transposed (a file error), so it looked upward and the world never appeared; movement and aim were also wrong. (be64ea9)
- **Player kept moving and casting at 0 HP.** Death was never handled; fixed by Slice 1. (9744135)
- **HUD slots swallowed mouse clicks.** (b4011aa)
- **A flaky test** and a wrong README path. (ed0bf58)

### Docs and process
- Roadmap planning for HP bars and Polish 1 Slices 1-5, director answers logged, and balance questions P1-P4 raised for the director. (fe43425, edb92e4, b854bca, 1fe89e5, 4c2bfef)
- A session where role hand-offs were blocked was logged. The cause was that game-lead lacked the tool to run other roles, and it was fixed. (07aff8c, 64e10ac)
- Hand-off and status updates throughout. (43c8b48, bc5abb1, e34179e, afb47c8, 61d642c, 796542d, 612a0b6, 42c9d8c, 26d26f6, 9ec2e03, 7271aaa)

## 2026-10-26 (Milestone 1 GDD, project scaffold, Milestone 2 combat prototype)

### Added
- **Repository created** (3f3edce, an empty README). **GDD added** (c3ebd6d): the design document from the director's design interview, which is Milestone 1 (engine, 3D isometric view, Rogue/Wizard and Fire/Water for the first slice).
- **Project scaffold (Milestone 1.5).** Godot 4.7.2 project, gdUnit4 test framework, folder layout, working agreements, README, docs, and the first role agents: game-lead, gameplay-dev, qa, plus dormant art, audio and story. (5496508, 4fdcf86)
- **Milestone 2: combat feel prototype**, in one arena room:
  - Isometric camera, WASD movement and mouse aim. (4cb6e37)
  - Click basic attack, dodge roll with i-frames, and the health/damage foundation. (479a755)
  - Stat-modifier system for future passives and gear. (d6c266b)
  - Status effect system with Burn. (d031edd)
  - Seven reusable card effect templates: projectile, cone, area, dash, heal, apply status, buff. (f747a95)
  - Card data format and loader; slot types and card pools as data. (bfd3361)
  - The five card slots, each with a mini-deck, cooldowns and dead-card swap. (f613475, a82e756)
  - Three enemy types (melee chaser, ranged shooter, fire-resistant golem) and a wave spawner. (d311d28)
  - A 15-card Fire Rogue starter set. (4f27a16)
  - Bottom HUD and an F3 debug overlay. (680be9a)
  - Hit-stop, screen shake, damage numbers and hit flash. (1973fd1)
  - Headless bot-sim stub. (b6d370d)
  - Milestone 2 marked complete. (6c74bdc)

### Fixed
- **The test command could silently pass without running tests**, and a signal parameter shadowed a built-in name. (3432239)

### Docs and process
- Hand-off notes. (aed6cf9, 505ff8f) gitignore updates; the exact purpose of the second update is unclear from history. (5496508, 939e70b)
