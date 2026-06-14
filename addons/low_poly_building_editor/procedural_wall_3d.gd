@tool
class_name ProceduralWall3D
extends MeshInstance3D

const GENERATED_META := &"procedural_wall_generated"
const PREVIEW_META := &"building_editor_preview"
const OPENING_META := &"building_editor_opening"
const SEGMENT_INDEX_META := &"wall_segment_index"
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/building_opening_3d.gd")
const WallSegment3DScript = preload("res://addons/low_poly_building_editor/wall_segment_3d.gd")
const MergedWallMeshBuilderScript = preload("res://addons/low_poly_building_editor/merged_wall_mesh_builder.gd")

const SEGMENT_ASSIGN_MARGIN := 0.25
const SEGMENT_ASSIGN_DEPTH := 0.2

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_wall_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(4.0, 0.0, 0.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export_range(0.1, 20.0, 0.01) var wall_height := 2.4:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(wall_height, clamped_value):
			return
		wall_height = clamped_value
		_request_rebuild()

@export_range(0.03, 4.0, 0.01) var wall_thickness := 0.22:
	set(value):
		var clamped_value := maxf(value, 0.03)
		if is_equal_approx(wall_thickness, clamped_value):
			return
		wall_thickness = clamped_value
		_request_rebuild()

@export var wall_color := Color(0.78, 0.68, 0.54, 1.0):
	set(value):
		if wall_color == value:
			return
		wall_color = value
		_request_rebuild()

## Additional merged wall spans absorbed from intersecting walls. Points are
## parent-local, like start_point/end_point. The node transform and primary
## span stay derived from start_point/end_point.
@export var extra_segments: Array[WallSegment3D] = []:
	set(value):
		extra_segments = value
		_request_rebuild()

@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

@export_range(0.0, 1.0, 0.01) var opening_padding := 0.02:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(opening_padding, clamped_value):
			return
		opening_padding = clamped_value
		_request_rebuild()

var m_is_ready := false
var m_rebuild_queued := false
var m_opening_signature := ""
var m_signature_timer := 0.0
var m_is_rebuilding := false


func _ready() -> void:
	m_is_ready = true
	if !child_entered_tree.is_connected(_on_child_tree_changed):
		child_entered_tree.connect(_on_child_tree_changed)
	if !child_exiting_tree.is_connected(_on_child_tree_changed):
		child_exiting_tree.connect(_on_child_tree_changed)
	set_process(Engine.is_editor_hint())
	if build_on_ready:
		rebuild_wall_mesh()


func _exit_tree() -> void:
	if child_entered_tree.is_connected(_on_child_tree_changed):
		child_entered_tree.disconnect(_on_child_tree_changed)
	if child_exiting_tree.is_connected(_on_child_tree_changed):
		child_exiting_tree.disconnect(_on_child_tree_changed)


func _process(delta: float) -> void:
	if !Engine.is_editor_hint():
		return
	m_signature_timer += delta
	if m_signature_timer < 0.2:
		return
	m_signature_timer = 0.0
	var signature := _build_opening_signature()
	if signature == m_opening_signature:
		return
	rebuild_wall_mesh()


func set_wall_endpoints(new_start: Vector3, new_end: Vector3) -> void:
	start_point = new_start
	end_point = new_end
	rebuild_wall_mesh()


func get_wall_length() -> float:
	return Vector2(end_point.x - start_point.x, end_point.z - start_point.z).length()


func get_wall_direction() -> Vector3:
	var flat_delta := Vector3(end_point.x - start_point.x, 0.0, end_point.z - start_point.z)
	if flat_delta.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return flat_delta.normalized()


func get_segment_count() -> int:
	return 1 + extra_segments.size()


## Segment 0 is the primary span synthesized from this node's exports; the
## rest map to extra_segments. Points are parent-local for every index.
func get_segment(index: int) -> WallSegment3DScript:
	if index <= 0 or index > extra_segments.size():
		var primary := WallSegment3DScript.new()
		primary.start_point = start_point
		primary.end_point = end_point
		primary.thickness = wall_thickness
		primary.height = wall_height
		primary.color = wall_color
		return primary
	return extra_segments[index - 1]


func count_connected_endpoints(endpoint: Vector3, tolerance: float) -> int:
	var count := 0
	if _endpoint_matches(start_point, endpoint, tolerance):
		count += 1
	if _endpoint_matches(end_point, endpoint, tolerance):
		count += 1
	for segment in extra_segments:
		if segment == null:
			continue
		if _endpoint_matches(segment.start_point, endpoint, tolerance):
			count += 1
		if _endpoint_matches(segment.end_point, endpoint, tolerance):
			count += 1
	return count


func move_connected_endpoint(old_endpoint: Vector3, new_endpoint: Vector3, tolerance: float) -> int:
	var moved_count := 0
	if _endpoint_matches(start_point, old_endpoint, tolerance):
		start_point = _endpoint_with_preserved_height(start_point, new_endpoint)
		moved_count += 1
	if _endpoint_matches(end_point, old_endpoint, tolerance):
		end_point = _endpoint_with_preserved_height(end_point, new_endpoint)
		moved_count += 1
	for segment in extra_segments:
		if segment == null:
			continue
		if _endpoint_matches(segment.start_point, old_endpoint, tolerance):
			segment.start_point = _endpoint_with_preserved_height(segment.start_point, new_endpoint)
			moved_count += 1
		if _endpoint_matches(segment.end_point, old_endpoint, tolerance):
			segment.end_point = _endpoint_with_preserved_height(segment.end_point, new_endpoint)
			moved_count += 1
	if moved_count > 0:
		rebuild_wall_mesh()
	return moved_count


func move_segment_endpoint(segment_index: int, endpoint: int, new_endpoint: Vector3) -> bool:
	if endpoint != 0 and endpoint != 1:
		return false
	if segment_index <= 0:
		if endpoint == 0:
			start_point = _endpoint_with_preserved_height(start_point, new_endpoint)
		else:
			end_point = _endpoint_with_preserved_height(end_point, new_endpoint)
		rebuild_wall_mesh()
		return true
	var extra_index := segment_index - 1
	if extra_index < 0 or extra_index >= extra_segments.size():
		return false
	var segment := extra_segments[extra_index]
	if segment == null:
		return false
	if endpoint == 0:
		segment.start_point = _endpoint_with_preserved_height(segment.start_point, new_endpoint)
	else:
		segment.end_point = _endpoint_with_preserved_height(segment.end_point, new_endpoint)
	rebuild_wall_mesh()
	return true


## Frame of a segment expressed in this node's local space. Segment 0 is the
## identity because the node transform is derived from the primary span.
func get_segment_local_frame(index: int) -> Transform3D:
	if index <= 0 or index > extra_segments.size():
		return Transform3D.IDENTITY
	return transform.affine_inverse() * extra_segments[index - 1].get_frame()


func can_place_opening(
	center: Vector2,
	size: Vector2,
	clearance: float = 0.03,
	ignored_node: Node = null,
	segment_index: int = 0
) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var segment := get_segment(segment_index)
	var segment_length := segment.get_length()
	var candidate := Rect2(center - size * 0.5, size)
	if candidate.position.x < clearance:
		return false
	if candidate.end.x > segment_length - clearance:
		return false
	if candidate.position.y < clearance:
		return false
	if candidate.end.y > segment.height - clearance:
		return false

	var frame := get_segment_local_frame(segment_index)
	var opening_plan := MergedWallMeshBuilderScript.span_plan_rect(
		frame, candidate.position.x, candidate.end.x, segment.thickness * 0.5
	)
	for other_index in range(get_segment_count()):
		if other_index == segment_index:
			continue
		var other := get_segment(other_index)
		if candidate.position.y >= other.height - 0.001:
			continue
		var other_frame := get_segment_local_frame(other_index)
		if MergedWallMeshBuilderScript.footprints_overlap(
			opening_plan,
			MergedWallMeshBuilderScript.segment_footprint(other, other_frame)
		):
			return false

	var rects_per_segment := _assigned_opening_rects(ignored_node)
	var rects: Array[Rect2] = rects_per_segment[clampi(segment_index, 0, rects_per_segment.size() - 1)]
	for opening in rects:
		if candidate.grow(clearance).intersects(opening):
			return false
	return true


func rebuild_wall_mesh() -> void:
	m_rebuild_queued = false
	m_is_rebuilding = true
	_sync_transform_from_points()
	_clear_generated_children()

	var segments: Array[WallSegment3DScript] = []
	var frames: Array[Transform3D] = []
	for index in range(get_segment_count()):
		segments.append(get_segment(index))
		frames.append(get_segment_local_frame(index))

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	MergedWallMeshBuilderScript.append_segments(
		segments,
		frames,
		_assigned_opening_rects(),
		vertices,
		normals,
		colors,
		indices,
		collision_faces
	)

	if vertices.is_empty():
		mesh = null
		m_opening_signature = _build_opening_signature()
		m_is_rebuilding = false
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh
	material_override = _build_wall_material(wall_color)

	if generate_collision:
		_add_collision_body(collision_faces)

	m_opening_signature = _build_opening_signature()
	m_is_rebuilding = false


func _request_rebuild() -> void:
	if !m_is_ready:
		return
	if m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_wall_mesh")


func _endpoint_matches(first: Vector3, second: Vector3, tolerance: float) -> bool:
	return first.distance_to(second) <= maxf(tolerance, 0.0)


func _endpoint_with_preserved_height(endpoint: Vector3, target: Vector3) -> Vector3:
	return Vector3(target.x, endpoint.y, target.z)


func _sync_transform_from_points() -> void:
	var direction := get_wall_direction()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() <= 0.000001:
		side = Vector3.BACK
	side = side.normalized()
	var basis := Basis(direction, Vector3.UP, side).orthonormalized()
	transform = Transform3D(basis, start_point)


## One Array[Rect2] per segment, mapping each child opening to the nearest
## segment face. Rects are padded by opening_padding and clamped to the
## segment span, ready for mesh-cut consumption.
func _assigned_opening_rects(ignored_node: Node = null) -> Array:
	var rects_per_segment: Array = []
	for index in range(get_segment_count()):
		var empty: Array[Rect2] = []
		rects_per_segment.append(empty)
	for child in get_children():
		if child == ignored_node:
			continue
		if child.has_meta(GENERATED_META):
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var size := _opening_size_from_child(child)
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		var segment_index := _segment_index_for_child(child, child_3d.position)
		var segment := get_segment(segment_index)
		var frame := get_segment_local_frame(segment_index)
		var local := frame.affine_inverse() * child_3d.position
		var padded := Rect2(
			Vector2(local.x, local.y) - size * 0.5 - Vector2(opening_padding, opening_padding),
			size + Vector2(opening_padding * 2.0, opening_padding * 2.0)
		)
		var segment_length := segment.get_length()
		var x0 := clampf(padded.position.x, 0.0, segment_length)
		var x1 := clampf(padded.end.x, 0.0, segment_length)
		var y0 := clampf(padded.position.y, 0.0, segment.height)
		var y1 := clampf(padded.end.y, 0.0, segment.height)
		if x1 - x0 <= 0.001 or y1 - y0 <= 0.001:
			continue
		var rects: Array[Rect2] = rects_per_segment[segment_index]
		rects.append(Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0)))
	return rects_per_segment


