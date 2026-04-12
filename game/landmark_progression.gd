class_name LandmarkProgression
extends RefCounted

var m_owner: Node = null


func _init(owner: Node) -> void:
	m_owner = owner


func activate_landmark_trigger(
	landmark_id: String,
	trigger_id: String,
	display_name: String,
	melody_hint: String = ""
) -> bool:
	match landmark_id:
		"piano_ferry":
			if trigger_id != "harbor_refrain":
				return false
			var ferry_progress: Dictionary = m_owner.get_landmark_progress("piano_ferry")
			if ferry_progress.is_empty() or bool(ferry_progress.get("harbor_clue_found", false)):
				return false
			_collect_piano_ferry_harbor_clue()
			if !melody_hint.is_empty():
				m_owner._emit_melody_hint_shown(melody_hint)
			m_owner._request_landmark_audio_cue("piano_ferry", landmark_id, trigger_id, display_name)
			m_owner.set_objective("Return to Caretaker Lian with the harbor refrain.")
			m_owner.set_hint(m_owner.build_input_hint("R Talk to Caretaker Lian"))
			m_owner.set_save_status("The harbor refrain is clearer now — return to Caretaker Lian.")
			m_owner._autosave_story_progress()
			return true
		"trinity_church":
			var church_progress: Dictionary = m_owner.get_landmark_progress("trinity_church")
			if church_progress.is_empty():
				return false
			if trigger_id == "choir_chime":
				if bool(church_progress.get("chime_performed", false)):
					return false
				var cue_count := _normalize_string_array(church_progress.get("cues_collected", [])).size()
				if cue_count < 3:
					m_owner.set_save_status("The church phrase needs all three choir cues before it can settle.")
					return false
				if !melody_hint.is_empty():
					m_owner._emit_melody_hint_shown(melody_hint)
				m_owner._request_landmark_audio_cue("trinity_church", landmark_id, trigger_id, display_name)
				request_trinity_chime_prompt()
				return false
			if _progress_has_string_entry(church_progress, "cues_collected", trigger_id):
				return false
			var all_collected := _collect_trinity_church_cue(trigger_id)
			var collected_progress: Dictionary = m_owner.get_landmark_progress("trinity_church")
			var collected_count := _normalize_string_array(
				collected_progress.get("cues_collected", [])
			).size()
			m_owner.set_save_status("Found: %s" % display_name)
			if !melody_hint.is_empty():
				m_owner._emit_melody_hint_shown(melody_hint)
			m_owner._request_landmark_audio_cue("trinity_church", landmark_id, trigger_id, display_name)
			if all_collected:
				m_owner._emit_melody_hint_shown("The three choir cues lean toward one church chime, but they still need to be settled together.")
				m_owner.set_objective("Settle the church phrase at the choir chime near the steps.")
				m_owner.set_hint(m_owner.build_input_hint("R Perform Choir Chime"))
				m_owner.set_save_status("All choir cues found — settle them at the choir chime.")
			elif collected_count == 1:
				m_owner.set_objective("Follow the next choir cue toward the side garden.")
			elif collected_count == 2:
				m_owner.set_objective("Find the last choir cue in the quiet yard.")
			m_owner._autosave_story_progress()
			return true
		"bi_shan_tunnel":
			var tunnel_progress: Dictionary = m_owner.get_landmark_progress("bi_shan_tunnel")
			if tunnel_progress.is_empty():
				return false
			if trigger_id == "chamber":
				var echoes := _normalize_string_array(tunnel_progress.get("echoes_collected", []))
				if echoes.size() >= 3:
					if !melody_hint.is_empty():
						m_owner._emit_melody_hint_shown(melody_hint)
					m_owner._request_landmark_audio_cue("bi_shan_tunnel", landmark_id, trigger_id, display_name)
					request_bi_shan_chamber_prompt()
					return false
				m_owner.set_save_status("The mural panel is silent. Trace the three tunnel echoes first.")
				return false
			if _progress_has_string_entry(tunnel_progress, "echoes_collected", trigger_id):
				return false
			var all_echoes := _collect_bi_shan_echo(trigger_id)
			m_owner.set_save_status("Heard: %s" % display_name)
			m_owner._request_landmark_audio_cue("bi_shan_tunnel", landmark_id, trigger_id, display_name)
			if all_echoes:
				m_owner.set_objective("Reach the mural chamber at the far end of Bi Shan Tunnel.")
				m_owner.set_hint("Follow the resonance to the chamber.   J Journal   Esc Pause")
				m_owner.set_save_status("All three echoes traced — follow the resonance to the chamber.")
			m_owner._autosave_story_progress()
			return true
		"long_shan_tunnel":
			match trigger_id:
				"tunnel_entry":
					if m_owner.get_landmark_state("long_shan_tunnel") == "available":
						m_owner.advance_landmark_state("long_shan_tunnel", "introduced")
						m_owner._request_landmark_audio_cue("long_shan_tunnel", landmark_id, trigger_id, display_name)
						m_owner.set_save_status("Long Shan Tunnel entry reached — find Tunnel Guide Ren.")
						m_owner._autosave_story_progress()
						return true
					return false
				"light_pocket_south", "light_pocket_north":
					if m_owner.get_landmark_state("long_shan_tunnel") != "in_progress":
						m_owner.set_save_status("The lit pockets matter once Tunnel Guide Ren starts the crossing.")
						return false
					var all_checkpoints := _collect_long_shan_checkpoint(trigger_id)
					if !melody_hint.is_empty():
						m_owner._emit_melody_hint_shown(melody_hint)
					m_owner._request_landmark_audio_cue("long_shan_tunnel", landmark_id, trigger_id, display_name)
					if all_checkpoints:
						m_owner.set_objective("Lead the route through to the Long Shan Tunnel exit.")
						m_owner.set_hint(m_owner.build_input_hint("R Collect Long Shan Tunnel Exit"))
						m_owner.set_save_status("Both lit pockets are steady — guide the route to the exit.")
					else:
						m_owner.set_objective("Keep moving with Ren until you reach the next lit pocket.")
						m_owner.set_save_status("A safe-lit pocket steadied the route ahead.")
					m_owner._autosave_story_progress()
					return true
				"tunnel_exit":
					if m_owner.get_landmark_state("long_shan_tunnel") == "in_progress":
						var checkpoint_count := _normalize_string_array(
							m_owner.get_landmark_progress("long_shan_tunnel").get("checkpoints_collected", [])
						).size()
						if checkpoint_count >= 2:
							if !melody_hint.is_empty():
								m_owner._emit_melody_hint_shown(melody_hint)
							m_owner._request_landmark_audio_cue("long_shan_tunnel", landmark_id, trigger_id, display_name)
							request_long_shan_route_prompt()
							return false
						m_owner.set_save_status("The route is still uneven. Pause with Ren at the lit pockets before crossing.")
						return false
					m_owner.set_save_status("Tunnel exit reached — talk to Tunnel Guide Ren before crossing.")
					return false
			return false
		"bagua_tower":
			if trigger_id != "synthesis_chamber":
				return false
			var tower_progress: Dictionary = m_owner.get_landmark_progress("bagua_tower")
			if tower_progress.is_empty():
				return false
			var melody_state: Dictionary = m_owner.get_melody_state("festival_melody")
			var fragments_in := int(melody_state.get("fragments_found", 0))
			if m_owner.get_landmark_state("bagua_tower") == "in_progress" \
			and fragments_in >= 3 \
			and !bool(tower_progress.get("synthesis_done", false)):
				resolve_bagua_tower_synthesis()
				m_owner._request_landmark_audio_cue("bagua_tower", landmark_id, trigger_id, display_name)
				m_owner._autosave_story_progress()
				return true
			m_owner.set_save_status("The tower shows distance but not yet direction. Recover more fragments first.")
			return false
		"festival_stage":
			if m_owner.get_landmark_state("festival_stage") != "available":
				return false
			if !melody_hint.is_empty():
				m_owner._emit_melody_hint_shown(melody_hint)
			m_owner._request_landmark_audio_cue("festival_stage", landmark_id, trigger_id, display_name)
			request_melody_prompt("festival_melody", "performance")
			return false

	return false


