@tool
class_name RainGroundImpacts
extends Node2D


class ImpactState:
	var active: bool = false
	var position: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var lifetime: float = 0.24
	var scale: float = 1.0
	var drift: Vector2 = Vector2.ZERO


@export var rain_overlay_path: NodePath
@export var spawn_layer_path: NodePath

@export var iso_tile_size: Vector2 = Vector2(64.0, 32.0):
	set(value):
		iso_tile_size = Vector2(max(value.x, 1.0), max(value.y, 1.0))
		queue_redraw()

@export var cell_jitter_ratio: Vector2 = Vector2(0.24, 0.18):
	set(value):
		cell_jitter_ratio = Vector2(clampf(value.x, 0.0, 0.5), clampf(value.y, 0.0, 0.5))

@export var max_impacts: int = 32:
	set(value):
		max_impacts = maxi(value, 1)
		_ensure_pool()

@export var base_spawn_rate: float = 8.0:
	set(value):
		base_spawn_rate = max(value, 0.0)

@export var density_spawn_multiplier: float = 6000.0:
	set(value):
		density_spawn_multiplier = max(value, 0.0)

@export_range(0.0, 1.0, 0.01) var spawn_top_ratio: float = 0.58:
	set(value):
		spawn_top_ratio = clamp(value, 0.0, 1.0)

@export var side_margin: float = 96.0:
	set(value):
		side_margin = max(value, 0.0)

@export var bottom_margin: float = 36.0:
	set(value):
		bottom_margin = max(value, 0.0)

@export var streak_duration: float = 0.05:
	set(value):
		streak_duration = max(value, 0.01)

@export var lifetime_min: float = 0.18:
	set(value):
		lifetime_min = max(value, 0.05)
		lifetime_max = max(lifetime_max, lifetime_min)

@export var lifetime_max: float = 0.28:
	set(value):
		lifetime_max = max(value, lifetime_min)

@export var scale_min: float = 4.0:
	set(value):
		scale_min = max(value, 0.5)
		scale_max = max(scale_max, scale_min)

@export var scale_max: float = 7.5:
	set(value):
		scale_max = max(value, scale_min)

@export var ripple_aspect: Vector2 = Vector2.ONE:
	set(value):
		ripple_aspect = Vector2(max(value.x, 0.1), max(value.y, 0.1))

@export_range(6, 16, 1) var ripple_segments: int = 10:
	set(value):
		ripple_segments = clampi(value, 6, 16)
		queue_redraw()

@export var drift_strength: float = 8.0:
	set(value):
		drift_strength = max(value, 0.0)

@export var fallback_angle_degrees: float = 72.0:
	set(value):
		fallback_angle_degrees = value

@export var impact_color: Color = Color(0.941176, 0.976471, 1.0, 0.3):
	set(value):
		impact_color = value
		queue_redraw()

@export var ripple_color: Color = Color(0.776471, 0.901961, 0.972549, 0.24):
	set(value):
		ripple_color = value
		queue_redraw()

var m_impacts: Array[ImpactState] = []
var m_rng := RandomNumberGenerator.new()
var m_spawn_accumulator: float = 0.0
var m_rain_overlay: RainOverlay = null
var m_spawn_layer: TileMapLayer = null


func _ready() -> void:
	m_rng.randomize()
	_ensure_pool()
	_resolve_rain_overlay()
	_resolve_spawn_layer()
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_resolve_rain_overlay()
	_resolve_spawn_layer()
	var camera_rect := _get_camera_world_rect()
	if camera_rect.size == Vector2.ZERO:
		return

	var needs_redraw := false
	for impact in m_impacts:
		if not impact.active:
			continue
		impact.age += delta
		if impact.age >= impact.lifetime:
			impact.active = false
			needs_redraw = true
			continue
		needs_redraw = true

	var target_spawn_rate := base_spawn_rate + _get_rain_density() * density_spawn_multiplier
	if target_spawn_rate > 0.0:
		m_spawn_accumulator += target_spawn_rate * delta
		var spawn_count := mini(int(m_spawn_accumulator), max_impacts)
		if spawn_count > 0:
			m_spawn_accumulator -= float(spawn_count)
			for _i in range(spawn_count):
				if _spawn_impact(camera_rect):
					needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _draw() -> void:
	var rain_dir := _get_rain_direction()
	for impact in m_impacts:
		if not impact.active:
			continue

		var progress := clampf(impact.age / impact.lifetime, 0.0, 1.0)
		var world_pos := impact.position + impact.drift * progress
		var local_pos := to_local(world_pos)
		var ripple_alpha := ripple_color.a * (1.0 - progress)
		var ripple_scale := impact.scale * lerpf(0.4, 0.72, progress)
		var ring_points := _build_isometric_ring(local_pos, ripple_scale)
		var outline_width := maxf(1.0, impact.scale * 0.08)
		draw_polyline(ring_points, Color(ripple_color.r, ripple_color.g, ripple_color.b, ripple_alpha), outline_width, true)

		if impact.age <= streak_duration:
			var flash: float = 1.0 - (impact.age / streak_duration)
			var streak_length: float = impact.scale * lerpf(1.2, 0.55, progress)
			var streak_color := Color(impact_color.r, impact_color.g, impact_color.b, impact_color.a * flash)
			draw_line(
				local_pos - rain_dir * streak_length,
				local_pos + rain_dir * (streak_length * 0.35),
				streak_color,
				maxf(1.0, impact.scale * 0.14),
				true
			)
			var spark_radius: float = maxf(0.8, impact.scale * 0.08)
			draw_line(
				local_pos - _get_iso_axis_y().normalized() * spark_radius,
				local_pos + _get_iso_axis_x().normalized() * spark_radius,
				streak_color,
				1.0,
				true
			)


