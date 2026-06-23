@tool
class_name Floor3D
extends MeshInstance3D

const GENERATED_META := &"floor_generated"
const PREVIEW_META := &"building_editor_preview"

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_floor_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(4.0, 0.0, 4.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export_range(0.01, 2.0, 0.01, "or_greater") var floor_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.01)
		if is_equal_approx(floor_thickness, clamped_value):
			return
		floor_thickness = clamped_value
		_request_rebuild()

@export var floor_color := Color(0.46, 0.40, 0.32, 1.0):
	set(value):
		if floor_color == value:
			return
		floor_color = value
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
	if build_on_ready:
		rebuild_floor_mesh()


func set_floor_corners(new_start: Vector3, new_end: Vector3) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	_sync_transform_from_points()
	rebuild_floor_mesh()


func get_floor_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func rebuild_floor_mesh(rebuild_collision: bool = true) -> void:
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_floor_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_floor_box(size.x, size.y, vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_floor_mesh_resource(arrays)
	_sync_floor_material()

	if rebuild_collision and generate_collision:
		_add_collision_body(size.x, size.y)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_floor_mesh")


func _sync_transform_from_points() -> void:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	transform = Transform3D(Basis.IDENTITY, Vector3(min_x, start_point.y, min_z))


func _append_floor_box(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var top_min_min := Vector3.ZERO
	var top_max_min := Vector3(width, 0.0, 0.0)
	var top_max_max := Vector3(width, 0.0, depth)
	var top_min_max := Vector3(0.0, 0.0, depth)
	var bottom_min_min := Vector3(0.0, -floor_thickness, 0.0)
	var bottom_max_min := Vector3(width, -floor_thickness, 0.0)
	var bottom_max_max := Vector3(width, -floor_thickness, depth)
	var bottom_min_max := Vector3(0.0, -floor_thickness, depth)

	_append_quad(vertices, normals, colors, indices, top_min_min, top_min_max, top_max_max, top_max_min, Vector3.UP)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		bottom_min_min,
		bottom_max_min,
		bottom_max_max,
		bottom_min_max,
		Vector3.DOWN
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		top_min_min,
		bottom_min_min,
		bottom_min_max,
		top_min_max,
		Vector3.LEFT
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		top_max_min,
		top_max_max,
		bottom_max_max,
		bottom_max_min,
		Vector3.RIGHT
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		top_min_min,
		top_max_min,
		bottom_max_min,
		bottom_min_min,
		Vector3.FORWARD
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		top_min_max,
		bottom_min_max,
		bottom_max_max,
		top_max_max,
		Vector3.BACK
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
		colors.append(floor_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _update_floor_mesh_resource(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh
	else:
		array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _sync_floor_material() -> void:
	var material := material_override as StandardMaterial3D
	if material == null:
		material_override = _build_floor_material(floor_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, floor_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if floor_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_floor_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_collision_body(width: float, depth: float) -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, floor_thickness, depth)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.position = Vector3(width * 0.5, -floor_thickness * 0.5, depth * 0.5)

	var body := StaticBody3D.new()
	body.name = "FloorCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
