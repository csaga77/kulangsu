extends Node3D

const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const Street3DScript = preload(
	"res://addons/low_poly_building_editor/streets/street_3d.gd"
)
const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)
const BuildingWireframeScript = preload(
	"res://addons/low_poly_building_editor/building_wireframe.gd"
)

var m_failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_validate_multi_point_ramp()
	_validate_strict_stair_threshold()
	_validate_descending_stairs()
	_validate_impossible_stairs()
	_validate_terrain_profile_and_manual_override()
	_validate_sibling_intersection_merging()
	_validate_street_json_generation()
	_validate_wireframe_and_native_transform()
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: Street3D smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_multi_point_ramp() -> void:
	var street := BuildingFactoryScript.create_street_node(
		self,
		PackedVector3Array([
			Vector3.ZERO,
			Vector3(6.0, 1.0, 0.0),
			Vector3(6.0, 2.0, 6.0),
		])
	)
	add_child(street)
	if street.mesh == null:
		m_failures.append("Multi-point street did not generate a mesh")
	elif street.get_last_build_stats().get("stair_segment_count", -1) != 0:
		m_failures.append("Gentle multi-point street unexpectedly generated footpath stairs")
	if street.get_node_or_null("StreetCollision") == null:
		m_failures.append("Street did not generate collision")
	street.queue_free()


func _validate_strict_stair_threshold() -> void:
	var run := 4.0
	var exact_rise := tan(deg_to_rad(25.0)) * run
	var exact: Street3DScript = _make_street(Vector3(run, exact_rise, 0.0))
	if exact.get_last_build_stats().get("stair_segment_count", -1) != 0:
		m_failures.append("A street at exactly 25 degrees generated stairs")
	exact.queue_free()
	var steep: Street3DScript = _make_street(Vector3(run, 2.0, 0.0))
	var stats: Dictionary = steep.get_last_build_stats()
	if int(stats.get("stair_segment_count", 0)) != 1:
		m_failures.append("A street above 25 degrees did not generate footpath stairs")
	if int(stats.get("step_count", 0)) <= 0:
		m_failures.append("Steep street reported no generated steps")
	steep.queue_free()


func _validate_descending_stairs() -> void:
	var street := BuildingFactoryScript.create_street_node(
		self,
		PackedVector3Array([
			Vector3(0.0, 2.0, 0.0),
			Vector3(4.0, 0.0, 0.0),
		])
	)
	add_child(street)
	if int(street.get_last_build_stats().get("step_count", 0)) <= 0:
		m_failures.append("Descending street did not generate stairs")
	if street.mesh == null:
		m_failures.append("Descending street did not generate a mesh")
	street.queue_free()


func _validate_impossible_stairs() -> void:
	var street: Street3DScript = _make_street(Vector3(1.0, 4.0, 0.0))
	if street.get_validation_errors().is_empty():
		m_failures.append("Dimensionally impossible stairs were not rejected")
	if street.mesh != null:
		m_failures.append("Invalid steep street retained generated geometry")
	street.queue_free()


func _validate_terrain_profile_and_manual_override() -> void:
	var street := BuildingFactoryScript.create_street_node(
		self,
		PackedVector3Array([
			Vector3.ZERO,
			Vector3(4.0, 0.0, 0.0),
			Vector3(4.0, 0.0, 4.0),
		]),
		{"terrain_sample_spacing": 1.0}
	)
	add_child(street)
	var errors: Array[String] = street.resample_terrain(self)
	if !errors.is_empty():
		m_failures.append("Terrain profile sampling failed: %s" % [errors])
		street.queue_free()
		return
	if street.profile_points.size() < 9:
		m_failures.append("Terrain sampling did not densify the bent street path")
		street.queue_free()
		return
	var edited_point = street.profile_points[2]
	edited_point.position.y = 0.6
	edited_point.manual_height = true
	errors = street.resample_terrain(self)
	if !errors.is_empty() or absf(street.profile_points[2].position.y - 0.6) > 0.001:
		m_failures.append(
			"Terrain resampling did not preserve a manual height override (y=%.3f, manual=%s, errors=%s)"
			% [street.profile_points[2].position.y, street.profile_points[2].manual_height, errors]
		)
	street.queue_free()


