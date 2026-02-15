class_name MarbleBallController
extends Resource

var m_ball: MarbleBall = null
var m_game: MarbleGame = null
var m_allowed: bool = false

func set_ball(ball: MarbleBall) -> void:
	m_ball = ball

func set_game(game: MarbleGame) -> void:
	m_game = game

func set_allowed(is_allowed: bool) -> void:
	if m_allowed == is_allowed:
		return
	m_allowed = is_allowed
	_on_allowed_changed(m_allowed)

func _on_allowed_changed(_is_allowed: bool) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func physics_tick(_delta: float) -> void:
	pass
