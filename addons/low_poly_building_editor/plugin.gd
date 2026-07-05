@tool
extends EditorPlugin

const _DOCK_SLOT := EditorDock.DOCK_SLOT_RIGHT_UL
const MODE_SELECT := "select"
const MODE_WALL := "wall"
const MODE_FLOOR := "floor"
const MODE_STAIRS := "stairs"
const MODE_RAIL := "rail"
const MODE_PILLAR := "pillar"
const MODE_ROOF := "roof"
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const MODE_DOOR := "door"
const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floors/floor_3d.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs/stairs_3d.gd")
const Rail3DScript = preload("res://addons/low_poly_building_editor/rails/rail_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillars/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roofs/roof_3d.gd")
const FlatRoof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/flat_roof_3d.gd"
)
const RoofStyleGeometryFactory := preload(
	"res://addons/low_poly_building_editor/roofs/roof_style_geometry_factory_3d.gd"
)
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/openings/building_opening_3d.gd")
const BuildingWireframeScript = preload("res://addons/low_poly_building_editor/building_wireframe.gd")
const Window3DScript = preload("res://addons/low_poly_building_editor/openings/window_3d.gd")
const Door3DScript = preload("res://addons/low_poly_building_editor/openings/door_3d.gd")
const WallSegmentScript = preload("res://addons/low_poly_building_editor/walls/wall_segment.gd")
const DockScript = preload("res://addons/low_poly_building_editor/low_poly_building_editor_dock.gd")
const ViewportInputOverlayScript = preload("res://addons/low_poly_building_editor/viewport_input_overlay.gd")
const ViewportInputCaptureScript = preload("res://addons/low_poly_building_editor/viewport_input_capture.gd")
const BuildingToolContextScript = preload("res://addons/low_poly_building_editor/editor/building_tool_context.gd")
const NativeToolbarIntegrationScript = preload("res://addons/low_poly_building_editor/editor/native_toolbar_integration.gd")
const BuildingToolControllerScript = preload("res://addons/low_poly_building_editor/editor/building_tool_controller.gd")
const PillarToolControllerScript = preload("res://addons/low_poly_building_editor/editor/pillar_tool_controller.gd")
const RailToolControllerScript = preload("res://addons/low_poly_building_editor/editor/rail_tool_controller.gd")
const StairsToolControllerScript = preload("res://addons/low_poly_building_editor/editor/stairs_tool_controller.gd")
const WALL_DRAG_COMMIT_DISTANCE := 6.0
const FLOOR_EDIT_MOVE := 0
const FLOOR_EDIT_MIN_X := 1
const FLOOR_EDIT_MAX_X := 2
const FLOOR_EDIT_MIN_Z := 4
const FLOOR_EDIT_MAX_Z := 8
const FLOOR_EDIT_POLYGON_VERTEX := 16
const FLOOR_EDIT_POLYGON_EDGE := 32
const WALL_TYPE_WALL := "wall"
const WALL_TYPE_ROOM := "room"
const FLOOR_TYPE_SOLID := "solid"
const FLOOR_TYPE_HOLE := "hole"
const FLOOR_STYLE_RECTANGLE := "rectangle"
const FLOOR_STYLE_POLYGON := "polygon"
const OPENING_SILL_META := BuildingFactoryScript.OPENING_SILL_META
const OPENING_ALLOW_BASE_META := BuildingFactoryScript.OPENING_ALLOW_BASE_META
const BUILDING_PROP_META := &"low_poly_building_editor_prop"

var m_dock: Control
var m_editor_dock: EditorDock
var m_input_capture: Node
var m_viewport_overlays: Array[Control] = []
var m_tool_mode := MODE_SELECT
var m_context: BuildingToolContextScript
var m_native_toolbar: NativeToolbarIntegrationScript
var m_tool_controllers := {}
var m_active_coordinator: Building3DScript
var m_display_settings := {
	"wireframe": false,
	"wireframe_xray": false,
	"wireframe_color": Color(0.05, 0.95, 1.0, 1.0),
}
var m_wall_settings := {
	"grid_step": 0.5,
	"type": WALL_TYPE_WALL,
	"room_sides": 4,
	"base_height": 0.0,
	"height": 2.4,
	"thickness": 0.22,
	"color": Color(0.78, 0.68, 0.54, 1.0),
	"lock_8_way": true,
}
var m_floor_settings := {
	"grid_step": 0.5,
	"type": FLOOR_TYPE_SOLID,
	"style": FLOOR_STYLE_RECTANGLE,
	"base_height": 0.0,
	"thickness": 0.12,
	"color": Color(0.46, 0.40, 0.32, 1.0),
}
var m_roof_settings := {
	"grid_step": 0.5,
	"style": "gable",
	"footprint_style": FLOOR_STYLE_RECTANGLE,
	"base_height": 2.4,
	"height": 40.0,
	"thickness": 0.12,
	"overhang": 0.2,
	"hip_gable_height": 0.0,
	"rotation_degrees": 0.0,
	"color": Color(0.50, 0.34, 0.25, 1.0),
}
var m_prop_settings := {
	"scene_path": "",
	"clearance": 0.25,
}
var m_window_settings := {
	"style": "single_window",
	"width": 1.0,
	"height": 1.0,
	"frame_thickness": 0.08,
	"sill_height": 0.9,
	"frame_sides": 0,
	"frame_protrusion": 0.02,
	"frame_color": Color(0.86, 0.92, 0.94, 1.0),
	"window_pane_depth": 0.03,
	"window_pane_color": Color(0.58, 0.82, 0.95, 0.52),
	"pane_grid_rows": 2,
	"pane_grid_cols": 1,
	"muntin_thickness": 0.03,
	"louver_count": 6,
	"louver_depth": 0.03,
	"transom_ratio": 0.28,
	"transom_rail_thickness": 0.03,
	"arch_steps": 3,
}
var m_door_settings := {
	"style": "single_door",
	"width": 0.9,
	"height": 2.1,
	"frame_thickness": 0.08,
	"frame_sides": 0,
	"frame_protrusion": 0.02,
	"frame_color": Color(0.86, 0.92, 0.94, 1.0),
	"door_panel_depth": 0.05,
	"door_panel_color": Color(0.50, 0.34, 0.20, 1.0),
	"door_glazing_ratio": 0.55,
	"door_glass_depth": 0.03,
	"door_glass_color": Color(0.58, 0.82, 0.95, 0.52),
	"pane_grid_rows": 2,
	"pane_grid_cols": 1,
	"muntin_thickness": 0.03,
	"door_inset_rows": 3,
	"door_inset_cols": 2,
}
var m_wall_start_local := Vector3.ZERO
var m_wall_end_local := Vector3.ZERO
var m_wall_start_screen_position := Vector2.ZERO
var m_wall_has_valid_preview := false
var m_wall_release_commits_preview := false
var m_is_drawing_wall := false
var m_wall_preview: Wall3DScript
var m_floor_start_local := Vector3.ZERO
var m_floor_end_local := Vector3.ZERO
var m_floor_start_screen_position := Vector2.ZERO
var m_floor_has_valid_preview := false
var m_floor_release_commits_preview := false
var m_is_drawing_floor := false
var m_floor_preview: Floor3DScript
var m_floor_polygon_points := PackedVector3Array()
var m_dragging_floor: Floor3DScript
var m_drag_floor_old_start := Vector3.ZERO
var m_drag_floor_old_end := Vector3.ZERO
var m_drag_floor_old_polygon := PackedVector3Array()
var m_drag_floor_old_holes: Array[Rect2] = []
var m_drag_floor_started_as_polygon := false
var m_drag_floor_vertex_index := -1
var m_drag_floor_edge_index := -1
var m_drag_floor_hole_index := -1
var m_drag_floor_hole_old_polygons: Array[PackedVector2Array] = []
var m_drag_floor_anchor_local := Vector3.ZERO
var m_drag_floor_edit_mask := FLOOR_EDIT_MOVE
var m_drag_floor_active_material: Material
var m_drag_floor_hover: Floor3DScript
var m_drag_floor_hover_material: Material
var m_drag_floor_hover_edit_mask := FLOOR_EDIT_MOVE
var m_roof_start_local := Vector3.ZERO
var m_roof_end_local := Vector3.ZERO
var m_roof_start_screen_position := Vector2.ZERO
var m_roof_has_valid_preview := false
var m_roof_release_commits_preview := false
var m_roof_draw_rotation_degrees := 0.0
var m_is_drawing_roof := false
var m_roof_preview: Roof3DScript
var m_roof_polygon_points := PackedVector3Array()
var m_dragging_roof: Roof3DScript
var m_drag_roof_old_start := Vector3.ZERO
var m_drag_roof_old_end := Vector3.ZERO
var m_drag_roof_old_polygon := PackedVector3Array()
var m_drag_roof_started_as_polygon := false
var m_drag_roof_vertex_index := -1
var m_drag_roof_edge_index := -1
var m_drag_roof_old_rotation_degrees := 0.0
var m_drag_roof_old_height := 0.0
var m_drag_roof_old_covered_rects: Array[Rect2] = []
var m_drag_roof_old_covered_polygons: Array[PackedVector2Array] = []
var m_drag_roof_anchor_local := Vector3.ZERO
var m_drag_roof_plane_y := 0.0
var m_drag_roof_edit_mask := FLOOR_EDIT_MOVE
var m_drag_roof_active_material: Material
var m_drag_roof_hover: Roof3DScript
var m_drag_roof_hover_material: Material
var m_drag_roof_hover_edit_mask := FLOOR_EDIT_MOVE
var m_prop_preview: Node3D
var m_prop_preview_path := ""
var m_prop_rotation_y := 0.0
var m_preview_valid := false
var m_preview_parent: Node
var m_preview_wall: Wall3DScript
var m_dragging_wall: Wall3DScript
var m_drag_wall_old_start: Vector3
var m_drag_wall_old_end: Vector3
var m_drag_wall_old_segments: Array[WallSegmentScript] = []
var m_drag_wall_opening_anchors: Array = []
var m_drag_wall_anchor_local: Vector3
var m_drag_wall_segment_index := 0
var m_drag_wall_endpoint := -1   # -1=full move, 0=start pt, 1=end pt
var m_drag_wall_joint_origin := Vector3.ZERO
var m_drag_wall_dragging_joint := false
var m_drag_wall_detaching_joint := false
var m_drag_wall_has_connection_snap := false
var m_drag_wall_resizing_room_side := false
var m_drag_wall_hover: Wall3DScript
var m_drag_wall_hover_material: Material
var m_drag_wall_hover_segment := 0
var m_drag_wall_hover_endpoint := -1
var m_drag_wall_hover_has_joint := false
var m_drag_wall_hover_joint_position := Vector3.ZERO
var m_drag_wall_hover_joint_marker: MeshInstance3D
var m_drag_wall_active_material: Material
var m_dragging_opening: BuildingOpening3DScript
var m_drag_old_position: Vector3
var m_drag_old_segment: int
var m_drag_target_segment: int
var m_drag_face_sign := 1.0
var m_drag_valid := false
var m_drag_opening_edge := -1    # -1=move, 0=left, 1=right, 2=bottom, 3=top
var m_drag_opening_old_width := 0.0
var m_drag_opening_old_height := 0.0
var m_drag_opening_old_frame_color := Color.WHITE
var m_drag_resize_anchor_2d := Vector2.ZERO
var m_drag_resize_center_2d := Vector2.ZERO
var m_drag_hover_opening: BuildingOpening3DScript
var m_drag_hover_old_color: Color
var m_drag_hover_edge := -1
var m_opening_custom_types: Array[Dictionary] = []
var m_building_style_custom_types: Array[Dictionary] = []


func _enter_tree() -> void:
	m_context = BuildingToolContextScript.new(self)
	m_native_toolbar = NativeToolbarIntegrationScript.new(self)
	m_tool_controllers[MODE_PILLAR] = PillarToolControllerScript.new(m_context)
	m_tool_controllers[MODE_RAIL] = RailToolControllerScript.new(m_context)
	m_tool_controllers[MODE_STAIRS] = StairsToolControllerScript.new(m_context)
	m_opening_custom_types = BuildingFactoryScript.get_opening_custom_types()
	m_building_style_custom_types = BuildingFactoryScript.get_building_style_custom_types()
	add_custom_type(
		"Building3D",
		"Node3D",
		Building3DScript,
		_get_editor_icon(&"Node3D")
	)
	add_custom_type(
		"Wall3D",
		"MeshInstance3D",
		Wall3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"Floor3D",
		"MeshInstance3D",
		Floor3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"Rail3D",
		"MeshInstance3D",
		Rail3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	for style_type: Dictionary in m_building_style_custom_types:
		add_custom_type(
			String(style_type["name"]),
			"MeshInstance3D",
			style_type["script"],
			_get_editor_icon(&"MeshInstance3D")
		)
	for opening_type: Dictionary in m_opening_custom_types:
		add_custom_type(
			String(opening_type["name"]),
			"Node3D",
			opening_type["script"],
			_get_editor_icon(&"Window")
		)
	set_input_event_forwarding_always_enabled()

	m_dock = DockScript.new() as Control
	m_dock.name = "Building Editor"
	if m_dock.has_method("setup"):
		m_dock.setup(get_editor_interface())
	m_dock.connect("tool_mode_changed", Callable(self, "_on_tool_mode_changed"))
	m_dock.connect("display_settings_changed", Callable(self, "_on_display_settings_changed"))
	m_dock.connect("wall_settings_changed", Callable(self, "_on_wall_settings_changed"))
	m_dock.connect("floor_settings_changed", Callable(self, "_on_floor_settings_changed"))
	m_dock.connect("stair_settings_changed", Callable(self, "_on_stair_settings_changed"))
	m_dock.connect("rail_settings_changed", Callable(self, "_on_rail_settings_changed"))
	m_dock.connect("pillar_settings_changed", Callable(self, "_on_pillar_settings_changed"))
	m_dock.connect("roof_settings_changed", Callable(self, "_on_roof_settings_changed"))
	m_dock.connect("prop_settings_changed", Callable(self, "_on_prop_settings_changed"))
	m_dock.connect("window_settings_changed", Callable(self, "_on_window_settings_changed"))
	m_dock.connect("door_settings_changed", Callable(self, "_on_door_settings_changed"))
	m_dock.connect("create_coordinator_requested", Callable(self, "_on_create_coordinator_requested"))

	m_editor_dock = EditorDock.new()
	m_editor_dock.name = "Low-Poly Building Editor"
	m_editor_dock.title = "Low-Poly Building Editor"
	m_editor_dock.default_slot = _DOCK_SLOT
	m_editor_dock.layout_key = "low_poly_building_editor"
	m_editor_dock.add_child(m_dock)
	add_dock(m_editor_dock)
	_build_viewport_toolbar()
	scene_changed.connect(_on_scene_changed)
	_connect_editor_selection()
	_refresh_dock_context()
	_attach_input_capture()
	_attach_viewport_overlays.call_deferred()


func _exit_tree() -> void:
	_cancel_tool_controller_previews()
	m_display_settings["wireframe"] = false
	_apply_debug_wireframe_to_scene()
	_cancel_floor_drag()
	_clear_floor_hover()
	_cancel_roof_drag()
	_clear_roof_hover()
	_clear_wall_preview()
	_clear_floor_preview()
	_clear_roof_preview()
	_clear_prop_preview()
	_clear_viewport_overlays()
	_clear_viewport_toolbar()
	_clear_input_capture()
	_disconnect_editor_selection()
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if m_editor_dock != null:
		remove_dock(m_editor_dock)
		m_editor_dock.queue_free()
		m_editor_dock = null
		m_dock = null
	elif m_dock != null:
		m_dock.queue_free()
		m_dock = null
	for type_index in range(m_opening_custom_types.size() - 1, -1, -1):
		remove_custom_type(String(m_opening_custom_types[type_index]["name"]))
	for type_index in range(m_building_style_custom_types.size() - 1, -1, -1):
		remove_custom_type(String(m_building_style_custom_types[type_index]["name"]))
	remove_custom_type("Rail3D")
	remove_custom_type("Floor3D")
	remove_custom_type("Wall3D")
	remove_custom_type("Building3D")
	m_tool_controllers.clear()
	m_context = null
	m_native_toolbar = null


func _handles(object: Object) -> bool:
	return object is Node3D


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if m_tool_mode == MODE_SELECT:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and !key_event.echo:
			if key_event.keycode == KEY_ESCAPE:
				_cancel_active_preview()
				return _handled()
			if (
				(key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER)
			):
				if m_tool_mode == MODE_FLOOR and _is_polygon_floor_mode() and m_is_drawing_floor:
					_finish_polygon_floor()
					return _handled()
				if m_tool_mode == MODE_ROOF and _is_polygon_roof_mode() and m_is_drawing_roof:
					_finish_polygon_roof()
					return _handled()
			if key_event.keycode == KEY_R and m_tool_mode == MODE_ROOF:
				return _handle_roof_rotation_key(key_event)
			if key_event.keycode == KEY_R and m_tool_mode == MODE_PROP:
				m_prop_rotation_y += PI * 0.5
				return _handled()

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_cancel_active_preview()
			return _handled()

	var tool_controller: BuildingToolControllerScript = m_tool_controllers.get(m_tool_mode)
	if tool_controller != null:
		return tool_controller.handle_input(camera, event)
	if m_tool_mode == MODE_WALL:
		return _handle_wall_input(camera, event)
	if m_tool_mode == MODE_FLOOR:
		return _handle_floor_input(camera, event)
	if m_tool_mode == MODE_ROOF:
		return _handle_roof_input(camera, event)
	if m_tool_mode == MODE_PROP or _is_opening_tool():
		return _handle_placement_input(camera, event)
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func is_building_tool_active() -> bool:
	return m_tool_mode != MODE_SELECT


func _is_opening_tool() -> bool:
	return m_tool_mode == MODE_WINDOW or m_tool_mode == MODE_DOOR


func handle_viewport_overlay_input(camera: Camera3D, event: InputEvent) -> bool:
	if m_tool_mode == MODE_SELECT:
		return false
	return _forward_3d_gui_input(camera, event) != EditorPlugin.AFTER_GUI_INPUT_PASS


func notify_viewport_overlay_event(event_name: String) -> void:
	_set_status("Viewport overlay captured %s." % event_name)


func _handle_wall_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_wall != null:
		return _handle_wall_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_wall:
			_update_wall_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_wall_start_screen_position) >= WALL_DRAG_COMMIT_DISTANCE:
				m_wall_release_commits_preview = true
			return _handled()
		var pick := _find_wall_pick(camera, mouse_motion.position)
		var hover_wall := pick.get("wall") as Wall3DScript
		var hover_segment := int(pick.get("segment", 0))
		var hover_ep := int(pick.get("endpoint", -1))
		var hover_joint_position := Vector3.ZERO
		if pick.has("joint_position"):
			hover_joint_position = Vector3(pick["joint_position"])
		var hover_has_joint := bool(pick.get("joint", false))
		_update_wall_hover(hover_wall, hover_segment, hover_ep, hover_joint_position, hover_has_joint)
		if hover_wall != null:
			_set_status(
				"Drag joint to move connected walls. Option-drag to disconnect." if hover_has_joint
				else "Click and drag endpoint to resize." if hover_ep >= 0
				else "Drag a side to resize the room. Option-drag to move the whole room."
				if hover_wall.is_rectangular_loop(_wall_joint_tolerance(hover_wall))
				else "Click and drag to move wall. Shift-click to add joint."
			)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_wall:
		if !m_wall_release_commits_preview:
			_set_status(
				"Click the opposite corner to place room, or drag from the start point and release."
				if _is_room_wall_mode()
				else "Click another point to place wall, or drag from the start point and release."
			)
			return _handled()
		_set_status("%s mouse release captured." % _wall_draw_label())
		var release_coordinator := _get_active_wall_coordinator()
		if release_coordinator != null:
			var release_end := m_wall_end_local
			if !m_wall_has_valid_preview:
				release_end = _resolve_wall_end_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_wall(release_coordinator, m_wall_start_local, release_end)
		_clear_wall_preview()
		_reset_wall_drawing_state()
		return _handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_wall:
		var pick := _find_wall_pick(camera, mouse_button.position)
		var hit_wall := pick.get("wall") as Wall3DScript
		if hit_wall != null:
			if mouse_button.shift_pressed and int(pick.get("endpoint", -1)) < 0:
				_commit_add_wall_joint(
					hit_wall,
					int(pick.get("segment", 0)),
					Vector3(pick.get("position", hit_wall.global_position))
				)
				return _handled()
			_clear_wall_hover()
			_start_wall_drag(
				hit_wall,
				camera,
				mouse_button.position,
				int(pick.get("segment", 0)),
				int(pick.get("endpoint", -1)),
				bool(mouse_button.alt_pressed)
			)
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing walls.")
		return _handled()

	var snapped_local := _wall_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_wall:
		m_wall_start_local = snapped_local
		m_wall_end_local = snapped_local
		m_wall_start_screen_position = mouse_button.position
		m_wall_has_valid_preview = false
		m_wall_release_commits_preview = false
		m_is_drawing_wall = true
		_create_wall_preview(coordinator)
		_update_wall_preview(camera, mouse_button.position)
		_set_status(
			"%s mouse press captured. Drag and release, or click %s."
			% [
				_wall_draw_label(),
				"the opposite corner" if _is_room_wall_mode() else "another point",
			]
		)
		return _handled()

	var local_end := _constrain_wall_end_on_base(coordinator, m_wall_start_local, snapped_local)
	_commit_wall(coordinator, m_wall_start_local, local_end)
	_clear_wall_preview()
	_reset_wall_drawing_state()
	return _handled()


func _handle_wall_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_wall_drag(camera, (event as InputEventMouseMotion).position)
		return _handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_wall_drag()
			return _handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_wall_drag()
			return _handled()
	return _handled()


func _handle_placement_input(camera: Camera3D, event: InputEvent) -> int:
	if _is_opening_tool() and m_dragging_opening != null:
		return _handle_window_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		if _is_opening_tool():
			var pick := _find_opening_pick(camera, mouse_pos)
			var hover_opening := pick.get("opening") as BuildingOpening3DScript
			var hover_edge := int(pick.get("edge", -1))
			_update_hover_highlight(hover_opening, hover_edge)
			if hover_opening != null:
				_clear_prop_preview()
				_set_status(
					"Click and drag edge to resize." if hover_edge >= 0
					else "Click and drag to move opening."
				)
				return _handled()
			_clear_drag_hover()
		_update_placement_preview(camera, mouse_pos)
		return _handled() if m_prop_preview != null else EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if _is_opening_tool():
		var pick := _find_opening_pick(camera, mouse_button.position)
		var hit_opening := pick.get("opening") as BuildingOpening3DScript
		if hit_opening != null:
			_clear_drag_hover()
			_start_window_drag(hit_opening, int(pick.get("edge", -1)), pick.get("wall") as Wall3DScript)
			return _handled()

	_update_placement_preview(camera, mouse_button.position)
	if m_preview_valid:
		_commit_placement()
	return _handled()


func _handle_window_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_window_drag(camera, (event as InputEventMouseMotion).position)
		return _handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_window_drag()
			return _handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_window_drag()
			return _handled()
	return _handled()


func _create_wall_preview(coordinator: Building3DScript) -> void:
	_clear_wall_preview()
	m_wall_preview = Wall3DScript.new() as Wall3DScript
	m_wall_preview.name = "WallPreview"
	m_wall_preview.set_meta(Wall3DScript.PREVIEW_META, true)
	m_wall_preview.wall_height = float(m_wall_settings["height"])
	m_wall_preview.wall_thickness = float(m_wall_settings["thickness"])
	var preview_color := Color(m_wall_settings["color"])
	preview_color.a = 0.48
	m_wall_preview.wall_color = preview_color
	m_wall_preview.generate_collision = false
	coordinator.add_child(m_wall_preview)
	m_wall_preview.owner = null
	_apply_debug_wireframe_to_node(m_wall_preview)


func _update_wall_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_wall_preview == null:
		return
	var coordinator := m_wall_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var local_position := _wall_draw_local_from_mouse(coordinator, camera, mouse_position)
	var local_end := _constrain_wall_end_on_base(coordinator, m_wall_start_local, local_position)
	m_wall_end_local = local_end
	m_wall_has_valid_preview = _is_wall_draw_valid(m_wall_start_local, local_end)
	_set_wall_preview_geometry(m_wall_start_local, local_end)
	if m_wall_has_valid_preview:
		_set_status("Release or click to place room." if _is_room_wall_mode() else "Release or click to place wall.")


func _set_wall_preview_geometry(local_start: Vector3, local_end: Vector3) -> void:
	if m_wall_preview == null:
		return
	if !_is_room_wall_mode():
		m_wall_preview.set_wall_geometry(local_start, local_end, [])
		return
	var segments := BuildingFactoryScript.room_segments_from_corners(
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		float(m_wall_settings["thickness"]),
		m_wall_preview.wall_color,
		_room_side_count()
	)
	var extras: Array[WallSegmentScript] = []
	for index in range(1, segments.size()):
		extras.append(segments[index])
	m_wall_preview.set_wall_geometry(segments[0].start_point, segments[0].end_point, extras)


func _resolve_wall_end_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var local_position := _wall_draw_local_from_mouse(coordinator, camera, mouse_position)
	return _constrain_wall_end_on_base(coordinator, m_wall_start_local, local_position)


func _wall_base_height() -> float:
	return float(m_wall_settings.get("base_height", 0.0))


func _wall_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _wall_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_wall_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := _raycast_world(camera, mouse_position, false)
	return _snap_wall_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_wall_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_wall_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _constrain_wall_end_on_base(
	_coordinator: Building3DScript,
	start_local: Vector3,
	target_local: Vector3
) -> Vector3:
	if _is_room_wall_mode():
		return Vector3(target_local.x, start_local.y, target_local.z)
	var constrained := BuildingFactoryScript.constrain_wall_end(
		start_local,
		target_local,
		float(m_wall_settings["grid_step"]),
		bool(m_wall_settings["lock_8_way"])
	)
	constrained.y = start_local.y
	return constrained


