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
	var summary = _app_state().ending_summary
	var endgame = _app_state().endgame_state
	var tones := String(summary.get("ending_tones", ""))
	if tones.is_empty():
		tones = "Not yet named"
	var closing_label := String(endgame.get("closing_label", "Take a quiet moment before choosing what comes next."))
	var ending_behavior := String(endgame.get("ending_behavior", "end_run"))
	var trigger_event_id := String(endgame.get("trigger_event_id", ""))
	match trigger_event_id:
		"harbor_festival_performed":
			m_title_label.text = "Harbor Performance"
		"summer_exam_complete":
			m_title_label.text = "Second Summer"
		"future_commitment_end":
			m_title_label.text = "Harbor Turning Point"
		_:
			m_title_label.text = "Story Turning Point"
	m_summary_body.text = "%s\n\nSeason: %s\nRoute scores: %s\nMelody fragments recovered: %s\nResidents helped: %s\nOptional collectibles found: %s\nPlaytime: %s\nEnding tones: %s" % [
		closing_label,
		String(summary.get("season", "Story")),
		String(summary.get("routes", "No route summary yet.")),
		summary.get("fragments", "4 / 4"),
		summary.get("residents", "4"),
		summary.get("collectibles", "Not tracked in this build"),
		summary.get("playtime", "a brief evening on Kulangsu"),
		tones,
	]
	if ending_behavior == "continue_story":
		m_choose_label.text = "This moment can settle and let the island continue."
		m_return_button.visible = false
		m_stay_button.visible = true
		m_stay_button.text = "Continue Exploring"
	else:
		m_choose_label.text = "This story run ends here."
		m_return_button.visible = true
		m_return_button.text = "Leave on the Morning Ferry"
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
