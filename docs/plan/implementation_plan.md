# Kulangsu Implementation Plan

This is the canonical implementation plan for the current playable game.

Read `AGENTS.md`, [`../design_brief.md`](../design_brief.md), [`../architecture.md`](../architecture.md), and [`../core_game_workflow.md`](../core_game_workflow.md) before starting a new task.

## Current State

The seasonal multi-route story architecture is now live.

Shipped foundations:

- `season_phase`-driven progression instead of `chapter` as the primary gate
- four canonical routes: family, study, preservation, melody
- one pinned HUD lead plus multi-route journal view
- modular storyline authoring in `game/storylines/`, with route projection and endgame trigger logic in `game/story_route_graph.gd`
- first-pass StoryEvent runtime in `game/story_event_service.gd`, including subject-based resident talk, landmark-trigger routing, and inspectable routing through `AppState`
- first authored StoryEvent tree file in `game/story_event_catalog.gd`, now owning the full `melody_landmarks` interaction spine: ferry harbor clue, Trinity cue/chime, Bi Shan echoes/chamber, Long Shan entry/checkpoints/exit, Bagua synthesis, and the harbor-stage prompt-open
- save/load support for seasonal story state, route state, lead pinning, and endgame state
- first lightweight life-time runtime slice with `story_day`, `world_hour`, derived `time_of_day`, StoryEvent time conditions/effects, journal summary exposure, and autosave persistence
- story-driven resident routine overrides that persist through autosave/continue and affect future projection-based resident configuration; live reapplication to already-spawned 3D actors remains open and is scheduled under Next world-state reactivity
- resident gating against `season_phase`, route state, and `story_flags`
- guarded final-act start with `spring_festival_resolved` as the earliest allowed endgame threshold
- `AppState` composition pattern with extracted helpers for profile, journal, save, landmark progression, resident interaction, audio settings, and story routes
- explicit manual-versus-auto lead presentation plus an in-journal `Auto Lead` clear action
- weather system with manager-owned overworld preset cycling, wind sync, and runtime rig instancing
- shared overworld weather preset resource consumed by both `game_world_3d` and the focused weather sandbox
- BGM weighted selection with 12-track catalog, commitment window, silence gaps, and landmark cue ducking
- landmark audio cues for all five canonical landmarks plus the festival stage
- all 25 resident definitions shipped as external resources under `game/residents/definitions/`
- differentiated ending and departure copy for exam, honest-future, and harbor-performance routes, including soft-ending stay-versus-leave text
- added cross-route resident follow-through across harbor, church, and Bagua districts after winter-memory, preservation, future-choice, second-summer, and resonant-festival beats
- scene-level milestone status feedback for major route events so world-state changes are not only visible in journal text
- harbor, church, and Bagua inspectable surfaces now carry route-state reactivity so non-resident world objects reflect Spring Festival, winter-memory, future-choice, second-summer, and preservation beats

Regression coverage now includes:

- full landmark cue progression
- story autosave and continue
- seasonal route progression outside the landmark spine
- resident interaction gate/trust/autosave coverage
- cross-route resident reactivity coverage
- arbitrary `story_flags` persistence coverage
- override-backed resident profile persistence coverage
- external resident override parity coverage
- BGM lazy catalog validation and location-fallback variety
- production 3D landmark/inspectable subject ids, dimension-neutral interaction
  requests, cross-world subject isolation, and semantic resume-anchor placement
  plus fallback

The low-poly 3D lane is now the production overworld instantiated directly by `main.gd`:

- the terrain pipeline is split into image sampling, cell data, mesh construction, and node/material integration; it supports heightmap or mask-driven land, connected seabed, collision, layered shader-displaced water, and weather-driven wind
- `HumanBody3D`, `BaseController3D`, and `PlayerController3D` mirror the main actor/controller concepts on the XZ plane; the actor uses a premade animated GLB, gravity, native wall and stair-slope movement, and capped dynamic-body pushing
- `LowPolyWorldCoordinates3D`, `LowPolyArtStyle3D`, and `Camera3DController` support coordinate-safe placement, orthographic orbit/zoom, and target-occluder fading
- the Low-Poly Building Editor and versioned `BuildingSpec` pipeline produce editable authored landmarks; Piano Ferry, Trinity Church, and Bagua Tower are instanced in the runtime while both tunnels remain anchors without authored geometry
- the resident factory spawns the full shared roster as locally wandering `HumanBody3D` actors with stable `StorySubject3D` ids and world-anchored speech balloons
- the runtime dispatches through shared story services, resolves semantic resume anchors, and owns shared BGM and landmark-cue playback
- focused terrain, actor, collision, camera-occlusion, environment-interaction, and production-world scenes cover the lane; headless smoke scenes must terminate with process status `0` on success and nonzero on failure
- physical traversal jumping, carrying, deliberate push/pull, sitting, and ladder climbing are now required planned capabilities; none is implemented by the current actor baseline

