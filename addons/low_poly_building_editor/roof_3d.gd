@tool
class_name ProceduralRoof3D
extends MeshInstance3D

const GENERATED_META := &"procedural_roof_generated"
const PREVIEW_META := &"building_editor_preview"
const STYLE_FLAT := "flat"
const STYLE_SHED := "shed"
const STYLE_GABLE := "gable"
const STYLE_HIP := "hip"
const VALID_STYLES := [STYLE_FLAT, STYLE_SHED, STYLE_GABLE, STYLE_HIP]
const RECT_EPSILON := 0.001
const MAX_ROOF_ANGLE_DEGREES := 89.0
const TRIANGLE_WIREFRAME_NODE_NAME := "RoofTriangleWireframe"

@export var rebuild := false:
	set(value):
		if !value:
			return
		call_deferred("rebuild_roof_mesh")

@export var start_point := Vector3.ZERO:
	set(value):
		if start_point.is_equal_approx(value):
			return
		start_point = value
		_request_rebuild()

@export var end_point := Vector3(4.0, 0.0, 4.0):
	set(value):
		if end_point.is_equal_approx(value):
			return
		end_point = value
		_request_rebuild()

@export_enum("Flat:0", "Shed:1", "Gable:2", "Hip:3") var roof_style_index := 2:
	set(value):
		var clamped_value := clampi(value, 0, VALID_STYLES.size() - 1)
		if roof_style_index == clamped_value:
			return
		roof_style_index = clamped_value
		_request_rebuild()

@export_range(0.0, 89.0, 1.0) var roof_height := 40.0:
	set(value):
		var clamped_value := _clamped_roof_angle_degrees(value)
		if is_equal_approx(roof_height, clamped_value):
			return
		roof_height = clamped_value
		_request_rebuild()

@export_range(0.02, 2.0, 0.01, "or_greater") var roof_thickness := 0.12:
	set(value):
		var clamped_value := maxf(value, 0.02)
		if is_equal_approx(roof_thickness, clamped_value):
			return
		roof_thickness = clamped_value
		_request_rebuild()

@export_range(0.0, 4.0, 0.01, "or_greater") var roof_overhang := 0.2:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(roof_overhang, clamped_value):
			return
		roof_overhang = clamped_value
		_request_rebuild()

@export_range(0.0, 20.0, 0.01, "or_greater") var hip_gable_height := 0.0:
	set(value):
		var clamped_value := maxf(value, 0.0)
		if is_equal_approx(hip_gable_height, clamped_value):
			return
		hip_gable_height = clamped_value
		_request_rebuild()

@export_range(-180.0, 180.0, 1.0) var roof_rotation_degrees := 0.0:
	set(value):
		var normalized_value := _normalize_degrees(value)
		if is_equal_approx(roof_rotation_degrees, normalized_value):
			return
		roof_rotation_degrees = normalized_value
		_request_rebuild()

@export var roof_color := Color(0.50, 0.34, 0.25, 1.0):
	set(value):
		if roof_color == value:
			return
		roof_color = value
		_request_rebuild()

@export var covered_rects: Array[Rect2] = []:
	set(value):
		covered_rects = _sanitize_covered_rects(value)
		_request_rebuild()

@export var covered_polygons: Array[PackedVector2Array] = []:
	set(value):
		covered_polygons = _sanitize_covered_polygons(value)
		_request_rebuild()

@export var build_on_ready := true
@export var generate_collision := true:
	set(value):
		if generate_collision == value:
			return
		generate_collision = value
		_request_rebuild()

@export var debug_show_triangle_wireframe := false:
	set(value):
		if debug_show_triangle_wireframe == value:
			return
		debug_show_triangle_wireframe = value
		_request_rebuild()

@export var debug_triangle_wireframe_color := Color(0.05, 0.95, 1.0, 1.0):
	set(value):
		if debug_triangle_wireframe_color == value:
			return
		debug_triangle_wireframe_color = value
		_request_rebuild()

var m_is_ready := false
var m_rebuild_queued := false


func _ready() -> void:
	m_is_ready = true
	if build_on_ready:
		rebuild_roof_mesh()


func set_roof_corners(new_start: Vector3, new_end: Vector3) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_corners_and_rotation(new_start: Vector3, new_end: Vector3, new_rotation_degrees: float) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	roof_rotation_degrees = new_rotation_degrees
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_corners_rotation_and_covers(
	new_start: Vector3,
	new_end: Vector3,
	new_rotation_degrees: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array] = []
) -> void:
	set_roof_corners_rotation_height_and_covers(
		new_start,
		new_end,
		new_rotation_degrees,
		roof_height,
		new_covered_rects,
		new_covered_polygons
	)


func set_roof_corners_rotation_height_and_covers(
	new_start: Vector3,
	new_end: Vector3,
	new_rotation_degrees: float,
	new_height: float,
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array] = []
) -> void:
	start_point = new_start
	end_point = Vector3(new_end.x, new_start.y, new_end.z)
	roof_rotation_degrees = new_rotation_degrees
	roof_height = new_height
	covered_rects = new_covered_rects
	covered_polygons = new_covered_polygons
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_covered_rects(new_covered_rects: Array[Rect2]) -> void:
	covered_rects = new_covered_rects
	covered_polygons = []
	rebuild_roof_mesh()


func set_covered_regions(
	new_covered_rects: Array[Rect2],
	new_covered_polygons: Array[PackedVector2Array]
) -> void:
	covered_rects = new_covered_rects
	covered_polygons = new_covered_polygons
	rebuild_roof_mesh()


func get_covered_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for rect in covered_rects:
		rects.append(rect)
	return rects


func get_covered_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for polygon in covered_polygons:
		polygons.append(PackedVector2Array(polygon))
	return polygons


func get_visible_footprint_rects() -> Array[Rect2]:
	var size := get_roof_size()
	if size.x <= RECT_EPSILON or size.y <= RECT_EPSILON:
		return []
	var footprint_rect := Rect2(Vector2.ZERO, size)
	var visible_footprint_rects: Array[Rect2] = []
	for render_rect in get_visible_render_rects():
		var footprint_piece := _rect_intersection(footprint_rect, render_rect)
		if _rect_has_area(footprint_piece):
			visible_footprint_rects.append(footprint_piece)
	return visible_footprint_rects


func get_roof_render_rect() -> Rect2:
	var size := get_roof_size()
	var overhang := maxf(roof_overhang, 0.0)
	return Rect2(
		Vector2(-overhang, -overhang),
		Vector2(size.x + overhang * 2.0, size.y + overhang * 2.0)
	)


