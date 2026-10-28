# Roadmap

Milestones match `docs/GDD.md` §13. Task status within a milestone is tracked here; design intent lives in the GDD; one-off technical/assumption calls live in `docs/DECISIONS.md`.

## Milestone 1 — GDD v0.2 — **Done**
Engine, perspective, and slice classes/elements decided (Godot, 3D isometric, Rogue/Wizard, Fire/Water).

## Milestone 1.5 — Project scaffold — **Done**
- [x] Move `GDD.md` to `docs/GDD.md`
- [x] Create `/src /scenes /data /assets /tests /tools /docs` layout
- [x] `project.godot`, `.gitignore`, `.gitattributes` for Godot 4
- [x] Install Godot 4.7.2, verify headless run with zero errors/warnings
- [x] Pick and wire up a headless-runnable test framework (gdUnit4)
- [x] Root `CLAUDE.md` working agreements
- [x] Role agents in `.claude/agents/`
- [x] `README.md` with run/test instructions

## Milestone 2 — Combat Feel Prototype — **Done**
Goal: one arena room where moving, aiming, and using card slots already feels good. The only question this milestone answers is "is the core combat fun?"

- [x] Camera and player: fixed isometric 3D camera, capsule player, WASD movement, mouse-raycast aim, smooth camera follow
- [x] Basic attack: left click, fixed cooldown, melee arc (see DECISIONS.md)
- [x] Dodge roll: Space, i-frames, own cooldown, universal (separate from Movement slot)
- [x] Generic stat-modifier system (stub values, data-driven hook for future passives/equipment)
- [x] Card data schema + loader + validation (fails loudly on malformed JSON)
- [x] Effect-template registry: projectile, cone, aoe, dash, heal, apply_status, buff
- [x] Card slot system: 5 data-driven slots, mini-decks, shuffle/reshuffle, cooldown = base + modifier, dead-card swap with penalty cooldown
- [x] Status effect system, generic, with Burn as the first implementation
- [x] Damage/resistance model: elemental-only resistance, caps per GDD §7
- [x] Enemies: melee chaser, ranged shooter, resistant elemental type; health, hit reactions, knockback, simple chase AI
- [x] Wave spawner for the arena
- [x] HUD: 5 slot widgets (name, cooldown sweep, next-card preview), health bar
- [x] Debug overlay (F3): FPS, slot cooldowns, deck contents
- [x] Starter card set: ~12-15 JSON cards for Fire Rogue (class/element/neutral pools)
- [x] Juice pass: hit-stop, screen shake, damage numbers, hit flash, enemy attack telegraphs
- [x] Unit tests: cooldown math, slot cycling/reshuffle, dead-card swap penalty, resistance math, Burn tick, card schema validation
- [x] Headless bot-simulation stub in `/tools`
- [x] QA pass over the milestone before marking done

## Post-milestone polish
Small director-requested items between milestones. Not Milestone 3 scope.

