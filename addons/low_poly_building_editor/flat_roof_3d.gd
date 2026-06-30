@tool
class_name FlatRoof3D
extends "res://addons/low_poly_building_editor/roof_3d.gd"

const StyleGeometry := preload("res://addons/low_poly_building_editor/roof_style_geometry_3d.gd")

var m_polygon_points := PackedVector3Array()

@export var polygon_points: PackedVector3Array = PackedVector3Array():
	set(value):
		set_roof_polygon(value)
	get:
		return get_roof_polygon()


func get_roof_style() -> String:
	return STYLE_FLAT


func _get_style_geometry() -> RefCounted:
	return StyleGeometry.new()


func set_roof_polygon(new_points: PackedVector3Array) -> void:
	var sanitized := _sanitize_polygon_points(new_points)
	var previous_signature := _roof_mesh_source_signature()
	m_polygon_points = sanitized
	if !m_polygon_points.is_empty():
		var bounds := _roof_polygon_parent_bounds(m_polygon_points)
		var base_y := m_polygon_points[0].y
		start_point = Vector3(bounds.position.x, base_y, bounds.position.y)
		end_point = Vector3(bounds.end.x, base_y, bounds.end.y)
		roof_rotation_degrees = 0.0
	if _roof_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_roof_mesh()
	source_geometry_changed.emit()


func get_roof_polygon() -> PackedVector3Array:
	return m_polygon_points.duplicate()


func is_polygon_roof() -> bool:
	return !m_polygon_points.is_empty()


func get_roof_render_polygons() -> Array[PackedVector2Array]:
	if !is_polygon_roof():
		return super.get_roof_render_polygons()
	var bounds := _roof_polygon_parent_bounds(m_polygon_points)
	var local_polygon := PackedVector2Array()
	for point in m_polygon_points:
		local_polygon.append(Vector2(point.x - bounds.position.x, point.z - bounds.position.y))
	if roof_overhang <= RECT_EPSILON:
		return [local_polygon]
	var offset_polygons := Geometry2D.offset_polygon(
		local_polygon,
		roof_overhang,
		Geometry2D.JOIN_MITER
	)
	var result: Array[PackedVector2Array] = []
	for polygon in offset_polygons:
		if polygon.size() >= 3:
			result.append(PackedVector2Array(polygon))
	return result if !result.is_empty() else [local_polygon]


func get_roof_render_rect() -> Rect2:
	if !is_polygon_roof():
		return super.get_roof_render_rect()
	var result := Rect2()
	var has_bounds := false
	for polygon in get_roof_render_polygons():
		for point in polygon:
			if !has_bounds:
				result = Rect2(point, Vector2.ZERO)
				has_bounds = true
			else:
				result = result.expand(point)
	return result


func _clear_roof_polygon() -> void:
	m_polygon_points = PackedVector3Array()


func _sanitize_polygon_points(points: PackedVector3Array) -> PackedVector3Array:
	var sanitized := PackedVector3Array()
	if points.is_empty():
		return sanitized
	var base_y := points[0].y
	for point in points:
		var flattened := Vector3(point.x, base_y, point.z)
		if !sanitized.is_empty() and sanitized[sanitized.size() - 1].is_equal_approx(flattened):
			continue
		sanitized.append(flattened)
	if sanitized.size() > 1 and sanitized[0].is_equal_approx(sanitized[sanitized.size() - 1]):
		sanitized.resize(sanitized.size() - 1)
	return sanitized
