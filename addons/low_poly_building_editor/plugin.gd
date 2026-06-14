@tool
extends EditorPlugin

const _DOCK_SLOT := EditorDock.DOCK_SLOT_RIGHT_UL
const MODE_SELECT := "select"
const MODE_WALL := "wall"
const MODE_PROP := "prop"
const MODE_WINDOW := "window"
const BuildingEditor3DScript = preload("res://addons/low_poly_building_editor/building_editor_3d.gd")
const ProceduralWall3DScript = preload("res://addons/low_poly_building_editor/procedural_wall_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/building_opening_3d.gd")
const WallSegment3DScript = preload("res://addons/low_poly_building_editor/wall_segment_3d.gd")
const DockScript = preload("res://addons/low_poly_building_editor/low_poly_building_editor_dock.gd")
const ViewportInputOverlayScript = preload("res://addons/low_poly_building_editor/viewport_input_overlay.gd")
const ViewportInputCaptureScript = preload("res://addons/low_poly_building_editor/viewport_input_capture.gd")

var m_dock: Control
var m_editor_dock: EditorDock
var m_input_capture: Node
var m_viewport_overlays: Array[Control] = []
var m_tool_mode := MODE_SELECT
var m_wall_settings := {
	"grid_step": 0.5,
	"height": 2.4,
	"thickness": 0.22,
	"color": Color(0.78, 0.68, 0.54, 1.0),
	"lock_8_way": true,
}
var m_prop_settings := {
	"scene_path": "",
	"clearance": 0.25,
}
var m_window_settings := {
	"width": 1.0,
	"height": 1.0,
	"frame_thickness": 0.08,
	"sill_height": 0.9,
}
var m_wall_start_local := Vector3.ZERO
var m_wall_end_local := Vector3.ZERO
var m_wall_has_valid_preview := false
var m_is_drawing_wall := false
var m_wall_preview: ProceduralWall3DScript
var m_prop_preview: Node3D
var m_prop_preview_path := ""
var m_prop_rotation_y := 0.0
var m_preview_valid := false
var m_preview_parent: Node
var m_preview_wall: ProceduralWall3DScript
var m_dragging_wall: ProceduralWall3DScript
var m_drag_wall_old_start: Vector3
var m_drag_wall_old_end: Vector3
var m_drag_wall_old_segments: Array[WallSegment3DScript] = []
var m_drag_wall_anchor_local: Vector3
var m_drag_wall_segment_index := 0
var m_drag_wall_endpoint := -1   # -1=full move, 0=start pt, 1=end pt
var m_drag_wall_joint_origin := Vector3.ZERO
var m_drag_wall_dragging_joint := false
var m_drag_wall_detaching_joint := false
var m_drag_wall_has_connection_snap := false
var m_drag_wall_hover: ProceduralWall3DScript
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
		"ProceduralWall3D",
		"MeshInstance3D",
		ProceduralWall3DScript,
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
	m_dock.connect("prop_settings_changed", Callable(self, "_on_prop_settings_changed"))
	m_dock.connect("window_settings_changed", Callable(self, "_on_window_settings_changed"))
	m_dock.connect("create_coordinator_requested", Callable(self, "_on_create_coordinator_requested"))

	m_editor_dock = EditorDock.new()
	m_editor_dock.name = "Low-Poly Building Editor"
	m_editor_dock.title = "Low-Poly Building Editor"
	m_editor_dock.default_slot = _DOCK_SLOT
	m_editor_dock.layout_key = "low_poly_building_editor"
	m_editor_dock.add_child(m_dock)
	add_dock(m_editor_dock)
	scene_changed.connect(_on_scene_changed)
	_refresh_dock_context()
	_attach_input_capture()
	_attach_viewport_overlays.call_deferred()


