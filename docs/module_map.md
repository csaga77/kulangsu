# Kulangsu Module Map

Read [`design_brief.md`](design_brief.md) and [`architecture.md`](architecture.md) first. Use this file to find where a feature probably belongs before you edit.

## Entry Points

- [`../project.godot`](../project.godot) - Godot project configuration, autoloads, input map, and main scene
- [`../main.tscn`](../main.tscn) / [`../main.gd`](../main.gd) - app startup and overlay flow
- [`../scenes/game_main.tscn`](../scenes/game_main.tscn) / [`../scenes/game_main.gd`](../scenes/game_main.gd) - main island scene and world integration

## UI And Screen Flow

- [`../ui/`](../ui) - shell logic, screen scenes, UI styling, and title assets
- [`../ui/screens/`](../ui/screens) - boot, title, HUD, journal, pause, settings, credits, ending, and player setup screens

Put new menu, overlay, HUD, or shell-flow work here.

## World Integration And Shared State

- [`../scenes/game_main.tscn`](../scenes/game_main.tscn) / [`../scenes/game_main.gd`](../scenes/game_main.gd) - connects terrain, the shared actor layer, landmarks, tunnel interior context, and residents to the UI
- [`../terrain/terrain.tscn`](../terrain/terrain.tscn) / [`../terrain/terrain.gd`](../terrain/terrain.gd) - island terrain, generated helper layers, water rendering setup, and the ground-layer masking hooks used by tunnel interiors
- [`../terrain/terrain_generation_profile.gd`](../terrain/terrain_generation_profile.gd) / [`../terrain/terrain_mask_rule.gd`](../terrain/terrain_mask_rule.gd) - terrain mask legend, per-color semantics, and generated-layer paint defaults
- [`../game/app_state.gd`](../game/app_state.gd) - shared UI/progression-facing state
- [`../game/melody_catalog.gd`](../game/melody_catalog.gd) - authored melody definitions, clue sources, and performance-point summaries
- [`../game/resident_catalog.gd`](../game/resident_catalog.gd) - resident roster, dialogue, appearance, and spawn data
- [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd) / [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd) - player customization data

If several screens or systems need the same player-facing state, it probably belongs in `game/app_state.gd`.
If you are changing how terrain mask colors map to layers, start with the terrain profile and rule scripts before editing `terrain.gd`.

## Characters And Interaction

- [`../characters/`](../characters) - player and NPC scenes plus sprite systems
- [`../characters/tests/`](../characters/tests) - direct character smoke scenes such as `HumanBody2D`
- [`../characters/control/`](../characters/control) - controllers, resident presentation hookup, and interaction behavior
- [`../characters/control/bt/`](../characters/control/bt) - behavior-tree framework
- [`../characters/universal_lpc/`](../characters/universal_lpc) - Universal LPC metadata tooling, runtime sprite composition, and related helpers
- [`../characters/universal_lpc/tests/`](../characters/universal_lpc/tests) - Universal LPC metadata and composition validation tooling
- [`../gui/`](../gui) - in-world UI such as speech balloons

Put player control, NPC behavior, interaction prompts, and behavior-tree work here.

## Landmark And World Content

- [`../architecture/`](../architecture) - landmark scenes such as Bagua Tower, tunnels, church, and ferry content
- [`../architecture/components/`](../architecture/components) - reusable world-building pieces such as portals and stairs
- [`../architecture/bagua_tower/tests/`](../architecture/bagua_tower/tests) - Bagua Tower-specific validation scenes and scripts
- [`../common/`](../common) - shared world nodes, effects, visibility helpers, and level helpers such as `AutoVisibilityNode2D`, `LevelNode2D`, and `LevelRegistry`

### Landmark Quest Triggers

