@tool
extends "res://addons/low_poly_building_editor/building_mesh_3d.gd"

enum NewelPlacement {
	TREAD,
	FLOOR,
}

enum TreadStyle {
	CLOSED,
	OPEN,
	NOSING,
}

enum TurnDirection {
	LEFT,
	RIGHT,
}

enum WinderTurn {
	TURN_90,
	TURN_180,
}

enum SegmentKind {
	SEGMENT_FLIGHT,
	SEGMENT_LANDING,
	SEGMENT_WINDER,
	SEGMENT_SPIRAL,
}

enum RailRunKind {
	RAIL_RUN_FLIGHT,
	RAIL_RUN_PLAIN,
}

const StandardRailGeometry := preload(
	"res://addons/low_poly_building_editor/standard_rail_geometry_3d.gd"
)

const GENERATED_META := &"stairs_generated"
const PREVIEW_META := &"building_editor_preview"
const MESH_GEOMETRY_VERSION := 26
const RAIL_SIDE_LEFT := 0
const RAIL_SIDE_RIGHT := 1
const WINDER_TREADS_90 := 3
const WINDER_TREADS_180 := 6
const SPIRAL_COLUMN_SIDES := 8
const SPIRAL_MAX_TREAD_ANGLE_DEGREES := 45.0
const SPIRAL_RAIL_MAX_SEGMENT_ANGLE_DEGREES := 7.5
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

# Closed keeps the solid stepped mass; Open floats individual tread slabs with
# no risers or underside; Nosing keeps the closed mass and overhangs each tread
# past the riser below by nosing_depth. Winder fans and spiral treads have no
# nosing variant and treat Nosing as Closed.
@export_enum("Closed", "Open", "Nosing") var tread_style: int = TreadStyle.CLOSED:
	set(value):
		var clamped_value := clampi(value, TreadStyle.CLOSED, TreadStyle.NOSING)
		if tread_style == clamped_value:
			return
		tread_style = clamped_value
		_request_rebuild()

@export_range(0.0, 1.0, 0.01, "or_greater") var nosing_depth := 0.08:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(nosing_depth, clamped_value):
			return
		nosing_depth = clamped_value
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
	return maxf(stair_height, 0.05) / float(_total_rising_step_count())


func get_step_run() -> float:
	return get_stair_size().y / float(_effective_step_count())


func _total_rising_step_count() -> int:
	return _effective_step_count()


func configure_stair_layout(
	_turn_direction: int,
	_winder_turn: int,
	_flight_width: float,
	_spiral_turn_degrees: float
) -> void:
	pass


func _layout_mesh_source_signature_values() -> Array:
	var script := get_script() as Script
	return [script.resource_path if script != null else ""]


func _layout_turn_direction() -> int:
	return TurnDirection.RIGHT


func _layout_winder_turn() -> int:
	return WinderTurn.TURN_90


func _layout_flight_width() -> float:
	return 1.2


func _layout_spiral_turn_degrees() -> float:
	return 360.0


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
	_append_stair_layout_geometry(
		size.x, size.y, vertices, normals, colors, indices
	)
	if vertices.is_empty():
		mesh = null
		return

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
	var signature: Array = [
		MESH_GEOMETRY_VERSION,
		start_point,
		end_point,
		stair_height,
		step_count,
		stair_thickness,
		tread_style,
		nosing_depth,
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
	]
	signature.append_array(_layout_mesh_source_signature_values())
	return hash(signature)


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
	var identity_seg := _make_flight_segment(
		Vector3.ZERO, Vector3.BACK, width, depth, steps, rise
	)

	if tread_style == TreadStyle.OPEN:
		_append_open_flight_treads(identity_seg, vertices, normals, colors, indices)
		_append_rail_geometry(width, depth, height, vertices, normals, colors, indices)
		return

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
	_append_flight_nosing_lips(identity_seg, vertices, normals, colors, indices)

	_append_rail_geometry(width, depth, height, vertices, normals, colors, indices)


func _append_stair_layout_geometry(
	_width: float,
	_depth: float,
	_vertices: PackedVector3Array,
	_normals: PackedVector3Array,
	_colors: PackedColorArray,
	_indices: PackedInt32Array
) -> void:
	pass


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
	var post_layout := _build_rail_post_layout(
		depth,
		height,
		steps,
		lower_newel_enabled,
		upper_newel_enabled,
		middle_newel_post_count,
		lower_newel_placement,
		upper_newel_placement
	)
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
		_effective_step_count(),
		lower_newel_enabled,
		upper_newel_enabled,
		middle_newel_post_count,
		lower_newel_placement,
		upper_newel_placement
	)


func _handrail_width() -> float:
	return minf(
		maxf(rail_thickness, 0.02),
		maxf(rail_height, 0.2) * 0.5
	)


func _clamped_infill_rail_size() -> float:
	# Like newels, infill geometry never exceeds the handrail cross-section.
	return minf(maxf(infill_rail_thickness, 0.02), _handrail_width())


func _build_rail_post_layout(
	depth: float,
	height: float,
	steps: int,
	use_lower_newel: bool,
	use_upper_newel: bool,
	middle_count: int,
	lower_placement: int,
	upper_placement: int,
	force_first_tread_newel: bool = false,
	force_last_tread_newel: bool = false
) -> Dictionary:
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

	for tread_index in _middle_newel_tread_indices(
		steps, use_lower_newel, use_upper_newel, middle_count,
		lower_placement, upper_placement
	):
		thicknesses[tread_index] = newel_size
		newel_flags[tread_index] = 1

	# Junction newels shared with a layout transition behave like distributed
	# newels: tread-mid position, raked top, and no handrail termination, so
	# the raked handrail runs continuously across the transition boundary.
	if force_first_tread_newel and !positions.is_empty() and newel_flags[0] == 0:
		thicknesses[0] = newel_size
		newel_flags[0] = 1
	if force_last_tread_newel and !positions.is_empty():
		var forced_last_index := positions.size() - 1
		if newel_flags[forced_last_index] == 0:
			thicknesses[forced_last_index] = newel_size
			newel_flags[forced_last_index] = 1

	if use_lower_newel and !positions.is_empty():
		if lower_placement == NewelPlacement.TREAD:
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

	if use_upper_newel and !positions.is_empty():
		if upper_placement == NewelPlacement.TREAD:
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
		use_lower_newel
		and lower_placement == NewelPlacement.FLOOR
	)
	var upper_newel_is_floor := (
		use_upper_newel
		and upper_placement == NewelPlacement.FLOOR
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


func _middle_newel_tread_indices(
	steps: int,
	use_lower_newel: bool,
	use_upper_newel: bool,
	middle_count: int,
	lower_placement: int,
	upper_placement: int
) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var has_lower_terminal := use_lower_newel
	var has_upper_terminal := use_upper_newel
	var lower_bound := (
		-1
		if has_lower_terminal and lower_placement == NewelPlacement.FLOOR
		else 0
	)
	var upper_bound := (
		steps
		if has_upper_terminal and upper_placement == NewelPlacement.FLOOR
		else steps - 1
	)
	var first_available_tread := (
		1
		if has_lower_terminal and lower_placement == NewelPlacement.TREAD
		else 0
	)
	var last_available_tread := (
		steps - 2
		if has_upper_terminal and upper_placement == NewelPlacement.TREAD
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
		middle_count - explicit_terminal_count,
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
	shape_size: Vector3,
	shape_basis := Basis.IDENTITY
) -> void:
	var side_shape := CollisionShape3D.new()
	side_shape.name = shape_name
	side_shape.set_meta(SIDE_WALL_COLLISION_META, true)
	var box := BoxShape3D.new()
	box.size = shape_size
	side_shape.shape = box
	side_shape.transform = Transform3D(shape_basis, shape_position)
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


func _allocate_layout_steps(
	run_lengths: PackedFloat32Array,
	winder_treads: int
) -> Dictionary:
	var flight_count := run_lengths.size()
	var flight_budget := maxi(_effective_step_count() - winder_treads, flight_count)
	var counts := PackedInt32Array()
	counts.resize(flight_count)
	counts.fill(1)
	var extra := flight_budget - flight_count
	var total_run := 0.0
	for run_length in run_lengths:
		total_run += maxf(run_length, 0.001)
	var assigned := 0
	var remainders: Array[Dictionary] = []
	for index in range(flight_count):
		var share := extra * maxf(run_lengths[index], 0.001) / total_run
		var base := int(floorf(share))
		counts[index] += base
		assigned += base
		remainders.append({"index": index, "fraction": share - float(base)})
	remainders.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["fraction"]) > float(b["fraction"])
	)
	for pass_index in range(extra - assigned):
		counts[int(remainders[pass_index % flight_count]["index"])] += 1
	return {
		"flights": counts,
		"winder": winder_treads,
		"total": flight_budget + winder_treads,
	}


