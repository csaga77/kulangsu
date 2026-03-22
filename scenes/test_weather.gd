@tool
extends Node2D

const TERRAIN_TILESET := preload("res://resources/tilesets/terrain_0_tiles.tres")
const WATER_MATERIAL := preload("res://resources/materials/water.tres")

const PIER_POLYGON := [
	Vector2(-110.0, 566.0),
	Vector2(1180.0, 470.0),
	Vector2(1370.0, 620.0),
	Vector2(60.0, 756.0),
]
const BACKDROP_ISLAND_POLYGON := [
	Vector2(-120.0, 350.0),
	Vector2(40.0, 280.0),
	Vector2(190.0, 298.0),
	Vector2(320.0, 224.0),
	Vector2(420.0, 254.0),
	Vector2(575.0, 198.0),
	Vector2(720.0, 246.0),
	Vector2(885.0, 182.0),
	Vector2(1020.0, 260.0),
	Vector2(1180.0, 214.0),
	Vector2(1360.0, 330.0),
	Vector2(1360.0, 450.0),
	Vector2(-120.0, 450.0),
]

const TERRAIN_SOURCE_ID := 8
const TERRAIN_TILE_VARIANTS := [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(3, 0),
	Vector2i(4, 0),
	Vector2i(5, 0),
	Vector2i(6, 0),
	Vector2i(7, 0),
	Vector2i(8, 0),
	Vector2i(9, 0),
	Vector2i(0, 2),
	Vector2i(1, 2),
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(4, 2),
	Vector2i(5, 2),
	Vector2i(6, 2),
	Vector2i(7, 2),
	Vector2i(8, 2),
	Vector2i(9, 2),
]
const WATER_TILE_COORDS := Vector2i(4, 16)
const WATER_TILE_ALTERNATIVE := 0
const WATER_FILL_MARGIN := Vector2(320.0, 240.0)
const WEATHER_CONTROLS_VISIBLE_TEXT := "Hide Weather Controls"
const WEATHER_CONTROLS_HIDDEN_TEXT := "Show Weather Controls"
const THUNDER_FILL_COLOR := Color(0.97, 0.98, 1.0, 0.0)
const THUNDER_GLOW_COLOR := Color(0.82, 0.9, 1.0, 0.0)
const THUNDER_FIRST_DELAY_MIN := 1.2
const THUNDER_FIRST_DELAY_MAX := 2.8
const THUNDER_MIN_DELAY := 3.0
const THUNDER_MAX_DELAY := 6.5

@export var rebuild_environment: bool = false:
	set(value):
		if not value:
			return
		rebuild_environment = false
		if is_node_ready():
			_rebuild_environment()

@export var rebuild_ground: bool = false:
	set(value):
		if not value:
			return
		rebuild_ground = false
		if is_node_ready():
			_rebuild_ground()

var m_player_controller: PlayerController = null
var m_closest_object: Node2D = null
var m_weather_defaults: Dictionary = {}
var m_rain_enabled := true
var m_thunder_enabled := false
var m_thunder_strength := 0.65
var m_thunder_wait_remaining := 0.0
var m_thunder_segments: Array[Dictionary] = []
var m_thunder_segment_index := -1
var m_thunder_segment_elapsed := 0.0
var m_thunder_segment_start_alpha := 0.0
var m_thunder_current_alpha := 0.0
var m_thunder_rng := RandomNumberGenerator.new()
var m_weather_controls_visible := true