func request_melody_prompt(
	melody_id: String,
	prompt_mode: String,
	completion_kind: String = "",
	request_overrides: Dictionary = {}
) -> void:
	var melody_definition: Dictionary = m_owner.get_melody_definition(melody_id)
	if melody_definition.is_empty():
		m_owner.set_save_status("The phrase slips away before it can be arranged.")
		return

	var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
	if melody_state.is_empty():
		m_owner.set_save_status("The phrase is not ready yet.")
		return

	var prompt_segments := build_melody_prompt_segments(melody_id)
	if prompt_segments.size() < 2:
		m_owner.set_save_status("Recover at least two steady phrase segments before arranging the melody.")
		return

	var melody_stage := String(melody_state.get("state", "unknown"))
	if melody_stage not in ["reconstructed", "performed", "resonant"]:
		m_owner.set_save_status("The phrase needs more shape before it can be rehearsed.")
		return

	var normalized_completion_kind := completion_kind
	if normalized_completion_kind.is_empty():
		normalized_completion_kind = "festival_performance" if prompt_mode == "performance" else "melody_practice"

	if prompt_mode == "performance" \
	and normalized_completion_kind == "festival_performance" \
	and !m_owner.can_perform_melody(melody_id):
		m_owner.set_save_status("The performance point is not ready to answer the melody yet.")
		return

	var expected_order: Array[String] = []
	for segment in prompt_segments:
		expected_order.append(String(segment.get("source_id", "")))

	var first_label := String(prompt_segments[0].get("label", "the opening phrase"))
	var display_name := String(melody_definition.get("display_name", melody_id))
	var prompt_title := "Practice %s" % display_name
	var prompt_body := "Arrange the phrase segments in the order that feels right. There is no penalty for trying again."
	if prompt_mode == "performance":
		prompt_title = "Perform %s" % display_name
		prompt_body = String(melody_definition.get("performance_prompt", ""))

	var request := {
		"melody_id": melody_id,
		"mode": prompt_mode,
		"completion_kind": normalized_completion_kind,
		"title": prompt_title,
		"body": prompt_body,
		"segments": prompt_segments,
		"expected_order": expected_order,
		"retry_hint": "That contour felt off. Try beginning with %s." % first_label,
		"hint_text": "Choose the known phrase segments in order.",
	}
	request.merge(request_overrides, true)
	m_owner._emit_melody_prompt_requested(request)


