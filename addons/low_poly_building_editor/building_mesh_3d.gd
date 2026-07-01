@tool
class_name BuildingMesh3D
extends MeshInstance3D

const BuildingWireframe := preload(
	"res://addons/low_poly_building_editor/building_wireframe_3d.gd"
)

var m_mesh_rebuild_count := 0
var m_debug_wireframe_enabled := false
var m_debug_wireframe_color := Color(0.05, 0.95, 1.0, 1.0)
var m_debug_wireframe_xray := false
@export_storage var m_generated_mesh_source_signature := 0
@export_storage var m_generated_mesh_clip_signature := 0
@export_storage var m_generated_mesh_cache_flags := 0


func get_mesh_rebuild_count() -> int:
	return m_mesh_rebuild_count


func set_debug_wireframe(
	enabled: bool,
	color: Color = Color(0.05, 0.95, 1.0, 1.0),
	xray: bool = false
) -> void:
	var was_enabled := m_debug_wireframe_enabled
	var style_changed := (
		m_debug_wireframe_color != color
		or m_debug_wireframe_xray != xray
	)
	m_debug_wireframe_enabled = enabled
	m_debug_wireframe_color = color
	m_debug_wireframe_xray = xray
	if !enabled:
		if was_enabled or BuildingWireframe.is_active(self):
			BuildingWireframe.clear(self)
	elif !was_enabled or !BuildingWireframe.is_active(self):
		_sync_debug_wireframe()
	elif style_changed:
		BuildingWireframe.update_style(self, color, xray)


func is_debug_wireframe_enabled() -> bool:
	return m_debug_wireframe_enabled


func get_debug_wireframe_color() -> Color:
	return m_debug_wireframe_color


func is_debug_wireframe_xray() -> bool:
	return m_debug_wireframe_xray


func _sync_debug_wireframe() -> void:
	var meshes: Array[MeshInstance3D] = [self]
	BuildingWireframe.sync(
		self,
		meshes,
		m_debug_wireframe_enabled,
		m_debug_wireframe_color,
		m_debug_wireframe_xray
	)


func _begin_generated_mesh_rebuild() -> void:
	m_mesh_rebuild_count += 1
	BuildingWireframe.clear(self)


func _generated_mesh_cache_matches(source_signature: int, clip_signature: int = 0) -> bool:
	return (
		mesh != null
		and m_generated_mesh_source_signature == source_signature
		and m_generated_mesh_clip_signature == clip_signature
	)


func _record_generated_mesh_cache(
	source_signature: int,
	clip_signature: int = 0,
	cache_flags: int = 0
) -> void:
	m_generated_mesh_source_signature = source_signature
	m_generated_mesh_clip_signature = clip_signature
	m_generated_mesh_cache_flags = cache_flags


func _generated_mesh_cache_has_flag(flag: int) -> bool:
	return (m_generated_mesh_cache_flags & flag) != 0


func _cached_mesh_vertices() -> PackedVector3Array:
	if mesh == null or mesh.get_surface_count() <= 0:
		return PackedVector3Array()
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_VERTEX]


func _cached_mesh_indices() -> PackedInt32Array:
	if mesh == null or mesh.get_surface_count() <= 0:
		return PackedInt32Array()
	var arrays := mesh.surface_get_arrays(0)
	return arrays[Mesh.ARRAY_INDEX]


func _cached_mesh_triangle_faces() -> PackedVector3Array:
	var faces := PackedVector3Array()
	var vertices := _cached_mesh_vertices()
	for index in _cached_mesh_indices():
		faces.append(vertices[index])
	return faces


func _replace_generated_mesh_surface(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null or !array_mesh.resource_local_to_scene:
		array_mesh = ArrayMesh.new()
		array_mesh.resource_local_to_scene = true
		mesh = array_mesh
	else:
		array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sync_debug_wireframe()


func _scene_local_material_for_write(
	material: StandardMaterial3D
) -> StandardMaterial3D:
	if material == null or material.resource_local_to_scene:
		return material
	var local_material := material.duplicate() as StandardMaterial3D
	local_material.resource_local_to_scene = true
	material_override = local_material
	return local_material