- [`../game/landmark_trigger.gd`](../game/landmark_trigger.gd) - `class_name LandmarkTrigger extends Area2D`; place directly in a landmark scene; exports `landmark_id`, `trigger_id`, `display_name`, `visible_in_states`, `collected_progress_key`, `requires_collected`, `hide_if_flag`; self-manages visibility by subscribing to `AppState.landmark_progress_changed`; hides and disables itself after `collect()` is called

Put new landmark scenes and reusable architectural pieces here. Define shared floor data in `LevelRegistry`, and use absolute or parent-relative exported `level_id` integers in traversal components.

## Reusable Gameplay Modules

- [`../game/grid_board_game/`](../game/grid_board_game) - reusable board-game module and local test scenes
- [`../game/marble_game/`](../game/marble_game) - marble-game prototype
- [`../game/piano_game/`](../game/piano_game) - piano mini-game prototype
- [`../game/tests/npc_system/`](../game/tests/npc_system) - NPC/resident validation scenes and companion test assets

If a feature is self-contained and reusable, extend its module folder instead of scattering logic across unrelated directories.

## Shared Utilities And Assets

- [`../godot_common/`](../godot_common) - support utilities reused across scenes
- [`../godot_tilemap/`](../godot_tilemap) - tilemap tooling and related helpers
- [`../resources/`](../resources) - materials, sprites, audio, animations, and tilesets

Be careful about renames or moves here because scene and resource references can break easily.

## Validation Scenes

- [`../scenes/`](../scenes) - runtime gameplay scenes such as `game_main`
- [`../scenes/tests/`](../scenes/tests) - ad hoc prototype and validation scenes
- [`../characters/tests/test_human_body_2d.tscn`](../characters/tests/test_human_body_2d.tscn) - direct `HumanBody2D` smoke sandbox with player-controller wiring
- [`../characters/universal_lpc/tests/test_universal_lpc_sprite_generator.tscn`](../characters/universal_lpc/tests/test_universal_lpc_sprite_generator.tscn) - Universal LPC metadata and sprite-composition validation tool
- [`../game/tests/npc_system/test_npc_layer_interaction.tscn`](../game/tests/npc_system/test_npc_layer_interaction.tscn) - focused same-layer NPC targeting and portal-driven z-layer switching sandbox
- [`../game/tests/npc_system/test_tunnel_visibility.tscn`](../game/tests/npc_system/test_tunnel_visibility.tscn) - focused tunnel-resident spawn, spacing, and tunnel-context visibility regression scene
- [`../game/tests/npc_system/test_tunnel_npc_travel.tscn`](../game/tests/npc_system/test_tunnel_npc_travel.tscn) - focused tunnel resident route, in/out tunnel travel, and tunnel level-state regression scene
- [`../scenes/tests/test_level_resolution.tscn`](../scenes/tests/test_level_resolution.tscn) - focused relative-level resolution and inherited room-level sandbox
- [`../scenes/tests/test_portal_overlap.tscn`](../scenes/tests/test_portal_overlap.tscn) - focused multi-actor portal transition regression test
- [`../architecture/bagua_tower/tests/test_bagua_portal_levels.tscn`](../architecture/bagua_tower/tests/test_bagua_portal_levels.tscn) - focused Bagua base-to-ground portal integration for `level_id` actor transitions
- [`../architecture/bagua_tower/tests/test_bagua_stairs_visibility.tscn`](../architecture/bagua_tower/tests/test_bagua_stairs_visibility.tscn) - full Bagua Tower ascent, descent, and upper-floor visibility integration test
- [`../architecture/bagua_tower/tests/test_bagua_stairs_walk.tscn`](../architecture/bagua_tower/tests/test_bagua_stairs_walk.tscn) - focused Bagua stair physical traversal integration test
- [`../scenes/tests/test_weather.tscn`](../scenes/tests/test_weather.tscn) - focused weather tuning sandbox with tilemap-backed water/terrain, a shared fog pass, pier impacts, a thunder-flash pass, an in-scene weather control panel with rain, fog, and thunder controls, actor readability checks, and temporary foreground occluder proxies
- [`../scenes/tests/test_water_render.tscn`](../scenes/tests/test_water_render.tscn) - focused water color, wave, transparency, and refraction sandbox
- [`../game/tests/npc_system/test_scene.tscn`](../game/tests/npc_system/test_scene.tscn) - focused resident speech, talk, and journal sandbox
- [`../game/grid_board_game/test_grid_board_game.tscn`](../game/grid_board_game/test_grid_board_game.tscn)
- [`../game/grid_board_game/test_terminal_turn_state.tscn`](../game/grid_board_game/test_terminal_turn_state.tscn)

