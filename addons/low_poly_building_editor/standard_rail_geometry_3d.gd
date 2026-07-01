@tool
extends RefCounted

# Shared post-and-bar rail geometry used by the standalone Rail3D tool and by
# Stairs3D's optional side rails. Geometry is authored in a canonical local
# frame -- u (run distance along the rail), h (height), s (side/thickness
# offset) -- and embedded into the caller's own space through explicit
# run/up/side axes plus a linear height "rise" applied across the run. Rise
# 0.0 reproduces a level standard rail; a nonzero rise produces a straight
# raked rail following a sloped run (for example, alongside a stairs
# footprint) without duplicating the post/bar assembly logic per caller.
#
# The rise is applied as a shear (each vertex's height gains `rise * u /
# length` before the run/up/side axes are combined), so every authored box
# face stays planar regardless of rise; exact face normals are recomputed
# from the embedded geometry rather than assumed, so lighting stays correct
# for both the level and sloped cases.
#
# Posts are the exception: each post is appended as a genuinely unsheared,
# upright box (no shear applied within its own small footprint) so its top
# and bottom edge planes stay perfectly flat instead of tilting with the
# run's rise. By default a post's flat base height follows the same rise/length
# diagonal as the bars (matching a level rail's ground plane when rise is
# 0.0); callers with a stepped run supply an explicit `post_base_heights`
# entry per post so its bottom lands exactly on the real surface (for
# example a stair tread) instead of the smooth diagonal projection. Each
# post's height is then derived, not fixed. On a level run it reaches the
# top bar's underside exactly. On a sloped run its flat top reaches the
# underside at the post's uphill edge, slightly overlapping the bar across
# the rest of the post footprint so the two volumes genuinely intersect
# instead of leaving a wedge-shaped gap. The result is clamped so it can
# never exceed the bar's own top surface even in a degenerate case where a
# very thick post would otherwise need to be taller than the bar itself.
# The post's enclosed top and hidden bottom caps are omitted; its side faces
# still terminate at that derived flat height inside the handrail and at the
# authored base plane.
#
# Every face's winding is chosen so its geometric winding normal is
# antiparallel to its stored vertex normal (Godot's front-face convention),
# but that pairing only holds as authored for a right-handed (positive
# orientation) run/up/side triple like Rail3D's own RIGHT/UP/BACK axes. A
# caller supplying a mirrored triple -- Stairs3D swaps two axes to use
# BACK/UP/RIGHT -- gets geometry with the opposite handedness, so the
# winding is reversed per quad whenever `run_axis.cross(up_axis).dot(
# side_axis)` is negative, keeping the actually-visible (non-culled) face
# on the same side as the stored normal regardless of axis permutation.


static func post_count_for_length(length: float, spacing: float) -> int:
	if length <= 0.001:
		return 0
	return maxi(ceili(length / maxf(spacing, 0.1)) + 1, 2)


static func distribute_post_ratios(length: float, spacing: float) -> PackedFloat32Array:
	var ratios := PackedFloat32Array()
	var count := post_count_for_length(length, spacing)
	if count <= 0:
		return ratios
	for post_index in range(count):
		ratios.append(float(post_index) / float(count - 1))
	return ratios


static func append_rail(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	rail_height: float,
	post_spacing: float,
	post_thickness: float,
	rail_thickness: float,
	lower_rail_height: float,
	color: Color,
	post_positions: PackedFloat32Array = PackedFloat32Array(),
	post_base_heights: PackedFloat32Array = PackedFloat32Array()
) -> void:
	if length <= 0.001:
		return

	var height := maxf(rail_height, 0.2)
	var post_size := maxf(post_thickness, 0.02)
	var bar_size := minf(maxf(rail_thickness, 0.02), height * 0.5)
	var top_bottom := maxf(height - bar_size, 0.0)

	_append_sheared_box(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise,
		Vector3(-post_size * 0.5, top_bottom, -bar_size * 0.5),
		Vector3(length + post_size * 0.5, height, bar_size * 0.5),
		color
	)

	var lower_center := clampf(lower_rail_height, bar_size * 0.5, top_bottom - bar_size * 0.5)
	if (
		lower_rail_height > 0.0001
		and top_bottom > bar_size
		and lower_center + bar_size * 0.5 < top_bottom - 0.001
	):
		_append_sheared_box(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise,
			Vector3(-post_size * 0.5, lower_center - bar_size * 0.5, -bar_size * 0.5),
			Vector3(length + post_size * 0.5, lower_center + bar_size * 0.5, bar_size * 0.5),
			color
		)

	var positions := post_positions
	if positions.is_empty():
		for ratio in distribute_post_ratios(length, post_spacing):
			positions.append(length * ratio)
	for index in range(positions.size()):
		var u := positions[index]
		var base_height := 0.0
		if index < post_base_heights.size():
			base_height = post_base_heights[index]
		elif length > 0.001:
			base_height = rise * (u / length)
		# The top bar's underside follows the run's rise, while each post
		# has a flat top. Reaching only the underside height at the post
		# center would leave a wedge-shaped gap over its uphill half.
		# Reaching the underside at the uphill edge instead makes the post
		# overlap the bar across its footprint and therefore merge visually
		# and physically. Clamp to the bar top so a thick post cannot poke
		# through the handrail.
		var half_width_shear := 0.0
		if length > 0.001:
			half_width_shear = absf(rise) * post_size * 0.5 / length
		var bar_bottom_at_u := top_bottom
		var bar_top_at_u := height
		if length > 0.001:
			bar_bottom_at_u += rise * (u / length)
			bar_top_at_u += rise * (u / length)
		var post_target_top := minf(bar_bottom_at_u + half_width_shear, bar_top_at_u)
		var post_max_local_top := maxf(bar_top_at_u - base_height, 0.0)
		var post_min_local_top := minf(post_size, post_max_local_top)
		var post_local_top := clampf(post_target_top - base_height, post_min_local_top, post_max_local_top)
		# Posts embed with zero rise: `base_height` already carries whatever
		# vertical placement is needed, so the post box itself stays a flat,
		# upright prism instead of tilting with the run's rise.
		_append_sheared_box(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, 0.0,
			Vector3(u - post_size * 0.5, base_height, -post_size * 0.5),
			Vector3(u + post_size * 0.5, base_height + post_local_top, post_size * 0.5),
			color,
			false,
			false
		)


static func tread_mid_post_positions(length: float, step_count: int) -> PackedFloat32Array:
	var positions := PackedFloat32Array()
	var steps := maxi(step_count, 1)
	if length <= 0.001:
		return positions
	var tread_depth := length / float(steps)
	for step_index in range(steps):
		positions.append(tread_depth * (float(step_index) + 0.5))
	return positions


static func tread_mid_post_base_heights(rise: float, step_count: int) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	var steps := maxi(step_count, 1)
	var rise_per_step := rise / float(steps)
	for step_index in range(steps):
		# Each post sits at the mid-depth of its tread (see
		# tread_mid_post_positions()), but its base must rest on that
		# tread's actual flat top -- the step *after* it, not the smooth
		# rise/length diagonal a mid-run position would otherwise imply.
		heights.append(rise_per_step * float(step_index + 1))
	return heights


static func _embed(
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	local_point: Vector3
) -> Vector3:
	var sheared_height := local_point.y
	if length > 0.001:
		sheared_height += rise * (local_point.x / length)
	return (
		origin
		+ run_axis * local_point.x
		+ up_axis * sheared_height
		+ side_axis * local_point.z
	)


static func _append_sheared_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	minimum: Vector3,
	maximum: Vector3,
	color: Color,
	include_top_face: bool = true,
	include_bottom_face: bool = true
) -> void:
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise, color,
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3.FORWARD
	)
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise, color,
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3.BACK
	)
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise, color,
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3.LEFT
	)
	_append_sheared_quad(
		vertices, normals, colors, indices,
		origin, run_axis, up_axis, side_axis, length, rise, color,
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3.RIGHT
	)
	if include_top_face:
		_append_sheared_quad(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise, color,
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
			Vector3.UP
		)
	if include_bottom_face:
		_append_sheared_quad(
			vertices, normals, colors, indices,
			origin, run_axis, up_axis, side_axis, length, rise, color,
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3.DOWN
		)


static func _append_sheared_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	origin: Vector3,
	run_axis: Vector3,
	up_axis: Vector3,
	side_axis: Vector3,
	length: float,
	rise: float,
	color: Color,
	local_a: Vector3,
	local_b: Vector3,
	local_c: Vector3,
	local_d: Vector3,
	reference_normal: Vector3
) -> void:
	var a := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_a)
	var b := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_b)
	var c := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_c)
	var d := _embed(origin, run_axis, up_axis, side_axis, length, rise, local_d)

	var geometric_normal := (b - a).cross(c - a)
	if geometric_normal.length_squared() <= 0.000001:
		geometric_normal = (c - a).cross(d - a)
	geometric_normal = geometric_normal.normalized()

	var reference_direction := (
		run_axis * reference_normal.x
		+ up_axis * reference_normal.y
		+ side_axis * reference_normal.z
	).normalized()

	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(d)
	var use_normal := geometric_normal if geometric_normal.dot(reference_direction) >= 0.0 else -geometric_normal
	for _index in range(4):
		normals.append(use_normal)
		colors.append(color)
	# The winding below is tuned for a right-handed (positive-orientation)
	# run/up/side triple, matching Rail3D's own RIGHT/UP/BACK axes. Stairs3D
	# passes BACK/UP/RIGHT -- an axis swap, which mirrors the triple
	# (negative orientation) -- so the same vertex order would be
	# backface-culled from the wrong side. Reversing the winding whenever
	# the supplied axes are mirrored keeps the visible (culled-in) face on
	# the same side as `use_normal` regardless of which axis permutation
	# the caller supplies.
	if run_axis.cross(up_axis).dot(side_axis) < 0.0:
		indices.append_array(PackedInt32Array([base, base + 3, base + 2, base, base + 2, base + 1]))
	else:
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
