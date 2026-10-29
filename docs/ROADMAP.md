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

- [x] **Slice 2: HUD text overflow and safe layout** - **Done** 2026-10-27 (game-lead). ux-designer f5b0c19, qa PASS 88732cf (`docs/reviews/2026-10-27-polish1-slice2-qa.md`), playtester no blocker 366eabd (`docs/playtests/2026-10-27-polish1-slice2-hud.md`).
  - **Follow-ups:** (s2-a) raise `preview_min_font_size` 9 -> 10 (decided, see DECISIONS; ux-designer does it in Slice 3). (s2-b) slot cooldown/ready state not visible: ux-designer in Slice 3 alongside attack timer indicators. (s2-c) two-line "Next:" looks ragged; HP bar low-HP cue and colour distinct from enemy bars (nice-to-have). (s2-d) pale blue triangle top-left at 8 s, unknown (likely world/sky edge, seen by ux too at wide aspect) - check in Slice 4. (s2-e) no test for F3 overlay or slots ignoring mouse; qa adds in Slice 3 (left click attack must not be eaten by slots).
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

- [x] **Slice 3: Automatic light attack, manual heavy attack** - **Done** 2026-10-27 (game-lead). gameplay-dev 1c12fd9 + de415be, ux-designer b4011aa, qa PASS ed0bf58 (`docs/reviews/2026-10-27-polish1-slice3-qa.md`), playtester no blocker e8b7e45 (`docs/playtests/2026-10-27-polish1-slice3-attacks.md`).
  - **Folded into Slice 4:** (s3-a) wedge drawn to `range` but hits reach ~range + 0.45 (hurtbox radius) - fix under criterion 4. (s3-b) auto light flash too faint/short (pale tan, 0.12 s); damage numbers tiny. (s3-c) heavy wind-up telegraph indistinguishable from impact in stills (muddy brown) - needs a distinct telegraph look. (s3-d) blue triangle top-left (also s2-d) - investigate.
  - **Other follow-ups:** (s3-e) LMB meter thin and unlabelled. (s3-f) slot cooling state still unverified in live play (no card cast in scenarios) - add a scenario that casts a card. (s3-g) clustered enemy HP bars unreadable in crowds -> Slice 5. (s3-h) F3 DebugOverlay Panel has STOP mouse filter (dev-only). (s3-i) same-tick test weak (min gap masks ordering). (s3-j) attacks poll `Input`; latch in `_unhandled_input` before the 3b reward screen.
  - **Balance proposals for the director (no change until decided):** (P1) spam-click light ~32 DPS vs auto ~13.3 (2.4x): lower cap to 0.4 s gap? (P2) heavy ~12.2 single-target DPS is below auto light: give it a reason (stagger, bonus damage)? (P3) root/slow during heavy wind-up? (P4) auto light 8 dmg beats most cheap cards (5-9): intended? (P5, info) 4a fixed projectile hit radius to read data: Flaming Nonsense 0.25 -> 0.3 actual. (P6, info) same fix widened all ranged enemy shots 0.25 -> 0.3 (kept, see DECISIONS 2026-10-28).
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
  - **Also in this slice (from Slice 2 follow-ups):** ux-designer raises `preview_min_font_size` to 10 (s2-a) and adds a visible slot cooldown/ready state (s2-b); qa tests that HUD slots don't swallow left clicks (s2-e).
  - **qa tests:** auto interval math incl. modifiers; manual click resets timer; no double fire; no fire without a target in range/arc; no fire while dead; heavy cooldown; data flag switches heavy to auto.
  - **playtester:** does auto-fire feel good; is clicking worth doing; is heavy meaningfully different; is auto light too strong or weak versus cards. Screenshot of an auto light and a heavy attack.

