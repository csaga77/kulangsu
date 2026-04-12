class_name BgmManager
extends Node

const APP_RUNTIME := preload("res://game/app_runtime.gd")
const BGM_CATALOG_SCRIPT := preload("res://game/bgm_catalog.gd")
const PRIMARY_MELODY_ID := "festival_melody"
const BGM_BUS_NAME := &"BGM"
const MASTER_BUS_NAME := &"Master"
const MIN_COMMITMENT_SECONDS := 45.0
const RECENT_HISTORY_LIMIT := 3
const SILENT_VOLUME_DB := -60.0
const PLAY_VOLUME_DB := -6.0
const DUCKED_PLAY_VOLUME_DB := PLAY_VOLUME_DB - 6.0
const DUCK_TWEEN_SECONDS := 0.18
const NATURAL_GAP_MIN_SECONDS := 5.0
const NATURAL_GAP_MAX_SECONDS := 12.0
const LOCATION_GAP_MIN_SECONDS := 1.5
const LOCATION_GAP_MAX_SECONDS := 3.0
const NATURAL_FADE_MIN_SECONDS := 3.0
const NATURAL_FADE_MAX_SECONDS := 5.0
const MIN_SCHEDULED_FADE_DELAY_SECONDS := 0.05

signal track_selected(track_id: String, file_path: String, context: Dictionary)
signal track_started(track_id: String)

var app_state: AppStateService = null
var melody_id := PRIMARY_MELODY_ID

var m_catalog: Dictionary = {}
var m_context := {
	"location": "overworld",
	"time": "afternoon",
	"progress": "unknown",
	"season": "summer",
	"weather": "clear",
}
var m_current_track_id := ""
var m_recent_history: Array[String] = []
var m_stream_cache: Dictionary = {}
var m_rng := RandomNumberGenerator.new()
var m_pending_location := ""
var m_pending_gap_reason := ""
var m_commitment_expires_at := 0.0
var m_is_transitioning := false
var m_player: AudioStreamPlayer = null
var m_gap_timer: Timer = null
var m_track_end_fade_timer: Timer = null
var m_cue_duck_timer: Timer = null
var m_fade_tween: Tween = null
var m_scheduled_fade_track_id := ""
var m_scheduled_fade_duration := 0.0
var m_is_manually_ducked := false
var m_is_cue_ducked := false
var m_is_natural_end_fading := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	m_rng.randomize()
	m_catalog = BGM_CATALOG_SCRIPT.build_catalog()
	_create_runtime_nodes()
	_connect_app_state()
	_validate_catalog()
	_sync_context_from_app_state()
	call_deferred("_start_if_idle")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if m_pending_location.is_empty():
		return
	if m_is_transitioning:
		return
	if !is_instance_valid(m_player) or !m_player.playing:
		return
	if _now_seconds() < m_commitment_expires_at:
		return

	_start_location_reselection()


func get_current_track_id() -> String:
	return m_current_track_id


func get_is_in_commitment_window() -> bool:
	if !is_instance_valid(m_player) or !m_player.playing:
		return false
	return _now_seconds() < m_commitment_expires_at


func request_reselection(reason: String = "manual") -> void:
	if m_is_transitioning:
		return
	if !is_instance_valid(m_player) or !m_player.playing:
		_select_and_play_next_track(reason)
		return
	_fade_out_current_track(reason)


func set_ducked(ducked: bool) -> void:
	if m_is_manually_ducked == ducked:
		return
	m_is_manually_ducked = ducked
	_sync_duck_volume()


func duck_for_cue(duration: float) -> void:
	if duration <= 0.0:
		return
	m_is_cue_ducked = true
	if is_instance_valid(m_cue_duck_timer):
		m_cue_duck_timer.start(duration)
	_sync_duck_volume()


