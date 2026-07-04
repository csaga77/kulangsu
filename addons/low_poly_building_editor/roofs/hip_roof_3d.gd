@tool
class_name HipRoof3D
extends "res://addons/low_poly_building_editor/roofs/sloped_roof_3d.gd"

const StyleGeometry := preload("res://addons/low_poly_building_editor/roofs/hip_roof_geometry_3d.gd")

@export_range(0.0, 20.0, 0.01, "or_greater") var hip_gable_height := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(hip_gable_height, clamped_value):
			return
		hip_gable_height = clamped_value
		_request_rebuild()
		source_geometry_changed.emit()


func get_roof_style() -> String:
	return "hip"


func get_hip_gable_height() -> float:
	return hip_gable_height


func set_hip_gable_height(height: float) -> void:
	hip_gable_height = height


func _style_geometry_parameters() -> Dictionary:
	var parameters := super()
	parameters["gable_height_from_peak"] = hip_gable_height
	return parameters


func _apply_style_geometry_parameters(parameters: Dictionary) -> void:
	super(parameters)
	hip_gable_height = float(parameters.get(
		"gable_height_from_peak", hip_gable_height
	))


func _get_style_geometry() -> RefCounted:
	return StyleGeometry.new()
