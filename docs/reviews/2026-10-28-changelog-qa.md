# QA: docs/CHANGELOG.md accuracy check (2026-10-28)

## Verdict: PASS after three small wording fixes (made directly in CHANGELOG.md)

Method: a script extracted every 7-char hash per section and checked `git show -s` for existence and commit date against the section date; then read the stat, message and diff behind each claimed number.

- Hashes: every one exists. Dates: every hash sits in the section matching its commit date (10-26, 10-27, 10-28). Format rules (newest first, one section per date, Added/Changed/Fixed/Docs and process, short hashes, old -> new for balance, [Director decision] tags, "unclear from history" used for the old basic attack and the second gitignore commit) are met.
- Missing commits: only pure doc bookkeeping (4fb5b57 and c60ad04 DECISIONS table fixes, 91587d5 4a notes, cdcdf47 and efc42e7 STATE/record). Nothing meaningful missing.
- Numbers verified against data diffs: light 8 -> 3 (13.3 -> 5.0 DPS), click ratio 2.4x -> 1.5x (gap 0.25 -> 0.4), Shrug Bomb 5 -> 12, Everyone Calm Down 8 -> 16, heavy 22 -> 8.5 (12.2 -> 4.7), slow 0.35, stun 0.6, DR window 4.0 -> 1.5, Fine Burn Then 7 -> 12, Ember 11.8 -> 6.4 credited, vfx cap 48 -> 64, Flaming Nonsense and enemy shot hit radius 0.25 -> 0.3, light flash 0.12 -> 0.2, slice-3 values (8 / 0.6 / 0.25, 22 / 1.8 / 0.45), name warn length 25, floor 40 (60 trial reverted), soak flake pre-existing (8/40 at 4c2bfef).
- Agent team: 10-26 (4fdcf86) created game-lead, gameplay-dev, qa and dormant art/audio/story; 10-27 (d6a6546) added playtester and ux-designer; 64e10ac gave game-lead the Agent tool. The changelog says exactly this.

## Errors found and fixed
1. "projectile path marker went from 0.75 to 0.60 wide": the numbers are the lane **half** width (DECISIONS: "Projectile lane half width ... 0.75 -> 0.60"). Now says half-width, lane 1.5 -> 1.2.
2. Light flash "from pale tan": the old colour was #ffe27a (pale yellow); new #ffcf1a. Reworded with the hex values.
3. Camera "rotation was stored flipped": the commit says the Camera3D basis was serialized transposed. Reworded.

## Not verified / judgment
- Cosmetic claims (stars, ring, sparkle, flame descriptions) taken from commit messages and DECISIONS, not re-rendered.
- The 10-28 "Changed" bullet about wedge size ("about 0.45 past the old drawn edge") rests on DECISIONS 4a text and the 1d87756 diff, not measured.
