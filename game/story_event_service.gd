class_name StoryEventService
extends RefCounted

const STORY_WORLD_REACTIVITY_SCRIPT := preload("res://game/story_world_reactivity.gd")

var m_owner: Node = null


func _init(owner: Node) -> void:
	m_owner = owner


func build_context(subject_id: String = "", extra_context: Dictionary = {}) -> Dictionary:
	var context := {
		"subject_id": subject_id.strip_edges(),
		"location": String(m_owner.location),
		"season_phase": String(m_owner.season_phase),
		"mode": String(m_owner.mode),
		"active_lead_id": String(m_owner.active_lead_id),
	}
	context.merge(extra_context, true)
	return context


func describe_subject(subject_id: String, action: String, context: Dictionary = {}) -> Dictionary:
	var normalized_subject := subject_id.strip_edges()
	var normalized_action := action.strip_edges().to_lower()
	if normalized_subject.is_empty() or normalized_action.is_empty():
		return {}

	var resolved_context := build_context(normalized_subject, context)
	match normalized_action:
		"inspect":
			return _describe_inspect_subject(normalized_subject, resolved_context)
		"talk":
			return _describe_npc_subject(normalized_subject, resolved_context)
		_:
			return {}


func activate_subject(subject_id: String, action: String, context: Dictionary = {}) -> Dictionary:
	var normalized_subject := subject_id.strip_edges()
	var normalized_action := action.strip_edges().to_lower()
	if normalized_subject.is_empty() or normalized_action.is_empty():
		return {}

	var resolved_context := build_context(normalized_subject, context)
	match normalized_action:
		"inspect":
			return _activate_inspect_subject(normalized_subject, resolved_context)
		"talk":
			return _activate_npc_subject(normalized_subject, resolved_context)
		_:
			return {}


