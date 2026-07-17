class_name AppStateProjection
extends RefCounted

var mode_id: StringName = AppStateSnapshot.MODE_TITLE
var mode := "Title"
var chapter := "Arrival"
var season_phase := ""
var season_display_name := ""
var story_day := 1
var world_hour := 8.0
var time_of_day := "morning"
var time_of_day_display_name := "Morning"
var story_time_label := "Day 1, Morning"
var location := ""
var objective := ""
var hint := ""
var save_status := ""
var journal_unlocked := true
var open_shortcuts := PackedStringArray()
var fragments_found := 0
var fragments_total := 0
var melody_definitions: Dictionary = {}
var melody_progress: Dictionary = {}
var landmark_names := PackedStringArray()
var landmark_progress: Dictionary = {}
var route_definitions: Dictionary = {}
var event_definitions: Dictionary = {}
var route_ids := PackedStringArray()
var route_progress: Dictionary = {}
var story_flags: Dictionary = {}
var available_lead_ids := PackedStringArray()
var active_lead_id := ""
var active_lead_text := ""
var manual_lead_pinned := false
var route_emphasis_text := ""
var endgame_state: Dictionary = {}
var ending_summary: Dictionary = {}
var resident_ids := PackedStringArray()
var resident_profiles: Dictionary = {}
var resident_definitions: Dictionary = {}
var resident_routine_overrides: Dictionary = {}
var known_resident_names := PackedStringArray()
var player_profile: Dictionary = {}
var player_appearance_config: Dictionary = {}
var player_costume_catalog: Dictionary = {}
var player_costume_ids := PackedStringArray()
var unlocked_player_costume_ids := PackedStringArray()
var equipped_player_costume_id := ""
var equipped_player_costume: Dictionary = {}
var player_body_display_name := ""
var player_gender_display_name := ""
var player_skin_display_name := ""
var player_hair_style_display_name := ""
var player_hair_color_display_name := ""
var master_volume_percent := 100.0
var music_volume_percent := 100.0
var prompt_volume_percent := 100.0
var dialogue_text_speed_percent := 100.0
var dialogue_text_characters_per_second := 0.0
var story_resume_anchor_id := ""
var story_resume_location := ""
var save_metadata: Dictionary = {}


func duplicate_projection() -> AppStateProjection:
	var copy := AppStateProjection.new()
	for property in get_property_list():
		var property_name := StringName(property.get("name", ""))
		if property_name == &"" or property_name in [&"RefCounted", &"script", &"resource_local_to_scene", &"resource_path", &"resource_name", &"resource_scene_unique_id"]:
			continue
		var usage := int(property.get("usage", 0))
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = get(property_name)
		if value is Dictionary or value is Array:
			copy.set(property_name, value.duplicate(true))
		elif value is PackedStringArray:
			copy.set(property_name, PackedStringArray(value))
		else:
			copy.set(property_name, value)
	return copy


func get_story_time_state() -> Dictionary:
	return {
		"story_day": story_day,
		"world_hour": world_hour,
		"time_of_day": time_of_day,
	}


func get_melody_ids() -> PackedStringArray:
	return PackedStringArray(melody_definitions.keys())


func get_melody_definition(melody_id: String) -> Dictionary:
	return melody_definitions.get(melody_id, {}).duplicate(true)


func get_melody_state(melody_id: String) -> Dictionary:
	return melody_progress.get(melody_id, {}).duplicate(true)


func get_landmark_progress(landmark_id: String) -> Dictionary:
	return landmark_progress.get(landmark_id, {}).duplicate(true)


func get_landmark_state(landmark_id: String) -> String:
	return String(landmark_progress.get(landmark_id, {}).get("state", "locked"))


func get_route_progress(route_id: String) -> Dictionary:
	return route_progress.get(route_id, {}).duplicate(true)


func get_story_route_definition(route_id: String) -> Dictionary:
	return route_definitions.get(route_id, {}).duplicate(true)


func get_story_event_definition(event_id: String) -> Dictionary:
	return event_definitions.get(event_id, {}).duplicate(true)


func get_resident_profile(resident_id: String) -> Dictionary:
	return resident_profiles.get(resident_id, {}).duplicate(true)


func get_resident_definition(resident_id: String):
	return resident_definitions.get(resident_id)


func get_resident_display_name(resident_id: String) -> String:
	var definition = resident_definitions.get(resident_id)
	if definition != null and !definition.display_name.is_empty():
		return definition.display_name
	return String(resident_profiles.get(resident_id, {}).get("display_name", "Resident"))


func get_resident_spawn_config(resident_id: String) -> Dictionary:
	return _get_resident_config(resident_id, "spawn")


func get_resident_movement_config(resident_id: String) -> Dictionary:
	return _get_resident_config(resident_id, "movement")


func get_resident_behavior_config(resident_id: String) -> Dictionary:
	return _get_resident_config(resident_id, "behavior")


func get_resident_appearance_config(resident_id: String) -> Dictionary:
	var definition = resident_definitions.get(resident_id)
	if definition != null:
		var appearance: Dictionary = definition.build_appearance_config()
		if !appearance.is_empty():
			return appearance
	return resident_profiles.get(resident_id, {}).get("appearance", {}).duplicate(true)


func get_player_costume(costume_id: String) -> Dictionary:
	return player_costume_catalog.get(costume_id, {}).duplicate(true)


func get_equipped_player_costume_display_name() -> String:
	return String(equipped_player_costume.get("display_name", "Harbor Arrival"))


func _get_resident_config(resident_id: String, section: String) -> Dictionary:
	var base: Dictionary = {}
	var definition = resident_definitions.get(resident_id)
	if definition != null:
		match section:
			"spawn":
				base = definition.get_spawn_config()
			"movement":
				base = definition.get_movement_config()
			"behavior":
				base = definition.get_behavior_config()
	if base.is_empty():
		base = resident_profiles.get(resident_id, {}).get(section, {}).duplicate(true)
	var override_value: Variant = resident_routine_overrides.get(resident_id, {}).get(section, {})
	if override_value is Dictionary:
		base.merge((override_value as Dictionary).duplicate(true), true)
	return base
