class_name NpcRouteDebugDrawer
extends Node2D

var app_state: Node = null
var resident_root: Node2D = null

var debug_draw_npc_routes: bool = false:
	set(value):
		if debug_draw_npc_routes == value:
			return
		debug_draw_npc_routes = value
		set_process(debug_draw_npc_routes)
		queue_redraw()

var debug_npc_route_filter: String = "":
	set(value):
		var normalized_value := value.strip_edges()
		if debug_npc_route_filter == normalized_value:
			return
		debug_npc_route_filter = normalized_value
		queue_redraw()

var debug_draw_npc_route_labels: bool = true:
	set(value):
		if debug_draw_npc_route_labels == value:
			return
		debug_draw_npc_route_labels = value
		queue_redraw()


func _ready() -> void:
	set_process(debug_draw_npc_routes)


func _process(_delta: float) -> void:
	if !debug_draw_npc_routes:
		return
	queue_redraw()


func _draw() -> void:
	if !debug_draw_npc_routes:
		return
	if !is_instance_valid(resident_root):
		return

	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(12, ThemeDB.fallback_font_size - 2)
	for child in resident_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue

		var controller := resident.controller as NPCController
		if controller == null or controller.m_route_points.size() < 2:
			continue
		if !_npc_route_matches_debug_filter(resident, controller):
			continue

		_draw_npc_route_debug(resident, controller, font, font_size)


func _draw_npc_route_debug(
	resident: HumanBody2D,
	controller: NPCController,
	font: Font,
	font_size: int
) -> void:
	var route_points: Array[Dictionary] = controller.m_route_points
	if route_points.size() < 2:
		return

	var resident_id: String = controller.get_resident_id()
	var display_name: String = String(resident.name)
	if app_state != null and !resident_id.is_empty():
		display_name = app_state.get_resident_display_name(resident_id)

	var color_key: String = resident_id if !resident_id.is_empty() else display_name
	var base_color: Color = _npc_route_debug_color(color_key)
	var line_color := Color(base_color.r, base_color.g, base_color.b, 0.78)
	var fill_color := Color(base_color.r, base_color.g, base_color.b, 0.22)
	var bypass_color := Color(1.0, 0.72, 0.28, 0.95)

	for i in range(route_points.size() - 1):
		var from_position: Vector2 = route_points[i].get("position", Vector2.ZERO)
		var to_position: Vector2 = route_points[i + 1].get("position", Vector2.ZERO)
		draw_line(to_local(from_position), to_local(to_position), line_color, 3.0, true)

	if !controller.m_route_ping_pong and route_points.size() > 2:
		var loop_start: Vector2 = route_points[0].get("position", Vector2.ZERO)
		var loop_end: Vector2 = route_points[route_points.size() - 1].get("position", Vector2.ZERO)
		draw_line(
			to_local(loop_end),
			to_local(loop_start),
			Color(base_color.r, base_color.g, base_color.b, 0.35),
			2.0,
			true
		)

	for i in range(route_points.size()):
		var route_point := route_points[i]
		var point_position: Vector2 = route_point.get("position", Vector2.ZERO)
		var point_local := to_local(point_position)
		var is_active_point := i == controller.m_route_index
		var radius := 11.0 if is_active_point else 8.0
		draw_circle(point_local, radius, fill_color)
		draw_arc(point_local, radius, 0.0, TAU, 32, base_color, 2.0)

		if bool(route_point.get("allow_collision_bypass", false)):
			draw_arc(point_local, radius + 4.0, 0.0, TAU, 24, bypass_color, 1.5)

		if debug_draw_npc_route_labels and font != null:
			draw_string(
				font,
				point_local + Vector2(radius + 4.0, -6.0),
				str(i),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_size,
				Color.WHITE
			)

	var resident_local := to_local(resident.global_position)
	draw_circle(resident_local, 6.0, Color(1.0, 1.0, 1.0, 0.92))
	draw_arc(resident_local, 10.0, 0.0, TAU, 32, base_color, 2.0)

	if controller.m_route_index >= 0 and controller.m_route_index < route_points.size():
		var active_position: Vector2 = route_points[controller.m_route_index].get("position", resident.global_position)
		draw_line(resident_local, to_local(active_position), Color(1.0, 1.0, 1.0, 0.78), 2.0, true)

	if debug_draw_npc_route_labels and font != null:
		var label := "%s [%d]" % [display_name, controller.m_route_index]
		draw_string(
			font,
			resident_local + Vector2(14.0, -12.0),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color.WHITE
		)


func _npc_route_matches_debug_filter(resident: HumanBody2D, controller: NPCController) -> bool:
	if debug_npc_route_filter.is_empty():
		return true

	var filter_text := debug_npc_route_filter.to_lower()
	var resident_id := controller.get_resident_id().to_lower()
	var display_name := resident.name.to_lower()
	return resident_id.contains(filter_text) or display_name.contains(filter_text)


func _npc_route_debug_color(color_key: String) -> Color:
	var hue_seed := absi(color_key.hash()) % 1024
	return Color.from_hsv(float(hue_seed) / 1024.0, 0.72, 1.0, 0.95)
