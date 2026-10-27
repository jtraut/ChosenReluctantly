# Handoff State

Last updated: 2026-10-26, well into Milestone 2. The architectural core is done; the test runner also had a real bug that's now fixed.

## What's done
- Project scaffold, gdUnit4, docs, role agents, README, isometric camera + Player (movement/aim), basic attack + dodge roll, full combat/status/effect-template/card architecture, and the 5-slot card system wired into Player — all committed, see `git log` for the full sequence (each commit is one vertical slice with its own tests).
- Architectural core, specifically: `StatModifiers` (generic modifier stack), `Health`/`Hurtbox`/`CombatMath`/`MeleeQuery` (combat foundation), `StatusEffectManager`/`StatusDatabase` + Burn (generic status effects), `EffectTemplates`/`EffectContext`/`Projectile` (all 7 effect templates: projectile, cone, aoe, dash, heal, apply_status, buff), `CardSchema`/`CardDatabase`/`SlotTypeDatabase`/`PoolDatabase`/`JsonDataTable` (data-driven cards/slots/pools), `CardSlot`/`CardSlotController` (the 5-slot mini-deck system, wired into `Player` on keys 1-5 + Ctrl+1-5 swap).
- **data/cards/ is still empty** - no starter cards authored yet. Every slot is correctly inert in the running game until that task lands.
- Fixed a real bug in `tools/run_tests.ps1`: it was silently reporting exit 0 even for a failing test (PowerShell's `&` doesn't reliably wait on/read a GUI-subsystem process). Now auto-switches to the `_console.exe` sibling. Verified both directions (deliberately failing test -> 100, clean -> 0).
- 57/57 tests passing headless. Every commit so far verified with: `--headless --editor --quit` (parse/class-cache clean), `--headless --path . --quit-after 30` (runtime clean), and the full test suite.

## In progress
Nothing mid-implementation. Just finished the card slot system commit. Next up is enemies.

## Exact next step (in order)
1. **Enemies + wave spawner:** melee chaser, ranged shooter, and one elemental-resistant type (to exercise `CombatMath.apply_resistance`'s cap). Health/Hurtbox/StatusEffectManager already exist as reusable components (see `scenes/debug/TrainingDummy.tscn` for the pattern) - enemies are mostly: a chase/shoot behavior script + reusing those components + simple hit reaction (flash/knockback) + a spawner that sends waves into the arena.
2. **Starter card set (~12-15 JSON cards)** for the Fire Rogue, into `data/cards/`: some physical Rogue cards, some Fire cards that `apply_status` Burn, a few neutral cards. Must include: one fast card with a negative `cooldown_modifier`, one AoE, one dash-style Movement card, one Recovery card. Dry/sarcastic flavor text per GDD §11 tone. Add the "every real card in data/cards/ validates" test here (enumerate via DirAccess) - this is the specific schema-validation test the kickoff prompt calls out, and it only makes sense once there's real data to enumerate.
3. **HUD:** 5 slot widgets (name, cooldown sweep, next-card preview) + health bar. Debug overlay on F3 (FPS, slot cooldowns, deck contents).
4. **Juice pass:** hit-stop, screen shake on heavy hits, damage numbers, hit flash, enemy attack telegraphs.
5. **Headless bot-sim stub in `/tools`:** runs a bot through N rooms with random card draws, reports crashes/NaN. A stub is fine for this milestone.
6. **QA pass:** review each already-landed feature against the GDD + its tests before marking Milestone 2 done in `docs/ROADMAP.md`.
7. Update `docs/ROADMAP.md` (milestone 2 complete, milestone 3 outlined - already is) and this file, then the final summary to the director per the kickoff prompt's Definition of Done.

## Open questions for the director
None blocking — remaining Milestone 2 ambiguities (enemy stat values, exact juice tuning, card flavor jokes) are all things to log a default for in `docs/DECISIONS.md` and keep moving, not things to stop and ask about.
