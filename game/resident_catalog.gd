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
	# All story residents migrated to external .tres definitions in
	# res://game/residents/definitions/
	return {}


static func _ambient_residents() -> Dictionary:
	# All ambient residents migrated to external .tres definitions in
	# res://game/residents/definitions/
	return {}


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
