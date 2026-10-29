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
- **Doc ownership (director, 2026-10-28):**
  - **tech-writer** owns `README.md`, `docs/CHANGELOG.md`, `docs/ASSETS.md`, `docs/ARCHITECTURE.md`.
  - **game-lead** owns `docs/GDD.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/STATE.md`, `docs/OPEN_ITEMS.md`, `CLAUDE.md`.
  - Other roles don't edit docs they don't own. They report needed changes in their hand-back.
- **Docs pass (director, 2026-10-28):** roles don't call tech-writer for small changes. game-lead runs tech-writer **once at the end of each slice or multi-agent task**, with a short doc handoff note: what changed, the commit range, files touched, new commands, and any new assets with source and license.
  - Exception: whoever adds a third-party asset gives tech-writer the source, author and license at that time.
  - The feature loop is now build -> qa -> playtester -> **tech-writer docs pass** -> game-lead close. game-lead can't mark a slice done until the docs pass is complete.
  - qa's slice review checks that the README commands work and that `docs/CHANGELOG.md` has an entry for the slice.
- **Changelog (standing rule, 2026-10-28; owner changed to tech-writer the same day):** tech-writer maintains `docs/CHANGELOG.md` in its docs pass at the end of every slice and every multi-agent task, covering every notable change (new feature, balance or design change, bug fix, process change).
  - New entries go at the TOP, directly under the header. Insert them by editing at the header, never by appending to the end of the file.
  - If the date already has a section, add to it instead of creating a duplicate heading.
  - Never rewrite old dated entries except to fix a factual error, and note the fix when you do.
  - Balance and design changes always state the old and new values. Director decisions are tagged `[Director decision]`.
- **What goes in `docs/DECISIONS.md` (director, 2026-10-28):** assumptions, defaults, and judgment calls that agents make on their own without an explicit director directive.
  - Director directives are recorded where they apply instead: `docs/GDD.md` for design, `CLAUDE.md` for process and working agreements, and `docs/CHANGELOG.md` with the `[Director decision]` tag. They don't need a DECISIONS.md entry.
  - Existing DECISIONS.md entries, including ones tagged `[DIRECTOR DECISION]`, stay as they are.
- **Director open items (standing rule, 2026-10-28):** `docs/OPEN_ITEMS.md` is the single place listing everything waiting on the director, in plain language. game-lead owns it, and updates it at the end of every slice, at the end of every multi-agent prompt, whenever a new director-facing question appears, and before stopping for any reason. Every role reports director-facing questions to game-lead in its hand-back, not buried in its own docs. When the director answers, game-lead records the answer where it applies (GDD, CLAUDE.md, and the changelog via tech-writer), moves the item to "Recently resolved", updates the affected files, and unblocks dependent work. The final message of any session ends with a line like: "docs/OPEN_ITEMS.md: N need your decision, M need your eyes."

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
/docs    - GDD, decisions, roadmap, state, open items, changelog, architecture, assets; playtests/ and reviews/ reports
```
Deviating from this layout requires a logged reason in `docs/DECISIONS.md`.

## Running and testing
See `README.md` for the exact commands.
