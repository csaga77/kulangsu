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
			"summary": "A missing festival line scattered across the harbor, church, tunnels, and tower.",
			"fragment_total": 4,
			"performance_landmark": "Bagua Tower",
			"performance_prompt": "Compare the recovered phrases at Bagua Tower when enough of the contour is known.",
			"unlock_condition": "Recover clues from the harbor, church, tunnels, and tower.",
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
					"source_id": "tunnel_echo",
					"label": "Tunnel Contour",
					"landmark": "Bi Shan / Long Shan Tunnels",
					"summary": "A direction-changing line heard through calmer echoes and safe-lit tunnel pockets.",
				},
				{
					"source_id": "tower_chamber",
					"label": "Tower Synthesis",
					"landmark": "Bagua Tower",
					"summary": "The high-place comparison that lets the island's separate phrases line up into one route.",
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
