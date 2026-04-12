extends Node

const LANDMARK_CUE_LOADER_SCRIPT := preload("res://game/landmark_cue_loader.gd")
const LANDMARK_CUE_FILES := {
	"piano_ferry": "res://resources/audio/sfx/landmark_cues/piano_ferry_refrain.ogg",
	"trinity_church": "res://resources/audio/sfx/landmark_cues/trinity_chime.ogg",
	"bi_shan_tunnel": "res://resources/audio/sfx/landmark_cues/bi_shan_echo.ogg",
	"long_shan_tunnel": "res://resources/audio/sfx/landmark_cues/long_shan_route.ogg",
	"bagua_tower": "res://resources/audio/sfx/landmark_cues/bagua_synthesis.ogg",
	"festival_stage": "res://resources/audio/sfx/landmark_cues/festival_stage.ogg",
}

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var cue_loader := LANDMARK_CUE_LOADER_SCRIPT.new()
	for cue_id in LANDMARK_CUE_FILES.keys():
		var file_path := String(LANDMARK_CUE_FILES[cue_id])
		_assert_true("%s source file exists" % cue_id, ResourceLoader.exists(file_path))
		var stream := cue_loader.get_stream(file_path)
		_assert_true("%s loads through landmark cue loader" % cue_id, stream != null)
		_assert_true("%s reports a positive duration" % cue_id, stream != null and stream.get_length() > 0.0)
		var cached_stream := cue_loader.get_stream(file_path)
		_assert_true("%s reuses cached stream instance" % cue_id, cached_stream == stream)

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
