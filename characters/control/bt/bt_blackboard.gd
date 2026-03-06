
class_name BTBlackboard
extends Resource

@export var data := {}

func get_value(key: String, default_value:Variant = null) -> Variant:
	return (data[key] if data.has(key) else default_value)

func set_value(key: String, value) -> void:
	data[key] = value

func get_time_since(key: String, now: float, default_if_absent:=INF) -> float:
	if not data.has(key):
		return default_if_absent
	return max(0.0, now - float(data[key]))

func stamp(key: String, now: float) -> void:
	data[key] = now