func _exit_tree() -> void:
	_clear_wall_preview()
	_clear_prop_preview()
	_clear_viewport_overlays()
	_clear_input_capture()
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
	remove_custom_type("ProceduralWall3D")
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
	if m_tool_mode == MODE_PROP or m_tool_mode == MODE_WINDOW:
		return _handle_placement_input(camera, event)
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func is_building_tool_active() -> bool:
	return m_tool_mode != MODE_SELECT


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
		if m_is_drawing_wall:
			_update_wall_preview(camera, (event as InputEventMouseMotion).position)
			return _handled()
		var pick := _find_wall_pick(camera, (event as InputEventMouseMotion).position)
		var hover_wall := pick.get("wall") as ProceduralWall3DScript
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
				else "Click and drag to move wall."
			)
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !(event is InputEventMouseButton):
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and !mouse_button.pressed and m_is_drawing_wall:
		_set_status("Wall mouse release captured.")
		var release_coordinator := _get_active_wall_coordinator()
		if release_coordinator != null:
			var release_end := m_wall_end_local
			if !m_wall_has_valid_preview:
				release_end = _resolve_wall_end_from_mouse(release_coordinator, camera, mouse_button.position)
			_commit_wall(release_coordinator, m_wall_start_local, release_end)
		_clear_wall_preview()
		m_is_drawing_wall = false
		m_wall_has_valid_preview = false
		return _handled()

	if mouse_button.button_index != MOUSE_BUTTON_LEFT or !mouse_button.pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if !m_is_drawing_wall:
		var pick := _find_wall_pick(camera, mouse_button.position)
		var hit_wall := pick.get("wall") as ProceduralWall3DScript
		if hit_wall != null:
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

	var hit := _raycast_world(camera, mouse_button.position, false)
	var local_position := coordinator.to_local(Vector3(hit["position"]))
	var snapped_local := coordinator.snap_local_position(local_position)
	if !m_is_drawing_wall:
		m_wall_start_local = snapped_local
		m_wall_end_local = snapped_local
		m_wall_has_valid_preview = false
		m_is_drawing_wall = true
		_create_wall_preview(coordinator)
		_update_wall_preview(camera, mouse_button.position)
		_set_status("Wall mouse press captured. Drag and release, or click another point.")
		return _handled()

	var local_end := coordinator.constrain_wall_end(m_wall_start_local, snapped_local)
	_commit_wall(coordinator, m_wall_start_local, local_end)
	_clear_wall_preview()
	m_is_drawing_wall = false
	m_wall_has_valid_preview = false
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
	if m_tool_mode == MODE_WINDOW and m_dragging_opening != null:
		return _handle_window_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		if m_tool_mode == MODE_WINDOW:
			var pick := _find_opening_pick(camera, mouse_pos)
			var hover_opening := pick.get("opening") as BuildingOpening3DScript
			var hover_edge := int(pick.get("edge", -1))
			_update_hover_highlight(hover_opening, hover_edge)
			if hover_opening != null:
				_clear_prop_preview()
				_set_status(
					"Click and drag edge to resize." if hover_edge >= 0
					else "Click and drag to reposition."
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

	if m_tool_mode == MODE_WINDOW:
		var pick := _find_opening_pick(camera, mouse_button.position)
		var hit_opening := pick.get("opening") as BuildingOpening3DScript
		if hit_opening != null:
			_clear_drag_hover()
			_start_window_drag(hit_opening, int(pick.get("edge", -1)), pick.get("wall") as ProceduralWall3DScript)
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
	m_wall_preview = ProceduralWall3DScript.new() as ProceduralWall3DScript
	m_wall_preview.name = "WallPreview"
	m_wall_preview.set_meta(ProceduralWall3DScript.PREVIEW_META, true)
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
	var hit := _raycast_world(camera, mouse_position, false)
	var local_position := coordinator.to_local(Vector3(hit["position"]))
	var local_end := coordinator.constrain_wall_end(m_wall_start_local, local_position)
	m_wall_end_local = local_end
	m_wall_has_valid_preview = _is_wall_span_long_enough(m_wall_start_local, local_end)
	m_wall_preview.set_wall_endpoints(m_wall_start_local, local_end)
	if m_wall_has_valid_preview:
		_set_status("Release or click to place wall.")


func _resolve_wall_end_from_mouse(
	coordinator: BuildingEditor3DScript,
	camera: Camera3D,
	mouse_position: Vector2
) -> Vector3:
	var hit := _raycast_world(camera, mouse_position, false)
	var local_position := coordinator.to_local(Vector3(hit["position"]))
	return coordinator.constrain_wall_end(m_wall_start_local, local_position)


func _get_active_wall_coordinator() -> BuildingEditor3DScript:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		var preview_parent := m_wall_preview.get_parent() as BuildingEditor3DScript
		if preview_parent != null:
			return preview_parent
	return _get_or_create_coordinator(false)


func _commit_wall(coordinator: BuildingEditor3DScript, local_start: Vector3, local_end: Vector3) -> void:
	if !_is_wall_span_long_enough(local_start, local_end):
		_set_status("Wall is too short.")
		return

	_apply_wall_settings_to_coordinator(coordinator)
	var thickness := float(m_wall_settings["thickness"])
	var merge := coordinator.find_merge_target(
		local_start,
		local_end,
		thickness,
		float(m_wall_settings["height"]),
		m_wall_preview
	)
	var undo_redo := get_undo_redo()
	if !merge.is_empty():
		var target := merge["wall"] as ProceduralWall3DScript
		var old_start := target.start_point
		var old_end := target.end_point
		undo_redo.create_action("Merge Procedural Wall")
		undo_redo.add_do_method(target, "set_wall_endpoints", merge["start"], merge["end"])
		undo_redo.add_undo_method(target, "set_wall_endpoints", old_start, old_end)
		undo_redo.commit_action()
		_select_node(target)
		_set_status("Merged wall span.")
		return

	if coordinator.merge_intersecting:
		var targets := coordinator.find_intersecting_walls(local_start, local_end, thickness, m_wall_preview)
		if !targets.is_empty():
			_commit_absorbed_wall(coordinator, targets, local_start, local_end)
			return

	var wall := coordinator.create_wall_node(
		local_start,
		local_end,
		float(m_wall_settings["height"]),
		thickness,
		Color(m_wall_settings["color"])
	)
	var scene_root := get_editor_interface().get_edited_scene_root()
	undo_redo.create_action("Create Procedural Wall")
	undo_redo.add_do_reference(wall)
	undo_redo.add_do_method(self, "_do_add_node", coordinator, wall, scene_root, true)
	undo_redo.add_undo_method(self, "_undo_remove_node", coordinator, wall)
	undo_redo.commit_action()
	_set_status("Created wall: %.2f units." % local_start.distance_to(local_end))


func _commit_absorbed_wall(
	coordinator: BuildingEditor3DScript,
	targets: Array[ProceduralWall3DScript],
	local_start: Vector3,
	local_end: Vector3
) -> void:
	var survivor := targets[0]
	var drawn := WallSegment3DScript.new()
	drawn.start_point = local_start
	drawn.end_point = local_end
	drawn.thickness = float(m_wall_settings["thickness"])
	drawn.height = float(m_wall_settings["height"])
	drawn.color = Color(m_wall_settings["color"])
	var removed: Array[ProceduralWall3DScript] = []
	for target_index in range(1, targets.size()):
		removed.append(targets[target_index])
	var added: Array[WallSegment3DScript] = [drawn]
	_commit_merged_wall_group(
		coordinator,
		survivor,
		removed,
		added,
		survivor.start_point,
		survivor.end_point,
		_duplicate_segments(survivor.extra_segments),
		"Merge Intersecting Walls",
		"Merged wall spans into %s." % survivor.name
	)


func _commit_merged_wall_group(
	coordinator: BuildingEditor3DScript,
	survivor: ProceduralWall3DScript,
	removed: Array[ProceduralWall3DScript],
	added_segments: Array[WallSegment3DScript],
	undo_start: Vector3,
	undo_end: Vector3,
	undo_segments: Array[WallSegment3DScript],
	action_name: String,
	status: String
) -> void:
	var merged_segments := _build_merged_wall_segments(coordinator, survivor, removed, added_segments)
	if merged_segments.is_empty():
		_set_status("Wall is too short.")
		return
	var primary := merged_segments[0]
	var extra_segments: Array[WallSegment3DScript] = []
	for segment_index in range(1, merged_segments.size()):
		extra_segments.append(merged_segments[segment_index].duplicate() as WallSegment3DScript)

	var scene_root := get_editor_interface().get_edited_scene_root()
	var moved: Array = []
	var moved_parents: Array = []
	var moved_transforms: Array = []
	for other in removed:
		for child in other.get_children():
			if child.has_meta(ProceduralWall3DScript.GENERATED_META):
				continue
			var child_3d := child as Node3D
			if child_3d == null:
				continue
			moved.append(child_3d)
			moved_parents.append(other)
			moved_transforms.append(child_3d.transform)

	var undo_redo := get_undo_redo()
	undo_redo.create_action(action_name)
	for node in removed:
		undo_redo.add_undo_reference(node)
	undo_redo.add_do_method(
		self,
		"_do_absorb_walls",
		survivor,
		primary.start_point,
		primary.end_point,
		extra_segments,
		removed,
		moved,
		scene_root
	)
	undo_redo.add_undo_method(
		self,
		"_undo_absorb_walls",
		survivor,
		undo_start,
		undo_end,
		_duplicate_segments(undo_segments),
		removed,
		moved,
		moved_parents,
		moved_transforms,
		coordinator,
		scene_root
	)
	undo_redo.commit_action()
	_set_status(status)


func _build_merged_wall_segments(
	coordinator: BuildingEditor3DScript,
	survivor: ProceduralWall3DScript,
	removed: Array[ProceduralWall3DScript],
	added_segments: Array[WallSegment3DScript]
) -> Array[WallSegment3DScript]:
	var tolerance := maxf(coordinator.grid_step * 0.25, 0.03)
	var combined: Array[WallSegment3DScript] = []
	for segment in _duplicate_wall_segments(survivor):
		WallSegment3DScript.merge_into(combined, segment, tolerance)
	for other in removed:
		for segment in _duplicate_wall_segments(other):
			WallSegment3DScript.merge_into(combined, segment, tolerance)
	for segment in added_segments:
		WallSegment3DScript.merge_into(combined, segment.duplicate() as WallSegment3DScript, tolerance)
	return WallSegment3DScript.split_at_intersections(combined, tolerance)


func _do_absorb_walls(
	survivor: ProceduralWall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegment3DScript],
	removed: Array,
	moved: Array,
	scene_root: Node
) -> void:
	for child in moved:
		var child_3d := child as Node3D
		if child_3d == null:
			continue
		var child_global := child_3d.global_transform
		if child_3d.get_parent() != null:
			child_3d.get_parent().remove_child(child_3d)
		survivor.add_child(child_3d)
		child_3d.global_transform = child_global
		_set_owner_recursive(child_3d, scene_root)
	for node in removed:
		var node_typed := node as Node
		if node_typed != null and node_typed.get_parent() != null:
			node_typed.get_parent().remove_child(node_typed)
	_apply_wall_geometry(survivor, new_start, new_end, segments)
	_select_node(survivor)


