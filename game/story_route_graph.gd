class_name StoryRouteGraph
extends RefCounted

const MAX_GLOBAL_LEADS := 4
const STORY_SEASON_PHASES_SCRIPT := preload("res://game/story_season_phases.gd")

var m_owner: Node = null


func _init(owner: Node) -> void:
	m_owner = owner


static func route_display_order() -> Array[String]:
	return StorylineCatalog.route_display_order()


static func build_route_definitions() -> Dictionary:
	return StorylineCatalog.build_route_definitions()


static func build_event_definitions() -> Dictionary:
	return StorylineCatalog.build_event_definitions()


static func build_default_story_flags() -> Dictionary:
	var flags: Dictionary = {}
	for event_id in build_event_definitions().keys():
		flags[event_id] = false
	return flags


static func default_endgame_state() -> Dictionary:
	return {
		"active": false,
		"trigger_event_id": "",
		"closing_label": "",
		"ending_tone_tags": [],
		"ending_behavior": "",
		"resume_phase_id": "",
	}


static func phase_display_name(phase_id: String) -> String:
	return STORY_SEASON_PHASES_SCRIPT.display_name(phase_id)


func build_story_state(state_id: String) -> Dictionary:
	var flags := build_default_story_flags()
	var phase := STORY_SEASON_PHASES_SCRIPT.DEFAULT_PHASE
	var endgame := default_endgame_state()
	match state_id:
		"free_walk":
			phase = STORY_SEASON_PHASES_SCRIPT.DEFAULT_PHASE

	var route_state := _compute_route_snapshot(flags, phase, endgame, "")
	return {
		"season_phase": phase,
		"story_flags": flags,
		"route_progress": route_state.get("route_progress", {}).duplicate(true),
		"available_lead_ids": route_state.get("available_lead_ids", PackedStringArray()),
		"active_lead_id": String(route_state.get("active_lead_id", "")),
		"endgame_state": endgame.duplicate(true),
		"manual_pinned_lead_id": "",
	}


func normalize_story_flags(flags_value: Variant) -> Dictionary:
	var normalized := build_default_story_flags()
	if flags_value is Dictionary:
		var incoming_flags: Dictionary = flags_value as Dictionary
		for flag_id in incoming_flags.keys():
			var normalized_flag_id := String(flag_id)
			if normalized.has(normalized_flag_id):
				normalized[normalized_flag_id] = bool(incoming_flags.get(flag_id, false))
			else:
				normalized[normalized_flag_id] = incoming_flags.get(flag_id)
	return normalized


func normalize_endgame_state(value: Variant) -> Dictionary:
	var normalized := default_endgame_state()
	if value is Dictionary:
		normalized.merge((value as Dictionary), true)
	normalized["active"] = bool(normalized.get("active", false))
	normalized["trigger_event_id"] = String(normalized.get("trigger_event_id", ""))
	normalized["closing_label"] = String(normalized.get("closing_label", ""))
	normalized["ending_tone_tags"] = _normalize_string_array(normalized.get("ending_tone_tags", []))
	normalized["ending_behavior"] = String(normalized.get("ending_behavior", ""))
	normalized["resume_phase_id"] = String(normalized.get("resume_phase_id", ""))
	return normalized


func get_route_definition(route_id: String) -> Dictionary:
	return build_route_definitions().get(route_id, {}).duplicate(true)


func get_route_ids() -> PackedStringArray:
	return PackedStringArray(route_display_order())


func get_event_definition(event_id: String) -> Dictionary:
	return build_event_definitions().get(event_id, {}).duplicate(true)


func get_active_lead_text() -> String:
	if bool(m_owner.endgame_state.get("active", false)):
		return String(m_owner.endgame_state.get("closing_label", "Take a quiet moment before choosing what comes next."))

	var lead_id := String(m_owner.active_lead_id)
	if lead_id.is_empty():
		return ""

	var lead_definition := get_event_definition(lead_id)
	if lead_definition.is_empty():
		return ""
	return String(lead_definition.get("lead_text", ""))


