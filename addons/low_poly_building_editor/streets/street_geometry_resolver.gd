@tool
class_name StreetGeometryResolver
extends RefCounted

const EPSILON := 0.0001
const MIN_CROSS_ANGLE_SINE := 0.05
const VERTICAL_TOLERANCE := 0.02

var m_streets: Array[Street3D] = []


func _init(streets: Array) -> void:
	for street: Variant in streets:
		if street is Street3D:
			m_streets.append(street)


func refresh_street_intersection_cuts() -> void:
	var cuts_by_street: Dictionary = {}
	for street: Street3D in m_streets:
		cuts_by_street[street] = []
	for first_index in range(m_streets.size()):
		var first := m_streets[first_index]
		var first_profile := first.get_geometry_profile()
		for second_index in range(first_index + 1, m_streets.size()):
			var second := m_streets[second_index]
			var second_profile := second.get_geometry_profile()
			_append_pair_cuts(first, first_profile, second, second_profile, cuts_by_street)
	for street: Street3D in m_streets:
		street.set_intersection_cuts(cuts_by_street.get(street, []))


func _append_pair_cuts(
	first: Street3D,
	first_profile: PackedVector3Array,
	second: Street3D,
	second_profile: PackedVector3Array,
	cuts_by_street: Dictionary
) -> void:
	for first_segment in range(first_profile.size() - 1):
		var first_a := first_profile[first_segment]
		var first_b := first_profile[first_segment + 1]
		if _segment_uses_stairs(first, first_a, first_b):
			continue
		for second_segment in range(second_profile.size() - 1):
			var second_a := second_profile[second_segment]
			var second_b := second_profile[second_segment + 1]
			if _segment_uses_stairs(second, second_a, second_b):
				continue
			var hit := _segment_intersection(first_a, first_b, second_a, second_b)
			if hit.is_empty():
				continue
			var first_t := float(hit["first_t"])
			var second_t := float(hit["second_t"])
			var first_height := lerpf(first_a.y, first_b.y, first_t)
			var second_height := lerpf(second_a.y, second_b.y, second_t)
			if absf(first_height - second_height) > VERTICAL_TOLERANCE:
				continue
			var first_through := first_t > EPSILON and first_t < 1.0 - EPSILON
			var second_through := second_t > EPSILON and second_t < 1.0 - EPSILON
			var first_clips_road := second_through and !first_through
			var second_clips_road := first_through and !second_through
			if first_through and second_through:
				# Scene order owns the coplanar crossing surface, matching wall/roof
				# clipping ownership while both authored paths remain intact.
				second_clips_road = true
			_append_cut(
				cuts_by_street[first], first_segment, first_t,
				second.road_width * 0.5, float(hit["angle_sine"]),
				_plan_length(first_a, first_b), first_clips_road
			)
			_append_cut(
				cuts_by_street[second], second_segment, second_t,
				first.road_width * 0.5, float(hit["angle_sine"]),
				_plan_length(second_a, second_b), second_clips_road
			)


func _append_cut(
	cuts: Array,
	segment_index: int,
	intersection_t: float,
	other_road_half_width: float,
	angle_sine: float,
	segment_length: float,
	clip_road: bool
) -> void:
	if segment_length <= EPSILON or angle_sine < MIN_CROSS_ANGLE_SINE:
		return
	var half_t := other_road_half_width / (segment_length * angle_sine)
	cuts.append({
		"segment_index": segment_index,
		"start_t": clampf(intersection_t - half_t, 0.0, 1.0),
		"end_t": clampf(intersection_t + half_t, 0.0, 1.0),
		"clip_road": clip_road,
	})


func _segment_intersection(
	first_a: Vector3, first_b: Vector3, second_a: Vector3, second_b: Vector3
) -> Dictionary:
	var first_origin := Vector2(first_a.x, first_a.z)
	var second_origin := Vector2(second_a.x, second_a.z)
	var first_delta := Vector2(first_b.x - first_a.x, first_b.z - first_a.z)
	var second_delta := Vector2(second_b.x - second_a.x, second_b.z - second_a.z)
	var first_length := first_delta.length()
	var second_length := second_delta.length()
	if first_length <= EPSILON or second_length <= EPSILON:
		return {}
	var denominator := first_delta.cross(second_delta)
	var angle_sine := absf(denominator) / (first_length * second_length)
	if angle_sine < MIN_CROSS_ANGLE_SINE:
		return {}
	var between := second_origin - first_origin
	var first_t := between.cross(second_delta) / denominator
	var second_t := between.cross(first_delta) / denominator
	if first_t < -EPSILON or first_t > 1.0 + EPSILON:
		return {}
	if second_t < -EPSILON or second_t > 1.0 + EPSILON:
		return {}
	return {
		"first_t": clampf(first_t, 0.0, 1.0),
		"second_t": clampf(second_t, 0.0, 1.0),
		"angle_sine": angle_sine,
	}


func _segment_uses_stairs(street: Street3D, a: Vector3, b: Vector3) -> bool:
	var run := _plan_length(a, b)
	if run <= EPSILON:
		return false
	return rad_to_deg(atan2(absf(b.y - a.y), run)) > street.stair_threshold_degrees + EPSILON


func _plan_length(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()
