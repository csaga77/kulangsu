@tool
class_name BuildingWireframe3D
extends RefCounted

const NODE_NAME := "BuildingDebugWireframe"
const GENERATED_META := &"building_debug_wireframe"
const EDGE_QUANTIZATION := 10000.0
const LEGACY_NODE_NAMES := [&"RoofTriangleWireframe"]


static func sync(
	root: Node3D,
	mesh_instances: Array[MeshInstance3D],
	enabled: bool,
	color: Color,
	xray: bool
) -> void:
	clear(root)
	if !enabled or root == null:
		return
	var line_vertices := _unique_line_vertices(root, mesh_instances)
	if line_vertices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = line_vertices
	var wire_mesh := ArrayMesh.new()
	wire_mesh.resource_local_to_scene = true
	wire_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = NODE_NAME
	instance.mesh = wire_mesh
	instance.material_override = _build_material(color, xray)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta(GENERATED_META, true)
	root.add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null


static func sync_recursive(
	root: Node3D,
	enabled: bool,
	color: Color,
	xray: bool
) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, meshes)
	sync(root, meshes, enabled, color, xray)


static func update_style(root: Node3D, color: Color, xray: bool) -> bool:
	if root == null:
		return false
	var instance := root.get_node_or_null(NODE_NAME) as MeshInstance3D
	if instance == null:
		return false
	instance.material_override = _build_material(color, xray)
	return true


static func clear(root: Node3D) -> void:
	if root == null:
		return
	for child in root.get_children():
		if (
			!child.has_meta(GENERATED_META)
			and StringName(child.name) not in LEGACY_NODE_NAMES
		):
			continue
		root.remove_child(child)
		child.free()


static func unique_edge_count(
	root: Node3D,
	mesh_instances: Array[MeshInstance3D]
) -> int:
	return _unique_edges(root, mesh_instances).size()


static func _collect_mesh_instances(
	node: Node,
	meshes: Array[MeshInstance3D]
) -> void:
	if node.has_meta(GENERATED_META):
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, meshes)


static func _unique_line_vertices(
	root: Node3D,
	mesh_instances: Array[MeshInstance3D]
) -> PackedVector3Array:
	var edges := _unique_edges(root, mesh_instances)
	var line_vertices := PackedVector3Array()
	for edge in edges.values():
		line_vertices.append(Vector3(edge["start"]))
		line_vertices.append(Vector3(edge["end"]))
	return line_vertices


static func _unique_edges(
	root: Node3D,
	mesh_instances: Array[MeshInstance3D]
) -> Dictionary:
	var edges := {}
	if root == null:
		return edges
	var root_inverse := root.global_transform.affine_inverse()
	for instance in mesh_instances:
		if (
			instance == null
			or !is_instance_valid(instance)
			or instance.has_meta(GENERATED_META)
			or instance.mesh == null
		):
			continue
		var local_transform := (
			Transform3D.IDENTITY
			if instance == root
			else root_inverse * instance.global_transform
		)
		var faces := instance.mesh.get_faces()
		for triangle_start in range(0, faces.size() - 2, 3):
			var a := local_transform * faces[triangle_start]
			var b := local_transform * faces[triangle_start + 1]
			var c := local_transform * faces[triangle_start + 2]
			_add_unique_edge(edges, a, b)
			_add_unique_edge(edges, b, c)
			_add_unique_edge(edges, c, a)
	return edges


static func _add_unique_edge(
	edges: Dictionary,
	start: Vector3,
	end: Vector3
) -> void:
	if start.distance_squared_to(end) <= 0.00000001:
		return
	var start_key := _point_key(start)
	var end_key := _point_key(end)
	var edge_key := (
		"%s|%s" % [start_key, end_key]
		if start_key < end_key
		else "%s|%s" % [end_key, start_key]
	)
	if edges.has(edge_key):
		return
	edges[edge_key] = {"start": start, "end": end}


static func _point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [
		roundi(point.x * EDGE_QUANTIZATION),
		roundi(point.y * EDGE_QUANTIZATION),
		roundi(point.z * EDGE_QUANTIZATION),
	]


static func _build_material(color: Color, xray: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.set("no_depth_test", xray)
	material.render_priority = 1
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
