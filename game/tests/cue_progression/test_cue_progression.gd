extends Node2D

const TRINITY_CHURCH_SCENE: PackedScene = preload("res://architecture/trinity_church.tscn")
const BI_SHAN_TUNNEL_SCENE: PackedScene = preload("res://architecture/bi_shan_tunnel.tscn")
const LONG_SHAN_TUNNEL_SCENE: PackedScene = preload("res://architecture/long_shan_tunnel.tscn")
const PIANO_FERRY_SCENE: PackedScene = preload("res://architecture/piano_ferry.tscn")
const BAGUA_TOWER_SCENE: PackedScene = preload("res://architecture/bagua_tower/bagua_tower.tscn")
const TERRAIN_SCENE: PackedScene = preload("res://terrain/terrain.tscn")
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const StorySubjectArea2D = preload("res://game/story_subject_area.gd")

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
	_assert_true(_app_state().get_landmark_state("festival_stage") == "locked", "Festival stage stays locked until Spring Festival is emotionally ready")
	_assert_true(!bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Bagua does not mark the melody performed")

	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("tea_vendor_hua")
	_app_state().interact_with_resident("ferry_caretaker")
	_assert_true(bool(_app_state().get_story_flag("spring_festival_resolved", false)), "The family route can still bring Spring Festival online after the melody is complete")
	_assert_true(_app_state().get_landmark_state("festival_stage") == "available", "Festival stage unlocks once Bagua and Spring Festival are both resolved")

	var festival_requests_before := m_prompt_requests.size()
	var stage_consumed = _app_state().activate_landmark_trigger("festival_stage", "harbor_stage", "Festival Stage")
	_assert_true(!stage_consumed, "Festival stage waits for prompt confirmation before completion")
	_assert_true(m_prompt_requests.size() == festival_requests_before + 1, "Festival stage requests the melody prompt")
	_assert_true(!bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Festival stage does not mark the melody performed before prompt success")
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Festival stage marks the melody performed")
	_assert_true(m_milestones.has("festival_performed"), "Festival performance emits the festival_performed milestone")
	_assert_true(bool(_app_state().endgame_state.get("active", false)), "Festival performance can now start the final act once spring has resolved")
	_assert_true(String(_app_state().endgame_state.get("trigger_event_id", "")) == "harbor_festival_performed", "Festival performance stores the correct endgame trigger once it is allowed")
	_assert_true(_app_state().get_endgame_behavior() == "continue_story", "Harbor performance is classified as a soft ending that can continue into play")
	_assert_true(_app_state().continue_story_after_endgame(), "Soft endings can clear the ending state and return to live story play")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Continuing after a soft ending clears the active endgame state")
	_assert_true(String(_app_state().get_melody_state("festival_melody").get("state", "")) == "resonant", "Continuing after the harbor ending upgrades the melody into its persistent resonant state")

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
	_assert_true(
		_find_subject_areas_with_prefix(trinity_scene, "landmark:").size() == 4,
		"Trinity Church now owns its cue subjects inside the packed church scene"
	)
	trinity_scene.free()

	var long_shan_scene: Node = LONG_SHAN_TUNNEL_SCENE.instantiate()
	_assert_true(
		_find_subject_areas_with_prefix(long_shan_scene, "landmark:").size() == 4,
		"Long Shan now owns its route subjects inside the packed tunnel scene"
	)
	long_shan_scene.free()

	var bi_shan_scene: Node = BI_SHAN_TUNNEL_SCENE.instantiate()
	_assert_true(
		_find_subject_areas_with_prefix(bi_shan_scene, "landmark:").size() == 4,
		"Bi Shan now owns its echo subjects inside the packed tunnel scene"
	)
	bi_shan_scene.free()

	var piano_ferry_scene: Node = PIANO_FERRY_SCENE.instantiate()
	_assert_true(
		_find_subject_areas_with_prefix(piano_ferry_scene, "landmark:").size() == 2,
		"Piano Ferry now owns its harbor subjects inside the packed ferry scene"
	)
	piano_ferry_scene.free()

	var bagua_tower_scene: Node = BAGUA_TOWER_SCENE.instantiate()
	_assert_true(
		_find_subject_areas_with_prefix(bagua_tower_scene, "landmark:").size() == 1,
		"Bagua Tower now owns its synthesis subject inside the packed tower scene"
	)
	bagua_tower_scene.free()

	var terrain_scene := TERRAIN_SCENE.instantiate()
	add_child(terrain_scene)
	await get_tree().process_frame
	var cue_garden := terrain_scene.get_node_or_null(
		"ground/buildings/TrinityChurch/CueGarden"
	) as StorySubjectArea2D
	var cue_yard := terrain_scene.get_node_or_null(
		"ground/buildings/TrinityChurch/CueYard"
	) as StorySubjectArea2D
	var choir_chime := terrain_scene.get_node_or_null(
		"ground/buildings/TrinityChurch/ChoirChime"
	) as StorySubjectArea2D
	_assert_true(cue_garden != null, "Trinity Church includes the garden cue under the terrain landmark instance")
	_assert_true(cue_yard != null, "Trinity Church includes the yard cue under the terrain landmark instance")
	_assert_true(choir_chime != null, "Trinity Church includes the choir chime under the terrain landmark instance")
	if cue_garden != null:
		_assert_true(cue_garden.subject_id == "landmark:trinity_church.garden", "Trinity garden cue resolves through a generic story subject id")
	if cue_yard != null:
		_assert_true(cue_yard.subject_id == "landmark:trinity_church.yard", "Trinity yard cue resolves through a generic story subject id")
	if choir_chime != null:
		_assert_true(choir_chime.subject_id == "landmark:trinity_church.choir_chime", "Trinity choir chime resolves through a generic story subject id")

	var pocket_south := terrain_scene.get_node_or_null(
		"long_shan_tunnel/interior_triggers/LightPocketSouth"
	) as StorySubjectArea2D
	var pocket_north := terrain_scene.get_node_or_null(
		"long_shan_tunnel/interior_triggers/LightPocketNorth"
	) as StorySubjectArea2D
	_assert_true(pocket_south != null, "Long Shan includes the first lit pocket cue under the terrain landmark instance")
	_assert_true(pocket_north != null, "Long Shan includes the second lit pocket cue under the terrain landmark instance")
	if pocket_north != null:
		_assert_true(pocket_north.subject_id == "landmark:long_shan_tunnel.light_pocket_north", "Long Shan second pocket resolves through a generic story subject id")

	var harbor_refrain := terrain_scene.get_node_or_null(
		"ground/buildings/piano_ferry/HarborRefrain"
	) as StorySubjectArea2D
	var festival_stage := terrain_scene.get_node_or_null(
		"ground/buildings/piano_ferry/FestivalStage"
	) as StorySubjectArea2D
	_assert_true(harbor_refrain != null, "Piano Ferry includes the harbor clue under the terrain landmark instance")
	_assert_true(festival_stage != null, "Piano Ferry includes the festival stage trigger under the terrain landmark instance")
	if harbor_refrain != null:
		_assert_true(harbor_refrain.subject_id == "landmark:piano_ferry.harbor_refrain", "Piano Ferry harbor clue resolves through a generic story subject id")
	if festival_stage != null:
		_assert_true(festival_stage.subject_id == "landmark:festival_stage.harbor_stage", "Festival stage resolves through a generic story subject id")

	var synthesis_chamber := terrain_scene.get_node_or_null(
		"ground/buildings/BaguaTower/SynthesisChamber"
	) as StorySubjectArea2D
	var bagua_roof_level := terrain_scene.get_node_or_null(
		"ground/buildings/BaguaTower/base/ground_level/upper_level/roof_level"
	)
	_assert_true(synthesis_chamber != null, "Bagua Tower includes the synthesis chamber under the terrain landmark instance")
	_assert_true(bagua_roof_level != null, "Bagua Tower terrain instance exposes the roof level for level-aware triggers")
	if synthesis_chamber != null:
		_assert_true(
			synthesis_chamber.level_context_path == NodePath("../base/ground_level/upper_level/roof_level"),
			"Bagua synthesis chamber resolves its level from the roof-level node inside the packed tower scene"
		)
		_assert_true(
			synthesis_chamber.sync_z_index_to_resolved_level,
			"Bagua synthesis chamber keeps its z index synced to the resolved roof level"
		)
		if bagua_roof_level != null and bagua_roof_level.has_method("get_resolved_level_id"):
			_assert_true(
				synthesis_chamber.get_resolved_level_id() == int(bagua_roof_level.call("get_resolved_level_id")),
				"Bagua synthesis chamber resolves to the same level as the tower roof"
			)
			_assert_true(
				synthesis_chamber.z_index == int(bagua_roof_level.call("get_resolved_level_id")),
				"Bagua synthesis chamber syncs its z index to the resolved roof level"
			)
	terrain_scene.free()

	var inspector_subject := StorySubjectArea2D.new()
	var subject_property := _get_property_info(inspector_subject, "subject_id")
	_assert_true(
		String(subject_property.get("hint_string", "")).contains("landmark:trinity_church.steps"),
		"StorySubjectArea2D subject_id dropdown comes from the shared StoryEvent world-subject catalog"
	)
	_assert_true(
		String(subject_property.get("hint_string", "")).contains("landmark:bi_shan_tunnel.echo_a"),
		"StorySubjectArea2D subject_id dropdown includes tunnel cue subjects"
	)
	_assert_true(
		String(subject_property.get("hint_string", "")).contains("inspectable:church_stone_bench"),
		"StorySubjectArea2D subject_id dropdown also includes scene-authored inspect subjects"
	)
	inspector_subject.free()

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


func _get_property_info(object: Object, property_name: String) -> Dictionary:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return property
	return {}


func _find_subject_areas_with_prefix(root: Node, prefix: String) -> Array[StorySubjectArea2D]:
	var matches: Array[StorySubjectArea2D] = []
	if root == null:
		return matches
	for node in root.find_children("*", "StorySubjectArea2D", true, false):
		var subject_area := node as StorySubjectArea2D
		if subject_area == null:
			continue
		if !subject_area.subject_id.begins_with(prefix):
			continue
		matches.append(subject_area)
	return matches


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
