class_name ResidentInteractionRuntimePort
extends AppStatePortBase


func ensure_resident_profiles() -> void:
	m_app_state.runtime_ensure_resident_profiles()


func has_resident_profile(resident_id: String) -> bool:
	return m_app_state.runtime_has_resident_profile(resident_id)


func get_resident_profile(resident_id: String) -> Dictionary:
	return m_app_state.get_resident_profile(resident_id)


func store_resident_profile(resident_id: String, profile: Dictionary) -> void:
	m_app_state.runtime_store_resident_profile(resident_id, profile)


func emit_resident_profile_changed(resident_id: String) -> void:
	m_app_state.runtime_emit_resident_profile_changed(resident_id)


func get_fragments_found() -> int:
	return int(_state_value(&"fragments_found", 0))


func get_story_flags() -> Dictionary:
	return m_app_state.get_story_flags()


func get_landmark_progress(landmark_id: String) -> Dictionary:
	return m_app_state.get_landmark_progress(landmark_id)


func get_landmark_state(landmark_id: String) -> String:
	return m_app_state.get_landmark_state(landmark_id)


func get_story_flag(flag_id: String, default_value: Variant = false) -> Variant:
	return m_app_state.get_story_flag(flag_id, default_value)


func can_resolve_story_event(event_id: String) -> bool:
	return m_app_state.can_resolve_story_event(event_id)


func get_story_event_blockers(event_id: String) -> Dictionary:
	return m_app_state.get_story_event_blockers(event_id)


func pick_story_candidate(candidates: Array, context: Dictionary = {}) -> Dictionary:
	return m_app_state.pick_story_candidate(candidates, context)


func matches_story_conditions(conditions: Variant, context: Dictionary = {}) -> bool:
	return m_app_state.matches_story_conditions(conditions, context)


func apply_story_effects(payload: Dictionary, context: Dictionary = {}) -> void:
	m_app_state.apply_story_effects(payload, context)


func set_residents(residents: PackedStringArray) -> void:
	m_app_state.set_residents(residents)


func autosave_story_progress() -> void:
	m_app_state.runtime_autosave_story_progress()


func refresh_player_costumes() -> void:
	m_app_state.runtime_refresh_player_costumes()


func update_summary_counts() -> void:
	m_app_state.runtime_update_summary_counts()


func emit_story_milestone(milestone_id: String, context: Dictionary = {}) -> void:
	m_app_state.runtime_emit_story_milestone(milestone_id, context)
