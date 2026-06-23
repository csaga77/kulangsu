@tool
class_name MergedWallMeshBuilder
extends RefCounted

## Static mesh-construction helpers for multi-segment ProceduralWall3D nodes.
## Builds combined geometry for a set of wall segments, clipping faces and
## mitering shared endpoints in plan (XZ) space so junctions render without
## buried interior geometry, square butt seams, or z-fighting caps. Segments
## are assumed to share a base plane. Horizontal caps stay tied to wall
## footprints so enclosed rooms do not become filled slabs.

const PLANE_EPSILON := 0.002
const VERTICAL_CLIP_DEFLATE := 0.0
const MIN_OVERLAP_AREA := 0.000001
const MIN_SPAN := 0.001
const MITER_LIMIT_MULTIPLIER := 4.0


static func footprint_from_points(
	start_point: Vector3,
	end_point: Vector3,
	thickness: float
) -> PackedVector2Array:
	var segment := WallSegment3D.new()
	segment.start_point = start_point
	segment.end_point = end_point
	segment.thickness = thickness
	return segment_footprint(segment, segment.get_frame())


static func segment_footprint(segment: WallSegment3D, frame: Transform3D) -> PackedVector2Array:
	var segment_length := segment.get_length()
	if segment_length <= MIN_SPAN:
		return PackedVector2Array()
	var half_thickness := segment.thickness * 0.5
	var corners := PackedVector2Array([
		_plan_point(frame, 0.0, half_thickness),
		_plan_point(frame, segment_length, half_thickness),
		_plan_point(frame, segment_length, -half_thickness),
		_plan_point(frame, 0.0, -half_thickness),
	])
	if _signed_area(corners) < 0.0:
		corners.reverse()
	return corners


## Plan-space rectangle of a sub-span of a segment (e.g. an opening's slice
## through the wall thickness), in the same space as segment footprints.
static func span_plan_rect(
	frame: Transform3D,
	x0: float,
	x1: float,
	half_thickness: float
) -> PackedVector2Array:
	var corners := PackedVector2Array([
		_plan_point(frame, x0, -half_thickness),
		_plan_point(frame, x1, -half_thickness),
		_plan_point(frame, x1, half_thickness),
		_plan_point(frame, x0, half_thickness),
	])
	if _signed_area(corners) < 0.0:
		corners.reverse()
	return corners


static func footprints_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	for piece in Geometry2D.intersect_polygons(a, b):
		if absf(_signed_area(piece)) > MIN_OVERLAP_AREA:
			return true
	return false


