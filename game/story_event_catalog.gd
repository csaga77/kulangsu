class_name StoryEventCatalog
extends RefCounted


static func build_event_tree() -> Array[Dictionary]:
	return [
		{
			"id": "melody_landmarks",
			"children": [
				{
					"id": "piano_ferry",
					"world_event_bindings": _piano_ferry_reward_bindings(),
					"children": [
						{
							"id": "harbor_refrain",
							"subject_bindings": [
								{
									"subject_id": "landmark:piano_ferry.harbor_refrain",
									"action": "collect",
									"prompt": "Collect Harbor Clue",
									"conditions": {
										"landmark_state": {"piano_ferry": "introduced"},
									},
									"effects": {
										"landmark_progress_patch": {
											"piano_ferry": {
												"state": "resolved",
												"harbor_clue_found": true,
											},
										},
										"melody_hint_text": _harbor_refrain_melody_hint_text(),
										"landmark_audio_cue_request": _landmark_audio_cue_request(
											"piano_ferry",
											"piano_ferry",
											"harbor_refrain"
										),
										"objective": "Return to Caretaker Lian with the harbor refrain.",
										"hint_action": "R Talk to Caretaker Lian",
										"save_status": "The harbor refrain is clearer now — return to Caretaker Lian.",
										"autosave_story_progress": true,
									},
									"consumes_interaction": true,
								},
							],
						},
					],
				},
				{
					"id": "trinity_church",
					"world_event_bindings": _trinity_church_reward_bindings(),
					"children": [
						{
							"id": "steps",
							"subject_bindings": _trinity_cue_bindings("steps"),
						},
						{
							"id": "garden",
							"subject_bindings": _trinity_cue_bindings("garden"),
						},
						{
							"id": "yard",
							"subject_bindings": _trinity_cue_bindings("yard"),
						},
						{
							"id": "choir_chime",
							"subject_bindings": _trinity_chime_bindings(),
							"world_event_bindings": _trinity_chime_completion_bindings(),
						},
					],
				},
				{
					"id": "bi_shan_tunnel",
					"children": [
						{
							"id": "echo_a",
							"subject_bindings": _bi_shan_echo_bindings("echo_a"),
						},
						{
							"id": "echo_b",
							"subject_bindings": _bi_shan_echo_bindings("echo_b"),
						},
						{
							"id": "echo_c",
							"subject_bindings": _bi_shan_echo_bindings("echo_c"),
						},
						{
							"id": "chamber",
							"subject_bindings": _bi_shan_chamber_bindings(),
							"world_event_bindings": _bi_shan_chamber_completion_bindings(),
						},
					],
				},
				{
					"id": "long_shan_tunnel",
					"children": [
						{
							"id": "tunnel_entry",
							"subject_bindings": _long_shan_entry_bindings(),
						},
						{
							"id": "light_pocket_south",
							"subject_bindings": _long_shan_checkpoint_bindings("light_pocket_south"),
						},
						{
							"id": "light_pocket_north",
							"subject_bindings": _long_shan_checkpoint_bindings("light_pocket_north"),
						},
						{
							"id": "tunnel_exit",
							"subject_bindings": _long_shan_exit_bindings(),
							"world_event_bindings": _long_shan_route_completion_bindings(),
						},
					],
				},
				{
					"id": "bagua_tower",
					"world_event_bindings": _bagua_tower_reward_bindings(),
					"children": [
						{
							"id": "synthesis_chamber",
							"subject_bindings": _bagua_synthesis_bindings(),
						},
					],
				},
				{
					"id": "festival_stage",
					"children": [
						{
							"id": "harbor_stage",
							"subject_bindings": _festival_stage_bindings(),
							"world_event_bindings": _festival_stage_completion_bindings(),
						},
					],
				},
			],
		},
	]


static func build_subject_binding_index() -> Dictionary:
	var index := {}
	_append_subject_bindings(build_event_tree(), index, [])
	return index


static func build_world_event_binding_index() -> Dictionary:
	var index := {}
	_append_world_event_bindings(build_event_tree(), index, [])
	return index


static func build_subject_metadata_index() -> Dictionary:
	var index := {}
	for definition in build_subject_metadata_definitions():
		if !(definition is Dictionary):
			continue
		var metadata: Dictionary = (definition as Dictionary).duplicate(true)
		var subject_id := String(metadata.get("subject_id", "")).strip_edges()
		if subject_id.is_empty():
			continue
		index[subject_id] = metadata
	return index


static func get_subject_metadata(subject_id: String) -> Dictionary:
	return build_subject_metadata_index().get(subject_id.strip_edges(), {}).duplicate(true)


static func build_world_subject_ids() -> Array[String]:
	var subject_ids: Array[String] = []
	for subject_id_value in build_subject_metadata_index().keys():
		subject_ids.append(String(subject_id_value))
	subject_ids.sort()
	return subject_ids


static func build_world_subject_enum_hint(include_unset: bool = true) -> String:
	var options: Array[String] = []
	if include_unset:
		options.append("Unset:")
	options.append_array(build_world_subject_ids())
	return ",".join(options)


static func validate_story_event_references(event_definitions: Dictionary = {}) -> PackedStringArray:
	var known_event_ids := {}
	var definitions := event_definitions
	if definitions.is_empty():
		definitions = StorylineCatalog.build_event_definitions()
	for event_id_value in definitions.keys():
		var event_id := String(event_id_value).strip_edges()
		if !event_id.is_empty():
			known_event_ids[event_id] = true

	var warnings := PackedStringArray()
	_collect_story_event_reference_warnings(build_event_tree(), known_event_ids, [], warnings)
	return warnings