Use these when you need a focused validation target instead of the full project flow.

## Documentation And Agent Support

- [`../docs/`](../docs) - project docs
- [`features/multi_level_spaces.md`](features/multi_level_spaces.md) - implementation-facing guide for stacked rooms, parent-owned level mapping, portals, stairs, and current design gaps
- [`features/core_melody_loop.md`](features/core_melody_loop.md) - implementation-facing summary of the current melody-driven gameplay loop, gap list, and MVP build order
- [`features/npc_system.md`](features/npc_system.md) - implementation-facing summary of the resident/NPC system
- [`features/terrain_system.md`](features/terrain_system.md) - terrain generation ownership, mask-rule workflow, and extension guide
- [`features/weather_rendering.md`](features/weather_rendering.md) - current weather-system design, ownership, extension guide, and focused validation notes for the tilemap-backed sandbox
- [`features/terrain_water_rendering.md`](features/terrain_water_rendering.md) - terrain water rendering and validation notes
- [`features/`](features) - feature specs
- [`features/template.md`](features/template.md) - local feature-spec template
- [`../codex_agents/`](../codex_agents) - shared generic agent runbooks and support docs
- [`../codex_agents/README.md`](../codex_agents/README.md) / [`../codex_agents/AGENTS.md`](../codex_agents/AGENTS.md) - submodule doc entry points when a task depends on shared runbooks or agent behavior

## Submodules

- [`../godot_common/`](../godot_common) - shared Godot support code, tracked as a submodule
- [`../godot_tilemap/`](../godot_tilemap) - tilemap helpers/tooling, tracked as a submodule
- [`../codex_agents/`](../codex_agents) - shared agent docs and runbooks, tracked as a submodule
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator) - third-party LPC asset generator, tracked as a submodule

Submodule doc entry points:

- [`../godot_common/AGENTS.md`](../godot_common/AGENTS.md)
- [`../godot_common/README.md`](../godot_common/README.md)
- [`../godot_common/docs/architecture.md`](../godot_common/docs/architecture.md)
- [`../godot_tilemap/AGENTS.md`](../godot_tilemap/AGENTS.md)
- [`../godot_tilemap/README.md`](../godot_tilemap/README.md)
- [`../godot_tilemap/docs/architecture.md`](../godot_tilemap/docs/architecture.md)
- [`../codex_agents/README.md`](../codex_agents/README.md)
- [`../codex_agents/AGENTS.md`](../codex_agents/AGENTS.md)
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md)

See [`submodules.md`](submodules.md) for edit rules, update rules, and a parent-repo index of submodule documentation.

## Search Tips

Useful searches when locating code:

- `ScreenState` for app shell transitions
- `AppState` for shared UI-facing state
- `inspect_requested` for inspect flow
- `set_location` for location syncing
- `resident` for resident systems and data
- `FogOverlay` for the reusable fog/weather effect
- `RainOverlay` for the reusable rain/weather effect
- `RainGroundImpacts` for isometric raindrop ground-hit rendering
- `test_weather` for the focused weather sandbox and control panel
- `water_tint` for the water shader and material
- `class_name GridBoardGame` for the board-game module
- `class_name UIStyle` for shared UI styling

## Update This Doc When

- a new module or top-level folder is introduced
- ownership of a directory or entry point changes
- a new feature should live somewhere that is not obvious from this map
- the submodule list or their effective role in the repo changes
