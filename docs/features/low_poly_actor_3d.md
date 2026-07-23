# Low Poly Actor 3D

## Goal

- Provide the production 3D actor adapter for the low-poly overworld.
- Provide a single 3D movement and collision contract for all production characters.
- Define the current character-action baseline and the acceptance gates for future physical actions.
- Keep resident, NPC, and story rules outside the physical actor.

## Current Status

- [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd) defines `class_name HumanBody3D`.
- [`../../characters/human_body_3d.tscn`](../../characters/human_body_3d.tscn) is the minimal actor scene.
- [`../../assets/characters/`](../../assets/characters) holds the premade low-poly character models (skinned and textured). The current validated locomotion baseline is `idle`, `walk`, and `run`; imported models may include extra clips such as `dance`, `scared`, or `wave_goodbye`, but those must be validated before gameplay use. [`male.glb`](../../assets/characters/male.glb) is the default actor visual; [`boy.glb`](../../assets/characters/boy.glb) and [`female.glb`](../../assets/characters/female.glb) are interchangeable alternates assignable through `character_model_scene`.
- [`../../characters/control/base_controller_3d.gd`](../../characters/control/base_controller_3d.gd) defines `class_name BaseController3D`, the shared 3D controller base for `HumanBody3D`.
- [`../../characters/control/player_controller_3d.gd`](../../characters/control/player_controller_3d.gd) defines `class_name PlayerController3D`, a first playable input adapter that extends `BaseController3D`.
- [`../../characters/character_model_catalog_3d.gd`](../../characters/character_model_catalog_3d.gd) centralizes player and resident model selection, and [`../../characters/character_preview_3d.gd`](../../characters/character_preview_3d.gd) renders the same actor/model contract in UI SubViewports.
- [`../../characters/tests/test_human_body_3d.tscn`](../../characters/tests/test_human_body_3d.tscn) is the focused smoke scene covering actor API parity, current-frame controller input, jump takeoff velocity, character-model structure (instanced model, mesh, material, skeleton, and `idle`/`walk`/`run` animation clips), and the absence of the removed per-part accessory API and generated accessory nodes.
- [`../../characters/tests/test_character_collisions.tscn`](../../characters/tests/test_character_collisions.tscn) builds its own collision fixtures and validates gravity/landing, static-wall blocking, native stair-slope ascent/descent and side blocking, and capped `RigidBody3D` pushing.
- [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn) validates the production actor/controller, generated terrain collision and streets, terrain-height following and wading, camera follow/orbit wiring, authored-landmark collision, and runtime integration.
- `HumanBody3D` instances the GLB model under `VisualRoot/CharacterModel`, scales it to `body_height`, rotates it to face the rig's forward axis, and auto-plants its lowest point at the foot origin.
- Hair and clothing are authored as part of the selected GLB. `HumanBody3D` does not instance separate hair, pants, or jacket scenes, create accessory `BoneAttachment3D` nodes, or transfer skin weights at runtime.
- The GLB model is the actor's only visual body; there is no procedural block-mannequin fallback. The actor's procedurally-generated geometry is limited to the optional `DebugBox` bounding-box gizmo and the optional skeleton bone-debug lines.

### Capability Scope

| Capability | Status | Current contract or scope |
| --- | --- | --- |
| Idle, walk, and run | Current | Camera-relative XZ movement with validated `idle`, `walk`, and `run` model clips. |
| Cosmetic jump | Current | A short visual arc; the collision capsule remains planted and cannot clear obstacles or gaps. |
| Physical fall and landing | Current | Gravity applies when the body is unsupported outside the cosmetic jump window. There is no fall damage or dedicated landing animation. |
| Inspect and talk | Current | One contextual inspect request selects a nearby story subject and dispatches through `StoryInteractionCoordinator`. |
| Contact-based dynamic pushing | Current | Contact with an unfrozen `RigidBody3D` applies a small capped impulse; this is not an aligned Push action or puzzle-object framework. |
| Physical traversal jump | Required planned | Add a physical collision-body arc with numeric clearance fixtures and recovery rules. |
| Carry | Required planned | Add typed light/medium carryables, placement validation, movement restrictions, and reset behavior. |
| Deliberate push/pull | Required planned | Add constrained target alignment and deterministic puzzle-object movement distinct from contact pushing. |
| Sit | Required planned | Add authored seat/exit anchors, animation, camera continuity, and immediate player-controlled exit. |
| Ladder climbing | Required planned | Add authored ladder paths, safe mount/dismount anchors, vertical locomotion, animation, and recovery. |
| Cooperative physical tasks and NPC-assisted traversal | Out of scope | These remain separate from the required player-action set until a route and resident-behavior contract owns them. |

