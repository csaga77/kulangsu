extends Node2D

const TEST_AUTOSAVE_PATH := "user://story_event_service_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const GAME_MAIN_SCENE := preload("res://scenes/game_main.tscn")
const StorySubjectArea2D = preload("res://game/story_subject_area.gd")

var m_failures := PackedStringArray()
var m_prompt_requests: Array[Dictionary] = []


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if !_app_state().melody_prompt_requested.is_connected(_on_melody_prompt_requested):
		_app_state().melody_prompt_requested.connect(_on_melody_prompt_requested)

	_app_state().override_story_autosave_path_for_tests(TEST_AUTOSAVE_PATH)
	_app_state().clear_story_autosave_for_tests()

	_app_state().configure_new_game()
	var harbor_trigger := StorySubjectArea2D.new()
	harbor_trigger.subject_id = "landmark:piano_ferry.harbor_refrain"
	_assert_true(
		harbor_trigger.get_story_subject_id() == "landmark:piano_ferry.harbor_refrain",
		"StorySubjectArea2D keeps a stable world subject id"
	)
	_assert_true(
		harbor_trigger.get_story_action() == "collect",
		"StorySubjectArea2D resolves the default collect action from StoryEvent metadata"
	)
	var choir_trigger := StorySubjectArea2D.new()
	choir_trigger.subject_id = "landmark:trinity_church.choir_chime"
	_assert_true(
		choir_trigger.get_story_action() == "perform",
		"StorySubjectArea2D resolves the default perform action from StoryEvent metadata"
	)
	harbor_trigger.free()
	choir_trigger.free()

	var lian_intro: Dictionary = _app_state().activate_story_subject("npc:ferry_caretaker", "talk")
	_assert_true(
		String(lian_intro.get("line", "")).to_lower().contains("old piano crate"),
		"StoryEvent talk activation routes ferry caretaker dialogue through the generic subject API"
	)
	_assert_true(
		int(_app_state().get_resident_profile("ferry_caretaker").get("conversation_index", 0)) == 1,
		"StoryEvent talk activation still advances resident progress"
	)

	_app_state().configure_new_game()
	m_prompt_requests.clear()
	_progress_through_landmark_spine_via_story_subjects()

	_app_state().configure_new_game()
	_progress_to_winter_memory_via_story_subjects()
	var bench_preview: Dictionary = _app_state().describe_story_subject("inspectable:church_stone_bench", "inspect")
	_assert_true(
		String(bench_preview.get("text", "")).to_lower().contains("winter memory"),
		"StoryEvent inspect description resolves route-aware inspect text"
	)
	var bench_activation: Dictionary = _app_state().activate_story_subject("inspectable:church_stone_bench", "inspect")
	_assert_true(
		String(bench_activation.get("text", "")).to_lower().contains("winter memory"),
		"StoryEvent inspect activation resolves the same route-aware inspect text"
	)

	_app_state().configure_new_game()
	var game_main := GAME_MAIN_SCENE.instantiate()
	add_child(game_main)
	await get_tree().process_frame

	var lian_actor := _find_resident_actor(game_main, "ferry_caretaker")
	var trinity_anchor := game_main.get_node_or_null("terrain/ground/buildings/TrinityChurch") as Node2D
	var ferry_anchor := game_main.get_node_or_null("terrain/ground/buildings/piano_ferry") as Node2D
	_assert_true(lian_actor != null, "GameMain exposes ferry caretaker for routine-override validation")
	_assert_true(trinity_anchor != null, "Trinity Church anchor exists for runtime routine overrides")
	_assert_true(ferry_anchor != null, "Piano Ferry anchor exists for runtime routine overrides")

	if lian_actor != null and trinity_anchor != null and ferry_anchor != null:
		var original_position := lian_actor.global_position
		_app_state().set_resident_routine_override("ferry_caretaker", {
			"spawn": {
				"anchor_id": "Trinity Church",
			},
		})
		await get_tree().process_frame

		var override_spawn: Dictionary = _app_state().get_resident_spawn_config("ferry_caretaker")
		var expected_override: Vector2 = game_main.call(
			"_resolve_actor_anchor_position",
			lian_actor,
			trinity_anchor,
			override_spawn.get("offset", Vector2.ZERO)
		)
		_assert_true(
			lian_actor.global_position.distance_to(original_position) > 64.0,
			"Resident routine overrides can move an already spawned resident to a new story-driven anchor"
		)
		_assert_true(
			lian_actor.global_position.distance_to(expected_override) <= 2.0,
			"Resident routine overrides resolve through the shared spawn-anchor pipeline"
		)

		_app_state().clear_resident_routine_override("ferry_caretaker")
		await get_tree().process_frame

		var restored_spawn: Dictionary = _app_state().get_resident_spawn_config("ferry_caretaker")
		var expected_restored: Vector2 = game_main.call(
			"_resolve_actor_anchor_position",
			lian_actor,
			ferry_anchor,
			restored_spawn.get("offset", Vector2.ZERO)
		)
		_assert_true(
			lian_actor.global_position.distance_to(expected_restored) <= 2.0,
			"Clearing a resident routine override restores the resident's base authored spawn route"
		)

	game_main.queue_free()
	await get_tree().process_frame
	_app_state().clear_story_autosave_for_tests()

	if m_failures.is_empty():
		print("PASS: story event service flow")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Story event service flow failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _progress_through_ferry_opening() -> void:
	_app_state().activate_story_subject("npc:ferry_caretaker", "talk")
	var harbor_result: Dictionary = _app_state().activate_story_subject(
		"landmark:piano_ferry.harbor_refrain",
		"collect",
		{"display_name": "Harbor Clue"}
	)
	_assert_true(
		bool(harbor_result.get("consumed", false)),
		"StoryEvent landmark activation routes the harbor refrain through the generic subject API"
	)
	_app_state().activate_story_subject("npc:ferry_caretaker", "talk")


