@tool
extends VBoxContainer
## Editor dock that batch-converts MP3 files to OGG Vorbis via ffmpeg.

const DEFAULT_FFMPEG_CANDIDATES_MACOS := [
	"/opt/homebrew/bin/ffmpeg",
	"/usr/local/bin/ffmpeg",
	"/opt/local/bin/ffmpeg",
	"/usr/bin/ffmpeg",
]

const DEFAULT_FFMPEG_CANDIDATES_LINUX := [
	"/usr/local/bin/ffmpeg",
	"/usr/bin/ffmpeg",
	"/snap/bin/ffmpeg",
]

const DEFAULT_FFMPEG_CANDIDATES_WINDOWS := [
	"ffmpeg.exe",
	"C:/ffmpeg/bin/ffmpeg.exe",
	"C:/Program Files/ffmpeg/bin/ffmpeg.exe",
	"C:/Program Files (x86)/ffmpeg/bin/ffmpeg.exe",
]

const PROJECT_METADATA_SECTION := "mp3_to_ogg"
const PROJECT_METADATA_KEY := "dock_state"

# ---------------------------------------------------------------------------
# UI references (built in _ready)
# ---------------------------------------------------------------------------
var m_editor_interface: EditorInterface
var m_ffmpeg_edit: LineEdit
var m_ffmpeg_browse: Button
var m_source_edit: LineEdit
var m_source_browse: Button
var m_target_edit: LineEdit
var m_target_browse: Button
var m_quality_spin: SpinBox
var m_convert_btn: Button
var m_copy_btn: Button
var m_progress_label: Label
var m_progress_bar: ProgressBar
var m_log_label: RichTextLabel
var m_ffmpeg_dialog: EditorFileDialog
var m_source_dialog: EditorFileDialog
var m_target_dialog: EditorFileDialog
var m_log_output_lines: PackedStringArray = PackedStringArray()
var m_worker_thread: Thread
var m_worker_mutex: Mutex = Mutex.new()
var m_worker_events: Array[Dictionary] = []
var m_conversion_running: bool = false
var m_rescan_requested: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func setup(editor_interface: EditorInterface) -> void:
	m_editor_interface = editor_interface


func _ready() -> void:
	if get_child_count() > 0:
		return
	_build_ui()
	_load_persisted_settings()
	set_process(false)


func _exit_tree() -> void:
	_save_persisted_settings()
	_wait_for_worker_thread()


