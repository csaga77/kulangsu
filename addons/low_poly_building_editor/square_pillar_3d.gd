@tool
class_name SquarePillar3D
extends Pillar3D


func get_pillar_style() -> String:
	return "square"


func _effective_side_count() -> int:
	return 4


func _effective_angle_offset(_sides: int) -> float:
	return PI * 0.25
