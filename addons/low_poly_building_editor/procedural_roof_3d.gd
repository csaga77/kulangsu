@tool
class_name ProceduralRoof3D
extends MeshInstance3D

const GENERATED_META := &"procedural_roof_generated"
const PREVIEW_META := &"building_editor_preview"
const STYLE_FLAT := "flat"
const STYLE_SHED := "shed"
const STYLE_GABLE := "gable"
const STYLE_HIP := "hip"
const VALID_STYLES := [STYLE_FLAT, STYLE_SHED, STYLE_GABLE, STYLE_HIP]
const RECT_EPSILON := 0.001
const MAX_ROOF_ANGLE_DEGREES := 89.0

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_roof_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(4.0, 0.0, 4.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export_enum("Flat:0", "Shed:1", "Gable:2", "Hip:3") var roof_style_index := 2:
	set(value):
		var clamped_value := clampi(value, 0, VALID_STYLES.size() - 1)
		if roof_style_index == clamped_value:
			return
		roof_style_index = clamped_value
		_request_rebuild()

@export_range(0.0, 89.0, 1.0) var roof_height := 40.0:
	set(value):
		var clamped_value := _clamped_roof_angle_degrees(value)
		if is_equal_approx(roof_height, clamped_value):
			return
		roof_height = clamped_value
		_request_rebuild()

@export_range(0.02, 2.0, 0.01, "or_greater") var roof_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(roof_thickness, clamped_value):
			return
		roof_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var roof_overhang := 0.2:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(roof_overhang, clamped_value):
			return
		roof_overhang = clamped_value
		_request_rebuild()

@export_range(-180.0, 180.0, 1.0) var roof_rotation_degrees := 0.0:
	set(value):
		var normalized_value := _normalize_degrees(value)
		if is_equal_approx(roof_rotation_degrees, normalized_value):
			return
		roof_rotation_degrees = normalized_value
		_request_rebuild()

@export var roof_color := Color(0.50, 0.34, 0.25, 1.0):
	set(value):
		if roof_color == value:
			return
		roof_color = value
		_request_rebuild()

@export var covered_rects: Array[Rect2] = []:
	set(value):
		covered_rects = _sanitize_covered_rects(value)
		_request_rebuild()

@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

var m_is_ready := false
var m_rebuild_queued := false


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		rebuild_roof_mesh()


func set_roof_corners(new_start: Vector3, new_end: Vector3) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_corners_and_rotation(new_start: Vector3, new_end: Vector3, new_rotation_degrees: float) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	roof_rotation_degrees = new_rotation_degrees
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_corners_rotation_and_covers(
	new_start: Vector3,
	new_end: Vector3,
	new_rotation_degrees: float,
	new_covered_rects: Array[Rect2]
) -> void:
	set_roof_corners_rotation_height_and_covers(
		new_start,
		new_end,
		new_rotation_degrees,
		roof_height,
		new_covered_rects
	)


func set_roof_corners_rotation_height_and_covers(
	new_start: Vector3,
	new_end: Vector3,
	new_rotation_degrees: float,
	new_height: float,
	new_covered_rects: Array[Rect2]
) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	roof_rotation_degrees = new_rotation_degrees
	roof_height = new_height
	covered_rects = new_covered_rects
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_covered_rects(new_covered_rects: Array[Rect2]) -> void:
	covered_rects = new_covered_rects
	rebuild_roof_mesh()


func get_covered_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for rect in covered_rects:
		rects.append(rect)
	return rects


func get_visible_footprint_rects() -> Array[Rect2]:
	var size := get_roof_size()
	if size.x <= RECT_EPSILON or size.y <= RECT_EPSILON:
		return []
	var footprint_rect := Rect2(Vector2.ZERO, size)
	var visible_footprint_rects: Array[Rect2] = []
	for render_rect in get_visible_render_rects():
		var footprint_piece := _rect_intersection(footprint_rect, render_rect)
		if _rect_has_area(footprint_piece):
			visible_footprint_rects.append(footprint_piece)
	return visible_footprint_rects


func get_roof_render_rect() -> Rect2:
	var size := get_roof_size()
	var overhang := maxf(roof_overhang, 0.0)
	return Rect2(
		Vector2(-overhang, -overhang),
		Vector2(size.x + overhang * 2.0, size.y + overhang * 2.0)
	)


func get_visible_render_rects() -> Array[Rect2]:
	var size := get_roof_size()
	if size.x <= RECT_EPSILON or size.y <= RECT_EPSILON:
		return []
	return _visible_roof_rects(get_roof_render_rect(), covered_rects)


func has_visible_roof_geometry() -> bool:
	return !get_visible_render_rects().is_empty()


func set_roof_rotation_degrees(new_rotation_degrees: float) -> void:
	roof_rotation_degrees = new_rotation_degrees
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_rotation_around_center(new_rotation_degrees: float) -> void:
	var size := get_roof_size()
	var center := get_roof_center_point()
	var normalized_rotation := _normalize_degrees(new_rotation_degrees)
	var rotated_anchor := center - _rotation_basis_for_degrees(normalized_rotation) * Vector3(
		size.x * 0.5,
		0.0,
		size.y * 0.5
	)
	set_roof_corners_and_rotation(
		rotated_anchor,
		rotated_anchor + Vector3(size.x, 0.0, size.y),
		normalized_rotation
	)


func set_roof_style(style: String) -> void:
	roof_style_index = _style_index_from_name(style)
	rebuild_roof_mesh()


func get_roof_style() -> String:
	return String(VALID_STYLES[clampi(roof_style_index, 0, VALID_STYLES.size() - 1)])


func get_roof_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func get_roof_angle_degrees() -> float:
	return _clamped_roof_angle_degrees(roof_height)


static func roof_height_for_angle_degrees(run: float, angle_degrees: float) -> float:
	return maxf(run, 0.0) * tan(deg_to_rad(_clamped_roof_angle_degrees(angle_degrees)))


static func shed_height_for_angle_degrees(depth: float, overhang: float, angle_degrees: float) -> float:
	return roof_height_for_angle_degrees(shed_roof_run_for_depth(depth, overhang), angle_degrees)


static func shed_roof_run_for_depth(depth: float, overhang: float) -> float:
	return maxf(depth, 0.0) + maxf(overhang, 0.0) * 2.0


static func gable_height_for_angle_degrees(depth: float, overhang: float, angle_degrees: float) -> float:
	return roof_height_for_angle_degrees(gable_roof_run_for_depth(depth, overhang), angle_degrees)


static func gable_roof_run_for_depth(depth: float, overhang: float) -> float:
	return maxf(maxf(depth, 0.0) * 0.5 + maxf(overhang, 0.0), 0.0)


static func hip_height_for_angle_degrees(size: Vector2, overhang: float, angle_degrees: float) -> float:
	return roof_height_for_angle_degrees(hip_roof_run_for_size(size, overhang), angle_degrees)


static func hip_roof_run_for_size(size: Vector2, overhang: float) -> float:
	var shortest_depth := minf(maxf(size.x, 0.0), maxf(size.y, 0.0))
	return maxf(shortest_depth * 0.5 + maxf(overhang, 0.0), 0.0)


static func roof_corners_from_base_points(base_start: Vector3, base_end: Vector3, rotation_degrees: float) -> Dictionary:
	var basis := Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))
	var flat_delta := Vector3(base_end.x - base_start.x, 0.0, base_end.z - base_start.z)
	var local_delta := basis.inverse() * flat_delta
	var min_x := minf(0.0, local_delta.x)
	var max_x := maxf(0.0, local_delta.x)
	var min_z := minf(0.0, local_delta.z)
	var max_z := maxf(0.0, local_delta.z)
	var anchor := base_start + basis * Vector3(min_x, 0.0, min_z)
	var size := Vector2(max_x - min_x, max_z - min_z)
	return {
		"start": Vector3(anchor.x, base_start.y, anchor.z),
		"end": Vector3(anchor.x + size.x, base_start.y, anchor.z + size.y),
	}


