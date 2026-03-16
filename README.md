# Kulangsu

Kulangsu is a Godot exploration game prototype set on Gulangyu (Kulangsu). The project centers on walking the island, meeting residents, collecting melody fragments, and moving through a calm, overlay-driven story flow instead of a combat-heavy loop.

This repository is also a small super-repo: the main game lives here, and several supporting codebases are brought in as git submodules.

## Tech Stack

- Godot 4 project configured through [`project.godot`](project.godot)
- GDScript and `.tscn` scenes
- Canvas-based UI rooted in [`ui/app_flow_root.tscn`](ui/app_flow_root.tscn)
- Shared UI/progression state in the `AppState` autoload at [`game/app_state.gd`](game/app_state.gd)
- Git submodules for shared support code, tilemap tooling, third-party LPC assets, and agent runbooks

No package manager, CI pipeline, or automated test runner is checked into this repository.

## Repository Layout

- [`ui/`](ui) - app shell, screens, overlays, and shared UI styling
- [`main.tscn`](main.tscn) / [`main.gd`](main.gd) - main island scene and world integration logic
- [`game/`](game) - shared state, catalogs, and reusable gameplay modules
- [`characters/`](characters) - player, NPC, controller, and behavior-tree code
- [`architecture/`](architecture) - landmark scenes and reusable building pieces
- [`scenes/`](scenes) - prototype and validation scenes
- [`resources/`](resources) - audio, sprites, materials, animations, and tilesets
- [`docs/`](docs) - project documentation for humans and coding agents
- [`codex_agents/`](codex_agents) - shared agent runbooks and reusable support docs
- [`godot_common/`](godot_common) - shared Godot support code via submodule
- [`godot_tilemap/`](godot_tilemap) - tilemap tooling/support code via submodule
- [`3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](3rdparty/Universal-LPC-Spritesheet-Character-Generator) - third-party LPC asset generator via submodule

## Submodules

This repo currently tracks these submodules through [`.gitmodules`](.gitmodules):

- [`godot_common/`](godot_common)
- [`godot_tilemap/`](godot_tilemap)
- [`3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](3rdparty/Universal-LPC-Spritesheet-Character-Generator)
- [`codex_agents/`](codex_agents)

See [`docs/submodules.md`](docs/submodules.md) for update rules, boundaries, and when to edit a submodule versus the parent repo.

## Run The Project

Use a local Godot 4 editor or runtime to open [`project.godot`](project.godot).

Important runtime entry points:

- Main configured scene: [`ui/app_flow_root.tscn`](ui/app_flow_root.tscn)
- Main gameplay scene embedded by the shell: [`main.tscn`](main.tscn)

This repo does not include export scripts or shell wrappers for launching the project.

## Validation And Testing

Validation is currently manual:

- Run the full project after app-shell, HUD, overlay, or progression changes.
- Open focused scenes when changing a specific subsystem.
- Use the existing test/prototype scenes under [`scenes/`](scenes) and feature-local test scenes such as [`game/grid_board_game/test_grid_board_game.tscn`](game/grid_board_game/test_grid_board_game.tscn) and [`game/grid_board_game/test_terminal_turn_state.tscn`](game/grid_board_game/test_terminal_turn_state.tscn).

If you make a change that affects behavior and you cannot run the project or a relevant scene, call that out explicitly in your handoff.

## Release And Versioning

This repo does not currently include a checked-in release pipeline, export automation, or tagged release history.

- The root branch is currently `main`.
- Submodule revisions are pinned by the parent repo commit.
- Release/version governance is documented in [`docs/release_policy.md`](docs/release_policy.md).

## Docs

Start here for project context:

- [`docs/design_brief.md`](docs/design_brief.md) - minimum-token game and UI summary
- [`docs/architecture.md`](docs/architecture.md) - system boundaries and relationships
- [`docs/module_map.md`](docs/module_map.md) - where code and content live
- [`docs/submodules.md`](docs/submodules.md) - submodule roles and governance
- [`docs/contracts.md`](docs/contracts.md) - stable interfaces and boundaries
- [`docs/release_policy.md`](docs/release_policy.md) - current release/version policy
- [`docs/features/README.md`](docs/features/README.md) - how feature specs work
- [`AGENTS.md`](AGENTS.md) - repository instructions for coding agents
