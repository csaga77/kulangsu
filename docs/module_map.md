# Kulangsu Module Map

Read [`design_brief.md`](design_brief.md) and [`architecture.md`](architecture.md) first. Use this file to find where a feature probably belongs before you edit.

## Entry Points

- [`../project.godot`](../project.godot) - Godot project configuration, input map, and main scene
- [`../main.tscn`](../main.tscn) / [`../main.gd`](../main.gd) - app startup, route rendering, and screen-action wiring
- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn) / [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd) - production low-poly 3D overworld composition root: builds terrain, actor/camera, landmarks and residents; composes surface-follow, unified contextual actions, story dispatch, traversal completion, and recovery; owns audio/generated collision; and forwards only Story-mode semantic results
- [`../scenes/tests/capture_game_world_3d_qa.tscn`](../scenes/tests/capture_game_world_3d_qa.tscn) - graphical Metal QA runner that produces the five fixed-camera acceptance PNGs plus a raw 5-second-warm-up/60-second performance report, cold-terrain timing, and resident/per-landmark visibility variants under `design/qa/low_poly_3d/`
- [`../game/tests/persistence/fixtures/`](../game/tests/persistence/fixtures/) -
  reversible fixed-save launch/restore scenes for Milestone A and Milestone B
  production-flow acceptance
- [`../game/tests/persistence/test_household_care_continue_fixtures.tscn`](../game/tests/persistence/test_household_care_continue_fixtures.tscn) - focused regression for fixed-fixture metadata, load normalization, journal/world/dialogue projection, repeated Continue, and route/endgame continuity
- [`../weather/`](../weather) - 3D weather presentation, the global weather manager/runtime, and focused 3D capture validation
- [`../weather/weather_manager.gd`](../weather/weather_manager.gd) - global overworld weather manager that owns weighted weather-state cycling, applies it to the registered `WeatherRig3D`, and publishes synced wind for terrain water
- [`../weather/weather_rig_3d.gd`](../weather/weather_rig_3d.gd) - 3D weather presentation target registered with `WeatherManager`; translates the shared cycle into player-following rain particles, `WorldEnvironment` fog, and moving cloud-cover sun modulation while water continues to consume the published wind
- [`../weather/tests/capture_weather_3d.tscn`](../weather/tests/capture_weather_3d.tscn) - graphical steady-rain validation/capture scene for the 3D runtime weather rig
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd) - runtime lookup helper for the global scene-owned `WeatherManager`

## UI And Screen Flow

- [`../ui/`](../ui) - shell logic, screen scenes, UI styling, and title assets
- [`../ui/app_screen_router.gd`](../ui/app_screen_router.gd) - app-specific route stack and presentation rules; derives the active content/modal panels, gameplay context, pause state, backdrop, and HUD state
- [`../ui/screens/`](../ui/screens) - boot, title, HUD, journal, melody prompt, pause, settings, departure, credits, ending, and player setup screens

Put new menu, overlay, HUD, or shell-flow work here.

## World Integration And Shared State

- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn) / [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd) - production overworld integration: connects terrain, landmarks, residents, weather, audio, story subjects, and resume anchors to shared state (the 2D `game_main` overworld and its route/tunnel helpers have been removed)
- [`../game/world/actor_surface_follower.gd`](../game/world/actor_surface_follower.gd) - configured actor-surface component that owns physics-ray grounding, terrain fallback, and shallow-water seating without making `HumanBody3D` terrain-aware
- [`../game/world/world_action_coordinator_3d.gd`](../game/world/world_action_coordinator_3d.gd) - sole contextual input/hint arbiter across physical targets and story subjects, including cancellation/recovery precedence and semantic forwarding
- [`../game/world/character_action_target_3d.gd`](../game/world/character_action_target_3d.gd) / [`../game/world/ladder_3d.gd`](../game/world/ladder_3d.gd) - reusable physical target contract and current two-way authored ladder implementation
- [`../game/world/story_interaction_coordinator.gd`](../game/world/story_interaction_coordinator.gd) - story-subject discovery, request construction, and delegated `AppState.activate_story_subject(...)` dispatch
- [`../terrain/low_poly_terrain_3d.gd`](../terrain/low_poly_terrain_3d.gd) - production low-poly 3D terrain node that owns exports, lifecycle, image loading, materials, wind, style resolution, and public surface-height queries; it configures a `LowPolyTerrainSampler` and `LowPolyTerrainMeshBuilder` and wraps the built buffers in `MeshInstance3D`/collision children
- [`../terrain/low_poly_terrain_sampler.gd`](../terrain/low_poly_terrain_sampler.gd) - the "images -> cell grid" half of the low-poly 3D pipeline: samples the terrain mask/profile and optional full-source heightmap into a coarse `LowPolyTerrainCell` grid, including land/street/building classification, height smoothing, and heightmap waterline application
- [`../terrain/low_poly_terrain_mesh_builder.gd`](../terrain/low_poly_terrain_mesh_builder.gd) - the "cell grid -> meshes" half of the low-poly 3D pipeline: `build(...)` turns the cell grid into a `MeshBuildResult` of per-pass `MeshBuildState` buffers (land, shoreline, water body/surface-layer/shoreline, building) plus collision faces and cell counts, renders STREET-classified cells as supporting land because the street network owns visible roads, and owns the shared corner/surface-height math reused by the node's placement queries
- [`../terrain/low_poly_street_corridor_integrator.gd`](../terrain/low_poly_street_corridor_integrator.gd) - generic pre-mesh terrain modifier that consumes duck-typed single or multi-corridor street sources, lowers the supporting terrain bed under segment cross-sections and junction polygons, feathers the boundary, normalizes corridor-core cells to land, suppresses building overlays in the core, and skips water unless explicitly enabled
- [`../terrain/low_poly_street_path_extractor.gd`](../terrain/low_poly_street_path_extractor.gd) - deterministic STREET-cell thinning and graph tracer that converts sampled mask lines into simplified branch-to-branch multipoint paths through bends, junctions, and closed loops for one terrain-owned `StreetNetwork3D`
- [`../terrain/low_poly_terrain_cell.gd`](../terrain/low_poly_terrain_cell.gd) / [`../terrain/low_poly_image_pixel_reader.gd`](../terrain/low_poly_image_pixel_reader.gd) - shared low-poly terrain sample-cell type (with the `Kind` enum) and the cached RGBA8 pixel reader used by the sampler and node
- [`../terrain/low_poly_art_style_3d.gd`](../terrain/low_poly_art_style_3d.gd) / [`../terrain/low_poly_postcard_diorama_style.tres`](../terrain/low_poly_postcard_diorama_style.tres) - shared low-poly style preset schema plus the current Painted Postcard Diorama palette, water tuning, camera, sunlight, and landmark-color preset
- [`../terrain/low_poly_world_coordinates_3d.gd`](../terrain/low_poly_world_coordinates_3d.gd) - shared coordinate adapter for converting terrain mask pixels and rough 2D isometric authored positions to low-poly 3D XZ world positions
- [`../terrain/low_poly_water_wind_adapter.gd`](../terrain/low_poly_water_wind_adapter.gd) - integration adapter that normalizes published weather wind and drives the terrain water shader without coupling `LowPolyTerrain3D` to `WeatherManager`
- [`../terrain/island_generation_profile.tres`](../terrain/island_generation_profile.tres) - shared authored terrain profile resource referenced by `terrain.tscn` so direct terrain validation and the gameplay world use the same rules
- [`../terrain/terrain_generation_profile.gd`](../terrain/terrain_generation_profile.gd) / [`../terrain/terrain_mask_rule.gd`](../terrain/terrain_mask_rule.gd) - terrain mask legend, per-color semantics, and generated-layer paint defaults
- [`../game/app_state.gd`](../game/app_state.gd) - scene-owned snapshot store and atomic command finalizer; owns one canonical snapshot, one projection cache, persistence coordination, `state_committed`, and queued imperative events
- [`../game/app_state/`](../game/app_state) - typed snapshot/projection/transition/change-set models, the detached reducer context with shared immutable catalog caches and explicit helper cleanup, V1/V2 save codec, and configurable save repository
- [`../game/app_runtime.gd`](../game/app_runtime.gd) - scene-owned runtime lookup for `AppStateService` and the live `"player"` group member
- [`../game/story_event_catalog.gd`](../game/story_event_catalog.gd) - authored StoryEvent tree data file; owns the full `melody_landmarks` landmark-interaction subtree, A Po household arrival/care, and optional Bagua stewardship completion bindings
- [`../game/story_event_service.gd`](../game/story_event_service.gd) - detached generic StoryEvent reducer for `npc:`, `landmark:`, and `inspectable:` subjects, shared condition matching, candidate selection, and effect application
- [`../game/story_moment_ledger.gd`](../game/story_moment_ledger.gd) - explicit
  parent-owned policy for bounded completed-versus-missed moments; currently maps
  only the Winter household-care event to its exclusive terminal story facts