## Content Reality Check

The architecture and authored content are now much closer together, but route density is still uneven.

Current practical coverage:

- `family_memory` now carries harbor return, church memory, winter revelation, A Po and parent-care reflection, Spring Festival preparation, and aftermath, but still leans heavily on resident talk instead of household scenes
- `study_future` now echoes across Pei, Lin, Min, and Jun, but still needs more lived middle beats between the major turns
- `preservation_inheritance` now spans harbor, Bagua, postcards, and map-making language, but still needs more inspectable and prop-level world response
- `melody_landmarks` remains the richest embodied route and now has a resonant follow-through after the public performance
- final-act text now differentiates the three ending triggers, but the closing movement still happens mostly through overlays rather than bespoke playable scenes

## Architecture Reality Check

`AppStateService` is now the scene-owned atomic snapshot store and the single owner of mutable shared runtime state. Player-profile/costume, story-time, audio/settings, route, StoryEvent, and resident helpers transform detached command state instead of owning mirrored runtime state. `resident_catalog.gd` is a loader/normalizer over external resident resources rather than the main route-content monolith.

Current pressure points:

- `AppStateService` is now an atomic snapshot store. Save migration/mapping lives in a pure codec, file I/O lives in an injectable repository, and `LandmarkProgression` remains an owner-free prompt calculator.
- `StoryEventService` is now live as a shared subject/effect bridge, and `story_event_catalog.gd` now owns the full melody-landmark interaction spine plus its landmark prompt-completion/reward world events, but progression still spans typed storyline route resources, resident resources, the StoryEvent catalog, and `story_world_reactivity.gd` instead of one fuller recursive event definition set plus a published-fact ledger
- StoryEvent catalog validation now checks authored `story_event` effect references against typed route resources, but subject/world-event bindings themselves are still authored in GDScript rather than editor-native resources
- runtime and regression coverage use `activate_story_subject(...)` through production `StorySubject3D` nodes for landmark beats; the direct landmark-trigger compatibility facade has been removed
- nested landmark, melody, resident, route, and endgame payloads remain dictionaries inside the typed top-level snapshot/projection boundary and are candidates for later typing
- missable/transformed moment processing is not implemented yet; the current life-time slice tracks and advances time but does not automatically expire optional beats into missed-state echoes, and Milestone A owns the first completed-versus-missed implementation
- the low-poly 3D runtime now has terrain/water, actor/camera, three authored landmark models plus two tunnel markers, shared-data residents, the complete 15-landmark/5-inspectable `StorySubject3D` set, speech balloons, BGM/cues, and semantic resume anchors; remaining work is tunnel/interior content, routed tunnel residents, richer landmark presentation, and release-performance confirmation
- regression coverage is now strong for landmark, route, resident-interaction, reactivity, autosave, and shared-state ownership flows, but remains lighter around audio-bus integration and richer world-object reactivity

## Delivery View

Plan status was reconciled against repository structure on **2026-07-23** at parent
revision `551d7e72a`. This documentation pass did not rerun the shipped validation
scenes; dated runtime evidence remains with the owning feature or QA record.

Workstreams 0 and 5, the low-poly 3D cutover, and resident-data migration are
complete. Workstreams 1-4 remain content and polish tracks. Workstream 6 is the
required planned character-action track. The accepted tunnel, parity, and release-
performance follow-ups remain later work rather than blockers for the next slice.

### Now: Milestone A — A Po's Household Care Beat And Action Gate

This is the next implementation milestone. It has one playable content slice and
one bounded enabling gate; neither lane may silently expand into a general household
system or an implementation of all five character actions.

Content slice:

- Add one embodied `family_memory` household/courtyard scene near the ferry district,
  positioned between `winter_memory_reveal` and `spring_festival_prepared`.
- Use `family_household_care_seen` as the canonical completed event id. The scene
  should contain an arrival, one small act of care, and one reflective response from
  A Po or a parent, with prop or ambience feedback after resolution.
- Make this the first optional seasonal beat with a transformed absence. If its
  authored phase closes before completion, publish
  `family_household_care_missed` and let the later Spring Festival response use the
  completed-or-missed fact without blocking `spring_festival_resolved`.
