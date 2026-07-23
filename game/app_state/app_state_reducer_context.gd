class_name AppStateReducerContext
extends RefCounted

const RESIDENT_CATALOG := preload("res://game/resident_catalog.gd")
const MELODY_CATALOG := preload("res://game/melody_catalog.gd")
const PLAYER_APPEARANCE_CATALOG := preload("res://game/player_appearance_catalog.gd")
const PLAYER_COSTUME_CATALOG := preload("res://game/player_costume_catalog.gd")
const PLAYER_PROFILE_SERVICE := preload("res://game/player_profile_service.gd")
const STORY_ROUTE_GRAPH := preload("res://game/story_route_graph.gd")
const STORY_EVENT_SERVICE := preload("res://game/story_event_service.gd")
const STORY_TIME_SERVICE := preload("res://game/story_time_service.gd")
const LANDMARK_PROGRESSION := preload("res://game/landmark_progression.gd")
const LANDMARK_CATALOG := preload("res://game/landmarks/landmark_catalog.gd")
const AUDIO_SETTINGS_SERVICE := preload("res://game/audio_settings_service.gd")
const RESIDENT_INTERACTION_SERVICE := preload("res://game/resident_interaction_service.gd")
const STORY_SEASON_PHASES := preload("res://game/story_season_phases.gd")
const STORY_MOMENT_LEDGER := preload("res://game/story_moment_ledger.gd")

const SHORTCUT_DEFINITIONS := {
	"bi_shan_crossing": {
		"display_name": "Bi Shan Tunnel Route",
		"summary": "The Bi Shan tunnel now reads as a dependable passage between the island's north and south approaches.",
	},
}

const EVENT_MELODY_HINT := &"melody_hint"
const EVENT_MELODY_PROMPT := &"melody_prompt"
const EVENT_LANDMARK_AUDIO := &"landmark_audio"
const EVENT_STORY_MILESTONE := &"story_milestone"

var transition: AppStateTransition
var projection: AppStateProjection

static var s_resident_definitions: Dictionary = {}
static var s_melody_catalog: Dictionary = {}
static var s_player_costume_catalog: Dictionary = {}

var m_story_route_graph
var m_story_event_service
var m_resident_interaction_service
var m_story_time_service := STORY_TIME_SERVICE.new()
var m_landmark_progression := LANDMARK_PROGRESSION.new()
var m_audio_settings_service := AUDIO_SETTINGS_SERVICE.new()
var m_player_profile_service
var m_resident_definitions: Dictionary = {}
var m_melody_catalog: Dictionary = {}
var m_player_costume_catalog: Dictionary = {}


func _init(
	source_transition: AppStateTransition,
	source_projection: AppStateProjection = null
) -> void:
	transition = source_transition
	_initialize_shared_catalogs()
	m_melody_catalog = s_melody_catalog
	m_player_costume_catalog = s_player_costume_catalog
	m_resident_definitions = s_resident_definitions
	m_player_profile_service = PLAYER_PROFILE_SERVICE.new(
		PLAYER_APPEARANCE_CATALOG,
		PLAYER_COSTUME_CATALOG,
		m_player_costume_catalog
	)
	m_story_route_graph = STORY_ROUTE_GRAPH.new(self)
	m_story_event_service = STORY_EVENT_SERVICE.new(self)
	m_resident_interaction_service = RESIDENT_INTERACTION_SERVICE.new(self)
	if source_projection != null:
		projection = source_projection.duplicate_projection()
	else:
		normalize_snapshot()
		projection = _build_projection()


static func _initialize_shared_catalogs() -> void:
	if s_resident_definitions.is_empty():
		s_resident_definitions = RESIDENT_CATALOG.build_definitions()
	if s_melody_catalog.is_empty():
		s_melody_catalog = MELODY_CATALOG.build_catalog()
	if s_player_costume_catalog.is_empty():
		s_player_costume_catalog = PLAYER_COSTUME_CATALOG.build_catalog()


func dispose() -> void:
	if m_story_route_graph != null:
		m_story_route_graph.detach_runtime()
	if m_story_event_service != null:
		m_story_event_service.detach_runtime()
	if m_resident_interaction_service != null:
		m_resident_interaction_service.detach_runtime()
	m_story_route_graph = null
	m_story_event_service = null
	m_resident_interaction_service = null


