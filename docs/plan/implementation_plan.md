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

Plan status was reconciled against the integrated Milestone A implementation and
accepted production-flow review on **2026-07-26**. The focused route, state,
persistence, StoryEvent, reactivity, storyline-resource, and production-world
scenes passed with process status `0`.
The active queue, per-capability safety gates, and bounded follow-on slices were
reconciled across the canonical planning docs on **2026-07-27**.
The dated pre-refactor character-action baseline remains recorded in
[`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md).

Workstreams 0 and 5, the low-poly 3D cutover, and resident-data migration are
complete. Workstreams 1-4 remain content and polish tracks. Workstream 6 is the
required planned character-action track. The accepted tunnel, parity, and release-
performance follow-ups remain later work rather than blockers for the next slice.

### Completed Milestone A — Accepted 2026-07-26

Milestone A shipped the embodied Winter household-care scene, the first bounded
completed-versus-missed story-moment policy, its saved world/dialogue/journal/ending
reactivity, and Workstream 6 Phase 0's tuning/content/animation gate.

Acceptance evidence:

- focused route, state, persistence, StoryEvent, reactivity, and production-world
  scenes passed with process status `0`
- open-window Continue, legacy post-closer Continue, completed-care New Game, and
  missed-care New Game production flows passed
- the care and missed outcomes remain exclusive and idempotent, do not block Spring
  Festival or endgame, and retain distinct later texture
- the complete numeric, input/cancellation, three-model animation-fallback, exact
  production-proof, and pre-refactor baseline records live in
  [`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md)

The durable household-moment contract and validation summary live in
[`../features/household_care_story_moment.md`](../features/household_care_story_moment.md).
Milestone A implemented none of the five planned character actions.

### Active — Milestone B: Bagua Stewardship Ascent

Milestone B is the only active delivery milestone. Complete Workstream 6 Phases 1-3
in order:

1. shared physics, action-state, contextual-interaction, animation-fallback, and
   recovery foundation
2. forgiving physical traversal jump and recovery
3. authored ladder climbing

The production proof is one optional Bagua stewardship ascent in
`architecture/bagua_tower/bagua_tower_stylized_3d.tscn`: the accepted lower-terrace
jump followed by the accepted service ladder. The ordinary route to the tower and
the existing `preservation_tower_perspective` event remain available throughout;
the new physical path never gates, resolves, renames, or changes the score of that
event.

Story-semantic contract:

- physical movement may remain usable whenever its geometry is enabled, but saved
  StoryEvent meaning is eligible only in Story mode after
  `preservation_tower_perspective` has resolved
- a settled jump landing publishes `bagua_stewardship_jump_crossed` once through a
  StoryEvent effect; it is a persistent story fact, not a scored route event
- a settled top ladder dismount requires the jump fact at the semantic layer and
  publishes `bagua_stewardship_ladder_ascended` once; it unlocks one conditional
  preservation journal note plus one view-deck world response, without changing
  route score or endgame eligibility
- both semantic completions are no-ops in `Free Walk`; physical components never
  write `AppState` or route state directly
- save/continue preserves only StoryEvent-owned facts and derived presentation;
  locomotion mode, ladder position, recovery state, and other transient action state
  always reset deterministically

Per-phase exit gates:

- **Phase 1 — foundation:** introduce the ownership components named in
  [`../features/low_poly_actor_3d.md`](../features/low_poly_actor_3d.md), route current
  inspect/talk through one contextual arbiter, establish safe-transform recovery and
  generated animation profiles, and preserve shipped behavior. Cancellation,
  pause, recovery, scene-unload cleanup, and Free Walk semantic suppression are
  foundation requirements, not Milestone D follow-ups.
- **Phase 2 — traversal jump:** pass every accepted numeric boundary and rejection
  case in `test_character_traversal_3d.tscn`; pass the Bagua jump proof for walk and
  run approaches, miss recovery, ceiling rejection, pause/unload cleanup, one
  idempotent Story-mode publication, Free Walk no-op behavior, save/continue, and
  all three player-model fallbacks.
