class_name StoryTimeService
extends RefCounted

const TIME_MORNING := "morning"
const TIME_AFTERNOON := "afternoon"
const TIME_EVENING := "evening"
const TIME_NIGHT := "night"

const DEFAULT_STORY_DAY := 1
const DEFAULT_WORLD_HOUR := 8.0
const HOURS_PER_DAY := 24.0
const TIME_OF_DAY_IDS := [
	TIME_MORNING,
	TIME_AFTERNOON,
	TIME_EVENING,
	TIME_NIGHT,
]
const TIME_OF_DAY_START_HOURS := {
	TIME_MORNING: 8.0,
	TIME_AFTERNOON: 13.0,
	TIME_EVENING: 17.0,
	TIME_NIGHT: 21.0,
}
const TIME_OF_DAY_DISPLAY_NAMES := {
	TIME_MORNING: "Morning",
	TIME_AFTERNOON: "Afternoon",
	TIME_EVENING: "Evening",
	TIME_NIGHT: "Night",
}

var m_owner: Node = null


func _init(owner: Node) -> void:
	m_owner = owner


static func default_time_state() -> Dictionary:
	return {
		"story_day": DEFAULT_STORY_DAY,
		"world_hour": DEFAULT_WORLD_HOUR,
		"time_of_day": time_of_day_for_hour(DEFAULT_WORLD_HOUR),
	}


static func time_of_day_ids() -> PackedStringArray:
	return PackedStringArray(TIME_OF_DAY_IDS)


static func normalize_story_day(value: Variant) -> int:
	return maxi(int(value), DEFAULT_STORY_DAY)


static func normalize_world_hour(value: Variant) -> float:
	var hour := float(value)
	while hour < 0.0:
		hour += HOURS_PER_DAY
	while hour >= HOURS_PER_DAY:
		hour -= HOURS_PER_DAY
	return hour


static func normalize_time_of_day(value: Variant) -> String:
	var normalized := String(value).strip_edges().to_lower()
	if TIME_OF_DAY_IDS.has(normalized):
		return normalized
	return time_of_day_for_hour(DEFAULT_WORLD_HOUR)


static func time_of_day_for_hour(hour_value: float) -> String:
	var hour := normalize_world_hour(hour_value)
	if hour >= 5.0 and hour < 12.0:
		return TIME_MORNING
	if hour >= 12.0 and hour < 17.0:
		return TIME_AFTERNOON
	if hour >= 17.0 and hour < 21.0:
		return TIME_EVENING
	return TIME_NIGHT


static func display_name(time_of_day: String) -> String:
	var normalized := normalize_time_of_day(time_of_day)
	return String(TIME_OF_DAY_DISPLAY_NAMES.get(normalized, "Time"))


static func normalize_time_state(value: Variant) -> Dictionary:
	var incoming: Dictionary = {}
	if value is Dictionary:
		incoming = (value as Dictionary)
	var default_state := default_time_state()
	var hour := normalize_world_hour(incoming.get("world_hour", default_state.get("world_hour", DEFAULT_WORLD_HOUR)))
	return {
		"story_day": normalize_story_day(incoming.get("story_day", default_state.get("story_day", DEFAULT_STORY_DAY))),
		"world_hour": hour,
		"time_of_day": time_of_day_for_hour(hour),
	}


static func hour_is_in_range(hour_value: float, min_hour_value: Variant, max_hour_value: Variant) -> bool:
	var hour := normalize_world_hour(hour_value)
	var min_hour := normalize_world_hour(min_hour_value)
	var max_hour := normalize_world_hour(max_hour_value)
	if min_hour <= max_hour:
		return hour >= min_hour and hour <= max_hour
	return hour >= min_hour or hour <= max_hour


func reset_time_state() -> void:
	set_time_state(default_time_state())


