extends PanelContainer

signal close_requested()
signal practice_completed(request: Dictionary)
signal performance_completed(request: Dictionary)

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const DEFAULT_FEEDBACK_COLOR := Color(0.88, 0.90, 0.94, 1.0)
const ERROR_FEEDBACK_COLOR := Color(0.95, 0.70, 0.64, 1.0)
const SEGMENT_SELECT_PATH := "res://resources/audio/sfx/melody_prompt/segment_select.ogg"
const ORDER_CORRECT_PATH := "res://resources/audio/sfx/melody_prompt/order_correct.ogg"
const ORDER_WRONG_PATH := "res://resources/audio/sfx/melody_prompt/order_wrong.ogg"
const UI_AUDIO_VOLUME_DB := -5.0
const ORDER_CORRECT_WAIT_CAP_SECONDS := 1.6
const ORDER_WRONG_WAIT_CAP_SECONDS := 0.9

@onready var m_title_label: Label = $Margin/Body/PromptTitle
@onready var m_body_label: Label = $Margin/Body/PromptBody
@onready var m_sequence_label: Label = $Margin/Body/SequenceLabel
@onready var m_feedback_label: Label = $Margin/Body/FeedbackLabel
@onready var m_options_container: VBoxContainer = $Margin/Body/Options
@onready var m_clear_button: Button = $Margin/Body/Actions/ClearButton
@onready var m_confirm_button: Button = $Margin/Body/Actions/ConfirmButton
@onready var m_cancel_button: Button = $Margin/Body/Actions/CancelButton

var m_request: Dictionary = {}
var m_selected_ids: Array[String] = []
var m_option_buttons: Dictionary = {}
var m_segment_select_player: AudioStreamPlayer = null
var m_order_correct_player: AudioStreamPlayer = null
var m_order_wrong_player: AudioStreamPlayer = null
var m_submission_locked := false


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_setup_audio_players()
	_apply_prompt_volume()
	m_clear_button.pressed.connect(_on_clear_pressed)
	m_confirm_button.pressed.connect(_on_confirm_pressed)
	m_cancel_button.pressed.connect(close_requested.emit)
	if !_app_state().prompt_volume_changed.is_connected(_on_prompt_volume_changed):
		_app_state().prompt_volume_changed.connect(_on_prompt_volume_changed)
	visibility_changed.connect(_on_visibility_changed)
	_reset_content()


func configure_request(request: Dictionary) -> void:
	m_request = request.duplicate(true)
	m_selected_ids.clear()
	m_submission_locked = false
	_rebuild_options()
	m_title_label.text = String(m_request.get("title", "Melody Prompt"))
	m_body_label.text = String(m_request.get("body", "Arrange the known phrase segments in order."))
	_set_feedback(String(m_request.get("hint_text", "Choose the known phrase segments in order.")), DEFAULT_FEEDBACK_COLOR)
	_refresh_selection_text()
	_refresh_action_state()


func _rebuild_options() -> void:
	for child in m_options_container.get_children():
		child.queue_free()
	m_option_buttons.clear()

	var segments: Array = m_request.get("segments", [])
	for segment in segments:
		var source_id := String(segment.get("source_id", ""))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.text = "%s (%s)" % [
			String(segment.get("label", "Unknown phrase")),
			String(segment.get("landmark", "Unknown landmark")),
		]
		button.pressed.connect(_on_option_pressed.bind(source_id))
		m_options_container.add_child(button)
		m_option_buttons[source_id] = button

	if is_visible_in_tree():
		call_deferred("grab_default_focus")


func _reset_content() -> void:
	m_request.clear()
	m_selected_ids.clear()
	m_submission_locked = false
	m_title_label.text = "Melody Prompt"
	m_body_label.text = ""
	m_sequence_label.text = "Selected order\nNothing chosen yet."
	_set_feedback("", DEFAULT_FEEDBACK_COLOR)
	_refresh_action_state()


func _refresh_selection_text() -> void:
	if m_selected_ids.is_empty():
		m_sequence_label.text = "Selected order\nNothing chosen yet."
		return

	var labels: Array[String] = []
	for source_id in m_selected_ids:
		labels.append(_label_for_source(source_id))
	m_sequence_label.text = "Selected order\n%s" % " -> ".join(labels)


