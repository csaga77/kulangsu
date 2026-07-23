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
- first bounded story-moment ledger policy for the Winter household-care window,
  including exclusive completed/missed facts, load normalization, terminal missed
  route projection, journal treatment, and care-versus-regret ending texture
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
- harbor, church, Bagua, and A Po household inspectable surfaces now carry route-state reactivity so non-resident world objects reflect Spring Festival, winter-memory, household care or absence, future-choice, second-summer, and preservation beats

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

- `family_memory` now carries harbor return, church memory, winter revelation, one
  embodied A Po household-care scene with a transformed missed path, Spring
  Festival preparation, and aftermath; it still needs more embodied family and
  district scenes beyond this first slice
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
- the first bounded missable/transformed moment is implemented for household care;
  later moments still need explicit ledger definitions and authored echoes instead
  of suffix conventions or a general runtime registry
- the low-poly 3D runtime now has terrain/water, actor/camera, three authored landmark models plus two tunnel markers, the A Po household courtyard, shared-data residents, the complete 17-landmark/6-inspectable `StorySubject3D` set, speech balloons, BGM/cues, and semantic resume anchors; remaining work is tunnel/interior content, routed tunnel residents, richer landmark presentation, and release-performance confirmation
- regression coverage is now strong for landmark, route, resident-interaction, reactivity, autosave, and shared-state ownership flows, but remains lighter around audio-bus integration and richer world-object reactivity

## Delivery View

Plan status was reconciled against the integrated Milestone A implementation on
**2026-07-23**. The focused route, state, persistence, StoryEvent, reactivity,
storyline-resource, and production-world scenes passed with process status `0`.
The dated pre-refactor character-action baseline remains recorded in
[`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md).

Workstreams 0 and 5, the low-poly 3D cutover, and resident-data migration are
complete. Workstreams 1-4 remain content and polish tracks. Workstream 6 is the
required planned character-action track. The accepted tunnel, parity, and release-
performance follow-ups remain later work rather than blockers for the next slice.

### Now: Milestone A — Implemented; Manual Visual Acceptance Pending

The playable content slice, story-moment ledger, automated coverage, and bounded
Workstream 6 Phase 0 gate are implemented. The remaining Milestone A closure work
is the fixed-fixture and New Game production-flow review listed in the exit
criteria; until that visual review is accepted, Milestone B remains queued rather
than active. This milestone does not introduce a general household system or
implement any of the five planned character actions.

Content slice:

- Add one embodied `family_memory` household/courtyard scene near the ferry district,
  positioned in the Winter window after `winter_memory_reveal`.
- Use `family_household_care_seen` as the canonical optional route-event id. It is
  available only while `winter_memory_reveal` is true,
  `spring_festival_prepared` is false, and `season_phase` is `winter`. The scene
  should contain an arrival, one small act of care, and one reflective response from
  A Po or a parent, with prop or ambience feedback after resolution.
- Use resolution of `spring_festival_prepared` as the exact window-closing trigger.
  Do not infer expiry from elapsed real time, a hidden day count, or a later generic
  season transition. If the care event is still unresolved in the same detached
  transition that resolves the closing trigger, publish
  `family_household_care_missed` before rebuilding route projection and autosaving.
- Keep `spring_festival_prepared` and `spring_festival_resolved` independent of both
  care outcomes. The optional beat changes later texture; it never blocks the main
  family route or ending access.
- Keep route rewards in StoryEvents. The scene and props emit semantic subjects or
  completion ids and do not write route state directly.

Locked story-moment contract:

- Add a parent-owned, bounded `StoryMomentLedger` policy over canonical
  `AppStateSnapshot.story_flags`; do not introduce a second mutable state owner.
  Its first and initially only definition is `family_household_care`, mapped to
  route `family_memory`, completed event `family_household_care_seen`, missed fact
  `family_household_care_missed`, opener `winter_memory_reveal`, Winter phase, and
  closer `spring_festival_prepared`. Definitions are explicit; suffix matching or
  arbitrary runtime registration is out of scope.
- Normalize the ledger inside the existing detached `AppStateTransition`, after
  authored command effects and story-flag normalization but before projection,
  change-set construction, autosave, and queued-event delivery. For a live command,
  preserve any terminal outcome already present in the transition's base snapshot;
  if the base has no outcome and the command produces both facts, completed wins.
  The closer publishes missed only when neither the base nor working snapshot has a
  terminal outcome. Repeating completion, expiry, load normalization, or
  normalization itself must be a no-op after the first terminal outcome.
- Run the same normalizer when a save is decoded and resumed. Saves from before the
  ledger keep the moment open when the opener is resolved and the closer is not;
  saves at or beyond `spring_festival_prepared` acquire the missed fact when neither
  outcome exists; seen and missed saves retain their outcome; conflicting old data
  deterministically normalizes to seen. The facts remain in the existing
  `story_flags` save payload, so this slice does not need a parallel save field.
- Extend route projection so a missed alternative closes its mapped route event.
  `family_household_care_seen` must disappear from available and blocked leads,
  appear in `missed_beat_ids`, count as terminal when deriving route state, and add
  no completion score. The seen path remains in `resolved_beat_ids` and earns its
  authored score. The journal must distinguish one missed optional beat from a
  blocked beat.
- Make both facts available to later consumers through normal StoryEvent condition
  matching. Spring Festival dialogue must have seen and missed variants; the
  household prop/ambience state must retain a warm/cared-for versus absent/untended
  distinction; ending tone/summary projection must add care versus regret texture
  without changing endgame eligibility.

Character-action gate:

- Complete Workstream 6 Phase 0 only. Record accepted values and their fixture
  geometry in [`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md)
  for the full numeric matrix: jump obstacle clearance and arc; gap width; landing
  width and recovery; input buffering and edge forgiveness; air control and ceiling
  rejection; ladder mount/dismount alignment, climb speed, endpoint clearance, and
  blocked-exit recovery; contextual action and pickup ranges; light/medium carry
  movement values plus attachment and doorway clearances; push/pull alignment,
  speed, path bounds, and blockage; object-placement reach, clearance, and
  tolerances; seat entry/exit alignment and clearance; and player/object
  out-of-bounds recovery thresholds.
