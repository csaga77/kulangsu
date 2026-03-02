# res://game/grid_board_game/ai/go_ai_strategy.gd
@tool
class_name GoAIStrategy
extends BoardAIStrategy

func choose_move(game: GridBoardGame, ai_color: int, level: int, rng: RandomNumberGenerator) -> Vector2i:
	var bs := game.get_board_size()
	var legal: Array[Vector2i] = []
	var best_moves: Array[Vector2i] = []
	var best_score: float = -1e30

	var center := Vector2(float(bs - 1) * 0.5, float(bs - 1) * 0.5)

	for y in range(bs):
		for x in range(bs):
			var c := Vector2i(x, y)
			if not game.is_empty_cell(c):
				continue

			var info: Dictionary = {}
			if not game.simulate_move(ai_color, c, info):
				continue

			legal.append(c)

			if level == 0:
				continue

			var captured: int = int(info.get("captured", 0))
			var self_lib: int = int(info.get("self_liberties", 0))
			var dist := center.distance_to(Vector2(x, y))
			var center_bonus := -dist

			var score: float = 0.0
			if level >= 1:
				score += float(captured) * 1000.0
				score += float(self_lib) * 2.0
				score += center_bonus * 0.8
			if level >= 2:
				score += float(captured) * 800.0
				score += float(self_lib) * 4.0
				score += center_bonus * 1.2

			if score > best_score + 0.0001:
				best_score = score
				best_moves = [c]
			elif absf(score - best_score) <= 0.0001:
				best_moves.append(c)

	if legal.is_empty():
		return Vector2i(-1, -1)

	if level == 0 or best_moves.is_empty():
		return legal[rng.randi_range(0, legal.size() - 1)]
	return best_moves[rng.randi_range(0, best_moves.size() - 1)]
