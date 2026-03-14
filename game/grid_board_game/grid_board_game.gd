# res://game/grid_board_game/grid_board_game.gd
@tool
class_name GridBoardGame
extends Node2D

signal board_changed()
signal turn_changed(turn_color: int)
signal move_played(cell: Vector2i, color: int)
signal game_reset()
signal game_over(winner_color: int, win_line: Array[Vector2i])

enum Stone { EMPTY = 0, BLACK = 1, WHITE = 2 }

@export var rules: BoardRules:
	set(v):
		rules = v
		if is_inside_tree():
			reset_game()

@export var board_size: int = 19:
	set(v):
		board_size = clampi(v, 2, 25)
		reset_game()

@export var cell_size: float = 36.0:
	set(v):
		cell_size = max(8.0, v)
		queue_redraw()

@export var margin: float = 40.0:
	set(v):
		margin = max(0.0, v)
		queue_redraw()

@export var stone_radius_ratio: float = 0.42:
	set(v):
		stone_radius_ratio = clampf(v, 0.25, 0.49)
		queue_redraw()

@export var show_coords: bool = true:
	set(v):
		show_coords = v
		queue_redraw()

@export var reset_trigger: bool = false:
	set(_v):
		reset_trigger = false
		reset_game()

# Undo / Redo (ALL logic lives here)
@export var enable_undo_redo: bool = true
@export var max_history_steps: int = 256
@export var enable_shortcuts: bool = true
@export_range(1, 2, 1) var undo_step_count: int = 1

var m_board: PackedInt32Array
var m_turn: int = Stone.BLACK
var m_last_move: Vector2i = Vector2i(-1, -1)

# for AI "one move at a time"
var m_turn_token: int = 0

# game over (Gomoku)
var m_is_game_over: bool = false
var m_winner: int = Stone.EMPTY
var m_win_line: Array[Vector2i] = []

# undo/redo stacks
var m_undo_stack: Array[Dictionary] = []
var m_redo_stack: Array[Dictionary] = []

func _ready() -> void:
	if rules == null:
		rules = GoRules.new()
	reset_game()

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if enable_shortcuts and enable_undo_redo and event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		# Undo: Ctrl/Cmd + Z
		if k.keycode == KEY_Z and (k.ctrl_pressed or k.meta_pressed) and (not k.shift_pressed):
			undo()
			return
		# Redo: Ctrl/Cmd + Y OR Ctrl/Cmd + Shift + Z
		if (k.keycode == KEY_Y and (k.ctrl_pressed or k.meta_pressed)) or (k.keycode == KEY_Z and (k.ctrl_pressed or k.meta_pressed) and k.shift_pressed):
			redo()
			return

	if m_is_game_over:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		var c := _screen_to_cell(p)
		if c.x < 0:
			return
		play_move(c)

	if event is InputEventKey and event.pressed:
		var k2 := event as InputEventKey
		if k2.keycode == KEY_R:
			reset_game()

func _draw() -> void:
	_draw_board()
	_draw_stones()
	_draw_last_move_mark()
	_draw_win_line_if_any()

# -----------------------
# Public API (used by AI agents)
# -----------------------

func reset_game() -> void:
	m_board = PackedInt32Array()
	m_board.resize(board_size * board_size)
	for i in range(m_board.size()):
		m_board[i] = Stone.EMPTY

	m_turn = Stone.BLACK
	m_last_move = Vector2i(-1, -1)

	m_is_game_over = false
	m_winner = Stone.EMPTY
	m_win_line = []

	m_turn_token += 1

	if rules:
		rules.reset(m_board, board_size)

	_clear_history()
	_push_current_snapshot()

	queue_redraw()
	game_reset.emit()
	turn_changed.emit(m_turn)
	board_changed.emit()

func get_turn() -> int:
	return m_turn

func get_turn_token() -> int:
	return m_turn_token

func is_game_over() -> bool:
	return m_is_game_over

func get_winner() -> int:
	return m_winner

func get_board_size() -> int:
	return board_size

func get_cell(cell: Vector2i) -> int:
	return _get_cell(cell)

func is_empty_cell(cell: Vector2i) -> bool:
	return _in_bounds(cell) and _get_cell(cell) == Stone.EMPTY

func play_move(cell: Vector2i) -> bool:
	if m_is_game_over:
		return false
	if rules == null:
		return false

	var played_color := m_turn
	var result := rules.compute_move(m_board, board_size, played_color, cell)
	if not bool(result.get("ok", false)):
		return false

	_clear_redo()

	m_board = result["board"] as PackedInt32Array
	m_last_move = cell

	_apply_rules_commit_result(result)

	if not m_is_game_over:
		m_turn = _other(m_turn)
	m_turn_token += 1

	_push_current_snapshot()

	queue_redraw()
	move_played.emit(cell, played_color)
	turn_changed.emit(m_turn)
	board_changed.emit()
	return true

