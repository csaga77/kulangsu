@tool
class_name Floor3D
extends MeshInstance3D

const GENERATED_META := &"floor_generated"
const PREVIEW_META := &"building_editor_preview"
const FLOOR_HOLE_EDGE_EPSILON := 0.001
const FLOOR_HOLE_MIN_SIZE := 0.001

var m_floor_holes: Array[Rect2] = []

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_floor_mesh")

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

@export var floor_holes: Array[Rect2] = []:
	set(value):
		var sanitized := _sanitize_floor_holes(value, get_floor_size())
		if _floor_hole_arrays_equal(m_floor_holes, sanitized):
			return
		m_floor_holes = sanitized
		_request_rebuild()
	get:
		return get_floor_holes()

@export_range(0.01, 2.0, 0.01, "or_greater") var floor_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(floor_thickness, clamped_value):
			return
		floor_thickness = clamped_value
		_request_rebuild()

@export var floor_color := Color(0.46, 0.40, 0.32, 1.0):
	set(value):
		if floor_color == value:
			return
		floor_color = value
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
		rebuild_floor_mesh()


func set_floor_corners(new_start: Vector3, new_end: Vector3) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	_sync_transform_from_points()
	rebuild_floor_mesh()


func set_floor_corners_and_holes(
	new_start: Vector3,
	new_end: Vector3,
	new_holes: Array[Rect2]
) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	_sync_transform_from_points()
	m_floor_holes = _sanitize_floor_holes(new_holes, get_floor_size())
	rebuild_floor_mesh()


func set_floor_holes(new_holes: Array[Rect2]) -> void:
	var sanitized := _sanitize_floor_holes(new_holes, get_floor_size())
	if _floor_hole_arrays_equal(m_floor_holes, sanitized):
		return
	m_floor_holes = sanitized
	rebuild_floor_mesh()


func get_floor_holes() -> Array[Rect2]:
	var holes: Array[Rect2] = []
	for hole in m_floor_holes:
		holes.append(hole)
	return holes


func get_floor_hole_rect_from_parent_corners(parent_start: Vector3, parent_end: Vector3) -> Rect2:
	var floor_min_x := minf(start_point.x, end_point.x)
	var floor_min_z := minf(start_point.z, end_point.z)
	var rect := _rect_from_parent_corners(parent_start, parent_end)
	rect.position -= Vector2(floor_min_x, floor_min_z)
	return rect


func can_add_floor_hole_from_parent_corners(parent_start: Vector3, parent_end: Vector3) -> bool:
	return can_add_floor_hole_rect(get_floor_hole_rect_from_parent_corners(parent_start, parent_end))


func can_add_floor_hole_rect(rect: Rect2) -> bool:
	var normalized := _normalized_rect(rect)
	return _is_floor_hole_rect_valid_for_size(normalized, get_floor_size())


func get_floor_holes_merged_with_rect(rect: Rect2) -> Array[Rect2]:
	var holes := get_floor_holes()
	holes.append(rect)
	return _sanitize_floor_holes(holes, get_floor_size())


func floor_hole_rect_intersects_existing(rect: Rect2) -> bool:
	var normalized := _normalized_rect(rect)
	for hole in m_floor_holes:
		if _rects_overlap(normalized, hole):
			return true
	return false


func floor_holes_fit_size(size: Vector2) -> bool:
	return _floor_hole_arrays_equal(m_floor_holes, _sanitize_floor_holes(m_floor_holes, size))


func has_floor_hole_at_local_point(local_point: Vector2) -> bool:
	for hole in m_floor_holes:
		var hole_end := _rect_end(hole)
		if (
			local_point.x > hole.position.x + FLOOR_HOLE_EDGE_EPSILON
			and local_point.x < hole_end.x - FLOOR_HOLE_EDGE_EPSILON
			and local_point.y > hole.position.y + FLOOR_HOLE_EDGE_EPSILON
			and local_point.y < hole_end.y - FLOOR_HOLE_EDGE_EPSILON
		):
			return true
	return false


func get_floor_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func rebuild_floor_mesh(rebuild_collision: bool = true) -> void:
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_floor_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return
	var mesh_holes := _sanitize_floor_holes(m_floor_holes, size)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	_append_floor_geometry(size.x, size.y, mesh_holes, vertices, normals, colors, indices, collision_faces)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_floor_mesh_resource(arrays)
	_sync_floor_material()

	if rebuild_collision and generate_collision:
		_add_collision_body(collision_faces)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_floor_mesh")


