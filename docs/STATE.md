# Handoff State

Last updated: 2026-10-26, mid Milestone 2.

## What's done
- Project scaffold, gdUnit4, docs, role agents, README — all committed (see git log).
- Isometric camera rig (fixed orthographic angle, smooth position-follow) + Player (WASD camera-relative movement, continuous mouse-ground-raycast aim) — committed.
- Combat foundation: `Health`, `Hurtbox` (team-tagged, own physics layer), `CombatMath.apply_resistance` (pure, unit-tested), `MeleeQuery` (shared cone hit-test). Player basic attack (left click, melee cone) and dodge roll (Space, i-frames via zeroing the Hurtbox's collision layer, own cooldown) — committed. A `TrainingDummy` debug target exists in the arena for manual verification.
- All headless checks clean: editor parse pass with zero errors/warnings, 60-frame runtime smoke pass, `tools/run_tests.ps1` passing (6/6 tests).
- Input bindings are data-driven (`data/input_bindings.json` + `InputBindings` autoload): movement, dodge, attack_basic defined so far.

## In progress
About to start the architectural core of the milestone: the generic stat-modifier system, the card JSON schema + loader + validation, and the effect-template registry (projectile, cone, aoe, dash, heal, apply_status, buff). This has to land before the card slot system and the starter card set, since both depend on it.

## Exact next step
1. Stat-modifier system: a generic stack of additive/multiplicative modifiers keyed by stat name (e.g. `slot_cooldown.attack_single`), so passives/equipment can push/pop modifiers without combat code knowing their source. Stub values only (no meta-progression yet).
2. Card JSON schema + loader (`src/cards/CardDatabase.gd` or similar) + validation that fails loudly on malformed data — this needs its own unit tests per the milestone's test list.
3. Effect-template registry: projectile, cone (reuse `MeleeQuery`), aoe, dash, heal, apply_status, buff — defined once in code, parameterized by data, so adding a card is a data change.
4. Card slot system: 5 data-driven slots, mini-decks (shuffle/reshuffle), cooldown = base + card modifier, dead-card swap with penalty. Needs its own unit tests (cooldown math incl. negative modifiers, slot cycling/reshuffle, dead-card swap penalty).
5. Then: status effects (Burn first), enemies (melee chaser, ranged shooter, elemental-resistant type) + wave spawner, HUD + F3 debug overlay, ~12-15 starter Fire Rogue cards, juice pass (hit-stop, screen shake, damage numbers, hit flash, telegraphs), headless bot-sim stub in `/tools`.
6. Commit after each vertical slice; update this file again before anything long.

## Open questions for the director
None blocking right now — all Milestone 2 ambiguities were pre-resolved in the kickoff prompt and logged in `docs/DECISIONS.md`. Will surface anything that comes up as it's found.
