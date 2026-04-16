class_name ResidentInteractionService
extends RefCounted

var m_owner: Node = null


func _init(owner: Node) -> void:
	m_owner = owner


func interact_with_resident(resident_id: String) -> Dictionary:
	m_owner._ensure_resident_profiles()
	if !m_owner.resident_profiles.has(resident_id):
		return {}

	var resident: Dictionary = m_owner.resident_profiles[resident_id].duplicate(true)
	var dialogue_beats: Array = resident.get("dialogue_beats", [])
	var resident_was_known := bool(resident.get("known", false))

	resident["known"] = true

	var conditional_beat := _pick_conditional_beat(resident_id, resident)
	if !conditional_beat.is_empty():
		var fired: Array = m_owner._normalize_string_array(resident.get("_fired_conditional_beats", []))
		var beat_key := String(conditional_beat.get("_beat_key", ""))
		var is_new_conditional := !beat_key.is_empty() and fired.find(beat_key) < 0
		if is_new_conditional:
			fired.append(beat_key)
			resident["_fired_conditional_beats"] = fired

		var old_cond_trust := int(resident.get("trust", 0))
		resident["trust"] = clampi(
			old_cond_trust + int(conditional_beat.get("trust_delta", 0)),
			0,
			m_owner.RESIDENT_CATALOG_SCRIPT.max_trust()
		)
		var cond_journal := String(conditional_beat.get("journal_step", ""))
		if !cond_journal.is_empty():
			resident["current_step"] = cond_journal

		m_owner.resident_profiles[resident_id] = resident
		_sync_known_residents()
		if is_new_conditional:
			_apply_resident_beat(conditional_beat, resident_id)
			_emit_trust_milestone_if_max(resident_id, old_cond_trust, int(resident.get("trust", 0)))
			m_owner._autosave_story_progress()
		elif !resident_was_known:
			m_owner._autosave_story_progress()
		m_owner._refresh_player_costumes()
		m_owner.resident_profile_changed.emit(resident_id, m_owner.get_resident_profile(resident_id))
		var result := conditional_beat.duplicate(true)
		result.erase("_beat_key")
		return result

	if dialogue_beats.is_empty():
		m_owner.resident_profiles[resident_id] = resident
		_sync_known_residents()
		if !resident_was_known:
			m_owner._autosave_story_progress()
		m_owner._refresh_player_costumes()
		m_owner.resident_profile_changed.emit(resident_id, m_owner.get_resident_profile(resident_id))
		return {}

	var beat_index := clampi(
		int(resident.get("conversation_index", 0)),
		0,
		dialogue_beats.size() - 1
	)
	var beat: Dictionary = dialogue_beats[beat_index]

	if !_check_beat_gate(beat):
		m_owner.resident_profiles[resident_id] = resident
		_sync_known_residents()
		if !resident_was_known:
			m_owner._autosave_story_progress()
		m_owner._refresh_player_costumes()
		m_owner.resident_profile_changed.emit(resident_id, m_owner.get_resident_profile(resident_id))
		var fallback := String(beat.get("gate_fallback", ""))
		return {"line": fallback}

	var is_new_beat := beat_index < dialogue_beats.size() - 1 \
		or int(resident.get("_last_applied_beat", -1)) != beat_index

	var old_trust := int(resident.get("trust", 0))
	resident["trust"] = clampi(
		old_trust + int(beat.get("trust_delta", 0)),
		0,
		m_owner.RESIDENT_CATALOG_SCRIPT.max_trust()
	)
	resident["quest_state"] = String(beat.get("quest_state", resident.get("quest_state", "available")))
	resident["current_step"] = String(beat.get("journal_step", beat.get("objective", "Stay in touch.")))

	if beat_index < dialogue_beats.size() - 1:
		resident["conversation_index"] = beat_index + 1

	resident["_last_applied_beat"] = beat_index

	m_owner.resident_profiles[resident_id] = resident
	_sync_known_residents()
	if is_new_beat:
		_apply_resident_beat(beat, resident_id)
		m_owner._autosave_story_progress()
	elif !resident_was_known:
		m_owner._autosave_story_progress()
	_emit_trust_milestone_if_max(resident_id, old_trust, int(resident.get("trust", 0)))
	m_owner._refresh_player_costumes()
	m_owner.resident_profile_changed.emit(resident_id, m_owner.get_resident_profile(resident_id))
	return beat.duplicate(true)


func get_known_resident_names() -> PackedStringArray:
	m_owner._ensure_resident_profiles()
	var names := PackedStringArray()
	for resident_id in m_owner.RESIDENT_CATALOG_SCRIPT.resident_order():
		var resident: Dictionary = m_owner.resident_profiles.get(resident_id, {})
		if resident.get("known", false):
			names.append(String(resident.get("display_name", resident_id)))
	return names


func get_resident_ambient_line(resident_id: String) -> String:
	m_owner._ensure_resident_profiles()
	var resident: Dictionary = m_owner.resident_profiles.get(resident_id, {})
	if resident.is_empty():
		return ""

	var ambient_lines: Array = resident.get("ambient_lines", [])
	if ambient_lines.is_empty():
		return ""

	var conversation_index := clampi(
		int(resident.get("conversation_index", 0)),
		0,
		ambient_lines.size() - 1
	)
	return String(ambient_lines[conversation_index])