- [`../weather/weather_manager.gd`](../weather/weather_manager.gd) - global scene-owned weather service for overworld preset cycling, runtime weather-rig instancing, and synced wind application
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd) - runtime lookup helper for `WeatherManager`
- [`../game/player_profile_service.gd`](../game/player_profile_service.gd) - stateless player-profile normalization, costume-catalog lookup, and costume-selection transforms used by `AppState`
- [`../game/journal_builder.gd`](../game/journal_builder.gd) - pure journal/setup text builders used by the journal and player setup overlays
- [`../game/app_state/story_save_codec.gd`](../game/app_state/story_save_codec.gd) / [`../game/app_state/story_save_repository.gd`](../game/app_state/story_save_repository.gd) - pure V1/V2 payload migration/mapping plus injectable file I/O
- [`../game/story_time_service.gd`](../game/story_time_service.gd) - stateless story-time normalization, display, and advancement transforms; `AppState` owns and commits the resulting runtime clock state
- [`../game/story_effect_schema.gd`](../game/story_effect_schema.gd) - parent-owned schema and extraction boundary for StoryEvent condition/effect dictionaries; validates unknown keys, nested types, canonical ids, and recursive conditional effects before runtime mutation
- [`../game/storyline_validation_provider.gd`](../game/storyline_validation_provider.gd) - Kulangsu implementation of the addon's optional host-validation interface; exposes `StoryEffectSchema`/`StoryEventCatalog` warnings during storyline editing without creating an addon-to-parent dependency
- [`../game/story_season_phases.gd`](../game/story_season_phases.gd) - canonical season-phase ids, default progression phases, and player-facing phase labels shared by route resources, the route graph, and autosave/state helpers
- [`../game/audio_settings_service.gd`](../game/audio_settings_service.gd) - stateless settings normalization and audio-bus application; settings remain canonical snapshot state but stay outside story saves
- [`../game/resident_interaction_service.gd`](../game/resident_interaction_service.gd) - detached resident reducer for dialogue beats, conditional beats, trust milestones, route refresh, and autosave requests
- [`../game/story_route_graph.gd`](../game/story_route_graph.gd) - detached route calculator with an instance-local definition cache; derives route progress, lead selection, display-order-independent score gates, event availability, endgame triggers, and tone tags
- [`../game/storylines/`](../game/storylines) - authored storyline data: typed route resources under `routes/`, the `phase_set.tres` phase vocabulary, and the checked-in graph layout; add new `StorylineRouteResource` files under `routes/` instead of editing the central route graph. The schema classes and `StorylineCatalog` loader now live in the `addons/storyline_editor` submodule, located through the `storyline_editor/*` project settings.
- [`../game/story_world_reactivity.gd`](../game/story_world_reactivity.gd) - resolves route-aware non-resident inspection text for `inspectable:` world subjects authored as `StorySubject3D` nodes in the production world scene
- [`../game/landmarks/landmark_definition.gd`](../game/landmarks/landmark_definition.gd) / [`../game/landmarks/landmark_progress_profile.gd`](../game/landmarks/landmark_progress_profile.gd) - typed resource schemas for immutable landmark metadata and named initial-progress presets
- [`../game/landmarks/landmark_catalog.gd`](../game/landmarks/landmark_catalog.gd) / [`../game/landmarks/definitions/`](../game/landmarks/definitions) - ordered landmark registry and editor-authored definitions consumed by `AppState`, StoryEffect validation, and the production world
- [`../game/landmark_progression.gd`](../game/landmark_progression.gd) - owner-free melody-prompt/result calculator used by `AppState`; the authored StoryEvent tree owns the current melody-landmark interaction and completion spine
- [`../game/bgm_catalog.gd`](../game/bgm_catalog.gd) / [`../game/bgm_manager.gd`](../game/bgm_manager.gd) - seed-pool BGM definitions plus scene-owned weighted playback and transition logic for overworld music
- [`../game/melody_catalog.gd`](../game/melody_catalog.gd) - authored melody definitions, onboarding clue sources, fragment sources, and performance-point summaries
- [`../game/resident_catalog.gd`](../game/resident_catalog.gd) - resident roster ordering, external `.tres` definition loading, and helper builders consumed by the loading pipeline
- [`../game/resident_system/`](../game/resident_system) - resident definition resources for appearance, dialogue, routine, and behavior metadata
- [`../game/residents/`](../game/residents) - all 25 editor-authored resident `.tres` definitions under `definitions/`, templates, and the short designer workflow note
- [`../game/player_appearance_catalog.gd`](../game/player_appearance_catalog.gd) / [`../game/player_costume_catalog.gd`](../game/player_costume_catalog.gd) - player customization data
If several screens or systems need the same player-facing state, it probably belongs in `game/app_state.gd`.
If you are changing how terrain mask colors map to generated surfaces, start with the terrain profile and rule scripts before editing `low_poly_terrain_3d.gd`.

## Characters And Interaction

- [`../characters/`](../characters) - low-poly 3D actor, resident presentation, controller, model-selection, and UI-preview systems
- [`../characters/human_body_3d.gd`](../characters/human_body_3d.gd) / [`../characters/human_body_3d.tscn`](../characters/human_body_3d.tscn) - runtime low-poly 3D actor with one intent-driven physics step, typed locomotion/action state, physical jump, ladder and sustained object-action adapters, safe recovery, integrated GLB presentation, native collision, and capped dynamic-body pushing
- [`../characters/actions/`](../characters/actions) - story-free sustained action lifecycle and validated/generated ladder, carry, push/pull, and sit animation fallback profile
- [`../assets/characters/`](../assets/characters) - premade skinned, textured low-poly character models; `idle`/`walk`/`run` are the current validated baseline clips, optional imported clips such as `dance`, `scared`, or `wave_goodbye` must be validated before gameplay use, and `male.glb` is the default `HumanBody3D` visual with `boy.glb` and `female.glb` as interchangeable alternates
- [`../characters/character_model_catalog_3d.gd`](../characters/character_model_catalog_3d.gd) - canonical mapping from saved player profiles and resident definitions to integrated GLB models
- [`../characters/character_preview_3d.gd`](../characters/character_preview_3d.gd) - transparent SubViewport-friendly low-poly actor preview used by customization and journal screens
- [`../characters/tests/`](../characters/tests) - direct `HumanBody3D` smoke scenes and generated-fixture 3D collision, traversal, carry, push/pull, and sit behavior
- [`../characters/control/`](../characters/control) - controllers, resident presentation hookup, and interaction behavior
- [`../characters/control/base_controller_3d.gd`](../characters/control/base_controller_3d.gd) - shared 3D controller base for `HumanBody3D` lifecycle, movement flags, and movement helper methods
- [`../characters/control/player_controller_3d.gd`](../characters/control/player_controller_3d.gd) - first playable 3D input adapter for `HumanBody3D`, using the existing input map on the XZ plane
- [`../characters/control/resident_controller_3d.gd`](../characters/control/resident_controller_3d.gd) - lightweight 3D resident wander controller (stroll to a nearby point, pause, repeat, with a stuck-timeout) plus `pause_for` so a talked-to resident holds still while facing the player
- [`../characters/resident_factory.gd`](../characters/resident_factory.gd) - spawns `HumanBody3D` residents from shared `AppState` resident data at their landmark anchors, each with an `npc:` talk `StorySubject3D`, a wander controller, and a world-anchored 3D speech balloon; used by `game_world_3d`
- [`../common/gui/`](../common/gui) - in-world UI such as speech balloons; [`../common/gui/speech_balloon_3d.gd`](../common/gui/speech_balloon_3d.gd) is the billboarded, camera-facing `Label3D` dialogue balloon used by the 3D overworld
- [`../game/story_subject_3d.gd`](../game/story_subject_3d.gd) - production `Area3D` world-subject adapter: exposes a stable `subject_id`, resolves action/display/presence from StoryEvent state, competes in `WorldActionCoordinator3D`, and is dispatched through `StoryInteractionCoordinator`

