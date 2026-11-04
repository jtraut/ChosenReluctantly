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

- [ ] **Backlog (C1 and 3a playtests, qa follow-ups) (not scheduled; small UX/content items, game-lead picks them up between M3 slices if cheap):** real-cast C1 scenarios in `data/scenarios.json`; a brief card-name pop-up on cast; a stronger Bleed cue and four distinct Flurry flashes; a brighter enemy projectile and stronger player outline in dense crowds; the Lunge preview shows the full path even when a body stops it; `Main.gd:74`/`GameOverScreen.gd:26` use `current_scene` (qa N5); bot-sim charter checks (qa N3, done in 3a). From 3a: keep elites from spawning under the card row; the LOST line shows a stale HP; the `--run-room` win count; run-mode sim results depend on earlier runs in the same process; +1 object per soak cycle; `-RoomTimeout` clamps silently. From W1b (ux): world-space damage numbers can draw over the boss bar when the boss stands right under it; keep them below the HUD or draw them under it.

## Later (director, 2026-10-28)
- **Difficulty tiers (director 2026-10-29, confirmed 2026-10-30, GDD §9; unscheduled).** Today's tuning is the lowest tier ("Easy"); later tiers working names Normal, Hard, and a top tier like "Torment" (names open, tone-fitting ideas welcome). The director finds the opening and busy waves comfortable and would lean toward a harder run overall. Plan the tiers as data multipliers (enemy HP and damage, wave density and pacing, maybe elite and boss numbers), picked at run start. Don't retune the base game until then. **Exception (director, 2026-11-02):** the director asked for one pressure pass now (slice H1: enemy movement speed, then attack rate if needed, behind shared data knobs the tiers will reuse). It is the only exception; the tiers themselves are still unscheduled.
- **Heavy attack (director note 2026-10-29):** it feels good now. It may later be weakened or given a longer cooldown. No change scheduled.
- **Pause shows card details (director request 2026-10-29, unscheduled; ux-designer, with a small gameplay hook if needed).**
  - When the player pauses (Esc), every slot's **active card and next-up card** (including slots on cooldown) expand upward so the player can read what each card does before resuming.
  - The card frame colour (GDD §4, director 2026-10-30) is the quick family cue; this view adds the detail.
  - Show the name, the effect line (reuse `CardSummary.effect_line`, as on the reward screen), the cooldown, and the remaining cooldown for cooling slots.
  - It must coexist with the pause/settings panel and fit at 720p, 1080p and 1440p with no scrolling. It collapses on resume.
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
- [x] **3c, boss encounter** — **DONE 2026-10-29.** Gameplay a35501d..2234dc8; ux b8af93f..5245779; qa PASS 64df947; playtest 81b03d8 (no blocker); director-requested no-scroll fix 741c624..b7a6a01 with qa PASS 8bc7241 (907/907); docs b4c7a1d. Tag `playtest-2026-10-29-3c`. Backlog from the playtest: marked resisted damage numbers (A1 covers armor and resist number styles), Leech explanation, boss spawn position (starts partly off screen in room 8), adds standing on the cone wedge (outline now drawn on top).
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
- [x] **Slice A1: Armor (director request 2026-10-29; runs right after the 3c close, ahead of P-dodge and 3d)** — **DONE 2026-10-29.** qa PASS 9292e4b + delta PASS 70a761f; playtest ff6e7f6 (no blocker); docs 28587a9 (968/968). Tag `playtest-2026-10-29-A1`. Backlog from the playtest (ux): damage-number styles blur in a clump of 4+ enemies; elite shield pip hidden behind neighbours; F3 overlay covers the arena centre; boss-bar end glyphs unlabeled; D17 card damage-type cue. Sim note: physical about 1.2x fire at the boss on 4 seeds (both inside the 70-130% band); re-measure with 10+ seeds in the T-decks sim alignment step.
  - **Progress:** Part 1 BUILT b23d7df..e141dfe (923/923; elite x2.5 -> x2.0, boss 280 -> 195 HP; fire 0.93x and physical 1.11x of standard at the boss). Part 2 BUILT 1604f6b..bcf13a5 (939/939). Part 3 qa PASS 9292e4b (965/965; fire 0.93x, physical 1.04x of standard at the boss). Small ux fix done f0cb109 (N2 1024x768 overlap, 720p elite pip_scale, N1 "all elements"); qa delta PASS 70a761f (966/966). Part 4 (playtester) next. Backlog (ux, non-blocking): add `boss_bar_gap`, `boss_bar_stack_below`, `boss_bar_stack_extra` to `UiConfig.DEFAULT_HUD` or a hud validator (qa 70a761f).
  - **Goal:** elites and bosses mitigate non-elemental damage about as much as elemental damage, so no build family is singled out at the final boss. GDD §7 "Armor" [DIRECTOR DECISION, 2026-10-29], points 1-10. This resolves D15.
  - **Today (to re-verify):** `CombatMath.apply_resistance` returns physical unchanged, and `neutral` effectively skips mitigation. At the final boss, physical and neutral take 0% while fire takes 50%.
  - **Part 1, gameplay-dev:**
    1. Armor and the formula go in `CombatMath` (pure), wired into `Health.take_damage` as the single choke point for every non-elemental hit: cards, light and heavy attacks, boss attacks on the player, status ticks, and path and zone damage.
    2. **Data:**
       - `armor` on the `run.json` elite and boss tiers, on the boss in `bosses.json`, and as an optional per-enemy override in `enemies.json`.
       - K (50) and `armor_reduction_cap` (0.5) in one shared data location (log which).
       - Validators fail loud on negative armor, a missing K or K <= 0, a cap outside [0, 1], or a tier with no armor.
    3. Tier armor is validated against the tier's resistance through `armor = K*r/(1-r)`, so a test catches any drift.
    4. **Plumbing only, no content:** an `armor_penetration` stat via StatModifiers (flat, floored at 0), and a player armor stat (default 0) that enemy non-elemental hits go through.
    5. **DoT:** Bleed ticks go through armor, Burn through resistance, and heals are untouched. Check whether tiny ticks round to zero; if they do, propose a data minimum and log it.
    6. **Re-tune:**
       - With the bot sim, measure the median time-to-kill for the standard deck against an elite and the boss, BEFORE and AFTER armor.
       - Adjust only elite `hp_multiplier` and boss `max_health`, so fight lengths stay near today's (boss about 61 s).
       - No enemy-damage or player changes. Log every number.
  - **Part 2, ux-designer:**
    - The boss bar shows armor next to resistance, in the same style.
    - Elite bars get a small armor cue.
    - Armor-reduced hits get a distinct muted damage-number style, told apart from the resisted style by more than colour.
    - The F3 overlay shows the nearest or under-cursor enemy's armor and resistance, plus the player's armor.
    - All of it stays unobtrusive in a crowd.
  - **Part 3, qa:**
    - **Formula:** armor 0 gives 0% reduction; armor = K gives exactly 50%; large armor approaches but never reaches 100%; the cap applies; bad inputs are rejected.
    - **Channels:** each one affects only its own damage types.
    - **Parity test:** for each tier (elite, boss, final boss), armor reduction and resistance agree within 2 points. The test must fail when one is changed without the other.
    - **Penetration and player armor:** flat penetration floors at 0, and a player with armor mitigates enemy physical attacks.
    - **DoT:** Bleed ticks are mitigated by armor, Burn ticks by resistance, and heals are untouched.
    - **Data validation** fails loud.
    - **Bot sim:**
      - Elite and boss time-to-kill for 4 decks (fire-only, physical/class-only, light and heavy only, standard mixed), before and after armor.
      - Headline: no family kills the final boss in under about 70% or over about 130% of the standard deck's time.
      - Say what the sim can't isolate.
    - **Gates:** full suite, 20 s headless run, reload soak, SceneSelfCheck.
  - **Part 4, playtester:**
    - Fight an elite and the boss with a fire-heavy deck and a physical-heavy deck (`--full-deck`, `--run-room`).
    - Do the fight lengths feel similar? Are the armor cues readable? Do damage numbers explain the smaller hits?
    - Screenshots of each cue.
  - **Part 5, close:**
    - OPEN_ITEMS:
      - an eyes item: element-heavy vs class-heavy deck at an elite and the boss;
      - calls: K = 50, the cap, the retuned HP and the DoT rule, each with its one-line change.
    - tech-writer: README if commands changed; ARCHITECTURE (damage and mitigation flow); CHANGELOG with `[Director decision]`.
    - Close with tag `playtest-2026-10-29-A1`.
  - **Done when:**
    - zero errors on startup and in the 20 s headless run;
    - the full suite passes, including the parity test;
    - the formula and cap live in data;
    - tier armor matches tier resistance;
    - standard-deck fight lengths are retuned, with before/after numbers logged;
    - the armor cues are readable;
    - the playtest report and OPEN_ITEMS are updated.

- [x] **T-decks, debug preset decks (director request 2026-10-29; runs right after A1 closes, ahead of P-dodge; lightweight loop: gameplay-dev -> qa -> tech-writer -> close, no playtester)** — **DONE 2026-10-29.** Build 9b6e8a6; qa PASS deb6ff1; docs cddab25 (996/996). Tag `playtest-2026-10-29-T-decks`. 12-seed parity: fire-heavy 1.02x, physical 1.07x of standard. Backlog: a notice when `--deck` is ignored (scenario/arena); a sim log of deck makeup at the boss; the soak flake moved to P-dodge.
  - **Goal:** launch a run with a named preset deck and jump to any room, to test builds against elites and the boss without playing through the rounds.
  - **Acceptance:**
    1. **Preset files:** one JSON per preset in `data/debug_decks/`; the file name is the preset name. Format:
       - `name`, plus a one-line `description`;
       - `full`: the whole intended deck (card ids, duplicates allowed);
       - `starter`: a subset of `full`, about 15 cards (3 per slot), used by default.

       Adding a preset means adding one file and nothing else.
    2. **Launch:**
       - `--deck=<name>` starts with that preset's `starter`;
       - `--deck=<name> --full-deck` starts with its `full`;
       - with no `--deck`, behaviour is unchanged (`--full-deck` still means the whole character pool);
       - `--deck` combines with `--run-room`, `--run-seed` and `--full-deck`, and applies to the whole launch (Try again keeps it).
    3. **Errors:**
       - an unknown name refuses to launch and lists the valid names;
       - `--deck` given twice is an error;
       - a bad preset refuses to launch with a message naming the preset, the problem and the shortfall: invalid card id, deck-rule failure, or `starter` not a subset of `full`.
       - No rule-bypass flag.
    4. **Shipped presets** (all Rogue; the character is in the name so Wizard presets can follow):
       - `fire-heavy-rogue`: as many Fire cards as the rules allow, the rest neutral or class;
       - `physical-rogue`: Rogue and neutral physical cards, no Fire;
       - `mixed-rogue`: the current starter plus the matching full deck.

       Report how many cards of each family each preset contains.
    5. **`--list-decks`** prints the names and descriptions, then exits.
    6. **Sim alignment (gameplay-dev builds, qa measures):** the wave sim's A1 `-Deck` families (`fire`, `physical`, `standard`, `lightheavy`) bypass the deck minimums through `RunSession.skip_deck_minimums`, and they clash in name with the new `--deck`.
       - Point the sim's deck selection at the presets (`-Deck fire-heavy-rogue` and so on) and remove the bypass.
       - Keep "light and heavy only" as a separate bot attack-policy flag, since it isn't a deck.
       - Log it. gameplay-dev makes the code change; **qa** re-runs the A1 4-family comparison with the presets in its review, using 10+ seeds (it settles the fire 0.80x vs 0.93x disagreement from A1). A family outside 70-130% of standard becomes a director item.
    7. **Tests:**
       - every shipped preset loads, both starter and full, and starter is a subset of full;
       - an unknown name gives an error listing the valid names;
       - `--deck` given twice;
       - an invalid card id;
       - a deck-rule failure gives a clear error;
       - `--full-deck` with and without a preset;
       - the `--list-decks` output;
       - a normal launch with no `--deck` is unchanged.
    8. **Docs:**
       - tech-writer: one "Launch options" table in README listing every launch option, with an example each; a CHANGELOG entry.
       - game-lead: boss-room examples in OPEN_ITEMS "How to playtest".

