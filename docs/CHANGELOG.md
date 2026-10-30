# Changelog: Chosen, Reluctantly

A plain-language history of the project for the director, grouped by date (from git commit dates). **Newest entry first:** new entries are always added directly under this header, never at the bottom. Hashes in parentheses are short git commit IDs.

## 2026-10-30 (Slice W1a: a playable Fire Wizard)

### Slice W1a: a playable Fire Wizard

Commits 451eaf3..HEAD. Gameplay 0c9704e and 39fe0c6; ux 7d93d1c, 82bce4e and 672622f; qa PASS b799153 (1053 of 1053; `docs/reviews/2026-10-30-w1a-qa.md`); playtest b5f2e02, no blocker (`docs/playtests/2026-10-30-w1a-wizard.md`). Judgment calls are in `docs/DECISIONS.md` under 2026-10-30 ("W1a gameplay build", "W1a ux"); the W1 split is under 2026-10-29.

#### Added
- **[Director decision] A second playable class, the Fire Wizard** (GDD section 5, "Wizard moved earlier"). New `data/characters.json` (read by `CharacterDatabase`): per class id, name, description, pools, starting deck, max HP and body colour. (0c9704e)
- **Wizard stats:** 26 HP (Rogue 30), purple body. Light attack: an auto-firing bolt, 2.4 neutral damage every 0.6 s = 4.0 DPS (80% of the Rogue's 5.0), range 12 m, speed 24 m/s, drawn cyan `#3fd9ff` via `attacks.json` `light_variants.wizard.bolt_look`. Heavy (`heavy.wizard`): a 2.0 m disc at up to 7 m, damage type physical -> neutral. (0c9704e, 7d93d1c)
- **Four Wizard cards** (pool `wizard`): Borrowed Focus, Footwork Allegedly, Sideways Blink, Tactical Hover. The Wizard starter is 15 cards; `--full-deck` gives 18 cards for the Wizard (24 for the Rogue). (0c9704e)
- **Class pick screen** (`ClassPickScreen`, `ClassPickCard`): opens on every run, including Try again and New run, and pauses the room behind it. 1/2 or the arrows highlight, Enter or a click confirms, Space is ignored during the arm delay, and the last pick is preselected. It is skipped when `--class` or `--deck` is given, headless, and in the arena. The last pick is remembered in `user://last_class.json` in windowed play only (`CharacterPick`). New `ui.json` blocks: `class_pick`, and `hud.meter_windup_words` / `hud.meter_ready_word`. (82bce4e)
- **The heavy meter says CAST for a targeted heavy (Wizard) and SWING for the Rogue's arc**, from data. (672622f)
- **Launch options** `--class=rogue|wizard` and `--show-class-pick` (forces the screen, for captures). Presets may carry `"class"`, and `--deck` alone sets the class. A `--class`/`--deck` mismatch, a bare `--class`, `--class` twice or an unknown class exits 2 with "Launch refused: ...". (0c9704e, 82bce4e)
- **Tools:** `run_wave_sim.ps1 -Class wizard` (whole runs, with `-Run`) and `run_reload_cycle.ps1 -Class wizard`; a `-Deck`/`-Class` clash is refused. (0c9704e, 39fe0c6)
- **Scenario** `wizard_bolt` and the new scenario key `character`. Known issue: the scenario body stays Rogue-coloured. (672622f)
- The projectile effect template gains the code-only params `direction`, `lane` and `look`. (0c9704e, 7d93d1c)

#### Changed
- **`starting_deck` and `character_pools` moved from `data/run.json` to `data/characters.json`** (per class). The Rogue's starter is unchanged. (0c9704e)
- **`RunState` saves a `character`;** a save without it loads as the Rogue. (0c9704e)
- `Player.owned_pools` is no longer a fixed export default: it is filled from the character unless a test or capture sets its own. (0c9704e)
- Captures should always pass `--class`, because the last pick persists in windowed play.

#### Docs and process
- **Process change:** the docs pass now happens per slice (game-lead runs tech-writer once at the end of each slice, as in `CLAUDE.md`).
- Docs pass for W1a: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- README: fixed two mangled command paths (`tools\run_wave_sim.ps1` and `tools\run_tests.ps1` in the examples and "Last verification" had a stray carriage return).
- Test count 996 -> 1053 across W1a (qa's figure; this pass re-ran it, see README).

## 2026-10-29 (Slice T-decks debug preset decks; Slice A1 armor; Milestone 3c boss encounter; Milestone 3b rewards and deck-clean; Milestone 3a run structure; content slice C1: deck rules, nine Fire Rogue cards, solid enemies, status cues)

### Slice T-decks: debug preset decks

Commits e7b0029..HEAD; build 9b6e8a6. qa passed (deb6ff1; `docs/reviews/2026-10-29-t-decks-qa.md`): 987 tests on HEAD plus 9 qa tests in `tests/unit/t_decks_qa_test.gd`.

#### Added
- **[Director decision] Debug preset decks for launches.** Named decks in `data/debug_decks/<name>.json` (`name` equals the file name, `description`, `full`, `starter` a sub-multiset of `full`). Adding a preset is one file, no code. Both lists must pass the deck rules; there is no bypass. Shipped: `fire-heavy-rogue`, `physical-rogue` (has 2 Fire cards, the minimum the rules allow) and `mixed-rogue`. New `src/run/DebugDecks.gd` and `RunSession.debug_deck`. (9b6e8a6)
- **Launch options** `--deck=<name>` (the preset's `starter`), `--deck=<name> --full-deck` (its `full` list) and `--list-decks` (prints names and descriptions, exits 0; exits 2 if a preset file is broken). The preset applies to the whole launch, so Try again keeps it. `--deck` is ignored with `--scenario` and in the arena. An unknown name, `--deck` twice, a bare `--deck` or an invalid preset exits 2 with "Launch refused: ...". (9b6e8a6)
- **Wave sim `-LightHeavyOnly`:** a bot policy that never presses card slots 1 and 2, so only light and heavy attacks hit. Not a deck; the random stream is unchanged. (9b6e8a6)
- README: a "Launch options" table listing every launch option with an example.

#### Changed
- **Wave sim `-Deck` now takes a preset name or `standard`** (passed to the game as `--sim-deck=`). Old: `standard|fire|physical|lightheavy`, test families that fixed the two attack slots. New: real, legal preset decks. A preset is only the starting deck; rewards change it during the run. (9b6e8a6)
- **`RunSession.skip_deck_minimums` is removed.** Nothing can start a run below the deck minimums any more. (9b6e8a6)

#### Docs and process
- 12-seed boss-fight result, `-Run -God`, median as a multiple of the standard deck: fire-heavy 1.02x, physical 1.07x, both inside the director's 70 to 130% band, so no retune. The A1 numbers (fire 0.93x, physical 1.04x) were seed noise. Details in `docs/DECISIONS.md`, "T-decks qa PASS". (43b7e35)
- Known: the reload soak (`tools/reload_cycle.gd`, "damage immunity leaked into a new room") flaked 2 of 3 under load before T-decks; it is assigned to P-dodge. Re-run once and note it until then.
- Docs pass for T-decks: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.

### Slice A1: armor

Commits b23d7df..HEAD. Director decision b6f85bd (GDD section 7, "Armor"). Gameplay b23d7df..e141dfe; ux 1604f6b..bcf13a5; readability fix f0cb109. qa passed at 965 of 965 (9292e4b; `docs/reviews/2026-10-29-a1-armor-qa.md`), and the readability fix at 966 of 966 plus 2 qa tests (70a761f; `docs/reviews/2026-10-29-a1-uxfix-qa.md`). Playtest found no blocker (ff6e7f6; `docs/playtests/2026-10-29-a1-armor.md`).

#### Added
- **[Director decision] Armor, a non-elemental mitigation channel** (GDD section 7). Physical and neutral damage is reduced by armor: reduction = armor / (armor + K), K 50, capped at 50%. Elemental damage still goes through resistance, and armor never touches it. Before A1, physical was skipped by a hardcoded check, so the boss took 0% from physical and 50% from fire. Settings are in the new `data/armor.json`, read by `ArmorConfig`; which damage types count as non-elemental is data (`non_elemental_types`). (735bda7, b6f85bd)
- **`Health.take_damage` is the single choke point** for both channels. Penetration is flat, read from the attacker's `armor_penetration` stat through `StatModifiers`. The player has armor 0 for now. Bleed ticks go through armor, Burn ticks through resistance, heals are untouched. (735bda7)
- **Armor values (new):** elite tier 17, `tiers.boss` 27 (unused by the real boss), `boss_guardian` 50 (`data/run.json`, `data/bosses.json`). Armor and resistance of one tier must give reductions within 2 points; checked at load and by tests. (735bda7)
- **Boss bar:** a shield pip and "Armor N% - Resists ..." text next to the resistance line. (1604f6b)
- **Elite bars:** a shield pip left of the resistance diamond; size is `hp_bars.pip_scale` in `data/ui.json`. (62463d8, f0cb109)
- **Damage numbers:** an armor-reduced hit shows `[9]` in muted grey at 85% size; a resisted hit shows `<4>`. The style appears only above a minimum reduction (`armor_min_reduction`, `resist_min_reduction`). Values under 1 show one decimal, never "0". (f67c317)
- **F3 overlay "Defense" block:** armor and resistance of the enemy under the cursor (else the nearest), plus the player's armor. (4d22904)
- **Scenarios** `boss_f3`, `elite_f3`, `armor_numbers` (new key `elite_indices`) for captures. (4d22904)
- **Wave sim `-Deck <standard|fire|physical|lightheavy>`:** fixed test decks for armor comparisons. The decks are not legal (a tool-only flag skips the run-start minimums). (62fa964)
  - Correction (T-decks docs pass): this wording is out of date. In T-decks (9b6e8a6) `-Deck` became a preset name or `standard`, the `fire`/`physical`/`lightheavy` families and the minimums skip (`skip_deck_minimums`) were removed, and the decks are legal.

#### Changed
- **Balance (re-tune to keep fight length, whole-run sim, 16 seeds):** elite `hp_multiplier` 2.5 -> 2.0; boss `max_health` 280 -> 195. Armor alone had stretched the median elite room from 41.9 s to 56.9 s and the boss fight from 63.7 s to 85.9 s; after the re-tune they are 40.6 s and 63.4 s. (e141dfe)
- **`tiers.boss.resistance_floor` 0.25 -> 0.35**, so its armor 27 passes the parity check and matches GDD section 7's 35% for bosses. (735bda7)
- **Boss bar width 480 -> 560 px** (`boss_bar_size` is now 560 x 104). At 1024x768 the bar fits and the blocks stack. (1604f6b, f0cb109)
- **Boss "all elements" text** is judged against the game's element list, not only the listed keys. (f0cb109)
- Deck families against the standard deck, real HP (bot, god mode, 8 seeds): fire 0.93x, physical 1.04x boss fight time (before armor: 1.08x and 0.85x), both inside the director's 70 to 130% band. Details in `docs/DECISIONS.md`.

#### Fixed
- A `BossHpBar` error when the boss is freed while the bar is binding (seen in long light/heavy-only runs; also present on the 3c tag). (1604f6b)

#### Docs and process
- Docs pass for A1: README, ARCHITECTURE (new "Armor and mitigation" part, `armor.json`, sharp edges) and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- Test count 907 -> 968 across A1.
- Known and logged: a light and heavy only bot is about 3.2x slower on the boss (was 3.5x); game-lead judged it a bot limit, not a director question. `armor_reduction(INF)` returns NaN (not reachable from data).


### Milestone 3c: the boss encounter, and the reward-screen scroll fix

Commits a35501d..8bc7241 (a35501d is the gameplay follow-up commit; gameplay a35501d..2234dc8; ux b8af93f..5245779; fix pass 741c624..b7a6a01). qa passed 3c at 903 of 903 tests (64df947; `docs/reviews/2026-10-29-m3c-qa.md`) and the fix pass at 907 (8bc7241). Playtest found no blocker (81b03d8; `docs/playtests/2026-10-29-m3c-boss.md`).

#### Added
- **A real boss: "The Overly Enthusiastic Guardian" (placeholder name, per DECISIONS)** replaces the 3a placeholder (a golem with HP x7). Everything is data in `data/bosses.json`, read by `BossConfig` (validator) and `BossRules` (pure rules); the brain is `src/enemies/Boss.gd` on `scenes/enemies/BossGuardian.tscn`. The boss is 280 HP, resists every element by 50% (GDD section 7, final boss), cannot be stunned, and takes no knockback. (31fa26e, a5303c2, 72b7985)
- **Four telegraphed attacks:** smash (cone), slam (disc on where you stood), volley (5 shot lanes), charge (a lane). Wind-ups run 0.77 to 1.1 s; the data floor is `rules.min_telegraph` 0.6 s, and a test (not load-time validation) checks every attack can be escaped by walking or by the dodge. (31fa26e)
- **Three phases** at 66% and 33% of HP: faster, a shorter gap between attacks, more attacks (charge from phase 2). Each change is a 1.2 s invulnerable roar. Phase 2 summons 2 chasers and phase 3 summons 2 shooters, at most 3 adds alive; the boss kills its adds when it dies. `Health.hp_floor` holds each threshold, so one big hit cannot skip a phase or kill the boss before its last one. (31fa26e)
- **Pinning rule:** the boss is not solid to the player or other enemies while it charges, and turns solid again only once it no longer overlaps the player, so a charge cannot trap you against a wall. (31fa26e)
- **Death beat:** 1.6 s of slow-motion and a burst with the player immune, then the win screen. The beat counts game time when hit-stop is off, so seeded sims still repeat exactly. (31fa26e, 2234dc8)
- **Template params** (optional, used by the boss): projectile `yaw_degrees` (turns the shot about the vertical axis, a fan) and aoe `vfx: false` (skip the template's own impact visual). (31fa26e)
- **`RunController.boss_spawned(boss)` and `current_boss()`** (the boss bar does not use them; it finds the boss by class). (a5303c2)
- **Boss HP bar (ux),** top centre while a boss lives: name, fill with ghost trail, a notch and line at each phase threshold, "Phase N of 3: name", a striped "Invulnerable" look during the roar, the resistance line, and the current attack's label with a draining wind-up strip. It finds the boss by class, so it also works in scenarios. New: `BossHpBar`, `BossMeter`, `BossAttackStrip`, `HudLayout.boss_bar_rect` and `debug_overlay_top`. (b8af93f)
- **Debug scenarios `boss`, `boss_edge`, `boss_phase3`** (9999 HP for both sides) for captures. The boss room itself: `-Scenario "" -Extra "--run-seed=1","--run-room=8"`. (a5303c2, b8af93f)
- **Sim tooling:** the run-mode bot leaves wind-up areas and dodges, and `run_wave_sim.ps1 -Run` prints a `boss fight (spawn to death)` line per run. The reload soak covers the boss fight, a phase transition and the death beat. (a5303c2, 72b7985)
- Test count 826 -> 907 across 3c and its fix pass.

#### Changed
- **Room indicator moved from top centre to top right** to make room for the boss bar; the F3 overlay now sits under the boss bar block (`HudLayout.debug_overlay_top`). (b8af93f)
- **Boss telegraphs are bolder:** lane alpha 0.3 -> 0.5 for boss lanes (`boss_lane_alpha` in `data/vfx.json`), the slam gets an inner ring, and cone outlines and aoe rings draw over bodies. Sizes are unchanged. (b8af93f, b7a6a01)
- **Boss attack label font 15 -> 22 px** (`boss_bar.attack_font_size`), attack row 22 -> 30 px, bar block 96 -> 104 px (`boss_bar_size`). (b7a6a01)
- **Boss pacing** (bot, seeds 1-8, 15-card starter): fight 52 to 67 s, mean 61 s (about 80 s with the placeholder); the bot won 8 of 8. HP tuned 520 -> 280. (72b7985)
- **The boss spawns with no tier,** so `tiers.boss` in `data/run.json` (HP x7) is now unused; qa logged removing it for 3d. (31fa26e)
- **3b follow-ups (ux):**
  - Offers list the slot's cards: "Slot N now: A / B / C" (separator is " / " because card names contain commas; first version used ", "). (5245779, 5a85712)
  - Effect lines carry units, from data (status numbers come from `statuses.json`).
  - Reject tile width 188 -> 216 px (`option_reject_width`) so "Reject" fits on one line.
  - Locked removal reads "Get another card for the Utility slot first (minimum 3 different)" on both the tile and the grid (`ui.rest.remove_locked`).
  - Continue and New run now ignore input for the arm delay (0.4 s), Space no longer confirms them, and the hints say Enter.
  - The reward panel sits below the HUD band, clear of the HP label.
- **`RunState.from_dict` rejects a bad `pending` value** (closes the 3b qa note; it now drops an unknown value and logs an error). The choice model gained `owned`, `next_room_type` and per-option `slot_contents`. (a35501d)

#### Fixed
- **[Director decision] Reward selection scrolled and clipped** in windows near or under 720p. Cause: the container around the panel reset the panel's fit scale to 1 every time it sorted its children, undoing the shrink-to-fit. The scale is now re-applied after every sort. Offers never scroll (tests from 1024x600 to 2560x1440, including a live window resize); only the removal grid scrolls. New `run_ui.offer_min_fit_scale` 0.45 (the removal grid keeps `option_min_fit_scale` 0.8); panel padding 28 -> 22 px (`prompt_panel_padding`). (741c624, qa 8bc7241)

#### Docs and process
- **[Director decision] Planned, not built: dodge charges** (GDD section 3; scheduled as slice P-dodge after the 3c close). The dodge gets charges, 3 to start (maybe 2; a data value), each recharging on a slightly longer cooldown than the old single dodge, with a HUD indicator. Passives may raise or lower the baseline (for example fewer charges for a tankier build); level-ups must never change it. Hard limits 0 to 4 after all modifiers. Today the dodge is still a single dodge with one cooldown (`data/player.json`). (bef7a8c, 467383d)
- Docs pass for 3c: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- Known and logged (not fixed): the Game Over screen still accepts Space and says "Enter or Space"; the boss body can cover the resist text; a doubled cooldown in some buff lines; player card visuals are drawn against the 0.45 m enemy radius so they understate reach on the boss's larger body (safe direction, accepted). qa's save-robustness findings go to 3d.

### Milestone 3b: reward screen and deck-clean

Commits fd2f644..d2cd00a (gameplay fd2f644..b8564cd; ux 56a76f0..d2cd00a). qa passed it at 826 of 826 tests (0a19808; review in `docs/reviews/2026-10-29-m3b-qa.md`). Playtest found no blocker (f2a3283; `docs/playtests/2026-10-29-m3b-rewards.md`).

#### Added
- **Card rewards.** After each won combat or elite room (never the boss or the last room) you get 3 card offers (`rewards.offer_size` in `data/run.json`). Pick one, or reject the whole offer. [Director decision] (GDD section 9): pick 1 of 3 or reject all, with 3 rejects per run (`rejects_per_run`). At 0 rejects you must pick. (fd2f644)
- **Seeded, pool-limited offers.** The offer comes from the run seed, the room index and the current deck, on its own RNG stream. Candidates are only cards in the character's pools. Cards you do not own weigh 4 and owned ones 1 (`unowned_weight`, `owned_weight`), so duplicates are possible but rarer. The offer shrinks if fewer cards qualify. (fd2f644)
- **Optional card field `requires`** (`slot_types`, `pools`, `status_sources`): a card is only offered when the deck and character meet it. No shipped card uses it yet. Checked by `CardSchema`. (fd2f644)
- **Rest room is now a choice:** Heal (30% of max HP, `rest_heal_fraction`) or Remove a card, then a card list with Back. Removal goes through the deck rules (`can_remove`): a card whose removal would drop a slot below its minimum is greyed out with the reason, and the remove tile is disabled when nothing can go. (fd2f644)
- **Reusable choice model.** `RunChoices` turns the run state into a list of options and resolves one; `RunController` gained `choice_requested`, `choice_resolved` and `choose()`. The same model can serve a later level-up screen. (fd2f644)
- **Choice screen (ux).** Reward cards show a number badge, name, slot pill, effect line, flavor and "You own N". The reject tile is narrower and darker, with pips for rejects left. Rest has two action tiles. The removal list is a per-slot grid that scrolls; keys 1-5 jump to a slot column. Keys 1-N highlight, Enter or a click confirms. Effect lines are built from effect params by `CardSummary.effect_line`, with wording in `data/run.json` `ui.effect`. (56a76f0, d2cd00a)
- **"Next: Room N of 8 - Type"** line on the choice screen (`ui.next_line`). (d2cd00a)
- **Save format v2.** `RunState` gained `pending`, `offer` and `choice_log`. A reload mid-reward reopens the same offer without replaying the room; a v1 state still loads. (fd2f644)
- **Debug args:** `--full-deck` (all 24 cards for the whole launch, including Try again) and `--run-auto-choose=<option ids>` (picks those options in turn, skipping the arm delay; for captures). (fd2f644, d2cd00a)
- **Bot sim plays the choices.** `run_wave_sim.ps1 -Run` picks, rejects and removes with a seeded policy and prints HP at each room end, the final deck size and per-slot composition, picks, rejects used, removals and rest heals, plus the mean room-end HP share per room. The reload soak also covers a reload mid-reward and Try again from a reward state. (82bf5d9, 9043866)
- 60 more test cases: 766 at the end of 3a, 826 at the qa pass, including 17 adversarial qa tests (removal fuzz over 300 decks, offers, rejects, real key input, a `force` audit). (689f2fd, 0a19808)

#### Changed
- **Starter deck 24 -> 15 cards:** the full rogue + fire + neutral pool (7 + 5 + 3 + 5 + 4) is now 3 cards per slot (`starting_deck` in `data/run.json`). Reason: with the full pool every reward was a duplicate and every removal was blocked. `--full-deck` restores all 24. Consequence: with exactly 3 unique per slot, no starter card can be removed until a pick adds a duplicate or a 4th card in that slot, so early rest rooms are mostly heal. (fd2f644)
- **Rest text:** a rest at full HP no longer says "Healed +0"; the heal tile reads "HP is already full". (fd2f644)
- **Rest room no longer ends at once:** it opens the heal-or-remove menu and the next room loads when you choose. (fd2f644)
- **Input safety on the choice screen:** options ignore input for 0.4 s after the panel opens (`run_ui.prompt_option_arm_delay` in `data/ui.json`), because the player is usually still mashing keys after a fight. Number keys only move the highlight. Presses are ignored while paused. (b8564cd)
- **`RunController.continue_to_next_room(force)`:** while a choice is open it does nothing; `force = true` (tests and debug only) discards the choice. Only `choose()` ends a choice in play. (fd2f644)
- **Game-lead calls** (not director decisions, logged in `docs/DECISIONS.md`): reject gives no card (no reroll); 4:1 weights; boss rooms are not reward rooms (`reward_room_types`); offers regenerate from the seed, a reload resumes the saved offer.

#### Fixed
- **Space confirmed the focused option** on the choice screen (it is also dodge); it is now swallowed while options are open. Focus returns to the highlighted option after a pause. (d2cd00a)
- **Buff cards showed raw ids** in the effect line; they now read like "Attack: Single cooldown -0.5 s for 6 s", with wording from data. (56a76f0)

#### Docs and process
- Docs pass for 3b: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.
- **Correction to the 3a entry below and the 3a README:** the wave sim does not fail on card pick-rate outliers; it prints them as a NOTE (`wave_sim.gd`, `_print_pick_rates`). The README and ARCHITECTURE are corrected.
- Known and logged by qa (not fixed): an unknown `RunState.pending` string would load as a choice with no options (not reachable until real saves exist); a few effect lines read oddly ("dash 6.5"); the 1440p reward panel slightly overlaps the dimmed HP label; the Continue / New run button has no arm delay.

### Milestone 3a: run structure

Commits a7731e2..013e7d7. qa passed it at 766 of 766 tests (a6a5d68; review in `docs/reviews/2026-10-29-m3a-qa.md`). Playtest found no blocker (013e7d7; `docs/playtests/2026-10-29-m3a-run-structure.md`).

#### Added
- **A normal launch is now a run.** The project's main scene is `scenes/main/RunMain.tscn`: 8 rooms in a straight line (5 combat, 1 elite, 1 rest, boss last), built from a seed. The elite lands in rooms 4-7 and the rest in rooms 3-7, and the first room is always combat. `scenes/main/Main.tscn` stays the endless arena for tests, scenarios, the wave sim and VpCapture. A `--scenario` launch keeps the arena. (a7731e2)
- **Run state across rooms.** `RunState` holds seed, room index, HP, deck card ids, rejects (3 per run), and room history; it serializes to JSON. Each room is a fresh scene, so cooldowns, the shuffle bag, zones, statuses and timers reset per room while HP and the deck carry over. A room won makes the player damage-immune until Continue, so a shot still in the air can't kill a winner. (a7731e2)
- **Run data in `data/run.json`:** room composition and placement rules, rest heal fraction, rejects per run, the starting deck (the whole current pool), elite and boss tiers, finite wave lists per room type, and the UI wording. The wave schema gained `finite` (the table ends instead of looping) and a per-spawn `tier`. (a7731e2)
- **Elites and a placeholder boss.** Elite: HP x2.5. Boss: HP x7, cannot be stunned (3c replaces this boss). Both: resistance becomes the larger of the enemy's own and 25%, capped at 50%. A flat diamond (elite) or star (boss) sign floats above the HP bar. The shape carries the rank, and the body is not bigger. (a7731e2, 8b54b25, c560d83)
- **Rest room.** Heals 30% of max HP and ends at once. (a7731e2)
- **Run UI (ux).** A "Room X of Y - Type" indicator at the top centre with a shape per type: circle combat, diamond elite, plus rest, star boss. A "Room cleared" panel with Continue shows HP and time ("Healed +N" on a rest room). A win screen shows rooms cleared, total time and HP left, with New run. The panel is generic (`show_content`, `options_box`), so the 3b reward screen can reuse it. (0f4e317)
- **Game Over in a run** adds "Reached room X of Y." Try again and New run both start a new seed. (0f4e317)
- **Launch args:** `--run-seed=N` (first run only), `--run-room=K` (1-based), `--run-clear-after=S`. (f47ae2e, f00ee65)
- **Tooling:** `run_wave_sim.ps1 -Run` plays whole seeded runs and checks for soft locks (`-RoomTimeout`), an empty deck, a stuck cooldown, and card pick-rate outliers; it reports lowest HP per room and the room-type distribution over 1000 seeds. `capture_screenshot.ps1` gained `-Extra` (comma list of game args), `-Scenario ""` to capture the normal run, and `-TrueSize` with `-Scenario ""` hosts RunMain in VpCapture. The reload soak also covers run mode. (f47ae2e, f00ee65, c560d83)
- 70 more test cases: 696 at the end of C1, 766 at the qa pass. (a7731e2..a6a5d68)

#### Changed
- **Elite and boss body scale** is 1.0 in `data/run.json` (the marker is the cue; hit shapes keep their data size). (c560d83)
- **Game-lead calls** (not director decisions, logged in `docs/DECISIONS.md`): linear rooms, 8 rooms, rest heals 30%, elite resistance is the larger of own and 25% (cap 50%).
- **Run stats on Game Over (D1)** were deferred "until the run structure"; a minimal one-line version shipped: "Reached room X of Y." (0f4e317)

#### Fixed
- **qa N5:** `Main` and `GameOverScreen` no longer depend on `current_scene`, so scene transitions work inside VpCapture.
- **Flaky `slice6_qa_test` crowd test:** tolerance 1e-6 -> 0.01 m. The drift (about 1e-4 m) comes from physics-engine sensitivity to allocation history, not from non-deterministic game code. (a6a5d68)

#### Docs and process
- Docs pass for 3a: README, ARCHITECTURE and this file. No new third-party assets, so `docs/ASSETS.md` is unchanged.

### Content slice C1

Slice C1 ran 2026-10-28 to 2026-10-29 (commits 2a985e4..d94676a; C1-a, C1-b1 and C1-t were built on 10-28). qa passed it at 696 of 696 tests (76bca75). The tooling task (true-size capture, seeded sims, dodge values in data) is listed under 2026-10-28.

### Added
- **Deck rules (C1-a).** `data/deck_rules.json` sets how many different cards each slot needs: 3 by default, with optional per-slot overrides and named slot groups with a combined minimum. A checker (`DeckRules`, `DeckCheck`) counts unique cards. Copies never count twice ([Director decision] D10: duplicates are allowed). Removing or swapping a card is refused when it would drop a slot below its minimum (`can_remove`, `can_swap`). The F3 overlay shows each slot's count and shortfalls. The director's example (attack group 10, utility 5, movement 3, recovery 3 = a 21-card minimum) exists only as a test fixture. (2a985e4, 73c8e72)
- **A run with a short deck is blocked (C1-c).** At run start, a deck that misses the minimums logs an error, switches the spawner off and emits `Main.run_start_blocked`. In C1-a it only warned, because the shipped deck was short. The shipped deck now passes. (22c8321)
- **New generic card abilities (C1-b1, C1-b2), all driven by data:**
  - `apply_status` can have a `chance`, and `hits`/`hit_interval`; cone, aoe and projectile can repeat `hits` times, `hit_interval` apart. (4236e5a)
  - Three statuses: **Bleed** (damage over time), **Regeneration** (heal over time) and **Leech** (lifesteal: a share of the damage you deal comes back as HP, with a per-hit cap). A `damage_dealt` event feeds Leech. (4236e5a, 87dbb87)
  - New `zone` template: a circle or line on the ground that ticks damage and an optional status chance for a set time. `data/zones.json` caps live zones (`max_live`) and holds the look. (b60fbe6)
  - New `pass_through` template: for a time, the player walks through enemy bodies. (114a1b3)
  - Dash gets `direction_mode` (`forward` or `away_from_aim`) and optional path damage (each enemy hit once). (114a1b3)
  - aoe gets `max_range` (placed at the aim point, clamped) and `delay` (the centre locks at cast and the telegraph grows). (114a1b3, 22c8321)
  - Placed skills draw a range reticle, with its look in data. (114a1b3, 3079dc7)
- **Nine new cards (C1-c; names and flavor by story in C1-d).** The preset Fire Rogue deck is now the whole rogue + fire + neutral pool. Slots hold attack_single 7, attack_aoe 5, utility 3, movement 5 and recovery 4 cards. Numbers live in `data/cards/`. (22c8321, 1b35908)
  - Slash, Then Bleed (single): a direct hit plus Bleed.
  - Four Quick Stabs (single): four small hits in a row.
  - Fireball, Incoming (aoe): aimed, delayed, with Burn.
  - Wall of Mild Fire (aoe): a line zone that burns whoever stands in it.
  - Walk Through Everyone (movement): pass through enemies for a few seconds. [Director decision] D9: Stealth is pass-through only for now; dropping enemy aggro comes later.
  - Reluctant Lunge (movement): a short dash that damages the first enemy it meets and stops there.
  - Nope, Leaping Away (movement, neutral pool): a long dash away from the aim, not invulnerable.
  - Heal By Hurting (recovery, neutral pool): Leech.
  - Eventual Healing (recovery, neutral pool): Regeneration.
- **Status and skill cues (C1-e).** Bleed shows a droplet pip on the enemy HP bar (alternating with the Burn pip); Regeneration a green ring; Leech a ring and a drain bead on hits. Heals on the player show "+N" numbers, batched every 0.25 s. Shadow Step makes the player see-through with a pale ring (a ghost). The Fire Wall has a burn-down timer bar that empties as the zone ends and blinks near the end. Dashes preview with arrowheads. Placed skills show a range ring and a marker where the aim lands (a diamond with a link line when clamped to max range). The F3 overlay is styled. A new `PlayerCues` node, attached from Main, holds the player cues. [Director decision] D11: the neutral cards use the neutral palette. (31fece2, 3079dc7, 353070f)
- **New capture scenarios:** `c1_status`, `c1_status_crowd`, `c1_placed`, `c1_placed_near`, `c1_moves`, `c1_names`, `c1_overlay` (see the README). (3079dc7)
- **Test helpers and sim lines:** `tests/support/body_flag.gd`, `test_caster.gd` and `test_clock.gd`; the wave sim prints pinned-frame and max-feet-height lines. (de9f916, 87ede1f)

### Changed
- **[Director decision] D8 = C: dodge speed 28 -> 20** (distance 7.0 m -> 5.0 m; the 0.25 s duration and i-frames are unchanged). It is one number in `data/player.json`. The code fallbacks were aligned to 20 too. History: 3.5 m intended, about 7.1 m in practice (slide bug), 3.5 m after S6-2, 7.0 m under the D8 default, now 5.0 m. (73c8e72, 4b1820a)
- **Enemies are now solid bodies.** `data/player.json` `body.collide_with_enemies` is true; before, player and enemy bodies effectively never collided. Neither body can ride the other, and enemies spawn in place. This is game-lead's call, not a director decision (logged in `docs/DECISIONS.md`, kept on pending the playtest). In the seeded sim (seeds 1/2/3, 150 s) HP lost about doubled: 49/47/41 with the flag off and the new cards, 86/91/83 with it on. The bot never uses Shadow Step on purpose, so this overstates the cost for a human. Set the flag to false to restore the old behaviour. (fcc72af, de9f916)
- **Hit-stop and screen shake now fire only on direct hits.** Before, every damage event did, including Burn ticks. Burn, Bleed, zone ticks and follow-up hits now show the number and flash only. A multi-hit dash hit-stops once per enemy. (4236e5a, 114a1b3)
- **Status tuning:** Regeneration `heal_per_tick` 1.0 -> 2.0 (14 HP over 7 s). Leech `fraction` 0.3 -> 0.4 and `max_heal_per_hit` 2.0 -> 3.0. Bleed unchanged. (22c8321)
- **A one-card slot's "next" preview** now shows that card instead of being blank (side effect of the shuffle fix). (741816c)
- **Card name rows** use `fit_padding` 12 (was 2) and line spacing 0, so a two-line name fits. (16eecd9)

### Fixed
- **Shuffle bag.** The old shuffle ran while the last-drawn card was still in hand, so that card was missing from the next cycle (a 3-card deck could cycle c1, c1, c2). The bag now refills from all owned copies, and the first card of a new bag is never the card just drawn (when another unique card exists). (741816c)
- **Game Over beat was too short** (869 of 900 ms under slow-mo). It is now counted from `Time.get_ticks_usec()`, with paused time excluded. (4b1820a)
- **Card name rows clipped their second line** (found on "Walk Through Everyone"). A test now pins every card name at 720p, 1080p and 1440p. (16eecd9)
- **Lifesteal no longer heals at full HP,** and counts HP actually removed (no overkill). (87dbb87)
- **A player standing at the arena origin was popped onto a spawning enemy.** Enemies now spawn in place, and a Shadow Step that ends inside an enemy restores collision only once the player is clear (3 s cap). (de9f916)
- **Flaky tests (C1-t):** the pause and crowd-determinism tests used timers that Godot overcounts after a hit-stop (a 0.1 s timer fired after 76 ms) and unisolated hit-stop. They now wait with `TestClock.wait_real`; 597 of 597 passed in 3 of 3 runs. (da1115a)
- **Reload soak** now places a Fire Wall and a pass-through grant, reloads with the buff live, and checks the static pass-through flag and mask. The attack_meter and slice4 node-growth tests were hardened. (76bca75)

### Docs and process
- **C1-t test gate repair (qa).** Flaky tests were fixed before more content landed. (da1115a)
- **qa C1-f PASS** (76bca75, 696 of 696): review in `docs/reviews/2026-10-29-c1f-qa.md`. Known gap: the Lunge preview shows the full 3 m path even when a body will stop it short.
- **Playtest C1-g / Polish 1 close-out** (d94676a): `docs/playtests/2026-10-29-c1-and-polish1-closeout.md`.
- **[Director decision] D12:** the order of work was the tooling task, then C1, then the end-of-pass playtest.
- game-lead housekeeping (fe3c785): `docs/OPEN_ITEMS.md` restructured; `.claude/settings.local.json` added to `.gitignore`.
- **Docs pass C1-h** also covers the tooling task: README, ARCHITECTURE and this file updated. There are no new third-party assets, so `docs/ASSETS.md` got no new entries.

## 2026-10-28 (Polish 1: Slice 6 fix pass, Slice 5 waves and readability, Slice 4 skill visuals, Slice 3b attack rework, director open items)

### Added
- **Tooling task: true-size capture.** `capture_screenshot.ps1 -TrueSize WxH` runs the real game inside a SubViewport of exactly that size (`tools/VpCapture.tscn`), so 1920x1080 and 2560x1440 captures are no longer clamped to the monitor. A new `WorldRef` helper tells effects, popups and screens where the arena is when `current_scene` is null. Normal play and tests are unchanged. (c4a3747; qa PASS b5a796a, 552 of 552 tests)
- **Tooling task: seeded sims repeat exactly.** The same `-Seed` now gives the same wave-sim and bot-sim result on the same machine and build. This closes qa finding S6-4. Fixes: card shuffles, the player's status RNG and the camera-shake RNG are seeded, the sims run at a fixed 60 fps (`--fixed-fps 60`), hit-stop is off in the wave sim, and buff ids use a counter. `run_bot_sim.ps1` gained `-Seed` and prints a checksum. (3402446)
- **Dodge values are data.** New `data/player.json` holds dodge speed, duration, cooldown and the post-pause block ticks, read and checked by `PlayerConfig`. (3e9e02a)

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
- **Dodge speed 14 -> 28 (distance 3.5 m -> 7.0 m)** in the tooling task, as the director-question D8 default while it was open. It was changed again on 2026-10-29 (see there). (3e9e02a)
- **Enemy shot lane tip padding.** The pink lane strip an enemy shooter draws now extends by the real reach against the player's capsule, matching its sides (it ended a few cm short). (968e9f0)
- **Feel change (S6-2): dash and dodge now stop at their data distance.** Before, a forced move kept sliding after it ended (friction carried it about twice as far, and the extra depended on frame rate). Now it ends exactly at speed x duration and stops, at any frame rate. Dodge roll: about 7.1 m -> 3.5 m (*correction 2026-10-29: the dodge values were Player exports at the time; they moved to `data/player.json` in the tooling task, see below*). Blaze and Bail dash: about 8.1 m -> 4.0 m. Ugh, Fine, Moving (data distance 4.5 m) uses the same code and shortened too; its old distance was not measured (unverified). Dodge i-frame time and cooldown are unchanged. In qa's seeded wave sim the bot lost about 2.5x more HP after this. The preview and the data distance already said 4.0 m, so the fix moved the player, not the preview. **D8 was open then** (*correction 2026-10-29: the director answered D8 = C; the final dodge is 5.0 m, see the 2026-10-29 entry*). (7b7a471)
- **Balance: golem wind-up** 0.45 s -> 0.7 s (director item D6, default A applied). Its attack cycle goes 2.25 s -> 2.5 s and its damage per second 4.0 -> 3.6. Hit damage is unchanged at 9. (acc26a4)
- **Damage numbers are bigger:** about 12 px -> 20 px at 720p, with an outline. Quick hits on the same spot merge into one number, and at most 16 show at once. **IMMUNE** now draws above HP bars. The cone, heal, dash and projectile trails read more strongly, and their timings are now data. A ring shows when a stun cancels an enemy's wind-up. Enemy HP bar visibility is now one data setting with four modes (shipped as "always" at the time; switched by director call D7 in 6b, see efaf164). (058d3dd, 3ae40b7, 39c03e6, b50aa0c, bff7581)
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
- **Slice 6 fix pass** (qa FAIL 957fa16, re-check PASS 57be0a1, 542 of 542 tests):
  - **S6-1:** an attack click latched just before a pause no longer fires when you resume. The latch is cleared on pause, death, focus loss and a cast-trigger change. (17b28a2)
  - **S6-3:** the projectile preview lane and ground marker now reach the true hit distance (they stopped short of the real hit reach; qa saw a hit still land 0.3 m past the drawn tip). (0e4d9b5)
  - **S6-5:** pressing Space on the focused Resume button no longer also dodges. Dodge is ignored for 2 physics ticks after a pause or resume (a code constant, `DODGE_BLOCK_TICKS_AFTER_PAUSE`). (6738109)
  - **S6-6 (test-only):** removed four stray engine error lines (`Parameter "material" is null`) from full test runs. Nothing changed in play. (1ed76f4, 5095be9)
  - **S6-7:** if the settings file can't be saved, the settings screen shows a note and logs an error instead of forgetting the choice silently. New `data/ui.json` keys `settings_screen.save_failed` and `settings_screen.save_failed_color`. (9e6c417)
  - **S6-4 is still open:** a seeded sim run does not repeat (see the README). It is a non-blocking item for a later capture and sim tooling task. *(Correction 2026-10-29: fixed in the tooling task, listed above; the same seed now repeats exactly.)*
- **5d fixes from qa:** a crowded enemy waiting to swing could slide faster than its top speed (now capped). A broken enemy stats block is now caught when the game loads. Enemy sidestep direction now comes from spawn order instead of an internal object id, so the steering itself repeats (a whole simulated run still does not repeat from a seed; see the 6c review). (c3d244f, 6e8c3e6, a23a960)
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
- **Docs pass for the Slice 6 fix pass and the new reference docs.** New `docs/ARCHITECTURE.md` (code map, data flow from a card press to an applied effect, how-to-add checklists, gotchas). `docs/ASSETS.md` now lists everything in the repo: one third-party library (gdUnit4, MIT), no art, audio or fonts, and three project-authored files. README commands were run and the README corrected (6f67367). README rewritten after running every command: it now has a docs index, repo layout, controls, a table of all 12 capture scenarios with working capture times, the two extra capture helpers, the sim flags, and a truthful note on seeds. The wave sim prints "rerun with --seed=N" and the README called the sims "seeded"; that is only partly true: the wave plan and steering repeat, a whole run does not (S6-4). The bot sim wrapper `run_bot_sim.ps1` has no seed parameter, so its own "rerun with --seed" hint can't be followed through the wrapper. README capture example `--screenshot-out=shots/a.png` pointed outside the gitignored `screenshots/`; it now uses `screenshots/`. (6f67367)
- **[Director decision] tech-writer role added, and doc ownership split.** tech-writer owns `README.md`, `docs/CHANGELOG.md`, `docs/ASSETS.md` and `docs/ARCHITECTURE.md`. game-lead owns `docs/GDD.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/STATE.md`, `docs/OPEN_ITEMS.md` and `CLAUDE.md`. Other roles don't edit docs they don't own; they report needed changes in their hand-back. (b4c735a)
- **[Director decision] one docs pass per slice or multi-agent task.** game-lead runs tech-writer once at the end, between playtester and close, with a short doc handoff note. The loop is now build -> qa -> playtester -> tech-writer -> game-lead close; a slice can't be marked done until the docs pass is complete. Whoever adds a third-party asset gives tech-writer its source, author and license at that time. qa's slice review checks that the README commands work and the CHANGELOG has an entry. The changelog rule now names tech-writer as its owner. (b4c735a)
- **[Director decision] what goes in `docs/DECISIONS.md`.** Only assumptions, defaults and judgment calls that agents make on their own. Director directives are recorded in the GDD (design), `CLAUDE.md` (process), and this changelog with the `[Director decision]` tag. Existing DECISIONS entries stay as they are. (b4c735a)
- qa's Slice 6 re-check passed all six items (blockers S6-1 and S6-2; plus S6-3, 5, 6, 7) with 542 of 542 tests, plus two extra qa probes. qa flagged that the bot lost about 2.5x more HP with the shorter dodge, as a playtest call (see the S6-2 entry). (57be0a1)
- game-lead recorded the fix pass and the D8 question. (84abe1e, 44c5d73, dcdb043)
- game-lead corrected the 5b damage-numbers bullet the 5b damage-numbers bullet: the HP bar mode note had gone stale after D7 (fact fix, qa S6-9).
- **5d closed** (qa re-check PASS 957fa16). **Slice 6 qa FAIL** on two small blockers: an attack click latched before a pause fired after resume, and the dash preview showed 4 m while the dash really ends about 8 m away. A fix pass is in progress. (957fa16, 0d670df) **Correction (tech-writer, 2026-10-28):** the fix pass finished and qa's re-check passed (57be0a1, 542 of 542 tests); see the Slice 6 fix pass entries under Changed and Fixed above.
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
