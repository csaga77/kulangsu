class_name ResidentCatalog
extends RefCounted

const RESIDENT_APPEARANCE_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_appearance_definition.gd")
const RESIDENT_BEAT_CONDITIONS_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_beat_conditions_definition.gd")
const RESIDENT_CONDITIONAL_BEAT_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_conditional_beat_definition.gd")
const RESIDENT_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_definition.gd")
const RESIDENT_DIALOGUE_BEAT_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_dialogue_beat_definition.gd")
const RESIDENT_DIALOGUE_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_dialogue_definition.gd")
const RESIDENT_MOVEMENT_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_movement_definition.gd")
const RESIDENT_ROUTE_POINT_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_route_point_definition.gd")
const RESIDENT_ROUTINE_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_routine_definition.gd")
const RESIDENT_SPAWN_DEFINITION_SCRIPT := preload("res://game/resident_system/resident_spawn_definition.gd")
const EXTERNAL_RESIDENT_DEFINITIONS_DIR := "res://game/residents/definitions"

const MAX_TRUST := 3
const MOOD_NORMAL := 1
const MOOD_SMILE := 2
const MOOD_BLUSH := 3
const MOOD_ANGRY := 4
const MOOD_SAD := 5
const MOOD_SHAME := 6
const MOOD_SHOCK := 7
const BUILTIN_RESIDENT_ORDER := [
	"ferry_caretaker",
	"ferry_porter_jun",
	"postcard_seller_an",
	"dock_musician_pei",
	"tea_vendor_hua",
	"ticket_clerk_min",
	"church_caretaker",
	"choir_student_lin",
	"bell_repairer_qiao",
	"florist_yumei",
	"echo_sketcher_yan",
	"mural_restorer_cai",
	"tunnel_listener_nuo",
	"tunnel_guide",
	"raincoat_child_xiu",
	"storyteller_wen",
	"rope_handler_qiu",
	"porter_shan",
	"light_watcher_he",
	"tower_keeper",
	"terrace_painter_nian",
	"map_student_jia",
	"rooftop_sweeper_mo",
	"view_guide_lio",
	"window_caretaker_su",
]


static func max_trust() -> int:
	return MAX_TRUST


static func resident_order() -> Array[String]:
	var ordered_ids: Array[String] = []
	for resident_id in BUILTIN_RESIDENT_ORDER:
		ordered_ids.append(String(resident_id))
	var external_definitions := _load_external_resident_definitions()
	var extra_entries: Array[Dictionary] = []

	for resident_id in external_definitions.keys():
		if ordered_ids.find(resident_id) >= 0:
			continue
		var definition = external_definitions.get(resident_id)
		var definition_sort_order := 0
		var sort_order_value = definition.get("sort_order")
		if sort_order_value != null:
			definition_sort_order = int(sort_order_value)
		extra_entries.append({
			"id": String(resident_id),
			"sort_order": definition_sort_order,
		})

	extra_entries.sort_custom(_sort_definition_order_entries)
	for entry in extra_entries:
		ordered_ids.append(String(entry.get("id", "")))

	return ordered_ids


static func build_definitions() -> Dictionary:
	var residents := build_builtin_definitions()
	residents.merge(_load_external_resident_definitions(), true)

	for resident_id in residents.keys():
		var definition = residents.get(resident_id)
		if definition == null:
			continue
		definition.id = String(resident_id)

	return residents


static func build_builtin_definitions() -> Dictionary:
	var residents: Dictionary = {}
	residents.merge(_story_residents(), true)
	residents.merge(_ambient_residents(), true)

	for resident_id in residents.keys():
		var definition = residents.get(resident_id)
		if definition == null:
			continue
		definition.id = String(resident_id)

	return residents


static func _sort_definition_order_entries(a: Dictionary, b: Dictionary) -> bool:
	var order_a := int(a.get("sort_order", 0))
	var order_b := int(b.get("sort_order", 0))
	if order_a != order_b:
		return order_a < order_b
	return String(a.get("id", "")) < String(b.get("id", ""))


static func _load_external_resident_definitions() -> Dictionary:
	var definitions: Dictionary = {}
	var resource_paths: Array[String] = []
	_collect_external_resident_definition_paths(EXTERNAL_RESIDENT_DEFINITIONS_DIR, resource_paths)
	resource_paths.sort()

	for resource_path in resource_paths:
		var definition = ResourceLoader.load(resource_path)
		if definition == null:
			continue
		if !definition.has_method("to_runtime_profile"):
			continue
		if definition.has_method("should_include_in_catalog") and !bool(definition.call("should_include_in_catalog")):
			continue

		var resident_id := String(definition.get("id")).strip_edges()
		if resident_id.is_empty():
			resident_id = resource_path.get_file().get_basename()
			definition.set("id", resident_id)

		definitions[resident_id] = definition

	return definitions