func _get_active_wall_coordinator() -> Building3DScript:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		var preview_parent := m_wall_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return _get_or_create_coordinator(false)


func _commit_wall(coordinator: Building3DScript, local_start: Vector3, local_end: Vector3) -> void:
	if !_is_wall_draw_valid(local_start, local_end):
		_set_status("Room is too small." if _is_room_wall_mode() else "Wall is too short.")
		return

	var thickness := float(m_wall_settings["thickness"])
	if _is_room_wall_mode():
		_commit_room(coordinator, local_start, local_end, thickness)
		return
	var merge := coordinator.find_merge_target(
		local_start,
		local_end,
		thickness,
		float(m_wall_settings["height"]),
		m_wall_preview,
		float(m_wall_settings["grid_step"])
	)
	var undo_redo := get_undo_redo()
	if !merge.is_empty():
		var target := merge["wall"] as Wall3DScript
		var target_primary := target.get_segment(0)
		if target_primary == null:
			return
		var old_start := target_primary.start_point
		var old_end := target_primary.end_point
		undo_redo.create_action("Merge Wall")
		undo_redo.add_do_method(
			self,
			"_set_wall_endpoints_and_refresh_intersections",
			target,
			merge["start"],
			merge["end"],
			coordinator
		)
		undo_redo.add_undo_method(
			self,
			"_set_wall_endpoints_and_refresh_intersections",
			target,
			old_start,
			old_end,
			coordinator
		)
		undo_redo.commit_action()
		_select_node(target)
		_set_status("Merged wall span.")
		return

	var intersects_existing_wall := false
	var targets := coordinator.find_intersecting_walls(local_start, local_end, thickness, m_wall_preview)
	if !targets.is_empty():
		intersects_existing_wall = true

	var wall := BuildingFactoryScript.create_wall_node(coordinator,
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		thickness,
		Color(m_wall_settings["color"])
	)
	var scene_root := get_editor_interface().get_edited_scene_root()
	undo_redo.create_action("Create Wall")
	undo_redo.add_do_reference(wall)
	undo_redo.add_do_method(
		self,
		"_do_add_node_and_refresh_wall_intersections",
		coordinator,
		wall,
		scene_root,
		true,
		coordinator
	)
	undo_redo.add_undo_method(self, "_undo_remove_node_and_refresh_wall_intersections", coordinator, wall, coordinator)
	undo_redo.commit_action()
	if intersects_existing_wall:
		_set_status("Created clipped wall: %.2f units." % local_start.distance_to(local_end))
	else:
		_set_status("Created wall: %.2f units." % local_start.distance_to(local_end))


func _commit_room(
	coordinator: Building3DScript,
	local_start: Vector3,
	local_end: Vector3,
	thickness: float
) -> void:
	var wall := BuildingFactoryScript.create_room_node(coordinator,
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		thickness,
		Color(m_wall_settings["color"]),
		_room_side_count()
	)
	var intersects_existing_wall := false
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if !coordinator.find_intersecting_walls(
			segment.start_point,
			segment.end_point,
			segment.thickness,
			m_wall_preview
		).is_empty():
			intersects_existing_wall = true
			break
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Room")
	undo_redo.add_do_reference(wall)
	undo_redo.add_do_method(
		self,
		"_do_add_node_and_refresh_wall_intersections",
		coordinator,
		wall,
		scene_root,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_undo_remove_node_and_refresh_wall_intersections",
		coordinator,
		wall,
		coordinator
	)
	undo_redo.commit_action()
	var room_size := Vector2(absf(local_end.x - local_start.x), absf(local_end.z - local_start.z))
	_set_status(
		"Created clipped room: %.2f x %.2f." % [room_size.x, room_size.y]
		if intersects_existing_wall
		else "Created room: %.2f x %.2f." % [room_size.x, room_size.y]
	)


func _handle_floor_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_floor != null:
		return _handle_floor_drag_input(camera, event)
	if _is_polygon_floor_mode():
		return _handle_polygon_floor_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_floor:
			_update_floor_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_floor_start_screen_position) >= WALL_DRAG_COMMIT_DISTANCE:
				m_floor_release_commits_preview = true
			return _handled()
		var floor_pick := (
			_find_floor_hole_edit_pick(camera, mouse_motion.position)
			if _is_floor_hole_mode()
			else _find_floor_edit_pick(camera, mouse_motion.position)
		)
		if _is_floor_hole_mode() and floor_pick.is_empty():
			floor_pick = _find_floor_pick(camera, mouse_motion.position)
		var hover_floor := floor_pick.get("floor") as Floor3DScript
		var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_floor_hover(hover_floor, edit_mask)
		if hover_floor != null:
			if _is_floor_hole_mode():
				if floor_pick.has("hole_index"):
					_set_floor_hole_edit_hover_status(edit_mask)
				else:
					_set_status("Drag to draw a floor hole inside the highlighted floor.")
			else:
				_set_floor_edit_hover_status(hover_floor, edit_mask)
		elif _is_floor_hole_mode():
			_set_status("Draw a hole fully inside an existing floor.")
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_floor:
		if !m_floor_release_commits_preview:
			_set_status(
				"Click the opposite corner to cut floor hole, or drag from the first corner and release."
				if _is_floor_hole_mode()
				else "Click the opposite corner to place floor, or drag from the first corner and release."
			)
			return _handled()
		var release_coordinator := _get_active_floor_coordinator()
		if release_coordinator != null:
			var release_end := m_floor_end_local
			if !m_floor_has_valid_preview:
				release_end = _floor_draw_local_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_floor(release_coordinator, m_floor_start_local, release_end)
		_clear_floor_preview()
		_reset_floor_drawing_state()
		return _handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_floor and !_is_floor_hole_mode():
		var floor_pick := _find_floor_edit_pick(camera, mouse_button.position)
		if _begin_floor_edit_from_pick(camera, mouse_button, floor_pick):
			return _handled()
	if !m_is_drawing_floor and _is_floor_hole_mode():
		var hole_pick := _find_floor_hole_edit_pick(camera, mouse_button.position)
		if _begin_floor_hole_edit_from_pick(camera, mouse_button, hole_pick):
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing floors.")
		return _handled()

	var snapped_local := _floor_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_floor:
		m_floor_start_local = snapped_local
		m_floor_end_local = snapped_local
		m_floor_start_screen_position = mouse_button.position
		m_floor_has_valid_preview = false
		m_floor_release_commits_preview = false
		m_is_drawing_floor = true
		_create_floor_preview(coordinator)
		_update_floor_preview(camera, mouse_button.position)
		_set_status(
			"Floor hole first corner captured. Drag and release, or click the opposite corner."
			if _is_floor_hole_mode()
			else "Floor first corner captured. Drag and release, or click the opposite corner."
		)
		return _handled()

	_commit_floor(coordinator, m_floor_start_local, snapped_local)
	_clear_floor_preview()
	_reset_floor_drawing_state()
	return _handled()


func _handle_polygon_floor_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_floor:
			_update_polygon_floor_preview(camera, mouse_motion.position)
			return _handled()
		var floor_pick := (
			_find_floor_hole_edit_pick(camera, mouse_motion.position)
			if _is_floor_hole_mode()
			else _find_floor_edit_pick(camera, mouse_motion.position)
		)
		var hover_floor := floor_pick.get("floor") as Floor3DScript
		var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_floor_hover(hover_floor, edit_mask)
		if hover_floor != null:
			if _is_floor_hole_mode():
				_set_floor_hole_edit_hover_status(edit_mask)
			else:
				_set_floor_edit_hover_status(hover_floor, edit_mask)
		else:
			_set_status("Click the first polygon vertex.")
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_floor:
		var floor_pick := (
			_find_floor_hole_edit_pick(camera, mouse_button.position)
			if _is_floor_hole_mode()
			else _find_floor_edit_pick(camera, mouse_button.position)
		)
		var began_edit := (
			_begin_floor_hole_edit_from_pick(camera, mouse_button, floor_pick)
			if _is_floor_hole_mode()
			else _begin_floor_edit_from_pick(camera, mouse_button, floor_pick)
		)
		if began_edit:
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing floors.")
		return _handled()
	var snapped_local := _floor_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_floor:
		m_is_drawing_floor = true
		m_floor_polygon_points = PackedVector3Array([snapped_local])
		_create_floor_preview(coordinator)
		_update_polygon_floor_preview(camera, mouse_button.position)
		_set_status("Polygon vertex 1 captured. Click more vertices, then click the first vertex or press Enter.")
		return _handled()

	if (
		m_floor_polygon_points.size() >= 3
		and snapped_local.distance_to(m_floor_polygon_points[0])
			<= maxf(float(m_floor_settings["grid_step"]) * 0.25, 0.05)
	):
		_finish_polygon_floor()
		return _handled()
	if snapped_local.distance_to(m_floor_polygon_points[m_floor_polygon_points.size() - 1]) <= 0.001:
		_set_status("Choose a different point for the next polygon vertex.")
		return _handled()

	var candidate := m_floor_polygon_points.duplicate()
	candidate.append(snapped_local)
	if candidate.size() >= 3 and !_is_valid_floor_polygon(candidate):
		_set_status("That vertex would make an invalid or self-intersecting polygon.")
		return _handled()
	m_floor_polygon_points = candidate
	_update_polygon_floor_preview(camera, mouse_button.position)
	_set_status(
		"Polygon vertex %d captured. Click the first vertex or press Enter to close."
		% m_floor_polygon_points.size()
	)
	return _handled()


func _update_polygon_floor_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_floor_preview == null:
		return
	var coordinator := m_floor_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var hover_point := _floor_draw_local_from_mouse(coordinator, camera, mouse_position)
	var preview_points := m_floor_polygon_points.duplicate()
	if preview_points.is_empty() or !preview_points[preview_points.size() - 1].is_equal_approx(hover_point):
		preview_points.append(hover_point)
	m_floor_preview.set_floor_polygon(preview_points)
	m_floor_has_valid_preview = _is_valid_floor_polygon(preview_points)


func _finish_polygon_floor() -> void:
	var coordinator := _get_active_floor_coordinator()
	if coordinator == null or !_is_valid_floor_polygon(m_floor_polygon_points):
		_set_status("A floor polygon needs at least three non-intersecting vertices.")
		return
	if _is_floor_hole_mode():
		_commit_floor_polygon_hole(coordinator, m_floor_polygon_points)
	else:
		_commit_floor_polygon(coordinator, m_floor_polygon_points)
	_clear_floor_preview()
	_reset_floor_drawing_state()


func _commit_floor_polygon(
	coordinator: Building3DScript,
	local_points: PackedVector3Array
) -> void:
	if !_is_valid_floor_polygon(local_points):
		_set_status("Floor polygon is invalid.")
		return
	var floor := BuildingFactoryScript.create_floor_polygon_node(
		coordinator,
		local_points,
		float(m_floor_settings["thickness"]),
		Color(m_floor_settings["color"])
	)
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Polygon Floor")
	undo_redo.add_do_reference(floor)
	undo_redo.add_do_method(self, "_do_add_node", coordinator, floor, scene_root, true)
	undo_redo.add_undo_method(self, "_undo_remove_node", coordinator, floor)
	undo_redo.commit_action()
	_set_status(
		"Created polygon floor: %d vertices, %.2f square units."
		% [local_points.size(), floor.get_floor_area()]
	)


func _set_floor_edit_hover_status(floor: Floor3DScript, edit_mask: int) -> void:
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		_set_status("Drag vertex to reshape. Option/Alt-click it to remove.")
		return
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		_set_status("Drag edge to reshape. Shift-click it to add a vertex.")
		return
	if floor.is_polygon_floor():
		_set_status("Drag floor body to move it.")
		return
	_set_status(
		"Drag floor corner to resize." if _floor_edit_mask_is_corner(edit_mask)
		else "Drag floor edge to resize." if edit_mask != FLOOR_EDIT_MOVE
		else "Drag floor body to move."
	)


func _set_floor_hole_edit_hover_status(edit_mask: int) -> void:
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		_set_status("Drag hole vertex to reshape. Option/Alt-click it to remove.")
	elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		_set_status("Drag hole edge to reshape. Shift-click it to add a vertex.")
	else:
		_set_status("Drag hole body to move it.")


func _begin_floor_hole_edit_from_pick(
	camera: Camera3D,
	mouse_button: InputEventMouseButton,
	floor_pick: Dictionary
) -> bool:
	var floor := floor_pick.get("floor") as Floor3DScript
	if floor == null or !floor_pick.has("hole_index"):
		return false
	_clear_floor_hover()
	var hole_index := int(floor_pick.get("hole_index", -1))
	var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
	var vertex_index := int(floor_pick.get("vertex_index", -1))
	var edge_index := int(floor_pick.get("edge_index", -1))
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX and mouse_button.alt_pressed:
		_remove_floor_hole_vertex(floor, hole_index, vertex_index)
		return true
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE and mouse_button.shift_pressed:
		var parent_position := Vector3(floor_pick.get("parent_position", floor.start_point))
		_add_floor_hole_vertex(floor, hole_index, edge_index, parent_position)
		return true
	_start_floor_hole_drag(
		floor,
		hole_index,
		camera,
		mouse_button.position,
		edit_mask,
		vertex_index,
		edge_index
	)
	return true


func _start_floor_hole_drag(
	floor: Floor3DScript,
	hole_index: int,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int,
	vertex_index: int,
	edge_index: int
) -> void:
	m_dragging_floor = floor
	m_drag_floor_hole_index = hole_index
	m_drag_floor_hole_old_polygons = floor.get_floor_hole_polygons()
	m_drag_floor_edit_mask = edit_mask
	m_drag_floor_vertex_index = vertex_index
	m_drag_floor_edge_index = edge_index
	m_drag_floor_anchor_local = _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	m_drag_floor_active_material = floor.material_override
	floor.material_override = _build_preview_material(_floor_drag_color(edit_mask, true))
	_select_node(floor)
	_set_status("Dragging floor hole %s - release to commit, Escape to cancel." % _floor_edit_label(edit_mask))


func _add_floor_hole_vertex(
	floor: Floor3DScript,
	hole_index: int,
	edge_index: int,
	parent_position: Vector3
) -> void:
	var old_holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
	if hole_index < 0 or hole_index >= old_holes.size():
		return
	var hole: PackedVector2Array = old_holes[hole_index].duplicate()
	if edge_index < 0 or edge_index >= hole.size():
		return
	var snapped_parent := _snap_floor_edit_local(floor, parent_position)
	var new_point := Vector2(
		snapped_parent.x - floor.position.x,
		snapped_parent.z - floor.position.z
	)
	if new_point.distance_to(hole[edge_index]) <= 0.001:
		return
	if new_point.distance_to(hole[(edge_index + 1) % hole.size()]) <= 0.001:
		return
	hole.insert(edge_index + 1, new_point)
	if !floor.can_set_floor_hole_polygon(hole_index, hole):
		_set_status("That point would make the floor hole invalid.")
		return
	var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
	new_holes[hole_index] = hole
	_commit_floor_hole_polygons(floor, old_holes, new_holes, "Add Floor Hole Vertex")


func _remove_floor_hole_vertex(
	floor: Floor3DScript,
	hole_index: int,
	vertex_index: int
) -> void:
	var old_holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
	if hole_index < 0 or hole_index >= old_holes.size():
		return
	var hole: PackedVector2Array = old_holes[hole_index].duplicate()
	if hole.size() <= 3:
		_set_status("A floor hole must keep at least three vertices.")
		return
	if vertex_index < 0 or vertex_index >= hole.size():
		return
	hole.remove_at(vertex_index)
	if !floor.can_set_floor_hole_polygon(hole_index, hole):
		_set_status("Removing that vertex would make the floor hole invalid.")
		return
	var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
	new_holes[hole_index] = hole
	_commit_floor_hole_polygons(floor, old_holes, new_holes, "Remove Floor Hole Vertex")


func _commit_floor_hole_polygons(
	floor: Floor3DScript,
	old_holes: Array[PackedVector2Array],
	new_holes: Array[PackedVector2Array],
	action_name: String
) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(floor, "set_floor_hole_polygons", new_holes)
	undo_redo.add_do_method(self, "_select_node", floor)
	undo_redo.add_undo_method(floor, "set_floor_hole_polygons", old_holes)
	undo_redo.add_undo_method(self, "_select_node", floor)
	undo_redo.commit_action()


func _begin_floor_edit_from_pick(
	camera: Camera3D,
	mouse_button: InputEventMouseButton,
	floor_pick: Dictionary
) -> bool:
	var floor := floor_pick.get("floor") as Floor3DScript
	if floor == null:
		return false
	_clear_floor_hover()
	var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
	var vertex_index := int(floor_pick.get("vertex_index", -1))
	var edge_index := int(floor_pick.get("edge_index", -1))
	if (
		edit_mask == FLOOR_EDIT_POLYGON_VERTEX
		and mouse_button.alt_pressed
	):
		_remove_floor_vertex(floor, vertex_index)
		return true
	if (
		edit_mask == FLOOR_EDIT_POLYGON_EDGE
		and mouse_button.shift_pressed
	):
		var hit_parent_position := Vector3(
			floor_pick.get("parent_position", floor.start_point)
		)
		_add_floor_vertex(floor, edge_index, hit_parent_position)
		return true
	_start_floor_drag(
		floor,
		camera,
		mouse_button.position,
		edit_mask,
		vertex_index,
		edge_index
	)
	return true


