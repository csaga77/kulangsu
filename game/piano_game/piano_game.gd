# PianoGame.gd (STRICT TYPED, ONSETS ONLY + onset_energy bins + auto min interval + LIVE HUD + final print)
# Godot 4.x
#
# Implemented:
# 1) number of lanes = number of key chars (unique characters in key_chars)
# 2) spread notes to all lanes evenly by onset_energy (quantile bins => ~equal counts per key)
# 3) keep each note time (unchanged, only filtered/thinned/interval-dropped)
# 4) min energy filter (min_onset_energy)
# 5) thinning (stride + keep_prob) while keeping energy aligned
# 6) min hit interval (manual OR auto difficulty-based)
# 7) LIVE HUD on screen: score (0..100), combo, PERFECT/GREAT/GOOD/MISS, total
# 8) Final summary printed once with print()

@tool
extends Node2D
class_name PianoGame

signal onset_spawned(index: int, time_sec: float, ch: String)
signal judged(result: String, error_ms: float)

# =========================================================
# 🎵 Audio & Chart
# =========================================================
@export_group("🎵 Audio & Chart")

@export_file_path("*.mp3")
var mp3_path: String = "res://music/song.mp3":
	# MP3 audio file played during the game.
	set(v):
		if mp3_path == v:
			return
		mp3_path = v
		_reload_deferred()

@export_file_path("*.json")
var json_path: String = "res://music/song.beats.json":
	# Beat/onset JSON file generated from the MP3.
	set(v):
		if json_path == v:
			return
		json_path = v
		_reload_deferred()

@export var auto_json_from_mp3: bool = true:
	# If true and json_path is empty, auto-derive JSON path from mp3_path.
	set(v):
		if auto_json_from_mp3 == v:
			return
		auto_json_from_mp3 = v
		_reload_deferred()


# =========================================================
# ⏱ Timing Calibration
# =========================================================
@export_group("⏱ Timing Calibration")

@export_range(-200.0, 200.0, 1.0)
var offset_ms: float = 0.0
# Manual timing offset applied to song time (positive = notes later).

@export var compensate_mix_time: bool = true
# Compensate AudioServer mix delay.

@export var compensate_output_latency: bool = true
# Compensate output latency.


# =========================================================
# 🚀 Note Motion
# =========================================================
@export_group("🚀 Note Motion")

@export_range(0.2, 5.0, 0.1)
var travel_time_sec: float = 1.2
# Seconds for a note to travel from spawn_y to hit_y.

@export var spawn_y: float = -120.0
# Y position where notes spawn.

@export var hit_y: float = 300.0
# Y position of the hit line.

@export_range(0.0, 5.0, 0.1)
var lookahead_sec: float = 1.2
# How far ahead to spawn notes.


# =========================================================
# 🎹 Lanes & Layout
# =========================================================
@export_group("🎹 Lanes & Layout")

@export var key_chars: String = "AWSD":
	# Unique characters define lanes.
	set(v):
		key_chars = v
		_rebuild_key_pool()
		_reload_deferred()

@export var lane_margin_x: float = 80.0
# Horizontal padding from screen edges.

@export_range(20.0, 400.0, 5.0)
var lane_min_spacing_x: float = 140.0
# Minimum horizontal spacing between lanes.

@export var randomize_lane_mapping: bool = false:
	# Shuffle mapping of energy bins to key characters.
	set(v):
		randomize_lane_mapping = v
		_reload_deferred()


# =========================================================
# 🎯 Note Density / Filtering
# =========================================================
@export_group("🎯 Note Density")

@export_range(1, 16, 1)
var onset_stride: int = 1:
	# Keep every Nth onset.
	set(v):
		onset_stride = max(1, v)
		_reload_deferred()

@export_range(0.0, 1.0, 0.01)
var onset_keep_prob: float = 1.0:
	# Random keep probability for onsets.
	set(v):
		onset_keep_prob = clamp(v, 0.0, 1.0)
		_reload_deferred()

@export var deterministic_thinning: bool = true:
	# Use stable seed for thinning.
	set(v):
		deterministic_thinning = v
		_reload_deferred()

@export_range(0.0, 1.0, 0.01)
var min_onset_energy: float = 0.0:
	# Drop onsets below this energy threshold.
	set(v):
		min_onset_energy = clamp(v, 0.0, 1.0)
		_reload_deferred()


