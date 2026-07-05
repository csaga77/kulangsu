extends SceneTree

const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)
const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)
const BuildingThumbnailRendererScript = preload(
	"res://addons/low_poly_building_editor/building_thumbnail_renderer.gd"
)
const Wall3DScript = preload(
	"res://addons/low_poly_building_editor/walls/wall_3d.gd"
)

const SPEC_PATH := (
	"res://architecture/trinity_church/trinity_church_building_spec.json"
)
const OUTPUT_SCENE := (
	"res://architecture/trinity_church/trinity_church_stylized_3d.tscn"
)
const OUTPUT_REPORT := (
	"res://architecture/trinity_church/trinity_church_generation_report.json"
)
const OUTPUT_PREVIEW := (
	"res://architecture/trinity_church/trinity_church_preview.png"
)

const CREAM := Color("#eee8dc")
const STONE := Color("#c8bdaa")
const STONE_SHADOW := Color("#a99f8f")
const BRICK := Color("#a84936")
const BRICK_DARK := Color("#843627")
const TERRACOTTA := Color("#d76543")
const TERRACOTTA_DARK := Color("#b94c34")
const DARK_WOOD := Color("#4d2d25")
const GLASS := Color("#627986b8")
const DOME_DARK := Color("#35383b")
const CROSS_RED := Color("#b53029")


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	var load_result := BuildingSpecCompilerScript.load_json_spec(SPEC_PATH)
	var spec_errors: Array = load_result.get("errors", [])
	if !spec_errors.is_empty():
		_finish_with_errors(spec_errors)
		return

	var spec = load_result.get("spec")
	var building := _build_reference_scene(spec)
	var resolved := {
		"schema_version": spec.schema_version,
		"generator_version": spec.generator_version,
		"seed": spec.generation_seed,
		"building_name": spec.building_name,
		"grid_step": spec.grid_step,
		"footprint_cells": [
			spec.footprint_cells.x,
			spec.footprint_cells.y,
		],
		"door_style": spec.door_style,
		"window_style": spec.window_style,
		"roof_style": spec.roof_style,
		"entrance_segment": spec.entrance_segment,
		"reference_features": [
			"cruciform_plan",
			"broad_stone_steps",
			"brick_pilasters",
			"white_classical_pediments",
			"terracotta_hip_roofs",
			"octagonal_lantern",
			"dark_cupola",
			"red_cross",
		],
		"node_count": _count_authored_nodes(building),
	}
	resolved["structural_signature"] = hash(resolved)

	var save_error := BuildingSpecCompilerScript.save_building(
		building,
		OUTPUT_SCENE
	)
	if save_error != OK:
		building.free()
		_finish_with_errors([
			"Could not save Trinity Church scene (error %d)." % save_error,
		])
		return

	var preview_rendered := false
	var preview_error := ""
	if DisplayServer.get_name() != "headless":
		var renderer := (
			BuildingThumbnailRendererScript.new()
			as BuildingThumbnailRendererScript
		)
		var render_result: Dictionary = await renderer.render_building(
			building,
			resolved,
			OUTPUT_PREVIEW,
			Vector2i(1200, 900)
		)
		preview_rendered = bool(render_result.get("ok", false))
		preview_error = String(render_result.get("error", ""))
		if !preview_rendered:
			push_error(preview_error)
		renderer.dispose()

	var warnings: Array[String] = []
	if !preview_rendered and !preview_error.is_empty():
		warnings.append(preview_error)
	var report := {
		"ok": true,
		"output": OUTPUT_SCENE,
		"preview": OUTPUT_PREVIEW if preview_rendered else "",
		"resolved": resolved,
		"errors": [],
		"warnings": warnings,
	}
	var report_error := _write_report(report)
	print(JSON.stringify(report, "\t"))
	building.free()
	quit(0 if report_error == OK else 1)


func _build_reference_scene(spec) -> Building3DScript:
	var building := Building3DScript.new() as Building3DScript
	building.name = spec.building_name
	building.set_meta("building_api", "low_poly_building_editor")
	building.set_meta(
		"building_api_features",
		PackedStringArray([
			"versioned_building_spec",
			"polygon_floors",
			"typed_openings",
			"typed_pillars",
			"typed_roofs",
			"stairs",
			"rails",
		])
	)
	building.set_meta(
		"design_source",
		"user-provided Trinity Church reference image"
	)
	building.set_meta(
		"design_notes",
		"Cruciform red-brick church with white classical trim, terracotta roofs, "
			+ "an octagonal lantern, dark cupola, and red cross."
	)

	_add_foundation(building)
	var rooms := _add_cruciform_body(building, spec)
	_add_openings(building, rooms, spec)
	_add_pilasters(building)
	_add_cornice_and_roofs(building, spec)
	_add_lantern_and_cross(building, spec)
	_add_balustrades(building)
	building.refresh_building_geometry_clips()
	return building