- [x] **W1: Fire Wizard, a ranged class** — **DONE 2026-11-02** (W1a 2026-10-30, W1b 2026-11-02; see each below). (Original header: director request 2026-10-29; runs after A1 and T-decks, ahead of P-dodge and 3d)
  - **Goal:** a second playable class whose basic attacks shoot where you aim, chosen at run start. GDD §5 "Wizard moved earlier" [DIRECTOR DECISION], §3 (cards beat basic attacks), §4 (deck rules), §7 (armor and resistance).
  - **Acceptance:**
    1. **Character data:** `data/characters.json` (validated) holds the class id, display name, element, pools, starting deck, max HP, body colour and attack set per class. It replaces the hardcoded `Player.owned_pools` and `run.json` `character_pools`. Rogue's behaviour is unchanged.
    2. **Class pick at run start:** a simple screen choosing Rogue or Wizard (the element is Fire for both, since it's the only element), shown at the start of every run including run 1, with the last pick preselected so Enter starts. Plus `--class=wizard|rogue` for launches and tools, combinable with `--run-room`, `--run-seed`, `--full-deck` and `--deck`.
    3. **Ranged light attack (Wizard):** an auto-firing magic bolt (projectile template) aimed at the reticle. Clicking speeds it up, like the Rogue's. Range is about 12 m (data). Damage type `neutral` (non-elemental magic, so it goes through armor per A1). Starting numbers: ranged safety costs damage, so light DPS is about 80% of the Rogue's (logged; tuned in the sim). It must visibly fly to the reticle.
    4. **Ranged heavy attack (Wizard):** reuse the existing `heavy.wizard` (a targeted aoe at the reticle, clamped to `max_range`, with a telegraph and wind-up). Change its damage type to `neutral`, and keep the card-beats-basic rule.
    5. **Wizard cards:** a Wizard class pool of about 6-8 cards in data (no new effect templates unless unavoidable), so Wizard + Fire + Neutral meets 3 unique cards per slot. Fire + Neutral alone give Utility 2 and Movement 2, so the Wizard pool needs at least 1 Utility and 1 Movement (aim for 2 each), plus a few attack cards with a ranged or caster feel (e.g. a bolt volley, an arcane nova, a blink, a mana-shield buff). Placeholder names (story names them in a later pass, if the director activates story again). A balance table in DECISIONS. A 15-card Wizard starter (3 per slot) and a full pool for `--full-deck`.
    6. **Rewards and pools:** offers use the chosen class's pools. Rogue cards never appear for a Wizard and vice versa (tested).
    7. **Look:** the Wizard body is a different colour or shape (a primitive placeholder), so it's obviously a different character.
    8. **HP:** the Wizard has 26 max HP vs the Rogue's 30 (game-lead call: ranged safety for a slightly squishier body; data).
    9. **Readability (ux):**
       - the class pick screen;
       - the light bolt and heavy telegraph are readable;
       - the HUD shows the right attack meters per class.
    10. **Sim:** the whole-run sim supports `--class=wizard`. Report Wizard vs Rogue win rate, elite and boss time-to-kill, and HP lost on about 8 seeds. Target: the Wizard's boss time is within about 70-130% of the Rogue's.
    11. **T-decks follow-up:** add `fire-heavy-wizard` and `mixed-wizard` presets (and an arcane-heavy one if it makes sense).
    12. **Gates:** suite green; zero errors on startup and in the 20 s headless run; reload soak (including a Wizard run); SceneSelfCheck; capture scenarios; the arena hash unchanged for the Rogue default.
  - **Quick win for the Rogue, from the same playtest (ux):** a new player can't tell the light attack is melee. Consider a short-range cue (e.g. the swing arc shown faintly at the player when nothing is in reach, or a "too far" tick when clicking at a distant reticle). Its own small item; doesn't block W1.
  - **Owner sequence:** gameplay-dev (character data, class pick logic, attacks, cards) -> ux-designer (pick screen, bolt and telegraph readability, HUD) -> qa -> playtester -> tech-writer -> close, tag `playtest-2026-10-29-W1`. If too big for one sitting, split into W1a (character data, pick, ranged attacks, minimal cards) and W1b (full card pool, presets, balance).
  - **Split (game-lead, 2026-10-29): W1 is two slices, each with the full loop.**
    - [x] **W1a, a playable Wizard.** **DONE 2026-10-30.** Gameplay 0c9704e, 39fe0c6; ux 7d93d1c..672622f; qa PASS b799153; playtest b5f2e02 (no blocker); docs 031f321 (1053/1053). Tag `playtest-2026-10-30-W1a`.
      - **gameplay-dev:**
        - items 1, 3, 4, 6, 7 and 8;
        - item 2's logic and `--class` (the pick screen itself is ux);
        - a **minimal Wizard pool**: 2 Utility and 2 Movement cards, enough for Wizard + Fire + Neutral to meet 3 unique per slot, with a 15-card Wizard starter;
        - item 10's sim plumbing (`-Class wizard` runs end to end), but no balance report yet;
        - item 12's gates.
      - **ux-designer:** item 9 (the pick screen, bolt and telegraph readability, per-class HUD meters).
      - **qa, playtester, tech-writer, close.**
    - [x] **F1, director feedback batch** — **DONE 2026-10-30.** Gameplay efb0516, cef82c5; ux a1504cc; qa PASS f305fae (1102/1102); playtest 027d65a (no blocker); docs 47fde95. Tag `playtest-2026-10-30-F1`. New arena hash 3513335656. D19 open (default A). (Original header: director checklist answers 2026-10-30; loop: gameplay-dev -> ux-designer -> qa -> playtester (short) -> tech-writer -> close; tag `playtest-2026-10-30-F1`)**
  - **Run order (game-lead, 2026-10-30):** PL2 -> **F1 -> P-dodge -> W1b** -> 3d. Wizard *tuning* must come after every change that shifts its risk (10 rooms, movement pass-through, Wall buff, per-class charges, Recovery 8 -> 12 and the Wizard's 14 s), so W1b moved after P-dodge. See DECISIONS.
  - **gameplay-dev:**
    1. **Wall of Mild Fire 1.5x size (director):** `data/cards/fire_wall.json` `length` 5.0 -> 7.5, `width` 1.2 -> 1.8. Everything else unchanged. The cast preview and the burn-down visual follow the new size.
    2. **Movement cards pass through enemies (director, GDD §3):** every card whose `slot_type` is `movement` ignores enemy bodies while it moves the player (today only Shadow Step does). Cards: Blaze and Bail, Nope Leaping Away, Reluctant Lunge, Walk Through Everyone, Ugh Fine Moving, Sideways Blink, Tactical Hover. Check each one's templates.
       - A move that ends inside a body resolves the overlap the way Shadow Step does (no stuck player).
       - A movement card that doesn't move the player is unaffected.
       - **The dodge stays blocked by bodies.**
       - **Reluctant Lunge** then hits every enemy on its line instead of stopping at the first body. That's a damage change: report its before/after on a line of 3 enemies, and the Lunge preview now matches the real path (old backlog item).
       - Prefer a template-level flag set in data over per-card code.
    3. **Dead-card swap on Shift + 1-5 (director, GDD §4):** `data/input_bindings.json` `ctrl` -> `shift`. **Check how a plain slot key ignores the modifier today:** Shift+N must swap only, with no preview or cast; plain N is unchanged; Ctrl+N does nothing. Make sure Shift isn't already bound. Tests.
    3a. **From the PL2 playtest (N1):** at 1024x600 (Rogue, seed 7) the boss's head sits about 15 px behind the RMB meter. Raise the top margin of the `bosses.json` `spawn` box so the head clears the HUD.
    4. **Runs of 10 rooms (director, GDD §9):** `data/run.json` composition 5/1/1/1 -> **7 combat, 1 elite, 1 rest, 1 boss** (game-lead call, the smallest change; harder runs come from the tiers). Update `placement.ranges` for 10 rooms (elite about [3, 8], rest about [2, 8]). Grep `src/`, `tests/`, `tools/` and `data/` for a hard-coded 8 (the boss index, `--run-room=8`, "of 8", the sim). The boss is room 10.
  - **ux-designer:**
    5a. **From the PL2 playtest:** the white focus ring on a grey reward card has a small notch at its left and top edges; fix the notch (ring contrast waits on the director's eyes).
    5. Every "Ctrl+1-5" hint (HUD, pause screen, any tooltip) now says Shift; "Room X of 10" fits at every supported size.
  - **qa:** the usual gates; the Wall preview matches its hitbox; the pass-through for each movement card, including no stuck-in-body cases and the dodge still blocked; Shift+N swap with no cast; the 10-room run end to end; a 10+ seed Rogue `-Run` report (informational; P-dodge sets the W1b baseline).
  - **Playtester (short):** a 10-room run; do movement cards feel like real escapes; does the Wall now catch walkers.
  - **Docs:** tech-writer, with the `[Director decision]` old/new values; README's `--run-room=8` examples become 10.

- [x] **W1b, Wizard content and balance.** **DONE 2026-11-02**, see the full entry below.

- [x] **PL2, small polish before W1b** — **DONE 2026-10-30.** Gameplay 3b8359e..5079a2a; ux ad77847, B1 fix cb2be67; qa FAIL b7ba7fe then delta PASS 8a99ce4 (1082/1082); playtest 4dd2eaa (no blocker); docs d175b51. Tag `playtest-2026-10-30-PL2`. Rogue boss baseline (8 rooms, 12 seeds) 66.7 s mean. Follow-ups (N1 boss head margin, focus-ring notch) in F1. (Original header: game-lead, 2026-10-30; loop: gameplay-dev -> ux-designer -> qa -> playtester (short) -> tech-writer -> close; tag `playtest-2026-10-30-PL2`)**
  - **Goal:** clear the non-Wizard fixes from the W1a qa and playtest, so W1b tunes against a stable baseline. The boss spawn fix changes the Rogue's boss fight.
  - **gameplay-dev:**
    1. **Boss spawn:** the boss starts fully on screen in room 8 (3c backlog; the W1a playtest saw only about a quarter of its body). The camera framing must not change for other rooms. **The Rogue `-Run` output and boss times are expected to change. The arena hash (2792856473) must still match**, since the arena has no boss.
    2. A bare or unknown `--class` (and `--deck`) prints only the "Launch refused" message, with no stack trace from `RunController.prepare`, and still exits 2.
    3. The scenario `character` key also sets the body look (W1a captures showed a Rogue body).
    4. Delete the tracked junk `scratch_suite.txt` (repo root, from 0c9704e).
    5. Identify the pink fan at the Wizard's feet in a room-1 capture (`--class=wizard`). Is it an enemy telegraph or the player's own cue? Fix it only if it's wrong.
    6. Check that a bolt hits only the first enemy on its line, and report it. No change unless it's a bug; the playtest and D18 decide.
    6a. **Card frame colour data (director, 2026-10-30, answers D17; GDD §4 "Card frame colours"):** a `frame_color` on every pool in `data/pools.json` (Fire `#ff6a1f`, class pools `#d9b48a` light bronze, neutral `#9a9a9a` grey; starting values, see DECISIONS). A load check fails if any pool lacks one. One accessor (card id -> pool -> frame colour) for the UI. Tests for both.
  - **ux-designer:**
    7. The pick-screen backdrop HUD no longer shows the previous class's HP (one paused frame).
    8. **Rogue melee cue** (the W1 brief's "Quick win"): a new player can tell the light attack is melee. For example, a faint swing arc at the player when nothing is in reach, or a "too far" tick when clicking at a distant reticle. Unobtrusive in a crowd, with data in ui.json.
    9. **Card frames in the family colour (director, 2026-10-30):** every surface that draws a card uses the 6a accessor for its frame: at least `CardSlotWidget` (active and next-up), `RunOptionCard` (reward offers) and the rest-room removal list; grep for any others. The reward screen's reject option isn't a card and keeps its own border.
       - **The family colour is always visible, and ready-vs-cooling stays readable at a glance** (today the slot border is the ready cue; move that cue to an inner outline, fill or brightness, your call). Hover and selected states on reward cards stay distinct too.
       - Check Fire vs bronze side by side in a mixed slot at 720p; adjust the hex values in data if they blur and log the final ones.
  - **qa:**
    - the suite, `--quit`, the 20 s headless run, SceneSelfCheck, and the reload soak (Main and Player likely change; the known flake belongs to P-dodge);
    - a boss capture showing the boss fully on screen at 1024x600 and 1280x720;
    - **re-measure the Rogue's boss time, 10+ seeds, as the new baseline for W1b.**
    - captures of the HUD and the reward screen showing all three frame colours (fire, bronze, grey) and a cooling slot.
  - **Playtester (short):** smoke check, the boss on screen, the melee cue, and whether the frame colours read as fire / class / neutral without explanation.
  - **Docs:** tech-writer, at the close.

- [x] **W1b, Wizard content and balance** — **DONE 2026-11-02.** Content aaa933a, tooling 8b1778a/45ed585, tuning 2128ae4 + 0754483 (Wizard HP net 26, D20 open); ux 245d8e3 (5e: no overlap, no fix needed); qa PASS 6f26ff9 (1156/1156); playtest d74e0df (no blocker); docs ab00c50 + red-suite correction. After the director's keybind commit 24530e4, 3 stale input tests failed; qa fixed them test-only in 0119999 (1156/1156, arena hash 2484586390). Tag `playtest-2026-11-02-W1b`. Carry-overs: the kiting Wizard's rooms 1-9 are nearly free (H1), Fan of regrets lane length/ramp and damage numbers over the boss bar (PL3). (Original header: brief, game-lead 2026-10-30; runs after F1 and P-dodge. Full loop: gameplay-dev -> qa -> playtester -> tech-writer -> close. Planned tag `playtest-2026-10-30-W1b`; closing it also ticks the parent W1 item.)**
  - **Goal:** the Wizard plays like a caster: its own attack cards, a caster starter, and test presets. It's tuned so its risk matches D18. GDD §3 (cards beat basic attacks), §4 (deck rules), §5 (Wizard), §7 (armor).
  - **Order inside the slice:** content first, tuning last, so D18 can be answered before any tuning depends on it.
  - **Acceptance, gameplay-dev:**
    1. **Wizard attack cards:** 2-4 attack cards in pool `wizard` (attack_single and/or attack_aoe) with a ranged or caster feel, e.g. a bolt volley, an arcane nova, a piercing beam. Existing effect templates only, unless one is unavoidable (log it). That brings the Wizard pool to about 6-8 cards in total. Placeholder names in the game's dry, weary tone.
       - **Every new damage card must pass `CardDamageRule` against the Rogue's 5.0 DPS light**, the existing stricter bar.
       - Optionally a ward or armor buff card, which needs `CardSummary` wording support for armor (see the W1a calls).
    2. **The Wizard starter is rebuilt** (F1 note: with 10 rooms the Wizard owns 15 of 18 available cards at the start, so most offers are duplicates; report the offer mix after the new cards). around the Wizard cards: 15 cards, 3 per slot, no melee-flavoured cards where a caster card exists (e.g. Pointy Stick out). The full deck is updated too.
    3. **Presets:** `fire-heavy-wizard` and `mixed-wizard` in `data/debug_decks/` with `"class": "wizard"` (plus an arcane-heavy one if it makes sense). Report the card counts per family.
    4. **A non-kiting Wizard bot policy** (`-WizardNoKite` or similar, the same pattern as `-LightHeavyOnly`): it holds a mid-range spot or walks in like the Rogue bot instead of kiting perfectly. qa and the playtester both said the kiting bot is a ceiling, not a typical player.
    5. **Balance table** for the Wizard cards in the hand-back, for DECISIONS.
    5a. **From the F1 playtest:** the Wizard's risk is flat, then a cliff. Rooms 1-9 cost almost nothing, then on seed 21 the boss killed a full-HP Wizard in 6.4 s; seed 22 won at 11/26 HP. Find which boss attack does it (opening charge or volley vs 26 HP), and tune so the boss is a real threat but not a sudden one-shot. Use Wizard data only, or report it as a director item.
    5c. **Bot caveat (P-dodge):** the charge-aware bot loses more HP in the 60 s arena with 3 charges than with 1 (extra rolls break its kiting). Read charge effects from whole runs, and note in the hand-back whether the non-kiting policy shows the same artefact.
    5d. **Cliff cause (P-dodge playtest, seed 3):** the Wizard died in phase 1 to four "Fan of regrets" volleys in a row (about 10 HP each; 5 pellets x 5 = 25 against 26 HP); the kiting bot stays where only volley and slam reach it, and may not dodge pellets. Check whether the bot dodges pellets at all before tuning (a bot gap would make the cliff a sim artefact). A `--boss-log` flag in `tools/wave_sim.gd` (per-attack damage taken in the boss room) is in scope.
    5e. **ux (small):** the STAGGERED banner overlaps the boss bar's "Armor / Resists" line (P-dodge playtest capture); fix the overlap.
    5b. A scenario with walking enemies crossing a Wall of Mild Fire, so the director's 1.5x buff can be checked (F1 playtest couldn't).
    6. **Tuning, last:**
       - With the kiting and non-kiting policies, 10+ seeds each, measure the Wizard's boss time against **P-dodge's** Rogue baseline (10 rooms, per-class charges, Recovery 12 s) — **set by qa 14eadd1: Rogue boss 64.3 s mean (47.8-81.3), 70-130% band = 45.0-83.6 s; per-room HP lost 2.0-6.8** (target 70-130%) and the HP lost per room.
       - Tune toward **D18 = A (director, 2026-10-30, GDD §5)**: Wizard rooms cost some HP, less than the Rogue's; the Wizard should be squishier than today (HP is a lever, 26 now). Its 2 dodge charges and longer Recovery already land in P-dodge.
       - **Tune only Wizard data:** bolt range, fire rate and damage, heavy numbers, Wizard HP, Wizard card numbers. **No enemy changes.** If the target needs enemy changes, stop and report: it's a director item.
       - Log every before and after number.
  - **qa:**
    - the suite and the usual gates; the Rogue unchanged against the P-dodge baseline (`-Run` output and arena hash);
    - the 3 presets valid;
    - `CardDamageRule` for the new cards;
    - an independent 10+ seed re-run under both bot policies.
  - **Playtester:** a Wizard run (captures plus sim). Do the caster cards make the Wizard feel distinct? Is the risk level right?
  - **Docs:** tech-writer, plus a CHANGELOG fix: the 2026-10-30 W1a entry says the docs pass "now happens per slice", but that rule dates from 2026-10-28. Correct or remove it, and note the fix.

- [x] **P-dodge, dodge charges and indicator** — **DONE 2026-10-30.** Gameplay 0209de4..1fdca8a + 4986db4, 6243785, bc976ca; ux 8566b9e, 74a972c; qa PASS 14eadd1 (1147/1147); playtest 60d86fd (no blocker); docs ee18b08. Tag `playtest-2026-10-30-P-dodge`. Arena hash 2484586390. W1b baseline: Rogue boss 64.3 s. (Original header: director request 2026-10-29; runs after F1 and before W1b (2026-10-30 run order); also carries D13, D16 and the 2026-10-30 per-class charges and Wizard Recovery)**
  - **Also carries (game-lead, from T-decks qa):** fix the reload soak flake "damage immunity leaked into a new room" (tools/reload_cycle.gd:248). It predates T-decks; reproduce it with a wave sim running alongside `run_reload_cycle.ps1 -Cycles 5`.
  - **Goal:** the dodge has charges and the player can see them. GDD §3 [DIRECTOR DECISION, 2026-10-29].
  - **Acceptance:**
    1. `data/player.json` `dodge.charges` (default 3). The effective count is read through the existing StatModifiers as a stat (e.g. `dodge_charges`) so future passives can raise or lower it, **clamped to a hard 0-4** after all modifiers (`dodge.min_charges` 0 and `dodge.max_charges` 4 in data, validated). At 0 the dodge is unavailable and the indicator shows that clearly. Tests cover the clamp at both ends and a mid-run change (the current charges clamp down). No passive or level-up content now; only the hook and `dodge.cooldown` is the per-charge recharge time. Charges recharge one at a time while below max. Each dodge spends one charge. A dodge can't start during another dodge (the roll lasts 0.25 s). Distance stays 5 m.
    2. **Cooldown default (game-lead call):** 0.8 s -> 1.2 s per charge ("slightly longer"). It's one data value.
    3. **HUD (ux-designer):** a dodge indicator near the LMB/RMB meters: one pip per charge (filled = ready) with the recharging pip filling over time, plus a "Space" label. It's readable at 720p, 1080p and 1440p and works for 0-4 charges. Charges reset each room and on Try again.
    4. Pause, death, reload and the 2-tick post-pause block still work. Tests for the charge logic and the recharge timing.
    4a. **qa N11 (from the 3c fix check):** the reload soak intermittently fails with "reward pick: damage immunity leaked into a new room" (about 1 in 5, also at 64df947). Find out whether `Health.damage_immune` really leaks into the next room after a reward pick (a real bug: the player would be invulnerable) or the soak is racing. Fix it and add a test.
    4b. **D13 = B (director):** `data/slot_types.json` recovery `base_cooldown` 8.0 -> 12.0. Check that Recovery is still the longest effective cooldown and update any test that pins 8.
    4d. **Per-class dodge charges (director, 2026-10-30, GDD §3/§5):** Rogue 3, Wizard 2, as a per-character override in `data/characters.json` (the `player.json` default stays 3). Still clamped 0-4. The pip indicator shows 2 for the Wizard. Tests.
    4e. **Wizard Recovery cooldown (director, 2026-10-30: "slightly longer" than the Rogue's):** Wizard Recovery 14 s vs the Rogue's 12 s (game-lead call), as a per-character slot cooldown override in data. Recovery stays the longest cooldown for both classes. Tests.
    4f. **From F1 qa (non-blocking):** if pass-through ends with an enemy's centre exactly on the player's position, the player is launched upward (pre-existing, also with Shadow Step). Nudge the player out on restore or clamp y; add a test. Also fix the stale "Ctrl" comment at `src/player/Player.gd:798`.
    4c. **D16 = B (director):** at each phase threshold the boss staggers briefly (`bosses.json` `transition.stagger` seconds, default 0.8, a game-lead call), which **interrupts its current attack or action**.
       - A visible reel: a stagger pose or tilt, a flash, and a "STAGGERED" cue on the boss bar (ux).
       - The stagger plays before the existing roar.
       - Design it as a reward: player damage dealt during the stagger counts (it isn't eaten by `hp_floor`). Explain how.
       - Keep the total transition within the 1.5 s cap, or raise the cap in data and log it.
    5. Rerun the seeded wave sim and the whole-run sim and report the HP lost before/after (3 charges is a big survival buff, which may feed D13 and the solid-enemies call). **qa re-measures the Rogue on 10+ seeds (`-Run`, 10 rooms): this is the baseline W1b tunes against.** Also report the Wizard (kiting bot) on the same seeds, for reference only.
  - **Owner sequence:** gameplay-dev -> ux-designer -> qa -> playtester (short) -> tech-writer (folded into the next docs pass if small) -> close.

### Run order after W1b (director, 2026-11-02)
W1b finishes as planned (tech-writer docs pass, then close). Then, in this order: **K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d.** **Updated 2026-11-02 (director's OPEN_ITEMS pass):** H1 -> **PL3 housekeeping** (D21 = B) -> **H2** (dodge-off trial; game-lead placement, logged) -> BD0 -> PL3 (rest) -> BD1 -> 3d. The branching map's place is D28. **Updated at BD0 (2026-11-02, game-lead defaults D24 = A and D28 = A):** BD0 -> MAP0 (map design doc, game-lead, docs only) -> PL3 (rest) -> BD1 -> BD2 (relics) -> first map build -> 3d -> BD3. **Updated 2026-11-02 (director answers D24 = A, D28 = A, D29 = B):** BD0 -> **H3 (dodge return; game-lead placement, logged)** -> MAP0 -> PL3 (rest) -> BD1 -> BD2 (relics) -> first map build -> 3d -> BD3. **Updated at MAP0 (2026-11-03):** the first map build is MAP1 (map, gold) + MAP2 (merchant), and MAP3 (mini-bosses, curse/buff rooms) follows 3d (D33 default): H3 -> MAP0 -> PL3 -> BD1 -> BD2 -> MAP1 -> MAP2 -> 3d -> MAP3 -> BD3. **Updated 2026-11-04 (director D32 = A with three acts, D33 = B):** PL3 -> BD1 -> BD2 -> MAP1 -> MAP2 -> MAP3 (three acts, mini-bosses, save/resume) -> MAP4 (curse/buff rooms) -> 3d -> BD3. Reason (director): cards and decks don't yet change how a run plays, and that must be settled before more screens, art or staging. game-lead's reorder note is D21 in OPEN_ITEMS (default: this order). Every build slice gets the full loop and a `playtest-YYYY-MM-DD-<slice>` tag; each role commits only its own paths.

- [x] **K1, key labels follow the bindings** — **DONE 2026-11-02.** gameplay-dev 04ac813 + 7f4b136 (`InputLabels`, validator, `bindings_changed`, Recovery on R); ux 6204f2a + 81abc85 (HUD/prompt/pause text from bindings; fixed slot keys leaking through an open reward prompt); qa PASS 8752a1c (1190/1190, soak OK, arena hashes unchanged; `docs/reviews/2026-11-02-k1-qa.md`); playtest 2c0d185 (smoke PASS; `docs/playtests/2026-11-02-k1-short.md`); docs 9e77aae. Tag `playtest-2026-11-02-K1`. Carry-overs: PL3 items 7-10. (Original header: director, 2026-11-02; small. Loop: gameplay-dev -> ux-designer -> qa -> playtester (short smoke) -> tech-writer -> close.)**
  - **Goal:** whatever is in `data/input_bindings.json` is what the UI shows. No UI text hardcodes a key. GDD §3 "Key labels follow the bindings" and "Card slots" [DIRECTOR DECISION].
  - **Today:** `data/input_bindings.json` (24530e4, the director's own change after Luke's playtest) has slot_1..slot_5 on Q, E, 1, 2, 3 and the swaps on Shift plus the same keys. `src/ui/Hud.gd:25` builds slot labels with `str(i + 1)`, so the HUD still shows 1-5. Reward screens say "Slot %d now", option cards say "Slot %d", and README, the pause screen and OPEN_ITEMS describe old keys.
  - **gameplay-dev:**
    1. **One helper** (for example `InputLabels.for_action(&"slot_1")`) turns an action name into display text by reading the live InputMap. It handles plain keys, Shift/Ctrl/Alt combos ("Shift+Q") and mouse buttons ("LMB", "RMB"). It reads the first binding and falls back to "?" when an action has none. It caches nothing that can go stale: it updates when bindings change at runtime (a signal or a refresh hook).
    2. **Data change:** Recovery on R (`slot_5` = R, `dead_card_swap_5` = Shift+R). Movement stays on 2; moving it to F later must be a one-line data change.
    3. **Binding validator:** no two actions may share the exact same key plus modifiers; the swap bindings keep the exact-match rule (`Player.gd` documents why). It fails loudly at startup on a conflict.
    4. Expose whatever ux needs (slot display name plus key text).
  - **ux-designer:**
    5. Card slot key labels use the helper.
    6. Wherever the UI says "Slot N" for a slot, show the slot's name and bound key instead (for example "Attack (Q)", "Movement (2)"). Keep the wording elsewhere.
    7. The pause/settings screen, the class pick hints and every hint (dodge, light/heavy click, dead-card swap, hold-to-preview) read from the helper. Search `src/` and `data/` for hardcoded "1-5", "Slot %d", "Shift+", "Ctrl+" and fix every hit.
    8. **Fit:** the key label box fits the longest label the helper can produce at the minimum HUD scale (the hud_layout test). "R", "Q", "Shift+Q" and "LMB" must not overflow or clip.
  - **qa:**
    - For each slot, the HUD label equals the helper's text for that slot's bound key.
    - Rebind in a test (Recovery on F, a Shift combo, a mouse button): the HUD, the reward screen text and the pause screen follow with no code change.
    - A scan test: no `.gd` or `.json` UI string holds a hardcoded digit key hint for a slot.
    - The validator rejects duplicates and accepts the shipped file.
    - Full suite, the 20 s headless run, SceneSelfCheck, and the **reload soak** (K1 touches the HUD and input).
  - **Playtester (short):** smoke check; captures of the card strip, a reward screen and the pause screen showing Q, E, 1, 2, R.
  - **Docs:** tech-writer updates README controls and any screenshots with old labels. game-lead updates the OPEN_ITEMS "How to playtest" keys line and adds the "Needs your eyes" checks (labels match Q, E, 1, 2, R; hold-to-preview and cast-on-release still work on the new keys; Shift+key still swaps without casting).

- [x] **H1, pressure pass** — **DONE 2026-11-02: gates met, goal missed.** gameplay-dev 0c834a0/4e72dda/e4f4cbe (`pressure` knobs in `data/enemies.json`, speed_scale 1.25, attack_rate_scale 1.0, boss unscaled, adds scaled; `-LightHeavyOnly` now presses no slot); qa PASS 42cdb13 (20 seeds; `docs/reviews/2026-11-02-h1-qa.md`); playtest a8123b5 (no blocker); housekeeping 642d546/c3f5ac1/98595d4 (D21 = B); docs f8238c1. Tag `playtest-2026-11-02-H1`. The standard runs and Rogue boss band held, but the director's no-card Wizard still looked winnable (his item 34), and the kiting Wizard isn't hit because shooter shots are dodged by walking (qa). Follow-up: **H2** (dodge-off trial). Flaky: `w1a_test.gd:485` failed once under full-suite load and passed alone (to qa in H2). (Original header: director, 2026-11-02; small. Loop: gameplay-dev -> qa -> playtester (short) -> tech-writer -> close.)**
  - **Goal:** a run with no cards (light, heavy, dodge, rest rooms allowed) is no longer a safe win for either class, while a normal card-using run stays winnable at today's tier (future "Easy"). Cards must clearly matter (GDD §3). GDD §9 "Pressure pass" [DIRECTOR DECISION]. This is the one deliberate exception to "don't retune the base game until the tiers exist" (ROADMAP "Later"); the director asked for it.
  - **Evidence:** the director cleared 10 rooms as the Wizard on 2026-10-31 with no cards and no healing in 5:25. The bot says the Wizard loses some HP; his hands say otherwise. **Treat the sim as a floor, not the truth.**
  - **Levers, in order (stop when the targets are met):**
    1. **Enemy movement speed**, every type including elites. Test +10%, +20% and +25%. Today: chaser 4.0, shooter 3.0, golem 2.0, boss 2.6 (phases 2.6/3.0/3.4). The player walks at 6.0 (`Player.gd` `move_speed`, not data). Ratios today: chaser 0.67, shooter 0.50, golem 0.33; at +25% the chaser is 5.0 (0.83). No normal enemy faster than the player's walk unless logged why. Chasers stay beatable by good dodging and kiting. Log the ratios.
    2. **Only if speed alone misses the targets: attack rate.** Shorter attack cooldowns first, then slightly shorter wind-ups. **Telegraph floor (game-lead default): no enemy telegraph shorter than today's shortest, 0.45 s** (chaser and shooter); boss attacks keep their 0.6 s minimum. D6 and the readability rules still hold.
  - **Knobs:** one shared data knob for enemy speed scale and one for enemy attack-rate scale, applied on top of the per-enemy values, so the future tiers (GDD §9) reuse them. Don't build tiers.
  - **Not in H1:** player stats, card numbers, boss mechanics. The boss uses the speed scale only if needed to keep its fight length; if so, say why.
  - **gameplay-dev:** the knobs and their validation; bot policy checks (the `-LightHeavyOnly` policy works for both classes, with and without Wizard kiting, on full 10-room runs and with rest-room use); run the lever sweep and hand qa the candidate values.
  - **qa (12+ seeds, before and after, report in DECISIONS):**
    - Policies: the standard card policy and `-LightHeavyOnly`, both classes, Wizard kiting and `-WizardNoKite`, full 10-room runs.
    - **Targets (game-lead may adjust with reasons; log the final ones):** the no-cards policy clears at most about 25% of runs on either class; the standard policy's clear rate stays within about 15 points of today's; the Wizard (standard, kiting) ends fight rooms with a median HP loss of at least about 10% of max HP; the Rogue's standard boss time stays in the A1 band of 45-84 s.
    - Say what the sim can't tell us.
    - Sim hashes will change: re-baseline them, and game-lead logs the new values in STATE.
    - Full suite, the 20 s headless run, SceneSelfCheck.
  - **Playtester (short):** a run per class with cards and one with no cards; does pressure feel fair and readable?
  - **Close:** OPEN_ITEMS asks the director to play the Wizard again with and without cards and say whether it bites, and to run with no cards and see whether he now loses before the boss.

- [x] **H2, dodge-off trial, Space/F keys, Wizard 22 HP** — **DONE 2026-11-02.** gameplay-dev 120bfef..dacc680 (`dodge.enabled` false; Movement Space, Utility F; Wizard 22 in its own commit 120bfef; game-over arm delay); ux e155c3e/ff3ef4f (dodge row hidden); qa PASS 4aa7141 (1220/1220; w1a flake fixed; `docs/reviews/2026-11-02-h2-qa.md`); playtest ebde769 (no blocker; `docs/playtests/2026-11-02-h2-short.md`); docs edef5c0/0e47a70. Tag `playtest-2026-11-02-H2`. **Trial result (bots, not retuned):** standard clears with the dodge off are Rogue 3/16, kiting Wizard 8/16, non-kiting Wizard 7/16 (16/16 each with it on); no-card runs die in room 1. Whether it stays off is D29. (Original header: director, 2026-11-02; small. Loop: gameplay-dev -> ux-designer -> qa -> playtester (short) -> tech-writer -> close.)**
  - **Goal:** see what a run plays like with **no dodge**. The director's no-card Wizard still looked winnable after H1 (his checklist item 34). GDD §3 "Dodge-off trial", "Card slots"; §5 "Wizard HP 22" (D20 = B). **This is a trial: report what happens and don't retune anything to compensate.** If standard runs get much harder, say so in the report.
  - **gameplay-dev:**
    1. **Data switch:** one value (for example `data/player.json` `dodge.enabled`, default **false** when shipped) turns the dodge off for both classes. Keep all the dodge code, its tests and the charge plumbing. When it's off, the dodge action does nothing, charges don't tick, and nothing else changes. Tests that cover the dodge still pass with the switch on.
    2. **Bindings (`data/input_bindings.json`):** `slot_4` (Movement) = **Space**, `dead_card_swap_4` = Shift+Space; `slot_3` (Utility) = **F**, `dead_card_swap_3` = Shift+F. The dodge action keeps no key while it's off.
       - **Turning it back on** takes two data edits: the switch, and a new dodge key that doesn't clash (the validator catches a clash). Say this in the hand-back so the README and OPEN_ITEMS can tell the director.
       - **Validator:** an action with no binding is allowed, and a disabled dodge must not trip it. Log your exact rule.
    3. **Space vs menus:** Space is now a card key. Check that Space never accepts a prompt, reward or "Try again" by accident: the reward and run prompts already swallow slot actions, so check game over and class pick too. **Pulled in from PL3 item 9:** GameOverScreen gets the same arm delay as RunPromptScreen.
    4. **Wizard HP 26 -> 22** (D20 = B) as **its own commit**, so its effect can be seen apart from the dodge.
    5. **Bots:** the wave sim and bot sim obey the switch (no dodge when it's off). Run the H1 policies (standard and `-LightHeavyOnly`, both classes, Wizard kite and `-WizardNoKite`, 10-room runs, 12+ seeds) for three columns: **H1 baseline** (dodge on, Wizard 26), **Wizard 22 with dodge on**, and **shipped** (dodge off, Wizard 22). Report clear rate, fight-room HP dip (the in-room lowest-HP metric, per qa at H1) and the Rogue boss median.
  - **ux-designer:** hide the dodge pips and their key column while the dodge is off, and bring them back with the switch. Any hint or label that names the dodge follows the switch. The Movement chip reads "Space" and Utility "F", from `InputLabels`. Check that "Space" and "Shift+Space" fit the key box at the minimum HUD scale. Captures: card strip, pause screen, a reward screen.
  - **qa:** review and tests:
    - switch off: Space casts Movement with hold-to-preview and cast-on-release; Shift+Space swaps without casting; no dodge happens; pips are hidden; Space doesn't confirm game over or class pick by accident;
    - switch on, with a test-only dodge key: the dodge works as before;
    - the validator accepts the shipped file.
    Also: full suite, the 20 s headless run, SceneSelfCheck, and the **reload soak** (input, HUD and Player change). Re-run the three-column table yourself. **The sim hashes change again:** re-baseline them, and game-lead records them in STATE.
  - **Playtester (short):** smoke check; a run per class with cards and one no-card run. Without the dodge, does danger read as fair, and does Space feel right as the Movement key?
  - **Close:** OPEN_ITEMS asks the director to play once with cards and once without, with no dodge: do you now lose a no-card run? Does Space feel right for Movement and F for Utility? Should the dodge stay off?

- [x] **BD0, build-depth design doc — DONE 2026-11-02.** game-lead 81fb65e..0ddd630 (`docs/BUILD_DEPTH.md`, GDD §4a [PROPOSED] summary, BD1 rewritten + BD2/BD3 added, DECISIONS "BD0", OPEN_ITEMS D22/D24/D25); docs 995befe. Ran on D29 default A. No tag. (Original header: director, 2026-11-02; game-lead alone, docs only, no code.)
  - **Goal:** a concrete, data-driven plan for GDD §4a's goals, in a new `docs/BUILD_DEPTH.md` plus a GDD §4a summary marked [PROPOSED].
  - **Contents:**
    1. **Diagnosis table:** why a card is interchangeable today (flat damage, no conditions, no tags, one-use effects, no cross-slot interaction), tied to real cards in `data/cards/`.
    2. **Goals as measurable checks** (future sim and qa tests): removal pain (removing a keystone drops an archetype deck's bot performance by a clear margin; removing a random off-plan card barely does); run fingerprint spread (same class and element, different picks, clearly different damage-source mixes by slot and status); archetype parity (each archetype's boss time inside 70-130% of the standard deck); no-cards run not viable (H1).
    3. **Synergy framework:** tags and keywords (Burn, Bleed, Projectile, Melee, Zone, Dash, Heal, later Summon-style), conditions and payoffs ("if the target is Burning", "after a Movement card", "per distinct tag in your deck", "while a Zone is active"), cross-slot hooks (a slot primes the next within a short window), scaling stacks. Say which are new generic effect types and which are data on existing templates.
    4. **Relics/enchants:** run-scoped, rule-changing. Sources (elite and boss drops, a reward-screen alternative to cards, a rest-room choice; pick defaults), count per run, data format, how a relic hooks the same event bus as statuses, reset between runs, HUD display. **10 relic sketches** for Fire Rogue and Fire Wizard, including the director's burn-explosion example, plus **5 that reward light and heavy attacks**.
    5. **Archetypes:** at least 4 per class on Fire, each with 4-6 cards (today's pool plus marked new ones), 2-3 relics, and a keystone card.
    6. **Slot decisions:** how timing, cooldown reading and the dead-card swap start to matter.
    7. **Readability:** tag chips on cards, a condition line, a glow when a condition is live; reuse `CardSummary`.
    8. **Content budget and slices:** BD1 (engine plus first 2 archetypes per class), BD2 (relics), BD3 (more cards and archetypes) and so on, each one sitting, with acceptance, owners and the loop. Loosely coupled to specific cards. Slices go into this ROADMAP.
    9. **Sources:** say which idea comes from which game, leaning on Erannorth Chronicles, Gwent, Slay the Spire and Monster Train. No web access: only mechanics game-lead is confident about, "unsure" otherwise. A research-digest request goes in OPEN_ITEMS if wanted.
    10. **Director questions:** at most 3, each with a default, as **D22, D24, D25** (D23 is taken by loadout availability). Don't wait for answers.
    11. **Branching map hooks (director, 2026-11-02, GDD §9):** treat future map nodes (mini-bosses, curse/buff rooms, a merchant) as relic and reward sources in the relic design, so BD1's relic framework doesn't need rework when the map lands. Don't design the map itself (D28 covers when).
    12. **Dodge-off:** if H2's trial keeps the dodge off, the Movement slot is the player's only escape. Say what that means for Movement cards in the archetypes.
  - **Done when:** `docs/BUILD_DEPTH.md` exists with all of the above, GDD §4a has the [PROPOSED] summary, BD1's brief below is rewritten from it, and OPEN_ITEMS has the questions.

- [x] **H3, the dodge returns — DONE 2026-11-03.** gameplay-dev cee653d/d22b08d/783d552/3dc74fb; ux 6f89eea; qa PASS 44eff31/f1a3f88 (`docs/reviews/2026-11-03-h3-qa.md`, 1244/1244); playtest 305b13b (no blocker; `docs/playtests/2026-11-03-h3-short.md`; findings -> PL3 items 11-13); docs 8700a4d. Tag `playtest-2026-11-03-H3`. Bots (20 seeds): Rogue 17/20, Wizard kite 15/20, no-kite 18/20; every `-LightHeavyOnly` 0/20 (no-card gate met). Ctrl verified with synthetic events only. (Original header: director, 2026-11-02, D29 = B; small. Loop: gameplay-dev -> ux-designer -> qa -> playtester (short) -> tech-writer -> close.)
  - **Goal:** the dodge-off trial ends. The dodge is back on **Space** with fewer charges (**Rogue 2, Wizard 1**), Movement cards move to **Ctrl**, and enemy attacks get a little faster, especially the telegraphs and above all the boss's "Fan of regrets". GDD §3 "Dodge roll", "Card slots"; §5 "Wizard risk". Like H1, the speed-up is a director-requested exception to "don't retune the base game before tiers exist".
  - **gameplay-dev:**
    1. **Dodge on:** `data/player.json` `dodge.enabled` false -> **true**; default `dodge.charges` 3 -> **2**; `data/characters.json` Rogue `dodge_charges` 3 -> **2**, Wizard 2 -> **1**. Clamp 0-4 unchanged.
    2. **Bindings (`data/input_bindings.json`):** `dodge` = **Space**; `slot_4` (Movement) Space -> **Ctrl**; `dead_card_swap_4` Shift+Space -> **Shift+Ctrl**. Utility stays F.
       - **Ctrl as a held key is the risk.** Acceptance: while Ctrl is held for hold-to-preview, WASD still moves, the mouse still aims, and left/right click still attack (Godot can fail to match a plain W or a click action when Ctrl is down, depending on how the events are matched). Releasing Ctrl casts. Shift+Ctrl swaps without casting, whichever key goes down first. Left and right Ctrl both work, or log which. If Ctrl can't be made reliable, stop and report; don't pick another key yourself.
       - The duplicate-binding validator still passes; the game-over and class-pick screens still ignore a mashed Space (the H2 arm delay).
    3. **Fan of regrets correctness, before any timing change (moved here from PL3 item 6):** the H2 playtest saw pellets hit a bot that wasn't in a lane at the fire moment. Check whether pellets or lanes stay dangerous after the fire moment, or whether the drawn lane doesn't match the pellet path, and fix it if so. Tooling: a boss scenario with a fixed attack (`--scenario`), so a mid-volley frame can be captured.
    4. **A bit faster (starting values, game-lead's call, logged in DECISIONS "2026-11-02 - H3"):**
       - `data/enemies.json` `pressure.attack_rate_scale` 1.0 -> **1.1** (it divides each enemy's attack cooldown, so 10% more attacks).
       - New knob `pressure.telegraph_scale` (default 1.0, shipped **0.85**) multiplying every non-boss enemy's `telegraph_duration` (0.45 -> 0.38, 0.7 -> 0.6, 0.9 -> 0.77). This is new code: the pressure validator rejects unknown keys today (`EnemyConfig.gd`). Validated range like the other knobs.
       - `data/bosses.json` "Fan of regrets" (`volley`) `windup` 0.9 -> **0.75**. With phase 3's `windup_scale` 0.85 that's 0.64, still above `min_telegraph` 0.6. Other boss attacks unchanged.
       - Land the dodge change and the speed-up in **separate commits**, so each one's effect can be measured on its own.
    5. **Bots:** they dodge again (they did before H2). Run standard and `-LightHeavyOnly`, both classes, Wizard kite and `-WizardNoKite`, 10-room runs, 12+ seeds, in three columns: **H2 shipped** (dodge off), **dodge on at 2/1 charges, no speed-up**, **H3 shipped**. Report clear rate, fight-room HP dip and the Rogue boss median. **No-card gate (GDD §3):** report the `-LightHeavyOnly` clear rate; if it is above 25%, say so in the hand-back. Don't retune further; game-lead takes it to the director.
    6. Re-baseline the arena and bot-sim hashes and give the new numbers.
  - **ux-designer:** bring the dodge pips back (2 for the Rogue, 1 for the Wizard; check that a single pip still reads as "dodge ready / recharging"). The Movement chip reads "Ctrl" and its swap "Shift+Ctrl", from `InputLabels`; check both fit the key box at the minimum HUD scale. Any hint that names the dodge follows the switch. **Fan of regrets telegraph look (from PL3 item 6):** cap lane length to what's on screen and ramp lane brightness toward the end of the wind-up, so the faster "now" moment reads. Captures: card strip (both classes), pause screen, a mid-wind-up volley frame.
  - **qa:** tests for the dodge on with 2/1 charges, the new bindings (Ctrl hold-to-preview with WASD and clicks, Shift+Ctrl swap, Space dodges, no clash), `telegraph_scale` (validation and effect), the volley windup and phase-3 floor, and the volley fix. Full suite, the 20 s headless run, SceneSelfCheck, reload soak (Player and bindings change). Check the README keys section and that the CHANGELOG has the slice.
  - **Playtester (short):** smoke check; one run per class with cards and one no-card run. Does the game feel fluid again? Is Ctrl comfortable for Movement while moving with WASD? Do the faster telegraphs and the volley read in time to react?
  - **Close:** OPEN_ITEMS asks the director to play one run per class: fluid again? Volley speed right? Ctrl OK? And a no-card run: still winnable?

- [x] **MAP0, branching map design doc — DONE 2026-11-03.** game-lead ee38ac0, e77653d, adf6468 (`docs/MAP.md`, GDD §9 [PROPOSED] summary, MAP1/MAP2/MAP3 briefs, DECISIONS "2026-11-03 - MAP0", OPEN_ITEMS D31-D33); docs 2762144. No tag. (Original header: director, 2026-11-02, D28 = A; game-lead alone, docs only. After H3.)
  - **Goal:** a concrete, data-driven plan for the branching map (GDD §9), in a new `docs/MAP.md` plus a GDD §9 summary marked [PROPOSED].
  - **Contents:** node types (combat, elite, rest, merchant, relic stage, curse/buff room, mini-boss, boss), choices per step, a layout for a 10-room run (rooms counted along any path), and how difficulty and reward rise together ("the hardest path is the most rewarding").
    - **Relics (D22 = C):** a relic-hunting route can reach **6-8 relics**, a route that ignores relics about 2-3; hard cap 10. The merchant sells **several relics at once** if you have the gold; prices come from rarity (`run.json`). Nodes call BD2's relic offer function (BUILD_DEPTH §4.6).
    - **Currencies:** gold (its income per node and what it buys: relics, card removal, maybe cards), and whether XP and between-run points (GDD §8 [OPEN]) start in the first map build or are only reserved.
    - **Rest node (D30 = A, director 2026-11-03):** no relic at rest. The director may remove the rest-room heal altogether (GDD §9), because Recovery already heals. Propose what a rest node offers without the heal (for example card removal only, or no rest node at all) as one of the D31+ questions, with a default.
    - Data format for map generation (seeded, like rooms today), the map screen at a sketch level (ux builds it later), and the first map build's slice brief with acceptance, owners and the loop.
  - **Director questions:** at most 3, each with a default, numbered from **D31**. Don't wait for answers.
  - **Done when:** `docs/MAP.md` exists, GDD §9 has the [PROPOSED] summary, the first map build's brief is in this ROADMAP, OPEN_ITEMS has the questions, and tech-writer has done a CHANGELOG pass.

- [x] **PL3, small polish — DONE 2026-11-04.** gameplay-dev 9a86757 (tooling), fbfd86c (knockback bug fix); ux da418aa; qa PASS 16387bf/e38bdd2 (`docs/reviews/2026-11-04-pl3-qa.md`, 1289/1289); playtest 7f21afb (no blocker; `docs/playtests/2026-11-04-pl3-short.md`); docs e03c4b8. Tag `playtest-2026-11-04-PL3`. Item 13 measured, not retuned (D36). (Original header: small polish after W1b, game-lead 2026-10-30.)
  - **From the W1b playtest (docs/playtests/2026-10-30-w1b-wizard-cards.md):**
    1. **Ward has no visible cue while it's up** (only a 0.5 s ring on cast). Add a persistent cue for player armor buffs (ring, tint or buff pip), data-driven. ux, with a gameplay hook if needed.
    2. **Three Bolts and Overqualified Bolt look like the auto bolt.** Give card projectiles a distinct look (size, colour, trail) via `look` params. Overqualified Bolt should read as heavy. ux.
    3. **The boss smash knocks an idle Wizard about 8 m to the arena edge** (void in view, boss off screen). Check the knockback against the arena bounds and clamp it if needed. gameplay-dev.
    4. **Volley hits may show as one faded "4"** (unconfirmed). Check how damage numbers merge for multi-pellet hits. ux.
    5. **Damage numbers drawing over the boss bar** (from the W1b ux backlog).
    6. **~~Fan of regrets telegraph~~ Moved to H3 (2026-11-02)**, because D29 = B speeds the volley up and its lanes must be fair first. Was (W1b playtest problem 3, added at W1b close): cap the lane length to what's on screen and ramp lane brightness toward the end of the wind-up so the "now" moment reads. Telegraph look only, no timing or damage change. ux. **Added at H2 close:** the H2 playtest saw pellets hit a bot that wasn't in a lane at the fire moment (5 of 30 pellets hit, though the bot was in a lane for only 1 of 6 volleys). Check whether pellets or lanes stay dangerous after the fire moment, or whether the lane drawn doesn't match the pellet path. If so, it's a correctness fix, not only a look fix (gameplay-dev). Tooling: a boss scenario with a fixed attack, so a mid-volley frame can be captured.
  - **From K1 (playtest docs/playtests/2026-11-02-k1-short.md, added at K1 close; all ux):**
    7. **Reward and removal screens: drop the number keys (director, 2026-11-02, call 16; replaces the old items 7-8).** Remove the number-key shortcuts that pick an option or jump to a column, and their hints ("Keys 1-4 highlight", "Keys 1-%d jump to a column") and option-number badges. Mouse selection is enough; arrows and Enter stay (he named only number keys). After H2 no slot key is a digit, so the "Key 1" chip and the "Utility (1)" header clashes go away with it. If the chips still say "Key Q", restyle them as a key cap. D26's reward/remove bullet is then moot. **D26 = A (director, 2026-11-02):** fixed menu keys (Enter, arrows, class-pick 1/2) may stay written out; nothing moves into the bindings file.
    9. **~~Game over and a mashed Space.~~ Moved to H2** (Space becomes the Movement key there). Was: GameOverScreen has no arm delay or Space guard, unlike RunPromptScreen (0.4 s), so a dodge mash on death may hit "Try again". Add the same arm delay. Build the "Enter or Space" hint from the `ui_accept` binding if InputLabels can, otherwise keep it literal (scan allowlist).
    10. **Wizard card strip is cramped** ("Next: Footwork, Allegedly" fills the width). Also, the reward "X (Key) now: A / B / C" line runs to 4 lines on some cards. Neither clips yet.
  - **From H3 (playtest docs/playtests/2026-11-03-h3-short.md, added at H3 close):**
    11. **Volley gaps are slivers (ux).** The lanes now brighten toward the fire moment, but the safe gaps between the five lanes are hard to find in 0.75 s (0.64 s in phase 3). Try a safe tint on the gaps, or boss-bar text pointing at the dodge. Look only.
    12. **Dodge pip is small and far from the action (ux).** Add a return flash (or a larger pip) when a charge comes back, and capture the EMPTY state (needs a capture-time dodge press; tooling, gameplay-dev).
    13. **Is the volley fair to the Wizard? (gameplay-dev, then qa)** In the bots' boss rooms the volley is 100% of the Wizard's damage (about 30 HP per boss visit against 22 max), and it landed in 13 of 13 volleys although the bot was in a lane at the fire moment in only 4. The likely cause is the known bot blind spot: lanes clear at the fire moment, pellets keep flying about 1.8 s, and the default bot doesn't dodge in-flight pellets (DECISIONS "2026-11-03 - H3 build"). Measure: a `boss_volley` scenario bot that stands between lanes, then in a lane, and logs HP; and Wizard boss runs with `-DodgePellets`. If a pellet-aware Wizard still can't survive the volley, game-lead takes the numbers to the director (no retune without him).
  - **Tooling (gameplay-dev):** scenarios give the Wizard its own deck (today they show the Rogue's card row); a capture trigger on a boss attack starting.
  - **Housekeeping — DONE before H2 (D21 = B):** 642d546 (`docs/.gdignore`), c3f5ac1 (`.uid` files), 98595d4 (`.gitattributes`; no renormalisation needed). Kept below for the record.
  - **Housekeeping (director, 2026-11-02, from STATE):**
    - commit the untracked `.uid` files (`tests/unit/w1b_content_test.gd.uid`: qa, **done in 0119999**; `tools/ux_capture.gd.uid`: ux-designer);
    - add `docs/.gdignore` so Godot stops importing playtest PNGs, and delete the stray `docs/playtests/img/*.import` files (game-lead);
    - (note at K1 close: a `.gitattributes` already exists since 3432239; extend it as below, and the normalisation commit is still needed, since docs in HEAD still mix CRLF and LF) add a `.gitattributes` (text=auto, LF in the repo for `.md`, `.gd`, `.json`, `.tscn`, `.tres`, `.cfg`, `.godot`; binaries marked binary) and do the one-time line-ending normalisation in a **single commit of its own with no other changes**, so later diffs stay readable. Owner: gameplay-dev (repo config; it runs the suite afterwards to prove nothing broke). tech-writer checks its docs still render.
  - **Loop:** gameplay-dev -> ux -> qa -> playtester (short) -> tech-writer -> close. Tag `playtest-YYYY-MM-DD-PL3`.
  - **Carry-overs from the PL3 qa review (docs/reviews/2026-11-04-pl3-qa.md; non-blocking; do with BD1's gameplay-dev step):** `--class=bogus` with a scenario prints its error twice and runs as the Rogue with exit 0 (the run path exits 2); a scenario with its own `character` plus a different `--class` gives a mixed player (pick one rule and log it); `-StartRoom 99` clamps silently (warn); an earlier suite leaves the `dodge` action pressed (find and release it; qa). ux: card strip about 3 px over at 1024x600 (pre-existing rounding; pinned by a test). Added at close: the `pl3_*` capture scenarios use a random deck, so `pl3_heavy_bolt` may not hold Overqualified Bolt (the playtest captured only auto bolts): give them fixed decks (gameplay-dev); stale `digit_target` comments in `RunPromptScreen.gd` lines 44 and 467 (ux); capture scenarios for the reward and removal screens and the boss smash (gameplay-dev).

- [ ] **BD1, synergy core (director, 2026-11-02; brief rewritten from `docs/BUILD_DEPTH.md` at BD0's close; after PL3). Full loop. Tag `playtest-YYYY-MM-DD-BD1`.**
  - **Goal:** cards start to read the board and each other, so two Fire Rogue (or Fire Wizard) runs with different plans play differently. GDD §4a, BUILD_DEPTH §3, §5 (R-A, R-B, W-A, W-C), §6, §7, §2. Relics are **BD2** (D24 = A, director 2026-11-02).
  - **gameplay-dev:**
    1. **Tags:** derive tags from effects at load (Projectile, Melee, Area, Zone, Dash, Heal, Burn, Bleed, Buff; rules in BUILD_DEPTH §3.1). New `data/keywords.json` (id, display name, rule text) with Primer, Payoff, Keystone; an optional validated `keywords` array on cards. A card's tags are exposed to the UI and conditions.
    2. **`CombatEvents` autoload (relay only, no game state):** `card_cast(slot_type, card_id, tags)` emitted next to `CardSlotController.card_cast`, plus a cast history (time, slot, tags; last few seconds) that conditions read. The other relay events are BD2's. Logged in DECISIONS.
    3. **Effect `condition`** on any card effect, with three types: `target_has_status` (per target hit, in the cone/aoe/projectile/zone hit paths), `cast_within` (`slot_type` or `tag`, `seconds`), `zone_active` (one of the caster's Zones is alive). False means that effect is skipped. Validator: known types, required params, numbers in range.
    4. **Primed buff:** `buff` gains optional `consume_on_cast` (slot type or tag) and `charges`. New buff stat `slot_cooldown_skip.<slot>` (or an equivalent the dev picks and logs): the next matching cast has no cooldown.
    5. **Stat `status_damage_mult.<status_id>`** read by damage-over-time ticks the caster applies.
    6. **`aoe` param `anchor: "caster"`** so a delayed area can lock at the caster's position (`EffectTemplates.gd:328` locks at the aim point today).
    7. **Content (8 NEW cards, numbers in BUILD_DEPTH §5):** `fire_fan_the_flames`, `fire_kindling`, `rogue_drive_by`, `rogue_momentum`, `fire_heat_sink`, `fire_slow_burn`, `wizard_parting_gift`, `wizard_well_actually`. Every Attack card passes `CardDamageRule` on unconditional damage (no `rule_exception`). The preset starting decks don't change.
    8. **Debug decks:** `rogue-kindling`, `rogue-hit-and-run`, `wizard-controlled-burn`, `wizard-departure-lounge` (the legal decks in BUILD_DEPTH §5).
    9. **Plan-aware bot policy** (`-Plan`) in the bot sim: casts a card when its condition is live or after a 1.5 s hold, uses the dead-card swap on a card that can't pay off soon, uses its dodge charges to escape and may spend Movement offensively (dodge back, D29 = B; BUILD_DEPTH §8). It reads the `condition` blocks; no per-card script.
    10. Expose for ux: per slot, the current card's tags, its condition text, whether the condition is live (target conditions: any enemy inside the card's preview area meets it), and primed state with time left.
  - **ux-designer:** tag chips (up to 3; keywords first), the condition line in `CardSummary` (strings from `run.json` `ui.effect`), the live-condition slot glow, the primed marker, and a "Keystone" chip on reward offers. Fits at the minimum HUD scale. Captures: a lit glow, a primed slot, a reward screen with a keystone.
  - **qa:**
    - unit tests for tag derivation, each condition type (true and false), primed buff consumption, `status_damage_mult`, `anchor`;
    - content validation: keywords known, conditions valid, the 4 debug decks legal, all new Attack cards pass the damage rule;
    - **sim reports (informational, not gating):** removal pain, run fingerprint spread and archetype parity for the 4 archetype decks vs the standard deck under `-Plan` (12+ seeds, 10 rooms; targets in BUILD_DEPTH §2); the no-card check still at or under 25%;
    - full suite, the 20 s headless run, SceneSelfCheck, reload soak (new autoload). **Sim hashes:** the standard policy's hashes must not change unless a new card enters a preset deck (it shouldn't); new policies get new baselines.
  - **Playtester:** one run per archetype deck (`--deck=...`). Does the glow read? Does the plan change how you press keys? Does Hit and Run's offensive dash feel like a risk?
  - **Close:** OPEN_ITEMS item 35 waits until BD2 (relics) unless the director wants to look now; game-lead adds a "what to try" note for the 4 decks.

- [ ] **BD2, relics (after BD1, before 3d; D24 = A). Full loop. Tag `playtest-YYYY-MM-DD-BD2`.**
  - **Goal:** run-scoped relics that change rules, found during a run and reset after it (GDD §4a goal 3). BUILD_DEPTH §4.
  - **gameplay-dev:** rest of the `CombatEvents` relay (`hit_landed` with `origin`, `status_ended` with reason incl. `owner_died` fired before the node frees, `enemy_killed`, `attack_fired`, `dash_ended`, `player_damaged`, zone/room relays); `RelicManager`; `data/relics/*.json` loader + validator; `RunState.relics` + save round trip; relic offers from **elite rooms** (pick 1 of 3 or skip, replacing the card offer) and a new **relic room** in the straight run (1 per run, rooms 2-8, not next to the rest room or elite; pick 1 of 3 or skip) (D22 = C in the director's wording; BUILD_DEPTH §4.1). Rest rooms and card reward screens don't offer relics (D30 = A, director 2026-11-03). **Hard cap 20** (`run.json` `relics.max_owned`; D34 = C, director 2026-11-04; was 10). **At the cap, offers still appear: taking a relic first asks which owned relic to give up** (cancel keeps what you have); test with a low cap, since 20 can't be reached in 10 rooms. **No duplicates:** offers skip owned relics and relics given up this run (`RunState.relics_given_up`, in the save round trip). With fewer than 3 eligible relics the offer shows what's left; with none, the source gives its card offer. Numbers in a `run.json` `relics` block. The merchant and more relic stages come with the map (MAP1/MAP2; on the map the relic room is a node, and BD2's interim relic room stays only in the straight run, `map.enabled` false); recursion guard (relic-origin events ignored by default, chain depth 1); sources list includes the future map nodes. 7 relics: Pyre Insurance, Smoldering Grudge, Lingering Embers, Exit Strategy (may slip to BD3), Second Wind, Spite Knuckles, Heavy Sigh. Bot sim: relic picks (first offered that matches the deck's archetype, else first).
  - **ux-designer:** HUD relic row with trigger flash; relic offer panel (relic frame, "Relic" label) on the elite and relic-room screens, plus its at-cap "give one up" step; relic list in the pause screen.
  - **qa:** event relay tests (incl. Burn ending on death), each relic's rule, the swap at a low test cap (cancel keeps your relics), offers never include owned or given-up relics, the given-up list survives a save round trip, an offer with fewer than 3 eligible relics, the recursion guard, save round trip, a corrupt relic file fails validation loudly; sim checks rerun with relics; no-card runs without relics still at or under 25%; full gates and reload soak.
  - **Close:** "Needs your eyes" item 35 (build twice with different plans; does removing a keystone hurt?) and the vision-check round 2.

- [ ] **BD3, depth 2 (after 3d unless the director moves it).** Stacking statuses (`stacking`, `per_stack`, `status_max_stacks.<id>`), `scale`, `detonate_status`, triggers on card buffs, conditions `self_stacks_at_least`/`deck_count_at_least`/`hp_below`; archetypes R-C Bleed Out, R-D Grudge Brawler, W-B Thesis, W-D Ward Battlemage (about 9 NEW cards, incl. a 4th Rogue Utility card); the other 8 relics; stack counts on enemies. The sim checks become gating after tuning. Brief to be written at BD2's close.

- [ ] **3d, loadouts (after BD1, BD2 and MAP1-MAP4, in the order above; D33 = B)**
  - **Goal:** from the second run on, you can build a starting deck, save it as a loadout and start runs with it. GDD §9 ("Starting decks and loadouts [DECIDED]", "Loadouts [DIRECTOR DECISION, 2026-11-02]"), §8 (passives linked to loadouts, free respec), §4 (deck rules).
  - **Changes from the director, 2026-11-02 (they override the items below where they conflict):**
    - **A. Slots:** at least **5 loadout slots per class** (data; replaces "3 save slots"). The player names each loadout (free text). Only Fire exists, so the element isn't enforced.
    - **B. Availability (D23 = A, director 2026-11-02):** each card gets an `availability` field in data: `starter`, `reward` or `locked` (the unlock condition is [OPEN]; `locked` cards carry a condition text or "TBD"). Validated. The editor shows a badge on each card ("Starter", "Reward", "Locked: <condition or TBD>"). **Today every existing card is tagged `starter`** (see D23 for why); BD1+ content decides per card.
    - **C. Plan list:** a loadout may hold reward-only and locked cards as a **plan** next to its starting deck. Reward screens highlight offered cards on the current loadout's plan ("On your plan"). The starting deck holds only `starter` cards and obeys the deck rules.
    - **D. Passive hook:** each loadout reserves an empty, versioned `passive_allocation` field. Don't build the tree; nothing else to build for respec.
    - **E. Coupling:** loadout code stays on the deck APIs only, so BD1's tags and relics slot in without rework.
    - **F. Gates:** "sim hashes unchanged" means the latest re-baselined hashes in STATE (H2 changes them again after H1). Tag `playtest-YYYY-MM-DD-3d` (replaces the stale 2026-10-29 name).
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
    - ~~3 save slots~~ 5 per class (director, 2026-11-02).
    - A finished run counts whether it was won or lost.
  - **Owner sequence:** gameplay-dev (profile, storage, rules, placeholder screens) -> ux-designer (start screen and editor) -> qa -> playtester -> tech-writer -> close, tag `playtest-YYYY-MM-DD-3d`. **This closes Milestone 3** except the out-of-scope items below.
- Later in M3 or after: shops and drops (GDD §14 item 1, [OPEN], not started).
- [ ] **MAP1, the map (after BD2; D28 = A). Full loop. Tag `playtest-YYYY-MM-DD-MAP1`.** Plan: `docs/MAP.md` (MAP0).
  - **Goal:** the run becomes a branching map of 10 rooms (GDD §9). The player picks a route; gold is earned. Merchant, mini-bosses and curse/buff rooms come later (weights 0 in data).
  - **gameplay-dev:**
    1. `data/map.json` loader and validator (MAP.md §6), including unknown-key rejection; `map.enabled` switch (shipped **on**). With it off, today's straight run (`RunGenerator`, BD2's relic room) is unchanged.
    2. Seeded generator (MAP.md §3): grid walks with no crossing edges, typed nodes with room windows and `no_repeat`, path rules checked on every path, deterministic redraws, loud error after `max_attempts`. Fight nodes get a `wave_id` as today. MAP1 ships `relic_route` [5, 7] (no merchant yet).
    3. Node handling: combat (card offer + gold), elite (BD2 relic offer + gold), relic_room (BD2 relic offer), rest (today's rest), boss. Gold rolls seeded from run seed and node id (`run.json` `gold`).
    4. RunState: `map`, `path`, `gold`, `xp_earned` (0, reserved); save round trip and `equals`; mid-map restore.
    5. Debug: `--run-room=N` follows the `first` route; a `--map-seed`/print helper if useful.
    6. Bots: `-Route first|relic|safe|random` in the bot sim; route summary in the report (relic estimate, fights, elites, gold).
  - **ux-designer:** the map screen (MAP.md §7): left to right, node shapes from `RunIcons` plus new shapes for the new node types, taken path bright, current ring, reachable highlighted, hover/focus text from data, legend, gold, mouse + arrows/Enter; view-only from pause. Gold on the run HUD. Fits 1024x600 without scrolling. Captures: start of run, mid-run, room 9.
  - **qa:** generator tests (determinism; 1000 seeds with zero failures; every rule on every path; no crossing edges; every node reachable), validator tests, save round trip mid-map, the switch off gives today's straight run and its old bot-sim hash; full suite, headless run, SceneSelfCheck, reload soak; re-baseline the hashes with `-Route first`. Check README and CHANGELOG.
  - **Playtester:** does choosing a route feel like a decision? Is the map readable at a glance? Does the run still last about as long?
  - **Close:** OPEN_ITEMS asks the director to play a run: is the map clear, do the choices matter?
- [ ] **MAP2, the merchant (right after MAP1). Full loop. Tag `playtest-YYYY-MM-DD-MAP2`.** Plan: `docs/MAP.md` §4.4.
  - **Goal:** gold buys things. The merchant sells several relics at once (D22 = C), cards and card removal.
  - **gameplay-dev:** merchant node (`map.json` weight about 8, `max_merchants` 1); stock seeded from run seed and node id: 3 relics from source `merchant` (BD2 offer function; no owned or given-up relics; at the cap, buying uses BD2's give-one-up step), 3 cards at 40 (reward weights), removal 50 then +25 per removal (through `can_remove`); `run.json` `merchant` and `relics.prices` (60/90/130); RunState `merchant_removals` + save; `relic_route` back to [6, 8]. Bots: the `relic` route buys relics first, `safe` buys a removal then a card.
  - **ux-designer:** merchant panel: prices, gold left, disabled items with the reason (too expensive, removal would break a slot minimum); at the relic cap a relic is buyable through the give-one-up step, buy several then leave; the removal list reuses the rest-room list. Captures.
  - **qa:** buying (gold never negative, several relics in one visit, the swap at the cap, no duplicates in stock), removal guard, prices from data, determinism, save mid-merchant; bot checks: median relics on `relic` routes 6-8 and on `safe` routes 2-3; no-card gate. Full gates.
  - **Playtester:** is a relic route a real alternative to a card route? Does the merchant feel worth the detour?
  - **Close:** item 35 (builds) gets the map; OPEN_ITEMS asks whether the relic route feels different.
- [ ] **MAP3, three acts (right after MAP2; D33 = B, director 2026-11-04). Full loop. Tag `playtest-YYYY-MM-DD-MAP3`.** Plan: `docs/MAP.md` §1, §4.5, §8. Detailed brief at MAP2's close.
  - **Goal:** a run is three acts of 10 rooms (30 rooms). Acts 1 and 2 end in a mini-boss, act 3 in the final boss. 30-45 minutes per run, and you can save and come back later (GDD §9).
  - **Scope:** acts 2-3 as their own maps; 2 act-end mini-boss encounters (`run.json` `tiers.mini_boss`, existing enemies + adds); act scaling (data multipliers per act; values from the sim, not hand-picked); new wave lists for acts 2-3 (today's 4 combat + 1 elite list would repeat badly); act transition screen ("Act 2"); "Room N of 30"; relics and gold per D34 = C (MAP.md §4.5: cap 20, per-act rules, merchant 80/120/170, act-end mini-bosses give gold + a rare card offer, acts 2-3 elites a 25% rare card chance, a card `rarity` field and rare cards per pool); rejects stay 3 per run (D35 = A). **Relic content:** at least about 22 relics eligible per class (pool + neutral) so a 14-17 hunter still sees 3 choices late in the run; BD2 + BD3 sketch 15 in total today, so MAP3/MAP4 add the rest (count set at MAP2's close). **Save and resume:** autosave at every room boundary, one slot, `user://` with an injectable path, versioned and validated, built on RunState `to_json`/`equals`; Continue on the start screen; deleted on win or loss; quitting mid-fight restarts the room. Must ship in this slice, not later.
  - **Acceptance (headline):** median bot run time 30-45 min (both classes); `relic` route median relics 14-17 and `safe` 4-6 (D34 = C, MAP.md §4.5); no-card gate holds; save, quit, resume gives the same run (tested).
- [ ] **MAP4, curse and buff rooms (after MAP3, before 3d; D33 = B). Full loop.** Plan: `docs/MAP.md` §2. Relic `curse` block (validator; the panel shows the curse); curse room (a strong relic with a curse, or leave) and buff room (a minor relic, or leave); 2-3 cursed and 2 minor Fire relics; optional `mini_boss` nodes inside acts at low weight. Brief detailed at MAP3's close.

## Milestone 4 — Second class/element, subclasses, passive tree prototype, balance sim
Not started. Per GDD §13: Wizard + Water added, 2 subclasses each for Rogue/Wizard/Fire/Water, first passive tree prototype (30-40 nodes), headless balance simulation grown out.

## Milestone 5 — Art/audio pass, friends-and-family playtest
Not started.