static func _collect_external_resident_definition_paths(root_dir: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue

		var entry_path := root_dir.path_join(entry_name)
		if dir.current_is_dir():
			_collect_external_resident_definition_paths(entry_path, out_paths)
			continue

		var extension := entry_name.get_extension().to_lower()
		if extension in ["tres", "res"]:
			out_paths.append(entry_path)
	dir.list_dir_end()


static func build_defaults() -> Dictionary:
	var residents: Dictionary = {}
	var definitions := build_definitions()
	for resident_id in resident_order():
		var definition = definitions.get(resident_id)
		if definition == null:
			continue
		residents[resident_id] = definition.to_runtime_profile()
	return residents


static func _story_residents() -> Dictionary:
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
					"line": "You hear it too, don't you? The island is holding its breath. Listen first to the old piano crate by the notice board. The harbor is keeping the opening pulse there.",
					"objective": "Inspect the old piano crate near the ferry notice board.",
					"journal_step": "Asked you to listen to the ferry plaza before chasing the island's larger melody.",
					"hint": "R Inspect   Esc Pause",
					"chapter": "Arrival",
					"quest_state": "introduced",
					"landmark_states": {"piano_ferry": "introduced"},
					"trust_delta": 1,
					"save_status": "Caretaker Lian pointed out a harbor clue.",
				},
				{
					"line": "Good. The harbor kept its part of the melody after all. Take that pulse uphill to Trinity Church; its bells still remember the next phrase, and the journal can hold the route for you now.",
					"objective": "Speak with the church caretaker.",
					"journal_step": "Pointed you toward Trinity Church once the harbor refrain settled into a clear lead.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "First Lead",
					"quest_state": "resolved",
					"gate": "piano_ferry_harbor_clue",
					"gate_fallback": "Before you chase the bells, listen to the old piano crate by the notice board. The harbor is holding the opening pulse there.",
					"unlock_landmark": "trinity_church",
					"landmark_reward": "piano_ferry",
					"story_event": "summer_return_complete",
					"trust_delta": 1,
					"save_status": "Caretaker Lian marked your first uphill lead.",
				},
				{
					"line": "Bring a real phrase back to the harbor and I'll help the plaza carry it farther than any notice board ever could.",
					"objective": "Return to the ferry plaza after recovering a fragment.",
					"journal_step": "Waiting at the harbor for proof that the melody is returning.",
					"quest_state": "resolved",
					"gate": "first_fragment_restored",
					"gate_fallback": "The plaza is listening. Bring one whole phrase back from the church before we ask the harbor to carry it farther.",
					"trust_delta": 1,
					"save_status": "Caretaker Lian is ready to hear the restored phrase",
				},
			],
			_look(
				"female",
				"light",
				"head/heads/human/heads_human_female_elderly",
				"hair/bob/hair_bob_side_part",
				"gray",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_cardigan",
				"sky",
				"legs/pants/legs_formal",
				"navy",
				"feet/shoes/feet_shoes_revised",
				"brown"
			),
			_spawn("Piano Ferry", Vector2(-260.0, 180.0), -150.0, MOOD_NORMAL, 88.0),
			{},
			[
				{
					"conditions": {"landmark_state": {"trinity_church": "reward_collected"}},
					"priority": 10,
					"once": true,
					"line": "The church phrase came home. The harbor can breathe easier now.",
					"trust_delta": 1,
					"journal_step": "Lian heard the church fragment return and trusts the melody is mending.",
				},
				{
					"conditions": {"landmark_state": {"long_shan_tunnel": "reward_collected"}},
					"priority": 20,
					"once": true,
					"line": "You walked someone through the dark. The harbor hears that kind of thing.",
					"trust_delta": 1,
					"journal_step": "Lian noticed you helped in Long Shan Tunnel.",
				},
				{
					"conditions": {"fragments_found_min": 3},
					"priority": 30,
					"once": true,
					"line": "Three phrases and the plaza is already humming louder. The tower will want to hear them together.",
					"objective": "Carry the recovered phrases to Bagua Tower.",
					"journal_step": "Lian urged you toward the tower now that most phrases are in hand.",
				},
				{
					"conditions": {"story_flag_all": ["winter_memory_reveal"]},
					"priority": 32,
					"once": true,
					"line": "A Po has been keeping the house warm enough for your parents to return into something gentler than silence. That kind of care holds longer than people admit. It is part of why this winter hurts the way it does.",
					"journal_step": "Lian tied the winter memory to A Po's care and the parents who keep leaving and returning around it.",
					"save_status": "Lian named care, absence, and winter as the same family story.",
				},
				{
					"conditions": {"story_flag_all": ["spring_festival_prepared"]},
					"priority": 35,
					"once": true,
					"line": "This coming festival will be the first one without your grandmother's place still waiting for her. The harbor knows before the house says it aloud.",
					"journal_step": "Lian finally spoke of the first Spring Festival without Grandma as something the whole island is already bracing for.",
					"story_event": "spring_festival_resolved",
				},
				{
					"conditions": {"story_flag_all": ["future_commitment_witnessed"]},
					"priority": 38,
					"once": true,
					"line": "Then let the harbor answer you clearly. A future does not become real only when it is approved. Sometimes it becomes real when you can finally carry it here without apologizing for it.",
					"objective": "If this turning point feels true, let the harbor close the story here.",
					"journal_step": "Lian turned the harbor into the place where an honest future could finally be answered back.",
					"story_event": "future_commitment_end",
					"save_status": "Caretaker Lian recognized the harbor as the place where the future-choice route can honestly close.",
				},
				{
					"conditions": {"melody_state": {"festival_melody": "resonant"}},
					"priority": 40,
					"once": true,
					"line": "Listen to the ropes now. The harbor kept the melody after the crowd went home. It is not performing anymore, just breathing on its own.",
					"journal_step": "Lian noticed the plaza now carries the restored melody even in the quiet after the festival.",
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
					"gate_fallback": "The church still feels like the next phrase, not the opening one. Let the harbor welcome you home first, then we can listen for the missing choir cues together.",
					"story_event": "trinity_memory_awakened",
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
					"gate": "trinity_church_chime",
					"gate_fallback": "The choir cues are gathered, but the church phrase still needs to settle at the choir chime near the steps.",
					"landmark_reward": "trinity_church",
				},
			],
			_look(
				"female",
				"olive",
				"head/heads/human/heads_human_female",
				"hair/long/hair_wavy",
				"dark brown",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_cardigan",
				"maroon",
				"legs/pants/legs_formal",
				"charcoal",
				"feet/shoes/feet_shoes_revised",
				"black"
			),
			_spawn("Trinity Church", Vector2(-300.0, 210.0), -130.0, MOOD_SMILE, 88.0),
			{},
			[
				{
					"conditions": {"landmark_state": {"bi_shan_tunnel": "reward_collected"}},
					"priority": 10,
					"once": true,
					"line": "The tunnel echo came back softer than I expected. When music returns through stone, it always sounds gentler.",
					"trust_delta": 1,
					"journal_step": "Mei heard the tunnel echo resolve and feels the church phrase sits more naturally now.",
				},
				{
					"conditions": {"fragments_found_min": 3, "resident_known": ["tower_keeper"]},
					"priority": 20,
					"once": true,
					"line": "Suyin at the tower knows how to read distance. If anyone can line up three separate phrases, it is someone who sees the whole island at once.",
					"journal_step": "Mei endorsed Tower Keeper Suyin as the person who can synthesize the recovered fragments.",
				},
				{
					"conditions": {"story_flag_all": ["trinity_memory_awakened", "autumn_pressure_named"]},
					"priority": 25,
					"once": true,
					"line": "Once the school year tightens, the church does not make the memory kinder. It only makes it impossible to avoid. Some grief waits until winter to speak clearly.",
					"journal_step": "Mei named the colder turn of the year as the moment memory stops staying gentle and starts speaking plainly.",
					"story_event": "winter_memory_reveal",
				},
				{
					"conditions": {"melody_state": {"festival_melody": "resonant"}},
					"priority": 30,
					"once": true,
					"line": "The bells do not need help to settle tonight. Even the empty loft keeps answering the harbor in a softer voice.",
					"journal_step": "Mei heard the church hold onto the festival melody after the performance ended.",
				},
			]
		),
			"tunnel_guide": _resident(
				"Tunnel Guide Ren",
				"Long Shan Tunnel",
				"Keeps a calm pace from the southern entrance through to the northern mouth, judging routes by how steady they feel.",
				"Usually moving from the southern entrance through the tunnel to the northern mouth.",
				"Ren listens for echoes that stay warm instead of the ones that bounce the farthest.",
			[
				"A loud echo is not always the right one. The good routes sound patient.",
				"If I stop, it means the light ahead no longer feels safe.",
				"The melody through these tunnels only survives when someone keeps a steady pace.",
			],
			[
				{
					"line": "I know the way through Long Shan, but not alone. Walk a calm route and stop whenever the light thins too much.",
					"objective": "Start a calm crossing through Long Shan Tunnel with Ren.",
					"journal_step": "Needs a calm crossing through Long Shan Tunnel, paced by the lit route.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "Open Exploration",
					"quest_state": "introduced",
					"landmark_states": {"long_shan_tunnel": "introduced"},
					"trust_delta": 1,
					"save_status": "Resident note added: Tunnel Guide Ren",
				},
				{
					"line": "If I call out, come back to the last lit pocket instead of pushing ahead. The route only works if we can both still hear each other.",
					"objective": "Move with Ren between the lit pockets through Long Shan Tunnel.",
					"journal_step": "Explained that the lit pockets, not speed, are what keep the route steady.",
					"quest_state": "in_progress",
					"landmark_states": {"long_shan_tunnel": "in_progress"},
					"trust_delta": 1,
					"save_status": "Tunnel Guide Ren explained the escort rhythm",
				},
				{
					"line": "Once we are through, I can finally tell whether the other tunnel still disagrees with this one. If it does, settle Bi Shan first and then come back.",
					"objective": "Settle Bi Shan Tunnel if its route still feels uncertain, then check back with Ren.",
					"journal_step": "Waiting to compare Long Shan against Bi Shan before pointing you toward the tower.",
					"quest_state": "resolved",
					"gate": "long_shan_exit_reached",
					"gate_fallback": "The passage is not done yet. Stay close and keep moving toward the exit.",
					"trust_delta": 1,
					"save_status": "Tunnel Guide Ren wants to compare the two tunnel routes before sending you to the tower",
				},
			],
			_look(
				"male",
				"bronze",
				"head/heads/human/heads_human_male",
				"hair/short/hair_bedhead",
				"black",
				"torso/shirts/shortsleeve/torso_clothes_tshirt",
				"forest",
				"legs/pants/legs_pants",
				"walnut",
				"feet/shoes/feet_shoes_revised",
				"leather",
				{
					"hair/beards/beards_trimmed": "dark brown",
				}
			),
			_spawn("Long Shan Tunnel", Vector2(-160.0, 48.0), -110.0, MOOD_SAD, 88.0),
				_route(
					[
						_route_point("Long Shan Tunnel South Portal", Vector2(-32.0, 0.0), 0.0, 0.0),
						_route_point("Long Shan Tunnel", Vector2(-1536.0, -1072.0), 0.0, 0.0),
						_route_point("Long Shan Tunnel North Portal", Vector2(-32.0, 0.0), 2.0, 2.0),
					],
					24.0,
					0.4,
					1.0
				),
				[
					{
						"conditions": {
							"landmark_state": {
								"long_shan_tunnel": "reward_collected",
								"bagua_tower": "locked",
							},
							"fragments_found_min": 3,
						},
						"priority": 5,
						"once": true,
						"line": "Good. Now the tunnels agree instead of arguing. Take that steadier route up to Bagua Tower, and the high rooms should finally make sense of it.",
						"objective": "Reach Bagua Tower now that both tunnel routes are steady.",
						"journal_step": "Ren judged the two tunnel routes steady enough to carry up to Bagua Tower.",
						"unlock_landmark": "bagua_tower",
						"save_status": "Tunnel Guide Ren opened the route toward Bagua Tower",
					},
					{
						"conditions": {"landmark_state": {"bagua_tower": "reward_collected"}},
						"priority": 10,
						"once": true,
					"line": "From the tower, the route sounds patient instead of anxious. I think that is how we knew it was the right crossing.",
					"journal_step": "Ren felt the tower confirmed the calm route through Long Shan Tunnel.",
				},
				{
					"conditions": {"melody_state": {"festival_melody": "performed"}},
					"priority": 20,
					"once": true,
						"line": "You carried the route all the way back to the harbor. Even the tunnel walls would have listened for that.",
						"journal_step": "Ren heard that the harbor finally carried the tunnel route out into the open.",
					},
					{
						"conditions": {"melody_state": {"festival_melody": "resonant"}},
						"priority": 30,
						"once": true,
						"line": "Long Shan sounds warmer now. The dark is still the dark, but the route keeps its calm even when no one is proving it anymore.",
						"journal_step": "Ren felt the tunnel keep its steadier cadence after the festival night quieted down.",
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
					"line": "The tower helps once the tunnels stop contradicting each other. Bring me the route when both crossings sound steady, and I can show you what the island looks like when its phrases finally agree.",
					"objective": "Reach Bagua Tower once the tunnel routes are steady.",
					"journal_step": "Waiting for the tunnel routes to settle before the tower can help assemble the larger melody.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "Open Exploration",
					"quest_state": "available",
					"gate": "bagua_tower_available",
					"gate_fallback": "The tower can wait until the tunnels agree. Settle Bi Shan and Long Shan until the route sounds steady, then bring it up here.",
					"landmark_states": {"bagua_tower": "available"},
					"trust_delta": 1,
					"save_status": "Resident note added: Tower Keeper Suyin",
				},
				{
					"line": "When you return, lay the fragments beside each other instead of in sequence. The island's shape matters as much as the notes.",
					"objective": "Compare recovered melody fragments at Bagua Tower.",
					"journal_step": "Preparing to turn separate phrases into one island-scale reading.",
					"quest_state": "introduced",
					"gate": "three_fragments_restored",
					"gate_fallback": "Bring me three reliable phrases first. Until then, the tower only shows distance and not direction.",
					"landmark_states": {"bagua_tower": "in_progress"},
					"trust_delta": 1,
					"save_status": "Tower Keeper Suyin reframed the tower as a synthesis space",
				},
				{
					"line": "From the top chamber, even silence has direction. Take that route back to the harbor stage, and the whole plaza will know where the melody belongs.",
					"objective": "Use Bagua Tower to reveal the harbor festival route.",
					"journal_step": "Waiting to send the restored route back to the harbor stage.",
					"quest_state": "resolved",
					"gate": "bagua_synthesis_done",
					"gate_fallback": "The synthesis chamber at the top is not ready yet. Climb higher and let the phrases settle from there.",
					"landmark_reward": "bagua_tower",
					"trust_delta": 1,
					"save_status": "Tower Keeper Suyin revealed the final festival route",
				},
			],
			_look(
				"male",
				"taupe",
				"head/heads/human/heads_human_male_elderly",
				"hair/bald/hair_buzzcut",
				"white",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_cardigan",
				"slate",
				"legs/pants/legs_formal",
				"tan",
				"feet/shoes/feet_shoes_revised",
				"charcoal"
			),
			_spawn("Bagua Tower", Vector2(-220.0, 260.0), -120.0, MOOD_NORMAL, 88.0),
			{},
			[
				{
					"conditions": {"melody_state": {"festival_melody": "performed"}},
					"priority": 10,
					"once": true,
					"line": "The harbor answered exactly where the tower said it would. Height only mattered because you carried the route back down.",
					"journal_step": "Suyin approved how the tower's route returned to the harbor.",
				},
				{
					"conditions": {"melody_state": {"festival_melody": "resonant"}},
					"priority": 20,
					"once": true,
					"line": "From up here the island has stopped sounding like separate landmarks. It holds one line now, even when nobody is trying to gather it.",
					"journal_step": "Suyin heard the whole island keep one shared line after the festival performance passed into memory.",
				},
			]
		),
	}


