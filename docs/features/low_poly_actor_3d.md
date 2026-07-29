# Low Poly Actor 3D

## Goal

- Provide the production 3D actor adapter for the low-poly overworld.
- Provide a single 3D movement and collision contract for all production characters.
- Define the current character-action baseline and the acceptance gates for physical actions.
- Keep resident, NPC, and story rules outside the physical actor.

## Current Status

- [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd) defines `class_name HumanBody3D`.
- [`../../characters/human_body_3d.tscn`](../../characters/human_body_3d.tscn) is the minimal actor scene.
- [`../../assets/characters/`](../../assets/characters) holds the premade low-poly character models (skinned and textured). The current validated locomotion baseline is `idle`, `walk`, and `run`; imported models may include extra clips such as `dance`, `scared`, or `wave_goodbye`, but those must be validated before gameplay use. [`male.glb`](../../assets/characters/male.glb) is the default actor visual; [`boy.glb`](../../assets/characters/boy.glb) and [`female.glb`](../../assets/characters/female.glb) are interchangeable alternates assignable through `character_model_scene`.
- [`../../characters/control/base_controller_3d.gd`](../../characters/control/base_controller_3d.gd) defines `class_name BaseController3D`, the shared 3D controller base for `HumanBody3D`.
- [`../../characters/control/player_controller_3d.gd`](../../characters/control/player_controller_3d.gd) defines `class_name PlayerController3D`, a first playable input adapter that extends `BaseController3D`.
- [`../../characters/actions/`](../../characters/actions) owns the story-free
  sustained action state and validated/generated animation fallback profile.
- [`../../game/world/`](../../game/world) owns unified contextual arbitration,
  physical action targets, ladder paths, traversal completion, and recovery areas.
- [`../../characters/character_model_catalog_3d.gd`](../../characters/character_model_catalog_3d.gd) centralizes player and resident model selection, and [`../../characters/character_preview_3d.gd`](../../characters/character_preview_3d.gd) renders the same actor/model contract in UI SubViewports.
- [`../../characters/tests/test_human_body_3d.tscn`](../../characters/tests/test_human_body_3d.tscn) is the focused smoke scene covering actor API parity, current-frame controller input, jump takeoff velocity, character-model structure (instanced model, mesh, material, skeleton, and `idle`/`walk`/`run` animation clips), and the absence of the removed per-part accessory API and generated accessory nodes.
- [`../../characters/tests/test_character_collisions.tscn`](../../characters/tests/test_character_collisions.tscn) builds its own collision fixtures and validates gravity/landing, static-wall blocking, native stair-slope ascent/descent and side blocking, and capped `RigidBody3D` pushing.
- [`../../characters/tests/test_character_action_state_3d.tscn`](../../characters/tests/test_character_action_state_3d.tscn)
  validates mode compatibility, exact target gates, arbitration, cancellation,
  recovery, cleanup, and Story/Free Walk semantic boundaries.
- [`../../characters/tests/test_character_traversal_3d.tscn`](../../characters/tests/test_character_traversal_3d.tscn)
  validates the accepted physical jump, recovery, ceiling, ladder, endpoint, and
  blocked-retreat contracts.
- [`../../characters/tests/test_character_object_actions_3d.tscn`](../../characters/tests/test_character_object_actions_3d.tscn),
  [`../../characters/tests/test_character_push_pull_3d.tscn`](../../characters/tests/test_character_push_pull_3d.tscn),
  and [`../../characters/tests/test_character_sit_3d.tscn`](../../characters/tests/test_character_sit_3d.tscn)
  validate the carry, deliberate push/pull, and sitting contracts plus their
  authored production child scenes.
- [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn) validates the production actor/controller, generated terrain collision and streets, terrain-height following and wading, camera follow/orbit wiring, authored-landmark collision, and runtime integration.
- `HumanBody3D` instances the GLB model under `VisualRoot/CharacterModel`, scales it to `body_height`, rotates it to face the rig's forward axis, and auto-plants its lowest point at the foot origin.
- Hair and clothing are authored as part of the selected GLB. `HumanBody3D` does not instance separate hair, pants, or jacket scenes, create accessory `BoneAttachment3D` nodes, or transfer skin weights at runtime.
- The GLB model is the actor's only visual body; there is no procedural block-mannequin fallback. The actor's procedurally-generated geometry is limited to the optional `DebugBox` bounding-box gizmo and the optional skeleton bone-debug lines.

### Capability Scope

| Capability | Status | Current contract or scope |
| --- | --- | --- |
| Idle, walk, and run | Current | Camera-relative XZ movement with validated `idle`, `walk`, and `run` model clips. |
| Legacy cosmetic jump adapter | Compatibility only | `jump()` remains for old previews/probes; production `ui_jump` uses the physical traversal request. |
| Physical fall and landing | Current | One intent-driven physics step owns gravity, floor/air transitions, landing recovery, and safe-transform recovery without fall damage. |
| Inspect, talk, and physical context | Current | `WorldActionCoordinator3D` is the sole contextual selector/hint owner and delegates story activation to `StoryInteractionCoordinator`. |
| Contact-based dynamic pushing | Current | Contact with an unfrozen `RigidBody3D` applies a small capped impulse; this is not an aligned Push action or puzzle-object framework. |
| Physical traversal jump | Current | `ui_jump` drives the accepted collision-body arc, buffer/coyote/air-control/ceiling limits, landing recovery, and safe-anchor cancellation. |
| Carry | Current | Typed light/medium carryables, bounded placement validation, movement restrictions, deterministic reset, and optional semantic completion. |
| Deliberate push/pull | Current | Constrained alignment and deterministic puzzle-object movement distinct from contact pushing, with blockage, bounds, reset, and goal handling. |
| Sit | Current | Authored seat/exit anchors, occupancy, animation, camera continuity, immediate exit, fallback search, and optional listening completion. |
| Ladder climbing | Current | Two-way straight authored paths own mount alignment, constrained climb, expanded endpoint clearance, blocked retreat, cancellation, semantic completion, and recovery. |
| Cooperative physical tasks and NPC-assisted traversal | Out of scope | These remain separate from the required player-action set until a route and resident-behavior contract owns them. |

All five required capabilities are now Current and have authored production slices.
Milestone C production review and Milestone D's combined full-flow closure review
remain before the character-action workstream can be marked complete.

The actor exposes familiar adapter fields and methods:

