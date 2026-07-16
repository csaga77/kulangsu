@tool
class_name StoryEffectSchema
extends RefCounted
## Kulangsu-owned schema for dictionary-authored StoryEvent conditions/effects.
##
## The storyline editor consumes this through the host validation provider;
## runtime code uses the same validator as an atomic preflight before mutating
## AppState.

const LANDMARK_IDS := [
	"piano_ferry",
	"trinity_church",
	"bi_shan_tunnel",
	"long_shan_tunnel",
	"bagua_tower",
	"festival_stage",
]
const TIME_OF_DAY_IDS := ["morning", "afternoon", "evening", "night"]
const EFFECT_KEYS := {
	"objective": true,
	"hint": true,
	"hint_action": true,
	"season_phase": true,
	"advance_time": true,
	"story_day": true,
	"world_hour": true,
	"advance_hours": true,
	"advance_to_time_of_day": true,
	"advance_day": true,
	"chapter": true,
	"save_status": true,
	"unlock_landmark": true,
	"landmark_states": true,
	"landmark_progress_list_append_unique": true,
	"landmark_progress_patch": true,
	"melody_progress_patch": true,
	"melody_source_award": true,
	"landmark_reward": true,
	"landmark_audio_cue_request": true,
	"melody_hint_text": true,
	"melody_prompt_request": true,
	"melody_prompt_request_builder": true,
	"story_flags": true,
	"story_event": true,
	"journal_unlocked": true,
	"unlock_shortcut": true,
	"pin_lead_id": true,
	"resident_routine_overrides": true,
	"clear_resident_routine_override_ids": true,
	"resident_routine_variant": true,
	"story_milestone": true,
	"story_milestone_context": true,
	"festival_performed_milestone": true,
	"landmark_resolved_milestone": true,
	"conditional_effects": true,
	"autosave_story_progress": true,
}
const CONDITION_KEYS := {
	"subject_id": true,
	"action": true,
	"season_phase": true,
	"mode": true,
	"chapter": true,
	"time_of_day": true,
	"story_day_min": true,
	"story_day_max": true,
	"world_hour_min": true,
	"world_hour_max": true,
	"story_flag_all": true,
	"story_flag_any": true,
	"route_state": true,
	"route_score_min": true,
	"landmark_state": true,
	"landmark_progress_contains_all": true,
	"landmark_progress_count_min": true,
	"landmark_progress_fields": true,
	"melody_state": true,
	"melody_progress_fields": true,
	"fragments_found_min": true,
	"trust_min": true,
	"resident_known": true,
	"endgame_active": true,
}


static func build_validation_context(catalog_context: Dictionary = {}) -> Dictionary:
	var context := catalog_context.duplicate(true)
	var event_definitions: Dictionary = context.get("event_definitions", {})
	var route_definitions: Dictionary = context.get("route_definitions", {})
	if event_definitions.is_empty():
		event_definitions = StorylineCatalog.build_event_definitions()
	if route_definitions.is_empty():
		route_definitions = StorylineCatalog.build_route_definitions()
	context["event_definitions"] = event_definitions
	context["route_definitions"] = route_definitions
	context["event_ids"] = _id_set(event_definitions.keys())
	context["route_ids"] = _id_set(route_definitions.keys())
	context["resident_ids"] = _id_set(ResidentCatalog.resident_order())
	context["melody_ids"] = _id_set(MelodyCatalog.ordered_ids())
	context["landmark_ids"] = _id_set(LANDMARK_IDS)
	context["phase_ids"] = _id_set(StorySeasonPhases.runtime_phase_ids())
	return context


static func extract_effects(payload: Dictionary) -> Dictionary:
	var effects := {}
	for key_value in payload.keys():
		var key := String(key_value)
		if EFFECT_KEYS.has(key):
			effects[key] = payload[key_value]
	return effects


