# Handoff State

> **Director: what's waiting on you is in `docs/OPEN_ITEMS.md`.**
> **Project history in plain language: `docs/CHANGELOG.md` (newest first). Code map: `docs/ARCHITECTURE.md`.**

Last updated: 2026-11-02. **Run order (director, 2026-11-02):** W1b is closed. Next: **K1 -> H1 -> BD0 -> PL3 -> BD1 -> 3d**. Briefs for all six are in ROADMAP ("Run order after W1b"). Each build slice gets the full loop and, at close, a `playtest-YYYY-MM-DD-<slice>` tag plus an update to OPEN_ITEMS "While you were away" and the tag list. BD0 is docs only (game-lead alone, no tag). Done so far: A1, T-decks, W1a, PL2, F1, P-dodge, W1b.

## What's done
- Milestone 2, Post-milestone polish 1, C1, 3a, 3b, 3c, A1, T-decks, W1 (W1a + W1b), PL2, F1, P-dodge (tags `playtest-2026-10-29-C1`, `-3a`, `-3b`, `-3c`, `-A1`, `-T-decks`, `playtest-2026-10-30-W1a`, `-PL2`, `-F1`, `-P-dodge`, `playtest-2026-11-02-W1b`).
- **W1b closed 2026-11-02:** content aaa933a .. playtest d74e0df; docs ab00c50 + d6a449a. The director's keybind commit 24530e4 left 3 stale input tests failing; qa fixed them test-only in 0119999 (tests now read slot keys from the InputMap). Carry-overs: kiting Wizard nearly unhurt in rooms 1-9 (H1); Fan of regrets telegraph added to PL3 as item 6.
- Director answers D1-D18 and checklist items 11-24 are recorded and built.
- **2026-11-02, Part 0 of the director's 10/31-11/2 notes (docs only, game-lead):** GDD §1, §3, §4, new §4a, §8, §9, §14 items 11-12; ROADMAP briefs for K1, H1, BD0, BD1, PL3 housekeeping, 3d changes A-F; OPEN_ITEMS updates; human playtest entries; DECISIONS "2026-11-02 - Recording the director's 10/31-11/2 notes". All 2026-11-02 director decisions are in the CHANGELOG (ab00c50).
- The repo runs. Suite 1156/1156 at 0119999. Arena hash baseline 2484586390 (30 s seed 1; 90 s 3255493562). **H1 will change the sim hashes; re-baseline and record them here at its close.**

## In progress
- **K1 started 2026-11-02:** gameplay-dev is on items 1-4 (label helper, R for slot 5, binding validator, data for ux). Pre-check: R is not bound to anything today; `InputBindings.gd` builds key events with `physical_keycode`, so the helper must convert for display. If this session stops mid-K1, check `git log` for gameplay-dev's K1 commits, then continue with ux-designer.
- Untracked on disk, not ours to commit: `tools/ux_capture.gd.uid` (ux) and `docs/playtests/img/*.import` (Godot imports; PL3 adds `docs/.gdignore`). Don't sweep them into other commits.

## Exact next step
1. **K1, gameplay-dev first:** the label helper, the R binding for slot 5, and the validator, per the K1 brief in ROADMAP. Then ux-designer (HUD hints, the `str(i + 1)` in `src/ui/Hud.gd:25`, "Slot %d" in `RunOptionCard.gd` and `RunPromptScreen.gd`, pause-screen key text) -> qa (incl. reload soak) -> playtester (short) -> tech-writer -> close, tag `playtest-YYYY-MM-DD-K1`.
   - Tests now read slot keys from the InputMap, so moving slot 5 to R shouldn't break the cast-input tests. qa still re-runs them.
2. Then H1, BD0, PL3, BD1, 3d per ROADMAP.

Re-run the reload soak whenever Main, Juice, Player or the autoloads change (K1 does).

**D-number reservation:** D21 = run order, D23 = loadout card flags (director-assigned). **D22, D24, D25 are reserved for BD0's questions** (at most 3). Next free after that: D26.

**Orchestration:** game-lead has the `Agent` tool. Restart with `claude --agent game-lead` and say "continue the pass". Run roles one at a time; each role commits only its own paths.

## Open questions
All director-facing items are in `docs/OPEN_ITEMS.md` (D19, D20, D21, D23 waiting; none blocks).
