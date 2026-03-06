# BTNode.gd
class_name BTNode
extends RefCounted

@export var name: String = ""
@export var last_status := BTTypes.Status.SUCCESS

func get_last_executed_path() -> String:
	return str(self) + ":" + str(last_status)

func tick(ctx, delta: float) -> BTTypes.Status:
	if not m_is_open:
		_open(ctx)
		m_is_open = true
	last_status = _tick(ctx, delta)
	#print(_type_name())
	if last_status != BTTypes.Status.RUNNING and m_is_open:
		_close(ctx)
		m_is_open = false
	return last_status

func abort(ctx) -> void:
	if m_is_open:
		_close(ctx)
		m_is_open = false

# --- private ---
var m_is_open: bool = false
var m_last_executed_path: Array[BTNode]

# --- Overridables ---
func _type_name() -> String: 
	return "BTNode"

func _to_string() -> String:
	return _type_name() if name.is_empty() else name

func _open(_ctx) -> void: pass
func _tick(_ctx, _delta: float) -> BTTypes.Status: return BTTypes.Status.SUCCESS
func _close(_ctx) -> void: pass
