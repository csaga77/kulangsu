extends Node

const RESIDENT_CATALOG_SCRIPT := preload("res://game/resident_catalog.gd")

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var merged := RESIDENT_CATALOG_SCRIPT.build_definitions()
	var merged_defaults := RESIDENT_CATALOG_SCRIPT.build_defaults()

	_assert_external_definition_loaded(
		"ticket_clerk_min",
		"res://game/residents/definitions/ticket_clerk_min.tres",
		merged,
		merged_defaults
	)
	_assert_external_definition_loaded(
		"terrace_painter_nian",
		"res://game/residents/definitions/terrace_painter_nian.tres",
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


func _assert_external_definition_loaded(
	resident_id: String,
	expected_path: String,
	merged: Dictionary,
	merged_defaults: Dictionary
) -> void:
	var definition = merged.get(resident_id)
	_assert_true(definition != null, "%s external definition loads into the merged catalog" % resident_id)
	if definition == null:
		return

	_assert_true(
		String(definition.resource_path) == expected_path,
		"%s merged definition comes from the external resource" % resident_id
	)
	_assert_true(
		merged_defaults.get(resident_id, {}) == definition.to_runtime_profile(),
		"%s default runtime profile matches its external definition" % resident_id
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