# =========================================================
# 🎚 Difficulty & Interval
# =========================================================
@export_group("🎚 Difficulty & Interval")

@export_enum("EASY", "NORMAL", "HARD", "EXPERT")
var difficulty: String = "NORMAL":
	# Difficulty preset used for auto interval.
	set(v):
		difficulty = v
		_reload_deferred()

@export var auto_min_hit_interval: bool = true:
	# If true, auto-calculate minimum interval between notes.
	set(v):
		auto_min_hit_interval = v
		_reload_deferred()

@export_range(0.0, 0.50, 0.005)
var min_hit_interval_sec: float = 0.0:
	# Manual minimum interval (when auto disabled).
	set(v):
		min_hit_interval_sec = max(0.0, v)
		_reload_deferred()

@export_range(0.5, 2.0, 0.05)
var interval_song_density_scale: float = 1.0
	# Global multiplier for auto interval.

@export_range(0.5, 2.0, 0.05)
var interval_lane_scale: float = 1.0
	# Lane-based multiplier for auto interval.


# =========================================================
# 🎯 Judgement Windows
# =========================================================
@export_group("🎯 Judgement")

@export_range(10.0, 200.0, 1.0)
var perfect_ms: float = 45.0
# PERFECT window (+/- ms).

@export_range(10.0, 250.0, 1.0)
var great_ms: float = 90.0
# GREAT window.

@export_range(10.0, 400.0, 1.0)
var good_ms: float = 140.0
# GOOD window.


# =========================================================
# 🎨 Visuals
# =========================================================
@export_group("🎨 Visuals")

@export var circle_radius: float = 22.0
# Note circle radius.

@export var draw_hit_line: bool = true
# Draw the hit line.

@export var hit_line_thickness: float = 4.0
@export var hit_line_margin_x: float = 40.0
@export var hit_line_label: String = "HIT"
@export var hit_line_label_offset_y: float = -18.0

@export var draw_lane_guides: bool = true
@export_range(0.0, 0.5, 0.01)
var lane_guide_alpha: float = 0.08


# =========================================================
# 🔤 Letters
# =========================================================
@export_group("🔤 Letters")

@export var show_letters: bool = true
@export var letter_scale: float = 1.0
@export var letter_font: Font
@export var letter_font_size: int = 32


# =========================================================
# 🖥 HUD (Live Results)
# =========================================================
@export_group("🖥 HUD")

@export var show_hud: bool = true
# Draw live score and hit counts.

@export var hud_pos: Vector2 = Vector2(20, 20)
# HUD top-left position.

@export_range(10, 80, 1)
var hud_font_size: int = 22
# HUD font size.


# =========================================================
# 🛠 Debug
# =========================================================
@export_group("🛠 Debug")

@export var print_debug: bool = false
# Print internal debug information.

# -------------------------
# Private (strict typed)
# -------------------------

var m_player: AudioStreamPlayer
var m_rng: RandomNumberGenerator = RandomNumberGenerator.new()

var m_draw_font: Font
var m_draw_font_size: int = 32

# From JSON (after thinning + filtering + interval-filter)
var m_onsets: Array[float] = []
var m_onset_energy: Array[float] = []
var m_onset_chars: Array[String] = []

# Optional BPM (for auto interval)
var m_bpm: float = 0.0

# For finalization
var m_last_onset_time: float = 0.0
var m_stream_length: float = 0.0

# Spawn/judge indices
var m_next_spawn: int = 0
var m_next_judge: int = 0

# Notes on screen
var m_notes: Array[Dictionary] = []

# Key pool and lane map
var m_pool: Array[String] = []
var m_lane_index: Dictionary = {} # String -> int

# Reload coalescing
var m_reload_queued: bool = false

# For sort_custom
var m_sort_energy_ref: Array[float] = []

# Live results
var m_count_perfect: int = 0
var m_count_great: int = 0
var m_count_good: int = 0
var m_count_miss: int = 0
var m_combo: int = 0
var m_max_combo: int = 0
var m_game_finished: bool = false
var m_final_printed: bool = false

const BIG_FLOAT: float = 1e20

const COLOR_BASE := Color(1, 1, 1, 0.85)
const JUDGE_COLORS := {
	"PERFECT": Color(0.2, 1.0, 0.2, 0.95),
	"GREAT":   Color(0.2, 0.6, 1.0, 0.95),
	"GOOD":    Color(1.0, 0.85, 0.2, 0.95),
	"MISS":    Color(1.0, 0.25, 0.25, 0.95),
}

