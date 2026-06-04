@tool
class_name LowPolyLandmarkProxy3D
extends Node3D

const GENERATED_META := &"low_poly_landmark_proxy_generated"
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("_rebuild")

@export var landmark_id := "landmark_proxy"
@export var art_style: LowPolyArtStyle3DScript:
	set(value):
		if art_style == value:
			return
		art_style = value
		_request_rebuild()

@export var building_size := Vector3(2.4, 1.25, 1.6):
	set(value):
		building_size = Vector3(maxf(value.x, 0.1), maxf(value.y, 0.1), maxf(value.z, 0.1))
		_request_rebuild()

@export var roof_height := 0.52:
	set(value):
		roof_height = maxf(value, 0.05)
		_request_rebuild()

@export var pier_size := Vector3(3.0, 0.14, 1.05):
	set(value):
		pier_size = Vector3(maxf(value.x, 0.1), maxf(value.y, 0.05), maxf(value.z, 0.1))
		_request_rebuild()

@export var pier_offset := Vector3(0.0, 0.0, 1.2):
	set(value):
		pier_offset = value
		_request_rebuild()

@export var show_pier := true:
	set(value):
		if show_pier == value:
			return
		show_pier = value
		_request_rebuild()

@export var build_on_ready := true

var m_is_ready := false
var m_rebuild_queued := false


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		_rebuild()


func _request_rebuild() -> void:
	if !m_is_ready:
		return
	if m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	m_rebuild_queued = false
	_clear_generated_children()

	var wall_color := _style_color("landmark_wall_color", Color(0.88, 0.79, 0.62, 1.0))
	var roof_color := _style_color("landmark_roof_color", Color(0.70, 0.28, 0.18, 1.0))
	var trim_color := _style_color("landmark_trim_color", Color(0.96, 0.88, 0.72, 1.0))
	var pier_color := _style_color("landmark_pier_color", Color(0.50, 0.36, 0.24, 1.0))

	_add_box("BuildingBody", building_size, Vector3(0.0, building_size.y * 0.5, 0.0), wall_color)
	_add_roof("PostcardRoof", Vector3(building_size.x * 1.12, roof_height, building_size.z * 1.16), Vector3(0.0, building_size.y, 0.0), roof_color)
	_add_box(
		"DoorTrim",
		Vector3(building_size.x * 0.28, building_size.y * 0.42, 0.06),
		Vector3(0.0, building_size.y * 0.26, -building_size.z * 0.52),
		trim_color
	)
	if show_pier:
		_add_box("Pier", pier_size, pier_offset + Vector3(0.0, pier_size.y * 0.5, 0.0), pier_color)


func _style_color(property_name: StringName, fallback: Color) -> Color:
	if art_style == null:
		return fallback
	var value: Variant = art_style.get(property_name)
	if value is Color:
		return value
	return fallback


func _add_box(part_name: String, size: Vector3, local_position: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = _build_material(color)
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null


func _add_roof(part_name: String, size: Vector3, local_position: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = _build_gable_roof_mesh(size)
	instance.position = local_position
	instance.material_override = _build_material(color)
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null


func _build_gable_roof_mesh(size: Vector3) -> ArrayMesh:
	var half_width := size.x * 0.5
	var half_depth := size.z * 0.5
	var a := Vector3(-half_width, 0.0, -half_depth)
	var b := Vector3(half_width, 0.0, -half_depth)
	var c := Vector3(0.0, size.y, -half_depth)
	var d := Vector3(-half_width, 0.0, half_depth)
	var e := Vector3(half_width, 0.0, half_depth)
	var f := Vector3(0.0, size.y, half_depth)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	_append_triangle(vertices, normals, indices, a, c, b)
	_append_triangle(vertices, normals, indices, d, e, f)
	_append_triangle(vertices, normals, indices, a, d, f)
	_append_triangle(vertices, normals, indices, a, f, c)
	_append_triangle(vertices, normals, indices, b, c, f)
	_append_triangle(vertices, normals, indices, b, f, e)
	_append_triangle(vertices, normals, indices, a, b, e)
	_append_triangle(vertices, normals, indices, a, e, d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var start_index := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	indices.append(start_index)
	indices.append(start_index + 1)
	indices.append(start_index + 2)


func _build_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
