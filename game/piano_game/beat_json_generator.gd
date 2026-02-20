@tool
class_name BeatJsonGenerator
extends Node

@export var generate := false:
	set(new_flag):
		if not new_flag:
			return
		generate = false
		_regenerate()

@export_file_path("*.mp3") var mp3_path: String = "res://music/song.mp3":
	set(new_path):
		if mp3_path == new_path:
			return
		mp3_path = new_path

@export var output_json_path: String = ""  # leave empty to auto

# Analysis knobs
@export_range(60, 240, 1) var bpm_min: int = 70
@export_range(60, 240, 1) var bpm_max: int = 180
@export var analysis_seconds_limit: float = 0.0 # 0 = full track
@export var hop_seconds: float = 0.010
@export var peak_threshold: float = 0.08
@export var beat_pick_window: float = 0.05

# Peak density control
@export_range(0.0, 0.30, 0.005) var min_peak_spacing_sec: float = 0.06

# Beat-subdivision filtering (keep only onsets close to beat grid)
@export var keep_only_beat_aligned_onsets: bool = true
@export_range(0.005, 0.080, 0.001) var beat_align_tolerance_sec: float = 0.020
@export_range(1, 16, 1) var beat_align_max_division: int = 16 # allow 1,2,4,8,16

# NEW: onset energy from local "volume"
@export_range(0.010, 0.200, 0.005) var onset_energy_window_sec: float = 0.050
@export_range(0.0, 1.0, 0.05) var energy_window_bias_to_past: float = 0.35
# 0.0 = centered window, 1.0 = window ends at onset (all in the past)

@export var onset_energy_use_p95_norm: bool = true

# --- progress/status ---
@export_range(0.0, 1.0, 0.001) var progress: float = 0.0
@export var status: String = ""

# Reduce debug output frequency
@export_range(0.0, 0.25, 0.01) var progress_print_min_delta: float = 0.02 # 2%
@export_range(0.0, 2.0, 0.1) var progress_print_min_interval_sec: float = 0.6

# Internal (private) - m_ prefix
var m_player: AudioStreamPlayer
var m_capture_bus_index: int = -1
var m_capture_effect: AudioEffectCapture
var m_mix_rate: int = 0
var m_is_generating: bool = false
var m_pending_regenerate: bool = false
var m_requested_mp3_path: String = ""
var m_requested_output_json_path: String = ""

var m_last_progress_print_p: float = -999.0
var m_last_progress_print_ms: int = 0

func _ready() -> void:
	m_player = AudioStreamPlayer.new()
	add_child(m_player)
	m_mix_rate = int(AudioServer.get_mix_rate())
	m_requested_mp3_path = mp3_path
	m_requested_output_json_path = output_json_path
	_set_progress(0.0, "Idle")

func _regenerate() -> void:
	m_requested_mp3_path = mp3_path
	m_requested_output_json_path = output_json_path

	if m_is_generating:
		m_pending_regenerate = true
		return

	m_is_generating = true
	call_deferred("_do_generate_json")

func _do_generate_json() -> void:
	await generate_json(m_requested_mp3_path, m_requested_output_json_path)
	m_is_generating = false

	if m_pending_regenerate:
		m_pending_regenerate = false
		_regenerate()

func _set_progress(p: float, s: String) -> void:
	progress = clamp(p, 0.0, 1.0)
	status = s

	var now_ms: int = Time.get_ticks_msec()
	var dt_ms: int = now_ms - m_last_progress_print_ms
	var dp: float = abs(progress - m_last_progress_print_p)

	var must_print: bool = false
	if progress <= 0.0001 or progress >= 0.9999:
		must_print = true
	elif dp >= progress_print_min_delta:
		must_print = true
	elif float(dt_ms) >= progress_print_min_interval_sec * 1000.0:
		must_print = true

	if must_print:
		m_last_progress_print_p = progress
		m_last_progress_print_ms = now_ms
		print("[BeatJsonGenerator] ", int(progress * 100.0), "% - ", status)

func _ensure_capture_bus(bus_name: String = "BeatCapture") -> void:
	m_capture_bus_index = AudioServer.get_bus_index(bus_name)
	if m_capture_bus_index == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		m_capture_bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(m_capture_bus_index, bus_name)

	m_capture_effect = null
	for i in range(AudioServer.get_bus_effect_count(m_capture_bus_index)):
		var e: AudioEffect = AudioServer.get_bus_effect(m_capture_bus_index, i)
		if e is AudioEffectCapture:
			m_capture_effect = e as AudioEffectCapture
			break

	if m_capture_effect == null:
		m_capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(m_capture_bus_index, m_capture_effect, 0)

	AudioServer.set_bus_mute(m_capture_bus_index, true)