static func _ambient_residents() -> Dictionary:
	var residents: Dictionary = {}
	var specs: Array[Dictionary] = [
		{
			"id": "ferry_porter_jun",
			"display_name": "Ferry Porter Jun",
			"landmark": "Piano Ferry",
			"role": "Stacks trunks by hand and listens for returning ferries by hull rhythm.",
			"routine_note": "Usually near the cargo lane by the ferry awning.",
			"melody_hint": "He swears the harbor rhythm is missing one dependable downbeat.",
			"ambient_lines": [
				"The carts feel lighter when the harbor has a tune to work with.",
				"If the ferry ropes start creaking in time again, we will all hear it.",
			],
			"appearance": _look(
				"male",
				"brown",
				"head/heads/human/heads_human_male_plump",
				"hair/short/hair_parted",
				"dark brown",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_polo",
				"walnut",
				"legs/pants/legs_pants2",
				"charcoal",
				"feet/shoes/feet_shoes_basic",
				"brown"
			),
			"spawn": _spawn("Piano Ferry", Vector2(-120.0, 240.0), -95.0, MOOD_NORMAL),
			"conditional_beats": [
				{
					"conditions": {"story_flag_all": ["summer_exam_complete"]},
					"priority": 20,
					"once": true,
					"line": "Second summer changes the cargo lane too. Everyone lifts the same trunks, but nobody is pretending the year still has one answer packed inside it anymore.",
					"journal_step": "Jun heard second summer arrive as a quieter harbor rhythm instead of one more deadline.",
				},
			],
		},
		{
			"id": "postcard_seller_an",
			"display_name": "Postcard Seller An",
			"landmark": "Piano Ferry",
			"role": "Keeps a rotating rack of island postcards and local paper charms.",
			"routine_note": "Usually beneath a shade umbrella near the notice board.",
			"melody_hint": "She remembers the island by which postcard customers hum over.",
			"ambient_lines": [
				"Tourists always pause longer at the cards that look musical.",
				"I think people remember this island with their ears first and their eyes second.",
			],
			"appearance": _look(
				"female",
				"amber",
				"head/heads/human/heads_human_female",
				"hair/braids/hair_ponytail",
				"strawberry",
				"torso/shirts/shortsleeve/torso_clothes_shortsleeve_polo",
				"rose",
				"legs/pants/legs_pants2",
				"bluegray",
				"feet/shoes/feet_shoes_basic",
				"tan"
			),
			"spawn": _spawn("Piano Ferry", Vector2(40.0, 280.0), -40.0, MOOD_SMILE),
			"conditional_beats": [
				{
					"conditions": {"story_flag_all": ["autumn_pressure_named"]},
					"priority": 20,
					"once": true,
					"line": "People buy the old verandas and tower railings more than the beach cards now. I think they are trying to carry home proof that this island still remembers itself. That is how inheritance starts feeling urgent instead of quaint.",
					"objective": "Climb to Bagua Tower once you can and see how that inheritance changes shape from above.",
					"journal_step": "An made the island's older buildings feel like the part people are quietly afraid to lose.",
					"story_event": "preservation_inheritance_seen",
					"save_status": "Postcard Seller An reframed preservation as something visitors and locals are already trying to hold onto.",
				},
				{
					"conditions": {"story_flag_all": ["preservation_tower_perspective"]},
					"priority": 30,
					"once": true,
					"line": "Once you have seen the island from Bagua, the postcard rack feels almost embarrassed. Little rectangles trying to carry whole verandas, stair rails, and rooflines home. Still, people keep buying them because they know those details matter.",
					"journal_step": "An treated the postcard rack like proof that people can recognize an inheritance even when they only carry part of it away.",
				},
			],
		},
		{
			"id": "dock_musician_pei",
			"display_name": "Dock Musician Pei",
			"landmark": "Piano Ferry",
			"role": "Tests small melodic fragments on a weathered travel violin.",
			"routine_note": "Usually perched on a crate where the sea breeze can carry the sound.",
			"melody_hint": "He notices when the harbor chords stop resolving cleanly.",
			"ambient_lines": [
				"The sea wind keeps taking the last note somewhere inland.",
				"I only need one honest phrase before the harbor can sing along again.",
			],
			"dialogue_beats": [
				{
					"line": "Everyone keeps talking about the year ahead as if your future were already scheduled. That kind of pressure can make even a harbor sound sharp. You do not have to pretend it feels normal.",
					"objective": "Come back to Dock Musician Pei once the year has turned far enough to speak honestly about the future.",
					"journal_step": "Pei heard the exam pressure in the harbor before you said it out loud.",
					"gate_fallback": "The harbor is still trying to become a real homecoming. Let Lian settle that first, then we can talk about why the future already sounds too loud.",
					"story_event": "autumn_pressure_named",
					"save_status": "Dock Musician Pei named the pressure hanging over the year.",
				},
				{
					"line": "After a year like this, honesty matters more than certainty. Name one future that is yours before the island asks anything else of you.",
					"objective": "Stay with Pei until the year breaks open into second summer.",
					"journal_step": "Pei pushed the future question away from prestige and toward honesty.",
					"gate_fallback": "The future question is real, but it needs both the shared autumn pressure and the Spring Festival harbor before it can be answered honestly.",
					"story_event": "future_commitment_choice",
					"save_status": "Dock Musician Pei reframed the future as an honest choice instead of a performance.",
				},
				{
					"line": "The exam is finally over. Listen to the harbor now: it is quieter, but it is not empty. What remains is the part nobody else could rank for you.",
					"objective": "Take a quiet moment at the harbor before choosing whether to leave or remain with what the island now means.",
					"journal_step": "Pei named the strange quiet after the exam and treated it like the start of second summer.",
					"gate_fallback": "Name one future honestly first. The stranger quiet comes after that.",
					"story_event": "summer_exam_complete",
					"save_status": "Dock Musician Pei marked the exam's end and the arrival of second summer.",
				},
			],
			"appearance": _look(
				"male",
				"olive",
				"head/heads/human/heads_human_male_gaunt",
				"hair/curly/hair_curly_short",
				"black",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_scoop",
				"navy",
				"legs/pants/legs_pants",
				"gray",
				"feet/shoes/feet_shoes_basic",
				"black"
			),
			"spawn": _spawn("Piano Ferry", Vector2(220.0, 220.0), 30.0, MOOD_BLUSH),
		},
		{
			"id": "tea_vendor_hua",
			"display_name": "Tea Vendor Hua",
			"landmark": "Piano Ferry",
			"role": "Keeps warm tea ready for arrivals, porters, and anyone waiting out the mist.",
			"routine_note": "Usually near the plaza edge where the smell of tea reaches the dock.",
			"melody_hint": "She says the kettle whistles in a lower key than usual.",
			"ambient_lines": [
				"My kettle still tries to whistle the opening bar every morning.",
				"The day the island settles, even the tea steam will rise in time.",
			],
			"appearance": _look(
				"female",
				"taupe",
				"head/heads/human/heads_human_female",
				"hair/bob/hair_relm_short",
				"black",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_scoop",
				"forest",
				"legs/pants/legs_formal",
				"brown",
				"feet/shoes/feet_shoes_revised",
				"leather"
			),
			"spawn": _spawn("Piano Ferry", Vector2(320.0, 140.0), 85.0, MOOD_SMILE),
			"conditional_beats": [
				{
					"conditions": {"story_flag_all": ["winter_memory_reveal", "preservation_inheritance_seen"]},
					"priority": 20,
					"once": true,
					"line": "I already started steeping extra chrysanthemum for the festival week, and every time I do it I remember your grandmother setting aside the first cup before anyone asked. The harbor has noticed this Spring Festival is arriving differently.",
					"objective": "Go back to Lian once the harbor's Spring Festival preparations feel impossible to ignore.",
					"journal_step": "Hua made the Spring Festival feel prepared by the harbor before it was spoken aloud at home.",
					"story_event": "spring_festival_prepared",
					"save_status": "Tea Vendor Hua turned Spring Festival from an upcoming date into something the harbor is already carrying.",
				},
				{
					"conditions": {"story_flag_all": ["spring_festival_resolved"]},
					"priority": 30,
					"once": true,
					"line": "I still set out one extra cup before dawn. A Po notices it, I notice that she notices it, and suddenly the whole stall understands what kind of festival week this is.",
					"journal_step": "Hua marked the festival aftermath through the extra cup everyone notices but nobody needs explained.",
				},
			],
		},
		{
			"id": "ticket_clerk_min",
			"display_name": "Ticket Clerk Min",
			"landmark": "Piano Ferry",
			"role": "Balances the outbound ledger and keeps track of ferry timings.",
			"routine_note": "Usually near the timetable board or ticket desk.",
			"melody_hint": "She hears the lost melody as a schedule that never quite departs on time.",
			"ambient_lines": [
				"The timetable looks correct, but the platform still feels early somehow.",
				"I trust clocks less than footsteps when the island goes quiet like this.",
			],
			"conditional_beats": [
				{
					"conditions": {"story_flag_all": ["future_commitment_choice"]},
					"priority": 30,
					"once": true,
					"line": "I can hear when someone is speaking about departure as a timetable and when they are speaking about it as a truth. Whatever you named with Pei, it sounds like something the harbor should witness before anyone tries to close the book on it.",
					"objective": "Return to Lian if this future feels steady enough to let the harbor answer it.",
					"journal_step": "Min witnessed the future you named and treated it like something the harbor could now answer back.",
					"story_event": "future_commitment_witnessed",
					"save_status": "Ticket Clerk Min heard the future-choice turning point and sent it back into the harbor to be answered.",
				},
			],
			"appearance": _look(
				"female",
				"light",
				"head/heads/human/heads_human_female",
				"hair/short/hair_parted",
				"ash",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_cardigan",
				"bluegray",
				"legs/pants/legs_formal",
				"navy",
				"feet/shoes/feet_shoes_revised",
				"black"
			),
			"spawn": _spawn("Piano Ferry", Vector2(120.0, 360.0), -10.0, MOOD_NORMAL),
		},
		{
			"id": "choir_student_lin",
			"display_name": "Choir Student Lin",
			"landmark": "Trinity Church",
			"role": "Practices choir entrances and marks uncertain notes in a tiny booklet.",
			"routine_note": "Usually near the church steps or outer choir wall.",
			"melody_hint": "She can still hear where the church phrase should breathe.",
			"ambient_lines": [
				"I know where the choir should inhale, but not where the phrase lands.",
				"The bells only sound lonely because they have no voices to answer them.",
			],
			"appearance": _look(
				"female",
				"light",
				"head/heads/human/heads_human_female",
				"hair/long/hair_bangslong",
				"platinum",
				"torso/shirts/shortsleeve/torso_clothes_tshirt_vneck",
				"lavender",
				"legs/pants/legs_pants2",
				"charcoal",
				"feet/shoes/feet_shoes_basic",
				"black"
			),
			"spawn": _spawn("Trinity Church", Vector2(-160.0, 290.0), -100.0, MOOD_BLUSH),
			"conditional_beats": [
				{
					"conditions": {"story_flag_all": ["autumn_pressure_named"]},
					"priority": 20,
					"once": true,
					"line": "Everyone talks about next year like there is a right note we are all supposed to hit together. I keep worrying I will only find out mine after everyone else has already sung theirs. It helps a little to know the fear is shared, even if that does not make it quieter.",
					"objective": "Carry that shared pressure back into the harbor before you try to answer the future question.",
					"journal_step": "Lin admitted the same pressure is shaping the church side of the island too, which made the fear feel shared instead of private.",
					"story_event": "autumn_pressure_shared",
					"save_status": "Choir Student Lin made the autumn pressure feel communal instead of solitary.",
				},
				{
					"conditions": {"story_flag_all": ["future_commitment_choice"]},
					"priority": 30,
					"once": true,
					"line": "When someone names a future honestly, the choir air changes. It does not make the next note easy. It just makes it sound like it belongs to the singer at last.",
					"journal_step": "Lin heard honesty change the sound of the future, even before it made anything easier.",
				},
			],
		},
		{
			"id": "mural_restorer_cai",
			"display_name": "Mural Restorer Cai",
			"landmark": "Bi Shan Tunnel",
			"role": "Brushes dust from tunnel murals and traces where old pigments still glint.",
			"routine_note": "Usually near the first tunnel wall that still catches lantern light.",
			"melody_hint": "She believes the murals were painted to match a procession tune.",
			"ambient_lines": [
				"Color lasts longer underground when the air remembers it.",
				"The mural patterns look almost musical if you stop trying to read them as pictures.",
			],
			"appearance": _look(
				"female",
				"amber",
				"head/heads/human/heads_human_female",
				"hair/bob/hair_relm_short",
				"chestnut",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_scoop",
				"orange",
				"legs/pants/legs_pants",
				"tan",
				"feet/shoes/feet_shoes_revised",
				"brown"
			),
			"spawn": _spawn("Bi Shan Tunnel", Vector2(-224.0, -592.0), -85.0, MOOD_SMILE),
		},
		{
			"id": "tunnel_listener_nuo",
			"display_name": "Tunnel Listener Nuo",
			"landmark": "Bi Shan Tunnel",
			"role": "Listens at the mouth of the tunnel and paces between the entrance and the first echo pocket.",
			"routine_note": "Usually moving between the southern entrance and the first chamber.",
			"melody_hint": "She notices when an echo lands on the wrong emotional beat.",
			"ambient_lines": [
				"You can tell which corridor is lying by how eager it sounds.",
				"I only follow echoes that arrive like an invitation instead of a dare.",
			],
			"appearance": _look(
				"female",
				"olive",
				"head/heads/human/heads_human_female",
				"hair/curly/hair_curly_short",
				"dark brown",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_cardigan",
				"teal",
				"legs/pants/legs_formal",
				"slate",
				"feet/shoes/feet_shoes_revised",
				"gray"
			),
			"spawn": _spawn("Bi Shan Tunnel", Vector2(-128.0, -32.0), 10.0, MOOD_SHAME),
			"movement": _route(
				[
					_route_point("Bi Shan Tunnel", Vector2(-128.0, -32.0), 1.0, 1.0),
					_route_point("Bi Shan Tunnel South Portal", Vector2(40.0, 0.0), 0.0, 0.0),
					_route_point("Bi Shan Tunnel South", Vector2(288.0, -144.0), 1.8, 1.8),
				],
				24.0,
				0.4,
				0.9
			),
		},
		{
			"id": "raincoat_child_xiu",
			"display_name": "Raincoat Child Xiu",
			"landmark": "Long Shan Tunnel",
			"role": "Collects polished pebbles and treats every tunnel as a weather story.",
			"routine_note": "Usually in the first lit stretch of the tunnel.",
			"melody_hint": "They notice which tunnel sounds brave and which sounds lonely.",
			"ambient_lines": [
				"This tunnel sounds like it wants company.",
				"I only come here when the grown-ups say the light feels friendly.",
			],
			"appearance": _look(
				"female",
				"light",
				"head/heads/human/heads_human_female_small",
				"hair/bob/hair_relm_short",
				"redhead",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_polo",
				"yellow",
				"legs/pants/legs_pants2",
				"blue",
				"feet/shoes/feet_shoes_basic",
				"brown"
			),
			"spawn": _spawn("Long Shan Tunnel", Vector2(-608.0, -208.0), -75.0, MOOD_SHOCK),
		},
		{
			"id": "storyteller_wen",
			"display_name": "Storyteller Wen",
			"landmark": "Long Shan Tunnel",
			"role": "Keeps nearby children calm by turning the tunnel into a story with gentle pacing.",
			"routine_note": "Usually on a dry stone a little way inside the tunnel, waiting for nervous walkers.",
			"melody_hint": "She says the melody through Long Shan needs reassurance more than volume.",
			"ambient_lines": [
				"The trick is not to outrun the tunnel. It dislikes being treated like a race.",
				"If you tell a calm story while you walk, even the dark keeps pace.",
			],
			"appearance": _look(
				"female",
				"amber",
				"head/heads/human/heads_human_female_elderly",
				"hair/bob/hair_bob_side_part",
				"white",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_cardigan",
				"rose",
				"legs/pants/legs_formal",
				"brown",
				"feet/shoes/feet_shoes_revised",
				"black"
			),
			"spawn": _spawn("Long Shan Tunnel", Vector2(-1024.0, -448.0), -20.0, MOOD_SMILE),
		},
		{
			"id": "rope_handler_qiu",
			"display_name": "Rope Handler Qiu",
			"landmark": "Long Shan Tunnel",
			"role": "Checks guide ropes and marks places where nervous walkers usually slow down.",
			"routine_note": "Usually near the first secure line into the tunnel.",
			"melody_hint": "He trusts routes that stay even, not routes that sound loud.",
			"ambient_lines": [
				"Every safe route has a pace people agree on without speaking.",
				"If the rope starts feeling too necessary, I know the light ahead needs help.",
			],
			"appearance": _look(
				"male",
				"olive",
				"head/heads/human/heads_human_male",
				"hair/short/hair_parted",
				"chestnut",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_polo",
				"forest",
				"legs/pants/legs_pants2",
				"walnut",
				"feet/shoes/feet_shoes_revised",
				"brown"
			),
			"spawn": _spawn("Long Shan Tunnel", Vector2(-1408.0, -672.0), 25.0, MOOD_NORMAL),
		},
		{
			"id": "porter_shan",
			"display_name": "Porter Shan",
			"landmark": "Long Shan Tunnel",
			"role": "Helps move supplies through the longer route when the safer lights are on.",
			"routine_note": "Usually leaning on a crate where the path widens a little.",
			"melody_hint": "He notices how a steady step can calm a frightened route.",
			"ambient_lines": [
				"I can carry the crates. Keeping the pace calm is the real work.",
				"Heavy footsteps are easy. Reassuring footsteps take practice.",
			],
			"appearance": _look(
				"male",
				"brown",
				"head/heads/human/heads_human_male_plump",
				"hair/curly/hair_curly_short",
				"black",
				"torso/shirts/shortsleeve/torso_clothes_shortsleeve_polo",
				"bluegray",
				"legs/pants/legs_pants",
				"charcoal",
				"feet/shoes/feet_shoes_basic",
				"leather"
			),
			"spawn": _spawn("Long Shan Tunnel", Vector2(-1760.0, -880.0), 70.0, MOOD_SMILE),
		},
		{
			"id": "light_watcher_he",
			"display_name": "Light Watcher He",
			"landmark": "Long Shan Tunnel",
			"role": "Keeps count of which pools of light feel strong enough for a safe crossing.",
			"routine_note": "Usually at the last bright patch before the tunnel deepens.",
			"melody_hint": "She says the melody only holds together here when the light stays kind.",
			"ambient_lines": [
				"The tunnel is easier when the light arrives before the fear does.",
				"I mark the patient lights. They are the ones people trust twice.",
			],
			"appearance": _look(
				"female",
				"taupe",
				"head/heads/human/heads_human_female",
				"hair/long/hair_wavy",
				"dark gray",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_scoop",
				"teal",
				"legs/pants/legs_pants2",
				"gray",
				"feet/shoes/feet_shoes_revised",
				"black"
			),
			"spawn": _spawn("Long Shan Tunnel", Vector2(-1984.0, -1184.0), -5.0, MOOD_SHAME),
		},
		{
			"id": "terrace_painter_nian",
			"display_name": "Terrace Painter Nian",
			"landmark": "Bagua Tower",
			"role": "Paints the tower terraces when the weather reveals enough of the harbor line.",
			"routine_note": "Usually on the lower terrace with a half-finished island study.",
			"melody_hint": "She says the island looks most musical when painted from above.",
			"ambient_lines": [
				"The island only starts composing itself when you climb high enough.",
				"I paint the gaps between landmarks first. That is where the melody hides.",
			],
			"dialogue_beats": [
				{
					"line": "From up here the old buildings stop looking decorative. They start looking like the shape of everyone who kept living here long enough to leave traces behind. That is why losing them hurts.",
					"objective": "Carry that wider view back into the year and notice what the island is asking you to preserve.",
					"journal_step": "Nian widened the inheritance question from a harbor feeling into an island-scale view.",
					"gate_fallback": "The tower view will land better after someone at the harbor first makes preservation feel urgent rather than picturesque.",
					"story_event": "preservation_tower_perspective",
					"save_status": "Terrace Painter Nian widened preservation from a feeling into a responsibility.",
				},
				{
					"line": "Once you see the island that way, every wall and window starts sounding like a memory someone trusted the next person to keep.",
					"journal_step": "Nian keeps treating the island's older buildings as memory made visible.",
					"save_status": "Spoke with Terrace Painter Nian",
				},
			],
			"appearance": _look(
				"female",
				"olive",
				"head/heads/human/heads_human_female",
				"hair/braids/hair_ponytail",
				"black",
				"torso/shirts/shortsleeve/torso_clothes_tshirt_vneck",
				"sky",
				"legs/pants/legs_pants2",
				"tan",
				"feet/shoes/feet_shoes_basic",
				"brown"
			),
			"spawn": _spawn("Bagua Tower", Vector2(-80.0, 330.0), -90.0, MOOD_BLUSH),
		},
		{
			"id": "map_student_jia",
			"display_name": "Map Student Jia",
			"landmark": "Bagua Tower",
			"role": "Sketches route diagrams and keeps revising them whenever an old route becomes easier to trust.",
			"routine_note": "Usually close to the lower stairs with paper spread on a crate.",
			"melody_hint": "They think the melody can be mapped as a route between trusted places.",
			"ambient_lines": [
				"From here, even a rumor starts looking like a path.",
				"The island gets easier to read once you stop drawing it flat.",
			],
			"appearance": _look(
				"male",
				"light",
				"head/heads/human/heads_human_male",
				"hair/short/hair_parted",
				"ash",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_polo",
				"blue",
				"legs/pants/legs_pants2",
				"navy",
				"feet/shoes/feet_shoes_basic",
				"black"
			),
			"spawn": _spawn("Bagua Tower", Vector2(80.0, 360.0), -35.0, MOOD_SMILE),
			"conditional_beats": [
				{
					"conditions": {"story_flag_all": ["preservation_tower_perspective"]},
					"priority": 20,
					"once": true,
					"line": "Once Nian points out the old roofs from above, the map stops being directions and starts being custody. Every line I draw now feels like a promise not to forget where the island learned to keep itself.",
					"journal_step": "Jia turned mapping into stewardship after the tower made preservation feel island-wide.",
				},
			],
		},
		{
			"id": "view_guide_lio",
			"display_name": "View Guide Lio",
			"landmark": "Bagua Tower",
			"role": "Points out landmarks for visitors and quietly corrects their sense of direction.",
			"routine_note": "Usually near the outer railing where people first stop to orient themselves.",
			"melody_hint": "He says the melody makes more sense when each district is treated like one voice.",
			"ambient_lines": [
				"People think this tower gives answers. Mostly it gives proportions.",
				"From here the church, harbor, and tunnels sound like they were always meant to answer each other.",
			],
			"appearance": _look(
				"male",
				"taupe",
				"head/heads/human/heads_human_male_plump",
				"hair/long/hair_long_straight",
				"dark brown",
				"torso/shirts/shortsleeve/torso_clothes_shortsleeve_polo",
				"slate",
				"legs/pants/legs_pants2",
				"walnut",
				"feet/shoes/feet_shoes_basic",
				"tan"
			),
			"spawn": _spawn("Bagua Tower", Vector2(360.0, 220.0), 55.0, MOOD_SMILE),
		},
		{
			"id": "window_caretaker_su",
			"display_name": "Window Caretaker Su",
			"landmark": "Bagua Tower",
			"role": "Keeps the tower shutters opening cleanly so the island view stays legible.",
			"routine_note": "Usually near a stack of cloths and half-open shutters.",
			"melody_hint": "She thinks the island's tune looks like light moving across windows.",
			"ambient_lines": [
				"If the shutters stick, the island feels smaller than it is.",
				"Clean windows do not add music. They just stop getting in its way.",
			],
			"appearance": _look(
				"female",
				"amber",
				"head/heads/human/heads_human_female",
				"hair/bob/hair_relm_short",
				"dark brown",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_cardigan",
				"lavender",
				"legs/pants/legs_pants",
				"navy",
				"feet/shoes/feet_shoes_revised",
				"gray"
			),
			"spawn": _spawn("Bagua Tower", Vector2(120.0, 180.0), -15.0, MOOD_NORMAL),
			"conditional_beats": [
				{
					"conditions": {"melody_state": {"festival_melody": "resonant"}},
					"priority": 20,
					"once": true,
					"line": "After the festival, the shutters still rattle in time even when the terrace is empty. It feels like the island finally learned how to keep its own light aligned.",
					"journal_step": "Su noticed the island keep the festival melody quietly alive in the empty tower shutters.",
				},
			],
		},
	]

	for spec_value in specs:
		if typeof(spec_value) != TYPE_DICTIONARY:
			continue

		var spec: Dictionary = spec_value
		var resident_id: String = String(spec.get("id", ""))
		if resident_id.is_empty():
			continue

		var ambient_lines: Array = spec.get("ambient_lines", [])
		var appearance = spec.get("appearance")
		var spawn = spec.get("spawn")
		var movement = spec.get("movement")
		var dialogue_beats: Array = spec.get("dialogue_beats", [])
		var conditional_beats: Array = spec.get("conditional_beats", [])

		if dialogue_beats.is_empty() and conditional_beats.is_empty():
			residents[resident_id] = _ambient_resident(
				String(spec.get("display_name", resident_id)),
				String(spec.get("landmark", "Island Paths")),
				String(spec.get("role", "")),
				String(spec.get("routine_note", "")),
				String(spec.get("melody_hint", "")),
				ambient_lines,
				appearance,
				spawn,
				movement
			)
			continue

		if dialogue_beats.is_empty():
			dialogue_beats = _ambient_beats(
				String(spec.get("display_name", resident_id)),
				String(spec.get("landmark", "Island Paths")),
				ambient_lines
			)

		residents[resident_id] = _resident(
			String(spec.get("display_name", resident_id)),
			String(spec.get("landmark", "Island Paths")),
			String(spec.get("role", "")),
			String(spec.get("routine_note", "")),
			String(spec.get("melody_hint", "")),
			ambient_lines,
			dialogue_beats,
			appearance,
			spawn,
			movement,
			conditional_beats
		)

	return residents