func _distribute_middle_newels(flight_steps: PackedInt32Array) -> PackedInt32Array:
	var shares := PackedInt32Array()
	shares.resize(flight_steps.size())
	var total := 0
	for steps in flight_steps:
		total += steps
	if total <= 0 or middle_newel_post_count <= 0:
		shares.fill(0)
		return shares
	for index in range(flight_steps.size()):
		shares[index] = int(roundf(
			float(middle_newel_post_count) * float(flight_steps[index]) / float(total)
		))
	return shares


func _make_flight_segment(
	origin: Vector3,
	run_dir: Vector3,
	width: float,
	run_length: float,
	steps: int,
	rise: float
) -> Dictionary:
	return {
		"kind": SegmentKind.SEGMENT_FLIGHT,
		"origin": origin,
		"run_axis": run_dir,
		"width_axis": Vector3.UP.cross(run_dir).normalized(),
		"width": width,
		"run": run_length,
		"steps": maxi(steps, 1),
		"rise": rise,
	}


func _make_landing_segment(
	origin: Vector3,
	run_dir: Vector3,
	width: float,
	run_length: float
) -> Dictionary:
	return {
		"kind": SegmentKind.SEGMENT_LANDING,
		"origin": origin,
		"run_axis": run_dir,
		"width_axis": Vector3.UP.cross(run_dir).normalized(),
		"width": width,
		"run": run_length,
		"steps": 0,
		"rise": 0.0,
	}


func _make_winder_segment(
	origin: Vector3,
	run_dir: Vector3,
	width: float,
	run_length: float,
	steps: int,
	rise: float,
	pivot: Vector2,
	perimeter: PackedVector2Array,
	extra_walls: Array[Dictionary]
) -> Dictionary:
	return {
		"kind": SegmentKind.SEGMENT_WINDER,
		"origin": origin,
		"run_axis": run_dir,
		"width_axis": Vector3.UP.cross(run_dir).normalized(),
		"width": width,
		"run": run_length,
		"steps": maxi(steps, 1),
		"rise": rise,
		"pivot": pivot,
		"perimeter": perimeter,
		"extra_walls": extra_walls,
	}


func _make_flight_rail_run(
	side: int,
	origin: Vector3,
	run_dir: Vector3,
	length: float,
	rise: float,
	steps: int,
	is_first: bool,
	is_last: bool,
	middle_newels: int
) -> Dictionary:
	return {
		"kind": RailRunKind.RAIL_RUN_FLIGHT,
		"side": side,
		"origin": origin,
		"run_dir": run_dir,
		"length": length,
		"rise": rise,
		"steps": maxi(steps, 1),
		"first": is_first,
		"last": is_last,
		"middle_newels": middle_newels,
	}


func _make_plain_rail_run(
	side: int,
	origin: Vector3,
	run_dir: Vector3,
	length: float,
	rise: float,
	post_spacing: float,
	post_positions := PackedFloat32Array(),
	post_base_heights := PackedFloat32Array(),
	post_thicknesses := PackedFloat32Array(),
	post_base_follows_rise := PackedByteArray(),
	minimum_run_override := NAN,
	maximum_run_override := NAN,
	post_top_heights := PackedFloat32Array(),
	lower_horizontal_end := -INF,
	upper_horizontal_start := INF,
	post_newel_flags := PackedByteArray()
) -> Dictionary:
	return {
		"kind": RailRunKind.RAIL_RUN_PLAIN,
		"side": side,
		"origin": origin,
		"run_dir": run_dir,
		"length": length,
		"rise": rise,
		"post_spacing": post_spacing,
		"post_positions": post_positions,
		"post_base_heights": post_base_heights,
		"post_thicknesses": post_thicknesses,
		"post_base_follows_rise": post_base_follows_rise,
		"minimum_run_override": minimum_run_override,
		"maximum_run_override": maximum_run_override,
		"post_top_heights": post_top_heights,
		"lower_horizontal_end": lower_horizontal_end,
		"upper_horizontal_start": upper_horizontal_start,
		"post_newel_flags": post_newel_flags,
	}


func _clamped_newel_size() -> float:
	# Same clamp as flight newels: never wider than the handrail so the welded
	# handrail underside fully covers the post's open top.
	return minf(maxf(rail_newel_post_thickness, 0.02), _handrail_width())



func _winder_surface_height(
	path_position: float,
	path_length: float,
	winder_treads: int,
	rise: float
) -> float:
	# Walking-surface height under a path point: the top of the winder tread
	# containing it, with exact tread boundaries resolving to the lower tread.
	if winder_treads <= 0 or path_length <= 0.001:
		return 0.0
	var tread_ratio := path_position * float(winder_treads) / path_length
	return rise * clampf(ceilf(tread_ratio - 0.0001), 0.0, float(winder_treads))


func _add_raked_path_rail_runs(
	rail_runs: Array[Dictionary],
	side: int,
	waypoints: Array[Vector2],
	start_height: float,
	total_rise: float,
	winder_treads: int,
	rise: float,
	post_spacing: float
) -> void:
	var total_length := 0.0
	for index in range(waypoints.size() - 1):
		total_length += waypoints[index].distance_to(waypoints[index + 1])
	if total_length <= 0.001:
		return
	var newel_size := _clamped_newel_size()
	var infill_size := _clamped_infill_rail_size()
	# At each interior corner both adjacent legs extend their bars past the
	# corner point by half the handrail bar thickness, so the handrail, base
	# rail, and panel outer faces close flush around the corner instead of
	# leaving a sliver where neither leg's cross-section reaches.
	var half_bar := minf(
		maxf(rail_thickness, 0.02),
		maxf(rail_height, 0.2) * 0.5
	) * 0.5
	# The same vertical-rail rule as flights: exactly
	# `infill_count_between_newels` vertical infills per newel span for the
	# Vertical style, and none for Horizontal/Glass (their bars/panel fill the
	# span instead). Each leg is one span bounded by its shared inflection
	# newels.
	var span_infill_count := (
		clampi(infill_count_between_newels, 0, 64)
		if infill_style == StandardRailGeometry.RailStyle.VERTICAL
		else 0
	)
	var has_base_rail := StandardRailGeometry.has_lower_rail(
		rail_height, rail_thickness, rail_lower_height
	)
	var base_rail_top := StandardRailGeometry.lower_rail_top_height(
		rail_height, rail_thickness, rail_lower_height
	)
	var traversed := 0.0
	for index in range(waypoints.size() - 1):
		var from_point := waypoints[index]
		var to_point := waypoints[index + 1]
		var length := from_point.distance_to(to_point)
		if length <= 0.001:
			continue
		var leg_rise := total_rise * length / total_length
		var rise_before := total_rise * traversed / total_length
		var run_dir := Vector3(
			to_point.x - from_point.x,
			0.0,
			to_point.y - from_point.y
		).normalized()
		var is_first_leg := traversed <= 0.001
		var is_last_leg := traversed + length >= total_length - 0.001
		var positions := PackedFloat32Array()
		var base_heights := PackedFloat32Array()
		var thicknesses := PackedFloat32Array()
		var follows_rise := PackedByteArray()
		# Infills between the bounding newel faces with equal clear gaps,
		# matching redistribute_infills_between_newels(). With a base rail they
		# mount on its top with bottoms sheared along the leg's rake; without
		# one they rebase onto the surface beneath (winder tread top, landing
		# floor, or the leg's base diagonal). Legs too short for the requested
		# infills carry only their shared newels. Junction-side spans start at
		# the leg boundary, since the flight's tread-mid junction newel sits
		# beyond it.
		var clear_start := 0.0 if is_first_leg else newel_size * 0.5
		var clear_end := length if is_last_leg else length - newel_size * 0.5
		var infill_clear_total := (
			clear_end - clear_start - infill_size * float(span_infill_count)
		)
		if span_infill_count > 0 and infill_clear_total >= 0.0:
			var clear_gap := infill_clear_total / float(span_infill_count + 1)
			for infill_index in range(span_infill_count):
				var center := (
					clear_start
					+ clear_gap * float(infill_index + 1)
					+ infill_size * (float(infill_index) + 0.5)
				)
				positions.append(center)
				thicknesses.append(infill_size)
				if has_base_rail:
					base_heights.append(base_rail_top + leg_rise * center / length)
					follows_rise.append(1)
				elif winder_treads > 0:
					base_heights.append(_winder_surface_height(
						traversed + center, total_length, winder_treads, rise
					) - rise_before)
					follows_rise.append(0)
				else:
					base_heights.append(leg_rise * center / length)
					follows_rise.append(0)
		# One shared newel per interior corner between two legs, owned by the
		# leg that starts there, so adjacent legs never stack duplicate posts.
		# The path's junctions with the adjacent flight rails carry no leg
		# posts at all: the flights own tread-mid junction newels there, and
		# this leg's bars are cut flush at the boundary where the flight's
		# bars end at the identical height, keeping the rail continuous.
		if !is_first_leg:
			positions.append(0.0)
			base_heights.append(
				_winder_surface_height(traversed, total_length, winder_treads, rise)
				- rise_before
			)
			thicknesses.append(newel_size)
			follows_rise.append(0)
		var minimum_override := 0.0 if is_first_leg else -half_bar
		var maximum_override := length if is_last_leg else length + half_bar
		rail_runs.append(_make_plain_rail_run(
			side,
			Vector3(from_point.x, start_height + rise_before, from_point.y),
			run_dir,
			length,
			leg_rise,
			post_spacing,
			positions,
			base_heights,
			thicknesses,
			follows_rise,
			minimum_override,
			maximum_override
		))
		traversed += length