## Public lookup used by tools and tests: which segment does a child opening
## belong to? Prefers a valid pinned SEGMENT_INDEX_META, then the segment
## whose face shell the position sits closest to.
func get_opening_segment_index(child: Node) -> int:
	var child_3d := child as Node3D
	if child_3d == null:
		return 0
	return _segment_index_for_child(child, child_3d.position)


func _segment_index_for_child(child: Node, local_position: Vector3) -> int:
	var pinned := int(child.get_meta(SEGMENT_INDEX_META, -1))
	if pinned >= 0 and pinned < get_segment_count() and _segment_matches_position(local_position, pinned):
		return pinned
	return _best_segment_for_position(local_position)


func _best_segment_for_position(local_position: Vector3) -> int:
	var best_index := 0
	var best_score := INF
	for index in range(get_segment_count()):
		if !_segment_matches_position(local_position, index):
			continue
		var segment := get_segment(index)
		var frame := get_segment_local_frame(index)
		var local := frame.affine_inverse() * local_position
		# Distance to the face shell, not the centerline: an opening sitting
		# on this segment's face scores ~0 here but ~thickness/2 against a
		# crossing segment whose centerline it happens to touch.
		var score := absf(absf(local.z) - segment.thickness * 0.5)
		if score < best_score:
			best_score = score
			best_index = index
	return best_index


