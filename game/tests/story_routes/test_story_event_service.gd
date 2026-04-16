extends Node2D

const TEST_AUTOSAVE_PATH := "user://story_event_service_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const GAME_MAIN_SCENE := preload("res://scenes/game_main.tscn")

var m_failures := PackedStringArray()


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_app_state().override_story_autosave_path_for_tests(TEST_AUTOSAVE_PATH)
	_app_state().clear_story_autosave_for_tests()

	_app_state().configure_new_game()
	var lian_intro: Dictionary = _app_state().activate_story_subject("npc:ferry_caretaker", "talk")
	_assert_true(
		String(lian_intro.get("line", "")).to_lower().contains("old piano crate"),
		"StoryEvent talk activation routes ferry caretaker dialogue through the generic subject API"
	)
	_assert_true(
		int(_app_state().get_resident_profile("ferry_caretaker").get("conversation_index", 0)) == 1,
		"StoryEvent talk activation still advances resident progress"
	)

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
	_app_state().activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().activate_story_subject("npc:ferry_caretaker", "talk")


func _progress_to_winter_memory_via_story_subjects() -> void:
	_progress_through_ferry_opening()
	_app_state().activate_story_subject("npc:dock_musician_pei", "talk")
	_app_state().activate_story_subject("npc:postcard_seller_an", "talk")
	_app_state().activate_story_subject("npc:choir_student_lin", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")
	_app_state().activate_story_subject("npc:church_caretaker", "talk")


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