func _sync_transform_from_points() -> void:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	transform = Transform3D(Basis.IDENTITY, Vector3(min_x, start_point.y, min_z))


func _append_floor_geometry(
	width: float,
	depth: float,
	holes: Array[Rect2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var visible_rects := _visible_floor_rects(Vector2(width, depth), holes)
	for rect in visible_rects:
		_append_horizontal_rect(
			rect,
			0.0,
			Vector3.UP,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)
		_append_horizontal_rect(
			rect,
			-floor_thickness,
			Vector3.DOWN,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	_append_outer_floor_sides(width, depth, vertices, normals, colors, indices, collision_faces)
	_append_floor_hole_boundary_sides(holes, vertices, normals, colors, indices, collision_faces)


func _append_outer_floor_sides(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var top_min_min := Vector3.ZERO
	var top_max_min := Vector3(width, 0.0, 0.0)
	var top_max_max := Vector3(width, 0.0, depth)
	var top_min_max := Vector3(0.0, 0.0, depth)
	var bottom_min_min := Vector3(0.0, -floor_thickness, 0.0)
	var bottom_max_min := Vector3(width, -floor_thickness, 0.0)
	var bottom_max_max := Vector3(width, -floor_thickness, depth)
	var bottom_min_max := Vector3(0.0, -floor_thickness, depth)

	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_min_min,
		bottom_min_min,
		bottom_min_max,
		top_min_max,
		Vector3.LEFT
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_max_min,
		top_max_max,
		bottom_max_max,
		bottom_max_min,
		Vector3.RIGHT
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_min_min,
		top_max_min,
		bottom_max_min,
		bottom_min_min,
		Vector3.FORWARD
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		collision_faces,
		top_min_max,
		bottom_min_max,
		bottom_max_max,
		top_max_max,
		Vector3.BACK
	)


func _append_horizontal_rect(
	rect: Rect2,
	y: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var rect_end := _rect_end(rect)
	if normal.dot(Vector3.UP) > 0.0:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(rect.position.x, y, rect.position.y),
			Vector3(rect.position.x, y, rect_end.y),
			Vector3(rect_end.x, y, rect_end.y),
			Vector3(rect_end.x, y, rect.position.y),
			normal
		)
	else:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(rect.position.x, y, rect.position.y),
			Vector3(rect_end.x, y, rect.position.y),
			Vector3(rect_end.x, y, rect_end.y),
			Vector3(rect.position.x, y, rect_end.y),
			normal
		)


func _append_floor_hole_boundary_sides(
	holes: Array[Rect2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	for hole in holes:
		_append_floor_hole_boundary_for_rect(
			hole,
			holes,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


func _append_floor_hole_boundary_for_rect(
	hole: Rect2,
	holes: Array[Rect2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var hole_end := _rect_end(hole)
	var intervals := _visible_hole_edge_intervals(hole.position.y, hole_end.y, _hole_left_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_x_side(
			hole.position.x,
			interval.x,
			interval.y,
			Vector3.RIGHT,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	intervals = _visible_hole_edge_intervals(hole.position.y, hole_end.y, _hole_right_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_x_side(
			hole_end.x,
			interval.x,
			interval.y,
			Vector3.LEFT,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	intervals = _visible_hole_edge_intervals(hole.position.x, hole_end.x, _hole_min_z_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_z_side(
			hole.position.y,
			interval.x,
			interval.y,
			Vector3.BACK,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)

	intervals = _visible_hole_edge_intervals(hole.position.x, hole_end.x, _hole_max_z_edge_cutters(hole, holes))
	for interval in intervals:
		_append_floor_hole_z_side(
			hole_end.y,
			interval.x,
			interval.y,
			Vector3.FORWARD,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


func _append_floor_hole_x_side(
	x: float,
	z_start: float,
	z_end: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	if normal.dot(Vector3.RIGHT) > 0.0:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x, 0.0, z_start),
			Vector3(x, 0.0, z_end),
			Vector3(x, -floor_thickness, z_end),
			Vector3(x, -floor_thickness, z_start),
			normal
		)
	else:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x, 0.0, z_start),
			Vector3(x, -floor_thickness, z_start),
			Vector3(x, -floor_thickness, z_end),
			Vector3(x, 0.0, z_end),
			normal
		)


func _append_floor_hole_z_side(
	z: float,
	x_start: float,
	x_end: float,
	normal: Vector3,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	if normal.dot(Vector3.BACK) > 0.0:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x_start, 0.0, z),
			Vector3(x_start, -floor_thickness, z),
			Vector3(x_end, -floor_thickness, z),
			Vector3(x_end, 0.0, z),
			normal
		)
	else:
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			collision_faces,
			Vector3(x_start, 0.0, z),
			Vector3(x_end, 0.0, z),
			Vector3(x_end, -floor_thickness, z),
			Vector3(x_start, -floor_thickness, z),
			normal
		)


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
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
		colors.append(floor_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))
	collision_faces.append(a)
	collision_faces.append(c)
	collision_faces.append(b)
	collision_faces.append(a)
	collision_faces.append(d)
	collision_faces.append(c)


func _visible_floor_rects(size: Vector2, holes: Array[Rect2]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append(Rect2(Vector2.ZERO, size))
	for hole in holes:
		var next_rects: Array[Rect2] = []
		for rect in rects:
			_append_rect_difference(next_rects, rect, hole)
		rects = next_rects
	return rects


func _append_rect_difference(output: Array[Rect2], rect: Rect2, cutter: Rect2) -> void:
	var rect_end := _rect_end(rect)
	var cutter_end := _rect_end(cutter)
	var intersect_min_x := maxf(rect.position.x, cutter.position.x)
	var intersect_min_y := maxf(rect.position.y, cutter.position.y)
	var intersect_max_x := minf(rect_end.x, cutter_end.x)
	var intersect_max_y := minf(rect_end.y, cutter_end.y)
	if (
		intersect_max_x <= intersect_min_x + FLOOR_HOLE_MIN_SIZE
		or intersect_max_y <= intersect_min_y + FLOOR_HOLE_MIN_SIZE
	):
		output.append(rect)
		return

	_append_rect_if_area(
		output,
		Rect2(
			rect.position,
			Vector2(intersect_min_x - rect.position.x, rect.size.y)
		)
	)
	_append_rect_if_area(
		output,
		Rect2(
			Vector2(intersect_max_x, rect.position.y),
			Vector2(rect_end.x - intersect_max_x, rect.size.y)
		)
	)
	_append_rect_if_area(
		output,
		Rect2(
			Vector2(intersect_min_x, rect.position.y),
			Vector2(intersect_max_x - intersect_min_x, intersect_min_y - rect.position.y)
		)
	)
	_append_rect_if_area(
		output,
		Rect2(
			Vector2(intersect_min_x, intersect_max_y),
			Vector2(intersect_max_x - intersect_min_x, rect_end.y - intersect_max_y)
		)
	)


func _append_rect_if_area(output: Array[Rect2], rect: Rect2) -> void:
	if rect.size.x <= FLOOR_HOLE_MIN_SIZE or rect.size.y <= FLOOR_HOLE_MIN_SIZE:
		return
	output.append(rect)


func _sanitize_floor_holes(holes: Array[Rect2], size: Vector2) -> Array[Rect2]:
	var valid_holes: Array[Rect2] = []
	if size.x <= FLOOR_HOLE_MIN_SIZE or size.y <= FLOOR_HOLE_MIN_SIZE:
		return valid_holes
	for hole in holes:
		var normalized := _normalized_rect(hole)
		if !_is_floor_hole_rect_valid_for_size(normalized, size):
			continue
		valid_holes.append(normalized)
	return _floor_hole_union_rects(valid_holes)


func _is_floor_hole_rect_valid_for_size(rect: Rect2, size: Vector2) -> bool:
	var rect_end := _rect_end(rect)
	return (
		rect.size.x > FLOOR_HOLE_MIN_SIZE
		and rect.size.y > FLOOR_HOLE_MIN_SIZE
		and rect.position.x > FLOOR_HOLE_EDGE_EPSILON
		and rect.position.y > FLOOR_HOLE_EDGE_EPSILON
		and rect_end.x < size.x - FLOOR_HOLE_EDGE_EPSILON
		and rect_end.y < size.y - FLOOR_HOLE_EDGE_EPSILON
	)


func _floor_hole_union_rects(holes: Array[Rect2]) -> Array[Rect2]:
	var union_rects: Array[Rect2] = []
	if holes.is_empty():
		return union_rects

	var x_values := _sorted_hole_coordinates(holes, true)
	var y_values := _sorted_hole_coordinates(holes, false)
	var active_rects: Array[Rect2] = []
	for y_index in range(y_values.size() - 1):
		var y_start := float(y_values[y_index])
		var y_end := float(y_values[y_index + 1])
		if y_end <= y_start + FLOOR_HOLE_MIN_SIZE:
			continue
		var row_runs := _floor_hole_row_runs(holes, x_values, y_start, y_end)
		if row_runs.is_empty():
			union_rects.append_array(active_rects)
			active_rects.clear()
			continue
		var next_active: Array[Rect2] = []
		var consumed_active: Array[bool] = []
		consumed_active.resize(active_rects.size())
		for index in range(consumed_active.size()):
			consumed_active[index] = false
		for row_run in row_runs:
			var merged := false
			for active_index in range(active_rects.size()):
				if consumed_active[active_index]:
					continue
				var active := active_rects[active_index]
				if (
					_rect_spans_match_x(active, row_run)
					and is_equal_approx(_rect_end(active).y, row_run.position.y)
				):
					active.size.y += row_run.size.y
					next_active.append(active)
					consumed_active[active_index] = true
					merged = true
					break
			if !merged:
				next_active.append(row_run)
		for active_index in range(active_rects.size()):
			if !consumed_active[active_index]:
				union_rects.append(active_rects[active_index])
		active_rects = next_active
	union_rects.append_array(active_rects)
	union_rects.sort_custom(_sort_floor_hole_rects)
	return union_rects


func _floor_hole_row_runs(
	holes: Array[Rect2],
	x_values: Array[float],
	y_start: float,
	y_end: float
) -> Array[Rect2]:
	var runs: Array[Rect2] = []
	var run_start := 0.0
	var in_run := false
	for x_index in range(x_values.size() - 1):
		var x_start := float(x_values[x_index])
		var x_end := float(x_values[x_index + 1])
		if x_end <= x_start + FLOOR_HOLE_MIN_SIZE:
			continue
		var center := Vector2((x_start + x_end) * 0.5, (y_start + y_end) * 0.5)
		var filled := _point_inside_any_hole(center, holes)
		if filled and !in_run:
			run_start = x_start
			in_run = true
		elif !filled and in_run:
			runs.append(Rect2(Vector2(run_start, y_start), Vector2(x_start - run_start, y_end - y_start)))
			in_run = false
	if in_run:
		var x_end := float(x_values[x_values.size() - 1])
		runs.append(Rect2(Vector2(run_start, y_start), Vector2(x_end - run_start, y_end - y_start)))
	return runs


func _point_inside_any_hole(point: Vector2, holes: Array[Rect2]) -> bool:
	for hole in holes:
		var hole_end := _rect_end(hole)
		if (
			point.x > hole.position.x - FLOOR_HOLE_EDGE_EPSILON
			and point.x < hole_end.x + FLOOR_HOLE_EDGE_EPSILON
			and point.y > hole.position.y - FLOOR_HOLE_EDGE_EPSILON
			and point.y < hole_end.y + FLOOR_HOLE_EDGE_EPSILON
		):
			return true
	return false


func _sorted_hole_coordinates(holes: Array[Rect2], use_x: bool) -> Array[float]:
	var values: Array[float] = []
	for hole in holes:
		var hole_end := _rect_end(hole)
		values.append(hole.position.x if use_x else hole.position.y)
		values.append(hole_end.x if use_x else hole_end.y)
	values.sort()
	var unique_values: Array[float] = []
	for value in values:
		if unique_values.is_empty():
			unique_values.append(value)
			continue
		if absf(value - float(unique_values[unique_values.size() - 1])) > FLOOR_HOLE_EDGE_EPSILON:
			unique_values.append(value)
	return unique_values


func _rect_spans_match_x(a: Rect2, b: Rect2) -> bool:
	var a_end := _rect_end(a)
	var b_end := _rect_end(b)
	return (
		is_equal_approx(a.position.x, b.position.x)
		and is_equal_approx(a_end.x, b_end.x)
	)


func _hole_left_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	for other in holes:
		if _rects_equal(hole, other):
			continue
		var other_end := _rect_end(other)
		if absf(other_end.x - hole.position.x) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.y, _rect_end(hole).y, other.position.y, other_end.y)
	return cutters


func _hole_right_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	var hole_end := _rect_end(hole)
	for other in holes:
		if _rects_equal(hole, other):
			continue
		if absf(other.position.x - hole_end.x) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.y, hole_end.y, other.position.y, _rect_end(other).y)
	return cutters


func _hole_min_z_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	for other in holes:
		if _rects_equal(hole, other):
			continue
		var other_end := _rect_end(other)
		if absf(other_end.y - hole.position.y) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.x, _rect_end(hole).x, other.position.x, other_end.x)
	return cutters


func _hole_max_z_edge_cutters(hole: Rect2, holes: Array[Rect2]) -> Array[Vector2]:
	var cutters: Array[Vector2] = []
	var hole_end := _rect_end(hole)
	for other in holes:
		if _rects_equal(hole, other):
			continue
		if absf(other.position.y - hole_end.y) > FLOOR_HOLE_EDGE_EPSILON:
			continue
		_append_overlap_interval(cutters, hole.position.x, hole_end.x, other.position.x, _rect_end(other).x)
	return cutters


func _append_overlap_interval(
	intervals: Array[Vector2],
	base_start: float,
	base_end: float,
	cutter_start: float,
	cutter_end: float
) -> void:
	var overlap_start := maxf(base_start, cutter_start)
	var overlap_end := minf(base_end, cutter_end)
	if overlap_end <= overlap_start + FLOOR_HOLE_MIN_SIZE:
		return
	intervals.append(Vector2(overlap_start, overlap_end))


func _visible_hole_edge_intervals(start: float, end: float, cutters: Array[Vector2]) -> Array[Vector2]:
	var visible: Array[Vector2] = []
	if end <= start + FLOOR_HOLE_MIN_SIZE:
		return visible
	if cutters.is_empty():
		visible.append(Vector2(start, end))
		return visible
	cutters.sort_custom(_sort_intervals)
	var cursor := start
	for cutter in cutters:
		var cutter_start := clampf(cutter.x, start, end)
		var cutter_end := clampf(cutter.y, start, end)
		if cutter_end <= cursor + FLOOR_HOLE_MIN_SIZE:
			continue
		if cutter_start > cursor + FLOOR_HOLE_MIN_SIZE:
			visible.append(Vector2(cursor, cutter_start))
		cursor = maxf(cursor, cutter_end)
	if cursor < end - FLOOR_HOLE_MIN_SIZE:
		visible.append(Vector2(cursor, end))
	return visible


func _sort_intervals(a: Vector2, b: Vector2) -> bool:
	if !is_equal_approx(a.x, b.x):
		return a.x < b.x
	return a.y < b.y


func _floor_hole_arrays_equal(a: Array[Rect2], b: Array[Rect2]) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if !_rects_equal(a[index], b[index]):
			return false
	return true


func _rects_equal(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.distance_to(b.position) <= FLOOR_HOLE_EDGE_EPSILON
		and a.size.distance_to(b.size) <= FLOOR_HOLE_EDGE_EPSILON
	)


func _rects_overlap(a: Rect2, b: Rect2) -> bool:
	var a_end := _rect_end(a)
	var b_end := _rect_end(b)
	return (
		a.position.x < b_end.x - FLOOR_HOLE_EDGE_EPSILON
		and a_end.x > b.position.x + FLOOR_HOLE_EDGE_EPSILON
		and a.position.y < b_end.y - FLOOR_HOLE_EDGE_EPSILON
		and a_end.y > b.position.y + FLOOR_HOLE_EDGE_EPSILON
	)


func _sort_floor_hole_rects(a: Rect2, b: Rect2) -> bool:
	if !is_equal_approx(a.position.x, b.position.x):
		return a.position.x < b.position.x
	if !is_equal_approx(a.position.y, b.position.y):
		return a.position.y < b.position.y
	if !is_equal_approx(a.size.x, b.size.x):
		return a.size.x < b.size.x
	return a.size.y < b.size.y


func _rect_from_parent_corners(parent_start: Vector3, parent_end: Vector3) -> Rect2:
	var min_x := minf(parent_start.x, parent_end.x)
	var max_x := maxf(parent_start.x, parent_end.x)
	var min_z := minf(parent_start.z, parent_end.z)
	var max_z := maxf(parent_start.z, parent_end.z)
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))


func _normalized_rect(rect: Rect2) -> Rect2:
	var rect_end := rect.position + rect.size
	var min_x := minf(rect.position.x, rect_end.x)
	var max_x := maxf(rect.position.x, rect_end.x)
	var min_y := minf(rect.position.y, rect_end.y)
	var max_y := maxf(rect.position.y, rect_end.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _rect_end(rect: Rect2) -> Vector2:
	return rect.position + rect.size


func _update_floor_mesh_resource(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh
	else:
		array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _sync_floor_material() -> void:
	var material := material_override as StandardMaterial3D
	if material == null:
		material_override = _build_floor_material(floor_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, floor_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if floor_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_floor_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_collision_body(collision_faces: PackedVector3Array) -> void:
	if collision_faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "FloorCollision"
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