func normalize_snapshot() -> void:
	var state := transition.next_snapshot
	state.mode_id = AppStateSnapshot.normalize_mode_id(state.mode_id)
	if !STORY_SEASON_PHASES.runtime_phase_ids().has(state.season_phase):
		state.season_phase = STORY_SEASON_PHASES.DEFAULT_PHASE
	var normalized_time := STORY_TIME_SERVICE.normalize_time_state({
		"story_day": state.story_day,
		"world_hour": state.world_hour,
	})
	state.story_day = int(normalized_time.get("story_day", STORY_TIME_SERVICE.DEFAULT_STORY_DAY))
	state.world_hour = float(normalized_time.get("world_hour", STORY_TIME_SERVICE.DEFAULT_WORLD_HOUR))
	state.story_flags = m_story_route_graph.normalize_story_flags(state.story_flags)
	state.story_flags = STORY_MOMENT_LEDGER.normalize_story_flags(
		state.story_flags,
		transition.base_snapshot.story_flags
	)
	state.endgame_state = m_story_route_graph.normalize_endgame_state(state.endgame_state)
	state.melody_progress = _normalize_melody_progress(state.melody_progress)
	state.landmark_progress = _normalize_landmark_progress(state.landmark_progress)
	state.resident_profiles = _normalize_resident_profiles(state.resident_profiles)
	state.resident_routine_overrides = _normalize_dictionary_values(
		state.resident_routine_overrides
	)
	state.player_profile = m_player_profile_service.normalize_profile(state.player_profile)
	state.open_shortcuts = _normalize_shortcuts(state.open_shortcuts)
	state.master_volume_percent = m_audio_settings_service.normalize_volume_percent(
		state.master_volume_percent
	)
	state.music_volume_percent = m_audio_settings_service.normalize_volume_percent(
		state.music_volume_percent
	)
	state.prompt_volume_percent = m_audio_settings_service.normalize_volume_percent(
		state.prompt_volume_percent
	)
	state.dialogue_text_speed_percent = \
		m_audio_settings_service.normalize_dialogue_text_speed_percent(
			state.dialogue_text_speed_percent
		)
	var default_location := LANDMARK_CATALOG.default_resume_display_name()
	if state.location.strip_edges().is_empty():
		state.location = default_location
	if state.story_resume_anchor_id.strip_edges().is_empty():
		state.story_resume_anchor_id = default_location
	if state.story_resume_location.strip_edges().is_empty():
		state.story_resume_location = state.location


func rebuild_projection() -> AppStateProjection:
	projection = _build_projection()
	return projection


func reset_for_mode(mode_id: StringName) -> void:
	var previous := transition.next_snapshot
	var state := AppStateSnapshot.new()
	state.mode_id = mode_id
	state.master_volume_percent = previous.master_volume_percent
	state.music_volume_percent = previous.music_volume_percent
	state.prompt_volume_percent = previous.prompt_volume_percent
	state.dialogue_text_speed_percent = previous.dialogue_text_speed_percent
	state.save_metadata = previous.save_metadata.duplicate(true)
	state.season_phase = preload("res://game/story_season_phases.gd").DEFAULT_PHASE
	state.story_day = STORY_TIME_SERVICE.DEFAULT_STORY_DAY
	state.world_hour = STORY_TIME_SERVICE.DEFAULT_WORLD_HOUR
	state.location = LANDMARK_CATALOG.default_resume_display_name()
	state.story_resume_anchor_id = state.location
	state.story_resume_location = state.location
	state.open_shortcuts = PackedStringArray()
	state.story_flags = m_story_route_graph.build_default_story_flags()
	state.endgame_state = STORY_ROUTE_GRAPH.default_endgame_state()
	state.manual_pinned_lead_id = ""
	state.resident_profiles = _default_resident_profiles()
	state.resident_routine_overrides = {}
	state.player_profile = PLAYER_APPEARANCE_CATALOG.default_profile()
	state.equipped_player_costume_id = PLAYER_COSTUME_CATALOG.default_costume_id()
	match mode_id:
		AppStateSnapshot.MODE_STORY:
			state.objective = "Find out why the island feels quiet today."
			state.journal_unlocked = false
			state.hint = _build_input_hint_for_state(state, "R Inspect")
			state.save_status = "Autosave: story start saved"
			state.melody_progress = _build_story_melody_progress("new_game")
			state.landmark_progress = LANDMARK_CATALOG.build_progress(&"new_game")
		AppStateSnapshot.MODE_FREE_WALK:
			state.objective = "Wander the island and learn how the first district wants to be introduced."
			state.journal_unlocked = true
			state.hint = _build_input_hint_for_state(state, "R Inspect")
			state.save_status = "Free Walk: sandbox ready"
			state.melody_progress = _build_story_melody_progress("free_walk")
			state.landmark_progress = LANDMARK_CATALOG.build_progress(&"free_walk")
		_:
			state.objective = "Find out why the island feels quiet today."
			state.journal_unlocked = true
			state.hint = _build_input_hint_for_state(state, "R Inspect")
			state.save_status = "Autosave: ready when story begins"
			state.melody_progress = _default_melody_progress()
			state.landmark_progress = LANDMARK_CATALOG.build_progress(&"default")
	transition.replace_snapshot(state, true)
	normalize_snapshot()
	projection = _build_projection()
	if mode_id == AppStateSnapshot.MODE_FREE_WALK:
		for resident_id in RESIDENT_CATALOG.resident_order():
			m_resident_interaction_service._seed_resident_progress(
				resident_id,
				1,
				1,
				"introduced",
				"Sandbox resident notes are available in free walk."
			)
		projection = _build_projection()
	if mode_id == AppStateSnapshot.MODE_STORY:
		transition.request_autosave()