- `direction`
- `is_walking`
- `is_running`
- `body_height`
- `body_radius`
- `character_model_scene`
- `character_model_height`
- `character_model_yaw_offset`
- `character_model_auto_ground`
- `character_model_y_offset`
- `draw_skeleton_bones`
- `skeleton_debug_color`
- `model_idle_animation` / `model_walk_animation` / `model_run_animation`
- `configuration`
- `move(...)`
- `move_with_speed(...)`
- `jump()` (legacy cosmetic adapter)
- `request_jump()` / `release_jump()`
- `get_locomotion_mode()` / `is_free_locomotion()` / `is_airborne()`
- `begin_ladder(...)` / `apply_ladder_motion(...)` / `finish_ladder(...)` / `cancel_ladder(...)`
- `set_safe_transform(...)` / `recover_to_safe_transform()`
- `get_direction_vector()`
- `set_direction_vector(...)`
- `get_ground_rect()`
- `is_grounded()`
- `global_position_changed`

## Ownership

- The runtime actor is owned by [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd).
- The character model asset lives in [`../../assets/characters/`](../../assets/characters); `HumanBody3D` owns its instancing, scaling, orientation, grounding, and animation mapping.
- `BaseController3D`, `PlayerController3D`, and `ResidentController3D` are the only production character controllers. The former 2D actor/controller hierarchy has been removed.
- `game_world_3d.tscn` owns runtime placement and integration; `HumanBody3D` remains independent of story and shared app state.

## Contracts

- `direction` uses a flat-angle convention: `0` points east, `90` points south, `180` points west, and `270` points north.
- `configuration` accepts and round-trips the retained high-level appearance dictionary for save compatibility. The 3D actor does not interpret per-part selections; all visible appearance comes from the selected GLB.
- `character_model_scene` is the `PackedScene` instanced for the model and defaults to `male.glb` (swap in `boy.glb` or `female.glb` for a different character). The model is scaled by `body_height / character_model_height`, rotated by `character_model_yaw_offset` (default `-90` so the model's authored facing aligns with the rig's `+Z` forward), and vertically planted so its lowest rendered point sits at the foot origin when `character_model_auto_ground` is on, with `character_model_y_offset` as an additional manual nudge.
- Hair, clothing, and other body styling must be part of `character_model_scene`; the actor intentionally exposes no separate hair, pants, jacket, attachment, or runtime skin-transfer contract.
- `draw_skeleton_bones` is an editor/runtime debug toggle (default `false`). When enabled with the GLB model active, `HumanBody3D` draws the character model's `Skeleton3D` as bone lines in a `SkeletonDebug` `ImmediateMesh` parented under the skeleton, refreshed every frame so it tracks animation; `skeleton_debug_color` sets the line color.
- Locomotion drives the model's `AnimationPlayer`: `idle` when standing, `walk` when walking, and `run` when running, looped with a short crossfade. Clip names come from `model_idle_animation` / `model_walk_animation` / `model_run_animation` and resolve case-insensitively against the imported animation list.
- The character model carries its own mesh, texture, skeleton, and animation clips; no runtime mesh generation or per-vertex color authoring is involved.
- `move(...)` and `move_with_speed(...)` consume XZ-plane `Vector3` directions.
- `get_ground_rect()` returns an XZ-plane `Rect2` footprint for future adapter code; it is not a drop-in replacement for 2D physics queries.
- `is_grounded()` is the preferred 3D actor grounded check; it excludes physical
  airborne/traversal, ladder, recovery, and legacy cosmetic-jump states.
- `body_height` and `body_radius` update the model scale, capsule collision shape, local bounding box, and ground footprint together.
- The optional `controller` slot accepts `BaseController3D` resources such as `PlayerController3D` or `ResidentController3D`.
- `PlayerController3D` consumes the existing input map: `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_walk`, `ui_jump`, and `ui_inspect`.
- `PlayerController3D` reads input before the base controller applies movement so starts and stops affect the current controller tick.
- `camera_relative_movement` can align movement to the active `Camera3D`; when disabled, movement is world-aligned on XZ.
- Stairs expose smooth walkable ramp/platform collision beneath their stepped render meshes. `HumanBody3D` traverses those shapes through its ordinary downward grounding velocity and Godot's native `move_and_slide()` slope response; it has no stair-specific floor probes, placement queries, position rewrites, or synthetic grounded state.
- Static walls and stair side faces stay on the same native collision path, while the actor applies a small movement-direction impulse to push dynamic bodies such as balls.
- Production `ui_jump` calls `request_jump()` and moves the collision body through
  the accepted physical arc. The old `jump()` visual-only behavior is retained only
  as an explicit compatibility adapter.
- Actor placement in generated terrain must use `LowPolyWorldCoordinates3D` instead of scene-local guessed offsets.
- Terrain/building elevation following is owned by `game_world_3d`. During physics frames it raycasts a short distance below the actor against the actor collision mask so terrain, piers, and collision-bearing building parts can support the feet; if no solid surface is found, it falls back to `LowPolyTerrain3D.get_world_surface_height(...)` and the documented water-wading rule. `HumanBody3D` itself stays terrain-agnostic.

### Action Model And Input

Character behavior uses orthogonal layers instead of one mutually exclusive list
of every action:

- the locomotion layer is `idle`, `walk`, `run`, `airborne`,
  `traversal_jump`, `ladder`, or `recovery`;
- the sustained action/posture layer is typed as `free`, `carry`, `push`, `pull`,
  or `sit`, with the three object-care modes current after Milestone C;
- inspecting and talking are one-shot requests, not sustained actor states.

Only one locomotion mode and at most one sustained action/posture may be active.
Compatibility and control restrictions must be derived from those layers rather
than encoded as combined states such as `walk_while_carrying`.

The current player input contract is:

- `WASD` or arrow keys move;
- holding `Shift` (`ui_walk`) uses the slower walk speed;
- releasing `Shift` while moving returns to the default run speed;
- `Space` (`ui_jump`) requests the physical traversal jump;
- `R` (`ui_inspect`) requests the selected physical action, inspect, or talk;
- `Esc` first cancels an active physical action or recovers an airborne player,
  then follows normal shell back behavior on a later press.

Changing from run-by-default to walk-by-default is a product and input decision
that must update the controller, hints, test scenes, and this document together.
Future world actions should reuse the contextual interaction input when the target
and result are unambiguous; a new dedicated input needs a repeated gameplay use and
player-facing prompt.

Short inspections and speech-balloon conversations are non-blocking by default.
An instrument, mechanism, seat, or overlay may request a movement lock, but the
owning feature must define entry, completion, cancellation, cleanup, and camera
behavior. Pressing `ui_inspect` alone must never imply a movement lock.