func _ready() -> void:
	m_rng.randomize()
	if m_player == null:
		m_player = AudioStreamPlayer.new()
		add_child(m_player)

	_prepare_draw_font()
	_rebuild_key_pool()
	_reload_deferred()

func _prepare_draw_font() -> void:
	m_draw_font = letter_font if letter_font != null else ThemeDB.fallback_font
	m_draw_font_size = max(8, int(float(letter_font_size) * letter_scale))

func _reload_deferred() -> void:
	if m_reload_queued:
		return
	m_reload_queued = true
	call_deferred("_do_reload")

func _do_reload() -> void:
	m_reload_queued = false
	_prepare_draw_font()
	_load_song_and_chart()
	_reset_runtime()

	if not Engine.is_editor_hint():
		_play()

func _reset_runtime() -> void:
	m_next_spawn = 0
	m_next_judge = 0
	m_notes.clear()

	m_count_perfect = 0
	m_count_great = 0
	m_count_good = 0
	m_count_miss = 0
	m_combo = 0
	m_max_combo = 0
	m_game_finished = false
	m_final_printed = false

func _play() -> void:
	if m_player == null or m_player.stream == null:
		return
	if m_player.playing:
		return
	m_player.play()

func stop() -> void:
	if m_player != null:
		m_player.stop()

func restart() -> void:
	stop()
	_reset_runtime()
	_play()

func _song_time() -> float:
	var t: float = m_player.get_playback_position()
	if compensate_mix_time:
		t -= AudioServer.get_time_since_last_mix()
	if compensate_output_latency:
		t -= AudioServer.get_output_latency()
	return t + (offset_ms / 1000.0)

# -------------------------
# Load JSON (onsets + onset_energy)
# -------------------------

func _load_song_and_chart() -> void:
	var stream: AudioStream = _load_mp3_stream(mp3_path)
	if stream == null:
		push_error("PianoGame: failed to load mp3: %s" % mp3_path)
		return
	m_player.stream = stream

	m_stream_length = 0.0
	if stream.has_method("get_length"):
		m_stream_length = float(stream.call("get_length"))

	var use_json_path: String = json_path
	if auto_json_from_mp3 and use_json_path.is_empty():
		use_json_path = _auto_json_path(mp3_path)

	var data: Dictionary = _load_json(use_json_path)
	if data.is_empty():
		push_error("PianoGame: failed to load json: %s" % use_json_path)
		return

	m_bpm = float(data.get("bpm", 0.0))

	var raw_onsets: Array[float] = _dict_get_float_array(data, "onsets")
	if raw_onsets.is_empty():
		push_error("PianoGame: JSON has no 'onsets'.")
		m_onsets.clear()
		m_onset_energy.clear()
		m_onset_chars.clear()
		return

	var raw_energy: Array[float] = _dict_get_float_array(data, "onset_energy")
	if raw_energy.is_empty():
		raw_energy.resize(raw_onsets.size())
		for i in range(raw_energy.size()):
			raw_energy[i] = 1.0
	else:
		var nmin: int = min(raw_onsets.size(), raw_energy.size())
		if nmin != raw_onsets.size():
			raw_onsets.resize(nmin)
		if nmin != raw_energy.size():
			raw_energy.resize(nmin)

	# Thinning RNG
	var thin_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if deterministic_thinning:
		thin_rng.seed = _stable_seed_from_strings(mp3_path, use_json_path)
	else:
		thin_rng.randomize()

	# Thin (keep alignment)
	var thin_res: Dictionary = _thin_times_and_energy(raw_onsets, raw_energy, onset_stride, onset_keep_prob, thin_rng)
	m_onsets = thin_res.get("times", []) as Array[float]
	m_onset_energy = thin_res.get("energy", []) as Array[float]

	# Filter by min energy (keep alignment)
	var filt_res: Dictionary = _filter_by_min_energy(m_onsets, m_onset_energy, min_onset_energy)
	m_onsets = filt_res.get("times", []) as Array[float]
	m_onset_energy = filt_res.get("energy", []) as Array[float]

	# Apply min hit interval (manual or auto) — keep alignment, drop too-close hits
	var effective_interval: float = _get_effective_min_hit_interval_sec()
	var int_res: Dictionary = _apply_min_hit_interval(m_onsets, m_onset_energy, effective_interval)
	m_onsets = int_res.get("times", []) as Array[float]
	m_onset_energy = int_res.get("energy", []) as Array[float]

	if m_onsets.size() != m_onset_energy.size():
		push_error("PianoGame: onsets/energy length mismatch after filtering.")
		m_onsets.clear()
		m_onset_energy.clear()
		m_onset_chars.clear()
		return

	m_last_onset_time = m_onsets.back() if not m_onsets.is_empty() else 0.0

	# Decide pool order for energy bands
	var band_pool: Array[String] = m_pool.duplicate()
	if randomize_lane_mapping and band_pool.size() > 1:
		var map_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		if deterministic_thinning:
			map_rng.seed = _stable_seed_from_strings("lane_map", use_json_path)
		else:
			map_rng.randomize()
		_shuffle_array_in_place(band_pool, map_rng)

	# Assign lane chars by energy quantile bins
	m_onset_chars = _assign_chars_by_energy_bins(m_onset_energy, band_pool)

	if print_debug:
		print("Loaded JSON: ", use_json_path,
			" onsets=", m_onsets.size(),
			" lanes=", m_pool.size(),
			" bpm=", m_bpm,
			" min_interval=", effective_interval,
			" min_energy=", min_onset_energy)