func get_visible_render_rects() -> Array[Rect2]:
	var size := get_roof_size()
	if size.x <= RECT_EPSILON or size.y <= RECT_EPSILON:
		return []
	if !covered_polygons.is_empty():
		return _visible_roof_polygon_bounds(size, covered_polygons)
	return _visible_roof_rects(get_roof_render_rect(), covered_rects)


func has_visible_roof_geometry() -> bool:
	var size := get_roof_size()
	if size.x <= RECT_EPSILON or size.y <= RECT_EPSILON:
		return false
	if !covered_polygons.is_empty():
		return _has_visible_roof_polygon_area(size, covered_polygons)
	return !get_visible_render_rects().is_empty()


func set_roof_rotation_degrees(new_rotation_degrees: float) -> void:
	roof_rotation_degrees = new_rotation_degrees
	_sync_transform_from_points()
	rebuild_roof_mesh()


func set_roof_rotation_around_center(new_rotation_degrees: float) -> void:
	var size := get_roof_size()
	var center := get_roof_center_point()
	var normalized_rotation := _normalize_degrees(new_rotation_degrees)
	var rotated_anchor := center - _rotation_basis_for_degrees(normalized_rotation) * Vector3(
		size.x * 0.5,
		0.0,
		size.y * 0.5
	)
	set_roof_corners_and_rotation(
		rotated_anchor,
		rotated_anchor + Vector3(size.x, 0.0, size.y),
		normalized_rotation
	)


func set_roof_style(style: String) -> void:
	roof_style_index = _style_index_from_name(style)
	rebuild_roof_mesh()


func get_roof_style() -> String:
	return String(VALID_STYLES[clampi(roof_style_index, 0, VALID_STYLES.size() - 1)])


func get_roof_size() -> Vector2:
	return Vector2(absf(end_point.x - start_point.x), absf(end_point.z - start_point.z))


func get_roof_height_at_local_render_point(local_render_point: Vector2) -> float:
	return roof_surface_height_for_style(
		get_roof_style(),
		get_roof_size(),
		roof_overhang,
		roof_height,
		local_render_point,
		hip_gable_height
	)


func get_roof_angle_degrees() -> float:
	return _clamped_roof_angle_degrees(roof_height)


static func roof_height_for_angle_degrees(run: float, angle_degrees: float) -> float:
	return maxf(run, 0.0) * tan(deg_to_rad(_clamped_roof_angle_degrees(angle_degrees)))


static func shed_height_for_angle_degrees(depth: float, overhang: float, angle_degrees: float) -> float:
	return roof_height_for_angle_degrees(shed_roof_run_for_depth(depth, overhang), angle_degrees)


static func shed_roof_run_for_depth(depth: float, overhang: float) -> float:
	return maxf(depth, 0.0) + maxf(overhang, 0.0) * 2.0


static func gable_height_for_angle_degrees(depth: float, overhang: float, angle_degrees: float) -> float:
	return roof_height_for_angle_degrees(gable_roof_run_for_depth(depth, overhang), angle_degrees)


static func gable_roof_run_for_depth(depth: float, overhang: float) -> float:
	return maxf(maxf(depth, 0.0) * 0.5 + maxf(overhang, 0.0), 0.0)


static func hip_height_for_angle_degrees(size: Vector2, overhang: float, angle_degrees: float) -> float:
	return roof_height_for_angle_degrees(hip_roof_run_for_size(size, overhang), angle_degrees)


static func hip_roof_run_for_size(size: Vector2, overhang: float) -> float:
	var shortest_depth := minf(maxf(size.x, 0.0), maxf(size.y, 0.0))
	return maxf(shortest_depth * 0.5 + maxf(overhang, 0.0), 0.0)


