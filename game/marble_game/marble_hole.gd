class_name MarbleHole
extends Area3D

## Pulls marbles toward the opening and down into the catch pocket.
@export var pull_strength: float = 8.0
@export var pull_target_y_offset: float = -0.8

signal ball_entered(ball: MarbleBall)
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

	var pull_target := global_position + Vector3.UP * pull_target_y_offset
	for ball: MarbleBall in m_balls_in_hole:
		if not is_instance_valid(ball):
			continue
		var offset: Vector3 = pull_target - ball.global_position
		if offset.length_squared() > 0.0001:
			ball.apply_central_force(offset.normalized() * pull_strength)


func _on_body_entered(body: Node3D) -> void:
	var ball := body as MarbleBall
	if ball == null or m_balls_in_hole.has(ball):
		return
	m_balls_in_hole.append(ball)
	ball.set_in_hole(true)
	ball_entered.emit(ball)


func _on_body_exited(body: Node3D) -> void:
	var ball := body as MarbleBall
	if ball == null:
		return
	m_balls_in_hole.erase(ball)
	ball.set_in_hole(false)
	ball_exited.emit(ball)
