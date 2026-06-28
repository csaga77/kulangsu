@tool
class_name Building3D
extends Node3D

const GEOMETRY_CLIP_REFRESH_INTERVAL_SECONDS := 0.2

var m_geometry_clip_signature := ""
var m_geometry_clip_refresh_timer := 0.0


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	m_geometry_clip_signature = _build_geometry_clip_signature()
	call_deferred("refresh_building_geometry_clips")


func _process(delta: float) -> void:
	if !Engine.is_editor_hint():
		return
	m_geometry_clip_refresh_timer += delta
	if m_geometry_clip_refresh_timer < GEOMETRY_CLIP_REFRESH_INTERVAL_SECONDS:
		return
	m_geometry_clip_refresh_timer = 0.0
	var signature := _build_geometry_clip_signature()
	if signature == m_geometry_clip_signature:
		return
	m_geometry_clip_signature = signature
	refresh_building_geometry_clips()


func get_wall_nodes() -> Array[Wall3D]:
	var walls: Array[Wall3D] = []
	for child in get_children():
		if child is Wall3D:
			walls.append(child)
	return walls


func get_roof_nodes() -> Array[Roof3D]:
	var roofs: Array[Roof3D] = []
	for child in get_children():
		if child is Roof3D:
			roofs.append(child)
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
	return _create_roof_geometry_resolver().find_roof_merge_target(
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		rotation_degrees,
		ignored_roof,
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
	return _create_roof_geometry_resolver().compute_roof_covered_rects(
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
	return _create_roof_geometry_resolver().compute_roof_cover_regions(
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


func roof_has_visible_render_area(
	local_start: Vector3,
	local_end: Vector3,
	overhang: float,
	covers: Array[Rect2]
) -> bool:
	return _create_roof_geometry_resolver().roof_has_visible_render_area(
		local_start,
		local_end,
		overhang,
		covers
	)


func roof_has_visible_cover_area(
	local_start: Vector3,
	local_end: Vector3,
	overhang: float,
	covers: Array[Rect2],
	cover_polygons: Array[PackedVector2Array]
) -> bool:
	return _create_roof_geometry_resolver().roof_has_visible_cover_area(
		local_start,
		local_end,
		overhang,
		covers,
		cover_polygons
	)


func refresh_wall_intersection_clips() -> void:
	_create_wall_geometry_resolver().refresh_wall_intersection_clips()


func refresh_roof_covered_rects() -> void:
	_create_roof_geometry_resolver().refresh_roof_covered_rects()


func find_merge_target(
	local_start: Vector3,
	local_end: Vector3,
	thickness: float,
	height: float,
	ignored_wall: Node = null,
	grid_step: float = 0.5
) -> Dictionary:
	return _create_wall_geometry_resolver(grid_step).find_merge_target(
		local_start,
		local_end,
		thickness,
		height,
		ignored_wall
	)


func find_intersecting_walls(
	local_start: Vector3,
	local_end: Vector3,
	thickness: float,
	ignored_wall: Node = null
) -> Array[Wall3D]:
	return _create_wall_geometry_resolver().find_intersecting_walls(
		local_start,
		local_end,
		thickness,
		ignored_wall
	)


func can_place_wall_opening(
	wall: Wall3D,
	segment_index: int,
	center: Vector2,
	size: Vector2,
	clearance: float = 0.03,
	ignored_opening: Node = null,
	allow_base_edge: bool = false
) -> bool:
	return _create_wall_geometry_resolver().can_place_wall_opening(
		wall,
		segment_index,
		center,
		size,
		clearance,
		ignored_opening,
		allow_base_edge
	)


func _create_roof_geometry_resolver() -> RoofGeometryResolver:
	return RoofGeometryResolver.new(get_roof_nodes())


func _create_wall_geometry_resolver(grid_step: float = 0.5) -> WallGeometryResolver:
	return WallGeometryResolver.new(
		self,
		get_wall_nodes(),
		grid_step,
		_create_roof_geometry_resolver()
	)



func refresh_building_geometry_clips() -> void:
	refresh_roof_covered_rects()
	refresh_wall_intersection_clips()
	m_geometry_clip_signature = _build_geometry_clip_signature()


func _build_geometry_clip_signature() -> String:
	var parts: Array[String] = []
	for wall in get_wall_nodes():
		if wall.has_meta(Wall3D.PREVIEW_META):
			continue
		parts.append("wall:%s" % wall.name)
		parts.append(_signature_float(wall.wall_height))
		parts.append(_signature_float(wall.wall_thickness))
		for segment_index in range(wall.get_segment_count()):
			var segment := wall.get_segment(segment_index)
			if segment == null:
				continue
			parts.append("segment:%d" % segment_index)
			parts.append(_signature_vector3(segment.start_point))
			parts.append(_signature_vector3(segment.end_point))
			parts.append(_signature_float(segment.height))
			parts.append(_signature_float(segment.thickness))
		parts.append("openings:%s" % wall.get_opening_signature())
	for roof in get_roof_nodes():
		if roof.has_meta(Roof3D.PREVIEW_META):
			continue
		parts.append("roof:%s" % roof.name)
		parts.append(_signature_vector3(roof.start_point))
		parts.append(_signature_vector3(roof.end_point))
		parts.append(roof.get_roof_style())
		parts.append(_signature_float(roof.get_roof_angle_degrees()))
		parts.append(_signature_float(roof.roof_thickness))
		parts.append(_signature_float(roof.roof_overhang))
		parts.append(_signature_float(roof.roof_rotation_degrees))
		parts.append(_signature_float(roof.get_hip_gable_height()))
	return "|".join(parts)


func _signature_vector3(value: Vector3) -> String:
	return "%s,%s,%s" % [
		_signature_float(value.x),
		_signature_float(value.y),
		_signature_float(value.z),
	]


func _signature_float(value: float) -> String:
	return "%0.4f" % value