Player and resident actors share the `HumanBody3D` collision, gravity, slope, and
locomotion contracts. `PlayerController3D` owns player input, jump, and inspect
requests; `ResidentController3D` owns resident wandering, pauses, and facing.
Future actions are opt-in per controller and must not introduce player input or
story rules into `HumanBody3D`.

The required compatibility defaults are:

| Action or posture | Allowed locomotion | Default restriction |
| --- | --- | --- |
| Free | Idle, walk, run, fall, traversal jump, or ladder climb | Full control for the active locomotion mode. |
| Carry light | Idle and walk | Run, jump, and ladder use stay disabled until a specific authored object proves they are safe. |
| Carry medium | Idle and walk | No run, jump, or ladder use. |
| Push or pull | Idle and constrained walk | No run, jump, or ladder use; movement remains aligned to the target. |
| Sit | Idle | Movement remains locked until the player exits; camera control stays available. |
| Ladder climb | Ladder locomotion with no sustained object action | No carry, push, pull, sit, or traversal jump while mounted. |

### Action Ownership

The action expansion keeps physical state scene-local and story meaning semantic:

| Owner | Current or planned responsibility |
| --- | --- |
| `HumanBody3D` | Own locomotion mode, velocity, one physics integration step per tick, floor/air transitions, and animation requests; remain free of story rules. |
| `PlayerController3D` | Translate input into movement, jump, contextual-action, and cancel intentions without manipulating world targets. |
| `CharacterActionController3D` | Own sustained `free`, `carry`, `push`, `pull`, or `sit` state, target lifecycle, compatibility, and cleanup. |
| `WorldActionCoordinator3D` | Sole contextual-input and hint arbiter across physical targets and story subjects, delegating story activation to `StoryInteractionCoordinator`. |
| `StoryInteractionCoordinator` | Continue story-subject selection, request construction, and `AppState` dispatch without competing for the input or hint. |
| `ActorSurfaceFollower` | Run normal seating only for grounded locomotion, expose forced spawn/resume settling, and suspend automatic seating during airborne, ladder, and recovery modes. |
| `PlayerRecoveryController3D` | Track a scene-local safe transform plus semantic landmark fallback, recover the player, cancel actions, and reset affected objects without changing story progress. |
| `CharacterActionTarget3D` | Provide typed action id, label, priority, range, facing/anchor data, availability, and begin/cancel/complete hooks. |
| Feature targets | `Ladder3D`, `CarryableObject3D`, `PushPullObject3D`, and `Seat3D` own only authored transforms, constraints, and local lifecycle. |
| `CharacterAnimationProfile3D` | Map locomotion/action modes to validated per-model clips with explicit development fallbacks. |

`AppState` receives only semantic completion results. It never owns velocity,
locomotion/action modes, ladder progress, held-object transforms, push/pull
coordinates, or seat alignment.

The world-action coordinator ranks candidates by authored priority, facing, then
distance. An engaged action receives its own exit/cancel first. `Esc` cancels a
sustained physical action before opening a higher overlay, preserving the app-wide
back-one-level rule. Phase 0 rejects player-controlled carried-object rotation:
there is no dedicated input or prompt, carried objects keep their authored socket
orientation, and a valid placement applies the target's authored orientation.
Rotation remains unsupported unless a later repeated production need approves a
dedicated input, prompt, behavior, and focused test together.

### Delivery Stages

The implementation plan owns which milestone is active; this feature owns the
engineering and acceptance contract for every stage.

0. **Tuning, content, and animation gate.** Lock numeric jump, gap, landing,
   buffering, forgiveness, ladder, action-range, carry, push/pull, placement, and
   recovery fixtures. Audit `male.glb`, `female.glb`, and `boy.glb` clips. Approve an
   exact scene, semantic completion id, geometry requirement, and manual check for
   every production proof. Capture the existing actor/collision/environment/world
   baseline before refactoring.
1. **Physics, state, interaction, and recovery foundation.** Introduce typed
   locomotion/action modes, make controllers provide intent, keep exactly one
   `move_and_slide()` integration per physics tick, route current story interaction
   through `WorldActionCoordinator3D`, make surface following locomotion-aware, and
   add safe-transform recovery plus animation profiles without changing shipped
   behavior. Establish deterministic pause/recovery/unload cleanup and suppress
   physical-action StoryEvent effects in `Free Walk` before any capability publishes
   a production semantic completion.
2. **Physical traversal jump.** Replace the visual-only jump with a collision-body
   arc using the approved buffer, forgiveness, air-control, ceiling, landing,
   camera, and recovery values. It must not bypass StoryEvent gates or semantic
   resume anchors.
3. **Ladder climbing.** Add a straight authored ladder path with deterministic
   mount/alignment, endpoints, clearance, constrained movement, blocked-exit,
   cancellation/fall, camera, cleanup, and recovery behavior.
4. **Carry — implemented.** Provides typed light/medium carryables, an actor socket, collision policy,
   bounded shape-tested placement, movement restrictions, reset behavior, and an
   optional semantic completion id.
5. **Deliberate push/pull — implemented.** Provides constrained deterministic objects with authored
   axis/path, range, alignment, blockage, release, route-protection, reset, and
   completion behavior; retain incidental `RigidBody3D` impulses only for ambient
   objects.
6. **Sit — implemented.** Provides seat/exit transforms, occupancy, camera policy, animation,
   shape-tested fallback exits, immediate contextual/cancel exit, and semantic
   listening/conversation context where authored.
7. **Full-flow integration and closure review.** Revalidate StoryEvent ownership,
   Free Walk suppression, deterministic pause/recovery/unload settlement, shared
   hints, camera/input consistency, and all five actions across the full
   title/New Game/Continue/Free Walk/overlay flow. These safeguards are required by
   each earlier capability slice; Phase 7 is not their first implementation point.

Focused validation ownership:

- `test_character_action_state_3d.tscn`: mode compatibility, target arbitration,
  cancellation/back behavior, surface-follow suspension, Story/Free Walk semantic
  boundaries, and shared cleanup
- `test_character_traversal_3d.tscn`: numeric jump/fall/recovery fixtures plus ladder
  mount, climb, blocked exit, cancel/fall, camera, and recovery behavior
- `test_character_object_actions_3d.tscn`: carry, placement, doorway clearance,
  reset, recovery, rejection, and the Piano Ferry carry proof
- `test_character_push_pull_3d.tscn`: alignment, push/pull speed, blockage, bounds,
  route protection, reset, goal completion, cleanup, and the Trinity proof
- `test_character_sit_3d.tscn`: entry, occupancy, camera continuity, listening,
  authored/radial exits, cleanup, and the Piano Ferry bench proof