func get_time_state() -> Dictionary:
	return {
		"story_day": normalize_story_day(m_owner.story_day),
		"world_hour": normalize_world_hour(m_owner.world_hour),
		"time_of_day": time_of_day_for_hour(float(m_owner.world_hour)),
	}


func set_time_state(value: Variant) -> bool:
	var normalized := normalize_time_state(value)
	if m_owner.story_day == int(normalized.get("story_day", DEFAULT_STORY_DAY)) \
	and is_equal_approx(m_owner.world_hour, float(normalized.get("world_hour", DEFAULT_WORLD_HOUR))) \
	and m_owner.time_of_day == String(normalized.get("time_of_day", TIME_MORNING)):
		return false

	m_owner.story_day = int(normalized.get("story_day", DEFAULT_STORY_DAY))
	m_owner.world_hour = float(normalized.get("world_hour", DEFAULT_WORLD_HOUR))
	m_owner.time_of_day = String(normalized.get("time_of_day", TIME_MORNING))
	m_owner._emit_story_time_changed(get_time_state())
	return true


func advance_hours(hours: float) -> bool:
	var amount := maxf(hours, 0.0)
	if is_zero_approx(amount):
		return false

	var next_hour := normalize_world_hour(m_owner.world_hour)
	var day_delta := 0
	next_hour += amount
	while next_hour >= HOURS_PER_DAY:
		next_hour -= HOURS_PER_DAY
		day_delta += 1

	return set_time_state({
		"story_day": normalize_story_day(m_owner.story_day) + day_delta,
		"world_hour": next_hour,
	})


func advance_day(days: int = 1, target_hour: float = DEFAULT_WORLD_HOUR) -> bool:
	var day_delta := maxi(days, 1)
	return set_time_state({
		"story_day": normalize_story_day(m_owner.story_day) + day_delta,
		"world_hour": normalize_world_hour(target_hour),
	})


func advance_to_time_of_day(target_time_of_day: String) -> bool:
	var normalized_target := normalize_time_of_day(target_time_of_day)
	if normalized_target == m_owner.time_of_day:
		return false

	var target_hour := float(TIME_OF_DAY_START_HOURS.get(normalized_target, DEFAULT_WORLD_HOUR))
	var next_day := normalize_story_day(m_owner.story_day)
	if target_hour <= normalize_world_hour(m_owner.world_hour):
		next_day += 1

	return set_time_state({
		"story_day": next_day,
		"world_hour": target_hour,
	})


func apply_time_effects(payload: Dictionary) -> bool:
	var changed := false
	var time_payload: Dictionary = {}
	var nested_time_payload = payload.get("advance_time", {})
	if nested_time_payload is Dictionary:
		time_payload = (nested_time_payload as Dictionary).duplicate(true)

	if payload.has("story_day"):
		time_payload["story_day"] = payload.get("story_day")
	if payload.has("world_hour"):
		time_payload["world_hour"] = payload.get("world_hour")
	if payload.has("advance_hours"):
		time_payload["advance_hours"] = payload.get("advance_hours")
	if payload.has("advance_to_time_of_day"):
		time_payload["advance_to_time_of_day"] = payload.get("advance_to_time_of_day")
	if payload.has("advance_day"):
		time_payload["advance_day"] = payload.get("advance_day")

	if time_payload.has("story_day") or time_payload.has("world_hour"):
		var next_state := get_time_state()
		if time_payload.has("story_day"):
			next_state["story_day"] = time_payload.get("story_day")
		if time_payload.has("world_hour"):
			next_state["world_hour"] = time_payload.get("world_hour")
		changed = set_time_state(next_state) or changed

	if time_payload.has("advance_hours"):
		changed = advance_hours(float(time_payload.get("advance_hours", 0.0))) or changed

	if time_payload.has("advance_to_time_of_day"):
		changed = advance_to_time_of_day(String(time_payload.get("advance_to_time_of_day", ""))) or changed

	if time_payload.has("advance_day"):
		changed = advance_day(int(time_payload.get("advance_day", 1))) or changed

	return changed