- [x] **Slice 4: Skill visuals and targeting readability** - **Done** 2026-10-28 (game-lead). 4a-4c built, qa PASS 6f82a4b + re-check 8cc7b92, playtester no blocker 68324d2 (`docs/playtests/2026-10-28-polish1-slice4-3b.md`).
  - **Owner sequence:** gameplay-dev (effect visuals, pooling, hitbox-driven sizing) -> ux-designer (aim indicator, ground markers, readability tuning) -> qa -> playtester -> game-lead.
  - **Sub-steps (scoping split, 2026-10-28; each one committed and runnable on its own):**
    - [x] **4a, foundation (gameplay-dev):** BUILT 2026-10-28 (42f4599..91587d5, 187/187 tests, reload soak clean); qa at 4d. Note for balance: projectile hit radius now really reads data (Flaming Nonsense 0.25 -> 0.3, bug fix). 4b hint: card_cast enemies clump on the player by ~1.5 s; consider stationary enemies for shots.
      s3-f card-cast capture scenario first (casts each card/template type, verifies slot cooling live); shared pooled VFX node with a simultaneous-effect cap from data; element visual data (color/scale) added to the existing element entries in `data/pools.json` (no parallel `elements.json` unless logged why); hitbox-driven sizing for cone, aoe, projectile plus the visual-vs-hitbox test; s3-a fix (default: draw the wedge to the current effective reach, range + hurtbox radius; don't change the hit query).
    - [x] **4b, template visuals (gameplay-dev):** BUILT 2026-10-28 (ba993b4..7755fbf, 208/208 tests, soak OK); qa at 4d. qa must check: soak flake (time_scale 0.25 ~1/8 runs, 250 ms grace added; pre-existing or not unverified), vfx cap 48 -> 64, projectile Area3D not pooled (visual is), enemy shots neutral-colored, player hit flash was dead code until now (now visible). Left: dodge roll has no trail.
      all seven template visuals from criterion 1; s3-b (stronger light flash), s3-c (distinct heavy telegraph look), s1-a (death flash/grey-out); s3-d/s2-d blue triangle, investigate and fix if cheap.
    - [x] **4c, aim and markers (gameplay-dev exposes aim point/direction if missing, then ux-designer draws):** aim reticle, direction line/arc, cast ground markers, readability tuning. BUILT 2026-10-28 (7d8817e..51fc5b0, 221/221, soak OK); qa at 4d. Follow-ups: (s4-a) enemy vs player physical shots both neutral cream, team tint needs code in `ElementVisuals` (gameplay-dev, later); (s4-b) tall golems occlude ground shapes and reticle -> Slice 5 enemy review; (s4-c) cone sweep duration 0.25 s is a constant in `TemplateVfx.cone_sweep`, move to data; (s4-d) dodge roll has no trail; (s4-e) director: check reticle with a real mouse and at 1440p.
    - [ ] **4d:** qa (whole slice) PASS 6f82a4b (`docs/reviews/2026-10-28-polish1-slice4-qa.md`), with should-fix S4-1/2/3 -> gameplay-dev fix pass done 5807412..b5180a8 -> qa re-check RESOLVED/PASS 8cc7b92 -> playtester folded into the Slice 3b playtest (one report, see DECISIONS 2026-10-28) -> playtester -> game-lead close. Follow-ups from review: S4-4 scenario flags unvalidated; DamageNumber only colors fire; CardDatabase fixture leak between suites (call `load_all()`).
    - Criterion 6 (hold-to-preview): proposal logged by game-lead in DECISIONS.md 2026-10-28. Done, no code.
  - **GDD:** §11 (shared templates recolored/rescaled per element), CLAUDE.md "Content is data".
  - **Also in this slice (from earlier follow-ups):** s1-a (stronger death cue: flash/grey-out), s3-a (attack wedge vs real reach), s3-b (light flash readability), s3-c (distinct heavy telegraph), s3-d/s2-d (blue triangle), s3-f (a capture scenario that casts each card/skill type, needed for this slice's screenshots and to verify slot cooling live). Note: scenarios default player HP to 9999 (`Scenario.gd`), so scenario shots say nothing about danger.
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

- [x] **Slice 3b: Attack rework (director decisions 2026-10-28, resolves P1-P4)** - **Done** 2026-10-28 (game-lead). qa PASS 552ef04 + re-check 0d454ae, playtester no blocker 68324d2. Playtest follow-ups -> Slice 5 (damage numbers, Pointy Stick visibility, weak cone/heal/dash reads); balance calls D4/D5 for the director.
  - **GDD:** §3 "Role of basic attacks [DIRECTOR DECISION, 2026-10-28]", §7 (statuses), §4 (slot cooldowns). DECISIONS 2026-10-28 "[DIRECTOR DECISION] Role of basic attacks".
  - **Owner sequence:** 3b-1 gameplay-dev -> 3b-2 gameplay-dev -> 3b-3 ux-designer -> 3b-4 qa (whole 3b) -> playtester (one report covering Slice 4 visuals and 3b) -> game-lead closes Slice 4 and 3b.
  - [x] **3b-1, click cap and cards-beat-light (gameplay-dev):** BUILT 2026-10-28 (961d7c6..4fb5b57, 260/260). Light 8 -> 3; Shrug Bomb 5 -> 12, Everyone Calm Down 8 -> 16; table in DECISIONS. Director call D4 (OPEN_ITEMS). qa at 3b-4.
   
    1. Replace light `manual_min_gap` with `manual_click_max_rate_ratio` (1.5). Min gap = resolved auto interval / ratio (0.4 s at 0.6 s), so it scales with attack-speed modifiers. Heavy keeps "click only when ready".
    2. Rule (game-lead default, logged): a **damage card** is any card in an `attack_single` or `attack_aoe` slot. Each must satisfy both:
       - (a) per-cast damage >= 1.5x the light hit.
       - (b) single-target DPS while cycling (per-cast / (slot base cooldown + modifier)) > auto light DPS.

       Per-cast damage includes guaranteed status damage from the card itself (e.g. Burn ticks over full duration, no resistance). Movement, utility and recovery cards are exempt and unchanged (Blaze and Bail is listed, but exempt). Fast, low-damage exceptions are allowed only with a logged `rule_exception` reason in the card data.
    3. Lower the light per-hit damage (8) and raise damage cards until the rule holds. Do not change non-damage cards, enemy numbers, or the light interval. If the rule forces any card past ~2x its current damage, still apply the simplest compliant numbers, and put a proposal in the hand-back (for example, slowing the light interval).
    4. A data validation check and a test that fail when any damage card breaks the rule.
    5. A before/after table in DECISIONS: every damage card's cast damage, slot cooldown and DPS, plus light and heavy for comparison. Also report rough time-to-kill per enemy type, before and after.
  - [x] **3b-2, heavy redesign (gameplay-dev):** BUILT 2026-10-28 (7192e13..ee9adbe, 292/292, soak OK). Rogue heavy 8.5 / 1.8 s (4.72 DPS direct, about 5.8 with Burn), arc area 3x light, stun, 50% Burn; Wizard `targeted_aoe` is data-only with a scenario. Director call D5. Follow-ups: (3b-a) a character entry in `/data` replacing the Player `owned_pools` export -> Milestone 3a; (3b-b) a Burn refresh resets its tick timer, so refreshes faster than 1 s deal 0 Burn (pre-existing; gameplay-dev, later); (3b-c) `attack_started` emitted before the wind-up state is set; (3b-d) re-stun emits no signal; qa at 3b-4.
   
    1. Per-class heavy definitions in data (for example under `heavy`, keyed by class id; the current character's class picks one). Shapes:
       - `arc`: wide melee, larger area than light.
       - `targeted_aoe`: centred on the mouse point, capped at `max_range`, with a ground telegraph during the wind-up. Clamp the target to the max range and the arena, with no errors when off the arena.
    2. Rogue heavy [PROPOSED]: wide arc, burst, a brief stun on hit. Wizard heavy [PROPOSED]: `targeted_aoe`, as a data definition only, proven by a test and a capture scenario. Do NOT build the Wizard class.
    3. Heavy numbers (default, updated after 3b-1, light is now 3 / 0.6 s = 5 DPS): about 8.5 per 1.8 s (4.7 direct DPS, burst 2.8x light). The current 22 beats every card and must come down. Burst per hit clearly larger than light (>= 2.5x), area meaningfully larger, sustained single-target DPS slightly below light. Report the final numbers.
    4. Element flavour: element status (Burn for Fire), chance = element base chance x the attack's `status_chance_multiplier`. Defaults: base 0.2 (in element data), light multiplier 0.0, heavy 2.5 (= 50%), heavy Burn duration 3 s. All in data.
    5. Stun: a new generic status in `statuses.json`. Stunned enemies don't move or attack, and an active wind-up is cancelled. Defaults:
       - Base duration 0.6 s.
       - Diminishing returns: each repeat within a 1.5 s window (was 4 s; changed by game-lead after 3b-2) x0.5; immune after the third stun until the window clears.
       - Elites x0.5; bosses immune.
       - Enemy `rank` (normal/elite/boss) in `data/enemies.json`. Current enemies are all normal unless logged otherwise. Test fixtures cover elite and boss.
    6. Wind-up slow: -35% move speed via StatModifiers, for the wind-up only. Removed on release, death, cancel, and scene reload. Never a root.
  - [x] **3b-3, ux-designer:** BUILT 2026-10-28 (8a9c704..ad9ee04, 306/306, soak OK). Stun stars + desaturate tint, IMMUNE popup (rate-limited), growing targeted_aoe telegraph, DR window 1.5 s. Follow-up (3b-e): IMMUNE can sit behind HP bars in tight crowds -> Slice 5 bar work. qa at 3b-4.
   
    - A clear stunned cue on enemies (for example spinning stars or a ring plus desaturation, via the shared pool).
    - A readable `targeted_aoe` ground telegraph that matches the hitbox via VfxSizing.
    - Heavy meter or labels updated if the heavy's shape or class matters to the player.
    - Any new bindings in `input_bindings.json`.
  - [ ] **3b-4, qa:** PASS 552ef04 (`docs/reviews/2026-10-28-polish1-slice3b-qa.md`, 326/326, DoD clean) with should-fix items. **Fix pass (gameplay-dev) done 9d91d7a..cdcdf47, 337/337; Fine, Burn Then 7 -> 12 (accepted, game-lead):** S3B-1 (Burn keeps its tick phase on refresh, and the card rule credits only the Burn that really lands, then Fine, Burn Then is retuned to comply), S3B-3..S3B-8, S4-4. qa re-check PASS 0d454ae (337/337, all RESOLVED; CHANGELOG accuracy PASS). Then the playtester (in progress) (Slice 4 + 3b), then close. S3B-2 (IMMUNE clipped by HP bars) -> Slice 5.
  - **qa tests:**
    - The click ratio never exceeds ratio x auto DPS, including under attack-speed modifiers.
    - The card rule check (fails on a bad fixture).
    - Stun: applies and expires; diminishing returns; elite and boss rules; stunned enemies don't move or attack.
    - Status chance multiplier math (seeded).
    - Wind-up slow is applied and removed, including on death and interruption.
    - `targeted_aoe` range cap; no errors when the target is off the arena.
    - DoD: zero errors and warnings on startup and in a 20 s headless run; full suite passes; SceneSelfCheck passes.
  - **playtester:** the heavy (stun, slow, element status, area), light-vs-card balance, and the 1.5x click cap, plus the Slice 4 questions (can you tell what was cast, where it went, what it hit). Screenshots.

- [x] **Slice 5: Wave density, enemy readability, HP bars** - **Done** 2026-10-28 (game-lead). 5a + 5b built; qa FAIL c13a43a -> fix pass -> re-check PASS 45ae002 (417/417); playtester no blocker f79455f (`docs/playtests/2026-10-28-polish1-slice5.md`). HP bar default: stays `always_alive` pending director D7 (playtester and ux both recommend B). Playtest should-fix items -> 5d.
- [x] **5d: Crowd readability follow-up** - **Done** 2026-10-28 (game-lead). Re-check PASS 957fa16 (in the Slice 6 review). Playtest folds into the pass close-out. BUILT 2026-10-28 (6db688d..0ca0afb, 426/426): steering raises spread frames from about 33-48% to 84-96%, the dummy is out, stats are in data. qa FAIL 8751371 (`docs/reviews/2026-10-28-polish1-5d-qa.md`): blockers S5d-1 (the in-range slide isn't speed-clamped; flaky test) and S5d-2 (stats validator never called on load), should-fix F1 (swirl side from instance id, not seeded). Fix pass done c3d244f..b1383f0 (435/435, 3 consecutive runs; spacing 84-86%). The qa re-check is folded into 6c. Original title: **5d (gameplay-dev -> qa, folded into the pass close-out playtest)**
  - (1) Separation steering for chasers (F-E3). Chasers must not stack into one blob on the player; the overlapping wedges and the hidden player were the playtest's top finding. Parameters go in data. Make sure the wedge telegraphs still match the real hits.
  - (2) Remove the TrainingDummy from the normal run (keep it available to scenarios). It reads as an enemy and clutters every run.
  - (3) Move per-type enemy combat stats (wind-up, damage, speeds, cooldown) from scene exports into `data/enemies.json`, with values unchanged. Only if it fits in the sitting; otherwise list it as a follow-up.
  - **qa:** no stacking (minimum pair distance over a seeded wave sim), telegraph/hit match, wave sim clean, DoD.
- **Slice 5 brief and sub-steps (reference, done):**
  - **Owner sequence:** gameplay-dev (spawner, enemy fixes, bar rendering) -> ux-designer (bar visibility/size options) -> qa (incl. bot-sim) -> playtester (compare bar options, density screenshots) -> game-lead (pick bar default, close).
  - **GDD:** §1 density principle, §7.
  - **Sub-steps (game-lead, 2026-10-28):**
    - [x] **5a, gameplay-dev:** BUILT 2026-10-28 (3af4538..8e05395, 365/365, soak OK). Waves `data/waves.json` (cap 12, 4 stages), enemy wedge/lane telegraphs, 1.5 s spawn grace, depth-tested bars (1.4x0.19 -> 1.2x0.16), golem capsule hurtbox (N1), enemy team tint (D3-A), arena walls, `tools/run_wave_sim.ps1`. Director: D6 (golem wind-up). Follow-ups F-E2 (thin roles), F-E3 (no separation steering), F-E5 (stun cancel cue). qa at 5c.
      criteria 1-3 and 5. Also:
      - Rendering side of criterion 4 (bar depth/priority).
      - N1: per-enemy reach for ground shapes vs the golem box hurtbox, or a capsule hurtbox.
      - D3 default A: team tint for shots, so enemy shots look different from player physical shots. Code in `ElementVisuals`, colour in data.
      - Reuse the physics query in `Player._attack_has_target` if profiling at the new density shows a cost.
      - s1-f: first contact about 1 s after spawn; add a spawn grace.
    - [x] **5b, ux-designer:** BUILT 2026-10-28 (058d3dd..642b1ee, 378/378, soak OK). Bar modes as data (shipped value still `always_alive`; director call D7), damage numbers ~12 -> ~20 px with merge/cap 16, IMMUNE above bars, cone/heal/dash/projectile reads in data, stun-cancel ring. Follow-up (5-a): the player's damage-taken numbers look like damage dealt (needs a caller change, gameplay-dev, later). qa at 5c.
      bar visibility modes as data (criterion 4). Also:
      - S3B-2: the IMMUNE popup is drawn above HP bars.
      - Damage numbers readable at 720p (old follow-up (e), playtest should-fix).
      - Pointy Stick / neutral projectile clearly visible.
      - s4-c: cone sweep duration moves to data, with the cone, heal sparkle and dash trail reads strengthened.
      - s4-b: golem occlusion of ground shapes (cheap fix or a note).
    - [x] **5c:** qa FAIL c13a43a (`docs/reviews/2026-10-28-polish1-slice5-qa.md`): blocker S5-1 (old bot-sim broken since 058d3dd, and it still printed OK). One intentionally red test until it's fixed. **Fix pass (gameplay-dev) done e100f09..2669d26, 416/416, bot-sim fixed, golem wind-up 0.7 s (D6-A).** qa re-check PASS 45ae002 (417/417). Playtester in progress. Items were: S5-1, S5-2..S5-7, S5-10, D6 default A, README CR bytes (S5-8), untracked .uid files. Then the qa re-check -> playtester -> close. Original line: qa (incl. bot-sim at the new density) -> playtester -> game-lead picks the bar default and closes.
  - **Also in this slice:** (s4-b) tall golems occlude ground shapes; (N1) ground shapes understate hit area vs FireResistantGolem box hurtbox (~20-30 cm short; per-enemy reach or accept); s3-g (enemy HP bars clump into an unreadable cluster in crowds), s1-f (first contact ~1 s after spawn).
  - **Files likely touched:** `src/enemies/EnemySpawner.gd`, new wave table data (e.g. `data/waves.json`), `src/enemies/Enemy.gd`, `scenes/enemies/*.tscn`, `src/ui/EnemyHpBar.gd`, `assets/shaders/enemy_hp_bar.gdshader`, `data/ui.json`, `tools/bot_sim.gd`, tests.
  - **Acceptance criteria:**
    1. Spawner holds about 6 to 15 simultaneous enemies, waves arrive in stages; cap and wave table are data.
    2. Each enemy type reviewed against the density principle (clear telegraph, distinct role, punishable window); findings in DECISIONS.md; cheap fixes done, rest listed as follow-ups.
    3. Enemy damage checked against player HP and the dodge i-frame window; numbers reported, adjustments proposed, any balance change logged.
    4. HP bar visibility default re-evaluated (always / after damage / hidden at full / always for elites+bosses) as a data config value. Bars depth-tested or otherwise not drawn over unrelated models, slightly smaller, consistent on-screen size.
    5. Headless bot-sim at the new density: report crashes, NaN, soft locks.
  - **qa tests:** spawner cap never exceeded; wave staging from data; bar config modes; bot-sim clean.
  - **playtester:** screenshots comparing bar options at the new density; a wave screenshot; explicitly say whether any single enemy feels unfair or unreadable. game-lead picks and logs the bar default.

- [x] **Slice 6: Hold-to-preview casting and a minimal settings screen (director D2 = C, 2026-10-28)** - **Done** 2026-10-28 (game-lead). 6a + 6b built; qa FAIL 957fa16 -> fix pass -> re-check PASS 57be0a1 (542/542); tech-writer docs pass 6f67367..af47c91. The playtest folds into the pass close-out.
  - **GDD:** §3 "Hold-to-preview casting [DIRECTOR DECISION, 2026-10-28]", §4. DECISIONS 2026-10-28 "Answers to D1-D7".
  - **Owner sequence:** 6a gameplay-dev -> 6b ux-designer -> 6c qa -> playtest folded into the pass close-out -> game-lead.
  - [x] **6a, gameplay-dev:** BUILT 2026-10-28 (37c42b6..4f5220e, 495/495). Settings store + `Settings` autoload, `CastInput` latched in `_unhandled_input` (s3-j closed), `CastPreview` sized via VfxSizing, `GamePause` with Juice freeze/thaw, `cast_preview` scenario. qa at 6c.
   
    - Card slot input becomes press / hold / release. In `release` mode (default), pressing starts a preview and releasing casts.
    - Cancel rules: releasing while the slot isn't ready doesn't cast. Death, the Game Over screen, or the settings screen opening cancel the preview. Only one preview at a time; pressing a second key switches to it. Dead-card swap (Ctrl+N) is unaffected.
    - In `press` mode, behaviour is exactly as today.
    - The preview shows the exact hit area for every aimed shape, sized via `VfxSizing` from the same data as the hitbox: cone wedge, aoe disc (centred where it really lands), projectile lane, dash path. Non-aimed cards (heal, buff) show a small self ring or nothing; log which.
    - The preview follows the aim live.
    - Settings store: defaults in `data/settings.json`, user overrides in `user://settings.cfg`, validated, with a getter API for the UI. The setting key is `cast_trigger: "release" | "press"`.
    - Input latched in `_unhandled_input` so UI screens can consume clicks and keys (also closes follow-up s3-j).
  - [x] **6b, ux-designer:** BUILT 2026-10-28 (efaf164..567cdc4, 512/512, soak OK). Esc settings screen, preview in player element colour drawn over enemies and dimmed when not ready, D7 applied, player occlusion silhouette. qa at 6c.
   
    - A minimal settings screen: Esc pauses and opens it. One toggle, "Cast cards on: Release (preview) / Press", plus Resume. Keyboard and mouse, readable, dry tone.
    - The preview look is distinct from the cast effect and from enemy telegraphs: an outline in the player's element colour, low fill.
    - **Apply D7:** set `hp_bars.visibility_mode` to `elite_boss_always`.
    - **Player occlusion cue (from 5d):** when enemies hide the player in the iso view, show a silhouette or outline of the player through them (e.g. a second material pass that draws only where the player is occluded). Colour and alpha go in data. It must not show when the player is visible.
  - [ ] **6c, qa:** FAIL 957fa16/0d670df (`docs/reviews/2026-10-28-polish1-slice6-qa.md`): blockers S6-1 (attack latch survives a pause) and S6-2 (dash coasts about 8.1 m against the previewed 4.0 m). **Fix pass done** 17b28a2..dcdb043 (540/540). Dodge is now 3.5 m and the dash 4.0 m, both frame-rate independent. qa re-check PASS 57be0a1 (542/542). tech-writer docs pass next, then close. Follow-up (6-a): the enemy shot lane tip also understates, so apply `projectile_lane_length` padding in the capture-tooling task. S6-4 (seeded sims don't repeat) moves to the capture-tooling task. (also: the 5d re-check of S5d-1, S5d-2, F1, F3, which must PASS before 5d closes)
    - Preview size equals hitbox size for every shape.
    - Release casts exactly once; press mode casts on press.
    - No cast while on cooldown.
    - Cancel cases: death, settings open, switching key.
    - The settings value persists across reload.
    - A bad settings file fails loud and falls back to defaults.
    - Pausing restores time correctly.
    - DoD.

- [x] **Docs pass (tech-writer, first job):** Done 6f67367..af47c91 (ARCHITECTURE.md 212 lines, README commands verified, ASSETS filled: gdUnit4 MIT, the rest project-authored or unverified). create `docs/ARCHITECTURE.md` (about 400 lines max, links not code); verify the README commands by running them; fill `docs/ASSETS.md` from the repo, marking anything unverified; add CHANGELOG entries for the Slice 6 fix pass and the tech-writer [Director decision]. It runs after the Slice 6 qa re-check, and Slice 6 closes after it.

- [x] **Tooling: true-size capture (gameplay-dev, before pass close-out)** **DONE 2026-10-29** (docs pass 4c7b490). BUILT 2026-10-28 (c4a3747..7a372b9, 552/552): `-TrueSize WxH` via `tools/VpCapture.tscn` + `WorldRef`; dodge in `data/player.json` (D8 B applied, so C1-a sets C); seeded sims repeat exactly (`--fixed-fps 60`, hit-stop off in the wave sim); enemy lane tip padded. **qa PASS b5a796a (552/552)** (`docs/reviews/2026-10-28-polish1-tooling-qa.md`). Closes with C1 after the C1-h docs pass (README capture/sim sections are stale until then: `-TrueSize`, fixed-fps, `run_bot_sim -Seed`). Non-blocking follow-up: `Main.gd:74` and `GameOverScreen.gd:26` still use `current_scene` (restart-after-death won't work inside VpCapture; normal play unaffected).
  - The OS window is clamped to the monitor (1061 px tall), so `capture_screenshot.ps1` can't produce real 1920x1080 / 2560x1440. qa's `tools/vp_capture.gd` (88732cf) renders into an oversized SubViewport but `current_scene` is null there, so spawner/card code errors ("add_child on null") and no waves spawn; abrupt exit leaks RIDs.
  - **Also in this task:** D8 (dodge distance; default B = `dodge_speed` 14 -> 28, same 0.25 s) with dodge values (`dodge_speed`, `dodge_duration`, cooldown, `DODGE_BLOCK_TICKS_AFTER_PAUSE`) moved from Player exports into data; S6-4 (seeded wave sims don't repeat: card shuffle RNG, status RNG, Juice wall-clock hit-stop) and the README reproduce claim; follow-up 6-a (enemy shot lane tip padding); `tools/run_bot_sim.ps1` passes a `-Seed`; the stale header comment in `src/enemies/Enemy.gd` (per-scene exports -> `data/enemies.json`).
  - **Acceptance:** a documented command produces true-size PNGs at 1280x720, 1920x1080, 2560x1440 with waves spawning and scenarios working; no error lines; spawn code uses a world/arena reference instead of `get_tree().current_scene` where needed (no behaviour change in normal play); clean exit. qa verifies; reload soak still clean.

- [x] **Content slice C1: Fire Rogue card expansion and unique-card minimums (director request 2026-10-28)** **DONE 2026-10-29**: qa PASS 76bca75 (696/696), playtest d94676a (no blocker), docs pass 4c7b490. Tag `playtest-2026-10-29-C1`.
  - **Order:** this was queued "after the current slice closes, ahead of Slice 5". Slice 5 had already closed, so C1 runs right after the tooling task (the one in flight) and before the pass close-out. The close-out playtest then covers C1. The reasoning is in OPEN_ITEMS (D12).
  - **GDD:** §4 "Shuffle bag" and "Unique-card minimums [DIRECTOR DECISION, 2026-10-28]", §15 "Slot cooldown reset effects [IDEA]", §3 (cards beat basic attacks), §7. The full director text is in the 2026-10-28 request (Parts 1-7). Number values are [PROPOSED] and get tuned to the card rule.
  - **Owner sequence:** C1-a, C1-b1, C1-b2, C1-c (gameplay-dev) -> C1-d (story: names and flavor) -> C1-e (ux-designer) -> C1-f (qa) -> C1-g (playtester, merged with the pass close-out report) -> C1-h (tech-writer) -> game-lead closes.
  - [x] **C1-a, deck rules plumbing (gameplay-dev):** BUILT 2a985e4..73c8e72 (571/571, soak OK). Shuffle bag bug fixed; dodge 28 -> 20; recovery cooldown unchanged. Shipped deck short Movement 2/3, Recovery 2/3, so run start warns for now (DECISIONS). qa reviews in C1-f. Flaky tests to investigate in C1-f: `pause_6a_test > test_a_hit_stop_that_ended_during_the_pause_does_not_come_back` (fails intermittently on baseline too) and `slice6_qa_test > test_f1_same_seed_crowd_is_bit_identical...` (failed once in a full run).
    - `data/deck_rules.json`: global `min_unique_per_slot` 3, optional per-slot `min_unique`, optional `slot_groups` [{name, slots, min_unique_total}]. Shipped with no overrides and no groups.
    - Validation fails loudly when a group minimum is below the sum of its members' minimums, when a slot name is unknown, or when any minimum is <= 0.
    - One reusable checker returns per-slot and per-group counts and shortfalls, with clear messages (e.g. "Utility needs 5 unique cards, deck has 4", "Attack group needs 10, has 8"). It is used by:
      - deck validation at run start: the preset deck now, loadouts later;
      - a reusable `can_remove(card)` / `can_swap` guard for future in-run removals;
      - content validation per class + element + neutral.
    - The F3 overlay shows counts ("Movement 4/3", plus the group line only when a group exists), with shortfalls highlighted. Expose the data; ux styles it in C1-e.
    - Shuffle bag: verify the current behaviour, fix it if needed, add the no-back-to-back rule across a reshuffle, add tests, and log what you found.
    - Test fixture with the director's example (attack group of 10, 3 per attack slot, utility 5, movement 3, recovery 3). Shipped data stays at 3 per slot.
    - **D8 = C (director):** dodge about 5 m. The tooling task applies default B (`dodge_speed` 28, 7 m) and moves the dodge values to data. C1-a changes the data value to 20 (20 x 0.25 s = 5.0 m) and updates tests. If the tooling task didn't land the data move, do it here.
    - Recovery gets the longest base cooldown: check `data/slot_types.json`, check no other slot's default effective cooldown is longer, and log old/new.
  - [x] **C1-b1, generic capabilities part 1 (gameplay-dev):** BUILT 4236e5a..87dbb87 (596/597; the one failure is the pre-existing pause_6a test). Data shapes are in the hand-back summary in DECISIONS. ux note: Bleed/Regen/Leech cues need code (`StatusDatabase.VISUAL_KINDS` only allows flame/stars). Rerun the seeded sims once C1-c cards use `hits`/`chance`.
  - [x] **C1-t, test gate repair (qa, inserted 2026-10-28):** DONE da1115a, 597/597 in 3 of 3 full runs (`docs/reviews/2026-10-28-c1t-test-gate.md`). pause_6a was a test-timer bug (ignore_time_scale timer counts the scale-change frame 10x); slice6 crowd test now runs with hit-stop off and asserts time_scale 1.0 per tick. Follow-ups: harden `attack_meter_test > test_meters_track_player_and_heavy_ready_state` (seen flaking once) in C1-f; `Main.gd:70` Game Over timer fix goes into C1-b2; enemy movement changes under `Engine.time_scale` despite a fixed delta (investigate with the enemy AI pass, not now). Original brief: `pause_6a_test > test_a_hit_stop_that_ended_during_the_pause_does_not_come_back` fails every time when its suite runs alone (on the baseline too). `slice6_qa_test > test_f1_same_seed_crowd_is_bit_identical...` drifts about 1e-4 in some full runs. Find the cause. Fix the tests if they're wrong; if game code is wrong, report it for gameplay-dev. Goal: a green, repeatable suite before C1-b2.
    - `chance` on `apply_status`, reusing the 3b element-chance code.
    - `hits` and `hit_interval` on cone, aoe and projectile.
    - Bleed status: physical DoT that ignores elemental resistance and refreshes rather than stacking.
    - Regeneration status: heal over time.
    - Lifesteal timed modifier: a single "damage dealt" event covering every source, with a per-hit cap.
    - All in data.
  - [x] **C1-b2, generic capabilities part 2 (gameplay-dev):** BUILT 4b1820a..5fbc715+uid (630/630, reload soak OK). The `zone` and `pass_through` templates; dash `direction_mode` and path damage; aoe `max_range` placement; Game Over beat counted from usec ticks with pause excluded; dodge fallbacks set to 20. Finding: player and enemy bodies never collided, so pass-through was a no-op. Resolved in C1-c (game-lead call, DECISIONS 2026-10-29). (also: `Main.gd:70` Game Over wait counts from `Time.get_ticks_msec()` instead of an ignore_time_scale timer, from C1-t)
    - Zone template: circle or line; size, duration, tick, damage and status chance; placed at a point within a range cap; pooled, capped and self-cleaning; safe if the caster dies.
    - Dash path damage: each enemy is hit once, using the shared query.
    - Dash `direction_mode` `forward` | `away_from_aim`.
    - Pass-through buff: disables player-vs-enemy body collision, restored on end, death or reload.
    - Placed skills use a reticle clamped to the range cap (data exposed for ux).
    - Align the dodge fallbacks to data: the `PlayerConfig.gd` default dict and the `Player.gd` export go from 28 to 20; update any test that pins 28 (added 2026-10-29). Rerun the reload soak (Main and Player change).
  - [x] **C1-c, cards (gameplay-dev):** BUILT 87ede1f..de9f916 (666/666; all gates clean). Balance table in DECISIONS. Solid enemies are on (HP lost about 2x in the sim; the playtester judges it). Capture scenarios not re-run after warn -> block (qa checks them in C1-f).
    - Cards: `rogue_bleed_slash`, `rogue_flurry`, `fire_fireball` (reuses `targeted_aoe`), `fire_wall` (line zone), `rogue_shadow_step` (pass-through only), `rogue_lunge_strike` (about 3.0 m with path damage), `neutral_backward_leap` (about 6-7 m, away from aim), `neutral_leech`, `neutral_regeneration`. Give them placeholder names.
    - Neutral cards must not reference class or element data.
    - Tune the numbers to the card-beats-basic rule, and put a balance table in DECISIONS.
    - The preset deck contains all Fire Rogue cards.
    - Content validation passes at 3 per slot (fixes Movement 2/3 and Recovery 2/3 from C1-a).
    - Then switch the run-start deck check from warn to block (fail loud), and delete the tripwire branch in `test_shipped_content_meets_the_minimums_PENDING_C1C`.
    - **Solid enemies (game-lead call 2026-10-29):** new data flag `data/player.json` `body.collide_with_enemies` (default true, validated) that turns on player-vs-enemy body collision both ways, so Shadow Step's pass-through means something. The dodge does NOT pass through bodies (escaping a crowd is the Movement cards' job, per D8). Guard against soft-pinning: separation steering keeps working, and enemies must not shove the player through arena walls. Rerun the seeded wave sim and report before/after HP lost and any stuck frames. False restores today's feel.
    - Rerun the seeded sims now that cards use `hits`/`chance` (C1-b1 note). Report numbers.
  - [x] **C1-d, story:** DONE 1b35908 (9 card names and flavor, plus 3 status flavor lines; the JSON parses; no test pins the names). names (25 characters or fewer) and flavor (80 characters or fewer) for the 9 new cards, in the dry weary-hero voice. Data text only.
  - [x] **C1-e, ux-designer:** BUILT 16eecd9..353070f (688/688 on 3079dc7; the last commit ran only the targeted suites). Bleed, Regeneration and Leech cues; the Shadow Step ghost; the Fire Wall timer; dash arrowheads; the range reticle; F3 styling; names fit at 720p/1080p/1440p. New scenarios: c1_status, c1_status_crowd, c1_placed, c1_placed_near, c1_moves, c1_names, c1_overlay.
    - Readable visuals via the shared VFX for Fireball (telegraph and burst), Fire Wall (line plus a duration indicator), Bleed, Regeneration, Stealth (ghosted player), Lunge, Backward Leap and Leech (drain plus heal cue).
    - Range-clamped reticle for placed skills.
    - F3 counts styling.
    - Names fit the HUD.
    - Visuals match hitboxes.
  - [x] **C1-f, qa:** PASS 76bca75 (696/696; soak extended to zones and pass-through; `docs/reviews/2026-10-29-c1f-qa.md`). Non-blocking N1-N6; N3 (bot-sim charter checks) goes into M3a. Docs inputs go to C1-h. everything in the director's Part 5, plus the README and CHANGELOG checks.
  - [x] **C1-g, playtester:** DONE d94676a (`docs/playtests/2026-10-29-c1-and-polish1-closeout.md`). Smoke PASS; no blocker; keep solid enemies on. the director's Part 6, merged into the pass close-out report.
  - [x] **C1-h, tech-writer:** DONE 4c7b490 (also covers the tooling task). the docs pass (ARCHITECTURE adds deck rules, the example config and the new templates; README; CHANGELOG).

- [x] **Pass close-out:** DONE 2026-10-29 (C1-g report covers the whole pass). **Post-milestone polish 1 is closed.** (Original: whole-pass playtester report, DoD verified, STATE points at 3a.)

- [ ] **Backlog (C1 and 3a playtests, qa follow-ups) (not scheduled; small UX/content items, game-lead picks them up between M3 slices if cheap):** real-cast C1 scenarios in `data/scenarios.json`; a brief card-name pop-up on cast; a stronger Bleed cue and four distinct Flurry flashes; a brighter enemy projectile and stronger player outline in dense crowds; the Lunge preview shows the full path even when a body stops it; `Main.gd:74`/`GameOverScreen.gd:26` use `current_scene` (qa N5); bot-sim charter checks (qa N3, done in 3a). From 3a: keep elites from spawning under the card row; the LOST line shows a stale HP; the `--run-room` win count; run-mode sim results depend on earlier runs in the same process; +1 object per soak cycle; `-RoomTimeout` clamps silently.

## Later (director, 2026-10-28)
- Stealth makes enemies drop aggro (GDD §15 "Stealth drops enemy aggro [PLANNED, later]"). Do it with the enemy targeting/AI pass.

## Milestone 3 — Card system and run loop
Director run order 2026-10-29: start right after C1 and Polish 1 close; one slice at a time, each with the full loop (build -> ux where seen/clicked -> qa -> playtester -> tech-writer docs pass -> game-lead close), then a `playtest-YYYY-MM-DD-<slice>` tag. GDD §2, §4, §5, §7, §9, §13. No art, audio, passive tree, Wizard or Water.
**Coupling rule for every M3 slice:** run-loop code must not know specific cards. It handles card ids, slot types and pools through the existing deck/card APIs, so a card-system change after the director's vision check doesn't strand it.

- [x] **3a, run structure** — **DONE 2026-10-29.** Gameplay a7731e2..c560d83; ux 8b54b25..0f4e317; qa PASS a6a5d68 (766/766); playtest 013e7d7 (no blocker); docs 15250c4. Tag `playtest-2026-10-29-3a`. The playtest found the boss room drags (65-98 s, fixed by 3c) and no attrition (3b starter shrink plus D13); the next-room preview and the rest text are in 3b.
  - **Goal:** a run is a seeded sequence of rooms you fight through, carrying your state, ending in a win or a loss.
  - **Acceptance:**
    1. **Run generation:** seeded generator builds a room sequence from data (`data/run.json` or similar): room count, the type mix and placement rules. Types: `combat`, `elite`, `rest` (placeholder: heal a data % of max HP, or a "deck-clean coming in 3b" note), `boss` (placeholder until 3c: a beefed-up elite). The same seed gives the same sequence.
    2. **Rooms:** each combat, elite or boss room has a finite wave list in data (reusing the existing spawner and wave schema where possible). A room is won when its waves are done and no enemy is alive. Elites use 25% resistance across elements (GDD §7). Schema validation fails loud.
    3. **RunState:** one object holding HP (current and max), deck (card ids), rejects remaining (3, data), seed, room index and room history. It survives room transitions. It serializes to and from a Dictionary/JSON (round-trip test). Nothing in it is card-specific.
    4. **Transitions:** a won room shows "Room cleared" and a Continue button (3b replaces it with the reward screen), then loads the next room with state carried over. Slot cooldowns and the shuffle bag reset per room. HP carries over.
    5. **HUD:** a minimal "Room X of Y" indicator (with the room type) (ux-designer).
    6. **End screens:** a placeholder win screen after the last room. The lose screen reuses the existing death and Game Over flow. "Try again" starts a new run with a new seed (and the same deck rules).
    7. **Bot sim:** the sim plays whole seeded runs headless and reports crashes, NaN, soft locks (a room that never ends), rooms reached, the win or loss, and the room-type distribution across N seeds.
    8. **Hygiene:** test scenarios and the capture tool still work. Zero errors on startup and in the 20 s headless run. Full suite green. Reload soak clean. SceneSelfCheck passes.
  - **Also in 3a (game-lead, 2026-10-29):**
    - **Normal launch vs scenarios:** a normal launch starts a run with finite room waves. Capture scenarios and `wave_sim` keep the current endless arena (`loop_from_stage`), and their seeded baselines must not change.
    - **Starting deck from data:** RunState takes its starting deck from a data list (`data/run.json` `starting_deck` or similar, validated by the deck rules). Ship it as the full Fire Rogue pool, as now. 3b will shrink it to a starter subset (the full pool would make every reward a duplicate). Keep a way to get the full deck (a scenario or debug flag).
    - **RunState lifetime:** if it is an autoload or a static, the reload soak must cover a mid-run reload and "Try again after death starts a fresh RunState with a new seed". No state may leak across runs.
    - **qa N5:** replace `get_tree().current_scene` in `Main.gd:74` and `GameOverScreen.gd:26` with the WorldRef path. Room transitions must work inside VpCapture.
    - **Elite resistance:** each element = max(the enemy's own value, 25%), capped at 50% (GDD §7). Elites are existing enemy types with a data HP multiplier and a visible marker (ux).
    - **Bot sim:** add qa's N3 charter checks: empty deck, stuck cooldown, pick-rate outliers per card.
  - **Files likely touched:** new `src/run/` (generator, RunState, room controller), `data/run.json` and room/wave data, `src/main/Main.gd`, the spawner, new HUD bits under `src/ui/`, `tools/bot_sim.gd`, and tests.
  - **Defaults (game-lead calls, logged in DECISIONS and "Calls I made"):** a linear sequence, no branching map (routing comes later); 8 rooms (5 combat, 1 elite, 1 rest, 1 boss last); rest heals 30% of max HP; short prototype runs (GDD §9 [PROPOSED]).

- [x] **3b, reward screen and deck-clean** — **DONE 2026-10-29.** Gameplay fd2f644..b8564cd; ux 56a76f0..d2cd00a; qa PASS 0a19808 (826/826); playtest f2a3283 (no blocker; attrition is real now, mean room-end HP about 85%); docs 16deeb2. Tag `playtest-2026-10-29-3b`.
  - **Goal:** after each won room you choose how your deck grows: pick 1 of N cards or reject the whole offer. Rest rooms let you trade the heal for removing a card. GDD §4 (deck rules, unique minimums), §5 (pools), §9 (rewards), §15 (the level-up idea reuses the screen).
  - **Acceptance:**
    1. **Offer:** after every won combat or elite room (not the last room, and not the rest room) the reward screen offers `offer_size` cards (data, default 3; distinct within an offer). Seeded from the run seed and room index, so the same seed gives the same offers.
    2. **Pools:** offers come only from the character's pools (class + element + neutral, read from data, never hardcoded). Cards that "do nothing for the build" are filtered by a generic data hook: an optional card field `requires` (for example a slot type the character lacks, or a status source), checked against the current deck and character. No shipped card needs it yet, so test it with fixtures. Weighting: cards not yet owned are preferred (data weight); duplicates are allowed (D10).
    3. **Pick or reject:** picking adds the card to RunState's deck. Rejecting spends 1 reject (`rejects_per_run` 3 from RunState). At 0 the Reject button is disabled with the reason shown. The rejects left are visible on the screen.
    4. **Deck-clean at rest rooms:** the rest room offers two options: heal (30% of max HP) or remove 1 card. Removal goes through the existing `can_remove` guard: cards that can't be removed are shown disabled with the reason (e.g. "Utility needs 3 unique cards"). No removal can break a slot minimum (tested).
    5. **Generic screen:** one reusable choice screen built on RunPromptScreen's `options_box`. It takes a list of options of any kind (card, remove, heal, skip), so level-up choices can reuse it later. Card options show name, slot, flavor and a short effect line. Keyboard (1-N, Enter) and mouse both work.
    6. **Starter deck shrink:** `data/run.json` `starting_deck` becomes 15 cards, 3 per slot (below). The full pool stays reachable with the launch arg `--full-deck` (and in scenarios), so every card is still testable by hand.
    7. **Room-cleared panel fixes from the 3a playtest:** a "Next: Room N of 8 - Type" line with its shape, and a rest-room text that doesn't say "Healed +0".
    8. **Bot sim:** picks rewards (a seeded simple policy), uses rejects and deck-clean, and reports deck size and composition at run end, plus HP at each room end. Soft-lock and N3 checks still pass.
    9. **Coupling:** reward and run code handles card ids and pools only, never specific card content.
    10. **Gates:** suite green; zero errors on startup and in the 20 s headless run; reload soak clean (mid-reward reload, Try again from a reward state); SceneSelfCheck; capture scenarios unchanged.
  - **Starter deck (game-lead call):** the original Polish starters plus one escape card and one regen card, 3 per slot:
    - single: Quick, I Guess; Overhand, Whatever; Ember, Whatever;
    - aoe: Fine, Burn Then; Everyone Calm Down; Shrug Bomb;
    - utility: all 3;
    - movement: Blaze and Bail; Ugh, Fine, Moving; Nope, Leaping Away (the escape, needed with solid enemies);
    - recovery: Healing Potion; Nap Time; Eventual Healing.

    Reward-only at start: Flaming Nonsense, Pointy Stick, Slash Then Bleed, Four Quick Stabs, Fireball, Wall of Mild Fire, Walk Through Everyone, Reluctant Lunge, Heal By Hurting.
  - **Known limit:** Utility has exactly 3 cards in the whole pool, so it can never be cleaned or grow until more Utility cards exist. Accepted for the prototype.
  - **Owner sequence:** gameplay-dev (logic, data, a placeholder screen) -> ux-designer (the choice screen) -> qa -> playtester -> tech-writer -> close, tag `playtest-2026-10-29-3b`.
- [ ] **3c, boss encounter** — gameplay BUILT a35501d..2234dc8 (875/875; bot boss fight mean 61 s, 8/8 won); ux BUILT b8af93f..5245779 (894/894, including the 3b follow-ups); qa PASS 64df947 (903/903). playtester running. **Director feedback 2026-10-29 (first hands-on run):** the reward selection scrolls by default (window about 1150x680; cards clipped at the top, scrollbar). Fix before the 3c tag (ux-designer): reward offers fit with no scrolling down to about 1024x600, scroll stays only on the removal grid, tests pin it.
  - **Goal:** the last room ends the run with a real fight: one boss with readable phases and telegraphed attacks, replacing the 3a placeholder (a golem with HP x7). GDD §7 (final boss: 50% resistance to every element, equal), §11 (telegraphs, feel).
  - **Acceptance:**
    1. **Data-driven boss** (`data/bosses.json` or a `boss` block in `data/enemies.json`, schema-validated): HP, move speed, 50% resistance to every element (physical ignores resistance as usual), and a phase list with HP thresholds (default 3 phases: 100-66%, 66-33%, 33-0%).
    2. **Attacks:** an attack list per phase, each built from existing shared shapes (cone, ground disc/aoe, lane or projectile volley, charge along a lane), parameterised in data: wind-up, damage, size, cooldown and weight. At least 3 distinct attacks. Every attack shows a telegraph in the existing enemy telegraph language for at least 0.6 s (data). Visuals match hitboxes (`VfxSizing`, tests).
    3. **Phases:** crossing a threshold triggers a short, readable transition (a brief invulnerable roar or flash, max 1.5 s, data) and changes the pattern: new attacks and/or faster cadence. Optional: the phase may summon a few normal enemies (data), capped well under the room cap.
    4. **Fairness:** the boss can't be stunned (or stun is heavily reduced; data). No attack is undodgeable: each one can be escaped by walking or with the 5 m dodge given its telegraph. Pinning against solid bodies must not trap the player (it pushes, or the boss isn't solid while charging; pick one and test it).
    5. **HUD:** a boss HP bar (name, phase pips at the thresholds) at the top of the screen while the boss lives (ux-designer). The room indicator keeps working.
    6. **Pacing target:** for the sim bot with the 15-card starter plus about 4 rewards, the boss room takes 45-75 s, and the bot wins in most seeds without god mode. Report the numbers.
    7. **Feel:** hit-stop and shake on its big hits, a heavier screen shake on phase change, knockback the player feels, and a death beat (slow-mo plus burst) on the boss's death before the win screen.
    8. **Gates:** suite green; zero errors on startup and in the 20 s headless run; reload soak clean (reload during the boss fight and during a phase transition); SceneSelfCheck; capture scenarios unchanged; the wave-sim arena hash unchanged. Add a `boss` capture scenario (9999 HP) so each attack can be screenshotted.
  - **Defaults (game-lead calls, logged):** the boss is a big capsule (a primitive placeholder, roughly 2x scale with a matching hurtbox); name "The Overly Enthusiastic Guardian" (placeholder; story may rename it later); 3 phases; no boss quips (story is dormant).
  - **Folded into the 3c ux step (3b playtest and qa follow-ups):**
    - offer cards show what you already hold in that slot ("Slot 1 now: A, B, C");
    - the removal-locked reason says what to do ("Own a 4th Utility card first");
    - plain-language effect lines with units ("dash 6.5" -> "Dash 6.5 m");
    - the Reject tile title doesn't wrap;
    - the 1440p panel top doesn't overlap the HP label;
    - the Continue / New run button gets the arm delay, and its hint drops "Space".
    - Gameplay side: `RunState.from_dict` rejects an unknown `pending`; the choice model carries `owned` and `next_room_type`.
  - **Owner sequence:** gameplay-dev -> ux-designer (boss bar, telegraph readability) -> qa -> playtester -> tech-writer -> close, tag `playtest-2026-10-29-3c`.
- [ ] **3d, loadouts**
  - **Goal:** from the second run on, you can build a starting deck, save it as a loadout and start runs with it. GDD §9 ("Starting decks and loadouts [DECIDED]"), §4 (deck rules).
  - **Acceptance:**
    1. **Profile:** a small persisted profile (`user://profile.json`, versioned, validated) counts finished runs (won or lost). Run 1 starts straight away with the preset (today's behaviour). The path is injectable so tests never touch the real user folder.
    2. **Start screen (from run 2):** before a run, a screen offers: Start with the preset; start with a saved loadout; edit or create a loadout. The last-used choice is preselected, so one Enter starts a run. Try again and New run go to this screen from run 2 on.
    3. **Loadout editor:** pick cards from the available collection into a deck, grouped by slot, with live deck-rule counts ("Movement 4/3") and the exact shortfall messages from the existing checker. Saving is blocked while the deck breaks a rule, with the reasons shown. Name and save it.
    4. **Rules (data, `data/loadouts.json` or a `loadouts` block in `run.json`):** collection = every card in the character's pools; at most 2 copies per card; deck size from the deck-rule minimum (15 today) to 20; 3 loadout save slots.
    5. **Persistence:** `user://loadouts.json`, versioned. A corrupt, outdated or rule-breaking file never crashes or blocks a run: bad loadouts are flagged and skipped with a message, and the preset is always available.
    6. **Run start:** the chosen deck goes into RunState through the existing validation (the run-start block still applies). `--full-deck` and the debug args still work. Scenarios and sims are unaffected (they ignore the profile).
    6a. **Save robustness (from 3c qa):** `RunState.from_dict` must not crash on wrongly-typed `offer`, `deck` or `choice_log` entries (use `str()` or validate types); clear a stale `offer` when `pending` is empty; `BossConfig.validate` must not throw a script error on a non-object attack (qa repro: `attacks.smash = "hit"`); remove the unused `tiers.boss` from `run.json`.
    7. **Coupling:** loadout code handles card ids, slots and pools through the deck APIs only.
    8. **Gates:** suite green (round trips, a corrupt file, rule enforcement, run-count gating, the injectable path); zero errors on startup and in the 20 s headless run; reload soak clean; SceneSelfCheck; capture scenarios and the sim hashes unchanged.
  - **Defaults (game-lead calls, logged):**
    - Every card in the character's pools is available. Unlock rules are [OPEN] and come with meta-progression.
    - At most 2 copies per card.
    - Deck size 15-20.
    - 3 save slots.
    - A finished run counts whether it was won or lost.
  - **Owner sequence:** gameplay-dev (profile, storage, rules, placeholder screens) -> ux-designer (start screen and editor) -> qa -> playtester -> tech-writer -> close, tag `playtest-2026-10-29-3d`. **This closes Milestone 3** except the out-of-scope items below.
- Later in M3 or after: shops and drops (GDD §14 item 1, [OPEN], not started); branching routes.

## Milestone 4 — Second class/element, subclasses, passive tree prototype, balance sim
Not started. Per GDD §13: Wizard + Water added, 2 subclasses each for Rogue/Wizard/Fire/Water, first passive tree prototype (30-40 nodes), headless balance simulation grown out.

## Milestone 5 — Art/audio pass, friends-and-family playtest
Not started.