static func hip_roof_ridge_points_for_size(
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> PackedVector3Array:
	var resolved_overhang := maxf(overhang, 0.0)
	var x0 := -resolved_overhang
	var x1 := maxf(size.x, 0.0) + resolved_overhang
	var z0 := -resolved_overhang
	var z1 := maxf(size.y, 0.0) + resolved_overhang
	var render_width := maxf(x1 - x0, 0.0)
	var render_depth := maxf(z1 - z0, 0.0)
	var run := minf(render_width, render_depth) * 0.5
	var height := roof_height_for_angle_degrees(run, angle_degrees)
	var ridge_extension := _hip_roof_gable_extension(run, height, angle_degrees, gable_height_from_peak)
	if render_width >= render_depth:
		var center_z := (z0 + z1) * 0.5
		return PackedVector3Array([
			Vector3(x0 + run - ridge_extension, height, center_z),
			Vector3(x1 - run + ridge_extension, height, center_z),
		])
	var center_x := (x0 + x1) * 0.5
	return PackedVector3Array([
		Vector3(center_x, height, z0 + run - ridge_extension),
		Vector3(center_x, height, z1 - run + ridge_extension),
	])


static func _hip_roof_gable_extension(
	run: float,
	roof_height: float,
	angle_degrees: float,
	gable_height_from_peak: float
) -> float:
	var clamped_drop := clampf(maxf(gable_height_from_peak, 0.0), 0.0, maxf(roof_height, 0.0))
	if clamped_drop <= RECT_EPSILON:
		return 0.0
	var slope := tan(deg_to_rad(_clamped_roof_angle_degrees(angle_degrees)))
	if slope <= RECT_EPSILON:
		return 0.0
	return minf(clamped_drop / slope, maxf(run, 0.0))


static func _hip_roof_face_polygons_for_size(
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> Array[PackedVector3Array]:
	var resolved_overhang := maxf(overhang, 0.0)
	var x0 := -resolved_overhang
	var x1 := maxf(size.x, 0.0) + resolved_overhang
	var z0 := -resolved_overhang
	var z1 := maxf(size.y, 0.0) + resolved_overhang
	var render_width := maxf(x1 - x0, 0.0)
	var render_depth := maxf(z1 - z0, 0.0)
	var run := minf(render_width, render_depth) * 0.5
	var height := roof_height_for_angle_degrees(run, angle_degrees)
	var gable_drop := clampf(maxf(gable_height_from_peak, 0.0), 0.0, height)
	var ridge_extension := _hip_roof_gable_extension(run, height, angle_degrees, gable_drop)
	var p0 := Vector3(x0, 0.0, z0)
	var p1 := Vector3(x1, 0.0, z0)
	var p2 := Vector3(x1, 0.0, z1)
	var p3 := Vector3(x0, 0.0, z1)
	var ridge_points := hip_roof_ridge_points_for_size(size, resolved_overhang, angle_degrees, gable_drop)
	var ridge_start := ridge_points[0]
	var ridge_end := ridge_points[1]
	var faces: Array[PackedVector3Array] = []
	if gable_drop <= RECT_EPSILON and ridge_start.distance_to(ridge_end) <= RECT_EPSILON:
		faces.append(PackedVector3Array([p0, ridge_start, p1]))
		faces.append(PackedVector3Array([p1, ridge_start, p2]))
		faces.append(PackedVector3Array([p2, ridge_start, p3]))
		faces.append(PackedVector3Array([p3, ridge_start, p0]))
		return faces
	if gable_drop > RECT_EPSILON and ridge_extension > RECT_EPSILON:
		var gable_base_height := height - gable_drop
		if render_width >= render_depth:
			var center_z := (z0 + z1) * 0.5
			var left_front := Vector3(ridge_start.x, gable_base_height, center_z - ridge_extension)
			var left_back := Vector3(ridge_start.x, gable_base_height, center_z + ridge_extension)
			var right_front := Vector3(ridge_end.x, gable_base_height, center_z - ridge_extension)
			var right_back := Vector3(ridge_end.x, gable_base_height, center_z + ridge_extension)
			faces.append(PackedVector3Array([left_front, ridge_start, ridge_end, right_front, p1, p0]))
			faces.append(PackedVector3Array([p1, right_front, right_back, p2]))
			faces.append(PackedVector3Array([right_back, ridge_end, ridge_start, left_back, p3, p2]))
			faces.append(PackedVector3Array([p0, p3, left_back, left_front]))
			faces.append(PackedVector3Array([left_front, left_back, ridge_start]))
			faces.append(PackedVector3Array([right_front, ridge_end, right_back]))
		else:
			var center_x := (x0 + x1) * 0.5
			var front_left := Vector3(center_x - ridge_extension, gable_base_height, ridge_start.z)
			var front_right := Vector3(center_x + ridge_extension, gable_base_height, ridge_start.z)
			var back_left := Vector3(center_x - ridge_extension, gable_base_height, ridge_end.z)
			var back_right := Vector3(center_x + ridge_extension, gable_base_height, ridge_end.z)
			faces.append(PackedVector3Array([p0, front_left, front_right, p1]))
			faces.append(PackedVector3Array([front_right, ridge_start, ridge_end, back_right, p2, p1]))
			faces.append(PackedVector3Array([p2, back_right, back_left, p3]))
			faces.append(PackedVector3Array([back_left, ridge_end, ridge_start, front_left, p0, p3]))
			faces.append(PackedVector3Array([front_left, ridge_start, front_right]))
			faces.append(PackedVector3Array([back_left, back_right, ridge_end]))
		return faces
	if render_width >= render_depth:
		faces.append(PackedVector3Array([p0, ridge_start, ridge_end, p1]))
		faces.append(PackedVector3Array([p1, ridge_end, p2]))
		faces.append(PackedVector3Array([p3, p2, ridge_end, ridge_start]))
		faces.append(PackedVector3Array([p0, p3, ridge_start]))
	else:
		faces.append(PackedVector3Array([p0, ridge_start, p1]))
		faces.append(PackedVector3Array([p1, ridge_start, ridge_end, p2]))
		faces.append(PackedVector3Array([p2, ridge_end, p3]))
		faces.append(PackedVector3Array([p0, p3, ridge_end, ridge_start]))
	return faces


static func _triangles_for_roof_face(face_vertices: PackedVector3Array) -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	if face_vertices.size() < 3:
		return triangles
	for index in range(1, face_vertices.size() - 1):
		triangles.append(PackedVector3Array([
			face_vertices[0],
			face_vertices[index],
			face_vertices[index + 1],
		]))
	return triangles


static func _plane_points_for_roof_face(face_vertices: PackedVector3Array) -> PackedVector3Array:
	for first_index in range(face_vertices.size() - 2):
		for second_index in range(first_index + 1, face_vertices.size() - 1):
			for third_index in range(second_index + 1, face_vertices.size()):
				var first := face_vertices[first_index]
				var second := face_vertices[second_index]
				var third := face_vertices[third_index]
				if (second - first).cross(third - first).length_squared() > RECT_EPSILON * RECT_EPSILON:
					return PackedVector3Array([first, second, third])
	return PackedVector3Array()


static func roof_generated_height_for_style(
	style: String,
	size: Vector2,
	overhang: float,
	angle_degrees: float
) -> float:
	match style:
		STYLE_SHED:
			return shed_height_for_angle_degrees(size.y, overhang, angle_degrees)
		STYLE_GABLE:
			return gable_height_for_angle_degrees(size.y, overhang, angle_degrees)
		STYLE_HIP:
			return hip_height_for_angle_degrees(size, overhang, angle_degrees)
	return 0.0


static func roof_surface_height_for_style(
	style: String,
	size: Vector2,
	overhang: float,
	angle_degrees: float,
	local_render_point: Vector2,
	gable_height_from_peak: float = 0.0
) -> float:
	var height := roof_generated_height_for_style(style, size, overhang, angle_degrees)
	if height <= 0.0:
		return 0.0
	var resolved_overhang := maxf(overhang, 0.0)
	var min_x := -resolved_overhang
	var max_x := size.x + resolved_overhang
	var min_z := -resolved_overhang
	var max_z := size.y + resolved_overhang
	var clamped_x := clampf(local_render_point.x, min_x, max_x)
	var clamped_z := clampf(local_render_point.y, min_z, max_z)
	match style:
		STYLE_SHED:
			return height * clampf((clamped_z - min_z) / maxf(max_z - min_z, RECT_EPSILON), 0.0, 1.0)
		STYLE_HIP:
			var run := hip_roof_run_for_size(size, resolved_overhang)
			var slope := height / maxf(run, RECT_EPSILON)
			var ridge_extension := _hip_roof_gable_extension(
				run,
				height,
				angle_degrees,
				gable_height_from_peak
			)
			var cross_distance := 0.0
			var axis_height := height
			if (max_x - min_x) >= (max_z - min_z):
				var ridge_start_x := min_x + run - ridge_extension
				var ridge_end_x := max_x - run + ridge_extension
				cross_distance = minf(clamped_z - min_z, max_z - clamped_z)
				if clamped_x < ridge_start_x - RECT_EPSILON:
					axis_height = minf(axis_height, (clamped_x - min_x) * slope)
				elif clamped_x > ridge_end_x + RECT_EPSILON:
					axis_height = minf(axis_height, (max_x - clamped_x) * slope)
			else:
				var ridge_start_z := min_z + run - ridge_extension
				var ridge_end_z := max_z - run + ridge_extension
				cross_distance = minf(clamped_x - min_x, max_x - clamped_x)
				if clamped_z < ridge_start_z - RECT_EPSILON:
					axis_height = minf(axis_height, (clamped_z - min_z) * slope)
				elif clamped_z > ridge_end_z + RECT_EPSILON:
					axis_height = minf(axis_height, (max_z - clamped_z) * slope)
			return clampf(minf(cross_distance * slope, axis_height), 0.0, height)
		STYLE_GABLE:
			var center_z := (min_z + max_z) * 0.5
			var half_depth := maxf((max_z - min_z) * 0.5, RECT_EPSILON)
			return height * clampf(1.0 - absf(clamped_z - center_z) / half_depth, 0.0, 1.0)
	return 0.0


static func roof_top_triangles_for_style(
	style: String,
	full_size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> Array[PackedVector3Array]:
	var resolved_overhang := maxf(overhang, 0.0)
	var x0 := -resolved_overhang
	var x1 := full_size.x + resolved_overhang
	var z0 := -resolved_overhang
	var z1 := full_size.y + resolved_overhang
	var center_x := (x0 + x1) * 0.5
	var center_z := (z0 + z1) * 0.5
	var height := roof_generated_height_for_style(style, full_size, resolved_overhang, angle_degrees)
	var triangles: Array[PackedVector3Array] = []
	match style:
		STYLE_SHED:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, height, z1)
			var p3 := Vector3(x0, height, z1)
			triangles.append(PackedVector3Array([p0, p3, p2]))
			triangles.append(PackedVector3Array([p0, p2, p1]))
		STYLE_HIP:
			for face_vertices in _hip_roof_face_polygons_for_size(
				full_size,
				resolved_overhang,
				angle_degrees,
				gable_height_from_peak
			):
				triangles.append_array(_triangles_for_roof_face(face_vertices))
		STYLE_GABLE:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			var ridge_left := Vector3(x0, height, center_z)
			var ridge_right := Vector3(x1, height, center_z)
			triangles.append(PackedVector3Array([p0, ridge_left, ridge_right]))
			triangles.append(PackedVector3Array([p0, ridge_right, p1]))
			triangles.append(PackedVector3Array([p3, p2, ridge_right]))
			triangles.append(PackedVector3Array([p3, ridge_right, ridge_left]))
		_:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			triangles.append(PackedVector3Array([p0, p3, p2]))
			triangles.append(PackedVector3Array([p0, p2, p1]))
	return triangles


static func roof_top_faces_for_style(
	style: String,
	full_size: Vector2,
	overhang: float,
	angle_degrees: float,
	gable_height_from_peak: float = 0.0
) -> Array[Dictionary]:
	var resolved_overhang := maxf(overhang, 0.0)
	var x0 := -resolved_overhang
	var x1 := full_size.x + resolved_overhang
	var z0 := -resolved_overhang
	var z1 := full_size.y + resolved_overhang
	var center_x := (x0 + x1) * 0.5
	var center_z := (z0 + z1) * 0.5
	var height := roof_generated_height_for_style(style, full_size, resolved_overhang, angle_degrees)
	var faces: Array[Dictionary] = []
	match style:
		STYLE_SHED:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, height, z1)
			var p3 := Vector3(x0, height, z1)
			faces.append({
				"vertices": PackedVector3Array([p0, p3, p2, p1]),
				"plane": PackedVector3Array([p0, p3, p2]),
			})
		STYLE_HIP:
			for face_vertices in _hip_roof_face_polygons_for_size(
				full_size,
				resolved_overhang,
				angle_degrees,
				gable_height_from_peak
			):
				var plane_points := _plane_points_for_roof_face(face_vertices)
				if plane_points.size() == 3:
					faces.append({"vertices": face_vertices, "plane": plane_points})
		STYLE_GABLE:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			var ridge_left := Vector3(x0, height, center_z)
			var ridge_right := Vector3(x1, height, center_z)
			faces.append({
				"vertices": PackedVector3Array([p0, ridge_left, ridge_right, p1]),
				"plane": PackedVector3Array([p0, ridge_left, ridge_right]),
			})
			faces.append({
				"vertices": PackedVector3Array([p3, p2, ridge_right, ridge_left]),
				"plane": PackedVector3Array([p3, p2, ridge_right]),
			})
		_:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			faces.append({
				"vertices": PackedVector3Array([p0, p3, p2, p1]),
				"plane": PackedVector3Array([p0, p3, p2]),
			})
	return faces


static func roof_corners_from_base_points(base_start: Vector3, base_end: Vector3, rotation_degrees: float) -> Dictionary:
	var basis := Basis(Vector3.UP, deg_to_rad(_normalize_degrees_static(rotation_degrees)))
	var flat_delta := Vector3(base_end.x - base_start.x, 0.0, base_end.z - base_start.z)
	var local_delta := basis.inverse() * flat_delta
	var min_x := minf(0.0, local_delta.x)
	var max_x := maxf(0.0, local_delta.x)
	var min_z := minf(0.0, local_delta.z)
	var max_z := maxf(0.0, local_delta.z)
	var anchor := base_start + basis * Vector3(min_x, 0.0, min_z)
	var size := Vector2(max_x - min_x, max_z - min_z)
	return {
		"start": Vector3(anchor.x, base_start.y, anchor.z),
		"end": Vector3(anchor.x + size.x, base_start.y, anchor.z + size.y),
	}


func get_roof_anchor_point() -> Vector3:
	var min_x := minf(start_point.x, end_point.x)
	var min_z := minf(start_point.z, end_point.z)
	return Vector3(min_x, start_point.y, min_z)


func get_roof_center_point() -> Vector3:
	var size := get_roof_size()
	return get_roof_anchor_point() + _rotation_basis() * Vector3(size.x * 0.5, 0.0, size.y * 0.5)


func get_roof_bounds_min() -> Vector3:
	var overhang := maxf(roof_overhang, 0.0)
	return Vector3(-overhang, -roof_thickness, -overhang)


func get_roof_bounds_max() -> Vector3:
	var size := get_roof_size()
	var overhang := maxf(roof_overhang, 0.0)
	return Vector3(size.x + overhang, _effective_roof_height(), size.y + overhang)


func rebuild_roof_mesh(rebuild_collision: bool = true) -> void:
	if rebuild_collision:
		m_rebuild_queued = false
	_sync_transform_from_points()
	if rebuild_collision:
		_clear_generated_children()

	var size := get_roof_size()
	if size.x <= 0.001 or size.y <= 0.001:
		mesh = null
		return

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var full_render_rect := get_roof_render_rect()
	var sanitized_polygons := _sanitize_covered_polygons(covered_polygons)
	if !sanitized_polygons.is_empty():
		_append_roof_polygon_clip_geometry(size, sanitized_polygons, vertices, normals, colors, indices)
	else:
		var visible_rects := get_visible_render_rects()
		if visible_rects.is_empty():
			mesh = null
			return
		if visible_rects.size() == 1 and _rects_match(visible_rects[0], full_render_rect):
			_append_roof_geometry(size.x, size.y, vertices, normals, colors, indices)
		else:
			for visible_rect in visible_rects:
				_append_roof_piece_geometry(size, visible_rect, vertices, normals, colors, indices)

	if vertices.is_empty() or indices.is_empty():
		mesh = null
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	_update_roof_mesh_resource(arrays)
	_sync_roof_material()

	if debug_show_triangle_wireframe:
		_add_triangle_wireframe(vertices, indices)

	if rebuild_collision and generate_collision:
		_add_collision_body(vertices, indices)


func _request_rebuild() -> void:
	if !m_is_ready or m_rebuild_queued:
		return
	m_rebuild_queued = true
	call_deferred("rebuild_roof_mesh")


func _sync_transform_from_points() -> void:
	transform = Transform3D(_rotation_basis(), get_roof_anchor_point())


func _rotation_basis() -> Basis:
	return _rotation_basis_for_degrees(roof_rotation_degrees)


func _rotation_basis_for_degrees(rotation_degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_normalize_degrees(rotation_degrees)))


