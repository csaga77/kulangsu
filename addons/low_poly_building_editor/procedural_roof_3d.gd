@tool
class_name ProceduralRoof3D
extends MeshInstance3D

const GENERATED_META := &"procedural_roof_generated"
const PREVIEW_META := &"building_editor_preview"
const STYLE_FLAT := "flat"
const STYLE_SHED := "shed"
const STYLE_GABLE := "gable"
const STYLE_HIP := "hip"
const VALID_STYLES := [STYLE_FLAT, STYLE_SHED, STYLE_GABLE, STYLE_HIP]

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_roof_mesh")

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

@export_enum("Flat:0", "Shed:1", "Gable:2", "Hip:3") var roof_style_index := 2:
	set(value):
		var clamped_value := clampi(value, 0, VALID_STYLES.size() - 1)
		if roof_style_index == clamped_value:
			return
		roof_style_index = clamped_value
		_request_rebuild()

@export_range(0.0, 8.0, 0.05, "or_greater") var roof_height := 0.8:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(roof_height, clamped_value):
			return
		roof_height = clamped_value
		_request_rebuild()

@export_range(0.02, 2.0, 0.01, "or_greater") var roof_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(roof_thickness, clamped_value):
			return
		roof_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var roof_overhang := 0.2:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(roof_overhang, clamped_value):
			return
		roof_overhang = clamped_value
		_request_rebuild()

@export_range(-180.0, 180.0, 1.0) var roof_rotation_degrees := 0.0:
	set(value):
		var normalized_value := _normalize_degrees(value)
		if is_equal_approx(roof_rotation_degrees, normalized_value):
			return
		roof_rotation_degrees = normalized_value
		_request_rebuild()

@export var roof_color := Color(0.50, 0.34, 0.25, 1.0):
	set(value):
		if roof_color == value:
			return
		roof_color = value
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
		rebuild_roof_mesh()


func set_roof_corners(new_start: Vector3, new_end: Vector3) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_corners_and_rotation(new_start: Vector3, new_end: Vector3, new_rotation_degrees: float) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	roof_rotation_degrees = new_rotation_degrees
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_rotation_degrees(new_rotation_degrees: float) -> void:
	roof_rotation_degrees = new_rotation_degrees
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_rotation_around_center(new_rotation_degrees: float) -> void:
	var size := get_roof_size()
	var center := get_roof_center_point()
	var normalized_rotation := _normalize_degrees(new_rotation_degrees)
	var rotated_anchor := center - _rotation_basis_for_degrees(normalized_rotation) * Vector3(
		size.x * 0.5,
		0.0,
		size.y * 0.5
	)
	set_roof_corners_and_rotation(
		rotated_anchor,
		rotated_anchor + Vector3(size.x, 0.0, size.y),
		normalized_rotation
	)


func set_roof_style(style: String) -> void:
	roof_style_index = _style_index_from_name(style)
	rebuild_roof_mesh()


func get_roof_style() -> String:
	return String(VALID_STYLES[clampi(roof_style_index, 0, VALID_STYLES.size() - 1)])


func get_roof_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func get_roof_anchor_point() -> Vector3:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	return Vector3(min_x, start_point.y, min_z)


func get_roof_center_point() -> Vector3:
	var size := get_roof_size()
	return get_roof_anchor_point() + _rotation_basis() * Vector3(size.x * 0.5, 0.0, size.y * 0.5)


func get_roof_bounds_min() -> Vector3:
	var overhang := maxf(roof_overhang, 0.0)
	return Vector3(-overhang, -roof_thickness, -overhang)


func get_roof_bounds_max() -> Vector3:
	var size := get_roof_size()
	var overhang := maxf(roof_overhang, 0.0)
	return Vector3(size.x + overhang, _effective_roof_height(), size.y + overhang)


