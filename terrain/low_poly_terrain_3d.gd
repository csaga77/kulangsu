@tool
class_name LowPolyTerrain3D
extends Node3D

signal terrain_rebuilt(summary: Dictionary)

const GENERATED_META := &"low_poly_terrain_generated"
const LowPolyArtStyle3DScript = preload("res://terrain/low_poly_art_style_3d.gd")
const LowPolyStreetCorridorIntegratorScript = preload(
	"res://terrain/low_poly_street_corridor_integrator.gd"
)
const LowPolyStreetPathExtractorScript = preload(
	"res://terrain/low_poly_street_path_extractor.gd"
)
const GENERATED_STREET_META := &"low_poly_terrain_generated_street"
## The generated-street root is persisted into the scene, so it carries its own
## meta instead of GENERATED_META. That keeps the per-rebuild transient clear
## (which targets GENERATED_META mesh/water children) from deleting baked streets.
const GENERATED_STREET_ROOT_META := &"low_poly_terrain_generated_street_root"
const GENERATED_STREET_ROOT_NAME := &"GeneratedStreets"
const STREET_3D_SCRIPT_PATH := "res://addons/low_poly_building_editor/streets/street_3d.gd"
const STREET_GEOMETRY_RESOLVER_SCRIPT_PATH := (
	"res://addons/low_poly_building_editor/streets/street_geometry_resolver.gd"
)
const WATER_SHADER := preload("res://resources/materials/water_3d.gdshader")

@export var rebuild: bool = false:
	set(value):
		if !value:
			return
		_request_rebuild()

@export_file_path("*.png") var mask_file: String = "res://design/gulangyu_map_mini_export.png":
	set(new_mask_file):
		if mask_file == new_mask_file:
			return
		mask_file = new_mask_file
		_request_rebuild()

@export_file_path("*.png") var heightmap_file: String = "res://design/gulangyu_height_map_mini_export.png":
	set(new_heightmap_file):
		if heightmap_file == new_heightmap_file:
			return
		heightmap_file = new_heightmap_file

@export var generation_profile: TerrainGenerationProfile:
	set(new_profile):
		if generation_profile == new_profile:
			return
		generation_profile = new_profile
		_request_rebuild()

@export var art_style: LowPolyArtStyle3DScript:
	set(new_style):
		if art_style == new_style:
			return
		art_style = new_style
		_request_rebuild()

@export_range(1, 32, 1) var sample_stride := 4:
	set(new_stride):
		var clamped_stride := maxi(new_stride, 1)
		if sample_stride == clamped_stride:
			return
		sample_stride = clamped_stride
		_request_rebuild()

@export_range(0.1, 10.0, 0.1) var cell_size := 1.0:
	set(new_cell_size):
		var clamped_size := maxf(new_cell_size, 0.1)
		if is_equal_approx(cell_size, clamped_size):
			return
		cell_size = clamped_size
		_request_rebuild()

@export_range(0.0, 4.0, 0.01) var water_height := 0.0:
	set(new_height):
		if is_equal_approx(water_height, new_height):
			return
		water_height = new_height
		_request_rebuild()

@export_range(0.0, 4.0, 0.01) var land_height := 0.22:
	set(new_height):
		if is_equal_approx(land_height, new_height):
			return
		land_height = new_height
		_request_rebuild()

@export var smooth_land_surface := true:
	set(new_smooth_land_surface):
		if smooth_land_surface == new_smooth_land_surface:
			return
		smooth_land_surface = new_smooth_land_surface
		_request_rebuild()

@export_range(0, 4, 1) var height_smoothing_passes := 1:
	set(new_passes):
		var clamped_passes := clampi(new_passes, 0, 4)
		if height_smoothing_passes == clamped_passes:
			return
		height_smoothing_passes = clamped_passes
		_request_rebuild()

@export var heightmap_expands_land_to_source := true:
	set(new_expands_land):
		if heightmap_expands_land_to_source == new_expands_land:
			return
		heightmap_expands_land_to_source = new_expands_land

@export_range(-4.0, 4.0, 0.01) var heightmap_min_offset := 0.0:
	set(new_offset):
		if is_equal_approx(heightmap_min_offset, new_offset):
			return
		heightmap_min_offset = new_offset

@export_range(-10.0, 10.0, 0.01) var heightmap_max_offset := 0.0:
	set(new_offset):
		if is_equal_approx(heightmap_max_offset, new_offset):
			return
		heightmap_max_offset = new_offset

@export_range(0.0, 1.0, 0.01) var street_lift := 0.02:
	set(new_lift):
		if is_equal_approx(street_lift, new_lift):
			return
		street_lift = new_lift
		_request_rebuild()

@export_range(0.0, 2.0, 0.01) var building_footprint_lift := 0.09:
	set(new_lift):
		if is_equal_approx(building_footprint_lift, new_lift):
			return
		building_footprint_lift = new_lift
		_request_rebuild()

# Terrain palette and water tuning (land_color, shoreline_color,
# building_footprint_color, water_color, water_deep_color, water_surface_layer_color,
# water_shoreline_color, water_highlight_color, water_wave_depth, water_wave_frequency,
# water_shoreline_band_ratio, water_shoreline_lift, water_surface_layer_lift) now live
# only on LowPolyArtStyle3D. Assign `art_style` to override them; otherwise a built-in
# default style is used. See _effective_style().

