@tool
class_name WinderStairs3D
extends TurningStairs3D

@export_enum("90 Degrees", "180 Degrees") var winder_turn: int = WinderTurn.TURN_90:
	set(value):
		var clamped_value := clampi(value, WinderTurn.TURN_90, WinderTurn.TURN_180)
		if winder_turn == clamped_value:
			return
		winder_turn = clamped_value
		_request_rebuild()


func _is_winder_layout() -> bool:
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
	new_winder_turn: int,
	_spiral_turn_degrees: float
) -> void:
	winder_turn = new_winder_turn


func _layout_winder_turn() -> int:
	return winder_turn


func _layout_mesh_source_signature_values() -> Array:
	var values := super()
	values.append(winder_turn)
	return values