func get_route_summary_lines() -> Array[String]:
	var lines: Array[String] = []
	var route_definitions: Dictionary = build_route_definitions()

	for route_id in route_display_order():
		var progress: Dictionary = m_owner.route_progress.get(route_id, {})
		if progress.is_empty():
			continue

		var next_lead_id := String(progress.get("next_lead_id", ""))
		var next_lead_text := "No open lead."
		if !next_lead_id.is_empty():
			next_lead_text = String(get_event_definition(next_lead_id).get("lead_text", "No open lead."))

		lines.append(
			"%s\nState: %s\nCompletion: %d\nNext lead: %s" % [
				String(route_definitions[route_id].get("display_name", route_id)),
				String(progress.get("state", "idle")),
				int(progress.get("completion_score", 0)),
				next_lead_text,
			]
		)

	return lines


func refresh_story_state() -> void:
	var snapshot := _compute_route_snapshot(
		normalize_story_flags(m_owner.story_flags),
		String(m_owner.season_phase),
		normalize_endgame_state(m_owner.endgame_state),
		String(m_owner._manual_pinned_lead_id)
	)
	m_owner.set_all_route_progress(snapshot.get("route_progress", {}))
	m_owner.set_active_leads(
		String(snapshot.get("active_lead_id", "")),
		snapshot.get("available_lead_ids", PackedStringArray())
	)
	m_owner._update_summary_counts()


func resolve_story_event(event_id: String) -> bool:
	var event_definition := get_event_definition(event_id)
	if event_definition.is_empty():
		return false
	if bool(m_owner.story_flags.get(event_id, false)):
		return false

	m_owner.set_story_flag(event_id, true)

	var next_phase := String(event_definition.get("season_phase", ""))
	if !next_phase.is_empty():
		m_owner.set_season_phase(next_phase)

	var status_text := String(event_definition.get("status_text", ""))
	if !status_text.is_empty():
		m_owner.set_save_status(status_text)

	refresh_story_state()
	m_owner._emit_story_milestone("story_event_resolved", {
		"event_id": event_id,
		"route_id": String(event_definition.get("route_id", "")),
		"season_phase": String(m_owner.season_phase),
	})

	var endgame_trigger := String(event_definition.get("endgame_trigger", ""))
	if !endgame_trigger.is_empty():
		_maybe_start_endgame(event_id)
	elif event_id == "spring_festival_resolved":
		_maybe_start_endgame("")

	refresh_story_state()
	return true


func pin_story_lead(lead_id: String) -> void:
	var normalized_id := lead_id.strip_edges()
	var available_ids := _normalize_string_array(m_owner.available_lead_ids)
	if available_ids.find(normalized_id) < 0:
		return
	m_owner._manual_pinned_lead_id = normalized_id
	m_owner.set_active_leads(normalized_id, m_owner.available_lead_ids)


func cycle_story_lead(direction: int) -> void:
	var available_ids := _normalize_string_array(m_owner.available_lead_ids)
	if available_ids.is_empty():
		return

	var current_index := maxi(available_ids.find(String(m_owner.active_lead_id)), 0)
	var next_index := posmod(current_index + direction, available_ids.size())
	var next_id := String(available_ids[next_index])
	m_owner._manual_pinned_lead_id = next_id
	m_owner.set_active_leads(next_id, m_owner.available_lead_ids)


func clear_manual_pinned_lead() -> void:
	m_owner._manual_pinned_lead_id = ""
	refresh_story_state()


func build_route_completion_summary() -> String:
	var parts: Array[String] = []
	for route_id in route_display_order():
		var route_definition: Dictionary = get_route_definition(route_id)
		var progress: Dictionary = m_owner.route_progress.get(route_id, {})
		parts.append("%s %d" % [
			String(route_definition.get("display_name", route_id)),
			int(progress.get("completion_score", 0)),
		])
	return ", ".join(PackedStringArray(parts))


