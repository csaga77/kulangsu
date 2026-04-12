extends Node2D

const RESIDENT_CATALOG_SCRIPT := preload("res://game/resident_catalog.gd")

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var builtins := RESIDENT_CATALOG_SCRIPT.build_builtin_definitions()
	var merged := RESIDENT_CATALOG_SCRIPT.build_definitions()
	var merged_defaults := RESIDENT_CATALOG_SCRIPT.build_defaults()

	_assert_true(builtins.has("ticket_clerk_min"), "Built-in resident catalog still contains Ticket Clerk Min")
	_assert_true(builtins.has("terrace_painter_nian"), "Built-in resident catalog still contains Terrace Painter Nian")

	_assert_override_matches_baseline(
		"ticket_clerk_min",
		"res://game/residents/definitions/ticket_clerk_min.tres",
		builtins,
		merged,
		merged_defaults
	)
	_assert_override_matches_baseline(
		"terrace_painter_nian",
		"res://game/residents/definitions/terrace_painter_nian.tres",
		builtins,
		merged,
		merged_defaults
	)

	if m_failures.is_empty():
		print("PASS: resident catalog external definitions")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Resident catalog external definitions failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_override_matches_baseline(
	resident_id: String,
	expected_path: String,
	builtins: Dictionary,
	merged: Dictionary,
	merged_defaults: Dictionary
) -> void:
	var baseline = builtins.get(resident_id)
	var override = merged.get(resident_id)
	_assert_true(override != null, "%s override loads into the merged catalog" % resident_id)
	if override == null or baseline == null:
		return

	_assert_true(
		String(override.resource_path) == expected_path,
		"%s merged definition comes from the external override resource" % resident_id
	)
	_assert_true(
		override.to_runtime_profile() == baseline.to_runtime_profile(),
		"%s override preserves the built-in runtime profile fields" % resident_id
	)
	_assert_true(
		merged_defaults.get(resident_id, {}) == baseline.to_runtime_profile(),
		"%s default runtime profile still matches the built-in baseline after the override merge" % resident_id
	)
	_assert_true(
		RESIDENT_CATALOG_SCRIPT.resident_order().find(resident_id) >= 0,
		"%s remains in the catalog order after the override merge" % resident_id
	)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
