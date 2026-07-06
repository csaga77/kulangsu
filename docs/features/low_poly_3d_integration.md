# Low-Poly 3D Integration

## Goal

- Define how the low-poly 3D runtime candidate proves interaction, resident,
  story, audio, save, and resume behavior without forking dimension-neutral
  gameplay services.
- Provide an explicit decision gate before any 3D work changes `game_main.tscn`.

## Current Status

- `scenes/game_world_3d.tscn` is a playable runtime candidate behind
  `main.gd`'s `USE_3D_OVERWORLD` development toggle (default off).
- Terrain/water, actor/controller, collision, camera, three authored landmarks,
  five stable landmark subjects, the complete shared resident roster, local
  resident wandering, 3D speech balloons, shared BGM/landmark-cue audio, and
  semantic resume anchors are integrated.
- `test_game_world_3d.tscn` boots the runtime candidate and exercises resident
  proximity selection and inspect dispatch through the 3D controller/adapter.
- The remaining acceptance work is two authored tunnel/interior spaces, routed
  tunnel residents, cycled 3D weather, representative landmark progression
  parity, the release-export repeat of the diagnostically green performance
  capture, and the recorded runtime-direction decision.

## Player Experience

- The player can approach one recognizable landmark with normal 3D movement and collision.
- A nearby inspect subject becomes the active contextual interaction.
- Inspecting it produces a response through the same subject-id semantics used by the current story layer.
- One resident proxy demonstrates readable scale and interaction range without introducing a parallel resident-data format.
- Leaving and restoring the slice returns the player to a safe documented anchor.

## Architecture And Ownership

- The dedicated 3D slice scene owns terrain/building instances, `HumanBody3D`, camera, spatial interaction areas, resident proxy instances, and mapping between authored 3D anchors and stable subject/resume ids.
- `HumanBody3D` owns movement and physical presentation only. It must not read `AppState`, route progress, resident definitions, or save data.
- Landmark and building scenes own geometry, collision, authored anchor nodes, and visual metadata. They must not apply story effects.
- A thin 3D interaction adapter converts the selected `Area3D` subject into the existing stable subject id and sends it to the integration scene.
- Existing story services own availability, response selection, and effects. No 3D-only fork of story rules is allowed.
- `AppState` remains the owner of shared progression, location, route, resident-override, and save-facing state.
- Existing resident definitions remain the source data. A 3D resident presenter may interpret appearance differently, but it must not duplicate identity, dialogue, routine, or story-gate data.
- A future 3D runtime world scene, not `game_main.tscn`, should own 3D spawning and world-to-story wiring until the runtime-direction decision is accepted.

## Interaction Contract

- Every interactive `Area3D` exposes a non-empty stable `subject_id`.
- Proximity selection is scene-local and must choose one deterministic active subject when ranges overlap.
- Input continues through `PlayerController3D`; architecture nodes do not poll input.
- The adapter emits an inspect request carrying the stable subject id and optional spatial context. It does not mutate progression directly.
- Story response/effect results flow back through the integration scene for presentation.
- Removing or replacing a visual building must not change stable subject ids.
- `LowPolyWorldCoordinates3D` remains the placement authority for island-level subjects and anchors.

## Save And Resume Contract

- Save data stores stable semantic ids and existing shared progression, never `NodePath`, instance id, raw `Vector3`, or generated mesh details as the sole resume key.
- The slice defines one stable resume-anchor id whose 3D transform is resolved by the owning scene.
- If the requested anchor is missing, resume falls back to the slice entry anchor.
- The current 2D save remains readable while the 3D lane is experimental. Prototype-only state must not alter the existing save schema without a versioned migration.

## Runtime Candidate Slice

- Default landmark: Piano Ferry.
- Shipped content: an authored landmark building, generated walkable collision,
  stable subjects, shared-data residents, entry/resume anchors, `HumanBody3D`,
  `PlayerController3D`, and `Camera3DController`.
- Automated checks cover deterministic prompt selection, controller-driven
  resident dispatch, camera-occluder behavior, the full shared resident count,
  audio-manager creation, and fallback resume behavior.
- The runtime candidate stays behind the development toggle until the final
  runtime-direction decision.

## Acceptance Evidence

- **Green:** focused 3D headless smoke scenes return status `0`.
- **Green:** the runtime candidate proves a controller/adapter resident dispatch
  and semantic resume anchor with fallback.
- **Green:** the five fixed-camera screenshots and dated visual acceptance note.
- **Diagnostic green / formal open:** the reproducible standalone Metal debug
  run passes every frame-time, draw-call, primitive, memory, and cold-rebuild
  budget over 60 seconds at 2880×1620 physical pixels. Repeat through a release
  export to close the formal gate.
- **Green baseline:** equivalent fresh 2D/3D resident dispatches produce the same
  dimension-neutral result and core progression state.
- **Open:** equivalent landmark dispatch parity with a meaningful progression
  effect.
- **Open:** `docs/plan/implementation_plan.md` must record replace, limited mode,
  or stop.

## Out Of Scope

- Replacing or deleting `game_main.tscn` before the decision gate.
- Duplicating resident/story data for the 3D presentation.
- A second story-event system, save format, resident catalog, or route model.
- Treating visual landmark proxies as authoritative story subjects.