func _add_foundation(building: Building3DScript) -> void:
	_add_floor_polygon(
		building,
		"StonePodium",
		_cross_points(0.65, 4.25, 9.65),
		0.65,
		STONE
	)
	_add_floor_polygon(
		building,
		"StonePodiumLowerCourse",
		_cross_points(0.16, 4.55, 9.95),
		0.16,
		STONE_SHADOW
	)
	_add_stairs(
		building,
		"FrontEntranceSteps",
		Vector3(-4.2, 0.0, -11.9),
		Vector3(4.2, 0.0, -9.55),
		0.68,
		8
	)
	_add_stairs(
		building,
		"EastEntranceSteps",
		Vector3(6.525, 0.0, -1.175),
		Vector3(14.925, 0.0, 1.175),
		0.68,
		8,
		90.0
	)
	_add_stairs(
		building,
		"WestEntranceSteps",
		Vector3(-14.925, 0.0, -1.175),
		Vector3(-6.525, 0.0, 1.175),
		0.68,
		8,
		-90.0
	)


func _add_cruciform_body(building: Building3DScript, spec) -> Dictionary:
	var base_y := 0.65
	var height: float = spec.wall_height
	var thickness: float = spec.wall_thickness
	var color: Color = spec.wall_color
	return {
		"center": _add_room(
			building,
			"CentralCrossing",
			Vector3(-4.45, base_y, -4.45),
			Vector3(4.45, base_y, 4.45),
			height,
			thickness,
			color
		),
		"front": _add_room(
			building,
			"FrontNave",
			Vector3(-3.55, base_y, -9.45),
			Vector3(3.55, base_y, -3.6),
			height,
			thickness,
			color
		),
		"rear": _add_room(
			building,
			"RearNave",
			Vector3(-3.55, base_y, 3.6),
			Vector3(3.55, base_y, 9.45),
			height,
			thickness,
			color
		),
		"west": _add_room(
			building,
			"WestTransept",
			Vector3(-9.45, base_y, -3.55),
			Vector3(-3.6, base_y, 3.55),
			height,
			thickness,
			color
		),
		"east": _add_room(
			building,
			"EastTransept",
			Vector3(3.6, base_y, -3.55),
			Vector3(9.45, base_y, 3.55),
			height,
			thickness,
			color
		),
	}


func _add_openings(
	building: Building3DScript,
	rooms: Dictionary,
	spec
) -> void:
	var front := rooms["front"] as Wall3DScript
	_add_opening(
		building,
		front,
		0,
		3.55,
		0.0,
		spec.door_style,
		spec.door_width,
		spec.door_height,
		true,
		spec
	)
	_add_opening(
		building, front, 0, 1.15, 0.82, "arched_window", 1.0, 2.4, false, spec
	)
	_add_opening(
		building, front, 0, 5.95, 0.82, "arched_window", 1.0, 2.4, false, spec
	)

	var rear := rooms["rear"] as Wall3DScript
	for distance in [1.15, 3.55, 5.95]:
		_add_opening(
			building,
			rear,
			2,
			distance,
			0.82,
			"arched_window",
			1.0,
			2.4,
			false,
			spec
		)

	var west := rooms["west"] as Wall3DScript
	var east := rooms["east"] as Wall3DScript
	for distance in [1.15, 3.55, 5.95]:
		_add_opening(
			building,
			west,
			3,
			distance,
			0.82,
			"arched_window",
			1.0,
			2.4,
			false,
			spec
		)
		_add_opening(
			building,
			east,
			1,
			distance,
			0.82,
			"arched_window",
			1.0,
			2.4,
			false,
			spec
		)

	for room_key in ["front", "rear"]:
		var room := rooms[room_key] as Wall3DScript
		_add_opening(
			building,
			room,
			1,
			2.65,
			0.82,
			"arched_window",
			1.0,
			2.4,
			false,
			spec
		)
		_add_opening(
			building,
			room,
			3,
			3.2,
			0.82,
			"arched_window",
			1.0,
			2.4,
			false,
			spec
		)


