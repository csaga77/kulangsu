@tool
class_name CharacterModelCatalog3D
extends RefCounted

const MODEL_MALE: PackedScene = preload("res://assets/characters/male.glb")
const MODEL_FEMALE: PackedScene = preload("res://assets/characters/female.glb")
const MODEL_TEEN: PackedScene = preload("res://assets/characters/boy.glb")


static func resolve_player_model(profile: Dictionary) -> PackedScene:
	var body_frame_id := String(profile.get("body_frame_id", "adult"))
	var presentation_id := String(profile.get("presentation_id", "masculine"))
	if body_frame_id in ["teen", "child"]:
		return MODEL_TEEN
	if presentation_id == "feminine":
		return MODEL_FEMALE
	return MODEL_MALE


static func resolve_resident_model(definition: ResidentDefinition) -> PackedScene:
	if definition == null or definition.appearance == null:
		return MODEL_MALE

	match definition.appearance.body_type:
		"female", "pregnant":
			return MODEL_FEMALE
		"teen", "child":
			return MODEL_TEEN
		_:
			return MODEL_MALE


static func model_id_for_player(profile: Dictionary) -> String:
	var model := resolve_player_model(profile)
	if model == MODEL_FEMALE:
		return "female"
	if model == MODEL_TEEN:
		return "teen"
	return "male"