func _process(_delta: float) -> void:
	var had_events := _drain_worker_events()
	if m_worker_thread != null and m_worker_thread.is_started() and not m_worker_thread.is_alive():
		_wait_for_worker_thread()
		_drain_worker_events()
		_finish_conversion_run()
		had_events = true

	if not m_conversion_running and m_worker_thread == null and not had_events:
		set_process(false)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# --- Title ---
	var title := Label.new()
	title.text = "MP3 to OGG Converter"
	add_child(title)

	add_child(HSeparator.new())

	# --- FFmpeg executable ---
	var ffmpeg_label := Label.new()
	ffmpeg_label.text = "FFmpeg executable:"
	ffmpeg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ffmpeg_label.tooltip_text = "Optional. Leave blank to auto-detect ffmpeg in standard locations."
	add_child(ffmpeg_label)

	var ffmpeg_row := HBoxContainer.new()
	m_ffmpeg_edit = LineEdit.new()
	m_ffmpeg_edit.placeholder_text = "ffmpeg"
	m_ffmpeg_edit.tooltip_text = ffmpeg_label.tooltip_text
	m_ffmpeg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_ffmpeg_edit.text_changed.connect(_on_settings_changed)
	ffmpeg_row.add_child(m_ffmpeg_edit)

	m_ffmpeg_browse = Button.new()
	m_ffmpeg_browse.text = "Browse..."
	m_ffmpeg_browse.pressed.connect(_on_ffmpeg_browse)
	ffmpeg_row.add_child(m_ffmpeg_browse)
	add_child(ffmpeg_row)

	# --- Source folder ---
	var src_label := Label.new()
	src_label.text = "Source folder:"
	src_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	src_label.tooltip_text = "Absolute path or res:// folder with .mp3 files."
	add_child(src_label)

	var src_row := HBoxContainer.new()
	m_source_edit = LineEdit.new()
	m_source_edit.placeholder_text = "/Users/you/Music/mp3s"
	m_source_edit.tooltip_text = src_label.tooltip_text
	m_source_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_source_edit.text_changed.connect(_on_settings_changed)
	src_row.add_child(m_source_edit)

	m_source_browse = Button.new()
	m_source_browse.text = "Browse..."
	m_source_browse.pressed.connect(_on_source_browse)
	src_row.add_child(m_source_browse)
	add_child(src_row)

	# --- Target folder ---
	var tgt_label := Label.new()
	tgt_label.text = "Target folder:"
	tgt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tgt_label.tooltip_text = "res:// path inside the project."
	add_child(tgt_label)

	var tgt_row := HBoxContainer.new()
	m_target_edit = LineEdit.new()
	m_target_edit.text = "res://resources/audio/music"
	m_target_edit.tooltip_text = tgt_label.tooltip_text
	m_target_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_target_edit.text_changed.connect(_on_settings_changed)
	tgt_row.add_child(m_target_edit)

	m_target_browse = Button.new()
	m_target_browse.text = "Browse..."
	m_target_browse.pressed.connect(_on_target_browse)
	tgt_row.add_child(m_target_browse)
	add_child(tgt_row)

	# --- Quality slider ---
	var q_row := HBoxContainer.new()
	var q_label := Label.new()
	q_label.text = "OGG quality:"
	q_label.tooltip_text = "0-10 ffmpeg -q:a value. Higher = better quality and larger files."
	q_row.add_child(q_label)

	m_quality_spin = SpinBox.new()
	m_quality_spin.min_value = 0
	m_quality_spin.max_value = 10
	m_quality_spin.value = 6
	m_quality_spin.step = 1
	m_quality_spin.tooltip_text = "ffmpeg -q:a value (higher = better quality / larger file)"
	m_quality_spin.value_changed.connect(_on_quality_changed)
	q_row.add_child(m_quality_spin)
	add_child(q_row)

	add_child(HSeparator.new())

	# --- Action buttons ---
	var action_row := HBoxContainer.new()

	m_convert_btn = Button.new()
	m_convert_btn.text = "Convert"
	m_convert_btn.pressed.connect(_on_convert)
	action_row.add_child(m_convert_btn)

	m_copy_btn = Button.new()
	m_copy_btn.text = "Copy Output"
	m_copy_btn.disabled = true
	m_copy_btn.pressed.connect(_on_copy_output)
	action_row.add_child(m_copy_btn)

	add_child(action_row)

	# --- Progress ---
	m_progress_label = Label.new()
	m_progress_label.text = "Idle"
	add_child(m_progress_label)

	m_progress_bar = ProgressBar.new()
	m_progress_bar.min_value = 0
	m_progress_bar.max_value = 1
	m_progress_bar.value = 0
	m_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(m_progress_bar)

	# --- Log ---
	m_log_label = RichTextLabel.new()
	m_log_label.bbcode_enabled = true
	m_log_label.selection_enabled = true
	m_log_label.shortcut_keys_enabled = true
	m_log_label.scroll_following = true
	m_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m_log_label.custom_minimum_size = Vector2(0, 200)
	add_child(m_log_label)

	# --- EditorFileDialogs ---
	m_ffmpeg_dialog = EditorFileDialog.new()
	m_ffmpeg_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	m_ffmpeg_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	m_ffmpeg_dialog.title = "Select ffmpeg executable"
	m_ffmpeg_dialog.file_selected.connect(_on_ffmpeg_selected)
	add_child(m_ffmpeg_dialog)

	m_source_dialog = EditorFileDialog.new()
	m_source_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	m_source_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	m_source_dialog.title = "Select source folder with MP3 files"
	m_source_dialog.dir_selected.connect(_on_source_selected)
	add_child(m_source_dialog)

	m_target_dialog = EditorFileDialog.new()
	m_target_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	m_target_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	m_target_dialog.title = "Select target folder in project"
	m_target_dialog.dir_selected.connect(_on_target_selected)
	add_child(m_target_dialog)