Put player control, resident movement, model presentation, and interaction prompts here.

## Landmark And World Content

- [`../architecture/`](../architecture) - editable low-poly 3D landmark scenes and their reproducible generators; the production proxy nodes and interaction hotspots are owned by `game_world_3d.tscn`
- [`../game/landmarks/`](../game/landmarks) - typed static landmark metadata, including the proxy-node mapping and authored placement coordinates resolved by `game_world_3d.gd`
- [`../architecture/bagua_tower/bagua_tower_stylized_3d.tscn`](../architecture/bagua_tower/bagua_tower_stylized_3d.tscn) / [`../architecture/bagua_tower/generate_stylized_3d.gd`](../architecture/bagua_tower/generate_stylized_3d.gd) - production Bagua Tower model and its reproducible Low-Poly Building Editor API generator
- [`../architecture/piano_ferry/piano_ferry_stylized_3d.tscn`](../architecture/piano_ferry/piano_ferry_stylized_3d.tscn) / [`../architecture/piano_ferry/generate_stylized_3d.gd`](../architecture/piano_ferry/generate_stylized_3d.gd) / [`../architecture/piano_ferry/piano_ferry_building_spec.json`](../architecture/piano_ferry/piano_ferry_building_spec.json) - production Piano Ferry model, generator, versioned deterministic base spec, and instanced music-case carry and harbor-bench sit proofs
- [`../architecture/trinity_church/trinity_church_stylized_3d.tscn`](../architecture/trinity_church/trinity_church_stylized_3d.tscn) - production Trinity Church model with the instanced constrained hymn-chest push/pull proof
- [`../architecture/apo_household/apo_household_courtyard_3d.tscn`](../architecture/apo_household/apo_household_courtyard_3d.tscn) / [`../architecture/apo_household/apo_household_courtyard_3d.gd`](../architecture/apo_household/apo_household_courtyard_3d.gd) - parent-owned ferry-district household/courtyard scene with semantic arrival/care/reflect subjects and saved cared-for versus untended presentation
- [`../architecture/bagua_tower/tests/`](../architecture/bagua_tower/tests) - Bagua Tower-specific validation scenes and scripts
- [`../common/`](../common) - shared runtime helpers and common world-facing UI primitives

### Landmark Quest Triggers

- [`../game/story_subject_3d.gd`](../game/story_subject_3d.gd) - place `StorySubject3D` hotspots under the owning landmark proxy in `game_world_3d.tscn`, assign a catalog-backed stable `subject_id`, and leave visibility/action resolution to the shared StoryEvent service

Put new landmark models and reproducible generators under `architecture/`; add static identity/placement/audio/default-progress metadata under `game/landmarks/`; author the proxy node, collision source, and story hotspots in `game_world_3d.tscn`.

## Reusable Gameplay Modules

- [`../game/grid_board_game/`](../game/grid_board_game) - reusable, intentionally 2D board-game module and local test scenes; isolated from the production overworld
- [`../game/marble_game/`](../game/marble_game) - self-contained native low-poly 3D marble-game prototype, including `RigidBody3D` actors, board physics, camera-ray input, and a focused smoke test; no tilemap dependency
- [`../game/piano_game/`](../game/piano_game) - intentionally 2D piano mini-game prototype; isolated from the production overworld
- [`../game/tests/npc_system/`](../game/tests/npc_system) - NPC/resident validation scenes and companion test assets

If a feature is self-contained and reusable, extend its module folder instead of scattering logic across unrelated directories.

## Addons And Editor Plugins

