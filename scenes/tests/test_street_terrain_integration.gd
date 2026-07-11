extends Node3D

const LowPolyTerrain3DScript = preload("res://terrain/low_poly_terrain_3d.gd")
const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Street3DScript = preload("res://addons/low_poly_building_editor/streets/street_3d.gd")

var m_failures: Array[String] = []
var m_rebuild_count := 0
var m_heightmap_path := OS.get_temp_dir().path_join("kulangsu_street_terrain_integration.png")
var m_terrain: LowPolyTerrain3DScript
var m_street: Street3DScript


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_build_fixture()
	if m_terrain == null or m_street == null:
		_finish()
		return
	_validate_initial_integration()
	_validate_manual_height_survives_rebuild()
	await _validate_street_change_rebuilds_terrain()
	_finish()


func _build_fixture() -> void:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	if image.save_png(m_heightmap_path) != OK:
		m_failures.append("Could not write the street/terrain integration heightmap")
		return
	m_terrain = LowPolyTerrain3DScript.new() as LowPolyTerrain3DScript
	m_terrain.name = "Terrain"
	m_terrain.build_on_ready = false
	m_terrain.print_summary = false
	m_terrain.mask_file = ""
	m_terrain.heightmap_file = m_heightmap_path
	m_terrain.heightmap_expands_land_to_source = true
	m_terrain.sample_stride = 2
	m_terrain.cell_size = 1.0
	m_terrain.water_height = 0.0
	m_terrain.land_height = 2.0
	m_terrain.heightmap_min_offset = 0.0
	m_terrain.heightmap_max_offset = 0.0
	m_terrain.street_source_root_path = NodePath("..")
	m_terrain.street_corridor_feather_cells = 1.0
	m_terrain.terrain_rebuilt.connect(_on_terrain_rebuilt)
	add_child(m_terrain)

	var building := Building3DScript.new() as Building3D
	building.name = "StreetAssembly"
	add_child(building)
	m_street = BuildingFactoryScript.create_street_node(
		building,
		PackedVector3Array([
			Vector3(-6.0, 0.0, 0.0),
			Vector3(0.0, 0.0, 0.0),
			Vector3(6.0, 0.0, 2.0),
		]),
		{
			"road_width": 2.4,
			"kerb_width": 0.18,
			"footpath_width": 0.8,
			"terrain_sample_spacing": 0.5,
			"terrain_clearance": 0.025,
		}
	)
	building.add_child(m_street)
	m_terrain.rebuild_from_source()


func _validate_initial_integration() -> void:
	var summary := m_terrain.get_street_integration_summary()
	if int(summary.get("source_count", 0)) != 1:
		m_failures.append("Terrain generation did not discover exactly one Street3D source")
	if int(summary.get("core_cells", 0)) <= 0:
		m_failures.append("Terrain generation did not shape cells beneath the street corridor")
	if m_street.profile_points.size() <= m_street.path_points.size():
		m_failures.append("Terrain generation did not bake a dense automatic street profile")
	var under_street := m_terrain.get_world_surface_height(Vector3(0.0, 0.0, 0.0))
	var outside_street := m_terrain.get_world_surface_height(Vector3(0.0, 0.0, 7.0))
	if under_street >= 1.95:
		m_failures.append("Terrain bed was not lowered beneath the street slab")
	if absf(outside_street - 2.0) > 0.02:
		m_failures.append("Street integration changed terrain outside its feather corridor")
	if m_street.mesh == null or m_street.get_node_or_null("StreetCollision") == null:
		m_failures.append("Integrated Street3D did not retain its mesh and collision")


func _validate_manual_height_survives_rebuild() -> void:
	if m_street.profile_points.size() < 3:
		return
	var manual_point: StreetProfilePoint = m_street.profile_points[m_street.profile_points.size() / 2]
	manual_point.position.y += 0.08
	manual_point.manual_height = true
	var expected_height: float = manual_point.position.y
	m_terrain.rebuild_from_source()
	var preserved := false
	for point in m_street.profile_points:
		if point.manual_height and absf(point.position.y - expected_height) <= 0.001:
			preserved = true
			break
	if !preserved:
		m_failures.append("Terrain regeneration overwrote a manual StreetProfilePoint height")


func _validate_street_change_rebuilds_terrain() -> void:
	var before := m_rebuild_count
	m_street.road_width += 0.5
	for _frame in range(4):
		await get_tree().process_frame
	if m_rebuild_count <= before:
		m_failures.append("Changing the street corridor did not request terrain regeneration")


func _on_terrain_rebuilt(_summary: Dictionary) -> void:
	m_rebuild_count += 1


func _finish() -> void:
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: Street/terrain generation integration smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)
