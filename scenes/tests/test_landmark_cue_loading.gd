extends Node

const LANDMARK_CATALOG_SCRIPT := preload("res://game/landmarks/landmark_catalog.gd")

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_true("landmark catalog validates", LANDMARK_CATALOG_SCRIPT.validate().is_empty())
	for cue_id in LANDMARK_CATALOG_SCRIPT.audio_cue_ids():
		var stream := LANDMARK_CATALOG_SCRIPT.get_audio_cue(StringName(cue_id))
		_assert_true("%s is assigned in landmark catalog" % cue_id, stream != null)
		_assert_true("%s reports a positive duration" % cue_id, stream != null and stream.get_length() > 0.0)
		var repeated_stream := LANDMARK_CATALOG_SCRIPT.get_audio_cue(StringName(cue_id))
		_assert_true("%s reuses the catalog resource instance" % cue_id, repeated_stream == stream)

	if m_failures.is_empty():
		print("PASS: landmark cue loading validation")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Landmark cue loading validation failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s. Expected true, got false." % label)