func _spiral_direction(theta: float, turn_sign: float) -> Vector2:
	# Radial unit direction at spiral angle theta; theta 0 points toward the
	# footprint front (-Z), positive turn_sign turns toward +X (right turn).
	return Vector2(sin(theta) * turn_sign, -cos(theta))


func _spiral_tangent(theta: float, turn_sign: float) -> Vector2:
	# Travel direction along the spiral at angle theta.
	return Vector2(cos(theta) * turn_sign, sin(theta)).normalized()


func _build_layout_plan(_width: float, _depth: float) -> Dictionary:
	# Concrete layout classes own their plan construction.
	return {}


func _mirror_layout_plan(plan: Dictionary, width: float) -> void:
	for seg: Dictionary in plan["segments"]:
		var run_axis: Vector3 = seg["run_axis"]
		var width_axis: Vector3 = seg["width_axis"]
		var origin: Vector3 = seg["origin"]
		var segment_width: float = seg["width"]
		var mirrored_run := Vector3(-run_axis.x, run_axis.y, run_axis.z)
		var far_corner := origin + width_axis * segment_width
		seg["run_axis"] = mirrored_run
		seg["width_axis"] = Vector3.UP.cross(mirrored_run).normalized()
		seg["origin"] = Vector3(width - far_corner.x, far_corner.y, far_corner.z)
		if seg.has("center"):
			var spiral_center: Vector2 = seg["center"]
			seg["center"] = Vector2(segment_width - spiral_center.x, spiral_center.y)
			seg["turn_sign"] = -float(seg["turn_sign"])
		if seg.has("pivot"):
			var pivot: Vector2 = seg["pivot"]
			seg["pivot"] = Vector2(segment_width - pivot.x, pivot.y)
			var perimeter: PackedVector2Array = seg["perimeter"]
			var mirrored_perimeter := PackedVector2Array()
			for point in perimeter:
				mirrored_perimeter.append(Vector2(segment_width - point.x, point.y))
			seg["perimeter"] = mirrored_perimeter
			for wall: Dictionary in seg["extra_walls"]:
				var a: Vector2 = wall["a"]
				var b: Vector2 = wall["b"]
				wall["a"] = Vector2(segment_width - a.x, a.y)
				wall["b"] = Vector2(segment_width - b.x, b.y)
	for run: Dictionary in plan["rail_runs"]:
		var run_origin: Vector3 = run["origin"]
		var run_dir: Vector3 = run["run_dir"]
		run["origin"] = Vector3(width - run_origin.x, run_origin.y, run_origin.z)
		run["run_dir"] = Vector3(-run_dir.x, run_dir.y, run_dir.z)
		run["side"] = (
			RAIL_SIDE_RIGHT if int(run["side"]) == RAIL_SIDE_LEFT else RAIL_SIDE_LEFT
		)
	if plan.has("spiral_rail"):
		var spiral_rail: Dictionary = plan["spiral_rail"]
		var rail_center: Vector2 = spiral_rail["center"]
		spiral_rail["center"] = Vector2(width - rail_center.x, rail_center.y)
		spiral_rail["turn_sign"] = -float(spiral_rail["turn_sign"])
		spiral_rail["side"] = (
			RAIL_SIDE_RIGHT
				if int(spiral_rail["side"]) == RAIL_SIDE_LEFT
				else RAIL_SIDE_LEFT
		)


func _segment_point(seg: Dictionary, local_point: Vector3) -> Vector3:
	return (
		Vector3(seg["origin"])
		+ Vector3(seg["width_axis"]) * local_point.x
		+ Vector3.UP * local_point.y
		+ Vector3(seg["run_axis"]) * local_point.z
	)


func _segment_direction(seg: Dictionary, local_direction: Vector3) -> Vector3:
	return (
		Vector3(seg["width_axis"]) * local_direction.x
		+ Vector3.UP * local_direction.y
		+ Vector3(seg["run_axis"]) * local_direction.z
	)


func _segment_bottom(seg: Dictionary) -> float:
	return -maxf(stair_thickness, 0.0) - Vector3(seg["origin"]).y


func _append_layout_geometry(
	plan: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	for seg: Dictionary in plan["segments"]:
		match int(seg["kind"]):
			SegmentKind.SEGMENT_FLIGHT:
				_append_flight_segment_geometry(seg, vertices, normals, colors, indices)
			SegmentKind.SEGMENT_LANDING:
				_append_landing_segment_geometry(seg, vertices, normals, colors, indices)
			SegmentKind.SEGMENT_WINDER:
				_append_winder_segment_geometry(seg, vertices, normals, colors, indices)
			SegmentKind.SEGMENT_SPIRAL:
				_append_spiral_segment_geometry(seg, vertices, normals, colors, indices)
	_append_layout_rail_geometry(plan, vertices, normals, colors, indices)


func _append_embedded_quad(
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
	var winding_normal := (b - a).cross(c - a)
	if winding_normal.length_squared() <= 0.000001:
		winding_normal = (c - a).cross(d - a)
	if winding_normal.dot(normal) > 0.0:
		indices.append_array(PackedInt32Array([
			base, base + 2, base + 1, base, base + 3, base + 2
		]))
	else:
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2, base, base + 2, base + 3
		]))


func _append_segment_quad(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	local_normal: Vector3
) -> void:
	_append_embedded_quad(
		vertices, normals, colors, indices,
		_segment_point(seg, a),
		_segment_point(seg, b),
		_segment_point(seg, c),
		_segment_point(seg, d),
		_segment_direction(seg, local_normal).normalized()
	)


func _tread_slab_thickness() -> float:
	# Open tread slabs and nosing lips reuse the underside thickness, with a
	# small floor so zero-thickness stairs still produce visible slabs. Matches
	# the spiral tread slab rule.
	return maxf(stair_thickness, 0.05)


func _effective_nosing_depth(tread_depth: float) -> float:
	if tread_style != TreadStyle.NOSING:
		return 0.0
	return clampf(nosing_depth, 0.0, tread_depth * 0.45)


func _nosing_lip_thickness(rise: float) -> float:
	# Strictly shallower than one rise so the lip underside never becomes
	# coplanar with the tread top below it.
	return minf(maxf(stair_thickness, 0.02), rise * 0.75)