static func build_subject_metadata_definitions() -> Array[Dictionary]:
	return [
		_inspect_subject_metadata("harbor_lantern_lines", "Harbor Lantern Lines"),
		_inspect_subject_metadata("harbor_notice_board", "Harbor Notice Board"),
		_inspect_subject_metadata("postcard_display_rack", "Postcard Display Rack"),
		_inspect_subject_metadata("church_stone_bench", "Church Stone Bench"),
		_inspect_subject_metadata("bagua_railings", "Bagua Railings"),
		{
			"subject_id": "landmark:piano_ferry.harbor_refrain",
			"default_action": "collect",
			"display_name": "Harbor Clue",
			"presence_rules": [
				_presence_visible_rule(10, {"landmark_state": {"piano_ferry": "introduced"}}),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:trinity_church.steps",
			"default_action": "collect",
			"display_name": "Choir Cue (Steps)",
			"presence_rules": [
				_presence_hidden_rule(100, _progress_contains_all("trinity_church", "cues_collected", ["steps"])),
				_presence_visible_rule(
					10,
					_merge_conditions(
						_landmark_state_conditions("trinity_church", ["available", "introduced", "in_progress"]),
						{}
					)
				),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:trinity_church.garden",
			"default_action": "collect",
			"display_name": "Choir Cue (Garden)",
			"presence_rules": [
				_presence_hidden_rule(100, _progress_contains_all("trinity_church", "cues_collected", ["garden"])),
				_presence_visible_rule(
					10,
					_merge_conditions(
						_landmark_state_conditions("trinity_church", ["available", "introduced", "in_progress"]),
						_progress_contains_all("trinity_church", "cues_collected", ["steps"])
					)
				),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:trinity_church.yard",
			"default_action": "collect",
			"display_name": "Choir Cue (Yard)",
			"presence_rules": [
				_presence_hidden_rule(100, _progress_contains_all("trinity_church", "cues_collected", ["yard"])),
				_presence_visible_rule(
					10,
					_merge_conditions(
						_landmark_state_conditions("trinity_church", ["available", "introduced", "in_progress"]),
						_progress_contains_all("trinity_church", "cues_collected", ["steps", "garden"])
					)
				),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:trinity_church.choir_chime",
			"default_action": "perform",
			"display_name": "Choir Chime",
			"presence_rules": [
				_presence_hidden_rule(
					100,
					_progress_fields("trinity_church", {"chime_performed": true})
				),
				_presence_visible_rule(
					10,
					_merge_conditions(
						_landmark_state_conditions("trinity_church", ["in_progress"]),
						_progress_contains_all("trinity_church", "cues_collected", ["steps", "garden", "yard"])
					)
				),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:bi_shan_tunnel.echo_a",
			"default_action": "collect",
			"display_name": "Tunnel Echo (North Wall)",
			"presence_rules": [
				_presence_hidden_rule(100, _progress_contains_all("bi_shan_tunnel", "echoes_collected", ["echo_a"])),
				_presence_visible_rule(10, _landmark_state_conditions("bi_shan_tunnel", ["available", "introduced", "in_progress"])),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:bi_shan_tunnel.echo_b",
			"default_action": "collect",
			"display_name": "Tunnel Echo (Arch Midpoint)",
			"presence_rules": [
				_presence_hidden_rule(100, _progress_contains_all("bi_shan_tunnel", "echoes_collected", ["echo_b"])),
				_presence_visible_rule(10, _landmark_state_conditions("bi_shan_tunnel", ["available", "introduced", "in_progress"])),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:bi_shan_tunnel.echo_c",
			"default_action": "collect",
			"display_name": "Tunnel Echo (Mural Approach)",
			"presence_rules": [
				_presence_hidden_rule(100, _progress_contains_all("bi_shan_tunnel", "echoes_collected", ["echo_c"])),
				_presence_visible_rule(10, _landmark_state_conditions("bi_shan_tunnel", ["available", "introduced", "in_progress"])),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:bi_shan_tunnel.chamber",
			"default_action": "collect",
			"display_name": "Mural Chamber",
			"presence_rules": [
				_presence_visible_rule(
					10,
					_merge_conditions(
						_landmark_state_conditions("bi_shan_tunnel", ["in_progress"]),
						_progress_contains_all("bi_shan_tunnel", "echoes_collected", ["echo_a", "echo_b", "echo_c"])
					)
				),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:long_shan_tunnel.tunnel_entry",
			"default_action": "collect",
			"display_name": "Long Shan Tunnel Entry",
			"presence_rules": [
				_presence_visible_rule(10, _landmark_state_conditions("long_shan_tunnel", ["available"])),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:long_shan_tunnel.light_pocket_south",
			"default_action": "collect",
			"display_name": "Lit Pocket",
			"presence_rules": [
				_presence_hidden_rule(
					100,
					_progress_contains_all("long_shan_tunnel", "checkpoints_collected", ["light_pocket_south"])
				),
				_presence_visible_rule(10, _landmark_state_conditions("long_shan_tunnel", ["in_progress"])),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:long_shan_tunnel.light_pocket_north",
			"default_action": "collect",
			"display_name": "Lit Pocket",
			"presence_rules": [
				_presence_hidden_rule(
					100,
					_progress_contains_all("long_shan_tunnel", "checkpoints_collected", ["light_pocket_north"])
				),
				_presence_visible_rule(
					10,
					_merge_conditions(
						_landmark_state_conditions("long_shan_tunnel", ["in_progress"]),
						_progress_contains_all("long_shan_tunnel", "checkpoints_collected", ["light_pocket_south"])
					)
				),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:long_shan_tunnel.tunnel_exit",
			"default_action": "collect",
			"display_name": "Long Shan Tunnel Exit",
			"presence_rules": [
				_presence_visible_rule(10, _landmark_state_conditions("long_shan_tunnel", ["in_progress"])),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:bagua_tower.synthesis_chamber",
			"default_action": "collect",
			"display_name": "Synthesis Chamber",
			"presence_rules": [
				_presence_hidden_rule(100, _progress_fields("bagua_tower", {"synthesis_done": true})),
				_presence_visible_rule(10, _landmark_state_conditions("bagua_tower", ["in_progress"])),
				_presence_hidden_rule(),
			],
		},
		{
			"subject_id": "landmark:festival_stage.harbor_stage",
			"default_action": "perform",
			"display_name": "Festival Stage",
			"presence_rules": [
				_presence_visible_rule(10, _landmark_state_conditions("festival_stage", ["available"])),
				_presence_hidden_rule(),
			],
		},
	]


static func _append_subject_bindings(nodes: Array, index: Dictionary, path: Array[String]) -> void:
	for node_value in nodes:
		if !(node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var node_id := String(node.get("id", "")).strip_edges()
		var next_path: Array[String] = path.duplicate()
		if !node_id.is_empty():
			next_path.append(node_id)

		for binding_value in node.get("subject_bindings", []):
			if !(binding_value is Dictionary):
				continue
			var binding: Dictionary = (binding_value as Dictionary).duplicate(true)
			var subject_id := String(binding.get("subject_id", "")).strip_edges()
			var action := String(binding.get("action", "")).strip_edges().to_lower()
			if subject_id.is_empty() or action.is_empty():
				continue
			binding["event_path"] = ".".join(next_path)
			var key := _binding_key(subject_id, action)
			if !index.has(key):
				index[key] = []
			var bindings: Array = index[key]
			bindings.append(binding)
			index[key] = bindings

		_append_subject_bindings(node.get("children", []), index, next_path)


static func _append_world_event_bindings(nodes: Array, index: Dictionary, path: Array[String]) -> void:
	for node_value in nodes:
		if !(node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var node_id := String(node.get("id", "")).strip_edges()
		var next_path: Array[String] = path.duplicate()
		if !node_id.is_empty():
			next_path.append(node_id)

		for binding_value in node.get("world_event_bindings", []):
			if !(binding_value is Dictionary):
				continue
			var binding: Dictionary = (binding_value as Dictionary).duplicate(true)
			var event_id := String(binding.get("event_id", "")).strip_edges()
			if event_id.is_empty():
				continue
			binding["event_path"] = ".".join(next_path)
			if !index.has(event_id):
				index[event_id] = []
			var bindings: Array = index[event_id]
			bindings.append(binding)
			index[event_id] = bindings

		_append_world_event_bindings(node.get("children", []), index, next_path)


static func _collect_story_event_reference_warnings(
	nodes: Array,
	known_event_ids: Dictionary,
	path: Array[String],
	warnings: PackedStringArray
) -> void:
	for node_value in nodes:
		if !(node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var node_id := String(node.get("id", "")).strip_edges()
		var next_path: Array[String] = path.duplicate()
		if !node_id.is_empty():
			next_path.append(node_id)
		var event_path := ".".join(next_path)

		for binding_value in node.get("subject_bindings", []):
			if !(binding_value is Dictionary):
				continue
			var binding: Dictionary = binding_value
			var subject_id := String(binding.get("subject_id", "")).strip_edges()
			var action := String(binding.get("action", "")).strip_edges().to_lower()
			var origin := "%s subject %s %s" % [event_path, subject_id, action]
			_collect_effect_story_event_references(
				binding.get("effects", {}),
				known_event_ids,
				origin.strip_edges(),
				warnings
			)

		for world_binding_value in node.get("world_event_bindings", []):
			if !(world_binding_value is Dictionary):
				continue
			var world_binding: Dictionary = world_binding_value
			var event_id := String(world_binding.get("event_id", "")).strip_edges()
			var origin := "%s world event %s" % [event_path, event_id]
			_collect_effect_story_event_references(
				world_binding.get("effects", {}),
				known_event_ids,
				origin.strip_edges(),
				warnings
			)

		_collect_story_event_reference_warnings(
			node.get("children", []),
			known_event_ids,
			next_path,
			warnings
		)


static func _collect_effect_story_event_references(
	value: Variant,
	known_event_ids: Dictionary,
	origin: String,
	warnings: PackedStringArray
) -> void:
	if value is Dictionary:
		var payload: Dictionary = value
		var story_event_id := String(payload.get("story_event", "")).strip_edges()
		if !story_event_id.is_empty() and !known_event_ids.has(story_event_id):
			warnings.append("%s references missing story_event '%s'" % [origin, story_event_id])
		for key in payload.keys():
			var nested_value = payload[key]
			if nested_value is Dictionary or nested_value is Array:
				_collect_effect_story_event_references(nested_value, known_event_ids, origin, warnings)
		return

	if value is Array:
		for nested_value in value:
			if nested_value is Dictionary or nested_value is Array:
				_collect_effect_story_event_references(nested_value, known_event_ids, origin, warnings)


static func _binding_key(subject_id: String, action: String) -> String:
	return "%s|%s" % [subject_id.strip_edges(), action.strip_edges().to_lower()]


static func _trinity_cue_bindings(trigger_id: String) -> Array[Dictionary]:
	var subject_id := "landmark:trinity_church.%s" % trigger_id
	return [
		{
			"priority": 100,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_progress_contains_all": {
					"trinity_church": {
						"cues_collected": [trigger_id],
					},
				},
			},
			"consumes_interaction": false,
		},
		{
			"priority": 30,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_progress_count_min": {
					"trinity_church": {
						"cues_collected": 2,
					},
				},
			},
			"effects": _merge_effects(_trinity_cue_collect_effects(trigger_id), {
				"melody_hint_text": "The three choir cues lean toward one church chime, but they still need to be settled together.",
				"objective": "Settle the church phrase at the choir chime near the steps.",
				"hint_action": "R Perform Choir Chime",
				"save_status": "All choir cues found — settle them at the choir chime.",
			}),
			"consumes_interaction": true,
		},
		{
			"priority": 20,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_progress_count_min": {
					"trinity_church": {
						"cues_collected": 1,
					},
				},
			},
			"effects": _merge_effects(_trinity_cue_collect_effects(trigger_id), {
				"objective": "Find the last choir cue in the quiet yard.",
			}),
			"consumes_interaction": true,
		},
		{
			"priority": 10,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"effects": _merge_effects(_trinity_cue_collect_effects(trigger_id), {
				"objective": "Follow the next choir cue toward the side garden.",
			}),
			"consumes_interaction": true,
		},
	]


static func _trinity_cue_collect_effects(trigger_id: String) -> Dictionary:
	return {
		"landmark_progress_list_append_unique": {
			"trinity_church": {
				"cues_collected": [trigger_id],
			},
		},
		"landmark_progress_patch": {
			"trinity_church": {
				"state": "in_progress",
			},
		},
		"save_status": "Found: {display_name}",
		"melody_hint_text": _trinity_cue_melody_hint_text(trigger_id),
		"landmark_audio_cue_request": _landmark_audio_cue_request(
			"trinity_church",
			"trinity_church",
			trigger_id
		),
		"autosave_story_progress": true,
	}


static func _trinity_chime_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"subject_id": "landmark:trinity_church.choir_chime",
			"action": "perform",
			"prompt": "Perform {display_name}",
			"conditions": {
				"landmark_progress_fields": {
					"trinity_church": {
						"chime_performed": true,
					},
				},
			},
			"consumes_interaction": false,
		},
		{
			"priority": 50,
			"subject_id": "landmark:trinity_church.choir_chime",
			"action": "perform",
			"prompt": "Perform {display_name}",
			"conditions": {
				"landmark_progress_count_min": {
					"trinity_church": {
						"cues_collected": 3,
					},
				},
			},
			"effects": {
				"melody_hint_text": _trinity_chime_melody_hint_text(),
				"landmark_audio_cue_request": _landmark_audio_cue_request(
					"trinity_church",
					"trinity_church",
					"choir_chime"
				),
				"melody_prompt_request": _trinity_chime_prompt_request(),
			},
			"consumes_interaction": false,
		},
		{
			"priority": 0,
			"subject_id": "landmark:trinity_church.choir_chime",
			"action": "perform",
			"prompt": "Perform {display_name}",
			"effects": {
				"save_status": "The church phrase needs all three choir cues before it can settle.",
			},
			"consumes_interaction": false,
		},
	]


static func _trinity_chime_prompt_request() -> Dictionary:
	return {
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "trinity_chime",
		"title": "Settle the Trinity Chime",
		"body": "Arrange the choir cues in the order Mei taught you, then let the church phrase settle into one calm chime.",
		"segments": [
			{"source_id": "steps", "label": "Stone Steps", "landmark": "Trinity Church"},
			{"source_id": "garden", "label": "Side Garden", "landmark": "Trinity Church"},
			{"source_id": "yard", "label": "Quiet Yard", "landmark": "Trinity Church"},
		],
		"expected_order": ["steps", "garden", "yard"],
		"retry_hint": "The church phrase begins at the steps before the garden and quiet yard answer.",
		"hint_text": "Choose the choir cues in Mei's order.",
	}


static func _bi_shan_echo_bindings(trigger_id: String) -> Array[Dictionary]:
	var subject_id := "landmark:bi_shan_tunnel.%s" % trigger_id
	var active_conditions := {
		"landmark_state": {
			"bi_shan_tunnel": ["available", "introduced", "in_progress"],
		},
	}
	return [
		{
			"priority": 100,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_progress_contains_all": {
					"bi_shan_tunnel": {
						"echoes_collected": [trigger_id],
					},
				},
			},
			"consumes_interaction": false,
		},
		{
			"priority": 20,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": _merge_conditions(active_conditions, {
				"landmark_progress_count_min": {
					"bi_shan_tunnel": {
						"echoes_collected": 2,
					},
				},
			}),
			"effects": _merge_effects(_bi_shan_echo_collect_effects(trigger_id), {
				"objective": "Reach the mural chamber at the far end of Bi Shan Tunnel.",
				"hint": "Follow the resonance to the chamber.   J Journal   Esc Pause",
				"save_status": "All three echoes traced — follow the resonance to the chamber.",
			}),
			"consumes_interaction": true,
		},
		{
			"priority": 10,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": active_conditions,
			"effects": _bi_shan_echo_collect_effects(trigger_id),
			"consumes_interaction": true,
		},
	]


static func _bi_shan_echo_collect_effects(trigger_id: String) -> Dictionary:
	return {
		"landmark_progress_list_append_unique": {
			"bi_shan_tunnel": {
				"echoes_collected": [trigger_id],
			},
		},
		"landmark_progress_patch": {
			"bi_shan_tunnel": {
				"state": "in_progress",
			},
		},
		"save_status": "Heard: {display_name}",
		"landmark_audio_cue_request": _landmark_audio_cue_request(
			"bi_shan_tunnel",
			"bi_shan_tunnel",
			trigger_id
		),
		"autosave_story_progress": true,
	}


static func _bi_shan_chamber_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"subject_id": "landmark:bi_shan_tunnel.chamber",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_state": {"bi_shan_tunnel": "reward_collected"},
			},
			"consumes_interaction": false,
		},
		{
			"priority": 50,
			"subject_id": "landmark:bi_shan_tunnel.chamber",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_progress_count_min": {
					"bi_shan_tunnel": {
						"echoes_collected": 3,
					},
				},
			},
			"effects": {
				"landmark_audio_cue_request": _landmark_audio_cue_request(
					"bi_shan_tunnel",
					"bi_shan_tunnel",
					"chamber"
				),
				"melody_prompt_request": _bi_shan_chamber_prompt_request(),
			},
			"consumes_interaction": false,
		},
		{
			"priority": 0,
			"subject_id": "landmark:bi_shan_tunnel.chamber",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"effects": {
				"save_status": "The mural panel is silent. Trace the three tunnel echoes first.",
			},
			"consumes_interaction": false,
		},
	]


