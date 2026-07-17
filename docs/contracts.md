# Kulangsu Contracts

This file documents the durable boundaries future changes should preserve. These are not formal schema files, but they are real interfaces between systems.

## Runtime Entry Contracts

- [`../project.godot`](../project.godot) must continue to define the Godot project entry point.
- The current main scene contract is `run/main_scene = res://main.tscn`.
- The current shared-state runtime contract is a single scene-owned [`AppStateService`](../game/app_state.gd) instance resolved through [`../game/app_runtime.gd`](../game/app_runtime.gd).
- The current overworld-weather runtime contract is a single scene-owned [`WeatherManager`](../weather/weather_manager.gd) instance resolved through [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd).

If either changes, update this file, [`architecture.md`](architecture.md), and [`README.md`](../README.md).

## App Shell Contract

Owned by:

- [`../main.tscn`](../main.tscn)
- [`../main.gd`](../main.gd)
- [`../ui/app_screen_router.gd`](../ui/app_screen_router.gd)

Current contract:

- the app shell owns boot, title, player setup, gameplay entry, and in-game overlays
- `AppScreenRouter` is the single navigation-history authority: handlers replace, push, or pop routes, and `main.gd` renders the resulting presentation instead of reconstructing prior state from panel visibility
- panel, HUD, backdrop, gameplay-root visibility, prompt BGM ducking, and `SceneTree.paused` are derived together from the current route stack; individual transition handlers must not mutate those presentation fields independently
- gameplay remains embedded while overlays are shown on top
- UI is authored against a `1920 x 1080` design canvas and scaled to the live viewport
- `Esc` backs out through overlay flow and `J` toggles the journal during gameplay
- the reusable melody prompt overlay opens from `AppState` requests and may return either to gameplay or to the journal, depending on where it was launched
- the ending overlay now opens from the shared `endgame_started` milestone instead of assuming the harbor performance is always the only ending gate
- once the ending overlay opens, `Continue Exploring` is offered only for endings whose `ending_behavior` is `continue_story`; choosing it clears the active ending wrapper, restores live story play, and writes a fresh story autosave, while `Leave` clears the resumable story autosave, routes through the dedicated morning-ferry departure card and credits, and returns to title with `Continue` disabled

## Shared State Contract

