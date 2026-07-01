@tool
class_name BuildingFactory
extends RefCounted

const Wall3DScript = preload("res://addons/low_poly_building_editor/wall_3d.gd")
const WallSegment3DScript = preload("res://addons/low_poly_building_editor/wall_segment_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floor_3d.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roof_3d.gd")
const BuildingOpening3DScript = preload(
	"res://addons/low_poly_building_editor/building_opening_3d.gd"
)

const PILLAR_STYLE_KEYS := ["round", "square", "octagonal", "tapered"]
const PILLAR_STYLE_SCRIPTS := {
	"round": preload("res://addons/low_poly_building_editor/round_pillar_3d.gd"),
	"square": preload("res://addons/low_poly_building_editor/square_pillar_3d.gd"),
	"octagonal": preload("res://addons/low_poly_building_editor/octagonal_pillar_3d.gd"),
	"tapered": preload("res://addons/low_poly_building_editor/tapered_pillar_3d.gd"),
}
const ROOF_STYLE_KEYS := ["flat", "shed", "gable", "hip", "dome"]
const ROOF_STYLE_SCRIPTS := {
	"flat": preload("res://addons/low_poly_building_editor/flat_roof_3d.gd"),
	"shed": preload("res://addons/low_poly_building_editor/shed_roof_3d.gd"),
	"gable": preload("res://addons/low_poly_building_editor/gable_roof_3d.gd"),
	"hip": preload("res://addons/low_poly_building_editor/hip_roof_3d.gd"),
	"dome": preload("res://addons/low_poly_building_editor/dome_roof_3d.gd"),
}
const WINDOW_STYLE_KEYS := [
	"single_window",
	"double_window",
	"grid_window",
	"louvered_window",
	"transom_window",
	"arched_window",
	"frame",
]
const DOOR_STYLE_KEYS := [
	"single_door",
	"double_door",
	"glazed_door",
	"glazed_grid_door",
	"panel_door",
	"dutch_door",
	"single_frame",
	"double_frame",
]
const OPENING_STYLE_SCRIPTS := {
	"single_window": preload("res://addons/low_poly_building_editor/single_window_3d.gd"),
	"double_window": preload("res://addons/low_poly_building_editor/double_window_3d.gd"),
	"grid_window": preload("res://addons/low_poly_building_editor/grid_window_3d.gd"),
	"louvered_window": preload("res://addons/low_poly_building_editor/louvered_window_3d.gd"),
	"transom_window": preload("res://addons/low_poly_building_editor/transom_window_3d.gd"),
	"arched_window": preload("res://addons/low_poly_building_editor/arched_window_3d.gd"),
	"frame": preload("res://addons/low_poly_building_editor/window_frame_3d.gd"),
	"single_door": preload("res://addons/low_poly_building_editor/single_door_3d.gd"),
	"double_door": preload("res://addons/low_poly_building_editor/double_door_3d.gd"),
	"glazed_door": preload("res://addons/low_poly_building_editor/glazed_door_3d.gd"),
	"glazed_grid_door": preload(
		"res://addons/low_poly_building_editor/glazed_grid_door_3d.gd"
	),
	"panel_door": preload("res://addons/low_poly_building_editor/panel_door_3d.gd"),
	"dutch_door": preload("res://addons/low_poly_building_editor/dutch_door_3d.gd"),
	"single_frame": preload(
		"res://addons/low_poly_building_editor/single_door_frame_3d.gd"
	),
	"double_frame": preload(
		"res://addons/low_poly_building_editor/double_door_frame_3d.gd"
	),
}
const OPENING_STYLE_PROPERTY_NAMES: Array[StringName] = [
	&"window_pane_depth",
	&"window_pane_color",
	&"pane_grid_rows",
	&"pane_grid_cols",
	&"muntin_thickness",
	&"louver_count",
	&"louver_depth",
	&"transom_ratio",
	&"transom_rail_thickness",
	&"arch_steps",
	&"door_panel_depth",
	&"door_panel_color",
	&"door_glazing_ratio",
	&"door_glass_depth",
	&"door_glass_color",
	&"door_inset_rows",
	&"door_inset_cols",
]
const OPENING_SILL_META := &"building_opening_sill_height"
const OPENING_ALLOW_BASE_META := &"building_opening_allow_base_edge"


static func snap_local_position(local_position: Vector3, grid_step: float) -> Vector3:
	var step := maxf(grid_step, 0.05)
	return Vector3(
		roundf(local_position.x / step) * step,
		roundf(local_position.y / step) * step,
		roundf(local_position.z / step) * step
	)


static func snap_world_position(building: Node3D, world_position: Vector3, grid_step: float) -> Vector3:
	if building == null:
		return snap_local_position(world_position, grid_step)
	return building.to_global(snap_local_position(building.to_local(world_position), grid_step))


