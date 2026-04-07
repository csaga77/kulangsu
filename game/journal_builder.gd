class_name JournalBuilder
extends RefCounted

const MELODY_CATALOG_SCRIPT := preload("res://game/melody_catalog.gd")
const RESIDENT_CATALOG_SCRIPT := preload("res://game/resident_catalog.gd")


static func build_map_journal_text(app_state: Node) -> String:
	var landmark_text := "None marked yet."
	if !app_state.landmarks.is_empty():
		landmark_text = "\n".join(app_state.landmarks)

	var shortcut_text := "No dependable routes noted yet."
	var open_shortcuts: PackedStringArray = app_state.get_open_shortcuts()
	if !open_shortcuts.is_empty():
		var shortcut_sections: Array[String] = []
		for shortcut_id in open_shortcuts:
			var shortcut_definition: Dictionary = app_state.SHORTCUT_DEFINITIONS.get(String(shortcut_id), {})
			shortcut_sections.append(
				"%s\n%s" % [
					String(shortcut_definition.get("display_name", shortcut_id)),
					String(shortcut_definition.get("summary", "")),
				]
			)
		shortcut_text = "\n\n".join(PackedStringArray(shortcut_sections))

	return "Discovered landmarks\n%s\n\nCurrent location\n%s\n\nDependable routes\n%s" % [
		landmark_text,
		app_state.location,
		shortcut_text,
	]


static func build_resident_journal_text(app_state: Node) -> String:
	var sections: Array[String] = []

	for resident_id in app_state.get_resident_ids():
		var resident: Dictionary = app_state.get_resident_profile(String(resident_id))
		if !bool(resident.get("known", false)):
			continue

		sections.append(
			"%s\n%s\nUsually found: %s\nTrust: %d / %d\nCurrent lead: %s\nMelody clue: %s" % [
				String(resident.get("display_name", resident_id)),
				String(resident.get("role", "")),
				String(resident.get("routine_note", "")),
				int(resident.get("trust", 0)),
				RESIDENT_CATALOG_SCRIPT.max_trust(),
				String(resident.get("current_step", "Stay in touch.")),
				String(resident.get("melody_hint", "")),
			]
		)

	if sections.is_empty():
		return "No residents introduced yet.\n\nListen for a nearby greeting or use R when a talk prompt appears."

	return "\n\n".join(PackedStringArray(sections))


static func build_melody_journal_text(app_state: Node) -> String:
	var sections: Array[String] = []

	for melody_id in app_state.get_melody_ids():
		var melody_definition: Dictionary = app_state.get_melody_definition(String(melody_id))
		if melody_definition.is_empty():
			continue

		var melody_state: Dictionary = app_state.get_melody_state(String(melody_id))
		var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
		var source_lines: Array[String] = []

		for source in melody_definition.get("sources", []):
			var source_id := String(source.get("source_id", ""))
			var source_status := "Not yet confirmed"
			if known_sources.find(source_id) >= 0:
				source_status = "Confirmed clue"

			source_lines.append(
				"%s (%s)\n%s\n%s" % [
					String(source.get("label", "Unknown clue")),
					String(source.get("landmark", "Unknown landmark")),
					source_status,
					String(source.get("summary", "")),
				]
			)

		sections.append(
			"%s\nDistrict: %s\nStage: %s\nRecovered fragments: %d / %d\nSummary: %s\nNext lead: %s\nPerformance point: %s\nWorld response: %s\n\nClue map\n%s" % [
				String(melody_definition.get("display_name", melody_id)),
				String(melody_definition.get("district", "Unknown district")),
				MELODY_CATALOG_SCRIPT.state_display_name(String(melody_state.get("state", "unknown"))),
				int(melody_state.get("fragments_found", 0)),
				int(melody_state.get("fragments_total", int(melody_definition.get("fragment_total", 0)))),
				String(melody_definition.get("summary", "")),
				String(melody_state.get("next_lead", melody_definition.get("unlock_condition", ""))),
				String(melody_definition.get("performance_landmark", "Unknown")),
				String(melody_definition.get("world_response_summary", "")),
				"\n\n".join(PackedStringArray(source_lines)),
			]
		)

	if sections.is_empty():
		return "No melody notes recorded yet.\n\nKeep exploring, listen for a repeated phrase, and check the journal after each major clue."

	return "\n\n".join(PackedStringArray(sections))


static func build_player_costume_journal_text(app_state: Node) -> String:
	var sections: Array[String] = []
	var unlocked_ids: PackedStringArray = app_state.get_unlocked_player_costume_ids()

	sections.append(
		"Current look: %s\nBody: %s\nGender: %s\nHair: %s\nHair color: %s\nUnlocked looks: %d / %d\nUse the controls below to change costume and hair." % [
			app_state.get_equipped_player_costume_display_name(),
			app_state.get_player_body_display_name(),
			app_state.get_player_gender_display_name(),
			app_state.get_player_hair_style_display_name(),
			app_state.get_player_hair_color_display_name(),
			unlocked_ids.size(),
			app_state.get_player_costume_ids().size(),
		]
	)

	for costume_id_value in app_state.get_player_costume_ids():
		var costume_id := String(costume_id_value)
		var costume: Dictionary = app_state.get_player_costume(costume_id)
		var is_unlocked: bool = unlocked_ids.find(costume_id) >= 0
		var state_text := "Locked"
		if costume_id == app_state.get_equipped_player_costume_id():
			state_text = "Wearing"
		elif is_unlocked:
			state_text = "Unlocked"

		sections.append(
			"%s: %s\n%s\nRoute: %s" % [
				state_text,
				String(costume.get("display_name", costume_id)),
				String(costume.get("summary", "")),
				String(costume.get("unlock_hint", "Always available.")),
			]
		)

	return "\n\n".join(PackedStringArray(sections))


static func build_player_setup_summary_text(app_state: Node) -> String:
	return "Body: %s\nGender: %s\nSkin: %s\nHair: %s\nHair color: %s\nStarting look: %s" % [
		app_state.get_player_body_display_name(),
		app_state.get_player_gender_display_name(),
		app_state.get_player_skin_display_name(),
		app_state.get_player_hair_style_display_name(),
		app_state.get_player_hair_color_display_name(),
		app_state.get_equipped_player_costume_display_name(),
	]


static func _normalize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []

	if value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
		return output

	if value is Array:
		for entry in value:
			output.append(String(entry))

	return output
