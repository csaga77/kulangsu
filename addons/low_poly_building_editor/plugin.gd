@tool
extends EditorPlugin

const _DOCK_SLOT := EditorDock.DOCK_SLOT_RIGHT_UL
const MODE_SELECT := "select"
const MODE_WALL := "wall"
const MODE_FLOOR := "floor"
const MODE_STAIRS := "stairs"
const MODE_PILLAR := "pillar"
const MODE_ROOF := "roof"
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const MODE_DOOR := "door"
const BuildingEditor3DScript = preload("res://addons/low_poly_building_editor/building_editor_3d.gd")
const Wall3DScript = preload("res://addons/low_poly_building_editor/wall_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floor_3d.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roof_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/building_opening_3d.gd")
const WallSegment3DScript = preload("res://addons/low_poly_building_editor/wall_segment_3d.gd")
const DockScript = preload("res://addons/low_poly_building_editor/low_poly_building_editor_dock.gd")
const ViewportInputOverlayScript = preload("res://addons/low_poly_building_editor/viewport_input_overlay.gd")
const ViewportInputCaptureScript = preload("res://addons/low_poly_building_editor/viewport_input_capture.gd")
const WALL_DRAG_COMMIT_DISTANCE := 6.0
const FLOOR_EDIT_MOVE := 0
const FLOOR_EDIT_MIN_X := 1
const FLOOR_EDIT_MAX_X := 2
const FLOOR_EDIT_MIN_Z := 4
const FLOOR_EDIT_MAX_Z := 8
const WALL_TYPE_WALL := "wall"
const WALL_TYPE_ROOM := "room"
const FLOOR_TYPE_SOLID := "solid"
const FLOOR_TYPE_HOLE := "hole"
const PILLAR_EDIT_MOVE := 0
const PILLAR_EDIT_RADIUS := 1
const OPENING_SILL_META := &"building_opening_sill_height"
const OPENING_ALLOW_BASE_META := &"building_opening_allow_base_edge"
# Temporary diagnostic: writes the 3D toolbar tree to native_buttons_debug.log
# when enabled.
const DEBUG_NATIVE_BUTTONS := false
const NATIVE_ICON_SELECT := &"ToolSelect"
const NATIVE_ICON_TRANSFORM := &"Transform"
const NATIVE_ICON_TRANSFORM_ALTERNATE := &"ToolTriangle"
const NATIVE_ICON_MOVE := &"ToolMove"
const NATIVE_ICON_ROTATE := &"ToolRotate"
const NATIVE_ICON_SCALE := &"ToolScale"
const NATIVE_MODE_TRANSFORM := &"transform"
const NATIVE_MODE_MOVE := &"move"
const NATIVE_MODE_ROTATE := &"rotate"
const NATIVE_MODE_SCALE := &"scale"
const NATIVE_MODE_SELECT := &"select"
const NATIVE_SHORTCUT_TRANSFORM := KEY_Q
const NATIVE_SHORTCUT_MOVE := KEY_W
const NATIVE_SHORTCUT_ROTATE := KEY_E
const NATIVE_SHORTCUT_SCALE := KEY_R
const NATIVE_SHORTCUT_SELECT := KEY_V
const NATIVE_TIPS_SELECT := ["select mode", "select tool"]
const NATIVE_TIPS_TRANSFORM := ["transform mode", "transform"]
const NATIVE_TIPS_MOVE := ["move mode", "move"]
const NATIVE_TIPS_ROTATE := ["rotate mode", "rotate"]
const NATIVE_TIPS_SCALE := ["scale mode", "scale"]
const TOOLBAR_BUTTON_MINIMUM_SIZE := Vector2(32.0, 32.0)
const TOOLBAR_FALLBACK_ICON_SIZE := Vector2i(24, 24)
const BUTTON_STYLEBOX_THEME_ITEMS := [
	&"normal",
	&"hover",
	&"pressed",
	&"disabled",
	&"focus",
	&"hover_pressed",
]
const BUTTON_COLOR_THEME_ITEMS := [
	&"font_color",
	&"font_hover_color",
	&"font_pressed_color",
	&"font_disabled_color",
	&"font_focus_color",
	&"font_hover_pressed_color",
	&"font_outline_color",
	&"icon_normal_color",
	&"icon_hover_color",
	&"icon_pressed_color",
	&"icon_disabled_color",
	&"icon_focus_color",
	&"icon_hover_pressed_color",
]
const BUTTON_CONSTANT_THEME_ITEMS := [
	&"h_separation",
	&"icon_max_width",
	&"outline_size",
]
const BUTTON_FONT_THEME_ITEMS := [
	&"font",
]
const BUTTON_FONT_SIZE_THEME_ITEMS := [
	&"font_size",
]

# The native 3D viewport Select mode is the "no building tool" state, so the
# toolbar only exposes the building tools and stays mutually exclusive with the
# native Transform/Move/Rotate/Scale/Select buttons.
const TOOLBAR_TOOLS := [
	{
		"mode": MODE_WALL,
		"label": "Wall",
		"tooltip": "Draw grid-snapped walls.",
		"generated_icon": true,
	},
	{
		"mode": MODE_FLOOR,
		"label": "Floor",
		"tooltip": "Draw rectangular floor slabs.",
		"generated_icon": true,
	},
	{
		"mode": MODE_STAIRS,
		"label": "Stairs",
		"tooltip": "Draw stepped stair blocks.",
		"generated_icon": true,
	},
	{
		"mode": MODE_PILLAR,
		"label": "Pillar",
		"tooltip": "Place low-poly pillars.",
		"generated_icon": true,
	},
	{
		"mode": MODE_ROOF,
		"label": "Roof",
		"tooltip": "Draw low-poly roofs.",
		"generated_icon": true,
	},
	{
		"mode": MODE_DOOR,
		"label": "Door",
		"tooltip": "Cut door openings.",
		"generated_icon": true,
	},
	{
		"mode": MODE_WINDOW,
		"label": "Window",
		"tooltip": "Cut window openings.",
		"generated_icon": true,
	},
	{
		"mode": MODE_PROP,
		"label": "Prop",
		"tooltip": "Place prop scenes.",
		"generated_icon": true,
	},
]