@onready var m_water: TileMapLayer = $Water
@onready var m_backdrop_terrain: TileMapLayer = $BackdropTerrain
@onready var m_ground: TileMapLayer = $Ground
@onready var m_ground_impacts: RainGroundImpacts = $GroundImpacts
@onready var m_player: HumanBody2D = $Actors/Player
@onready var m_rain_overlay: RainOverlay = $WeatherLayer/RainOverlay
@onready var m_thunder_fill: ColorRect = $ThunderLayer/ThunderFill
@onready var m_thunder_glow: ColorRect = $ThunderLayer/ThunderGlow
@onready var m_toggle_weather_controls_button: Button = $WeatherControlsLayer/ToggleWeatherControlsButton
@onready var m_weather_panel: PanelContainer = $WeatherControlsLayer/WeatherPanel
@onready var m_rain_enabled_button: CheckButton = $WeatherControlsLayer/WeatherPanel/Margin/Body/RainEnabledButton
@onready var m_thunder_enabled_button: CheckButton = $WeatherControlsLayer/WeatherPanel/Margin/Body/ThunderEnabledButton
@onready var m_density_slider: HSlider = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/DensitySlider
@onready var m_density_value: Label = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/DensityValue
@onready var m_angle_slider: HSlider = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/AngleSlider
@onready var m_angle_value: Label = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/AngleValue
@onready var m_wind_strength_slider: HSlider = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/WindStrengthSlider
@onready var m_wind_strength_value: Label = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/WindStrengthValue
@onready var m_drop_speed_slider: HSlider = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/DropSpeedSlider
@onready var m_drop_speed_value: Label = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/DropSpeedValue
@onready var m_drop_size_slider: HSlider = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/DropSizeSlider
@onready var m_drop_size_value: Label = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/DropSizeValue
@onready var m_thunder_strength_slider: HSlider = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/ThunderStrengthSlider
@onready var m_thunder_strength_value: Label = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/ThunderStrengthValue
@onready var m_impact_gain_slider: HSlider = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/ImpactGainSlider
@onready var m_impact_gain_value: Label = $WeatherControlsLayer/WeatherPanel/Margin/Body/ControlsGrid/ImpactGainValue
@onready var m_trigger_thunder_button: Button = $WeatherControlsLayer/WeatherPanel/Margin/Body/TriggerThunderButton
@onready var m_reset_weather_controls_button: Button = $WeatherControlsLayer/WeatherPanel/Margin/Body/ResetWeatherButton


func _ready() -> void:
	m_thunder_rng.randomize()
	_rebuild_environment()
	_rebuild_ground()
	_setup_weather_controls()
	if Engine.is_editor_hint():
		return

	GameGlobal.get_instance().set_player(m_player)
	if !AppState.player_appearance_changed.is_connected(_on_player_appearance_changed):
		AppState.player_appearance_changed.connect(_on_player_appearance_changed)

	m_player_controller = m_player.controller as PlayerController
	_apply_player_costume()
	if m_player_controller != null:
		if !m_player_controller.closest_object_changed.is_connected(_on_closest_object_changed):
			m_player_controller.closest_object_changed.connect(_on_closest_object_changed)
		if !m_player_controller.inspect_requested.is_connected(_on_player_inspect_requested):
			m_player_controller.inspect_requested.connect(_on_player_inspect_requested)
	AppState.set_residents(AppState.get_known_resident_names())


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_thunder(delta)


func _rebuild_environment() -> void:
	_rebuild_water()
	_rebuild_backdrop_terrain()


func _rebuild_water() -> void:
	if not is_instance_valid(m_water):
		return

	m_water.tile_set = TERRAIN_TILESET
	m_water.material = WATER_MATERIAL
	m_water.y_sort_enabled = false
	m_water.clear()

	var scene_bounds := _get_scene_bounds()
	var water_bounds := Rect2(
		scene_bounds.position - WATER_FILL_MARGIN,
		scene_bounds.size + WATER_FILL_MARGIN * 2.0
	)
	_fill_rect_layer(m_water, water_bounds, TERRAIN_SOURCE_ID, WATER_TILE_COORDS, WATER_TILE_ALTERNATIVE)


