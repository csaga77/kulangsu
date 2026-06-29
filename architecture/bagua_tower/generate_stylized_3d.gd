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
	"res://addons/low_poly_building_editor/wall_3d.gd"
)

const OUTPUT_SCENE := "res://architecture/bagua_tower/bagua_tower_stylized_3d.tscn"
const OUTPUT_PREVIEW := "res://design/examples/bagua_tower_stylized_3d.png"

const CREAM := Color("#d8d0bc")
const WARM_WHITE := Color("#e8e2d5")
const STONE := Color("#a89c82")
const TERRACOTTA := Color("#a54832")
const TERRACOTTA_LIGHT := Color("#c5684d")
const DOME_RED := Color("#8f2638")
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
		renderer.dispose()

	print(JSON.stringify({
		"ok": save_error == OK,
		"scene": OUTPUT_SCENE,
		"preview": OUTPUT_PREVIEW if preview_rendered else "",
		"authored_nodes": _count_authored_nodes(building),
	}, "\t"))
	building.free()
	quit(0 if save_error == OK else 1)


func _build_reference_scene() -> Building3DScript:
	var building := Building3DScript.new() as Building3DScript
	building.name = "BaguaTowerStylized3D"
	building.set_meta("building_api", "low_poly_building_editor")
	building.set_meta("design_source", "user-provided Bagua Tower reference photo")
	building.set_meta(
		"design_notes",
		"Symmetrical colonial wings, curved colonnade, terracotta roofs, drum, and red dome."
	)

	_add_base_and_stairs(building)
	_add_main_storeys(building)
	_add_portico(building)
	_add_roofs_and_upper_storey(building)
	_add_drum(building)
	_add_dome(building)
	building.refresh_building_geometry_clips()
	return building