func build_route_emphasis_text() -> String:
	var ranked_routes := _build_route_mix_entries()
	if ranked_routes.is_empty():
		return "No route has taken the lead yet."

	var primary: Dictionary = ranked_routes[0]
	var primary_label := String(primary.get("display_name", "The year"))
	var primary_score := int(primary.get("score", 0))
	if primary_score <= 0:
		return "No route has taken the lead yet."

	if ranked_routes.size() == 1:
		return "%s carried most of the year." % primary_label

	var secondary: Dictionary = ranked_routes[1]
	var secondary_label := String(secondary.get("display_name", "the rest of the island"))
	var secondary_score := int(secondary.get("score", 0))
	if secondary_score <= 0:
		return "%s carried most of the year." % primary_label
	if primary_score == secondary_score:
		return "%s and %s kept the year in balance." % [primary_label, secondary_label]
	return "%s carried most of the year, with %s answering close behind." % [
		primary_label,
		secondary_label,
	]


func build_ending_tone_tags(ending_choice: String = "") -> PackedStringArray:
	var trigger_event_id := String(m_owner.endgame_state.get("trigger_event_id", ""))
	var event_definition := get_event_definition(trigger_event_id)
	return _build_tone_tags(event_definition, ending_choice)


func _compute_route_snapshot(
	flags: Dictionary,
	phase_id: String,
	endgame: Dictionary,
	manual_pinned_lead_id: String
) -> Dictionary:
	var route_definitions := build_route_definitions()
	var event_definitions := build_event_definitions()
	var route_progress: Dictionary = {}
	var global_candidates: Array[Dictionary] = []

	for route_id in route_display_order():
		var route_events: Array[String] = []
		var resolved_ids := PackedStringArray()
		var available_ids := PackedStringArray()
		var blocked_ids := PackedStringArray()
		var next_lead_id := ""
		var next_priority := -100000
		var completion_score := 0

		for event_id in event_definitions.keys():
			var event_definition: Dictionary = event_definitions[event_id]
			if String(event_definition.get("route_id", "")) != route_id:
				continue

			route_events.append(event_id)
			if bool(flags.get(event_id, false)):
				resolved_ids.append(event_id)
				completion_score += int(event_definition.get("completion_score", 1))
				continue

			if !_event_is_available(event_definition, flags, phase_id, route_progress):
				blocked_ids.append(event_id)
				continue

			available_ids.append(event_id)
			var candidate_priority := _event_priority(event_definition, route_definitions.get(route_id, {}))
			if candidate_priority > next_priority:
				next_priority = candidate_priority
				next_lead_id = event_id
			global_candidates.append({
				"event_id": event_id,
				"priority": candidate_priority,
				"route_id": route_id,
			})

		route_progress[route_id] = {
			"state": _route_state_label(resolved_ids, available_ids, route_events.size()),
			"available_beat_ids": available_ids,
			"resolved_beat_ids": resolved_ids,
			"blocked_beat_ids": blocked_ids,
			"next_lead_id": next_lead_id,
			"completion_score": completion_score,
		}

	var available_lead_ids := PackedStringArray()
	if m_owner.mode != "Story":
		return {
			"route_progress": route_progress,
			"available_lead_ids": available_lead_ids,
			"active_lead_id": "",
		}

	if bool(endgame.get("active", false)):
		var trigger_event_id := String(endgame.get("trigger_event_id", ""))
		if !trigger_event_id.is_empty():
			available_lead_ids.append(trigger_event_id)
		return {
			"route_progress": route_progress,
			"available_lead_ids": available_lead_ids,
			"active_lead_id": trigger_event_id,
		}

	global_candidates.sort_custom(_sort_lead_candidates)
	var route_seen := {}
	for candidate in global_candidates:
		var route_id := String(candidate.get("route_id", ""))
		if route_seen.has(route_id):
			continue
		route_seen[route_id] = true
		available_lead_ids.append(String(candidate.get("event_id", "")))
		if available_lead_ids.size() >= MAX_GLOBAL_LEADS:
			break

	var active_lead_id := ""
	if !manual_pinned_lead_id.is_empty() and available_lead_ids.find(manual_pinned_lead_id) >= 0:
		active_lead_id = manual_pinned_lead_id
	elif !available_lead_ids.is_empty():
		active_lead_id = String(available_lead_ids[0])

	return {
		"route_progress": route_progress,
		"available_lead_ids": available_lead_ids,
		"active_lead_id": active_lead_id,
	}