- [`../addons/low_poly_building_editor/`](../addons/low_poly_building_editor) - submodule containing the native editor dock and 3D viewport tool for low-poly building authoring, including `StreetNetwork3D` junction/segment/profile authoring, adaptive road curves/grades, asymmetric cross-sections, dedicated multi-road junction geometry, direct placement/edit operations, legacy `Street3D` compatibility, and versioned building/street JSON-to-scene generation. See the plugin's own [`README.md`](../addons/low_poly_building_editor/README.md), [`docs/feature.md`](../addons/low_poly_building_editor/docs/feature.md), and [`docs/contract.md`](../addons/low_poly_building_editor/docs/contract.md).
- [`../addons/mp3_to_ogg/`](../addons/mp3_to_ogg) - submodule containing the editor dock plugin that batch-converts MP3 files to OGG Vorbis via ffmpeg. See the plugin's own docs: [`../addons/mp3_to_ogg/README.md`](../addons/mp3_to_ogg/README.md).
- [`../addons/storyline_editor/`](../addons/storyline_editor) - submodule containing the editor plugin that visualizes and edits storyline event dependencies (route browser, graph, and validation/inspector bridge) over parent-owned canonical route resources. Its optional `StorylineHostValidationProvider` lets the parent add live semantic warnings while the addon stays standalone. See the plugin's own docs: [`../addons/storyline_editor/README.md`](../addons/storyline_editor/README.md), [`../addons/storyline_editor/docs/feature.md`](../addons/storyline_editor/docs/feature.md), and [`../addons/storyline_editor/docs/contract.md`](../addons/storyline_editor/docs/contract.md).
- [`../addons/asset_browser/`](../addons/asset_browser) - Blender-style asset browser panel for dragging `.tscn` files into the viewport. See the plugin's own docs: [`../addons/asset_browser/README.md`](../addons/asset_browser/README.md).
- [`../addons/asset_placer/`](../addons/asset_placer) - third-party (vendored) 3D asset placement/management addon. See the plugin's own docs: [`../addons/asset_placer/README.md`](../addons/asset_placer/README.md).
  - **Inspector plugin** — adds a validation-warning panel to the Inspector that auto-refreshes when route or event edits change validation status, listens to normal inspector property edits so warning/status surfaces stay current, replaces raw `phase_window` editing on `StorylineEventResource` objects with an inline Phase Window panel that stays in the normal property order beside `season_phase`, only offers unselected season phases, and disables `Add Element` once every authorable phase is already chosen, replaces raw `story_flags_all` / `story_flags_any` string-array editing on `StorylineEventResource` objects with a route-rooted prerequisite picker that mirrors the storyline browser and now keeps those `All` / `Any` dependencies in sync with the graph and browser after edits from either surface, and replaces raw `events` array editing on `StorylineRouteResource` objects with a Route Events panel whose Add Event action creates a unique default id like `<route_name>_new_event_1`, whose Remove action confirms before deleting an event, and which refreshes the storyline browser immediately.
- [`../addons/storyline_editor/resources/`](../addons/storyline_editor/resources) - Typed GDScript Resource classes for the storyline schema (addon-owned): `StorylineEndingToneRule`, `StorylineEventResource`, `StorylineRouteResource`, `StorylinePhaseSet`. Each class has `@export` fields covering all runtime dict keys plus a `validate()` method; phase validation reads the parent-authored `phase_set.tres`.
- [`../game/storylines/phase_set.tres`](../game/storylines/phase_set.tres) - Authored `StorylinePhaseSet` phase vocabulary consumed by the storyline editor addon; must stay in sync with `StorySeasonPhases` (guarded by `test_storyline_resources`).
- [`../game/storylines/storyline_graph_layout.cfg`](../game/storylines/storyline_graph_layout.cfg) - Checked-in graph-node positions for the Storyline Graph editor. The editor updates this file when authors manually arrange story event nodes so layout changes can be reviewed and committed alongside route edits.
- [`../game/storylines/routes/`](../game/storylines/routes) - Drop `.tres` files of type `StorylineRouteResource` here. `StorylineCatalog` loads these as the canonical source, runtime `StoryRouteGraph` instances cache the loaded route/event bundle, and editor panels rebuild directly from those resources during authoring refreshes.

## Shared Utilities And Assets

- [`../godot_common/`](../godot_common) - support utilities reused across scenes
- [`../resources/`](../resources) - materials, sprites, audio, and animations

Be careful about renames or moves here because scene and resource references can break easily.

## Validation Scenes

