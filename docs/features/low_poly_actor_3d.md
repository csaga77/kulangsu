# Low Poly Actor 3D Prototype

## Goal

- Provide a first 3D actor adapter for the low-poly exploration prototype.
- Mirror the important `HumanBody2D` runtime concepts without changing the current 2D overworld actor stack.
- Keep resident, NPC, and story integration out of scope until a 3D world slice needs them.

## Current Status

- [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd) defines `class_name HumanBody3D`.
- [`../../characters/human_body_3d.tscn`](../../characters/human_body_3d.tscn) is the minimal actor scene.
- [`../../characters/low_poly_character_config.gd`](../../characters/low_poly_character_config.gd) defines deterministic seed-driven body proportions, palette choices, profile ids, and asymmetry flags.
- [`../../characters/procedural_low_poly_character_rig.gd`](../../characters/procedural_low_poly_character_rig.gd) defines the optional runtime-generated low-poly character rig with `Skeleton3D`, a stylized flat-shaded vertex-color body surface, and head/hand bone attachments.
- [`../../characters/control/base_controller_3d.gd`](../../characters/control/base_controller_3d.gd) defines `class_name BaseController3D`, the shared 3D controller base for `HumanBody3D`.
- [`../../characters/control/player_controller_3d.gd`](../../characters/control/player_controller_3d.gd) defines `class_name PlayerController3D`, a first playable input adapter that extends `BaseController3D`.
- [`../../characters/tests/test_human_body_3d.tscn`](../../characters/tests/test_human_body_3d.tscn) is the focused smoke scene covering actor API parity, current-frame controller input, placement occupancy, step-up/step-down navigation, deterministic procedural rig generation, skeleton attachments, vertex colors, and mathematical walk motion.
- [`../../characters/tests/test_low_poly_character_3d.tscn`](../../characters/tests/test_low_poly_character_3d.tscn) is the direct procedural-character preview scene with an animated primary character, seeded variants, camera, light, and smoke coverage for generated rig structure and mesh data.
- [`../../scenes/tests/test_low_poly_world_3d.tscn`](../../scenes/tests/test_low_poly_world_3d.tscn) validates the actor, controller, generated terrain collision, terrain-height following, coordinate adapter, `Camera3DController` follow/zoom/orbit behavior, style preset, five canonical postcard landmark proxies, and camera together.
- The default visual remains a generated low-poly block mannequin assembled from simple `BoxMesh` parts, with tunable body height/radius, contact shadow, stronger facing markers, and procedural walk/run bob plus limb swing.
- `HumanBody3D.use_procedural_rig` can switch the actor to the optional seeded procedural character rig. The rig is runtime-generated from code and does not depend on external mesh, texture, animation, or keyframe assets.
- The default procedural seed, `kulangsu_player`, now resolves to `formal_reference_avatar`: a slim dark-suit avatar with a light shirt, dark tie, short dark-brown hair, warm skin tone, and simplified business-character silhouette matching the current reference direction.
- The procedural rig now generates a stylized character silhouette from code: simplified anatomy, angular tapered torso/head forms, separate upper/lower limbs, hands, boots, hair locks/fringe, minimal facial details, collar/belt trim, and seed-driven accent pieces.
- The actor exposes familiar adapter fields and methods:
  - `direction`
  - `is_walking`
  - `is_running`
  - `body_height`
  - `body_radius`
  - `use_procedural_rig`
  - `procedural_seed`
  - `facial_mood`
  - `facial_action`
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
- Seeded procedural character parameters are owned by [`../../characters/low_poly_character_config.gd`](../../characters/low_poly_character_config.gd).
- Optional procedural character mesh, skeleton, and attachment-node generation are owned by [`../../characters/procedural_low_poly_character_rig.gd`](../../characters/procedural_low_poly_character_rig.gd).
- The existing `ResidentNPC`, `BaseController`, `PlayerController`, and `NPCController` remain 2D-only.
- `BaseController3D` and `PlayerController3D` mirror the 2D controller hierarchy while staying separate from `BaseController` and `PlayerController` because they use `Vector3`, `CharacterBody3D`, and XZ-plane movement.
- Do not wire `HumanBody3D` into `game_main.tscn` until a deliberate 3D world-integration phase starts.

## Contracts