func get_roof_anchor_point() -> Vector3:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	return Vector3(min_x, start_point.y, min_z)


func get_roof_center_point() -> Vector3:
	var size := get_roof_size()
	return get_roof_anchor_point() + _rotation_basis() * Vector3(size.x * 0.5, 0.0, size.y * 0.5)


func get_roof_bounds_min() -> Vector3:
	var overhang := maxf(roof_overhang, 0.0)
	return Vector3(-overhang, -roof_thickness, -overhang)


func get_roof_bounds_max() -> Vector3:
	var size := get_roof_size()
	var overhang := maxf(roof_overhang, 0.0)
	return Vector3(size.x + overhang, _effective_roof_height(), size.y + overhang)


func rebuild_roof_mesh(rebuild_collision: bool = true) -> void:
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_roof_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var full_render_rect := get_roof_render_rect()
	var visible_rects := get_visible_render_rects()
	if visible_rects.is_empty():
		mesh = null
		return
	if visible_rects.size() == 1 and _rects_match(visible_rects[0], full_render_rect):
		_append_roof_geometry(size.x, size.y, vertices, normals, colors, indices)
	else:
		for visible_rect in visible_rects:
			_append_roof_piece_geometry(size, visible_rect, vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_roof_mesh_resource(arrays)
	_sync_roof_material()

	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_roof_mesh")


func _sync_transform_from_points() -> void:
	transform = Transform3D(_rotation_basis(), get_roof_anchor_point())


func _rotation_basis() -> Basis:
	return _rotation_basis_for_degrees(roof_rotation_degrees)


func _rotation_basis_for_degrees(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees(rotation_degrees)))


