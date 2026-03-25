# grid_board_game

Self-contained turn-based grid board game prototype with AI support.

## Integration Status

**Standalone prototype — not yet wired into the main story flow.**

`grid_board_game.gd` and `grid_board_game.tscn` define the module interface and its public contract (signals: `board_changed`, `turn_changed`, `move_played`, `game_reset`, `game_over`; API: `reset_game()`, `play_move()`, `simulate_move()`, `undo()`, `redo()`). However, there is currently no trigger in `main.gd`, `app_flow_root.gd`, or any landmark scene that instantiates or enters this module during normal gameplay.

The public API contract is documented in `docs/contracts.md` (Reusable Module Contracts — Grid Board Game). Update that file if signals or public methods change.

## Contents

- `grid_board_game.gd` / `grid_board_game.tscn` — module root and scene
- `board_ai_agent.gd` — AI agent for board evaluation
- `ai/` — AI strategy helpers
- `rules/` — game rule definitions
- `test_grid_board_game.tscn` — local validation scene
- `test_terminal_turn_state.gd` / `test_terminal_turn_state.tscn` — terminal-state test scene
