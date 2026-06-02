# Low Poly Actor 3D Prototype

## Goal

- Provide a first 3D actor adapter for the low-poly exploration prototype.
- Mirror the important `HumanBody2D` runtime concepts without changing the current 2D overworld actor stack.
- Keep resident, controller, and story integration out of scope until a 3D world slice needs them.

## Current Status

- [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd) defines `class_name HumanBody3D`.
- [`../../characters/human_body_3d.tscn`](../../characters/human_body_3d.tscn) is the minimal actor scene.
- [`../../characters/control/base_controller_3d.gd`](../../characters/control/base_controller_3d.gd) defines `class_name BaseController3D`, the shared 3D controller base for `HumanBody3D`.
- [`../../characters/control/player_controller_3d.gd`](../../characters/control/player_controller_3d.gd) defines `class_name PlayerController3D`, a first playable input adapter that extends `BaseController3D`.
- [`../../characters/tests/test_human_body_3d.tscn`](../../characters/tests/test_human_body_3d.tscn) is the focused smoke scene.
- The current visual is a generated low-poly block mannequin assembled from simple `BoxMesh` parts.
- The actor exposes familiar adapter fields and methods:
  - `direction`
  - `is_walking`
  - `is_running`
  - `facial_mood`
  - `facial_action`
  - `configuration`
  - `move(...)`
  - `move_with_speed(...)`
  - `jump()`
  - `get_direction_vector()`
  - `set_direction_vector(...)`
  - `get_ground_rect()`
  - `global_position_changed`

## Ownership

- The runtime 2D actor remains [`../../characters/human_body_2d.gd`](../../characters/human_body_2d.gd).
- The 3D prototype actor is owned by [`../../characters/human_body_3d.gd`](../../characters/human_body_3d.gd).
- The existing `ResidentNPC`, `BaseController`, `PlayerController`, and `NPCController` remain 2D-only.
- `BaseController3D` and `PlayerController3D` mirror the 2D controller hierarchy while staying separate from `BaseController` and `PlayerController` because they use `Vector3`, `CharacterBody3D`, and XZ-plane movement.
- Do not wire `HumanBody3D` into `game_main.tscn` until a deliberate 3D world-integration phase starts.

## Contracts

- `direction` uses the same flat-angle convention as `HumanBody2D`: `0` points east, `90` points south, `180` points west, and `270` points north.
- `configuration` accepts the same high-level appearance dictionary shape used by the 2D LPC actor. The 3D prototype maps recognized variant names to a small material palette instead of composing sprite layers.
- `move(...)` and `move_with_speed(...)` consume XZ-plane `Vector3` directions.
- `get_ground_rect()` returns an XZ-plane `Rect2` footprint for future adapter code; it is not a drop-in replacement for 2D physics queries.
- The optional `controller` slot accepts `BaseController3D` resources such as `PlayerController3D`; the existing 2D `BaseController` should not be assigned to it.
- `PlayerController3D` consumes the existing input map: `ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_walk`, `ui_jump`, and `ui_inspect`.
- `camera_relative_movement` can align movement to the active `Camera3D`; when disabled, movement is world-aligned on XZ.

## Validation

- Run:

```sh
"/Applications/Godot.app/Contents/MacOS/Godot" --headless --path . --scene res://characters/tests/test_human_body_3d.tscn --quit-after 1
```

- Confirm the scene logs:

```text
PASS: HumanBody3D adapter smoke test
```

## Next Steps

- Add a 3D interaction-area adapter after the first 3D landmark hotspot exists.
- Decide whether the first 3D resident slice should use this block mannequin, billboarded LPC sprites, or a real low-poly character mesh.