Owned by:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/app_runtime.gd`](../game/app_runtime.gd)

Current contract:

- the running app owns exactly one scene-owned `AppStateService`, resolved through the typed `AppRuntime.get_app_state(node) -> AppStateService` lookup rather than an autoload
- the store owns one `AppStateSnapshot` and one `AppStateProjection`; `get_snapshot()` and `get_projection()` always return detached copies
- canonical snapshot data includes mode, season/day/hour, location/objective/journal, story flags, melody/landmark/endgame/resident progress, player profile/costume, runtime settings, checkpoint, and save metadata
- chapter, time-of-day, fragment totals, route progress/leads, display-name lists, unlocked costumes, and ending summary are projection-only values and must not be serialized or independently mutated
- top-level commands finalize in this order: normalize, rebuild projection, diff into `AppStateChangeSet`, commit snapshot/projection, attempt one requested autosave, emit one `state_committed(changes)`, then emit queued imperative events
- unchanged `update_world_context(...)` requests must return before creating a transition, and the world interaction coordinator must not republish the same proximity hint every frame
- reducer contexts may share immutable catalog, route-definition, and StoryEvent-index data, but per-command snapshot/projection data stays detached; helper back-references to the reducer context are released after each operation
- failed autosaves do not roll back gameplay state and do not replace the last valid save metadata
- production callers must not read or mutate service fields. UI, BGM, world integration, resident spawning, and journals fetch projections and issue semantic commands
- `state_committed(changes)` replaces field-specific state signals. Consumers check the `SESSION`, `STORY`, `TIME`, `MELODY`, `LANDMARKS`, `RESIDENTS`, `PLAYER`, `SETTINGS`, `CHECKPOINT`, and `SAVE` domains before refreshing
- the only non-state signals are `melody_prompt_requested`, `melody_hint_shown`, `landmark_audio_cue_requested`, and `story_milestone`; queued events run after committed state is observable
- `landmark_audio_cue_requested(cue_id, context)` is the bridge from successful landmark interactions into one-shot world audio feedback; it fires for both collected pickups and prompt-opening landmark interactions such as the Trinity choir chime, Bi Shan chamber, Long Shan exit, and harbor stage
- `story_milestone(milestone_id, context)` fires after compound state changes resolve; current milestone ids include `landmark_resolved`, `fragment_restored`, `festival_ready`, `festival_performed`, `resident_trust_max`, and `endgame_started`
- lifecycle commands are `start_new_story()`, `resume_story()`, and `start_free_walk()`; persistence commands are `request_autosave()` and `clear_story_save()`
- world commands cover subject description/activation, world-event notification, prompt completion, world-context changes, and resume-checkpoint changes. Player commands replace the full profile, equip a costume, or pin/cycle/clear a lead. `commit_settings(...)` accepts one complete normalized settings set
- `game/app_state/story_save_codec.gd` owns V1 migration and V2 dictionary mapping; `story_save_repository.gd` owns file I/O and accepts a configurable path. Loading V1 leaves the file unchanged, and the next successful normal autosave writes V2
- V2 stores canonical story data only. It excludes projections, transient hint/status, save metadata, and runtime settings
- `StoryEventService`, `StoryRouteGraph`, and `ResidentInteractionService` operate against a detached transition context. They do not retain the live store, emit public signals, or perform file I/O; runtime-port files and `runtime_*` forwarding methods no longer exist
- `activate_story_subject(...)` is the generic interaction entry point for resident talk and all scene-authored `StorySubject3D` world subjects; the current subject taxonomy includes `npc:<resident_id>`, `landmark:<landmark_id>.<trigger_id>`, and `inspectable:<inspectable_id>`
- `game/storylines/` owns canonical route and route-event authoring, while `game/story_route_graph.gd` owns projection, lead selection, canonical story-event availability checks/blocker reporting, endgame-trigger evaluation, ending-behavior classification, and baseline ending-tone tag generation
- route-score prerequisites are evaluated against an all-route completion snapshot, so cross-route score gates cannot depend on route display order
- all resident definitions live in external `.tres` files under `res://game/residents/definitions/`; `ResidentCatalog` loads them at runtime and `include_in_catalog = false` keeps a resource out of the runtime roster
- `interact_with_resident()` checks a resident's `conditional_beats` (priority-sorted, condition-gated) before falling through to the linear `dialogue_beats` spine
- resident conditional gating and StoryEvent conditions may now read `season_phase`, `story_day`, `world_hour`, `time_of_day`, `story_flags`, route state, route score, and endgame-active state
- routine overrides are saved and are merged into projection configuration. They are not yet reapplied to resident actors that are already alive in the production 3D world
- `JournalBuilder` consumes detached `AppStateProjection` data and never receives the live service node

Governance:

- keep shared cross-screen state here
- do not move scene-local behavior into `AppState` without a strong reason
- if signal names, payload shapes, or key state fields change, update this file and the affected feature docs

## StoryEvent Boundary

Reference:

- [`event_story_system_design.md`](event_story_system_design.md)

Owned by:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/story_effect_schema.gd`](../game/story_effect_schema.gd)
- [`../game/story_event_catalog.gd`](../game/story_event_catalog.gd)
- [`../game/story_event_service.gd`](../game/story_event_service.gd)
- [`../game/storyline_validation_provider.gd`](../game/storyline_validation_provider.gd)
- [`../game/resident_interaction_service.gd`](../game/resident_interaction_service.gd)
- [`../game/app_state/app_state_reducer_context.gd`](../game/app_state/app_state_reducer_context.gd)
- [`../game/story_world_reactivity.gd`](../game/story_world_reactivity.gd)

Current contract:

- story-facing world interactions now flow through stable `subject_id + action` pairs instead of route-specific scene callbacks
- `StoryEventService` owns generic context building, shared condition matching, priority-based candidate selection, and shared effect application. It receives a per-command detached reducer context, never the live store.
- `StoryRouteGraph` and `ResidentInteractionService` follow the same detached-input rule; `AppStateService` remains the sole committer, persistence coordinator, and public signal owner.
- `StoryEffectSchema` is the parent-owned contract for dictionary-authored StoryEvent conditions and effects. It rejects unknown keys, wrong nested types, invalid canonical ids, and malformed recursive `conditional_effects`; `StoryEventService` validates the complete payload before applying any mutation, so a bad payload cannot leave partially updated story state
- each `StorylineRouteResource` under `game/storylines/routes/` resolves to one `route` definition plus that route's `events`; runtime `StoryRouteGraph` instances share one immutable definition bundle for the process, while editor tools continue to rebuild directly from `StorylineCatalog` when authors refresh or edit resources
- the storyline schema classes (`StorylineCatalog`, `StorylineRouteResource`, `StorylineEventResource`, `StorylineEndingToneRule`, `StorylinePhaseSet`, `StorylineHostValidationProvider`) are owned by the `addons/storyline_editor` submodule; the parent owns the authored `.tres` data, `game/storylines/phase_set.tres` (kept in sync with `StorySeasonPhases` by `test_storyline_resources`), `StoryEffectSchema`, `KulangsuStorylineValidationProvider`, and the `storyline_editor/*` project settings that locate/configure them
- `storyline_editor/validation_provider_script` points from the parent to `game/storyline_validation_provider.gd`; the provider extends the addon's generic interface and supplies live Kulangsu semantic validation to the inspector and route browser. The addon has no Kulangsu class/path dependency and must continue working when the setting is empty
- route events may depend on events from any other route resource by referencing those event ids in `prerequisites.story_flags_all` or `prerequisites.story_flags_any`
- `game/story_event_catalog.gd` is the authored StoryEvent tree file for the current landmark migration; it now owns the full `melody_landmarks` landmark-interaction subtree
- StoryEvent catalog validation checks every authored condition/effect payload, including nested conditional effects and `story_event` references against the typed route-event resources loaded by `StorylineCatalog`, so interaction bindings cannot silently contain typos, invalid types, or missing canonical ids
- resident dialogue beats are projected through `StoryEffectSchema.extract_effects(...)` before runtime application, keeping dialogue metadata out of the strict effect executor while preserving declared effect keys
- resident conditional beats now resolve through `pick_story_candidate(...)` and apply their side effects through `apply_story_effects(...)` rather than keeping separate copies of condition/effect logic
- typed route resources are now the canonical narrative gate source for route events; cached `StoryRouteGraph.can_resolve_story_event(...)` and `get_story_event_blockers(...)` calls are the shared availability surface consumed by resident dialogue and StoryEvent effect application
- `StorySubject3D` is the production world-side subject adapter; `StoryInteractionCoordinator` routes all subjects below its configured world root through `activate_story_subject(...)`, and `StoryEventService` resolves current `landmark:` and `inspectable:` subjects plus landmark reward world events through the authored catalog before any compatibility fallback path
- non-resident inspect text now resolves through `StoryWorldReactivity.resolve_inspect_result(...)`, which builds stable `inspectable:` subject ids and reuses the shared condition matcher
- resident routine overrides are the first live world-state effect channel driven through the shared StoryEvent boundary; they redirect the shared spawn/movement config, and reapplying them to live 3D resident actors in `game_world_3d.gd` is a pending work item (the retired 2D overworld owned that behavior)
- the current route ledger remains the player-facing progression view, while the longer-term goal is still to migrate route families into authored recursive StoryEvent definitions and a published-fact ledger

Governance:

- do not let future route implementations bypass the generic subject/fact model by adding direct route-to-route service calls unless there is a proven ownership need
- prefer optional capability adapters and published facts over hardcoded calls between individual story families

## 3D Character Presentation Contract

[`../characters/character_model_catalog_3d.gd`](../characters/character_model_catalog_3d.gd) is the single mapping from saved player profiles and resident definitions to integrated low-poly GLB models. Runtime actors and UI previews must use that catalog rather than interpreting the retained per-part appearance keys. Those keys remain serialized for backward save compatibility, but they do not imply a layered 2D renderer contract.

## Weather Runtime Contract

Owned by:

- [`../weather/weather_manager.gd`](../weather/weather_manager.gd)
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd)
- [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)

Current contract:

- `WeatherManager` owns the weighted overworld weather-state list, random hold/transition timing, interpolation, live application to one registered `WeatherRig3D`, and publication of synced wind for terrain water
- the running app owns exactly one `WeatherManager` node; callers resolve it through `WeatherRuntime.get_weather_manager(node)` instead of a Project Settings autoload
- gameplay scenes register a weather host with `WeatherManager.register_weather_host(...)`, providing the scene-owned `WeatherRig3D` as `weather_state_target`
- weather state dictionaries remain internal to the manager; the rig exposes `capture_weather_state()` and `apply_weather_state(...)` as the presentation boundary
- gameplay scenes may update the shared wind through `WeatherManager.set_registered_wind(...)`; water consumes that same state through `LowPolyWaterWindAdapter`
- [`../weather/tests/capture_weather_3d.tscn`](../weather/tests/capture_weather_3d.tscn) is the focused presentation validation scene

Governance:

- keep overworld weather-cycle policy and synced wind publication in `WeatherManager`, not in presentation nodes or scene files
- keep 3D rain/fog/cloud rendering in `WeatherRig3D`
- if the registration API or the single-manager runtime assumption changes, update this file and the weather feature docs

## Scene-Graph Lookup Contract

Owned by:

- [`../game/app_runtime.gd`](../game/app_runtime.gd)

Current contract:

- scene-graph systems that need the live player node resolve it through `AppRuntime.get_player(node)`
- the current player contract depends on the active player actor staying in the `"player"` group; the production player is a `HumanBody3D`, so `get_player` returns an untyped `Node` and callers cast to the actor type they require
- shared UI/progression code should still use `AppState`, not direct player-node lookups, for anything save-relevant or player-facing

Governance:

- keep player lookup lightweight and scene-owned; do not reintroduce a static singleton just to hold the live player pointer
- if the player group contract changes, update this file and `architecture.md`

## World Integration Contract

Owned by:

- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn)
- [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)
- [`../game/world/actor_surface_follower.gd`](../game/world/actor_surface_follower.gd)
- [`../game/world/story_interaction_coordinator.gd`](../game/world/story_interaction_coordinator.gd)

Current contract:

- `scenes/game_world_3d.gd` is the world composition root: it maps landmark proxies through the shared coordinate adapter, spawns the resident roster through `ResidentFactory`, configures the focused world components, and syncs location/landmark/resume context into `AppState`
- `ActorSurfaceFollower` seats its configured actor on the solid surface beneath it and applies the shallow-water policy; `HumanBody3D` remains terrain-agnostic
- `StoryInteractionCoordinator` listens to the configured actor controller, selects only `StorySubject3D` nodes below its configured world root, and owns proximity hints plus dispatch through `AppState.activate_story_subject(...)`
- `scenes/game_world_3d.gd` owns mapping the live player position onto safe story resume anchors for autosave and continue, and applies the saved resume anchor on entry (falling back to the definition marked as the catalog default)
- `scenes/game_world_3d.gd` registers the 3D weather rig target with `WeatherManager`, which owns preset cycling and synced wind application
- `scenes/game_world_3d.tscn` keeps the player actor in the `"player"` group and residents under a scene-owned resident root
- landmark naming, proxy lookup, placement, and location sync depend on `LandmarkCatalog` definitions resolving to the authored `Landmarks/*Proxy` nodes in the world scene
- reapplying resident routine overrides to live 3D resident actors is a pending work item; overrides currently take effect through the shared spawn/movement config (validated at the shared-state level by `game/tests/story_routes/test_story_event_service.tscn`)

Governance:

- keep scene-specific composition in `scenes/game_world_3d.gd`; keep surface-follow and interaction-coordination policy in their `game/world/` components
- document node-path or spawn-anchor naming assumptions if new systems depend on them

## Editor Addon Contracts

The low-poly building editor contract lives in its [`../addons/low_poly_building_editor/`](../addons/low_poly_building_editor) submodule at [`docs/contract.md`](../addons/low_poly_building_editor/docs/contract.md). The storyline editor contract lives in its [`../addons/storyline_editor/`](../addons/storyline_editor) submodule at [`docs/contract.md`](../addons/storyline_editor/docs/contract.md). The parent repo owns the pinned revisions and Kulangsu-specific integration data; reusable editor implementation and addon documentation land in the addon repositories first.

## Low-Poly 3D Prototype Contract

Owned by:

- [`../terrain/low_poly_terrain_3d.gd`](../terrain/low_poly_terrain_3d.gd)
- [`../terrain/low_poly_world_coordinates_3d.gd`](../terrain/low_poly_world_coordinates_3d.gd)
- [`../terrain/low_poly_art_style_3d.gd`](../terrain/low_poly_art_style_3d.gd)
- [`../characters/human_body_3d.gd`](../characters/human_body_3d.gd)
- [`../assets/characters/male.glb`](../assets/characters/male.glb) (default model; `boy.glb` and `female.glb` are alternates)
- [`../characters/tests/test_character_collisions.tscn`](../characters/tests/test_character_collisions.tscn)
- [`../scenes/game_world_3d.tscn`](../scenes/game_world_3d.tscn)
- [`../scenes/tests/test_game_world_3d.tscn`](../scenes/tests/test_game_world_3d.tscn)
- [`features/low_poly_3d_integration.md`](features/low_poly_3d_integration.md)

Current contract:

- `game_world_3d.tscn` is the production overworld instantiated directly by `main.gd`; the runtime-direction decision and cutover evidence are recorded in [`plan/implementation_plan.md`](plan/implementation_plan.md) and [`features/low_poly_3d_integration.md`](features/low_poly_3d_integration.md)
- `StorySubject3D` nodes provide spatial adapters for the stable subject ids in
  the authored StoryEvent catalog, and they must dispatch through
  `AppState.activate_story_subject(...)`; visual building replacement must not
  rename subject ids or introduce 3D-only story effects
- `game_world_3d` may resolve semantic landmark-name resume anchors to 3D
  transforms, including the Piano Ferry fallback; save data must not persist
  `NodePath`, instance ids, or raw generated-mesh details as the sole resume key
- `LowPolyWorldCoordinates3D` owns terrain-mask-pixel to 3D XZ conversion plus rough 2D isometric-position to mask-pixel conversion for authored landmark blockouts
- landmark, actor, story-anchor, and future hotspot placement must use `LowPolyWorldCoordinates3D` instead of duplicating grid-centering or isometric conversion math
- `LowPolyTerrain3D` owns optional grayscale heightmap sampling; black maps to `heightmap_min_offset`, white maps to `heightmap_max_offset`, and offsets are added to `land_height`
- when `heightmap_expands_land_to_source` is enabled with an assigned heightmap, the heightmap dimensions become the generated terrain source, sampled cells at or below `water_height` become water, higher mask colors may upgrade cells to STREET semantics or building-footprint overlays, and mask water does not clip the heightmap source area
- when heightmap expansion is disabled or no heightmap is assigned, mask water remains the water-area source; its baked placement/query plane stays flat at `water_height` while the water shader displaces the rendered vertices
- water rendering expands beyond classified water by `water_land_overlap_cells`, defaulting to one adjacent land-cell ring; this is visual-only and must not change terrain kind, land/seabed height queries, collision generation, or placement semantics
- by default, heightmapped terrain is generated as a connected low-poly surface with shared-corner height averaging; expanded heightmap source heights are smoothed before waterline classification, while mask-clipped generation keeps the smoothing pass land-only
- submerged heightmap-expanded cells keep a terrain surface below the flat baked water plane so the seabed remains visible through the shader-displaced transparent `WaterMesh`; dry land and seabed cells share corner-height sampling, and heightmap-expanded shorelines must not draw vertical land-wall `ShorelineMesh` geometry between them
- heightmap file, expansion-mode, and offset edits are manual-apply: assigning the image, toggling `heightmap_expands_land_to_source`, or tuning min/max must not automatically rebuild in the editor; use the exported rebuild control or `rebuild_from_source()`
- generated streets persist as one deterministic `StreetNetwork3D` definition: `LowPolyTerrain3D` only re-extracts `GeneratedStreets` from the mask on an explicit rebuild and owns the network under the edited scene so stable junction/segment IDs, curves, vertical profiles, and section resources serialize into the `.tscn`. Generated segment and junction meshes remain rebuildable caches. On scene load / `rebuild_reusing_generated_streets()` terrain reshapes its bed from stored segment corridors and junction footprints without re-extracting the mask; `GENERATED_STREET_ROOT_META` protects the subtree from transient terrain-mesh clearing. Legacy stored Street3D children remain readable until an explicit rebuild migrates the generated subtree.
- STREET mask cells remain extraction and terrain-classification input, but they must not emit a parallel mask-derived `StreetMesh`; `StreetNetwork3D` owns generated visible road/junction geometry, standalone `Street3D` remains an authored compatibility source, and cells that cannot become a generated path render as supporting land
- height-aware placement must query generated terrain heights through `LowPolyTerrain3D.get_world_surface_height(...)` or `LowPolyTerrain3D.get_sample_cell_height(...)` after rebuild instead of assuming global `land_height`; in heightmap-expanded water these queries currently expose underlying land/seabed elevation rather than visual water-plane height
- `ActorSurfaceFollower`, configured by `game_world_3d`, owns actor grounding: each physics frame it seats the player actor on the solid surface directly beneath it by casting a short downward ray against the physics world (the actor's `collision_mask`), so the actor stands on terrain, piers, or collision-bearing building parts instead of hovering. It falls back to `LowPolyTerrain3D.get_world_surface_height(...)` only when the ray finds nothing within reach, preserving land/seabed elevation following and shallow-water seating. `terrain_clearance` defaults to `0`; `HumanBody3D` itself stays terrain-agnostic
- `game_world_3d` owns three authored building scenes, two stable tunnel marker anchors, the complete 15-landmark/5-inspectable `StorySubject3D` set, and recursively generated static collision for authored landmark meshes
- `Camera3DController` keeps its followed target readable by raycasting from the current camera to the look-at point and fading every collision-backed `GeometryInstance3D` blocker through the instance `transparency` property. It excludes the target subtree, preserves pre-existing transparency, restores cleared blockers (or blockers tracked by a camera that stops being current), and exposes collision-mask, fade amount/duration, area-query, and hit-limit tuning. Automatic visual resolution requires the geometry instance to be an ancestor or descendant of the hit collision object
- `HumanBody3D.body_height` and `HumanBody3D.body_radius` are the current low-poly actor shape contract; they update the GLB model scale, capsule collision, bounding box, and ground footprint together
- `HumanBody3D` always renders one integrated GLB character model under `VisualRoot/CharacterModel`; there is no procedural block-mannequin fallback or separate hair, pants, jacket, accessory-attachment, or runtime skin-transfer layer. The only code-generated geometry left is the optional `DebugBox` bounding-box gizmo and the optional skeleton bone-debug lines
- the default character model is `assets/characters/male.glb`, with `boy.glb` and `female.glb` as interchangeable alternates; the selected model owns its complete visible appearance and is scaled by `body_height / character_model_height`, rotated by `character_model_yaw_offset` to face the rig's `+Z` forward, and planted so its lowest rendered point sits at the foot origin (`character_model_auto_ground` plus the manual `character_model_y_offset`)
- `game_world_3d` maps the shared player profile to those whole-model alternates:
  adult masculine uses `male.glb`, adult feminine uses `female.glb`, and teen
  uses `boy.glb`; the 3D layer does not duplicate or persist a separate
  appearance profile
- `game_world_3d` registers one `WeatherRig3D` generic state target with the shared
  `WeatherManager`; the manager remains authoritative for preset choice, hold/transition timing,
  interpolation, and published wind, while the rig owns only 3D rain, fog, and cloud-light
  presentation
- `HumanBody3D.draw_skeleton_bones` is a debug toggle (default `false`): when on with the GLB model active it draws the model's `Skeleton3D` as bone lines in a `SkeletonDebug` `ImmediateMesh` under the skeleton, refreshed each frame to track animation, colored by `skeleton_debug_color`; it is a debug aid only and stays hidden in normal play
- locomotion drives the model `AnimationPlayer`: `model_idle_animation` / `model_walk_animation` / `model_run_animation` map to standing/walking/running and loop with a short crossfade; clip names resolve case-insensitively against the imported animation list; optional imported clips beyond `idle`/`walk`/`run` must be validated before being bound to gameplay states
- `HumanBody3D.max_step_height`, `HumanBody3D.floor_snap_distance`, and `HumanBody3D.grounding_speed` tune prototype 3D navigation over floor meshes, including stair treads; solid wall geometry must still block traversal instead of being bypassed by stair support, while preserving lateral `move_and_slide()` motion. Blocking wall contact suppresses horizontal snap repositioning, but forward floor probes stay available for normal riser step-up and step-down support. Generated stair side blockers are tagged as side walls; `HumanBody3D` checks both current contact and the short movement path ahead before permitting forward step-up, and every target-floor lookup propagates that permission so a tread cannot be sampled through a thin side wall before contact. `RigidBody3D` contacts are dynamic push targets, not blocking wall contacts: the actor applies a small movement-direction impulse to them while keeping static walls on the wall-slide path
- `HumanBody3D` applies gravity (`GRAVITY`, capped by `MAX_FALL_SPEED`) whenever it is airborne and not in a cosmetic jump, so a body spawned or walked off an edge above the floor falls and lands instead of hovering. For a body that has a `controller`, `_physics_process` also runs a vertical-only `_apply_passive_vertical_motion` step on any frame the controller issued no move, so an idle character still settles onto the floor beneath it. Bodies without a controller (manually driven test probes) are exempt so their physics is never double-stepped, and `stop_moving` zeroes only horizontal velocity so the vertical fall continues while idle
- `HumanBody3D` must not run manual stair/floor reacquisition while `m_is_currently_jumping` is active; jump-state grounded checks intentionally return false so repeated visual jumps on stair crests cannot reuse stale stair directions and pull the actor onto the wrong floor sample
- `HumanBody3D` locomotion is conveyed entirely by the GLB model's `idle`/`walk`/`run` animation clips; the actor adds no procedural walk/run bob (the only scripted `VisualRoot` offset is the jump arc). It remains a prototype actor until the 3D asset direction is finalized
- low-poly palette, camera, lighting, and landmark colors should flow through `LowPolyArtStyle3D` presets while the art direction is exploratory
- `LowPolyArtStyle3D` preset field edits are manual-apply: use exported rebuild controls, deliberate rebuild calls, or scene reloads after style changes rather than adding automatic resource-change rebuild behavior

Governance:

- keep prototype placement, style, and validation docs in sync with [`features/low_poly_terrain_3d.md`](features/low_poly_terrain_3d.md) and [`features/low_poly_actor_3d.md`](features/low_poly_actor_3d.md)
- keep the stable 3D subject-id and semantic resume-anchor rules above aligned
  with `features/low_poly_3d_integration.md` whenever interaction or save
  ownership changes

## Multi-Level World Contract

The retired 2D level registry, level-aware nodes, portals, steps, rooms, and tunnel masking stack has been removed. The production world currently uses ordinary 3D collision, authored terrain heights, and model-owned stair geometry. There is no general-purpose 3D portal or tunnel-interior visibility contract yet; [`features/multi_level_spaces.md`](features/multi_level_spaces.md) records that gap and the requirements for a future implementation.

## Landmark Progress Contract

Owned by:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/landmarks/landmark_catalog.gd`](../game/landmarks/landmark_catalog.gd)
- [`../game/landmarks/landmark_definition.gd`](../game/landmarks/landmark_definition.gd)
- [`../game/landmarks/definitions/`](../game/landmarks/definitions)
- [`../game/story_subject_3d.gd`](../game/story_subject_3d.gd) (scene-authored production world subject node)

Current contract:

- `AppStateSnapshot.landmark_progress` is the canonical `Dictionary` keyed by landmark id (`piano_ferry`, `trinity_church`, `bi_shan_tunnel`, `long_shan_tunnel`, `bagua_tower`, `festival_stage`)
- `LandmarkCatalog` is the canonical registry for static landmark identity, display name, world inclusion/path/coordinate metadata, default resume selection, audio cue id/resource, and named initial-progress profiles
- `AppStateService` builds new-story, resume, free-walk, and fallback snapshots from the catalog, then owns the committed runtime copy; definition resources must not be mutated during play
- each entry is a `Dictionary` with at minimum a `"state"` key: `locked / available / introduced / in_progress / resolved / reward_collected`
- landmark-specific sub-state (e.g. `"harbor_clue_found"` for Piano Ferry, `"cues_collected"` plus `"chime_performed"` for Trinity Church, `"checkpoints_collected"` for Long Shan Tunnel, or `"synthesis_done"` for Bagua Tower) lives inside the same per-landmark entry
- consumers read detached landmark data through `AppStateService.get_projection()` and `AppStateProjection.get_landmark_progress()` / `get_landmark_state()`; production callers must not access the committed snapshot directly
- semantic commands such as `activate_story_subject()`, `notify_story_world_event()`, and `complete_prompt_request()` are the write boundary; reducers update a detached working snapshot and return one transition
- a successful landmark mutation contributes `LANDMARKS` (and, when relevant, `MELODY`) to the single `AppState.state_committed(changes)` notification for that command
- `AppState.melody_hint_shown(text)` fires when a melody-specific StoryEvent effect emits flavour text; the HUD subscribes to display it on-screen without making `StorySubject3D` carry melody-only metadata
- successful landmark interactions may also emit `AppState.landmark_audio_cue_requested(cue_id, context)` so the world scene can play the catalog-assigned local motif without relying on `melody_hint_shown` text alone; `StoryEffectSchema` validates cue and landmark ids against the same catalog before mutation
- Resident dialogue beats may carry `"unlock_landmark"` to unlock a landmark when the beat fires, and `"gate"` / `"gate_fallback"` to block a beat until a landmark condition is satisfied
- Resident dialogue beats may carry `"landmark_reward"` to trigger a landmark resolution (fragment award, melody state update, downstream unlocks) when the beat fires
- `game/story_event_catalog.gd` owns the canonical authored world-subject metadata list and presence rules; the `StorySubject3D.subject_id` dropdown reads from that shared catalog, surfaces configuration warnings for unknown ids, and keeps stable world subjects decoupled from whichever StoryEvent currently binds them
- `scenes/game_world_3d.tscn` owns the production proxy nodes and exact 15 landmark plus 5 inspectable non-NPC subject ids; each navigable `LandmarkDefinition` maps to one proxy path and authored isometric coordinate, and the production-world smoke test checks the complete subject set

Governance:

- keep per-landmark and inspect-surface setup in `StorySubject3D` nodes under the owning production-world landmark proxy, and keep active resolution logic behind `AppStateService` semantic commands; current landmark interaction beats plus landmark prompt-completion/reward follow-through and visibility rules live in `game/story_event_catalog.gd`/`game/story_event_service.gd`
- if a new landmark arc is added, create its typed definition resource and register it in `LandmarkCatalog`, place any navigable proxy and `StorySubject3D` nodes with the correct stable ids in `game_world_3d.tscn`, update catalog/world regression expectations, and prefer authored StoryEvent bindings before extending compatibility fallbacks
- adding a landmark id, audio cue id, or progress-profile name anywhere else without updating the catalog is a contract violation; derived consumers must query the catalog instead of maintaining parallel lists
- if the landmark state enum changes, update this file and the relevant landmark feature docs
- `StorySubject3D` nodes mirror visibility and targetability from StoryEvent metadata; callers should not own hide/disable decisions directly

## Reusable Module Contracts

### Background Music

Owned by:

- [`../game/bgm_catalog.gd`](../game/bgm_catalog.gd)
- [`../game/bgm_manager.gd`](../game/bgm_manager.gd)
- [`../scenes/game_world_3d.gd`](../scenes/game_world_3d.gd)

Current contract:

- `game_world_3d.gd` owns exactly one scene-local `BgmManager` while gameplay is loaded
- `BgmManager` owns the active `AudioStreamPlayer`, recent-history buffer, commitment window, silence gap timer, and weighted track selection
- `BgmManager` also owns short-lived ducking state through `duck_for_cue(duration)` and `set_ducked(ducked)` so landmark cues and melody prompts can lower BGM without moving BGM ownership into the UI
- `BgmManager` listens to `AppState.state_committed(changes)` and refreshes location or melody context from the latest projection when the `SESSION` or `MELODY` domain changes; it does not write shared gameplay state back
- the current V1 context is `location + melody progress` with fixed defaults `time = afternoon`, `season = summer`, and `weather = clear`
- the current seed pool is authored in `BgmCatalog` rather than inferred from directory scanning

Governance:

- if the catalog format changes materially, update this file and the BGM feature docs
- if BGM ownership moves out of `game_world_3d.gd` or begins depending on new `AppState` APIs, update this file, [`architecture.md`](architecture.md), and [`module_map.md`](module_map.md)

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
