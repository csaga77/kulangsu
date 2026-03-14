# Grid Board Game Design

Read [`docs/design_brief.md`](docs/design_brief.md) first for the minimum-token project summary. This document describes the reusable board-game module in [`game/grid_board_game`](game/grid_board_game) as it exists today.

## Purpose

`grid_board_game` is a small reusable tabletop module for turn-based stone placement games. It currently supports:

- Go-style placement, capture, suicide checks, and positional superko through [`game/grid_board_game/rules/go_rules.gd`](game/grid_board_game/rules/go_rules.gd)
- Gomoku-style line wins plus optional exact-five and Renju restrictions through [`game/grid_board_game/rules/gomoku_rules.gd`](game/grid_board_game/rules/gomoku_rules.gd)
- Optional AI turns through [`game/grid_board_game/board_ai_agent.gd`](game/grid_board_game/board_ai_agent.gd)
- Local undo/redo state handled by [`game/grid_board_game/grid_board_game.gd`](game/grid_board_game/grid_board_game.gd)

The module is a sandbox component, not a full island-facing feature yet.

## Files

- Scene shell: [`game/grid_board_game/grid_board_game.tscn`](game/grid_board_game/grid_board_game.tscn)
- Main controller and renderer: [`game/grid_board_game/grid_board_game.gd`](game/grid_board_game/grid_board_game.gd)
- Base rules contract: [`game/grid_board_game/rules/board_rules.gd`](game/grid_board_game/rules/board_rules.gd)
- Go rules: [`game/grid_board_game/rules/go_rules.gd`](game/grid_board_game/rules/go_rules.gd)
- Gomoku rules: [`game/grid_board_game/rules/gomoku_rules.gd`](game/grid_board_game/rules/gomoku_rules.gd)
- AI scheduler: [`game/grid_board_game/board_ai_agent.gd`](game/grid_board_game/board_ai_agent.gd)
- AI strategies: [`game/grid_board_game/ai`](game/grid_board_game/ai)
- Manual test scene: [`game/grid_board_game/test_grid_board_game.tscn`](game/grid_board_game/test_grid_board_game.tscn)
- Terminal turn regression scene: [`game/grid_board_game/test_terminal_turn_state.tscn`](game/grid_board_game/test_terminal_turn_state.tscn)

## Current Structure

### `GridBoardGame`

[`game/grid_board_game/grid_board_game.gd`](game/grid_board_game/grid_board_game.gd) owns the live match state:

- Flat `PackedInt32Array` board storage
- Active turn, last move marker, and game-over fields
- Undo and redo snapshots
- Rendering of board, stones, coordinates, and win line
- Mouse and keyboard input for local testing
- Public API used by rules and AI

It emits the module-level signals:

- `board_changed`
- `turn_changed(turn_color)`
- `move_played(cell, color)`
- `game_reset`
- `game_over(winner_color, win_line)`

Design rule:
`GridBoardGame` should remain the single owner of match lifecycle, history, and rendering. Rule resources decide whether a move is legal and what board state it produces, but they should not own turn progression, undo stacks, or drawing.

### `BoardRules`

[`game/grid_board_game/rules/board_rules.gd`](game/grid_board_game/rules/board_rules.gd) defines the swap-in rules interface:

- `reset(board, board_size)`
- `simulate_move(board, board_size, color, cell, out_info)`
- `compute_move(board, board_size, color, cell)`
- `export_state()`
- `import_state(state)`

Design rule:
`compute_move()` returns a new board snapshot plus rule-specific metadata. That keeps the core board node generic while still allowing rule-specific state such as superko memory.

### Go Rules

[`game/grid_board_game/rules/go_rules.gd`](game/grid_board_game/rules/go_rules.gd) currently implements:

- Occupancy validation
- Opponent capture after placement
- Optional suicide prevention
- Positional superko via seen-board hashes

Current boundary:
This is not yet a full scored Go loop. There is no explicit pass action, territory scoring, or end-of-game scoring flow in the module today.

### Gomoku Rules

[`game/grid_board_game/rules/gomoku_rules.gd`](game/grid_board_game/rules/gomoku_rules.gd) currently implements:

