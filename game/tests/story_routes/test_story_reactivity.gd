extends Node2D

const TEST_AUTOSAVE_PATH := "user://story_reactivity_test.save"
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
	_progress_to_winter_memory()
	var qiao_result: Dictionary = _app_state().interact_with_resident("bell_repairer_qiao")
	_assert_true(
		String(qiao_result.get("line", "")).to_lower().contains("brass"),
		"Bell Repairer Qiao reacts once the winter memory reveal lands"
	)
	var lian_result: Dictionary = _app_state().interact_with_resident("ferry_caretaker")
	_assert_true(
		String(lian_result.get("line", "")).to_lower().contains("a po"),
		"Lian now reflects on A Po and the parents once winter memory turns clear"
	)
	var church_bench_text := String(
		_app_state().activate_story_subject("inspectable:church_stone_bench", "inspect").get("text", "")
	)
	_assert_true(
		church_bench_text.to_lower().contains("winter memory"),
		"Church Stone Bench echoes the winter-memory reveal outside resident dialogue"
	)
	_app_state().interact_with_resident("tea_vendor_hua")
	var lanterns_prepared_text := String(
		_app_state().activate_story_subject("inspectable:harbor_lantern_lines", "inspect").get("text", "")
	)
	_assert_true(
		lanterns_prepared_text.to_lower().contains("festival week"),
		"Harbor Lantern Lines react once Spring Festival preparation is underway"
	)
	_app_state().interact_with_resident("ferry_caretaker")
	var hua_after: Dictionary = _app_state().interact_with_resident("tea_vendor_hua")
	_assert_true(
		String(hua_after.get("line", "")).to_lower().contains("extra cup"),
		"Tea Vendor Hua reflects the Spring Festival aftermath after the harbor resolution"
	)
	var lanterns_resolved_text := String(
		_app_state().activate_story_subject("inspectable:harbor_lantern_lines", "inspect").get("text", "")
	)
	_assert_true(
		lanterns_resolved_text.to_lower().contains("wax"),
		"Harbor Lantern Lines keep the Spring Festival aftermath visible after the route resolves"
	)

	_app_state().configure_new_game()
	_progress_to_future_choice()
	var lin_after: Dictionary = _app_state().interact_with_resident("choir_student_lin")
	_assert_true(
		String(lin_after.get("line", "")).to_lower().contains("belongs to the singer"),
		"Choir Student Lin reacts once the future choice has been named honestly"
	)
	var notice_board_choice_text := String(
		_app_state().activate_story_subject("inspectable:harbor_notice_board", "inspect").get("text", "")
	)
	_assert_true(
		notice_board_choice_text.to_lower().contains("sentence"),
		"Harbor Notice Board reacts once the future choice is named"
	)
	_app_state().interact_with_resident("dock_musician_pei")
	var jun_after: Dictionary = _app_state().interact_with_resident("ferry_porter_jun")
	_assert_true(
		String(jun_after.get("line", "")).to_lower().contains("second summer"),
		"Ferry Porter Jun reacts once the exam route opens into second summer"
	)
	var notice_board_exam_text := String(
		_app_state().activate_story_subject("inspectable:harbor_notice_board", "inspect").get("text", "")
	)
	_assert_true(
		notice_board_exam_text.to_lower().contains("second summer"),
		"Harbor Notice Board reflects the quieter second-summer aftermath"
	)

	_app_state().configure_new_game()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().advance_landmark_state("bagua_tower", "available")
	_app_state().refresh_story_routes()
	_app_state().interact_with_resident("terrace_painter_nian")
	var jia_after: Dictionary = _app_state().interact_with_resident("map_student_jia")
	_assert_true(
		String(jia_after.get("line", "")).to_lower().contains("custody"),
		"Map Student Jia reacts once Bagua turns preservation into responsibility"
	)
	await _assert_story_subject_areas_are_authored_in_scene("entrusted")
	var postcard_rack_text := String(
		_app_state().activate_story_subject("inspectable:postcard_display_rack", "inspect").get("text", "")
	)
	_assert_true(
		postcard_rack_text.to_lower().contains("custody"),
		"Postcard Display Rack reacts once preservation turns into inheritance"
	)
	var an_after: Dictionary = _app_state().interact_with_resident("postcard_seller_an")
	_assert_true(
		String(an_after.get("line", "")).to_lower().contains("little rectangles"),
		"Postcard Seller An reacts after the Bagua preservation perspective lands"
	)
	var bagua_railings_text := String(
		_app_state().activate_story_subject("inspectable:bagua_railings", "inspect").get("text", "")
	)
	_assert_true(
		bagua_railings_text.to_lower().contains("entrusted"),
		"Bagua Railings carry the preservation perspective onto a non-resident surface"
	)

	_app_state().clear_story_autosave_for_tests()

	if m_failures.is_empty():
		print("PASS: story route reactivity")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Story route reactivity failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _progress_through_ferry_opening() -> void:
	_app_state().interact_with_resident("ferry_caretaker")
	_activate_landmark_subject("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")


