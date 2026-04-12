extends Control

const APP_RUNTIME := preload("res://game/app_runtime.gd")

@onready var m_objective_card: PanelContainer = $ObjectiveCard
@onready var m_status_card: PanelContainer = $StatusCard
@onready var m_hint_card: PanelContainer = $HintCard
@onready var m_objective_label: Label = $ObjectiveCard/Margin/Body/Objective
@onready var m_task_label: Label = $ObjectiveCard/Margin/Body/Task
@onready var m_mode_label: Label = $StatusCard/Margin/Body/Mode
@onready var m_chapter_label: Label = $StatusCard/Margin/Body/Chapter
@onready var m_location_label: Label = $StatusCard/Margin/Body/Location
@onready var m_fragments_label: Label = $StatusCard/Margin/Body/Fragments
@onready var m_hint_label: Label = $HintCard/Margin/Hint
@onready var m_save_label: Label = $SaveStatus


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	m_objective_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_status_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_hint_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_bind_state()
	_refresh_all()


func _bind_state() -> void:
	if _app_state().objective_changed.is_connected(_refresh_objective):
		return
	_app_state().objective_changed.connect(_refresh_objective)
	_app_state().mode_changed.connect(_refresh_mode)
	_app_state().chapter_changed.connect(_refresh_chapter)
	_app_state().season_phase_changed.connect(_refresh_chapter_from_phase)
	_app_state().location_changed.connect(_refresh_location)
	_app_state().fragments_changed.connect(_refresh_fragments)
	_app_state().hint_changed.connect(_refresh_hint)
	_app_state().save_status_changed.connect(_refresh_save_status)
	_app_state().melody_hint_shown.connect(_show_melody_hint)
	_app_state().active_leads_changed.connect(_on_active_leads_changed)


func _refresh_all() -> void:
	_refresh_objective(_app_state().objective)
	_refresh_mode(_app_state().mode)
	_refresh_chapter_from_phase(_app_state().season_phase)
	_refresh_location(_app_state().location)
	_refresh_fragments(_app_state().fragments_found, _app_state().fragments_total)
	_refresh_hint(_app_state().hint)
	_refresh_save_status(_app_state().save_status)


func _refresh_objective(value: String) -> void:
	m_objective_label.text = _app_state().get_active_lead_text()
	if m_objective_label.text.is_empty():
		m_objective_label.text = value
	m_task_label.text = "Current task: %s" % value


func _refresh_mode(value: String) -> void:
	m_mode_label.text = "Mode: %s" % value


func _refresh_chapter(value: String) -> void:
	m_chapter_label.text = "Chapter: %s" % value


func _refresh_chapter_from_phase(_phase_id: String) -> void:
	m_chapter_label.text = "Season: %s" % _app_state().get_season_phase_display_name()


func _refresh_location(value: String) -> void:
	m_location_label.text = "Location: %s" % value


func _refresh_fragments(found: int, total: int) -> void:
	m_fragments_label.text = "Melody Fragments: %d / %d" % [found, total]


func _refresh_hint(value: String) -> void:
	m_hint_label.text = value


func _refresh_save_status(value: String) -> void:
	m_save_label.text = value


func _show_melody_hint(value: String) -> void:
	m_save_label.text = value


func _on_active_leads_changed(_active_lead_id: String, _available_lead_ids: PackedStringArray) -> void:
	_refresh_objective(_app_state().objective)