- `direction` uses the same flat-angle convention as `HumanBody2D`: `0` points east, `90` points south, `180` points west, and `270` points north.
- `configuration` accepts the same high-level appearance dictionary shape used by the 2D LPC actor. The 3D prototype maps recognized variant names to a small material palette instead of composing sprite layers.
- `use_procedural_rig` is opt-in. When enabled, `HumanBody3D` hides the legacy block-body parts and shows `VisualRoot/ProceduralLowPolyCharacterRig`; when disabled, the legacy block mannequin remains the visible prototype body.
- `procedural_seed` must produce deterministic `LowPolyCharacterConfig` output for the same alphanumeric string and meaningfully different output for different strings.
- `LowPolyCharacterConfig` currently owns `profile_id`, height modifier, limb thickness, head scale, torso mass, main/accent/skin/hair colors, per-side limb scale, and per-side accent flags. The `kulangsu_player` seed is intentionally pinned to the formal reference profile instead of random palette/proportion generation.
- `ProceduralLowPolyCharacterRig` must keep the authored runtime hierarchy `Node3D -> Skeleton3D -> BodySurface/HeadAttachment/LeftHandAttachment/RightHandAttachment` so future attachments can target named bones without inspecting mesh internals.
- `ProceduralLowPolyCharacterRig` generates a stylized flat-shaded `ArrayMesh` with per-vertex albedo colors, computed face normals, renderer-facing triangle winding, and a high-roughness, specular-disabled material. Dedicated UV texture files should not be introduced for this prototype path.
- The current procedural body surface is generated as a single stylized visual mesh and is not yet skinned to the skeleton. Mathematical locomotion updates skeleton bone poses and attachment targets first; visible skinned deformation is a future step.
- `ProceduralLowPolyCharacterRig.get_style_snapshot()` returns the current model style contract: `stylized_low_poly_avatar_v1`, simplified anatomy, cartoon proportions, simple readable silhouette, minimal face primitives, flat vertex-color material profile, and no external asset dependency.
- `move(...)` and `move_with_speed(...)` consume XZ-plane `Vector3` directions.
- `get_ground_rect()` returns an XZ-plane `Rect2` footprint for future adapter code; it is not a drop-in replacement for 2D physics queries.
- `is_grounded()` is the preferred 3D actor grounded check because it includes both Godot floor contact and the actor's manual stair/floor snap support.
- `body_height` and `body_radius` update the generated low-poly body, capsule collision shape, local bounding box, and ground footprint together.
- The optional `controller` slot accepts `BaseController3D` resources such as `PlayerController3D`; the existing 2D `BaseController` should not be assigned to it.
- `PlayerController3D` consumes the existing input map: `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_walk`, `ui_jump`, and `ui_inspect`.
- `PlayerController3D` reads input before the base controller applies movement so starts and stops affect the current controller tick.
- `camera_relative_movement` can align movement to the active `Camera3D`; when disabled, movement is world-aligned on XZ.
- Stair/floor snapping may move the actor vertically or horizontally only after the current capsule shape is checked against the physics space at the candidate placement. The resolver favors a nearer higher stair face while climbing and a farther lower floor while descending so stairs do not snap the actor back to a previous landing.
- Manual stair/floor reacquisition is suspended while the actor is in its visual jump state, and `is_grounded()` reports false during that jump window. This prevents stale stair directions from pulling the actor to an older lower floor or a forward stair sample while the player repeatedly jumps near stair crests.
- Actor placement in generated terrain must use `LowPolyWorldCoordinates3D` instead of scene-local guessed offsets.
- Terrain elevation following is owned by the combined low-poly world scene. It samples `LowPolyTerrain3D.get_world_surface_height(...)` for the actor's current XZ position and applies a small clearance to `HumanBody3D.global_position.y`; in heightmap-expanded water this currently means land/seabed elevation rather than the visual water plane, while `HumanBody3D` itself stays terrain-agnostic.
- Dynamic foot IK, terrain-adaptive hip offsets, and weight-based inertia drifts are not implemented yet. Keep those in the procedural rig layer when they are added so controller and terrain ownership stay clean.

## Visual Style Contract

- Keep the tunable block mannequin as the default prototype body until the seeded procedural rig is visually proven in the terrain-plus-player validation scene.
- The current preferred 3D character direction is now runtime procedural low-poly mesh generation with a stylized, readable model, but resident/NPC integration should still wait for skinned deformation, terrain foot adaptation, and camera readability validation.
- The generated model should read as a broad-use stylized avatar: cartoon-like proportions, clean angular forms, two-eye-and-mouth facial detail, matte flat-shaded materials, and a silhouette simple enough for games, animation previews, explainer-style scenes, or avatar applications.
- Character colors should remain generated vertex-color/material values derived from high-level appearance or seed configuration until a final 3D character customization contract is chosen.
- Preserve strong directional readability in orthographic camera views; pose, face marker, body proportions, and shadow/readability matter more than animation polish at this stage.
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

- Run the direct procedural-character preview and smoke scene:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://characters/tests/test_low_poly_character_3d.tscn --quit-after 1
```

- Confirm the scene logs `PASS: LowPolyCharacter3D smoke test`. Open the same scene in the editor or run it normally to inspect the animated seeded character preview.

- Run the combined low-poly world validation after actor scale, movement, camera, or terrain-collision changes:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://scenes/tests/test_low_poly_world_3d.tscn --quit-after 1
```

- Confirm the scene logs `PASS: LowPolyWorld3D smoke test`.

## Next Steps

- Skin or otherwise bind the generated body surface to the procedural skeleton so mathematical locomotion visibly deforms the character body, not only attachment targets.
- Add terrain-aware foot targets and hip offsets inside `ProceduralLowPolyCharacterRig` after the current stair/floor snap behavior remains stable.
- Add secondary inertia offsets for hands, hair, and future clothing/gear attachments once the attachment nodes carry visible child geometry.
- Tune actor movement speed, camera-relative movement, `Camera3DController` follow offset, and camera orbit feel with the procedural rig enabled inside the combined world scene before adding landmark hotspots.
