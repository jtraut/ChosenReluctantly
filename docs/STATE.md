# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-02. **Run order (director, 2026-11-02):** finish W1b (tech-writer docs pass -> close), then **K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d**. Briefs for all six are in ROADMAP ("Run order after W1b"). Each build slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag plus an update to OPEN_ITEMS "While you were away" and the tag list. BD0 is docs only (game-lead alone, no tag). Done so far: A1, T-decks, W1a, PL2, F1, P-dodge.

## What's done
- Milestone 2, Post-milestone polish 1, C1, 3a, 3b, 3c, A1, T-decks, W1a, PL2, F1, P-dodge (tags `playtest-2026-10-29-C1`, `-3a`, `-3b`, `-3c`, `-A1`, `-T-decks`, `playtest-2026-10-30-W1a`, `-PL2`, `-F1`, `-P-dodge`).
- Director answers D1-D18 and checklist items 11-24 are recorded and built.
- **2026-11-02, Part 0 of the director's 10/31-11/2 notes (docs only, game-lead):**
  - GDD: §1 pillar 1 note, §3 (bindings rule, Q/E/1/2/R, no-card runs not viable), §4 (swap on Shift+slot key; swap unchanged for now), new **§4a Build depth and synergy**, §8 (passives linked to loadouts, free respec), §9 (pressure pass exception, loadout changes), §14 items 11-12. All tagged [DIRECTOR DECISION, 2026-11-02] or [PROPOSED].
  - ROADMAP: briefs for K1, H1, BD0, BD1 (provisional), PL3 housekeeping (`.uid`, `docs/.gdignore`, `.gitattributes` + normalisation), 3d changes A-F, and the H1 exception in "Later".
  - OPEN_ITEMS: the notes under "Your feedback in progress", Vision check round 1 resolved, round 2 posted (7 questions), D21 and D23 added, eyes items 30-35 queued, "How to playtest" keys fixed to 24530e4.
  - Human playtest entries: `docs/playtests/2026-10-31-director-wizard-no-cards.md`, `docs/playtests/2026-11-01-luke-keybinds.md`.
  - DECISIONS: "2026-11-02 - Recording the director's 10/31-11/2 notes".
- The repo runs. Suite 1156/1156 (W1b qa). Arena hash baseline 2484586390 (30 s seed 1; 90 s 3255493562). **H1 will change the sim hashes; re-baseline and record them here at its close.**

## In progress
- **W1b**: built, qa PASS 6f26ff9 (1156/1156), playtest d74e0df (no blocker). **Remaining: tech-writer docs pass -> game-lead close** (tag `playtest-2026-11-0X-W1b` on the close date; tick the parent W1 item).
- Uncommitted on disk, not ours to commit now: `tests/unit/w1b_content_test.gd.uid` (qa), `tools/ux_capture.gd.uid` (ux), `docs/playtests/img/*.import` (Godot imports; PL3 adds `docs/.gdignore`). Don't sweep them into other commits.

## Exact next step
1. **tech-writer, W1b docs pass.** Handoff note must include:
   - W1b commit range aaa933a..ecec528 (content, tuning, ux, qa, playtest), new Wizard cards and presets, `-BossLog` / `-WizardNoKite` / `-DodgePellets` sim flags, Wizard HP 26 (D20 open), and the CHANGELOG fix the W1b brief asks for (W1a entry's "now happens per slice" wording).
   - **The 2026-11-02 director decisions** from commit 0e2e60c, as `[Director decision]` CHANGELOG entries: Q/E bindings (24530e4, the director's own commit) and Recovery-on-R plan; key labels follow the bindings; pressure pass (enemy speed, then attack rate; exception to the no-retune rule); no-card runs should not win; build depth as pillar-1 priority with relics/enchants reset per run; loadouts (5 named slots per class, card availability flags, passive_allocation field); free respec; passives linked to loadouts; run order K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d.
   - README: the keys are now Q, E, 1, 2, 3 (Shift + same key for swap); K1 changes 3 to R.
2. **game-lead closes W1b** (ROADMAP, STATE, OPEN_ITEMS "While you were away", tag).
3. **K1:** gameplay-dev (helper, R binding, validator) -> ux-designer -> qa (incl. reload soak) -> playtester (short) -> tech-writer -> close.
4. Then H1, BD0, PL3, BD1, 3d per ROADMAP.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-number reservation:** D21 = run order, D23 = loadout card flags (director-assigned). **D22, D24, D25 are reserved for BD0's questions** (at most 3). Next free after that: D26.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md` (D19, D20, D21, D23 waiting; none blocks).