- Occupancy validation
- Line-win detection from the latest move
- Optional exact-five mode
- Optional Renju-style black restrictions
- Win-line extraction for rendering

Design rule:
Rule-specific win detection should stay in the rules resource so the board controller only needs to react to generic `game_over`, `winner`, and `win_line` fields.

### AI Layer

[`game/grid_board_game/board_ai_agent.gd`](game/grid_board_game/board_ai_agent.gd) is a turn scheduler, not the decision maker. It:

- Binds to a `GridBoardGame`
- Watches turn changes and resets
- Uses `m_turn_token` to ensure one move per turn
- Waits for an optional delay before moving

Strategy classes in [`game/grid_board_game/ai`](game/grid_board_game/ai) choose cells:

- [`game/grid_board_game/ai/go_ai_strategy.gd`](game/grid_board_game/ai/go_ai_strategy.gd) prefers captures, liberties, and center control
- [`game/grid_board_game/ai/gomoku_ai_strategy.gd`](game/grid_board_game/ai/gomoku_ai_strategy.gd) prefers immediate wins, blocks, line growth, and center bias

Design rule:
Keep scheduling and move evaluation separate. Turn timing belongs in the agent; board heuristics belong in strategies.

## Data Flow

1. The player or AI requests a move on a board cell.
2. `GridBoardGame.play_move()` asks the active `BoardRules` resource to `compute_move()`.
3. The rules resource returns legality plus a next board snapshot and any rule metadata.
4. `GridBoardGame` commits the result, updates history, advances the match state, and emits signals.
5. The AI agent reacts to the next `turn_changed` signal and schedules another move if needed.

Terminal-state rule:
When a move ends the match, `GridBoardGame` keeps `m_turn` on the player who made that winning move instead of advancing to a nonexistent next turn.

## Rendering And Input

The board is drawn directly in `_draw()` rather than assembled from per-cell nodes. This keeps the scene light and makes board size and rule swaps simple.

Current implementation details:

- Board geometry is derived from `board_size`, `cell_size`, and `margin`
- Stones are drawn as circles with a simple highlight pass
- The latest move is marked with a red cross
- Gomoku wins are shown with a red line
- Coordinate labels are optional

Current validation coverage is strongest for the origin-placed manual test scene in [`game/grid_board_game/test_grid_board_game.tscn`](game/grid_board_game/test_grid_board_game.tscn). Transformed placements and UI embedding still need explicit coverage.

## Undo / Redo

Undo and redo are snapshot-based rather than command-based. Each snapshot stores:

- Board contents
- Active turn
- Last move
- Game-over state
- Winner and win line
- Rule-specific exported state

Design rule:
If a new rules resource carries internal state, it must fully round-trip through `export_state()` and `import_state()` or undo/redo will desynchronize rule logic from the board.

## Test Scene

[`game/grid_board_game/test_grid_board_game.tscn`](game/grid_board_game/test_grid_board_game.tscn) is the current smoke-test scene. It provides:

- A live `GridBoardGame` instance
- A Gomoku rules resource override
- A single AI agent
- Buttons for restart, undo, and redo

This scene is useful for interaction checks, but it is not a substitute for targeted automated tests around rules, AI legality, and state restoration.

[`game/grid_board_game/test_terminal_turn_state.tscn`](game/grid_board_game/test_terminal_turn_state.tscn) is a focused regression scene that boots, plays a forced Gomoku win, and exits. It verifies that terminal match state keeps the winning player as the visible turn and as the final `turn_changed` value.

## Known Gaps

- Go mode is a move-legality sandbox today, not a full pass-and-score implementation.
- Rule combinations such as exact-five and Renju need explicit AI-focused coverage, not just rule-engine coverage.
- Board interaction has only been exercised in the origin-positioned test scene so far.
- There are no dedicated automated tests for undo/redo state restoration across both rule sets.

## Extension Guidance

When extending this module:

- Add new game variants as `BoardRules` implementations first.
- Keep render-agnostic legality inside rules, not in the board controller.
- Preserve the signal contract so AI and future UI wrappers remain decoupled.
- Prefer adding focused automated checks before increasing AI complexity.
- If the board will be embedded in a larger UI flow, validate transformed input, focus handling, and match-end presentation early.
