class_name StorylineCatalog
extends RefCounted
## Central loader for all storyline route and event definitions.
##
## Loading priority (highest to lowest):
##   1. [StorylineRouteResource] .tres files under [constant ROUTE_RESOURCE_DIR].
##   2. Legacy *_storyline.gd modules under [constant STORYLINE_DIR] — used as a
##      compatibility-only migration fallback for older routes that still need
##      conversion.
##
## The public API ([method build_route_definitions] / [method build_event_definitions])
## always returns plain Dictionary values so editor tooling can rebuild directly
## from authored content. Runtime systems should use [method build_definition_bundle]
## once and keep an instance-local cache.

const STORYLINE_DIR      := "res://game/storylines"
const STORYLINE_SUFFIX   := "_storyline.gd"
## Directory scanned for [StorylineRouteResource] .tres files.
const ROUTE_RESOURCE_DIR := "res://game/storylines/routes"


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func route_display_order() -> Array[String]:
	return _route_display_order_from_definitions(build_route_definitions())


static func build_definition_bundle() -> Dictionary:
	var route_definitions := {}
	var event_definitions := {}

	for storyline in _load_storyline_modules():
		var route_definition: Dictionary = storyline.get("route", {})
		var route_id := String(route_definition.get("id", "")).strip_edges()
		if route_id.is_empty():
			push_warning("Skipping storyline route without an id")
			continue
		if route_definitions.has(route_id):
			push_warning("Duplicate storyline route id '%s'; keeping the latest definition" % route_id)
		route_definitions[route_id] = route_definition

		for event_value in storyline.get("events", []):
			if !(event_value is Dictionary):
				continue
			var event_definition: Dictionary = (event_value as Dictionary).duplicate(true)
			var event_id := String(event_definition.get("id", "")).strip_edges()
			if event_id.is_empty():
				push_warning("Skipping storyline event without an id in route '%s'" % route_id)
				continue
			if String(event_definition.get("route_id", "")).strip_edges().is_empty():
				event_definition["route_id"] = route_id
			if event_definitions.has(event_id):
				push_warning("Duplicate storyline event id '%s'; keeping the latest definition" % event_id)
			event_definitions[event_id] = event_definition

	return {
		"route_definitions": route_definitions,
		"event_definitions": event_definitions,
		"route_display_order": _route_display_order_from_definitions(route_definitions),
	}


static func _route_display_order_from_definitions(route_definitions: Dictionary) -> Array[String]:
	var entries: Array[Dictionary] = []
	for route_id_variant in route_definitions.keys():
		var route_id := String(route_id_variant)
		var route_definition: Dictionary = route_definitions.get(route_id, {})
		if route_definition is Dictionary:
			entries.append({
				"id": route_id,
				"display_order": int(route_definition.get("display_order", 9999)),
				"display_name": String(route_definition.get("display_name", route_id)),
			})
	entries.sort_custom(_sort_route_entries)
	var ordered_ids: Array[String] = []
	for entry in entries:
		ordered_ids.append(String(entry.get("id", "")))
	return ordered_ids


static func build_route_definitions() -> Dictionary:
	var route_definitions := {}
	for storyline in _load_storyline_modules():
		var route_definition: Dictionary = storyline.get("route", {})
		var route_id := String(route_definition.get("id", "")).strip_edges()
		if route_id.is_empty():
			push_warning("Skipping storyline route without an id")
			continue
		if route_definitions.has(route_id):
			push_warning("Duplicate storyline route id '%s'; keeping the latest definition" % route_id)
		route_definitions[route_id] = route_definition
	return route_definitions


static func build_event_definitions() -> Dictionary:
	var event_definitions := {}
	for storyline in _load_storyline_modules():
		var route_definition: Dictionary = storyline.get("route", {})
		var route_id := String(route_definition.get("id", "")).strip_edges()
		for event_value in storyline.get("events", []):
			if !(event_value is Dictionary):
				continue
			var event_definition: Dictionary = (event_value as Dictionary).duplicate(true)
			var event_id := String(event_definition.get("id", "")).strip_edges()
			if event_id.is_empty():
				push_warning("Skipping storyline event without an id in route '%s'" % route_id)
				continue
			if String(event_definition.get("route_id", "")).strip_edges().is_empty():
				event_definition["route_id"] = route_id
			if event_definitions.has(event_id):
				push_warning("Duplicate storyline event id '%s'; keeping the latest definition" % event_id)
			event_definitions[event_id] = event_definition
	return event_definitions


## Loads all [StorylineRouteResource] .tres files found in [constant ROUTE_RESOURCE_DIR].
## Returns them as Resource objects for use in editor tooling (browser, graph editor).
## Runtime callers should use [method build_route_definitions] instead.
static func load_route_resources() -> Array[StorylineRouteResource]:
	var resources: Array[StorylineRouteResource] = []
	for path in _discover_route_resource_paths():
		var res: Resource = load(path)
		if res is StorylineRouteResource:
			resources.append(res as StorylineRouteResource)
		elif res != null:
			push_warning(
				"StorylineCatalog: %s is not a StorylineRouteResource (got %s)"
				% [path, res.get_class()]
			)
	return resources


## Returns route source paths keyed by route id for editor tooling.
## Each entry is a Dictionary with `resource_paths` and `gdscript_paths`.
static func build_route_source_paths() -> Dictionary:
	var source_paths: Dictionary = {}

	for path in _discover_route_resource_paths():
		var res: Resource = load(path)
		if not (res is StorylineRouteResource):
			continue
		var route_id := (res as StorylineRouteResource).id.strip_edges()
		if route_id.is_empty():
			continue
		var route_entry := _ensure_route_source_path_entry(source_paths, route_id)
		var resource_paths := PackedStringArray(route_entry.get("resource_paths", PackedStringArray()))
		resource_paths.append(path)
		route_entry["resource_paths"] = resource_paths
		source_paths[route_id] = route_entry

	for path in _discover_storyline_paths():
		var script: GDScript = load(path) as GDScript
		if script == null or !script.has_method("build_storyline"):
			continue
		var storyline_value = script.call("build_storyline")
		if !(storyline_value is Dictionary):
			continue
		var normalized := _normalize_storyline(path, storyline_value as Dictionary)
		var route_id := String(normalized.get("route", {}).get("id", "")).strip_edges()
		if route_id.is_empty():
			continue
		var route_entry := _ensure_route_source_path_entry(source_paths, route_id)
		var gdscript_paths := PackedStringArray(route_entry.get("gdscript_paths", PackedStringArray()))
		gdscript_paths.append(path)
		route_entry["gdscript_paths"] = gdscript_paths
		source_paths[route_id] = route_entry

	return source_paths


# ---------------------------------------------------------------------------
# Internal loading pipeline
# ---------------------------------------------------------------------------

static func _load_storyline_modules() -> Array[Dictionary]:
	var modules: Array[Dictionary] = []

	# --- Priority 1: typed resource files ------------------------------------
	var resource_route_ids: Dictionary = {}
	for storyline in _load_route_resource_modules():
		var route_definition: Dictionary = storyline.get("route", {})
		var route_id: String = String(route_definition.get("id", "")).strip_edges()
		if !route_id.is_empty():
			resource_route_ids[route_id] = true
		modules.append(storyline)

	# --- Priority 2: legacy .gd modules (skip already-covered routes) --------
	for path in _discover_storyline_paths():
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_warning("Failed to load storyline module %s" % path)
			continue
		if !script.has_method("build_storyline"):
			push_warning("Storyline module %s is missing build_storyline()" % path)
			continue
		var storyline_value = script.call("build_storyline")
		if !(storyline_value is Dictionary):
			push_warning("Storyline module %s did not return a Dictionary" % path)
			continue
		var normalized := _normalize_storyline(path, storyline_value as Dictionary)
		var route_id: String = String(normalized.get("route", {}).get("id", "")).strip_edges()
		if resource_route_ids.has(route_id):
			# A typed resource already covers this route — skip the .gd fallback.
			continue
		modules.append(normalized)

	modules.sort_custom(_sort_storyline_modules)
	return modules


## Loads and converts [StorylineRouteResource] .tres files into the internal
## normalized Dictionary format used throughout the pipeline.
static func _load_route_resource_modules() -> Array[Dictionary]:
	var modules: Array[Dictionary] = []
	for path in _discover_route_resource_paths():
		var res: Resource = load(path)
		if res is StorylineRouteResource:
			modules.append((res as StorylineRouteResource).to_storyline_dict(path))
		elif res != null:
			push_warning(
				"StorylineCatalog: %s is not a StorylineRouteResource — skipping"
				% path
			)
	return modules


static func _normalize_storyline(path: String, storyline_value: Dictionary) -> Dictionary:
	var storyline := storyline_value.duplicate(true)
	var route_value = storyline.get("route", {})
	var normalized_route: Dictionary = {}
	if route_value is Dictionary:
		normalized_route = (route_value as Dictionary).duplicate(true)
	var route_id := String(normalized_route.get("id", "")).strip_edges()
	normalized_route["id"] = route_id
	if !normalized_route.has("display_order"):
		normalized_route["display_order"] = 9999
	var events: Array = []
	var events_value = storyline.get("events", [])
	if events_value is Array:
		events = (events_value as Array).duplicate(true)
	return {
		"path": path,
		"route": normalized_route,
		"events": events,
	}


static func _discover_storyline_paths() -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(STORYLINE_DIR)
	if directory == null:
		push_warning("Unable to open storyline directory %s" % STORYLINE_DIR)
		return paths
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while !file_name.is_empty():
		if !directory.current_is_dir() and file_name.ends_with(STORYLINE_SUFFIX):
			paths.append("%s/%s" % [STORYLINE_DIR, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths


static func _discover_route_resource_paths() -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(ROUTE_RESOURCE_DIR)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while !file_name.is_empty():
		if !directory.current_is_dir() and file_name.ends_with(".tres"):
			paths.append("%s/%s" % [ROUTE_RESOURCE_DIR, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths


static func _ensure_route_source_path_entry(source_paths: Dictionary, route_id: String) -> Dictionary:
	if not source_paths.has(route_id):
		source_paths[route_id] = {
			"resource_paths": PackedStringArray(),
			"gdscript_paths": PackedStringArray(),
		}
	return source_paths.get(route_id, {}) as Dictionary


# ---------------------------------------------------------------------------
# Sorters
# ---------------------------------------------------------------------------

static func _sort_route_entries(a: Dictionary, b: Dictionary) -> bool:
	var order_a := int(a.get("display_order", 9999))
	var order_b := int(b.get("display_order", 9999))
	if order_a == order_b:
		return String(a.get("display_name", a.get("id", ""))) < String(b.get("display_name", b.get("id", "")))
	return order_a < order_b


static func _sort_storyline_modules(a: Dictionary, b: Dictionary) -> bool:
	var route_a: Dictionary = a.get("route", {})
	var route_b: Dictionary = b.get("route", {})
	var order_a := int(route_a.get("display_order", 9999))
	var order_b := int(route_b.get("display_order", 9999))
	if order_a == order_b:
		return String(route_a.get("id", "")) < String(route_b.get("id", ""))
	return order_a < order_b