static func _ambient_resident(
	display_name: String,
	landmark: String,
	role: String,
	routine_note: String,
	melody_hint: String,
	ambient_lines: Array,
	appearance,
	spawn,
	movement = null
) -> ResidentDefinition:
	return _resident(
		display_name,
		landmark,
		role,
		routine_note,
		melody_hint,
		ambient_lines,
		_ambient_beats(display_name, landmark, ambient_lines),
		appearance,
		spawn,
		movement
	)


static func _ambient_beats(display_name: String, landmark: String, ambient_lines: Array) -> Array[ResidentDialogueBeatDefinition]:
	var beats: Array[ResidentDialogueBeatDefinition] = []

	for line_value in ambient_lines:
		var line: String = String(line_value).strip_edges()
		if line.is_empty():
			continue

		beats.append(_dialogue_beat_from_dictionary({
			"line": line,
			"journal_step": "Heard a local note from %s near %s." % [display_name, landmark],
			"save_status": "Spoke with %s" % display_name,
			"trust_delta": 0,
		}))

	if beats.is_empty():
		beats.append(_dialogue_beat_from_dictionary({
			"line": "%s shares a quiet nod." % display_name,
			"journal_step": "Met %s near %s." % [display_name, landmark],
			"save_status": "Spoke with %s" % display_name,
			"trust_delta": 0,
		}))

	return beats


