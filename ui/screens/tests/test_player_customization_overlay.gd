extends Node

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const PLAYER_APPEARANCE_CATALOG := preload("res://game/player_appearance_catalog.gd")
const PLAYER_COSTUME_CATALOG := preload("res://game/player_costume_catalog.gd")
const PLAYER_SETUP_SCENE := preload("res://ui/screens/player_customization_overlay.tscn")

var m_failures := PackedStringArray()
var m_cancel_requested := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var app_state = APP_RUNTIME.get_app_state(self)
	app_state.configure_free_walk()
	await get_tree().process_frame

	var base_profile := PLAYER_APPEARANCE_CATALOG.default_profile()
	_assert_true("Free walk unlocks the festival costume for test setup", app_state.equip_player_costume("festival_evening"))
	app_state.set_player_profile(base_profile)
	_assert_dict_equal("Base profile is active before opening setup", app_state.get_player_profile(), base_profile)

	var overlay := PLAYER_SETUP_SCENE.instantiate()
	add_child(overlay)
	overlay.connect("cancel_requested", func() -> void:
		m_cancel_requested = true
	)
	await get_tree().process_frame

	overlay.call("set_flow_context", false)
	overlay.call("refresh_from_state")
	await get_tree().process_frame

	var summary_label := overlay.get_node("Margin/Body/Content/PreviewColumn/Summary") as Label
	var body_value := overlay.get_node("Margin/Body/Content/ControlsColumn/BodyRow/Controls/Value") as Label
	var body_next_button := overlay.get_node("Margin/Body/Content/ControlsColumn/BodyRow/Controls/NextButton") as Button
	var cancel_button := overlay.get_node("Margin/Body/Footer/CancelButton") as Button
	var confirm_button := overlay.get_node("Margin/Body/Footer/ConfirmButton") as Button

	_assert_contains(
		"Setup preview always shows the default starting costume",
		summary_label.text,
		"Starting look: Harbor Arrival"
	)
	_assert_equal("Initial body label matches the live profile", body_value.text, "Adult")

	body_next_button.emit_signal("pressed")
	await get_tree().process_frame
	_assert_equal("Browsing body options only changes the setup draft", body_value.text, "Teen")
	_assert_dict_equal("Browsing setup options does not mutate AppState immediately", app_state.get_player_profile(), base_profile)
	_assert_equal(
		"Browsing setup options does not change the equipped live costume",
		app_state.get_equipped_player_costume_id(),
		"festival_evening"
	)

	cancel_button.emit_signal("pressed")
	await get_tree().process_frame
	_assert_true("Cancel still emits the setup cancellation signal", m_cancel_requested)
	_assert_dict_equal("Cancel leaves the live player profile untouched", app_state.get_player_profile(), base_profile)

	overlay.call("refresh_from_state")
	await get_tree().process_frame
	_assert_equal("Reopening setup restores the live body value", body_value.text, "Adult")

	body_next_button.emit_signal("pressed")
	await get_tree().process_frame
	confirm_button.emit_signal("pressed")
	await get_tree().process_frame

	var committed_profile: Dictionary = app_state.get_player_profile()
	_assert_equal("Confirm commits the setup draft into AppState", String(committed_profile.get("body_frame_id", "")), "teen")
	_assert_equal(
		"Confirm resets the equipped costume to the default starting look",
		app_state.get_equipped_player_costume_id(),
		PLAYER_COSTUME_CATALOG.default_costume_id()
	)

	if m_failures.is_empty():
		print("PASS: player customization overlay regression")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Player customization overlay regression failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected true, got false." % label)


func _assert_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])


func _assert_contains(label: String, text: String, expected_fragment: String) -> void:
	if text.contains(expected_fragment):
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected `%s` to contain `%s`." % [label, text, expected_fragment])


func _assert_dict_equal(label: String, actual: Dictionary, expected: Dictionary) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, str(expected), str(actual)])
