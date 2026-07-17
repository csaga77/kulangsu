class_name MemoryStorySaveRepository
extends StorySaveRepository

var payload: Dictionary = {}
var save_count := 0
var fail_saves := false


func exists() -> bool:
	return !payload.is_empty()


func clear() -> void:
	payload = {}


func load_payload() -> Dictionary:
	return payload.duplicate(true)


func save_payload(next_payload: Dictionary) -> bool:
	save_count += 1
	if fail_saves:
		return false
	payload = next_payload.duplicate(true)
	return true
