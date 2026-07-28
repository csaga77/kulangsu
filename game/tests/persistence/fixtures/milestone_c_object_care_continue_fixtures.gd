class_name MilestoneCObjectCareContinueFixtures
extends RefCounted

const STORY_SAVE_CODEC := preload("res://game/app_state/story_save_codec.gd")


static func build_ferry_payload() -> Dictionary:
	return _build_payload(
		"Piano Ferry",
		"Care for the ferry music case, then listen from the harbor bench.",
		31,
		15.5
	)


static func build_church_payload() -> Dictionary:
	return _build_payload(
		"Trinity Church",
		"Align the hymn chest without blocking the church aisle.",
		32,
		10.0
	)


static func _build_payload(
	location: String,
	objective: String,
	story_day: int,
	world_hour: float
) -> Dictionary:
	return {
		"version": STORY_SAVE_CODEC.SAVE_VERSION,
		"saved_at_unix": 1785211200 + story_day,
		"mode_id": "story",
		"season_phase": "summer_1",
		"story_day": story_day,
		"world_hour": world_hour,
		"location": location,
		"objective": objective,
		"journal_unlocked": true,
		"story_flags": {
			"summer_return_complete": true,
		},
		"story_resume_anchor_id": location,
		"story_resume_location": location,
	}