func _progress_to_winter_memory_via_story_subjects() -> void:
	_progress_through_ferry_opening()
	_app_state().activate_story_subject("npc:dock_musician_pei", "talk")
	_app_state().activate_story_subject("npc:postcard_seller_an", "talk")
	_app_state().activate_story_subject("npc:choir_student_lin", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")


func _progress_through_trinity_church_via_story_subjects() -> void:
	_progress_through_ferry_opening()
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	var steps_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.steps",
		"collect",
		{"display_name": "Stone Steps"}
	)
	_assert_true(
		bool(steps_result.get("consumed", false)),
		"StoryEvent landmark activation collects the first Trinity cue through the generic subject API"
	)
	var garden_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.garden",
		"collect",
		{"display_name": "Side Garden"}
	)
	_assert_true(
		bool(garden_result.get("consumed", false)),
		"StoryEvent landmark activation collects the second Trinity cue through the generic subject API"
	)
	var yard_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.yard",
		"collect",
		{"display_name": "Quiet Yard"}
	)
	_assert_true(
		bool(yard_result.get("consumed", false)),
		"StoryEvent landmark activation collects the final Trinity cue through the generic subject API"
	)
	_assert_true(
		_app_state().get_landmark_progress("trinity_church").get("cues_collected", []).size() == 3,
		"StoryEvent landmark activation updates Trinity cue progress in shared landmark state"
	)

	var prompt_count_before := m_prompt_requests.size()
	var choir_result: Dictionary = _app_state().activate_story_subject(
		"landmark:trinity_church.choir_chime",
		"perform",
		{"display_name": "Choir Chime"}
	)
	_assert_true(
		!bool(choir_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the Trinity choir chime available while the prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == prompt_count_before + 1,
		"StoryEvent landmark activation emits the Trinity choir prompt through the shared melody prompt signal"
	)
	var latest_prompt: Dictionary = {}
	if m_prompt_requests.size() > 0:
		latest_prompt = m_prompt_requests[m_prompt_requests.size() - 1]
	_assert_true(
		String(latest_prompt.get("completion_kind", "")) == "trinity_chime",
		"StoryEvent landmark activation emits the authored Trinity choir prompt payload"
	)


func _progress_through_landmark_spine_via_story_subjects() -> void:
	_progress_through_trinity_church_via_story_subjects()
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_assert_true(
		_app_state().fragments_found == 1,
		"StoryEvent landmark prompt completion still leaves Trinity reward resolution intact"
	)

	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:bi_shan_tunnel.echo_a",
			"collect",
			{"display_name": "North Wall Echo"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the first Bi Shan echo through the generic subject API"
	)
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:bi_shan_tunnel.echo_b",
			"collect",
			{"display_name": "Arch Midpoint"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the second Bi Shan echo through the generic subject API"
	)
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:bi_shan_tunnel.echo_c",
			"collect",
			{"display_name": "Mural Approach"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the final Bi Shan echo through the generic subject API"
	)

	var bi_shan_prompt_count := m_prompt_requests.size()
	var chamber_result: Dictionary = _app_state().activate_story_subject(
		"landmark:bi_shan_tunnel.chamber",
		"collect",
		{"display_name": "Mural Chamber"}
	)
	_assert_true(
		!bool(chamber_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the Bi Shan chamber available while the prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == bi_shan_prompt_count + 1,
		"StoryEvent landmark activation emits the Bi Shan chamber prompt through the shared melody prompt signal"
	)
	_assert_true(
		String(m_prompt_requests[m_prompt_requests.size() - 1].get("completion_kind", "")) == "bi_shan_chamber",
		"StoryEvent landmark activation emits the authored Bi Shan chamber prompt payload"
	)
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(
		_app_state().fragments_found == 2,
		"StoryEvent landmark prompt completion still resolves the Bi Shan reward path"
	)

	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:long_shan_tunnel.tunnel_entry",
			"collect",
			{"display_name": "Long Shan Entry"}
		).get("consumed", false)),
		"StoryEvent landmark activation routes the Long Shan entry through the generic subject API"
	)
	_app_state().activate_story_subject("npc:tunnel_guide", "talk")
	_app_state().activate_story_subject("npc:tunnel_guide", "talk")
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:long_shan_tunnel.light_pocket_south",
			"collect",
			{"display_name": "South Lit Pocket"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the first Long Shan checkpoint through the generic subject API"
	)
	_assert_true(
		bool(_app_state().activate_story_subject(
			"landmark:long_shan_tunnel.light_pocket_north",
			"collect",
			{"display_name": "North Lit Pocket"}
		).get("consumed", false)),
		"StoryEvent landmark activation collects the second Long Shan checkpoint through the generic subject API"
	)

	var long_shan_prompt_count := m_prompt_requests.size()
	var exit_result: Dictionary = _app_state().activate_story_subject(
		"landmark:long_shan_tunnel.tunnel_exit",
		"collect",
		{"display_name": "Tunnel Exit"}
	)
	_assert_true(
		!bool(exit_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the Long Shan exit available while the prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == long_shan_prompt_count + 1,
		"StoryEvent landmark activation emits the Long Shan route prompt through the shared melody prompt signal"
	)
	_assert_true(
		String(m_prompt_requests[m_prompt_requests.size() - 1].get("completion_kind", "")) == "long_shan_route",
		"StoryEvent landmark activation emits the authored Long Shan route prompt payload"
	)
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_app_state().activate_story_subject("npc:tunnel_guide", "talk")
	_assert_true(
		_app_state().get_landmark_state("bagua_tower") == "available",
		"StoryEvent landmark prompt completion still leaves Ren's Bagua handoff intact"
	)

	_app_state().activate_story_subject("npc:tower_keeper", "talk")
	_app_state().activate_story_subject("npc:tower_keeper", "talk")
	var bagua_result: Dictionary = _app_state().activate_story_subject(
		"landmark:bagua_tower.synthesis_chamber",
		"collect",
		{"display_name": "Synthesis Chamber"}
	)
	_assert_true(
		bool(bagua_result.get("consumed", false)),
		"StoryEvent landmark activation routes the Bagua synthesis chamber through the generic subject API"
	)
	_assert_true(
		bool(_app_state().get_landmark_progress("bagua_tower").get("synthesis_done", false)),
		"StoryEvent landmark activation writes Bagua synthesis progress through shared landmark state"
	)
	_app_state().activate_story_subject("npc:tower_keeper", "talk")
	_assert_true(
		_app_state().get_landmark_state("festival_stage") == "locked",
		"StoryEvent landmark migration keeps the festival stage gated behind Spring Festival resolution"
	)

	_app_state().activate_story_subject("npc:dock_musician_pei", "talk")
	_app_state().activate_story_subject("npc:postcard_seller_an", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_app_state().activate_story_subject("npc:tea_vendor_hua", "talk")
	_app_state().activate_story_subject("npc:ferry_caretaker", "talk")
	_assert_true(
		bool(_app_state().get_story_flag("spring_festival_resolved", false)),
		"StoryEvent landmark migration still fits the existing Spring Festival resolution path"
	)
	_assert_true(
		_app_state().get_landmark_state("festival_stage") == "available",
		"StoryEvent landmark migration still unlocks the harbor stage once melody and Spring Festival are ready"
	)

	var festival_prompt_count := m_prompt_requests.size()
	var festival_result: Dictionary = _app_state().activate_story_subject(
		"landmark:festival_stage.harbor_stage",
		"perform",
		{"display_name": "Festival Stage"}
	)
	_assert_true(
		!bool(festival_result.get("consumed", true)),
		"StoryEvent landmark activation keeps the festival stage available while the harbor prompt is open"
	)
	_assert_true(
		m_prompt_requests.size() == festival_prompt_count + 1,
		"StoryEvent landmark activation emits the harbor-stage melody prompt through the shared melody prompt builder"
	)
	_assert_true(
		String(m_prompt_requests[m_prompt_requests.size() - 1].get("completion_kind", "")) == "festival_performance",
		"StoryEvent landmark activation emits the live festival-performance prompt payload"
	)
	_app_state().complete_prompt_request(m_prompt_requests[m_prompt_requests.size() - 1])
	_assert_true(
		bool(_app_state().get_melody_state("festival_melody").get("performed", false)),
		"StoryEvent landmark prompt completion still resolves the harbor-stage performance path"
	)


func _find_resident_actor(game_main: Node, resident_id: String) -> HumanBody2D:
	var resident_root := game_main.get_node_or_null("actors/Residents")
	if resident_root == null:
		return null
	for child in resident_root.get_children():
		var resident := child as HumanBody2D
		if resident == null:
			continue
		var controller := resident.controller as NPCController
		if controller == null:
			continue
		if controller.get_resident_id() == resident_id:
			return resident
	return null


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)


func _on_melody_prompt_requested(request: Dictionary) -> void:
	m_prompt_requests.append(request.duplicate(true))