func _normalize_degrees(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _append_roof_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var overhang := maxf(roof_overhang, 0.0)
	var x0 := -overhang
	var x1 := width + overhang
	var z0 := -overhang
	var z1 := depth + overhang
	var center_x := (x0 + x1) * 0.5
	var center_z := (z0 + z1) * 0.5
	var height := _effective_roof_height_for_size(Vector2(width, depth))
	var top_points: Array[Vector3] = []
	var top_triangles: Array[PackedInt32Array] = []
	var boundary := PackedInt32Array()

	match get_roof_style():
		STYLE_SHED:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, height, z1),
				Vector3(x0, height, z1),
			]
			top_triangles = [PackedInt32Array([0, 3, 2]), PackedInt32Array([0, 2, 1])]
			boundary = PackedInt32Array([0, 1, 2, 3])
		STYLE_HIP:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
				Vector3(center_x, height, center_z),
			]
			top_triangles = [
				PackedInt32Array([0, 4, 1]),
				PackedInt32Array([1, 4, 2]),
				PackedInt32Array([2, 4, 3]),
				PackedInt32Array([3, 4, 0]),
			]
			boundary = PackedInt32Array([0, 1, 2, 3])
		STYLE_GABLE:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
				Vector3(x0, height, center_z),
				Vector3(x1, height, center_z),
			]
			top_triangles = [
				PackedInt32Array([0, 4, 5]),
				PackedInt32Array([0, 5, 1]),
				PackedInt32Array([3, 2, 5]),
				PackedInt32Array([3, 5, 4]),
			]
			boundary = PackedInt32Array([0, 1, 5, 2, 3, 4])
		_:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
			]
			top_triangles = [PackedInt32Array([0, 3, 2]), PackedInt32Array([0, 2, 1])]
			boundary = PackedInt32Array([0, 1, 2, 3])

	for triangle in top_triangles:
		_append_triangle_auto(
			vertices,
			normals,
			colors,
			indices,
			top_points[triangle[0]],
			top_points[triangle[1]],
			top_points[triangle[2]]
		)

	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for triangle in top_triangles:
		_append_triangle_auto(
			vertices,
			normals,
			colors,
			indices,
			top_points[triangle[0]] + bottom_offset,
			top_points[triangle[2]] + bottom_offset,
			top_points[triangle[1]] + bottom_offset
		)

	for edge_index in range(boundary.size()):
		var next_edge_index := (edge_index + 1) % boundary.size()
		var edge_start: Vector3 = top_points[boundary[edge_index]]
		var edge_end: Vector3 = top_points[boundary[next_edge_index]]
		_append_quad_auto(
			vertices,
			normals,
			colors,
			indices,
			edge_start,
			edge_end,
			edge_end + bottom_offset,
			edge_start + bottom_offset
		)


