extends Node3D

const LowPolyTerrain3DScript = preload("res://terrain/low_poly_terrain_3d.gd")

var m_failures: Array[String] = []
var m_mask_path := OS.get_temp_dir().path_join("kulangsu_street_mask_generation.png")
var m_heightmap_path := OS.get_temp_dir().path_join("kulangsu_street_mask_heightmap.png")


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var terrain := _build_fixture()
	if terrain != null:
		_validate_generated_streets(terrain)
		terrain.rebuild_from_source()
		_validate_rebuild_replaces_streets(terrain)
	_finish()


func _build_fixture() -> LowPolyTerrain3DScript:
	var mask := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	for x in range(4, 25):
		mask.set_pixel(x, 8, Color.BLUE)
	for y in range(8, 25):
		mask.set_pixel(24, y, Color.BLUE)
	if mask.save_png(m_mask_path) != OK:
		m_failures.append("Could not write the generated-street mask fixture")
		return null

	var heightmap := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in range(32):
		var value := float(y) / 31.0
		for x in range(32):
			heightmap.set_pixel(x, y, Color(value, value, value, 1.0))
	if heightmap.save_png(m_heightmap_path) != OK:
		m_failures.append("Could not write the generated-street heightmap fixture")
		return null

	var terrain := LowPolyTerrain3DScript.new() as LowPolyTerrain3DScript
	terrain.name = "Terrain"
	terrain.build_on_ready = false
	terrain.print_summary = false
	terrain.mask_file = m_mask_path
	terrain.heightmap_file = m_heightmap_path
	terrain.heightmap_expands_land_to_source = true
	terrain.sample_stride = 2
	terrain.cell_size = 1.0
	terrain.land_height = 1.0
	terrain.heightmap_min_offset = 0.0
	terrain.heightmap_max_offset = 2.0
	terrain.generate_collision = false
	terrain.generate_streets_from_mask = true
	terrain.generated_street_minimum_path_cells = 2
	add_child(terrain)
	terrain.rebuild_from_source()
	return terrain


func _validate_generated_streets(terrain: LowPolyTerrain3DScript) -> void:
	var summary := terrain.get_street_integration_summary()
	if int(summary.get("mask_street_cell_count", 0)) <= 0:
		m_failures.append("Terrain generation did not retain STREET cells from the mask")
	if int(summary.get("mask_path_count", 0)) <= 0:
		m_failures.append("Terrain generation did not extract centerline paths from STREET cells")
	if int(summary.get("generated_source_count", 0)) <= 0:
		m_failures.append("Terrain generation did not instantiate Street3D from extracted paths")
	if int(summary.get("core_cells", 0)) <= 0:
		m_failures.append("Generated mask streets did not shape their terrain corridors")
	var root := terrain.get_node_or_null("GeneratedStreets")
	if root == null or root.get_child_count() <= 0:
		m_failures.append("Terrain is missing its GeneratedStreets assembly")
		return
	var has_mesh := false
	var has_bend := false
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			has_mesh = true
		var path: PackedVector3Array = child.get("path_points")
		if path.size() >= 3:
			has_bend = true
	if !has_mesh:
		m_failures.append("Generated Street3D assemblies have no visible mesh")
	if !has_bend:
		m_failures.append("The bent STREET mask did not produce a multipoint street path")


func _validate_rebuild_replaces_streets(terrain: LowPolyTerrain3DScript) -> void:
	var root := terrain.get_node_or_null("GeneratedStreets")
	if root == null:
		m_failures.append("Terrain rebuild removed GeneratedStreets without replacing it")
		return
	if root.get_child_count() != int(terrain.get_street_integration_summary().get("generated_source_count", -1)):
		m_failures.append("Terrain rebuild left stale generated street nodes")


func _finish() -> void:
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: terrain STREET mask generation smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)