- [`../scenes/`](../scenes) - runtime gameplay scenes such as `game_world_3d`
- [`../scenes/tests/`](../scenes/tests) - ad hoc prototype and validation scenes
- [`../weather/tests/`](../weather/tests) - dedicated 3D weather validation and capture scenes
- [`../ui/screens/tests/test_app_screen_router.tscn`](../ui/screens/tests/test_app_screen_router.tscn) - focused route-stack regression covering frontend/gameplay context inheritance, nested back behavior, credits/ending return, and confirm-modal restoration
- [`../ui/screens/tests/test_app_shell_navigation.tscn`](../ui/screens/tests/test_app_shell_navigation.tscn) - shell integration regression proving that route rendering alone controls title/settings/confirm panels, HUD, backdrop, world visibility, and pause state
- [`../characters/tests/test_human_body_3d.tscn`](../characters/tests/test_human_body_3d.tscn) - direct `HumanBody3D` adapter smoke scene covering configuration, flat direction, movement velocity, current-frame controller input, jump state and takeoff velocity, ground footprint behavior, and character-model structure (instanced model, mesh, material, animation clips)
- [`../characters/tests/test_character_action_state_3d.tscn`](../characters/tests/test_character_action_state_3d.tscn) - typed mode, contextual arbitration/gates, cancel/recovery/cleanup, and Story/Free Walk semantic regression
- [`../characters/tests/test_character_traversal_3d.tscn`](../characters/tests/test_character_traversal_3d.tscn) - executable physical jump, ceiling, recovery, ladder, endpoint, and blocked-retreat regression
- [`../characters/tests/test_character_object_actions_3d.tscn`](../characters/tests/test_character_object_actions_3d.tscn) - typed carry, doorway, placement, reset, and Piano Ferry authored-scene regression
- [`../characters/tests/test_character_push_pull_3d.tscn`](../characters/tests/test_character_push_pull_3d.tscn) - constrained push/pull alignment, speed, blockage, bounds, reset, goal, and Trinity authored-scene regression
- [`../characters/tests/test_character_sit_3d.tscn`](../characters/tests/test_character_sit_3d.tscn) - seat entry, occupancy, camera, listening, exit fallback, cleanup, and Piano Ferry authored-scene regression
- [`../game/tests/persistence/test_milestone_c_object_care_continue_fixtures.tscn`](../game/tests/persistence/test_milestone_c_object_care_continue_fixtures.tscn) - fixed ferry/church Continue, exact object-care facts, idempotency, journal, autosave/reload, and Free Walk regression
- [`../game/tests/persistence/test_bagua_ascent_continue_fixture.tscn`](../game/tests/persistence/test_bagua_ascent_continue_fixture.tscn) - fixed pre-ascent Continue, optional-fact persistence, journal/view response, route-score isolation, and Free Walk regression
- [`../common/gui/tests/test_speech_balloon_3d.tscn`](../common/gui/tests/test_speech_balloon_3d.tscn) - focused world-space resident-dialogue regression covering readable horizontal wrapping for long story lines
- [`../game/tests/npc_system/test_resident_interaction.tscn`](../game/tests/npc_system/test_resident_interaction.tscn) - focused resident progression regression covering gate fallbacks, trust-max milestones, and a resident-driven autosave/continue path
- [`../game/tests/npc_system/test_resident_catalog_external_defs.tscn`](../game/tests/npc_system/test_resident_catalog_external_defs.tscn) - focused resident catalog regression covering external `.tres` definition loading, roster completeness, and field-level validation
- [`../game/tests/cue_progression/test_cue_progression.tscn`](../game/tests/cue_progression/test_cue_progression.tscn) - focused Ferry -> Trinity choir chime -> Bi Shan chamber prompt -> Long Shan exit prompt -> Bagua -> harbor-stage progression regression covering fragment awards, dependable-route notes, Bagua gating, and the spring guardrail on harbor-triggered endgame
- [`../game/tests/bgm/test_bgm_manager.tscn`](../game/tests/bgm/test_bgm_manager.tscn) - focused BGM regression scene covering lazy catalog validation, natural-end fade scheduling, and location-fallback variety rules
- [`../game/tests/persistence/test_story_autosave.tscn`](../game/tests/persistence/test_story_autosave.tscn) - focused story autosave regression covering first-save creation, real `Continue`, safe resume anchors, guarded harbor-performance persistence, soft-ending continuation restore, and departure-save clearing
- [`../game/tests/persistence/test_story_state_persistence.tscn`](../game/tests/persistence/test_story_state_persistence.tscn) - focused persistence regression covering unknown `story_flags` plus save/load restoration for override-backed resident profiles
- [`../game/tests/story_routes/test_story_routes.tscn`](../game/tests/story_routes/test_story_routes.tscn) - focused seasonal-route regression covering concurrent route seeds, manual lead pinning persistence, non-landmark seasonal progression, guarded endgame activation, and final-act save/restore
- [`../game/tests/story_routes/test_story_reactivity.tscn`](../game/tests/story_routes/test_story_reactivity.tscn) - focused cross-route resident reactivity regression covering winter-memory, Spring Festival aftermath, future-choice, second-summer, and preservation-perspective follow-through
- [`../game/tests/story_routes/test_story_event_service.tscn`](../game/tests/story_routes/test_story_event_service.tscn) - focused StoryEvent bridge regression covering strict condition/effect schema validation, resident-beat effect extraction, subject-based resident talk, landmark-trigger activation, inspectable resolution, and resident routine overrides at the shared-state level
- [`../game/tests/state/test_app_state_ownership.tscn`](../game/tests/state/test_app_state_ownership.tscn) - focused single-owner regression covering player profile/costumes, detached profile reads, story-time snapshot commits, and audio/text-speed settings signals
- [`../game/tests/state/test_app_state_snapshot_store.tscn`](../game/tests/state/test_app_state_snapshot_store.tscn) - atomic snapshot/persistence/migration regression with hot-path budgets for unchanged world context and detached subject descriptions
- [`../characters/tests/test_character_collisions.tscn`](../characters/tests/test_character_collisions.tscn) - self-contained generated-fixture regression covering `HumanBody3D` gravity/landing, static-wall blocking, native stair-slope ascent/descent and side blocking, and capped `RigidBody3D` pushing
- [`../game/tests/landmarks/test_landmark_catalog.tscn`](../game/tests/landmarks/test_landmark_catalog.tscn) - typed landmark catalog contract covering identity/order, world navigation names, resume fallback, initial progress profiles, deep-copy behavior, and audio resources
- [`../scenes/tests/test_landmark_cue_loading.tscn`](../scenes/tests/test_landmark_cue_loading.tscn) - focused landmark catalog audio-resource smoke test
- [`../scenes/tests/test_low_poly_building_editor_3d.tscn`](../scenes/tests/test_low_poly_building_editor_3d.tscn) - end-to-end building-editor smoke suite relocated from the `addons/low_poly_building_editor` submodule so the addon carries no parent-repo paths; probes generated buildings with `HumanBody3D` collision and covers the full wall/floor/stairs/rail/pillar/roof/opening regression matrix described in the addon's `docs/feature.md`
- [`../scenes/tests/test_environment_3d.tscn`](../scenes/tests/test_environment_3d.tscn) - compact character-environment interaction harness with an exported `building_scene`, transform and player spawn, plus `HumanBody3D` driven by `PlayerController3D`, camera-relative movement, a level orbit/zoom camera that does not follow jump height, lighting, and ground collision; defaults to the generated low-poly Bagua Tower concept and places the playable Milestone C carry, sit, and push/pull fixtures on a clear southern test strip, with smoke assertions for contextual-action registration, visibility above ground, building clearance, and fixture spacing
- [`../weather/tests/capture_weather_3d.tscn`](../weather/tests/capture_weather_3d.tscn) - focused steady-rain validation/capture scene for the production 3D weather rig
- [`../scenes/tests/test_camera_3d_occlusion.tscn`](../scenes/tests/test_camera_3d_occlusion.tscn) - focused `Camera3DController` regression covering multiple blockers, target exclusion, prior-transparency preservation, sightline restoration, disable cleanup, and inactive-camera cleanup
- [`../scenes/tests/test_low_poly_terrain_3d.tscn`](../scenes/tests/test_low_poly_terrain_3d.tscn) - focused 3D terrain scene covering heightmap and mask-clipped generation, layered water, wind control, and coordinate round-trips
- [`../scenes/tests/test_street_terrain_integration.tscn`](../scenes/tests/test_street_terrain_integration.tscn) - focused terrain-generation/Street3D integration regression covering automatic source discovery, base-grid profile baking, corridor bed shaping/feathering, manual-height preservation, street mesh/collision retention, and street-triggered terrain regeneration
- [`../scenes/tests/test_street_mask_generation.tscn`](../scenes/tests/test_street_mask_generation.tscn) - focused STREET-mask regression covering centerline extraction into one deterministic network, stable graph IDs, bent paths, dedicated junction geometry, segment/junction terrain shaping, replacement/reuse, and a real-island rebuild with visible segment meshes and coherent stairs
- [`../scenes/tests/test_game_world_3d.tscn`](../scenes/tests/test_game_world_3d.tscn) - production-world smoke covering terrain/water/street generation, actor/controller grounding and wading, camera wiring/orbit, authored-landmark placement/collision, residents, actionable resident/landmark proximity priority, scene-local story interaction, cross-world subject isolation, audio, weather-to-water integration, and semantic resume anchors
- [`../game/grid_board_game/test_grid_board_game.tscn`](../game/grid_board_game/test_grid_board_game.tscn)
- [`../game/grid_board_game/test_terminal_turn_state.tscn`](../game/grid_board_game/test_terminal_turn_state.tscn)

Use these when you need a focused validation target instead of the full project flow.

## Documentation And Agent Support

- [`../agent_tools/scripts/source_control_report.py`](../agent_tools/scripts/source_control_report.py) - shared read-only source-control inspection helper
- [`../agent_tools/scripts/source_control_ops.py`](../agent_tools/scripts/source_control_ops.py) - shared compact helper for explicit stage, commit, push, publish, and update-latest workflows
- [`../scripts/token_efficiency_workflows.json`](../scripts/token_efficiency_workflows.json) - local workflow baselines and review cadence for token-efficiency audits
- [`../agent_tools/scripts/token_efficiency_audit.py`](../agent_tools/scripts/token_efficiency_audit.py) - shared helper ROI audit script used with the local workflow config
- [`../docs/`](../docs) - project docs
- [`plan/README.md`](plan/README.md) - planning-doc index for the current status and active plan
- [`plan/implementation_plan.md`](plan/implementation_plan.md) - canonical implementation plan for the current seasonal multi-route playable game
- [`features/multi_level_spaces.md`](features/multi_level_spaces.md) - implementation-facing guide for stacked rooms, parent-owned level mapping, portals, stairs, and current design gaps
- [`features/core_melody_loop.md`](features/core_melody_loop.md) - implementation-facing summary of the current melody-driven gameplay loop, gap list, MVP build order, reusable manual playtest route, and manual ending smoke pass
- [`features/household_care_story_moment.md`](features/household_care_story_moment.md) - implementation-facing contract for the first bounded completed-versus-missed route moment, its A Po courtyard scene, saved outcome projection, and validation
- [`story/summer_of_piano_island_story_framework.md`](story/summer_of_piano_island_story_framework.md) - single source of truth for the current story, protagonist background, seasonal frame, route meanings, and ending tone
- [`features/bgm_system.md`](features/bgm_system.md) - BGM pool design, V1 controller scope, selection rules, fallback order, and variant policy
- [`features/bgm_tagging_guide.md`](features/bgm_tagging_guide.md) - track-weight authoring rules for the future `bgm_catalog.gd`
- [`bgm_suno_guide.md`](bgm_suno_guide.md) - Suno-focused content-generation guide for the 7-track BGM seed pool and later expansion
- [`piano_game_design.md`](piano_game_design.md) - current piano prototype status plus integration rules for short story-facing performance beats
- [`features/piano_game_integration.md`](features/piano_game_integration.md) - canonical decision and future contract for connecting the standalone piano prototype to the main game
- [`features/piano_ferry.md`](features/piano_ferry.md) - implementation-facing summary of the ferry onboarding arc and journal unlock handoff
- [`features/landmark_definitions.md`](features/landmark_definitions.md) - static landmark-definition ownership, extension workflow, runtime boundaries, and validation
- [`features/npc_system.md`](features/npc_system.md) - implementation-facing summary of the resident/NPC system
- [`features/terrain_system.md`](features/terrain_system.md) - terrain generation ownership, mask-rule workflow, and extension guide
- [`features/low_poly_terrain_3d.md`](features/low_poly_terrain_3d.md) - current low-poly 3D terrain prototype scope, ownership, and validation notes
- [`features/low_poly_actor_3d.md`](features/low_poly_actor_3d.md) - canonical current 3D actor plus planned character-action ownership, input/physics contract, delivery stages, validation, and future capability gates
- [`features/low_poly_3d_integration.md`](features/low_poly_3d_integration.md) - planned one-landmark interaction, story/resident/save ownership, evidence gates, and runtime-direction decision contract for the 3D sidecar
- [`features/weather_rendering.md`](features/weather_rendering.md) - current 3D weather-system design, ownership, extension guide, and validation notes
- [`features/terrain_water_rendering.md`](features/terrain_water_rendering.md) - terrain water rendering and validation notes
- [`features/`](features) - feature specs
- [`features/template.md`](features/template.md) - local feature-spec template
- [`../agent_tools/`](../agent_tools) - shared generic agent runbooks and support docs
- [`../agent_tools/README.md`](../agent_tools/README.md) / [`../agent_tools/AGENTS.md`](../agent_tools/AGENTS.md) - submodule doc entry points when a task depends on shared runbooks or agent behavior