- [x] **HP bars above enemies** — **Done** 2026-10-27 (qa PASS e60e515, 83/83 tests; playtester: no blockers)
  - **Shipped as:** `scenes/ui/EnemyHpBar.tscn`, `src/ui/EnemyHpBar.gd`, `src/ui/UiConfig.gd`, `assets/shaders/enemy_hp_bar.gdshader`, config in `data/ui.json` (`hp_bars`) - names differ from the brief's guesses below. Commits b31cbde, 0309f86, bcbfe34, e60e515. Ghost trail and Burn flame pip included; resistant enemies get a tinted thick frame + diamond pip.
  - **Goal:** every enemy shows a world-space health bar so the player can read fight state at a glance.
  - **Owner sequence:** gameplay-dev -> ux-designer -> qa -> playtester -> game-lead (close).
  - **Files likely touched:** new `scenes/ui/EnemyHealthBar.tscn` + `src/ui/EnemyHealthBar.gd`, `scenes/enemies/*.tscn`, `scenes/debug/TrainingDummy.tscn`, new data config (e.g. `data/enemy_health_bar.json`), `src/combat/Health.gd` (read-only unless a signal is missing), new tests in `tests/unit/`.
  - **GDD sections:** §3 (fixed isometric camera), §7 (elemental resistance), combat-feel/readability notes. Visibility default logged in `docs/DECISIONS.md` (2026-10-27).
  - **Acceptance criteria:**
    1. Every enemy (melee chaser, ranged shooter, fire-resistant golem) and the TrainingDummy shows a health bar floating above it in world space.
    2. The bar always faces the camera, has a consistent on-screen size under the fixed orthographic isometric camera, and stays readable when enemies are clustered.
    3. Fill is proportional to current/max HP and updates immediately on damage, healing, and Burn ticks. Ghost trail (lighter segment draining after the main bar drops) is nice-to-have, only if cheap.
    4. Visibility follows the config value (default: always visible while alive, hidden on death). Changing the rule (e.g. "show only after damage") must be a data change, not a code change.
    5. Enemy types are distinguishable where it helps (e.g. a subtle tint or marker for elemental resistance), never relying on color alone. Kept simple.
    6. Optional if trivial: a small Burn status indicator on the bar; otherwise logged as a follow-up item.
    7. Performance: no per-frame allocations, no SubViewport per enemy, no Control node per enemy. Lightweight billboard approach (billboard quad meshes with an unshaded material or one small shared shader).
    8. One reusable scene driven by `Health` signals (`health_changed`, `died`); no per-frame HP polling; no hardcoded enemy types inside the bar.
  - **Done requires:**
    - qa PASS: tests for ratio math, clamping at 0 and at max, updates on damage and heal, hidden on death, no errors when an enemy spawns or is freed mid-frame; full suite green; 20-second headless run; zero errors and warnings.
    - playtester report with no blockers: smoke check, a screenshot of a wave, readability notes.
  - **Follow-ups** (director answers 2026-10-27, logged in `docs/DECISIONS.md`):
    - [x] (a) gameplay-dev: screenshot tooling - **done** (f468959, 96ca1a1, 083a8cf; qa PASS on 083a8cf, 91/91 tests). `powershell -File tools\capture_screenshot.ps1 -Scenario hp_bars -After "2.0,2.9,3.6"` (see README).
    - [ ] (b) visual check - **partially covered** by an hp_bars capture: damaged fills, Burn triangles, and resistant frames read clearly; ghost segment is subtle at 720p; in a very tight cluster bars stack and are hard to match to bodies. **Remaining:** director's hands-on look at bars over/near the player while playing.
    - [ ] (c) ux-designer (later): resistance marker reads as "armoured", not "resists fire". Director: acceptable for now; tooltip/legend stays open for later.
    - ~~(d) size bump~~ - dropped; director says size is fine.
    - [ ] (e) ux-designer (small): damage-number readability - numbers are ~10 px at 720p and hard to read (pre-existing, not caused by the bars).
    - [ ] (f) ux-designer (optional, config-only in `data/ui.json`): make the ghost segment more visible at 720p.
  - **Deferred idea (not a task):** show HP as a number or % (e.g. "34/100") on or near the bar.

## Post-milestone polish 1
Director-approved combined polish pass before Milestone 3 (2026-10-27). **Not Milestone 3.** Every slice runs the full loop one role at a time: game-lead brief -> gameplay-dev -> ux-designer (anything seen or clicked) -> qa (PASS/FAIL) -> playtester (smoke check + play) -> game-lead close. Commit after each slice; update `docs/STATE.md` between slices.

**Standing rules for every slice:** typed GDScript, content as data, placeholder visuals only, small commits, repo always runs. Tuned numbers and assumptions go in `docs/DECISIONS.md`.

**qa note on "zero warnings":** `docs/DECISIONS.md` (2026-10-26, test framework) records that ordinary GDScript lint warnings do not print in any CLI mode in Godot 4.7.2. qa reports "zero errors/warnings" only for what `--headless --editor --quit`, the 20 s `--headless --quit-after 1200` run, and the test runner actually surface, and says so explicitly. No blanket "zero warnings" claim.

