@tool
class_name BuildingEditor3D
extends Node3D

const Wall3DScript = preload("res://addons/low_poly_building_editor/wall_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floor_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roof_3d.gd")
const MergedWallMeshBuilderScript = preload("res://addons/low_poly_building_editor/merged_wall_mesh_builder.gd")

const INTERSECT_BASE_TOLERANCE := 0.01
const ROOF_COVER_HEIGHT_EPSILON := 0.01

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
@export var default_roof_style := "gable"
@export_range(0.0, 89.0, 1.0) var default_roof_height := 40.0
@export_range(0.02, 2.0, 0.01, "or_greater") var default_roof_thickness := 0.12
@export_range(0.0, 4.0, 0.01, "or_greater") var default_roof_overhang := 0.2
@export_range(0.0, 20.0, 0.01, "or_greater") var default_roof_hip_gable_height := 0.0
@export_range(-180.0, 180.0, 1.0) var default_roof_rotation_degrees := 0.0
@export var default_roof_color := Color(0.50, 0.34, 0.25, 1.0)
@export var default_roof_debug_wireframe := false
@export var merge_intersecting := true


func _ready() -> void:
	call_deferred("refresh_wall_intersection_clips")


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
) -> Wall3DScript:
	var wall := Wall3DScript.new() as Wall3DScript
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
) -> Floor3DScript:
	var floor := Floor3DScript.new() as Floor3DScript
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
) -> Pillar3DScript:
	var pillar := Pillar3DScript.new() as Pillar3DScript
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


func create_roof_node(
	local_start: Vector3,
	local_end: Vector3,
	style: String = default_roof_style,
	height: float = default_roof_height,
	thickness: float = default_roof_thickness,
	overhang: float = default_roof_overhang,
	color: Color = default_roof_color,
	rotation_degrees: float = default_roof_rotation_degrees,
	debug_wireframe: bool = default_roof_debug_wireframe,
	hip_gable_height: float = default_roof_hip_gable_height
) -> Roof3DScript:
	var roof := Roof3DScript.new() as Roof3DScript
	roof.name = _unique_roof_name()
	roof.start_point = local_start
	roof.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	roof.set_roof_style(style)
	roof.roof_height = height
	roof.roof_thickness = thickness
	roof.roof_overhang = overhang
	roof.hip_gable_height = hip_gable_height
	roof.roof_color = color
	roof.roof_rotation_degrees = rotation_degrees
	roof.build_on_ready = true
	roof.generate_collision = true
	roof.debug_show_triangle_wireframe = debug_wireframe
	roof.rebuild_roof_mesh()
	return roof


func get_wall_nodes() -> Array[Wall3DScript]:
	var walls: Array[Wall3DScript] = []
	for child in get_children():
		if child is Wall3DScript:
			walls.append(child)
	return walls


func get_floor_nodes() -> Array[Floor3DScript]:
	var floors: Array[Floor3DScript] = []
	for child in get_children():
		if child is Floor3DScript:
			floors.append(child as Floor3DScript)
	return floors


func get_pillar_nodes() -> Array[Pillar3DScript]:
	var pillars: Array[Pillar3DScript] = []
	for child in get_children():
		if child is Pillar3DScript:
			pillars.append(child as Pillar3DScript)
	return pillars


func get_roof_nodes() -> Array[Roof3DScript]:
	var roofs: Array[Roof3DScript] = []
	for child in get_children():
		if child is Roof3DScript:
			roofs.append(child as Roof3DScript)
	return roofs


func find_roof_merge_target(
	local_start: Vector3,
	local_end: Vector3,
	style: String,
	height: float,
	thickness: float,
	overhang: float,
	color: Color,
	rotation_degrees: float = 0.0,
	ignored_roof: Node = null,
	hip_gable_height: float = 0.0
) -> Dictionary:
	return _find_roof_cover_data(
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		rotation_degrees,
		ignored_roof,
		false,
		hip_gable_height
	)