## Submodules

- [`../godot_common/`](../godot_common) - shared Godot support code, tracked as a submodule
- [`../agent_tools/`](../agent_tools) - shared agent docs and runbooks, tracked as a submodule
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator) - third-party LPC asset generator, tracked as a submodule
- [`../addons/mp3_to_ogg/`](../addons/mp3_to_ogg) - reusable MP3 conversion editor addon, tracked as a submodule
- [`../addons/low_poly_building_editor/`](../addons/low_poly_building_editor) - reusable low-poly building and street editor addon, tracked as a submodule
- [`../addons/storyline_editor/`](../addons/storyline_editor) - reusable storyline route/dependency editor addon, tracked as a submodule

Submodule doc entry points:

- [`../godot_common/AGENTS.md`](../godot_common/AGENTS.md)
- [`../godot_common/README.md`](../godot_common/README.md)
- [`../godot_common/docs/architecture.md`](../godot_common/docs/architecture.md)
- [`../agent_tools/README.md`](../agent_tools/README.md)
- [`../agent_tools/AGENTS.md`](../agent_tools/AGENTS.md)
- [`../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md`](../3rdparty/Universal-LPC-Spritesheet-Character-Generator/README.md)
- [`../addons/mp3_to_ogg/README.md`](../addons/mp3_to_ogg/README.md)
- [`../addons/low_poly_building_editor/README.md`](../addons/low_poly_building_editor/README.md)
- [`../addons/low_poly_building_editor/docs/contract.md`](../addons/low_poly_building_editor/docs/contract.md)
- [`../addons/storyline_editor/README.md`](../addons/storyline_editor/README.md)
- [`../addons/storyline_editor/docs/contract.md`](../addons/storyline_editor/docs/contract.md)

See [`submodules.md`](submodules.md) for edit rules, update rules, and a parent-repo index of submodule documentation.

## Search Tips

Useful searches when locating code:

- `ScreenState` for app shell transitions
- `AppState` for shared UI-facing state
- `inspect_requested` for inspect flow
- `set_location` for location syncing
- `resident` for resident systems and data
- `WeatherManager` for the overworld's global weather-cycle and wind-sync service
- `WeatherRig3D` for the production rain/fog/cloud presentation target
- `water_tint` for the water shader and material
- `LowPolyTerrain3D` for production terrain-mask/heightmap-to-3D generation, including optional full-heightmap source expansion, heightmap elevation sampling, water-level classification, continuous visible seabed generation, and smooth low-poly land-surface generation
- `LowPolyArtStyle3D` for low-poly 3D palette, camera, lighting, and landmark-color presets
- `LowPolyWorldCoordinates3D` for terrain-mask-pixel and rough 2D isometric-position to low-poly 3D world-position conversion
- `HumanBody3D` for the runtime low-poly 3D actor that renders one integrated premade GLB character model with idle/walk/run animation and no procedural body or separate clothing/hair attachment layer
- `BaseController3D` for the shared 3D controller base
- `PlayerController3D` for the runtime 3D player-input adapter
- `source_control_report` for the repo-local and shared Git inspection helpers
- `source_control_ops` for the repo-local and shared Git mutation helpers
- `token_efficiency` for helper ROI and audit cadence review
- `class_name GridBoardGame` for the board-game module
- `class_name UIStyle` for shared UI styling

## Update This Doc When

- a new module or top-level folder is introduced
- ownership of a directory or entry point changes
- a new feature should live somewhere that is not obvious from this map
- the submodule list or their effective role in the repo changes
