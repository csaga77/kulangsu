class_name PlayerProfileService
extends RefCounted

var m_owner: Node = null
var m_appearance_catalog_script = null
var m_costume_catalog_script = null
var m_player_costume_catalog: Dictionary = {}
var m_player_profile: Dictionary = {}
var m_unlocked_player_costume_ids: PackedStringArray = PackedStringArray()
var m_equipped_player_costume_id := ""


func _init(
	owner: Node,
	appearance_catalog_script,
	costume_catalog_script,
	player_costume_catalog: Dictionary,
	mode_id: String,
	fragments_found: int,
	fragments_total: int,
	resident_profiles: Dictionary
) -> void:
	m_owner = owner
	m_appearance_catalog_script = appearance_catalog_script
	m_costume_catalog_script = costume_catalog_script
	m_player_costume_catalog = player_costume_catalog.duplicate(true)
	m_player_profile = m_appearance_catalog_script.default_profile()
	m_unlocked_player_costume_ids = m_costume_catalog_script.build_unlocked_costume_ids(
		mode_id,
		fragments_found,
		fragments_total,
		resident_profiles
	)
	m_equipped_player_costume_id = m_costume_catalog_script.default_costume_id()
	if m_unlocked_player_costume_ids.find(m_equipped_player_costume_id) < 0 and !m_unlocked_player_costume_ids.is_empty():
		m_equipped_player_costume_id = String(m_unlocked_player_costume_ids[0])
	_sync_owner_state()


func get_player_profile() -> Dictionary:
	return m_player_profile.duplicate(true)


func get_player_body_display_name() -> String:
	return m_appearance_catalog_script.body_frame_display_name(
		String(m_player_profile.get("body_frame_id", "adult"))
	)


func get_player_gender_display_name() -> String:
	return m_appearance_catalog_script.presentation_display_name(
		String(m_player_profile.get("presentation_id", "masculine"))
	)


func get_player_skin_display_name() -> String:
	return m_appearance_catalog_script.skin_tone_display_name(
		String(m_player_profile.get("skin_tone_id", "light"))
	)


func get_player_hair_style_display_name() -> String:
	return m_appearance_catalog_script.hair_style_display_name(
		String(m_player_profile.get("hair_style_id", "short_bangs"))
	)


func get_player_hair_color_display_name() -> String:
	return m_appearance_catalog_script.hair_color_display_name(
		String(m_player_profile.get("hair_color_id", "chestnut"))
	)


func get_player_costume_ids() -> PackedStringArray:
	return m_costume_catalog_script.ordered_ids()


func get_player_costume(costume_id: String) -> Dictionary:
	if !m_player_costume_catalog.has(costume_id):
		return {}
	return m_player_costume_catalog[costume_id].duplicate(true)


func get_unlocked_player_costume_ids() -> PackedStringArray:
	return PackedStringArray(m_unlocked_player_costume_ids)


func get_equipped_player_costume_id() -> String:
	return m_equipped_player_costume_id


func get_equipped_player_costume() -> Dictionary:
	return get_player_costume(m_equipped_player_costume_id)


func get_equipped_player_costume_display_name() -> String:
	return String(get_equipped_player_costume().get("display_name", "Harbor Arrival"))


func set_player_profile(new_profile: Dictionary) -> bool:
	var normalized_profile: Dictionary = m_appearance_catalog_script.normalize_profile(new_profile)
	if m_player_profile == normalized_profile:
		return false

	m_player_profile = normalized_profile
	_sync_owner_state()
	m_owner._emit_player_profile_changed(get_player_profile())
	_emit_player_appearance_changed()
	return true


func cycle_player_body_frame(direction: int) -> void:
	_cycle_player_profile_option(
		"body_frame_id",
		m_appearance_catalog_script.body_frame_options(),
		direction
	)


func cycle_player_gender(direction: int) -> void:
	_cycle_player_profile_option(
		"presentation_id",
		m_appearance_catalog_script.presentation_options(),
		direction
	)


