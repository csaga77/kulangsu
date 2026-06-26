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

Current contract:

- the app shell owns boot, title, player setup, gameplay entry, and in-game overlays
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

- `AppState` is the shared UI/progression-facing bridge between gameplay and UI
- the running app owns exactly one `AppStateService` node; callers resolve it through `AppRuntime.get_app_state(node)` instead of a Project Settings autoload
- `AppState` keeps the stable public API, but active player-profile, journal-text, story-save, landmark/melody progression, resident interaction, and runtime audio/settings logic now live in composed helper scripts under `game/`
- `chapter` is now a compatibility/display label; authoritative story progression lives in `season_phase`, route state, and `story_flags`
- resident definitions and default resident runtime profiles are initialized lazily through `AppState` getters/configuration instead of being fully built at script-load time
- it exposes signals for mode, chapter, season phase, story time, location, objective, hint, save status, fragments, melody progress, melody prompt requests, landmark audio cue requests, landmarks, residents, resident profiles, player appearance/costumes, route progress, active leads, endgame state, summary updates, and story milestones
- `landmark_audio_cue_requested(cue_id, context)` is the bridge from successful landmark interactions into one-shot world audio feedback; it fires for both collected pickups and prompt-opening landmark interactions such as the Trinity choir chime, Bi Shan chamber, Long Shan exit, and harbor stage
- `story_milestone(milestone_id, context)` fires after compound state changes resolve; current milestone ids include `landmark_resolved`, `fragment_restored`, `festival_ready`, `festival_performed`, `resident_trust_max`, and `endgame_started`
- it now owns shared melody runtime state while [`../game/melody_catalog.gd`](../game/melody_catalog.gd) owns authored melody definitions
- `melody_prompt_requested(request)` is the bridge from gameplay/journal actions into the reusable ordered-confirmation overlay; `AppState` preserves the public validation/completion API while `game/landmark_progression.gd` now mainly owns generic melody-prompt validation/building and StoryEvent world-event bindings own the current landmark-specific completions
- prompt completions now flow back through `complete_prompt_request(request)`, which first offers the request to authored StoryEvent world-event bindings for landmark-specific confirmations such as the Trinity choir chime, the Bi Shan chamber contour, the Long Shan exit route, and the harbor-stage performance, while melody practice still falls back through the compatibility helper
- `save_metadata_changed(metadata)` is the shell-facing signal for title `Continue` state and latest story autosave summary
- composed helper scripts emit `AppState`-owned signals back through bridge methods on `AppState` itself so the public signal contract stays centralized and GDScript static analysis can still verify those signals are live
- `AppState` now owns the one-slot story autosave contract, current safe resume anchor, and the `configure_new_game()`, `configure_continue()`, `configure_free_walk()`, `save_story_autosave()`, `clear_story_autosave()`, and `set_story_resume_checkpoint(...)` bridge methods used by the shell and world scene; `game/story_save_service.gd` owns the active read/write implementation
- `AppState` now owns lightweight story-time state through `story_day`, `world_hour`, and derived `time_of_day`; `game/story_time_service.gd` owns normalization, display labels, authored hour/day/day-phase advancement, and story autosave persistence through `StorySaveService`
- `AppState` also keeps the landmark bridge methods (`activate_landmark_trigger(...)`, prompt-request/completion facades) and resident/audio facades even when helper scripts own the implementation, so legacy direct callers still have a stable bridge while runtime and regression coverage prefer the generic story-subject path
- `AppState` now composes `game/story_event_service.gd` and exposes `describe_story_subject(subject_id, action, context)`, `activate_story_subject(subject_id, action, context)`, `notify_story_world_event(event_id, payload, context)`, `pick_story_candidate(candidates, context)`, `matches_story_conditions(conditions, context)`, and `apply_story_effects(payload, context)` as the shared StoryEvent bridge
- `activate_story_subject(...)` is now the generic interaction entry point for resident talk and all scene-authored `StorySubjectArea2D` world subjects; the current subject taxonomy includes `npc:<resident_id>`, `landmark:<landmark_id>.<trigger_id>`, and `inspectable:<inspectable_id>`
- `activate_landmark_trigger(...)` remains as a compatibility bridge for direct callers, but it now consults the authored StoryEvent landmark bindings first; the current landmark-trigger surface is authored there, and landmark reward handoffs now route through authored StoryEvent world-event bindings as well
- `apply_story_effects(...)` is the shared write path for resident beats and future StoryEvent bindings; current supported effect channels include objective/hint/save-status updates, `season_phase`, story-time effects (`advance_time`, `advance_hours`, `advance_to_time_of_day`, `advance_day`, `story_day`, `world_hour`), landmark unlock/state/reward changes, landmark-progress patch/list updates, melody hint/audio/prompt emission, melody-progress patch/fragment-award updates, journal/shortcut unlocks, `story_flags`, `story_event`, `pin_lead_id`, resident routine overrides, resident routine override clearing, conditional follow-up effects, and story milestones
- `game/storylines/` owns canonical route and route-event authoring, while `game/story_route_graph.gd` owns projection, lead selection, canonical story-event availability checks/blocker reporting, endgame-trigger evaluation, ending-behavior classification, and baseline ending-tone tag generation
- resident dialogue beats and StoryEvent effect payloads must treat `AppState.can_resolve_story_event(...)` / `get_story_event_blockers(...)` as the narrative-availability authority instead of re-authoring route prerequisite logic through custom resident gate ids
- route-score prerequisites are evaluated against an all-route completion snapshot, so cross-route score gates cannot depend on route display order
- story-state bundles include route progress plus available/active leads; mode setup must apply the full bundle so Free Walk clears story leads instead of inheriting stale HUD state
- the app shell and world hint logic may query `AppState.is_journal_unlocked()` and `AppState.build_input_hint(...)` to keep the early tutorial flow and controls text aligned
- world and UI code rely on resident getters for resident ids, definitions, display names, appearance configs, spawn configs, movement configs, behavior configs, ambient speech, resident journal text, and full resident profiles when optional movement metadata is needed
- all resident definitions live in external `.tres` files under `res://game/residents/definitions/`; `ResidentCatalog` loads them at runtime and `include_in_catalog = false` keeps a resource out of the runtime roster
- `interact_with_resident()` checks a resident's `conditional_beats` (priority-sorted, condition-gated) before falling through to the linear `dialogue_beats` spine
- resident conditional gating and StoryEvent conditions may now read `season_phase`, `story_day`, `world_hour`, `time_of_day`, `story_flags`, route state, route score, and endgame-active state
- `resident_routine_override_changed(resident_id, routine_override)` is the world-facing signal for live resident route changes; `get_resident_spawn_config(...)`, `get_resident_movement_config(...)`, and `get_resident_behavior_config(...)` now merge base authored data with any active override, and story autosave persists those overrides through continue/load
- UI code can now rely on melody getters, journal helpers, `build_map_journal_text()`, `get_open_shortcuts()`, `can_practice_melody(...)`, `request_melody_practice(...)`, and `complete_prompt_request(...)` for melody-facing and dependable-route player context
- `ui/screens/journal_overlay.gd` and `ui/screens/player_customization_overlay.gd` are the live consumers of `game/journal_builder.gd`
- HUD and journal code now treat one active lead as the primary player-facing objective while the journal exposes the broader live route list
- UI screens and world integration code rely on those signals and state getters/setters

Governance:

- keep shared cross-screen state here
- do not move scene-local behavior into `AppState` without a strong reason
- if signal names, payload shapes, or key state fields change, update this file and the affected feature docs

## StoryEvent Boundary

Reference:

- [`event_story_system_design.md`](event_story_system_design.md)

Owned by:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/story_event_catalog.gd`](../game/story_event_catalog.gd)
- [`../game/story_event_service.gd`](../game/story_event_service.gd)
- [`../game/resident_interaction_service.gd`](../game/resident_interaction_service.gd)
- [`../game/story_world_reactivity.gd`](../game/story_world_reactivity.gd)

Current contract:

- story-facing world interactions now flow through stable `subject_id + action` pairs instead of route-specific scene callbacks
- `StoryEventService` owns generic context building, shared condition matching, priority-based candidate selection, and shared effect application, while typed route resources under `game/storylines/routes/`, resident data, and existing landmark helpers remain the current canonical source for route/event meaning
- each `StorylineRouteResource` under `game/storylines/routes/` resolves to one `route` definition plus that route's `events`; `StoryRouteGraph` loads that catalog into an instance-local runtime cache, while editor tools continue to rebuild directly from `StorylineCatalog` when authors refresh or edit resources
- route events may depend on events from any other route resource by referencing those event ids in `prerequisites.story_flags_all` or `prerequisites.story_flags_any`
- `game/story_event_catalog.gd` is the authored StoryEvent tree file for the current landmark migration; it now owns the full `melody_landmarks` landmark-interaction subtree
- StoryEvent catalog validation checks authored `story_event` effect references against the typed route-event resources loaded by `StorylineCatalog`, so interaction bindings cannot silently point at missing route facts
- resident conditional beats now resolve through `pick_story_candidate(...)` and apply their side effects through `apply_story_effects(...)` rather than keeping separate copies of condition/effect logic
- typed route resources are now the canonical narrative gate source for route events; cached `StoryRouteGraph.can_resolve_story_event(...)` and `get_story_event_blockers(...)` calls are the shared availability surface consumed by resident dialogue and StoryEvent effect application
- `StorySubjectArea2D` is now the shared world-side subject adapter; `game_main.gd` routes all world-subject interactions through `activate_story_subject(...)`, and `StoryEventService` resolves current `landmark:` and `inspectable:` subjects plus landmark reward world events through the authored catalog before any compatibility fallback path
- non-resident inspect text now resolves through `StoryWorldReactivity.resolve_inspect_result(...)`, which builds stable `inspectable:` subject ids and reuses the shared condition matcher
- resident routine overrides are the first live world-state effect channel driven through the shared StoryEvent boundary; the world scene listens for override changes and reapplies spawn anchor, level, and movement state to live resident actors
- the current route ledger remains the player-facing progression view, while the longer-term goal is still to migrate route families into authored recursive StoryEvent definitions and a published-fact ledger

Governance:

- do not let future route implementations bypass the generic subject/fact model by adding direct route-to-route service calls unless there is a proven ownership need
- prefer optional capability adapters and published facts over hardcoded calls between individual story families

## Weather Runtime Contract

Owned by:

- [`../weather/weather_manager.gd`](../weather/weather_manager.gd)
- [`../weather/weather_runtime.gd`](../weather/weather_runtime.gd)
- [`../scenes/game_main.gd`](../scenes/game_main.gd)

Current contract:

- `WeatherManager` owns the overworld weather preset list, random hold/transition timing, interpolation, runtime weather-rig instancing, and the live application of synced wind settings to registered rain, fog, and cloud-shadow nodes
- the running app owns exactly one `WeatherManager` node; callers resolve it through `WeatherRuntime.get_weather_manager(node)` instead of a Project Settings autoload
- gameplay scenes register weather hosts with `WeatherManager.register_weather_host(...)`, providing attachment parents, a ground-impact spawn layer, and any scene-specific default properties instead of instantiating weather nodes themselves
- the shared default overworld rain/fog/cloud/impact properties now live in [`../weather/overworld_weather_preset.tres`](../weather/overworld_weather_preset.tres), and both [`../scenes/game_main.gd`](../scenes/game_main.gd) and [`../weather/tests/test_weather.gd`](../weather/tests/test_weather.gd) must consume that same resource instead of carrying duplicate inline constant dictionaries
- gameplay scenes may update sync flags and shared wind through `WeatherManager.set_target_sync(...)` and `WeatherManager.set_registered_wind(...)` instead of duplicating per-pass wind propagation logic
- gameplay scenes may use `WeatherManager.set_registered_visibility(...)` for aggregate show/hide, but tunnel suppression and other visibility-policy decisions still stay in `game_main.gd`
- the focused weather sandbox may reuse the same manager for wind-sync behavior while keeping random cycling disabled

Governance:

- keep overworld weather-cycle policy, synced wind application, and runtime weather-rig creation in `WeatherManager`, not in reusable overlay nodes or scene files
- keep scene-specific visibility rules such as tunnel suppression in the owning scene script
- if the registration API or the single-manager runtime assumption changes, update this file and the weather feature docs

## Scene-Graph Lookup Contract

Owned by:

- [`../game/app_runtime.gd`](../game/app_runtime.gd)

Current contract:

- scene-graph systems that need the live player node resolve it through `AppRuntime.get_player(node)`
- the current player contract depends on the active player actor staying in the `"player"` group
- shared UI/progression code should still use `AppState`, not direct player-node lookups, for anything save-relevant or player-facing

Governance:

- keep player lookup lightweight and scene-owned; do not reintroduce a static singleton just to hold the live player pointer
- if the player group contract changes, update this file and `architecture.md`

## World Integration Contract

Owned by:

- [`../scenes/game_main.tscn`](../scenes/game_main.tscn)
- [`../scenes/game_main.gd`](../scenes/game_main.gd)

Current contract:

- `scenes/game_main.gd` maps landmarks plus resident spawn/movement anchors, reacts to controller events, syncs player tunnel context into `AppState`, and delegates route resolution, resident spawning, tunnel context, and debug route drawing to focused helper scripts under `scenes/`
- `scenes/game_main.gd` instantiates `ResidentNPC` actors from `AppState.get_resident_definition(...)` and then applies world-specific spawn, level, and route resolution
- `scenes/game_main.gd` now routes resident talk and `StorySubjectArea2D` world interactions through `AppState.activate_story_subject(...)`, while still owning closest-target selection, world prompt presentation, and fallback generic inspect text
- `scenes/game_main.gd` also owns mapping the live player position onto safe story resume anchors for autosave and continue
- `scenes/game_main.gd` registers overworld weather hosts plus the terrain spawn layer with `WeatherManager`, which instantiates the active rain, fog, cloud-shadow, and ground-impact nodes at runtime
- `scenes/game_main.tscn` keeps the player and resident instances under one shared y-sorted actor layer rooted at `actors`
- player inspect and talk prompts flow from the nearest nearby same-layer resident or landmark cue through controller signals into `AppState`
- `scenes/game_main.gd` listens for `resident_routine_override_changed(...)` and reapplies the shared spawn-anchor, level, and movement pipeline to already spawned residents when story state changes their routine
- landmark naming and location sync depend on known nodes in the main scene
- player tunnel context must only become active after the player reaches the tunnel interior level; overlapping the tunnel footprint on the surface must not count as tunnel entry

Governance:

- keep scene-specific world wiring local to `scenes/game_main.gd` unless it becomes a reusable subsystem; reusable overworld helpers should live under `scenes/`
- document node-path, actor-layer, or spawn-anchor naming assumptions if new systems depend on them

## Low-Poly Building Editor Contract

Moved to the plugin's own docs folder: [`../addons/low_poly_building_editor/docs/contract.md`](../addons/low_poly_building_editor/docs/contract.md).

## Low-Poly 3D Prototype Contract

Owned by:

- [`../terrain/low_poly_terrain_3d.gd`](../terrain/low_poly_terrain_3d.gd)
- [`../terrain/low_poly_world_coordinates_3d.gd`](../terrain/low_poly_world_coordinates_3d.gd)
- [`../terrain/low_poly_art_style_3d.gd`](../terrain/low_poly_art_style_3d.gd)
- [`../architecture/low_poly/low_poly_landmark_proxy_3d.gd`](../architecture/low_poly/low_poly_landmark_proxy_3d.gd)
- [`../characters/human_body_3d.gd`](../characters/human_body_3d.gd)
- [`../assets/characters/boy.glb`](../assets/characters/boy.glb) (default model; `female.glb` and `male.glb` are alternates)
- [`../scenes/tests/test_low_poly_world_3d.tscn`](../scenes/tests/test_low_poly_world_3d.tscn)

Current contract:

- the low-poly 3D prototype remains a sidecar validation lane and must not be wired into `game_main.tscn` until it has green combined smoke tests, accepted visual QA screenshots, a stable interaction contract, an acceptable performance budget, and a written story/resident ownership plan
- `LowPolyWorldCoordinates3D` owns terrain-mask-pixel to 3D XZ conversion plus rough 2D isometric-position to mask-pixel conversion for authored landmark blockouts
- landmark, actor, story-anchor, and future hotspot placement must use `LowPolyWorldCoordinates3D` instead of duplicating grid-centering or isometric conversion math
- `LowPolyTerrain3D` owns optional grayscale heightmap sampling; black maps to `heightmap_min_offset`, white maps to `heightmap_max_offset`, and offsets are added to `land_height`
- when `heightmap_expands_land_to_source` is enabled with an assigned heightmap, the heightmap dimensions become the generated terrain source, sampled cells at or below `water_height` become water, higher mask colors may upgrade cells to street or building-footprint overlays, and mask water does not clip the heightmap source area
- when heightmap expansion is disabled or no heightmap is assigned, mask water remains the water-area source and is drawn flat at `water_height`
- water rendering expands beyond classified water by `water_land_overlap_cells`, defaulting to one adjacent land-cell ring; this is visual-only and must not change terrain kind, land/seabed height queries, collision generation, or placement semantics
- by default, heightmapped terrain is generated as a connected low-poly surface with shared-corner height averaging; expanded heightmap source heights are smoothed before waterline classification, while mask-clipped generation keeps the smoothing pass land-only
- submerged heightmap-expanded cells keep a terrain surface below the flat transparent water plane so the seabed remains visible through `WaterMesh`; dry land and seabed cells share corner-height sampling, and heightmap-expanded shorelines must not draw vertical land-wall `ShorelineMesh` geometry between them
- heightmap file, expansion-mode, and offset edits are manual-apply: assigning the image, toggling `heightmap_expands_land_to_source`, or tuning min/max must not automatically rebuild in the editor; use the exported rebuild control or `rebuild_from_source()`
- height-aware placement must query generated terrain heights through `LowPolyTerrain3D.get_world_surface_height(...)` or `LowPolyTerrain3D.get_sample_cell_height(...)` after rebuild instead of assuming global `land_height`; in heightmap-expanded water these queries currently expose underlying land/seabed elevation rather than visual water-plane height
- the combined low-poly world scene owns actor grounding wiring: each frame it seats the player actor on the solid surface directly beneath it by casting a short downward ray against the physics world (the actor's `collision_mask`), so the actor stands on whatever it is over -- terrain mesh, pier, or any collision-bearing building part -- instead of hovering. It falls back to `LowPolyTerrain3D.get_world_surface_height(...)` only when the ray finds nothing within reach (e.g. heightmap-water cells with no land collision), preserving land/seabed elevation following there. `actor_terrain_clearance` defaults to `0` so the feet rest on the floor rather than floating above it; `HumanBody3D` itself stays terrain-agnostic
- the current five canonical `LowPolyLandmarkProxy3D` nodes are non-interactive visual blockouts snapped to nearby land, not authoritative gameplay hotspots; "non-interactive" means no story/gameplay hotspot, not non-solid -- with `generate_collision` (default `true`) each generated part (wall/body boxes, tower cylinders, and gable roofs) parents a `StaticBody3D`/`CollisionShape3D` on the default layer so the character is physically blocked by the landmark's walls and roof. The collision children are `GENERATED_META` rebuild artifacts freed and rebuilt with their parts
- `HumanBody3D.body_height` and `HumanBody3D.body_radius` are the current low-poly actor shape contract; they update the GLB model scale, capsule collision, bounding box, and ground footprint together
- `HumanBody3D` always renders the GLB character model under `VisualRoot/CharacterModel`; there is no procedural block-mannequin fallback (it was removed along with the contact shadow). The only code-generated geometry left is the optional `DebugBox` bounding-box gizmo and the optional skeleton bone-debug lines
- the default character model is `assets/characters/boy.glb`, with `female.glb` and `male.glb` as interchangeable alternates (same height and `idle`/`walk`/`run` clips); the selected model is scaled by `body_height / character_model_height`, rotated by `character_model_yaw_offset` to face the rig's `+Z` forward, and planted so its lowest rendered point sits at the foot origin (`character_model_auto_ground` plus the manual `character_model_y_offset`)
- `HumanBody3D.use_hair_model` defaults to `true`: when the GLB character model is active it instances `hair_model_scene` (default `assets/characters/spiky_hair.glb`) into a dedicated `HairModel` node under a `HairAttachment` `BoneAttachment3D` bound to the skeleton bone named by `hair_attach_bone` (default `Head`), so hair tracks head animation; `hair_model_scale` / `hair_model_offset` / `hair_model_yaw_offset` tune placement in bone-local space
- `HumanBody3D.draw_skeleton_bones` is a debug toggle (default `false`): when on with the GLB model active it draws the model's `Skeleton3D` as bone lines in a `SkeletonDebug` `ImmediateMesh` under the skeleton, refreshed each frame to track animation, colored by `skeleton_debug_color`; it is a debug aid only and stays hidden in normal play
- locomotion drives the model `AnimationPlayer`: `model_idle_animation` / `model_walk_animation` / `model_run_animation` map to standing/walking/running and loop with a short crossfade; clip names resolve case-insensitively against the imported animation list; optional imported clips beyond `idle`/`walk`/`run` must be validated before being bound to gameplay states
- `HumanBody3D.max_step_height`, `HumanBody3D.floor_snap_distance`, and `HumanBody3D.grounding_speed` tune prototype 3D navigation over floor meshes, including GridMap stair treads; solid wall geometry must still block traversal instead of being bypassed by stair support
- `HumanBody3D` applies gravity (`GRAVITY`, capped by `MAX_FALL_SPEED`) whenever it is airborne and not in a cosmetic jump, so a body spawned or walked off an edge above the floor falls and lands instead of hovering. For a body that has a `controller`, `_physics_process` also runs a vertical-only `_apply_passive_vertical_motion` step on any frame the controller issued no move, so an idle character still settles onto the floor beneath it. Bodies without a controller (manually driven test probes) are exempt so their physics is never double-stepped, and `stop_moving` zeroes only horizontal velocity so the vertical fall continues while idle
- `HumanBody3D` must not run manual stair/floor reacquisition while `m_is_currently_jumping` is active; jump-state grounded checks intentionally return false so repeated visual jumps on stair crests cannot reuse stale stair directions and pull the actor onto the wrong floor sample
- `HumanBody3D` locomotion is conveyed entirely by the GLB model's `idle`/`walk`/`run` animation clips; the actor adds no procedural walk/run bob (the only scripted `VisualRoot` offset is the jump arc). It remains a prototype actor until the 3D asset direction is finalized
- low-poly palette, camera, lighting, and landmark colors should flow through `LowPolyArtStyle3D` presets while the art direction is exploratory
- `LowPolyArtStyle3D` preset field edits are manual-apply: use exported rebuild controls, deliberate rebuild calls, or scene reloads after style changes rather than adding automatic resource-change rebuild behavior

Governance:

- keep prototype placement, style, and validation docs in sync with [`features/low_poly_terrain_3d.md`](features/low_poly_terrain_3d.md) and [`features/low_poly_actor_3d.md`](features/low_poly_actor_3d.md)
- update this contract before treating low-poly landmarks as runtime story subjects or save/resume anchors

## Multi-Level Scene Contract

Owned by:

- [`../common/level_node_2d.gd`](../common/level_node_2d.gd)
- [`../common/level_area_2d.gd`](../common/level_area_2d.gd)
- [`../common/level_registry.gd`](../common/level_registry.gd)
- [`features/multi_level_spaces.md`](features/multi_level_spaces.md)

Current contract:

- every level-aware node must expose a `level_id` for its own level
- every level-aware node may expose additional `level_id` properties such as `level_from`, `level_to`, `level_bottom`, or `level_top`
- `LevelNode2D` resolves its `level_id` either absolutely or relative to the closest level-aware parent
- `LevelArea2D` exposes the same `level_id` contract for reusable `Area2D` gameplay nodes and may optionally resolve relative ids through an explicit `level_context_path`, but scene-owned interactables should normally live under the matching level-aware parent
- reusable room scenes should prefer relative level ids so they do not hardcode runtime level ids
- `LevelRegistry` derives shared runtime floor data from `level_id`
- By default, `LevelRegistry` maps `level_id` to runtime floor data as `physics_atlas_column = level_id`, `z_index = level_id`, and `collision_mask = 1 << (19 + level_id)`
- `LevelRegistry` remains the place to update if a landmark ever needs non-formula level behavior
- `LevelNode2D` resolves a `level_id`, then asks `LevelRegistry` for the corresponding physics-atlas column instead of assuming `level_id == atlas_column`
- actor traversal components resolve their final collision-mask and `z_index` state through the same shared global level data
- level-aware `Area2D` nodes may also sync their runtime `z_index` from the resolved level so interaction-layer checks line up with the shared level model
- visibility masking still depends on authored mask layers plus absolute `z_index` behavior
- tunnel masking may layer additional context rules on top of authored masks, such as requiring the player to be on the tunnel's interior level before hiding ground buildings

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
- Both player and NPC actors use the same shared level-transition helpers, but gameplay systems may still interpret tunnel context differently on top of that shared transition data.

Governance:

- if the shared level derivation rules or the traversal components' `level_id` interface change, update this file and relevant feature docs
- new multi-level spaces should use either absolute or parent-relative exported `level_id` values where a reusable scene or component needs to point at a logical level
- when a reusable `Area2D` needs shared level behavior, prefer `LevelArea2D` or a subclass instead of duplicating level-resolution logic in the leaf node
- when a scene-owned `LevelArea2D` can live under the right `LevelNode2D`, prefer that parentage over pointing back to an external `level_context_path`
- existing portals and stairs outside Bagua Tower may continue to use hand-authored mask values; migration is not required but recommended

## Landmark Progress Contract

Owned by:

- [`../game/app_state.gd`](../game/app_state.gd)
- [`../game/story_subject_area.gd`](../game/story_subject_area.gd) (scene-authored world subject node)

Current contract:

- `AppState.landmark_progress` is a `Dictionary` keyed by landmark id (`piano_ferry`, `trinity_church`, `bi_shan_tunnel`, `long_shan_tunnel`, `bagua_tower`, `festival_stage`)
- each entry is a `Dictionary` with at minimum a `"state"` key: `locked / available / introduced / in_progress / resolved / reward_collected`
- landmark-specific sub-state (e.g. `"harbor_clue_found"` for Piano Ferry, `"cues_collected"` plus `"chime_performed"` for Trinity Church, `"checkpoints_collected"` for Long Shan Tunnel, or `"synthesis_done"` for Bagua Tower) lives inside the same per-landmark entry
- `AppState.landmark_progress_changed(landmark_id, progress)` fires whenever any landmark's entry changes
- `AppState.get_landmark_progress(landmark_id)` and `get_landmark_state(landmark_id)` are the read API
- `AppState.set_landmark_progress(landmark_id, progress)` and `advance_landmark_state(landmark_id, new_state)` are the write API
- `AppState.activate_landmark_trigger(landmark_id, trigger_id, display_name)` now exists as a compatibility bridge for legacy callers; runtime world interaction and regression coverage go through `StorySubjectArea2D` nodes or `AppState.activate_story_subject(...)`, which first offers the interaction to `game/story_event_service.gd` as the stable subject id `landmark:<landmark_id>.<trigger_id>`
- `AppState.melody_hint_shown(text)` fires when a melody-specific StoryEvent effect emits flavour text; the HUD subscribes to display it on-screen without making `StorySubjectArea2D` carry melody-only metadata
- successful landmark interactions may also emit `AppState.landmark_audio_cue_requested(cue_id, context)` so the world scene can play a local motif without relying on `melody_hint_shown` text alone
- `AppState.set_all_landmark_progress(progress)` sets multiple landmarks at once; used by `configure_*` methods
- Resident dialogue beats may carry `"unlock_landmark"` to unlock a landmark when the beat fires, and `"gate"` / `"gate_fallback"` to block a beat until a landmark condition is satisfied
- Resident dialogue beats may carry `"landmark_reward"` to trigger a landmark resolution (fragment award, melody state update, downstream unlocks) when the beat fires
- `StorySubjectArea2D` inherits the shared `LevelArea2D` level fields, so a world subject can resolve its interaction layer from a parent level node or an explicit `level_context_path` without landmark-specific logic; use the explicit context path mainly for scene-internal cross-level placement or other exceptional cases where the hotspot cannot sit directly under its level context
- `game/story_event_catalog.gd` owns the canonical authored world-subject metadata list and presence rules; the `StorySubjectArea2D.subject_id` dropdown reads from that shared catalog, surfaces configuration warnings for unknown ids, and keeps stable world subjects decoupled from whichever StoryEvent currently binds them

Governance:

- keep per-landmark and inspect-surface setup in `StorySubjectArea2D` nodes placed in the landmark or feature scene that owns the hotspot, and keep active resolution logic behind `AppState`'s public API; current landmark interaction beats plus landmark prompt-completion/reward follow-through and world-subject visibility rules live in `game/story_event_catalog.gd`/`game/story_event_service.gd`, while `game/landmark_progression.gd` now mostly supplies generic prompt-building and fallback behavior
- when a trigger must follow a non-ground interaction layer, set its shared level fields instead of hardcoding a separate scene-local z contract
- if a new landmark arc is added, add its id to `_default_landmark_progress()` and `_build_landmark_progress()`, place `StorySubjectArea2D` nodes with the correct stable `subject_id` and level placement in the owning landmark scene, and prefer authored `StoryEvent` subject/world-event bindings plus subject metadata/presence rules before extending any remaining legacy `game/landmark_progression.gd` fallback
- if the landmark state enum changes, update this file and the relevant landmark feature docs
- `StorySubjectArea2D` nodes mirror visibility and targetability from StoryEvent metadata; callers should not own hide/disable decisions directly

## Reusable Module Contracts

### Background Music

Owned by:

- [`../game/bgm_catalog.gd`](../game/bgm_catalog.gd)
- [`../game/bgm_manager.gd`](../game/bgm_manager.gd)
- [`../scenes/game_main.gd`](../scenes/game_main.gd)

Current contract:

- `game_main.gd` owns exactly one scene-local `BgmManager` while gameplay is loaded
- `BgmManager` owns the active `AudioStreamPlayer`, recent-history buffer, commitment window, silence gap timer, and weighted track selection
- `BgmManager` also owns short-lived ducking state through `duck_for_cue(duration)` and `set_ducked(ducked)` so landmark cues and melody prompts can lower BGM without moving BGM ownership into the UI
- `BgmManager` reads shared state from `AppState` through the existing `location_changed` and `melody_progress_changed` signals plus current location/progress snapshots; it does not write shared gameplay state back
- the current V1 context is `location + melody progress` with fixed defaults `time = afternoon`, `season = summer`, and `weather = clear`
- the current seed pool is authored in `BgmCatalog` rather than inferred from directory scanning

Governance:

- if the catalog format changes materially, update this file and the BGM feature docs
- if BGM ownership moves out of `game_main.gd` or begins depending on new `AppState` APIs, update this file, [`architecture.md`](architecture.md), and [`module_map.md`](module_map.md)

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
