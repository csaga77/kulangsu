extends Node2D

const GAME_SCENE: PackedScene = preload("res://scenes/game_main.tscn")
const TEST_AUTOSAVE_PATH := "user://story_autosave_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")

var m_failures := PackedStringArray()


func _app_state():
	return APP_RUNTIME.get_app_state(self)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_app_state().override_story_autosave_path_for_tests(TEST_AUTOSAVE_PATH)
	_app_state().clear_story_autosave_for_tests()

	_assert_true(!_app_state().has_story_autosave(), "Test autosave path starts empty")

	_app_state().configure_new_game()
	_assert_true(_app_state().has_story_autosave(), "New game writes the first story autosave")
	_assert_true(_app_state().get_story_save_metadata().get("resume_location", "") == "Piano Ferry", "New game metadata points to Piano Ferry")

	_app_state().interact_with_resident("ferry_caretaker")
	_activate_landmark_subject("piano_ferry", "harbor_refrain", "Harbor Refrain")
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().set_story_resume_checkpoint("Trinity Church", "Trinity Church")
	_app_state().apply_story_effects({"advance_time": {"advance_to_time_of_day": "evening"}})
	_app_state().save_story_autosave()

	var metadata = _app_state().get_story_save_metadata()
	_assert_true(bool(metadata.get("exists", false)), "Story autosave metadata reports an available save")
	_assert_true(String(metadata.get("resume_location", "")) == "Trinity Church", "Story autosave metadata keeps the saved resume location")

	_app_state().configure_free_walk()
	_assert_true(_app_state().mode == "Free Walk", "Free Walk can replace live runtime state before Continue")

	_assert_true(_app_state().configure_continue(), "Continue loads the story autosave")
	_assert_true(_app_state().mode == "Story", "Continue restores story mode")
	_assert_true(_app_state().is_journal_unlocked(), "Continue restores the unlocked journal state")
	_assert_true(_app_state().get_landmark_state("piano_ferry") == "reward_collected", "Continue restores ferry onboarding progress")
	_assert_true(_app_state().get_landmark_state("trinity_church") == "available", "Continue restores the next unlocked landmark")
	_assert_true(_app_state().get_story_resume_anchor_id() == "Trinity Church", "Continue restores the saved resume anchor")
	_assert_true(_app_state().get_story_resume_location() == "Trinity Church", "Continue restores the saved resume location label")
	_assert_true(_app_state().get_story_day() == 1, "Continue restores the saved story day")
	_assert_true(_app_state().get_time_of_day() == "evening", "Continue restores the saved time of day")

	var story_scene := GAME_SCENE.instantiate()
	add_child(story_scene)
	await get_tree().process_frame

	var player := story_scene.get_node("actors/player") as Node2D
	var trinity_anchor := story_scene.get_node("terrain/ground/buildings/TrinityChurch") as Node2D
	var expected_position: Vector2 = story_scene.call("_resolve_actor_anchor_position", player, trinity_anchor, Vector2.ZERO)
	_assert_true(player.global_position.distance_to(expected_position) <= 1.0, "GameMain places the player at the saved Trinity resume anchor")
	story_scene.queue_free()
	await get_tree().process_frame

	_app_state().configure_new_game()
	_app_state().interact_with_resident("ferry_caretaker")
	_activate_landmark_subject("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_activate_landmark_subject("trinity_church", "steps", "Steps")
	_activate_landmark_subject("trinity_church", "garden", "Garden")
	_activate_landmark_subject("trinity_church", "yard", "Yard")
	_activate_landmark_subject("trinity_church", "choir_chime", "Choir Chime")
	_app_state().complete_prompt_request({"completion_kind": "trinity_chime"})
	_app_state().interact_with_resident("church_caretaker")
	_activate_landmark_subject("bi_shan_tunnel", "echo_a", "Echo A")
	_activate_landmark_subject("bi_shan_tunnel", "echo_b", "Echo B")
	_activate_landmark_subject("bi_shan_tunnel", "echo_c", "Echo C")
	var chamber_consumed = _activate_landmark_subject("bi_shan_tunnel", "chamber", "Mural Chamber")
	_assert_true(!chamber_consumed, "Bi Shan chamber still waits for prompt confirmation before saving")
	_app_state().complete_prompt_request({"completion_kind": "bi_shan_chamber"})
	_assert_true(_app_state().get_open_shortcuts().find("bi_shan_crossing") >= 0, "Bi Shan records the dependable route before saving")
	_activate_landmark_subject("long_shan_tunnel", "tunnel_entry", "Entry")
	_app_state().interact_with_resident("tunnel_guide")
	_app_state().interact_with_resident("tunnel_guide")
	_activate_landmark_subject("long_shan_tunnel", "light_pocket_south", "Lit Pocket")
	_activate_landmark_subject("long_shan_tunnel", "light_pocket_north", "Lit Pocket")
	var exit_consumed = _activate_landmark_subject("long_shan_tunnel", "tunnel_exit", "Exit")
	_assert_true(!exit_consumed, "Long Shan exit still waits for prompt confirmation before saving")
	_app_state().complete_prompt_request({"completion_kind": "long_shan_route"})
	_app_state().interact_with_resident("tunnel_guide")
	_app_state().interact_with_resident("tower_keeper")
	_app_state().interact_with_resident("tower_keeper")
	_activate_landmark_subject("bagua_tower", "synthesis_chamber", "Synthesis Chamber")
	_app_state().interact_with_resident("tower_keeper")
	_assert_true(_app_state().get_landmark_state("festival_stage") == "locked", "Bagua completion alone does not unlock the festival stage in saves")
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("tea_vendor_hua")
	_app_state().interact_with_resident("ferry_caretaker")
	_assert_true(_app_state().get_landmark_state("festival_stage") == "available", "Spring Festival resolution unlocks the harbor stage once the melody route is complete")
	_app_state().set_story_resume_checkpoint("Piano Ferry", "Festival Stage")
	_app_state().save_story_autosave()

	var saved_before_performance = _app_state().get_story_save_metadata()
	var stage_consumed = _activate_landmark_subject("festival_stage", "harbor_stage", "Festival Stage")
	_assert_true(!stage_consumed, "Festival stage still waits for prompt confirmation before performance save state changes")
	_app_state().complete_prompt_request({
		"melody_id": "festival_melody",
		"completion_kind": "festival_performance",
	})
	_assert_true(bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Festival performance still updates the live story state")

	var saved_after_performance = _app_state().get_story_save_metadata()
	_assert_true(
		String(saved_after_performance.get("resume_location", "")) == String(saved_before_performance.get("resume_location", "")),
		"Festival performance does not overwrite the pre-choice autosave metadata"
	)
	_assert_true(_app_state().configure_continue(), "Continue can still reload the last pre-ending autosave after performance")
	_assert_true(bool(_app_state().get_melody_state("festival_melody").get("performed", false)), "Continue restores the saved harbor performance state")
	_assert_true(bool(_app_state().endgame_state.get("active", false)), "Continue restores the harbor-performance endgame once spring was resolved first")
	_assert_true(String(_app_state().endgame_state.get("trigger_event_id", "")) == "harbor_festival_performed", "Continue preserves the harbor-performance endgame trigger")
	_assert_true(_app_state().get_endgame_behavior() == "continue_story", "Continue preserves the soft-ending classification for harbor performance")
	_assert_true(_app_state().get_open_shortcuts().find("bi_shan_crossing") >= 0, "Continue restores dependable route state")

	_assert_true(_app_state().continue_story_after_endgame(), "Soft endings can be cleared into continued story play")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Continuing after a soft ending removes the active endgame state")
	_assert_true(_app_state().mode == "Story", "Soft ending continuation stays in Story mode")
	_assert_true(_app_state().season_phase == "spring_festival", "Soft ending continuation restores the underlying seasonal phase")
	_assert_true(String(_app_state().get_melody_state("festival_melody").get("state", "")) == "resonant", "Soft ending continuation keeps the harbor melody in a resonant follow-through state")

	_app_state().configure_free_walk()
	_assert_true(_app_state().configure_continue(), "Continue can load a saved continued-story state after a soft ending")
	_assert_true(_app_state().mode == "Story", "Continue restores Story mode after a soft ending was allowed to continue")
	_assert_true(!bool(_app_state().endgame_state.get("active", false)), "Continue does not reopen the ending overlay after a soft ending was already resolved")
	_assert_true(String(_app_state().get_melody_state("festival_melody").get("state", "")) == "resonant", "Continue preserves the resonant melody state from the soft-ending continuation")

	_app_state().clear_story_autosave()
	_assert_true(!_app_state().has_story_autosave(), "Clearing the story autosave removes the saved continue state")
	_assert_true(!_app_state().configure_continue(), "Continue stays unavailable after the story autosave is cleared")

	if m_failures.is_empty():
		print("PASS: story autosave flow")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Story autosave flow failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)


func _activate_landmark_subject(landmark_id: String, trigger_id: String, display_name: String) -> bool:
	var subject_id := "landmark:%s.%s" % [landmark_id, trigger_id]
	var context := {"display_name": display_name}
	var metadata: Dictionary = _app_state().describe_story_subject_metadata(subject_id, context)
	var action := String(metadata.get("action", "")).strip_edges().to_lower()
	if action.is_empty():
		action = "inspect"
	var result: Dictionary = _app_state().activate_story_subject(subject_id, action, context)
	return bool(result.get("consumed", false))
