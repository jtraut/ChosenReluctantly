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
  - **tech-writer** owns `README.md`, `docs/CHANGELOG.md`, `docs/ASSETS.md`, `docs/ARCHITECTURE.md`, `docs/RESOLVED.md` (director, 2026-11-02).
  - **game-lead** owns `docs/GDD.md`, `docs/BUILD_DEPTH.md`, `docs/MAP.md`, `docs/DECISIONS.md`, `docs/ROADMAP.md`, `docs/STATE.md`, `docs/OPEN_ITEMS.md`, `CLAUDE.md`.
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
- **Director open items (standing rule, 2026-10-28):** `docs/OPEN_ITEMS.md` is the single place listing everything waiting on the director, in plain language. game-lead owns it, and updates it at the end of every slice, at the end of every multi-agent prompt, whenever a new director-facing question appears, and before stopping for any reason. Every role reports director-facing questions to game-lead in its hand-back, not buried in its own docs. When the director answers, game-lead records the answer where it applies (GDD, CLAUDE.md, and the changelog via tech-writer), updates the affected files, and unblocks dependent work.
  - **OPEN_ITEMS holds only active items (director, 2026-11-02).** It lists only what still needs the director's input or eyes: a status line, the latest tag, a short "How to playtest", "Needs your decision", "Needs your eyes", and questions waiting for a later slice. Anything resolved, answered or acknowledged leaves OPEN_ITEMS. That includes decisions, checklist answers, feedback that has been recorded, calls he has confirmed, and "what's new" notes he has played.
  - **`docs/RESOLVED.md` is the archive, and tech-writer owns it.** game-lead removes answered items from OPEN_ITEMS and lists them, with the director's answer and where it was recorded, in the doc handoff note. tech-writer adds them to RESOLVED.md at the top, newest first, in its next docs pass. Nothing is dropped: if an item is removed before the pass, the handoff note names the commit that still holds the text. The final message of any session ends with a line like: "docs/OPEN_ITEMS.md: N need your decision, M need your eyes."

- **Cost controls (director, 2026-11-12):**
  - **Session size.** gameplay-dev, ux-designer and qa stop at a clean point after about 150 tool calls, or once the work is clearly large. They commit, put a `Remaining:` list in the commit body and the hand-back, and stop. game-lead copies the list and the commit hash into STATE "In progress", commits, then starts a fresh agent for the rest. game-lead sizes briefs to one such session, smaller than MAP3b's sittings.
  - **Playtest gate.** Every slice brief is tagged `safe to chain` or `needs your play first`. A slice that tunes the feel or balance of a slice the director hasn't played waits for his playtest.
  - **Eyes items expire.** Every "Needs your eyes" item states its default. If it isn't answered by the close of the slice after the one that added it, the default applies and game-lead moves it to the RESOLVED handoff as "expired, default kept".
  - **Record each answer once.** A director answer goes where it applies (GDD or CLAUDE.md), leaves OPEN_ITEMS, and gets one line in STATE's pending docs-pass list. ROADMAP changes only if a brief changes; DECISIONS only for game-lead's own judgment calls.
  - **STATE.md is short:** in progress, the exact next step, current baselines, pending docs-pass items, known issues and open questions. No slice history: that's ROADMAP and CHANGELOG.

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

## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), recorded as a `Status:` line in each issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` + `docs/adr/`, created lazily. See `docs/agents/domain.md`.
