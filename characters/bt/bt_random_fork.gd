# BTRandomFork.gd
# Chooses one child at open and ticks only that child until it finishes.
class_name BTRandomFork
extends BTComposite

@export var use_weights: bool = false
@export var weights: Array[float] = []   # if empty or too short, defaults to uniform

func get_last_executed_path() -> String:
	return str(self) + ("/" + m_last_child.get_last_executed_path()) if m_last_child else ""

var m_last_child: BTNode = null

func _type_name() -> String:
	return "BTRandomSelector"

func _open(_ctx) -> void:
	if children.is_empty():
		m_running_child = -1
		return
	if use_weights:
		m_running_child = _pick_weighted_index()
	else:
		m_running_child = randi() % children.size()

func _pick_weighted_index() -> int:
	var total := 0.0
	for w in weights:
		total += max(w, 0.0)

	if total <= 0.0:
		# fallback to uniform
		return randi() % children.size()

	var rnd := randf() * total
	var accum := 0.0
	for i in range(children.size()):
		var w :float = max(weights[i], 0.0) if (i < weights.size()) else 1.0
		accum += w
		if rnd <= accum:
			return i
	return children.size() - 1

func _tick(ctx, delta: float) -> BTTypes.Status:
	m_last_child = null
	if m_running_child >= 0 and m_running_child < children.size():
		m_last_child = children[m_running_child]
	return m_last_child.tick(ctx, delta) if m_last_child else BTTypes.Status.FAILURE