func _undo_absorb_walls(
	survivor: ProceduralWall3DScript,
	old_start: Vector3,
	old_end: Vector3,
	old_segments: Array[WallSegment3DScript],
	removed: Array,
	moved: Array,
	moved_parents: Array,
	moved_transforms: Array,
	coordinator: BuildingEditor3DScript,
	scene_root: Node
) -> void:
	for node in removed:
		var node_typed := node as Node
		if node_typed != null and node_typed.get_parent() == null:
			coordinator.add_child(node_typed)
			_set_owner_recursive(node_typed, scene_root)
	for index in range(moved.size()):
		var child_3d := moved[index] as Node3D
		if child_3d == null:
			continue
		if child_3d.get_parent() != null:
			child_3d.get_parent().remove_child(child_3d)
		var old_parent := moved_parents[index] as Node
		old_parent.add_child(child_3d)
		child_3d.transform = moved_transforms[index]
		_set_owner_recursive(child_3d, scene_root)
	_apply_wall_geometry(survivor, old_start, old_end, old_segments)
	for node in removed:
		var node_typed := node as Node
		if node_typed != null and node_typed.has_method("rebuild_wall_mesh"):
			node_typed.rebuild_wall_mesh()


func _update_placement_preview(camera: Camera3D, mouse_position: Vector2) -> void:
	var hit := _raycast_world(camera, mouse_position)
	var wall := _find_wall_from_collider(hit.get("collider"))

	if m_tool_mode == MODE_WINDOW:
		_update_window_preview(wall, hit)
		return

	_update_prop_preview(wall, hit)