# ---------------------------------------------------------------------------
# Dialog callbacks
# ---------------------------------------------------------------------------

func _on_ffmpeg_browse() -> void:
	m_ffmpeg_dialog.popup_centered(Vector2i(700, 500))


func _on_source_browse() -> void:
	m_source_dialog.popup_centered(Vector2i(700, 500))


func _on_target_browse() -> void:
	m_target_dialog.popup_centered(Vector2i(700, 500))


func _on_ffmpeg_selected(file_path: String) -> void:
	m_ffmpeg_edit.text = file_path
	_save_persisted_settings()


func _on_copy_output() -> void:
	var clipboard_text := _get_log_output_text()
	if clipboard_text.is_empty():
		return
	DisplayServer.clipboard_set(clipboard_text)


func _on_source_selected(dir: String) -> void:
	m_source_edit.text = dir
	_save_persisted_settings()


func _on_target_selected(dir: String) -> void:
	m_target_edit.text = dir
	_save_persisted_settings()


func _on_settings_changed(_value: String) -> void:
	_save_persisted_settings()


func _on_quality_changed(_value: float) -> void:
	_save_persisted_settings()


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

func _on_convert() -> void:
	if m_conversion_running:
		return

	m_log_label.clear()
	m_log_output_lines.clear()
	m_rescan_requested = false
	_refresh_copy_button()
	_log_msg("[b]Starting conversion...[/b]", "Starting conversion...")

	var configured_ffmpeg := m_ffmpeg_edit.text.strip_edges()
	var source_dir_input := m_source_edit.text.strip_edges()
	var target_dir_input := m_target_edit.text.strip_edges()

	if source_dir_input.is_empty():
		_log_msg("[color=red]Error: source folder is empty.[/color]", "Error: source folder is empty.")
		return
	if target_dir_input.is_empty():
		_log_msg("[color=red]Error: target folder is empty.[/color]", "Error: target folder is empty.")
		return

	var ffmpeg_path := _resolve_ffmpeg_path(configured_ffmpeg)
	if ffmpeg_path.is_empty():
		_log_msg("[color=red]Error: ffmpeg not found.[/color]", "Error: ffmpeg not found.")
		_log_msg("Set the executable path explicitly or install ffmpeg in a standard location.")
		return

	var audio_encoder := _resolve_vorbis_encoder(ffmpeg_path)
	if audio_encoder.is_empty():
		_log_msg("[color=red]Error: no Vorbis encoder was found in this ffmpeg build.[/color]", "Error: no Vorbis encoder was found in this ffmpeg build.")
		_log_msg("Expected one of: vorbis, libvorbis")
		return
	var encoder_requires_experimental := _encoder_requires_strict_experimental(ffmpeg_path, audio_encoder)

	var source_dir := _resolve_source_directory(source_dir_input)
	if source_dir.is_empty():
		return

	var target_paths := _resolve_target_paths(target_dir_input)
	if target_paths.is_empty():
		return
	var target_dir: String = target_paths["resource"]
	var abs_target: String = target_paths["absolute"]

	var make_dir_result: Error = DirAccess.make_dir_recursive_absolute(abs_target)
	if make_dir_result != OK:
		_log_msg("[color=red]Error: could not create target folder %s (code %d).[/color]" % [target_dir, make_dir_result], "Error: could not create target folder %s (code %d)." % [target_dir, make_dir_result])
		return

	_log_msg("Using ffmpeg: %s" % ffmpeg_path)
	_log_msg("Using audio encoder: %s" % audio_encoder)
	if encoder_requires_experimental:
		_log_msg("Using experimental encoder mode: -strict -2")
	_log_msg("Source: %s" % source_dir_input)
	_log_msg("Target: %s" % target_dir)

	var mp3_files := _list_mp3(source_dir)
	if mp3_files.is_empty():
		_log_msg("[color=yellow]No .mp3 files found in: %s[/color]" % source_dir_input, "No .mp3 files found in: %s" % source_dir_input)
		return

	_log_msg("Found [b]%d[/b] MP3 file(s)." % mp3_files.size(), "Found %d MP3 file(s)." % mp3_files.size())

	var quality := int(m_quality_spin.value)
	_start_conversion_run(mp3_files.size())

	var job := {
		"ffmpeg_path": ffmpeg_path,
		"audio_encoder": audio_encoder,
		"encoder_requires_experimental": encoder_requires_experimental,
		"quality": quality,
		"abs_target": abs_target,
		"mp3_files": mp3_files,
	}

	m_worker_thread = Thread.new()
	var start_error: Error = m_worker_thread.start(_run_conversion_worker.bind(job))
	if start_error != OK:
		m_worker_thread = null
		_finish_conversion_run()
		_log_msg("[color=red]Error: failed to start conversion thread (code %d).[/color]" % start_error, "Error: failed to start conversion thread (code %d)." % start_error)
		return

	set_process(true)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _list_mp3(dir_path: String) -> PackedStringArray:
	var results := PackedStringArray()
	var da := DirAccess.open(dir_path)
	if da == null:
		_log_msg("[color=red]Cannot open directory: %s[/color]" % dir_path, "Cannot open directory: %s" % dir_path)
		return results
	da.list_dir_begin()
	var file_name := da.get_next()
	while file_name != "":
		if not da.current_is_dir() and file_name.to_lower().ends_with(".mp3"):
			results.append(dir_path.path_join(file_name))
		file_name = da.get_next()
	da.list_dir_end()
	return results


