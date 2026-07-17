class_name AppStateService
extends Node

const APP_STATE_GROUP := &"app_state_service"
const REDUCER_CONTEXT := preload("res://game/app_state/app_state_reducer_context.gd")
const AUDIO_SETTINGS_SERVICE := preload("res://game/audio_settings_service.gd")
const PLAYER_APPEARANCE_CATALOG := preload("res://game/player_appearance_catalog.gd")

signal state_committed(changes: AppStateChangeSet)
signal melody_prompt_requested(request: Dictionary)
signal melody_hint_shown(text: String)
signal landmark_audio_cue_requested(cue_id: String, context: Dictionary)
signal story_milestone(milestone_id: String, context: Dictionary)

var m_snapshot: AppStateSnapshot
var m_projection: AppStateProjection
var m_save_codec := StorySaveCodec.new()
var m_save_repository: StorySaveRepository
var m_audio_settings_service := AUDIO_SETTINGS_SERVICE.new()
var m_last_autosave_succeeded := false


func _init(repository: StorySaveRepository = null) -> void:
	m_save_repository = repository if repository != null else StorySaveRepository.new()
	var initial := AppStateSnapshot.new()
	var transition := AppStateTransition.new(initial)
	var context := REDUCER_CONTEXT.new(transition)
	context.reset_for_mode(AppStateSnapshot.MODE_TITLE)
	m_snapshot = transition.next_snapshot.duplicate_state()
	m_projection = context.rebuild_projection()
	context.dispose()
	_refresh_save_metadata_from_repository()


func _enter_tree() -> void:
	add_to_group(APP_STATE_GROUP)


func _ready() -> void:
	m_audio_settings_service.apply_runtime_settings(
		m_snapshot.master_volume_percent,
		m_snapshot.music_volume_percent
	)


func get_snapshot() -> AppStateSnapshot:
	return m_snapshot.duplicate_state()


func get_projection() -> AppStateProjection:
	return m_projection.duplicate_projection()


func has_story_save() -> bool:
	return bool(m_snapshot.save_metadata.get("exists", false))


func get_save_metadata() -> Dictionary:
	return m_snapshot.save_metadata.duplicate(true)


func start_new_story() -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.reset_for_mode(AppStateSnapshot.MODE_STORY)
	)


func resume_story() -> bool:
	var payload := m_save_repository.load_payload()
	var decoded := m_save_codec.decode(payload, _build_clean_story_snapshot())
	if decoded.is_empty():
		return false
	var loaded: AppStateSnapshot = decoded.get("snapshot")
	loaded.master_volume_percent = m_snapshot.master_volume_percent
	loaded.music_volume_percent = m_snapshot.music_volume_percent
	loaded.prompt_volume_percent = m_snapshot.prompt_volume_percent
	loaded.dialogue_text_speed_percent = m_snapshot.dialogue_text_speed_percent
	loaded.save_metadata = m_save_codec.build_metadata(payload, loaded)
	var transition := AppStateTransition.new(loaded)
	var context := REDUCER_CONTEXT.new(transition)
	context.normalize_snapshot()
	var loaded_projection := context.rebuild_projection()
	loaded.save_metadata["chapter"] = loaded_projection.chapter
	transition.next_snapshot.save_metadata = loaded.save_metadata.duplicate(true)
	_finalize_transition(transition, context)
	context.dispose()
	return true


func start_free_walk() -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.reset_for_mode(AppStateSnapshot.MODE_FREE_WALK)
	)


func enter_title_mode() -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.reset_for_mode(AppStateSnapshot.MODE_TITLE)
	)


func describe_story_subject(
	subject_id: String,
	action: String,
	world_context: Dictionary = {}
) -> Dictionary:
	var context := _detached_context()
	var result := context.describe_story_subject(subject_id, action, world_context)
	context.dispose()
	return result


func describe_story_subject_metadata(
	subject_id: String,
	world_context: Dictionary = {}
) -> Dictionary:
	var context := _detached_context()
	var result := context.describe_story_subject_metadata(subject_id, world_context)
	context.dispose()
	return result


func activate_story_subject(
	subject_id: String,
	action: String,
	world_context: Dictionary = {}
) -> Dictionary:
	var result: Variant = _commit_command(func(context: AppStateReducerContext) -> Dictionary:
		return context.activate_story_subject(subject_id, action, world_context)
	)
	return result if result is Dictionary else {}


func notify_story_world_event(
	event_id: String,
	payload: Dictionary = {},
	world_context: Dictionary = {}
) -> Dictionary:
	var result: Variant = _commit_command(func(context: AppStateReducerContext) -> Dictionary:
		return context.notify_story_world_event(event_id, payload, world_context)
	)
	return result if result is Dictionary else {}