static func constrain_wall_end(
	start_local: Vector3,
	target_local: Vector3,
	grid_step: float,
	lock_to_8_way: bool
) -> Vector3:
	var snapped_target := snap_local_position(target_local, grid_step)
	if !lock_to_8_way:
		return snapped_target

	var flat_delta := Vector2(snapped_target.x - start_local.x, snapped_target.z - start_local.z)
	if flat_delta.length_squared() <= 0.000001:
		return start_local

	var angle_step := PI * 0.25
	var angle := atan2(flat_delta.y, flat_delta.x)
	var locked_angle := roundf(angle / angle_step) * angle_step
	var step := maxf(grid_step, 0.05)
	var length := roundf(flat_delta.length() / step) * step
	var locked := Vector3(cos(locked_angle) * length, 0.0, sin(locked_angle) * length)
	return snap_local_position(start_local + locked, step)


static func create_wall_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	height: float = 2.4,
	thickness: float = 0.22,
	color: Color = Color(0.78, 0.68, 0.54, 1.0)
) -> Wall3DScript:
	var wall := Wall3DScript.new() as Wall3DScript
	wall.name = _unique_child_name(building, "Wall3D")
	wall.wall_height = height
	wall.wall_thickness = thickness
	wall.wall_color = color
	var segment := WallSegment3DScript.new() as WallSegment3D
	segment.start_point = local_start
	segment.end_point = local_end
	segment.height = height
	segment.thickness = thickness
	segment.color = color
	var wall_segments: Array[WallSegment3D] = [segment]
	wall.segments = wall_segments
	wall.build_on_ready = true
	wall.generate_collision = true
	wall.rebuild_wall_mesh()
	return wall


static func room_segments_from_corners(
	local_start: Vector3,
	local_end: Vector3,
	height: float,
	thickness: float,
	color: Color
) -> Array[WallSegment3D]:
	var base_y := local_start.y
	var corners: Array[Vector3] = [
		Vector3(local_start.x, base_y, local_start.z),
		Vector3(local_end.x, base_y, local_start.z),
		Vector3(local_end.x, base_y, local_end.z),
		Vector3(local_start.x, base_y, local_end.z),
	]
	var segments: Array[WallSegment3D] = []
	for index in range(corners.size()):
		var segment := WallSegment3DScript.new() as WallSegment3D
		segment.start_point = corners[index]
		segment.end_point = corners[(index + 1) % corners.size()]
		segment.height = height
		segment.thickness = thickness
		segment.color = color
		segments.append(segment)
	return segments


static func create_room_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	height: float = 2.4,
	thickness: float = 0.22,
	color: Color = Color(0.78, 0.68, 0.54, 1.0)
) -> Wall3DScript:
	var segments := room_segments_from_corners(local_start, local_end, height, thickness, color)
	var wall := create_wall_node(
		building,
		segments[0].start_point,
		segments[0].end_point,
		height,
		thickness,
		color
	)
	wall.name = _unique_child_name(building, "Room3D")
	wall.segments = segments
	wall.rebuild_wall_mesh()
	return wall


static func create_floor_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	thickness: float = 0.12,
	color: Color = Color(0.46, 0.40, 0.32, 1.0)
) -> Floor3DScript:
	var floor := Floor3DScript.new() as Floor3DScript
	floor.name = _unique_child_name(building, "Floor3D")
	floor.start_point = local_start
	floor.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	floor.floor_thickness = thickness
	floor.floor_color = color
	floor.build_on_ready = true
	floor.generate_collision = true
	floor.rebuild_floor_mesh()
	return floor


static func create_floor_polygon_node(
	building: Node,
	local_points: PackedVector3Array,
	thickness: float = 0.12,
	color: Color = Color(0.46, 0.40, 0.32, 1.0)
) -> Floor3DScript:
	var floor := Floor3DScript.new() as Floor3DScript
	floor.name = _unique_child_name(building, "Floor3D")
	floor.floor_thickness = thickness
	floor.floor_color = color
	floor.build_on_ready = true
	floor.generate_collision = true
	floor.set_floor_polygon(local_points)
	return floor


static func create_stairs_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	height: float = 1.2,
	step_count: int = 6,
	thickness: float = 0.12,
	color: Color = Color(0.52, 0.46, 0.38, 1.0),
	rotation_degrees: float = 0.0
) -> Stairs3DScript:
	var stairs := Stairs3DScript.new() as Stairs3DScript
	stairs.name = _unique_child_name(building, "Stairs3D")
	stairs.start_point = local_start
	stairs.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	stairs.stair_height = height
	stairs.step_count = step_count
	stairs.stair_thickness = thickness
	stairs.stair_color = color
	stairs.stair_rotation_degrees = rotation_degrees
	stairs.build_on_ready = true
	stairs.generate_collision = true
	stairs.rebuild_stairs_mesh()
	return stairs


