@tool
extends RefCounted

## Shared editor services for building tools — stage 1 of the plugin split
## (see `../docs/plugin_split_plan.md`). Owns coordinator resolution, shared
## snapping/raycast/preview helpers, and the node-lifecycle methods invoked
## from undo/redo actions. Internal and path-extended like other internal
## layers; not an editor-creatable type.
##
## Transitional plugin callbacks that move in later stages:
## `_raycast_walls` and `_refresh_wall_intersections` (wall stage),
## `_apply_debug_wireframe_to_node` (display), `_refresh_dock_context`
## (dock wiring). `m_active_coordinator`, `m_preview_parent`, and `m_dock`
## remain plugin members per the split plan and are accessed through
## `m_plugin`. Undo/redo actions keep binding the plugin's delegating
## methods so queued actions stay valid while bodies live here.

const Building3DScript = preload("res://addons/low_poly_building_editor/building_3d.gd")
const BuildingFactoryScript = preload("res://addons/low_poly_building_editor/building_factory.gd")
const BuildingWireframeScript = preload("res://addons/low_poly_building_editor/building_wireframe.gd")
const Wall3DScript = preload("res://addons/low_poly_building_editor/walls/wall_3d.gd")
const Floor3DScript = preload("res://addons/low_poly_building_editor/floors/floor_3d.gd")
const Stairs3DScript = preload("res://addons/low_poly_building_editor/stairs/stairs_3d.gd")
const Rail3DScript = preload("res://addons/low_poly_building_editor/rails/rail_3d.gd")
const Pillar3DScript = preload("res://addons/low_poly_building_editor/pillars/pillar_3d.gd")
const Roof3DScript = preload("res://addons/low_poly_building_editor/roofs/roof_3d.gd")
const BuildingOpening3DScript = preload("res://addons/low_poly_building_editor/openings/building_opening_3d.gd")

## Owning plugin, typed as the native `EditorPlugin` base (typing it as the
## concrete script would create a cyclic preload with `plugin.gd`). Editor
## services resolve as typed native calls; the documented transitional
## callbacks and member accesses are dynamic and flagged unsafe by design.
var m_plugin: EditorPlugin


func _init(plugin: EditorPlugin) -> void:
	m_plugin = plugin


# --- Editor services ---


func editor_interface() -> EditorInterface:
	return m_plugin.get_editor_interface()


func undo_redo() -> EditorUndoRedoManager:
	return m_plugin.get_undo_redo()


func handled() -> int:
	m_plugin.get_viewport().set_input_as_handled()
	return EditorPlugin.AFTER_GUI_INPUT_STOP


func set_status(text: String) -> void:
	var dock: Control = m_plugin.m_dock
	if dock != null and dock.has_method("set_status"):
		dock.set_status(text)


# --- Coordinator resolution ---


func get_or_create_coordinator(create_if_missing: bool) -> Building3DScript:
	var scene_root := editor_interface().get_edited_scene_root()
	if scene_root == null:
		return null
	var selected := find_selected_coordinator()
	if selected != null:
		m_plugin.m_active_coordinator = selected
	elif !coordinator_belongs_to_scene(
		m_plugin.m_active_coordinator as Building3DScript, scene_root
	):
		m_plugin.m_active_coordinator = find_first_coordinator(scene_root)
	var active := m_plugin.m_active_coordinator as Building3DScript
	if active != null or !create_if_missing:
		return active
	return create_coordinator()


func create_coordinator() -> Building3DScript:
	var scene_root := editor_interface().get_edited_scene_root()
	if scene_root == null:
		return null
	var coordinator := Building3DScript.new() as Building3DScript
	coordinator.name = _unique_coordinator_name(scene_root)
	m_plugin.m_active_coordinator = coordinator
	var undo := undo_redo()
	undo.create_action("Create Building")
	undo.add_do_reference(coordinator)
	undo.add_do_method(m_plugin, "_do_add_node", scene_root, coordinator, scene_root, true)
	undo.add_undo_method(m_plugin, "_undo_remove_node", scene_root, coordinator)
	undo.commit_action()
	m_plugin._refresh_dock_context()
	return coordinator


func find_selected_coordinator() -> Building3DScript:
	var selection := editor_interface().get_selection()
	if selection == null:
		return null
	for node in selection.get_selected_nodes():
		var coordinator := find_coordinator_from_node(node)
		if coordinator != null:
			return coordinator
	return null


func coordinator_belongs_to_scene(coordinator: Building3DScript, scene_root: Node) -> bool:
	if coordinator == null or !is_instance_valid(coordinator) or scene_root == null:
		return false
	return coordinator == scene_root or scene_root.is_ancestor_of(coordinator)


func find_coordinator_from_node(node: Node) -> Building3DScript:
	var cursor := node
	while cursor != null:
		if cursor is Building3DScript:
			return cursor as Building3DScript
		cursor = cursor.get_parent()
	return null


func find_first_coordinator(root: Node) -> Building3DScript:
	if root is Building3DScript:
		return root as Building3DScript
	for child in root.get_children():
		var found := find_first_coordinator(child)
		if found != null:
			return found
	return null


func _unique_coordinator_name(scene_root: Node) -> String:
	const BASE_NAME := "Building3D"
	if !_scene_has_coordinator_name(scene_root, BASE_NAME):
		return BASE_NAME
	var index := 2
	var candidate := "%s%d" % [BASE_NAME, index]
	while _scene_has_coordinator_name(scene_root, candidate):
		index += 1
		candidate = "%s%d" % [BASE_NAME, index]
	return candidate


func _scene_has_coordinator_name(root: Node, candidate: String) -> bool:
	if root is Building3DScript and String(root.name) == candidate:
		return true
	for child in root.get_children():
		if _scene_has_coordinator_name(child, candidate):
			return true
	return false


# --- Snapping, raycasting, and plan geometry ---


func snap_world_position(world_position: Vector3, grid_step: float) -> Vector3:
	var coordinator := get_or_create_coordinator(false)
	var step := maxf(grid_step, 0.05)
	return BuildingFactoryScript.snap_world_position(coordinator, world_position, step)


func raycast_world(
	camera: Camera3D,
	mouse_position: Vector2,
	include_walls: bool = true
) -> Dictionary:
	var origin := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	if include_walls:
		var wall_hit: Dictionary = m_plugin._raycast_walls(origin, direction)
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


func intersect_aabb_ray(
	origin: Vector3,
	direction: Vector3,
	min_corner: Vector3,
	max_corner: Vector3
) -> Dictionary:
	var t_min := -INF
	var t_max := INF
	for axis in range(3):
		var axis_origin := axis_value(origin, axis)
		var axis_direction := axis_value(direction, axis)
		var axis_min := axis_value(min_corner, axis)
		var axis_max := axis_value(max_corner, axis)
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


func axis_value(value: Vector3, axis: int) -> float:
	match axis:
		0:
			return value.x
		1:
			return value.y
		_:
			return value.z


func nearest_box_normal(point: Vector3, min_corner: Vector3, max_corner: Vector3) -> Vector3:
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


func closest_point_on_plan_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> Vector2:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return segment_start
	var ratio := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return segment_start + segment * ratio


# --- Preview plumbing ---


func set_preview_parent(preview: Node3D, parent: Node) -> void:
	if preview.get_parent() == parent:
		m_plugin.m_preview_parent = parent
		return
	if preview.get_parent() != null:
		preview.get_parent().remove_child(preview)
	parent.add_child(preview)
	preview.owner = null
	m_plugin.m_preview_parent = parent


func apply_preview_material(node: Node, color: Color) -> void:
	if node.has_meta(BuildingWireframeScript.GENERATED_META):
		return
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.material_override = build_preview_material(color)
	for child in node.get_children():
		apply_preview_material(child, color)


func build_preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# --- Node lifecycle used inside undo/redo actions ---


func do_add_node(parent: Node, node: Node, scene_root: Node, select_after_add: bool) -> void:
	if node.get_parent() != parent:
		parent.add_child(node)
	set_owner_recursive(node, scene_root)
	m_plugin._apply_debug_wireframe_to_node(node)
	if select_after_add:
		select_node(node)


func do_add_node_and_rebuild(parent: Node, node: Node, scene_root: Node, select_after_add: bool) -> void:
	do_add_node(parent, node, scene_root, select_after_add)
	if parent.has_method("rebuild_wall_mesh"):
		parent.rebuild_wall_mesh()


func do_add_node_and_refresh_wall_intersections(
	parent: Node,
	node: Node,
	scene_root: Node,
	select_after_add: bool,
	coordinator: Building3DScript
) -> void:
	do_add_node(parent, node, scene_root, select_after_add)
	m_plugin._refresh_wall_intersections(coordinator)


func do_add_node_and_refresh_roofs(
	parent: Node,
	node: Node,
	scene_root: Node,
	select_after_add: bool,
	coordinator: Building3DScript
) -> void:
	do_add_node(parent, node, scene_root, select_after_add)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_building_geometry_clips()


func undo_remove_node(parent: Node, node: Node) -> void:
	if node.get_parent() == parent:
		parent.remove_child(node)


func undo_remove_node_and_rebuild(parent: Node, node: Node) -> void:
	undo_remove_node(parent, node)
	if parent.has_method("rebuild_wall_mesh"):
		parent.rebuild_wall_mesh()


func undo_remove_node_and_refresh_wall_intersections(
	parent: Node,
	node: Node,
	coordinator: Building3DScript
) -> void:
	undo_remove_node(parent, node)
	m_plugin._refresh_wall_intersections(coordinator)


func undo_remove_node_and_refresh_roofs(parent: Node, node: Node, coordinator: Building3DScript) -> void:
	undo_remove_node(parent, node)
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.refresh_building_geometry_clips()


func set_owner_recursive(node: Node, scene_root: Node) -> void:
	if (
		node.has_meta(Wall3DScript.GENERATED_META)
		or node.has_meta(Floor3DScript.GENERATED_META)
		or node.has_meta(Stairs3DScript.GENERATED_META)
		or node.has_meta(Rail3DScript.GENERATED_META)
		or node.has_meta(Pillar3DScript.GENERATED_META)
		or node.has_meta(Roof3DScript.GENERATED_META)
		or node.has_meta(BuildingOpening3DScript.GENERATED_META)
	):
		node.owner = null
	else:
		node.owner = scene_root
	for child in node.get_children():
		set_owner_recursive(child, scene_root)


func select_node(node: Node) -> void:
	var selection := editor_interface().get_selection()
	selection.clear()
	selection.add_node(node)
	editor_interface().edit_node(node)