func _add_floor_vertex(
	floor: Floor3DScript,
	edge_index: int,
	parent_position: Vector3
) -> void:
	var old_points := _get_floor_edit_points(floor)
	if edge_index < 0 or edge_index >= old_points.size():
		_set_status("No floor edge selected.")
		return
	var new_point := _snap_floor_edit_local(floor, parent_position)
	var edge_start := old_points[edge_index]
	var edge_end := old_points[(edge_index + 1) % old_points.size()]
	if new_point.distance_to(edge_start) <= 0.001 or new_point.distance_to(edge_end) <= 0.001:
		_set_status("New vertex must be between two existing vertices.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		new_points.append(old_points[index])
		if index == edge_index:
			new_points.append(new_point)
	if !_is_valid_floor_polygon(new_points):
		_set_status("That point would make an invalid polygon.")
		return
	_commit_floor_points(
		floor,
		old_points,
		new_points,
		"Add Floor Vertex",
		"Added floor vertex."
	)


func _remove_floor_vertex(floor: Floor3DScript, vertex_index: int) -> void:
	var old_points := _get_floor_edit_points(floor)
	if old_points.size() <= 3:
		_set_status("A floor must keep at least three vertices.")
		return
	if vertex_index < 0 or vertex_index >= old_points.size():
		_set_status("No floor vertex selected.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		if index != vertex_index:
			new_points.append(old_points[index])
	if !_is_valid_floor_polygon(new_points):
		_set_status("Removing that vertex would make an invalid polygon.")
		return
	_commit_floor_points(
		floor,
		old_points,
		new_points,
		"Remove Floor Vertex",
		"Removed floor vertex."
	)


func _commit_floor_points(
	floor: Floor3DScript,
	old_points: PackedVector3Array,
	new_points: PackedVector3Array,
	action_name: String,
	status: String
) -> void:
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(floor, "set_floor_polygon", new_points)
	undo_redo.add_do_method(self, "_select_node", floor)
	if floor.is_polygon_floor():
		undo_redo.add_undo_method(floor, "set_floor_polygon", old_points)
	else:
		undo_redo.add_undo_method(
			floor,
			"set_floor_corners_and_holes",
			floor.start_point,
			floor.end_point,
			floor.get_floor_holes()
		)
	undo_redo.add_undo_method(self, "_select_node", floor)
	undo_redo.commit_action()
	_set_status(status)


func _create_floor_preview(coordinator: Building3DScript) -> void:
	_clear_floor_preview()
	m_floor_preview = Floor3DScript.new() as Floor3DScript
	m_floor_preview.name = "FloorPreview"
	m_floor_preview.set_meta(Floor3DScript.PREVIEW_META, true)
	m_floor_preview.floor_thickness = float(m_floor_settings["thickness"])
	var preview_color := (
		Color(0.95, 0.20, 0.16, 1.0)
		if _is_floor_hole_mode()
		else Color(m_floor_settings["color"])
	)
	preview_color.a = 0.44
	m_floor_preview.floor_color = preview_color
	m_floor_preview.generate_collision = false
	coordinator.add_child(m_floor_preview)
	m_floor_preview.owner = null
	_apply_debug_wireframe_to_node(m_floor_preview)


func _update_floor_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_floor_preview == null:
		return
	var coordinator := m_floor_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var local_end := _floor_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_floor_end_local = local_end
	m_floor_has_valid_preview = _is_floor_span_large_enough(m_floor_start_local, local_end)
	m_floor_preview.set_floor_corners(m_floor_start_local, local_end)
	if m_floor_has_valid_preview:
		var size := m_floor_preview.get_floor_size()
		if _is_floor_hole_mode():
			var target_floor := _find_floor_for_polygon_hole(
				coordinator,
				_rectangle_floor_points(m_floor_start_local, local_end)
			)
			if target_floor != null:
				_set_status("Release or click to cut floor hole: %.2f x %.2f." % [size.x, size.y])
			else:
				_set_status("Draw the hole fully inside one existing floor.")
		else:
			_set_status("Release or click to place floor: %.2f x %.2f." % [size.x, size.y])


func _floor_base_height() -> float:
	return float(m_floor_settings.get("base_height", 0.0))


func _floor_tool_type() -> String:
	return str(m_floor_settings.get("type", FLOOR_TYPE_SOLID))


func _floor_tool_style() -> String:
	return str(m_floor_settings.get("style", FLOOR_STYLE_RECTANGLE))


func _is_floor_hole_mode() -> bool:
	return _floor_tool_type() == FLOOR_TYPE_HOLE


func _is_polygon_floor_mode() -> bool:
	return _floor_tool_style() == FLOOR_STYLE_POLYGON


func _floor_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _floor_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	if _is_floor_hole_mode():
		if m_is_drawing_floor:
			base_y = m_floor_start_local.y
		var floor_hit := _raycast_floors(origin, direction)
		var hit_floor := floor_hit.get("floor") as Floor3DScript
		if hit_floor != null:
			base_y = hit_floor.start_point.y
			return _snap_floor_draw_local(
				coordinator,
				coordinator.to_local(Vector3(floor_hit["position"])),
				base_y
			)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_floor_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := _raycast_world(camera, mouse_position, false)
	return _snap_floor_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_floor_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_floor_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _get_active_floor_coordinator() -> Building3DScript:
	if m_floor_preview != null and is_instance_valid(m_floor_preview):
		var preview_parent := m_floor_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return _get_or_create_coordinator(false)


func _commit_floor(coordinator: Building3DScript, local_start: Vector3, local_end: Vector3) -> void:
	if !_is_floor_span_large_enough(local_start, local_end):
		_set_status("Floor is too small.")
		return
	if _is_floor_hole_mode():
		_commit_floor_hole(coordinator, local_start, local_end)
		return

	var floor := BuildingFactoryScript.create_floor_node(
		coordinator,
		local_start,
		local_end,
		float(m_floor_settings["thickness"]),
		Color(m_floor_settings["color"])
	)
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Floor")
	undo_redo.add_do_reference(floor)
	undo_redo.add_do_method(self, "_do_add_node", coordinator, floor, scene_root, true)
	undo_redo.add_undo_method(self, "_undo_remove_node", coordinator, floor)
	undo_redo.commit_action()
	var size := floor.get_floor_size()
	_set_status("Created floor: %.2f x %.2f units." % [size.x, size.y])


func _commit_floor_hole(
	coordinator: Building3DScript,
	local_start: Vector3,
	local_end: Vector3
) -> void:
	_commit_floor_polygon_hole(
		coordinator,
		_rectangle_floor_points(local_start, local_end)
	)


func _commit_floor_polygon_hole(
	coordinator: Building3DScript,
	parent_points: PackedVector3Array
) -> void:
	var target_floor := _find_floor_for_polygon_hole(coordinator, parent_points)
	if target_floor == null:
		_set_status("Draw the hole fully inside one existing floor.")
		return
	var local_polygon := target_floor.get_floor_hole_polygon_from_parent_points(parent_points)
	if !target_floor.can_add_floor_hole_polygon(local_polygon):
		_set_status("Floor hole must stay fully inside the floor.")
		return
	var old_holes: Array[PackedVector2Array] = target_floor.get_floor_hole_polygons()
	var new_holes: Array[PackedVector2Array] = old_holes.duplicate()
	new_holes.append(local_polygon)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Floor Hole")
	undo_redo.add_do_method(target_floor, "set_floor_hole_polygons", new_holes)
	undo_redo.add_do_method(self, "_select_node", target_floor)
	undo_redo.add_undo_method(target_floor, "set_floor_hole_polygons", old_holes)
	undo_redo.add_undo_method(self, "_select_node", target_floor)
	undo_redo.commit_action()
	_set_status(
		"Cut floor hole: %d vertices."
		% local_polygon.size()
	)


func _find_floor_for_polygon_hole(
	coordinator: Building3DScript,
	parent_points: PackedVector3Array
) -> Floor3DScript:
	if coordinator == null or parent_points.is_empty():
		return null
	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(coordinator, floors)
	var best_floor: Floor3DScript = null
	var best_area := INF
	var height_tolerance := maxf(float(m_floor_settings["grid_step"]) * 0.05, 0.01)
	for floor in floors:
		if !is_instance_valid(floor) or floor == m_floor_preview:
			continue
		if floor.has_meta(Floor3DScript.PREVIEW_META):
			continue
		if absf(floor.start_point.y - parent_points[0].y) > height_tolerance:
			continue
		var local_polygon := floor.get_floor_hole_polygon_from_parent_points(parent_points)
		if !floor.can_add_floor_hole_polygon(local_polygon):
			continue
		var floor_area := floor.get_floor_area()
		if best_floor == null or floor_area < best_area:
			best_floor = floor
			best_area = floor_area
	return best_floor


func _handle_floor_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_floor_drag(camera, (event as InputEventMouseMotion).position)
		return _handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_floor_drag()
			return _handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_floor_drag()
			return _handled()
	return _handled()


func _start_floor_drag(
	floor: Floor3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int,
	vertex_index: int = -1,
	edge_index: int = -1
) -> void:
	m_dragging_floor = floor
	m_drag_floor_old_start = floor.start_point
	m_drag_floor_old_end = floor.end_point
	m_drag_floor_old_polygon = _get_floor_edit_points(floor)
	m_drag_floor_old_holes = floor.get_floor_holes()
	m_drag_floor_started_as_polygon = floor.is_polygon_floor()
	m_drag_floor_edit_mask = edit_mask
	if vertex_index >= 0:
		m_drag_floor_edit_mask = FLOOR_EDIT_POLYGON_VERTEX
	elif edge_index >= 0:
		m_drag_floor_edit_mask = FLOOR_EDIT_POLYGON_EDGE
	elif floor.is_polygon_floor():
		m_drag_floor_edit_mask = FLOOR_EDIT_MOVE
	m_drag_floor_vertex_index = vertex_index if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_VERTEX else -1
	m_drag_floor_edge_index = edge_index if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_EDGE else -1
	m_drag_floor_active_material = floor.material_override
	m_drag_floor_anchor_local = _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	floor.material_override = _build_preview_material(_floor_drag_color(m_drag_floor_edit_mask, true))
	_select_node(floor)
	_set_status(
		"Dragging floor %s - release to commit, Escape to cancel."
		% _floor_edit_label(m_drag_floor_edit_mask)
	)


func _update_floor_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_floor == null or !is_instance_valid(m_dragging_floor):
		_reset_floor_drag_state()
		return
	var floor := m_dragging_floor
	if m_drag_floor_hole_index >= 0:
		_update_floor_hole_drag(floor, camera, mouse_pos)
		return
	var hit_local := _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	var new_start := m_drag_floor_old_start
	var new_end := m_drag_floor_old_end
	if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		var edited_polygon := m_drag_floor_old_polygon.duplicate()
		if m_drag_floor_vertex_index < 0 or m_drag_floor_vertex_index >= edited_polygon.size():
			return
		edited_polygon[m_drag_floor_vertex_index] = _snap_floor_edit_local(floor, hit_local)
		var valid := _is_valid_floor_polygon(edited_polygon)
		if valid:
			floor.set_floor_polygon(edited_polygon)
			_set_status("Release to commit floor vertex position.")
		else:
			_set_status("That position would make the floor invalid.")
		floor.material_override = _build_preview_material(
			_floor_drag_color(FLOOR_EDIT_POLYGON_VERTEX, valid)
		)
		return
	if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		var edited_polygon := m_drag_floor_old_polygon.duplicate()
		if m_drag_floor_edge_index < 0 or m_drag_floor_edge_index >= edited_polygon.size():
			return
		var step := _active_floor_grid_step(floor)
		var raw_delta := hit_local - m_drag_floor_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var next_edge_index := (m_drag_floor_edge_index + 1) % edited_polygon.size()
		edited_polygon[m_drag_floor_edge_index] += snapped_delta
		edited_polygon[next_edge_index] += snapped_delta
		var valid := _is_valid_floor_polygon(edited_polygon)
		if valid:
			floor.set_floor_polygon(edited_polygon)
			_set_status("Release to commit floor edge position.")
		else:
			_set_status("That position would make the floor invalid.")
		floor.material_override = _build_preview_material(
			_floor_drag_color(FLOOR_EDIT_POLYGON_EDGE, valid)
		)
		return
	if floor.is_polygon_floor():
		var step := _active_floor_grid_step(floor)
		var raw_delta := hit_local - m_drag_floor_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var moved_polygon := PackedVector3Array()
		for point in m_drag_floor_old_polygon:
			moved_polygon.append(point + snapped_delta)
		floor.set_floor_polygon(moved_polygon)
		floor.material_override = _build_preview_material(_floor_drag_color(FLOOR_EDIT_MOVE, true))
		_set_status("Release to commit polygon floor move.")
		return
	if m_drag_floor_edit_mask == FLOOR_EDIT_MOVE:
		var step := _active_floor_grid_step(floor)
		var raw_delta := hit_local - m_drag_floor_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		new_start = m_drag_floor_old_start + snapped_delta
		new_end = m_drag_floor_old_end + snapped_delta
	else:
		var snapped := _snap_floor_edit_local(floor, hit_local)
		var resized := _resized_floor_points(snapped)
		new_start = Vector3(resized["start"])
		new_end = Vector3(resized["end"])

	floor.set_floor_corners(new_start, new_end)
	var holes_fit := _floor_holes_fit_for_points(floor, new_start, new_end)
	var valid := _is_floor_span_large_enough(new_start, new_end) and holes_fit
	floor.material_override = _build_preview_material(
		_floor_drag_color(m_drag_floor_edit_mask, valid)
	)
	if valid:
		var size := floor.get_floor_size()
		_set_status("Release to commit floor %s: %.2f x %.2f." % [_floor_edit_label(m_drag_floor_edit_mask), size.x, size.y])
	elif !holes_fit:
		_set_status("Floor resize would move a hole outside the floor.")
	else:
		_set_status("Floor is too small.")


func _update_floor_hole_drag(
	floor: Floor3DScript,
	camera: Camera3D,
	mouse_pos: Vector2
) -> void:
	var holes: Array[PackedVector2Array] = m_drag_floor_hole_old_polygons.duplicate()
	if m_drag_floor_hole_index < 0 or m_drag_floor_hole_index >= holes.size():
		return
	var hole: PackedVector2Array = holes[m_drag_floor_hole_index].duplicate()
	var hit_parent := _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	var snapped_parent := _snap_floor_edit_local(floor, hit_parent)
	var snapped_local := Vector2(
		snapped_parent.x - floor.position.x,
		snapped_parent.z - floor.position.z
	)
	var anchor_local := Vector2(
		m_drag_floor_anchor_local.x - floor.position.x,
		m_drag_floor_anchor_local.z - floor.position.z
	)
	var step := _active_floor_grid_step(floor)
	var raw_delta := snapped_local - anchor_local
	var delta := Vector2(
		roundf(raw_delta.x / step) * step,
		roundf(raw_delta.y / step) * step
	)
	if m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		if m_drag_floor_vertex_index < 0 or m_drag_floor_vertex_index >= hole.size():
			return
		hole[m_drag_floor_vertex_index] = snapped_local
	elif m_drag_floor_edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		if m_drag_floor_edge_index < 0 or m_drag_floor_edge_index >= hole.size():
			return
		hole[m_drag_floor_edge_index] += delta
		hole[(m_drag_floor_edge_index + 1) % hole.size()] += delta
	else:
		for index in range(hole.size()):
			hole[index] += delta
	var valid := floor.can_set_floor_hole_polygon(m_drag_floor_hole_index, hole)
	if valid:
		holes[m_drag_floor_hole_index] = hole
		floor.set_floor_hole_polygons(holes)
		_set_status("Release to commit floor hole edit.")
	else:
		_set_status("That edit would make the floor hole invalid.")
	floor.material_override = _build_preview_material(
		_floor_drag_color(m_drag_floor_edit_mask, valid)
	)


func _commit_floor_drag() -> void:
	if m_dragging_floor == null:
		return
	var floor := m_dragging_floor
	var old_start := m_drag_floor_old_start
	var old_end := m_drag_floor_old_end
	var old_polygon := m_drag_floor_old_polygon.duplicate()
	var new_start := floor.start_point
	var new_end := floor.end_point
	var new_polygon := floor.get_floor_polygon()
	var edit_mask := m_drag_floor_edit_mask
	floor.material_override = m_drag_floor_active_material
	if m_drag_floor_hole_index >= 0:
		var old_holes: Array[PackedVector2Array] = m_drag_floor_hole_old_polygons
		var new_holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
		if _floor_hole_polygons_match(old_holes, new_holes):
			_reset_floor_drag_state()
			_set_status("Floor hole unchanged.")
			return
		_commit_floor_hole_polygons(floor, old_holes, new_holes, "Edit Floor Hole")
		_reset_floor_drag_state()
		_set_status("Edited floor hole.")
		return
	if floor.is_polygon_floor():
		if old_polygon == new_polygon:
			_restore_floor_drag_original(floor)
			_reset_floor_drag_state()
			_set_status("Floor unchanged.")
			return
		var polygon_undo_redo := get_undo_redo()
		var action_name := "Move Floor"
		if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
			action_name = "Edit Floor Vertex"
		elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
			action_name = "Edit Floor Edge"
		polygon_undo_redo.create_action(action_name)
		polygon_undo_redo.add_do_method(floor, "set_floor_polygon", new_polygon)
		polygon_undo_redo.add_do_method(self, "_select_node", floor)
		if m_drag_floor_started_as_polygon:
			polygon_undo_redo.add_undo_method(floor, "set_floor_polygon", old_polygon)
		else:
			polygon_undo_redo.add_undo_method(
				floor,
				"set_floor_corners_and_holes",
				old_start,
				old_end,
				m_drag_floor_old_holes
			)
		polygon_undo_redo.commit_action()
		_reset_floor_drag_state()
		if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
			_set_status("Edited floor vertex.")
		elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
			_set_status("Edited floor edge.")
		else:
			_set_status("Moved polygon floor.")
		return
	if !_is_floor_span_large_enough(new_start, new_end):
		floor.set_floor_corners(old_start, old_end)
		_reset_floor_drag_state()
		_set_status("Floor is too small.")
		return
	if !_floor_holes_fit_for_points(floor, new_start, new_end):
		floor.set_floor_corners(old_start, old_end)
		_reset_floor_drag_state()
		_set_status("Floor resize would move a hole outside the floor.")
		return
	if old_start.distance_to(new_start) <= 0.001 and old_end.distance_to(new_end) <= 0.001:
		_reset_floor_drag_state()
		_set_status("Floor unchanged.")
		return

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Move Floor" if edit_mask == FLOOR_EDIT_MOVE else "Resize Floor")
	undo_redo.add_do_method(floor, "set_floor_corners", new_start, new_end)
	undo_redo.add_do_method(self, "_select_node", floor)
	undo_redo.add_undo_method(floor, "set_floor_corners", old_start, old_end)
	undo_redo.commit_action()
	_reset_floor_drag_state()
	var size := floor.get_floor_size()
	_set_status("Edited floor: %.2f x %.2f units." % [size.x, size.y])


func _cancel_floor_drag() -> void:
	if m_dragging_floor == null:
		return
	if is_instance_valid(m_dragging_floor):
		if m_drag_floor_hole_index >= 0:
			m_dragging_floor.set_floor_hole_polygons(m_drag_floor_hole_old_polygons)
		else:
			_restore_floor_drag_original(m_dragging_floor)
		m_dragging_floor.material_override = m_drag_floor_active_material
	_reset_floor_drag_state()
	_set_status("Floor edit canceled.")


func _restore_floor_drag_original(floor: Floor3DScript) -> void:
	if m_drag_floor_started_as_polygon:
		floor.set_floor_polygon(m_drag_floor_old_polygon)
	else:
		floor.set_floor_corners_and_holes(
			m_drag_floor_old_start,
			m_drag_floor_old_end,
			m_drag_floor_old_holes
		)


func _floor_hole_polygons_match(
	a: Array[PackedVector2Array],
	b: Array[PackedVector2Array]
) -> bool:
	if a.size() != b.size():
		return false
	for hole_index in range(a.size()):
		if a[hole_index].size() != b[hole_index].size():
			return false
		for point_index in range(a[hole_index].size()):
			if a[hole_index][point_index].distance_to(b[hole_index][point_index]) > 0.001:
				return false
	return true


func _resized_floor_points(snapped_hit: Vector3) -> Dictionary:
	var min_x := minf(m_drag_floor_old_start.x, m_drag_floor_old_end.x)
	var max_x := maxf(m_drag_floor_old_start.x, m_drag_floor_old_end.x)
	var min_z := minf(m_drag_floor_old_start.z, m_drag_floor_old_end.z)
	var max_z := maxf(m_drag_floor_old_start.z, m_drag_floor_old_end.z)
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MIN_X) != 0:
		min_x = snapped_hit.x
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MAX_X) != 0:
		max_x = snapped_hit.x
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MIN_Z) != 0:
		min_z = snapped_hit.z
	if (m_drag_floor_edit_mask & FLOOR_EDIT_MAX_Z) != 0:
		max_z = snapped_hit.z
	var sorted_min_x := minf(min_x, max_x)
	var sorted_max_x := maxf(min_x, max_x)
	var sorted_min_z := minf(min_z, max_z)
	var sorted_max_z := maxf(min_z, max_z)
	var base_y := m_drag_floor_old_start.y
	return {
		"start": Vector3(sorted_min_x, base_y, sorted_min_z),
		"end": Vector3(sorted_max_x, base_y, sorted_max_z),
	}


func _floor_plane_local_from_mouse(
	floor: Floor3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var parent_3d := floor.get_parent() as Node3D
	var base_y := floor.start_point.y
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := parent_3d.to_local(origin) if parent_3d != null else origin
	var local_direction := (
		parent_3d.global_transform.basis.inverse() * direction
		if parent_3d != null
		else direction
	)
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return local_origin + local_direction * distance_to_plane
	return floor.start_point


func _snap_floor_edit_local(floor: Floor3DScript, local_position: Vector3) -> Vector3:
	var step := _active_floor_grid_step(floor)
	return Vector3(
		roundf(local_position.x / step) * step,
		floor.start_point.y,
		roundf(local_position.z / step) * step
	)


func _floor_drag_color(edit_mask: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if edit_mask == FLOOR_EDIT_MOVE:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _floor_edit_label(edit_mask: int) -> String:
	if edit_mask == FLOOR_EDIT_MOVE:
		return "body"
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		return "vertex"
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		return "edge"
	return "corner" if _floor_edit_mask_is_corner(edit_mask) else "edge"


func _floor_edit_mask_is_corner(edit_mask: int) -> bool:
	var edits_x := (edit_mask & FLOOR_EDIT_MIN_X) != 0 or (edit_mask & FLOOR_EDIT_MAX_X) != 0
	var edits_z := (edit_mask & FLOOR_EDIT_MIN_Z) != 0 or (edit_mask & FLOOR_EDIT_MAX_Z) != 0
	return edits_x and edits_z


func _floor_holes_fit_for_points(floor: Floor3DScript, local_start: Vector3, local_end: Vector3) -> bool:
	if floor == null:
		return true
	return floor.floor_holes_fit_size(
		Vector2(absf(local_end.x - local_start.x), absf(local_end.z - local_start.z))
	)


func _active_floor_grid_step(_floor: Floor3DScript) -> float:
	return maxf(float(m_floor_settings["grid_step"]), 0.05)


func _reset_floor_drag_state() -> void:
	m_dragging_floor = null
	m_drag_floor_old_start = Vector3.ZERO
	m_drag_floor_old_end = Vector3.ZERO
	m_drag_floor_old_polygon = PackedVector3Array()
	m_drag_floor_old_holes.clear()
	m_drag_floor_started_as_polygon = false
	m_drag_floor_vertex_index = -1
	m_drag_floor_edge_index = -1
	m_drag_floor_hole_index = -1
	m_drag_floor_hole_old_polygons.clear()
	m_drag_floor_anchor_local = Vector3.ZERO
	m_drag_floor_edit_mask = FLOOR_EDIT_MOVE
	m_drag_floor_active_material = null


func _handle_roof_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_roof != null:
		return _handle_roof_drag_input(camera, event)
	if _is_polygon_roof_mode():
		return _handle_polygon_roof_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_roof:
			_update_roof_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_roof_start_screen_position) >= WALL_DRAG_COMMIT_DISTANCE:
				m_roof_release_commits_preview = true
			return _handled()
		var roof_pick := _find_roof_edit_pick(camera, mouse_motion.position)
		var hover_roof := roof_pick.get("roof") as Roof3DScript
		var edit_mask := int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_roof_hover(hover_roof, edit_mask)
		if hover_roof != null:
			_set_roof_edit_hover_status(hover_roof, edit_mask)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_roof:
		if !m_roof_release_commits_preview:
			_set_status("Click the opposite corner to place roof, or drag from the first corner and release.")
			return _handled()
		var release_coordinator := _get_active_roof_coordinator()
		if release_coordinator != null:
			var release_end := m_roof_end_local
			if !m_roof_has_valid_preview:
				release_end = _roof_draw_local_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_roof(release_coordinator, m_roof_start_local, release_end, m_roof_draw_rotation_degrees)
		_clear_roof_preview()
		_reset_roof_drawing_state()
		return _handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_roof:
		var roof_pick := _find_roof_edit_pick(camera, mouse_button.position)
		if _begin_roof_edit_from_pick(camera, mouse_button, roof_pick):
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing roofs.")
		return _handled()

	var snapped_local := _roof_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_roof:
		m_roof_start_local = snapped_local
		m_roof_end_local = snapped_local
		m_roof_start_screen_position = mouse_button.position
		m_roof_has_valid_preview = false
		m_roof_release_commits_preview = false
		m_roof_draw_rotation_degrees = _normalize_degrees(float(m_roof_settings.get("rotation_degrees", 0.0)))
		m_is_drawing_roof = true
		_create_roof_preview(coordinator)
		_update_roof_preview(camera, mouse_button.position)
		_set_status("Roof first corner captured. Drag and release, or click the opposite corner.")
		return _handled()

	_commit_roof(coordinator, m_roof_start_local, snapped_local, m_roof_draw_rotation_degrees)
	_clear_roof_preview()
	_reset_roof_drawing_state()
	return _handled()


func _handle_polygon_roof_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_roof:
			_update_polygon_roof_preview(camera, mouse_motion.position)
			return _handled()
		var roof_pick := _find_roof_edit_pick(camera, mouse_motion.position)
		var hover_roof := roof_pick.get("roof") as Roof3DScript
		var edit_mask := int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_roof_hover(hover_roof, edit_mask)
		if hover_roof != null:
			_set_roof_edit_hover_status(hover_roof, edit_mask)
		else:
			_set_status("Click the first Flat roof polygon vertex.")
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_roof:
		var roof_pick := _find_roof_edit_pick(camera, mouse_button.position)
		if _begin_roof_edit_from_pick(camera, mouse_button, roof_pick):
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing roofs.")
		return _handled()
	var snapped_local := _roof_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_roof:
		m_is_drawing_roof = true
		m_roof_polygon_points = PackedVector3Array([snapped_local])
		m_roof_draw_rotation_degrees = 0.0
		_create_roof_preview(coordinator)
		_update_polygon_roof_preview(camera, mouse_button.position)
		_set_status("Roof polygon vertex 1 captured. Click more vertices, then click the first vertex or press Enter.")
		return _handled()

	if (
		m_roof_polygon_points.size() >= 3
		and snapped_local.distance_to(m_roof_polygon_points[0])
			<= maxf(float(m_roof_settings["grid_step"]) * 0.25, 0.05)
	):
		_finish_polygon_roof()
		return _handled()
	if snapped_local.distance_to(m_roof_polygon_points[m_roof_polygon_points.size() - 1]) <= 0.001:
		_set_status("Choose a different point for the next roof vertex.")
		return _handled()

	var candidate := m_roof_polygon_points.duplicate()
	candidate.append(snapped_local)
	if candidate.size() >= 3 and !_is_valid_roof_polygon(candidate):
		_set_status("That vertex would make an invalid or self-intersecting roof polygon.")
		return _handled()
	m_roof_polygon_points = candidate
	_update_polygon_roof_preview(camera, mouse_button.position)
	_set_status(
		"Roof polygon vertex %d captured. Click the first vertex or press Enter to close."
		% m_roof_polygon_points.size()
	)
	return _handled()


func _update_polygon_roof_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_roof_preview == null:
		return
	var coordinator := m_roof_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var hover_point := _roof_draw_local_from_mouse(coordinator, camera, mouse_position)
	var preview_points := m_roof_polygon_points.duplicate()
	if preview_points.is_empty() or !preview_points[preview_points.size() - 1].is_equal_approx(hover_point):
		preview_points.append(hover_point)
	_set_roof_polygon(m_roof_preview, preview_points)
	m_roof_has_valid_preview = _is_valid_roof_polygon(preview_points)


func _finish_polygon_roof() -> void:
	var coordinator := _get_active_roof_coordinator()
	if coordinator == null or !_is_valid_roof_polygon(m_roof_polygon_points):
		_set_status("A roof polygon needs at least three non-intersecting vertices.")
		return
	_commit_roof_polygon(coordinator, m_roof_polygon_points)
	_clear_roof_preview()
	_reset_roof_drawing_state()


func _commit_roof_polygon(
	coordinator: Building3DScript,
	local_points: PackedVector3Array
) -> void:
	if !_is_valid_roof_polygon(local_points):
		_set_status("Flat roof polygon is invalid.")
		return
	var bounds := _roof_polygon_parent_bounds(local_points)
	var local_start := Vector3(bounds.position.x, local_points[0].y, bounds.position.y)
	var local_end := Vector3(bounds.end.x, local_points[0].y, bounds.end.y)
	var merge := coordinator.find_roof_merge_target(
		local_start,
		local_end,
			RoofStyleGeometryFactory.STYLE_FLAT,
		0.0,
		float(m_roof_settings["thickness"]),
		float(m_roof_settings["overhang"]),
		Color(m_roof_settings["color"]),
		0.0,
		m_roof_preview
	)
	var roof := BuildingFactoryScript.create_flat_roof_polygon_node(
		coordinator,
		local_points,
		float(m_roof_settings["thickness"]),
		float(m_roof_settings["overhang"]),
		Color(m_roof_settings["color"])
	)
	var covered_rects := _roof_covered_rects_from_regions(merge)
	var covered_polygons := _roof_covered_polygons_from_regions(merge)
	if !covered_rects.is_empty() or !covered_polygons.is_empty():
		roof.set_covered_regions(covered_rects, covered_polygons)
	if !roof.has_visible_roof_geometry():
		_set_status("Flat roof polygon is fully covered by overlapping roof geometry.")
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Polygon Flat Roof")
	undo_redo.add_do_reference(roof)
	undo_redo.add_do_method(
		self,
		"_do_add_node_and_refresh_roofs",
		coordinator,
		roof,
		scene_root,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_undo_remove_node_and_refresh_roofs",
		coordinator,
		roof,
		coordinator
	)
	undo_redo.commit_action()
	_set_status("Created Flat roof polygon: %d vertices." % local_points.size())


func _create_roof_preview(coordinator: Building3DScript) -> void:
	_clear_roof_preview()
	m_roof_preview = BuildingFactoryScript.instantiate_roof_style(String(m_roof_settings["style"]))
	m_roof_preview.name = "RoofPreview"
	m_roof_preview.set_meta(Roof3DScript.PREVIEW_META, true)
	BuildingFactoryScript.configure_roof_style(
		m_roof_preview,
		float(m_roof_settings["height"]),
		float(m_roof_settings.get("hip_gable_height", 0.0))
	)
	m_roof_preview.roof_thickness = float(m_roof_settings["thickness"])
	m_roof_preview.roof_overhang = float(m_roof_settings["overhang"])
	m_roof_preview.roof_rotation_degrees = m_roof_draw_rotation_degrees
	var preview_color := Color(m_roof_settings["color"])
	preview_color.a = 0.46
	m_roof_preview.roof_color = preview_color
	m_roof_preview.generate_collision = false
	coordinator.add_child(m_roof_preview)
	m_roof_preview.owner = null
	_apply_debug_wireframe_to_node(m_roof_preview)


func _update_roof_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_roof_preview == null:
		return
	var coordinator := m_roof_preview.get_parent() as Building3DScript
	if coordinator == null:
		return
	var selected_style := String(m_roof_settings["style"])
	if m_roof_preview.get_roof_style() != selected_style:
		_create_roof_preview(coordinator)
		if m_roof_preview == null:
			return
	var local_end := _roof_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_roof_end_local = local_end
	var roof_points := Roof3DScript.roof_corners_from_base_points(
		m_roof_start_local,
		local_end,
		m_roof_draw_rotation_degrees
	)
	var roof_start := Vector3(roof_points["start"])
	var roof_end := Vector3(roof_points["end"])
	m_roof_has_valid_preview = _is_roof_span_large_enough(roof_start, roof_end)
	BuildingFactoryScript.configure_roof_style(
		m_roof_preview,
		float(m_roof_settings["height"]),
		float(m_roof_settings.get("hip_gable_height", 0.0))
	)
	m_roof_preview.roof_thickness = float(m_roof_settings["thickness"])
	m_roof_preview.roof_overhang = float(m_roof_settings["overhang"])
	m_roof_preview.set_roof_corners_and_rotation(roof_start, roof_end, m_roof_draw_rotation_degrees)
	if m_roof_has_valid_preview:
		var size := m_roof_preview.get_roof_size()
		_set_status(
			"Release or click to place roof: %.2f x %.2f, %.0f deg." %
			[size.x, size.y, m_roof_draw_rotation_degrees]
		)


func _roof_base_height() -> float:
	return float(m_roof_settings.get("base_height", 2.4))


func _is_polygon_roof_mode() -> bool:
	return (
			String(m_roof_settings.get("style", "")) == RoofStyleGeometryFactory.STYLE_FLAT
		and String(m_roof_settings.get("footprint_style", FLOOR_STYLE_RECTANGLE))
			== FLOOR_STYLE_POLYGON
	)


func _roof_draw_local_from_mouse(
	coordinator: Building3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _roof_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_roof_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := _raycast_world(camera, mouse_position, false)
	return _snap_roof_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_roof_draw_local(
	_coordinator: Building3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := BuildingFactoryScript.snap_local_position(
		local_position,
		float(m_roof_settings["grid_step"])
	)
	snapped.y = base_y
	return snapped


func _get_active_roof_coordinator() -> Building3DScript:
	if m_roof_preview != null and is_instance_valid(m_roof_preview):
		var preview_parent := m_roof_preview.get_parent() as Building3DScript
		if preview_parent != null:
			return preview_parent
	return _get_or_create_coordinator(false)


func _handle_roof_rotation_key(key_event: InputEventKey) -> int:
	var delta := -90.0 if key_event.shift_pressed else 90.0
	if m_is_drawing_roof:
		m_roof_draw_rotation_degrees = _normalize_degrees(m_roof_draw_rotation_degrees + delta)
		if m_roof_preview != null and is_instance_valid(m_roof_preview):
			var roof_points := Roof3DScript.roof_corners_from_base_points(
				m_roof_start_local,
				m_roof_end_local,
				m_roof_draw_rotation_degrees
			)
			m_roof_preview.set_roof_corners_and_rotation(
				Vector3(roof_points["start"]),
				Vector3(roof_points["end"]),
				m_roof_draw_rotation_degrees
			)
		_set_status("Roof preview rotation: %.0f degrees." % m_roof_draw_rotation_degrees)
		return _handled()

	if m_dragging_roof != null:
		_set_status("Release the roof edit before rotating.")
		return _handled()

	var roof := m_drag_roof_hover if is_instance_valid(m_drag_roof_hover) else _selected_roof_for_rotation()
	if roof == null:
		_set_status("Hover or select a roof to rotate it.")
		return _handled()
	if _is_polygon_roof(roof):
		_set_status("Polygon Flat roofs rotate by dragging their vertices or edges.")
		return _handled()
	_commit_roof_rotation(roof, delta)
	return _handled()


func _selected_roof_for_rotation() -> Roof3DScript:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return null
	for node in selection.get_selected_nodes():
		if node is Roof3DScript:
			return node as Roof3DScript
	return null


func _commit_roof_rotation(roof: Roof3DScript, delta_degrees: float) -> void:
	if roof == null or !is_instance_valid(roof):
		return
	var old_start := roof.start_point
	var old_end := roof.end_point
	var old_rotation := roof.roof_rotation_degrees
	var old_height := _roof_angle_degrees(roof)
	var old_covered_rects := roof.get_covered_rects()
	var old_covered_polygons := roof.get_covered_polygons()
	var new_rotation := _normalize_degrees(old_rotation + delta_degrees)
	var rotated_state := _roof_state_rotated_around_center(roof, new_rotation)
	var new_start := Vector3(rotated_state["start"])
	var new_end := Vector3(rotated_state["end"])
	var new_covered_rects: Array[Rect2] = []
	var new_covered_polygons: Array[PackedVector2Array] = []
	var coordinator := _find_coordinator_from_node(roof)
	if coordinator != null:
		var cover_regions := coordinator.compute_roof_cover_regions(
			new_start,
			new_end,
			roof.get_roof_style(),
			_roof_angle_degrees(roof),
			roof.roof_thickness,
			roof.roof_overhang,
			roof.roof_color,
			new_rotation,
			roof,
			true,
			_roof_hip_gable_height(roof)
		)
		new_covered_rects = _roof_covered_rects_from_regions(cover_regions)
		new_covered_polygons = _roof_covered_polygons_from_regions(cover_regions)
		if !coordinator.roof_has_visible_cover_area(
			new_start,
			new_end,
			roof.roof_overhang,
			new_covered_rects,
			new_covered_polygons
		):
			_set_status("Rotated roof would be fully covered.")
			return
		if _roof_layout_would_hide_any_roof(
			coordinator,
			roof,
			new_start,
			new_end,
			new_rotation,
			old_height,
			new_covered_rects,
			new_covered_polygons
		):
			_set_status("Rotated roof would fully cover another roof.")
			return
	_clear_roof_hover()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Rotate Roof")
	undo_redo.add_do_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		new_start,
		new_end,
		new_rotation,
		old_height,
		new_covered_rects,
		new_covered_polygons,
		coordinator
	)
	undo_redo.add_do_method(self, "_select_node", roof)
	undo_redo.add_undo_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		old_start,
		old_end,
		old_rotation,
		old_height,
		old_covered_rects,
		old_covered_polygons,
		coordinator
	)
	undo_redo.commit_action()
	_set_status("Rotated roof to %.0f degrees." % new_rotation)


func _roof_state_rotated_around_center(roof: Roof3DScript, rotation_degrees: float) -> Dictionary:
	var size := roof.get_roof_size()
	var center := roof.get_roof_center_point()
	var anchor := center - _roof_rotation_basis(rotation_degrees) * Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	return {
		"start": anchor,
		"end": anchor + Vector3(size.x, 0.0, size.y),
	}


func _commit_roof(
	coordinator: Building3DScript,
	draw_start: Vector3,
	draw_end: Vector3,
	rotation_degrees: float
) -> void:
	var roof_points := Roof3DScript.roof_corners_from_base_points(draw_start, draw_end, rotation_degrees)
	var local_start := Vector3(roof_points["start"])
	var local_end := Vector3(roof_points["end"])
	if !_is_roof_span_large_enough(local_start, local_end):
		_set_status("Roof is too small.")
		return

	var style := String(m_roof_settings["style"])
	var height := float(m_roof_settings["height"])
	var thickness := float(m_roof_settings["thickness"])
	var overhang := float(m_roof_settings["overhang"])
	var hip_gable_height := float(m_roof_settings.get("hip_gable_height", 0.0))
	var color := Color(m_roof_settings["color"])
	var normalized_rotation := _normalize_degrees(rotation_degrees)
	var merge := coordinator.find_roof_merge_target(
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		normalized_rotation,
		m_roof_preview,
		hip_gable_height
	)
	var covered_rects := _roof_covered_rects_from_regions(merge)
	var covered_polygons := _roof_covered_polygons_from_regions(merge)

	var roof := BuildingFactoryScript.create_roof_node(coordinator,
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		normalized_rotation,
		hip_gable_height
	)
	if !covered_rects.is_empty() or !covered_polygons.is_empty():
		roof.set_covered_regions(covered_rects, covered_polygons)
	if !roof.has_visible_roof_geometry():
		_set_status("Roof is fully covered by overlapping roof geometry.")
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Roof")
	undo_redo.add_do_reference(roof)
	undo_redo.add_do_method(self, "_do_add_node_and_refresh_roofs", coordinator, roof, scene_root, true, coordinator)
	undo_redo.add_undo_method(self, "_undo_remove_node_and_refresh_roofs", coordinator, roof, coordinator)
	undo_redo.commit_action()
	var size := roof.get_roof_size()
	if covered_rects.is_empty():
		_set_status("Created roof: %.2f x %.2f units." % [size.x, size.y])
	else:
		_set_status("Created clipped roof: %.2f x %.2f units." % [size.x, size.y])


func _set_roof_edit_hover_status(roof: Roof3DScript, edit_mask: int) -> void:
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		_set_status("Drag roof vertex to reshape. Option/Alt-click it to remove.")
	elif edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		_set_status("Drag roof edge to reshape. Shift-click it to add a vertex.")
	elif _is_polygon_roof(roof):
		_set_status("Drag roof body to move it.")
	else:
		_set_status(
			"Drag roof corner to resize." if _roof_edit_mask_is_corner(edit_mask)
			else "Drag roof edge to resize." if edit_mask != FLOOR_EDIT_MOVE
			else "Drag roof body to move."
		)


func _begin_roof_edit_from_pick(
	camera: Camera3D,
	mouse_button: InputEventMouseButton,
	roof_pick: Dictionary
) -> bool:
	var roof := roof_pick.get("roof") as Roof3DScript
	if roof == null:
		return false
	_clear_roof_hover()
	var edit_mask := int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE))
	var vertex_index := int(roof_pick.get("vertex_index", -1))
	var edge_index := int(roof_pick.get("edge_index", -1))
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX and mouse_button.alt_pressed:
		_remove_roof_vertex(roof, vertex_index)
		return true
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE and mouse_button.shift_pressed:
		_add_roof_vertex(
			roof,
			edge_index,
			Vector3(roof_pick.get("parent_position", roof.start_point))
		)
		return true
	_start_roof_drag(
		roof,
		camera,
		mouse_button.position,
		edit_mask,
		vertex_index,
		edge_index
	)
	return true


