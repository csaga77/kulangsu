@tool
class_name MergedWallMeshBuilder
extends RefCounted

## Static mesh-construction helpers for multi-segment ProceduralWall3D nodes.
## Builds combined geometry for a set of wall segments, clipping faces in
## plan (XZ) space against the other segments so junctions render without
## buried interior geometry or z-fighting caps. Segments are assumed to share
## a base plane. Caps at a shared plane are kept by the lowest-index segment
## and clipped from the others; vertical faces are clipped against slightly
## deflated footprints so they end just inside the neighboring segment.

const PLANE_EPSILON := 0.002
const VERTICAL_CLIP_DEFLATE := 0.001
const MIN_OVERLAP_AREA := 0.000001
const MIN_SPAN := 0.001


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
	collision_faces: PackedVector3Array
) -> void:
	var footprints: Array[PackedVector2Array] = []
	var deflated: Array[PackedVector2Array] = []
	for index in range(segments.size()):
		var footprint := segment_footprint(segments[index], frames[index])
		footprints.append(footprint)
		deflated.append(_deflate(footprint, VERTICAL_CLIP_DEFLATE))
	for index in range(segments.size()):
		var rects: Array[Rect2] = []
		if index < opening_rects.size():
			rects = opening_rects[index]
		_append_segment_geometry(
			segments,
			frames,
			index,
			footprints,
			deflated,
			rects,
			vertices,
			normals,
			colors,
			indices,
			collision_faces
		)


static func _append_segment_geometry(
	segments: Array[WallSegment3D],
	frames: Array[Transform3D],
	segment_index: int,
	footprints: Array[PackedVector2Array],
	deflated: Array[PackedVector2Array],
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
	var y_cuts := _cut_values(opening_rects, segment_length, segment.height, false)
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
	var dir3 := frame.basis.x
	var side3 := frame.basis.z

	_append_vertical_face(
		segments, segment_index, deflated, frame,
		x0, half_thickness, x1, half_thickness, y0, y1, side3, color,
		vertices, normals, colors, indices, collision_faces
	)
	_append_vertical_face(
		segments, segment_index, deflated, frame,
		x0, -half_thickness, x1, -half_thickness, y0, y1, -side3, color,
		vertices, normals, colors, indices, collision_faces
	)
	_append_vertical_face(
		segments, segment_index, deflated, frame,
		x1, -half_thickness, x1, half_thickness, y0, y1, dir3, color,
		vertices, normals, colors, indices, collision_faces
	)
	_append_vertical_face(
		segments, segment_index, deflated, frame,
		x0, -half_thickness, x0, half_thickness, y0, y1, -dir3, color,
		vertices, normals, colors, indices, collision_faces
	)
	_append_horizontal_face(
		segments, segment_index, footprints, frame,
		x0, x1, half_thickness, y1, Vector3.UP, color,
		vertices, normals, colors, indices, collision_faces
	)
	_append_horizontal_face(
		segments, segment_index, footprints, frame,
		x0, x1, half_thickness, y0, Vector3.DOWN, color,
		vertices, normals, colors, indices, collision_faces
	)


static func _append_vertical_face(
	segments: Array[WallSegment3D],
	segment_index: int,
	deflated: Array[PackedVector2Array],
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


static func _append_horizontal_face(
	segments: Array[WallSegment3D],
	segment_index: int,
	footprints: Array[PackedVector2Array],
	frame: Transform3D,
	x0: float, x1: float,
	half_thickness: float,
	y: float,
	face_normal: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array
) -> void:
	var rect := PackedVector2Array([
		_plan_point(frame, x0, -half_thickness),
		_plan_point(frame, x1, -half_thickness),
		_plan_point(frame, x1, half_thickness),
		_plan_point(frame, x0, half_thickness),
	])
	if _signed_area(rect) < 0.0:
		rect.reverse()
	var polygons: Array[PackedVector2Array] = [rect]
	for other_index in range(segments.size()):
		if other_index == segment_index:
			continue
		if footprints[other_index].is_empty():
			continue
		var other_height := segments[other_index].height
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
				if _signed_area(piece) > MIN_OVERLAP_AREA:
					remaining.append(piece)
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
	horizontal: bool
) -> Array[float]:
	var values: Array[float] = [0.0, segment_length if horizontal else segment_height]
	for opening in openings:
		if horizontal:
			values.append(clampf(opening.position.x, 0.0, segment_length))
			values.append(clampf(opening.end.x, 0.0, segment_length))
		else:
			values.append(clampf(opening.position.y, 0.0, segment_height))
			values.append(clampf(opening.end.y, 0.0, segment_height))
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


static func _deflate(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	if polygon.is_empty():
		return polygon
	var shrunk := Geometry2D.offset_polygon(polygon, -amount, Geometry2D.JOIN_MITER)
	if shrunk.is_empty():
		return polygon
	return shrunk[0]


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