static func validate_effects(
	effects_value: Variant,
	context: Dictionary = {},
	path: String = "effects"
) -> PackedStringArray:
	var warnings := PackedStringArray()
	if !(effects_value is Dictionary):
		warnings.append("%s must be a Dictionary." % path)
		return warnings
	var effects: Dictionary = effects_value

	for key_value in effects.keys():
		var key := String(key_value)
		if !EFFECT_KEYS.has(key):
			warnings.append("Unknown story effect key '%s' at %s.%s." % [key, path, key])

	_validate_optional_string_keys(effects, [
		"objective", "hint", "hint_action", "chapter", "save_status",
		"melody_hint_text", "pin_lead_id", "story_milestone",
	], path, warnings)
	_validate_optional_bool_keys(effects, [
		"journal_unlocked", "festival_performed_milestone", "autosave_story_progress",
	], path, warnings)
	_validate_optional_number_keys(effects, [
		"story_day", "world_hour", "advance_hours", "advance_day",
	], path, warnings)

	if effects.has("season_phase"):
		_validate_known_id(effects["season_phase"], "%s.season_phase" % path, context, "phase_ids", warnings)
	if effects.has("advance_to_time_of_day"):
		_validate_enum_string(effects["advance_to_time_of_day"], "%s.advance_to_time_of_day" % path, TIME_OF_DAY_IDS, warnings)
	if effects.has("unlock_landmark"):
		_validate_known_id(effects["unlock_landmark"], "%s.unlock_landmark" % path, context, "landmark_ids", warnings)
	if effects.has("landmark_reward"):
		_validate_known_id(effects["landmark_reward"], "%s.landmark_reward" % path, context, "landmark_ids", warnings)
	if effects.has("landmark_resolved_milestone"):
		_validate_known_id(effects["landmark_resolved_milestone"], "%s.landmark_resolved_milestone" % path, context, "landmark_ids", warnings)
	if effects.has("story_event"):
		_validate_known_id(effects["story_event"], "%s.story_event" % path, context, "event_ids", warnings)

	if effects.has("advance_time"):
		_validate_advance_time(effects["advance_time"], context, "%s.advance_time" % path, warnings)
	if effects.has("landmark_states"):
		_validate_string_id_map(effects["landmark_states"], context, "landmark_ids", "%s.landmark_states" % path, warnings)
	if effects.has("landmark_progress_list_append_unique"):
		_validate_nested_id_map(effects["landmark_progress_list_append_unique"], context, "landmark_ids", "%s.landmark_progress_list_append_unique" % path, warnings, "string_collection")
	if effects.has("landmark_progress_patch"):
		_validate_nested_id_map(effects["landmark_progress_patch"], context, "landmark_ids", "%s.landmark_progress_patch" % path, warnings)
	if effects.has("melody_progress_patch"):
		_validate_nested_id_map(effects["melody_progress_patch"], context, "melody_ids", "%s.melody_progress_patch" % path, warnings)
	if effects.has("melody_source_award"):
		_validate_melody_source_award(effects["melody_source_award"], context, "%s.melody_source_award" % path, warnings)
	if effects.has("landmark_audio_cue_request"):
		_validate_landmark_audio_cue_request(effects["landmark_audio_cue_request"], context, "%s.landmark_audio_cue_request" % path, warnings)
	if effects.has("melody_prompt_request"):
		_validate_melody_prompt_request(effects["melody_prompt_request"], context, "%s.melody_prompt_request" % path, warnings)
	if effects.has("melody_prompt_request_builder"):
		_validate_melody_prompt_builder(effects["melody_prompt_request_builder"], context, "%s.melody_prompt_request_builder" % path, warnings)
	if effects.has("story_flags"):
		_expect_dictionary(effects["story_flags"], "%s.story_flags" % path, warnings)
	if effects.has("unlock_shortcut"):
		_expect_string_or_collection(effects["unlock_shortcut"], "%s.unlock_shortcut" % path, warnings)
	if effects.has("resident_routine_overrides"):
		_validate_nested_id_map(effects["resident_routine_overrides"], context, "resident_ids", "%s.resident_routine_overrides" % path, warnings)
	if effects.has("clear_resident_routine_override_ids"):
		_validate_known_id_collection(effects["clear_resident_routine_override_ids"], "%s.clear_resident_routine_override_ids" % path, context, "resident_ids", warnings)
	if effects.has("resident_routine_variant"):
		_validate_nested_id_map(effects["resident_routine_variant"], context, "resident_ids", "%s.resident_routine_variant" % path, warnings)
	if effects.has("story_milestone_context"):
		_expect_dictionary(effects["story_milestone_context"], "%s.story_milestone_context" % path, warnings)
	if effects.has("conditional_effects"):
		_validate_conditional_effects(effects["conditional_effects"], context, "%s.conditional_effects" % path, warnings)
	return warnings


