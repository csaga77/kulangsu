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

const OUTPUT_SCENE := "res://architecture/bagua_tower/bagua_tower_stylized_3d.tscn"
const OUTPUT_PREVIEW := "res://design/examples/bagua_tower_stylized_3d.png"
const OUTPUT_CURVED_PREVIEW := (
	"res://design/examples/bagua_tower_stylized_3d_curved_facade.png"
)
const LADDER_SCRIPT_PATH := "res://game/world/ladder_3d.gd"
const TRAVERSAL_COMPLETION_SCRIPT_PATH := (
	"res://game/world/traversal_semantic_completion_area_3d.gd"
)
const PLAYER_RECOVERY_AREA_SCRIPT_PATH := (
	"res://game/world/player_recovery_area_3d.gd"
)
const FOOTPRINT_AXIS_SCALE := 0.5
const FOOTPRINT_AREA_RATIO := FOOTPRINT_AXIS_SCALE * FOOTPRINT_AXIS_SCALE
const SIMPLIFICATION_TARGET := 0.1

const CREAM := Color("#d8d0bc")
const WARM_WHITE := Color("#e8e2d5")
const STONE := Color("#a89c82")
const BRICK := Color("#b55f50")
const TERRACOTTA := Color("#a54832")
const TERRACOTTA_LIGHT := Color("#c5684d")
const DOME_RED := Color("#98293b")
const DARK_WOOD := Color("#4b302a")
const GLASS := Color("#6c8b9888")


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	var building := _build_reference_scene()
	var save_error := BuildingSpecCompilerScript.save_building(building, OUTPUT_SCENE)
	if save_error != OK:
		push_error("Could not save Bagua Tower scene (error %d)." % save_error)
		building.free()
		quit(1)
		return

	var preview_rendered := false
	var curved_preview_rendered := false
	if DisplayServer.get_name() != "headless":
		var renderer := (
			BuildingThumbnailRendererScript.new()
			as BuildingThumbnailRendererScript
		)
		var render_result: Dictionary = await renderer.render_building(
			building,
			{"entrance_segment": 0},
			OUTPUT_PREVIEW,
			Vector2i(1200, 900)
		)
		preview_rendered = bool(render_result.get("ok", false))
		if !preview_rendered:
			push_error(String(render_result.get("error", "Preview render failed.")))
		var curved_render_result: Dictionary = await renderer.render_building(
			building,
			{"entrance_segment": 2},
			OUTPUT_CURVED_PREVIEW,
			Vector2i(1200, 900)
		)
		curved_preview_rendered = bool(curved_render_result.get("ok", false))
		if !curved_preview_rendered:
			push_error(
				String(curved_render_result.get(
					"error",
					"Curved-facade preview render failed."
				))
			)
		renderer.dispose()

	print(JSON.stringify({
		"ok": save_error == OK,
		"scene": OUTPUT_SCENE,
		"preview": OUTPUT_PREVIEW if preview_rendered else "",
		"curved_preview": (
			OUTPUT_CURVED_PREVIEW if curved_preview_rendered else ""
		),
		"authored_nodes": _count_authored_nodes(building),
	}, "\t"))
	building.free()
	quit(0 if save_error == OK else 1)


func _build_reference_scene() -> Building3DScript:
	var building := Building3DScript.new() as Building3DScript
	building.name = "BaguaTowerStylized3D"
	building.set_meta("building_api", "low_poly_building_editor")
	building.set_meta("footprint_area_ratio", FOOTPRINT_AREA_RATIO)
	building.set_meta("simplification_target", SIMPLIFICATION_TARGET)
	building.set_meta(
		"building_api_features",
		PackedStringArray([
			"typed_openings",
			"polygon_floors",
			"multi_segment_rooms",
			"typed_roofs",
		])
	)
	building.set_meta(
		"design_source",
		"user-provided Bagua Tower front-elevation reference photo"
	)
	building.set_meta(
		"design_notes",
		"Reference-led low-poly massing with two brick wings, two-level galleries, a bowed classical portico, terracotta terraces, an octagonal upper platform, an arched drum, and a red dome."
	)

	_add_base_and_stairs(building)
	_add_main_storeys(building)
	_add_portico(building)
	_add_roofs_and_upper_storey(building)
	_add_drum(building)
	_add_dome(building)
	_add_stewardship_ascent(building)
	building.refresh_building_geometry_clips()
	return building


