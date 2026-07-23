class_name APosHouseholdCourtyard3D
extends Node3D

## A bounded, scene-local presentation adapter for A Po's household care beat.
## Durable state stays in AppState story flags; this scene only reflects it.

const APP_RUNTIME := preload("res://game/app_runtime.gd")

const CARE_SEEN_FLAG := "family_household_care_seen"
const CARE_MISSED_FLAG := "family_household_care_missed"
const PRESENTATION_WAITING := "waiting"
const PRESENTATION_CARED_FOR := "cared_for"
const PRESENTATION_UNTENDED := "untended"

@onready var m_warm_window: MeshInstance3D = $House/WarmWindow
@onready var m_cold_window: MeshInstance3D = $House/ColdWindow
@onready var m_lantern_glow: OmniLight3D = $House/LanternGlow
@onready var m_tended_props: Node3D = $Courtyard/TendedProps
@onready var m_untended_props: Node3D = $Courtyard/UntendedProps

var m_story_state: AppStateService = null
var m_presentation_state := PRESENTATION_WAITING


func _ready() -> void:
	_apply_presentation_state(PRESENTATION_WAITING)
	call_deferred("_bind_runtime_story_state")


func _exit_tree() -> void:
	bind_story_state(null)


func bind_story_state(story_state: AppStateService) -> void:
	if is_instance_valid(m_story_state):
		if m_story_state.state_committed.is_connected(_on_story_state_committed):
			m_story_state.state_committed.disconnect(_on_story_state_committed)

	m_story_state = story_state
	if is_instance_valid(m_story_state):
		if !m_story_state.state_committed.is_connected(_on_story_state_committed):
			m_story_state.state_committed.connect(_on_story_state_committed)
		sync_story_presentation()


func sync_story_presentation() -> void:
	if !is_instance_valid(m_story_state):
		return
	apply_story_flags(m_story_state.get_snapshot().story_flags)


func apply_story_flags(story_flags: Dictionary) -> void:
	var next_state := PRESENTATION_WAITING
	if bool(story_flags.get(CARE_SEEN_FLAG, false)):
		next_state = PRESENTATION_CARED_FOR
	elif bool(story_flags.get(CARE_MISSED_FLAG, false)):
		next_state = PRESENTATION_UNTENDED
	_apply_presentation_state(next_state)


func get_presentation_state() -> String:
	return m_presentation_state


func _bind_runtime_story_state() -> void:
	if is_instance_valid(m_story_state) or !is_inside_tree():
		return
	bind_story_state(APP_RUNTIME.get_app_state(self))


func _apply_presentation_state(next_state: String) -> void:
	m_presentation_state = next_state
	var cared_for := next_state == PRESENTATION_CARED_FOR
	var untended := next_state == PRESENTATION_UNTENDED

	if is_instance_valid(m_warm_window):
		m_warm_window.visible = cared_for
	if is_instance_valid(m_cold_window):
		m_cold_window.visible = !cared_for
	if is_instance_valid(m_lantern_glow):
		m_lantern_glow.visible = cared_for
	if is_instance_valid(m_tended_props):
		m_tended_props.visible = cared_for
	if is_instance_valid(m_untended_props):
		m_untended_props.visible = untended


func _on_story_state_committed(changes: AppStateChangeSet) -> void:
	if changes.has_domain(AppStateChangeSet.Domain.STORY):
		sync_story_presentation()
