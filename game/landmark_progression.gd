class_name LandmarkProgression
extends RefCounted


func build_melody_prompt_result(
	melody_id: String,
	prompt_mode: String,
	completion_kind: String,
	request_overrides: Dictionary,
	melody_definition: Dictionary,
	melody_state: Dictionary,
	can_perform: bool
) -> Dictionary:
	if melody_definition.is_empty():
		return {"status": "The phrase slips away before it can be arranged."}
	if melody_state.is_empty():
		return {"status": "The phrase is not ready yet."}

	var prompt_segments := build_melody_prompt_segments(melody_definition, melody_state)
	if prompt_segments.size() < 2:
		return {
			"status": "Recover at least two steady phrase segments before arranging the melody."
		}

	var melody_stage := String(melody_state.get("state", "unknown"))
	if melody_stage not in ["reconstructed", "performed", "resonant"]:
		return {"status": "The phrase needs more shape before it can be rehearsed."}

	var normalized_completion_kind := completion_kind
	if normalized_completion_kind.is_empty():
		normalized_completion_kind = (
			"festival_performance" if prompt_mode == "performance" else "melody_practice"
		)

	if prompt_mode == "performance" \
	and normalized_completion_kind == "festival_performance" \
	and !can_perform:
		return {"status": "The performance point is not ready to answer the melody yet."}

	var expected_order: Array[String] = []
	for segment in prompt_segments:
		expected_order.append(String(segment.get("source_id", "")))

	var first_label := String(prompt_segments[0].get("label", "the opening phrase"))
	var display_name := String(melody_definition.get("display_name", melody_id))
	var prompt_title := "Practice %s" % display_name
	var prompt_body := (
		"Arrange the phrase segments in the order that feels right. "
		+ "There is no penalty for trying again."
	)
	if prompt_mode == "performance":
		prompt_title = "Perform %s" % display_name
		prompt_body = String(melody_definition.get("performance_prompt", ""))

	var request := {
		"melody_id": melody_id,
		"mode": prompt_mode,
		"completion_kind": normalized_completion_kind,
		"title": prompt_title,
		"body": prompt_body,
		"segments": prompt_segments,
		"expected_order": expected_order,
		"retry_hint": "That contour felt off. Try beginning with %s." % first_label,
		"hint_text": "Choose the known phrase segments in order.",
	}
	request.merge(request_overrides, true)
	return {"request": request}


func build_melody_prompt_segments(
	melody_definition: Dictionary,
	melody_state: Dictionary
) -> Array[Dictionary]:
	if melody_definition.is_empty() or melody_state.is_empty():
		return []

	var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
	var prompt_segments: Array[Dictionary] = []
	for source in melody_definition.get("sources", []):
		var source_id := String(source.get("source_id", ""))
		if source_id.is_empty() or !bool(source.get("counts_as_fragment", true)):
			continue
		if known_sources.find(source_id) < 0:
			continue
		prompt_segments.append({
			"source_id": source_id,
			"label": String(source.get("label", "Unknown phrase")),
			"landmark": String(source.get("landmark", "Unknown landmark")),
		})
	return prompt_segments


func get_prompt_completion_status(request: Dictionary, melody_definition: Dictionary) -> String:
	var completion_kind := String(request.get("completion_kind", ""))
	match completion_kind:
		"melody_practice":
			return get_melody_practice_status(melody_definition)
		"festival_performance":
			return "This performance point is not wired yet."
		_:
			return "The phrase settles, but nothing answers it yet."


func get_melody_practice_status(melody_definition: Dictionary) -> String:
	if melody_definition.is_empty():
		return "The phrase slips away before you can practice it."
	return "%s feels steadier after a short rehearsal." % String(
		melody_definition.get("display_name", "The melody")
	)


func get_melody_performance_status(melody_state: Dictionary, can_perform: bool) -> String:
	if melody_state.is_empty():
		return "The performance point is not ready yet."
	if bool(melody_state.get("performed", false)):
		return "The harbor already remembers this melody."
	if !can_perform:
		return "The phrase is not ready to carry across the harbor yet."
	return "This performance point is not wired yet."


func _normalize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
	elif value is Array:
		for entry in value:
			output.append(String(entry))
	return output
