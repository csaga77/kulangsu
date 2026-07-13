# Kulangsu Architecture

Read [`design_brief.md`](design_brief.md) first. This file is the high-level map of the running game and the ownership boundaries future changes should respect.

## Repo Shape

This repository has two layers:

- the main Godot game project
- supporting submodule repositories listed in [`submodules.md`](submodules.md)

Most gameplay and scene work happens in the main repo. Shared or vendor-style code in submodules should be treated as separate ownership boundaries.

## Startup Flow

1. [`../project.godot`](../project.godot) boots the app through [`../main.tscn`](../main.tscn).
2. [`../main.gd`](../main.gd) builds the UI shell, ensures the shared runtime services exist through [`../game/app_runtime.gd`](../game/app_runtime.gd) and [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd), and instantiates the low-poly 3D overworld [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn) for gameplay.
3. [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd) connects the player, terrain, landmarks, residents, interaction state, audio, save anchors, and 3D weather rig to shared runtime services.
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

- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn)
- [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)
- [`../weather/weather_manager.gd`](../weather/weather_manager.gd)
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd)
- [`../terrain/low_poly_terrain_3d.gd`](../terrain/low_poly_terrain_3d.gd)
- [`../terrain/low_poly_terrain_sampler.gd`](../terrain/low_poly_terrain_sampler.gd)
- [`../terrain/low_poly_terrain_mesh_builder.gd`](../terrain/low_poly_terrain_mesh_builder.gd)
- [`../terrain/low_poly_art_style_3d.gd`](../terrain/low_poly_art_style_3d.gd)
- [`../terrain/low_poly_postcard_diorama_style.tres`](../terrain/low_poly_postcard_diorama_style.tres)
- [`../terrain/low_poly_world_coordinates_3d.gd`](../terrain/low_poly_world_coordinates_3d.gd)
- [`../terrain/low_poly_water_wind_adapter.gd`](../terrain/low_poly_water_wind_adapter.gd)
- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn) / [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)
- [`../game/story_subject_3d.gd`](../game/story_subject_3d.gd)
- [`../characters/resident_presenter_3d.gd`](../characters/resident_presenter_3d.gd)
- [`../characters/control/resident_controller_3d.gd`](../characters/control/resident_controller_3d.gd)
- [`../common/gui/speech_balloon_3d.gd`](../common/gui/speech_balloon_3d.gd)
- [`../terrain/island_generation_profile.tres`](../terrain/island_generation_profile.tres)
- [`../terrain/terrain_generation_profile.gd`](../terrain/terrain_generation_profile.gd)
- [`../terrain/terrain_mask_rule.gd`](../terrain/terrain_mask_rule.gd)

Responsibilities:

- main island scene setup
- mask-driven terrain generation and generated helper-layer lifecycle
- shared authored terrain-profile resource used by both direct terrain validation and the gameplay scene instance
- terrain mask legend, per-color semantics, and street-connect defaults
- low-poly 3D terrain with split image-sampling and mesh-building stages, heightmap-level water, visible seabed, shader-displaced wind-aware water, shared style presets, and shared terrain-mask-pixel/isometric-position to 3D-world coordinate conversion
- the production low-poly 3D overworld (`game_world_3d`), which assembles terrain, `HumanBody3D`, camera, five landmark anchors (three stylized building instances plus tunnel markers), wandering residents, the complete set of 15 landmark and 5 inspectable `StorySubject3D` interactions, shared BGM/landmark-cue audio, manager-cycled 3D rain/fog/cloud light plus wind-aware water, and location/resume syncing into `AppState`
- player spawn and camera context
- shared overworld registration of one `WeatherRig3D` presentation target
- global weather-manager ownership for random weather cycling and shared wind sync across the 3D rain/fog/cloud presentation and terrain water
- scene-owned BGM playback driven by shared location and melody-progress context
- shared y-sorted actor layer for the player and spawned residents
- landmark lookup and location syncing
- data-driven resident spawning, inspect/talk prompts, and overworld resident presentation
- lightweight story subjects authored inside the world scene (`StorySubject3D` nodes under the landmark proxies) so route-state changes can surface on world objects as well as in dialogue
- `scenes/game_world_3d.gd` routes resident talk and all scene-authored `StorySubject3D` interactions through one story-subject dispatch path (`AppState.activate_story_subject`) so world nodes keep placement context while shared StoryEvent metadata owns visibility, response selection, and side effects
- feeding current world context into `AppState`