func _apply_resident_beat(beat: Dictionary, resident_id: String = "") -> void:
	m_owner.apply_story_effects(beat, {
		"subject_id": "npc:%s" % resident_id,
		"action": "talk",
		"resident_id": resident_id,
	})


func _sync_known_residents() -> void:
	m_owner.set_residents(get_known_resident_names())
	m_owner._update_summary_counts()


func _seed_resident_progress(
	resident_id: String,
	conversation_index: int,
	trust: int,
	quest_state: String,
	current_step: String
) -> void:
	if !m_owner.resident_profiles.has(resident_id):
		return

	var resident: Dictionary = m_owner.resident_profiles[resident_id].duplicate(true)
	var dialogue_beats: Array = resident.get("dialogue_beats", [])

	resident["known"] = true
	resident["trust"] = clampi(trust, 0, m_owner.RESIDENT_CATALOG_SCRIPT.max_trust())
	resident["quest_state"] = quest_state
	resident["current_step"] = current_step

	if dialogue_beats.is_empty():
		resident["conversation_index"] = 0
	else:
		resident["conversation_index"] = clampi(conversation_index, 0, dialogue_beats.size() - 1)

	m_owner.resident_profiles[resident_id] = resident
	_sync_known_residents()
	m_owner._refresh_player_costumes()
	m_owner.resident_profile_changed.emit(resident_id, m_owner.get_resident_profile(resident_id))


func _count_helped_residents() -> int:
	m_owner._ensure_resident_profiles()
	var count := 0
	for resident_id in m_owner.RESIDENT_CATALOG_SCRIPT.resident_order():
		var resident: Dictionary = m_owner.resident_profiles.get(resident_id, {})
		if int(resident.get("trust", 0)) > 0:
			count += 1
	return count


func _check_beat_gate(beat: Dictionary) -> bool:
	var gate := String(beat.get("gate", ""))
	if gate.is_empty():
		return true
	match gate:
		"piano_ferry_harbor_clue":
			var ferry_progress: Dictionary = m_owner.get_landmark_progress("piano_ferry")
			return bool(ferry_progress.get("harbor_clue_found", false))
		"first_fragment_restored":
			return m_owner.fragments_found >= 1
		"trinity_church_cues":
			var trinity_progress: Dictionary = m_owner.get_landmark_progress("trinity_church")
			var cues: Array = trinity_progress.get("cues_collected", [])
			return cues.size() >= 3
		"trinity_church_chime":
			var trinity_resolved_progress: Dictionary = m_owner.get_landmark_progress("trinity_church")
			return bool(trinity_resolved_progress.get("chime_performed", false))
		"long_shan_exit_reached":
			return m_owner.get_landmark_state("long_shan_tunnel") == "reward_collected"
		"bagua_synthesis_done":
			var tower_progress: Dictionary = m_owner.get_landmark_progress("bagua_tower")
			return bool(tower_progress.get("synthesis_done", false))
		"bagua_tower_available":
			return m_owner.get_landmark_state("bagua_tower") != "locked"
		"three_fragments_restored":
			return m_owner.fragments_found >= 3
		"future_choice_ready":
			return bool(m_owner.get_story_flag("spring_festival_resolved", false)) \
				and bool(m_owner.get_story_flag("autumn_pressure_shared", false))
		"preservation_tower_ready":
			return bool(m_owner.get_story_flag("preservation_inheritance_seen", false)) \
				and m_owner.get_landmark_state("bagua_tower") != "locked"
		_:
			if m_owner.story_flags.has(gate):
				return bool(m_owner.story_flags.get(gate, false))
	return true


func _pick_conditional_beat(_resident_id: String, resident: Dictionary) -> Dictionary:
	var conditional_beats: Array = resident.get("conditional_beats", [])
	if conditional_beats.is_empty():
		return {}

	var fired: Array[String] = m_owner._normalize_string_array(resident.get("_fired_conditional_beats", []))
	var available_beats: Array = []

	for i in conditional_beats.size():
		var conditional_beat: Dictionary = conditional_beats[i]
		var beat_key := "cond_%d" % i

		if bool(conditional_beat.get("once", false)) and fired.find(beat_key) >= 0:
			continue

		var candidate := conditional_beat.duplicate(true)
		candidate["_beat_key"] = beat_key
		available_beats.append(candidate)

	return m_owner.pick_story_candidate(available_beats, {
		"subject_id": "npc:%s" % _resident_id,
		"action": "talk",
		"resident_id": _resident_id,
		"resident": resident,
	})


func _check_conditional_conditions(conditions: Dictionary, resident: Dictionary) -> bool:
	return m_owner.matches_story_conditions(conditions, {"resident": resident})


func _emit_trust_milestone_if_max(resident_id: String, old_trust: int, new_trust: int) -> void:
	if new_trust >= m_owner.RESIDENT_CATALOG_SCRIPT.max_trust() \
	and old_trust < m_owner.RESIDENT_CATALOG_SCRIPT.max_trust():
		m_owner._emit_story_milestone("resident_trust_max", {"resident_id": resident_id})
