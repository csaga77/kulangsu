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
	{"id": "amber", "display_name": "Amber"},
	{"id": "black", "display_name": "Black"},
	{"id": "blue", "display_name": "Blue"},
	{"id": "bright_green", "display_name": "Bright Green"},
	{"id": "bronze", "display_name": "Bronze"},
	{"id": "brown", "display_name": "Brown"},
	{"id": "dark_green", "display_name": "Dark Green"},
	{"id": "fur_black", "display_name": "Fur Black"},
	{"id": "fur_brown", "display_name": "Fur Brown"},
	{"id": "fur_copper", "display_name": "Fur Copper"},
	{"id": "fur_gold", "display_name": "Fur Gold"},
	{"id": "fur_grey", "display_name": "Fur Grey"},
	{"id": "fur_tan", "display_name": "Fur Tan"},
	{"id": "fur_white", "display_name": "Fur White"},
	{"id": "green", "display_name": "Green"},
	{"id": "lavender", "display_name": "Lavender"},
	{"id": "light", "display_name": "Light"},
	{"id": "olive", "display_name": "Olive"},
	{"id": "pale_green", "display_name": "Pale Green"},
	{"id": "taupe", "display_name": "Taupe"},
	{"id": "zombie_green", "display_name": "Zombie Green"},
]

