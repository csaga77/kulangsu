# Kulangsu Module Map

Read [`design_brief.md`](design_brief.md) and [`architecture.md`](architecture.md) first. Use this file to find where a feature probably belongs before you edit.

## Entry Points

- [`../project.godot`](../project.godot) - Godot project configuration, input map, and main scene
- [`../main.tscn`](../main.tscn) / [`../main.gd`](../main.gd) - app startup, route rendering, and screen-action wiring
- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn) / [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd) - production low-poly 3D overworld: builds `LowPolyTerrain3D`, `HumanBody3D`, an orthographic camera, five landmark anchors (three stylized building instances plus tunnel markers), maps the shared player profile to male/female/boy GLBs, spawns the shared wandering resident roster, owns 3D `StorySubject3D` interaction dispatch, shared BGM/landmark-cue audio, generated landmark collision, and location/landmark/resume syncing into `AppState`
- [`../scenes/tests/capture_game_world_3d_qa.tscn`](../scenes/tests/capture_game_world_3d_qa.tscn) - graphical Metal QA runner that produces the five fixed-camera acceptance PNGs plus a raw 5-second-warm-up/60-second performance report, cold-terrain timing, and resident/per-landmark visibility variants under `design/qa/low_poly_3d/`
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
- [`../terrain/low_poly_terrain_3d.gd`](../terrain/low_poly_terrain_3d.gd) - production low-poly 3D terrain node that owns exports, lifecycle, image loading, materials, wind, style resolution, and public surface-height queries; it configures a `LowPolyTerrainSampler` and `LowPolyTerrainMeshBuilder` and wraps the built buffers in `MeshInstance3D`/collision children
- [`../terrain/low_poly_terrain_sampler.gd`](../terrain/low_poly_terrain_sampler.gd) - the "images -> cell grid" half of the low-poly 3D pipeline: samples the terrain mask/profile and optional full-source heightmap into a coarse `LowPolyTerrainCell` grid, including land/street/building classification, height smoothing, and heightmap waterline application
- [`../terrain/low_poly_terrain_mesh_builder.gd`](../terrain/low_poly_terrain_mesh_builder.gd) - the "cell grid -> meshes" half of the low-poly 3D pipeline: `build(...)` turns the cell grid into a `MeshBuildResult` of per-pass `MeshBuildState` buffers (land, shoreline, water body/surface-layer/shoreline, building) plus collision faces and cell counts, renders STREET-classified cells as supporting land because Street3D owns visible roads, and owns the shared corner/surface-height math reused by the node's placement queries
- [`../terrain/low_poly_street_corridor_integrator.gd`](../terrain/low_poly_street_corridor_integrator.gd) - generic pre-mesh terrain modifier that consumes duck-typed Street3D world corridors, lowers the supporting terrain bed under their full cross-section, feathers the boundary, normalizes corridor-core cells to land, suppresses building overlays in the core, and skips water unless explicitly enabled
- [`../terrain/low_poly_street_path_extractor.gd`](../terrain/low_poly_street_path_extractor.gd) - deterministic STREET-cell thinning and graph tracer that converts sampled mask lines into simplified branch-to-branch multipoint paths through bends, junctions, and closed loops for terrain-owned transient Street3D generation
- [`../terrain/low_poly_terrain_cell.gd`](../terrain/low_poly_terrain_cell.gd) / [`../terrain/low_poly_image_pixel_reader.gd`](../terrain/low_poly_image_pixel_reader.gd) - shared low-poly terrain sample-cell type (with the `Kind` enum) and the cached RGBA8 pixel reader used by the sampler and node
- [`../terrain/low_poly_art_style_3d.gd`](../terrain/low_poly_art_style_3d.gd) / [`../terrain/low_poly_postcard_diorama_style.tres`](../terrain/low_poly_postcard_diorama_style.tres) - shared low-poly style preset schema plus the current Painted Postcard Diorama palette, water tuning, camera, sunlight, and landmark-color preset
- [`../terrain/low_poly_world_coordinates_3d.gd`](../terrain/low_poly_world_coordinates_3d.gd) - shared coordinate adapter for converting terrain mask pixels and rough 2D isometric authored positions to low-poly 3D XZ world positions
- [`../terrain/low_poly_water_wind_adapter.gd`](../terrain/low_poly_water_wind_adapter.gd) - integration adapter that normalizes published weather wind and drives the terrain water shader without coupling `LowPolyTerrain3D` to `WeatherManager`
- [`../terrain/island_generation_profile.tres`](../terrain/island_generation_profile.tres) - shared authored terrain profile resource referenced by `terrain.tscn` so direct terrain validation and the gameplay world use the same rules
- [`../terrain/terrain_generation_profile.gd`](../terrain/terrain_generation_profile.gd) / [`../terrain/terrain_mask_rule.gd`](../terrain/terrain_mask_rule.gd) - terrain mask legend, per-color semantics, and generated-layer paint defaults
- [`../game/app_state.gd`](../game/app_state.gd) - shared UI/progression-facing state plus the compatibility shell that composes profile, journal, autosave, landmark, and StoryEvent helpers
- [`../game/app_runtime.gd`](../game/app_runtime.gd) - scene-owned runtime lookup for `AppStateService` and the live `"player"` group member
- [`../game/story_event_catalog.gd`](../game/story_event_catalog.gd) - authored StoryEvent tree data file; currently owns the full `melody_landmarks` landmark-interaction subtree, including ferry, Trinity, Bi Shan, Long Shan, Bagua, and harbor-stage trigger bindings
- [`../game/story_event_service.gd`](../game/story_event_service.gd) - first-pass generic StoryEvent bridge for subject-based interactions, including `npc:`, `landmark:`, and `inspectable:` subjects, plus shared condition matching, candidate selection, and shared effect application
- [`../weather/weather_manager.gd`](../weather/weather_manager.gd) - global scene-owned weather service for overworld preset cycling, runtime weather-rig instancing, and synced wind application
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd) - runtime lookup helper for `WeatherManager`
- [`../game/player_profile_service.gd`](../game/player_profile_service.gd) - owns player appearance/profile and unlocked/equipped costume state while preserving `AppState`'s public API
- [`../game/journal_builder.gd`](../game/journal_builder.gd) - pure journal/setup text builders used by the journal and player setup overlays
- [`../game/story_save_service.gd`](../game/story_save_service.gd) - versioned story autosave read/write logic and save metadata refresh
- [`../game/story_time_service.gd`](../game/story_time_service.gd) - lightweight story-time helper for `story_day`, `world_hour`, derived `time_of_day`, and authored time advancement
- [`../game/story_effect_schema.gd`](../game/story_effect_schema.gd) - parent-owned schema and extraction boundary for StoryEvent condition/effect dictionaries; validates unknown keys, nested types, canonical ids, and recursive conditional effects before runtime mutation
- [`../game/storyline_validation_provider.gd`](../game/storyline_validation_provider.gd) - Kulangsu implementation of the addon's optional host-validation interface; exposes `StoryEffectSchema`/`StoryEventCatalog` warnings during storyline editing without creating an addon-to-parent dependency
- [`../game/story_season_phases.gd`](../game/story_season_phases.gd) - canonical season-phase ids, default progression phases, and player-facing phase labels shared by route resources, the route graph, and autosave/state helpers
- [`../game/audio_settings_service.gd`](../game/audio_settings_service.gd) - owns runtime volume/text-speed state while `AppState` keeps the shell-facing API and signals
- [`../game/resident_interaction_service.gd`](../game/resident_interaction_service.gd) - applies resident dialogue beats, conditional beats, trust milestones, route refresh, and resident-facing autosave side effects behind `AppState` facades
- [`../game/story_route_graph.gd`](../game/story_route_graph.gd) - keeps an instance-local runtime cache of modular storyline definitions, then projects them into route progress, lead selection, display-order-independent route-score gates, canonical story-event availability/blocker checks, endgame trigger logic, and tone-tag assembly
- [`../game/storylines/`](../game/storylines) - authored storyline data: typed route resources under `routes/`, the `phase_set.tres` phase vocabulary, and the checked-in graph layout; add new `StorylineRouteResource` files under `routes/` instead of editing the central route graph. The schema classes and `StorylineCatalog` loader now live in the `addons/storyline_editor` submodule, located through the `storyline_editor/*` project settings.
- [`../game/story_world_reactivity.gd`](../game/story_world_reactivity.gd) - resolves route-aware non-resident inspection text for `inspectable:` world subjects authored as `StorySubject3D` nodes in the production world scene
- [`../game/landmark_progression.gd`](../game/landmark_progression.gd) - shared melody-prompt builder plus compatibility/fallback landmark helpers kept behind the `AppState` bridge while the authored StoryEvent tree owns the current melody-landmark interaction and completion spine
- [`../game/landmark_cue_loader.gd`](../game/landmark_cue_loader.gd) - shared one-shot landmark cue loader/cache that decodes shipped Vorbis `.ogg` cues directly instead of relying on editor import state
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
- [`../characters/human_body_3d.gd`](../characters/human_body_3d.gd) / [`../characters/human_body_3d.tscn`](../characters/human_body_3d.tscn) - runtime low-poly 3D actor that renders one integrated premade GLB character model (scaled, yaw-corrected, auto-grounded, with idle/walk/run animation), with optional debug draws, gravity, wall sliding, floor snap, front-riser stair traversal, tagged stair-side rejection, and capped dynamic-body pushing
- [`../assets/characters/`](../assets/characters) - premade skinned, textured low-poly character models; `idle`/`walk`/`run` are the current validated baseline clips, optional imported clips such as `dance`, `scared`, or `wave_goodbye` must be validated before gameplay use, and `male.glb` is the default `HumanBody3D` visual with `boy.glb` and `female.glb` as interchangeable alternates
- [`../characters/character_model_catalog_3d.gd`](../characters/character_model_catalog_3d.gd) - canonical mapping from saved player profiles and resident definitions to integrated GLB models
- [`../characters/character_preview_3d.gd`](../characters/character_preview_3d.gd) - transparent SubViewport-friendly low-poly actor preview used by customization and journal screens
- [`../characters/tests/`](../characters/tests) - direct `HumanBody3D` smoke scenes and generated-fixture 3D collision/traversal behavior
- [`../characters/control/`](../characters/control) - controllers, resident presentation hookup, and interaction behavior
- [`../characters/control/base_controller_3d.gd`](../characters/control/base_controller_3d.gd) - shared 3D controller base for `HumanBody3D` lifecycle, movement flags, and movement helper methods
- [`../characters/control/player_controller_3d.gd`](../characters/control/player_controller_3d.gd) - first playable 3D input adapter for `HumanBody3D`, using the existing input map on the XZ plane
- [`../characters/control/resident_controller_3d.gd`](../characters/control/resident_controller_3d.gd) - lightweight 3D resident wander controller (stroll to a nearby point, pause, repeat, with a stuck-timeout) plus `pause_for` so a talked-to resident holds still while facing the player
- [`../characters/resident_factory.gd`](../characters/resident_factory.gd) - spawns `HumanBody3D` residents from shared `AppState` resident data at their landmark anchors, each with an `npc:` talk `StorySubject3D`, a wander controller, and a world-anchored 3D speech balloon; used by `game_world_3d`
- [`../common/gui/`](../common/gui) - in-world UI such as speech balloons; [`../common/gui/speech_balloon_3d.gd`](../common/gui/speech_balloon_3d.gd) is the billboarded, camera-facing `Label3D` dialogue balloon used by the 3D overworld
- [`../game/story_subject_3d.gd`](../game/story_subject_3d.gd) - production `Area3D` world-subject adapter: exposes a stable `subject_id`, resolves action/display/presence from the shared StoryEvent catalog/`AppState`, and is dispatched by `game_world_3d` through `AppState.activate_story_subject`

