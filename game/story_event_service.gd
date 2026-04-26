class_name StoryEventService
extends RefCounted

const STORY_WORLD_REACTIVITY_SCRIPT := preload("res://game/story_world_reactivity.gd")
const STORY_EVENT_CATALOG_SCRIPT := preload("res://game/story_event_catalog.gd")
const LANDMARK_SUBJECT_PREFIX := "landmark:"

var m_owner: Node = null
var m_subject_binding_index: Dictionary = {}
var m_subject_metadata_index: Dictionary = {}
var m_world_event_binding_index: Dictionary = {}


func _init(owner: Node) -> void:
	m_owner = owner
	m_subject_binding_index = STORY_EVENT_CATALOG_SCRIPT.build_subject_binding_index()
	m_subject_metadata_index = STORY_EVENT_CATALOG_SCRIPT.build_subject_metadata_index()
	m_world_event_binding_index = STORY_EVENT_CATALOG_SCRIPT.build_world_event_binding_index()


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
	if normalized_subject.is_empty():
		return {}

	var resolved_context := build_context(normalized_subject, context)
	var metadata := _resolve_subject_metadata(normalized_subject, action, resolved_context)
	var normalized_action := String(metadata.get("action", action)).strip_edges().to_lower()
	if normalized_action.is_empty():
		return {}
	resolved_context = _build_subject_context(normalized_subject, normalized_action, metadata, resolved_context)

	var result := {}
	match normalized_action:
		"inspect":
			result = _describe_inspect_subject(normalized_subject, resolved_context)
		"talk":
			result = _describe_npc_subject(normalized_subject, resolved_context)
		"collect", "perform":
			result = _describe_landmark_subject(normalized_subject, normalized_action, resolved_context)
		_:
			return {}
	return _apply_subject_metadata(result, metadata, resolved_context)


func describe_subject_metadata(subject_id: String, context: Dictionary = {}) -> Dictionary:
	var normalized_subject := subject_id.strip_edges()
	if normalized_subject.is_empty():
		return {}
	return _resolve_subject_metadata(normalized_subject, "", build_context(normalized_subject, context))


func activate_subject(subject_id: String, action: String, context: Dictionary = {}) -> Dictionary:
	var normalized_subject := subject_id.strip_edges()
	if normalized_subject.is_empty():
		return {}

	var resolved_context := build_context(normalized_subject, context)
	var metadata := _resolve_subject_metadata(normalized_subject, action, resolved_context)
	var normalized_action := String(metadata.get("action", action)).strip_edges().to_lower()
	if normalized_action.is_empty():
		return {}
	resolved_context = _build_subject_context(normalized_subject, normalized_action, metadata, resolved_context)
	if !metadata.is_empty() and !bool(metadata.get("targetable", metadata.get("visible", true))):
		var blocked_result := _apply_subject_metadata({}, metadata, resolved_context)
		blocked_result["handled"] = false
		blocked_result["blocked"] = true
		return blocked_result

	var result := {}
	match normalized_action:
		"inspect":
			result = _activate_inspect_subject(normalized_subject, resolved_context)
		"talk":
			result = _activate_npc_subject(normalized_subject, resolved_context)
		"collect", "perform":
			result = _activate_landmark_subject(normalized_subject, normalized_action, resolved_context)
		_:
			return {}
	return _apply_subject_metadata(result, metadata, resolved_context)


