class_name BaguaAscentContinueFixture
extends RefCounted

const STORY_SAVE_CODEC := preload("res://game/app_state/story_save_codec.gd")


static func build_payload() -> Dictionary:
	return {
		"version": STORY_SAVE_CODEC.SAVE_VERSION,
		"saved_at_unix": 1785124800,
		"mode_id": "story",
		"season_phase": "summer_1",
		"story_day": 28,
		"world_hour": 16.0,
		"location": "Bagua Tower",
		"objective": "Optionally cross the lower stewardship terrace and inspect the service view.",
		"journal_unlocked": true,
		"melody_progress": {
			"festival_melody": {
				"state": "heard",
				"fragments_found": 0,
				"fragments_total": 4,
				"known_sources": ["ferry_plaza"],
				"next_lead": "The ordinary Bagua route remains open beside the optional stewardship ascent.",
				"performed": false,
			},
		},
		"landmark_progress": {
			"bagua_tower": {
				"state": "available",
				"synthesis_done": false,
			},
		},
		"story_flags": {
			"summer_return_complete": true,
			"autumn_pressure_named": true,
			"preservation_inheritance_seen": true,
			"preservation_tower_perspective": true,
		},
		"story_resume_anchor_id": "Bagua Tower",
		"story_resume_location": "Bagua Tower",
	}
