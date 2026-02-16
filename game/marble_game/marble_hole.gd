# MarbleHole.gd
class_name MarbleHole
extends Area2D

## Pull strength applied to balls currently inside the hole.
@export var pull_strength: float = 0.5

## Emitted when a MarbleBall enters the hole (after ball state updated).
signal ball_entered(ball: MarbleBall)

## Emitted when a MarbleBall exits the hole (after ball state updated).
signal ball_exited(ball: MarbleBall)

var m_balls_in_hole: Array[MarbleBall] = []

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	if pull_strength <= 0.0:
		return

	for b in m_balls_in_hole:
		if not is_instance_valid(b):
			continue
		var vec := global_position - b.global_position
		if vec.length() > 15.0:
			b.apply_central_force(vec.normalized() * vec.length_squared() * pull_strength)

func _on_body_entered(body: Node2D) -> void:
	if body is MarbleBall:
		var b := body as MarbleBall
		if not m_balls_in_hole.has(b):
			m_balls_in_hole.append(b)

		# ✅ Hole owns the state flip
		b.set_in_hole(true)

		ball_entered.emit(b)

func _on_body_exited(body: Node2D) -> void:
	if body is MarbleBall:
		var b := body as MarbleBall
		m_balls_in_hole.erase(b)

		# ✅ Hole owns the state flip
		b.set_in_hole(false)

		ball_exited.emit(b)