var m_dock: Control
var m_editor_dock: EditorDock
var m_input_capture: Node
var m_viewport_overlays: Array[Control] = []
var m_viewport_toolbar: HBoxContainer
var m_toolbar_buttons := {}
var m_toolbar_icon_cache := {}
var m_toolbar_icon_size := TOOLBAR_FALLBACK_ICON_SIZE
var m_native_tool_buttons: Array[Button] = []
var m_native_select_button: Button
var m_native_active_button: Button
var m_handling_native_click := false
var m_tool_mode := MODE_SELECT
var m_wall_settings := {
	"grid_step": 0.5,
	"type": WALL_TYPE_WALL,
	"base_height": 0.0,
	"height": 2.4,
	"thickness": 0.22,
	"color": Color(0.78, 0.68, 0.54, 1.0),
	"lock_8_way": true,
}
var m_floor_settings := {
	"grid_step": 0.5,
	"type": FLOOR_TYPE_SOLID,
	"base_height": 0.0,
	"thickness": 0.12,
	"color": Color(0.46, 0.40, 0.32, 1.0),
}
var m_stair_settings := {
	"grid_step": 0.5,
	"base_height": 0.0,
	"height": 1.2,
	"step_count": 6,
	"thickness": 0.12,
	"rotation_degrees": 0.0,
	"color": Color(0.52, 0.46, 0.38, 1.0),
}
var m_pillar_settings := {
	"grid_step": 0.5,
	"style": "round",
	"base_height": 0.0,
	"radius": 0.25,
	"upper_radius": 0.0,
	"height": 2.4,
	"sides": 8,
	"lower_rim_height": 0.12,
	"lower_rim_outset": 0.05,
	"upper_rim_height": 0.12,
	"upper_rim_outset": 0.05,
	"color": Color(0.70, 0.64, 0.52, 1.0),
}
var m_roof_settings := {
	"grid_step": 0.5,
	"style": "gable",
	"base_height": 2.4,
	"height": 40.0,
	"thickness": 0.12,
	"overhang": 0.2,
	"hip_gable_height": 0.0,
	"rotation_degrees": 0.0,
	"color": Color(0.50, 0.34, 0.25, 1.0),
	"debug_wireframe": false,
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
}
var m_door_settings := {
	"style": "single_door",
	"width": 0.9,
	"height": 2.1,
	"frame_thickness": 0.08,
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
var m_dragging_floor: Floor3DScript
var m_drag_floor_old_start := Vector3.ZERO
var m_drag_floor_old_end := Vector3.ZERO
var m_drag_floor_anchor_local := Vector3.ZERO
var m_drag_floor_edit_mask := FLOOR_EDIT_MOVE
var m_drag_floor_active_material: Material
var m_drag_floor_hover: Floor3DScript
var m_drag_floor_hover_material: Material
var m_drag_floor_hover_edit_mask := FLOOR_EDIT_MOVE
var m_stair_start_local := Vector3.ZERO
var m_stair_end_local := Vector3.ZERO
var m_stair_start_screen_position := Vector2.ZERO
var m_stair_has_valid_preview := false
var m_stair_release_commits_preview := false
var m_stair_draw_rotation_degrees := 0.0
var m_is_drawing_stair := false
var m_stair_preview: Stairs3DScript
var m_dragging_stair: Stairs3DScript
var m_drag_stair_old_start := Vector3.ZERO
var m_drag_stair_old_end := Vector3.ZERO
var m_drag_stair_old_rotation_degrees := 0.0
var m_drag_stair_anchor_local := Vector3.ZERO
var m_drag_stair_plane_y := 0.0
var m_drag_stair_edit_mask := FLOOR_EDIT_MOVE
var m_drag_stair_active_material: Material
var m_drag_stair_hover: Stairs3DScript
var m_drag_stair_hover_material: Material
var m_drag_stair_hover_edit_mask := FLOOR_EDIT_MOVE
var m_pillar_preview: Pillar3DScript
var m_pillar_preview_valid := false
var m_dragging_pillar: Pillar3DScript
var m_drag_pillar_old_base := Vector3.ZERO
var m_drag_pillar_old_radius := 0.0
var m_drag_pillar_old_upper_radius := 0.0
var m_drag_pillar_anchor_local := Vector3.ZERO
var m_drag_pillar_edit_mode := PILLAR_EDIT_MOVE
var m_drag_pillar_active_material: Material
var m_drag_pillar_hover: Pillar3DScript
var m_drag_pillar_hover_material: Material
var m_drag_pillar_hover_edit_mode := PILLAR_EDIT_MOVE
var m_roof_start_local := Vector3.ZERO
var m_roof_end_local := Vector3.ZERO
var m_roof_start_screen_position := Vector2.ZERO
var m_roof_has_valid_preview := false
var m_roof_release_commits_preview := false
var m_roof_draw_rotation_degrees := 0.0
var m_is_drawing_roof := false
var m_roof_preview: Roof3DScript
var m_dragging_roof: Roof3DScript
var m_drag_roof_old_start := Vector3.ZERO
var m_drag_roof_old_end := Vector3.ZERO
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
var m_drag_wall_old_segments: Array[WallSegment3DScript] = []
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
var m_drag_resize_anchor_2d := Vector2.ZERO
var m_drag_resize_center_2d := Vector2.ZERO
var m_drag_hover_opening: BuildingOpening3DScript
var m_drag_hover_old_color: Color
var m_drag_hover_edge := -1


func _enter_tree() -> void:
	add_custom_type(
		"BuildingEditor3D",
		"Node3D",
		BuildingEditor3DScript,
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
		"Stairs3D",
		"MeshInstance3D",
		Stairs3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"Pillar3D",
		"MeshInstance3D",
		Pillar3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"Roof3D",
		"MeshInstance3D",
		Roof3DScript,
		_get_editor_icon(&"MeshInstance3D")
	)
	add_custom_type(
		"BuildingOpening3D",
		"Node3D",
		BuildingOpening3DScript,
		_get_editor_icon(&"Window")
	)
	set_input_event_forwarding_always_enabled()

	m_dock = DockScript.new() as Control
	m_dock.name = "Building Editor"
	if m_dock.has_method("setup"):
		m_dock.setup(get_editor_interface())
	m_dock.connect("tool_mode_changed", Callable(self, "_on_tool_mode_changed"))
	m_dock.connect("wall_settings_changed", Callable(self, "_on_wall_settings_changed"))
	m_dock.connect("floor_settings_changed", Callable(self, "_on_floor_settings_changed"))
	m_dock.connect("stair_settings_changed", Callable(self, "_on_stair_settings_changed"))
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
	_cancel_floor_drag()
	_clear_floor_hover()
	_cancel_stair_drag()
	_clear_stair_hover()
	_cancel_pillar_drag()
	_clear_pillar_hover()
	_cancel_roof_drag()
	_clear_roof_hover()
	_clear_wall_preview()
	_clear_floor_preview()
	_clear_stair_preview()
	_clear_pillar_preview()
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
	remove_custom_type("BuildingOpening3D")
	remove_custom_type("Roof3D")
	remove_custom_type("Pillar3D")
	remove_custom_type("Stairs3D")
	remove_custom_type("Floor3D")
	remove_custom_type("Wall3D")
	remove_custom_type("BuildingEditor3D")


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
			if key_event.keycode == KEY_R and m_tool_mode == MODE_STAIRS:
				return _handle_stair_rotation_key(key_event)
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

	if m_tool_mode == MODE_WALL:
		return _handle_wall_input(camera, event)
	if m_tool_mode == MODE_FLOOR:
		return _handle_floor_input(camera, event)
	if m_tool_mode == MODE_STAIRS:
		return _handle_stair_input(camera, event)
	if m_tool_mode == MODE_PILLAR:
		return _handle_pillar_input(camera, event)
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


func _create_wall_preview(coordinator: BuildingEditor3DScript) -> void:
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


func _update_wall_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_wall_preview == null:
		return
	var coordinator := m_wall_preview.get_parent() as BuildingEditor3DScript
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
	var segments := BuildingEditor3DScript.room_segments_from_corners(
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		float(m_wall_settings["thickness"]),
		m_wall_preview.wall_color
	)
	var extras: Array[WallSegment3DScript] = []
	for index in range(1, segments.size()):
		extras.append(segments[index])
	m_wall_preview.set_wall_geometry(segments[0].start_point, segments[0].end_point, extras)


func _resolve_wall_end_from_mouse(
	coordinator: BuildingEditor3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var local_position := _wall_draw_local_from_mouse(coordinator, camera, mouse_position)
	return _constrain_wall_end_on_base(coordinator, m_wall_start_local, local_position)


func _wall_base_height() -> float:
	return float(m_wall_settings.get("base_height", 0.0))


func _wall_draw_local_from_mouse(
	coordinator: BuildingEditor3DScript,
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
	coordinator: BuildingEditor3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := coordinator.snap_local_position(local_position)
	snapped.y = base_y
	return snapped


func _constrain_wall_end_on_base(
	coordinator: BuildingEditor3DScript,
	start_local: Vector3,
	target_local: Vector3
) -> Vector3:
	if _is_room_wall_mode():
		return Vector3(target_local.x, start_local.y, target_local.z)
	var constrained := coordinator.constrain_wall_end(start_local, target_local)
	constrained.y = start_local.y
	return constrained


func _get_active_wall_coordinator() -> BuildingEditor3DScript:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		var preview_parent := m_wall_preview.get_parent() as BuildingEditor3DScript
		if preview_parent != null:
			return preview_parent
	return _get_or_create_coordinator(false)


func _commit_wall(coordinator: BuildingEditor3DScript, local_start: Vector3, local_end: Vector3) -> void:
	if !_is_wall_draw_valid(local_start, local_end):
		_set_status("Room is too small." if _is_room_wall_mode() else "Wall is too short.")
		return

	_apply_wall_settings_to_coordinator(coordinator)
	var thickness := float(m_wall_settings["thickness"])
	if _is_room_wall_mode():
		_commit_room(coordinator, local_start, local_end, thickness)
		return
	var merge := coordinator.find_merge_target(
		local_start,
		local_end,
		thickness,
		float(m_wall_settings["height"]),
		m_wall_preview
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
	if coordinator.merge_intersecting:
		var targets := coordinator.find_intersecting_walls(local_start, local_end, thickness, m_wall_preview)
		if !targets.is_empty():
			intersects_existing_wall = true

	var wall := coordinator.create_wall_node(
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
	coordinator: BuildingEditor3DScript,
	local_start: Vector3,
	local_end: Vector3,
	thickness: float
) -> void:
	var wall := coordinator.create_room_node(
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		thickness,
		Color(m_wall_settings["color"])
	)
	var intersects_existing_wall := false
	if coordinator.merge_intersecting:
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

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_floor:
			_update_floor_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_floor_start_screen_position) >= WALL_DRAG_COMMIT_DISTANCE:
				m_floor_release_commits_preview = true
			return _handled()
		var floor_pick := _find_floor_pick(camera, mouse_motion.position)
		var hover_floor := floor_pick.get("floor") as Floor3DScript
		var edit_mask := int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_floor_hover(hover_floor, edit_mask)
		if hover_floor != null:
			if _is_floor_hole_mode():
				_set_status("Drag to draw a floor hole inside the highlighted floor.")
			else:
				_set_status(
					"Drag floor corner to resize." if _floor_edit_mask_is_corner(edit_mask)
					else "Drag floor edge to resize." if edit_mask != FLOOR_EDIT_MOVE
					else "Drag floor body to move."
				)
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
		var floor_pick := _find_floor_pick(camera, mouse_button.position)
		var hit_floor := floor_pick.get("floor") as Floor3DScript
		if hit_floor != null:
			_clear_floor_hover()
			_start_floor_drag(hit_floor, camera, mouse_button.position, int(floor_pick.get("edit_mask", FLOOR_EDIT_MOVE)))
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing floors.")
		return _handled()
	_apply_floor_settings_to_coordinator(coordinator)

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


func _create_floor_preview(coordinator: BuildingEditor3DScript) -> void:
	_clear_floor_preview()
	_apply_floor_settings_to_coordinator(coordinator)
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


func _update_floor_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_floor_preview == null:
		return
	var coordinator := m_floor_preview.get_parent() as BuildingEditor3DScript
	if coordinator == null:
		return
	var local_end := _floor_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_floor_end_local = local_end
	m_floor_has_valid_preview = _is_floor_span_large_enough(m_floor_start_local, local_end)
	m_floor_preview.set_floor_corners(m_floor_start_local, local_end)
	if m_floor_has_valid_preview:
		var size := m_floor_preview.get_floor_size()
		if _is_floor_hole_mode():
			var target_floor := _find_floor_for_hole(coordinator, m_floor_start_local, local_end)
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


func _is_floor_hole_mode() -> bool:
	return _floor_tool_type() == FLOOR_TYPE_HOLE


func _floor_draw_local_from_mouse(
	coordinator: BuildingEditor3DScript,
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
	coordinator: BuildingEditor3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := coordinator.snap_local_position(local_position)
	snapped.y = base_y
	return snapped


func _get_active_floor_coordinator() -> BuildingEditor3DScript:
	if m_floor_preview != null and is_instance_valid(m_floor_preview):
		var preview_parent := m_floor_preview.get_parent() as BuildingEditor3DScript
		if preview_parent != null:
			return preview_parent
	return _get_or_create_coordinator(false)


func _commit_floor(coordinator: BuildingEditor3DScript, local_start: Vector3, local_end: Vector3) -> void:
	if !_is_floor_span_large_enough(local_start, local_end):
		_set_status("Floor is too small.")
		return
	if _is_floor_hole_mode():
		_commit_floor_hole(coordinator, local_start, local_end)
		return

	_apply_floor_settings_to_coordinator(coordinator)
	var floor := coordinator.create_floor_node(
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
	coordinator: BuildingEditor3DScript,
	local_start: Vector3,
	local_end: Vector3
) -> void:
	var target_floor := _find_floor_for_hole(coordinator, local_start, local_end)
	if target_floor == null:
		_set_status("Draw the hole fully inside one existing floor.")
		return

	var hole_rect := target_floor.get_floor_hole_rect_from_parent_corners(local_start, local_end)
	if !target_floor.can_add_floor_hole_rect(hole_rect):
		_set_status("Floor hole must stay fully inside the floor.")
		return

	var old_holes := target_floor.get_floor_holes()
	var intersects_existing_hole := target_floor.floor_hole_rect_intersects_existing(hole_rect)
	var new_holes := target_floor.get_floor_holes_merged_with_rect(hole_rect)
	if _floor_hole_arrays_match(old_holes, new_holes):
		_set_status("Floor hole already covers that area.")
		return

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Floor Hole")
	undo_redo.add_do_method(target_floor, "set_floor_holes", new_holes)
	undo_redo.add_do_method(self, "_select_node", target_floor)
	undo_redo.add_undo_method(target_floor, "set_floor_holes", old_holes)
	undo_redo.add_undo_method(self, "_select_node", target_floor)
	undo_redo.commit_action()
	var hole_size := hole_rect.size
	if intersects_existing_hole:
		_set_status("Merged floor hole: %.2f x %.2f units." % [hole_size.x, hole_size.y])
	else:
		_set_status("Cut floor hole: %.2f x %.2f units." % [hole_size.x, hole_size.y])


func _find_floor_for_hole(
	coordinator: BuildingEditor3DScript,
	local_start: Vector3,
	local_end: Vector3
) -> Floor3DScript:
	if coordinator == null:
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
		if absf(floor.start_point.y - local_start.y) > height_tolerance:
			continue
		var hole_rect := floor.get_floor_hole_rect_from_parent_corners(local_start, local_end)
		if !floor.can_add_floor_hole_rect(hole_rect):
			continue
		var floor_size := floor.get_floor_size()
		var floor_area := floor_size.x * floor_size.y
		if best_floor == null or floor_area < best_area:
			best_floor = floor
			best_area = floor_area
	return best_floor


func _floor_hole_arrays_match(a: Array[Rect2], b: Array[Rect2]) -> bool:
	if a.size() != b.size():
		return false
	for index in range(a.size()):
		if a[index].position.distance_to(b[index].position) > 0.001:
			return false
		if a[index].size.distance_to(b[index].size) > 0.001:
			return false
	return true


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
	edit_mask: int
) -> void:
	m_dragging_floor = floor
	m_drag_floor_old_start = floor.start_point
	m_drag_floor_old_end = floor.end_point
	m_drag_floor_edit_mask = edit_mask
	m_drag_floor_active_material = floor.material_override
	m_drag_floor_anchor_local = _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	floor.material_override = _build_preview_material(_floor_drag_color(edit_mask, true))
	_select_node(floor)
	_set_status("Dragging floor %s - release to commit, Escape to cancel." % _floor_edit_label(edit_mask))


func _update_floor_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_floor == null or !is_instance_valid(m_dragging_floor):
		_reset_floor_drag_state()
		return
	var floor := m_dragging_floor
	var hit_local := _floor_plane_local_from_mouse(floor, camera, mouse_pos)
	var new_start := m_drag_floor_old_start
	var new_end := m_drag_floor_old_end
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


func _commit_floor_drag() -> void:
	if m_dragging_floor == null:
		return
	var floor := m_dragging_floor
	var old_start := m_drag_floor_old_start
	var old_end := m_drag_floor_old_end
	var new_start := floor.start_point
	var new_end := floor.end_point
	var edit_mask := m_drag_floor_edit_mask
	floor.material_override = m_drag_floor_active_material
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
		m_dragging_floor.set_floor_corners(m_drag_floor_old_start, m_drag_floor_old_end)
		m_dragging_floor.material_override = m_drag_floor_active_material
	_reset_floor_drag_state()
	_set_status("Floor edit canceled.")


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


func _active_floor_grid_step(floor: Floor3DScript) -> float:
	var coordinator := _find_coordinator_from_node(floor)
	if coordinator != null:
		return maxf(coordinator.grid_step, 0.05)
	return maxf(float(m_floor_settings["grid_step"]), 0.05)


func _reset_floor_drag_state() -> void:
	m_dragging_floor = null
	m_drag_floor_old_start = Vector3.ZERO
	m_drag_floor_old_end = Vector3.ZERO
	m_drag_floor_anchor_local = Vector3.ZERO
	m_drag_floor_edit_mask = FLOOR_EDIT_MOVE
	m_drag_floor_active_material = null


func _handle_stair_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_stair != null:
		return _handle_stair_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_stair:
			_update_stair_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_stair_start_screen_position) >= WALL_DRAG_COMMIT_DISTANCE:
				m_stair_release_commits_preview = true
			return _handled()
		var stair_pick := _find_stair_pick(camera, mouse_motion.position)
		var hover_stair := stair_pick.get("stair") as Stairs3DScript
		var edit_mask := int(stair_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_stair_hover(hover_stair, edit_mask)
		if hover_stair != null:
			_set_status(
				"Drag stairs corner to resize." if _stair_edit_mask_is_corner(edit_mask)
				else "Drag stairs edge to resize." if edit_mask != FLOOR_EDIT_MOVE
				else "Drag stairs body to move."
			)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_stair:
		if !m_stair_release_commits_preview:
			_set_status("Click the opposite corner to place stairs, or drag from the first corner and release.")
			return _handled()
		var release_coordinator := _get_active_stair_coordinator()
		if release_coordinator != null:
			var release_end := m_stair_end_local
			if !m_stair_has_valid_preview:
				release_end = _stair_draw_local_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_stairs(release_coordinator, m_stair_start_local, release_end, m_stair_draw_rotation_degrees)
		_clear_stair_preview()
		_reset_stair_drawing_state()
		return _handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_stair:
		var stair_pick := _find_stair_pick(camera, mouse_button.position)
		var hit_stair := stair_pick.get("stair") as Stairs3DScript
		if hit_stair != null:
			_clear_stair_hover()
			_start_stair_drag(hit_stair, camera, mouse_button.position, int(stair_pick.get("edit_mask", FLOOR_EDIT_MOVE)))
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing stairs.")
		return _handled()
	_apply_stair_settings_to_coordinator(coordinator)

	var snapped_local := _stair_draw_local_from_mouse(coordinator, camera, mouse_button.position)
	if !m_is_drawing_stair:
		m_stair_start_local = snapped_local
		m_stair_end_local = snapped_local
		m_stair_start_screen_position = mouse_button.position
		m_stair_has_valid_preview = false
		m_stair_release_commits_preview = false
		m_stair_draw_rotation_degrees = _normalize_degrees(float(m_stair_settings.get("rotation_degrees", 0.0)))
		m_is_drawing_stair = true
		_create_stair_preview(coordinator)
		_update_stair_preview(camera, mouse_button.position)
		_set_status("Stairs first corner captured. Drag and release, or click the opposite corner.")
		return _handled()

	_commit_stairs(coordinator, m_stair_start_local, snapped_local, m_stair_draw_rotation_degrees)
	_clear_stair_preview()
	_reset_stair_drawing_state()
	return _handled()


func _create_stair_preview(coordinator: BuildingEditor3DScript) -> void:
	_clear_stair_preview()
	_apply_stair_settings_to_coordinator(coordinator)
	m_stair_preview = Stairs3DScript.new() as Stairs3DScript
	m_stair_preview.name = "StairsPreview"
	m_stair_preview.set_meta(Stairs3DScript.PREVIEW_META, true)
	m_stair_preview.stair_height = float(m_stair_settings["height"])
	m_stair_preview.step_count = int(m_stair_settings["step_count"])
	m_stair_preview.stair_thickness = float(m_stair_settings["thickness"])
	m_stair_preview.stair_rotation_degrees = m_stair_draw_rotation_degrees
	var preview_color := Color(m_stair_settings["color"])
	preview_color.a = 0.46
	m_stair_preview.stair_color = preview_color
	m_stair_preview.generate_collision = false
	coordinator.add_child(m_stair_preview)
	m_stair_preview.owner = null


func _update_stair_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_stair_preview == null:
		return
	var coordinator := m_stair_preview.get_parent() as BuildingEditor3DScript
	if coordinator == null:
		return
	var local_end := _stair_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_stair_end_local = local_end
	var stair_points := Stairs3DScript.stair_corners_from_base_points(
		m_stair_start_local,
		local_end,
		m_stair_draw_rotation_degrees
	)
	var stair_start := Vector3(stair_points["start"])
	var stair_end := Vector3(stair_points["end"])
	m_stair_has_valid_preview = _is_stair_span_large_enough(stair_start, stair_end)
	m_stair_preview.stair_height = float(m_stair_settings["height"])
	m_stair_preview.step_count = int(m_stair_settings["step_count"])
	m_stair_preview.stair_thickness = float(m_stair_settings["thickness"])
	m_stair_preview.set_stair_corners_and_rotation(stair_start, stair_end, m_stair_draw_rotation_degrees)
	if m_stair_has_valid_preview:
		var size := m_stair_preview.get_stair_size()
		_set_status(
			"Release or click to place stairs: %.2f x %.2f, %.0f deg." %
			[size.x, size.y, m_stair_draw_rotation_degrees]
		)


func _stair_base_height() -> float:
	return float(m_stair_settings.get("base_height", 0.0))


func _stair_draw_local_from_mouse(
	coordinator: BuildingEditor3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _stair_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_stair_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := _raycast_world(camera, mouse_position, false)
	return _snap_stair_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_stair_draw_local(
	coordinator: BuildingEditor3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := coordinator.snap_local_position(local_position)
	snapped.y = base_y
	return snapped


func _get_active_stair_coordinator() -> BuildingEditor3DScript:
	if m_stair_preview != null and is_instance_valid(m_stair_preview):
		var preview_parent := m_stair_preview.get_parent() as BuildingEditor3DScript
		if preview_parent != null:
			return preview_parent
	return _get_or_create_coordinator(false)


func _handle_stair_rotation_key(key_event: InputEventKey) -> int:
	var delta := -90.0 if key_event.shift_pressed else 90.0
	if m_is_drawing_stair:
		m_stair_draw_rotation_degrees = _normalize_degrees(m_stair_draw_rotation_degrees + delta)
		if m_stair_preview != null and is_instance_valid(m_stair_preview):
			var stair_points := Stairs3DScript.stair_corners_from_base_points(
				m_stair_start_local,
				m_stair_end_local,
				m_stair_draw_rotation_degrees
			)
			m_stair_preview.set_stair_corners_and_rotation(
				Vector3(stair_points["start"]),
				Vector3(stair_points["end"]),
				m_stair_draw_rotation_degrees
			)
		_set_status("Stairs preview rotation: %.0f degrees." % m_stair_draw_rotation_degrees)
		return _handled()

	if m_dragging_stair != null:
		_set_status("Release the stairs edit before rotating.")
		return _handled()

	var stair := m_drag_stair_hover if is_instance_valid(m_drag_stair_hover) else _selected_stair_for_rotation()
	if stair == null:
		_set_status("Hover or select stairs to rotate them.")
		return _handled()
	_commit_stair_rotation(stair, delta)
	return _handled()


func _selected_stair_for_rotation() -> Stairs3DScript:
	var selection := get_editor_interface().get_selection()
	if selection == null:
		return null
	for node in selection.get_selected_nodes():
		if node is Stairs3DScript:
			return node as Stairs3DScript
	return null


func _commit_stair_rotation(stair: Stairs3DScript, delta_degrees: float) -> void:
	if stair == null or !is_instance_valid(stair):
		return
	var old_start := stair.start_point
	var old_end := stair.end_point
	var old_rotation := stair.stair_rotation_degrees
	var new_rotation := _normalize_degrees(old_rotation + delta_degrees)
	var rotated_state := _stair_state_rotated_around_center(stair, new_rotation)
	var new_start := Vector3(rotated_state["start"])
	var new_end := Vector3(rotated_state["end"])
	_clear_stair_hover()

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Rotate Stairs")
	undo_redo.add_do_method(stair, "set_stair_corners_and_rotation", new_start, new_end, new_rotation)
	undo_redo.add_do_method(self, "_select_node", stair)
	undo_redo.add_undo_method(stair, "set_stair_corners_and_rotation", old_start, old_end, old_rotation)
	undo_redo.commit_action()
	_set_status("Rotated stairs to %.0f degrees." % new_rotation)


func _stair_state_rotated_around_center(stair: Stairs3DScript, rotation_degrees: float) -> Dictionary:
	var size := stair.get_stair_size()
	var center := stair.get_stair_center_point()
	var anchor := center - _stair_rotation_basis(rotation_degrees) * Vector3(size.x * 0.5, 0.0, size.y * 0.5)
	return {
		"start": anchor,
		"end": anchor + Vector3(size.x, 0.0, size.y),
	}


func _commit_stairs(
	coordinator: BuildingEditor3DScript,
	draw_start: Vector3,
	draw_end: Vector3,
	rotation_degrees: float
) -> void:
	var stair_points := Stairs3DScript.stair_corners_from_base_points(draw_start, draw_end, rotation_degrees)
	var local_start := Vector3(stair_points["start"])
	var local_end := Vector3(stair_points["end"])
	if !_is_stair_span_large_enough(local_start, local_end):
		_set_status("Stairs footprint is too small.")
		return

	_apply_stair_settings_to_coordinator(coordinator)
	var normalized_rotation := _normalize_degrees(rotation_degrees)
	var stairs := coordinator.create_stairs_node(
		local_start,
		local_end,
		float(m_stair_settings["height"]),
		int(m_stair_settings["step_count"]),
		float(m_stair_settings["thickness"]),
		Color(m_stair_settings["color"]),
		normalized_rotation
	)
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Stairs")
	undo_redo.add_do_reference(stairs)
	undo_redo.add_do_method(self, "_do_add_node", coordinator, stairs, scene_root, true)
	undo_redo.add_undo_method(self, "_undo_remove_node", coordinator, stairs)
	undo_redo.commit_action()
	var size := stairs.get_stair_size()
	_set_status("Created stairs: %.2f x %.2f units." % [size.x, size.y])


func _handle_stair_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_stair_drag(camera, (event as InputEventMouseMotion).position)
		return _handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_stair_drag()
			return _handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_stair_drag()
			return _handled()
	return _handled()


func _start_stair_drag(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mask: int
) -> void:
	m_dragging_stair = stair
	m_drag_stair_old_start = stair.start_point
	m_drag_stair_old_end = stair.end_point
	m_drag_stair_old_rotation_degrees = stair.stair_rotation_degrees
	m_drag_stair_edit_mask = edit_mask
	m_drag_stair_active_material = stair.material_override
	m_drag_stair_plane_y = _stair_drag_plane_y_from_mouse(stair, camera, mouse_pos)
	m_drag_stair_anchor_local = _stair_plane_local_from_mouse_at_y(stair, camera, mouse_pos, m_drag_stair_plane_y)
	stair.material_override = _build_preview_material(_stair_drag_color(edit_mask, true))
	_select_node(stair)
	_set_status("Dragging stairs %s - release to commit, Escape to cancel." % _stair_edit_label(edit_mask))


func _update_stair_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_stair == null or !is_instance_valid(m_dragging_stair):
		_reset_stair_drag_state()
		return
	var stair := m_dragging_stair
	var hit_local := _stair_plane_local_from_mouse_at_y(stair, camera, mouse_pos, m_drag_stair_plane_y)
	var new_start := m_drag_stair_old_start
	var new_end := m_drag_stair_old_end
	if m_drag_stair_edit_mask == FLOOR_EDIT_MOVE:
		var step := _active_stair_grid_step(stair)
		var raw_delta := hit_local - m_drag_stair_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		new_start = m_drag_stair_old_start + snapped_delta
		new_end = m_drag_stair_old_end + snapped_delta
	else:
		var stair_local := _stair_edit_local_from_parent_position(hit_local)
		var resized := _resized_stair_points(stair, stair_local)
		new_start = Vector3(resized["start"])
		new_end = Vector3(resized["end"])

	stair.set_stair_corners_and_rotation(new_start, new_end, m_drag_stair_old_rotation_degrees)
	var valid := _is_stair_span_large_enough(new_start, new_end)
	stair.material_override = _build_preview_material(
		_stair_drag_color(m_drag_stair_edit_mask, valid)
	)
	if valid:
		var size := stair.get_stair_size()
		_set_status("Release to commit stairs %s: %.2f x %.2f." % [_stair_edit_label(m_drag_stair_edit_mask), size.x, size.y])
	else:
		_set_status("Stairs footprint is too small.")


func _commit_stair_drag() -> void:
	if m_dragging_stair == null:
		return
	var stair := m_dragging_stair
	var old_start := m_drag_stair_old_start
	var old_end := m_drag_stair_old_end
	var old_rotation := m_drag_stair_old_rotation_degrees
	var new_start := stair.start_point
	var new_end := stair.end_point
	var new_rotation := stair.stair_rotation_degrees
	var edit_mask := m_drag_stair_edit_mask
	stair.material_override = m_drag_stair_active_material
	if !_is_stair_span_large_enough(new_start, new_end):
		stair.set_stair_corners_and_rotation(old_start, old_end, old_rotation)
		_reset_stair_drag_state()
		_set_status("Stairs footprint is too small.")
		return
	if (
			old_start.distance_to(new_start) <= 0.001
			and old_end.distance_to(new_end) <= 0.001
			and _angles_match(old_rotation, new_rotation)
	):
		_reset_stair_drag_state()
		_set_status("Stairs unchanged.")
		return

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Move Stairs" if edit_mask == FLOOR_EDIT_MOVE else "Resize Stairs")
	undo_redo.add_do_method(stair, "set_stair_corners_and_rotation", new_start, new_end, new_rotation)
	undo_redo.add_do_method(self, "_select_node", stair)
	undo_redo.add_undo_method(stair, "set_stair_corners_and_rotation", old_start, old_end, old_rotation)
	undo_redo.commit_action()
	_reset_stair_drag_state()
	var size := stair.get_stair_size()
	_set_status("Edited stairs: %.2f x %.2f units." % [size.x, size.y])


func _cancel_stair_drag() -> void:
	if m_dragging_stair == null:
		return
	if is_instance_valid(m_dragging_stair):
		m_dragging_stair.set_stair_corners_and_rotation(
			m_drag_stair_old_start,
			m_drag_stair_old_end,
			m_drag_stair_old_rotation_degrees
		)
		m_dragging_stair.material_override = m_drag_stair_active_material
	_reset_stair_drag_state()
	_set_status("Stairs edit canceled.")


func _resized_stair_points(stair: Stairs3DScript, stair_local_hit: Vector3) -> Dictionary:
	var old_size := Vector2(
		absf(m_drag_stair_old_end.x - m_drag_stair_old_start.x),
		absf(m_drag_stair_old_end.z - m_drag_stair_old_start.z)
	)
	var min_x := 0.0
	var max_x := old_size.x
	var min_z := 0.0
	var max_z := old_size.y
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MIN_X) != 0:
		min_x = _snap_stair_footprint_edge(stair, stair_local_hit.x)
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MAX_X) != 0:
		max_x = _snap_stair_footprint_edge(stair, stair_local_hit.x)
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MIN_Z) != 0:
		min_z = _snap_stair_footprint_edge(stair, stair_local_hit.z)
	if (m_drag_stair_edit_mask & FLOOR_EDIT_MAX_Z) != 0:
		max_z = _snap_stair_footprint_edge(stair, stair_local_hit.z)
	var sorted_min_x := minf(min_x, max_x)
	var sorted_max_x := maxf(min_x, max_x)
	var sorted_min_z := minf(min_z, max_z)
	var sorted_max_z := maxf(min_z, max_z)
	var base_y := m_drag_stair_old_start.y
	var old_anchor := Vector3(
		minf(m_drag_stair_old_start.x, m_drag_stair_old_end.x),
		base_y,
		minf(m_drag_stair_old_start.z, m_drag_stair_old_end.z)
	)
	var rotated_anchor := old_anchor + _stair_rotation_basis(m_drag_stair_old_rotation_degrees) * Vector3(
		sorted_min_x,
		0.0,
		sorted_min_z
	)
	var resized_size := Vector2(sorted_max_x - sorted_min_x, sorted_max_z - sorted_min_z)
	return {
		"start": rotated_anchor,
		"end": rotated_anchor + Vector3(resized_size.x, 0.0, resized_size.y),
	}


func _stair_plane_local_from_mouse(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	return _stair_plane_local_from_mouse_at_y(stair, camera, mouse_position, stair.start_point.y)


func _stair_plane_local_from_mouse_at_y(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_position: Vector2,
	plane_y: float
) -> Vector3:
	var parent_3d := stair.get_parent() as Node3D
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
	return stair.start_point


func _stair_drag_plane_y_from_mouse(
	stair: Stairs3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> float:
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var hit := _intersect_stair_bounds(stair, origin, direction)
	if hit.is_empty():
		return stair.start_point.y
	var hit_position := Vector3(hit.get("position", stair.global_position))
	var parent_3d := stair.get_parent() as Node3D
	var parent_position := parent_3d.to_local(hit_position) if parent_3d != null else hit_position
	return parent_position.y


func _stair_edit_local_from_parent_position(local_position: Vector3) -> Vector3:
	var drag_anchor := Vector3(
		minf(m_drag_stair_old_start.x, m_drag_stair_old_end.x),
		m_drag_stair_old_start.y,
		minf(m_drag_stair_old_start.z, m_drag_stair_old_end.z)
	)
	var drag_frame := Transform3D(_stair_rotation_basis(m_drag_stair_old_rotation_degrees), drag_anchor)
	return drag_frame.affine_inverse() * local_position


func _snap_stair_footprint_edge(stair: Stairs3DScript, value: float) -> float:
	var step := _active_stair_grid_step(stair)
	return roundf(value / step) * step


func _stair_drag_color(edit_mask: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if edit_mask == FLOOR_EDIT_MOVE:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _stair_edit_label(edit_mask: int) -> String:
	if edit_mask == FLOOR_EDIT_MOVE:
		return "body"
	return "corner" if _stair_edit_mask_is_corner(edit_mask) else "edge"


func _stair_edit_mask_is_corner(edit_mask: int) -> bool:
	var edits_x := (edit_mask & FLOOR_EDIT_MIN_X) != 0 or (edit_mask & FLOOR_EDIT_MAX_X) != 0
	var edits_z := (edit_mask & FLOOR_EDIT_MIN_Z) != 0 or (edit_mask & FLOOR_EDIT_MAX_Z) != 0
	return edits_x and edits_z


func _active_stair_grid_step(stair: Stairs3DScript) -> float:
	var coordinator := _find_coordinator_from_node(stair)
	if coordinator != null:
		return maxf(coordinator.grid_step, 0.05)
	return maxf(float(m_stair_settings["grid_step"]), 0.05)


func _stair_rotation_basis(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees(rotation_degrees)))


func _reset_stair_drag_state() -> void:
	m_dragging_stair = null
	m_drag_stair_old_start = Vector3.ZERO
	m_drag_stair_old_end = Vector3.ZERO
	m_drag_stair_old_rotation_degrees = 0.0
	m_drag_stair_anchor_local = Vector3.ZERO
	m_drag_stair_plane_y = 0.0
	m_drag_stair_edit_mask = FLOOR_EDIT_MOVE
	m_drag_stair_active_material = null


func _handle_roof_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_roof != null:
		return _handle_roof_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if m_is_drawing_roof:
			_update_roof_preview(camera, mouse_motion.position)
			if mouse_motion.position.distance_to(m_roof_start_screen_position) >= WALL_DRAG_COMMIT_DISTANCE:
				m_roof_release_commits_preview = true
			return _handled()
		var roof_pick := _find_roof_pick(camera, mouse_motion.position)
		var hover_roof := roof_pick.get("roof") as Roof3DScript
		var edit_mask := int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE))
		_update_roof_hover(hover_roof, edit_mask)
		if hover_roof != null:
			_set_status(
				"Drag roof corner to resize." if _roof_edit_mask_is_corner(edit_mask)
				else "Drag roof edge to resize." if edit_mask != FLOOR_EDIT_MOVE
				else "Drag roof body to move."
			)
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
		var roof_pick := _find_roof_pick(camera, mouse_button.position)
		var hit_roof := roof_pick.get("roof") as Roof3DScript
		if hit_roof != null:
			_clear_roof_hover()
			_start_roof_drag(hit_roof, camera, mouse_button.position, int(roof_pick.get("edit_mask", FLOOR_EDIT_MOVE)))
			return _handled()

	var coordinator := _get_or_create_coordinator(true)
	if coordinator == null:
		_set_status("Open or create a scene before drawing roofs.")
		return _handled()
	_apply_roof_settings_to_coordinator(coordinator)

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


func _create_roof_preview(coordinator: BuildingEditor3DScript) -> void:
	_clear_roof_preview()
	_apply_roof_settings_to_coordinator(coordinator)
	m_roof_preview = Roof3DScript.new() as Roof3DScript
	m_roof_preview.name = "RoofPreview"
	m_roof_preview.set_meta(Roof3DScript.PREVIEW_META, true)
	m_roof_preview.set_roof_style(String(m_roof_settings["style"]))
	m_roof_preview.roof_height = float(m_roof_settings["height"])
	m_roof_preview.roof_thickness = float(m_roof_settings["thickness"])
	m_roof_preview.roof_overhang = float(m_roof_settings["overhang"])
	m_roof_preview.hip_gable_height = float(m_roof_settings.get("hip_gable_height", 0.0))
	m_roof_preview.roof_rotation_degrees = m_roof_draw_rotation_degrees
	var preview_color := Color(m_roof_settings["color"])
	preview_color.a = 0.46
	m_roof_preview.roof_color = preview_color
	m_roof_preview.generate_collision = false
	m_roof_preview.debug_show_triangle_wireframe = bool(m_roof_settings.get("debug_wireframe", false))
	coordinator.add_child(m_roof_preview)
	m_roof_preview.owner = null


func _update_roof_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	if m_roof_preview == null:
		return
	var coordinator := m_roof_preview.get_parent() as BuildingEditor3DScript
	if coordinator == null:
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
	m_roof_preview.set_roof_style(String(m_roof_settings["style"]))
	m_roof_preview.roof_height = float(m_roof_settings["height"])
	m_roof_preview.roof_thickness = float(m_roof_settings["thickness"])
	m_roof_preview.roof_overhang = float(m_roof_settings["overhang"])
	m_roof_preview.hip_gable_height = float(m_roof_settings.get("hip_gable_height", 0.0))
	m_roof_preview.debug_show_triangle_wireframe = bool(m_roof_settings.get("debug_wireframe", false))
	m_roof_preview.set_roof_corners_and_rotation(roof_start, roof_end, m_roof_draw_rotation_degrees)
	if m_roof_has_valid_preview:
		var size := m_roof_preview.get_roof_size()
		_set_status(
			"Release or click to place roof: %.2f x %.2f, %.0f deg." %
			[size.x, size.y, m_roof_draw_rotation_degrees]
		)


func _roof_base_height() -> float:
	return float(m_roof_settings.get("base_height", 2.4))


func _roof_draw_local_from_mouse(
	coordinator: BuildingEditor3DScript,
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
	coordinator: BuildingEditor3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := coordinator.snap_local_position(local_position)
	snapped.y = base_y
	return snapped


func _get_active_roof_coordinator() -> BuildingEditor3DScript:
	if m_roof_preview != null and is_instance_valid(m_roof_preview):
		var preview_parent := m_roof_preview.get_parent() as BuildingEditor3DScript
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
	var old_height := roof.roof_height
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
			roof.roof_height,
			roof.roof_thickness,
			roof.roof_overhang,
			roof.roof_color,
			new_rotation,
			roof,
			true,
			roof.hip_gable_height
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
	coordinator: BuildingEditor3DScript,
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

	_apply_roof_settings_to_coordinator(coordinator)
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

	var roof := coordinator.create_roof_node(
		local_start,
		local_end,
		style,
		height,
		thickness,
		overhang,
		color,
		normalized_rotation,
		bool(m_roof_settings.get("debug_wireframe", false)),
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
	edit_mask: int
) -> void:
	m_dragging_roof = roof
	m_drag_roof_old_start = roof.start_point
	m_drag_roof_old_end = roof.end_point
	m_drag_roof_old_rotation_degrees = roof.roof_rotation_degrees
	m_drag_roof_old_height = roof.roof_height
	m_drag_roof_old_covered_rects = roof.get_covered_rects()
	m_drag_roof_old_covered_polygons = roof.get_covered_polygons()
	m_drag_roof_edit_mask = edit_mask
	m_drag_roof_active_material = roof.material_override
	m_drag_roof_plane_y = _roof_drag_plane_y_from_mouse(roof, camera, mouse_pos)
	m_drag_roof_anchor_local = _roof_plane_local_from_mouse_at_y(roof, camera, mouse_pos, m_drag_roof_plane_y)
	roof.material_override = _build_preview_material(_roof_drag_color(edit_mask, true))
	_select_node(roof)
	_set_status("Dragging roof %s - release to commit, Escape to cancel." % _roof_edit_label(edit_mask))


func _update_roof_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_roof == null or !is_instance_valid(m_dragging_roof):
		_reset_roof_drag_state()
		return
	var roof := m_dragging_roof
	var hit_local := _roof_plane_local_from_mouse_at_y(roof, camera, mouse_pos, m_drag_roof_plane_y)
	var new_start := m_drag_roof_old_start
	var new_end := m_drag_roof_old_end
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
	roof.set_roof_corners_rotation_height_and_covers(
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
	var old_start := m_drag_roof_old_start
	var old_end := m_drag_roof_old_end
	var old_rotation := m_drag_roof_old_rotation_degrees
	var old_height := m_drag_roof_old_height
	var old_covered_rects := m_drag_roof_old_covered_rects
	var old_covered_polygons := m_drag_roof_old_covered_polygons
	var new_start := roof.start_point
	var new_end := roof.end_point
	var new_rotation := roof.roof_rotation_degrees
	var new_height := roof.roof_height
	var edit_mask := m_drag_roof_edit_mask
	var coordinator := _find_coordinator_from_node(roof)
	roof.material_override = m_drag_roof_active_material
	if !_is_roof_span_large_enough(new_start, new_end):
		roof.set_roof_corners_rotation_height_and_covers(
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
		if coordinator != null:
			coordinator.refresh_roof_covered_rects()
		_reset_roof_drag_state()
		_set_status("Roof is too small.")
		return
	if (
			old_start.distance_to(new_start) <= 0.001
			and old_end.distance_to(new_end) <= 0.001
			and _angles_match(old_rotation, new_rotation)
			and is_equal_approx(old_height, new_height)
	):
		roof.set_roof_corners_rotation_height_and_covers(
			old_start,
			old_end,
			old_rotation,
			old_height,
			old_covered_rects,
			old_covered_polygons
		)
		if coordinator != null:
			coordinator.refresh_roof_covered_rects()
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
			roof.hip_gable_height
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
			roof.set_roof_corners_rotation_height_and_covers(
				old_start,
				old_end,
				old_rotation,
				old_height,
				old_covered_rects,
				old_covered_polygons
			)
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
			roof.set_roof_corners_rotation_height_and_covers(
				old_start,
				old_end,
				old_rotation,
				old_height,
				old_covered_rects,
				old_covered_polygons
			)
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


func _cancel_roof_drag() -> void:
	if m_dragging_roof == null:
		return
	if is_instance_valid(m_dragging_roof):
		m_dragging_roof.set_roof_corners_rotation_height_and_covers(
			m_drag_roof_old_start,
			m_drag_roof_old_end,
			m_drag_roof_old_rotation_degrees,
			m_drag_roof_old_height,
			m_drag_roof_old_covered_rects,
			m_drag_roof_old_covered_polygons
		)
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


func _roof_drag_color(edit_mask: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	if edit_mask == FLOOR_EDIT_MOVE:
		return Color(0.20, 0.60, 1.0, 0.55)
	return Color(1.0, 0.85, 0.20, 0.72)


func _roof_edit_label(edit_mask: int) -> String:
	if edit_mask == FLOOR_EDIT_MOVE:
		return "body"
	return "corner" if _roof_edit_mask_is_corner(edit_mask) else "edge"


func _roof_edit_mask_is_corner(edit_mask: int) -> bool:
	var edits_x := (edit_mask & FLOOR_EDIT_MIN_X) != 0 or (edit_mask & FLOOR_EDIT_MAX_X) != 0
	var edits_z := (edit_mask & FLOOR_EDIT_MIN_Z) != 0 or (edit_mask & FLOOR_EDIT_MAX_Z) != 0
	return edits_x and edits_z


func _active_roof_grid_step(roof: Roof3DScript) -> float:
	var coordinator := _find_coordinator_from_node(roof)
	if coordinator != null:
		return maxf(coordinator.grid_step, 0.05)
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
	m_drag_roof_old_rotation_degrees = 0.0
	m_drag_roof_old_height = 0.0
	m_drag_roof_old_covered_rects = []
	m_drag_roof_old_covered_polygons = []
	m_drag_roof_anchor_local = Vector3.ZERO
	m_drag_roof_plane_y = 0.0
	m_drag_roof_edit_mask = FLOOR_EDIT_MOVE
	m_drag_roof_active_material = null


func _handle_pillar_input(camera: Camera3D, event: InputEvent) -> int:
	if m_dragging_pillar != null:
		return _handle_pillar_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		var pillar_pick := _find_pillar_pick(camera, mouse_pos)
		var hover_pillar := pillar_pick.get("pillar") as Pillar3DScript
		var edit_mode := int(pillar_pick.get("edit_mode", PILLAR_EDIT_MOVE))
		_update_pillar_hover(hover_pillar, edit_mode)
		if hover_pillar != null:
			_clear_pillar_preview()
			_set_status(
				"Drag pillar edge to resize radius." if edit_mode == PILLAR_EDIT_RADIUS
				else "Drag pillar body to move."
			)
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		_update_pillar_preview(camera, mouse_pos, false)
		return _handled() if m_pillar_preview != null else EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var pillar_pick := _find_pillar_pick(camera, mouse_button.position)
	var hit_pillar := pillar_pick.get("pillar") as Pillar3DScript
	if hit_pillar != null:
		_clear_pillar_preview()
		_clear_pillar_hover()
		_start_pillar_drag(
			hit_pillar,
			camera,
			mouse_button.position,
			int(pillar_pick.get("edit_mode", PILLAR_EDIT_MOVE))
		)
		return _handled()

	_update_pillar_preview(camera, mouse_button.position, true)
	if m_pillar_preview_valid:
		_commit_pillar()
	return _handled()


func _create_pillar_preview(coordinator: BuildingEditor3DScript) -> void:
	_clear_pillar_preview()
	_apply_pillar_settings_to_coordinator(coordinator)
	m_pillar_preview = Pillar3DScript.new() as Pillar3DScript
	m_pillar_preview.name = "PillarPreview"
	m_pillar_preview.set_meta(Pillar3DScript.PREVIEW_META, true)
	m_pillar_preview.pillar_radius = float(m_pillar_settings["radius"])
	m_pillar_preview.upper_radius = float(m_pillar_settings["upper_radius"])
	m_pillar_preview.pillar_height = float(m_pillar_settings["height"])
	m_pillar_preview.side_count = int(m_pillar_settings["sides"])
	m_pillar_preview.set_pillar_style(String(m_pillar_settings["style"]))
	m_pillar_preview.set_pillar_rims(
		float(m_pillar_settings["lower_rim_height"]),
		float(m_pillar_settings["lower_rim_outset"]),
		float(m_pillar_settings["upper_rim_height"]),
		float(m_pillar_settings["upper_rim_outset"])
	)
	var preview_color := Color(m_pillar_settings["color"])
	preview_color.a = 0.48
	m_pillar_preview.pillar_color = preview_color
	m_pillar_preview.generate_collision = false
	coordinator.add_child(m_pillar_preview)
	m_pillar_preview.owner = null


func _update_pillar_preview(camera: Camera3D, mouse_position: Vector2, create_if_missing: bool) -> void:
	var coordinator := _get_or_create_coordinator(create_if_missing)
	if coordinator == null:
		_clear_pillar_preview()
		m_pillar_preview_valid = false
		_set_status("Click to create a coordinator and place a pillar." if create_if_missing else "Move over the scene, then click to place a pillar.")
		return
	if m_pillar_preview == null:
		_create_pillar_preview(coordinator)
	_apply_pillar_settings_to_coordinator(coordinator)
	var local_base := _pillar_draw_local_from_mouse(coordinator, camera, mouse_position)
	m_pillar_preview.set_pillar_base_position(local_base)
	m_pillar_preview.pillar_radius = float(m_pillar_settings["radius"])
	m_pillar_preview.upper_radius = float(m_pillar_settings["upper_radius"])
	m_pillar_preview.pillar_height = float(m_pillar_settings["height"])
	m_pillar_preview.side_count = int(m_pillar_settings["sides"])
	m_pillar_preview.set_pillar_style(String(m_pillar_settings["style"]))
	m_pillar_preview.set_pillar_rims(
		float(m_pillar_settings["lower_rim_height"]),
		float(m_pillar_settings["lower_rim_outset"]),
		float(m_pillar_settings["upper_rim_height"]),
		float(m_pillar_settings["upper_rim_outset"])
	)
	m_pillar_preview_valid = _is_pillar_radius_valid(m_pillar_preview.pillar_radius)
	_set_status("Click to place pillar." if m_pillar_preview_valid else "Pillar radius is too small.")


func _pillar_base_height() -> float:
	return float(m_pillar_settings.get("base_height", 0.0))


func _pillar_draw_local_from_mouse(
	coordinator: BuildingEditor3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var base_y := _pillar_base_height()
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var local_origin := coordinator.to_local(origin)
	var local_direction := coordinator.global_transform.basis.inverse() * direction
	if local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		if absf(local_direction.y) > 0.001:
			var distance_to_plane := (base_y - local_origin.y) / local_direction.y
			if distance_to_plane > 0.0:
				return _snap_pillar_draw_local(
					coordinator,
					local_origin + local_direction * distance_to_plane,
					base_y
				)

	var hit := _raycast_world(camera, mouse_position, false)
	return _snap_pillar_draw_local(coordinator, coordinator.to_local(Vector3(hit["position"])), base_y)


func _snap_pillar_draw_local(
	coordinator: BuildingEditor3DScript,
	local_position: Vector3,
	base_y: float
) -> Vector3:
	var snapped := coordinator.snap_local_position(local_position)
	snapped.y = base_y
	return snapped


func _commit_pillar() -> void:
	if m_pillar_preview == null:
		return
	var coordinator := m_pillar_preview.get_parent() as BuildingEditor3DScript
	if coordinator == null:
		return
	if !_is_pillar_radius_valid(m_pillar_preview.pillar_radius):
		_set_status("Pillar radius is too small.")
		return

	_apply_pillar_settings_to_coordinator(coordinator)
	var pillar := coordinator.create_pillar_node(
		m_pillar_preview.base_point,
		float(m_pillar_settings["radius"]),
		float(m_pillar_settings["height"]),
		int(m_pillar_settings["sides"]),
		String(m_pillar_settings["style"]),
		Color(m_pillar_settings["color"]),
		float(m_pillar_settings["lower_rim_height"]),
		float(m_pillar_settings["lower_rim_outset"]),
		float(m_pillar_settings["upper_rim_height"]),
		float(m_pillar_settings["upper_rim_outset"]),
		float(m_pillar_settings["upper_radius"])
	)
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Pillar")
	undo_redo.add_do_reference(pillar)
	undo_redo.add_do_method(self, "_do_add_node", coordinator, pillar, scene_root, true)
	undo_redo.add_undo_method(self, "_undo_remove_node", coordinator, pillar)
	undo_redo.commit_action()
	_set_status("Created pillar.")


func _handle_pillar_drag_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventMouseMotion:
		_update_pillar_drag(camera, (event as InputEventMouseMotion).position)
		return _handled()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and !mb.pressed:
			_commit_pillar_drag()
			return _handled()
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_cancel_pillar_drag()
			return _handled()
	return _handled()


func _start_pillar_drag(
	pillar: Pillar3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	edit_mode: int
) -> void:
	m_dragging_pillar = pillar
	m_drag_pillar_old_base = pillar.base_point
	m_drag_pillar_old_radius = pillar.pillar_radius
	m_drag_pillar_old_upper_radius = pillar.upper_radius
	m_drag_pillar_edit_mode = edit_mode
	m_drag_pillar_active_material = pillar.material_override
	m_drag_pillar_anchor_local = _pillar_plane_local_from_mouse(pillar, camera, mouse_pos)
	pillar.material_override = _build_preview_material(_pillar_drag_color(edit_mode, true))
	_select_node(pillar)
	_set_status("Dragging pillar %s - release to commit, Escape to cancel." % _pillar_edit_label(edit_mode))


func _update_pillar_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_pillar == null or !is_instance_valid(m_dragging_pillar):
		_reset_pillar_drag_state()
		return
	var pillar := m_dragging_pillar
	var hit_local := _pillar_plane_local_from_mouse(pillar, camera, mouse_pos)
	if m_drag_pillar_edit_mode == PILLAR_EDIT_RADIUS:
		var raw_radius := Vector2(hit_local.x - pillar.base_point.x, hit_local.z - pillar.base_point.z).length()
		var new_lower_radius := _snap_pillar_radius(pillar, raw_radius)
		var new_upper_radius := m_drag_pillar_old_upper_radius
		if new_upper_radius > 0.0001 and m_drag_pillar_old_radius > 0.0001:
			new_upper_radius = maxf(0.05, new_upper_radius * new_lower_radius / m_drag_pillar_old_radius)
		pillar.set_pillar_radii(new_lower_radius, new_upper_radius)
	else:
		var step := _active_pillar_grid_step(pillar)
		var raw_delta := hit_local - m_drag_pillar_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		pillar.set_pillar_base_position(m_drag_pillar_old_base + snapped_delta)
	var valid := _is_pillar_radius_valid(pillar.pillar_radius)
	pillar.material_override = _build_preview_material(_pillar_drag_color(m_drag_pillar_edit_mode, valid))
	_set_status(
		"Release to commit pillar %s." % _pillar_edit_label(m_drag_pillar_edit_mode)
		if valid
		else "Pillar radius is too small."
	)


func _commit_pillar_drag() -> void:
	if m_dragging_pillar == null:
		return
	var pillar := m_dragging_pillar
	var old_base := m_drag_pillar_old_base
	var old_radius := m_drag_pillar_old_radius
	var old_upper_radius := m_drag_pillar_old_upper_radius
	var new_base := pillar.base_point
	var new_radius := pillar.pillar_radius
	var new_upper_radius := pillar.upper_radius
	var edit_mode := m_drag_pillar_edit_mode
	pillar.material_override = m_drag_pillar_active_material
	if !_is_pillar_radius_valid(new_radius):
		pillar.set_pillar_base_and_radii(old_base, old_radius, old_upper_radius)
		_reset_pillar_drag_state()
		_set_status("Pillar radius is too small.")
		return
	if (
		old_base.distance_to(new_base) <= 0.001
		and is_equal_approx(old_radius, new_radius)
		and is_equal_approx(old_upper_radius, new_upper_radius)
	):
		_reset_pillar_drag_state()
		_set_status("Pillar unchanged.")
		return

	var undo_redo := get_undo_redo()
	undo_redo.create_action("Move Pillar" if edit_mode == PILLAR_EDIT_MOVE else "Resize Pillar")
	undo_redo.add_do_method(pillar, "set_pillar_base_and_radii", new_base, new_radius, new_upper_radius)
	undo_redo.add_do_method(self, "_select_node", pillar)
	undo_redo.add_undo_method(pillar, "set_pillar_base_and_radii", old_base, old_radius, old_upper_radius)
	undo_redo.commit_action()
	_reset_pillar_drag_state()
	_set_status("Edited pillar.")


func _cancel_pillar_drag() -> void:
	if m_dragging_pillar == null:
		return
	if is_instance_valid(m_dragging_pillar):
		m_dragging_pillar.set_pillar_base_and_radii(
			m_drag_pillar_old_base,
			m_drag_pillar_old_radius,
			m_drag_pillar_old_upper_radius
		)
		m_dragging_pillar.material_override = m_drag_pillar_active_material
	_reset_pillar_drag_state()
	_set_status("Pillar edit canceled.")


func _pillar_plane_local_from_mouse(
	pillar: Pillar3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var parent_3d := pillar.get_parent() as Node3D
	var base_y := pillar.base_point.y
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
	return pillar.base_point


func _snap_pillar_radius(pillar: Pillar3DScript, radius: float) -> float:
	var step := maxf(_active_pillar_grid_step(pillar) * 0.5, 0.05)
	return maxf(roundf(radius / step) * step, 0.05)


func _pillar_drag_color(edit_mode: int, valid: bool) -> Color:
	if !valid:
		return Color(0.95, 0.20, 0.16, 0.72)
	return Color(1.0, 0.85, 0.20, 0.72) if edit_mode == PILLAR_EDIT_RADIUS else Color(0.20, 0.60, 1.0, 0.55)


func _pillar_edit_label(edit_mode: int) -> String:
	return "radius" if edit_mode == PILLAR_EDIT_RADIUS else "body"


func _active_pillar_grid_step(pillar: Pillar3DScript) -> float:
	var coordinator := _find_coordinator_from_node(pillar)
	if coordinator != null:
		return maxf(coordinator.grid_step, 0.05)
	return maxf(float(m_pillar_settings["grid_step"]), 0.05)


func _is_pillar_radius_valid(radius: float) -> bool:
	return radius >= maxf(float(m_pillar_settings["grid_step"]) * 0.1, 0.05)


func _reset_pillar_drag_state() -> void:
	m_dragging_pillar = null
	m_drag_pillar_old_base = Vector3.ZERO
	m_drag_pillar_old_radius = 0.0
	m_drag_pillar_old_upper_radius = 0.0
	m_drag_pillar_anchor_local = Vector3.ZERO
	m_drag_pillar_edit_mode = PILLAR_EDIT_MOVE
	m_drag_pillar_active_material = null


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

	if !(m_prop_preview is BuildingOpening3DScript):
		_clear_prop_preview()
		m_prop_preview = BuildingOpening3DScript.new() as BuildingOpening3DScript
		(m_prop_preview as BuildingOpening3DScript).build_on_ready = true
	_set_preview_parent(m_prop_preview, wall)

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
	opening.transform = Transform3D(frame.basis, frame * local_hit)
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
	opening.opening_width = float(settings["width"])
	opening.opening_height = float(settings["height"])
	opening.frame_thickness = float(settings["frame_thickness"])
	opening.frame_depth = frame_depth
	opening.show_bottom_frame = bool(settings["show_bottom_frame"])
	opening.door_panel_count = int(settings["door_panel_count"])
	opening.door_panel_depth = float(settings["door_panel_depth"])
	opening.door_panel_color = Color(settings["door_panel_color"])
	opening.window_pane_count = int(settings["window_pane_count"])
	opening.window_pane_depth = float(settings["window_pane_depth"])
	opening.window_pane_color = Color(settings["window_pane_color"])


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
		var is_frame_only := style.ends_with("_frame")
		var label := "Double Door" if is_double else "Single Door"
		if is_frame_only:
			label += " Frame"
		var panel_count := 0
		if !is_frame_only:
			panel_count = 2 if is_double else 1
		var default_width := 1.6 if is_double else 0.9
		var node_name := label.replace(" ", "") + "Opening"
		return {
			"label": label,
			"node_name": node_name,
			"width": float(m_door_settings.get("width", default_width)),
			"height": float(m_door_settings.get("height", 2.1)),
			"frame_thickness": float(m_door_settings.get("frame_thickness", 0.08)),
			"sill_height": 0.0,
			"show_bottom_frame": false,
			"door_panel_count": panel_count,
			"door_panel_depth": 0.05,
			"door_panel_color": Color(0.50, 0.34, 0.20, 1.0),
			"window_pane_count": 0,
			"window_pane_depth": 0.03,
			"window_pane_color": Color(0.58, 0.82, 0.95, 0.52),
			"allow_base_edge": true,
		}

	var style := String(m_window_settings.get("style", "single_window"))
	var is_double := style == "double_window"
	var is_frame_only := style == "frame"
	var label := "Single Window"
	if is_double:
		label = "Double Window"
	if is_frame_only:
		label = "Window Frame"
	var pane_count := 0
	if !is_frame_only:
		pane_count = 2 if is_double else 1
	var default_width := 1.8 if is_double else 1.0
	var node_name := label.replace(" ", "") + "Opening"
	return {
		"label": label,
		"node_name": node_name,
		"width": float(m_window_settings.get("width", default_width)),
		"height": float(m_window_settings["height"]),
		"frame_thickness": float(m_window_settings["frame_thickness"]),
		"sill_height": maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0),
		"show_bottom_frame": true,
		"door_panel_count": 0,
		"door_panel_depth": 0.05,
		"door_panel_color": Color(0.50, 0.34, 0.20, 1.0),
		"window_pane_count": pane_count,
		"window_pane_depth": 0.03,
		"window_pane_color": Color(0.58, 0.82, 0.95, 0.52),
		"allow_base_edge": false,
	}


func _update_prop_preview(wall: Wall3DScript, hit: Dictionary) -> void:
	var scene_path := String(m_prop_settings["scene_path"])
	if scene_path.is_empty() or !ResourceLoader.exists(scene_path):
		_clear_prop_preview()
		_set_status("Select a prop scene.")
		m_preview_valid = false
		return

	if m_prop_preview == null or m_prop_preview_path != scene_path:
		_clear_prop_preview()
		m_prop_preview = _instantiate_prop(scene_path)
		m_prop_preview_path = scene_path
		if m_prop_preview == null:
			m_preview_valid = false
			_set_status("Prop scene root must be Node3D.")
			return
		_apply_preview_material(m_prop_preview, Color(0.20, 0.88, 0.36, 0.42))

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
		var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
		opening.name = String(settings["node_name"])
		opening.opening_width = opening_preview.opening_width
		opening.opening_height = opening_preview.opening_height
		opening.frame_thickness = opening_preview.frame_thickness
		opening.frame_depth = opening_preview.frame_depth
		opening.frame_color = Color(0.86, 0.92, 0.94, 1.0)
		opening.show_bottom_frame = opening_preview.show_bottom_frame
		opening.door_panel_count = opening_preview.door_panel_count
		opening.door_panel_depth = opening_preview.door_panel_depth
		opening.door_panel_color = opening_preview.door_panel_color
		opening.window_pane_count = opening_preview.window_pane_count
		opening.window_pane_depth = opening_preview.window_pane_depth
		opening.window_pane_color = opening_preview.window_pane_color
		opening.position = opening_preview.position
		opening.rotation = opening_preview.rotation
		opening.set_meta(
			Wall3DScript.SEGMENT_INDEX_META,
			int(opening_preview.get_meta(Wall3DScript.SEGMENT_INDEX_META, 0))
		)
		opening.set_meta(
			OPENING_SILL_META,
			float(opening_preview.get_meta(OPENING_SILL_META, settings["sill_height"]))
		)
		opening.set_meta(
			OPENING_ALLOW_BASE_META,
			bool(opening_preview.get_meta(OPENING_ALLOW_BASE_META, settings["allow_base_edge"]))
		)
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
	if parent == scene_root and !(parent is BuildingEditor3DScript):
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
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	if include_walls:
		var wall_hit := _raycast_walls(origin, direction)
		if !wall_hit.is_empty():
			return wall_hit

	var fallback_position := origin + direction * 12.0
	if absf(direction.y) > 0.001:
		var t := -origin.y / direction.y
		if t > 0.0:
			fallback_position = origin + direction * t
	return {
		"position": fallback_position,
		"normal": Vector3.UP,
		"collider": null,
	}


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


func _find_stair_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_stairs(origin, direction)
	if hit.is_empty():
		return {}
	var stair := hit.get("stair") as Stairs3DScript
	if stair == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mask"] = _stair_edit_mask_for_local_hit(stair, local_position)
	return hit


func _raycast_stairs(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var stairs_nodes: Array[Stairs3DScript] = []
	_collect_scene_stairs(scene_root, stairs_nodes)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for stair in stairs_nodes:
		if !is_instance_valid(stair) or stair == m_stair_preview:
			continue
		if stair.has_meta(Stairs3DScript.PREVIEW_META):
			continue
		var hit := _intersect_stair_bounds(stair, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_stairs(node: Node, stairs_nodes: Array[Stairs3DScript]) -> void:
	if node is Stairs3DScript:
		stairs_nodes.append(node as Stairs3DScript)
	for child in node.get_children():
		_collect_scene_stairs(child, stairs_nodes)


func _intersect_stair_bounds(
	stair: Stairs3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var size := stair.get_stair_size()
	if size.x <= 0.001 or size.y <= 0.001:
		return {}
	var inverse_frame := stair.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var min_corner := stair.get_stair_bounds_min()
	var max_corner := stair.get_stair_bounds_max()
	var hit := _intersect_aabb_ray(local_origin, local_direction, min_corner, max_corner)
	if hit.is_empty():
		return {}

	var local_hit := Vector3(hit["position"])
	var local_normal := _nearest_box_normal(local_hit, min_corner, max_corner)
	var global_hit := stair.global_transform * local_hit
	return {
		"stair": stair,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (stair.global_transform.basis * local_normal).normalized(),
		"collider": stair,
		"distance": origin.distance_to(global_hit),
	}


func _stair_edit_mask_for_local_hit(stair: Stairs3DScript, local_hit: Vector3) -> int:
	var size := stair.get_stair_size()
	var radius := maxf(_active_stair_grid_step(stair) * 0.35, 0.16)
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


func _find_pillar_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_pos)
	var direction := camera.project_ray_normal(mouse_pos)
	var hit := _raycast_pillars(origin, direction)
	if hit.is_empty():
		return {}
	var pillar := hit.get("pillar") as Pillar3DScript
	if pillar == null:
		return {}
	var local_position := Vector3(hit.get("local_position", Vector3.ZERO))
	hit["edit_mode"] = _pillar_edit_mode_for_local_hit(pillar, local_position)
	return hit


func _raycast_pillars(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var pillars: Array[Pillar3DScript] = []
	_collect_scene_pillars(scene_root, pillars)

	var best_hit: Dictionary = {}
	var best_distance := INF
	for pillar in pillars:
		if !is_instance_valid(pillar) or pillar == m_pillar_preview:
			continue
		if pillar.has_meta(Pillar3DScript.PREVIEW_META):
			continue
		var hit := _intersect_pillar_cylinder(pillar, origin, direction)
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	return best_hit


func _collect_scene_pillars(node: Node, pillars: Array[Pillar3DScript]) -> void:
	if node is Pillar3DScript:
		pillars.append(node as Pillar3DScript)
	for child in node.get_children():
		_collect_scene_pillars(child, pillars)


func _intersect_pillar_cylinder(
	pillar: Pillar3DScript,
	origin: Vector3,
	direction: Vector3
) -> Dictionary:
	var pick_radius := pillar.get_outer_radius()
	if pick_radius <= 0.001 or pillar.pillar_height <= 0.001:
		return {}
	var inverse_frame := pillar.global_transform.affine_inverse()
	var local_origin := inverse_frame * origin
	var local_direction := inverse_frame.basis * direction
	if local_direction.length_squared() <= 0.000001:
		return {}
	local_direction = local_direction.normalized()

	var candidates: Array[Dictionary] = []
	var a := local_direction.x * local_direction.x + local_direction.z * local_direction.z
	if a > 0.000001:
		var b := 2.0 * (local_origin.x * local_direction.x + local_origin.z * local_direction.z)
		var c := (
			local_origin.x * local_origin.x
			+ local_origin.z * local_origin.z
			- pick_radius * pick_radius
		)
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var sqrt_discriminant := sqrt(discriminant)
			_append_pillar_side_hit_candidate(candidates, pillar, local_origin, local_direction, (-b - sqrt_discriminant) / (2.0 * a))
			_append_pillar_side_hit_candidate(candidates, pillar, local_origin, local_direction, (-b + sqrt_discriminant) / (2.0 * a))

	if absf(local_direction.y) > 0.000001:
		_append_pillar_cap_hit_candidate(candidates, pillar, local_origin, local_direction, 0.0, Vector3.DOWN)
		_append_pillar_cap_hit_candidate(candidates, pillar, local_origin, local_direction, pillar.pillar_height, Vector3.UP)

	if candidates.is_empty():
		return {}

	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if float(candidate["t"]) < float(best["t"]):
			best = candidate
	var local_hit := Vector3(best["position"])
	var local_normal := Vector3(best["normal"])
	var global_hit := pillar.global_transform * local_hit
	return {
		"pillar": pillar,
		"position": global_hit,
		"local_position": local_hit,
		"normal": (pillar.global_transform.basis * local_normal).normalized(),
		"collider": pillar,
		"distance": origin.distance_to(global_hit),
	}


func _append_pillar_side_hit_candidate(
	candidates: Array[Dictionary],
	pillar: Pillar3DScript,
	local_origin: Vector3,
	local_direction: Vector3,
	t: float
) -> void:
	if t < 0.0:
		return
	var hit_position := local_origin + local_direction * t
	if hit_position.y < 0.0 or hit_position.y > pillar.pillar_height:
		return
	var normal := Vector3(hit_position.x, 0.0, hit_position.z)
	if normal.length_squared() <= 0.000001:
		return
	candidates.append({
		"t": t,
		"position": hit_position,
		"normal": normal.normalized(),
	})


func _append_pillar_cap_hit_candidate(
	candidates: Array[Dictionary],
	pillar: Pillar3DScript,
	local_origin: Vector3,
	local_direction: Vector3,
	cap_y: float,
	normal: Vector3
) -> void:
	var t := (cap_y - local_origin.y) / local_direction.y
	if t < 0.0:
		return
	var hit_position := local_origin + local_direction * t
	var radius_sq := hit_position.x * hit_position.x + hit_position.z * hit_position.z
	var pick_radius := pillar.get_outer_radius()
	if radius_sq > pick_radius * pick_radius:
		return
	candidates.append({
		"t": t,
		"position": hit_position,
		"normal": normal,
	})


func _pillar_edit_mode_for_local_hit(pillar: Pillar3DScript, local_hit: Vector3) -> int:
	var radius := Vector2(local_hit.x, local_hit.z).length()
	var edge_tolerance := maxf(_active_pillar_grid_step(pillar) * 0.25, 0.08)
	if (
		absf(pillar.pillar_radius - radius) <= edge_tolerance
		or absf(pillar.get_outer_radius() - radius) <= edge_tolerance
	):
		return PILLAR_EDIT_RADIUS
	return PILLAR_EDIT_MOVE


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
	var t_min := -INF
	var t_max := INF
	for axis in range(3):
		var axis_origin := _axis_value(origin, axis)
		var axis_direction := _axis_value(direction, axis)
		var axis_min := _axis_value(min_corner, axis)
		var axis_max := _axis_value(max_corner, axis)
		if absf(axis_direction) <= 0.000001:
			if axis_origin < axis_min or axis_origin > axis_max:
				return {}
			continue

		var t1 := (axis_min - axis_origin) / axis_direction
		var t2 := (axis_max - axis_origin) / axis_direction
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return {}

	if t_max < 0.0:
		return {}

	var hit_distance := maxf(t_min, 0.0)
	return {
		"position": origin + direction * hit_distance,
	}


func _axis_value(value: Vector3, axis: int) -> float:
	match axis:
		0:
			return value.x
		1:
			return value.y
		_:
			return value.z


func _nearest_box_normal(point: Vector3, min_corner: Vector3, max_corner: Vector3) -> Vector3:
	var best_distance := absf(point.x - min_corner.x)
	var best_normal := Vector3(-1.0, 0.0, 0.0)

	var distance := absf(point.x - max_corner.x)
	if distance < best_distance:
		best_distance = distance
		best_normal = Vector3(1.0, 0.0, 0.0)

	distance = absf(point.y - min_corner.y)
	if distance < best_distance:
		best_distance = distance
		best_normal = Vector3(0.0, -1.0, 0.0)

	distance = absf(point.y - max_corner.y)
	if distance < best_distance:
		best_distance = distance
		best_normal = Vector3(0.0, 1.0, 0.0)

	distance = absf(point.z - min_corner.z)
	if distance < best_distance:
		best_distance = distance
		best_normal = Vector3(0.0, 0.0, -1.0)

	distance = absf(point.z - max_corner.z)
	if distance < best_distance:
		best_normal = Vector3(0.0, 0.0, 1.0)

	return best_normal


func _find_wall_from_collider(collider: Variant) -> Wall3DScript:
	var node := collider as Node
	while node != null:
		if node is Wall3DScript:
			return node as Wall3DScript
		node = node.get_parent()
	return null


func _get_or_create_coordinator(create_if_missing: bool) -> BuildingEditor3DScript:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return null
	var selected_nodes := get_editor_interface().get_selection().get_selected_nodes()
	for node in selected_nodes:
		var coordinator := _find_coordinator_from_node(node)
		if coordinator != null:
			return coordinator
	var existing := _find_first_coordinator(scene_root)
	if existing != null or !create_if_missing:
		return existing
	var coordinator := BuildingEditor3DScript.new() as BuildingEditor3DScript
	coordinator.name = "BuildingEditor3D"
	_apply_wall_settings_to_coordinator(coordinator)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Create Building Editor")
	undo_redo.add_do_reference(coordinator)
	undo_redo.add_do_method(self, "_do_add_node", scene_root, coordinator, scene_root, true)
	undo_redo.add_undo_method(self, "_undo_remove_node", scene_root, coordinator)
	undo_redo.commit_action()
	_refresh_dock_context()
	return coordinator


func _find_coordinator_from_node(node: Node) -> BuildingEditor3DScript:
	var cursor := node
	while cursor != null:
		if cursor is BuildingEditor3DScript:
			return cursor as BuildingEditor3DScript
		cursor = cursor.get_parent()
	return null


func _find_first_coordinator(root: Node) -> BuildingEditor3DScript:
	if root is BuildingEditor3DScript:
		return root as BuildingEditor3DScript
	for child in root.get_children():
		var found := _find_first_coordinator(child)
		if found != null:
			return found
	return null


func _apply_wall_settings_to_coordinator(coordinator: BuildingEditor3DScript) -> void:
	coordinator.grid_step = float(m_wall_settings["grid_step"])
	coordinator.lock_to_8_way = bool(m_wall_settings["lock_8_way"])
	coordinator.default_wall_height = float(m_wall_settings["height"])
	coordinator.default_wall_thickness = float(m_wall_settings["thickness"])
	coordinator.default_wall_color = Color(m_wall_settings["color"])


func _apply_floor_settings_to_coordinator(coordinator: BuildingEditor3DScript) -> void:
	coordinator.grid_step = float(m_floor_settings["grid_step"])
	coordinator.default_floor_thickness = float(m_floor_settings["thickness"])
	coordinator.default_floor_color = Color(m_floor_settings["color"])


func _apply_stair_settings_to_coordinator(coordinator: BuildingEditor3DScript) -> void:
	coordinator.grid_step = float(m_stair_settings["grid_step"])
	coordinator.default_stair_height = float(m_stair_settings["height"])
	coordinator.default_stair_step_count = int(m_stair_settings["step_count"])
	coordinator.default_stair_thickness = float(m_stair_settings["thickness"])
	coordinator.default_stair_rotation_degrees = float(m_stair_settings.get("rotation_degrees", 0.0))
	coordinator.default_stair_color = Color(m_stair_settings["color"])


func _apply_pillar_settings_to_coordinator(coordinator: BuildingEditor3DScript) -> void:
	coordinator.grid_step = float(m_pillar_settings["grid_step"])
	coordinator.default_pillar_radius = float(m_pillar_settings["radius"])
	coordinator.default_pillar_upper_radius = float(m_pillar_settings["upper_radius"])
	coordinator.default_pillar_height = float(m_pillar_settings["height"])
	coordinator.default_pillar_sides = int(m_pillar_settings["sides"])
	coordinator.default_pillar_style = String(m_pillar_settings["style"])
	coordinator.default_pillar_lower_rim_height = float(m_pillar_settings["lower_rim_height"])
	coordinator.default_pillar_lower_rim_outset = float(m_pillar_settings["lower_rim_outset"])
	coordinator.default_pillar_upper_rim_height = float(m_pillar_settings["upper_rim_height"])
	coordinator.default_pillar_upper_rim_outset = float(m_pillar_settings["upper_rim_outset"])
	coordinator.default_pillar_color = Color(m_pillar_settings["color"])


func _apply_roof_settings_to_coordinator(coordinator: BuildingEditor3DScript) -> void:
	coordinator.grid_step = float(m_roof_settings["grid_step"])
	coordinator.default_roof_style = String(m_roof_settings["style"])
	coordinator.default_roof_height = float(m_roof_settings["height"])
	coordinator.default_roof_thickness = float(m_roof_settings["thickness"])
	coordinator.default_roof_overhang = float(m_roof_settings["overhang"])
	coordinator.default_roof_hip_gable_height = float(m_roof_settings.get("hip_gable_height", 0.0))
	coordinator.default_roof_rotation_degrees = float(m_roof_settings.get("rotation_degrees", 0.0))
	coordinator.default_roof_color = Color(m_roof_settings["color"])
	coordinator.default_roof_debug_wireframe = bool(m_roof_settings.get("debug_wireframe", false))


func _active_grid_step(wall: Wall3DScript) -> float:
	var coordinator := _find_coordinator_from_node(wall)
	if coordinator != null:
		return maxf(coordinator.grid_step, 0.05)
	return maxf(float(m_wall_settings["grid_step"]), 0.05)


func _apply_wall_geometry(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegment3DScript],
	opening_anchors: Array = []
) -> void:
	wall.set_wall_geometry(new_start, new_end, _duplicate_segments(segments), opening_anchors)


func _refresh_wall_intersections(coordinator: BuildingEditor3DScript) -> void:
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_wall_intersection_clips()


func _set_wall_endpoints_and_refresh_intersections(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	coordinator: BuildingEditor3DScript
) -> void:
	if wall == null or !is_instance_valid(wall):
		return
	wall.set_wall_endpoints(new_start, new_end)
	_refresh_wall_intersections(coordinator)


func _do_set_wall_geometry(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegment3DScript],
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
	segments: Array[WallSegment3DScript],
	select_after: bool,
	coordinator: BuildingEditor3DScript
) -> void:
	_do_set_wall_geometry(wall, new_start, new_end, segments, select_after)
	_refresh_wall_intersections(coordinator)


func _do_set_wall_geometry_preserving_children(
	wall: Wall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegment3DScript],
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
	segments: Array[WallSegment3DScript],
	select_after: bool,
	coordinator: BuildingEditor3DScript
) -> void:
	_do_set_wall_geometry_preserving_children(wall, new_start, new_end, segments, select_after)
	_refresh_wall_intersections(coordinator)


func _duplicate_segments(segments: Array) -> Array[WallSegment3DScript]:
	var copies: Array[WallSegment3DScript] = []
	for segment in segments:
		var typed_segment := segment as WallSegment3DScript
		if typed_segment == null:
			continue
		copies.append(typed_segment.duplicate() as WallSegment3DScript)
	return copies


func _duplicate_wall_segments(wall: Wall3DScript) -> Array[WallSegment3DScript]:
	var segments: Array[WallSegment3DScript] = []
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment == null:
			continue
		segments.append(segment.duplicate() as WallSegment3DScript)
	return segments


func _normalized_wall_geometry(wall: Wall3DScript) -> Dictionary:
	var coordinator := _find_coordinator_from_node(wall)
	var tolerance := maxf(_active_grid_step(wall) * 0.25, 0.03)
	if coordinator != null:
		tolerance = maxf(coordinator.grid_step * 0.25, 0.03)
	var combined: Array[WallSegment3DScript] = []
	for segment in _duplicate_wall_segments(wall):
		WallSegment3DScript.merge_into(combined, segment, tolerance, false)
	var split_segments := WallSegment3DScript.split_at_intersections(combined, tolerance)
	return _wall_geometry_from_segments(split_segments)


func _wall_geometry_from_segments(segments: Array) -> Dictionary:
	if segments.is_empty():
		return {}
	var primary := segments[0] as WallSegment3DScript
	if primary == null:
		return {}
	var extras: Array[WallSegment3DScript] = []
	for segment_index in range(1, segments.size()):
		var segment := segments[segment_index] as WallSegment3DScript
		if segment == null:
			continue
		extras.append(segment.duplicate() as WallSegment3DScript)
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
	var remaining: Array[WallSegment3DScript] = []
	var zero_epsilon := _wall_segment_zero_epsilon(wall)
	for segment_index in range(wall.get_segment_count()):
		if segment_index == removed_segment_index:
			continue
		var segment := wall.get_segment(segment_index).duplicate() as WallSegment3DScript
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
		hit_parent_local = coordinator.snap_local_position(hit_parent_local)
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
	var old_segments: Array[WallSegment3DScript] = old_geometry["segments"]
	var new_segments: Array[WallSegment3DScript] = geometry["segments"]
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
	old_segments: Array[WallSegment3DScript]
) -> void:
	var next_segments: Array[WallSegment3DScript] = geometry["segments"]
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
	old_segments: Array[WallSegment3DScript]
) -> void:
	var parent := wall.get_parent()
	var coordinator := parent as BuildingEditor3DScript
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
	coordinator: BuildingEditor3DScript,
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
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null:
		return coordinator.snap_world_position(world_position)
	var step := maxf(float(m_wall_settings["grid_step"]), 0.05)
	return Vector3(
		roundf(world_position.x / step) * step,
		roundf(world_position.y / step) * step,
		roundf(world_position.z / step) * step
	)


func _set_preview_parent(preview: Node3D, parent: Node) -> void:
	if preview.get_parent() == parent:
		m_preview_parent = parent
		return
	if preview.get_parent() != null:
		preview.get_parent().remove_child(preview)
	parent.add_child(preview)
	preview.owner = null
	m_preview_parent = parent


func _apply_preview_material(node: Node, color: Color) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.material_override = _build_preview_material(color)
	for child in node.get_children():
		_apply_preview_material(child, color)


func _build_preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


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


func _update_stair_hover(stair: Stairs3DScript, edit_mask: int) -> void:
	if stair == m_drag_stair_hover and edit_mask == m_drag_stair_hover_edit_mask:
		return
	_clear_stair_hover()
	if stair == null:
		return
	m_drag_stair_hover = stair
	m_drag_stair_hover_edit_mask = edit_mask
	m_drag_stair_hover_material = stair.material_override
	stair.material_override = _build_preview_material(_stair_drag_color(edit_mask, true))


func _clear_stair_hover() -> void:
	if m_drag_stair_hover == null:
		return
	if is_instance_valid(m_drag_stair_hover):
		m_drag_stair_hover.material_override = m_drag_stair_hover_material
	m_drag_stair_hover = null
	m_drag_stair_hover_material = null
	m_drag_stair_hover_edit_mask = FLOOR_EDIT_MOVE


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


func _update_pillar_hover(pillar: Pillar3DScript, edit_mode: int) -> void:
	if pillar == m_drag_pillar_hover and edit_mode == m_drag_pillar_hover_edit_mode:
		return
	_clear_pillar_hover()
	if pillar == null:
		return
	m_drag_pillar_hover = pillar
	m_drag_pillar_hover_edit_mode = edit_mode
	m_drag_pillar_hover_material = pillar.material_override
	pillar.material_override = _build_preview_material(_pillar_drag_color(edit_mode, true))


func _clear_pillar_hover() -> void:
	if m_drag_pillar_hover == null:
		return
	if is_instance_valid(m_drag_pillar_hover):
		m_drag_pillar_hover.material_override = m_drag_pillar_hover_material
	m_drag_pillar_hover = null
	m_drag_pillar_hover_material = null
	m_drag_pillar_hover_edit_mode = PILLAR_EDIT_MOVE


func _clear_wall_preview() -> void:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		m_wall_preview.queue_free()
	m_wall_preview = null


func _clear_floor_preview() -> void:
	if m_floor_preview != null and is_instance_valid(m_floor_preview):
		m_floor_preview.queue_free()
	m_floor_preview = null


func _clear_stair_preview() -> void:
	if m_stair_preview != null and is_instance_valid(m_stair_preview):
		m_stair_preview.queue_free()
	m_stair_preview = null


func _clear_pillar_preview() -> void:
	if m_pillar_preview != null and is_instance_valid(m_pillar_preview):
		m_pillar_preview.queue_free()
	m_pillar_preview = null
	m_pillar_preview_valid = false


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


func _reset_stair_drawing_state() -> void:
	m_is_drawing_stair = false
	m_stair_has_valid_preview = false
	m_stair_release_commits_preview = false
	m_stair_start_screen_position = Vector2.ZERO
	m_stair_draw_rotation_degrees = _normalize_degrees(float(m_stair_settings.get("rotation_degrees", 0.0)))


func _reset_roof_drawing_state() -> void:
	m_is_drawing_roof = false
	m_roof_has_valid_preview = false
	m_roof_release_commits_preview = false
	m_roof_start_screen_position = Vector2.ZERO
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
	segment: WallSegment3DScript,
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
	var new_segments: Array[WallSegment3DScript] = new_geometry["segments"]
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
	if coordinator != null and coordinator.merge_intersecting:
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
	if is_instance_valid(m_dragging_wall):
		_apply_wall_geometry(
			m_dragging_wall,
			m_drag_wall_old_start,
			m_drag_wall_old_end,
			m_drag_wall_old_segments,
			m_drag_wall_opening_anchors
		)
		m_dragging_wall.material_override = m_drag_wall_active_material
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
		m_dragging_opening.transform = Transform3D(frame.basis, frame * center_local)
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
		m_dragging_opening.transform = Transform3D(frame.basis, frame * local_hit)
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
	opening.frame_color = Color(0.86, 0.92, 0.94, 1.0)
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
		m_dragging_opening.frame_color = Color(0.86, 0.92, 0.94, 1.0)
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
		overlay.move_to_front()
		m_viewport_overlays.append(overlay)


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


func _cancel_active_preview() -> void:
	_cancel_wall_drag()
	_clear_wall_hover()
	_cancel_floor_drag()
	_clear_floor_hover()
	_cancel_stair_drag()
	_clear_stair_hover()
	_cancel_pillar_drag()
	_clear_pillar_hover()
	_cancel_roof_drag()
	_clear_roof_hover()
	_cancel_window_drag()
	_clear_drag_hover()
	_clear_wall_preview()
	_clear_floor_preview()
	_clear_stair_preview()
	_clear_pillar_preview()
	_clear_roof_preview()
	_clear_prop_preview()
	_reset_wall_drawing_state()
	_reset_floor_drawing_state()
	_reset_stair_drawing_state()
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


func _wall_draw_label() -> String:
	return "Room" if _is_room_wall_mode() else "Wall"


func _is_floor_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_floor_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _is_stair_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_stair_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _is_roof_span_large_enough(local_start: Vector3, local_end: Vector3) -> bool:
	var minimum_size := maxf(float(m_roof_settings["grid_step"]) * 0.5, 0.1)
	return (
		absf(local_end.x - local_start.x) >= minimum_size
		and absf(local_end.z - local_start.z) >= minimum_size
	)


func _do_add_node(parent: Node, node: Node, scene_root: Node, select_after_add: bool) -> void:
	if node.get_parent() != parent:
		parent.add_child(node)
	_set_owner_recursive(node, scene_root)
	if select_after_add:
		_select_node(node)


func _do_add_node_and_rebuild(parent: Node, node: Node, scene_root: Node, select_after_add: bool) -> void:
	_do_add_node(parent, node, scene_root, select_after_add)
	if parent.has_method("rebuild_wall_mesh"):
		parent.rebuild_wall_mesh()


func _do_add_node_and_refresh_wall_intersections(
	parent: Node,
	node: Node,
	scene_root: Node,
	select_after_add: bool,
	coordinator: BuildingEditor3DScript
) -> void:
	_do_add_node(parent, node, scene_root, select_after_add)
	_refresh_wall_intersections(coordinator)


func _do_add_node_and_refresh_roofs(
	parent: Node,
	node: Node,
	scene_root: Node,
	select_after_add: bool,
	coordinator: BuildingEditor3DScript
) -> void:
	_do_add_node(parent, node, scene_root, select_after_add)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_roof_covered_rects()


func _undo_remove_node(parent: Node, node: Node) -> void:
	if node.get_parent() == parent:
		parent.remove_child(node)


func _undo_remove_node_and_rebuild(parent: Node, node: Node) -> void:
	_undo_remove_node(parent, node)
	if parent.has_method("rebuild_wall_mesh"):
		parent.rebuild_wall_mesh()


func _undo_remove_node_and_refresh_wall_intersections(
	parent: Node,
	node: Node,
	coordinator: BuildingEditor3DScript
) -> void:
	_undo_remove_node(parent, node)
	_refresh_wall_intersections(coordinator)


func _undo_remove_node_and_refresh_roofs(parent: Node, node: Node, coordinator: BuildingEditor3DScript) -> void:
	_undo_remove_node(parent, node)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_roof_covered_rects()


func _set_roof_state_and_refresh(
	roof: Roof3DScript,
	new_start: Vector3,
	new_end: Vector3,
	new_rotation: float,
	new_height: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array],
	coordinator: BuildingEditor3DScript
) -> void:
	if roof == null or !is_instance_valid(roof):
		return
	roof.set_roof_corners_rotation_height_and_covers(
		new_start,
		new_end,
		new_rotation,
		new_height,
		new_covered_rects,
		new_covered_polygons
	)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_roof_covered_rects()


func _roof_layout_would_hide_any_roof(
	coordinator: BuildingEditor3DScript,
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
			"rotation": roof_node.roof_rotation_degrees,
			"height": roof_node.roof_height,
			"covered_rects": roof_node.get_covered_rects(),
			"covered_polygons": roof_node.get_covered_polygons(),
		})

	roof.set_roof_corners_rotation_height_and_covers(
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
		snapshot_roof.set_roof_corners_rotation_height_and_covers(
			Vector3(snapshot["start"]),
			Vector3(snapshot["end"]),
			float(snapshot["rotation"]),
			float(snapshot["height"]),
			snapshot_covers,
			snapshot_polygons
		)
	return hides_roof


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if (
		node.has_meta(Wall3DScript.GENERATED_META)
		or node.has_meta(Floor3DScript.GENERATED_META)
		or node.has_meta(Stairs3DScript.GENERATED_META)
		or node.has_meta(Pillar3DScript.GENERATED_META)
		or node.has_meta(Roof3DScript.GENERATED_META)
		or node.has_meta(BuildingOpening3DScript.GENERATED_META)
	):
		node.owner = null
	else:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)


func _select_node(node: Node) -> void:
	var selection := get_editor_interface().get_selection()
	selection.clear()
	selection.add_node(node)
	get_editor_interface().edit_node(node)


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
	if node is Pillar3DScript:
		return MODE_PILLAR
	if node is Roof3DScript:
		return MODE_ROOF
	if node is BuildingOpening3DScript:
		return _tool_mode_for_opening_node(node as BuildingOpening3DScript)
	return ""


func _tool_mode_for_opening_node(opening: BuildingOpening3DScript) -> String:
	if opening == null:
		return ""
	if opening.door_panel_count > 0:
		return MODE_DOOR
	if !opening.show_bottom_frame:
		return MODE_DOOR
	if opening.has_meta(OPENING_ALLOW_BASE_META) and bool(opening.get_meta(OPENING_ALLOW_BASE_META)):
		return MODE_DOOR
	return MODE_WINDOW


func _build_viewport_toolbar() -> void:
	if m_viewport_toolbar != null:
		return
	m_viewport_toolbar = HBoxContainer.new()
	m_viewport_toolbar.name = "LowPolyBuildingEditorToolbar"
	m_viewport_toolbar.mouse_filter = Control.MOUSE_FILTER_PASS

	m_toolbar_buttons.clear()
	for tool_info in TOOLBAR_TOOLS:
		var mode := String(tool_info["mode"])
		var label := String(tool_info["label"])
		var button := Button.new()
		button.name = "LowPolyBuildingEditor%sButton" % label
		button.toggle_mode = true
		button.icon = _get_toolbar_tool_icon(tool_info)
		button.tooltip_text = "%s: %s" % [label, String(tool_info["tooltip"])]
		button.focus_mode = Control.FOCUS_NONE
		_apply_toolbar_button_style(button)
		button.set_pressed_no_signal(mode == m_tool_mode)
		button.pressed.connect(_on_toolbar_tool_selected.bind(mode))
		m_viewport_toolbar.add_child(button)
		m_toolbar_buttons[mode] = button

	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, m_viewport_toolbar)
	# Defer so the control is reparented into the spatial editor menu bar before
	# we look up the native Transform/Move/Rotate/Scale/Select buttons beside it.
	_collect_native_tool_buttons.call_deferred()
	set_process(true)
	set_process_input(true)


func _clear_viewport_toolbar() -> void:
	_release_native_tool_buttons()
	if m_viewport_toolbar == null:
		return
	set_process(false)
	set_process_input(false)
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, m_viewport_toolbar)
	m_viewport_toolbar.queue_free()
	m_viewport_toolbar = null
	m_toolbar_buttons.clear()


func _process(_delta: float) -> void:
	if m_tool_mode != MODE_SELECT:
		_clear_native_tool_button_highlights()


func _input(event: InputEvent) -> void:
	if m_tool_mode == MODE_SELECT:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if (
			mouse_button.button_index == MOUSE_BUTTON_LEFT
			and mouse_button.pressed
			and _event_hits_native_select_button(mouse_button)
		):
			_on_native_tool_button_chosen(_get_native_select_button())


func _on_toolbar_tool_selected(mode: String) -> void:
	_select_tool_mode(mode)


func _select_tool_mode(mode: String) -> void:
	if mode.is_empty():
		return
	# Route through the dock so its option button, shortcuts, and visible tool
	# section stay in sync; the dock re-emits tool_mode_changed back to us.
	if m_dock != null and m_dock.has_method("select_tool_mode"):
		m_dock.call("select_tool_mode", mode)
	else:
		_on_tool_mode_changed(mode)


func _sync_toolbar_tool_mode(mode: String) -> void:
	# Setting button_pressed without a signal keeps the building buttons a radio
	# set without looping back through "pressed".
	for tool_mode in m_toolbar_buttons:
		var button: Button = m_toolbar_buttons[tool_mode]
		if button != null:
			button.set_pressed_no_signal(tool_mode == mode)
	_sync_native_tool_buttons(mode)


func _collect_native_tool_buttons() -> void:
	# Find the native Transform/Move/Rotate/Scale/Select mode buttons so the
	# building tools can stay mutually exclusive with them. Godot's toolbar
	# layout can move, so match each native button by icon name first, then by
	# its tooltip text, then by its native shortcut.
	_release_native_tool_buttons()
	if m_viewport_toolbar == null:
		return
	var found := _find_native_mode_buttons_from_node_3d_editor()
	m_native_select_button = found.get(NATIVE_MODE_SELECT) as Button
	var native_reference := found.get(NATIVE_MODE_MOVE) as Button
	_apply_native_toolbar_box_layout(native_reference)
	_apply_native_toolbar_icon_size(native_reference)
	_apply_native_toolbar_button_style(native_reference)
	for native_button in _native_button_values(found):
		if m_native_tool_buttons.has(native_button):
			continue
		m_native_tool_buttons.append(native_button)
		var native_pressed := Callable(self, "_on_native_tool_button_chosen").bind(native_button)
		var native_gui_input := Callable(self, "_on_native_tool_button_gui_input").bind(native_button)
		if not native_button.pressed.is_connected(native_pressed):
			native_button.pressed.connect(native_pressed)
		if not native_button.button_down.is_connected(native_pressed):
			native_button.button_down.connect(native_pressed)
		if not native_button.gui_input.is_connected(native_gui_input):
			native_button.gui_input.connect(native_gui_input)
	if DEBUG_NATIVE_BUTTONS:
		_dump_native_button_debug()
	if m_native_tool_buttons.is_empty():
		push_warning("Low-Poly Building Editor: could not locate the native 3D viewport mode buttons; building-tool exclusivity is disabled.")
		return
	_update_native_active_button()
	_sync_native_tool_buttons(m_tool_mode)


func _apply_native_toolbar_box_layout(reference_button: Button) -> void:
	if m_viewport_toolbar == null or reference_button == null or !is_instance_valid(reference_button):
		return
	var native_toolbar_parent := _find_toolbar_box_parent(reference_button)
	if native_toolbar_parent == null:
		return
	m_viewport_toolbar.theme = native_toolbar_parent.theme
	m_viewport_toolbar.theme_type_variation = native_toolbar_parent.theme_type_variation
	m_viewport_toolbar.add_theme_constant_override(
		"separation",
		native_toolbar_parent.get_theme_constant("separation")
	)


func _find_toolbar_box_parent(button: Button) -> HBoxContainer:
	var node := button.get_parent()
	while node != null:
		if node is HBoxContainer:
			return node as HBoxContainer
		node = node.get_parent()
	return null


func _apply_native_toolbar_button_style(reference_button: Button) -> void:
	for tool_mode in m_toolbar_buttons:
		_apply_toolbar_button_style(m_toolbar_buttons[tool_mode], reference_button)


func _apply_native_toolbar_icon_size(reference_button: Button) -> void:
	if reference_button == null or !is_instance_valid(reference_button):
		return
	var native_icon_size := _get_native_toolbar_icon_size(reference_button)
	if native_icon_size == m_toolbar_icon_size:
		return
	m_toolbar_icon_size = native_icon_size
	m_toolbar_icon_cache.clear()
	for tool_mode in m_toolbar_buttons:
		var button := m_toolbar_buttons[tool_mode] as Button
		if button != null and is_instance_valid(button):
			button.icon = _make_toolbar_tool_icon(String(tool_mode))


func _get_native_toolbar_icon_size(reference_button: Button) -> Vector2i:
	if reference_button.icon != null:
		var icon_size := reference_button.icon.get_size()
		if icon_size.x > 0.0 and icon_size.y > 0.0:
			return Vector2i(roundi(icon_size.x), roundi(icon_size.y))
	if reference_button.has_theme_constant(&"icon_max_width"):
		var icon_max_width := reference_button.get_theme_constant(&"icon_max_width")
		if icon_max_width > 0:
			return Vector2i(icon_max_width, icon_max_width)
	return TOOLBAR_FALLBACK_ICON_SIZE


func _apply_toolbar_button_style(button: Button, reference_button: Button = null) -> void:
	if button == null:
		return
	button.theme_type_variation = &"ToolButton"
	button.custom_minimum_size = TOOLBAR_BUTTON_MINIMUM_SIZE
	button.flat = false
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if reference_button == null or !is_instance_valid(reference_button):
		return
	button.theme = reference_button.theme
	button.theme_type_variation = reference_button.theme_type_variation
	button.custom_minimum_size = _get_native_toolbar_button_size(reference_button)
	button.flat = reference_button.flat
	button.alignment = reference_button.alignment
	button.icon_alignment = reference_button.icon_alignment
	button.vertical_icon_alignment = reference_button.vertical_icon_alignment
	button.expand_icon = reference_button.expand_icon
	_copy_button_theme_items(reference_button, button)


func _get_native_toolbar_button_size(reference_button: Button) -> Vector2:
	if reference_button.custom_minimum_size.x > 0.0 and reference_button.custom_minimum_size.y > 0.0:
		return reference_button.custom_minimum_size
	if reference_button.size.x > 0.0 and reference_button.size.y > 0.0:
		return reference_button.size
	var combined_minimum := reference_button.get_combined_minimum_size()
	if combined_minimum.x > 0.0 and combined_minimum.y > 0.0:
		return combined_minimum
	return TOOLBAR_BUTTON_MINIMUM_SIZE


func _copy_button_theme_items(source: Button, target: Button) -> void:
	for item in BUTTON_STYLEBOX_THEME_ITEMS:
		if source.has_theme_stylebox(item):
			target.add_theme_stylebox_override(item, source.get_theme_stylebox(item))
	for item in BUTTON_COLOR_THEME_ITEMS:
		if source.has_theme_color(item):
			target.add_theme_color_override(item, source.get_theme_color(item))
	for item in BUTTON_CONSTANT_THEME_ITEMS:
		if source.has_theme_constant(item):
			target.add_theme_constant_override(item, source.get_theme_constant(item))
	for item in BUTTON_FONT_THEME_ITEMS:
		if source.has_theme_font(item):
			target.add_theme_font_override(item, source.get_theme_font(item))
	for item in BUTTON_FONT_SIZE_THEME_ITEMS:
		if source.has_theme_font_size(item):
			target.add_theme_font_size_override(item, source.get_theme_font_size(item))


func _find_native_mode_buttons_from_node_3d_editor() -> Dictionary:
	var editor_base := get_editor_interface().get_base_control()
	if editor_base == null:
		return {}
	var node_3d_editors := _find_nodes_by_class_name(editor_base, "Node3DEditor")
	for node in node_3d_editors:
		var native_buttons := _find_native_mode_buttons_in_node_3d_editor_node(node)
		if _native_button_map_is_complete(native_buttons):
			return native_buttons
	return {}


func _find_native_mode_buttons_in_node_3d_editor_node(root: Node) -> Dictionary:
	var buttons := _find_buttons(root)
	var native_buttons := {}
	native_buttons[NATIVE_MODE_TRANSFORM] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_TRANSFORM, NATIVE_ICON_TRANSFORM_ALTERNATE],
		NATIVE_TIPS_TRANSFORM,
		NATIVE_SHORTCUT_TRANSFORM
	)
	native_buttons[NATIVE_MODE_MOVE] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_MOVE],
		NATIVE_TIPS_MOVE,
		NATIVE_SHORTCUT_MOVE
	)
	native_buttons[NATIVE_MODE_ROTATE] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_ROTATE],
		NATIVE_TIPS_ROTATE,
		NATIVE_SHORTCUT_ROTATE
	)
	native_buttons[NATIVE_MODE_SCALE] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_SCALE],
		NATIVE_TIPS_SCALE,
		NATIVE_SHORTCUT_SCALE
	)
	native_buttons[NATIVE_MODE_SELECT] = _find_button_by_icon_tip_or_shortcut(
		buttons,
		[NATIVE_ICON_SELECT],
		NATIVE_TIPS_SELECT,
		NATIVE_SHORTCUT_SELECT
	)
	if !_native_button_map_is_complete(native_buttons):
		return {}
	if !_native_buttons_are_unique(_native_button_values(native_buttons)):
		return {}
	return native_buttons