static func _bi_shan_chamber_prompt_request() -> Dictionary:
	return {
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "bi_shan_chamber",
		"title": "Settle the Bi Shan Contour",
		"body": "Arrange the tunnel echoes from the first steady contour to the mural-facing answer so the chamber can respond.",
		"segments": [
			{"source_id": "echo_a", "label": "North Wall Echo", "landmark": "Bi Shan Tunnel"},
			{"source_id": "echo_b", "label": "Arch Midpoint", "landmark": "Bi Shan Tunnel"},
			{"source_id": "echo_c", "label": "Mural Approach", "landmark": "Bi Shan Tunnel"},
		],
		"expected_order": ["echo_a", "echo_b", "echo_c"],
		"retry_hint": "Let the north wall answer first, then the arch midpoint, before the mural approach settles.",
		"hint_text": "Choose the tunnel echoes in the contour they reveal together.",
	}


static func _long_shan_entry_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 10,
			"subject_id": "landmark:long_shan_tunnel.tunnel_entry",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_state": {"long_shan_tunnel": "available"},
			},
			"effects": {
				"landmark_progress_patch": {
					"long_shan_tunnel": {
						"state": "introduced",
					},
				},
				"landmark_audio_cue_request": _landmark_audio_cue_request(
					"long_shan_tunnel",
					"long_shan_tunnel",
					"tunnel_entry"
				),
				"save_status": "Long Shan Tunnel entry reached — find Tunnel Guide Ren.",
				"autosave_story_progress": true,
			},
			"consumes_interaction": true,
		},
	]