**Visual verification:** use `tools/capture_screenshot.ps1 -Scenario <name> -After "<s,...>"` (README). New scenarios may be added to `data/scenarios.json` for a slice.

**Pass definition of done:** zero errors (and CLI-visible warnings) on `--headless --editor --quit` and a 20 s headless run; full suite green; SceneSelfCheck passes; one playtester report in `docs/playtests/` covering the whole pass with screenshots of each skill type cast, an auto light attack and a heavy attack, the death + game over flow, the HUD at 1280x720 / 1920x1080 / 2560x1440, and a wave at the new density, explicitly saying whether any single enemy feels unfair or unreadable; every tuned number in `docs/DECISIONS.md`; STATE.md points at Milestone 3a.

- [x] **Slice 0: Record director decisions (docs only)** - **Done** 2026-10-27 (game-lead)
  - GDD §9: reward offer is pick 1 of 3 or reject the whole offer; reject token spent only on whole-offer reject; 3 rejects per run; offer size is data. Reward screen NOT built (Milestone 3b).
  - GDD §1: density principle `[DIRECTOR DECISION]`.
  - GDD §3: light attack auto on a timer + left click; heavy attack right click.
  - GDD §15 (new, appended so existing §13/§14 references stay valid): survivor-style level-up layer `[IDEA, not scheduled]`, DO NOT IMPLEMENT.
  - GDD §14 item 1 narrowed to shops/drops only.

- [x] **Slice 1: Death and game over** - **Done** 2026-10-27 (game-lead). gameplay-dev 9744135, ux-designer 99f6af2, qa PASS 1f24ceb (`docs/reviews/2026-10-27-polish1-slice1-qa.md`, real 5x reload soak via `tools/run_reload_cycle.ps1`), playtester no blocker d268f19 (`docs/playtests/2026-10-27-polish1-slice1-death.md`).
  - **Follow-ups (not blocking):** (s1-a) death beat is subtle in stills: only the topple reads; add a flash/stronger grey-out cue, fold into Slice 4 (visuals); director to watch the slow-mo once. (s1-b) killing-blow damage number tiny/overlapping, joins follow-up (e). (s1-c) "Enter or Space" hint detached from button; world/HP bars show through backdrop (consider darker dim). (s1-d) HUD HP bar thin/low contrast, fold into Slice 2. (s1-e) in-flight projectiles still hit after death; enemies idle not wander; Burn ticks on dead player (harmless). (s1-f) first contact ~1 s after spawn, fold into Slice 5 density review.
  - **Owner sequence:** gameplay-dev -> ux-designer (Game Over screen) -> qa -> playtester -> game-lead.
  - **GDD:** §1 (density/readability), §11 (feel, tone), §3.
  - **Investigation result (game-lead, read-only):** the top-left "0 / 30" is **player HP** (`src/ui/Hud.gd:30`, `"%d / %d"` of `player.health`). `Player.gd` never connects `Health.died`, so when HP hits 0 nothing happens and the player keeps moving and casting at 0. That is what the director saw. Before the camera fix the unseen player died to wave 1 within ~7 s (STATE.md). Fix: handle death. Label the HUD value clearly (e.g. "HP 0 / 30").
  - **Note:** `Health` already guards double death (`_is_dead`, emits `died` once). Consume that signal. Don't build a second guard; do test it under simultaneous hits and Burn ticks.
  - **Files likely touched:** `src/player/Player.gd`, `src/enemies/Enemy.gd` (targets the player without checking death), `src/enemies/EnemySpawner.gd` (stop/reset waves), `src/main/Main.gd` (restart orchestration), `src/ui/Hud.gd`, new `scenes/ui/GameOverScreen.tscn` + `src/ui/GameOverScreen.gd`, `src/core/Juice.gd` (slow-mo beat), `data/ui.json` or a new data entry for death timings, `data/input_bindings.json` if "Try again" gets a key, tests in `tests/unit/`.
  - **Acceptance criteria:**
    1. At HP <= 0 the player dies exactly once: input disabled, placeholder death animation (collapse or flash), short slow-mo or hit-stop beat, then the Game Over screen.
    2. Death is idempotent: simultaneous hits or Burn ticks cannot trigger two game-overs.
    3. After death: no damage taken or dealt by the player, no card use, no dodge, no basic attack. Enemies stop chasing and attacking (idle or wander).
    4. A clear death signal/event exists that the Milestone 3 run system can listen to later (e.g. a `player_died` signal on Player or a small event hub). Don't build the run system.
    5. "Try again" cleanly restarts the arena: fresh HP, decks, cooldowns, enemies, wave state, status effects, timers; no leaked nodes, no stale signal connections, `Engine.time_scale` restored to 1.0. Simplest acceptable approach is a scene reload; log the choice.
    6. Enemy death still works, and effects, damage numbers, and HP bars clean up.
    7. ux-designer: Game Over screen is readable, dry in tone (GDD §11), and "Try again" is unmistakable (large, focused by default, keyboard + mouse).
    8. HUD HP value is clearly labelled.
  - **qa tests:** death at exactly 0 and below 0; idempotent death (two hits same frame, hit + Burn tick); input blocked after death; enemies stop targeting; restart resets all state (HP, decks, cooldowns, enemy count, wave index, time_scale); no errors and no orphan growth across e.g. 5 repeated death/restart cycles.
  - **playtester:** smoke check; screenshots of death beat and Game Over screen; is "Try again" obvious?

