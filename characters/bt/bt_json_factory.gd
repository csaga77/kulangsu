class_name BTJsonFactory
extends RefCounted

## 1) JSON authoring patterns
## A) Include a whole file (with params)
'''
{
    "name": "root",
    "type": "Selector",
    "children": [
        { "$include": "res://bt/snippets/follow_block.json",
          "params": { "follow_interval": 0.08, "dot": 0.9 } },
        { "$include": "./idle_lib.json#WanderIdle",
          "params": { "idle_min": 1.0, "idle_max": 3.0, "idle_prob": 0.5 } }
    ]
}
'''
## • "$include": "<path>[#SubtreeName]"
## • If #SubtreeName omitted → include that file’s root.
## • If present → include the named subtree (see library format below).
## • params (optional): simple string/number/bool placeholders you can reference as ${key} anywhere inside the included JSON.
## 
## • Directive style:
## This is a special JSON directive recognized by the loader.
## • It means: “Replace this whole node with the contents of WanderIdle from idle_lib.json (or the file root if no # part).”
## • It’s shorthand: you don’t need "type", "ref", etc.
## • Common when you want to “just pull in” another file or subtree, with optional "params":
##
## B) Subtree node (explicit)
## 
## • Node style:
## This is an actual node entry with "type": "Subtree".
## • It makes the intention explicit: this node is a subtree reference.
## • It allows you to add other keys alongside "ref" and "params" without conflicting with $include syntax:

'''
{ "type": "Subtree",
  "ref": "res://bt/combat_lib.json#FollowOrOrbit",
  "params": { "orbit": true, "dot": 0.99999 } }
'''
## C) Library JSON with named subtrees
'''
{
    "$library": {
        "FollowOnly": {
            "type": "Decorator.Throttle",
            "interval": "${follow_interval}",
            "child": {
                "type": "Sequence",
                "children": [
                    { "type": "Action.TryToFollowTarget",
                      "name": "StartFollow",
                      "max_following_distance": "${max_dist}",
                      "max_following_time": "${max_time}",
                      "min_following_distance": "${min_dist}",
                      "min_following_interval_seconds": "${min_interval}" },
                    { "type": "Sequence",
                      "name": "Adjust Following",
                      "children": [
                        { "type": "Action.AimAtTargetIfNeeded",
                          "dot_threshold": "${dot}" },
                        { "type": "Action.MoveForward" }
                      ] }
                ]
            }
        },

        "WanderIdle": {
            "type": "Selector",
            "children": [
                { "type": "Sequence",
                  "children": [
                    { "type": "Condition.RandomTimeout",
                      "min_duration": "${idle_min}",
                      "max_duration": "${idle_max}",
                      "possibility": "${idle_prob}" },
                    { "type": "Action.StopMovement" }
                  ] },
                { "type": "Parallel",
                  "success_policy": "REQUIRE_ALL",
                  "failure_policy": "REQUIRE_ALL",
                  "children": [
                    { "type": "Sequence",
                      "children": [
                        { "type": "Condition.RandomTimeout",
                          "min_duration": "${idle_min}",
                          "max_duration": "${idle_max}",
                          "possibility": 0.0,
                          "timeout_result": true },
                        { "type": "Action.UpdateWanderHeading" }
                      ] },
                    { "type": "Action.MoveForward" }
                  ] }
            ]
        }
    }
}
'''

## Summary
## • $include → directive; inlines raw JSON, like a C #include.
## • type: Subtree with ref → explicit node; looks/acts like other BT nodes, with clearer semantics in the tree.

## Both resolve to the same expanded structure internally — the difference is style and clarity:
## • $include = “drop in the JSON here.”
## • Subtree/ref = “this node is an external subtree.”

## 2) Ways to declare defaults

## A) String placeholder with inline default
## • ${key} → replaced by params.key
## • ${key|default} → uses default if params.key is missing

## Examples:
'''
"interval": "${follow_interval|0.08}",
"dot_threshold": "${dot|0.9}"
'''
## B) Typed placeholder object (preserves number/bool types)
## • {"$param":"key","default": <value>}

## Examples:
'''
"max_following_distance": { "$param": "max_dist", "default": 400 },
"timeout_result": { "$param": "timeout_result", "default": true }
'''

## C) Defaults at subtree scope ($defaults)
## Inside a library JSON’s named subtree, declare a $defaults dict. At call time, we merge:

'''
{
  "$library": {
    "FollowOnly": {
      "$defaults": { "follow_interval": 0.08, "dot": 0.9, "max_dist": 400, "max_time": 5, "min_dist": 150, "min_interval": 3.0 },
      "type": "Decorator.Throttle",
      "interval": "${follow_interval}",
      "child": {
        "type": "Sequence",
        "children": [
          { "type": "Action.TryToFollowTarget",
            "max_following_distance": { "$param": "max_dist", "default": 400 },
            "max_following_time": { "$param": "max_time", "default": 5 },
            "min_following_distance": { "$param": "min_dist", "default": 150 },
            "min_following_interval_seconds": { "$param": "min_interval", "default": 3.0 }
          },
          { "type": "Sequence",
            "children": [
              { "type": "Action.AimAtTargetIfNeeded", "dot_threshold": "${dot|0.9}" },
              { "type": "Action.MoveForward" }
            ]
          }
        ]
      }
    }
  }
}
'''


# ====== Registry: map JSON "type" -> constructor (yours unchanged) ======
static var _registry := {
	#Common
	"Selector": func() -> BTSelector: return BTSelector.new(),
	"Sequence": func() -> BTSequence: return BTSequence.new(),
	"Parallel": func() -> BTParallel: return BTParallel.new(),

	"Decorator.Throttle": func() -> BTNode: return BTThrottle.new(),
	"Decorator.Wait": func() -> BTNode: return BTWait.new(),
	"Decorator.SucceedOnRunningOrSuccess": func() -> BTNode: return BTSucceedOnRunningOrSuccess.new(),
	"Decorator.UntilFailure": func() -> BTNode: return BTUntilFailure.new(),
	"Decorator.ConditionDecorator": func() -> BTNode: return BTConditionDecorator.new(),

	#Vehicle
	#"Condition.NeedToReturn": func() -> BTNode: return BTVehicleConditions.NeedToReturn.new(),
	#"Condition.HealthThreshold": func() -> BTNode: return BTVehicleConditions.HealthThreshold.new(),
	#"Condition.IsSelfDestructReady": func() -> BTNode: return BTVehicleConditions.IsSelfDestructReady.new(),
	#"Condition.TargetValid": func() -> BTNode: return BTVehicleConditions.TargetValid.new(),
	"Condition.RandomTimeout": func() -> BTNode: return BTRandomTimeoutCondition.new(),
	
	#"Action.MoveForward": func() -> BTNode: return BTVehicleActions.MoveForward.new(),
	#"Action.StopMovement": func() -> BTNode: return BTVehicleActions.StopMovement.new(),
	#"Action.UpdateWanderHeading": func() -> BTNode: return BTVehicleActions.UpdateWanderHeading.new(),
	#"Action.BackOffFromTarget": func() -> BTNode: return BTVehicleActions.BackOffFromTarget.new(),
	#"Action.TryToFollowTarget": func() -> BTNode: return BTVehicleActions.TryToFollowTarget.new(),
	#"Action.AimAtTargetIfNeeded": func() -> BTNode: return BTVehicleActions.AimAtTargetIfNeeded.new(),
	#"Action.CollisionRecover": func() -> BTNode: return BTVehicleActions.CollisionRecover.new(),
	#"Action.Explode": func() -> BTNode: return BTVehicleActions.ExplodeAction.new(),
	#"Action.Dig": func() -> BTNode: return BTWalkerActions.DigAction.new(),
	
	#Boid
	"Boid.InFlock": func() -> BTNode: return BTBoid.InFlock.new(),
	"Boid.UpdateBoid": func() -> BTNode: return BTBoid.UpdateBoid.new(),
	
	#Turret
	#"Condition.IsAttackEnabled": func() -> BTNode: return BTTurretConditions.IsAttackEnabled.new(),
	#"Condition.IsTargetInRange": func() -> BTNode: return BTTurretConditions.IsTargetInRange.new(),
	#"Condition.IsTargetVisible": func() -> BTNode: return BTTurretConditions.IsTargetVisible.new(),
	#"Condition.IsWeaponReady": func() -> BTNode: return BTTurretConditions.IsWeaponReady.new(),
	#
	#"Action.AimTurret": func() -> BTNode: return BTTurretActions.AimTurret.new(),
	#"Action.StartShooting": func() -> BTNode: return BTTurretActions.StartShooting.new(),
	#"Action.MaintainShooting": func() -> BTNode: return BTTurretActions.MaintainShooting.new(),
	#"Action.StopShooting": func() -> BTNode: return BTTurretActions.StopShooting.new(),
}

# ====== Dynamic Registry API (non-breaking) ======
static func registry_has(name: String) -> bool:
	return _registry.has(name)

static func registry_list() -> Array:
	return _registry.keys()

# ctor: Callable that returns a new BTNode (e.g., func()->BTNode: return MyNode.new())
static func registry_register(name: String, ctor: Callable, overwrite := false) -> void:
	if _registry.has(name) and not overwrite:
		push_warning("[BTJsonFactory] Type already registered (use overwrite=true): %s" % name)
		return
	_registry[name] = ctor

# cls: a Class that supports .new()
static func registry_register_class(name: String, cls: Variant, overwrite := false) -> void:
	registry_register(name, func() -> BTNode: return cls.new(), overwrite)

static func registry_alias(alias_name: String, existing: String, overwrite := false) -> void:
	if not _registry.has(existing):
		push_error("[BTJsonFactory] Cannot alias '%s' -> '%s'; base not found" % [alias_name, existing])
		return
	registry_register(alias_name, _registry[existing], overwrite)

# Bulk helpers
static func registry_register_many_by_class(map: Dictionary, overwrite := false, prefix := "") -> void:
	for k in map.keys():
		var key := prefix + String(k)
		registry_register_class(key, map[k], overwrite)

static func registry_register_many_by_ctor(map: Dictionary, overwrite := false, prefix := "") -> void:
	for k in map.keys():
		var key := prefix + String(k)
		registry_register(key, map[k], overwrite)

# Optional: create via registry (used by builder)
static func registry_create(name: String) -> BTNode:
	return _registry[name].call() if _registry.has(name) else null

# ====== Cache & state ======
var _file_cache: Dictionary = {}     # path -> { json: Dictionary, library: Dictionary, basedir: String }
var _include_stack: Array[String] = []  # cycle detection (paths)

# ====== Enums (unchanged) ======
static func _to_parallel_success(val) -> int:
	if typeof(val) == TYPE_INT: return val
	match String(val).to_upper():
		"REQUIRE_ALL": return BTTypes.ParallelSuccessPolicy.REQUIRE_ALL
		"REQUIRE_ANY": return BTTypes.ParallelSuccessPolicy.REQUIRE_ANY
		_: return BTTypes.ParallelSuccessPolicy.REQUIRE_ALL

static func _to_parallel_failure(val) -> int:
	if typeof(val) == TYPE_INT: return val
	match String(val).to_upper():
		"REQUIRE_ALL": return BTTypes.ParallelFailurePolicy.REQUIRE_ALL
		"REQUIRE_ANY": return BTTypes.ParallelFailurePolicy.REQUIRE_ANY
		_: return BTTypes.ParallelFailurePolicy.REQUIRE_ANY

# ====== Utils ======
static func _dirname(path: String) -> String:
	var i :int = max(path.rfind("/"), path.rfind("\\"))
	return path.substr(0, i) if i >= 0 else "res://"

static func _join(a: String, b: String) -> String:
	if b.begins_with("res://") or b.begins_with("user://"):
		return b
	if a.ends_with("/"):
		return a + b
	return a + "/" + b

# Deep clone (Dictionary/Array primitives only)
static func _clone(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var d := {}
			for k in v.keys():
				d[k] = _clone(v[k])
			return d
		TYPE_ARRAY:
			var arr := []
			for x in v:
				arr.append(_clone(x))
			return arr
		_:
			return v

# Merge dictionaries: latter overrides earlier.
static func _merge_params(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}.duplicate()
	for k in a.keys():
		out[k] = a[k]
	for k in b.keys():
		out[k] = b[k]
	return out

# Extract `$defaults` at this node (if any) and remove it from the node.
static func _extract_defaults_inplace(node: Dictionary) -> Dictionary:
	if node.has("$defaults") and typeof(node["$defaults"]) == TYPE_DICTIONARY:
		var d = node["$defaults"]
		node.erase("$defaults")
		return d
	return {}

# Parameter expansion: replaces "${key}" in strings recursively
static func _expand_params(node, params: Dictionary):
	match typeof(node):
		TYPE_DICTIONARY:
			# typed placeholder
			if node.has("$param"):
				var key := String(node["$param"])
				return params[key] if params.has(key) else node.get("default")
			# normal dict
			var out := {}
			for k in node.keys():
				out[k] = _expand_params(node[k], params)
			# strip any $defaults that slipped through (should be handled earlier)
			if out.has("$defaults"):
				out.erase("$defaults")
			return out

		TYPE_ARRAY:
			var arr := []
			for x in node:
				arr.append(_expand_params(x, params))
			return arr

		TYPE_STRING:
			var s := node as String
			var i := 0
			while true:
				var start := s.find("${", i)
				if start == -1: break
				var end := s.find("}", start + 2)
				if end == -1: break
				var inner := s.substr(start + 2, end - (start + 2))
				var bar := inner.find("|")
				var key := inner if (bar == -1) else inner.substr(0, bar)
				var has_default := bar != -1
				var def_val := inner.substr(bar + 1) if has_default else ""
				var repl := def_val
				if params.has(key):
					repl = str(params[key])
				s = s.substr(0, start) + repl + s.substr(end + 1)
				i = start + repl.length()
			return s

		_:
			return node

# Load + cache a file, extract $library if present
func _load_json_file(path: String) -> Dictionary:
	if _file_cache.has(path):
		return _file_cache[path]

	if not FileAccess.file_exists(path):
		push_error("[BTJsonFactory] File not found: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var root = JSON.parse_string(text)
	if typeof(root) != TYPE_DICTIONARY:
		push_error("[BTJsonFactory] Invalid JSON root in %s" % path)
		return {}

	var lib := {}
	if root.has("$library") and typeof(root["$library"]) == TYPE_DICTIONARY:
		lib = root["$library"]

	var rec := {
		"json": root,
		"library": lib,
		"basedir": _dirname(path)
	}
	_file_cache[path] = rec
	return rec

# Resolve include like "path[#Subtree]"
func _resolve_include_spec(spec: String, base_dir: String) -> Dictionary:
	var hash_idx  := spec.find("#")
	var file_part := spec.substr(0, hash_idx) if hash_idx >= 0 else spec
	var name_part := spec.substr(hash_idx + 1) if hash_idx >= 0 else ""
	var file_path := file_part
	if not file_path.begins_with("res://") and not file_path.begins_with("user://"):
		file_path = _join(base_dir, file_path)
	return {"path": file_path, "name": name_part}

# Build a JSON dictionary into node(s). `ctx_path` is the current file path for relative includes.
# Build a JSON dictionary into node(s).
func _build_dict(data: Dictionary, ctx_path: String, parent_params: Dictionary) -> Dictionary:
	# Handle include / subtree
	if data.has("$include"):
		var spec: String = data["$include"]
		var inc_params = data.get("params", {})
		assert(typeof(inc_params) == TYPE_DICTIONARY, "params must be a dictionary")
		var resolved := _resolve_include_spec(spec, _dirname(ctx_path))
		return _build_include(resolved["path"], resolved["name"], parent_params, inc_params)

	if data.get("type", "") == "Subtree":
		var ref: String = data.get("ref", "")
		assert(ref != "", "Subtree requires 'ref'")
		var sub_params = data.get("params", {})
		assert(typeof(sub_params) == TYPE_DICTIONARY, "params must be a dictionary")
		var resolved := _resolve_include_spec(ref, _dirname(ctx_path))
		return _build_include(resolved["path"], resolved["name"], parent_params, sub_params)

	# Not an include: clone, expand with parent params right here
	var expanded = _expand_params(_clone(data), parent_params)
	return expanded

# Pull from file root or $library[name], with cycle safety and param expansion
# Pull from file root or $library[name], merge defaults, expand, and resolve nested.
func _build_include(path: String, name: String, parent_params: Dictionary, inc_params: Dictionary) -> Dictionary:
	# cycle detection
	if _include_stack.has(path):
		push_error("[BTJsonFactory] Cyclic include detected: %s -> %s" % [_include_stack.back(), path])
		return {}

	_include_stack.append(path)

	var rec := _load_json_file(path)
	#var base_dir: String = rec.get("basedir", _dirname(path))
	var root: Dictionary = rec.get("json", {})
	var lib: Dictionary = rec.get("library", {})

	var picked: Dictionary = {}
	var picked_defaults: Dictionary = {}

	if name == "":
		# include entire file root; root-level $defaults apply
		picked = _clone(root)
		picked_defaults = _extract_defaults_inplace(picked)
		if picked.has("$library") and picked.keys().size() == 1:
			push_error("[BTJsonFactory] File %s only contains $library; specify #Subtree" % path)
			_include_stack.pop_back()
			return {}
	else:
		# include library subtree; subtree-level $defaults apply
		if not lib.has(name):
			push_error("[BTJsonFactory] Subtree '%s' not found in %s" % [name, path])
			_include_stack.pop_back()
			return {}
		picked = _clone(lib[name])
		picked_defaults = _extract_defaults_inplace(picked)

	# Effective params precedence:
	# parent_params  <  picked_defaults  <  inc_params
	var effective := _merge_params(parent_params, _merge_params(picked_defaults, inc_params))

	# First expand placeholders with effective params at this include boundary
	var expanded = _expand_params(picked, effective)

	# Then resolve any nested includes inside, passing the same effective params down
	var resolved = _resolve_embeds(expanded, path, effective)

	_include_stack.pop_back()
	return resolved

# Walk a JSON node and resolve any nested $include/Subtree within it
# Walk and resolve nested includes, carrying current params down
func _resolve_embeds(node, ctx_path: String, parent_params: Dictionary):
	match typeof(node):
		TYPE_DICTIONARY:
			# If node is an include or subtree, let _build_dict handle it (pulls defaults too)
			if node.has("$include") or node.get("type", "") == "Subtree":
				return _build_dict(node, ctx_path, parent_params)

			var out := {}
			for k in node.keys():
				out[k] = _resolve_embeds(node[k], ctx_path, parent_params)
			return out

		TYPE_ARRAY:
			var arr := []
			for x in node:
				arr.append(_resolve_embeds(x, ctx_path, parent_params))
			return arr

		_:
			return node

# ====== Node construction ======
static func _apply_properties(node: Object, data: Dictionary) -> void:
	var reserved := {"type": true, "children": true, "child": true, "name": true, "child_condition": true}
	var props := {}
	for p in node.get_property_list():
		if "name" in p and typeof(p.name) == TYPE_STRING:
			props[p.name] = true

	for k in data.keys():
		if reserved.has(k):
			continue
		if props.has(k):
			if node is BTParallel:
				if k == "success_policy":
					node.success_policy = _to_parallel_success(data[k])
					continue
				if k == "failure_policy":
					node.failure_policy = _to_parallel_failure(data[k])
					continue
			var t = typeof(node.get(k))
			var raw_value = data[k]
			var v = type_convert(raw_value, t)
			if typeof(raw_value) == Variant.Type.TYPE_STRING:
				if t == Variant.Type.TYPE_BOOL:
					v = true if raw_value.to_lower() == "true" else false
			node.set(k, v)

	if data.has("name") and props.has("name"):
		node.name = String(data["name"])

func _build_node_from_json(data: Dictionary) -> BTNode:
	assert(data.has("type"), "BT JSON node missing 'type'")
	var t: String = data["type"]

	var node: BTNode = registry_create(t)
	if node == null:
		push_error("[BTJsonFactory] Unknown type: %s" % t)
		return null

	_apply_properties(node, data)

	# composites
	if node is BTComposite and data.has("children"):
		for child_data in data["children"]:
			var child_node := _build_node_from_json(child_data)
			if child_node:
				node.add_child_node(child_node)

	# decorators
	if node is BTDecorator and data.has("child"):
		var c := _build_node_from_json(data["child"])
		if c:
			(node as BTDecorator).child = c

	# condition decorators
	if node is BTConditionDecorator and data.has("child_condition"):
		var c := _build_node_from_json(data["child_condition"])
		if c:
			(node as BTConditionDecorator).child_condition = c
	return node

# ====== Public entrypoints ======
func build_tree_from_json_text(json_text: String, ctx_path: String = "res://") -> BTTree:
	_file_cache.clear()
	_include_stack.clear()

	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[BTJsonFactory] Invalid JSON root")
		return null

	# Top-level defaults (common for files with direct root content)
	var root_dict = _clone(parsed)
	var top_defaults := _extract_defaults_inplace(root_dict)

	# 1) Expand with top defaults
	var expanded_root = _expand_params(root_dict, top_defaults)
	# 2) Resolve embeds (includes/subtrees), passing top defaults down
	var resolved = _resolve_embeds(expanded_root, ctx_path, top_defaults)

	var root_node := _build_node_from_json(resolved)
	return BTTree.new(root_node) if root_node else null

func build_tree_from_file(path: String, default_params: Dictionary = {}) -> BTTree:
	_file_cache.clear()
	_include_stack.clear()

	if not FileAccess.file_exists(path):
		push_error("[BTJsonFactory] File not found: %s" % path)
		return null

	var rec := _load_json_file(path)
	var root_dict: Dictionary = _clone(rec.get("json", {}))

	# Top-level defaults at file root
	var top_defaults := _extract_defaults_inplace(root_dict)

	var merged_defaults := _merge_params(top_defaults, default_params)
	# 1) Expand with top defaults
	var expanded_root = _expand_params(root_dict, merged_defaults)
	
	# 2) Resolve embeds with those defaults
	var resolved = _resolve_embeds(expanded_root, path, merged_defaults)

	var root_node := _build_node_from_json(resolved)
	return BTTree.new(root_node) if root_node else null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		#print_debug("Delete BTJsonFactory")
		pass