func compute_roof_covered_rects(
	local_start: Vector3,
	local_end: Vector3,
	style: String,
	height: float,
	thickness: float,
	overhang: float,
	color: Color,
	rotation_degrees: float = 0.0,
	ignored_roof: Node = null,
	only_before_ignored_roof := false,
	hip_gable_height: float = 0.0
) -> Array[Rect2]:
	var cover_data := compute_roof_cover_regions(
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		rotation_degrees,
		ignored_roof,
		only_before_ignored_roof,
		hip_gable_height
	)
	var rects: Array[Rect2] = []
	for rect in cover_data.get("covered_rects", []):
		rects.append(rect)
	return rects


func compute_roof_cover_regions(
	local_start: Vector3,
	local_end: Vector3,
	style: String,
	height: float,
	thickness: float,
	overhang: float,
	color: Color,
	rotation_degrees: float = 0.0,
	ignored_roof: Node = null,
	only_before_ignored_roof := false,
	hip_gable_height: float = 0.0
) -> Dictionary:
	return _find_roof_cover_data(
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		rotation_degrees,
		ignored_roof,
		only_before_ignored_roof,
		hip_gable_height
	)


func roof_has_visible_render_area(local_start: Vector3, local_end: Vector3, overhang: float, covers: Array[Rect2]) -> bool:
	var size := Vector2(absf(local_end.x - local_start.x), absf(local_end.z - local_start.z))
	if size.x <= 0.001 or size.y <= 0.001:
		return false
	return !_visible_roof_rects(_roof_render_rect(size, overhang), covers).is_empty()


func roof_has_visible_cover_area(
	local_start: Vector3,
	local_end: Vector3,
	overhang: float,
	covers: Array[Rect2],
	cover_polygons: Array[PackedVector2Array]
) -> bool:
	var size := Vector2(absf(local_end.x - local_start.x), absf(local_end.z - local_start.z))
	if size.x <= 0.001 or size.y <= 0.001:
		return false
	if !cover_polygons.is_empty():
		return _cover_polygons_leave_area(_roof_render_rect(size, overhang), cover_polygons)
	return !_visible_roof_rects(_roof_render_rect(size, overhang), covers).is_empty()


func refresh_wall_intersection_clips() -> void:
	var walls := get_wall_nodes()
	for wall_index in range(walls.size()):
		var wall := walls[wall_index]
		if wall.has_meta(Wall3DScript.PREVIEW_META) or !merge_intersecting:
			wall.clear_intersection_clip_segments()
			continue
		var before_segments: Array[WallSegment3D] = []
		var after_segments: Array[WallSegment3D] = []
		for other_index in range(walls.size()):
			if other_index == wall_index:
				continue
			var other := walls[other_index]
			if other.has_meta(Wall3DScript.PREVIEW_META):
				continue
			for segment_index in range(other.get_segment_count()):
				var segment := other.get_segment(segment_index)
				if !_wall_clip_segment_relevant(wall, segment):
					continue
				if other_index < wall_index:
					before_segments.append(segment)
				else:
					after_segments.append(segment)
		wall.set_intersection_clip_segments(before_segments, after_segments)


func refresh_roof_covered_rects() -> void:
	for roof in get_roof_nodes():
		if roof.has_meta(Roof3DScript.PREVIEW_META):
			continue
		var cover_regions := compute_roof_cover_regions(
			roof.start_point,
			roof.end_point,
			roof.get_roof_style(),
			roof.roof_height,
			roof.roof_thickness,
			roof.roof_overhang,
			roof.roof_color,
			roof.roof_rotation_degrees,
			roof,
			true,
			roof.hip_gable_height
		)
		roof.set_covered_regions(
			_roof_covered_rects_from_regions(cover_regions),
			_roof_covered_polygons_from_regions(cover_regions)
		)