static func _coerce_dialogue_beat_definition(beat_value) -> ResidentDialogueBeatDefinition:
	if beat_value == null:
		return null
	if beat_value is ResidentDialogueBeatDefinition:
		return beat_value
	if beat_value is Dictionary:
		return _dialogue_beat_from_dictionary(beat_value)
	return null


static func _coerce_conditional_beat_definition(beat_value) -> ResidentConditionalBeatDefinition:
	if beat_value == null:
		return null
	if beat_value is ResidentConditionalBeatDefinition:
		return beat_value
	if beat_value is Dictionary:
		return _conditional_beat_from_dictionary(beat_value)
	return null


static func _dialogue_beat_from_dictionary(beat_data: Dictionary) -> ResidentDialogueBeatDefinition:
	var definition: ResidentDialogueBeatDefinition = RESIDENT_DIALOGUE_BEAT_DEFINITION_SCRIPT.new()
	_populate_dialogue_beat_definition(definition, beat_data)
	return definition


static func _conditional_beat_from_dictionary(beat_data: Dictionary) -> ResidentConditionalBeatDefinition:
	var definition: ResidentConditionalBeatDefinition = RESIDENT_CONDITIONAL_BEAT_DEFINITION_SCRIPT.new()
	_populate_dialogue_beat_definition(
		definition,
		beat_data,
		PackedStringArray(["conditions", "priority", "once"])
	)
	definition.conditions = _coerce_beat_conditions_definition(beat_data.get("conditions"))
	if beat_data.has("priority"):
		definition.priority = int(beat_data.get("priority", 0))
	if beat_data.has("once"):
		definition.once = bool(beat_data.get("once", false))
	return definition