func _add_simplified_building(building: Building3DScript) -> void:
	_add_floor(
		building,
		"MainPodium",
		Vector3(-15.5, 0.6, -0.4),
		Vector3(15.5, 0.6, 11.2),
		0.6,
		STONE
	)
	var main_block := _add_room(
		building,
		"MainBlock",
		Vector3(-15.0, 0.65, 0.0),
		Vector3(15.0, 0.65, 10.5),
		5.55,
		WARM_WHITE
	)
	_add_opening(
		building,
		main_block,
		15.0,
		0.0,
		"glazed_grid_door",
		1.55,
		2.25,
		true
	)
	var left_bay := _create_wall(
		building,
		Vector3(-15.0, 0.65, -0.14),
		Vector3(-10.0, 0.65, -0.14),
		5.55,
		0.18,
		BRICK
	)
	_attach(building, left_bay, building, "LeftBrickBay")
	var right_bay := _create_wall(
		building,
		Vector3(10.0, 0.65, -0.14),
		Vector3(15.0, 0.65, -0.14),
		5.55,
		0.18,
		BRICK
	)
	_attach(building, right_bay, building, "RightBrickBay")
	for bay in [left_bay, right_bay]:
		_add_opening(
			building,
			bay,
			2.5,
			0.65,
			"arched_window",
			1.35,
			1.35,
			false
		)

	var front_stairs := BuildingFactoryScript.create_stairs_node(
		building,
		_scaled(Vector3(-1.75, 0.0, -2.05)),
		_scaled(Vector3(1.75, 0.0, -0.35)),
		{
			"height": 0.65,
			"step_count": 6,
			"thickness": 0.14,
			"color": CREAM,
		}
	)
	_attach(building, front_stairs, building, "FrontEntranceSteps")

	_add_roof(
		building,
		"MainFlatRoof",
		Vector3(-15.15, 6.28, -0.15),
		Vector3(15.15, 6.28, 10.7),
		"flat",
		0.0,
		0.2,
		0.2,
		TERRACOTTA_LIGHT
	)
	_add_roof(
		building,
		"LeftHipRoof",
		Vector3(-9.0, 6.3, 0.2),
		Vector3(-4.65, 6.3, 9.9),
		"hip",
		27.0,
		0.24,
		0.42,
		TERRACOTTA
	)
	_add_roof(
		building,
		"RightHipRoof",
		Vector3(4.65, 6.3, 0.2),
		Vector3(9.0, 6.3, 9.9),
		"hip",
		27.0,
		0.24,
		0.42,
		TERRACOTTA
	)

	_add_room(
		building,
		"UpperCentralStorey",
		Vector3(-5.2, 6.3, 2.7),
		Vector3(5.2, 6.3, 9.8),
		2.05,
		WARM_WHITE
	)
	var upper_terrace_points := PackedVector3Array([
		Vector3(-4.4, 8.48, 1.05),
		Vector3(4.4, 8.48, 1.05),
		Vector3(7.2, 8.48, 3.85),
		Vector3(7.2, 8.48, 8.35),
		Vector3(4.4, 8.48, 11.15),
		Vector3(-4.4, 8.48, 11.15),
		Vector3(-7.2, 8.48, 8.35),
		Vector3(-7.2, 8.48, 3.85),
	])
	_add_floor_polygon(
		building,
		"UpperOctagonalTerrace",
		upper_terrace_points,
		0.28,
		TERRACOTTA_LIGHT
	)

	var drum := BuildingFactoryScript.create_room_node(
		building,
		_scaled(Vector3(-2.76, 8.68, 3.34)),
		_scaled(Vector3(2.76, 8.68, 8.86)),
		2.55,
		0.2,
		CREAM,
		16
	)
	_attach(building, drum, building, "Drum")
	_add_dome(building)

	var rear_terrace_points := _curved_rear_portico_points(
		0.65,
		7.0,
		8.3,
		13.05
	)
	_add_floor_polygon(
		building,
		"RearCurvedTerrace",
		rear_terrace_points,
		0.24,
		TERRACOTTA_LIGHT
	)
	for column_index in range(3):
		var column_x := -3.0 + float(column_index) * 3.0
		var column_z := 12.0 + (0.32 if column_index == 1 else 0.0)
		_add_pillar(
			building,
			"RearPorticoColumn%02d" % (column_index + 1),
			Vector3(column_x, 0.65, column_z),
			0.29,
			5.55,
			"round",
			CREAM,
			0.13,
			0.11
		)
	_add_floor_polygon(
		building,
		"RearPorticoEntablature",
		_curved_rear_portico_points(6.25, 7.0, 8.3, 12.85),
		0.34,
		CREAM
	)