- `test_milestone_c_object_care_continue_fixtures.tscn`: exact Story-mode facts,
  idempotency, journal, autosave/reload, and Free Walk no-op behavior
- existing actor, collision, environment, and production-world scenes remain green
  throughout the migration

### Phase 0 Accepted Tuning And Content Gate

Phase 0 was completed on **2026-07-23**. The values below are acceptance targets,
not claims that the planned action code exists. World units are metres at the
current `1.72`-unit actor height. Fixtures must test the accepted boundary and the
named rejection boundary; authors may make production geometry easier but not
harder. All mandatory paths retain a walkable alternative until the focused and
production-flow checks for the action pass.

#### Numeric Acceptance Matrix

| Item | Accepted value | Required fixture geometry and boundary check |
| --- | --- | --- |
| Jump obstacle clearance and arc | Full press uses `4.80 m/s` takeoff velocity with `16.0 m/s²` gravity: `0.72 m` apex and `0.60 s` same-height flight. Releasing Space while rising clamps vertical velocity to `2.00 m/s`. Maximum authored obstacle is `0.45 m` high. | `2.00 m`-wide approach, a `0.45 m` high x `0.60 m` deep block, and a `1.40 m` deep landing pass. A `0.55 m` high block rejects cleanly; there is no mantle. |
| Gap width | Maximum required clear span is `1.20 m`; production proof uses `1.00 m`. | `2.00 m`-wide, `3.00 m`-long approach; `1.00 m`, `1.20 m`, and `1.35 m` trenches; `1.40 m`-deep x `2.00 m`-wide far pads. `1.20 m` passes and `1.35 m` is explicitly non-required/rejected. |
| Landing width and recovery | Required landing is at least `1.40 m` deep x `2.00 m` wide, with up to `0.12 m` downward floor snap. Normal control returns within `0.10 s`; there is no damage or stumble lock. | The gap fixture's far pad plus a `0.70 m`-deep narrow pad that must not be accepted as required geometry. Missing the pad enters player recovery rather than a fail screen. |
| Jump input buffering and edge forgiveness | `0.16 s` pre-landing input buffer and `0.18 s` coyote time after leaving a floor edge. Holding Space never auto-repeats; a new press is required. | A `2.00 m` square takeoff platform ending at a sharp edge records presses `0.16 s`/`0.17 s` before landing and `0.18 s`/`0.19 s` after departure as pass/reject pairs. |
| Air control | Horizontal jump speed is capped at `4.50 m/s`; steering acceleration is `6.00 m/s²`, with at most `1.00 m/s` total change from takeoff velocity during one jump. | Three `1.40 m`-deep landing lanes centred at `-0.45 m`, `0`, and `+0.45 m` after a `1.00 m` gap. Adjacent-lane correction passes; reversing direction or reaching a second adjacent lane does not. |
| Ceiling rejection | Takeoff needs `0.20 m` clear above the standing capsule. A ceiling contact cancels upward velocity in that physics tick and begins the fall; it never clips or crouch-launches. | Standing actor under slabs whose undersides are `1.90 m` and `1.94 m` above the floor. The `1.90 m` fixture rejects takeoff for the `1.72 m` body; `1.94 m` starts safely and later collision still cancels ascent. |
| Ladder mount/dismount alignment | Context range `0.90 m`, facing error at most `20°`, final anchor error at most `0.10 m` and `10°`, and alignment blend at most `0.30 s`. | Straight `3.20 m` ladder, `1.20 m` square bottom pad, mount probes at `0.90 m`/`0.91 m` and `20°`/`21°`, and authored top/bottom anchors. |
| Ladder climb speed | `1.80 m/s` in either direction; no acceleration ramp and no free XZ drift. | The `3.20 m` ladder path must take `1.78 s ± 0.05 s` between endpoint holds, excluding alignment blends. |
| Ladder endpoint clearance | Actor capsule sweep expanded by `0.10 m` radially and `0.20 m` vertically. Bottom clear pad is `1.20 m` square; top pad is `1.40 m` deep x `1.40 m` wide; top dismount anchor is `0.75 m` forward of the rail. | Clear endpoints pass. A `0.20 m`-deep overhead blocker or a `0.30 m` cube occupying either dismount capsule rejects that exit without ejecting the player. |
| Blocked ladder-exit recovery | After `0.20 s` of blocked endpoint contact, move back `0.35 m` along the ladder over `0.20 s`, remain mounted, and accept movement away from the blockage. If `Esc` is used, restore the last clear mount anchor. | Toggle the endpoint blocker in the ladder fixture while climbing. The actor must never remain inside the blocker, fall through the ladder, or advance story state. |
| Contextual physical-action range | Target anchor within `1.50 m`, vertical delta at most `1.00 m`, and facing half-angle `60°`. Story subjects retain their own authored radii; the shared arbiter still ranks priority, facing, then distance. | Anchors at `1.50 m`/`1.51 m`, `1.00 m`/`1.01 m` vertical delta, and `60°`/`61°`, with a competing story subject to prove deterministic arbitration. |
| Pickup range | Carryable centre/handle within `1.10 m`, vertical delta at most `0.65 m`, and a clear capsule-to-handle sweep. | Identical `0.50 m` light boxes at `1.10 m` and `1.11 m`, one on a `0.65 m` shelf and one on a `0.66 m` shelf, plus a `0.10 m` occluding wall. |
| Light carry movement, attachment, and doorway clearance | Forced walk speed `3.20 m/s`, turn rate `180°/s`, socket `0.45 m` forward and `1.05 m` above feet, maximum carried bounds `0.55 m` per axis, and `0.08 m` world-sweep margin. Door opening must exceed the combined actor/object envelope by `0.20 m` in width and `0.15 m` in height. | `0.50 m` cube; `4.00 m` walk lane; `1.00 m` wide x `2.10 m` high pass doorway and `0.75 m` wide rejection doorway. |
| Medium carry movement, attachment, and doorway clearance | Forced walk speed `2.40 m/s`, turn rate `120°/s`, socket `0.50 m` forward and `0.90 m` above feet, maximum bounds `0.75 x 0.55 x 0.55 m`, and `0.08 m` world-sweep margin. Door opening must exceed the combined envelope by `0.20 m` in width and `0.15 m` in height. | `0.75 x 0.55 x 0.55 m` case; `4.00 m` walk lane; `1.10 m` wide x `2.15 m` high pass doorway and `0.94 m` wide rejection doorway. |
| Push/pull alignment | Target handle within `1.10 m`; aligned actor anchor error at most `0.12 m` and `10°`; constrained object cross-axis error at most `0.05 m`. | `0.80 x 0.55 x 0.65 m` chest on a visible `3.00 m` rail, with entry probes at `0.12 m`/`0.13 m` and `10°`/`11°`. |
| Push/pull speed | Push `1.25 m/s`; pull `1.00 m/s`; no run modifier or acceleration impulse. | Timed `2.50 m` clear segment: push `2.00 s ± 0.05 s`, pull `2.50 s ± 0.05 s`. The object never leaves its authored axis. |
| Push/pull path bounds | Maximum production path length `4.00 m`; proof path `3.00 m`; stop `0.10 m` before either hard endpoint. | The `3.00 m` rail has explicit min/max anchors and goal at `2.50 m`. Continued input at either stop produces no drift or physics impulse. |
| Push/pull blockage | Combined actor/object sweep margin `0.08 m`. Less than `0.02 m` progress for `0.20 s` while input is held is blocked; stop motion, retain alignment, and show the blocked hint. | Insert a `0.30 m` wall across the rail and a side blocker beside the actor. Removing either resumes motion without accumulated impulse; `Esc` remains available. |
| Object-placement reach | Placement anchor `0.65-1.35 m` forward of the actor, with target height within `±0.60 m` of the carried socket. | Ground pads at `0.65 m`, `1.35 m`, and `1.36 m`; shelves at `±0.60 m` and `±0.61 m`. Out-of-range attempts keep the object attached. |
| Object-placement clearance | Object shape sweep and final overlap check use `0.08 m` margin; support must cover at least `80%` of the footprint. | One clear pad, one pad with a `0.07 m` gap, one with a `0.09 m` gap, and a support shelf covering `79%`/`80%`. Only the `0.09 m` and `80%` cases pass. |
| Object-placement tolerances | Final anchor error at most `0.10 m`, yaw error at most `10°`, and support slope at most `10°`. Valid placement applies authored orientation; the player cannot rotate the carried object. | Target sockets at `0.10 m`/`0.11 m`, `10°`/`11°`, and support ramps at `10°`/`11°`. Failed attempts keep the previous held transform. |
| Seat entry alignment and clearance | Context range `1.10 m`; seat-anchor error at most `0.10 m` and `10°`; entry blend `0.35 s`; occupied capsule volume has `0.10 m` radial/head margin. | `0.50 m`-high bench with one seat anchor, probes at `1.10 m`/`1.11 m`, and an overhead/side blocker intruding by `0.05 m`. |
| Seat exit alignment and clearance | Primary exit is `0.90 m` from the seat; final error at most `0.10 m` and `10°`; exit blend `0.30 s`; clear pad is `1.00 m` square. If blocked, test eight directions at radii `0.75`, `1.00`, then `1.25 m`; otherwise use player recovery. | Block the primary exit and then all but one radial candidate. The chosen capsule must be clear with `0.10 m` margin and must not overlap the bench or a drop. |
| Player out-of-bounds recovery | Record a safe transform only while grounded, free, and vertically stable (`≤0.50 m/s`) for `0.25 s`. Recover if feet fall `4.00 m` below it, remain `2.00 m` outside an authored recovery volume for `0.25 s`, or stay unsupported for `2.50 s`; settle within `0.25 s`, without damage or story rollback. | Guarded floor, `4.00 m` pit threshold, volume boundary markers at `2.00 m`/`2.01 m`, and a void fall. Recovery returns to the latest safe semantic anchor. |
| Movable-object out-of-bounds recovery | Save the last clear in-bounds transform. Restore if centre falls `2.00 m` below authored origin, remains `0.50 m` beyond its bounds for `0.25 s`, or blocks a required traversal volume for `2.00 s`; restored shape needs `0.10 m` clearance. | Carry and rail fixtures include a drop, boundary at `0.50 m`/`0.51 m`, and a required-path volume. Reset never changes story facts or teleports the player. |