func _add_roof_vertex(
	roof: Roof3DScript,
	edge_index: int,
	parent_position: Vector3
) -> void:
	if roof.get_roof_style() != RoofStyleGeometryFactory.STYLE_FLAT:
		return
	var old_points := _get_roof_edit_points(roof)
	if edge_index < 0 or edge_index >= old_points.size():
		_set_status("No roof edge selected.")
		return
	var new_point := _snap_roof_edit_point(roof, parent_position)
	var edge_start := old_points[edge_index]
	var edge_end := old_points[(edge_index + 1) % old_points.size()]
	if new_point.distance_to(edge_start) <= 0.001 or new_point.distance_to(edge_end) <= 0.001:
		_set_status("New vertex must be between two existing roof vertices.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		new_points.append(old_points[index])
		if index == edge_index:
			new_points.append(new_point)
	if !_is_valid_roof_polygon(new_points):
		_set_status("That point would make an invalid roof polygon.")
		return
	_commit_roof_points(roof, old_points, new_points, "Add Roof Vertex", "Added roof vertex.")


func _remove_roof_vertex(roof: Roof3DScript, vertex_index: int) -> void:
	if roof.get_roof_style() != RoofStyleGeometryFactory.STYLE_FLAT:
		return
	var old_points := _get_roof_edit_points(roof)
	if old_points.size() <= 3:
		_set_status("A roof must keep at least three vertices.")
		return
	if vertex_index < 0 or vertex_index >= old_points.size():
		_set_status("No roof vertex selected.")
		return
	var new_points := PackedVector3Array()
	for index in range(old_points.size()):
		if index != vertex_index:
			new_points.append(old_points[index])
	if !_is_valid_roof_polygon(new_points):
		_set_status("Removing that vertex would make an invalid roof polygon.")
		return
	_commit_roof_points(roof, old_points, new_points, "Remove Roof Vertex", "Removed roof vertex.")


func _commit_roof_points(
	roof: Roof3DScript,
	old_points: PackedVector3Array,
	new_points: PackedVector3Array,
	action_name: String,
	status: String
) -> void:
	var coordinator := _find_coordinator_from_node(roof)
	var started_as_polygon := _is_polygon_roof(roof)
	var old_start := roof.start_point
	var old_end := roof.end_point
	var old_rotation := roof.roof_rotation_degrees
	var old_height := _roof_angle_degrees(roof)
	var old_covered_rects := roof.get_covered_rects()
	var old_covered_polygons := roof.get_covered_polygons()
	_set_roof_polygon(roof, new_points)
	var layout_valid := true
	if coordinator != null:
		coordinator.refresh_roof_covered_rects()
		for roof_node in coordinator.get_roof_nodes():
			if roof_node.has_meta(Roof3DScript.PREVIEW_META):
				continue
			if !roof_node.has_visible_roof_geometry():
				layout_valid = false
				break
	if started_as_polygon:
		_set_roof_polygon(roof, old_points)
		roof.set_covered_regions(old_covered_rects, old_covered_polygons)
	else:
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
	if coordinator != null:
		coordinator.refresh_building_geometry_clips()
	if !layout_valid:
		_set_status("Roof edit would fully cover a roof.")
		return
	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(self, "_set_roof_polygon_and_refresh", roof, new_points, coordinator)
	undo_redo.add_do_method(self, "_select_node", roof)
	if started_as_polygon:
		undo_redo.add_undo_method(self, "_set_roof_polygon_and_refresh", roof, old_points, coordinator)
	else:
		undo_redo.add_undo_method(
			self,
			"_set_roof_state_and_refresh",
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons,
			coordinator
		)
	undo_redo.commit_action()
	_set_status(status)


func _set_roof_polygon_and_refresh(
	roof: Roof3DScript,
	points: PackedVector3Array,
	coordinator: Building3DScript
) -> void:
	_set_roof_polygon(roof, points)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_building_geometry_clips()


func _handle_roof_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_roof_drag(camera, (event as InputEventMouseMotion).position)
		return _handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_roof_drag()
			return _handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_roof_drag()
			return _handled()
	return _handled()


func _start_roof_drag(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int,
	vertex_index: int = -1,
	edge_index: int = -1
) -> void:
	m_dragging_roof = roof
	m_drag_roof_old_start = roof.start_point
	m_drag_roof_old_end = roof.end_point
	m_drag_roof_old_polygon = _get_roof_edit_points(roof)
	m_drag_roof_started_as_polygon = _is_polygon_roof(roof)
	m_drag_roof_old_rotation_degrees = roof.roof_rotation_degrees
	m_drag_roof_old_height = _roof_angle_degrees(roof)
	m_drag_roof_old_covered_rects = roof.get_covered_rects()
	m_drag_roof_old_covered_polygons = roof.get_covered_polygons()
	m_drag_roof_edit_mask = edit_mask
	if vertex_index >= 0:
		m_drag_roof_edit_mask = FLOOR_EDIT_POLYGON_VERTEX
	elif edge_index >= 0:
		m_drag_roof_edit_mask = FLOOR_EDIT_POLYGON_EDGE
	elif _is_polygon_roof(roof):
		m_drag_roof_edit_mask = FLOOR_EDIT_MOVE
	m_drag_roof_vertex_index = (
		vertex_index if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_VERTEX else -1
	)
	m_drag_roof_edge_index = (
		edge_index if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_EDGE else -1
	)
	m_drag_roof_active_material = roof.material_override
	m_drag_roof_plane_y = _roof_drag_plane_y_from_mouse(roof, camera, mouse_pos)
	m_drag_roof_anchor_local = _roof_plane_local_from_mouse_at_y(roof, camera, mouse_pos, m_drag_roof_plane_y)
	roof.material_override = _build_preview_material(_roof_drag_color(m_drag_roof_edit_mask, true))
	_select_node(roof)
	_set_status(
		"Dragging roof %s - release to commit, Escape to cancel."
		% _roof_edit_label(m_drag_roof_edit_mask)
	)


func _update_roof_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_roof == null or !is_instance_valid(m_dragging_roof):
		_reset_roof_drag_state()
		return
	var roof := m_dragging_roof
	var hit_local := _roof_plane_local_from_mouse_at_y(roof, camera, mouse_pos, m_drag_roof_plane_y)
	var new_start := m_drag_roof_old_start
	var new_end := m_drag_roof_old_end
	if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		var edited_polygon := m_drag_roof_old_polygon.duplicate()
		if m_drag_roof_vertex_index < 0 or m_drag_roof_vertex_index >= edited_polygon.size():
			return
		edited_polygon[m_drag_roof_vertex_index] = _snap_roof_edit_point(roof, hit_local)
		var valid := _is_valid_roof_polygon(edited_polygon)
		if valid:
			_set_roof_polygon(roof, edited_polygon)
			roof.set_covered_regions([], [])
			_set_status("Release to commit roof vertex position.")
		else:
			_set_status("That position would make the roof invalid.")
		roof.material_override = _build_preview_material(
			_roof_drag_color(FLOOR_EDIT_POLYGON_VERTEX, valid)
		)
		return
	if m_drag_roof_edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		var edited_polygon := m_drag_roof_old_polygon.duplicate()
		if m_drag_roof_edge_index < 0 or m_drag_roof_edge_index >= edited_polygon.size():
			return
		var step := _active_roof_grid_step(roof)
		var raw_delta := hit_local - m_drag_roof_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var next_edge_index := (m_drag_roof_edge_index + 1) % edited_polygon.size()
		edited_polygon[m_drag_roof_edge_index] += snapped_delta
		edited_polygon[next_edge_index] += snapped_delta
		var valid := _is_valid_roof_polygon(edited_polygon)
		if valid:
			_set_roof_polygon(roof, edited_polygon)
			roof.set_covered_regions([], [])
			_set_status("Release to commit roof edge position.")
		else:
			_set_status("That position would make the roof invalid.")
		roof.material_override = _build_preview_material(
			_roof_drag_color(FLOOR_EDIT_POLYGON_EDGE, valid)
		)
		return
	if _is_polygon_roof(roof):
		var step := _active_roof_grid_step(roof)
		var raw_delta := hit_local - m_drag_roof_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		var moved_polygon := PackedVector3Array()
		for point in m_drag_roof_old_polygon:
			moved_polygon.append(point + snapped_delta)
		_set_roof_polygon(roof, moved_polygon)
		roof.set_covered_regions([], [])
		roof.material_override = _build_preview_material(
			_roof_drag_color(FLOOR_EDIT_MOVE, true)
		)
		_set_status("Release to commit polygon roof move.")
		return
	if m_drag_roof_edit_mask == FLOOR_EDIT_MOVE:
		var step := _active_roof_grid_step(roof)
		var raw_delta := hit_local - m_drag_roof_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		new_start = m_drag_roof_old_start + snapped_delta
		new_end = m_drag_roof_old_end + snapped_delta
	else:
		var roof_local := _roof_edit_local_from_parent_position(hit_local)
		var resized := _resized_roof_points(roof, roof_local)
		new_start = Vector3(resized["start"])
		new_end = Vector3(resized["end"])

	var preview_covered_rects: Array[Rect2] = []
	var preview_covered_polygons: Array[PackedVector2Array] = []
	_set_roof_corners_rotation_angle_and_covers(
		roof,
		new_start,
		new_end,
		m_drag_roof_old_rotation_degrees,
		m_drag_roof_old_height,
		preview_covered_rects,
		preview_covered_polygons
	)
	var valid := _is_roof_span_large_enough(new_start, new_end)
	roof.material_override = _build_preview_material(
		_roof_drag_color(m_drag_roof_edit_mask, valid)
	)
	if valid:
		var size := roof.get_roof_size()
		_set_status("Release to commit roof %s: %.2f x %.2f." % [_roof_edit_label(m_drag_roof_edit_mask), size.x, size.y])
	else:
		_set_status("Roof is too small.")


func _commit_roof_drag() -> void:
	if m_dragging_roof == null:
		return
	var roof := m_dragging_roof
	if _is_polygon_roof(roof):
		_commit_polygon_roof_drag(roof)
		return
	var old_start := m_drag_roof_old_start
	var old_end := m_drag_roof_old_end
	var old_rotation := m_drag_roof_old_rotation_degrees
	var old_height := m_drag_roof_old_height
	var old_covered_rects := m_drag_roof_old_covered_rects
	var old_covered_polygons := m_drag_roof_old_covered_polygons
	var new_start := roof.start_point
	var new_end := roof.end_point
	var new_rotation := roof.roof_rotation_degrees
	var new_height := _roof_angle_degrees(roof)
	var edit_mask := m_drag_roof_edit_mask
	var coordinator := _find_coordinator_from_node(roof)
	roof.material_override = m_drag_roof_active_material
	if !_is_roof_span_large_enough(new_start, new_end):
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
		if coordinator != null:
			coordinator.refresh_building_geometry_clips()
		_reset_roof_drag_state()
		_set_status("Roof is too small.")
		return
	if (
			old_start.distance_to(new_start) <= 0.001
			and old_end.distance_to(new_end) <= 0.001
			and _angles_match(old_rotation, new_rotation)
			and is_equal_approx(old_height, new_height)
	):
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
		if coordinator != null:
			coordinator.refresh_building_geometry_clips()
		_reset_roof_drag_state()
		_set_status("Roof unchanged.")
		return

	var new_covered_rects: Array[Rect2] = []
	var new_covered_polygons: Array[PackedVector2Array] = []
	if coordinator != null:
		var cover_regions := coordinator.compute_roof_cover_regions(
			new_start,
			new_end,
			roof.get_roof_style(),
			new_height,
			roof.roof_thickness,
			roof.roof_overhang,
			roof.roof_color,
			roof.roof_rotation_degrees,
			roof,
			true,
			_roof_hip_gable_height(roof)
		)
		new_covered_rects = _roof_covered_rects_from_regions(cover_regions)
		new_covered_polygons = _roof_covered_polygons_from_regions(cover_regions)
		if !coordinator.roof_has_visible_cover_area(
			new_start,
			new_end,
			roof.roof_overhang,
			new_covered_rects,
			new_covered_polygons
		):
			_set_roof_corners_rotation_angle_and_covers(
				roof,
				old_start,
				old_end,
				old_rotation,
				old_height,
				old_covered_rects,
				old_covered_polygons
			)
			coordinator.refresh_building_geometry_clips()
			_reset_roof_drag_state()
			_set_status("Roof would be fully covered.")
			return
		if _roof_layout_would_hide_any_roof(
			coordinator,
			roof,
			new_start,
			new_end,
			new_rotation,
			new_height,
			new_covered_rects,
			new_covered_polygons
		):
			_set_roof_corners_rotation_angle_and_covers(
				roof,
				old_start,
				old_end,
				old_rotation,
				old_height,
				old_covered_rects,
				old_covered_polygons
			)
			coordinator.refresh_building_geometry_clips()
			_reset_roof_drag_state()
			_set_status("Roof edit would fully cover another roof.")
			return

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Move Roof" if edit_mask == FLOOR_EDIT_MOVE else "Resize Roof")
	undo_redo.add_do_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		new_start,
		new_end,
		new_rotation,
		new_height,
		new_covered_rects,
		new_covered_polygons,
		coordinator
	)
	undo_redo.add_do_method(self, "_select_node", roof)
	undo_redo.add_undo_method(
		self,
		"_set_roof_state_and_refresh",
		roof,
		old_start,
		old_end,
		old_rotation,
		old_height,
		old_covered_rects,
		old_covered_polygons,
		coordinator
	)
	undo_redo.commit_action()
	_reset_roof_drag_state()
	var size := roof.get_roof_size()
	if new_covered_rects.is_empty():
		_set_status("Edited roof: %.2f x %.2f units." % [size.x, size.y])
	else:
		_set_status("Edited clipped roof: %.2f x %.2f units." % [size.x, size.y])


func _commit_polygon_roof_drag(roof: Roof3DScript) -> void:
	var new_points := _get_roof_polygon(roof)
	var old_points := m_drag_roof_old_polygon
	var coordinator := _find_coordinator_from_node(roof)
	var edit_mask := m_drag_roof_edit_mask
	roof.material_override = m_drag_roof_active_material
	if !_is_valid_roof_polygon(new_points):
		_restore_roof_drag_start(roof, coordinator)
		_reset_roof_drag_state()
		_set_status("Roof polygon is invalid.")
		return
	if old_points == new_points and m_drag_roof_started_as_polygon:
		_restore_roof_drag_start(roof, coordinator)
		_reset_roof_drag_state()
		_set_status("Roof unchanged.")
		return
	if coordinator != null:
		coordinator.refresh_roof_covered_rects()
		for roof_node in coordinator.get_roof_nodes():
			if roof_node.has_meta(Roof3DScript.PREVIEW_META):
				continue
			if !roof_node.has_visible_roof_geometry():
				_restore_roof_drag_start(roof, coordinator)
				_reset_roof_drag_state()
				_set_status("Roof edit would fully cover a roof.")
				return
	var old_start := m_drag_roof_old_start
	var old_end := m_drag_roof_old_end
	var old_rotation := m_drag_roof_old_rotation_degrees
	var old_height := m_drag_roof_old_height
	var old_covered_rects := m_drag_roof_old_covered_rects
	var old_covered_polygons := m_drag_roof_old_covered_polygons
	var undo_redo := get_undo_redo()
	undo_redo.create_action(
		"Move Roof" if edit_mask == FLOOR_EDIT_MOVE
		else "Edit Roof Vertex" if edit_mask == FLOOR_EDIT_POLYGON_VERTEX
		else "Edit Roof Edge"
	)
	undo_redo.add_do_method(self, "_set_roof_polygon_and_refresh", roof, new_points, coordinator)
	undo_redo.add_do_method(self, "_select_node", roof)
	if m_drag_roof_started_as_polygon:
		undo_redo.add_undo_method(
			self,
			"_set_roof_polygon_and_refresh",
			roof,
			old_points,
			coordinator
		)
	else:
		undo_redo.add_undo_method(
			self,
			"_set_roof_state_and_refresh",
			roof,
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons,
			coordinator
		)
	undo_redo.commit_action()
	_reset_roof_drag_state()
	_set_status("Edited Flat roof polygon: %d vertices." % new_points.size())


func _restore_roof_drag_start(
	roof: Roof3DScript,
	coordinator: Building3DScript
) -> void:
	if m_drag_roof_started_as_polygon:
		_set_roof_polygon(roof, m_drag_roof_old_polygon)
		roof.set_covered_regions(
			m_drag_roof_old_covered_rects,
			m_drag_roof_old_covered_polygons
		)
	else:
		_set_roof_corners_rotation_angle_and_covers(
			roof,
			m_drag_roof_old_start,
			m_drag_roof_old_end,
			m_drag_roof_old_rotation_degrees,
			m_drag_roof_old_height,
			m_drag_roof_old_covered_rects,
			m_drag_roof_old_covered_polygons
		)
	if coordinator != null:
		coordinator.refresh_building_geometry_clips()


func _cancel_roof_drag() -> void:
	if m_dragging_roof == null:
		return
	var coordinator := _find_coordinator_from_node(m_dragging_roof)
	if is_instance_valid(m_dragging_roof):
		_restore_roof_drag_start(m_dragging_roof, coordinator)
		m_dragging_roof.material_override = m_drag_roof_active_material
	_reset_roof_drag_state()
	_set_status("Roof edit canceled.")


