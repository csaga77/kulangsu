extends Node2D

const TRINITY_CHURCH_SCENE: PackedScene = preload("res://architecture/trinity_church.tscn")
const LONG_SHAN_TUNNEL_SCENE: PackedScene = preload("res://architecture/long_shan_tunnel.tscn")
const PIANO_FERRY_SCENE: PackedScene = preload("res://architecture/piano_ferry.tscn")

var m_failures := PackedStringArray()
var m_milestones := PackedStringArray()
var m_prompt_requests: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if !AppState.story_milestone.is_connected(_on_story_milestone):
		AppState.story_milestone.connect(_on_story_milestone)
	if !AppState.melody_prompt_requested.is_connected(_on_melody_prompt_requested):
		AppState.melody_prompt_requested.connect(_on_melody_prompt_requested)

	AppState.configure_new_game()
	_assert_true(AppState.fragments_found == 0, "New game starts with zero fragments")
	_assert_true(AppState.get_landmark_state("festival_stage") == "locked", "Festival stage starts locked")
	_assert_true(!AppState.can_practice_melody("festival_melody"), "Practice stays locked until at least two true fragments are restored")

	AppState.interact_with_resident("ferry_caretaker")
	AppState.activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Clue")
	AppState.interact_with_resident("ferry_caretaker")
	_assert_true(AppState.is_journal_unlocked(), "Journal unlocks after the ferry handoff")
	_assert_true(AppState.fragments_found == 0, "Ferry onboarding does not count as a fragment")
	_assert_true(AppState.get_landmark_state("trinity_church") == "available", "Trinity unlocks after the ferry handoff")

	AppState.interact_with_resident("church_caretaker")
	AppState.interact_with_resident("church_caretaker")
	AppState.activate_landmark_trigger("trinity_church", "steps", "Steps")
	AppState.activate_landmark_trigger("trinity_church", "garden", "Garden")
	AppState.activate_landmark_trigger("trinity_church", "yard", "Yard")
	AppState.interact_with_resident("church_caretaker")
	_assert_true(AppState.fragments_found == 1, "Trinity awards the first fragment")
	_assert_true(AppState.get_landmark_state("bi_shan_tunnel") == "available", "Bi Shan unlocks after Trinity")
	_assert_true(AppState.get_landmark_state("long_shan_tunnel") == "available", "Long Shan unlocks after Trinity")

	AppState.activate_landmark_trigger("bi_shan_tunnel", "echo_a", "Echo A")
	AppState.activate_landmark_trigger("bi_shan_tunnel", "echo_b", "Echo B")
	AppState.activate_landmark_trigger("bi_shan_tunnel", "echo_c", "Echo C")
	AppState.activate_landmark_trigger("bi_shan_tunnel", "chamber", "Mural Chamber")
	_assert_true(AppState.fragments_found == 2, "Bi Shan awards the second fragment")
	_assert_true(AppState.can_practice_melody("festival_melody"), "Practice unlocks once the melody is reconstructed")

	var practice_requests_before := m_prompt_requests.size()
	AppState.request_melody_practice("festival_melody")
	_assert_true(m_prompt_requests.size() == practice_requests_before + 1, "Journal practice requests the melody prompt once reconstructed")

	AppState.activate_landmark_trigger("long_shan_tunnel", "tunnel_entry", "Entry")
	AppState.interact_with_resident("tunnel_guide")
	AppState.interact_with_resident("tunnel_guide")
	AppState.activate_landmark_trigger("long_shan_tunnel", "light_pocket_south", "Lit Pocket")
	AppState.activate_landmark_trigger("long_shan_tunnel", "light_pocket_north", "Lit Pocket")
	AppState.activate_landmark_trigger("long_shan_tunnel", "tunnel_exit", "Exit")
	AppState.interact_with_resident("tunnel_guide")
	_assert_true(AppState.fragments_found == 3, "Long Shan awards the third fragment")
	_assert_true(AppState.get_landmark_state("bagua_tower") == "available", "Bagua unlocks after Long Shan")

	AppState.interact_with_resident("tower_keeper")
	AppState.interact_with_resident("tower_keeper")
	AppState.activate_landmark_trigger("bagua_tower", "synthesis_chamber", "Synthesis Chamber")
	AppState.interact_with_resident("tower_keeper")
	_assert_true(AppState.fragments_found == 4, "Bagua awards the fourth fragment")
	_assert_true(AppState.get_landmark_state("festival_stage") == "available", "Festival stage unlocks after Bagua")
	_assert_true(!bool(AppState.get_melody_state("festival_melody").get("performed", false)), "Bagua does not mark the melody performed")

	var festival_requests_before := m_prompt_requests.size()
	var stage_consumed := AppState.activate_landmark_trigger("festival_stage", "harbor_stage", "Festival Stage")
	_assert_true(!stage_consumed, "Festival stage waits for prompt confirmation before completion")
	_assert_true(m_prompt_requests.size() == festival_requests_before + 1, "Festival stage requests the melody prompt")
	_assert_true(!bool(AppState.get_melody_state("festival_melody").get("performed", false)), "Festival stage does not mark the melody performed before prompt success")
	AppState.complete_melody_performance("festival_melody")
	_assert_true(bool(AppState.get_melody_state("festival_melody").get("performed", false)), "Festival stage marks the melody performed")
	_assert_true(m_milestones.has("festival_performed"), "Festival performance emits the festival_performed milestone")

	var trinity_scene: Node = TRINITY_CHURCH_SCENE.instantiate()
	var cue_garden: Node = trinity_scene.get_node("CueGarden")
	var cue_yard: Node = trinity_scene.get_node("CueYard")
	_assert_true(cue_garden.requires_collected == ["steps"], "Trinity garden cue waits for the steps cue")
	_assert_true(cue_yard.requires_collected == ["steps", "garden"], "Trinity yard cue waits for steps and garden")
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