static func _long_shan_checkpoint_bindings(trigger_id: String) -> Array[Dictionary]:
	var subject_id := "landmark:long_shan_tunnel.%s" % trigger_id
	return [
		{
			"priority": 100,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_progress_contains_all": {
					"long_shan_tunnel": {
						"checkpoints_collected": [trigger_id],
					},
				},
			},
			"consumes_interaction": false,
		},
		{
			"priority": 20,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_state": {"long_shan_tunnel": "in_progress"},
				"landmark_progress_count_min": {
					"long_shan_tunnel": {
						"checkpoints_collected": 1,
					},
				},
			},
			"effects": _merge_effects(_long_shan_checkpoint_effects(trigger_id), {
				"objective": "Lead the route through to the Long Shan Tunnel exit.",
				"hint_action": "R Collect Long Shan Tunnel Exit",
				"save_status": "Both lit pockets are steady — guide the route to the exit.",
			}),
			"consumes_interaction": true,
		},
		{
			"priority": 10,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_state": {"long_shan_tunnel": "in_progress"},
			},
			"effects": _merge_effects(_long_shan_checkpoint_effects(trigger_id), {
				"objective": "Keep moving with Ren until you reach the next lit pocket.",
				"save_status": "A safe-lit pocket steadied the route ahead.",
			}),
			"consumes_interaction": true,
		},
		{
			"priority": 0,
			"subject_id": subject_id,
			"action": "collect",
			"prompt": "Collect {display_name}",
			"effects": {
				"save_status": "The lit pockets matter once Tunnel Guide Ren starts the crossing.",
			},
			"consumes_interaction": false,
		},
	]