func _find_roof_cover_data(
	local_start: Vector3,
	local_end: Vector3,
	style: String,
	height: float,
	_thickness: float,
	overhang: float,
	_color: Color,
	rotation_degrees: float,
	ignored_roof: Node,
	_only_before_ignored_roof: bool,
	hip_gable_height: float
) -> Dictionary:
	var new_size := Vector2(absf(local_end.x - local_start.x), absf(local_end.z - local_start.z))
	if new_size.x <= 0.001 or new_size.y <= 0.001:
		return {}
	var new_rotation := _normalize_degrees(rotation_degrees)
	var new_anchor := _roof_anchor_from_points(local_start, local_end)
	var new_basis := _rotation_basis(new_rotation)
	var new_rect := _roof_render_rect(new_size, overhang)
	var covered_rects: Array[Rect2] = []
	var covered_polygons: Array[PackedVector2Array] = []
	var first_target: Roof3DScript = null
	var candidate_seen := false
	for roof in get_roof_nodes():
		if roof == ignored_roof:
			candidate_seen = true
			continue
		if roof.has_meta(Roof3DScript.PREVIEW_META):
			continue
		if absf(roof.start_point.y - local_start.y) > INTERSECT_BASE_TOLERANCE:
			continue
		var other_before_candidate := !candidate_seen
		var existing_anchor := roof.get_roof_anchor_point()
		for visible_rect in [roof.get_roof_render_rect()]:
			var projected_existing_rect := _roof_projected_rect_from_local_rect(
				existing_anchor,
				roof.roof_rotation_degrees,
				visible_rect,
				new_anchor,
				new_rotation
			)
			var covered_rect := _rect_intersection(new_rect, projected_existing_rect)
			if covered_rect.size.x <= 0.001 or covered_rect.size.y <= 0.001:
				continue
			var under_polygons := _roof_polygons_under_other_roof(
				new_anchor,
				new_basis,
				local_start.y,
				new_size,
				style,
				height,
				overhang,
				hip_gable_height,
				roof,
				covered_rect,
				other_before_candidate
			)
			if under_polygons.is_empty():
				continue
			if first_target == null:
				first_target = roof
			for polygon in under_polygons:
				covered_polygons.append(polygon)
				covered_rects.append(_polygon_bounds(polygon))
	if first_target == null:
		return {}
	return {
		"roof": first_target,
		"covered_rects": covered_rects,
		"covered_polygons": covered_polygons,
		"rotation_degrees": new_rotation,
	}


func _roof_polygons_under_other_roof(
	candidate_anchor: Vector3,
	candidate_basis: Basis,
	candidate_base_y: float,
	candidate_size: Vector2,
	candidate_style: String,
	candidate_angle_degrees: float,
	candidate_overhang: float,
	candidate_hip_gable_height: float,
	other_roof: Roof3DScript,
	overlap_rect: Rect2,
	other_before_candidate: bool
) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	var candidate_faces := Roof3DScript.roof_top_faces_for_style(
		candidate_style,
		candidate_size,
		candidate_overhang,
		candidate_angle_degrees,
		candidate_hip_gable_height
	)
	var other_faces := Roof3DScript.roof_top_faces_for_style(
		other_roof.get_roof_style(),
		other_roof.get_roof_size(),
		other_roof.roof_overhang,
		other_roof.roof_height,
		other_roof.hip_gable_height
	)
	var candidate_inverse := candidate_basis.inverse()
	var other_anchor := other_roof.get_roof_anchor_point()
	var other_basis := _rotation_basis(other_roof.roof_rotation_degrees)
	var overlap_polygon := _rect_polygon(overlap_rect)
	for candidate_face in candidate_faces:
		var candidate_world_triangle := _triangle_with_base_y(
			PackedVector3Array(candidate_face["plane"]),
			candidate_base_y
		)
		var candidate_polygon := _face_polygon(PackedVector3Array(candidate_face["vertices"]))
		candidate_polygon = _clip_polygon_by_convex_polygon(candidate_polygon, overlap_polygon)
		if absf(_polygon_signed_area(candidate_polygon)) <= 0.0001:
			continue
		for other_face in other_faces:
			var other_projected_triangle := _project_roof_triangle_to_candidate_frame(
				PackedVector3Array(other_face["plane"]),
				other_anchor,
				other_basis,
				candidate_anchor,
				candidate_inverse,
				other_roof.start_point.y
			)
			var other_polygon := _project_roof_face_polygon_to_candidate_frame(
				PackedVector3Array(other_face["vertices"]),
				other_anchor,
				other_basis,
				candidate_anchor,
				candidate_inverse
			)
			var intersection := _clip_polygon_by_convex_polygon(candidate_polygon, other_polygon)
			if absf(_polygon_signed_area(intersection)) <= 0.0001:
				continue
			var under_polygon := _clip_polygon_under_triangle_pair(
				intersection,
				candidate_world_triangle,
				other_projected_triangle,
				other_before_candidate
			)
			if absf(_polygon_signed_area(under_polygon)) <= 0.0001:
				continue
			polygons.append(_normalize_polygon(under_polygon))
	return polygons


