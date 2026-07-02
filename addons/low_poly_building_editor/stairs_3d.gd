@tool
class_name Stairs3D
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

enum NewelPlacement {
	TREAD,
	FLOOR,
}

const StandardRailGeometry := preload(
	"res://addons/low_poly_building_editor/standard_rail_geometry_3d.gd"
)

const GENERATED_META := &"stairs_generated"
const PREVIEW_META := &"building_editor_preview"
const MESH_GEOMETRY_VERSION := 16
const SIDE_WALL_COLLISION_THICKNESS := 0.64
const SIDE_WALL_COLLISION_META := &"stairs_side_wall_collision"
const LEFT_SIDE_COLLISION_SHAPE_NAME := "LeftSideCollisionShape3D"
const RIGHT_SIDE_COLLISION_SHAPE_NAME := "RightSideCollisionShape3D"

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_stairs_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(2.0, 0.0, 4.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export_range(0.05, 20.0, 0.01, "or_greater") var stair_height := 1.2:
	set(value):
		var clamped_value := maxf(value, 0.05)
		if is_equal_approx(stair_height, clamped_value):
			return
		stair_height = clamped_value
		_request_rebuild()

@export_range(1, 64, 1) var step_count := 6:
	set(value):
		var clamped_value := clampi(value, 1, 64)
		if step_count == clamped_value:
			return
		step_count = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var stair_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(stair_thickness, clamped_value):
			return
		stair_thickness = clamped_value
		_request_rebuild()

@export_range(-180.0, 180.0, 1.0) var stair_rotation_degrees := 0.0:
	set(value):
		var normalized_value := _normalize_degrees_static(value)
		if is_equal_approx(stair_rotation_degrees, normalized_value):
			return
		stair_rotation_degrees = normalized_value
		_request_rebuild()

@export var stair_color := Color(0.52, 0.46, 0.38, 1.0):
	set(value):
		if stair_color == value:
			return
		stair_color = value
		_request_rebuild()

@export_group("Rails")
@export var left_rail_enabled := false:
	set(value):
		if left_rail_enabled == value:
			return
		left_rail_enabled = value
		_request_rebuild()

@export var right_rail_enabled := false:
	set(value):
		if right_rail_enabled == value:
			return
		right_rail_enabled = value
		_request_rebuild()

@export_enum("Vertical Rail", "Horizontal Rail", "Glass Panel") var infill_style: int = (
	StandardRailGeometry.RailStyle.VERTICAL
):
	set(value):
		var clamped_value := clampi(
			value,
			StandardRailGeometry.RailStyle.VERTICAL,
			StandardRailGeometry.RailStyle.GLASS_PANEL
		)
		if infill_style == clamped_value:
			return
		infill_style = clamped_value
		_request_rebuild()

@export var lower_newel_enabled := false:
	set(value):
		if lower_newel_enabled == value:
			return
		lower_newel_enabled = value
		_request_rebuild()

@export_enum("Tread", "Floor") var lower_newel_placement: int = NewelPlacement.TREAD:
	set(value):
		var normalized_value := clampi(value, NewelPlacement.TREAD, NewelPlacement.FLOOR)
		if lower_newel_placement == normalized_value:
			return
		lower_newel_placement = normalized_value
		_request_rebuild()

@export var upper_newel_enabled := false:
	set(value):
		if upper_newel_enabled == value:
			return
		upper_newel_enabled = value
		_request_rebuild()

@export_enum("Tread", "Floor") var upper_newel_placement: int = NewelPlacement.TREAD:
	set(value):
		var normalized_value := clampi(value, NewelPlacement.TREAD, NewelPlacement.FLOOR)
		if upper_newel_placement == normalized_value:
			return
		upper_newel_placement = normalized_value
		_request_rebuild()

@export_range(0, 64, 1) var middle_newel_post_count := 0:
	set(value):
		var clamped_value := clampi(value, 0, 64)
		if middle_newel_post_count == clamped_value:
			return
		middle_newel_post_count = clamped_value
		_request_rebuild()

@export_range(0, 64, 1) var infill_count_between_newels := 1:
	set(value):
		var clamped_value := clampi(value, 0, 64)
		if infill_count_between_newels == clamped_value:
			return
		infill_count_between_newels = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var rail_newel_post_thickness := 0.1:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(rail_newel_post_thickness, clamped_value):
			return
		rail_newel_post_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 2.0, 0.01, "or_greater") var rail_edge_margin := 0.15:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(rail_edge_margin, clamped_value):
			return
		rail_edge_margin = clamped_value
		_request_rebuild()

