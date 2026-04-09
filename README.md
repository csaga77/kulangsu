# Kulangsu

Kulangsu is a Godot exploration game prototype set on Gulangyu (Kulangsu). The project centers on walking the island, meeting residents, collecting melody fragments, and moving through a calm, overlay-driven story flow instead of a combat-heavy loop.

This repository is also a small super-repo: the main game lives here, and several supporting codebases are brought in as git submodules.

## Tech Stack

- Godot 4 project configured through [`project.godot`](project.godot)
- GDScript and `.tscn` scenes
- Canvas-based UI rooted in [`main.tscn`](main.tscn)
- Shared scene-owned runtime services for UI/progression state and overworld weather, resolved through [`AppRuntime`](game/app_runtime.gd) and [`WeatherRuntime`](weather/weather_runtime.gd)
- Git submodules for shared support code, tilemap tooling, third-party LPC assets, and agent runbooks

No package manager, CI pipeline, or automated test runner is checked into this repository.

## Repository Layout

- [`ui/`](ui) - app shell, screens, overlays, and shared UI styling
- [`scenes/game_main.tscn`](scenes/game_main.tscn) / [`scenes/game_main.gd`](scenes/game_main.gd) - main island scene and world integration logic
- [`game/`](game) - shared state, catalogs, and reusable gameplay modules
- [`weather/`](weather) - reusable weather overlays, the global weather manager/runtime, and the dedicated weather sandbox
- [`characters/`](characters) - player, NPC, controller, and behavior-tree code
- [`architecture/`](architecture) - landmark scenes and reusable building pieces
- [`scenes/`](scenes) - runtime gameplay scenes plus validation scene containers
- [`terrain/`](terrain) - island terrain scene, terrain generation, and water rendering setup
- [`resources/`](resources) - audio, sprites, materials, animations, and tilesets
- [`scripts/`](scripts) - repo-local workflow configs and project-specific helper data
- [`docs/`](docs) - project documentation for humans and coding agents
- [`agent_tools/`](agent_tools) - shared agent runbooks and reusable support docs
- [`godot_common/`](godot_common) - shared Godot support code via submodule
- [`godot_tilemap/`](godot_tilemap) - tilemap tooling/support code via submodule
- [`3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](3rdparty/Universal-LPC-Spritesheet-Character-Generator) - third-party LPC asset generator via submodule

## Submodules

This repo currently tracks these submodules through [`.gitmodules`](.gitmodules):

- [`godot_common/`](godot_common)
- [`godot_tilemap/`](godot_tilemap)
- [`3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](3rdparty/Universal-LPC-Spritesheet-Character-Generator)
- [`agent_tools/`](agent_tools)

See [`docs/submodules.md`](docs/submodules.md) for update rules, boundaries, and when to edit a submodule versus the parent repo.

Primary submodule documentation entry points:

- [`agent_tools/AGENTS.md`](agent_tools/AGENTS.md) and [`agent_tools/README.md`](agent_tools/README.md) - generic agent guidance, reusable runbooks, and the submodule's own docs map
- [`godot_common/AGENTS.md`](godot_common/AGENTS.md), [`godot_common/README.md`](godot_common/README.md), and [`godot_common/docs/`](godot_common/docs) - entry points for shared Godot support code and helper ownership guidance
- [`godot_tilemap/AGENTS.md`](godot_tilemap/AGENTS.md), [`godot_tilemap/README.md`](godot_tilemap/README.md), and [`godot_tilemap/docs/`](godot_tilemap/docs) - entry points for tilemap helper/tooling architecture and repo conventions
- [`3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md`](3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md) - upstream LPC generator overview, licensing, attribution, and development references

## Workflow Helpers

For low-token source-control inspection in this repo, prefer the shared helper directly:

```bash
python3 agent_tools/scripts/source_control_report.py .
```

It keeps common branch/worktree/submodule checks in one report without a repo-local wrapper layer.

Useful variants:

```bash
python3 agent_tools/scripts/source_control_report.py agent_tools
python3 agent_tools/scripts/source_control_report.py . --fail-on-warnings
python3 agent_tools/scripts/source_control_report.py . --json
```

For the routine "pull latest parent repo state and refresh all tracked submodules" flow on a clean worktree, prefer:

```bash
python3 agent_tools/scripts/source_control_ops.py update-latest .
```

Useful variants:

```bash
python3 agent_tools/scripts/source_control_ops.py update-latest . --dry-run
python3 agent_tools/scripts/source_control_ops.py update-latest . --max-submodule-commits 5
```

