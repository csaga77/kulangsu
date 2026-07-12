extends SceneTree

const MARBLE_GAME_SCENE: PackedScene = preload("res://game/marble_game/marble_game.tscn")

var m_failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var game := MARBLE_GAME_SCENE.instantiate() as MarbleGame
	if game == null:
		_fail("marble_game.tscn did not instantiate as MarbleGame")
		_finish()
		return

	root.add_child(game)
	for _frame: int in 45:
		await physics_frame

	_expect(game is Node3D, "game root must be Node3D")
	_expect(game.get_hole() is Area3D, "hole must use Area3D physics")
	_expect(game.get_node_or_null("camera") is Camera3D, "scene must own a Camera3D")
	_expect(game.get_node_or_null("damping_area") is Area3D, "damping zone must use Area3D")
	_expect(game.get_balls().size() == 2, "scene should discover both marble bodies")
	var turn_mode := MarbleGameTurnMode.new()
	_expect(turn_mode is Resource, "turn mode must remain loadable after the 3D conversion")

	for ball: MarbleBall in game.get_balls():
		_expect(ball is RigidBody3D, "%s must use RigidBody3D physics" % ball.name)
		_expect(ball.global_position.y > -1.5, "%s fell through the board or catch pocket" % ball.name)
		_expect(ball.global_position.x > -0.8 and ball.global_position.x < 14.4, "%s escaped the X rails" % ball.name)
		_expect(ball.global_position.z > -0.8 and ball.global_position.z < 9.6, "%s escaped the Z rails" % ball.name)

	var player_ball: MarbleBall = game.get_node_or_null("player_ball") as MarbleBall
	if player_ball != null and not player_ball.m_in_hole:
		player_ball.apply_central_impulse(Vector3(0.7, 0.0, 0.35))
		for _frame: int in 90:
			await physics_frame
		_expect(player_ball.global_position.y > -1.5, "player marble remained supported after a 3D impulse")

	game.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	m_failures.append(message)
	push_error("[MarbleGame3DTest] " + message)


func _finish() -> void:
	if m_failures.is_empty():
		print("[MarbleGame3DTest] PASS")
		quit(0)
	else:
		print("[MarbleGame3DTest] FAIL count=", m_failures.size())
		quit(1)