func notify_world_event(event_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var normalized_event_id := event_id.strip_edges()
	var result := {
		"event_id": normalized_event_id,
		"context": build_context("", context),
	}
	if !normalized_event_id.is_empty():
		result["resolved"] = m_owner.resolve_story_event(normalized_event_id)
	if !payload.is_empty():
		apply_effects(payload, context)
		result["effects_applied"] = true
	return result


func pick_story_candidate(candidates: Array, context: Dictionary = {}) -> Dictionary:
	var best_candidate: Dictionary = {}
	var best_priority := -2147483648
	var resolved_context := build_context(String(context.get("subject_id", "")), context)
	for candidate_value in candidates:
		if !(candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value as Dictionary
		if !matches_conditions(candidate.get("conditions", {}), resolved_context):
			continue
		var priority := int(candidate.get("priority", 0))
		if priority > best_priority:
			best_priority = priority
			best_candidate = candidate.duplicate(true)
	return best_candidate


func matches_conditions(conditions_value: Variant, context: Dictionary = {}) -> bool:
	if !(conditions_value is Dictionary):
		return true
	var conditions: Dictionary = conditions_value
	if conditions.is_empty():
		return true

	var resolved_context := build_context(String(context.get("subject_id", "")), context)
	var resident: Dictionary = {}
	var resident_value = resolved_context.get("resident", {})
	if resident_value is Dictionary:
		resident = (resident_value as Dictionary)

	var expected_subject_id := String(conditions.get("subject_id", ""))
	if !expected_subject_id.is_empty() and String(resolved_context.get("subject_id", "")) != expected_subject_id:
		return false

	var expected_action := String(conditions.get("action", ""))
	if !expected_action.is_empty() and String(resolved_context.get("action", "")) != expected_action:
		return false

	var expected_phase: Variant = conditions.get("season_phase", null)
	if expected_phase != null:
		if expected_phase is Array or expected_phase is PackedStringArray:
			var allowed_phases: Array[String] = m_owner._normalize_string_array(expected_phase)
			if allowed_phases.find(String(m_owner.season_phase)) < 0:
				return false
		elif String(m_owner.season_phase) != String(expected_phase):
			return false

	var expected_mode := String(conditions.get("mode", ""))
	if !expected_mode.is_empty() and String(m_owner.mode) != expected_mode:
		return false

	var expected_chapter := String(conditions.get("chapter", ""))
	if !expected_chapter.is_empty() and String(m_owner.chapter) != expected_chapter:
		return false

	for flag_value in conditions.get("story_flag_all", []):
		if !bool(m_owner.get_story_flag(String(flag_value), false)):
			return false

	var any_flags: Array = conditions.get("story_flag_any", [])
	if !any_flags.is_empty():
		var matched_any := false
		for flag_value in any_flags:
			if bool(m_owner.get_story_flag(String(flag_value), false)):
				matched_any = true
				break
		if !matched_any:
			return false

	var required_routes = conditions.get("route_state", {})
	if required_routes is Dictionary:
		for route_id_value in required_routes.keys():
			var route_id := String(route_id_value)
			var expected_state := String(required_routes[route_id_value])
			var current_state := String(m_owner.get_route_progress(route_id).get("state", "idle"))
			if current_state != expected_state:
				return false

	var minimum_scores = conditions.get("route_score_min", {})
	if minimum_scores is Dictionary:
		for route_id_value in minimum_scores.keys():
			var route_id := String(route_id_value)
			if int(m_owner.get_route_progress(route_id).get("completion_score", 0)) < int(minimum_scores[route_id_value]):
				return false

	var required_landmarks = conditions.get("landmark_state", {})
	if required_landmarks is Dictionary:
		for landmark_id_value in required_landmarks.keys():
			var landmark_id := String(landmark_id_value)
			if m_owner.get_landmark_state(landmark_id) != String(required_landmarks[landmark_id_value]):
				return false

	var required_melodies = conditions.get("melody_state", {})
	if required_melodies is Dictionary:
		for melody_id_value in required_melodies.keys():
			var melody_id := String(melody_id_value)
			var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
			if String(melody_state.get("state", "unknown")) != String(required_melodies[melody_id_value]):
				return false

	if conditions.has("fragments_found_min") and m_owner.fragments_found < int(conditions.get("fragments_found_min", 0)):
		return false

	if conditions.has("trust_min") and int(resident.get("trust", 0)) < int(conditions.get("trust_min", 0)):
		return false

	var required_known: Variant = conditions.get("resident_known", [])
	if required_known is Array or required_known is PackedStringArray:
		for resident_id_value in required_known:
			var resident_id := String(resident_id_value)
			var other_resident: Dictionary = m_owner.get_resident_profile(resident_id)
			if !bool(other_resident.get("known", false)):
				return false

	if conditions.has("endgame_active") and bool(m_owner.endgame_state.get("active", false)) != bool(conditions.get("endgame_active", false)):
		return false

	return true


func apply_effects(payload: Dictionary, context: Dictionary = {}) -> void:
	if payload.is_empty():
		return

	var resolved_context := build_context(String(context.get("subject_id", "")), context)
	var new_objective := String(payload.get("objective", ""))
	if !new_objective.is_empty():
		m_owner.set_objective(new_objective)

	var new_hint := String(payload.get("hint", ""))
	if !new_hint.is_empty():
		m_owner.set_hint(new_hint)

	var new_phase := String(payload.get("season_phase", ""))
	if !new_phase.is_empty():
		m_owner.set_season_phase(new_phase)

	var new_chapter := String(payload.get("chapter", ""))
	if !new_chapter.is_empty() and m_owner.mode != "Story":
		m_owner.set_chapter(new_chapter)

	var new_status := String(payload.get("save_status", ""))
	if !new_status.is_empty():
		m_owner.set_save_status(new_status)

	var unlock_landmark := String(payload.get("unlock_landmark", ""))
	if !unlock_landmark.is_empty():
		m_owner.advance_landmark_state(unlock_landmark, "available")

	var landmark_states = payload.get("landmark_states", {})
	if landmark_states is Dictionary:
		for landmark_id in landmark_states.keys():
			m_owner.advance_landmark_state(String(landmark_id), String(landmark_states[landmark_id]))

	var landmark_reward := String(payload.get("landmark_reward", ""))
	if !landmark_reward.is_empty():
		m_owner._resolve_landmark(landmark_reward)

	var beat_story_flags = payload.get("story_flags", {})
	if beat_story_flags is Dictionary:
		for flag_id in beat_story_flags.keys():
			m_owner.set_story_flag(String(flag_id), beat_story_flags[flag_id])

	var story_event := String(payload.get("story_event", ""))
	if !story_event.is_empty():
		m_owner.resolve_story_event(story_event)

	var pin_lead_id := String(payload.get("pin_lead_id", ""))
	if !pin_lead_id.is_empty():
		m_owner.pin_story_lead(pin_lead_id)

	var resident_routine_overrides: Variant = payload.get("resident_routine_overrides", {})
	if resident_routine_overrides is Dictionary:
		for resident_id in resident_routine_overrides.keys():
			var override_value = resident_routine_overrides[resident_id]
			if override_value is Dictionary:
				m_owner.set_resident_routine_override(String(resident_id), override_value)

	var clear_override_ids: Array[String] = m_owner._normalize_string_array(payload.get("clear_resident_routine_override_ids", []))
	for resident_id in clear_override_ids:
		m_owner.clear_resident_routine_override(resident_id)

	var resident_routine_variant: Variant = payload.get("resident_routine_variant", {})
	if resident_routine_variant is Dictionary:
		for resident_id in resident_routine_variant.keys():
			var variant_value = resident_routine_variant[resident_id]
			if variant_value is Dictionary:
				m_owner.set_resident_routine_override(String(resident_id), variant_value)

	var milestone_id := String(payload.get("story_milestone", ""))
	if !milestone_id.is_empty():
		var milestone_context: Variant = payload.get("story_milestone_context", {})
		if milestone_context is Dictionary:
			var emitted_context: Dictionary = milestone_context.duplicate(true)
			emitted_context.merge(resolved_context, false)
			m_owner._emit_story_milestone(milestone_id, emitted_context)
		else:
			m_owner._emit_story_milestone(milestone_id, resolved_context)

	m_owner._update_summary_counts()
	m_owner.refresh_story_routes()


func _describe_npc_subject(subject_id: String, context: Dictionary) -> Dictionary:
	var resident_id := _resident_id_from_subject_id(subject_id)
	if resident_id.is_empty():
		return {}
	return {
		"subject_id": subject_id,
		"action": "talk",
		"resident_id": resident_id,
		"display_name": m_owner.get_resident_display_name(resident_id),
		"prompt": "Talk to %s" % m_owner.get_resident_display_name(resident_id),
		"consumed": true,
		"context": context.duplicate(true),
	}


func _activate_npc_subject(subject_id: String, context: Dictionary) -> Dictionary:
	var resident_id := _resident_id_from_subject_id(subject_id)
	if resident_id.is_empty():
		return {}
	var result: Dictionary = m_owner.interact_with_resident(resident_id)
	result["subject_id"] = subject_id
	result["action"] = "talk"
	result["resident_id"] = resident_id
	result["display_name"] = m_owner.get_resident_display_name(resident_id)
	result["consumed"] = true
	result["context"] = context.duplicate(true)
	return result


func _describe_inspect_subject(subject_id: String, context: Dictionary) -> Dictionary:
	var inspectable_id := STORY_WORLD_REACTIVITY_SCRIPT.inspectable_id_from_subject_id(subject_id)
	if inspectable_id.is_empty():
		return {}
	var display_name := String(context.get("display_name", ""))
	return STORY_WORLD_REACTIVITY_SCRIPT.resolve_inspect_result(
		m_owner,
		inspectable_id,
		display_name,
		context
	)


func _activate_inspect_subject(subject_id: String, context: Dictionary) -> Dictionary:
	var result := _describe_inspect_subject(subject_id, context)
	if result.is_empty():
		return {}
	result["consumed"] = true
	return result


func _resident_id_from_subject_id(subject_id: String) -> String:
	var normalized_subject := subject_id.strip_edges()
	if normalized_subject.begins_with("npc:"):
		return normalized_subject.substr("npc:".length())
	return ""