func _add_base_and_stairs(building: Building3DScript) -> void:
	_add_floor(
		building,
		"MainPodium",
		Vector3(-15.5, 0.6, -0.4),
		Vector3(15.5, 0.6, 11.2),
		0.6,
		STONE
	)
	_add_floor(
		building,
		"PorticoTerrace",
		Vector3(-8.2, 0.65, -2.8),
		Vector3(8.2, 0.65, 2.2),
		0.24,
		TERRACOTTA_LIGHT
	)
	var stairs := BuildingFactoryScript.create_stairs_node(
		building,
		Vector3(-2.8, 0.0, -5.2),
		Vector3(2.8, 0.0, -2.75),
		0.65,
		6,
		0.16,
		CREAM,
		0.0
	)
	_attach(building, stairs, building, "FrontSteps")


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
			WARM_WHITE
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

		var right_wing := _add_room(
			building,
			"RightWingStorey%d" % (storey + 1),
			Vector3(9.0, base_y, 0.0),
			Vector3(15.0, base_y, 10.5),
			wall_height,
			WARM_WHITE
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

		var center := _add_room(
			building,
			"CentralGalleryStorey%d" % (storey + 1),
			Vector3(-9.0, base_y, 1.8),
			Vector3(9.0, base_y, 10.5),
			wall_height,
			CREAM
		)
		if storey == 0:
			_add_openings(
				building,
				center,
				[3.0, 6.0, 9.0, 12.0, 15.0],
				0.0,
				"double_frame",
				1.55,
				2.2,
				true
			)
		else:
			_add_openings(
				building,
				center,
				[2.4, 5.7, 9.0, 12.3, 15.6],
				0.58,
				"arched_window",
				1.35,
				1.45
			)

	_add_floor(
		building,
		"GalleryBalcony",
		Vector3(-9.2, 3.48, 0.7),
		Vector3(9.2, 3.48, 3.0),
		0.22,
		TERRACOTTA_LIGHT
	)

	for x in [-15.0, -9.0, 9.0, 15.0]:
		_add_pillar(
			building,
			"FacadePier",
			Vector3(x, 0.65, -0.05),
			0.34,
			5.7,
			"square",
			CREAM,
			0.12,
			0.09
		)


func _add_portico(building: Building3DScript) -> void:
	var column_points: Array[Vector3] = [
		Vector3(-7.2, 0.65, 0.55),
		Vector3(-5.4, 0.65, -0.45),
		Vector3(-3.6, 0.65, -1.25),
		Vector3(-1.8, 0.65, -1.72),
		Vector3(0.0, 0.65, -1.88),
		Vector3(1.8, 0.65, -1.72),
		Vector3(3.6, 0.65, -1.25),
		Vector3(5.4, 0.65, -0.45),
		Vector3(7.2, 0.65, 0.55),
	]
	for index in range(column_points.size()):
		_add_pillar(
			building,
			"PorticoColumn%02d" % (index + 1),
			column_points[index],
			0.29,
			5.55,
			"round",
			CREAM,
			0.13,
			0.11
		)

	_add_floor(
		building,
		"PorticoEntablature",
		Vector3(-8.0, 6.25, -2.45),
		Vector3(8.0, 6.25, 2.25),
		0.34,
		CREAM
	)


func _add_roofs_and_upper_storey(building: Building3DScript) -> void:
	_add_roof(
		building,
		"LeftHipRoof",
		Vector3(-15.1, 6.28, -0.1),
		Vector3(-4.8, 6.28, 10.7),
		"hip",
		24.0,
		0.24,
		0.42,
		TERRACOTTA
	)
	_add_roof(
		building,
		"RightHipRoof",
		Vector3(4.8, 6.28, -0.1),
		Vector3(15.1, 6.28, 10.7),
		"hip",
		24.0,
		0.24,
		0.42,
		TERRACOTTA
	)

	var upper := _add_room(
		building,
		"UpperCentralStorey",
		Vector3(-5.2, 6.3, 2.7),
		Vector3(5.2, 6.3, 9.8),
		2.05,
		WARM_WHITE
	)
	_add_openings(
		building,
		upper,
		[2.1, 5.2, 8.3],
		0.35,
		"grid_window",
		1.45,
		1.25
	)
	_add_floor(
		building,
		"UpperTerrace",
		Vector3(-6.1, 8.48, 1.9),
		Vector3(6.1, 8.48, 10.6),
		0.28,
		TERRACOTTA_LIGHT
	)


func _add_drum(building: Building3DScript) -> void:
	var center := Vector3(0.0, 8.68, 6.1)
	var radius := 2.72
	var side_count := 12
	for index in range(side_count):
		var angle_0 := -PI * 0.5 + TAU * float(index) / float(side_count)
		var angle_1 := -PI * 0.5 + TAU * float(index + 1) / float(side_count)
		var start := center + Vector3(cos(angle_0) * radius, 0.0, sin(angle_0) * radius)
		var end := center + Vector3(cos(angle_1) * radius, 0.0, sin(angle_1) * radius)
		var wall := BuildingFactoryScript.create_wall_node(
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
			segment.get_length() * 0.5,
			0.38,
			"arched_window",
			0.72,
			1.72,
			false
		)

	_add_pillar(
		building,
		"DrumLowerRing",
		Vector3(center.x, 8.56, center.z),
		2.96,
		0.18,
		"round",
		STONE,
		0.0,
		0.0,
		24
	)
	_add_pillar(
		building,
		"DrumUpperRing",
		Vector3(center.x, 11.18, center.z),
		2.98,
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
		Vector3(-2.86, 11.39, 3.24),
		Vector3(2.86, 11.39, 8.96),
		"dome",
		45.0,
		0.16,
		0.0,
		DOME_RED
	)


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
		start,
		end,
		height,
		0.24,
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
		start,
		end,
		thickness,
		color
	)
	_attach(building, floor, building, node_name)


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
	sides: int = 12
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


func _add_openings(
	building: Building3DScript,
	wall: Wall3DScript,
	positions: Array[float],
	sill_height: float,
	style: String,
	width: float,
	height: float,
	allow_base_edge: bool = false
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
			allow_base_edge
		)


func _add_opening(
	building: Building3DScript,
	wall: Wall3DScript,
	distance: float,
	sill_height: float,
	style: String,
	width: float,
	height: float,
	allow_base_edge: bool
) -> void:
	var is_door := style.contains("door") or style.contains("frame")
	var settings := {
		"style": style,
		"node_name": "Door" if is_door else "Window",
		"width": width,
		"height": height,
		"frame_thickness": 0.09,
		"frame_color": CREAM,
		"window_pane_color": GLASS,
		"door_panel_color": DARK_WOOD,
		"door_glass_color": GLASS,
		"show_bottom_frame": !allow_base_edge,
		"allow_base_edge": allow_base_edge,
		"pane_grid_rows": 2,
		"pane_grid_cols": 2,
		"arch_steps": 10,
	}
	var opening := BuildingFactoryScript.create_opening_node(
		wall,
		0,
		distance,
		sill_height,
		-1.0,
		settings,
		true
	)
	if opening == null:
		push_warning("Could not create %s on %s." % [style, wall.name])
		return
	_attach(wall, opening, building, String(settings["node_name"]))
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