func request_trinity_chime_prompt() -> void:
	m_owner._emit_melody_prompt_requested({
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "trinity_chime",
		"title": "Settle the Trinity Chime",
		"body": "Arrange the choir cues in the order Mei taught you, then let the church phrase settle into one calm chime.",
		"segments": [
			{"source_id": "steps", "label": "Stone Steps", "landmark": "Trinity Church"},
			{"source_id": "garden", "label": "Side Garden", "landmark": "Trinity Church"},
			{"source_id": "yard", "label": "Quiet Yard", "landmark": "Trinity Church"},
		],
		"expected_order": ["steps", "garden", "yard"],
		"retry_hint": "The church phrase begins at the steps before the garden and quiet yard answer.",
		"hint_text": "Choose the choir cues in Mei's order.",
	})


func request_bi_shan_chamber_prompt() -> void:
	m_owner._emit_melody_prompt_requested({
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "bi_shan_chamber",
		"title": "Settle the Bi Shan Contour",
		"body": "Arrange the tunnel echoes from the first steady contour to the mural-facing answer so the chamber can respond.",
		"segments": [
			{"source_id": "echo_a", "label": "North Wall Echo", "landmark": "Bi Shan Tunnel"},
			{"source_id": "echo_b", "label": "Arch Midpoint", "landmark": "Bi Shan Tunnel"},
			{"source_id": "echo_c", "label": "Mural Approach", "landmark": "Bi Shan Tunnel"},
		],
		"expected_order": ["echo_a", "echo_b", "echo_c"],
		"retry_hint": "Let the north wall answer first, then the arch midpoint, before the mural approach settles.",
		"hint_text": "Choose the tunnel echoes in the contour they reveal together.",
	})


