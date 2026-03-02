# res://game/grid_board_game/ai/board_ai_strategy.gd
@tool
class_name BoardAIStrategy
extends RefCounted

func choose_move(game: GridBoardGame, ai_color: int, level: int, rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(-1, -1)
