@tool
class_name LShapedStairs3D
extends TurningStairs3D


func _is_l_shaped_layout() -> bool:
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