The current playable build contains only the Current capabilities above. The target
character-action milestone is not complete until every Required planned capability
is implemented in an authored production slice and passes its acceptance gates.

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
- `jump()`
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
- `is_grounded()` is the preferred 3D actor grounded check; it reports Godot floor contact except during the actor's cosmetic jump window.
- `body_height` and `body_radius` update the model scale, capsule collision shape, local bounding box, and ground footprint together.
- The optional `controller` slot accepts `BaseController3D` resources such as `PlayerController3D` or `ResidentController3D`.
- `PlayerController3D` consumes the existing input map: `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_walk`, `ui_jump`, and `ui_inspect`.
- `PlayerController3D` reads input before the base controller applies movement so starts and stops affect the current controller tick.
- `camera_relative_movement` can align movement to the active `Camera3D`; when disabled, movement is world-aligned on XZ.
- Stairs expose smooth walkable ramp/platform collision beneath their stepped render meshes. `HumanBody3D` traverses those shapes through its ordinary downward grounding velocity and Godot's native `move_and_slide()` slope response; it has no stair-specific floor probes, placement queries, position rewrites, or synthetic grounded state.
- Static walls and stair side faces stay on the same native collision path, while the actor applies a small movement-direction impulse to push dynamic bodies such as balls.
- A grounded jump clears the downward planting velocity and applies its parabolic offset only to `VisualRoot`; the collision capsule remains planted so floor resolution cannot cancel the visible jump. `is_grounded()` reports false during that jump window.
- Actor placement in generated terrain must use `LowPolyWorldCoordinates3D` instead of scene-local guessed offsets.
- Terrain/building elevation following is owned by `game_world_3d`. During physics frames it raycasts a short distance below the actor against the actor collision mask so terrain, piers, and collision-bearing building parts can support the feet; if no solid surface is found, it falls back to `LowPolyTerrain3D.get_world_surface_height(...)` and the documented water-wading rule. `HumanBody3D` itself stays terrain-agnostic.

### Action Model And Input

Character behavior uses orthogonal layers instead of one mutually exclusive list
of every action:

- the locomotion layer is currently `idle`, `walk`, `run`, or physically `airborne`,
  and will add `traversal_jump` and `ladder_climb` modes;
- the current cosmetic jump is a timed visual overlay, not physical locomotion;
- the sustained action/posture layer will support `free`, `carry`, `push`, `pull`,
  or `sit`;
- inspecting and talking are one-shot requests, not sustained actor states.

Only one locomotion mode and at most one sustained action/posture may be active.
Compatibility and control restrictions must be derived from those layers rather
than encoded as combined states such as `walk_while_carrying`.

The current player input contract is:

- `WASD` or arrow keys move;
- holding `Shift` (`ui_walk`) uses the slower walk speed;
- releasing `Shift` while moving returns to the default run speed;
- `Space` (`ui_jump`) plays the cosmetic jump;
- `R` (`ui_inspect`) requests contextual inspect or talk.

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

The required planned compatibility defaults are:

