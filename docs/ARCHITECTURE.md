# Architecture

A map of the code for a new agent. Read this first, then open the files it links. Every path below exists; line-level detail is left to the code. Numbers that change (balance, timings) live in `data/`, not here. Engine: Godot 4.7.2, statically typed GDScript. Last verified against HEAD 44c5d73 (2026-10-28).

## 1. Repo layout

| Path | What lives there |
|---|---|
| `project.godot` | Main scene `scenes/main/Main.tscn`, four autoloads, physics layer names, gdUnit4 plugin enabled |
| `src/camera/` | `CameraRig` (follow + shake) |
| `src/cards/` | Card data and slots: `CardDatabase`, `CardSchema`, `CardSlot`, `CardSlotController`, held-key cast: `CastInput`, `CastPreview`, `CastPreviewShapes`, `CastPreviewConfig` |
| `src/combat/` | Damage and effects: `Health`, `Hurtbox`, `EffectTemplates`, `EffectContext`, `Projectile`, `MeleeQuery`, `CombatMath`, status system (`StatusDatabase`, `StatusEffectManager`, `StunRules`), attack data (`AttackDatabase`, `AttackStatuses`), `CardDamageRule`, `AoeTargeting`, `CollisionLayers`, `TrainingDummy` (debug only) |
| `src/core/` | Autoloads and shared data access: `InputBindings`, `Juice`, `Settings`, `GamePause`; `SettingsStore`, `JsonDataTable`, `PoolDatabase`, `SlotTypeDatabase`, `StatModifiers` |
| `src/debug/` | Capture and scenario tooling: `CaptureArgs`, `Scenario`, `ScenarioSchema`, `ScreenshotCapture` |
| `src/effects/` | Visual effects: `EffectPool`, `PooledEffect`, `TemplateVfx`, `ElementVisuals`, `VfxConfig`, `VfxSizing`, `DamageNumber` |
| `src/enemies/` | `Enemy`, `EnemySpawner`, `WaveConfig`, `WavePlan`, `EnemyConfig` |
| `src/main/` | `Main` (wiring, death beat, restart), `SceneSelfCheck` |
| `src/player/` | `Player`, `AttackController`, `AttackArcVisual`, `PlayerOcclusionCue` (+ its `.gdshader`) |
| `src/ui/` | `Hud`, `HudLayout`, `CardSlotWidget`, `AttackMeter`, `EnemyHpBar`, `GameOverScreen`, `SettingsScreen`, `AimIndicator`, `DebugOverlay`, `TextFit`, `UiConfig` |
| `scenes/` | `main/Main.tscn`, `player/`, `camera/`, `enemies/` (3 types), `effects/` (Projectile, DamageNumber), `ui/`, `debug/TrainingDummy.tscn` |
| `data/` | All content and tuning as JSON (section 6) |
| `assets/` | `icon.svg`, `shaders/enemy_hp_bar.gdshader` only. No art or audio |
| `tests/` | gdUnit4 suites in `tests/unit/`, JSON fixtures in `tests/fixtures/`, helper `tests/support/test_input.gd` |
| `tools/` | PowerShell wrappers and headless/capture scripts (section 9) |
| `docs/` | Design, decisions, roadmap, state, reviews, playtests, and the four tech-writer docs |

Rule from `CLAUDE.md`: content is data, not code. A new card, enemy or status should not need a new script unless it brings a brand-new effect type.

## 2. Scene and run flow

`Main.tscn` is the only gameplay scene. Its children: `WorldEnvironment`, `Sun`, `Floor` (CSG box), `ArenaWalls` (invisible static walls), `Player`, `CameraRig`, `EnemySpawner`, `Hud`, `GameOverScreen`, `SettingsScreen`, `DebugOverlay`.

