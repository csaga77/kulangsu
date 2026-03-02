# res://game/go_game/go_game.gd
@tool
class_name GoGame
extends Node2D

# Minimal Go (Weiqi/Baduk) core:
# - Click to place stones (human input)
# - Captures (groups with 0 liberties removed)
# - Optional suicide rule
# - Positional superko via board hashes
# NOTE: No AI here. AI lives in GoAIAgent and calls this class via public API.

signal board_changed()
signal turn_changed(turn_color: int)
signal move_played(cell: Vector2i, color: int)
signal game_reset()

enum Stone {
	EMPTY = 0,
	BLACK = 1,
	WHITE = 2,
}

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

@export var allow_suicide: bool = false

@export var reset_trigger: bool = false:
	set(_v):
		reset_trigger = false
		reset_game()

var m_board: PackedInt32Array
var m_turn: int = Stone.BLACK
var m_last_move: Vector2i = Vector2i(-1, -1)

# Repetition detection: hash(int) -> true
var m_seen_hashes: Dictionary = {}
var m_current_hash: int = 0

# Increments once per successful move / reset.
# Used by AI to guarantee "one move at a time".
var m_turn_token: int = 0

func _ready() -> void:
	reset_game()

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (event as InputEventMouseButton).position
		var c := _screen_to_cell(p)
		if c.x < 0:
			return
		play_move(c)

	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_R:
			reset_game()

func _draw() -> void:
	_draw_board()
	_draw_stones()
	_draw_last_move_mark()

# -----------------------
# Public API (used by GoAIAgent)
# -----------------------

func reset_game() -> void:
	m_board = PackedInt32Array()
	m_board.resize(board_size * board_size)
	for i in range(m_board.size()):
		m_board[i] = Stone.EMPTY

	m_turn = Stone.BLACK
	m_last_move = Vector2i(-1, -1)

	m_seen_hashes.clear()
	m_current_hash = _compute_board_hash()
	m_seen_hashes[m_current_hash] = true

	m_turn_token += 1

	queue_redraw()
	game_reset.emit()
	turn_changed.emit(m_turn)
	board_changed.emit()

func get_turn() -> int:
	return m_turn

func get_turn_token() -> int:
	return m_turn_token

func get_board_size() -> int:
	return board_size

func get_cell(cell: Vector2i) -> int:
	return _get_cell(cell)

func is_empty_cell(cell: Vector2i) -> bool:
	return _in_bounds(cell) and _get_cell(cell) == Stone.EMPTY

func play_move(cell: Vector2i) -> bool:
	# Returns true if move is made.
	var result := _compute_next_state_for_move_result(m_turn, cell)
	if not bool(result.get("ok", false)):
		return false

	var played_color := m_turn

	# Commit
	m_board = result["board"] as PackedInt32Array
	m_current_hash = int(result["hash"])
	m_seen_hashes[m_current_hash] = true

	m_last_move = cell
	m_turn = _other(m_turn)

	m_turn_token += 1

	queue_redraw()
	move_played.emit(cell, played_color)
	turn_changed.emit(m_turn)
	board_changed.emit()
	return true


func simulate_move(color: int, cell: Vector2i, out_info: Dictionary) -> bool:
	# IMPORTANT: must NOT mutate game state.
	var result := _compute_next_state_for_move_result(color, cell)
	if not bool(result.get("ok", false)):
		return false

	# Copy only the info fields out (keep it small and stable)
	out_info["captured"] = int(result.get("captured", 0))
	out_info["self_liberties"] = int(result.get("self_liberties", 0))
	return true


func _compute_next_state_for_move_result(color: int, cell: Vector2i) -> Dictionary:
	# Returns:
	# { ok: bool, board: PackedInt32Array, hash: int, captured: int, self_liberties: int }
	var result: Dictionary = {}

	if not _in_bounds(cell):
		result["ok"] = false
		return result
	if _get_cell_in(m_board, cell) != Stone.EMPTY:
		result["ok"] = false
		return result

	var next_board: PackedInt32Array = m_board.duplicate()
	_set_cell_in(next_board, cell, color)

	var opponent := _other(color)
	var captured_total: int = 0

	for n in _neighbors(cell):
		if _get_cell_in(next_board, n) == opponent:
			if _count_liberties_in(next_board, n) == 0:
				captured_total += _remove_group_in(next_board, n)

	if not allow_suicide:
		if _count_liberties_in(next_board, cell) == 0:
			result["ok"] = false
			return result

	var next_hash: int = _compute_board_hash_in(next_board)
	if m_seen_hashes.has(next_hash):
		result["ok"] = false
		return result

	result["ok"] = true
	result["board"] = next_board
	result["hash"] = next_hash
	result["captured"] = captured_total
	result["self_liberties"] = _count_liberties_in(next_board, cell)
	return result