static func create_pillar_node(
	building: Node,
	local_base: Vector3,
	radius: float = 0.25,
	height: float = 2.4,
	sides: int = 8,
	style: String = "round",
	color: Color = Color(0.70, 0.64, 0.52, 1.0),
	lower_rim_height: float = 0.0,
	lower_rim_outset: float = 0.0,
	upper_rim_height: float = 0.0,
	upper_rim_outset: float = 0.0,
	upper_radius: float = 0.0
) -> Pillar3DScript:
	var normalized_style := style.strip_edges().to_lower()
	var pillar := instantiate_pillar_style(normalized_style)
	pillar.name = _unique_child_name(building, "Pillar3D")
	pillar.base_point = local_base
	pillar.pillar_radius = radius
	pillar.upper_radius = upper_radius
	pillar.pillar_height = height
	if normalized_style == "round" or normalized_style == "tapered":
		pillar.set(&"side_count", sides)
	pillar.pillar_color = color
	pillar.lower_rim_height = lower_rim_height
	pillar.lower_rim_outset = lower_rim_outset
	pillar.upper_rim_height = upper_rim_height
	pillar.upper_rim_outset = upper_rim_outset
	pillar.build_on_ready = true
	pillar.generate_collision = true
	pillar.rebuild_pillar_mesh()
	return pillar


static func instantiate_pillar_style(style: String) -> Pillar3DScript:
	var normalized_style := style.strip_edges().to_lower()
	var pillar_script := PILLAR_STYLE_SCRIPTS.get(
		normalized_style,
		PILLAR_STYLE_SCRIPTS["round"]
	) as Script
	return pillar_script.new() as Pillar3DScript


static func create_roof_node(
	building: Node,
	local_start: Vector3,
	local_end: Vector3,
	style: String = "gable",
	height: float = 40.0,
	thickness: float = 0.12,
	overhang: float = 0.2,
	color: Color = Color(0.50, 0.34, 0.25, 1.0),
	rotation_degrees: float = 0.0,
	hip_gable_height: float = 0.0
) -> Roof3DScript:
	var roof := instantiate_roof_style(style)
	roof.name = _unique_child_name(building, "Roof3D")
	roof.start_point = local_start
	roof.end_point = Vector3(local_end.x, local_start.y, local_end.z)
	roof.set_roof_angle_degrees(height)
	roof.roof_thickness = thickness
	roof.roof_overhang = overhang
	roof.set_hip_gable_height(hip_gable_height)
	roof.roof_color = color
	roof.roof_rotation_degrees = rotation_degrees
	roof.build_on_ready = true
	roof.generate_collision = true
	roof.rebuild_roof_mesh()
	return roof


static func create_flat_roof_polygon_node(
	building: Node,
	local_points: PackedVector3Array,
	thickness: float = 0.12,
	overhang: float = 0.2,
	color: Color = Color(0.50, 0.34, 0.25, 1.0)
) -> Roof3DScript:
	var roof := instantiate_roof_style("flat")
	roof.name = _unique_child_name(building, "Roof3D")
	roof.roof_thickness = thickness
	roof.roof_overhang = overhang
	roof.roof_color = color
	roof.build_on_ready = true
	roof.generate_collision = true
	roof.set_roof_polygon(local_points)
	return roof


static func instantiate_roof_style(style: String) -> Roof3DScript:
	var normalized_style := style.strip_edges().to_lower()
	var roof_script := ROOF_STYLE_SCRIPTS.get(
		normalized_style,
		ROOF_STYLE_SCRIPTS["gable"]
	) as Script
	return roof_script.new() as Roof3DScript


static func get_pillar_style_keys() -> PackedStringArray:
	return PackedStringArray(PILLAR_STYLE_KEYS)


static func get_roof_style_keys() -> PackedStringArray:
	return PackedStringArray(ROOF_STYLE_KEYS)


static func get_opening_style_keys() -> PackedStringArray:
	var styles := PackedStringArray(WINDOW_STYLE_KEYS)
	styles.append_array(PackedStringArray(DOOR_STYLE_KEYS))
	return styles


static func get_window_style_keys() -> PackedStringArray:
	return PackedStringArray(WINDOW_STYLE_KEYS)


static func get_door_style_keys() -> PackedStringArray:
	return PackedStringArray(DOOR_STYLE_KEYS)


static func is_pillar_style_supported(style: String) -> bool:
	return PILLAR_STYLE_SCRIPTS.has(style.strip_edges().to_lower())


