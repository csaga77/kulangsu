class_name PlayerAppearanceCatalog
extends RefCounted

const BODY_FRAME_OPTIONS := [
	{"id": "adult", "display_name": "Adult"},
	{"id": "teen", "display_name": "Teen"},
]

const PRESENTATION_OPTIONS := [
	{"id": "masculine", "display_name": "Masculine"},
	{"id": "feminine", "display_name": "Feminine"},
]

const SKIN_TONE_OPTIONS := [
	{"id": "light", "display_name": "Light"},
	{"id": "olive", "display_name": "Olive"},
	{"id": "bronze", "display_name": "Bronze"},
	{"id": "brown", "display_name": "Brown"},
]

const HAIR_STYLE_OPTIONS := [
	{"id": "short_bangs", "display_name": "Short Bangs", "path": "hair/short/hair_bangs"},
	{"id": "bob", "display_name": "Bob", "path": "hair/bob/hair_bob"},
	{"id": "long_bangs", "display_name": "Long Bangs", "path": "hair/long/hair_bangslong"},
	{"id": "braid", "display_name": "Braid", "path": "hair/braids/hair_braid"},
]

const HAIR_COLOR_OPTIONS := [
	{"id": "blonde", "display_name": "Blonde", "variant": "blonde"},
	{"id": "chestnut", "display_name": "Chestnut", "variant": "chestnut"},
	{"id": "dark_brown", "display_name": "Dark Brown", "variant": "dark brown"},
	{"id": "black", "display_name": "Black", "variant": "black"},
]

const DEFAULT_PROFILE := {
	"body_frame_id": "adult",
	"presentation_id": "masculine",
	"skin_tone_id": "light",
	"hair_style_id": "short_bangs",
	"hair_color_id": "chestnut",
}

const FACE_PATH := "head/faces/face_neutral"
const MALE_HEAD_PATH := "head/heads/human/heads_human_male"
const FEMALE_HEAD_PATH := "head/heads/human/heads_human_female"


static func default_profile() -> Dictionary:
	return DEFAULT_PROFILE.duplicate(true)


static func body_frame_options() -> Array:
	return BODY_FRAME_OPTIONS.duplicate(true)


static func presentation_options() -> Array:
	return PRESENTATION_OPTIONS.duplicate(true)


static func skin_tone_options() -> Array:
	return SKIN_TONE_OPTIONS.duplicate(true)


static func hair_style_options() -> Array:
	return HAIR_STYLE_OPTIONS.duplicate(true)


static func hair_color_options() -> Array:
	return HAIR_COLOR_OPTIONS.duplicate(true)


static func normalize_profile(profile: Dictionary) -> Dictionary:
	var normalized := DEFAULT_PROFILE.duplicate(true)

	normalized["body_frame_id"] = _validated_option_id(
		body_frame_options(),
		String(profile.get("body_frame_id", normalized["body_frame_id"]))
	)
	normalized["presentation_id"] = _validated_option_id(
		presentation_options(),
		String(profile.get("presentation_id", normalized["presentation_id"]))
	)
	normalized["skin_tone_id"] = _validated_option_id(
		skin_tone_options(),
		String(profile.get("skin_tone_id", normalized["skin_tone_id"]))
	)
	normalized["hair_style_id"] = _validated_option_id(
		hair_style_options(),
		String(profile.get("hair_style_id", normalized["hair_style_id"]))
	)
	normalized["hair_color_id"] = _validated_option_id(
		hair_color_options(),
		String(profile.get("hair_color_id", normalized["hair_color_id"]))
	)

	return normalized


static func cycle_option_id(options: Array, current_id: String, direction: int) -> String:
	if options.is_empty():
		return current_id

	var current_index := _index_for_option_id(options, current_id)
	if current_index < 0:
		return String((options[0] as Dictionary).get("id", current_id))

	var next_index := posmod(current_index + direction, options.size())
	return String((options[next_index] as Dictionary).get("id", current_id))


static func body_frame_display_name(option_id: String) -> String:
	return _display_name_for_option_id(body_frame_options(), option_id)


static func presentation_display_name(option_id: String) -> String:
	return _display_name_for_option_id(presentation_options(), option_id)


static func skin_tone_display_name(option_id: String) -> String:
	return _display_name_for_option_id(skin_tone_options(), option_id)


static func hair_style_display_name(option_id: String) -> String:
	return _display_name_for_option_id(hair_style_options(), option_id)


static func hair_color_display_name(option_id: String) -> String:
	return _display_name_for_option_id(hair_color_options(), option_id)


static func resolve_body_type(profile: Dictionary) -> String:
	var normalized := normalize_profile(profile)
	var body_frame_id := String(normalized.get("body_frame_id", "adult"))
	var presentation_id := String(normalized.get("presentation_id", "masculine"))

	if body_frame_id == "teen":
		return "teen"

	return "female" if presentation_id == "feminine" else "male"


static func resolve_body_type_index(profile: Dictionary) -> int:
	match resolve_body_type(profile):
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


static func resolve_head_path(profile: Dictionary) -> String:
	var normalized := normalize_profile(profile)
	var presentation_id := String(normalized.get("presentation_id", "masculine"))
	return FEMALE_HEAD_PATH if presentation_id == "feminine" else MALE_HEAD_PATH


static func resolve_hair_path(profile: Dictionary) -> String:
	var normalized := normalize_profile(profile)
	var hair_style_id := String(normalized.get("hair_style_id", "short_bangs"))
	return _string_value_for_option_id(hair_style_options(), hair_style_id, "path")


static func resolve_hair_variant(profile: Dictionary) -> String:
	var normalized := normalize_profile(profile)
	var hair_color_id := String(normalized.get("hair_color_id", "chestnut"))
	return _string_value_for_option_id(hair_color_options(), hair_color_id, "variant")


static func build_base_selections(profile: Dictionary) -> Dictionary:
	var normalized := normalize_profile(profile)
	var skin_tone := String(normalized.get("skin_tone_id", "light"))
	var hair_path := resolve_hair_path(normalized)
	var hair_variant := resolve_hair_variant(normalized)

	return {
		"body/body": skin_tone,
		FACE_PATH: skin_tone,
		resolve_head_path(normalized): skin_tone,
		hair_path: hair_variant,
	}


static func build_appearance_config(profile: Dictionary, costume_selections: Dictionary = {}) -> Dictionary:
	var normalized := normalize_profile(profile)
	var selections := build_base_selections(normalized)
	selections.merge(costume_selections, true)

	return {
		"body_type": resolve_body_type(normalized),
		"body_type_index": resolve_body_type_index(normalized),
		"selections": selections,
	}


static func _validated_option_id(options: Array, option_id: String) -> String:
	var fallback_id := String((options[0] as Dictionary).get("id", option_id)) if !options.is_empty() else option_id
	if _index_for_option_id(options, option_id) >= 0:
		return option_id
	return fallback_id


static func _display_name_for_option_id(options: Array, option_id: String) -> String:
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = option_value
		if String(option.get("id", "")) == option_id:
			return String(option.get("display_name", option_id))

	return option_id.capitalize()


static func _string_value_for_option_id(options: Array, option_id: String, key: String) -> String:
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = option_value
		if String(option.get("id", "")) == option_id:
			return String(option.get(key, ""))

	return ""


static func _index_for_option_id(options: Array, option_id: String) -> int:
	for index in range(options.size()):
		var option_value = options[index]
		if typeof(option_value) != TYPE_DICTIONARY:
			continue

		if String((option_value as Dictionary).get("id", "")) == option_id:
			return index

	return -1