# -------------------------
# Difficulty-based interval
# -------------------------

func _get_effective_min_hit_interval_sec() -> float:
	if not auto_min_hit_interval:
		return min_hit_interval_sec

	var bpm: float = m_bpm
	if bpm <= 1.0:
		bpm = 120.0

	# Base = 16th note
	var sixteenth: float = 60.0 / (bpm * 4.0)

	var mult: float = 1.0
	match difficulty:
		"EASY":
			mult = 2.0
		"NORMAL":
			mult = 1.5
		"HARD":
			mult = 1.15
		"EXPERT":
			mult = 0.90

	var lanes: int = max(1, m_pool.size())
	var lane_factor: float = 1.0 / sqrt(float(lanes)) # more lanes => smaller interval

	var interval: float = sixteenth * mult
	interval *= interval_song_density_scale
	interval *= lerp(1.0, lane_factor, 0.7) * interval_lane_scale

	return clamp(interval, 0.03, 0.25)

# -------------------------
# Thinning / filtering / interval / assignment
# -------------------------

func _stable_seed_from_strings(a: String, b: String) -> int:
	return int((a + "|" + b).hash()) & 0x7fffffff

func _thin_times_and_energy(times_in: Array[float], energy_in: Array[float], stride: int, keep_prob: float, rng: RandomNumberGenerator) -> Dictionary:
	var out_t: Array[float] = []
	var out_e: Array[float] = []
	if times_in.is_empty():
		return {"times": out_t, "energy": out_e}

	var nmin: int = min(times_in.size(), energy_in.size())
	if nmin <= 0:
		return {"times": out_t, "energy": out_e}

	var s: int = max(1, stride)
	var p: float = clamp(keep_prob, 0.0, 1.0)
	if p <= 0.0:
		return {"times": out_t, "energy": out_e}

	for i in range(nmin):
		if (i % s) != 0:
			continue
		if p < 1.0 and rng.randf() > p:
			continue
		out_t.append(times_in[i])
		out_e.append(clamp(energy_in[i], 0.0, 1.0))

	return {"times": out_t, "energy": out_e}

func _filter_by_min_energy(times_in: Array[float], energy_in: Array[float], min_e: float) -> Dictionary:
	var out_t: Array[float] = []
	var out_e: Array[float] = []
	var nmin: int = min(times_in.size(), energy_in.size())
	if nmin <= 0:
		return {"times": out_t, "energy": out_e}

	var th: float = clamp(min_e, 0.0, 1.0)
	for i in range(nmin):
		var e: float = clamp(energy_in[i], 0.0, 1.0)
		if e >= th:
			out_t.append(times_in[i])
			out_e.append(e)

	return {"times": out_t, "energy": out_e}