#### Input, Cancellation, And Cleanup

`R` remains the contextual action input and `Space` becomes the one physical jump
input when traversal jump ships. While an action is engaged, its controls outrank
new physical targets and story subjects.

| Action | Entry and continued control | Completion | Explicit cancel/exit | `Esc` precedence | Incompatible-mode rejection | Pause, recovery, and unload cleanup |
| --- | --- | --- | --- | --- | --- | --- |
| Traversal jump | Press Space while grounded and `free`; WASD uses the accepted air-control limits; releasing Space shortens ascent. | Clear landing plus the `0.10 s` landing recovery. | No arbitrary mid-air drop. `Esc` invokes safe-anchor recovery. | Consume the first press for recovery; do not open pause on that press. A later press follows normal shell back behavior. | Reject while carrying, pushing, pulling, sitting, mounted on a ladder, recovering, or without accepted ceiling clearance. Rejection does not consume buffered movement. | External pause, forced recovery, or scene unload cancels velocity and restores the last safe transform before control/state teardown. |
| Ladder | Press R on the selected ladder while grounded and `free`; W/S climbs, camera remains available, A/D has no locomotion effect. | Cross a clear top or bottom dismount anchor; a semantic id may publish only after the dismount settles. | R at an endpoint dismounts; `Esc` restores the last clear mount anchor. | Ladder exit/cancel consumes the first press and prevents an overlay on that press. | Reject while airborne, carrying, pushing, pulling, sitting, recovering, or when mount/endpoint clearance fails. | Settle at the nearest clear endpoint; if neither is clear, use the mount safe anchor. Clear ladder reservation and zero velocity on pause, recovery, or unload. |
| Carry | Press R on the selected carryable while grounded and `free`; WASD uses the light/medium forced walk and turn values. | Press R on a valid placement target; apply its authored orientation, detach, then publish its optional semantic id once. | `Esc` returns the object to its last safe authored transform and exits carry. Invalid R placement is not a drop. | Carry cancel consumes the first press; pause does not open until a later press. | Reject in air, on a ladder, while push/pull or sit is active, during recovery, for heavy/unavailable objects, or on blocked pickup sweep. | Restore the object to its last safe transform, clear ownership/socket state, and return the actor to `free` before pause, recovery, or unload. |
| Push/pull | Press R on the selected handle while grounded and `free`; W pushes and S pulls on the authored axis; camera remains available. | Reaching the authored goal within `0.10 m` publishes the optional semantic id once and releases. | R releases at the last valid constrained coordinate without completion; `Esc` also releases. | Release consumes the first press and prevents an overlay on that press. | Reject while airborne, carrying, sitting, ladder-mounted, recovering, already reserved, outside alignment, or blocked at entry. | Snap to the last valid constrained coordinate, clear reservation/alignment, and restore free movement on pause, recovery, or unload. |
| Sit | Press R on a selected unoccupied seat while grounded and `free`; movement is locked and camera remains available. | Entry completes on the seat anchor after the `0.35 s` blend; any semantic listening completion is feature-owned and idempotent. | R exits immediately to the first clear exit; `Esc` performs the same exit. | Seat exit consumes the first press and prevents an overlay on that press. | Reject while airborne, carrying, pushing, pulling, ladder-mounted, recovering, occupied, or without a clear seat capsule. | Resolve a clear authored/fallback exit before pause or unload; forced recovery uses the player safe anchor. Always release occupancy. |