- Record one input-and-cancellation decision table for traversal jump, ladder, carry,
  push/pull, and sit. It must name entry and continued-control inputs, completion,
  explicit cancel/exit, `Esc` precedence, incompatible-mode rejection, and
  pause/recovery/unload cleanup, and must decide whether carried-object rotation has
  a dedicated input, prompt, behavior, and test or remains unsupported.
- Audit `male.glb`, `female.glb`, and `boy.glb` against every required locomotion and
  action phase: idle/walk/run, takeoff/airborne/landing, ladder
  mount/climb/dismount, carry idle/walk/place, push, pull, sit enter/idle/exit, and
  fall/recovery. Record the exact accepted clip or an explicitly approved fallback
  for every model-and-phase cell; the presence of an imported clip alone is not
  acceptance.
- Replace the five candidate production locations with one approved proof record per
  capability. Each traversal-jump, ladder, carry, push/pull, and sit record must name
  the exact production scene, semantic completion id, required geometry, and manual
  production-flow check.
- Before Phase 1 refactors actor behavior, capture the dated passing actor,
  collision, environment, and production-world baseline from
  `test_human_body_3d.tscn`, `test_character_collisions.tscn`,
  `test_environment_3d.tscn`, and `test_game_world_3d.tscn`.
- Lock the next production action slice as the Bagua stewardship ascent: physical
  traversal jump plus recovery followed by one authored ladder connection. This is
  planning approval, not a claim that either action is implemented in Milestone A.

Milestone A exit criteria:

- the household scene is playable through the production Story flow and updates the
  journal, world feedback, autosave, and continue state through semantic commands
- completing and missing the optional beat produce exclusive, idempotent saved facts
  plus distinct Spring Festival dialogue, prop/ambience state, journal treatment,
  and ending texture, while both paths preserve main-route continuity
- route tests cover opening only after `winter_memory_reveal`, closing exactly on
  `spring_festival_prepared`, no stale available/blocked lead after a miss, no
  completion score for a miss, and unchanged access to
  `spring_festival_resolved`
- state and persistence tests cover one detached commit/autosave for expiry,
  repeated normalization, repeated completion/close commands, malformed dual-fact
  normalization, seen/missed save round trips, and pre-ledger saves on both sides of
  the closing trigger
- StoryEvent/reactivity tests cover both later dialogue branches, both saved
  prop/ambience branches, and both ending-tone projections
- automated coverage is followed by two manual title -> Continue checks from fixed
  fixtures: one save inside the open Winter window and one legacy save after
  `spring_festival_prepared`; also play New Game -> winter reveal -> household ->
  journal -> continue and New Game -> winter reveal -> festival preparation ->
  journal -> continue to inspect both outcomes in the production world
