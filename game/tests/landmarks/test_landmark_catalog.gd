extends Node

const LANDMARK_CATALOG_SCRIPT := preload("res://game/landmarks/landmark_catalog.gd")

const EXPECTED_LANDMARK_IDS := [
	"piano_ferry",
	"trinity_church",
	"bi_shan_tunnel",
	"long_shan_tunnel",
	"bagua_tower",
	"festival_stage",
]
const EXPECTED_WORLD_NAMES := [
	"Piano Ferry",
	"Trinity Church",
	"Bi Shan Tunnel",
	"Long Shan Tunnel",
	"Bagua Tower",
]

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var validation_warnings := LANDMARK_CATALOG_SCRIPT.validate()
	_assert_true(
		validation_warnings.is_empty(),
		"catalog validates without warnings: %s" % "; ".join(validation_warnings)
	)
	_assert_equal(
		LANDMARK_CATALOG_SCRIPT.landmark_ids(),
		PackedStringArray(EXPECTED_LANDMARK_IDS),
		"catalog order"
	)
	_assert_equal(
		LANDMARK_CATALOG_SCRIPT.world_display_names(),
		PackedStringArray(EXPECTED_WORLD_NAMES),
		"world navigation names"
	)

	var default_resume := LANDMARK_CATALOG_SCRIPT.default_resume_definition()
	_assert_true(default_resume != null, "default resume definition exists")
	if default_resume != null:
		_assert_equal(default_resume.id, &"piano_ferry", "default resume id")
		_assert_equal(default_resume.display_name, "Piano Ferry", "default resume display name")

	var new_game := LANDMARK_CATALOG_SCRIPT.build_progress(&"new_game")
	var continued := LANDMARK_CATALOG_SCRIPT.build_progress(&"continue")
	var free_walk := LANDMARK_CATALOG_SCRIPT.build_progress(&"free_walk")
	_assert_equal(new_game["piano_ferry"]["state"], "available", "new game ferry state")
	_assert_equal(continued["trinity_church"]["state"], "reward_collected", "continue church state")
	_assert_equal(
		continued["trinity_church"]["cues_collected"],
		["steps", "garden", "yard"],
		"continue church cues"
	)
	_assert_equal(free_walk["bagua_tower"]["state"], "available", "free walk tower state")

	new_game["piano_ferry"]["state"] = "mutated_by_test"
	_assert_equal(
		LANDMARK_CATALOG_SCRIPT.build_progress(&"new_game")["piano_ferry"]["state"],
		"available",
		"progress profiles return deep copies"
	)

	for cue_id in LANDMARK_CATALOG_SCRIPT.audio_cue_ids():
		var stream := LANDMARK_CATALOG_SCRIPT.get_audio_cue(StringName(cue_id))
		_assert_true(stream != null, "%s audio cue exists" % cue_id)
		_assert_true(stream != null and stream.get_length() > 0.0, "%s audio cue has duration" % cue_id)

	if m_failures.is_empty():
		print("PASS: landmark catalog contract")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Landmark catalog contract failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected %s, got %s." % [label, expected, actual])


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected true, got false." % label)