func _find_button_by_icon_tip_or_shortcut(
	buttons: Array[Button],
	icon_names: Array[StringName],
	tip_patterns: Array,
	shortcut_key: int
) -> Button:
	var icon_button := _find_button_with_icon_names(buttons, icon_names)
	if icon_button != null:
		return icon_button
	var tip_button := _find_button_with_tip_text(buttons, tip_patterns)
	if tip_button != null:
		return tip_button
	return _find_button_with_shortcut_key(buttons, shortcut_key)


func _find_button_with_icon_names(buttons: Array[Button], icon_names: Array[StringName]) -> Button:
	for icon_name in icon_names:
		var button := _find_button_with_icon_name(buttons, icon_name)
		if button != null:
			return button
	return null


func _find_button_with_icon_name(buttons: Array[Button], icon_name: StringName) -> Button:
	for button in buttons:
		if button != null and is_instance_valid(button) and _button_has_icon_name(button, icon_name):
			return button
	return null


func _find_button_with_tip_text(buttons: Array[Button], tip_patterns: Array) -> Button:
	for button in buttons:
		if button != null and is_instance_valid(button) and _button_tip_contains_any(button, tip_patterns):
			return button
	return null


func _find_button_with_shortcut_key(buttons: Array[Button], shortcut_key: int) -> Button:
	for button in buttons:
		if (
			button != null
			and is_instance_valid(button)
			and button.toggle_mode
			and _button_has_unmodified_shortcut_key(button, shortcut_key)
		):
			return button
	return null


