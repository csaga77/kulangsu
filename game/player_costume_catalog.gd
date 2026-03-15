class_name PlayerCostumeCatalog
extends RefCounted

const DEFAULT_COSTUME_ID := "harbor_arrival"

const ORDER := [
	"harbor_arrival",
	"choir_visit",
	"tunnel_weather",
	"festival_evening",
]


static func ordered_ids() -> PackedStringArray:
	return PackedStringArray(ORDER)


static func default_costume_id() -> String:
	return DEFAULT_COSTUME_ID


static func build_catalog() -> Dictionary:
	return {
		"harbor_arrival": _costume(
			"Harbor Arrival",
			"The everyday travel layers the newcomer wears stepping off the ferry.",
			"Always available.",
			_arrival_selections()
		),
		"choir_visit": _costume(
			"Choir Visit",
			"A neater coat and scarf for slower conversations and indoor listening.",
			"Unlocked after earning trust with Choir Caretaker Mei.",
			_choir_selections()
		),
		"tunnel_weather": _costume(
			"Tunnel Weather",
			"A cape-and-bandana layer set for damp routes and echo-heavy crossings.",
			"Unlocked after helping Tunnel Guide Ren or recovering two melody fragments.",
			_tunnel_selections()
		),
		"festival_evening": _costume(
			"Festival Evening",
			"A formal sash, scarf, and hat kept for the restored island performance.",
			"Unlocked once the full festival melody is restored.",
			_festival_selections()
		),
	}


static func build_unlocked_costume_ids(
	mode: String,
	fragments_found: int,
	fragments_total: int,
	resident_profiles: Dictionary
) -> PackedStringArray:
	var unlocked := PackedStringArray()

	for costume_id in ORDER:
		if is_costume_unlocked(costume_id, mode, fragments_found, fragments_total, resident_profiles):
			unlocked.append(costume_id)

	if unlocked.is_empty():
		unlocked.append(DEFAULT_COSTUME_ID)

	return unlocked


static func is_costume_unlocked(
	costume_id: String,
	mode: String,
	fragments_found: int,
	fragments_total: int,
	resident_profiles: Dictionary
) -> bool:
	if mode == "Free Walk":
		return true

	match costume_id:
		"harbor_arrival":
			return true
		"choir_visit":
			return _resident_trust(resident_profiles, "church_caretaker") > 0
		"tunnel_weather":
			return _resident_trust(resident_profiles, "tunnel_guide") > 0 or fragments_found >= 2
		"festival_evening":
			return mode == "Postgame" or (fragments_total > 0 and fragments_found >= fragments_total)
		_:
			return false


static func _costume(
	display_name: String,
	summary: String,
	unlock_hint: String,
	selections: Dictionary
) -> Dictionary:
	return {
		"display_name": display_name,
		"summary": summary,
		"unlock_hint": unlock_hint,
		"selections": selections.duplicate(true),
	}


static func _arrival_selections() -> Dictionary:
	return {
		"torso/shirts/longsleeve/torso_clothes_longsleeve": "teal",
		"legs/pants/legs_pants": "charcoal",
		"feet/shoes/feet_shoes_basic": "brown",
		"torso/backpack/backpack": "leather",
	}


static func _choir_selections() -> Dictionary:
	return {
		"torso/shirts/longsleeve/torso_clothes_longsleeve": "white",
		"legs/pants/legs_pants": "navy",
		"feet/shoes/feet_shoes_basic": "black",
		"head/neck/neck_scarf": "blue",
	}


static func _tunnel_selections() -> Dictionary:
	return {
		"torso/shirts/longsleeve/torso_clothes_longsleeve": "charcoal",
		"legs/pants/legs_pants": "brown",
		"feet/boots/feet_boots_basic": "brown",
		"headwear/coverings/bandana/hat_bandana": "charcoal",
		"torso/cape/cape_solid": "forest",
	}


static func _festival_selections() -> Dictionary:
	return {
		"torso/shirts/longsleeve/torso_clothes_longsleeve": "white",
		"legs/pants/legs_pants": "navy",
		"feet/shoes/feet_shoes_basic": "black",
		"headwear/hats/formal/hat_formal_bowler": "black",
		"torso/waist/belt_sash": "yellow",
		"head/neck/neck_scarf": "red",
	}


static func _resident_trust(resident_profiles: Dictionary, resident_id: String) -> int:
	var resident: Dictionary = resident_profiles.get(resident_id, {})
	return int(resident.get("trust", 0))
