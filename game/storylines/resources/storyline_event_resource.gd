@tool
class_name StorylineEventResource
extends Resource
## Typed, inspector-editable definition of a single storyline event (beat).
##
## Create a .tres file of this type under game/storylines/routes/ (inside the
## owning [StorylineRouteResource]) to author events without hand-editing
## GDScript dictionaries. All fields map 1-to-1 to the existing runtime
## dictionary schema so [StorylineCatalog] can convert them transparently.
##
## Validation: call [method validate] from the inspector plugin or the route
## browser to surface duplicate-id, empty-field, and bad-phase-window errors.

## Valid season phase identifiers accepted by the runtime.
const VALID_PHASES := [
	"summer_1", "autumn_study", "winter", "spring_festival", "summer_2",
]

## Stable event identifier — must be unique across the entire project.
@export var id: String = ""

# --- Narrative text ----------------------------------------------------------

## Short player-facing hint shown as the journal lead for this event.
@export_multiline var lead_text: String = ""
## Longer journal entry shown once the event resolves.
@export_multiline var journal_note: String = ""
## One-line past-tense summary shown in the milestone feed.
@export_multiline var status_text: String = ""

# --- Progression metadata ----------------------------------------------------

## Which season phases this event is active in.
## Valid values: summer_1 · autumn_study · winter · spring_festival · summer_2
@export var phase_window: PackedStringArray = PackedStringArray()
## If set, this event is only offered once the season reaches this phase.
@export_enum("summer_1", "autumn_study", "winter", "spring_festival", "summer_2")
var season_phase: String = ""

## Weight used to rank this event as the pinned HUD lead.
@export var pin_priority: int = 0
## Points added to the route completion score when this event resolves.
@export var completion_score: int = 1

# --- Prerequisites -----------------------------------------------------------

## Every flag in this list must be set for the event to become available.
## Values are event ids from any route (cross-route dependencies are allowed).
@export var story_flags_all: PackedStringArray = PackedStringArray()
## At least one flag in this list must be set (ignored when empty).
@export var story_flags_any: PackedStringArray = PackedStringArray()
## Optional landmark-state gate: { landmark_id: required_state }.
## Supported states: locked · available · introduced · in_progress · resolved · reward_collected
@export var landmark_state: Dictionary = {}
## Optional melody-state gate: { melody_id: required_state }.
@export var melody_state: Dictionary = {}
## Optional resident-knowledge gate: every listed resident must already be known.
@export var resident_known: PackedStringArray = PackedStringArray()
## Optional route-score gate: { route_id: minimum_completion_score }.
@export var route_score_min: Dictionary = {}

# --- Ending / endgame --------------------------------------------------------

## When set, completing this event triggers an endgame check with this id.
@export var endgame_trigger: String = ""
## "end_run" closes the current run; "continue_story" opens the ending overlay
## but allows continued play afterward.
@export_enum("end_run", "continue_story") var ending_behavior: String = ""
## Closing copy shown on the departure / ending overlay.
@export_multiline var closing_label: String = ""
## Tone tags fed into the ending-tone assembly.
@export var tone_tags: PackedStringArray = PackedStringArray()


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

## Returns a plain Dictionary matching the runtime format expected by
## [StorylineCatalog], [StoryRouteGraph], and the journal builder.
func to_dict() -> Dictionary:
	var d: Dictionary = {
		"id":               id,
		"lead_text":        lead_text,
		"journal_note":     journal_note,
		"status_text":      status_text,
		"phase_window":     Array(phase_window),
		"pin_priority":     pin_priority,
		"completion_score": completion_score,
	}
	if not season_phase.is_empty():
		d["season_phase"] = season_phase

	# Prerequisites — only emit non-empty entries.
	var prereqs: Dictionary = {}
	if story_flags_all.size() > 0:
		prereqs["story_flags_all"] = Array(story_flags_all)
	if story_flags_any.size() > 0:
		prereqs["story_flags_any"] = Array(story_flags_any)
	if not landmark_state.is_empty():
		prereqs["landmark_state"] = landmark_state.duplicate()
	if not melody_state.is_empty():
		prereqs["melody_state"] = melody_state.duplicate()
	if resident_known.size() > 0:
		prereqs["resident_known"] = Array(resident_known)
	if not route_score_min.is_empty():
		prereqs["route_score_min"] = route_score_min.duplicate()
	if not prereqs.is_empty():
		d["prerequisites"] = prereqs

	if not endgame_trigger.is_empty():
		d["endgame_trigger"] = endgame_trigger
	if not ending_behavior.is_empty():
		d["ending_behavior"] = ending_behavior
	if not closing_label.is_empty():
		d["closing_label"] = closing_label
	if tone_tags.size() > 0:
		d["tone_tags"] = Array(tone_tags)

	return d


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Returns a list of human-readable warnings about this event.
## Called by the inspector plugin and the route browser.
func validate() -> PackedStringArray:
	var warnings := PackedStringArray()

	if id.strip_edges().is_empty():
		warnings.append("id is empty — every event must have a unique stable id")

	if lead_text.strip_edges().is_empty():
		warnings.append("[%s] lead_text is empty" % id)

	if phase_window.is_empty():
		warnings.append("[%s] phase_window is empty — event will never become available" % id)
	else:
		for phase: String in phase_window:
			if not VALID_PHASES.has(phase):
				warnings.append("[%s] unknown phase_window value: '%s'" % [id, phase])

	if not season_phase.is_empty() and not VALID_PHASES.has(season_phase):
		warnings.append("[%s] unknown season_phase: '%s'" % [id, season_phase])

	if not endgame_trigger.is_empty() and ending_behavior.is_empty():
		warnings.append(
			"[%s] has endgame_trigger but no ending_behavior — set 'end_run' or 'continue_story'"
			% id
		)

	return warnings


## Builds a typed event resource from the runtime Dictionary format.
static func from_dict(value: Dictionary) -> StorylineEventResource:
	var event := StorylineEventResource.new()
	event.id = String(value.get("id", "")).strip_edges()
	event.lead_text = String(value.get("lead_text", ""))
	event.journal_note = String(value.get("journal_note", ""))
	event.status_text = String(value.get("status_text", ""))
	event.phase_window = _to_packed_string_array(value.get("phase_window", []))
	event.season_phase = String(value.get("season_phase", "")).strip_edges()
	event.pin_priority = int(value.get("pin_priority", 0))
	event.completion_score = int(value.get("completion_score", 1))

	var prereq_value = value.get("prerequisites", {})
	var prereq_dict: Dictionary = {}
	if prereq_value is Dictionary:
		prereq_dict = (prereq_value as Dictionary).duplicate(true)

	event.story_flags_all = _to_packed_string_array(prereq_dict.get("story_flags_all", []))
	event.story_flags_any = _to_packed_string_array(prereq_dict.get("story_flags_any", []))
	event.landmark_state = _to_dictionary(prereq_dict.get("landmark_state", {}))
	event.melody_state = _to_dictionary(prereq_dict.get("melody_state", {}))
	event.resident_known = _to_packed_string_array(prereq_dict.get("resident_known", []))
	event.route_score_min = _to_dictionary(prereq_dict.get("route_score_min", {}))

	event.endgame_trigger = String(value.get("endgame_trigger", "")).strip_edges()
	event.ending_behavior = String(value.get("ending_behavior", "")).strip_edges()
	event.closing_label = String(value.get("closing_label", ""))
	event.tone_tags = _to_packed_string_array(value.get("tone_tags", []))
	return event


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray:
		return value
	if value is Array:
		for item in value as Array:
			var text := String(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


static func _to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
