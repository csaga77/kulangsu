class_name StoryEventRuntimePort
extends AppStatePortBase


func get_mode() -> String:
	return String(_state_value(&"mode", "Title"))


func get_chapter() -> String:
	return String(_state_value(&"chapter", "Arrival"))


func get_season_phase() -> String:
	return String(_state_value(&"season_phase", ""))


func get_location() -> String:
	return String(_state_value(&"location", ""))


func get_save_status() -> String:
	return String(_state_value(&"save_status", ""))


func get_fragments_found() -> int:
	return int(_state_value(&"fragments_found", 0))


func get_fragments_total() -> int:
	return int(_state_value(&"fragments_total", 0))


func get_active_lead_id() -> String:
	return m_app_state.get_active_lead_id()


func get_endgame_state() -> Dictionary:
	return (_state_value(&"endgame_state", {}) as Dictionary).duplicate(true)


func get_melody_progress() -> Dictionary:
	return (_state_value(&"melody_progress", {}) as Dictionary).duplicate(true)


func get_story_day() -> int:
	return m_app_state.get_story_day()


func get_world_hour() -> float:
	return m_app_state.get_world_hour()


func get_time_of_day() -> String:
	return m_app_state.get_time_of_day()


func get_story_flag(flag_id: String, default_value: Variant = false) -> Variant:
	return m_app_state.get_story_flag(flag_id, default_value)


func get_route_progress(route_id: String) -> Dictionary:
	return m_app_state.get_route_progress(route_id)


func get_landmark_progress(landmark_id: String) -> Dictionary:
	return m_app_state.get_landmark_progress(landmark_id)


func get_landmark_state(landmark_id: String) -> String:
	return m_app_state.get_landmark_state(landmark_id)


func get_melody_state(melody_id: String) -> Dictionary:
	return m_app_state.get_melody_state(melody_id)


func get_resident_profile(resident_id: String) -> Dictionary:
	return m_app_state.get_resident_profile(resident_id)


func get_resident_display_name(resident_id: String) -> String:
	return m_app_state.get_resident_display_name(resident_id)


func is_world_hour_in_range(min_hour: Variant, max_hour: Variant) -> bool:
	return m_app_state.is_world_hour_in_range(min_hour, max_hour)


func build_input_hint(primary_action: String) -> String:
	return m_app_state.build_input_hint(primary_action)


func can_resolve_story_event(event_id: String) -> bool:
	return m_app_state.can_resolve_story_event(event_id)


func matches_story_conditions(conditions: Variant, context: Dictionary = {}) -> bool:
	return m_app_state.matches_story_conditions(conditions, context)


func interact_with_resident(resident_id: String) -> Dictionary:
	return m_app_state.interact_with_resident(resident_id)


func set_objective(objective: String) -> void:
	m_app_state.set_objective(objective)


func set_hint(hint: String) -> void:
	m_app_state.set_hint(hint)


func set_season_phase(phase_id: String) -> void:
	m_app_state.set_season_phase(phase_id)


func apply_story_time_effects(payload: Dictionary) -> bool:
	return m_app_state.apply_story_time_effects(payload)


func set_chapter(chapter: String) -> void:
	m_app_state.set_chapter(chapter)


func set_save_status(status: String) -> void:
	m_app_state.set_save_status(status)


func advance_landmark_state(landmark_id: String, state_id: String) -> void:
	m_app_state.advance_landmark_state(landmark_id, state_id)


func set_landmark_progress(landmark_id: String, progress: Dictionary) -> void:
	m_app_state.set_landmark_progress(landmark_id, progress)


func set_melody_progress(progress: Dictionary) -> void:
	m_app_state.set_melody_progress(progress)


func set_journal_unlocked(unlocked: bool) -> void:
	m_app_state.set_journal_unlocked(unlocked)


func set_story_flag(flag_id: String, value: Variant = true) -> void:
	m_app_state.set_story_flag(flag_id, value)


func resolve_story_event(event_id: String) -> bool:
	return m_app_state.resolve_story_event(event_id)


func pin_story_lead(lead_id: String) -> void:
	m_app_state.pin_story_lead(lead_id)


func set_resident_routine_override(resident_id: String, override_data: Dictionary) -> void:
	m_app_state.set_resident_routine_override(resident_id, override_data)


func clear_resident_routine_override(resident_id: String) -> void:
	m_app_state.clear_resident_routine_override(resident_id)


func unlock_shortcut(shortcut_id: String) -> bool:
	return m_app_state.unlock_shortcut(shortcut_id)


func request_melody_prompt(
	melody_id: String,
	prompt_mode: String,
	completion_kind: String = "",
	request_overrides: Dictionary = {}
) -> void:
	m_app_state.request_melody_prompt(
		melody_id,
		prompt_mode,
		completion_kind,
		request_overrides
	)


func refresh_story_routes() -> void:
	m_app_state.refresh_story_routes()


func resolve_landmark(landmark_id: String) -> void:
	m_app_state.runtime_resolve_landmark(landmark_id)


func request_landmark_audio_cue(
	cue_id: String,
	landmark_id: String,
	trigger_id: String,
	display_name: String
) -> void:
	m_app_state.runtime_request_landmark_audio_cue(
		cue_id,
		landmark_id,
		trigger_id,
		display_name
	)


func emit_melody_hint(text: String) -> void:
	m_app_state.runtime_emit_melody_hint(text)


func emit_melody_prompt(request: Dictionary) -> void:
	m_app_state.runtime_emit_melody_prompt(request)


func emit_story_milestone(milestone_id: String, context: Dictionary = {}) -> void:
	m_app_state.runtime_emit_story_milestone(milestone_id, context)


func count_helped_residents() -> int:
	return m_app_state.runtime_count_helped_residents()


func update_summary_counts() -> void:
	m_app_state.runtime_update_summary_counts()


func autosave_story_progress() -> void:
	m_app_state.runtime_autosave_story_progress()


func activate_legacy_landmark_trigger(
	landmark_id: String,
	trigger_id: String,
	display_name: String
) -> bool:
	return m_app_state.runtime_activate_legacy_landmark_trigger(
		landmark_id,
		trigger_id,
		display_name
	)
