@tool
class_name NPCController
extends BaseController

# ---------- JSON BT settings ----------
@export_category("Behavior Tree (JSON)")
@export var use_json_bt: bool = true
@export_file var bt_json_path: String = "res://resources/bt/bt_default_npc.json"
@export_category("Resident")
@export var resident_id: StringName

const DEFAULT_ROUTE_ARRIVAL_RADIUS := 24.0
const DEFAULT_ROUTE_WAIT_MIN_SEC := 0.5
const DEFAULT_ROUTE_WAIT_MAX_SEC := 1.2
const ROUTE_MOVE_SPEED := 72.0

var m_target: Node2D = null
var m_bt_tree: BTTree
var m_is_building_bt_tree := false
var m_revealed_dialogue_line: String = ""
var m_route_points: Array[Dictionary] = []
var m_route_index := -1
var m_route_direction := 1
var m_route_arrival_radius: float = DEFAULT_ROUTE_ARRIVAL_RADIUS
var m_route_wait_min_sec: float = DEFAULT_ROUTE_WAIT_MIN_SEC
var m_route_wait_max_sec: float = DEFAULT_ROUTE_WAIT_MAX_SEC
var m_route_wait_timer: float = 0.0
var m_route_ping_pong: bool = true
var m_route_is_moving: bool = false
var m_route_motion_target: Vector2 = Vector2.ZERO
var m_route_allow_collision_bypass: bool = false

func _on_setup() -> void:
	super._on_setup()
	_apply_resident_presentation()
	_reset_route_progress()
	if use_json_bt and !_has_route():
		_schedule_built_bt_tree()


func configure_movement(movement_config: Dictionary) -> void:
	m_route_points.clear()
	m_route_index = -1
	m_route_direction = 1
	m_route_wait_timer = 0.0
	m_route_arrival_radius = maxf(float(movement_config.get("arrival_radius", DEFAULT_ROUTE_ARRIVAL_RADIUS)), 4.0)
	m_route_wait_min_sec = maxf(float(movement_config.get("wait_min_sec", DEFAULT_ROUTE_WAIT_MIN_SEC)), 0.0)
	m_route_wait_max_sec = maxf(float(movement_config.get("wait_max_sec", DEFAULT_ROUTE_WAIT_MAX_SEC)), m_route_wait_min_sec)
	m_route_ping_pong = bool(movement_config.get("ping_pong", true))
	m_route_allow_collision_bypass = false

	for point_value in movement_config.get("route_points", []):
		var route_point := point_value as Dictionary
		if route_point.is_empty():
			continue
		if !route_point.has("position"):
			continue
		m_route_points.append(route_point.duplicate(true))

	if is_instance_valid(m_character):
		_reset_route_progress()

func _schedule_built_bt_tree():
	if m_is_building_bt_tree:
		return
	m_is_building_bt_tree = true
	call_deferred("_load_BT_tree")
	
func _load_BT_tree():
	if Engine.is_editor_hint():
		m_bt_tree = null
		m_is_building_bt_tree = false
		return

	var tree: BTTree = null
	if use_json_bt:
		var path := bt_json_path
		var factory := BTJsonFactory.new()
		
		var default_params := _get_default_params()
		#print(default_params)
		tree = factory.build_tree_from_file(path, default_params)

	m_bt_tree = tree
	m_is_building_bt_tree = false
	if m_bt_tree == null:
		printerr("Could not build BT tree!")


func get_resident_id() -> String:
	return String(resident_id)


func refresh_dialogue() -> void:
	_update_balloon_content()


func reveal_dialogue(line: String) -> void:
	m_revealed_dialogue_line = line.strip_edges()
	_update_balloon_content()


func _apply_resident_presentation() -> void:
	if !is_instance_valid(m_character):
		return

	if m_character.has_method("has_definition") and bool(m_character.call("has_definition")):
		m_character.call("sync_definition_presentation")
		return

	var resident_key := get_resident_id()
	if resident_key.is_empty():
		return

	var appearance_config: Dictionary = AppState.get_resident_appearance_config(resident_key)
	if !appearance_config.is_empty():
		m_character.call_deferred("set_configuration", appearance_config)

func _get_default_params() -> Dictionary:
	return {
		#"max_orbit_distance": m_max_following_distance / 2.0,
		#"max_orbit_time": m_max_following_time * 2.0,
		#"min_orbit_distance": min(m_min_following_distance, m_max_following_distance / 2.0),
		#"min_orbit_interval_seconds": m_min_following_interval_seconds,
		#"orbit_threshold": m_follow_dot_threshold,
		#"max_following_distance": m_max_following_distance,
		#"min_following_distance": m_min_following_distance,
		#"max_following_time": m_max_following_time,
		#"min_following_interval_seconds": m_min_following_interval_seconds,
		#"follow_threshold": m_follow_dot_threshold,
		#"backoff_distance": m_backoff_distance,
	}

func _on_body_entered(body: Node2D) -> void:
	super._on_body_entered(body)
	if body.is_in_group("player"):
		m_target = body
		_clear_revealed_dialogue()

func _on_body_exited(body: Node2D) -> void:
	super._on_body_exited(body)
	if body.is_in_group("player"):
		m_target = null
		_clear_revealed_dialogue()