| Action or posture | Allowed locomotion | Default restriction |
| --- | --- | --- |
| Free | Idle, walk, run, fall, traversal jump, or ladder climb | Full control for the active locomotion mode. |
| Carry light | Idle and walk | Run, jump, and ladder use stay disabled until a specific authored object proves they are safe. |
| Carry medium | Idle and walk | No run, jump, or ladder use. |
| Push or pull | Idle and constrained walk | No run, jump, or ladder use; movement remains aligned to the target. |
| Sit | Idle | Movement remains locked until the player exits; camera control stays available. |
| Ladder climb | Ladder locomotion with no sustained object action | No carry, push, pull, sit, or traversal jump while mounted. |

### Planned Action Ownership

The action expansion keeps physical state scene-local and story meaning semantic:

| Owner | Planned responsibility |
| --- | --- |
| `HumanBody3D` | Own locomotion mode, velocity, one physics integration step per tick, floor/air transitions, and animation requests; remain free of story rules. |
| `PlayerController3D` | Translate input into movement, jump, contextual-action, and cancel intentions without manipulating world targets. |
| `CharacterActionController3D` | Own sustained `free`, `carry`, `push`, `pull`, or `sit` state, target lifecycle, compatibility, and cleanup. |
| `WorldActionCoordinator3D` | Become the sole contextual-input and hint arbiter across physical targets and story subjects, delegating story activation to `StoryInteractionCoordinator`. |
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
back-one-level rule. Phase 0 decides whether carried-object rotation warrants
dedicated inputs; rotation is not supported until its input, prompt, behavior, and
test are approved together.

### Planned Delivery Stages

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
   behavior.
2. **Physical traversal jump.** Replace the visual-only jump with a collision-body
   arc using the approved buffer, forgiveness, air-control, ceiling, landing,
   camera, and recovery values. It must not bypass StoryEvent gates or semantic
   resume anchors.
3. **Ladder climbing.** Add a straight authored ladder path with deterministic
   mount/alignment, endpoints, clearance, constrained movement, blocked-exit,
   cancellation/fall, camera, cleanup, and recovery behavior.
4. **Carry.** Add typed light/medium carryables, an actor socket, collision policy,
   bounded shape-tested placement, movement restrictions, reset behavior, and an
   optional semantic completion id.
5. **Deliberate push/pull.** Add constrained deterministic objects with authored
   axis/path, range, alignment, blockage, release, route-protection, reset, and
   completion behavior; retain incidental `RigidBody3D` impulses only for ambient
   objects.
6. **Sit.** Add seat/exit transforms, occupancy, camera policy, animation,
   shape-tested fallback exits, immediate contextual/cancel exit, and semantic
   listening/conversation context where authored.
7. **Production hardening.** Keep rewards in StoryEvents, disable story advancement
   in `Free Walk`, deterministically settle every action during pause/recovery/unload,
   add final hints, and run the full title/New Game/Free Walk/overlay flow.

Focused validation ownership:

- `test_character_action_state_3d.tscn`: mode compatibility, target arbitration,
  cancellation/back behavior, surface-follow suspension, sitting, and cleanup
- `test_character_traversal_3d.tscn`: numeric jump/fall/recovery fixtures plus ladder
  mount, climb, blocked exit, cancel/fall, camera, and recovery behavior
- `test_character_object_actions_3d.tscn`: carry, placement, push/pull, blockage,
  bounds, reset, recovery, and incompatible-mode rejection
- existing actor, collision, environment, and production-world scenes remain green
  throughout the migration

Candidate first production proofs are Bagua for traversal jump and ladder, Piano
Ferry or Trinity for a light carry/restoration beat, Trinity for constrained
push/pull care, and the harbor or church for a reflective seat. Phase 0 must replace
those candidates with exact commitments before implementation.

The workstream is complete only when all five required actions are Current, each has
a focused fixture and authored production use, all three player models have accepted
animation coverage or an approved fallback, and no action introduces precision-
platforming gates, route softlocks, punitive recovery, or transient physics state in
`AppState`.

### Current Physics Defaults

These values describe the implementation defaults, not permanent design constants:

