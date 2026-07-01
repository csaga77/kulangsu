@tool
class_name Stairs3D
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

const StandardRailGeometry := preload(
	"res://addons/low_poly_building_editor/standard_rail_geometry_3d.gd"
)

const GENERATED_META := &"stairs_generated"
const PREVIEW_META := &"building_editor_preview"
const MESH_GEOMETRY_VERSION := 2
const SIDE_WALL_COLLISION_THICKNESS := 0.64
const SIDE_WALL_COLLISION_META := &"stairs_side_wall_collision"
const LEFT_SIDE_COLLISION_SHAPE_NAME := "LeftSideCollisionShape3D"
const RIGHT_SIDE_COLLISION_SHAPE_NAME := "RightSideCollisionShape3D"

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_stairs_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(2.0, 0.0, 4.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export_range(0.05, 20.0, 0.01, "or_greater") var stair_height := 1.2:
	set(value):
		var clamped_value := maxf(value, 0.05)
		if is_equal_approx(stair_height, clamped_value):
			return
		stair_height = clamped_value
		_request_rebuild()

@export_range(1, 64, 1) var step_count := 6:
	set(value):
		var clamped_value := clampi(value, 1, 64)
		if step_count == clamped_value:
			return
		step_count = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var stair_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(stair_thickness, clamped_value):
			return
		stair_thickness = clamped_value
		_request_rebuild()

@export_range(-180.0, 180.0, 1.0) var stair_rotation_degrees := 0.0:
	set(value):
		var normalized_value := _normalize_degrees_static(value)
		if is_equal_approx(stair_rotation_degrees, normalized_value):
			return
		stair_rotation_degrees = normalized_value
		_request_rebuild()

@export var stair_color := Color(0.52, 0.46, 0.38, 1.0):
	set(value):
		if stair_color == value:
			return
		stair_color = value
		_request_rebuild()

@export_group("Rails")
@export var left_rail_enabled := false:
	set(value):
		if left_rail_enabled == value:
			return
		left_rail_enabled = value
		_request_rebuild()

@export var right_rail_enabled := false:
	set(value):
		if right_rail_enabled == value:
			return
		right_rail_enabled = value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var rail_edge_margin := 0.15:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(rail_edge_margin, clamped_value):
			return
		rail_edge_margin = clamped_value
		_request_rebuild()

@export_range(0.2, 4.0, 0.01, "or_greater") var rail_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.2)
		if is_equal_approx(rail_height, clamped_value):
			return
		rail_height = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var rail_post_thickness := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(rail_post_thickness, clamped_value):
			return
		rail_post_thickness = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var rail_thickness := 0.1:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(rail_thickness, clamped_value):
			return
		rail_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var rail_lower_height := 0.18:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(rail_lower_height, clamped_value):
			return
		rail_lower_height = clamped_value
		_request_rebuild()

@export var rail_color := Color(0.33, 0.28, 0.22, 1.0):
	set(value):
		if rail_color == value:
			return
		rail_color = value
		_request_rebuild()

@export_group("")
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
		_sync_transform_from_points()
		if _generated_mesh_cache_matches(_stairs_mesh_source_signature()):
			_sync_stairs_material()
			_rebuild_collision_from_cached_mesh()
		else:
			rebuild_stairs_mesh()


func set_stair_corners(new_start: Vector3, new_end: Vector3) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_corners_and_rotation(
	new_start: Vector3,
	new_end: Vector3,
	new_rotation_degrees: float
) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	stair_rotation_degrees = new_rotation_degrees
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_rotation_degrees(new_rotation_degrees: float) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	stair_rotation_degrees = new_rotation_degrees
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_rotation_around_center(new_rotation_degrees: float) -> void:
	var size := get_stair_size()
	var center := get_stair_center_point()
	var normalized_rotation := _normalize_degrees_static(new_rotation_degrees)
	var rotated_anchor := center - _rotation_basis_for_degrees(normalized_rotation) * Vector3(
		size.x * 0.5,
		0.0,
		size.y * 0.5
	)
	set_stair_corners_and_rotation(
		rotated_anchor,
		rotated_anchor + Vector3(size.x, 0.0, size.y),
		normalized_rotation
	)


func get_stair_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func get_stair_anchor_point() -> Vector3:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	return Vector3(min_x, start_point.y, min_z)


func get_stair_center_point() -> Vector3:
	var size := get_stair_size()
	return get_stair_anchor_point() + _rotation_basis() * Vector3(size.x * 0.5, 0.0, size.y * 0.5)


func get_stair_bounds_min() -> Vector3:
	return Vector3(0.0, -maxf(stair_thickness, 0.0), 0.0)


func get_stair_bounds_max() -> Vector3:
	var size := get_stair_size()
	return Vector3(size.x, maxf(stair_height, 0.05), size.y)


