class_name StoryRouteGraph
extends RefCounted

const MAX_GLOBAL_LEADS := 4

var m_owner: Node = null


func _init(owner: Node) -> void:
	m_owner = owner


static func build_route_definitions() -> Dictionary:
	return {
		"family_memory": {
			"id": "family_memory",
			"display_name": "Family and Memory",
			"pin_priority": 110,
			"journal_section": "Family",
		},
		"study_future": {
			"id": "study_future",
			"display_name": "Study and Future",
			"pin_priority": 100,
			"journal_section": "Future",
		},
		"preservation_inheritance": {
			"id": "preservation_inheritance",
			"display_name": "Preservation and Inheritance",
			"pin_priority": 90,
			"journal_section": "Preservation",
		},
		"melody_landmarks": {
			"id": "melody_landmarks",
			"display_name": "Island Melody",
			"pin_priority": 80,
			"journal_section": "Landmarks",
		},
	}


static func build_event_definitions() -> Dictionary:
	return {
		"summer_return_complete": {
			"id": "summer_return_complete",
			"route_id": "family_memory",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {},
			"lead_text": "Return to Caretaker Lian and let the harbor become a real homecoming.",
			"journal_note": "The harbor feels familiar, but not easy. Home is close enough to recognize and still hard to hear clearly.",
			"pin_priority": 115,
			"completion_score": 1,
			"status_text": "The harbor return now belongs to this year instead of the last one.",
		},
		"trinity_memory_awakened": {
			"id": "trinity_memory_awakened",
			"route_id": "family_memory",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival"],
			"prerequisites": {
				"story_flags_all": ["summer_return_complete"],
			},
			"lead_text": "Visit Trinity Church and let one clear memory of Grandma return.",
			"journal_note": "Church memory, guilt, and grace are beginning to sound like part of the same story.",
			"pin_priority": 108,
			"completion_score": 1,
			"status_text": "A church-linked memory of Grandma has started to return clearly.",
		},
		"winter_memory_reveal": {
			"id": "winter_memory_reveal",
			"route_id": "family_memory",
			"phase_window": ["autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["trinity_memory_awakened", "autumn_pressure_named"],
			},
			"lead_text": "Return to Trinity Church once the pressure settles in and face the memory you kept avoiding.",
			"journal_note": "The year has grown colder, and the memory that once stayed blurred is becoming harder to outrun.",
			"pin_priority": 112,
			"completion_score": 1,
			"season_phase": "winter",
			"status_text": "Winter has turned the memory inward and unmistakable.",
		},
		"spring_festival_resolved": {
			"id": "spring_festival_resolved",
			"route_id": "family_memory",
			"phase_window": ["winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["winter_memory_reveal", "preservation_inheritance_seen"],
			},
			"lead_text": "Go back to the harbor and speak with Lian about the first Spring Festival without Grandma.",
			"journal_note": "The family story, the season, and the island's older memory are finally leaning into the same difficult holiday.",
			"pin_priority": 120,
			"completion_score": 2,
			"season_phase": "spring_festival",
			"status_text": "The first Spring Festival without Grandma has become the emotional center of the year.",
		},
		"autumn_pressure_named": {
			"id": "autumn_pressure_named",
			"route_id": "study_future",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["summer_return_complete"],
			},
			"lead_text": "Speak with Dock Musician Pei about how the future already feels too loud.",
			"journal_note": "The exam and everything after it are no longer background pressure. They have started naming themselves openly.",
			"pin_priority": 105,
			"completion_score": 1,
			"season_phase": "autumn_study",
			"status_text": "Autumn study pressure has become explicit instead of quietly implied.",
		},
		"future_commitment_choice": {
			"id": "future_commitment_choice",
			"route_id": "study_future",
			"phase_window": ["spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["spring_festival_resolved"],
			},
			"lead_text": "Return to Pei and name at least one future that belongs to you honestly.",
			"journal_note": "The real question is no longer what sounds impressive. It is which future still sounds true when the room gets quiet.",
			"pin_priority": 104,
			"completion_score": 1,
			"status_text": "The future no longer sounds like one forced answer. Honesty has entered the choice.",
		},
		"future_commitment_end": {
			"id": "future_commitment_end",
			"route_id": "study_future",
			"phase_window": ["spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["future_commitment_choice"],
			},
			"lead_text": "If this feels like the true turning point, speak with Ticket Clerk Min and let the story close at the harbor.",
			"journal_note": "An honest commitment can itself become an ending, even before every formal milestone has arrived.",
			"pin_priority": 99,
			"completion_score": 1,
			"endgame_trigger": "future_commitment_choice",
			"closing_label": "The harbor no longer asks for certainty. It only asks whether the future you carry is finally your own.",
			"tone_tags": ["honesty", "turning_point", "harbor"],
			"status_text": "The harbor has turned into a place where an honest future can become its own ending.",
		},
		"summer_exam_complete": {
			"id": "summer_exam_complete",
			"route_id": "study_future",
			"phase_window": ["spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["future_commitment_choice"],
			},
			"lead_text": "Stay with Pei until the exam season breaks open into second summer.",
			"journal_note": "The exam finally passes, and the question stops being what everyone wanted from you and becomes what still remains after the pressure goes quiet.",
			"pin_priority": 118,
			"completion_score": 2,
			"season_phase": "summer_2",
			"endgame_trigger": "exam_completed",
			"closing_label": "The exam is over. Second summer arrives without certainty, but with a more honest self standing inside it.",
			"tone_tags": ["release", "second_summer", "honesty"],
			"status_text": "The exam season has passed, and the year has opened into a second summer.",
		},
		"preservation_inheritance_seen": {
			"id": "preservation_inheritance_seen",
			"route_id": "preservation_inheritance",
			"phase_window": ["autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["autumn_pressure_named"],
			},
			"lead_text": "Climb toward Bagua Tower and speak with Terrace Painter Nian about what the island keeps in view.",
			"journal_note": "The old buildings have stopped feeling decorative. They now feel like memory made visible and waiting for someone to care for it.",
			"pin_priority": 96,
			"completion_score": 2,
			"status_text": "The island's old buildings now read as inheritance rather than background.",
		},
		"melody_ferry_settled": {
			"id": "melody_ferry_settled",
			"route_id": "melody_landmarks",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {},
			"lead_text": "Listen to the harbor refrain and carry it uphill into the island.",
			"journal_note": "The harbor has offered the first steady pulse. The rest of the island still has to answer it.",
			"pin_priority": 82,
			"completion_score": 1,
			"status_text": "The harbor refrain has settled into the melody route.",
		},
		"melody_church_restored": {
			"id": "melody_church_restored",
			"route_id": "melody_landmarks",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["melody_ferry_settled"],
			},
			"lead_text": "Settle Trinity Church so the bells can answer the harbor clearly.",
			"journal_note": "The church route is the first full phrase the island gives back.",
			"pin_priority": 85,
			"completion_score": 1,
			"status_text": "Trinity Church has returned one full phrase to the island.",
		},
		"melody_bi_shan_restored": {
			"id": "melody_bi_shan_restored",
			"route_id": "melody_landmarks",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["melody_church_restored"],
			},
			"lead_text": "Trace the steadier echo through Bi Shan Tunnel.",
			"journal_note": "Bi Shan turns a hidden route back into something dependable and shared.",
			"pin_priority": 83,
			"completion_score": 1,
			"status_text": "Bi Shan Tunnel has answered with a steadier route.",
		},
		"melody_long_shan_restored": {
			"id": "melody_long_shan_restored",
			"route_id": "melody_landmarks",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["melody_church_restored"],
			},
			"lead_text": "Walk the Long Shan route patiently enough for someone else to trust it.",
			"journal_note": "Long Shan turns route-finding into companionship instead of simple navigation.",
			"pin_priority": 83,
			"completion_score": 1,
			"status_text": "Long Shan Tunnel has become a route someone else can believe in.",
		},
		"melody_bagua_aligned": {
			"id": "melody_bagua_aligned",
			"route_id": "melody_landmarks",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["melody_bi_shan_restored", "melody_long_shan_restored"],
			},
			"lead_text": "Carry the steady routes to Bagua Tower and align the island from above.",
			"journal_note": "The tower turns separate errands into one visible route across the island.",
			"pin_priority": 86,
			"completion_score": 1,
			"status_text": "Bagua Tower has aligned the melody route into one island-scale line.",
		},
		"harbor_festival_performed": {
			"id": "harbor_festival_performed",
			"route_id": "melody_landmarks",
			"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
			"prerequisites": {
				"story_flags_all": ["melody_bagua_aligned"],
			},
			"lead_text": "Return the restored melody to the harbor stage and see what the island remembers in public.",
			"journal_note": "The island's music has been restored in public, even if the rest of the year is not finished yet.",
			"pin_priority": 98,
			"completion_score": 2,
			"endgame_trigger": "harbor_festival_performed",
			"closing_label": "The restored harbor performance is no longer only a festival. It has become the public shape of everything the island remembers.",
			"tone_tags": ["music", "community", "public_memory"],
			"status_text": "The harbor has performed the restored melody back into the island.",
		},
	}


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
	}