Carried-object rotation is firmly **unsupported** for the accepted action set. There
is no rotation input, no rotation hint, no free-spin behavior, and therefore no
rotation-control test. Placement validation tests only the authored target
orientation and the `0.10 m` / `10°` tolerance. A later change must add all four
parts—input, prompt, deterministic behavior, and focused test—in one approved slice.

#### Three-Model Animation Audit

The audit instantiated each GLB through Godot 4.7's importer and inspected the live
`AnimationPlayer`, not only the `.import` metadata. All three models expose the same
41-bone skeleton from `Root` through named hip, spine, arm, hand, leg, and foot
bones, so the explicitly approved generated fallbacks below can share bone names.
Imported clips are `30 fps`, have 40 tracks, and import with `LOOP_NONE`; runtime
profiles may loop only the accepted locomotion clips.

| Model | Imported clips and exact lengths | Acceptance decision |
| --- | --- | --- |
| `male.glb` | `cross_arms` `17.083334 s`; `idle` `17.583334 s`; `idle_1` `15.375000 s`; `run` `1.291667 s`; `scared` `3.291667 s`; `walk` `2.375000 s` | Accept only exact `idle`, `walk`, and `run` for locomotion. `cross_arms`, `idle_1`, and `scared` are not accepted for any required action phase. |
| `female.glb` | `dance` `23.166666 s`; `idle` `15.375000 s`; `run` `1.291667 s`; `scared` `2.583333 s`; `walk` `2.375000 s`; `wave_goodbye` `5.875000 s` | Accept only exact `idle`, `walk`, and `run` for locomotion. `dance`, `scared`, and `wave_goodbye` are not accepted for any required action phase. |
| `boy.glb` | `dance` `23.166666 s`; `idle` `15.375000 s`; `run` `1.291667 s`; `scared` `2.583333 s`; `walk` `2.375000 s`; `wave_goodbye` `5.875000 s` | Accept only exact `idle`, `walk`, and `run` for locomotion. `dance`, `scared`, and `wave_goodbye` are not accepted for any required action phase. |

Approved fallback profiles are explicit animation work owned by the future
`CharacterAnimationProfile3D`; they are not evidence that the source GLBs contain
the action clips:

- `FB_AIR`: blend from the current locomotion clip to the first neutral sample of
  exact `idle` over `0.12 s`; the physical body owns the arc/fall.
- `FB_LAND`: restart exact `idle` with a `0.10 s` crossfade; control is not delayed.
- `FB_LADDER`: generated `fallback_ladder_climb` `1.00 s` alternating hand/foot
  cycle on the common skeleton; mount and dismount are `0.30 s` blends to/from its
  endpoint poses.
- `FB_CARRY`: generated `fallback_carry_hold` two-hand upper-body pose layered over
  exact `idle` or exact `walk`; placement removes the layer over `0.25 s`.
- `FB_PUSH` / `FB_PULL`: generated `fallback_object_brace` upper-body pose layered
  over exact `walk` at `0.55x`; pull reverses the walk sample while the authored
  object axis owns motion.
- `FB_SIT`: generated `fallback_sit` on the common skeleton with `80°` hip and
  `90°` knee flexion, neutral ankles, upright spine, `0.35 s` entry, held seated
  pose, and `0.30 s` reversed exit.
- `FB_RECOVER`: first neutral sample of exact `idle`, held through a `0.15 s`
  recovery fade. No fall-damage or hurt clip is implied.

Every required model-and-phase cell is locked as follows:

| Required phase | `male.glb` | `female.glb` | `boy.glb` |
| --- | --- | --- | --- |
| Idle | exact `idle` (`17.583334 s`) | exact `idle` (`15.375000 s`) | exact `idle` (`15.375000 s`) |
| Walk | exact `walk` (`2.375000 s`) | exact `walk` (`2.375000 s`) | exact `walk` (`2.375000 s`) |
| Run | exact `run` (`1.291667 s`) | exact `run` (`1.291667 s`) | exact `run` (`1.291667 s`) |
| Takeoff | approved `FB_AIR` | approved `FB_AIR` | approved `FB_AIR` |
| Airborne | approved `FB_AIR` | approved `FB_AIR` | approved `FB_AIR` |
| Landing | approved `FB_LAND` | approved `FB_LAND` | approved `FB_LAND` |
| Ladder mount | approved `FB_LADDER` mount blend | approved `FB_LADDER` mount blend | approved `FB_LADDER` mount blend |
| Ladder climb | approved `FB_LADDER` cycle | approved `FB_LADDER` cycle | approved `FB_LADDER` cycle |
| Ladder dismount | approved `FB_LADDER` dismount blend | approved `FB_LADDER` dismount blend | approved `FB_LADDER` dismount blend |
| Carry idle | approved `FB_CARRY` over exact `idle` | approved `FB_CARRY` over exact `idle` | approved `FB_CARRY` over exact `idle` |
| Carry walk | approved `FB_CARRY` over exact `walk` | approved `FB_CARRY` over exact `walk` | approved `FB_CARRY` over exact `walk` |
| Carry place | approved `FB_CARRY` `0.25 s` release | approved `FB_CARRY` `0.25 s` release | approved `FB_CARRY` `0.25 s` release |
| Push | approved `FB_PUSH` | approved `FB_PUSH` | approved `FB_PUSH` |
| Pull | approved `FB_PULL` | approved `FB_PULL` | approved `FB_PULL` |
| Sit enter | approved `FB_SIT` `0.35 s` entry | approved `FB_SIT` `0.35 s` entry | approved `FB_SIT` `0.35 s` entry |
| Sit idle | approved `FB_SIT` held pose | approved `FB_SIT` held pose | approved `FB_SIT` held pose |
| Sit exit | approved `FB_SIT` `0.30 s` exit | approved `FB_SIT` `0.30 s` exit | approved `FB_SIT` `0.30 s` exit |
| Fall | approved `FB_AIR` | approved `FB_AIR` | approved `FB_AIR` |
| Recovery | approved `FB_RECOVER` | approved `FB_RECOVER` | approved `FB_RECOVER` |