static func _long_shan_checkpoint_effects(trigger_id: String) -> Dictionary:
	return {
		"landmark_progress_list_append_unique": {
			"long_shan_tunnel": {
				"checkpoints_collected": [trigger_id],
			},
		},
		"melody_hint_text": _long_shan_checkpoint_melody_hint_text(trigger_id),
		"landmark_audio_cue_request": _landmark_audio_cue_request(
			"long_shan_tunnel",
			"long_shan_tunnel",
			trigger_id
		),
		"autosave_story_progress": true,
	}


static func _long_shan_exit_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 50,
			"subject_id": "landmark:long_shan_tunnel.tunnel_exit",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_state": {"long_shan_tunnel": "in_progress"},
				"landmark_progress_count_min": {
					"long_shan_tunnel": {
						"checkpoints_collected": 2,
					},
				},
			},
			"effects": {
				"landmark_audio_cue_request": _landmark_audio_cue_request(
					"long_shan_tunnel",
					"long_shan_tunnel",
					"tunnel_exit"
				),
				"melody_prompt_request": _long_shan_route_prompt_request(),
			},
			"consumes_interaction": false,
		},
		{
			"priority": 10,
			"subject_id": "landmark:long_shan_tunnel.tunnel_exit",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_state": {"long_shan_tunnel": "in_progress"},
			},
			"effects": {
				"save_status": "The route is still uneven. Pause with Ren at the lit pockets before crossing.",
			},
			"consumes_interaction": false,
		},
		{
			"priority": 0,
			"subject_id": "landmark:long_shan_tunnel.tunnel_exit",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"effects": {
				"save_status": "Tunnel exit reached — talk to Tunnel Guide Ren before crossing.",
			},
			"consumes_interaction": false,
		},
	]


static func _long_shan_route_prompt_request() -> Dictionary:
	return {
		"melody_id": "festival_melody",
		"mode": "performance",
		"completion_kind": "long_shan_route",
		"title": "Steady the Long Shan Route",
		"body": "Confirm the lit-pocket rhythm that carried Ren through the tunnel before the exit can settle into one route.",
		"segments": [
			{"source_id": "light_pocket_south", "label": "South Lit Pocket", "landmark": "Long Shan Tunnel"},
			{"source_id": "light_pocket_north", "label": "North Lit Pocket", "landmark": "Long Shan Tunnel"},
		],
		"expected_order": ["light_pocket_south", "light_pocket_north"],
		"retry_hint": "The steadier route begins with the south lit pocket before the northern light answers it.",
		"hint_text": "Choose the lit pockets in the order Ren followed them.",
	}


static func _bagua_synthesis_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"subject_id": "landmark:bagua_tower.synthesis_chamber",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_progress_fields": {
					"bagua_tower": {
						"synthesis_done": true,
					},
				},
			},
			"consumes_interaction": false,
		},
		{
			"priority": 50,
			"subject_id": "landmark:bagua_tower.synthesis_chamber",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"conditions": {
				"landmark_state": {"bagua_tower": "in_progress"},
				"fragments_found_min": 3,
				"landmark_progress_fields": {
					"bagua_tower": {
						"synthesis_done": false,
					},
				},
			},
			"effects": {
				"landmark_progress_patch": {
					"bagua_tower": {
						"synthesis_done": true,
						"state": "resolved",
					},
				},
				"objective": "Return to Tower Keeper Suyin to confirm the island route.",
				"save_status": "Bagua Tower synthesis complete — return to Tower Keeper Suyin.",
				"landmark_audio_cue_request": _landmark_audio_cue_request(
					"bagua_tower",
					"bagua_tower",
					"synthesis_chamber"
				),
				"autosave_story_progress": true,
			},
			"consumes_interaction": true,
		},
		{
			"priority": 0,
			"subject_id": "landmark:bagua_tower.synthesis_chamber",
			"action": "collect",
			"prompt": "Collect {display_name}",
			"effects": {
				"save_status": "The tower shows distance but not yet direction. Recover more fragments first.",
			},
			"consumes_interaction": false,
		},
	]


static func _festival_stage_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 50,
			"subject_id": "landmark:festival_stage.harbor_stage",
			"action": "perform",
			"prompt": "Perform {display_name}",
			"conditions": {
				"landmark_state": {"festival_stage": "available"},
			},
			"effects": {
				"melody_hint_text": _festival_stage_melody_hint_text(),
				"landmark_audio_cue_request": _landmark_audio_cue_request(
					"festival_stage",
					"festival_stage",
					"harbor_stage"
				),
				"melody_prompt_request_builder": {
					"melody_id": "festival_melody",
					"prompt_mode": "performance",
				},
			},
			"consumes_interaction": false,
		},
	]


static func _harbor_refrain_melody_hint_text() -> String:
	return "The old piano crate answers the ferry ropes with a patient two-note pulse."


static func _trinity_cue_melody_hint_text(trigger_id: String) -> String:
	match trigger_id:
		"steps":
			return "A low bell tone echoes from the old stone steps..."
		"garden":
			return "A bright chime rises from the garden wall..."
		"yard":
			return "A warm hum lingers in the quiet yard..."
		_:
			return ""


static func _trinity_chime_melody_hint_text() -> String:
	return "The bell tower waits for the three choir cues to settle together..."


static func _long_shan_checkpoint_melody_hint_text(trigger_id: String) -> String:
	match trigger_id:
		"light_pocket_south":
			return "The tunnel air steadies where the lantern light gathers."
		"light_pocket_north":
			return "Ren's route holds together once the next lantern pocket answers back."
		_:
			return ""


static func _festival_stage_melody_hint_text() -> String:
	return "The plaza answers back all at once as the harbor finally carries the full melody."


static func _trinity_chime_completion_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"event_id": "prompt_completed:trinity_chime",
			"conditions": {
				"landmark_progress_fields": {
					"trinity_church": {
						"chime_performed": true,
					},
				},
			},
			"effects": {
				"save_status": "The church phrase is already settled at the choir chime.",
			},
		},
		{
			"priority": 50,
			"event_id": "prompt_completed:trinity_chime",
			"conditions": {
				"landmark_progress_count_min": {
					"trinity_church": {
						"cues_collected": 3,
					},
				},
			},
			"effects": {
				"landmark_progress_patch": {
					"trinity_church": {
						"chime_performed": true,
						"state": "resolved",
					},
				},
				"objective": "Return to Choir Caretaker Mei and compare how the church now answers the harbor.",
				"hint_action": "R Talk to Choir Caretaker Mei",
				"save_status": "The church bells now agree with one another.",
				"autosave_story_progress": true,
			},
		},
		{
			"priority": 0,
			"event_id": "prompt_completed:trinity_chime",
			"effects": {
				"save_status": "The church phrase still needs all three choir cues before it can settle.",
			},
		},
	]


