extends PanelContainer

const APP_RUNTIME := preload("res://game/app_runtime.gd")

signal leave_requested()
signal continue_story_requested()
signal credits_requested()

@onready var m_title_label: Label = $Margin/Body/Title
@onready var m_choose_label: Label = $Margin/Body/ChooseLabel
@onready var m_summary_body: Label = $Margin/Body/SummaryBody
@onready var m_return_button: Button = $Margin/Body/ReturnButton
@onready var m_stay_button: Button = $Margin/Body/StayButton
@onready var m_credits_button: Button = $Margin/Body/CreditsButton


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_return_button.pressed.connect(leave_requested.emit)
	m_stay_button.pressed.connect(continue_story_requested.emit)
	m_credits_button.pressed.connect(credits_requested.emit)
	visibility_changed.connect(_on_visibility_changed)


func refresh_from_state() -> void:
	var summary: Dictionary = _app_state().ending_summary
	var endgame: Dictionary = _app_state().endgame_state
	var trigger_event_id := String(endgame.get("trigger_event_id", ""))
	var ending_behavior := String(endgame.get("ending_behavior", "end_run"))
	var tones := String(summary.get("ending_tones", ""))
	if tones.is_empty():
		tones = "Not yet named"
	var closing_label := String(endgame.get("closing_label", "Take a quiet moment before choosing what comes next."))
	var route_emphasis := String(summary.get("route_emphasis", "No route has taken the lead yet."))
	m_title_label.text = _build_title(trigger_event_id)
	m_summary_body.text = _build_summary_text(trigger_event_id, closing_label, route_emphasis, tones, summary)
	if ending_behavior == "continue_story":
		m_choose_label.text = "The plaza can keep this ending in ordinary island air. Leave now, or stay a little longer and hear what the melody becomes once the crowd is gone."
		m_return_button.visible = true
		m_return_button.text = "Leave on the Morning Ferry"
		m_stay_button.visible = true
		m_stay_button.text = "Stay a Little Longer"
	else:
		m_choose_label.text = _build_hard_ending_prompt(trigger_event_id)
		m_return_button.visible = true
		m_return_button.text = _build_leave_button_text(trigger_event_id)
		m_stay_button.visible = false


func grab_default_focus() -> void:
	if !is_visible_in_tree():
		return
	if m_stay_button.visible:
		m_stay_button.grab_focus()
	elif m_return_button.visible:
		m_return_button.grab_focus()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		call_deferred("grab_default_focus")


func _build_title(trigger_event_id: String) -> String:
	match trigger_event_id:
		"harbor_festival_performed":
			return "Harbor Performance"
		"summer_exam_complete":
			return "Second Summer"
		"future_commitment_end":
			return "Harbor Turning Point"
		_:
			return "Story Turning Point"


func _build_summary_text(
	trigger_event_id: String,
	closing_label: String,
	route_emphasis: String,
	tones: String,
	summary: Dictionary
) -> String:
	var opening_text := ""
	match trigger_event_id:
		"harbor_festival_performed":
			opening_text = "The island has already heard this year in public. What was private now lingers in the plaza, the church, and the walk back uphill."
		"summer_exam_complete":
			opening_text = "Second summer arrives with the exam behind you and the harder question still alive: what remains once pressure finally stops speaking for you."
		"future_commitment_end":
			opening_text = "The harbor heard your future clearly enough to answer it. This ending is quieter than triumph, but steadier than doubt."
		_:
			opening_text = "The year has reached one of its true stopping places."

	return "%s\n\n%s\n\nSeason: %s\nRoute emphasis: %s\nRoute scores: %s\nMelody fragments recovered: %s\nResidents helped: %s\nOptional collectibles found: %s\nPlaytime: %s\nEnding tones: %s" % [
		opening_text,
		closing_label,
		String(summary.get("season", "Story")),
		route_emphasis,
		String(summary.get("routes", "No route summary yet.")),
		summary.get("fragments", "4 / 4"),
		summary.get("residents", "4"),
		summary.get("collectibles", "Not tracked in this build"),
		summary.get("playtime", "a brief evening on Kulangsu"),
		tones,
	]


func _build_hard_ending_prompt(trigger_event_id: String) -> String:
	match trigger_event_id:
		"summer_exam_complete":
			return "The year has already turned into second summer. Morning ferry is the remaining honest motion."
		"future_commitment_end":
			return "The harbor has answered. Morning ferry carries the named future onward."
		_:
			return "This story run ends here."


func _build_leave_button_text(trigger_event_id: String) -> String:
	match trigger_event_id:
		"summer_exam_complete":
			return "Leave in Second Summer"
		"future_commitment_end":
			return "Take the Morning Ferry"
		_:
			return "Leave on the Morning Ferry"