func _rebuild_backdrop_terrain() -> void:
	if not is_instance_valid(m_backdrop_terrain):
		return

	m_backdrop_terrain.tile_set = TERRAIN_TILESET
	m_backdrop_terrain.material = null
	m_backdrop_terrain.y_sort_enabled = false
	m_backdrop_terrain.clear()
	_fill_polygon_with_variants(
		m_backdrop_terrain,
		BACKDROP_ISLAND_POLYGON,
		TERRAIN_SOURCE_ID,
		TERRAIN_TILE_VARIANTS
	)


func _rebuild_ground() -> void:
	if not is_instance_valid(m_ground):
		return

	m_ground.tile_set = TERRAIN_TILESET
	m_ground.y_sort_enabled = false
	m_ground.clear()
	_fill_polygon_with_variants(m_ground, PIER_POLYGON, TERRAIN_SOURCE_ID, TERRAIN_TILE_VARIANTS)


func _fill_polygon_with_variants(
	layer: TileMapLayer,
	polygon_world: Array,
	source_id: int,
	tile_variants: Array
) -> void:
	if polygon_world.is_empty() or tile_variants.is_empty():
		return

	var polygon_map := PackedVector2Array()
	for point: Vector2 in polygon_world:
		polygon_map.append(_world_to_iso_map_coords(layer, point))

	var bounds := Rect2(polygon_map[0], Vector2.ZERO)
	for point in polygon_map:
		bounds = bounds.expand(point)

	var min_cell := Vector2i(floori(bounds.position.x) - 2, floori(bounds.position.y) - 2)
	var max_cell := Vector2i(ceili(bounds.end.x) + 2, ceili(bounds.end.y) + 2)

	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(x, y)
			var cell_center := Vector2(float(x), float(y))
			if not Geometry2D.is_point_in_polygon(cell_center, polygon_map):
				continue
			var index := posmod(cell.x * 3 + cell.y * 5, tile_variants.size())
			layer.set_cell(cell, source_id, tile_variants[index], 0)


func _fill_rect_layer(
	layer: TileMapLayer,
	world_rect: Rect2,
	source_id: int,
	tile_coords: Vector2i,
	alternative: int
) -> void:
	var top_left := layer.local_to_map(layer.to_local(world_rect.position))
	var top_right := layer.local_to_map(layer.to_local(Vector2(world_rect.end.x, world_rect.position.y)))
	var bottom_left := layer.local_to_map(layer.to_local(Vector2(world_rect.position.x, world_rect.end.y)))
	var bottom_right := layer.local_to_map(layer.to_local(world_rect.end))

	var min_x := mini(mini(top_left.x, top_right.x), mini(bottom_left.x, bottom_right.x))
	var max_x := maxi(maxi(top_left.x, top_right.x), maxi(bottom_left.x, bottom_right.x))
	var min_y := mini(mini(top_left.y, top_right.y), mini(bottom_left.y, bottom_right.y))
	var max_y := maxi(maxi(top_left.y, top_right.y), maxi(bottom_left.y, bottom_right.y))

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			layer.set_cell(Vector2i(x, y), source_id, tile_coords, alternative)


func _get_scene_bounds() -> Rect2:
	var bounds := Rect2(PIER_POLYGON[0], Vector2.ZERO)
	for point: Vector2 in PIER_POLYGON:
		bounds = bounds.expand(point)
	for point: Vector2 in BACKDROP_ISLAND_POLYGON:
		bounds = bounds.expand(point)
	return bounds


func _world_to_iso_map_coords(layer: TileMapLayer, world_pos: Vector2) -> Vector2:
	var local_pos := layer.to_local(world_pos)
	var tile_size := Vector2.ONE
	if layer.tile_set != null:
		tile_size = Vector2(layer.tile_set.tile_size)
	else:
		tile_size = Vector2(64.0, 32.0)

	var tile_width := maxf(tile_size.x, 1.0)
	var tile_height := maxf(tile_size.y, 1.0)
	var map_x := local_pos.x / tile_width + local_pos.y / tile_height
	var map_y := local_pos.y / tile_height - local_pos.x / tile_width
	return Vector2(map_x, map_y)


