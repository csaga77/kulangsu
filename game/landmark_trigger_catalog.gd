class_name LandmarkTriggerCatalog
extends RefCounted

const LANDMARK_IDS := [
	"piano_ferry",
	"trinity_church",
	"bi_shan_tunnel",
	"long_shan_tunnel",
	"bagua_tower",
	"festival_stage",
]

const TRIGGER_IDS_BY_LANDMARK := {
	"piano_ferry": ["harbor_refrain"],
	"trinity_church": ["steps", "garden", "yard", "choir_chime"],
	"bi_shan_tunnel": ["echo_a", "echo_b", "echo_c", "chamber"],
	"long_shan_tunnel": ["tunnel_entry", "light_pocket_south", "light_pocket_north", "tunnel_exit"],
	"bagua_tower": ["synthesis_chamber"],
	"festival_stage": ["harbor_stage"],
}


static func get_landmark_ids() -> Array[String]:
	return _normalize_string_array(LANDMARK_IDS)


static func get_valid_trigger_ids(landmark_id: String) -> Array[String]:
	return _normalize_string_array(TRIGGER_IDS_BY_LANDMARK.get(landmark_id, []))


static func has_landmark_id(landmark_id: String) -> bool:
	return LANDMARK_IDS.has(landmark_id)


static func has_valid_trigger_id(
	landmark_id: String,
	trigger_id: String,
	allow_empty: bool = true
) -> bool:
	if trigger_id.is_empty():
		return allow_empty
	return get_valid_trigger_ids(landmark_id).find(trigger_id) >= 0


static func build_landmark_enum_hint(include_unset: bool = true) -> String:
	var options: Array[String] = []
	if include_unset:
		options.append("Unset:")
	options.append_array(get_landmark_ids())
	return ",".join(options)


static func build_trigger_enum_hint(landmark_id: String, include_unset: bool = true) -> String:
	var options: Array[String] = []
	if include_unset:
		options.append("Unset:")
	options.append_array(get_valid_trigger_ids(landmark_id))
	return ",".join(options)


static func _normalize_string_array(values: Array) -> Array[String]:
	var normalized: Array[String] = []
	for value in values:
		normalized.append(String(value))
	return normalized
