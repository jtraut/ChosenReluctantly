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

## Milestone 2 — Combat Feel Prototype (current)
Goal: one arena room where moving, aiming, and using card slots already feels good. The only question this milestone answers is "is the core combat fun?"

- [x] Camera and player: fixed isometric 3D camera, capsule player, WASD movement, mouse-raycast aim, smooth camera follow
- [x] Basic attack: left click, fixed cooldown, melee arc (see DECISIONS.md)
- [x] Dodge roll: Space, i-frames, own cooldown, universal (separate from Movement slot)
- [x] Generic stat-modifier system (stub values, data-driven hook for future passives/equipment)
- [x] Card data schema + loader + validation (fails loudly on malformed JSON)
- [x] Effect-template registry: projectile, cone, aoe, dash, heal, apply_status, buff
- [ ] Card slot system: 5 data-driven slots, mini-decks, shuffle/reshuffle, cooldown = base + modifier, dead-card swap with penalty cooldown
- [x] Status effect system, generic, with Burn as the first implementation
- [ ] Damage/resistance model: elemental-only resistance, caps per GDD §7
- [ ] Enemies: melee chaser, ranged shooter, resistant elemental type; health, hit reactions, knockback, simple chase AI
- [ ] Wave spawner for the arena
- [ ] HUD: 5 slot widgets (name, cooldown sweep, next-card preview), health bar
- [ ] Debug overlay (F3): FPS, slot cooldowns, deck contents
- [ ] Starter card set: ~12-15 JSON cards for Fire Rogue (class/element/neutral pools)
- [ ] Juice pass: hit-stop, screen shake, damage numbers, hit flash, enemy attack telegraphs
- [ ] Unit tests: cooldown math, slot cycling/reshuffle, dead-card swap penalty, resistance math, Burn tick, card schema validation
- [ ] Headless bot-simulation stub in `/tools`
- [ ] QA pass over the milestone before marking done

## Milestone 3 — Card system and run loop (next, outlined only)
Not started. Expected scope per GDD §13 milestone 3 and §9:
- Multi-room procedural run structure (room graph, not just one arena)
- Post-battle card reward screen (accept/reject, 3-reject cap per run)
- Deck-clean rewards / routing choices
- A boss encounter
- Loadout saving between runs (starting from run 2, per GDD §9)
- Resolve open question: single-card offer vs. choice of several (GDD §14 item 1)
- Resolve open question: shops/drops alongside post-battle rewards (GDD §14 item 1)
- Expand the headless bot simulator from a stub into a real multi-room balance tool

## Milestone 4 — Second class/element, subclasses, passive tree prototype, balance sim
Not started. Per GDD §13: Wizard + Water added, 2 subclasses each for Rogue/Wizard/Fire/Water, first passive tree prototype (30-40 nodes), headless balance simulation grown out.

## Milestone 5 — Art/audio pass, friends-and-family playtest
Not started.