func _add_base_and_stairs(building: Building3DScript) -> void:
	_add_floor(
		building,
		"MainPodium",
		Vector3(-15.5, 0.6, -0.4),
		Vector3(15.5, 0.6, 11.2),
		0.6,
		STONE
	)
	_add_floor_polygon(
		building,
		"RearPorticoTerrace",
		_curved_rear_portico_points(0.65, 8.2, 8.3, 13.05),
		0.24,
		TERRACOTTA_LIGHT
	)
	var front_stairs := BuildingFactoryScript.create_stairs_node(
		building,
		_scaled(Vector3(-1.75, 0.0, -2.05)),
		_scaled(Vector3(1.75, 0.0, -0.35)),
		{
			"height": _scaled_length(0.65),
			"step_count": 6,
			"thickness": _scaled_length(0.14),
			"color": CREAM,
		}
	)
	_attach(building, front_stairs, building, "FrontEntranceSteps")

	var basement := _create_wall(
		building,
		Vector3(-9.0, 0.0, -0.18),
		Vector3(9.0, 0.0, -0.18),
		0.65,
		0.2,
		STONE
	)
	_attach(building, basement, building, "FrontBasementArcade")
	_add_openings(
		building,
		basement,
		[1.4, 4.0, 6.6, 9.0, 11.4, 14.0, 16.6],
		0.02,
		"arched_window",
		1.55,
		0.52
	)


func _add_main_storeys(building: Building3DScript) -> void:
	for storey in range(2):
		var base_y := 0.65 + float(storey) * 2.9
		var wall_height := 2.65
		var sill := 0.65
		var window_style := "arched_window" if storey == 0 else "grid_window"

		var left_wing := _add_room(
			building,
			"LeftWingStorey%d" % (storey + 1),
			Vector3(-15.0, base_y, 0.0),
			Vector3(-9.0, base_y, 10.5),
			wall_height,
			BRICK
		)
		_add_openings(
			building,
			left_wing,
			[1.55, 4.45],
			sill,
			window_style,
			1.35,
			1.35
		)
		_add_openings(
			building,
			left_wing,
			[1.55, 4.45],
			sill,
			window_style,
			1.35,
			1.35,
			false,
			2
		)

		var right_wing := _add_room(
			building,
			"RightWingStorey%d" % (storey + 1),
			Vector3(9.0, base_y, 0.0),
			Vector3(15.0, base_y, 10.5),
			wall_height,
			BRICK
		)
		_add_openings(
			building,
			right_wing,
			[1.55, 4.45],
			sill,
			window_style,
			1.35,
			1.35
		)
		_add_openings(
			building,
			right_wing,
			[1.55, 4.45],
			sill,
			window_style,
			1.35,
			1.35,
			false,
			2
		)

		var center := _add_room(
			building,
			"CentralGalleryStorey%d" % (storey + 1),
			Vector3(-9.0, base_y, 0.0),
			Vector3(9.0, base_y, 10.5),
			wall_height,
			CREAM
		)
		if storey == 0:
			_add_openings(
				building,
				center,
				[1.5, 4.0, 6.5, 11.5, 14.0, 16.5],
				0.56,
				"grid_window",
				1.25,
				1.4
			)
			_add_opening(
				building,
				center,
				9.0,
				0.0,
				"glazed_grid_door",
				1.55,
				2.25,
				true
			)
		else:
			_add_openings(
				building,
				center,
				[1.5, 4.0, 6.5, 9.0, 11.5, 14.0, 16.5],
				0.56,
				"grid_window",
				1.25,
				1.4
			)
		_add_openings(
			building,
			center,
			[1.8, 5.4, 9.0, 12.6, 16.2],
			0.16 if storey == 1 else 0.0,
			"double_frame",
			2.5,
			2.15 if storey == 1 else 2.2,
			true,
			2
		)

	var wing_starts: Array[float] = [-15.0, 9.0]
	var wing_names: Array[String] = ["Left", "Right"]
	for wing_index in range(wing_starts.size()):
		var wing_start := wing_starts[wing_index]
		var wing_name := wing_names[wing_index]
		_add_floor(
			building,
			"%sWingBeltCourse" % wing_name,
			Vector3(wing_start, 3.4, -0.28),
			Vector3(wing_start + 6.0, 3.4, 0.18),
			0.2,
			CREAM
		)
		_add_wall(
			building,
			"%sWingStonePlinth" % wing_name,
			Vector3(wing_start, 0.65, -0.14),
			Vector3(wing_start + 6.0, 0.65, -0.14),
			0.5,
			0.12,
			STONE
		)

	_add_floor(
		building,
		"FrontGalleryBeltCourse",
		Vector3(-9.0, 3.4, -0.28),
		Vector3(9.0, 3.4, 0.18),
		0.2,
		CREAM
	)
	var bay_pier_positions: Array[float] = [-6.25, -3.75, -1.25, 1.25, 3.75, 6.25]
	for bay_pier_index in range(bay_pier_positions.size()):
		_add_pillar(
			building,
			"FrontBayPilaster%02d" % (bay_pier_index + 1),
			Vector3(bay_pier_positions[bay_pier_index], 0.65, -0.08),
			0.14,
			5.7,
			"square",
			CREAM,
			0.05,
			0.035
		)

	var pier_positions: Array[float] = [-15.0, -9.0, 9.0, 15.0]
	for pier_index in range(pier_positions.size()):
		_add_pillar(
			building,
			"FacadePier%02d" % (pier_index + 1),
			Vector3(pier_positions[pier_index], 0.65, -0.05),
			0.34,
			5.7,
			"square",
			CREAM,
			0.12,
			0.09
		)