func get_step_rise() -> float:
	return maxf(stair_height, 0.05) / float(_effective_step_count())


func get_step_run() -> float:
	return get_stair_size().y / float(_effective_step_count())


static func stair_corners_from_base_points(base_start: Vector3, base_end: Vector3, rotation_degrees: float) -> Dictionary:
	var basis := Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))
	var flat_delta := Vector3(base_end.x - base_start.x, 0.0, base_end.z - base_start.z)
	var local_delta := basis.inverse() * flat_delta
	var min_x := minf(0.0, local_delta.x)
	var max_x := maxf(0.0, local_delta.x)
	var min_z := minf(0.0, local_delta.z)
	var max_z := maxf(0.0, local_delta.z)
	var anchor := base_start + basis * Vector3(min_x, 0.0, min_z)
	var size := Vector2(max_x - min_x, max_z - min_z)
	return {
		"start": Vector3(anchor.x, base_start.y, anchor.z),
		"end": Vector3(anchor.x + size.x, base_start.y, anchor.z + size.y),
	}


func rebuild_stairs_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_stair_geometry(size.x, size.y, vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_stairs_mesh_resource(arrays)
	_sync_stairs_material()
	_record_generated_mesh_cache(_stairs_mesh_source_signature())

	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_stairs_mesh")


func _stairs_mesh_source_signature() -> int:
	return hash([
		MESH_GEOMETRY_VERSION,
		start_point,
		end_point,
		stair_height,
		step_count,
		stair_thickness,
		stair_rotation_degrees,
		stair_color,
		left_rail_enabled,
		right_rail_enabled,
		rail_edge_margin,
		rail_height,
		rail_post_thickness,
		rail_thickness,
		rail_lower_height,
		rail_color,
	])


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body(_cached_mesh_vertices(), _cached_mesh_indices())


func _sync_transform_from_points() -> void:
	transform = Transform3D(_rotation_basis(), get_stair_anchor_point())


func _append_stair_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps := _effective_step_count()
	var height := maxf(stair_height, 0.05)
	var bottom_y := -maxf(stair_thickness, 0.0)
	var tread_depth := depth / float(steps)
	var rise := height / float(steps)

	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y0 := rise * float(step_index)
		var y1 := rise * float(step_index + 1)
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			Vector3(0.0, y1, z0),
			Vector3(0.0, y1, z1),
			Vector3(width, y1, z1),
			Vector3(width, y1, z0),
			Vector3.UP
		)
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			Vector3(0.0, y0, z0),
			Vector3(0.0, y1, z0),
			Vector3(width, y1, z0),
			Vector3(width, y0, z0),
			Vector3.FORWARD
		)

	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		Vector3(0.0, bottom_y, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, bottom_y, 0.0),
		Vector3.FORWARD
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		Vector3(0.0, bottom_y, depth),
		Vector3(width, bottom_y, depth),
		Vector3(width, height, depth),
		Vector3(0.0, height, depth),
		Vector3.BACK
	)
	var side_polygon := _side_profile_polygon(depth, height, bottom_y, steps)
	_append_side_polygon(vertices, normals, colors, indices, side_polygon, 0.0, Vector3.LEFT)
	_append_side_polygon(vertices, normals, colors, indices, side_polygon, width, Vector3.RIGHT)

	_append_rail_geometry(width, depth, height, vertices, normals, colors, indices)


