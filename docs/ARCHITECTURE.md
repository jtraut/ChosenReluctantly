# Architecture

A map of the code for a new agent. Read this first, then open the files it links. Every path below exists; line-level detail is left to the code. Numbers that change (balance, timings) live in `data/`, not here. Engine: Godot 4.7.2, statically typed GDScript. Last verified against HEAD 013e7d7 (2026-10-29, after Milestone 3a).

## 1. Repo layout

| Path | What lives there |
|---|---|
| `project.godot` | Main scene `scenes/main/RunMain.tscn`, four autoloads, physics layer names, gdUnit4 plugin enabled |
| `src/camera/` | `CameraRig` (follow + shake) |
| `src/cards/` | Card data and slots: `CardDatabase`, `CardSchema`, `CardSlot`, `CardSlotController`, held-key cast: `CastInput`, `CastPreview`, `CastPreviewShapes`, `CastPreviewConfig`; deck rules: `DeckRules`, `DeckCheck` |
| `src/combat/` | Damage and effects: `Health`, `Hurtbox`, `EffectTemplates`, `EffectContext`, `Projectile`, `MeleeQuery`, `CombatMath`, status system (`StatusDatabase`, `StatusEffectManager`, `StunRules`), attack data (`AttackDatabase`, `AttackStatuses`), `CardDamageRule`, `AoeTargeting`, `CollisionLayers`, zones (`ZoneManager`, `ZoneShape`, `ZoneConfig`), `TrainingDummy` (debug only) |
| `src/core/` | Autoloads and shared data access: `InputBindings`, `Juice`, `Settings`, `GamePause`; `SettingsStore`, `JsonDataTable`, `PoolDatabase`, `SlotTypeDatabase`, `StatModifiers`, `WorldRef` |
| `src/debug/` | Capture and scenario tooling: `CaptureArgs`, `Scenario`, `ScenarioSchema`, `ScreenshotCapture` |
| `src/effects/` | Visual effects: `EffectPool`, `PooledEffect`, `TemplateVfx`, `ElementVisuals`, `VfxConfig`, `VfxSizing`, `DamageNumber`, `GroundOutlines` (ground ring/outline builders shared by the preview and zones) |
| `src/enemies/` | `Enemy`, `EnemySpawner`, `WaveConfig`, `WavePlan`, `EnemyConfig` |
| `src/main/` | `Main` (wiring, death beat, restart), `SceneSelfCheck` |
| `src/run/` | Run structure (3a): `RunConfig` (loads and validates `data/run.json`), `RunGenerator` (seed to room list), `RunState` (what carries across rooms), `RunSession` (static holder), `RunController` (one room's flow), `TierRules` (elite/boss maths) |
| `src/player/` | `Player`, `PlayerConfig` (`data/player.json`), `AttackController`, `AttackArcVisual`, `PlayerCues` (ghost, heal numbers, Leech drain), `PlayerOcclusionCue` (+ its `.gdshader`) |
| `src/ui/` | `Hud`, `HudLayout`, `CardSlotWidget`, `AttackMeter`, `EnemyHpBar`, `GameOverScreen`, `SettingsScreen`, run UI: `RunHud`, `RunPromptScreen`, `RunPromptRows`, `RunIcons`, `RunTypeIcon`, `TierMarker`, `AimIndicator`, `DebugOverlay`, `TextFit`, `UiConfig` |
| `scenes/` | `main/RunMain.tscn` (Main plus run nodes), `main/Main.tscn` (endless arena), `player/`, `camera/`, `enemies/` (3 types), `effects/` (Projectile, DamageNumber), `ui/`, `debug/TrainingDummy.tscn` |
| `data/` | All content and tuning as JSON (section 6) |
| `assets/` | `icon.svg`, `shaders/enemy_hp_bar.gdshader` only. No art or audio |
| `tests/` | gdUnit4 suites in `tests/unit/`, JSON fixtures in `tests/fixtures/`, helpers in `tests/support/` (`test_input.gd`, `body_flag.gd`, `test_caster.gd`, `test_clock.gd`) |
| `tools/` | PowerShell wrappers and headless/capture scripts (section 9) |
| `docs/` | Design, decisions, roadmap, state, reviews, playtests, and the four tech-writer docs |

Rule from `CLAUDE.md`: content is data, not code. A new card, enemy or status should not need a new script unless it brings a brand-new effect type.

## 2. Scene and run flow

There are two entry scenes:
- `scenes/main/RunMain.tscn` is the project's main scene. It is an inherited instance of `Main.tscn` with `run_mode = true` plus `RunController`, `RunHud`, `RoomClearedScreen` and `WinScreen` (both `RunPromptScreen`, the second with `kind = "win"`).
- `scenes/main/Main.tscn` is the endless arena (looping waves from `data/waves.json`, no rooms). Tests, `wave_sim` (without `--run`), `ReloadCycle` and scenarios use it.

`Main.tscn` children: `WorldEnvironment`, `Sun`, `Floor` (CSG box), `ArenaWalls` (invisible static walls), `Player`, `CameraRig`, `EnemySpawner`, `Hud`, `GameOverScreen`, `SettingsScreen`, `DebugOverlay`.

`Main._ready` ([src/main/Main.gd](../src/main/Main.gd)):
1. Hands the player to the camera rig, the spawner, the HUD and the debug overlay; gives the player the camera for aiming.
2. Attaches `AimIndicator`, `PlayerOcclusionCue` and `PlayerCues` to the player; registers itself with `WorldRef` (`_enter_tree`).
3. `_setup_run_mode`: if `uses_run_mode(run_mode, user args)` (pure static: `run_mode` is true and there is no `--scenario` arg) and `data/run.json` is valid, calls `RunController.begin(self)`. Otherwise it removes the run nodes (`RunController`, `RunHud`, `RoomClearedScreen`, `WinScreen`) so the scene is the endless arena. An invalid `run.json` logs an error and falls back to the arena.
4. `_check_starting_deck`, then `SceneSelfCheck.find_problems` (`push_error`s if the world would render empty).
5. If user args follow `--`, sets up scenario and screenshot capture (`Main._setup_debug_capture`).

Deck check: `Main` checks the deck rules (`DeckRules.run_start_block_message`). A short deck is blocked: `push_error`, the spawner is switched off, and `Main.run_start_blocked(message)` is emitted. The shipped deck passes.

### Run flow (Milestone 3a)
- **Config:** `data/run.json` (section 6) is loaded and validated by `RunConfig`. `RunGenerator.generate(seed, config)` returns the room list (each entry has `index`, `type`, `wave_id`) from a seeded shuffle that follows `composition` and `placement` (boss last, first room combat, elite and rest inside index ranges). The same seed gives the same rooms.
- **State:** `RunState` holds seed, room index, HP and max HP, deck ids, rejects left, history and outcome. It serializes with `to_json`/`from_json`. `RunSession.current` (a static, not an autoload) keeps it between scenes; `RunSession.begin_new_run` is the only way to start a fresh one (it consumes `forced_seed` once).
- **A room:** `RunController.begin` puts the state's HP and deck on the player, builds the room's finite wave table (`RunConfig.room_wave_config`), configures the spawner with it and a seed from `room_spawn_seed(run_seed, room_index)`, and emits `room_started`. `_process` watches `EnemySpawner.room_cleared()`. A rest room heals `rest_heal_fraction` of max HP and ends at once (spawner off). `_finish_room` sets `Health.damage_immune` on the player (so a projectile in flight can't kill a winner), records history, and emits `room_cleared` or, on the last room, `run_won`.
- **Next room:** the Continue button calls `RunController.continue_to_next_room`, which bumps the index and calls `Main.swap_to_fresh_scene`. A fresh scene resets cooldowns, shuffle bags, zones, statuses and timers; the `RunState` carries HP and the deck.
- **Death:** `Player.player_died` goes through the normal death beat to Game Over, which shows "Reached room X of Y". Try again and New run both call `Main.restart_arena`, which in run mode does `RunSession.begin_new_run()` (new seed) and swaps the scene.
- **Launch args** (`RunController._apply_launch_args`, first scene of a launch only): `--run-seed=N`, `--run-room=K` (1-based), `--run-clear-after=S` (debug: clears that room after S seconds).
- **Tiers:** a wave spawn can carry `tier` (`elite` or `boss`). `EnemySpawner` calls `Enemy.apply_tier(tier_id, cfg)` with the `data/run.json` `tiers` entry: HP multiplier, resistance via `TierRules.resistance` (the larger of own and the floor, capped), rank, and a `TierMarker`. The boss in 3a is a placeholder (3c replaces it); it is unstunnable.
- **UI:** `RunHud` shows "Room X of Y - Type" with a `RunTypeIcon` (shapes from `RunIcons`: circle combat, diamond elite, plus rest, star boss; placed by `HudLayout.room_indicator_rect`). `RunPromptScreen` is a generic panel (icon, title, subtitle, flavour line, label/value rows, `options_box`, one action button). To reuse it (3b rewards), fill `options_box` and call `show_content(dict)`; the text rows come from `RunPromptRows`. `TierMarker` is the flat diamond/star sign above an elite's or boss's HP bar (shape, not colour, and no bigger body). Look and sizes: `data/ui.json` `run_ui`; words: `data/run.json` `ui`.

Death and restart:
- `Player.player_died` (from `Health.died`) -> `Main._on_player_died` starts slow-mo and shake via `Juice`. The beat is timed in `Main._process` from `Time.get_ticks_usec()` (paused time excluded), because Godot's ignore_time_scale timer overcounts the frame where the time scale changes.
- When the beat ends `Main` calls `Main._announce_game_over`, which emits `Main.game_over_ready` once. `GameOverScreen` listens, shows itself, and on "Try again" calls `Main.restart_arena()`.
- `restart_arena()` (in run mode it starts a new run first) calls `swap_to_fresh_scene()`, which resets `Juice` and `GamePause`, unpauses, and replaces the scene with a fresh copy of itself in the same place in the tree (deferred; it does not rely on `current_scene`, so it works inside VpCapture). If the scene has no parent or file path it falls back to `reload_current_scene()`. The fresh scene resets everything that lives in the scene (HP, decks, cooldowns, enemies, waves, statuses). Autoload state does not reset on its own, which is why `Juice.reset()` and `GamePause.reset()` are called first.

## 3. Autoloads (`project.godot`)

| Name | File | Job |
|---|---|---|
| `InputBindings` | `src/core/InputBindings.gd` | Builds the `InputMap` from `data/input_bindings.json` on `_enter_tree` |
| `Juice` | `src/core/Juice.gd` | Combat feel: `hit_stop`, `slow_mo`, `screen_shake`, damage numbers and popups (merge + cap), `freeze_time`/`thaw_time` for pause |
| `Settings` | `src/core/Settings.gd` | Wraps a `SettingsStore` (defaults `data/settings.json`, user values `user://settings.cfg`); `changed` signal; `cast_trigger()` |
| `GamePause` | `src/core/GamePause.gd` | The only code that should touch `get_tree().paused`. Refuses to pause once Game Over is up |

## 4. Core systems

### Player ([src/player/Player.gd](../src/player/Player.gd), `scenes/player/Player.tscn`)
- `CharacterBody3D` with child nodes `Health`, `StatusEffectManager`, `Hurtbox` (team "player"), body mesh.
- Movement is relative to the fixed camera; aim is the mouse ray on the ground plane (`get_aim_point`, `get_aim_direction`).
- Owns: `card_slots` (a `CardSlotController`), `stat_modifiers` (a `StatModifiers`), `attacks` (an `AttackController` built in `_setup_attacks`), `cast_input` (`CastInput`), `cast_preview` (`CastPreview`).
- Character identity is `owned_pools` (export, default rogue + fire + neutral). Class = first owned pool with kind "class"; element = first with kind "element" (`data/pools.json`). There is no character creation yet.
- Dodge: Space, `start_forced_move` with i-frames. `Hurtbox.set_invulnerable` makes i-frames by zeroing the hurtbox collision layer, so attack queries skip it. Dodge speed, duration, cooldown and post-pause block ticks come from `data/player.json` through `PlayerConfig` (copied into `dodge_speed` etc. in `_ready`).
- `start_forced_move(direction, speed, duration, invulnerable, vfx_look)` is shared by the dodge and the "dash" effect template. It ends exactly at `speed * duration` and stops dead (S6-2).
- Input model: light/heavy clicks and card keys are latched in `_unhandled_input` (so a UI screen can swallow them); movement and dodge poll `Input`. Latched casts and clicks are consumed on the next physics tick. Pause, death, focus loss and a cast-trigger change call `cancel_cast_preview()`.
- Solid bodies: if `data/player.json` `body.collide_with_enemies` is true (shipped), the player's mask includes the enemy layer and enemies' masks include the player layer; both use `platform_floor_layers = WORLD` so neither can ride the other. `EnemySpawner` positions an enemy before `add_child`. `pass_through` clears the enemy bit for a time (static flag); when it ends inside an enemy, collision returns only once the player is clear (3 s cap). False restores the old walk-through behaviour.
- `Player.default_rng_seed` (static, -1 = random) seeds the card and status RNGs for sims. Signals: `player_died`, `pass_through_changed`, `damage_dealt`, and forwarded `attack_started/fired/ready/cancelled(attack_id)` for the HUD meters.

### Camera ([src/camera/CameraRig.gd](../src/camera/CameraRig.gd))
Fixed-angle isometric rig. Root follows `target`; child `Camera3D` keeps a fixed offset plus shake jitter. Orthographic. `Juice.register_camera_rig` lets `Juice.screen_shake` reach it.

### Combat and damage
- `Hurtbox` (Area3D) has a `team` and paths to `Health` and `StatusEffectManager`. Attacks find hurtboxes by physics query (`MeleeQuery.find_hurtboxes_in_cone / in_sphere`), skipping the caster's own team (no friendly fire).
- `Health.take_damage(amount, type, knockback)` applies the resistance fraction (`CombatMath.apply_resistance`, capped), lowers HP (ignored while `Health.damage_immune` is true; the run sets it on a won room), emits `damaged`, `health_changed`, and `died` once.
- `Player._on_damaged` and `Enemy._on_damaged` call `Juice.on_hit_landed` (damage number; hit-stop and shake **only for `Health.KIND_HIT`**, not `KIND_DOT` ticks or `KIND_ECHO` follow-up hits) and apply their own hit flash and knockback.
- `Health.take_damage(..., source, kind)` emits the source's `damage_dealt(target, removed, damage_type, kind)` (HP actually removed, after resistance). Leech listens to it through `StatusEffectManager.on_damage_dealt`.
- Layers: `CollisionLayers` (World 1, Player 2, Enemy 4, Hurtbox 8, Hitbox 16), named in `project.godot`. Player and enemy bodies are solid to each other (see Player).

### Card slots and decks
- `CardSlot` ([src/cards/CardSlot.gd](../src/cards/CardSlot.gd)): pure `RefCounted`. A shuffled mini-deck (draw pile, discard pile) over the cards owned for one slot type, plus a cooldown. Cooldown = slot base + card `cooldown_modifier`, then `StatModifiers`, floored. Swapping a dead card is blocked while cooling.
- `CardSlotController`: builds the five slots in `SLOT_TYPE_ORDER` (attack_single, attack_aoe, utility, movement, recovery), filters cards by `owned_pools`, and on `try_use(slot_type)` casts the revealed card through `EffectTemplates`. Emits `card_cast`.
- Keys: `slot_1..5` to use, `Ctrl+1..5` (`dead_card_swap_N`) to swap.

### Deck rules
- `data/deck_rules.json` -> `DeckRules` (pure static logic; `shipped_config()` is cached because the F3 overlay reads it every frame). Config: `min_unique_per_slot`, optional `slots: {slot: {min_unique}}`, optional `slot_groups: [{name, slots, min_unique_total}]`. Copies never count twice.
- `DeckRules.check(...)` returns a `DeckCheck` (per-slot and per-group `count/required/short`, `problems`, `summary_lines()`). `can_remove` / `can_swap` return the problems a change would cause (empty = allowed); they only block on the card's own slot and groups. `CardSlotController.deck_check()`, `can_remove`, `can_swap` wrap them for the live deck.
- `DeckRules.validate_shipped_content()` (run by a test, not at boot) checks the shipped pools against the minimums. `Main` blocks run start on a short deck (section 2).
- The shuffle is a true bag: it refills from all owned copies when empty, and never repeats the card just drawn across a reshuffle (when another unique card exists).

### Held-key casting (Slice 6)
- `CastInput` tracks which slot key is held. In `release` mode (default, `data/settings.json`) press starts a preview and release casts; in `press` mode press casts at once.
- `CastPreview` draws the held card's exact hit area on the ground (shapes from `CastPreviewShapes`, sizes from `VfxSizing`, same numbers as the hit query; look from `data/cast_preview.json`). `Player.get_preview_state()` exposes it to tests and the HUD.

### Effect templates ([src/combat/EffectTemplates.gd](../src/combat/EffectTemplates.gd))
Nine reusable effects: `projectile`, `cone`, `aoe`, `dash`, `heal`, `apply_status`, `buff`, `zone`, `pass_through`. `REQUIRED_PARAMS` is the single source of truth for each template's required params; `CardSchema` validates against it. `EffectContext` carries `caster`, `spawn_parent`, `caster_team` and `last_hits` (hurtboxes the previous effect in the same card hit, which `apply_status` targets). Optional params (the list in the file header is authoritative):
- Any damaging effect: `knockback_strength`; `hits` + `hit_interval` (cone, aoe, projectile, apply_status; `hit_interval` required when `hits` > 1). Follow-up hits re-query from the caster's live position and stop if the caster is gone.
- `apply_status`: `chance` (rolled on the seeded `status_rng`), `target: "self"`.
- `cone`: `vfx` (false skips the wedge). `aoe`: `center` (code-only, targeted heavies), `max_range` (place at the clamped aim point), `delay` (centre locks at cast, telegraph grows).
- `dash`: `invulnerable`, `direction_mode` (`forward` | `away_from_aim`), path damage (each enemy hit once as `KIND_HIT`). Bodies are solid, so a dash stops at the first enemy unless `pass_through` is active.
- `zone`: ground circle or line (a line runs across the cast direction) that ticks damage and an optional status chance for `duration`; placed at the aim point clamped to `max_range`; first tick at placement. `ZoneManager` (one per world, `ZoneManager.for_world`) owns the live zones; `data/zones.json` `max_live` caps them (the oldest ends first) and `look` holds the visuals. A zone ends with its caster. Ticks are `KIND_DOT`.
- `pass_through`: `duration`. Overlapping grants end with the last. A static flag clears enemy masks so enemies spawned mid-buff are included; it resets on end, death and `_exit_tree`.

### Statuses ([src/combat/StatusEffectManager.gd](../src/combat/StatusEffectManager.gd), `StatusDatabase`)
A `StatusEffectManager` node on every body that can be affected. `StatusDatabase` validates `data/statuses.json` once; a bad entry is treated as missing and `push_error`s. Effect types are closed (`StatusDatabase.EFFECT_TYPES`): `damage_over_time` (Burn, Bleed), `heal_over_time` (Regeneration), `lifesteal` (Leech: a fraction of damage dealt, with a per-hit cap, counted after resistance and skipped at full HP) and `stun`. Visual kinds (`VISUAL_KINDS`): `flame`, `stars`, `drips`, `ring`, `orbs`. Stun has diminishing returns and per-rank multipliers (`StunRules`; elite half, boss immune). Signals: `status_applied/expired/refreshed/resisted`. Burn flames and stun stars come from `EffectPool`; Bleed, Regeneration and Leech cues are held nodes (one, one and two) so they stay inside the pool budget. Burn and Bleed share the HP bar's single pip slot, alternating.

### Attacks (light and heavy)
`data/attacks.json` -> `AttackDatabase` (validated) -> `AttackController` (pure timing: cooldown, auto-fire only with a target, click-rate cap as a ratio, wind-up). `Player._on_attack_fired` runs the same `cone` (or `aoe` for targeted heavies) template cards use, then `AttackStatuses.apply_on_hit` (on-hit statuses, element chance), then `Juice.hit_stop` and shake. The heavy is chosen by the character's class id.

### Enemies and spawner
- `Enemy` ([src/enemies/Enemy.gd](../src/enemies/Enemy.gd)) is one script for all types. `_apply_stats` overrides the scene's exported values with `data/enemies.json` `enemies.<id>.stats`. It chases, telegraphs (ground wedge or shot lane), then attacks through `EffectTemplates` (cone for melee, projectile for ranged). Separation steering uses a static roster and `spawn_index`. Signals: `stunned`, `stun_ended`, `stun_refreshed`.
- Types: `melee_chaser`, `ranged_shooter`, `fire_resistant_golem` (scenes in `scenes/enemies/`, ids and rank in `data/enemies.json`).
- `EnemySpawner` runs a `WavePlan` built from `WaveConfig` (`data/waves.json`): staged groups, a delay per stage, a `max_alive` cap, ring spawn positions, spawn attack grace. A table with `finite: true` ends after its last stage (endless ones loop), and `EnemySpawner.room_cleared()` is true when a finite plan is done and nothing is alive. A queued spawn is the enemy id, or `"<tier>|<enemy id>"` for an elite or boss (`WavePlan.TIER_SEPARATOR`), which keeps the shuffle's random calls identical to the plain-id case. Signal `enemy_spawned(enemy, alive)`. `set_seed` seeds spawn choices.
- `EnemyConfig` validates `data/enemies.json` (call `validate_stats`; `Enemy` reads via `stats_for`, `rank_for`, `scene_path_for`).

### Effects and VFX
`EffectPool` (one per world, found with `EffectPool.for_world`) animates simple primitive effects (disc, wedge, sphere burst) with a cap from `data/vfx.json` `max_simultaneous`; at the cap the oldest is recycled. `TemplateVfx` draws each template's visual; `VfxSizing` derives visual size from the hit numbers so visuals equal hitboxes. `ElementVisuals` maps a damage type to color/scale from `data/pools.json` `visual`; a team tint (`data/vfx.json` `team_tints`) makes enemy shots pink.

### HUD and UI
- `Hud` polls the player each frame (no signals): five `CardSlotWidget`s, a health bar with "HP x / y", `AttackMeter`s for light and heavy. Layout comes from `data/ui.json` `hud` through `HudLayout`/`TextFit`.
- `EnemyHpBar` is a billboard per enemy using `assets/shaders/enemy_hp_bar.gdshader`; visibility mode is `data/ui.json` `hp_bars.visibility_mode`.
- `GameOverScreen` (listens to `Main.game_over_ready`; shows the run line in run mode), the run UI (see Run flow), `SettingsScreen` (Esc; one setting; calls `GamePause`), `DebugOverlay` (F3), `AimIndicator`.
- All UI numbers, colors and strings go through `UiConfig` (`data/ui.json`), which validates the `hp_bars`, `death_beat`, `aim`, `popups` and `damage_numbers` blocks on load (others are read as is: unverified).

## 5. Data flow: card key to applied effect

1. Input event (`slot_N`) reaches `Player._unhandled_input` (only if no UI screen consumed it).
2. `CastInput.press/release` decides, from `Settings.casts_on_release()`, whether this event is a cast; the slot index is queued (`_cast_queue`).
3. Next physics tick: `Player._handle_card_slot_input` -> `CardSlotController.try_use(slot_type)`.
4. `CardSlot.use_card` checks the slot is ready, discards the card, starts the cooldown (with `StatModifiers`), and draws the next card. Returns "" if cooling, which stops the cast.
5. `CardSlotController._cast_card` builds an `EffectContext` and, for each entry in the card's `effects` array, calls `EffectTemplates.execute(template, params, context)`.
6. Template runs: cone/aoe query hurtboxes and call `Hurtbox.receive_damage`; projectile spawns `Projectile.tscn` (damage lands later); dash calls `Player.start_forced_move`; heal/buff touch `Health`/`StatModifiers`; apply_status calls `StatusEffectManager.apply_status` on `context.last_hits`.
7. `Health.take_damage` -> resistance -> `damaged`/`died` signals -> owner calls `Juice.on_hit_landed`.
8. `CardSlotController.card_cast` is emitted; the HUD shows the new cooling state next frame.

Light and heavy attacks skip steps 2-5 but share steps 6-7.

## 6. Data files

All in `data/`. Schema/validation lives in code; the file is not self-describing.

| File | Content | Schema/loader |
|---|---|---|
| `cards/*.json` | One card per file: `id`, `name`, `slot_type`, `pool`, `cooldown_modifier`, `flavor_text`, `effects[]` of `{template, params}` | `src/cards/CardSchema.gd`, loaded by `CardDatabase.load_all` |
| `slot_types.json` | Five slot types: display name, `base_cooldown`, `input_action` | `SlotTypeDatabase` |
| `pools.json` | Classes, elements, neutral: `kind` (class / element / neutral), `visual {color, scale}`, element `status {status_id, base_chance}` | `PoolDatabase` |
| `statuses.json` | burn, bleed, regeneration, leech, stun | `StatusDatabase` |
| `deck_rules.json` | Unique-card minimums (`min_unique_per_slot`, `slots`, `slot_groups`) | `DeckRules` |
| `zones.json` | `max_live` and the zone `look` | `ZoneConfig` |
| `player.json` | `dodge {speed, duration, cooldown, block_ticks_after_pause}`, `body {collide_with_enemies}` | `PlayerConfig` |
| `attacks.json` | `light`, and `heavy` keyed by class id | `AttackDatabase` |
| `enemies.json` | `attack_shapes`, `separation`, `enemies.<id> {rank, scene, stats}` | `EnemyConfig` |
| `waves.json` | `max_alive`, delays, spawn distances, `stages[]`; optional `finite`, and per spawn an optional `tier` (`elite`/`boss`) | `WaveConfig`, `WavePlan` |
| `run.json` | Run structure: `composition`, `placement`, `rest_heal_fraction`, `rejects_per_run`, `starting_deck`, `tiers` (elite, boss), `rooms` (finite wave lists per room type, with `min_index`/`max_index`), `ui` words | `RunConfig.validate` |
| `vfx.json` | Effect pool cap, durations, alphas, `team_tints` | `VfxConfig` |
| `ui.json` | HUD, HP bars, damage numbers, popups, game over, settings screen, death beat, aim, `run_ui` | `UiConfig` |
| `cast_preview.json` | Preview look | `CastPreviewConfig` |
| `settings.json` | User-facing settings and defaults (`cast_trigger`) | `SettingsStore` |
| `input_bindings.json` | Action name to key/mouse events | `InputBindings` |
| `scenarios.json` | Capture/test scenarios | `src/debug/ScenarioSchema.gd`, `Scenario` |

Data is validated at first use and fails loudly (`push_error`) on bad content; several tests load the real files, so a typo shows up in the suite.

## 7. Signals worth knowing

- `Player.player_died` -> `Main._on_player_died`.
- `Main.game_over_ready` -> `GameOverScreen`. `GameOverScreen` emits `retry_requested` and then calls `Main.restart_arena()` itself (no signal connection).
- `RunController.room_started(index, total, room_type)` -> `RunHud`; `room_cleared(summary)` -> the cleared `RunPromptScreen`; `run_won` -> the win screen; `run_lost`. `RunPromptScreen.confirmed` (its action button).
- `Health.damaged / healed / health_changed / died`.
- `CardSlotController.card_cast(slot_type, card_id)`.
- `Main.run_start_blocked(message)`; `Player.pass_through_changed`; `damage_dealt` (source -> `StatusEffectManager.on_damage_dealt`, `PlayerCues`); `ZoneManager.zone_started / zone_ended`.
- `Player.attack_started / attack_fired / attack_ready / attack_cancelled` (from `AttackController`).
- `StatusEffectManager.status_applied / expired / refreshed / resisted`; `Enemy.stunned / stun_ended / stun_refreshed`.
- `EnemySpawner.enemy_spawned(enemy, alive)`.
- `GamePause.paused_changed(is_paused)` -> `Player` cancels held casts and blocks dodge for a moment. `Settings.changed(key, value)`.
- `SettingsScreen.opened / closed`.

## 8. How to add things

### A card
1. Add `data/cards/<pool>_<name>.json` with the fields above. `slot_type` must be in `slot_types.json`, `pool` in `pools.json`, each effect `template` in `EffectTemplates.REQUIRED_PARAMS` with all its required params.
2. Names over `ui.json` `hud.name_warn_length` raise a warning (HUD shrinks/truncates).
3. Attack cards must beat the free light attack (`CardDamageRule`); a load check and a test fail if not.
4. Run the tests (`card_database_test`, `starter_card_set_test`, `card_schema_test` load real data). A card also changes unique counts: the deck rules (`deck_rules.json`) must still pass (`DeckRules.validate_shipped_content`).
5. A card is only reachable if its pool is in `Player.owned_pools`.

### An enemy
1. Duplicate a scene in `scenes/enemies/` (root script `Enemy`), set `enemy_id`, mesh, `Hurtbox` team "enemy", resistances on `Health`.
2. Add `enemies.<id>` in `data/enemies.json` with `rank` (normal/elite/boss), `scene`, and the full `stats` block (`EnemyConfig.validate_stats` lists required keys).
3. Reference the id in `data/waves.json` stages.

### A status
Add an entry in `data/statuses.json` using an existing `effect_type` (`damage_over_time` or `stun`) and a visual `kind` (`flame` or `stars`). Visual kinds are `flame`, `stars`, `drips`, `ring`, `orbs`. A new effect type or visual kind needs code in `StatusDatabase` (`EFFECT_TYPES`, `VISUAL_KINDS`), `StatusEffectManager` and the cue drawing. Apply it from a card with `apply_status`, or from an element via `pools.json` `status`.

### An effect template
(For a new option on an existing template, extend `EffectTemplates.validate_params` and its header comment instead.) Add the id and required params to `EffectTemplates.REQUIRED_PARAMS`, add a case in `execute` and an `_execute_<name>`, add its VFX in `TemplateVfx` (sized through `VfxSizing`), add a preview shape if it has a hit area (`CastPreviewShapes`, `CastPreview`), and cover it in `tests/unit/effect_templates_test.gd`.

### An element
Add a pool in `data/pools.json` with `kind: "element"`, a `visual` (color, scale) and optionally a `status`. Cards use the element id as `damage_type`. No code is needed for the look (`ElementVisuals`); a test proves a Water entry works.

### A slot type
`SLOT_TYPE_ORDER` in `CardSlotController` and `USE_ACTIONS`/`SWAP_ACTIONS` in `Player` are hardcoded to five. A new slot type needs code plus HUD and input binding changes, not just data.

### A room wave list or room type
Add a variant under `data/run.json` `rooms.<type>` with `id`, optional `min_index`/`max_index`, `first_wave_delay` and `stages`. `RunConfig.validate` checks enemy ids and that every room index has a variant; the run tests load the real file. A new room *type* also needs `composition`, `RunController` handling, an icon in `RunIcons` and a `run_ui` colour.

### A scenario
Add an entry in `data/scenarios.json`; unknown or misspelled keys fail on load (`ScenarioSchema`). Add a test in `tests/unit/` if it proves behavior. Document the new scenario in `README.md`.

## 9. Tests and tools

- **Tests:** gdUnit4 suites in `tests/unit/*_test.gd`. Names with `slice*_qa_test`, `*_recheck_test` are qa regression tests; qa sometimes adds a test that is red on purpose until the fix lands. Tests wait real time with `TestClock.wait_real`, never `create_timer(t, true, false, true)` (Godot overcounts the frame where `Engine.time_scale` changes, which made hit-stop tests flaky), and force `body.collide_with_enemies` with `BodyFlag` when they pin non-solid geometry. The log's `ERROR:` lines come from bad-data fixtures, so the exit code is the gate. `tests/fixtures/` holds bad-data samples for schema tests. Run all: `powershell -File tools\run_tests.ps1`. See `README.md`.
- **Sending input in tests:** use `TestInput.press/release/tap` (`tests/support/test_input.gd`). `Input.action_press` emits no event, so `_unhandled_input` never sees it.
- **Tools** (all in `tools/`, commands and verification in `README.md`):
  - `run_tests.ps1` -> gdUnit4 headless.
  - `capture_screenshot.ps1` -> windowed capture, uses `src/debug/*` via user args.
  - `run_bot_sim.ps1 [-Rooms] [-Seed]` + `bot_sim.gd` -> card/deck NaN check, runs as a `SceneTree` script; prints a checksum that repeats per seed.
  - `run_wave_sim.ps1` + `WaveSim.tscn` + `wave_sim.gd` -> real Main scene with a bot. `-Run` plays whole seeded runs through RunMain (`-Seed` first seed, `-Runs` count, `-RoomTimeout`): checks soft locks, empty decks, stuck cooldowns and card pick rates, and prints the room-type distribution over 1000 seeds. A scene, so autoloads exist. Runs at `--fixed-fps 60` with hit-stop off, so a seed repeats exactly; prints `pinned:` and `climb:` lines.
  - `run_reload_cycle.ps1` + `ReloadCycle.tscn` + `reload_cycle.gd` -> death/restart soak.
  - `VpCapture.tscn` + `vp_capture.gd` (`capture_screenshot.ps1 -TrueSize WxH`) -> hosts the real Main in an oversized SubViewport (RunMain with `--run`, which `capture_screenshot.ps1` adds for `-Scenario ""`); Main registers with `WorldRef` so spawners, popups and effects find the arena when `current_scene` is null. Scene swaps work there too (`swap_to_fresh_scene`).
  - `SlotStateCapture.tscn` + `slot_state_capture.gd` -> HUD slot capture.
- **Windows binary:** the scripts prefer the `*_console.exe` Godot build. The windowed build can make PowerShell report a failing run as success.

## 10. Known sharp edges

- **Projectiles leave `last_hits` empty** (damage lands later). An `apply_status` after a `projectile` in the same card hits nothing.
- **Seeded sims repeat exactly** only at `--fixed-fps 60` with hit-stop off (what `run_wave_sim.ps1` does at `-Scale 1`), on one machine and build. A new RNG or wall-clock read in gameplay breaks this; seed it through `Player.default_rng_seed` or the shared RNG, and `seeded_sim_repeat_test` will fail.
- **Only `GamePause` should set `paused`.** The pause screen and cast preview run `PROCESS_MODE_ALWAYS`. The pause also freezes `Juice` time scale and hands the remaining hit-stop/slow-mo back on resume.
- **Autoload state survives a scene reload** (`Engine.time_scale`, `Juice`, `GamePause`). `Main._prepare_for_restart` resets them; anything new that is global must be reset there too. Re-run the reload soak after touching `Main`, `Juice`, `Player` or the autoloads.
- **Dodge distance is data** (`data/player.json`, speed x duration). The `Player.gd` and `PlayerConfig.gd` fallbacks must match it; they are used only if the file is missing or bad. Dash cards use their own `distance` and `speed`.
- **Solid enemies change difficulty and tests.** `body.collide_with_enemies` roughly doubled HP lost in the sim. A crowd can pin the player (the wave sim's `pinned:` line watches it). Lunge stops at the first body. Keep `WorldRef` in mind: use `WorldRef.get_world(tree)`, not `current_scene`, for anything that spawns into the arena.
- **Pass-through leaves a timer alive** for about one object per reload until it expires (qa N2).
- **The Lunge preview** shows the full path even when a body will stop the dash short (known gap).
- **Hit-stop only on `KIND_HIT`.** A new damage source that should feel heavy must pass `Health.KIND_HIT`; DoT and zone ticks use `KIND_DOT`.
- **New `class_name` scripts** aren't picked up by a plain headless test run: run `godot --headless --editor --quit --path .` once.
- **Sims must run as scenes** (not `SceneTree` scripts) or autoloads won't exist.
- **Ctrl+N** is a swap, not a cast. Slot keys use `exact_match` on press so Ctrl+1 doesn't also press 1.
- **Don't add per-frame allocation** in hot paths (`Player._physics_process`, `Enemy`, HUD): earlier reviews removed several. Use the `EffectPool`, not new nodes, for transient visuals. The held `CastPreview` is deliberately not pooled.
- **Enemy stats live in data.** The exported fields on `Enemy` scenes are only fallbacks (see `Enemy._apply_stats`).
- **Enemy HP bars:** `elite` and `boss` ranks always show their bar; the endless-arena `data/waves.json` has none; the shipped run rooms have one elite and a placeholder boss.
- **Run state is a static.** `RunSession.current` survives scene swaps on purpose, so tests and tools that start a run must call `RunSession.clear()`. A new per-room reset belongs in the fresh scene; something that must carry over belongs in `RunState` (and its `to_dict`/`from_dict`). `Health.damage_immune` is set at room clear and must not leak into the next room (the reload soak checks it).
- **Seeded baselines use the endless arena.** The wave_sim seed hashes depend on `Main.tscn`. The `tier|enemy` encoding in `WavePlan` is built to leave them unchanged.
- **`TrainingDummy`** (`scenes/debug/`) is not in `Main.tscn`; some tests instantiate it.
- **Name rows:** card names use `fit_padding` 12 and line spacing 0 so two-line names fit; a test pins every card name at 720p, 1080p and 1440p.
- **One shader lives in `src/player/`** (`player_occlusion_cue.gdshader`), the other in `assets/shaders/`.
