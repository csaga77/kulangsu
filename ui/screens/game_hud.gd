extends Control

@onready var m_objective_card: PanelContainer = $ObjectiveCard
@onready var m_status_card: PanelContainer = $StatusCard
@onready var m_hint_card: PanelContainer = $HintCard
@onready var m_objective_label: Label = $ObjectiveCard/Margin/Body/Objective
@onready var m_mode_label: Label = $StatusCard/Margin/Body/Mode
@onready var m_chapter_label: Label = $StatusCard/Margin/Body/Chapter
@onready var m_location_label: Label = $StatusCard/Margin/Body/Location
@onready var m_fragments_label: Label = $StatusCard/Margin/Body/Fragments
@onready var m_hint_label: Label = $HintCard/Margin/Hint
@onready var m_save_label: Label = $SaveStatus


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	m_objective_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_status_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	m_hint_card.add_theme_stylebox_override("panel", UIStyle.build_panel_style())
	_bind_state()
	_refresh_all()


func _bind_state() -> void:
	if AppState.objective_changed.is_connected(_refresh_objective):
		return
	AppState.objective_changed.connect(_refresh_objective)
	AppState.mode_changed.connect(_refresh_mode)
	AppState.chapter_changed.connect(_refresh_chapter)
	AppState.location_changed.connect(_refresh_location)
	AppState.fragments_changed.connect(_refresh_fragments)
	AppState.hint_changed.connect(_refresh_hint)
	AppState.save_status_changed.connect(_refresh_save_status)


func _refresh_all() -> void:
	_refresh_objective(AppState.objective)
	_refresh_mode(AppState.mode)
	_refresh_chapter(AppState.chapter)
	_refresh_location(AppState.location)
	_refresh_fragments(AppState.fragments_found, AppState.fragments_total)
	_refresh_hint(AppState.hint)
	_refresh_save_status(AppState.save_status)


func _refresh_objective(value: String) -> void:
	m_objective_label.text = value


func _refresh_mode(value: String) -> void:
	m_mode_label.text = "Mode: %s" % value


func _refresh_chapter(value: String) -> void:
	m_chapter_label.text = "Chapter: %s" % value


func _refresh_location(value: String) -> void:
	m_location_label.text = "Location: %s" % value


func _refresh_fragments(found: int, total: int) -> void:
	m_fragments_label.text = "Melody: %d / %d fragments" % [found, total]


func _refresh_hint(value: String) -> void:
	m_hint_label.text = value


func _refresh_save_status(value: String) -> void:
	m_save_label.text = value