func _resolve_source_directory(source_dir_input: String) -> String:
	if source_dir_input.begins_with("res://"):
		var resource_dir := ProjectSettings.globalize_path(source_dir_input)
		if DirAccess.dir_exists_absolute(resource_dir):
			return resource_dir
		_log_msg("[color=red]Error: source folder does not exist: %s[/color]" % source_dir_input, "Error: source folder does not exist: %s" % source_dir_input)
		return ""

	if not source_dir_input.is_absolute_path():
		_log_msg("[color=red]Error: source folder must be an absolute path or a res:// folder.[/color]", "Error: source folder must be an absolute path or a res:// folder.")
		return ""

	if not DirAccess.dir_exists_absolute(source_dir_input):
		_log_msg("[color=red]Error: source folder does not exist: %s[/color]" % source_dir_input, "Error: source folder does not exist: %s" % source_dir_input)
		return ""

	return source_dir_input


func _resolve_target_paths(target_dir_input: String) -> Dictionary:
	var resource_dir := target_dir_input
	if target_dir_input.is_absolute_path():
		resource_dir = ProjectSettings.localize_path(target_dir_input)

	if not resource_dir.begins_with("res://"):
		_log_msg("[color=red]Error: target folder must be inside the project (use a res:// path or an absolute path under the project root).[/color]", "Error: target folder must be inside the project (use a res:// path or an absolute path under the project root).")
		return {}

	return {
		"resource": resource_dir,
		"absolute": ProjectSettings.globalize_path(resource_dir),
	}


func _resolve_ffmpeg_path(configured_ffmpeg: String) -> String:
	for candidate in _build_ffmpeg_candidates(configured_ffmpeg):
		if _can_execute_ffmpeg(candidate):
			return candidate
	return ""


func _resolve_vorbis_encoder(ffmpeg_path: String) -> String:
	var output: Array = []
	var code: int = OS.execute(ffmpeg_path, PackedStringArray(["-encoders"]), output, true)
	if code != 0:
		return ""

	var encoders_text := " ".join(PackedStringArray(output)).to_lower()
	if " libvorbis " in (" " + encoders_text + " "):
		return "libvorbis"
	if " vorbis " in (" " + encoders_text + " "):
		return "vorbis"
	return ""