static func validate_conditions(
	conditions_value: Variant,
	context: Dictionary = {},
	path: String = "conditions"
) -> PackedStringArray:
	var warnings := PackedStringArray()
	if !(conditions_value is Dictionary):
		warnings.append("%s must be a Dictionary." % path)
		return warnings
	var conditions: Dictionary = conditions_value

	for key_value in conditions.keys():
		var key := String(key_value)
		if !CONDITION_KEYS.has(key):
			warnings.append("Unknown story condition key '%s' at %s.%s." % [key, path, key])

	_validate_optional_string_keys(conditions, ["subject_id", "action", "mode", "chapter"], path, warnings)
	_validate_optional_number_keys(conditions, [
		"story_day_min", "story_day_max", "world_hour_min", "world_hour_max",
		"fragments_found_min", "trust_min",
	], path, warnings)
	_validate_optional_bool_keys(conditions, ["endgame_active"], path, warnings)

	if conditions.has("season_phase"):
		_validate_known_id_or_collection(conditions["season_phase"], "%s.season_phase" % path, context, "phase_ids", warnings)
	if conditions.has("time_of_day"):
		_validate_enum_string_or_collection(conditions["time_of_day"], "%s.time_of_day" % path, TIME_OF_DAY_IDS, warnings)
	for key in ["story_flag_all", "story_flag_any"]:
		if conditions.has(key):
			_expect_string_collection(conditions[key], "%s.%s" % [path, key], warnings)
	if conditions.has("route_state"):
		_validate_string_id_map(conditions["route_state"], context, "route_ids", "%s.route_state" % path, warnings)
	if conditions.has("route_score_min"):
		_validate_number_id_map(conditions["route_score_min"], context, "route_ids", "%s.route_score_min" % path, warnings)
	if conditions.has("landmark_state"):
		_validate_string_or_collection_id_map(conditions["landmark_state"], context, "landmark_ids", "%s.landmark_state" % path, warnings)
	if conditions.has("landmark_progress_contains_all"):
		_validate_nested_id_map(conditions["landmark_progress_contains_all"], context, "landmark_ids", "%s.landmark_progress_contains_all" % path, warnings, "string_collection")
	if conditions.has("landmark_progress_count_min"):
		_validate_nested_id_map(conditions["landmark_progress_count_min"], context, "landmark_ids", "%s.landmark_progress_count_min" % path, warnings, "number")
	if conditions.has("landmark_progress_fields"):
		_validate_nested_id_map(conditions["landmark_progress_fields"], context, "landmark_ids", "%s.landmark_progress_fields" % path, warnings)
	if conditions.has("melody_state"):
		_validate_string_id_map(conditions["melody_state"], context, "melody_ids", "%s.melody_state" % path, warnings)
	if conditions.has("melody_progress_fields"):
		_validate_nested_id_map(conditions["melody_progress_fields"], context, "melody_ids", "%s.melody_progress_fields" % path, warnings)
	if conditions.has("resident_known"):
		_validate_known_id_collection(conditions["resident_known"], "%s.resident_known" % path, context, "resident_ids", warnings)
	return warnings


static func _validate_advance_time(value: Variant, _context: Dictionary, path: String, warnings: PackedStringArray) -> void:
	if !_expect_dictionary(value, path, warnings):
		return
	var payload: Dictionary = value
	var allowed := {
		"story_day": true,
		"world_hour": true,
		"advance_hours": true,
		"advance_to_time_of_day": true,
		"advance_day": true,
	}
	for key_value in payload.keys():
		var key := String(key_value)
		if !allowed.has(key):
			warnings.append("Unknown story time effect key '%s' at %s.%s." % [key, path, key])
	_validate_optional_number_keys(payload, ["story_day", "world_hour", "advance_hours", "advance_day"], path, warnings)
	if payload.has("advance_to_time_of_day"):
		_validate_enum_string(payload["advance_to_time_of_day"], "%s.advance_to_time_of_day" % path, TIME_OF_DAY_IDS, warnings)


