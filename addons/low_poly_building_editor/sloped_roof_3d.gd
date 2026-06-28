@tool
extends "res://addons/low_poly_building_editor/roof_3d.gd"

@export_range(0.0, 89.0, 1.0) var roof_height := 40.0:
	set(value):
		var clamped_value := clampf(value, 0.0, MAX_ROOF_ANGLE_DEGREES)
		if is_equal_approx(roof_height, clamped_value):
			return
		roof_height = clamped_value
		_request_rebuild()
		source_geometry_changed.emit()


func get_roof_angle_degrees() -> float:
	return roof_height


func set_roof_angle_degrees(angle_degrees: float) -> void:
	roof_height = angle_degrees
