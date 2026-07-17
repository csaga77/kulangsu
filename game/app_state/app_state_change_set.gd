class_name AppStateChangeSet
extends RefCounted

enum Domain {
	SESSION = 1 << 0,
	STORY = 1 << 1,
	TIME = 1 << 2,
	MELODY = 1 << 3,
	LANDMARKS = 1 << 4,
	RESIDENTS = 1 << 5,
	PLAYER = 1 << 6,
	SETTINGS = 1 << 7,
	CHECKPOINT = 1 << 8,
	SAVE = 1 << 9,
}

var domains := 0
var resident_ids := PackedStringArray()
var melody_ids := PackedStringArray()
var landmark_ids := PackedStringArray()


func has_domain(domain: int) -> bool:
	return domains & domain != 0


func mark(domain: int) -> void:
	domains |= domain


func is_empty() -> bool:
	return domains == 0
