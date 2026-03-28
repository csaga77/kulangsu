@tool
extends Node

const UniversalLpcAssetAuditorScript = preload("res://characters/universal_lpc/universal_lpc_asset_auditor.gd")

@export_dir var universal_lpc_root: String = "res://3rdparty/Universal-LPC-Spritesheet-Character-Generator"
@export var sheet_definitions_dir: String = "sheet_definitions"
@export var spritesheets_dir: String = "spritesheets"
@export_file("*.md") var report_output_path: String = ""
@export_range(1, 200, 1) var max_entries_per_section: int = 20
@export var auto_run_when_played: bool = true
@export var quit_after_run: bool = true

var _last_report: Dictionary = {}
var _last_markdown: String = ""
var _last_summary: String = "Not run yet."


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not auto_run_when_played:
		return

	_run_asset_audit()
	if quit_after_run and get_tree() != null:
		get_tree().quit()


func _get_property_list() -> Array:
	return [
		{
			"name": "run_asset_audit",
			"type": TYPE_CALLABLE,
			"usage": PROPERTY_USAGE_EDITOR,
			"hint": PROPERTY_HINT_TOOL_BUTTON,
			"hint_string": "Run Asset Audit"
		},
		{
			"name": "last_summary",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		}
	]


func _get(property: StringName):
	if property == "run_asset_audit":
		return Callable(self, "_run_asset_audit")
	if property == "last_summary":
		return _last_summary
	return null


func _set(_property: StringName, _value) -> bool:
	return false


func _run_asset_audit() -> void:
	var auditor := UniversalLpcAssetAuditorScript.new()
	_last_report = auditor.audit(universal_lpc_root, sheet_definitions_dir, spritesheets_dir)
	_last_markdown = auditor.build_markdown_report(_last_report, max_entries_per_section)
	_last_summary = _build_summary_line(_last_report.get("summary", {}))
	notify_property_list_changed()

	print(_last_markdown)

	if report_output_path.strip_edges() != "":
		var save_err := _save_report(report_output_path, _last_markdown)
		if save_err == OK:
			print("[ULPC Audit] Report written to %s" % report_output_path)
		else:
			push_error("Failed to save audit report to %s error=%d" % [report_output_path, save_err])


func _build_summary_line(summary_value) -> String:
	if typeof(summary_value) != TYPE_DICTIONARY:
		return "Audit finished."

	var summary: Dictionary = summary_value
	return "Definitions=%d | Missing Rows=%d | JSON Gaps=%d | Player AI Targets=%d | Player Metadata Targets=%d" % [
		int(summary.get("definitions_scanned", 0)),
		int(summary.get("missing_source_row_definitions", 0)),
		int(summary.get("source_rows_not_declared_definitions", 0)),
		int(summary.get("player_ai_targets", 0)),
		int(summary.get("player_metadata_targets", 0)),
	]


func _save_report(path: String, text: String) -> int:
	var dir_path := path.get_base_dir()
	if dir_path != "":
		var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
		if dir_err != OK:
			return dir_err

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	file.store_string(text)
	return OK