func _append_rail_geometry(
	width: float,
	depth: float,
	height: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if !left_rail_enabled and !right_rail_enabled:
		return
	var steps := _effective_step_count()
	# One post per tread, centered on that tread's depth span, instead of the
	# spacing-based distribution Rail3D uses for a level span. Each post's
	# base height follows the actual flat tread surface it stands on, not
	# the smooth rise/length diagonal, so it rests on top of its step
	# instead of partway inside it, and stays a flat, upright post.
	var post_positions := StandardRailGeometry.tread_mid_post_positions(depth, steps)
	var post_base_heights := StandardRailGeometry.tread_mid_post_base_heights(height, steps)
	# Inset each rail from its side edge instead of straddling the exact
	# footprint boundary, clamped so opposing margins cannot cross.
	var margin := minf(rail_edge_margin, width * 0.45)
	if left_rail_enabled:
		StandardRailGeometry.append_rail(
			vertices,
			normals,
			colors,
			indices,
			Vector3(margin, 0.0, 0.0),
			Vector3.BACK,
			Vector3.UP,
			Vector3.RIGHT,
			depth,
			height,
			rail_height,
			1.0, # post_spacing is unused: post_positions overrides it below.
			rail_post_thickness,
			rail_thickness,
			rail_lower_height,
			rail_color,
			post_positions,
			post_base_heights
		)
	if right_rail_enabled:
		StandardRailGeometry.append_rail(
			vertices,
			normals,
			colors,
			indices,
			Vector3(width - margin, 0.0, 0.0),
			Vector3.BACK,
			Vector3.UP,
			Vector3.RIGHT,
			depth,
			height,
			rail_height,
			1.0, # post_spacing is unused: post_positions overrides it below.
			rail_post_thickness,
			rail_thickness,
			rail_lower_height,
			rail_color,
			post_positions,
			post_base_heights
		)


func _side_profile_polygon(depth: float, height: float, bottom_y: float, steps: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	polygon.append(Vector2(0.0, bottom_y))
	polygon.append(Vector2(0.0, 0.0))
	var tread_depth := depth / float(steps)
	var rise := height / float(steps)
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y1 := rise * float(step_index + 1)
		polygon.append(Vector2(z0, y1))
		polygon.append(Vector2(z1, y1))
	polygon.append(Vector2(depth, bottom_y))
	return polygon


func _append_side_polygon(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	polygon: PackedVector2Array,
	x: float,
	normal: Vector3
) -> void:
	var base := vertices.size()
	for point in polygon:
		vertices.append(Vector3(x, point.y, point.x))
		normals.append(normal)
		colors.append(stair_color)
	var triangles := Geometry2D.triangulate_polygon(polygon)
	for index in range(0, triangles.size(), 3):
		var first := int(triangles[index])
		var second := int(triangles[index + 1])
		var third := int(triangles[index + 2])
		var winding_normal := (
			vertices[base + second] - vertices[base + first]
		).cross(
			vertices[base + third] - vertices[base + first]
		).normalized()
		if winding_normal.dot(normal) > 0.0:
			indices.append_array(PackedInt32Array([base + first, base + third, base + second]))
		else:
			indices.append_array(PackedInt32Array([base + first, base + second, base + third]))


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
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
		colors.append(stair_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _update_stairs_mesh_resource(arrays: Array) -> void:
	_replace_generated_mesh_surface(arrays)


func _sync_stairs_material() -> void:
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_stairs_material(stair_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, stair_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if stair_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_stairs_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_collision_body(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var faces := PackedVector3Array()
	for index in range(0, indices.size(), 3):
		faces.append(vertices[indices[index]])
		faces.append(vertices[indices[index + 1]])
		faces.append(vertices[indices[index + 2]])
	if faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape

	var body := StaticBody3D.new()
	body.name = "StairsCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	_add_side_wall_collision_shapes(body)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null
		for child in body.get_children():
			if child != collision_shape:
				child.owner = null


func _add_side_wall_collision_shapes(body: StaticBody3D) -> void:
	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return
	var bottom_y := -maxf(stair_thickness, 0.0)
	var side_wall_thickness := minf(SIDE_WALL_COLLISION_THICKNESS, size.x * 0.45)
	var steps := _effective_step_count()
	var tread_depth := size.y / float(steps)
	var rise := maxf(stair_height, 0.05) / float(steps)
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var top_y := rise * float(step_index + 1)
		var collision_height := top_y - bottom_y
		var collision_center_y := bottom_y + collision_height * 0.5
		var collision_center_z := (z0 + z1) * 0.5
		var shape_suffix := "" if step_index == 0 else "_%d" % (step_index + 1)
		_add_side_wall_collision_shape(
			body,
			LEFT_SIDE_COLLISION_SHAPE_NAME + shape_suffix,
			Vector3(
				side_wall_thickness * 0.5,
				collision_center_y,
				collision_center_z
			),
			Vector3(side_wall_thickness, collision_height, tread_depth)
		)
		_add_side_wall_collision_shape(
			body,
			RIGHT_SIDE_COLLISION_SHAPE_NAME + shape_suffix,
			Vector3(
				size.x - side_wall_thickness * 0.5,
				collision_center_y,
				collision_center_z
			),
			Vector3(side_wall_thickness, collision_height, tread_depth)
		)


func _add_side_wall_collision_shape(
	body: StaticBody3D,
	shape_name: String,
	shape_position: Vector3,
	shape_size: Vector3
) -> void:
	var side_shape := CollisionShape3D.new()
	side_shape.name = shape_name
	side_shape.set_meta(SIDE_WALL_COLLISION_META, true)
	var box := BoxShape3D.new()
	box.size = shape_size
	side_shape.shape = box
	side_shape.position = shape_position
	body.add_child(side_shape)


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()


func _effective_step_count() -> int:
	return clampi(step_count, 1, 64)


func _rotation_basis() -> Basis:
	return _rotation_basis_for_degrees(stair_rotation_degrees)


static func _rotation_basis_for_degrees(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))


static func _normalize_degrees_static(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized
