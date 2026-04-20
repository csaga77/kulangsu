extends RefCounted


static func build_storyline() -> Dictionary:
	return {
		"route": {
			"id": "family_memory",
			"display_name": "Family and Memory",
			"pin_priority": 110,
			"journal_section": "Family",
			"display_order": 10,
			"ending_tone_rules": [
				{"min_score": 3, "tag": "grace"},
				{"min_score": 4, "tag": "care"},
			],
		},
		"events": [
			{
				"id": "summer_return_complete",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {},
				"lead_text": "Return to Caretaker Lian and let the harbor become a real homecoming.",
				"journal_note": "The harbor feels familiar, but not easy. Home is close enough to recognize and still hard to hear clearly.",
				"pin_priority": 115,
				"completion_score": 1,
				"status_text": "The harbor return now belongs to this year instead of the last one.",
			},
			{
				"id": "trinity_memory_awakened",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival"],
				"prerequisites": {"story_flags_all": ["summer_return_complete"]},
				"lead_text": "Visit Trinity Church and let one clear memory of Grandma return.",
				"journal_note": "Church memory, guilt, and grace are beginning to sound like part of the same story.",
				"pin_priority": 108,
				"completion_score": 1,
				"status_text": "A church-linked memory of Grandma has started to return clearly.",
			},
			{
				"id": "winter_memory_reveal",
				"phase_window": ["autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["trinity_memory_awakened", "autumn_pressure_named"],
				},
				"lead_text": "Return to Trinity Church once the pressure settles in and face the memory you kept avoiding.",
				"journal_note": "The year has grown colder, and the memory that once stayed blurred is becoming harder to outrun.",
				"pin_priority": 112,
				"completion_score": 1,
				"season_phase": "winter",
				"status_text": "Winter has turned the memory inward and unmistakable.",
			},
			{
				"id": "spring_festival_prepared",
				"phase_window": ["winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["winter_memory_reveal", "preservation_inheritance_seen"],
				},
				"lead_text": "Speak with Tea Vendor Hua about how the harbor is quietly preparing for the first Spring Festival without Grandma.",
				"journal_note": "Before the holiday can land emotionally, the harbor has to admit it is already bracing for it.",
				"pin_priority": 118,
				"completion_score": 1,
				"status_text": "The harbor has started preparing for Spring Festival in a way that makes the loss impossible to ignore.",
			},
			{
				"id": "spring_festival_resolved",
				"phase_window": ["winter", "spring_festival", "summer_2"],
				"prerequisites": {"story_flags_all": ["spring_festival_prepared"]},
				"lead_text": "Go back to the harbor and speak with Lian about the first Spring Festival without Grandma.",
				"journal_note": "The family story, the season, and the island's older memory are finally leaning into the same difficult holiday.",
				"pin_priority": 120,
				"completion_score": 2,
				"season_phase": "spring_festival",
				"status_text": "The first Spring Festival without Grandma has become the emotional center of the year.",
			},
		],
	}
