# Architecture

A map of the code for a new agent. Read this first, then open the files it links. Every path below exists; line-level detail is left to the code. Numbers that change (balance, timings) live in `data/`, not here. Engine: Godot 4.7.2, statically typed GDScript. Last verified against HEAD 8bc7241 (2026-10-29, after Milestone 3c).

## 1. Repo layout

| Path | What lives there |
|---|---|
| `project.godot` | Main scene `scenes/main/RunMain.tscn`, four autoloads, physics layer names, gdUnit4 plugin enabled |
| `src/camera/` | `CameraRig` (follow + shake) |
| `src/cards/` | Card data and slots: `CardDatabase`, `CardSchema`, `CardSlot`, `CardSlotController`, held-key cast: `CastInput`, `CastPreview`, `CastPreviewShapes`, `CastPreviewConfig`; deck rules: `DeckRules`, `DeckCheck`; `CardSummary` (the generic effect line for the reward screens) |
| `src/combat/` | Damage and effects: `Health`, `Hurtbox`, `EffectTemplates`, `EffectContext`, `Projectile`, `MeleeQuery`, `CombatMath`, status system (`StatusDatabase`, `StatusEffectManager`, `StunRules`), attack data (`AttackDatabase`, `AttackStatuses`), `CardDamageRule`, `AoeTargeting`, `CollisionLayers`, zones (`ZoneManager`, `ZoneShape`, `ZoneConfig`), `TrainingDummy` (debug only) |
| `src/core/` | Autoloads and shared data access: `InputBindings`, `Juice`, `Settings`, `GamePause`; `SettingsStore`, `JsonDataTable`, `PoolDatabase`, `SlotTypeDatabase`, `StatModifiers`, `WorldRef` |
| `src/debug/` | Capture and scenario tooling: `CaptureArgs`, `Scenario`, `ScenarioSchema`, `ScreenshotCapture` |
| `src/effects/` | Visual effects: `EffectPool`, `PooledEffect`, `TemplateVfx`, `ElementVisuals`, `VfxConfig`, `VfxSizing`, `DamageNumber`, `GroundOutlines` (ground ring/outline builders shared by the preview and zones) |
| `src/enemies/` | `Enemy`, `EnemySpawner`, `WaveConfig`, `WavePlan`, `EnemyConfig`; the boss (3c): `Boss`, `BossConfig`, `BossRules` |
| `src/main/` | `Main` (wiring, death beat, restart), `SceneSelfCheck` |
| `src/run/` | Run structure (3a, 3b): `RunConfig` (loads and validates `data/run.json`), `RunGenerator` (seed to room list), `RunState` (what carries across rooms, save format v2), `RunSession` (static holder), `RunController` (one room's flow), `TierRules` (elite/boss maths), `RunChoices` (the post-room choice model: options and resolving one), `RewardOffer` (seeded card offer and the `requires` filter) |
| `src/player/` | `Player`, `PlayerConfig` (`data/player.json`), `AttackController`, `AttackArcVisual`, `PlayerCues` (ghost, heal numbers, Leech drain), `PlayerOcclusionCue` (+ its `.gdshader`) |
| `src/ui/` | `Hud`, `HudLayout`, `CardSlotWidget`, `AttackMeter`, `EnemyHpBar`, `GameOverScreen`, `SettingsScreen`, run UI: `RunHud`, `RunPromptScreen`, `RunOptionCard` (one choice option drawn as a card, reject tile, action tile, grid cell or Back), `RunPromptRows`, `RunIcons`, `RunTypeIcon`, `TierMarker`, boss UI (3c): `BossHpBar`, `BossMeter`, `BossAttackStrip`, `AimIndicator`, `DebugOverlay`, `TextFit`, `UiConfig` |
| `scenes/` | `main/RunMain.tscn` (Main plus run nodes), `main/Main.tscn` (endless arena), `player/`, `camera/`, `enemies/` (3 types plus `BossGuardian.tscn`), `effects/` (Projectile, DamageNumber), `ui/`, `debug/TrainingDummy.tscn` |
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

`Main.tscn` children: `WorldEnvironment`, `Sun`, `Floor` (CSG box), `ArenaWalls` (invisible static walls), `Player`, `CameraRig`, `EnemySpawner`, `Hud`, `BossHpBar` (a `scenes/ui/BossHpBar.tscn` instance), `GameOverScreen`, `SettingsScreen`, `DebugOverlay`.

`Main._ready` ([src/main/Main.gd](../src/main/Main.gd)):
1. Hands the player to the camera rig, the spawner, the HUD and the debug overlay; gives the player the camera for aiming.
2. Attaches `AimIndicator`, `PlayerOcclusionCue` and `PlayerCues` to the player; registers itself with `WorldRef` (`_enter_tree`).
3. `_setup_run_mode`: if `uses_run_mode(run_mode, user args)` (pure static: `run_mode` is true and there is no `--scenario` arg) and `data/run.json` is valid, calls `RunController.begin(self)`. Otherwise it removes the run nodes (`RunController`, `RunHud`, `RoomClearedScreen`, `WinScreen`) so the scene is the endless arena. An invalid `run.json` logs an error and falls back to the arena.
4. `_check_starting_deck`, then `SceneSelfCheck.find_problems` (`push_error`s if the world would render empty).
5. If user args follow `--`, sets up scenario and screenshot capture (`Main._setup_debug_capture`).

Deck check: `Main` checks the deck rules (`DeckRules.run_start_block_message`). A short deck is blocked: `push_error`, the spawner is switched off, and `Main.run_start_blocked(message)` is emitted. The shipped deck passes.

### Run flow (Milestone 3a)
- **Config:** `data/run.json` (section 6) is loaded and validated by `RunConfig`. `RunGenerator.generate(seed, config)` returns the room list (each entry has `index`, `type`, `wave_id`) from a seeded shuffle that follows `composition` and `placement` (boss last, first room combat, elite and rest inside index ranges). The same seed gives the same rooms.
- **State:** `RunState` holds seed, room index, HP and max HP, deck ids, rejects left, history, outcome, and (3b) `pending`, `offer` and `choice_log`. It serializes with `to_json`/`from_json` (`FORMAT_VERSION` 2; a v1 dict loads with no pending choice). `RunSession.current` (a static, not an autoload) keeps it between scenes; `RunSession.begin_new_run` is the only way to start a fresh one (it consumes `forced_seed` once). `RunSession.full_deck` (`--full-deck`) makes new runs start with every card of `character_pools` instead of `starting_deck`, and stays on for the launch.
- **A room:** `RunController.begin` puts the state's HP and deck on the player, builds the room's finite wave table (`RunConfig.room_wave_config`), configures the spawner with it and a seed from `room_spawn_seed(run_seed, room_index)`, and emits `room_started`. `_process` watches `EnemySpawner.room_cleared()`. A rest room is finished at once (spawner off). `_finish_room` sets `Health.damage_immune` on the player (so a projectile in flight can't kill a winner), records history, and on the last room emits `run_won`. Otherwise it calls `RunChoices.open_for_room`; if that opens a choice it emits `choice_requested(model)`, else `room_cleared` (the plain Continue panel; with the shipped data every non-final room opens a choice).
- **Choices (3b):** after a won combat or elite room `RunChoices` opens a card reward (3 offers from `RewardOffer`, or reject all); a rest room opens the rest menu (heal, or a per-card removal list with Back). `RunController.choose(option_id)` resolves one option through `RunChoices.apply`, heals the player for a heal option, emits `choice_resolved(result)` and, when the choice is finished, goes to the next room at once. A non-final step (open the removal list, Back) re-emits `choice_requested`. `RunState.pending` and `offer` persist the open choice, so a reload resumes it (`RunController._resume_choice`) instead of replaying the room. Details in the choice model section below.
- **Next room:** `RunController.continue_to_next_room(force := false)` bumps the index and calls `Main.swap_to_fresh_scene`. It does nothing while a choice is open; `force = true` discards the choice and is for tests and the reload soak only (a qa test scans `src` and `tools` for other callers). A fresh scene resets cooldowns, shuffle bags, zones, statuses and timers; the `RunState` carries HP and the deck.
- **Death:** `Player.player_died` goes through the normal death beat to Game Over, which shows "Reached room X of Y". Try again and New run both call `Main.restart_arena`, which in run mode does `RunSession.begin_new_run()` (new seed) and swaps the scene.
- **Launch args** (`RunController._apply_launch_args`, first scene of a launch only): `--run-seed=N`, `--run-room=K` (1-based), `--run-clear-after=S` (debug: clears that room after S seconds), `--full-deck` (debug). `RunPromptScreen` also reads `--run-auto-choose=<option ids>` (debug: picks those option ids in turn as choices open, skipping the arm delay).
- **Tiers:** a wave spawn can carry `tier` (`elite` or `boss`). `EnemySpawner` calls `Enemy.apply_tier(tier_id, cfg)` with the `data/run.json` `tiers` entry: HP multiplier, resistance via `TierRules.resistance` (the larger of own and the floor, capped), rank, and a `TierMarker`. The shipped boss no longer uses the `boss` tier: `boss_guardian` has its own HP and rules in `data/bosses.json` (see the Boss section), so `tiers.boss` is unused (qa logged removing it for 3d). `TierRules` still handles the elite.
- **UI:** `RunHud` shows "Room X of Y - Type" with a `RunTypeIcon` (shapes from `RunIcons`: circle combat, diamond elite, plus rest, star boss; placed by `HudLayout.room_indicator_rect`, top right since 3c). `RunController.boss_spawned(boss)` and `current_boss()` expose the room's boss. `RunPromptScreen` is a generic panel (icon, title, subtitle, flavour line, label/value rows, `options_box`, one action button). `show_content(dict)` fills it; the text rows come from `RunPromptRows`. 3b rewards use it through `show_choice(model)` (see the choice model section). `TierMarker` is the flat diamond/star sign above an elite's or boss's HP bar (shape, not colour, and no bigger body). Look and sizes: `data/ui.json` `run_ui`; words: `data/run.json` `ui`.

### Choice model (Milestone 3b)
- `RunChoices` ([src/run/RunChoices.gd](../src/run/RunChoices.gd)): pure and static over a `RunState` and a context dict (`RunChoices.shipped_context(pools)` builds it from the databases; tests pass fixtures). Functions: `open_for_room(state, room_type, is_last_room, ctx)` (sets `pending`/`offer`), `model`, `options`, `apply(state, option_id, ctx)`, `removal_problems` (wraps `DeckRules.can_remove`). It never reads card ids or names; the one place that looks inside a card is `CardSummary`.
- **Option dict** (every key always present): `id` ("card:<id>", "skip", "heal", "remove_menu", "remove:<id>", "back"), `kind` (card, remove, heal, skip, back), `label`, `detail`, `flavor`, `card_id`, `slot_type`, `slot_name`, `count`, `enabled`, `reason`, `costs_reject`, `opens_list`, `amount`.
- **Model dict** (`RunChoices.model`): `choice` (reward, rest or rest_remove), `title`, `line`, `options`, `rejects_remaining`, `rejects_max`. `RunController.current_choice()` adds `room_label`, `room_type`, `room_type_name` and `next_line`.
- `apply` returns `{ok, kind, card_id, amount, finished, reason}`. A disabled or unknown option changes nothing and returns `ok = false`. Picks and removals change `RunState.deck`; every resolved option is appended to `choice_log` (`pick`, `reject`, `heal`, `remove`).
- `RewardOffer.generate(run_seed, room_index, deck, cards, pools, pool_defs, rewards)`: own RNG stream from `offer_seed`, candidates sorted by id, weights from `rewards.unowned_weight` / `owned_weight`, distinct, up to `offer_size`. Card field `requires` (`slot_types`, `pools`, `status_sources`) is checked by `meets_requires` and validated in `CardSchema` (`RewardOffer.validate_requires`).
- `CardSummary.effect_line(card, slot_base_cooldown, text)` builds a line like "12.0 fire damage (aoe), Burn 5.0 s. Cooldown 3.3 s" from effect templates and params. Buff wording comes from `run.json` `ui.effect` plus the slot names.
- **Screen:** `RunPromptScreen.show_choice(model)` builds one `RunOptionCard` per option into `options_box`. `layout_for` picks `row` (reward cards), `actions` (rest tiles) or `grid` (removal list, one column per slot); `look_for` maps kind to card look. Keys 1-N move the highlight (in the grid, 1-5 jump to a slot column) and never confirm; Enter or a click confirms (`option_chosen`, then `RunController.choose`). Options are armed `run_ui.prompt_option_arm_delay` seconds after opening (`options_armed()`, `disarm()`), Space is swallowed, input is ignored while paused, and focus is restored after a pause. Sizes and colours: `data/ui.json` `run_ui` keys starting `option_`. **Fit:** `_fit_panel` shrinks the whole panel to the window; an offer never scrolls (floor `offer_min_fit_scale`), only the removal grid scrolls (floor `option_min_fit_scale`). A `CenterContainer` resets its child's scale on every sort, so the scale is kept in `_fit_scale` and re-applied on the container's `sort_children` signal (`_apply_fit_scale`); the panel sits under the HUD band (`_avail_height`). Locked-removal and "Slot N now: A / B / C" words come from `run.json` `ui.rest.remove_locked` and `ui.option.slot_now`; the effect-line wording from `ui.effect`.

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
- `Health.take_damage(amount, type, knockback)` applies the resistance fraction (`CombatMath.apply_resistance`, capped), lowers HP (never below `Health.hp_floor`, default 0; the boss raises it to its next phase threshold so one hit cannot skip a phase) (ignored while `Health.damage_immune` is true; the run sets it on a won room), emits `damaged`, `health_changed`, and `died` once.
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
- `projectile`: `yaw_degrees` (turn the shot about the vertical axis, a fan). `aoe`: `vfx` (false skips the impact visual; the boss draws its own).
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
- Types: `melee_chaser`, `ranged_shooter`, `fire_resistant_golem`, and the boss `boss_guardian` (scenes in `scenes/enemies/`, ids and rank in `data/enemies.json`; the boss is its own section).
- `EnemySpawner` runs a `WavePlan` built from `WaveConfig` (`data/waves.json`): staged groups, a delay per stage, a `max_alive` cap, ring spawn positions, spawn attack grace. A table with `finite: true` ends after its last stage (endless ones loop), and `EnemySpawner.room_cleared()` is true when a finite plan is done and nothing is alive. A queued spawn is the enemy id, or `"<tier>|<enemy id>"` for an elite or boss (`WavePlan.TIER_SEPARATOR`), which keeps the shuffle's random calls identical to the plain-id case. Signal `enemy_spawned(enemy, alive)`. `set_seed` seeds spawn choices.
- `EnemyConfig` validates `data/enemies.json` (call `validate_stats`; `Enemy` reads via `stats_for`, `rank_for`, `scene_path_for`).

### The boss (Milestone 3c)
- **Data:** `data/bosses.json` -> `BossConfig` ([src/enemies/BossConfig.gd](../src/enemies/BossConfig.gd), validator; a bad file is a `push_error` and no boss exists). `rules` (minimum telegraph, maximum transition, adds cap, minimum attacks), then per boss id (a key of `data/enemies.json` with rank `boss`): name, HP, `resistance` (applied to every element), `knockback_taken`, `transition`, `death`, `attacks` and `phases` (HP threshold `enters_at`, speed, attack gap, wind-up scale, optional `summon`, weighted attack list). Numbers live there, not here.
- **Rules:** `BossRules` ([src/enemies/BossRules.gd](../src/enemies/BossRules.gd)) is pure: which phase an HP fraction is in, attack picking, telegraph sizes (from `VfxSizing`, the same numbers the hit queries use) and `escape`, the fairness check (`escape`) that an attack can be walked or dodged out of; only a test applies it. `tests/unit/m3c_boss_test.gd` covers it.
- **Brain:** `Boss` ([src/enemies/Boss.gd](../src/enemies/Boss.gd), extends `Enemy`, group `boss`; scene `scenes/enemies/BossGuardian.tscn`) is a state machine: chase, wind-up (telegraph), active, recover, transition, dead. Attacks go through `EffectTemplates` (cone, aoe, projectile with `yaw_degrees`); telegraphs are drawn at the vs-player reach. Not solid while charging (and solid again only once clear of the player), unstunnable, takes no knockback. Phase thresholds are held by `Health.hp_floor`; each crossing runs an invulnerable roar, then `phase_changed`. Adds (`summon`) are capped and killed on its death. The death beat (slow-mo, then the win) counts game time when hit-stop is off.
- **Signals:** `phase_changed`, `transition_started/ended`, `attack_telegraphed(id, label, windup)`, `attack_landed`, `adds_summoned`, `defeated`. `RunController.boss_spawned(boss)` fires when it spawns; `current_boss()` returns the living boss or null.
- **Spawning:** the boss room in `data/run.json` spawns `boss_guardian` like any enemy; it has no tier.
- **UI:** `BossHpBar` (a `CanvasLayer` in `Main.tscn`) finds the boss by class on `node_added`, so it also works in the capture scenarios, and reads the boss's live state on bind (a reload mid-fight starts correct). It draws a `BossMeter` (fill, ghost, threshold notches and lines, invulnerable stripes, resist frame) and a `BossAttackStrip` (attack label and draining wind-up strip). Placement: `HudLayout.boss_bar_rect` (top centre); `HudLayout.debug_overlay_top` puts the F3 overlay below it; the room indicator is top right. Look and sizes: `data/ui.json` `hud.boss_bar_size`, `hud.debug_overlay_gap`, the `boss_bar` block; boss lane alpha: `data/vfx.json` `boss_lane_alpha`.

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
| `cards/*.json` | One card per file: `id`, `name`, `slot_type`, `pool`, `cooldown_modifier`, `flavor_text`, `effects[]` of `{template, params}`, optional `requires` (reward filter: `slot_types`, `pools`, `status_sources`) | `src/cards/CardSchema.gd`, loaded by `CardDatabase.load_all` |
| `slot_types.json` | Five slot types: display name, `base_cooldown`, `input_action` | `SlotTypeDatabase` |
| `pools.json` | Classes, elements, neutral: `kind` (class / element / neutral), `visual {color, scale}`, element `status {status_id, base_chance}` | `PoolDatabase` |
| `statuses.json` | burn, bleed, regeneration, leech, stun | `StatusDatabase` |
| `deck_rules.json` | Unique-card minimums (`min_unique_per_slot`, `slots`, `slot_groups`) | `DeckRules` |
| `zones.json` | `max_live` and the zone `look` | `ZoneConfig` |
| `player.json` | `dodge {speed, duration, cooldown, block_ticks_after_pause}`, `body {collide_with_enemies}` | `PlayerConfig` |
| `attacks.json` | `light`, and `heavy` keyed by class id | `AttackDatabase` |
| `enemies.json` | `attack_shapes`, `separation`, `enemies.<id> {rank, scene, stats}` | `EnemyConfig` |
| `bosses.json` | Boss fight: `rules`, per-boss name, HP, resistance, `attacks`, `phases` (section 4, The boss) | `BossConfig`, `BossRules` |
| `waves.json` | `max_alive`, delays, spawn distances, `stages[]`; optional `finite`, and per spawn an optional `tier` (`elite`/`boss`) | `WaveConfig`, `WavePlan` |
| `run.json` | Run structure: `composition`, `placement`, `rest_heal_fraction`, `rejects_per_run`, `starting_deck` (15 cards), `character_pools`, `rewards {offer_size, unowned_weight, owned_weight, reward_room_types}`, `tiers` (elite, boss; `boss` is unused since 3c), `rooms` (finite wave lists per room type, with `min_index`/`max_index`), `ui` words (`option` incl. `slot_now`, `effect`, `reward`, `rest` incl. `remove_locked`, `next_line`, `room_cleared`, `win`, `lose`) | `RunConfig.validate` |
| `vfx.json` | Effect pool cap, durations, alphas (incl. `boss_lane_alpha`), `team_tints` | `VfxConfig` |
| `ui.json` | HUD, HP bars, damage numbers, popups, game over, settings screen, death beat, aim, `hud` (3c adds `boss_bar_size`, `debug_overlay_gap`; `room_indicator_size` is older), `boss_bar` (3c), `run_ui` (3b adds `prompt_option_arm_delay` and the `option_*` sizes and colours; the fix pass adds `offer_min_fit_scale`) | `UiConfig` |
| `cast_preview.json` | Preview look | `CastPreviewConfig` |
| `settings.json` | User-facing settings and defaults (`cast_trigger`) | `SettingsStore` |
| `input_bindings.json` | Action name to key/mouse events | `InputBindings` |
| `scenarios.json` | Capture/test scenarios | `src/debug/ScenarioSchema.gd`, `Scenario` |

Data is validated at first use and fails loudly (`push_error`) on bad content; several tests load the real files, so a typo shows up in the suite.

## 7. Signals worth knowing

- `Player.player_died` -> `Main._on_player_died`.
- `Main.game_over_ready` -> `GameOverScreen`. `GameOverScreen` emits `retry_requested` and then calls `Main.restart_arena()` itself (no signal connection).
- `RunController.room_started(index, total, room_type)` -> `RunHud`; `room_cleared(summary)` -> the cleared `RunPromptScreen`; `choice_requested(model)` -> `RunPromptScreen.show_choice`; `choice_resolved(result)` (a choice finished, just before the next room loads); `boss_spawned(boss)` (only a test listens today; `BossHpBar` finds the boss by class instead); the `Boss` signals are listed in section 4; `run_won` -> the win screen; `run_lost`. `RunPromptScreen.confirmed` (its action button) and `option_chosen(option_id)`.
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
4. Run the tests (`card_database_test`, `starter_card_set_test`, `card_schema_test` load real data). A new card is not in the 15-card `starting_deck`; it appears only as a reward unless added there (or via `--full-deck`). A card also changes unique counts: the deck rules (`deck_rules.json`) must still pass (`DeckRules.validate_shipped_content`).
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

### A reward rule or choice
Card reward filtering is data: add `requires` to a card (`slot_types`, `pools`, `status_sources`) and `RewardOffer` applies it. Weights, offer size and which room types reward are `data/run.json` `rewards`. A new kind of option (for example a level-up pick) is a new branch in `RunChoices.options`/`apply` plus an option `kind` and a `RunOptionCard` look; the screen is otherwise generic. Wording lives in `run.json` `ui`.

### A boss attack, phase or boss
Attack: add it under `attacks` in `data/bosses.json` with an existing `kind` (cone, aoe, volley, charge; see the `BossConfig` header) and list it in a phase's weighted `attacks`; `BossConfig.validate` rejects malformed entries (including a telegraph under `rules.min_telegraph`); a test (`m3c_boss_test`, `BossRules.escape`) checks every shipped attack can be walked or dodged out of. A new attack kind needs code in `Boss`, `BossConfig` and `BossRules` (unverified in detail). A phase is one more entry in `phases` (descending `enters_at`). Another boss: add `bosses.<id>` with a matching `enemies.json` entry (rank `boss`) and a scene using the `Boss` script; the bar reads the name and phases from the boss.

### A scenario
Add an entry in `data/scenarios.json`; unknown or misspelled keys fail on load (`ScenarioSchema`). Add a test in `tests/unit/` if it proves behavior. Document the new scenario in `README.md`.

## 9. Tests and tools

- **Tests:** gdUnit4 suites in `tests/unit/*_test.gd`. Names with `slice*_qa_test`, `*_recheck_test` are qa regression tests; qa sometimes adds a test that is red on purpose until the fix lands. Tests wait real time with `TestClock.wait_real`, never `create_timer(t, true, false, true)` (Godot overcounts the frame where `Engine.time_scale` changes, which made hit-stop tests flaky), and force `body.collide_with_enemies` with `BodyFlag` when they pin non-solid geometry. The log's `ERROR:` lines come from bad-data fixtures, so the exit code is the gate. `tests/fixtures/` holds bad-data samples for schema tests. Run all: `powershell -File tools\run_tests.ps1`. See `README.md`.
- **Sending input in tests:** use `TestInput.press/release/tap` (`tests/support/test_input.gd`). `Input.action_press` emits no event, so `_unhandled_input` never sees it.
- **Tools** (all in `tools/`, commands and verification in `README.md`):
  - `run_tests.ps1` -> gdUnit4 headless.
  - `capture_screenshot.ps1` -> windowed capture, uses `src/debug/*` via user args.
  - `run_bot_sim.ps1 [-Rooms] [-Seed]` + `bot_sim.gd` -> card/deck NaN check, runs as a `SceneTree` script; prints a checksum that repeats per seed.
  - `run_wave_sim.ps1` + `WaveSim.tscn` + `wave_sim.gd` -> real Main scene with a bot. `-Run` plays whole seeded runs through RunMain (`-Seed` first seed, `-Runs` count, `-RoomTimeout`): the bot also plays the choices with a seeded policy (rejects, picks, removals); it checks soft locks, empty decks and stuck cooldowns, reports card pick rates as a note (not a failure), prints HP at each room end, final deck composition and the choice counts, and prints the room-type distribution over 1000 seeds. A scene, so autoloads exist. Runs at `--fixed-fps 60` with hit-stop off, so a seed repeats exactly; prints `pinned:` and `climb:` lines.
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
- **Enemy HP bars:** `elite` and `boss` ranks always show their bar; the endless-arena `data/waves.json` has none; the shipped run rooms have one elite and the boss, which always shows `BossHpBar` (top centre) instead.
- **Run state is a static.** `RunSession.current` survives scene swaps on purpose, so tests and tools that start a run must call `RunSession.clear()`. A new per-room reset belongs in the fresh scene; something that must carry over belongs in `RunState` (and its `to_dict`/`from_dict`). `Health.damage_immune` is set at room clear and must not leak into the next room (the reload soak checks it).
- **The starter deck is exactly at the minimum.** `starting_deck` has 3 unique cards per slot, so `DeckRules.can_remove` blocks every starter card until a pick adds a 4th unique or a duplicate in that slot; early rest rooms are heal-only. Editing `starting_deck` must keep `deck_rules.json` satisfied (`RunConfig.deck_problems` checks it). `--full-deck` is the way to reach the removal grid in a capture.
- **A choice is state, not UI.** An open choice lives in `RunState.pending`/`offer`. Anything that frees or reloads the scene mid-choice must leave them alone; only `choose` (or `continue_to_next_room(force = true)` in tests) clears them. `RunState.from_dict` drops an unknown `pending` (logs an error); other field types are not fully validated yet (qa's save-robustness findings, planned for 3d).
- **Offers are seeded by (run seed, room index) and the current deck,** on their own RNG stream, so a change to the deck changes later offers but never touches the spawner or player RNG. Candidates are sorted by id before the draw.
- **Wave-sim pick rates cover all database cards,** so cards the bot never picked show as `NEVER CAST`. That is expected, not a defect.
- **Seeded baselines use the endless arena.** The wave_sim seed hashes depend on `Main.tscn`. The `tier|enemy` encoding in `WavePlan` is built to leave them unchanged.
- **`TrainingDummy`** (`scenes/debug/`) is not in `Main.tscn`; some tests instantiate it.
- **Name rows:** card names use `fit_padding` 12 and line spacing 0 so two-line names fit; a test pins every card name at 720p, 1080p and 1440p.
- **One shader lives in `src/player/`** (`player_occlusion_cue.gdshader`), the other in `assets/shaders/`.
- **Boss fairness is checked by data tests.** Edit `data/bosses.json` and run `m3c_boss_test`: it checks every shipped attack can be escaped by walking or the dodge (a test, not load-time validation; the load only enforces `rules.min_telegraph` and shape).
- **A container resets child scale on sort.** Anything scaled inside a `Container` (the reward panel's fit) must be re-applied on `sort_children`.