Put player control, resident movement, model presentation, and interaction prompts here.

## Landmark And World Content

- [`../architecture/`](../architecture) - editable low-poly 3D landmark scenes and their reproducible generators; production placement and interaction hotspots are owned by `game_world_3d.tscn`
- [`../architecture/bagua_tower/bagua_tower_stylized_3d.tscn`](../architecture/bagua_tower/bagua_tower_stylized_3d.tscn) / [`../architecture/bagua_tower/generate_stylized_3d.gd`](../architecture/bagua_tower/generate_stylized_3d.gd) - production Bagua Tower model and its reproducible Low-Poly Building Editor API generator
- [`../architecture/piano_ferry/piano_ferry_stylized_3d.tscn`](../architecture/piano_ferry/piano_ferry_stylized_3d.tscn) / [`../architecture/piano_ferry/generate_stylized_3d.gd`](../architecture/piano_ferry/generate_stylized_3d.gd) / [`../architecture/piano_ferry/piano_ferry_building_spec.json`](../architecture/piano_ferry/piano_ferry_building_spec.json) - production Piano Ferry model, generator, and versioned deterministic base spec
- [`../architecture/bagua_tower/tests/`](../architecture/bagua_tower/tests) - Bagua Tower-specific validation scenes and scripts
- [`../common/`](../common) - shared runtime helpers and common world-facing UI primitives

