# Decisions Log

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
- **Documented command:** `tools/run_tests.ps1` (PowerShell). It resolves the Godot binary from `$env:GODOT_BIN` or `godot` on PATH, then runs the gdUnit4 CLI tool against `res://tests` with `-c` (continue past failures, so one run reports everything instead of failing fast). Exit code reflects pass/fail. See README.md.
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
- **Burn implementation:** generic `StatusEffect` resource (id, duration, tick_interval, data-driven effect list) so Chill/Soaked/etc. are pure data later; Burn's data is `{type: "damage_over_time", element: "fire", ...}` applied through the same effect-template system as cards.