func _add_portico(building: Building3DScript) -> void:
	var column_points: Array[Vector3] = [
		Vector3(-5.4, 0.65, 10.9),
		Vector3(-2.7, 0.65, 12.0),
		Vector3(0.0, 0.65, 12.32),
		Vector3(2.7, 0.65, 12.0),
		Vector3(5.4, 0.65, 10.9),
	]
	for step_index in range(6):
		var progress := float(step_index) / 5.0
		var step_y := float(step_index) * 0.105
		var half_width := lerpf(3.9, 2.75, progress)
		var outer_z := lerpf(15.75, 14.65, progress)
		_add_floor_polygon(
			building,
			"RearCurvedStep%02d" % (step_index + 1),
			_curved_rear_step_points(step_y, half_width, 13.0, outer_z),
			0.12,
			CREAM
		)

	for index in range(column_points.size() - 1):
		var arcade_start := Vector3(
			column_points[index].x,
			0.0,
			column_points[index].z
		)
		var arcade_end := Vector3(
			column_points[index + 1].x,
			0.0,
			column_points[index + 1].z
		)
		var arcade_wall := _create_wall(
			building,
			arcade_start,
			arcade_end,
			0.65,
			0.2,
			STONE
		)
		_attach(
			building,
			arcade_wall,
			building,
			"RearBasementArcade%02d" % (index + 1)
		)
		var arcade_segment := arcade_wall.get_segment(0)
		if arcade_segment != null:
			_add_opening(
				building,
				arcade_wall,
				arcade_start.distance_to(arcade_end) * 0.5,
				0.02,
				"arched_window",
				1.15,
				0.52,
				false
			)

	for index in range(column_points.size()):
		_add_pillar(
			building,
			"RearPorticoColumn%02d" % (index + 1),
			column_points[index],
			0.29,
			5.55,
			"round",
			CREAM,
			0.13,
			0.11
		)

	var gallery_pier_positions: Array[float] = [-8.0, -6.0, -4.0, 4.0, 6.0, 8.0]
	for storey in range(2):
		var gallery_pier_y := 0.65 + float(storey) * 2.9
		for pier_index in range(gallery_pier_positions.size()):
			_add_pillar(
				building,
				"RearGalleryPier%d_%02d" % [storey + 1, pier_index + 1],
				Vector3(
					gallery_pier_positions[pier_index],
					gallery_pier_y,
					10.62
				),
				0.13,
				2.65,
				"square",
				CREAM,
				0.06,
				0.04
			)

	var balcony_points := _curved_rear_portico_points(3.48, 8.0, 8.35, 12.85)
	_add_floor_polygon(
		building,
		"RearGalleryBalcony",
		balcony_points,
		0.22,
		TERRACOTTA_LIGHT
	)
	for index in range(column_points.size() - 1):
		_add_rail(
			building,
			"RearGalleryBalustrade%02d" % (index + 1),
			Vector3(
				column_points[index].x,
				3.7,
				column_points[index].z
			),
			Vector3(
				column_points[index + 1].x,
				3.7,
				column_points[index + 1].z
			),
			0.7,
			CREAM,
			2,
			4
		)
	_add_rail(
		building,
		"RearLeftGalleryBalustrade",
		Vector3(-8.0, 3.7, 10.76),
		Vector3(-4.0, 3.7, 10.76),
		0.7,
		CREAM,
		3,
		4
	)
	_add_rail(
		building,
		"RearRightGalleryBalustrade",
		Vector3(4.0, 3.7, 10.76),
		Vector3(8.0, 3.7, 10.76),
		0.7,
		CREAM,
		3,
		4
	)

	_add_floor_polygon(
		building,
		"RearPorticoEntablature",
		_curved_rear_portico_points(6.25, 8.0, 8.3, 12.85),
		0.34,
		CREAM
	)