The 2D overworld (`scenes/game_main.*`) and its extracted helpers (`route_resolver.gd`, `resident_spawner.gd`, `tunnel_context.gd`, `npc_route_debug_drawer.gd`) have been removed. 2D-only behaviors they owned - tunnel interior context, tunnel-resident visibility masking, and routed waypoint travel through tunnels - have no 3D equivalent yet; resident routine overrides are currently validated at the shared-state level only.

Boundary:

- Keep scene-specific world integration here instead of scattering it across UI files or unrelated helpers.
- Keep terrain semantics in terrain profile/rule resources instead of hard-coding new mask-color branches directly into unrelated systems.
- Keep low-poly 3D palette, water tuning, camera, and lighting in `LowPolyArtStyle3D` resources.

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

Responsibilities:

- resolves the one scene-owned `AppStateService` instance for runtime callers without using a Project Settings autoload
- resolves the one scene-owned `WeatherManager` instance for runtime callers without using a Project Settings autoload
- keeps overworld weather-cycle selection, interpolation, and shared wind publication out of `game_world_3d.tscn`
- applies the active weather state only to the registered `WeatherRig3D`; water consumes the same published wind through its adapter

Boundary:

- `AppRuntime` and `WeatherRuntime` are lookup helpers, not gameplay-state owners
- `WeatherManager` owns the global overworld weather-cycle policy and the live application of synced wind settings to registered weather nodes
- UI and progression code should use `AppState`, not raw player lookup, for anything player-facing or save-relevant
- the player group contract must stay valid for scene-graph helpers that resolve the player through `AppRuntime`

### Characters, Interaction, And Behavior

Primary folders:

- [`../characters/control/`](../characters/control)
- [`../common/gui/`](../common/gui)

Responsibilities:

- player and NPC control
- interaction discovery and inspect requests
- behavior-tree support code
- resident presentation hookup, collision-aware routed NPC movement, character visuals, and in-world speech balloon UI
- metadata-driven LPC sprite composition and development-time metadata generation tooling

Notes:

- [`../characters/human_body_3d.gd`](../characters/human_body_3d.gd), [`../characters/control/base_controller_3d.gd`](../characters/control/base_controller_3d.gd), and [`../characters/control/player_controller_3d.gd`](../characters/control/player_controller_3d.gd) own the runtime actor/controller stack. `HumanBody3D` renders one premade low-poly GLB character model (default [`../assets/characters/male.glb`](../assets/characters/male.glb), with `boy.glb`/`female.glb` alternates) whose integrated appearance and idle/walk/run animation come from the model asset. Gravity, static walls, front and side stair behavior, and dynamic-body pushing are covered by [`../characters/tests/test_character_collisions.tscn`](../characters/tests/test_character_collisions.tscn).
- [`../characters/character_model_catalog_3d.gd`](../characters/character_model_catalog_3d.gd) centralizes player and resident model selection, while [`../characters/character_preview_3d.gd`](../characters/character_preview_3d.gd) provides the transparent SubViewport preview used by customization and journal UI.

### World Spaces And Landmark Content

Primary folders:

- [`../architecture/`](../architecture)
- [`../architecture/bagua_tower/`](../architecture/bagua_tower)
- [`../architecture/piano_ferry/`](../architecture/piano_ferry)

Responsibilities:

- editable low-poly 3D landmark scenes and their reproducible generators
- production landmark placement and all landmark/inspectable hotspots remain owned by `game_world_3d.tscn`
- the retired 2D landmark/component and multi-level helper stack is no longer part of runtime architecture

### Reusable Game Modules

Primary folders:

- [`../game/grid_board_game/`](../game/grid_board_game)
- [`../game/marble_game/`](../game/marble_game)
- [`../game/bgm_catalog.gd`](../game/bgm_catalog.gd)
- [`../game/bgm_manager.gd`](../game/bgm_manager.gd)
- [`../game/piano_game/`](../game/piano_game)