- **Phase 3 — ladder:** pass mount, climb, endpoint, blocked-exit, cancel, camera,
  recovery, pause/unload, and incompatible-mode cases in
  `test_character_traversal_3d.tscn`; pass the Bagua ladder production proof in both
  directions, one idempotent Story-mode publication, Free Walk no-op behavior,
  save/continue, and all three player-model fallbacks.

Milestone B closes only when:

- `test_character_action_state_3d.tscn` and
  `test_character_traversal_3d.tscn` exist and pass with process status `0`
- the existing actor, collision, environment, production-world, story route,
  StoryEvent, persistence, app-shell, and screen-router regressions remain green
- the fixed pre-ascent Continue fixture and a New Game production flow prove the
  optional path, alternate walkable route, journal/world response, recovery,
  overlays, reload, and Free Walk isolation
- the current-status tables in the actor feature, module map, gameplay workflow, and
  this plan are updated together

Primary implementation areas:

- `characters/` and `characters/control/`
- `characters/tests/`
- `game/world/`
- `architecture/bagua_tower/bagua_tower_stylized_3d.tscn`
- `game/story_event_catalog.gd`, `game/story_world_reactivity.gd`, and
  `game/journal_builder.gd`
- `game/tests/persistence/fixtures/`
- `game/tests/story_routes/` and `game/tests/persistence/`
- `scenes/game_world_3d.tscn` / `scenes/game_world_3d.gd`

### Next

1. **Bounded world-state reactivity slice.** Reapply changed resident routine
   overrides to already-spawned 3D actors without respawning them. Use a
   post-ascent `terrace_painter_nian` override to an authored view-deck anchor as the
   production proof. Close the slice only when focused reactivity coverage and the
   production-world test prove live update, save/continue parity, and no
   interruption of active talk or physical action state.
2. **Bounded final-act slice.** Add one playable ferry closing movement shared by
   the three current endgame triggers, with trigger-specific aftermath, hard-ending
   departure, and soft-ending stay/continue behavior. Close it only when all three
   trigger flows pass focused routing/persistence coverage and a production flow.
3. **Milestone C — object-care actions.** Complete Workstream 6 Phases 4-6 through
   the already locked proofs: carry the Piano Ferry music case
   (`piano_ferry_music_case_shelved`), push/pull the Trinity hymn chest
   (`trinity_hymn_chest_aligned`), and sit for the Piano Ferry harbor listening beat
   (`harbor_sea_melody_listened`). Each capability must ship with its focused
   fixture, deterministic pause/recovery/unload cleanup, Story-mode idempotency,
   Free Walk no-op semantics, production-flow check, and three-model animation
   acceptance.
4. **Milestone D — character-action production hardening.** Re-run all five actions
   across title, New Game, Continue, Free Walk, journal, pause, settings, ending,
   recovery, and scene-unload flows; finish shared hints and camera/input consistency.
   Milestone D revalidates safeguards required by each earlier slice; it is not the
   first point at which Free Walk suppression or deterministic cleanup is
   implemented. It remains the sole Workstream 6 closure gate.

### Later

- settings/audio-bus and richer world-reactivity validation
- typed migrations for remaining high-traffic dictionary payloads if their defect
  rate justifies the cost
- authored Bi Shan and Long Shan interiors, routed tunnel residents, landmark result
  equality, and a release-export performance repeat
- journal/HUD grouping and identity-focused resident model/material variants when
  content density or a usability finding justifies either

### Done

- Milestone A: household-care content slice, bounded missed-moment ledger, and
  Workstream 6 Phase 0
- Workstream 0: AppState decomposition and atomic snapshot ownership
- Workstream 5: typed storyline resources, inspector authoring, route browser,
  editable dependency graph, canonical-source persistence, and editor validation
- low-poly 3D production cutover and removal of the retired 2D overworld
- external resident-definition migration and 3D resident presentation

### Low-Poly 3D Runtime

The low-poly 3D world became the production overworld on 2026-07-06. The cutover,
legacy 2D runtime removal, visual acceptance, standalone Metal performance
acceptance, shell integration, story/resident/save ownership review, and focused
actor/terrain/camera/environment/world regressions are complete.