@export_range(0.2, 4.0, 0.01, "or_greater") var rail_height := 1.0:
	set(value):
		var clamped_value := maxf(value, 0.2)
		if is_equal_approx(rail_height, clamped_value):
			return
		rail_height = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var infill_rail_thickness := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(infill_rail_thickness, clamped_value):
			return
		infill_rail_thickness = clamped_value
		_request_rebuild()

@export_range(0.02, 1.0, 0.01, "or_greater") var rail_thickness := 0.1:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(rail_thickness, clamped_value):
			return
		rail_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var rail_lower_height := 0.18:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(rail_lower_height, clamped_value):
			return
		rail_lower_height = clamped_value
		_request_rebuild()

@export var rail_color := Color(0.33, 0.28, 0.22, 1.0):
	set(value):
		if rail_color == value:
			return
		rail_color = value
		_request_rebuild()

@export_group("")
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
		_sync_transform_from_points()
		if _generated_mesh_cache_matches(_stairs_mesh_source_signature()):
			_sync_stairs_material()
			_rebuild_collision_from_cached_mesh()
		else:
			rebuild_stairs_mesh()


func set_stair_corners(new_start: Vector3, new_end: Vector3) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_corners_and_rotation(
	new_start: Vector3,
	new_end: Vector3,
	new_rotation_degrees: float
) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	stair_rotation_degrees = new_rotation_degrees
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_rotation_degrees(new_rotation_degrees: float) -> void:
	var previous_signature := _stairs_mesh_source_signature()
	stair_rotation_degrees = new_rotation_degrees
	if _stairs_mesh_source_signature() == previous_signature:
		return
	_sync_transform_from_points()
	rebuild_stairs_mesh()


func set_stair_rotation_around_center(new_rotation_degrees: float) -> void:
	var size := get_stair_size()
	var center := get_stair_center_point()
	var normalized_rotation := _normalize_degrees_static(new_rotation_degrees)
	var rotated_anchor := center - _rotation_basis_for_degrees(normalized_rotation) * Vector3(
		size.x * 0.5,
		0.0,
		size.y * 0.5
	)
	set_stair_corners_and_rotation(
		rotated_anchor,
		rotated_anchor + Vector3(size.x, 0.0, size.y),
		normalized_rotation
	)


func get_stair_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func get_stair_anchor_point() -> Vector3:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	return Vector3(min_x, start_point.y, min_z)


func get_stair_center_point() -> Vector3:
	var size := get_stair_size()
	return get_stair_anchor_point() + _rotation_basis() * Vector3(size.x * 0.5, 0.0, size.y * 0.5)


func get_stair_bounds_min() -> Vector3:
	return Vector3(0.0, -maxf(stair_thickness, 0.0), 0.0)


func get_stair_bounds_max() -> Vector3:
	var size := get_stair_size()
	return Vector3(size.x, maxf(stair_height, 0.05), size.y)


func get_step_rise() -> float:
	return maxf(stair_height, 0.05) / float(_effective_step_count())


func get_step_run() -> float:
	return get_stair_size().y / float(_effective_step_count())


static func stair_corners_from_base_points(base_start: Vector3, base_end: Vector3, rotation_degrees: float) -> Dictionary:
	var basis := Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))
	var flat_delta := Vector3(base_end.x - base_start.x, 0.0, base_end.z - base_start.z)
	var local_delta := basis.inverse() * flat_delta
	var min_x := minf(0.0, local_delta.x)
	var max_x := maxf(0.0, local_delta.x)
	var min_z := minf(0.0, local_delta.z)
	var max_z := maxf(0.0, local_delta.z)
	var anchor := base_start + basis * Vector3(min_x, 0.0, min_z)
	var size := Vector2(max_x - min_x, max_z - min_z)
	return {
		"start": Vector3(anchor.x, base_start.y, anchor.z),
		"end": Vector3(anchor.x + size.x, base_start.y, anchor.z + size.y),
	}