func _create_runtime_nodes() -> void:
	m_player = AudioStreamPlayer.new()
	m_player.name = "BGMPlayer"
	m_player.bus = _resolve_bus_name()
	m_player.volume_db = SILENT_VOLUME_DB
	add_child(m_player)
	if !m_player.finished.is_connected(_on_track_finished):
		m_player.finished.connect(_on_track_finished)

	m_gap_timer = Timer.new()
	m_gap_timer.name = "BGMGapTimer"
	m_gap_timer.one_shot = true
	add_child(m_gap_timer)
	if !m_gap_timer.timeout.is_connected(_on_gap_timer_timeout):
		m_gap_timer.timeout.connect(_on_gap_timer_timeout)

	m_track_end_fade_timer = Timer.new()
	m_track_end_fade_timer.name = "BGMTrackEndFadeTimer"
	m_track_end_fade_timer.one_shot = true
	add_child(m_track_end_fade_timer)
	if !m_track_end_fade_timer.timeout.is_connected(_on_track_end_fade_timer_timeout):
		m_track_end_fade_timer.timeout.connect(_on_track_end_fade_timer_timeout)

	m_cue_duck_timer = Timer.new()
	m_cue_duck_timer.name = "BGMCueDuckTimer"
	m_cue_duck_timer.one_shot = true
	add_child(m_cue_duck_timer)
	if !m_cue_duck_timer.timeout.is_connected(_on_cue_duck_timer_timeout):
		m_cue_duck_timer.timeout.connect(_on_cue_duck_timer_timeout)


func _connect_app_state() -> void:
	if app_state == null:
		app_state = APP_RUNTIME.get_app_state(self)
	if app_state == null:
		return

	if !app_state.location_changed.is_connected(_on_location_changed):
		app_state.location_changed.connect(_on_location_changed)
	if !app_state.melody_progress_changed.is_connected(_on_melody_progress_changed):
		app_state.melody_progress_changed.connect(_on_melody_progress_changed)


func _validate_catalog() -> void:
	for track_id_value in BGM_CATALOG_SCRIPT.ordered_ids():
		var track_id := String(track_id_value)
		var track: Dictionary = m_catalog.get(track_id, {})
		if track.is_empty():
			push_warning("BGM: missing catalog entry for %s." % track_id)
			continue

		var file_path := String(track.get("file", ""))
		if file_path.is_empty():
			push_warning("BGM: %s has no audio file." % track_id)
			continue
		if !ResourceLoader.exists(file_path):
			push_warning("BGM: %s is missing %s." % [track_id, file_path])


func _sync_context_from_app_state() -> void:
	if app_state == null:
		return

	m_context["location"] = _map_location_label(app_state.location)
	m_context["progress"] = _resolve_progress_state()


func _resolve_progress_state() -> String:
	if app_state == null:
		return "unknown"

	var tracked_melody_id := melody_id
	if !app_state.get_melody_ids().has(tracked_melody_id):
		var melody_ids := app_state.get_melody_ids()
		if melody_ids.is_empty():
			return "unknown"
		tracked_melody_id = String(melody_ids[0])

	var melody_state := app_state.get_melody_state(tracked_melody_id)
	var state_id := String(melody_state.get("state", "unknown"))
	if state_id in ["unknown", "heard", "reconstructed", "performed", "resonant"]:
		return state_id
	return "unknown"


func _start_if_idle() -> void:
	if m_is_transitioning:
		return
	if is_instance_valid(m_gap_timer) and !m_gap_timer.is_stopped():
		return
	if is_instance_valid(m_player) and m_player.playing:
		return
	if !m_current_track_id.is_empty():
		return

	_select_and_play_next_track("startup")


func _on_location_changed(location_label: String) -> void:
	var mapped_location := _map_location_label(location_label)
	if String(m_context.get("location", "overworld")) == mapped_location:
		return

	m_context["location"] = mapped_location
	m_pending_location = mapped_location

	if m_current_track_id.is_empty():
		_start_if_idle()
		return
	if m_is_transitioning:
		return
	if is_instance_valid(m_gap_timer) and !m_gap_timer.is_stopped():
		return
	if is_instance_valid(m_player) and m_player.playing and _now_seconds() >= m_commitment_expires_at:
		_start_location_reselection()


func _on_melody_progress_changed(changed_melody_id: String, _melody: Dictionary) -> void:
	if changed_melody_id != melody_id and changed_melody_id != PRIMARY_MELODY_ID:
		return

	m_context["progress"] = _resolve_progress_state()
	if m_current_track_id.is_empty():
		_start_if_idle()


func _start_location_reselection() -> void:
	if m_is_transitioning:
		return
	if !is_instance_valid(m_player) or !m_player.playing:
		return

	_fade_out_current_track("location_change")


