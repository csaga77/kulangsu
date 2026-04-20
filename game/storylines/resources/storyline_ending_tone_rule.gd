@tool
class_name StorylineEndingToneRule
extends Resource
## A single ending-tone rule: if the route's weighted completion score reaches
## [member min_score], the [member tag] is added to the ending tone set.
## Optionally gates on a minimum number of helped residents.

@export var min_score: int = 1
@export var tag: String = ""
## Set to -1 (the default) to ignore the helped-resident count.
@export var helped_residents_min: int = -1
## Set to -1 (the default) to ignore the max-trust-resident count.
@export var max_trust_residents_min: int = -1


## Returns a plain Dictionary in the format expected by [StoryRouteGraph].
func to_dict() -> Dictionary:
	var d: Dictionary = {"min_score": min_score, "tag": tag}
	if helped_residents_min >= 0:
		d["helped_residents_min"] = helped_residents_min
	if max_trust_residents_min >= 0:
		d["max_trust_residents_min"] = max_trust_residents_min
	return d


## Returns a list of validation warnings for this rule.
func validate() -> PackedStringArray:
	var warnings := PackedStringArray()
	if tag.strip_edges().is_empty():
		warnings.append("ending tone rule is missing a tag")
	if min_score <= 0:
		warnings.append("min_score should be at least 1 (current: %d)" % min_score)
	if helped_residents_min < -1:
		warnings.append("helped_residents_min should be -1 or greater")
	if max_trust_residents_min < -1:
		warnings.append("max_trust_residents_min should be -1 or greater")
	return warnings


## Builds a typed ending-tone rule from a runtime Dictionary.
static func from_dict(value: Dictionary) -> StorylineEndingToneRule:
	var rule := StorylineEndingToneRule.new()
	rule.min_score = int(value.get("min_score", 1))
	rule.tag = String(value.get("tag", "")).strip_edges()
	rule.helped_residents_min = int(value.get("helped_residents_min", -1))
	rule.max_trust_residents_min = int(value.get("max_trust_residents_min", -1))
	return rule
