extends PanelContainer

signal leave_requested()
signal stay_requested()
signal credits_requested()

@onready var m_summary_body: Label = $Margin/Body/SummaryBody
@onready var m_return_button: Button = $Margin/Body/ReturnButton
@onready var m_stay_button: Button = $Margin/Body/StayButton
@onready var m_credits_button: Button = $Margin/Body/CreditsButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_return_button.pressed.connect(leave_requested.emit)
	m_stay_button.pressed.connect(stay_requested.emit)
	m_credits_button.pressed.connect(credits_requested.emit)


func refresh_from_state() -> void:
	var summary := AppState.ending_summary
	m_summary_body.text = "Melody fragments recovered: %s\nResidents helped: %s\nOptional collectibles found: %s\nPlaytime: %s" % [
		summary.get("fragments", "4 / 4"),
		summary.get("residents", "4"),
		summary.get("collectibles", "Not tracked in this build"),
		summary.get("playtime", "a brief evening on Kulangsu"),
	]