func cycle_player_skin_tone(direction: int) -> void:
	_cycle_player_profile_option(
		"skin_tone_id",
		m_appearance_catalog_script.skin_tone_options(),
		direction
	)


func cycle_player_hair_style(direction: int) -> void:
	_cycle_player_profile_option(
		"hair_style_id",
		m_appearance_catalog_script.hair_style_options(),
		direction
	)


func cycle_player_hair_color(direction: int) -> void:
	_cycle_player_profile_option(
		"hair_color_id",
		m_appearance_catalog_script.hair_color_options(),
		direction
	)


func get_player_appearance_config() -> Dictionary:
	var costume: Dictionary = get_equipped_player_costume()
	var costume_selections: Dictionary = costume.get("selections", {})
	return m_appearance_catalog_script.build_appearance_config(m_player_profile, costume_selections)


func equip_player_costume(costume_id: String) -> bool:
	if !m_player_costume_catalog.has(costume_id):
		return false
	if m_unlocked_player_costume_ids.find(costume_id) < 0:
		return false
	if m_equipped_player_costume_id == costume_id:
		return true

	m_equipped_player_costume_id = costume_id
	_sync_owner_state()
	m_owner._emit_player_costume_changed(m_equipped_player_costume_id, get_equipped_player_costume())
	_emit_player_appearance_changed()
	m_owner._emit_player_costumes_changed(get_unlocked_player_costume_ids(), m_equipped_player_costume_id)
	return true


func cycle_player_costume(direction: int) -> void:
	if m_unlocked_player_costume_ids.is_empty():
		return

	var current_index := m_unlocked_player_costume_ids.find(m_equipped_player_costume_id)
	if current_index < 0:
		equip_player_costume(String(m_unlocked_player_costume_ids[0]))
		return

	var next_index := posmod(current_index + direction, m_unlocked_player_costume_ids.size())
	equip_player_costume(String(m_unlocked_player_costume_ids[next_index]))


func refresh_player_costumes(
	mode_id: String,
	fragments_found: int,
	fragments_total: int,
	resident_profiles: Dictionary
) -> void:
	var next_unlocked: PackedStringArray = m_costume_catalog_script.build_unlocked_costume_ids(
		mode_id,
		fragments_found,
		fragments_total,
		resident_profiles
	)
	var unlocked_changed: bool = m_unlocked_player_costume_ids != next_unlocked
	var next_equipped := m_equipped_player_costume_id

	if next_unlocked.find(next_equipped) < 0:
		next_equipped = m_costume_catalog_script.default_costume_id()
		if next_unlocked.find(next_equipped) < 0 and !next_unlocked.is_empty():
			next_equipped = String(next_unlocked[0])

	var costume_changed := next_equipped != m_equipped_player_costume_id

	m_unlocked_player_costume_ids = next_unlocked
	m_equipped_player_costume_id = next_equipped
	_sync_owner_state()

	if costume_changed:
		m_owner._emit_player_costume_changed(m_equipped_player_costume_id, get_equipped_player_costume())
		_emit_player_appearance_changed()

	if unlocked_changed or costume_changed:
		m_owner._emit_player_costumes_changed(get_unlocked_player_costume_ids(), m_equipped_player_costume_id)


func _cycle_player_profile_option(profile_key: String, options: Array, direction: int) -> void:
	var next_profile := get_player_profile()
	var current_id := String(next_profile.get(profile_key, ""))
	next_profile[profile_key] = m_appearance_catalog_script.cycle_option_id(options, current_id, direction)
	set_player_profile(next_profile)


func _emit_player_appearance_changed() -> void:
	m_owner.player_appearance_changed.emit(get_player_profile(), get_player_appearance_config())


func _sync_owner_state() -> void:
	m_owner.player_profile = get_player_profile()
	m_owner.unlocked_player_costume_ids = get_unlocked_player_costume_ids()
	m_owner.equipped_player_costume_id = m_equipped_player_costume_id