func _refresh_action_state() -> void:
	var expected_count := _expected_order().size()
	m_clear_button.disabled = m_submission_locked or m_selected_ids.is_empty()
	m_confirm_button.disabled = m_submission_locked or expected_count == 0 or m_selected_ids.size() != expected_count
	m_cancel_button.disabled = m_submission_locked

	for source_id in m_option_buttons.keys():
		var button := m_option_buttons[source_id] as Button
		if button == null:
			continue
		button.disabled = m_submission_locked or m_selected_ids.find(String(source_id)) >= 0


func grab_default_focus() -> void:
	if !is_visible_in_tree():
		return

	for source_id in m_option_buttons.keys():
		var button := m_option_buttons[source_id] as Button
		if button == null or button.disabled:
			continue
		button.grab_focus()
		return

	m_cancel_button.grab_focus()


func _label_for_source(source_id: String) -> String:
	var segments: Array = m_request.get("segments", [])
	for segment in segments:
		if String(segment.get("source_id", "")) == source_id:
			return String(segment.get("label", source_id))
	return source_id


func _expected_order() -> Array[String]:
	var ordered: Array[String] = []
	for source_id in m_request.get("expected_order", []):
		ordered.append(String(source_id))
	return ordered


func _set_feedback(text: String, color: Color) -> void:
	m_feedback_label.text = text
	m_feedback_label.modulate = color


func _setup_audio_players() -> void:
	m_segment_select_player = _build_audio_player("SegmentSelectPlayer", SEGMENT_SELECT_PATH)
	m_order_correct_player = _build_audio_player("OrderCorrectPlayer", ORDER_CORRECT_PATH)
	m_order_wrong_player = _build_audio_player("OrderWrongPlayer", ORDER_WRONG_PATH)
	_apply_prompt_volume()


func _build_audio_player(player_name: String, stream_path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = UI_AUDIO_VOLUME_DB
	if ResourceLoader.exists(stream_path):
		player.stream = load(stream_path) as AudioStream
	add_child(player)
	return player


func _apply_prompt_volume() -> void:
	var app_state = _app_state()
	if app_state == null:
		return

	var volume_db = app_state.get_prompt_volume_db(UI_AUDIO_VOLUME_DB)
	for player in [m_segment_select_player, m_order_correct_player, m_order_wrong_player]:
		if player != null:
			player.volume_db = volume_db


func _on_prompt_volume_changed(_volume_percent: float) -> void:
	_apply_prompt_volume()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		call_deferred("grab_default_focus")


func _play_one_shot(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()


func _play_one_shot_and_wait(player: AudioStreamPlayer, wait_cap_seconds: float) -> void:
	if player == null or player.stream == null:
		return

	var wait_time := wait_cap_seconds
	var stream_length := player.stream.get_length()
	if stream_length > 0.05:
		wait_time = minf(stream_length, wait_cap_seconds)

	player.stop()
	player.play()
	if wait_time <= 0.05:
		return
	await get_tree().create_timer(wait_time, true, false, true).timeout


func _on_option_pressed(source_id: String) -> void:
	if m_submission_locked:
		return
	if m_selected_ids.find(source_id) >= 0:
		return

	m_selected_ids.append(source_id)
	_play_one_shot(m_segment_select_player)
	_refresh_selection_text()
	_refresh_action_state()


func _on_clear_pressed() -> void:
	if m_submission_locked:
		return
	m_selected_ids.clear()
	_set_feedback(String(m_request.get("hint_text", "Choose the known phrase segments in order.")), DEFAULT_FEEDBACK_COLOR)
	_refresh_selection_text()
	_refresh_action_state()


func _on_confirm_pressed() -> void:
	if m_submission_locked:
		return
	var expected_order := _expected_order()
	if expected_order.is_empty():
		return

	m_submission_locked = true
	_refresh_action_state()
	if m_selected_ids == expected_order:
		_set_feedback("The phrase settles into place.", DEFAULT_FEEDBACK_COLOR)
		await _play_one_shot_and_wait(m_order_correct_player, ORDER_CORRECT_WAIT_CAP_SECONDS)
		if String(m_request.get("mode", "practice")) == "performance":
			performance_completed.emit(m_request.duplicate(true))
		else:
			practice_completed.emit(m_request.duplicate(true))
		return

	await _play_one_shot_and_wait(m_order_wrong_player, ORDER_WRONG_WAIT_CAP_SECONDS)
	_set_feedback(String(m_request.get("retry_hint", "That order felt off. Try again.")), ERROR_FEEDBACK_COLOR)
	m_selected_ids.clear()
	m_submission_locked = false
	_refresh_selection_text()
	_refresh_action_state()
