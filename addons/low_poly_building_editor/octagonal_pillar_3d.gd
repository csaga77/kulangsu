@tool
class_name OctagonalPillar3D
extends Pillar3D


func get_pillar_style() -> String:
	return "octagonal"


func _effective_side_count() -> int:
	return 8