# Keep times at least min_interval apart.
# If two hits are too close, keep the one with higher energy (stable).
func _apply_min_hit_interval(times_in: Array[float], energy_in: Array[float], min_interval: float) -> Dictionary:
	var out_t: Array[float] = []
	var out_e: Array[float] = []
	var nmin: int = min(times_in.size(), energy_in.size())
	if nmin <= 0:
		return {"times": out_t, "energy": out_e}

	var dt: float = max(0.0, min_interval)
	if dt <= 0.0:
		return {"times": times_in.duplicate(), "energy": energy_in.duplicate()}

	var last_t: float = -1e20
	var last_idx: int = -1

	for i in range(nmin):
		var t: float = times_in[i]
		var e: float = clamp(energy_in[i], 0.0, 1.0)

		if out_t.is_empty():
			out_t.append(t)
			out_e.append(e)
			last_t = t
			last_idx = 0
			continue

		if (t - last_t) >= dt:
			out_t.append(t)
			out_e.append(e)
			last_t = t
			last_idx = out_t.size() - 1
		else:
			if last_idx >= 0 and e > out_e[last_idx]:
				out_t[last_idx] = t
				out_e[last_idx] = e
				last_t = t

	return {"times": out_t, "energy": out_e}

# Quantile binning: each lane gets ~same count, and each lane corresponds to an energy band.
# Keeps original order; only assigns chars.
func _assign_chars_by_energy_bins(energy: Array[float], pool_for_bands: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var n: int = energy.size()
	if n <= 0:
		return out

	var p: Array[String] = pool_for_bands
	if p.is_empty():
		p = ["A"]
	var lanes: int = max(1, p.size())

	out.resize(n)

	var idxs: Array[int] = []
	idxs.resize(n)
	for i in range(n):
		idxs[i] = i

	m_sort_energy_ref = energy
	idxs.sort_custom(Callable(self, "_cmp_energy_idx"))
	m_sort_energy_ref = []

	for rank in range(n):
		var original_i: int = idxs[rank]
		var lane: int = int(floor(float(rank) * float(lanes) / float(n)))
		lane = clamp(lane, 0, lanes - 1)
		out[original_i] = p[lane]

	return out

func _cmp_energy_idx(a: int, b: int) -> bool:
	if m_sort_energy_ref.is_empty():
		return a < b
	var ea: float = m_sort_energy_ref[a]
	var eb: float = m_sort_energy_ref[b]
	if ea == eb:
		return a < b
	return ea < eb

func _shuffle_array_in_place(arr: Array[String], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# -------------------------
# Keys & lanes
# -------------------------

func _rebuild_key_pool() -> void:
	m_pool = _string_to_unique_chars(key_chars, "AWSD")
	m_lane_index.clear()
	for i in range(m_pool.size()):
		m_lane_index[m_pool[i]] = i

func _string_to_unique_chars(s: String, fallback: String) -> Array[String]:
	var src: String = s
	if src.is_empty():
		src = fallback
	var out: Array[String] = []
	var seen: Dictionary = {}
	for i in range(src.length()):
		var ch: String = src.substr(i, 1).to_upper()
		if ch.strip_edges().is_empty():
			continue
		if not seen.has(ch):
			seen[ch] = true
			out.append(ch)
	return out

# -------------------------
# Runtime: spawn + move notes + finalize
# -------------------------

func _process(_delta: float) -> void:
	if m_player == null:
		queue_redraw()
		return

	# Keep drawing HUD even when stopped
	if not m_player.playing:
		_try_finalize_if_done(_song_time())
		queue_redraw()
		return

	var now_t: float = _song_time()
	_spawn_onsets(now_t)
	_update_notes(now_t)
	_try_finalize_if_done(now_t)
	queue_redraw()

func _spawn_onsets(now_t: float) -> void:
	if m_onsets.is_empty():
		return
	var spawn_ahead: float = max(travel_time_sec, lookahead_sec)

	while m_next_spawn < m_onsets.size():
		var t: float = m_onsets[m_next_spawn]
		if t > now_t + spawn_ahead:
			break

		var spawn_t: float = t - travel_time_sec
		var ch: String = m_onset_chars[m_next_spawn] if m_next_spawn < m_onset_chars.size() else (m_pool[0] if not m_pool.is_empty() else "A")
		var lane: int = int(m_lane_index.get(ch, 0))
		var x: float = _lane_x(lane)

		var n: Dictionary = {}
		n["time"] = t
		n["spawn"] = spawn_t
		n["ch"] = ch
		n["lane"] = lane
		n["pos"] = Vector2(x, spawn_y)
		n["judge"] = ""
		m_notes.append(n)

		emit_signal("onset_spawned", m_next_spawn, t, ch)
		m_next_spawn += 1

func _update_notes(now_t: float) -> void:
	var rect: Rect2 = get_viewport_rect()
	var bottom_y: float = float(rect.size.y) + 200.0
	var late_sec: float = (good_ms / 1000.0) * 1.2

	for i in range(m_notes.size() - 1, -1, -1):
		var n: Dictionary = m_notes[i]
		var t: float = _dict_get_float(n, "time", 0.0)
		var spawn_t: float = _dict_get_float(n, "spawn", t - travel_time_sec)
		var denom: float = max(t - spawn_t, 0.000001)
		var p: float = (now_t - spawn_t) / denom

		var lane: int = _dict_get_int(n, "lane", 0)
		var x: float = _lane_x(lane)
		var y: float = lerp(spawn_y, hit_y, p)
		n["pos"] = Vector2(x, y)
		m_notes[i] = n

		# Auto-miss (count it once)
		var judge_str: String = _dict_get_string(n, "judge", "")
		if judge_str.is_empty() and now_t > t + late_sec:
			n["judge"] = "MISS"
			m_notes[i] = n
			m_count_miss += 1
			m_combo = 0

		# Remove off-screen
		if y > bottom_y:
			m_notes.remove_at(i)

func _try_finalize_if_done(now_t: float) -> void:
	if m_game_finished:
		return

	var late_sec: float = (good_ms / 1000.0) * 1.2
	var all_spawned: bool = (m_next_spawn >= m_onsets.size())
	var after_last: bool = (m_onsets.is_empty() or now_t > (m_last_onset_time + late_sec))
	var no_notes: bool = m_notes.is_empty()

	# If stream length known, also allow end-of-track
	var end_of_track: bool = false
	if m_stream_length > 0.1:
		end_of_track = (now_t >= m_stream_length - 0.05)

	if (all_spawned and after_last and no_notes) or (end_of_track and all_spawned and no_notes):
		m_game_finished = true
		_print_final_summary_once()

func _print_final_summary_once() -> void:
	if m_final_printed:
		return
	m_final_printed = true

	var score: float = _compute_score_0_100()
	var total: int = m_count_perfect + m_count_great + m_count_good + m_count_miss
	print("=== PianoGame Results ===")
	print("Score: ", int(round(score)), " / 100")
	print("Perfect: ", m_count_perfect, "  Great: ", m_count_great, "  Good: ", m_count_good, "  Miss: ", m_count_miss, "  Total: ", total)
	print("Max Combo: ", m_max_combo)

# -------------------------
# Input & judging
# -------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_string: String = OS.get_keycode_string(event.keycode).to_upper()
		if m_lane_index.has(key_string):
			judge_key(key_string)

func judge_key(ch: String) -> void:
	if m_player == null or m_player.stream == null:
		return
	if m_onsets.is_empty() or m_onset_chars.is_empty():
		return

	var now_t: float = _song_time()
	var res: Dictionary = _best_candidate_for_key(ch, now_t)
	var ok: bool = bool(res.get("ok", false))
	if not ok:
		# MISS on key press with no candidate
		m_count_miss += 1
		m_combo = 0
		emit_signal("judged", "MISS", 9999.0)
		return

	var idx: int = int(res["idx"])
	var err_ms: float = float(res["err_ms"])
	var abs_ms: float = float(res["abs_ms"])

	var result: String = "MISS"
	if abs_ms <= perfect_ms:
		result = "PERFECT"
	elif abs_ms <= great_ms:
		result = "GREAT"
	elif abs_ms <= good_ms:
		result = "GOOD"

	# --- update counters + combo ---
	match result:
		"PERFECT":
			m_count_perfect += 1
			m_combo += 1
		"GREAT":
			m_count_great += 1
			m_combo += 1
		"GOOD":
			m_count_good += 1
			m_combo += 1
		_:
			m_count_miss += 1
			m_combo = 0
	m_max_combo = max(m_max_combo, m_combo)

	emit_signal("judged", result, err_ms)
	_mark_note_judgement(m_onsets[idx], result)

	if result != "MISS":
		m_next_judge = max(m_next_judge, idx + 1)

func _best_candidate_for_key(ch: String, now_t: float) -> Dictionary:
	var good_s: float = good_ms / 1000.0

	# Skip too-old targets
	while m_next_judge < m_onsets.size():
		var tt: float = m_onsets[m_next_judge]
		if now_t - tt > good_s * 1.2:
			m_next_judge += 1
		else:
			break

	# Search ahead for best matching key
	var max_check: int = 10
	var best_idx: int = -1
	var best_abs_ms: float = BIG_FLOAT
	var best_err_ms: float = 0.0

	for k in range(max_check):
		var i: int = m_next_judge + k
		if i >= m_onsets.size():
			break
		if m_onset_chars[i] != ch:
			continue
		var err_s: float = now_t - m_onsets[i]
		var a_ms: float = abs(err_s * 1000.0)
		if a_ms < best_abs_ms:
			best_abs_ms = a_ms
			best_idx = i
			best_err_ms = err_s * 1000.0

	if best_idx < 0:
		return {"ok": false}
	if best_abs_ms > good_ms:
		return {"ok": false}

	return {"ok": true, "idx": best_idx, "abs_ms": best_abs_ms, "err_ms": best_err_ms}

func _mark_note_judgement(target_t: float, result: String) -> void:
	var window: float = 0.02
	for i in range(m_notes.size() - 1, -1, -1):
		var n: Dictionary = m_notes[i]
		var t: float = _dict_get_float(n, "time", 0.0)
		if abs(t - target_t) <= window:
			n["judge"] = result
			m_notes[i] = n
			return

# -------------------------
# Score (0..100)
# -------------------------

func _compute_score_0_100() -> float:
	var total: int = m_count_perfect + m_count_great + m_count_good + m_count_miss
	if total <= 0:
		return 0.0

	# Accuracy weights
	var acc: float = (
		float(m_count_perfect) * 1.00 +
		float(m_count_great)   * 0.85 +
		float(m_count_good)    * 0.65 +
		float(m_count_miss)    * 0.00
	) / float(total)

	# Combo bonus (soft)
	var combo_ratio: float = clamp(float(m_max_combo) / float(max(1, total)), 0.0, 1.0)

	# 85% accuracy + 15% combo => even all perfect may not be exactly 100 depending on combo ratio
	var score: float = (acc * 85.0) + (combo_ratio * 15.0)
	return clamp(score, 0.0, 100.0)

# -------------------------
# Draw
# -------------------------

func _draw() -> void:
	var rect: Rect2 = get_viewport_rect()
	var w: float = float(rect.size.x)

	# Hit line
	if draw_hit_line:
		var x0: float = hit_line_margin_x
		var x1: float = max(x0 + 1.0, w - hit_line_margin_x)
		draw_line(Vector2(x0, hit_y), Vector2(x1, hit_y), Color.RED, hit_line_thickness)

		if m_draw_font != null and not hit_line_label.is_empty():
			var fs: int = m_draw_font_size
			var ascent: float = float(m_draw_font.get_ascent(fs))
			var descent: float = float(m_draw_font.get_descent(fs))
			var hh: float = ascent + descent
			var by: float = hit_y + hit_line_label_offset_y + (hh * 0.5) - descent
			draw_string(m_draw_font, Vector2(x0, by), hit_line_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	# Lane guides
	if draw_lane_guides:
		for i in range(m_pool.size()):
			var xg: float = _lane_x(i)
			draw_line(Vector2(xg, spawn_y), Vector2(xg, hit_y + 220.0), Color(1, 1, 1, lane_guide_alpha), 1.0)

	# Notes
	for i in range(m_notes.size()):
		var n: Dictionary = m_notes[i]
		var pos: Vector2 = _dict_get_vec2(n, "pos", Vector2.ZERO)
		var ch: String = _dict_get_string(n, "ch", "A")
		var judge_str: String = _dict_get_string(n, "judge", "")

		var fill: Color = COLOR_BASE
		if not judge_str.is_empty() and JUDGE_COLORS.has(judge_str):
			fill = JUDGE_COLORS[judge_str] as Color

		draw_circle(pos, circle_radius, fill)
		draw_arc(pos, circle_radius, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 2.0)

		if show_letters and m_draw_font != null:
			var fs2: int = m_draw_font_size
			var sz: Vector2 = m_draw_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
			var ascent2: float = float(m_draw_font.get_ascent(fs2))
			var descent2: float = float(m_draw_font.get_descent(fs2))
			var hh2: float = ascent2 + descent2
			var by2: float = pos.y + (hh2 * 0.5) - descent2
			draw_string(m_draw_font, Vector2(pos.x - sz.x * 0.5, by2), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color.BLACK)

	_draw_hud()

func _draw_hud() -> void:
	if not show_hud:
		return
	if m_draw_font == null:
		return

	var score: float = _compute_score_0_100()
	var total: int = m_count_perfect + m_count_great + m_count_good + m_count_miss

	var lines: Array[String] = [
		"Score: %d" % int(round(score)),
		"Combo: %d  (Max %d)" % [m_combo, m_max_combo],
		"PERFECT: %d" % m_count_perfect,
		"GREAT:   %d" % m_count_great,
		"GOOD:    %d" % m_count_good,
		"MISS:    %d" % m_count_miss,
		"TOTAL:   %d" % total,
	]

	var fs: int = max(10, hud_font_size)
	var ascent: float = float(m_draw_font.get_ascent(fs))
	var descent: float = float(m_draw_font.get_descent(fs))
	var line_h: float = ascent + descent + 4.0

	var x: float = hud_pos.x
	var y: float = hud_pos.y + ascent

	for i in range(lines.size()):
		draw_string(
			m_draw_font,
			Vector2(x, y + float(i) * line_h),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			Color.WHITE
		)
# -------------------------
# Lane positioning (CENTERED CLUSTER)
# -------------------------

func _lane_x(lane: int) -> float:
	var rect: Rect2 = get_viewport_rect()
	var w: float = float(rect.size.x)

	var count: int = max(1, m_pool.size())
	var usable_max: float = max(1.0, w - 2.0 * lane_margin_x)

	# Desired span based on minimum spacing, but never exceed usable width
	var desired_span: float = 0.0
	if count > 1:
		desired_span = float(count - 1) * lane_min_spacing_x
	var span: float = min(usable_max, max(0.0, desired_span))

	# If only 1 lane, span doesn't matter; otherwise center the span
	var left: float = (w - span) * 0.5
	var right: float = w - left

	# Clamp to respect margin (in case span==usable_max etc.)
	left = max(left, lane_margin_x)
	right = min(right, w - lane_margin_x)

	return _lane_x_in_range(lane, count, left, right)

func _lane_x_in_range(lane: int, count: int, left: float, right: float) -> float:
	var c: int = max(1, count)
	if c == 1:
		return (left + right) * 0.5
	var li: int = clamp(lane, 0, c - 1)
	var tt: float = float(li) / float(c - 1)
	return lerp(left, right, tt)

# -------------------------
# Typed dictionary helpers
# -------------------------

func _dict_get_float(d: Dictionary, k: String, def: float) -> float:
	if not d.has(k):
		return def
	return float(d[k])

func _dict_get_int(d: Dictionary, k: String, def: int) -> int:
	if not d.has(k):
		return def
	return int(d[k])

func _dict_get_string(d: Dictionary, k: String, def: String) -> String:
	if not d.has(k):
		return def
	return String(d[k])

func _dict_get_vec2(d: Dictionary, k: String, def: Vector2) -> Vector2:
	if not d.has(k):
		return def
	return d[k] as Vector2

func _dict_get_float_array(d: Dictionary, k: String) -> Array[float]:
	var out: Array[float] = []
	if not d.has(k):
		return out
	var v: Variant = d[k]
	if v is Array:
		var a: Array = v
		out.resize(a.size())
		for i in range(a.size()):
			out[i] = float(a[i])
	return out

# -------------------------
# IO
# -------------------------

func _auto_json_path(src_mp3_path: String) -> String:
	var base: String = src_mp3_path.get_base_dir()
	var name: String = src_mp3_path.get_file().get_basename()
	return "%s/%s.beats.json" % [base, name]

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var j: JSON = JSON.new()
	var err: int = j.parse(text)
	if err != OK:
		push_error("JSON parse error: %s at line %d" % [j.get_error_message(), j.get_error_line()])
		return {}
	var data: Variant = j.data
	return data if data is Dictionary else {}

func _load_mp3_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		var s: Variant = load(path)
		return s as AudioStream if s is AudioStream else null
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var mp3: AudioStreamMP3 = AudioStreamMP3.new()
	mp3.data = bytes
	return mp3
