extends Control

const APP_RUNTIME := preload("res://game/app_runtime.gd")

@onready var m_objective_card: PanelContainer = $ObjectiveCard
@onready var m_status_card: PanelContainer = $StatusCard
@onready var m_hint_card: PanelContainer = $HintCard
@onready var m_header_label: Label = $ObjectiveCard/Margin/Body/Header
@onready var m_objective_label: Label = $ObjectiveCard/Margin/Body/Objective
@onready var m_task_label: Label = $ObjectiveCard/Margin/Body/Task
@onready var m_mode_label: Label = $StatusCard/Margin/Body/Mode
@onready var m_chapter_label: Label = $StatusCard/Margin/Body/Chapter
@onready var m_time_label: Label = $StatusCard/Margin/Body/Time
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
	if !_app_state().state_committed.is_connected(_on_state_committed):
		_app_state().state_committed.connect(_on_state_committed)
	_app_state().melody_hint_shown.connect(_show_melody_hint)


func _refresh_all() -> void:
	var projection := _app_state().get_projection()
	_refresh_objective(projection.objective)
	_refresh_mode(projection.mode)
	m_chapter_label.text = "Season: %s" % projection.season_display_name
	m_time_label.text = "Time: %s" % projection.story_time_label
	_refresh_location(projection.location)
	_refresh_fragments(projection.fragments_found, projection.fragments_total)
	_refresh_hint(projection.hint)
	_refresh_save_status(projection.save_status)


func _refresh_objective(value: String) -> void:
	var projection := _app_state().get_projection()
	var active_lead_id: String = projection.active_lead_id
	var lead_text: String = projection.active_lead_text
	if lead_text.is_empty():
		lead_text = value
		m_header_label.text = "Current Lead"
	elif projection.manual_lead_pinned:
		m_header_label.text = "Pinned Lead (Manual)"
	else:
		m_header_label.text = "Pinned Lead (Auto)"

	m_objective_label.text = lead_text

	var extra_leads := maxi(projection.available_lead_ids.size() - (0 if active_lead_id.is_empty() else 1), 0)
	var task_lines := PackedStringArray(["Current task: %s" % value])
	if extra_leads > 0:
		task_lines.append("%d other live lead%s waiting in the journal." % [
			extra_leads,
			"s" if extra_leads != 1 else "",
		])
	elif !active_lead_id.is_empty():
		task_lines.append("No other live leads right now.")
	m_task_label.text = "\n".join(task_lines)


func _refresh_mode(value: String) -> void:
	m_mode_label.text = "Mode: %s" % value


func _refresh_chapter(value: String) -> void:
	m_chapter_label.text = "Chapter: %s" % value


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


func _on_state_committed(_changes: AppStateChangeSet) -> void:
	_refresh_all()