func _on_player_appearance_changed(_profile: Dictionary, _appearance_config: Dictionary) -> void:
	_apply_player_costume()


func _apply_player_costume() -> void:
	if !is_instance_valid(m_player):
		return

	var appearance_config := AppState.get_player_appearance_config()
	if appearance_config.is_empty():
		return

	m_player.set_configuration(appearance_config)


func _on_closest_object_changed(new_object: Node2D) -> void:
	m_closest_object = new_object


func _on_player_inspect_requested() -> void:
	var resident_controller := _get_resident_controller(m_closest_object)
	if resident_controller == null:
		return

	var resident_id := resident_controller.get_resident_id()
	var interaction := AppState.interact_with_resident(resident_id)
	var dialogue_line := String(interaction.get("line", ""))
	resident_controller.reveal_dialogue(dialogue_line)
	AppState.set_residents(AppState.get_known_resident_names())


func _get_resident_controller(target: Node2D) -> NPCController:
	var human := target as HumanBody2D
	if human == null:
		return null
	return human.controller as NPCController


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_set_weather_controls_visible(not m_weather_controls_visible)
		get_viewport().set_input_as_handled()


func _setup_weather_controls() -> void:
	if not is_instance_valid(m_weather_panel):
		return

	m_weather_panel.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_disable_focus_for_control(m_toggle_weather_controls_button)
	_disable_focus_for_control(m_weather_panel)
	_connect_weather_controls()
	_capture_weather_defaults()
	_apply_rain_enabled(m_rain_enabled)
	_apply_thunder_strength(m_thunder_strength)
	_apply_thunder_enabled(m_thunder_enabled)
	_sync_weather_controls_from_scene()
	_set_weather_controls_visible(m_weather_controls_visible)


func _disable_focus_for_control(control: Control) -> void:
	if control == null:
		return

	control.focus_mode = Control.FOCUS_NONE
	for child in control.get_children():
		var child_control := child as Control
		if child_control != null:
			_disable_focus_for_control(child_control)


func _connect_weather_controls() -> void:
	if not m_toggle_weather_controls_button.pressed.is_connected(_on_toggle_weather_controls_pressed):
		m_toggle_weather_controls_button.pressed.connect(_on_toggle_weather_controls_pressed)
	if not m_rain_enabled_button.toggled.is_connected(_on_rain_enabled_toggled):
		m_rain_enabled_button.toggled.connect(_on_rain_enabled_toggled)
	if not m_thunder_enabled_button.toggled.is_connected(_on_thunder_enabled_toggled):
		m_thunder_enabled_button.toggled.connect(_on_thunder_enabled_toggled)
	if not m_density_slider.value_changed.is_connected(_on_density_slider_changed):
		m_density_slider.value_changed.connect(_on_density_slider_changed)
	if not m_angle_slider.value_changed.is_connected(_on_angle_slider_changed):
		m_angle_slider.value_changed.connect(_on_angle_slider_changed)
	if not m_wind_strength_slider.value_changed.is_connected(_on_wind_strength_slider_changed):
		m_wind_strength_slider.value_changed.connect(_on_wind_strength_slider_changed)
	if not m_drop_speed_slider.value_changed.is_connected(_on_drop_speed_slider_changed):
		m_drop_speed_slider.value_changed.connect(_on_drop_speed_slider_changed)
	if not m_drop_size_slider.value_changed.is_connected(_on_drop_size_slider_changed):
		m_drop_size_slider.value_changed.connect(_on_drop_size_slider_changed)
	if not m_thunder_strength_slider.value_changed.is_connected(_on_thunder_strength_slider_changed):
		m_thunder_strength_slider.value_changed.connect(_on_thunder_strength_slider_changed)
	if not m_impact_gain_slider.value_changed.is_connected(_on_impact_gain_slider_changed):
		m_impact_gain_slider.value_changed.connect(_on_impact_gain_slider_changed)
	if not m_trigger_thunder_button.pressed.is_connected(_on_trigger_thunder_pressed):
		m_trigger_thunder_button.pressed.connect(_on_trigger_thunder_pressed)
	if not m_reset_weather_controls_button.pressed.is_connected(_on_reset_weather_controls_pressed):
		m_reset_weather_controls_button.pressed.connect(_on_reset_weather_controls_pressed)


