@tool
class_name BuildingFactory
extends RefCounted

const Wall3DScript = preload("res://addons/low_poly_building_editor/wall_3d.gd")
const WallSegment3DScript = preload("res://addons/low_poly_building_editor/wall_segment_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floor_3d.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roof_3d.gd")

const PILLAR_STYLE_SCRIPTS := {
	"round": preload("res://addons/low_poly_building_editor/round_pillar_3d.gd"),
	"square": preload("res://addons/low_poly_building_editor/square_pillar_3d.gd"),
	"octagonal": preload("res://addons/low_poly_building_editor/octagonal_pillar_3d.gd"),
	"tapered": preload("res://addons/low_poly_building_editor/tapered_pillar_3d.gd"),
}
const ROOF_STYLE_SCRIPTS := {
	"flat": preload("res://addons/low_poly_building_editor/flat_roof_3d.gd"),
	"shed": preload("res://addons/low_poly_building_editor/shed_roof_3d.gd"),
	"gable": preload("res://addons/low_poly_building_editor/gable_roof_3d.gd"),
	"hip": preload("res://addons/low_poly_building_editor/hip_roof_3d.gd"),
}


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
	debug_wireframe: bool = false,
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
	roof.debug_show_triangle_wireframe = debug_wireframe
	roof.rebuild_roof_mesh()
	return roof


static func instantiate_roof_style(style: String) -> Roof3DScript:
	var normalized_style := style.strip_edges().to_lower()
	var roof_script := ROOF_STYLE_SCRIPTS.get(
		normalized_style,
		ROOF_STYLE_SCRIPTS["gable"]
	) as Script
	return roof_script.new() as Roof3DScript


static func _unique_child_name(building: Node, prefix: String) -> String:
	var index := 1
	var candidate := "%s%d" % [prefix, index]
	if building == null:
		return candidate
	while building.has_node(candidate):
		index += 1
		candidate = "%s%d" % [prefix, index]
	return candidate