func _normalize_degrees(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _append_roof_geometry(
	width: float,
	depth: float,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var overhang := maxf(roof_overhang, 0.0)
	var x0 := -overhang
	var x1 := width + overhang
	var z0 := -overhang
	var z1 := depth + overhang
	var center_x := (x0 + x1) * 0.5
	var center_z := (z0 + z1) * 0.5
	var height := _effective_roof_height_for_size(Vector2(width, depth))
	var top_points: Array[Vector3] = []
	var top_triangles: Array[PackedInt32Array] = []
	var boundary := PackedInt32Array()

	match get_roof_style():
		STYLE_SHED:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, height, z1),
				Vector3(x0, height, z1),
			]
			top_triangles = [PackedInt32Array([0, 3, 2]), PackedInt32Array([0, 2, 1])]
			boundary = PackedInt32Array([0, 1, 2, 3])
		STYLE_HIP:
			var p0 := Vector3(x0, 0.0, z0)
			var p1 := Vector3(x1, 0.0, z0)
			var p2 := Vector3(x1, 0.0, z1)
			var p3 := Vector3(x0, 0.0, z1)
			top_points = [p0, p1, p2, p3]
			for face_vertices in _hip_roof_face_polygons_for_size(
				Vector2(width, depth),
				overhang,
				roof_height,
				hip_gable_height
			):
				_append_roof_face_indices(face_vertices, top_points, top_triangles)
			boundary = PackedInt32Array([0, 1, 2, 3])
		STYLE_GABLE:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
				Vector3(x0, height, center_z),
				Vector3(x1, height, center_z),
			]
			top_triangles = [
				PackedInt32Array([0, 4, 5]),
				PackedInt32Array([0, 5, 1]),
				PackedInt32Array([3, 2, 5]),
				PackedInt32Array([3, 5, 4]),
			]
			boundary = PackedInt32Array([0, 1, 5, 2, 3, 4])
		_:
			top_points = [
				Vector3(x0, 0.0, z0),
				Vector3(x1, 0.0, z0),
				Vector3(x1, 0.0, z1),
				Vector3(x0, 0.0, z1),
			]
			top_triangles = [PackedInt32Array([0, 3, 2]), PackedInt32Array([0, 2, 1])]
			boundary = PackedInt32Array([0, 1, 2, 3])

	for triangle in top_triangles:
		_append_triangle_auto(
			vertices,
			normals,
			colors,
			indices,
			top_points[triangle[0]],
			top_points[triangle[1]],
			top_points[triangle[2]]
		)

	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for triangle in top_triangles:
		_append_triangle_auto(
			vertices,
			normals,
			colors,
			indices,
			top_points[triangle[0]] + bottom_offset,
			top_points[triangle[2]] + bottom_offset,
			top_points[triangle[1]] + bottom_offset
		)

	for edge_index in range(boundary.size()):
		var next_edge_index := (edge_index + 1) % boundary.size()
		var edge_start: Vector3 = top_points[boundary[edge_index]]
		var edge_end: Vector3 = top_points[boundary[next_edge_index]]
		_append_quad_auto(
			vertices,
			normals,
			colors,
			indices,
			edge_start,
			edge_end,
			edge_end + bottom_offset,
			edge_start + bottom_offset
		)


