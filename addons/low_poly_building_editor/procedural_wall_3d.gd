@tool
class_name ProceduralWall3D
extends MeshInstance3D

const GENERATED_META := &"procedural_wall_generated"
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/building_opening_3d.gd")

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


func can_place_opening(center: Vector2, size: Vector2, clearance: float = 0.03, ignored_node: Node = null) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var wall_length := get_wall_length()
	var candidate := Rect2(center - size * 0.5, size)
	if candidate.position.x < clearance:
		return false
	if candidate.end.x > wall_length - clearance:
		return false
	if candidate.position.y < clearance:
		return false
	if candidate.end.y > wall_height - clearance:
		return false

	for opening in _collect_openings(ignored_node):
		if candidate.grow(clearance).intersects(opening):
			return false
	return true


func rebuild_wall_mesh() -> void:
	m_rebuild_queued = false
	m_is_rebuilding = true
	_sync_transform_from_points()
	_clear_generated_children()

	var wall_length := get_wall_length()
	if wall_length <= 0.001:
		mesh = null
		m_opening_signature = _build_opening_signature()
		m_is_rebuilding = false
		return

	var openings := _collect_openings()
	var x_cuts: Array[float] = [0.0, wall_length]
	var y_cuts: Array[float] = [0.0, wall_height]
	for opening in openings:
		x_cuts.append(clampf(opening.position.x, 0.0, wall_length))
		x_cuts.append(clampf(opening.end.x, 0.0, wall_length))
		y_cuts.append(clampf(opening.position.y, 0.0, wall_height))
		y_cuts.append(clampf(opening.end.y, 0.0, wall_height))
	x_cuts = _sorted_unique_floats(x_cuts)
	y_cuts = _sorted_unique_floats(y_cuts)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	var half_thickness := wall_thickness * 0.5

	for x_index in range(x_cuts.size() - 1):
		var x0 := x_cuts[x_index]
		var x1 := x_cuts[x_index + 1]
		if x1 - x0 <= 0.001:
			continue
		for y_index in range(y_cuts.size() - 1):
			var y0 := y_cuts[y_index]
			var y1 := y_cuts[y_index + 1]
			if y1 - y0 <= 0.001:
				continue
			var center := Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
			if _point_inside_opening(center, openings):
				continue
			_append_box(
				vertices,
				normals,
				colors,
				indices,
				collision_faces,
				Vector3(x0, y0, -half_thickness),
				Vector3(x1, y1, half_thickness),
				wall_color
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


func _sync_transform_from_points() -> void:
	var direction := get_wall_direction()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() <= 0.000001:
		side = Vector3.BACK
	side = side.normalized()
	var basis := Basis(direction, Vector3.UP, side).orthonormalized()
	transform = Transform3D(basis, start_point)


func _collect_openings(ignored_node: Node = null) -> Array[Rect2]:
	var openings: Array[Rect2] = []
	var wall_length := get_wall_length()
	for child in get_children():
		if child == ignored_node:
			continue
		if child.has_meta(GENERATED_META):
			continue
		var rect := _opening_rect_from_child(child)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var padded_rect := Rect2(
			rect.position - Vector2(opening_padding, opening_padding),
			rect.size + Vector2(opening_padding * 2.0, opening_padding * 2.0)
		)
		var x0 := clampf(padded_rect.position.x, 0.0, wall_length)
		var x1 := clampf(padded_rect.end.x, 0.0, wall_length)
		var y0 := clampf(padded_rect.position.y, 0.0, wall_height)
		var y1 := clampf(padded_rect.end.y, 0.0, wall_height)
		if x1 - x0 <= 0.001 or y1 - y0 <= 0.001:
			continue
		openings.append(Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0)))
	openings.sort_custom(_sort_rects_by_x)
	return openings


func _opening_rect_from_child(child: Node) -> Rect2:
	if child is BuildingOpening3DScript:
		var typed_opening := child as BuildingOpening3DScript
		return typed_opening.get_opening_rect()
	if child.has_meta(&"building_editor_opening"):
		var child_3d := child as Node3D
		if child_3d == null:
			return Rect2()
		var width := float(child.get_meta(&"opening_width", 1.0))
		var height := float(child.get_meta(&"opening_height", 1.0))
		var size := Vector2(maxf(width, 0.0), maxf(height, 0.0))
		var center := Vector2(child_3d.position.x, child_3d.position.y)
		return Rect2(center - size * 0.5, size)
	return Rect2()


func _sort_rects_by_x(a: Rect2, b: Rect2) -> bool:
	if is_equal_approx(a.position.x, b.position.x):
		return a.position.y < b.position.y
	return a.position.x < b.position.x


func _sorted_unique_floats(values: Array[float]) -> Array[float]:
	values.sort()
	var result: Array[float] = []
	for value in values:
		if result.is_empty() or absf(result[result.size() - 1] - value) > 0.001:
			result.append(value)
	return result


func _point_inside_opening(point: Vector2, openings: Array[Rect2]) -> bool:
	for opening in openings:
		if opening.has_point(point):
			return true
	return false


func _append_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	min_corner: Vector3,
	max_corner: Vector3,
	color: Color
) -> void:
	var p000 := Vector3(min_corner.x, min_corner.y, min_corner.z)
	var p001 := Vector3(min_corner.x, min_corner.y, max_corner.z)
	var p010 := Vector3(min_corner.x, max_corner.y, min_corner.z)
	var p011 := Vector3(min_corner.x, max_corner.y, max_corner.z)
	var p100 := Vector3(max_corner.x, min_corner.y, min_corner.z)
	var p101 := Vector3(max_corner.x, min_corner.y, max_corner.z)
	var p110 := Vector3(max_corner.x, max_corner.y, min_corner.z)
	var p111 := Vector3(max_corner.x, max_corner.y, max_corner.z)

	_append_quad(vertices, normals, colors, indices, collision_faces, p001, p101, p111, p011, color)
	_append_quad(vertices, normals, colors, indices, collision_faces, p100, p000, p010, p110, color)
	_append_quad(vertices, normals, colors, indices, collision_faces, p000, p001, p011, p010, color)
	_append_quad(vertices, normals, colors, indices, collision_faces, p101, p100, p110, p111, color)
	_append_quad(vertices, normals, colors, indices, collision_faces, p011, p111, p110, p010, color)
	_append_quad(vertices, normals, colors, indices, collision_faces, p000, p100, p101, p001, color)


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	collision_faces: PackedVector3Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color
) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var start_index := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(d)
	for index in range(4):
		normals.append(normal)
		colors.append(color)
	indices.append(start_index)
	indices.append(start_index + 2)
	indices.append(start_index + 1)
	indices.append(start_index)
	indices.append(start_index + 3)
	indices.append(start_index + 2)

	collision_faces.append(a)
	collision_faces.append(c)
	collision_faces.append(b)
	collision_faces.append(a)
	collision_faces.append(d)
	collision_faces.append(c)


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
	for child in get_children():
		if child.has_meta(GENERATED_META):
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var rect := _opening_rect_from_child(child)
		if rect.size == Vector2.ZERO:
			continue
		parts.append(
			"%.3f,%.3f,%.3f,%.3f,%.3f" % [
				rect.position.x,
				rect.position.y,
				rect.size.x,
				rect.size.y,
				child_3d.position.z,
			]
		)
	return "|".join(parts)
