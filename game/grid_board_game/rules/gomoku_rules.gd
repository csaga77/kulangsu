@tool
class_name GomokuRules
extends BoardRules

@export var win_length: int = 5
@export var exact_five: bool = false

# Renju options (apply to BLACK only)
@export var renju_enabled: bool = false
@export var renju_forbid_overline: bool = true
@export var renju_forbid_double_three: bool = true
@export var renju_forbid_double_four: bool = true
@export var renju_black_exact_five: bool = true
@export var renju_white_allow_overline_win: bool = true

func reset(_board: PackedInt32Array, _board_size: int) -> void:
	pass

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
	out_info["captured"] = 0
	out_info["self_liberties"] = 0
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

	# --- Renju forbidden checks (BLACK only) ---
	if renju_enabled and color == GridBoardGame.Stone.BLACK:
		if _is_renju_forbidden_move(next_board, board_size, cell):
			result["ok"] = false
			return result

	# --- Win detection ---
	var require_exact := _is_exact_five_required_for_color(color)
	var line := _get_win_line(next_board, board_size, cell, color, win_length, require_exact)

	# Optional: if renju enabled and white overline win is disallowed
	if renju_enabled and color == GridBoardGame.Stone.WHITE and (not renju_white_allow_overline_win):
		if _max_run_len(next_board, board_size, cell, color) >= (win_length + 1):
			line = []

	result["ok"] = true
	result["board"] = next_board
	result["game_over"] = not line.is_empty()
	result["winner"] = color if not line.is_empty() else GridBoardGame.Stone.EMPTY
	result["win_line"] = line
	return result

# -----------------------
# Renju forbidden logic
# -----------------------

func _is_exact_five_required_for_color(color: int) -> bool:
	if renju_enabled:
		if color == GridBoardGame.Stone.BLACK:
			return renju_black_exact_five
		return false
	return exact_five

func _is_renju_forbidden_move(board: PackedInt32Array, board_size: int, last_cell: Vector2i) -> bool:
	var overline := _max_run_len(board, board_size, last_cell, GridBoardGame.Stone.BLACK) >= (win_length + 1)
	if renju_forbid_overline and overline:
		return true

	var open_three_count := 0
	var four_count := 0

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]

	for d in dirs:
		var s := _line_string(board, board_size, last_cell, GridBoardGame.Stone.BLACK, d, 5)
		open_three_count += _count_open_threes_in_line(s)
		four_count += _count_fours_in_line(s)

	if renju_forbid_double_three and open_three_count >= 2:
		return true
	if renju_forbid_double_four and four_count >= 2:
		return true

	return false

func _line_string(
	board: PackedInt32Array,
	board_size: int,
	origin: Vector2i,
	own_color: int,
	dir: Vector2i,
	radius: int
) -> String:
	var chars: PackedStringArray = []
	for step in range(-radius, radius + 1):
		var p := origin + dir * step
		if not _in_bounds(board_size, p):
			chars.append("2")
			continue
		var v := _get_cell_in(board, board_size, p)
		if v == GridBoardGame.Stone.EMPTY:
			chars.append("0")
		elif v == own_color:
			chars.append("1")
		else:
			chars.append("2")
	return "".join(chars)

func _count_open_threes_in_line(s: String) -> int:
	var patterns: Array[String] = [
		"01110",
		"010110",
		"011010",
	]
	return _count_any_patterns(s, patterns)

func _count_fours_in_line(s: String) -> int:
	var patterns: Array[String] = [
		"011110",
		"0111010",
		"0101110",
		"0110110",
	]
	return _count_any_patterns(s, patterns)

func _count_any_patterns(s: String, patterns: Array[String]) -> int:
	var count := 0
	for p in patterns:
		var from := 0
		while true:
			var idx := s.find(p, from)
			if idx < 0:
				break
			count += 1
			from = idx + 1
	return count

func _max_run_len(board: PackedInt32Array, board_size: int, origin: Vector2i, color: int) -> int:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]
	var best := 1
	for d in dirs:
		var run := 1
		run += _count_one_dir(board, board_size, origin, color, d)
		run += _count_one_dir(board, board_size, origin, color, -d)
		best = maxi(best, run)
	return best

func _count_one_dir(board: PackedInt32Array, board_size: int, start: Vector2i, color: int, dir: Vector2i) -> int:
	var n := 0
	var p := start + dir
	while _in_bounds(board_size, p) and _get_cell_in(board, board_size, p) == color:
		n += 1
		p += dir
	return n

# -----------------------
# Win detection
# -----------------------

func _get_win_line(
	board: PackedInt32Array,
	board_size: int,
	last_cell: Vector2i,
	color: int,
	length: int,
	require_exact: bool
) -> Array[Vector2i]:
	if length < 2:
		return []

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]

	for d in dirs:
		var line := _collect_line(board, board_size, last_cell, color, d)
		var run_len := line.size()

		if require_exact:
			if run_len == length:
				return _pick_segment_containing_origin(line, last_cell, length)
		else:
			if run_len >= length:
				return _pick_segment_containing_origin(line, last_cell, length)

	return []

func _collect_line(board: PackedInt32Array, board_size: int, origin: Vector2i, color: int, dir: Vector2i) -> Array[Vector2i]:
	var neg: Array[Vector2i] = []
	var p := origin - dir
	while _in_bounds(board_size, p) and _get_cell_in(board, board_size, p) == color:
		neg.append(p)
		p -= dir

	var pos: Array[Vector2i] = []
	p = origin + dir
	while _in_bounds(board_size, p) and _get_cell_in(board, board_size, p) == color:
		pos.append(p)
		p += dir

	neg.reverse()
	var out: Array[Vector2i] = []
	out.append_array(neg)
	out.append(origin)
	out.append_array(pos)
	return out

func _pick_segment_containing_origin(line: Array[Vector2i], origin: Vector2i, length: int) -> Array[Vector2i]:
	if line.size() <= length:
		return line.duplicate()
	var origin_index := line.find(origin)
	if origin_index < 0:
		origin_index = 0
	var start := clampi(origin_index - (length / 2), 0, line.size() - length)
	var seg: Array[Vector2i] = []
	for i in range(length):
		seg.append(line[start + i])
	return seg

# -----------------------
# Helpers
# -----------------------

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
