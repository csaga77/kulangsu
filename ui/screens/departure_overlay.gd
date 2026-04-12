extends PanelContainer

const APP_RUNTIME := preload("res://game/app_runtime.gd")

signal continue_requested()

@onready var m_title_label: Label = $Margin/Body/Title
@onready var m_subtitle_label: Label = $Margin/Body/SubtitleLabel
@onready var m_body_label: Label = $Margin/Body/BodyLabel
@onready var m_continue_button: Button = $Margin/Body/ContinueButton


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_continue_button.pressed.connect(continue_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func refresh_from_state() -> void:
	var summary: Dictionary = _app_state().ending_summary
	var trigger_event_id := String(summary.get("ending_trigger", ""))
	var tones := String(summary.get("ending_tones", ""))
	if tones.is_empty():
		tones = "quiet departure"
	var route_emphasis := String(summary.get("route_emphasis", "No route has taken the lead yet."))
	m_title_label.text = _build_title(trigger_event_id)
	m_subtitle_label.text = _build_subtitle(trigger_event_id)
	m_body_label.text = _build_body_text(trigger_event_id, route_emphasis, tones, summary)


func grab_default_focus() -> void:
	if !is_visible_in_tree():
		return
	m_continue_button.grab_focus()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		call_deferred("grab_default_focus")


func _build_title(trigger_event_id: String) -> String:
	match trigger_event_id:
		"summer_exam_complete":
			return "Second Summer Ferry"
		"future_commitment_end":
			return "Turning-Point Ferry"
		"harbor_festival_performed":
			return "After the Festival"
		_:
			return "Morning Ferry"


func _build_subtitle(trigger_event_id: String) -> String:
	match trigger_event_id:
		"summer_exam_complete":
			return "The exam season is behind you, but the harbor keeps the truer question."
		"future_commitment_end":
			return "You leave after the harbor finally heard the future in your own voice."
		"harbor_festival_performed":
			return "The plaza keeps the melody even after the crowd and ferry lights thin out."
		_:
			return "The harbor keeps the melody after you step aboard."


func _build_body_text(
	trigger_event_id: String,
	route_emphasis: String,
	tones: String,
	summary: Dictionary
) -> String:
	var opening_text := ""
	match trigger_event_id:
		"summer_exam_complete":
			opening_text = "You step aboard in second summer. The exam is over, but what follows you onto the water is the quieter honesty that survived it."
		"future_commitment_end":
			opening_text = "You leave after the harbor answered instead of demanding more proof. The choice feels real because it was finally spoken without apology."
		"harbor_festival_performed":
			opening_text = "You leave after hearing the island remember itself in public. The performance is over, but the harbor no longer sounds unfinished."
		_:
			opening_text = "The first ferry ropes loosen while the harbor keeps singing behind you."

	return "%s\n\nYou leave during %s after restoring %s of the festival melody and helping %s residents answer the year.\n\nRoute emphasis: %s\nEnding tones: %s\n\nThis story run is complete. Continue will stay unavailable until a new journey begins." % [
		opening_text,
		String(summary.get("season", "the story's final season")),
		String(summary.get("fragments", "4 / 4")),
		String(summary.get("residents", "0")),
		route_emphasis,
		tones,
	]
