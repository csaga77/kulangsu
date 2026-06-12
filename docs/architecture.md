# Kulangsu Architecture

Read [`design_brief.md`](design_brief.md) first. This file is the high-level map of the running game and the ownership boundaries future changes should respect.

## Repo Shape

This repository has two layers:

- the main Godot game project
- supporting submodule repositories listed in [`submodules.md`](submodules.md)

Most gameplay and scene work happens in the main repo. Shared or vendor-style code in submodules should be treated as separate ownership boundaries.

## Startup Flow

1. [`../project.godot`](../project.godot) boots the app through [`../main.tscn`](../main.tscn).
2. [`../main.gd`](../main.gd) builds the UI shell, ensures the shared runtime services exist through [`../game/app_runtime.gd`](../game/app_runtime.gd) and [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd), and instantiates [`../scenes/game_main.tscn`](../scenes/game_main.tscn) for gameplay.
3. [`../scenes/game_main.gd`](../scenes/game_main.gd) connects the player, terrain, landmarks, residents, and interaction state to shared runtime services, and registers the overworld weather nodes with the global weather manager.
4. Screen scripts under [`../ui/screens/`](../ui/screens) read shared state and send actions back to the shell.

## Main Systems

### App Shell And Screens

Primary files:

- [`../main.tscn`](../main.tscn)
- [`../main.gd`](../main.gd)
- [`../ui/screens/`](../ui/screens)
- [`../ui/ui_style.gd`](../ui/ui_style.gd)

Responsibilities:

- boot, title, new game, free walk, pause, journal, settings, credits, ending, and confirm flows
- scaling the `1920 x 1080` authored UI to the live viewport
- keeping gameplay in one scene while overlays come and go on top of it

Boundary:

- UI scripts should present state and route actions. They should not become the home for gameplay rules.

### World Scene And Overworld Integration

Primary files:

- [`../scenes/game_main.tscn`](../scenes/game_main.tscn)
- [`../scenes/game_main.gd`](../scenes/game_main.gd)
- [`../weather/weather_manager.gd`](../weather/weather_manager.gd)
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd)
- [`../terrain/terrain.tscn`](../terrain/terrain.tscn)
- [`../terrain/terrain.gd`](../terrain/terrain.gd)
- [`../terrain/low_poly_terrain_3d.gd`](../terrain/low_poly_terrain_3d.gd)
- [`../terrain/low_poly_art_style_3d.gd`](../terrain/low_poly_art_style_3d.gd)
- [`../terrain/low_poly_postcard_diorama_style.tres`](../terrain/low_poly_postcard_diorama_style.tres)
- [`../terrain/low_poly_world_coordinates_3d.gd`](../terrain/low_poly_world_coordinates_3d.gd)
- [`../architecture/low_poly/low_poly_landmark_proxy_3d.gd`](../architecture/low_poly/low_poly_landmark_proxy_3d.gd)
- [`../terrain/island_generation_profile.tres`](../terrain/island_generation_profile.tres)
- [`../terrain/terrain_generation_profile.gd`](../terrain/terrain_generation_profile.gd)
- [`../terrain/terrain_mask_rule.gd`](../terrain/terrain_mask_rule.gd)

Responsibilities:

- main island scene setup
- mask-driven terrain generation and generated helper-layer lifecycle
- shared authored terrain-profile resource used by both direct terrain validation and the gameplay scene instance
- terrain mask legend, per-color semantics, and street-connect defaults
- parallel low-poly 3D terrain with heightmap-level water and visible seabed prototyping, shared style presets, canonical postcard landmark proxying, and shared terrain-mask-pixel/isometric-position to 3D-world coordinate conversion
- player spawn and camera context
- shared overworld weather host registration for reusable cloud-shadow, rain, fog, and ground-impact rendering
- global weather-manager ownership for runtime weather-rig instancing, overworld random weather cycling, and shared wind sync across reusable rain/fog/cloud passes
- scene-owned BGM playback driven by shared location and melody-progress context
- shared y-sorted actor layer for the player and spawned residents
- landmark lookup and location syncing
- data-driven resident spawning, inspect/talk prompts, and overworld resident presentation
- extracted world helpers under `scenes/` now own route resolution (`route_resolver.gd`), resident spawning (`resident_spawner.gd`), tunnel context (`tunnel_context.gd`), and optional NPC route debug drawing (`npc_route_debug_drawer.gd`)
- resident route resolution from authored anchors into runtime world-space waypoints, including tunnel path expansion and portal-direction helper points
- tunnel interior context, tunnel-resident visibility syncing, and ground-building masking when the player actually enters a tunnel interior
- lightweight story inspectables authored inside major landmark scenes so route-state changes can surface on non-resident world objects as well as in dialogue without losing level context
- `scenes/game_main.gd` now routes resident talk and all scene-authored `StorySubjectArea2D` interactions through one story-subject dispatch path so world nodes keep placement and level context while shared StoryEvent metadata owns visibility, response selection, and side effects
- feeding current world context into `AppState`

Boundary:

