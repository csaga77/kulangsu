# MarbleBall.gd
class_name MarbleBall
extends RigidBody2D

signal kicked(ball: MarbleBall)
signal body_hit(ball: MarbleBall, other_body: Node)
signal hole_state_changed(ball: MarbleBall, in_hole: bool)

## The controller Resource that drives this ball.
@export var controller: MarbleBallController

## The game that owns this ball (assigned by MarbleGame).
var m_game: MarbleGame = null

## True if this ball is currently inside the hole.
var m_in_hole: bool = false

func _ready() -> void:
	# Ensure collision signals actually fire for a RigidBody2D.
	contact_monitor = true
	max_contacts_reported = 8

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if is_instance_valid(controller):
		controller.set_ball(self)

func set_game(game: MarbleGame) -> void:
	m_game = game
	if is_instance_valid(controller):
		controller.set_game(game)

func set_controller_active(is_active: bool) -> void:
	if is_instance_valid(controller):
		controller.set_allowed(is_active)

func notify_kicked() -> void:
	kicked.emit(self)

func set_in_hole(in_hole: bool) -> void:
	if m_in_hole == in_hole:
		return
	m_in_hole = in_hole
	hole_state_changed.emit(self, m_in_hole)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(controller):
		controller.handle_input(event)

func _physics_process(delta: float) -> void:
	if is_instance_valid(controller):
		controller.physics_tick(delta)

func _on_body_entered(body: Node) -> void:
	body_hit.emit(self, body)
