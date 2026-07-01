@tool
class_name Rail3D
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

const GENERATED_META := &"rail_generated"
const PREVIEW_META := &"building_editor_preview"

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_rail_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		if !is_equal_approx(end_point.y, value.y):
			end_point = Vector3(end_point.x, value.y, end_point.z)
		_request_rebuild()

@export var end_point := Vector3(4.0, 0.0, 0.0):
	set(value):
		var flattened := Vector3(value.x, start_point.y, value.z)
		if end_point.is_equal_approx(flattened):
			return
		end_point = flattened
		_request_rebuild()

@export_range(0.2, 4.0, 0.01, "or_greater") var rail_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.2)
		if is_equal_approx(rail_height, clamped_value):
			return
		rail_height = clamped_value
		_request_rebuild()

@export_range(0.1, 8.0, 0.01, "or_greater") var post_spacing := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.1)
		if is_equal_approx(post_spacing, clamped_value):
			return
		post_spacing = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var post_thickness := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(post_thickness, clamped_value):
			return
		post_thickness = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var rail_thickness := 0.1:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(rail_thickness, clamped_value):
			return
		rail_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var lower_rail_height := 0.18:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(lower_rail_height, clamped_value):
			return
		lower_rail_height = clamped_value
		_request_rebuild()

@export var rail_color := Color(0.33, 0.28, 0.22, 1.0):
	set(value):
		if rail_color == value:
			return
		rail_color = value
		_request_rebuild()

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
	if !build_on_ready:
		return
	_sync_transform_from_points()
	if _generated_mesh_cache_matches(_rail_mesh_source_signature()):
		_sync_rail_material()
		_rebuild_collision_from_cached_mesh()
	else:
		rebuild_rail_mesh()


func set_rail_points(new_start: Vector3, new_end: Vector3) -> void:
	var previous_signature := _rail_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	if _rail_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_rail_mesh()


func get_rail_length() -> float:
	return Vector2(
		end_point.x - start_point.x,
		end_point.z - start_point.z
	).length()


func get_rail_bounds_min() -> Vector3:
	var half_width := maxf(post_thickness, rail_thickness) * 0.5
	return Vector3(-post_thickness * 0.5, 0.0, -half_width)


func get_rail_bounds_max() -> Vector3:
	var half_width := maxf(post_thickness, rail_thickness) * 0.5
	return Vector3(
		get_rail_length() + post_thickness * 0.5,
		maxf(rail_height, 0.2),
		half_width
	)


func get_post_count() -> int:
	var length := get_rail_length()
	if length <= 0.001:
		return 0
	return maxi(ceili(length / maxf(post_spacing, 0.1)) + 1, 2)


func rebuild_rail_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var length := get_rail_length()
	if length <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_standard_rail_geometry(length, vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_replace_generated_mesh_surface(arrays)
	_sync_rail_material()
	_record_generated_mesh_cache(_rail_mesh_source_signature())

	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_rail_mesh")


func _rail_mesh_source_signature() -> int:
	return hash([
		start_point,
		end_point,
		rail_height,
		post_spacing,
		post_thickness,
		rail_thickness,
		lower_rail_height,
		rail_color,
	])


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body(_cached_mesh_vertices(), _cached_mesh_indices())


func _sync_transform_from_points() -> void:
	var flat_delta := Vector3(
		end_point.x - start_point.x,
		0.0,
		end_point.z - start_point.z
	)
	var direction := Vector3.RIGHT
	if flat_delta.length_squared() > 0.000001:
		direction = flat_delta.normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() <= 0.000001:
		side = Vector3.BACK
	transform = Transform3D(
		Basis(direction, Vector3.UP, side.normalized()).orthonormalized(),
		start_point
	)


func _append_standard_rail_geometry(
	length: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var height := maxf(rail_height, 0.2)
	var post_size := maxf(post_thickness, 0.02)
	var bar_size := minf(maxf(rail_thickness, 0.02), height * 0.5)
	var top_bottom := maxf(height - bar_size, 0.0)
	_append_box(
		vertices,
		normals,
		colors,
		indices,
		Vector3(-post_size * 0.5, top_bottom, -bar_size * 0.5),
		Vector3(length + post_size * 0.5, height, bar_size * 0.5)
	)

	var lower_center := clampf(lower_rail_height, bar_size * 0.5, top_bottom - bar_size * 0.5)
	if (
		lower_rail_height > 0.0001
		and top_bottom > bar_size
		and lower_center + bar_size * 0.5 < top_bottom - 0.001
	):
		_append_box(
			vertices,
			normals,
			colors,
			indices,
			Vector3(-post_size * 0.5, lower_center - bar_size * 0.5, -bar_size * 0.5),
			Vector3(length + post_size * 0.5, lower_center + bar_size * 0.5, bar_size * 0.5)
		)

	var post_top := maxf(top_bottom, post_size)
	var post_count := get_post_count()
	for post_index in range(post_count):
		var ratio := float(post_index) / float(post_count - 1)
		var x := length * ratio
		_append_box(
			vertices,
			normals,
			colors,
			indices,
			Vector3(x - post_size * 0.5, 0.0, -post_size * 0.5),
			Vector3(x + post_size * 0.5, post_top, post_size * 0.5)
		)


func _append_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	minimum: Vector3,
	maximum: Vector3
) -> void:
	_append_quad(
		vertices, normals, colors, indices,
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3.FORWARD
	)
	_append_quad(
		vertices, normals, colors, indices,
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3.BACK
	)
	_append_quad(
		vertices, normals, colors, indices,
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3.LEFT
	)
	_append_quad(
		vertices, normals, colors, indices,
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3.RIGHT
	)
	_append_quad(
		vertices, normals, colors, indices,
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3.UP
	)
	_append_quad(
		vertices, normals, colors, indices,
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3.DOWN
	)


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
		colors.append(rail_color)
	indices.append_array(PackedInt32Array([
		base,
		base + 1,
		base + 2,
		base,
		base + 2,
		base + 3,
	]))


func _sync_rail_material() -> void:
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_rail_material()
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, rail_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
		if rail_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_rail_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(1.0, 1.0, 1.0, rail_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if rail_color.a < 0.99:
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
	body.name = "RailCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _clear_generated_children() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.free()
