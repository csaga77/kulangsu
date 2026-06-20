@tool
class_name BuildingEditor3D
extends Node3D

const ProceduralWall3DScript = preload("res://addons/low_poly_building_editor/procedural_wall_3d.gd")
const MergedWallMeshBuilderScript = preload("res://addons/low_poly_building_editor/merged_wall_mesh_builder.gd")

const INTERSECT_BASE_TOLERANCE := 0.01

@export_range(0.05, 8.0, 0.05) var grid_step := 0.5:
	set(value):
		grid_step = maxf(value, 0.05)

@export var lock_to_8_way := true
@export_range(0.1, 6.0, 0.05, "or_greater") var default_wall_height := 2.4
@export_range(0.03, 1.0, 0.01, "or_greater") var default_wall_thickness := 0.22
@export var default_wall_color := Color(0.78, 0.68, 0.54, 1.0)
@export var merge_intersecting := true


func snap_local_position(local_position: Vector3) -> Vector3:
	var step := maxf(grid_step, 0.05)
	return Vector3(
		roundf(local_position.x / step) * step,
		roundf(local_position.y / step) * step,
		roundf(local_position.z / step) * step
	)


func snap_world_position(world_position: Vector3) -> Vector3:
	return to_global(snap_local_position(to_local(world_position)))


func constrain_wall_end(start_local: Vector3, target_local: Vector3) -> Vector3:
	var snapped_target := snap_local_position(target_local)
	if !lock_to_8_way:
		return snapped_target

	var flat_delta := Vector2(snapped_target.x - start_local.x, snapped_target.z - start_local.z)
	if flat_delta.length_squared() <= 0.000001:
		return start_local

	var angle_step := PI * 0.25
	var angle := atan2(flat_delta.y, flat_delta.x)
	var locked_angle := roundf(angle / angle_step) * angle_step
	var length := roundf(flat_delta.length() / maxf(grid_step, 0.05)) * maxf(grid_step, 0.05)
	var locked := Vector3(cos(locked_angle) * length, 0.0, sin(locked_angle) * length)
	return snap_local_position(start_local + locked)


func create_wall_node(
	local_start: Vector3,
	local_end: Vector3,
	height: float = default_wall_height,
	thickness: float = default_wall_thickness,
	color: Color = default_wall_color
) -> ProceduralWall3DScript:
	var wall := ProceduralWall3DScript.new() as ProceduralWall3DScript
	wall.name = _unique_wall_name()
	wall.start_point = local_start
	wall.end_point = local_end
	wall.wall_height = height
	wall.wall_thickness = thickness
	wall.wall_color = color
	wall.build_on_ready = true
	wall.generate_collision = true
	wall.rebuild_wall_mesh()
	return wall


func get_wall_nodes() -> Array[ProceduralWall3DScript]:
	var walls: Array[ProceduralWall3DScript] = []
	for child in get_children():
		if child is ProceduralWall3DScript:
			walls.append(child)
	return walls


func find_merge_target(
	local_start: Vector3,
	local_end: Vector3,
	thickness: float,
	height: float,
	ignored_wall: Node = null
) -> Dictionary:
	var new_axis := _flat_direction(local_start, local_end)
	if new_axis == Vector2.ZERO:
		return {}

	var tolerance := maxf(grid_step * 0.25, 0.03)
	var new_start_2d := Vector2(local_start.x, local_start.z)
	var new_end_2d := Vector2(local_end.x, local_end.z)
	for wall in get_wall_nodes():
		if wall == ignored_wall:
			continue
		if absf(wall.start_point.y - local_start.y) > INTERSECT_BASE_TOLERANCE:
			continue
		if !is_equal_approx(wall.wall_thickness, thickness):
			continue
		if !is_equal_approx(wall.wall_height, height):
			continue
		var existing_axis := _flat_direction(wall.start_point, wall.end_point)
		if existing_axis == Vector2.ZERO:
			continue
		if absf(existing_axis.dot(new_axis)) < 0.999:
			continue

		var origin := Vector2(wall.start_point.x, wall.start_point.z)
		var existing_length := Vector2(
			wall.end_point.x - wall.start_point.x,
			wall.end_point.z - wall.start_point.z
		).length()
		var new_start_distance := _line_distance(origin, existing_axis, new_start_2d)
		var new_end_distance := _line_distance(origin, existing_axis, new_end_2d)
		if maxf(new_start_distance, new_end_distance) > tolerance:
			continue

		var new_start_projection := (new_start_2d - origin).dot(existing_axis)
		var new_end_projection := (new_end_2d - origin).dot(existing_axis)
		var new_min := minf(new_start_projection, new_end_projection)
		var new_max := maxf(new_start_projection, new_end_projection)
		if maxf(0.0, new_min) > minf(existing_length, new_max) + tolerance:
			continue

		var merged_min := minf(0.0, new_min)
		var merged_max := maxf(existing_length, new_max)
		var merged_start_2d := origin + existing_axis * merged_min
		var merged_end_2d := origin + existing_axis * merged_max
		return {
			"wall": wall,
			"start": Vector3(merged_start_2d.x, wall.start_point.y, merged_start_2d.y),
			"end": Vector3(merged_end_2d.x, wall.start_point.y, merged_end_2d.y),
		}
	return {}


## Walls whose footprints (primary span or any extra segment) overlap the
## candidate span on the same base plane. Preview-tagged walls are skipped.
func find_intersecting_walls(
	local_start: Vector3,
	local_end: Vector3,
	thickness: float,
	ignored_wall: Node = null
) -> Array[ProceduralWall3DScript]:
	var hits: Array[ProceduralWall3DScript] = []
	var candidate := MergedWallMeshBuilderScript.footprint_from_points(local_start, local_end, thickness)
	if candidate.is_empty():
		return hits
	for wall in get_wall_nodes():
		if wall == ignored_wall:
			continue
		if wall.has_meta(ProceduralWall3DScript.PREVIEW_META):
			continue
		for segment_index in range(wall.get_segment_count()):
			var segment := wall.get_segment(segment_index)
			if absf(segment.start_point.y - local_start.y) > INTERSECT_BASE_TOLERANCE:
				continue
			var footprint := MergedWallMeshBuilderScript.footprint_from_points(
				segment.start_point, segment.end_point, segment.thickness
			)
			if MergedWallMeshBuilderScript.footprints_overlap(candidate, footprint):
				hits.append(wall)
				break
	return hits


func _flat_direction(local_start: Vector3, local_end: Vector3) -> Vector2:
	var delta := Vector2(local_end.x - local_start.x, local_end.z - local_start.z)
	if delta.length_squared() <= 0.000001:
		return Vector2.ZERO
	return delta.normalized()


func _line_distance(origin: Vector2, axis: Vector2, point: Vector2) -> float:
	var offset := point - origin
	return absf(offset.x * axis.y - offset.y * axis.x)


func _unique_wall_name() -> String:
	var index := get_wall_nodes().size() + 1
	var candidate := "ProceduralWall3D%d" % index
	while has_node(candidate):
		index += 1
		candidate = "ProceduralWall3D%d" % index
	return candidate
