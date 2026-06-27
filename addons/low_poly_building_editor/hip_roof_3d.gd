@tool
class_name HipRoof3D
extends "res://addons/low_poly_building_editor/sloped_roof_3d.gd"

const StyleGeometry := preload("res://addons/low_poly_building_editor/hip_roof_geometry_3d.gd")

@export_range(0.0, 20.0, 0.01, "or_greater") var hip_gable_height := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(hip_gable_height, clamped_value):
			return
		hip_gable_height = clamped_value
		_request_rebuild()


func get_roof_style() -> String:
	return STYLE_HIP


func get_hip_gable_height() -> float:
	return hip_gable_height


func set_hip_gable_height(height: float) -> void:
	hip_gable_height = height


func _get_style_geometry() -> RefCounted:
	return StyleGeometry.new()