func request_long_shan_route_prompt() -> void:
	m_owner._emit_melody_prompt_requested({
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "long_shan_route",
		"title": "Steady the Long Shan Route",
		"body": "Confirm the lit-pocket rhythm that carried Ren through the tunnel before the exit can settle into one route.",
		"segments": [
			{"source_id": "light_pocket_south", "label": "South Lit Pocket", "landmark": "Long Shan Tunnel"},
			{"source_id": "light_pocket_north", "label": "North Lit Pocket", "landmark": "Long Shan Tunnel"},
		],
		"expected_order": ["light_pocket_south", "light_pocket_north"],
		"retry_hint": "The steadier route begins with the south lit pocket before the northern light answers it.",
		"hint_text": "Choose the lit pockets in the order Ren followed them.",
	})


func build_melody_prompt_segments(melody_id: String) -> Array[Dictionary]:
	var melody_definition: Dictionary = m_owner.get_melody_definition(melody_id)
	var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
	if melody_definition.is_empty() or melody_state.is_empty():
		return []

	var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
	var prompt_segments: Array[Dictionary] = []

	for source in melody_definition.get("sources", []):
		var source_id := String(source.get("source_id", ""))
		if source_id.is_empty():
			continue
		if !bool(source.get("counts_as_fragment", true)):
			continue
		if known_sources.find(source_id) < 0:
			continue

		prompt_segments.append({
			"source_id": source_id,
			"label": String(source.get("label", "Unknown phrase")),
			"landmark": String(source.get("landmark", "Unknown landmark")),
		})

	return prompt_segments


func complete_prompt_request(request: Dictionary) -> void:
	var completion_kind := String(request.get("completion_kind", ""))
	var melody_id := String(request.get("melody_id", ""))

	match completion_kind:
		"melody_practice":
			complete_melody_practice(melody_id)
		"festival_performance":
			complete_melody_performance(melody_id)
		"trinity_chime":
			complete_trinity_church_chime()
		"bi_shan_chamber":
			complete_bi_shan_chamber()
		"long_shan_route":
			complete_long_shan_route()
		_:
			m_owner.set_save_status("The phrase settles, but nothing answers it yet.")


func complete_melody_practice(melody_id: String) -> void:
	var melody_definition: Dictionary = m_owner.get_melody_definition(melody_id)
	if melody_definition.is_empty():
		m_owner.set_save_status("The phrase slips away before you can practice it.")
		return

	m_owner.set_save_status(
		"%s feels steadier after a short rehearsal." % String(melody_definition.get("display_name", "The melody"))
	)


func complete_melody_performance(melody_id: String) -> void:
	var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
	if melody_state.is_empty():
		m_owner.set_save_status("The performance point is not ready yet.")
		return

	if bool(melody_state.get("performed", false)):
		m_owner.set_save_status("The harbor already remembers this melody.")
		return

	if !m_owner.can_perform_melody(melody_id):
		m_owner.set_save_status("The phrase is not ready to carry across the harbor yet.")
		return

	match melody_id:
		"festival_melody":
			perform_festival_melody()
		_:
			m_owner.set_save_status("This performance point is not wired yet.")


func complete_trinity_church_chime() -> void:
	var progress: Dictionary = m_owner.get_landmark_progress("trinity_church")
	if progress.is_empty():
		m_owner.set_save_status("The church phrase is not ready to settle yet.")
		return

	var cues := _normalize_string_array(progress.get("cues_collected", []))
	if cues.size() < 3:
		m_owner.set_save_status("The church phrase still needs all three choir cues.")
		return

	if bool(progress.get("chime_performed", false)):
		m_owner.set_save_status("The church bells have already settled into place.")
		return

	progress["chime_performed"] = true
	progress["state"] = "resolved"
	m_owner.set_landmark_progress("trinity_church", progress)
	m_owner.set_objective("Return to Choir Caretaker Mei with the settled church phrase.")
	m_owner.set_hint(m_owner.build_input_hint("R Talk to Choir Caretaker Mei"))
	m_owner.set_save_status("The choir phrase settled into one calm church chime.")
	m_owner._autosave_story_progress()


func complete_bi_shan_chamber() -> void:
	var progress: Dictionary = m_owner.get_landmark_progress("bi_shan_tunnel")
	var echoes := _normalize_string_array(progress.get("echoes_collected", []))
	if echoes.size() < 3:
		m_owner.set_save_status("The mural panel is still waiting on the three tunnel echoes.")
		return

	if m_owner.get_landmark_state("bi_shan_tunnel") == "reward_collected":
		m_owner.set_save_status("The Bi Shan contour has already settled into the tunnel walls.")
		return

	resolve_bi_shan_tunnel()
	m_owner._autosave_story_progress()


func complete_long_shan_route() -> void:
	var progress: Dictionary = m_owner.get_landmark_progress("long_shan_tunnel")
	var checkpoints := _normalize_string_array(progress.get("checkpoints_collected", []))
	if checkpoints.size() < 2 or m_owner.get_landmark_state("long_shan_tunnel") != "in_progress":
		m_owner.set_save_status("The Long Shan route still needs both lit pockets before it can settle.")
		return

	resolve_long_shan_tunnel()
	m_owner._autosave_story_progress()


func resolve_landmark(landmark_id: String) -> void:
	match landmark_id:
		"piano_ferry":
			resolve_piano_ferry()
		"trinity_church":
			resolve_trinity_church()
		"bagua_tower":
			resolve_bagua_tower()

	m_owner._emit_story_milestone("landmark_resolved", {
		"landmark_id": landmark_id,
		"fragments_found": m_owner.fragments_found,
		"helped_residents": m_owner._count_helped_residents(),
	})


func resolve_piano_ferry() -> void:
	m_owner.advance_landmark_state("piano_ferry", "reward_collected")
	m_owner.set_journal_unlocked(true)

	var previous_melody: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
	var melody_state := award_festival_source_once("ferry_plaza", false)
	sync_festival_state_from_fragments(melody_state)
	melody_state["next_lead"] = "Speak with the church caretaker and compare how the bells answer the harbor."
	m_owner.set_melody_progress({"festival_melody": melody_state})
	m_owner.resolve_story_event("melody_ferry_settled")
	emit_fragment_story_milestones(previous_melody, "ferry_plaza", melody_state, false)
	m_owner.set_save_status("Journal unlocked - Trinity Church is marked as your first lead.")


func resolve_trinity_church() -> void:
	m_owner.advance_landmark_state("trinity_church", "reward_collected")

	var previous_melody: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
	var melody_state := award_festival_source_once("church_bells")
	sync_festival_state_from_fragments(melody_state)

	m_owner.set_melody_progress({"festival_melody": melody_state})
	m_owner.resolve_story_event("melody_church_restored")
	emit_fragment_story_milestones(previous_melody, "church_bells", melody_state)

	m_owner.advance_landmark_state("bi_shan_tunnel", "available")
	m_owner.advance_landmark_state("long_shan_tunnel", "available")


