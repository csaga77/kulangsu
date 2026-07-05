# Low-Poly 3D Integration

## Goal

- Define how the low-poly 3D sidecar can prove interaction, resident, story, save, and resume behavior without coupling prototype rendering code to the current 2D runtime.
- Provide an explicit decision gate before any 3D work changes `game_main.tscn`.

## Current Status

- Terrain, actor/controller, collision, camera, landmark proxy, authored-building, and playable review foundations exist.
- Runtime story/resident integration is not shipped.
- The next integration artifact is one non-story landmark slice, defaulting to Piano Ferry, in a dedicated test scene.

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

## First Vertical Slice

- Default landmark: Piano Ferry.
- Required content: one authored landmark building, walkable collision, one inspect subject, one resident proxy, entry/resume anchors, `HumanBody3D`, `PlayerController3D`, and `Camera3DController`.
- Required checks: approach without clipping, deterministic prompt selection, one subject dispatch, camera-occluder fade, readable resident/player scale, and fallback resume behavior.
- The slice stays under `scenes/tests/` until the final runtime-direction decision.

## Acceptance Evidence

- All focused 3D headless smoke scenes return status `0`.
- Fixed-camera screenshots and their dated acceptance note exist under `design/qa/low_poly_3d/`.
- `design/qa/low_poly_3d/performance.md` records the measurements and budgets defined in the implementation plan.
- The first vertical slice proves one subject dispatch and one resume anchor.
- `docs/plan/implementation_plan.md` records whether 3D replaces the 2D overworld, ships in a limited mode, or remains a discontinued experiment.

## Out Of Scope

- Replacing `game_main.tscn` before the decision gate.
- Reauthoring all residents or landmarks.
- A second story-event system, save format, resident catalog, or route model.
- Treating visual landmark proxies as authoritative story subjects.
