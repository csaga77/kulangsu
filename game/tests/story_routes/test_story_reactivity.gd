extends Node2D

const TEST_AUTOSAVE_PATH := "user://story_reactivity_test.save"
const APP_RUNTIME := preload("res://game/app_runtime.gd")

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
	_app_state().interact_with_resident("tea_vendor_hua")
	_app_state().interact_with_resident("ferry_caretaker")
	var hua_after: Dictionary = _app_state().interact_with_resident("tea_vendor_hua")
	_assert_true(
		String(hua_after.get("line", "")).to_lower().contains("extra cup"),
		"Tea Vendor Hua reflects the Spring Festival aftermath after the harbor resolution"
	)

	_app_state().configure_new_game()
	_progress_to_future_choice()
	var lin_after: Dictionary = _app_state().interact_with_resident("choir_student_lin")
	_assert_true(
		String(lin_after.get("line", "")).to_lower().contains("belongs to the singer"),
		"Choir Student Lin reacts once the future choice has been named honestly"
	)
	_app_state().interact_with_resident("dock_musician_pei")
	var jun_after: Dictionary = _app_state().interact_with_resident("ferry_porter_jun")
	_assert_true(
		String(jun_after.get("line", "")).to_lower().contains("second summer"),
		"Ferry Porter Jun reacts once the exam route opens into second summer"
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
	var an_after: Dictionary = _app_state().interact_with_resident("postcard_seller_an")
	_assert_true(
		String(an_after.get("line", "")).to_lower().contains("little rectangles"),
		"Postcard Seller An reacts after the Bagua preservation perspective lands"
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
	_app_state().activate_landmark_trigger("piano_ferry", "harbor_refrain", "Harbor Clue")
	_app_state().interact_with_resident("ferry_caretaker")


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


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