func _resized_roof_points(roof: Roof3DScript, roof_local_hit: Vector3) -> Dictionary:
	var old_size := Vector2(
		absf(m_drag_roof_old_end.x - m_drag_roof_old_start.x),
		absf(m_drag_roof_old_end.z - m_drag_roof_old_start.z)
	)
	var overhang := maxf(roof.roof_overhang, 0.0)
	var min_x := 0.0
	var max_x := old_size.x
	var min_z := 0.0
	var max_z := old_size.y
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MIN_X) != 0:
		min_x = _snap_roof_footprint_edge(roof, roof_local_hit.x + overhang)
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MAX_X) != 0:
		max_x = _snap_roof_footprint_edge(roof, roof_local_hit.x - overhang)
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MIN_Z) != 0:
		min_z = _snap_roof_footprint_edge(roof, roof_local_hit.z + overhang)
	if (m_drag_roof_edit_mask & FLOOR_EDIT_MAX_Z) != 0:
		max_z = _snap_roof_footprint_edge(roof, roof_local_hit.z - overhang)
	var sorted_min_x := minf(min_x, max_x)
	var sorted_max_x := maxf(min_x, max_x)
	var sorted_min_z := minf(min_z, max_z)
	var sorted_max_z := maxf(min_z, max_z)
	var base_y := m_drag_roof_old_start.y
	var old_anchor := Vector3(
		minf(m_drag_roof_old_start.x, m_drag_roof_old_end.x),
		base_y,
		minf(m_drag_roof_old_start.z, m_drag_roof_old_end.z)
	)
	var rotated_anchor := old_anchor + _roof_rotation_basis(m_drag_roof_old_rotation_degrees) * Vector3(
		sorted_min_x,
		0.0,
		sorted_min_z
	)
	var resized_size := Vector2(sorted_max_x - sorted_min_x, sorted_max_z - sorted_min_z)
	return {
		"start": rotated_anchor,
		"end": rotated_anchor + Vector3(resized_size.x, 0.0, resized_size.y),
	}