func _append_segment_box(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	box_min: Vector3,
	box_max: Vector3,
	skip_back := false
) -> void:
	# Axis-aligned box in segment-local space; used for floating tread slabs
	# and nosing lips. skip_back omits the +Z face when it abuts a riser plane.
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_max.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_max.z),
		Vector3(box_max.x, box_max.y, box_max.z),
		Vector3(box_max.x, box_max.y, box_min.z),
		Vector3.UP
	)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_min.y, box_min.z),
		Vector3(box_min.x, box_min.y, box_max.z),
		Vector3(box_max.x, box_min.y, box_max.z),
		Vector3(box_max.x, box_min.y, box_min.z),
		Vector3.DOWN
	)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_min.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_min.z),
		Vector3(box_max.x, box_max.y, box_min.z),
		Vector3(box_max.x, box_min.y, box_min.z),
		Vector3.FORWARD
	)
	if !skip_back:
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(box_min.x, box_min.y, box_max.z),
			Vector3(box_min.x, box_max.y, box_max.z),
			Vector3(box_max.x, box_max.y, box_max.z),
			Vector3(box_max.x, box_min.y, box_max.z),
			Vector3.BACK
		)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_min.x, box_min.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_min.z),
		Vector3(box_min.x, box_max.y, box_max.z),
		Vector3(box_min.x, box_min.y, box_max.z),
		Vector3.LEFT
	)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(box_max.x, box_min.y, box_min.z),
		Vector3(box_max.x, box_max.y, box_min.z),
		Vector3(box_max.x, box_max.y, box_max.z),
		Vector3(box_max.x, box_min.y, box_max.z),
		Vector3.RIGHT
	)


func _append_open_flight_treads(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	# Open risers: one floating slab per tread, no risers, no solid underside.
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	var tread_depth := run / float(steps)
	var slab := _tread_slab_thickness()
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y1 := rise * float(step_index + 1)
		_append_segment_box(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y1 - slab, z0),
			Vector3(width, y1, z1)
		)


func _append_flight_nosing_lips(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	# Nosing: a thin lip box overhanging each riser plane. Additive over the
	# closed mass, so the underlying stepped geometry stays unchanged. The lip
	# back face is skipped: it abuts the riser plane it overhangs.
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	var tread_depth := run / float(steps)
	var nose := _effective_nosing_depth(tread_depth)
	if nose <= 0.0005:
		return
	var lip := _nosing_lip_thickness(rise)
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var y1 := rise * float(step_index + 1)
		_append_segment_box(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y1 - lip, z0 - nose),
			Vector3(width, y1, z0),
			true
		)


func _append_flight_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	if tread_style == TreadStyle.OPEN:
		_append_open_flight_treads(seg, vertices, normals, colors, indices)
		return
	var bottom := _segment_bottom(seg)
	var top := rise * float(steps)
	var tread_depth := run / float(steps)
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y0 := rise * float(step_index)
		var y1 := rise * float(step_index + 1)
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y1, z0),
			Vector3(0.0, y1, z1),
			Vector3(width, y1, z1),
			Vector3(width, y1, z0),
			Vector3.UP
		)
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, y0, z0),
			Vector3(0.0, y1, z0),
			Vector3(width, y1, z0),
			Vector3(width, y0, z0),
			Vector3.FORWARD
		)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, bottom, 0.0),
		Vector3.FORWARD
	)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, run),
		Vector3(width, bottom, run),
		Vector3(width, top, run),
		Vector3(0.0, top, run),
		Vector3.BACK
	)
	_append_segment_side_strips(seg, vertices, normals, colors, indices, 0.0, Vector3.LEFT)
	_append_segment_side_strips(seg, vertices, normals, colors, indices, width, Vector3.RIGHT)
	_append_flight_nosing_lips(seg, vertices, normals, colors, indices)


func _append_segment_side_strips(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	x: float,
	local_normal: Vector3
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var run: float = seg["run"]
	var bottom := _segment_bottom(seg)
	var tread_depth := run / float(steps)
	var normal := _segment_direction(seg, local_normal).normalized()
	var base := vertices.size()
	for boundary_index in range(steps + 1):
		vertices.append(_segment_point(seg, Vector3(
			x, bottom, tread_depth * float(boundary_index)
		)))
		normals.append(normal)
		colors.append(stair_color)
	var top_base := vertices.size()
	for step_index in range(steps):
		var z0 := tread_depth * float(step_index)
		var z1 := tread_depth * float(step_index + 1)
		var y1 := rise * float(step_index + 1)
		vertices.append(_segment_point(seg, Vector3(x, y1, z0)))
		normals.append(normal)
		colors.append(stair_color)
		vertices.append(_segment_point(seg, Vector3(x, y1, z1)))
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


func _append_landing_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return
	var bottom := _landing_bottom(seg)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, run),
		Vector3(width, 0.0, run),
		Vector3(width, 0.0, 0.0),
		Vector3.UP
	)
	if tread_style == TreadStyle.OPEN:
		# Floating landing slabs expose their underside.
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(0.0, bottom, 0.0),
			Vector3(0.0, bottom, run),
			Vector3(width, bottom, run),
			Vector3(width, bottom, 0.0),
			Vector3.DOWN
		)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, bottom, 0.0),
		Vector3.FORWARD
	)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, run),
		Vector3(width, bottom, run),
		Vector3(width, 0.0, run),
		Vector3(0.0, 0.0, run),
		Vector3.BACK
	)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(0.0, bottom, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, run),
		Vector3(0.0, bottom, run),
		Vector3.LEFT
	)
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(width, bottom, 0.0),
		Vector3(width, 0.0, 0.0),
		Vector3(width, 0.0, run),
		Vector3(width, bottom, run),
		Vector3.RIGHT
	)


func _landing_bottom(seg: Dictionary) -> float:
	# Open-riser landings float as slabs instead of dropping to the stair base.
	if tread_style == TreadStyle.OPEN:
		return -_tread_slab_thickness()
	return _segment_bottom(seg)


func _winder_perimeter_cumulative(perimeter: PackedVector2Array) -> PackedFloat32Array:
	var cumulative := PackedFloat32Array([0.0])
	for index in range(perimeter.size() - 1):
		cumulative.append(
			cumulative[index] + perimeter[index].distance_to(perimeter[index + 1])
		)
	return cumulative


func _winder_point_at(
	perimeter: PackedVector2Array,
	cumulative: PackedFloat32Array,
	target: float
) -> Vector2:
	for index in range(perimeter.size() - 1):
		if target <= cumulative[index + 1] + 0.0001:
			var leg_length := cumulative[index + 1] - cumulative[index]
			if leg_length <= 0.0001:
				continue
			var ratio := clampf((target - cumulative[index]) / leg_length, 0.0, 1.0)
			return perimeter[index].lerp(perimeter[index + 1], ratio)
	return perimeter[perimeter.size() - 1]


