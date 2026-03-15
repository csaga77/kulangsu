@tool
class_name NPCController
extends BaseController

# ---------- JSON BT settings ----------
@export_category("Behavior Tree (JSON)")
@export var use_json_bt := true
@export_file var bt_json_path := "res://resources/bt/bt_default_npc.json"
@export_category("Resident")
@export var resident_id: StringName

var m_target: Node2D = null
var m_bt_tree: BTTree
var m_is_building_bt_tree := false

func _on_setup() -> void:
	super._on_setup()
	_apply_resident_presentation()
	if use_json_bt:
		_schedule_built_bt_tree()

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


func _apply_resident_presentation() -> void:
	if !is_instance_valid(m_character):
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

func _on_body_exited(body: Node2D) -> void:
	super._on_body_exited(body)
	if body.is_in_group("player"):
		m_target = null

func _process(delta: float) -> void:
	super._process(delta)
	
	if !Engine.is_editor_hint() and is_instance_valid(m_bt_tree):
		#m_bt_tree.set_debug_enabled(is_debug_enabled())
		m_bt_tree.tick(self, delta)
		#_set_debug_string(m_bt_tree.get_last_executed_path())

	if m_character == null or !is_instance_valid(m_character):
		return

	if m_target == null or !is_instance_valid(m_target):
		return

	var to_target: Vector2 = m_target.global_position - m_character.global_position
	if to_target.length_squared() < 0.001:
		return

	m_character.direction = rad_to_deg(to_target.angle())

func _can_talk_to(target_obj: Node2D) -> bool:
	return target_obj.is_in_group("player")

func _get_speech(target_obj: Node2D) -> String:
	if !is_instance_valid(m_character) or !is_instance_valid(target_obj):
		return ""
	if !target_obj.is_in_group("player"):
		return ""

	var resident_key := get_resident_id()
	if resident_key.is_empty():
		return "%s: ♪..." % m_character.name

	var display_name := AppState.get_resident_display_name(resident_key)
	var speech := AppState.get_resident_ambient_line(resident_key)
	if speech.is_empty():
		return ""
	return "%s: %s" % [display_name, speech]
