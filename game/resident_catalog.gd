class_name ResidentCatalog
extends RefCounted

const MAX_TRUST := 3
const MOOD_NORMAL := 1
const MOOD_SMILE := 2
const MOOD_BLUSH := 3
const MOOD_ANGRY := 4
const MOOD_SAD := 5
const MOOD_SHAME := 6
const MOOD_SHOCK := 7


static func max_trust() -> int:
	return MAX_TRUST


static func resident_order() -> Array[String]:
	return [
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


static func build_defaults() -> Dictionary:
	var residents: Dictionary = {}
	residents.merge(_story_residents(), true)
	residents.merge(_ambient_residents(), true)
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
					"line": "You hear it too, don't you? The island is holding its breath. Start with Trinity Church; its bells still remember the first phrase.",
					"objective": "Speak with the church caretaker.",
					"journal_step": "Pointed you toward Trinity Church as the cleanest first lead.",
					"hint": "R Talk   J Journal   Esc Pause",
					"chapter": "First Lead",
					"quest_state": "introduced",
					"trust_delta": 1,
					"save_status": "Resident note added: Caretaker Lian",
				"unlock_landmark": "trinity_church",
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
			_spawn("Piano Ferry", Vector2(-260.0, 180.0), -150.0, MOOD_NORMAL, 88.0)
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
					"gate": "trinity_church_cues",
					"gate_fallback": "The choir cues are still scattered across the grounds. Keep searching near the steps, the side garden, and the quiet yard.",
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
			_spawn("Trinity Church", Vector2(-300.0, 210.0), -130.0, MOOD_SMILE, 88.0)
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
					"landmark_states": {"long_shan_tunnel": "introduced"},
					"trust_delta": 1,
					"save_status": "Resident note added: Tunnel Guide Ren",
				},
				{
					"line": "If I call out, come back to the last lit pocket instead of pushing ahead. The route only works if we can both still hear each other.",
					"objective": "Keep Ren close to the lit route through Long Shan Tunnel.",
					"journal_step": "Explained that distance, not danger, is the main escort failure point.",
					"quest_state": "in_progress",
					"landmark_states": {"long_shan_tunnel": "in_progress"},
					"trust_delta": 1,
					"save_status": "Tunnel Guide Ren explained the escort rhythm",
				},
				{
					"line": "Once we are through, I can point you toward the tower. High places make the scattered phrases finally line up.",
					"objective": "Reach Bagua Tower after the tunnel escort.",
					"journal_step": "Ready to redirect you toward Bagua Tower after the escort resolves.",
					"quest_state": "resolved",
					"gate": "long_shan_exit_reached",
					"gate_fallback": "The passage is not done yet. Stay close and keep moving toward the exit.",
					"unlock_landmark": "bagua_tower",
					"trust_delta": 1,
					"save_status": "Tunnel Guide Ren opened the route toward Bagua Tower",
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
			_spawn("Long Shan Tunnel South", Vector2(-220.0, 200.0), -110.0, MOOD_SAD, 88.0)
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
					"landmark_states": {"bagua_tower": "available"},
					"trust_delta": 1,
					"save_status": "Resident note added: Tower Keeper Suyin",
				},
				{
					"line": "When you return, lay the fragments beside each other instead of in sequence. The island's shape matters as much as the notes.",
					"objective": "Compare recovered melody fragments at Bagua Tower.",
					"journal_step": "Preparing to turn separate phrases into one island-scale reading.",
					"quest_state": "introduced",
					"landmark_states": {"bagua_tower": "in_progress"},
					"trust_delta": 1,
					"save_status": "Tower Keeper Suyin reframed the tower as a synthesis space",
				},
				{
					"line": "From the top chamber, even silence has direction. That is when the final festival route becomes obvious.",
					"objective": "Use Bagua Tower to reveal the festival route.",
					"journal_step": "Waiting to reveal the final route once enough fragments are in hand.",
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
			_spawn("Bagua Tower", Vector2(-220.0, 260.0), -120.0, MOOD_NORMAL, 88.0)
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
		},
		{
			"id": "bell_repairer_qiao",
			"display_name": "Bell Repairer Qiao",
			"landmark": "Trinity Church",
			"role": "Checks cracked bell fittings and polishes brass that nobody notices until it sings.",
			"routine_note": "Usually along the church side path with a toolkit at his feet.",
			"melody_hint": "He measures silence by how long a bell should have kept ringing.",
			"ambient_lines": [
				"Brass remembers the hand that tuned it last.",
				"The problem is not the bell. Something around it forgot how to answer.",
			],
			"appearance": _look(
				"male",
				"amber",
				"head/heads/human/heads_human_male",
				"hair/short/hair_parted",
				"gray",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_polo",
				"tan",
				"legs/pants/legs_pants2",
				"walnut",
				"feet/shoes/feet_shoes_revised",
				"copper",
				{
					"hair/beards/beards_trimmed": "gray",
				}
			),
			"spawn": _spawn("Trinity Church", Vector2(20.0, 330.0), -35.0, MOOD_NORMAL),
		},
		{
			"id": "florist_yumei",
			"display_name": "Florist Yumei",
			"landmark": "Trinity Church",
			"role": "Refreshes flower stands that soften the church courtyard.",
			"routine_note": "Usually near the side garden gate and lily pots.",
			"melody_hint": "She says some flowers only open fully when the bells feel resolved.",
			"ambient_lines": [
				"The lilies lean toward the bell tower even when the wind says otherwise.",
				"I like to think flowers hear rehearsals before people do.",
			],
			"appearance": _look(
				"female",
				"brown",
				"head/heads/human/heads_human_female",
				"hair/braids/hair_ponytail",
				"redhead",
				"torso/shirts/shortsleeve/torso_clothes_tshirt",
				"yellow",
				"legs/pants/legs_pants",
				"forest",
				"feet/shoes/feet_shoes_basic",
				"brown"
			),
			"spawn": _spawn("Trinity Church", Vector2(200.0, 260.0), 15.0, MOOD_SMILE),
		},
		{
			"id": "echo_sketcher_yan",
			"display_name": "Echo Sketcher Yan",
			"landmark": "Bi Shan Tunnel",
			"role": "Draws tunnel corners from memory and labels them by how they sound.",
			"routine_note": "Usually near the safer side of the southern tunnel mouth.",
			"melody_hint": "He maps echoes like they are architectural lines.",
			"ambient_lines": [
				"The tunnel draws straighter on paper than it behaves in person.",
				"I trust the echoes that return rounded at the edges.",
			],
			"appearance": _look(
				"male",
				"light",
				"head/heads/human/heads_human_male",
				"hair/short/hair_parted",
				"sandy",
				"torso/shirts/shortsleeve/torso_clothes_tshirt_vneck",
				"sky",
				"legs/pants/legs_pants2",
				"brown",
				"feet/shoes/feet_shoes_basic",
				"bluegray"
			),
			"spawn": _spawn("Bi Shan Tunnel", Vector2(-120.0, -200.0), -125.0, MOOD_NORMAL),
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
			"spawn": _spawn("Bi Shan Tunnel", Vector2(-350.0, -480.0), -85.0, MOOD_SMILE),
		},
		{
			"id": "tunnel_listener_nuo",
			"display_name": "Tunnel Listener Nuo",
			"landmark": "Bi Shan Tunnel",
			"role": "Waits at the mouth of the tunnel and judges routes by the shape of returning echoes.",
			"routine_note": "Usually standing still just outside the southern entrance.",
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
			"spawn": _spawn("Bi Shan Tunnel", Vector2(-550.0, -750.0), 10.0, MOOD_SHAME),
		},
		{
			"id": "raincoat_child_xiu",
			"display_name": "Raincoat Child Xiu",
			"landmark": "Long Shan Tunnel",
			"role": "Collects polished pebbles and treats every tunnel as a weather story.",
			"routine_note": "Usually just outside the safer long tunnel approach.",
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
			"spawn": _spawn("Long Shan Tunnel South", Vector2(-80.0, 260.0), -75.0, MOOD_SHOCK),
		},
		{
			"id": "storyteller_wen",
			"display_name": "Storyteller Wen",
			"landmark": "Long Shan Tunnel",
			"role": "Keeps nearby children calm by turning the tunnel into a story with gentle pacing.",
			"routine_note": "Usually on a dry stone near the entrance, waiting for nervous walkers.",
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
			"spawn": _spawn("Long Shan Tunnel South", Vector2(70.0, 220.0), -20.0, MOOD_SMILE),
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
			"spawn": _spawn("Long Shan Tunnel South", Vector2(210.0, 160.0), 25.0, MOOD_NORMAL),
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
			"spawn": _spawn("Long Shan Tunnel South", Vector2(340.0, 100.0), 70.0, MOOD_SMILE),
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
			"spawn": _spawn("Long Shan Tunnel South", Vector2(120.0, 320.0), -5.0, MOOD_SHAME),
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
			"role": "Sketches route diagrams and keeps revising them whenever a new shortcut opens.",
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
		},
		{
			"id": "rooftop_sweeper_mo",
			"display_name": "Rooftop Sweeper Mo",
			"landmark": "Bagua Tower",
			"role": "Keeps the tower walkways clear enough for visitors to stop and notice the view.",
			"routine_note": "Usually following the terrace edge with a stiff broom.",
			"melody_hint": "He says the top of the tower hears the whole island at once.",
			"ambient_lines": [
				"Dust always gathers where people hesitate to look down.",
				"Up here the island sounds less broken and more unfinished.",
			],
			"appearance": _look(
				"male",
				"bronze",
				"head/heads/human/heads_human_male_gaunt",
				"hair/bald/hair_buzzcut",
				"black",
				"torso/shirts/longsleeve/torso_clothes_longsleeve2_polo",
				"brown",
				"legs/pants/legs_formal",
				"charcoal",
				"feet/shoes/feet_shoes_revised",
				"leather"
			),
			"spawn": _spawn("Bagua Tower", Vector2(240.0, 300.0), 10.0, MOOD_NORMAL),
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
		var appearance: Dictionary = spec.get("appearance", {})
		var spawn: Dictionary = spec.get("spawn", {})

		residents[resident_id] = _ambient_resident(
			String(spec.get("display_name", resident_id)),
			String(spec.get("landmark", "Island Paths")),
			String(spec.get("role", "")),
			String(spec.get("routine_note", "")),
			String(spec.get("melody_hint", "")),
			ambient_lines,
			appearance,
			spawn
		)

	return residents


static func _ambient_resident(
	display_name: String,
	landmark: String,
	role: String,
	routine_note: String,
	melody_hint: String,
	ambient_lines: Array,
	appearance: Dictionary,
	spawn: Dictionary
) -> Dictionary:
	return _resident(
		display_name,
		landmark,
		role,
		routine_note,
		melody_hint,
		ambient_lines,
		_ambient_beats(display_name, landmark, ambient_lines),
		appearance,
		spawn
	)


static func _ambient_beats(display_name: String, landmark: String, ambient_lines: Array) -> Array:
	var beats: Array = []

	for line_value in ambient_lines:
		var line: String = String(line_value).strip_edges()
		if line.is_empty():
			continue

		beats.append({
			"line": line,
			"journal_step": "Heard a local note from %s near %s." % [display_name, landmark],
			"save_status": "Spoke with %s" % display_name,
			"trust_delta": 0,
		})

	if beats.is_empty():
		beats.append({
			"line": "%s shares a quiet nod." % display_name,
			"journal_step": "Met %s near %s." % [display_name, landmark],
			"save_status": "Spoke with %s" % display_name,
			"trust_delta": 0,
		})

	return beats


static func _resident(
	display_name: String,
	landmark: String,
	role: String,
	routine_note: String,
	melody_hint: String,
	ambient_lines: Array,
	dialogue_beats: Array,
	appearance: Dictionary,
	spawn: Dictionary
) -> Dictionary:
	return {
		"display_name": display_name,
		"landmark": landmark,
		"role": role,
		"routine_note": routine_note,
		"melody_hint": melody_hint,
		"ambient_lines": ambient_lines.duplicate(true),
		"dialogue_beats": dialogue_beats.duplicate(true),
		"appearance": appearance.duplicate(true),
		"spawn": spawn.duplicate(true),
		"known": false,
		"trust": 0,
		"conversation_index": 0,
		"quest_state": "available",
		"current_step": "Not introduced yet.",
	}


static func _spawn(
	anchor_id: String,
	offset: Vector2,
	direction: float,
	mood: int = MOOD_NORMAL,
	interaction_radius: float = 72.0
) -> Dictionary:
	return {
		"anchor_id": anchor_id,
		"offset": offset,
		"direction": direction,
		"mood": mood,
		"interaction_radius": interaction_radius,
	}


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
) -> Dictionary:
	var selections := {
		"body/body": skin,
		"head/faces/face_neutral": skin,
		head_path: skin,
		shirt_path: shirt_color,
		pants_path: pants_color,
		shoes_path: shoes_color,
	}

	if !hair_path.is_empty():
		selections[hair_path] = hair_color

	selections.merge(extra_selections, true)

	return _appearance(body_type, _body_type_index(body_type), selections)


static func _appearance(body_type: String, body_type_index: int, selections: Dictionary) -> Dictionary:
	return {
		"body_type": body_type,
		"body_type_index": body_type_index,
		"selections": selections.duplicate(true),
	}


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