func _append_winder_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var pivot: Vector2 = seg["pivot"]
	var perimeter: PackedVector2Array = seg["perimeter"]
	var bottom := _segment_bottom(seg)
	var cumulative := _winder_perimeter_cumulative(perimeter)
	var total_length := cumulative[cumulative.size() - 1]
	if total_length <= 0.001:
		return
	var up_normal := _segment_direction(seg, Vector3.UP).normalized()
	# Open risers turn each fanned tread into a floating wedge slab: a bottom
	# fan and per-tread radial faces replace the shared closed underside,
	# boundary risers, and extra walls. Nosing has no winder-fan variant and
	# falls back to the closed mass.
	var use_open := tread_style == TreadStyle.OPEN
	var slab := _tread_slab_thickness()
	for tread_index in range(steps):
		var t0 := total_length * float(tread_index) / float(steps)
		var t1 := total_length * float(tread_index + 1) / float(steps)
		var tread_top := rise * float(tread_index + 1)
		var tread_bottom := tread_top - slab if use_open else bottom
		var edge_points: Array[Vector2] = [
			_winder_point_at(perimeter, cumulative, t0),
		]
		for corner_index in range(1, perimeter.size() - 1):
			var corner_distance := cumulative[corner_index]
			if corner_distance > t0 + 0.0001 and corner_distance < t1 - 0.0001:
				edge_points.append(perimeter[corner_index])
		edge_points.append(_winder_point_at(perimeter, cumulative, t1))
		for edge_index in range(edge_points.size() - 1):
			var q0 := edge_points[edge_index]
			var q1 := edge_points[edge_index + 1]
			if q0.distance_to(q1) <= 0.0001:
				continue
			var triangle_base := vertices.size()
			vertices.append(_segment_point(seg, Vector3(pivot.x, tread_top, pivot.y)))
			vertices.append(_segment_point(seg, Vector3(q0.x, tread_top, q0.y)))
			vertices.append(_segment_point(seg, Vector3(q1.x, tread_top, q1.y)))
			for _index in range(3):
				normals.append(up_normal)
				colors.append(stair_color)
			_append_oriented_triangle(
				vertices, indices, up_normal,
				triangle_base, triangle_base + 1, triangle_base + 2
			)
			if use_open:
				var down_normal := -up_normal
				var bottom_base := vertices.size()
				vertices.append(_segment_point(seg, Vector3(
					pivot.x, tread_bottom, pivot.y
				)))
				vertices.append(_segment_point(seg, Vector3(q0.x, tread_bottom, q0.y)))
				vertices.append(_segment_point(seg, Vector3(q1.x, tread_bottom, q1.y)))
				for _index in range(3):
					normals.append(down_normal)
					colors.append(stair_color)
				_append_oriented_triangle(
					vertices, indices, down_normal,
					bottom_base, bottom_base + 1, bottom_base + 2
				)
			var edge_dir := (q1 - q0).normalized()
			var outward := Vector2(-edge_dir.y, edge_dir.x)
			var edge_mid := (q0 + q1) * 0.5
			if outward.dot(edge_mid - pivot) < 0.0:
				outward = -outward
			_append_segment_quad(
				seg, vertices, normals, colors, indices,
				Vector3(q0.x, tread_bottom, q0.y),
				Vector3(q1.x, tread_bottom, q1.y),
				Vector3(q1.x, tread_top, q1.y),
				Vector3(q0.x, tread_top, q0.y),
				Vector3(outward.x, 0.0, outward.y)
			)
		if use_open:
			var interior := _winder_point_at(
				perimeter, cumulative, (t0 + t1) * 0.5
			)
			_append_winder_radial_face(
				seg, vertices, normals, colors, indices,
				pivot, edge_points[0], tread_bottom, tread_top, interior
			)
			_append_winder_radial_face(
				seg, vertices, normals, colors, indices,
				pivot, edge_points[edge_points.size() - 1],
				tread_bottom, tread_top, interior
			)
	if use_open:
		return
	for boundary_index in range(steps):
		var boundary_t := total_length * float(boundary_index) / float(steps)
		var boundary_point := _winder_point_at(perimeter, cumulative, boundary_t)
		var radial := boundary_point - pivot
		if radial.length() <= 0.0001:
			continue
		var riser_low := rise * float(boundary_index)
		var riser_high := rise * float(boundary_index + 1)
		var riser_normal := Vector2(-radial.y, radial.x).normalized()
		var sample := _winder_point_at(
			perimeter, cumulative, minf(boundary_t + total_length * 0.01, total_length)
		)
		var edge_mid := (pivot + boundary_point) * 0.5
		if riser_normal.dot(sample - edge_mid) > 0.0:
			riser_normal = -riser_normal
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(pivot.x, riser_low, pivot.y),
			Vector3(boundary_point.x, riser_low, boundary_point.y),
			Vector3(boundary_point.x, riser_high, boundary_point.y),
			Vector3(pivot.x, riser_high, pivot.y),
			Vector3(riser_normal.x, 0.0, riser_normal.y)
		)
	for wall: Dictionary in seg["extra_walls"]:
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		if a.distance_to(b) <= 0.001:
			continue
		var wall_top: float = wall["top"]
		var wall_normal: Vector2 = wall["normal"]
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(a.x, bottom, a.y),
			Vector3(b.x, bottom, b.y),
			Vector3(b.x, wall_top, b.y),
			Vector3(a.x, wall_top, a.y),
			Vector3(wall_normal.x, 0.0, wall_normal.y)
		)


func _append_winder_radial_face(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	pivot: Vector2,
	boundary_point: Vector2,
	y0: float,
	y1: float,
	away_from: Vector2
) -> void:
	# Radial face of one floating winder tread, from pivot to a fan boundary,
	# facing away from the tread interior sample point.
	var radial := boundary_point - pivot
	if radial.length() <= 0.0001 or y1 - y0 <= 0.0001:
		return
	var face_normal := Vector2(-radial.y, radial.x).normalized()
	var edge_mid := (pivot + boundary_point) * 0.5
	if face_normal.dot(away_from - edge_mid) > 0.0:
		face_normal = -face_normal
	_append_segment_quad(
		seg, vertices, normals, colors, indices,
		Vector3(pivot.x, y0, pivot.y),
		Vector3(boundary_point.x, y0, boundary_point.y),
		Vector3(boundary_point.x, y1, boundary_point.y),
		Vector3(pivot.x, y1, pivot.y),
		Vector3(face_normal.x, 0.0, face_normal.y)
	)


