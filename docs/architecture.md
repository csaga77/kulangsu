# Kulangsu Architecture

Read [`design_brief.md`](design_brief.md) first. This file is the high-level map of the running game and the ownership boundaries future changes should respect.

## Repo Shape

This repository has two layers:

- the main Godot game project
- supporting submodule repositories listed in [`submodules.md`](submodules.md)

Most gameplay and scene work happens in the main repo. Shared or vendor-style code in submodules should be treated as separate ownership boundaries.

## Startup Flow

1. [`../project.godot`](../project.godot) boots the app through [`../main.tscn`](../main.tscn).
2. [`../main.gd`](../main.gd) builds the UI shell, delegates navigation history and presentation rules to [`../ui/app_screen_router.gd`](../ui/app_screen_router.gd), ensures the shared runtime services exist through [`../game/app_runtime.gd`](../game/app_runtime.gd) and [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd), and instantiates the low-poly 3D overworld [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn) for gameplay.
3. [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd) composes the player, terrain, landmarks, residents, audio, save anchors, and 3D weather rig with focused actor-surface and story-interaction components, then connects them to shared runtime services.
4. Screen scripts under [`../ui/screens/`](../ui/screens) read shared state and send actions back to the shell.

## Main Systems

### App Shell And Screens

Primary files:

- [`../main.tscn`](../main.tscn)
- [`../main.gd`](../main.gd)
- [`../ui/app_screen_router.gd`](../ui/app_screen_router.gd)
- [`../ui/screens/`](../ui/screens)
- [`../ui/ui_style.gd`](../ui/ui_style.gd)

Responsibilities:

- boot, title, new game, free walk, pause, journal, settings, credits, ending, and confirm flows
- stack-based screen history plus centralized derivation of panel, HUD, backdrop, gameplay visibility, BGM ducking, and pause state
- scaling the `1920 x 1080` authored UI to the live viewport
- keeping gameplay in one scene while overlays come and go on top of it

Boundary:

- UI scripts should present state and route actions. They should not become the home for gameplay rules.
- Screen handlers request route replacement, push, or pop operations; only the shell's route renderer applies global visibility and pause state.

### World Scene And Overworld Integration

Primary files:

- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn)
- [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)
- [`../game/world/actor_surface_follower.gd`](../game/world/actor_surface_follower.gd)
- [`../game/world/story_interaction_coordinator.gd`](../game/world/story_interaction_coordinator.gd)
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
- [`../characters/resident_factory.gd`](../characters/resident_factory.gd)
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
- data-driven resident spawning and overworld resident presentation
- lightweight story subjects authored inside the world scene (`StorySubject3D` nodes under the landmark proxies) so route-state changes can surface on world objects as well as in dialogue
- `ActorSurfaceFollower` owns player grounding and shallow-water seating after the world supplies its actor, terrain, and coordinate adapter
- `StoryInteractionCoordinator` owns scene-local subject discovery, deterministic proximity selection, inspect/talk hints, and dispatch through `AppState.activate_story_subject`; it republishes hint context only when the selected subject or committed story state changes, and subjects outside its configured world root are ignored
- feeding current world context into `AppState`

The 2D overworld (`scenes/game_main.*`) and its extracted helpers (`route_resolver.gd`, `resident_spawner.gd`, `tunnel_context.gd`, `npc_route_debug_drawer.gd`) have been removed. 2D-only behaviors they owned - tunnel interior context, tunnel-resident visibility masking, and routed waypoint travel through tunnels - have no 3D equivalent yet; resident routine overrides are currently validated at the shared-state level only.

Boundary:

- Keep `game_world_3d.gd` as the composition root; keep actor-surface policy and story-interaction coordination in their focused `game/world/` components.
- Keep terrain semantics in terrain profile/rule resources instead of hard-coding new mask-color branches directly into unrelated systems.
- Keep low-poly 3D palette, water tuning, camera, and lighting in `LowPolyArtStyle3D` resources.

### Shared State And Catalogs

