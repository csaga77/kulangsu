@tool
extends "res://addons/low_poly_building_editor/roof_style_geometry_3d.gd"


func generated_height(size: Vector2, overhang: float, angle_degrees: float) -> float:
	return roof_height_for_angle(roof_run(size, overhang), angle_degrees)


func roof_run(size: Vector2, overhang: float) -> float:
	return maxf(size.y, 0.0) + maxf(overhang, 0.0) * 2.0


func surface_height(
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	local_render_point: Vector2,
	_gable_height_from_peak: float = 0.0
) -> float:
	var bounds := _bounds(size, overhang)
	var height := generated_height(size, overhang, angle_degrees)
	var z := clampf(local_render_point.y, bounds.z, bounds.w)
	return height * clampf((z - bounds.z) / maxf(bounds.w - bounds.z, RECT_EPSILON), 0.0, 1.0)


func top_triangles(
	full_size: Vector2,
	overhang: float,
	angle_degrees: float,
	_gable_height_from_peak: float = 0.0
) -> Array[PackedVector3Array]:
	var bounds := _bounds(full_size, overhang)
	var height := generated_height(full_size, overhang, angle_degrees)
	var p0 := Vector3(bounds.x, 0.0, bounds.z)
	var p1 := Vector3(bounds.y, 0.0, bounds.z)
	var p2 := Vector3(bounds.y, height, bounds.w)
	var p3 := Vector3(bounds.x, height, bounds.w)
	return [
		PackedVector3Array([p0, p3, p2]),
		PackedVector3Array([p0, p2, p1]),
	]


func top_faces(
	full_size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> Array[Dictionary]:
	var triangles := top_triangles(full_size, overhang, angle_degrees, gable_height_from_peak)
	var first := triangles[0]
	var second := triangles[1]
	return [{
		"vertices": PackedVector3Array([first[0], first[1], first[2], second[2]]),
		"plane": PackedVector3Array([first[0], first[1], first[2]]),
	}]