static func _validate_melody_source_award(value: Variant, context: Dictionary, path: String, warnings: PackedStringArray) -> void:
	if !_expect_dictionary(value, path, warnings):
		return
	var award: Dictionary = value
	_validate_allowed_keys(award, ["melody_id", "source_id", "counts_as_fragment", "sync_state_from_fragments", "next_lead"], path, warnings)
	if !award.has("melody_id"):
		warnings.append("%s.melody_id is required." % path)
	else:
		_validate_known_id(award["melody_id"], "%s.melody_id" % path, context, "melody_ids", warnings)
	if !award.has("source_id"):
		warnings.append("%s.source_id is required." % path)
	else:
		_expect_nonempty_string(award["source_id"], "%s.source_id" % path, warnings)
	_validate_optional_bool_keys(award, ["counts_as_fragment", "sync_state_from_fragments"], path, warnings)
	_validate_optional_string_keys(award, ["next_lead"], path, warnings)


static func _validate_landmark_audio_cue_request(value: Variant, context: Dictionary, path: String, warnings: PackedStringArray) -> void:
	if !_expect_dictionary(value, path, warnings):
		return
	var request: Dictionary = value
	_validate_allowed_keys(request, ["cue_id", "landmark_id", "trigger_id", "display_name"], path, warnings)
	for key in ["cue_id", "trigger_id"]:
		if !request.has(key):
			warnings.append("%s.%s is required." % [path, key])
		else:
			_expect_nonempty_string(request[key], "%s.%s" % [path, key], warnings)
	if !request.has("landmark_id"):
		warnings.append("%s.landmark_id is required." % path)
	else:
		_validate_known_id(request["landmark_id"], "%s.landmark_id" % path, context, "landmark_ids", warnings)
	_validate_optional_string_keys(request, ["display_name"], path, warnings)


static func _validate_melody_prompt_builder(value: Variant, context: Dictionary, path: String, warnings: PackedStringArray) -> void:
	if !_expect_dictionary(value, path, warnings):
		return
	var builder: Dictionary = value
	_validate_allowed_keys(builder, ["melody_id", "prompt_mode", "completion_kind", "request_overrides"], path, warnings)
	if !builder.has("melody_id"):
		warnings.append("%s.melody_id is required." % path)
	else:
		_validate_known_id(builder["melody_id"], "%s.melody_id" % path, context, "melody_ids", warnings)
	if !builder.has("prompt_mode"):
		warnings.append("%s.prompt_mode is required." % path)
	else:
		_expect_nonempty_string(builder["prompt_mode"], "%s.prompt_mode" % path, warnings)
	_validate_optional_string_keys(builder, ["completion_kind"], path, warnings)
	if builder.has("request_overrides"):
		_validate_melody_prompt_request(
			builder["request_overrides"],
			context,
			"%s.request_overrides" % path,
			warnings,
			false
		)


static func _validate_melody_prompt_request(
	value: Variant,
	context: Dictionary,
	path: String,
	warnings: PackedStringArray,
	require_core_fields: bool = true
) -> void:
	if !_expect_dictionary(value, path, warnings):
		return
	var request: Dictionary = value
	_validate_allowed_keys(request, [
		"melody_id", "mode", "completion_kind", "title", "body", "segments",
		"expected_order", "retry_hint", "hint_text",
	], path, warnings)
	if require_core_fields:
		for key in ["melody_id", "mode", "completion_kind", "segments", "expected_order"]:
			if !request.has(key):
				warnings.append("%s.%s is required." % [path, key])
	if request.has("melody_id"):
		_validate_known_id(request["melody_id"], "%s.melody_id" % path, context, "melody_ids", warnings)
	_validate_optional_string_keys(request, [
		"mode", "completion_kind", "title", "body", "retry_hint", "hint_text",
	], path, warnings)
	if request.has("expected_order"):
		_expect_string_collection(request["expected_order"], "%s.expected_order" % path, warnings)
	if !request.has("segments"):
		return
	var segments_value = request["segments"]
	if !(segments_value is Array):
		warnings.append("%s.segments must be an Array." % path)
		return
	var segments: Array = segments_value
	for index in segments.size():
		var segment_path := "%s.segments[%d]" % [path, index]
		var segment_value = segments[index]
		if !(segment_value is Dictionary):
			warnings.append("%s must be a Dictionary." % segment_path)
			continue
		var segment: Dictionary = segment_value
		_validate_allowed_keys(segment, ["source_id", "label", "landmark"], segment_path, warnings)
		for key in ["source_id", "label", "landmark"]:
			if !segment.has(key):
				warnings.append("%s.%s is required." % [segment_path, key])
			else:
				_expect_nonempty_string(segment[key], "%s.%s" % [segment_path, key], warnings)