static func phase_display_name(phase_id: String) -> String:
	match phase_id:
		"summer_1":
			return "Summer"
		"autumn_study":
			return "Autumn / Study"
		"winter":
			return "Winter"
		"spring_festival":
			return "Spring Festival / Spring"
		"summer_2":
			return "Second Summer"
		"endgame":
			return "Final Act"
		"postgame":
			return "Afterword"
		_:
			return "Story"


func build_story_state(state_id: String) -> Dictionary:
	var flags := build_default_story_flags()
	var phase := "summer_1"
	var endgame := default_endgame_state()
	match state_id:
		"postgame":
			phase = "postgame"
			for event_id in flags.keys():
				flags[event_id] = true
			endgame = {
				"active": false,
				"trigger_event_id": "harbor_festival_performed",
				"closing_label": "The harbor has gone quiet again, but it no longer sounds empty.",
				"ending_tone_tags": PackedStringArray(["music", "inheritance", "afterglow"]),
			}
		"free_walk":
			phase = "summer_1"

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
	return normalized


func get_route_definition(route_id: String) -> Dictionary:
	return build_route_definitions().get(route_id, {}).duplicate(true)


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

	for route_id in route_definitions.keys():
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
	for route_id in build_route_definitions().keys():
		var route_definition: Dictionary = get_route_definition(route_id)
		var progress: Dictionary = m_owner.route_progress.get(route_id, {})
		parts.append("%s %d" % [
			String(route_definition.get("display_name", route_id)),
			int(progress.get("completion_score", 0)),
		])
	return ", ".join(PackedStringArray(parts))


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

	for route_id in route_definitions.keys():
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
		var endgame_state := {
			"active": true,
			"trigger_event_id": event_id,
			"closing_label": String(definition.get("closing_label", "Take a quiet moment before choosing what comes next.")),
			"ending_tone_tags": _build_tone_tags(definition),
		}
		m_owner.set_endgame_state(endgame_state)
		m_owner.set_season_phase("endgame")
		m_owner._emit_story_milestone("endgame_started", {
			"trigger_event_id": event_id,
			"trigger_id": trigger_id,
			"closing_label": String(endgame_state.get("closing_label", "")),
		})
		return


