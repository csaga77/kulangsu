extends RefCounted


func build_storyline() -> Dictionary:
	return {
		"route": {
			"id": "preservation_inheritance",
			"display_name": "Preservation and Inheritance",
			"pin_priority": 90,
			"journal_section": "Preservation",
			"display_order": 30,
			"ending_tone_rules": [
				{"min_score": 2, "tag": "inheritance"},
				{"min_score": 2, "helped_residents_min": 4, "tag": "stewardship"},
			],
		},
		"events": [
			{
				"id": "preservation_inheritance_seen",
				"phase_window": ["autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["autumn_pressure_named"],
				},
				"lead_text": "Speak with Postcard Seller An about why the island's older buildings keep ending up in people's hands.",
				"journal_note": "The old buildings stop feeling decorative once someone at the harbor treats them like the part of the island people are afraid to lose.",
				"pin_priority": 96,
				"completion_score": 1,
				"status_text": "The island's old buildings now read as inheritance rather than background.",
			},
			{
				"id": "preservation_tower_perspective",
				"phase_window": ["autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["preservation_inheritance_seen"],
					"landmark_state": {"bagua_tower": "available"},
				},
				"lead_text": "Climb to Bagua Tower and let Terrace Painter Nian show you how preservation looks once the whole island is in view.",
				"journal_note": "From the tower, preservation stops sounding sentimental and starts feeling like an island-scale responsibility.",
				"pin_priority": 94,
				"completion_score": 1,
				"status_text": "Bagua Tower has turned inheritance into a wider view of what the island still needs kept.",
			},
		],
	}