func _add_pilasters(building: Building3DScript) -> void:
	var bases := [
		Vector3(-3.48, 0.65, -9.52),
		Vector3(-1.78, 0.65, -9.52),
		Vector3(1.78, 0.65, -9.52),
		Vector3(3.48, 0.65, -9.52),
		Vector3(-9.52, 0.65, -3.48),
		Vector3(-9.52, 0.65, 0.0),
		Vector3(-9.52, 0.65, 3.48),
		Vector3(9.52, 0.65, -3.48),
		Vector3(9.52, 0.65, 0.0),
		Vector3(9.52, 0.65, 3.48),
		Vector3(-3.48, 0.65, 9.52),
		Vector3(0.0, 0.65, 9.52),
		Vector3(3.48, 0.65, 9.52),
	]
	for index in range(bases.size()):
		_add_pillar(
			building,
			"BrickPilaster%02d" % (index + 1),
			bases[index],
			0.28,
			4.8,
			"square",
			BRICK_DARK,
			0.14,
			0.07
		)


func _add_cornice_and_roofs(building: Building3DScript, spec) -> void:
	_add_flat_roof_polygon(
		building,
		"WhiteCrossCornice",
		_cross_points(5.46, 3.92, 9.82),
		0.3,
		0.24,
		CREAM
	)

	_add_roof(
		building,
		"FrontHipRoof",
		Vector3(-3.8, 5.66, -9.5),
		Vector3(3.8, 5.66, 0.3),
		spec.roof_style,
		spec.roof_angle_degrees,
		spec.roof_thickness,
		spec.roof_overhang,
		spec.roof_color
	)
	_add_roof(
		building,
		"RearHipRoof",
		Vector3(-3.8, 5.66, -0.3),
		Vector3(3.8, 5.66, 9.5),
		spec.roof_style,
		spec.roof_angle_degrees,
		spec.roof_thickness,
		spec.roof_overhang,
		spec.roof_color
	)
	_add_roof(
		building,
		"WestHipRoof",
		Vector3(-9.5, 5.68, -3.8),
		Vector3(0.3, 5.68, 3.8),
		spec.roof_style,
		spec.roof_angle_degrees,
		spec.roof_thickness,
		spec.roof_overhang,
		spec.roof_color
	)
	_add_roof(
		building,
		"EastHipRoof",
		Vector3(-0.3, 5.68, -3.8),
		Vector3(9.5, 5.68, 3.8),
		spec.roof_style,
		spec.roof_angle_degrees,
		spec.roof_thickness,
		spec.roof_overhang,
		spec.roof_color
	)

	_add_roof(
		building,
		"FrontWhitePediment",
		Vector3(-3.86, 5.72, -9.68),
		Vector3(3.86, 5.72, -7.22),
		"gable",
		34.0,
		0.2,
		0.16,
		CREAM
	)
	_add_roof(
		building,
		"EastWhitePediment",
		Vector3(7.22, 5.74, -3.86),
		Vector3(9.68, 5.74, 3.86),
		"gable",
		34.0,
		0.2,
		0.16,
		CREAM
	)
	_add_roof(
		building,
		"WestWhitePediment",
		Vector3(-9.68, 5.74, -3.86),
		Vector3(-7.22, 5.74, 3.86),
		"gable",
		34.0,
		0.2,
		0.16,
		CREAM
	)