func _encoder_requires_strict_experimental(ffmpeg_path: String, encoder_name: String) -> bool:
	var output: Array = []
	var code: int = OS.execute(ffmpeg_path, PackedStringArray(["-h", "encoder=%s" % encoder_name]), output, true)
	if code != 0:
		return false

	var help_text := " ".join(PackedStringArray(output)).to_lower()
	return "capabilities: dr1 delay exp" in help_text or "capabilities: exp" in help_text


func _get_editor_settings() -> EditorSettings:
	if m_editor_interface != null:
		return m_editor_interface.get_editor_settings()
	return EditorInterface.get_editor_settings()


func _load_persisted_settings() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return

	var state_variant: Variant = editor_settings.get_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, {})
	if typeof(state_variant) != TYPE_DICTIONARY:
		return

	var state: Dictionary = state_variant
	m_ffmpeg_edit.text = str(state.get("ffmpeg_path", m_ffmpeg_edit.text))
	m_source_edit.text = str(state.get("source_dir", m_source_edit.text))
	m_target_edit.text = str(state.get("target_dir", m_target_edit.text))

	var quality_value: Variant = state.get("quality", m_quality_spin.value)
	if typeof(quality_value) in [TYPE_INT, TYPE_FLOAT]:
		m_quality_spin.value = clampf(float(quality_value), m_quality_spin.min_value, m_quality_spin.max_value)


func _save_persisted_settings() -> void:
	var editor_settings := _get_editor_settings()
	if editor_settings == null:
		return

	editor_settings.set_project_metadata(PROJECT_METADATA_SECTION, PROJECT_METADATA_KEY, {
		"ffmpeg_path": m_ffmpeg_edit.text,
		"source_dir": m_source_edit.text,
		"target_dir": m_target_edit.text,
		"quality": int(m_quality_spin.value),
	})


func _run_conversion_worker(job: Dictionary) -> void:
	var ffmpeg_path: String = job["ffmpeg_path"]
	var audio_encoder: String = job["audio_encoder"]
	var encoder_requires_experimental: bool = job["encoder_requires_experimental"]
	var quality: int = job["quality"]
	var abs_target: String = job["abs_target"]
	var mp3_files: PackedStringArray = job["mp3_files"]
	var success_count := 0
	var skipped_count := 0
	var fail_count := 0
	var total_count := mp3_files.size()
	var completed_count := 0

	for mp3_path in mp3_files:
		var stem: String = mp3_path.get_file().get_basename()
		var ogg_path: String = abs_target.path_join(stem + ".ogg")
		_enqueue_worker_event({
			"type": "file_started",
			"file_name": mp3_path.get_file(),
			"completed_count": completed_count,
			"total_count": total_count,
		})

		if FileAccess.file_exists(ogg_path):
			skipped_count += 1
			completed_count += 1
			_enqueue_worker_event({
				"type": "file_skipped",
				"file_name": mp3_path.get_file(),
				"stem": stem,
				"completed_count": completed_count,
				"total_count": total_count,
				"success_count": success_count,
				"skipped_count": skipped_count,
				"fail_count": fail_count,
			})
			continue

		var args: PackedStringArray = PackedStringArray([
			"-y",
			"-i", mp3_path,
			"-vn",
			"-codec:a", audio_encoder,
		])
		if encoder_requires_experimental:
			args.append_array(PackedStringArray(["-strict", "-2"]))
		args.append_array(PackedStringArray([
			"-q:a", str(quality),
			ogg_path,
		]))

		var output: Array = []
		var exit_code: int = OS.execute(ffmpeg_path, args, output, true)
		var err_text: String = " ".join(PackedStringArray(output)).strip_edges()
		completed_count += 1

		if exit_code == 0:
			success_count += 1
		else:
			fail_count += 1

		_enqueue_worker_event({
			"type": "file_finished",
			"file_name": mp3_path.get_file(),
			"stem": stem,
			"exit_code": exit_code,
			"output_text": err_text,
			"completed_count": completed_count,
			"total_count": total_count,
			"success_count": success_count,
			"skipped_count": skipped_count,
			"fail_count": fail_count,
		})

	_enqueue_worker_event({
		"type": "finished",
		"total_count": total_count,
		"success_count": success_count,
		"skipped_count": skipped_count,
		"fail_count": fail_count,
		"needs_rescan": success_count > 0,
	})