func _append_layout_rail_geometry(
	plan: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if !left_rail_enabled and !right_rail_enabled:
		return
	for run: Dictionary in plan["rail_runs"]:
		var side: int = run["side"]
		if side == RAIL_SIDE_LEFT and !left_rail_enabled:
			continue
		if side == RAIL_SIDE_RIGHT and !right_rail_enabled:
			continue
		var length: float = run["length"]
		if length <= 0.001:
			continue
		var run_dir: Vector3 = run["run_dir"]
		var side_axis := Vector3.UP.cross(run_dir).normalized()
		if int(run["kind"]) == RailRunKind.RAIL_RUN_FLIGHT:
			# Interior flight ends (the transition side) carry one shared
			# tread-mid junction newel with a raked top, and the raked
			# handrail/base bars are cut flush at the flight boundary where
			# the transition leg's bars continue at the identical height, so
			# the rail stays continuous across every transition.
			var is_first := bool(run["first"])
			var is_last := bool(run["last"])
			var layout := _build_rail_post_layout(
				length,
				run["rise"],
				run["steps"],
				lower_newel_enabled and is_first,
				upper_newel_enabled and is_last,
				int(run["middle_newels"]),
				lower_newel_placement,
				upper_newel_placement,
				!is_first,
				!is_last
			)
			var handrail_minimum: float = layout["handrail_minimum_run"]
			var handrail_maximum: float = layout["handrail_maximum_run"]
			if !is_first:
				handrail_minimum = 0.0
			if !is_last:
				handrail_maximum = length
			StandardRailGeometry.append_rail(
				vertices, normals, colors, indices,
				run["origin"], run_dir, Vector3.UP, side_axis,
				length, run["rise"], rail_height,
				1.0, # post_spacing is unused: post_positions overrides it below.
				_clamped_infill_rail_size(), rail_thickness, rail_lower_height,
				rail_color,
				layout["positions"], layout["base_heights"],
				layout["thicknesses"], layout["top_heights"],
				float(layout["lower_horizontal_end"]),
				float(layout["upper_horizontal_start"]),
				handrail_minimum,
				handrail_maximum,
				infill_style, infill_count_between_newels,
				layout["base_follows_rise"]
			)
		else:
			StandardRailGeometry.append_rail(
				vertices, normals, colors, indices,
				run["origin"], run_dir, Vector3.UP, side_axis,
				length, run["rise"], rail_height,
				float(run["post_spacing"]),
				_clamped_infill_rail_size(), rail_thickness, rail_lower_height,
				rail_color,
				run["post_positions"], run["post_base_heights"],
				run["post_thicknesses"], run["post_top_heights"],
				float(run["lower_horizontal_end"]),
				float(run["upper_horizontal_start"]),
				float(run["minimum_run_override"]),
				float(run["maximum_run_override"]),
				infill_style, infill_count_between_newels,
				run["post_base_follows_rise"],
				false # transition legs own their full post layout; junction
					# posts are shared with the adjacent flight/leg runs.
			)
	if plan.has("spiral_rail"):
		var spiral_rail: Dictionary = plan["spiral_rail"]
		var spiral_side: int = spiral_rail["side"]
		if (
			(spiral_side == RAIL_SIDE_LEFT and left_rail_enabled)
			or (spiral_side == RAIL_SIDE_RIGHT and right_rail_enabled)
		):
			_append_spiral_rail_geometry(
				spiral_rail, vertices, normals, colors, indices
			)


func _spiral_rail_member_extents(rail: Dictionary) -> Vector2:
	var length: float = rail["length"]
	var layout: Dictionary = rail["post_layout"]
	var positions: PackedFloat32Array = layout["positions"]
	var thicknesses: PackedFloat32Array = layout["thicknesses"]
	var default_size := _clamped_infill_rail_size()
	var minimum_run := -default_size * 0.5
	var maximum_run := length + default_size * 0.5
	for index in range(positions.size()):
		var post_size := (
			thicknesses[index] if index < thicknesses.size() else default_size
		)
		minimum_run = minf(minimum_run, positions[index] - post_size * 0.5)
		maximum_run = maxf(maximum_run, positions[index] + post_size * 0.5)
	var minimum_override := float(layout["handrail_minimum_run"])
	var maximum_override := float(layout["handrail_maximum_run"])
	if !is_nan(minimum_override):
		minimum_run = minimum_override
	if !is_nan(maximum_override):
		maximum_run = maximum_override
	return Vector2(minimum_run, maximum_run)


func _spiral_rail_frame(rail: Dictionary, run_position: float) -> Dictionary:
	var length := maxf(float(rail["length"]), 0.001)
	var turn_radians: float = rail["turn_radians"]
	var turn_sign: float = rail["turn_sign"]
	var clamped_run := clampf(run_position, 0.0, length)
	var theta := turn_radians * clamped_run / length
	var tangent_2d := _spiral_tangent(theta, turn_sign)
	var point_2d := (
		Vector2(rail["center"])
		+ _spiral_direction(theta, turn_sign) * float(rail["radius"])
	)
	if run_position < 0.0:
		point_2d += tangent_2d * run_position
	elif run_position > length:
		point_2d += tangent_2d * (run_position - length)
	var tangent := Vector3(tangent_2d.x, 0.0, tangent_2d.y)
	var side := Vector3.UP.cross(tangent).normalized()
	return {
		"point": Vector3(point_2d.x, 0.0, point_2d.y),
		"tangent": tangent,
		"side": side,
	}


func _spiral_rail_path_height(
	rail: Dictionary,
	run_position: float,
	lower_horizontal_end: float,
	upper_horizontal_start: float,
	use_horizontal_ends: bool
) -> float:
	var height_run := run_position
	if use_horizontal_ends:
		if run_position < lower_horizontal_end:
			height_run = lower_horizontal_end
		elif run_position > upper_horizontal_start:
			height_run = upper_horizontal_start
	return float(rail["rise"]) * height_run / maxf(float(rail["length"]), 0.001)


func _spiral_rail_path_slope(
	rail: Dictionary,
	run_position: float,
	lower_horizontal_end: float,
	upper_horizontal_start: float,
	use_horizontal_ends: bool
) -> float:
	if (
		use_horizontal_ends
		and (
			run_position < lower_horizontal_end - 0.0001
			or run_position > upper_horizontal_start + 0.0001
		)
	):
		return 0.0
	return float(rail["rise"]) / maxf(float(rail["length"]), 0.001)


func _spiral_rail_sample_positions(
	rail: Dictionary,
	minimum_run: float,
	maximum_run: float,
	lower_horizontal_end: float,
	upper_horizontal_start: float
) -> PackedFloat32Array:
	var candidates: Array[float] = [minimum_run, maximum_run]
	var length: float = rail["length"]
	if minimum_run < 0.0 and maximum_run > 0.0:
		candidates.append(0.0)
	if minimum_run < length and maximum_run > length:
		candidates.append(length)
	for transition in [lower_horizontal_end, upper_horizontal_start]:
		if transition > minimum_run and transition < maximum_run:
			candidates.append(transition)
	var segment_count := maxi(
		ceili(
			rad_to_deg(float(rail["turn_radians"]))
			/ SPIRAL_RAIL_MAX_SEGMENT_ANGLE_DEGREES
		),
		1
	)
	for segment_index in range(segment_count + 1):
		var run_position := length * float(segment_index) / float(segment_count)
		if run_position > minimum_run and run_position < maximum_run:
			candidates.append(run_position)
	candidates.sort()
	var samples := PackedFloat32Array()
	for candidate in candidates:
		if samples.is_empty() or absf(candidate - samples[-1]) > 0.0001:
			samples.append(candidate)
	return samples


func _append_spiral_rail_strip(
	edge_a: PackedVector3Array,
	edge_b: PackedVector3Array,
	normal_a: PackedVector3Array,
	normal_b: PackedVector3Array,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if edge_a.size() < 2 or edge_b.size() != edge_a.size():
		return
	var base := vertices.size()
	for sample_index in range(edge_a.size()):
		vertices.append(edge_a[sample_index])
		vertices.append(edge_b[sample_index])
		normals.append(normal_a[sample_index])
		normals.append(normal_b[sample_index])
		colors.append(color)
		colors.append(color)
	for sample_index in range(edge_a.size() - 1):
		var first := base + sample_index * 2
		var next := first + 2
		var face_normal := (
			normal_a[sample_index]
			+ normal_b[sample_index]
			+ normal_a[sample_index + 1]
			+ normal_b[sample_index + 1]
		).normalized()
		_append_oriented_triangle(
			vertices, indices, face_normal, first, next, next + 1
		)
		_append_oriented_triangle(
			vertices, indices, face_normal, first, next + 1, first + 1
		)


func _append_spiral_rail_cap(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	color: Color,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var base := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	for _index in range(4):
		normals.append(normal)
		colors.append(color)
	_append_oriented_triangle(vertices, indices, normal, base, base + 1, base + 2)
	_append_oriented_triangle(vertices, indices, normal, base, base + 2, base + 3)


func _append_spiral_rail_sweep(
	rail: Dictionary,
	minimum_run: float,
	maximum_run: float,
	bottom_height: float,
	top_height: float,
	member_width: float,
	color: Color,
	use_horizontal_ends: bool,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if maximum_run - minimum_run <= 0.001 or top_height - bottom_height <= 0.001:
		return
	var layout: Dictionary = rail["post_layout"]
	var lower_horizontal_end := float(layout["lower_horizontal_end"])
	var upper_horizontal_start := float(layout["upper_horizontal_start"])
	var samples := _spiral_rail_sample_positions(
		rail,
		minimum_run,
		maximum_run,
		lower_horizontal_end,
		upper_horizontal_start
	)
	if samples.size() < 2:
		return
	var half_width := maxf(member_width, 0.01) * 0.5
	var inner_bottom := PackedVector3Array()
	var outer_bottom := PackedVector3Array()
	var inner_top := PackedVector3Array()
	var outer_top := PackedVector3Array()
	var inner_normals := PackedVector3Array()
	var outer_normals := PackedVector3Array()
	var top_normals := PackedVector3Array()
	var bottom_normals := PackedVector3Array()
	for run_position in samples:
		var frame := _spiral_rail_frame(rail, run_position)
		var point: Vector3 = frame["point"]
		var tangent: Vector3 = frame["tangent"]
		var side: Vector3 = frame["side"]
		var path_height := _spiral_rail_path_height(
			rail,
			run_position,
			lower_horizontal_end,
			upper_horizontal_start,
			use_horizontal_ends
		)
		var slope := _spiral_rail_path_slope(
			rail,
			run_position,
			lower_horizontal_end,
			upper_horizontal_start,
			use_horizontal_ends
		)
		var path_tangent := Vector3(tangent.x, slope, tangent.z).normalized()
		var top_normal := path_tangent.cross(side).normalized()
		var bottom_normal := -top_normal
		var inner_offset := -side * half_width
		var outer_offset := side * half_width
		inner_bottom.append(point + inner_offset + Vector3.UP * (path_height + bottom_height))
		outer_bottom.append(point + outer_offset + Vector3.UP * (path_height + bottom_height))
		inner_top.append(point + inner_offset + Vector3.UP * (path_height + top_height))
		outer_top.append(point + outer_offset + Vector3.UP * (path_height + top_height))
		inner_normals.append(-side)
		outer_normals.append(side)
		top_normals.append(top_normal)
		bottom_normals.append(bottom_normal)
	_append_spiral_rail_strip(
		inner_top, outer_top, top_normals, top_normals, color,
		vertices, normals, colors, indices
	)
	_append_spiral_rail_strip(
		outer_bottom, inner_bottom, bottom_normals, bottom_normals, color,
		vertices, normals, colors, indices
	)
	_append_spiral_rail_strip(
		outer_top, outer_bottom, outer_normals, outer_normals, color,
		vertices, normals, colors, indices
	)
	_append_spiral_rail_strip(
		inner_bottom, inner_top, inner_normals, inner_normals, color,
		vertices, normals, colors, indices
	)
	var start_tangent: Vector3 = _spiral_rail_frame(rail, samples[0])["tangent"]
	var end_tangent: Vector3 = _spiral_rail_frame(rail, samples[-1])["tangent"]
	_append_spiral_rail_cap(
		inner_bottom[0], inner_top[0], outer_top[0], outer_bottom[0],
		-start_tangent, color, vertices, normals, colors, indices
	)
	var last := samples.size() - 1
	_append_spiral_rail_cap(
		inner_bottom[last], outer_bottom[last], outer_top[last], inner_top[last],
		end_tangent, color, vertices, normals, colors, indices
	)


func _append_spiral_rail_posts(
	rail: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var layout: Dictionary = rail["post_layout"]
	var positions: PackedFloat32Array = layout["positions"]
	var base_heights: PackedFloat32Array = layout["base_heights"]
	var thicknesses: PackedFloat32Array = layout["thicknesses"]
	var top_heights: PackedFloat32Array = layout["top_heights"]
	var base_follows_rise: PackedByteArray = layout["base_follows_rise"]
	var length := maxf(float(rail["length"]), 0.001)
	var rise_per_run := float(rail["rise"]) / length
	for index in range(positions.size()):
		var run_position := positions[index]
		var frame := _spiral_rail_frame(rail, run_position)
		var point: Vector3 = frame["point"]
		var path_height := float(rail["rise"]) * run_position / length
		var local_top := NAN
		if index < top_heights.size() and !is_nan(top_heights[index]):
			local_top = top_heights[index] - path_height
		StandardRailGeometry.append_rail(
			vertices, normals, colors, indices,
			Vector3(point.x, path_height, point.z),
			frame["tangent"], Vector3.UP, frame["side"],
			1.0, rise_per_run, rail_height,
			1.0, _clamped_infill_rail_size(), rail_thickness, rail_lower_height,
			rail_color,
			PackedFloat32Array([0.0]),
			PackedFloat32Array([base_heights[index] - path_height]),
			PackedFloat32Array([thicknesses[index]]),
			PackedFloat32Array([local_top]),
			-INF, INF, NAN, NAN,
			infill_style, infill_count_between_newels,
			PackedByteArray([
				base_follows_rise[index] if index < base_follows_rise.size() else 0
			]),
			false,
			false
		)


func _append_spiral_rail_geometry(
	rail: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var extents := _spiral_rail_member_extents(rail)
	var height := maxf(rail_height, 0.2)
	var bar_size := _handrail_width()
	var handrail_bottom := height - bar_size
	_append_spiral_rail_sweep(
		rail, extents.x, extents.y, handrail_bottom, height, bar_size,
		rail_color, true, vertices, normals, colors, indices
	)

	var has_base_rail := StandardRailGeometry.has_lower_rail(
		rail_height, rail_thickness, rail_lower_height
	)
	var base_rail_top := StandardRailGeometry.lower_rail_top_height(
		rail_height, rail_thickness, rail_lower_height
	)
	var infill_bottom := 0.0
	if has_base_rail:
		var base_center := base_rail_top - bar_size * 0.5
		_append_spiral_rail_sweep(
			rail, extents.x, extents.y,
			base_center - bar_size * 0.5,
			base_center + bar_size * 0.5,
			bar_size, rail_color, false,
			vertices, normals, colors, indices
		)
		infill_bottom = base_rail_top

	if infill_style == StandardRailGeometry.RailStyle.HORIZONTAL:
		var infill_count := clampi(infill_count_between_newels, 0, 64)
		var infill_size := minf(
			_clamped_infill_rail_size(),
			maxf(handrail_bottom - infill_bottom, 0.02)
		)
		var clear_height := (
			handrail_bottom - infill_bottom - infill_size * float(infill_count)
		)
		if infill_count > 0 and clear_height >= 0.0:
			var clear_gap := clear_height / float(infill_count + 1)
			for infill_index in range(infill_count):
				var infill_center := (
					infill_bottom
					+ clear_gap * float(infill_index + 1)
					+ infill_size * (float(infill_index) + 0.5)
				)
				_append_spiral_rail_sweep(
					rail, extents.x, extents.y,
					infill_center - infill_size * 0.5,
					infill_center + infill_size * 0.5,
					infill_size, rail_color, false,
					vertices, normals, colors, indices
				)
	elif (
		infill_style == StandardRailGeometry.RailStyle.GLASS_PANEL
		and handrail_bottom - infill_bottom > 0.001
	):
		var panel_thickness := maxf(
			minf(bar_size, _clamped_infill_rail_size()) * 0.5,
			0.02
		)
		_append_spiral_rail_sweep(
			rail, extents.x, extents.y,
			infill_bottom, handrail_bottom,
			panel_thickness, StandardRailGeometry.GLASS_PANEL_COLOR, false,
			vertices, normals, colors, indices
		)
	_append_spiral_rail_posts(rail, vertices, normals, colors, indices)


func _add_layout_side_wall_collision_shapes(
	body: StaticBody3D,
	width: float,
	depth: float
) -> void:
	var plan := _build_layout_plan(width, depth)
	var fw: float = plan["flight_width"]
	var wall_thickness := minf(SIDE_WALL_COLLISION_THICKNESS, fw * 0.45)
	var shape_index := 0
	for seg: Dictionary in plan["segments"]:
		match int(seg["kind"]):
			SegmentKind.SEGMENT_FLIGHT:
				shape_index = _add_flight_collision_boxes(
					body, seg, wall_thickness, shape_index
				)
			SegmentKind.SEGMENT_LANDING:
				shape_index = _add_landing_collision_box(body, seg, shape_index)
			SegmentKind.SEGMENT_WINDER:
				shape_index = _add_winder_collision_boxes(
					body, seg, wall_thickness, shape_index
				)
			SegmentKind.SEGMENT_SPIRAL:
				shape_index = _add_spiral_collision_boxes(
					body, seg, wall_thickness, shape_index
				)


func _layout_collision_shape_name(shape_index: int) -> String:
	if shape_index == 0:
		return "LayoutSideCollisionShape3D"
	return "LayoutSideCollisionShape3D_%d" % (shape_index + 1)


func _add_flight_collision_boxes(
	body: StaticBody3D,
	seg: Dictionary,
	wall_thickness: float,
	shape_index: int
) -> int:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return shape_index
	var bottom := _segment_bottom(seg)
	var tread_depth := run / float(steps)
	var thickness := minf(wall_thickness, width * 0.45)
	var seg_basis := Basis(
		Vector3(seg["width_axis"]), Vector3.UP, Vector3(seg["run_axis"])
	)
	for step_index in range(steps):
		var z_center := tread_depth * (float(step_index) + 0.5)
		var top := rise * float(step_index + 1)
		var box_height := top - bottom
		var y_center := bottom + box_height * 0.5
		_add_side_wall_collision_shape(
			body,
			_layout_collision_shape_name(shape_index),
			_segment_point(seg, Vector3(thickness * 0.5, y_center, z_center)),
			Vector3(thickness, box_height, tread_depth),
			seg_basis
		)
		shape_index += 1
		_add_side_wall_collision_shape(
			body,
			_layout_collision_shape_name(shape_index),
			_segment_point(seg, Vector3(width - thickness * 0.5, y_center, z_center)),
			Vector3(thickness, box_height, tread_depth),
			seg_basis
		)
		shape_index += 1
	return shape_index


func _add_landing_collision_box(
	body: StaticBody3D,
	seg: Dictionary,
	shape_index: int
) -> int:
	var width: float = seg["width"]
	var run: float = seg["run"]
	if width <= 0.001 or run <= 0.001:
		return shape_index
	var bottom := _landing_bottom(seg)
	var box_height := -bottom
	if box_height <= 0.001:
		return shape_index
	var seg_basis := Basis(
		Vector3(seg["width_axis"]), Vector3.UP, Vector3(seg["run_axis"])
	)
	_add_side_wall_collision_shape(
		body,
		_layout_collision_shape_name(shape_index),
		_segment_point(seg, Vector3(width * 0.5, bottom * 0.5, run * 0.5)),
		Vector3(width, box_height, run),
		seg_basis
	)
	return shape_index + 1


func _append_spiral_segment_geometry(
	seg: Dictionary,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var center: Vector2 = seg["center"]
	var outer_radius: float = seg["outer_radius"]
	var inner_radius: float = seg["inner_radius"]
	var turn_radians: float = seg["turn_radians"]
	var turn_sign: float = seg["turn_sign"]
	if steps <= 0 or outer_radius - inner_radius <= 0.001:
		return
	# Wedge tread slabs around the central column. The inner faces are
	# omitted: they sit inside the column, whose circumscribed prism contains
	# the treads' inner circle. Open risers keep each slab floating at the
	# tread slab thickness; Closed (and Nosing, which has no spiral variant)
	# drops each wedge to the previous tread's top minus the slab so
	# consecutive wedges overlap vertically with no gap.
	var slab := _tread_slab_thickness()
	for tread_index in range(steps):
		var theta0 := turn_radians * float(tread_index) / float(steps)
		var theta1 := turn_radians * float(tread_index + 1) / float(steps)
		var top := rise * float(tread_index + 1)
		var bottom := top - slab
		if tread_style != TreadStyle.OPEN:
			bottom = rise * float(tread_index) - slab
		var inner0 := center + _spiral_direction(theta0, turn_sign) * inner_radius
		var inner1 := center + _spiral_direction(theta1, turn_sign) * inner_radius
		var outer0 := center + _spiral_direction(theta0, turn_sign) * outer_radius
		var outer1 := center + _spiral_direction(theta1, turn_sign) * outer_radius
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner0.x, top, inner0.y),
			Vector3(inner1.x, top, inner1.y),
			Vector3(outer1.x, top, outer1.y),
			Vector3(outer0.x, top, outer0.y),
			Vector3.UP
		)
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner0.x, bottom, inner0.y),
			Vector3(inner1.x, bottom, inner1.y),
			Vector3(outer1.x, bottom, outer1.y),
			Vector3(outer0.x, bottom, outer0.y),
			Vector3.DOWN
		)
		var outer_mid := ((outer0 + outer1) * 0.5 - center).normalized()
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(outer0.x, bottom, outer0.y),
			Vector3(outer1.x, bottom, outer1.y),
			Vector3(outer1.x, top, outer1.y),
			Vector3(outer0.x, top, outer0.y),
			Vector3(outer_mid.x, 0.0, outer_mid.y)
		)
		var leading_normal := -_spiral_tangent(theta0, turn_sign)
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner0.x, bottom, inner0.y),
			Vector3(outer0.x, bottom, outer0.y),
			Vector3(outer0.x, top, outer0.y),
			Vector3(inner0.x, top, inner0.y),
			Vector3(leading_normal.x, 0.0, leading_normal.y)
		)
		var trailing_normal := _spiral_tangent(theta1, turn_sign)
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(inner1.x, bottom, inner1.y),
			Vector3(outer1.x, bottom, outer1.y),
			Vector3(outer1.x, top, outer1.y),
			Vector3(inner1.x, top, inner1.y),
			Vector3(trailing_normal.x, 0.0, trailing_normal.y)
		)
	# Central column: a fixed-side prism circumscribing the treads' inner
	# circle, from the underside depth up to the top-floor height, with a
	# visible top cap and an open hidden bottom.
	var column_radius := inner_radius / cos(PI / float(SPIRAL_COLUMN_SIDES))
	var height := maxf(stair_height, 0.05)
	var base_y := -maxf(stair_thickness, 0.0)
	var up_normal := _segment_direction(seg, Vector3.UP).normalized()
	for side_index in range(SPIRAL_COLUMN_SIDES):
		var phi0 := TAU * float(side_index) / float(SPIRAL_COLUMN_SIDES)
		var phi1 := TAU * float(side_index + 1) / float(SPIRAL_COLUMN_SIDES)
		var p0 := center + Vector2(cos(phi0), sin(phi0)) * column_radius
		var p1 := center + Vector2(cos(phi1), sin(phi1)) * column_radius
		var face_mid := ((p0 + p1) * 0.5 - center).normalized()
		_append_segment_quad(
			seg, vertices, normals, colors, indices,
			Vector3(p0.x, base_y, p0.y),
			Vector3(p1.x, base_y, p1.y),
			Vector3(p1.x, height, p1.y),
			Vector3(p0.x, height, p0.y),
			Vector3(face_mid.x, 0.0, face_mid.y)
		)
		var triangle_base := vertices.size()
		vertices.append(_segment_point(seg, Vector3(center.x, height, center.y)))
		vertices.append(_segment_point(seg, Vector3(p0.x, height, p0.y)))
		vertices.append(_segment_point(seg, Vector3(p1.x, height, p1.y)))
		for _index in range(3):
			normals.append(up_normal)
			colors.append(stair_color)
		_append_oriented_triangle(
			vertices, indices, up_normal,
			triangle_base, triangle_base + 1, triangle_base + 2
		)