func get_mode() -> String:
	return AppStateSnapshot.mode_display_name(transition.next_snapshot.mode_id)


func get_chapter() -> String:
	return projection.chapter


func get_season_phase() -> String:
	return transition.next_snapshot.season_phase


func get_location() -> String:
	return transition.next_snapshot.location


func get_save_status() -> String:
	return transition.next_snapshot.save_status


func get_fragments_found() -> int:
	return projection.fragments_found


func get_fragments_total() -> int:
	return projection.fragments_total


func get_active_lead_id() -> String:
	return projection.active_lead_id


func get_available_lead_ids() -> PackedStringArray:
	return PackedStringArray(projection.available_lead_ids)


func get_endgame_state() -> Dictionary:
	return transition.next_snapshot.endgame_state.duplicate(true)


func get_melody_progress() -> Dictionary:
	return transition.next_snapshot.melody_progress.duplicate(true)


func get_story_day() -> int:
	return transition.next_snapshot.story_day


func get_world_hour() -> float:
	return transition.next_snapshot.world_hour


func get_time_of_day() -> String:
	return STORY_TIME_SERVICE.time_of_day_for_hour(get_world_hour())


func get_story_flags() -> Dictionary:
	return transition.next_snapshot.story_flags.duplicate(true)


func get_story_flag(flag_id: String, default_value: Variant = false) -> Variant:
	return transition.next_snapshot.story_flags.get(flag_id, default_value)


func get_route_progress(route_id: String = "") -> Dictionary:
	if route_id.is_empty():
		return projection.route_progress.duplicate(true)
	return projection.route_progress.get(route_id, {}).duplicate(true)


func get_landmark_progress(landmark_id: String) -> Dictionary:
	return transition.next_snapshot.landmark_progress.get(landmark_id, {}).duplicate(true)


func get_landmark_state(landmark_id: String) -> String:
	return String(
		transition.next_snapshot.landmark_progress.get(landmark_id, {}).get("state", "locked")
	)


func get_melody_state(melody_id: String) -> Dictionary:
	return transition.next_snapshot.melody_progress.get(melody_id, {}).duplicate(true)


func get_resident_ids() -> PackedStringArray:
	return PackedStringArray(RESIDENT_CATALOG.resident_order())


func get_resident_profile(resident_id: String) -> Dictionary:
	ensure_resident_profiles()
	return transition.next_snapshot.resident_profiles.get(resident_id, {}).duplicate(true)


func get_resident_display_name(resident_id: String) -> String:
	var definition = m_resident_definitions.get(resident_id)
	if definition != null and !definition.display_name.is_empty():
		return definition.display_name
	return String(get_resident_profile(resident_id).get("display_name", "Resident"))


func get_manual_pinned_lead_id() -> String:
	return transition.next_snapshot.manual_pinned_lead_id


func set_manual_pinned_lead_id(lead_id: String) -> void:
	transition.next_snapshot.manual_pinned_lead_id = lead_id.strip_edges()


func get_story_event_blockers(event_id: String) -> Dictionary:
	return m_story_route_graph.get_story_event_blockers(event_id)


func can_resolve_story_event(event_id: String) -> bool:
	return m_story_route_graph.can_resolve_story_event(event_id)


func is_world_hour_in_range(min_hour: Variant, max_hour: Variant) -> bool:
	return STORY_TIME_SERVICE.hour_is_in_range(get_world_hour(), min_hour, max_hour)


func build_input_hint(primary_action: String) -> String:
	return _build_input_hint_for_state(transition.next_snapshot, primary_action)


func set_objective(value: String) -> void:
	transition.next_snapshot.objective = value