func _enqueue_worker_event(event: Dictionary) -> void:
	m_worker_mutex.lock()
	m_worker_events.append(event)
	m_worker_mutex.unlock()


func _drain_worker_events() -> bool:
	var events := _take_worker_events()
	if events.is_empty():
		return false

	for event in events:
		_handle_worker_event(event)
	return true


func _take_worker_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	m_worker_mutex.lock()
	events.assign(m_worker_events)
	m_worker_events.clear()
	m_worker_mutex.unlock()
	return events


func _handle_worker_event(event: Dictionary) -> void:
	var event_type: String = event.get("type", "")
	match event_type:
		"file_started":
			var started_completed: int = event.get("completed_count", 0)
			var started_total: int = event.get("total_count", 0)
			var started_file_name: String = event.get("file_name", "")
			m_progress_label.text = "Processing %d / %d: %s" % [started_completed + 1, started_total, started_file_name]
			_log_msg("  Processing: %s" % started_file_name)
		"file_skipped":
			var skipped_completed: int = event.get("completed_count", 0)
			var skipped_total: int = event.get("total_count", 0)
			var skipped_success: int = event.get("success_count", 0)
			var skipped_count: int = event.get("skipped_count", 0)
			var skipped_fail: int = event.get("fail_count", 0)
			var skipped_stem: String = event.get("stem", "")
			m_progress_bar.value = skipped_completed
			m_progress_label.text = "Completed %d / %d (ok=%d, skipped=%d, failed=%d)" % [skipped_completed, skipped_total, skipped_success, skipped_count, skipped_fail]
			_log_msg("    [color=yellow]SKIP existing: %s[/color]" % (skipped_stem + ".ogg"), "    SKIP existing: %s" % (skipped_stem + ".ogg"))
		"file_finished":
			var file_exit_code: int = event.get("exit_code", ERR_CANT_CREATE)
			var finished_completed: int = event.get("completed_count", 0)
			var finished_total: int = event.get("total_count", 0)
			var finished_success: int = event.get("success_count", 0)
			var finished_skipped: int = event.get("skipped_count", 0)
			var finished_fail: int = event.get("fail_count", 0)
			var finished_stem: String = event.get("stem", "")
			var output_text: String = event.get("output_text", "")
			m_progress_bar.value = finished_completed
			m_progress_label.text = "Completed %d / %d (ok=%d, skipped=%d, failed=%d)" % [finished_completed, finished_total, finished_success, finished_skipped, finished_fail]
			if file_exit_code == 0:
				_log_msg("    [color=green]OK: %s[/color]" % (finished_stem + ".ogg"), "    OK: %s" % (finished_stem + ".ogg"))
			else:
				_log_msg("    [color=red]FAIL exit code %d[/color]" % file_exit_code, "    FAIL exit code %d" % file_exit_code)
				if not output_text.is_empty():
					_log_msg("    %s" % output_text)
		"finished":
			var final_total: int = event.get("total_count", 0)
			var final_success: int = event.get("success_count", 0)
			var final_skipped: int = event.get("skipped_count", 0)
			var final_fail: int = event.get("fail_count", 0)
			m_rescan_requested = event.get("needs_rescan", false)
			m_progress_bar.value = final_total
			m_progress_label.text = "Done: ok=%d, skipped=%d, failed=%d" % [final_success, final_skipped, final_fail]
			_log_msg("")
			_log_msg("[b]Done.[/b]  success=%d  skipped=%d  failed=%d" % [final_success, final_skipped, final_fail], "Done. success=%d skipped=%d failed=%d" % [final_success, final_skipped, final_fail])