@export_range(0, 4, 1) var water_land_overlap_cells := 1:
	set(new_overlap_cells):
		var clamped_overlap := clampi(new_overlap_cells, 0, 4)
		if water_land_overlap_cells == clamped_overlap:
			return
		water_land_overlap_cells = clamped_overlap
		_request_rebuild()

@export var generate_collision := true:
	set(new_generate_collision):
		if generate_collision == new_generate_collision:
			return
		generate_collision = new_generate_collision
		_request_rebuild()

@export var build_on_ready := true
@export var print_summary := true

@export_group("Street Integration")
## Converts STREET cells from the terrain mask into generated road, kerb, and
## footpath assemblies. This happens before corridor shaping and mesh creation.
@export var generate_streets_from_mask := true:
	set(value):
		if generate_streets_from_mask == value:
			return
		generate_streets_from_mask = value
		_request_rebuild()
@export_range(2, 32, 1) var generated_street_minimum_path_cells := 2:
	set(value):
		var clamped_value := maxi(value, 2)
		if generated_street_minimum_path_cells == clamped_value:
			return
		generated_street_minimum_path_cells = clamped_value
		_request_rebuild()
@export_range(1, 512, 1) var generated_street_maximum_paths := 256:
	set(value):
		var clamped_value := maxi(value, 1)
		if generated_street_maximum_paths == clamped_value:
			return
		generated_street_maximum_paths = clamped_value
		_request_rebuild()
@export_range(0.25, 3.0, 0.05) var generated_street_road_width_cells := 0.9:
	set(value):
		var clamped_value := maxf(value, 0.25)
		if is_equal_approx(generated_street_road_width_cells, clamped_value):
			return
		generated_street_road_width_cells = clamped_value
		_request_rebuild()
@export_range(0.0, 2.0, 0.05) var generated_street_footpath_width_cells := 0.35:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(generated_street_footpath_width_cells, clamped_value):
			return
		generated_street_footpath_width_cells = clamped_value
		_request_rebuild()
## Centerline simplify tolerance in cells. Diagonal mask lines rasterize into a
## staircase whose corners sit up to ~1 cell off the ideal chord, so a tolerance
## above one cell straightens diagonals into a single run while preserving
## multi-cell bends and curves. Lower it only to keep finer sub-cell jogs.
@export_range(0.0, 3.0, 0.05) var generated_street_simplify_tolerance_cells := 1.2:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(generated_street_simplify_tolerance_cells, clamped_value):
			return
		generated_street_simplify_tolerance_cells = clamped_value
		_request_rebuild()
## When enabled, the terrain discovers duck-typed street sources, lets them
## sample the unmodified base grid, then shapes the terrain bed beneath their
## published road/kerb/footpath corridors before mesh and collision creation.
@export var integrate_street_corridors := true:
	set(value):
		if integrate_street_corridors == value:
			return
		integrate_street_corridors = value
		_request_rebuild()
@export var auto_resample_street_profiles := true:
	set(value):
		if auto_resample_street_profiles == value:
			return
		auto_resample_street_profiles = value
		_request_rebuild()
## Optional subtree containing Street3D-compatible sources. Empty searches the
## owning/current scene without serializing a dependency on the editor add-on.
@export_node_path("Node") var street_source_root_path := NodePath(""):
	set(value):
		if street_source_root_path == value:
			return
		street_source_root_path = value
		_request_rebuild()
@export_range(0.0, 4.0, 0.25) var street_corridor_feather_cells := 1.0:
	set(value):
		var clamped_value := clampf(value, 0.0, 4.0)
		if is_equal_approx(street_corridor_feather_cells, clamped_value):
			return
		street_corridor_feather_cells = clamped_value
		_request_rebuild()
@export var street_corridors_may_shape_water := false:
	set(value):
		if street_corridors_may_shape_water == value:
			return
		street_corridors_may_shape_water = value
		_request_rebuild()

@export_group("Wind")
## Horizontal direction the water waves travel, in degrees. Drive this from
## weather (e.g. WeatherManager wind_angle_degrees) via set_wind(); the
## prototype stays decoupled from the weather system.
@export_range(0.0, 360.0, 1.0) var wind_angle_degrees := 72.0:
	set(value):
		wind_angle_degrees = wrapf(value, 0.0, 360.0)
		_apply_wind_to_water()
## Normalized wind strength: 0 = near-calm ripple, 1 = full choppy seas. Map a
## raw weather wind speed into 0..1 before passing it in.
@export_range(0.0, 1.0, 0.01) var wind_strength := 0.5:
	set(value):
		wind_strength = clampf(value, 0.0, 1.0)
		_apply_wind_to_water()

