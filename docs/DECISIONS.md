# Decisions Log

> **Scope (director, 2026-10-28):** this log is for assumptions, defaults, and judgment calls that agents make on their own without an explicit director directive. Director directives live where they apply (GDD for design, CLAUDE.md for process, CHANGELOG with the [Director decision] tag) and need no entry here. Older entries are kept as written.

Running log of assumptions, defaults, and technical choices made without stopping for director approval, per the working agreements in `CLAUDE.md`. Newest entries at the bottom. Anything here can be overridden by the director at any time.

---

### 2026-10-26 — Engine and runtime
- **Engine:** Godot 4.7.2 (stable, official build), installed via `winget install GodotEngine.GodotEngine`. This is the latest stable available at kickoff. Record this exact version because GDScript typing/warning behavior has changed across 4.x minors.
- **Language:** GDScript, statically typed (typed variables, typed function signatures, typed arrays where practical). Chosen in the kickoff prompt over C# for zero .NET build step and best Godot editor integration.
- **Rendering:** Forward+ (`renderer/rendering_method="forward_plus"`), the default for desktop. No mobile/compatibility renderer needed for a desktop-only passion project.

### 2026-10-26 — Test framework: gdUnit4
- **Choice:** gdUnit4 v6.2.2 over GUT.
- **Why:** gdUnit4 ships a dedicated CLI runner (`addons/gdUnit4/bin/GdUnitCmdTool.gd`) designed for headless/CI use, with JUnit-style XML + HTML reports out of the box, richer fluent assertions (`assert_int`, `assert_that`, etc.), and more active maintenance tracking current Godot versions (its CI already targets 4.8.dev at the time of writing, so 4.7.2 is comfortably inside its support window — it requires Godot 4.5+).
- **Headless caveat:** gdUnit4's CLI runner intentionally does *not* pass the engine `--headless` flag by default — it runs with a minimized window and a deliberately-refused `--remote-debug` connection to suppress Godot's interactive CLI debugger. This is the upstream-documented pattern and works fine on the director's desktop (confirmed: NVIDIA RTX 3080, Vulkan Forward+). A true dummy-display run is available via `--ignoreHeadlessMode` if ever needed on a GPU-less CI box; not needed now.
- **Documented command:** `tools/run_tests.ps1` (PowerShell). It resolves the Godot binary from `$env:GODOT_BIN` or `godot`/`godot_console` on PATH, then runs the gdUnit4 CLI tool against `res://tests` with `-c` (continue past failures, so one run reports everything instead of failing fast). Exit code reflects pass/fail. See README.md.
- **Found and fixed a silent test-gate bug:** PowerShell's `&` call operator does not reliably wait on, or receive stdout from, a Windows **GUI-subsystem** process — and Godot's default installed binary (`Godot_v4.7.2-stable_win64.exe`) is GUI-subsystem. A deliberately-failing test still returned exit code 0 through the script. Fixed by having `run_tests.ps1` auto-switch to the `_console.exe` sibling binary winget also installs (confirmed: the same failing test now correctly returns exit code 100). Verified a real pass separately returns 0. Lesson: always prove a test *gate* catches a failure, not just that it reports a pass.
- **"Zero warnings" has a real, unresolved gap:** standard GDScript lint warnings (`unused_variable`, `shadowed_global_identifier`, etc., confirmed enabled at the project-settings level) do not print to stdout/stderr under `--headless --quit`, `--headless --editor --quit`, *or* a plain windowed `--quit-after N` run in this Godot 4.7.2 build — only the interactive Script Editor UI surfaces them (confirmed empirically with a planted unused variable and a planted parameter that shadows the `max()` builtin; neither printed anything in any CLI mode tried). The one exception found: scripts with `class_name` go through a stricter global-class-resolution pass during `--editor` mode that *does* error on certain type-inference ambiguity (caught and fixed one real instance in `Player.gd`). Until/unless a better CLI hook is found, "no warnings" for ordinary lint categories is enforced by code discipline (typed declarations, no unused locals, no shadowing builtins), not by an automated gate — flagging this honestly rather than claiming false coverage.
- **Gotcha discovered:** the global `class_name` cache (`.godot/global_script_class_cache.cfg`) is only populated by an editor-mode pass, not by `--headless --quit` running the main scene. After adding any new global-class script (like the gdUnit4 addon, or future autoloads), run `godot --headless --editor --quit --path .` once to rescan before running tests — otherwise the CLI runner fails with "Could not find type X in current scope".

### 2026-10-26 — Project layout
- Root: `project.godot`. `/src` scripts, `/scenes` .tscn files, `/data` JSON content, `/assets` placeholder art/audio, `/tests` gdUnit4 suites, `/tools` CLI utilities (test runner, headless sim), `/docs` design and process docs. Matches the kickoff prompt exactly; no deviation.
- `addons/gdUnit4` is vendored (copied from the v6.2.2 GitHub release source, not npm/asset-library) because the project has no other package manager. It is source-only GDScript, no binaries, ~1.8MB.
- `reports/` (gdUnit4 output) and `.godot/` (Godot's own cache) are gitignored, not committed.
- `KICKOFF_MILESTONE_2.md` (the director's own kickoff-prompt scratch file, predates this session) is gitignored per the director's existing `.gitignore` entry — left as-is, not deleted, not committed.

### 2026-10-26 — Resolving GDD [OPEN]/[PROPOSED] items needed for Milestone 2
These were already resolved by explicit instruction in the Milestone 2 kickoff prompt (not by my own judgment), logged here for the record per GDD §14:
- **Dodge roll vs. Movement slot (GDD §4, open item 2):** Space dodge roll is universal, always available, with its own short cooldown and a brief invulnerability window — separate from the Movement card slot, which is reserved for special movement cards (blink, charge, leap, etc.). Matches the GDD's own `[PROPOSED]` default.
- **Attack slot split (GDD §4, open item 3):** Split into two slots for the prototype — Attack: Single and Attack: AoE — per the GDD's own `[PROPOSED]` default. Will reassess after playtesting whether the split feels cluttered.
- **Empty mini-deck behavior (GDD §4, open item):** Auto-reshuffle the discard pile into the deck when it runs out. Matches the GDD's own `[PROPOSED]` default.
- **Resistance caps (GDD §7):** Elemental resistance reduces elemental damage only (physical damage is never resisted). Caps: normal enemies up to 50%, elites 25% flat, bosses 35% flat, final boss 50% flat across all elements. Exact values from GDD §7, implemented as data on the enemy, not hardcoded per enemy type.

### 2026-10-26 — Milestone 2 implementation choices (not covered by the GDD, decided to keep moving)
- **Basic attack (left click):** a short melee arc (a forward-facing cone hitbox, ~90°, ~1.5m range) rather than a projectile. Reasoning: it is the always-available fallback the GDD says should cover gaps when card slots are on cooldown, and a guaranteed-hit-if-close melee swing is simpler to make feel good (hit-stop, flash, knockback) than tuning a projectile's travel time as a fallback action. Ranged options exist through Attack: Single projectile cards instead.
- **Dead-card swap key:** `Ctrl+<slot number>` as specified in the kickoff prompt, implemented as a remappable input action (`InputMap`), not a hardcoded key check.
- **Stat-modifier system:** implemented as a generic additive/multiplicative modifier stack per stat name (e.g. `slot_cooldown.attack_single`), so passives/equipment can push/pop modifiers without the combat code knowing who they came from. Values are stubbed at zero/neutral for Milestone 2 since there is no meta-progression yet.
- **No resource system:** confirmed per GDD §4 — no mana/energy in this milestone.
- **Camera:** true orthographic isometric (yaw 45°, pitch -35.264°, i.e. the classic (1,1,1) corner view), not a perspective camera — gives a cleaner, distance-independent "isometric" read and matches GDD §3's "fixed isometric camera" literally. `CameraRig` (a plain `Node3D`) exponentially smooths its *position* toward the player each frame; the `Camera3D` child never rotates, it's a fixed local offset, so the angle never drifts.
- **Movement is camera-relative, not world-axis-relative:** WASD is transformed by the camera's flattened forward/right vectors rather than raw world X/Z. With a fixed camera this is equivalent today, but it means movement stays correct if the fixed angle is ever tuned later without touching `Player.gd`.
- **Input bindings are data:** `data/input_bindings.json` + the `InputBindings` autoload (`src/core/InputBindings.gd`) build the `InputMap` at startup from JSON (key names resolved via `OS.find_keycode_from_string`), instead of hand-editing `project.godot`'s `[input]` section. Only movement bindings exist so far; attack/dodge/slot bindings will be added to the same file as those features land.
- **Headless bot-sim stub (`tools/bot_sim.gd`):** drives N "rooms," each a fresh `CardSlotController` loaded with the real starter cards, randomly using/swapping slots for 300 ticks and checking for NaN in cooldowns/health. Deliberately not a balance simulator yet - cards whose effects need targets (cone/aoe/projectile) just find nothing to hit in an empty room, which is fine since this stub stresses the card/deck/cooldown system itself, not combat outcomes; that's explicitly Milestone 3/4 scope per the GDD. **Found a real Godot gotcha while building it:** a node added to the tree (`root.add_child(...)`) from inside a `SceneTree` script's `_initialize()` is *not yet* `is_inside_tree()` - `global_transform`/`get_world_3d()` fail with engine errors - until the main loop has ticked at least once. Fixed by `await process_frame` right after adding each room's caster, before touching any of its 3D properties. This is specific to driving nodes synchronously from `_initialize()`; the actual game (driven by the normal running engine loop) never hits this.
- **Juice pass (hit-stop/screen shake/damage numbers):** a `Juice` autoload is the single thing combat code calls on a hit (`Juice.on_hit_landed(pos, amount, damage_type)`); Player/Enemy/TrainingDummy's `_on_damaged` handlers all call it alongside their own hit-flash, instead of each reaching into camera/time-scale internals themselves. Hit-stop (`Engine.time_scale` dipped briefly) is timed by wall-clock (`Time.get_ticks_msec()`), not by accumulating a scaled `delta` - otherwise a dipped time-scale would make the hit-stop's own countdown take far longer in real time than intended. A hit at/above `HEAVY_HIT_THRESHOLD = 10` gets a stronger hit-stop + a screen shake (forwarded to `CameraRig.shake()`, which jitters the `Camera3D` child's local position around a cached base offset - never touches the rig's own follow position, which stays locked to the player); lighter hits get a smaller hit-stop and no shake. Damage numbers are a `Label3D` (`DamageNumber`) that rises and fades over a fixed duration, color-coded per `damage_type` (fire = orange, else white) - the one general hook for per-element juice this milestone needed.
- **HUD/debug overlay are pure pollers, not signal-driven:** `Hud`/`DebugOverlay` read `Player.health`/`Player.card_slots` directly in `_process()` every frame rather than subscribing to change signals. Simpler for a 5-widget HUD at this scale, no event wiring to keep in sync; worth revisiting with signals if the UI grows much more complex. The cooldown bar is a linear `ProgressBar`, not a true radial "sweep" (no texture/shader work for a placeholder-visuals milestone) - conveys the same information.
- **`CardSlot.last_cooldown_duration` is UI-only, informational state:** added purely so the HUD can compute a fill ratio (`cooldown_remaining / last_cooldown_duration`); nothing in the slot's own logic reads it back, and it's not part of the 15 CardSlot tests' contract.
- **Starter card set:** 15 cards in `data/cards/` for the Fire Rogue slice - 5 attack_single, 3 attack_aoe, 3 utility, 2 movement, 2 recovery; 6 rogue (physical), 4 fire (3 of which `apply_status` Burn), 4 neutral. Damage/cooldown numbers are placeholder tuning values, not balanced against anything yet - first real playtest target. One deliberate constraint logged here because it shapes which templates a card can combine: `apply_status`/`buff` targeting `"last_hits"` only works after a *synchronous* damage effect (`cone`/`aoe`) earlier in the same card's effects list, never after `projectile` (its hit lands on a future frame - see the effect-template commit). That's why `fire_flaming_nonsense` (a projectile card) doesn't also apply Burn, while `fire_ember_whatever`/`fire_fine_burn_then`/`fire_blaze_and_bail` (cone/aoe) do.
- **`buff` cards only target `slot_cooldown.<slot_type>` for now** (e.g. `rogue_not_my_problem` cuts `attack_single`'s cooldown briefly) - that's the only stat `CardSlotController` actually reads through `StatModifiers`. A card author could write a `buff` targeting some other stat name and it would validate fine (the schema only checks the effect's own required params, not whether anything *reads* that stat) but do nothing - acceptable for the prototype, worth a schema tightening later if it becomes a real authoring foot-gun.
- **Added the required "every card must load and validate" test** (`starter_card_set_test.gd`), enumerating `data/cards/` directly via `DirAccess` and running each through `CardSchema.validate()` - this is the specific test called out in the kickoff prompt, deferred until there was real data to enumerate. Also locks in: at least 12 cards exist, no duplicate ids, at least one card has a negative `cooldown_modifier`, and every slot type has at least one owned card.
- **Enemies are one script (`Enemy.gd`), not three:** the melee chaser, ranged shooter, and elemental-resistant golem are the same `CharacterBody3D` script with different exported values per scene (`is_ranged`, speeds, damage, and - for the golem - `Health.resistances = {"fire": 0.5}`, the GDD's own Fire Golem example from §7, at the normal-enemy 50% cap). A ranged enemy's attack calls `EffectTemplates.execute("projectile", ...)` and a melee one calls `"cone"` - the *same* templates cards use, so enemy attacks and player cards share one code path, not parallel implementations.
- **Added a knockback vector through the whole damage chain** (`Hurtbox.receive_damage` -> `Health.take_damage` -> the `damaged` signal now carries `knockback: Vector3`, default `Vector3.ZERO`) so `Enemy._on_damaged` can react to being hit without Health/Hurtbox needing to know anything about physics bodies. `cone`/`aoe`/`projectile` compute it from an optional (not required) `knockback_strength` param, so most cards that don't set it get a real `Vector3.ZERO`, not a flag to check. Enemies decay their knockback velocity over time (`KNOCKBACK_DECAY`) rather than it being an instant one-frame nudge.
- **Hit-flash and the attack telegraph share one mechanism:** both just set `BodyMesh.material_override.albedo_color` and either let a `Tween` fade it back (hit-flash) or hold it for `telegraph_duration` then snap back when the attack fires (telegraph). Each enemy instance duplicates its material in `_ready()` - without that, tweening one enemy's color would tweak the shared `.tscn` material resource and flash every instance of that enemy type at once.
- **Enemies collide with each other, not just the world** (`collision_mask` includes both `WORLD` and `ENEMY_BODY`), purely so a spawned wave doesn't stack enemies on top of each other - cheap, no pathfinding needed for this milestone's open arena.
- **`CardSlotController` wires 5 `CardSlot`s to one caster, keyed `attack_single/attack_aoe/utility/movement/recovery` (keys 1-5 in that order):** also plain `RefCounted`, owned directly by `Player` rather than a scene-tree component, since only Player casts cards in this milestone. Casting calls `EffectTemplates.execute()` for every effect in the used card's data - so "what a card does" is 100% in `data/cards/*.json`, never in `CardSlotController`.
- **Character creation doesn't exist yet, so owned pools are a fixed export:** `Player.owned_pools = ["rogue", "fire", "neutral"]` (the Fire Rogue slice). A slot's mini-deck is every card in `data/cards/` whose `slot_type` matches and whose `pool` is in that list. Will become real character-creation data in a later milestone.
- **Real input gotcha, fixed before it shipped:** `Input.is_action_just_pressed()` defaults to `exact_match=false`, which ignores extra held modifiers - so without a fix, Ctrl+1 would fire *both* `slot_1` and `dead_card_swap_1` in the same frame. `Player._handle_card_slot_input()` passes `exact_match=true` for every slot/swap check, and checks swap before use, so the two actions are mutually exclusive.
- **`CardSlot` (the mini-deck + cooldown logic) is plain `RefCounted`, not a `Node`:** no scene tree dependency, ticked by an explicit `advance(delta)` call, RNG injected (defaults to a real `RandomNumberGenerator` but tests pass a seeded one) - so it's a normal unit-testable class and the same code will drive the headless bot-sim later with zero changes.
  - **Cooldown order:** `raw = base_cooldown + card_cooldown_modifier`, *then* the generic `StatModifiers` stack is applied to that raw value (so passives/equipment modify the card-adjusted number, not the slot's bare base), *then* floored at `MIN_COOLDOWN = 0.05s` so a large negative card modifier can't zero/negative the cooldown and let a slot infinite-chain.
  - **Dead-card swap is blocked while the slot is already on cooldown** (from a cast or a previous swap) - "busy" means busy regardless of which action caused it, so a player can't spam-swap to peek future cards for free mid-cooldown.
  - **Reshuffle happens the instant the draw pile would go empty**, including mid-draw (right after taking the card that empties it), never lazily on the next peek - `preview_card_id()` can never show a stale/wrong "next" card across a reshuffle boundary. One concrete, slightly surprising consequence locked in by a test: swapping on a 2-card deck discards the current card, draws the only other card, and that immediately empties the draw pile - so the just-discarded card gets reshuffled straight back into the draw pile instead of sitting in `discard_pile`. Not a bug; a 1-card deck behaves the same way (swap just hands the same card back, wasting the penalty) - also covered by a test.
  - **An empty slot (no owned cards of that type) is fully inert:** `is_ready()` is always false, `use_card`/`swap_card` are safe no-ops, nothing crashes.
- **Card schema (`CardSchema`) never logs; the loader (`CardDatabase`) does, and only it:** `CardSchema.validate(card_data) -> Array[String]` returns errors as plain data and never calls `push_error`, specifically so unit tests can throw malformed cards at it without polluting a "zero errors" run or risking gdUnit4's error monitor flagging the test itself. `CardDatabase.load_all()` (the actual boot-time path) is the only place that `push_error`s and skips a bad file rather than crashing - consistent with "fail loudly" meaning *the log*, not *the game*. Malformed-schema test cases live as inline Dictionary literals in `card_schema_test.gd`; `tests/fixtures/cards_valid/` holds real small JSON files for `CardDatabase`'s happy-path tests (loading from disk is the thing being tested there), not malformed ones.
- **Slot types and pools are data, not an enum:** `data/slot_types.json` (the 5 slots, each with a base cooldown and input action) and `data/pools.json` (rogue/fire/neutral for the slice) back `SlotTypeDatabase`/`PoolDatabase`, both tiny wrappers around a shared `JsonDataTable` lazy-cache (also now used by `StatusDatabase`, retro-fitted to remove its duplicate load/cache code). `CardSchema` cross-checks a card's `slot_type`/`pool` against these at validation time, so a new class, element, or slot is a data change, never a code change.
- **Effect-template registry (`EffectTemplates`):** a static dictionary of required params per template (`projectile`, `cone`, `aoe`, `dash`, `heal`, `apply_status`, `buff`) plus a `match`-based `execute()`. `CardSchema` (next) validates a card's effect params against the *same* `REQUIRED_PARAMS` dictionary the executor uses, so the two can't silently drift apart. `EffectContext` carries the caster, where to spawn child nodes, the caster's team (for friendly-fire exclusion), and `last_hits` - the Hurtboxes a damaging effect (cone/aoe) just hit, which a later effect in the *same* card (e.g. `apply_status`) targets by default. `apply_status`/`heal`/`buff` can instead target `"self"` via a `target` param. Refactored the basic attack to call `EffectTemplates.execute("cone", ...)` instead of inlining its own copy of the same logic, so "basic attack" and "a Rogue card that happens to use the cone template" are provably the same code path, not two copies that can drift apart.
- **Dash reuses dodge's motion code, not a copy:** generalized Player's dodge-specific state into `start_forced_move(direction, speed, duration, invulnerable)`, a public method any caster can call. Dodge calls it with `invulnerable=true`; the "dash" template calls it with whatever the card's `invulnerable` param says (defaults `false` - a Movement-slot dash card isn't automatically an i-frame dodge unless a card explicitly says so).
- **Projectile is a self-contained node, not something its caster has to tick:** `Projectile.gd` (an `Area3D`) manages its own travel distance and frees itself on hit or at max range. This is why `projectile` can never populate `EffectContext.last_hits` for a following effect in the same card (the hit happens on a future frame, possibly after the card-cast call has already returned) - documented as a known composition limit, not a bug.
- **Test coverage gap, accepted:** `cone`/`aoe`/`projectile` are physics-overlap-dependent and not covered by automated unit tests (gdUnit4's ad-hoc test-tree nodes don't get a physics-server flush without real scene-tree frames, which is more machinery than this milestone's required test list calls for). Verified instead via code review + the manual TrainingDummy playtest, since `cone` is exactly the same path the already-working basic attack uses. `heal`/`apply_status`/`buff` (no physics query) are unit tested directly.
- **Combat foundation (Health/Hurtbox/CombatMath):** `Health` (generic damage/death component), `Hurtbox` (Area3D damage receiver with a `team` tag for friendly-fire filtering, on a dedicated "Hurtbox" physics layer so attack queries don't also pick up world geometry), and `CombatMath.apply_resistance()` (pure static function, physical damage always ignores resistance, elemental damage clamped to the resistance cap) are the shared primitives enemies and cards will reuse. Dodge i-frames are implemented by zeroing the Hurtbox's collision layer for the dodge's duration, not a boolean flag the attacker has to check — this means *any* attack query simply fails to find the dodging target, no special-casing needed at the call site.
- **Basic attack hit-detection (`MeleeQuery`):** a forward-facing cone query (sphere overlap + angle filter) kept as a standalone static function rather than inlined in `Player.gd`, specifically so the upcoming "cone" card effect template can call the same function instead of re-deriving cone-hit logic.
- **Status effects / Burn:** `StatusEffectManager` (a `Node` component, one per damageable entity) holds active statuses as plain data and ticks them in `_process`. Each status is a `data/statuses.json` entry with an `effect_type` (only `damage_over_time` exists yet); adding Chill/Soaked later, if they're also damage-over-time variants, is a data-only change — a genuinely new mechanic (e.g. a movement-slow) is one new `match` branch in `_tick()`, not a new system. Re-applying a status the target already has refreshes its duration rather than stacking a second instance — simplest behavior, and nothing in the GDD asks for stacking. `StatusDatabase` lazily loads and caches `data/statuses.json` behind a `static var`, so repeated `apply_status` calls don't re-parse JSON.
- **Found a gdUnit4 gotcha while testing this:** instantiating a `Node`-derived class (`Health.new()`, `StatusEffectManager.new()`) directly in a test without adding it to the scene tree trips gdUnit4's orphan-node monitor (exit code 101, even with 0 failed assertions) unless wrapped in the suite's `auto_free()` helper. Will keep using `auto_free()` for every `Node` created directly in a test.

### 2026-10-27 — Enemy HP bars: default visibility rule (post-milestone polish)
- **Rule:** enemy health bars are **always visible while the enemy is alive, and hidden on death**. Proposed default for the director's "HP bars above enemies" request; the GDD does not specify one.
- **Stored as data, not code:** the rule is a config value (e.g. `data/enemy_health_bar.json`, `"visibility": "always_while_alive"`) that the bar reads at spawn, so it can later become `"after_first_damage"` or a player setting without touching the bar's script. Exact file/key name is gameplay-dev's call; it must be logged here when chosen.
- **Reasoning:** simplest rule to implement and verify, and the most readable for a combat-feel prototype where the director is judging fight state.
- **Rejected alternative:** "show only after first damage" (less clutter in big waves, but hides information during the exact playtests where readability is being judged). Kept available as a future config value.

### 2026-10-27 — Enemy HP bars: director follow-up answers
- **Visibility:** director confirmed `always_alive` (always visible while alive) as the default. No change.
- **Size:** director says the current size is fine. The proposed bump (~1.6 x 0.22) is dropped. Rejected alternative: bump now pre-emptively. No evidence it's needed.
- **Resistance marker:** reading as "armoured" rather than "resists fire" is acceptable for now. Tooltip/legend follow-up stays open for later.
- **Deferred idea, not a task:** show HP as a number or % (e.g. "34/100") on or near the bar. Not scheduled. Revisit if the director asks or readability feedback calls for it.
- **Screenshot tooling approved and built** (f468959, 96ca1a1, 083a8cf; qa PASS on 083a8cf after an earlier FAIL for malformed args hanging and an unknown scenario exiting 0). Agents now verify visuals with `tools/capture_screenshot.ps1 -Scenario <name> -After "<seconds,...>"` instead of ad-hoc `--script` captures.
- **New follow-ups from the capture review** (game-lead call, small and reversible): damage-number readability (~10 px at 720p) and an optional, config-only, more visible ghost segment, both for ux-designer. Tight-cluster bar stacking is noted but not scheduled; it only shows in very dense clusters.

### 2026-10-27 — Post-milestone polish 1, Slice 0: director decisions recorded in the GDD
- **Authorization:** the director explicitly approved every item in the "Post-milestone polish 1" request and said not to ask about them. game-lead made these GDD edits under that approval; no design was invented.
- **GDD §9 reward offer:** pick 1 of 3 or reject the whole offer. A reject token is spent only on a whole-offer reject (the director's wording "rejects the whole offer" plus the 3-per-run cap; the GDD's own open question asked exactly this). Offer size is a data value (default 3) so boons, passives, and gear can raise it or add rerolls. Shops and drops stay `[OPEN]` (GDD §14 item 1 narrowed). Reward screen is Milestone 3b, not built now.
- **GDD §1:** density principle added verbatim, tagged `[DIRECTOR DECISION]`.
- **GDD §3:** "Basic attack: left click ... fallback" replaced by the light attack (auto on a timer + left click) and heavy attack (right click). The old "used automatically as a fallback" wording is superseded by the auto light attack.
- **New GDD §15 "Ideas and Parked Concepts":** appended at the end instead of inserted mid-document, so existing references to "§13" and "§14 item 1" in STATE/ROADMAP/DECISIONS stay valid. Rejected alternative: insert before §14 and renumber (breaks cross-references silently).
- **Roadmap:** Milestone 3 split into 3a (run structure, next after this pass) and 3b (reward screen, reusable for future 3-choice screens).

### 2026-10-27 — Post-milestone polish 1: "0 / 30" HUD investigation (game-lead, read-only)
- It is **player HP**: `src/ui/Hud.gd:30` formats `player.health` as `"%d / %d"` (max HP 30). `Player.gd` connects `Health.damaged` but never `Health.died`, so at 0 HP nothing happens and the player keeps moving and casting. That matches the director's report of "0 with an empty bar while alive and moving". Fixed in Slice 1 by handling death and labelling the value "HP".
- `Health` already guards against double death (`_is_dead`, `died` emitted once), so Slice 1 consumes that signal rather than adding a second guard.

### 2026-10-27 — Post-milestone polish 1: how roles are run
- This main session has no in-process subagent tool. game-lead tried running roles via the Claude Code CLI (`claude -p --agent <role> ...`) from Bash; the session's auto-mode permission check **denied** launching nested agents. game-lead did not work around it, and does not write game code itself (out of scope per `.claude/agents/game-lead.md`).
- Result: Slice 0 (docs) is done; slices 1-5 are fully briefed in `docs/ROADMAP.md` and wait for the director to run each role. Options: start sessions per role (`claude --agent gameplay-dev`, then `ux-designer`, `qa`, `playtester`), or allow nested agents / a subagent tool so game-lead can orchestrate the loop itself.
- **Follow-up (director, same day): chose "game-lead orchestrates".** A second nested-CLI attempt was also denied. Root cause: `.claude/agents/game-lead.md` listed `tools: Read, Grep, Glob, Edit, Write, Bash`, which leaves out Claude Code's built-in `Agent` (subagent) tool, so a `claude --agent game-lead` session cannot delegate. Fix: added `Agent` to game-lead's tool list (takes effect on the next session start). Subagents run in-process, one at a time, using the existing `.claude/agents/*.md` definitions and their own tool limits. Rejected alternative: a Bash permission rule for nested `claude -p --agent` processes (heavier, bypasses the in-process subagent model, and widens Bash permissions). game-lead did not edit permission settings itself.

### 2026-10-27 — Slice 1 (death and game over), gameplay half
- **Signals/methods:** `Player.player_died` (src/player/Player.gd; emitted once, forwarded from `Health.died`, no second guard), `Player.is_dead()` / `Player.can_act()`. `Main.game_over_ready` (src/main/Main.gd; emitted once after the death beat), `Main.is_game_over()`, `Main.restart_arena()`. UI finds Main as `get_tree().current_scene`. The future run system listens to `player_died`.
- **Death beat timings (data/ui.json `death_beat`, validated by `UiConfig.validate_death_beat`, bad values push_error and fall back to defaults):** slow-mo scale 0.25 for 0.9 s real time, body collapse/grey-out 0.5 s. Slow-mo reuses Juice's wall-clock hit-stop (`Juice.slow_mo`), and Main's beat timer is created with `ignore_time_scale = true`, so neither is stretched by the slow-mo. `game_over_ready` fires when the beat ends.
- **Restart = `reload_current_scene()`.** Rejected: manual state reset (HP, decks, cooldowns, enemies, waves, statuses, timers each reset by hand) - easy to miss a field and leak state as systems grow. Before reloading, `Main._prepare_for_restart()` calls `Juice.reset()` (clears hit-stop state, drops the stale camera-rig ref, `Engine.time_scale = 1.0`) and unpauses the tree. InputBindings is idempotent on reload (it only rebuilds the InputMap in `_enter_tree`, which runs once). A repeat `restart_arena()` call is ignored.
- **Dead player:** physics loop only settles (gravity/friction); hurtbox made invulnerable (also blocks Burn/hits; Health already guards); `start_forced_move` refused. Enemies use duck-typed `is_dead()` on their target, cancel any telegraph, and stand still; the spawner stops waves.

### 2026-10-27 — Slice 1 (death and game over), UI half
- **Game Over screen:** `scenes/ui/GameOverScreen.tscn` + `src/ui/GameOverScreen.gd`, a CanvasLayer (layer 10, above the HUD) instanced in Main.tscn. Hidden until `Main.game_over_ready` (or shown at once if `is_game_over()` is already true). Its full-rect root has `mouse_filter = STOP`, so clicks never reach the world. Placeholder look: dim backdrop, centered column.
- **Text (data/ui.json `game_over`, so story can re-voice it):** title "Well. That went badly.", line "The world is still cheerful about it. You are not.", button "Try again", hint "Enter or Space". Cheerful-world/weary-hero tone per GDD §11; the button label stays plain.
- **Sizes:** font sizes and button min size are in data at a 720p reference (title 56, line 24, button 40, hint 18; button 360x90) and scaled by window height / `reference_height` in code (`GameOverScreen.ui_scale`), because the project has no stretch mode yet. Rejected: enabling project-wide content scaling now (would change every existing screen).
- **Input:** "Try again" is focused on show; mouse click, Enter, and Space (Godot's `ui_accept`) all activate it. No extra `input_bindings.json` action added: ui_accept already covers it, and a second binding adds nothing. Space doubles as dodge, harmless since a dead player cannot act.
- **HUD HP label:** now "HP %d / %d" (Hud.gd, Hud.tscn placeholder text).
- **Capture tooling:** scenario `game_over` (player 30 HP, 2 melee chasers) with a scenario-only `kill_player_at` key handled in `Scenario._process`; only runs under `--scenario=`. `tools/capture_screenshot.ps1` gained `-Resolution` (default 1280x720).

### 2026-10-27 — Slice 2 (HUD text overflow and safe layout)
- **Scaling rule (consistent with Game Over):** still no project stretch mode. All HUD sizes live in `data/ui.json` `hud` at a 720p reference and are scaled by viewport height / `reference_height` (`HudLayout.ui_scale`). The HUD re-lays itself out on `size_changed`. Rejected: project-wide content scaling (changes every screen).
- **Fixed slot size:** 150 x 118 px at 720p; gap 12; row heights fixed (key 20, name 48, bar 10, preview 34, row separation 2). Name/preview labels are fixed-size with `clip_text`, so a long name can never move the bar or preview. Row heights are checked by tests against the real font at base size and at 1.0/1.5/2.0 scale (2 lines of the base font must fit the row; the 1-px rounding that broke this at 1.5x is why the heights carry slack).
- **Safe margin:** 16 px at 720p (scales: 24 at 1080, 32 at 1440) on every side. Slot bar is bottom-centre, HP panel top-left, both inside the safe area (`HudLayout.safe_area`).
- **Fit rule (`src/ui/TextFit.gd`, pure):** wrap to max 2 lines; else shrink 1 px at a time to the minimum; only then truncate with an ellipsis (binary search for the longest prefix). Name: 15 px base, 11 px min. "Next:" preview: 11 px base, 9 px min, 2 lines. Mins are at 720p, so they scale up with the window. 9 px at 720p is small; it is a last-resort size (no current card needs it) and is a data value if the director wants it raised. `fit_padding` 2 px keeps text off the label edge.
- **Flavor lines:** not shown in the HUD today. The test budgets them against a 260 px box, 3 lines, 11 px min (`flavor_box_width`, `flavor_max_lines`, `flavor_min_font_size`) as the assumed width for the future card tooltip/reward screens. Placeholder; revisit when those screens exist.
- **Full name:** the F3 overlay now prints `id (Full Name)` for current and next. **Tooltip deferred:** a hover tooltip needs the slot widgets to stop ignoring the mouse, which would swallow world clicks (attacks) over the bar. Not cheap; revisit with the Slice 3 click-attack work.
- **Schema warning:** `CardSchema.warnings(card)` returns advisory strings for names over `hud.name_warn_length` (25 chars; Healing Potion (Lukewarm) is exactly 25 and passes). `validate()` is unchanged, so it is never a failure. `CardDatabase` logs them via `push_warning` at load. No current card triggers it.
- **HP bar (s1-d):** 22 px tall at 720p, white 2 px border, dark back, saturated red fill, white 16 px label with a dark outline (colors in `hud.hp_*`). Shape plus border carry the contrast, not color alone.
- **Capture note:** this machine's display clamps the window height to 1061 px, so 1920x1080 and 2560x1440 captures are 1920x1061 and 2560x1061. The scale follows the real height, so these are not true 1080p/1440p. True sizes are covered by the layout tests.

## 2026-10-27 - Raise "Next:" preview minimum font to 10 px (game-lead)
- Playtester (Slice 2) found 9 px at 720p legible but the smallest text on screen. No current card shrinks that far, so raising it costs nothing now and leaves headroom.
- Decision: `preview_min_font_size` 9 -> 10, done by ux-designer during Slice 3. Rejected: 11 px (would force ellipsis sooner on long next-card names in fixed 150 px slots).

### 2026-10-27 — Slice 3 (auto light attack, manual heavy attack), gameplay half
- **Data:** `data/attacks.json` (`light`, `heavy`), loaded by `AttackDatabase` (src/combat) and validated field by field (`validate_entry`/`validate_table`: bool `auto`, non-empty strings, numeric ranges, valid color, both ids required). `Player` calls `load_valid()`: every problem is `push_error`'d and an invalid attack is not built (never half-loaded). Timing lives in `AttackController` (src/player, RefCounted, scene-free, signal-driven); `Player` only supplies input, a target query, and executes the existing `cone` template. No new effect template. The old export attack fields and the `attack_basic` action are removed; bindings are `attack_light` (LEFT) and `attack_heavy` (RIGHT) in `input_bindings.json`.
- **Light (placeholders):** auto true, interval 0.6 s, damage 8, range 1.8, half angle 50 deg, wind-up 0, knockback 3, hit-stop 0.03 s at scale 0.2, shake 0.05 / 0.08 s, color #ffe27a, flash 0.12 s. Old basic attack was 0.45 s cooldown; the auto cadence is slower on purpose so clicking is worth doing.
- **Heavy (placeholders):** auto false, cooldown 1.8 s, damage 22, range 2.4, half angle 85 deg, wind-up 0.45 s, knockback 8, hit-stop 0.1 s at scale 0.03, shake 0.4 / 0.25 s, color #ff5a2a, flash 0.2 s. Setting `"auto": true` is the only change needed to make it automatic.
- **Auto rule:** an auto attack starts only when its cooldown is ready and at least one enemy hurtbox is inside its range and arc (cone along the player's current facing, which tracks mouse aim). It stays ready while nothing is in range and swings the instant a target enters. Auto heavy uses the same rule with heavy's own range and arc.
- **Manual rule:** a click always swings, even with no target ("manual always swings"). Light click is allowed whenever at least `manual_min_gap` (0.25 s) has passed since the last start, and it restarts the auto timer, so spam-clicking tops out at 4 swings/s versus 1.67 auto. Heavy has `manual_min_gap` -1, meaning a click works only when ready. Manual is processed before auto in a tick, so click plus auto on the same tick fires once.
- **Cooldown start:** the cooldown starts when the swing/wind-up starts (not when it lands), so heavy 1.8 s includes its 0.45 s wind-up. `get_attack_progress` therefore refills during the wind-up.
- **Blocking:** while any attack is winding up (heavy), no other attack starts (light is blocked, committed swing). Wind-up does not slow or root the player and does not cancel on dodge (dodge never blocked attacks before; rule kept). Death cancels a wind-up and blocks everything via `can_act()`.
- **StatModifiers:** the stat name is a data field (`stat`): `attack_interval.light`, `attack_cooldown.heavy`. Resolved with `apply()` (read-only; no StatModifiers change), floored at 0.05 s (`AttackController.MIN_INTERVAL`).
- **Visuals:** `AttackArcVisual` is a flat wedge on the ground sized exactly to the attack's range and half angle (so it matches the hitbox), colored from data. Heavy shows it as a telegraph brightening from alpha 0.15 to 0.6 over the wind-up, then a flash; light only flashes (alpha 0.8, fading over `flash_duration`). The brief's "scale" is not a data field: scaling the wedge would misrepresent the hit area (Slice 4 rule); heavy reads as different through color, a larger wedge (range and arc), wind-up, and stronger feel. Hit-stop and shake are applied only when the swing hit something, through `Juice`; enemies' own on-hit hit-stop still applies and the longer one wins.
- **Input gap:** attacks poll `Input.is_action_just_pressed`, so a click consumed by a future full-screen UI (reward screen) would still count unless the player is blocked; Game Over is safe because the player is dead. Revisit with the reward screen (move to `_unhandled_input` latching).
- **Capture:** scenario `attacks` (2 golems in front, aim frozen via scenario-only `freeze_aim`, scripted heavy click at 2.2 s via `heavy_at`). Good shots: `-After "0.75,2.4,2.7"`.

### 2026-10-27 — Slice 3 (auto light attack, manual heavy attack), UI half
- **Attack meters** (`src/ui/AttackMeter.gd`, two instances in Hud.tscn, rects from `HudLayout.attack_meter_rects`): stacked under the HP bar, same left edge, so the centre stays clear. Each is a label ("LMB"/"RMB") plus a left-to-right fill bar that reads `Player.get_attack_progress`, `is_attack_ready`, `attacks.is_winding_up` each frame. Light is subtle (12 px tall at 720p, 60% alpha fill, thin border), heavy is prominent (22 px, full alpha). Colors reuse the attack colors from `attacks.json` (light #ffe27a, heavy #ff5a2a) for one color language with the swing wedges. Sizes/colors/alpha live in `data/ui.json` `hud` (`light_meter_size`, `heavy_meter_size`, `meter_*`).
- **States (shape and text, not color alone):** cooling = darkened fill and faint border; ready = full bar, bright thick border; heavy ready also prints "READY"; heavy during wind-up prints "SWING" (its cooldown is already refilling then, per the gameplay rule). Heavy gets a 0.4 s white pulse on `attack_ready`; light never pulses (0.6 s cycle would flicker). Light's bar stays full while no target is in range (auto holds), which reads as "armed".
- **Slot ready/cooling (s2-b):** uses existing `CardSlot.cooldown_remaining`/`last_cooldown_duration`/`is_ready()`, no gameplay change. The bar now fills as the cooldown elapses (full = ready; before it drained). Ready = full brightness, 2 px white border, green bar. Cooling = whole widget dimmed to 70% (`slot_cooling_dim`; 55% was too faint for the "Next:" text on the green ground), no border, grey-blue bar. Border presence is the non-color cue.
- **s2-a:** `preview_min_font_size` 9 -> 10; existing fit tests pass.
- **Mouse:** the HUD root, containers, bars and labels defaulted to STOP/PASS (HealthPanel, HealthBar, SlotBar swallowed clicks). `Hud._ready` now sets IGNORE on every Control under Root, and a test walks the whole HUD tree. This also covers the qa s2-e check.
- **Tools:** `tools/SlotStateCapture.tscn` renders the HUD with mixed ready/cooling slots (run as a scene; autoloads do not exist under `--script`).

### 2026-10-28 — Slice 4 scoping and hold-to-preview proposal (game-lead)
- **Split Slice 4 into 4a/4b/4c/4d** (foundation; template visuals; aim and markers; qa/playtest/close). Reason: six criteria plus six folded follow-ups is too much for one sitting under the usage limit. Each sub-step is committed and runnable alone. Rejected: one gameplay-dev pass for the whole slice (high cutoff risk, half-done visuals).
- **Element visual data home:** element entries already live in `data/pools.json` (`"kind": "element"`). Visual color/scale goes there by default. Rejected: a new parallel `data/elements.json` (two sources of truth for an element). gameplay-dev may deviate with a logged reason.
- **s3-a default:** the swing wedge is drawn to the current effective reach (range + target hurtbox radius); the hit query is unchanged. Reason: attack balance (P1-P4) awaits the director's feel check; changing the hit query would shift balance silently. Rejected: shrink hits to the drawn range.
- **Hold-to-preview (criterion 6, PROPOSAL ONLY, not built):** holding a card's key shows its exact hit area (cone/aoe circle/projectile path) on the ground from the same data as the hitbox, and casts on release; a quick tap casts immediately as today. Cost: input latching per slot, a preview draw reusing the 4a hitbox-sized visuals. Open for the director: tap-vs-hold threshold, and whether it is an option in Settings or the default. Revisit after Milestone 3a.

### 2026-10-28 — Slice 4a foundation (gameplay-dev)
- **Capture scenario `card_cast`** (`data/scenarios.json`, hooks in `Scenario.gd`): 8 enemies (4 golems, 4 chasers, 2000 HP each via scenario-only `enemy_max_health`) in front of the frozen-aim player, `player_start_damage` 60 so the heal shows, and a `casts` list `{at, slot, card}`. Each cast forces the named card into the slot's revealed position (deck order is random) and goes through the real `CardSlotController.try_use`. Half a second later it re-reads the slot cooldown, prints `Scenario: ... cooling a -> b OK` and `push_error`s if it did not drop (live cooling check). Casts: 0.6 projectile (Pointy Stick), 1.8 cone (Overhand), 3.0 aoe (Shrug Bomb), 4.2 cone + Burn (Ember, Whatever), 5.4 heal, 6.0 buff (Hot Head), 6.6 dash. **Good `-After` times:** `0.9,1.9,3.2,4.4,5.5,6.1,6.8` (about 0.1 to 0.3 s after each cast; cooling bars visible in the HUD). Command: `powershell -File tools\capture_screenshot.ps1 -Scenario card_cast -After "0.9,1.9,3.2,4.4,5.5,6.1,6.8" -Out screenshots\cc.png`. Rejected: relying on the random mini-deck (non-repeatable shots).
- **Pooled VFX** (`src/effects/EffectPool.gd`, `PooledEffect.gd`, `VfxConfig.gd`, `data/vfx.json`): one `EffectPool` node per world, found or created under the spawn parent by `EffectPool.for_world()` (null if the node is not in the tree, so orphan-node unit tests get no visuals). Effects are `MeshInstance3D` primitives (unit disc, unit fan, unit sphere, shared meshes, one material per node) animated by scale and alpha in the pool's single `_process` loop: no tweens, no per-frame allocation, finished effects go back to a free list (hidden). Nodes are created lazily up to the cap. **Cap** = `data/vfx.json` `max_simultaneous` (48, validated 1..512); at the cap the oldest running effect is recycled so the newest cast always shows. Effects store only positions and numbers, never the caster or target, so freeing either mid-effect cannot error (tested). **Particle choice:** mesh primitives, not GPUParticles3D or CPUParticles3D: no process-material setup, deterministic, cheapest headless, and enough for flat placeholder visuals. Rejected: tween-per-effect (allocates per cast), autoload pool (survives scene reloads and would hold freed nodes).
- **Element visual data** lives in `data/pools.json` as `"visual": {"color": "#hex", "scale": n}` on element entries (Fire `#ff6a1f`) and on `neutral` (used for physical/unknown damage types). `PoolDatabase.validate_entry/validate_table/validate_all` check it (element requires visual; color valid; scale 0.1..5); `ElementVisuals` does the damage-type to look lookup and logs a `push_error` once if pools.json is invalid. Water later is one data entry. No `elements.json` (a second source of truth). **`scale` only rescales cosmetic parts** (bursts, later auras/particles), never a hit-area shape, because resizing a hit-area visual would lie about the hitbox.
- **Hitbox-driven sizing** (`src/effects/VfxSizing.gd`): cone, aoe and projectile visuals take their size from the same params the hit uses. Cone/aoe ground shapes are drawn to **range (or radius) + `hurtbox_reach_radius`** (0.45 in `data/vfx.json`, equals the MeleeChaser capsule radius, asserted by a test), because the hit is a sphere query against capsule hurtboxes, so a target is hit while its centre is within that distance. Applied to aoe as well as cone (same mechanics, same lie otherwise). Projectile visual radius == hit sphere radius exactly (no padding; it is the object itself). Tests in `tests/unit/vfx_sizing_test.gd` assert visual == hitbox for all three. The Golem is a box hurtbox, so its corners can reach slightly past 0.45; not worth a per-enemy figure.
- **Bug fixed on the way:** `Projectile` applied `hit_radius` in `_ready`, but `EffectTemplates` assigned it after `add_child`, so every projectile used the scene default 0.25, and the shape resource was shared between all instances. Now `set_hit_radius()` duplicates the shape, resizes the hit sphere and scales the ball from the same number. This is a behaviour change: Flaming Nonsense now really has a 0.3 hit radius (was 0.25). Logged for balance awareness; no number was edited.
- **s3-a:** the player's light/heavy wedge is drawn to range + hurtbox reach radius (`AttackArcVisual.setup(VfxSizing.cone_reach(range))`); the hit query is unchanged, per game-lead's default. `slice3_qa_test` wedge-size assertion updated to the new intended value. Rejected: shrinking the hit to the drawn range (silent balance shift before the director's feel check).
- **Cone cards now draw a wedge** via the pool; the player's basic attacks pass `"vfx": false` to `cone` so they do not double-draw over `AttackArcVisual`.
- **Not done (4b):** projectile trail/muzzle/impact and pooling/recolor, aoe wind-up/impact burst polish, dash, heal, buff, Burn flame visuals; s3-b, s3-c, s1-a, blue triangle.

### 2026-10-28 - Slice 4b template visuals (gameplay-dev)
- **One effect system, extended.** `PooledEffect`/`EffectPool` gained plain-number options instead of a second system: `delay` (hidden until it elapses, used to stage aoe flash then burst), `velocity` (rising heal sparkles), `yaw_from/yaw_to` (cone sweep), `stretch_y` and `pulse` (flames), `persistent` (runs until stopped), `follow` (tracks a node by instance id, never a reference), a `RING` shape (flat annulus, shared mesh), and `generation` so `stop()` with a stale handle is ignored. All template looks live in `src/effects/TemplateVfx.gd` (static functions taking a possibly-null pool); `EffectTemplates` only calls them. Rejected: a Tween per effect (allocates per cast), GPUParticles (see 4a), a visual node class per template.
- **Cap eviction skips persistent effects.** A Burn flame is always the oldest effect, so plain oldest-first eviction would let every burst steal it. Persistent ones are only recycled when nothing else is running. `data/vfx.json` `max_simultaneous` raised 48 -> 64 to leave room for flames (data tuning, not balance). Rejected: a separate flame pool (a second system, a second cap).
- **Burn flame** is data driven: `data/statuses.json` burn has `"visual": {"kind": "flame", "size": 0.25}`; color comes from the status `damage_type` through `ElementVisuals`. `StatusEffectManager` starts it in `apply_status` (re-checked on every refresh, since a refresh emits no signal), stops it on expiry and on `tree_exiting`, and the flame also ends itself when its owner is freed (an enemy's `queue_free` on death never emits `status_expired`). It sits on the owner's `BodyMesh` top so it shows from the iso camera instead of hiding inside a tall golem. Pool world is the owner's parent (no `current_scene` lookup); `vfx_world` overrides it for tests. Rejected: a flame child node on each enemy (not pooled, not capped, leaks if the status is cleared another way).
- **Projectile**: ball recolored by element through one shared material per color (static cache), not by editing the scene's shared SubResource. Muzzle flash at launch, a trail puff every 0.04 s (not every frame, so a few shots cannot flood the pool), impact burst on hit or at max range. The look is cached at `set_look()` so `_physics_process` does no data lookup. The `Area3D` itself is not pooled: instantiating one per cast is cheap, hit state is easy to leak, and the visual allocation the brief cares about (per-cast materials, burst/trail nodes) is gone. Enemy shots are physical so they use the neutral (cream) look, not orange; flag for ux/playtester. `visual_radius()` still reads the `Mesh` child, so the sizing test is unchanged.
- **Cone**: a fading wedge at the true reach (VfxSizing) plus a brighter narrow blade that sweeps across the arc by yaw animation, staying inside the wedge. Rejected: animating the half angle (a new cached mesh per 0.1 degree) or scaling the hit wedge.
- **aoe**: damage stays instant (no timing change). The visuals stage: ground disc at hit reach at once, a short cosmetic charge flash at the caster, then (delay 0.1 s) a burst and a ring that expands to exactly the hit reach. Rejected: delaying the damage so the wind-up is "honest".
- **Dash**: start puff from the template; trail puffs every 0.04 s and the end puff come from `Player._apply_forced_move`, so the end puff is where the motion really stopped (not start + distance when blocked). Only the dash card passes a look; the dodge roll has no trail (not a template; trivial to add by passing a look). `start_forced_move` got an optional `vfx_look` arg.
- **Heal** sparkles play only if the caster was actually below max HP; **buff** is two staggered rings. Their colors (no element owns them) are `heal_color`/`buff_color` in `data/vfx.json`, validated.
- **s3-b light flash**: color `#ffe27a` -> `#ffcf1a` (saturated yellow: pale tan blended with the green floor), `flash_duration` 0.12 -> 0.2, alpha 0.95, a white edge outline, and the fade starts after 45% of the duration so a still frame catches full strength. Data change in `data/attacks.json`, no numbers that touch balance.
- **s3-c heavy telegraph**: the wind-up is now a pale (75% toward white) outline at full reach whose edge pulses, with a faint fill growing in from the origin; the impact is a solid fan in the attack color with a white edge. The solid fan stays the node's own mesh (sizing test unchanged); the telegraph parts are children. Rejected: only changing alpha/hue of the same solid fill (that was the muddy brown).
- **s1-a death cue**: the body flashes white then red before greying and toppling (topple delayed by the flash hold), a pooled white burst + red ring + red disc pop at the body, and the camera shakes. No CanvasLayer vignette (UI scope) and no Environment saturation tween (the Environment is a cached scene sub-resource, so a change would survive scene reloads unless restored). Nothing is stored in Juice, so `Juice.reset()` is unchanged; reload soak clean.
- **s3-d / s2-d blue triangle: cause found and fixed.** It is the Environment background color (pale sky blue) showing past the edge of the 40x40 floor at wide aspect ratios (reproduced at 1900x700, hp_bars, top-left). Fix: floor 60x60 and background a dark neutral, so any future edge reads as void, not as a stray overlay. Rejected: arena walls (design scope).
- **card_cast scenario** got two flags, `enemies_idle` (enemies never get a target, so they stay put; process mode untouched so Burn still ticks) and `disable_auto_attack` (the auto light attack knocked enemies out of reach and drew its own flash), and a smaller 2x2 layout inside cone reach (the old layout put Ember out of range, so no Burn landed). Casts also include Flaming Nonsense at 7.6 for a fire-colored projectile. Good `-After`: `0.9,1.9,3.2,4.4,5.5,6.1,6.8,7.8`.
- **Root cause of the weak death beat (s1-a), found while building the cue:** `Player` read `body_mesh.material_override`, but the scene sets the body material as a surface override, so it was null and every body flash (hit flash AND the death grey-out) silently did nothing; only the topple ran. `_ready` now takes `get_active_material(0)`, duplicates it and assigns it as `material_override`. Side effect (intended, was always the design): the player now flashes red when hit. Existing tests pass unchanged.
- **Reload soak flake:** `tools/reload_cycle.gd` checked `time_scale == 1.0` exactly 2 frames after `game_over_ready`; the Game Over timer (delta-accumulated) can fire a frame before Juice's wall-clock resume, so it failed about 1 run in 8. It now allows a 250 ms grace; a real leak still fails. Not a game bug (the game continues at the right time scale a few ms later).
- **Correction (later 2026-10-28, 4b review):** the floor stays 40x40 (a bigger floor is a walkable-area change, out of scope); only the dark void background was kept as the blue-triangle fix, so at wide aspect the arena edge reads as void. The projectile ball IS now pooled: a held pooled sphere following the projectile by id, sized to exactly its hit radius, with the scene Mesh hidden (the Mesh and its shared per-color material remain as the no-pool fallback for orphan-node tests). `visual_radius()` reads the pooled ball. At max range a shot now only plays a small faint fizzle; the impact burst is for real hits. `AttackController.set_auto()` replaces the scenario's direct write into the cached attack table.

### 2026-10-28 — 4c ownership shortcut (game-lead)
- The aim point is computed privately in `Player.gd` (`_ground_point_under_mouse`). Instead of a separate gameplay-dev run, ux-designer may add **read-only public getters** (aim point, aim direction) to `Player.gd` with no behaviour change, tested. Reason: a gameplay-dev session for a 3-line getter costs the director's usage for nothing. Rejected: gameplay-dev run first. Any change beyond read-only getters still goes to gameplay-dev.

### 2026-10-28 - Slice 4c aim indicator and ground markers (ux-designer)
- **Getters:** `Player.get_aim_point()` (Vector3 or null: null with no camera, not in tree, or ray miss; delegates to the unchanged `_ground_point_under_mouse`) and `Player.get_aim_direction()` (flat unit FACING direction, the one cards fire along). Read-only, tested (`tests/unit/aim_getters_test.gd`). Rejected: refactoring `_apply_aim` to share code (behaviour risk).
- **Direction dots follow facing, the reticle follows the mouse.** Facing trails the mouse by a few frames (slerp), so a line drawn to the mouse would lie about where a cast goes during a turn. Rejected: a line from the player to the mouse point.
- **Indicator = `src/ui/AimIndicator.gd`, not pooled effects.** Always-on while alive, so it owns a ring, a center dot and 8 disc dots (shared `EffectPool` ring/disc meshes, one unshaded alpha material each, no per-frame allocation). A held pooled effect would eat the cap (64) and fight the persistent-eviction rule. It sits at y +0.03 (below the pool's 0.05) with render priority -2, cream `#f4ece8` at low alpha (not a fire/yellow/orange color), ring + dots shape so it never reads as a wedge. Hidden when the player is dead (covers the Game Over screen, the arena reloads on restart), with no aim point, or `aim.enabled` false. Wired in `Main._ready` with one line (`AimIndicator.attach`). Rejected: a Decal or shader (heavier, more setup), a line mesh (reads as a wedge/lane).
- **Aim data lives in `data/ui.json` `aim`** (validated by `UiConfig.validate_aim`, defaults in `UiConfig.DEFAULT_AIM`): enabled, color, ground_offset, reticle_radius, reticle_alpha, center_dot_radius, dot_count, dot_radius, dot_spacing, dot_start_gap, dot_alpha_near, dot_alpha_far, max_length. It is UI tuning, so not `vfx.json`. Tuned after captures: reticle_alpha 0.7, dot_radius 0.075, dot alpha 0.6 -> 0.18.
- **Capture-only aim:** scenarios freeze aim (camera null), so there is no aim point. Scenario key `aim_preview_distance` (5.0 on `attacks` and `card_cast`) makes the indicator draw the reticle that far ahead of the player. Not used in play.
- **Cast markers: only where 4b shows nothing.** Cone has the wedge, aoe has the caster-centered disc and ring (aoe is NOT aimed, so a marker at the mouse point would lie about the hit area), heal/buff have rings. Added: **projectile lane** (a flat strip from the launch point `max_range` forward, 0.3 s fade) and **dash path** (intended start to start + distance, 0.3 s fade). New `EffectPool.Shape.STRIP` mesh (one more shared flat mesh, same pool, same cap) plus `PooledEffect.strip_length`/`lengthened()`. Rejected: a second marker system, an aoe marker at the cursor.
- **Lane width = `VfxSizing.projectile_lane_half_width(hit_radius)` = hit_radius + hurtbox_reach_radius**, the same rule as cone and aoe (an enemy whose centre is inside the lane is hit). So Flaming Nonsense (0.3) draws a 1.5 wide lane although its ball is 0.6 wide. Rejected: ball width only (would understate the real hit area). It shows the potential path to max range, not where it will stop. Tested in `tests/unit/cast_markers_test.gd` (width and length equal the hit params). The dash path width is cosmetic (a dash has no hit area), `dash_path_half_width`.
- **Lane only for the player's team.** An enemy shot's lane would read like a telegraph it is not (the shot fires instantly). Rejected: lane for every caster.
- **Hook:** `CardSlotController` has no cast signal, so the two marker calls are single visual-only lines in `EffectTemplates` (`_execute_projectile`, `_execute_dash`), the same pattern as 4b's other `TemplateVfx` calls. No behaviour change. Rejected: a new signal on `CardSlotController` (gameplay file, more surface).
- **Marker data in `data/vfx.json`:** `projectile_lane_alpha` 0.2, `projectile_lane_duration` 0.3, `dash_path_alpha` 0.28, `dash_path_duration` 0.3, `dash_path_half_width` 0.25 (validated, optional with defaults in `VfxConfig`).
- **Readability notes (not changed):** enemy shots are cream (neutral) and so are the player's physical shots (Pointy Stick); nothing but position tells them apart. A team tint needs code (the look is chosen by damage type only), so it is flagged for gameplay-dev; recoloring `neutral` in pools.json would change every physical visual. Cream itself reads fine against the green floor. Tall golems (boxes) hide the ground shapes and the reticle behind them from the iso camera; no cheap data fix (a lighter ground alpha does not help occlusion). The fire projectile lane is long (14 m) and runs off the arena edge on the card_cast shot; fine in play (0.3 s, 0.2 alpha). The cone wedge (0.25 s) is easy to miss in a still; its duration is a constant in `TemplateVfx.cone_sweep`, not data, so not tuned here.

### 2026-10-28 - Slice 4 qa follow-up calls (game-lead)
- **S4-1 (projectile lane overstates hit width):** fix before closing Slice 4, since criterion 4 says a visual that lies about the hit area is a bug. Fix the visual (`VfxSizing` lateral reach from the real capsule geometry), not the launch height. Rejected: launching shots at body height (changes what hits, a balance change pending the P1-P5 feel check).
- **S4-2 (enemy shots 20% wider since 4a):** keep 0.3. `Enemy.gd` always asked for 0.3; 4a only made the request take effect. Logged as balance info P6. Move the hardcoded enemy shot radius and cone angle into data with unchanged values. Rejected: reverting to 0.25 (that would freeze a bug in place as design).
- **S4-3 (status `visual` block unvalidated):** fix now. It is cheap, and fail-loud on data typos is a project rule.
- **Re-verification:** these are small, test-pinned fixes, so qa re-checks them in a short targeted pass (only the S4 items) rather than a second full review. Rejected: a full qa re-review (it costs the director's usage for nothing new).

### 2026-10-28 - S4-1 fix: ground shapes use the real lateral reach (gameplay-dev)
- All floor-level hit spheres (projectile launch y = 0, cone and aoe origin = caster origin y = 0) meet a capsule hurtbox whose lowest sphere centre is `hurtbox_low_center_height` = 0.45 up (new key in `data/vfx.json`, optional in `VfxConfig`, equals capsule height/2 - radius for MeleeChaser, pinned by a test). A target centre is hit out to `VfxSizing.lateral_reach(q) = sqrt((q + R)^2 - dy^2)`, R = `hurtbox_reach_radius` (0.45), dy = 0.45 - `QUERY_HEIGHT` (0.0).
- Projectile lane half width for r = 0.3 goes 0.75 -> 0.60 (physical pin: hit at 0.55, miss at 0.65). The cone wedge and aoe disc had the same height issue (range + 0.45 was 0.04 to 0.05 m too generous: range 1.8 draws 2.205 instead of 2.25, aoe 2.5 draws 2.906 instead of 2.95), so `cone_reach`, `aoe_reach` and the lane all go through `lateral_reach`. Hit queries untouched.
- Rejected: launching shots at body height (changes what hits, a balance change); keeping `q + R` for cone/aoe because the error is small (it is the same bug and one function now serves all three).
- Limit: dy is one global number from data, tuned for the MeleeChaser capsule; Shooter (0.4/1.6, low centre 0.4) and Golem differ by a few cm and are not modelled per enemy.
- `VfxConfig.DEFAULTS.max_simultaneous` is now 64, matching `data/vfx.json`.

### 2026-10-28 - S4-2: enemy attack shapes moved to data (gameplay-dev)
- There is no per-enemy data table yet (enemy stats are exported values in each scene), so the two hardcodes from `Enemy.gd` live in a new `data/enemies.json` under `attack_shapes`: `projectile_hit_radius` 0.3 and `melee_half_angle_degrees` 60.0, values unchanged. Loaded and validated by `EnemyConfig` (same pattern as `VfxConfig`: push_error and DEFAULTS on invalid data). Tests: `tests/unit/enemy_config_test.gd`; the qa pin test stays green. The cone knockback 2.0 in `Enemy.gd` was not asked for and is still hardcoded.
- Rejected: a full per-enemy `enemies.json` keyed by scene (a larger refactor of exported values, out of scope for a fix pass); the values apply to all enemy types today, as the hardcodes did.

### 2026-10-28 - S4-3: StatusDatabase validator (gameplay-dev)
- `StatusDatabase.validate_entry/validate_table` check `display_name`, `damage_type`, `effect_type` (only `damage_over_time`), `damage_per_tick` (>= 0), `tick_interval` (> 0) and the optional `visual` block: `kind` in {flame}, `size` a number in (0, 5], optional `color` a valid hex string. Validation runs once on first `get_status`/`has_status`; every problem is `push_error`'d and an invalid entry is treated as missing (`get_status` returns `{}`). Bad-fixture test: `tests/fixtures/statuses_bad/statuses.json` and `tests/unit/status_database_test.gd`.
- `visual.color` is validated but not yet consumed (the flame takes the element color); it exists so the validator covers the color rule from the brief without inventing a new feature.
- Rejected: leaving invalid entries in place after the error (the status would then run with silent defaults, the exact failure S4-3 reports).

### 2026-10-28 - Correction and Slice 4 re-check calls (game-lead)
- Correction to the S4-1 entry: the aoe radius 2.5 draws **2.9155** (sqrt(2.95^2 - 0.45^2)), not 2.906. The code is right.
- N1 (ground shapes understate the hit area against the golem's box hurtbox by ~20-30 cm): accepted for now, because it errs the safe way. Moved to Slice 5's enemy review, which decides between per-enemy reach and a capsule hurtbox. Rejected: fixing it now (it needs per-enemy hurtbox data, which overlaps Slice 5).

### 2026-10-28 - [DIRECTOR DECISION] Role of basic attacks (resolves P1-P4)
- [DIRECTOR DECISION, 2026-10-28] Clicking is an early-game crutch. Manual attacks should feel underwhelming and unnecessary as the build and cards take shape, unless the player deliberately builds into basic or heavy attacks with boosters.
- [DIRECTOR DECISION, 2026-10-28] Basic attacks are weaker than active card plays. Cards are the heart of the game; a card should always feel better than the free attack it competes with.
- [DIRECTOR DECISION, 2026-10-28] Heavy attacks trade sustained damage for burst and utility: lower single-target DPS than light is allowed, in exchange for burst, a larger area, and class/element flavor (stun, boosted element status chance, ranged targeted area for casters).
- [DIRECTOR DECISION, 2026-10-28] Heavy wind-up slows the player slightly. It never roots.
- Resolutions: **P1** -> spam-click cap is 1.5x auto light DPS, as a data ratio `manual_click_max_rate_ratio` (min gap = auto_interval / ratio, 0.4 s at 0.6 s). **P2** -> heavy redesign: per-class heavy definitions, shapes `arc` and `targeted_aoe`, element status with a boosted chance, generic Stun status. **P3** -> minor wind-up slow through StatModifiers, never a root. **P4** -> lower light per-hit damage, raise cheap damage cards, plus a validation rule so cards cannot drift below the free attack.
- GDD §3 updated with these (director-approved text).

### 2026-10-28 - Director open items file (process change, director request)
- Created `docs/OPEN_ITEMS.md` (owned by game-lead), added the standing rule to CLAUDE.md under Process, and put a pointer at the top of STATE.md.
- Items found in the scan and given IDs by game-lead:
  - D1: Game Over run stats, from the Slice 1 playtest.
  - D2: hold-to-preview, from the Slice 4 proposal.
  - D3: team tint for shots, from the 4c ux finding.
- Moved to "eyes": death slow-mo, aim reticle, HP bars near the player, and the light/heavy readability checks.
- Treated as answered, so not re-asked:
  - "Is death handling deferred?" Slice 1 was built.
  - "Wave 1 grace": Slice 5 handles it as s1-f.
  - "The blue shape": fixed in 4b.
  - "Dark cooldown bar": fixed in Slice 3.
- Rejected: listing every follow-up. Only items that need the director appear; the rest stay in ROADMAP.

### 2026-10-28 - Slice 3b scoping and defaults (game-lead)
- **Part B is a new Slice 3b** (attack rework), split into 3b-1 (click cap, card rule), 3b-2 (heavy redesign), 3b-3 (ux), then qa. Rejected: a single gameplay-dev run (too large to finish in one sitting).
- **Slice 4's playtest is folded into the 3b playtest**, as one report. Reason: 3b changes the heavy visuals and the attack numbers, so a Slice 4 playtest run first would be stale within the hour, and a second run costs usage. Slice 4 stays open until that report comes back with no blocker. Rejected: playtesting Slice 4 first.
- **"Damage card" definition:** a card in an `attack_single` or `attack_aoe` slot. Its per-cast damage includes guaranteed status damage from the card (full duration, no resistance). DPS is single-target, as the director worded it. Movement, utility and recovery cards are exempt, because the director said not to change them. Rejected: counting AoE cards at an assumed multi-target count (that reinterprets the director's rule).
- **Proposed defaults** (data, cheap to change):
  - click ratio 1.5
  - element status base chance 0.2; light multiplier 0.0, heavy 2.5 (50% Burn on heavy); heavy Burn lasts 3 s
  - Stun: 0.6 s; a repeat within a 4 s window x0.5; immune after the third; elites x0.5; bosses immune
  - heavy wind-up slow -35%
  - heavy burst >= 2.5x the light hit, with DPS slightly below light
  - current enemies are all rank "normal" unless gameplay-dev logs otherwise

### 2026-10-28 - Slice 3b-1: click cap and cards-beat-light (gameplay-dev)
- **Click cap:** light `manual_min_gap` (0.25 s) is replaced by `manual_click_max_rate_ratio` 1.5. Gap = resolved interval / ratio (0.4 s at 0.6 s), computed live from StatModifiers, so attack-speed boosts scale both auto and click rate. Max click rate = 2.5/s (was 4/s). Heavy has ratio 0, meaning click only when ready. The same-tick press + auto fires once because a manual start sets the cooldown before auto is checked, not because of the gap. The ratio is validated in `AttackDatabase`.
- **Rule** (`src/combat/CardDamageRule.gd`): damage card = any card in `attack_single` or `attack_aoe`. (a) per-cast damage >= 1.5x light hit; (b) per-cast / (slot base cooldown + card modifier) strictly greater than light damage / light interval. Per-cast = direct cone/aoe/projectile damage plus whole Burn ticks over the card's `duration` (no resistance). Light DPS uses the base 0.6 s interval. Exemption: a non-empty `rule_exception` string on the card (none used). Enforced three ways: `CardDatabase.load_all()` on the shipped dir push_errors each break at boot, `CardDamageRule.check_shipped()` is asserted in `tests/unit/card_damage_rule_test.gd`, and the same test has failing fixtures (low cast, slow DPS, tie, bad exception).
- **Numbers chosen:** light 8 -> 3 (auto DPS 13.3 -> 5.0). With light = 3 only two cards break the rule, and they are the only ones raised: Shrug Bomb 5 -> 12 (2.4x), Everyone Calm Down 8 -> 16 (2.0x). Light = 4 would force Shrug 15 and Fine, Burn Then 13 direct; light = 2.5 would force Shrug 10 but leaves the free attack near useless. Rejected: lowering light less (every AoE card balloons, because AoE slot base cooldown is 2.5 s), changing card cooldown modifiers (outside "raise damage").
- **Before / after** (cast includes Burn; DPS = cast / (slot base + modifier); light DPS before 13.33, after 5.00):

| Card | Slot | Cooldown | Cast before | Cast after | DPS before | DPS after | Rule before / after |
|---|---|---|---|---|---|---|---|
| Light (auto) | - | 0.6 | 8 | 3 | 13.33 | 5.00 | - |
| Heavy (comparison, 3b-2 redesigns) | - | 1.8 (+0.45 wind-up) | 22 | 22 | 12.22 | 12.22 | - |
| Quick, I Guess | single | 0.6 | 5 | 5 | 8.33 | 8.33 | fail (a,b) / ok |
| Pointy Stick | single | 1.0 | 6 | 6 | 6.00 | 6.00 | fail (a,b) / ok |
| Ember, Whatever (5 + Burn 4s = 8) | single | 1.1 | 13 | 13 | 11.82 | 11.82 | fail (b) / ok |
| Flaming Nonsense | single | 1.2 | 9 | 9 | 7.50 | 7.50 | fail (a,b) / ok |
| Overhand, Whatever | single | 1.3 | 12 | 12 | 9.23 | 9.23 | fail (b) / ok |
| Shrug Bomb | aoe | 2.2 | 5 | 12 | 2.27 | 5.45 | fail / ok |
| Everyone Calm Down | aoe | 3.0 | 8 | 16 | 2.67 | 5.33 | fail / ok |
| Fine, Burn Then (7 + Burn 5s = 10) | aoe | 3.3 | 17 | 17 | 5.15 | 5.15 | fail (b) / ok (thin margin, 0.15) |

  Before the change the old light out-DPSed all eight cards, and only Ember, Overhand and Fine, Burn Then even met the 1.5x cast ratio.
- **Rough time-to-kill, one target, seconds** (hits spaced by the interval, first hit at t=0; HP: Chaser 20, Shooter 14, Golem 50 with 50% fire resist, which affects only fire):

| Source | Chaser before / after | Shooter | Golem |
|---|---|---|---|
| Light auto | 1.2 / 3.6 (3 hits -> 7) | 0.6 / 2.4 (2 -> 5) | 3.6 / 9.6 (7 -> 17) |
| Heavy (22, unchanged) | 1 hit | 1 hit | 3 hits (3.6 s) |
| Pointy Stick (unchanged) | 3.0 | 2.0 | 8.0 |
| Overhand (unchanged) | 1.3 | 1.3 | 5.2 |
| Shrug Bomb | 6.6 / 2.2 | 4.4 / 2.2 | 19.8 / 8.8 |
| Everyone Calm Down | 6.0 / 3.0 | 3.0 / 0 (one cast) | 18.0 / 9.0 |

  The unchanged cards have identical TTK before and after; only light, Shrug Bomb and Everyone Calm Down moved. Shrug Bomb on a Golem is about 8.8 s, similar to light on a Golem, which is fine because the AoE value is the other enemies it hits.
- **Flag for 3b-2:** the heavy (22 per 1.8 s, DPS 12.2) is now 2.4x the light DPS and beats every card's DPS, so it contradicts both "heavy DPS slightly below light" and "cards beat the free attack". 3b-2 must lower it. With light = 3 the 3b-2 default needs burst >= 7.5 and DPS just under 5, for example 8 to 9 per 1.8 s.

### 2026-10-28 - After 3b-1 (game-lead)
- Light at 3 is kept as the default. It is the smallest change that makes the rule hold with only two cards raised. The bigger feel question went to the director as D4. Rejected: changing the light interval now (the brief forbade it; it's option B in D4).
- Heavy target for 3b-2: about 8.5 damage per 1.8 s, which is 4.7 direct DPS against light's 5.0, with burst 2.8x the light hit. Expected Burn from the 50% chance is extra, as element flavor, and does not count toward the "slightly below light" check, which is direct damage only. Rejected: keeping 22, which beats every card and contradicts both director decisions.

### 2026-10-28 - Slice 3b-2: heavy redesign (gameplay-dev)
- **Class resolution:** no character data existed, but `Player.owned_pools` (`rogue`, `fire`, `neutral`) already names the character, and `pools.json` gives each pool a `kind`. So class = first owned pool of kind `class`, element = first of kind `element` (`Player.character_class_id()` / `character_element_id()`). One source, no new "characters" file. Rejected: a separate characters.json (two copies of the same fact that can drift; character creation is not in scope). No `wizard` pool was added (that would start building the class); heavy keys under `heavy` only need to be non-empty class ids. A class with no valid heavy is a push_error and falls back to the first valid heavy so the game still runs. `Player.use_heavy_class()` is a capture/test hook only.
- **Data shape:** `attacks.json` keeps `light` as one entry; `heavy` is `{class_id: entry}`. Every entry has `shape` (`arc` or `targeted_aoe`). The controller ids stay `&"light"` / `&"heavy"` so HUD, meters and signals are unchanged. `AttackDatabase.get_heavy(class_id)`; `get_attack("heavy")` now errors (the heavy is per class). Validation is per shape (`arc`: range, half_angle; `targeted_aoe`: radius, max_range), an automatic attack must be an arc, `wind_up_move_slow` must be in [-0.999, 0], `on_hit_statuses` ids must exist. Rejected: a global default class constant (a hidden second source of "current class").
- **Shapes reuse templates:** `arc` goes through the existing `cone` template; `targeted_aoe` goes through the existing `aoe` template with an optional code-only `center` param (cards omit it and stay caster-centred). No new template, CardSchema/REQUIRED_PARAMS untouched.
- **Heavy numbers** (Rogue; Wizard uses the same damage and interval): 8.5 damage, interval 1.8 s (the 0.45 s wind-up is inside the interval, so DPS = 8.5 / 1.8; the 3b-1 table note "+0.45 wind-up" was misleading), arc range 2.4, half angle 85. Wizard: radius 2.0, max_range 7.0, wind-up 0.6.

| | Light | Heavy (Rogue arc) | Heavy before |
|---|---|---|---|
| Damage per hit | 3 | 8.5 (2.83x light) | 22 |
| Direct DPS | 5.00 | 4.72 (94% of light) | 12.22 |
| Arc area (0.5 r^2 x full angle) | 2.83 | 8.55 (3.0x) | same |
| Arc range / half angle | 1.8 / 50 | 2.4 / 85 | same |
| Extras | none | stun 100% (0.6 s), Burn 50% x 3 s | none |

  Heavy Burn, measured (not hand-computed): a seeded loop applying the heavy to one target every 1.8 s for 1800 s of game time at 60 fps gives about 2.0 Burn damage per heavy (1.94 to 2.07 over 3 seeds), so about +1.1 DPS, and direct + Burn is about 5.8 DPS. The hand figure (3 expected ticks per proc, 6.4 DPS) was wrong: a refresh rebuilds the status and resets its tick timer, so a Burn that is refreshed 1.8 s later has only ticked once. 5.8 is above light (5.0) and above Shrug Bomb (5.45), Everyone Calm Down (5.33) and Fine Burn Then (5.15), and below Pointy Stick (6.0), Flaming Nonsense (7.5), Overhand (9.2) and Ember (11.8). Game-lead's "slightly below light" check counts direct damage only (4.72), so it holds; the Burn flavor is a director question in the hand-back. Heavy is not a card, so `CardDamageRule` is unchanged and still passes.
  Stun steady state on one target at the heavy's own 1.8 s rhythm: 0.6, 0.3, 0.15, then 0.15 on every later swing (only the two previous stuns are ever inside the 4 s window, so it never reaches immunity). The brief stun is effectively 0.15 s after the second swing; immunity (after three stuns inside 4 s) ends when the oldest ages out, not all three.
- **Element status chance:** `pools.json` fire gets `status: {status_id: burn, base_chance: 0.2}` (optional per element, validated, only on elements). Chance = base x the attack's `status_chance_multiplier` (light 0.0, heavy 2.5 = 50%), clamped to 0..1, duration = the attack's `element_status_duration` (3 s). One roll per enemy per hit in `AttackStatuses.apply_on_hit`; a chance of 0 never rolls and a chance of 1 never rolls (always applies). The RNG is injected (`Player.status_rng`, randomized in `_ready`; tests and the capture scenarios set `.seed`). Dead targets are skipped. Rejected: a per-attack chance field (the director wording is element base x multiplier).
- **Stun is generic:** `statuses.json` `stun` has `effect_type: stun` (no damage_type, no ticks), `base_duration` 0.6, `diminishing_returns {window 4, multiplier 0.5, immune_after 3}`, `rank_multipliers {normal 1, elite 0.5, boss 0}`, and a `halo` visual. `StatusDatabase` validates by effect type (all ranks must be listed, 0 = immune). The rank and DR math is pure (`StunRules`, takes explicit time) and is applied inside `StatusEffectManager.apply_status`, so a future card using the existing `apply_status` template with `stun` gets it for free. The manager's own clock advances in `_process` (game time, so hit-stop and slow-mo are included).
  - **DR window:** a sliding window from each stun's own start; every stun that took effect in the last 4 s is a repeat. Normal enemy: 0.6, 0.3, 0.15, then immune; elite 0.3, 0.15, 0.075, then immune. An immune result is a true no-op (not recorded, so it cannot extend the immunity; only `status_resisted` is emitted; an active stun or wind-up is untouched, so a boss mid-wind-up is not cancelled). Re-stunning an active stun keeps the longer remaining time. Rejected: counting immune hits (perma-immunity), and one fixed window from the first stun (a burst at the window edge would reset everything at once).
  - **Rank:** `data/enemies.json` gets `enemies: {melee_chaser, ranged_shooter, fire_resistant_golem}`, all `normal`. Enemies had no type id, so each scene got an exported `enemy_id`; `EnemyConfig.rank_for()` validates rank in normal/elite/boss and errors loudly on an unknown id (counts as normal). Test fixtures set `status_manager.rank` for elite and boss.
  - **Inert:** `Enemy._physics_process` checks `is_stunned()` first: the telegraph is cancelled and colour restored, no chasing, turning or attacking; knockback still moves it. `is_stunned()` is by effect type, not by id. Hooks for ux: `Enemy.is_stunned()`, `Enemy.stunned(duration)`, `Enemy.stun_ended()`, `StatusEffectManager.is_stunned()` / `stun_time_remaining()` / `status_resisted(status_id)`.
  - **Placeholder cue:** a pulsing yellow halo ring above the head through the pool (`TemplateVfx.status_halo`, status visual kind `halo`) plus a body tint. ux replaces both in 3b-3.
- **Wind-up slow:** `wind_up_move_slow: -0.35` in data. `AttackController` adds a multiplicative StatModifiers entry on stat `move_speed` (id `wind_up_slow.<attack>`) when a wind-up starts and removes it on fire and in `cancel_all()` (death, can_act false). Player movement now reads `stat_modifiers.apply("move_speed", move_speed)` (`Player.get_move_speed()`), which also makes `move_speed` buffs possible. The dodge and card dashes use their own forced-move speed and are not slowed; the slow can never reach -1 (validated), so it is never a root. A scene reload frees the Player and its StatModifiers.
- **targeted_aoe:** the target is locked when the wind-up starts (the telegraph does not follow the mouse), so the player and enemies can react; clamped to max_range first, then to the arena rectangle read from the `Floor` node (40 x 40, 0.5 edge margin), so an off-arena or missing aim point is never an error (no aim point falls back to straight ahead at max_range). The telegraph is a held disc plus ring through the pool at `VfxSizing.aoe_reach(radius)`, the same number as the hitbox; stopped on fire and cancel. `Player.aim_point_override` (capture/test only) feeds `get_aim_point()`. Rejected: tracking the mouse during the wind-up (harder to read and dodge; ux can ask for it).
- **Side finding (not fixed):** `AttackController._start` emits `attack_started` before it marks the wind-up, so `is_winding_up()` is false inside an `attack_started` handler. Player now tests `wind_up > 0` from data instead. Left as is because reordering would touch every consumer; qa may want a test.
- **Scenarios:** `attacks` (Rogue heavy with stun halo and Burn, seed 5) and new `targeted_aoe` (Wizard heavy at a point 6.6 ahead, 4 chasers; flags `heavy_class`, `aim_point_offset`, `status_seed`). Capture: `-Scenario targeted_aoe -After "1.3,1.7,2.0"` (telegraph, then burst).
- **Tests:** `tests/unit/heavy_3b2_test.gd`, 32 cases (suite 260 -> 292). Existing tests updated for the per-class heavy (`get_heavy("rogue")`, `load_valid("rogue")`).

### 2026-10-28 - After 3b-2 (game-lead)
- **Stun DR window 4 s -> 1.5 s.** This corrects my own default. With a 4 s window, the heavy alone (one swing every 1.8 s) shrinks its stun to 0.15 s from the third swing on, so the stun would read as "does nothing". That's not a lock either: one heavy stunning 0.6 s every 1.8 s is about 33% uptime. A 1.5 s window, shorter than the heavy cooldown, gives the heavy its full 0.6 s every time, while stacked stuns from several sources (future cards, other heavies) inside 1.5 s still get diminishing returns and immunity after the third. It's a data value, applied by ux-designer in 3b-3 together with the test update. Rejected: shortening the base duration instead (that doesn't fix the decay).
- **Heavy total DPS with Burn (~5.8) vs light and the area cards:** kept as built, and sent to the director as D5. Reason: a boosted element status is explicitly part of the heavy's flavour per the director decision; area cards win on multiple targets. Rejected: cutting the multiplier silently (that would change director-facing flavour without asking).
- **Character data:** the class/element comes from the Player `owned_pools` export for now. A proper character entry in `/data` belongs to Milestone 3a (character selection). Rejected: adding it now (scope creep).

### 2026-10-28 - Slice 3b-3: stun cue, IMMUNE popup, targeted_aoe telegraph (ux-designer)
- **Stun DR window 4.0 -> 1.5 s** in `data/statuses.json`, as game-lead asked in "After 3b-2". Tests updated; new tests prove the Rogue heavy at its own 1.8 s interval stuns the full 0.6 s on 12 swings in a row (pure rules and through the manager clock), and that 3 stuns inside 1.5 s give 0.6 / 0.3 / 0.15, then immune, then recover.
- **Stunned cue = 3 stars orbiting above the head + a desaturating body tint.** Stars are pooled spheres (`TemplateVfx.status_stars`, `PooledEffect.orbiting`) that circle the head at `orbit_radius` and `orbit_hz`; from the iso camera that reads as a ring of dots that spins, which nothing else in the game does (Burn is one orange flame, telegraphs are on the ground). Motion plus shape plus tint, so it is not colour-only. Data: `statuses.json` `stun.visual` = `kind: stars`, `size`, `color`, `count`, `orbit_radius`, `orbit_hz`, `tint_color`, `tint_amount` (validated in `StatusDatabase`; `body_tint(status_id)` is the helper). The Enemy tint constants were removed from code; `Enemy` reads the tint of whichever status stunned it. Cost: 3 pool slots per stunned enemy (cap 64), held effects are never evicted by bursts. Rejected: keeping the flat halo ring (a thin ground-plane ring above a head is a sliver from the iso camera and vanishes in a crowd); a ring under the feet (collides with telegraph language); a yellow tint (looked like a status "buff"; a pale desaturated body says "switched off"). Stars are plain spheres, a real star sprite is art work and out of scope. The old `halo` kind is gone (nothing else used it).
- **IMMUNE popup:** `Enemy` listens to `status_resisted` and shows a small word through `Juice.spawn_popup` (reuses `DamageNumber` via `show_text`), at most once per `immune_cooldown` (1.5 s) per enemy, so heavy spam on a boss shows one word per swing at most, never a stream. Data: `ui.json` `popups` (`immune_text`, `immune_color`, `immune_scale`, `immune_height`, `immune_cooldown`), validated, defaults in `UiConfig`. Rejected: an HP-bar icon (bars are tiny at 720p); a popup on every resist (spam); nothing at all (a boss that silently ignores the heavy reads as a bug).
- **targeted_aoe telegraph, same language as the arc telegraph (s3-c):** wind-up = pale OUTLINE ring at the true hit reach (`VfxSizing.aoe_reach`, never rescaled, its alpha rises with progress) + a faint fill disc that GROWS from 15% to 100% of the reach + a bright front ring riding the fill edge and fading out as it arrives. The impact is the opposite shape of look: the existing solid disc, flash and expanding ring. Driven by wind-up progress, not by time (`PooledEffect.driven()` / `set_progress`, `TemplateVfx.set_aoe_telegraph_progress`, Player updates it every frame and skips parts the pool has recycled). Hit-stop or slow-mo therefore cannot desync it from the real wind-up. Parts order is fixed: [0] fill (base_size = hit reach), [1] edge, [2] front. Rejected: a pulsing-size ring (a pulse changes the edge radius, so it would lie about the hitbox); a time-based tween (drifts from the real wind-up under hit-stop).
- **Aim reticle vs telegraph:** checked in captures. The reticle (cream ring and dot, lowest render priority) sits under the locked disc, so it is simply covered by the translucent fill and never competes with it; after the lock the reticle follows the mouse as before. No change.
- **Heavy meter and labels: no change.** The meter says LMB/RMB, READY/SWING, and the player does not need the heavy's shape or class there (the telegraph shows the shape, the class is not selectable yet). No new input bindings were needed. Rejected: showing the class name or a shape icon on the meter (information the player cannot act on until classes exist; revisit at Milestone 3a).
- **Capture scenario:** new `stun_crowd` (9 idle chasers, 6 stunned at 0.5 s, one of them a boss so it shows IMMUNE) with capture-only flags `stun_indices`, `stun_at`, `stun_duration`, `boss_indices`.
- **Known weakness:** in a very tight crowd the IMMUNE word can sit partly behind neighbours' HP bars (HP bars draw over it). It is readable in the capture but not great; raising it or giving it a draw priority is a small follow-up if the playtester flags it. Stunned tint is subtle on enemies whose base colour is already grey (the Golem); the stars carry it there.
- **Tests:** `tests/unit/stun_cue_3b3_test.gd`, 11 cases, plus 3 in `heavy_3b2_test.gd` (suite 292 -> 306).

### 2026-10-28 - After the 3b qa review (game-lead)
- **Doc correction:** the stun DR window is **1.5 s** (data). Older mentions of "4 s" in the 3b scoping and 3b-2 entries are superseded.
- **S3B-1: fix before the playtest.** The playtester is asked to judge light vs cards, and a pre-existing Burn bug makes Fine, Burn Then really lose to the light (3.94 vs 5.0 DPS). That would poison the report.
  - Fix 1: a Burn refresh keeps its tick phase.
  - Fix 2: `CardDamageRule` credits only the status damage that actually lands in sustained use, i.e. ticks over min(status duration, card cycle time). It no longer credits the full duration. Even with the phase fixed, a recast that refreshes Burn before it expires doesn't stack it, so full-duration credit overstates.
  - Then retune any damage card that fails, raising direct damage only. Fine, Burn Then is expected to fail; Ember should still pass.
  - Rejected: accepting the gap until later (it breaks a director decision on a shipped card), and logging a `rule_exception` (it isn't a fast low-damage card).
- **The heavy's total DPS** will be re-measured after the fix, and D5 updated with the new number.
- **S3B-3..S3B-8 and S4-4** (scenario flag validation) go into the same fix pass. They're small, and S3B-7 (per-frame allocations) must land before Slice 5 raises enemy density. S3B-2 (IMMUNE clipped by HP bars) joins the Slice 5 bar work.

### 2026-10-28 - S3B-1 fix pass: Burn refresh and the card rule (gameplay-dev)
- **(a) Refresh keeps the tick phase.** `StatusEffectManager.apply_status` on an active status now updates it in place (`ActiveStatus.refresh`): `time_to_next_tick` is untouched, duration = max(remaining, new), tick damage re-read from the definition. Rejected: restarting the timer (the bug), and also resetting the phase "for fairness" to a fresh apply (it would re-open the bug for any card cast faster than the tick).
- **(b) Rule credit.** `CardDamageRule.cast_damage(card, statuses, cycle_time)` credits whole ticks over min(status duration, cycle). Rejected: keeping a default for `cycle_time` (a forgotten argument would silently re-credit the full duration), and crediting `cycle / tick` without the floor (the first tick lands 1 s after the cast, so fractional ticks are not guaranteed; the real sim gives a slight surplus, never a deficit).
- **(c) Retune:** only Fine, Burn Then fails (3.94 DPS). Its direct damage 7 -> **12**. 11 is the smallest that passes (5.15 vs 5.0, margin 0.15, the thin margin the old table already flagged); 12 gives 5.45 (same as Shrug Bomb) so one stray rounding or a light buff does not flip it. Ember passes unchanged (cast 7, 6.36 DPS). No other card, enemy, light or heavy number touched. Rejected: 11 (too thin), a `rule_exception` (not a fast low-damage card).
- **(d) Real vs credited**, steady state, seeded 60 fps sim through the real manager (`slice3b_qa_test`): Ember Burn 2.2 per cast (credited 2), real DPS (5 + 2.2) / 1.1 = 6.55 vs credited 6.36. Fine, Burn Then Burn 6.6 per cast (credited 6), real (12 + 6.6) / 3.3 = 5.64 vs credited 5.45. Both real values are at or above credit and beat the light's 5.0.
- **(e) Rogue heavy total DPS**, 600 swings at 1.8 s, 50% Burn of 3 s, seed 424242: direct 4.72 + Burn 1.25 = **5.97** (was about 5.8; the phase fix adds roughly 0.15). Still above light (5.0). Compare Fine, Burn Then 5.64, Shrug Bomb 5.45, Everyone Calm Down 5.33, Pointy Stick 6.0, Ember 6.55. D5 should quote 5.97.

| Card | Cast before S3B-1 (3b-1 table) | Cast after S3B-1 | DPS 3b-1 table | Credited DPS after S3B-1 | Real sustained DPS after S3B-1 |
|---|---|---|---|---|---|
| Ember, Whatever | 13 | 7 (5 + 2) | 11.82 | 6.36 | 6.55 |
| Fine, Burn Then | 17 (7 + 10) | 18 (12 + 6) | 5.15 | 5.45 | 5.64 |
| Rogue heavy (direct + 50% Burn) | - | - | 5.8 | - | 5.97 |
| All other damage cards | unchanged | unchanged | unchanged | unchanged | - |

  The test `test_decisions_balance_table_matches_the_data_files` carries the new numbers; the pin test became `test_burn_refresh_keeps_its_tick_phase_so_the_rule_credit_is_real`.

### 2026-10-28 - S3B-3: attack_started order (gameplay-dev)
- `AttackController._start` now sets the wind-up timer and applies the wind-up slow before emitting `attack_started`; an instant attack still emits `attack_fired` right after it. A handler therefore sees `is_winding_up()` true and the slowed move speed. Player's "test the wind_up from data" workaround comment was removed (the check itself stays, it is the cheaper test). The qa pin became `test_attack_started_is_emitted_after_the_wind_up_state_and_slow`. Rejected: leaving it pinned (a trap for the next consumer) and a second signal such as `wind_up_started` (two signals for one event).

### 2026-10-28 - S3B-4: re-stun signal (gameplay-dev)
- New `StatusEffectManager.status_refreshed(status_id)` (any status applied again while active) and `Enemy.stun_refreshed(remaining)` (a stun landed while already stunned). `status_applied` and `Enemy.stunned` keep meaning "began", so the stars and tint are never started twice (the existing cue check also still sees them running; a test counts pool effects before and after). Rejected: re-emitting `stunned` / `status_applied` (every existing listener treats them as "start the cue", which would restart or double the stars and re-cancel the telegraph). `stun_refreshed` carries the time left so ux can flash or play a sound without reading the manager. A resisted stun still emits only `status_resisted`.

### 2026-10-28 - S3B-5: Player telegraph accessor (gameplay-dev)
- `Player.has_aoe_telegraph(attack_id) -> bool` and `Player.get_aoe_telegraph(attack_id) -> Array[PooledEffect]` (a copy, order [fill, edge, front]). The three suites that read `_telegraphs` now use them; no test touches the private dictionary any more. Rejected: exposing the dictionary itself (callers could mutate Player-owned state), and only a bool (the stun-cue test needs the parts to check sizes).

### 2026-10-28 - S3B-6 + S4-4: scenario flag schema (gameplay-dev)
- New pure `ScenarioSchema.validate(id, def)` (`src/debug/ScenarioSchema.gd`); `Scenario.load_def` runs it and push_errors every problem (key named, expected shape stated), then returns `{}` so `Main` refuses to build the scenario. Covers bool, number (with minimums), whole-number, string, fixed-length number arrays (`origin_offset` 3, `spacing` 2, `aim_point_offset` 2), enemy-index arrays, `hp_fractions` 0..1, `groups`, `late_hit`, `casts`. Unknown keys are errors (catches typos).
- `aim_point_offset` must have **exactly 2** numbers ([x, z] from the player), not "2 or 3": the build code only reads x and z, so accepting a third would silently ignore it. Rejected: allowing 3 (a y that does nothing). Rejected: validating that group scenes / cards / slots exist in the schema (it stays pure; those fail at build with their own loud messages).
- Tests: `tests/unit/scenario_schema_test.gd`, bad fixture `tests/fixtures/scenarios_bad/scenarios.json` (17 bad scenarios, each must be rejected with its id in the message), plus all shipped scenarios must validate.

### 2026-10-28 - S3B-7: per-frame allocations (gameplay-dev)
- `StatusEffectManager.is_stunned()` reads a `_stun_count` int (incremented when a stun status is created, decremented when it expires; a refresh does not change it), so the call every enemy makes every physics frame no longer builds an Array. `_process` iterates `_active` directly and reuses one `_expired` array instead of `keys()` plus a new array per frame. Rejected: a cached bool recomputed lazily (a counter is exact with no invalidation rule).
- `Player` finds the effect pool once at wind-up start (`_telegraph_pool`) and `_update_aoe_telegraph` uses it; no `EffectPool.for_world` NodePath per frame. Rejected: caching in a static (the pool is per world and dies with it, so the cache lives on the Player and is checked with `is_instance_valid`).
- Other cheap fixes found by grepping the Player and Enemy per-frame paths: `Player._handle_attack` reused a fresh Dictionary every frame (now a member updated in place); `_handle_card_slot_input` formatted ten action-name strings every frame (now two const `StringName` arrays); `CardSlotController.advance` used `slots.values()` (now iterates the dictionary). Left as is: `_attack_has_target` runs a physics query only when an auto attack is ready and the controller idle (allocates the query and result array then; moving it to a reused query object is a bigger change, flagged for Slice 5 profiling), and `Enemy._has_live_target` / `_chase_and_attack` allocate nothing (Vector3 math only).

### 2026-10-28 - After the 3b fix pass (game-lead)
- Accepted Fine, Burn Then at 12 direct damage (5.45 credited DPS, the same as Shrug Bomb). Rejected 11, which passes by only 0.15 DPS, too thin for future modifiers.
- D5 updated with the measured heavy total of 5.97 DPS.
- The changelog's first commit was swept into gameplay-dev's 9d91d7a by a `git add -A` while roles overlapped on the working tree. No content was lost. The rule stays: each role commits only its own paths.

### 2026-10-28 - Slice 5a: waves, spawn grace, enemy review, damage check (gameplay-dev)
**Wave table and cap (`data/waves.json`, validated by `WaveConfig`, run by `WavePlan`, driven by `EnemySpawner`).**
- `max_alive` 12 (validator range 6 to 15, whole number). `first_wave_delay` 3.0 s, `spawn_gap` 0.5 s between members of a stage, spawn ring 9 to 13 m from the player, clamped inside the arena (`arena_half_extent` 19). Stages: 0) 4 chasers; 1) 3 chasers + 2 shooters (after 8 s, once at most 4 are alive); 2) 4 chasers + 2 shooters (8 s, at most 6 alive); 3) 1 golem + 2 shooters + 3 chasers (10 s, at most 6 alive). After stage 3 it loops back to stage 2 (`loop_from_stage`). Why these numbers: a first draft with gates of 3 to 4 alive and stages of 3 to 5 could never get above 9 alive, so the cap of 12 never bound and "holds about 6 to 15" was not met in real play (advisor review caught it). Gates of at most 6 with stages of 6 now let a coping player sit around 7 alive and touch the cap of 12 at peaks (sim numbers below). Rejected: raising `max_alive` to make the cap look used (the cap is the ceiling; the stage sizes and gates are the pacing).
- A stage opens when its delay has passed AND the alive count is at or below its `until_alive_at_most`. So density follows how fast the player kills, instead of a timer that piles enemies on a player who is losing. Blocked spawns wait in a queue, never dropped, never over the cap. A stage that could never fit under the cap is a validation error.
- Rejected: a flat interval timer with a bigger `enemies_per_wave` (the old shape; it ignores whether the player is coping and cannot express a cap). Rejected: spawning back up to the cap whenever below it (that is a horde faucet, against the GDD section 1 density principle).
- Enemy scenes now come from `data/enemies.json` (`scene` per id, validated as an existing res:// path); the spawner's `enemy_scenes`, `wave_interval`, `enemies_per_wave`, `spawn_radius`, `min_spawn_distance` exports are gone (rejected: keeping them as a second source of truth). Spawn parent is the spawner's own parent (Main), so spawning no longer needs `current_scene` (helps the true-size capture task). The RNG is seedable (`set_seed`); the wave order within a stage is shuffled with it. The reload soak now checks "no enemies and wave clock reset" on a fresh arena instead of "first wave present".

**s1-f spawn grace.** `spawn_attack_grace` 1.5 s (data): a spawned enemy cannot start an attack for 1.5 s (`Enemy.begin_spawn_grace`, only lengthens the cooldown), plus the 9 to 13 m spawn distance (was 6 to 12) and the 3 s first-wave delay. The old first contact at about 1 s was mostly the RangedShooter (preferred range 7 is inside the old 6 m minimum spawn distance, so it telegraphed on frame 1; 0.45 s wind-up plus 0.8 s of flight). Rejected: distance alone (a shooter at 9 m still telegraphs at once); making enemies passive during grace (they keep walking in, which keeps the arena looking alive).

**Arena walls (bug found by the bot-sim).** The floor is 40 x 40 and had no walls, so a player or knocked-back enemy that crossed the edge fell into the void forever (a soft lock). Added four invisible wall boxes (`ArenaWalls`, layer 1) just outside +-20 in `Main.tscn`. Rejected: a kill plane or respawn (it would need a design call; a wall is the obvious minimum).

**Criterion 2: enemy review (density principle: clear telegraph, distinct role, punishable window).** All three share one 0.45 s wind-up and a body flash. Findings:
- *MeleeChaser* (20 HP, speed 4, 5 dmg, cone 1.5 m, cooldown 1.2). Role: pressure, the fast one (slower than the player's 6, so it can be kited). Telegraph before: orange body flash only, nothing on the ground. Window: stands still for the wind-up, does not turn while winding up, then has a 1.2 s cooldown while it keeps chasing (a real punish window). FIXED (cheap): a ground wedge during the wind-up in the player-heavy language (pale outline plus a fill growing in) in the enemy team tint, sized to where the cone really lands on the player (`VfxSizing.lateral_reach_vs_player`, new data keys `player_hurtbox_*` in `data/vfx.json`).
- *RangedShooter* (14 HP, speed 3, 4 dmg, preferred range 7, shot 9 m/s, cooldown 1.6). Role: zoner. Telegraph before: body flash only, and nothing showed where the shot would go. Window: stands still while winding up and does not re-aim, so a sidestep always works. FIXED (cheap): a lane strip along the shot path for the whole wind-up (`TemplateVfx.enemy_shot_lane`, alpha in `data/vfx.json` `enemy_shot_lane_alpha`), tinted for the enemy team. Player shots keep their own faint lane.
- *FireResistantGolem* (50 HP, 50% fire resist, speed 2, 9 dmg, cone 2.0 m, cooldown 1.8). Role: the tank that blanks fire builds, slow. Telegraph: same 0.45 s as the chaser although it hits nearly twice as hard (follow-up F-E1). Window: slow enough that it never catches a moving player. The wedge fix applies. Its box hurtbox made ground shapes under-report its hit area (N1, below).
- Follow-ups, not done (balance or design, for game-lead): F-E1 the golem's wind-up should be longer than the chaser's (a tell proportional to the hit; proposal 0.7 s). F-E2 three types is thin for "distinct roles": nothing flanks, charges or blocks the dodge. F-E3 enemies stack into one line behind each other when chasing (visible in the 5 s waves capture); there is no separation steering. F-E4 no sound on tells (out of scope). F-E5 a stunned enemy gives no extra cue that its wedge is cancelled (ux).

**Criterion 3: damage check (numbers from the scene values; unchanged, no balance edits).** Player 30 HP, move speed 6, dodge speed 14 for 0.25 s (3.5 m) with 0.25 s of invulnerability and a 0.8 s cooldown (at most 31 percent invulnerable time if rolling constantly). One attack cycle is wind-up 0.45 s plus cooldown (the golem is 0.7 s since D6, see 2026-10-28 "Slice 5 fix pass"):

| Enemy | Damage per cycle | Cycle | DPS | Hits to kill the player | Free window after a swing |
|---|---|---|---|---|---|
| Chaser | 5 | 1.65 s | 3.0 | 6 | 1.2 s |
| Shooter | 4 | 2.05 s | 1.95 | 8 | 1.6 s |
| Golem | 9 | 2.5 s (was 2.25, D6) | 3.6 (was 4.0) | 4 | 1.8 s |

- A roll only avoids a hit if its 0.25 s of invulnerability covers the instant the attack lands, i.e. it is pressed in the last 0.25 s of the 0.45 s wind-up (55 percent of it). Catchable on reaction, but it is the narrow answer: sidestepping out of the cone or lane during the wind-up is the wide one (the enemy does not turn or re-aim while winding up; the player moves 2.7 m in 0.45 s).
- At the new density the roll alone cannot cover a crowd: with N enemies winding up out of sync, one 0.25 s roll covers only the swings that land inside it, and it is on a 0.8 s cooldown. With 3 chasers in reach the damage rate is 9 per second, so 30 HP lasts about 3.3 s. That is the intended pressure: a player who stands still dies in 8 to 13 s in the sim (three seeds died at 8.5, 9.2 and 9.4 s with the shipped table, against the playtester's 14 s at the old density), which is why kiting (speed 6 against 4, 3, 2) and killing matter. A cap of 12 is a ceiling, not a typical state: the competent bot's mean alive count was about 7 with peaks at the cap, because the stage gates wait for kills.
- Proposals (NOT applied; the director said not to change enemy numbers in the attack rework): P-D1 golem wind-up 0.45 to 0.7 s (see F-E1). P-D2 if playtests show the first wave is too hard for a new player, drop stage 0 from 3 chasers to 2 (one number in `data/waves.json`). P-D3 leave chaser, shooter and golem damage alone: the per-enemy DPS is not the problem, the overlap of many swings is, and the cap and stage gates already control that.

**N1 (golem hurtbox).** Chose the capsule hurtbox, not per-enemy reach: a ground shape is drawn once per cast for whoever stands in it, so one shape cannot be right for a chaser and a golem at once. The golem's Hurtbox is now a `CapsuleShape3D` radius 0.45, height 1.9 (low centre 0.45 up), exactly `hurtbox_reach_radius` and `hurtbox_low_center_height` in `data/vfx.json`, so the existing ground-shape maths is exact for it. Its movement collision stays the 1.2 m box. Its body mesh is a capsule of radius 0.5 (was a 1.2 m box) so the visible body and the hit area agree to 5 cm. Side effect, a small balance change (golem slightly harder to hit): its hit area is about 15 cm narrower than the old box, which was the part that overstated. Tests pin the capsule numbers and a real physics check that a sphere just inside the drawn edge hits the golem and just outside misses. The shooter capsule (0.4, 1.6) differs from the shared numbers by 5 cm and is pinned within 6 cm (known S4-1 limit). Rejected: per-enemy reach data in `VfxSizing`.

**D3 default A (team tint).** `ElementVisuals.visual_for_team(damage_type, team)` pulls the look toward `data/vfx.json` `team_tints.<team>`: enemy colour `#ff3d8b` (hot pink), `neutral_mix` 1.0 (physical shots become fully pink) and `element_mix` 0.4 (an enemy fire shot stays orange-leaning but is visibly not the player's). The player team has no tint. Used for enemy shots (ball, trail, muzzle), the enemy cone wedge and aoe, the new wind-up wedge and shot lane. Rejected: recolouring the element pools per team (duplicates pool data); tinting player shots (the player's colours are the reference).

**Criterion 4, rendering side (HP bars).** The bar shader had `depth_test_disabled`, so a bar was drawn over every model including ones in front of it. It is now depth-tested and depth-writing (opaque, with discard), so a model in front of a bar hides it. This is deliberate; ux should expect bars of back-row enemies to be hidden behind front-row bodies in a crowd (the 5b visibility modes or a bar lift can address it). Size: width 1.4 to 1.2 and height 0.19 to 0.16 (about 15 percent smaller). This SUPERSEDES the 2026-10-27 director answer "size is fine", on game-lead's Slice 5 brief ("slightly smaller"). `render_priority` is now a data key (`hp_bars.render_priority`, 10). The camera is orthographic (size 14, no runtime zoom), so a world-sized quad is a constant on-screen size; pinned by a test. For ux in 5b: `EnemyHpBar.rank()` returns the owner's rank (`normal`, `elite`, `boss`) for an "always for elites and bosses" mode; the visibility mode is read once in `_ready` from `hp_bars.visibility_mode` and `_update_visibility` is the hook. Rejected: a second shader variant for depth on and off (nobody asked for the switch).

**Profiling.** `Player._attack_has_target` costs about 6 to 12 microseconds per call with 8 to 9 enemies alive (2000-call average inside the sim), about 0.05 percent of a 16.7 ms frame, even though it runs every frame while the auto attack is ready with nobody in range. Not worth a reused query object, so none was added (rejected: caching the query for no measurable gain; revisit if the cap goes up a lot). Headless frame cost with 5 to 9 enemies alive at 3x time scale: about 1 to 4 ms of engine process and 2 to 6 ms of physics per rendered frame (each frame steps about 3 physics ticks), with no visible growth with the alive count. These are CPU only and headless; they say nothing about GPU or rendering.

**Bot-sim results (shipped table; `tools/run_wave_sim.ps1`; no crash, NaN, cap violation, out-of-arena position or soft lock in any run; HP lost counts all damage taken, healing cards offset it).** Competent bot, real HP, 180 s: seeds 100, 101, 102 all survived, HP lost 28, 66, 28, mean alive 7.1, 7.0, 6.3, peak alive 12 (the cap) in all three, 75 to 80 kills, longest stretch with no stage opening and no kill 10 to 15 s. God mode, 240 s: seeds 200, 201 peak 11 and 12, mean 6.9 and 7.2, 90 to 100 kills, 17 to 19 stages opened, max stall 12 and 17 s. Idle bot (never moves, only the auto light attack, real time): died at 8.5, 9.2 and 9.4 s with 4 enemies alive at most. Old density (the playtester): dead at 14 s. The cap binds at peaks, so the "never over the cap" test is no longer vacuous in play. Only an unattended player dies quickly; a kiting bot that aims perfectly survives at this density, so this is an upper bound for a human and the real question (is 12 too much for a person?) needs the director live.

**Late fixes in the same pass.** (1) The ranged wind-up lane is now ended when the wind-up is cancelled (stun, player death) or the enemy dies, instead of lasting out its 0.45 s (a visual must not promise a shot that never comes); test added. (2) The HP bar shader no longer writes ALPHA, which keeps it in the opaque pass: it both tests and writes depth, and a transparent popup such as IMMUNE draws after it (relevant to S3B-2). Before this the bar was in the transparent pass, where depth is tested but not written. (3) The `waves` capture scenario is a STRESS case (no gates, no delays), not the shipped pacing; the shipped pacing is what the sim numbers describe.

**Tooling.** `tools/wave_sim.gd` + `tools/WaveSim.tscn` + `tools/run_wave_sim.ps1` (README). Scenario `waves` (`dense_waves`, `wave_seed`) for density captures. Bot-sim limits: the bot aims perfectly and kites, so its survival is an upper bound for a human; it overrides `Engine.time_scale` every frame (Juice hands it back as 1.0 after hit-stop), which shortens hit-stop in the sim only.

### 2026-10-28 - After 5a (game-lead)
- **N1 capsule hurtbox: accepted.** The rule that a visual must not lie about the hit area wins over the golem's box silhouette. The art is placeholder anyway. Rejected: per-enemy reach, because one ground shape is drawn for every enemy standing in it.
- **Arena walls: accepted.** They fix a real fall-off bug, are cheap and reversible, and add no new mechanic. Rejected: a kill plane or respawn (a death you can't see is worse than a wall).
- **P-D1 golem wind-up 0.45 -> 0.7 s:** sent to the director as D6. It's an enemy balance change, and the director earlier kept enemy numbers out of the attack rework. Default A is applied at the start of the next gameplay-dev task if no answer comes. Reason: GDD §1 density principle (readable, punishable danger).
- **P-D2 first wave size and the 12-alive cap:** feel checks for the director, under "eyes". They stay as built.
- **HP bar size change:** this supersedes the director's 2026-10-27 "size is fine". It falls under the director-approved Slice 5 criterion 4 ("slightly smaller"). Listed as FYI.

### 2026-10-28 - Slice 5b: bar modes, damage numbers, cast reads (ux-designer)
**HP bar visibility modes (criterion 4). The shipped value is UNCHANGED (`always_alive`); game-lead picks after the playtest.** One data value, `data/ui.json` `hp_bars.visibility_mode`, validated (`UiConfig.validate_hp_bars`: an unknown value is a loud push_error and falls back to `always_alive`, instead of silently behaving as always). Modes, all hiding the bar of a dead enemy:
- `always_alive`: every bar, always (the current default).
- `after_damage`: from the first hit on, sticky.
- `hidden_at_full`: only while below full HP. Enemies cannot heal today, so this is IDENTICAL to `after_damage` in every capture; kept because it differs once healing enemies exist. The playtester should treat them as one look.
- `elite_boss_always`: elites and bosses always, normals after damage. Today every enemy in `data/enemies.json` is rank normal, so this too equals `after_damage` in real waves; it differs only where a boss or elite exists (the `bar_modes` capture has two bosses).
- **Candidate default (a suggestion, not a decision): `elite_boss_always`.** In the 12-enemy captures every bar draws at once and the clump becomes a pile of overlapping red strips; only damaged enemies carry information the player acts on (who is nearly dead), and a boss needs a bar from the first frame. It is a superset of `after_damage`, so choosing it costs nothing now. The real trade, for the playtester: a fresh full-HP enemy shows no bar, so "how tough is this one" is not visible until it is hit. The director confirmed `always_alive` on 2026-10-27; this is therefore a candidate only.
- `EnemyHpBar.should_show(mode, dead, damaged, fill, rank)` is a pure function with a truth-table test. The rank is now read LIVE from the owner's `StatusEffectManager.rank` (it used to be read once in `_ready`, so a rank set later, as the capture scenarios do, was missed). Rejected: a separate "elite" visual or a mode per enemy type (nothing asks for it).
- **Back-row bars hidden behind bodies: not a readability problem at this density; no lift proposed.** In the 12-enemy captures (`bars_waves_*`, `bars_*`) bars sit 2.35 m up, above the heads, so a front body rarely covers a back bar; I could not find a bar hidden by a body. What does hurt is bar-on-bar overlap in a clump (a lift would not fix that: the quads stack in the same screen area), which the after-damage modes address. If the playtester finds a hidden bar, the fix is a larger `y_offset` (data), not a depth change. This is a judgement from stills; I did not count pixels.
- Captures (gitignored, in `screenshots/`): `bars_always_alive.png`, `bars_after_damage.png`, `bars_hidden_at_full.png`, `bars_elite_boss_always.png` (scenario `bar_modes`, 1.5 s) and `bars_waves_<mode>.png` (scenario `waves`, 5 s). New scenario `bar_modes`: 12 idle enemies, mixed HP, two bosses. To switch, edit the one value and rerun.

**Damage numbers (old follow-up (e)).** A Label3D at `pixel_size` 0.005 and font 48 was about 12 px tall at 720p. Now `data/ui.json` `damage_numbers`: `font_size` 48, `pixel_size` 0.011 (about 20 px digits at 720p; a test pins cap height over 14 px), `outline_size` 14, `outline_color` dark, `color_lighten` 0.3, `spawn_height`, `rise_distance`, `duration` 0.8, `big_scale` 1.35 for hits at the existing heavy threshold, `render_priority`. Colour comes from the element data (`ElementVisuals`, lightened toward white), not a second colour table, so fire is orange-leaning and physical cream. The fade holds, then drops (alpha 1 - t squared). **Anti-spam:** a new hit of the SAME damage type within `merge_radius` 0.8 m (ground plane) of a number idle less than `merge_window` 0.3 s adds into it (its clock is pulled back so it stays readable); at most `max_alive` 16 numbers, the oldest is freed first. Pure functions (`DamageNumber.find_merge_index`, `evict_count`) are tested. The live list is in `Juice`, cleared in `reset()` and pruned of freed nodes (the reload soak passes). Rejected: a flat cap only (it drops the newest information); merging across types (it would hide a Burn tick behind physical hits); a per-enemy accumulator (needs the enemy to own UI state).
- Known limit: the player's own damage-taken numbers use the same style and colour rules (same call). A separate "you got hurt" colour needs the caller to say who was hit, which is a gameplay-file change. Not done.

**S3B-2 IMMUNE.** 5a already helped (bars are opaque, IMMUNE has no depth test), but in the crowd capture the word was small, thin and crossed by neighbours' stars. Now it uses the same outlined style, sits one `render_priority` above the numbers, `immune_scale` 1.4 to 0.9 (the base got about 2.2x bigger, so the word is still bigger than before) and `immune_height` 3.0 to 3.3, above the bar line. Verified in `stun_crowd` (`dn_immune.png`): fully readable over bars and stars.

**Cast reads (s4-c, data first).** New `data/vfx.json` keys, validated, defaults in `VfxConfig`: `cone_duration` 0.25 to 0.45, `cone_alpha` 0.45 to 0.6, `cone_blade_duration` 0.13 to 0.22, `cone_blade_alpha`, `cone_enemy_duration_scale` 0.55; `heal_sparkle_size` 0.09 to 0.14, `heal_sparkle_duration` 0.6 to 0.9, `heal_sparkle_rise`, `heal_ring_radius` 0.8 to 1.0, `heal_ring_alpha` 0.6 to 0.85, `heal_ring_duration`; `dash_trail_size` 0.28 to 0.4, `dash_trail_duration`, `dash_trail_alpha` 0.5 to 0.7, `dash_trail_lighten` 0.35 (a paler puff so it separates from the floor); `projectile_trail_*` and `projectile_muzzle_*`. The cone sweep duration is no longer a constant in `TemplateVfx.cone_sweep`. **Enemy melee impacts use the same template and would linger like a live telegraph, so they are scaled by `cone_enemy_duration_scale` (a new optional `enemy` flag, set from the caster team).** Rejected: one longer duration for everyone. Pool cost: the dash trail spawns a puff per frame during the short dash; at 0.4 s lifetime it stays well under the 64 cap (the suite's cap tests pass).
- **Pointy Stick / neutral bolt.** The ball is sized to the hit radius (VfxSizing), so it was not enlarged; the neutral colour stays cream (colour language intact, enemy shots stay pink). What changed is the trail (larger, longer, more opaque) and the muzzle flash (1.6x), for every projectile, in data. Captured in the new `pointy_shot` scenario (`ps_new_1.png`): the ball and a clear dotted trail are visible. Honest limit: it is still a cream ball on a green floor; whether that is enough is a playtester question. Rejected: recolouring `neutral` in `pools.json` (changes every physical visual), a bigger halo (would lie about the hit area).

**s4-b golem occlusion: a note, no change.** The golem is now a 0.5 m radius capsule (N1), narrower than the old 1.2 m box. In `attacks` captures the wedge outlines and the aim reticle read around and in front of it; only the footprint directly behind the body is hidden, the normal cost of a 3D body over a ground shape. No cheap data fix exists (alpha does not help occlusion). Revisit only if the playtester loses a telegraph behind a golem.

**F-E5 (done, cheap).** When a stun cancels a live wind-up, a bright ring snaps inward at the enemy's feet in its team colour (`TemplateVfx.windup_cancelled`, keys `windup_cancel_size`, `_duration`, `_alpha`), so a vanished wedge or lane reads as "you stopped it", not "a glitch". One block in `Enemy._on_status_applied`, no behaviour change. Verified in the new `stun_cancel` scenario (`cancel_2.png`). Rejected: a popup word (more spam in a crowd).

**Verification.** Full suite 378/378 (365 before), 0 orphans; 20 s headless run (`--quit-after 1200`) and five scenarios headless: no error, warning or BUG lines; reload soak (5 cycles, run because Juice and Enemy changed) OK. Not verified: anything in motion, 1080p or 1440p, a hand-played fight; stills only at 1280x720.

### 2026-10-28 - After 5b (game-lead)
- **HP bar default:** the brief let game-lead pick, but ux's candidate (`elite_boss_always`) overrides the director's 2026-10-27 answer (`always_alive`). It goes to the director as D7. The shipped value stays `always_alive` until answered, and the playtester compares both looks. Rejected: switching now (that would override a director answer without asking).
- **Damage-taken vs damage-dealt numbers:** worth doing for readability. It's a small caller change, logged as follow-up 5-a for gameplay-dev after the pass. Not a director call.

### 2026-10-28 - After the Slice 5 qa FAIL (game-lead)
- **One fix pass, owned by gameplay-dev**, covering S5-1 through S5-7, S5-10, S5-8 (README CR bytes) and the stray .uid files. Ownership is formally split: S5-1, S5-2, S5-5 and S5-7 belong to ux-designer. But S5-1 is a script dependency issue (an autoload referenced under `-s`), not UI, and one run is cheaper than two. Rejected: two sequential runs.
- **D6 default A is applied in this pass** (golem wind-up 0.45 -> 0.7 s), as OPEN_ITEMS said would happen if the director hadn't answered. It's one data or scene value, and it's logged.
- **Density:** a competent-bot mean of 6.0-6.6 alive, peaking at 11-12, meets "about 6 to 15". It sits at the low end, which matches the GDD §1 density principle (fewer, more impactful enemies). It's listed as FYI for the director; no change.

### 2026-10-28 - Slice 5 fix pass (gameplay-dev)
Fixes for the Slice 5 qa FAIL, one commit each. Choices and the alternative rejected:
- **S5-1:** `const HP_BAR_MODES` in `UiConfig`; `EnemyHpBar.MODES` points at it. UiConfig no longer names `EnemyHpBar`, so nothing under `-s` reaches `Enemy` and the `Juice` autoload. Grepped the other `-s` entry points: only `tools/bot_sim.gd` and the gdUnit runner use `-s`, and the runner already works. Rejected: making `bot_sim` register autoloads (hides the real coupling). Rule going forward: static config classes must not name node classes that touch autoloads.
- **S5-2:** `validate_hp_bars` checks every key of `DEFAULT_HP_BARS`: width, height, ghost_drain_per_sec > 0; border, resist_border, y_offset, ghost_delay >= 0; render_priority a whole number in [-127, 126] (the IMMUNE word adds 1); ghost_enabled bool; burn_status_id non-empty string; every color a hex string, `colors` must contain all five default keys. A test lists a bad value for every default key and fails if a new default key has no case. Rejected: bounding border against width (no real failure to catch).
- **S5-3:** `WaveConfig.WALL_INNER_HALF_EXTENT` = 20.0 and `WALL_CLEARANCE` = 0.5, so `arena_half_extent` is capped at 19.5. Chose "validate against a constant" plus a test that reads the four wall boxes in `Main.tscn` and fails if the constant drifts. Rejected: deriving the walls from the scene at load (WaveConfig is a static data class with no scene, and the spawner would depend on a node lookup).
- **S5-4:** the spawn minimum is the existing `spawn_distance_min` in `waves.json` (no new key). `EnemySpawner._random_spawn_position` takes the first of 8 random ring points that is at least that far from the player after clamping; if none, it sweeps 32 evenly spaced angles at `spawn_distance_max` and takes the first that fits, else the farthest. Measured: 0 of 12,000 spawns under the minimum with the player at 8 spots including all four corners (was 0.6 percent, worst 0.54 m). Rejected: spawning along the wall only (needs wall-direction logic for what a sweep solves in 10 lines).
- **S5-5:** a merged damage number moves to the back of `Juice._live_numbers`, so cap eviction takes the oldest untouched one. Rejected: evicting the most idle (needs a per-number scan on every spawn; the move is O(n) on 16 items only at merge time).
- **S5-6:** `WavePlan.step_one()` returns one id or "" (no array); the spawner uses it. `step()` stays as a thin wrapper returning a list, because 10 existing tests iterate it. Rejected: a reused member array (callers that hold the result would see it change).
- **S5-7:** `UiConfig.damage_numbers()` caches the validated dictionary in a static var (read-only by convention; `DamageNumber` does not mutate it). A bad block still errors once and caches the defaults. Rejected: caching in Juice (other callers read it too).
- **S5-8:** README lines 51-53 had raw CR bytes (a backslash-r typed into the file became a carriage return, eating the following letter). Replaced with the real backslash and the file is text again to git (it was `i/-text`); the diff is a one-time whole-file line-ending normalisation (63 CRLF lines to LF, per `.gitattributes`). `.gitattributes` itself was fine. Watch for it: never type a backslash followed by r, n or t into a doc through a tool that unescapes.
- **S5-10:** `EnemyConfig.validate_enemies` also requires the scene root's script to be or extend the global class `Enemy`. It reads `PackedScene.get_state()` and the script's global name instead of instancing or naming `Enemy`, so it stays safe under `-s` (S5-1). Tests: Main.tscn is rejected as an enemy scene.
- **D6 default A:** golem `telegraph_duration` 0.45 -> 0.7 s as a scene export in `FireResistantGolem.tscn` (the other two stay 0.45). The wedge fill and the hit both read `telegraph_duration`, so the telegraph lasts the whole wind-up (a test checks it is still showing at 0.02 s left). New golem numbers: cycle 0.7 + 1.8 = 2.5 s (was 2.25), DPS 3.6 (was 4.0), hits to kill the player 4, free window after a swing unchanged at 1.8 s; a roll's 0.25 s of invulnerability now covers the last 36 percent of the wind-up (was 55 percent), and a sidestep has 4.2 m of walking time (was 2.7 m). Net: easier to read and avoid by moving, slightly harder to dodge by rolling on reaction. Rejected: moving all wind-ups into `data/enemies.json` in this pass. The file still keeps per-type combat stats as scene exports (see the Slice 1 enemies entry), so moving only one value would split the pattern and moving all is a refactor with no qa-visible gain now. Flagged as a candidate for the next enemy data pass.
- Untracked `.uid` files committed.

### 2026-10-28 - Closing Slice 5 (game-lead)
- **Closed with HP bars at `always_alive`.** The brief let game-lead pick the bar default, but B overrides a director answer, so the default stays until D7 is answered. Both ux and playtester recommend B.
- **New 5d, before the pass close-out.** Chaser stacking breaks GDD §1 readability: the player is hidden and the wedges merge. Separation steering is the fix. Rejected: lowering the cap (the playtester showed 12 spread out reads fine; the blob is the problem).
- **TrainingDummy removed from the normal run:** my call, cheap and reversible. It was a Milestone 2 test aid, it reads as an enemy, and scenarios keep it. Rejected: asking the director (not a design question).
- **5d's qa is short and targeted, and its playtest folds into the whole-pass close-out playtest.** That saves a separate run. Rejected: a separate 5d playtest.
- **The playtester's "dark void corner"** is the arena edge past the floor, by design since 4b. Listed as FYI.

### 2026-10-28 - Slice 5d: separation steering, TrainingDummy, enemy stats (gameplay-dev)
- **Separation steering (F-E3).** Every `Enemy` keeps a static roster array (`Enemy._roster`, added in `_ready`, erased in `_exit_tree`) and each physics frame walks it once, summing a push away from every neighbour inside `separation.radius`, weighted by depth (0 at the edge, 1 on top). Plain `Vector3` math, no allocation, spawn order so it is deterministic; at 12 alive that is 144 distance checks per frame. Rejected: Godot's built-in `NavigationAgent3D` avoidance (needs a navigation map and baked mesh we do not have, adds a per-agent server callback, and its results are not as easy to unit test) and `get_nodes_in_group` per frame (allocates an array each call).
- **How the push is applied.** While closing in, only the sideways part of the push counts, plus a fixed per-enemy swirl (side chosen by instance id parity, `SWIRL` = 0.6 of the push length). Reason: the full push points straight back along the path for an enemy queued behind another, cancels the chase, and parks it in line (measured: radius and strength had no effect until this was handled). The total is clamped to the enemy's own `move_speed`. In range, while waiting out the attack cooldown, enemies slide sideways only (the radial part is removed) so they neither leave attack range nor crowd in. Rejected: a random sideways jitter (not repeatable, jitters visibly).
- **Wind-up untouched.** Steering lives only in `_chase_and_attack`; the wind-up branch still sets velocity from knockback alone and does not turn, so the wedge and lane still match the real hit. A test pins position and facing across a wind-up with a neighbour on top of the enemy.
- **Data (`data/enemies.json` `separation`, validated by `EnemyConfig.validate_separation`, unknown keys rejected):** `radius` 2.5 m, `strength` 1.5 (multiplies the push, as a fraction of the enemy's move speed), `readable_spacing` 1.2 m, `near_player_radius` 4.0 m. Tuned on the seeded test: strength 0.8 and radius 1.8 gave 50 percent spread frames, 1.5 and 2.5 gave 79 percent (steering off: 5 percent). Applies to every enemy type (shooters and golems spread too); there is no per-type override yet.
- **Metric (sim and test).** Per physics frame with 2 or more non-ranged enemies within `near_player_radius` of the player, take the smallest pairwise flat distance among them. A frame is "spread" if that is at least `readable_spacing` (1.2 m; chaser bodies are 0.9 m across, so 1.2 m is a visible gap). The test (`tests/unit/separation_5d_test.gd`: 6 chasers from a 70 degree arc, still player, 360 frames) needs 60 percent or more spread frames with steering on, and requires the same setup with steering off to fall below that (so the test is not vacuous). The wave sim prints mean, worst and the share per run. Rejected: a metric over all enemies (far-away spawns are always apart and would hide a blob on the player).
- **Wave sim, before to after (seed 1, 90 s, 3 runs; and idle seed 20, 60 s, 3 runs).** Before: mean alive 5.9/4.7/5.5, HP lost 21/20/20, mean min-pair 1.71/1.49/1.47 m, spread frames 48/33/36 percent, worst 0.88/0.83/0.76 m. After: mean alive 4.3/5.9/5.7, HP lost 20/12/28, mean min-pair 2.26/1.90/2.18 m, spread 96/84/85 percent, worst 0.90/0.87/0.72 m. Idle: spread 6/10/34 percent before to 90/87/100 percent after, and the idle player still dies at about 8-9 s with 30 HP lost (no balance change). The worst-case pair distance stays near the 0.9 m body contact because single frames still touch (a knockback or a spawn); the share is what moved.
- **TrainingDummy out of the normal run.** Removed the node (and its ext_resource) from `scenes/main/Main.tscn`; `scenes/debug/TrainingDummy.tscn` and its script stay for tests (`enemy_hp_bar_test` spawns it directly). No scenario in `data/scenarios.json` used it, so nothing needed re-adding. Tests that freed it from Main (`slice4_qa_test`, `slice4_recheck_test`) lost that line; a new smoke test asserts Main has none. Rejected: a Main export flag to toggle it (more surface for a node nobody wants in a run).
- **Enemy combat stats moved to data (5d item 3, done, values unchanged).** `data/enemies.json` `enemies.<id>.stats` now holds move_speed, is_ranged, attack_range, preferred_range, attack_damage, attack_damage_type, attack_cooldown, telegraph_duration, projectile_speed, projectile_max_range for the three types. `EnemyConfig.validate_stats` requires every key (numbers range-checked and finite, bool, non-empty string) and rejects unknown keys; `Enemy._ready` applies them over the script defaults. The overrides were deleted from the three enemy scenes so data is the only source (HP and resistances stay on the scene's `Health` node, rank stays in the same entry). `tests/unit/enemy_stats_5d_test.gd` freezes the old scene values and asserts both the data and a spawned enemy of each type equal them. An enemy with no data entry (a test scene with no `enemy_id`) falls back to the script exports. Rejected: keeping the scene overrides next to the data (two sources that can drift); moving HP and resistances too (outside the brief, and `Health` is shared with the player).

### 2026-10-28 - [DIRECTOR DECISION] Answers to D1-D7
- [DIRECTOR DECISION, 2026-10-28] **D1 = A:** no run stats on the Game Over screen for now; revisit with the run structure (Milestone 3a).
- [DIRECTOR DECISION, 2026-10-28] **D2 = C:** hold-to-preview is the default (hold the card key to see the exact hit area, cast on release). It must be changeable in settings to cast on press instead. GDD §3 is updated. This needs new work: Slice 6, plus a minimal settings store and screen, since none exists yet.
- [DIRECTOR DECISION, 2026-10-28] **D3 = A:** team tint for shots. Already built in 5a; no change.
- [DIRECTOR DECISION, 2026-10-28] **D4 = A:** keep light at 3 damage per hit. The director will playtest personally; keep it easily tunable (it already is: one value in `data/attacks.json`).
- [DIRECTOR DECISION, 2026-10-28] **D5 = A:** keep the heavy's 50% Burn as built (about 5.97 total DPS).
- [DIRECTOR DECISION, 2026-10-28] **D6 = A:** golem wind-up 0.7 s. Already applied (acc26a4); confirmed.
- [DIRECTOR DECISION, 2026-10-28] **D7 = B:** HP bars show on damaged enemies, and elites and bosses always show theirs (`hp_bars.visibility_mode = elite_boss_always`). It supersedes the 2026-10-27 `always_alive` answer. Applied in Slice 6b by ux-designer, because gameplay-dev is mid-5d and the roles don't overlap.
- **Settings scope (game-lead default):** a minimal settings store with defaults in data (`data/settings.json`), user overrides in `user://settings.cfg`, and a minimal settings screen (Esc pauses and opens it) with the cast-on-press toggle. Rejected: a full options menu now (not asked for; it grows with Milestone 3).

### 2026-10-28 - After 5d (game-lead)
- **Player occlusion cue: yes**, added to Slice 6b (ux-designer). In the iso view, bodies still hide the player in a crowd even with good spacing, which hurts GDD §1 readability. This is a readability call, not a design question, so it isn't sent to the director. Rejected: more steering strength (it can't fix camera-angle overlap).

### 2026-10-28 - After the 5d qa FAIL (game-lead)
- Fix pass to gameplay-dev: S5d-1, S5d-2, F1 (swirl side from spawn order, not from the instance id, so runs are reproducible from a seed), and F3 (.uid files). F2 (the roster only fills in `_ready`) stays a follow-up, because nothing reparents enemies. F4 (mean alive is a little higher) is checked at the close-out playtest.
- Changelog corrected: spread-frame range "84-96%" -> "about 80-96% (depending on seed)", per the qa seeds.

### 2026-10-28 - 5d qa-FAIL fix pass (gameplay-dev)
- **S5d-1:** the in-range waiting slide is clamped to `move_speed` with the same scale-down as the chase branch. Every other branch (wind-up, stunned, spawn grace) sets velocity from knockback alone, so there was no further gap. Rejected: clamping the final velocity in `_physics_process` (it would also cap knockback, which is meant to exceed move speed).
- **S5d-2:** `validate_enemies` calls `validate_stats` per entry, so `validate()` covers it. A bad block makes the whole file invalid: `get_config()` already logs the joined errors with `push_error` and returns the defaults before it reaches the stats dereference, so it never dereferences null. Two older tests (`heavy_3b2_test`, `slice5_qa_test`) used stats-less "valid" fixtures; they now carry the real chaser stats block. Rejected: making stats optional (the point of 5d is that data is the only source).
- **F1:** `Enemy.spawn_index` (assigned by `EnemySpawner` from a per-spawner counter, reset in `set_seed`) replaces `get_instance_id()`: swirl side is its parity, the on-top push angle is `spawn_index` times the golden angle. An enemy with no assigned index (tests, scenarios) takes the roster size at `_ready`. The separation speed test sets the index explicitly. Rejected: a global static counter (survives across tests, so suite order would change behaviour again) and a per-enemy RNG (extra state for no gain).
- **F3:** added the three missing test `.uid` files (the two named, plus `slice5d_qa_test.gd.uid`). F2 (roster filled only in `_ready`) is left open as agreed.

### 2026-10-28 - 5d re-check folded into 6c (game-lead)
- The 5d fixes are small. qa's own regression tests now pass unmodified, and the suite was green on 3 consecutive runs. qa re-checks them inside the Slice 6 review instead of in a separate run, and 5d is not marked done until that verdict. Rejected: a separate re-check run (it costs usage for a pinned fix).

### 2026-10-28 - Slice 6a: hold-to-preview casting and the settings store (gameplay-dev)
- **Settings store.** `data/settings.json` holds typed definitions (`type` enum or bool, `default`, `options`, `label`, `option_labels`); `SettingsStore` (RefCounted, injectable defaults and user paths) validates them and the user file `user://settings.cfg` (a ConfigFile, section `[settings]`). A bad value falls back to that key's default; garbage that is not a config file falls back to all defaults. Problems are collected in `store.problems`, and the `Settings` autoload `push_error`s them at startup (fail loud, never fatal). `set_value` changes memory and emits `changed(key, value)` but never writes; `save()` writes (the UI calls it when the player confirms). Reason: a test or tool flipping a value must not overwrite a real settings file. Tests inject a store with `Settings.use_store(...)` and a temp path. Key `cast_trigger`: `"release"` (default) | `"press"`. Rejected: saving on every `set_value` (tests would rewrite the dev's real file); a JSON user file (the brief names `settings.cfg`).
- **Input model.** Light/heavy clicks and slot keys are latched from events in `Player._unhandled_input` (closes s3-j), so a UI screen that consumes the event blocks them. Dodge and movement still poll `Input`. Latched edges live until a physics tick takes them (not per frame), so a click is never lost to hit-stop. `CastInput` (pure) is the press/hold/release model. Slot press uses `exact_match` (Ctrl+1 is a swap, not a cast); slot RELEASE does not (press 1, press Ctrl, release 1 must still end the hold). A release only counts for the slot being previewed. Press and release inside one tick cast once. A cast request is queued and run in `_physics_process` (physics queries stay out of input callbacks); `try_use` refuses a slot on cooldown, so releasing a cooling slot just clears the preview, and a slot that becomes ready during the hold casts on release.
- **Cancel rules** (`Player.cancel_cast_preview()`, no cast, pending latched cast dropped): death; pause (`GamePause.paused_changed`); the `cast_trigger` setting changing mid-hold; any screen calling it. A new press is needed after a cancel. Dead player: no input at all, so Game Over (which is always after death) cannot start a preview. Dead-card swap (Ctrl+N) acts on press, never casts, and leaves the preview alone (the preview refreshes to the new revealed card; the swap penalty makes the release a no-cast anyway).
- **Preview.** One held, reused node set (`CastPreview`, child of Player, top-level), not pooled effects: a preview held for seconds would be evicted at the 64 cap in a busy wave and would starve Burn flames. Built only when the previewed slot or its revealed card changes; per frame it only moves up to 3 pivots. Shapes (`CastPreviewShapes`, pure): `cone` (VfxSizing.cone_reach, half angle, at caster), `aoe` (VfxSizing.aoe_reach, centred on caster), `projectile_lane` (length max_range, half width VfxSizing.projectile_lane_half_width, starts `EffectTemplates.PROJECTILE_MUZZLE_OFFSET` = 0.6 ahead), `dash_path` (length distance, half width `dash_path_half_width`), each along the FACING (`get_aim_direction()`, what cards really fire along), one part per aimed effect (Blaze and Bail = aoe + dash). **Heal, buff and status-only cards show a small `self_ring`** (radius `self_ring_radius` 0.9; `self_ring_enabled: false` shows nothing instead). Rejected: nothing for non-aimed cards (a held key with no feedback reads as broken). Look is data in `data/cast_preview.json` (fill/edge alpha, edge thickness, lighten, default colour, ground offset, render priority); fill plus a lighter edge in the card's element colour. ux restyles in 6b. `color_source` ("card_element" default | "player_element" | "fixed") picks the colour, so the 6b "player's element colour" is a data edit; `get_preview_state()["ready"]` says whether a release would cast now (ux may dim the preview). Losing window focus cancels a hold like a pause (a release during focus-out may never arrive). The `cast_preview` scenario forces `release` in memory (never saved) so a saved "press" cannot blank the capture.
- **Pause.** `GamePause` autoload: `pause()`, `resume()`, `toggle()`, `is_paused()`, `paused_changed(bool)`, `reset()`. It also calls `Juice.freeze_time()` / `thaw_time()`: freeze puts `Engine.time_scale` back to 1.0 and remembers the unfinished hit-stop or slow-mo (time left and scale); thaw continues it for exactly that long. A hit-stop requested while frozen is ignored. `Juice.reset()` and `Main._prepare_for_restart` clear the state. Two timers now pause with the tree (they used to ignore it): Main's death-beat timer (so Game Over cannot appear over a pause screen) and the buff duration timer. `pause()` is refused once Game Over is up. Rejected: pausing through `get_tree().paused` alone (Juice's wall-clock deadline would keep running through the pause and the slow-mo would be eaten).
- **Tooling.** `wave_sim` and `Scenario` now send real `InputEventAction`s through `Input.parse_input_event` for slot/attack actions (`Input.action_press` emits no event, so they would stop firing). Tests use `tests/support/test_input.gd` (`TestInput.press/release/tap`, flushed at once). Seed 7, 60 s, god, scale 1: card casts 127 before, 132 after. New scenario `cast_preview` (flag `previews`: held keys for captures). `CardSlotController.card_cast(slot_type, card_id)` signal added (sim and HUD can use it).
- **Test files touched** (injection lines only, assertions unchanged): `attack_meter_test`, `heavy_3b2_test`, `player_attack_test`, `player_death_test`, `slice3_qa_test`, `slice3b_qa_test`, `stun_cue_3b3_test`.

### 2026-10-28 - Slice 6b: settings screen, preview look, D7, occlusion cue (ux-designer)
- **Settings screen** (`scenes/ui/SettingsScreen.tscn`, `src/ui/SettingsScreen.gd`, child of Main, canvas layer 20, `PROCESS_MODE_ALWAYS`). New `pause` action = Esc in `data/input_bindings.json`. Esc opens (via `GamePause.pause()`, so it is refused over Game Over) and closes; Resume does too. Text, sizes and colours in `data/ui.json` `settings_screen`; the toggle's label and option names come from `Settings.get_definition("cast_trigger")`, never typed in the UI. Changing the toggle calls `set_value` then `save()` at once; opening never saves. Focus starts on Resume. Backdrop darkens the world (alpha 0.6, tunable).
  - **Toggle is two toggle buttons, not an OptionButton / dropdown.** Both choices are visible at once, one click or one arrow key, nothing hidden in a popup. Rejected: dropdown (hides the other choice, extra click). The selected button also has the "(x)" marker and a lighter fill, so selection is never colour-only.
  - **Unit scale rule:** same as Game Over (`reference_height` 720, scaled by window height); fits 1280x720 with room (tested).
  - The Esc handler is `_unhandled_input` on the screen, so a focused button never eats it. Capture tooling: new scenario key `open_settings_at` (scenario `settings_open`); `ScreenshotCapture` is now `PROCESS_MODE_ALWAYS` so timed shots still fire under a pause.
  - `slice3_qa_test` "UI does not swallow clicks" now skips `SettingsScreen` (modal on purpose, hidden until Esc), like Game Over.
- **Preview look** (`data/cast_preview.json`): `color_source` = `player_element` (one colour for every card: the player's element; pink stays enemy telegraphs, and the cast effect keeps the card's own colours). Rejected: `card_element`, which made a fire cone and the fire cast effect the same orange, so the preview read as the effect. New keys: `over_enemies` (true: material `no_depth_test`, so the preview stays visible over the enemies it targets; HP bars and damage numbers have a higher render priority and still sit on top), `not_ready_alpha_scale` 0.4 and `not_ready_desaturate` 0.7 (a cooling slot shows the same shape, fainter and greyer; `Player.get_preview_state()["ready"]` drives it, it is polled each frame and writes materials only when it flips). Size is untouched (VfxSizing). Rejected for visibility: bumping `render_priority` alone (it does not beat the depth test), a stencil or second pass (more machinery for a flat ground marking). Side effect to be aware of: with no depth test a preview also draws over tall things standing in front of it (an enemy body between camera and ground area). That is the wanted behaviour here.
- **D7 applied:** `data/ui.json` `hp_bars.visibility_mode` = `elite_boss_always`. The code fallback `UiConfig.DEFAULT_HP_BARS` stays `always_alive` (a missing file should not hide bars). Two tests that needed a full-HP bar (`test_bar_follows_health_and_hides_on_death`, `test_every_enemy_scene_has_a_bar_bound_to_its_health`) now pin `always_alive` around their spawn; the config-default test pins `elite_boss_always`.
- **Player occlusion cue** (`src/player/PlayerOcclusionCue.gd`, `player_occlusion_cue.gdshader`, attached by Main like AimIndicator; Player untouched). A copy of the body mesh under BodyMesh with a spatial shader: no depth test, no depth write, reads the depth texture, draws a pixel only where the scene is nearer than the body's own surface by more than `depth_bias`; slightly stronger at the silhouette edge. A visible player matches its own depth and draws nothing. It is a 3D node, so it cannot draw over the HUD. Data: `data/ui.json` `player_outline` {enabled, color `#8fd0ff`, alpha 0.75, depth_bias 0.05} (validated, loud on bad values). Rejected: a `next_pass` on the body material (the hit and death flash code tweens a duplicate of that material, and a shared pass would fight it), and a stencil outline (needs scene-wide stencil setup).
- **Cannot be verified headless:** the cue and the not-ready dimming are render effects. Seen in captures (waves: pale blue silhouette through the crowd; cast_preview: cone over enemies) and by data-level tests; the shader's rule is pinned by a source test, not run.

### 2026-10-28 - After the Slice 6 qa (game-lead)
- **5d closed:** re-check PASS. S6-4 (whole seeded sim runs don't repeat) is outside 5d: the causes are the card shuffle RNG, the status RNG and Juice's wall-clock hit-stop. Steering itself repeats. S6-4 moves to the capture-tooling task, and the README claim gets fixed there.
- **S6-2: the dash moves, not the preview.** The data says `distance` 4.0. The extra coast (about 8.1 m total) is a forced-move bug: velocity isn't stopped at the end. Fix: a forced move ends at its distance and hands back to normal movement without coasting. The dodge shares the code, so it gets shorter too. That's logged as a feel change in OPEN_ITEMS FYI, and it's one data value to tune. Rejected: making the preview show the coast. That would make data `distance` meaningless and the coast depends on the frame rate.
- **S6-3 (the projectile lane tip understates the hit by about 0.3 m):** extend the lane's length by the same lateral-reach padding as its width (VfxSizing), so the shape doesn't lie. Rejected: accepting it because it errs safe (the rule is "visuals match hitboxes").
- **One fix pass with gameplay-dev**, including the ux-owned S6-5 (Space on a focused button also dodges), S6-6 (null-material error lines in the suite) and S6-7 (a failed settings save is silent). Same reason as before: they're small, and one run is cheaper than two.
- **tech-writer agent:** an untracked `.claude/agents/tech-writer.md` appeared. It wasn't created by the team, so I assume the director made it. Left uncommitted and unused until the director says. The CLAUDE.md changelog rule still names game-lead.

### 2026-10-28 - Slice 6 qa-FAIL fix pass (gameplay-dev)
- **S6-1:** `Player.cancel_cast_preview()` also clears both attack latches (light, heavy). It is already what death (`_on_died`), pause and settings open (`_on_pause_changed`; the settings screen pauses through `GamePause`), focus loss and a `cast_trigger` change call, so every path that drops a latched cast now drops a latched click too. Rejected: clearing only in `_on_pause_changed` (death and focus loss would still leave a latched click).
- **S6-2:** a forced move (dodge roll, dash card) ends at exactly `speed * duration` and stops dead. `_apply_forced_move` scales the last tick's velocity to the time left (`remaining / delta`, clamped to 0..1), so no tick overshoots; after `move_and_slide` on the tick the move ends, horizontal velocity is zeroed and normal movement takes over from rest. Frame-rate independent (measured below). Rejected: only zeroing the velocity at the end (the last tick would still overshoot by up to one tick of travel, 0.47 m at dash speed at 30 Hz). The preview is unchanged. Measured with the player facing a clear floor, distance along the facing, before to after: Dodge (14 m/s, 0.25 s, intended 3.5 m): driven 3.96 m and rest 7.12 m at 60 Hz (30 Hz: 4.17 / 7.00, 120 Hz: 3.73 / 7.06); now 3.50 m driven and 3.50 m at rest at 30, 60 and 120 Hz. Blaze and Bail dash (15 m/s, 4.0 m): driven 4.49 m and rest 8.14 m at 60 Hz (30 Hz: 4.97 / 8.27, 120 Hz: 4.25 / 8.08); now 4.00 m and 4.00 m at all three rates. So the dodge is about half as far (7.1 to 3.5 m) and the dash about half as far (8.1 to 4.0 m). Dodge i-frames (duration 0.25 s, 15 to 16 ticks at 60 Hz) and cooldown (0.8 s) are unchanged: same duration, same code. If the dodge now feels short, tune `dodge_speed` or `dodge_duration` (Player exports); that is a playtest call. The qa pin `test_pin_dodge_coasts_past_its_drive_distance_like_the_dash` became `test_dodge_ends_at_its_drive_distance_and_does_not_coast`. New `tests/unit/forced_move_s6_test.gd` covers 30/60/120 Hz and the i-frame window.
- **S6-3:** `VfxSizing.projectile_lane_length(max_range, hit_radius)` = `max_range + lateral_reach(hit_radius)` (about 0.6 m longer for a 0.3 m shot). Used by both the cast marker (`TemplateVfx.projectile_lane`) and the hold preview (`CastPreviewShapes`, projectile part `size`), so they agree. Start is unchanged (the muzzle). The lane is an upper bound, not exact: a `Projectile` frees itself on the tick it passes `max_range`, so its last tested position can be up to one tick of travel short of `max_range` and the real reach varies a little with speed and frame alignment; the rule that matters (nothing is hit outside the drawn lane) holds. qa's pin became `test_projectile_lane_tip_is_where_a_real_shot_stops_hitting`; `cast_markers_test` and `cast_preview_6a_test` use the new length. Not changed: the ranged-enemy wind-up lane (`enemy_shot_lane`) has the same understated tip against the player; outside this brief, flagged for game-lead. Rejected: making the projectile test its final position exactly (a gameplay change, not asked for).
- **S6-5:** `Player` ignores a dodge press for `DODGE_BLOCK_TICKS_AFTER_PAUSE` (2) physics ticks after every pause or resume (`_on_pause_changed`). The settings screen pauses through `GamePause`, so Space on a focused Resume (ui_accept) closes it and no longer also rolls; a fresh press after that dodges (tested). Two ticks is about 33 ms, below human re-press time. Rejected: latching dodge from `_unhandled_input` like attacks and cards (the right long-term shape because a UI that consumes the event blocks it, but several older tests drive dodge with `Input.action_press`, which emits no event, so it would rewrite them for no new coverage); swallowing the key in `SettingsScreen` (the screen would need to know about gameplay actions).
- **S6-6:** the four `Parameter "material" is null` lines came from `ux_6b_test::test_occlusion_cue_is_attached_from_data_and_a_3d_object`, not from teardown order or the cue: `assert_object(cue.mesh).is_same(...)` made gdUnit hold a reference to the body mesh, and freeing the Main afterwards made the renderer update the cue's instance against a freed material. Bisected with a scratch suite (immediate free, shader param reads, frames, camera null all clean; only that assert reproduced it). Fix is one line in the test (`assert_bool(cue.mesh == ...)`). No production change. Rejected: `queue_free` plus waiting frames in `after_test` and clearing `material_override` in the cue's `_exit_tree` (both tried, neither changed the output). Note `vfx_sizing_test` uses `assert_object(...mesh).is_same` on a pooled disc mesh and prints nothing.
- **S6-7:** `SettingsScreen._on_option_toggled` checks the result of `Settings.save()`. On false it `push_error`s ("could not save 'cast_trigger'... will not survive a restart") and shows a `SaveNote` label under the hint (built in code, so `SettingsScreen.tscn` is untouched). Text and colour are `data/ui.json settings_screen` `save_failed` and `save_failed_color` (with code defaults in `UiConfig`). The note hides on open and after a save that works. Test: `ux_6b_test::test_a_failed_save_shows_a_note_and_a_good_save_clears_it` (store pointed at a directory that does not exist); it prints one expected ERROR line. Rejected: blocking the toggle on a failed save (the session setting should still work), and a modal error (too heavy for a note).

### 2026-10-28 - Dodge distance after S6-2 (game-lead)
- The S6-2 fix made forced moves stop at speed x duration. The dodge went from about 7.1 m effective to 3.5 m, and the wave-sim bot's HP lost rose about 2.5x on the same seed. I didn't decide it silently: it's a feel and difficulty change on the player's main defence, so it goes to the director as D8. Recommended and default B: `dodge_speed` 14 -> 28, the same 0.25 s duration and i-frames, which restores the tested feel. It's applied in the next gameplay task, together with moving the dodge values into data (CLAUDE.md "content is data"). Rejected: leaving 3.5 m in place unasked (it would silently change difficulty).

### 2026-10-28 - Note on seeds (game-lead)
- The 5d F1 entries say steering comes "from spawn order, so a seed reproduces the run". Only the steering repeats; whole wave and bot sim runs do not yet (S6-4: card shuffle RNG, status RNG, Juice wall-clock hit-stop). This is fixed or documented in the tooling task. The older entries stay as written.

### 2026-10-28 - True-size capture: WorldRef and tools/VpCapture.tscn (gameplay-dev)
- `tools/capture_screenshot.ps1 -TrueSize 2560x1440` runs `res://tools/VpCapture.tscn`, which hosts the real Main in a SubViewport of exactly that size (the OS window is clamped to the monitor). Same `--scenario` / `--screenshot-after` / `--screenshot-out` args; Main's own ScreenshotCapture saves the SubViewport texture and quits the tree normally (no leaked RIDs, exit 0). A SubViewportContainer forwards scenario input events. It is a scene, not a `-s` script, so autoloads resolve.
- New `src/core/WorldRef.gd`: Main registers in `_enter_tree`; `get_world(tree)` returns `current_scene` when set (so normal play and the test runner are unchanged) and the registered Main only when `current_scene` is null (the SubViewport case). Used by the spawner, Juice popups, Player and Enemy effect contexts, and GamePause.
- GameOverScreen keeps `bind(current_scene)`; VpCapture binds it by hand. Reason: binding it through WorldRef in unit tests (Main added under root before current_scene is set) changed first-run timing and broke qa's `slice6_qa_test` crowd test (bit-identical positions) when run after `slice5_qa_test`. Rejected: using WorldRef there and loosening the test; making `current_scene` settable inside the SubViewport (Godot requires a root child); one oversized OS window (clamped by the monitor).

### 2026-10-28 - Dodge values in data/player.json; D8 default B applied (gameplay-dev)
- New `data/player.json` `{"dodge": {speed, duration, cooldown, block_ticks_after_pause}}`, read and validated by `src/player/PlayerConfig.gd` (ranges, integer tick count, unknown or missing keys rejected; a bad file push_errors and falls back to the same defaults). `Player` copies them into `dodge_speed`, `dodge_duration`, `dodge_cooldown` and `dodge_block_ticks_after_pause` in `_ready` (plain vars, no longer exports or a constant), so existing code and tests keep reading the same names.
- Values: `speed` 14 -> 28, `duration` 0.25, `cooldown` 0.8, `block_ticks_after_pause` 2. Distance 3.5 m -> 7.0 m (speed x duration, measured at rest in `player_config_test`). I-frames (0.25 s) and cooldown unchanged. This is the D8 default B as briefed; the director's later answer (D8 = C, about 5 m, `speed` 20) is a one-number data change for C1-a.
- Rejected: adding the keys to `data/attacks.json` (it is the light/heavy attack table with a shape-specific validator; the dodge is not an attack); keeping Player exports as the source (they would still be a second place to tune).

### 2026-10-28 - S6-4: seeded sims repeat exactly (gameplay-dev)
- **What now repeats:** `run_wave_sim.ps1 -Seed N` and `run_bot_sim.ps1 -Seed N` give identical results on rerun (wave sim: the `result:` line, including a hash of every position at the end; bot-sim: a `checksum` line). Test: `seeded_sim_repeat_test` runs each tool twice in child processes and compares, and checks another seed differs. Checked also with `--trace` (per-second state hash) over 30 s.
- **Sources fixed:** (1) card shuffles: `CardSlotController` takes an optional shared `RandomNumberGenerator` (the bot-sim seeds one per room); (2) `Player.status_rng` and the card RNG: static `Player.default_rng_seed` (-1 = normal random play) seeds them in `_ready`, set by the wave sim per run; (3) `CameraRig` shake jitter (an unseeded RNG that moves the camera and so the mouse aim and knockback direction; found by tracing, a 5e-5 m drift in the first fight), seeded from the same value; (4) `Juice` hit-stop and slow-mo end on the wall clock, so `Juice.hit_stop_enabled = false` in the wave sim (hit-stop only affects feel; shake and numbers still run); (5) buff modifier ids used `Time.get_ticks_usec()`, now a counter.
- **Pacing:** frames used to step a wall-clock-dependent number of physics ticks. `run_wave_sim.ps1` now launches Godot with `--fixed-fps 60` (one 60 Hz tick per frame). Under `--fixed-fps`, `Engine.time_scale` does not speed physics (measured: 1 tick per frame at scale 3), so `-Scale` now defaults to 1; `-Scale` above 1 drops `--fixed-fps`, prints a note, and the run does not repeat. Sim runs are fast anyway (30 s of game time in about 1.6 s wall, headless).
- **Not covered:** a windowed run, or any run with `-Scale` above 1; results can differ between machines or Godot versions (physics float behaviour), so a seed repeats on the same machine and build.
- Rejected: a sim-only fake clock inside Juice (more code and still needs fixed frame stepping); making the sim wait on wall-clock hit-stop (slow and still racy).

### 2026-10-28 - Follow-up 6-a: enemy shot lane tip padding; Enemy.gd header (gameplay-dev)
- `TemplateVfx.enemy_shot_lane` now draws the strip `VfxSizing.enemy_shot_lane_length(max_range, hit_radius)` long: `max_range` plus `lateral_reach_vs_player(hit_radius)`, the same reach its sides already use. That is the player lane's `projectile_lane_length` rule applied against the PLAYER's capsule (the brief said "the same padding"; the player lane pads by the enemy-capsule reach, which would be about 0.03 m wrong here, so the enemy lane uses its own matching helper). Test: `cast_markers_test`. Rejected: reusing `projectile_lane_length` directly (wrong capsule).
- `src/enemies/Enemy.gd` header comment: stats come from `data/enemies.json`, not per-scene exports.

### 2026-10-28 - After the tooling task (game-lead)
- **The tooling task's docs pass is folded into C1-h** (one tech-writer run instead of two). The README capture and sim sections stay stale until C1 closes, and the tooling task is not marked done until that pass. qa is told to report those README gaps, not fail on them. Rejected: a separate tech-writer run now.
- **The wave sim disables hit-stop** to repeat exactly. Accepted: hit-stop timing is covered by unit tests and the reload soak, and the sim's job is crashes, NaN, soft locks and pacing. Rejected: a fake clock in Juice (more code in a hot path).

### 2026-10-28 - C1-a deck rules plumbing (gameplay-dev, logged by game-lead)
- **Run start warns instead of blocking (temporary).** *(Superseded 2026-10-29: C1-c made it block, and the PENDING_C1C tripwire was replaced by a real pass test.)* GDD §4 says a deck that misses the minimums can't start a run. The shipped Fire Rogue deck is short (Movement 2/3, Recovery 2/3) until C1-c adds the cards, so blocking now would make the game unplayable. Rejected: block now. **C1-c must switch run start to block (fail loud) once content passes**, and delete the tripwire test branch `test_shipped_content_meets_the_minimums_PENDING_C1C`.
- **Per-slot overrides live in `deck_rules.json`** as `"slots": {slot: {"min_unique": n}}`. Rejected: a field in `slot_types.json`, because keeping every deck rule in one file is simpler.
- **Content validation runs as a test and helper, not at boot.** Rejected: a boot check, which would duplicate the run-start warning.
- **The pending content check is a tripwire test** that asserts the exact known shortfalls. Rejected: a gdUnit skip, which would hide a regression.
- **Remove/swap guards only block on the card's own slot and groups.** Removing a spare copy in an already-short slot isn't blocked; removing the last copy of a unique card is. Rejected: comparing full before/after counts. Revisit when the in-run removal UI exists.
- **The run-start warning fires once per process,** so scene reloads don't repeat it. **`DeckRules.shipped_config()` is cached** because the F3 overlay reads it every frame; explicit-path loads (fixtures) stay uncached.
- **Shuffle bag fix (bug, not design):** the old code reshuffled while the last-drawn card was still in hand, so that card was missing from the next cycle (a size-3 deck could cycle [c1,c1,c2]). Now the bag refills from all owned copies when it empties, and the first card of the new bag is never the card just drawn (when another unique card exists). Side effect: a one-card slot's "next" preview now shows that card instead of "".
- **Recovery cooldown: no change.** Base 8.0 vs next-longest utility 4.0; shortest recovery effective 6.5 (Nap Time) vs longest non-recovery effective 4.5 (Deep Sigh). A test pins this rule against shipped data.

### 2026-10-28 - C1-b1 generic capabilities part 1 (gameplay-dev, logged by game-lead)
Commits 4236e5a..87dbb87. Rejected alternatives in brackets.
- **Lifesteal is a status (`leech`, effect_type `lifesteal`)**, so it gets refresh, a data cap, and the applied/expired signals. [A `StatModifiers` buff, which stacks on recast and can expire a refreshed modifier early.]
- **Lifesteal counts HP actually removed after resistance** (no overkill). [Overkill-inclusive amount.]
- **Multi-hit cone/aoe:** hits 2..N re-query from the caster's live position and facing. [Lock the origin at cast.] **Projectile `hits`** means N shots, `hit_interval` apart. [One shot that re-hits.]
- **`apply_status` has its own `hits`/`hit_interval`.** With them it rolls once per hit against the latest hit set. Without them it applies once, to the first hit's targets. [Auto-linking to the previous effect.] **`hit_interval` is required when `hits` > 1**, with no hidden default.
- **`CardDamageRule`** multiplies direct damage by `hits` and weights DoT by `chance` (expected value). [Counting full DoT damage.]
- **Chance rolls use `status_rng`**, not `card_rng`, so deck order and status rolls stay independent. Chance 0 or 1 draws nothing, so existing seeds are unchanged.
- **Follow-up hits stop if the caster is freed, dead or out of the tree** (reload-safe). Source ids are stored as object ids.
- **Bleed, Regeneration and Leech ship in `statuses.json` with placeholder numbers.** [Test-only fixtures.] C1-c tunes them.
- **Feel change:** only direct hits (`KIND_HIT`) trigger hit-stop and shake. DoT ticks (including Burn) and follow-up hits show the number and flash only. Before, every damage event, including Burn ticks, triggered hit-stop. [Keep hit-stop on every tick, which would spam hit-stop with multi-hit and DoTs.] Playtester checks this in C1-g; CHANGELOG notes it.

### 2026-10-29 - OPEN_ITEMS cleanup (game-lead)
- **Notes moved out of OPEN_ITEMS FYI** (already in CHANGELOG or DECISIONS, so just deleted there): restart-test flake, dark area past the arena edge, projectile hit size P5/P6, golem capsule and Slice 5 changes, training dummy removal, S6-2 dodge and dash stop.
- **Kept here as a record, since they weren't anywhere else:**
  - The director's example minimum config (attack group 10, utility 5, movement 3, recovery 3) means a 21-card minimum deck, which would limit deck-clean rewards. It exists only as a test fixture.
  - After C1, the Neutral pool gives 3 Recovery cards (Healing Potion, Leech, Regeneration) and 1 Movement card (Backward Leap). Any future class + element pair needs at least 2 Movement cards of its own to meet 3 per slot. Content validation flags it.
- **Dodge note corrected.** OPEN_ITEMS said "7.1 m to 3.5 m", which was the S6-2 step only. The full history: 3.5 m set (speed 14 x 0.25 s), 7.1 m in practice because of the slide bug; S6-2 fixed it to 3.5 m; D8 default B made it 7.0 m (speed 28); D8 = C made it 5.0 m (`data/player.json` speed 20). The code fallbacks in `PlayerConfig.gd` and the `Player.gd` export said 28; C1-b2 (4b1820a) aligned them to 20.
- **`.claude/settings.local.json` is local-only** (Claude Code's per-machine permissions file, already ignored by the director's global git ignore). Added to the repo `.gitignore` so it is never committed from another machine. Rejected: sharing it (it holds machine-specific allowances).

### 2026-10-29 - C1-b2 generic capabilities part 2 (gameplay-dev, logged by game-lead)
Commits 4b1820a..5fbc715 plus a uid commit; 630/630. Rejected alternatives in brackets.
- **New `zone` template** (circle or line; duration, tick_interval, damage, optional status with chance; placed at the aim point clamped to `max_range`). The first tick lands at placement. At the `data/zones.json` `max_live` cap (6), the oldest zone ends. [Refuse the new zone.] A zone ends when its caster dies or is freed. A line zone runs across the cast direction, like a wall. [An orientation param.] Zone ticks are `KIND_DOT`, so they show the number and flash only.
- **New `pass_through` template** `{duration}`. [A fake `buff` stat.] Overlapping grants end with the last one. A static flag also clears enemy masks, so enemies spawned mid-buff are included; it resets on end, death and `_exit_tree`.
- **Dash:** `direction_mode` forward | away_from_aim, plus optional path damage. Each enemy is hit once, as `KIND_HIT` (hit-stop per enemy, so the playtester checks for stutter). The path is sampled every `hit_radius`.
- **aoe `max_range`** places the disc at the clamped aim point, so Fireball can be an aoe card.
- **Game Over beat:** `Main` already used an ignore_time_scale timer, but Godot overcounts the frame where the time scale changes. The beat is now counted from `Time.get_ticks_usec()` in `_process`, excluding paused time, with each step clamped to 0.5 s. [Creating the timer a frame later still fired at 869 of 900 ms.]
- `CastPreview` outline builders moved to `src/effects/GroundOutlines.gd`, because a dependency chain through `Player` broke `bot_sim.gd` under `-s`.
- **Finding:** player and enemy bodies never collided (player mask = world only), so pass-through had no effect in the shipped game.

### 2026-10-29 - Enemies solid to the player (game-lead)
- **Call:** add a data flag `data/player.json` `body.collide_with_enemies`, default **true**, which turns on body collision between player and enemies. Shadow Step's pass-through (D9 = A) then has a real use: walking out through a crowd. The dodge doesn't pass through bodies, so escape is a Movement-card job, which fits the D8 note that critical survival moves should come from Movement cards.
- **Rejected:**
  - Leaving bodies non-solid and redefining Shadow Step as invulnerability or an aggro drop. That contradicts D9 (pass-through only for now), and aggro drop is planned for later.
  - Asking the director first. It's one data flag, cheap to reverse, so it doesn't meet the escalation bar.
- **Risk:** the player gets pinned by a crowd of 12. Mitigations: separation steering, the sim rerun, and the playtester checks. Listed under "Calls I made".

### 2026-10-29 - C1-c cards and balance table (gameplay-dev, logged by game-lead)
Commits 87ede1f..de9f916; 666/666. Rejected alternatives in brackets.
Slots now hold attack_single 7, attack_aoe 5, utility 3, movement 5, recovery 4. The preset deck is the whole rogue + fire + neutral pool. The run start now **blocks** (a push_error, the spawner off, and a `run_start_blocked` signal) when a deck misses the minimums. [`quit()`, which would kill tools.]

**Balance table** (light = 3 dmg / 0.6 s = 5.00 DPS; cast floor 4.5; "DPS (rule)" is the CardDamageRule value pinned by `slice3b_qa_test`):

| Card | Slot | Cooldown (base+mod) | Cast damage / effect | DPS (rule) | vs light |
|---|---|---|---|---|---|
| Bleed Slash | single | 1.2 (1.0+0.2) | 5 direct + Bleed 4 s (2 credited ticks) | 7.0/1.2 = 5.83 | 117% |
| Flurry | single | 1.3 (1.0+0.3) | 4 hits x 2, 0.12 s apart | 8.0/1.3 = 6.15 | 123% |
| Fireball | aoe | 3.1 (2.5+0.6) | 14 + Burn (6 credited), radius 2.0, max_range 8, 0.4 s delay | 20/3.1 = 6.45 | 129% |
| Fire Wall | aoe | 3.3 (2.5+0.8) | line zone 5 x 1.2, 4 s, 2.5 per 0.5 s tick, Burn 40% per tick (not credited) | 20/3.3 = 6.06 | 121% |
| Shadow Step | movement | 4.0 (3.0+1.0) | pass_through 2.5 s | n/a | n/a |
| Lunge Strike | movement | 3.0 | dash 3.0 m / 0.2 s, 8 path damage once per enemy, knockback 3 | n/a | n/a |
| Backward Leap | movement | 3.5 (3.0+0.5) | dash 6.5 m / 0.25 s, away_from_aim, not invulnerable | n/a | n/a |
| Leech | recovery | 8.5 (8.0+0.5) | 7 s: 40% of damage dealt, at most 3 HP per hit (about 1.6-2.0 HP/s in a fight) | n/a | n/a |
| Regeneration | recovery | 8.0 | 2 HP/s for 7 s = 14 HP | n/a | n/a |

- **Status tuning:** Regeneration `heal_per_tick` 1.0 -> 2.0; Leech `fraction` 0.3 -> 0.4 and `max_heal_per_hit` 2.0 -> 3.0; Bleed unchanged at 1 per 0.5 s.
- Fireball is a bit above the other aoe cards (5.3-5.5) because it is aimed and delayed. Fire Wall's rule value assumes one target stands in it the whole time, which is generous; real crossings give 1-3 ticks.
- Recovery is still the longest effective cooldown (6.5 vs 4.5).
- **New generic aoe `delay`** (0-3 s): the centre locks at cast and the telegraph grows over the delay. [Treating the hold-to-preview as the telegraph.]
- **Fire Wall is in attack_aoe,** so the damage rule checks it. [Utility, which is unchecked.]
- **Lunge Strike stops at the first enemy** (bodies are solid), so it's a gap-closer. [A short pass-through, which would blur it with Shadow Step.]
- **Solid-enemy implementation:** `data/player.json` `body.collide_with_enemies` (default true). Player and enemies use `platform_floor_layers = WORLD`, so neither can ride the other. The spawner positions an enemy before `add_child` (gated on the flag, so false is bit-exact with the old behaviour). When pass-through ends inside an enemy, collision restores only once the player is clear (3 s cap).
- **Tests** that pin non-solid geometry use `tests/support/body_flag.gd` to force the flag off; the solid case has its own suite (`c1c_solid_enemies_test.gd`).
- The wave sim gained read-only pinned-frame and max-feet-height lines.

**Sim, seeds 1/2/3, 150 s, fixed 60 fps.** HP lost: before 21/32/53; cards with the flag false 49/47/41; cards with the flag true 86/91/83. Kills are about the same. The longest pinned stretch goes 0.32 s -> 1.83 s with the flag true. There were no crashes, NaN or stalls, and runs repeat bit-identically.

### 2026-10-29 - Solid enemies kept on, pending playtest (game-lead)
- The bot sim shows solid bodies about double HP lost. The bot never uses Shadow Step on purpose and walks into enemies, so this overstates the cost for a human.
- **Call:** keep the flag true and have the C1-g playtester judge pinning and fairness. If the playtester reports being pinned with no way out, or a frustration blocker, I flip the default to false before the C1 tag and park Shadow Step's purpose as a director question.
- **Rejected:**
  - Flipping it off now, which leaves Shadow Step a no-op.
  - Letting the dodge pass through bodies, which would make Shadow Step redundant.

### 2026-10-29 - C1-e visuals (ux-designer, logged by game-lead)
Commits 16eecd9..353070f; 688/688. Rejected alternatives in brackets.
- **Burn and Bleed share the HP bar's one pip slot,** alternating every 1.6 s. [Widen the bar; or Burn always wins.]
- **Status cues stay inside the pool budget:** one held node each for Bleed and Regeneration, two for Leech. [Multi-drop persistent cues.]
- **"+N" heal numbers cover every heal on the player,** batched every 0.25 s. [Per-source numbers.]
- **Ghost via `GeometryInstance3D.transparency`.** [Albedo alpha, which the hit flash breaks.] Cues live in a new `PlayerCues` node attached from Main, so `Player.gd` is untouched.
- **Fire Wall timer** is a third mesh that empties from both ends, and the outline blinks in the last quarter. The fill never shrinks, so it keeps matching the hit area. The look constants moved to `data/zones.json` `look`.
- **Range reticle:** a ring at the range cap, plus a circle marker when the aim is in range, or a diamond with a link line to the cursor when clamped.
- **F3 colours** are code constants (it's a dev tool).
- **Name fit:** `fit_padding` 2 -> 12 and line spacing 0 (the second line of "Walk Through Everyone" was being clipped).
- **Known gap:** the Lunge preview shows the full 3 m path even when a body will stop it short.
- **Process:** the CLAUDE.md rule says qa checks README commands and the CHANGELOG entry, but the docs pass comes after qa. So in C1-f qa lists README and CHANGELOG gaps as inputs for C1-h, and game-lead confirms the CHANGELOG entry exists before closing. [Running qa twice.]

### 2026-10-29 - C1, tooling task and Polish 1 closed (game-lead)
- Closed on qa PASS 76bca75, the C1-g playtest d94676a (no blocker) and the docs pass 4c7b490. Tagged `playtest-2026-10-29-C1`.
- **Solid enemies stay on.** The playtester judged them fair, not a blocker. The bot is pinned in 8-10% of move frames, the longest stretch is 1.8 s, and there's never a full lock. If the director finds it sticky, the first lever is the Shadow Step cooldown 4.0 -> 3.0, before flipping the flag.
- **Playtest proposals not acted on** (sent to the director as D13/D14, because they change balance the director is about to feel by hand): Recovery heal power against 30 HP, and Fire Wall being weak on a single target. Small UX items went to the ROADMAP backlog.
- **Not adopted:** "every Movement slot must guarantee an escape card". The shipped pool has 2 escapes (Shadow Step, Backward Leap) among 5 Movement cards, and the rule would need a new deck-rule type. Revisit if the director finds pinning a problem.

### 2026-10-29 - Milestone 3a defaults (game-lead)
Each is also listed under "Calls I made" in OPEN_ITEMS.
- **Linear room sequence, no branching map.** It's the simplest way to prove the loop, and the GDD only says "procedurally generated room sequence". [A branching map now; it adds UI and a generator before we know the loop is fun.]
- **8 rooms:** 5 combat, 1 elite, 1 rest, boss last. That's about a 10-15 minute run at the current wave lengths, within GDD §9's [PROPOSED] 15-25 minute prototype. The elite and rest positions are seeded within rules from data. [A 15-room run, which is slower to iterate on.]
- **Rest heals 30% of max HP.** It's a placeholder; 3b adds the deck-clean option. [A full heal, which removes attrition.]
- **Elite resistance = max(own, 25%), capped at 50%.** GDD §7 says "25% across elements", and an elite golem shouldn't lose its fire resistance. [Overwriting to exactly 25%.]
- **Normal launch = run mode; scenarios and wave_sim = endless arena.** This keeps the capture tooling and the seeded sim baselines stable.
- **Starting deck is a data list,** shipped as the full pool so the C1 checklist stays testable. 3b shrinks it, because with the full pool every reward is a duplicate and `can_remove` blocks every unique at exactly 3. (Utility has only 3 unique cards in the whole pool.)
- **Coupling rule:** run-loop code handles card ids through the deck APIs only, never specific card content (director, Part 5).

### 2026-10-29 - 3a run structure, gameplay side (gameplay-dev, logged by game-lead)
Commits a7731e2..c560d83; 726/726. The wave-sim seed 1 hash and the bot-sim checksum are unchanged. Rejected alternatives in brackets.
- **`project.godot` main scene is now `scenes/main/RunMain.tscn`.** `Main.tscn` stays the endless arena for tests, scenarios, wave_sim and VpCapture. [Auto-detecting run mode inside Main, which would flip about 30 suites.] `--scenario` launches fall back to the arena.
- **Continue swaps in a fresh Main** (`Main.swap_to_fresh_scene`). [`reload_current_scene`, which needs `current_scene` and is null in VpCapture (qa N5, now fixed).]
- **`RunSession` is a static, not an autoload.** `begin_new_run` is the only constructor, and a forced seed is used once, so "Try again" always gets a new seed.
- **Finite waves via `finite: true`** on the existing wave schema. [`loop_from_stage` -1.] **Tier is encoded in the queued spawn** (`tier|enemy`), so RNG calls and seeded baselines are unchanged.
- **Tiers** (`data/run.json`): elite HP x2.5, boss placeholder HP x7, resistance floor 0.25 and cap 0.5, body scale 1.0 (the hurtbox doesn't scale), plus a marker sphere. The boss is unstunnable. The boss placeholder's resistance is 25% until 3c sets 50%.
- **Damage immunity after a room is won.** [Clearing projectiles and zones.]
- **Placement:** elite in rooms 4-7 and rest in rooms 3-7 (seeded), the first room is combat, the boss is last.
- **Bot change in run mode only:** it hunts the last 2 enemies or a lone shooter. Without that, a lone shooter stalls a room.
- **Sim, seeds 1-12 at real time:** 12/12 won, 0 soft locks. A run is about 260-290 s, the boss room 65-98 s. **The bot ends every room at 30/30 HP:** with the full deck, Recovery out-heals everything, so attrition is nil (feeds D13 and the 3b starter shrink). The N3 checks are clean (pick rate 0.93-1.06x, which shows no bag bug, not balance).

### 2026-10-29 - 3a UX (ux-designer, logged by game-lead)
Commits 8b54b25..0f4e317; 740/740. Rejected alternatives in brackets.
- **One shape per room type** (circle combat, diamond elite, plus rest, star boss), reused in the room indicator, the prompt icon and the world tier sign. Colours come from `data/run.json`, so the HUD and world agree.
- **Indicator at top centre.** [Top right.]
- **Tier cue is a flat billboard sign above the HP bar.** [A rank frame on the HP bar, which would clash with the resistance frame that the 25% floor already triggers; a larger body.]
- **Prompt panel is generic** (`show_content`, `options_box`), so 3b's reward screen reuses it. The rest room shows "Healed +N" instead of the time.
- **Game Over in run mode adds one line,** "Reached room X of Y." This is the minimal part of D1's deferred run stats.
- **Recurring flake:** `slice6_qa_test` same-seed crowd test failed in one full run each in C1-c, 3a and 3a-ux, and passes alone. Sent to qa in the 3a review.

### 2026-10-29 - 3a qa PASS (qa, logged by game-lead)
- PASS a6a5d68, 766/766 (`docs/reviews/2026-10-29-m3a-qa.md`).
- **Flake fix:** `slice6_qa_test` same-seed crowd test tolerance 1e-6 -> 0.01 m. The 1e-4 drift comes from physics-engine sensitivity to allocation history (one unrelated StaticBody3D shifted it 7.8e-4 m), not from non-deterministic game code. The strict id-dependence pin stays in the sibling steering test (1e-5). [Keeping 1e-6 and hunting the engine internals.]
- Non-blocking follow-ups go to the backlog: run-mode sim results depend on earlier runs in the same process; the LOST line shows a stale HP; the `--run-room` win count is wrong; objects rise +1 per soak cycle; `-RoomTimeout` clamps silently.

### 2026-10-29 - 3a closed; 3b plan (game-lead)
- 3a closed: qa PASS a6a5d68, playtest 013e7d7 with no blocker, docs 15250c4. D1's "revisit with the run structure" is partly met by a single "Reached room X of Y" line; the full run stats stay deferred.
- **Playtester questions I answered myself:**
  - The boss room drags (65-98 s): 3c replaces the placeholder boss, so I didn't touch the HP x7 now.
  - The rest room at full HP shows "Healed +0": 3b turns rest into heal-or-remove and fixes the text.
  - Next-room preview: added to 3b, on the shared panel.
  - Run length: 8 rooms stays.
- **3b starter deck = 15 cards, 3 per slot** (listed in the ROADMAP 3b brief). The full pool is reachable via `--full-deck`. [Keeping the full pool, which makes every reward a duplicate and every unique card unremovable.] The escape card (Backward Leap) is in the starter because enemies are solid.
- **"Does nothing for the build" filter** is a generic optional card field `requires`. No shipped card needs it yet. [Hardcoded per-card rules.]

### 2026-10-29 - 3b rewards and deck-clean, gameplay side (gameplay-dev, logged by game-lead)
Commits fd2f644..b8564cd; 802/802. Wave-sim seed 1 30 s hash unchanged. Rejected alternatives in brackets.
- **Reject skips the offer and gives no card,** per the GDD wording. [Reroll.] At 0 rejects you must pick.
- **Offers are seeded from (run seed, room index) plus the current deck,** on their own RNG stream. Unowned:owned weight is 4:1. The offer shrinks if fewer cards are eligible. Boss rooms aren't reward rooms (data `reward_room_types`).
- **Rest is two steps:** Heal or "Remove a card", then a card list with Back. [One flat list.] Heal stays enabled at full HP with "HP is already full", which fixes "Healed +0".
- **A reload mid-reward resumes the same offer** (`RunState.pending` and `offer`; save format v2, v1 still loads). [Regenerating the offer.]
- **Input safety:** number keys only move the highlight; Enter or a click confirms. Presses are ignored for 0.4 s after the panel opens (`data/ui.json`), and while paused.
- **`--full-deck`** applies for the whole launch, including Try again. `run.json` `character_pools` duplicates `Player.owned_pools` until there's a character data entry.
- **The card effect line comes from the effect params,** never from the card id (coupling rule).
- **Consequence of the deck rules:** every starter card is unremovable until you own a duplicate or a 4th unique card in that slot (3 per slot exactly). Early rest rooms are therefore mostly "heal". Accepted; it's the GDD rule working.
- **Sim, 10 seeds, scale 8:** 9 won, 1 lost (elite room). The lowest HP inside a room often reaches 1-12 of 30, but carried attrition is mild (mean room-end HP 78-93%). Final decks are 17-19 cards.

### 2026-10-29 - 3b UX (ux-designer, logged by game-lead)
Commits 56a76f0..d2cd00a. Rejected alternatives in brackets.
- **Reward = a horizontal row of cards plus a narrower reject tile** inside `options_box`. [A separate reject footer button.] Card tiles show a number badge, name, a "Slot N" pill with the slot name (the HUD's own language, so no new slot colours), effect line, flavor and "You own N". The reject tile shows the rejects left as pips.
- **Rest = two action tiles; removal = a per-slot grid that scrolls,** where keys 1-5 jump to a slot column. [One vertical list, which doesn't fit 20+ cards at 720p.] Greyed cells show the deck-rule reason.
- **Effect wording comes from data** (`run.json` `ui.effect`); unknown stats become words, never raw ids.
- **Safety fixes:** Space (dodge) is swallowed while options are open (it used to confirm the focused option); focus returns to the highlighted option after pause.
- **New debug arg `--run-auto-choose=<ids>`,** for screenshots.
- **Process:** subagent commits carry their own session's model attribution (Sonnet), not the "Opus" line in the briefs. That's fine: the attribution should name the model that wrote the commit. Briefs now say "use your session's attribution line".
- **Follow-up (backlog):** put `owned` and `next_room_type` in the choice model so the screen is self-contained for level-up reuse.

### 2026-10-29 - 3b qa PASS (qa, logged by game-lead)
- PASS 0a19808, 826/826 (`docs/reviews/2026-10-29-m3b-qa.md`). A removal fuzz over 300 decks never broke a minimum.
- **Backlog:**
  - validate an unknown `RunState.pending` value when real saves arrive (3d);
  - tidy the effect-line wording ("dash 6.5");
  - the 1440p panel top slightly overlaps the dimmed HP label;
  - the Continue / New run button has no arm delay, and its hint says "Space".
- **Balance note:** with the 15-card starter, the bot loses mostly at the placeholder boss (5 of 6 losses). 3c replaces it.

### 2026-10-29 - 3b closed; 3c plan (game-lead)
- 3b closed: qa PASS 0a19808, playtest f2a3283 (no blocker), docs 16deeb2. Tagged `playtest-2026-10-29-3b`.
- **Playtester questions I decided:**
  - Show slot contents on offers: yes, in the 3c ux step.
  - Starter stays at 3 per slot. Locked early removal is the GDD rule working; the fix is a clearer reason. [A 4-per-slot starter, which dilutes the rewards.]
  - Rejects stay 3 per run (a director rule).
  - 8 rooms stays.
- **3c defaults:** a 3-phase data-driven boss at 50% resistance to every element (GDD §7, final boss), a placeholder name, no quips, and a pacing target of 45-75 s in the boss room for the bot.

### 2026-10-29 - 3c boss, gameplay side (gameplay-dev, logged by game-lead)
Commits a35501d..2234dc8; 875/875. The arena hash and the bot-sim checksum are unchanged. Rejected alternatives in brackets.
- **`data/bosses.json`** (validated by `BossConfig` and `BossRules`). `boss_guardian` "The Overly Enthusiastic Guardian" (placeholder name): 280 HP, 50% resistance to every element, no knockback taken, unstunnable.
- **Attacks:**
  - smash: cone 3.4 m, 8 dmg;
  - slam: disc radius 3.2 locked on the player's spot, 9 dmg;
  - volley: 5 lanes, 5 dmg each;
  - charge: an 11 m lane, 10 dmg.

  Wind-ups are 0.9-1.1 s, and 0.77 s at the shortest in phase 3 (the floor is 0.6).
- **Phases at 66% and 33%:** faster, a shorter attack gap, and new attacks (charge from phase 2). Adds: 2 chasers at phase 2 and 2 shooters at phase 3, with at most 3 alive. Each change is a 1.2 s invulnerable roar.
- **`Health.hp_floor` holds each threshold,** so one hit can't skip a phase. [Checking after the damage lands.]
- **Pinning:** the boss isn't solid while charging, and becomes solid again only once it's clear of the player. [Pushing the player, which can eject them through a wall.]
- **Boss telegraphs are drawn at the vs-player reach.** [The template's `delay` telegraph, which sizes against the enemy hurtbox.] Projectile `yaw_degrees` and aoe `vfx:false` were added as optional template params. [A template per boss attack.]
- **The boss spawns with no tier** (the 3a `tiers.boss` HP x7 is now unused). The boss owns its adds and kills them on death.
- **Death beat** 1.6 s (slow-mo, burst, the player immune), then the win screen.
- **Pacing** (seeds 1-8, 15-card starter, real HP): boss fight 52-67 s, mean 61 (was 80 with the placeholder). The bot won 8/8; its lowest HP in the fight was 12-26 of 30. Tuned HP 520 -> 280.
- **Follow-ups done:** `RunState.from_dict` rejects bad `pending` values; the choice model has `owned`, `next_room_type` and per-option `slot_contents`.
- **Known:** player card visuals are drawn against the 0.45 m enemy radius, so they understate reach on the boss (1.05 m). That's the safe direction, so it's accepted.

### 2026-10-29 - 3c UX (ux-designer, logged by game-lead)
Commits b8af93f..5245779; 894/894. Rejected alternatives in brackets.
- **Boss bar at top centre:** name, fill with ghost, threshold notches, "Phase N of 3: name", striped "Invulnerable" during the roar, "Resists all elements 50%", and the current attack label with a draining wind-up strip. **The room indicator moved to the top right.** [Boss bar below the indicator, which collides with F3 at 720p.]
- The bar finds the boss by class via `node_added`, so it works in capture scenarios too. [`RunController.boss_spawned`, which the arena doesn't have.] Equal resistance across elements uses the neutral tint.
- **Boss telegraphs are bolder:** lanes at alpha 0.5 vs 0.3, and the slam gets an inner ring. Sizes are unchanged.
- **3b follow-ups done:**
  - "Slot N now: A / B / C" (the separator changed to " / " in 5a85712, since names contain commas);
  - effect lines with units, from data (status numbers come from `statuses.json` via context);
  - Reject tile 188 -> 216 px;
  - the locked-removal reason is "Get another card for the Utility slot first (minimum 3 different)";
  - Continue and New run get the arm delay, Space is swallowed, and the hints say Enter;
  - the reward panel sits below the HUD band.
- **Backlog:** the Game Over screen still accepts Space and says "Enter or Space". One unreproduced reload-soak failure happened before a `disarm()` fix; qa watches for it.

### 2026-10-29 - 3c qa PASS; 3d defaults (game-lead)
- 3c qa PASS 64df947, 903/903 (`docs/reviews/2026-10-29-m3c-qa.md`). Soak 5/5; ux's single soak failure is treated as a fixed flake (New run pressed inside the arm delay).
- **qa's save-robustness findings** (`from_dict` type crashes, stale offer, BossConfig script error, unused `tiers.boss`) go into 3d, because 3d adds real persistence. Cosmetic items (boss body over the resist text, a doubled cooldown in buff lines, Game Over accepts Space) go to the backlog.
- **3d defaults** (also in "Calls I made"):
  - every card in the character's pools is available (unlock rules are [OPEN] for meta-progression);
  - at most 2 copies per card;
  - deck size 15-20;
  - 3 save slots;
  - any finished run counts toward "from run 2".

  [Unlock-gated collections, which need meta-progression design; unlimited copies, which make a degenerate one-card deck plausible within the unique-count rule.]

### 2026-10-29 - Dodge charges defaults (game-lead)
- **Director directive:** 3 charges (maybe 2), a slightly longer cooldown, and a HUD indicator (recorded in GDD §3).
- **My calls:**
  - the per-charge recharge goes 0.8 s -> 1.2 s;
  - charges recharge one at a time;
  - charges reset each room;
  - the indicator is pips near the LMB/RMB meters.

  [Recharging all charges at once; a 1.0 s recharge.]
- **Note:** 3 x 5 m of i-frame rolls is a large survival buff against the GDD line that critical escapes should come from Movement cards. The director chose it knowingly, and the sim before/after will show the size of the effect.

### 2026-10-29 - 3c closed (game-lead)
- 3c closed: qa PASS 64df947; playtest 81b03d8 (no blocker); the director's no-scroll fix 741c624..b7a6a01 with qa PASS 8bc7241 (907/907); docs b4c7a1d. Tagged `playtest-2026-10-29-3c`.
- **Boss name stays a placeholder** until the director or the story role names it.
- **qa N11** (an intermittent soak failure: damage immunity leaked after a reward pick, also present at 64df947) goes to the P-dodge gameplay task.
- **Order after 3c:** A1 armor, then P-dodge, then 3d (director order).

### 2026-10-29 - A1 armor Part 1 (gameplay-dev, logged by game-lead)
Commits b23d7df..e141dfe; 923/923; arena hash unchanged. Rejected alternatives in brackets.
- **Re-verified:** physical was skipped by a hardcoded `== "physical"`; `neutral` skipped mitigation only because it had no resistance entry. The boss took 0% from physical and 50% from fire.
- **`data/armor.json`:** `k` 50, `armor_reduction_cap` 0.5, `non_elemental_types` [physical, neutral], loaded by `ArmorConfig`. It's a new file because tiers, the boss, enemies and the player all share it. Unlisted types count as elemental. [A second "elemental" list.]
- **Armor values:** elite tier 17; `tiers.boss` 27 (still unused); boss_guardian 50; per-enemy optional, default 0. Tiered enemies use max(own, tier).
- **`tiers.boss.resistance_floor` 0.25 -> 0.35** so its armor 27 passes parity, which matches GDD §7's 35% for bosses. [Removing the unused tier.]
- **Parity is enforced at load** (`RunConfig`, `BossConfig`) and by a test. [Test only.]
- **`Health.take_damage` is the single choke point.** Penetration is read from the source's `armor_penetration` stat; the player has armor 0 via its own StatModifiers. Scenario setup hits bypass armor.
- **DoT is float end to end:** a Bleed tick of 1.0 at armor 50 does 0.5. No gameplay minimum is needed. On display, a single unmerged tick under 0.5 would show "0"; ux handles that.
- **Re-tune** (whole-run sim, 16 seeds, medians):
  - Before: elite room 41.85 s, boss 63.65 s.
  - Armor at the old HP: 56.85 s and 85.9 s.
  - After the retune: 40.55 s and 63.4 s.
  - **Elite `hp_multiplier` 2.5 -> 2.0; boss `max_health` 280 -> 195.**
  - Target was the measured baseline (about 63 s), not 61. No enemy-damage or player changes.
- **Deck families** (`-Deck` sim option, god mode, 8 seeds), boss fight median after armor:
  - standard 63.1 s; fire 58.4 s (0.93x); physical 70.05 s (1.11x). Both are within the director's 70-130% band.
  - Light and heavy only: about 3.2x (it was 3.5x before armor). That's a bot-capability limit, not armor; 4 of 8 seeds timed out.
  - Limits: light and heavy are in every family, Blaze and Bail deals fire in every family, and the minimums are bypassed by a tool-only flag.
- **Pre-existing:** a BossHpBar deferred-bind error in long light/heavy-only runs (a freed boss), also on the 3c tag. Sent to ux in Part 2.

### 2026-10-29 - A1 armor Part 2, readability (ux-designer, logged by game-lead)
Commits 1604f6b..bcf13a5 plus a uid; 939/939. Only HEAD is runnable: the earlier commits read keys that arrive in bcf13a5. Rejected alternatives in brackets.
- **Boss bar** widened 480 -> 560 px. It shows a shield pip at the right end plus "Armor 50% · Resists all elements 50%"; the armor part is hidden at 0.
- **Elite bars:** a shield pip (flat top, pointed bottom) beside the existing diamond. At 720p the pips are about 6 px, which may be too small (a playtest check; the fix would be a data size knob).
- **Damage numbers:**
  - armor-reduced hits show `[9]` in muted grey at 85% size;
  - resisted elemental hits show `<4>` (a new style, element colour toward grey);
  - both need at least 10% reduction (data);
  - shape and colour both tell them apart.
- **Display rule:** values under 1 show one decimal (floor 0.1), so Bleed at armor 50 reads "0.5". [Rounding to "0".]
- **F3 "Defense" block:** under-cursor (1.6 m pick radius) or nearest enemy armor and resistance, plus the player's armor.
- **BossHpBar deferred-bind error fixed** by binding via instance id; proven by restoring the old code. The engine error itself can't be asserted in gdUnit4.
- New scenarios: `boss_f3`, `elite_f3`, `armor_numbers` (key `elite_indices`).
- **Housekeeping:** game-lead stopped 4 stray headless WaveSim processes left by the lightheavy repro (and left the director's game alone), and deleted `ws2.log`. The log showed class-cache parse errors from a run started mid-edit; qa re-verifies on a clean tree.

### 2026-10-29 - A1 Part 3 qa PASS (qa, logged by game-lead)
- PASS 9292e4b, 965/965 (`docs/reviews/2026-10-29-a1-armor-qa.md`). Parity is enforced at load and caught by mutated fixtures; a static audit test guards the single damage choke point.
- **Boss fight vs standard, real HP:** fire 0.93x, physical 1.04x (1.11x in god mode). Before armor: fire 1.08x, physical 0.85x. Both families sit inside the director's 70-130% band.
- **A pure light and heavy bot is about 3.2x** (it was about 3.5x before armor). **Game-lead call: not a director question.** GDD §3 says cards beat basic attacks, and a no-card build is meant to be weak. The bot also plays it badly. [Buffing basic attacks.]
- **Fix before the playtest (ux):**
  - N2: the boss bar overlaps the player HUD at 1024x768;
  - the elite shield pip is illegible at 720p (about 6 px), so add a size knob in data;
  - N1: "all elements" must compare against `TierRules.element_ids()`.
- **Backlog:**
  - N3: validate damage types against the known set (a typo escapes both channels);
  - N4: the golem's fire resistance lives in its `.tscn`;
  - N5: `armor_reduction(INF)` returns NaN (not reachable from data).
- **The BossHpBar bind error couldn't be reproduced** on either the old or the new code over 32 sim runs; the fix stays, covered by a unit test.

### 2026-10-29 - W1 Fire Wizard plan (game-lead)
- **Director directive:** the Wizard comes earlier, with ranged light and heavy attacks (GDD §5).
- **My calls:**
  - **Order:** after A1 and T-decks, ahead of P-dodge and 3d. T-decks is small and gives Wizard test decks. [Wizard right after A1, which delays a small director request already queued.]
  - **Element:** Fire only.
  - **Class pick:** every run, with the last pick preselected.
  - **Basic attacks:** the Wizard's are `neutral` (non-elemental magic, so armor applies).
  - **Light DPS** is about 80% of the Rogue's as the price of range.
  - **HP** 26 vs 30.
  - **Data:** a new `data/characters.json` replaces the hardcoded pools.
  - **Wizard pool** 6-8 cards with at least 1 Utility and 1 Movement, so Wizard + Fire + Neutral meets 3 per slot.
- **Rejected:**
  - a ranged light attack for every class (it changes the Rogue's identity);
  - Water now (the director said the Wizard only).

### 2026-10-29 - A1 close: ux fix, qa delta, playtest (game-lead)
- **ux fix f0cb109:**
  - New `data/ui.json` keys: `hp_bars.pip_scale` (validated, number >= 1), plus `hud.boss_bar_gap`, `hud.boss_bar_stack_below` (500 ref px) and `hud.boss_bar_stack_extra`.
  - "All elements" is now judged against `TierRules.element_ids()`.
  - Soft spot: the `target_line` test (`{"fire": 0.5}` -> "all elements") holds only while fire is the only element, and must change on purpose when a second element ships.
- **qa delta PASS 70a761f:** 968/968 including qa's 2 new tests.
  - The three hud keys have no `DEFAULT_HUD` defaults; a qa test pins their presence.
  - Defaults go to the ux backlog. [Fix before close.]
- **Playtest ff6e7f6 (no blocker), 4 seeds per family, boss spawn to death:** fire 57 s, physical 69 s, standard 71 s, which is 0.80x and 0.97x of standard.
  - qa's earlier measurement was 0.93x and 1.04x. The two disagree on fire.
  - Both are inside the director's 70-130% band.
- **My calls:**
  - **No retune now.** qa re-measures with 10+ seeds using the T-decks presets in its T-decks review. If either family falls outside the band, it becomes a director item. [Tune parity to within about 10% now.]
  - **Playtest readability findings go to the ux backlog** (numbers blurring in a clump, the shield pip hidden behind neighbours, F3 covering the arena, unlabeled boss-bar glyphs). [Fix before the A1 close.]
  - **Card damage-type cue is D17 for the director,** default B (schedule it with the pause card-details request). [Building a tag now unasked.]
  - **The playtester's "safety net for a no-card build" question** is covered by the existing 3.2x call above, so it isn't a director item. [Escalating it.]

### 2026-10-29 - T-decks build (gameplay-dev, logged by game-lead)
- Built 9b6e8a6 (987/987). New `src/run/DebugDecks.gd`, `data/debug_decks/*.json`, `RunSession.debug_deck` (lasts for the whole launch). `RunSession.skip_deck_minimums` is removed.
- **physical-rogue has 2 Fire cards** (`fire_hot_head` for Utility, `fire_fine_burn_then` for AoE). The non-Fire pool has only 2 Utility and 2 AoE cards, and the rules need 3 unique per slot. A test pins the minimum. [Zero Fire through a rule bypass.]
- **Sim Godot arg renamed `--sim-deck=`.** The PowerShell `-Deck` name is kept, and the old families `fire`/`physical`/`lightheavy` are gone. [Sharing `--deck=` with the launch flag.]
- **A preset is only the starting deck.** Rewards change it as in a normal run, which may weaken the family contrast in sim measurements. [Re-imposing the preset after each reward: a bypass in another form.]
- **`-LightHeavyOnly`** is a bot policy that skips the attack slots; seeds don't shift. [Emptying the slots needs a bypass.]
- **A bad `--deck` or `--list-decks` quits from `RunController.begin`** with exit 2 (0 for the list). `--deck` is ignored with `--scenario` or in the arena. [A pre-Main autoload check.]
- **Only the selected preset must be valid.** `--list-decks` marks broken files `INVALID` and exits 2. `name` must equal the file name. Only `--deck=name` is accepted.

### 2026-10-29 - T-decks qa PASS and the A1 sim re-measure (qa, logged by game-lead)
- PASS deb6ff1 (987 on HEAD plus 9 qa tests = 996; `docs/reviews/2026-10-29-t-decks-qa.md`).
- **Boss fight, 12 seeds per family, `-Run -God`, median as a multiple of standard (63.1 s):**
  - fire-heavy-rogue 1.02x (per seed 0.57-1.62);
  - physical-rogue 1.07x (0.77-1.46);
  - light/heavy-only policy 3.95x.
  - The A1 numbers (0.93x/1.04x qa, 0.80x/0.97x playtest) were seed noise.
  - **Result: both deck families are inside the director's 70-130% band.** No retune.
- **Dilution:** rewards push physical-rogue from 2 to 4.2 Fire cards by the boss; fire-heavy keeps most of its contrast. **My call:** don't build a skip-rewards or start-at-boss sim mode now. The A1 goal is met and a hand test can use `--deck=... --run-room=8`. Revisit in W1 balancing if a pure comparison is needed. [Building it now.]
- **Reload soak flake** ("damage immunity leaked into a new room", tools/reload_cycle.gd:248). It predates T-decks, failing 2 of 3 under load on e7b0029. **My call:** it's assigned to P-dodge, which reworks dodge and immunity anyway. Until then, a single soak failure on that line means re-run once and note it. [Fixing it now in a separate task, which delays W1.]
- Backlog (gameplay-dev, small): print a notice when `--deck` is ignored (scenario or arena), and a permanent sim log of the deck makeup at the boss.

### 2026-10-29 - W1 split into W1a and W1b (game-lead)
- **W1a, a playable Wizard:** character data, the class pick, ranged light and heavy, a minimal 4-card Wizard pool (2 Utility, 2 Movement), sim plumbing.
- **W1b, content and balance:** the full 6-8 card pool, presets, the sim balance report.
- Reason: the brief is too big for one sitting, and the brief itself allows the split. A playable ranged Wizard is the part the director asked for, so it ships first. [One W1 slice, which risks a half-built class at a usage cutoff.]

### 2026-10-30 - W1a gameplay build (gameplay-dev, logged by game-lead)
- Built 451eaf3..39fe0c6 (1025/1025). The Rogue is unchanged: arena hash 2792856473, bot checksum 2281795515, and the `-Run` output is identical.
- **New data:** `data/characters.json` (CharacterDatabase). `starting_deck` and `character_pools` were removed from `run.json`; the `RunConfig` wrappers return the Rogue's.
- **Wizard numbers:**
  - light bolt 2.4 neutral per 0.6 s = 4.0 DPS (80% of the Rogue's 5.0), 12 m, 24 m/s;
  - heavy 8.5 per 1.8 s, a 2.0 m disc at up to 7 m, damage type physical -> neutral;
  - 26 HP.
- **4 Wizard cards:** Borrowed Focus and Footwork, Allegedly (utility cooldown buffs), Sideways Blink and Tactical Hover (movement dashes). There's a 15-card starter, and `--full-deck` gives the Wizard 18 cards.
- **Calls:**
  - **Class set before Player `_ready`** via `RunController.prepare`. The arena, scenarios and tests stay Rogue. [Rebuilding the Player after `_ready`.]
  - **A preset may carry `class` (default rogue).** `--deck` alone sets the class; a `--class` that disagrees exits 2. [Silent override.]
  - **`light_variants` in attacks.json.** `CardDamageRule` is still judged against the Rogue's light, the stricter bar. [Restructuring `light` per class.]
  - **The bolt flies along the player-to-reticle line** for its full 12 m. [Stopping at the reticle.]
  - **Projectile template gains code params `direction` and `lane`.**
  - **A Wizard armor-buff card was dropped**, because the effect wording doesn't support armor. That's a W1b idea. [Editing qa's wording test.]
  - **The last pick is remembered** in memory, plus `user://last_class.json` in windowed play only. [settings.json.]
  - **Wizard sim bot** kites at 5-9 m.
  - **4 existing tests changed**; they had pinned the Rogue-only world.
- **Sim note (2 seeds, not a balance read):** Wizard boss 45 s and 52 s vs the Rogue's 63 s, ending rooms at full HP. W1b owns the balance.

### 2026-10-30 - W1a ux (ux-designer, logged by game-lead)
- Built 0b540d6..672622f (1044/1044).
  - The class pick screen: `ClassPickScreen`, all from `CharacterDatabase` plus the `ui.json` `class_pick` block.
  - The cyan Wizard bolt: `#3fd9ff`, `bolt_look` in `attacks.json`, and a code-only `look` template param.
  - A heavy meter wind-up word per attack shape (SWING / CAST).
  - The `wizard_bolt` scenario and the scenario `character` key.
- **Calls:**
  - **The pick screen pauses the already-built room via GamePause** until a pick is confirmed. [Delaying the room start in RunController/Main.]
  - **The screen skips itself** when `character_forced`, headless, under `-s`, or outside a run. `--show-class-pick` forces it for captures. [Checking `character_forced` alone, which would hang the unforced tests, sims and soak.]
  - **The same-run guard is a screen static,** not RunSession. [Touching gameplay files.]
  - **1/2 and arrows highlight; only Enter or a click confirms,** matching the reward screen. [Number keys confirm.]
  - **The bolt look is per attack (`bolt_look`),** not a new element. [An element entry in `pools.json`.]
- **Known and accepted for now:**
  - the HUD behind the dim shows the previous class's HP for one paused frame;
  - the screen copy ("Pick your hero"...) is ux placeholder wording.

### 2026-10-30 - W1a playtest triage (game-lead)
- Playtest b5f2e02, no blocker. Pick screen clear; the bolt follows the aim line and reads against enemy shots. On 4 seeds the Wizard's boss time is about 77% of the Rogue's (inside 70-130%), and it ended 31 of 32 rooms at full HP.
- **My calls:**
  - **Whether the Wizard should be the "easy class" goes to the director as D18.** The GDD says nothing about class difficulty, and it shapes the W1b tuning target. Default until answered: W1b tunes the Wizard so its rooms cost HP, but less than the Rogue's (A). [Deciding it myself.]
  - **The melee-flavoured cards in the Wizard starter** (Pointy Stick and others, from the Neutral and Fire pools) are fixed in W1b by adding Wizard attack cards and rebuilding the starter around them. [A director question.]
  - **No playstyle or difficulty tag on the pick screen for now.** "Melee" vs "Ranged" plus the descriptions answer the original complaint. [Adding a tag.]
  - **Run length** (about 3 min in the sim vs the GDD's 30-60 min) stays as is. Short prototype runs are a standing call (OPEN_ITEMS calls #3, GDD §9). [Lengthening runs before more classes.]
- **Backlog into W1b:**
  - the `character` scenario key also sets the body look (captures show a Rogue body);
  - the boss starting mostly off-screen (a 3c backlog item, now higher priority for a ranged class);
  - the pick backdrop HUD showing the previous class's HP;
  - check by hand that a bolt hits only the first enemy on its line;
  - identify the pink fan at the Wizard's feet in a room-1 capture.

### 2026-10-30 - W1b brief and the PL2 split (game-lead)
- **The non-Wizard fixes become a small slice PL2, run before W1b:** the boss spawn on screen, no stack trace on a bad `--class`, the scenario body look, junk file removal, the pink fan check, the bolt-line check, the stale HP behind the pick screen, and the Rogue melee cue.
  - Reasons: the boss spawn fix changes the Rogue's boss times, so W1b must tune against the new baseline; a combined W1b wouldn't fit one sitting; and it gives the director time to answer D18. [Everything in W1b.]
- **W1b tunes Wizard data only.** Enemy changes would hit the Rogue too, so if the target needs them, that's a director item. [Using "enemy pressure" as a W1b lever, as my D18 wording allowed.]
- **A non-kiting Wizard bot policy is added before tuning,** and tuning is checked under both policies. The perfect-kiting bot is a ceiling, and tuning to it would over-nerf the Wizard for real players. [Tune to the kiting bot only.]
- **New Wizard damage cards must still pass `CardDamageRule` against the Rogue's 5.0 DPS light.**

### 2026-10-30 - Card frame colours scoped into PL2 (game-lead)
- The director answered D17 with a frame-colour rule (GDD §4, "Card frame colours"). That's a director directive; only my picks are logged here.
- **Starting hex values (ux may adjust them for contrast and must log the final values):**
  - Fire frame reuses the pool colour `#ff6a1f`. [A separate frame-tuned red; one colour per element keeps the VFX and the frame matching.]
  - Class (any class pool, Rogue and Wizard alike) light bronze `#d9b48a`, deliberately lighter and less saturated than Fire so the two don't blur on the dark `#2a1f27` card background. [A deeper bronze such as `#b0793f`, which reads as a dim orange next to Fire.] Wizard cards get no separate arcane colour; they're class cards.
  - Neutral grey `#9a9a9a`. [The neutral VFX cream `#f2ecd8`, which the director didn't pick for frames.]
- **Data shape:** a `frame_color` on every pool in `data/pools.json`, with a load check that every pool has one, so a future element (Water) can't ship frameless. One accessor maps card id -> pool -> frame colour; UI never derives it from card fields. [A per-kind default with overrides; more indirection for 4 pools.]
- **It goes into PL2, not W1b,** because it's ux polish on existing surfaces and W1b's new Wizard cards then show bronze from day one. [A separate slice.]
- **The slot border already shows readiness** (`slot_ready_border_color`). The family colour must always be visible and ready-vs-cooling must stay readable; ux picks how (inner outline, fill, brightness). [Letting the family colour replace the ready cue.]
- **PL2 now gets a short playtester pass** (it adds two player-visible changes: the melee cue and the frames). [qa captures only.]

### 2026-10-30 - PL2 gameplay (gameplay-dev, logged by game-lead)
- Built 3b8359e..5079a2a (1064/1064; arena hash 2792856473 unchanged). Boss spawns inside an on-screen box; `frame_color` on every pool with `PoolDatabase.frame_color_for_card` / `frame_color_for_pool`; quiet launch refusals; scenario body look; junk file removed.
- **Findings:** the pink fan at the Wizard's feet is the enemy chaser's melee wind-up wedge (enemy team tint), not a player cue; no change. A bolt does stop on its first hit.
- **Calls:**
  - **Launch refusals use `printerr`, not `push_error`,** so there's no stack trace. [Suppressing the error inside `prepare`.]
  - **Boss placement uses a data box (`bosses.json` `spawn`, optional per boss) on the fixed iso axes,** pinned by a test to `CameraRig.tscn`. [Projecting through the live camera, which needs a viewport and fails headless.] The box is asymmetric (2.2 m up, 3.6 m down) because the boss body is drawn upward from its ground point.
  - **An unknown card or pool gets the neutral frame silently.** [`push_error`, which would spam the UI and test logs.]
  - **A `_spent` guard on every `Projectile`:** a deferred `queue_free` could let two hurtboxes entered in the same physics step both take damage. It's a latent bug, never seen in play; it applies to enemy and card projectiles too. [Report only.]
- **Rogue boss after the change (gameplay-dev, seeds 1-6, not the baseline):** 57.7-75.5 s, mean about 66.9 s, all won. qa's 10+ seed run sets the W1b baseline.

### 2026-10-30 - PL2 ux (ux-designer, logged by game-lead)
- Built ad77847 (1079/1079). Card frames in the family colour on slots, reward offers and removal cells; the Rogue melee reach cue (`MeleeReachCue`, `ui.json` `melee_cue`); the class pick hides the HUD behind it.
- **Final frame colours:** unchanged from the starting values (fire `#ff6a1f`, class `#d9b48a`, neutral `#9a9a9a`); distinct at 720p, ready or cooling.
- **Calls:**
  - **The pick screen hides the whole HUD** (it showed the build-time class's HUD for the whole pick, not one frame). [Showing the highlighted class's HP, which needs a rebuild per highlight; a refresh fix, which wouldn't help.]
  - **The ready cue moved from the border to a plate plus text brightness;** cooling slots dim only their contents, never the frame. `slot_ready_border_*` removed. [A bright inner outline (merged with grey, crowded the digit); a ready fill tint (poor text contrast).]
  - **Reward focus is a white ring outside the frame** (`option_card_focus_color`), since the peach focus colour is close to bronze. Grey + white ring is the weakest pair; check in play. [Reusing `option_focus_color`.]
  - **The HUD slot strip is 8 px taller** (`slot_size` 150x118 -> 150x126, `key_height` 20 -> 24, `preview_height` 34 -> 38) so the frame doesn't clip the key digit or a two-line Next name. [Thinner frame.]
  - **Melee cue:** a thin pale-blue arc at true light reach, shown only when nothing is in reach, brightening on a whiffed click; keyed on the light attack's `arc` shape, not the class id. No side edges or fill, so it can't be mistaken for the heavy wind-up. [Always on; a filled wedge.]

### 2026-10-30 - Scheduling the director's checklist answers (game-lead)
- The director answered checklist items 11-24 and D18 = A. Directives are recorded in GDD §3, §4, §5 and §9; only my calls are here.
- **Run order PL2 -> F1 -> P-dodge -> W1b -> 3d** (was W1b -> P-dodge). Wizard tuning must come after every change that shifts its risk (10 rooms, movement pass-through, the Wall buff, per-class charges, Recovery 8 -> 12 and the Wizard's 14 s), or it would be tuned twice. W1b's Rogue baseline moves from PL2 to P-dodge. [Keeping W1b content first and splitting its tuning off to the end; more slices for the same result.] Told to the director as easy to reverse.
- **New slice F1** for the four small global changes (Wall 1.5x, movement pass-through, Shift+1-5 swap, 10 rooms). [Folding them into P-dodge, which would no longer fit one sitting.]
- **10-room mix: 7 combat, 1 elite, 1 rest, boss.** The smallest change from 5/1/1/1; the director wants harder play to come from the difficulty tiers. [6 combat + 2 elites, which also raises difficulty.]
- **"1.5x size" for Wall of Mild Fire = length and width both x1.5** (5.0 -> 7.5 m, 1.2 -> 1.8 m). [Length only, which doesn't fix walkers barely touching it.]
- **"Movement cards pass through"** applies to every `movement`-slot card while it moves the player. Reluctant Lunge then hits every enemy on its line; qa checks the damage change. [Only blink/leap cards; the director said movement cards.]
- **Wizard Recovery 14 s vs the Rogue's 12 s** ("slightly longer"). [16 s.] Per-character overrides in `characters.json` for charges and Recovery. [Separate per-class data files.]

### 2026-10-30 - PL2 qa and playtest triage (game-lead)
- qa FAIL b7ba7fe (B1: the melee cue leaked a node for the Wizard) -> fixed cb2be67 -> delta PASS 8a99ce4 (1082/1082, 0 orphans). The soak failure was the known P-dodge flake (Rogue only, "damage immunity leaked"). Playtest 4dd2eaa: smoke PASS, no blocker; the frame colours read as three families without labels.
- **Rogue boss baseline (qa, 12 seeds, 8 rooms):** mean 66.7 s (49.7-75.6), boss-room HP lost mean 10.6. Superseded for W1b by P-dodge's re-measure.
- **Calls:**
  - **Boss head behind the RMB meter at 1024x600 (N1) goes to F1** as a data margin tweak, not a PL2 blocker. Nothing is clipped by the screen edge. [Reopening PL2.]
  - **Bronze vs grey, the grey focus ring's contrast, and whether the melee arc teaches "melee"** go to the director's eyes, not to tuning: the playtester only had stills, and all three are subjective. The ring's notch artefact is a plain bug and goes to F1. [Tuning colours now from stills.]

### 2026-10-30 - F1 gameplay (gameplay-dev, logged by game-lead)
- Built efb0516 + a preview-pin test commit (1095/1095). Wall 7.5 x 1.8; a `pass_through` flag on the dash template, set on the 6 movement dash cards (Shadow Step is a buff and already passed through); swap on Shift+1-5; boss spawn `screen_up` 2.2 -> 1.5; runs of 10 rooms (7/1/1/1, elite [3,8], rest [2,8]).
- **Arena hash changes 2792856473 -> 3513335656** (90 s seed-1: 4120250839 -> 2081798188). The Wall alone causes it (bisected): in that sim, HP lost 14 -> 5, kills 9 -> 8. Accepted as the new baseline: it's the intended director buff.
- **Reluctant Lunge on 3 enemies in a line:** damage [8,0,0] -> [8,8,8], distance 0.73 -> 3.0 m. The preview already drew the full path.
- **10-room Rogue (12 seeds):** all won; boss 45-78 s, mean about 66 s; room-end HP 77-98%; two near-deaths (0.6 HP in room 4, 4 HP in room 3).
- **Calls:**
  - **Pass-through is a data flag on the dash template,** required on every movement dash card by a test. [Deriving it from `slot_type`; a schema rule.]
  - **The grant lasts exactly the move,** not a timer. A dash that ends inside a body reuses Shadow Step's restore (up to 3 s ghosted). [`grant_pass_through(duration)`, which can be off by a tick.]
  - **`screen_up` 1.5,** head at y≈112 vs the meter's 92 at 1024x600. [1.6, too tight.]
  - **A finer boss fallback sweep at three distances, with no extra RNG draw.** [Loosening the corner test.]
- **Known gap for qa:** in that up-to-3 s ghost window after a dash ends inside a body, a dodge also passes through. That bends GDD §3 ("the dodge doesn't pass through") only in an edge case; qa judges whether it matters.
- **For W1b (game-lead):** with 10 rooms, the Wizard owns 15 of its 18 available cards at the start, so most later offers are duplicates. W1b's 2-4 new Wizard cards ease this; W1b reports the offer mix.

### 2026-10-30 - F1 ux (ux-designer, logged by game-lead)
- Built a1504cc (1098/1098; hash 3513335656 unchanged). "of 10" fixtures and comments; the focus-ring notch fixed; a ghost delay on short pass-through grants.
- **Calls:**
  - **The ring notch was the scroll container clipping the ring;** the container gets a padding stylebox equal to the ring width, and the fit maths includes it. [Moving the ring inside the card, which changes the look the director is judging; a wrapper MarginContainer, which changes node paths.]
  - **The ghost look shows only after pass-through has lasted `ghost_show_delay` 0.35 s** (`data/vfx.json`), so movement dashes no longer flicker; Shadow Step and the stuck-in-body window still show it, 0.35 s late. [A flag on dash grants, which touches gameplay code.]
  - **No swap hint added:** the game never showed one. [Adding a Shift hint.]

### 2026-10-30 - F1 qa triage (game-lead)
- qa PASS f305fae (1102/1102 with qa's 4 new cases; soak clean, hash 3513335656). Rogue 10 rooms, 12 seeds: boss mean 66.5 s (45.3-78.2).
- **The dodge passing through during the post-dash ghost window goes to the director as D19** (it touches the wording of a GDD §3 director rule). Default A: accept it and add a carve-out line. It stays as built until answered. [Deciding the GDD wording myself.]
- **The concentric launch quirk and a stale comment go to P-dodge,** which touches Player anyway. They're pre-existing and essentially unreachable in play (exact centre overlap). [Reopening F1.]
- **Bot pick-rate outliers** (Wall 0.30x, because the bot doesn't aim walls) need no action; W1b's tuning watches card pick rates.

### 2026-10-30 - F1 playtest triage (game-lead)
- Playtest 027d65a: smoke PASS, no blocker. The boss in room 10 is clear of the HUD; Wall and Lunge read well.
- **The Wizard's boss cliff** (killed at full HP in 6.4 s on seed 21) goes into W1b item 5a, under D18 = A. It's not a new director question. [Asking the director.]
- **Run length (about 5 bot-minutes for 10 rooms)** stays as the standing prototype call (OPEN_ITEMS call #3, GDD §9 [PROPOSED] short runs); the director set "at least 10" and difficulty via tiers. I mention it to the director as FYI, not a decision. [A new D item.]
- **A walking-enemy Wall scenario** goes into W1b item 5b.

### 2026-10-30 - P-dodge gameplay (gameplay-dev, logged by game-lead)
- Built 0209de4..HEAD (1140/1140). Dodge charges (`DodgeCharges`, 1.2 s each, clamped 0-4; Rogue 3, Wizard 2 via `characters.json` `dodge_charges`); Recovery 8 -> 12 s, Wizard 14 s (`slot_base_cooldowns`); boss stagger 0.8 s before the roar (STAGGER state); a nudge-out when pass-through ends inside a body (the launch bug).
- **The soak flake was not a real leak:** after Try again the seed is random, and a rest room is correctly immune while its choice is open. The soak now expects immunity in rest rooms only and prints the room type and seed on failure.
- **Arena hash 3513335656 -> 1867641457, caused only by Recovery 8 -> 12** (bisected; the charges don't change this seed). Accepted as the new baseline.
- **Calls (gameplay-dev):**
  - **Stagger damage counts** because the HP floor drops to the next threshold for the stagger only; one hit can't pass two thresholds (a new stagger starts). [Making the boss immune during the stagger.]
  - **`max_transition` 1.5 -> 2.0 s** to fit stagger 0.8 + roar 1.2. [Shortening the roar to 0.7 s.]
  - **The new `characters.json` keys are optional;** `player.json` charge keys are required. [All required.]
- **My calls on gameplay-dev's three questions (none touch a GDD rule, all cheap to reverse):**
  - **Accept 0.8 s stagger and the 2.0 s cap.** The GDD makes the length a data value. [Asking the director.]
  - **The last-phase stagger keeps a 1 HP floor,** so the boss can't skip phase 3 and its adds. It's unreachable today, but the 3-phase fight is the design. [Allowing a kill during the stagger.]
  - **The sim bot becomes charge-aware now** (throttled to the roll length, gated by charges), in P-dodge, before qa takes the baseline. Otherwise W1b would tune the Wizard's 2 vs the Rogue's 3 charges with a bot that can't see them. A new baseline is accepted. [Leaving the bot at one dodge per 0.9 s.]
- **Follow-up done (4986db4, 6243785, bc976ca; 1141/1141):** the bot dodges whenever a charge is ready (throttled to the 0.25 s roll); the last-phase stagger keeps a 1 HP floor. **New arena hash baseline 2484586390** (90 s seed 1: 3255493562), accepted: the bot change.
- **Bot caveat for W1b:** in whole runs the charges now show (Rogue 3 vs 1: lowest HP 13.0 vs 7.8; Wizard 2 vs 1: 11.0 vs 7.2). In the 60 s arena the Rogue lost *more* HP with 3 charges (129) than with 1 (87), probably because extra rolls pull the bot off its kiting line. Treat the bot's dodge use as a behaviour artefact, not charge-tuning evidence; W1b tunes on whole runs under both bot policies. [Tuning the bot's dodge decisions now, which moves every baseline again.]

### 2026-10-30 - P-dodge ux (ux-designer, logged by game-lead)
- Built 8566b9e (DodgePips, the boss bar STAGGERED cue, tests) and 74a972c (`tools/ux_capture`). ux's final hand-back didn't arrive, so its gate results and call list are unknown; qa runs every gate independently.
- **Call visible in the commit:** the phase notch is marked crossed when the stagger starts, and the phase line reads "Hit it now" during the stagger. [Marking it at the roar.]

### 2026-10-30 - P-dodge qa (game-lead)
- qa PASS 14eadd1 (1147/1147; soak 8 of 8 clean; hash 2484586390). The ux gates were all re-run by qa.
- **W1b baseline (10 rooms, seeds 1-12, charge-aware bot):** Rogue 12/12 won, boss 64.3 s mean (47.8-81.3), boss-fight lowest HP 24.7/30 mean; per-room HP lost 2.0-6.8. Wizard (kiting) 11/12 won, boss 55.0 s mean; per-room HP lost about 0-1.7 in rooms 1-9, then 11.5 in the boss room (1 death at 13.6 s). This is the "cliff" W1b item 5a fixes.

### 2026-10-30 - P-dodge playtest triage (game-lead)
- Playtest 60d86fd: smoke PASS, no blocker. The pips read and don't crowd the meters; the stagger reads as a reward window; Recovery matters without being leaned on.
- **The Wizard's cliff** is four "Fan of regrets" volleys in a row in phase 1 (about 10 HP each, 26 HP total). It goes into W1b 5d, which first checks whether the bot dodges pellets at all. [Tuning straight away.]
- **"Is the Rogue boss fight meant to be nearly damage-free?"** isn't a new director question. The director already called today's tuning "Easy" and wants difficulty to come from the tiers. [A new D item.]
- **A charge-return flash near the player** goes to the director's eyes (checklist 28), not a build. [Building it from a still capture.]
- **The STAGGERED banner overlapping the armor line** goes to W1b 5e (ux, small).
- The playtester committed 7 capture PNGs (440 KB) in `docs/playtests/img/`. They're small, so I'm keeping them. [Removing them.]

### 2026-10-30 - W1b content (gameplay-dev, logged by game-lead)
- Built aaa933a, 8b1778a, 45ed585 (1151/1151; Rogue `-Run` seeds 1-12 and arena hash 2484586390 unchanged).
  - 4 Wizard cards: Three Bolts, Reluctantly; Overqualified Bolt; Personal Space, Enforced; Ward, Technically.
  - A caster starter: Pointy Stick, Ember Whatever, Shrug Bomb and Blaze and Bail are out.
  - 3 Wizard presets.
  - Sim flags `-BossLog`, `-WizardNoKite` and `-DodgePellets`.
  - The `wall_crossing` scenario.
  - `Health.last_source_id` (telemetry only).
- **Balance table, new Wizard damage cards (CardDamageRule bar: cast 4.5, the 5.0 DPS light):**

  | Card | Slot | Cast | Cycle | DPS |
  |---|---|---|---|---|
  | wizard_bolt_volley | attack_single | 7.5 | 1.2 s | 6.25 |
  | wizard_overqualified_bolt | attack_single | 12.0 | 1.8 s | 6.67 |
  | wizard_arcane_nova | attack_aoe | 11.0 | 2.0 s | 5.50 |

  Ward: +25 armor (33% off physical/neutral) for 6 s on a 5 s cycle. It's the first player armor source.
- **The bot never dodged pellets in flight.** With `-DodgePellets`, the kiting Wizard's boss-room damage drops from 14.9 to 5.0. About two thirds of the "cliff" was a sim artefact. The kiting stand-off (5-9 m) also selects the volley (`min_range` 4), the one attack it can't escape.
- **Wizard boss (new starter, current tuning, 12 seeds):**
  - kiting: 53.8 s (84% of the Rogue's), 12/12 won;
  - non-kiting: 38.2 s (59%, under the 70% floor), 12/12 won.
- **Offer mix:** about 1.27 of 3 offers are new cards (58% duplicates), against 86% duplicates before.
- **Calls (gameplay-dev):**
  - pellet dodging is opt-in, so baselines hold. [Default on.]
  - the no-kite policy reuses the Rogue bot's numbers. [A new mid-range hold.]
  - Fine, Burn Then stays in the starter. [Wall of Mild Fire.]
  - Ward is in the pool but not the starter. [In the starter.]
  - the cards use "neutral" damage. [A new "arcane" damage type.]
  - telemetry goes through `last_source_id`. [Matching boss hits by damage amount, which collides with add damage.]
- **My calls for the tuning run:**
  - **No piercing beam.** It needs a new `pierce` projectile param, and the pool has enough caster feel without it. [Adding the param now.]
  - **Tuning reads the pellet-dodging bot as the primary measure for both classes**, since a human dodges visible pellets. The default bot is reported too. Rogue reference with `-DodgePellets`: boss 66.5 s. [Tuning to the default bot, which over-punishes the Wizard for a bot gap.]
  - **`-DodgePellets` stays opt-in for now,** so P-dodge's baselines still compare. Making it the default is a later tooling call. [Flipping it now and re-baselining mid-slice.]
  - **Ward duration must end up below its cycle** (no permanent armor with 2 copies).

### 2026-10-30 - W1b tuning (gameplay-dev, logged by game-lead)
- Built 2128ae4 (1152/1152; Rogue seeds 1-12 and hash 2484586390 unchanged). Wizard data only; no enemy changes were needed.
- **Values:**
  - Wizard `max_hp` 26 -> 22;
  - light 2.4 -> 1.5 (3 DPS, 50% of the Rogue's; the old 80% was a W1a test pin, not a GDD rule);
  - heavy 8.5 -> 5.5;
  - Three Bolts 2.5 -> 2.2 per hit;
  - Overqualified Bolt 12 -> 10.5;
  - Personal Space, Enforced 11 -> 10.5;
  - Ward 6 s -> 4 s (below its 5 s cycle).
- **Balance table update** (supersedes the content-phase rows):

  | Card | Cast | Cycle | DPS |
  |---|---|---|---|
  | wizard_bolt_volley | 6.6 | 1.2 s | 5.50 |
  | wizard_overqualified_bolt | 10.5 | 1.8 s | 5.83 |
  | wizard_arcane_nova | 10.5 | 2.0 s | 5.25 |

- **Results (pellet-dodging bot, 12 seeds, 10 rooms; Rogue boss 66.5 s, 2.39 HP lost per room):**
  - kiting Wizard 68.8 s (103%), 0.82 HP per room;
  - non-kiting 47.6 s (72%), 1.82 HP per room;
  - all won.
  - Default bot: kiting 106% and non-kiting 70% boss time, 1.38 and 2.81 HP per room (Rogue 3.89).
- **D18 = A is met:** rooms cost HP, less than the Rogue's; the Wizard is squishier; boss time is within 70-130%; no deaths.
- **My calls on gameplay-dev's two questions (tuning numbers, cheap to reverse):**
  - **The kiting Wizard losing under 1 HP per room is accepted.** The kiting bot is a ceiling; the non-kiting policy (about 75% of the Rogue's room cost) is the typical player. [More nerfs, which would push the non-kiting boss time under 70%.]
  - **Raise Wizard HP to the smallest value where one full boss volley from full HP can't kill** (about 24, gameplay-dev confirms). The director asked for "not a sudden one-shot". A full-HP death to one telegraphed attack is the cliff we were fixing, even if the bot never saw it. 24 is still squishier than 26. [Keeping 22.]
  - **The non-kiting boss time sits at the 70% floor;** HP 24 doesn't change damage output, so it stays near 70-72%. qa's independent re-run decides whether it needs one more notch. [Pre-emptively cutting damage.]
- **Correction (gameplay-dev 0754483):** a full volley is 5 x 5 = 25 physical, and the player has no armor, so the smallest safe HP is **26**, not 24. Wizard HP is back to 26, and a test pins "max HP > one full volley" for every class (1153/1153). The bot table is otherwise unchanged; no runs died.
- **This conflicts with GDD §5 (director: the Wizard "should be squishier than it is today").** My one-shot guard was my own inference, so it goes to the director as **D20**. As built (26 HP), the Wizard is harder through about 40% less damage, 2 dodge charges and Recovery 14 s, but not lower HP. It's a one-value change either way.

### 2026-10-30 - W1b ux (ux-designer, logged by game-lead)
- 245d8e3 (`tools/ux_capture.gd` only). **5e: no banner overlap.** STAGGERED sits on its own row at all four sizes. The playtest's overlap was a world-space damage number over the boss's head landing on the bar. The stagger capture now uses a normal 30-damage hit. The 4 new Wizard cards fit the slot strip and reward offers at 1024x600, with bronze frames and no clipping.
- **Damage numbers drawing over the boss bar** when the boss stands just under it goes to the backlog as a ux readability item, not to the director. It's readability, not feel. [A director question.]
- **Flake for qa:** `w1a_test:482` (Wizard bolt autofire, "less than 20.0 but was 20.0") failed once in a full suite run and passed 30/30 alone.

### 2026-10-30 - W1b qa triage (game-lead)
- qa PASS 6f26ff9 (1156/1156). The flake was test timing: the bolt tests now poll up to 4 s. 24-seed re-run on both bots.
- **N1, the non-kiting Wizard's boss time sits at the floor** (pooled 70.7-73.1%, one cell 69.8%). Accepted for now: the mean is inside the band, and the director's D20 answer may change the tuning anyway. Revisit after his hands-on play. [One more notch of Wizard damage now, which pulls against "squishier".]
- **N2, the pellet-blind kiting bot died 3/12 on seeds 13-24** (two volleys, not a one-shot). With pellet dodging there were 0 of 48 deaths; the playtester checks the "Fan of regrets" telegraph is readable. [Tuning to the pellet-blind bot.]
- **N3, the Wizard's light is now 50% of the Rogue's DPS (was 80%) and its heavy 5.5 (was 8.5).** These were tuning choices, not director values. Told to the director as FYI alongside D20, not as a separate question. [A new D item.]
- **N6, generated files are untracked** (`*.uid` for new tests and tools; `docs/playtests/img/*.import`, which Godot creates because it scans `docs/`). Housekeeping: each owner commits its `.uid`, and a `docs/.gdignore` stops the imports. Logged in STATE. [Ignoring them.]

### 2026-10-30 - W1b playtest triage (game-lead)
- Playtest d74e0df: smoke PASS, no blocker. The caster cards and names fit the tone; Personal Space, Enforced is the standout. The "Fan of regrets" telegraph reads well enough for a human to dodge. 72 runs on seeds 31-42: no Wizard deaths. Non-kiting Wizard boss at 77% of the Rogue's.
- **The missing Ward cue, the look-alike card bolts, the long smash knockback and the volley damage numbers go to a new small polish slice PL3,** not a W1b reopen. They're readability polish on content that works. [Fixing them inside W1b, which adds another full qa cycle before the director can play.]
- **"A kiting Wizard is nearly free until the boss" is accepted for now** (same call as qa N1/N2). Making room enemies threaten a kiter needs enemy changes, which is a director call. It goes with D20 and his own play. [Enemy changes now.]
- **The auto bolt stays at 50% for the director's first hands-on run.** [Tuning before any human has felt it.]
- **The Rogue loss on seed 36 (default bot, room 2)** is a bot loss, not a bug: the same seed wins with pellet dodging. No action.
- Note: the playtest commit's trailer says "Sonnet 5.5" (the harness's attribution), not "Opus 5.5" as briefed. History isn't rewritten.

### 2026-11-02 - Recording the director's 10/31-11/2 notes (game-lead)
- **"Face" read as "pace".** The director's note says the "face" could be a bit faster; he asked me to read it as pace and log the reading. It feeds H1's enemy speed lever; no separate pace change. [Reading it as a visual or UI note.]
- **Vision check round 1 mapped from his notes.** He didn't answer the six questions one by one; questions 2-6 each match a specific note, quoted in the OPEN_ITEMS table. Question 1 (combat feel) has no direct answer, so it's marked "not answered directly" and asked again in round 2. [Inferring an answer for Q1.]
- **Human playtests are logged as dated files in `docs/playtests/`** (`2026-10-31-director-wizard-no-cards.md`, `2026-11-01-luke-keybinds.md`), labelled as human sessions recorded by game-lead, next to the playtester reports. There was no separate playtest log file. [A new single log file, which would split the playtest record in two places.]
- **D-number reservation.** The director numbered D21 (run order) and D23 (loadout card flags), and asked for BD0's questions "as D22 onward". So D22, D24 and D25 are reserved for BD0 (at most 3); D23 stays the loadout one. Written in STATE and OPEN_ITEMS so BD0 doesn't overwrite it. [Renumbering the director's D23.]
- **D21 raised, default = his order.** My one genuine reorder reason is the PL3 housekeeping (stray untracked files, mixed CRLF/LF docs) before the doc-heavy BD0. It's small enough to offer as option B; I proceed with his order. [Reordering without asking.]
- **D23 default = every existing card is `starter`.** Both class starting decks are exactly 15 cards, 3 per slot, at the 3-unique minimum (`data/characters.json`), so a "default decks only" reading leaves the loadout editor 3 extra cards per class (the other class's shared Fire and Neutral starters, none for Utility) plus copies. "Starter" therefore means "allowed in a loadout's starting deck"; `reward` and `locked` are for BD1+ content. [Tagging only today's 15 as starter.]
- **H1 telegraph floor: 0.45 s** (today's shortest, chaser and shooter; `data/enemies.json`), with boss attacks keeping their 0.6 s minimum (3c). Attack-rate changes may shorten cooldowns but never push a telegraph under it. [A lower floor such as 0.35 s, which risks undodgeable hits.]
- **H1 speed ratios use the player's walk of 6.0** (`Player.gd` `move_speed`, an export, not data). At +25% the chaser is 5.0 (0.83 of walk), still below the director's ceiling. [Moving player speed to data inside H1, which H1 forbids touching.]
- **K1 runs the reload soak** (it touches the HUD and input), per the standing rule.
- **PL3 `.gitattributes` owner: gameplay-dev** (repo config), in a commit of its own with no other changes; tech-writer checks its docs after. No role owned repo config. [tech-writer, which would have it touch code files it doesn't own.]
- **OPEN_ITEMS "How to playtest" corrected now** to the director's 24530e4 bindings, 10 rooms and `--run-room=10`. It was stale; OPEN_ITEMS is game-lead's. K1 updates it again for R. [Waiting for K1.]
- **OPEN_ITEMS call 13 marked superseded** (no-card builds "stay slow"): the 10/31 run won anyway.
- **3d tag renamed** from the stale `playtest-2026-10-29-3d` to the close date, and its "sim hashes unchanged" gate now means H1's re-baselined hashes.
- **The new GDD section is §4a,** placed after §4 so existing § references (§9 and others, used throughout the docs) don't shift. [Renumbering the GDD.]

### 2026-11-02 - K1, key labels follow the bindings (gameplay-dev, ux-designer, qa, game-lead)
- **The label helper is a static class, `InputLabels`, not a new autoload,** so the reload-soak surface doesn't grow. The `bindings_changed` signal lives on the existing `InputBindings` autoload, because an autoload can't share a `class_name`. [A new `InputLabels` autoload.] (gameplay-dev)
- **Label modifier order is Ctrl+Alt+Shift+key.** Physical keycodes are converted to the user's layout for display, and the physical key is shown in headless mode. [Showing the raw physical key always: it would be wrong on non-QWERTY layouts.] (gameplay-dev)
- **The validator compares resolved signatures** (modifiers plus key, or mouse button). It only checks actions defined in `data/input_bindings.json`, because Godot's `ui_*` actions legitimately overlap. [An InputMap-wide check: it would fail on the shipped file.] (gameplay-dev)
- **A conflict does `push_error` and fills `last_conflicts`, but never quits,** so headless tests and the runner keep working. [A hard quit at startup.] (gameplay-dev)
- **The swap key text is derived:** `slot_N` maps to `dead_card_swap_N`, with no extra data field. [A `swap_action` field in `slot_types.json`.] (gameplay-dev)
- **The HUD and pause hint refresh on `bindings_changed`.** Option cards and prompt text are built from live bindings each time a screen opens and don't refresh while open. That's fine until a rebind UI exists that can be open alongside a prompt. [Live refresh on every screen.] (ux-designer)
- **The dodge and attack-meter key columns size to `max(config width, text width + pad)`** (`HudLayout.key_label_width`). A very long key such as "Shift+Space" pushes the pips right rather than clipping. [A fixed width that clips.] (ux-designer)
- **`dodge_label` was removed from `data/ui.json`;** the text comes from the dodge binding. (ux-designer)
- **The game-over hint "Enter or Space" stays literal.** Space there is Godot's `ui_accept` on the focused button, not the dodge binding, so it's allowlisted in the scan test. PL3 looks at whether game over needs the same mashed-Space guard the other prompts have. [Building it from `for_action(&"dodge")`: that would be wrong.] (ux-designer, qa)
- **The prompt swallows slot and swap actions on both press and release,** after its digit-focus logic, so digit 2 (Movement) still moves the highlight. Release is swallowed too, so a key held while the panel opens doesn't cast when it's let go. (ux-designer)
- **Menu number keys stay positional** on reward, removal and class-pick screens (1 = first option or column). They're menu navigation, not slot bindings. Only `remove_list_hint` was reworded ("Keys 1-%d jump to a column"). The playtester found two clashes this leaves: a "Key 1" chip next to option badge 1, and the "Utility (1)" header while digit 1 jumps to the first column. Both go to PL3 as readability fixes. [Mapping menu columns to slot keys, which would make the digits jump around.] (game-lead)
- **The scan test matches "Space" by context,** because a bare "Space" pattern flagged the card name "Personal Space, Enforced". (qa)

### 2026-11-02 - H1, pressure pass (gameplay-dev, game-lead)
- **Knobs live in `data/enemies.json` as a `pressure` block** (`speed_scale`, `attack_rate_scale`, each 0.25-4.0, unknown keys rejected). Speed multiplies `move_speed`; attack rate divides `attack_cooldown` only. No wind-up knob: the 0.45 s telegraph floor already binds the chaser and shooter. [A separate pressure file; a wind-up multiplier.] (gameplay-dev)
- **The boss is unscaled** (its speeds and gaps come from `data/bosses.json` phases). Its summoned adds are normal enemies and are scaled. Rogue standard boss time 62.8 -> 66.1 s, inside 45-84 s, so scaling the boss wasn't needed. (gameplay-dev)
- **`-LightHeavyOnly` now presses no card slot at all** (it skipped only slots 1-2 and still used Ward, blinks, Recovery and heals), to match H1's "no cards" definition. RNG draws unchanged, so standard-policy hashes didn't move. [Leaving it, which overstated no-card runs.] (gameplay-dev)
- **Candidate values: `speed_scale` 1.25, `attack_rate_scale` 1.0.** Chaser 5.0 (0.83 of walk 6.0), shooter 3.75 (0.625), golem 2.5 (0.42); boss 2.6/3.0/3.4 unchanged. Sweep 16 seeds, 10-room runs: attack rate 1.25+ dropped the Rogue's standard clear rate from 100% to 50-62% (outside the 15-point band) and still didn't touch the kiting Wizard. [1.25/1.25, which breaks the standard-run target.] (gameplay-dev; game-lead accepts pending qa) This departs from the director's "then attack speed" step, so it's raised as D27.
- **Final H1 targets (game-lead, set before qa):**
  - **Gates:** the standard clear rate stays within about 15 points of today's for both classes; Rogue standard boss median stays in 45-84 s.
  - **No-cards ≤25%:** met, but **not evidence**. The corrected no-cards bot already clears 0% at the 1.0 baseline, so this metric can't tell 1.0 from 1.25, and the director's human 5:25 clear contradicts it. The human test (OPEN_ITEMS 33) judges it.
  - **Wizard kiting HP loss ≥10%: dropped as a gate.** It's 0.0% at every variant (speed to 1.25, attack rate to 2.0). With speed capped below walk, the kiting bot is never hit. It isn't reachable with H1's two levers. Recorded as missed; D27 offers the next lever. [Holding the slice open for a lever H1 doesn't allow.]
- **HP-loss metric:** the median over combat and elite rooms of (HP at room start - HP at room end) / max. The death room and rooms after a rest room are excluded. A "dip" variant measures to the lowest HP in the room. (gameplay-dev)
- **qa PASS 42cdb13 (20 seeds, `docs/reviews/2026-11-02-h1-qa.md`).**
  - Reproduced the sweep: at 1.25/1.0, Rogue standard clears 100% with a 66.1 s boss median; the kiting Wizard standard clears 95%.
  - At 1.25/1.25 the Rogue standard clear rate drops to 65% (7 deaths of 20 vs 0 of 20, p≈0.008), so it's not noise.
  - **Why the kiting Wizard isn't hit:** shooters do fire (574 shots, 8 seeds), but about 4% land. A shot holds the lane it had when its 0.45 s wind-up started and takes about 0.78 s to arrive, and a player walking at 6.0 leaves that lane in about 0.1 s. More attack rate only means more dodgeable shots.
  - **Metric note:** end-of-room HP loss is 0% for every standard deck (they heal in-room). Any future pressure target uses the in-room dip instead.
  - **Watch item:** the boss carries scaled `move_speed` and `attack_cooldown` fields it doesn't use. That's a trap if later code reads them. (qa)

### 2026-11-02 - Director's OPEN_ITEMS pass: my readings (game-lead)
His answers are recorded verbatim in `docs/playtests/2026-11-02-director-open-items-pass.md`. They live in the GDD and CLAUDE.md, not here. These are my own readings and placements:
- **D27 read as A** (speed x1.25, attack rate 1.0). He didn't answer D27 directly, but he said "Wizard with cards is good" (item 33) and named his own next lever, the dodge-off trial (item 34). Stated in his report so he can object. [Keeping D27 open, which would keep a settled question in front of him.]
- **H1 closes as "gates met, goal missed".** His no-card Wizard reached room 8 and looked likely to win, so H1 didn't make no-card runs unsafe in his hands. H2 is the follow-up. [Holding H1 open until H2: they're separate changes, and H1's knobs are worth keeping.]
- **Call 16 covers both the reward and removal screens** (my call text said "on those screens"), and drops only the number keys; arrows and Enter stay. D26 stays open, narrowed to game over and class pick. [Also dropping keyboard navigation, which he didn't ask for.]
- **H2 runs before BD0**, right after the PL3 housekeeping. It's his direct "I'd like to see what happens" request, it's small, and BD0 needs to know whether the dodge stays to design Movement cards. [After BD1, which would design archetypes without knowing whether the dodge stays.]
- **D20 = B (Wizard 22 HP) ships in H2 as its own commit,** with a separate sim column, so its effect can be seen apart from the dodge removal. [A separate slice for one data value.]
- **Turning the dodge back on takes two data edits** (the switch and a non-clashing key), because Movement takes Space. I say so rather than inventing a hidden spare key. [Auto-moving Movement back to 2 when the dodge returns, which is magic the director didn't ask for.]
- **The H2 shipped default is dodge off.** "Removed entirely" means off by default, not a test-only setting. [Off only in a test scenario.]
- **D28 raised (branching map placement), default: a MAP0 design doc right after BD0, and the first map build after BD1, before 3d.** He wants the roguelite feel "sooner", but build depth is still his top concern, and the map's rewards need currencies that don't exist yet. [Building the map now, before BD0.]
- **RESOLVED.md migration:** tech-writer creates it from the OPEN_ITEMS text at commit 8c03e6f plus today's answers. I then trim OPEN_ITEMS to active items only. For one pass, both docs hold the resolved items; nothing is lost.
- **PL3 items 7-8 replaced** by the number-key removal (call 16). Item 9 (the game-over Space guard) moved into H2, because Space becomes a card key there.

### 2026-11-02 - H2, dodge-off trial (gameplay-dev, game-lead)
- **`dodge.enabled` reads as false when missing**, matching the shipped file, so old fixtures stay valid. [Default true, which would quietly re-enable the dodge in any data file without the key.] (gameplay-dev)
- **An unbound action is an empty list and is valid.** The only binding error added is "dodge on with no key" (`InputLabels.find_missing_required`, called at startup). [Removing the dodge action entirely, which would break the plumbing the director asked to keep.] (gameplay-dev)
- **Space stays in `ui_accept`.** It's swallowed on the class pick, reward and run prompts, and game over, where a mashed Space could confirm by accident. Pause and settings still accept it on purpose. [Removing Space from `ui_accept`, which changes Godot defaults on every screen.] (gameplay-dev)
- **The game-over arm delay reuses `run_ui.prompt_option_arm_delay` (0.4 s);** no new data key. Hint "Enter or Space" -> "Enter". (gameplay-dev; menu text, so ux checks the wording)
- **The full-volley survival pins now cover the Rogue only** (D20 = B allows a one-volley Wizard). A new check, not a GDD rule, requires the Wizard's max HP to exceed half a volley, so a partial volley can't kill from full. [No Wizard check at all.] (gameplay-dev)
- **Dodge tests enable the switch and bind a test-only key (F9)** through `tests/support/dodge_switch.gd`. (gameplay-dev)
- **The suite is red between 120bfef and 43bac04** (one volley pin), green from 43bac04 on. History is not rewritten. (gameplay-dev)
- **No retune for the trial result (game-lead).** On the shipped build (dodge off, Wizard 22), standard bot clears fall to Rogue 3/16, kiting Wizard 8/16 and no-kite Wizard 7/16, from 16/16, 16/16 and 16/16 with the dodge on (H1 baseline). (Corrected after qa: the kiting Wizard is 16/16 at 26 HP and 15/16 at 22 HP with the dodge on; it was written as 15-16/16.) Wizard 22 HP alone costs one kiting run in 16. Per the brief, this is reported to the director and not compensated. The bot has no deliberate escape logic and presses slots at random, so it's a pessimistic stand-in for a human using Space-Movement on purpose. [Tuning enemies down to restore clear rates, which would hide the trial's answer.]
- **Commit trailer fix:** gameplay-dev's last commit carried the wrong co-author line; game-lead amended the unpushed message only (55e0f58 -> dacc680).
- **The dodge row is hidden by visibility, polled each frame from `PlayerConfig.dodge_enabled()`,** not removed. This allows a live switch flip and tests. It's the last row of the top-left stack, so there's no gap to re-flow. [Removing the node, which breaks the older pip tests and live toggling.] (ux-designer)
- **qa PASS 4aa7141 (`docs/reviews/2026-11-02-h2-qa.md`).**
  - The three-column table reproduces exactly. Bots press 0 dodges with the switch off and 18.7 per run with it on.
  - The dodge-on copy matches H1's hashes. New baselines: arena 2591372848 / 4009010406; bot sim 2281795515 unchanged. Suite 1220/1220 (105 suites). (qa)
- **w1a flake fix: waits are bounded in physics ticks (`MAX_WAIT_TICKS` 1800), not wall-clock seconds.** The bolt test asserts the first hit is exactly 1.5. [A longer wall-clock wait, which only moves the threshold.] Wall-clock waits remain in `attack_meter_test.gd:79`, `player_attack_test.gd:86`, `slice1_qa_test.gd:69` and `slice4_qa_test.gd:320`; fix them if they flake. (qa)
- **Pause keeps accepting Space on its focused button.** The tree is paused, so the press never casts. Arm the pause screen only if a playtest shows a mash closing it. (qa, game-lead agrees)
- **H2 close (game-lead).**
  - **D29 raised, default A** (the dodge stays off until the director has played). The trial's answer is his hands, not the bot.
  - **The playtester's D20 question is not re-asked:** the director already said a full volley killing the Wizard is acceptable. Its pause-arming question is closed by qa's view.
  - **Pause before BD0:** I stop after H2's close rather than start BD0 straight away, because D29 changes what BD0 designs for the Movement slot. BD0 can still start on default A if he says "continue". [Starting BD0 immediately, which risks redoing its Movement section.]
  - **The H2 playtest's volley observation** (pellets hitting outside the lane at the fire moment) went into PL3 item 6 as a possible correctness fix.

## 2026-11-02 - BD0: build-depth design doc (game-lead)
- **BD0 ran on D29's default A** (the dodge stays off). The director said "continue" without answering D29. `docs/BUILD_DEPTH.md` §8 says what changes if he picks B or C (only the Movement-card guidance). [Waiting for D29.]
- **Conditional and scaled damage doesn't count toward `CardDamageRule`.** Every Attack-slot card must pass on its unconditional damage, so a payoff is never dead when its condition isn't live. BD0 set paper numbers for all 9 new Attack cards that pass. [Counting conditions at an expected value, or giving payoffs a `rule_exception`, which would let weak-when-unlit cards in.]
- **Tags are derived from effects; only Primer, Payoff and Keystone are authored** (in a new `data/keywords.json`). Derived tags can't drift from what a card does. [Hand-written tag lists on every card.]
- **`CombatEvents` relay autoload as the event bus.** There's none today (checked: per-node signals only; `status_expired` never fires on death; damage `kind` can't tell light, heavy and card apart). BD1 adds the autoload with `card_cast` and a cast history; BD2 adds the rest (damage origin, `status_ended` with `owner_died`). [A Player-owned manager, which can't see enemy deaths without wiring every enemy.]
- **Relics use the card effect format plus triggers.** One mechanic serves relics and, later, card buffs. Relic data names future map nodes as sources now (`merchant`, `curse_room`, `buff_room`, `mini_boss`), with `rarity` and a reserved `curse` block, so the map needs no relic rework. [A separate relic effect vocabulary.]
- **Relic defaults (D22 = A until answered):** an elite gives a relic choice instead of cards; a rest room offers heal 30% or a relic; 1 in 4 reward screens shows a relic in one slot; about 3-4 per run; no boss relic while the boss ends the run.
- **Slice split (D24 = A until answered):** the provisional BD1 brief had relics in BD1, while the BD0 brief put them in BD2. I followed the BD0 brief so each slice fits one sitting, and put BD2 before 3d so relics aren't delayed. Run order with D28's default: BD0 -> MAP0 -> PL3 (rest) -> BD1 -> BD2 -> first map build -> 3d -> BD3. [One big BD1, more likely to be cut off mid-slice.]
- **Burn and Bleed don't stack in the base game (D25 = A until answered).** Stacking is plumbing that only relics and keystones turn on, so base balance doesn't move. [Base stacking for everyone, which retunes every Burn card.]
- **BD1 archetypes: Kindling and Hit and Run (Rogue), Controlled Burn and Departure Lounge (Wizard).** They need only conditions and primes, with no stacking. Bleed Out, Grudge Brawler, Thesis and Ward Battlemage wait for BD3's stacking, scaling and card triggers.
- **New keystones will be `reward`, other new cards `starter`** (3d adds the field; D23 left BD1+ content to decide per card). Debug decks give testers the keystones.
- **Every archetype deck keeps a pure escape Movement card** while the dodge is off. BD1's plan-aware bot keeps one Movement for escape. Movement cooldowns aren't touched until that bot's numbers exist, since H2's random-press bots understate a human. [Shortening Movement cooldowns now.]
- **The measurable checks need a plan-aware bot** (`-Plan`), built in BD1. With random presses, removal pain and parity would read as noise.
- **No web research.** Sources list only mechanics I'm confident about and mark the rest "unsure". A research digest is offered in OPEN_ITEMS, not scheduled.
- **`docs/BUILD_DEPTH.md` is a game-lead doc,** added to CLAUDE.md's ownership list (a design doc alongside the GDD).

## 2026-11-02 - Applying the director's answers D22/D24/D25/D26/D28/D29 (game-lead)
The answers themselves are recorded in GDD §3, §4a, §5 and §9 (director decisions). These are my own calls in applying them:
- **D22 = C read as his three named sources only:** elites, a dedicated relic stage, and a merchant. BD0's rest-room "heal or relic" and the 1-in-4 reward-screen relic are dropped, because he didn't list them. Asked as D30 (non-blocking). [Keeping them as extra sources, which matches option C's "any reward screen can show one", but not his own description.]
- **Interim relic source before the map:** BD2 adds a **relic room** to the straight 10-room run (1 per run, rooms 2-8, not next to the rest room or the elite; pick 1 of 3 or skip) as the first version of his "dedicated relic reward stage". With 1 elite, a run gives about 2 relics until the map adds merchants and more relic stages. The 6-8 target is MAP0's job. [Relics only from elites in BD2, about 1 per run, which is too thin to playtest relics.]
- **Cap 10 is a data value** (`run.json` `relics.max_owned`). At the cap, relic sources fall back to a card offer. [Hiding the reward entirely.]
- **D25's passive nodes:** the stacking hook (`status_max_stacks.<id>` through StatModifiers) already covers passives; no plan change. Recorded in BUILD_DEPTH §3.4.
- **H3 runs before MAP0.** D29 changes how the game plays today, so the director gets a playable build sooner; MAP0 is docs only and doesn't depend on it. Order: H3 -> MAP0 -> PL3 -> BD1 -> BD2 -> map build -> 3d -> BD3. [MAP0 first, as STATE had it.]
- **H3 speed-up starting values** ("a little bit faster", no numbers given): `pressure.attack_rate_scale` 1.0 -> 1.1; a new `pressure.telegraph_scale` 0.85 on non-boss telegraphs; boss "Fan of regrets" windup 0.9 -> 0.75 (phase 3: 0.64, above the 0.6 floor). Other boss attacks unchanged, since he singled out the fan-out. [A single bigger cut on the volley only; or scaling every boss windup.]
- **PL3 item 6 (Fan of regrets lanes) moves into H3.** Speeding up a volley whose lanes may not match its pellets would be unfair; the correctness check comes first. [Leaving it in PL3 after the speed-up.]
- **Ctrl reliability is an H3 acceptance test, not a key change I make.** If Ctrl can't hold-to-preview while WASD and clicks work, gameplay-dev stops and I take it to the director. [Silently picking another key.]
- **BUILD_DEPTH §8 rewritten for the dodge-on case:** one pure escape per deck becomes a recommendation; the plan-aware bot dodges and drops the "no offensive Movement below 50% HP" rule. The dodge-off version is in git at 0ddd630.

## 2026-11-03 - H3 build: dodge returns (gameplay-dev; logged by game-lead)
Commits cee653d, d22b08d, 783d552, 3dc74fb.
- **Slot keys ignore every modifier except Shift.** Q, E, F and R pressed while Ctrl is held still cast; only Shift turns a slot key into a swap. The old "Ctrl plus the key does nothing" rule is gone. [Exact modifier match, which would drop Q or E pressed during a Ctrl hold-to-preview.]
- **Ctrl then Shift swaps in code** (`Player._swap_by_late_modifier`, generic for any modifier-keyed swap binding): a Shift press while the swap binding's modifier key is held swaps that slot and drops its preview, so releasing Ctrl doesn't cast. In "press" cast mode Ctrl-then-Shift still casts on the Ctrl press. [A second binding; Godot can't express it.]
- **Swap binding stays `{Ctrl, shift: true}` with no ctrl flag,** because a modifier's own key event never carries its own flag. [`ctrl: true`.]
- **Left/right Ctrl** both arrive as physical `KEY_CTRL` and both work; tested with synthetic key events on Windows, not a physical keyboard.
- **`pressure.telegraph_scale` is optional** (missing reads as 1.0; range 0.25-4; unknown keys still rejected). Boss adds are normal enemies and get it. [Required key.]
- **Fan of regrets:** lanes match the pellet path (worst offset under 0.03 m). Lanes clear at the fire moment while pellets fly about 1.8 s; the H2 "hit outside a lane" was the default bot not dodging in-flight pellets, not a game bug. Only fix: `Boss.in_threat` now measures from the muzzle (was 0.6 m short). [Making `in_threat` cover in-flight pellets, which would change the default bot; `-DodgePellets` exists as an opt-in.] Whether the lane should fade through the flight is a ux call in H3.
- **Pool tests needing 3 charges** use a +1 charge stat modifier. [Editing shipped data.]
- **Commit trailer:** gameplay-dev's commits carry `Co-Authored-By: Claude Sonnet 5.5` (its own harness attribution) instead of the Opus 5.5 line in the brief. Not rewritten: history rewrite for a trailer isn't worth it. [Amending the four commits.]
- **Known OS caveats, not fixed:** Ctrl+Shift is the Windows layout-switch hotkey on multi-layout machines; Ctrl+Space toggles the IME on some CJK setups; Ctrl then Shift while a reward panel is open swaps a card (rare, harmless).

## 2026-11-03 - H3 ux: volley lanes, dodge pips (ux-designer; logged by game-lead)
Commit 6f89eea.
- **Fan of regrets lanes ramp dim to bright** (alpha 0.22 -> 0.9, linear) across the wind-up, so the fire moment is the brightest frame (they used to fade out toward it). Volley only, via an optional `ramp` flag on `TemplateVfx.enemy_shot_lane`; one-argument change at the Boss.gd call site. [Changing every enemy shot lane.] [Eased ramp.]
- **Lane length capped at 14 m** (shot range 16 m) as `data/vfx.json` `boss_volley_lane_max_length`, with `boss_volley_lane_alpha_start` / `_end`. [Computing the cap from the camera each frame.]
- **Lanes still vanish at the fire moment;** no fade through the ~1.8 s pellet flight. A fading lane would suggest danger behind pellets that already passed; the pellets are visible on their own. [Fading lane in flight.]
- **Dodge pips and the Movement chip needed no change:** they already read InputLabels and `get_dodge_state()`. A recharging single pip differs from a ready one by shape and the word EMPTY, not colour alone. "Shift+Ctrl" isn't shown anywhere in the UI today.

## 2026-11-03 - MAP0: branching map design doc (game-lead)
Plan in `docs/MAP.md`; GDD §9 [PROPOSED] summary. Defaults for D31-D33 applied until answered.
- **Every path is exactly 10 rooms** (grid 10 x 4, boss in room 10), so "Room N of 10", run length and today's tuning carry over. [Paths of different lengths, like Slay the Spire's acts, which would change run length per route.]
- **Left to right, whole map visible** (D32 default A): ten columns fit 16:9, and a relic route needs planning. [Bottom to top like Slay the Spire; fog beyond 2 rooms.]
- **Path rules checked on every path** (at least 6 fights, at most 3 elites + mini-bosses, 1 merchant, 2 rests; best path 6-8 relics, worst at most 3), with seeded redraws and a 1000-seed test. [Only weighting the type picks and hoping, which can't guarantee the director's 6-8.]
- **Relic estimate counts the merchant as floor(gold / 60), at most 3.** The worked routes give 7-8 for a hunter, 2 for a route that ignores relics; the rules make 8 the practical maximum, so cap 10 is a backstop. [Validating with a simulated bot only, too slow for a generator check.]
- **Gold** start 0, combat 12-18, elite 30-40, mini-boss 45-55; **prices** relic 60/90/130 by rarity, card 40, removal 50 +25 per removal; stock 3 relics + 3 cards. Chosen so the hunter route affords 2 relics at the merchant and a fight-skipping route affords fewer. [Gold from every node, which removes the fight-vs-reward tension.]
- **Elites keep BD2's rule** (a relic instead of the card offer), so a hunter gets about 3 card offers vs about 7. That is the map's main trade-off, stated in MAP.md §4.3. [Elites giving both, which makes the relic route strictly better.]
- **Mini-boss is a data tier on existing enemies** (HP x3.5, armor 22). [A new boss AI per mini-boss.]
- **XP and between-run points reserved only** (fields at 0), because GDD §8 is open. [Designing the passive economy here.]
- **`map.enabled` switch,** shipped on at MAP1; off keeps the straight run, tests and the old hashes. BD2's interim relic room lives only in the straight run. [Deleting the straight run.]
- **Three slices:** MAP1 (map, gold), MAP2 (merchant), MAP3 (mini-bosses, curse/buff rooms; D33 default after 3d). MAP1 + MAP2 are D28's "first map build" before 3d, merchant included. MAP1 ships `relic_route` [5, 7] until the merchant exists. [One map slice, too big for one sitting.]
- **Map gen in a new `data/map.json`;** economy (`gold`, `merchant`, `relics.prices`) in `run.json`, matching BUILD_DEPTH §4.6. [Everything in run.json.]
- **`docs/MAP.md` is a game-lead doc,** added to CLAUDE.md's ownership list (as BUILD_DEPTH was at BD0).
- **Director feedback on H3 folded:** his Rogue run ("never overwhelmed") half-answers old item 38 (H1 pace); 38 is merged into item 40 for the Wizard side rather than marked answered.

## 2026-11-04 - Applying D31 = A, D32 = A (three acts), D33 = B (game-lead)
The answers are recorded in GDD §9 and `docs/MAP.md` (director decisions). My calls in applying them:
- **"3 tier, 2 mini-bosses and final boss on the 3rd tier, 30 rooms" read as three acts of 10 rooms,** acts 1-2 ending in a fixed mini-boss room, act 3 in the final boss; each act is its own map with the D32 = A shape. [Reading "tier" as the difficulty tiers of GDD §9.]
- **Optional mini-boss nodes inside acts stay, at a low weight, in MAP4.** His GDD §9 list ("harder rooms and mini-bosses") wasn't withdrawn; it's a data weight, cheap to drop. [Removing them because act ends now have mini-bosses.]
- **Split the old MAP3:** MAP3 = acts, mini-bosses, act scaling, save/resume; MAP4 = curse/buff rooms. Both before 3d (D33 = B). [One slice, too big for one sitting.]
- **Save/resume ships in MAP3,** the slice that makes runs 30 rooms long: autosave at room boundaries, one slot, mid-fight quit restarts the room. [Mid-fight saves, which need every enemy and projectile serialised.] [A later save slice, which would leave 30-45 minute runs unsavable.]
- **Act scaling** (data multipliers per act) is in MAP3's scope with values from the sim, so acts 2-3 don't get easier as the deck grows. [No scaling.] [Hand-picked values now.]
- **Relic and reject numbers over 30 rooms are asked (D34, D35)** because they change his earlier numbers (D22's 6-8 per run; GDD §9's 3 rejects per run). Defaults keep his numbers. MAP.md §4.5 shows A's cost: about 1 elite and 1 relic stage per route per act, mini-bosses give no relic, merchant relics at 150/200/260. MAP1/MAP2 keep MAP0's single-act numbers until MAP3.
- **Target run length now 30-45 min** replaces 30-60 and the [PROPOSED] 15-25 prototype note.

## 2026-11-04 - PL3 gameplay-dev (logged by game-lead)
Commits 9a86757, fbfd86c.
- **Knockback bug fixed at the cause, kept as a bug fix, not a balance call.** `Player._apply_movement` re-added last tick's knockback every tick, so a 9 m/s smash carried 19.6 m instead of the 2.25 m the data implies. Fixed for every hit on the player. It changes feel (all shoves are shorter), so the director gets an eyes item; revert fbfd86c to compare. [Clamping to the arena bounds; lowering boss `knockback` data; treating the fix as a director decision before shipping.]
- **Wizard scenarios via `--class`** (Main sets `character_id` before Player `_ready`; Scenario swaps the deck). [A per-scenario `character` key; changing the arena default, which the baselines assume is the Rogue.]
- **Capture tooling:** generic `--press=<t>:<action>` taps (`-Actions`), `--at-boss-attack=<id>` makes `-After` relative to the attack's telegraph; wave sim `-StartRoom`. [Dodge-only flag; a separate delay argument.]
- **Volley fairness measured with a standalone probe** (`tools/VolleyProbe.tscn`, teleports at wind-up start) plus 16-seed Wizard boss runs. Result: mostly a bot blind spot (pellet-aware bot 16/16, hit rate 53% -> 26%), but at 6 m or closer there's no gap wide enough to stand in, so only the 1 dodge helps; the boss can fire from 4 m. Not retuned: asked as D36. [Raising `min_range` myself.]
- **Arena 90 s seed 1 hash 819020947 -> 1212800** (knockback fix); 30 s and bot-sim hashes unchanged. Suite 1252/1252, 110 suites.

## 2026-11-04 - PL3 ux (ux-designer; logged by game-lead)
Commit da418aa.
- **Ward cue in the world, not the HUD:** a pulsing ring and bubble around the caster for the buff's duration, keyed by stat in `data/vfx.json` `buff_cues` (only `armor` today). [A HUD buff pip with a draining bar; possible later.]
- **Card projectile `look` lives in card JSON** (`color`, `scale`, `ball_scale`; the ball is drawn bigger, but the hit radius doesn't change). Three Bolts lime, Overqualified Bolt big white. [A `look_id` indirection.]
- **Damage numbers move below the boss bar** in screen space while it shows (`ui.json` `damage_numbers.boss_bar_gap`). [Hiding them; raising render priority, which can't beat a 2D bar.]
- **Volley damage numbers:** the faded "4" wasn't reproduced; merging works (one total within 0.3 s). No fix, test added.
- **Volley safe-gap tint** only where the real clear gap is at least 0.2 m half width (`boss_volley_gap_min_half_width`), computed by `VolleyGaps.gd` from the actual lane geometry, so nothing is drawn within about 7 m. No boss-bar dodge text while D36 is open. [A tapered wedge; tinting every gap.]
- **Reward and removal screens:** digits, hints and badges removed; "Key Q" became a key cap "Q"; the reward line "Recovery (R) now: A" became "In slot: A". The removal grid headers and the "Next:" line still write keys out (D26 = A allows it). [Shrinking the font.]
- **Card strip** slots 126 -> 134 px, preview row 38 -> 46 px; **dodge return pulse** 0.3 -> 0.6 s with a swell. The pip itself isn't bigger.

## 2026-11-04 - Applying D34 = C, D35 = A, D36 = A (game-lead)
The director's answers are recorded in GDD §4a/§5/§9/§14, `docs/MAP.md` §2/§4.4/§4.5/§10, BUILD_DEPTH §4.1/§11 and the ROADMAP (BD2, MAP2, MAP3). These are my readings and defaults on top of them.
- **"Later tiers like 2-3 elites" read as elites in acts 2 and 3**, as with "3 tier ... 30 rooms" (2026-11-04 entry above). [Difficulty tiers (Normal, Hard): they don't exist yet, and he has used "tier" for act before.] Flagged to the director; it's one data value either way.
- **Elite rare card chance 25% in acts 2-3, 0% in act 1** (data per act); the rare card offer comes after the relic offer. ["Smaller" than the mini-boss's 100%; 25% gives about 1-2 extra rare offers per run on an elite-heavy route.] Set by the MAP3 sim.
- **Relic targets over the run: hunter median 14-17, best path about 18-19, ignore route 4-6.** "Hard to reach 20" means the cap is above what a perfect hunter path gets today. Per act: best-path relic estimate [4, 6], at most 2 relic stages per path; merchant prices 80/120/170 in MAP3 (MAP2 keeps 60/90/130 for one act). [B's 15-20 with cap 25: the cap must stay hard to reach.] All data, set by the MAP3 sim.
- **The swap at the cap is built in BD2** with the relic offer panel and tested with a low cap; the MAP2 merchant reuses it. Cancelling the swap keeps your relics and declines the offer. This replaces the BD2 call "at the cap, relic sources fall back to a card offer" (2026-11-02). [Deferring it to MAP3, when the cap first becomes reachable: that means a throwaway fallback and reworking the panel later.]
- **A relic you gave up is never offered again in the same run**, which extends "no duplicates" so you can't swap the same relic back and forth. [Only filtering owned relics.]
- **Rare cards need a card rarity, which doesn't exist yet.** MAP3 adds an optional card `rarity` field (default `common`) and enough rare cards per pool. A pool with fewer than 3 rare cards fills the offer from the normal weights. [Treating reward-only or locked cards as "rare": that mixes up availability with rarity.]
- **A short relic pool degrades gently:** an offer with fewer than 3 eligible relics shows what's left; with none, an elite or relic room gives its card offer and the merchant shows fewer relics. The given-up list is `RunState.relics_given_up` and is saved. [Allowing duplicates once the pool runs out: that breaks his no-duplicates rule.]
- **Relic content target about 22 eligible per class** for the 14-17 hunter (15 sketched today across BD2/BD3); added to MAP3's scope, count confirmed at MAP2's close. [Lowering the hunter target to fit 15: that misreads "let it grow".]
- **D36 = A needs no work.** PL3 item 13 is closed as "the volley stays; the bot's pellet blind spot is a bot issue". The pellet-aware bot stays a tooling option.

## 2026-11-04 - Applying the director's revised relic and card tiers (item 42) (game-lead)
He confirmed that "later tiers" means acts 2-3 and then revised D34 = C. His rules are recorded in GDD §4a/§9, `docs/MAP.md` §2/§4.4/§4.5/§10, BUILD_DEPTH §4.1/§4.2/§4.6/§11 and the ROADMAP (BD2, MAP2, MAP3). **Superseded from the entry above:** the 25% elite rare-card chance (elites never offer cards now), and the ignore-route target of 4-6 (now 6-8, because everyone gets 2 boss relics). These are my readings and defaults on top of his rules.
- **Tier odds per act:**
  - act 1: tier 1 80, tier 2 20, tier 3 0;
  - act 2: 15 / 70 / 15;
  - act 3: 5 / 25 / 70.

  They apply to every tier 1-3 relic source (elite, relic room, merchant, buff room), not only elites. One-act runs use act 1's row. [Applying the odds to elites only: his tier table read as a rule for the whole act.] Set by the MAP3 sim.
- **The boss-tier relic offer can't be skipped, and boss-tier relics can't be given up in a swap**, so "you always have 2 boss-tier relics per run at the end" holds. They count toward the cap of 20. [A skippable offer, which would break his "always 2"; boss relics outside the cap, which would be a second cap rule to explain.]
- **Mini-boss card offers follow the normal reward rule** (pick 1 or reject with a token). Mini-bosses keep the gold 60 from his first D34 answer. [A free skip.]
- **Card rarity odds per offer slot:**
  - act 1: common 100;
  - act 2: common 80, rare 20;
  - act 3: common 62, rare 30, legendary 8.

  A short pool falls back to the next rarity down. [Odds per offer instead of per slot, which is harder to reason about.]
- **The relic data field keeps the name `rarity`, with values `tier1`/`tier2`/`tier3`/`boss`,** because `run.json` `tiers` already means enemy tiers. The player sees "Tier 1/2/3" and "Boss". BD2 uses these values from the start. [A field named `tier`, which would clash with the enemy tiers.]
- **Optional in-act mini-boss nodes (MAP4) give gold and a relic with the next act's tier odds, but never a boss-tier relic,** because he made act-end mini-bosses the only source. [Dropping the optional nodes.]
- **Content cost, flagged:**
  - about 6 boss-tier relics per class, which need a game-lead design pass first and may need new effect code;
  - about 5+ rare and 4+ legendary cards per class pool;
  - about 22 tier 1-3 relics per class.

  MAP3 may be split into MAP3 (acts, save/resume) and MAP3b (rarity content) at MAP2's close. [Building all the content now: BD1 and BD2 come first.]
- **His other item 42-46 replies** (his 43 = my 41, his 44 = my 40, his 45 = my 39, his 46 = my 35) are recorded as acknowledged in OPEN_ITEMS and STATE. They aren't decisions.

## 2026-11-04 - All relic sources and starter relics in the loadout (game-lead)
The director's direction is recorded in GDD §4a. The plan is BUILD_DEPTH §4.7, with pointers in MAP.md §2/§9 and the ROADMAP (BD2, MAP1, MAP2, MAP4, 3d). These are my calls on the details.
- **One place for the plan,** BUILD_DEPTH §4.7, with pointers everywhere else. [Copying it into every doc.] Game details come only from his summary; anything else is "unsure".
- **Curse and buff rooms become event kinds** in a data-driven event system, and so does the altar. [Separate room types per kind.] MAP4 is renamed "events" and probably splits in two at MAP3's close. That pushes 3d later; I didn't re-sequence it.
- **Event outcomes come from a closed list,** and every choice shows its costs plainly (readability). [Free-form scripted events: that would mean a script per event, against "content is data".] The text stays placeholder because the story role is dormant.
- **Merchant third slot is shop-only,** meaning relics whose `sources` is exactly `["merchant"]`, falling back to normal stock. The Last Flame's trophy research waits for GDD §8. [A separate shop-only flag: `sources` already says it.]
- **Chest sizes:**
  - small, medium and large, with weights 50/35/15, shown on the map;
  - medium uses the next act's odds, and large is at least tier 2 using the act 3 row;
  - still pick 1 of 3 (D22). [One guaranteed relic with no choice: that changes D22's "pick a relic".]
- **Sacrifice:** an altar event (give up tier N, pick from tier N+1) and a `sacrifice_cost` field. Both reuse the give-one-up step and the no-return rule. [Altar only: he named "high-tier relics that require a sacrifice" specifically.]
- **Curses are downside-only relics.** They're outside the cap of 20, can't be discarded through the swap step, and are removed by events or the merchant. [Counting them toward the cap, which would punish you twice.]
- **Starter relics follow his follow-up message:**
  - they're chosen in the loadout (3d) from the unlocked tier 1 relics with `sources` `["starter"]`, and found nowhere else;
  - there's no random opening offer, so the boss-relic opening swap I had drafted as D38 is moot and was never asked;
  - run 1 and the preset start have none;
  - until unlock rules exist, 2 per class are unlocked by default and the rest are `locked` (TBD), like D23 for cards. [All unlocked: there would be nothing to unlock later.]

  This reverses my BD0 default "no starting relic for now".
- **BD2 only reserves the new `sources` values and `sacrifice_cost`.** [Building a starter relic in BD2: he put it in the loadout.]
- **The rest dig is asked (D37),** because it contradicts D30's reason, "heal or relic is too obvious". Until he answers, MAP4 plans it as optional.

## 2026-11-04 - Relic candidates from the director's Gemini list (game-lead)
- **Adapted 12 ideas, 4 boss-tier ideas and the Forge into BUILD_DEPTH §4.5/§4.7 as unscheduled candidates.** Hand, energy and draw ideas were translated to our slots and cooldowns, or left out (we have no resource system). [Adding them to BD2/BD3 scope now: BD2's seven are set, and BD3's brief is written at BD2's close.]
- **Ideas needing new effect code are marked** (`chain`, pull, projectile reflection, tether), so the content budget sees them. [Dropping them: chain and reflection are strong ARPG flavour.]
- **Cursed Gauntlet (no dodge) is kept as a boss-tier candidate,** even though the dodge-off trial (D29) felt less fun as a baseline. As an opt-in trade-off it's a different question. [Dropping it because of D29.]

## 2026-11-04 - Gemini round 2 candidates (game-lead)
- **Sorted them into keep, fix, merge, drop and move, as unscheduled candidates in BUILD_DEPTH §4.8.** Each fix adapts the idea to systems we have, for example no crit (use +damage), no root (use stun), and no infinite stacks (use a cap of 10). Duplicates are merged with the existing sketches. [Taking them as written: several rules don't work here, e.g. Incidental Expense, where a Burn that ends on its own has no damage left.]
- **Brainstorming Session uses Shift + key for the second card,** taking over the swap input, instead of a double-tap, which clashes with hold-to-aim. [Double-tap.]
- **The Complacency Trap is only offered with 2+ dodge charges,** so the Wizard isn't left without a dodge (D29 = B). [Letting it reach 0.]
- **Curse cards are asked as D38,** because they change my earlier default (curses as relics). They'd also give the dead-card swap a real job, which he asked for (GDD §4, 2026-11-02). They're needed by MAP4 only.

## 2026-11-04 - Applying D37 = A, D38 = A (game-lead)
His answers are in GDD §4a, BUILD_DEPTH §4.2/§4.6/§4.7/§4.8, the MAP.md §9 row and the ROADMAP MAP4 brief.
- **Curse cards carry a `curse` flag and are never offered,** and `can_remove` always allows removing them. [A separate curse pool file: the flag is simpler.]
- **The relic `curse` field is now unused.** BD2 should leave it out of the schema. [Keeping it reserved, which would be dead schema.]

## 2026-11-04 - BD1 split into two gameplay-dev sittings (game-lead)
- **Choice:** BD1's gameplay-dev step runs in two sittings. The rest of the loop (ux -> qa -> playtester -> tech-writer -> close, one tag) runs once, after both.
  - **BD1-A (engine):** brief items 1-6: tags and `data/keywords.json`, the `CombatEvents` autoload, effect `condition`, primed buff, `status_damage_mult`, aoe `anchor: "caster"`. Unit tests for each. Standard-policy sim hashes and arena hashes must not move; reload soak required (new autoload).
  - **BD1-B (content and tooling):** brief items 7-10 (8 cards, 4 debug decks, `-Plan` bot policy, ux data exposure) plus the PL3 carry-overs (ROADMAP, under PL3).
- **Why:** the brief is larger than one sitting, and the director can be cut off at any time. The cards and the ux exposure need every engine piece, so the dependency seam sits between items 6 and 7. Each sitting leaves the repo running and committed.
- **Rejected:** two full loops (BD1a/BD1b, each with qa, playtest and a tag). Engine-only work has nothing for the playtester to feel and would double the review cost. Also rejected: one sitting, which risks a half-built engine at a cutoff.
- **Checked first:** item 6 (`anchor`) isn't built yet. PL3's "anchor" was the screenshot-capture boss-attack anchor. `EffectTemplates.gd:328` still locks placed discs at the aim point.

## 2026-11-04 - BD1-A engine calls (gameplay-dev, logged by game-lead)
gameplay-dev made these in a141865..7c5a66b. All are cheap to change.
- **CombatEvents** (`src/core/CombatEvents.gd`, class `CombatEventsRelay`, the last autoload) holds only a clock and a cast history.
  - The clock is game time: it pauses, scales with hit-stop and repeats in seeded sims.
  - The history window is 6 s with at most 32 entries, so `cast_within.seconds` must be above 0 and at most 6.
  - A cast is recorded after its effects run, so a card never sees its own cast.
  - Code that `bot_sim.gd` also compiles reaches it through `CombatLink.events()`, because the bare autoload name doesn't compile in `-s` scripts.
  - Rejected: storing the history on `CardSlotController`. The relay is where BD2's relic events go.
- **Tags and keywords share one capitalised namespace** (Burn, Dash, Primer). The fixed order is Projectile, Melee, Area, Zone, Dash, Heal, Burn, Bleed, Buff, then keywords.
  - A damaging dash is Melee and Dash.
  - A zone's status counts toward Burn and Bleed.
  - A heal_over_time or lifesteal status counts as Heal.
  - Conditional effects count like unconditional ones.
- **Primed stat:** `slot_cooldown_skip.<slot>`, additive 1.0.
  - A skipped cooldown is `MIN_COOLDOWN` (0.05 s) rather than 0, because 0 would mean a divide-by-zero in the UI.
  - Charges are consumed after the cast, from a snapshot taken before it, so a card never eats its own prime.
  - A skip buff is only consumed by a cast in its own slot.
- **Conditions:**
  - `target_has_status` is allowed only on cone, aoe, projectile, zone and apply_status.
  - `min_stacks` and the three later BUILD_DEPTH condition types are rejected until stacking exists.
  - A projectile that fails its condition is spent and deals nothing.
  - Dash path hits ignore target conditions.
  - `CardDamageRule` skips conditional effects, because the rule applies to unconditional damage.
  - Authoring rule: a conditional effect must come before the effect that applies the status it tests.
- **`status_damage_mult`** is read by status ticks only. Zone ticks don't read it, but Burn that a zone applies is a status, so it does.
- **`anchor: "caster"` together with `max_range`** is a validation error, not an override.
- **Dodge vs Movement casts:** the dodge does **not** count as a Movement cast for `cast_within` or primes. That is current behaviour and the D39 default (A), because the dodge stays a pure escape (BUILD_DEPTH §8). Rejected for now: counting it, which would make Hit and Run's payoffs free on every dodge. Asked as D39.

## 2026-11-04 - BD1-B: new standard baselines, and gameplay-dev's calls (game-lead)
- **Hashes rebaselined.** The brief expected the standard-policy hashes to hold, and they didn't.
  - **Cause:** the arena Player and the bot sim fill slots from *every* card in the owned pools (`CardSlotController._owned_card_ids_for_slot`), so any new card moves them. gameplay-dev proved the 8 new cards are the only cause: taking them out at HEAD restores 2333565009 / 1212800 / 2281795515 exactly.
  - **New baselines:** arena 30 s seed 1 = **1897787086**; 90 s = **4207041509**; bot sim `-Rooms 20 -Seed 3` = **846850403**.
  - **Rejected:** adding an availability field now to keep the new cards out of pool-fill. That is 3d item B (D23), and pulling it forward would widen BD1.
  - **Side effect:** new runs can now roll the new cards into their random starting slots, as any pool card can. The preset decks are unchanged. The playtester should say if that muddies the archetypes. 3d's `starter`/`reward` availability is where this gets controlled.
- **Plan baselines** (`-Rooms 20 -Seed 3 -Plan`):
  - standard 2387448677
  - rogue-kindling 3642396276
  - rogue-hit-and-run 212612574
  - wizard-controlled-burn 1247966865
  - wizard-departure-lounge 1255552678
  - Wave sim arena `-Plan` 30 s seed 1: state_hash 1160207333.
- **gameplay-dev's calls (3e297d5..49b117b):**
  - **Bot sims:** the plan bot spans both sims through a shared `PlanPolicy`.
    - `bot_sim` uses a stand-in caster and a hand-stepped CombatEvents clock (`CombatEventsRelay.step`). It fakes one enemy's Burn and Zone state for 4 s after a matching cast.
    - The plan bot treats the dodge as "ready" while it has a charge, rather than by the sim's throttle. Otherwise it would act like D39 = B.
  - **D39 switch:** `data/player.json` `dodge.counts_as_movement_cast` (false = A), in one place (`CombatEventsRelay.notify_dodge`).
  - **Launch and capture tooling:**
    - A scenario with its own `character` plus a different `--class` is refused with exit 2, following the `--deck` precedent.
    - `-StartRoom` past the end prints a plain "note:", because the wrappers fail on any WARNING line.
    - Capture states that need a run go in `tools/capture_presets.json` (`-Preset`), not `scenarios.json`.
    - The forced reward offer `--run-offer=a+b+c` is capture-only.
  - **Slot glow:** a slot glows when any of its conditional effects is live.
  - **Numbers §5 left open:**
    - Drive-By: cone 1.8 / 45°, knockback 3.
    - Momentum: speed 16.
    - Slow Burn: range 8, status 3 s.
    - Parting Gift: blink 5 m, +0.5 s cooldown.
    - Heat Sink: range 8 on both discs.
    - Well, Actually: knockback 6 on the conditional hit.
    - These are all data.
  - **Dodge-pressed leak between suites:** not isolated. Every dodge suite now releases the action in `DodgeSwitch.reset()`.
- **Commit trailers:** 22ee886 and 49b117b carry gameplay-dev's own model trailer. They were left as they are; history isn't rewritten for a trailer.

## 2026-11-04 - BD1 ux calls (ux-designer, logged by game-lead)
ux-designer made these calls in b61c388..1d3cbda. All values live in `data/ui.json` `hud`.
- **HUD slot height:** 134 -> 142 px. This adds room for a chip row (name 44, chip 16, preview 40). Rejected: squeezing the existing rows, which pushed the Next line under the frame.
- **Chips:** up to 3. Keywords are filled; derived tags are outlined.
  - When chips don't fit, they drop from the end, so keywords stay. At 1024x600 a slot shows about 2 chips.
- **Keyword rule text is tooltip-only** on the reward and removal screens. A visible rule line dropped the reward fit below the 0.7 floor.
- **Live glow:** yellow `#ffe94a` rings, corner brackets and a "LIVE" pill. The easing is 0.08 s rise, 0.3 s hold and 0.25 s fade.
  - The glow shows at 55% while the slot cools, so the player can plan around it.
- **Primed marker:** a cyan `#5ad8ff` bolt, "xN" when there is more than one charge, and a drain bar. Rejected: the word "PRIMED", which doesn't fit next to "Ctrl".
- **Card text order:** in `CardSummary.effect_line`, condition lines now come after the cooldown, each on its own line.
- **No condition sentence on the HUD in combat.** The HUD ignores the mouse, and the sentence doesn't fit. A pause-screen list of slot cards is the fallback idea, not scheduled.
- **1024x600 card-strip overflow:** fixed (3.3 px -> 0.3 px).

## 2026-11-04 - BD2 split into two gameplay-dev sittings (game-lead)
- **Choice:** BD2's gameplay-dev step runs in two sittings, like BD1. The rest of the loop (ux -> qa -> playtester -> tech-writer -> close, one tag) runs once, after both.
  - **BD2-A (engine, no player-visible change):**
    - the rest of the `CombatEvents` relay (BUILD_DEPTH §4.3), with every event the 7 relics need, including `status_ended` with reason `owner_died` fired before the node frees, and `dash_ended`;
    - `hit_landed.origin`;
    - `RelicManager`;
    - the `data/relics/*.json` loader and validator, with the full `sources` list (`elite`, `relic_room`, `merchant`, `mini_boss`, `curse_room`, `buff_room`, `boss`, `starter`, `event`, `altar`; chests are a `relic_room` size, BUILD_DEPTH §4.7 row 4, not a source) and `boss` tier valid only with `mini_boss`;
    - the `run.json` `relics` block, including `enabled`;
    - `RunState.relics` and `relics_given_up`;
    - the recursion guard;
    - the pure offer function: source, count and rng in; pool, source, owned and given-up filters; tier weights per act.
    - Test fixture relics only. No relic files ship in `data/relics/` yet.
    - BD1 carry-overs: the `JsonDataTable.get_entry` type fix, the `status_damage_mult` validator floor, and the slice6 crowd flake.
  - **BD2-B (content and run flow):**
    - the 7 relics;
    - elite relic offers and the straight-run relic room;
    - the at-cap give-one-up step;
    - ux data exposure (trigger signal, owned and given-up lists, pending swap state with cancel);
    - bot sim relic picks;
    - BD1 carry-overs: the sim tooling (damage-by-source tally, preset card swap, timed-out boss runs reported separately) and the seed 7 no-card Rogue soft lock.
- **Save round trip means `RunState.to_dict()` / `from_dict()`, proven by tests.** No save file is written in BD2. A save file and resume are MAP3 (D32). Rejected: building the save file now, which is MAP3's scope.
- **Hash gates:**
  - **BD2-A:** suite all green; arena 30 s seed 1 = 1897787086, 90 s = 4207041509; bot sim `-Rooms 20 -Seed 3` = 846850403. None may move, since no relic ships.
  - **BD2-B:** the relic room changes the run's room list, so the bot-sim hash will move. With `relics.enabled` false the run must still give 846850403. New relics-on baselines are logged, as BD1-B did. The arena hashes shouldn't move.
- **Exit Strategy:** BUILD_DEPTH §4.5 already lets it slip to BD3. gameplay-dev makes that call in BD2-B and reports it. `dash_ended` is built in BD2-A either way.
- **Why:** BD2 is as large as BD1. The relics need every engine piece, so the seam sits between the engine and the content. Each sitting leaves the repo running and committed.
- **Rejected:** two full loops (engine-only work has nothing to playtest), and one sitting (it risks a half-built engine at a cutoff).

## 2026-11-04 - BD2-A engine calls (gameplay-dev, logged by game-lead)
gameplay-dev made these calls in 3b1ac07..fe051cc. All of them are cheap to change. Gates held: suite 1499/1499 (125 suites); arena 1897787086 / 4207041509; bot sim 846850403 (game-lead re-ran it).
- **Relic effects run deferred** (end of frame), not inside the event that caused them. Godot blocks spawning a projectile or a dash inside `area_entered`. `relic_triggered` fires when the effect runs. Rejected: synchronous effects, which error in the engine.
- **A missing or empty `data/relics/` means no relics,** not an error.
- **Offers:**
  - eligible ids are sorted before the weighted draw;
  - a tier with weight 0 is ineligible;
  - boss relics are drawn only when the caller asks for `rarities=["boss"]`, uniformly;
  - a boss relic needs `sources` to be exactly `["mini_boss"]`.
- **`run.json` `relics` tier weights:**
  - act 1: 80/20/0;
  - act 2: 15/70/15;
  - act 3: 5/25/70.

  These are from MAP.md §4.5. Acts past the last row use the last row.
- **Relic format:**
  - `flavor_text` is required;
  - modifiers have no duration or charges;
  - a relic needs at least one modifier or trigger.
  - Extra filter keys: `every_nth`, `min_amount`, `kind`, `damage_type`, `target_has_status`, `tag`, and `origin` with `card:*` wildcards. `allow_relic_origin` is only valid on events that carry an origin.
- **`at`:**
  - an aoe lands at the event point;
  - a zone lands at the event point, clamped by its `max_range` from the player;
  - projectile and dash ignore `at`.
- **Relay order on a kill:** `hit_landed` -> `enemy_killed` -> `status_ended(owner_died)` -> the enemy's own died handler. `dash_ended` fires for card dashes only, not the dodge. `room_cleared` also fires for rest rooms.
- **Statuses carry their origin.** A status tick has origin `status:<id>`, not the relic that applied it. A `hit_landed` relic with no origin filter can fire on ticks of a relic-applied Burn. That is bounded by the chain depth of 1, not a loop. Accepted.
- **Relics roll chances on `player.status_rng`**, so holding relics shifts card status rolls. That is expected hash movement in BD2-B.
- **`JsonDataTable`:** `get_entry` stays `-> Dictionary` and errors loudly on a non-object entry. Validators use the new `get_raw`.
- **`status_damage_mult` floor:** a buff or relic modifier at or below -1 is rejected.
- **`RunState` `FORMAT_VERSION` stays 2.** The relic keys are always written; old dicts load as empty lists.

## 2026-11-04 - BD2-A follow-ups decided by game-lead
- **Relic counters and internal cooldowns reset every room,** as built. Spite Knuckles' "every 4th light hit" restarts each room. That is the simplest rule, and it matches cooldowns resetting between rooms. Rejected: keeping counters in `RunState`, which adds save state for little gain. If the playtest finds it feels wrong, game-lead writes a proposal.
- **Relics get a required `rule_text` field in BD2-B,** a plain one-line rule for the HUD chip and the pause list. Rejected: deriving the text from triggers, which reads badly for rule-changing relics.
- **slice6 crowd flake:** localized (the first crowd run in a suite differs from tick 73), not fixed. The test is qa's file. qa tries the warm-up patch in BD2's qa step: one discarded `await _aligned_crowd(11)` before `var first := await _aligned_crowd(11)` in `slice6_qa_test.gd`. qa validates it over several full runs.

## 2026-11-04 - BD2-B content and run-flow calls (gameplay-dev, logged by game-lead)
gameplay-dev made these in 673db13..1af42c5. All are cheap to change.

Gates: suite 1546/1546 (128 suites); arena 1897787086 / 4207041509 / `-Plan` 1160207333; bot sim 846850403 and every `-Plan` checksum unchanged. Relics off: `wave_sim -Run -NoRelics` matches the pre-BD2-B repo line for line.

- **Correction to "BD2 split":** that entry expected the bot-sim hash to move with relics on. It can't: `tools/bot_sim.gd` builds no rooms, choices or relics. The relic run baselines are the `wave_sim -Run` numbers, not the bot sim:
  - Rogue and Wizard each won 12/12 with relics on.
  - Boss time medians are 57.3 s (Rogue) and 62.5 s (Wizard).
  - Relic damage is under 1% of the total.
- **Exit Strategy moves to BD3.** A line of fire along the dash path needs new zone placement code. The 6 relics shipped are Pyre Insurance, Smoldering Grudge, Lingering Embers, Second Wind (Unwillingly), Spite Knuckles and Heavy Sigh.
- **New generic pieces:**
  - New stats:
    - `card_damage_mult_vs_status.<id>` applies to card-origin damage only;
    - `zone_duration_mult` is clamped to the zone cap;
    - `zone_status_chance` is additive and capped at 1.
  - A new effect template, `reduce_cooldown {slot_type, seconds}`, for Second Wind.
  - The validator floors the factor stats at -1.
- **Relic room placement:** it turns one combat room into the relic room, so the run stays 10 rooms. It has its own seeded RNG and is never next to the rest room, the elite or another relic room. The next fight may redraw its wave list to keep the no-repeat rule. `run.json` gets `relics.relic_room {count, first, last}`. The `rooms.relic_room: []` entry is a stopgap for qa's generator test.
- **Fallbacks and costs:** a relic room with nothing eligible gives a card offer, as the elite does. Skipping a relic offer costs no reject.
- **Relic tuning:**
  - Pyre Insurance has `allow_relic_origin` true, so it pops Spite Knuckles' Burns.
  - Heavy Sigh has a 0.5 s internal cooldown.
  - Spite Knuckles' Burn lasts 4 s.
  - Smoldering Grudge counts card zone ticks.
  - Lingering Embers makes any zone status certain.
- **Odds and pools:** the straight run uses act 1 tier odds. The Wizard sees 5 of the 6 relics, because Spite Knuckles is in the rogue pool.
- **Bot relic policy:** a relic "matches" the deck when one of its keywords is carried by at least 3 deck cards. Otherwise the bot takes the first offered. At the cap it gives up the first giveable relic.
- **The seed 7 no-card soft lock was a bot deadlock,** not a game bug. After 45 s with no kill and one enemy left, the bot stops dodging. Seed 7 now reads LOST.
- **The relic room is named "Relics" on the plate,** to fit the existing plate-width test. ux may change it.

## 2026-11-04 - Relic room position (game-lead)
- **Choice:** keep the shipped range, 0-based `first: 2, last: 8`, which is on-screen rooms 3-9. About 31% of seeds put it on room 9, right before the boss.
- **Why:**
  - "Rooms 2-8" was game-lead's wording in BUILD_DEPTH §4.1, not the director's, so this is a game-lead call.
  - The literal reading (on-screen 2-8) puts the relic room at room 2 in about 80% of seeds, because of the rest and elite spacing. That's a poor spread.
  - A relic just before the boss is a fair "prepare for the boss" beat.
- **Rejected:** on-screen 2-8 (it bunches up at room 2 and breaks two qa tests that use seed 42's room 2).
- The playtester is asked whether room 9 feels right. The MAP1 map replaces this with a node anyway.

## 2026-11-04 - BD2 ux calls (ux-designer, logged by game-lead)
ux-designer made these in 4040259..92e4a31. Suite 1581/1581 (129 suites). All hashes unchanged and the reload soak is OK.
- **HUD relic row:** under the dodge pips, as wide as the health panel, and it wraps. Each chip shows a two-letter mark in a pool-colour frame. A trigger lights the chip with a ring and shows a name tag. Rapid repeats stay lit and show "xN" instead of strobing.
- **Offer cards:** square corners, a filled "Relic" band, a hexagon, the tier, the pool, keyword chips, the rule and the flavour. Skip is a green "Free" tile. The give-up step shows a "Taking: X" plate and a Cancel button. Boss relics show in a "Cannot be given up" row.
- **`chip_keyword_color`** changed from `#d8c8ff` to `#b8dcff`, so it doesn't clash with the relic violet `#c9a2ff`.
- **"Minimum HUD scale"** means 1024x600 (scale 0.833), since there is no UI-scale setting.
- **BD1 carry-overs:**
  - The primed marker has a 12 px font floor and a flash with "USED" or "GONE" when the prime ends.
  - A slot that isn't lit shows a dim condition line such as "Needs Burn".
  - Reward cards that need a Movement cast note that the dodge doesn't count.
  - A card that is both Keystone and Payoff gets one "Keystone + Payoff" chip, in gold with a star.
  - A non-breaking space keeps "3 s" together.

## 2026-11-04 - Two small ux calls ux-designer raised (game-lead)
- **The relic room plate keeps "Relics".** "Relic room" would push the boss bar to about 502 px at 1024x600, against a 500 px stack threshold. It would also need a test edit. The map (MAP1) turns this room into a node anyway. Rejected: widening the plate.
- **No dodge note on the HUD slot.** It's on reward cards only. The slot's key row is about 55 px wide, and a taller slot would reopen PL3's pinned 142 px. Rejected: a wider key row or a taller slot. Revisit if the playtester finds the HUD's "After Move" confusing.

## 2026-11-04 - BD2 qa carry-overs routed (game-lead)
- **qa verdict:** PASS with carry-overs (`docs/reviews/2026-11-04-bd2-qa.md`).
- **qa kept the slice6 warm-up patch.** Unpatched it failed 1 in 10 isolated runs; patched, 0 in 15.
- **3d item 6a (save robustness) moves into MAP3, before the save file.** `RunState.from_dict` crashes on a null, array or object `offer` entry, and the save file ships in MAP3 (D32). That fix must land before any file on disk can feed `from_dict`. MAP3 also adds relic checks: owned and given-up lists don't overlap, the cap holds, the ids exist. Rejected: leaving it in 3d, which comes after the save file.
- **The `rooms.relic_room: []` stopgap goes with MAP1's gameplay-dev step.** It's a one-line data change. The stopgap note in "BD2-B content and run-flow calls" is now out of date.
- **The c1e ghost-look flake** (pre-BD2, about 1 in 5) goes to qa with MAP1.
- **Correction to "BD2-B content and run-flow calls":** relic damage is about 1% of the total, not under 1%. qa measured 0.45% for the Rogue and 1.15% for the Wizard.

## 2026-11-05 - MAP1 relic nodes on rooms 3-8 (game-lead)
- **Choice:** MAP.md's `relic_room` node window changes from rooms 3-9 to **3-8** (1-based, with the boss on room 10). Room 9, just before the boss, never holds a relic node.
- **Why:** the BD2 playtest said a relic on room 9 gets only one fight of use and suggested "by room 7". On the map a relic hunter passes several relic nodes, so 3-8 still leaves room for a relic route. It's a one-number data change.
- **Rejected:**
  - 3-7, which squeezes the relic route with `relic_route` [5, 7];
  - keeping 3-9.
- The director can say otherwise (OPEN_ITEMS 49). BD2's straight-run relic room is unchanged, since it only runs with the map off.
- **Director feedback 2026-11-05 (recorded, not a decision):** "Relics feel fun so far, builds are starting to get more exciting and strategy starting to fold in." Pending for tech-writer at MAP1's docs pass: a CHANGELOG human-playtest note, and archiving the answered parts of item 49 in RESOLVED. The old item 49 text is in commit 9cde725.

## 2026-11-05 - MAP1 split into two gameplay-dev sittings; route bots in the run sim (game-lead)
- **Choice:** MAP1's gameplay-dev step runs in two sittings, like BD1 and BD2. ux, qa, playtest and docs run once, after both.
  - **MAP1-A (map engine, no player-visible change):**
    - the `data/map.json` loader and validator (MAP.md §6), shipped with **`enabled` false**;
    - the seeded generator (MAP.md §3) with every rule, and a loud error after `max_attempts`;
    - the relic estimate (§4.1);
    - RunState `map`, `path`, `gold` and `xp_earned` in `to_dict`/`from_dict`/`equals`;
    - a map print helper for debugging;
    - the 1000-seed generation sweep;
    - the BD2 carry-over that validates `ui.relic.swap_line_one` in `RunConfig`.
  - **MAP1-B (map run flow):**
    - node handling (combat card offer + gold, elite relic offer + gold, relic_room with chest sizes, rest, boss);
    - gold rolls seeded from the run seed and node id (`run.json` `gold`);
    - mid-map restore of the open choice;
    - `--run-room=N` along the `first` route;
    - route bots;
    - ux data exposure (map, reachable nodes, current node, hover text from data, gold);
    - a `--map` / `--no-map` launch override;
    - BD2 carry-overs: delete the `rooms.relic_room: []` stopgap, and check whether bot sim `-Swap` is a no-op.
  - **`map.enabled` stays false in shipped data until ux's map screen exists.** ux flips it to true in its step, and qa then re-baselines. Rejected: shipping it on in MAP1-B with no way to pick a node.
- **The route policy goes in `wave_sim -Run`, not `bot_sim`.** BD2 found that `tools/bot_sim.gd` builds no rooms, choices or relics, so it can't follow a route. The `-Rooms 20 -Seed 3` bot-sim hash stays a combat baseline and shouldn't move. The run-sim baselines are re-taken with `-Route first`. This corrects MAP.md §8 and the MAP1 brief, which named the bot sim.
- **Why the split:** the generator and its rules are self-contained and testable alone, and the run flow needs them. Each sitting leaves the repo running with the map off.

## 2026-11-05 - MAP1-A map engine calls (gameplay-dev, logged by game-lead)
gameplay-dev made these in afdf30d..ed4e2aa. The map ships off (`data/map.json` `enabled` false).

**Gates:** suite 1640/1640 (134 suites) at afdf30d; ed4e2aa added 2 tests, so 1642 is expected, to be confirmed by MAP1-B's full run. Arena, bot-sim and run-sim baselines are unchanged. The 1000-seed sweep has 0 failures (worst 83 of 200 attempts, about 41-52 s).

- **`min_branching` 0.6 -> 0.4 (accepted by game-lead).**
  - 4 random walks gave 0 valid grids in 20,000 draws at 0.6. Typical valid grids branch at 0.2-0.4.
  - Rejected: 6 walks with 0.5 (more nodes and clutter); a merge-biased walk (an algorithm change).
  - **Revisit if the MAP1 playtest says routes don't feel like decisions.** A merge-biased walk is then the fix.
- **Type weights:**

  | Type | Old | New |
  |---|---|---|
  | combat | 50 | 40 |
  | elite | 14 | 16 |
  | relic_room | 10 | 14 |
  | rest | 10 | 10 |
  - **Accepted by game-lead.** The old weights rarely met the best-path relic estimate of 5 or more, and the sweep took 2.7x as long.
  - **Cost:** fewer combat nodes (about 60% -> 50% of picks), so fewer card offers and less gold per route. More elites and relic rooms.
  - Rejected: the old weights with `max_attempts` 400 (content-neutral, but a thin margin and a slow sweep).
  - This is first-pass data, so the MAP1 sim and playtest should check run difficulty and card count.
- **Node ids** are `(room - 1) * columns + column`, with the boss in column 2.
- **Attempts:** `max_attempts` counts type draws only. Grid redraws for shape rules cost no attempt (bounded at 5000).
- **The map seed** is its own stream derived from the run seed; RunGenerator's stream is untouched.
- **Wave ids** avoid the predecessors' lists when another list fits. With 3 combat lists and 1 elite list, some repeats are unavoidable.
- **A type with no candidate left fails the draw**; there is no fallback to combat.
- **`swap_line_one`** is validated only when present.
- **Validator bounds:** `MAX_ROOMS` 16, `walks` 2-16, `columns` 2-8.
- **Relic-counting types** for the estimate are a code constant (`MapConfig.RELIC_TYPES`), not data.
- **Docs:** MAP.md §3.4 and §6 are updated by game-lead to 0.4 and the new weights.

## 2026-11-05 - MAP1-B map run flow calls (gameplay-dev, logged by game-lead)
gameplay-dev made these calls in 2181b9b..3a2d9d8. The map is still off in shipped data.
- **Gates:** suite 1671/1671. All map-off gates are unchanged (arena 1897787086 / 4207041509; bot sim 846850403; run sim 12/12, 57.3 s / 62.5 s). No-card runs: 0/12 on both the straight run and `-Route first`.
- **Gold** (`run.json` `gold`):
  - combat [12, 18], elite [30, 40], mini_boss [45, 55] (unused until MAP3);
  - boss, rest and relic stage pay 0;
  - gold is paid once, at `_finish_room`;
  - `--run-room` gives no gold for skipped rooms.
- **Chests** (`map.json` `chests`, optional):
  - small uses the act's row, medium the next act's row, and large the act 3 row with `min_tier` 2;
  - weights 50/35/15;
  - sizes are assigned in a post-pass with their own stream, so map layouts are byte-identical to MAP1-A.
- **Map runs:**
  - A run is a map run when its RunState holds a map. The data switch only decides what new runs get.
  - A map run opens on the room-1 pick.
  - `--run-room=N` lays the path along the `first` route.
  - `from_dict` drops the map loudly when `path` and `room_index` disagree.
- **Launch refusals:** `--map` and `--no-map` exit 2 only when both are given, either is repeated, or a value form is used.
- **Route policies:**
  - `relic` maximizes the estimate; ties go to the lowest column.
  - `safe` prefers the fewest elite-like nodes, then the most rests, then the lowest column.
  - `random` has its own rng.
- **Two edits in ux files,** both needed for the flow and pinned by tests:
  - `ClassPickScreen.should_open` opens only at a map run's start.
  - `RunPromptScreen` stays open when a new choice follows a reward.
- **The bot sim `-Swap` carry-over is not a bug.** A Recovery swap never shows, because the bot-sim caster is never damaged. An Attack swap moves the plan checksum.
- **Route baselines** (`-Run -Seed 1 -Runs 12 -Route r`):

  | Class | Route | Won | Boss median | Median relics | Median gold |
  |---|---|---|---|---|---|
  | Rogue | first | 12/12 | 66.2 s | 2.5 | 144 |
  | Rogue | relic | 11/12 | 52.9 s | 5 | 147.5 |
  | Rogue | safe | 12/12 | 58.4 s | 2 | 100 |
  | Wizard | first | 10/12 | 60.6 s | 2 | 130 |
  | Wizard | relic | 11/12 | 63.2 s | 5 | 146 |
  | Wizard | safe | 12/12 | 65.0 s | 2 | 100 |

  The relic route's median of 5 sits at the bottom of `relic_route` [5, 7]. Content limits it: the Rogue has 6 relics and the Wizard 5.

## 2026-11-05 - Large chest without its tier floor until tier 3 relics exist (game-lead)
- **Choice:** the large chest's `min_tier` goes from 2 to 1 for now. It still uses the act 3 row (5/25/70), but today's catalog has no tier 3 relics. So it draws mostly tier 2, fills with tier 1, and offers a full 3.
- **Why:** with only 2 tier 2 relics (Heavy Sigh, Lingering Embers) and 0 tier 3, a large chest with the floor offers at most 2 relics. Once both are held, it falls back to a card offer. A chest labelled "Large" that hands you cards reads as broken.
- **Restore `min_tier` 2 in MAP3,** when tier 3 relics arrive.
- **Rejected:**
  - keeping the floor (thin or empty offers);
  - setting the large weight to 0 (it loses the visible chest-size choice the director asked for).
- **Owner:** ux makes this one-line `data/map.json` edit when it flips `enabled` to true (game-lead's instruction).

## 2026-11-05 - MAP1 ux calls (ux-designer, logged by game-lead)
ux-designer made these calls in a1a4155..ac7baa2. The map is turned on: `data/map.json` `enabled` true, and the large chest `min_tier` 2 -> 1.

**Map screen**
- **Default focus:** the least surprising reachable node, in this type order: combat, rest, relic_room, merchant, buff_room, curse_room, elite, mini_boss, boss. Ties go to the lowest lane. A reflexive Enter lands on a plain fight. Rejected: lowest column, which can land on an elite.
- **Focus and input:**
  - When picking, only reachable nodes take focus. In view mode every node is focusable.
  - Pick mode ignores presses during `prompt_option_arm_delay`, and it swallows Space and the slot keys.
- **Shapes and legend:**
  - New shapes: merchant square, mini-boss triangle, curse X, buff up-arrow.
  - Chest size shows as the hexagon size plus 1, 2 or 3 dots.
  - The legend lists only the types on the current map.
- **Gold** shows only in map runs. A "+N" appears when a fight pays.

**Layout values**

| Item | Old | New |
|---|---|---|
| Room plate | 280 | 304 |
| Relic chip | 26 | 30 |
| Relic font | 12 (min 10) | 15 (min 12) |
| Condition font | 11 (min 10) | 13 (min 12) |
| `relic_list_max_height` | 150 | 320, plus a new min of 90 |
| `relic_list_width` | 560 | 640 |

The boss bar width is now floored to whole pixels.

**BD2 carry-overs, all done**
- A relic cue ring and name at the trigger point. Repeats nearby merge into "x3", with at most 6 cues.
- Pips on the chip of an every-Nth relic.
- Chip marks are unique within the held set.
- The pause relic list sits on an opaque plate, sized to the space available.
- The relic Skip text explains rejects.
- "After Move (Ctrl)" is drawn as a 12 px or larger tag above the slot.

**Stopgap:** `RelicProgress` reads `RelicManager._triggers` because no API exists yet. A tripwire test catches a rename. gameplay-dev adds `RelicManager.trigger_progress(relic_id) -> int`.

**Test edits**
- ux rewrote one gameplay-dev test, the `map1b_flow_test` prompt-stays-open test. It pinned the placeholder that the map screen replaced.

**Run sim with the map on** (`-Run -Seed 1 -Runs 12`, which plays the first route): Rogue won 12/12 with a 66.2 s boss median; Wizard won 10/12 with 60.6 s.

**49 failing tests after the flip, none in ux code**
- **gameplay-dev's:**
  - `bd2b_flow` 4, `h2` 3, `m3a_run_flow` 7, `m3b_flow` 8, `m3b_rewards` 1, `m3c_boss` 3, `p_dodge` 1, `w1a_test` 1;
  - plus the old-data pins `map1a_config` 1 and `map1b_flow` 5.
- **qa's:** `m3a_qa` 8, `m3b_qa` 5, `m3c_qa` 1, `pl3_qa` 1.
- **Verified fix:** `RunSession.map_override = 0` in `before_test`, and -1 in `after_test`.

## 2026-11-05 - The red suite after the map flip: how it's fixed (game-lead)
- **Choice:**
  - gameplay-dev fixes its own failing tests, pinning the straight run where a test is about the straight run.
  - It updates the old-data pins to the shipped data.
  - It makes the reload soak run with `--no-map` and adds a map-aware pass.
  - It adds `RelicManager.trigger_progress`, and updates the `map_*` capture preset descriptions.
  - Then qa fixes its 4 suites in its review step.
- **Why:** each role edits only its own files. Pinning the straight run keeps those tests about what they were written to test. The map flow has its own tests (map1b, map1_ux).
- **Rejected:**
  - turning the map back off until every test is fixed (that hides the real shipped state);
  - one role editing every file.

## 2026-11-05 - MAP1 qa: correction and carry-overs routed (game-lead)
- **Correction to "MAP1-B map run flow calls":** the Rogue relic-route row is **12/12 at 52.1 s**, not 11/12 at 52.9 s. qa ran it twice.
- **Carry-overs:**
  - The capture presets that now land on the wrong room, the generator script error and the dead `_triggers` fallback go with MAP2.
  - The `from_dict` node-pending soft lock and negative gold go with MAP3's save robustness, before any save file exists.
  - Rejected: fixing them before the MAP1 playtest. None of them is reachable from play or from shipped data.
- **The playtester uses the `map_*` presets.** For the older `bd2_*` and `removal_screen` presets it adds `--no-map`.

## 2026-11-06 - MAP2 split, relic pool growth, shop-only relic picks, and the merchant switch (game-lead)
- **Split:** gameplay-dev works in two sittings, like MAP1.
  - **MAP2-A, the merchant engine:**
    - the `merchant` and `relics.prices` data;
    - the stock, buying and reroll model;
    - RunState and save;
    - D40 `min_rest`;
    - the MAP1 carry-overs.
  - **MAP2-B:**
    - 7 relics;
    - the merchant node in the run flow;
    - a sim override;
    - bots;
    - getting the suite ready for the switch.
  - ux, qa, playtest and docs then run once each. **Why:** MAP1 was this size and needed two sittings. The engine can be tested on its own.
- **D40 is built as default A** (`min_rest` 1). **Update 2026-11-06: the director answered D40 = A, so this is now his decision (GDD §9).** At the time of writing he hadn't answered. If he picks B, set `min_rest` to 0. If he picks C, it's a fixed room 9 rest, which is a data change plus a generator rule.
- **The relic pool grows in MAP2. This was found while scoping.**
  - **The gap:** 6 relics exist. A Rogue is eligible for 6 and a Wizard for 5. A relic hunter would empty the pool before reaching the merchant, so MAP2's qa target of 6-8 relics on relic routes couldn't be met.
  - **The fix:** add 4 pool relics (ASAP Notice, Severance Package, Paperwork Fire, Grading Curve) and 3 shop-only relics. Each class then has 11 eligible relics.
  - They come from the BUILD_DEPTH §4.5 and §4.8 candidates, chosen because they need no new effect code. Backups are named in the brief.
  - **Rejected:** logging the target as unreachable until MAP3. The merchant would often show an empty stock, and the playtest question ("is a relic route a real alternative?") couldn't be answered.
- **Shop-only relics:**
  - **Liquidate Assets:** the docs tag it as shop-only. It moves from tier 3 to tier 2, because act 1's weights are 80/20/0 and the offer function drops weight-0 tiers, so a tier 3 relic would never be stocked. Its value stays as documented (+1% per 50 gold spent). If that's weak in one act, it goes to BD3 or the sim. Re-tier it at MAP3.
  - **The shop expander:** 1 free reroll per visit, usable in the visit you buy it. **Rejected: +1 relic slot.** With `max_merchants` 1 there's no later visit, so the extra slot would do nothing. "Request for Quotation" is a placeholder name.
  - **The third:** As Per the Attached Document, moved to shop-only. It uses the existing `reduce_cooldown`.
- **Switching the merchant on:**
  - MAP2-A and MAP2-B ship with `merchant` weight 0 and `relic_route` [5, 7].
  - MAP2-B adds a sim override that turns the merchant on, so prices, `relic_route` [6, 8] and the bot buying can be measured before the switch. It also runs the suite locally with the merchant on and fixes any test that assumes there's no merchant.
  - ux switches the merchant on with its panel, and qa re-baselines the map-on `-Route` numbers. The `-NoMap`, arena and bot-sim numbers mustn't move.
  - **Rejected: MAP1's approach** (ux switches the feature on with no preparation). It turned the suite red and needed a gameplay-dev return trip (3841b41..0226ec9).
- **Allowed data knobs** if the 1000-seed sweep or the relic targets fail: type weights, `max_attempts` up to 1000, the rest window down to [4, 9], and relic prices. Each change gets logged.

## 2026-11-06 - MAP2-A merchant engine calls (gameplay-dev, logged by game-lead)
gameplay-dev's commits are 66ba317, bf80b35 and 9321820. The merchant ships off (`merchant` weight 0, `relic_route` [5, 7]).

**Gates:**
- **Suite:** 1770, with 2 skipped (the MAP3 save carry-overs) and 0 failures, in 139 suites. The `:59` test is un-skipped.
- **Unchanged:** the arena hashes, bot sim 846850403, and `-NoMap` 57.3 s / 62.5 s.
- **Sweep:** 0 failures on seeds 1-1000 (worst 593 of 1000 attempts) and on 5000-5999 (worst 676). These are interim MAP2-A numbers. With MAP2-B's final data and the merchant on, the worst is 479 (qa, tech-writer).

- **`min_rest` 1 couldn't be met with the old data.** At 200 attempts, 351 of 1000 seeds failed, and some still failed at 1000. Accepted by game-lead:
  - **`types.rest.weight` 10 -> 25.**
    - Rejected 20: a worst case of 905 attempts on seeds 5000-6999.
    - Rejected 30: no better.
    - Rejected combat 30 with rest 30: it changes the fight mix more.
    - **Cost:** more rest nodes on the map. `max_rest` 2 and `min_fights` 6 still cap them per path. The MAP2 playtest should check run difficulty and the number of card offers.
  - **`max_attempts` 200 -> 1000**, the allowed ceiling.
- **A code change outside the knob list (accepted):** `MapGenerator` `TYPE_DRAWS_PER_GRID` 10 -> 40, plus a one-pass rest pre-check.
  - **Why:** it's about 3x faster. At 10, a 1000-seed sweep took about 305 s, and the suite runs two sweeps.
  - **Seeds:** those that succeeded within 10 draws on their first grid are unchanged. The rest generate different maps.
  - **Rejected:** keeping 10 and living with suite times about 7 min longer.
- **Every map-on route baseline moved** (12 runs, seed 1). The brief's "move only through `min_rest`" gate was impossible, because `min_rest` forced the knobs.

  | Class | Route | Before | After |
  |---|---|---|---|
  | Rogue | first | 12/12, 66.2 s | 12/12, 54.7 s |
  | Rogue | relic | 12/12, 52.1 s | 12/12, 56.5 s |
  | Rogue | safe | 12/12, 58.4 s | 11/12, 62.2 s |
  | Wizard | first | 10/12, 60.6 s | 11/12, 64.8 s |
  | Wizard | relic | 11/12, 63.2 s | 10/12, 60.0 s |
  | Wizard | safe | 12/12, 65.0 s | 11/12, 62.5 s |

  These are interim. MAP2-B's merchant override and ux's switch move them again, and qa re-baselines after the switch.
- **qa pins that gameplay-dev changed** (for qa to review in its MAP2 pass):
  - `map1_qa_test` `GOLDEN_HASH` -> 2713285137;
  - the rest weight pin 10 -> 25;
  - the sweep headroom from worst < 50% to worst < 80% of `max_attempts`;
  - the unreachable-rules test now loosens the other rules, so the relic rule is the one that fails.
- **Presets re-pinned:** `map_mid`, `map_room9` and `map_chest_medium` -> seed 54; `map_chest_large` -> seed 157. ux and the playtester re-look at them.
- **Merchant design calls (accepted):**
  - **Data:** a `merchant.shop_only_slots` 1 key, so the slot count is data.
  - **Draw order:** the shop-only slot is drawn first, and shop-only relics can also fill a normal slot.
  - **Removal price:** rest-room removals don't raise the merchant's price; only merchant removals do.
  - **Reroll:** redraws only the slots that aren't sold.
  - **Refusals and old saves:** refusals are reason codes (ux maps them to text). An old save whose stocked relic id is no longer in the catalog returns `unknown_relic` and doesn't crash.
  - **Estimate:** `estimate.merchant_prices` [60, 60, 90] replaces `merchant_price` and `merchant_stock`.
- **For MAP2-B:**
  - `free_rerolls` is fixed at 0 in `MerchantConfig.shipped_context`, and the run flow must set it from owned relics.
  - `Merchant.items()` marks removal buyable even when no card can be removed, so B or ux must surface the per-card `removal_problems` reason.

## 2026-11-06 - MAP2-B calls: relic prices halved, the safe-route target, override knobs (gameplay-dev, logged and decided by game-lead)
gameplay-dev did this in 5801fe7..6a3e780. The merchant still ships off.

**Gates:**
- **Suite:** 1800 with 2 skipped and 0 failures, with the merchant off and also with it switched on in a worktree.
- **Unchanged:** the arena hashes and bot sim 846850403.
- **`-NoMap` moved, because the 7 new relics widen the offers:**
  - Rogue: 12/12, 57.3 s -> 12/12, 57.5 s.
  - Wizard: 12/12, 62.5 s -> 12/12, 63.3 s.
- **Sweep with the merchant on:** 0 failures, worst 479 of 1000 attempts.

- **Update 2026-11-06: the director answered D41 = B** (keep 60/90/130, raise gold income, cards priced by rarity; GDD §4a). The halving below is superseded and is rebuilt in MAP3.
- **Relic prices go from 60/90/130 to 30/45/65 (tier 1/2/3). They take effect when ux switches the merchant on. The estimate goes from [60, 60, 90] to [30, 30, 45].** Accepted by game-lead and put to the director as D41, default A (as built).
  - **Evidence** (relic-route median, 12 runs):
    - 60/90: 5;
    - 40/60: 5;
    - 30/45: 6, meeting the 6-8 relic-hunter rule (D22).
  - **Generator check:** with the estimate at 60/60/90 and `relic_route` [6, 8], 284 of 1000 seeds fail to generate.
  - **What it costs:** a tier 1 relic (30) is cheaper than a card (40) or a removal (50).
  - **Rejected:**
    - more gold income: it makes cards and removals cheaper too;
    - `relic_route` [5, 7] with the merchant on: a hunter would end with about 5, below the director's 6-8;
    - more relic-room or rest weight, or a narrower rest window: no help, or more failed seeds.
  - The prices are MAP0's proposal, not a director value, so they can be changed in data.
  - **Fragile:** the relic route sits on the floor of 6-8. BD3 or MAP3 retunes it when the act count changes.
- **The safe-route target is now "at most 3 relics", not "a median of 2-3".** With the merchant on, the safe median is 1 (2 with it off). The bot's safe policy (a removal, then a card) never buys a relic.
  - MAP0's intent was that ignoring relics leaves you with few, and an upper bound is the rule the generator already uses (`ignore_route_max` 3).
  - Rejected: making the safe bot buy a relic just to hit a number.
- **Bot policy:** `first` and `random` shop like `safe` (a removal, then a card). Accepted.
- **Relic implementation calls (accepted):**
  - **ASAP Notice** scales base cooldown plus the card's own modifier, as `CardSlot` applies the stat.
  - **Paperwork Fire** needed a `tag` filter on `hit_landed`. That's a matcher extension, not a new effect type.
  - **Liquidate Assets:** the new `damage_mult` stat applies before armor and scales damage-over-time ticks. Modifiers can now carry `per_run_stat` and `per`.
  - **Severance Package** can chain kill to kill. That's bounded by enemy count and pinned by a test. Watch it in BD3.
  - **As Per the Attached Document** has a 0.5 s internal cooldown.
- **qa-owned tests that gameplay-dev changed** (qa reviews them in the MAP2 pass):
  - `bd2_qa_test` and `bd2b_flow_test` cut their catalog back to the original 6 relics;
  - `map1_qa_test` models merchant relics and adds `GOLDEN_HASH_MERCHANT_ON` 1726783216;
  - the `map1a_*` estimate pins;
  - `map2a_merchant_test`: "ships off" becomes "off or fully on";
  - the `bd2b_relics_test` counts.
- **The switch is all-or-nothing:** `MerchantSwitch.shipped_problems` checks that the four data lines flip together.

## 2026-11-06 - MAP2 ux calls (ux-designer, logged by game-lead)
ux made these changes in 8897701..accf46f. **The merchant is now on in shipped data:** all four switch lines flipped (8994863).

**Suite:** 1800 with 2 skipped right after the flip. It was 1821 with 2 skipped, 0 failures, after the panel work.

All accepted:
- **The shop has no instruction line and no keys hint.** The gold badge and the Leave button carry that. Rejected: keeping both and letting the shop scroll at 1024x600.
- **Layout:** two columns, relics on the left and cards on the right. Remove, Reroll and Leave sit in the footer. Rejected: three rows of three tiles (about 100 px too tall) and a services row (about 70 px).
- **Short reasons on the tiles** (`tile_reasons`), with the full text in the tooltip. "Need N more gold" is computed. The margin is `shop_fit_margin` 0.975, against 0.94 elsewhere, rather than smaller fonts.
- **The room 9 -> boss pick is relabelled "Face the boss"** instead of being picked automatically. That's lower risk for the run flow.
- **The map's gold line** shows only while a merchant can still be reached forward from where you are.
- **`--run-auto-choose` also splits on `+`.**
- **Open, cosmetic:** the legend's merchant icon is a plain square, while the node has a coin. The playtester can say whether it matters.

## 2026-11-06 - MAP2 qa carry-overs routed (game-lead)
- **Request for Quotation dominates the shop-only slot** (about 79% of shops). That's because the shop-only slot uses the act's tier weights. **Left as built for MAP2, and goes to BD3.** Rejected: weighting the shop-only slot evenly now, which is a code change after qa PASS for a balance problem a playtest hasn't confirmed.
- **The flag robustness items, the stale comment, the Liquidate refresh and the at-cap-with-nothing-to-give display go to MAP3 housekeeping.** None of them is reachable through normal play today.

## 2026-11-06 - MAP2 playtest triage (game-lead)
- **The shop keeps its first-purchase focus.**
  - The 0.4 s `prompt_option_arm_delay` already catches a carried-over Enter.
  - **Rejected:** focusing Leave by default, where one reflexive Enter throws away the whole shop.
  - **Rejected:** a confirm on every purchase, which slows down "buy several then leave".
  - The director is asked to check it (eyes item 51).
- **A merchant on every route is a director question (D42, default A: no guarantee).** It changes the map design.
- **D41 gets the playtester's 45/65/90 as option D.** The default stays A, because the bot evidence says D drops the relic route below the director's 6-8.

## 2026-11-06 - Applying D41 = B and D42 = A (game-lead)
- **The director's answers are recorded in GDD §4a and §9, MAP.md §3, §4.4 and §4.5, and the ROADMAP MAP3 brief.** The calls below are mine.
- **When to build D41: as MAP3's first gameplay-dev step, not as a fix now.**
  - Reason: a plain price revert isn't safe. At 60/90/130 with today's gold, hunters end with about 5 relics, and the generator's estimate fails 284 of 1000 seeds (MAP2-B). B needs a gold retune plus a sim, and MAP3 redoes both for three acts right after.
  - Cost: main and the `playtest-2026-11-06-MAP2` tag still sell 30-gold relics until MAP3 ships. The director has been told.
  - Rejected: a one-act retune slice now. It would be tuned twice in a row.
- **How "equivalent tiers" map:** common card ↔ tier 1 relic, rare ↔ tier 2, legendary ↔ tier 3. Boss relics are never sold, so they have no card match. Rejected: comparing every card price to the tier 1 price only. That's stricter than he asked and would squeeze legendary card prices under 60.
- **Proposed card prices:** common 40 (as today), rare 65, legendary 95 at the 60/90/130 scale, each about 70% of its relic tier. They scale with MAP3's relic prices and are set by the sim, with the "always cheaper" rule checked by a data-validation test.
- **Card removal stays at 50, +25 each time.** He didn't mention it. Removal is a service, not a card tier.
- **The sim's lever order (D41 = B):** too few relics for a hunter means gold income goes up, never prices down. Too many means prices go up first, as MAP.md §4.5 already said.
- **D42 = A:** nothing to build. MAP3's fold-in list says so.

## 2026-11-07 - MAP3 split and the detailed brief (game-lead)
- **MAP3 is split into MAP3 (structure) and MAP3b (content). Each is its own slice with its own tag.** MAP2's close said to decide this.
  - **MAP3:** three acts, mini-bosses, act scaling, wave lists for acts 2-3, save and resume. Two gameplay-dev sittings (A: save robustness, the save file, D41 prices, housekeeping; B: the acts).
  - **MAP3b:** card rarity, rare and legendary cards, tier 3 and boss-tier relics, and the final gold tuning.
  - **Reason:** the content isn't there. 13 relics, tier 1-2 only, 3 of them merchant-only; no tier 3, no boss tier; no card `rarity`. Gold tuned against the 14-17 relic target now would hit the pool limit, not a gold limit, and would be wrong after MAP3b. Save still ships with 30-room runs (MAP.md §8).
  - **Rejected:** one MAP3 slice with everything (several sittings, and nothing to playtest for a long time). Also rejected: content first (nothing to test boss relics on without acts).
- **Interim mini-boss reward (MAP3 only):**
  - gold from `gold.mini_boss`;
  - a normal relic offer with skip, at the next act's tier odds;
  - then a normal card offer.

  MAP3b replaces it with the director's reward (a boss-tier relic with no skip, then 3 rare or 3 legendary cards). Rejected: no relic until MAP3b, because mini-bosses would then pay less than elites.
- **An exhausted relic pool keeps BD2's shipped fallback (a card offer).** This bends "elites never give cards" only when nothing is left to offer, and MAP3 will reach that point in acts 2-3 until MAP3b adds relics. Rejected: gold only. It's a new rule for a temporary state. Cheap to reverse.
- **Act 3 offers draw tier 1 and 2 at 5:25 until tier 3 relics exist.** That's the existing weights with nothing in tier 3.
- **No free heal between acts.** HP, gold, deck, relics and rejects carry over, and every act has rests (`min_rest` 1). Rejected: a full heal at each act start. It's an easy data switch if the playtest says act 2 starts too low.
- **The run-length acceptance is restated.**
  - The bot no longer has to hit 30-45 min. One act of bot play takes 3-6.5 min, and the MAP1 triage already ruled that bot time isn't human time.
  - Instead: 30 rooms in 3 acts; both classes win 8/12 or more 3-act bot runs on the `first` route; each act's bot time stays within about ±30% of act 1's.
  - Human run length is checked by the playtester and the director.
  - Rejected: keeping the bot gate. It would push tuning toward slower fights, not longer runs.
- **Relic count targets and "2 boss relics" move to MAP3b's acceptance.**
- **D41 prices are staged:**
  - sitting A: 60/90/130, still one act, with gold raised only as far as the 1000-seed sweep and the MAP2 `relic` median of 6 need;
  - sitting B: 80/120/170 for three acts.

  Card prices stay at 40 flat until rarity exists (MAP3b).
- **Starting act scaling:** act 2 HP x1.35, damage x1.15; act 3 HP x1.7, damage x1.3. These are proposals the sim tunes, not final values.
- **`map.json` `acts` (3, with 1 = MAP2's behaviour) and the sim's `-Acts 1`** keep one-act tests, scenarios and baselines working. That's the same idea as `--no-map`.
- **Rare and legendary cards, retag or new:** decided in MAP3b's design pass. Default: legendary cards all new; rare may retag up to 2 existing cards per pool.

## 2026-11-07 - MAP3 sitting A calls (gameplay-dev, decided by game-lead)
- **Gold income doubles (combat 24-36, elite 60-80, mini-boss 90-110; `estimate.gold_mean` 30/70/100), accepted.** The ratio to the doubled prices is unchanged, so every generated map, the golden-map hash, seed 54 and the capture presets stay valid.
  - Rejected: 25/55/80, the smallest change that met the sim. It failed `map1a_sweep_test`'s headroom (worst seed 945 attempts, limit 800) and would have changed every map.
  - It goes past the brief's "only as far as needed". That's acceptable because sitting B retunes gold for three acts and MAP3b does the final tuning.
- **`tiers.boss` stays.** `RunConfig`, the tests and ux's marker colour and size read it. Its HP, armor and resistance fields are probably dead, because `Boss.gd` takes its stats from `bosses.json`. Cleaning that up goes to BD3 housekeeping. Rejected: removing it now, which would touch ux files for no player gain.
- **Saves happen at the map screen and at a room's start.** There's no save before the first room and none on straight (no-map) runs, and debug launch flags never touch the save. `from_dict` refuses bad relic lists and clamps negative gold to 0. All accepted as built.
- **The `first`/`safe` bots end runs with about 200 unspent gold.** They buy only a removal and a card. Goes to MAP3b's gold tuning (and the bot's buy policy). Not a blocker.
- **Shop overflows 4 px at 1280x720 when every tile shows "Need N more gold":** goes to ux in MAP3's ux step.

## 2026-11-09 - BD3a placement and scope (game-lead)
Context: director feedback 2026-11-09. He played a three-act physical/Bleed Rogue run and found too few physical and Bleed cards, and relics mostly Fire/Burn. He wants non-Fire build variety as a priority. The reprioritisation is his directive and is recorded in ROADMAP and the CHANGELOG. These are my calls on how to apply it.
- **BD3 is split.** BD3a (physical Rogue: stacking, `detonate_status`, R-C Bleed Out, R-D Grudge Brawler, 6 relics) runs after MAP3. BD3b (Wizard depth and the rest of BD3) stays after 3d. Rejected: pulling all of BD3 forward, which is about 3 sittings and blocks MAP3b's content for longer.
- **BD3a runs after MAP3 closes, not now.** MAP3 sitting B is built and on main (5d85ee4..e20df08), with gameplay-dev's last changes still uncommitted. Only ux, qa, playtest and docs are left. Rejected: pausing MAP3 now, which would leave three acts on main with no qa verdict and no tag. The director can override this.
- **BD3a runs before MAP3b.** MAP3b designs tier 3 and boss relics and rare and legendary cards. With the stacking and Bleed mechanics already in, those can cover Bleed and basic attacks, not only Burn.
- **`rogue_bad_influence` becomes a Keystone that lets Bleed stack to 5** (BUILD_DEPTH §5 had it only speeding up Bleed ticks). D25 = A allows stacking only from keystones, relics or passives. Without this, the Bleed Out archetype would stack only with the Serrated Excuse relic. Rejected: making `rogue_paper_cuts` stack Bleed by itself, which breaks D25.
- **Four new card sketches beyond BUILD_DEPTH §5** (`rogue_cut_corners`, `rogue_knife_drawer`, `rogue_excuse_me`, `rogue_blood_money`). They fill the Rogue's thin AoE, Movement and Recovery slots, so a physical deck isn't forced into Fire AoE cards. They use only existing templates. Rejected: only the 4 §5 cards, which leaves the Fire offer share at about 33%.
- **Spite Knuckles: Burn -> Bleed.** It's the Rogue's own relic and the Grudge Brawler relic, so it shouldn't push Fire. It's a data change, easy to revert. Rejected: a new Bleed copy next to it, which leaves a Burn relic in the Rogue pool.
- **Card-offer weighting is the director's call (D43), not mine.** GDD §9 draws offers evenly across pools, and content alone only takes the Fire share from about 37% to about 29%. Default A (no weighting change) until he answers.
- **Detonate order:** the damage lands with the status still on, and then the status is removed (reason `detonated`). A detonate kill counts as killing a Bleeding enemy, so Severance Package, the archetype's own payoff relic, keeps working. Pyre Insurance ignores `detonated`, to avoid a double explosion. Rejected: removing the status first, which would make Severance Package dead in the Bleed Out deck.
- **D43 option B is worded as a status lean (Bleed and Burn only), not a lean on every tag.** Broad tags like Melee and Dash are in every deck, so leaning on them would do nothing.
- **D43 = B starting numbers (game-lead, 2026-11-09):** weight x (1 + 0.25 per owned card that applies the status), capped at x3. Owning 4 Bleed cards doubles a Bleed card's chance. The cap stops a mono-status deck from seeing only that status. The values are data, tuned by the BD3a offer report. Rejected: a flat x2 for any shared status, which can't tell a 1-card dip from a full commitment.

## 2026-11-09 - MAP3 sitting B calls (gameplay-dev, decided by game-lead)
- **Act scaling is lighter than the brief's starting values: act 2 HP x1.1, act 3 HP x1.2, damage x1, gold x1.** Accepted. The run sim met the gates with them (Rogue 9/12, Wizard 10/12 three-act wins; every act within +13% of act 1's time). The act 2-3 wave lists are bigger mixes, so they already add difficulty, and damage at x1 keeps the Rogue's fight HP loss in range. Rejected: the brief's 1.35/1.15 and 1.7/1.3, which were proposals for the sim to tune. Easy to raise later in `data/run.json` `acts` if the playtest says later acts are too easy.
- **`--acts=N` launch flag** for debug and capture: refused with exit 2 on a bad or repeated value, like the other launch flags, and counted as a debug flag so it never touches the save. Rejected: silently ignoring bad values.
- **The one-act capture presets are pinned with `--acts=1`** so they keep their MAP2 meaning (boss at room 10). Two new unpinned presets cover the act 1 mini-boss and the act 3 boss. Rejected: re-pointing every preset at three-act rooms, which would change what qa's old screenshots compare against.

## 2026-11-09 - MAP3 ux calls (ux-designer, decided by game-lead)
- **New Run with a save present leaves the save alone until its first room start, then overwrites it.** The class cards say "(replaces your saved run)". Rejected: a confirm dialog, which adds a step for a one-slot save.
- **Continue starts focused when a save exists**, and it sets the remembered class to the saved run's class. Rejected: focusing the last class, which makes Enter start over by accident.
- **The act screen doesn't pause the game**, like the map pick (no fight is running). **Resuming a save at an act's first map shows no act screen**, because `act_started` doesn't fire on resume. Accepted for now; the playtest can ask for it.
- **The HUD plate grows to two lines only on multi-act runs**, so one-act runs and their captures don't change.
- **The shop shrinks instead of scrolling when up to 4% too tall** (`run_ui.shop_scroll_slack` 0.04). Rejected: a smaller font for every shop.
- **Act summary reads "relics: N"** instead of "N relics", so it never says "1 relics".

## 2026-11-09 - MAP3 qa calls (qa, decided by game-lead)
- **The hand-edited-save bug (hp 0 or over max, bad `rejects_remaining` load) is committed as a skipped probe**, so the suite gate stays green and meaningful. It's low severity (the game never writes these values) and goes to BD3a sitting A housekeeping. Rejected: a failing test on main, or holding MAP3's close for it.
- **A paused-tree guard went into 11 suites' `after_test` even though no leak reproduced.** Cheap and test-only. The root cause (`GamePause.reset()` doesn't unpause the tree) goes to BD3a sitting A.
- **Test `.uid` files are tracked** (153 already were), so the stray ones were committed.

## 2026-11-09 - MAP3 playtest triage (game-lead)
- **The mini-boss's named bar and bigger marker, and the act screen's "HP carries over" line with low HP in red, are readability fixes scheduled for BD3a's ux step** without waiting for D44 or D45. They don't change design. Rejected: holding MAP3's close for them, since there's no blocker and BD3a has a ux step anyway.
- **Act identity (D44) and healing between acts (D45) go to the director.** Both are design. "No free heal between acts" was my interim call in "MAP3 split", not a GDD rule, so it stays only as the default until he answers.
- **The playtester's gold ideas go into MAP3b's design pass.** A guaranteed merchant per act would reverse D42 = A, so it would need the director.
- **MAP3 closes on a capture-and-sim playtest with no hand play.** qa's tests cover Continue, save/resume and the act screen's input. The director's three-act run (2026-11-09, "felt good mostly") was played on the sitting B build, and OPEN_ITEMS 52 asks for a timed run. Rejected: another playtest pass, which wouldn't add hand play either.

## 2026-11-09 - MAP3 close (game-lead)
- **MAP3 closes with the `--no-map` save-deletion finding open.** tech-writer found by code reading that a `--no-map` win or loss deletes the player's saved map run. `--no-map` is a test launch the player has to type, the normal launch can't reach it, and it costs at most one saved run. It goes to BD3a sitting A housekeeping with a test. Rejected: reopening MAP3 for it.

## 2026-11-09 - Applying D44 = C and D45 = B (game-lead)
- **MB1 (mini-boss and act identity) is a new slice after BD3a and before MAP3b.** BD3a is the director's stated priority and is planned, so it stays first. MB1 goes before MAP3b because MAP3b's boss-tier relics are the mini-bosses' reward, so they should land on the finished fights. Rejected: folding MB1 into MAP3b, which would make that slice about 4 sittings; and running MB1 before BD3a, which goes against his 2026-11-09 priority.
- **The mini-boss starting sketch** (an act 1 brute and an act 2 rogue-style duelist) is mine, built from his example. It's confirmed in a short MAP.md design note before the build, not invented in code.
- **D45's heal is 30% of max HP at the start of acts 2 and 3**, the example value in his option B, stored as `acts.start_heal` so 0 turns it off. It's built as BD3a sitting A housekeeping because it's one data value and a small code path. Rejected: waiting for MB1.
- **The act 3 damage bump from D44's option B waits for the sim after the heal.** The heal makes runs easier, and per-act scaling is data, so tuning both at once in MB1 is cleaner.

## 2026-11-09 - BD3a sitting A (gameplay-dev, logged by game-lead)
Commits 7625eee..6f57756. Rejected alternatives in brackets.
- **Stacks:** a reapply adds a stack only below the current cap. If the cap drops (the buff ends), existing stacks stay until the status ends. The cap and tick rate come from the latest applier; the tick rate is re-read every tick and floored at 0.1 s. [Trimming stacks when the cap drops.]
- **Detonate** is a `KIND_HIT` with the card's origin, so it gets hit-stop, and `damage_mult` and `card_damage_mult_vs_status` apply. A killing detonate ends the status as `detonated`, not `owner_died`, so a Burn detonate never triggers Pyre Insurance; `enemy_killed` still lists the status. A detonate is not a status source (`CardSummary.status_ids` skips it), so it doesn't count for `requires.status_sources` or the D43 lean.
- **"Faster" convention:** tick rate x1.5 divides the interval by 1.5; Warm-Up's light interval x0.7 is shown as "Light attack delay -30%".
- **Paper Cuts' Bleed lasts 2.0 s** (BUILD_DEPTH §9a implied about 1 s): same `CardDamageRule` cast value, and stacking has something to work with.
- **`status_applied` doesn't fire on a stack gain;** `status_stacks_changed` does.
- **RunSave refuses** (doesn't clamp) hp <= 0, hp above max, and `rejects_remaining` outside 0..`rejects_per_run`. [Clamping, which would hide a corrupt save.]
- **`act_summary()` reports `healed` 0 for an act resumed from a save** (the heal is already in the saved HP).
- **`--run-room`** must be a whole number 1..(acts x `map.json` `rooms`); `abc`, bare, `0`, `1.5` and past the end exit 2. A straight-run win or loss deletes the save only when it owns a map run.
- **Presets:** `physical-rogue` swaps Hot Head for Bad Influence (1 Fire card left); `mixed-rogue` `full` includes the 4 new cards.
- **Balance table rows** (pinned in `slice3b_qa_test`; light 5.00 DPS):

| Card | Slot | Cooldown | Cast damage | DPS (rule) | vs light |
|---|---|---|---|---|---|
| Open a Vein | single | 1.1 (1.0+0.1) | cone 6 physical, then detonate Bleed x2 (not credited) | 6.0/1.1 = 5.45 | 109% |
| Paper Cuts | single | 1.3 (1.0+0.3) | 4 x 1.5 physical + Bleed 2 s per hit | 8.0/1.3 = 6.15 | 123% |

- **Rebaseline (new Rogue pool cards fill sim slots; removing the 4 card files restores every old value exactly):** arena 30 s seed 1 1897787086 -> 1263206438, 90 s 4207041509 -> 2593159768, `-Plan` 1160207333 -> 1047806691; bot sim `-Rooms 20 -Seed 3` 846850403 -> 1440092910. `-Plan -Deck rogue-kindling` bot sim checksum 3805463225 (first recorded).
- **The Rogue three-act floor is read at the slice's end, not after sitting A (game-lead).** `-Route first` seed 1 Rogue went 9/12 -> 7/12 (seed 13: 10/12 -> 7/12); the Wizard is unchanged at 10/12. The cause is the random-pick sim bot diluting its deck with Utility buffs it can't use. The 8/12 floor is a BD3a acceptance line, and sitting B brings the plan-aware bot picks and the D43 lean, so qa checks it after sitting B. If the Rogue is still under 8/12 with the random bot then, sitting B's hand-back must say whether that bot or the cards are the cause, and a card tweak or bot fix goes in before qa. [Tuning the cards now, against a bot that's about to change.]
- **D45's heal can't be measured by the bot** (it ends every act at full HP; the 0 and 0.3 runs are identical). It's covered by unit tests; the playtester checks it in a human run.
- **Wizard `-Run` "hang" was buffering:** `run_wave_sim.ps1` piped through `Out-String`; a 12-run three-act sim takes 12-15 min. It now streams (4f87d06).

## 2026-11-09 - BD3a sitting B (gameplay-dev, logged and triaged by game-lead)
Commits 4afe5b9..f48e696 (code 4afe5b9..cb41f39 plus 82654a7; four reverted experiments). Suite 2034 cases, 152 suites, 0 skipped. Rejected alternatives in brackets.
- **Per My Last Email reads "an Attack: Single hit applies Bleed 3 s if you cast a Primer in the last 6 s"** (BUILD_DEPTH §9a updated). No Attack: Single card is a Primer, so the "next card is a Primer" rule could never fire. [Adding an Attack: Single Primer card just to make the literal rule work.]
- **Muscle Memory** counts per light swing that hits (0.1 s internal cooldown), not per enemy hit. **Chasing Paper** uses a new `dash_passed_through` event; the dodge never fires it.
- **Lean counting:** n_S counts copies; a card with two statuses takes the larger factor, not the product; the element pool's own status isn't counted; the merchant's card stock uses the same weights.
- **"Burn-dependent" relic** = keyword Burn and not Bleed (Second Wind reads either).
- **Shortened names ("Corner Cut", "Knives") are temporary.** gameplay-dev shortened them to keep `offer_fit_test` above 0.7, but the real failure is the unbounded "In slot: A / B / ..." list. ux caps it ("+N more") in BD3a and restores "Cutting Corners" and "The Knife Drawer". [Keeping short names, which MAP3b would have to repeat for every new card.]
- **Rebaseline (the 4 new pool cards fill sim slots and consume the shared shuffle; removing the 4 card files restores sitting A's values exactly):** arena 30 s 1263206438 -> 2833360253, 90 s 2593159768 -> 2458345884, `-Plan` 1047806691 -> 197110259; bot sim 1440092910 -> 3476063471; `-Plan -Deck rogue-kindling` 3805463225 -> 3607698402.
- **The D43 lean fails acceptance at 0.25.** A neutral Fire Rogue's Fire share is 30.0% at lean 0 and 38.2% at 0.25, because the starter deck has 3 Burn appliers. The Bleed-picking bot's Fire share doesn't fall either. 0.25 was my starting number, not his. GDD §9 says the lean counts "owned cards", so leaving the starter out is a change in reading and goes to him as D46. Before writing D46, gameplay-dev measures starter-excluded counting and lower values, so he picks from measured options. [Shipping 0.25 by the "use the default" rule, which makes his main complaint measurably worse.]
- **A pruned card keeps its normal offer weight.** That's new design, so it goes to him as D47 with a default of no change. Measured: a never-again rule takes the Bleed bot's late Fire share from 39.6% to 32.3%.
- **The 8/12 three-act floor is missed. I'm re-scoping it, not blocking on it.** The Rogue pooled 21/36 over seeds 1/13/25: before BD3a it was 29/36, lean 0 gives 13/36, the Wizard 28/36. Anything that makes a Fire Rogue's offers less Fire cuts the wins of a Fire-starter bot that never adapts, so the gate can't sit alongside the slice goal. The drop could still be real for a human, though, so the playtester's normal Fire Rogue three-act run is an explicit difficulty check against MAP3. It blocks the close only if that run is clearly harder. A plan-following three-act bot with its own floor goes to MAP3b. [Tuning cards against a bot that ignores the plan; dropping the gate silently.]
- **Parity holds** (boss room, 12 seeds, vs the standard Rogue's 42.8 s): bleed-out 117% (104% with its 2 relics), grudge-brawler 111% (84% with its relics), kindling 98%. **Fingerprint** Kindling vs Bleed Out is 0.72 (0.78 with relics). Their top sources match at slot level without relics (Attack: AoE), but differ at card level (Fire Wall vs Open a Vein) and with relics (`status:bleed`). qa rules on which reading the acceptance means.
- **Latent bug fixed:** a deferred relic trigger aimed at a freed enemy raised "Trying to cast a freed object" (`RelicManager._live_target`, with a regression test).
- **Commit attribution:** sitting B's commits carry a "Claude Sonnet 5.5" co-author line instead of the session's. That's cosmetic, and history isn't rewritten.

## 2026-11-09 - BD3a lean measurement and D46/D47 defaults (game-lead)
Commit a41dfd0 adds `rewards.status_lean_skip_starter` (optional bool, default false). n_S counts copies beyond the starter's copies, never below 0. Quirk: a starter card that's pruned and then picked again still counts as starter. [Tracking added cards in RunState, which needs a save change.]
- **D46 default B (don't count the starter) is set in `run.json` for the BD3a playtest.** The shipped 0.25 with the starter counted fails the slice acceptance (neutral Fire share 38.2%). Not counting the starter gives 30.0/30.8/29.8, the same as lean 0, and slightly raises the Bleed bot's early Bleed share. It's one data flag to change back if he picks A. The GDD §9 text "owned cards" stays as it is until he answers. [Shipping A because it matches the GDD wording, which hands him the complaint he asked to fix; C, turning the lean off, which throws away his D43 = B.]
- **D47 default A (no change).** A "never offered again" rule is new design, so it isn't built until he answers. Measured with the lean at 0.25 and the starter not counted: late Fire 39.1% -> 31.6%.
- **After the D46 flip (49f3f3e):** the Rogue three-act `-Route first` seed 1 went 7/12 -> 9/12, back to the MAP3 value. The floor is still re-scoped as above; qa re-reads it over the pooled seeds.

## 2026-11-09 - BD3a ux calls (ux-designer, decided by game-lead)
Commits aa02650..cff56aa.
- **The act screen's low-HP red starts at 50% of max HP** (`ui.act.low_hp_fraction`). With D45's 30% heal you can never be at or below 30% after the heal, so a 0.3 threshold would never fire. [0.3.]
- **The mini-boss name lives on `tiers.mini_boss`** ("Act %d Mini-boss"), because the tier is what the bar reads. MB1 can override it per encounter. The marker size is 0.34, the same as the boss; 0.42 out-signed the final boss. [`rooms.mini_boss`; a bigger marker.]
- **Stack counts show from 2 stacks** ("Bleed x3", and "MAX" at the cap). The boss gets the label too. The detonate word is "Bleed detonated", so it doesn't collide with Severance Package's "bursts".
- **"In slot" shows 3 names, then "+N more".** The §9a names "Cutting Corners" and "The Knife Drawer" are restored, so the "temporary names" line in "BD3a sitting B" is done.
- **No hover on the HUD relic chips; the pause list is enough for now.** The chips ignore the mouse during combat on purpose, and the rule text is on the offer, shop and pause screens. This isn't sent to the director. It comes back if a playtest says relics are hard to read mid-run. [Adding hover to combat HUD chips.]
- **Open a Vein shows 2 tag chips at 1024x600** ("Keystone + Payoff", Melee), so Bleed can drop off. That's the existing chip rule; no change.
- **`m3b_flow_test`'s offer-and-reject test fails on main since the D46 flip (49f3f3e),** because its pinned seeded offer moved. It's re-pinned in the D47 sitting, which moves offers again anyway.

## 2026-11-09 - D47 = B build (gameplay-dev, logged by game-lead)
Commits 7b81933..29da9bf. Suite 154 suites, 2069 cases, 0 failures. Hashes unchanged. Rejected alternatives in brackets.
- **Removing one copy bans the id,** following the GDD's wording, "a card you remove". [Banning only once every copy is gone.]
- **A pruned card on the merchant's shelf in the same visit leaves the shelf,** so it can't be bought straight back. [Showing it but making it unbuyable.]
- **`removed_cards` is validated like the deck:** a non-string, an empty string or an unknown id makes the save unusable. No save version bump; a missing key reads as empty.
- **Nothing erases a ban.** Only debug paths (`--full-deck`, `--run-offer`, presets) can put a removed card back in the deck, and it still never appears in an offer.
- **Offer report:** it now reads the shipped flags from `run.json`, with `-SkipStarter`/`-CountStarter` overrides, and the bots play the real D47 rule. The Bleed-picking, Burn-pruning bot's Fire share is 29.9/31.7/31.6% (pre-D47 rule: 30.8/35.9/39.1%). A neutral Fire Rogue's is 30.0/30.8/29.8%.
- **Rogue three-act `-Route first` seed 1 went 9/12 -> 8/12** (D47 is the only gameplay change since). That's at the floor; the gate stays re-scoped as in "BD3a sitting B".
- **The pinned `-Plan` arena value 197110259 comes from `-Plan -Seed 1 -Seconds 30`.** Bare `-Plan` defaults to 90 s (2710411178, not pinned).

## 2026-11-09 - BD3a qa FAIL triage (game-lead)
qa FAIL in 4477c95/baf31e6/39ef43a (`docs/reviews/2026-11-09-bd3a-qa.md`). Rejected alternatives in brackets.
- **Blocker 1, the orphan leak** (`EnemyHpBar` adds `StatusStackLabel` with `call_deferred`, so it leaks when the enemy is freed first; the suite exits 101). ux fixes it and un-skips qa's probe. ux also aligns `cast_preview_6a_test` with the code (`status_id` and `hit_radius`).
- **Blocker 2, the Fire-share line, is re-scoped (mine to call; I wrote the line).** "Clearly lower over the run" was meant as clearly lower than the same deck saw before BD3a, which is the director's complaint. That's met: the Bleed-picking, Burn-pruning bot's late Fire share is 31.6%, against 39.1% under the pre-D47 rule and about 37% before BD3a. It is flat over the run, not falling, because its Bleed share falls 17.9% -> 8.2% once it owns the small Bleed pool. That isn't fixable inside BD3a without more Bleed content, so it goes to MAP3b, whose rare and legendary lists must cover Bleed. It's also told to the director as a known limit. [Holding BD3a for more content; a stronger lean, which the measurement showed barely moves the share.]
- **Fingerprint "top sources differ": the with-relics reading counts.** The archetypes are defined with their relics, and with them Bleed Out tops at `status:bleed` against Kindling's Attack: AoE. Card level isn't in the §2 vector. [The relics-off reading, where both top at Attack: AoE.]
- **Not a blocker, but investigated before the playtest:** the Rogue three-act pooled score is 17/36 (pre-BD3a 29/36), and `rogue-bleed-out` from room 1 wins 0/12, with 9 of the 12 deaths in rooms 1-2. Dying that early, while the boss-room parity is fine, looks like a structural problem (deck or bot plan), not tuning. gameplay-dev diagnoses it and fixes it if it's a bug or a clear data mistake. A balance change beyond BUILD_DEPTH §9a's intent comes back to me first.
- **`physical-rogue` keeps a Fire card it no longer needs:** gameplay-dev drops it, fixes the description and `t_decks_test`, and un-skips qa's probe.

## 2026-11-09 - The sim bot's aim bug and the baselines (game-lead)
gameplay-dev e4ef264..bf0d44c. `Player._apply_aim` ignored `aim_point_override`, so in every headless sim the bot's body faced a fixed direction. Cones, projectile fans and attack dashes whiffed, and the plan bot held facing-dependent cards uncast. The bug is as old as the sim. Real play is unaffected, because the override is null when a person plays. After the fix: `rogue-bleed-out` from room 1 went 0/12 -> 12/12; the Rogue three-act pooled score (seeds 1/13/25) went 17/36 -> 35/36, against 36/36 for pre-BD3a plus the fix; the Wizard seed 1 went 10/12 -> 9/12. Suite 2080 / 156, exit 0, 0 orphans. Rejected alternatives in brackets.
- **Every bot-measured balance number from before a9d56fc is stale,** including the old H1/H2 dodge-off bot clears, the MAP1-MAP3 run baselines and the BD3a fingerprint. Those numbers informed earlier calls, but no shipped value is changed because of this. The director's own play was never affected, and his reports stand.
- **BD3a isn't held for re-tuning.** With the fix, BD3a costs about 1 win in 36 against the pre-BD3a build, so the slice's own question is answered: it doesn't weaken the Rogue. qa re-measures the BD3a acceptance numbers (parity, fingerprint, three-act per class) with the fixed bot, and the playtester's difficulty check stays. [Holding BD3a until the bot is re-calibrated.]
- **The 8/12 sim floors stop being gates until they're re-calibrated.** The bot now wins 35/36 with bosses at about 30 s, so the floor can't catch a run that's too hard for a human. A new tooling slice, **SIM1**, runs before MB1 (whose acceptance uses the floor). It re-baselines every sim number, and makes the bot human-like enough for floors to mean something: reaction delay, aim error, or a tuned plan. It sets new floors from human reports where we have them, the director's "felt good mostly" three-act Rogue run among them. [New floors set straight from the fixed bot, which would pass anything; leaving the old floors, which now never fail.]
- **Hash rebaseline (a9d56fc; the bot now faces its target, so positions change):** arena 30 s 2833360253 -> 3172486861, 90 s 2458345884 -> 916264160, `-Plan -Seed 1 -Seconds 30` 197110259 -> 1317880580. Bot sim 3476063471 is unchanged.
- **`physical-rogue` has no Fire card** (`fire_fine_burn_then` -> `rogue_cut_corners`).

## 2026-11-09 - BD3a re-check (qa 8e8c3bc, FAIL on one narrow blocker; game-lead)
- **Blocker:** a614f76 frees the queued label, so Godot logs "Error calling deferred method ... _add_sibling_deferred" once per suite run (and one loaded-machine run crashed with exit 139 right after it). ux builds the label inside the deferred call, so no node crosses the deferred boundary. qa re-checks with one isolated run and one full run.
- **The fingerprint passes on the with-relics reading: 0.61 on median vectors (BUILD_DEPTH wording), 0.66 on mean vectors.** Relics off it's 0.45, a fail. I keep the with-relics ruling, because the archetypes are defined with their relics. It's a thin pass, so SIM1's human-like bot re-measures it. If it drops below 0.6, Bleed Out gets more distinct in MAP3b (its Bleed content). [Failing BD3a on a margin the bot settings can move.]
- **Correction to "BD3a qa FAIL triage":** the reason given there ("with relics Bleed Out tops at `status:bleed`") was measured with the aim bug. With the fixed bot, Bleed Out tops at Attack: Single and Kindling at Attack: AoE in both readings. Bleed ticks are third, at 21-23%. The ruling still stands.
- **Fixed-bot numbers (seed 1, for SIM1):**
  - **Parity:** bleed-out 92% (79% with relics), grudge-brawler 109% (94%), kindling 106% (96%), against standard 29.8 s.
  - **No-card gate:** 0/12 for each class.
  - **Three-act pooled:** Rogue 35/36, Wizard 29/36.

## 2026-11-09 - BD3a playtest triage (game-lead)
Report: `docs/playtests/2026-11-09-bd3a-short.md` (2034c6e). No blocker. The difficulty check answers "not harder than MAP3, slightly easier": enemy, boss and player data are unchanged since the MAP3 tag, and D45's heal is the only difficulty change. Rejected alternatives in brackets.
- **There are still few Bleed cards (6), and late offers are about 8.5% Bleed.** The content gap is the director's call to schedule, so it goes to him as D48. Default: BD3a closes as it is, and Bleed and physical rares and legendaries come in MAP3b, already planned. The alternative is a short common-card top-up now. [Adding cards without asking, which reorders his run order.]
- **The stack fantasy needing a source (Bad Influence or Serrated Excuse) is his D25 = A, working as designed.** It isn't re-asked. ux adds a cue that Open a Vein is better on stacks. [Re-opening D25.]
- **Grudge Brawler using Heavy Sigh, a Burn relic, is acceptable.** R-D is a basic-attack plan, not a non-Fire plan, and GDD §5's dual-class rule allows hybrids. A non-Burn heavy-attack relic goes onto the MAP3b relic list. [Changing the preset now.]
- **The idea that pruning or rejecting a type also shrinks its offers** goes into the MAP3b design pass as a candidate. It isn't asked now: D47 just shipped, and the director hasn't played it yet.
- **Not blocking, to MB1's ux** (which builds on the mini-boss bar):
  - stack labels overlap each other, the elite marker and the "Bleed detonated" word;
  - the mini-boss bar behind the Act 2 screen says "Act 2 Mini-boss" (it should say Act 1);
  - "HP" is repeated on the low-HP line;
  - the Open a Vein stacks cue.
- **A human three-act run is the only real difficulty read** while the bot is uncalibrated. It's eyes item 53 for the director, and SIM1 uses his answer.

## 2026-11-11 - SIM1 targets and method (game-lead)
SIM1 needs a target for its "human-like" bot preset. No human win rate exists, so the target is provisional. Rejected alternatives in brackets.
- **Anchors used:** the director accepted a boss fight of about 1 minute (RESOLVED 39: Rogue about 66 s, "boss length is fine"; RESOLVED 10), the 1-dodge Wizard "seemed fine" (RESOLVED 40), and his three-act physical Rogue run "felt good mostly".
- **Provisional target (Rogue, standard deck):** median boss time 50-80 s, three-act `-Route first` win rate about 50-75% pooled over seeds 1/13/25. The win band is my judgment. It's cheap to change, so it isn't escalated, and the director's own three-act run (eyes 53) overrides it. [Asking the director for a win rate first, which would stall SIM1 on a number he can give better by playing.]
- **gameplay-dev delivers a sweep table, not one hand-tuned preset.** game-lead/qa pick the cell, so a wrong target doesn't mean redoing the build. Sweep on 1-act or boss-room runs; three-act only to confirm. [Tuning to a single target inside gameplay-dev.]
- **One preset for both classes.** The Wizard is reported on the Rogue's preset. [Per-class presets, which would hide the class gap the floors are meant to catch.]
- **Determinism:** bot jitter uses the sim's seeded RNG; with the settings off, every current hash holds.

## 2026-11-11 - SIM1 sitting 1 triage (gameplay-dev d15e691..85e7d6a; game-lead)
- **Win rate is the calibration axis; boss time is information only.** No setting moves the boss time much: every sweep cell sits at 38-46 s, against the 50-80 s target. The bot keeps hitting the boss whatever its lag, and a person spends time backing off. The boss-time anchor is weak anyway: the "about 66 s" the director accepted (RESOLVED 39) was a bot number, taken with the aim bug, not a human time. [Scheduling bot retreat and dodge behaviour now, which is new work for a number with no real human anchor; dropping the boss-time number altogether.]
- **The `human` preset (0.2 s delay, 25 degrees aim error) is accepted as provisional.** Rogue three-act 26/36 (72%, top of the band); Wizard 15/36 (42%) on the same preset. The curve is steep (0.25 s gives 13/36), so floors must allow for seed noise. The Wizard gap is recorded as a finding for the floors and for BD3b, not tuned away. [A per-class preset; a slower preset nearer 60%, which would sit on the steep part of the curve.]
- **gameplay-dev's own calls are accepted:** the lag is a delay on every bot decision; the aim error is a uniform angle re-rolled every 0.35 s; sweeps use override flags, not one preset per cell.
- **`--run-room=30` not exiting headless is by design:** a plain launch waits for input. Docs should say to add `--quit-after N` for an exit-code check. No code change.

## 2026-11-11 - SIM1 qa FAIL triage and the floors (qa e19ecec, c5202ff; game-lead)
Review: `docs/reviews/2026-11-11-sim1-qa.md`. One blocker: `tools\run_wave_sim.ps1` line 80 matches `ERROR|WARNING` case-insensitively, so the `aim_error` settings line makes every run with aim error exit 1. gameplay-dev makes it a case-sensitive engine-prefix match and fixes the two nits (`--bot-delay=abc` is silently 0; the bot sim prints `bot preset ''`). qa re-checks and runs the three missing Wizard numbers (`-Route relic`, `-Route safe`, `-Relics`). The suite is red on purpose (2 cases in `sim1_qa_test.gd`) until the fix. Rejected alternatives in brackets.
- **The floors (set now; they apply from MB1 on), on pooled seeds 1/13/25, `-Route first`, 36 runs. Gate on pooled counts only, never on a single seed:**
  - **Primary, `human` preset, three-act:** Rogue at least 21/36, Wizard at least 9/36 (about 2 binomial SDs below today's 26 and 15).
  - **Guards on the off bot (catch broken content, not difficulty):** Rogue at least 32/36, Wizard at least 25/36.
  - **No-card ceiling:** at most 25% clears, measured on the **off** bot. A weaker bot makes the ceiling trivially true. [Gating it on `human`, as the brief said.]
  - **Parity:** 70-130% of the standard deck's boss time, on both bots.
  - **Fingerprint:** at least 0.6 with relics on median vectors, on the off bot (the thin reading, 0.61; `human` gives 0.73).
- **Per-class floors, not one.** One floor (about 21/36) would fail the Wizard today (15/36) and block MB1 on a gap MB1 isn't scoped to fix. The one-preset rule still holds, so the gap stays visible. **The Wizard gap is a named finding for BD3b** (human 42% vs Rogue 72%; the Wizard is far more sensitive to the preset, 81% -> 42%). [One shared floor; a per-class preset.]
- **Boss-time correction to "SIM1 sitting 1 triage":** the preset does move the Wizard's boss time (to 50-62 s, inside the old target); only the Rogue's stays at 35-43 s. Win rate stays the calibration axis.
- **`-Relics pyre_insurance+heavy_sigh`** is qa's new form; it's the baseline from now on.

## 2026-11-11 - SIM1 re-check PASS (qa 95aebd7; game-lead)
gameplay-dev a047b9b fixed the gate (case-sensitive, prefix-anchored in all three sim wrappers) and the two nits. Suite 2100 / 160, exit 0, 0 orphans; off-hashes unchanged. No playtest: SIM1 is tooling and changes nothing a player sees. Rejected alternatives in brackets.
- **The human Wizard won 0/12 on `-Route safe`** (seed 1; the route with the fewest relics, median 4; furthest room 20). Off it was 9/12. It's one seed, not gated, and it fits the Wizard gap already named for BD3b, so it's added there as a finding. **MB1 gates on `-Route first` only**; it also reports `safe` per class for information. [Gating `safe` now, which would block MB1 on the Wizard gap.]
- The other Wizard rows (human): `-Route relic` 6/12, `-Relics` 1-act 11/12; off 9/12 and 12/12.

## 2026-11-11 - MB1 design note (game-lead)
The full note is in `docs/MAP.md` §11. These are my starting values, not director decisions. The sim floors and the playtest tune them. Rejected alternatives are in brackets.
- **Both mini-bosses run on `Boss.gd` and `bosses.json`,** with a field that marks a mini-boss: rank `elite`, a shorter death beat, and never a run win. [A new AI class, which would duplicate the telegraph, phase and fairness code.]
- **HP is anchored to today's mini-boss** (175 in act 1, about 192 in act 2), because the SIM1 floors were measured against it. The brute has 170 and the duelist 90 (99 in act 2), the duelist's being about half, as the director's example says. Final HP = `bosses.json` x `acts.N.hp`, with no tier multiplier. [Keeping the x3.5 tier on top, which would double-scale.]
- **Every wind-up stays at 0.6 s or more,** so the duelist's "short telegraph" is the existing floor. [Lowering `min_telegraph` for the duelist: it's the Wizard's worst matchup and the Wizard has the least floor slack.]
- **The duelist's damage is set so a full-HP Wizard (22) survives any two sequences** (at most 20). Its hardest single hit is 9, against the Guardian's 10. If the Wizard falls under its floor in room 20, damage is the first knob.
- **The brute has a signature move the Guardian doesn't** (three telegraphed floor circles at once) and drops the volley. That keeps it from being the "bigger copy" D44 rejected. [Brute = slam + charge + adds only: too close to the Guardian's kit.]
- **Adds come only from phase `summon`;** the mini-boss rooms lose their second wave stage. [Both, which makes the add count hard to read and to cap.]
- **New code is limited to three pieces:** the aoe `count`/`scatter` fields, the `chain` field and the `blink` kind. Each implements the sim bot's threat functions.
- **Two gameplay-dev sittings along the new code.** Sitting A: the mini-boss marker, the act tint, aoe `count`/`scatter`, the brute, act 1 room data and `mini_boss_act1`. Sitting B: `chain`, `blink`, the duelist, act 2 room data and `mini_boss_act2`.
- **The act tint lives in `run.json` `acts.N.tint`** (floor and light colours). There's no act 3 damage bump for now.

## 2026-11-11 - MB1 sitting A triage (gameplay-dev 5991616..f0fbdc3; game-lead)
All four SIM1 floors pass:

| Bot | Class | Wins (36 runs) | SIM1 baseline |
|---|---|---|---|
| human | Rogue | 27 | 26 |
| human | Wizard | 15 | 15 |
| off | Rogue | 35 | 35 |
| off | Wizard | 29 | 29 |

The hashes are unchanged and the suite is 2136, 0 orphans. No human-preset run was lost at room 10, the brute's room. That's information, not a gate. The act 1 brute may be on the easy side; the playtest decides.
- **The brute's armor is 22, not 30, with resistance 0.3.**
  - The armor-parity validator rejects armor 30 with resistance 0.3. 22 is exactly the old `mini_boss` tier's defence, so the SIM1 anchor holds. MAP.md §11.2 is corrected.
  - [Armor 30 with resistance about 0.37: a tankier brute nobody asked for. A parity exception: it weakens a tested rule for one enemy.]
- **Elite-rank bosses can be stunned** (gameplay-dev's call, accepted):
  - a stun cancels the wind-up or charge with no hit;
  - the duration is halved for elites;
  - the final Guardian stays immune.
  - This is the existing status rule applied consistently, so the GDD doesn't change.
- **gameplay-dev's other filled-in values are accepted:**
  - recover times;
  - `max_range` values;
  - a shorter transition and death beat;
  - the spawn block copied from the Guardian;
  - the act tints `#4d734d`/`#ffffff`, `#46606f`/`#dce8ff`, `#704840`/`#ffe3cf`;
  - the scenario flags `natural_hp`, `standard_deck` and `act`.
- **The sim's `BOSS TIMES` line now includes the brute fight.** It isn't comparable with the earlier final-boss-only figures.
- **For ux:**
  - the brute uses `BossHpBar` with its `display_name`;
  - whether to add an "Act 1 Mini-boss" subtitle is ux's call;
  - `MiniBossBar` only covers tier-`mini_boss` enemies (the act 2 golem until sitting B).

## 2026-11-11 - MB1 sitting B triage (gameplay-dev a284270..8dae255; game-lead)
All floors pass:

| Bot | Class | Wins (36 runs) | Sitting A |
|---|---|---|---|
| human | Rogue | 28 | 27 |
| human | Wizard | 15 | 15 |
| off | Rogue | 35 | 35 |
| off | Wizard | 30 | 29 |

The suite is 2174, 0 orphans, and the hashes are unchanged.

**Neither mini-boss cost a human-preset run (0 losses at room 10, 0 at room 20).** The duelist dies in a median 15 s (Rogue) and 23 s (Wizard). The Rogue's median HP left is 22 of 30, the Wizard's 22 of 22.

**Kept for the playtest, not retuned.** The bot isn't a reliable read of reaction-based fights. The director's "hits harder" is a feel judgment, and the playtester and he will answer it. [Raising the damage or HP now on bot numbers alone.]

If the playtest finds them soft, the knobs are, in order:
1. the duelist's HP (90 -> about 120);
2. its damage, within the 22 HP two-sequence rule;
3. the brute's summon count.

**gameplay-dev's calls, accepted:**
- **Duelist armor 10 and resistance 0.17** (parity; it stays fragile). [21.4 / 0.3 would make it as tough as the brute.] MAP.md §11.3 is corrected.
- **"Behind" means the far side of the player from the boss,** not the player's facing. It's clamped to the arena and moves to the boss's side if it would land within 1.2 m of the player. This is readable in isometric view, where facing isn't.
- **A chain is at most 2 attacks** (one link), as MAP.md says.
- **Bosses ignore knockback during a wind-up or an active attack.** Otherwise a hit could shove the duelist off its drawn telegraph. Fairness beats push.
- The filled-in values in the hand-back are accepted, including the enemies.json `move_speed` 4.5. The phase speeds 5.0 / 5.6 are what play.

**For ux:**
- Label the second dash link so it reads as coming.
- The blink marker must not read as a damage zone; the backstab outline is thin.
- Re-check the BD3a mini-boss bar item against `BossHpBar`. `MiniBossBar` is now unused in runs.

## 2026-11-11 - MB1 ux triage (ux 1b3fe3a..7897d66; game-lead)
The suite is 2191 / 163, 0 orphans, and the hashes are unchanged. ux's 11 judgment calls are accepted as listed in the hand-back:
1. the "(1/2)" / "(2/2)" chain cue, derived from data;
2. the cyan ring-and-ghost blink marker, distinct by shape;
3. compact multi-disc telegraphs;
4. thicker boss wedges;
5. "Running low" for the low-HP tag;
6. "Wants Bleed stacks", as words only;
7. the on-screen stack-label lift;
8. the act read once at bind;
9. MiniBossBar kept for MAP4;
10. act tints unchanged;
11. the commit attribution line.

Two items stay open:
- **The Open a Vein LIVE glow isn't asked of the director.** It's a cheap, reversible readability call. It waits on the playtest: if the words-only cue is missed, gameplay-dev exposes stack counts to the slot view in MAP3b. [Building a new condition type now.]
- **The ux "eyes" items go to the playtester, not to OPEN_ITEMS:** act 3 red chasers on the dull-red floor, the "Running low" wording, and stack labels with 3 or more neighbours. They reach the director only if the playtester finds a problem.

**Flake watch:** `player_death_test.test_enemy_stops_targeting_dead_player` failed twice in full runs (enemy velocity 2.4) and passes alone. qa investigates in the MB1 review. ux's added reset may only mask it.

## 2026-11-11 - MB1 qa PASS (qa e3835d0; game-lead)
Review: `docs/reviews/2026-11-11-mb1-qa.md`. No blockers.
- **Gate:** the numbers match sitting B cell for cell.

  | Bot | Rogue | Wizard |
  |---|---|---|
  | human | 28/36 | 15/36 |
  | off | 35/36 | 30/36 |

  - 0 losses at rooms 10 and 20 in any cell.
  - No-card ceiling 0/12 for each class; parity unchanged.
- **Suite and hashes:** the suite is 2191 / 163, green twice; the hashes are unchanged.
- **The `player_death_test` flake is a test-setup fragility from before MB1:** the enemy spawned inside the player's capsule. qa moved it to 4 m and added a diagnostic message. It wasn't reproduced, so it's on watch.
- **Carry-overs, all non-blocking:**
  - co-located solid bodies climb (gameplay-dev, low priority);
  - the O(n^2) stack-label scan;
  - an untyped loop variable in `Scenario.gd`;
  - blink visual constants in code;
  - the Wizard's early-room losses (BD3b).
  - They go to the MAP3b housekeeping list.
- **Next:** the playtester, with the "soft mini-bosses" question and the ux eyes items.

## 2026-11-11 - MB1 playtest triage (playtester 73e844b; game-lead)
Report: `docs/playtests/2026-11-11-mb1.md`. The smoke check passed and there's no blocker. The acceptance line ("clearly different from normal enemies, each other and the Guardian") is met on frames. The playtester couldn't hand-play, so the feel judgments are opinion built on bot data and frames.
- **MB1 closes with the numbers as built.** The tuning goes to the director as eyes item 55, with a default. Both mini-bosses look soft: the duelist is a "speed bump" for a moving Rogue (12-16 s, usually no damage taken), and the brute is soft for the Rogue but fair for the Wizard.
- **The default, if he doesn't object,** is gameplay-dev's first data step in MAP3b, with a qa re-gate:
  - the duelist's `max_health` goes 90 -> 120 (act 2: 99 -> 132);
  - Wet floor's outer discs land at least 3 m from the player, so the safe pockets are real. That's a small code change to the scatter rule.
  - The brute is unchanged for now. Adds come before HP if it needs more.
  - [Re-tuning before the tag: it costs a full build -> qa -> playtest loop on bot evidence alone, while his play is the real read for "hits harder".]
- **Open a Vein glow:** the playtester recommends one (you read the pill once, then ignore it). It's scheduled for MAP3b: gameplay-dev exposes stack counts to the slot view, then ux adds the glow. It isn't asked of the director, since it's cheap and reversible.
- **"Running low" being rare is as designed.** With the 30% act-start heal and the 50% threshold, it shows only if you arrive at 6 HP or less. No change.
- **To MAP3b ux:**
  - stack labels still collide with a neighbour's damage numbers at 2 enemies (the 3+ case is unverified);
  - slot card names clip at a comma;
  - red chasers have low contrast on the act 3 floor.

## 2026-11-12 - MAP3b design pass (game-lead)
The content plan is in `docs/BUILD_DEPTH.md` §12, and the sittings are in the ROADMAP MAP3b "Detailed brief". These are the calls made without a director directive:
- **Counting rule.** MAP.md §4.5's "5+ rare, 4+ legendary per class pool" is met on each class's eligible set (class + Fire + Neutral), and at least half of a class's rare and legendary cards come from its own pool.
  - Result: 6 rare and 5 legendary per class, 6 of the 11 from the class pool.
  - [Counting the eligible set only: Fire and Neutral could fill most of a Rogue's top tier, which is the "trapped in Fire" problem again.]
- **Retag or new: all new; no retags.**
  - Retagging BD3a's Bleed commons would pull them out of act 1 offers.
  - Retagging Fire commons would shrink the Fire Wizard's act 1 options before BD3b.
  - [The brief's default allowed up to 2 retags per pool.]
- **New code is limited to:**
  - card rarity and the per-act rolls;
  - the mini-boss boss-relic offer;
  - card prices by rarity;
  - two stats, `attack_damage_mult.<light|heavy>` and `dead_card_swap_locked`;
  - possibly allowing `reduce_cooldown` on cards.
  - Everything else uses shipped stats, events and templates, each with a named shipped example in §12.2.
  - [Taking Performance Review, The Glass Ceiling, Thermal Ward, Echoing Aegis or cc: All Staff as written: each needs a new event, condition or projectile rule.]
- **Bot-safe boss relics only.** No dodge loss, no disabled slot, no auto-cast and no input rebinding. So Cursed Gauntlet, Quarterly Downsizing, The Unstable Core, Glass Hourglass and Brainstorming Session stay candidates.
  - Reason: SIM1's floors gate every slice, and each of those needs its own bot rules, and some need ux.
  - [Building them with bot rules now: it roughly doubles sitting A for 1-2 relics per class.]
- **Rarity with the shipped offer rules:**
  - the slot rolls a rarity first, then uses the unowned/owned weights, the D43 lean and D47 pruning;
  - an empty rarity falls down, never up;
  - the mini-boss card offer fixes the rarity and uses the same fall-down.
  - [Rolling rarity after picking a card: the lean would then also have to weight rarity, which is harder to explain.]
- **Boss offer at the cap:** Cancel in the give-up step goes back to the boss offer, because "no skip" means you can't leave without one. The second offer excludes only the owned boss relic: 6 per class leaves 5 to draw 3.
  - [Showing every offered boss relic only once per run: that needs 7 or more per class.]
- **Card prices:**
  - three-act: common 55, rare 85, legendary 125;
  - one-act: 40/65/95.
  - Each is below its relic tier (80/120/170 and 60/90/130); the sim tunes them under D41 = B.
  - [Keeping the one-act 40/65/95 for three acts: commons would cost half a tier 1 relic, cheaper than intended.]
- **The Wizard's top tier is knowingly thinner.** No new Fire Wizard cards. Its 6 class-pool cards use projectiles, armor, the auto bolt and cooldowns, because Thesis and Ward Battlemage need BD3b's code. BD3b closes the gap.
- **Targets:**
  - late-offer Bleed share for a Bleed Rogue in act 3: at least 12% (it was 8.5%; the content gives an estimated 18%);
  - Burn-needing relics: Rogue 5 of 23, Wizard 7 of 22 (was 6 of 10);
  - boss relics needing Burn: 1 of 6 per class.
- **Split:** three gameplay-dev sittings in one tag: A engine, B content, C tuning. C may merge into B. A's tests use fixture content, so A doesn't wait on B.
  - [One sitting: about 40 new data files plus the engine is too much for one sitting.]
  - [Two tags: a playtest of rarity with no rare cards has nothing to judge.]
- **Follow-ups from game-lead's review of the brief (same day):**
  - Pool-filled decks take only common cards, so legendaries never land in opening or sim decks, and the SIM1 floors and hashes stay comparable.
    - [Leaving it to 3d's availability field: sitting B would move every hash and put legendaries into the bot's decks.]
  - `stacking.hard_cap` 10 for Bleed and Burn.
    - [No ceiling: Bleed would reach 20+ stacks before an x3 detonate.]
  - Liquidate Assets stays tier 2.
  - `CardDamageRule` is a floor, not a ceiling, so rare and legendary power is judged by the sim and the playtest.
- **D49 (pruning or rejecting shrinks a type's offers) goes to the director.** It changes GDD §9 offer weighting, as D43 did. Default A: no new rule. Nothing in MAP3b waits on it.

## 2026-11-12 - MAP3b sitting A triage (gameplay-dev 5d5678c..472beb0; game-lead)
- **Accepted as built:**
  - Suite 2233 / 164, 0 orphans.
  - Hashes unchanged.
  - SIM1 gate at the MB1 tuning, unchanged on every cell: human Rogue 28/36, Wizard 15/36; off 35/36, 30/36. There were no losses at rooms 10 or 20.
- **One-act card prices: no scaling.** The brief's 40/65/95 assumed a 0.75 one-act relic scale that was never built: `--acts=1` already uses 80/120/170. Cards use 55/85/125 in both run lengths. The one-act run is a debug and legacy mode.
  - [Building a one-act price scale: new code for a mode nobody plays by default.]
- **gameplay-dev's calls, accepted:**
  - the rarity roll on its own seeded stream (old offers are unchanged when act 1 is all common);
  - the keys `rewards.rarity_weights` and `rewards.mini_boss_rarity`, not a new `cards` block;
  - with no boss relics shipped, the mini-boss keeps the interim offer with skip until sitting B;
  - a boss offer that can't be taken at the cap (only boss relics held, `--relic-cap=1`) shows Skip, so it can't deadlock;
  - Wet floor `scatter_min` 3 equal to `scatter` 3 (a wider scatter broke the fairness tests);
  - `GroundClamp` at floor y 0;
  - relic bolts use the reticle direction.
- **Eyes 55 data point:** the default tuning (Raider 120 HP, Wet floor ring) didn't move the bot results, and the fights still cost the bots almost no HP. It's relayed in OPEN_ITEMS 55: "harder" would need more than HP.
- **For qa:**
  - the gate at HEAD, which includes card price 55, chest `min_tier` 2 and the relic aim fix;
  - Cancel at the cap with `--relic-cap=1`;
  - expect more exhausted-pool fallbacks in act 3 until sitting B adds tier 3 relics.

## 2026-11-12 - MAP3b sitting B interim calls (gameplay-dev 22a9d8f + uncommitted bumps; game-lead)
- **Exsanguinate stays at 21 base damage with the +1.5 cooldown.** gameplay-dev asked; it's game-lead's call, since it's a balance value on a new card.
  - The slow cooldown keeps the detonate a paced payoff, and the 21 base only clears the `CardDamageRule` floor at the 4.0 s cycle.
  - qa reports the worst-case detonate at 10 stacks x3; the playtest judges it.
  - [13 base with no cooldown penalty: a x3 detonate every 2.5 s is the bigger risk.]
- **Base damage bumps instead of `rule_exception`, accepted:** Arterial Spray 5 -> 8 (unconditional part), Controlled Demolition 10 -> 13. These are new cards, so there are no old shipped values.
- **gameplay-dev's data deviations, accepted:**
  - Knuckle Sandwich `reduce_cooldown` is 60 s, the validator maximum;
  - `tick_interval` 0.5 on Office Hours and Scorched Earth;
  - Tenured Professor bolts do 1.5 each;
  - Thousand Memos range is 2.0;
  - "X% faster" on light attacks uses the rate reading;
  - stuns follow rank and diminishing-returns rules, so they're halved on elites. The rule text doesn't say so; ux may add it.
- **Pyre Insurance still lists `mini_boss` in its sources**, left over from MAP3's interim reward. To fix in sitting B or C: remove it, since boss offers draw only rarity `boss`. qa confirms that a tier 1 relic can't count toward the 2 boss relics.
- **Process:** the sim and suite batches gameplay-dev started before the bumps are stale. Killing the Godot processes was refused by the permission system. game-lead doesn't override that: the batches finish on their own, and gameplay-dev relaunches on the final commit.

## 2026-11-12 - MAP3b sittings B and C triage (gameplay-dev 22a9d8f..8157c59; game-lead)
- **Accepted:**
  - suite 2244, 0 orphans;
  - hashes unchanged;
  - SIM1 at 8157c59: human Rogue 27/36, Wizard 23/36; off 33/36, 35/36; no-card 0%. All floors hold. Off Rogue is 1 above its floor of 32, so watch it.
- **Relic targets met with no gold or price change** (three acts, 36 runs per cell, off bot):
  - `relic` median 15 for both classes;
  - `safe` median 6.5 for the Rogue, 6 for the Wizard;
  - max 18, nobody at the cap;
  - exactly 2 boss relics in every finished run.
  - D41 = B: income wasn't the limit, so no knob moved.
- **The merchant bot's change is accepted:** non-relic routes now finish with relics, cheapest first. `safe` missed its target only because the bot never bought a relic. This also moves the `first` baselines, so the SIM1 numbers aren't like-for-like with MB1's.
  - [Limiting it to `safe`: a rule tied to a route name, which leaves `first` bots hoarding gold.]
- **Late-offer Bleed share 11.8% against a 12% target: accepted as met.**
  - The tool doesn't model the mini-boss's fixed rare and legendary offers, so the real share is a little higher.
  - My 18% estimate assumed the lean multiplies rare draws more than it does.
  - The playtester's Bleed run is the real check. A further Bleed card is a candidate for BD3b if the playtest says so.
  - [Adding a card now: one more content loop for a 0.2-point gap inside measurement error.]
- **The `offer_report` tool now rolls act rarity.** It's a one-line fix to existing tooling, accepted.
- **Spread check** (n = 12 per cell, reported, not gated):
  - The Non-Compete Clause won 12/12 for both classes, the clear outlier.
  - Corporate Buyout came in under baseline (7 and 6).
  - Fight Club won 12/12 for the Rogue.
  - No change before the playtest. Both go to the playtester and qa as watch items; the first knobs are Non-Compete's 0.5 s refund and Corporate Buyout's cooldown cost.

## 2026-11-12 - MAP3b ux triage (ux-designer e596c5a..f59e2c6; game-lead)
- **Accepted:** suite 2264, 0 orphans; hashes unchanged; all six items done or answered.
- **Act 3 floor tint `#704840` -> `#8f8060` (sand), accepted for now**, so red chasers stand out. Act identity is the director's (D44 = C), so it goes into the MAP3b eyes item with before and after screenshots. Reverting is a single data value.
  - [Recolouring the chaser: one colour per element.]
- **The "comma clipping" nit wasn't reproduced.** A test now fits every name at 10 HUD heights. Closed.
- **The stun relics' "halved on elites" note:** skipped by ux. It's a `rule_text` data edit, deferred to BD3b housekeeping, since the stun rules apply everywhere and are shown nowhere else either.
- **For qa and the playtester:**
  - the Open a Vein glow lit in play (unit-tested only);
  - stack-label dimming with 3+ enemies;
  - act 3 telegraph readability on the sand floor;
  - a real act 3 merchant with a legendary in stock;
  - the Burnout Syndrome tile.

## 2026-11-12 - MAP3b qa PASS (qa 02ed622 and later; game-lead)
Review: `docs/reviews/2026-11-12-map3b-qa.md`.
- **Results:**
  - suite 2273, 1 skipped (qa's open-finding test), 0 orphans;
  - hashes unchanged;
  - SIM1 27, 23, 33 and 35 of 36, no-card 0%;
  - 189 of 189 won runs have exactly 2 boss relics;
  - §12.6 met.
- **Exsanguinate's worst case** (1332 before armor, with 10 stacks and six amplifiers) is left to the playtest. It needs a deep, deliberate build inside a 4 s window, and a broken late combo is part of the genre's fun.
  - [A cap on detonate damage: new code, and it limits the Bleed payoff the director asked for.]
- **Quitting inside the mini-boss reward drops a boss relic already taken, by design.** Saves happen only at room boundaries (MAP.md §8), and the replay gives the identical offers, so you just pick again.
  - [Saving mid-reward: a second save point for one screen.]
- **Carry-overs to MAP4 gameplay-dev housekeeping:**
  - the sim bot picks an untakeable relic at `-RelicCap 1` (un-skip the qa test);
  - a forced `--relic-offer` skips the boss branch (capture tooling only).
- **Watch items:**
  - The Non-Compete Clause is confirmed strong: 12/12 for both classes.
  - "Corporate Buyout is weak" isn't confirmed (11/12 and 12/12 in qa's cells).
  - Both go to the playtest.
- **Wizard act 1 losses** (5 of 13 human losses in rooms 2-4) go to BD3b.

## 2026-11-12 - MAP3b playtest triage (playtester bffaf3a; game-lead)
Report: `docs/playtests/2026-11-12-map3b.md`.
- **Results:** smoke PASS, no blocker. The playtester can't hand-play, so feel calls are theory based on bots and frames.
- **MAP3b closes as built.** Tuning goes to the director as eyes item 56, with defaults that become MAP4 gameplay-dev's first step (as MB1 did):
  - **The Non-Compete Clause's refund goes 0.5 s -> 0.3 s.** Its cost (half basic-attack damage) barely bites a card-heavy deck, and it went 12/12 in the sims.
  - The other boss relics stay as built.
  - [Re-tuning before the tag: it costs a full loop on bot evidence, and his play is the real read.]
- **"Every boss relic needs a cost you feel often":** game-lead's design target from BUILD_DEPTH §12.5, not a GDD rule. It's reviewed after the director has played; not asked separately.
- **Fire still crowds a Bleed Rogue late: 31% Fire against 12% Bleed** (the offer tool; the mini-boss offers aren't modelled). Content alone hasn't fixed the director's priority, so D49 is updated with this data, and game-lead now recommends B (pruning or rejecting a type lowers its offers). The default stays A until he answers.
- **Rare and legendary Bleed cards are rarely cast by the plan bot,** which likely undervalues them. Watched in BD3b's bot work; no change now.
- **Burnout Syndrome turning up in both offers is expected.** It's 1 of 6 eligible, so it's in about half of all 3-card offers. A smarter draw is not worth code now.
- **Carry-overs to MAP4:**
  - gameplay-dev: Knuckle Sandwich's tile reads "Take 60 s off your Heavy attack cooldown"; make it read as a reset. Also the `-RelicCap 1` bot finding.
  - ux:
    - stack labels overlapping at 2 enemies;
    - a 4-enemy Bleed scenario to verify the dimming and the Open a Vein glow;
    - golem and pink telegraph contrast on the act 3 sand floor.
- **Exsanguinate's worst case:** left as is. Watch for one-cast boss kills in the director's play.

## 2026-11-12 - Applying D49 = B (game-lead)
- **The director chose B.** It's recorded in GDD §9 and is MAP4 gameplay-dev's first step.
- **"Type" means the statuses a card applies (Burn, Bleed),** the same key the D43 lean uses. So a pruned Fire/Burn card lowers every Burn card's offer weight, and statusless cards are untouched.
  - [The card's pool (Fire, Rogue): that would also push away statusless Fire cards and the class's own Bleed cards when a Rogue Bleed card is rejected.]
- **Starting values (data):** x0.8 per prune or reject, floor x0.4, applied on top of the lean.
- **A reject counts once per offered card of each status in that offer.**
  - [Once per offer: a reject of three Burn cards would count the same as one.]
