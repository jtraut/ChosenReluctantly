# Human playtest: Luke (the director's brother) (2026-11-01)

Recorded by game-lead from the director's notes of 2026-11-02. This is a human hands-on session, not a playtester-role report.

- **His only suggestion so far:** friendlier keybindings, using Q and E.
- **What the director did:** changed `data/input_bindings.json` himself (commit 24530e4): cards on Q, E, 1, 2, 3, and the dead-card swap on Shift plus the same keys.
- **What it exposed:** the HUD still shows 1-5, because the card slot labels are hardcoded (`src/ui/Hud.gd`). Other text names slots by number too.
- **Follow-up:** slice K1 (key labels follow the bindings), GDD §3 [DIRECTOR DECISION, 2026-11-02]. K1 also moves Recovery to R at the director's request.