func simulate_move(color: int, cell: Vector2i, out_info: Dictionary) -> bool:
	if rules == null:
		return false
	return rules.simulate_move(m_board, board_size, color, cell, out_info)

# -----------------------
# Undo / Redo API
# -----------------------

func can_undo() -> bool:
	return enable_undo_redo and m_undo_stack.size() >= 2

func can_redo() -> bool:
	return enable_undo_redo and (not m_redo_stack.is_empty())

func undo() -> bool:
	if not can_undo():
		return false

	var steps := mini(undo_step_count, m_undo_stack.size() - 1)
	var changed := false

	for _i in range(steps):
		if m_undo_stack.size() < 2:
			break
		var current: Dictionary = m_undo_stack.pop_back()
		m_redo_stack.append(current)
		_trim_history(m_redo_stack)

		var prev := m_undo_stack[m_undo_stack.size() - 1]
		_restore_snapshot(prev)
		changed = true

	if changed:
		m_turn_token += 1
		queue_redraw()
		turn_changed.emit(m_turn)
		board_changed.emit()

	return changed

func redo() -> bool:
	if not can_redo():
		return false

	var steps := mini(undo_step_count, m_redo_stack.size())
	var changed := false

	for _i in range(steps):
		if m_redo_stack.is_empty():
			break
		var next: Dictionary = m_redo_stack.pop_back()
		_restore_snapshot(next)

		m_undo_stack.append(next)
		_trim_history(m_undo_stack)
		changed = true

	if changed:
		m_turn_token += 1
		queue_redraw()
		turn_changed.emit(m_turn)
		board_changed.emit()

	return changed

# -----------------------
# Rules commit handling
# -----------------------

func _apply_rules_commit_result(result: Dictionary) -> void:
	# Go: accept hash for superko state if rule supports it.
	if result.has("hash") and rules is GoRules:
		(rules as GoRules).accept_hash(int(result["hash"]))

	# Any rules: game_over fields (Gomoku)
	if bool(result.get("game_over", false)):
		m_is_game_over = true
		m_winner = int(result.get("winner", Stone.EMPTY))
		m_win_line = result.get("win_line", []) as Array[Vector2i]
		game_over.emit(m_winner, m_win_line)
	else:
		m_is_game_over = false
		m_winner = Stone.EMPTY
		m_win_line = []

# -----------------------
# Snapshot helpers
# -----------------------

func _clear_history() -> void:
	m_undo_stack.clear()
	m_redo_stack.clear()

func _clear_redo() -> void:
	m_redo_stack.clear()

func _trim_history(stack: Array[Dictionary]) -> void:
	if max_history_steps <= 0:
		return
	while stack.size() > max_history_steps:
		stack.pop_front()

func _push_current_snapshot() -> void:
	if not enable_undo_redo:
		return
	m_undo_stack.append(_capture_snapshot())
	_trim_history(m_undo_stack)

func _capture_snapshot() -> Dictionary:
	return {
		"board": m_board.duplicate(),
		"turn": m_turn,
		"last_move": m_last_move,
		"is_game_over": m_is_game_over,
		"winner": m_winner,
		"win_line": m_win_line.duplicate(),
		"rules_state": (rules.export_state() if rules != null else {}),
	}

func _restore_snapshot(snap: Dictionary) -> void:
	m_board = snap["board"] as PackedInt32Array
	m_turn = int(snap["turn"])
	m_last_move = snap["last_move"] as Vector2i
	m_is_game_over = bool(snap["is_game_over"])
	m_winner = int(snap["winner"])
	m_win_line = snap["win_line"] as Array[Vector2i]

	if rules != null:
		rules.import_state(snap.get("rules_state", {}) as Dictionary)

# -----------------------
# Drawing helpers (RESTORED)
# -----------------------

func _board_origin() -> Vector2:
	return Vector2(margin, margin)

func _board_end() -> Vector2:
	return _board_origin() + Vector2((board_size - 1) * cell_size, (board_size - 1) * cell_size)

func _cell_to_screen(c: Vector2i) -> Vector2:
	return _board_origin() + Vector2(float(c.x) * cell_size, float(c.y) * cell_size)

func _screen_to_cell(p: Vector2) -> Vector2i:
	var o := _board_origin()
	var e := _board_end()

	if p.x < o.x - cell_size * 0.5 or p.y < o.y - cell_size * 0.5:
		return Vector2i(-1, -1)
	if p.x > e.x + cell_size * 0.5 or p.y > e.y + cell_size * 0.5:
		return Vector2i(-1, -1)

	var fx := (p.x - o.x) / cell_size
	var fy := (p.y - o.y) / cell_size
	var cx := int(round(fx))
	var cy := int(round(fy))

	if cx < 0 or cy < 0 or cx >= board_size or cy >= board_size:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