func set_hint(value: String) -> void:
	transition.next_snapshot.hint = value


func set_chapter(_value: String) -> void:
	# Story chapter is a projection of season_phase; Free Walk is a mode label.
	pass


func set_save_status(value: String) -> void:
	transition.next_snapshot.save_status = value


func set_season_phase(value: String) -> void:
	var normalized := value.strip_edges()
	if normalized.is_empty():
		normalized = preload("res://game/story_season_phases.gd").DEFAULT_PHASE
	transition.next_snapshot.season_phase = normalized


func apply_story_time_effects(payload: Dictionary) -> bool:
	var current := {
		"story_day": get_story_day(),
		"world_hour": get_world_hour(),
	}
	var normalized := m_story_time_service.apply_time_effects(current, payload)
	var next_day := int(normalized.get("story_day", get_story_day()))
	var next_hour := float(normalized.get("world_hour", get_world_hour()))
	if next_day == get_story_day() and is_equal_approx(next_hour, get_world_hour()):
		return false
	transition.next_snapshot.story_day = next_day
	transition.next_snapshot.world_hour = next_hour
	return true


func advance_landmark_state(landmark_id: String, state_id: String) -> void:
	var current := get_landmark_progress(landmark_id)
	if current.is_empty():
		return
	current["state"] = state_id
	set_landmark_progress(landmark_id, current)


func set_landmark_progress(landmark_id: String, progress: Dictionary) -> void:
	if !transition.next_snapshot.landmark_progress.has(landmark_id):
		return
	transition.next_snapshot.landmark_progress[landmark_id] = progress.duplicate(true)


func set_melody_progress(progress: Dictionary) -> void:
	transition.next_snapshot.melody_progress = _normalize_melody_progress(progress)
	projection = _build_projection(false)


func set_journal_unlocked(value: bool) -> void:
	transition.next_snapshot.journal_unlocked = value


func set_story_flag(flag_id: String, value: Variant = true) -> void:
	var normalized := flag_id.strip_edges()
	if !normalized.is_empty():
		transition.next_snapshot.story_flags[normalized] = value


func set_endgame_state(value: Dictionary) -> void:
	transition.next_snapshot.endgame_state = m_story_route_graph.normalize_endgame_state(value)


func set_all_route_progress(progress: Dictionary) -> void:
	projection.route_progress = progress.duplicate(true)


func set_active_leads(active_lead: String, available_leads: Variant) -> void:
	projection.available_lead_ids = PackedStringArray(_normalize_string_array(available_leads))
	projection.active_lead_id = active_lead


func set_residents(_residents: PackedStringArray) -> void:
	# Known resident names are projection data derived from resident profiles.
	pass


func set_resident_routine_override(resident_id: String, override_data: Dictionary) -> void:
	var normalized := resident_id.strip_edges()
	if normalized.is_empty():
		return
	if override_data.is_empty():
		clear_resident_routine_override(normalized)
		return
	transition.next_snapshot.resident_routine_overrides[normalized] = override_data.duplicate(true)


func clear_resident_routine_override(resident_id: String) -> void:
	transition.next_snapshot.resident_routine_overrides.erase(resident_id.strip_edges())


func unlock_shortcut(shortcut_id: String) -> bool:
	var normalized := shortcut_id.strip_edges()
	if !SHORTCUT_DEFINITIONS.has(normalized):
		return false
	if transition.next_snapshot.open_shortcuts.find(normalized) >= 0:
		return false
	transition.next_snapshot.open_shortcuts.append(normalized)
	return true


func ensure_resident_profiles() -> void:
	if transition.next_snapshot.resident_profiles.is_empty():
		transition.next_snapshot.resident_profiles = _default_resident_profiles()


func has_resident_profile(resident_id: String) -> bool:
	ensure_resident_profiles()
	return transition.next_snapshot.resident_profiles.has(resident_id)


func store_resident_profile(resident_id: String, profile: Dictionary) -> void:
	if has_resident_profile(resident_id):
		transition.next_snapshot.resident_profiles[resident_id] = profile.duplicate(true)


func emit_resident_profile_changed(_resident_id: String) -> void:
	pass


func refresh_player_costumes() -> void:
	pass


func update_summary_counts() -> void:
	pass


func count_helped_residents() -> int:
	var count := 0
	for resident_id in RESIDENT_CATALOG.resident_order():
		if int(get_resident_profile(resident_id).get("trust", 0)) > 0:
			count += 1
	return count


func autosave_story_progress() -> void:
	if transition.next_snapshot.mode_id == AppStateSnapshot.MODE_STORY:
		transition.request_autosave()