func _update_window_preview(wall: ProceduralWall3DScript, hit: Dictionary) -> void:
	if wall == null:
		_clear_prop_preview()
		_set_status("Window openings need a wall target.")
		m_preview_valid = false
		return
	var segment_index := int(hit.get("segment", 0))
	var segment := wall.get_segment(segment_index)
	var frame := wall.get_segment_local_frame(segment_index)

	if !(m_prop_preview is BuildingOpening3DScript):
		_clear_prop_preview()
		m_prop_preview = BuildingOpening3DScript.new() as BuildingOpening3DScript
		m_prop_preview.name = "WindowOpeningPreview"
		(m_prop_preview as BuildingOpening3DScript).build_on_ready = true
		(m_prop_preview as BuildingOpening3DScript).frame_depth = segment.thickness + 0.04
	_set_preview_parent(m_prop_preview, wall)

	var opening := m_prop_preview as BuildingOpening3DScript
	opening.set_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, segment_index)
	opening.opening_width = float(m_window_settings["width"])
	opening.opening_height = float(m_window_settings["height"])
	opening.frame_thickness = float(m_window_settings["frame_thickness"])
	opening.frame_depth = segment.thickness + 0.04
	var local_hit := frame.affine_inverse() * wall.to_local(Vector3(hit["position"]))
	var face_sign := 1.0 if local_hit.z >= 0.0 else -1.0
	var grid_step := _active_grid_step(wall)
	local_hit.x = clampf(roundf(local_hit.x / grid_step) * grid_step, 0.0, segment.get_length())
	var sill_height := maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0)
	local_hit.y = sill_height + opening.opening_height * 0.5
	local_hit.z = face_sign * (segment.thickness * 0.5 + 0.035)
	opening.transform = Transform3D(frame.basis, frame * local_hit)
	var center := Vector2(local_hit.x, local_hit.y)
	var size := Vector2(opening.opening_width, opening.opening_height)
	m_preview_valid = wall.can_place_opening(center, size, 0.04, opening, segment_index)
	opening.frame_color = Color(0.20, 0.88, 0.36, 0.72) if m_preview_valid else Color(0.95, 0.20, 0.16, 0.72)
	m_preview_wall = wall
	_set_status("Window ready." if m_preview_valid else "Window overlaps or leaves the wall span.")


func _update_prop_preview(wall: ProceduralWall3DScript, hit: Dictionary) -> void:
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

	if m_tool_mode == MODE_WINDOW:
		var opening_preview := m_prop_preview as BuildingOpening3DScript
		var wall := m_preview_parent as ProceduralWall3DScript
		if opening_preview == null or wall == null:
			return
		var opening := BuildingOpening3DScript.new() as BuildingOpening3DScript
		opening.name = "WindowOpening"
		opening.opening_width = opening_preview.opening_width
		opening.opening_height = opening_preview.opening_height
		opening.frame_thickness = opening_preview.frame_thickness
		opening.frame_depth = opening_preview.frame_depth
		opening.frame_color = Color(0.86, 0.92, 0.94, 1.0)
		opening.position = opening_preview.position
		opening.rotation = opening_preview.rotation
		opening.set_meta(
			ProceduralWall3DScript.SEGMENT_INDEX_META,
			int(opening_preview.get_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, 0))
		)
		var scene_root := get_editor_interface().get_edited_scene_root()
		var undo_redo := get_undo_redo()
		undo_redo.create_action("Place Wall Opening")
		undo_redo.add_do_reference(opening)
		undo_redo.add_do_method(self, "_do_add_node_and_rebuild", wall, opening, scene_root, true)
		undo_redo.add_undo_method(self, "_undo_remove_node_and_rebuild", wall, opening)
		undo_redo.commit_action()
		_set_status("Placed window opening.")
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
		if child.has_meta(ProceduralWall3DScript.GENERATED_META):
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
		var wall_hit := _raycast_procedural_walls(origin, direction)
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