| Parameter | Current default |
| --- | ---: |
| Walk speed | `4.0` world units per second |
| Run speed | `7.5` world units per second |
| Cosmetic jump height | `0.48` world units |
| Cosmetic jump duration | `0.55` seconds |
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
- The cosmetic jump never clears collision, crosses gaps, reaches ledges, starts a
  physical falling arc, or gates story progress.
- Unsupported actors fall at the capped gravity speed, land through native floor
  contact, regain control immediately, and take no fall damage.
- Stairs use smooth authored ramp/platform collision and require no jump.
- Slopes use `CharacterBody3D` floor classification and native `move_and_slide()`;
  there is no bespoke speed-reduction band for steep slopes.
- Current dynamic-body contact does not align the actor, reserve a target, classify
  weight, guarantee puzzle placement, or persist object position. Critical paths
  must not depend on a freely simulated body remaining in place.

### Future Capability Gates

A future physical action needs a concrete story or exploration use, numeric
authored limits, focused automated validation, and one production-flow manual check
before it moves into Current scope.

- **Traversal jump:** define obstacle height, gap width, landing width, timings,
  input buffering, edge forgiveness, air control, takeoff rejection, camera
  response, and out-of-bounds recovery. It must remain forgiving and must not make
  precision platforming mandatory. When it becomes Current, `ui_jump` must drive
  the physical player jump and supersede the production cosmetic-only behavior
  rather than adding a second ambiguous jump input.
- **Carry:** define a typed carryable component, light/medium weight classes, pickup
  range, attachment and collision policy, rotation and placement validation,
  doorway rejection, reset behavior, and whether placement is save-relevant.
  Heavy objects are not carryable.
- **Deliberate push/pull:** use a constrained target interface distinct from
  incidental `RigidBody3D` contact; define alignment, interaction distance,
  movement, release, blockage, cancellation, route protection, and reset behavior.
- **Sit:** provide authored seat and clear exit transforms. Entry must align within
  `0.10` world units and `10` degrees unless the seat resource explicitly overrides
  those tolerances; the player may exit at any time.
- **Ladder climbing:** define a typed ladder path, mount and dismount transforms,
  climb speed, input mapping, top/bottom clearance, collision policy, animation,
  camera behavior, cancellation, blocked-exit handling, and fall recovery. Mounting
  must use the contextual interaction path unless playtesting demonstrates that an
  explicit ladder action is clearer.

Dangerous drops must remain behind authored collision while there is no player
recovery service. Before any unguarded fall ships, the world must restore the
player to a recent safe semantic anchor without damage, story-progress loss, or an
unrelated shared-state reload. Future movable objects likewise need deterministic
recovery when they leave their bounds or block required traversal.

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

- Run the production-world validation after actor scale, movement, camera, or terrain-collision changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_game_world_3d.tscn
```

- Each headless scene must log its `PASS` line and return process status `0`; assertion failures return nonzero.

The current character-action baseline is accepted when all four validations pass,
movement starts and stops in the current controller tick, holding `Shift` walks,
the cosmetic jump never bypasses collision, unsupported actors land and regain
control, static geometry and stairs remain reliable, and short story interactions
do not acquire an accidental movement lock.

## Next Steps

- Implement the required character-action workstream in staged slices: traversal
  jump and recovery, ladder climbing, carry, deliberate push/pull, then sitting and
  integrated action polish. Keep each capability behind its acceptance gates until
  its focused fixture and production-flow check pass.
- Audit and validate any optional imported clips beyond `idle`, `walk`, and `run`, then map accepted clips to actor states such as the jump window or idle gestures.
- Tune actor movement speed, camera-relative movement, `Camera3DController` follow offset, and camera orbit feel inside the first one-landmark interaction slice so gameplay scale informs visual acceptance.
- The 3D runtime maps the shared player profile to whole-model swaps:
  adult masculine → `male.glb`, adult feminine → `female.glb`, and teen →
  `boy.glb`. Resident-specific visual identity beyond the current shared model
  remains an open content decision.
