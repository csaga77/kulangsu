@tool
class_name SpiralStairs3D
extends TurningStairs3D

@export_range(45.0, 1080.0, 1.0) var spiral_turn_degrees := 360.0:
	set(value):
		var clamped_value := clampf(value, 45.0, 1080.0)
		if is_equal_approx(spiral_turn_degrees, clamped_value):
			return
		spiral_turn_degrees = clamped_value
		_request_rebuild()


func _is_spiral_layout() -> bool:
	return true


func _append_stair_layout_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_append_layout_geometry(width, depth, vertices, normals, colors, indices)


func _configure_specific_stair_layout(
	_winder_turn: int,
	new_spiral_turn_degrees: float
) -> void:
	spiral_turn_degrees = new_spiral_turn_degrees


func _layout_spiral_turn_degrees() -> float:
	return spiral_turn_degrees


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(spiral_turn_degrees)
	return values