func _raycast_procedural_walls(origin: Vector3, direction: Vector3) -> Dictionary:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return {}

	var walls: Array[ProceduralWall3DScript] = []
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


func _collect_scene_walls(node: Node, walls: Array[ProceduralWall3DScript]) -> void:
	if node is ProceduralWall3DScript:
		walls.append(node as ProceduralWall3DScript)
	for child in node.get_children():
		_collect_scene_walls(child, walls)


func _intersect_wall_box(
	wall: ProceduralWall3DScript,
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


func _find_wall_from_collider(collider: Variant) -> ProceduralWall3DScript:
	var node := collider as Node
	while node != null:
		if node is ProceduralWall3DScript:
			return node as ProceduralWall3DScript
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


func _active_grid_step(wall: ProceduralWall3DScript) -> float:
	var coordinator := _find_coordinator_from_node(wall)
	if coordinator != null:
		return maxf(coordinator.grid_step, 0.05)
	return maxf(float(m_wall_settings["grid_step"]), 0.05)


func _apply_wall_geometry(
	wall: ProceduralWall3DScript,
	new_start: Vector3,
	new_end: Vector3,
	segments: Array[WallSegment3DScript]
) -> void:
	wall.start_point = new_start
	wall.end_point = new_end
	wall.extra_segments = _duplicate_segments(segments)
	wall.rebuild_wall_mesh()


func _do_set_wall_geometry(
	wall: ProceduralWall3DScript,
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


func _duplicate_segments(segments: Array) -> Array[WallSegment3DScript]:
	var copies: Array[WallSegment3DScript] = []
	for segment in segments:
		var typed_segment := segment as WallSegment3DScript
		if typed_segment == null:
			continue
		copies.append(typed_segment.duplicate() as WallSegment3DScript)
	return copies


func _duplicate_wall_segments(wall: ProceduralWall3DScript) -> Array[WallSegment3DScript]:
	var segments: Array[WallSegment3DScript] = []
	for segment_index in range(wall.get_segment_count()):
		var segment := wall.get_segment(segment_index)
		if segment == null:
			continue
		segments.append(segment.duplicate() as WallSegment3DScript)
	return segments


func _normalized_wall_geometry(wall: ProceduralWall3DScript) -> Dictionary:
	var coordinator := _find_coordinator_from_node(wall)
	var tolerance := maxf(_active_grid_step(wall) * 0.25, 0.03)
	if coordinator != null:
		tolerance = maxf(coordinator.grid_step * 0.25, 0.03)
	var combined: Array[WallSegment3DScript] = []
	for segment in _duplicate_wall_segments(wall):
		WallSegment3DScript.merge_into(combined, segment, tolerance)
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


func _wall_segment_zero_epsilon(wall: ProceduralWall3DScript) -> float:
	return maxf(_active_grid_step(wall) * 0.01, 0.001)


func _is_dragged_wall_span_zero_length(wall: ProceduralWall3DScript) -> bool:
	if wall == null:
		return false
	var segment_index := clampi(m_drag_wall_segment_index, 0, wall.get_segment_count() - 1)
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	return segment.get_length() <= _wall_segment_zero_epsilon(wall)


func _wall_geometry_without_segment(
	wall: ProceduralWall3DScript,
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


func _commit_delete_zero_length_wall_segment(
	wall: ProceduralWall3DScript,
	geometry: Dictionary,
	old_start: Vector3,
	old_end: Vector3,
	old_segments: Array[WallSegment3DScript]
) -> void:
	var next_segments: Array[WallSegment3DScript] = geometry["segments"]
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Delete Wall Segment")
	undo_redo.add_do_method(
		self,
		"_do_set_wall_geometry",
		wall,
		Vector3(geometry["start"]),
		Vector3(geometry["end"]),
		next_segments,
		true
	)
	undo_redo.add_undo_method(self, "_do_set_wall_geometry", wall, old_start, old_end, old_segments, true)
	undo_redo.commit_action()
	_set_status("Deleted zero-length wall segment.")


func _commit_delete_zero_length_wall(
	wall: ProceduralWall3DScript,
	old_start: Vector3,
	old_end: Vector3,
	old_segments: Array[WallSegment3DScript]
) -> void:
	var parent := wall.get_parent()
	var scene_root := get_editor_interface().get_edited_scene_root()
	if parent == null or scene_root == null:
		_apply_wall_geometry(wall, old_start, old_end, old_segments)
		_set_status("Wall is too short.")
		return
	_apply_wall_geometry(wall, old_start, old_end, old_segments)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Delete Procedural Wall")
	undo_redo.add_undo_reference(wall)
	undo_redo.add_do_method(self, "_undo_remove_node", parent, wall)
	undo_redo.add_undo_method(self, "_do_add_node", parent, wall, scene_root, true)
	undo_redo.commit_action()
	_set_status("Deleted zero-length wall.")


func _apply_drag_wall_endpoint(snapped_position: Vector3) -> void:
	if m_dragging_wall == null:
		return
	var extras := _duplicate_segments(m_drag_wall_old_segments)
	_apply_wall_geometry(m_dragging_wall, m_drag_wall_old_start, m_drag_wall_old_end, extras)
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
		extras
	)


func _is_dragged_wall_span_long_enough(wall: ProceduralWall3DScript) -> bool:
	if wall == null:
		return false
	var segment_index := clampi(m_drag_wall_segment_index, 0, wall.get_segment_count() - 1)
	var segment := wall.get_segment(segment_index)
	if segment == null:
		return false
	return _is_wall_span_long_enough(segment.start_point, segment.end_point)


func _find_intersecting_targets_for_wall(
	coordinator: BuildingEditor3DScript,
	wall: ProceduralWall3DScript
) -> Array[ProceduralWall3DScript]:
	var targets: Array[ProceduralWall3DScript] = []
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


func _clear_wall_preview() -> void:
	if m_wall_preview != null and is_instance_valid(m_wall_preview):
		m_wall_preview.queue_free()
	m_wall_preview = null


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
			}
		if _hit_near_wall_endpoint(hit_parent_local, segment.end_point, segment, ep_radius):
			var end_joint := _wall_joint_info(wall, segment.end_point)
			return {
				"wall": wall,
				"segment": segment_index,
				"endpoint": 1,
				"joint": bool(end_joint["joint"]),
				"joint_position": end_joint["position"],
			}
	return {"wall": wall, "segment": segment_hint, "endpoint": -1}


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


func _wall_joint_info(wall: ProceduralWall3DScript, endpoint: Vector3) -> Dictionary:
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


func _wall_joint_tolerance(wall: ProceduralWall3DScript) -> float:
	return maxf(_active_grid_step(wall) * 0.05, 0.03)


func _wall_connection_snap_radius(wall: ProceduralWall3DScript) -> float:
	return maxf(maxf(_active_grid_step(wall) * 0.45, wall.wall_thickness * 1.25), 0.08)


func _drag_wall_endpoint_position(
	wall: ProceduralWall3DScript,
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
	wall: ProceduralWall3DScript,
	position: Vector3,
	radius: float
) -> Dictionary:
	var candidates: Array[ProceduralWall3DScript] = []
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
		if candidate_wall.has_meta(ProceduralWall3DScript.PREVIEW_META):
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
	wall: ProceduralWall3DScript,
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


func _show_wall_joint_hover(wall: ProceduralWall3DScript, joint_position: Vector3) -> void:
	_clear_wall_joint_hover()
	if wall == null or !is_instance_valid(wall):
		return
	var marker := MeshInstance3D.new()
	marker.name = "WallJointHover"
	marker.set_meta(ProceduralWall3DScript.GENERATED_META, true)
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


func _wall_joint_hover_height(wall: ProceduralWall3DScript, joint_position: Vector3) -> float:
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


func _wall_parent_local_to_wall_local(wall: ProceduralWall3DScript, parent_local_position: Vector3) -> Vector3:
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
	wall: ProceduralWall3DScript,
	camera: Camera3D,
	mouse_pos: Vector2,
	segment_index: int,
	endpoint: int,
	disconnect_joint: bool = false
) -> void:
	m_dragging_wall = wall
	m_drag_wall_old_start = wall.start_point
	m_drag_wall_old_end = wall.end_point
	m_drag_wall_old_segments = _duplicate_segments(wall.extra_segments)
	m_drag_wall_segment_index = clampi(segment_index, 0, wall.get_segment_count() - 1)
	m_drag_wall_endpoint = endpoint
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	if endpoint >= 0:
		m_drag_wall_joint_origin = _drag_wall_endpoint_position(wall, m_drag_wall_segment_index, endpoint)
		var is_shared_joint := wall.count_connected_endpoints(
			m_drag_wall_joint_origin,
			_wall_joint_tolerance(wall)
		) >= 2
		m_drag_wall_dragging_joint = is_shared_joint and !disconnect_joint
		m_drag_wall_detaching_joint = is_shared_joint and disconnect_joint
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
		else "wall"
	)
	_set_status("Dragging %s — release to commit, Escape to cancel." % action)