func _append_roof_piece_geometry(
	full_size: Vector2,
	render_rect: Rect2,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for top_triangle in _roof_top_triangles(full_size):
		var clipped_top := _clip_polygon_to_rect(top_triangle, render_rect)
		_append_polygon_triangles(clipped_top, false, vertices, normals, colors, indices)
		var clipped_bottom: Array[Vector3] = []
		for point in clipped_top:
			clipped_bottom.append(point + bottom_offset)
		_append_polygon_triangles(clipped_bottom, true, vertices, normals, colors, indices)
	_append_roof_outer_sides(full_size, render_rect, vertices, normals, colors, indices)


func _roof_top_triangles(full_size: Vector2) -> Array[PackedVector3Array]:
	var overhang := maxf(roof_overhang, 0.0)
	var x0 := -overhang
	var x1 := full_size.x + overhang
	var z0 := -overhang
	var z1 := full_size.y + overhang
	var center_x := (x0 + x1) * 0.5
	var center_z := (z0 + z1) * 0.5
	var height := _effective_roof_height_for_size(full_size)
	var triangles: Array[PackedVector3Array] = []
	match get_roof_style():
		STYLE_SHED:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, height, z1)
			var p3 := Vector3(x0, height, z1)
			triangles.append(PackedVector3Array([p0, p3, p2]))
			triangles.append(PackedVector3Array([p0, p2, p1]))
		STYLE_HIP:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			var apex := Vector3(center_x, height, center_z)
			triangles.append(PackedVector3Array([p0, apex, p1]))
			triangles.append(PackedVector3Array([p1, apex, p2]))
			triangles.append(PackedVector3Array([p2, apex, p3]))
			triangles.append(PackedVector3Array([p3, apex, p0]))
		STYLE_GABLE:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			var ridge_left := Vector3(x0, height, center_z)
			var ridge_right := Vector3(x1, height, center_z)
			triangles.append(PackedVector3Array([p0, ridge_left, ridge_right]))
			triangles.append(PackedVector3Array([p0, ridge_right, p1]))
			triangles.append(PackedVector3Array([p3, p2, ridge_right]))
			triangles.append(PackedVector3Array([p3, ridge_right, ridge_left]))
		_:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			triangles.append(PackedVector3Array([p0, p3, p2]))
			triangles.append(PackedVector3Array([p0, p2, p1]))
	return triangles


func _clip_polygon_to_rect(polygon: PackedVector3Array, rect: Rect2) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point in polygon:
		points.append(point)
	points = _clip_polygon_axis(points, rect.position.x, 0, true)
	points = _clip_polygon_axis(points, rect.position.x + rect.size.x, 0, false)
	points = _clip_polygon_axis(points, rect.position.y, 2, true)
	points = _clip_polygon_axis(points, rect.position.y + rect.size.y, 2, false)
	return points


func _clip_polygon_axis(
	points: Array[Vector3],
	boundary: float,
	axis: int,
	keep_greater: bool
) -> Array[Vector3]:
	if points.is_empty():
		return []
	var clipped: Array[Vector3] = []
	var previous := points[points.size() - 1]
	var previous_inside := _is_point_inside_clip(previous, boundary, axis, keep_greater)
	for current in points:
		var current_inside := _is_point_inside_clip(current, boundary, axis, keep_greater)
		if current_inside != previous_inside:
			clipped.append(_interpolate_clip_intersection(previous, current, boundary, axis))
		if current_inside:
			clipped.append(current)
		previous = current
		previous_inside = current_inside
	return clipped


func _is_point_inside_clip(point: Vector3, boundary: float, axis: int, keep_greater: bool) -> bool:
	var value := point.x if axis == 0 else point.z
	if keep_greater:
		return value >= boundary - RECT_EPSILON
	return value <= boundary + RECT_EPSILON


func _interpolate_clip_intersection(from_point: Vector3, to_point: Vector3, boundary: float, axis: int) -> Vector3:
	var from_value := from_point.x if axis == 0 else from_point.z
	var to_value := to_point.x if axis == 0 else to_point.z
	var denominator := to_value - from_value
	if absf(denominator) <= RECT_EPSILON:
		return from_point
	var weight := clampf((boundary - from_value) / denominator, 0.0, 1.0)
	return from_point.lerp(to_point, weight)


