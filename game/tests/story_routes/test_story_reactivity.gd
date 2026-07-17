extends Node

const TEST_AUTOSAVE_PATH := "user://story_reactivity_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")
const GAME_WORLD_3D_SCENE := preload("res://scenes/game_world_3d.tscn")
const STORY_SUBJECT_3D_SCRIPT := preload("res://game/story_subject_3d.gd")

# Subject nodes authored directly inside scenes/game_world_3d.tscn. Keep in
# sync with the Landmarks/*Proxy/Subject nodes.
const AUTHORED_WORLD_SUBJECTS := {
	"Landmarks/PianoFerryProxy/Subject": "landmark:piano_ferry.harbor_refrain",
	"Landmarks/TrinityChurchProxy/Subject": "landmark:trinity_church.steps",
	"Landmarks/BiShanTunnelProxy/Subject": "landmark:bi_shan_tunnel.echo_a",
	"Landmarks/LongShanTunnelProxy/Subject": "landmark:long_shan_tunnel.tunnel_entry",
	"Landmarks/BaguaTowerProxy/Subject": "landmark:bagua_tower.synthesis_chamber",
}

var m_failures := PackedStringArray()
var m_app_state: AppStateService


func _app_state() -> AppStateService:
	return m_app_state


func _ready() -> void:
	m_app_state = AppStateService.new(StorySaveRepository.new(TEST_AUTOSAVE_PATH))
	m_app_state.name = "AppState"
	add_child(m_app_state)
	call_deferred("_run")


func _run() -> void:
	_app_state().clear_story_save()

	_app_state().start_new_story()
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

	_app_state().start_new_story()
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

	_app_state().start_new_story()
	_progress_through_ferry_opening()
	_app_state().interact_with_resident("dock_musician_pei")
	_app_state().interact_with_resident("postcard_seller_an")
	_app_state().apply_story_effects({"unlock_landmark": "bagua_tower"})
	_app_state().interact_with_resident("terrace_painter_nian")
	var jia_after: Dictionary = _app_state().interact_with_resident("map_student_jia")
	_assert_true(
		String(jia_after.get("line", "")).to_lower().contains("custody"),
		"Map Student Jia reacts once Bagua turns preservation into responsibility"
	)
	_assert_story_subjects_are_authored_in_world("entrusted")
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

	_app_state().clear_story_save()

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


# Regression guard for scene-authored story subjects in the production 3D
# overworld. The world scene is instantiated without entering the tree, so the
# authored node structure is checked without paying for a full terrain build;
# live proximity/dispatch behavior is owned by scenes/tests/test_game_world_3d.gd.
func _assert_story_subjects_are_authored_in_world(expected_bagua_fragment: String) -> void:
	var world := GAME_WORLD_3D_SCENE.instantiate()

	for node_path in AUTHORED_WORLD_SUBJECTS:
		var expected_subject_id: String = AUTHORED_WORLD_SUBJECTS[node_path]
		var subject := world.get_node_or_null(node_path)
		_assert_true(
			subject != null and subject.get_script() == STORY_SUBJECT_3D_SCRIPT,
			"Story subject is authored in game_world_3d at %s" % node_path
		)
		if subject == null:
			continue
		_assert_true(
			String(subject.get("subject_id")) == expected_subject_id,
			"Authored subject at %s carries the stable id %s" % [node_path, expected_subject_id]
		)
		var metadata: Dictionary = _app_state().describe_story_subject_metadata(
			expected_subject_id, {}
		)
		_assert_true(
			!metadata.is_empty(),
			"Authored subject id %s resolves through the shared StoryEvent metadata path" % expected_subject_id
		)

	world.free()

	# The route-aware inspect surface itself stays validated at the shared
	# service level (scene-owned dispatch parity is covered by the 3D smoke test).
	var railing_text := String(
		_app_state().activate_story_subject("inspectable:bagua_railings", "inspect").get("text", "")
	)
	_assert_true(
		railing_text.to_lower().contains(expected_bagua_fragment),
		"Bagua Railings inspect text runs through the shared inspectable path"
	)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