The durable execution record and evidence live in
[`low_poly_3d_replacement.md`](low_poly_3d_replacement.md),
[`../features/low_poly_3d_integration.md`](../features/low_poly_3d_integration.md),
and `design/qa/low_poly_3d/`. Keep their established correctness tests green during
Milestone B.

Accepted residual follow-ups:

- author walkable Bi Shan and Long Shan interiors plus routed tunnel residents
- repeat the accepted performance runner through a release export
- tune street-network defaults and remaining footprint sampling after island-scale
  review
- add resident model/material variants only if a later identity-readability review
  demonstrates the need

### Completed Resident Migration

- all resident definitions live as external `.tres` resources
- all production resident actors use `HumanBody3D`, `ResidentController3D`, and `ResidentFactory`
- compatibility appearance keys remain authored, while `CharacterModelCatalog3D` selects integrated GLB models

## Workstream 1: Route Content Depth

Status: ongoing content track. Only a named, bounded slice may enter the delivery
queue; “add more content” is not an executable task or closure criterion.

Shipped baseline:

- `family_memory` now has an embodied A Po household/courtyard care beat, an
  exclusive transformed missed path, explicit parent-care reflection after winter,
  and a Spring Festival aftermath beat
- `study_future` now keeps sounding across church and harbor residents after the future choice and second-summer release
- `preservation_inheritance` now reaches beyond Bagua's first perspective beat into postcard and map-stewardship reactions
- `melody_landmarks` now has a softer resonant follow-through after the harbor performance

Current bounded slice:

- Milestone B adds the optional Bagua stewardship ascent and its journal/world
  follow-through without gating or rescoring `preservation_tower_perspective`
- its content portion closes only with the exact semantic, production-flow,
  persistence, recovery, and alternate-path evidence in the Active milestone

Selection rule for the following slice:

- choose exactly one unresolved gap from the story framework
- name the production scene, route family, semantic facts, opening/closing
  conditions, journal/world response, automated owner, and manual production flow
- do not begin another general household system or new top-level route by default

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

Status: first pass shipped; one bounded follow-up is queued immediately after
Milestone B.

Shipped baseline:

- new conditional beats now react to winter-memory, Spring Festival, future-choice, second-summer, preservation, and resonant-festival state across ferry, church, and Bagua districts
- `scenes/game_world_3d.gd` surfaces selected route-event resolutions as world-status feedback instead of leaving those turns only in journal state
- route-aware inspectables at Piano Ferry, Trinity Church, and Bagua Tower now carry non-resident world reactivity alongside dialogue follow-through
- A Po's household now retains cared-for versus untended props, window/lantern
  ambience, reflective inspect text, and later Spring Festival dialogue from saved
  completed/missed facts
- first-pass StoryEvent routing now unifies resident talk, inspectable resolution, shared condition matching, and saved resident routine-override configuration behind the `AppState` story-subject bridge
- route progress now changes more of what the island feels like without requiring landmark-only progression

Next bounded slice:

- reapply changed resident routine overrides to already-spawned 3D actors instead
  of waiting for a future spawn or scene reload
- after `bagua_stewardship_ladder_ascended`, apply a
  `terrace_painter_nian` routine override to an authored view-deck anchor as the
  production proof
- close only when focused reactivity and production-world coverage prove live
  update without respawn, save/continue parity, and no disruption of active talk or
  physical action state

Later reactivity work must enter the queue as another named surface/district slice.
The typed-binding migration remains conditional: either introduce typed StoryEvent
bindings with a dedicated migration plan, or add drift validation in the feature
that introduces the next binding shape.

Primary files:

- `game/residents/definitions/`
- `game/story_event_service.gd`
- `game/story_world_reactivity.gd`
- `game/world/story_interaction_coordinator.gd`
- `characters/resident_factory.gd`
- `characters/control/resident_controller_3d.gd`
- `architecture/piano_ferry/piano_ferry_stylized_3d.tscn`
- `architecture/trinity_church/trinity_church_stylized_3d.tscn`
- `architecture/bagua_tower/bagua_tower_stylized_3d.tscn`
- `scenes/game_world_3d.gd`
- `game/tests/story_routes/test_story_reactivity.gd`
- `scenes/tests/test_game_world_3d.gd`

