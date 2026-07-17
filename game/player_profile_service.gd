class_name PlayerProfileService
extends RefCounted

var m_appearance_catalog_script = null
var m_costume_catalog_script = null
var m_player_costume_catalog: Dictionary = {}


func _init(
	appearance_catalog_script,
	costume_catalog_script,
	player_costume_catalog: Dictionary
) -> void:
	m_appearance_catalog_script = appearance_catalog_script
	m_costume_catalog_script = costume_catalog_script
	m_player_costume_catalog = player_costume_catalog.duplicate(true)


func normalize_profile(profile: Dictionary) -> Dictionary:
	return m_appearance_catalog_script.normalize_profile(profile)


func get_player_body_display_name(profile: Dictionary) -> String:
	return m_appearance_catalog_script.body_frame_display_name(
		String(profile.get("body_frame_id", "adult"))
	)


func get_player_gender_display_name(profile: Dictionary) -> String:
	return m_appearance_catalog_script.presentation_display_name(
		String(profile.get("presentation_id", "masculine"))
	)


func get_player_skin_display_name(profile: Dictionary) -> String:
	return m_appearance_catalog_script.skin_tone_display_name(
		String(profile.get("skin_tone_id", "light"))
	)


func get_player_hair_style_display_name(profile: Dictionary) -> String:
	return m_appearance_catalog_script.hair_style_display_name(
		String(profile.get("hair_style_id", "short_bangs"))
	)


func get_player_hair_color_display_name(profile: Dictionary) -> String:
	return m_appearance_catalog_script.hair_color_display_name(
		String(profile.get("hair_color_id", "chestnut"))
	)


func get_player_costume_ids() -> PackedStringArray:
	return m_costume_catalog_script.ordered_ids()


func get_player_costume(costume_id: String) -> Dictionary:
	if !m_player_costume_catalog.has(costume_id):
		return {}
	return m_player_costume_catalog[costume_id].duplicate(true)


func build_unlocked_costume_ids(
	mode_id: String,
	fragments_found: int,
	fragments_total: int,
	resident_profiles: Dictionary
) -> PackedStringArray:
	return m_costume_catalog_script.build_unlocked_costume_ids(
		mode_id,
		fragments_found,
		fragments_total,
		resident_profiles
	)


func resolve_equipped_costume_id(
	unlocked_ids: PackedStringArray,
	preferred_costume_id: String
) -> String:
	if unlocked_ids.find(preferred_costume_id) >= 0:
		return preferred_costume_id

	var default_costume_id: String = m_costume_catalog_script.default_costume_id()
	if unlocked_ids.find(default_costume_id) >= 0 or unlocked_ids.is_empty():
		return default_costume_id
	return String(unlocked_ids[0])


func get_equipped_player_costume(equipped_costume_id: String) -> Dictionary:
	return get_player_costume(equipped_costume_id)


func get_equipped_player_costume_display_name(equipped_costume_id: String) -> String:
	return String(
		get_equipped_player_costume(equipped_costume_id).get("display_name", "Harbor Arrival")
	)


func get_player_appearance_config(
	profile: Dictionary,
	equipped_costume_id: String
) -> Dictionary:
	var costume: Dictionary = get_equipped_player_costume(equipped_costume_id)
	var costume_selections: Dictionary = costume.get("selections", {})
	return m_appearance_catalog_script.build_appearance_config(profile, costume_selections)


func cycle_costume_id(
	unlocked_ids: PackedStringArray,
	current_costume_id: String,
	direction: int
) -> String:
	if unlocked_ids.is_empty():
		return current_costume_id

	var current_index := unlocked_ids.find(current_costume_id)
	if current_index < 0:
		return String(unlocked_ids[0])

	var next_index := posmod(current_index + direction, unlocked_ids.size())
	return String(unlocked_ids[next_index])
