@tool
class_name StraightStairs3D
extends Stairs3D


func _append_stair_layout_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	_append_stair_geometry(width, depth, vertices, normals, colors, indices)