func _update_wall_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_wall == null or !is_instance_valid(m_dragging_wall):
		m_dragging_wall = null
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
		# Full move: translate both endpoints by snapped delta
		var raw_delta := hit_local - m_drag_wall_anchor_local
		var snapped_delta := Vector3(
			roundf(raw_delta.x / step) * step,
			0.0,
			roundf(raw_delta.z / step) * step
		)
		_translate_drag_wall_geometry(snapped_delta)
		_set_status("Release to commit.")


func _commit_wall_drag() -> void:
	if m_dragging_wall == null:
		return
	var wall := m_dragging_wall
	var new_start := wall.start_point
	var new_end := wall.end_point
	var new_segments := _duplicate_segments(wall.extra_segments)
	var old_start := m_drag_wall_old_start
	var old_end := m_drag_wall_old_end
	var old_segments := _duplicate_segments(m_drag_wall_old_segments)
	var was_joint_drag := m_drag_wall_dragging_joint
	var was_detaching_joint := m_drag_wall_detaching_joint
	var was_connection_snap := m_drag_wall_has_connection_snap
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
		m_drag_wall_segment_index = 0
		m_drag_wall_endpoint = -1
		m_drag_wall_joint_origin = Vector3.ZERO
		m_drag_wall_dragging_joint = false
		m_drag_wall_detaching_joint = false
		m_drag_wall_has_connection_snap = false
		return
	if !_is_dragged_wall_span_long_enough(wall):
		_apply_wall_geometry(wall, old_start, old_end, old_segments)
		m_drag_wall_old_segments.clear()
		m_drag_wall_segment_index = 0
		m_drag_wall_endpoint = -1
		m_drag_wall_joint_origin = Vector3.ZERO
		m_drag_wall_dragging_joint = false
		m_drag_wall_detaching_joint = false
		m_drag_wall_has_connection_snap = false
		_set_status("Wall is too short.")
		return
	var coordinator := _find_coordinator_from_node(wall)
	if coordinator != null and coordinator.merge_intersecting:
		var targets := _find_intersecting_targets_for_wall(coordinator, wall)
		if !targets.is_empty():
			var no_added_segments: Array[WallSegment3DScript] = []
			_commit_merged_wall_group(
				coordinator,
				wall,
				targets,
				no_added_segments,
				old_start,
				old_end,
				old_segments,
				"Move And Merge Procedural Wall",
				"Moved and merged wall."
			)
			m_drag_wall_old_segments.clear()
			m_drag_wall_segment_index = 0
			m_drag_wall_endpoint = -1
			m_drag_wall_joint_origin = Vector3.ZERO
			m_drag_wall_dragging_joint = false
			m_drag_wall_detaching_joint = false
			m_drag_wall_has_connection_snap = false
			return
	var normalized_geometry := _normalized_wall_geometry(wall)
	if !normalized_geometry.is_empty():
		new_start = Vector3(normalized_geometry["start"])
		new_end = Vector3(normalized_geometry["end"])
		new_segments = normalized_geometry["segments"]
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Move Procedural Wall")
	undo_redo.add_do_method(self, "_do_set_wall_geometry", wall, new_start, new_end, new_segments, true)
	undo_redo.add_undo_method(self, "_do_set_wall_geometry", wall, old_start, old_end, old_segments, true)
	undo_redo.commit_action()
	m_drag_wall_old_segments.clear()
	m_drag_wall_segment_index = 0
	m_drag_wall_endpoint = -1
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	if was_connection_snap:
		_set_status("Connected wall endpoint.")
	elif was_detaching_joint:
		_set_status("Disconnected wall endpoint.")
	elif was_joint_drag:
		_set_status("Moved wall joint.")
	else:
		_set_status("Moved wall.")


