# MarbleBallController.gd
class_name MarbleBallController
extends Resource

## The ball currently controlled by this controller (assigned by MarbleBall).
var m_ball: MarbleBall = null

## The game instance owning the ball (assigned by MarbleGame -> MarbleBall).
var m_game: MarbleGame = null

## Whether the game/mode currently allows this controller to act.
var m_allowed: bool = false

## Called by MarbleBall when the controller is assigned / re-assigned.
func set_ball(ball: MarbleBall) -> void:
	m_ball = ball

## Called by MarbleBall when MarbleGame injects the game instance.
func set_game(game: MarbleGame) -> void:
	m_game = game

## Called by MarbleBall (via game/mode) to enable/disable this controller.
func set_allowed(is_allowed: bool) -> void:
	if m_allowed == is_allowed:
		return
	m_allowed = is_allowed
	_on_allowed_changed(m_allowed)

## Optional override in subclasses.
func _on_allowed_changed(_is_allowed: bool) -> void:
	pass

## Called by MarbleBall from _unhandled_input.
func handle_input(_event: InputEvent) -> void:
	pass

## Called by MarbleBall from _physics_process.
func physics_tick(_delta: float) -> void:
	pass
