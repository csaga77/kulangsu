extends Node3D

const LowPolyTerrain3DScript = preload("res://terrain/low_poly_terrain_3d.gd")

var m_failures: Array[String] = []
var m_mask_path := OS.get_temp_dir().path_join("kulangsu_street_mask_generation.png")
var m_heightmap_path := OS.get_temp_dir().path_join("kulangsu_street_mask_heightmap.png")
var m_diagonal_mask_path := OS.get_temp_dir().path_join("kulangsu_street_mask_diagonal.png")


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var terrain := _build_fixture()
	if terrain != null:
		_validate_generated_streets(terrain)
		terrain.rebuild_from_source()
		_validate_rebuild_replaces_streets(terrain)
		_validate_reuse_preserves_streets(terrain)
		_validate_geometry_not_stored(terrain)
	_validate_diagonal_stays_straight()
	_finish()


func _build_fixture() -> LowPolyTerrain3DScript:
	var mask := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	for x in range(4, 25):
		mask.set_pixel(x, 8, Color.BLUE)
	for y in range(8, 25):
		mask.set_pixel(24, y, Color.BLUE)
	for y in range(2, 15):
		mask.set_pixel(16, y, Color.BLUE)
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
	var has_intersection_cut := false
	for child in root.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			has_mesh = true
		var path: PackedVector3Array = child.get("path_points")
		if path.size() >= 3:
			has_bend = true
		if child.has_method("get_intersection_cuts") and !child.call("get_intersection_cuts").is_empty():
			has_intersection_cut = true
	if !has_mesh:
		m_failures.append("Generated Street3D assemblies have no visible mesh")
	if !has_bend:
		m_failures.append("The bent STREET mask did not produce a multipoint street path")
	if !has_intersection_cut:
		m_failures.append("Generated STREET junction paths did not merge their sibling geometry")


func _validate_rebuild_replaces_streets(terrain: LowPolyTerrain3DScript) -> void:
	var root := terrain.get_node_or_null("GeneratedStreets")
	if root == null:
		m_failures.append("Terrain rebuild removed GeneratedStreets without replacing it")
		return
	if root.get_child_count() != int(terrain.get_street_integration_summary().get("generated_source_count", -1)):
		m_failures.append("Terrain rebuild left stale generated street nodes")


func _validate_reuse_preserves_streets(terrain: LowPolyTerrain3DScript) -> void:
	# A reuse rebuild (the scene-load path) must keep the exact street nodes stored
	# in the scene instead of regenerating them, while still shaping the terrain bed
	# beneath their baked corridors.
	var root := terrain.get_node_or_null("GeneratedStreets")
	if root == null or root.get_child_count() <= 0:
		m_failures.append("No generated streets to exercise the reuse path")
		return
	var before_ids: Array[int] = []
	for child in root.get_children():
		before_ids.append(child.get_instance_id())

	terrain.rebuild_reusing_generated_streets()

	var reused_root := terrain.get_node_or_null("GeneratedStreets")
	if reused_root != root:
		m_failures.append("Reuse rebuild replaced the generated-street root instead of keeping it")
		return
	var after_ids: Array[int] = []
	for child in reused_root.get_children():
		after_ids.append(child.get_instance_id())
	if after_ids != before_ids:
		m_failures.append("Reuse rebuild regenerated street nodes instead of reusing the stored ones")
	var summary := terrain.get_street_integration_summary()
	if !bool(summary.get("streets_reused", false)):
		m_failures.append("Reuse rebuild did not report streets_reused")
	if int(summary.get("core_cells", 0)) <= 0:
		m_failures.append("Reused streets did not shape their terrain corridors")


func _validate_geometry_not_stored(terrain: LowPolyTerrain3DScript) -> void:
	# The scene stores only the street definition (centerline points, sampled
	# height profile, authored properties); the mesh geometry is dropped on save
	# and rebuilt from that definition on load. Verify the definition is present
	# and that the mesh reconstructs from it once the geometry is cleared.
	var root := terrain.get_node_or_null("GeneratedStreets")
	if root == null or root.get_child_count() <= 0:
		m_failures.append("No generated streets to check geometry persistence")
		return
	var street := root.get_child(0)
	var path: PackedVector3Array = street.get("path_points")
	var profile: Array = street.get("profile_points")
	if path.size() < 2:
		m_failures.append("Generated street did not retain its centerline points")
	if profile.size() < 2:
		m_failures.append("Generated street did not retain its sampled height profile")
	var mesh_before := street.get("mesh") as ArrayMesh
	if mesh_before == null or mesh_before.get_surface_count() <= 0:
		m_failures.append("Generated street has no baked mesh to start from")
		return
	var vertices_before := int(mesh_before.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())

	# Simulate the save-time geometry drop, then load-time reconstruction.
	terrain._strip_generated_street_meshes_for_save()
	if street.get("mesh") != null:
		m_failures.append("Save-time strip did not drop the generated street mesh")
	street.call("rebuild_street_mesh")
	var mesh_after := street.get("mesh") as ArrayMesh
	if mesh_after == null or mesh_after.get_surface_count() <= 0:
		m_failures.append("Generated street did not rebuild its mesh from the stored profile")
	else:
		var vertices_after := int(mesh_after.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
		if vertices_after != vertices_before:
			m_failures.append(
				"Mesh rebuilt from the stored profile differs from the original (%d vs %d vertices)"
				% [vertices_after, vertices_before]
			)
	terrain._restore_generated_street_meshes_after_save()


func _validate_diagonal_stays_straight() -> void:
	# A non-45-degree mask line rasterizes into a staircase of cells. The
	# extractor must collapse that back into a single straight diagonal run
	# instead of emitting the staircase corners as a zigzag street.
	var mask := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	var start := Vector2i(6, 8)
	var end := Vector2i(40, 26)
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := int(round(lerpf(start.x, end.x, t)))
		var py := int(round(lerpf(start.y, end.y, t)))
		mask.set_pixel(px, py, Color.BLUE)
	if mask.save_png(m_diagonal_mask_path) != OK:
		m_failures.append("Could not write the diagonal-street mask fixture")
		return

	var heightmap := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	heightmap.fill(Color(0.5, 0.5, 0.5, 1.0))
	if heightmap.save_png(m_heightmap_path) != OK:
		m_failures.append("Could not write the diagonal-street heightmap fixture")
		return

	var terrain := LowPolyTerrain3DScript.new() as LowPolyTerrain3DScript
	terrain.name = "DiagonalTerrain"
	terrain.build_on_ready = false
	terrain.print_summary = false
	terrain.mask_file = m_diagonal_mask_path
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

	var root := terrain.get_node_or_null("GeneratedStreets")
	if root == null or root.get_child_count() <= 0:
		m_failures.append("Diagonal mask did not generate any streets")
		terrain.queue_free()
		return
	var longest: PackedVector3Array = PackedVector3Array()
	for child in root.get_children():
		var path: PackedVector3Array = child.get("path_points")
		if path.size() > longest.size():
			longest = path
	if longest.size() < 2:
		m_failures.append("Diagonal mask produced no usable street path")
	elif longest.size() > 2:
		m_failures.append(
			"Diagonal mask produced a zigzag street path with %d points instead of a straight run"
			% longest.size()
		)
	elif longest.size() == 2:
		var delta := longest[1] - longest[0]
		if absf(delta.x) < 0.5 or absf(delta.z) < 0.5:
			m_failures.append("Diagonal street path collapsed but is not actually diagonal")
	terrain.queue_free()


func _finish() -> void:
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: terrain STREET mask generation smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)
