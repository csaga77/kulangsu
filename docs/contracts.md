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
- it exposes signals for mode, chapter, location, objective, hint, save status, fragments, melody progress, landmarks, residents, resident profiles, player appearance/costumes, and summary updates
- it now owns shared melody runtime state while [`../game/melody_catalog.gd`](../game/melody_catalog.gd) owns authored melody definitions
- world and UI code rely on resident getters for resident ids, display names, appearance configs, spawn configs, ambient speech, and resident journal text
- UI code can now rely on melody getters and journal helpers for melody-facing player context
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
- player inspect and talk prompts flow from nearby same-layer world objects through controller signals into `AppState`
- landmark naming and location sync depend on known nodes in the main scene

Governance:

- keep scene-specific world wiring local to `main.gd` unless it becomes a reusable subsystem
- document node-path, actor-layer, or spawn-anchor naming assumptions if new systems depend on them

## Multi-Level Scene Contract

Owned by:

- [`../common/level_node_2d.gd`](../common/level_node_2d.gd)
- [`../common/level_registry.gd`](../common/level_registry.gd)
- [`features/multi_level_spaces.md`](features/multi_level_spaces.md)

Current contract:

- every level-aware node must expose a `level_id` for its own level
- every level-aware node may expose additional `level_id` properties such as `level_from`, `level_to`, `level_bottom`, or `level_top`
- `LevelNode2D` resolves its `level_id` either absolutely or relative to the closest level-aware parent
- reusable room scenes should prefer relative level ids so they do not hardcode runtime level ids
- `LevelRegistry` derives shared runtime floor data from `level_id`
- By default, `LevelRegistry` maps `level_id` to runtime floor data as `physics_atlas_column = level_id`, `z_index = level_id`, and `collision_mask = 1 << (19 + level_id)`
- `LevelRegistry` remains the place to update if a landmark ever needs non-formula level behavior
- `LevelNode2D` resolves a `level_id`, then asks `LevelRegistry` for the corresponding physics-atlas column instead of assuming `level_id == atlas_column`
- actor traversal components resolve their final collision-mask and `z_index` state through the same shared global level data
- visibility masking still depends on authored mask layers plus absolute `z_index` behavior

Governance:

- keep shared level ids consistent across scenes when child rooms are intended to be reusable
- when introducing new multi-level spaces, prefer relative level ids on child instances over repeating raw runtime level ids everywhere
- do not duplicate physics-atlas, collision-mask, or actor-`z_index` values outside `LevelRegistry` when a scene is using the shared model
- do not assume `LevelRegistry` automatically configures visibility masks
- if you need the full current design, known limitation, or validation targets, start with [`features/multi_level_spaces.md`](features/multi_level_spaces.md)
- if the level-id resolution model or `LevelRegistry` derivation rules change, update this file and the relevant scene docs

## Multi-Level Actor Transition Contract

Owned by:

- [`../common/level_registry.gd`](../common/level_registry.gd)
- [`../architecture/components/portal.gd`](../architecture/components/portal.gd)
- [`../architecture/components/steps.gd`](../architecture/components/steps.gd)

Current contract:

- `LevelRegistry` owns the shared level derivation rules keyed by `level_id`
- `LevelRegistry` exposes `resolve_level_physics_atlas_column()`, `resolve_level_collision_mask()`, `resolve_level_z_index()`, and `apply_level_to_actor()`
- `LevelRegistry` is used as a static global helper and should not be instantiated
- `Portal` exposes `level_id`, `level_from`, and `level_to` plus a mode that makes all of those ids either absolute or relative to the closest level-aware parent.
- `Steps` exposes `level_id`, `level_bottom`, and `level_top` plus a mode that makes all of those ids either absolute or relative to the closest level-aware parent.
- When their related `level_id` properties are set, `Portal` and `Steps` resolve the matching profiles through `LevelRegistry`.
- Both `Portal` and `Steps` fall back to hand-authored mask values if level ids are not provided or profile lookup is unavailable, preserving backward compatibility.
- Direct spawn, teleport, or restore of an actor into a non-ground level should call `LevelRegistry.apply_level_to_actor(level_id, actor)` or the equivalent profile lookup path.

Governance:

- if the shared level derivation rules or the traversal components' `level_id` interface change, update this file and relevant feature docs
- new multi-level spaces should use either absolute or parent-relative exported `level_id` values where a reusable scene or component needs to point at a logical level
- existing portals and stairs outside Bagua Tower may continue to use hand-authored mask values; migration is not required but recommended

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
