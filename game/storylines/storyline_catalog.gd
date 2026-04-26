class_name StorylineCatalog
extends RefCounted
## Central loader for all storyline route and event definitions.
##
## The public API ([method build_route_definitions] / [method build_event_definitions])
## always returns plain Dictionary values so editor tooling can rebuild directly
## from authored content. Runtime systems should use [method build_definition_bundle]
## once and keep an instance-local cache.

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

	for storyline in _load_route_resource_modules():
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
	for storyline in _load_route_resource_modules():
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
	for storyline in _load_route_resource_modules():
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


## Returns route resource paths keyed by route id for editor tooling.
static func build_route_resource_paths() -> Dictionary:
	var resource_paths_by_route: Dictionary = {}
	for path in _discover_route_resource_paths():
		var res: Resource = load(path)
		if not (res is StorylineRouteResource):
			continue
		var route_id := (res as StorylineRouteResource).id.strip_edges()
		if route_id.is_empty():
			continue
		var resource_paths := PackedStringArray(
			resource_paths_by_route.get(route_id, PackedStringArray())
		)
		resource_paths.append(path)
		resource_paths_by_route[route_id] = resource_paths
	return resource_paths_by_route


# ---------------------------------------------------------------------------
# Internal loading pipeline
# ---------------------------------------------------------------------------


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
	modules.sort_custom(_sort_route_resource_modules)
	return modules


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


# ---------------------------------------------------------------------------
# Sorters
# ---------------------------------------------------------------------------

static func _sort_route_entries(a: Dictionary, b: Dictionary) -> bool:
	var order_a := int(a.get("display_order", 9999))
	var order_b := int(b.get("display_order", 9999))
	if order_a == order_b:
		return String(a.get("display_name", a.get("id", ""))) < String(b.get("display_name", b.get("id", "")))
	return order_a < order_b


static func _sort_route_resource_modules(a: Dictionary, b: Dictionary) -> bool:
	var route_a: Dictionary = a.get("route", {})
	var route_b: Dictionary = b.get("route", {})
	var order_a := int(route_a.get("display_order", 9999))
	var order_b := int(route_b.get("display_order", 9999))
	if order_a == order_b:
		return String(route_a.get("id", "")) < String(route_b.get("id", ""))
	return order_a < order_b
