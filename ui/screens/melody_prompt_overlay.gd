extends PanelContainer

signal close_requested()
signal practice_completed(request: Dictionary)
signal performance_completed(request: Dictionary)

const DEFAULT_FEEDBACK_COLOR := Color(0.88, 0.90, 0.94, 1.0)
const ERROR_FEEDBACK_COLOR := Color(0.95, 0.70, 0.64, 1.0)

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_clear_button.pressed.connect(_on_clear_pressed)
	m_confirm_button.pressed.connect(_on_confirm_pressed)
	m_cancel_button.pressed.connect(close_requested.emit)
	_reset_content()


func configure_request(request: Dictionary) -> void:
	m_request = request.duplicate(true)
	m_selected_ids.clear()
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


func _reset_content() -> void:
	m_request.clear()
	m_selected_ids.clear()
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
	m_clear_button.disabled = m_selected_ids.is_empty()
	m_confirm_button.disabled = expected_count == 0 or m_selected_ids.size() != expected_count

	for source_id in m_option_buttons.keys():
		var button := m_option_buttons[source_id] as Button
		if button == null:
			continue
		button.disabled = m_selected_ids.find(String(source_id)) >= 0


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


func _on_option_pressed(source_id: String) -> void:
	if m_selected_ids.find(source_id) >= 0:
		return

	m_selected_ids.append(source_id)
	_refresh_selection_text()
	_refresh_action_state()


func _on_clear_pressed() -> void:
	m_selected_ids.clear()
	_set_feedback(String(m_request.get("hint_text", "Choose the known phrase segments in order.")), DEFAULT_FEEDBACK_COLOR)
	_refresh_selection_text()
	_refresh_action_state()


func _on_confirm_pressed() -> void:
	var expected_order := _expected_order()
	if expected_order.is_empty():
		return

	if m_selected_ids == expected_order:
		if String(m_request.get("mode", "practice")) == "performance":
			performance_completed.emit(m_request.duplicate(true))
		else:
			practice_completed.emit(m_request.duplicate(true))
		return

	_set_feedback(String(m_request.get("retry_hint", "That order felt off. Try again.")), ERROR_FEEDBACK_COLOR)
	m_selected_ids.clear()
	_refresh_selection_text()
	_refresh_action_state()