func resolve_bi_shan_tunnel() -> void:
	m_owner.advance_landmark_state("bi_shan_tunnel", "reward_collected")

	var previous_melody: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
	var melody_state := award_festival_source_once("bi_shan_echo")
	sync_festival_state_from_fragments(melody_state)

	m_owner.set_melody_progress({"festival_melody": melody_state})
	m_owner.resolve_story_event("melody_bi_shan_restored")
	emit_fragment_story_milestones(previous_melody, "bi_shan_echo", melody_state)
	m_owner.unlock_shortcut("bi_shan_crossing")
	if m_owner.get_landmark_state("long_shan_tunnel") == "reward_collected" \
	and m_owner.get_landmark_state("bagua_tower") == "locked":
		m_owner.set_objective("Return to Tunnel Guide Ren now that both tunnel routes agree.")
		m_owner.set_hint(m_owner.build_input_hint("R Talk to Tunnel Guide Ren"))
		m_owner.set_save_status("Bi Shan Tunnel — mural resonance restored. Ren can now compare the two tunnel routes.")
	elif m_owner.get_landmark_state("bagua_tower") != "locked":
		m_owner.set_objective("Carry the steadier tunnel route up to Bagua Tower.")
		m_owner.set_hint(m_owner.build_input_hint("R Talk to Tower Keeper Suyin"))
		m_owner.set_save_status("Bi Shan Tunnel — mural resonance restored, and the tower can now read the route clearly.")
	else:
		m_owner.set_objective("Explore Long Shan Tunnel and move with Ren between the lit pockets.")
		m_owner.set_hint(m_owner.build_input_hint("R Inspect"))
		m_owner.set_save_status("Bi Shan Tunnel — mural resonance restored, and the tunnel route feels steadier now.")


func resolve_long_shan_tunnel() -> void:
	m_owner.advance_landmark_state("long_shan_tunnel", "reward_collected")

	var previous_melody: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
	var melody_state := award_festival_source_once("long_shan_route")
	sync_festival_state_from_fragments(melody_state)

	m_owner.set_melody_progress({"festival_melody": melody_state})
	m_owner.resolve_story_event("melody_long_shan_restored")
	emit_fragment_story_milestones(previous_melody, "long_shan_route", melody_state)
	m_owner.set_objective("Return to Tunnel Guide Ren and compare what the tunnel routes now suggest.")
	m_owner.set_hint(m_owner.build_input_hint("R Talk to Tunnel Guide Ren"))
	m_owner.set_save_status("Long Shan Tunnel — passage completed. Ren can now judge what the route means.")


func resolve_bagua_tower_synthesis() -> void:
	var progress: Dictionary = m_owner.get_landmark_progress("bagua_tower")
	progress["synthesis_done"] = true
	progress["state"] = "resolved"
	m_owner.set_landmark_progress("bagua_tower", progress)
	m_owner.set_objective("Return to Tower Keeper Suyin to confirm the island route.")
	m_owner.set_save_status("Bagua Tower synthesis complete — return to Tower Keeper Suyin.")


func resolve_bagua_tower() -> void:
	m_owner.advance_landmark_state("bagua_tower", "reward_collected")

	var previous_melody: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
	var melody_state := award_festival_source_once("tower_chamber")
	sync_festival_state_from_fragments(melody_state)
	melody_state["next_lead"] = "Return to the ferry plaza and perform the restored melody at the festival stage."

	m_owner.set_melody_progress({"festival_melody": melody_state})
	m_owner.resolve_story_event("melody_bagua_aligned")
	emit_fragment_story_milestones(previous_melody, "tower_chamber", melody_state)
	m_owner.advance_landmark_state("festival_stage", "available")
	m_owner.set_objective("Return to Piano Ferry and perform the restored melody at the festival stage.")
	m_owner.set_save_status("The island melody is whole — the harbor stage is ready.")


func sync_festival_state_from_fragments(melody_state: Dictionary) -> void:
	var found := int(melody_state.get("fragments_found", 0))
	var performed := bool(melody_state.get("performed", false))
	var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
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


func perform_festival_melody() -> void:
	m_owner.advance_landmark_state("festival_stage", "reward_collected")

	var melody_state: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
	melody_state["performed"] = true
	melody_state["state"] = "performed"
	melody_state["next_lead"] = "Stay for the harbor gathering or keep wandering once the festival recap ends."
	m_owner.set_melody_progress({"festival_melody": melody_state})

	m_owner.resolve_story_event("harbor_festival_performed")
	m_owner.set_objective("The restored festival melody carries across the harbor.")
	m_owner.set_save_status("The harbor gathering answers the restored melody.")
	m_owner._emit_story_milestone("festival_performed", {
		"fragments_found": m_owner.fragments_found,
		"helped_residents": m_owner._count_helped_residents(),
	})


