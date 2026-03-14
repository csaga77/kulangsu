extends Node

var m_last_turn_changed: int = GridBoardGame.Stone.EMPTY
var m_last_game_over_winner: int = GridBoardGame.Stone.EMPTY


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	var game := GridBoardGame.new()
	var rules := GomokuRules.new()
	rules.win_length = 5
	game.rules = rules
	game.board_size = 9

	game.turn_changed.connect(_on_turn_changed)
	game.game_over.connect(_on_game_over)
	add_child(game)

	await get_tree().process_frame

	var moves: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, 1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(2, 0),
		Vector2i(2, 1),
		Vector2i(3, 0),
		Vector2i(3, 1),
		Vector2i(4, 0),
	]

	for move in moves:
		if not game.play_move(move):
			_fail("Expected move %s to be legal." % [move])
			return

	if not game.is_game_over():
		_fail("Expected the final move to end the game.")
		return
	if game.get_winner() != GridBoardGame.Stone.BLACK:
		_fail("Expected black to be the recorded winner.")
		return
	if game.get_turn() != GridBoardGame.Stone.BLACK:
		_fail("Expected terminal turn state to remain on the winning player.")
		return
	if m_last_turn_changed != GridBoardGame.Stone.BLACK:
		_fail("Expected final turn_changed signal to report the winning player.")
		return
	if m_last_game_over_winner != GridBoardGame.Stone.BLACK:
		_fail("Expected game_over to report the winning player.")
		return

	print("GRID_BOARD_GAME_TEST PASS: terminal turn state remains on winner")
	get_tree().quit()


func _on_turn_changed(turn_color: int) -> void:
	m_last_turn_changed = turn_color


func _on_game_over(winner_color: int, _win_line: Array[Vector2i]) -> void:
	m_last_game_over_winner = winner_color


func _fail(message: String) -> void:
	push_error(message)
	printerr("GRID_BOARD_GAME_TEST FAIL: %s" % message)
	get_tree().quit(1)
