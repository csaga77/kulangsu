extends Control

signal continue_pressed()
signal new_game_pressed()
signal free_walk_pressed()
signal settings_pressed()
signal credits_pressed()
signal quit_pressed()

@onready var m_menu_card: PanelContainer = $SafeArea/Center/Content/MenuCard
@onready var m_continue_button: Button = $SafeArea/Center/Content/MenuCard/Margin/MenuButtons/ContinueButton
@onready var m_new_game_button: Button = $SafeArea/Center/Content/MenuCard/Margin/MenuButtons/NewGameButton
@onready var m_free_walk_button: Button = $SafeArea/Center/Content/MenuCard/Margin/MenuButtons/FreeWalkButton
@onready var m_settings_button: Button = $SafeArea/Center/Content/MenuCard/Margin/MenuButtons/SettingsButton
@onready var m_credits_button: Button = $SafeArea/Center/Content/MenuCard/Margin/MenuButtons/CreditsButton
@onready var m_quit_button: Button = $SafeArea/Center/Content/MenuCard/Margin/MenuButtons/QuitButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	m_menu_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_continue_button.pressed.connect(continue_pressed.emit)
	m_new_game_button.pressed.connect(new_game_pressed.emit)
	m_free_walk_button.pressed.connect(free_walk_pressed.emit)
	m_settings_button.pressed.connect(settings_pressed.emit)
	m_credits_button.pressed.connect(credits_pressed.emit)
	m_quit_button.pressed.connect(quit_pressed.emit)


func set_continue_enabled(is_enabled: bool) -> void:
	m_continue_button.disabled = !is_enabled