static func _bi_shan_chamber_completion_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"event_id": "prompt_completed:bi_shan_chamber",
			"conditions": {
				"landmark_state": {"bi_shan_tunnel": "reward_collected"},
			},
			"effects": {
				"save_status": "The Bi Shan contour is already settled in the mural chamber.",
			},
		},
		{
			"priority": 70,
			"event_id": "prompt_completed:bi_shan_chamber",
			"conditions": {
				"landmark_progress_count_min": {
					"bi_shan_tunnel": {
						"echoes_collected": 3,
					},
				},
				"landmark_state": {
					"long_shan_tunnel": "reward_collected",
					"bagua_tower": "locked",
				},
			},
			"effects": _merge_effects(_bi_shan_reward_base_effects(), {
				"objective": "Return to Tunnel Guide Ren now that both tunnel routes agree.",
				"hint_action": "R Talk to Tunnel Guide Ren",
				"save_status": "Bi Shan Tunnel — mural resonance restored. Ren can now compare the two tunnel routes.",
			}),
		},
		{
			"priority": 60,
			"event_id": "prompt_completed:bi_shan_chamber",
			"conditions": {
				"landmark_progress_count_min": {
					"bi_shan_tunnel": {
						"echoes_collected": 3,
					},
				},
				"landmark_state": {
					"bagua_tower": ["available", "introduced", "in_progress", "resolved", "reward_collected"],
				},
			},
			"effects": _merge_effects(_bi_shan_reward_base_effects(), {
				"objective": "Carry the steadier tunnel route up to Bagua Tower.",
				"hint_action": "R Talk to Tower Keeper Suyin",
				"save_status": "Bi Shan Tunnel — mural resonance restored, and the tower can now read the route clearly.",
			}),
		},
		{
			"priority": 50,
			"event_id": "prompt_completed:bi_shan_chamber",
			"conditions": {
				"landmark_progress_count_min": {
					"bi_shan_tunnel": {
						"echoes_collected": 3,
					},
				},
			},
			"effects": _merge_effects(_bi_shan_reward_base_effects(), {
				"objective": "Explore Long Shan Tunnel and move with Ren between the lit pockets.",
				"hint_action": "R Inspect",
				"save_status": "Bi Shan Tunnel — mural resonance restored, and the tunnel route feels steadier now.",
			}),
		},
		{
			"priority": 0,
			"event_id": "prompt_completed:bi_shan_chamber",
			"effects": {
				"save_status": "The mural panel is silent. Trace the three tunnel echoes first.",
			},
		},
	]


static func _long_shan_route_completion_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"event_id": "prompt_completed:long_shan_route",
			"conditions": {
				"landmark_state": {"long_shan_tunnel": "reward_collected"},
			},
			"effects": {
				"save_status": "The Long Shan route is already settled.",
			},
		},
		{
			"priority": 50,
			"event_id": "prompt_completed:long_shan_route",
			"conditions": {
				"landmark_state": {"long_shan_tunnel": "in_progress"},
				"landmark_progress_count_min": {
					"long_shan_tunnel": {
						"checkpoints_collected": 2,
					},
				},
			},
			"effects": {
				"landmark_states": {
					"long_shan_tunnel": "reward_collected",
				},
				"melody_source_award": _festival_melody_source_award("long_shan_route"),
				"story_event": "melody_long_shan_restored",
				"objective": "Return to Tunnel Guide Ren and compare what the tunnel routes now suggest.",
				"hint_action": "R Talk to Tunnel Guide Ren",
				"save_status": "Long Shan Tunnel — passage completed. Ren can now judge what the route means.",
				"autosave_story_progress": true,
			},
		},
		{
			"priority": 0,
			"event_id": "prompt_completed:long_shan_route",
			"effects": {
				"save_status": "The route is still uneven. Pause with Ren at the lit pockets before crossing.",
			},
		},
	]


static func _festival_stage_completion_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"event_id": "prompt_completed:festival_performance",
			"conditions": {
				"melody_progress_fields": {
					"festival_melody": {
						"performed": true,
					},
				},
			},
			"effects": {
				"save_status": "The harbor has already answered the restored melody.",
			},
		},
		{
			"priority": 50,
			"event_id": "prompt_completed:festival_performance",
			"conditions": {
				"landmark_state": {"festival_stage": "available"},
				"melody_state": {"festival_melody": "reconstructed"},
				"melody_progress_fields": {
					"festival_melody": {
						"performed": false,
					},
				},
			},
			"effects": {
				"landmark_states": {
					"festival_stage": "reward_collected",
				},
				"melody_progress_patch": {
					"festival_melody": {
						"performed": true,
						"state": "performed",
						"next_lead": "Stay for the harbor gathering or keep wandering once the festival recap ends.",
					},
				},
				"story_event": "harbor_festival_performed",
				"objective": "The restored festival melody carries across the harbor.",
				"save_status": "The harbor gathering answers the restored melody.",
				"festival_performed_milestone": true,
				"autosave_story_progress": true,
			},
		},
		{
			"priority": 10,
			"event_id": "prompt_completed:festival_performance",
			"conditions": {
				"landmark_state": {"festival_stage": "available"},
			},
			"effects": {
				"save_status": "The restored melody still needs its full harbor phrase before it can carry.",
			},
		},
		{
			"priority": 0,
			"event_id": "prompt_completed:festival_performance",
			"effects": {
				"save_status": "The harbor stage is not ready to answer the melody yet.",
			},
		},
	]