func _append_roof_face_indices(
	face_vertices: PackedVector3Array,
	top_points: Array[Vector3],
	top_triangles: Array[PackedInt32Array]
) -> void:
	if face_vertices.size() < 3:
		return
	var base_index := top_points.size()
	for point in face_vertices:
		top_points.append(point)
	for index in range(1, face_vertices.size() - 1):
		top_triangles.append(PackedInt32Array([base_index, base_index + index, base_index + index + 1]))


func _append_roof_piece_geometry(
	full_size: Vector2,
	render_rect: Rect2,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for top_triangle in _roof_top_triangles(full_size):
		var clipped_top := _clip_polygon_to_rect(top_triangle, render_rect)
		_append_polygon_triangles(clipped_top, false, vertices, normals, colors, indices)
		var clipped_bottom: Array[Vector3] = []
		for point in clipped_top:
			clipped_bottom.append(point + bottom_offset)
		_append_polygon_triangles(clipped_bottom, true, vertices, normals, colors, indices)
	_append_roof_outer_sides(full_size, render_rect, vertices, normals, colors, indices)


func _append_roof_polygon_clip_geometry(
	full_size: Vector2,
	cover_polygons: Array[PackedVector2Array],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	var visible_polygons: Array = []
	for top_triangle in _roof_top_triangles(full_size):
		var pieces: Array = [_packed_vector3_to_array(top_triangle)]
		for cover_polygon in cover_polygons:
			var next_pieces: Array = []
			for piece in pieces:
				next_pieces.append_array(_subtract_cover_polygon(piece, cover_polygon))
			pieces = next_pieces
			if pieces.is_empty():
				break
		for piece in pieces:
			if !_polygon3_has_area(piece):
				continue
			visible_polygons.append(piece)
			_append_polygon_triangles(piece, false, vertices, normals, colors, indices)
			var clipped_bottom: Array[Vector3] = []
			for point in piece:
				clipped_bottom.append(Vector3(point) + bottom_offset)
			_append_polygon_triangles(clipped_bottom, true, vertices, normals, colors, indices)
	_append_roof_polygon_boundary_sides(visible_polygons, vertices, normals, colors, indices)


func _packed_vector3_to_array(points: PackedVector3Array) -> Array[Vector3]:
	var array: Array[Vector3] = []
	for point in points:
		array.append(point)
	return array


func _subtract_cover_polygon(source_polygon: Array, cover_polygon: PackedVector2Array) -> Array:
	if source_polygon.size() < 3:
		return []
	var clip_polygon := _normalized_polygon2(cover_polygon)
	if clip_polygon.size() < 3:
		return [source_polygon]

	var remaining: Array = []
	var inside_pieces: Array = [source_polygon]
	for edge_index in range(clip_polygon.size()):
		var edge_start := clip_polygon[edge_index]
		var edge_end := clip_polygon[(edge_index + 1) % clip_polygon.size()]
		var next_inside_pieces: Array = []
		for piece in inside_pieces:
			var outside_piece := _clip_roof_polygon_by_cover_edge(piece, edge_start, edge_end, false)
			if _polygon3_has_area(outside_piece):
				remaining.append(outside_piece)
			var inside_piece := _clip_roof_polygon_by_cover_edge(piece, edge_start, edge_end, true)
			if _polygon3_has_area(inside_piece):
				next_inside_pieces.append(inside_piece)
		inside_pieces = next_inside_pieces
		if inside_pieces.is_empty():
			break
	return remaining


func _clip_roof_polygon_by_cover_edge(
	points: Array,
	edge_start: Vector2,
	edge_end: Vector2,
	keep_inside: bool
) -> Array[Vector3]:
	if points.is_empty():
		return []
	var clipped: Array[Vector3] = []
	var previous := Vector3(points[points.size() - 1])
	var previous_side := _cover_edge_side(previous, edge_start, edge_end)
	var previous_inside := previous_side >= -RECT_EPSILON
	for current_variant in points:
		var current := Vector3(current_variant)
		var current_side := _cover_edge_side(current, edge_start, edge_end)
		var current_inside := current_side >= -RECT_EPSILON
		var previous_kept := previous_inside if keep_inside else !previous_inside
		var current_kept := current_inside if keep_inside else !current_inside
		if current_kept != previous_kept:
			clipped.append(_interpolate_cover_edge_intersection(previous, current, previous_side, current_side))
		if current_kept:
			clipped.append(current)
		previous = current
		previous_side = current_side
		previous_inside = current_inside
	return _dedupe_polygon3(clipped)


func _cover_edge_side(point: Vector3, edge_start: Vector2, edge_end: Vector2) -> float:
	var edge := edge_end - edge_start
	var offset := Vector2(point.x, point.z) - edge_start
	return edge.x * offset.y - edge.y * offset.x


func _interpolate_cover_edge_intersection(
	from_point: Vector3,
	to_point: Vector3,
	from_side: float,
	to_side: float
) -> Vector3:
	var denominator := from_side - to_side
	if absf(denominator) <= RECT_EPSILON:
		return from_point
	var weight := clampf(from_side / denominator, 0.0, 1.0)
	return from_point.lerp(to_point, weight)


func _normalized_polygon2(polygon: PackedVector2Array) -> PackedVector2Array:
	var normalized := PackedVector2Array()
	for point in polygon:
		if normalized.size() > 0 and normalized[normalized.size() - 1].distance_to(point) <= RECT_EPSILON:
			continue
		normalized.append(point)
	if normalized.size() > 1 and normalized[0].distance_to(normalized[normalized.size() - 1]) <= RECT_EPSILON:
		normalized.remove_at(normalized.size() - 1)
	if _polygon2_signed_area(normalized) < 0.0:
		normalized.reverse()
	return normalized


func _dedupe_polygon3(points: Array[Vector3]) -> Array[Vector3]:
	var deduped: Array[Vector3] = []
	for point in points:
		if deduped.size() > 0 and deduped[deduped.size() - 1].distance_to(point) <= RECT_EPSILON:
			continue
		deduped.append(point)
	if deduped.size() > 1 and deduped[0].distance_to(deduped[deduped.size() - 1]) <= RECT_EPSILON:
		deduped.pop_back()
	return deduped


func _append_roof_polygon_boundary_sides(
	visible_polygons: Array,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var edge_counts := {}
	var edge_records: Array[Dictionary] = []
	for polygon in visible_polygons:
		for edge_index in range(polygon.size()):
			var edge_start := Vector3(polygon[edge_index])
			var edge_end := Vector3(polygon[(edge_index + 1) % polygon.size()])
			if edge_start.distance_to(edge_end) <= RECT_EPSILON:
				continue
			var edge_key := _roof_polygon_boundary_edge_key(edge_start, edge_end)
			edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1
			edge_records.append({
				"key": edge_key,
				"start": edge_start,
				"end": edge_end,
			})

	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for edge_record in edge_records:
		var edge_key := String(edge_record["key"])
		if int(edge_counts.get(edge_key, 0)) != 1:
			continue
		var edge_start := Vector3(edge_record["start"])
		var edge_end := Vector3(edge_record["end"])
		_append_quad_auto(
			vertices,
			normals,
			colors,
			indices,
			edge_end,
			edge_start,
			edge_start + bottom_offset,
			edge_end + bottom_offset
		)


func _roof_polygon_boundary_edge_key(first: Vector3, second: Vector3) -> String:
	var first_key := _roof_polygon_boundary_point_key(first)
	var second_key := _roof_polygon_boundary_point_key(second)
	if first_key <= second_key:
		return "%s|%s" % [first_key, second_key]
	return "%s|%s" % [second_key, first_key]


func _roof_polygon_boundary_point_key(point: Vector3) -> String:
	return "%d,%d,%d" % [
		roundi(point.x / RECT_EPSILON),
		roundi(point.y / RECT_EPSILON),
		roundi(point.z / RECT_EPSILON),
	]


func _roof_top_triangles(full_size: Vector2) -> Array[PackedVector3Array]:
	return roof_top_triangles_for_style(
		get_roof_style(),
		full_size,
		roof_overhang,
		roof_height,
		hip_gable_height
	)


func _clip_polygon_to_rect(polygon: PackedVector3Array, rect: Rect2) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point in polygon:
		points.append(point)
	points = _clip_polygon_axis(points, rect.position.x, 0, true)
	points = _clip_polygon_axis(points, rect.position.x + rect.size.x, 0, false)
	points = _clip_polygon_axis(points, rect.position.y, 2, true)
	points = _clip_polygon_axis(points, rect.position.y + rect.size.y, 2, false)
	return points


func _clip_polygon_axis(
	points: Array[Vector3],
	boundary: float,
	axis: int,
	keep_greater: bool
) -> Array[Vector3]:
	if points.is_empty():
		return []
	var clipped: Array[Vector3] = []
	var previous := points[points.size() - 1]
	var previous_inside := _is_point_inside_clip(previous, boundary, axis, keep_greater)
	for current in points:
		var current_inside := _is_point_inside_clip(current, boundary, axis, keep_greater)
		if current_inside != previous_inside:
			clipped.append(_interpolate_clip_intersection(previous, current, boundary, axis))
		if current_inside:
			clipped.append(current)
		previous = current
		previous_inside = current_inside
	return clipped


func _is_point_inside_clip(point: Vector3, boundary: float, axis: int, keep_greater: bool) -> bool:
	var value := point.x if axis == 0 else point.z
	if keep_greater:
		return value >= boundary - RECT_EPSILON
	return value <= boundary + RECT_EPSILON


func _interpolate_clip_intersection(from_point: Vector3, to_point: Vector3, boundary: float, axis: int) -> Vector3:
	var from_value := from_point.x if axis == 0 else from_point.z
	var to_value := to_point.x if axis == 0 else to_point.z
	var denominator := to_value - from_value
	if absf(denominator) <= RECT_EPSILON:
		return from_point
	var weight := clampf((boundary - from_value) / denominator, 0.0, 1.0)
	return from_point.lerp(to_point, weight)


func _append_polygon_triangles(
	polygon: Array[Vector3],
	reverse_order: bool,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if polygon.size() < 3:
		return
	for index in range(1, polygon.size() - 1):
		if reverse_order:
			_append_triangle_auto(vertices, normals, colors, indices, polygon[0], polygon[index + 1], polygon[index])
		else:
			_append_triangle_auto(vertices, normals, colors, indices, polygon[0], polygon[index], polygon[index + 1])


func _append_roof_outer_sides(
	full_size: Vector2,
	render_rect: Rect2,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var full_render_rect := get_roof_render_rect()
	var full_render_min := full_render_rect.position
	var full_render_max := full_render_rect.position + full_render_rect.size
	var render_min := render_rect.position
	var render_max := render_rect.position + render_rect.size
	if absf(render_min.y - full_render_min.y) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_min.x, render_max.x, render_min.y, true, true),
			vertices,
			normals,
			colors,
			indices
		)
	if absf(render_max.x - full_render_max.x) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_min.y, render_max.y, render_max.x, false, true),
			vertices,
			normals,
			colors,
			indices
		)
	if absf(render_max.y - full_render_max.y) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_max.x, render_min.x, render_max.y, true, true),
			vertices,
			normals,
			colors,
			indices
		)
	if absf(render_min.x - full_render_min.x) <= RECT_EPSILON:
		_append_roof_side_polyline(
			_roof_edge_points_for_axis(full_size, render_max.y, render_min.y, render_min.x, false, true),
			vertices,
			normals,
			colors,
			indices
		)


