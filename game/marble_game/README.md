# marble_game

Self-contained low-poly 3D physics marble gameplay prototype.

## Integration Status

**Standalone prototype — not yet wired into the main story flow.**

`marble_game.gd` and `marble_game.tscn` define the module interface, but there is currently no trigger in `scenes/game_main.gd`, `main.gd`, or any landmark scene that instantiates or enters this module during normal gameplay.

If this module is intended to serve as a landmark mini-game (e.g. a puzzle at Bi Shan Tunnel or Long Shan Tunnel), that integration should be designed as a landmark-local controller that instantiates the module scene — see `docs/architecture.md` (Reusable Game Modules boundary) and `AGENTS.md` (Architecture Boundaries) before adding wiring.

## Contents

- `marble_game.gd` / `marble_game.tscn` — `Node3D` module root and native low-poly board scene
- `marble_game_mode.gd` — base mode class
- `marble_game_free_mode.gd` — free-play mode
- `marble_game_turn_mode.gd` — turn-based mode
- `marble_ball.gd` / `marble_ball.tscn` — faceted `RigidBody3D` marble actor
- `marble_ball_controller.gd` — base controller
- `marble_ball_player_controller.gd` — player controller with camera-ray board-plane dragging
- `marble_ball_ai_controller.gd` — AI controller
- `marble_hole.gd` — 3D hole/pull/catch target actor
- `damping_area.gd` — `Area3D` physics damping zone
- `marble_camera_3d.gd` — fixed tabletop camera composition
- `tests/test_marble_game_3d.gd` — headless 3D scene and containment smoke test

The module uses only native Godot 3D meshes and physics. It has no tilemap, 2D render, or 2D physics dependency.

## Validation

Run the focused smoke test from the project root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script game/marble_game/tests/test_marble_game_3d.gd
```