func _draw_board() -> void:
	var o := _board_origin()
	var e := _board_end()

	draw_rect(
		Rect2(
			o - Vector2(cell_size * 0.6, cell_size * 0.6),
			(e - o) + Vector2(cell_size * 1.2, cell_size * 1.2)
		),
		Color(0.93, 0.78, 0.52, 1.0),
		true
	)

	for i in range(board_size):
		var a := o + Vector2(float(i) * cell_size, 0.0)
		var b := o + Vector2(float(i) * cell_size, float(board_size - 1) * cell_size)
		draw_line(a, b, Color(0.12, 0.08, 0.05, 1.0), 1.0)

	for j in range(board_size):
		var a2 := o + Vector2(0.0, float(j) * cell_size)
		var b2 := o + Vector2(float(board_size - 1) * cell_size, float(j) * cell_size)
		draw_line(a2, b2, Color(0.12, 0.08, 0.05, 1.0), 1.0)

	for sp in _star_points(board_size):
		draw_circle(_cell_to_screen(sp), max(2.0, cell_size * 0.09), Color(0.12, 0.08, 0.05, 1.0))

	if show_coords:
		var f := ThemeDB.fallback_font
		var fs := int(max(10.0, cell_size * 0.35))

		for x in range(board_size):
			var label := _go_col_label(x)
			var px := o + Vector2(float(x) * cell_size, -cell_size * 0.85)
			draw_string(f, px, label, HORIZONTAL_ALIGNMENT_CENTER, cell_size, fs, Color(0, 0, 0, 0.75))

		for y in range(board_size):
			var row := str(board_size - y)
			var py := o + Vector2(-cell_size * 0.95, float(y) * cell_size + fs * 0.35)
			draw_string(f, py, row, HORIZONTAL_ALIGNMENT_LEFT, cell_size, fs, Color(0, 0, 0, 0.75))

func _draw_stones() -> void:
	var r := cell_size * stone_radius_ratio
	for y in range(board_size):
		for x in range(board_size):
			var s := m_board[_idx(Vector2i(x, y))]
			if s == Stone.EMPTY:
				continue
			var p := _cell_to_screen(Vector2i(x, y))
			if s == Stone.BLACK:
				draw_circle(p, r, Color(0.05, 0.05, 0.05, 1.0))
				draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.35, Color(0.25, 0.25, 0.25, 0.25))
			else:
				draw_circle(p, r, Color(0.95, 0.95, 0.95, 1.0))
				draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.35, Color(1, 1, 1, 0.55))
				draw_arc(p, r, 0.0, TAU, 48, Color(0.2, 0.2, 0.2, 0.55), 1.0)

func _draw_last_move_mark() -> void:
	if m_last_move.x < 0:
		return
	var p := _cell_to_screen(m_last_move)
	var r := cell_size * stone_radius_ratio * 0.35
	var col := Color(1.0, 0.2, 0.2, 0.9)
	draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), col, 2.0)
	draw_line(p + Vector2(0, -r), p + Vector2(0, r), col, 2.0)

func _draw_win_line_if_any() -> void:
	if m_win_line.is_empty():
		return
	for i in range(m_win_line.size() - 1):
		var a := _cell_to_screen(m_win_line[i])
		var b := _cell_to_screen(m_win_line[i + 1])
		draw_line(a, b, Color(1.0, 0.2, 0.2, 0.9), max(2.0, cell_size * 0.10))

# -----------------------
# Internal board helpers
# -----------------------

func _idx(c: Vector2i) -> int:
	return c.y * board_size + c.x

func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < board_size and c.y < board_size

func _get_cell(c: Vector2i) -> int:
	if not _in_bounds(c):
		return Stone.EMPTY
	return m_board[_idx(c)]

func _other(s: int) -> int:
	return Stone.WHITE if s == Stone.BLACK else Stone.BLACK

func _star_points(n: int) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	if n < 7:
		return pts
	if n >= 19:
		var a := 3
		var b := n - 4
		var mid := n / 2
		pts = [
			Vector2i(a, a), Vector2i(a, mid), Vector2i(a, b),
			Vector2i(mid, a), Vector2i(mid, mid), Vector2i(mid, b),
			Vector2i(b, a), Vector2i(b, mid), Vector2i(b, b),
		]
	elif n >= 13:
		var a13 := 3
		var b13 := n - 4
		var mid13 := n / 2
		pts = [
			Vector2i(a13, a13), Vector2i(a13, b13),
			Vector2i(b13, a13), Vector2i(b13, b13),
			Vector2i(mid13, mid13),
		]
	else:
		var a9 := 2
		var b9 := n - 3
		var mid9 := n / 2
		pts = [
			Vector2i(a9, a9), Vector2i(a9, b9),
			Vector2i(b9, a9), Vector2i(b9, b9),
			Vector2i(mid9, mid9),
		]

	var filtered: Array[Vector2i] = []
	for p in pts:
		if _in_bounds(p):
			filtered.append(p)
	return filtered

func _go_col_label(x: int) -> String:
	var alphabet := "ABCDEFGHJKLMNOPQRSTUVWXYZ" # skip I
	if x < 0:
		return ""
	if x >= alphabet.length():
		return str(x + 1)
	return alphabet.substr(x, 1)