func _load_mp3_stream(path: String) -> AudioStream:
	if path.begins_with("res://"):
		var s: Variant = load(path)
		if s is AudioStream:
			return s as AudioStream
		push_error("Failed to load AudioStream from res:// path: %s" % path)
		return null

	if not FileAccess.file_exists(path):
		push_error("MP3 file not found: %s" % path)
		return null

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("MP3 read returned empty bytes: %s" % path)
		return null

	var mp3: AudioStreamMP3 = AudioStreamMP3.new()
	mp3.data = bytes
	return mp3

func _auto_output_path(src_path: String) -> String:
	var base: String = src_path.get_base_dir()
	var name: String = src_path.get_file().get_basename()
	return "%s/%s.beats.json" % [base, name]

func _safe_write_json(path_try: String, json_text: String) -> String:
	var f: FileAccess = FileAccess.open(path_try, FileAccess.WRITE)
	if f:
		f.store_string(json_text)
		f.close()
		return path_try

	var fallback: String = "user://beats.json"
	var f2: FileAccess = FileAccess.open(fallback, FileAccess.WRITE)
	if f2:
		f2.store_string(json_text)
		f2.close()
		return fallback

	push_error("Failed to write JSON to %s and %s" % [path_try, fallback])
	return ""

func generate_json(src_mp3_path: String, out_json_path: String = "") -> void:
	_set_progress(0.0, "Preparing capture bus")
	_ensure_capture_bus()

	_set_progress(0.02, "Loading MP3")
	var stream: AudioStream = _load_mp3_stream(src_mp3_path)
	if stream == null:
		_set_progress(0.0, "Failed to load MP3")
		return

	m_player.stream = stream
	m_player.bus = AudioServer.get_bus_name(m_capture_bus_index)

	var duration: float = 0.0
	if stream.has_method("get_length"):
		duration = float(stream.call("get_length"))

	var max_time: float = duration
	if analysis_seconds_limit > 0.0:
		max_time = min(duration, analysis_seconds_limit) if duration > 0.0 else analysis_seconds_limit

	_set_progress(0.05, "Capturing audio")
	m_capture_effect.clear_buffer()
	m_player.play()

	var mono_samples: PackedFloat32Array = PackedFloat32Array() # signed mono for onset detection
	var vol_samples: PackedFloat32Array = PackedFloat32Array()  # per-sample stereo RMS magnitude for "volume energy"
	var last_time: float = 0.0

	while m_player.playing:
		await get_tree().process_frame

		var t: float = m_player.get_playback_position()

		if max_time > 0.0:
			var cap_p: float = clamp(t / max_time, 0.0, 1.0)
			_set_progress(0.05 + cap_p * 0.65, "Capturing audio (%.2fs / %.2fs)" % [t, max_time])

		if max_time > 0.0 and t >= max_time:
			m_player.stop()
			break

		var frames_available: int = m_capture_effect.get_frames_available()
		if frames_available > 0:
			var buf: PackedVector2Array = m_capture_effect.get_buffer(frames_available)
			var n: int = buf.size()

			var old_m: int = mono_samples.size()
			var old_v: int = vol_samples.size()
			mono_samples.resize(old_m + n)
			vol_samples.resize(old_v + n)

			for i in range(n):
				var l: float = buf[i].x
				var r: float = buf[i].y

				# signed mono (keeps waveform polarity) -> better onset diff behavior
				mono_samples[old_m + i] = (l + r) * 0.5

				# stereo RMS magnitude per sample -> good for "volume"
				vol_samples[old_v + i] = sqrt((l * l + r * r) * 0.5)

		if t <= last_time and duration > 0.0 and t >= duration - 0.05:
			break
		last_time = t

	_set_progress(0.72, "Analyzing audio")
	var analyzed_duration: float = float(mono_samples.size()) / float(m_mix_rate)
	if analyzed_duration < 1.0:
		push_error("Not enough audio captured to analyze.")
		_set_progress(0.0, "Not enough audio captured")
		return

	var analysis: Dictionary = _analyze_beats_onsets_and_energy(mono_samples, vol_samples, m_mix_rate, analyzed_duration)

	_set_progress(0.92, "Writing JSON")
	var out_path: String = out_json_path
	if out_path.is_empty():
		out_path = _auto_output_path(src_mp3_path)

	var json_text: String = JSON.stringify(analysis, "\t", false)
	var written_to: String = _safe_write_json(out_path, json_text)
	if written_to != "":
		print("Wrote beat JSON: ", written_to)

	_set_progress(1.0, "Done")

# ------------------------------------------------------------
# Outputs:
#   - beats
#   - onsets
#   - onset_energy (volume RMS around onset time, normalized 0..1)
# ------------------------------------------------------------

