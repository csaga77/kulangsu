@tool
class_name Building3D
extends Node3D

var m_geometry_clip_refresh_queued := false


func _ready() -> void:
	for child in get_children():
		_connect_geometry_source(child)
	if !child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.connect(_on_child_entered_tree)
	if !child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.connect(_on_child_exiting_tree)
	if !child_order_changed.is_connected(_on_child_order_changed):
		child_order_changed.connect(_on_child_order_changed)
	request_geometry_clip_refresh()


func _exit_tree() -> void:
	m_geometry_clip_refresh_queued = false
	for child in get_children():
		_disconnect_geometry_source(child)
	if child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.disconnect(_on_child_entered_tree)
	if child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.disconnect(_on_child_exiting_tree)
	if child_order_changed.is_connected(_on_child_order_changed):
		child_order_changed.disconnect(_on_child_order_changed)


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
	m_geometry_clip_refresh_queued = false
	refresh_roof_covered_rects()
	refresh_wall_intersection_clips()


func request_geometry_clip_refresh() -> void:
	if m_geometry_clip_refresh_queued:
		return
	m_geometry_clip_refresh_queued = true
	call_deferred("_flush_geometry_clip_refresh")


func _flush_geometry_clip_refresh() -> void:
	if !m_geometry_clip_refresh_queued:
		return
	refresh_building_geometry_clips()


func _connect_geometry_source(child: Node) -> void:
	var wall := child as Wall3D
	if wall != null:
		if wall.has_meta(Wall3D.PREVIEW_META):
			return
		if !wall.source_geometry_changed.is_connected(_on_source_geometry_changed):
			wall.source_geometry_changed.connect(_on_source_geometry_changed)
		return
	var roof := child as Roof3D
	if roof == null or roof.has_meta(Roof3D.PREVIEW_META):
		return
	if !roof.source_geometry_changed.is_connected(_on_source_geometry_changed):
		roof.source_geometry_changed.connect(_on_source_geometry_changed)


func _disconnect_geometry_source(child: Node) -> void:
	var wall := child as Wall3D
	if wall != null:
		if wall.source_geometry_changed.is_connected(_on_source_geometry_changed):
			wall.source_geometry_changed.disconnect(_on_source_geometry_changed)
		return
	var roof := child as Roof3D
	if roof == null:
		return
	if roof.source_geometry_changed.is_connected(_on_source_geometry_changed):
		roof.source_geometry_changed.disconnect(_on_source_geometry_changed)


func _on_source_geometry_changed() -> void:
	request_geometry_clip_refresh()


func _on_child_entered_tree(child: Node) -> void:
	if !_is_authored_geometry_source(child):
		return
	_connect_geometry_source(child)
	request_geometry_clip_refresh()


func _on_child_exiting_tree(child: Node) -> void:
	if !_is_authored_geometry_source(child):
		return
	_disconnect_geometry_source(child)
	request_geometry_clip_refresh()


func _on_child_order_changed() -> void:
	request_geometry_clip_refresh()


func _is_authored_geometry_source(child: Node) -> bool:
	if child is Wall3D:
		return !child.has_meta(Wall3D.PREVIEW_META)
	if child is Roof3D:
		return !child.has_meta(Roof3D.PREVIEW_META)
	return false