Responsibilities:

- self-contained gameplay modules and prototypes
- the grid-board and piano prototypes intentionally keep local `Node2D` rendering; they are isolated activities, not part of the overworld scene graph
- seed-pool BGM catalog authoring plus scene-owned weighted playback orchestration
- feature-specific scenes, scripts, rules, AI helpers, and local test scenes

Boundary:

- Extend the owning feature folder before creating duplicate logic elsewhere.

### Addons And Editor Tooling

Primary folders:

- [`../addons/low_poly_building_editor/`](../addons/low_poly_building_editor)
- [`../addons/mp3_to_ogg/`](../addons/mp3_to_ogg)
- [`../addons/storyline_editor/`](../addons/storyline_editor)
- [`../addons/asset_browser/`](../addons/asset_browser)
- [`../addons/asset_placer/`](../addons/asset_placer) (third-party, vendored)

Each plugin documents itself in its own root `README.md` (with deeper docs under the plugin's `docs/` when needed); see those for full descriptions.

Responsibilities:

- project-local editor tooling for authoring content and validating assets
- low-poly building and terrain-profiled street blockout authoring through normal scene nodes, with Street3D owning visible road/kerb/footpath/stair geometry while LowPolyTerrain3D extracts deterministic multipoint centerlines from mask STREET cells, creates transient Street3D assemblies, and shapes its own supporting bed from generated or authored published corridors before terrain mesh construction (see [`../addons/low_poly_building_editor/README.md`](../addons/low_poly_building_editor/README.md))
- deterministic, versioned JSON-to-scene low-poly building and street generation plus graphical seeded-variant thumbnails/contact sheets for agents and batch authoring, kept inside the building-editor addon
- audio conversion (see [`../addons/mp3_to_ogg/README.md`](../addons/mp3_to_ogg/README.md)) and storyline graph/route editing (see [`../addons/storyline_editor/README.md`](../addons/storyline_editor/README.md))
- scene-asset browsing/placement (see [`../addons/asset_browser/README.md`](../addons/asset_browser/README.md) and the vendored [`../addons/asset_placer/README.md`](../addons/asset_placer/README.md))

Boundary:

- Editor plugins are authoring helpers. They should not become runtime gameplay services or be wired into `main.tscn`.
- Runtime addons may be consumed by game-owned actors, but gameplay movement, collision, and appearance-catalog policy stay outside the addon.
- `addons/mp3_to_ogg`, `addons/low_poly_building_editor`, and `addons/storyline_editor` are submodule repository boundaries; reusable changes land in those repositories first, then the parent intentionally updates their pointers.
- Building-editor-generated content should remain ordinary scene-owned nodes under `Building3D` coordinators.

### Submodule Layer

Primary folders:

- [`../godot_common/`](../godot_common)
- [`../agent_tools/`](../agent_tools)
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator)
- [`../addons/mp3_to_ogg/`](../addons/mp3_to_ogg)
- [`../addons/low_poly_building_editor/`](../addons/low_poly_building_editor)
- [`../addons/storyline_editor/`](../addons/storyline_editor)

Responsibilities:

- shared support code used by the main project
- agent runbooks and shared documentation assets
- third-party LPC asset generator content
- reusable MP3 conversion editor tooling
- reusable low-poly building and street authoring tooling
- reusable storyline schema, catalog loader, and route/dependency editor tooling over parent-owned authored data (routes, phase vocabulary, graph layout), located through `storyline_editor/*` project settings

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
- Overworld logic and resident syncing: [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)
- Player or NPC behavior: [`../characters/control/`](../characters/control)
- Landmark scenes and reusable architecture pieces: [`../architecture/`](../architecture)
- Reusable mini-games or subsystems: [`../game/`](../game)

## Update This Doc When

- the startup scene or app shell ownership changes
- a new top-level subsystem is introduced
- ownership moves between UI, world integration, shared state, or feature modules
- a feature module becomes part of the main game flow
- a submodule becomes a required integration point for new runtime behavior
