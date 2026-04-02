extends PanelContainer

const APP_RUNTIME := preload("res://game/app_runtime.gd")

signal resume_requested()
signal journal_requested()
signal settings_requested()
signal return_to_title_requested()
signal quit_requested()

@onready var m_resume_button: Button = $Margin/Body/ResumeButton
@onready var m_journal_button: Button = $Margin/Body/JournalButton
@onready var m_settings_button: Button = $Margin/Body/SettingsButton
@onready var m_return_button: Button = $Margin/Body/ReturnButton
@onready var m_quit_button: Button = $Margin/Body/QuitButton


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_resume_button.pressed.connect(resume_requested.emit)
	m_journal_button.pressed.connect(journal_requested.emit)
	m_settings_button.pressed.connect(settings_requested.emit)
	m_return_button.pressed.connect(return_to_title_requested.emit)
	m_quit_button.pressed.connect(quit_requested.emit)
	set_journal_enabled(_app_state().is_journal_unlocked())


func set_journal_enabled(enabled: bool) -> void:
	m_journal_button.disabled = !enabled
	m_journal_button.text = "Journal" if enabled else "Journal (Locked)"
