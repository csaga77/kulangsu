class_name BTRandomTimeoutCondition
extends BTCondition

## For how long (seconds) does the current outcome stick?
@export_range(0.0, 9999.0, 0.01) var min_duration: float = 1.0
@export_range(0.0, 9999.0, 0.01) var max_duration: float = 3.0

## Probability that the condition returns SUCCESS (true) during a window.
@export var possibility: float = 0.5
@export var timeout_result: bool = false

var m_until: float = -INF
var m_initialized: bool = false
var m_has_time_out: bool = false
var m_succeed: bool = true

func _type_name() -> String:
	return "BTRandomTimeoutCondition"

func _refresh(now: float) -> void:
	m_succeed = randf() < clamp(possibility, 0, 1.0)
	var lo :float = min(min_duration, max_duration)
	var hi :float = max(min_duration, max_duration)
	var dur := randf_range(lo, hi)
	m_until = now + maxf(0.0, dur)

func _open(_ctx):
	if m_has_time_out:
		m_initialized = false
		m_has_time_out = false

func test(ctx) -> bool:
	var now = ctx.get_time_stamp()

	if not m_initialized:
		_refresh(now)
		m_initialized = true

	if now >= m_until:
		m_has_time_out = true
		return timeout_result

	return m_succeed
