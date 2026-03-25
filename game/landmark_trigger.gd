## LandmarkTrigger
##
## Place this node directly in a landmark scene to create an inspectable pickup.
## main.gd detects it via _get_landmark_trigger() and routes the R-inspect action
## to AppState.activate_landmark_trigger(). The trigger manages its own visibility
## by subscribing to AppState.landmark_progress_changed.
##
## Setup checklist when placing in a scene:
##   1. Set landmark_id to match the AppState landmark key (e.g. "trinity_church").
##   2. Set trigger_id to the per-landmark action key (e.g. "steps").
##   3. Set display_name to the speech-balloon and save-status label.
##   4. Set visible_in_states to the landmark states that should show this trigger.
##   5. If this trigger requires other triggers to be collected first, add their
##      trigger_ids to requires_collected and set collected_progress_key to the
##      progress dict key that tracks them (e.g. "echoes_collected").
##   6. If a progress flag should hide this trigger once set (e.g. "synthesis_done"),
##      set hide_if_flag to that key.
##   7. Add a CollisionShape2D child with a shape that covers the pickup area.
##   8. Set collision_layer to match the physics layer the player scans for
##      nearby interactables (same layer used by resident NPC areas).

@tool
class_name LandmarkTrigger
extends Area2D

## Must match the AppState.landmark_progress key for this landmark.
@export var landmark_id: String = ""

## Per-landmark action key — passed to AppState.activate_landmark_trigger.
@export var trigger_id: String = ""

## Label shown in the inspect prompt and save-status line.
@export var display_name: String = "Inspect"

## Landmark states in which this trigger should be visible.
## Common values: "available", "introduced", "in_progress".
@export var visible_in_states: Array[String] = []

## Progress dict key whose array is checked for requires_collected.
## Set to e.g. "echoes_collected" or "cues_collected" when requires_collected is used.
@export var collected_progress_key: String = ""

## All of these trigger_ids must already be in progress[collected_progress_key]
## before this trigger becomes visible. Leave empty for no prerequisite.
@export var requires_collected: Array[String] = []

## If non-empty, hide this trigger when progress[hide_if_flag] is truthy.
@export var hide_if_flag: String = ""

var _collected: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_sync_visibility()
	AppState.landmark_progress_changed.connect(_on_landmark_progress_changed)


func is_collected() -> bool:
	return _collected


## Mark this trigger as collected, hide it, and disable its collision.
## Safe to call multiple times; subsequent calls are no-ops.
func collect() -> void:
	if _collected:
		return
	_collected = true
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	for child in get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape != null:
			collision_shape.set_deferred("disabled", true)


func _on_landmark_progress_changed(changed_id: String, progress: Dictionary) -> void:
	if changed_id != landmark_id:
		return
	_apply_progress(progress)


func _sync_visibility() -> void:
	var progress := AppState.get_landmark_progress(landmark_id)
	_apply_progress(progress)


func _apply_progress(progress: Dictionary) -> void:
	if _collected:
		visible = false
		return

	var state := String(progress.get("state", "locked"))

	# Arc fully done — hide everything.
	if state in ["resolved", "reward_collected"]:
		visible = false
		return

	# Rule 1: state must be in the allowed list.
	if state not in visible_in_states:
		visible = false
		return

	# Rule 2: all required collected ids must be present.
	if !requires_collected.is_empty():
		var collected: Array[String] = []
		for entry in progress.get(collected_progress_key, []):
			collected.append(String(entry))
		for req_id in requires_collected:
			if collected.find(req_id) < 0:
				visible = false
				return

	# Rule 3: hide_if_flag must be absent or falsy.
	if !hide_if_flag.is_empty() and bool(progress.get(hide_if_flag, false)):
		visible = false
		return

	visible = true