func _fade_out_current_track(reason: String) -> void:
	if !is_instance_valid(m_player):
		return

	var fade_duration := _resolve_scheduled_fade_duration(reason)
	m_is_transitioning = true
	m_is_natural_end_fading = false
	_cancel_scheduled_track_end_fade()
	_kill_fade_tween()
	m_fade_tween = create_tween()
	m_fade_tween.tween_property(
		m_player,
		"volume_db",
		SILENT_VOLUME_DB,
		fade_duration
	)
	m_fade_tween.finished.connect(_on_fade_out_finished.bind(reason), CONNECT_ONE_SHOT)


func _on_fade_out_finished(reason: String) -> void:
	if is_instance_valid(m_player):
		m_player.stop()
	m_is_transitioning = false
	_start_gap(reason)


func _on_track_finished() -> void:
	_cancel_scheduled_track_end_fade()
	m_is_natural_end_fading = false
	if m_is_transitioning:
		return
	_start_gap("natural_end")


func _start_gap(reason: String) -> void:
	if !is_instance_valid(m_gap_timer):
		return

	var wait_time := _gap_duration_for_reason(reason)
	m_pending_gap_reason = reason

	if wait_time <= 0.05:
		call_deferred("_select_and_play_next_track", reason)
		return

	m_gap_timer.start(wait_time)


func _on_gap_timer_timeout() -> void:
	var reason := m_pending_gap_reason
	m_pending_gap_reason = ""
	_select_and_play_next_track(reason)


func _on_track_end_fade_timer_timeout() -> void:
	if m_is_transitioning:
		return
	if !is_instance_valid(m_player) or !m_player.playing:
		return
	if m_current_track_id.is_empty() or m_current_track_id != m_scheduled_fade_track_id:
		return

	_start_natural_end_fade()


func _start_natural_end_fade() -> void:
	if !is_instance_valid(m_player) or !m_player.playing:
		return
	if m_is_natural_end_fading:
		return

	var fade_duration := _resolve_scheduled_fade_duration("natural_end")
	m_is_natural_end_fading = true
	_cancel_scheduled_track_end_fade()
	_kill_fade_tween()
	m_fade_tween = create_tween()
	m_fade_tween.tween_property(
		m_player,
		"volume_db",
		SILENT_VOLUME_DB,
		fade_duration
	)


func _on_cue_duck_timer_timeout() -> void:
	m_is_cue_ducked = false
	_sync_duck_volume()


func _select_and_play_next_track(reason: String) -> void:
	var track_id := _pick_next_track_id()
	if track_id.is_empty():
		m_current_track_id = ""
		_cancel_scheduled_track_end_fade()
		push_warning("BGM: no track could be selected for context %s." % _context_debug_string())
		return

	var track: Dictionary = m_catalog.get(track_id, {})
	var file_path := String(track.get("file", ""))
	var stream := _get_stream_for_track(track)
	if stream == null:
		m_current_track_id = ""
		_cancel_scheduled_track_end_fade()
		push_warning("BGM: selected track %s has no usable stream at %s." % [track_id, file_path])
		return
		
	m_current_track_id = track_id
	m_pending_location = ""
	m_commitment_expires_at = _now_seconds() + MIN_COMMITMENT_SECONDS
	m_is_natural_end_fading = false
	_append_recent_history(track_id)

	m_player.bus = _resolve_bus_name()
	m_player.stream = stream
	m_player.volume_db = SILENT_VOLUME_DB
	m_player.play()
	_schedule_track_end_fade(track_id, track, stream)

	_kill_fade_tween()
	m_fade_tween = create_tween()
	m_fade_tween.tween_property(
		m_player,
		"volume_db",
		_target_play_volume_db(),
		_fade_in_duration_for_reason(reason)
	)

	var label := String(track.get("label", track_id))
	print(
		"BGM: selected %s (%s) for %s because %s"
		% [track_id, label, _context_debug_string(), reason]
	)
	track_selected.emit(track_id, file_path, m_context.duplicate(true))
	track_started.emit(track_id)


func _pick_next_track_id() -> String:
	var track_id := _pick_track_id(true, "")
	if !track_id.is_empty():
		return track_id

	push_warning("BGM: ignoring recent-history exclusion for %s." % _context_debug_string())
	track_id = _pick_track_id(false, "")
	if !track_id.is_empty():
		return track_id

	push_warning("BGM: falling back to commons for %s." % _context_debug_string())
	track_id = _pick_track_id(false, "commons")
	if !track_id.is_empty():
		return track_id

	track_id = _pick_location_fallback_track_id(true)
	if !track_id.is_empty():
		push_warning("BGM: using location-only fallback %s for %s." % [track_id, _context_debug_string()])
		return track_id
		
	track_id = _pick_location_fallback_track_id(false)
	if !track_id.is_empty():
		push_warning(
			"BGM: using relaxed location-only fallback %s for %s."
			% [track_id, _context_debug_string()]
		)
		return track_id

	return ""


