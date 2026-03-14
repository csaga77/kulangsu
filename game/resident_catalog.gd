class_name ResidentCatalog
extends RefCounted

const MAX_TRUST := 3
static func max_trust() -> int:
	return MAX_TRUST


static func resident_order() -> Array[String]:
	return [
		"ferry_caretaker",
		"church_caretaker",
		"tunnel_guide",
		"tower_keeper",
	]


static func build_defaults() -> Dictionary:
	return {
		"ferry_caretaker": _resident(
			"Caretaker Lian",
			"Piano Ferry",
			"Prepares the ferry plaza for arrivals and festival nights.",
			"Usually near the luggage crates and plaza notice board.",
			"She hears the melody as a steady harbor refrain that anchors the rest of the island.",
			[
				"The plaza still keeps time, even when the island goes quiet.",
				"The church bells answer the harbor when the wind is kind.",
				"When the melody returns, the whole square will know before dawn.",
			],
			[
				{
					"line": "You hear it too, don't you? The island is holding its breath. Start with Trinity Church; its bells still remember the first phrase.",
					"objective": "Speak with the church caretaker.",
					"journal_step": "Pointed you toward Trinity Church as the cleanest first lead.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "First Lead",
					"quest_state": "introduced",
					"trust_delta": 1,
					"save_status": "Resident note added: Caretaker Lian",
				},
				{
					"line": "If a melody repeats, listen for what changed between the first pass and the second. That is usually where a resident hid the clue on purpose.",
					"objective": "Notice the choir echoes around Trinity Church.",
					"journal_step": "Wants you to compare repeated phrases instead of chasing every sound at once.",
					"quest_state": "in_progress",
					"trust_delta": 1,
					"save_status": "Caretaker Lian shared a listening tip",
				},
				{
					"line": "Bring a real phrase back to the harbor and I'll help the plaza carry it farther than any notice board ever could.",
					"objective": "Return to the ferry plaza after recovering a fragment.",
					"journal_step": "Waiting at the harbor for proof that the melody is returning.",
					"quest_state": "resolved",
					"trust_delta": 1,
					"save_status": "Caretaker Lian is ready to hear the restored phrase",
				},
			]
		),
		"church_caretaker": _resident(
			"Choir Caretaker Mei",
			"Trinity Church",
			"Maintains the choir loft and keeps track of misplaced hymn fragments.",
			"Usually on the church steps or inside the front hall.",
			"She recognizes broken melody lines by which note the bells refuse to resolve.",
			[
				"The choir loft sounds empty, but the bells still argue with each other.",
				"The missing cues were never stolen, only scattered where people stopped listening.",
				"The church can sing again once the cues return in the right order.",
			],
			[
				{
					"line": "Three choir cues vanished between rehearsal and dusk. If you can find where the grounds still echo them, we can rebuild the opening phrase together.",
					"objective": "Find the missing choir cues around Trinity Church.",
					"journal_step": "Asked for three choir cues hidden in the church grounds.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "Open Exploration",
					"quest_state": "introduced",
					"trust_delta": 1,
					"save_status": "Resident note added: Choir Caretaker Mei",
				},
				{
					"line": "The first cue lingers near the front steps, the second near the side garden, and the last one only returns when the yard goes quiet.",
					"objective": "Recover the choir cues in order.",
					"journal_step": "Mapped the likely cue locations to the steps, side garden, and quiet yard.",
					"quest_state": "in_progress",
					"trust_delta": 1,
					"save_status": "Choir Caretaker Mei clarified the cue order",
				},
				{
					"line": "Once the choir phrase settles, the tunnels will sound different. Follow whichever echo feels calmer, not louder.",
					"objective": "Carry the church phrase toward the tunnels.",
					"journal_step": "Believes the restored church phrase will make the tunnels easier to read.",
					"quest_state": "resolved",
					"trust_delta": 1,
					"save_status": "Choir Caretaker Mei tied the church clue to the tunnels",
				},
			]
		),
		"tunnel_guide": _resident(
			"Tunnel Guide Ren",
			"Long Shan Tunnel",
			"Waits at the safer tunnel mouths and judges routes by how calm they feel.",
			"Usually near the lit tunnel pockets or the southern entrance.",
			"Ren listens for echoes that stay warm instead of the ones that bounce the farthest.",
			[
				"A loud echo is not always the right one. The good routes sound patient.",
				"If I stop, it means the light ahead no longer feels safe.",
				"The melody through these tunnels only survives when someone keeps a steady pace.",
			],
			[
				{
					"line": "I know the way through Long Shan, but not alone. Walk a calm route and stop whenever the light thins too much.",
					"objective": "Guide the resident through Long Shan Tunnel.",
					"journal_step": "Needs a calm escort route through Long Shan Tunnel.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "Open Exploration",
					"quest_state": "introduced",
					"trust_delta": 1,
					"save_status": "Resident note added: Tunnel Guide Ren",
				},
				{
					"line": "If I call out, come back to the last lit pocket instead of pushing ahead. The route only works if we can both still hear each other.",
					"objective": "Keep Ren close to the lit route through Long Shan Tunnel.",
					"journal_step": "Explained that distance, not danger, is the main escort failure point.",
					"quest_state": "in_progress",
					"trust_delta": 1,
					"save_status": "Tunnel Guide Ren explained the escort rhythm",
				},
				{
					"line": "Once we are through, I can point you toward the tower. High places make the scattered phrases finally line up.",
					"objective": "Reach Bagua Tower after the tunnel escort.",
					"journal_step": "Ready to redirect you toward Bagua Tower after the escort resolves.",
					"quest_state": "resolved",
					"trust_delta": 1,
					"save_status": "Tunnel Guide Ren opened the route toward Bagua Tower",
				},
			]
		),
		"tower_keeper": _resident(
			"Tower Keeper Suyin",
			"Bagua Tower",
			"Keeps the lower Bagua rooms open and watches for patterns in the evening wind.",
			"Usually near the lower stairs and outer walkway.",
			"Suyin hears the island's melody as climbing notes that only align from above.",
			[
				"The higher you climb, the less the island feels like separate errands.",
				"The tower does not hide answers. It asks whether your clues can stand beside each other.",
				"Once the phrases agree from up here, the plaza will know where to gather.",
			],
			[
				{
					"line": "Most people climb Bagua Tower too early and only see distance. Bring me even one reliable phrase and I can show you how perspective changes the whole melody.",
					"objective": "Carry a reliable melody clue to Bagua Tower.",
					"journal_step": "Wants proof from another district before the tower can help assemble the larger melody.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "Open Exploration",
					"quest_state": "available",
					"trust_delta": 1,
					"save_status": "Resident note added: Tower Keeper Suyin",
				},
				{
					"line": "When you return, lay the fragments beside each other instead of in sequence. The island's shape matters as much as the notes.",
					"objective": "Compare recovered melody fragments at Bagua Tower.",
					"journal_step": "Preparing to turn separate phrases into one island-scale reading.",
					"quest_state": "introduced",
					"trust_delta": 1,
					"save_status": "Tower Keeper Suyin reframed the tower as a synthesis space",
				},
				{
					"line": "From the top chamber, even silence has direction. That is when the final festival route becomes obvious.",
					"objective": "Use Bagua Tower to reveal the festival route.",
					"journal_step": "Waiting to reveal the final route once enough fragments are in hand.",
					"quest_state": "resolved",
					"trust_delta": 1,
					"save_status": "Tower Keeper Suyin is ready for the final reveal",
				},
			]
		),
	}


static func _resident(
	display_name: String,
	landmark: String,
	role: String,
	routine_note: String,
	melody_hint: String,
	ambient_lines: Array,
	dialogue_beats: Array
) -> Dictionary:
	return {
		"display_name": display_name,
		"landmark": landmark,
		"role": role,
		"routine_note": routine_note,
		"melody_hint": melody_hint,
		"ambient_lines": ambient_lines.duplicate(true),
		"dialogue_beats": dialogue_beats.duplicate(true),
		"known": false,
		"trust": 0,
		"conversation_index": 0,
		"quest_state": "available",
		"current_step": "Not introduced yet.",
	}
