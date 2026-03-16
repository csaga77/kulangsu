# Kulangsu Contracts

This file documents the durable boundaries future changes should preserve. These are not formal schema files, but they are real interfaces between systems.

## Runtime Entry Contracts

- [`../project.godot`](../project.godot) must continue to define the Godot project entry point and the `AppState` autoload.
- The current main scene contract is `run/main_scene = res://ui/app_flow_root.tscn`.
- The current autoload contract is `AppState = res://game/app_state.gd`.

If either changes, update this file, [`architecture.md`](architecture.md), and [`README.md`](../README.md).

## App Shell Contract

Owned by:

- [`../ui/app_flow_root.tscn`](../ui/app_flow_root.tscn)
- [`../ui/app_flow_root.gd`](../ui/app_flow_root.gd)

Current contract:

- the app shell owns boot, title, player setup, gameplay entry, and in-game overlays
- gameplay remains embedded while overlays are shown on top
- UI is authored against a `1920 x 1080` design canvas and scaled to the live viewport
- `Esc` backs out through overlay flow and `J` toggles the journal during gameplay

## Shared State Contract

Owned by:

- [`../game/app_state.gd`](../game/app_state.gd)

Current contract:

- `AppState` is the shared UI/progression-facing bridge between gameplay and UI
- it exposes signals for mode, chapter, location, objective, hint, save status, fragments, landmarks, residents, resident profiles, player appearance/costumes, and summary updates
- world and UI code rely on resident getters for resident ids, display names, appearance configs, spawn configs, ambient speech, and resident journal text
- UI screens and world integration code rely on those signals and state getters/setters

Governance:

- keep shared cross-screen state here
- do not move scene-local behavior into `AppState` without a strong reason
- if signal names, payload shapes, or key state fields change, update this file and the affected feature docs

## World Integration Contract

Owned by:

- [`../main.tscn`](../main.tscn)
- [`../main.gd`](../main.gd)

Current contract:

- `main.gd` maps landmarks and spawn anchors, spawns residents, reacts to controller events, and syncs player context into `AppState`
- `main.tscn` keeps the player and resident instances under one shared y-sorted actor layer rooted at `actors`
- player inspect and talk prompts flow from nearby world objects through controller signals into `AppState`
- landmark naming and location sync depend on known nodes in the main scene

Governance:

- keep scene-specific world wiring local to `main.gd` unless it becomes a reusable subsystem
- document node-path, actor-layer, or spawn-anchor naming assumptions if new systems depend on them

## Reusable Module Contracts

### Grid Board Game

Owned by:

- [`../game/grid_board_game/grid_board_game.gd`](../game/grid_board_game/grid_board_game.gd)

Current contract:

- `GridBoardGame` is a reusable `class_name`
- it exposes signals such as `board_changed`, `turn_changed`, `move_played`, `game_reset`, and `game_over`
- it exposes a public gameplay API including methods like `reset_game()`, `play_move()`, `simulate_move()`, `undo()`, and `redo()`

Governance:

- if those signals or public methods change, update this file and the relevant feature docs

## Submodule Integration Contracts

Submodules are governed in [`submodules.md`](submodules.md). At the parent-repo level, the durable contract is:

- the parent repo owns which submodule commit is pinned
- submodule folders are separate repositories, not normal local directories
- parent-repo docs should describe how submodules are consumed, not duplicate the submodules’ internal docs

## Documentation Contract

Update this file when:

- startup entry points change
- a shared signal, public API, or state contract changes
- a submodule boundary changes
- a feature begins depending on a new stable interface