func _analyze_beats_onsets_and_energy(mono: PackedFloat32Array, vol: PackedFloat32Array, sr: int, duration: float) -> Dictionary:
	var hop: int = max(1, int(round(hop_seconds * float(sr))))
	var win: int = max(hop, int(round(0.050 * float(sr)))) # 50ms

	# 1) RMS envelope (from signed mono)
	var energy: PackedFloat32Array = PackedFloat32Array()
	var times: PackedFloat32Array = PackedFloat32Array()

	var i: int = 0
	while i + win < mono.size():
		var sum: float = 0.0
		for j in range(win):
			var x: float = mono[i + j]
			sum += x * x
		var rms: float = sqrt(sum / float(win))
		energy.append(rms)
		times.append(float(i) / float(sr))
		i += hop

	# 2) Onset strength (positive diffs)
	var onset: PackedFloat32Array = PackedFloat32Array()
	onset.resize(energy.size())
	onset[0] = 0.0
	var max_onset: float = 0.000001
	for k in range(1, energy.size()):
		var d: float = energy[k] - energy[k - 1]
		var v: float = d if d > 0.0 else 0.0
		onset[k] = v
		if v > max_onset:
			max_onset = v

	for k in range(onset.size()):
		onset[k] = onset[k] / max_onset

	# 3) BPM + phase
	var bpm: float = _estimate_bpm_from_onset(onset, sr, hop, bpm_min, bpm_max)
	var beat_period: float = 60.0 / bpm
	var phase: float = _pick_best_phase(onset, times, beat_period, beat_pick_window)

	# 4) Beat grid
	var beats: Array[float] = []
	var t0: float = phase
	while t0 < duration:
		beats.append(t0)
		t0 += beat_period

	# 5) Onset peaks
	var peaks_out: Dictionary = _extract_onset_peaks_filtered_with_energy(onset, times, peak_threshold, min_peak_spacing_sec)
	var onsets_peaks: Array[float] = peaks_out.get("times", []) as Array[float]

	# 6) onset_energy from "volume" samples (RMS in window, optionally biased to past)
	var onset_energy: Array[float] = _compute_volume_rms_energy(vol, sr, onsets_peaks, onset_energy_window_sec, energy_window_bias_to_past)

	if onset_energy_use_p95_norm:
		_normalize_energy_by_p95_in_place(onset_energy)
	else:
		_normalize_energy_by_max_in_place(onset_energy)

	# 7) Optional beat subdivision filter (1, 1/2, 1/4, 1/8, 1/16) — filter only
	if keep_only_beat_aligned_onsets and onsets_peaks.size() > 0:
		var tol: float = max(beat_align_tolerance_sec, hop_seconds * 1.5)
		var div_max: int = clamp(beat_align_max_division, 1, 16)
		var filt: Dictionary = _filter_onsets_to_beat_subdivisions(onsets_peaks, onset_energy, phase, beat_period, tol, div_max)
		onsets_peaks = filt.get("times", []) as Array[float]
		onset_energy = filt.get("energy", []) as Array[float]

	return {
		"bpm": bpm,
		"duration": duration,
		"hop_seconds": hop_seconds,
		"phase_offset": phase,
		"beats": beats,
		"onsets": onsets_peaks,
		"onset_energy": onset_energy,
	}

func _estimate_bpm_from_onset(onset: PackedFloat32Array, sr: int, hop: int, min_bpm: int, max_bpm: int) -> float:
	var hop_s: float = float(hop) / float(sr)
	var min_lag: int = int(round((60.0 / float(max_bpm)) / hop_s))
	var max_lag: int = int(round((60.0 / float(min_bpm)) / hop_s))
	min_lag = max(min_lag, 1)
	max_lag = min(max_lag, onset.size() - 1)

	var best_lag: int = min_lag
	var best_score: float = -1.0

	for lag in range(min_lag, max_lag + 1):
		var s: float = 0.0
		for t in range(lag, onset.size()):
			s += onset[t] * onset[t - lag]
		if s > best_score:
			best_score = s
			best_lag = lag

	var period_s: float = float(best_lag) * hop_s
	var bpm: float = 60.0 / max(period_s, 0.000001)
	return clamp(bpm, float(min_bpm), float(max_bpm))

func _pick_best_phase(onset: PackedFloat32Array, times: PackedFloat32Array, period_s: float, window_s: float) -> float:
	var steps: int = 64
	var best_phase: float = 0.0
	var best_score: float = -1.0

	for si in range(steps):
		var phase: float = (float(si) / float(steps)) * period_s
		var score: float = 0.0

		var t: float = phase
		while t < times[-1]:
			score += _sum_onset_near_time(onset, times, t, window_s)
			t += period_s

		if score > best_score:
			best_score = score
			best_phase = phase

	return best_phase