func _process(delta: float) -> void:
	m_route_is_moving = false
	if _has_route():
		_update_route(delta)
	else:
		_update_behavior_tree(delta)

	super._process(delta)

	if m_character == null or !is_instance_valid(m_character):
		return

	_apply_route_motion(delta)

	if m_target == null or !is_instance_valid(m_target):
		return

	var to_target: Vector2 = m_target.global_position - m_character.global_position
	if to_target.length_squared() < 0.001:
		return

	m_character.direction = rad_to_deg(to_target.angle())

func _can_talk_to(target_obj: Node2D) -> bool:
	return target_obj.is_in_group("player")


func is_moving() -> bool:
	return m_route_is_moving or super.is_moving()


func _get_speech(target_obj: Node2D) -> String:
	if !is_instance_valid(m_character) or !is_instance_valid(target_obj):
		return ""
	if !target_obj.is_in_group("player"):
		return ""

	if m_revealed_dialogue_line.is_empty():
		return "..."

	var resident_key := get_resident_id()
	if resident_key.is_empty():
		return "%s: %s" % [m_character.name, m_revealed_dialogue_line]

	var display_name := AppState.get_resident_display_name(resident_key)
	return "%s: %s" % [display_name, m_revealed_dialogue_line]


func _clear_revealed_dialogue() -> void:
	m_revealed_dialogue_line = ""


func _has_route() -> bool:
	return m_route_points.size() >= 2


func _update_behavior_tree(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if !is_instance_valid(m_bt_tree):
		return
	#m_bt_tree.set_debug_enabled(is_debug_enabled())
	m_bt_tree.tick(self, delta)
	#_set_debug_string(m_bt_tree.get_last_executed_path())


func _update_route(delta: float) -> void:
	if !is_instance_valid(m_character):
		return

	if is_talking() or (is_instance_valid(m_target) and m_target.is_in_group("player")):
		stop_moving()
		return

	if m_route_index < 0 or m_route_index >= m_route_points.size():
		_reset_route_progress()

	if m_route_index < 0 or m_route_index >= m_route_points.size():
		stop_moving()
		return

	if m_route_wait_timer > 0.0:
		m_route_wait_timer = maxf(m_route_wait_timer - delta, 0.0)
		stop_moving()
		return

	var route_point := m_route_points[m_route_index]
	var target_position: Vector2 = route_point.get("position", m_character.global_position)
	var to_target := target_position - m_character.global_position
	if to_target.length_squared() <= m_route_arrival_radius * m_route_arrival_radius:
		_advance_route_point(route_point)
		stop_moving()
		return

	set_running(false)
	move_direction = MoveDirectionEnum.MOVE_IDLE
	set_target_direction(to_target)
	m_route_motion_target = target_position
	m_route_allow_collision_bypass = bool(route_point.get("allow_collision_bypass", false))
	m_route_is_moving = true


func _advance_route_point(route_point: Dictionary) -> void:
	m_route_wait_timer = _get_route_wait_duration(route_point)

	if m_route_points.size() <= 1:
		return

	var next_index := m_route_index + m_route_direction
	if m_route_ping_pong:
		if next_index >= m_route_points.size() or next_index < 0:
			m_route_direction *= -1
			next_index = m_route_index + m_route_direction
	else:
		next_index = posmod(next_index, m_route_points.size())

	m_route_index = clampi(next_index, 0, m_route_points.size() - 1)


func _get_route_wait_duration(route_point: Dictionary) -> float:
	var wait_min_sec := maxf(float(route_point.get("wait_min_sec", m_route_wait_min_sec)), 0.0)
	var wait_max_sec := maxf(float(route_point.get("wait_max_sec", m_route_wait_max_sec)), wait_min_sec)
	if is_equal_approx(wait_min_sec, wait_max_sec):
		return wait_min_sec
	return randf_range(wait_min_sec, wait_max_sec)


func _reset_route_progress() -> void:
	m_route_wait_timer = 0.0
	m_route_is_moving = false
	if !_has_route() or !is_instance_valid(m_character):
		m_route_index = -1
		m_route_direction = 1
		return

	var nearest_index := 0
	var nearest_distance_sq := INF
	for i in range(m_route_points.size()):
		var route_point := m_route_points[i]
		var route_position: Vector2 = route_point.get("position", m_character.global_position)
		var distance_sq := m_character.global_position.distance_squared_to(route_position)
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest_index = i

	m_route_index = nearest_index
	m_route_direction = -1 if nearest_index >= m_route_points.size() - 1 else 1


func _apply_route_motion(delta: float) -> void:
	if !_has_route():
		return
	if !m_route_is_moving:
		return
	if !is_instance_valid(m_character):
		return

	var to_target := m_route_motion_target - m_character.global_position
	if to_target.length_squared() <= 0.001:
		return

	if m_route_allow_collision_bypass:
		m_character.global_position = m_character.global_position.move_toward(
			m_route_motion_target,
			ROUTE_MOVE_SPEED * delta
		)
	else:
		m_character.move_with_speed(to_target, ROUTE_MOVE_SPEED)
	m_character.is_walking = true
