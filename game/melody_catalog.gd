class_name MelodyCatalog
extends RefCounted

const ORDER := ["festival_melody"]


static func ordered_ids() -> PackedStringArray:
	return PackedStringArray(ORDER)


static func build_catalog() -> Dictionary:
	return {
			"festival_melody": {
				"display_name": "Festival Melody",
				"district": "Island-wide",
				"summary": "A missing festival line first noticed at the harbor, then rebuilt across the church, tunnels, and tower.",
				"fragment_total": 4,
				"performance_landmark": "Festival Stage",
				"performance_prompt": "Return to the ferry plaza and let the restored route ring out at the harbor stage.",
				"unlock_condition": "Listen at the harbor, then recover four true fragments from the church, tunnels, and tower.",
				"world_response_summary": "Residents, routes, and the harbor gathering feel more alive once the island remembers the tune.",
			"sources": [
				{
					"source_id": "ferry_plaza",
					"label": "Harbor Refrain",
					"landmark": "Piano Ferry",
					"summary": "The opening pulse carried by ferry ropes, plaza footsteps, and Caretaker Lian's listening hints.",
				},
				{
					"source_id": "church_bells",
					"label": "Choir Echo",
					"landmark": "Trinity Church",
					"summary": "A steadier phrase hidden in the bells, choir cues, and the church grounds.",
				},
				{
					"source_id": "bi_shan_echo",
					"label": "Bi Shan Contour",
					"landmark": "Bi Shan Tunnel",
					"summary": "A calmer tunnel phrase revealed when the mural chamber finally answers the traced echoes.",
				},
				{
					"source_id": "long_shan_route",
					"label": "Long Shan Cadence",
					"landmark": "Long Shan Tunnel",
					"summary": "A steadier route phrase carried between the lit pockets while escorting Ren through the dark.",
				},
				{
					"source_id": "tower_chamber",
					"label": "Tower Synthesis",
					"landmark": "Bagua Tower",
					"summary": "The high-place comparison that lets the island's separate phrases line up into one route toward the harbor stage.",
				},
			],
		},
	}


static func state_display_name(state: String) -> String:
	match state:
		"heard":
			return "Heard"
		"reconstructed":
			return "Reconstructed"
		"performed":
			return "Performed"
		"resonant":
			return "Resonant"
		_:
			return "Unknown"
