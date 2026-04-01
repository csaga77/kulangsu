extends PanelContainer

signal continue_requested()

@onready var m_body_label: Label = $Margin/Body/BodyLabel
@onready var m_continue_button: Button = $Margin/Body/ContinueButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_continue_button.pressed.connect(continue_requested.emit)


func refresh_from_state() -> void:
	var summary := AppState.ending_summary
	m_body_label.text = "The first ferry ropes loosen while the harbor keeps singing behind you.\n\nYou leave after restoring %s of the festival melody and helping %s residents answer it.\n\nThis story run is complete. Continue will stay unavailable until a new journey begins." % [
		String(summary.get("fragments", "4 / 4")),
		String(summary.get("residents", "0")),
	]
