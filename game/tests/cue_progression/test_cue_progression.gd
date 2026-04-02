extends Node2D

const TRINITY_CHURCH_SCENE: PackedScene = preload("res://architecture/trinity_church.tscn")
const LONG_SHAN_TUNNEL_SCENE: PackedScene = preload("res://architecture/long_shan_tunnel.tscn")
const PIANO_FERRY_SCENE: PackedScene = preload("res://architecture/piano_ferry.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()
var m_milestones := PackedStringArray()
var m_prompt_requests: Array[Dictionary] = []


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if !_app_state().story_milestone.is_connected(_on_story_milestone):
		_app_state().story_milestone.connect(_on_story_milestone)
	if !_app_state().melody_prompt_requested.is_connected(_on_melody_prompt_requested):
		_app_state().melody_prompt_requested.connect(_on_melody_prompt_requested)

	_app_state().configure_new_game()
	_assert_true(_app_state().fragments_found == 0, "New game starts with zero fragments")
	_assert_true(_app_state().get_landmark_state("festival_stage") == "locked", "Festival stage starts locked")
	_assert_true(!_app_state().can_practice_melody("festival_melody"), "Practice stays locked until at least two true fragments are restored")

	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")
	_assert_true(_app_state().is_journal_unlocked(), "Journal unlocks after the ferry handoff")
	_assert_true(_app_state().fragments_found == 0, "Ferry onboarding does not count as a fragment")
	_assert_true(_app_state().get_landmark_state("trinity_church") == "available", "Trinity unlocks after the ferry handoff")

	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().activate_landmark_trigger("trinity_church", "steps", "Steps")
	_app_state().activate_landmark_trigger("trinity_church", "garden", "Garden")
	_app_state().activate_landmark_trigger("trinity_church", "yard", "Yard")
	var trinity_requests_before := m_prompt_requests.size()
	var chime_consumed = _app_state().activate_landmark_trigger("trinity_church", "choir_chime", "Choir Chime")
	_assert_true(!chime_consumed, "Trinity choir chime waits for prompt confirmation before resolution")
	_assert_true(m_prompt_requests.size() == trinity_requests_before + 1, "Trinity choir chime requests the prompt once all cues are gathered")
	_assert_true(_app_state().fragments_found == 0, "Trinity does not award a fragment before the choir chime settles")
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(_app_state().get_landmark_state("trinity_church") == "resolved", "Trinity enters a settled state after the choir chime prompt succeeds")
	_app_state().interact_with_resident("church_caretaker")
	_assert_true(_app_state().fragments_found == 1, "Trinity awards the first fragment")
	_assert_true(_app_state().get_landmark_state("bi_shan_tunnel") == "available", "Bi Shan unlocks after Trinity")
	_assert_true(_app_state().get_landmark_state("long_shan_tunnel") == "available", "Long Shan unlocks after Trinity")

	_app_state().activate_landmark_trigger("bi_shan_tunnel", "echo_a", "Echo A")
	_app_state().activate_landmark_trigger("bi_shan_tunnel", "echo_b", "Echo B")
	_app_state().activate_landmark_trigger("bi_shan_tunnel", "echo_c", "Echo C")
	var bi_shan_requests_before := m_prompt_requests.size()
	var chamber_consumed = _app_state().activate_landmark_trigger("bi_shan_tunnel", "chamber", "Mural Chamber")
	_assert_true(!chamber_consumed, "Bi Shan chamber waits for prompt confirmation before resolution")
	_assert_true(m_prompt_requests.size() == bi_shan_requests_before + 1, "Bi Shan chamber requests the prompt once all echoes are gathered")
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(_app_state().fragments_found == 2, "Bi Shan awards the second fragment")
	_assert_true(_app_state().get_open_shortcuts().find("bi_shan_crossing") >= 0, "Bi Shan records the dependable tunnel route reward")
	_assert_true(_app_state().build_map_journal_text().contains("Dependable routes"), "The journal map lists dependable route notes")
	_assert_true(_app_state().build_map_journal_text().contains("Bi Shan Tunnel Route"), "The journal map lists the Bi Shan tunnel route note")
	_assert_true(_app_state().can_practice_melody("festival_melody"), "Practice unlocks once the melody is reconstructed")

	var practice_requests_before := m_prompt_requests.size()
	_app_state().request_melody_practice("festival_melody")
	_assert_true(m_prompt_requests.size() == practice_requests_before + 1, "Journal practice requests the melody prompt once reconstructed")

	_app_state().activate_landmark_trigger("long_shan_tunnel", "tunnel_entry", "Entry")
	_app_state().interact_with_resident("tunnel_guide")
	_app_state().interact_with_resident("tunnel_guide")
	_app_state().activate_landmark_trigger("long_shan_tunnel", "light_pocket_south", "Lit Pocket")
	_app_state().activate_landmark_trigger("long_shan_tunnel", "light_pocket_north", "Lit Pocket")
	var long_shan_requests_before := m_prompt_requests.size()
	var exit_consumed = _app_state().activate_landmark_trigger("long_shan_tunnel", "tunnel_exit", "Exit")
	_assert_true(!exit_consumed, "Long Shan exit waits for prompt confirmation before resolution")
	_assert_true(m_prompt_requests.size() == long_shan_requests_before + 1, "Long Shan exit requests the route prompt after both lit pockets")
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(_app_state().objective.contains("Tunnel Guide Ren"), "Long Shan exit points the player back to Ren before Bagua unlocks")
	_assert_true(_app_state().fragments_found == 3, "Long Shan awards the third fragment after the route prompt settles")
	_assert_true(_app_state().get_landmark_state("bagua_tower") == "locked", "Bagua stays locked until Ren delivers the tower handoff")
	_app_state().interact_with_resident("tunnel_guide")
	_assert_true(_app_state().get_landmark_state("bagua_tower") == "available", "Bagua unlocks after Long Shan")

	_app_state().interact_with_resident("tower_keeper")
	_app_state().interact_with_resident("tower_keeper")
	_app_state().activate_landmark_trigger("bagua_tower", "synthesis_chamber", "Synthesis Chamber")
	_app_state().interact_with_resident("tower_keeper")
	_assert_true(_app_state().fragments_found == 4, "Bagua awards the fourth fragment")
	_assert_true(_app_state().get_landmark_state("festival_stage") == "available", "Festival stage unlocks after Bagua")
	_assert_true(!bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Bagua does not mark the melody performed")

	var festival_requests_before := m_prompt_requests.size()
	var stage_consumed = _app_state().activate_landmark_trigger("festival_stage", "harbor_stage", "Festival Stage")
	_assert_true(!stage_consumed, "Festival stage waits for prompt confirmation before completion")
	_assert_true(m_prompt_requests.size() == festival_requests_before + 1, "Festival stage requests the melody prompt")
	_assert_true(!bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Festival stage does not mark the melody performed before prompt success")
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Festival stage marks the melody performed")
	_assert_true(m_milestones.has("festival_performed"), "Festival performance emits the festival_performed milestone")

	_app_state().configure_new_game()
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().activate_landmark_trigger("trinity_church", "steps", "Steps")
	_app_state().activate_landmark_trigger("trinity_church", "garden", "Garden")
	_app_state().activate_landmark_trigger("trinity_church", "yard", "Yard")
	_app_state().activate_landmark_trigger("trinity_church", "choir_chime", "Choir Chime")
	_app_state().complete_prompt_request({"completion_kind": "trinity_chime"})
	_app_state().interact_with_resident("church_caretaker")
	_app_state().activate_landmark_trigger("long_shan_tunnel", "tunnel_entry", "Entry")
	_app_state().interact_with_resident("tunnel_guide")
	_app_state().interact_with_resident("tunnel_guide")
	_app_state().activate_landmark_trigger("long_shan_tunnel", "light_pocket_south", "Lit Pocket")
	_app_state().activate_landmark_trigger("long_shan_tunnel", "light_pocket_north", "Lit Pocket")
	_app_state().activate_landmark_trigger("long_shan_tunnel", "tunnel_exit", "Exit")
	_app_state().complete_prompt_request({"completion_kind": "long_shan_route"})
	var ren_midgame = _app_state().interact_with_resident("tunnel_guide")
	_assert_true(_app_state().get_landmark_state("bagua_tower") == "locked", "Long Shan alone does not unlock Bagua")
	_assert_true(String(ren_midgame.get("objective", _app_state().objective)).contains("Bi Shan"), "Ren redirects the player to Bi Shan when the other tunnel is still unresolved")
	_app_state().activate_landmark_trigger("bi_shan_tunnel", "echo_a", "Echo A")
	_app_state().activate_landmark_trigger("bi_shan_tunnel", "echo_b", "Echo B")
	_app_state().activate_landmark_trigger("bi_shan_tunnel", "echo_c", "Echo C")
	_app_state().activate_landmark_trigger("bi_shan_tunnel", "chamber", "Mural Chamber")
	_app_state().complete_prompt_request({"completion_kind": "bi_shan_chamber"})
	_app_state().interact_with_resident("tunnel_guide")
	_assert_true(_app_state().get_landmark_state("bagua_tower") == "available", "Ren unlocks Bagua once both tunnel routes are steady")

	var trinity_scene: Node = TRINITY_CHURCH_SCENE.instantiate()
	var cue_garden: Node = trinity_scene.get_node("CueGarden")
	var cue_yard: Node = trinity_scene.get_node("CueYard")
	var choir_chime: Node = trinity_scene.get_node("ChoirChime")
	_assert_true(cue_garden.requires_collected == ["steps"], "Trinity garden cue waits for the steps cue")
	_assert_true(cue_yard.requires_collected == ["steps", "garden"], "Trinity yard cue waits for steps and garden")
	_assert_true(choir_chime.requires_collected == ["steps", "garden", "yard"], "Trinity choir chime waits for all three choir cues")
	trinity_scene.free()

	var long_shan_scene: Node = LONG_SHAN_TUNNEL_SCENE.instantiate()
	var pocket_south: Node = long_shan_scene.get_node("LightPocketSouth")
	var pocket_north: Node = long_shan_scene.get_node("LightPocketNorth")
	_assert_true(pocket_south != null, "Long Shan includes the first lit pocket cue")
	_assert_true(pocket_north.requires_collected == ["light_pocket_south"], "Long Shan second pocket waits for the first")
	long_shan_scene.free()

	var piano_ferry_scene: Node = PIANO_FERRY_SCENE.instantiate()
	var festival_stage: Node = piano_ferry_scene.get_node("FestivalStage")
	_assert_true(festival_stage != null, "Piano Ferry includes the festival stage trigger")
	piano_ferry_scene.free()

	if m_failures.is_empty():
		print("PASS: cue progression flow")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Cue progression flow failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _on_story_milestone(milestone_id: String, _context: Dictionary) -> void:
	m_milestones.append(milestone_id)


func _on_melody_prompt_requested(request: Dictionary) -> void:
	m_prompt_requests.append(request.duplicate(true))


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