func _capture_weather_defaults() -> void:
	if not is_instance_valid(m_rain_overlay) or not is_instance_valid(m_ground_impacts):
		return

	m_rain_enabled = m_rain_overlay.visible and m_ground_impacts.visible
	m_thunder_enabled = m_thunder_enabled_button.button_pressed
	m_thunder_strength = m_thunder_strength_slider.value
	m_weather_defaults = {
		"rain_enabled": m_rain_enabled,
		"thunder_enabled": m_thunder_enabled,
		"thunder_strength": m_thunder_strength,
		"density": m_rain_overlay.density,
		"wind_angle_degrees": m_rain_overlay.wind_angle_degrees,
		"wind_strength": m_rain_overlay.wind_strength,
		"drop_speed": m_rain_overlay.drop_speed,
		"drop_size": m_rain_overlay.drop_size,
		"impact_gain": m_ground_impacts.density_spawn_multiplier,
	}


func _sync_weather_controls_from_scene() -> void:
	if not is_instance_valid(m_rain_overlay) or not is_instance_valid(m_ground_impacts):
		return

	m_rain_enabled_button.set_pressed_no_signal(m_rain_enabled)
	m_thunder_enabled_button.set_pressed_no_signal(m_thunder_enabled)
	m_density_slider.set_value_no_signal(m_rain_overlay.density)
	m_angle_slider.set_value_no_signal(m_rain_overlay.wind_angle_degrees)
	m_wind_strength_slider.set_value_no_signal(m_rain_overlay.wind_strength)
	m_drop_speed_slider.set_value_no_signal(m_rain_overlay.drop_speed)
	m_drop_size_slider.set_value_no_signal(m_rain_overlay.drop_size)
	m_thunder_strength_slider.set_value_no_signal(m_thunder_strength)
	m_impact_gain_slider.set_value_no_signal(m_ground_impacts.density_spawn_multiplier)
	_update_weather_value_labels()


func _update_weather_value_labels() -> void:
	m_density_value.text = "%.4f" % m_density_slider.value
	m_angle_value.text = "%d deg" % roundi(m_angle_slider.value)
	m_wind_strength_value.text = "%d" % roundi(m_wind_strength_slider.value)
	m_drop_speed_value.text = "%d" % roundi(m_drop_speed_slider.value)
	m_drop_size_value.text = "%.3f" % m_drop_size_slider.value
	m_thunder_strength_value.text = "%.2f" % m_thunder_strength_slider.value
	m_impact_gain_value.text = "%d" % roundi(m_impact_gain_slider.value)


func _set_weather_controls_visible(should_show: bool) -> void:
	m_weather_controls_visible = should_show
	if is_instance_valid(m_weather_panel):
		m_weather_panel.visible = should_show
	if is_instance_valid(m_toggle_weather_controls_button):
		m_toggle_weather_controls_button.text = (
			WEATHER_CONTROLS_VISIBLE_TEXT if should_show else WEATHER_CONTROLS_HIDDEN_TEXT
		)


func _apply_rain_enabled(should_enable: bool) -> void:
	m_rain_enabled = should_enable
	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.visible = should_enable
	if is_instance_valid(m_ground_impacts):
		if not should_enable:
			m_ground_impacts.clear_impacts()
		m_ground_impacts.visible = should_enable
	if is_instance_valid(m_rain_enabled_button):
		m_rain_enabled_button.set_pressed_no_signal(should_enable)