func _cancel_wall_drag() -> void:
	if m_dragging_wall == null:
		return
	if is_instance_valid(m_dragging_wall):
		_apply_wall_geometry(m_dragging_wall, m_drag_wall_old_start, m_drag_wall_old_end, m_drag_wall_old_segments)
		m_dragging_wall.material_override = m_drag_wall_active_material
	m_dragging_wall = null
	m_drag_wall_old_segments.clear()
	m_drag_wall_segment_index = 0
	m_drag_wall_endpoint = -1
	m_drag_wall_joint_origin = Vector3.ZERO
	m_drag_wall_dragging_joint = false
	m_drag_wall_detaching_joint = false
	m_drag_wall_has_connection_snap = false
	m_drag_wall_active_material = null


func _find_opening_pick(camera: Camera3D, mouse_pos: Vector2) -> Dictionary:
	var hit := _raycast_world(camera, mouse_pos)
	var wall := _find_wall_from_collider(hit.get("collider"))
	if wall == null:
		return {}
	var hit_world := Vector3(hit["position"])
	for child in wall.get_children():
		if child.has_meta(ProceduralWall3DScript.GENERATED_META):
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
	wall_hint: ProceduralWall3DScript
) -> void:
	_clear_prop_preview()
	m_dragging_opening = opening
	m_drag_old_position = opening.position
	m_drag_opening_old_width = opening.opening_width
	m_drag_opening_old_height = opening.opening_height
	m_drag_old_segment = int(opening.get_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, 0))
	m_drag_target_segment = m_drag_old_segment
	m_drag_opening_edge = edge
	m_drag_valid = true
	var wall := opening.get_parent() as ProceduralWall3DScript
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
	var action := "edge" if edge >= 0 else "window"
	_set_status("Dragging %s — release to commit, Escape to cancel." % action)