func _roof_edge_points_for_axis(
	full_size: Vector2,
	start_value: float,
	end_value: float,
	fixed_value: float,
	axis_is_x: bool,
	include_style_splits: bool
) -> Array[Vector3]:
	var values := _edge_axis_values(full_size, start_value, end_value, axis_is_x, include_style_splits)
	var points: Array[Vector3] = []
	for value in values:
		var x := value if axis_is_x else fixed_value
		var z := fixed_value if axis_is_x else value
		points.append(Vector3(x, _roof_height_at(full_size, x, z), z))
	return points


func _edge_axis_values(
	full_size: Vector2,
	start_value: float,
	end_value: float,
	axis_is_x: bool,
	include_style_splits: bool
) -> Array[float]:
	var min_value := minf(start_value, end_value)
	var max_value := maxf(start_value, end_value)
	var values: Array[float] = [start_value, end_value]
	if include_style_splits and !axis_is_x and get_roof_style() == STYLE_GABLE:
		var center_z := full_size.y * 0.5
		if center_z > min_value + RECT_EPSILON and center_z < max_value - RECT_EPSILON:
			values.append(center_z)
	values.sort()
	if start_value > end_value:
		values.reverse()
	return values


func _append_roof_side_polyline(
	points: Array[Vector3],
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	if points.size() < 2:
		return
	var bottom_offset := Vector3(0.0, -roof_thickness, 0.0)
	for index in range(points.size() - 1):
		var edge_start := points[index]
		var edge_end := points[index + 1]
		_append_quad_auto(
			vertices,
			normals,
			colors,
			indices,
			edge_start,
			edge_end,
			edge_end + bottom_offset,
			edge_start + bottom_offset
		)


func _roof_height_at(full_size: Vector2, x: float, z: float) -> float:
	return roof_surface_height_for_style(
		get_roof_style(),
		full_size,
		roof_overhang,
		roof_height,
		Vector2(x, z),
		hip_gable_height
	)


func _visible_roof_rects(full_rect: Rect2, covers: Array[Rect2]) -> Array[Rect2]:
	var visible_rects: Array[Rect2] = [full_rect]
	for cover in covers:
		var clipped_cover := _rect_intersection(full_rect, cover)
		if !_rect_has_area(clipped_cover):
			continue
		var next_visible_rects: Array[Rect2] = []
		for visible_rect in visible_rects:
			next_visible_rects.append_array(_subtract_rect(visible_rect, clipped_cover))
		visible_rects = next_visible_rects
		if visible_rects.is_empty():
			break
	return visible_rects


func _visible_roof_polygon_bounds(
	full_size: Vector2,
	covers: Array[PackedVector2Array]
) -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for polygon in _visible_roof_polygons(full_size, covers):
		var polygon_bounds := _polygon3_bounds(polygon)
		if _rect_has_area(polygon_bounds):
			bounds.append(polygon_bounds)
	return bounds


func _has_visible_roof_polygon_area(
	full_size: Vector2,
	covers: Array[PackedVector2Array]
) -> bool:
	for polygon in _visible_roof_polygons(full_size, covers):
		if _polygon3_has_area(polygon):
			return true
	return false


func _visible_roof_polygons(
	full_size: Vector2,
	covers: Array[PackedVector2Array]
) -> Array:
	var visible_polygons: Array = []
	for top_triangle in _roof_top_triangles(full_size):
		var pieces: Array = [_packed_vector3_to_array(top_triangle)]
		for cover in covers:
			var next_pieces: Array = []
			for piece in pieces:
				next_pieces.append_array(_subtract_cover_polygon(piece, cover))
			pieces = next_pieces
			if pieces.is_empty():
				break
		for piece in pieces:
			if _polygon3_has_area(piece):
				visible_polygons.append(piece)
	return visible_polygons


func _subtract_rect(source: Rect2, cover: Rect2) -> Array[Rect2]:
	var overlap := _rect_intersection(source, cover)
	if !_rect_has_area(overlap):
		return [source]

	var source_min := source.position
	var source_max := source.position + source.size
	var overlap_min := overlap.position
	var overlap_max := overlap.position + overlap.size
	var rects: Array[Rect2] = []
	_append_visible_rect(rects, Rect2(
		Vector2(source_min.x, source_min.y),
		Vector2(overlap_min.x - source_min.x, source.size.y)
	))
	_append_visible_rect(rects, Rect2(
		Vector2(overlap_max.x, source_min.y),
		Vector2(source_max.x - overlap_max.x, source.size.y)
	))
	_append_visible_rect(rects, Rect2(
		Vector2(overlap_min.x, source_min.y),
		Vector2(overlap.size.x, overlap_min.y - source_min.y)
	))
	_append_visible_rect(rects, Rect2(
		Vector2(overlap_min.x, overlap_max.y),
		Vector2(overlap.size.x, source_max.y - overlap_max.y)
	))
	return rects


func _append_visible_rect(rects: Array[Rect2], rect: Rect2) -> void:
	if _rect_has_area(rect):
		rects.append(rect)


func _rect_intersection(first: Rect2, second: Rect2) -> Rect2:
	var first_max := first.position + first.size
	var second_max := second.position + second.size
	var min_point := Vector2(maxf(first.position.x, second.position.x), maxf(first.position.y, second.position.y))
	var max_point := Vector2(minf(first_max.x, second_max.x), minf(first_max.y, second_max.y))
	return Rect2(min_point, Vector2(max_point.x - min_point.x, max_point.y - min_point.y))


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > RECT_EPSILON and rect.size.y > RECT_EPSILON


func _rects_match(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.distance_to(second.position) <= RECT_EPSILON
		and first.size.distance_to(second.size) <= RECT_EPSILON
	)


func _sanitize_covered_rects(rects: Array[Rect2]) -> Array[Rect2]:
	var sanitized: Array[Rect2] = []
	for rect in rects:
		if !_rect_has_area(rect):
			continue
		sanitized.append(rect)
	return sanitized


func _sanitize_covered_polygons(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var sanitized: Array[PackedVector2Array] = []
	for polygon in polygons:
		var normalized := _normalized_polygon2(polygon)
		if absf(_polygon2_signed_area(normalized)) <= RECT_EPSILON:
			continue
		sanitized.append(normalized)
	return sanitized


func _polygon3_bounds(polygon: Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var min_x := INF
	var min_z := INF
	var max_x := -INF
	var max_z := -INF
	for point_variant in polygon:
		var point := Vector3(point_variant)
		min_x = minf(min_x, point.x)
		min_z = minf(min_z, point.z)
		max_x = maxf(max_x, point.x)
		max_z = maxf(max_z, point.z)
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))


func _polygon3_has_area(polygon: Array) -> bool:
	if polygon.size() < 3:
		return false
	return absf(_polygon3_signed_area(polygon)) > RECT_EPSILON


func _polygon3_signed_area(polygon: Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current := Vector3(polygon[index])
		var next := Vector3(polygon[(index + 1) % polygon.size()])
		area += current.x * next.z - next.x * current.z
	return area * 0.5


func _polygon2_signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


func _effective_roof_height() -> float:
	return _effective_roof_height_for_size(get_roof_size())


func _effective_roof_height_for_size(size: Vector2) -> float:
	return roof_generated_height_for_style(get_roof_style(), size, roof_overhang, roof_height)


static func _clamped_roof_angle_degrees(angle_degrees: float) -> float:
	return clampf(angle_degrees, 0.0, MAX_ROOF_ANGLE_DEGREES)


static func _normalize_degrees_static(value: float) -> float:
	var normalized := fposmod(value + 180.0, 360.0) - 180.0
	if is_equal_approx(normalized, -180.0):
		return 180.0
	return normalized


func _style_index_from_name(style: String) -> int:
	var normalized := style.strip_edges().to_lower()
	for index in range(VALID_STYLES.size()):
		if String(VALID_STYLES[index]) == normalized:
			return index
	return 2


func _append_triangle_auto(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	_append_triangle(vertices, normals, colors, indices, a, b, c, normal.normalized())


func _append_quad_auto(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	_append_quad(vertices, normals, colors, indices, a, b, c, d, normal.normalized())


func _append_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	vertices.append(d)
	for _index in range(4):
		normals.append(normal)
		colors.append(roof_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1, base, base + 3, base + 2]))


func _append_triangle(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	normal: Vector3
) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	colors.append(roof_color)
	colors.append(roof_color)
	colors.append(roof_color)
	indices.append_array(PackedInt32Array([base, base + 2, base + 1]))


func _update_roof_mesh_resource(arrays: Array) -> void:
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		array_mesh = ArrayMesh.new()
		mesh = array_mesh
	else:
		array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _sync_roof_material() -> void:
	var material := material_override as StandardMaterial3D
	if material == null:
		material_override = _build_roof_material(roof_color)
		return
	material.albedo_color = Color(1.0, 1.0, 1.0, roof_color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA if roof_color.a < 0.99
		else BaseMaterial3D.TRANSPARENCY_DISABLED
	)


func _build_roof_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, color.a)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_triangle_wireframe(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var line_vertices := PackedVector3Array()
	for index in range(0, indices.size(), 3):
		var a := vertices[indices[index]]
		var b := vertices[indices[index + 1]]
		var c := vertices[indices[index + 2]]
		_append_wireframe_edge(line_vertices, a, b)
		_append_wireframe_edge(line_vertices, b, c)
		_append_wireframe_edge(line_vertices, c, a)
	if line_vertices.is_empty():
		return

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = line_vertices

	var wire_mesh := ArrayMesh.new()
	wire_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = TRIANGLE_WIREFRAME_NODE_NAME
	instance.mesh = wire_mesh
	instance.material_override = _build_triangle_wireframe_material()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta(GENERATED_META, true)
	add_child(instance)
	if Engine.is_editor_hint():
		instance.owner = null


func _append_wireframe_edge(line_vertices: PackedVector3Array, start: Vector3, end: Vector3) -> void:
	line_vertices.append(start)
	line_vertices.append(end)


func _build_triangle_wireframe_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = debug_triangle_wireframe_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.set("no_depth_test", true)
	if debug_triangle_wireframe_color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_collision_body(vertices: PackedVector3Array, indices: PackedInt32Array) -> void:
	var faces := PackedVector3Array()
	for index in range(0, indices.size(), 3):
		faces.append(vertices[indices[index]])
		faces.append(vertices[indices[index + 1]])
		faces.append(vertices[indices[index + 2]])
	if faces.is_empty():
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.set_meta(GENERATED_META, true)

	var body := StaticBody3D.new()
	body.name = "RoofCollision"
	body.set_meta(GENERATED_META, true)
	body.add_child(collision_shape)
	add_child(body)
	if Engine.is_editor_hint():
		body.owner = null
		collision_shape.owner = null


func _clear_generated_children() -> void:
	for child in get_children():
		if !child.has_meta(GENERATED_META):
			continue
		remove_child(child)
		child.free()