func _ensure_pool() -> void:
	while m_impacts.size() < max_impacts:
		m_impacts.append(ImpactState.new())
	while m_impacts.size() > max_impacts:
		m_impacts.pop_back()


func clear_impacts() -> void:
	var had_active := false
	for impact in m_impacts:
		if impact.active:
			impact.active = false
			had_active = true

	m_spawn_accumulator = 0.0
	if had_active:
		queue_redraw()


func _resolve_rain_overlay() -> void:
	if has_node(rain_overlay_path):
		m_rain_overlay = get_node(rain_overlay_path) as RainOverlay


func _resolve_spawn_layer() -> void:
	if has_node(spawn_layer_path):
		m_spawn_layer = get_node(spawn_layer_path) as TileMapLayer


func _get_camera_world_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()

	var camera := viewport.get_camera_2d()
	if camera == null:
		return Rect2()

	var visible_size := Vector2(viewport.size) / camera.zoom
	return Rect2(camera.global_position - visible_size * 0.5, visible_size)


func _get_rain_density() -> float:
	if is_instance_valid(m_rain_overlay):
		return m_rain_overlay.density
	return 0.0


func _get_rain_direction() -> Vector2:
	if is_instance_valid(m_rain_overlay):
		return Vector2.RIGHT.rotated(deg_to_rad(m_rain_overlay.wind_angle_degrees)).normalized()
	return Vector2.RIGHT.rotated(deg_to_rad(fallback_angle_degrees)).normalized()


func _get_active_iso_tile_size() -> Vector2:
	if is_instance_valid(m_spawn_layer) and m_spawn_layer.tile_set != null:
		return Vector2(m_spawn_layer.tile_set.tile_size)
	return iso_tile_size


func _spawn_impact(camera_rect: Rect2) -> bool:
	var impact := _find_free_impact()
	if impact == null:
		return false

	var left := camera_rect.position.x + side_margin
	var right := camera_rect.end.x - side_margin
	var top := lerpf(camera_rect.position.y, camera_rect.end.y, spawn_top_ratio)
	var bottom := camera_rect.end.y - bottom_margin
	if right <= left or bottom <= top:
		return false

	var candidate_rect := Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
	var snapped_pos := _sample_spawn_position(candidate_rect)
	if not snapped_pos.is_finite():
		return false
	var axis_x := _get_iso_axis_x()
	var axis_y := _get_iso_axis_y()
	var jitter := axis_x * m_rng.randf_range(-cell_jitter_ratio.x, cell_jitter_ratio.x)
	jitter += axis_y * m_rng.randf_range(-cell_jitter_ratio.y, cell_jitter_ratio.y)

	impact.active = true
	impact.position = snapped_pos + jitter
	impact.age = 0.0
	impact.lifetime = m_rng.randf_range(lifetime_min, lifetime_max)
	impact.scale = m_rng.randf_range(scale_min, scale_max)
	impact.drift = _get_rain_direction() * m_rng.randf_range(1.5, drift_strength)
	return true


func _find_free_impact() -> ImpactState:
	for impact in m_impacts:
		if not impact.active:
			return impact
	return null


func _get_iso_axis_x() -> Vector2:
	var active_tile_size := _get_active_iso_tile_size()
	return Vector2(active_tile_size.x * 0.5, active_tile_size.y * 0.5)


func _get_iso_axis_y() -> Vector2:
	var active_tile_size := _get_active_iso_tile_size()
	return Vector2(-active_tile_size.x * 0.5, active_tile_size.y * 0.5)


func _build_isometric_ring(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var axis_x := _get_iso_axis_x().normalized() * radius * ripple_aspect.x
	var axis_y := _get_iso_axis_y().normalized() * radius * ripple_aspect.y
	for i in range(ripple_segments + 1):
		var t := TAU * float(i) / float(ripple_segments)
		points.append(center + axis_x * cos(t) + axis_y * sin(t))
	return points


func _sample_spawn_position(candidate_rect: Rect2) -> Vector2:
	if is_instance_valid(m_spawn_layer) and m_spawn_layer.tile_set != null:
		var candidate_cells := _collect_spawn_cells(candidate_rect)
		if candidate_cells.is_empty():
			var fallback_rect := _get_camera_world_rect().grow(maxf(_get_active_iso_tile_size().x, _get_active_iso_tile_size().y))
			candidate_cells = _collect_spawn_cells(fallback_rect)
		if candidate_cells.is_empty():
			return Vector2(INF, INF)
		return candidate_cells[m_rng.randi_range(0, candidate_cells.size() - 1)]

	for _i in range(10):
		var candidate := Vector2(
			m_rng.randf_range(candidate_rect.position.x, candidate_rect.end.x),
			m_rng.randf_range(candidate_rect.position.y, candidate_rect.end.y)
		)
		return TileMapUtils.snap_to_iso_grid(candidate, _get_active_iso_tile_size())
	return Vector2(INF, INF)


func _collect_spawn_cells(candidate_rect: Rect2) -> Array[Vector2]:
	var spawn_points: Array[Vector2] = []
	var expanded_rect := candidate_rect.grow(maxf(_get_active_iso_tile_size().x, _get_active_iso_tile_size().y) * 0.5)
	for cell in m_spawn_layer.get_used_cells():
		var world_pos := m_spawn_layer.to_global(m_spawn_layer.map_to_local(cell))
		if expanded_rect.has_point(world_pos):
			spawn_points.append(world_pos)

	return spawn_points