func notify_world_event(event_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var normalized_event_id := event_id.strip_edges()
	var resolved_context := build_context("", context)
	resolved_context["event_id"] = normalized_event_id
	if !payload.is_empty():
		resolved_context.merge(payload, false)

	var result := {
		"event_id": normalized_event_id,
		"context": resolved_context.duplicate(true),
		"handled": false,
		"authored": false,
		"effects_applied": false,
	}

	var candidates := _get_world_event_binding_candidates(normalized_event_id)
	var binding := pick_story_candidate(candidates, resolved_context)
	if !binding.is_empty():
		result["handled"] = true
		result["authored"] = true
		result["effects_applied"] = true
		result["event_path"] = String(binding.get("event_path", ""))
		apply_effects(binding.get("effects", {}), resolved_context)
		return result

	if !candidates.is_empty():
		result["handled"] = true
		result["authored"] = true
		return result

	if !normalized_event_id.is_empty():
		result["resolved"] = m_owner.resolve_story_event(normalized_event_id)
		result["handled"] = bool(result.get("resolved", false))
	if !payload.is_empty():
		apply_effects(payload, resolved_context)
		result["effects_applied"] = true
		result["handled"] = true
	return result


func sync_story_route_dependent_landmarks(event_id: String = "") -> void:
	if event_id.is_empty() or event_id == "spring_festival_resolved" or event_id == "melody_bagua_aligned":
		_sync_festival_stage_availability(event_id == "spring_festival_resolved")


func activate_authored_landmark_subject(
	landmark_id: String,
	trigger_id: String,
	display_name: String
) -> Dictionary:
	var subject_id := build_landmark_subject_id(landmark_id, trigger_id)
	var action := default_landmark_action(landmark_id, trigger_id)
	var context := build_context(subject_id, {
		"display_name": display_name,
		"landmark_id": landmark_id,
		"trigger_id": trigger_id,
		"action": action,
	})
	return _activate_landmark_subject(subject_id, action, context, false)


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
			if !_matches_expected_value(m_owner.get_landmark_state(landmark_id), required_landmarks[landmark_id_value]):
				return false

	var required_progress_entries = conditions.get("landmark_progress_contains_all", {})
	if required_progress_entries is Dictionary:
		for landmark_id_value in required_progress_entries.keys():
			var landmark_id := String(landmark_id_value)
			var progress_requirements = required_progress_entries[landmark_id_value]
			if !(progress_requirements is Dictionary):
				continue
			var progress: Dictionary = m_owner.get_landmark_progress(landmark_id)
			for progress_key_value in progress_requirements.keys():
				var progress_key := String(progress_key_value)
				var required_entries: Array[String] = m_owner._normalize_string_array(progress_requirements[progress_key_value])
				var current_entries: Array[String] = m_owner._normalize_string_array(progress.get(progress_key, []))
				for entry in required_entries:
					if current_entries.find(entry) < 0:
						return false

	var minimum_progress_counts = conditions.get("landmark_progress_count_min", {})
	if minimum_progress_counts is Dictionary:
		for landmark_id_value in minimum_progress_counts.keys():
			var landmark_id := String(landmark_id_value)
			var count_requirements = minimum_progress_counts[landmark_id_value]
			if !(count_requirements is Dictionary):
				continue
			var progress: Dictionary = m_owner.get_landmark_progress(landmark_id)
			for progress_key_value in count_requirements.keys():
				var progress_key := String(progress_key_value)
				if _progress_value_count(progress.get(progress_key, null)) < int(count_requirements[progress_key_value]):
					return false

	var required_progress_fields = conditions.get("landmark_progress_fields", {})
	if required_progress_fields is Dictionary:
		for landmark_id_value in required_progress_fields.keys():
			var landmark_id := String(landmark_id_value)
			var field_requirements = required_progress_fields[landmark_id_value]
			if !(field_requirements is Dictionary):
				continue
			var progress: Dictionary = m_owner.get_landmark_progress(landmark_id)
			for field_name_value in field_requirements.keys():
				var field_name := String(field_name_value)
				if !_matches_expected_value(progress.get(field_name, null), field_requirements[field_name_value]):
					return false

	var required_melodies = conditions.get("melody_state", {})
	if required_melodies is Dictionary:
		for melody_id_value in required_melodies.keys():
			var melody_id := String(melody_id_value)
			var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
			if String(melody_state.get("state", "unknown")) != String(required_melodies[melody_id_value]):
				return false

	var required_melody_fields = conditions.get("melody_progress_fields", {})
	if required_melody_fields is Dictionary:
		for melody_id_value in required_melody_fields.keys():
			var melody_id := String(melody_id_value)
			var field_requirements = required_melody_fields[melody_id_value]
			if !(field_requirements is Dictionary):
				continue
			var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
			for field_name_value in field_requirements.keys():
				var field_name := String(field_name_value)
				if !_matches_expected_value(melody_state.get(field_name, null), field_requirements[field_name_value]):
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
	var formatted_payload: Dictionary = payload.duplicate(true)
	var formatted_payload_value = _deep_format_strings(payload, resolved_context)
	if formatted_payload_value is Dictionary:
		formatted_payload = formatted_payload_value

	var new_objective := String(formatted_payload.get("objective", ""))
	if !new_objective.is_empty():
		m_owner.set_objective(new_objective)

	var new_hint := String(formatted_payload.get("hint", ""))
	if !new_hint.is_empty():
		m_owner.set_hint(new_hint)

	var hint_action := String(formatted_payload.get("hint_action", ""))
	if !hint_action.is_empty():
		m_owner.set_hint(m_owner.build_input_hint(hint_action))

	var new_phase := String(formatted_payload.get("season_phase", ""))
	if !new_phase.is_empty():
		m_owner.set_season_phase(new_phase)

	var new_chapter := String(formatted_payload.get("chapter", ""))
	if !new_chapter.is_empty() and m_owner.mode != "Story":
		m_owner.set_chapter(new_chapter)

	var new_status := String(formatted_payload.get("save_status", ""))
	if !new_status.is_empty():
		m_owner.set_save_status(new_status)

	var unlock_landmark := String(formatted_payload.get("unlock_landmark", ""))
	if !unlock_landmark.is_empty():
		m_owner.advance_landmark_state(unlock_landmark, "available")

	var landmark_states = formatted_payload.get("landmark_states", {})
	if landmark_states is Dictionary:
		for landmark_id in landmark_states.keys():
			m_owner.advance_landmark_state(String(landmark_id), String(landmark_states[landmark_id]))

	var landmark_progress_list_append = formatted_payload.get("landmark_progress_list_append_unique", {})
	if landmark_progress_list_append is Dictionary:
		for landmark_id_value in landmark_progress_list_append.keys():
			var landmark_id := String(landmark_id_value)
			var append_requirements = landmark_progress_list_append[landmark_id_value]
			if !(append_requirements is Dictionary):
				continue
			var current_progress: Dictionary = m_owner.get_landmark_progress(landmark_id)
			if current_progress.is_empty():
				continue
			var patched_progress: Dictionary = current_progress.duplicate(true)
			for progress_key_value in append_requirements.keys():
				var progress_key := String(progress_key_value)
				var existing_values: Array[String] = m_owner._normalize_string_array(patched_progress.get(progress_key, []))
				var appended_values: Array[String] = m_owner._normalize_string_array(append_requirements[progress_key_value])
				for value in appended_values:
					if existing_values.find(value) < 0:
						existing_values.append(value)
				patched_progress[progress_key] = existing_values
			m_owner.set_landmark_progress(landmark_id, patched_progress)

	var landmark_progress_patch = formatted_payload.get("landmark_progress_patch", {})
	if landmark_progress_patch is Dictionary:
		for landmark_id_value in landmark_progress_patch.keys():
			var landmark_id := String(landmark_id_value)
			var progress_patch = landmark_progress_patch[landmark_id_value]
			if !(progress_patch is Dictionary):
				continue
			var current_progress: Dictionary = m_owner.get_landmark_progress(landmark_id)
			if current_progress.is_empty():
				continue
			var patched_progress: Dictionary = current_progress.duplicate(true)
			patched_progress.merge(progress_patch, true)
			m_owner.set_landmark_progress(landmark_id, patched_progress)

	var melody_progress_patch = formatted_payload.get("melody_progress_patch", {})
	if melody_progress_patch is Dictionary:
		_apply_melody_progress_patch(melody_progress_patch)

	var melody_source_award = formatted_payload.get("melody_source_award", {})
	if melody_source_award is Dictionary and !melody_source_award.is_empty():
		_apply_melody_source_award(melody_source_award)

	var landmark_reward := String(formatted_payload.get("landmark_reward", ""))
	if !landmark_reward.is_empty():
		var reward_result := notify_world_event(
			"landmark_reward:%s" % landmark_reward,
			{},
			_merge_context(resolved_context, {"landmark_id": landmark_reward})
		)
		if !bool(reward_result.get("handled", false)):
			m_owner._resolve_landmark(landmark_reward)

	var landmark_audio_cue_request = formatted_payload.get("landmark_audio_cue_request", {})
	if landmark_audio_cue_request is Dictionary:
		var cue_id := String(landmark_audio_cue_request.get("cue_id", ""))
		var cue_landmark_id := String(landmark_audio_cue_request.get("landmark_id", ""))
		var cue_trigger_id := String(landmark_audio_cue_request.get("trigger_id", ""))
		var cue_display_name := String(landmark_audio_cue_request.get("display_name", resolved_context.get("display_name", "")))
		if !cue_id.is_empty() and !cue_landmark_id.is_empty() and !cue_trigger_id.is_empty():
			m_owner._request_landmark_audio_cue(cue_id, cue_landmark_id, cue_trigger_id, cue_display_name)

	var explicit_melody_hint := String(formatted_payload.get("melody_hint_text", "")).strip_edges()
	if !explicit_melody_hint.is_empty():
		m_owner._emit_melody_hint_shown(explicit_melody_hint)

	var melody_prompt_request = formatted_payload.get("melody_prompt_request", {})
	if melody_prompt_request is Dictionary and !melody_prompt_request.is_empty():
		m_owner._emit_melody_prompt_requested(melody_prompt_request.duplicate(true))

	var melody_prompt_request_builder = formatted_payload.get("melody_prompt_request_builder", {})
	if melody_prompt_request_builder is Dictionary and !melody_prompt_request_builder.is_empty():
		var melody_id := String(melody_prompt_request_builder.get("melody_id", "")).strip_edges()
		var prompt_mode := String(melody_prompt_request_builder.get("prompt_mode", "")).strip_edges()
		var completion_kind := String(melody_prompt_request_builder.get("completion_kind", "")).strip_edges()
		var request_overrides := {}
		var request_overrides_value = melody_prompt_request_builder.get("request_overrides", {})
		if request_overrides_value is Dictionary:
			request_overrides = (request_overrides_value as Dictionary).duplicate(true)
		if !melody_id.is_empty() and !prompt_mode.is_empty():
			m_owner.request_melody_prompt(melody_id, prompt_mode, completion_kind, request_overrides)

	var beat_story_flags = formatted_payload.get("story_flags", {})
	if beat_story_flags is Dictionary:
		for flag_id in beat_story_flags.keys():
			m_owner.set_story_flag(String(flag_id), beat_story_flags[flag_id])

	var story_event := String(formatted_payload.get("story_event", ""))
	if !story_event.is_empty() and m_owner.can_resolve_story_event(story_event):
		m_owner.resolve_story_event(story_event)

	var journal_unlocked_value = formatted_payload.get("journal_unlocked", null)
	if journal_unlocked_value != null:
		m_owner.set_journal_unlocked(bool(journal_unlocked_value))

	var unlocked_shortcuts: Array[String] = []
	var unlock_shortcut_value = formatted_payload.get("unlock_shortcut", null)
	if unlock_shortcut_value is String:
		var shortcut_id := String(unlock_shortcut_value).strip_edges()
		if !shortcut_id.is_empty():
			unlocked_shortcuts.append(shortcut_id)
	elif unlock_shortcut_value is Array or unlock_shortcut_value is PackedStringArray:
		unlocked_shortcuts = m_owner._normalize_string_array(unlock_shortcut_value)
	for shortcut_id in unlocked_shortcuts:
		m_owner.unlock_shortcut(shortcut_id)

	var pin_lead_id := String(formatted_payload.get("pin_lead_id", ""))
	if !pin_lead_id.is_empty():
		m_owner.pin_story_lead(pin_lead_id)

	var resident_routine_overrides: Variant = formatted_payload.get("resident_routine_overrides", {})
	if resident_routine_overrides is Dictionary:
		for resident_id in resident_routine_overrides.keys():
			var override_value = resident_routine_overrides[resident_id]
			if override_value is Dictionary:
				m_owner.set_resident_routine_override(String(resident_id), override_value)

	var clear_override_ids: Array[String] = m_owner._normalize_string_array(formatted_payload.get("clear_resident_routine_override_ids", []))
	for resident_id in clear_override_ids:
		m_owner.clear_resident_routine_override(resident_id)

	var resident_routine_variant: Variant = formatted_payload.get("resident_routine_variant", {})
	if resident_routine_variant is Dictionary:
		for resident_id in resident_routine_variant.keys():
			var variant_value = resident_routine_variant[resident_id]
			if variant_value is Dictionary:
				m_owner.set_resident_routine_override(String(resident_id), variant_value)

	var milestone_id := String(formatted_payload.get("story_milestone", ""))
	if !milestone_id.is_empty():
		var milestone_context: Variant = formatted_payload.get("story_milestone_context", {})
		if milestone_context is Dictionary:
			var emitted_context: Dictionary = milestone_context.duplicate(true)
			emitted_context.merge(resolved_context, false)
			m_owner._emit_story_milestone(milestone_id, emitted_context)
		else:
			m_owner._emit_story_milestone(milestone_id, resolved_context)

	var festival_performed_milestone := bool(formatted_payload.get("festival_performed_milestone", false))
	if festival_performed_milestone:
		m_owner._emit_story_milestone("festival_performed", {
			"fragments_found": m_owner.fragments_found,
			"helped_residents": m_owner._count_helped_residents(),
		})

	var landmark_resolved_milestone := String(formatted_payload.get("landmark_resolved_milestone", "")).strip_edges()
	if !landmark_resolved_milestone.is_empty():
		m_owner._emit_story_milestone("landmark_resolved", {
			"landmark_id": landmark_resolved_milestone,
			"fragments_found": m_owner.fragments_found,
			"helped_residents": m_owner._count_helped_residents(),
		})

	var conditional_effects = formatted_payload.get("conditional_effects", [])
	if conditional_effects is Array and !conditional_effects.is_empty():
		var conditional_binding := pick_story_candidate(conditional_effects, resolved_context)
		if !conditional_binding.is_empty():
			var conditional_payload = conditional_binding.get("effects", {})
			if conditional_payload is Dictionary:
				apply_effects(conditional_payload, resolved_context)

	m_owner._update_summary_counts()
	m_owner.refresh_story_routes()
	if bool(formatted_payload.get("autosave_story_progress", false)):
		m_owner._autosave_story_progress()


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


func _describe_landmark_subject(subject_id: String, action: String, context: Dictionary) -> Dictionary:
	var subject_parts := _parse_landmark_subject(subject_id)
	if subject_parts.is_empty():
		return {}

	var candidates := _get_subject_binding_candidates(subject_id, action)
	var binding: Dictionary = _pick_subject_binding_from_candidates(candidates, context)
	var display_name := String(context.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = String(subject_parts.get("trigger_id", "")).replace("_", " ").strip_edges()
		if display_name.is_empty():
			display_name = String(subject_parts.get("landmark_id", "landmark interaction")).replace("_", " ").strip_edges()

	var prompt := "%s %s" % [_display_verb_for_action(action), display_name]
	if !binding.is_empty():
		var authored_prompt := _format_context_text(String(binding.get("prompt", "")).strip_edges(), context)
		if !authored_prompt.is_empty():
			prompt = authored_prompt
	elif !candidates.is_empty():
		var fallback_prompt := _format_context_text(String(candidates[0].get("prompt", "")).strip_edges(), context)
		if !fallback_prompt.is_empty():
			prompt = fallback_prompt

	var event_path := ""
	if !binding.is_empty():
		event_path = String(binding.get("event_path", ""))
	elif !candidates.is_empty():
		event_path = String(candidates[0].get("event_path", ""))

	return {
		"subject_id": subject_id,
		"action": action,
		"landmark_id": String(subject_parts.get("landmark_id", "")),
		"trigger_id": String(subject_parts.get("trigger_id", "")),
		"display_name": display_name,
		"prompt": prompt,
		"consumed": false,
		"handled": !candidates.is_empty(),
		"event_path": event_path,
		"context": context.duplicate(true),
	}


func _activate_landmark_subject(
	subject_id: String,
	action: String,
	context: Dictionary,
	allow_legacy_bridge: bool = true
) -> Dictionary:
	var candidates := _get_subject_binding_candidates(subject_id, action)
	var description := _describe_landmark_subject(subject_id, action, context)
	if description.is_empty():
		return {}

	var binding: Dictionary = _pick_subject_binding_from_candidates(candidates, context)
	if !binding.is_empty():
		description["handled"] = true
		description["authored"] = true
		apply_effects(binding.get("effects", {}), context)
		description["consumed"] = bool(binding.get("consumes_interaction", true))
		description["status_text"] = String(m_owner.save_status)
		description["line"] = String(m_owner.save_status)
		description["text"] = String(m_owner.save_status)
		return description

	if !candidates.is_empty():
		description["handled"] = true
		description["authored"] = true
		description["consumed"] = false
		return description

	if !allow_legacy_bridge:
		return {}

	var display_name := String(description.get("display_name", ""))
	var consumed: bool = m_owner._activate_legacy_landmark_trigger(
		String(description.get("landmark_id", "")),
		String(description.get("trigger_id", "")),
		display_name
	)
	description["consumed"] = consumed
	description["handled"] = true
	description["status_text"] = String(m_owner.save_status)
	description["line"] = String(m_owner.save_status)
	description["text"] = String(m_owner.save_status)
	return description


func build_landmark_subject_id(landmark_id: String, trigger_id: String) -> String:
	var normalized_landmark_id := landmark_id.strip_edges()
	var normalized_trigger_id := trigger_id.strip_edges()
	if normalized_landmark_id.is_empty():
		return ""
	if normalized_trigger_id.is_empty():
		return "%s%s" % [LANDMARK_SUBJECT_PREFIX, normalized_landmark_id]
	return "%s%s.%s" % [LANDMARK_SUBJECT_PREFIX, normalized_landmark_id, normalized_trigger_id]


func default_landmark_action(landmark_id: String, trigger_id: String) -> String:
	var subject_metadata := _get_subject_metadata(build_landmark_subject_id(landmark_id, trigger_id))
	if !subject_metadata.is_empty():
		var metadata_action := String(subject_metadata.get("default_action", "")).strip_edges().to_lower()
		if !metadata_action.is_empty():
			return metadata_action
	if landmark_id == "festival_stage":
		return "perform"
	if landmark_id == "trinity_church" and trigger_id == "choir_chime":
		return "perform"
	return "collect"


func _get_subject_metadata(subject_id: String) -> Dictionary:
	return m_subject_metadata_index.get(subject_id.strip_edges(), {}).duplicate(true)


func _resolve_subject_metadata(subject_id: String, action: String, context: Dictionary) -> Dictionary:
	var normalized_subject := subject_id.strip_edges()
	var metadata := _get_subject_metadata(normalized_subject)
	var resolved_action := String(context.get("action", action)).strip_edges().to_lower()
	var resolved_display_name := String(context.get("display_name", "")).strip_edges()
	var active_binding := _pick_subject_binding_for_metadata(normalized_subject, resolved_action, context)
	var binding_metadata := {}
	var raw_binding_metadata = active_binding.get("subject_metadata", {})
	if raw_binding_metadata is Dictionary:
		binding_metadata = (raw_binding_metadata as Dictionary).duplicate(true)
	if !active_binding.is_empty():
		if resolved_action.is_empty():
			resolved_action = String(active_binding.get("action", "")).strip_edges().to_lower()
		if resolved_display_name.is_empty():
			resolved_display_name = String(
				binding_metadata.get("display_name", active_binding.get("display_name", ""))
			).strip_edges()
	if !metadata.is_empty():
		if resolved_action.is_empty():
			resolved_action = String(metadata.get("default_action", "")).strip_edges().to_lower()
		if resolved_display_name.is_empty():
			resolved_display_name = String(metadata.get("display_name", "")).strip_edges()
	else:
		if resolved_display_name.is_empty():
			resolved_display_name = _fallback_subject_display_name(normalized_subject)
		if resolved_action.is_empty() and normalized_subject.begins_with(LANDMARK_SUBJECT_PREFIX):
			var subject_parts := _parse_landmark_subject(normalized_subject)
			resolved_action = default_landmark_action(
				String(subject_parts.get("landmark_id", "")),
				String(subject_parts.get("trigger_id", ""))
			)

	var metadata_context := _merge_context(context, {
		"subject_id": normalized_subject,
		"action": resolved_action,
		"display_name": resolved_display_name,
	})
	var resolved_metadata := metadata.duplicate(true)
	if !binding_metadata.is_empty():
		resolved_metadata.merge(binding_metadata, true)
	resolved_metadata["subject_id"] = normalized_subject
	resolved_metadata["action"] = resolved_action
	resolved_metadata["display_name"] = resolved_display_name
	if !active_binding.is_empty():
		resolved_metadata["active_binding"] = active_binding.duplicate(true)
	resolved_metadata.merge(_resolve_subject_presence(resolved_metadata, metadata_context), true)
	return resolved_metadata


func _resolve_subject_presence(metadata: Dictionary, context: Dictionary) -> Dictionary:
	var presence_rules_value = metadata.get("presence_rules", [])
	if !(presence_rules_value is Array) or (presence_rules_value as Array).is_empty():
		return {
			"visible": true,
			"targetable": true,
		}

	var presence_rules: Array = presence_rules_value
	var rule := pick_story_candidate(presence_rules, context)
	if rule.is_empty():
		return {
			"visible": false,
			"targetable": false,
		}

	var visible := bool(rule.get("visible", true))
	var targetable := bool(rule.get("targetable", visible))
	return {
		"visible": visible,
		"targetable": targetable,
		"presence_rule": rule.duplicate(true),
	}


func _build_subject_context(subject_id: String, action: String, metadata: Dictionary, context: Dictionary) -> Dictionary:
	var merged_context := context.duplicate(true)
	merged_context["subject_id"] = subject_id
	merged_context["action"] = action
	var display_name := String(metadata.get("display_name", context.get("display_name", ""))).strip_edges()
	if !display_name.is_empty():
		merged_context["display_name"] = display_name
	return merged_context


func _apply_subject_metadata(result: Dictionary, metadata: Dictionary, context: Dictionary) -> Dictionary:
	var enriched := result.duplicate(true)
	if String(enriched.get("subject_id", "")).is_empty():
		enriched["subject_id"] = String(metadata.get("subject_id", context.get("subject_id", "")))
	if String(enriched.get("action", "")).is_empty():
		enriched["action"] = String(metadata.get("action", context.get("action", "")))
	if String(enriched.get("display_name", "")).strip_edges().is_empty():
		enriched["display_name"] = String(metadata.get("display_name", context.get("display_name", ""))).strip_edges()
	if !metadata.is_empty():
		enriched["visible"] = bool(metadata.get("visible", enriched.get("visible", true)))
		enriched["targetable"] = bool(metadata.get("targetable", enriched.get("targetable", enriched.get("visible", true))))
	if !enriched.has("context"):
		enriched["context"] = context.duplicate(true)
	return enriched


func _fallback_subject_display_name(subject_id: String) -> String:
	var normalized_subject := subject_id.strip_edges()
	if normalized_subject.is_empty():
		return ""
	var subject_tail := normalized_subject.get_slice(":", 1)
	if subject_tail.is_empty():
		subject_tail = normalized_subject
	subject_tail = subject_tail.get_slice(".", subject_tail.get_slice_count(".") - 1)
	return String(subject_tail).replace("_", " ").strip_edges()


func _resident_id_from_subject_id(subject_id: String) -> String:
	var normalized_subject := subject_id.strip_edges()
	if normalized_subject.begins_with("npc:"):
		return normalized_subject.substr("npc:".length())
	return ""


func _parse_landmark_subject(subject_id: String) -> Dictionary:
	var normalized_subject := subject_id.strip_edges()
	if !normalized_subject.begins_with(LANDMARK_SUBJECT_PREFIX):
		return {}

	var raw_subject := normalized_subject.substr(LANDMARK_SUBJECT_PREFIX.length())
	if raw_subject.is_empty():
		return {}

	var split_index := raw_subject.find(".")
	if split_index < 0:
		return {
			"landmark_id": raw_subject,
			"trigger_id": "",
		}

	return {
		"landmark_id": raw_subject.substr(0, split_index),
		"trigger_id": raw_subject.substr(split_index + 1),
	}


func _get_subject_binding_candidates(subject_id: String, action: String) -> Array[Dictionary]:
	var binding_key := _subject_binding_key(subject_id, action)
	if !m_subject_binding_index.has(binding_key):
		return []
	var candidates: Array[Dictionary] = []
	var raw_candidates = m_subject_binding_index[binding_key]
	if raw_candidates is Array:
		for candidate_value in raw_candidates:
			if candidate_value is Dictionary:
				candidates.append((candidate_value as Dictionary).duplicate(true))
	return candidates


func _pick_subject_binding_from_candidates(candidates: Array[Dictionary], context: Dictionary) -> Dictionary:
	return pick_story_candidate(candidates, context)


func _pick_subject_binding(subject_id: String, action: String, context: Dictionary) -> Dictionary:
	return _pick_subject_binding_from_candidates(_get_subject_binding_candidates(subject_id, action), context)


func _subject_binding_key(subject_id: String, action: String) -> String:
	return "%s|%s" % [subject_id.strip_edges(), action.strip_edges().to_lower()]


func _get_subject_binding_candidates_for_all_actions(subject_id: String) -> Array[Dictionary]:
	var normalized_subject := subject_id.strip_edges()
	if normalized_subject.is_empty():
		return []
	var subject_prefix := "%s|" % normalized_subject
	var candidates: Array[Dictionary] = []
	for binding_key_value in m_subject_binding_index.keys():
		var binding_key := String(binding_key_value)
		if !binding_key.begins_with(subject_prefix):
			continue
		var raw_candidates = m_subject_binding_index[binding_key_value]
		if !(raw_candidates is Array):
			continue
		for candidate_value in raw_candidates:
			if candidate_value is Dictionary:
				candidates.append((candidate_value as Dictionary).duplicate(true))
	return candidates


func _pick_subject_binding_for_metadata(subject_id: String, action: String, context: Dictionary) -> Dictionary:
	if !action.is_empty():
		return _pick_subject_binding_from_candidates(_get_subject_binding_candidates(subject_id, action), context)
	return _pick_subject_binding_from_candidates(_get_subject_binding_candidates_for_all_actions(subject_id), context)


func _get_world_event_binding_candidates(event_id: String) -> Array[Dictionary]:
	var binding_key := _world_event_binding_key(event_id)
	if !m_world_event_binding_index.has(binding_key):
		return []
	var candidates: Array[Dictionary] = []
	var raw_candidates = m_world_event_binding_index[binding_key]
	if raw_candidates is Array:
		for candidate_value in raw_candidates:
			if candidate_value is Dictionary:
				candidates.append((candidate_value as Dictionary).duplicate(true))
	return candidates


func _world_event_binding_key(event_id: String) -> String:
	return event_id.strip_edges()


func _display_verb_for_action(action: String) -> String:
	match action:
		"perform":
			return "Perform"
		"collect":
			return "Collect"
		"inspect":
			return "Inspect"
		"talk":
			return "Talk to"
		_:
			return action.capitalize()


func _matches_expected_value(current_value: Variant, expected_value: Variant) -> bool:
	if expected_value is Array or expected_value is PackedStringArray:
		var allowed_values: Array[String] = m_owner._normalize_string_array(expected_value)
		return allowed_values.find(String(current_value)) >= 0
	return current_value == expected_value


func _progress_value_count(value: Variant) -> int:
	if value is Array or value is PackedStringArray:
		return m_owner._normalize_string_array(value).size()
	if value is Dictionary:
		return (value as Dictionary).size()
	if value == null:
		return 0
	return int(value)


func _apply_melody_progress_patch(progress_patch: Dictionary) -> void:
	var next_progress: Dictionary = m_owner.melody_progress.duplicate(true)
	for melody_id_value in progress_patch.keys():
		var melody_id := String(melody_id_value)
		var patch_value = progress_patch[melody_id_value]
		if !(patch_value is Dictionary):
			continue
		var current_state: Dictionary = m_owner.get_melody_state(melody_id).duplicate(true)
		current_state.merge(patch_value, true)
		next_progress[melody_id] = current_state
	m_owner.set_melody_progress(next_progress)


func _apply_melody_source_award(award: Dictionary) -> void:
	var melody_id := String(award.get("melody_id", "festival_melody")).strip_edges()
	if melody_id.is_empty():
		return

	var source_id := String(award.get("source_id", "")).strip_edges()
	if source_id.is_empty():
		return

	var counts_as_fragment := bool(award.get("counts_as_fragment", true))
	var next_progress: Dictionary = m_owner.melody_progress.duplicate(true)
	var previous_melody: Dictionary = m_owner.get_melody_state(melody_id).duplicate(true)
	var melody_state: Dictionary = previous_melody.duplicate(true)
	var known_sources: Array[String] = m_owner._normalize_string_array(melody_state.get("known_sources", []))
	var is_new_source: bool = known_sources.find(source_id) < 0
	if is_new_source:
		known_sources.append(source_id)
	melody_state["known_sources"] = known_sources

	if counts_as_fragment and is_new_source:
		var fragments_total := int(melody_state.get("fragments_total", m_owner.fragments_total))
		melody_state["fragments_found"] = mini(int(melody_state.get("fragments_found", 0)) + 1, fragments_total)

	if award.has("next_lead"):
		melody_state["next_lead"] = String(award.get("next_lead", ""))

	if bool(award.get("sync_state_from_fragments", true)):
		_sync_melody_state_from_fragments(melody_state)

	next_progress[melody_id] = melody_state
	m_owner.set_melody_progress(next_progress)

	if !is_new_source or !counts_as_fragment:
		return

	var new_count := int(melody_state.get("fragments_found", 0))
	m_owner._emit_story_milestone("fragment_restored", {
		"melody_id": melody_id,
		"source_id": source_id,
		"total_found": new_count,
	})

	if new_count >= int(melody_state.get("fragments_total", m_owner.fragments_total)):
		m_owner._emit_story_milestone("festival_ready", {
			"fragments_found": new_count,
			"helped_residents": m_owner._count_helped_residents(),
		})


func _sync_melody_state_from_fragments(melody_state: Dictionary) -> void:
	var found := int(melody_state.get("fragments_found", 0))
	var performed := bool(melody_state.get("performed", false))
	var known_sources: Array[String] = m_owner._normalize_string_array(melody_state.get("known_sources", []))
	if performed:
		melody_state["state"] = "performed"
		melody_state["performed"] = true
	elif found >= 2:
		melody_state["state"] = "reconstructed"
		melody_state["performed"] = bool(melody_state.get("performed", false))
	elif found >= 1 or !known_sources.is_empty():
		melody_state["state"] = "heard"
		melody_state["performed"] = bool(melody_state.get("performed", false))
	else:
		melody_state["state"] = "unknown"
		melody_state["performed"] = bool(melody_state.get("performed", false))


func _sync_festival_stage_availability(notify_player: bool = false) -> void:
	if m_owner.mode != "Story":
		return

	var stage_state := String(m_owner.get_landmark_state("festival_stage"))
	if stage_state == "reward_collected":
		return

	var melody_ready := bool(m_owner.get_story_flag("melody_bagua_aligned", false))
	var spring_ready := bool(m_owner.get_story_flag("spring_festival_resolved", false))
	if melody_ready and spring_ready:
		if stage_state != "available":
			m_owner.advance_landmark_state("festival_stage", "available")
		var next_progress: Dictionary = m_owner.melody_progress.duplicate(true)
		var melody_state: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
		melody_state["next_lead"] = "Return to the ferry plaza and perform the restored melody at the festival stage."
		next_progress["festival_melody"] = melody_state
		m_owner.set_melody_progress(next_progress)
		if notify_player:
			m_owner.set_objective("Return to Piano Ferry and perform the restored melody at the festival stage.")
			m_owner.set_save_status("Spring Festival is ready — the harbor stage can finally answer the restored melody.")
		return

	if stage_state == "available":
		m_owner.advance_landmark_state("festival_stage", "locked")


func _merge_context(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	merged.merge(extra, true)
	return merged


func _format_context_text(text: String, context: Dictionary) -> String:
	var formatted := text
	for key_value in context.keys():
		var key := String(key_value)
		var placeholder := "{%s}" % key
		if formatted.contains(placeholder):
			formatted = formatted.replace(placeholder, String(context[key_value]))
	return formatted


func _deep_format_strings(value: Variant, context: Dictionary) -> Variant:
	if value is String:
		return _format_context_text(String(value), context)
	if value is Dictionary:
		var formatted_dictionary := {}
		for key in value.keys():
			formatted_dictionary[key] = _deep_format_strings(value[key], context)
		return formatted_dictionary
	if value is Array:
		var formatted_array: Array = []
		for element in value:
			formatted_array.append(_deep_format_strings(element, context))
		return formatted_array
	return value
