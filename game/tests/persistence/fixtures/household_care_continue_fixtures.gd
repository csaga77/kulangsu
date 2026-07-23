class_name HouseholdCareContinueFixtures
extends RefCounted

const STORY_SAVE_CODEC := preload("res://game/app_state/story_save_codec.gd")
const OPEN_WINTER := "open_winter"
const LEGACY_POST_CLOSER := "legacy_post_closer"


static func build_payload(fixture_id: String) -> Dictionary:
	match fixture_id.strip_edges():
		OPEN_WINTER:
			return _build_open_winter_payload()
		LEGACY_POST_CLOSER:
			return _build_legacy_post_closer_payload()
	return {}


static func _build_open_winter_payload() -> Dictionary:
	return {
		"version": STORY_SAVE_CODEC.SAVE_VERSION,
		"saved_at_unix": 1784815200,
		"season_phase": "winter",
		"story_day": 92,
		"world_hour": 16.5,
		"location": "Piano Ferry",
		"objective": "Visit A Po's household near the ferry before festival preparations begin.",
		"journal_unlocked": true,
		"melody_progress": _build_melody_progress(),
		"story_flags": _build_open_window_flags(),
		"story_resume_anchor_id": "Piano Ferry",
		"story_resume_location": "Piano Ferry",
	}


static func _build_legacy_post_closer_payload() -> Dictionary:
	var story_flags := _build_open_window_flags()
	story_flags["spring_festival_prepared"] = true
	return {
		"version": 1,
		"saved_at_unix": 1784818800,
		"season_phase": "winter",
		"story_time": {
			"story_day": 93,
			"world_hour": 17.5,
		},
		"location": "Piano Ferry",
		"objective": "Return to Lian once the harbor's festival preparations feel impossible to ignore.",
		"journal_unlocked": true,
		"melody_progress": _build_melody_progress(),
		"story_flags": story_flags,
		"story_resume_anchor_id": "Piano Ferry",
		"story_resume_location": "Piano Ferry",
	}


static func _build_open_window_flags() -> Dictionary:
	return {
		"summer_return_complete": true,
		"autumn_pressure_named": true,
		"autumn_pressure_shared": true,
		"preservation_inheritance_seen": true,
		"trinity_memory_awakened": true,
		"winter_memory_reveal": true,
	}


static func _build_melody_progress() -> Dictionary:
	return {
		"festival_melody": {
			"state": "heard",
			"fragments_found": 0,
			"fragments_total": 4,
			"known_sources": ["ferry_plaza"],
			"next_lead": "Listen to the harbor refrain around the ferry plaza before following the bells uphill.",
			"performed": false,
		},
	}