func _add_roofs_and_upper_storey(building: Building3DScript) -> void:
	_add_roof(
		building,
		"LeftHipRoof",
		Vector3(-9.0, 6.28, 0.2),
		Vector3(-4.65, 6.28, 9.9),
		"hip",
		27.0,
		0.24,
		0.42,
		TERRACOTTA
	)
	_add_roof(
		building,
		"RightHipRoof",
		Vector3(4.65, 6.28, 0.2),
		Vector3(9.0, 6.28, 9.9),
		"hip",
		27.0,
		0.24,
		0.42,
		TERRACOTTA
	)
	var roof_starts: Array[float] = [-15.15, 9.0]
	var roof_names: Array[String] = ["Left", "Right"]
	for roof_index in range(roof_starts.size()):
		var wing_start := roof_starts[roof_index]
		var wing_name := roof_names[roof_index]
		_add_roof(
			building,
			"%sWingFlatRoof" % wing_name,
			Vector3(wing_start, 6.28, -0.15),
			Vector3(wing_start + 6.15, 6.28, 10.7),
			"flat",
			0.0,
			0.2,
			0.2,
			TERRACOTTA_LIGHT
		)
		_add_roof_parapet(
			building,
			"%sWingRoofParapet" % wing_name,
			wing_start,
			wing_start + 6.15
		)

	var upper := _add_room(
		building,
		"UpperCentralStorey",
		Vector3(-5.2, 6.3, 2.7),
		Vector3(5.2, 6.3, 9.8),
		2.05,
		WARM_WHITE
	)
	_add_opening(
		building,
		upper,
		2.1,
		0.35,
		"grid_window",
		1.45,
		1.25,
		false
	)
	_add_opening(
		building,
		upper,
		2.1,
		0.35,
		"grid_window",
		1.45,
		1.25,
		false,
		2
	)
	_add_opening(
		building,
		upper,
		5.2,
		0.0,
		"double_frame",
		1.6,
		1.9,
		true,
		2
	)
	_add_opening(
		building,
		upper,
		8.3,
		0.35,
		"grid_window",
		1.45,
		1.25,
		false,
		2
	)
	_add_opening(
		building,
		upper,
		5.2,
		0.0,
		"double_frame",
		1.6,
		1.9,
		true
	)
	_add_opening(
		building,
		upper,
		8.3,
		0.35,
		"grid_window",
		1.45,
		1.25,
		false
	)
	var upper_terrace_points := PackedVector3Array([
		Vector3(-4.4, 8.48, 1.05),
		Vector3(4.4, 8.48, 1.05),
		Vector3(7.2, 8.48, 3.85),
		Vector3(7.2, 8.48, 8.35),
		Vector3(4.4, 8.48, 11.15),
		Vector3(-4.4, 8.48, 11.15),
		Vector3(-7.2, 8.48, 8.35),
		Vector3(-7.2, 8.48, 3.85),
	])
	_add_floor_polygon(
		building,
		"UpperTerrace",
		upper_terrace_points,
		0.28,
		TERRACOTTA_LIGHT
	)
	_add_wall_loop(
		building,
		"UpperTerraceParapet",
		_with_y(upper_terrace_points, 8.76),
		0.38,
		0.18,
		CREAM
	)


func _add_drum(building: Building3DScript) -> void:
	var center := Vector3(0.0, 8.68, 6.1)
	var radius := 2.76
	var side_count := 16
	for index in range(side_count):
		var angle_0 := -PI * 0.5 + TAU * float(index) / float(side_count)
		var angle_1 := -PI * 0.5 + TAU * float(index + 1) / float(side_count)
		var start := center + Vector3(cos(angle_0) * radius, 0.0, sin(angle_0) * radius)
		var end := center + Vector3(cos(angle_1) * radius, 0.0, sin(angle_1) * radius)
		var wall := _create_wall(
			building,
			start,
			end,
			2.55,
			0.2,
			CREAM
		)
		_attach(building, wall, building, "DrumWall%02d" % (index + 1))
		var segment := wall.get_segment(0)
		if segment == null:
			continue
		_add_opening(
			building,
			wall,
			start.distance_to(end) * 0.5,
			0.38,
			"arched_window",
			0.62,
			1.72,
			false
		)
		_add_pillar(
			building,
			"DrumPilaster%02d" % (index + 1),
			start,
			0.12,
			2.55,
			"square",
			CREAM,
			0.06,
			0.035
		)

	_add_pillar(
		building,
		"DrumLowerRing",
		Vector3(center.x, 8.56, center.z),
		_scaled_horizontal_length(2.96),
		0.18,
		"round",
		STONE,
		0.0,
		0.0,
		24
	)
	var balustrade_radius := 3.03
	for index in range(side_count):
		var rail_angle_0 := -PI * 0.5 + TAU * float(index) / float(side_count)
		var rail_angle_1 := -PI * 0.5 + TAU * float(index + 1) / float(side_count)
		_add_rail(
			building,
			"DrumBalustrade%02d" % (index + 1),
			Vector3(
				cos(rail_angle_0) * balustrade_radius,
				8.78,
				6.1 + sin(rail_angle_0) * balustrade_radius
			),
			Vector3(
				cos(rail_angle_1) * balustrade_radius,
				8.78,
				6.1 + sin(rail_angle_1) * balustrade_radius
			),
			0.52,
			STONE,
			2,
			2
		)
	_add_pillar(
		building,
		"DrumUpperRing",
		Vector3(center.x, 11.18, center.z),
		_scaled_horizontal_length(2.98),
		0.22,
		"round",
		CREAM,
		0.0,
		0.0,
		24
	)


func _add_dome(building: Building3DScript) -> void:
	_add_roof(
		building,
		"DomeRoof",
		Vector3(-2.9, 11.39, 3.2),
		Vector3(2.9, 11.39, 9.0),
		"dome",
		50.0,
		0.16,
		0.0,
		DOME_RED
	)