func _validate_sibling_intersection_merging() -> void:
	var coordinator := Building3DScript.new() as Building3DScript
	add_child(coordinator)
	var through_street := BuildingFactoryScript.create_street_node(
		coordinator,
		PackedVector3Array([Vector3(-6.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0)])
	)
	var branch_street := BuildingFactoryScript.create_street_node(
		coordinator,
		PackedVector3Array([Vector3(0.0, 0.0, -6.0), Vector3.ZERO])
	)
	coordinator.add_child(through_street)
	coordinator.add_child(branch_street)
	coordinator.refresh_street_intersection_cuts()
	var through_stats: Dictionary = through_street.get_last_build_stats()
	var branch_stats: Dictionary = branch_street.get_last_build_stats()
	if int(through_stats.get("intersection_cut_count", 0)) != 1:
		m_failures.append("Through street did not clip its kerbs and footpaths at a T-junction")
	if int(through_stats.get("road_surface_cut_count", 0)) != 0:
		m_failures.append("Through street lost road-surface ownership at a T-junction")
	if int(branch_stats.get("intersection_cut_count", 0)) != 1:
		m_failures.append("Branch street did not clip its kerbs and footpaths at a T-junction")
	if int(branch_stats.get("road_surface_cut_count", 0)) != 1:
		m_failures.append("Branch street retained buried road geometry inside a T-junction")
	var through_arrays: Array = through_street.mesh.surface_get_arrays(0)
	var through_vertices: PackedVector3Array = through_arrays[Mesh.ARRAY_VERTEX]
	var through_colors: PackedColorArray = through_arrays[Mesh.ARRAY_COLOR]
	var found_kerb_cut_boundary := false
	for vertex_index in range(through_vertices.size()):
		if !_colors_near(through_colors[vertex_index], through_street.kerb_color):
			continue
		if absf(through_vertices[vertex_index].x - 4.4) <= 0.001:
			found_kerb_cut_boundary = true
			break
	if !found_kerb_cut_boundary:
		m_failures.append("T-junction mesh did not terminate its kerb at the branch road edge")
	var branch_arrays: Array = branch_street.mesh.surface_get_arrays(0)
	var branch_vertices: PackedVector3Array = branch_arrays[Mesh.ARRAY_VERTEX]
	var branch_colors: PackedColorArray = branch_arrays[Mesh.ARRAY_COLOR]
	var branch_road_max_z := -INF
	for vertex_index in range(branch_vertices.size()):
		if _colors_near(branch_colors[vertex_index], branch_street.road_color):
			branch_road_max_z = maxf(branch_road_max_z, branch_vertices[vertex_index].z)
	if absf(branch_road_max_z - 4.4) > 0.001:
		m_failures.append("Branch road surface did not stop flush at the through-road edge")
	coordinator.remove_child(branch_street)
	branch_street.free()
	coordinator.refresh_street_intersection_cuts()
	if !through_street.get_intersection_cuts().is_empty():
		m_failures.append("Removing a branch street left stale intersection geometry")

	var separated_street := BuildingFactoryScript.create_street_node(
		coordinator,
		PackedVector3Array([Vector3(-6.0, 1.0, 0.0), Vector3(6.0, 1.0, 0.0)])
	)
	coordinator.add_child(separated_street)
	coordinator.refresh_street_intersection_cuts()
	if !separated_street.get_intersection_cuts().is_empty():
		m_failures.append("Vertically separated streets were merged as a plan intersection")
	coordinator.queue_free()


func _colors_near(first: Color, second: Color, tolerance := 0.01) -> bool:
	return (
		absf(first.r - second.r) <= tolerance
		and absf(first.g - second.g) <= tolerance
		and absf(first.b - second.b) <= tolerance
		and absf(first.a - second.a) <= tolerance
	)


func _make_street(end_point: Vector3) -> Street3DScript:
	var street := BuildingFactoryScript.create_street_node(
		self,
		PackedVector3Array([Vector3.ZERO, end_point])
	)
	add_child(street)
	return street


func get_world_surface_height(world_position: Vector3) -> float:
	return world_position.x * 0.1 + world_position.z * 0.2


func _validate_street_json_generation() -> void:
	var load_result := BuildingSpecCompilerScript.load_json_spec(
		"res://addons/low_poly_building_editor/examples/seeded_street.json"
	)
	var load_errors: Array = load_result.get("errors", [])
	if !load_errors.is_empty():
		m_failures.append("Street JSON failed to load: %s" % [load_errors])
		return
	var compile_result := BuildingSpecCompilerScript.compile(load_result.get("spec"))
	var errors: Array = compile_result.get("errors", [])
	var building = compile_result.get("building")
	if !errors.is_empty() or building == null:
		m_failures.append("Street JSON failed to compile: %s" % [errors])
		return
	var resolved: Dictionary = compile_result.get("resolved", {})
	if String(resolved.get("type", "")) != "street":
		m_failures.append("Street generator report omitted the street type")
	if int(resolved.get("stair_segment_count", 0)) != 1:
		m_failures.append("Street generator did not resolve the expected stair segment")
	if building.get_child_count() != 1 or !(building.get_child(0) is Street3DScript):
		m_failures.append("Street generator did not author exactly one Street3D block")
	building.free()


func _validate_wireframe_and_native_transform() -> void:
	var street: Street3DScript = _make_street(Vector3(4.0, 1.0, 0.0))
	var rebuild_count := street.get_mesh_rebuild_count()
	street.set_debug_wireframe(true)
	if !BuildingWireframeScript.is_active(street):
		m_failures.append("Street did not participate in shared debug wireframe display")
	if street.get_mesh_rebuild_count() != rebuild_count:
		m_failures.append("Street wireframe display rebuilt authored geometry")
	street.set_debug_wireframe(false)
	street.transform.origin += Vector3(1.0, 0.0, 2.0)
	street.apply_native_transform(0.5)
	if street.path_points[0].distance_to(Vector3(1.0, 0.0, 2.0)) > 0.001:
		m_failures.append("Street native translation did not bake into its path")
	if street.transform.basis.get_scale().distance_to(Vector3.ONE) > 0.001:
		m_failures.append("Street native transform did not restore unit node scale")
	street.queue_free()