## Workstream 3: Final-Act And Ending Polish

Status: overlay differentiation shipped; one bounded playable closing slice is
queued after the world-state reactivity slice.

Shipped baseline:

- ending and departure overlays now have trigger-specific title, summary, and departure language for exam, honest-future, and harbor-performance runs
- soft endings now present explicit stay-versus-leave text instead of only a generic continue prompt
- route emphasis and expanded tone tags now feed the final summary language
- household care versus absence adds distinct care/regret tone tags and summary
  texture without changing final-act eligibility

Next bounded slice:

- add one shared playable ferry closing movement with trigger-specific aftermath
  for `summer_exam_complete`, `future_commitment_end`, and
  `harbor_festival_performed`
- preserve hard-ending departure for the first two triggers and soft-ending
  stay/continue behavior for the harbor performance
- close only when focused route/persistence coverage and one production flow per
  trigger prove entry, departure, continue, save handling, and return-to-title

Primary files:

- `ui/screens/ending_overlay.gd`
- `ui/screens/departure_overlay.gd`
- `game/story_route_graph.gd`
- `main.gd` and `scenes/game_world_3d.gd`
- `game/tests/persistence/test_story_autosave.gd`
- `ui/screens/tests/test_app_screen_router.gd`

## Workstream 4: Journal And HUD Polish

Status: no active slice. The current presentation is accepted for the existing
content density.

Shipped baseline:

- the HUD now distinguishes manual versus automatic pinned-lead state
- the journal now shows lead-selection mode, route emphasis, richer per-route counts, and lead-control guidance
- the `Auto Lead` action now makes manual lead clearing explicit instead of leaving it implied
- route sections now distinguish terminal missed optional beats from blocked and
  resolved work

Reopen trigger:

- a second missable moment, materially denser route ledger, or documented usability
  finding demonstrates that current grouping or wording is insufficient
- before implementation, name the exact readability problem, affected states,
  proposed presentation, screenshot/manual review, and focused projection/UI
  coverage

Primary files:

- `ui/screens/game_hud.gd`
- `ui/screens/journal_overlay.gd`
- `ui/screens/journal_overlay.tscn`
- `game/journal_builder.gd`

## Completed Workstream 5: Storyline Editor Workflow, Content Tooling, And Test Growth

Status: complete for its defined authoring-workflow exit criteria. Future validation
growth belongs to the Later queue or to the feature that introduces a new schema or
runtime behavior; it is not a reason to keep the editor workflow itself active.

Shipped outcome:

- typed route resources under `game/storylines/routes/` are the canonical runtime
  and editor source
- the addon-owned schema, inspector workflow, route browser, editable dependency
  graph, checked-in graph layout, and cross-route validation all write back to that
  source
- runtime, journal, and autosave consumers keep reading one definition bundle rather
  than a graph-only or editor-only format
- focused storyline-resource, route, StoryEvent, reactivity, and persistence
  regressions cover the delivered workflow

Detailed addon behavior belongs in `addons/storyline_editor/README.md` and its
`docs/` folder rather than in this current delivery plan.

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
7. full-flow integration, regression, and closure review

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

Before an individual capability is described as implemented, its own slice must
also prove deterministic pause/recovery/unload cleanup and no StoryEvent mutation in
`Free Walk`. Milestone D repeats those safeguards across combined actions and the
full app flow; it does not postpone their first implementation.

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

### Medium-Impact (add content or modes)

2. **Additional Routes**: Whether to add more non-landmark routes beyond the current four
3. **Additional Endgame Triggers**: Whether to add more major-event endgame triggers after the current structure settles
4. **Post-Ending Wandering**: Whether to add more authored wandering content after soft endings without introducing a separate after-ending mode

### Low-Impact (cleanup/refinement)

5. **Profile Facade Collapse**: Whether to collapse the player profile facade by exposing the profile service directly to UI consumers
