class_name LandmarkProgression
extends RefCounted

var m_owner: Node = null


func _init(owner: Node) -> void:
	m_owner = owner


func activate_landmark_trigger(
	_landmark_id: String,
	_trigger_id: String,
	_display_name: String
) -> bool:
	return false


func request_melody_prompt(
	melody_id: String,
	prompt_mode: String,
	completion_kind: String = "",
	request_overrides: Dictionary = {}
) -> void:
	var melody_definition: Dictionary = m_owner.get_melody_definition(melody_id)
	if melody_definition.is_empty():
		m_owner.set_save_status("The phrase slips away before it can be arranged.")
		return

	var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
	if melody_state.is_empty():
		m_owner.set_save_status("The phrase is not ready yet.")
		return

	var prompt_segments := build_melody_prompt_segments(melody_id)
	if prompt_segments.size() < 2:
		m_owner.set_save_status("Recover at least two steady phrase segments before arranging the melody.")
		return

	var melody_stage := String(melody_state.get("state", "unknown"))
	if melody_stage not in ["reconstructed", "performed", "resonant"]:
		m_owner.set_save_status("The phrase needs more shape before it can be rehearsed.")
		return

	var normalized_completion_kind := completion_kind
	if normalized_completion_kind.is_empty():
		normalized_completion_kind = "festival_performance" if prompt_mode == "performance" else "melody_practice"

	if prompt_mode == "performance" \
	and normalized_completion_kind == "festival_performance" \
	and !m_owner.can_perform_melody(melody_id):
		m_owner.set_save_status("The performance point is not ready to answer the melody yet.")
		return

	var expected_order: Array[String] = []
	for segment in prompt_segments:
		expected_order.append(String(segment.get("source_id", "")))

	var first_label := String(prompt_segments[0].get("label", "the opening phrase"))
	var display_name := String(melody_definition.get("display_name", melody_id))
	var prompt_title := "Practice %s" % display_name
	var prompt_body := "Arrange the phrase segments in the order that feels right. There is no penalty for trying again."
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
	m_owner._emit_melody_prompt_requested(request)


func build_melody_prompt_segments(melody_id: String) -> Array[Dictionary]:
	var melody_definition: Dictionary = m_owner.get_melody_definition(melody_id)
	var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
	if melody_definition.is_empty() or melody_state.is_empty():
		return []

	var known_sources := _normalize_string_array(melody_state.get("known_sources", []))
	var prompt_segments: Array[Dictionary] = []

	for source in melody_definition.get("sources", []):
		var source_id := String(source.get("source_id", ""))
		if source_id.is_empty():
			continue
		if !bool(source.get("counts_as_fragment", true)):
			continue
		if known_sources.find(source_id) < 0:
			continue

		prompt_segments.append({
			"source_id": source_id,
			"label": String(source.get("label", "Unknown phrase")),
			"landmark": String(source.get("landmark", "Unknown landmark")),
		})

	return prompt_segments


func complete_prompt_request(request: Dictionary) -> void:
	var completion_kind := String(request.get("completion_kind", ""))
	var melody_id := String(request.get("melody_id", ""))

	match completion_kind:
		"melody_practice":
			complete_melody_practice(melody_id)
		"festival_performance":
			complete_melody_performance(melody_id)
		_:
			m_owner.set_save_status("The phrase settles, but nothing answers it yet.")


func complete_melody_practice(melody_id: String) -> void:
	var melody_definition: Dictionary = m_owner.get_melody_definition(melody_id)
	if melody_definition.is_empty():
		m_owner.set_save_status("The phrase slips away before you can practice it.")
		return

	m_owner.set_save_status(
		"%s feels steadier after a short rehearsal." % String(melody_definition.get("display_name", "The melody"))
	)


func complete_melody_performance(melody_id: String) -> void:
	var melody_state: Dictionary = m_owner.get_melody_state(melody_id)
	if melody_state.is_empty():
		m_owner.set_save_status("The performance point is not ready yet.")
		return

	if bool(melody_state.get("performed", false)):
		m_owner.set_save_status("The harbor already remembers this melody.")
		return

	if !m_owner.can_perform_melody(melody_id):
		m_owner.set_save_status("The phrase is not ready to carry across the harbor yet.")
		return

	m_owner.set_save_status("This performance point is not wired yet.")


func resolve_landmark(_landmark_id: String) -> void:
	m_owner.set_save_status("This landmark reward is not wired yet.")


func _normalize_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []

	if value is PackedStringArray:
		for entry in value:
			output.append(String(entry))
		return output

	if value is Array:
		for entry in value:
			output.append(String(entry))

	return output
