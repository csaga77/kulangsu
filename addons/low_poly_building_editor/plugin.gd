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
var m_dragging_opening: BuildingOpening3DScript
var m_drag_old_position: Vector3
var m_drag_old_segment: int
var m_drag_target_segment: int
var m_drag_face_sign := 1.0
var m_drag_valid := false
var m_drag_hover_opening: BuildingOpening3DScript
var m_drag_hover_old_color: Color


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
	if event is InputEventMouseMotion:
		if m_is_drawing_wall:
			_update_wall_preview(camera, (event as InputEventMouseMotion).position)
			return _handled()
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


func _handle_placement_input(camera: Camera3D, event: InputEvent) -> int:
	if m_tool_mode == MODE_WINDOW and m_dragging_opening != null:
		return _handle_window_drag_input(camera, event)

	if event is InputEventMouseMotion:
		var mouse_pos := (event as InputEventMouseMotion).position
		if m_tool_mode == MODE_WINDOW:
			var hover := _find_opening_under_cursor(camera, mouse_pos)
			_update_hover_highlight(hover)
			if hover != null:
				_clear_prop_preview()
				_set_status("Click and drag to reposition.")
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
		var hit_opening := _find_opening_under_cursor(camera, mouse_button.position)
		if hit_opening != null:
			_clear_drag_hover()
			_start_window_drag(hit_opening)
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
	var tolerance := maxf(coordinator.grid_step * 0.25, 0.03)

	var old_segments: Array[WallSegment3DScript] = survivor.extra_segments
	var combined: Array[WallSegment3DScript] = []
	for segment in old_segments:
		combined.append(segment.duplicate() as WallSegment3DScript)

	var removed: Array = []
	var moved: Array = []
	var moved_parents: Array = []
	var moved_transforms: Array = []
	for target_index in range(1, targets.size()):
		var other := targets[target_index]
		for segment_index in range(other.get_segment_count()):
			var segment := other.get_segment(segment_index).duplicate() as WallSegment3DScript
			WallSegment3DScript.merge_into(combined, segment, tolerance)
		removed.append(other)
		for child in other.get_children():
			if child.has_meta(ProceduralWall3DScript.GENERATED_META):
				continue
			var child_3d := child as Node3D
			if child_3d == null:
				continue
			moved.append(child_3d)
			moved_parents.append(other)
			moved_transforms.append(child_3d.transform)

	var drawn := WallSegment3DScript.new()
	drawn.start_point = local_start
	drawn.end_point = local_end
	drawn.thickness = float(m_wall_settings["thickness"])
	drawn.height = float(m_wall_settings["height"])
	drawn.color = Color(m_wall_settings["color"])
	WallSegment3DScript.merge_into(combined, drawn, tolerance)

	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Merge Intersecting Walls")
	for node in removed:
		undo_redo.add_undo_reference(node)
	undo_redo.add_do_method(self, "_do_absorb_walls", survivor, combined, removed, moved, scene_root)
	undo_redo.add_undo_method(
		self,
		"_undo_absorb_walls",
		survivor,
		old_segments,
		removed,
		moved,
		moved_parents,
		moved_transforms,
		coordinator,
		scene_root
	)
	undo_redo.commit_action()
	_set_status("Merged %d wall spans into %s." % [targets.size(), survivor.name])


func _do_absorb_walls(
	survivor: ProceduralWall3DScript,
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
	survivor.extra_segments = segments
	survivor.rebuild_wall_mesh()
	_select_node(survivor)


func _undo_absorb_walls(
	survivor: ProceduralWall3DScript,
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
	survivor.extra_segments = old_segments
	survivor.rebuild_wall_mesh()
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


func _find_opening_under_cursor(camera: Camera3D, mouse_pos: Vector2) -> BuildingOpening3DScript:
	var hit := _raycast_world(camera, mouse_pos)
	var wall := _find_wall_from_collider(hit.get("collider"))
	if wall == null:
		return null
	var hit_world := Vector3(hit["position"])
	var best: BuildingOpening3DScript = null
	var best_dist := INF
	for child in wall.get_children():
		if child.has_meta(ProceduralWall3DScript.GENERATED_META):
			continue
		var opening := child as BuildingOpening3DScript
		if opening == null or opening == m_prop_preview:
			continue
		var pick_radius := maxf(opening.opening_width, opening.opening_height) * 0.5 + 0.15
		var dist := hit_world.distance_to(opening.global_position)
		if dist < pick_radius and dist < best_dist:
			best_dist = dist
			best = opening
	return best


func _update_hover_highlight(opening: BuildingOpening3DScript) -> void:
	if opening == m_drag_hover_opening:
		return
	_clear_drag_hover()
	if opening == null:
		return
	m_drag_hover_opening = opening
	m_drag_hover_old_color = opening.frame_color
	opening.frame_color = Color(0.20, 0.60, 1.0, 0.9)


func _clear_drag_hover() -> void:
	if m_drag_hover_opening == null:
		return
	if is_instance_valid(m_drag_hover_opening):
		m_drag_hover_opening.frame_color = m_drag_hover_old_color
	m_drag_hover_opening = null


func _start_window_drag(opening: BuildingOpening3DScript) -> void:
	_clear_prop_preview()
	m_dragging_opening = opening
	m_drag_old_position = opening.position
	m_drag_old_segment = int(opening.get_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, 0))
	m_drag_target_segment = m_drag_old_segment
	m_drag_valid = true
	var wall := opening.get_parent() as ProceduralWall3DScript
	if wall != null:
		var frame := wall.get_segment_local_frame(m_drag_target_segment)
		var local_pos := frame.affine_inverse() * opening.position
		m_drag_face_sign = signf(local_pos.z) if absf(local_pos.z) > 0.001 else 1.0
	else:
		m_drag_face_sign = 1.0
	opening.frame_color = Color(0.20, 0.60, 1.0, 0.9)
	_set_status("Dragging window — release to commit, Escape to cancel.")


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
	local_hit.x = clampf(roundf(local_hit.x / grid_step) * grid_step, 0.0, segment.get_length())
	var sill_height := maxf(float(m_window_settings.get("sill_height", 0.9)), 0.0)
	local_hit.y = sill_height + m_dragging_opening.opening_height * 0.5
	local_hit.z = m_drag_face_sign * (segment.thickness * 0.5 + 0.035)
	m_dragging_opening.transform = Transform3D(frame.basis, frame * local_hit)
	var center := Vector2(local_hit.x, local_hit.y)
	var size := Vector2(m_dragging_opening.opening_width, m_dragging_opening.opening_height)
	m_drag_valid = wall.can_place_opening(center, size, 0.04, m_dragging_opening, m_drag_target_segment)
	m_dragging_opening.frame_color = (
		Color(0.20, 0.60, 1.0, 0.9) if m_drag_valid else Color(0.95, 0.20, 0.16, 0.9)
	)
	_set_status("Release to commit." if m_drag_valid else "Position overlaps or is out of bounds.")


func _commit_window_drag() -> void:
	if m_dragging_opening == null:
		return
	var wall := m_dragging_opening.get_parent() as ProceduralWall3DScript
	if wall == null or !m_drag_valid:
		_cancel_window_drag()
		if !m_drag_valid:
			_set_status("Cannot place window there — move canceled.")
		return
	var new_position := m_dragging_opening.position
	var old_position := m_drag_old_position
	var old_segment := m_drag_old_segment
	var target_segment := m_drag_target_segment
	var opening := m_dragging_opening
	m_dragging_opening = null
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Move Wall Opening")
	undo_redo.add_do_method(self, "_do_move_opening", opening, new_position, target_segment, wall)
	undo_redo.add_undo_method(self, "_do_move_opening", opening, old_position, old_segment, wall)
	undo_redo.commit_action()
	opening.frame_color = Color(0.86, 0.92, 0.94, 1.0)
	_set_status("Moved window opening.")


func _cancel_window_drag() -> void:
	if m_dragging_opening == null:
		return
	if is_instance_valid(m_dragging_opening):
		m_dragging_opening.position = m_drag_old_position
		m_dragging_opening.set_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, m_drag_old_segment)
		m_dragging_opening.frame_color = Color(0.86, 0.92, 0.94, 1.0)
		var wall := m_dragging_opening.get_parent() as ProceduralWall3DScript
		if wall != null:
			wall.rebuild_wall_mesh()
	m_dragging_opening = null
	m_drag_valid = false


func _do_move_opening(
	opening: BuildingOpening3DScript,
	new_pos: Vector3,
	segment_index: int,
	wall: ProceduralWall3DScript
) -> void:
	opening.position = new_pos
	opening.set_meta(ProceduralWall3DScript.SEGMENT_INDEX_META, segment_index)
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