func _sum_onset_near_time(onset: PackedFloat32Array, times: PackedFloat32Array, target_t: float, window_s: float) -> float:
	var s: float = 0.0
	for i in range(times.size()):
		if abs(times[i] - target_t) <= window_s:
			s += onset[i]
	return s

# Peak filter output:
#   times[]  : onset peak time (sec)
#   energy[] : peak strength (0..1) -- NOT used as onset_energy anymore, but kept if needed
func _extract_onset_peaks_filtered_with_energy(
	onset: PackedFloat32Array,
	times: PackedFloat32Array,
	thresh: float,
	min_spacing_s: float
) -> Dictionary:
	var out_times: Array[float] = []
	var out_energy: Array[float] = []

	if onset.size() < 3:
		return {"times": out_times, "energy": out_energy}

	var min_spacing: float = max(0.0, min_spacing_s)
	var last_keep_t: float = -1e20
	var last_keep_strength: float = -1.0

	for i in range(1, onset.size() - 1):
		var v: float = onset[i]
		if v < thresh:
			continue
		if not (v > onset[i - 1] and v >= onset[i + 1]):
			continue

		var t: float = float(times[i])

		if out_times.is_empty() or min_spacing <= 0.0 or (t - last_keep_t) >= min_spacing:
			out_times.append(t)
			out_energy.append(v)
			last_keep_t = t
			last_keep_strength = v
		else:
			if v > last_keep_strength:
				out_times[out_times.size() - 1] = t
				out_energy[out_energy.size() - 1] = v
				last_keep_t = t
				last_keep_strength = v

	return {"times": out_times, "energy": out_energy}

# Volume energy = RMS of vol_samples inside window around onset.
# Bias:
#   0.0 => centered
#   1.0 => window ends exactly at onset (all in the past)
func _compute_volume_rms_energy(
	vol_samples: PackedFloat32Array,
	sr: int,
	onset_times: Array[float],
	window_sec: float,
	bias_to_past: float
) -> Array[float]:
	var out: Array[float] = []
	out.resize(onset_times.size())

	var win_s: float = max(0.010, window_sec)
	var win: int = int(round(win_s * float(sr)))
	win = max(16, win)

	var bias: float = clamp(bias_to_past, 0.0, 1.0)
	var past_len: int = int(round(float(win) * bias))
	past_len = clamp(past_len, 0, win)
	var future_len: int = win - past_len

	for i in range(onset_times.size()):
		var t: float = onset_times[i]
		var center: int = int(round(t * float(sr)))

		var a: int = max(0, center - past_len)
		var b: int = min(vol_samples.size() - 1, center + future_len)
		if b <= a:
			out[i] = 0.0
			continue

		var sum_sq: float = 0.0
		var n: int = 0
		for sidx in range(a, b + 1):
			var x: float = vol_samples[sidx]
			sum_sq += x * x
			n += 1

		out[i] = sqrt(sum_sq / float(max(1, n)))

	return out

func _normalize_energy_by_max_in_place(arr: Array[float]) -> void:
	if arr.is_empty():
		return
	var m: float = 0.000001
	for v in arr:
		m = max(m, float(v))
	for i in range(arr.size()):
		arr[i] = clamp(float(arr[i]) / m, 0.0, 1.0)

func _normalize_energy_by_p95_in_place(arr: Array[float]) -> void:
	if arr.is_empty():
		return
	var tmp: Array[float] = arr.duplicate()
	tmp.sort()
	var n: int = tmp.size()
	var idx: int = int(floor(float(n - 1) * 0.95))
	idx = clamp(idx, 0, n - 1)
	var p95: float = max(0.000001, float(tmp[idx]))
	for i in range(arr.size()):
		arr[i] = clamp(float(arr[i]) / p95, 0.0, 1.0)

func _filter_onsets_to_beat_subdivisions(
	onsets: Array[float],
	energy: Array[float],
	phase: float,
	beat_period: float,
	tol: float,
	div_max: int
) -> Dictionary:
	var out_t: Array[float] = []
	var out_e: Array[float] = []

	var nmin: int = min(onsets.size(), energy.size())
	if nmin <= 0:
		return {"times": out_t, "energy": out_e}

	var allowed: Array[int] = [1, 2, 4, 8, 16]
	var max_div: int = clamp(div_max, 1, 16)

	for i in range(nmin):
		var t: float = onsets[i]
		var best_err: float = 1e20

		for div in allowed:
			if div > max_div:
				continue
			var step: float = beat_period / float(div)
			if step <= 0.000001:
				continue

			var k: float = (t - phase) / step
			var kk: int = int(round(k))
			var grid_t: float = phase + float(kk) * step
			var err: float = abs(t - grid_t)
			if err < best_err:
				best_err = err

		if best_err <= tol:
			out_t.append(t)
			out_e.append(energy[i])

	return {"times": out_t, "energy": out_e}
