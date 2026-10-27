# Handoff State

Last updated: 2026-10-26. **Milestone 2 is done.**

## What's done
Everything in `docs/ROADMAP.md`'s Milestone 2 list is checked off and verified: isometric camera + Player (movement/aim), basic attack + dodge roll, the full combat/status/effect-template/card architecture (`StatModifiers`, `Health`/`Hurtbox`/`CombatMath`/`MeleeQuery`, `StatusEffectManager`/`StatusDatabase`+Burn, all 7 `EffectTemplates`, `CardSchema`/`CardDatabase`/`SlotTypeDatabase`/`PoolDatabase`, `CardSlot`/`CardSlotController`), 3 enemy types + wave spawner, the 15-card Fire Rogue starter set, HUD + F3 debug overlay, the juice pass (hit-stop/shake/damage numbers/hit-flash/telegraphs), and a headless bot-sim stub. See `git log` for the full commit-by-commit sequence - each is one vertical slice with its own tests.

Final verification before marking the milestone done: fresh `--headless --editor --quit` (zero errors/warnings), a 20-second `--headless --path . --quit-after 1200` run (zero errors - long enough for enemy waves to spawn, chase, attack, and get hit by the player), full test suite (**62/62 passing**), and the bot-sim (20 rooms clean, no NaN).

Two real bugs were found and fixed along the way (both logged in `docs/DECISIONS.md` with detail): `tools/run_tests.ps1` was silently reporting exit 0 for a failing test (PowerShell doesn't reliably wait on a GUI-subsystem process); and the bot-sim's nodes weren't `is_inside_tree()` until the main loop ticked once, since it drives everything from `_initialize()`.

**What I cannot verify myself:** actually playing it. The DoD's "I can play a wave arena with the Fire Rogue using all 5 slots plus basic attack and dodge" needs the director at the keyboard - everything automatable says the systems are wired correctly and crash-free, but feel/fun is not something I can self-certify.

## In progress
Nothing. Milestone 2 is closed out. Milestone 3 (card system and run loop) hasn't been started - see `docs/ROADMAP.md` for its outline.

## Exact next step
Wait for the director's playtest and design feedback before starting Milestone 3. If asked to proceed anyway: Milestone 3's first real decision is the two open questions it inherits from GDD §14 item 1 (single-card reward offer vs. choice of several; whether shops/drops exist alongside post-battle rewards) - resolve those via the GDD's own `[PROPOSED]` defaults if no new director input arrives, log in `docs/DECISIONS.md`, then start with the room-graph/run-structure data model before the reward screen, since the reward screen needs somewhere to fire between rooms.

## Open questions for the director
None blocking. Everything to actually look at and react to:
- Does the core loop (move/aim/basic-attack/dodge + 5 card slots) feel good? This is literally the only question Milestone 2 was scoped to answer.
- Are the enemy/card damage and cooldown numbers in the right neighborhood, or wildly off? They're placeholder tuning values, logged as such in `docs/DECISIONS.md`.
- Is the Ctrl+number dead-card-swap binding comfortable, or does it want a different default?
- Tone check on the card flavor text (dry/sarcastic, per GDD §11) - too much, too little, right amount?