func rebuild_stairs_mesh(rebuild_collision: bool = true) -> void:
	_begin_generated_mesh_rebuild()
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_append_stair_geometry(size.x, size.y, vertices, normals, colors, indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_stairs_mesh_resource(arrays)
	_sync_stairs_material()
	_record_generated_mesh_cache(_stairs_mesh_source_signature())

	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_stairs_mesh")


func _stairs_mesh_source_signature() -> int:
	return hash([
		MESH_GEOMETRY_VERSION,
		start_point,
		end_point,
		stair_height,
		step_count,
		stair_thickness,
		stair_rotation_degrees,
		stair_color,
		left_rail_enabled,
		right_rail_enabled,
		infill_style,
		lower_newel_enabled,
		lower_newel_placement,
		upper_newel_enabled,
		upper_newel_placement,
		middle_newel_post_count,
		infill_count_between_newels,
		rail_newel_post_thickness,
		rail_edge_margin,
		rail_height,
		infill_rail_thickness,
		rail_thickness,
		rail_lower_height,
		rail_color,
	])


func _rebuild_collision_from_cached_mesh() -> void:
	_clear_generated_children()
	if generate_collision:
		_add_collision_body(_cached_mesh_vertices(), _cached_mesh_indices())


func _sync_transform_from_points() -> void:
	transform = Transform3D(_rotation_basis(), get_stair_anchor_point())


func _append_stair_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps := _effective_step_count()
	var height := maxf(stair_height, 0.05)
	var bottom_y := -maxf(stair_thickness, 0.0)
	var tread_depth := depth / float(steps)
	var rise := height / float(steps)

	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y0 := rise * float(step_index)
		var y1 := rise * float(step_index + 1)
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			Vector3(0.0, y1, z0),
			Vector3(0.0, y1, z1),
			Vector3(width, y1, z1),
			Vector3(width, y1, z0),
			Vector3.UP
		)
		_append_quad(
			vertices,
			normals,
			colors,
			indices,
			Vector3(0.0, y0, z0),
			Vector3(0.0, y1, z0),
			Vector3(width, y1, z0),
			Vector3(width, y0, z0),
			Vector3.FORWARD
		)

	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		Vector3(0.0, bottom_y, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, bottom_y, 0.0),
		Vector3.FORWARD
	)
	_append_quad(
		vertices,
		normals,
		colors,
		indices,
		Vector3(0.0, bottom_y, depth),
		Vector3(width, bottom_y, depth),
		Vector3(width, height, depth),
		Vector3(0.0, height, depth),
		Vector3.BACK
	)
	_append_side_strips(
		vertices, normals, colors, indices,
		depth, height, bottom_y, steps, 0.0, Vector3.LEFT
	)
	_append_side_strips(
		vertices, normals, colors, indices,
		depth, height, bottom_y, steps, width, Vector3.RIGHT
	)

	_append_rail_geometry(width, depth, height, vertices, normals, colors, indices)


