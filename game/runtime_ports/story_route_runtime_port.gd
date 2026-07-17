class_name StoryRouteRuntimePort
extends AppStatePortBase


func get_mode() -> String:
	return String(_state_value(&"mode", "Title"))


func get_season_phase() -> String:
	return String(_state_value(&"season_phase", ""))


func get_story_flags() -> Dictionary:
	return m_app_state.get_story_flags()


func get_endgame_state() -> Dictionary:
	return (_state_value(&"endgame_state", {}) as Dictionary).duplicate(true)


func get_active_lead_id() -> String:
	return m_app_state.get_active_lead_id()


func get_available_lead_ids() -> PackedStringArray:
	return m_app_state.get_available_lead_ids()


func get_route_progress() -> Dictionary:
	return (_state_value(&"route_progress", {}) as Dictionary).duplicate(true)


func get_manual_pinned_lead_id() -> String:
	return m_app_state.runtime_get_manual_pinned_lead_id()


func set_manual_pinned_lead_id(lead_id: String) -> void:
	m_app_state.runtime_set_manual_pinned_lead_id(lead_id)


func get_landmark_state(landmark_id: String) -> String:
	return m_app_state.get_landmark_state(landmark_id)


func get_melody_state(melody_id: String) -> Dictionary:
	return m_app_state.get_melody_state(melody_id)


func get_resident_ids() -> PackedStringArray:
	return m_app_state.get_resident_ids()


func get_resident_profile(resident_id: String) -> Dictionary:
	return m_app_state.get_resident_profile(resident_id)


func set_all_route_progress(progress: Dictionary) -> void:
	m_app_state.set_all_route_progress(progress)


func set_active_leads(active_lead_id: String, available_lead_ids: Variant) -> void:
	m_app_state.set_active_leads(active_lead_id, available_lead_ids)


func set_story_flag(flag_id: String, value: Variant = true) -> void:
	m_app_state.set_story_flag(flag_id, value)


func set_season_phase(phase_id: String) -> void:
	m_app_state.set_season_phase(phase_id)


func set_save_status(status: String) -> void:
	m_app_state.set_save_status(status)


func set_endgame_state(state: Dictionary) -> void:
	m_app_state.set_endgame_state(state)


func update_summary_counts() -> void:
	m_app_state.runtime_update_summary_counts()


func count_helped_residents() -> int:
	return m_app_state.runtime_count_helped_residents()


func emit_story_milestone(milestone_id: String, context: Dictionary = {}) -> void:
	m_app_state.runtime_emit_story_milestone(milestone_id, context)