func _add_spiral_collision_boxes(
	body: StaticBody3D,
	seg: Dictionary,
	wall_thickness: float,
	shape_index: int
) -> int:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var center: Vector2 = seg["center"]
	var outer_radius: float = seg["outer_radius"]
	var turn_radians: float = seg["turn_radians"]
	var turn_sign: float = seg["turn_sign"]
	if steps <= 0:
		return shape_index
	var slab := _tread_slab_thickness()
	for tread_index in range(steps):
		var theta0 := turn_radians * float(tread_index) / float(steps)
		var theta1 := turn_radians * float(tread_index + 1) / float(steps)
		var outer0 := center + _spiral_direction(theta0, turn_sign) * outer_radius
		var outer1 := center + _spiral_direction(theta1, turn_sign) * outer_radius
		var chord := outer1 - outer0
		var chord_length := chord.length()
		if chord_length <= 0.01:
			continue
		var chord_dir := chord / chord_length
		var inward := ((center - (outer0 + outer1) * 0.5)).normalized()
		var top := rise * float(tread_index + 1)
		var box_bottom := top - slab
		if tread_style != TreadStyle.OPEN:
			# Match the closed spiral wedge, which drops to the previous
			# tread's top minus the slab.
			box_bottom = rise * float(tread_index) - slab
		var box_height := top - box_bottom
		var center_2d := (outer0 + outer1) * 0.5 + inward * (wall_thickness * 0.5)
		var chord_dir_3d := _segment_direction(
			seg, Vector3(chord_dir.x, 0.0, chord_dir.y)
		).normalized()
		var box_basis := Basis(
			chord_dir_3d, Vector3.UP, chord_dir_3d.cross(Vector3.UP)
		)
		_add_side_wall_collision_shape(
			body,
			_layout_collision_shape_name(shape_index),
			_segment_point(seg, Vector3(
				center_2d.x, (top + box_bottom) * 0.5, center_2d.y
			)),
			Vector3(chord_length, box_height, wall_thickness),
			box_basis
		)
		shape_index += 1
	return shape_index