- Keep route rewards in StoryEvents. The scene and props emit semantic subjects or
  completion ids and do not write route state directly.

Character-action gate:

- Complete Workstream 6 Phase 0 only: lock the numeric acceptance matrix, inspect
  animation coverage for all three player models, decide carried-object rotation
  input, and approve the first production proof for each capability.
- Lock the next production action slice as the Bagua stewardship ascent: physical
  traversal jump plus recovery followed by one authored ladder connection. This is
  planning approval, not a claim that either action is implemented in Milestone A.

Milestone A exit criteria:

- the household scene is playable through the production Story flow and updates the
  journal, world feedback, autosave, and continue state through semantic commands
- completing and missing the optional beat produce distinct saved facts and later
  Spring Festival text, while both paths preserve main-route continuity
- focused route, StoryEvent, missed-beat, and persistence coverage passes, followed
  by one manual title -> New Game -> household -> journal -> continue check
- Workstream 6 Phase 0's numeric fixtures, input decisions, animation audit, and five
  approved production proof locations are recorded in
  [`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md)

Primary implementation areas:

- `game/storylines/routes/family_memory.tres`
- `game/residents/definitions/`
- `game/story_event_catalog.gd` and `game/story_event_service.gd`
- the authored household/courtyard scene and its `StorySubject3D` nodes
- `scenes/game_world_3d.tscn` / `scenes/game_world_3d.gd`
- route, StoryEvent, persistence, and production-world validations

### Next

1. **Milestone B — Bagua stewardship ascent.** Complete Workstream 6 Phases 1-3:
   shared action/recovery foundation, physical traversal jump, and ladder climbing.
   Integrate them into a short optional Bagua route that strengthens
   `preservation_tower_perspective` without gating the existing route event until
   focused and production-flow checks pass.
2. **Milestone C — Object care actions.** Add carry and deliberate push/pull on the
   shared action foundation, first through one compact Piano Ferry or Trinity
   restoration beat. Sitting follows through one harbor or church listening moment.
3. **World-state reactivity.** Reapply saved resident routine overrides to already-
   spawned 3D residents and extend route response into props, ambience, district
   dressing, and other non-resident surfaces.
4. **Final-act polish.** Turn differentiated ending and departure copy into playable
   closing movement after the embodied route slices above exist.

### Later

- settings/audio-bus and richer world-reactivity validation
- typed migrations for remaining high-traffic dictionary payloads if their defect
  rate justifies the cost
- authored Bi Shan and Long Shan interiors, routed tunnel residents, landmark result
  equality, and a release-export performance repeat
- journal/HUD grouping and identity-focused resident model/material variants when
  content density makes either necessary

### Done

- Workstream 0: AppState decomposition and atomic snapshot ownership
- Workstream 5: typed storyline resources, inspector authoring, route browser,
  editable dependency graph, canonical-source persistence, and editor validation
- low-poly 3D production cutover and removal of the retired 2D overworld
- external resident-definition migration and 3D resident presentation

### Low-Poly 3D Runtime

The low-poly 3D world is the production overworld. Stage 6 records the completed
runtime-direction decision; remaining items below are accepted follow-ups.

Shipped baseline:

- `LowPolyTerrainSampler` turns mask/heightmap images into typed cells; `LowPolyTerrainMeshBuilder` turns those cells into land, seabed, street, footprint, shoreline, layered water, and collision geometry; `LowPolyTerrain3D` owns lifecycle, materials, wind, and placement-height queries
- water uses a flat baked plane for placement semantics but real shader-displaced waves, analytic normals, layered highlights, shoreline overlap, and normalized wind supplied through `LowPolyWaterWindAdapter`
- `HumanBody3D`, `BaseController3D`, and `PlayerController3D` provide camera-relative XZ movement, animated model locomotion, gravity, native stair-slope traversal and static-wall sliding, and capped `RigidBody3D` pushing
- `LowPolyWorldCoordinates3D`, `LowPolyArtStyle3D`, and `Camera3DController` support the production world without scene-local placement math; authored landmark scenes provide runtime massing and collision
- the Low-Poly Building Editor, versioned `BuildingSpec` generation, authored landmark concepts, and `test_environment_3d.tscn` provide the environment-authoring and playable character-interaction review lane
- design-time streets now use an explicit `StreetNetwork3D` graph with stable junction/segment resources, adaptive horizontal curves and vertical profiles, asymmetric cross-sections, dedicated multi-road centre geometry, topology-aware placement/editing, deterministic mask conversion, terrain junction footprints, and legacy Street3D migration compatibility
- three authored landmarks, two tunnel markers, the complete 15-landmark/5-inspectable `StorySubject3D`
  set, the shared resident roster, speech balloons, BGM/landmark cues, and semantic resume anchors are
  assembled by `game_world_3d`
- focused actor, collision, terrain, camera-occlusion, environment-interaction,
  combined-world, and runtime-world scenes form the current validation set

Execution order:

1. **Correctness baseline (shipped guardrail).**
   - Keep actor API, generated collision fixtures, terrain/water, camera occlusion, building loading, and combined-world headless scenes green.
   - Every automated smoke scene must return process status `0` on success and nonzero on assertion failure; a logged `PASS` line alone is insufficient.
   - `test_character_collisions.tscn` is the owner for gravity/landing, static wall blocking, native stair-slope ascent/descent and side blocking, and dynamic rigid-body pushing.
2. **Runtime interaction slice (green for current authored scope).**
   - All five landmark anchors, shared-data residents, stable subject-id dispatch, collision,
     prompt selection, camera readability, and semantic resume fallback are
     assembled in `game_world_3d`.
   - `test_game_world_3d.tscn` now enters resident talk through proximity
     selection and the player controller's inspect signal rather than calling
     `AppState` directly.
   - Resident dispatch asserts the expected dimension-neutral result and core progression state. The smoke also asserts the exact 15 landmark and 5 inspectable production subject ids and their shared request contract.
3. **Visual-style acceptance (green).**
   - Tune camera, projection, follow offset, palette, lighting, restrained wave depth, terrain chunkiness, building scale, actor readability, and camera-relative movement using the interaction slice plus combined world.
   - Store fixed-camera evidence under `design/qa/low_poly_3d/`: `world_overview.png`, `player_scale.png`, `landmark_approach.png`, `camera_occlusion.png`, and `water_shoreline.png`.
   - The visual gate requires nonblank frames, readable player silhouette, recognizable landmark approach, legible water/seabed layering, successful occluder fade, no incoherent overlap, and a dated acceptance note in the same folder.
   - `capture_game_world_3d_qa.tscn` generated the complete set at 2880×1620 physical pixels; the dated acceptance note records each accepted view.
4. **Performance acceptance (diagnostic green; release repeat open).**
   - Record renderer, build type, resolution, hardware, scene revision, and measurement method in `design/qa/low_poly_3d/performance.md`.
   - At `1920 x 1080`, after a 5-second warm-up over a 60-second interaction-slice run, target p95 frame time at or below `16.7 ms`, worst sustained frame time at or below `33.3 ms`, no more than `500` visible draw calls, no more than `750,000` visible triangles, peak process memory below `1 GiB`, and a cold terrain rebuild below `3 seconds`.
   - If a target is missed, record the exception and approved tradeoff explicitly; “looks acceptable” is not a passing measurement.
   - The reproducible standalone Metal editor-debug run with cycling 3D weather passed every numeric
     budget: 14.963 ms p95, 20.420 ms worst, 92 max draw calls, 231,166 max primitives,
     264.98 MiB video memory, 140.50 MiB static memory, and a 534.52 ms cold terrain rebuild at
     2880×1620 physical pixels.
     `performance_latest.json` contains the raw 60-second capture and visibility variants.
   - Repeat the same runner through a release export to satisfy the build-type formality; the prior
     1,222 embedded-editor draw-call estimate was not reproduced and is superseded.
   - **Accepted 2026-07-06 for the runtime-direction decision.** Every numeric budget passes with
     margin on the standalone Metal diagnostic capture, so the performance gate is accepted for the
     cutover; the release-export repeat is a recorded residual confirmation, not a blocker (an
     approved tradeoff per the "record the exception" rule above). Release builds strip the
     debug-server overhead, so the release numbers are expected to be no worse than the diagnostic.
5. **Story/resident/save ownership acceptance (green for current runtime scope).**
   - Follow [`../features/low_poly_3d_integration.md`](../features/low_poly_3d_integration.md): the 3D scene owns spatial adapters, existing story services own rules/effects, `AppState` owns shared progression/save data, and resident definitions remain dimension-neutral data.
   - Controller/coordinator resident dispatch, resident result/state parity, semantic resume fallback, and the exact production set of 15 landmark plus 5 inspectable subjects are green. Tunnel-resident routing/visibility remains open. Player profiles map adult masculine/feminine and teen frames to the male/female/boy GLBs.
6. **Runtime-direction decision — DECIDED 2026-07-06: replace the 2D overworld.**
   - Outcome: the low-poly 3D overworld (`scenes/game_world_3d.tscn`) replaces the 2D overworld as
     the runtime. `main.gd` now instantiates it directly; the `USE_3D_OVERWORLD` toggle and the
     `game_main.tscn` preload are removed.
   - Evidence linked: correctness (`scenes/tests/test_game_world_3d.tscn` green — world build, spawn,
     five landmark anchors, story subjects, controller/coordinator resident talk dispatch, resume anchor
     + fallback, interaction contract); visual acceptance (all five fixed-camera PNGs in
     `design/qa/low_poly_3d/` plus the dated acceptance note); performance (stage 4 diagnostic passes
     every budget); full-shell integration (title → New Game → traveler setup → 3D overworld with HUD,
     story progression, journal gating, autosave, 0 errors); interaction contract and ownership per
     [`../features/low_poly_3d_integration.md`](../features/low_poly_3d_integration.md).
   - Accepted as post-cutover follow-ups (explicit tradeoffs, project-owner decision): tunnel interior
     geometry (Bi Shan / Long Shan remain marker anchors) and the release-export performance repeat. The two tunnels are traversable-as-anchors but not yet
     walkable interiors; this is a known, accepted gap at cutover.
   - Execution: the hard-cutover sequence is recorded in [`low_poly_3d_replacement.md`](low_poly_3d_replacement.md).
     The runtime flip, legacy 2D character/NPC deletion, 3D UI preview migration, Universal LPC
     runtime renderer/addon removal, final 2D world/landmark/terrain/weather residual cleanup, and
     canonical doc sweep are complete. The third-party LPC generator remains a tracked submodule for
     offline asset-generation and licensing reference; the production runtime does not depend on it.

Open art/content decisions:

- validate optional character clips beyond `idle`/`walk`/`run` before mapping them to gameplay states
- visually tune the shipped street-network curve/profile defaults and remaining building-footprint sampling after island-scale editor review
- decide whether resident identity needs additional model/material variants;
  player body-frame/presentation mapping now uses whole-model male/female/boy
  GLB swaps

Primary files:

- `terrain/low_poly_terrain_3d.gd`
- `terrain/low_poly_terrain_sampler.gd`
- `terrain/low_poly_terrain_mesh_builder.gd`
- `terrain/low_poly_terrain_cell.gd`
- `terrain/low_poly_art_style_3d.gd`
- `terrain/low_poly_postcard_diorama_style.tres`
- `terrain/low_poly_world_coordinates_3d.gd`
- `terrain/low_poly_water_wind_adapter.gd`
- `resources/materials/water_3d.gdshader`
- `scenes/tests/test_low_poly_terrain_3d.tscn`
- `scenes/tests/test_game_world_3d.tscn`
- `scenes/tests/test_camera_3d_occlusion.tscn`
- `scenes/tests/test_environment_3d.tscn`
- `characters/human_body_3d.gd`
- `assets/characters/male.glb` (default; `boy.glb`, `female.glb` alternates)
- `characters/control/base_controller_3d.gd`
- `characters/control/player_controller_3d.gd`
- `characters/tests/test_human_body_3d.tscn`
- `characters/tests/test_character_collisions.tscn`
- `docs/features/low_poly_terrain_3d.md`
- `docs/features/low_poly_actor_3d.md`
- `docs/features/low_poly_3d_integration.md`

### Completed Resident Migration

- all resident definitions live as external `.tres` resources
- all production resident actors use `HumanBody3D`, `ResidentController3D`, and `ResidentFactory`
- compatibility appearance keys remain authored, while `CharacterModelCatalog3D` selects integrated GLB models

## Workstream 1: Route Content Depth

First-pass shipped outcome:

- `family_memory` now has explicit A Po and parent-care reflection after winter, plus a Spring Festival aftermath beat
- `study_future` now keeps sounding across church and harbor residents after the future choice and second-summer release
- `preservation_inheritance` now reaches beyond Bagua's first perspective beat into postcard and map-stewardship reactions
- `melody_landmarks` now has a softer resonant follow-through after the harbor performance

Still open:

- deliver Milestone A's embodied `family_household_care_seen` scene and its
  `family_household_care_missed` transformed-absence path
- add more embodied household, festival, and district scenes so route depth is not carried mostly by talk beats
- spread the mid-route beats across more playable spaces and smaller turns instead of relying on a handful of major resident conversations

Primary files:

- `game/storylines/routes/`
- `game/residents/definitions/`
- `game/story_event_catalog.gd`
- authored production scenes and `StorySubject3D` nodes
- `scenes/game_world_3d.tscn`
- `scenes/game_world_3d.gd`
- `docs/story/summer_of_piano_island_story_framework.md`
- `docs/core_game_workflow.md`

## Workstream 2: World-State Reactivity

First-pass shipped outcome:

- new conditional beats now react to winter-memory, Spring Festival, future-choice, second-summer, preservation, and resonant-festival state across ferry, church, and Bagua districts
- `scenes/game_world_3d.gd` surfaces selected route-event resolutions as world-status feedback instead of leaving those turns only in journal state
- route-aware inspectables at Piano Ferry, Trinity Church, and Bagua Tower now carry non-resident world reactivity alongside dialogue follow-through
- first-pass StoryEvent routing now unifies resident talk, inspectable resolution, shared condition matching, and saved resident routine-override configuration behind the `AppState` story-subject bridge
- route progress now changes more of what the island feels like without requiring landmark-only progression

Still open:

- extend route-state changes into inspectables, props, ambient audio, district dressing, and more non-resident surfaces
- reapply changed resident routine overrides to already-spawned 3D actors instead
  of waiting for a future spawn or scene reload
- move landmark subject/world-event bindings toward typed StoryEvent resources, or keep expanding validation so authored bindings, route events, subject metadata, and resident effects cannot drift silently
- keep widening cross-district follow-through so major anchors feel visible outside the specific resident who resolved them

Primary files:

- `game/residents/definitions/`
- `game/story_event_service.gd`
- `game/story_world_reactivity.gd`
- `game/world/story_interaction_coordinator.gd`
- `architecture/piano_ferry/piano_ferry_stylized_3d.tscn`
- `architecture/trinity_church/trinity_church_stylized_3d.tscn`
- `architecture/bagua_tower/bagua_tower_stylized_3d.tscn`
- `scenes/game_world_3d.gd`

## Workstream 3: Final-Act And Ending Polish

First-pass shipped outcome:

- ending and departure overlays now have trigger-specific title, summary, and departure language for exam, honest-future, and harbor-performance runs
- soft endings now present explicit stay-versus-leave text instead of only a generic continue prompt
- route emphasis and expanded tone tags now feed the final summary language

Still open:

- turn more of the final-act and departure texture into playable closing movement rather than leaving it mostly in overlays
- keep sharpening trigger-specific aftermath and ferry framing once more embodied content exists to support it

Primary files:

- `ui/screens/ending_overlay.gd`
- `ui/screens/departure_overlay.gd`
- `game/story_route_graph.gd`

## Workstream 4: Journal And HUD Polish

First-pass shipped outcome:

- the HUD now distinguishes manual versus automatic pinned-lead state
- the journal now shows lead-selection mode, route emphasis, richer per-route counts, and lead-control guidance
- the `Auto Lead` action now makes manual lead clearing explicit instead of leaving it implied

Still open:

- decide whether later route-sectioning, icons, or other stronger visual grouping would help once more route content lands
- keep tuning wording and density as the ledger grows so readability does not slip

Primary files:

- `ui/screens/game_hud.gd`
- `ui/screens/journal_overlay.gd`
- `ui/screens/journal_overlay.tscn`
- `game/journal_builder.gd`

## Completed Workstream 5: Storyline Editor Workflow, Content Tooling, And Test Growth

Status: complete for its defined authoring-workflow exit criteria. Future validation
growth belongs to the Later queue or to the feature that introduces a new schema or
runtime behavior; it is not a reason to keep the editor workflow itself active.

First-pass shipped outcome:

- per-route storyline resources now live under `game/storylines/routes/`, so adding or editing a route no longer requires touching the central route graph
- added focused route-reactivity coverage in `game/tests/story_routes/test_story_reactivity.tscn`
- added focused StoryEvent bridge coverage in `game/tests/story_routes/test_story_event_service.tscn`
- added arbitrary-flag plus override-backed resident profile persistence coverage in `game/tests/persistence/test_story_state_persistence.tscn`
- kept the existing seasonal-route, resident-interaction, and autosave regressions green after the content pass

Phases 1–3 shipped:

- Phase 1 — typed Resource schema (schema scripts have since moved into the `addons/storyline_editor` submodule under `resources/`; the parent keeps the authored data and the `storyline_editor/*` project settings):
  - `storyline_ending_tone_rule.gd` — `StorylineEndingToneRule`
  - `storyline_event_resource.gd` — `StorylineEventResource` with `to_dict()` and `validate()`
  - `storyline_route_resource.gd` — `StorylineRouteResource` with `to_storyline_dict()` and `validate()`
  - `StorylineCatalog` now loads only `.tres` files from the configured routes directory (`game/storylines/routes/` in this project) as the canonical source
  - `StorylineCatalog.build_definition_bundle()` builds route definitions, event definitions, and display order in one pass so runtime `StoryRouteGraph` instances can cache that bundle instead of reloading route resources during normal progression refreshes
- Phase 2 — inspector-first workflow:
  - `@tool` `validate()` methods on all three resource classes check for empty ids, duplicate event ids within a route, invalid `phase_window` values, and missing `ending_behavior` on endgame events, while project-wide prerequisite existence checks remain in the editor tooling so valid cross-route dependencies are not treated as route-local warnings
  - `addons/storyline_editor/storyline_validator_inspector_plugin.gd` — `EditorInspectorPlugin` that shows a validation-warning panel which auto-refreshes when inspector edits change route or event validation status, listens to normal inspector property edits so browser warnings and inspector status messages update immediately, swaps `StorylineEventResource.phase_window` editing away from the raw array widget into an inline Phase Window panel that stays adjacent to `season_phase` in the normal property order, filters out already-selected season phases, and disables `Add Element` once all authorable phases are chosen, swaps `story_flags_all` / `story_flags_any` editing away from raw string arrays into a route-rooted event picker that mirrors the storyline browser and keeps those `All` / `Any` dependencies synchronized with graph/browser refreshes, and swaps `StorylineRouteResource` event creation away from raw array editing into a Route Events panel that generates unique default ids like `<route_name>_new_event_1`, confirms before deleting events, and refreshes the storyline browser immediately
- Phase 3 — route browser dock:
  - `addons/storyline_editor/storyline_route_browser.gd` — Scene/Import-stack dock with one combined storyline tree whose top-level rows are routes and whose child rows are route events; the plugin now registers this browser through Godot's editor-managed `EditorDock` API so the editor restores its remembered Scene/Import placement cleanly from startup instead of relying on the older `add_control_to_dock()` path; it also surfaces project-wide missing-prerequisite validation warnings, provides a `+ New` scaffold action for `StorylineRouteResource` files, and uses a selection-driven `Delete` action that confirms before deleting the selected route's authored resource files or the selected event from its canonical typed route resource while clearing any now-deleted inspector selection
  - selecting a route row emits an inspector-edit request so the plugin opens that `StorylineRouteResource` in the Inspector; selecting an event row does the same for the backing `StorylineEventResource`, while double-clicking an event still emits `event_show_in_graph_requested` to scroll and highlight the node in the graph editor

Phase 4 shipped (first pass):

- `addons/storyline_editor/` — GraphEdit-based dependency view added as an editor bottom panel
- reads live data directly from `StorylineCatalog`; events from all four typed route resources are shown as color-coded GraphNodes
- prerequisite edges (`story_flags_all` / `story_flags_any`) are drawn as directed connections; cross-route dependencies visible in "All routes" mode
- events are laid out in columns by topological depth (longest prerequisite chain), sorted within each column by route display order
- per-route filter, Refresh button, and graph-first authoring flow without a redundant in-panel details pane; event inspection/editing now happens through the Inspector when a node is selected
- dependency edges are now editable in the graph: each node exposes separate `All` and `Any` input slots, so connecting to `All` writes `story_flags_all`, connecting to `Any` writes `story_flags_any`, and dragging either end of an existing connection disconnects it from the targeted bucket
- selecting a graph node now resolves the backing `StorylineEventResource` into the Inspector so authors can edit event properties directly from the graph, and graph edits save directly back to the canonical typed route resource for the target event
- graph edits emit a catalog refresh so the route browser updates its source badge and event tree without requiring a manual dock reload, and structural route/event changes from the browser or route-event inspector panel now refresh the graph's route filter and visible nodes without a manual graph reload
- manual graph layout now persists in the checked-in `game/storylines/storyline_graph_layout.cfg` file instead of a per-user-only editor cache, so node arrangement changes can be reviewed and committed alongside route edits, and the graph toolbar can explicitly re-run automatic layout for the currently visible nodes

Satisfied exit criteria for this workstream:

- authors can create and edit a storyline in the Godot editor without changing `story_route_graph.gd` or hand-editing raw GDScript dictionaries
- cross-route event dependencies are selectable and validated from the editor
- the runtime, journal, and autosave systems keep reading one canonical storyline source of truth
- any later graph editor writes back to that same source of truth instead of inventing a separate graph-only format

Primary files:

- `addons/storyline_editor/storyline_catalog.gd` (schema/loader now addon-owned)
- `game/story_route_graph.gd`
- storyline resource classes under `addons/storyline_editor/resources/`
- editor plugin under `addons/storyline_editor/`
- `game/tests/story_routes/test_story_reactivity.gd`
- `game/tests/persistence/test_story_state_persistence.gd`
- `game/tests/story_routes/test_story_routes.gd`
- `game/tests/persistence/test_story_autosave.gd`

## Workstream 6: Required Character Action Expansion

Status: planned. The production actor currently has the shipped locomotion baseline
only; none of the five capabilities below should be described as implemented until
its focused and production-flow validations pass.

The full ownership, input, compatibility, recovery, animation, phase validation, and
completion contract now lives in
[`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md). Keep that
feature document and the focused fixtures authoritative for engineering detail; this
plan owns only delivery order and milestone status.

Delivery order:

0. Phase 0 tuning/content/animation gate — active inside Milestone A
1. shared physics, action-state, world-interaction, animation, and recovery foundation
2. physical traversal jump and recovery
3. ladder climbing
4. carrying
5. deliberate push/pull
6. sitting
7. production integration and hardening

Milestone B owns Phases 1-3. Milestone C owns Phases 4-6. Phase 7 closes the
workstream only after every capability has a focused automated fixture, one authored
production use, a manual production-flow check, consistent input/cancellation/camera
behavior, and accepted animation coverage or an approved fallback for all three
player models.

No action may become required story progress until its focused and production-flow
checks pass. Physical components publish only semantic completion ids; `AppState`
must never own transient locomotion, collision, carried-object, ladder, push/pull,
seat, or recovery state.

## Completed Workstream 0: AppState Decomposition And Architecture Cleanup

Shipped outcome:

- `AppStateService` owns one typed canonical `AppStateSnapshot` and one cached `AppStateProjection`; every top-level command commits once, emits one `state_committed` change set, and requests at most one autosave
- route, StoryEvent, and resident logic run against detached transitions and never retain the live store, emit public state signals, or perform file I/O; the former runtime ports and `runtime_*` forwarding surface have been removed
- canonical player-profile/costume, story-time, runtime-settings, checkpoint, and progression values live only in the snapshot; chapter/time labels, fragments, routes/leads, display lists, costume unlocks, and ending summary are derived projection data
- `StorySaveCodec` owns V1-to-V2 migration and canonical-only V2 mapping, while `StorySaveRepository` owns injectable file I/O. Existing V1 files remain untouched until the next successful normal autosave
- production shell, HUD, journal, settings, BGM, world integration, resident spawning, story subjects, and customization code now consume detached projections or semantic commands instead of raw AppState fields and field-specific signals
- the weather cycle now lives in `weather/weather_manager.gd` and applies to the production `WeatherRig3D`; focused presentation validation lives in `weather/tests/capture_weather_3d.tscn`
- all resident definitions now live as external resources under `game/residents/definitions/`, with `resident_catalog.gd` kept as the loader/normalizer bridge

Verification now in repo:

- `game/tests/cue_progression/test_cue_progression.tscn`
- `game/tests/persistence/test_story_autosave.tscn`
- `game/tests/story_routes/test_story_routes.tscn`
- `game/tests/npc_system/test_resident_interaction.tscn`
- `game/tests/npc_system/test_resident_catalog_external_defs.tscn`
- `game/tests/state/test_app_state_ownership.tscn`
- `game/tests/state/test_app_state_snapshot_store.tscn`

## Deferred Design Questions

### High-Impact (affect significant architecture)

1. **Typed Resource Migration**: Whether to introduce `Resource` subclasses for high-traffic dictionary payloads (landmark progress, melody progress, autosave) to catch key-typo bugs at parse time
2. **Route State Visibility**: Whether to expose more route state directly in the world instead of mostly in dialogue and journal text

### Medium-Impact (add content or modes)

3. **Additional Routes**: Whether to add more non-landmark routes beyond the current four
4. **Additional Endgame Triggers**: Whether to add more major-event endgame triggers after the current structure settles
5. **Post-Ending Wandering**: Whether to add more authored wandering content after soft endings without introducing a separate after-ending mode

### Low-Impact (cleanup/refinement)

6. **Profile Facade Collapse**: Whether to collapse the player profile facade by exposing the profile service directly to UI consumers
