class_name AppStateSnapshot
extends RefCounted

const MODE_TITLE := &"title"
const MODE_STORY := &"story"
const MODE_FREE_WALK := &"free_walk"

var mode_id: StringName = MODE_TITLE
var season_phase := ""
var story_day := 1
var world_hour := 8.0
var location := ""
var objective := ""
var hint := ""
var save_status := ""
var journal_unlocked := true
var open_shortcuts := PackedStringArray()
var melody_progress: Dictionary = {}
var landmark_progress: Dictionary = {}
var story_flags: Dictionary = {}
var endgame_state: Dictionary = {}
var manual_pinned_lead_id := ""
var resident_profiles: Dictionary = {}
var resident_routine_overrides: Dictionary = {}
var player_profile: Dictionary = {}
var equipped_player_costume_id := ""
var master_volume_percent := 100.0
var music_volume_percent := 100.0
var prompt_volume_percent := 100.0
var dialogue_text_speed_percent := 100.0
var story_resume_anchor_id := ""
var story_resume_location := ""
var save_metadata: Dictionary = {}


func duplicate_state() -> AppStateSnapshot:
	var copy := AppStateSnapshot.new()
	copy.mode_id = mode_id
	copy.season_phase = season_phase
	copy.story_day = story_day
	copy.world_hour = world_hour
	copy.location = location
	copy.objective = objective
	copy.hint = hint
	copy.save_status = save_status
	copy.journal_unlocked = journal_unlocked
	copy.open_shortcuts = PackedStringArray(open_shortcuts)
	copy.melody_progress = melody_progress.duplicate(true)
	copy.landmark_progress = landmark_progress.duplicate(true)
	copy.story_flags = story_flags.duplicate(true)
	copy.endgame_state = endgame_state.duplicate(true)
	copy.manual_pinned_lead_id = manual_pinned_lead_id
	copy.resident_profiles = resident_profiles.duplicate(true)
	copy.resident_routine_overrides = resident_routine_overrides.duplicate(true)
	copy.player_profile = player_profile.duplicate(true)
	copy.equipped_player_costume_id = equipped_player_costume_id
	copy.master_volume_percent = master_volume_percent
	copy.music_volume_percent = music_volume_percent
	copy.prompt_volume_percent = prompt_volume_percent
	copy.dialogue_text_speed_percent = dialogue_text_speed_percent
	copy.story_resume_anchor_id = story_resume_anchor_id
	copy.story_resume_location = story_resume_location
	copy.save_metadata = save_metadata.duplicate(true)
	return copy


func canonical_dictionary(include_settings: bool = true, include_save_metadata: bool = true) -> Dictionary:
	var output := {
		"mode_id": String(mode_id),
		"season_phase": season_phase,
		"story_day": story_day,
		"world_hour": world_hour,
		"location": location,
		"objective": objective,
		"hint": hint,
		"save_status": save_status,
		"journal_unlocked": journal_unlocked,
		"open_shortcuts": PackedStringArray(open_shortcuts),
		"melody_progress": melody_progress.duplicate(true),
		"landmark_progress": landmark_progress.duplicate(true),
		"story_flags": story_flags.duplicate(true),
		"endgame_state": endgame_state.duplicate(true),
		"manual_pinned_lead_id": manual_pinned_lead_id,
		"resident_profiles": resident_profiles.duplicate(true),
		"resident_routine_overrides": resident_routine_overrides.duplicate(true),
		"player_profile": player_profile.duplicate(true),
		"equipped_player_costume_id": equipped_player_costume_id,
		"story_resume_anchor_id": story_resume_anchor_id,
		"story_resume_location": story_resume_location,
	}
	if include_settings:
		output["settings"] = {
			"master_volume_percent": master_volume_percent,
			"music_volume_percent": music_volume_percent,
			"prompt_volume_percent": prompt_volume_percent,
			"dialogue_text_speed_percent": dialogue_text_speed_percent,
		}
	if include_save_metadata:
		output["save_metadata"] = save_metadata.duplicate(true)
	return output


static func mode_display_name(value: StringName) -> String:
	match value:
		MODE_STORY:
			return "Story"
		MODE_FREE_WALK:
			return "Free Walk"
		_:
			return "Title"


static func normalize_mode_id(value: Variant) -> StringName:
	var normalized := String(value).strip_edges().to_lower().replace(" ", "_")
	match normalized:
		"story":
			return MODE_STORY
		"free_walk":
			return MODE_FREE_WALK
		_:
			return MODE_TITLE
