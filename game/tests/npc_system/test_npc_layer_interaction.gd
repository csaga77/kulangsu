@tool
extends Node2D

const LAYER_ONE_MASK := 524288
const LAYER_TWO_MASK := 1048576

@onready var m_player: HumanBody2D = $Player
@onready var m_status_label: Label = $CanvasLayer/StatusLabel

var m_player_controller: PlayerController = null
var m_closest_object: Node2D = null
var m_last_interaction_text := "No interaction yet."
var m_last_player_z := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	AppState.configure_new_game()
	GameGlobal.get_instance().set_player(m_player)
	m_player.set_configuration(AppState.get_player_appearance_config())

	m_player_controller = m_player.controller as PlayerController
	if m_player_controller != null:
		if !m_player_controller.closest_object_changed.is_connected(_on_closest_object_changed):
			m_player_controller.closest_object_changed.connect(_on_closest_object_changed)
		if !m_player_controller.inspect_requested.is_connected(_on_inspect_requested):
			m_player_controller.inspect_requested.connect(_on_inspect_requested)

	m_last_player_z = CommonUtils.get_absolute_z_index(m_player)
	_refresh_status()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var current_player_z := CommonUtils.get_absolute_z_index(m_player)
	if current_player_z != m_last_player_z:
		m_last_player_z = current_player_z
		_refresh_status()


func _on_closest_object_changed(new_object: Node2D) -> void:
	m_closest_object = new_object
	_refresh_status()


func _on_inspect_requested() -> void:
	if !is_instance_valid(m_closest_object):
		m_last_interaction_text = "No nearby same-layer resident."
		_refresh_status()
		return

	var resident_controller := _get_resident_controller(m_closest_object)
	if resident_controller == null:
		m_last_interaction_text = "Closest target is not a resident."
		_refresh_status()
		return

	var resident_id := resident_controller.get_resident_id()
	var resident_name := AppState.get_resident_display_name(resident_id)
	var interaction := AppState.interact_with_resident(resident_id)
	resident_controller.reveal_dialogue(String(interaction.get("line", "")))

	if interaction.is_empty():
		m_last_interaction_text = "Talked with %s." % resident_name
	else:
		m_last_interaction_text = String(interaction.get("line", "Talked with %s." % resident_name))

	_refresh_status()


func _refresh_status() -> void:
	if !is_instance_valid(m_status_label):
		return

	var player_z := CommonUtils.get_absolute_z_index(m_player)
	var target_text := "None"
	var prompt_text := "No same-layer target"

	if is_instance_valid(m_closest_object):
		var target_z := CommonUtils.get_absolute_z_index(m_closest_object)
		var resident_controller := _get_resident_controller(m_closest_object)
		if resident_controller != null:
			var resident_name := AppState.get_resident_display_name(resident_controller.get_resident_id())
			target_text = "%s (z %d)" % [resident_name, target_z]
			prompt_text = "R Talk to %s" % resident_name
		else:
			target_text = "%s (z %d)" % [m_closest_object.name, target_z]
			prompt_text = "R Inspect %s" % m_closest_object.name

	m_status_label.text = "\n".join([
		"NPC Layer Interaction Test",
		"",
		"Controls: move with WASD / arrows, press R to talk, cross the cyan portal zone to switch layers.",
		"Residents show \"...\" until R reveals the current talk line.",
		"Portal layers: bottom-to-top goes to z 1, top-to-bottom returns to z 0.",
		"",
		"Player absolute z: %d" % player_z,
		"Player collision layer mask: %d / %d active" % [
			int((m_player.collision_mask & LAYER_ONE_MASK) != 0),
			int((m_player.collision_mask & LAYER_TWO_MASK) != 0),
		],
		"Current target: %s" % target_text,
		"Current prompt: %s" % prompt_text,
		"Last interaction: %s" % m_last_interaction_text,
		"",
		"Ground row (z 0): Caretaker Lian, Dock Musician Pei",
		"Upper row (z 1): Tower Keeper Suyin, Storyteller Wen",
		"Walk onto the top row while still on z 0 to confirm no resident is targetable.",
	])


func _get_resident_controller(target: Node2D) -> NPCController:
	var human := target as HumanBody2D
	if human == null:
		return null
	return human.controller as NPCController