static func _validate_conditional_effects(value: Variant, context: Dictionary, path: String, warnings: PackedStringArray) -> void:
	if !(value is Array):
		warnings.append("%s must be an Array." % path)
		return
	var bindings: Array = value
	for index in bindings.size():
		var binding_path := "%s[%d]" % [path, index]
		var binding_value = bindings[index]
		if !(binding_value is Dictionary):
			warnings.append("%s must be a Dictionary." % binding_path)
			continue
		var binding: Dictionary = binding_value
		_validate_allowed_keys(binding, ["priority", "conditions", "effects"], binding_path, warnings)
		if binding.has("priority") and !(binding["priority"] is int):
			warnings.append("%s.priority must be an int." % binding_path)
		if binding.has("conditions"):
			warnings.append_array(validate_conditions(binding["conditions"], context, "%s.conditions" % binding_path))
		if !binding.has("effects"):
			warnings.append("%s.effects is required." % binding_path)
		else:
			warnings.append_array(validate_effects(binding["effects"], context, "%s.effects" % binding_path))


static func _validate_nested_id_map(value: Variant, context: Dictionary, id_set_key: String, path: String, warnings: PackedStringArray, leaf_kind: String = "any") -> void:
	if !_expect_dictionary(value, path, warnings):
		return
	var values: Dictionary = value
	for id_value in values.keys():
		var item_path := "%s.%s" % [path, String(id_value)]
		_validate_known_id(String(id_value), item_path, context, id_set_key, warnings)
		var nested_value = values[id_value]
		if !_expect_dictionary(nested_value, item_path, warnings):
			continue
		if leaf_kind == "any":
			continue
		for leaf_key in (nested_value as Dictionary).keys():
			var leaf_path := "%s.%s" % [item_path, String(leaf_key)]
			if leaf_kind == "string_collection":
				_expect_string_collection((nested_value as Dictionary)[leaf_key], leaf_path, warnings)
			elif leaf_kind == "number":
				_expect_number((nested_value as Dictionary)[leaf_key], leaf_path, warnings)


static func _validate_string_id_map(value: Variant, context: Dictionary, id_set_key: String, path: String, warnings: PackedStringArray) -> void:
	_validate_id_map(value, context, id_set_key, path, warnings, "string")


static func _validate_number_id_map(value: Variant, context: Dictionary, id_set_key: String, path: String, warnings: PackedStringArray) -> void:
	_validate_id_map(value, context, id_set_key, path, warnings, "number")


static func _validate_string_or_collection_id_map(value: Variant, context: Dictionary, id_set_key: String, path: String, warnings: PackedStringArray) -> void:
	_validate_id_map(value, context, id_set_key, path, warnings, "string_or_collection")


static func _validate_id_map(value: Variant, context: Dictionary, id_set_key: String, path: String, warnings: PackedStringArray, value_kind: String) -> void:
	if !_expect_dictionary(value, path, warnings):
		return
	var values: Dictionary = value
	for id_value in values.keys():
		var item_path := "%s.%s" % [path, String(id_value)]
		_validate_known_id(String(id_value), item_path, context, id_set_key, warnings)
		if value_kind == "string":
			_expect_string(values[id_value], item_path, warnings)
		elif value_kind == "number":
			_expect_number(values[id_value], item_path, warnings)
		else:
			_expect_string_or_collection(values[id_value], item_path, warnings)


