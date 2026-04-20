extends RefCounted


static func build_storyline() -> Dictionary:
	return {
		"route": {
			"id": "melody_landmarks",
			"display_name": "Island Melody",
			"pin_priority": 80,
			"journal_section": "Landmarks",
			"display_order": 40,
			"ending_tone_rules": [
				{"min_score": 4, "tag": "belonging"},
			],
		},
		"events": [
			{
				"id": "melody_ferry_settled",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {},
				"lead_text": "Listen to the harbor refrain and carry it uphill into the island.",
				"journal_note": "The harbor has offered the first steady pulse. The rest of the island still has to answer it.",
				"pin_priority": 82,
				"completion_score": 1,
				"status_text": "The harbor refrain has settled into the melody route.",
			},
			{
				"id": "melody_church_restored",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["melody_ferry_settled"],
				},
				"lead_text": "Settle Trinity Church so the bells can answer the harbor clearly.",
				"journal_note": "The church route is the first full phrase the island gives back.",
				"pin_priority": 85,
				"completion_score": 1,
				"status_text": "Trinity Church has returned one full phrase to the island.",
			},
			{
				"id": "melody_bi_shan_restored",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["melody_church_restored"],
				},
				"lead_text": "Trace the steadier echo through Bi Shan Tunnel.",
				"journal_note": "Bi Shan turns a hidden route back into something dependable and shared.",
				"pin_priority": 83,
				"completion_score": 1,
				"status_text": "Bi Shan Tunnel has answered with a steadier route.",
			},
			{
				"id": "melody_long_shan_restored",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["melody_church_restored"],
				},
				"lead_text": "Walk the Long Shan route patiently enough for someone else to trust it.",
				"journal_note": "Long Shan turns route-finding into companionship instead of simple navigation.",
				"pin_priority": 83,
				"completion_score": 1,
				"status_text": "Long Shan Tunnel has become a route someone else can believe in.",
			},
			{
				"id": "melody_bagua_aligned",
				"phase_window": ["summer_1", "autumn_study", "winter", "spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["melody_bi_shan_restored", "melody_long_shan_restored"],
				},
				"lead_text": "Carry the steady routes to Bagua Tower and align the island from above.",
				"journal_note": "The tower turns separate errands into one visible route across the island.",
				"pin_priority": 86,
				"completion_score": 1,
				"status_text": "Bagua Tower has aligned the melody route into one island-scale line.",
			},
			{
				"id": "harbor_festival_performed",
				"phase_window": ["spring_festival", "summer_2"],
				"prerequisites": {
					"story_flags_all": ["melody_bagua_aligned", "spring_festival_resolved"],
				},
				"lead_text": "Return the restored melody to the harbor stage and see what the island remembers in public.",
				"journal_note": "The island's music returns in public only once the private year has finally caught up with it.",
				"pin_priority": 98,
				"completion_score": 2,
				"endgame_trigger": "harbor_festival_performed",
				"ending_behavior": "continue_story",
				"closing_label": "The restored harbor performance is no longer only a festival. It has become the public shape of everything the island remembers.",
				"tone_tags": ["music", "community", "public_memory"],
				"status_text": "The harbor has performed the restored melody back into the island.",
			},
		],
	}