func _update_window_drag(camera: Camera3D, mouse_pos: Vector2) -> void:
	if m_dragging_opening == null or !is_instance_valid(m_dragging_opening):
		m_dragging_opening = null
		return
	var wall := m_dragging_opening.get_parent() as ProceduralWall3DScript
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
		var sill_height := maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0)
		var center_local := Vector3(
			m_drag_resize_center_2d.x,
			sill_height + new_height * 0.5,
			m_drag_face_sign * (segment.thickness * 0.5 + 0.035)
		)
		m_dragging_opening.transform = Transform3D(frame.basis, frame * center_local)
		var center_2d := Vector2(center_local.x, center_local.y)
		var size := Vector2(new_width, new_height)
		m_drag_valid = wall.can_place_opening(center_2d, size, 0.04, m_dragging_opening, m_drag_target_segment)
	else:
		# Move mode
		local_hit.x = clampf(roundf(local_hit.x / grid_step) * grid_step, 0.0, segment.get_length())
		var sill_height := maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0)
		local_hit.y = sill_height + m_dragging_opening.opening_height * 0.5
		local_hit.z = m_drag_face_sign * (segment.thickness * 0.5 + 0.035)
		m_dragging_opening.transform = Transform3D(frame.basis, frame * local_hit)
		var center := Vector2(local_hit.x, local_hit.y)
		var size := Vector2(m_dragging_opening.opening_width, m_dragging_opening.opening_height)
		m_drag_valid = wall.can_place_opening(center, size, 0.04, m_dragging_opening, m_drag_target_segment)

	var ok_color := Color(1.0, 0.85, 0.20, 0.9) if m_drag_opening_edge >= 0 else Color(0.20, 0.60, 1.0, 0.9)
	m_dragging_opening.frame_color = ok_color if m_drag_valid else Color(0.95, 0.20, 0.16, 0.9)
	_set_status("Release to commit." if m_drag_valid else "Position overlaps or is out of bounds.")


func _commit_window_drag() -> void:
	if m_dragging_opening == null:
		return
	var wall := m_dragging_opening.get_parent() as ProceduralWall3DScript
	if wall == null or !m_drag_valid:
		_cancel_window_drag()
		if !m_drag_valid:
			_set_status("Cannot place window there — canceled.")
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
	_set_status("Resized window opening." if m_drag_opening_edge >= 0 else "Moved window opening.")
	m_drag_opening_edge = -1


func _cancel_window_drag() -> void:
	if m_dragging_opening == null:
		return
	if is_instance_valid(m_dragging_opening):
		m_dragging_opening.position = m_drag_old_position
		m_dragging_opening.opening_width = m_drag_opening_old_width
		m_dragging_opening.opening_height = m_drag_opening_old_height
		m_dragging_opening.set_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, m_drag_old_segment)
		m_dragging_opening.frame_color = Color(0.86, 0.92, 0.94, 1.0)
		var wall := m_dragging_opening.get_parent() as ProceduralWall3DScript
		if wall != null:
			wall.rebuild_wall_mesh()
	m_dragging_opening = null
	m_drag_valid = false
	m_drag_opening_edge = -1


func _do_move_opening(
	opening: BuildingOpening3DScript,
	new_pos: Vector3,
	segment_index: int,
	wall: ProceduralWall3DScript
) -> void:
	opening.position = new_pos
	opening.set_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, segment_index)
	wall.rebuild_wall_mesh()


func _do_resize_opening(
	opening: BuildingOpening3DScript,
	new_pos: Vector3,
	new_width: float,
	new_height: float,
	wall: ProceduralWall3DScript
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
	_cancel_window_drag()
	_clear_drag_hover()
	_clear_wall_preview()
	_clear_prop_preview()
	m_is_drawing_wall = false
	m_wall_has_valid_preview = false
	_set_status("Tool preview canceled.")


func _is_wall_span_long_enough(local_start: Vector3, local_end: Vector3) -> bool:
	return local_start.distance_to(local_end) >= maxf(float(m_wall_settings["grid_step"]) * 0.5, 0.1)


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


func _undo_remove_node(parent: Node, node: Node) -> void:
	if node.get_parent() == parent:
		parent.remove_child(node)


func _undo_remove_node_and_rebuild(parent: Node, node: Node) -> void:
	_undo_remove_node(parent, node)
	if parent.has_method("rebuild_wall_mesh"):
		parent.rebuild_wall_mesh()


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node.has_meta(ProceduralWall3DScript.GENERATED_META) or node.has_meta(BuildingOpening3DScript.GENERATED_META):
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


func _get_editor_icon(icon_name: StringName) -> Texture2D:
	var base_control := get_editor_interface().get_base_control()
	if base_control == null:
		return null
	if base_control.has_theme_icon(icon_name, &"EditorIcons"):
		return base_control.get_theme_icon(icon_name, &"EditorIcons")
	if base_control.has_theme_icon(&"Node3D", &"EditorIcons"):
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
	_cancel_active_preview()
	if m_tool_mode != MODE_SELECT:
		_activate_3d_editor_context()
	_set_status("Select a tool." if mode == MODE_SELECT else "Active tool: %s" % mode.capitalize())


func _on_wall_settings_changed(settings: Dictionary) -> void:
	m_wall_settings = settings.duplicate(true)
	var coordinator := _get_or_create_coordinator(false)
	if coordinator != null:
		_apply_wall_settings_to_coordinator(coordinator)


func _on_prop_settings_changed(settings: Dictionary) -> void:
	m_prop_settings = settings.duplicate(true)
	_clear_prop_preview()


func _on_window_settings_changed(settings: Dictionary) -> void:
	m_window_settings = settings.duplicate(true)


func _on_create_coordinator_requested() -> void:
	var coordinator := _get_or_create_coordinator(true)
	if coordinator != null:
		_set_status("Coordinator ready.")


func _on_scene_changed(_scene_root: Node) -> void:
	_cancel_active_preview()
	_refresh_dock_context()


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