static func is_roof_style_supported(style: String) -> bool:
	return ROOF_STYLE_SCRIPTS.has(style.strip_edges().to_lower())


static func is_opening_style_supported(style: String) -> bool:
	return OPENING_STYLE_SCRIPTS.has(style.strip_edges().to_lower())


static func is_window_style_supported(style: String) -> bool:
	return WINDOW_STYLE_KEYS.has(style.strip_edges().to_lower())


static func is_door_style_supported(style: String) -> bool:
	return DOOR_STYLE_KEYS.has(style.strip_edges().to_lower())


static func instantiate_opening_style(
	style: String,
	strict: bool = false
) -> BuildingOpening3DScript:
	var normalized_style := style.strip_edges().to_lower()
	if strict and !OPENING_STYLE_SCRIPTS.has(normalized_style):
		return null
	var opening_script := OPENING_STYLE_SCRIPTS.get(
		normalized_style,
		BuildingOpening3DScript
	) as Script
	return opening_script.new() as BuildingOpening3DScript


static func apply_opening_settings(
	opening: BuildingOpening3DScript,
	settings: Dictionary,
	wall_thickness: float
) -> void:
	if opening == null:
		return
	opening.opening_width = float(settings.get("width", opening.opening_width))
	opening.opening_height = float(settings.get("height", opening.opening_height))
	opening.frame_thickness = float(
		settings.get("frame_thickness", opening.frame_thickness)
	)
	opening.frame_depth = maxf(wall_thickness, 0.0) + 0.04
	opening.wall_thickness = maxf(wall_thickness, 0.0)
	opening.frame_sides = int(settings.get("frame_sides", opening.frame_sides))
	opening.frame_protrusion = float(
		settings.get("frame_protrusion", opening.frame_protrusion)
	)
	opening.frame_color = Color(settings.get("frame_color", opening.frame_color))
	opening.show_bottom_frame = bool(
		settings.get("show_bottom_frame", opening.show_bottom_frame)
	)
	for property_name in OPENING_STYLE_PROPERTY_NAMES:
		var setting_key := String(property_name)
		if settings.has(setting_key) and _object_has_property(opening, property_name):
			opening.set(property_name, settings[setting_key])


static func configure_opening_placement(
	opening: BuildingOpening3DScript,
	wall: Wall3DScript,
	segment_index: int,
	distance_along_wall: float,
	sill_height: float,
	face_sign: float,
	allow_base_edge: bool
) -> bool:
	if opening == null or wall == null:
		return false
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	var resolved_face_sign := 1.0 if face_sign >= 0.0 else -1.0
	var frame := wall.get_segment_local_frame(segment_index)
	var local_position := Vector3(
		distance_along_wall,
		maxf(sill_height, 0.0) + opening.opening_height * 0.5,
		resolved_face_sign * (
			segment.thickness * 0.5 + BuildingOpening3DScript.FRAME_FACE_GAP
		)
	)
	opening.transform = Transform3D(
		opening_basis_for_face(frame.basis, resolved_face_sign),
		frame * local_position
	)
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, segment_index)
	opening.set_meta(OPENING_SILL_META, maxf(sill_height, 0.0))
	opening.set_meta(OPENING_ALLOW_BASE_META, allow_base_edge)
	return true


static func create_opening_node(
	wall: Wall3DScript,
	segment_index: int,
	distance_along_wall: float,
	sill_height: float,
	face_sign: float,
	settings: Dictionary,
	strict_style: bool = false
) -> BuildingOpening3DScript:
	if wall == null:
		return null
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return null
	var style := String(settings.get("style", ""))
	var opening := instantiate_opening_style(style, strict_style)
	if opening == null:
		return null
	var name_prefix := String(settings.get("node_name", "BuildingOpening3D"))
	opening.name = _unique_child_name(wall, name_prefix)
	apply_opening_settings(opening, settings, segment.thickness)
	var allow_base_edge := bool(settings.get("allow_base_edge", false))
	if !configure_opening_placement(
		opening,
		wall,
		segment_index,
		distance_along_wall,
		sill_height,
		face_sign,
		allow_base_edge
	):
		opening.free()
		return null
	opening.build_on_ready = true
	opening.generate_collision = true
	return opening


static func opening_basis_for_face(basis: Basis, face_sign: float) -> Basis:
	if face_sign < 0.0:
		return basis * Basis(Vector3.UP, PI)
	return basis


static func _object_has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


static func _unique_child_name(building: Node, prefix: String) -> String:
	var index := 1
	var candidate := "%s%d" % [prefix, index]
	if building == null:
		return candidate
	while building.has_node(candidate):
		index += 1
		candidate = "%s%d" % [prefix, index]
	return candidate