func refresh_story_routes() -> void:
	m_story_route_graph.refresh_story_state()


func resolve_story_event(event_id: String) -> bool:
	var changed: bool = m_story_route_graph.resolve_story_event(event_id)
	if changed:
		m_story_event_service.sync_story_route_dependent_landmarks(event_id)
		autosave_story_progress()
	return changed


func pin_story_lead(lead_id: String) -> void:
	m_story_route_graph.pin_story_lead(lead_id)


func cycle_story_lead(direction: int) -> void:
	m_story_route_graph.cycle_story_lead(direction)


func clear_manual_story_lead() -> void:
	m_story_route_graph.clear_manual_pinned_lead()


func pick_story_candidate(candidates: Array, context: Dictionary = {}) -> Dictionary:
	return m_story_event_service.pick_story_candidate(candidates, context)


func matches_story_conditions(conditions: Variant, context: Dictionary = {}) -> bool:
	return m_story_event_service.matches_conditions(conditions, context)


func apply_story_effects(payload: Dictionary, context: Dictionary = {}) -> void:
	m_story_event_service.apply_effects(payload, context)


func interact_with_resident(resident_id: String) -> Dictionary:
	return m_resident_interaction_service.interact_with_resident(resident_id)


func describe_story_subject(subject_id: String, action: String, context: Dictionary = {}) -> Dictionary:
	return m_story_event_service.describe_subject(subject_id, action, context)


func describe_story_subject_metadata(subject_id: String, context: Dictionary = {}) -> Dictionary:
	return m_story_event_service.describe_subject_metadata(subject_id, context)


func activate_story_subject(subject_id: String, action: String, context: Dictionary = {}) -> Dictionary:
	return m_story_event_service.activate_subject(subject_id, action, context)


func notify_story_world_event(event_id: String, payload: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	return m_story_event_service.notify_world_event(event_id, payload, context)


func request_melody_prompt(
	melody_id: String,
	prompt_mode: String,
	completion_kind: String = "",
	request_overrides: Dictionary = {}
) -> void:
	var result := m_landmark_progression.build_melody_prompt_result(
		melody_id,
		prompt_mode,
		completion_kind,
		request_overrides,
		m_melody_catalog.get(melody_id, {}).duplicate(true),
		get_melody_state(melody_id),
		can_perform_melody(melody_id)
	)
	var status := String(result.get("status", ""))
	if !status.is_empty():
		set_save_status(status)
		return
	var request: Dictionary = result.get("request", {})
	if !request.is_empty():
		emit_melody_prompt(request)


func complete_prompt_request(request: Dictionary) -> void:
	var completion_kind := String(request.get("completion_kind", "")).strip_edges()
	if !completion_kind.is_empty():
		var result: Dictionary = m_story_event_service.notify_world_event(
			"prompt_completed:%s" % completion_kind,
			{},
			request
		)
		if bool(result.get("handled", false)):
			return
	var melody_id := String(request.get("melody_id", ""))
	if completion_kind == "festival_performance":
		set_save_status(
			m_landmark_progression.get_melody_performance_status(
				get_melody_state(melody_id),
				can_perform_melody(melody_id)
			)
		)
		return
	set_save_status(
		m_landmark_progression.get_prompt_completion_status(
			request,
			m_melody_catalog.get(melody_id, {})
		)
	)


func can_practice_melody(melody_id: String) -> bool:
	var melody_state := get_melody_state(melody_id)
	if String(melody_state.get("state", "unknown")) not in ["reconstructed", "performed", "resonant"]:
		return false
	return m_landmark_progression.build_melody_prompt_segments(
		m_melody_catalog.get(melody_id, {}),
		melody_state
	).size() >= 2


func can_perform_melody(melody_id: String) -> bool:
	return melody_id == "festival_melody" \
		and get_landmark_state("festival_stage") == "available" \
		and can_practice_melody(melody_id)


func apply_ending_choice(choice_id: String) -> void:
	var normalized := choice_id.strip_edges().to_lower()
	if normalized.is_empty():
		return
	set_story_flag("ending_choice", normalized)
	var next_endgame := get_endgame_state()
	next_endgame["ending_tone_tags"] = m_story_route_graph.build_ending_tone_tags(normalized)
	set_endgame_state(next_endgame)
	autosave_story_progress()


func continue_story_after_endgame() -> bool:
	var current := get_endgame_state()
	if !bool(current.get("active", false)) or String(current.get("ending_behavior", "")) != "continue_story":
		return false
	var trigger_event_id := String(current.get("trigger_event_id", ""))
	var resume_phase_id := String(
		current.get(
			"resume_phase_id",
			preload("res://game/story_season_phases.gd").DEFAULT_RESUME_PHASE
		)
	)
	if resume_phase_id.is_empty() or resume_phase_id == preload("res://game/story_season_phases.gd").ENDGAME:
		resume_phase_id = preload("res://game/story_season_phases.gd").DEFAULT_RESUME_PHASE
	set_endgame_state(STORY_ROUTE_GRAPH.default_endgame_state())
	set_season_phase(resume_phase_id)
	if trigger_event_id == "harbor_festival_performed":
		var melody_state := get_melody_state("festival_melody")
		if bool(melody_state.get("performed", false)):
			melody_state["state"] = "resonant"
			melody_state["next_lead"] = "Wander the island and listen to what the restored melody leaves behind."
			set_melody_progress({"festival_melody": melody_state})
		set_objective("Wander the island and listen to what the restored melody leaves behind.")
		set_save_status("The festival fades, but the island keeps the melody.")
	refresh_story_routes()
	autosave_story_progress()
	return true


func resolve_landmark(landmark_id: String) -> void:
	var result: Dictionary = m_story_event_service.notify_world_event(
		"landmark_reward:%s" % landmark_id.strip_edges(),
		{},
		{"landmark_id": landmark_id}
	)
	if !bool(result.get("handled", false)):
		set_save_status("This landmark reward is not wired yet.")


func request_landmark_audio_cue(
	cue_id: String,
	landmark_id: String,
	trigger_id: String,
	display_name: String
) -> void:
	if cue_id.is_empty():
		return
	transition.queue_event(EVENT_LANDMARK_AUDIO, {
		"cue_id": cue_id,
		"context": {
			"landmark_id": landmark_id,
			"trigger_id": trigger_id,
			"display_name": display_name,
		},
	})


func emit_melody_hint(text: String) -> void:
	transition.queue_event(EVENT_MELODY_HINT, {"text": text})


func emit_melody_prompt(request: Dictionary) -> void:
	transition.queue_event(EVENT_MELODY_PROMPT, {"request": request})


func emit_story_milestone(milestone_id: String, context: Dictionary = {}) -> void:
	transition.queue_event(EVENT_STORY_MILESTONE, {
		"milestone_id": milestone_id,
		"context": context,
	})


func activate_legacy_landmark_trigger(
	_landmark_id: String,
	_trigger_id: String,
	_display_name: String
) -> bool:
	return false


func get_prompt_volume_db(base_volume_db: float = 0.0) -> float:
	return m_audio_settings_service.get_prompt_volume_db(
		transition.next_snapshot.prompt_volume_percent,
		base_volume_db
	)


func get_dialogue_text_characters_per_second() -> float:
	return m_audio_settings_service.get_dialogue_text_characters_per_second(
		transition.next_snapshot.dialogue_text_speed_percent
	)


func _build_projection(refresh_routes: bool = true) -> AppStateProjection:
	var state := transition.next_snapshot
	var view := AppStateProjection.new()
	projection = view
	view.mode_id = state.mode_id
	view.mode = AppStateSnapshot.mode_display_name(state.mode_id)
	view.season_phase = state.season_phase
	view.season_display_name = STORY_ROUTE_GRAPH.phase_display_name(state.season_phase)
	view.chapter = "Free Walk" if state.mode_id == AppStateSnapshot.MODE_FREE_WALK else view.season_display_name
	view.story_day = state.story_day
	view.world_hour = state.world_hour
	view.time_of_day = STORY_TIME_SERVICE.time_of_day_for_hour(state.world_hour)
	view.time_of_day_display_name = STORY_TIME_SERVICE.display_name(view.time_of_day)
	view.story_time_label = "Day %d, %s" % [state.story_day, view.time_of_day_display_name]
	view.location = state.location
	view.objective = state.objective
	view.hint = state.hint
	view.save_status = state.save_status
	view.journal_unlocked = state.journal_unlocked
	view.open_shortcuts = PackedStringArray(state.open_shortcuts)
	view.melody_definitions = m_melody_catalog.duplicate(true)
	view.melody_progress = state.melody_progress.duplicate(true)
	for melody_state_value in state.melody_progress.values():
		if melody_state_value is Dictionary:
			view.fragments_found += int(melody_state_value.get("fragments_found", 0))
			view.fragments_total += int(melody_state_value.get("fragments_total", 0))
	view.landmark_names = LANDMARK_CATALOG.world_display_names()
	view.landmark_progress = state.landmark_progress.duplicate(true)
	view.route_definitions = m_story_route_graph.get_route_definitions_view()
	view.event_definitions = m_story_route_graph.get_event_definitions_view()
	view.route_ids = PackedStringArray(m_story_route_graph.get_route_display_order_view())
	view.story_flags = state.story_flags.duplicate(true)
	view.endgame_state = state.endgame_state.duplicate(true)
	view.resident_ids = PackedStringArray(RESIDENT_CATALOG.resident_order())
	view.resident_profiles = state.resident_profiles.duplicate(true)
	view.resident_definitions = m_resident_definitions.duplicate()
	view.resident_routine_overrides = state.resident_routine_overrides.duplicate(true)
	for resident_id in view.resident_ids:
		var resident: Dictionary = state.resident_profiles.get(resident_id, {})
		if bool(resident.get("known", false)):
			view.known_resident_names.append(
				String(resident.get("display_name", resident_id))
			)
	view.player_profile = state.player_profile.duplicate(true)
	view.player_costume_catalog = m_player_costume_catalog.duplicate(true)
	view.player_costume_ids = m_player_profile_service.get_player_costume_ids()
	view.unlocked_player_costume_ids = m_player_profile_service.build_unlocked_costume_ids(
		view.mode,
		view.fragments_found,
		view.fragments_total,
		state.resident_profiles
	)
	view.equipped_player_costume_id = m_player_profile_service.resolve_equipped_costume_id(
		view.unlocked_player_costume_ids,
		state.equipped_player_costume_id
	)
	state.equipped_player_costume_id = view.equipped_player_costume_id
	view.equipped_player_costume = m_player_profile_service.get_equipped_player_costume(
		view.equipped_player_costume_id
	)
	view.player_appearance_config = m_player_profile_service.get_player_appearance_config(
		state.player_profile,
		view.equipped_player_costume_id
	)
	view.player_body_display_name = m_player_profile_service.get_player_body_display_name(state.player_profile)
	view.player_gender_display_name = m_player_profile_service.get_player_gender_display_name(state.player_profile)
	view.player_skin_display_name = m_player_profile_service.get_player_skin_display_name(state.player_profile)
	view.player_hair_style_display_name = m_player_profile_service.get_player_hair_style_display_name(state.player_profile)
	view.player_hair_color_display_name = m_player_profile_service.get_player_hair_color_display_name(state.player_profile)
	view.master_volume_percent = state.master_volume_percent
	view.music_volume_percent = state.music_volume_percent
	view.prompt_volume_percent = state.prompt_volume_percent
	view.dialogue_text_speed_percent = state.dialogue_text_speed_percent
	view.dialogue_text_characters_per_second = get_dialogue_text_characters_per_second()
	view.story_resume_anchor_id = state.story_resume_anchor_id
	view.story_resume_location = state.story_resume_location
	view.save_metadata = state.save_metadata.duplicate(true)
	if refresh_routes:
		m_story_route_graph.refresh_story_state()
	if (
		!state.manual_pinned_lead_id.is_empty()
		and view.available_lead_ids.find(state.manual_pinned_lead_id) < 0
	):
		state.manual_pinned_lead_id = ""
		m_story_route_graph.refresh_story_state()
	view.manual_lead_pinned = !state.manual_pinned_lead_id.is_empty() \
		and view.available_lead_ids.find(state.manual_pinned_lead_id) >= 0
	view.active_lead_text = m_story_route_graph.get_active_lead_text()
	if view.active_lead_text.is_empty():
		view.active_lead_text = state.objective
	view.route_emphasis_text = m_story_route_graph.build_route_emphasis_text()
	view.ending_summary = _build_ending_summary(view)
	return view


func _build_ending_summary(view: AppStateProjection) -> Dictionary:
	var tone_tags := _normalize_string_array(view.endgame_state.get("ending_tone_tags", []))
	return {
		"fragments": "%d / %d" % [view.fragments_found, view.fragments_total],
		"residents": str(count_helped_residents()),
		"collectibles": "Not tracked in this build",
		"playtime": "a brief evening on Kulangsu",
		"season": view.season_display_name,
		"time": view.story_time_label,
		"routes": m_story_route_graph.build_route_completion_summary(),
		"route_emphasis": view.route_emphasis_text,
		"ending_trigger": String(view.endgame_state.get("trigger_event_id", "")),
		"ending_tones": ", ".join(PackedStringArray(tone_tags)),
		"ending_choice": String(get_story_flag("ending_choice", "")),
		"care_texture": _build_household_care_texture(view.story_flags),
	}


func _build_household_care_texture(story_flags: Dictionary) -> String:
	if bool(story_flags.get("family_household_care_seen", false)):
		return "Care reached A Po's household in time, and its warmth stays with the ending."
	if bool(story_flags.get("family_household_care_missed", false)):
		return "The untended household leaves a quiet thread of regret in the ending."
	return ""


func _default_melody_progress() -> Dictionary:
	var progress: Dictionary = {}
	for melody_id in MELODY_CATALOG.ordered_ids():
		var definition: Dictionary = m_melody_catalog.get(melody_id, {})
		progress[melody_id] = {
			"state": "unknown",
			"fragments_found": 0,
			"fragments_total": int(definition.get("fragment_total", 0)),
			"known_sources": [],
			"next_lead": String(definition.get("unlock_condition", "")),
			"performed": false,
		}
	return progress


func _build_story_melody_progress(state_id: String) -> Dictionary:
	var progress := _default_melody_progress()
	var festival: Dictionary = progress.get("festival_melody", {})
	festival["state"] = "heard"
	festival["fragments_found"] = 0
	festival["known_sources"] = ["ferry_plaza"]
	festival["performed"] = false
	if state_id == "free_walk":
		festival["next_lead"] = "Wander freely and use residents to sample how each district hears the island's missing tune."
	else:
		festival["next_lead"] = "Listen to the harbor refrain around the ferry plaza before following the bells uphill."
	progress["festival_melody"] = festival
	return progress


func _normalize_melody_progress(value: Dictionary) -> Dictionary:
	var normalized := _default_melody_progress()
	for melody_id in MELODY_CATALOG.ordered_ids():
		var current: Dictionary = normalized.get(melody_id, {}).duplicate(true)
		var incoming: Dictionary = value.get(melody_id, {})
		current["state"] = String(incoming.get("state", current.get("state", "unknown")))
		current["fragments_total"] = maxi(
			int(incoming.get("fragments_total", current.get("fragments_total", 0))),
			0
		)
		current["fragments_found"] = clampi(
			int(incoming.get("fragments_found", current.get("fragments_found", 0))),
			0,
			int(current.get("fragments_total", 0))
		)
		current["known_sources"] = _normalize_string_array(
			incoming.get("known_sources", current.get("known_sources", []))
		)
		current["next_lead"] = String(incoming.get("next_lead", current.get("next_lead", "")))
		current["performed"] = bool(incoming.get("performed", current.get("performed", false)))
		normalized[melody_id] = current
	return normalized


func _normalize_landmark_progress(value: Dictionary) -> Dictionary:
	var normalized := LANDMARK_CATALOG.build_progress(&"default")
	for landmark_id in value.keys():
		if normalized.has(landmark_id) and value[landmark_id] is Dictionary:
			var current: Dictionary = normalized[landmark_id].duplicate(true)
			current.merge(value[landmark_id], true)
			normalized[landmark_id] = current
	return normalized


func _default_resident_profiles() -> Dictionary:
	var profiles: Dictionary = {}
	for resident_id in RESIDENT_CATALOG.resident_order():
		var definition = m_resident_definitions.get(resident_id)
		if definition != null:
			profiles[resident_id] = definition.to_runtime_profile()
	return profiles


func _normalize_resident_profiles(value: Dictionary) -> Dictionary:
	var normalized := _default_resident_profiles()
	for resident_id in value.keys():
		if normalized.has(resident_id) and value[resident_id] is Dictionary:
			var current: Dictionary = normalized[resident_id].duplicate(true)
			current.merge(value[resident_id], true)
			normalized[resident_id] = current
	return normalized


func _normalize_shortcuts(value: Variant) -> PackedStringArray:
	var output := PackedStringArray()
	for shortcut_id in _normalize_string_array(value):
		if SHORTCUT_DEFINITIONS.has(shortcut_id) and output.find(shortcut_id) < 0:
			output.append(shortcut_id)
	return output


func _normalize_dictionary_values(value: Variant) -> Dictionary:
	var output: Dictionary = {}
	if value is Dictionary:
		for key in value.keys():
			if value[key] is Dictionary and !String(key).strip_edges().is_empty():
				output[String(key)] = value[key].duplicate(true)
	return output


func _normalize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array or value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
	return output


func _build_input_hint_for_state(state: AppStateSnapshot, primary_action: String) -> String:
	var parts := PackedStringArray()
	if !primary_action.is_empty():
		parts.append(primary_action)
	if state.journal_unlocked:
		parts.append("J Journal")
	parts.append("Esc Pause")
	return "   ".join(parts)