func _face_polygon(face_vertices: PackedVector3Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in face_vertices:
		polygon.append(Vector2(point.x, point.z))
	return _normalize_polygon(polygon)


func _triangle_with_base_y(triangle: PackedVector3Array, base_y: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for point in triangle:
		points.append(Vector3(point.x, base_y + point.y, point.z))
	return points


func _project_roof_face_polygon_to_candidate_frame(
	face_vertices: PackedVector3Array,
	other_anchor: Vector3,
	other_basis: Basis,
	candidate_anchor: Vector3,
	candidate_inverse: Basis
) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in face_vertices:
		var parent_point := other_anchor + other_basis * Vector3(point.x, 0.0, point.z)
		var candidate_local := candidate_inverse * (parent_point - candidate_anchor)
		polygon.append(Vector2(candidate_local.x, candidate_local.z))
	return _normalize_polygon(polygon)


func _project_roof_triangle_to_candidate_frame(
	triangle: PackedVector3Array,
	other_anchor: Vector3,
	other_basis: Basis,
	candidate_anchor: Vector3,
	candidate_inverse: Basis,
	other_base_y: float
) -> PackedVector3Array:
	var points := PackedVector3Array()
	for point in triangle:
		var parent_point := other_anchor + other_basis * Vector3(point.x, 0.0, point.z)
		var candidate_local := candidate_inverse * (parent_point - candidate_anchor)
		points.append(Vector3(candidate_local.x, other_base_y + point.y, candidate_local.z))
	return points


func _clip_polygon_under_triangle_pair(
	polygon: PackedVector2Array,
	candidate_triangle: PackedVector3Array,
	other_triangle: PackedVector3Array,
	other_before_candidate: bool
) -> PackedVector2Array:
	if polygon.is_empty():
		return PackedVector2Array()
	var threshold := -ROOF_COVER_HEIGHT_EPSILON if other_before_candidate else ROOF_COVER_HEIGHT_EPSILON
	var diff_points: Array[Vector3] = []
	for point in polygon:
		var candidate_y := _triangle_height_at_point(candidate_triangle, point)
		var other_y := _triangle_height_at_point(other_triangle, point)
		diff_points.append(Vector3(point.x, other_y - candidate_y, point.y))
	var clipped: Array[Vector3] = []
	var previous := diff_points[diff_points.size() - 1]
	var previous_inside := previous.y >= threshold
	for current in diff_points:
		var current_inside := current.y >= threshold
		if current_inside != previous_inside:
			clipped.append(_interpolate_height_threshold(previous, current, threshold))
		if current_inside:
			clipped.append(current)
		previous = current
		previous_inside = current_inside
	var result := PackedVector2Array()
	for point in clipped:
		result.append(Vector2(point.x, point.z))
	return _normalize_polygon(result)


func _triangle_height_at_point(triangle: PackedVector3Array, point: Vector2) -> float:
	if triangle.size() < 3:
		return 0.0
	var a := Vector2(triangle[0].x, triangle[0].z)
	var b := Vector2(triangle[1].x, triangle[1].z)
	var c := Vector2(triangle[2].x, triangle[2].z)
	var denominator := (
		(b.y - c.y) * (a.x - c.x)
		+ (c.x - b.x) * (a.y - c.y)
	)
	if absf(denominator) <= 0.000001:
		return (triangle[0].y + triangle[1].y + triangle[2].y) / 3.0
	var weight_a := (
		(b.y - c.y) * (point.x - c.x)
		+ (c.x - b.x) * (point.y - c.y)
	) / denominator
	var weight_b := (
		(c.y - a.y) * (point.x - c.x)
		+ (a.x - c.x) * (point.y - c.y)
	) / denominator
	var weight_c := 1.0 - weight_a - weight_b
	return triangle[0].y * weight_a + triangle[1].y * weight_b + triangle[2].y * weight_c


func _interpolate_height_threshold(from_point: Vector3, to_point: Vector3, threshold: float) -> Vector3:
	var denominator := to_point.y - from_point.y
	if absf(denominator) <= 0.000001:
		return from_point
	var weight := clampf((threshold - from_point.y) / denominator, 0.0, 1.0)
	return from_point.lerp(to_point, weight)


func _triangle_polygon(triangle: PackedVector3Array) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in triangle:
		polygon.append(Vector2(point.x, point.z))
	return _normalize_polygon(polygon)


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	var rect_min := rect.position
	var rect_max := rect.position + rect.size
	return PackedVector2Array([
		rect_min,
		Vector2(rect_max.x, rect_min.y),
		rect_max,
		Vector2(rect_min.x, rect_max.y),
	])


func _clip_polygon_by_convex_polygon(subject: PackedVector2Array, clip_polygon: PackedVector2Array) -> PackedVector2Array:
	var clipped := _normalize_polygon(subject)
	var clip := _normalize_polygon(clip_polygon)
	for edge_index in range(clip.size()):
		clipped = _clip_polygon_by_edge(clipped, clip[edge_index], clip[(edge_index + 1) % clip.size()])
		if clipped.is_empty():
			break
	return clipped


func _clip_polygon_by_edge(subject: PackedVector2Array, edge_start: Vector2, edge_end: Vector2) -> PackedVector2Array:
	if subject.is_empty():
		return PackedVector2Array()
	var clipped := PackedVector2Array()
	var previous := subject[subject.size() - 1]
	var previous_side := _edge_side(previous, edge_start, edge_end)
	var previous_inside := previous_side >= -0.0001
	for current in subject:
		var current_side := _edge_side(current, edge_start, edge_end)
		var current_inside := current_side >= -0.0001
		if current_inside != previous_inside:
			clipped.append(_interpolate_edge_intersection(previous, current, previous_side, current_side))
		if current_inside:
			clipped.append(current)
		previous = current
		previous_side = current_side
		previous_inside = current_inside
	return _normalize_polygon(clipped)


func _edge_side(point: Vector2, edge_start: Vector2, edge_end: Vector2) -> float:
	var edge := edge_end - edge_start
	var offset := point - edge_start
	return edge.x * offset.y - edge.y * offset.x


func _interpolate_edge_intersection(from_point: Vector2, to_point: Vector2, from_side: float, to_side: float) -> Vector2:
	var denominator := from_side - to_side
	if absf(denominator) <= 0.000001:
		return from_point
	var weight := clampf(from_side / denominator, 0.0, 1.0)
	return from_point.lerp(to_point, weight)


func _normalize_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var normalized := PackedVector2Array()
	for point in polygon:
		if normalized.size() > 0 and normalized[normalized.size() - 1].distance_to(point) <= 0.0001:
			continue
		normalized.append(point)
	if normalized.size() > 1 and normalized[0].distance_to(normalized[normalized.size() - 1]) <= 0.0001:
		normalized.remove_at(normalized.size() - 1)
	if _polygon_signed_area(normalized) < 0.0:
		normalized.reverse()
	return normalized


func _polygon_signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point in polygon:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _cover_polygons_leave_area(full_rect: Rect2, covers: Array[PackedVector2Array]) -> bool:
	var visible: Array[PackedVector2Array] = [_rect_polygon(full_rect)]
	for cover in covers:
		var next_visible: Array[PackedVector2Array] = []
		for polygon in visible:
			next_visible.append_array(_subtract_polygon(polygon, cover))
		visible = next_visible
		if visible.is_empty():
			return false
	for polygon in visible:
		if absf(_polygon_signed_area(polygon)) > 0.0001:
			return true
	return false


func _subtract_polygon(subject: PackedVector2Array, cover: PackedVector2Array) -> Array[PackedVector2Array]:
	var clip := _normalize_polygon(cover)
	if clip.size() < 3:
		return [subject]
	var remaining: Array[PackedVector2Array] = []
	var inside_pieces: Array[PackedVector2Array] = [_normalize_polygon(subject)]
	for edge_index in range(clip.size()):
		var edge_start := clip[edge_index]
		var edge_end := clip[(edge_index + 1) % clip.size()]
		var next_inside: Array[PackedVector2Array] = []
		for piece in inside_pieces:
			var outside_piece := _clip_polygon_by_edge_side(piece, edge_start, edge_end, false)
			if absf(_polygon_signed_area(outside_piece)) > 0.0001:
				remaining.append(outside_piece)
			var inside_piece := _clip_polygon_by_edge_side(piece, edge_start, edge_end, true)
			if absf(_polygon_signed_area(inside_piece)) > 0.0001:
				next_inside.append(inside_piece)
		inside_pieces = next_inside
		if inside_pieces.is_empty():
			break
	return remaining


func _clip_polygon_by_edge_side(
	subject: PackedVector2Array,
	edge_start: Vector2,
	edge_end: Vector2,
	keep_inside: bool
) -> PackedVector2Array:
	if subject.is_empty():
		return PackedVector2Array()
	var clipped := PackedVector2Array()
	var previous := subject[subject.size() - 1]
	var previous_side := _edge_side(previous, edge_start, edge_end)
	var previous_inside := previous_side >= -0.0001
	for current in subject:
		var current_side := _edge_side(current, edge_start, edge_end)
		var current_inside := current_side >= -0.0001
		var previous_kept := previous_inside if keep_inside else !previous_inside
		var current_kept := current_inside if keep_inside else !current_inside
		if current_kept != previous_kept:
			clipped.append(_interpolate_edge_intersection(previous, current, previous_side, current_side))
		if current_kept:
			clipped.append(current)
		previous = current
		previous_side = current_side
		previous_inside = current_inside
	return _normalize_polygon(clipped)


func _roof_covered_rects_from_regions(regions: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for rect in regions.get("covered_rects", []):
		rects.append(rect)
	return rects


func _roof_covered_polygons_from_regions(regions: Dictionary) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for polygon in regions.get("covered_polygons", []):
		polygons.append(PackedVector2Array(polygon))
	return polygons


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
) -> Array[Wall3DScript]:
	var hits: Array[Wall3DScript] = []
	var candidate := MergedWallMeshBuilderScript.footprint_from_points(local_start, local_end, thickness)
	if candidate.is_empty():
		return hits
	for wall in get_wall_nodes():
		if wall == ignored_wall:
			continue
		if wall.has_meta(Wall3DScript.PREVIEW_META):
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


func _wall_clip_segment_relevant(wall: Wall3DScript, clip_segment: WallSegment3D) -> bool:
	if wall == null or clip_segment == null:
		return false
	for own_index in range(wall.get_segment_count()):
		var own_segment := wall.get_segment(own_index)
		if own_segment == null:
			continue
		if absf(own_segment.start_point.y - clip_segment.start_point.y) <= INTERSECT_BASE_TOLERANCE:
			return true
	return false


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
	var candidate := "Wall3D%d" % index
	while has_node(candidate):
		index += 1
		candidate = "Wall3D%d" % index
	return candidate


func _unique_floor_name() -> String:
	var index := get_floor_nodes().size() + 1
	var candidate := "Floor3D%d" % index
	while has_node(candidate):
		index += 1
		candidate = "Floor3D%d" % index
	return candidate


func _unique_pillar_name() -> String:
	var index := get_pillar_nodes().size() + 1
	var candidate := "Pillar3D%d" % index
	while has_node(candidate):
		index += 1
		candidate = "Pillar3D%d" % index
	return candidate


func _unique_roof_name() -> String:
	var index := get_roof_nodes().size() + 1
	var candidate := "Roof3D%d" % index
	while has_node(candidate):
		index += 1
		candidate = "Roof3D%d" % index
	return candidate


func _roof_anchor_from_points(first: Vector3, second: Vector3) -> Vector3:
	return Vector3(minf(first.x, second.x), first.y, minf(first.z, second.z))


func _roof_render_rect(size: Vector2, overhang: float) -> Rect2:
	var resolved_overhang := maxf(overhang, 0.0)
	return Rect2(
		Vector2(-resolved_overhang, -resolved_overhang),
		Vector2(size.x + resolved_overhang * 2.0, size.y + resolved_overhang * 2.0)
	)


func _roof_projected_rect_from_local_rect(
	source_anchor: Vector3,
	rotation_degrees: float,
	source_rect: Rect2,
	frame_origin: Vector3,
	frame_rotation_degrees: float
) -> Rect2:
	var source_basis := _rotation_basis(rotation_degrees)
	var frame_inverse := _rotation_basis(frame_rotation_degrees).inverse()
	var source_min := source_rect.position
	var source_max := source_rect.position + source_rect.size
	var projected_points := [
		frame_inverse * (
			source_anchor + source_basis * Vector3(source_min.x, 0.0, source_min.y) - frame_origin
		),
		frame_inverse * (
			source_anchor + source_basis * Vector3(source_max.x, 0.0, source_min.y) - frame_origin
		),
		frame_inverse * (
			source_anchor + source_basis * Vector3(source_max.x, 0.0, source_max.y) - frame_origin
		),
		frame_inverse * (
			source_anchor + source_basis * Vector3(source_min.x, 0.0, source_max.y) - frame_origin
		),
	]
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for point in projected_points:
		var projected := point as Vector3
		min_x = minf(min_x, projected.x)
		min_z = minf(min_z, projected.z)
		max_x = maxf(max_x, projected.x)
		max_z = maxf(max_z, projected.z)
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))