func _roof_plane_local_from_mouse(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	return _roof_plane_local_from_mouse_at_y(roof, camera, mouse_position, roof.start_point.y)


func _roof_plane_local_from_mouse_at_y(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_position: Vector2,
	plane_y: float
) -> Vector3:
	var parent_3d := roof.get_parent() as Node3D
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := parent_3d.to_local(origin) if parent_3d != null else origin
	var local_direction := (
		parent_3d.global_transform.basis.inverse() * direction
		if parent_3d != null
		else direction
	)
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (plane_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return local_origin + local_direction * distance_to_plane
	return roof.start_point


func _roof_drag_plane_y_from_mouse(
	roof: Roof3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> float:
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var hit := _intersect_roof_bounds(roof, origin, direction)
	if hit.is_empty():
		return roof.start_point.y
	var hit_position := Vector3(hit.get("position", roof.global_position))
	var parent_3d := roof.get_parent() as Node3D
	var parent_position := parent_3d.to_local(hit_position) if parent_3d != null else hit_position
	return parent_position.y


func _roof_edit_local_from_parent_position(local_position: Vector3) -> Vector3:
	var drag_anchor := Vector3(
		minf(m_drag_roof_old_start.x, m_drag_roof_old_end.x),
		m_drag_roof_old_start.y,
		minf(m_drag_roof_old_start.z, m_drag_roof_old_end.z)
	)
	var drag_frame := Transform3D(_roof_rotation_basis(m_drag_roof_old_rotation_degrees), drag_anchor)
	return drag_frame.affine_inverse() * local_position


func _snap_roof_footprint_edge(roof: Roof3DScript, value: float) -> float:
	var step := _active_roof_grid_step(roof)
	return roundf(value / step) * step


func _snap_roof_edit_point(roof: Roof3DScript, point: Vector3) -> Vector3:
	var step := _active_roof_grid_step(roof)
	return Vector3(
		roundf(point.x / step) * step,
		m_drag_roof_old_start.y,
		roundf(point.z / step) * step
	)


func _roof_drag_color(edit_mask: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if edit_mask == FLOOR_EDIT_MOVE:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _roof_edit_label(edit_mask: int) -> String:
	if edit_mask == FLOOR_EDIT_MOVE:
		return "body"
	if edit_mask == FLOOR_EDIT_POLYGON_VERTEX:
		return "vertex"
	if edit_mask == FLOOR_EDIT_POLYGON_EDGE:
		return "edge"
	return "corner" if _roof_edit_mask_is_corner(edit_mask) else "edge"


func _roof_edit_mask_is_corner(edit_mask: int) -> bool:
	var edits_x := (edit_mask & FLOOR_EDIT_MIN_X) != 0 or (edit_mask & FLOOR_EDIT_MAX_X) != 0
	var edits_z := (edit_mask & FLOOR_EDIT_MIN_Z) != 0 or (edit_mask & FLOOR_EDIT_MAX_Z) != 0
	return edits_x and edits_z


func _active_roof_grid_step(_roof: Roof3DScript) -> float:
	return maxf(float(m_roof_settings["grid_step"]), 0.05)


func _roof_covered_rects_from_regions(regions: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if regions.is_empty():
		return rects
	for rect in regions.get("covered_rects", []):
		rects.append(rect)
	return rects


func _roof_covered_polygons_from_regions(regions: Dictionary) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if regions.is_empty():
		return polygons
	for polygon in regions.get("covered_polygons", []):
		polygons.append(PackedVector2Array(polygon))
	return polygons


func _roof_rotation_basis(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees(rotation_degrees)))


func _normalize_degrees(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _angles_match(first: float, second: float) -> bool:
	return absf(angle_difference(deg_to_rad(first), deg_to_rad(second))) <= deg_to_rad(0.5)


func _reset_roof_drag_state() -> void:
	m_dragging_roof = null
	m_drag_roof_old_start = Vector3.ZERO
	m_drag_roof_old_end = Vector3.ZERO
	m_drag_roof_old_polygon = PackedVector3Array()
	m_drag_roof_started_as_polygon = false
	m_drag_roof_vertex_index = -1
	m_drag_roof_edge_index = -1
	m_drag_roof_old_rotation_degrees = 0.0
	m_drag_roof_old_height = 0.0
	m_drag_roof_old_covered_rects = []
	m_drag_roof_old_covered_polygons = []
	m_drag_roof_anchor_local = Vector3.ZERO
	m_drag_roof_plane_y = 0.0
	m_drag_roof_edit_mask = FLOOR_EDIT_MOVE
	m_drag_roof_active_material = null


func _update_placement_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	var hit := _raycast_world(camera, mouse_position)
	var wall := _find_wall_from_collider(hit.get("collider"))

	if _is_opening_tool():
		_update_opening_preview(wall, hit)
		return

	_update_prop_preview(wall, hit)


func _update_opening_preview(wall: Wall3DScript, hit: Dictionary) -> void:
	var settings := _active_opening_settings()
	var label := String(settings["label"])
	if wall == null:
		_clear_prop_preview()
		_set_status("%s openings need a wall target." % label)
		m_preview_valid = false
		return
	var segment_index := int(hit.get("segment", 0))
	var segment := wall.get_segment(segment_index)
	var frame := wall.get_segment_local_frame(segment_index)

	var opening_script := _opening_script_for_settings(settings)
	if m_prop_preview == null or m_prop_preview.get_script() != opening_script:
		_clear_prop_preview()
		m_prop_preview = opening_script.new() as BuildingOpening3DScript
		(m_prop_preview as BuildingOpening3DScript).build_on_ready = true
	_set_preview_parent(m_prop_preview, wall)
	_apply_debug_wireframe_to_node(m_prop_preview)

	var opening := m_prop_preview as BuildingOpening3DScript
	opening.name = "%sPreview" % String(settings["node_name"])
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, segment_index)
	_apply_opening_settings(opening, settings, segment.thickness + 0.04)
	var local_hit := frame.affine_inverse() * wall.to_local(Vector3(hit["position"]))
	var face_sign := 1.0 if local_hit.z >= 0.0 else -1.0
	var grid_step := _active_grid_step(wall)
	local_hit.x = clampf(roundf(local_hit.x / grid_step) * grid_step, 0.0, segment.get_length())
	var sill_height := maxf(float(settings["sill_height"]), 0.0)
	local_hit.y = sill_height + opening.opening_height * 0.5
	local_hit.z = face_sign * (segment.thickness * 0.5 + 0.035)
	opening.transform = Transform3D(_opening_basis_for_face(frame.basis, face_sign), frame * local_hit)
	opening.set_meta(OPENING_SILL_META, sill_height)
	opening.set_meta(OPENING_ALLOW_BASE_META, bool(settings["allow_base_edge"]))
	var center := Vector2(local_hit.x, local_hit.y)
	var size := Vector2(opening.opening_width, opening.opening_height)
	m_preview_valid = _can_place_wall_opening(
		wall,
		segment_index,
		center,
		size,
		0.04,
		opening,
		bool(settings["allow_base_edge"])
	)
	opening.frame_color = Color(0.20, 0.88, 0.36, 0.72) if m_preview_valid else Color(0.95, 0.20, 0.16, 0.72)
	m_preview_wall = wall
	_set_status("%s ready." % label if m_preview_valid else "%s overlaps or leaves the wall span." % label)


func _apply_opening_settings(opening: BuildingOpening3DScript, settings: Dictionary, frame_depth: float) -> void:
	BuildingFactoryScript.apply_opening_settings(
		opening,
		settings,
		maxf(frame_depth - 0.04, 0.0)
	)


func _opening_script_for_settings(settings: Dictionary) -> Script:
	var style := String(settings.get("style", ""))
	return BuildingFactoryScript.get_opening_style(style).get("script") as Script


# The both-sided frame casing (BuildingOpening3D._frame_casing) assumes the wall
# lies in the opening's local -Z half. Openings placed against the far wall face
# only flip their position via face_sign, not their orientation, so without this
# their -Z points away from the wall and the casing protrudes on one face only.
# Rotate 180 deg about local up so -Z always faces into the wall.
func _opening_basis_for_face(basis: Basis, face_sign: float) -> Basis:
	return BuildingFactoryScript.opening_basis_for_face(basis, face_sign)


func _can_place_wall_opening(
	wall: Wall3DScript,
	segment_index: int,
	center: Vector2,
	size: Vector2,
	clearance: float,
	ignored_opening: Node,
	allow_base_edge: bool
) -> bool:
	var coordinator := _find_coordinator_from_node(wall)
	if coordinator != null:
		return coordinator.can_place_wall_opening(
			wall,
			segment_index,
			center,
			size,
			clearance,
			ignored_opening,
			allow_base_edge
		)
	return wall.can_place_opening(
		center,
		size,
		clearance,
		ignored_opening,
		segment_index,
		allow_base_edge
	)


func _active_opening_settings() -> Dictionary:
	if m_tool_mode == MODE_DOOR:
		var style := String(m_door_settings.get("style", "single_door"))
		var is_double := style.begins_with("double")
		var label := "Single Door"
		match style:
			"double_door":
				label = "Double Door"
			"glazed_door":
				label = "Glazed Door"
			"glazed_grid_door":
				label = "Cross Glazed Door"
			"panel_door":
				label = "Panel Door"
			"dutch_door":
				label = "Dutch Door"
			"single_frame":
				label = "Single Door Frame"
			"double_frame":
				label = "Double Door Frame"
		var default_width := 1.6 if is_double else 0.9
		var node_name := label.replace(" ", "") + "Opening"
		return {
			"style": style,
			"label": label,
			"node_name": node_name,
			"width": float(m_door_settings.get("width", default_width)),
			"height": float(m_door_settings.get("height", 2.1)),
			"frame_thickness": float(m_door_settings.get("frame_thickness", 0.08)),
			"frame_sides": int(m_door_settings.get("frame_sides", 0)),
			"frame_protrusion": float(m_door_settings.get("frame_protrusion", 0.02)),
			"frame_color": Color(m_door_settings.get("frame_color", Color(0.86, 0.92, 0.94, 1.0))),
			"door_panel_depth": float(m_door_settings.get("door_panel_depth", 0.05)),
			"door_panel_color": Color(m_door_settings.get("door_panel_color", Color(0.50, 0.34, 0.20, 1.0))),
			"door_glazing_ratio": float(m_door_settings.get("door_glazing_ratio", 0.55)),
			"door_glass_depth": float(m_door_settings.get("door_glass_depth", 0.03)),
			"door_glass_color": Color(m_door_settings.get("door_glass_color", Color(0.58, 0.82, 0.95, 0.52))),
			"pane_grid_rows": int(m_door_settings.get("pane_grid_rows", 2)),
			"pane_grid_cols": int(m_door_settings.get("pane_grid_cols", 1)),
			"muntin_thickness": float(m_door_settings.get("muntin_thickness", 0.03)),
			"door_inset_rows": int(m_door_settings.get("door_inset_rows", 3)),
			"door_inset_cols": int(m_door_settings.get("door_inset_cols", 2)),
			"sill_height": 0.0,
			"show_bottom_frame": false,
			"allow_base_edge": true,
		}

	var style := String(m_window_settings.get("style", "single_window"))
	var is_double := style == "double_window"
	var label := "Single Window"
	match style:
		"double_window":
			label = "Double Window"
		"grid_window":
			label = "Grid Window"
		"louvered_window":
			label = "Louvered Window"
		"transom_window":
			label = "Transom Window"
		"arched_window":
			label = "Arched Window"
		"frame":
			label = "Window Frame"
	var default_width := 1.8 if is_double else 1.0
	var node_name := label.replace(" ", "") + "Opening"
	return {
		"style": style,
		"label": label,
		"node_name": node_name,
		"width": float(m_window_settings.get("width", default_width)),
		"height": float(m_window_settings["height"]),
		"frame_thickness": float(m_window_settings["frame_thickness"]),
		"frame_sides": int(m_window_settings.get("frame_sides", 0)),
		"frame_protrusion": float(m_window_settings.get("frame_protrusion", 0.02)),
		"frame_color": Color(m_window_settings.get("frame_color", Color(0.86, 0.92, 0.94, 1.0))),
		"window_pane_depth": float(m_window_settings.get("window_pane_depth", 0.03)),
		"window_pane_color": Color(m_window_settings.get("window_pane_color", Color(0.58, 0.82, 0.95, 0.52))),
		"pane_grid_rows": int(m_window_settings.get("pane_grid_rows", 2)),
		"pane_grid_cols": int(m_window_settings.get("pane_grid_cols", 1)),
		"muntin_thickness": float(m_window_settings.get("muntin_thickness", 0.03)),
		"louver_count": int(m_window_settings.get("louver_count", 6)),
		"louver_depth": float(m_window_settings.get("louver_depth", 0.03)),
		"transom_ratio": float(m_window_settings.get("transom_ratio", 0.28)),
		"transom_rail_thickness": float(m_window_settings.get("transom_rail_thickness", 0.03)),
		"arch_steps": int(m_window_settings.get("arch_steps", 3)),
		"sill_height": maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0),
		"show_bottom_frame": true,
		"allow_base_edge": false,
	}


func _update_prop_preview(wall: Wall3DScript, hit: Dictionary) -> void:
	var scene_path := String(m_prop_settings["scene_path"])
	if scene_path.is_empty() or !ResourceLoader.exists(scene_path):
		_clear_prop_preview()
		_set_status("Select a prop scene.")
		m_preview_valid = false
		return

	var created_preview := false
	if m_prop_preview == null or m_prop_preview_path != scene_path:
		_clear_prop_preview()
		m_prop_preview = _instantiate_prop(scene_path)
		m_prop_preview_path = scene_path
		if m_prop_preview == null:
			m_preview_valid = false
			_set_status("Prop scene root must be Node3D.")
			return
		_apply_preview_material(m_prop_preview, Color(0.20, 0.88, 0.36, 0.42))
		created_preview = true

	var parent := wall as Node
	if parent == null:
		parent = _get_or_create_coordinator(false)
	if parent == null:
		parent = get_editor_interface().get_edited_scene_root()
	if parent == null:
		_clear_prop_preview()
		m_preview_valid = false
		return

	_set_preview_parent(m_prop_preview, parent)
	if created_preview:
		_apply_debug_wireframe_to_node(m_prop_preview)
	if wall != null:
		var segment_index := int(hit.get("segment", 0))
		var segment := wall.get_segment(segment_index)
		var frame := wall.get_segment_local_frame(segment_index)
		var local_hit := frame.affine_inverse() * wall.to_local(Vector3(hit["position"]))
		var face_sign := 1.0 if local_hit.z >= 0.0 else -1.0
		local_hit.z = face_sign * (segment.thickness * 0.5 + 0.04)
		m_prop_preview.transform = Transform3D(
			frame.basis * Basis(Vector3.UP, m_prop_rotation_y),
			frame * local_hit
		)
	else:
		var snapped_world := _snap_world_position(Vector3(hit["position"]))
		m_prop_preview.global_position = snapped_world
		m_prop_preview.rotation = Vector3(0.0, m_prop_rotation_y, 0.0)

	m_preview_valid = _validate_prop_preview(parent, m_prop_preview)
	_apply_preview_material(
		m_prop_preview,
		Color(0.20, 0.88, 0.36, 0.42) if m_preview_valid else Color(0.95, 0.20, 0.16, 0.42)
	)
	m_preview_wall = wall
	_set_status("Prop ready." if m_preview_valid else "Prop is too close to another placed item.")


func _commit_placement() -> void:
	if m_prop_preview == null or m_preview_parent == null:
		return

	if _is_opening_tool():
		var settings := _active_opening_settings()
		var opening_preview := m_prop_preview as BuildingOpening3DScript
		var wall := m_preview_parent as Wall3DScript
		if opening_preview == null or wall == null:
			return
		var segment_index := int(
			opening_preview.get_meta(Wall3DScript.SEGMENT_INDEX_META, 0)
		)
		var frame := wall.get_segment_local_frame(segment_index)
		var segment_local := frame.affine_inverse() * opening_preview.position
		var sill_height := float(
			opening_preview.get_meta(OPENING_SILL_META, settings["sill_height"])
		)
		var opening := BuildingFactoryScript.create_opening_node(
			wall,
			segment_index,
			segment_local.x,
			sill_height,
			1.0 if segment_local.z >= 0.0 else -1.0,
			settings
		)
		if opening == null:
			_set_status("Could not create the selected opening style.")
			return
		opening.name = String(settings["node_name"])
		var scene_root := get_editor_interface().get_edited_scene_root()
		var undo_redo := get_undo_redo()
		undo_redo.create_action("Place Wall Opening")
		undo_redo.add_do_reference(opening)
		undo_redo.add_do_method(self, "_do_add_node_and_rebuild", wall, opening, scene_root, true)
		undo_redo.add_undo_method(self, "_undo_remove_node_and_rebuild", wall, opening)
		undo_redo.commit_action()
		_set_status("Placed %s." % String(settings["label"]).to_lower())
		return

	var scene_path := String(m_prop_settings["scene_path"])
	var prop := _instantiate_prop(scene_path)
	if prop == null:
		return
	prop.name = scene_path.get_file().get_basename()
	var scene_root := get_editor_interface().get_edited_scene_root()
	var parent: Node = m_preview_parent
	if parent == scene_root and !(parent is Building3DScript):
		var coordinator := _get_or_create_coordinator(true)
		if coordinator != null:
			parent = coordinator
	var parent_3d := parent as Node3D
	if parent_3d != null:
		prop.transform = parent_3d.global_transform.affine_inverse() * m_prop_preview.global_transform
	else:
		prop.transform = m_prop_preview.global_transform
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Place Building Prop")
	undo_redo.add_do_reference(prop)
	undo_redo.add_do_method(self, "_do_add_node", parent, prop, scene_root, true)
	undo_redo.add_undo_method(self, "_undo_remove_node", parent, prop)
	undo_redo.commit_action()
	_set_status("Placed prop.")


func _instantiate_prop(scene_path: String) -> Node3D:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	node.set_meta(BUILDING_PROP_META, true)
	return node


func _validate_prop_preview(parent: Node, preview: Node3D) -> bool:
	var clearance := float(m_prop_settings["clearance"])
	if clearance <= 0.0:
		return true
	for child in parent.get_children():
		if child == preview:
			continue
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		if child.has_meta(Wall3DScript.GENERATED_META):
			continue
		if child_3d.global_position.distance_to(preview.global_position) < clearance:
			return false
	return true


func _raycast_world(
	camera: Camera3D,
	mouse_position: Vector2,
	include_walls: bool = true
) -> Dictionary:
	return m_context.raycast_world(camera, mouse_position, include_walls)


func _raycast_walls(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var walls: Array[Wall3DScript] = []
	_collect_scene_walls(scene_root, walls)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for wall in walls:
		if !is_instance_valid(wall) or wall == m_wall_preview:
			continue
		var hit := _intersect_wall_box(wall, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _find_floor_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_floors(origin, direction)
	if hit.is_empty():
		return {}
	var floor := hit.get("floor") as Floor3DScript
	if floor == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mask"] = _floor_edit_mask_for_local_hit(floor, local_position)
	return hit


func _find_floor_edit_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var handle_pick := _find_floor_handle_pick(camera, mouse_pos)
	if !handle_pick.is_empty():
		return handle_pick
	return _find_floor_pick(camera, mouse_pos)


func _find_floor_hole_edit_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}
	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(scene_root, floors)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var best_pick: Dictionary = {}
	var best_camera_distance := INF
	for floor in floors:
		if !is_instance_valid(floor) or floor == m_floor_preview:
			continue
		var holes: Array[PackedVector2Array] = floor.get_floor_hole_polygons()
		if holes.is_empty():
			continue
		var parent_3d := floor.get_parent() as Node3D
		var local_origin := parent_3d.to_local(ray_origin) if parent_3d != null else ray_origin
		var local_direction := (
			parent_3d.global_transform.basis.inverse() * ray_direction
			if parent_3d != null
			else ray_direction
		)
		if local_direction.length_squared() <= 0.000001:
			continue
		local_direction = local_direction.normalized()
		if absf(local_direction.y) <= 0.001:
			continue
		var plane_distance := (floor.start_point.y - local_origin.y) / local_direction.y
		if plane_distance <= 0.0:
			continue
		var parent_hit := local_origin + local_direction * plane_distance
		var floor_local_hit := Vector2(
			parent_hit.x - floor.position.x,
			parent_hit.z - floor.position.z
		)
		var global_hit := parent_3d.to_global(parent_hit) if parent_3d != null else parent_hit
		var camera_distance := ray_origin.distance_to(global_hit)
		if camera_distance > best_camera_distance + 0.01:
			continue
		var radius := maxf(_active_floor_grid_step(floor) * 0.35, 0.16)
		for hole_index in range(holes.size()):
			var hole: PackedVector2Array = holes[hole_index]
			var closest_vertex_index := -1
			var closest_vertex_distance := INF
			for vertex_index in range(hole.size()):
				var distance := floor_local_hit.distance_to(hole[vertex_index])
				if distance < closest_vertex_distance:
					closest_vertex_distance = distance
					closest_vertex_index = vertex_index
			if closest_vertex_index >= 0 and closest_vertex_distance <= radius:
				best_camera_distance = camera_distance
				best_pick = {
					"floor": floor,
					"hole_index": hole_index,
					"edit_mask": FLOOR_EDIT_POLYGON_VERTEX,
					"vertex_index": closest_vertex_index,
					"edge_index": -1,
					"parent_position": parent_hit,
				}
				continue
			var closest_edge_index := -1
			var closest_edge_distance := INF
			for edge_index in range(hole.size()):
				var edge_point := _closest_point_on_plan_segment(
					floor_local_hit,
					hole[edge_index],
					hole[(edge_index + 1) % hole.size()]
				)
				var distance := floor_local_hit.distance_to(edge_point)
				if distance < closest_edge_distance:
					closest_edge_distance = distance
					closest_edge_index = edge_index
			if closest_edge_index >= 0 and closest_edge_distance <= radius:
				best_camera_distance = camera_distance
				best_pick = {
					"floor": floor,
					"hole_index": hole_index,
					"edit_mask": FLOOR_EDIT_POLYGON_EDGE,
					"vertex_index": -1,
					"edge_index": closest_edge_index,
					"parent_position": parent_hit,
				}
				continue
			if Geometry2D.is_point_in_polygon(floor_local_hit, hole):
				best_camera_distance = camera_distance
				best_pick = {
					"floor": floor,
					"hole_index": hole_index,
					"edit_mask": FLOOR_EDIT_MOVE,
					"vertex_index": -1,
					"edge_index": -1,
					"parent_position": parent_hit,
				}
	return best_pick


func _find_floor_handle_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}
	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(scene_root, floors)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var best_vertex_pick: Dictionary = {}
	var best_vertex_camera_distance := INF
	var best_edge_pick: Dictionary = {}
	var best_edge_camera_distance := INF
	for floor in floors:
		if !is_instance_valid(floor):
			continue
		if floor == m_floor_preview or floor.has_meta(Floor3DScript.PREVIEW_META):
			continue
		if floor.has_any_floor_holes():
			continue
		var parent_3d := floor.get_parent() as Node3D
		var local_origin := parent_3d.to_local(ray_origin) if parent_3d != null else ray_origin
		var local_direction := (
			parent_3d.global_transform.basis.inverse() * ray_direction
			if parent_3d != null
			else ray_direction
		)
		if local_direction.length_squared() <= 0.000001:
			continue
		local_direction = local_direction.normalized()
		if absf(local_direction.y) <= 0.001:
			continue
		var plane_distance := (floor.start_point.y - local_origin.y) / local_direction.y
		if plane_distance <= 0.0:
			continue
		var parent_hit := local_origin + local_direction * plane_distance
		var plan_hit := Vector2(parent_hit.x, parent_hit.z)
		var points := _get_floor_edit_points(floor)
		var radius := maxf(_active_floor_grid_step(floor) * 0.35, 0.16)
		var global_hit := (
			parent_3d.to_global(parent_hit)
			if parent_3d != null
			else parent_hit
		)
		var camera_distance := ray_origin.distance_to(global_hit)
		var closest_vertex_index := -1
		var closest_vertex_distance := INF
		for vertex_index in range(points.size()):
			var vertex_plan := Vector2(points[vertex_index].x, points[vertex_index].z)
			var vertex_distance := plan_hit.distance_to(vertex_plan)
			if vertex_distance < closest_vertex_distance:
				closest_vertex_distance = vertex_distance
				closest_vertex_index = vertex_index
		if (
			closest_vertex_index >= 0
			and closest_vertex_distance <= radius
			and camera_distance < best_vertex_camera_distance
		):
			best_vertex_camera_distance = camera_distance
			best_vertex_pick = {
				"floor": floor,
				"edit_mask": FLOOR_EDIT_POLYGON_VERTEX,
				"vertex_index": closest_vertex_index,
				"edge_index": -1,
				"parent_position": points[closest_vertex_index],
			}

		var closest_edge_index := -1
		var closest_edge_distance := INF
		var closest_edge_point := Vector2.ZERO
		for edge_index in range(points.size()):
			var edge_start := Vector2(points[edge_index].x, points[edge_index].z)
			var edge_end_point := points[(edge_index + 1) % points.size()]
			var edge_end := Vector2(edge_end_point.x, edge_end_point.z)
			var edge_point := _closest_point_on_plan_segment(plan_hit, edge_start, edge_end)
			var edge_distance := plan_hit.distance_to(edge_point)
			if edge_distance < closest_edge_distance:
				closest_edge_distance = edge_distance
				closest_edge_index = edge_index
				closest_edge_point = edge_point
		if (
			closest_edge_index >= 0
			and closest_edge_distance <= radius
			and camera_distance < best_edge_camera_distance
		):
			best_edge_camera_distance = camera_distance
			best_edge_pick = {
				"floor": floor,
				"edit_mask": FLOOR_EDIT_POLYGON_EDGE,
				"vertex_index": -1,
				"edge_index": closest_edge_index,
				"parent_position": Vector3(
					closest_edge_point.x,
					floor.start_point.y,
					closest_edge_point.y
				),
			}
	if (
		!best_vertex_pick.is_empty()
		and (
			best_edge_pick.is_empty()
			or best_vertex_camera_distance <= best_edge_camera_distance + 0.01
		)
	):
		return best_vertex_pick
	return best_edge_pick


func _closest_point_on_plan_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> Vector2:
	return m_context.closest_point_on_plan_segment(point, segment_start, segment_end)


func _raycast_floors(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var floors: Array[Floor3DScript] = []
	_collect_scene_floors(scene_root, floors)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for floor in floors:
		if !is_instance_valid(floor) or floor == m_floor_preview:
			continue
		if floor.has_meta(Floor3DScript.PREVIEW_META):
			continue
		var hit := _intersect_floor_box(floor, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_floors(node: Node, floors: Array[Floor3DScript]) -> void:
	if node is Floor3DScript:
		floors.append(node as Floor3DScript)
	for child in node.get_children():
		_collect_scene_floors(child, floors)


func _intersect_floor_box(
	floor: Floor3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var size := floor.get_floor_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return {}
	var inverse_frame := floor.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var min_corner := Vector3(0.0, -floor.floor_thickness, 0.0)
	var max_corner := Vector3(size.x, 0.0, size.y)
	var hit := _intersect_aabb_ray(local_origin, local_direction, min_corner, max_corner)
	if hit.is_empty():
		return {}

	var local_hit := Vector3(hit["position"])
	if !floor.contains_local_plan_point(Vector2(local_hit.x, local_hit.z)):
		return {}
	if floor.has_floor_hole_at_local_point(Vector2(local_hit.x, local_hit.z)):
		return {}
	var local_normal := _nearest_box_normal(local_hit, min_corner, max_corner)
	var global_hit := floor.global_transform * local_hit
	return {
		"floor": floor,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (floor.global_transform.basis * local_normal).normalized(),
		"collider": floor,
		"distance": origin.distance_to(global_hit),
	}


func _floor_edit_mask_for_local_hit(floor: Floor3DScript, local_hit: Vector3) -> int:
	if floor.has_any_floor_holes():
		return FLOOR_EDIT_MOVE
	if floor.is_polygon_floor():
		return FLOOR_EDIT_MOVE
	var size := floor.get_floor_size()
	var radius := maxf(_active_floor_grid_step(floor) * 0.35, 0.16)
	var edit_mask := FLOOR_EDIT_MOVE
	var min_x_distance := absf(local_hit.x)
	var max_x_distance := absf(size.x - local_hit.x)
	if minf(min_x_distance, max_x_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_X if min_x_distance <= max_x_distance else FLOOR_EDIT_MAX_X
	var min_z_distance := absf(local_hit.z)
	var max_z_distance := absf(size.y - local_hit.z)
	if minf(min_z_distance, max_z_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_Z if min_z_distance <= max_z_distance else FLOOR_EDIT_MAX_Z
	return edit_mask


func _find_roof_edit_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var handle_pick := _find_roof_handle_pick(camera, mouse_pos)
	if !handle_pick.is_empty():
		return handle_pick
	return _find_roof_pick(camera, mouse_pos)


func _find_roof_handle_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}
	var roofs: Array[Roof3DScript] = []
	_collect_scene_roofs(scene_root, roofs)
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var best_vertex_pick: Dictionary = {}
	var best_vertex_camera_distance := INF
	var best_edge_pick: Dictionary = {}
	var best_edge_camera_distance := INF
	for roof in roofs:
		if (
			!is_instance_valid(roof)
			or roof.get_roof_style() != RoofStyleGeometryFactory.STYLE_FLAT
		):
			continue
		if roof == m_roof_preview or roof.has_meta(Roof3DScript.PREVIEW_META):
			continue
		var parent_3d := roof.get_parent() as Node3D
		var local_origin := parent_3d.to_local(ray_origin) if parent_3d != null else ray_origin
		var local_direction := (
			parent_3d.global_transform.basis.inverse() * ray_direction
			if parent_3d != null
			else ray_direction
		)
		if local_direction.length_squared() <= 0.000001:
			continue
		local_direction = local_direction.normalized()
		if absf(local_direction.y) <= 0.001:
			continue
		var plane_distance := (roof.start_point.y - local_origin.y) / local_direction.y
		if plane_distance <= 0.0:
			continue
		var parent_hit := local_origin + local_direction * plane_distance
		var plan_hit := Vector2(parent_hit.x, parent_hit.z)
		var points := _get_roof_edit_points(roof)
		var radius := maxf(_active_roof_grid_step(roof) * 0.35, 0.16)
		var global_hit := parent_3d.to_global(parent_hit) if parent_3d != null else parent_hit
		var camera_distance := ray_origin.distance_to(global_hit)
		var closest_vertex_index := -1
		var closest_vertex_distance := INF
		for vertex_index in range(points.size()):
			var vertex_plan := Vector2(points[vertex_index].x, points[vertex_index].z)
			var vertex_distance := plan_hit.distance_to(vertex_plan)
			if vertex_distance < closest_vertex_distance:
				closest_vertex_distance = vertex_distance
				closest_vertex_index = vertex_index
		if (
			closest_vertex_index >= 0
			and closest_vertex_distance <= radius
			and camera_distance < best_vertex_camera_distance
		):
			best_vertex_camera_distance = camera_distance
			best_vertex_pick = {
				"roof": roof,
				"edit_mask": FLOOR_EDIT_POLYGON_VERTEX,
				"vertex_index": closest_vertex_index,
				"edge_index": -1,
				"parent_position": points[closest_vertex_index],
			}

		var closest_edge_index := -1
		var closest_edge_distance := INF
		var closest_edge_point := Vector2.ZERO
		for edge_index in range(points.size()):
			var edge_start := Vector2(points[edge_index].x, points[edge_index].z)
			var edge_end_point := points[(edge_index + 1) % points.size()]
			var edge_end := Vector2(edge_end_point.x, edge_end_point.z)
			var edge_point := _closest_point_on_plan_segment(plan_hit, edge_start, edge_end)
			var edge_distance := plan_hit.distance_to(edge_point)
			if edge_distance < closest_edge_distance:
				closest_edge_distance = edge_distance
				closest_edge_index = edge_index
				closest_edge_point = edge_point
		if (
			closest_edge_index >= 0
			and closest_edge_distance <= radius
			and camera_distance < best_edge_camera_distance
		):
			best_edge_camera_distance = camera_distance
			best_edge_pick = {
				"roof": roof,
				"edit_mask": FLOOR_EDIT_POLYGON_EDGE,
				"vertex_index": -1,
				"edge_index": closest_edge_index,
				"parent_position": Vector3(
					closest_edge_point.x,
					roof.start_point.y,
					closest_edge_point.y
				),
			}
	if (
		!best_vertex_pick.is_empty()
		and (
			best_edge_pick.is_empty()
			or best_vertex_camera_distance <= best_edge_camera_distance + 0.01
		)
	):
		return best_vertex_pick
	return best_edge_pick


func _find_roof_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_roofs(origin, direction)
	if hit.is_empty():
		return {}
	var roof := hit.get("roof") as Roof3DScript
	if roof == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mask"] = _roof_edit_mask_for_local_hit(roof, local_position)
	return hit


func _raycast_roofs(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var roofs: Array[Roof3DScript] = []
	_collect_scene_roofs(scene_root, roofs)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for roof in roofs:
		if !is_instance_valid(roof) or roof == m_roof_preview:
			continue
		if roof.has_meta(Roof3DScript.PREVIEW_META):
			continue
		var hit := _intersect_roof_bounds(roof, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_roofs(node: Node, roofs: Array[Roof3DScript]) -> void:
	if node is Roof3DScript:
		roofs.append(node as Roof3DScript)
	for child in node.get_children():
		_collect_scene_roofs(child, roofs)


func _intersect_roof_bounds(
	roof: Roof3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var size := roof.get_roof_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return {}
	var inverse_frame := roof.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var min_corner := roof.get_roof_bounds_min()
	var max_corner := roof.get_roof_bounds_max()
	var hit := _intersect_aabb_ray(local_origin, local_direction, min_corner, max_corner)
	if hit.is_empty():
		return {}

	var local_hit := Vector3(hit["position"])
	if !roof.contains_local_plan_point(Vector2(local_hit.x, local_hit.z)):
		return {}
	var local_normal := _nearest_box_normal(local_hit, min_corner, max_corner)
	var global_hit := roof.global_transform * local_hit
	return {
		"roof": roof,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (roof.global_transform.basis * local_normal).normalized(),
		"collider": roof,
		"distance": origin.distance_to(global_hit),
	}


func _roof_edit_mask_for_local_hit(roof: Roof3DScript, local_hit: Vector3) -> int:
	var size := roof.get_roof_size()
	var overhang := maxf(roof.roof_overhang, 0.0)
	var radius := maxf(_active_roof_grid_step(roof) * 0.35, 0.16)
	var edit_mask := FLOOR_EDIT_MOVE
	var min_x_distance := absf(local_hit.x + overhang)
	var max_x_distance := absf(size.x + overhang - local_hit.x)
	if minf(min_x_distance, max_x_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_X if min_x_distance <= max_x_distance else FLOOR_EDIT_MAX_X
	var min_z_distance := absf(local_hit.z + overhang)
	var max_z_distance := absf(size.y + overhang - local_hit.z)
	if minf(min_z_distance, max_z_distance) <= radius:
		edit_mask |= FLOOR_EDIT_MIN_Z if min_z_distance <= max_z_distance else FLOOR_EDIT_MAX_Z
	return edit_mask


func _collect_scene_walls(node: Node, walls: Array[Wall3DScript]) -> void:
	if node is Wall3DScript:
		walls.append(node as Wall3DScript)
	for child in node.get_children():
		_collect_scene_walls(child, walls)


func _intersect_wall_box(
	wall: Wall3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var best_hit: Dictionary = {}
	var best_distance := INF
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		var segment_length := segment.get_length()
		if segment_length <= 0.001:
			continue
		var world_frame := wall.global_transform * wall.get_segment_local_frame(segment_index)
		var inverse_frame := world_frame.affine_inverse()
		var local_origin := inverse_frame * origin
		var local_direction := (inverse_frame.basis * direction)
		if local_direction.length_squared() <= 0.000001:
			continue
		local_direction = local_direction.normalized()

		var half_thickness := segment.thickness * 0.5
		var min_corner := Vector3(0.0, 0.0, -half_thickness)
		var max_corner := Vector3(segment_length, segment.height, half_thickness)
		var hit := _intersect_aabb_ray(local_origin, local_direction, min_corner, max_corner)
		if hit.is_empty():
			continue

		var local_hit := Vector3(hit["position"])
		var local_normal := _nearest_box_normal(local_hit, min_corner, max_corner)
		var global_hit := world_frame * local_hit
		var distance := origin.distance_to(global_hit)
		if distance >= best_distance:
			continue
		best_distance = distance
		best_hit = {
			"position": global_hit,
			"normal": (world_frame.basis * local_normal).normalized(),
			"collider": wall,
			"segment": segment_index,
			"distance": distance,
		}
	return best_hit


func _intersect_aabb_ray(
	origin: Vector3,
	direction: Vector3,
	min_corner: Vector3,
	max_corner: Vector3
) -> Dictionary:
	return m_context.intersect_aabb_ray(origin, direction, min_corner, max_corner)


func _axis_value(value: Vector3, axis: int) -> float:
	return m_context.axis_value(value, axis)


func _nearest_box_normal(point: Vector3, min_corner: Vector3, max_corner: Vector3) -> Vector3:
	return m_context.nearest_box_normal(point, min_corner, max_corner)


func _find_wall_from_collider(collider: Variant) -> Wall3DScript:
	var node := collider as Node
	while node != null:
		if node is Wall3DScript:
			return node as Wall3DScript
		node = node.get_parent()
	return null


func _get_or_create_coordinator(create_if_missing: bool) -> Building3DScript:
	return m_context.get_or_create_coordinator(create_if_missing)


func _create_coordinator() -> Building3DScript:
	return m_context.create_coordinator()


func _find_selected_coordinator() -> Building3DScript:
	return m_context.find_selected_coordinator()


func _coordinator_belongs_to_scene(coordinator: Building3DScript, scene_root: Node) -> bool:
	return m_context.coordinator_belongs_to_scene(coordinator, scene_root)


func _find_coordinator_from_node(node: Node) -> Building3DScript:
	return m_context.find_coordinator_from_node(node)


func _find_first_coordinator(root: Node) -> Building3DScript:
	return m_context.find_first_coordinator(root)


func _active_grid_step(wall: Wall3DScript) -> float:
	return maxf(float(m_wall_settings["grid_step"]), 0.05)


func _apply_wall_geometry(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	opening_anchors: Array = []
) -> void:
	wall.set_wall_geometry(new_start, new_end, _duplicate_segments(segments), opening_anchors)


func _refresh_wall_intersections(coordinator: Building3DScript) -> void:
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_building_geometry_clips()


func _set_wall_endpoints_and_refresh_intersections(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	coordinator: Building3DScript
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	wall.set_wall_endpoints(new_start, new_end)
	_refresh_wall_intersections(coordinator)


func _do_set_wall_geometry(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	_apply_wall_geometry(wall, new_start, new_end, segments)
	if select_after:
		_select_node(wall)


func _do_set_wall_geometry_and_refresh_intersections(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool,
	coordinator: Building3DScript
) -> void:
	_do_set_wall_geometry(wall, new_start, new_end, segments, select_after)
	_refresh_wall_intersections(coordinator)


func _do_set_wall_geometry_preserving_children(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	wall.set_wall_geometry_preserving_child_transforms(
		new_start,
		new_end,
		_duplicate_segments(segments)
	)
	if select_after:
		_select_node(wall)


func _do_set_wall_geometry_preserving_children_and_refresh_intersections(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegmentScript],
	select_after: bool,
	coordinator: Building3DScript
) -> void:
	_do_set_wall_geometry_preserving_children(wall, new_start, new_end, segments, select_after)
	_refresh_wall_intersections(coordinator)


func _duplicate_segments(segments: Array) -> Array[WallSegmentScript]:
	var copies: Array[WallSegmentScript] = []
	for segment in segments:
		var typed_segment := segment as WallSegmentScript
		if typed_segment == null:
			continue
		copies.append(typed_segment.duplicate() as WallSegmentScript)
	return copies


func _duplicate_wall_segments(wall: Wall3DScript) -> Array[WallSegmentScript]:
	var segments: Array[WallSegmentScript] = []
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment == null:
			continue
		segments.append(segment.duplicate() as WallSegmentScript)
	return segments


func _normalized_wall_geometry(wall: Wall3DScript) -> Dictionary:
	var tolerance := maxf(_active_grid_step(wall) * 0.25, 0.03)
	var combined: Array[WallSegmentScript] = []
	for segment in _duplicate_wall_segments(wall):
		WallSegmentScript.merge_into(combined, segment, tolerance, false)
	var split_segments := WallSegmentScript.split_at_intersections(combined, tolerance)
	return _wall_geometry_from_segments(split_segments)


func _wall_geometry_from_segments(segments: Array) -> Dictionary:
	if segments.is_empty():
		return {}
	var primary := segments[0] as WallSegmentScript
	if primary == null:
		return {}
	var extras: Array[WallSegmentScript] = []
	for segment_index in range(1, segments.size()):
		var segment := segments[segment_index] as WallSegmentScript
		if segment == null:
			continue
		extras.append(segment.duplicate() as WallSegmentScript)
	return {
		"start": primary.start_point,
		"end": primary.end_point,
		"segments": extras,
	}


func _wall_geometry_snapshot(wall: Wall3DScript) -> Dictionary:
	if wall == null:
		return {}
	return _wall_geometry_from_segments(_duplicate_wall_segments(wall))


func _wall_segment_zero_epsilon(wall: Wall3DScript) -> float:
	return maxf(_active_grid_step(wall) * 0.01, 0.001)


func _is_dragged_wall_span_zero_length(wall: Wall3DScript) -> bool:
	if wall == null:
		return false
	var segment_index := clampi(m_drag_wall_segment_index, 0, wall.get_segment_count() - 1)
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	return segment.get_length() <= _wall_segment_zero_epsilon(wall)


func _wall_geometry_without_segment(
	wall: Wall3DScript,
	removed_segment_index: int
) -> Dictionary:
	var remaining: Array[WallSegmentScript] = []
	var zero_epsilon := _wall_segment_zero_epsilon(wall)
	for segment_index in range(wall.get_segment_count()):
		if segment_index == removed_segment_index:
			continue
		var segment := wall.get_segment(segment_index).duplicate() as WallSegmentScript
		if segment == null or segment.get_length() <= zero_epsilon:
			continue
		remaining.append(segment)
	if remaining.is_empty():
		return {}
	return _wall_geometry_from_segments(remaining)


func _commit_add_wall_joint(
	wall: Wall3DScript,
	segment_index: int,
	hit_world: Vector3
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	var hit_parent_local := _wall_world_to_parent_local(wall, hit_world)
	var coordinator := _find_coordinator_from_node(wall)
	if coordinator != null:
		hit_parent_local = BuildingFactoryScript.snap_local_position(
			hit_parent_local,
			float(m_wall_settings["grid_step"])
		)
	var minimum_piece_length := maxf(_active_grid_step(wall) * 0.5, 0.1)
	var geometry := wall.split_segment_geometry(segment_index, hit_parent_local, minimum_piece_length)
	if geometry.is_empty():
		_set_status("Joint is too close to an endpoint.")
		return
	var old_geometry := _wall_geometry_snapshot(wall)
	if old_geometry.is_empty():
		return
	var old_start := Vector3(old_geometry["start"])
	var old_end := Vector3(old_geometry["end"])
	var old_segments: Array[WallSegmentScript] = old_geometry["segments"]
	var new_segments: Array[WallSegmentScript] = geometry["segments"]
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Add Wall Joint")
	undo_redo.add_do_method(
		self,
		"_do_set_wall_geometry_preserving_children_and_refresh_intersections",
		wall,
		Vector3(geometry["start"]),
		Vector3(geometry["end"]),
		new_segments,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_do_set_wall_geometry_preserving_children_and_refresh_intersections",
		wall,
		old_start,
		old_end,
		old_segments,
		true,
		coordinator
	)
	undo_redo.commit_action()
	_clear_wall_hover()
	_set_status("Added wall joint.")


func _wall_world_to_parent_local(wall: Wall3DScript, world_position: Vector3) -> Vector3:
	var wall_parent := wall.get_parent() as Node3D
	if wall_parent != null:
		return wall_parent.to_local(world_position)
	return wall.to_local(world_position)


func _commit_delete_zero_length_wall_segment(
	wall: Wall3DScript,
	geometry: Dictionary,
	old_start: Vector3,
	old_end: Vector3,
	old_segments: Array[WallSegmentScript]
) -> void:
	var next_segments: Array[WallSegmentScript] = geometry["segments"]
	var coordinator := _find_coordinator_from_node(wall)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Delete Wall Segment")
	undo_redo.add_do_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		Vector3(geometry["start"]),
		Vector3(geometry["end"]),
		next_segments,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		old_start,
		old_end,
		old_segments,
		true,
		coordinator
	)
	undo_redo.commit_action()
	_set_status("Deleted zero-length wall segment.")


func _commit_delete_zero_length_wall(
	wall: Wall3DScript,
	old_start: Vector3,
	old_end: Vector3,
	old_segments: Array[WallSegmentScript]
) -> void:
	var parent := wall.get_parent()
	var coordinator := parent as Building3DScript
	var scene_root := get_editor_interface().get_edited_scene_root()
	if parent == null or scene_root == null:
		_apply_wall_geometry(wall, old_start, old_end, old_segments)
		_set_status("Wall is too short.")
		return
	_apply_wall_geometry(wall, old_start, old_end, old_segments)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Delete Wall")
	undo_redo.add_undo_reference(wall)
	undo_redo.add_do_method(self, "_undo_remove_node_and_refresh_wall_intersections", parent, wall, coordinator)
	undo_redo.add_undo_method(
		self,
		"_do_add_node_and_refresh_wall_intersections",
		parent,
		wall,
		scene_root,
		true,
		coordinator
	)
	undo_redo.commit_action()
	_set_status("Deleted zero-length wall.")


func _apply_drag_wall_endpoint(snapped_position: Vector3) -> void:
	if m_dragging_wall == null:
		return
	var extras := _duplicate_segments(m_drag_wall_old_segments)
	_apply_wall_geometry(
		m_dragging_wall,
		m_drag_wall_old_start,
		m_drag_wall_old_end,
		extras,
		m_drag_wall_opening_anchors
	)
	if m_drag_wall_dragging_joint:
		m_dragging_wall.move_connected_endpoint(
			m_drag_wall_joint_origin,
			snapped_position,
			_wall_joint_tolerance(m_dragging_wall)
		)
		return
	m_dragging_wall.move_segment_endpoint(
		m_drag_wall_segment_index,
		m_drag_wall_endpoint,
		snapped_position
	)


func _translate_drag_wall_geometry(delta: Vector3) -> void:
	if m_dragging_wall == null:
		return
	var extras := _duplicate_segments(m_drag_wall_old_segments)
	for segment in extras:
		segment.start_point += delta
		segment.end_point += delta
	_apply_wall_geometry(
		m_dragging_wall,
		m_drag_wall_old_start + delta,
		m_drag_wall_old_end + delta,
		extras,
		m_drag_wall_opening_anchors
	)


func _resize_drag_room_side(delta: Vector3) -> void:
	if m_dragging_wall == null:
		return
	var extras := _duplicate_segments(m_drag_wall_old_segments)
	_apply_wall_geometry(
		m_dragging_wall,
		m_drag_wall_old_start,
		m_drag_wall_old_end,
		extras,
		m_drag_wall_opening_anchors
	)
	m_dragging_wall.move_rectangular_loop_side(
		m_drag_wall_segment_index,
		delta,
		_wall_joint_tolerance(m_dragging_wall)
	)


func _is_dragged_wall_span_long_enough(wall: Wall3DScript) -> bool:
	if wall == null:
		return false
	var segment_index := clampi(m_drag_wall_segment_index, 0, wall.get_segment_count() - 1)
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	return _is_wall_span_long_enough(segment.start_point, segment.end_point)


func _are_dragged_wall_spans_long_enough(wall: Wall3DScript) -> bool:
	if wall == null:
		return false
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment == null or !_is_wall_span_long_enough(segment.start_point, segment.end_point):
			return false
	return true


func _find_intersecting_targets_for_wall(
	coordinator: Building3DScript,
	wall: Wall3DScript
) -> Array[Wall3DScript]:
	var targets: Array[Wall3DScript] = []
	for segment in _duplicate_wall_segments(wall):
		var hits := coordinator.find_intersecting_walls(
			segment.start_point,
			segment.end_point,
			segment.thickness,
			wall
		)
		for candidate in hits:
			if candidate == wall or targets.has(candidate):
				continue
			targets.append(candidate)
	return targets


func _snap_world_position(world_position: Vector3) -> Vector3:
	return m_context.snap_world_position(
		world_position, float(m_wall_settings["grid_step"])
	)


func _set_preview_parent(preview: Node3D, parent: Node) -> void:
	m_context.set_preview_parent(preview, parent)


func _apply_preview_material(node: Node, color: Color) -> void:
	m_context.apply_preview_material(node, color)


func _build_preview_material(color: Color) -> StandardMaterial3D:
	return m_context.build_preview_material(color)


func _update_floor_hover(floor: Floor3DScript, edit_mask: int) -> void:
	if floor == m_drag_floor_hover and edit_mask == m_drag_floor_hover_edit_mask:
		return
	_clear_floor_hover()
	if floor == null:
		return
	m_drag_floor_hover = floor
	m_drag_floor_hover_edit_mask = edit_mask
	m_drag_floor_hover_material = floor.material_override
	floor.material_override = _build_preview_material(_floor_drag_color(edit_mask, true))


func _clear_floor_hover() -> void:
	if m_drag_floor_hover == null:
		return
	if is_instance_valid(m_drag_floor_hover):
		m_drag_floor_hover.material_override = m_drag_floor_hover_material
	m_drag_floor_hover = null
	m_drag_floor_hover_material = null
	m_drag_floor_hover_edit_mask = FLOOR_EDIT_MOVE


func _update_roof_hover(roof: Roof3DScript, edit_mask: int) -> void:
	if roof == m_drag_roof_hover and edit_mask == m_drag_roof_hover_edit_mask:
		return
	_clear_roof_hover()
	if roof == null:
		return
	m_drag_roof_hover = roof
	m_drag_roof_hover_edit_mask = edit_mask
	m_drag_roof_hover_material = roof.material_override
	roof.material_override = _build_preview_material(_roof_drag_color(edit_mask, true))


func _clear_roof_hover() -> void:
	if m_drag_roof_hover == null:
		return
	if is_instance_valid(m_drag_roof_hover):
		m_drag_roof_hover.material_override = m_drag_roof_hover_material
	m_drag_roof_hover = null
	m_drag_roof_hover_material = null
	m_drag_roof_hover_edit_mask = FLOOR_EDIT_MOVE


func _clear_wall_preview() -> void:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		m_wall_preview.queue_free()
	m_wall_preview = null


func _clear_floor_preview() -> void:
	if m_floor_preview != null and is_instance_valid(m_floor_preview):
		m_floor_preview.queue_free()
	m_floor_preview = null


func _clear_roof_preview() -> void:
	if m_roof_preview != null and is_instance_valid(m_roof_preview):
		m_roof_preview.queue_free()
	m_roof_preview = null


func _reset_wall_drawing_state() -> void:
	m_is_drawing_wall = false
	m_wall_has_valid_preview = false
	m_wall_release_commits_preview = false
	m_wall_start_screen_position = Vector2.ZERO


func _reset_floor_drawing_state() -> void:
	m_is_drawing_floor = false
	m_floor_has_valid_preview = false
	m_floor_release_commits_preview = false
	m_floor_start_screen_position = Vector2.ZERO
	m_floor_polygon_points = PackedVector3Array()


func _reset_roof_drawing_state() -> void:
	m_is_drawing_roof = false
	m_roof_has_valid_preview = false
	m_roof_release_commits_preview = false
	m_roof_start_screen_position = Vector2.ZERO
	m_roof_polygon_points = PackedVector3Array()
	m_roof_draw_rotation_degrees = _normalize_degrees(float(m_roof_settings.get("rotation_degrees", 0.0)))


func _clear_prop_preview() -> void:
	if m_prop_preview != null and is_instance_valid(m_prop_preview):
		m_prop_preview.queue_free()
	m_prop_preview = null
	m_prop_preview_path = ""
	m_preview_parent = null
	m_preview_wall = null
	m_preview_valid = false


func _find_wall_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var hit := _raycast_world(camera, mouse_pos)
	var wall := _find_wall_from_collider(hit.get("collider"))
	if wall == null:
		return {}
	var hit_world := Vector3(hit["position"])
	var ep_radius := 0.4
	var segment_hint := int(hit.get("segment", 0))
	var wall_parent := wall.get_parent() as Node3D
	var hit_parent_local := wall_parent.to_local(hit_world) if wall_parent != null else wall.to_local(hit_world)
	for offset in range(wall.get_segment_count()):
		var segment_index := (segment_hint + offset) % wall.get_segment_count()
		var segment := wall.get_segment(segment_index)
		if _hit_near_wall_endpoint(hit_parent_local, segment.start_point, segment, ep_radius):
			var start_joint := _wall_joint_info(wall, segment.start_point)
			return {
				"wall": wall,
				"segment": segment_index,
				"endpoint": 0,
				"joint": bool(start_joint["joint"]),
				"joint_position": start_joint["position"],
				"position": hit_world,
			}
		if _hit_near_wall_endpoint(hit_parent_local, segment.end_point, segment, ep_radius):
			var end_joint := _wall_joint_info(wall, segment.end_point)
			return {
				"wall": wall,
				"segment": segment_index,
				"endpoint": 1,
				"joint": bool(end_joint["joint"]),
				"joint_position": end_joint["position"],
				"position": hit_world,
			}
	return {"wall": wall, "segment": segment_hint, "endpoint": -1, "position": hit_world}


func _hit_near_wall_endpoint(
	hit_parent_local: Vector3,
	endpoint: Vector3,
	segment: WallSegmentScript,
	radius: float
) -> bool:
	if hit_parent_local.y < endpoint.y - radius or hit_parent_local.y > endpoint.y + segment.height + radius:
		return false
	var hit_2d := Vector2(hit_parent_local.x, hit_parent_local.z)
	var endpoint_2d := Vector2(endpoint.x, endpoint.z)
	return hit_2d.distance_to(endpoint_2d) <= radius


func _wall_joint_info(wall: Wall3DScript, endpoint: Vector3) -> Dictionary:
	var tolerance := _wall_joint_tolerance(wall)
	var count := 0
	var total := Vector3.ZERO
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment.start_point.distance_to(endpoint) <= tolerance:
			count += 1
			total += segment.start_point
		if segment.end_point.distance_to(endpoint) <= tolerance:
			count += 1
			total += segment.end_point
	var position := endpoint
	if count > 0:
		position = total / float(count)
	return {
		"joint": count >= 2,
		"position": position,
		"count": count,
	}


func _wall_joint_tolerance(wall: Wall3DScript) -> float:
	return maxf(_active_grid_step(wall) * 0.05, 0.03)


func _wall_connection_snap_radius(wall: Wall3DScript) -> float:
	return maxf(maxf(_active_grid_step(wall) * 0.45, wall.wall_thickness * 1.25), 0.08)


func _drag_wall_endpoint_position(
	wall: Wall3DScript,
	segment_index: int,
	endpoint: int
) -> Vector3:
	if wall == null or wall.get_segment_count() <= 0:
		return Vector3.ZERO
	var segment := wall.get_segment(clampi(segment_index, 0, wall.get_segment_count() - 1))
	if segment == null:
		return Vector3.ZERO
	return segment.start_point if endpoint == 0 else segment.end_point


func _snap_drag_wall_endpoint_to_connection(snapped_position: Vector3) -> Vector3:
	m_drag_wall_has_connection_snap = false
	if m_dragging_wall == null or m_drag_wall_endpoint < 0 or m_drag_wall_dragging_joint:
		return snapped_position
	var target := _nearest_wall_connection_endpoint(
		m_dragging_wall,
		snapped_position,
		_wall_connection_snap_radius(m_dragging_wall)
	)
	if target.is_empty():
		return snapped_position
	var target_position := Vector3(target["position"])
	m_drag_wall_has_connection_snap = true
	return Vector3(target_position.x, snapped_position.y, target_position.z)


func _nearest_wall_connection_endpoint(
	wall: Wall3DScript,
	position: Vector3,
	radius: float
) -> Dictionary:
	var candidates: Array[Wall3DScript] = []
	var coordinator := _find_coordinator_from_node(wall)
	if coordinator != null:
		candidates = coordinator.get_wall_nodes()
	else:
		candidates.append(wall)
	var best_distance := radius
	var best_position := Vector3.ZERO
	var found := false
	for candidate_wall in candidates:
		if candidate_wall == null or !is_instance_valid(candidate_wall):
			continue
		if candidate_wall.has_meta(Wall3DScript.PREVIEW_META):
			continue
		for segment_index in range(candidate_wall.get_segment_count()):
			var segment := candidate_wall.get_segment(segment_index)
			var endpoints := [segment.start_point, segment.end_point]
			for endpoint_index in range(endpoints.size()):
				if (
					candidate_wall == wall
					and segment_index == m_drag_wall_segment_index
					and endpoint_index == m_drag_wall_endpoint
				):
					continue
				var endpoint := Vector3(endpoints[endpoint_index])
				if absf(endpoint.y - position.y) > 0.01:
					continue
				var distance := Vector2(endpoint.x - position.x, endpoint.z - position.z).length()
				if distance > best_distance:
					continue
				best_distance = distance
				best_position = endpoint
				found = true
	if !found:
		return {}
	return {
		"position": best_position,
		"distance": best_distance,
	}


func _update_wall_hover(
	wall: Wall3DScript,
	segment_index: int,
	endpoint: int,
	joint_position: Vector3,
	has_joint: bool
) -> void:
	if (
		wall == m_drag_wall_hover
		and segment_index == m_drag_wall_hover_segment
		and endpoint == m_drag_wall_hover_endpoint
		and has_joint == m_drag_wall_hover_has_joint
		and (!has_joint or joint_position.distance_to(m_drag_wall_hover_joint_position) <= 0.001)
	):
		return
	_clear_wall_hover()
	if wall == null:
		return
	m_drag_wall_hover = wall
	m_drag_wall_hover_segment = segment_index
	m_drag_wall_hover_endpoint = endpoint
	m_drag_wall_hover_has_joint = has_joint
	m_drag_wall_hover_joint_position = joint_position
	m_drag_wall_hover_material = wall.material_override
	var color := Color(1.0, 0.85, 0.20, 0.65) if endpoint >= 0 else Color(0.20, 0.60, 1.0, 0.55)
	wall.material_override = _build_preview_material(color)
	if has_joint:
		_show_wall_joint_hover(wall, joint_position)


func _clear_wall_hover() -> void:
	_clear_wall_joint_hover()
	if m_drag_wall_hover == null:
		return
	if is_instance_valid(m_drag_wall_hover):
		m_drag_wall_hover.material_override = m_drag_wall_hover_material
	m_drag_wall_hover = null
	m_drag_wall_hover_material = null
	m_drag_wall_hover_segment = 0
	m_drag_wall_hover_endpoint = -1
	m_drag_wall_hover_has_joint = false
	m_drag_wall_hover_joint_position = Vector3.ZERO


func _show_wall_joint_hover(wall: Wall3DScript, joint_position: Vector3) -> void:
	_clear_wall_joint_hover()
	if wall == null or !is_instance_valid(wall):
		return
	var marker := MeshInstance3D.new()
	marker.name = "WallJointHover"
	marker.set_meta(Wall3DScript.GENERATED_META, true)
	var mesh := SphereMesh.new()
	var radius := maxf(wall.wall_thickness * 0.85, 0.16)
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	marker.mesh = mesh
	marker.material_override = _build_joint_hover_material()
	wall.add_child(marker)
	marker.owner = null
	var display_position := joint_position
	display_position.y += _wall_joint_hover_height(wall, joint_position)
	marker.position = _wall_parent_local_to_wall_local(wall, display_position)
	m_drag_wall_hover_joint_marker = marker


func _clear_wall_joint_hover() -> void:
	if m_drag_wall_hover_joint_marker != null and is_instance_valid(m_drag_wall_hover_joint_marker):
		m_drag_wall_hover_joint_marker.queue_free()
	m_drag_wall_hover_joint_marker = null


func _wall_joint_hover_height(wall: Wall3DScript, joint_position: Vector3) -> float:
	var tolerance := _wall_joint_tolerance(wall)
	var height := 0.0
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if (
			segment.start_point.distance_to(joint_position) <= tolerance
			or segment.end_point.distance_to(joint_position) <= tolerance
		):
			height = maxf(height, segment.height)
	if height <= 0.0:
		height = wall.wall_height
	return height * 0.55


func _wall_parent_local_to_wall_local(wall: Wall3DScript, parent_local_position: Vector3) -> Vector3:
	var wall_parent := wall.get_parent() as Node3D
	if wall_parent == null:
		return wall.to_local(parent_local_position)
	return wall.to_local(wall_parent.to_global(parent_local_position))


func _build_joint_hover_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.46, 0.05, 0.95)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.34, 0.02, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _start_wall_drag(
	wall: Wall3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	segment_index: int,
	endpoint: int,
	alt_modifier: bool = false
) -> void:
	m_dragging_wall = wall
	var old_geometry := _wall_geometry_snapshot(wall)
	if old_geometry.is_empty():
		m_dragging_wall = null
		return
	m_drag_wall_old_start = Vector3(old_geometry["start"])
	m_drag_wall_old_end = Vector3(old_geometry["end"])
	m_drag_wall_old_segments = old_geometry["segments"]
	m_drag_wall_opening_anchors = wall.capture_opening_segment_anchors()
	m_drag_wall_segment_index = clampi(segment_index, 0, wall.get_segment_count() - 1)
	m_drag_wall_endpoint = endpoint
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	var is_room := wall.is_rectangular_loop(_wall_joint_tolerance(wall))
	# Alt/Option-dragging a room body moves the whole room instead of resizing one side.
	m_drag_wall_resizing_room_side = (
		endpoint < 0
		and !alt_modifier
		and is_room
	)
	if endpoint >= 0:
		m_drag_wall_joint_origin = _drag_wall_endpoint_position(wall, m_drag_wall_segment_index, endpoint)
		var is_shared_joint := wall.count_connected_endpoints(
			m_drag_wall_joint_origin,
			_wall_joint_tolerance(wall)
		) >= 2
		m_drag_wall_dragging_joint = is_shared_joint and !alt_modifier
		m_drag_wall_detaching_joint = is_shared_joint and alt_modifier
	m_drag_wall_active_material = wall.material_override
	var coordinator := _find_coordinator_from_node(wall)
	var hit := _raycast_world(camera, mouse_pos, false)
	m_drag_wall_anchor_local = (
		coordinator.to_local(Vector3(hit["position"])) if coordinator != null
		else Vector3(hit["position"])
	)
	var color := (
		Color(1.0, 0.46, 0.05, 0.75) if m_drag_wall_dragging_joint
		else Color(1.0, 0.85, 0.20, 0.75) if endpoint >= 0
		else Color(0.20, 0.60, 1.0, 0.55)
	)
	wall.material_override = _build_preview_material(color)
	var action := (
		"joint"
		if m_drag_wall_dragging_joint
		else "detached endpoint" if m_drag_wall_detaching_joint
		else "endpoint" if endpoint >= 0
		else "room wall" if m_drag_wall_resizing_room_side
		else "room" if is_room
		else "wall"
	)
	_set_status("Dragging %s — release to commit, Escape to cancel." % action)


func _update_wall_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_wall == null or !is_instance_valid(m_dragging_wall):
		m_dragging_wall = null
		m_drag_wall_old_segments.clear()
		m_drag_wall_opening_anchors.clear()
		m_drag_wall_resizing_room_side = false
		return
	var coordinator := _find_coordinator_from_node(m_dragging_wall)
	var hit := _raycast_world(camera, mouse_pos, false)
	var hit_local: Vector3 = (
		coordinator.to_local(Vector3(hit["position"])) if coordinator != null
		else Vector3(hit["position"])
	)
	var step := _active_grid_step(m_dragging_wall)

	if m_drag_wall_endpoint >= 0:
		var snapped := Vector3(
			roundf(hit_local.x / step) * step,
			0.0,
			roundf(hit_local.z / step) * step
		)
		snapped = _snap_drag_wall_endpoint_to_connection(snapped)
		_apply_drag_wall_endpoint(snapped)
		var zero_span := _is_dragged_wall_span_zero_length(m_dragging_wall)
		var valid_span := _is_dragged_wall_span_long_enough(m_dragging_wall)
		var drag_color := Color(1.0, 0.46, 0.05, 0.75) if m_drag_wall_dragging_joint else Color(1.0, 0.85, 0.20, 0.75)
		if zero_span:
			drag_color = Color(1.0, 0.46, 0.05, 0.75)
		elif !valid_span:
			drag_color = Color(0.95, 0.20, 0.16, 0.72)
		elif m_drag_wall_has_connection_snap:
			drag_color = Color(0.20, 0.88, 0.36, 0.75)
		m_dragging_wall.material_override = _build_preview_material(drag_color)
		if zero_span:
			_set_status(
				"Release to delete segment."
				if m_dragging_wall.get_segment_count() > 1
				else "Release to delete wall."
			)
		else:
			var drag_target := "joint" if m_drag_wall_dragging_joint else "endpoint"
			if valid_span:
				if m_drag_wall_has_connection_snap:
					_set_status("Release to connect endpoint.")
				elif m_drag_wall_detaching_joint:
					_set_status("Release to disconnect endpoint.")
				else:
					_set_status("Release to commit %s." % drag_target)
			else:
				_set_status("Wall is too short.")
	else:
		var raw_delta := hit_local - m_drag_wall_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		if m_drag_wall_resizing_room_side:
			_resize_drag_room_side(snapped_delta)
			var room_valid := _are_dragged_wall_spans_long_enough(m_dragging_wall)
			m_dragging_wall.material_override = _build_preview_material(
				Color(0.20, 0.60, 1.0, 0.55)
				if room_valid
				else Color(0.95, 0.20, 0.16, 0.72)
			)
			_set_status("Release to resize room." if room_valid else "Room is too small.")
		else:
			_translate_drag_wall_geometry(snapped_delta)
			_set_status("Release to commit.")


func _commit_wall_drag() -> void:
	if m_dragging_wall == null:
		return
	var wall := m_dragging_wall
	var new_geometry := _wall_geometry_snapshot(wall)
	if new_geometry.is_empty():
		_cancel_wall_drag()
		return
	var new_start := Vector3(new_geometry["start"])
	var new_end := Vector3(new_geometry["end"])
	var new_segments: Array[WallSegmentScript] = new_geometry["segments"]
	var old_start := m_drag_wall_old_start
	var old_end := m_drag_wall_old_end
	var old_segments := _duplicate_segments(m_drag_wall_old_segments)
	var was_joint_drag := m_drag_wall_dragging_joint
	var was_detaching_joint := m_drag_wall_detaching_joint
	var was_connection_snap := m_drag_wall_has_connection_snap
	var was_room_resize := m_drag_wall_resizing_room_side
	m_dragging_wall = null
	wall.material_override = m_drag_wall_active_material
	m_drag_wall_active_material = null
	if m_drag_wall_endpoint >= 0 and _is_dragged_wall_span_zero_length(wall):
		var deletion_geometry := _wall_geometry_without_segment(wall, m_drag_wall_segment_index)
		if deletion_geometry.is_empty():
			_commit_delete_zero_length_wall(wall, old_start, old_end, old_segments)
		else:
			_commit_delete_zero_length_wall_segment(wall, deletion_geometry, old_start, old_end, old_segments)
		m_drag_wall_old_segments.clear()
		m_drag_wall_opening_anchors.clear()
		m_drag_wall_segment_index = 0
		m_drag_wall_endpoint = -1
		m_drag_wall_joint_origin = Vector3.ZERO
		m_drag_wall_dragging_joint = false
		m_drag_wall_detaching_joint = false
		m_drag_wall_has_connection_snap = false
		m_drag_wall_resizing_room_side = false
		return
	var wall_geometry_valid := (
		_are_dragged_wall_spans_long_enough(wall)
		if was_room_resize
		else _is_dragged_wall_span_long_enough(wall)
	)
	if !wall_geometry_valid:
		_apply_wall_geometry(wall, old_start, old_end, old_segments, m_drag_wall_opening_anchors)
		m_drag_wall_old_segments.clear()
		m_drag_wall_opening_anchors.clear()
		m_drag_wall_segment_index = 0
		m_drag_wall_endpoint = -1
		m_drag_wall_joint_origin = Vector3.ZERO
		m_drag_wall_dragging_joint = false
		m_drag_wall_detaching_joint = false
		m_drag_wall_has_connection_snap = false
		m_drag_wall_resizing_room_side = false
		_set_status("Room is too small." if was_room_resize else "Wall is too short.")
		return
	var coordinator := _find_coordinator_from_node(wall)
	var intersects_after_move := false
	if coordinator != null:
		intersects_after_move = !_find_intersecting_targets_for_wall(coordinator, wall).is_empty()
	var normalized_geometry := _normalized_wall_geometry(wall)
	if !normalized_geometry.is_empty():
		new_start = Vector3(normalized_geometry["start"])
		new_end = Vector3(normalized_geometry["end"])
		new_segments = normalized_geometry["segments"]
	var undo_redo := get_undo_redo()
	var move_action_name := (
		"Move Room"
		if wall.is_rectangular_loop(_wall_joint_tolerance(wall))
		else "Move Wall"
	)
	undo_redo.create_action("Resize Room" if was_room_resize else move_action_name)
	undo_redo.add_do_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		new_start,
		new_end,
		new_segments,
		true,
		coordinator
	)
	undo_redo.add_undo_method(
		self,
		"_do_set_wall_geometry_and_refresh_intersections",
		wall,
		old_start,
		old_end,
		old_segments,
		true,
		coordinator
	)
	undo_redo.commit_action()
	m_drag_wall_old_segments.clear()
	m_drag_wall_opening_anchors.clear()
	m_drag_wall_segment_index = 0
	m_drag_wall_endpoint = -1
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	m_drag_wall_resizing_room_side = false
	if was_room_resize:
		_set_status("Resized room.")
	elif was_connection_snap:
		_set_status("Connected wall endpoint.")
	elif was_detaching_joint:
		_set_status("Disconnected wall endpoint.")
	elif was_joint_drag:
		_set_status("Moved wall joint.")
	elif intersects_after_move:
		_set_status("Moved wall and clipped intersections.")
	else:
		_set_status("Moved wall.")


func _cancel_wall_drag() -> void:
	if m_dragging_wall == null:
		return
	var coordinator := _find_coordinator_from_node(m_dragging_wall)
	if is_instance_valid(m_dragging_wall):
		_apply_wall_geometry(
			m_dragging_wall,
			m_drag_wall_old_start,
			m_drag_wall_old_end,
			m_drag_wall_old_segments,
			m_drag_wall_opening_anchors
		)
		m_dragging_wall.material_override = m_drag_wall_active_material
		if coordinator != null:
			coordinator.refresh_building_geometry_clips()
	m_dragging_wall = null
	m_drag_wall_old_segments.clear()
	m_drag_wall_opening_anchors.clear()
	m_drag_wall_segment_index = 0
	m_drag_wall_endpoint = -1
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	m_drag_wall_resizing_room_side = false
	m_drag_wall_active_material = null


func _find_opening_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var hit := _raycast_world(camera, mouse_pos)
	var wall := _find_wall_from_collider(hit.get("collider"))
	if wall == null:
		return {}
	var hit_world := Vector3(hit["position"])
	for child in wall.get_children():
		if child.has_meta(Wall3DScript.GENERATED_META):
			continue
		var opening := child as BuildingOpening3DScript
		if opening == null or opening == m_prop_preview:
			continue
		var pick_radius := maxf(opening.opening_width, opening.opening_height) * 0.5 + 0.2
		if hit_world.distance_to(opening.global_position) > pick_radius:
			continue
		# Convert hit to opening's segment-local 2D space
		var seg_idx := wall.get_opening_segment_index(opening)
		var frame := wall.get_segment_local_frame(seg_idx)
		var local_hit := frame.affine_inverse() * wall.to_local(hit_world)
		var local_center := frame.affine_inverse() * opening.position
		var rel := Vector2(local_hit.x - local_center.x, local_hit.y - local_center.y)
		var half_w := opening.opening_width * 0.5
		var half_h := opening.opening_height * 0.5
		var edge_zone := minf(0.22, minf(half_w, half_h) * 0.4)
		# Center zone → move
		if absf(rel.x) < half_w - edge_zone and absf(rel.y) < half_h - edge_zone:
			return {"opening": opening, "edge": -1, "wall": wall}
		# Nearest edge
		var candidates := [
			[absf(rel.x + half_w), 0],  # left
			[absf(rel.x - half_w), 1],  # right
			[absf(rel.y + half_h), 2],  # bottom
			[absf(rel.y - half_h), 3],  # top
		]
		var best_edge := 0
		var best_d := INF
		for c in candidates:
			if float(c[0]) < best_d:
				best_d = float(c[0])
				best_edge = int(c[1])
		return {"opening": opening, "edge": best_edge, "wall": wall}
	return {}


func _update_hover_highlight(opening: BuildingOpening3DScript, edge: int) -> void:
	if opening == m_drag_hover_opening and edge == m_drag_hover_edge:
		return
	_clear_drag_hover()
	if opening == null:
		return
	m_drag_hover_opening = opening
	m_drag_hover_old_color = opening.frame_color
	m_drag_hover_edge = edge
	opening.frame_color = (
		Color(1.0, 0.85, 0.20, 0.9) if edge >= 0 else Color(0.20, 0.60, 1.0, 0.9)
	)


func _clear_drag_hover() -> void:
	if m_drag_hover_opening == null:
		return
	if is_instance_valid(m_drag_hover_opening):
		m_drag_hover_opening.frame_color = m_drag_hover_old_color
	m_drag_hover_opening = null
	m_drag_hover_edge = -1


func _start_window_drag(
	opening: BuildingOpening3DScript,
	edge: int,
	wall_hint: Wall3DScript
) -> void:
	_clear_prop_preview()
	m_dragging_opening = opening
	m_drag_old_position = opening.position
	m_drag_opening_old_width = opening.opening_width
	m_drag_opening_old_height = opening.opening_height
	m_drag_opening_old_frame_color = (
		m_drag_hover_old_color if opening == m_drag_hover_opening else opening.frame_color
	)
	m_drag_old_segment = int(opening.get_meta(Wall3DScript.SEGMENT_INDEX_META, 0))
	m_drag_target_segment = m_drag_old_segment
	m_drag_opening_edge = edge
	m_drag_valid = true
	var wall := opening.get_parent() as Wall3DScript
	if wall == null:
		wall = wall_hint
	if wall != null:
		var frame := wall.get_segment_local_frame(m_drag_target_segment)
		var local_pos := frame.affine_inverse() * opening.position
		m_drag_face_sign = signf(local_pos.z) if absf(local_pos.z) > 0.001 else 1.0
		m_drag_resize_center_2d = Vector2(local_pos.x, local_pos.y)
		m_drag_resize_anchor_2d = m_drag_resize_center_2d
	else:
		m_drag_face_sign = 1.0
	var color := Color(1.0, 0.85, 0.20, 0.9) if edge >= 0 else Color(0.20, 0.60, 1.0, 0.9)
	opening.frame_color = color
	var action := "edge" if edge >= 0 else "opening"
	_set_status("Dragging %s — release to commit, Escape to cancel." % action)


func _update_window_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_opening == null or !is_instance_valid(m_dragging_opening):
		m_dragging_opening = null
		return
	var wall := m_dragging_opening.get_parent() as Wall3DScript
	if wall == null:
		_cancel_window_drag()
		return
	var hit := _raycast_world(camera, mouse_pos)
	var hit_wall := _find_wall_from_collider(hit.get("collider"))
	if hit_wall != wall:
		m_dragging_opening.frame_color = Color(0.95, 0.20, 0.16, 0.9)
		m_drag_valid = false
		_set_status("Drag within the same wall.")
		return
	var hit_segment := clampi(int(hit.get("segment", m_drag_target_segment)), 0, wall.get_segment_count() - 1)
	if m_drag_opening_edge < 0:
		m_drag_target_segment = hit_segment
	var segment := wall.get_segment(m_drag_target_segment)
	var frame := wall.get_segment_local_frame(m_drag_target_segment)
	var local_hit := frame.affine_inverse() * wall.to_local(Vector3(hit["position"]))
	var grid_step := _active_grid_step(wall)

	if m_drag_opening_edge >= 0:
		# Resize mode: adjust width or height based on which edge is dragged
		var hit_2d := Vector2(local_hit.x, local_hit.y)
		var delta := hit_2d - m_drag_resize_anchor_2d
		var new_width := m_drag_opening_old_width
		var new_height := m_drag_opening_old_height
		match m_drag_opening_edge:
			0:  # left edge: moving left increases width
				new_width = maxf(roundf((m_drag_opening_old_width - 2.0 * delta.x) / grid_step) * grid_step, grid_step)
			1:  # right edge: moving right increases width
				new_width = maxf(roundf((m_drag_opening_old_width + 2.0 * delta.x) / grid_step) * grid_step, grid_step)
			2:  # bottom edge: moving down increases height
				new_height = maxf(roundf((m_drag_opening_old_height - 2.0 * delta.y) / grid_step) * grid_step, grid_step)
			3:  # top edge: moving up increases height
				new_height = maxf(roundf((m_drag_opening_old_height + 2.0 * delta.y) / grid_step) * grid_step, grid_step)
		m_dragging_opening.opening_width = new_width
		m_dragging_opening.opening_height = new_height
		# Keep center position fixed (sill constraint: re-apply to Y)
		var sill_height := _opening_sill_height(m_dragging_opening)
		var center_local := Vector3(
			m_drag_resize_center_2d.x,
			sill_height + new_height * 0.5,
			m_drag_face_sign * (segment.thickness * 0.5 + 0.035)
		)
		m_dragging_opening.transform = Transform3D(
			_opening_basis_for_face(frame.basis, m_drag_face_sign), frame * center_local
		)
		var center_2d := Vector2(center_local.x, center_local.y)
		var size := Vector2(new_width, new_height)
		m_drag_valid = _can_place_wall_opening(
			wall,
			m_drag_target_segment,
			center_2d,
			size,
			0.04,
			m_dragging_opening,
			_opening_allow_base_edge(m_dragging_opening)
		)
	else:
		# Move mode
		m_drag_face_sign = signf(local_hit.z) if absf(local_hit.z) > 0.001 else m_drag_face_sign
		local_hit.x = clampf(roundf(local_hit.x / grid_step) * grid_step, 0.0, segment.get_length())
		var sill_height := _opening_sill_height(m_dragging_opening)
		local_hit.y = sill_height + m_dragging_opening.opening_height * 0.5
		local_hit.z = m_drag_face_sign * (segment.thickness * 0.5 + 0.035)
		m_dragging_opening.transform = Transform3D(
			_opening_basis_for_face(frame.basis, m_drag_face_sign), frame * local_hit
		)
		var center := Vector2(local_hit.x, local_hit.y)
		var size := Vector2(m_dragging_opening.opening_width, m_dragging_opening.opening_height)
		m_drag_valid = _can_place_wall_opening(
			wall,
			m_drag_target_segment,
			center,
			size,
			0.04,
			m_dragging_opening,
			_opening_allow_base_edge(m_dragging_opening)
		)

	var ok_color := Color(1.0, 0.85, 0.20, 0.9) if m_drag_opening_edge >= 0 else Color(0.20, 0.60, 1.0, 0.9)
	m_dragging_opening.frame_color = ok_color if m_drag_valid else Color(0.95, 0.20, 0.16, 0.9)
	_set_status("Release to commit." if m_drag_valid else "Position overlaps or is out of bounds.")


func _commit_window_drag() -> void:
	if m_dragging_opening == null:
		return
	var wall := m_dragging_opening.get_parent() as Wall3DScript
	if wall == null or !m_drag_valid:
		_cancel_window_drag()
		if !m_drag_valid:
			_set_status("Cannot place opening there — canceled.")
		return
	var opening := m_dragging_opening
	var new_position := opening.position
	var new_width := opening.opening_width
	var new_height := opening.opening_height
	var old_position := m_drag_old_position
	var old_width := m_drag_opening_old_width
	var old_height := m_drag_opening_old_height
	var old_segment := m_drag_old_segment
	var target_segment := m_drag_target_segment
	m_dragging_opening = null
	var undo_redo := get_undo_redo()
	if m_drag_opening_edge >= 0:
		undo_redo.create_action("Resize Wall Opening")
		undo_redo.add_do_method(self, "_do_resize_opening", opening, new_position, new_width, new_height, wall)
		undo_redo.add_undo_method(self, "_do_resize_opening", opening, old_position, old_width, old_height, wall)
	else:
		undo_redo.create_action("Move Wall Opening")
		undo_redo.add_do_method(self, "_do_move_opening", opening, new_position, target_segment, wall)
		undo_redo.add_undo_method(self, "_do_move_opening", opening, old_position, old_segment, wall)
	undo_redo.commit_action()
	opening.frame_color = m_drag_opening_old_frame_color
	_set_status("Resized wall opening." if m_drag_opening_edge >= 0 else "Moved wall opening.")
	m_drag_opening_edge = -1


func _opening_sill_height(opening: BuildingOpening3DScript) -> float:
	if opening != null and opening.has_meta(OPENING_SILL_META):
		return maxf(float(opening.get_meta(OPENING_SILL_META)), 0.0)
	return 0.0 if m_tool_mode == MODE_DOOR else maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0)


func _opening_allow_base_edge(opening: BuildingOpening3DScript) -> bool:
	if opening != null and opening.has_meta(OPENING_ALLOW_BASE_META):
		return bool(opening.get_meta(OPENING_ALLOW_BASE_META))
	return m_tool_mode == MODE_DOOR


func _cancel_window_drag() -> void:
	if m_dragging_opening == null:
		return
	if is_instance_valid(m_dragging_opening):
		m_dragging_opening.position = m_drag_old_position
		m_dragging_opening.opening_width = m_drag_opening_old_width
		m_dragging_opening.opening_height = m_drag_opening_old_height
		m_dragging_opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, m_drag_old_segment)
		m_dragging_opening.frame_color = m_drag_opening_old_frame_color
		var wall := m_dragging_opening.get_parent() as Wall3DScript
		if wall != null:
			wall.rebuild_wall_mesh()
	m_dragging_opening = null
	m_drag_valid = false
	m_drag_opening_edge = -1


func _do_move_opening(
	opening: BuildingOpening3DScript,
	new_pos: Vector3,
	segment_index: int,
	wall: Wall3DScript
) -> void:
	opening.position = new_pos
	opening.set_meta(Wall3DScript.SEGMENT_INDEX_META, segment_index)
	wall.rebuild_wall_mesh()


func _do_resize_opening(
	opening: BuildingOpening3DScript,
	new_pos: Vector3,
	new_width: float,
	new_height: float,
	wall: Wall3DScript
) -> void:
	opening.position = new_pos
	opening.opening_width = new_width
	opening.opening_height = new_height
	wall.rebuild_wall_mesh()


func _attach_viewport_overlays() -> void:
	_clear_viewport_overlays()
	for index in range(4):
		var sub_viewport := EditorInterface.get_editor_viewport_3d(index)
		if sub_viewport == null:
			continue
		var viewport_control := sub_viewport.get_parent() as Control
		if viewport_control == null:
			continue
		var overlay := ViewportInputOverlayScript.new() as Control
		overlay.name = "LowPolyBuildingEditorInputOverlay%d" % index
		if overlay.has_method("setup"):
			overlay.setup(self)
		viewport_control.add_child(overlay)
		m_viewport_overlays.append(overlay)
		if overlay.has_method("set_active"):
			overlay.call("set_active", m_tool_mode != MODE_SELECT)


func _attach_input_capture() -> void:
	_clear_input_capture()
	m_input_capture = ViewportInputCaptureScript.new()
	m_input_capture.name = "LowPolyBuildingEditorInputCapture"
	if m_input_capture.has_method("setup"):
		m_input_capture.setup(self)
	get_tree().root.add_child(m_input_capture)


func _clear_input_capture() -> void:
	if m_input_capture != null and is_instance_valid(m_input_capture):
		m_input_capture.queue_free()
	m_input_capture = null


func _clear_viewport_overlays() -> void:
	for overlay in m_viewport_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	m_viewport_overlays.clear()


func _cancel_tool_controller_previews() -> void:
	for mode in m_tool_controllers:
		m_tool_controllers[mode].cancel_preview()


func _cancel_active_preview() -> void:
	_cancel_tool_controller_previews()
	_cancel_wall_drag()
	_clear_wall_hover()
	_cancel_floor_drag()
	_clear_floor_hover()
	_cancel_roof_drag()
	_clear_roof_hover()
	_cancel_window_drag()
	_clear_drag_hover()
	_clear_wall_preview()
	_clear_floor_preview()
	_clear_roof_preview()
	_clear_prop_preview()
	_reset_wall_drawing_state()
	_reset_floor_drawing_state()
	_reset_roof_drawing_state()
	_set_status("Tool preview canceled.")


func _is_wall_span_long_enough(local_start: Vector3, local_end: Vector3) -> bool:
	return local_start.distance_to(local_end) >= maxf(float(m_wall_settings["grid_step"]) * 0.5, 0.1)


func _is_wall_draw_valid(local_start: Vector3, local_end: Vector3) -> bool:
	if !_is_room_wall_mode():
		return _is_wall_span_long_enough(local_start, local_end)
	var minimum_size := maxf(float(m_wall_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _wall_tool_type() -> String:
	return str(m_wall_settings.get("type", WALL_TYPE_WALL))


func _is_room_wall_mode() -> bool:
	return _wall_tool_type() == WALL_TYPE_ROOM


func _room_side_count() -> int:
	return maxi(int(m_wall_settings.get("room_sides", 4)), 3)


func _wall_draw_label() -> String:
	return "Room" if _is_room_wall_mode() else "Wall"


func _is_floor_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_floor_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _is_valid_floor_polygon(points: PackedVector3Array) -> bool:
	if points.size() < 3:
		return false
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(Vector2(point.x, point.z))
	return !Geometry2D.triangulate_polygon(polygon).is_empty()


func _rectangle_floor_points(local_start: Vector3, local_end: Vector3) -> PackedVector3Array:
	var min_x := minf(local_start.x, local_end.x)
	var max_x := maxf(local_start.x, local_end.x)
	var min_z := minf(local_start.z, local_end.z)
	var max_z := maxf(local_start.z, local_end.z)
	var base_y := local_start.y
	return PackedVector3Array([
		Vector3(min_x, base_y, min_z),
		Vector3(max_x, base_y, min_z),
		Vector3(max_x, base_y, max_z),
		Vector3(min_x, base_y, max_z),
	])


func _get_floor_edit_points(floor: Floor3DScript) -> PackedVector3Array:
	if floor.is_polygon_floor():
		return floor.get_floor_polygon()
	return _rectangle_floor_points(floor.start_point, floor.end_point)


func _is_roof_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_roof_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _is_valid_roof_polygon(points: PackedVector3Array) -> bool:
	if points.size() < 3:
		return false
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(Vector2(point.x, point.z))
	return !Geometry2D.triangulate_polygon(polygon).is_empty()


func _roof_polygon_parent_bounds(points: PackedVector3Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := Vector2(points[0].x, points[0].z)
	var max_point := min_point
	for point in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.z)
	return Rect2(min_point, max_point - min_point)


func _flat_roof(roof: Roof3DScript) -> FlatRoof3DScript:
	return roof as FlatRoof3DScript


func _is_polygon_roof(roof: Roof3DScript) -> bool:
	var flat_roof := _flat_roof(roof)
	return flat_roof != null and flat_roof.is_polygon_roof()


func _get_roof_polygon(roof: Roof3DScript) -> PackedVector3Array:
	var flat_roof := _flat_roof(roof)
	return flat_roof.get_roof_polygon() if flat_roof != null else PackedVector3Array()


func _set_roof_polygon(roof: Roof3DScript, points: PackedVector3Array) -> void:
	var flat_roof := _flat_roof(roof)
	if flat_roof != null:
		flat_roof.set_roof_polygon(points)


func _roof_angle_degrees(roof: Roof3DScript) -> float:
	return BuildingFactoryScript.get_roof_angle_degrees(roof)


func _roof_hip_gable_height(roof: Roof3DScript) -> float:
	return BuildingFactoryScript.get_roof_hip_gable_height(roof)


func _set_roof_corners_rotation_angle_and_covers(
	roof: Roof3DScript,
	new_start: Vector3,
	new_end: Vector3,
	new_rotation: float,
	new_angle_degrees: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array]
) -> void:
	var parameters := BuildingFactoryScript.get_roof_style_parameters(roof)
	if parameters.has("angle_degrees"):
		parameters["angle_degrees"] = new_angle_degrees
	roof.set_roof_corners_rotation_parameters_and_covers(
		new_start,
		new_end,
		new_rotation,
		parameters,
		new_covered_rects,
		new_covered_polygons
	)


func _get_roof_edit_points(roof: Roof3DScript) -> PackedVector3Array:
	if _is_polygon_roof(roof):
		return _get_roof_polygon(roof)
	var size := roof.get_roof_size()
	var anchor := roof.get_roof_anchor_point()
	var basis := _roof_rotation_basis(roof.roof_rotation_degrees)
	return PackedVector3Array([
		anchor,
		anchor + basis * Vector3(size.x, 0.0, 0.0),
		anchor + basis * Vector3(size.x, 0.0, size.y),
		anchor + basis * Vector3(0.0, 0.0, size.y),
	])


func _do_add_node(parent: Node, node: Node, scene_root: Node, select_after_add: bool) -> void:
	m_context.do_add_node(parent, node, scene_root, select_after_add)


func _do_add_node_and_rebuild(parent: Node, node: Node, scene_root: Node, select_after_add: bool) -> void:
	m_context.do_add_node_and_rebuild(parent, node, scene_root, select_after_add)


func _do_add_node_and_refresh_wall_intersections(
	parent: Node,
	node: Node,
	scene_root: Node,
	select_after_add: bool,
	coordinator: Building3DScript
) -> void:
	m_context.do_add_node_and_refresh_wall_intersections(
		parent, node, scene_root, select_after_add, coordinator
	)


func _do_add_node_and_refresh_roofs(
	parent: Node,
	node: Node,
	scene_root: Node,
	select_after_add: bool,
	coordinator: Building3DScript
) -> void:
	m_context.do_add_node_and_refresh_roofs(
		parent, node, scene_root, select_after_add, coordinator
	)


func _undo_remove_node(parent: Node, node: Node) -> void:
	m_context.undo_remove_node(parent, node)


func _undo_remove_node_and_rebuild(parent: Node, node: Node) -> void:
	m_context.undo_remove_node_and_rebuild(parent, node)


func _undo_remove_node_and_refresh_wall_intersections(
	parent: Node,
	node: Node,
	coordinator: Building3DScript
) -> void:
	m_context.undo_remove_node_and_refresh_wall_intersections(
		parent, node, coordinator
	)


func _undo_remove_node_and_refresh_roofs(parent: Node, node: Node, coordinator: Building3DScript) -> void:
	m_context.undo_remove_node_and_refresh_roofs(parent, node, coordinator)


func _set_roof_state_and_refresh(
	roof: Roof3DScript,
	new_start: Vector3,
	new_end: Vector3,
	new_rotation: float,
	new_height: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array],
	coordinator: Building3DScript
) -> void:
	if roof == null or !is_instance_valid(roof):
		return
	_set_roof_corners_rotation_angle_and_covers(
		roof,
		new_start,
		new_end,
		new_rotation,
		new_height,
		new_covered_rects,
		new_covered_polygons
	)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_building_geometry_clips()


func _roof_layout_would_hide_any_roof(
	coordinator: Building3DScript,
	roof: Roof3DScript,
	new_start: Vector3,
	new_end: Vector3,
	new_rotation: float,
	new_height: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array]
) -> bool:
	if coordinator == null or !is_instance_valid(coordinator):
		return false
	if roof == null or !is_instance_valid(roof):
		return false

	var snapshots: Array[Dictionary] = []
	for roof_node in coordinator.get_roof_nodes():
		snapshots.append({
			"roof": roof_node,
			"start": roof_node.start_point,
			"end": roof_node.end_point,
			"polygon": _get_roof_polygon(roof_node),
			"rotation": roof_node.roof_rotation_degrees,
			"height": _roof_angle_degrees(roof_node),
			"covered_rects": roof_node.get_covered_rects(),
			"covered_polygons": roof_node.get_covered_polygons(),
		})

	_set_roof_corners_rotation_angle_and_covers(
		roof,
		new_start,
		new_end,
		new_rotation,
		new_height,
		new_covered_rects,
		new_covered_polygons
	)
	coordinator.refresh_roof_covered_rects()
	var hides_roof := false
	for roof_node in coordinator.get_roof_nodes():
		if roof_node.has_meta(Roof3DScript.PREVIEW_META):
			continue
		if !roof_node.has_visible_roof_geometry():
			hides_roof = true
			break

	for snapshot in snapshots:
		var snapshot_roof := snapshot["roof"] as Roof3DScript
		if snapshot_roof == null or !is_instance_valid(snapshot_roof):
			continue
		var snapshot_covers: Array[Rect2] = []
		for rect in snapshot.get("covered_rects", []):
			snapshot_covers.append(rect)
		var snapshot_polygons: Array[PackedVector2Array] = []
		for polygon in snapshot.get("covered_polygons", []):
			snapshot_polygons.append(PackedVector2Array(polygon))
		var snapshot_polygon := PackedVector3Array(snapshot.get("polygon", PackedVector3Array()))
		if !snapshot_polygon.is_empty():
			_set_roof_polygon(snapshot_roof, snapshot_polygon)
			snapshot_roof.set_covered_regions(snapshot_covers, snapshot_polygons)
		else:
			_set_roof_corners_rotation_angle_and_covers(
				snapshot_roof,
				Vector3(snapshot["start"]),
				Vector3(snapshot["end"]),
				float(snapshot["rotation"]),
				float(snapshot["height"]),
				snapshot_covers,
				snapshot_polygons
			)
	return hides_roof


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	m_context.set_owner_recursive(node, scene_root)


func _select_node(node: Node) -> void:
	m_context.select_node(node)


func _connect_editor_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	if !selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.connect(_on_editor_selection_changed)


func _disconnect_editor_selection() -> void:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return
	if selection.selection_changed.is_connected(_on_editor_selection_changed):
		selection.selection_changed.disconnect(_on_editor_selection_changed)


func _tool_mode_for_selected_building_node() -> String:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return ""
	for node in selection.get_selected_nodes():
		var mode := _tool_mode_for_building_node(node)
		if !mode.is_empty():
			return mode
	return ""


func _tool_mode_for_building_node(node: Node) -> String:
	if node == null:
		return ""
	if node is Wall3DScript:
		return MODE_WALL
	if node is Floor3DScript:
		return MODE_FLOOR
	if node is Stairs3DScript:
		return MODE_STAIRS
	if node is Rail3DScript:
		return MODE_RAIL
	if node is Pillar3DScript:
		return MODE_PILLAR
	if node is Roof3DScript:
		return MODE_ROOF
	if node is BuildingOpening3DScript:
		return _tool_mode_for_opening_node(node as BuildingOpening3DScript)
	if node.has_meta(BUILDING_PROP_META):
		return MODE_PROP
	return ""


func _tool_mode_for_opening_node(opening: BuildingOpening3DScript) -> String:
	if opening == null:
		return ""
	if opening is Door3DScript:
		return MODE_DOOR
	if opening is Window3DScript:
		return MODE_WINDOW
	return ""


func _build_viewport_toolbar() -> void:
	m_native_toolbar.build_viewport_toolbar()


func _clear_viewport_toolbar() -> void:
	if m_native_toolbar != null:
		m_native_toolbar.clear_viewport_toolbar()


func _input(event: InputEvent) -> void:
	if m_native_toolbar != null:
		m_native_toolbar.handle_editor_input(event)


func _select_tool_mode(mode: String) -> void:
	m_native_toolbar.select_tool_mode(mode)


func _sync_toolbar_tool_mode(mode: String) -> void:
	m_native_toolbar.sync_toolbar_tool_mode(mode)


func _get_editor_icon(icon_name: StringName, fallback_to_node_3d := true) -> Texture2D:
	return m_native_toolbar.get_editor_icon(icon_name, fallback_to_node_3d)


func _handled() -> int:
	return m_context.handled()


func _set_status(text: String) -> void:
	m_context.set_status(text)


func _refresh_dock_context() -> void:
	if m_dock == null or !m_dock.has_method("set_active_coordinator_path"):
		return
	var coordinator := _get_or_create_coordinator(false)
	if coordinator == null:
		m_dock.set_active_coordinator_path("")
	else:
		m_dock.set_active_coordinator_path(str(coordinator.get_path()))


func _on_tool_mode_changed(mode: String) -> void:
	m_tool_mode = mode
	_sync_toolbar_tool_mode(mode)
	_sync_viewport_overlay_state()
	_cancel_active_preview()
	if m_tool_mode != MODE_SELECT:
		_activate_3d_editor_context()
	_set_status("Select a tool." if mode == MODE_SELECT else "Active tool: %s" % mode.capitalize())


func _on_display_settings_changed(settings: Dictionary) -> void:
	m_display_settings = settings.duplicate(true)
	_apply_debug_wireframe_to_scene()


func _apply_debug_wireframe_to_scene() -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root != null:
		_apply_debug_wireframe_recursive(scene_root)


func _apply_debug_wireframe_to_node(node: Node) -> void:
	if node == null or !is_instance_valid(node):
		return
	var enabled := bool(m_display_settings.get("wireframe", false))
	var color := Color(
		m_display_settings.get(
			"wireframe_color",
			Color(0.05, 0.95, 1.0, 1.0)
		)
	)
	var xray := bool(m_display_settings.get("wireframe_xray", false))
	if node.has_method("set_debug_wireframe"):
		node.call("set_debug_wireframe", enabled, color, xray)
	elif node is Node3D and node.has_meta(BUILDING_PROP_META):
		var prop_root := node as Node3D
		if (
			!enabled
			or !BuildingWireframeScript.update_style(prop_root, color, xray)
		):
			BuildingWireframeScript.sync_recursive(prop_root, enabled, color, xray)


func _apply_debug_wireframe_recursive(node: Node) -> void:
	if node == null or node.has_meta(BuildingWireframeScript.GENERATED_META):
		return
	_apply_debug_wireframe_to_node(node)
	if node.has_meta(BUILDING_PROP_META):
		return
	for child in node.get_children():
		_apply_debug_wireframe_recursive(child)


func _sync_viewport_overlay_state() -> void:
	var active := m_tool_mode != MODE_SELECT
	for overlay in m_viewport_overlays:
		if is_instance_valid(overlay) and overlay.has_method("set_active"):
			overlay.call("set_active", active)


func _on_wall_settings_changed(settings: Dictionary) -> void:
	var previous_type := _wall_tool_type()
	m_wall_settings = settings.duplicate(true)
	if _wall_tool_type() != previous_type:
		_clear_wall_preview()
		_reset_wall_drawing_state()


func _on_floor_settings_changed(settings: Dictionary) -> void:
	m_floor_settings = settings.duplicate(true)
	_clear_floor_preview()
	_reset_floor_drawing_state()


func _on_stair_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_STAIRS].apply_settings(settings)


func _on_rail_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_RAIL].apply_settings(settings)


func _on_pillar_settings_changed(settings: Dictionary) -> void:
	m_tool_controllers[MODE_PILLAR].apply_settings(settings)


func _on_roof_settings_changed(settings: Dictionary) -> void:
	m_roof_settings = settings.duplicate(true)
	_clear_roof_preview()


func _on_prop_settings_changed(settings: Dictionary) -> void:
	m_prop_settings = settings.duplicate(true)
	_clear_prop_preview()


func _on_window_settings_changed(settings: Dictionary) -> void:
	m_window_settings = settings.duplicate(true)


func _on_door_settings_changed(settings: Dictionary) -> void:
	m_door_settings = settings.duplicate(true)
	_clear_prop_preview()


func _on_create_coordinator_requested() -> void:
	_cancel_active_preview()
	var coordinator := _create_coordinator()
	if coordinator != null:
		_set_status("%s ready." % coordinator.name)


func _on_scene_changed(_scene_root: Node) -> void:
	m_active_coordinator = null
	_cancel_active_preview()
	_refresh_dock_context()
	_apply_debug_wireframe_to_scene()


func _on_editor_selection_changed() -> void:
	var selected_coordinator := _find_selected_coordinator()
	if selected_coordinator != null and selected_coordinator != m_active_coordinator:
		_cancel_active_preview()
		m_active_coordinator = selected_coordinator
	_refresh_dock_context()
	var selected_tool_mode := _tool_mode_for_selected_building_node()
	if selected_tool_mode.is_empty() or selected_tool_mode == m_tool_mode:
		return
	_select_tool_mode(selected_tool_mode)


func _activate_3d_editor_context() -> void:
	EditorInterface.set_main_screen_editor("3D")
	var selection := get_editor_interface().get_selection()
	for node in selection.get_selected_nodes():
		if node is Node3D:
			return
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root is Node3D:
		selection.clear()
		selection.add_node(scene_root)