static func _coerce_beat_conditions_definition(conditions_value) -> ResidentBeatConditionsDefinition:
	if conditions_value == null:
		return null
	if conditions_value is ResidentBeatConditionsDefinition:
		return conditions_value
	if conditions_value is Dictionary:
		return _beat_conditions_from_dictionary(conditions_value)
	return null


static func _beat_conditions_from_dictionary(conditions_data: Dictionary) -> ResidentBeatConditionsDefinition:
	var definition: ResidentBeatConditionsDefinition = RESIDENT_BEAT_CONDITIONS_DEFINITION_SCRIPT.new()
	var extra_conditions := conditions_data.duplicate(true)

	var landmark_state_value = conditions_data.get("landmark_state")
	if landmark_state_value is Dictionary:
		definition.required_landmark_states = (landmark_state_value as Dictionary).duplicate(true)
		extra_conditions.erase("landmark_state")

	var melody_state_value = conditions_data.get("melody_state")
	if melody_state_value is Dictionary:
		definition.required_melody_states = (melody_state_value as Dictionary).duplicate(true)
		extra_conditions.erase("melody_state")

	if conditions_data.has("fragments_found_min"):
		definition.fragments_found_min = int(conditions_data.get("fragments_found_min", -1))
		extra_conditions.erase("fragments_found_min")
	if conditions_data.has("trust_min"):
		definition.trust_min = int(conditions_data.get("trust_min", -1))
		extra_conditions.erase("trust_min")
	if conditions_data.has("chapter"):
		definition.required_chapter = String(conditions_data.get("chapter", ""))
		extra_conditions.erase("chapter")
	if conditions_data.has("mode"):
		definition.required_mode = String(conditions_data.get("mode", ""))
		extra_conditions.erase("mode")
	if conditions_data.has("resident_known"):
		var resident_known_value = conditions_data.get("resident_known", [])
		var known_ids := PackedStringArray()
		if resident_known_value is Array:
			for resident_id_value in resident_known_value:
				known_ids.append(String(resident_id_value))
		definition.required_known_resident_ids = known_ids
		extra_conditions.erase("resident_known")

	definition.extra_conditions = extra_conditions
	return definition