func _apply_thunder_enabled(should_enable: bool) -> void:
	m_thunder_enabled = should_enable
	if is_instance_valid(m_thunder_enabled_button):
		m_thunder_enabled_button.set_pressed_no_signal(should_enable)
	if should_enable:
		if not _thunder_is_active() and m_thunder_wait_remaining <= 0.0:
			_schedule_next_thunder_burst(true)
	else:
		_clear_active_thunder()


func _apply_thunder_strength(value: float) -> void:
	m_thunder_strength = clampf(value, 0.0, 1.0)
	if is_instance_valid(m_thunder_strength_slider):
		m_thunder_strength_slider.set_value_no_signal(m_thunder_strength)


func _update_thunder(delta: float) -> void:
	if _thunder_is_active():
		_advance_thunder_burst(delta)
		return

	if not m_thunder_enabled:
		return

	m_thunder_wait_remaining -= delta
	if m_thunder_wait_remaining <= 0.0:
		_start_random_thunder_burst()


func _schedule_next_thunder_burst(use_short_delay: bool = false) -> void:
	if use_short_delay:
		m_thunder_wait_remaining = m_thunder_rng.randf_range(THUNDER_FIRST_DELAY_MIN, THUNDER_FIRST_DELAY_MAX)
		return
	m_thunder_wait_remaining = m_thunder_rng.randf_range(THUNDER_MIN_DELAY, THUNDER_MAX_DELAY)


func _start_random_thunder_burst() -> void:
	_start_thunder_burst(_build_random_thunder_burst())


func _start_thunder_burst(segments: Array[Dictionary]) -> void:
	if segments.is_empty():
		return
	m_thunder_segments = segments
	m_thunder_segment_index = 0
	m_thunder_segment_elapsed = 0.0
	m_thunder_segment_start_alpha = m_thunder_current_alpha


func _build_random_thunder_burst() -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var primary_peak := lerpf(0.24, 0.74, m_thunder_strength) * m_thunder_rng.randf_range(0.92, 1.08)
	segments.append({"alpha": primary_peak, "duration": 0.03})
	segments.append({"alpha": 0.0, "duration": 0.11})
	if m_thunder_rng.randf() < 0.75:
		var secondary_peak := primary_peak * m_thunder_rng.randf_range(0.45, 0.78)
		segments.append({"alpha": secondary_peak, "duration": 0.026})
		segments.append({"alpha": 0.0, "duration": 0.16})
	if m_thunder_rng.randf() < 0.28:
		var tertiary_peak := primary_peak * m_thunder_rng.randf_range(0.2, 0.42)
		segments.append({"alpha": tertiary_peak, "duration": 0.02})
		segments.append({"alpha": 0.0, "duration": 0.18})
	return segments


func _advance_thunder_burst(delta: float) -> void:
	if not _thunder_is_active():
		return

	var segment := m_thunder_segments[m_thunder_segment_index]
	var duration := maxf(float(segment.get("duration", 0.01)), 0.001)
	var target_alpha := clampf(float(segment.get("alpha", 0.0)), 0.0, 1.0)
	m_thunder_segment_elapsed += delta
	var progress := clampf(m_thunder_segment_elapsed / duration, 0.0, 1.0)
	_set_thunder_flash_alpha(lerpf(m_thunder_segment_start_alpha, target_alpha, progress))
	if progress < 1.0:
		return

	m_thunder_segment_index += 1
	m_thunder_segment_elapsed = 0.0
	m_thunder_segment_start_alpha = m_thunder_current_alpha
	if m_thunder_segment_index >= m_thunder_segments.size():
		_finish_thunder_burst()


func _finish_thunder_burst() -> void:
	m_thunder_segments.clear()
	m_thunder_segment_index = -1
	m_thunder_segment_elapsed = 0.0
	m_thunder_segment_start_alpha = 0.0
	_set_thunder_flash_alpha(0.0)
	if m_thunder_enabled:
		_schedule_next_thunder_burst()


