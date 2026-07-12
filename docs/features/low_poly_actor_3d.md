# Low Poly Actor 3D

## Goal

- Provide the production 3D actor adapter for the low-poly overworld.
- Preserve the useful `HumanBody2D`-era controller concepts while using 3D movement and collision.
- Keep resident, NPC, and story rules outside the physical actor.

## Current Status

- [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd) defines `class_name HumanBody3D`.
- [`../../characters/human_body_3d.tscn`](../../characters/human_body_3d.tscn) is the minimal actor scene.
- [`../../assets/characters/`](../../assets/characters) holds the premade low-poly character models (skinned and textured). The current validated locomotion baseline is `idle`, `walk`, and `run`; imported models may include extra clips such as `dance`, `scared`, or `wave_goodbye`, but those must be validated before gameplay use. [`male.glb`](../../assets/characters/male.glb) is the default actor visual; [`boy.glb`](../../assets/characters/boy.glb) and [`female.glb`](../../assets/characters/female.glb) are interchangeable alternates assignable through `character_model_scene`.
- [`../../characters/control/base_controller_3d.gd`](../../characters/control/base_controller_3d.gd) defines `class_name BaseController3D`, the shared 3D controller base for `HumanBody3D`.
- [`../../characters/control/player_controller_3d.gd`](../../characters/control/player_controller_3d.gd) defines `class_name PlayerController3D`, a first playable input adapter that extends `BaseController3D`.
- [`../../characters/tests/test_human_body_3d.tscn`](../../characters/tests/test_human_body_3d.tscn) is the focused smoke scene covering actor API parity, current-frame controller input, placement occupancy, step-up/step-down navigation, character-model structure (instanced model, mesh, material, skeleton, and `idle`/`walk`/`run` animation clips), and the absence of the removed per-part accessory API and generated accessory nodes.
- [`../../characters/tests/test_character_collisions.tscn`](../../characters/tests/test_character_collisions.tscn) builds its own collision fixtures and validates gravity/landing, static-wall blocking, front stair ascent/descent, tagged stair-side rejection, and capped `RigidBody3D` pushing.
- [`../../scenes/tests/test_game_world_3d.tscn`](../../scenes/tests/test_game_world_3d.tscn) validates the production actor/controller, generated terrain collision and streets, terrain-height following and wading, camera follow/orbit wiring, authored-landmark collision, and runtime integration.
- `HumanBody3D` instances the GLB model under `VisualRoot/CharacterModel`, scales it to `body_height`, rotates it to face the rig's forward axis, and auto-plants its lowest point at the foot origin.
- Hair and clothing are authored as part of the selected GLB. `HumanBody3D` does not instance separate hair, pants, or jacket scenes, create accessory `BoneAttachment3D` nodes, or transfer skin weights at runtime.
- The GLB model is the actor's only visual body; there is no procedural block-mannequin fallback. The actor's procedurally-generated geometry is limited to the optional `DebugBox` bounding-box gizmo and the optional skeleton bone-debug lines.
- The actor exposes familiar adapter fields and methods:
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
- The existing `ResidentNPC`, `BaseController`, `PlayerController`, and `NPCController` remain 2D-only.
- `BaseController3D` and `PlayerController3D` mirror the 2D controller hierarchy while staying separate from `BaseController` and `PlayerController` because they use `Vector3`, `CharacterBody3D`, and XZ-plane movement.
- `game_world_3d.tscn` owns runtime placement and integration; `HumanBody3D` remains independent of story and shared app state.

## Contracts

- `direction` uses the same flat-angle convention as `HumanBody2D`: `0` points east, `90` points south, `180` points west, and `270` points north.
- `configuration` accepts and round-trips the same high-level appearance dictionary shape used by the 2D LPC actor (stored and re-emitted via `configuration_changed`). The 3D actor does not interpret per-part selections; all visible appearance comes from the selected GLB.
- `character_model_scene` is the `PackedScene` instanced for the model and defaults to `male.glb` (swap in `boy.glb` or `female.glb` for a different character). The model is scaled by `body_height / character_model_height`, rotated by `character_model_yaw_offset` (default `-90` so the model's authored facing aligns with the rig's `+Z` forward), and vertically planted so its lowest rendered point sits at the foot origin when `character_model_auto_ground` is on, with `character_model_y_offset` as an additional manual nudge.
- Hair, clothing, and other body styling must be part of `character_model_scene`; the actor intentionally exposes no separate hair, pants, jacket, attachment, or runtime skin-transfer contract.
- `draw_skeleton_bones` is an editor/runtime debug toggle (default `false`). When enabled with the GLB model active, `HumanBody3D` draws the character model's `Skeleton3D` as bone lines in a `SkeletonDebug` `ImmediateMesh` parented under the skeleton, refreshed every frame so it tracks animation; `skeleton_debug_color` sets the line color.
- Locomotion drives the model's `AnimationPlayer`: `idle` when standing, `walk` when walking, and `run` when running, looped with a short crossfade. Clip names come from `model_idle_animation` / `model_walk_animation` / `model_run_animation` and resolve case-insensitively against the imported animation list.
- The character model carries its own mesh, texture, skeleton, and animation clips; no runtime mesh generation or per-vertex color authoring is involved.
- `move(...)` and `move_with_speed(...)` consume XZ-plane `Vector3` directions.
- `get_ground_rect()` returns an XZ-plane `Rect2` footprint for future adapter code; it is not a drop-in replacement for 2D physics queries.
- `is_grounded()` is the preferred 3D actor grounded check because it includes both Godot floor contact and the actor's manual stair/floor snap support.
- `body_height` and `body_radius` update the model scale, capsule collision shape, local bounding box, and ground footprint together.
- The optional `controller` slot accepts `BaseController3D` resources such as `PlayerController3D`; the existing 2D `BaseController` should not be assigned to it.
- `PlayerController3D` consumes the existing input map: `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_walk`, `ui_jump`, and `ui_inspect`.
- `PlayerController3D` reads input before the base controller applies movement so starts and stops affect the current controller tick.
- `camera_relative_movement` can align movement to the active `Camera3D`; when disabled, movement is world-aligned on XZ.
- Stair/floor snapping may move the actor vertically or horizontally only after the current capsule shape is checked against the physics space at the candidate placement. The resolver favors a nearer higher stair face while climbing and a farther lower floor while descending so stairs do not snap the actor back to a previous landing.
- When `move_and_slide()` reports a blocking wall contact, stair/floor snapping must preserve the slid XZ position so diagonal input carries the actor along the wall instead of snapping it back into the original into-wall target. Forward floor probes remain available for ordinary stair riser step-up and step-down support. Generated stair side blockers are tagged separately; current contacts and a short ahead-of-capsule ray suppress only forward step-up, and target-floor lookups preserve that suppression so the actor cannot sample a tread through a thin side wall before contact. `RigidBody3D` contacts are excluded from static-wall classification; the actor applies a small movement-direction impulse to push dynamic bodies such as balls.
- Manual stair/floor reacquisition is suspended while the actor is in its visual jump state, and `is_grounded()` reports false during that jump window.
- Actor placement in generated terrain must use `LowPolyWorldCoordinates3D` instead of scene-local guessed offsets.
- Terrain/building elevation following is owned by `game_world_3d`. During physics frames it raycasts a short distance below the actor against the actor collision mask so terrain, piers, and collision-bearing building parts can support the feet; if no solid surface is found, it falls back to `LowPolyTerrain3D.get_world_surface_height(...)` and the documented water-wading rule. `HumanBody3D` itself stays terrain-agnostic.

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

- Run the focused collision regression after changing gravity, wall handling, stair/floor probes, placement checks, or dynamic-body pushing:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --fixed-fps 60 --path . --scene res://characters/tests/test_character_collisions.tscn
```

- Confirm it logs `PASS: HumanBody3D collision smoke test`.
- Run the production-world validation after actor scale, movement, camera, or terrain-collision changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_game_world_3d.tscn
```

- Each headless scene must log its `PASS` line and return process status `0`; assertion failures return nonzero.

## Next Steps

- Audit and validate any optional imported clips beyond `idle`, `walk`, and `run`, then map accepted clips to actor states such as the jump window or idle gestures.
- Tune actor movement speed, camera-relative movement, `Camera3DController` follow offset, and camera orbit feel inside the first one-landmark interaction slice so gameplay scale informs visual acceptance.
- The 3D runtime maps the shared player profile to whole-model swaps:
  adult masculine → `male.glb`, adult feminine → `female.glb`, and teen →
  `boy.glb`. Resident-specific visual identity beyond the current shared model
  remains an open content decision.
