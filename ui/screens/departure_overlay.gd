extends PanelContainer

const APP_RUNTIME := preload("res://game/app_runtime.gd")

signal continue_requested()

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
	var summary = _app_state().ending_summary
	m_body_label.text = "The first ferry ropes loosen while the harbor keeps singing behind you.\n\nYou leave after restoring %s of the festival melody and helping %s residents answer it.\n\nThis story run is complete. Continue will stay unavailable until a new journey begins." % [
		String(summary.get("fragments", "4 / 4")),
		String(summary.get("residents", "0")),
	]


func grab_default_focus() -> void:
	if !is_visible_in_tree():
		return
	m_continue_button.grab_focus()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		call_deferred("grab_default_focus")
