extends Control

signal continue_pressed()
signal new_game_pressed()
signal free_walk_pressed()
signal settings_pressed()
signal credits_pressed()
signal quit_pressed()

const BUTTON_TEXT_COLOR := Color(0.97, 0.95, 0.90, 1.0)
const BUTTON_DISABLED_TEXT_COLOR := Color(0.84, 0.82, 0.76, 0.45)

@onready var m_hero_panel: PanelContainer = $SafeArea/Center/Content/HeroColumn/HeroPanel
@onready var m_menu_card: PanelContainer = $SafeArea/Center/Content/ActionColumn/MenuCard
@onready var m_chip_panels: Array[PanelContainer] = [
	$SafeArea/Center/Content/HeroColumn/HeroPanel/Margin/Hero/FeatureRow/HarborChip,
	$SafeArea/Center/Content/HeroColumn/HeroPanel/Margin/Hero/FeatureRow/BellChip,
	$SafeArea/Center/Content/HeroColumn/HeroPanel/Margin/Hero/FeatureRow/TunnelChip,
]
@onready var m_continue_button: Button = $SafeArea/Center/Content/ActionColumn/MenuCard/Margin/MenuButtons/ContinueButton
@onready var m_new_game_button: Button = $SafeArea/Center/Content/ActionColumn/MenuCard/Margin/MenuButtons/NewGameButton
@onready var m_free_walk_button: Button = $SafeArea/Center/Content/ActionColumn/MenuCard/Margin/MenuButtons/FreeWalkButton
@onready var m_settings_button: Button = $SafeArea/Center/Content/ActionColumn/MenuCard/Margin/MenuButtons/SettingsButton
@onready var m_credits_button: Button = $SafeArea/Center/Content/ActionColumn/MenuCard/Margin/MenuButtons/CreditsButton
@onready var m_quit_button: Button = $SafeArea/Center/Content/ActionColumn/MenuCard/Margin/MenuButtons/QuitButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	m_hero_panel.add_theme_stylebox_override("panel", UIStyle.build_hero_panel_style())
	m_menu_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	for chip_panel in m_chip_panels:
		chip_panel.add_theme_stylebox_override("panel", UIStyle.build_chip_style())
	_apply_button_styles()
	m_continue_button.pressed.connect(continue_pressed.emit)
	m_new_game_button.pressed.connect(new_game_pressed.emit)
	m_free_walk_button.pressed.connect(free_walk_pressed.emit)
	m_settings_button.pressed.connect(settings_pressed.emit)
	m_credits_button.pressed.connect(credits_pressed.emit)
	m_quit_button.pressed.connect(quit_pressed.emit)


func set_continue_enabled(is_enabled: bool) -> void:
	m_continue_button.disabled = !is_enabled


func _apply_button_styles() -> void:
	var buttons: Array[Button] = [
		m_continue_button,
		m_new_game_button,
		m_free_walk_button,
		m_settings_button,
		m_credits_button,
		m_quit_button,
	]
	var normal_style := UIStyle.build_menu_button_style(
		Color(0.10, 0.16, 0.19, 0.94),
		Color(0.84, 0.77, 0.62, 0.42)
	)
	var hover_style := UIStyle.build_menu_button_style(
		Color(0.16, 0.25, 0.27, 0.98),
		Color(0.94, 0.86, 0.69, 0.72)
	)
	var pressed_style := UIStyle.build_menu_button_style(
		Color(0.22, 0.30, 0.24, 0.98),
		Color(0.96, 0.90, 0.75, 0.88)
	)
	var disabled_style := UIStyle.build_menu_button_style(
		Color(0.07, 0.10, 0.12, 0.84),
		Color(0.64, 0.62, 0.57, 0.18)
	)
	var focus_style := UIStyle.build_menu_button_style(
		Color(0.14, 0.22, 0.24, 0.98),
		Color(0.98, 0.92, 0.78, 0.98)
	)
	for button in buttons:
		button.add_theme_stylebox_override("normal", normal_style.duplicate())
		button.add_theme_stylebox_override("hover", hover_style.duplicate())
		button.add_theme_stylebox_override("pressed", pressed_style.duplicate())
		button.add_theme_stylebox_override("disabled", disabled_style.duplicate())
		button.add_theme_stylebox_override("focus", focus_style.duplicate())
		button.add_theme_color_override("font_color", BUTTON_TEXT_COLOR)
		button.add_theme_color_override("font_hover_color", BUTTON_TEXT_COLOR)
		button.add_theme_color_override("font_pressed_color", BUTTON_TEXT_COLOR)
		button.add_theme_color_override("font_focus_color", BUTTON_TEXT_COLOR)
		button.add_theme_color_override("font_disabled_color", BUTTON_DISABLED_TEXT_COLOR)