- [ ] **Slice 2: HUD text overflow and safe layout**
  - **Owner sequence:** ux-designer (lead; gameplay-dev only if a data hook is missing) -> qa -> playtester -> game-lead.
  - **GDD:** §4 (next card visible), §11.
  - **Files likely touched:** `scenes/ui/Hud.tscn`, `scenes/ui/CardSlotWidget.tscn`, `src/ui/CardSlotWidget.gd`, `src/ui/Hud.gd`, `src/ui/DebugOverlay.gd`, `data/ui.json` (font sizes, min size, margins), `src/cards/CardSchema.gd` (name-length warning), tests.
  - **Acceptance criteria:**
    1. Slot widgets have a fixed size; the five slots always align and nothing shifts. Cooldown bar and next-card preview have fixed positions.
    2. Card names: max two lines, then shrink font to a minimum (data value), and only as a last resort truncate with an ellipsis. Same rules for the "Next:" preview.
    3. Full name available in the F3 overlay, and as a tooltip if cheap.
    4. Bottom HUD anchored with safe margins; nothing touches or crosses a screen edge at 1280x720, 1920x1080, 2560x1440 (capture all three).
    5. Schema **warning** (not failure) for card names over 25 characters; logged in DECISIONS.md.
  - **qa tests:** a check that loads every card in `/data/cards` and flags any name or flavor line that would not fit at the minimum font size; a deliberately ~60-character name (test fixture, not a real card) does not overflow; layout checks at the three resolutions.
  - **playtester:** HUD screenshots at the three resolutions.

