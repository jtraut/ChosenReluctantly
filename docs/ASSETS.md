# Third-Party Assets

Tracks every non-original asset or library in the repo: source, license, where it's used. Required before committing anything not authored in this project (per root `CLAUDE.md`).

| Asset | Source | License | Used for | Notes |
|---|---|---|---|---|
| gdUnit4 v6.2.2 | https://github.com/godot-gdunit-labs/gdUnit4 (release tag v6.2.2) | MIT (see `addons/gdUnit4/LICENSE`) | Headless unit testing / CI test runner | Vendored as GDScript source, no binaries. Not an asset-library install — downloaded the tagged release zip directly from GitHub. |

No art or audio assets yet — Milestone 2 uses only Godot primitives/CSG shapes and flat colors, per the working agreements. This file will grow once placeholder CC0 art/audio is pulled in.