func _add_stewardship_ascent(building: Building3DScript) -> void:
	var ascent := Node3D.new()
	ascent.position = Vector3(-5.5, 0.6, 7.4)
	ascent.set_meta("optional_route", true)
	ascent.set_meta("ordinary_route_unchanged", true)
	ascent.set_meta("jump_span_m", 1.0)
	ascent.set_meta("ladder_height_m", 3.2)
	_attach(building, ascent, building, "MilestoneBStewardshipAscent")

	_add_ascent_box(
		ascent,
		building,
		"JumpApproach3x2",
		Vector3(1.5, 0.0, 0.0),
		Vector3(3.0, 0.2, 2.0),
		STONE
	)
	_add_ascent_box(
		ascent,
		building,
		"JumpLanding1_4x2",
		Vector3(4.7, 0.0, 0.0),
		Vector3(1.4, 0.2, 2.0),
		CREAM
	)
	for side_index in 2:
		var side_sign := -1.0 if side_index == 0 else 1.0
		_add_ascent_box(
			ascent,
			building,
			"JumpLaneSideRail%02d" % (side_index + 1),
			Vector3(2.7, 0.55, side_sign * 1.08),
			Vector3(5.4, 1.1, 0.1),
			DARK_WOOD
		)
	_add_ascent_box(
		ascent,
		building,
		"BottomMountPad1_2",
		Vector3(4.8, 0.12, 0.0),
		Vector3(1.2, 0.04, 1.2),
		TERRACOTTA_LIGHT
	)
	_add_ascent_box(
		ascent,
		building,
		"TopViewDeckPad1_4x1_4",
		Vector3(6.1, 3.2, 0.0),
		Vector3(1.4, 0.2, 1.4),
		CREAM
	)

	var recovery_anchor := Marker3D.new()
	recovery_anchor.position = Vector3(1.5, 0.2, 0.0)
	_attach(ascent, recovery_anchor, building, "RecoveryAnchor")
	var recovery_volume := Area3D.new()
	recovery_volume.position = Vector3(2.7, -4.25, 0.0)
	recovery_volume.add_to_group("player_recovery_volume_3d")
	_attach_optional_script(recovery_volume, PLAYER_RECOVERY_AREA_SCRIPT_PATH)
	recovery_volume.set("safe_anchor_path", NodePath("../RecoveryAnchor"))
	recovery_volume.set("drop_threshold_m", 4.0)
	_attach(ascent, recovery_volume, building, "RecoveryVolume4m")
	_add_area_box_shape(
		recovery_volume,
		building,
		"CollisionShape3D",
		Vector3(7.0, 0.5, 3.0)
	)

	var jump_completion := Area3D.new()
	jump_completion.position = Vector3(4.7, 0.22, 0.0)
	_attach_optional_script(jump_completion, TRAVERSAL_COMPLETION_SCRIPT_PATH)
	jump_completion.set("semantic_completion_id", &"bagua_stewardship_jump_crossed")
	jump_completion.set("require_grounded", true)
	jump_completion.set("one_shot_per_entry", true)
	_attach(ascent, jump_completion, building, "JumpCompletionArea")
	_add_area_box_shape(
		jump_completion,
		building,
		"CollisionShape3D",
		Vector3(1.2, 0.35, 1.8)
	)

	var ladder := Node3D.new()
	ladder.position = Vector3(5.4, 0.2, 0.0)
	_attach_optional_script(ladder, LADDER_SCRIPT_PATH)
	ladder.set_meta("skip_runtime_collision", true)
	ladder.set("action_id", &"ladder")
	ladder.set("action_label", "Climb Service Ladder")
	ladder.set("action_priority", -10)
	ladder.set("interaction_range", 0.9)
	ladder.set("facing_tolerance_degrees", 20.0)
	ladder.set("action_anchor_path", NodePath("BottomMount"))
	ladder.set("bottom_mount_path", NodePath("BottomMount"))
	ladder.set("top_mount_path", NodePath("TopMount"))
	ladder.set("bottom_exit_path", NodePath("BottomExit"))
	ladder.set("top_exit_path", NodePath("TopExit"))
	ladder.set("climb_speed", 1.8)
	ladder.set("alignment_duration", 0.3)
	ladder.set("endpoint_clearance", 0.75)
	ladder.set("blocked_retreat_distance", 0.35)
	ladder.set("semantic_completion_id", &"bagua_stewardship_ladder_ascended")
	_attach(ascent, ladder, building, "ServiceLadder3_2m")
	_add_ladder_markers(ladder, building)
	_add_ladder_visuals(ladder, building)
	_add_top_endpoint_blocker(ladder, building)


