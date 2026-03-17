# Kulangsu Module Map

Read [`design_brief.md`](design_brief.md) and [`architecture.md`](architecture.md) first. Use this file to find where a feature probably belongs before you edit.

## Entry Points

- [`../project.godot`](../project.godot) - Godot project configuration, autoloads, input map, and main scene
- [`../ui/app_flow_root.tscn`](../ui/app_flow_root.tscn) / [`../ui/app_flow_root.gd`](../ui/app_flow_root.gd) - app startup and overlay flow
- [`../main.tscn`](../main.tscn) / [`../main.gd`](../main.gd) - main island scene and world integration

## UI And Screen Flow

- [`../ui/`](../ui) - shell logic, screen scenes, UI styling, and title assets
- [`../ui/screens/`](../ui/screens) - boot, title, HUD, journal, pause, settings, credits, ending, and player setup screens

Put new menu, overlay, HUD, or shell-flow work here.

## World Integration And Shared State

- [`../main.tscn`](../main.tscn) / [`../main.gd`](../main.gd) - connects terrain, the shared actor layer, landmarks, and residents to the UI
- [`../terrain.tscn`](../terrain.tscn) / [`../terrain.gd`](../terrain.gd) - island terrain, generated water layer, and water rendering setup
- [`../game/app_state.gd`](../game/app_state.gd) - shared UI/progression-facing state
- [`../game/resident_catalog.gd`](../game/resident_catalog.gd) - resident roster, dialogue, appearance, and spawn data
- [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd) / [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd) - player customization data

If several screens or systems need the same player-facing state, it probably belongs in `game/app_state.gd`.

## Characters And Interaction

- [`../characters/`](../characters) - player and NPC scenes plus sprite systems
- [`../characters/control/`](../characters/control) - controllers, resident presentation hookup, and interaction behavior
- [`../characters/control/bt/`](../characters/control/bt) - behavior-tree framework
- [`../gui/`](../gui) - in-world UI such as speech balloons

Put player control, NPC behavior, interaction prompts, and behavior-tree work here.

## Landmark And World Content

- [`../architecture/`](../architecture) - landmark scenes such as Bagua Tower, tunnels, church, and ferry content
- [`../architecture/components/`](../architecture/components) - reusable world-building pieces
- [`../common/`](../common) - shared world nodes, effects, and level-context helpers such as `LevelNode2D`

Put new landmark scenes and reusable architectural pieces here.

## Reusable Gameplay Modules

- [`../game/grid_board_game/`](../game/grid_board_game) - reusable board-game module and local test scenes
- [`../game/marble_game/`](../game/marble_game) - marble-game prototype
- [`../game/piano_game/`](../game/piano_game) - piano mini-game prototype

If a feature is self-contained and reusable, extend its module folder instead of scattering logic across unrelated directories.

## Shared Utilities And Assets

- [`../godot_common/`](../godot_common) - support utilities reused across scenes
- [`../godot_tilemap/`](../godot_tilemap) - tilemap tooling and related helpers
- [`../resources/`](../resources) - materials, sprites, audio, animations, and tilesets

Be careful about renames or moves here because scene and resource references can break easily.

## Validation Scenes

- [`../scenes/`](../scenes) - ad hoc prototype and validation scenes
- [`../scenes/test_water_render.tscn`](../scenes/test_water_render.tscn) - focused water color, wave, transparency, and refraction sandbox
- [`../scenes/test_scene.tscn`](../scenes/test_scene.tscn) - focused resident speech, talk, and journal sandbox
- [`../game/grid_board_game/test_grid_board_game.tscn`](../game/grid_board_game/test_grid_board_game.tscn)
- [`../game/grid_board_game/test_terminal_turn_state.tscn`](../game/grid_board_game/test_terminal_turn_state.tscn)

Use these when you need a focused validation target instead of the full project flow.

## Documentation And Agent Support

- [`../docs/`](../docs) - project docs
- [`features/npc_system.md`](features/npc_system.md) - implementation-facing summary of the resident/NPC system
- [`features/terrain_water_rendering.md`](features/terrain_water_rendering.md) - terrain water rendering and validation notes
- [`features/`](features) - feature specs
- [`features/template.md`](features/template.md) - local feature-spec template
- [`../codex_agents/`](../codex_agents) - shared generic agent runbooks and support docs

## Submodules

- [`../godot_common/`](../godot_common) - shared Godot support code, tracked as a submodule
- [`../godot_tilemap/`](../godot_tilemap) - tilemap helpers/tooling, tracked as a submodule
- [`../codex_agents/`](../codex_agents) - shared agent docs and runbooks, tracked as a submodule
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator) - third-party LPC asset generator, tracked as a submodule

See [`submodules.md`](submodules.md) for edit and update rules.

## Search Tips

Useful searches when locating code:

- `ScreenState` for app shell transitions
- `AppState` for shared UI-facing state
- `inspect_requested` for inspect flow
- `set_location` for location syncing
- `resident` for resident systems and data
- `water_tint` for the water shader and material
- `class_name GridBoardGame` for the board-game module
- `class_name UIStyle` for shared UI styling

## Update This Doc When

- a new module or top-level folder is introduced
- ownership of a directory or entry point changes
- a new feature should live somewhere that is not obvious from this map
- the submodule list or their effective role in the repo changes