- [ ] **Slice 3: Automatic light attack, manual heavy attack**
  - **Owner sequence:** gameplay-dev -> ux-designer (timer indicators, bindings) -> qa -> playtester (feel report) -> game-lead.
  - **GDD:** §3 (as updated in Slice 0), §11, §12 (data-driven).
  - **Files likely touched:** `src/player/Player.gd` (replace the export-based basic attack), new attack config in `/data` (e.g. `data/attacks.json`) + loader/validation, `src/core/StatModifiers.gd` (read-only unless a hook is missing), `src/combat/EffectTemplates.gd` / `MeleeQuery.gd` (reuse, no new template), `data/input_bindings.json` (`attack_light` LEFT, `attack_heavy` RIGHT), `src/ui/Hud.gd` + small indicator widgets, tests.
  - **Acceptance criteria:**
    1. Each attack type (light, heavy) is data: `auto` (bool), interval/cooldown, damage, range, arc, wind-up, knockback, effect settings (hit-stop, shake, color/scale).
    2. Light: auto-fires on its interval toward mouse aim; **default (logged): only when at least one enemy is within range and arc**, so it never whiffs.
    3. Left click fires light immediately and restarts the auto timer; a click on the same tick as the auto timer fires once, never twice.
    4. Right click fires heavy: longer cooldown, visible wind-up telegraph, wider arc, more damage, stronger knockback, bigger hit-stop and shake. Manual by default; setting heavy `auto: true` in data is the only change needed to make it automatic.
    5. Intervals/cooldowns resolve through `StatModifiers` (e.g. `attack_interval.light`, `attack_cooldown.heavy`) so passives/gear can speed them up.
    6. Both reuse shared effect templates; heavy looks clearly different from light. Neither uses card slots, affects slot cooldowns, or is affected by dead-card swap.
    7. Nothing fires while dead (Slice 1) or in any already-blocking state (e.g. during dodge if dodge already blocks attacks; keep existing rules).
    8. Bindings configurable via `data/input_bindings.json`, defaults left/right click.
    9. ux-designer: small, unobtrusive light and heavy timer indicators.
    10. Placeholder numbers logged in DECISIONS.md.
  - **qa tests:** auto interval math incl. modifiers; manual click resets timer; no double fire; no fire without a target in range/arc; no fire while dead; heavy cooldown; data flag switches heavy to auto.
  - **playtester:** does auto-fire feel good; is clicking worth doing; is heavy meaningfully different; is auto light too strong or weak versus cards. Screenshot of an auto light and a heavy attack.

- [ ] **Slice 4: Skill visuals and targeting readability**
  - **Owner sequence:** gameplay-dev (effect visuals, pooling, hitbox-driven sizing) -> ux-designer (aim indicator, ground markers, readability tuning) -> qa -> playtester -> game-lead.
  - **GDD:** §11 (shared templates recolored/rescaled per element), CLAUDE.md "Content is data".
  - **Files likely touched:** `src/combat/EffectTemplates.gd`, `src/combat/Projectile.gd`, new `src/effects/*` (pooled visual nodes), `scenes/effects/*`, new element visual data (e.g. `data/elements.json` with color/scale; per-card overrides optional), `src/player/Player.gd` (aim indicator), `src/combat/StatusEffectManager.gd` (Burn visual hook), tests.
  - **Acceptance criteria:**
    1. Every template gets basic particles/animation, built once: projectile (trail, muzzle flash, impact burst); cone/melee arcs (sweep matching true shape and range); aoe (ground radius indicator, wind-up flash, impact burst); dash/movement (trail, start/end puffs); heal (rising sparkles); buff (short aura/ring); apply_status Burn (persistent flame on the enemy for the duration).
    2. Element looks are recolor/rescale from data; Fire is orange/red. Adding Water later is a data change only.
    3. Aim indicator: subtle ground reticle at the target point plus a direction line/arc. Aimed skills show a brief ground marker at the target or along the path on cast.
    4. **Visuals match hitboxes:** visual size is driven by the same data as the hitbox; a test asserts it for cone, aoe, and projectile. A visual that lies about the hit area is a bug.
    5. Performance: pooled/reused instances, a cap on simultaneous effects (data value), no per-frame allocations, cheapest particle type that runs headless (choice logged). Effects free/return themselves, don't leak over many casts, and don't error if caster or target is freed mid-effect.
    6. Hold-to-preview mode: game-lead logs a proposal only. Don't build it.
  - **qa tests:** visual-vs-hitbox size test; pool cap and no leak over N casts; caster/target freed mid-effect; headless run clean.
  - **playtester:** from a screenshot or short capture, can you tell which skill was cast, where it went, what it hit? Screenshots of each template type.