func rebuild_roof_mesh(rebuild_collision: bool = true) -> void:
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_roof_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_roof_geometry(size.x, size.y, vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_roof_mesh_resource(arrays)
	_sync_roof_material()

	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_roof_mesh")


func _sync_transform_from_points() -> void:
	transform = Transform3D(_rotation_basis(), get_roof_anchor_point())


func _rotation_basis() -> Basis:
	return _rotation_basis_for_degrees(roof_rotation_degrees)


func _rotation_basis_for_degrees(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees(rotation_degrees)))


func _normalize_degrees(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _append_roof_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var overhang := maxf(roof_overhang, 0.0)
	var x0 := -overhang
	var x1 := width + overhang
	var z0 := -overhang
	var z1 := depth + overhang
	var center_x := (x0 + x1) * 0.5
	var center_z := (z0 + z1) * 0.5
	var height := _effective_roof_height()
	var top_points: Array[Vector3] = []
	var top_triangles: Array[PackedInt32Array] = []
	var boundary := PackedInt32Array()

	match get_roof_style():
		STYLE_SHED:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, height, z1),
				Vector3(x0, height, z1),
			]
			top_triangles = [PackedInt32Array([0, 3, 2]), PackedInt32Array([0, 2, 1])]
			boundary = PackedInt32Array([0, 1, 2, 3])
		STYLE_HIP:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
				Vector3(center_x, height, center_z),
			]
			top_triangles = [
				PackedInt32Array([0, 4, 1]),
				PackedInt32Array([1, 4, 2]),
				PackedInt32Array([2, 4, 3]),
				PackedInt32Array([3, 4, 0]),
			]
			boundary = PackedInt32Array([0, 1, 2, 3])
		STYLE_GABLE:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
				Vector3(x0, height, center_z),
				Vector3(x1, height, center_z),
			]
			top_triangles = [
				PackedInt32Array([0, 4, 5]),
				PackedInt32Array([0, 5, 1]),
				PackedInt32Array([3, 2, 5]),
				PackedInt32Array([3, 5, 4]),
			]
			boundary = PackedInt32Array([0, 1, 5, 2, 3, 4])
		_:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
			]
			top_triangles = [PackedInt32Array([0, 3, 2]), PackedInt32Array([0, 2, 1])]
			boundary = PackedInt32Array([0, 1, 2, 3])

	for triangle in top_triangles:
		_append_triangle_auto(
			vertices,
			normals,
			colors,
			indices,
			top_points[triangle[0]],
			top_points[triangle[1]],
			top_points[triangle[2]]
		)

	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for triangle in top_triangles:
		_append_triangle_auto(
			vertices,
			normals,
			colors,
			indices,
			top_points[triangle[0]] + bottom_offset,
			top_points[triangle[2]] + bottom_offset,
			top_points[triangle[1]] + bottom_offset
		)

	for edge_index in range(boundary.size()):
		var next_edge_index := (edge_index + 1) % boundary.size()
		var edge_start: Vector3 = top_points[boundary[edge_index]]
		var edge_end: Vector3 = top_points[boundary[next_edge_index]]
		_append_quad_auto(
			vertices,
			normals,
			colors,
			indices,
			edge_start,
			edge_end,
			edge_end + bottom_offset,
			edge_start + bottom_offset
		)


func _effective_roof_height() -> float:
	if get_roof_style() == STYLE_FLAT:
		return 0.0
	return maxf(roof_height, 0.0)


func _style_index_from_name(style: String) -> int:
	var normalized := style.strip_edges().to_lower()
	for index in range(VALID_STYLES.size()):
		if String(VALID_STYLES[index]) == normalized:
			return index
	return 2


func _append_triangle_auto(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	_append_triangle(vertices, normals, colors, indices, a, b, c, normal.normalized())


func _append_quad_auto(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	_append_quad(vertices, normals, colors, indices, a, b, c, d, normal.normalized())


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
		colors.append(roof_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	colors.append(roof_color)
	colors.append(roof_color)
	colors.append(roof_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1]))


func _update_roof_mesh_resource(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh
	else:
		array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _sync_roof_material() -> void:
	var material := material_override as StandardMaterial3D
	if material == null:
		material_override = _build_roof_material(roof_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, roof_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if roof_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_roof_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
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
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "RoofCollision"
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