Each generated fallback must be checked at actor scale in its focused fixture and
its named production proof. Substituting any merely present optional imported clip
does not satisfy that check.

#### Exact Production Proofs

These commitments replace the former location candidates. Geometry is authored in
the named landmark scene, which is instanced by
[`../../scenes/game_world_3d.tscn`](../../scenes/game_world_3d.tscn). Physical
targets publish the exact semantic completion id; StoryEvents decide any reward.

| Capability | Exact production scene and semantic completion id | Required production geometry | Required manual production-flow check |
| --- | --- | --- | --- |
| Traversal jump | [`../../architecture/bagua_tower/bagua_tower_stylized_3d.tscn`](../../architecture/bagua_tower/bagua_tower_stylized_3d.tscn); `bagua_stewardship_jump_crossed` | Lower stewardship terrace: `3.00 x 2.00 m` approach, `1.00 m` clear span, `1.40 x 2.00 m` landing, side rails outside the jump lane, and a recovery volume at the `4.00 m` drop threshold. | Title -> Continue from the fixed Story-mode pre-ascent fixture with `preservation_tower_perspective` resolved; walk and run approaches both cross; a miss restores the lower terrace without changing route state; successful landing publishes the StoryEvent-owned fact once; journal/reload retains only that authored meaning; the equivalent Free Walk crossing changes no story state. |
| Ladder | [`../../architecture/bagua_tower/bagua_tower_stylized_3d.tscn`](../../architecture/bagua_tower/bagua_tower_stylized_3d.tscn); `bagua_stewardship_ladder_ascended` | Straight `3.20 m` service ladder after the jump, `1.20 m` bottom pad, `1.40 x 1.40 m` top pad, `0.75 m` top dismount, and a controllable endpoint blocker for validation. | Continue from the same Story-mode fixture; mount only after the jump terrace, climb both ways, prove blocked-top retreat and `Esc` mount recovery, dismount at the view deck, confirm one StoryEvent-owned fact plus the journal/world response with no softlock after reload, and prove the equivalent Free Walk ascent changes no story state. |
| Carry | [`../../architecture/piano_ferry/piano_ferry_stylized_3d.tscn`](../../architecture/piano_ferry/piano_ferry_stylized_3d.tscn); `piano_ferry_music_case_shelved` | Light `0.50 x 0.35 x 0.30 m` music case, `1.00 x 2.10 m` doorway, `4.00 m` carry lane, and a clear authored shelf socket `1.00 m` forward of the standing anchor. | Title -> Continue from the fixed ferry-care fixture; pick up, walk through the pass doorway, verify the narrow rejection frame, cancel/reset once, then place on the shelf and confirm one completion plus deterministic reload; repeat the placement in Free Walk with no story mutation. |
| Push/pull | [`../../architecture/trinity_church/trinity_church_stylized_3d.tscn`](../../architecture/trinity_church/trinity_church_stylized_3d.tscn); `trinity_hymn_chest_aligned` | `0.80 x 0.55 x 0.65 m` hymn chest on a `3.00 m` authored axis, goal at `2.50 m`, `0.30 m` removable blocker, and required-path reset volume. | Title -> Continue from the fixed church-care fixture; push, pull, release/re-engage, prove blockage with no impulse buildup, reach the goal once, and reload with the StoryEvent result while the transient object resets deterministically; repeat the goal in Free Walk with no story mutation. |
| Sit | [`../../architecture/piano_ferry/piano_ferry_stylized_3d.tscn`](../../architecture/piano_ferry/piano_ferry_stylized_3d.tscn); `harbor_sea_melody_listened` | `0.50 m`-high harbor bench, one seat anchor, `0.90 m` primary exit, `1.00 m` square clear pad, and one blocker that forces the radial fallback exit. | Title -> Continue from the fixed harbor-listening fixture; enter, orbit the camera, exit immediately with R and with `Esc`, prove fallback exit, sit through the authored listening completion once, then journal/reload without retained occupancy; repeat the listening duration in Free Walk with no story mutation. |

**Milestone B: Bagua stewardship ascent** was accepted on **2026-07-28** with its
shared action/recovery foundation, physical traversal jump proof, authored ladder
proof, fixed Continue fixture, and New Game production flow. It is optional and, in
Story mode after
`preservation_tower_perspective` resolves, persists the two exact stewardship facts
and unlocks conditional journal/world follow-through. It must not gate, resolve,
rename, or rescore that existing event, and both facts are suppressed in
`Free Walk`.

**Milestone C: object-care actions** completed implementation and automated
consolidation on **2026-07-29** and awaits production review. The Piano Ferry
instances its music-case carry and harbor-bench sitting child scenes; Trinity Church
instances its constrained hymn-chest push/pull child scene. Their focused fixtures,
fixed Continue persistence fixture, production-world assertions, and standalone
environment test strip pass with process status `0`. The environment harness places
carry, sit, and push/pull fixtures clear of the default Bagua Tower and verifies
context registration, visible grounding, building clearance, and fixture spacing.
Deterministic cancel/pause/recovery/unload behavior, Story-mode idempotency, Free
Walk no-op semantics, and generated action fallbacks for all three player models
also remain green. The locked manual production-flow checks in the table above
remain the acceptance review; Milestone D remains the sole workstream closure gate.

#### Dated Pre-Refactor Baseline

The pinned `godot_common`, `low_poly_building_editor`, and `storyline_editor`
submodules were initialized before this baseline. On **2026-07-23**, Godot
`4.7.stable.official.5b4e0cb0f` produced:

| Scene | Required result | Recorded result |
| --- | --- | --- |
| `res://characters/tests/test_human_body_3d.tscn` | `PASS: HumanBody3D adapter smoke test`, status `0` | **PASS**, exact line present, status `0` |
| `res://characters/tests/test_character_collisions.tscn` (`--fixed-fps 60`) | `PASS: HumanBody3D collision smoke test`, status `0` | **PASS**, exact line present, status `0` |
| `res://scenes/tests/test_environment_3d.tscn` | `PASS: Environment test scene (res://architecture/bagua_tower/bagua_tower_stylized_3d.tscn)`, status `0` | **PASS**, exact line present, status `0` |
| `res://scenes/tests/test_game_world_3d.tscn` | `PASS: game_world_3d smoke test`, status `0` | **PASS**, exact line present, status `0` |

The sandboxed runs also logged the macOS CA-certificate lookup diagnostic. The
production-world scene logged expected unavailable-user-save warnings and
exit-time resource-leak diagnostics, but its PASS line and process status were
still `0`. No source, scene, test, plan, or submodule content was changed to obtain
this baseline.

