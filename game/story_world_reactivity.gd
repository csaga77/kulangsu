class_name StoryWorldReactivity
extends RefCounted

const INSPECTABLE_DEFINITIONS := {
	"harbor_lantern_lines": {
		"display_name": "Harbor Lantern Lines",
		"default_text": "Bare lantern hooks sway above the harbor, still waiting for a festival week to claim them.",
		"reactions": [
			{
				"conditions": {"story_flag_all": ["spring_festival_resolved"]},
				"text": "Wax, smoke, and paper ash cling to the lantern lines. The harbor looks used now, not merely prepared.",
			},
			{
				"conditions": {"story_flag_all": ["spring_festival_prepared"]},
				"text": "Paper lanterns and ferry ropes are being measured together, like the harbor is dressing itself for festival week.",
			},
		],
	},
	"harbor_notice_board": {
		"display_name": "Harbor Notice Board",
		"default_text": "Timetables, lessons, and ferry notices crowd the board until every future looks equally official.",
		"reactions": [
			{
				"conditions": {"story_flag_all": ["summer_exam_complete"]},
				"text": "The exam sheets are already curling at the corners. The board reads more like a timetable for second summer than a verdict.",
			},
			{
				"conditions": {"story_flag_all": ["future_commitment_choice"]},
				"text": "Half the notices still talk about departures, but the board no longer reads like a sentence you have to obey.",
			},
		],
	},
	"postcard_display_rack": {
		"display_name": "Postcard Display Rack",
		"default_text": "The postcard rack keeps its faded ferry views and family portraits in the same patient rows.",
		"reactions": [
			{
				"conditions": {"story_flag_all": ["preservation_inheritance_seen"]},
				"text": "Old ferry views and family portraits sit together like the harbor has been keeping custody of the island all along.",
			},
		],
	},
	"church_stone_bench": {
		"display_name": "Church Stone Bench",
		"default_text": "The stone bench feels like a place to wait out weather, hymns, and whatever answer the church has not given yet.",
		"reactions": [
			{
				"conditions": {"story_flag_all": ["winter_memory_reveal"]},
				"text": "The bench keeps the cold longer now. Even the church yard feels like it is listening to what the winter memory finally said.",
			},
		],
	},
	"bagua_railings": {
		"display_name": "Bagua Railings",
		"default_text": "From the railings, the older roofs still read like a pattern more than a responsibility.",
		"reactions": [
			{
				"conditions": {"story_flag_all": ["preservation_tower_perspective"]},
				"text": "From the railings down, the roofs stop looking quaint and start looking entrusted to everyone still here.",
			},
		],
	},
}


static func build_inspect_text(app_state, inspectable_id: String, display_name: String = "") -> String:
	var definition: Dictionary = INSPECTABLE_DEFINITIONS.get(inspectable_id, {})
	var resolved_display_name := display_name.strip_edges()
	if resolved_display_name.is_empty():
		resolved_display_name = String(definition.get("display_name", inspectable_id))

	for reaction_value in definition.get("reactions", []):
		var reaction: Dictionary = reaction_value
		if !_matches_conditions(app_state, reaction.get("conditions", {})):
			continue
		return String(reaction.get("text", "")).replace("{display_name}", resolved_display_name)

	var default_text := String(definition.get("default_text", "Inspect: %s" % resolved_display_name))
	return default_text.replace("{display_name}", resolved_display_name)


static func _matches_conditions(app_state, conditions_value: Variant) -> bool:
	if !(conditions_value is Dictionary):
		return true
	var conditions: Dictionary = conditions_value
	if conditions.is_empty():
		return true
	if app_state == null:
		return false

	var expected_phase := String(conditions.get("season_phase", ""))
	if !expected_phase.is_empty() and String(app_state.season_phase) != expected_phase:
		return false

	for flag_value in conditions.get("story_flag_all", []):
		if !bool(app_state.get_story_flag(String(flag_value), false)):
			return false

	var any_flags: Array = conditions.get("story_flag_any", [])
	if !any_flags.is_empty():
		var matched_any := false
		for flag_value in any_flags:
			if bool(app_state.get_story_flag(String(flag_value), false)):
				matched_any = true
				break
		if !matched_any:
			return false

	var required_routes = conditions.get("route_state", {})
	if required_routes is Dictionary:
		for route_id_value in required_routes.keys():
			var route_id := String(route_id_value)
			var expected_state := String(required_routes[route_id_value])
			var current_state := String(app_state.get_route_progress(route_id).get("state", "idle"))
			if current_state != expected_state:
				return false

	return true
