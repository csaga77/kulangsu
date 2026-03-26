# marble_game

Self-contained physics-based marble/ball gameplay prototype.

## Integration Status

**Standalone prototype — not yet wired into the main story flow.**

`marble_game.gd` and `marble_game.tscn` define the module interface, but there is currently no trigger in `scenes/game_main.gd`, `main.gd`, or any landmark scene that instantiates or enters this module during normal gameplay.

If this module is intended to serve as a landmark mini-game (e.g. a puzzle at Bi Shan Tunnel or Long Shan Tunnel), that integration should be designed as a landmark-local controller that instantiates the module scene — see `docs/architecture.md` (Reusable Game Modules boundary) and `AGENTS.md` (Architecture Boundaries) before adding wiring.

## Contents

- `marble_game.gd` / `marble_game.tscn` — module root and scene
- `marble_game_mode.gd` — base mode class
- `marble_game_free_mode.gd` — free-play mode
- `marble_game_turn_mode.gd` — turn-based mode
- `marble_ball.gd` / `marble_ball.tscn` — ball actor
- `marble_ball_controller.gd` — base controller
- `marble_ball_player_controller.gd` — player-driven controller
- `marble_ball_ai_controller.gd` — AI controller
- `marble_hole.gd` — hole/target actor
- `damping_area.gd` — physics damping zone
