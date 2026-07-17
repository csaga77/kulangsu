class_name AppStateTransition
extends RefCounted

var next_snapshot: AppStateSnapshot
var changes := AppStateChangeSet.new()
var events: Array[Dictionary] = []
var autosave_requested := false
var result: Variant = null


func _init(snapshot: AppStateSnapshot) -> void:
	next_snapshot = snapshot.duplicate_state()


func queue_event(kind: StringName, payload: Dictionary = {}) -> void:
	events.append({
		"kind": kind,
		"payload": payload.duplicate(true),
	})


func request_autosave() -> void:
	autosave_requested = true