func _start_conversion_run(total_count: int) -> void:
	m_conversion_running = true
	_set_conversion_controls_enabled(false)
	m_progress_label.text = "Preparing conversion..."
	m_progress_bar.max_value = max(total_count, 1)
	m_progress_bar.value = 0


func _finish_conversion_run() -> void:
	m_conversion_running = false
	_set_conversion_controls_enabled(true)

	if m_rescan_requested:
		if Engine.is_editor_hint() and m_editor_interface != null:
			m_editor_interface.get_resource_filesystem().scan()
			_log_msg("Editor filesystem rescanned.")
		elif Engine.is_editor_hint():
			_log_msg("[color=yellow]Warning: editor interface unavailable, so the filesystem was not rescanned automatically.[/color]", "Warning: editor interface unavailable, so the filesystem was not rescanned automatically.")
	m_rescan_requested = false


func _set_conversion_controls_enabled(enabled: bool) -> void:
	m_ffmpeg_edit.editable = enabled
	m_ffmpeg_browse.disabled = not enabled
	m_source_edit.editable = enabled
	m_source_browse.disabled = not enabled
	m_target_edit.editable = enabled
	m_target_browse.disabled = not enabled
	m_quality_spin.editable = enabled
	m_convert_btn.disabled = not enabled
	_refresh_copy_button()


func _wait_for_worker_thread() -> void:
	if m_worker_thread == null:
		return
	if m_worker_thread.is_started():
		m_worker_thread.wait_to_finish()
	m_worker_thread = null


func _build_ffmpeg_candidates(configured_ffmpeg: String) -> PackedStringArray:
	var candidates := PackedStringArray()
	var seen := {}
	var exe_name := "ffmpeg.exe" if OS.has_feature("windows") else "ffmpeg"

	_append_candidate(candidates, seen, configured_ffmpeg)
	_append_candidate(candidates, seen, exe_name)

	for path_entry in _get_path_entries():
		_append_candidate(candidates, seen, path_entry.path_join(exe_name))

	var defaults := DEFAULT_FFMPEG_CANDIDATES_LINUX
	if OS.has_feature("macos"):
		defaults = DEFAULT_FFMPEG_CANDIDATES_MACOS
	elif OS.has_feature("windows"):
		defaults = DEFAULT_FFMPEG_CANDIDATES_WINDOWS

	for candidate in defaults:
		_append_candidate(candidates, seen, candidate)

	return candidates


func _append_candidate(candidates: PackedStringArray, seen: Dictionary, candidate: String) -> void:
	var trimmed := candidate.strip_edges()
	if trimmed.is_empty():
		return
	if seen.has(trimmed):
		return
	seen[trimmed] = true
	candidates.append(trimmed)


func _get_path_entries() -> PackedStringArray:
	var path_value := OS.get_environment("PATH").strip_edges()
	if path_value.is_empty():
		return PackedStringArray()

	var separator := ";" if OS.has_feature("windows") else ":"
	return PackedStringArray(path_value.split(separator, false))


func _can_execute_ffmpeg(candidate: String) -> bool:
	if candidate.contains("/") or candidate.contains("\\"):
		if not FileAccess.file_exists(candidate):
			return false

	var output: Array = []
	var code: int = OS.execute(candidate, PackedStringArray(["-version"]), output, true)
	return code == 0


func _log_msg(msg: String, plain_text: String = "") -> void:
	m_log_label.append_text(msg + "\n")
	m_log_output_lines.append(plain_text if not plain_text.is_empty() else msg)
	_refresh_copy_button()


func _get_log_output_text() -> String:
	return "\n".join(m_log_output_lines)


func _refresh_copy_button() -> void:
	if m_copy_btn == null:
		return
	m_copy_btn.disabled = _get_log_output_text().is_empty()
