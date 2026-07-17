class_name StorySaveRepository
extends RefCounted

const DEFAULT_PATH := "user://story_autosave.save"

var m_path := DEFAULT_PATH


func _init(path: String = DEFAULT_PATH) -> void:
	set_path(path)


func set_path(path: String) -> void:
	m_path = path.strip_edges()
	if m_path.is_empty():
		m_path = DEFAULT_PATH


func get_path() -> String:
	return m_path


func exists() -> bool:
	return FileAccess.file_exists(m_path)


func clear() -> void:
	if exists():
		DirAccess.remove_absolute(m_path)


func load_payload() -> Dictionary:
	if !exists():
		return {}
	var file := FileAccess.open(m_path, FileAccess.READ)
	if file == null:
		return {}
	var payload: Variant = file.get_var(false)
	if payload is Dictionary:
		return (payload as Dictionary).duplicate(true)
	return {}


func save_payload(payload: Dictionary) -> bool:
	var file := FileAccess.open(m_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(payload.duplicate(true), false)
	file.flush()
	return true