For periodic review of whether a token-saving helper still earns its keep, call the shared audit directly with the local workflow config:

```bash
python3 agent_tools/scripts/token_efficiency_audit.py scripts/token_efficiency_workflows.json
```

The audit logic stays generic in [`agent_tools/scripts/token_efficiency_audit.py`](agent_tools/scripts/token_efficiency_audit.py), while the repo-specific manual baseline and review cadence live in [`scripts/token_efficiency_workflows.json`](scripts/token_efficiency_workflows.json).

Useful variants:

```bash
python3 agent_tools/scripts/token_efficiency_audit.py scripts/token_efficiency_workflows.json --fail-on-regression
python3 agent_tools/scripts/token_efficiency_audit.py scripts/token_efficiency_workflows.json --json
python3 agent_tools/scripts/token_efficiency_audit.py scripts/token_efficiency_workflows.json --workflow source_control_parent_repo
```

## Run The Project

Use a local Godot 4 editor or runtime to open [`project.godot`](project.godot).

Important runtime entry points:

- Main configured scene: [`main.tscn`](main.tscn)
- Main gameplay scene embedded by the shell: [`scenes/game_main.tscn`](scenes/game_main.tscn), which now registers overworld weather hosts and lets the global [`WeatherManager`](weather/weather_manager.gd) instantiate and manage the shared cloud-shadow, rain, fog, and ground-impact passes at runtime

This repo does not include export scripts or shell wrappers for launching the project.

## Validation And Testing

Validation is currently manual:

- Run the full project after app-shell, HUD, overlay, or progression changes.
- Open focused scenes when changing a specific subsystem.
- Use the existing validation scenes under [`scenes/tests/`](scenes/tests), the dedicated weather sandbox under [`weather/tests/`](weather/tests), and feature-local test scenes such as [`game/grid_board_game/test_grid_board_game.tscn`](game/grid_board_game/test_grid_board_game.tscn) and [`game/grid_board_game/test_terminal_turn_state.tscn`](game/grid_board_game/test_terminal_turn_state.tscn).
- Use [`scenes/game_main.tscn`](scenes/game_main.tscn) or the full app flow when validating the shared overworld weather, cloud shadows, and global weather-manager transitions against the real island terrain and resident silhouettes.
- Use [`weather/tests/test_weather.tscn`](weather/tests/test_weather.tscn) for weather-specific validation. It now combines tilemap-backed water and terrain, manager-attached shared fog/rain/cloud/impact passes, a thunder-flash test pass, and a tabbed weather control panel split into `Wind`, `Rain`, `Fog`, and `Cloud` groups with per-pass `Sync With Wind` toggles for faster tuning, alongside foreground occluders and actor readability checks.

If you make a change that affects behavior and you cannot run the project or a relevant scene, call that out explicitly in your handoff.

## Release And Versioning

This repo does not currently include a checked-in release pipeline, export automation, or tagged release history.

- The root branch is currently `main`.
- Submodule revisions are pinned by the parent repo commit.
- Release/version governance is documented in [`docs/release_policy.md`](docs/release_policy.md).

## Docs

Start here for project context:

- [`docs/design_brief.md`](docs/design_brief.md) - minimum-token game and UI summary
- [`docs/storyline.md`](docs/storyline.md) - dedicated background story and main narrative summary
- [`docs/architecture.md`](docs/architecture.md) - system boundaries and relationships
- [`docs/module_map.md`](docs/module_map.md) - where code and content live
- [`docs/submodules.md`](docs/submodules.md) - submodule roles and governance
- [`agent_tools/scripts/source_control_report.py`](agent_tools/scripts/source_control_report.py) - shared source-control status helper
- [`scripts/token_efficiency_workflows.json`](scripts/token_efficiency_workflows.json) - local manual baseline and review cadence for token-efficiency audits
- [`agent_tools/scripts/token_efficiency_audit.py`](agent_tools/scripts/token_efficiency_audit.py) - shared helper ROI and review-cadence audit script
- [`agent_tools/README.md`](agent_tools/README.md) - entry point for the shared agent-support submodule
- [`docs/contracts.md`](docs/contracts.md) - stable interfaces and boundaries
- [`docs/release_policy.md`](docs/release_policy.md) - current release/version policy
- [`docs/features/README.md`](docs/features/README.md) - how feature specs work
- [`docs/features/weather_rendering.md`](docs/features/weather_rendering.md) - current weather-system design, reusable overlay ownership, and focused weather-sandbox guidance
- [`AGENTS.md`](AGENTS.md) - repository instructions for coding agents