func _add_ascent_box(
	parent: Node3D,
	scene_owner: Node,
	node_name: String,
	center: Vector3,
	size: Vector3,
	color: Color
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = center
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	mesh_instance.material_override = material
	_attach(parent, mesh_instance, scene_owner, node_name)


func _add_area_box_shape(
	parent: Area3D,
	scene_owner: Node,
	node_name: String,
	size: Vector3
) -> void:
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	_attach(parent, collision_shape, scene_owner, node_name)


func _add_ladder_markers(ladder: Node3D, scene_owner: Node) -> void:
	var marker_positions := {
		"BottomMount": Vector3(-0.6, 0.0, 0.0),
		"BottomExit": Vector3(-0.75, 0.0, 0.0),
		"TopMount": Vector3(0.0, 3.2, 0.0),
		"TopExit": Vector3(0.75, 3.2, 0.0),
	}
	for marker_name in marker_positions:
		var marker := Marker3D.new()
		marker.position = marker_positions[marker_name]
		_attach(ladder, marker, scene_owner, marker_name)


func _add_ladder_visuals(ladder: Node3D, scene_owner: Node) -> void:
	for rail_index in 2:
		var rail_sign := -1.0 if rail_index == 0 else 1.0
		_add_ascent_box(
			ladder,
			scene_owner,
			"Rail%02d" % (rail_index + 1),
			Vector3(0.0, 1.6, rail_sign * 0.35),
			Vector3(0.08, 3.2, 0.08),
			DARK_WOOD
		)
	for rung_index in 9:
		_add_ascent_box(
			ladder,
			scene_owner,
			"Rung%02d" % (rung_index + 1),
			Vector3(-0.04, 0.2 + float(rung_index) * 0.35, 0.0),
			Vector3(0.08, 0.06, 0.78),
			DARK_WOOD
		)


func _add_top_endpoint_blocker(ladder: Node3D, scene_owner: Node) -> void:
	var blocker := StaticBody3D.new()
	blocker.position = Vector3(0.75, 3.75, 0.0)
	blocker.set_meta("validation_toggle", true)
	_attach(ladder, blocker, scene_owner, "TopEndpointBlocker")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 0.3, 0.3)
	shape_node.shape = shape
	shape_node.disabled = true
	_attach(blocker, shape_node, scene_owner, "CollisionShape3D")


func _attach_optional_script(node: Node, script_path: String) -> void:
	if ResourceLoader.exists(script_path):
		node.set_script(load(script_path))
	else:
		node.set_meta("planned_script_path", script_path)


func _add_room(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	height: float,
	color: Color
) -> Wall3DScript:
	var room := BuildingFactoryScript.create_room_node(
		building,
		_scaled(start),
		_scaled(end),
		_scaled_length(height),
		_scaled_length(0.24),
		color
	)
	_attach(building, room, building, node_name)
	return room


func _add_floor(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	thickness: float,
	color: Color
) -> void:
	var floor := BuildingFactoryScript.create_floor_node(
		building,
		_scaled(start),
		_scaled(end),
		_scaled_length(thickness),
		color
	)
	_attach(building, floor, building, node_name)


func _add_floor_polygon(
	building: Building3DScript,
	node_name: String,
	points: PackedVector3Array,
	thickness: float,
	color: Color
) -> void:
	var floor := BuildingFactoryScript.create_floor_polygon_node(
		building,
		_scaled_points(points),
		_scaled_length(thickness),
		color
	)
	_attach(building, floor, building, node_name)


func _add_wall(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	height: float,
	thickness: float,
	color: Color
) -> void:
	var wall := _create_wall(
		building,
		start,
		end,
		height,
		thickness,
		color
	)
	_attach(building, wall, building, node_name)


func _create_wall(
	building: Building3DScript,
	start: Vector3,
	end: Vector3,
	height: float,
	thickness: float,
	color: Color
) -> Wall3DScript:
	return BuildingFactoryScript.create_wall_node(
		building,
		_scaled(start),
		_scaled(end),
		_scaled_length(height),
		_scaled_length(thickness),
		color
	)


func _add_wall_loop(
	building: Building3DScript,
	node_name: String,
	points: PackedVector3Array,
	height: float,
	thickness: float,
	color: Color
) -> void:
	for index in range(points.size()):
		_add_wall(
			building,
			"%s%02d" % [node_name, index + 1],
			points[index],
			points[(index + 1) % points.size()],
			height,
			thickness,
			color
		)


