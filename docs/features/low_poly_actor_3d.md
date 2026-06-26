# Low Poly Actor 3D Prototype

## Goal

- Provide a first 3D actor adapter for the low-poly exploration prototype.
- Mirror the important `HumanBody2D` runtime concepts without changing the current 2D overworld actor stack.
- Keep resident, NPC, and story integration out of scope until a 3D world slice needs them.

## Current Status

- [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd) defines `class_name HumanBody3D`.
- [`../../characters/human_body_3d.tscn`](../../characters/human_body_3d.tscn) is the minimal actor scene.
- [`../../assets/characters/`](../../assets/characters) holds the premade low-poly character models (skinned, textured, ~2k triangles each). The current validated locomotion baseline is `idle`, `walk`, and `run`; imported models may include extra clips such as `dance`, `scared`, or `wave_goodbye`, but those must be validated before gameplay use. [`boy.glb`](../../assets/characters/boy.glb) is the default actor visual; [`female.glb`](../../assets/characters/female.glb) and [`male.glb`](../../assets/characters/male.glb) are interchangeable alternates assignable through `character_model_scene` (all share the same height and feet-at-origin pivot).
- [`../../characters/control/base_controller_3d.gd`](../../characters/control/base_controller_3d.gd) defines `class_name BaseController3D`, the shared 3D controller base for `HumanBody3D`.
- [`../../characters/control/player_controller_3d.gd`](../../characters/control/player_controller_3d.gd) defines `class_name PlayerController3D`, a first playable input adapter that extends `BaseController3D`.
- [`../../characters/tests/test_human_body_3d.tscn`](../../characters/tests/test_human_body_3d.tscn) is the focused smoke scene covering actor API parity, current-frame controller input, placement occupancy, step-up/step-down navigation, character-model structure (instanced model, mesh, material, and `idle`/`walk`/`run` animation clips), hair-node structure (head-bone `BoneAttachment3D`, instanced `HairModel` mesh, and `use_hair_model` visibility toggle), pants-node structure (skinned `PantsSkinnedMesh` under the `Skeleton3D` with per-vertex bone weights, skin binds to leg bones, and `use_pants_model` visibility toggle), and jacket-node structure (upper-spine-bone `BoneAttachment3D`, instanced `JacketModel` mesh, and `use_jacket_model` visibility toggle).
- [`../../scenes/tests/test_low_poly_world_3d.tscn`](../../scenes/tests/test_low_poly_world_3d.tscn) validates the actor, controller, generated terrain collision, terrain-height following, coordinate adapter, `Camera3DController` follow/zoom/orbit behavior, style preset, five canonical postcard landmark proxies, and camera together.
- `HumanBody3D` instances the GLB model under `VisualRoot/CharacterModel`, scales it to `body_height`, rotates it to face the rig's forward axis, and auto-plants its lowest point at the foot origin.
- A separate hair model is instanced in its own `HairModel` node under a `HairAttachment` `BoneAttachment3D` bound to the character model's `Head` bone, so the hair tracks head animation and can be swapped independently of the body. It defaults to [`spiky_hair.glb`](../../assets/characters/spiky_hair.glb).
- A separate pants model defaults to runtime skinning: the unskinned [`pants.glb`](../../assets/characters/pants.glb) source mesh is baked into the character skeleton's rest space, and each pants vertex inherits the body mesh's own bone weights from the nearest point on the body surface (so the pants wrap around the bones and deform exactly like the legs they cover). The result is rebuilt as a `PantsSkinnedMesh` `MeshInstance3D` parented under the model's `Skeleton3D`. Setting `pants_skinned` to `false` falls back to the rigid `PantsModel` / `PantsAttachment` `BoneAttachment3D` bound to the `Pelvis` bone.
- A separate jacket model is instanced in its own `JacketModel` node under a `JacketAttachment` `BoneAttachment3D` bound to the character model's `Spine02` bone, so the jacket rides along with upper-torso motion and can be swapped independently of the body. It defaults to [`jacket.glb`](../../assets/characters/jacket.glb).
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
  - `use_hair_model`
  - `hair_model_scene`
  - `hair_attach_bone`
  - `hair_model_scale`
  - `hair_model_offset`
  - `hair_model_yaw_offset`
  - `use_pants_model`
  - `pants_skinned`
  - `pants_model_scene`
  - `pants_attach_bone`
  - `pants_model_scale`
  - `pants_model_offset`
  - `pants_model_yaw_offset`
  - `use_jacket_model`
  - `jacket_model_scene`
  - `jacket_attach_bone`
  - `jacket_model_scale`
  - `jacket_model_offset`
  - `jacket_model_yaw_offset`
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

- The runtime 2D actor remains [`../../characters/human_body_2d.gd`](../../characters/human_body_2d.gd).
- The 3D prototype actor is owned by [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd).
- The character model asset lives in [`../../assets/characters/`](../../assets/characters); `HumanBody3D` owns its instancing, scaling, orientation, grounding, and animation mapping.
- The existing `ResidentNPC`, `BaseController`, `PlayerController`, and `NPCController` remain 2D-only.
- `BaseController3D` and `PlayerController3D` mirror the 2D controller hierarchy while staying separate from `BaseController` and `PlayerController` because they use `Vector3`, `CharacterBody3D`, and XZ-plane movement.
- Do not wire `HumanBody3D` into `game_main.tscn` until the parallel 3D lane has green combined smoke tests, accepted visual QA screenshots, a stable interaction contract, an acceptable performance budget, and a written story/resident ownership plan.

## Contracts