func _maybe_start_endgame(preferred_event_id: String) -> void:
	if bool(m_owner.endgame_state.get("active", false)):
		return
	if !bool(m_owner.story_flags.get("spring_festival_resolved", false)):
		return

	var candidate_ids: Array[String] = []
	if !preferred_event_id.is_empty():
		candidate_ids.append(preferred_event_id)
	for event_id in build_event_definitions().keys():
		if candidate_ids.find(event_id) >= 0:
			continue
		candidate_ids.append(event_id)

	for event_id in candidate_ids:
		if !bool(m_owner.story_flags.get(event_id, false)):
			continue
		var definition := get_event_definition(event_id)
		if definition.is_empty():
			continue
		var trigger_id := String(definition.get("endgame_trigger", ""))
		if trigger_id.is_empty():
			continue
		var ending_behavior := String(definition.get("ending_behavior", "end_run"))
		var endgame_state := {
			"active": true,
			"trigger_event_id": event_id,
			"closing_label": String(definition.get("closing_label", "Take a quiet moment before choosing what comes next.")),
			"ending_tone_tags": _build_tone_tags(definition),
			"ending_behavior": ending_behavior,
			"resume_phase_id": String(m_owner.season_phase),
		}
		m_owner.set_endgame_state(endgame_state)
		m_owner.set_season_phase(STORY_SEASON_PHASES_SCRIPT.ENDGAME)
		m_owner._emit_story_milestone("endgame_started", {
			"trigger_event_id": event_id,
			"trigger_id": trigger_id,
			"ending_behavior": ending_behavior,
			"closing_label": String(endgame_state.get("closing_label", "")),
		})
		return


func _build_tone_tags(event_definition: Dictionary, ending_choice: String = "") -> PackedStringArray:
	var tags := PackedStringArray(_normalize_string_array(event_definition.get("tone_tags", [])))
	var helped_residents := int(m_owner._count_helped_residents())
	var max_trust_residents := _count_max_trust_residents()
	var route_definitions := build_route_definitions()

	for route_id in route_display_order():
		var route_definition: Dictionary = route_definitions.get(route_id, {})
		var route_score := int(m_owner.route_progress.get(route_id, {}).get("completion_score", 0))
		for rule_value in route_definition.get("ending_tone_rules", []):
			if !(rule_value is Dictionary):
				continue
			var rule: Dictionary = rule_value
			if route_score < int(rule.get("min_score", 0)):
				continue
			if helped_residents < int(rule.get("helped_residents_min", 0)):
				continue
			if max_trust_residents < int(rule.get("max_trust_residents_min", 0)):
				continue
			var tag := String(rule.get("tag", ""))
			if !tag.is_empty() and tags.find(tag) < 0:
				tags.append(tag)
	if helped_residents >= 6 and tags.find("community") < 0:
		tags.append("community")
	if max_trust_residents >= 2 and tags.find("trust") < 0:
		tags.append("trust")
	match ending_choice.strip_edges().to_lower():
		"stay":
			if tags.find("lingering") < 0:
				tags.append("lingering")
		"leave":
			if tags.find("departure") < 0:
				tags.append("departure")
	return tags


func _count_max_trust_residents() -> int:
	var count := 0
	for resident_id in m_owner.get_resident_ids():
		var resident: Dictionary = m_owner.get_resident_profile(String(resident_id))
		if int(resident.get("trust", 0)) >= m_owner.RESIDENT_CATALOG_SCRIPT.max_trust():
			count += 1
	return count