Primary files:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/app_state/`](../game/app_state)
- [`../game/landmarks/`](../game/landmarks)
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

- one typed canonical `AppStateSnapshot` for shared session, progression, player, settings, checkpoint, and save-metadata values
- one cached `AppStateProjection` for chapter/time labels, route progress and leads, fragment totals, display lists, unlocked costumes, ending summary, and UI/world/audio views
- typed landmark definitions for stable ids, display names, world-node mapping, authored coordinates, resume defaults, audio cues, and initial progress profiles; `AppState`, the StoryEffect schema, and the production world consume the same catalog
- first-pass generic StoryEvent routing now lives in `game/story_event_service.gd`, composed by `AppState`, while `game/story_event_catalog.gd` now owns the full melody-landmark interaction spine plus its landmark prompt-completion/reward world events: ferry harbor clue and onboarding reward, Trinity cue/chime/reward beats, Bi Shan echoes/chamber/reward, Long Shan entry/checkpoints/exit/reward, Bagua synthesis/reward, and the harbor-stage prompt/performance completion
- shared melody definitions and melody-progress state used by the journal and future performance systems
- modular storyline route/event definitions in `game/storylines/`, with `story_route_graph.gd` loading them once into a runtime definition cache and projecting them into route progress, lead selection, display-order-independent route-score gates, canonical story-event availability checks, and endgame-trigger logic
- resident and player-facing catalog data
- `AppStateService` owns exactly one canonical snapshot and one projection cache. Every semantic command runs against a detached transition, normalizes once, commits once, optionally autosaves once, emits one `state_committed(changes)`, and only then emits queued imperative events.
- high-frequency world-context calls reject unchanged values before allocating a transition. Detached reducer contexts seed from the committed projection, reuse immutable catalog/index caches, and explicitly detach helper back-references when a command or read calculation finishes.
- `StoryEventService`, `StoryRouteGraph`, and `ResidentInteractionService` operate on a detached reducer context and never retain the live store, emit public signals, or perform file I/O.
- `game/app_state/story_save_codec.gd` owns defaults, validation, V1-to-V2 migration, and V2 mapping; `story_save_repository.gd` owns the configurable persistence path and file I/O.
- resident dialogue and shared StoryEvent effects now consume the route graph's story-event availability API instead of duplicating narrative prerequisite rules through custom resident gates
- resident routine overrides are canonical story state and affect projection-based spawn/movement/behavior configuration. The production 3D world still does not reapply a changed override to an already-spawned resident; the implementation plan schedules that gap under Next world-state reactivity.
- the app shell now opens the ending overlay from the shared `endgame_started` story milestone instead of relying on the older landmark-only ending assumption
- lazy resident definition/profile initialization so startup does not eagerly build the full resident runtime just to load the shared state service
- resident definition resources for appearance, dialogue, routine, and behavior metadata
- all 25 resident definitions are authored as standalone `.tres` files under `game/residents/definitions/`; `ResidentCatalog` loads them at runtime and the built-in definition helpers exist only as infrastructure for the external loading pipeline
- resident runtime profiles plus resident appearance, spawn, movement, behavior, and journal-facing lookup helpers
- state that multiple screens or systems need to read consistently

Boundary:

- `AppState` is for shared UI/progression state. Production callers read detached data through `get_snapshot()` or `get_projection()` and mutate only through semantic commands; direct field access is not part of the contract.
- Reducers receive only a detached transition context. Runtime-port forwarding and `runtime_*` methods are intentionally absent.
- `game/landmarks/` owns immutable authored landmark metadata and initial-state presets. Mutable landmark progress remains owned by `AppState`, and interaction rules remain owned by StoryEvents and scene-authored `StorySubject3D` nodes.
- Do not use `AppState` as a dumping ground for scene-local implementation details.

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

- 3D player control, collision-aware movement, and locomotion presentation
- interaction discovery and inspect requests
- resident model presentation, local wandering and talk-facing behavior, and in-world speech balloon UI
- shared low-poly model selection plus transparent 3D player preview rendering

Notes:

- [`../characters/human_body_3d.gd`](../characters/human_body_3d.gd), [`../characters/control/base_controller_3d.gd`](../characters/control/base_controller_3d.gd), and [`../characters/control/player_controller_3d.gd`](../characters/control/player_controller_3d.gd) own the runtime actor/controller stack. `HumanBody3D` renders one premade low-poly GLB character model (default [`../assets/characters/male.glb`](../assets/characters/male.glb), with `boy.glb`/`female.glb` alternates) whose integrated appearance and idle/walk/run animation come from the model asset. Gravity, static walls, front and side stair behavior, and dynamic-body pushing are covered by [`../characters/tests/test_character_collisions.tscn`](../characters/tests/test_character_collisions.tscn).
- [`../characters/character_model_catalog_3d.gd`](../characters/character_model_catalog_3d.gd) centralizes player and resident model selection, while [`../characters/character_preview_3d.gd`](../characters/character_preview_3d.gd) provides the transparent SubViewport preview used by customization and journal UI.

### World Spaces And Landmark Content

Primary folders:

- [`../architecture/`](../architecture)
- [`../architecture/bagua_tower/`](../architecture/bagua_tower)
- [`../architecture/piano_ferry/`](../architecture/piano_ferry)
- [`../game/landmarks/`](../game/landmarks)

Responsibilities:

- editable low-poly 3D landmark scenes and their reproducible generators
- `LandmarkDefinition` resources own the static mapping from landmark ids to display names, world proxy paths, authored isometric coordinates, audio cues, resume defaults, and progress presets
- `game_world_3d.tscn` owns the actual landmark proxy nodes and landmark/inspectable hotspots; `game_world_3d.gd` resolves their placement and audio through `LandmarkCatalog`
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
- low-poly building and design-time street-network authoring through normal scene nodes. `StreetNetwork3D` owns stable junction/segment/profile resources, adaptive curves/grades, segment sweeps, and dedicated multi-road junction surfaces; legacy `Street3D` remains compatible. `LowPolyTerrain3D` converts deterministic mask paths into one generated network and shapes its supporting bed from segment corridors plus junction footprints before terrain mesh construction (see [`../addons/low_poly_building_editor/README.md`](../addons/low_poly_building_editor/README.md))
- deterministic, versioned JSON-to-scene low-poly building and street generation plus graphical seeded-variant thumbnails/contact sheets for agents and batch authoring, kept inside the building-editor addon
- audio conversion (see [`../addons/mp3_to_ogg/README.md`](../addons/mp3_to_ogg/README.md)) and storyline graph/route editing (see [`../addons/storyline_editor/README.md`](../addons/storyline_editor/README.md))
- scene-asset browsing/placement (see [`../addons/asset_browser/README.md`](../addons/asset_browser/README.md) and the vendored [`../addons/asset_placer/README.md`](../addons/asset_placer/README.md))

Boundary:

- Editor plugins are authoring helpers. They should not become runtime gameplay services or be wired into `main.tscn`.
- Project-specific storyline semantics plug into the generic storyline editor through its optional `StorylineHostValidationProvider` setting. The parent provider may depend on the addon interface; the addon must not depend on Kulangsu classes or paths.
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
- offline third-party LPC asset generator content and licensing reference; the production actor,
  resident, and preview runtime does not depend on it
- reusable MP3 conversion editor tooling
- reusable low-poly building and street authoring tooling
- reusable storyline schema, catalog loader, and route/dependency editor tooling over parent-owned authored data (routes, phase vocabulary, graph layout) plus an optional host-validation interface, configured through `storyline_editor/*` project settings

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
- Overworld composition, location, and resident syncing: [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)
- Actor grounding and world-subject coordination: [`../game/world/`](../game/world)
- Player or NPC behavior: [`../characters/control/`](../characters/control)
- Landmark scenes and reusable architecture pieces: [`../architecture/`](../architecture)
- Reusable mini-games or subsystems: [`../game/`](../game)

## Update This Doc When

- the startup scene or app shell ownership changes
- a new top-level subsystem is introduced
- ownership moves between UI, world integration, shared state, or feature modules
- a feature module becomes part of the main game flow
- a submodule becomes a required integration point for new runtime behavior
