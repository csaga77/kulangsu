# MarbleGameMode.gd
class_name MarbleGameMode
extends RefCounted

func on_apply_mode(_game: MarbleGame) -> void:
	pass

func on_restart(_game: MarbleGame) -> void:
	pass

func on_physics_process(_game: MarbleGame, _delta: float) -> void:
	pass

func on_ball_kicked(_game: MarbleGame, _ball: MarbleBall) -> void:
	pass

func on_ball_body_entered(_game: MarbleGame, _self_ball: MarbleBall, _other_body: Node) -> void:
	pass

func on_ball_hole_state_changed(_game: MarbleGame, _ball: MarbleBall, _in_hole: bool) -> void:
	pass