func _event_is_available(
	event_definition: Dictionary,
	flags: Dictionary,
	phase_id: String,
	route_progress: Dictionary
) -> bool:
	var allowed_phases := _normalize_string_array(event_definition.get("phase_window", []))
	if !allowed_phases.is_empty() and allowed_phases.find(phase_id) < 0:
		return false

	var prerequisites: Dictionary = event_definition.get("prerequisites", {})
	for key in prerequisites.keys():
		match key:
			"story_flags_all":
				for flag_id_value in prerequisites[key]:
					if !bool(flags.get(String(flag_id_value), false)):
						return false
			"story_flags_any":
				var found := false
				for flag_id_value in prerequisites[key]:
					if bool(flags.get(String(flag_id_value), false)):
						found = true
						break
				if !found:
					return false
			"landmark_state":
				var required_landmarks: Dictionary = prerequisites[key]
				for landmark_id in required_landmarks.keys():
					if m_owner.get_landmark_state(String(landmark_id)) != String(required_landmarks[landmark_id]):
						return false
			"melody_state":
				var required_melodies: Dictionary = prerequisites[key]
				for melody_id in required_melodies.keys():
					var melody_state: Dictionary = m_owner.get_melody_state(String(melody_id))
					if String(melody_state.get("state", "unknown")) != String(required_melodies[melody_id]):
						return false
			"resident_known":
				for resident_id_value in prerequisites[key]:
					var resident: Dictionary = m_owner.get_resident_profile(String(resident_id_value))
					if !bool(resident.get("known", false)):
						return false
			"route_score_min":
				var required_routes: Dictionary = prerequisites[key]
				for route_id in required_routes.keys():
					var current_progress: Dictionary = route_progress.get(String(route_id), {})
					if int(current_progress.get("completion_score", 0)) < int(required_routes[route_id]):
						return false
	return true


func _event_priority(event_definition: Dictionary, route_definition: Dictionary) -> int:
	var event_priority := int(event_definition.get("pin_priority", -1))
	if event_priority >= 0:
		return event_priority
	return int(route_definition.get("pin_priority", 0))


func _route_state_label(
	resolved_ids: PackedStringArray,
	available_ids: PackedStringArray,
	total_events: int
) -> String:
	if total_events > 0 and resolved_ids.size() >= total_events:
		return "complete"
	if !available_ids.is_empty() and !resolved_ids.is_empty():
		return "active"
	if !available_ids.is_empty():
		return "available"
	if !resolved_ids.is_empty():
		return "waiting"
	return "idle"


func _build_route_mix_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var route_definitions := build_route_definitions()
	for route_id in route_display_order():
		var route_definition: Dictionary = route_definitions.get(route_id, {})
		var progress: Dictionary = m_owner.route_progress.get(route_id, {})
		var score := int(progress.get("completion_score", 0))
		if score <= 0:
			continue
		entries.append({
			"route_id": route_id,
			"display_name": String(route_definition.get("display_name", route_id)),
			"pin_priority": int(route_definition.get("pin_priority", 0)),
			"score": score,
		})

	entries.sort_custom(_sort_route_mix_entries)
	return entries


static func _sort_lead_candidates(a: Dictionary, b: Dictionary) -> bool:
	var priority_a := int(a.get("priority", 0))
	var priority_b := int(b.get("priority", 0))
	if priority_a != priority_b:
		return priority_a > priority_b
	return String(a.get("event_id", "")) < String(b.get("event_id", ""))


static func _sort_route_mix_entries(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", 0))
	var score_b := int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b

	var priority_a := int(a.get("pin_priority", 0))
	var priority_b := int(b.get("pin_priority", 0))
	if priority_a != priority_b:
		return priority_a > priority_b
	return String(a.get("route_id", "")) < String(b.get("route_id", ""))


static func _normalize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
		return output
	if value is Array:
		for entry in value:
			output.append(String(entry))
	return output