static func _piano_ferry_reward_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"event_id": "landmark_reward:piano_ferry",
			"conditions": {
				"landmark_state": {"piano_ferry": "reward_collected"},
			},
			"effects": {
				"save_status": "The harbor refrain is already settled in your journal.",
			},
		},
		{
			"priority": 50,
			"event_id": "landmark_reward:piano_ferry",
			"effects": {
				"landmark_states": {
					"piano_ferry": "reward_collected",
				},
				"journal_unlocked": true,
				"melody_source_award": _festival_melody_source_award(
					"ferry_plaza",
					false,
					"Speak with the church caretaker and compare how the bells answer the harbor."
				),
				"story_event": "melody_ferry_settled",
				"save_status": "Journal unlocked - Trinity Church is marked as your first lead.",
				"landmark_resolved_milestone": "piano_ferry",
				"autosave_story_progress": true,
			},
		},
	]


static func _trinity_church_reward_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"event_id": "landmark_reward:trinity_church",
			"conditions": {
				"landmark_state": {"trinity_church": "reward_collected"},
			},
			"effects": {
				"save_status": "The church phrase has already opened the tunnel leads.",
			},
		},
		{
			"priority": 50,
			"event_id": "landmark_reward:trinity_church",
			"effects": {
				"landmark_states": {
					"trinity_church": "reward_collected",
					"bi_shan_tunnel": "available",
					"long_shan_tunnel": "available",
				},
				"melody_source_award": _festival_melody_source_award("church_bells"),
				"story_event": "melody_church_restored",
				"landmark_resolved_milestone": "trinity_church",
				"autosave_story_progress": true,
			},
		},
	]


static func _bagua_tower_reward_bindings() -> Array[Dictionary]:
	return [
		{
			"priority": 100,
			"event_id": "landmark_reward:bagua_tower",
			"conditions": {
				"landmark_state": {"bagua_tower": "reward_collected"},
			},
			"effects": {
				"save_status": "The tower route is already aligned with the harbor.",
			},
		},
		{
			"priority": 50,
			"event_id": "landmark_reward:bagua_tower",
			"effects": {
				"landmark_states": {
					"bagua_tower": "reward_collected",
				},
				"melody_source_award": _festival_melody_source_award(
					"tower_chamber",
					true,
					"Carry the restored melody quietly until Spring Festival is ready to hold it in public."
				),
				"story_event": "melody_bagua_aligned",
				"conditional_effects": [
					{
						"priority": 10,
						"conditions": {
							"landmark_state": {"festival_stage": "available"},
						},
						"effects": {
							"objective": "Return to Piano Ferry and perform the restored melody at the festival stage.",
							"save_status": "The island melody is whole — the harbor stage is ready.",
						},
					},
					{
						"priority": 0,
						"effects": {
							"objective": "Carry the restored melody until Spring Festival is ready to answer it in public.",
							"save_status": "The island melody is whole, but the harbor is not ready to perform it yet.",
						},
					},
				],
				"landmark_resolved_milestone": "bagua_tower",
				"autosave_story_progress": true,
			},
		},
	]


static func _bi_shan_reward_base_effects() -> Dictionary:
	return {
		"landmark_states": {
			"bi_shan_tunnel": "reward_collected",
		},
		"melody_source_award": _festival_melody_source_award("bi_shan_echo"),
		"story_event": "melody_bi_shan_restored",
		"unlock_shortcut": "bi_shan_crossing",
		"autosave_story_progress": true,
	}


static func _inspect_subject_metadata(inspectable_id: String, display_name: String) -> Dictionary:
	return {
		"subject_id": "inspectable:%s" % inspectable_id,
		"default_action": "inspect",
		"display_name": display_name,
	}


static func _presence_visible_rule(priority: int, conditions: Dictionary = {}, targetable: bool = true) -> Dictionary:
	return {
		"priority": priority,
		"conditions": conditions.duplicate(true),
		"visible": true,
		"targetable": targetable,
	}


static func _presence_hidden_rule(priority: int = 0, conditions: Dictionary = {}) -> Dictionary:
	return {
		"priority": priority,
		"conditions": conditions.duplicate(true),
		"visible": false,
		"targetable": false,
	}


static func _landmark_state_conditions(landmark_id: String, states: Variant) -> Dictionary:
	return {
		"landmark_state": {
			landmark_id: states,
		},
	}


static func _progress_contains_all(landmark_id: String, progress_key: String, entries: Array[String]) -> Dictionary:
	return {
		"landmark_progress_contains_all": {
			landmark_id: {
				progress_key: entries,
			},
		},
	}


static func _progress_fields(landmark_id: String, fields: Dictionary) -> Dictionary:
	return {
		"landmark_progress_fields": {
			landmark_id: fields.duplicate(true),
		},
	}


static func _festival_melody_source_award(
	source_id: String,
	counts_as_fragment: bool = true,
	next_lead: String = ""
) -> Dictionary:
	var award := {
		"melody_id": "festival_melody",
		"source_id": source_id,
		"counts_as_fragment": counts_as_fragment,
		"sync_state_from_fragments": true,
	}
	if !next_lead.is_empty():
		award["next_lead"] = next_lead
	return award


static func _landmark_audio_cue_request(cue_id: String, landmark_id: String, trigger_id: String) -> Dictionary:
	return {
		"cue_id": cue_id,
		"landmark_id": landmark_id,
		"trigger_id": trigger_id,
	}


static func _merge_conditions(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	merged.merge(extra, true)
	return merged


static func _merge_effects(base: Dictionary, extra: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	merged.merge(extra, true)
	return merged