func _append_polygon_triangles(
	polygon: Array[Vector3],
	reverse_order: bool,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if polygon.size() < 3:
		return
	for index in range(1, polygon.size() - 1):
		if reverse_order:
			_append_triangle_auto(vertices, normals, colors, indices, polygon[0], polygon[index + 1], polygon[index])
		else:
			_append_triangle_auto(vertices, normals, colors, indices, polygon[0], polygon[index], polygon[index + 1])


func _append_roof_outer_sides(
	full_size: Vector2,
	render_rect: Rect2,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var full_render_rect := get_roof_render_rect()
	var full_render_min := full_render_rect.position
	var full_render_max := full_render_rect.position + full_render_rect.size
	var render_min := render_rect.position
	var render_max := render_rect.position + render_rect.size
	if absf(render_min.y - full_render_min.y) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_min.x, render_max.x, render_min.y, true, true),
			vertices,
			normals,
			colors,
			indices
		)
	if absf(render_max.x - full_render_max.x) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_min.y, render_max.y, render_max.x, false, true),
			vertices,
			normals,
			colors,
			indices
		)
	if absf(render_max.y - full_render_max.y) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_max.x, render_min.x, render_max.y, true, true),
			vertices,
			normals,
			colors,
			indices
		)
	if absf(render_min.x - full_render_min.x) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_max.y, render_min.y, render_min.x, false, true),
			vertices,
			normals,
			colors,
			indices
		)


func _roof_edge_points_for_axis(
	full_size: Vector2,
	start_value: float,
	end_value: float,
	fixed_value: float,
	axis_is_x: bool,
	include_style_splits: bool
) -> Array[Vector3]:
	var values := _edge_axis_values(full_size, start_value, end_value, axis_is_x, include_style_splits)
	var points: Array[Vector3] = []
	for value in values:
		var x := value if axis_is_x else fixed_value
		var z := fixed_value if axis_is_x else value
		points.append(Vector3(x, _roof_height_at(full_size, x, z), z))
	return points


func _edge_axis_values(
	full_size: Vector2,
	start_value: float,
	end_value: float,
	axis_is_x: bool,
	include_style_splits: bool
) -> Array[float]:
	var min_value := minf(start_value, end_value)
	var max_value := maxf(start_value, end_value)
	var values: Array[float] = [start_value, end_value]
	if include_style_splits and !axis_is_x and get_roof_style() == STYLE_GABLE:
		var center_z := full_size.y * 0.5
		if center_z > min_value + RECT_EPSILON and center_z < max_value - RECT_EPSILON:
			values.append(center_z)
	values.sort()
	if start_value > end_value:
		values.reverse()
	return values