const HAIR_STYLE_OPTIONS := [
	{"id": "bedhead", "display_name": "Bedhead", "path": "hair/short/hair_bedhead"},
	{"id": "cowlick", "display_name": "Cowlick", "path": "hair/short/hair_cowlick"},
	{"id": "cowlick_tall", "display_name": "Cowlick Tall", "path": "hair/short/hair_cowlick_tall"},
	{"id": "curtains", "display_name": "Curtains", "path": "hair/short/hair_curtains"},
	{"id": "idol", "display_name": "Idol", "path": "hair/short/hair_idol"},
	{"id": "messy_1", "display_name": "Messy 1", "path": "hair/short/hair_messy1"},
	{"id": "messy_2", "display_name": "Messy 2", "path": "hair/short/hair_messy2"},
	{"id": "messy_3", "display_name": "Messy 3", "path": "hair/short/hair_messy3"},
	{"id": "mop", "display_name": "Mop", "path": "hair/short/hair_mop"},
	{"id": "page", "display_name": "Page", "path": "hair/short/hair_page"},
	{"id": "page_2", "display_name": "Page 2", "path": "hair/short/hair_page2"},
	{"id": "parted", "display_name": "Parted", "path": "hair/short/hair_parted"},
	{"id": "parted_2", "display_name": "Parted 2", "path": "hair/short/hair_parted2"},
	{"id": "parted_3", "display_name": "Parted 3", "path": "hair/short/hair_parted3"},
	{"id": "pixie", "display_name": "Pixie", "path": "hair/short/hair_pixie"},
	{"id": "plain", "display_name": "Plain", "path": "hair/short/hair_plain"},
	{"id": "short_bangs", "display_name": "Short Bangs", "path": "hair/short/hair_bangs"},
	{"id": "parted_side_bangs", "display_name": "Side Parted with Bangs", "path": "hair/short/hair_parted_side_bangs"},
	{"id": "parted_side_bangs_2", "display_name": "Side Parted with Bangs 2", "path": "hair/short/hair_parted_side_bangs2"},
	{"id": "swoop_side", "display_name": "Side Swoop", "path": "hair/short/hair_swoop_side"},
	{"id": "single", "display_name": "Single", "path": "hair/short/hair_single"},
	{"id": "swoop", "display_name": "Swoop", "path": "hair/short/hair_swoop"},
	{"id": "unkempt", "display_name": "Unkempt", "path": "hair/short/hair_unkempt"},
	{"id": "very_short_bangs", "display_name": "Very Short Bangs", "path": "hair/short/hair_bangsshort"},
	{"id": "bob", "display_name": "Bob", "path": "hair/bob/hair_bob"},
	{"id": "bob_side_part", "display_name": "Bob Side Part", "path": "hair/bob/hair_bob_side_part"},
	{"id": "lob", "display_name": "Lob", "path": "hair/bob/hair_lob"},
	{"id": "relm_short", "display_name": "Relm Short", "path": "hair/bob/hair_relm_short"},
	{"id": "curly_long", "display_name": "Curly Long", "path": "hair/curly/hair_curly_long"},
	{"id": "curly_short", "display_name": "Curly Short", "path": "hair/curly/hair_curly_short"},
	{"id": "curly_short_2", "display_name": "Curly Short 2", "path": "hair/curly/hair_curly_short2"},
	{"id": "jewfro", "display_name": "Jewfro", "path": "hair/curly/hair_jewfro"},
	{"id": "large_curls", "display_name": "Large Curls", "path": "hair/curly/hair_curls_large"},
	{"id": "large_curls_extra_long", "display_name": "Large Curls Extra Long", "path": "hair/curly/hair_curls_large_xlong"},
	{"id": "afro", "display_name": "Afro", "path": "hair/afro/hair_afro"},
	{"id": "cornrows", "display_name": "Cornrows", "path": "hair/afro/hair_cornrows"},
	{"id": "dreadlocks_long", "display_name": "Dreadlocks Long", "path": "hair/afro/hair_dreadlocks_long"},
	{"id": "dreadlocks_short", "display_name": "Dreadlocks Short", "path": "hair/afro/hair_dreadlocks_short"},
	{"id": "flat_top_fade", "display_name": "Flat Top Fade", "path": "hair/afro/hair_flat_top_fade"},
	{"id": "flat_top_straight", "display_name": "Flat Top Straight", "path": "hair/afro/hair_flat_top_straight"},
	{"id": "natural", "display_name": "Natural", "path": "hair/afro/hair_natural"},
	{"id": "twists_fade", "display_name": "Twists Fade", "path": "hair/afro/hair_twists_fade"},
	{"id": "twists_straight", "display_name": "Twists Straight", "path": "hair/afro/hair_twists_straight"},
	{"id": "bangs_bun", "display_name": "Bangs Bun", "path": "hair/braids/hair_bangs_bun"},
	{"id": "braid", "display_name": "Braid", "path": "hair/braids/hair_braid"},
	{"id": "braid_2", "display_name": "Braid 2", "path": "hair/braids/hair_braid2"},
	{"id": "half_up", "display_name": "Half Up", "path": "hair/braids/hair_half_up"},
	{"id": "high_ponytail", "display_name": "High Ponytail", "path": "hair/braids/hair_high_ponytail"},
	{"id": "long_tied", "display_name": "Long Tied", "path": "hair/braids/hair_long_tied"},
	{"id": "ponytail", "display_name": "Ponytail", "path": "hair/braids/hair_ponytail"},
	{"id": "ponytail_2", "display_name": "Ponytail 2", "path": "hair/braids/hair_ponytail2"},
	{"id": "short_topknot", "display_name": "Short Topknot", "path": "hair/braids/hair_topknot_short"},
	{"id": "short_topknot_2", "display_name": "Short Topknot 2", "path": "hair/braids/hair_topknot_short2"},
	{"id": "shoulder_braid_left", "display_name": "Shoulder Braid Left", "path": "hair/braids/hair_shoulderl"},
	{"id": "shoulder_braid_right", "display_name": "Shoulder Braid Right", "path": "hair/braids/hair_shoulderr"},
	{"id": "bunches", "display_name": "Bunches", "path": "hair/pigtails/hair_bunches"},
	{"id": "pigtails", "display_name": "Pigtails", "path": "hair/pigtails/hair_pigtails"},
	{"id": "pigtails_bangs", "display_name": "Pigtails Bangs", "path": "hair/pigtails/hair_pigtails_bangs"},
	{"id": "curtains_long", "display_name": "Curtains Long", "path": "hair/long/hair_curtains_long"},
	{"id": "long", "display_name": "Long", "path": "hair/long/hair_long"},
	{"id": "long_bangs", "display_name": "Long Bangs", "path": "hair/long/hair_bangslong"},
	{"id": "long_bangs_2", "display_name": "Long Bangs 2", "path": "hair/long/hair_bangslong2"},
	{"id": "long_center_part", "display_name": "Long Center Part", "path": "hair/long/hair_long_center_part"},
	{"id": "long_messy", "display_name": "Long Messy", "path": "hair/long/hair_long_messy"},
	{"id": "long_messy_2", "display_name": "Long Messy 2", "path": "hair/long/hair_long_messy2"},
	{"id": "long_straight", "display_name": "Long Straight", "path": "hair/long/hair_long_straight"},
	{"id": "loose", "display_name": "Loose", "path": "hair/long/hair_loose"},
	{"id": "wavy", "display_name": "Wavy", "path": "hair/long/hair_wavy"},
	{"id": "half_messy", "display_name": "Half-Messy", "path": "hair/spiky/hair_halfmessy"},
	{"id": "spiked", "display_name": "Spiked", "path": "hair/spiky/hair_spiked"},
	{"id": "spiked_2", "display_name": "Spiked 2", "path": "hair/spiky/hair_spiked2"},
	{"id": "spiked_beehive", "display_name": "Spiked Beehive", "path": "hair/spiky/hair_spiked_beehive"},
	{"id": "spiked_liberty", "display_name": "Spiked Liberty", "path": "hair/spiky/hair_spiked_liberty"},
	{"id": "spiked_liberty_2", "display_name": "Spiked Liberty 2", "path": "hair/spiky/hair_spiked_liberty2"},
	{"id": "spiked_porcupine", "display_name": "Spiked Porcupine", "path": "hair/spiky/hair_spiked_porcupine"},
	{"id": "balding", "display_name": "Balding", "path": "hair/bald/hair_balding"},
	{"id": "buzzcut", "display_name": "Buzzcut", "path": "hair/bald/hair_buzzcut"},
	{"id": "high_and_tight", "display_name": "High and Tight", "path": "hair/bald/hair_high_and_tight"},
	{"id": "longhawk", "display_name": "Longhawk", "path": "hair/bald/hair_longhawk"},
	{"id": "shorthawk", "display_name": "Shorthawk", "path": "hair/bald/hair_shorthawk"},
	{"id": "extra_long", "display_name": "Extra Long", "path": "hair/xlong/hair_xlong"},
	{"id": "extra_long_wavy", "display_name": "Extra Long Wavy", "path": "hair/xlong/hair_xlong_wavy"},
	{"id": "long_band", "display_name": "Long Band", "path": "hair/xlong/hair_long_band"},
	{"id": "princess", "display_name": "Princess", "path": "hair/xlong/hair_princess"},
	{"id": "relm_extra_long", "display_name": "Relm Extra Long", "path": "hair/braids/hair_relm_xlong"},
	{"id": "sara", "display_name": "Sara", "path": "hair/xlong/hair_sara"},
]