static func _validate_known_id(value: Variant, path: String, context: Dictionary, id_set_key: String, warnings: PackedStringArray) -> void:
	if !_expect_nonempty_string(value, path, warnings):
		return
	var id := String(value).strip_edges()
	if id.contains("{"):
		return
	var known_ids: Dictionary = context.get(id_set_key, {})
	if !known_ids.is_empty() and !known_ids.has(id):
		warnings.append("%s references unknown id '%s'." % [path, id])


static func _validate_known_id_collection(value: Variant, path: String, context: Dictionary, id_set_key: String, warnings: PackedStringArray) -> void:
	if !_expect_string_collection(value, path, warnings):
		return
	for id_value in value:
		_validate_known_id(id_value, path, context, id_set_key, warnings)


static func _validate_known_id_or_collection(value: Variant, path: String, context: Dictionary, id_set_key: String, warnings: PackedStringArray) -> void:
	if value is String:
		_validate_known_id(value, path, context, id_set_key, warnings)
		return
	_validate_known_id_collection(value, path, context, id_set_key, warnings)


static func _validate_enum_string(value: Variant, path: String, allowed_values: Array, warnings: PackedStringArray) -> void:
	if !_expect_nonempty_string(value, path, warnings):
		return
	var normalized := String(value).strip_edges()
	if !allowed_values.has(normalized):
		warnings.append("%s has unsupported value '%s'." % [path, normalized])


static func _validate_enum_string_or_collection(value: Variant, path: String, allowed_values: Array, warnings: PackedStringArray) -> void:
	if value is String:
		_validate_enum_string(value, path, allowed_values, warnings)
		return
	if !_expect_string_collection(value, path, warnings):
		return
	for item in value:
		_validate_enum_string(item, path, allowed_values, warnings)


static func _validate_allowed_keys(value: Dictionary, allowed_keys: Array, path: String, warnings: PackedStringArray) -> void:
	for key_value in value.keys():
		var key := String(key_value)
		if !allowed_keys.has(key):
			warnings.append("Unknown key '%s' at %s.%s." % [key, path, key])


static func _validate_optional_string_keys(value: Dictionary, keys: Array, path: String, warnings: PackedStringArray) -> void:
	for key in keys:
		if value.has(key):
			_expect_string(value[key], "%s.%s" % [path, key], warnings)


static func _validate_optional_bool_keys(value: Dictionary, keys: Array, path: String, warnings: PackedStringArray) -> void:
	for key in keys:
		if value.has(key) and !(value[key] is bool):
			warnings.append("%s.%s must be a bool." % [path, key])


static func _validate_optional_number_keys(value: Dictionary, keys: Array, path: String, warnings: PackedStringArray) -> void:
	for key in keys:
		if value.has(key):
			_expect_number(value[key], "%s.%s" % [path, key], warnings)


static func _expect_dictionary(value: Variant, path: String, warnings: PackedStringArray) -> bool:
	if value is Dictionary:
		return true
	warnings.append("%s must be a Dictionary." % path)
	return false


static func _expect_string(value: Variant, path: String, warnings: PackedStringArray) -> bool:
	if value is String:
		return true
	warnings.append("%s must be a String." % path)
	return false


static func _expect_nonempty_string(value: Variant, path: String, warnings: PackedStringArray) -> bool:
	if !_expect_string(value, path, warnings):
		return false
	if String(value).strip_edges().is_empty():
		warnings.append("%s must not be empty." % path)
		return false
	return true


static func _expect_number(value: Variant, path: String, warnings: PackedStringArray) -> bool:
	if value is int or value is float:
		return true
	warnings.append("%s must be a number." % path)
	return false


static func _expect_string_collection(value: Variant, path: String, warnings: PackedStringArray) -> bool:
	if !(value is Array or value is PackedStringArray):
		warnings.append("%s must be an Array or PackedStringArray of Strings." % path)
		return false
	var valid := true
	for item in value:
		if !(item is String):
			warnings.append("%s must contain only Strings." % path)
			valid = false
	return valid


static func _expect_string_or_collection(value: Variant, path: String, warnings: PackedStringArray) -> bool:
	if value is String:
		return true
	return _expect_string_collection(value, path, warnings)


static func _id_set(values: Variant) -> Dictionary:
	var ids := {}
	for value in values:
		var id := String(value).strip_edges()
		if !id.is_empty():
			ids[id] = true
	return ids
