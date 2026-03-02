@tool
class_name GoRules
extends BoardRules

@export var allow_suicide: bool = false

# Positional superko: remember all seen board hashes
var m_seen_hashes: Dictionary = {}
var m_current_hash: int = 0

func reset(board: PackedInt32Array, _board_size: int) -> void:
	m_seen_hashes.clear()
	m_current_hash = _compute_board_hash_in(board)
	m_seen_hashes[m_current_hash] = true

func accept_hash(hash_value: int) -> void:
	m_current_hash = hash_value
	m_seen_hashes[m_current_hash] = true

func export_state() -> Dictionary:
	var seen_copy: Dictionary = {}
	for k in m_seen_hashes.keys():
		seen_copy[k] = true
	return {
		"current_hash": m_current_hash,
		"seen_hashes": seen_copy,
	}

func import_state(state: Dictionary) -> void:
	m_current_hash = int(state.get("current_hash", 0))
	m_seen_hashes.clear()
	var seen := state.get("seen_hashes", {}) as Dictionary
	for k in seen.keys():
		m_seen_hashes[k] = true

func simulate_move(
	board: PackedInt32Array,
	board_size: int,
	color: int,
	cell: Vector2i,
	out_info: Dictionary
) -> bool:
	var result := compute_move(board, board_size, color, cell)
	if not bool(result.get("ok", false)):
		return false
	out_info["captured"] = int(result.get("captured", 0))
	out_info["self_liberties"] = int(result.get("self_liberties", 0))
	return true

func compute_move(
	board: PackedInt32Array,
	board_size: int,
	color: int,
	cell: Vector2i
) -> Dictionary:
	var result: Dictionary = {}

	if not _in_bounds(board_size, cell):
		result["ok"] = false
		return result
	if _get_cell_in(board, board_size, cell) != GridBoardGame.Stone.EMPTY:
		result["ok"] = false
		return result

	var next_board: PackedInt32Array = board.duplicate()
	_set_cell_in(next_board, board_size, cell, color)

	var opponent := _other(color)
	var captured_total: int = 0

	for n in _neighbors(cell):
		if not _in_bounds(board_size, n):
			continue
		if _get_cell_in(next_board, board_size, n) == opponent:
			if _count_liberties_in(next_board, board_size, n) == 0:
				captured_total += _remove_group_in(next_board, board_size, n)

	if not allow_suicide:
		if _count_liberties_in(next_board, board_size, cell) == 0:
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
	result["self_liberties"] = _count_liberties_in(next_board, board_size, cell)
	return result

# ---- helpers ----

func _idx(board_size: int, c: Vector2i) -> int:
	return c.y * board_size + c.x

func _in_bounds(board_size: int, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < board_size and c.y < board_size

func _get_cell_in(arr: PackedInt32Array, board_size: int, c: Vector2i) -> int:
	if not _in_bounds(board_size, c):
		return GridBoardGame.Stone.EMPTY
	return arr[_idx(board_size, c)]

func _set_cell_in(arr: PackedInt32Array, board_size: int, c: Vector2i, v: int) -> void:
	if not _in_bounds(board_size, c):
		return
	arr[_idx(board_size, c)] = v

func _other(s: int) -> int:
	return GridBoardGame.Stone.WHITE if s == GridBoardGame.Stone.BLACK else GridBoardGame.Stone.BLACK

func _neighbors(c: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(c.x - 1, c.y),
		Vector2i(c.x + 1, c.y),
		Vector2i(c.x, c.y - 1),
		Vector2i(c.x, c.y + 1),
	]

func _collect_group_in(arr: PackedInt32Array, board_size: int, start: Vector2i) -> Array[Vector2i]:
	if not _in_bounds(board_size, start):
		return []
	var color := _get_cell_in(arr, board_size, start)
	if color == GridBoardGame.Stone.EMPTY:
		return []

	var out: Array[Vector2i] = []
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [start]
	visited[start] = true

	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		out.append(c)
		for n in _neighbors(c):
			if not _in_bounds(board_size, n):
				continue
			if visited.has(n):
				continue
			if _get_cell_in(arr, board_size, n) == color:
				visited[n] = true
				stack.append(n)

	return out

func _count_liberties_in(arr: PackedInt32Array, board_size: int, start: Vector2i) -> int:
	var group := _collect_group_in(arr, board_size, start)
	if group.is_empty():
		return 0
	var liberties: Dictionary = {}
	for c in group:
		for n in _neighbors(c):
			if not _in_bounds(board_size, n):
				continue
			if _get_cell_in(arr, board_size, n) == GridBoardGame.Stone.EMPTY:
				liberties[n] = true
	return liberties.size()

func _remove_group_in(arr: PackedInt32Array, board_size: int, start: Vector2i) -> int:
	var group := _collect_group_in(arr, board_size, start)
	for c in group:
		_set_cell_in(arr, board_size, c, GridBoardGame.Stone.EMPTY)
	return group.size()

func _compute_board_hash_in(arr: PackedInt32Array) -> int:
	var h: int = 146959810
	for i in range(arr.size()):
		h = int(h * 16777619) ^ int(arr[i] + (i * 3))
	return h