static func _populate_dialogue_beat_definition(
	definition: ResidentDialogueBeatDefinition,
	beat_data: Dictionary,
	extra_skip_keys: PackedStringArray = PackedStringArray()
) -> void:
	if beat_data.has("line"):
		definition.line = String(beat_data.get("line", ""))
	if beat_data.has("objective"):
		definition.objective = String(beat_data.get("objective", ""))
	if beat_data.has("journal_step"):
		definition.journal_step = String(beat_data.get("journal_step", ""))
	if beat_data.has("hint"):
		definition.hint = String(beat_data.get("hint", ""))
	if beat_data.has("chapter"):
		definition.chapter = String(beat_data.get("chapter", ""))
	if beat_data.has("quest_state"):
		definition.quest_state = String(beat_data.get("quest_state", ""))
	if beat_data.has("trust_delta"):
		definition.trust_delta = int(beat_data.get("trust_delta", 0))
	if beat_data.has("save_status"):
		definition.save_status = String(beat_data.get("save_status", ""))
	var landmark_states_value = beat_data.get("landmark_states")
	if landmark_states_value is Dictionary:
		definition.landmark_states = (landmark_states_value as Dictionary).duplicate(true)
	if beat_data.has("unlock_landmark"):
		definition.unlock_landmark = String(beat_data.get("unlock_landmark", ""))
	if beat_data.has("landmark_reward"):
		definition.landmark_reward = String(beat_data.get("landmark_reward", ""))
	if beat_data.has("gate"):
		definition.gate = String(beat_data.get("gate", ""))
	if beat_data.has("gate_fallback"):
		definition.gate_fallback = String(beat_data.get("gate_fallback", ""))

	var handled_keys := PackedStringArray([
		"line",
		"objective",
		"journal_step",
		"hint",
		"chapter",
		"quest_state",
		"trust_delta",
		"save_status",
		"landmark_states",
		"unlock_landmark",
		"landmark_reward",
		"gate",
		"gate_fallback",
	])
	for key in extra_skip_keys:
		if handled_keys.find(key) < 0:
			handled_keys.append(key)
	definition.extra_fields = _extract_remaining_fields(beat_data, handled_keys)


