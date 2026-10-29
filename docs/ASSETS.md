# Third-Party Assets

Tracks every non-original asset or library in the repo: source, author, license, where it is used. Required before committing anything not authored in this project (per root `CLAUDE.md`). Last audited against the repo: 2026-10-28 (tech-writer, first pass).

## Third-party

| Asset | Source | Author | License | Date added | Files | Used for | Status |
|---|---|---|---|---|---|---|---|
| gdUnit4 v6.2.2 | https://github.com/godot-gdunit-labs/gdUnit4 (release tag v6.2.2, per the scaffold commit and `docs/DECISIONS.md`) | Mike Schulze (`addons/gdUnit4/plugin.cfg`) | MIT, Copyright (c) 2023 Mike Schulze (`addons/gdUnit4/LICENSE`) | 2026-10-26 (4fdcf86) | `addons/gdUnit4/` (GDScript source, plus `.tscn`, `.html`, `.css`, `.png` and a C# API stub that ship inside the addon) | Headless unit tests (`tools/run_tests.ps1`); enabled as an editor plugin in `project.godot` | License and version verified from the files in the repo. Source URL not re-checked online. The addon's bundled images (`src/core/assets/touch-button.png`, `src/ui/settings/logo.png`, `src/reporters/html/template/css/logo.png`) are assumed covered by the addon's MIT license: unverified. Not shipped in a game build (test-only). |

## Not vendored

- **Godot Engine** 4.7.2 stable (official build) is installed on the developer machine (`docs/DECISIONS.md` records the version and the winget install). It is not in the repo. Godot is MIT licensed; a shipped game will carry the engine, so its license text must be included then. Not audited yet.
- **Fonts:** none in the repo. All text uses Godot's built-in default theme font (`get_theme_default_font()` in `src/ui/AttackMeter.gd`; no font files or theme resources are referenced). The default font's own license is unverified here and should be checked before a Steam release.
- **Audio:** none.
- **Art / textures / models:** none. All visuals are Godot primitives, CSG shapes and flat colors.

## Project-authored (not third-party)

Listed so the inventory is complete. Authorship is from the git history and file contents, not a signed statement.

| File | What | Added | Notes |
|---|---|---|---|
| `assets/icon.svg` | App icon: a red rounded square on a dark rounded square | 2026-10-26 (4fdcf86, scaffold) | Plain SVG of two rectangles. No credit or license text in the file. Origin assumed project-authored: unverified. |
| `assets/shaders/enemy_hp_bar.gdshader` | Billboard enemy HP bar shader | 2026-10-27 (0309f86) | Header comments describe project behavior; no external credit. |
| `src/player/player_occlusion_cue.gdshader` | Silhouette where the player is hidden by nearer geometry | 2026-10-28 (2f44346) | Written for Slice 6b; no external credit. Lives in `src/`, not `assets/`. |

## Flags for game-lead
- Nothing in the repo is known to forbid commercial use or redistribution. The only third-party code is MIT.
- Two items are unverified: the origin of `assets/icon.svg`, and the default engine font's license (not in the repo, but present in any build).
- No third-party art or audio has been added. When one is, record source, author, license and URL here before it is committed.