- Workstream 6 Phase 0's complete numeric matrix, action-by-action input/cancel
  table, three-model clip/fallback matrix, five exact production-proof records, and
  dated pre-refactor baseline are recorded in
  [`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md)

Automated status on **2026-07-23**: satisfied. Manual status: pending the two fixed
title -> Continue fixtures and the completed-versus-missed New Game production
playthroughs above.

Primary implementation areas:

- `game/storylines/routes/family_memory.tres`
- new parent-owned `game/story_moment_ledger.gd`
- `game/app_state.gd`, `game/app_state/app_state_transition.gd`,
  `game/app_state/app_state_reducer_context.gd`,
  `game/app_state/app_state_projection.gd`, and
  `game/app_state/story_save_codec.gd`
- `game/story_route_graph.gd` and `game/journal_builder.gd`
- `game/residents/definitions/`
- `game/story_event_catalog.gd`, `game/story_event_service.gd`, and
  `game/story_world_reactivity.gd`
- the authored household/courtyard scene and its `StorySubject3D` nodes
- `scenes/game_world_3d.tscn` / `scenes/game_world_3d.gd`
- `game/tests/story_routes/test_story_routes.*`,
  `game/tests/story_routes/test_story_event_service.*`,
  `game/tests/story_routes/test_story_reactivity.*`,
  `game/tests/state/test_app_state_ownership.*`,
  `game/tests/persistence/test_story_state_persistence.*`,
  `game/tests/persistence/test_story_autosave.*`, and
  `scenes/tests/test_game_world_3d.*`

### Next

1. **Milestone A manual acceptance.** Review the open-window and legacy
   post-closer Continue fixtures, then inspect both New Game household outcomes,
   journal state, saved continuation, and cared-for/untended world presentation.
2. **Milestone B — Bagua stewardship ascent.** Complete Workstream 6 Phases 1-3:
   shared action/recovery foundation, physical traversal jump, and ladder climbing.
   Integrate them into a short optional Bagua route that strengthens
   `preservation_tower_perspective` without gating the existing route event until
   focused and production-flow checks pass.
3. **Milestone C — Object care actions.** Add carry and deliberate push/pull on the
   shared action foundation, first through one compact Piano Ferry or Trinity
   restoration beat. Sitting follows through one harbor or church listening moment.
4. **Milestone D — Character-action production hardening.** Complete Workstream 6
   Phase 7 after Phases 1-6 have passed their focused and production-use gates.
   Disable story advancement for every physical action in `Free Walk`,
   deterministically settle actions and affected objects during pause, recovery, and
   scene unload, finish contextual hints and consistent input/cancel/camera behavior,
   and run the full title, New Game, Free Walk, and overlay flows. Milestone D is
   the sole Workstream 6 closure gate: it passes only when all five actions have
   focused automated fixtures, an authored production use, a manual production-flow
   check, and accepted animation coverage or an approved fallback for all three
   player models.
5. **World-state reactivity.** Reapply saved resident routine overrides to already-
   spawned 3D residents and extend route response into props, ambience, district
   dressing, and other non-resident surfaces.
6. **Final-act polish.** Turn differentiated ending and departure copy into playable
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
- three authored landmarks, two tunnel markers, A Po's household courtyard, the
  complete 17-landmark/6-inspectable `StorySubject3D` set, the shared resident
  roster, speech balloons, BGM/landmark cues, and semantic resume anchors are
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
   - Resident dispatch asserts the expected dimension-neutral result and core progression state. The smoke also asserts the exact 17 landmark and 6 inspectable production subject ids and their shared request contract.
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
   - Controller/coordinator resident dispatch, resident result/state parity, semantic resume fallback, and the exact production set of 17 landmark plus 6 inspectable subjects are green. Tunnel-resident routing/visibility remains open. Player profiles map adult masculine/feminine and teen frames to the male/female/boy GLBs.
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

- `family_memory` now has an embodied A Po household/courtyard care beat, an
  exclusive transformed missed path, explicit parent-care reflection after winter,
  and a Spring Festival aftermath beat
- `study_future` now keeps sounding across church and harbor residents after the future choice and second-summer release
- `preservation_inheritance` now reaches beyond Bagua's first perspective beat into postcard and map-stewardship reactions
- `melody_landmarks` now has a softer resonant follow-through after the harbor performance

Still open:

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
- A Po's household now retains cared-for versus untended props, window/lantern
  ambience, reflective inspect text, and later Spring Festival dialogue from saved
  completed/missed facts
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
- household care versus absence adds distinct care/regret tone tags and summary
  texture without changing final-act eligibility

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
- route sections now distinguish terminal missed optional beats from blocked and
  resolved work

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

Status: Phase 0 complete; Phases 1-7 planned. The production actor still has the
shipped locomotion baseline only; none of the five capabilities below should be
described as implemented until its focused and production-flow validations pass.

The full ownership, input, compatibility, recovery, animation, phase validation, and
completion contract now lives in
[`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md). Keep that
feature document and the focused fixtures authoritative for engineering detail; this
plan owns only delivery order and milestone status.

Delivery order:

0. Phase 0 tuning/content/animation gate — complete 2026-07-23
1. shared physics, action-state, world-interaction, animation, and recovery foundation
2. physical traversal jump and recovery
3. ladder climbing
4. carrying
5. deliberate push/pull
6. sitting
7. production integration and hardening

Milestone B owns Phases 1-3. Milestone C owns Phases 4-6. Milestone D owns Phase 7
and is the sole Workstream 6 closure gate. Earlier milestones may deliver individual
capabilities but may not close the workstream. Milestone D closes it only after every
capability has a focused automated fixture, one authored production use, a manual
production-flow check, consistent input/cancellation/camera behavior, and accepted
animation coverage or an approved fallback for all three player models.

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