func _rect_intersection(first: Rect2, second: Rect2) -> Rect2:
	var first_max := first.position + first.size
	var second_max := second.position + second.size
	var min_point := Vector2(maxf(first.position.x, second.position.x), maxf(first.position.y, second.position.y))
	var max_point := Vector2(minf(first_max.x, second_max.x), minf(first_max.y, second_max.y))
	return Rect2(min_point, Vector2(max_point.x - min_point.x, max_point.y - min_point.y))


func _rect_contains_point(rect: Rect2, point: Vector2) -> bool:
	var max_point := rect.position + rect.size
	return (
		point.x >= rect.position.x - 0.001
		and point.y >= rect.position.y - 0.001
		and point.x <= max_point.x + 0.001
		and point.y <= max_point.y + 0.001
	)


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


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.001 and rect.size.y > 0.001


func _rotation_basis(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees(rotation_degrees)))


func _normalize_degrees(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _angles_match(first: float, second: float) -> bool:
	return is_equal_approx(_normalize_degrees(first), _normalize_degrees(second))


func _colors_match(first: Color, second: Color) -> bool:
	return (
		is_equal_approx(first.r, second.r)
		and is_equal_approx(first.g, second.g)
		and is_equal_approx(first.b, second.b)
		and is_equal_approx(first.a, second.a)
	)