static func append_segments(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	opening_rects: Array,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	render_segment_indices: Array = []
) -> void:
	var footprints: Array[PackedVector2Array] = []
	var deflated: Array[PackedVector2Array] = []
	var miter_plans: Array = []
	for index in range(segments.size()):
		var miter_plan := _segment_miter_plan(segments, frames, index)
		var footprint := _segment_miter_footprint(segments[index], frames[index], miter_plan)
		miter_plans.append(miter_plan)
		footprints.append(footprint)
		deflated.append(_deflate(footprint, VERTICAL_CLIP_DEFLATE))
	for index in _render_segment_indices(segments.size(), render_segment_indices):
		var rects: Array[Rect2] = []
		if index < opening_rects.size():
			rects = opening_rects[index]
		_append_segment_geometry(
			segments,
			frames,
			index,
			footprints,
			deflated,
			miter_plans,
			rects,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


static func _render_segment_indices(segment_count: int, requested_indices: Array) -> Array[int]:
	var result: Array[int] = []
	if requested_indices.is_empty():
		for index in range(segment_count):
			result.append(index)
		return result
	for requested in requested_indices:
		var index := int(requested)
		if index < 0 or index >= segment_count:
			continue
		if result.has(index):
			continue
		result.append(index)
	return result


static func _append_segment_geometry(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int,
	footprints: Array[PackedVector2Array],
	deflated: Array[PackedVector2Array],
	miter_plans: Array,
	opening_rects: Array[Rect2],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var segment := segments[segment_index]
	var segment_length := segment.get_length()
	if segment_length <= MIN_SPAN:
		return
	var x_cuts := _cut_values(opening_rects, segment_length, segment.height, true)
	var y_cuts := _cut_values(opening_rects, segment_length, segment.height, false, segments, segment_index)
	var half_thickness := segment.thickness * 0.5
	for x_index in range(x_cuts.size() - 1):
		var x0 := x_cuts[x_index]
		var x1 := x_cuts[x_index + 1]
		if x1 - x0 <= MIN_SPAN:
			continue
		for y_index in range(y_cuts.size() - 1):
			var y0 := y_cuts[y_index]
			var y1 := y_cuts[y_index + 1]
			if y1 - y0 <= MIN_SPAN:
				continue
			var center := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
			if _point_inside_opening(center, opening_rects):
				continue
			_append_cell(
				segments,
				frames,
				segment_index,
				footprints,
				deflated,
				miter_plans,
				x0, x1, y0, y1,
				half_thickness,
				vertices,
				normals,
				colors,
				indices,
				collision_faces
			)


static func _append_cell(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int,
	footprints: Array[PackedVector2Array],
	deflated: Array[PackedVector2Array],
	miter_plans: Array,
	x0: float, x1: float, y0: float, y1: float,
	half_thickness: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var frame := frames[segment_index]
	var color := segments[segment_index].color
	var segment_length := segments[segment_index].get_length()
	var miter_plan: Dictionary = miter_plans[segment_index]
	var cell_points := _cell_local_points(x0, x1, half_thickness, segment_length, miter_plan)
	var start_plus: Vector2 = cell_points["start_plus"]
	var start_minus: Vector2 = cell_points["start_minus"]
	var end_plus: Vector2 = cell_points["end_plus"]
	var end_minus: Vector2 = cell_points["end_minus"]
	var dir3 := frame.basis.x
	var side3 := frame.basis.z
	var end_partners: Array = miter_plan["end_partners"]
	var end_is_mitered := (
		segment_length - x1 <= MIN_SPAN
		and bool(miter_plan["end_mitered"])
	)
	var end_cap_suppressed := (
		segment_length - x1 <= MIN_SPAN
		and bool(miter_plan["end_cap_suppressed"])
	)
	var start_partners: Array = miter_plan["start_partners"]
	var start_is_mitered := (
		x0 <= MIN_SPAN
		and bool(miter_plan["start_mitered"])
	)
	var start_cap_suppressed := (
		x0 <= MIN_SPAN
		and bool(miter_plan["start_cap_suppressed"])
	)
	var side_clip_exceptions := []
	var cap_clip_exceptions := []
	if start_is_mitered:
		for partner in start_partners:
			if !side_clip_exceptions.has(partner):
				side_clip_exceptions.append(partner)
		if start_partners.size() == 1 and !cap_clip_exceptions.has(start_partners[0]):
			cap_clip_exceptions.append(start_partners[0])
	if end_is_mitered:
		for partner in end_partners:
			if !side_clip_exceptions.has(partner):
				side_clip_exceptions.append(partner)
		if end_partners.size() == 1 and !cap_clip_exceptions.has(end_partners[0]):
			cap_clip_exceptions.append(end_partners[0])

	_append_vertical_face(
		segments, segment_index, deflated, side_clip_exceptions, frame,
		start_plus.x, start_plus.y, end_plus.x, end_plus.y, y0, y1, side3, color,
		vertices, normals, colors, indices, collision_faces
	)
	_append_vertical_face(
		segments, segment_index, deflated, side_clip_exceptions, frame,
		start_minus.x, start_minus.y, end_minus.x, end_minus.y, y0, y1, -side3, color,
		vertices, normals, colors, indices, collision_faces
	)
	var end_cap_normal := dir3
	if segment_length - x1 <= MIN_SPAN:
		end_cap_normal = _cap_normal(frame, end_minus, end_plus, dir3)
	if !end_cap_suppressed:
		_append_vertical_face(
			segments, segment_index, deflated, [], frame,
			end_minus.x, end_minus.y, end_plus.x, end_plus.y, y0, y1, end_cap_normal, color,
			vertices, normals, colors, indices, collision_faces
		)
	var start_cap_normal := -dir3
	if x0 <= MIN_SPAN:
		start_cap_normal = _cap_normal(frame, start_minus, start_plus, -dir3)
	if !start_cap_suppressed:
		_append_vertical_face(
			segments, segment_index, deflated, [], frame,
			start_minus.x, start_minus.y, start_plus.x, start_plus.y, y0, y1, start_cap_normal, color,
			vertices, normals, colors, indices, collision_faces
		)
	var local_polygon := PackedVector2Array([start_minus, end_minus, end_plus, start_plus])
	_append_horizontal_face_polygon(
		segments, segment_index, footprints, cap_clip_exceptions, frame,
		local_polygon, y1, Vector3.UP, color,
		vertices, normals, colors, indices, collision_faces
	)
	_append_horizontal_face_polygon(
		segments, segment_index, footprints, cap_clip_exceptions, frame,
		local_polygon, y0, Vector3.DOWN, color,
		vertices, normals, colors, indices, collision_faces
	)


static func _append_vertical_face(
	segments: Array[WallSegment3D],
	segment_index: int,
	deflated: Array[PackedVector2Array],
	clip_exceptions: Array,
	frame: Transform3D,
	ax: float, az: float, bx: float, bz: float,
	y0: float, y1: float,
	face_normal: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var a2 := _plan_point(frame, ax, az)
	var b2 := _plan_point(frame, bx, bz)
	var polylines: Array[PackedVector2Array] = [PackedVector2Array([a2, b2])]
	for other_index in range(segments.size()):
		if other_index == segment_index:
			continue
		if clip_exceptions.has(other_index):
			continue
		if deflated[other_index].is_empty():
			continue
		if y1 > segments[other_index].height + PLANE_EPSILON:
			continue
		var remaining: Array[PackedVector2Array] = []
		for polyline in polylines:
			for piece in Geometry2D.clip_polyline_with_polygon(polyline, deflated[other_index]):
				if piece.size() >= 2:
					remaining.append(piece)
		polylines = remaining
		if polylines.is_empty():
			return
	for polyline in polylines:
		for point_index in range(polyline.size() - 1):
			var w1 := polyline[point_index]
			var w2 := polyline[point_index + 1]
			if w1.distance_to(w2) <= MIN_SPAN:
				continue
			_append_vertical_segment(
				w1, w2, frame, y0, y1, face_normal, color,
				vertices, normals, colors, indices, collision_faces
			)


static func _append_vertical_segment(
	w1: Vector2,
	w2: Vector2,
	frame: Transform3D,
	y0: float,
	y1: float,
	face_normal: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var a := _lift(w1, frame, y0)
	var b := _lift(w2, frame, y0)
	var c := _lift(w2, frame, y1)
	var d := _lift(w1, frame, y1)
	if ((b - a).cross(c - a)).dot(face_normal) < 0.0:
		var swap_bottom := a
		a = b
		b = swap_bottom
		var swap_top := c
		c = d
		d = swap_top
	_append_quad(
		vertices, normals, colors, indices, collision_faces,
		a, b, c, d, face_normal, color
	)


static func _append_horizontal_face_polygon(
	segments: Array[WallSegment3D],
	segment_index: int,
	footprints: Array[PackedVector2Array],
	clip_exceptions: Array,
	frame: Transform3D,
	local_polygon: PackedVector2Array,
	y: float,
	face_normal: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var footprint := PackedVector2Array()
	for local_point in local_polygon:
		footprint.append(_plan_point(frame, local_point.x, local_point.y))
	if _signed_area(footprint) < 0.0:
		footprint.reverse()
	var polygons: Array[PackedVector2Array] = [footprint]
	for other_index in range(segments.size()):
		if other_index == segment_index:
			continue
		if footprints[other_index].is_empty():
			continue
		var other_height := segments[other_index].height
		var is_shared_cap_plane := y <= PLANE_EPSILON or absf(y - other_height) <= PLANE_EPSILON
		if is_shared_cap_plane and clip_exceptions.has(other_index):
			continue
		var should_clip := false
		if y > PLANE_EPSILON and y < other_height - PLANE_EPSILON:
			should_clip = true
		elif y <= PLANE_EPSILON or absf(y - other_height) <= PLANE_EPSILON:
			should_clip = other_index < segment_index
		if !should_clip:
			continue
		var remaining: Array[PackedVector2Array] = []
		for polygon in polygons:
			for piece in Geometry2D.clip_polygons(polygon, footprints[other_index]):
				var normalized := _normalized_positive_polygon(piece)
				if !normalized.is_empty():
					remaining.append(normalized)
		polygons = remaining
		if polygons.is_empty():
			return
	for polygon in polygons:
		var triangle_indices := Geometry2D.triangulate_polygon(polygon)
		for triangle_start in range(0, triangle_indices.size(), 3):
			var v0 := _lift(polygon[triangle_indices[triangle_start]], frame, y)
			var v1 := _lift(polygon[triangle_indices[triangle_start + 1]], frame, y)
			var v2 := _lift(polygon[triangle_indices[triangle_start + 2]], frame, y)
			_append_triangle(
				vertices, normals, colors, indices, collision_faces,
				v0, v1, v2, face_normal, color
			)


static func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	var start_index := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(d)
	for index in range(4):
		normals.append(normal)
		colors.append(color)
	indices.append(start_index)
	indices.append(start_index + 2)
	indices.append(start_index + 1)
	indices.append(start_index)
	indices.append(start_index + 3)
	indices.append(start_index + 2)

	collision_faces.append(a)
	collision_faces.append(c)
	collision_faces.append(b)
	collision_faces.append(a)
	collision_faces.append(d)
	collision_faces.append(c)


static func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	if ((b - a).cross(c - a)).dot(normal) < 0.0:
		var swap := b
		b = c
		c = swap
	var start_index := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	for index in range(3):
		normals.append(normal)
		colors.append(color)
	indices.append(start_index)
	indices.append(start_index + 2)
	indices.append(start_index + 1)

	collision_faces.append(a)
	collision_faces.append(c)
	collision_faces.append(b)


static func _cut_values(
	openings: Array[Rect2],
	segment_length: float,
	segment_height: float,
	horizontal: bool,
	segments: Array[WallSegment3D] = [],
	segment_index: int = -1
) -> Array[float]:
	var values: Array[float] = [0.0, segment_length if horizontal else segment_height]
	for opening in openings:
		if horizontal:
			values.append(clampf(opening.position.x, 0.0, segment_length))
			values.append(clampf(opening.end.x, 0.0, segment_length))
		else:
			values.append(clampf(opening.position.y, 0.0, segment_height))
			values.append(clampf(opening.end.y, 0.0, segment_height))
	if !horizontal:
		for other_index in range(segments.size()):
			if other_index == segment_index:
				continue
			var other_height := segments[other_index].height
			if other_height > MIN_SPAN and other_height < segment_height - MIN_SPAN:
				values.append(other_height)
	values.sort()
	var result: Array[float] = []
	for value in values:
		if result.is_empty() or absf(result[result.size() - 1] - value) > MIN_SPAN:
			result.append(value)
	return result


static func _point_inside_opening(point: Vector2, openings: Array[Rect2]) -> bool:
	for opening in openings:
		if opening.has_point(point):
			return true
	return false


static func _append_horizontal_plan_polygon(
	polygon: PackedVector2Array,
	base_y: float,
	y: float,
	face_normal: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var triangle_indices := Geometry2D.triangulate_polygon(polygon)
	for triangle_start in range(0, triangle_indices.size(), 3):
		var p0 := polygon[triangle_indices[triangle_start]]
		var p1 := polygon[triangle_indices[triangle_start + 1]]
		var p2 := polygon[triangle_indices[triangle_start + 2]]
		_append_triangle(
			vertices, normals, colors, indices, collision_faces,
			Vector3(p0.x, base_y + y, p0.y),
			Vector3(p1.x, base_y + y, p1.y),
			Vector3(p2.x, base_y + y, p2.y),
			face_normal,
			color
		)


static func _segment_miter_plan(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int
) -> Dictionary:
	var segment := segments[segment_index]
	var segment_length := segment.get_length()
	var half_thickness := segment.thickness * 0.5
	var plan := _default_miter_plan(segment_length, half_thickness)
	if segment_length <= MIN_SPAN:
		return plan
	_apply_endpoint_miter(segments, frames, segment_index, true, plan)
	_apply_endpoint_miter(segments, frames, segment_index, false, plan)
	return plan


static func _default_miter_plan(segment_length: float, half_thickness: float) -> Dictionary:
	return {
		"start_plus": Vector2(0.0, half_thickness),
		"start_minus": Vector2(0.0, -half_thickness),
		"end_plus": Vector2(segment_length, half_thickness),
		"end_minus": Vector2(segment_length, -half_thickness),
		"start_mitered": false,
		"end_mitered": false,
		"start_cap_suppressed": false,
		"end_cap_suppressed": false,
		"start_partners": [],
		"end_partners": [],
	}


static func _apply_endpoint_miter(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int,
	is_start: bool,
	plan: Dictionary
) -> void:
	var segment := segments[segment_index]
	var frame := frames[segment_index]
	var segment_length := segment.get_length()
	var half_thickness := segment.thickness * 0.5
	var joint := _endpoint_plan_point(frame, segment_length, is_start)
	var current_dir := _endpoint_out_direction(frame, is_start)
	var current_side := _plan_side(frame)
	var partner_indices := _non_collinear_endpoint_neighbor_indices(
		segments,
		frames,
		segment_index,
		joint,
		current_dir,
		half_thickness
	)
	var collinear_partner_indices := _collinear_endpoint_neighbor_indices(
		segments,
		frames,
		segment_index,
		joint,
		current_dir,
		half_thickness
	)
	if !collinear_partner_indices.is_empty():
		if is_start:
			plan["start_cap_suppressed"] = true
		else:
			plan["end_cap_suppressed"] = true
		return
	if partner_indices.is_empty():
		return
	if _has_opposite_endpoint_neighbor_pair(
		segments,
		frames,
		partner_indices,
		joint,
		half_thickness
	):
		if is_start:
			plan["start_cap_suppressed"] = true
		else:
			plan["end_cap_suppressed"] = true
		return
	var plus_x := _miter_corner_local_x(
		segments,
		frames,
		segment_index,
		joint,
		current_dir,
		current_side,
		1.0,
		half_thickness,
		is_start,
		segment_length
	)
	var minus_x := _miter_corner_local_x(
		segments,
		frames,
		segment_index,
		joint,
		current_dir,
		current_side,
		-1.0,
		half_thickness,
		is_start,
		segment_length
	)
	if is_start:
		plan["start_plus"] = Vector2(plus_x, half_thickness)
		plan["start_minus"] = Vector2(minus_x, -half_thickness)
		plan["start_mitered"] = true
		plan["start_cap_suppressed"] = true
		plan["start_partners"] = partner_indices
	else:
		plan["end_plus"] = Vector2(plus_x, half_thickness)
		plan["end_minus"] = Vector2(minus_x, -half_thickness)
		plan["end_mitered"] = true
		plan["end_cap_suppressed"] = true
		plan["end_partners"] = partner_indices


static func _miter_corner_local_x(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int,
	joint: Vector2,
	current_dir: Vector2,
	current_side: Vector2,
	sign: float,
	half_thickness: float,
	is_start: bool,
	segment_length: float
) -> float:
	var default_x := 0.0 if is_start else segment_length
	var endpoint_side_sign := sign if is_start else -sign
	var other_endpoint_side_sign := -endpoint_side_sign
	var current_offset_point: Vector2 = joint + current_side * sign * half_thickness
	var best_distance := INF
	var best_x := default_x
	for other_index in range(segments.size()):
		if other_index == segment_index:
			continue
		var other := segments[other_index]
		var other_length := other.get_length()
		if other_length <= MIN_SPAN:
			continue
		var other_half := other.thickness * 0.5
		var joint_tolerance := maxf(maxf(half_thickness, other_half) * 0.35, 0.02)
		var miter_limit := maxf(maxf(half_thickness, other_half) * MITER_LIMIT_MULTIPLIER, MIN_SPAN)
		for other_is_start in [true, false]:
			var other_joint := _endpoint_plan_point(frames[other_index], other_length, other_is_start)
			if other_joint.distance_to(joint) > joint_tolerance:
				continue
			var other_dir := _endpoint_out_direction(frames[other_index], other_is_start)
			if absf(current_dir.dot(other_dir)) > 0.999:
				continue
			var other_side := _plan_side(frames[other_index])
			var other_sign := other_endpoint_side_sign if other_is_start else -other_endpoint_side_sign
			var other_offset_point: Vector2 = other_joint + other_side * other_sign * other_half
			var hit := _line_intersection_params(
				current_offset_point,
				current_dir,
				other_offset_point,
				other_dir
			)
			if hit.is_empty():
				continue
			var t := float(hit["t"])
			var u := float(hit["u"])
			if t < -miter_limit or u < -miter_limit:
				continue
			if t > miter_limit or u > miter_limit:
				continue
			var distance := absf(t)
			if distance >= best_distance:
				continue
			best_distance = distance
			best_x = t if is_start else segment_length - t
	return best_x


static func _non_collinear_endpoint_neighbor_indices(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int,
	joint: Vector2,
	current_dir: Vector2,
	half_thickness: float
) -> Array:
	var result := []
	for other_index in range(segments.size()):
		if other_index == segment_index:
			continue
		var other := segments[other_index]
		var other_length := other.get_length()
		if other_length <= MIN_SPAN:
			continue
		var other_half := other.thickness * 0.5
		var joint_tolerance := maxf(maxf(half_thickness, other_half) * 0.35, 0.02)
		for other_is_start in [true, false]:
			var other_joint := _endpoint_plan_point(frames[other_index], other_length, other_is_start)
			if other_joint.distance_to(joint) > joint_tolerance:
				continue
			var other_dir := _endpoint_out_direction(frames[other_index], other_is_start)
			if absf(current_dir.dot(other_dir)) > 0.999:
				continue
			if !result.has(other_index):
				result.append(other_index)
	return result


static func _collinear_endpoint_neighbor_indices(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int,
	joint: Vector2,
	current_dir: Vector2,
	half_thickness: float
) -> Array:
	var result := []
	for other_index in range(segments.size()):
		if other_index == segment_index:
			continue
		var other := segments[other_index]
		var other_length := other.get_length()
		if other_length <= MIN_SPAN:
			continue
		var other_half := other.thickness * 0.5
		var joint_tolerance := maxf(maxf(half_thickness, other_half) * 0.35, 0.02)
		for other_is_start in [true, false]:
			var other_joint := _endpoint_plan_point(frames[other_index], other_length, other_is_start)
			if other_joint.distance_to(joint) > joint_tolerance:
				continue
			var other_dir := _endpoint_out_direction(frames[other_index], other_is_start)
			if absf(current_dir.dot(other_dir)) <= 0.999:
				continue
			if !result.has(other_index):
				result.append(other_index)
	return result


static func _has_opposite_endpoint_neighbor_pair(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	partner_indices: Array,
	joint: Vector2,
	half_thickness: float
) -> bool:
	var directions: Array[Vector2] = []
	for partner_index in partner_indices:
		var partner := segments[partner_index]
		var partner_length := partner.get_length()
		if partner_length <= MIN_SPAN:
			continue
		var partner_half := partner.thickness * 0.5
		var joint_tolerance := maxf(maxf(half_thickness, partner_half) * 0.35, 0.02)
		for partner_is_start in [true, false]:
			var partner_joint := _endpoint_plan_point(frames[partner_index], partner_length, partner_is_start)
			if partner_joint.distance_to(joint) > joint_tolerance:
				continue
			directions.append(_endpoint_out_direction(frames[partner_index], partner_is_start))
	for first_index in range(directions.size()):
		for second_index in range(first_index + 1, directions.size()):
			if directions[first_index].dot(directions[second_index]) < -0.999:
				return true
	return false


static func _segment_miter_footprint(
	segment: WallSegment3D,
	frame: Transform3D,
	miter_plan: Dictionary
) -> PackedVector2Array:
	var segment_length := segment.get_length()
	if segment_length <= MIN_SPAN:
		return PackedVector2Array()
	var start_plus: Vector2 = miter_plan["start_plus"]
	var end_plus: Vector2 = miter_plan["end_plus"]
	var end_minus: Vector2 = miter_plan["end_minus"]
	var start_minus: Vector2 = miter_plan["start_minus"]
	var corners := PackedVector2Array([
		_plan_point(frame, start_plus.x, start_plus.y),
		_plan_point(frame, end_plus.x, end_plus.y),
		_plan_point(frame, end_minus.x, end_minus.y),
		_plan_point(frame, start_minus.x, start_minus.y),
	])
	if _signed_area(corners) < 0.0:
		corners.reverse()
	return corners


static func _cell_local_points(
	x0: float,
	x1: float,
	half_thickness: float,
	segment_length: float,
	miter_plan: Dictionary
) -> Dictionary:
	var start_plus := Vector2(x0, half_thickness)
	var start_minus := Vector2(x0, -half_thickness)
	var end_plus := Vector2(x1, half_thickness)
	var end_minus := Vector2(x1, -half_thickness)
	if x0 <= MIN_SPAN:
		start_plus = miter_plan["start_plus"]
		start_minus = miter_plan["start_minus"]
	if segment_length - x1 <= MIN_SPAN:
		end_plus = miter_plan["end_plus"]
		end_minus = miter_plan["end_minus"]
	return {
		"start_plus": start_plus,
		"start_minus": start_minus,
		"end_plus": end_plus,
		"end_minus": end_minus,
	}


static func _endpoint_plan_point(
	frame: Transform3D,
	segment_length: float,
	is_start: bool
) -> Vector2:
	return _plan_point(frame, 0.0 if is_start else segment_length, 0.0)


static func _endpoint_y(frame: Transform3D, segment_length: float, is_start: bool) -> float:
	var point := frame.origin + frame.basis.x * (0.0 if is_start else segment_length)
	return point.y


static func _endpoint_out_direction(frame: Transform3D, is_start: bool) -> Vector2:
	var direction := Vector2(frame.basis.x.x, frame.basis.x.z)
	if direction.length_squared() <= MIN_OVERLAP_AREA:
		return Vector2.RIGHT
	direction = direction.normalized()
	return direction if is_start else -direction


static func _plan_side(frame: Transform3D) -> Vector2:
	var side := Vector2(frame.basis.z.x, frame.basis.z.z)
	if side.length_squared() <= MIN_OVERLAP_AREA:
		return Vector2.DOWN
	return side.normalized()


static func _line_intersection_params(
	p: Vector2,
	r: Vector2,
	q: Vector2,
	s: Vector2
) -> Dictionary:
	var denominator := _cross2(r, s)
	if absf(denominator) <= MIN_OVERLAP_AREA:
		return {}
	var delta := q - p
	return {
		"t": _cross2(delta, s) / denominator,
		"u": _cross2(delta, r) / denominator,
	}


static func _cap_normal(frame: Transform3D, local_a: Vector2, local_b: Vector2, desired: Vector3) -> Vector3:
	var edge := frame.basis.x * (local_b.x - local_a.x) + frame.basis.z * (local_b.y - local_a.y)
	if edge.length_squared() <= MIN_OVERLAP_AREA:
		return desired.normalized()
	var normal := edge.cross(Vector3.UP)
	if normal.length_squared() <= MIN_OVERLAP_AREA:
		return desired.normalized()
	normal = normal.normalized()
	if normal.dot(desired) < 0.0:
		normal = -normal
	return normal


static func _deflate(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	if polygon.is_empty():
		return polygon
	var shrunk := Geometry2D.offset_polygon(polygon, -amount, Geometry2D.JOIN_MITER)
	if shrunk.is_empty():
		return polygon
	return shrunk[0]


static func _normalized_positive_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var area := _signed_area(polygon)
	if absf(area) <= MIN_OVERLAP_AREA:
		return PackedVector2Array()
	var result := PackedVector2Array(polygon)
	if area < 0.0:
		result.reverse()
	return result


static func _plan_point(frame: Transform3D, x: float, z: float) -> Vector2:
	var point := frame.origin + frame.basis.x * x + frame.basis.z * z
	return Vector2(point.x, point.z)


static func _lift(point: Vector2, frame: Transform3D, y: float) -> Vector3:
	var origin_2d := Vector2(frame.origin.x, frame.origin.z)
	var dir_2d := Vector2(frame.basis.x.x, frame.basis.x.z)
	var side_2d := Vector2(frame.basis.z.x, frame.basis.z.z)
	var offset := point - origin_2d
	var x := offset.dot(dir_2d)
	var z := offset.dot(side_2d)
	return frame.origin + frame.basis.x * x + frame.basis.z * z + Vector3.UP * y


static func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


static func _cross2(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x