static func _extract_remaining_fields(source: Dictionary, handled_keys: PackedStringArray) -> Dictionary:
	var remaining := source.duplicate(true)
	for key in handled_keys:
		remaining.erase(String(key))
	return remaining


static func _resident(
	display_name: String,
	landmark: String,
	role: String,
	routine_note: String,
	melody_hint: String,
	ambient_lines: Array,
	dialogue_beats: Array,
	appearance,
	spawn,
	movement = null,
	conditional_beats: Array = []
) -> ResidentDefinition:
	var dialogue: ResidentDialogueDefinition = RESIDENT_DIALOGUE_DEFINITION_SCRIPT.new()
	dialogue.set_ambient_lines_from_array(ambient_lines)
	for beat_value in dialogue_beats:
		var beat_definition := _coerce_dialogue_beat_definition(beat_value)
		if beat_definition != null:
			dialogue.dialogue_beats.append(beat_definition)
	for conditional_value in conditional_beats:
		var conditional_definition := _coerce_conditional_beat_definition(conditional_value)
		if conditional_definition != null:
			dialogue.conditional_beats.append(conditional_definition)

	if movement is Dictionary and movement.is_empty():
		movement = null

	var routine: ResidentRoutineDefinition = RESIDENT_ROUTINE_DEFINITION_SCRIPT.new()
	routine.spawn = spawn
	routine.movement = movement

	var definition: ResidentDefinition = RESIDENT_DEFINITION_SCRIPT.new()
	definition.display_name = display_name
	definition.landmark = landmark
	definition.role = role
	definition.routine_note = routine_note
	definition.melody_hint = melody_hint
	definition.appearance = appearance
	definition.dialogue = dialogue
	definition.routine = routine
	return definition


static func _spawn(
	anchor_id: String,
	offset: Vector2,
	direction: float,
	mood: int = MOOD_NORMAL,
	interaction_radius: float = 72.0
) -> ResidentSpawnDefinition:
	var definition: ResidentSpawnDefinition = RESIDENT_SPAWN_DEFINITION_SCRIPT.new()
	definition.anchor_id = anchor_id
	definition.offset = offset
	definition.direction = direction
	definition.mood = mood
	definition.interaction_radius = interaction_radius
	return definition


static func _route(
	route_points: Array,
	arrival_radius: float = 24.0,
	wait_min_sec: float = 0.5,
	wait_max_sec: float = 1.2,
	ping_pong: bool = true
) -> ResidentMovementDefinition:
	var definition: ResidentMovementDefinition = RESIDENT_MOVEMENT_DEFINITION_SCRIPT.new()
	definition.arrival_radius = arrival_radius
	definition.wait_min_sec = wait_min_sec
	definition.wait_max_sec = wait_max_sec
	definition.ping_pong = ping_pong
	for point_value in route_points:
		if point_value == null:
			continue
		definition.route_points.append(point_value)
	return definition


static func _route_point(
	anchor_id: String,
	offset: Vector2 = Vector2.ZERO,
	wait_min_sec: float = -1.0,
	wait_max_sec: float = -1.0
) -> ResidentRoutePointDefinition:
	var definition: ResidentRoutePointDefinition = RESIDENT_ROUTE_POINT_DEFINITION_SCRIPT.new()
	definition.anchor_id = anchor_id
	definition.offset = offset
	definition.wait_min_sec = wait_min_sec
	definition.wait_max_sec = wait_max_sec
	return definition


static func _look(
	body_type: String,
	skin: String,
	head_path: String,
	hair_path: String,
	hair_color: String,
	shirt_path: String,
	shirt_color: String,
	pants_path: String,
	pants_color: String,
	shoes_path: String,
	shoes_color: String,
	extra_selections: Dictionary = {}
) -> ResidentAppearanceDefinition:
	var definition: ResidentAppearanceDefinition = RESIDENT_APPEARANCE_DEFINITION_SCRIPT.new()
	definition.body_type = body_type
	definition.body_type_index_override = _body_type_index(body_type)
	definition.skin = skin
	definition.head_path = head_path
	definition.hair_path = hair_path
	definition.hair_color = hair_color
	definition.shirt_path = shirt_path
	definition.shirt_color = shirt_color
	definition.pants_path = pants_path
	definition.pants_color = pants_color
	definition.shoes_path = shoes_path
	definition.shoes_color = shoes_color
	definition.extra_selections = extra_selections.duplicate(true)
	return definition


static func _appearance(
	body_type: String,
	body_type_index: int,
	selections: Dictionary
) -> ResidentAppearanceDefinition:
	var definition: ResidentAppearanceDefinition = RESIDENT_APPEARANCE_DEFINITION_SCRIPT.new()
	definition.body_type = body_type
	definition.body_type_index_override = body_type_index
	definition.selections = selections.duplicate(true)
	return definition


static func _body_type_index(body_type: String) -> int:
	match body_type:
		"male":
			return 0
		"female":
			return 1
		"teen":
			return 2
		"child":
			return 3
		"muscular":
			return 4
		"pregnant":
			return 5
		_:
			return 0
