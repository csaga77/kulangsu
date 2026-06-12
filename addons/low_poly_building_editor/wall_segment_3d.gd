@tool
class_name WallSegment3D
extends Resource

## One straight wall span stored inside a MergedWall3D node. Points are in
## the owning node's local space; the segment's render frame is derived from
## them the same way ProceduralWall3D derives its transform.

@export var start_point := Vector3.ZERO
@export var end_point := Vector3(4.0, 0.0, 0.0)
@export_range(0.03, 4.0, 0.01) var thickness := 0.22
@export_range(0.1, 20.0, 0.01) var height := 2.4
@export var color := Color(0.78, 0.68, 0.54, 1.0)


func get_length() -> float:
	return Vector2(end_point.x - start_point.x, end_point.z - start_point.z).length()


## Collinear-merges `candidate` into an existing entry of `segments` when
## axis, line offset, thickness, height, and base match within tolerance and
## the ranges overlap; otherwise appends it. Returns true when extended.
static func merge_into(
	segments: Array[WallSegment3D],
	candidate: WallSegment3D,
	tolerance: float
) -> bool:
	var candidate_axis := _flat_axis(candidate.start_point, candidate.end_point)
	if candidate_axis == Vector2.ZERO:
		return false
	var candidate_start := Vector2(candidate.start_point.x, candidate.start_point.z)
	var candidate_end := Vector2(candidate.end_point.x, candidate.end_point.z)
	for segment in segments:
		if !is_equal_approx(segment.thickness, candidate.thickness):
			continue
		if !is_equal_approx(segment.height, candidate.height):
			continue
		if absf(segment.start_point.y - candidate.start_point.y) > 0.01:
			continue
		var axis := _flat_axis(segment.start_point, segment.end_point)
		if axis == Vector2.ZERO:
			continue
		if absf(axis.dot(candidate_axis)) < 0.999:
			continue
		var origin := Vector2(segment.start_point.x, segment.start_point.z)
		if _line_distance(origin, axis, candidate_start) > tolerance:
			continue
		if _line_distance(origin, axis, candidate_end) > tolerance:
			continue
		var segment_length := segment.get_length()
		var start_projection := (candidate_start - origin).dot(axis)
		var end_projection := (candidate_end - origin).dot(axis)
		var projected_min := minf(start_projection, end_projection)
		var projected_max := maxf(start_projection, end_projection)
		if maxf(0.0, projected_min) > minf(segment_length, projected_max) + tolerance:
			continue
		var merged_min := minf(0.0, projected_min)
		var merged_max := maxf(segment_length, projected_max)
		var base_y := segment.start_point.y
		var merged_start := origin + axis * merged_min
		var merged_end := origin + axis * merged_max
		segment.start_point = Vector3(merged_start.x, base_y, merged_start.y)
		segment.end_point = Vector3(merged_end.x, base_y, merged_end.y)
		return true
	segments.append(candidate)
	return false


static func _flat_axis(from_point: Vector3, to_point: Vector3) -> Vector2:
	var delta := Vector2(to_point.x - from_point.x, to_point.z - from_point.z)
	if delta.length_squared() <= 0.000001:
		return Vector2.ZERO
	return delta.normalized()


static func _line_distance(origin: Vector2, axis: Vector2, point: Vector2) -> float:
	var offset := point - origin
	return absf(offset.x * axis.y - offset.y * axis.x)


func get_frame() -> Transform3D:
	var flat_delta := Vector3(end_point.x - start_point.x, 0.0, end_point.z - start_point.z)
	var direction := Vector3.RIGHT
	if flat_delta.length_squared() > 0.000001:
		direction = flat_delta.normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() <= 0.000001:
		side = Vector3.BACK
	side = side.normalized()
	return Transform3D(Basis(direction, Vector3.UP, side).orthonormalized(), start_point)
