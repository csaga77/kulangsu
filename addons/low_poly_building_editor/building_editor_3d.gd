@tool
class_name BuildingEditor3D
extends Node3D

const ProceduralWall3DScript = preload("res://addons/low_poly_building_editor/procedural_wall_3d.gd")
const ProceduralFloor3DScript = preload("res://addons/low_poly_building_editor/procedural_floor_3d.gd")
const ProceduralPillar3DScript = preload("res://addons/low_poly_building_editor/procedural_pillar_3d.gd")
const MergedWallMeshBuilderScript = preload("res://addons/low_poly_building_editor/merged_wall_mesh_builder.gd")

const INTERSECT_BASE_TOLERANCE := 0.01

@export_range(0.05, 8.0, 0.05) var grid_step := 0.5:
	set(value):
		grid_step = maxf(value, 0.05)

@export var lock_to_8_way := true
@export_range(0.1, 6.0, 0.05, "or_greater") var default_wall_height := 2.4
@export_range(0.03, 1.0, 0.01, "or_greater") var default_wall_thickness := 0.22
@export var default_wall_color := Color(0.78, 0.68, 0.54, 1.0)
@export_range(0.01, 2.0, 0.01, "or_greater") var default_floor_thickness := 0.12
@export var default_floor_color := Color(0.46, 0.40, 0.32, 1.0)
@export_range(0.05, 4.0, 0.01, "or_greater") var default_pillar_radius := 0.25
@export_range(0.0, 4.0, 0.01, "or_greater") var default_pillar_upper_radius := 0.0
@export_range(0.1, 12.0, 0.05, "or_greater") var default_pillar_height := 2.4
@export_range(3, 24, 1) var default_pillar_sides := 8
@export var default_pillar_style := "round"
@export_range(0.0, 2.0, 0.01, "or_greater") var default_pillar_lower_rim_height := 0.0
@export_range(0.0, 2.0, 0.01, "or_greater") var default_pillar_lower_rim_outset := 0.0
@export_range(0.0, 2.0, 0.01, "or_greater") var default_pillar_upper_rim_height := 0.0
@export_range(0.0, 2.0, 0.01, "or_greater") var default_pillar_upper_rim_outset := 0.0
@export var default_pillar_color := Color(0.70, 0.64, 0.52, 1.0)
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


func create_floor_node(
	local_start: Vector3,
	local_end: Vector3,
	thickness: float = default_floor_thickness,
	color: Color = default_floor_color
) -> ProceduralFloor3DScript:
	var floor := ProceduralFloor3DScript.new() as ProceduralFloor3DScript
	floor.name = _unique_floor_name()
	floor.start_point = local_start
	floor.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	floor.floor_thickness = thickness
	floor.floor_color = color
	floor.build_on_ready = true
	floor.generate_collision = true
	floor.rebuild_floor_mesh()
	return floor


func create_pillar_node(
	local_base: Vector3,
	radius: float = default_pillar_radius,
	height: float = default_pillar_height,
	sides: int = default_pillar_sides,
	style: String = default_pillar_style,
	color: Color = default_pillar_color,
	lower_rim_height: float = default_pillar_lower_rim_height,
	lower_rim_outset: float = default_pillar_lower_rim_outset,
	upper_rim_height: float = default_pillar_upper_rim_height,
	upper_rim_outset: float = default_pillar_upper_rim_outset,
	upper_radius: float = default_pillar_upper_radius
) -> ProceduralPillar3DScript:
	var pillar := ProceduralPillar3DScript.new() as ProceduralPillar3DScript
	pillar.name = _unique_pillar_name()
	pillar.base_point = local_base
	pillar.pillar_radius = radius
	pillar.upper_radius = upper_radius
	pillar.pillar_height = height
	pillar.side_count = sides
	pillar.set_pillar_style(style)
	pillar.pillar_color = color
	pillar.lower_rim_height = lower_rim_height
	pillar.lower_rim_outset = lower_rim_outset
	pillar.upper_rim_height = upper_rim_height
	pillar.upper_rim_outset = upper_rim_outset
	pillar.build_on_ready = true
	pillar.generate_collision = true
	pillar.rebuild_pillar_mesh()
	return pillar


func get_wall_nodes() -> Array[ProceduralWall3DScript]:
	var walls: Array[ProceduralWall3DScript] = []
	for child in get_children():
		if child is ProceduralWall3DScript:
			walls.append(child)
	return walls


func get_floor_nodes() -> Array[ProceduralFloor3DScript]:
	var floors: Array[ProceduralFloor3DScript] = []
	for child in get_children():
		if child is ProceduralFloor3DScript:
			floors.append(child as ProceduralFloor3DScript)
	return floors


func get_pillar_nodes() -> Array[ProceduralPillar3DScript]:
	var pillars: Array[ProceduralPillar3DScript] = []
	for child in get_children():
		if child is ProceduralPillar3DScript:
			pillars.append(child as ProceduralPillar3DScript)
	return pillars


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


func _unique_floor_name() -> String:
	var index := get_floor_nodes().size() + 1
	var candidate := "ProceduralFloor3D%d" % index
	while has_node(candidate):
		index += 1
		candidate = "ProceduralFloor3D%d" % index
	return candidate


func _unique_pillar_name() -> String:
	var index := get_pillar_nodes().size() + 1
	var candidate := "ProceduralPillar3D%d" % index
	while has_node(candidate):
		index += 1
		candidate = "ProceduralPillar3D%d" % index
	return candidate
