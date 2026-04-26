extends Node

const ENDING_TONE_RULE_SCRIPT := preload("res://game/storylines/resources/storyline_ending_tone_rule.gd")
const EVENT_RESOURCE_SCRIPT := preload("res://game/storylines/resources/storyline_event_resource.gd")
const ROUTE_RESOURCE_SCRIPT := preload("res://game/storylines/resources/storyline_route_resource.gd")
const STORY_SEASON_PHASES_SCRIPT := preload("res://game/story_season_phases.gd")
const STORYLINE_EDITOR_PLUGIN_SCRIPT := preload("res://addons/storyline_editor/plugin.gd")
const INSPECTOR_PLUGIN_SCRIPT := preload("res://addons/storyline_editor/storyline_validator_inspector_plugin.gd")
const VALIDATION_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_validation_panel.gd"
)
const INSPECTOR_STATUS_BRIDGE_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_inspector_status_bridge.gd"
)
const PREREQUISITE_PICKER_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_prerequisite_picker_panel.gd"
)
const PHASE_WINDOW_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_phase_window_panel.gd"
)
const ROUTE_EVENT_PANEL_SCRIPT := preload(
	"res://addons/storyline_editor/storyline_route_event_panel.gd"
)

var m_failures := PackedStringArray()
var m_catalog_refresh_requests: int = 0


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
	anchor_event.phase_window = ["summer_1"]

	var soft_ending_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	soft_ending_event.id = "typed_resource_soft_ending"
	soft_ending_event.lead_text = "Close the typed resource route with a soft ending."
	soft_ending_event.journal_note = "The typed resource route carries the full prerequisite schema."
	soft_ending_event.status_text = "The typed resource route opened a continue-story ending."
	soft_ending_event.phase_window = ["spring_festival"]
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

	var cross_route_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	cross_route_event.id = "typed_resource_cross_route"
	cross_route_event.lead_text = "Let another storyline answer this route."
	cross_route_event.journal_note = "Cross-route prerequisites should not warn at the route level."
	cross_route_event.status_text = "A cross-route dependency connected cleanly."
	cross_route_event.phase_window = ["winter"]
	cross_route_event.story_flags_all = PackedStringArray(["winter_memory_reveal"])

	var route_resource: StorylineRouteResource = ROUTE_RESOURCE_SCRIPT.new()
	route_resource.id = "typed_resource_route"
	route_resource.display_name = "Typed Resource Route"
	route_resource.journal_section = "Typed"
	route_resource.display_order = 90
	route_resource.pin_priority = 77
	route_resource.ending_tone_rules = [tone_rule]
	route_resource.events = [anchor_event, soft_ending_event, cross_route_event]

	_assert_true(
		PackedStringArray(EVENT_RESOURCE_SCRIPT.VALID_PHASES) == STORY_SEASON_PHASES_SCRIPT.authorable_phase_ids(),
		"Storyline event resources reuse the canonical authorable season phase ids"
	)
	_assert_true(
		STORY_SEASON_PHASES_SCRIPT.display_name(STORY_SEASON_PHASES_SCRIPT.SPRING_FESTIVAL) == "Spring Festival / Spring",
		"Story season phase display names come from the canonical phase catalog"
	)

	_assert_true(anchor_event.validate().is_empty(), "Anchor resource event validates cleanly")
	_assert_true(soft_ending_event.validate().is_empty(), "Soft-ending resource event validates cleanly")
	_assert_true(cross_route_event.validate().is_empty(), "Cross-route resource event validates cleanly")
	_assert_true(route_resource.validate().is_empty(), "Typed route resource validates cleanly")

	var storyline_dict: Dictionary = route_resource.to_storyline_dict("res://game/tests/story_routes/typed_resource_route.tres")
	var route_dict: Dictionary = storyline_dict.get("route", {})
	var event_dicts: Array = storyline_dict.get("events", [])
	_assert_true(event_dicts.size() == 3, "Typed route resource converts all events")
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
		reconstructed_route.events.size() == 3,
		"Route resource reconstruction preserves event count"
	)
	if reconstructed_route.ending_tone_rules.size() == 1:
		var reconstructed_rule := reconstructed_route.ending_tone_rules[0]
		_assert_true(
			reconstructed_rule.max_trust_residents_min == 1,
			"Route resource reconstruction preserves max-trust tone gates"
		)
	if reconstructed_route.events.size() == 3:
		var reconstructed_soft_event := reconstructed_route.events[1]
		_assert_true(
			reconstructed_soft_event.melody_state.get("trinity_church", "") == "resolved",
			"Route resource reconstruction preserves melody-state prerequisites"
		)
		_assert_true(
			reconstructed_soft_event.route_score_min.get("family_memory", 0) == 2,
			"Route resource reconstruction preserves nested event prerequisites"
		)
		var reconstructed_cross_route_event := reconstructed_route.events[2]
		_assert_true(
			reconstructed_cross_route_event.story_flags_all.has("winter_memory_reveal"),
			"Route resource reconstruction preserves cross-route prerequisite flags"
		)

	_assert_true(
		STORYLINE_EDITOR_PLUGIN_SCRIPT != null,
		"Storyline editor plugin script loads for editor startup checks"
	)
	_assert_true(
		INSPECTOR_PLUGIN_SCRIPT != null,
		"Storyline inspector plugin script loads for editor tooling checks"
	)
	_assert_true(
		VALIDATION_PANEL_SCRIPT != null,
		"Storyline validation panel script loads for editor tooling checks"
	)
	_assert_true(
		INSPECTOR_STATUS_BRIDGE_SCRIPT != null,
		"Storyline inspector status bridge script loads for editor tooling checks"
	)
	_assert_true(
		ROUTE_EVENT_PANEL_SCRIPT != null,
		"Storyline route event panel script loads for editor tooling checks"
	)
	_assert_true(
		PREREQUISITE_PICKER_PANEL_SCRIPT != null,
		"Storyline prerequisite picker panel script loads for editor tooling checks"
	)
	_assert_true(
		PHASE_WINDOW_PANEL_SCRIPT != null,
		"Storyline phase window panel script loads for editor tooling checks"
	)

	var property_list := anchor_event.get_property_list()
	var phase_window_property: Dictionary = {}
	var season_phase_property: Dictionary = {}
	for property_def_var in property_list:
		if not (property_def_var is Dictionary):
			continue
		var property_def := property_def_var as Dictionary
		match String(property_def.get("name", "")):
			"phase_window":
				phase_window_property = property_def
			"season_phase":
				season_phase_property = property_def
	_assert_true(
		int(phase_window_property.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_TYPE_STRING,
		"Storyline phase_window uses typed-array inspector hints"
	)
	_assert_true(
		String(phase_window_property.get("hint_string", "")) == "%d/%d:%s" % [
			TYPE_STRING,
			PROPERTY_HINT_ENUM,
			STORY_SEASON_PHASES_SCRIPT.AUTHORABLE_PHASE_HINT,
		],
		"Storyline phase_window exposes the canonical season phase picker for each array element"
	)
	anchor_event.phase_window = [
		STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
		STORY_SEASON_PHASES_SCRIPT.WINTER,
		STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
		"",
		STORY_SEASON_PHASES_SCRIPT.WINTER,
	]
	_assert_true(
		anchor_event.phase_window == [
			STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
			STORY_SEASON_PHASES_SCRIPT.WINTER,
			STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
			"",
			STORY_SEASON_PHASES_SCRIPT.WINTER,
		],
		"Storyline phase_window stays a native editable array before normalization"
	)
	_assert_true(
		anchor_event.normalize_phase_window(),
		"Storyline events can normalize duplicate phase_window entries on demand"
	)
	_assert_true(
		anchor_event.phase_window == [
			STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
			STORY_SEASON_PHASES_SCRIPT.WINTER,
		],
		"Storyline phase_window normalization removes duplicate and empty entries while preserving order"
	)
	var serialized_phase_event := EVENT_RESOURCE_SCRIPT.new()
	serialized_phase_event.id = "typed_serialized_phase_event"
	serialized_phase_event.lead_text = "Serialize deduped phases."
	serialized_phase_event.journal_note = "Serialized phase windows should not keep duplicates."
	serialized_phase_event.status_text = "Serialized phase window deduped."
	serialized_phase_event.phase_window = [
		STORY_SEASON_PHASES_SCRIPT.AUTUMN_STUDY,
		STORY_SEASON_PHASES_SCRIPT.AUTUMN_STUDY,
		STORY_SEASON_PHASES_SCRIPT.WINTER,
	]
	_assert_true(
		serialized_phase_event.to_dict().get("phase_window", []) == [
			STORY_SEASON_PHASES_SCRIPT.AUTUMN_STUDY,
			STORY_SEASON_PHASES_SCRIPT.WINTER,
		],
		"Storyline event serialization deduplicates repeated phase_window entries"
	)
	var deduped_event := EVENT_RESOURCE_SCRIPT.from_dict({
		"id": "typed_deduped_phase_event",
		"lead_text": "Deduped phases",
		"journal_note": "Duplicate phases should collapse during reconstruction.",
		"status_text": "Deduped phase window loaded.",
		"phase_window": [
			STORY_SEASON_PHASES_SCRIPT.SPRING_FESTIVAL,
			STORY_SEASON_PHASES_SCRIPT.SPRING_FESTIVAL,
			STORY_SEASON_PHASES_SCRIPT.SUMMER_2,
		],
	})
	_assert_true(
		deduped_event.phase_window == [
			STORY_SEASON_PHASES_SCRIPT.SPRING_FESTIVAL,
			STORY_SEASON_PHASES_SCRIPT.SUMMER_2,
		],
		"Storyline event reconstruction deduplicates repeated phase_window entries"
	)
	_assert_true(
		int(season_phase_property.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_ENUM,
		"Storyline season_phase uses enum-backed inspector hints"
	)
	_assert_true(
		String(season_phase_property.get("hint_string", "")) == STORY_SEASON_PHASES_SCRIPT.AUTHORABLE_PHASE_HINT,
		"Storyline season_phase reuses the canonical season phase list in the inspector"
	)

	var phase_panel_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	phase_panel_event.id = "typed_phase_panel_event"
	phase_panel_event.lead_text = "Use the phase window picker."
	phase_panel_event.journal_note = "The phase window picker should filter already-selected phases."
	phase_panel_event.status_text = "Phase window picker state changed."
	phase_panel_event.phase_window = [
		STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
		STORY_SEASON_PHASES_SCRIPT.WINTER,
	]
	m_catalog_refresh_requests = 0

	var phase_window_panel = PHASE_WINDOW_PANEL_SCRIPT.new()
	phase_window_panel.setup(
		phase_panel_event,
		Callable(self, "_on_catalog_refresh_requested")
	)
	add_child(phase_window_panel)
	await get_tree().process_frame

	_assert_true(
		phase_window_panel.m_phase_rows != null,
		"Storyline phase window panel builds its phase list container"
	)
	_assert_true(
		phase_window_panel.m_add_button != null,
		"Storyline phase window panel builds its add button"
	)
	_assert_true(
		phase_window_panel.mouse_filter == Control.MOUSE_FILTER_PASS,
		"Storyline phase window panel passes mouse input through for inspector scrolling"
	)
	_assert_true(
		not phase_window_panel.m_add_button.disabled,
		"Storyline phase window panel allows adding phases while unused values remain"
	)
	if phase_window_panel.m_phase_rows != null and phase_window_panel.m_phase_rows.get_child_count() >= 2:
		var first_phase_row := phase_window_panel.m_phase_rows.get_child(0) as HBoxContainer
		var second_phase_row := phase_window_panel.m_phase_rows.get_child(1) as HBoxContainer
		_assert_true(
			first_phase_row != null and second_phase_row != null,
			"Storyline phase window panel rebuilds one row per selected phase"
		)
		if first_phase_row != null and first_phase_row.get_child_count() > 0:
			var first_phase_picker := first_phase_row.get_child(0) as OptionButton
			_assert_true(
				first_phase_picker != null,
				"Storyline phase window panel exposes a picker for each selected phase"
			)
			if first_phase_picker != null:
				var first_picker_options := _option_button_item_metadata(first_phase_picker)
				_assert_true(
					first_picker_options.has(STORY_SEASON_PHASES_SCRIPT.SUMMER_1),
					"Storyline phase window panel keeps the current phase available in its own picker"
				)
				_assert_true(
					not first_picker_options.has(STORY_SEASON_PHASES_SCRIPT.WINTER),
					"Storyline phase window panel hides phases already selected in other rows"
				)

	phase_window_panel._on_add_phase_pressed()
	phase_window_panel._on_add_phase_pressed()
	phase_window_panel._on_add_phase_pressed()
	_assert_true(
		phase_panel_event.phase_window == [
			STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
			STORY_SEASON_PHASES_SCRIPT.WINTER,
			STORY_SEASON_PHASES_SCRIPT.AUTUMN_STUDY,
			STORY_SEASON_PHASES_SCRIPT.SPRING_FESTIVAL,
			STORY_SEASON_PHASES_SCRIPT.SUMMER_2,
		],
		"Storyline phase window panel appends only unselected season phases"
	)
	await get_tree().process_frame
	_assert_true(
		m_catalog_refresh_requests == 3,
		"Storyline phase window panel requests shared refreshes after phase additions"
	)
	_assert_true(
		phase_window_panel.m_add_button.disabled,
		"Storyline phase window panel disables add once every season phase is selected"
	)
	phase_window_panel.queue_free()
	await get_tree().process_frame

	var id_route_resource: StorylineRouteResource = ROUTE_RESOURCE_SCRIPT.new()
	id_route_resource.id = "typed_resource_route"
	_assert_true(
		id_route_resource.next_default_event_id() == "typed_resource_route_new_event_1",
		"Route resources derive their first default event id from the route id"
	)
	var existing_default_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	existing_default_event.id = "typed_resource_route_new_event_1"
	id_route_resource.events = [existing_default_event]
	_assert_true(
		id_route_resource.next_default_event_id() == "typed_resource_route_new_event_2",
		"Route resources increment default event ids to keep them unique"
	)

	var validation_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	validation_event.id = "typed_validation_event"
	validation_event.lead_text = "Track validation refresh state."
	validation_event.journal_note = "The validation panel should refresh after resource edits."
	validation_event.status_text = "Validation state updated."
	_assert_true(
		validation_event.validate().is_empty(),
		"Storyline events allow an empty phase_window as an unrestricted season window"
	)
	validation_event.phase_window = ["unknown_phase"]
	var validation_panel = VALIDATION_PANEL_SCRIPT.new()
	validation_panel.setup(validation_event)
	add_child(validation_panel)
	await get_tree().process_frame

	_assert_true(
		validation_panel.m_header_lbl != null,
		"Storyline validation panel builds its header label"
	)
	_assert_true(
		validation_panel.mouse_filter == Control.MOUSE_FILTER_PASS,
		"Storyline validation panel passes mouse input through for inspector scrolling"
	)
	if validation_panel.m_header_lbl != null:
		_assert_true(
			validation_panel.m_header_lbl.text == "⚠  1 warning",
			"Storyline validation panel shows the initial warning count"
		)
		_assert_true(
			validation_panel.m_header_lbl.mouse_filter == Control.MOUSE_FILTER_PASS,
			"Storyline validation labels pass mouse input through for inspector scrolling"
		)

	validation_event.phase_window = ["summer_1"]
	validation_event.emit_changed()
	await get_tree().process_frame
	if validation_panel.m_header_lbl != null:
		_assert_true(
			validation_panel.m_header_lbl.text == "✓  No validation warnings",
			"Storyline validation panel refreshes after resource changes"
		)
	validation_panel.queue_free()
	await get_tree().process_frame

	var wrapped_warning_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	wrapped_warning_event.id = (
		"typed_validation_event_with_a_really_long_identifier_that_should_wrap_"
		+ "inside_a_narrow_storyline_inspector_panel"
	)
	var wrapped_warning_panel = VALIDATION_PANEL_SCRIPT.new()
	wrapped_warning_panel.setup(wrapped_warning_event)
	add_child(wrapped_warning_panel)
	await get_tree().process_frame

	var wrapped_warning_label: Label = null
	if wrapped_warning_panel.m_warning_rows != null and wrapped_warning_panel.m_warning_rows.get_child_count() > 0:
		wrapped_warning_label = wrapped_warning_panel.m_warning_rows.get_child(0) as Label
	_assert_true(
		wrapped_warning_label != null,
		"Storyline validation panel exposes a warning label for wrapped-width layout checks"
	)
	if wrapped_warning_label != null:
		wrapped_warning_panel.size = Vector2(420.0, 0.0)
		wrapped_warning_panel._refresh_layout_metrics()
		await get_tree().process_frame
		var wide_warning_height := wrapped_warning_label.size.y
		var wide_panel_min_height := wrapped_warning_panel.get_combined_minimum_size().y

		wrapped_warning_panel.size = Vector2(120.0, 0.0)
		wrapped_warning_panel._refresh_layout_metrics()
		await get_tree().process_frame
		_assert_true(
			wrapped_warning_label.size.y > wide_warning_height,
			"Storyline validation panel recalculates wrapped warning heights when inspector width changes"
		)
		_assert_true(
			wrapped_warning_panel.get_combined_minimum_size().y > wide_panel_min_height,
			"Storyline validation panel updates its minimum size after wrapped warning heights change"
		)
	wrapped_warning_panel.queue_free()
	await get_tree().process_frame

	m_catalog_refresh_requests = 0
	var inspector_refresh_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	inspector_refresh_event.id = "typed_inspector_refresh_event"
	inspector_refresh_event.lead_text = "Refresh from inspector edits."
	inspector_refresh_event.journal_note = "Inspector edits should refresh validation and browser state."
	inspector_refresh_event.status_text = "Inspector refresh state updated."
	var inspector_refresh_panel = VALIDATION_PANEL_SCRIPT.new()
	inspector_refresh_panel.setup(inspector_refresh_event)
	add_child(inspector_refresh_panel)
	await get_tree().process_frame

	var inspector_status_bridge = INSPECTOR_STATUS_BRIDGE_SCRIPT.new()
	inspector_status_bridge.setup(
		inspector_refresh_panel,
		Callable(self, "_on_catalog_refresh_requested")
	)

	m_catalog_refresh_requests = 0
	inspector_status_bridge.refresh_validation_panel()
	await get_tree().process_frame
	_assert_true(
		m_catalog_refresh_requests == 0,
		"Storyline inspector validation-only refresh does not request a browser/catalog refresh"
	)

	inspector_refresh_event.phase_window = [
		STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
		STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
		"",
		STORY_SEASON_PHASES_SCRIPT.WINTER,
	]
	inspector_status_bridge.refresh_storyline_status_for_object(inspector_refresh_event)
	await get_tree().process_frame
	_assert_true(
		inspector_refresh_event.phase_window == [
			STORY_SEASON_PHASES_SCRIPT.SUMMER_1,
			STORY_SEASON_PHASES_SCRIPT.WINTER,
		],
		"Storyline inspector status refresh normalizes duplicate and empty phase_window edits"
	)
	_assert_true(
		m_catalog_refresh_requests == 1,
		"Storyline inspector status refresh requests a browser/catalog refresh callback"
	)
	if inspector_refresh_panel.m_header_lbl != null:
		_assert_true(
			inspector_refresh_panel.m_header_lbl.text == "✓  No validation warnings",
			"Storyline inspector status refresh updates the validation panel after inspector edits"
		)
	inspector_refresh_panel.queue_free()
	await get_tree().process_frame

	var picker_event: StorylineEventResource = EVENT_RESOURCE_SCRIPT.new()
	picker_event.id = "typed_picker_anchor"
	picker_event.lead_text = "Use the prerequisite picker."
	picker_event.journal_note = "The picker should add and remove prerequisite ids."
	picker_event.status_text = "Picker state changed."
	picker_event.phase_window = ["summer_1"]
	picker_event.story_flags_any = PackedStringArray(["typed_resource_anchor"])
	m_catalog_refresh_requests = 0

	var prerequisite_picker = PREREQUISITE_PICKER_PANEL_SCRIPT.new()
	prerequisite_picker.setup(
		picker_event,
		Callable(self, "_on_catalog_refresh_requested")
	)
	add_child(prerequisite_picker)
	await get_tree().process_frame

	_assert_true(
		prerequisite_picker.m_picker_tree != null,
		"Storyline prerequisite picker builds a route-rooted event tree"
	)
	_assert_true(
		prerequisite_picker.mouse_filter == Control.MOUSE_FILTER_PASS,
		"Storyline prerequisite picker passes mouse input through for inspector scrolling"
	)
	_assert_true(
		prerequisite_picker.m_bucket_lists.has("story_flags_all"),
		"Storyline prerequisite picker builds the All bucket UI"
	)
	_assert_true(
		prerequisite_picker.m_bucket_lists.has("story_flags_any"),
		"Storyline prerequisite picker builds the Any bucket UI"
	)
	prerequisite_picker._open_picker_for_bucket("story_flags_all")
	var picker_root: TreeItem = prerequisite_picker.m_picker_tree.get_root()
	_assert_true(
		picker_root != null,
		"Storyline prerequisite picker populates the chooser tree"
	)
	if picker_root != null:
		var selected_item := _find_tree_item_with_event_id(picker_root, "summer_return_complete")
		_assert_true(
			selected_item != null,
			"Storyline prerequisite picker can find a project event in the chooser tree"
		)
		if selected_item != null:
			prerequisite_picker.m_picker_tree.set_selected(selected_item, 0)
			prerequisite_picker._confirm_picker_selection()
			_assert_true(
				picker_event.story_flags_all.has("summer_return_complete"),
				"Storyline prerequisite picker adds the selected event to the target bucket"
			)
			_assert_true(
				not picker_event.story_flags_any.has("summer_return_complete"),
				"Storyline prerequisite picker keeps the opposite bucket clear for the added event"
			)
			await get_tree().process_frame
			_assert_true(
				m_catalog_refresh_requests == 1,
				"Storyline prerequisite picker requests a shared refresh after adding a dependency"
			)

	prerequisite_picker._remove_prerequisite("summer_return_complete", "story_flags_all")
	_assert_true(
		not picker_event.story_flags_all.has("summer_return_complete"),
		"Storyline prerequisite picker removes selected events from the target bucket"
	)
	await get_tree().process_frame
	_assert_true(
		m_catalog_refresh_requests == 2,
		"Storyline prerequisite picker requests a shared refresh after removing a dependency"
	)
	picker_event.story_flags_any = PackedStringArray(["winter_memory_reveal"])
	prerequisite_picker.refresh()
	var refreshed_any_bucket := prerequisite_picker.m_bucket_lists.get("story_flags_any") as VBoxContainer
	_assert_true(
		refreshed_any_bucket != null,
		"Storyline prerequisite picker can access the Any bucket during refresh checks"
	)
	if refreshed_any_bucket != null and refreshed_any_bucket.get_child_count() > 0:
		var refreshed_row := refreshed_any_bucket.get_child(0) as HBoxContainer
		_assert_true(
			refreshed_row != null,
			"Storyline prerequisite picker refresh rebuilds a dependency row after external changes"
		)
		if refreshed_row != null and refreshed_row.get_child_count() > 0:
			var refreshed_label := refreshed_row.get_child(0) as Label
			_assert_true(
				refreshed_label != null and refreshed_label.text == "winter_memory_reveal",
				"Storyline prerequisite picker refresh syncs externally changed dependencies into the inspector UI"
			)
	prerequisite_picker.queue_free()
	await get_tree().process_frame

	var route_panel_resource: StorylineRouteResource = ROUTE_RESOURCE_SCRIPT.new()
	route_panel_resource.id = "typed_panel_route"
	var route_event_panel = ROUTE_EVENT_PANEL_SCRIPT.new()
	route_event_panel.setup(route_panel_resource)
	add_child(route_event_panel)
	await get_tree().process_frame

	_assert_true(
		route_event_panel.m_event_rows != null,
		"Storyline route event panel builds its event list container"
	)
	_assert_true(
		route_event_panel.mouse_filter == Control.MOUSE_FILTER_PASS,
		"Storyline route event panel passes mouse input through for inspector scrolling"
	)
	route_event_panel._on_add_event_pressed()
	_assert_true(
		route_panel_resource.events.size() == 1,
		"Storyline route event panel appends a new event resource"
	)
	if route_panel_resource.events.size() == 1:
		_assert_true(
			route_panel_resource.events[0].id == "typed_panel_route_new_event_1",
			"Storyline route event panel assigns the first default event id"
		)
	route_event_panel._on_add_event_pressed()
	_assert_true(
		route_panel_resource.events.size() == 2,
		"Storyline route event panel can append multiple new events"
	)
	if route_panel_resource.events.size() == 2:
		_assert_true(
			route_panel_resource.events[1].id == "typed_panel_route_new_event_2",
			"Storyline route event panel keeps default ids unique across repeated adds"
		)
	route_event_panel._on_remove_event_pressed(0)
	_assert_true(
		route_panel_resource.events.size() == 2,
		"Storyline route event panel keeps events intact until delete confirmation"
	)
	_assert_true(
		route_event_panel.m_delete_event_dialog != null,
		"Storyline route event panel opens a confirmation dialog before deleting an event"
	)
	route_event_panel._confirm_delete_event()
	_assert_true(
		route_panel_resource.events.size() == 1,
		"Storyline route event panel removes the event after delete confirmation"
	)
	if route_panel_resource.events.size() == 1:
		_assert_true(
			route_panel_resource.events[0].id == "typed_panel_route_new_event_2",
			"Storyline route event panel keeps the remaining event after delete confirmation"
		)
	route_event_panel.queue_free()
	await get_tree().process_frame

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


func _find_tree_item_with_event_id(item: TreeItem, event_id: String) -> TreeItem:
	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary:
		var metadata_dict := metadata as Dictionary
		if String(metadata_dict.get("kind", "")) == "event" and String(metadata_dict.get("event_id", "")) == event_id:
			return item

	var child := item.get_first_child()
	while child != null:
		var found := _find_tree_item_with_event_id(child, event_id)
		if found != null:
			return found
		child = child.get_next()
	return null


func _option_button_item_metadata(option_button: OptionButton) -> Dictionary:
	var items: Dictionary = {}
	if option_button == null:
		return items
	for item_index: int in option_button.item_count:
		items[String(option_button.get_item_metadata(item_index))] = true
	return items


func _on_catalog_refresh_requested() -> void:
	m_catalog_refresh_requests += 1
