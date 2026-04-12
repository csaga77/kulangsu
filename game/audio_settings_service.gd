class_name AudioSettingsService
extends RefCounted

const MASTER_BUS_NAME := &"Master"
const BGM_BUS_NAME := &"BGM"
const DEFAULT_MASTER_VOLUME_PERCENT := 100.0
const DEFAULT_MUSIC_VOLUME_PERCENT := 100.0
const DEFAULT_PROMPT_VOLUME_PERCENT := 100.0
const DEFAULT_DIALOGUE_TEXT_SPEED_PERCENT := 100.0
const DEFAULT_DIALOGUE_TEXT_CHARACTERS_PER_SECOND := 120.0
const MIN_DIALOGUE_TEXT_SPEED_PERCENT := 25.0
const MAX_DIALOGUE_TEXT_SPEED_PERCENT := 200.0

var m_owner: Node = null
var m_master_volume_percent := DEFAULT_MASTER_VOLUME_PERCENT
var m_music_volume_percent := DEFAULT_MUSIC_VOLUME_PERCENT
var m_prompt_volume_percent := DEFAULT_PROMPT_VOLUME_PERCENT
var m_dialogue_text_speed_percent := DEFAULT_DIALOGUE_TEXT_SPEED_PERCENT


func _init(owner: Node) -> void:
	m_owner = owner


func apply_runtime_settings() -> void:
	_apply_bus_volume(MASTER_BUS_NAME, m_master_volume_percent)
	_apply_bus_volume(BGM_BUS_NAME, m_music_volume_percent)


func get_master_volume_percent() -> float:
	return m_master_volume_percent


func set_master_volume_percent(new_percent: float) -> void:
	var normalized_percent := clampf(new_percent, 0.0, 100.0)
	if is_equal_approx(m_master_volume_percent, normalized_percent):
		return

	m_master_volume_percent = normalized_percent
	_apply_bus_volume(MASTER_BUS_NAME, m_master_volume_percent)
	m_owner.master_volume_changed.emit(m_master_volume_percent)


func get_music_volume_percent() -> float:
	return m_music_volume_percent


func set_music_volume_percent(new_percent: float) -> void:
	var normalized_percent := clampf(new_percent, 0.0, 100.0)
	if is_equal_approx(m_music_volume_percent, normalized_percent):
		return

	m_music_volume_percent = normalized_percent
	_apply_bus_volume(BGM_BUS_NAME, m_music_volume_percent)
	m_owner.music_volume_changed.emit(m_music_volume_percent)


func get_prompt_volume_percent() -> float:
	return m_prompt_volume_percent


func set_prompt_volume_percent(new_percent: float) -> void:
	var normalized_percent := clampf(new_percent, 0.0, 100.0)
	if is_equal_approx(m_prompt_volume_percent, normalized_percent):
		return

	m_prompt_volume_percent = normalized_percent
	m_owner.prompt_volume_changed.emit(m_prompt_volume_percent)


func get_dialogue_text_speed_percent() -> float:
	return m_dialogue_text_speed_percent


func set_dialogue_text_speed_percent(new_percent: float) -> void:
	var normalized_percent := clampf(
		new_percent,
		MIN_DIALOGUE_TEXT_SPEED_PERCENT,
		MAX_DIALOGUE_TEXT_SPEED_PERCENT
	)
	if is_equal_approx(m_dialogue_text_speed_percent, normalized_percent):
		return

	m_dialogue_text_speed_percent = normalized_percent
	m_owner.dialogue_text_speed_changed.emit(
		m_dialogue_text_speed_percent,
		get_dialogue_text_characters_per_second()
	)


func get_dialogue_text_characters_per_second() -> float:
	return DEFAULT_DIALOGUE_TEXT_CHARACTERS_PER_SECOND * (m_dialogue_text_speed_percent / 100.0)


func get_prompt_volume_db(base_volume_db: float = 0.0) -> float:
	return _scale_db_from_percent(m_prompt_volume_percent, base_volume_db)


func _apply_bus_volume(bus_name: StringName, volume_percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	AudioServer.set_bus_volume_db(bus_index, _scale_db_from_percent(volume_percent))


func _scale_db_from_percent(volume_percent: float, base_volume_db: float = 0.0) -> float:
	var normalized_volume := maxf(volume_percent / 100.0, 0.0)
	if normalized_volume <= 0.0001:
		return -80.0
	return base_volume_db + linear_to_db(normalized_volume)
