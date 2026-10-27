# Working Agreements — Chosen, Reluctantly

This file governs how work happens in this repo. It applies to the main session and to every role agent in `.claude/agents/`.

## Source of truth
- `docs/GDD.md` is the source of truth for design. If a design question isn't answered there, don't invent an answer silently.
- Changes to design require the director's approval. If the GDD marks something `[OPEN]` or `[PROPOSED]` and a value is needed to keep moving, use the `[PROPOSED]` default (or the simplest option), and log it in `docs/DECISIONS.md` with the date and reasoning. Ask the director only when a decision is costly to reverse or contradicts the GDD.

## Content is data, not code
- Cards, slot types, card pools, classes, elements, subclasses, enemies, statuses, resistances, and passive trees live in `/data` as JSON. Adding a card must never require a new script unless it introduces a brand-new effect type.
- Card effects are composed from reusable effect templates (projectile, cone, aoe, dash, heal, apply_status, buff) defined once in code and parameterized by data. Element visuals are a recolor/rescale of the same shared templates, not new templates per element.

## Visuals and audio
- Placeholder only, for now: Godot primitives and CSG shapes, flat colors, free CC0 assets. No custom art, audio, or story work.
- Record every third-party asset's source and license in `docs/ASSETS.md` before it's committed.

## Game feel
- Combat feel is a code priority, not a later polish pass: hit-stop, screen shake, knockback, telegraphs, damage numbers, easing, simple particles.

## Process
- Work in small increments. Commit after each meaningful step with a clear message.
- The director is on a limited usage plan — work may be cut off at any time. Before any long task, update `docs/STATE.md`: what's done, what's in progress, the exact next step, and any open questions. Always leave the repo in a state that runs.
- Define role agents in `.claude/agents/` as short markdown files with a clear job and scope. Run roles one at a time, not in parallel, to conserve usage.
- The `qa` role reviews every completed feature before it's marked done in `docs/ROADMAP.md`.
- Never commit secrets or large binaries. Don't download assets or tools from untrusted sources.

## Engine and language
- Godot 4.x (exact version recorded in `docs/DECISIONS.md`).
- Statically typed GDScript everywhere: typed variables, typed function signatures.

## Repo layout
```
project.godot
/src     - GDScript source
/scenes  - .tscn scenes
/data    - JSON game content
/assets  - placeholder art/audio only
/tests   - gdUnit4 test suites
/tools   - CLI utilities (test runner, headless sim)
/docs    - GDD, decisions, roadmap, state, assets
```
Deviating from this layout requires a logged reason in `docs/DECISIONS.md`.

## Running and testing
See `README.md` for the exact commands.