func _append_rail_geometry(
	width: float,
	depth: float,
	height: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if !left_rail_enabled and !right_rail_enabled:
		return
	var steps := _effective_step_count()
	# One post per tread, with optional thicker lower/upper and evenly spaced
	# middle newels.
	# Tread placement replaces the terminal regular post; Floor placement
	# retains it and adds a newel at the corresponding stair-run endpoint.
	var post_layout := _build_rail_post_layout(depth, height, steps)
	var post_positions: PackedFloat32Array = post_layout["positions"]
	var post_base_heights: PackedFloat32Array = post_layout["base_heights"]
	var post_thicknesses: PackedFloat32Array = post_layout["thicknesses"]
	var post_top_heights: PackedFloat32Array = post_layout["top_heights"]
	var post_base_follows_rise: PackedByteArray = post_layout["base_follows_rise"]
	var lower_horizontal_end := float(post_layout["lower_horizontal_end"])
	var upper_horizontal_start := float(post_layout["upper_horizontal_start"])
	var handrail_minimum_run := float(post_layout["handrail_minimum_run"])
	var handrail_maximum_run := float(post_layout["handrail_maximum_run"])
	# Inset each rail from its side edge instead of straddling the exact
	# footprint boundary, clamped so opposing margins cannot cross.
	var margin := minf(rail_edge_margin, width * 0.45)
	if left_rail_enabled:
		StandardRailGeometry.append_rail(
			vertices,
			normals,
			colors,
			indices,
			Vector3(margin, 0.0, 0.0),
			Vector3.BACK,
			Vector3.UP,
			Vector3.RIGHT,
			depth,
			height,
			rail_height,
			1.0, # post_spacing is unused: post_positions overrides it below.
			_clamped_infill_rail_size(),
			rail_thickness,
			rail_lower_height,
			rail_color,
			post_positions,
			post_base_heights,
			post_thicknesses,
			post_top_heights,
			lower_horizontal_end,
			upper_horizontal_start,
			handrail_minimum_run,
			handrail_maximum_run,
			infill_style,
			infill_count_between_newels,
			post_base_follows_rise
		)
	if right_rail_enabled:
		StandardRailGeometry.append_rail(
			vertices,
			normals,
			colors,
			indices,
			Vector3(width - margin, 0.0, 0.0),
			Vector3.BACK,
			Vector3.UP,
			Vector3.RIGHT,
			depth,
			height,
			rail_height,
			1.0, # post_spacing is unused: post_positions overrides it below.
			_clamped_infill_rail_size(),
			rail_thickness,
			rail_lower_height,
			rail_color,
			post_positions,
			post_base_heights,
			post_thicknesses,
			post_top_heights,
			lower_horizontal_end,
			upper_horizontal_start,
			handrail_minimum_run,
			handrail_maximum_run,
			infill_style,
			infill_count_between_newels,
			post_base_follows_rise
		)


func _get_rail_post_layout() -> Dictionary:
	var size := get_stair_size()
	return _build_rail_post_layout(
		size.y,
		maxf(stair_height, 0.05),
		_effective_step_count()
	)


func _handrail_width() -> float:
	return minf(
		maxf(rail_thickness, 0.02),
		maxf(rail_height, 0.2) * 0.5
	)


func _clamped_infill_rail_size() -> float:
	# Like newels, infill geometry never exceeds the handrail cross-section.
	return minf(maxf(infill_rail_thickness, 0.02), _handrail_width())


func _build_rail_post_layout(depth: float, height: float, steps: int) -> Dictionary:
	var positions := StandardRailGeometry.tread_mid_post_positions(depth, steps)
	var base_heights := StandardRailGeometry.tread_mid_post_base_heights(height, steps)
	var infill_size := _clamped_infill_rail_size()
	var thicknesses := PackedFloat32Array()
	var newel_flags := PackedByteArray()
	for _index in range(positions.size()):
		thicknesses.append(infill_size)
		newel_flags.append(0)

	# A newel stays no wider than the handrail so its open top is completely
	# covered by the welded handrail underside.
	var newel_size := minf(maxf(rail_newel_post_thickness, 0.02), _handrail_width())
	var post_spacing := depth / float(maxi(steps, 1))
	var lower_newel_index := -1
	var upper_newel_index := -1

	for tread_index in _middle_newel_tread_indices(steps):
		thicknesses[tread_index] = newel_size
		newel_flags[tread_index] = 1

	if lower_newel_enabled and !positions.is_empty():
		if lower_newel_placement == NewelPlacement.TREAD:
			thicknesses[0] = newel_size
			newel_flags[0] = 1
			lower_newel_index = 0
		else:
			# Continue the regular tread-post cadence by one full interval.
			var floor_positions := PackedFloat32Array([positions[0] - post_spacing])
			floor_positions.append_array(positions)
			positions = floor_positions
			var floor_heights := PackedFloat32Array([0.0])
			floor_heights.append_array(base_heights)
			base_heights = floor_heights
			var floor_thicknesses := PackedFloat32Array([newel_size])
			floor_thicknesses.append_array(thicknesses)
			thicknesses = floor_thicknesses
			var floor_newel_flags := PackedByteArray([1])
			floor_newel_flags.append_array(newel_flags)
			newel_flags = floor_newel_flags
			lower_newel_index = 0

	if upper_newel_enabled and !positions.is_empty():
		if upper_newel_placement == NewelPlacement.TREAD:
			var last_tread_index := positions.size() - 1
			thicknesses[last_tread_index] = newel_size
			newel_flags[last_tread_index] = 1
			upper_newel_index = last_tread_index
		else:
			# Continue the regular tread-post cadence by one full interval.
			positions.append(positions[positions.size() - 1] + post_spacing)
			base_heights.append(height)
			thicknesses.append(newel_size)
			newel_flags.append(1)
			upper_newel_index = positions.size() - 1

	var lower_newel_position := NAN
	var upper_newel_position := NAN
	if lower_newel_index >= 0:
		lower_newel_position = positions[lower_newel_index]
	if upper_newel_index >= 0:
		upper_newel_position = positions[upper_newel_index]
	var counted_layout := StandardRailGeometry.apply_infill_count_between_newels(
		positions,
		base_heights,
		thicknesses,
		newel_flags,
		(
			infill_count_between_newels
			if infill_style == StandardRailGeometry.RailStyle.VERTICAL
			else 0
		),
		infill_size
	)
	positions = counted_layout["positions"]
	base_heights = counted_layout["base_heights"]
	thicknesses = counted_layout["thicknesses"]
	newel_flags = counted_layout["newel_flags"]
	lower_newel_index = _find_post_position(positions, lower_newel_position)
	upper_newel_index = _find_post_position(positions, upper_newel_position)
	var lower_newel_is_floor := (
		lower_newel_enabled
		and lower_newel_placement == NewelPlacement.FLOOR
	)
	var upper_newel_is_floor := (
		upper_newel_enabled
		and upper_newel_placement == NewelPlacement.FLOOR
	)

	var bar_size := minf(maxf(rail_thickness, 0.02), maxf(rail_height, 0.2) * 0.5)
	var handrail_bottom := maxf(rail_height, 0.2) - bar_size
	var has_base_rail := StandardRailGeometry.has_lower_rail(
		rail_height,
		rail_thickness,
		rail_lower_height
	)
	var safe_depth := maxf(depth, 0.001)
	var base_follows_rise := PackedByteArray()
	base_follows_rise.resize(positions.size())
	if has_base_rail:
		StandardRailGeometry.redistribute_infills_between_newels(
			positions,
			thicknesses,
			newel_flags
		)
		var base_rail_top := StandardRailGeometry.lower_rail_top_height(
			rail_height,
			rail_thickness,
			rail_lower_height
		)
		for index in range(positions.size()):
			if newel_flags[index] != 0:
				continue
			base_heights[index] = (
				base_rail_top
				+ height * (positions[index] / safe_depth)
			)
			# The base-rail top is raked, so this infill's bottom corners
			# must shear along the run instead of staying flat.
			base_follows_rise[index] = 1
	else:
		var tread_depth := depth / float(maxi(steps, 1))
		var rise_per_tread := height / float(maxi(steps, 1))
		for index in range(positions.size()):
			if newel_flags[index] != 0:
				continue
			var tread_index := clampi(
				floori(positions[index] / maxf(tread_depth, 0.001)),
				0,
				steps - 1
			)
			base_heights[index] = rise_per_tread * float(tread_index + 1)

	var lower_horizontal_end := -INF
	var upper_horizontal_start := INF
	if lower_newel_index >= 0:
		if lower_newel_is_floor:
			lower_horizontal_end = 0.0
		else:
			lower_horizontal_end = (
				positions[lower_newel_index]
				+ thicknesses[lower_newel_index] * 0.5
			)
	if upper_newel_index >= 0:
		if upper_newel_is_floor:
			upper_horizontal_start = depth
		else:
			upper_horizontal_start = (
				positions[upper_newel_index]
				- thicknesses[upper_newel_index] * 0.5
			)
	if lower_horizontal_end > upper_horizontal_start:
		var shared_transition := (lower_horizontal_end + upper_horizontal_start) * 0.5
		lower_horizontal_end = shared_transition
		upper_horizontal_start = shared_transition

	var top_heights := PackedFloat32Array()
	top_heights.resize(positions.size())
	for index in range(top_heights.size()):
		top_heights[index] = NAN
	if lower_newel_index >= 0:
		top_heights[lower_newel_index] = (
			handrail_bottom
			+ height * (lower_horizontal_end / safe_depth)
		)
	if upper_newel_index >= 0:
		top_heights[upper_newel_index] = (
			handrail_bottom
			+ height * (upper_horizontal_start / safe_depth)
		)

	var handrail_minimum_run := NAN
	var handrail_maximum_run := NAN
	# Distributed newels only create welded openings in the continuous raked
	# handrail. Explicit lower/upper newels alone may terminate its run.
	if lower_newel_index >= 0:
		handrail_minimum_run = (
			positions[lower_newel_index]
			- thicknesses[lower_newel_index] * 0.5
		)
	if upper_newel_index >= 0:
		handrail_maximum_run = (
			positions[upper_newel_index]
			+ thicknesses[upper_newel_index] * 0.5
		)

	return {
		"positions": positions,
		"base_heights": base_heights,
		"thicknesses": thicknesses,
		"newel_flags": newel_flags,
		"top_heights": top_heights,
		"base_follows_rise": base_follows_rise,
		"lower_horizontal_end": lower_horizontal_end,
		"upper_horizontal_start": upper_horizontal_start,
		"handrail_minimum_run": handrail_minimum_run,
		"handrail_maximum_run": handrail_maximum_run,
	}


func _find_post_position(positions: PackedFloat32Array, target: float) -> int:
	if is_nan(target):
		return -1
	for index in range(positions.size()):
		if is_equal_approx(positions[index], target):
			return index
	return -1


func _middle_newel_tread_indices(steps: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var has_lower_terminal := lower_newel_enabled
	var has_upper_terminal := upper_newel_enabled
	var lower_bound := (
		-1
		if has_lower_terminal and lower_newel_placement == NewelPlacement.FLOOR
		else 0
	)
	var upper_bound := (
		steps
		if has_upper_terminal and upper_newel_placement == NewelPlacement.FLOOR
		else steps - 1
	)
	var first_available_tread := (
		1
		if has_lower_terminal and lower_newel_placement == NewelPlacement.TREAD
		else 0
	)
	var last_available_tread := (
		steps - 2
		if has_upper_terminal and upper_newel_placement == NewelPlacement.TREAD
		else steps - 1
	)
	var available_middle_treads := maxi(
		last_available_tread - first_available_tread + 1,
		0
	)
	var explicit_terminal_count := (
		(1 if has_lower_terminal else 0)
		+ (1 if has_upper_terminal else 0)
	)
	var count := clampi(
		middle_newel_post_count - explicit_terminal_count,
		0,
		available_middle_treads
	)
	if count <= 0:
		return indices

	var lower_padding := 1 if has_lower_terminal else 0
	var upper_padding := 1 if has_upper_terminal else 0
	var interval_count := count - 1 + lower_padding + upper_padding
	if interval_count <= 0:
		indices.append(first_available_tread)
		return indices

	# Divide the actual lower/upper newel interval into equal spans. Missing
	# terminals make the first/last distributed newels occupy the endpoint
	# tread; explicit terminals bound the interval without being duplicated.
	for index in range(count):
		var distributed_index := roundi(
			lerpf(
				float(lower_bound),
				float(upper_bound),
				float(index + lower_padding) / float(interval_count)
			)
		)
		indices.append(clampi(
			distributed_index,
			first_available_tread,
			last_available_tread
		))
	return indices


func _append_side_strips(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	depth: float,
	height: float,
	bottom_y: float,
	steps: int,
	x: float,
	normal: Vector3
) -> void:
	var base := vertices.size()
	var tread_depth := depth / float(steps)
	var rise := height / float(steps)

	# Give every tread-width strip its own bottom endpoints. The old single
	# outline triangulation had only two bottom corners, forcing ear clipping
	# to fan long, needle-like triangles across the full stair run.
	for boundary_index in range(steps + 1):
		vertices.append(Vector3(
			x,
			bottom_y,
			tread_depth * float(boundary_index)
		))
		normals.append(normal)
		colors.append(stair_color)

	var top_base := vertices.size()
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y1 := rise * float(step_index + 1)
		vertices.append(Vector3(x, y1, z0))
		normals.append(normal)
		colors.append(stair_color)
		vertices.append(Vector3(x, y1, z1))
		normals.append(normal)
		colors.append(stair_color)

	for step_index in range(steps):
		var bottom_left := base + step_index
		var bottom_right := bottom_left + 1
		var top_left := top_base + step_index * 2
		var top_right := top_left + 1
		_append_oriented_triangle(
			vertices, indices, normal,
			bottom_left, top_left, top_right
		)
		_append_oriented_triangle(
			vertices, indices, normal,
			bottom_left, top_right, bottom_right
		)


func _append_oriented_triangle(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	normal: Vector3,
	first: int,
	second: int,
	third: int
) -> void:
	var winding_normal := (
		vertices[second] - vertices[first]
	).cross(
		vertices[third] - vertices[first]
	).normalized()
	if winding_normal.dot(normal) > 0.0:
		indices.append_array(PackedInt32Array([first, third, second]))
	else:
		indices.append_array(PackedInt32Array([first, second, third]))


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
		colors.append(stair_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _update_stairs_mesh_resource(arrays: Array) -> void:
	_replace_generated_mesh_surface(arrays)


func _stairs_material_transparency(color: Color) -> BaseMaterial3D.Transparency:
	# The glass-panel rail infill carries its translucency in vertex alpha
	# inside the same surface as the opaque steps, posts, and handrail. Plain
	# alpha blending would move the whole stairs mesh into the no-depth-write
	# transparent pass and break depth sorting, so the glass style uses an
	# opaque depth pre-pass: opaque fragments keep correct depth while the
	# panel still blends.
	if (
		(left_rail_enabled or right_rail_enabled)
		and infill_style == StandardRailGeometry.RailStyle.GLASS_PANEL
	):
		return BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	if color.a < 0.99:
		return BaseMaterial3D.TRANSPARENCY_ALPHA
	return BaseMaterial3D.TRANSPARENCY_DISABLED


func _sync_stairs_material() -> void:
	var material := _scene_local_material_for_write(
		material_override as StandardMaterial3D
	)
	if material == null:
		material_override = _build_stairs_material(stair_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, stair_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = _stairs_material_transparency(stair_color)


func _build_stairs_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = _stairs_material_transparency(color)
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

	var body := StaticBody3D.new()
	body.name = "StairsCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	_add_side_wall_collision_shapes(body)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null
		for child in body.get_children():
			if child != collision_shape:
				child.owner = null


func _add_side_wall_collision_shapes(body: StaticBody3D) -> void:
	var size := get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return
	var bottom_y := -maxf(stair_thickness, 0.0)
	var side_wall_thickness := minf(SIDE_WALL_COLLISION_THICKNESS, size.x * 0.45)
	var steps := _effective_step_count()
	var tread_depth := size.y / float(steps)
	var rise := maxf(stair_height, 0.05) / float(steps)
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var top_y := rise * float(step_index + 1)
		var collision_height := top_y - bottom_y
		var collision_center_y := bottom_y + collision_height * 0.5
		var collision_center_z := (z0 + z1) * 0.5
		var shape_suffix := "" if step_index == 0 else "_%d" % (step_index + 1)
		_add_side_wall_collision_shape(
			body,
			LEFT_SIDE_COLLISION_SHAPE_NAME + shape_suffix,
			Vector3(
				side_wall_thickness * 0.5,
				collision_center_y,
				collision_center_z
			),
			Vector3(side_wall_thickness, collision_height, tread_depth)
		)
		_add_side_wall_collision_shape(
			body,
			RIGHT_SIDE_COLLISION_SHAPE_NAME + shape_suffix,
			Vector3(
				size.x - side_wall_thickness * 0.5,
				collision_center_y,
				collision_center_z
			),
			Vector3(side_wall_thickness, collision_height, tread_depth)
		)


func _add_side_wall_collision_shape(
	body: StaticBody3D,
	shape_name: String,
	shape_position: Vector3,
	shape_size: Vector3
) -> void:
	var side_shape := CollisionShape3D.new()
	side_shape.name = shape_name
	side_shape.set_meta(SIDE_WALL_COLLISION_META, true)
	var box := BoxShape3D.new()
	box.size = shape_size
	side_shape.shape = box
	side_shape.position = shape_position
	body.add_child(side_shape)


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()


func _effective_step_count() -> int:
	return clampi(step_count, 1, 64)


func _rotation_basis() -> Basis:
	return _rotation_basis_for_degrees(stair_rotation_degrees)


static func _rotation_basis_for_degrees(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))


static func _normalize_degrees_static(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized
