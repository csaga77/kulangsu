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


func apply_runtime_settings(master_volume_percent: float, music_volume_percent: float) -> void:
	apply_master_volume(master_volume_percent)
	apply_music_volume(music_volume_percent)


func normalize_volume_percent(value: float) -> float:
	return clampf(value, 0.0, 100.0)


func normalize_dialogue_text_speed_percent(value: float) -> float:
	return clampf(
		value,
		MIN_DIALOGUE_TEXT_SPEED_PERCENT,
		MAX_DIALOGUE_TEXT_SPEED_PERCENT
	)


func apply_master_volume(volume_percent: float) -> void:
	_apply_bus_volume(MASTER_BUS_NAME, normalize_volume_percent(volume_percent))


func apply_music_volume(volume_percent: float) -> void:
	_apply_bus_volume(BGM_BUS_NAME, normalize_volume_percent(volume_percent))


func get_dialogue_text_characters_per_second(speed_percent: float) -> float:
	return DEFAULT_DIALOGUE_TEXT_CHARACTERS_PER_SECOND * (
		normalize_dialogue_text_speed_percent(speed_percent) / 100.0
	)


func get_prompt_volume_db(volume_percent: float, base_volume_db: float = 0.0) -> float:
	return _scale_db_from_percent(normalize_volume_percent(volume_percent), base_volume_db)


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