func complete_prompt_request(request: Dictionary) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.complete_prompt_request(request)
	)


func update_world_context(values: Dictionary) -> void:
	if !_world_context_has_changes(values):
		return
	_commit_command(func(context: AppStateReducerContext) -> void:
		var state := context.transition.next_snapshot
		if values.has("location"):
			state.location = String(values.get("location", state.location))
		if values.has("objective"):
			state.objective = String(values.get("objective", state.objective))
		if values.has("status"):
			state.save_status = String(values.get("status", state.save_status))
		if values.has("hint"):
			state.hint = String(values.get("hint", state.hint))
		elif values.has("hint_action"):
			state.hint = context.build_input_hint(String(values.get("hint_action", "")))
		if values.has("story_time") and values.get("story_time") is Dictionary:
			context.apply_story_time_effects(values.get("story_time"))
	)


func update_resume_checkpoint(anchor_id: String, location_label: String = "") -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		var state := context.transition.next_snapshot
		var normalized_anchor := anchor_id.strip_edges()
		if normalized_anchor.is_empty():
			return
		state.story_resume_anchor_id = normalized_anchor
		state.story_resume_location = location_label.strip_edges()
		if state.story_resume_location.is_empty():
			state.story_resume_location = normalized_anchor
		context.autosave_story_progress()
	)


func replace_player_profile(profile: Dictionary) -> bool:
	var previous := m_snapshot.player_profile
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.transition.next_snapshot.player_profile = profile.duplicate(true)
		context.autosave_story_progress()
	)
	return previous != m_snapshot.player_profile


func equip_player_costume(costume_id: String) -> bool:
	if m_projection.unlocked_player_costume_ids.find(costume_id) < 0:
		return false
	var previous := m_snapshot.equipped_player_costume_id
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.transition.next_snapshot.equipped_player_costume_id = costume_id
		context.autosave_story_progress()
	)
	return previous != m_snapshot.equipped_player_costume_id


func pin_story_lead(lead_id: String) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.pin_story_lead(lead_id)
		context.autosave_story_progress()
	)


func cycle_story_lead(direction: int) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.cycle_story_lead(direction)
		context.autosave_story_progress()
	)


func clear_story_lead_pin() -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.clear_manual_story_lead()
		context.autosave_story_progress()
	)


func commit_settings(settings: Dictionary) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		var state := context.transition.next_snapshot
		state.master_volume_percent = float(
			settings.get("master_volume_percent", state.master_volume_percent)
		)
		state.music_volume_percent = float(
			settings.get("music_volume_percent", state.music_volume_percent)
		)
		state.prompt_volume_percent = float(
			settings.get("prompt_volume_percent", state.prompt_volume_percent)
		)
		state.dialogue_text_speed_percent = float(
			settings.get(
				"dialogue_text_speed_percent",
				state.dialogue_text_speed_percent
			)
		)
	)


func request_autosave() -> bool:
	if m_snapshot.mode_id != AppStateSnapshot.MODE_STORY:
		return false
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.transition.request_autosave()
	)
	return m_last_autosave_succeeded


func clear_story_save() -> void:
	m_save_repository.clear()
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.transition.next_snapshot.save_metadata = _default_save_metadata()
	)


func interact_with_resident(resident_id: String) -> Dictionary:
	var result: Variant = _commit_command(func(context: AppStateReducerContext) -> Dictionary:
		return context.interact_with_resident(resident_id)
	)
	return result if result is Dictionary else {}


func request_melody_practice(melody_id: String) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.request_melody_prompt(melody_id, "practice")
	)


func apply_ending_choice(choice_id: String) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.apply_ending_choice(choice_id)
	)


func continue_story_after_endgame() -> bool:
	var result: Variant = _commit_command(func(context: AppStateReducerContext) -> bool:
		return context.continue_story_after_endgame()
	)
	return bool(result)


func apply_story_effects(payload: Dictionary, world_context: Dictionary = {}) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.apply_story_effects(payload, world_context)
	)


func matches_story_conditions(
	conditions: Variant,
	world_context: Dictionary = {}
) -> bool:
	var context := _detached_context()
	var result := context.matches_story_conditions(conditions, world_context)
	context.dispose()
	return result


func can_practice_melody(melody_id: String) -> bool:
	var context := _detached_context()
	var result := context.can_practice_melody(melody_id)
	context.dispose()
	return result


func can_perform_melody(melody_id: String) -> bool:
	var context := _detached_context()
	var result := context.can_perform_melody(melody_id)
	context.dispose()
	return result


func resolve_story_event(event_id: String) -> bool:
	var result: Variant = _commit_command(func(context: AppStateReducerContext) -> bool:
		return context.resolve_story_event(event_id)
	)
	return bool(result)


func set_resident_routine_override(resident_id: String, override_data: Dictionary) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.set_resident_routine_override(resident_id, override_data)
		context.autosave_story_progress()
	)


func clear_resident_routine_override(resident_id: String) -> void:
	_commit_command(func(context: AppStateReducerContext) -> void:
		context.clear_resident_routine_override(resident_id)
		context.autosave_story_progress()
	)


func _commit_command(command: Callable) -> Variant:
	var transition := AppStateTransition.new(m_snapshot)
	var context := REDUCER_CONTEXT.new(transition, m_projection)
	transition.result = command.call(context)
	_finalize_transition(transition, context)
	context.dispose()
	return transition.result


func _finalize_transition(
	transition: AppStateTransition,
	context: AppStateReducerContext
) -> void:
	m_last_autosave_succeeded = false
	context.normalize_snapshot()
	var next_projection := context.rebuild_projection()
	var next_snapshot := transition.next_snapshot
	var changes := _build_change_set(m_snapshot, next_snapshot)
	transition.changes = changes
	m_snapshot = next_snapshot.duplicate_state()
	m_projection = next_projection
	if transition.autosave_requested and m_snapshot.mode_id == AppStateSnapshot.MODE_STORY:
		m_last_autosave_succeeded = _save_committed_snapshot()
		if m_last_autosave_succeeded:
			changes.mark(AppStateChangeSet.Domain.SAVE)
	if changes.has_domain(AppStateChangeSet.Domain.SETTINGS):
		m_audio_settings_service.apply_runtime_settings(
			m_snapshot.master_volume_percent,
			m_snapshot.music_volume_percent
		)
	if !changes.is_empty():
		state_committed.emit(changes)
	_emit_queued_events(transition.events)


func _save_committed_snapshot() -> bool:
	var payload := m_save_codec.encode(m_snapshot)
	if !m_save_repository.save_payload(payload):
		push_warning("AppState autosave failed; gameplay state remains committed.")
		return false
	var metadata := m_save_codec.build_metadata(payload, m_snapshot)
	metadata["chapter"] = m_projection.chapter
	m_snapshot.save_metadata = metadata
	m_projection.save_metadata = metadata.duplicate(true)
	return true


func _emit_queued_events(events: Array[Dictionary]) -> void:
	for event in events:
		var kind := StringName(event.get("kind", &""))
		var payload: Dictionary = event.get("payload", {})
		match kind:
			AppStateReducerContext.EVENT_MELODY_HINT:
				melody_hint_shown.emit(String(payload.get("text", "")))
			AppStateReducerContext.EVENT_MELODY_PROMPT:
				melody_prompt_requested.emit(
					(payload.get("request", {}) as Dictionary).duplicate(true)
				)
			AppStateReducerContext.EVENT_LANDMARK_AUDIO:
				landmark_audio_cue_requested.emit(
					String(payload.get("cue_id", "")),
					(payload.get("context", {}) as Dictionary).duplicate(true)
				)
			AppStateReducerContext.EVENT_STORY_MILESTONE:
				story_milestone.emit(
					String(payload.get("milestone_id", "")),
					(payload.get("context", {}) as Dictionary).duplicate(true)
				)


func _detached_context() -> AppStateReducerContext:
	return REDUCER_CONTEXT.new(AppStateTransition.new(m_snapshot), m_projection)


func _world_context_has_changes(values: Dictionary) -> bool:
	if values.has("location") and String(values.get("location")) != m_snapshot.location:
		return true
	if values.has("objective") and String(values.get("objective")) != m_snapshot.objective:
		return true
	if values.has("status") and String(values.get("status")) != m_snapshot.save_status:
		return true
	if values.has("hint"):
		if String(values.get("hint")) != m_snapshot.hint:
			return true
	elif values.has("hint_action"):
		if _format_input_hint(String(values.get("hint_action", ""))) != m_snapshot.hint:
			return true
	if values.has("story_time") and values.get("story_time") is Dictionary:
		return !(values.get("story_time") as Dictionary).is_empty()
	return false


func _format_input_hint(primary_action: String) -> String:
	var parts := PackedStringArray()
	if !primary_action.is_empty():
		parts.append(primary_action)
	if m_snapshot.journal_unlocked:
		parts.append("J Journal")
	parts.append("Esc Pause")
	return "   ".join(parts)


func _build_clean_story_snapshot() -> AppStateSnapshot:
	var transition := AppStateTransition.new(m_snapshot)
	var context := REDUCER_CONTEXT.new(transition)
	context.reset_for_mode(AppStateSnapshot.MODE_STORY)
	transition.autosave_requested = false
	transition.next_snapshot.save_metadata = _default_save_metadata()
	var snapshot := transition.next_snapshot.duplicate_state()
	context.dispose()
	return snapshot


func _refresh_save_metadata_from_repository() -> void:
	var payload := m_save_repository.load_payload()
	var decoded := m_save_codec.decode(payload, _build_clean_story_snapshot())
	if decoded.is_empty():
		m_snapshot.save_metadata = _default_save_metadata()
		m_projection.save_metadata = _default_save_metadata()
		return
	var saved_snapshot: AppStateSnapshot = decoded.get("snapshot")
	var saved_context := REDUCER_CONTEXT.new(AppStateTransition.new(saved_snapshot))
	var saved_projection := saved_context.rebuild_projection()
	var metadata := m_save_codec.build_metadata(payload, saved_snapshot)
	metadata["chapter"] = saved_projection.chapter
	m_snapshot.save_metadata = metadata
	m_projection.save_metadata = metadata.duplicate(true)
	saved_context.dispose()


func _build_change_set(
	old_state: AppStateSnapshot,
	new_state: AppStateSnapshot
) -> AppStateChangeSet:
	var changes := AppStateChangeSet.new()
	if old_state.mode_id != new_state.mode_id or old_state.location != new_state.location:
		changes.mark(AppStateChangeSet.Domain.SESSION)
	if (
		old_state.season_phase != new_state.season_phase
		or old_state.objective != new_state.objective
		or old_state.hint != new_state.hint
		or old_state.save_status != new_state.save_status
		or old_state.journal_unlocked != new_state.journal_unlocked
		or old_state.open_shortcuts != new_state.open_shortcuts
		or old_state.story_flags != new_state.story_flags
		or old_state.endgame_state != new_state.endgame_state
		or old_state.manual_pinned_lead_id != new_state.manual_pinned_lead_id
	):
		changes.mark(AppStateChangeSet.Domain.STORY)
	if old_state.story_day != new_state.story_day or !is_equal_approx(
		old_state.world_hour,
		new_state.world_hour
	):
		changes.mark(AppStateChangeSet.Domain.TIME)
	_mark_dictionary_changes(
		changes,
		old_state.melody_progress,
		new_state.melody_progress,
		AppStateChangeSet.Domain.MELODY,
		changes.melody_ids
	)
	_mark_dictionary_changes(
		changes,
		old_state.landmark_progress,
		new_state.landmark_progress,
		AppStateChangeSet.Domain.LANDMARKS,
		changes.landmark_ids
	)
	if old_state.resident_routine_overrides != new_state.resident_routine_overrides:
		changes.mark(AppStateChangeSet.Domain.RESIDENTS)
	_mark_dictionary_changes(
		changes,
		old_state.resident_profiles,
		new_state.resident_profiles,
		AppStateChangeSet.Domain.RESIDENTS,
		changes.resident_ids
	)
	if (
		old_state.player_profile != new_state.player_profile
		or old_state.equipped_player_costume_id != new_state.equipped_player_costume_id
	):
		changes.mark(AppStateChangeSet.Domain.PLAYER)
	if (
		!is_equal_approx(old_state.master_volume_percent, new_state.master_volume_percent)
		or !is_equal_approx(old_state.music_volume_percent, new_state.music_volume_percent)
		or !is_equal_approx(old_state.prompt_volume_percent, new_state.prompt_volume_percent)
		or !is_equal_approx(
			old_state.dialogue_text_speed_percent,
			new_state.dialogue_text_speed_percent
		)
	):
		changes.mark(AppStateChangeSet.Domain.SETTINGS)
	if (
		old_state.story_resume_anchor_id != new_state.story_resume_anchor_id
		or old_state.story_resume_location != new_state.story_resume_location
	):
		changes.mark(AppStateChangeSet.Domain.CHECKPOINT)
	if old_state.save_metadata != new_state.save_metadata:
		changes.mark(AppStateChangeSet.Domain.SAVE)
	return changes


func _mark_dictionary_changes(
	changes: AppStateChangeSet,
	old_values: Dictionary,
	new_values: Dictionary,
	domain: int,
	changed_ids: PackedStringArray
) -> void:
	var ids := PackedStringArray(old_values.keys())
	for entry_id in new_values.keys():
		var normalized_id := String(entry_id)
		if ids.find(normalized_id) < 0:
			ids.append(normalized_id)
	for entry_id in ids:
		if old_values.get(entry_id) != new_values.get(entry_id):
			changes.mark(domain)
			changed_ids.append(entry_id)


func _default_save_metadata() -> Dictionary:
	return {
		"exists": false,
		"mode": "Story",
		"chapter": "Arrival",
		"location": "",
		"fragments_text": "0 / 4",
		"resume_anchor_id": "",
		"resume_location": "",
		"saved_at_unix": 0,
	}