func _add_lantern_and_cross(building: Building3DScript, spec) -> void:
	_add_pillar(
		building,
		"LanternLowerRing",
		Vector3(0.0, 7.82, 0.0),
		2.05,
		0.28,
		"round",
		CREAM,
		0.0,
		0.0,
		16
	)
	var lantern := _add_room(
		building,
		"OctagonalLantern",
		Vector3(-1.72, 8.04, -1.72),
		Vector3(1.72, 8.04, 1.72),
		1.82,
		0.2,
		BRICK_DARK,
		8
	)
	for segment_index in range(8):
		var segment = lantern.get_segment(segment_index)
		if segment == null:
			continue
		_add_opening(
			building,
			lantern,
			segment_index,
			segment.get_length() * 0.5,
			0.32,
			"grid_window",
			0.64,
			1.12,
			false,
			spec
		)
		_add_pillar(
			building,
			"LanternPilaster%02d" % (segment_index + 1),
			segment.start_point,
			0.1,
			1.82,
			"square",
			CREAM,
			0.06,
			0.03
		)
	_add_pillar(
		building,
		"LanternUpperRing",
		Vector3(0.0, 9.84, 0.0),
		2.08,
		0.26,
		"round",
		CREAM,
		0.0,
		0.0,
		16
	)
	_add_roof(
		building,
		"LanternTerracottaRoof",
		Vector3(-2.05, 10.08, -2.05),
		Vector3(2.05, 10.08, 2.05),
		"hip",
		33.0,
		0.16,
		0.18,
		TERRACOTTA
	)
	_add_roof(
		building,
		"DarkCupola",
		Vector3(-0.56, 11.35, -0.56),
		Vector3(0.56, 11.35, 0.56),
		"dome",
		58.0,
		0.12,
		0.0,
		DOME_DARK
	)
	_add_pillar(
		building,
		"CrossVertical",
		Vector3(0.0, 11.92, 0.0),
		0.09,
		1.5,
		"square",
		CROSS_RED,
		0.0,
		0.0,
		4
	)
	_add_wall(
		building,
		"CrossHorizontal",
		Vector3(-0.62, 12.84, 0.0),
		Vector3(0.62, 12.84, 0.0),
		0.18,
		0.18,
		CROSS_RED
	)


func _add_balustrades(building: Building3DScript) -> void:
	_add_rail(
		building,
		"FrontBalustradeWest",
		Vector3(-4.52, 0.68, -10.0),
		Vector3(-4.52, 0.68, -8.2)
	)
	_add_rail(
		building,
		"FrontBalustradeEast",
		Vector3(4.52, 0.68, -8.2),
		Vector3(4.52, 0.68, -10.0)
	)
	_add_rail(
		building,
		"EastBalustradeNorth",
		Vector3(8.2, 0.68, 4.52),
		Vector3(10.0, 0.68, 4.52)
	)
	_add_rail(
		building,
		"EastBalustradeSouth",
		Vector3(10.0, 0.68, -4.52),
		Vector3(8.2, 0.68, -4.52)
	)
	_add_rail(
		building,
		"WestBalustradeNorth",
		Vector3(-10.0, 0.68, 4.52),
		Vector3(-8.2, 0.68, 4.52)
	)
	_add_rail(
		building,
		"WestBalustradeSouth",
		Vector3(-8.2, 0.68, -4.52),
		Vector3(-10.0, 0.68, -4.52)
	)


func _cross_points(y: float, half_width: float, reach: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-half_width, y, -reach),
		Vector3(half_width, y, -reach),
		Vector3(half_width, y, -half_width),
		Vector3(reach, y, -half_width),
		Vector3(reach, y, half_width),
		Vector3(half_width, y, half_width),
		Vector3(half_width, y, reach),
		Vector3(-half_width, y, reach),
		Vector3(-half_width, y, half_width),
		Vector3(-reach, y, half_width),
		Vector3(-reach, y, -half_width),
		Vector3(-half_width, y, -half_width),
	])


func _add_room(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	height: float,
	thickness: float,
	color: Color,
	side_count: int = 4
) -> Wall3DScript:
	var room := BuildingFactoryScript.create_room_node(
		building,
		start,
		end,
		height,
		thickness,
		color,
		side_count
	)
	_attach(building, room, building, node_name)
	return room


func _add_floor_polygon(
	building: Building3DScript,
	node_name: String,
	points: PackedVector3Array,
	thickness: float,
	color: Color
) -> void:
	var floor := BuildingFactoryScript.create_floor_polygon_node(
		building,
		points,
		thickness,
		color
	)
	_attach(building, floor, building, node_name)


func _add_flat_roof_polygon(
	building: Building3DScript,
	node_name: String,
	points: PackedVector3Array,
	thickness: float,
	overhang: float,
	color: Color
) -> void:
	var roof := BuildingFactoryScript.create_flat_roof_polygon_node(
		building,
		points,
		thickness,
		overhang,
		color
	)
	_attach(building, roof, building, node_name)


func _add_stairs(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	height: float,
	step_count: int,
	rotation_degrees: float = 0.0
) -> void:
	var stairs := BuildingFactoryScript.create_stairs_node(
		building,
		start,
		end,
		{
			"height": height,
			"step_count": step_count,
			"thickness": 0.12,
			"color": STONE,
		}
	)
	if !is_zero_approx(rotation_degrees):
		stairs.set_stair_rotation_around_center(rotation_degrees)
	_attach(building, stairs, building, node_name)