func _progress_has_string_entry(progress: Dictionary, progress_key: String, entry_id: String) -> bool:
	return _normalize_string_array(progress.get(progress_key, [])).find(entry_id) >= 0


func _collect_piano_ferry_harbor_clue() -> void:
	var progress: Dictionary = m_owner.get_landmark_progress("piano_ferry")
	if progress.is_empty():
		return

	progress["harbor_clue_found"] = true
	progress["state"] = "resolved"
	m_owner.set_landmark_progress("piano_ferry", progress)


func _collect_trinity_church_cue(cue_id: String) -> bool:
	var progress: Dictionary = m_owner.get_landmark_progress("trinity_church")
	if progress.is_empty():
		return false

	var cues := _normalize_string_array(progress.get("cues_collected", []))
	if cues.find(cue_id) >= 0:
		return cues.size() >= 3

	cues.append(cue_id)
	progress["cues_collected"] = cues

	var current_state := String(progress.get("state", "locked"))
	if current_state == "available" or current_state == "introduced":
		progress["state"] = "in_progress"

	m_owner.set_landmark_progress("trinity_church", progress)
	return cues.size() >= 3


func _collect_bi_shan_echo(echo_id: String) -> bool:
	var progress: Dictionary = m_owner.get_landmark_progress("bi_shan_tunnel")
	if progress.is_empty():
		return false

	var echoes := _normalize_string_array(progress.get("echoes_collected", []))
	if echoes.find(echo_id) >= 0:
		return echoes.size() >= 3

	echoes.append(echo_id)
	progress["echoes_collected"] = echoes

	var current_state := String(progress.get("state", "locked"))
	if current_state == "available" or current_state == "introduced":
		progress["state"] = "in_progress"

	m_owner.set_landmark_progress("bi_shan_tunnel", progress)
	return echoes.size() >= 3


func _collect_long_shan_checkpoint(checkpoint_id: String) -> bool:
	var progress: Dictionary = m_owner.get_landmark_progress("long_shan_tunnel")
	if progress.is_empty():
		return false

	var checkpoints := _normalize_string_array(progress.get("checkpoints_collected", []))
	if checkpoints.find(checkpoint_id) >= 0:
		return checkpoints.size() >= 2

	checkpoints.append(checkpoint_id)
	progress["checkpoints_collected"] = checkpoints
	m_owner.set_landmark_progress("long_shan_tunnel", progress)
	return checkpoints.size() >= 2


func award_festival_source_once(source_id: String, counts_as_fragment: bool = true) -> Dictionary:
	var melody_state: Dictionary = m_owner.get_melody_state("festival_melody").duplicate(true)
	var sources := _normalize_string_array(melody_state.get("known_sources", []))
	if sources.find(source_id) >= 0:
		melody_state["known_sources"] = sources
		return melody_state

	sources.append(source_id)
	melody_state["known_sources"] = sources
	if counts_as_fragment:
		var new_count := mini(
			int(melody_state.get("fragments_found", 0)) + 1,
			int(melody_state.get("fragments_total", m_owner.fragments_total))
		)
		melody_state["fragments_found"] = new_count

	return melody_state


func emit_fragment_story_milestones(
	previous_melody: Dictionary,
	source_id: String,
	melody_state: Dictionary,
	counts_as_fragment: bool = true
) -> void:
	var previous_sources := _normalize_string_array(previous_melody.get("known_sources", []))
	if previous_sources.find(source_id) >= 0 or !counts_as_fragment:
		return

	var new_count := int(melody_state.get("fragments_found", 0))
	m_owner._emit_story_milestone("fragment_restored", {
		"melody_id": "festival_melody",
		"source_id": source_id,
		"total_found": new_count,
	})

	if new_count >= int(melody_state.get("fragments_total", m_owner.fragments_total)):
		m_owner._emit_story_milestone("festival_ready", {
			"fragments_found": new_count,
			"helped_residents": m_owner._count_helped_residents(),
		})


func _normalize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []

	if value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
		return output

	if value is Array:
		for entry in value:
			output.append(String(entry))

	return output
