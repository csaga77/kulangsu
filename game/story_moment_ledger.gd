class_name StoryMomentLedger
extends RefCounted

const DEFINITIONS: Array[Dictionary] = [{
	"id": "family_household_care",
	"route_id": "family_memory",
	"completed_event_id": "family_household_care_seen",
	"missed_fact_id": "family_household_care_missed",
	"opener_event_id": "winter_memory_reveal",
	"phase_id": "winter",
	"closer_event_id": "spring_festival_prepared",
}]


static func definitions() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for definition in DEFINITIONS:
		output.append(definition.duplicate(true))
	return output


static func definition_for_moment(moment_id: String) -> Dictionary:
	var normalized_id := moment_id.strip_edges()
	for definition in DEFINITIONS:
		if String(definition.get("id", "")) == normalized_id:
			return definition.duplicate(true)
	return {}


static func definition_for_completed_event(event_id: String) -> Dictionary:
	var normalized_id := event_id.strip_edges()
	for definition in DEFINITIONS:
		if String(definition.get("completed_event_id", "")) == normalized_id:
			return definition.duplicate(true)
	return {}


static func add_default_flags(flags: Dictionary) -> Dictionary:
	var output := flags.duplicate(true)
	for definition in DEFINITIONS:
		var completed_event_id := String(definition.get("completed_event_id", ""))
		var missed_fact_id := String(definition.get("missed_fact_id", ""))
		if !output.has(completed_event_id):
			output[completed_event_id] = false
		if !output.has(missed_fact_id):
			output[missed_fact_id] = false
	return output


static func normalize_story_flags(
	working_flags: Dictionary,
	base_flags: Dictionary = {}
) -> Dictionary:
	var output := working_flags.duplicate(true)
	for definition in DEFINITIONS:
		var completed_event_id := String(definition.get("completed_event_id", ""))
		var missed_fact_id := String(definition.get("missed_fact_id", ""))
		var closer_event_id := String(definition.get("closer_event_id", ""))
		var base_completed := bool(base_flags.get(completed_event_id, false))
		var base_missed := bool(base_flags.get(missed_fact_id, false))
		var working_completed := bool(output.get(completed_event_id, false))
		var working_missed := bool(output.get(missed_fact_id, false))

		if base_completed:
			output[completed_event_id] = true
			output[missed_fact_id] = false
		elif base_missed:
			output[completed_event_id] = false
			output[missed_fact_id] = true
		elif working_completed:
			# Completion wins when malformed data or one detached command
			# produces both outcomes without a previously committed result.
			output[completed_event_id] = true
			output[missed_fact_id] = false
		elif working_missed:
			output[completed_event_id] = false
			output[missed_fact_id] = true
		elif bool(output.get(closer_event_id, false)):
			output[completed_event_id] = false
			output[missed_fact_id] = true
		else:
			output[completed_event_id] = false
			output[missed_fact_id] = false
	return output


static func missed_fact_id_for_completed_event(event_id: String) -> String:
	return String(
		definition_for_completed_event(event_id).get("missed_fact_id", "")
	)


static func is_completed_event_missed(event_id: String, flags: Dictionary) -> bool:
	var missed_fact_id := missed_fact_id_for_completed_event(event_id)
	return !missed_fact_id.is_empty() and bool(flags.get(missed_fact_id, false))
