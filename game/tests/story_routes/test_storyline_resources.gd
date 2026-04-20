extends Node

const ENDING_TONE_RULE_SCRIPT := preload("res://game/storylines/resources/storyline_ending_tone_rule.gd")
const EVENT_RESOURCE_SCRIPT := preload("res://game/storylines/resources/storyline_event_resource.gd")
const ROUTE_RESOURCE_SCRIPT := preload("res://game/storylines/resources/storyline_route_resource.gd")

var m_failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var tone_rule: StorylineEndingToneRule = ENDING_TONE_RULE_SCRIPT.new()
	tone_rule.min_score = 2
	tone_rule.tag = "continuity"
	tone_rule.helped_residents_min = 3
	tone_rule.max_trust_residents_min = 1

	var anchor_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	anchor_event.id = "typed_resource_anchor"
	anchor_event.lead_text = "Anchor the typed resource route."
	anchor_event.journal_note = "This event exists to anchor prerequisite references."
	anchor_event.status_text = "The typed resource anchor resolved."
	anchor_event.phase_window = PackedStringArray(["summer_1"])

	var soft_ending_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	soft_ending_event.id = "typed_resource_soft_ending"
	soft_ending_event.lead_text = "Close the typed resource route with a soft ending."
	soft_ending_event.journal_note = "The typed resource route carries the full prerequisite schema."
	soft_ending_event.status_text = "The typed resource route opened a continue-story ending."
	soft_ending_event.phase_window = PackedStringArray(["spring_festival"])
	soft_ending_event.story_flags_all = PackedStringArray(["typed_resource_anchor"])
	soft_ending_event.story_flags_any = PackedStringArray(["typed_resource_anchor"])
	soft_ending_event.landmark_state = {"bagua_tower": "available"}
	soft_ending_event.melody_state = {"trinity_church": "resolved"}
	soft_ending_event.resident_known = PackedStringArray(["ferry_caretaker"])
	soft_ending_event.route_score_min = {"family_memory": 2}
	soft_ending_event.endgame_trigger = "typed_resource_soft_ending"
	soft_ending_event.ending_behavior = "continue_story"
	soft_ending_event.closing_label = "The typed route can keep going after the ending overlay."
	soft_ending_event.tone_tags = PackedStringArray(["continuity"])

	var route_resource: StorylineRouteResource = ROUTE_RESOURCE_SCRIPT.new()
	route_resource.id = "typed_resource_route"
	route_resource.display_name = "Typed Resource Route"
	route_resource.journal_section = "Typed"
	route_resource.display_order = 90
	route_resource.pin_priority = 77
	route_resource.ending_tone_rules = [tone_rule]
	route_resource.events = [anchor_event, soft_ending_event]

	_assert_true(anchor_event.validate().is_empty(), "Anchor resource event validates cleanly")
	_assert_true(soft_ending_event.validate().is_empty(), "Soft-ending resource event validates cleanly")
	_assert_true(route_resource.validate().is_empty(), "Typed route resource validates cleanly")

	var storyline_dict: Dictionary = route_resource.to_storyline_dict("res://game/tests/story_routes/typed_resource_route.tres")
	var route_dict: Dictionary = storyline_dict.get("route", {})
	var event_dicts: Array = storyline_dict.get("events", [])
	_assert_true(event_dicts.size() == 2, "Typed route resource converts both events")
	_assert_true(String(route_dict.get("id", "")) == "typed_resource_route", "Route resource conversion preserves route id")
	_assert_true(int(route_dict.get("pin_priority", 0)) == 77, "Route resource conversion preserves pin priority")

	var tone_rules: Array = route_dict.get("ending_tone_rules", [])
	_assert_true(tone_rules.size() == 1, "Route conversion preserves ending tone rules")
	if !tone_rules.is_empty():
		var tone_rule_dict: Dictionary = tone_rules[0]
		_assert_true(int(tone_rule_dict.get("helped_residents_min", -1)) == 3, "Ending tone rule preserves helped-resident gate")
		_assert_true(int(tone_rule_dict.get("max_trust_residents_min", -1)) == 1, "Ending tone rule preserves max-trust gate")

	var converted_soft_ending: Dictionary = event_dicts[1]
	var prerequisites: Dictionary = converted_soft_ending.get("prerequisites", {})
	_assert_true(String(converted_soft_ending.get("ending_behavior", "")) == "continue_story", "Event conversion preserves continue-story endings")
	_assert_true((prerequisites.get("melody_state", {}) as Dictionary).get("trinity_church", "") == "resolved", "Event conversion preserves melody-state prerequisites")
	_assert_true(
		PackedStringArray(prerequisites.get("resident_known", [])).find("ferry_caretaker") >= 0,
		"Event conversion preserves resident-known prerequisites"
	)
	_assert_true(
		int((prerequisites.get("route_score_min", {}) as Dictionary).get("family_memory", 0)) == 2,
		"Event conversion preserves route-score prerequisites"
	)

	var reconstructed_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.from_dict(converted_soft_ending)
	_assert_true(
		reconstructed_event.story_flags_all.has("typed_resource_anchor"),
		"Event resource reconstruction preserves hard prerequisite flags"
	)
	_assert_true(
		reconstructed_event.route_score_min.get("family_memory", 0) == 2,
		"Event resource reconstruction preserves route-score gates"
	)
	_assert_true(
		reconstructed_event.ending_behavior == "continue_story",
		"Event resource reconstruction preserves ending behavior"
	)

	var reconstructed_route: StorylineRouteResource = ROUTE_RESOURCE_SCRIPT.from_storyline_dict(storyline_dict)
	_assert_true(
		reconstructed_route.ending_tone_rules.size() == 1,
		"Route resource reconstruction preserves ending-tone rule count"
	)
	_assert_true(
		reconstructed_route.events.size() == 2,
		"Route resource reconstruction preserves event count"
	)
	if reconstructed_route.ending_tone_rules.size() == 1:
		var reconstructed_rule := reconstructed_route.ending_tone_rules[0]
		_assert_true(
			reconstructed_rule.max_trust_residents_min == 1,
			"Route resource reconstruction preserves max-trust tone gates"
		)
	if reconstructed_route.events.size() == 2:
		var reconstructed_soft_event := reconstructed_route.events[1]
		_assert_true(
			reconstructed_soft_event.melody_state.get("trinity_church", "") == "resolved",
			"Route resource reconstruction preserves melody-state prerequisites"
		)
		_assert_true(
			reconstructed_soft_event.route_score_min.get("family_memory", 0) == 2,
			"Route resource reconstruction preserves nested event prerequisites"
		)

	if m_failures.is_empty():
		print("PASS: storyline resource schema")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error("Storyline resource schema failed with %d issue(s)." % m_failures.size())

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