func _native_button_map_is_complete(native_buttons: Dictionary) -> bool:
	for mode in [
		NATIVE_MODE_TRANSFORM,
		NATIVE_MODE_MOVE,
		NATIVE_MODE_ROTATE,
		NATIVE_MODE_SCALE,
		NATIVE_MODE_SELECT,
	]:
		if !native_buttons.has(mode):
			return false
		var button := native_buttons[mode] as Button
		if button == null or !is_instance_valid(button):
			return false
	return true


func _native_button_values(native_buttons: Dictionary) -> Array[Button]:
	var buttons: Array[Button] = []
	for mode in native_buttons:
		var button := native_buttons[mode] as Button
		if button != null and is_instance_valid(button):
			buttons.append(button)
	return buttons


func _native_buttons_are_unique(buttons: Array[Button]) -> bool:
	for i in range(buttons.size()):
		for j in range(i + 1, buttons.size()):
			if buttons[i] == buttons[j]:
				return false
	return true


func _button_has_icon_name(button: Button, icon_name: StringName) -> bool:
	if button.icon == null:
		return false
	var expected_icon := _get_editor_icon(icon_name)
	if expected_icon != null and button.icon == expected_icon:
		return true
	var icon_name_text := String(icon_name).to_lower()
	var icon_resource_name := String(button.icon.resource_name).to_lower()
	var icon_resource_path := button.icon.resource_path.to_lower()
	return icon_resource_name.contains(icon_name_text) or icon_resource_path.contains(icon_name_text)


