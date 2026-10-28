# Playtest 2026-10-27: smoke check + idle observation (limited)

## Build and setup
Commit edb92e4, Godot 4.7.2, windowed 1280x720 on RTX 3080, via `tools/capture_screenshot.ps1 -Scenario "" -After "1.0,6.0,12.0"` (screenshots/pt_0..2.png, gitignored). Plus a 600-frame headless boot.
**I could not play.** No input-simulation tool exists, so movement, aim, attack, dodge and card slots 1-5 were NOT tested. Observations below are from an idle player only. Feel, pacing, decisions and tone-in-play are untested.

## Smoke check result
PASS on what I could check; input is UNVERIFIED.
- Headless boot: no errors or warnings, exit 0.
- Windowed: floor, lit and shadowed player, 3 enemy types, enemy HP bars and a camera framing the player are all visible. HUD starts at 30 / 30. 5 card slots show name and "Next:" card.
- No console errors during the windowed run.

## Top 3 things that work
1. The world is visible and readable. Player (blue), enemies (red/orange) and the dummy (grey) are distinct, and the shadows help.
2. Card names land the tone: "Quick, I Guess", "Shrug Bomb", "Ugh, Fine, Moving", "Healing Potion (Lukewarm)". The "Next:" preview under each slot tells me what I'll draw.
3. Enemy HP bars are clear at a glance.

## Top 5 problems (ranked, observed from idle only)
1. **Idle death with no feedback.** By 12s the HUD read "0 / 30" and the player capsule was still standing there. I saw no death screen, no restart prompt, no fade. A player who dies sees nothing happen. (Not sure whether this is out of scope for M2; the roadmap should say.) Suggest a minimal "You died. Reluctantly. [R] restart".
2. **Fast first-contact.** Enemies were on me within 1s and the player was dead by 12s doing nothing. That is not tuning evidence, but I need to see whether an active player gets a fair opening. Suggest a short grace period before wave 1 and a visible spawn telegraph.
3. **Slot 5 text is clipped.** "Next: Nap Time (Brief)" is cut off by the bottom edge at 720p, because the long name "Healing Potion (Lukewarm)" wraps to 2 lines. Suggest a smaller or shorter layout, or margin.
4. **No cooldown or ready state readable on the slots.** All slots look identical in the 3 frames, so I can't tell "ready" from "on cooldown". Needs a live test to confirm.
5. **Arena edge.** The sky/void is visible at the corner (pt_2) after the camera followed. Looks unfinished, not a blocker. Walls or a fog fade would help.

Possible code bug for QA: the player stays visible and un-animated at 0 HP (no death handling that I could see).

## Questions for the director
- Is death handling (screen/restart) intentionally deferred to Milestone 3?
- Should wave 1 start at t=0, or after a few seconds' grace?

## Suggested next playtest focus
Build a scripted-input tool first. I propose `--script=data/playtest_inputs.json`, a timed list of `{t, action, pressed}` events that feeds `Input.parse_input_event`, combined with the existing screenshot-after times. That lets me test dodge, attack and cards 1-5 and report feel. Meanwhile the director should play by hand and use this checklist: does the dash read as on cooldown, does the basic attack have impact, does a card use feel "oh nice", is wave 1 survivable, and do HP bars clash with the player.
