# Playtest 2026-10-27: Polish 1 Slice 1, death and Game Over

## Build and setup
Commit afb47c8, Godot 4.7.2, windowed on RTX 3080, via `tools/capture_screenshot.ps1`. Screenshots (gitignored), all looked at:
- `screenshots/go720_0.png` (0.5 s, before death), `go720_1.png` (1.2 s, death beat), `go720_2.png` (1.6 s) and `go720_3.png` (2.6 s), both Game Over. Scenario `game_over`, 1280x720.
- `screenshots/go1080.png` (3.0 s, Game Over, 1920x1080).
- `screenshots/smoke_0.png` (1 s) and `smoke_1.png` (4 s), normal run, no scenario.

I could not play by hand. I did not press Try again, and I did not feel the slow-mo in real time. Stills cannot judge its duration or impact. Input (move, dodge, attack, cards) is still unverified by me.

## Smoke check result
PASS, no blocker. The game launched with no errors or warnings in the capture output. The world shows a lit floor, a blue player with shadow, red and grey enemies with HP bars, and a camera framing the player. The HUD reads "HP 30 / 30" at start and "HP 21 / 30" by 4 s, so damage lands and the number is sensible.

## 1. Death beat
- At 1.2 s the HUD reads "HP 0 / 30" and the player capsule is tipped over (collapse). A hit number is floating at the player. I can tell something happened because the capsule tilts, but the tilt alone is subtle. The player still has its normal blue colour, with no flash or grey-out yet.
- By 1.6 s the screen is already dimmed, so the beat is short. Enemy bars and a ghost of the capsule show through the dim.
- should-fix: I cannot judge slow-mo from stills. The director should watch it once by hand. A collapse alone at HP 0 looks easy to miss during a busy fight, so a stronger cue (red or white flash, or a brief desaturation before the dim) would help.
- nice-to-have: the damage number over the player at death is tiny and overlaps itself ("60" and "5" stacked), so I cannot read the killing blow.

## 2. Game Over screen
- Readable at both 1280x720 and 1920x1080. The screen scales cleanly and the text is centred.
- Tone lands: "Well. That went badly." and "The world is still cheerful about it. You are not." This is dry, weary hero, cheerful world. It is short and does not get in the way.
- "Try again" is unmistakable. It is a large boxed button in the centre with bright text, and it is the only interactive element. The key hint "Enter or Space" is under it.
- nice-to-have: the key hint is small, sits outside the button, and is not obviously a hint for the button. "Try again (Enter)" inside the button would read faster.
- nice-to-have: enemy HP bars and a ghost of the capsules sit behind the subtitle and button (see `go1080.png`, where bars cross the "badly" heading area). It is dimmed and legible, but a stronger dim would make it cleaner.
- nice-to-have: the dimmed HUD slot bar still shows, which is fine.

## 3. HP label
Clear. "HP 30 / 30" with a bar under it is unambiguous. This fixes the earlier "0 / 30" confusion. nice-to-have: the bar is thin and grey, which is low contrast and has no health colour, so I read the number rather than the bar.

## 4. Other player-facing issues (out of scope, follow-ups)
- should-fix, already known (Slice 2): the slot bar clips at 720p. In `smoke_0.png` and `smoke_1.png`, slot 2 "Everyone Calm Down" and slot 5 "Healing Potion (Lukewarm)" wrap to two lines and their "Next:" lines are cut off by the screen edge. It is worse at 1080p (`go1080.png`, slot 5). Note that in `go720_0.png` the names are short, so this depends on the deck draw.
- should-fix: first contact is still fast. Enemies are on the player at 1 s in the normal run (`smoke_0.png`). Carried over from the previous report.
- nice-to-have: no cooldown or ready state is visible on slots. Carried over.

## Top 3 things that work
1. The Game Over screen: clear, readable at 720p and 1080p, and the copy is funny without being long.
2. "Try again" is the obvious next action, and it gives a keyboard hint.
3. The HP label is now unambiguous, and the dim-out clearly separates "alive" from "dead".

## Top problems, ranked
1. should-fix: the death cue before the dim is subtle (capsule tilt only). Add a flash or grey-out so death is noticed mid-fight. Unverified in motion.
2. should-fix: the slot bar is clipped (known, Slice 2).
3. nice-to-have: the key hint is detached from the button.
4. nice-to-have: the killing-blow damage number is unreadable.
5. nice-to-have: HP bar contrast and enemy bars bleeding through the overlay.

## Questions for the director
- Should the Game Over screen show anything about the run (time survived, kills)? Not needed yet, but a dry one-liner would be on-tone.
- Does the director want the slow-mo to be longer? Please watch it once by hand and tell me.

## Suggested next playtest focus
Play by hand: die in a real fight, press Enter or Space, and check that restart feels instant and the arena is fresh. Then Slice 2 (slot bar layout).