func _add_roof(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	style: String,
	angle: float,
	thickness: float,
	overhang: float,
	color: Color
) -> void:
	var roof := BuildingFactoryScript.create_roof_node(
		building,
		start,
		end,
		style,
		angle,
		thickness,
		overhang,
		color
	)
	_attach(building, roof, building, node_name)


func _add_pillar(
	building: Building3DScript,
	node_name: String,
	base: Vector3,
	radius: float,
	height: float,
	style: String,
	color: Color,
	rim_height: float,
	rim_outset: float,
	sides: int = 8
) -> void:
	var pillar := BuildingFactoryScript.create_pillar_node(
		building,
		base,
		radius,
		height,
		sides,
		style,
		color,
		rim_height,
		rim_outset,
		rim_height,
		rim_outset
	)
	_attach(building, pillar, building, node_name)


func _add_wall(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	height: float,
	thickness: float,
	color: Color
) -> void:
	var wall := BuildingFactoryScript.create_wall_node(
		building,
		start,
		end,
		height,
		thickness,
		color
	)
	_attach(building, wall, building, node_name)


func _add_rail(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3
) -> void:
	var rail := BuildingFactoryScript.create_rail_node(
		building,
		start,
		end,
		0.72,
		0.55,
		0.055,
		0.075,
		0.16,
		STONE_SHADOW,
		4,
		2,
		0.1,
		0
	)
	_attach(building, rail, building, node_name)


func _add_opening(
	building: Building3DScript,
	wall: Wall3DScript,
	segment_index: int,
	distance: float,
	sill_height: float,
	style: String,
	width: float,
	height: float,
	allow_base_edge: bool,
	spec
) -> void:
	var is_door := style.contains("door") or style.contains("frame")
	var settings := {
		"style": style,
		"node_name": "Door" if is_door else "Window",
		"width": width,
		"height": height,
		"frame_thickness": 0.1,
		"frame_protrusion": 0.05,
		"frame_color": spec.frame_color if spec != null else CREAM,
		"window_pane_color": spec.window_pane_color if spec != null else GLASS,
		"door_panel_color": spec.door_color if spec != null else DARK_WOOD,
		"door_glass_color": GLASS,
		"show_bottom_frame": !allow_base_edge,
		"allow_base_edge": allow_base_edge,
		"pane_grid_rows": 2,
		"pane_grid_cols": 2,
		"panel_rows": 3,
		"panel_cols": 2,
		"arch_steps": 10,
	}
	var opening := BuildingFactoryScript.create_opening_node(
		wall,
		segment_index,
		distance,
		sill_height,
		-1.0,
		settings
	)
	if opening == null:
		push_warning("Could not create %s on %s." % [style, wall.name])
		return
	var opening_index := 1
	for child in wall.get_children():
		if child.owner == building:
			opening_index += 1
	_attach(
		wall,
		opening,
		building,
		"%s%02d" % [String(settings["node_name"]), opening_index]
	)
	wall.rebuild_wall_mesh()


func _attach(
	parent: Node,
	node: Node,
	scene_owner: Node,
	node_name: String
) -> void:
	node.name = node_name
	parent.add_child(node)
	node.owner = scene_owner


func _count_authored_nodes(root: Node) -> int:
	var count := 1
	for child in root.get_children():
		if child.owner == root:
			count += _count_authored_descendants(child, root)
	return count


func _count_authored_descendants(node: Node, scene_owner: Node) -> int:
	var count := 1
	for child in node.get_children():
		if child.owner == scene_owner:
			count += _count_authored_descendants(child, scene_owner)
	return count


func _write_report(report: Dictionary) -> Error:
	var file := FileAccess.open(OUTPUT_REPORT, FileAccess.WRITE)
	if file == null:
		var open_error := FileAccess.get_open_error()
		push_error("Could not write Trinity Church report (error %d)." % open_error)
		return open_error
	file.store_string(JSON.stringify(report, "\t") + "\n")
	return OK


func _finish_with_errors(errors: Array) -> void:
	var report := {
		"ok": false,
		"output": OUTPUT_SCENE,
		"preview": "",
		"resolved": {},
		"errors": errors,
		"warnings": [],
	}
	_write_report(report)
	print(JSON.stringify(report, "\t"))
	for error in errors:
		push_error(String(error))
	quit(1)