- `direction` uses the same flat-angle convention as `HumanBody2D`: `0` points east, `90` points south, `180` points west, and `270` points north.
- `configuration` accepts and round-trips the same high-level appearance dictionary shape used by the 2D LPC actor (stored and re-emitted via `configuration_changed`). The 3D actor no longer maps it to per-part colors, since the procedural block mannequin that consumed those selections has been removed; appearance comes from the GLB model and hair instead.
- `character_model_scene` is the `PackedScene` instanced for the model and defaults to `boy.glb` (swap in `female.glb` or `male.glb` for a different character). The model is scaled by `body_height / character_model_height`, rotated by `character_model_yaw_offset` (default `-90` so the model's authored facing aligns with the rig's `+Z` forward), and vertically planted so its lowest rendered point sits at the foot origin when `character_model_auto_ground` is on, with `character_model_y_offset` as an additional manual nudge.
- `use_hair_model` defaults to `true`. When enabled (and the GLB character model is active), `HumanBody3D` instances `hair_model_scene` into a dedicated `HairModel` node under a `HairAttachment` `BoneAttachment3D` on the skeleton bone named by `hair_attach_bone` (default `Head`), so the hair follows head animation. `hair_model_scene` defaults to `spiky_hair.glb` and can be swapped per instance; `hair_model_scale`, `hair_model_offset`, and `hair_model_yaw_offset` fine-tune placement in bone-local space.
- `use_pants_model` defaults to `true`. When enabled (and the GLB character model is active), `HumanBody3D` shows the pants. `pants_skinned` defaults to `true`: the source mesh is skinned at runtime by transferring the body mesh's own bone weights onto each pants vertex (closest point on the body surface), then rebuilt as a `PantsSkinnedMesh` under the `Skeleton3D` so it deforms with the legs exactly as the body does. The pants source mesh is authored in the character model's space (same as the body), so in skinned mode it maps straight into the body mesh's local (bind) space with no bone anchor; `pants_model_offset`, `pants_model_yaw_offset`, and `pants_model_scale` provide alignment tweaks before the weight transfer. `pants_attach_bone` (default `Pelvis`) is only used by the rigid fallback as its `BoneAttachment3D` anchor. With `pants_skinned` set to `false`, those same fields instead place a rigid `PantsModel` under a `PantsAttachment` `BoneAttachment3D`. `pants_model_scene` defaults to `pants.glb` and can be swapped per instance. The weight transfer is closest-point (not hand-painted), so it closely follows the body's deformation but can still show minor artifacts where pants extend past the body silhouette.
- `use_jacket_model` defaults to `true`. When enabled (and the GLB character model is active), `HumanBody3D` instances `jacket_model_scene` into a dedicated `JacketModel` node under a `JacketAttachment` `BoneAttachment3D` on the skeleton bone named by `jacket_attach_bone` (default `Spine02`), so the jacket follows upper-torso motion. `jacket_model_scene` defaults to `jacket.glb` and can be swapped per instance; `jacket_model_scale`, `jacket_model_offset`, and `jacket_model_yaw_offset` fine-tune placement in bone-local space.
- `draw_skeleton_bones` is an editor/runtime debug toggle (default `false`). When enabled with the GLB model active, `HumanBody3D` draws the character model's `Skeleton3D` as bone lines in a `SkeletonDebug` `ImmediateMesh` parented under the skeleton, refreshed every frame so it tracks animation; `skeleton_debug_color` sets the line color. Useful for verifying the hair attach bone.
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
- When `move_and_slide()` reports a blocking wall contact, stair/floor snapping must preserve the slid XZ position and suppress forward step-floor probes so diagonal input carries the actor along the wall instead of snapping it back into the original into-wall target or climbing through side blockers.
- Manual stair/floor reacquisition is suspended while the actor is in its visual jump state, and `is_grounded()` reports false during that jump window.
- Actor placement in generated terrain must use `LowPolyWorldCoordinates3D` instead of scene-local guessed offsets.
- Terrain elevation following is owned by the combined low-poly world scene. It samples `LowPolyTerrain3D.get_world_surface_height(...)` for the actor's current XZ position and applies a small clearance to `HumanBody3D.global_position.y`, while `HumanBody3D` itself stays terrain-agnostic.

## Visual Style Contract

- The default 3D character is the premade low-poly GLB model with baked-texture detailing and skinned `idle`/`walk`/`run` animation.
- The model should read as a broad-use stylized avatar with a silhouette simple enough for games, animation previews, explainer-style scenes, or avatar applications.
- Preserve strong directional readability in orthographic camera views; the model's facing, proportions, and grounding matter more than animation polish at this stage.
- Tune the player against the style-preset camera and five-landmark proxy blockout before changing the actor asset direction.

## Validation

- Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://characters/tests/test_human_body_3d.tscn --quit-after 1
```

- Confirm the scene logs:

```text
PASS: HumanBody3D adapter smoke test
```

- Run the combined low-poly world validation after actor scale, movement, camera, or terrain-collision changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_world_3d.tscn --quit-after 1
```

- Confirm the scene logs `PASS: LowPolyWorld3D smoke test`.

## Next Steps

- Audit and validate any optional imported clips beyond `idle`, `walk`, and `run`, then map accepted clips to actor states such as the jump window or idle gestures.
- Tune actor movement speed, camera-relative movement, `Camera3DController` follow offset, and camera orbit feel with the model inside the combined world scene before adding landmark hotspots.
- Decide a final 3D character customization contract (swappable models, tints, or accessories) before wiring residents and NPCs to the 3D actor.
