extends RefCounted


static func build_storyline() -> Dictionary:
	return {
		"route": {
			"id": "study_future",
			"display_name": "Study and Future",
			"pin_priority": 100,
			"journal_section": "Future",
			"display_order": 20,
			"ending_tone_rules": [
				{"min_score": 2, "tag": "future"},
			],
		},
		"events": [
			{
				"id": "autumn_pressure_named",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["summer_return_complete"],
				},
				"lead_text": "Speak with Dock Musician Pei about how the future already feels too loud.",
				"journal_note": "The exam and everything after it are no longer background pressure. They have started naming themselves openly.",
				"pin_priority": 105,
				"completion_score": 1,
				"season_phase": "autumn_study",
				"status_text": "Autumn study pressure has become explicit instead of quietly implied.",
			},
			{
				"id": "autumn_pressure_shared",
				"phase_window": ["autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {"story_flags_all": ["autumn_pressure_named"]},
				"lead_text": "Speak with Choir Student Lin and hear how the same pressure sounds in someone else's voice.",
				"journal_note": "The year stops feeling like a private flaw once another student names the same fear out loud.",
				"pin_priority": 103,
				"completion_score": 1,
				"status_text": "Autumn pressure is no longer yours alone; it has become a shared truth of the year.",
			},
			{
				"id": "future_commitment_choice",
				"phase_window": ["spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["spring_festival_resolved", "autumn_pressure_shared"],
				},
				"lead_text": "Return to Pei and name at least one future that belongs to you honestly.",
				"journal_note": "The real question is no longer what sounds impressive. It is which future still sounds true when the room gets quiet.",
				"pin_priority": 104,
				"completion_score": 1,
				"status_text": "The future no longer sounds like one forced answer. Honesty has entered the choice.",
			},
			{
				"id": "future_commitment_witnessed",
				"phase_window": ["spring_festival", "summer_2"],
				"prerequisites": {"story_flags_all": ["future_commitment_choice"]},
				"lead_text": "Let Ticket Clerk Min hear what changed, so the harbor can witness the choice before it becomes an ending.",
				"journal_note": "An honest future sounds different once someone at the harbor recognizes that the decision has already begun to live in you.",
				"pin_priority": 101,
				"completion_score": 1,
				"status_text": "The harbor has witnessed the future you named instead of treating it as a private thought.",
			},
			{
				"id": "future_commitment_end",
				"phase_window": ["spring_festival", "summer_2"],
				"prerequisites": {"story_flags_all": ["future_commitment_witnessed"]},
				"lead_text": "If this feels like the true turning point, return to Lian and let the harbor close the story around what was finally named.",
				"journal_note": "An honest commitment can itself become an ending, but only after the harbor has heard it, held it, and answered back.",
				"pin_priority": 120,
				"completion_score": 1,
				"endgame_trigger": "future_commitment_end",
				"ending_behavior": "end_run",
				"closing_label": "The harbor no longer asks for certainty. It only asks whether the future you carry is finally your own.",
				"tone_tags": ["honesty", "turning_point", "harbor"],
				"status_text": "The harbor has turned into a place where an honest future can become its own ending.",
			},
			{
				"id": "summer_exam_complete",
				"phase_window": ["spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["future_commitment_choice"],
				},
				"lead_text": "Stay with Pei until the exam season breaks open into second summer.",
				"journal_note": "The exam finally passes, and the question stops being what everyone wanted from you and becomes what still remains after the pressure goes quiet.",
				"pin_priority": 118,
				"completion_score": 2,
				"season_phase": "summer_2",
				"endgame_trigger": "exam_completed",
				"ending_behavior": "end_run",
				"closing_label": "The exam is over. Second summer arrives without certainty, but with a more honest self standing inside it.",
				"tone_tags": ["release", "second_summer", "honesty"],
				"status_text": "The exam season has passed, and the year has opened into a second summer.",
			},
		],
	}