const HAIR_COLOR_OPTIONS := [
	{"id": "ash", "display_name": "Ash", "variant": "ash"},
	{"id": "black", "display_name": "Black", "variant": "black"},
	{"id": "blonde", "display_name": "Blonde", "variant": "blonde"},
	{"id": "blue", "display_name": "Blue", "variant": "blue"},
	{"id": "carrot", "display_name": "Carrot", "variant": "carrot"},
	{"id": "chestnut", "display_name": "Chestnut", "variant": "chestnut"},
	{"id": "dark_brown", "display_name": "Dark Brown", "variant": "dark brown"},
	{"id": "dark_gray", "display_name": "Dark Gray", "variant": "dark gray"},
	{"id": "ginger", "display_name": "Ginger", "variant": "ginger"},
	{"id": "gold", "display_name": "Gold", "variant": "gold"},
	{"id": "gray", "display_name": "Gray", "variant": "gray"},
	{"id": "green", "display_name": "Green", "variant": "green"},
	{"id": "light_brown", "display_name": "Light Brown", "variant": "light brown"},
	{"id": "navy", "display_name": "Navy", "variant": "navy"},
	{"id": "orange", "display_name": "Orange", "variant": "orange"},
	{"id": "pink", "display_name": "Pink", "variant": "pink"},
	{"id": "platinum", "display_name": "Platinum", "variant": "platinum"},
	{"id": "purple", "display_name": "Purple", "variant": "purple"},
	{"id": "raven", "display_name": "Raven", "variant": "raven"},
	{"id": "red", "display_name": "Red", "variant": "red"},
	{"id": "redhead", "display_name": "Redhead", "variant": "redhead"},
	{"id": "rose", "display_name": "Rose", "variant": "rose"},
	{"id": "sandy", "display_name": "Sandy", "variant": "sandy"},
	{"id": "strawberry", "display_name": "Strawberry", "variant": "strawberry"},
	{"id": "violet", "display_name": "Violet", "variant": "violet"},
	{"id": "white", "display_name": "White", "variant": "white"},
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