# -----------------------
# Drawing helpers
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
		var a := o + Vector2(i * cell_size, 0)
		var b := o + Vector2(i * cell_size, (board_size - 1) * cell_size)
		draw_line(a, b, Color(0.12, 0.08, 0.05, 1.0), 1.0)

	for j in range(board_size):
		var a2 := o + Vector2(0, j * cell_size)
		var b2 := o + Vector2((board_size - 1) * cell_size, j * cell_size)
		draw_line(a2, b2, Color(0.12, 0.08, 0.05, 1.0), 1.0)

	for sp in _star_points(board_size):
		draw_circle(_cell_to_screen(sp), max(2.0, cell_size * 0.09), Color(0.12, 0.08, 0.05, 1.0))

	if show_coords:
		var f := ThemeDB.fallback_font
		var fs := int(max(10.0, cell_size * 0.35))
		for x in range(board_size):
			var label := _go_col_label(x)
			var px := o + Vector2(x * cell_size, -cell_size * 0.85)
			draw_string(f, px, label, HORIZONTAL_ALIGNMENT_CENTER, cell_size, fs, Color(0, 0, 0, 0.75))
		for y in range(board_size):
			var row := str(board_size - y)
			var py := o + Vector2(-cell_size * 0.95, y * cell_size + fs * 0.35)
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
				draw_arc(p, r, 0, TAU, 48, Color(0.2, 0.2, 0.2, 0.55), 1.0)

func _draw_last_move_mark() -> void:
	if m_last_move.x < 0:
		return
	var p := _cell_to_screen(m_last_move)
	var r := cell_size * stone_radius_ratio * 0.35
	var col := Color(1.0, 0.2, 0.2, 0.9)
	draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), col, 2.0)
	draw_line(p + Vector2(0, -r), p + Vector2(0, r), col, 2.0)

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

func _get_cell_in(arr: PackedInt32Array, c: Vector2i) -> int:
	if not _in_bounds(c):
		return Stone.EMPTY
	return arr[_idx(c)]

func _set_cell_in(arr: PackedInt32Array, c: Vector2i, v: int) -> void:
	if not _in_bounds(c):
		return
	arr[_idx(c)] = v

func _other(s: int) -> int:
	return Stone.WHITE if s == Stone.BLACK else Stone.BLACK

func _neighbors(c: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(c.x - 1, c.y),
		Vector2i(c.x + 1, c.y),
		Vector2i(c.x, c.y - 1),
		Vector2i(c.x, c.y + 1),
	]

func _collect_group_in(arr: PackedInt32Array, start: Vector2i) -> Array[Vector2i]:
	if not _in_bounds(start):
		return []
	var color := _get_cell_in(arr, start)
	if color == Stone.EMPTY:
		return []

	var out: Array[Vector2i] = []
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [start]
	visited[start] = true

	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		out.append(c)
		for n in _neighbors(c):
			if not _in_bounds(n):
				continue
			if visited.has(n):
				continue
			if _get_cell_in(arr, n) == color:
				visited[n] = true
				stack.append(n)

	return out

func _count_liberties_in(arr: PackedInt32Array, start: Vector2i) -> int:
	var group := _collect_group_in(arr, start)
	if group.is_empty():
		return 0
	var liberties: Dictionary = {}
	for c in group:
		for n in _neighbors(c):
			if not _in_bounds(n):
				continue
			if _get_cell_in(arr, n) == Stone.EMPTY:
				liberties[n] = true
	return liberties.size()

func _remove_group_in(arr: PackedInt32Array, start: Vector2i) -> int:
	var group := _collect_group_in(arr, start)
	for c in group:
		_set_cell_in(arr, c, Stone.EMPTY)
	return group.size()

func _compute_board_hash() -> int:
	return _compute_board_hash_in(m_board)

func _compute_board_hash_in(arr: PackedInt32Array) -> int:
	var h: int = 146959810
	for i in range(arr.size()):
		h = int(h * 16777619) ^ int(arr[i] + (i * 3))
	return h

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