func _build_tone_tags(event_definition: Dictionary, ending_choice: String = "") -> PackedStringArray:
	var tags := PackedStringArray(_normalize_string_array(event_definition.get("tone_tags", [])))
	var family_score := int(m_owner.route_progress.get("family_memory", {}).get("completion_score", 0))
	var study_score := int(m_owner.route_progress.get("study_future", {}).get("completion_score", 0))
	var preservation_score := int(m_owner.route_progress.get("preservation_inheritance", {}).get("completion_score", 0))
	var melody_score := int(m_owner.route_progress.get("melody_landmarks", {}).get("completion_score", 0))
	var helped_residents := int(m_owner._count_helped_residents())
	var max_trust_residents := _count_max_trust_residents()

	if family_score >= 3 and tags.find("grace") < 0:
		tags.append("grace")
	if study_score >= 2 and tags.find("future") < 0:
		tags.append("future")
	if preservation_score >= 2 and tags.find("inheritance") < 0:
		tags.append("inheritance")
	if melody_score >= 4 and tags.find("belonging") < 0:
		tags.append("belonging")
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


static func _sort_lead_candidates(a: Dictionary, b: Dictionary) -> bool:
	var priority_a := int(a.get("priority", 0))
	var priority_b := int(b.get("priority", 0))
	if priority_a != priority_b:
		return priority_a > priority_b
	return String(a.get("event_id", "")) < String(b.get("event_id", ""))


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