func _pick_track_id(exclude_history: bool, tier_filter: String) -> String:
	var scores := {}
	var total_score := 0.0

	for track_id_value in BGM_CATALOG_SCRIPT.ordered_ids():
		var track_id := String(track_id_value)
		var track: Dictionary = m_catalog.get(track_id, {})
		if track.is_empty():
			continue
		if exclude_history and m_recent_history.has(track_id):
			continue
		if is_instance_valid(m_player) and m_player.playing and track_id == m_current_track_id:
			continue
		if !tier_filter.is_empty() and String(track.get("tier", "")) != tier_filter:
			continue
		if !_track_file_exists(track):
			continue

		var score := _score_track(track, m_context)
		if score <= 0.0:
			continue

		scores[track_id] = score
		total_score += score

	if total_score <= 0.0:
		return ""

	var roll := m_rng.randf() * total_score
	for track_id_value in BGM_CATALOG_SCRIPT.ordered_ids():
		var track_id := String(track_id_value)
		if !scores.has(track_id):
			continue
		roll -= float(scores.get(track_id, 0.0))
		if roll <= 0.0:
			return track_id

	for track_id_value in BGM_CATALOG_SCRIPT.ordered_ids():
		var track_id := String(track_id_value)
		if scores.has(track_id):
			return track_id

	return ""


func _pick_location_fallback_track_id(exclude_recent_history: bool = true) -> String:
	var location_key := String(m_context.get("location", "overworld"))
	var best_track_id := ""
	var best_location_weight := -1.0

	for track_id_value in BGM_CATALOG_SCRIPT.ordered_ids():
		var track_id := String(track_id_value)
		var track: Dictionary = m_catalog.get(track_id, {})
		if track.is_empty():
			continue
		if String(track.get("tier", "")) == "exclusive":
			continue
		if exclude_recent_history and m_recent_history.has(track_id):
			continue
		if is_instance_valid(m_player) and m_player.playing and track_id == m_current_track_id:
			continue
		if !_track_file_exists(track):
			continue

		var location_weights: Dictionary = track.get("location", {})
		var location_weight := float(location_weights.get(location_key, 0.0))
		if location_weight <= best_location_weight:
			continue

		best_location_weight = location_weight
		best_track_id = track_id

	return best_track_id


func _score_track(track: Dictionary, context: Dictionary) -> float:
	var location_weights: Dictionary = track.get("location", {})
	var time_weights: Dictionary = track.get("time", {})
	var progress_weights: Dictionary = track.get("progress", {})
	var season_weights: Dictionary = track.get("season", {})
	var weather_weights: Dictionary = track.get("weather", {})

	var score := float(location_weights.get(String(context.get("location", "overworld")), 0.0))
	score *= float(time_weights.get(String(context.get("time", "afternoon")), 0.0))
	score *= float(progress_weights.get(String(context.get("progress", "unknown")), 0.0))
	score *= float(season_weights.get(String(context.get("season", "summer")), 0.0))
	score *= float(weather_weights.get(String(context.get("weather", "clear")), 0.0))
	return score


func _get_stream_for_track(track: Dictionary) -> AudioStream:
	var file_path := String(track.get("file", ""))
	if file_path.is_empty():
		return null
	return _get_stream_for_path(file_path)


func _track_file_exists(track: Dictionary) -> bool:
	var file_path := String(track.get("file", ""))
	return !file_path.is_empty() and ResourceLoader.exists(file_path)


func _get_stream_for_path(file_path: String) -> AudioStream:
	if m_stream_cache.has(file_path):
		return m_stream_cache.get(file_path) as AudioStream
	if !ResourceLoader.exists(file_path):
		return null

	var stream := load(file_path) as AudioStream
	if stream == null:
		return null

	m_stream_cache[file_path] = stream
	return stream


