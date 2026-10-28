# qa review: Polish 1 Slice 2 (HUD text overflow and safe layout), commit f5b0c19

**Verdict: PASS**

## Checks run (by qa, this session)
- `godot --headless --editor --quit`: no lines matching error/warn.
- `godot --headless --quit-after 1200` (full 20 s): no lines matching error/warn/SceneSelf. (Lint-level GDScript warnings are not surfaced by the CLI in 4.7.2; no blanket "zero warnings" claim.)
- `tools\run_tests.ps1`: 127 cases, 0 errors, 0 failures, 0 orphans, exit 0 (124 before; +3 qa tests in `tests/unit/hud_layout_qa_test.gd`). `hud_layout_test.gd` 12/12.
- `tools\run_reload_cycle.ps1 -Cycles 5`: RELOAD CYCLE OK, orphans 0, objects stable at 1784, nodes 85, time_scale 1.0.
- >25-char warning: no current card triggers it (the real-card test asserts `CardSchema.warnings` is empty for all cards; the normal run printed no warning). "Healing Potion (Lukewarm)" is exactly 25.
- Uid files `tests/unit/slice1_qa_test.gd.uid` and `tools/reload_cycle.gd.uid`: correct to commit; every other script in those dirs has a tracked .uid.

## Acceptance criteria
1. Fixed slot size: PASS. Rows have fixed heights from data; `test_widget_rows_do_not_move_with_a_long_name` and the real-HUD SubViewport test (slot rect size and top y identical across 5 slots) back it. Rendered 2560x1440 capture shows aligned slots.
2. Wrap 2 lines, shrink, then ellipsis (names and "Next:"): PASS. `TextFit` implements that order; my unconditional tests confirm shrink-before-truncate and truncation only when min size still overflows.
3. Full name in F3: PASS (code review of `DebugOverlay._card_label`; not run interactively). Tooltip deferred: acceptable ("if cheap" is in the criterion; making slots mouse-visible would swallow world clicks).
4. Safe margins at 3 resolutions: PASS by test. `test_real_hud_nodes_inside_viewport_with_margin_and_aligned` instantiates the real Hud.tscn in a SubViewport sized 1280x720 / 1920x1080 / 2560x1440 and measures `get_global_rect()` of slots and HP panel against the safe area. Real, not just math. Rendered capture at 2560x1440 confirms (below).
5. Schema warning, not failure: PASS. `validate()` unchanged, tested with a 60+ char fixture (valid but warned; 25 ok, 26 warns). Logged in DECISIONS.
s1-d HP bar contrast: PASS on the 1440 render (white border, saturated fill, outlined "HP 30 / 30"). The existing HP-label test is green. Hud is CanvasLayer layer 1, GameOverScreen layer 10, so Game Over stays above.

## Do the tests test what they claim?
- Fit test uses `ThemeDB.fallback_font`, which is what unthemed Labels use (the real widget calls `label.get_theme_font("font")`; my real-HUD test measures with that and passes). So metrics are real.
- Real-card test checks names at min font against slot width minus padding, preview with "Next: " prefix, and flavor against a budget box (flavor is not displayed in the HUD yet; the 260 px / 3 line box is an assumption).
- Weakness (non-blocking): `test_shrinks_before_truncating` ends in an `if` and is vacuous if the search finds no width. My `test_shrink_happens_before_truncation_unconditional` covers it.
- Gap I filled: the original suite never put a long name through the real widget at all three resolutions. `hud_layout_qa_test.gd` does (lines <= 2, text height <= label height, ellipsis, bar and preview rects unmoved, truncated text is a prefix).

## Real-size capture gap
Tests are sufficient to PASS this slice, but the pass close-out should still have real images. Cheap solution found: `tools/vp_capture.gd` renders Main into an oversized SubViewport (bypasses the OS window clamp) and saves a PNG:
`godot --path . --script tools\vp_capture.gd -- 2560 1440 screenshots\vp_1440.png` (needs a renderer, not --headless). I produced true 1280x720, 1920x1080 and 2560x1440 images; the 1440 image was viewed (HUD aligned, margins clear, no overflow, "Next: Healing Potion (Lukewarm)" wraps to 2 lines). Limits: `current_scene` is null inside a SubViewport, so spawner/player-card code logs "Cannot call method 'add_child' on a null value" and no wave enemies spawn; exit prints leaked-RID errors (abrupt `--script` quit). HUD/layout is unaffected. game-lead can fold this into the capture tool (e.g. a Main option that parents itself under a SubViewport, or `current_scene` set by the tool) for playtester screenshots.

## Non-blocking issues
- 9 px "Next:" minimum at 720p is small; no current card reaches it (longest "Healing Potion (Lukewarm)" wraps at base 11 px). Data value `preview_min_font_size`; raise to 10 if the director wants margin.
- Vacuous-if test noted above.
- F3 overlay not exercised by any test.
- Mouse-filter of slot widgets (ignore) not asserted by a test; worth adding when the tooltip is revisited.

## Bugs
None blocking. (No file/line repros.)

## Not verified
- F3 overlay visually; real-window 1080p/1440p (only via SubViewport render and tests); hover behavior.