func _add_rail(
	building: Building3DScript,
	node_name: String,
	start: Vector3,
	end: Vector3,
	height: float,
	color: Color,
	newel_count: int,
	infill_count: int
) -> void:
	var rail := BuildingFactoryScript.create_rail_node(
		building,
		_scaled(start),
		_scaled(end),
		_scaled_length(height),
		_scaled_length(1.0),
		_scaled_length(0.055),
		_scaled_length(0.09),
		_scaled_length(0.12),
		color,
		newel_count,
		infill_count,
		_scaled_length(0.11),
		0
	)
	_attach(building, rail, building, node_name)


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
		_scaled(start),
		_scaled(end),
		style,
		angle,
		_scaled_length(thickness),
		_scaled_length(overhang),
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
	sides: int = 12
) -> void:
	var pillar := BuildingFactoryScript.create_pillar_node(
		building,
		_scaled(base),
		_scaled_length(radius),
		_scaled_length(height),
		sides,
		style,
		color,
		_scaled_length(rim_height),
		_scaled_length(rim_outset),
		_scaled_length(rim_height),
		_scaled_length(rim_outset)
	)
	_attach(building, pillar, building, node_name)


func _add_roof_parapet(
	building: Building3DScript,
	node_name: String,
	start_x: float,
	end_x: float
) -> void:
	var points := PackedVector3Array([
		Vector3(start_x, 6.48, -0.28),
		Vector3(end_x, 6.48, -0.28),
		Vector3(end_x, 6.48, 10.82),
		Vector3(start_x, 6.48, 10.82),
	])
	_add_wall_loop(building, node_name, points, 0.42, 0.18, CREAM)


func _curved_rear_portico_points(
	y: float,
	half_width: float,
	inner_z: float,
	rear_z: float
) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-half_width, y, inner_z),
		Vector3(-half_width, y, 10.05),
		Vector3(-half_width * 0.72, y, 11.28),
		Vector3(-half_width * 0.36, y, rear_z - 0.35),
		Vector3(0.0, y, rear_z),
		Vector3(half_width * 0.36, y, rear_z - 0.35),
		Vector3(half_width * 0.72, y, 11.28),
		Vector3(half_width, y, 10.05),
		Vector3(half_width, y, inner_z),
	])


func _curved_rear_step_points(
	y: float,
	half_width: float,
	inner_z: float,
	outer_z: float
) -> PackedVector3Array:
	var depth := outer_z - inner_z
	return PackedVector3Array([
		Vector3(-half_width, y, inner_z),
		Vector3(-half_width * 0.96, y, outer_z - depth * 0.42),
		Vector3(-half_width * 0.7, y, outer_z - depth * 0.14),
		Vector3(-half_width * 0.36, y, outer_z - depth * 0.03),
		Vector3(0.0, y, outer_z),
		Vector3(half_width * 0.36, y, outer_z - depth * 0.03),
		Vector3(half_width * 0.7, y, outer_z - depth * 0.14),
		Vector3(half_width * 0.96, y, outer_z - depth * 0.42),
		Vector3(half_width, y, inner_z),
	])


func _with_y(points: PackedVector3Array, y: float) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point in points:
		result.append(Vector3(point.x, y, point.z))
	return result


func _add_openings(
	building: Building3DScript,
	wall: Wall3DScript,
	positions: Array[float],
	sill_height: float,
	style: String,
	width: float,
	height: float,
	allow_base_edge: bool = false,
	segment_index: int = 0
) -> void:
	for position in positions:
		_add_opening(
			building,
			wall,
			position,
			sill_height,
			style,
			width,
			height,
			allow_base_edge,
			segment_index
		)


func _add_opening(
	building: Building3DScript,
	wall: Wall3DScript,
	distance: float,
	sill_height: float,
	style: String,
	width: float,
	height: float,
	allow_base_edge: bool,
	segment_index: int = 0
) -> void:
	var is_door := style.contains("door") or style.contains("frame")
	var settings := {
		"style": style,
		"node_name": "Door" if is_door else "Window",
		"width": _scaled_length(width),
		"height": _scaled_length(height),
		"frame_thickness": _scaled_length(0.09),
		"frame_depth": _scaled_length(0.08),
		"frame_protrusion": _scaled_length(0.02),
		"frame_color": CREAM,
		"window_pane_depth": _scaled_length(0.03),
		"window_pane_color": GLASS,
		"door_panel_depth": _scaled_length(0.05),
		"door_panel_color": DARK_WOOD,
		"door_glass_depth": _scaled_length(0.025),
		"door_glass_color": GLASS,
		"show_bottom_frame": !allow_base_edge,
		"allow_base_edge": allow_base_edge,
		"pane_grid_rows": 2,
		"pane_grid_cols": 2,
		"arch_steps": 10,
	}
	var opening := BuildingFactoryScript.create_opening_node(
		wall,
		segment_index,
		_scaled_horizontal_length(distance),
		_scaled_length(sill_height),
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


func _scaled(point: Vector3) -> Vector3:
	return Vector3(
		point.x * FOOTPRINT_AXIS_SCALE,
		point.y,
		point.z * FOOTPRINT_AXIS_SCALE
	)


func _scaled_points(points: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point in points:
		result.append(_scaled(point))
	return result


func _scaled_length(value: float) -> float:
	return value


func _scaled_horizontal_length(value: float) -> float:
	return value * FOOTPRINT_AXIS_SCALE


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