func _add_winder_collision_boxes(
	body: StaticBody3D,
	seg: Dictionary,
	wall_thickness: float,
	shape_index: int
) -> int:
	var steps: int = seg["steps"]
	var rise: float = seg["rise"]
	var pivot: Vector2 = seg["pivot"]
	var perimeter: PackedVector2Array = seg["perimeter"]
	var bottom := _segment_bottom(seg)
	var cumulative := _winder_perimeter_cumulative(perimeter)
	var total_length := cumulative[cumulative.size() - 1]
	if total_length <= 0.001:
		return shape_index
	var walls: Array[Dictionary] = []
	for tread_index in range(steps):
		var t0 := total_length * float(tread_index) / float(steps)
		var t1 := total_length * float(tread_index + 1) / float(steps)
		var tread_top := rise * float(tread_index + 1)
		var edge_points: Array[Vector2] = [
			_winder_point_at(perimeter, cumulative, t0),
		]
		for corner_index in range(1, perimeter.size() - 1):
			var corner_distance := cumulative[corner_index]
			if corner_distance > t0 + 0.0001 and corner_distance < t1 - 0.0001:
				edge_points.append(perimeter[corner_index])
		edge_points.append(_winder_point_at(perimeter, cumulative, t1))
		for edge_index in range(edge_points.size() - 1):
			walls.append({
				"a": edge_points[edge_index],
				"b": edge_points[edge_index + 1],
				"top": tread_top,
			})
	for wall: Dictionary in seg["extra_walls"]:
		walls.append(wall)
	for wall in walls:
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var edge_length := a.distance_to(b)
		if edge_length <= 0.01:
			continue
		var wall_top: float = wall["top"]
		var box_height := wall_top - bottom
		if box_height <= 0.001:
			continue
		var edge_dir := (b - a).normalized()
		var inward := Vector2(-edge_dir.y, edge_dir.x)
		var edge_mid := (a + b) * 0.5
		if inward.dot(pivot - edge_mid) < 0.0:
			inward = -inward
		var center_2d := edge_mid + inward * (wall_thickness * 0.5)
		var edge_dir_3d := _segment_direction(
			seg, Vector3(edge_dir.x, 0.0, edge_dir.y)
		).normalized()
		var box_basis := Basis(edge_dir_3d, Vector3.UP, edge_dir_3d.cross(Vector3.UP))
		_add_side_wall_collision_shape(
			body,
			_layout_collision_shape_name(shape_index),
			_segment_point(seg, Vector3(
				center_2d.x, bottom + box_height * 0.5, center_2d.y
			)),
			Vector3(edge_length, box_height, wall_thickness),
			box_basis
		)
		shape_index += 1
	return shape_index
