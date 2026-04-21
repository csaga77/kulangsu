@tool
class_name StorylineRouteResource
extends Resource
## Typed, inspector-editable definition of a complete storyline route.
##
## Create one .tres file per route under game/storylines/routes/.
## [StorylineCatalog] loads these as the canonical format and falls back to
## the per-route *_storyline.gd modules for any route not yet migrated.
##
## Author workflow:
##   1. Right-click game/storylines/routes/ → New Resource → StorylineRouteResource
##   2. Fill in the route metadata fields below.
##   3. Use the inspector's Route Events panel to add [StorylineEventResource]
##      sub-resources with unique default ids.
##   4. Save. The graph editor and route browser refresh on the next Refresh click.

# --- Route identity ----------------------------------------------------------

## Stable machine-readable route id — must be unique across the project.
## Examples: family_memory · study_future · preservation_inheritance · melody_landmarks
@export var id: String = ""
## Player-facing route name shown in the journal and HUD.
@export var display_name: String = ""
## Journal section header this route appears under.
@export var journal_section: String = ""
## Lower number = earlier in route display order.
@export var display_order: int = 0

# --- Lead selection ----------------------------------------------------------

## Base weight for pinning this route's best lead in the HUD.
@export var pin_priority: int = 0

# --- Ending tone rules -------------------------------------------------------

## Each rule adds a tone tag to the ending once the route's completion score
## passes [member StorylineEndingToneRule.min_score].
@export var ending_tone_rules: Array[StorylineEndingToneRule] = []

# --- Events ------------------------------------------------------------------

## Ordered list of events belonging to this route.
## [StorylineCatalog] flattens these into the shared event map.
@export var events: Array[StorylineEventResource] = []


## Returns the next unique default event id for this route using the pattern
## "<route_name>_new_event_<n>".
func next_default_event_id() -> String:
	var used_event_ids := _used_event_ids()
	var base := _default_event_id_base()
	var index := 1
	while true:
		var candidate := "%s_new_event_%d" % [base, index]
		if not used_event_ids.has(candidate):
			return candidate
		index += 1
	return ""


## Creates a new event resource with a unique default id for this route.
func create_default_event_resource() -> StorylineEventResource:
	var event_resource := StorylineEventResource.new()
	event_resource.id = next_default_event_id()
	return event_resource


# ---------------------------------------------------------------------------
# Conversion
# ---------------------------------------------------------------------------

## Returns a route-definition Dictionary matching the runtime format used by
## [StorylineCatalog], [StoryRouteGraph], and the journal builder.
func route_to_dict() -> Dictionary:
	var tone_rules: Array[Dictionary] = []
	for rule: StorylineEndingToneRule in ending_tone_rules:
		if rule != null:
			tone_rules.append(rule.to_dict())
	return {
		"id":                id,
		"display_name":      display_name,
		"journal_section":   journal_section,
		"display_order":     display_order,
		"pin_priority":      pin_priority,
		"ending_tone_rules": tone_rules,
	}


## Returns the full storyline Dictionary expected by [StorylineCatalog]'s
## internal normalizer: { "route": {...}, "events": [...] }.
func to_storyline_dict(source_path: String) -> Dictionary:
	var event_dicts: Array[Dictionary] = []
	for evt: StorylineEventResource in events:
		if evt != null:
			event_dicts.append(evt.to_dict())
	return {
		"path":   source_path,
		"route":  route_to_dict(),
		"events": event_dicts,
	}


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Returns all warnings for this route and its events.
## Checks: empty id, empty display_name, duplicate event ids, invalid
## fields from nested events, and tone-rule issues. Project-wide prerequisite
## existence checks live in [StorylineRouteBrowser] so valid cross-route
## references are not treated as route-local warnings.
func validate() -> PackedStringArray:
	var warnings := PackedStringArray()

	if id.strip_edges().is_empty():
		warnings.append("route id is empty")
	if display_name.strip_edges().is_empty():
		warnings.append("[%s] display_name is empty" % id)
	if display_order == 0:
		warnings.append(
			"[%s] display_order is 0 — set a positive integer to control sort position" % id
		)

	# Collect event ids for duplicate detection.
	var seen_ids: Dictionary = {}
	for evt: StorylineEventResource in events:
		if evt == null:
			warnings.append("[%s] events array contains a null entry" % id)
			continue
		var evt_id: String = evt.id.strip_edges()
		if evt_id.is_empty():
			warnings.append("[%s] an event has an empty id" % id)
		elif seen_ids.has(evt_id):
			warnings.append("[%s] duplicate event id '%s'" % [id, evt_id])
		else:
			seen_ids[evt_id] = true

		# Delegate per-event validation.
		for w: String in evt.validate():
			warnings.append(w)

	# Validate tone rules.
	for rule: StorylineEndingToneRule in ending_tone_rules:
		if rule == null:
			warnings.append("[%s] ending_tone_rules contains a null entry" % id)
			continue
		for w: String in rule.validate():
			warnings.append("[%s] " % id + w)

	return warnings


## Builds a typed route resource from the runtime storyline Dictionary format:
## { "route": {...}, "events": [...] }.
static func from_storyline_dict(value: Dictionary) -> StorylineRouteResource:
	var route_resource := StorylineRouteResource.new()

	var route_value = value.get("route", {})
	var route_dict: Dictionary = {}
	if route_value is Dictionary:
		route_dict = (route_value as Dictionary).duplicate(true)

	route_resource.id = String(route_dict.get("id", "")).strip_edges()
	route_resource.display_name = String(route_dict.get("display_name", ""))
	route_resource.journal_section = String(route_dict.get("journal_section", ""))
	route_resource.display_order = int(route_dict.get("display_order", 0))
	route_resource.pin_priority = int(route_dict.get("pin_priority", 0))

	var tone_rules_value = route_dict.get("ending_tone_rules", [])
	if tone_rules_value is Array:
		for rule_value in tone_rules_value as Array:
			if rule_value is Dictionary:
				route_resource.ending_tone_rules.append(
					StorylineEndingToneRule.from_dict(rule_value as Dictionary)
				)

	var events_value = value.get("events", [])
	if events_value is Array:
		for event_value in events_value as Array:
			if event_value is Dictionary:
				route_resource.events.append(
					StorylineEventResource.from_dict(event_value as Dictionary)
				)

	return route_resource


func _used_event_ids() -> Dictionary:
	var used_event_ids: Dictionary = {}
	for event_id_var in StorylineCatalog.build_event_definitions().keys():
		var event_id := String(event_id_var).strip_edges()
		if not event_id.is_empty():
			used_event_ids[event_id] = true
	for event_resource: StorylineEventResource in events:
		if event_resource == null:
			continue
		var event_id := event_resource.id.strip_edges()
		if not event_id.is_empty():
			used_event_ids[event_id] = true
	return used_event_ids


func _default_event_id_base() -> String:
	var route_name := id.strip_edges()
	if route_name.is_empty():
		route_name = _normalize_event_id_fragment(display_name)
	else:
		route_name = route_name.to_lower()
	if route_name.is_empty():
		return "story_route"
	return route_name


static func _normalize_event_id_fragment(value: String) -> String:
	var normalized := ""
	var lower_value := value.strip_edges().to_lower()
	var last_was_separator := false
	for index: int in lower_value.length():
		var character := lower_value.substr(index, 1)
		var code := lower_value.unicode_at(index)
		var is_lowercase_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if is_lowercase_letter or is_digit:
			normalized += character
			last_was_separator = false
		elif not normalized.is_empty() and not last_was_separator:
			normalized += "_"
			last_was_separator = true

	while normalized.ends_with("_"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized
