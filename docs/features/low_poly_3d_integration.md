# Low-Poly 3D Integration

## Goal

- Define how the production low-poly 3D runtime integrates interaction, resident,
  story, audio, save, and resume behavior without forking dimension-neutral
  gameplay services.
- Preserve the evidence and ownership contract used for the completed 3D cutover.

## Current Status

- `scenes/game_world_3d.tscn` is the production overworld instantiated directly by `main.gd`.
- Terrain/water, actor/controller, collision, camera, three authored landmarks,
  two tunnel markers, all 15 landmark subjects, all 5 inspectable subjects, the complete shared resident roster, local
  resident wandering, 3D speech balloons, shared BGM/landmark-cue audio, and
  semantic resume anchors are integrated.
- `test_game_world_3d.tscn` boots the production world and exercises terrain/water/street generation,
  actor grounding and wading, camera wiring, authored-landmark collision, resident proximity and
  inspect dispatch, shared audio/weather, and semantic resume behavior.
- Remaining work is two authored tunnel/interior spaces, routed tunnel residents, richer landmark presentation, and the release-export repeat of the diagnostically green performance capture. The runtime-direction decision is recorded as **replace**, the flip is complete, and the old 2D world stack has been removed.

## Player Experience

- The player can approach five recognizable landmark anchors with normal 3D movement and collision.
- A nearby inspect subject becomes the active contextual interaction.
- Inspecting it produces a response through the same subject-id semantics used by the current story layer.
- The complete resident roster uses shared definitions without introducing a parallel resident-data format.
- Leaving and restoring the world returns the player to a safe documented anchor.

## Architecture And Ownership

- The dedicated 3D slice scene owns terrain/building instances, `HumanBody3D`, camera, spatial interaction areas, resident proxy instances, and mapping between authored 3D anchors and stable subject/resume ids.
- `HumanBody3D` owns movement and physical presentation only. It must not read `AppState`, route progress, resident definitions, or save data.
- Landmark and building scenes own geometry, collision, authored anchor nodes, and visual metadata. They must not apply story effects.
- `StoryInteractionCoordinator` converts the selected `Area3D` subject into the existing stable subject request and sends it through `AppState`; it only considers subjects below its configured world root.
- Existing story services own availability, response selection, and effects. No 3D-only fork of story rules is allowed.
- `AppState` remains the owner of shared progression, location, route, resident-override, and save-facing state.
- Existing resident definitions remain the source data. `ResidentFactory` may interpret appearance differently for the 3D world, but it must not duplicate identity, dialogue, routine, or story-gate data.
- `game_world_3d.tscn` owns 3D spawning and composition; `ActorSurfaceFollower` owns grounding policy and `StoryInteractionCoordinator` owns world-to-story interaction wiring.

## Interaction Contract

- Every interactive `StorySubject3D` exposes a non-empty stable `subject_id`; the production-world test asserts the exact 15-landmark/5-inspectable non-NPC set.
- Proximity selection is world-root-local and must choose one deterministic active subject when ranges overlap; simultaneously loaded worlds cannot contribute competing subjects.
- Input continues through `PlayerController3D`; architecture nodes do not poll input.
- The coordinator emits an inspect request carrying the stable subject id and optional spatial context. It does not mutate progression directly.
- Story response/effect results flow back through the coordinator for world presentation.
- Removing or replacing a visual building must not change stable subject ids.
- `LowPolyWorldCoordinates3D` remains the placement authority for island-level subjects and anchors.

## Save And Resume Contract

- Save data stores stable semantic ids and existing shared progression, never `NodePath`, instance id, raw `Vector3`, or generated mesh details as the sole resume key.
- The slice defines one stable resume-anchor id whose 3D transform is resolved by the owning scene.
- If the requested anchor is missing, resume falls back to the slice entry anchor.
- Save-schema changes still require a versioned migration; presentation-specific 3D details must not leak into the dimension-neutral payload.

## Runtime World

- Default resume landmark: Piano Ferry.
- Shipped content: three authored landmark buildings, two tunnel markers, generated walkable collision,
  the complete authored subject set, shared-data residents, entry/resume anchors, `HumanBody3D`,
  `PlayerController3D`, and `Camera3DController`.
- Automated checks cover deterministic prompt selection, cross-world subject isolation,
  controller-driven resident dispatch, camera-occluder behavior, the full shared resident count,
  audio-manager creation, and fallback resume behavior.
- Lower-level terrain, actor, camera, street, and building behavior remains covered by focused tests;
  `test_game_world_3d.tscn` owns their production-world integration.

## Acceptance Evidence

- **Green:** focused 3D headless smoke scenes return status `0`.
- **Green:** the runtime world proves a controller/coordinator resident dispatch
  and semantic resume anchor with fallback.
- **Green:** the five fixed-camera screenshots and dated visual acceptance note.
- **Diagnostic green / formal open:** the reproducible standalone Metal debug
  run passes every frame-time, draw-call, primitive, memory, and cold-rebuild
  budget over 60 seconds at 2880×1620 physical pixels. Repeat through a release
  export to close the formal gate.
- **Green:** resident dispatch produces the expected dimension-neutral result/core progression state, and all 20 authored non-NPC world subjects satisfy the same shared service contract.
- **Green:** `docs/plan/implementation_plan.md` records the replace decision and completed runtime flip.

## Out Of Scope

- Restoring a second runtime overworld path without a new architecture decision.
- Duplicating resident/story data for the 3D presentation.
- A second story-event system, save format, resident catalog, or route model.
- Treating visual landmark proxies as authoritative story subjects.