func _append_roof_side_polyline(
	points: Array[Vector3],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if points.size() < 2:
		return
	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for index in range(points.size() - 1):
		var edge_start := points[index]
		var edge_end := points[index + 1]
		_append_quad_auto(
			vertices,
			normals,
			colors,
			indices,
			edge_start,
			edge_end,
			edge_end + bottom_offset,
			edge_start + bottom_offset
		)


func _roof_height_at(full_size: Vector2, x: float, z: float) -> float:
	var height := _effective_roof_height_for_size(full_size)
	if height <= 0.0:
		return 0.0
	var overhang := maxf(roof_overhang, 0.0)
	var min_x := -overhang
	var max_x := full_size.x + overhang
	var min_z := -overhang
	var max_z := full_size.y + overhang
	var clamped_x := clampf(x, min_x, max_x)
	var clamped_z := clampf(z, min_z, max_z)
	match get_roof_style():
		STYLE_SHED:
			return height * clampf((clamped_z - min_z) / maxf(max_z - min_z, RECT_EPSILON), 0.0, 1.0)
		STYLE_HIP:
			var x_fraction := minf(
				(clamped_x - min_x) / maxf((max_x - min_x) * 0.5, RECT_EPSILON),
				(max_x - clamped_x) / maxf((max_x - min_x) * 0.5, RECT_EPSILON)
			)
			var z_fraction := minf(
				(clamped_z - min_z) / maxf((max_z - min_z) * 0.5, RECT_EPSILON),
				(max_z - clamped_z) / maxf((max_z - min_z) * 0.5, RECT_EPSILON)
			)
			return height * clampf(minf(x_fraction, z_fraction), 0.0, 1.0)
		STYLE_GABLE:
			var center_z := (min_z + max_z) * 0.5
			var half_depth := maxf((max_z - min_z) * 0.5, RECT_EPSILON)
			return height * clampf(1.0 - absf(clamped_z - center_z) / half_depth, 0.0, 1.0)
		_:
			return 0.0


func _visible_roof_rects(full_rect: Rect2, covers: Array[Rect2]) -> Array[Rect2]:
	var visible_rects: Array[Rect2] = [full_rect]
	for cover in covers:
		var clipped_cover := _rect_intersection(full_rect, cover)
		if !_rect_has_area(clipped_cover):
			continue
		var next_visible_rects: Array[Rect2] = []
		for visible_rect in visible_rects:
			next_visible_rects.append_array(_subtract_rect(visible_rect, clipped_cover))
		visible_rects = next_visible_rects
		if visible_rects.is_empty():
			break
	return visible_rects


func _subtract_rect(source: Rect2, cover: Rect2) -> Array[Rect2]:
	var overlap := _rect_intersection(source, cover)
	if !_rect_has_area(overlap):
		return [source]

	var source_min := source.position
	var source_max := source.position + source.size
	var overlap_min := overlap.position
	var overlap_max := overlap.position + overlap.size
	var rects: Array[Rect2] = []
	_append_visible_rect(rects, Rect2(
		Vector2(source_min.x, source_min.y),
		Vector2(overlap_min.x - source_min.x, source.size.y)
	))
	_append_visible_rect(rects, Rect2(
		Vector2(overlap_max.x, source_min.y),
		Vector2(source_max.x - overlap_max.x, source.size.y)
	))
	_append_visible_rect(rects, Rect2(
		Vector2(overlap_min.x, source_min.y),
		Vector2(overlap.size.x, overlap_min.y - source_min.y)
	))
	_append_visible_rect(rects, Rect2(
		Vector2(overlap_min.x, overlap_max.y),
		Vector2(overlap.size.x, source_max.y - overlap_max.y)
	))
	return rects


func _append_visible_rect(rects: Array[Rect2], rect: Rect2) -> void:
	if _rect_has_area(rect):
		rects.append(rect)


func _rect_intersection(first: Rect2, second: Rect2) -> Rect2:
	var first_max := first.position + first.size
	var second_max := second.position + second.size
	var min_point := Vector2(maxf(first.position.x, second.position.x), maxf(first.position.y, second.position.y))
	var max_point := Vector2(minf(first_max.x, second_max.x), minf(first_max.y, second_max.y))
	return Rect2(min_point, Vector2(max_point.x - min_point.x, max_point.y - min_point.y))


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > RECT_EPSILON and rect.size.y > RECT_EPSILON


func _rects_match(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.distance_to(second.position) <= RECT_EPSILON
		and first.size.distance_to(second.size) <= RECT_EPSILON
	)


func _sanitize_covered_rects(rects: Array[Rect2]) -> Array[Rect2]:
	var sanitized: Array[Rect2] = []
	for rect in rects:
		if !_rect_has_area(rect):
			continue
		sanitized.append(rect)
	return sanitized


func _effective_roof_height() -> float:
	return _effective_roof_height_for_size(get_roof_size())


func _effective_roof_height_for_size(size: Vector2) -> float:
	match get_roof_style():
		STYLE_SHED:
			return shed_height_for_angle_degrees(size.y, roof_overhang, roof_height)
		STYLE_GABLE:
			return gable_height_for_angle_degrees(size.y, roof_overhang, roof_height)
		STYLE_HIP:
			return hip_height_for_angle_degrees(size, roof_overhang, roof_height)
	return 0.0


static func _clamped_roof_angle_degrees(angle_degrees: float) -> float:
	return clampf(angle_degrees, 0.0, MAX_ROOF_ANGLE_DEGREES)


static func _normalize_degrees_static(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _style_index_from_name(style: String) -> int:
	var normalized := style.strip_edges().to_lower()
	for index in range(VALID_STYLES.size()):
		if String(VALID_STYLES[index]) == normalized:
			return index
	return 2


func _append_triangle_auto(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	_append_triangle(vertices, normals, colors, indices, a, b, c, normal.normalized())


func _append_quad_auto(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	_append_quad(vertices, normals, colors, indices, a, b, c, d, normal.normalized())


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(d)
	for _index in range(4):
		normals.append(normal)
		colors.append(roof_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	colors.append(roof_color)
	colors.append(roof_color)
	colors.append(roof_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1]))


func _update_roof_mesh_resource(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh
	else:
		array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _sync_roof_material() -> void:
	var material := material_override as StandardMaterial3D
	if material == null:
		material_override = _build_roof_material(roof_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, roof_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if roof_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_roof_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_collision_body(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var faces := PackedVector3Array()
	for index in range(0, indices.size(), 3):
		faces.append(vertices[indices[index]])
		faces.append(vertices[indices[index + 1]])
		faces.append(vertices[indices[index + 2]])
	if faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "RoofCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