var m_is_ready := false
var m_rebuild_queued := false
var m_queued_regenerate_streets := false
var m_sample_grid: Array[Array] = []
var m_source_size := Vector2i.ZERO
var m_heightmap_defines_water_area := false
var m_default_style: LowPolyArtStyle3DScript = null
var m_water_materials: Array[ShaderMaterial] = []
var m_mesh_builder: LowPolyTerrainMeshBuilder = null
var m_integrating_streets := false
var m_generated_street_intersection_refresh_queued := false
var m_street_integrator: LowPolyStreetCorridorIntegratorScript = null
var m_street_path_extractor: LowPolyStreetPathExtractorScript = null
var last_rebuild_duration_ms := 0.0
var last_street_integration_summary: Dictionary = {}
# Generated street meshes are held out of the saved scene: only their centerline,
# sampled heights, and authored properties serialize, and the mesh rebuilds from
# those on load. This stashes the live meshes across an editor save.
var m_saved_street_meshes: Dictionary = {}


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		# Scene load reshapes terrain but reuses the streets baked into the scene
		# instead of regenerating them.
		_rebuild_from_source(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		# Drop generated street geometry so the .tscn stores only the street
		# definition (centerline, sampled heights, authored properties).
		_strip_generated_street_meshes_for_save()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		# Restore the live meshes so the editor keeps showing the streets.
		_restore_generated_street_meshes_after_save()


func _request_rebuild(regenerate_streets := true) -> void:
	if !m_is_ready:
		return
	m_queued_regenerate_streets = m_queued_regenerate_streets or regenerate_streets
	if m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("_run_queued_rebuild")


func _run_queued_rebuild() -> void:
	if !m_rebuild_queued:
		return
	var regenerate_streets := m_queued_regenerate_streets
	m_rebuild_queued = false
	m_queued_regenerate_streets = false
	_rebuild_from_source(regenerate_streets)


## Explicit rebuild: regenerates street geometry from the mask and bakes it into
## the scene. This is the "rebuild the terrain in the editor" entry point.
func rebuild_from_source() -> void:
	_rebuild_from_source(true)


## Reshapes terrain from the source while keeping the already-generated streets
## stored in the scene. Matches the scene-load path; useful for refreshing the
## terrain bed without discarding baked street geometry.
func rebuild_reusing_generated_streets() -> void:
	_rebuild_from_source(false)


func request_street_integration_rebuild() -> void:
	_request_rebuild(false)


func get_sample_cell_height(sample_cell: Vector2i) -> float:
	if m_sample_grid.is_empty():
		return land_height

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var clamped_cell := Vector2i(
		clampi(sample_cell.x, 0, grid_size.x - 1),
		clampi(sample_cell.y, 0, grid_size.y - 1)
	)
	var cell := m_sample_grid[clamped_cell.y][clamped_cell.x] as LowPolyTerrainCell
	if cell == null:
		return land_height
	var builder := _ensure_mesh_builder()
	if cell.kind == LowPolyTerrainCell.Kind.WATER:
		if !m_heightmap_defines_water_area:
			return water_height
		return builder.get_cell_surface_height(
			m_sample_grid,
			clamped_cell.x,
			clamped_cell.y,
			cell.height,
			0.5,
			0.5,
			true
		)
	return builder.get_cell_surface_height(
		m_sample_grid,
		clamped_cell.x,
		clamped_cell.y,
		cell.height,
		0.5,
		0.5,
		m_heightmap_defines_water_area
	)


func get_sample_cell_kind(sample_cell: Vector2i) -> LowPolyTerrainCell.Kind:
	if m_sample_grid.is_empty():
		return LowPolyTerrainCell.Kind.WATER

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var clamped_cell := Vector2i(
		clampi(sample_cell.x, 0, grid_size.x - 1),
		clampi(sample_cell.y, 0, grid_size.y - 1)
	)
	var cell := m_sample_grid[clamped_cell.y][clamped_cell.x] as LowPolyTerrainCell
	if cell == null:
		return LowPolyTerrainCell.Kind.WATER
	return cell.kind


func get_world_surface_height(world_position: Vector3) -> float:
	if m_sample_grid.is_empty():
		return land_height

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var origin_offset := _get_grid_origin_offset(grid_size)
	var grid_position := Vector2(
		(world_position.x - origin_offset.x) / cell_size,
		(world_position.z - origin_offset.z) / cell_size
	)
	var sample_cell := Vector2i(
		clampi(floori(grid_position.x), 0, grid_size.x - 1),
		clampi(floori(grid_position.y), 0, grid_size.y - 1)
	)
	var local_x := clampf(grid_position.x - float(sample_cell.x), 0.0, 1.0)
	var local_z := clampf(grid_position.y - float(sample_cell.y), 0.0, 1.0)
	var cell := m_sample_grid[sample_cell.y][sample_cell.x] as LowPolyTerrainCell
	if cell == null:
		return land_height
	var builder := _ensure_mesh_builder()
	if cell.kind == LowPolyTerrainCell.Kind.WATER:
		if !m_heightmap_defines_water_area:
			return water_height
		return builder.get_cell_surface_height(
			m_sample_grid,
			sample_cell.x,
			sample_cell.y,
			cell.height,
			local_x,
			local_z,
			true
		)
	return builder.get_cell_surface_height(
		m_sample_grid,
		sample_cell.x,
		sample_cell.y,
		cell.height,
		local_x,
		local_z,
		m_heightmap_defines_water_area
	)


func get_world_water_surface_height(world_position: Vector3) -> float:
	# Visible top surface for placement: the flat water plane over water cells (in
	# both mask-clipped and heightmap-expanded modes) and the land surface
	# elsewhere. Unlike get_world_surface_height, this never returns the submerged
	# seabed elevation, so callers can rest actors, boats, or hotspots on the water
	# plane instead of sinking them to the seabed.
	if m_sample_grid.is_empty():
		return water_height

	var grid_size := Vector2i(m_sample_grid[0].size(), m_sample_grid.size())
	var origin_offset := _get_grid_origin_offset(grid_size)
	var grid_position := Vector2(
		(world_position.x - origin_offset.x) / cell_size,
		(world_position.z - origin_offset.z) / cell_size
	)
	var sample_cell := Vector2i(
		clampi(floori(grid_position.x), 0, grid_size.x - 1),
		clampi(floori(grid_position.y), 0, grid_size.y - 1)
	)
	var cell := m_sample_grid[sample_cell.y][sample_cell.x] as LowPolyTerrainCell
	if cell == null or cell.kind == LowPolyTerrainCell.Kind.WATER:
		return water_height
	return get_world_surface_height(world_position)


func get_sample_cell_water_surface_height(sample_cell: Vector2i) -> float:
	# Sample-cell companion to get_world_water_surface_height: the water plane over
	# water cells, the land surface otherwise.
	if get_sample_cell_kind(sample_cell) == LowPolyTerrainCell.Kind.WATER:
		return water_height
	return get_sample_cell_height(sample_cell)


func get_source_size() -> Vector2i:
	return m_source_size


func get_street_integration_summary() -> Dictionary:
	return last_street_integration_summary.duplicate(true)


func _rebuild_from_source(regenerate_streets: bool = true) -> void:
	var rebuild_started_usec := Time.get_ticks_usec()
	m_rebuild_queued = false
	m_queued_regenerate_streets = false
	_clear_generated_children()
	m_sample_grid.clear()
	m_source_size = Vector2i.ZERO
	m_heightmap_defines_water_area = false

	var profile := _get_generation_profile()
	if profile == null:
		return

	var heightmap_image := _load_heightmap_image()
	var mask_image := _load_mask_image()
	if mask_image == null and heightmap_image == null:
		push_warning("LowPolyTerrain3D requires a mask_file or heightmap_file.")
		return

	var source_size := _resolve_generation_source_size(mask_image, heightmap_image)
	if source_size == Vector2i.ZERO:
		push_warning("LowPolyTerrain3D could not resolve a terrain source size.")
		return

	var sampler := _build_sampler()
	var grid := sampler.build_grid(mask_image, profile, heightmap_image, source_size)
	var heightmap_defines_water_area := sampler.heightmap_fills_source_land(heightmap_image)
	m_sample_grid = grid
	m_source_size = source_size
	m_heightmap_defines_water_area = heightmap_defines_water_area
	var generated_sources: Array[Node] = []
	var generation_summary: Dictionary = {}
	if regenerate_streets:
		# Explicit rebuild: discard baked streets and re-derive them from the mask.
		_clear_generated_streets()
		var generated_streets := _generate_streets_from_mask(grid)
		generated_sources = generated_streets["sources"]
		generation_summary = generated_streets["summary"]
	else:
		# Scene load / reuse: keep the streets stored in the scene and only feed
		# their baked corridors into terrain shaping.
		generated_sources = _collect_generated_street_sources()
		generation_summary = _reused_street_summary(generated_sources)
	_refresh_generated_street_intersections(generated_sources)
	last_street_integration_summary = _integrate_street_generation(grid, generated_sources)
	last_street_integration_summary.merge(generation_summary, true)
	if print_summary and int(last_street_integration_summary.get("mask_street_cell_count", 0)) > 0:
		print(
			"LowPolyTerrain3D: street mask %d cells -> %d paths -> %d generated streets (%d errors)."
			% [
				int(last_street_integration_summary.get("mask_street_cell_count", 0)),
				int(last_street_integration_summary.get("mask_path_count", 0)),
				int(last_street_integration_summary.get("generated_source_count", 0)),
				(last_street_integration_summary.get("generation_errors", []) as Array).size(),
			]
		)
	_build_meshes_from_grid(grid, source_size.x, source_size.y, heightmap_defines_water_area)
	last_rebuild_duration_ms = float(Time.get_ticks_usec() - rebuild_started_usec) / 1000.0
	var rebuild_summary := {
		"duration_ms": last_rebuild_duration_ms,
		"source_size": source_size,
		"street_integration": last_street_integration_summary.duplicate(true),
	}
	terrain_rebuilt.emit(rebuild_summary)
	if print_summary:
		print("LowPolyTerrain3D: cold rebuild %.2f ms." % last_rebuild_duration_ms)


func _integrate_street_generation(
	grid: Array[Array],
	generated_sources: Array[Node] = []
) -> Dictionary:
	var empty_summary := {
		"source_count": 0,
		"authored_source_count": 0,
		"generated_source_count": generated_sources.size(),
		"corridor_count": 0,
		"core_cells": 0,
		"feather_cells": 0,
		"water_cells_skipped": 0,
		"errors": [] as Array[String],
	}
	if !integrate_street_corridors or grid.is_empty():
		return empty_summary
	var sources: Array[Node] = []
	_collect_street_sources(_street_source_root(), sources)
	var authored_source_count := sources.size()
	for source: Node in generated_sources:
		if !sources.has(source):
			sources.append(source)
	if sources.is_empty():
		return empty_summary
	var errors: Array[String] = []
	var corridors: Array[Dictionary] = []
	m_integrating_streets = true
	for source: Node in sources:
		_connect_street_source(source)
		var source_failed := false
		if (
			auto_resample_street_profiles
			and !source.has_meta(GENERATED_STREET_META)
			and source.has_method("resample_terrain")
		):
			var previous_state: Dictionary = {}
			if source.has_method("capture_native_transform_state"):
				previous_state = source.call("capture_native_transform_state")
			var sample_result: Variant = source.call("resample_terrain", self)
			var sample_errors := _string_array(sample_result)
			if !sample_errors.is_empty():
				errors.append_array(sample_errors)
				source_failed = true
				if !previous_state.is_empty() and source.has_method("restore_native_transform_state"):
					source.call("restore_native_transform_state", previous_state)
		if source_failed:
			continue
		if !source.has_method("get_world_terrain_corridor"):
			continue
		var corridor: Variant = source.call("get_world_terrain_corridor")
		if corridor is Dictionary and !(corridor as Dictionary).is_empty():
			corridors.append(corridor)
	m_integrating_streets = false
	if m_street_integrator == null:
		m_street_integrator = LowPolyStreetCorridorIntegratorScript.new()
	var integration: Dictionary = m_street_integrator.apply(
		grid,
		self,
		corridors,
		cell_size,
		_get_grid_origin_offset(Vector2i(grid[0].size(), grid.size())),
		street_corridor_feather_cells * cell_size,
		street_corridors_may_shape_water
	)
	integration["source_count"] = sources.size()
	integration["authored_source_count"] = authored_source_count
	integration["generated_source_count"] = generated_sources.size()
	integration["errors"] = errors
	for error in errors:
		push_warning("LowPolyTerrain3D street integration: %s" % error)
	return integration


func _generate_streets_from_mask(grid: Array[Array]) -> Dictionary:
	var sources: Array[Node] = []
	var generation_errors: Array[String] = []
	var summary := {
		"mask_street_cell_count": 0,
		"mask_street_skeleton_cell_count": 0,
		"mask_path_count": 0,
		"generated_source_count": 0,
		"discarded_mask_path_count": 0,
		"truncated_mask_path_count": 0,
		"generation_errors": generation_errors,
	}
	if !generate_streets_from_mask or grid.is_empty():
		return {"sources": sources, "summary": summary}
	if m_street_path_extractor == null:
		m_street_path_extractor = LowPolyStreetPathExtractorScript.new()
	var extraction: Dictionary = m_street_path_extractor.extract(
		grid,
		cell_size,
		_get_grid_origin_offset(Vector2i(grid[0].size(), grid.size())),
		generated_street_minimum_path_cells,
		generated_street_maximum_paths,
		generated_street_simplify_tolerance_cells
	)
	summary["mask_street_cell_count"] = int(extraction.get("street_cell_count", 0))
	summary["mask_street_skeleton_cell_count"] = int(extraction.get("skeleton_cell_count", 0))
	summary["discarded_mask_path_count"] = int(extraction.get("discarded_path_count", 0))
	summary["truncated_mask_path_count"] = int(extraction.get("truncated_path_count", 0))
	var paths: Array[PackedVector3Array] = extraction.get("paths", [] as Array[PackedVector3Array])
	summary["mask_path_count"] = paths.size()
	if paths.is_empty():
		return {"sources": sources, "summary": summary}
	var street_script := load(STREET_3D_SCRIPT_PATH) as GDScript
	if street_script == null:
		var missing_script_error := "Street mask paths were found, but Street3D could not be loaded."
		generation_errors.append(missing_script_error)
		push_warning("LowPolyTerrain3D: %s" % missing_script_error)
		return {"sources": sources, "summary": summary}

	var root := Node3D.new()
	root.name = GENERATED_STREET_ROOT_NAME
	root.set_meta(GENERATED_STREET_ROOT_META, true)
	add_child(root)
	_persist_generated_street(root)
	for index in range(paths.size()):
		var street := street_script.new() as Node3D
		if street == null:
			generation_errors.append("Could not instantiate generated street path %d." % index)
			continue
		street.name = "Street_%03d" % (index + 1)
		street.set_meta(GENERATED_STREET_META, true)
		street.set("build_on_ready", false)
		street.set("generate_collision", generate_collision)
		street.set("path_points", paths[index])
		street.set("road_width", generated_street_road_width_cells * cell_size)
		street.set("kerb_width", maxf(cell_size * 0.06, 0.04))
		street.set("kerb_height", maxf(cell_size * 0.06, 0.04))
		street.set("footpath_width", maxf(generated_street_footpath_width_cells * cell_size, 0.05))
		street.set("terrain_sample_spacing", maxf(cell_size * 0.5, 0.1))
		street.set("terrain_clearance", maxf(street_lift, 0.015))
		root.add_child(street)
		var sample_result: Variant = street.call("resample_terrain", self)
		var sample_errors := _string_array(sample_result)
		if !sample_errors.is_empty():
			# A source heightmap can be steeper than the authoring defaults permit.
			# Keep the requested 25-degree trigger, but derive the smallest larger
			# riser needed to make this particular sampled path constructible.
			_adapt_generated_stair_constraints(street)
			street.call("rebuild_street_mesh")
			sample_errors = _string_array(street.call("get_validation_errors"))
		if !sample_errors.is_empty():
			generation_errors.append_array(sample_errors)
			root.remove_child(street)
			street.queue_free()
			continue
		# Bake the street into the scene: build_on_ready lets a later scene load
		# rebuild collision from the cached mesh without regenerating geometry, and
		# _persist_generated_street sets owner so the node and its serialized mesh
		# save into the .tscn.
		street.set("build_on_ready", true)
		_persist_generated_street(street)
		sources.append(street)
	summary["generated_source_count"] = sources.size()
	return {"sources": sources, "summary": summary}


func _adapt_generated_stair_constraints(street: Node3D) -> void:
	if !street.has_method("get_geometry_profile"):
		return
	var profile: PackedVector3Array = street.call("get_geometry_profile")
	if profile.size() < 2:
		return
	var minimum_tread := maxf(cell_size * 0.1, 0.05)
	var required_maximum_riser := float(street.get("max_riser_height"))
	for index in range(profile.size() - 1):
		var a := profile[index]
		var b := profile[index + 1]
		var run := Vector2(b.x - a.x, b.z - a.z).length()
		var rise := absf(b.y - a.y)
		if run <= 0.00001 or rad_to_deg(atan2(rise, run)) <= 25.0001:
			continue
		var available_steps := maxi(floori(run / minimum_tread), 1)
		required_maximum_riser = maxf(
			required_maximum_riser,
			rise / float(available_steps) + 0.0001
		)
	street.set("min_tread_depth", minimum_tread)
	street.set("max_riser_height", required_maximum_riser)


func _refresh_generated_street_intersections(streets: Array[Node]) -> void:
	if streets.size() < 2:
		return
	var resolver_script := load(STREET_GEOMETRY_RESOLVER_SCRIPT_PATH) as GDScript
	if resolver_script == null:
		push_warning("LowPolyTerrain3D could not load the generated-street intersection resolver.")
		return
	var resolver: RefCounted = resolver_script.new(streets)
	resolver.call("refresh_street_intersection_cuts")


func _street_source_root() -> Node:
	if !street_source_root_path.is_empty():
		var configured := get_node_or_null(street_source_root_path)
		if configured != null:
			return configured
	if owner != null:
		return owner
	if get_tree() != null and get_tree().current_scene != null:
		return get_tree().current_scene
	var root: Node = self
	while root.get_parent() != null:
		root = root.get_parent()
	return root


func _collect_street_sources(node: Node, result: Array[Node]) -> void:
	if node == null:
		return
	if (
		node != self
		and node.has_method("is_terrain_street_source")
		and bool(node.call("is_terrain_street_source"))
		and node.has_method("get_world_terrain_corridor")
	):
		result.append(node)
	for child in node.get_children():
		# Skip transient generated meshes and the baked-street root so generated
		# streets are never rediscovered here as authored sources.
		if child.has_meta(GENERATED_META) or child.has_meta(GENERATED_STREET_ROOT_META):
			continue
		_collect_street_sources(child, result)


func _connect_street_source(source: Node) -> void:
	if !source.has_signal("terrain_corridor_changed"):
		return
	var legacy_callback := Callable(self, "_on_street_corridor_changed")
	if source.is_connected("terrain_corridor_changed", legacy_callback):
		source.disconnect("terrain_corridor_changed", legacy_callback)
	var callback := legacy_callback.bind(source)
	if !source.is_connected("terrain_corridor_changed", callback):
		source.connect("terrain_corridor_changed", callback)


func _on_street_corridor_changed(source: Node = null) -> void:
	if m_integrating_streets:
		return
	if source != null and !source.has_meta(GENERATED_STREET_META):
		# Authored streets remain terrain corridor sources; their owning Building3D
		# resolves visible sibling intersections independently.
		_request_rebuild(false)
		return
	_request_generated_street_intersection_refresh()


func _request_generated_street_intersection_refresh() -> void:
	if m_generated_street_intersection_refresh_queued:
		return
	m_generated_street_intersection_refresh_queued = true
	call_deferred("_refresh_queued_generated_street_intersections")


func _refresh_queued_generated_street_intersections() -> void:
	m_generated_street_intersection_refresh_queued = false
	_refresh_generated_street_intersections(_collect_generated_street_sources())


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(String(entry))
	return result


func _build_sampler() -> LowPolyTerrainSampler:
	var sampler := LowPolyTerrainSampler.new()
	sampler.sample_stride = sample_stride
	sampler.land_height = land_height
	sampler.water_height = water_height
	sampler.smooth_land_surface = smooth_land_surface
	sampler.height_smoothing_passes = height_smoothing_passes
	sampler.heightmap_min_offset = heightmap_min_offset
	sampler.heightmap_max_offset = heightmap_max_offset
	sampler.heightmap_expands_land_to_source = heightmap_expands_land_to_source
	return sampler


func _get_generation_profile() -> TerrainGenerationProfile:
	var profile := generation_profile
	if profile == null:
		profile = TerrainGenerationProfile.create_default_profile() as TerrainGenerationProfile
	profile.ensure_defaults()
	if !profile.is_valid_profile():
		return null
	return profile


func _load_mask_image() -> Image:
	if mask_file.is_empty():
		return null

	var image := Image.new()
	var load_error := image.load(mask_file)
	if load_error != OK:
		push_error("LowPolyTerrain3D failed to load mask image: %s (err=%d)" % [mask_file, load_error])
		return null

	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _load_heightmap_image() -> Image:
	if heightmap_file.is_empty():
		return null

	var image := Image.new()
	var load_error := image.load(heightmap_file)
	if load_error != OK:
		push_error("LowPolyTerrain3D failed to load heightmap image: %s (err=%d)" % [heightmap_file, load_error])
		return null

	if image.is_compressed():
		image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _resolve_generation_source_size(mask_image: Image, heightmap_image: Image) -> Vector2i:
	if heightmap_expands_land_to_source and heightmap_image != null:
		return heightmap_image.get_size()
	if mask_image != null:
		return mask_image.get_size()
	if heightmap_image != null:
		return heightmap_image.get_size()
	return Vector2i.ZERO


func _build_meshes_from_grid(
	grid: Array[Array],
	source_width: int,
	source_height: int,
	heightmap_defines_water_area: bool
) -> void:
	if grid.is_empty():
		return

	var grid_height := grid.size()
	var grid_width := grid[0].size()

	var builder := _configure_mesh_builder()
	var rendering := builder.water_rendering
	var result := builder.build(grid, source_width, source_height, heightmap_defines_water_area)

	# All three transparent water layers run the same wave shader so they
	# displace together; render_priority keeps a stable composite order (body <
	# foam < gloss) regardless of camera angle. Cache the materials so live wind
	# updates (set_wind) can retune them without rebuilding the meshes.
	m_water_materials.clear()
	var water_material := _build_water_material(
		"Low Poly Water", rendering, true, rendering.base_color, rendering.material_alpha
	)
	water_material.render_priority = 0
	m_water_materials.append(water_material)
	_add_mesh_instance("WaterMesh", result.water, water_material)
	var water_shoreline_material := _build_water_material(
		"Low Poly Water Shoreline", rendering, false, rendering.shoreline_color, 1.0
	)
	water_shoreline_material.render_priority = 1
	m_water_materials.append(water_shoreline_material)
	_add_mesh_instance("WaterShorelineMesh", result.water_shoreline, water_shoreline_material)
	var water_surface_layer_material := _build_water_material(
		"Low Poly Water Surface Layer", rendering, false, rendering.surface_layer_color, 1.0
	)
	water_surface_layer_material.render_priority = 2
	m_water_materials.append(water_surface_layer_material)
	_add_mesh_instance("WaterSurfaceLayerMesh", result.water_surface_layer, water_surface_layer_material)
	_add_mesh_instance("LandMesh", result.land, _build_material("Low Poly Land", _resolve_style_color(&"land_color"), false))
	_add_mesh_instance("ShorelineMesh", result.shoreline, _build_material("Low Poly Shoreline", _resolve_style_color(&"shoreline_color"), false))
	_add_mesh_instance(
		"BuildingFootprintMesh",
		result.building,
		_build_material("Low Poly Building Footprints", _resolve_style_color(&"building_footprint_color"), false)
	)

	if generate_collision:
		_add_collision_body(result.collision_faces)

	if print_summary:
		print(
			"LowPolyTerrain3D: built %dx%d source into %dx%d sampled cells (%d land, %d street, %d building, %d water, %d water render)."
			% [source_width, source_height, grid_width, grid_height, result.land_cells, result.street_cells, result.building_cells, result.water_cells, result.water_render_cells]
		)


## Reuse a cached mesh builder configured with the geometry parameters the height
## queries depend on. _configure_mesh_builder adds the build-only fields.
func _ensure_mesh_builder() -> LowPolyTerrainMeshBuilder:
	if m_mesh_builder == null:
		m_mesh_builder = LowPolyTerrainMeshBuilder.new()
	m_mesh_builder.cell_size = cell_size
	m_mesh_builder.water_height = water_height
	m_mesh_builder.land_height = land_height
	m_mesh_builder.smooth_land_surface = smooth_land_surface
	return m_mesh_builder


func _configure_mesh_builder() -> LowPolyTerrainMeshBuilder:
	var builder := _ensure_mesh_builder()
	builder.building_footprint_lift = building_footprint_lift
	builder.water_land_overlap_cells = water_land_overlap_cells
	builder.water_rendering = _build_water_rendering()
	return builder


func _get_grid_origin_offset(grid_size: Vector2i) -> Vector3:
	return LowPolyWorldCoordinates3D.compute_world_origin(grid_size, cell_size)


func _add_mesh_instance(name_value: String, builder: LowPolyTerrainMeshBuilder.MeshBuildState, material: Material) -> void:
	if builder.vertices.is_empty():
		return

	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.vertices
	arrays[Mesh.ARRAY_NORMAL] = builder.normals
	if builder.colors.size() == builder.vertices.size():
		arrays[Mesh.ARRAY_COLOR] = builder.colors
	arrays[Mesh.ARRAY_INDEX] = builder.indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = name_value
	instance.mesh = mesh
	instance.material_override = material
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null


func _add_collision_body(collision_faces: PackedVector3Array) -> void:
	if collision_faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _build_material(name_value: String, color: Color, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name_value
	material.albedo_color = color
	material.roughness = 0.92
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent or color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _build_water_material(
	name_value: String,
	rendering: LowPolyTerrainMeshBuilder.WaterRendering,
	use_vertex_color: bool,
	base_color: Color,
	opacity: float
) -> ShaderMaterial:
	# Animated low-poly water with real wave-geometry displacement
	# (resources/materials/water_3d.gdshader). All three water layers share this
	# shader and the same world-space waves so they rise and fall together.
	var material := ShaderMaterial.new()
	material.resource_name = name_value
	material.shader = WATER_SHADER
	material.set_shader_parameter(&"use_vertex_color", use_vertex_color)
	material.set_shader_parameter(&"base_color", base_color)
	material.set_shader_parameter(&"water_opacity", opacity)
	material.set_shader_parameter(&"wave_depth", rendering.wave_depth)
	material.set_shader_parameter(&"wave_frequency", rendering.wave_frequency)
	material.set_shader_parameter(&"wave_speed", rendering.wave_speed)
	material.set_shader_parameter(&"highlight_color", rendering.highlight_color)
	material.set_shader_parameter(&"highlight_strength", clampf(0.14 + rendering.wave_depth * 0.3, 0.1, 0.4))
	material.set_shader_parameter(&"wind_dir", _wind_direction())
	material.set_shader_parameter(&"wind_strength", wind_strength)
	return material


## Set the water wind live without rebuilding meshes. wind_angle is in degrees
## (horizontal wave travel direction); normalized_strength is 0..1. Intended to
## be driven by weather (e.g. map WeatherManager wind to these), keeping this
## prototype decoupled from the weather system.
func set_wind(wind_angle: float, normalized_strength: float) -> void:
	# Assigning the exported properties runs their setters, which retune the
	# cached water materials via _apply_wind_to_water().
	wind_angle_degrees = wind_angle
	wind_strength = normalized_strength


func _wind_direction() -> Vector2:
	var radians := deg_to_rad(wind_angle_degrees)
	return Vector2(cos(radians), sin(radians))


func _apply_wind_to_water() -> void:
	var direction := _wind_direction()
	for material in m_water_materials:
		if material == null:
			continue
		material.set_shader_parameter(&"wind_dir", direction)
		material.set_shader_parameter(&"wind_strength", wind_strength)


func _build_water_rendering() -> LowPolyTerrainMeshBuilder.WaterRendering:
	var rendering := LowPolyTerrainMeshBuilder.WaterRendering.new()
	rendering.base_color = _resolve_style_color(&"water_color")
	rendering.deep_color = _resolve_style_color(&"water_deep_color")
	rendering.surface_layer_color = _resolve_style_color(&"water_surface_layer_color")
	rendering.shoreline_color = _resolve_style_color(&"water_shoreline_color")
	rendering.highlight_color = _resolve_style_color(&"water_highlight_color")
	rendering.material_alpha = clampf(maxf(rendering.base_color.a, rendering.deep_color.a), 0.0, 0.62)
	rendering.wave_depth = maxf(_resolve_style_float(&"water_wave_depth"), 0.0)
	rendering.wave_frequency = maxf(_resolve_style_float(&"water_wave_frequency"), 0.05)
	rendering.wave_speed = maxf(_resolve_style_float(&"water_wave_speed"), 0.0)
	rendering.shoreline_band_ratio = clampf(
		_resolve_style_float(&"water_shoreline_band_ratio"),
		0.0,
		0.45
	)
	rendering.shoreline_lift = maxf(_resolve_style_float(&"water_shoreline_lift"), 0.0)
	rendering.surface_layer_lift = maxf(_resolve_style_float(&"water_surface_layer_lift"), 0.0)
	return rendering


func _effective_style() -> LowPolyArtStyle3DScript:
	if art_style != null:
		return art_style
	if m_default_style == null:
		m_default_style = LowPolyArtStyle3DScript.new()
	return m_default_style


func _resolve_style_color(property_name: StringName) -> Color:
	var value: Variant = _effective_style().get(property_name)
	if value is Color:
		return value
	return Color.MAGENTA


func _resolve_style_float(property_name: StringName) -> float:
	var value: Variant = _effective_style().get(property_name)
	if value is float or value is int:
		return float(value)
	return 0.0


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.queue_free()


## Removes the baked-street root. Called only on an explicit rebuild, right
## before streets are regenerated, so scene loads never discard baked streets.
func _clear_generated_streets() -> void:
	var root := _generated_street_root()
	if root == null:
		return
	remove_child(root)
	root.queue_free()


func _generated_street_root() -> Node:
	return get_node_or_null(NodePath(String(GENERATED_STREET_ROOT_NAME)))


## Editor PRE_SAVE: null each generated street's mesh so the geometry is not
## serialized. The centerline, sampled height profile, and authored properties
## still persist, and build_on_ready rebuilds the mesh from them on load.
func _strip_generated_street_meshes_for_save() -> void:
	m_saved_street_meshes.clear()
	var root := _generated_street_root()
	if root == null:
		return
	for child in root.get_children():
		if !child.has_meta(GENERATED_STREET_META):
			continue
		var street := child as MeshInstance3D
		if street == null:
			continue
		m_saved_street_meshes[street.get_instance_id()] = street.mesh
		street.mesh = null


## Editor POST_SAVE companion: put the live meshes back after the save wrote the
## definition-only nodes.
func _restore_generated_street_meshes_after_save() -> void:
	for instance_id: int in m_saved_street_meshes:
		var street := instance_from_id(instance_id) as MeshInstance3D
		if street != null:
			street.mesh = m_saved_street_meshes[instance_id]
	m_saved_street_meshes.clear()


## Streets already baked into the scene, used as corridor sources on reuse.
func _collect_generated_street_sources() -> Array[Node]:
	var result: Array[Node] = []
	if !generate_streets_from_mask:
		return result
	var root := _generated_street_root()
	if root == null:
		return result
	for child in root.get_children():
		if child.has_meta(GENERATED_STREET_META) and child.has_method("get_world_terrain_corridor"):
			result.append(child)
	return result


## Sets owner so a generated street node (and its serialized mesh) saves into the
## edited scene. No-op at runtime, where nothing is serialized.
func _persist_generated_street(node: Node) -> void:
	if !Engine.is_editor_hint():
		return
	node.owner = owner if owner != null else self


## Street summary for the reuse path: reports the streets carried over from the
## scene rather than freshly extracted mask paths.
func _reused_street_summary(reused_sources: Array[Node]) -> Dictionary:
	return {
		"mask_street_cell_count": 0,
		"mask_street_skeleton_cell_count": 0,
		"mask_path_count": reused_sources.size(),
		"discarded_mask_path_count": 0,
		"truncated_mask_path_count": 0,
		"generated_source_count": reused_sources.size(),
		"generation_errors": [] as Array[String],
		"streets_reused": true,
	}