### Landmark Quest Triggers

- [`../game/story_subject_3d.gd`](../game/story_subject_3d.gd) - place `StorySubject3D` hotspots under the owning landmark proxy in `game_world_3d.tscn`, assign a catalog-backed stable `subject_id`, and leave visibility/action resolution to the shared StoryEvent service

Put new landmark models and reproducible generators under `architecture/`; author production placement, collision, and story hotspots in `game_world_3d.tscn`.

## Reusable Gameplay Modules

- [`../game/grid_board_game/`](../game/grid_board_game) - reusable, intentionally 2D board-game module and local test scenes; isolated from the production overworld
- [`../game/marble_game/`](../game/marble_game) - self-contained native low-poly 3D marble-game prototype, including `RigidBody3D` actors, board physics, camera-ray input, and a focused smoke test; no tilemap dependency
- [`../game/piano_game/`](../game/piano_game) - intentionally 2D piano mini-game prototype; isolated from the production overworld
- [`../game/tests/npc_system/`](../game/tests/npc_system) - NPC/resident validation scenes and companion test assets

If a feature is self-contained and reusable, extend its module folder instead of scattering logic across unrelated directories.

## Addons And Editor Plugins

- [`../addons/low_poly_building_editor/`](../addons/low_poly_building_editor) - submodule containing the native editor dock and 3D viewport tool for low-poly building authoring, including terrain-profiled multi-point Street3D authoring with sloped roads and automatic footpath stairs, plus versioned building/street JSON-to-scene generation, graphical seeded-variant thumbnails/contact sheets, and the interactive generated-building gallery. See the plugin's own docs for the full description: [`../addons/low_poly_building_editor/README.md`](../addons/low_poly_building_editor/README.md) (overview), [`../addons/low_poly_building_editor/docs/feature.md`](../addons/low_poly_building_editor/docs/feature.md) (feature spec), and [`../addons/low_poly_building_editor/docs/contract.md`](../addons/low_poly_building_editor/docs/contract.md) (contract).
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
- [`../characters/tests/test_human_body_3d.tscn`](../characters/tests/test_human_body_3d.tscn) - direct `HumanBody3D` adapter smoke scene covering configuration, flat direction, movement velocity, current-frame controller input, safe capsule placement, step-up/step-down behavior, jump state, ground footprint behavior, and character-model structure (instanced model, mesh, material, animation clips)
- [`../game/tests/npc_system/test_resident_interaction.tscn`](../game/tests/npc_system/test_resident_interaction.tscn) - focused resident progression regression covering gate fallbacks, trust-max milestones, and a resident-driven autosave/continue path
- [`../game/tests/npc_system/test_resident_catalog_external_defs.tscn`](../game/tests/npc_system/test_resident_catalog_external_defs.tscn) - focused resident catalog regression covering external `.tres` definition loading, roster completeness, and field-level validation
- [`../game/tests/cue_progression/test_cue_progression.tscn`](../game/tests/cue_progression/test_cue_progression.tscn) - focused Ferry -> Trinity choir chime -> Bi Shan chamber prompt -> Long Shan exit prompt -> Bagua -> harbor-stage progression regression covering fragment awards, dependable-route notes, Bagua gating, and the spring guardrail on harbor-triggered endgame
- [`../game/tests/bgm/test_bgm_manager.tscn`](../game/tests/bgm/test_bgm_manager.tscn) - focused BGM regression scene covering lazy catalog validation, natural-end fade scheduling, and location-fallback variety rules
- [`../game/tests/persistence/test_story_autosave.tscn`](../game/tests/persistence/test_story_autosave.tscn) - focused story autosave regression covering first-save creation, real `Continue`, safe resume anchors, guarded harbor-performance persistence, soft-ending continuation restore, and departure-save clearing
- [`../game/tests/persistence/test_story_state_persistence.tscn`](../game/tests/persistence/test_story_state_persistence.tscn) - focused persistence regression covering unknown `story_flags` plus save/load restoration for override-backed resident profiles
- [`../game/tests/story_routes/test_story_routes.tscn`](../game/tests/story_routes/test_story_routes.tscn) - focused seasonal-route regression covering concurrent route seeds, manual lead pinning persistence, non-landmark seasonal progression, guarded endgame activation, and final-act save/restore
- [`../game/tests/story_routes/test_story_reactivity.tscn`](../game/tests/story_routes/test_story_reactivity.tscn) - focused cross-route resident reactivity regression covering winter-memory, Spring Festival aftermath, future-choice, second-summer, and preservation-perspective follow-through
- [`../game/tests/story_routes/test_story_event_service.tscn`](../game/tests/story_routes/test_story_event_service.tscn) - focused StoryEvent bridge regression covering strict condition/effect schema validation, resident-beat effect extraction, subject-based resident talk, landmark-trigger activation, inspectable resolution, and resident routine overrides at the shared-state level
- [`../characters/tests/test_character_collisions.tscn`](../characters/tests/test_character_collisions.tscn) - self-contained generated-fixture regression covering `HumanBody3D` gravity/landing, static-wall blocking, front stair ascent/descent, tagged stair-side rejection, and capped `RigidBody3D` pushing
- [`../scenes/tests/test_landmark_cue_loading.tscn`](../scenes/tests/test_landmark_cue_loading.tscn) - focused landmark cue audio loader/cache smoke test
- [`../scenes/tests/test_low_poly_building_editor_3d.tscn`](../scenes/tests/test_low_poly_building_editor_3d.tscn) - end-to-end building-editor smoke suite relocated from the `addons/low_poly_building_editor` submodule so the addon carries no parent-repo paths; probes generated buildings with `HumanBody3D` collision and covers the full wall/floor/stairs/rail/pillar/roof/opening regression matrix described in the addon's `docs/feature.md`
- [`../scenes/tests/test_building_tour_3d.tscn`](../scenes/tests/test_building_tour_3d.tscn) - generic playable building-tour harness with an exported `building_scene`, transform and player spawn, plus `HumanBody3D`, camera-relative movement, orbit/zoom camera, lighting, and ground collision; defaults to the generated low-poly Bagua Tower concept
- [`../weather/tests/capture_weather_3d.tscn`](../weather/tests/capture_weather_3d.tscn) - focused steady-rain validation/capture scene for the production 3D weather rig
- [`../scenes/tests/test_camera_3d_occlusion.tscn`](../scenes/tests/test_camera_3d_occlusion.tscn) - focused `Camera3DController` regression covering multiple blockers, target exclusion, prior-transparency preservation, sightline restoration, disable cleanup, and inactive-camera cleanup
- [`../scenes/tests/test_low_poly_terrain_3d.tscn`](../scenes/tests/test_low_poly_terrain_3d.tscn) - focused 3D terrain scene covering heightmap and mask-clipped generation, layered water, wind control, and coordinate round-trips
- [`../scenes/tests/test_street_terrain_integration.tscn`](../scenes/tests/test_street_terrain_integration.tscn) - focused terrain-generation/Street3D integration regression covering automatic source discovery, base-grid profile baking, corridor bed shaping/feathering, manual-height preservation, street mesh/collision retention, and street-triggered terrain regeneration
- [`../scenes/tests/test_street_mask_generation.tscn`](../scenes/tests/test_street_mask_generation.tscn) - focused STREET-mask regression covering centerline extraction, bent multipoint and sibling-junction generated street geometry, terrain corridor shaping, deterministic replacement/reuse, and a real-island rebuild with visible Street3D meshes and stairs
- [`../scenes/tests/test_game_world_3d.tscn`](../scenes/tests/test_game_world_3d.tscn) - production-world smoke covering terrain/water/street generation, actor/controller grounding and wading, camera wiring/orbit, authored-landmark placement/collision, residents, story interaction, audio, weather-to-water integration, and semantic resume anchors
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
- [`story/summer_of_piano_island_story_framework.md`](story/summer_of_piano_island_story_framework.md) - single source of truth for the current story, protagonist background, seasonal frame, route meanings, and ending tone
- [`features/bgm_system.md`](features/bgm_system.md) - BGM pool design, V1 controller scope, selection rules, fallback order, and variant policy
- [`features/bgm_tagging_guide.md`](features/bgm_tagging_guide.md) - track-weight authoring rules for the future `bgm_catalog.gd`
- [`bgm_suno_guide.md`](bgm_suno_guide.md) - Suno-focused content-generation guide for the 7-track BGM seed pool and later expansion
- [`piano_game_design.md`](piano_game_design.md) - current piano prototype status plus integration rules for short story-facing performance beats
- [`features/piano_game_integration.md`](features/piano_game_integration.md) - canonical decision and future contract for connecting the standalone piano prototype to the main game
- [`features/piano_ferry.md`](features/piano_ferry.md) - implementation-facing summary of the ferry onboarding arc and journal unlock handoff
- [`features/npc_system.md`](features/npc_system.md) - implementation-facing summary of the resident/NPC system
- [`features/terrain_system.md`](features/terrain_system.md) - terrain generation ownership, mask-rule workflow, and extension guide
- [`features/low_poly_terrain_3d.md`](features/low_poly_terrain_3d.md) - current low-poly 3D terrain prototype scope, ownership, and validation notes
- [`features/low_poly_actor_3d.md`](features/low_poly_actor_3d.md) - current low-poly 3D actor adapter prototype scope, ownership, and validation notes
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