- [ ] **Slice 5: Wave density, enemy readability, HP bars**
  - **Owner sequence:** gameplay-dev (spawner, enemy fixes, bar rendering) -> ux-designer (bar visibility/size options) -> qa (incl. bot-sim) -> playtester (compare bar options, density screenshots) -> game-lead (pick bar default, close).
  - **GDD:** §1 density principle, §7.
  - **Files likely touched:** `src/enemies/EnemySpawner.gd`, new wave table data (e.g. `data/waves.json`), `src/enemies/Enemy.gd`, `scenes/enemies/*.tscn`, `src/ui/EnemyHpBar.gd`, `assets/shaders/enemy_hp_bar.gdshader`, `data/ui.json`, `tools/bot_sim.gd`, tests.
  - **Acceptance criteria:**
    1. Spawner holds about 6 to 15 simultaneous enemies, waves arrive in stages; cap and wave table are data.
    2. Each enemy type reviewed against the density principle (clear telegraph, distinct role, punishable window); findings in DECISIONS.md; cheap fixes done, rest listed as follow-ups.
    3. Enemy damage checked against player HP and the dodge i-frame window; numbers reported, adjustments proposed, any balance change logged.
    4. HP bar visibility default re-evaluated (always / after damage / hidden at full / always for elites+bosses) as a data config value. Bars depth-tested or otherwise not drawn over unrelated models, slightly smaller, consistent on-screen size.
    5. Headless bot-sim at the new density: report crashes, NaN, soft locks.
  - **qa tests:** spawner cap never exceeded; wave staging from data; bar config modes; bot-sim clean.
  - **playtester:** screenshots comparing bar options at the new density; a wave screenshot; explicitly say whether any single enemy feels unfair or unreadable. game-lead picks and logs the bar default.

- [ ] **Tooling: true-size capture (gameplay-dev, before pass close-out)**
  - The OS window is clamped to the monitor (1061 px tall), so `capture_screenshot.ps1` can't produce real 1920x1080 / 2560x1440. qa's `tools/vp_capture.gd` (88732cf) renders into an oversized SubViewport but `current_scene` is null there, so spawner/card code errors ("add_child on null") and no waves spawn; abrupt exit leaks RIDs.
  - **Acceptance:** a documented command produces true-size PNGs at 1280x720, 1920x1080, 2560x1440 with waves spawning and scenarios working; no error lines; spawn code uses a world/arena reference instead of `get_tree().current_scene` where needed (no behaviour change in normal play); clean exit. qa verifies; reload soak still clean.

- [ ] **Pass close-out:** whole-pass playtester report in `docs/playtests/`, DoD above verified, STATE.md points at Milestone 3a.

## Milestone 3 — Card system and run loop (next, outlined only)
Not started. Expected scope per GDD §13 milestone 3 and §9:
- Multi-room procedural run structure (room graph, not just one arena)
- **3a:** run structure (room graph/data model) first
- **3b:** post-battle card reward screen: pick 1 of 3 or reject the whole offer, 3-reject cap per run, offer size from data. Build it to be reusable for future 3-choice screens (GDD §15 level-up idea)
- Deck-clean rewards / routing choices
- A boss encounter
- Loadout saving between runs (starting from run 2, per GDD §9)
- ~~Resolve open question: single-card offer vs. choice of several~~ - resolved by director 2026-10-27 (pick 1 of 3 or reject all; GDD §9)
- Resolve open question: shops/drops alongside post-battle rewards (GDD §14 item 1)
- Expand the headless bot simulator from a stub into a real multi-room balance tool

## Milestone 4 — Second class/element, subclasses, passive tree prototype, balance sim
Not started. Per GDD §13: Wizard + Water added, 2 subclasses each for Rogue/Wizard/Fire/Water, first passive tree prototype (30-40 nodes), headless balance simulation grown out.

## Milestone 5 — Art/audio pass, friends-and-family playtest
Not started.