func _find_nodes_by_class_name(node: Node, class_name_text: String) -> Array[Node]:
	var results: Array[Node] = []
	if node.is_class(class_name_text):
		results.append(node)
	for child in node.get_children():
		results.append_array(_find_nodes_by_class_name(child, class_name_text))
	return results


func _find_buttons(root: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	if root is Button:
		buttons.append(root as Button)
	for child in root.get_children():
		buttons.append_array(_find_buttons(child))
	return buttons


func _is_native_select_button(button: Button) -> bool:
	if _button_has_icon_name(button, NATIVE_ICON_SELECT):
		return true
	if _button_tip_contains_any(button, NATIVE_TIPS_SELECT):
		return true
	return _button_has_unmodified_shortcut_key(button, NATIVE_SHORTCUT_SELECT)


func _find_native_select_button(buttons: Array[Button]) -> Button:
	for button in buttons:
		if button != null and is_instance_valid(button) and _is_native_select_button(button):
			return button
	return null


func _button_tip_contains_any(button: Button, tip_patterns: Array) -> bool:
	if button == null or !button.toggle_mode:
		return false
	var tip_text := "%s\n%s" % [button.tooltip_text, button.get_tooltip(Vector2.ZERO)]
	var tip_lower := tip_text.to_lower()
	for pattern in tip_patterns:
		var pattern_text := String(pattern).to_lower()
		if !pattern_text.is_empty() and tip_lower.contains(pattern_text):
			return true
	return false


func _button_has_unmodified_shortcut_key(button: Button, shortcut_key: int) -> bool:
	if button == null:
		return false
	var shortcut := button.shortcut
	if shortcut == null:
		return false
	for event in shortcut.events:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.shift_pressed or key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
				continue
			if key_event.keycode == shortcut_key or key_event.physical_keycode == shortcut_key:
				return true
	return false


func _dump_native_button_debug() -> void:
	var lines := PackedStringArray()
	lines.append("toolbar parent: %s" % str(null if m_viewport_toolbar == null else m_viewport_toolbar.get_parent()))
	lines.append("matched native buttons: %d" % m_native_tool_buttons.size())
	for matched in m_native_tool_buttons:
		lines.append("  MATCH tip='%s' shortcut='%s' icon='%s' pressed=%s" % [
			matched.get_tooltip(Vector2.ZERO),
			"" if matched.shortcut == null else matched.shortcut.get_as_text(),
			_button_icon_debug_text(matched),
			str(matched.button_pressed),
		])
	var ancestor: Node = null if m_viewport_toolbar == null else m_viewport_toolbar.get_parent()
	for i in range(3):
		if ancestor == null:
			break
		lines.append("=== ancestor[%d]: %s (%s) ===" % [i, ancestor.name, ancestor.get_class()])
		_dump_node_tree(ancestor, 0, lines)
		ancestor = ancestor.get_parent()
	var file := FileAccess.open("res://addons/low_poly_building_editor/native_buttons_debug.log", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _dump_node_tree(node: Node, depth: int, lines: PackedStringArray) -> void:
	if depth > 4:
		return
	for child in node.get_children():
		var info := "  ".repeat(depth + 1) + "%s [%s]" % [child.name, child.get_class()]
		if child is Button:
			var btn := child as Button
			info += " toggle=%s pressed=%s text='%s' tip='%s' shortcut='%s' icon='%s'" % [
				str(btn.toggle_mode),
				str(btn.button_pressed),
				btn.text,
				btn.get_tooltip(Vector2.ZERO),
				"" if btn.shortcut == null else btn.shortcut.get_as_text(),
				_button_icon_debug_text(btn),
			]
		lines.append(info)
		_dump_node_tree(child, depth + 1, lines)


func _button_icon_debug_text(button: Button) -> String:
	if button == null or button.icon == null:
		return ""
	return "%s|%s" % [String(button.icon.resource_name), button.icon.resource_path]


func _release_native_tool_buttons() -> void:
	for native_button in m_native_tool_buttons:
		if native_button != null and is_instance_valid(native_button):
			var native_pressed := Callable(self, "_on_native_tool_button_chosen").bind(native_button)
			var native_gui_input := Callable(self, "_on_native_tool_button_gui_input").bind(native_button)
			if native_button.pressed.is_connected(native_pressed):
				native_button.pressed.disconnect(native_pressed)
			if native_button.button_down.is_connected(native_pressed):
				native_button.button_down.disconnect(native_pressed)
			if native_button.gui_input.is_connected(native_gui_input):
				native_button.gui_input.disconnect(native_gui_input)
	m_native_tool_buttons.clear()
	m_native_select_button = null
	m_native_active_button = null


func _on_native_tool_button_gui_input(event: InputEvent, native_button: Button) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_on_native_tool_button_chosen(native_button)


func _on_native_tool_button_chosen(native_button: Button) -> void:
	# A native viewport selection mode was chosen; deactivate any building tool
	# so the two button sets stay mutually exclusive.
	if native_button != null and is_instance_valid(native_button):
		m_native_active_button = native_button
	else:
		_update_native_active_button()
	if m_tool_mode == MODE_SELECT:
		return
	m_handling_native_click = true
	if m_dock != null and m_dock.has_method("select_tool_mode"):
		m_dock.call("select_tool_mode", MODE_SELECT)
	else:
		_on_tool_mode_changed(MODE_SELECT)
	m_handling_native_click = false


func _update_native_active_button() -> void:
	for native_button in m_native_tool_buttons:
		if native_button != null and is_instance_valid(native_button) and native_button.button_pressed:
			m_native_active_button = native_button
			return


func _sync_native_tool_buttons(mode: String) -> void:
	if m_native_tool_buttons.is_empty():
		return
	if mode == MODE_SELECT:
		# A native click already reflects the user's choice; only restore the
		# native highlight when a building tool is cleared from our own UI.
		if m_handling_native_click:
			return
		var select_button := _get_native_select_button()
		if select_button != null:
			_clear_native_tool_button_highlights()
			select_button.set_pressed_no_signal(true)
			m_native_active_button = select_button
		elif m_native_active_button != null and is_instance_valid(m_native_active_button):
			m_native_active_button.set_pressed_no_signal(true)
	else:
		_queue_native_tool_button_highlight_clear()


func _get_native_select_button() -> Button:
	if m_native_select_button != null and is_instance_valid(m_native_select_button):
		return m_native_select_button
	m_native_select_button = _find_native_select_button(m_native_tool_buttons)
	return m_native_select_button


func _event_hits_native_select_button(mouse_button: InputEventMouseButton) -> bool:
	var select_button := _get_native_select_button()
	if select_button == null or !select_button.is_visible_in_tree():
		return false
	return select_button.get_global_rect().has_point(mouse_button.position)


func _queue_native_tool_button_highlight_clear() -> void:
	_clear_native_tool_button_highlights()
	call_deferred("_clear_native_tool_button_highlights_if_building_tool_active")
	if is_inside_tree():
		var timer := get_tree().create_timer(0.05)
		timer.timeout.connect(_clear_native_tool_button_highlights_if_building_tool_active)


func _clear_native_tool_button_highlights_if_building_tool_active() -> void:
	if m_tool_mode != MODE_SELECT:
		_clear_native_tool_button_highlights()


func _clear_native_tool_button_highlights() -> void:
	for native_button in m_native_tool_buttons:
		if native_button != null and is_instance_valid(native_button):
			native_button.set_pressed_no_signal(false)


func _get_toolbar_tool_icon(tool_info: Dictionary) -> Texture2D:
	if bool(tool_info.get("generated_icon", false)):
		return _make_toolbar_tool_icon(String(tool_info.get("mode", "")))
	var icon_names: Array = tool_info.get("icons", [])
	for icon_name in icon_names:
		var icon := _get_editor_icon(StringName(icon_name), false)
		if icon != null:
			return icon
	return _make_toolbar_tool_icon(String(tool_info.get("mode", "")))


func _make_toolbar_tool_icon(mode: String) -> Texture2D:
	if m_toolbar_icon_cache.has(mode):
		return m_toolbar_icon_cache[mode]
	var image := Image.create(
		TOOLBAR_FALLBACK_ICON_SIZE.x,
		TOOLBAR_FALLBACK_ICON_SIZE.y,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var color := Color.WHITE
	match mode:
		MODE_WALL:
			_draw_icon_rect_outline(image, Rect2i(3, 7, 18, 12), color, 2)
			_draw_icon_line(image, Vector2i(4, 11), Vector2i(20, 11), color, 1)
			_draw_icon_line(image, Vector2i(4, 15), Vector2i(20, 15), color, 1)
			_draw_icon_line(image, Vector2i(9, 8), Vector2i(9, 10), color, 1)
			_draw_icon_line(image, Vector2i(15, 8), Vector2i(15, 10), color, 1)
			_draw_icon_line(image, Vector2i(6, 12), Vector2i(6, 14), color, 1)
			_draw_icon_line(image, Vector2i(12, 12), Vector2i(12, 14), color, 1)
			_draw_icon_line(image, Vector2i(18, 12), Vector2i(18, 14), color, 1)
			_draw_icon_line(image, Vector2i(9, 16), Vector2i(9, 18), color, 1)
			_draw_icon_line(image, Vector2i(15, 16), Vector2i(15, 18), color, 1)
		MODE_FLOOR:
			_draw_icon_line(image, Vector2i(12, 4), Vector2i(21, 10), color, 2)
			_draw_icon_line(image, Vector2i(21, 10), Vector2i(12, 17), color, 2)
			_draw_icon_line(image, Vector2i(12, 17), Vector2i(3, 10), color, 2)
			_draw_icon_line(image, Vector2i(3, 10), Vector2i(12, 4), color, 2)
			_draw_icon_line(image, Vector2i(3, 10), Vector2i(21, 10), color, 1)
			_draw_icon_line(image, Vector2i(12, 4), Vector2i(12, 17), color, 1)
		MODE_STAIRS:
			_draw_icon_line(image, Vector2i(4, 18), Vector2i(8, 18), color, 2)
			_draw_icon_line(image, Vector2i(8, 18), Vector2i(8, 14), color, 2)
			_draw_icon_line(image, Vector2i(8, 14), Vector2i(12, 14), color, 2)
			_draw_icon_line(image, Vector2i(12, 14), Vector2i(12, 10), color, 2)
			_draw_icon_line(image, Vector2i(12, 10), Vector2i(16, 10), color, 2)
			_draw_icon_line(image, Vector2i(16, 10), Vector2i(16, 6), color, 2)
			_draw_icon_line(image, Vector2i(16, 6), Vector2i(20, 6), color, 2)
			_draw_icon_line(image, Vector2i(4, 20), Vector2i(20, 20), color, 1)
			_draw_icon_line(image, Vector2i(20, 6), Vector2i(20, 20), color, 1)
		MODE_PILLAR:
			_draw_icon_line(image, Vector2i(7, 8), Vector2i(9, 5), color, 2)
			_draw_icon_line(image, Vector2i(9, 5), Vector2i(15, 5), color, 2)
			_draw_icon_line(image, Vector2i(15, 5), Vector2i(17, 8), color, 2)
			_draw_icon_line(image, Vector2i(7, 8), Vector2i(7, 17), color, 2)
			_draw_icon_line(image, Vector2i(17, 8), Vector2i(17, 17), color, 2)
			_draw_icon_line(image, Vector2i(7, 17), Vector2i(9, 20), color, 2)
			_draw_icon_line(image, Vector2i(9, 20), Vector2i(15, 20), color, 2)
			_draw_icon_line(image, Vector2i(15, 20), Vector2i(17, 17), color, 2)
		MODE_ROOF:
			_draw_icon_line(image, Vector2i(3, 14), Vector2i(12, 5), color, 2)
			_draw_icon_line(image, Vector2i(12, 5), Vector2i(21, 14), color, 2)
			_draw_icon_line(image, Vector2i(5, 14), Vector2i(19, 14), color, 2)
			_draw_icon_line(image, Vector2i(7, 14), Vector2i(7, 19), color, 1)
			_draw_icon_line(image, Vector2i(17, 14), Vector2i(17, 19), color, 1)
			_draw_icon_line(image, Vector2i(7, 19), Vector2i(17, 19), color, 1)
		MODE_PROP:
			_draw_icon_cube(image, color)
		MODE_DOOR:
			_draw_icon_line(image, Vector2i(7, 20), Vector2i(7, 8), color, 2)
			_draw_icon_line(image, Vector2i(7, 8), Vector2i(12, 4), color, 2)
			_draw_icon_line(image, Vector2i(12, 4), Vector2i(17, 8), color, 2)
			_draw_icon_line(image, Vector2i(17, 8), Vector2i(17, 20), color, 2)
			_draw_icon_line(image, Vector2i(5, 20), Vector2i(19, 20), color, 2)
			_draw_icon_line(image, Vector2i(10, 9), Vector2i(10, 18), color, 1)
			image.fill_rect(Rect2i(14, 13, 2, 2), color)
		MODE_WINDOW:
			_draw_icon_rect_outline(image, Rect2i(4, 5, 16, 13), color, 2)
			_draw_icon_line(image, Vector2i(12, 6), Vector2i(12, 17), color, 2)
			_draw_icon_line(image, Vector2i(5, 12), Vector2i(19, 12), color, 2)
			_draw_icon_line(image, Vector2i(3, 20), Vector2i(21, 20), color, 2)
			_draw_icon_line(image, Vector2i(5, 18), Vector2i(19, 18), color, 1)
		_:
			_draw_icon_cube(image, color)
	if m_toolbar_icon_size != TOOLBAR_FALLBACK_ICON_SIZE:
		image.resize(m_toolbar_icon_size.x, m_toolbar_icon_size.y, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	m_toolbar_icon_cache[mode] = texture
	return texture


func _draw_icon_cube(image: Image, color: Color) -> void:
	_draw_icon_rect_outline(image, Rect2i(5, 9, 11, 10), color, 2)
	_draw_icon_line(image, Vector2i(5, 9), Vector2i(9, 5), color, 1)
	_draw_icon_line(image, Vector2i(16, 9), Vector2i(20, 5), color, 1)
	_draw_icon_line(image, Vector2i(9, 5), Vector2i(20, 5), color, 1)
	_draw_icon_line(image, Vector2i(20, 5), Vector2i(20, 15), color, 1)
	_draw_icon_line(image, Vector2i(16, 19), Vector2i(20, 15), color, 1)


func _draw_icon_rect_outline(image: Image, rect: Rect2i, color: Color, width := 1) -> void:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x - 1
	var bottom := rect.position.y + rect.size.y - 1
	_draw_icon_line(image, Vector2i(left, top), Vector2i(right, top), color, width)
	_draw_icon_line(image, Vector2i(right, top), Vector2i(right, bottom), color, width)
	_draw_icon_line(image, Vector2i(right, bottom), Vector2i(left, bottom), color, width)
	_draw_icon_line(image, Vector2i(left, bottom), Vector2i(left, top), color, width)


func _draw_icon_line(image: Image, start: Vector2i, end: Vector2i, color: Color, width := 1) -> void:
	var x0 := start.x
	var y0 := start.y
	var x1 := end.x
	var y1 := end.y
	var dx: int = abs(x1 - x0)
	var dy: int = abs(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		_draw_icon_dot(image, x0, y0, color, width)
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy


func _draw_icon_dot(image: Image, x: int, y: int, color: Color, width: int) -> void:
	for px in range(x, x + width):
		for py in range(y, y + width):
			if (
				px >= 0
				and py >= 0
				and px < TOOLBAR_FALLBACK_ICON_SIZE.x
				and py < TOOLBAR_FALLBACK_ICON_SIZE.y
			):
				image.set_pixel(px, py, color)


func _get_editor_icon(icon_name: StringName, fallback_to_node_3d := true) -> Texture2D:
	var base_control := get_editor_interface().get_base_control()
	if base_control == null:
		return null
	if base_control.has_theme_icon(icon_name, &"EditorIcons"):
		return base_control.get_theme_icon(icon_name, &"EditorIcons")
	if fallback_to_node_3d and base_control.has_theme_icon(&"Node3D", &"EditorIcons"):
		return base_control.get_theme_icon(&"Node3D", &"EditorIcons")
	return null


func _handled() -> int:
	get_viewport().set_input_as_handled()
	return EditorPlugin.AFTER_GUI_INPUT_STOP


func _set_status(text: String) -> void:
	if m_dock != null and m_dock.has_method("set_status"):
		m_dock.set_status(text)


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
	_cancel_active_preview()
	if m_tool_mode != MODE_SELECT:
		_activate_3d_editor_context()
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null:
		if m_tool_mode == MODE_FLOOR:
			_apply_floor_settings_to_coordinator(coordinator)
		elif m_tool_mode == MODE_STAIRS:
			_apply_stair_settings_to_coordinator(coordinator)
		elif m_tool_mode == MODE_PILLAR:
			_apply_pillar_settings_to_coordinator(coordinator)
		elif m_tool_mode == MODE_ROOF:
			_apply_roof_settings_to_coordinator(coordinator)
		elif m_tool_mode == MODE_WALL:
			_apply_wall_settings_to_coordinator(coordinator)
	_set_status("Select a tool." if mode == MODE_SELECT else "Active tool: %s" % mode.capitalize())


func _on_wall_settings_changed(settings: Dictionary) -> void:
	var previous_type := _wall_tool_type()
	m_wall_settings = settings.duplicate(true)
	if _wall_tool_type() != previous_type:
		_clear_wall_preview()
		_reset_wall_drawing_state()
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null:
		_apply_wall_settings_to_coordinator(coordinator)


func _on_floor_settings_changed(settings: Dictionary) -> void:
	m_floor_settings = settings.duplicate(true)
	_clear_floor_preview()
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null and m_tool_mode == MODE_FLOOR:
		_apply_floor_settings_to_coordinator(coordinator)


func _on_stair_settings_changed(settings: Dictionary) -> void:
	m_stair_settings = settings.duplicate(true)
	_clear_stair_preview()
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null and m_tool_mode == MODE_STAIRS:
		_apply_stair_settings_to_coordinator(coordinator)


func _on_pillar_settings_changed(settings: Dictionary) -> void:
	m_pillar_settings = settings.duplicate(true)
	_clear_pillar_preview()
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null and m_tool_mode == MODE_PILLAR:
		_apply_pillar_settings_to_coordinator(coordinator)


func _on_roof_settings_changed(settings: Dictionary) -> void:
	m_roof_settings = settings.duplicate(true)
	_clear_roof_preview()
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null and m_tool_mode == MODE_ROOF:
		_apply_roof_settings_to_coordinator(coordinator)


func _on_prop_settings_changed(settings: Dictionary) -> void:
	m_prop_settings = settings.duplicate(true)
	_clear_prop_preview()


func _on_window_settings_changed(settings: Dictionary) -> void:
	m_window_settings = settings.duplicate(true)


func _on_door_settings_changed(settings: Dictionary) -> void:
	m_door_settings = settings.duplicate(true)
	_clear_prop_preview()


func _on_create_coordinator_requested() -> void:
	var coordinator := _get_or_create_coordinator(true)
	if coordinator != null:
		_set_status("Coordinator ready.")


func _on_scene_changed(_scene_root: Node) -> void:
	_cancel_active_preview()
	_refresh_dock_context()


func _on_editor_selection_changed() -> void:
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