func _clear_active_thunder() -> void:
	m_thunder_segments.clear()
	m_thunder_segment_index = -1
	m_thunder_segment_elapsed = 0.0
	m_thunder_segment_start_alpha = 0.0
	m_thunder_wait_remaining = 0.0
	_set_thunder_flash_alpha(0.0)


func _thunder_is_active() -> bool:
	return m_thunder_segment_index >= 0 and m_thunder_segment_index < m_thunder_segments.size()


func _set_thunder_flash_alpha(alpha: float) -> void:
	m_thunder_current_alpha = clampf(alpha, 0.0, 1.0)
	var should_show := m_thunder_current_alpha > 0.001

	if is_instance_valid(m_thunder_fill):
		var fill_color := THUNDER_FILL_COLOR
		fill_color.a = minf(m_thunder_current_alpha * 0.4, 0.42)
		m_thunder_fill.color = fill_color
		m_thunder_fill.visible = should_show

	if is_instance_valid(m_thunder_glow):
		var glow_color := THUNDER_GLOW_COLOR
		glow_color.a = minf(m_thunder_current_alpha * 0.9, 0.85)
		m_thunder_glow.color = glow_color
		m_thunder_glow.visible = should_show


func _on_toggle_weather_controls_pressed() -> void:
	_set_weather_controls_visible(not m_weather_controls_visible)


func _on_rain_enabled_toggled(button_pressed: bool) -> void:
	_apply_rain_enabled(button_pressed)


func _on_thunder_enabled_toggled(button_pressed: bool) -> void:
	_apply_thunder_enabled(button_pressed)


func _on_density_slider_changed(value: float) -> void:
	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.density = value
	_update_weather_value_labels()


func _on_angle_slider_changed(value: float) -> void:
	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.wind_angle_degrees = value
	_update_weather_value_labels()


func _on_wind_strength_slider_changed(value: float) -> void:
	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.wind_strength = value
	_update_weather_value_labels()


func _on_drop_speed_slider_changed(value: float) -> void:
	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.drop_speed = value
	_update_weather_value_labels()


func _on_drop_size_slider_changed(value: float) -> void:
	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.drop_size = value
	_update_weather_value_labels()


func _on_thunder_strength_slider_changed(value: float) -> void:
	_apply_thunder_strength(value)
	_update_weather_value_labels()


func _on_impact_gain_slider_changed(value: float) -> void:
	if is_instance_valid(m_ground_impacts):
		m_ground_impacts.density_spawn_multiplier = value
	_update_weather_value_labels()


func _on_trigger_thunder_pressed() -> void:
	_start_random_thunder_burst()


func _on_reset_weather_controls_pressed() -> void:
	if m_weather_defaults.is_empty():
		return

	_apply_rain_enabled(bool(m_weather_defaults.get("rain_enabled", true)))
	_apply_thunder_enabled(bool(m_weather_defaults.get("thunder_enabled", false)))
	_apply_thunder_strength(float(m_weather_defaults.get("thunder_strength", m_thunder_strength)))
	if is_instance_valid(m_rain_overlay):
		m_rain_overlay.density = float(m_weather_defaults.get("density", m_rain_overlay.density))
		m_rain_overlay.wind_angle_degrees = float(
			m_weather_defaults.get("wind_angle_degrees", m_rain_overlay.wind_angle_degrees)
		)
		m_rain_overlay.wind_strength = float(
			m_weather_defaults.get("wind_strength", m_rain_overlay.wind_strength)
		)
		m_rain_overlay.drop_speed = float(m_weather_defaults.get("drop_speed", m_rain_overlay.drop_speed))
		m_rain_overlay.drop_size = float(m_weather_defaults.get("drop_size", m_rain_overlay.drop_size))

	if is_instance_valid(m_ground_impacts):
		m_ground_impacts.density_spawn_multiplier = float(
			m_weather_defaults.get("impact_gain", m_ground_impacts.density_spawn_multiplier)
		)

	_sync_weather_controls_from_scene()