- Keep scene-specific world integration here instead of scattering it across UI files or unrelated helpers.
- Keep terrain semantics in terrain profile/rule resources instead of hard-coding new mask-color branches directly into unrelated systems.
- Keep low-poly 3D terrain and coordinate work in the prototype lane until an explicit 3D world-integration phase starts.
- Keep low-poly 3D palette, water tuning, camera, lighting, and proxy-landmark tuning in `LowPolyArtStyle3D` resources while the art direction is still exploratory.

### Shared State And Catalogs

Primary files:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/melody_catalog.gd`](../game/melody_catalog.gd)
- [`../game/resident_catalog.gd`](../game/resident_catalog.gd)
- [`../game/story_event_catalog.gd`](../game/story_event_catalog.gd)
- [`../game/story_event_service.gd`](../game/story_event_service.gd)
- [`../game/story_time_service.gd`](../game/story_time_service.gd)
- [`../game/story_route_graph.gd`](../game/story_route_graph.gd)
- [`../game/storylines/`](../game/storylines)
- [`../game/audio_settings_service.gd`](../game/audio_settings_service.gd)
- [`../game/resident_interaction_service.gd`](../game/resident_interaction_service.gd)
- [`../game/resident_system/`](../game/resident_system)
- [`../game/residents/`](../game/residents)
- [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd)
- [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd)

Responsibilities:

- shared mode, chapter, location, objective, hint, save status, and summary data
- shared seasonal story state: `season_phase`, `story_day`, `world_hour`, derived `time_of_day`, `route_progress`, `story_flags`, active leads, and endgame state
- first-pass generic StoryEvent routing now lives in `game/story_event_service.gd`, composed by `AppState`, while `game/story_event_catalog.gd` now owns the full melody-landmark interaction spine plus its landmark prompt-completion/reward world events: ferry harbor clue and onboarding reward, Trinity cue/chime/reward beats, Bi Shan echoes/chamber/reward, Long Shan entry/checkpoints/exit/reward, Bagua synthesis/reward, and the harbor-stage prompt/performance completion
- shared melody definitions and melody-progress state used by the journal and future performance systems
- modular storyline route/event definitions in `game/storylines/`, with `story_route_graph.gd` loading them once into a runtime definition cache and projecting them into route progress, lead selection, display-order-independent route-score gates, canonical story-event availability checks, and endgame-trigger logic
- resident and player-facing catalog data
- `AppState` now composes focused helper scripts for journal text (`journal_builder.gd`), player profile/costume ownership (`player_profile_service.gd`), story autosave (`story_save_service.gd`), lightweight story time (`story_time_service.gd`), landmark/melody progression (`landmark_progression.gd`), resident dialogue/application (`resident_interaction_service.gd`), and runtime audio/settings state (`audio_settings_service.gd`)
- resident dialogue and shared StoryEvent effects now consume the route graph's story-event availability API instead of duplicating narrative prerequisite rules through custom resident gates
- resident routine overrides are now part of shared story state so story effects can temporarily redirect spawn, movement, or behavior through the same `AppState` getters and autosave pipeline the rest of the game already uses
- the app shell now opens the ending overlay from the shared `endgame_started` story milestone instead of relying on the older landmark-only ending assumption
- lazy resident definition/profile initialization so startup does not eagerly build the full resident runtime just to load the shared state service
- resident definition resources for appearance, dialogue, routine, and behavior metadata
- all 25 resident definitions are authored as standalone `.tres` files under `game/residents/definitions/`; `ResidentCatalog` loads them at runtime and the built-in definition helpers exist only as infrastructure for the external loading pipeline
- resident runtime profiles plus resident appearance, spawn, movement, behavior, and journal-facing lookup helpers
- state that multiple screens or systems need to read consistently

Boundary:

- `AppState` is for shared UI/progression state. Do not use it as a dumping ground for scene-local implementation details.

### Runtime Service Lookup

Primary file:

- [`../game/app_runtime.gd`](../game/app_runtime.gd)
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd)
- [`../weather/weather_manager.gd`](../weather/weather_manager.gd)
- [`../weather/overworld_weather_preset.gd`](../weather/overworld_weather_preset.gd)
- [`../weather/overworld_weather_preset.tres`](../weather/overworld_weather_preset.tres)

Responsibilities:

- resolves the one scene-owned `AppStateService` instance for runtime callers without using a Project Settings autoload
- resolves the one scene-owned `WeatherManager` instance for runtime callers without using a Project Settings autoload
- keeps the default overworld weather tuning in a shared resource consumed by both the real overworld and the focused weather sandbox
- keeps overworld weather-cycle selection, interpolation, and shared wind-sync application out of `game_main.tscn`
- resolves the live `HumanBody2D` player from the existing `"player"` group for scene-graph helpers such as visibility masking

Boundary:

- `AppRuntime` and `WeatherRuntime` are lookup helpers, not gameplay-state owners
- `WeatherManager` owns the global overworld weather-cycle policy and the live application of synced wind settings to registered weather nodes
- UI and progression code should use `AppState`, not raw player lookup, for anything player-facing or save-relevant
- the player group contract must stay valid for scene-graph helpers that resolve the player through `AppRuntime`

### Characters, Interaction, And Behavior

Primary folders:

- [`../characters/control/`](../characters/control)
- [`../characters/control/bt/`](../characters/control/bt)
- [`../characters/universal_lpc/`](../characters/universal_lpc)
- [`../common/gui/`](../common/gui)

Responsibilities:

- player and NPC control
- interaction discovery and inspect requests
- behavior-tree support code
- resident presentation hookup, collision-aware routed NPC movement, character visuals, and in-world speech balloon UI
- metadata-driven LPC sprite composition and development-time metadata generation tooling

Notes:

- The runtime game consumes the prebuilt Universal LPC metadata under [`../resources/sprites/universal_lpc/`](../resources/sprites/universal_lpc).
- [`../characters/human_body_2d.gd`](../characters/human_body_2d.gd) owns the root material/shader setup for composed avatars, while the child Universal LPC node composes the visible layers.
- [`../characters/human_body_3d.gd`](../characters/human_body_3d.gd), [`../characters/low_poly_character_config.gd`](../characters/low_poly_character_config.gd), [`../characters/procedural_low_poly_character_rig.gd`](../characters/procedural_low_poly_character_rig.gd), [`../characters/control/base_controller_3d.gd`](../characters/control/base_controller_3d.gd), and [`../characters/control/player_controller_3d.gd`](../characters/control/player_controller_3d.gd) own the parallel low-poly 3D actor/controller prototype. They mirror the main `HumanBody2D` and controller hierarchy for future 3D slices, while the optional procedural rig provides the first seeded runtime-generated low-poly character lane. The runtime overworld still uses the 2D actor/controller stack.

### World Spaces And Landmark Content

Primary folders:

- [`../architecture/`](../architecture)
- [`../architecture/components/`](../architecture/components)
- [`../common/`](../common)

Responsibilities:

- landmark scenes such as Bagua Tower, tunnels, church, and ferry content
- reusable architectural pieces shared by those spaces
- shared multi-level helpers such as `LevelNode2D`, `LevelArea2D`, and `LevelRegistry`

### Reusable Game Modules

Primary folders:

- [`../game/grid_board_game/`](../game/grid_board_game)
- [`../game/marble_game/`](../game/marble_game)
- [`../game/bgm_catalog.gd`](../game/bgm_catalog.gd)
- [`../game/bgm_manager.gd`](../game/bgm_manager.gd)
- [`../game/piano_game/`](../game/piano_game)

Responsibilities:

- self-contained gameplay modules and prototypes
- seed-pool BGM catalog authoring plus scene-owned weighted playback orchestration
- feature-specific scenes, scripts, rules, AI helpers, and local test scenes

Boundary:

- Extend the owning feature folder before creating duplicate logic elsewhere.

### Editor Tooling

Primary folders:

- [`../addons/low_poly_building_editor/`](../addons/low_poly_building_editor)
- [`../addons/mp3_to_ogg/`](../addons/mp3_to_ogg)
- [`../addons/storyline_editor/`](../addons/storyline_editor)

Responsibilities:

- project-local editor tooling for authoring content and validating assets
- low-poly building blockout authoring through normal scene nodes, including grid-snapped walls, window openings, generated wall collision, and prop placement
- audio conversion and storyline graph/route editing workflows

Boundary:

- Editor plugins are authoring helpers. They should not become runtime gameplay services or be wired into `main.tscn`.
- Building-editor-generated content should remain ordinary scene-owned nodes under `BuildingEditor3D` coordinators.

### Submodule Layer

Primary folders:

- [`../godot_common/`](../godot_common)
- [`../godot_tilemap/`](../godot_tilemap)
- [`../agent_tools/`](../agent_tools)
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator)

Responsibilities:

- shared support code used by the main project
- reusable tilemap tooling and helpers
- agent runbooks and shared documentation assets
- third-party LPC asset generator content

Boundary:

- These folders are governed as submodules. Update them intentionally, and document interface or pointer changes in the parent repo.

## System Relationships

- The app shell owns navigation and overlays.
- The world scene owns moment-to-moment overworld behavior.
- `AppState` is the bridge between gameplay context and UI presentation.
- Feature modules stay local until they are intentionally wired into the main flow.
- Submodules provide supporting code or assets, but the parent repo owns how they are integrated.

## Where Changes Usually Belong

- Screen flow, menus, overlays, HUD: [`../ui/`](../ui)
- Shared player-facing state: [`../game/app_state.gd`](../game/app_state.gd)
- Overworld logic and resident syncing: [`../scenes/game_main.gd`](../scenes/game_main.gd)
- Player or NPC behavior: [`../characters/control/`](../characters/control)
- Landmark scenes and reusable architecture pieces: [`../architecture/`](../architecture)
- Reusable mini-games or subsystems: [`../game/`](../game)

## Update This Doc When

- the startup scene or app shell ownership changes
- a new top-level subsystem is introduced
- ownership moves between UI, world integration, shared state, or feature modules
- a feature module becomes part of the main game flow
- a submodule becomes a required integration point for new runtime behavior