func _activate_landmark_subject(landmark_id: String, trigger_id: String, display_name: String) -> bool:
	var subject_id := "landmark:%s.%s" % [landmark_id, trigger_id]
	var context := {"display_name": display_name}
	var metadata: Dictionary = _app_state().describe_story_subject_metadata(subject_id, context)
	var action := String(metadata.get("action", "")).strip_edges().to_lower()
	if action.is_empty():
		action = "inspect"
	var result: Dictionary = _app_state().activate_story_subject(subject_id, action, context)
	return bool(result.get("consumed", false))


func _progress_to_winter_memory() -> void:
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().interact_with_resident("choir_student_lin")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")


func _progress_to_future_choice() -> void:
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().interact_with_resident("choir_student_lin")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("church_caretaker")
	_app_state().interact_with_resident("tea_vendor_hua")
	_app_state().interact_with_resident("ferry_caretaker")
	_app_state().interact_with_resident("dock_musician_pei")


func _assert_story_subject_areas_are_authored_in_scene(expected_bagua_fragment: String) -> void:
	var game_main := GAME_MAIN_SCENE.instantiate()
	add_child(game_main)
	await get_tree().process_frame

	var harbor_lantern_lines := game_main.get_node_or_null(
		"terrain/ground/buildings/piano_ferry/HarborLanternLines"
	) as StorySubjectArea2D
	_assert_true(
		harbor_lantern_lines != null,
		"Harbor Lantern Lines are authored in the Piano Ferry scene"
	)

	var church_stone_bench := game_main.get_node_or_null(
		"terrain/ground/buildings/TrinityChurch/ChurchStoneBench"
	) as StorySubjectArea2D
	_assert_true(
		church_stone_bench != null,
		"Church Stone Bench is authored in the Trinity Church scene"
	)

	var bagua_upper_level := game_main.get_node_or_null(
		"terrain/ground/buildings/BaguaTower/base/ground_level/upper_level"
	) as Node2D
	_assert_true(
		bagua_upper_level != null,
		"Bagua upper level is available for scene-owned inspectable checks"
	)

	var bagua_railings := game_main.get_node_or_null(
		"terrain/ground/buildings/BaguaTower/base/ground_level/upper_level/BaguaRailings"
	) as StorySubjectArea2D
	_assert_true(
		bagua_railings != null,
		"Bagua Railings are authored in the Bagua upper level scene"
	)

	var player := game_main.get_node_or_null("actors/player") as HumanBody2D
	var player_controller := player.controller as PlayerController if player != null else null
	_assert_true(
		player_controller != null,
		"GameMain exposes the player controller for inspect integration checks"
	)

	if bagua_upper_level != null and bagua_railings != null and player != null and player_controller != null:
		_assert_true(
			CommonUtils.get_absolute_z_index(bagua_railings) == CommonUtils.get_absolute_z_index(bagua_upper_level),
			"Bagua Railings share the Bagua upper-level interaction layer"
		)
		LevelRegistry.apply_level_to_actor(bagua_railings.get_resolved_level_id(), player)
		player.global_position = bagua_railings.global_position
		player_controller._on_body_entered(bagua_railings)
		player_controller._process(0.0)
		player_controller.inspect_requested.emit()
		_assert_true(
			_app_state().save_status.to_lower().contains(expected_bagua_fragment),
			"Bagua Railings inspect text runs through the scene-owned inspectable path"
		)

	game_main.queue_free()
	await get_tree().process_frame


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
