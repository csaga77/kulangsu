# res://game/grid_board_game/ai/gomoku_ai_strategy.gd
@tool
class_name GomokuAIStrategy
extends BoardAIStrategy

func choose_move(game: GridBoardGame, ai_color: int, level: int, rng: RandomNumberGenerator) -> Vector2i:
	var bs := game.get_board_size()
	var win_len := _gomoku_win_len(game)
	var opp := _other(ai_color)

	var legal: Array[Vector2i] = []
	var winning: Array[Vector2i] = []
	var blocking: Array[Vector2i] = []

	# 1) collect legal moves + immediate win/block
	for y in range(bs):
		for x in range(bs):
			var c := Vector2i(x, y)
			if not game.is_empty_cell(c):
				continue

			var info: Dictionary = {}
			if not game.simulate_move(ai_color, c, info):
				continue

			legal.append(c)

			if _run_if_place(game, c, ai_color) >= win_len:
				winning.append(c)
			elif _run_if_place(game, c, opp) >= win_len:
				blocking.append(c)

	# Win now
	if not winning.is_empty():
		return winning[rng.randi_range(0, winning.size() - 1)]

	# Block opponent win
	if not blocking.is_empty():
		return blocking[rng.randi_range(0, blocking.size() - 1)]

	if legal.is_empty():
		return Vector2i(-1, -1)

	# 2) otherwise: maximize our best run, reduce opponent run, slight center bias
	var center := Vector2(float(bs - 1) * 0.5, float(bs - 1) * 0.5)
	var best_moves: Array[Vector2i] = []
	var best_score: float = -1e30

	for c in legal:
		var my_run := _run_if_place(game, c, ai_color)
		var opp_run := _run_if_place(game, c, opp)

		var dist := center.distance_to(Vector2(c.x, c.y))
		var score := float(my_run) * 100.0 - float(opp_run) * 60.0 - dist * 0.6

		if level == 0:
			score += rng.randf_range(-1.0, 1.0)

		if score > best_score + 0.0001:
			best_score = score
			best_moves = [c]
		elif absf(score - best_score) <= 0.0001:
			best_moves.append(c)

	return best_moves[rng.randi_range(0, best_moves.size() - 1)]

# --------------------
# Helpers
# --------------------

func _gomoku_win_len(game: GridBoardGame) -> int:
	var v = game.rules.win_length
	if v == null:
		return 5
	return max(2, int(v))

func _run_if_place(game: GridBoardGame, cell: Vector2i, color: int) -> int:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(1, -1),
	]

	var best := 1
	for d in dirs:
		var count := 1
		count += _count_dir(game, cell, color, d)
		count += _count_dir(game, cell, color, -d)
		if count > best:
			best = count
	return best

func _count_dir(game: GridBoardGame, origin: Vector2i, color: int, step: Vector2i) -> int:
	var bs := game.get_board_size()
	var c := origin + step
	var n := 0
	while c.x >= 0 and c.y >= 0 and c.x < bs and c.y < bs:
		if game.get_cell(c) != color:
			break
		n += 1
		c += step
	return n

func _other(s: int) -> int:
	return GridBoardGame.Stone.WHITE if s == GridBoardGame.Stone.BLACK else GridBoardGame.Stone.BLACK