func _segment_matches_position(local_position: Vector3, index: int) -> bool:
	var segment := get_segment(index)
	var frame := get_segment_local_frame(index)
	var local := frame.affine_inverse() * local_position
	if local.x < -SEGMENT_ASSIGN_MARGIN or local.x > segment.get_length() + SEGMENT_ASSIGN_MARGIN:
		return false
	if local.y < -SEGMENT_ASSIGN_MARGIN or local.y > segment.height + SEGMENT_ASSIGN_MARGIN:
		return false
	return absf(local.z) <= segment.thickness * 0.5 + SEGMENT_ASSIGN_DEPTH


func _opening_size_from_child(child: Node) -> Vector2:
	if child is BuildingOpening3DScript:
		var typed_opening := child as BuildingOpening3DScript
		return Vector2(typed_opening.opening_width, typed_opening.opening_height)
	if child.has_meta(OPENING_META):
		var width := float(child.get_meta(&"opening_width", 1.0))
		var height := float(child.get_meta(&"opening_height", 1.0))
		return Vector2(maxf(width, 0.0), maxf(height, 0.0))
	return Vector2.ZERO


func _add_collision_body(collision_faces: PackedVector3Array) -> void:
	if collision_faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape

	var body := StaticBody3D.new()
	body.name = "WallCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _build_wall_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()


func _on_child_tree_changed(_child: Node) -> void:
	if m_is_rebuilding:
		return
	if _child != null and _child.has_meta(GENERATED_META):
		return
	_request_rebuild()


func _build_opening_signature() -> String:
	var parts := PackedStringArray()
	for segment in extra_segments:
		if segment == null:
			continue
		parts.append(
			"seg:%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
				segment.start_point.x,
				segment.start_point.y,
				segment.start_point.z,
				segment.end_point.x,
				segment.end_point.y,
				segment.end_point.z,
				segment.thickness,
				segment.height,
			]
		)
	for child in get_children():
		if child.has_meta(GENERATED_META):
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var size := _opening_size_from_child(child)
		if size == Vector2.ZERO:
			continue
		parts.append(
			"%.3f,%.3f,%.3f,%.3f,%.3f" % [
				child_3d.position.x,
				child_3d.position.y,
				child_3d.position.z,
				size.x,
				size.y,
			]
		)
	return "|".join(parts)