func _schedule_track_end_fade(track_id: String, track: Dictionary, stream: AudioStream) -> void:
	_cancel_scheduled_track_end_fade()
	if !is_instance_valid(m_track_end_fade_timer):
		return

	var fade_out_duration := _fade_out_duration_for_reason("natural_end")
	var track_duration := _resolve_track_duration_seconds(track, stream)
	var schedule_delay := maxf(track_duration - fade_out_duration, MIN_SCHEDULED_FADE_DELAY_SECONDS)
	m_scheduled_fade_track_id = track_id
	m_scheduled_fade_duration = fade_out_duration
	m_track_end_fade_timer.start(schedule_delay)


func _resolve_track_duration_seconds(track: Dictionary, stream: AudioStream) -> float:
	if stream != null:
		var stream_length := stream.get_length()
		if stream_length > 0.05:
			return stream_length
	return maxf(float(track.get("duration", 0.0)), MIN_SCHEDULED_FADE_DELAY_SECONDS)


func _cancel_scheduled_track_end_fade() -> void:
	m_scheduled_fade_track_id = ""
	m_scheduled_fade_duration = 0.0
	if is_instance_valid(m_track_end_fade_timer):
		m_track_end_fade_timer.stop()


func _resolve_scheduled_fade_duration(reason: String) -> float:
	if reason == "natural_end" and m_scheduled_fade_duration > 0.0:
		return m_scheduled_fade_duration
	return _fade_out_duration_for_reason(reason)


func _append_recent_history(track_id: String) -> void:
	m_recent_history.append(track_id)
	while m_recent_history.size() > RECENT_HISTORY_LIMIT:
		m_recent_history.remove_at(0)


func _map_location_label(location_label: String) -> String:
	var normalized := location_label.strip_edges().to_lower()
	if normalized.is_empty():
		return "overworld"
	if normalized in ["piano ferry", "ferry plaza", "festival stage"]:
		return "ferry_plaza"
	if normalized.contains("trinity"):
		return "trinity_church"
	if normalized.contains("bi shan"):
		return "bi_shan_tunnel"
	if normalized.contains("long shan"):
		return "long_shan_tunnel"
	if normalized.contains("bagua"):
		return "bagua_tower"
	return "overworld"


func _resolve_bus_name() -> StringName:
	if AudioServer.get_bus_index(BGM_BUS_NAME) >= 0:
		return BGM_BUS_NAME
	return MASTER_BUS_NAME


func _fade_in_duration_for_reason(reason: String) -> float:
	match reason:
		"location_change":
			return 2.2
		"natural_end":
			return 2.8
		_:
			return 1.8


func _fade_out_duration_for_reason(reason: String) -> float:
	match reason:
		"natural_end":
			return m_rng.randf_range(NATURAL_FADE_MIN_SECONDS, NATURAL_FADE_MAX_SECONDS)
		"location_change":
			return m_rng.randf_range(4.0, 6.0)
		"weather_change":
			return m_rng.randf_range(6.0, 8.0)
		_:
			return 2.4


func _gap_duration_for_reason(reason: String) -> float:
	match reason:
		"natural_end":
			return m_rng.randf_range(NATURAL_GAP_MIN_SECONDS, NATURAL_GAP_MAX_SECONDS)
		"location_change":
			return m_rng.randf_range(LOCATION_GAP_MIN_SECONDS, LOCATION_GAP_MAX_SECONDS)
		_:
			return 0.01


func _target_play_volume_db() -> float:
	if m_is_manually_ducked or m_is_cue_ducked:
		return DUCKED_PLAY_VOLUME_DB
	return PLAY_VOLUME_DB


func _sync_duck_volume() -> void:
	if !is_instance_valid(m_player) or !m_player.playing:
		return
	if m_is_transitioning:
		return

	var target_volume := _target_play_volume_db()
	if is_equal_approx(m_player.volume_db, target_volume):
		return

	_kill_fade_tween()
	m_fade_tween = create_tween()
	m_fade_tween.tween_property(m_player, "volume_db", target_volume, DUCK_TWEEN_SECONDS)


func _kill_fade_tween() -> void:
	if m_fade_tween != null and is_instance_valid(m_fade_tween):
		m_fade_tween.kill()
	m_fade_tween = null


func _context_debug_string() -> String:
	return "location=%s progress=%s time=%s season=%s weather=%s" % [
		String(m_context.get("location", "overworld")),
		String(m_context.get("progress", "unknown")),
		String(m_context.get("time", "afternoon")),
		String(m_context.get("season", "summer")),
		String(m_context.get("weather", "clear")),
	]


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