All five required actions are now Current, each has a focused fixture and authored
production use, and all three player models have accepted animation coverage or an
approved fallback. The workstream is complete only after Milestone D confirms the
combined full-flow behavior and no action introduces precision-platforming gates,
route softlocks, punitive recovery, or transient physics state in `AppState`.

### Current Physics Defaults

These values describe the implementation defaults, not permanent design constants:

| Parameter | Current default |
| --- | ---: |
| Walk speed | `4.0` world units per second |
| Run speed | `7.5` world units per second |
| Traversal jump takeoff | `4.8` world units per second |
| Traversal jump short-hop clamp | `2.0` world units per second |
| Traversal jump horizontal cap | `4.5` world units per second |
| Jump buffer / coyote time | `0.16` / `0.18` seconds |
| Gravity | `16.0` world units per second squared |
| Maximum fall speed | `12.0` world units per second |
| Body height | `1.72` world units |
| Body radius | `0.28` world units |
| Grounding speed | `1.6` world units per second downward |
| Maximum dynamic-body push impulse | `1.2` engine impulse units |

Changing a value requires the actor, collision, environment, and production-world
validations below. An author-facing value belongs on the narrowest owning actor or
feature resource rather than in unrelated scenes.

### Current Movement Boundaries

- Idle zeroes horizontal velocity while vertical physics continues, so an
  unsupported controlled actor still falls and settles.
- The production traversal jump uses physical collision and the accepted forgiving
  obstacle/gap/landing limits; no required route depends on precision platforming.
- The legacy cosmetic `jump()` adapter never clears collision and is not bound to
  production input.
- Unsupported actors fall at the capped gravity speed, land through native floor
  contact, regain control immediately, and take no fall damage.
- Stairs use smooth authored ramp/platform collision and require no jump.
- Slopes use `CharacterBody3D` floor classification and native `move_and_slide()`;
  there is no bespoke speed-reduction band for steep slopes.
- Incidental dynamic-body contact still does not align the actor, reserve a target,
  classify weight, guarantee puzzle placement, or persist object position. Authored
  carry and deliberate push/pull use their deterministic target components instead;
  critical paths must not depend on a freely simulated body remaining in place.

### Current Object-Care Capability Contracts

Each current physical action has a concrete story or exploration use, numeric
authored limits, focused automated validation, and one locked production-flow
manual check.

Each object-care capability proves deterministic pause/recovery/unload cleanup and
no StoryEvent mutation in `Free Walk`.

- **Carry:** uses a typed carryable component with the accepted light/medium
  movement, pickup, attachment, doorway, placement, cancellation, and recovery
  contract. Heavy objects are not carryable, and player-controlled rotation stays
  unsupported.
- **Deliberate push/pull:** uses a constrained target interface distinct from
  incidental `RigidBody3D` contact and validates the accepted alignment, distance,
  speed, bounds, blockage, cancellation, route-protection, and reset values.
- **Sit:** provides authored seat and clear exit transforms using the accepted
  alignment, blend, clearance, and fallback-search values. A seat resource may make
  entry or exit more forgiving but not tighter; the player may exit at any time.

Dangerous drops require an authored recovery volume or the actor's safe-transform
recovery. Recovery must not cause damage, story-progress loss, or an unrelated
shared-state reload. Movable objects likewise need deterministic recovery
when they leave their bounds or block required traversal.

## Visual Style Contract

- The default 3D character is `male.glb`, a premade low-poly model with integrated appearance, baked-texture detailing, and skinned `idle`/`walk`/`run` animation.
- The model should read as a broad-use stylized avatar with a silhouette simple enough for games, animation previews, explainer-style scenes, or avatar applications.
- Preserve strong directional readability in orthographic camera views; the model's facing, proportions, and grounding matter more than animation polish at this stage.
- Tune the player against the production style-preset camera and authored landmark scale before changing the actor asset direction.

## Validation

- Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://characters/tests/test_human_body_3d.tscn
```

- Confirm the scene logs:

```text
PASS: HumanBody3D adapter smoke test
```

- Run the focused action regressions after changing sustained action state,
  interaction, animation, carry, push/pull, sitting, or semantic completion:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://characters/tests/test_character_action_state_3d.tscn
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://characters/tests/test_character_object_actions_3d.tscn
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --fixed-fps 60 --path . --scene res://characters/tests/test_character_push_pull_3d.tscn
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://characters/tests/test_character_sit_3d.tscn
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://game/tests/persistence/test_milestone_c_object_care_continue_fixtures.tscn
```

- Run the focused collision regression after changing gravity, wall handling, stair slope collision, or dynamic-body pushing:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --fixed-fps 60 --path . --scene res://characters/tests/test_character_collisions.tscn
```

- Confirm it logs `PASS: HumanBody3D collision smoke test`.
- Run the standalone environment integration after changing player/camera/action
  interaction with authored building collision:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_environment_3d.tscn
```

- The environment scene must register all three Milestone C targets and keep their
  visible bounds above ground, at least `3.0 m` from the default building, and at
  least `2.0 m` from each other. Open the scene without `--headless` for a compact
  manual sandbox: walk south from the spawn and press `R` at the left carry,
  center sit, or right push/pull fixture; `Esc` cancels an active action.
- Run the production-world validation after actor scale, movement, camera, or terrain-collision changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_game_world_3d.tscn
```

- Each headless scene must log its `PASS` line and return process status `0`; assertion failures return nonzero.

Milestone C implementation is review-ready when the actor, action-state, traversal,
carry, push/pull, sit, persistence, collision, environment, and production-world
validations pass; movement starts and stops in the current controller tick; holding
`Shift` walks; all three player models expose the generated action fallbacks;
unsupported actors and objects recover safely; and short story interactions do not
acquire an accidental movement lock.

## Next Steps

- Complete Milestone C's locked manual production-flow review for carry, deliberate
  push/pull, and sitting, then record acceptance without broadening the slice.
- Continue to Milestone D's combined title, New Game, Continue, Free Walk, overlay,
  recovery, and scene-unload closure review only after Milestone C is accepted.
- Tune actor movement speed, camera-relative movement, `Camera3DController` follow offset, and camera orbit feel inside the first one-landmark interaction slice so gameplay scale informs visual acceptance.
- The 3D runtime maps the shared player profile to whole-model swaps:
  adult masculine → `male.glb`, adult feminine → `female.glb`, and teen →
  `boy.glb`. Resident-specific visual identity beyond the current shared model
  remains an open content decision.