`Main._ready` ([src/main/Main.gd](../src/main/Main.gd)):
1. Hands the player to the camera rig, the spawner, the HUD and the debug overlay; gives the player the camera for aiming.
2. Attaches `AimIndicator` and `PlayerOcclusionCue` to the player.
3. Runs `SceneSelfCheck.find_problems` and `push_error`s if the world would render empty (no camera, camera can't see the player, etc.).
4. If user args follow `--`, sets up scenario and screenshot capture (`Main._setup_debug_capture`).

Run loop today: one arena, no rooms, no rewards, no run structure yet (Milestone 3a is next per `docs/STATE.md`). The player fights staged waves until dead.

Death and restart:
- `Player.player_died` (from `Health.died`) -> `Main._on_player_died` starts slow-mo and shake via `Juice` and a real-time timer.
- The timer calls `Main._announce_game_over`, which emits `Main.game_over_ready` once. `GameOverScreen` listens, shows itself, and on "Try again" calls `Main.restart_arena()`.
- `restart_arena()` resets `Juice` and `GamePause`, unpauses, and calls `get_tree().reload_current_scene()`. The reload resets everything that lives in the scene (HP, decks, cooldowns, enemies, waves, statuses). Autoload state does not reset on its own, which is why `Juice.reset()` and `GamePause.reset()` are called first.

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
- Dodge: Space, `start_forced_move` with i-frames. `Hurtbox.set_invulnerable` makes i-frames by zeroing the hurtbox collision layer, so attack queries skip it. Dodge speed and duration are Player exports (`dodge_speed`, `dodge_duration`, `dodge_cooldown`), not data.
- `start_forced_move(direction, speed, duration, invulnerable, vfx_look)` is shared by the dodge and the "dash" effect template. It ends exactly at `speed * duration` and stops dead (S6-2).
- Input model: light/heavy clicks and card keys are latched in `_unhandled_input` (so a UI screen can swallow them); movement and dodge poll `Input`. Latched casts and clicks are consumed on the next physics tick. Pause, death, focus loss and a cast-trigger change call `cancel_cast_preview()`.
- Signals: `player_died`, and forwarded `attack_started/fired/ready/cancelled(attack_id)` for the HUD meters.

### Camera ([src/camera/CameraRig.gd](../src/camera/CameraRig.gd))
Fixed-angle isometric rig. Root follows `target`; child `Camera3D` keeps a fixed offset plus shake jitter. Orthographic. `Juice.register_camera_rig` lets `Juice.screen_shake` reach it.

### Combat and damage
- `Hurtbox` (Area3D) has a `team` and paths to `Health` and `StatusEffectManager`. Attacks find hurtboxes by physics query (`MeleeQuery.find_hurtboxes_in_cone / in_sphere`), skipping the caster's own team (no friendly fire).
- `Health.take_damage(amount, type, knockback)` applies the resistance fraction (`CombatMath.apply_resistance`, capped), lowers HP, emits `damaged`, `health_changed`, and `died` once.
- `Player._on_damaged` and `Enemy._on_damaged` call `Juice.on_hit_landed` (damage number, hit-stop, and shake on heavy hits) and apply their own hit flash and knockback.
- Layers: `CollisionLayers` (World 1, Player 2, Enemy 4, Hurtbox 8, Hitbox 16), named in `project.godot`.

### Card slots and decks
- `CardSlot` ([src/cards/CardSlot.gd](../src/cards/CardSlot.gd)): pure `RefCounted`. A shuffled mini-deck (draw pile, discard pile) over the cards owned for one slot type, plus a cooldown. Cooldown = slot base + card `cooldown_modifier`, then `StatModifiers`, floored. Swapping a dead card is blocked while cooling.
- `CardSlotController`: builds the five slots in `SLOT_TYPE_ORDER` (attack_single, attack_aoe, utility, movement, recovery), filters cards by `owned_pools`, and on `try_use(slot_type)` casts the revealed card through `EffectTemplates`. Emits `card_cast`.
- Keys: `slot_1..5` to use, `Ctrl+1..5` (`dead_card_swap_N`) to swap.

### Held-key casting (Slice 6)
- `CastInput` tracks which slot key is held. In `release` mode (default, `data/settings.json`) press starts a preview and release casts; in `press` mode press casts at once.
- `CastPreview` draws the held card's exact hit area on the ground (shapes from `CastPreviewShapes`, sizes from `VfxSizing`, same numbers as the hit query; look from `data/cast_preview.json`). `Player.get_preview_state()` exposes it to tests and the HUD.

### Effect templates ([src/combat/EffectTemplates.gd](../src/combat/EffectTemplates.gd))
Seven reusable effects: `projectile`, `cone`, `aoe`, `dash`, `heal`, `apply_status`, `buff`. `REQUIRED_PARAMS` is the single source of truth for each template's required params; `CardSchema` validates against it. `EffectContext` carries `caster`, `spawn_parent`, `caster_team` and `last_hits` (hurtboxes the previous effect in the same card hit, which `apply_status` targets). Optional params: `knockback_strength`; cone `vfx` (false skips the wedge); aoe `center` (code-only, used by targeted heavies); apply_status `target: "self"`; dash `invulnerable`.

### Statuses ([src/combat/StatusEffectManager.gd](../src/combat/StatusEffectManager.gd), `StatusDatabase`)
A `StatusEffectManager` node on every body that can be affected. `StatusDatabase` validates `data/statuses.json` once; a bad entry is treated as missing and `push_error`s. Effect types are closed: `damage_over_time` (Burn) and `stun` (`StatusDatabase.EFFECT_TYPES`). Stun has diminishing returns and per-rank multipliers (`StunRules`; elite half, boss immune). Signals: `status_applied/expired/refreshed/resisted`. Burn flames and stun stars come from `EffectPool`.

### Attacks (light and heavy)
`data/attacks.json` -> `AttackDatabase` (validated) -> `AttackController` (pure timing: cooldown, auto-fire only with a target, click-rate cap as a ratio, wind-up). `Player._on_attack_fired` runs the same `cone` (or `aoe` for targeted heavies) template cards use, then `AttackStatuses.apply_on_hit` (on-hit statuses, element chance), then `Juice.hit_stop` and shake. The heavy is chosen by the character's class id.

### Enemies and spawner
- `Enemy` ([src/enemies/Enemy.gd](../src/enemies/Enemy.gd)) is one script for all types. `_apply_stats` overrides the scene's exported values with `data/enemies.json` `enemies.<id>.stats`. It chases, telegraphs (ground wedge or shot lane), then attacks through `EffectTemplates` (cone for melee, projectile for ranged). Separation steering uses a static roster and `spawn_index`. Signals: `stunned`, `stun_ended`, `stun_refreshed`.
- Types: `melee_chaser`, `ranged_shooter`, `fire_resistant_golem` (scenes in `scenes/enemies/`, ids and rank in `data/enemies.json`).
- `EnemySpawner` runs a `WavePlan` built from `WaveConfig` (`data/waves.json`): staged groups, a delay per stage, a `max_alive` cap, ring spawn positions, spawn attack grace. Signal `enemy_spawned(enemy, alive)`. `set_seed` seeds spawn choices.
- `EnemyConfig` validates `data/enemies.json` (call `validate_stats`; `Enemy` reads via `stats_for`, `rank_for`, `scene_path_for`).

### Effects and VFX
`EffectPool` (one per world, found with `EffectPool.for_world`) animates simple primitive effects (disc, wedge, sphere burst) with a cap from `data/vfx.json` `max_simultaneous`; at the cap the oldest is recycled. `TemplateVfx` draws each template's visual; `VfxSizing` derives visual size from the hit numbers so visuals equal hitboxes. `ElementVisuals` maps a damage type to color/scale from `data/pools.json` `visual`; a team tint (`data/vfx.json` `team_tints`) makes enemy shots pink.

### HUD and UI
- `Hud` polls the player each frame (no signals): five `CardSlotWidget`s, a health bar with "HP x / y", `AttackMeter`s for light and heavy. Layout comes from `data/ui.json` `hud` through `HudLayout`/`TextFit`.
- `EnemyHpBar` is a billboard per enemy using `assets/shaders/enemy_hp_bar.gdshader`; visibility mode is `data/ui.json` `hp_bars.visibility_mode`.
- `GameOverScreen` (listens to `Main.game_over_ready`), `SettingsScreen` (Esc; one setting; calls `GamePause`), `DebugOverlay` (F3), `AimIndicator`.
- All UI numbers, colors and strings go through `UiConfig` (`data/ui.json`), which validates on load.

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
| `statuses.json` | burn, stun | `StatusDatabase` |
| `attacks.json` | `light`, and `heavy` keyed by class id | `AttackDatabase` |
| `enemies.json` | `attack_shapes`, `separation`, `enemies.<id> {rank, scene, stats}` | `EnemyConfig` |
| `waves.json` | `max_alive`, delays, spawn distances, `stages[]` | `WaveConfig`, `WavePlan` |
| `vfx.json` | Effect pool cap, durations, alphas, `team_tints` | `VfxConfig` |
| `ui.json` | HUD, HP bars, damage numbers, popups, game over, settings screen, death beat, aim | `UiConfig` |
| `cast_preview.json` | Preview look | `CastPreviewConfig` |
| `settings.json` | User-facing settings and defaults (`cast_trigger`) | `SettingsStore` |
| `input_bindings.json` | Action name to key/mouse events | `InputBindings` |
| `scenarios.json` | Capture/test scenarios | `src/debug/ScenarioSchema.gd`, `Scenario` |

Data is validated at first use and fails loudly (`push_error`) on bad content; several tests load the real files, so a typo shows up in the suite.

## 7. Signals worth knowing

- `Player.player_died` -> `Main._on_player_died`.
- `Main.game_over_ready` -> `GameOverScreen`. `GameOverScreen.retry_requested` -> `Main.restart_arena`.
- `Health.damaged / healed / health_changed / died`.
- `CardSlotController.card_cast(slot_type, card_id)`.
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
4. Run the tests (`card_database_test`, `starter_card_set_test`, `card_schema_test` load real data).
5. A card is only reachable if its pool is in `Player.owned_pools`.

### An enemy
1. Duplicate a scene in `scenes/enemies/` (root script `Enemy`), set `enemy_id`, mesh, `Hurtbox` team "enemy", resistances on `Health`.
2. Add `enemies.<id>` in `data/enemies.json` with `rank` (normal/elite/boss), `scene`, and the full `stats` block (`EnemyConfig.validate_stats` lists required keys).
3. Reference the id in `data/waves.json` stages.

### A status
Add an entry in `data/statuses.json` using an existing `effect_type` (`damage_over_time` or `stun`) and a visual `kind` (`flame` or `stars`). A new effect type or visual kind needs code in `StatusDatabase` (`EFFECT_TYPES`, `VISUAL_KINDS`) and `StatusEffectManager`. Apply it from a card with `apply_status`, or from an element via `pools.json` `status`.

### An effect template
Add the id and required params to `EffectTemplates.REQUIRED_PARAMS`, add a case in `execute` and an `_execute_<name>`, add its VFX in `TemplateVfx` (sized through `VfxSizing`), add a preview shape if it has a hit area (`CastPreviewShapes`, `CastPreview`), and cover it in `tests/unit/effect_templates_test.gd`.

### An element
Add a pool in `data/pools.json` with `kind: "element"`, a `visual` (color, scale) and optionally a `status`. Cards use the element id as `damage_type`. No code is needed for the look (`ElementVisuals`); a test proves a Water entry works.

### A slot type
`SLOT_TYPE_ORDER` in `CardSlotController` and `USE_ACTIONS`/`SWAP_ACTIONS` in `Player` are hardcoded to five. A new slot type needs code plus HUD and input binding changes, not just data.

### A scenario
Add an entry in `data/scenarios.json`; unknown or misspelled keys fail on load (`ScenarioSchema`). Add a test in `tests/unit/` if it proves behavior. Document the new scenario in `README.md`.

## 9. Tests and tools

- **Tests:** gdUnit4 suites in `tests/unit/*_test.gd`. Names with `slice*_qa_test`, `*_recheck_test` are qa regression tests; some pin a bug as red-on-purpose until fixed. `tests/fixtures/` holds bad-data samples for schema tests. Run all: `powershell -File tools\run_tests.ps1`. See `README.md`.
- **Sending input in tests:** use `TestInput.press/release/tap` (`tests/support/test_input.gd`). `Input.action_press` emits no event, so `_unhandled_input` never sees it.
- **Tools** (all in `tools/`, commands and verification in `README.md`):
  - `run_tests.ps1` -> gdUnit4 headless.
  - `capture_screenshot.ps1` -> windowed capture, uses `src/debug/*` via user args.
  - `run_bot_sim.ps1` + `bot_sim.gd` -> card/deck NaN check, runs as a `SceneTree` script.
  - `run_wave_sim.ps1` + `WaveSim.tscn` + `wave_sim.gd` -> real Main scene with a bot. A scene, so autoloads exist.
  - `run_reload_cycle.ps1` + `ReloadCycle.tscn` + `reload_cycle.gd` -> death/restart soak.
  - `vp_capture.gd`, `SlotStateCapture.tscn` + `slot_state_capture.gd` -> oversized viewport and HUD slot captures.
- **Windows binary:** the scripts prefer the `*_console.exe` Godot build. The windowed build can make PowerShell report a failing run as success.

## 10. Known sharp edges

- **Projectiles leave `last_hits` empty** (damage lands later). An `apply_status` after a `projectile` in the same card hits nothing.
- **Seeded sim runs don't repeat** (qa S6-4, open): `CardSlot` shuffles use an unseeded RNG, `Player.status_rng` is randomized, and `Juice` hit-stop reads the wall clock. Steering and the wave plan do repeat.
- **Only `GamePause` should set `paused`.** The pause screen and cast preview run `PROCESS_MODE_ALWAYS`. The pause also freezes `Juice` time scale and hands the remaining hit-stop/slow-mo back on resume.
- **Autoload state survives a scene reload** (`Engine.time_scale`, `Juice`, `GamePause`). `Main._prepare_for_restart` resets them; anything new that is global must be reset there too. Re-run the reload soak after touching `Main`, `Juice`, `Player` or the autoloads.
- **Dodge distance is in Player exports,** not `data/`. Director question D8 (open) may move it to data. Dash cards use data `distance` and `speed`.
- **New `class_name` scripts** aren't picked up by a plain headless test run: run `godot --headless --editor --quit --path .` once.
- **Sims must run as scenes** (not `SceneTree` scripts) or autoloads won't exist.
- **Ctrl+N** is a swap, not a cast. Slot keys use `exact_match` on press so Ctrl+1 doesn't also press 1.
- **Don't add per-frame allocation** in hot paths (`Player._physics_process`, `Enemy`, HUD): earlier reviews removed several. Use the `EffectPool`, not new nodes, for transient visuals. The held `CastPreview` is deliberately not pooled.
- **Enemy stats live in data.** The exported fields on `Enemy` scenes are only fallbacks (see `Enemy._apply_stats`); the class header comment in `Enemy.gd` still says per-scene values.
- **Enemy HP bars:** `elite` and `boss` ranks always show their bar; no elite or boss is in the shipped waves yet.
- **`TrainingDummy`** (`scenes/debug/`) is not in `Main.tscn`; some tests instantiate it.
- **One shader lives in `src/player/`** (`player_occlusion_cue.gdshader`), the other in `assets/shaders/`.
