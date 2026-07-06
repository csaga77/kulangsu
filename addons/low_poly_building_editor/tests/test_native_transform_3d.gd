extends Node3D

# Verifies that a native Move/Rotate/Scale gizmo edit (simulated by writing the
# node transform directly) is baked back into each block's authored properties,
# snapped to the shared grid, with the node scale reset to 1.

const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const BuildingMeshScript = preload(
	"res://addons/low_poly_building_editor/building_mesh_3d.gd"
)
const RoundPillar3DScript = preload(
	"res://addons/low_poly_building_editor/pillars/round_pillar_3d.gd"
)
const Rail3DScript = preload(
	"res://addons/low_poly_building_editor/rails/rail_3d.gd"
)
const Floor3DScript = preload(
	"res://addons/low_poly_building_editor/floors/floor_3d.gd"
)

const GRID := 0.5
var m_failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_validate_static_helpers()
	_validate_roof_translate()
	_validate_roof_scale()
	_validate_roof_rotate()
	_validate_pillar_scale_translate()
	_validate_rail_translate()
	_validate_floor_translate()
	for failure in m_failures:
		push_error(failure)
	if m_failures.is_empty():
		print("PASS: Native transform bake smoke test")
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _validate_static_helpers() -> void:
	if !BuildingMeshScript.native_transform_is_identity(Transform3D.IDENTITY):
		m_failures.append("Identity transform not recognized as identity delta")
	if BuildingMeshScript.native_transform_is_identity(
		Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0))
	):
		m_failures.append("Translated transform wrongly treated as identity delta")
	if !is_equal_approx(BuildingMeshScript.snap_axis_to_grid(1.24, 0.5), 1.0):
		m_failures.append("snap_axis_to_grid did not round to the grid")
	if !is_equal_approx(BuildingMeshScript.snap_axis_to_grid(1.24, 0.0), 1.24):
		m_failures.append("snap_axis_to_grid should pass through when step is 0")
	var yaw := BuildingMeshScript.native_delta_yaw_degrees(
		Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3.ZERO)
	)
	if absf(yaw - 90.0) > 0.01:
		m_failures.append("native_delta_yaw_degrees did not extract 90 degrees")
	var scale := BuildingMeshScript.native_delta_scale(
		Transform3D(Basis.from_scale(Vector3(2.0, 3.0, 4.0)), Vector3.ZERO)
	)
	if scale.distance_to(Vector3(2.0, 3.0, 4.0)) > 0.01:
		m_failures.append("native_delta_scale did not extract per-axis scale")


func _make_roof():
	var roof := BuildingFactoryScript.create_roof_node(
		self,
		Vector3.ZERO,
		Vector3(4.0, 0.0, 6.0),
		"gable",
		30.0,
		0.12,
		0.2,
		Color(0.5, 0.34, 0.25, 1.0)
	)
	add_child(roof)
	return roof


func _validate_roof_translate() -> void:
	var roof = _make_roof()
	roof.transform = Transform3D(roof.transform.basis, Vector3(2.0, 0.0, 3.0))
	roof.apply_native_transform(GRID)
	if roof.start_point.distance_to(Vector3(2.0, 0.0, 3.0)) > 0.01:
		m_failures.append("Roof translate did not move the anchor start point")
	if roof.end_point.distance_to(Vector3(6.0, 0.0, 9.0)) > 0.01:
		m_failures.append("Roof translate did not move the far corner")
	if roof.transform.basis.get_scale().distance_to(Vector3.ONE) > 0.01:
		m_failures.append("Roof translate did not keep node scale at 1")
	roof.queue_free()


func _validate_roof_scale() -> void:
	var roof = _make_roof()
	roof.transform = Transform3D(
		roof.transform.basis.scaled(Vector3(2.0, 1.0, 2.0)),
		roof.transform.origin
	)
	roof.apply_native_transform(GRID)
	if roof.get_roof_size().distance_to(Vector2(8.0, 12.0)) > 0.01:
		m_failures.append("Roof scale did not bake into the footprint size")
	if roof.transform.basis.get_scale().distance_to(Vector3.ONE) > 0.01:
		m_failures.append("Roof scale did not reset node scale to 1")
	roof.queue_free()


func _validate_roof_rotate() -> void:
	var roof = _make_roof()
	roof.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(90.0)) * roof.transform.basis,
		roof.transform.origin
	)
	roof.apply_native_transform(GRID)
	if absf(roof.roof_rotation_degrees - 90.0) > 0.5:
		m_failures.append("Roof rotate did not bake yaw into roof_rotation_degrees")
	if roof.get_roof_size().distance_to(Vector2(4.0, 6.0)) > 0.01:
		m_failures.append("Roof rotate should not change the footprint size")
	roof.queue_free()


func _validate_pillar_scale_translate() -> void:
	var pillar := RoundPillar3DScript.new()
	pillar.base_point = Vector3.ZERO
	pillar.pillar_radius = 0.25
	pillar.pillar_height = 2.4
	add_child(pillar)
	pillar.transform = Transform3D(Basis.from_scale(Vector3(2.0, 3.0, 2.0)), Vector3(1.0, 0.0, 1.0))
	pillar.apply_native_transform(GRID)
	if pillar.base_point.distance_to(Vector3(1.0, 0.0, 1.0)) > 0.01:
		m_failures.append("Pillar translate did not move the base point")
	if absf(pillar.pillar_radius - 0.5) > 0.01:
		m_failures.append("Pillar horizontal scale did not bake into radius")
	if absf(pillar.pillar_height - 7.2) > 0.01:
		m_failures.append("Pillar vertical scale did not bake into height")
	if pillar.transform.basis.get_scale().distance_to(Vector3.ONE) > 0.01:
		m_failures.append("Pillar scale did not reset node scale to 1")
	pillar.queue_free()


func _validate_rail_translate() -> void:
	var rail := Rail3DScript.new()
	rail.start_point = Vector3.ZERO
	rail.end_point = Vector3(4.0, 0.0, 0.0)
	add_child(rail)
	rail.transform = Transform3D(rail.transform.basis, rail.transform.origin + Vector3(1.0, 0.0, 1.0))
	rail.apply_native_transform(GRID)
	if rail.start_point.distance_to(Vector3(1.0, 0.0, 1.0)) > 0.01:
		m_failures.append("Rail translate did not move the start point")
	if rail.end_point.distance_to(Vector3(5.0, 0.0, 1.0)) > 0.01:
		m_failures.append("Rail translate did not move the end point")
	rail.queue_free()


func _validate_floor_translate() -> void:
	var floor_node := Floor3DScript.new()
	floor_node.set_floor_corners(Vector3.ZERO, Vector3(4.0, 0.0, 4.0))
	add_child(floor_node)
	floor_node.transform = Transform3D(
		floor_node.transform.basis,
		floor_node.transform.origin + Vector3(2.0, 0.0, 2.0)
	)
	floor_node.apply_native_transform(GRID)
	if floor_node.start_point.distance_to(Vector3(2.0, 0.0, 2.0)) > 0.01:
		m_failures.append("Floor translate did not move the start corner")
	if floor_node.end_point.distance_to(Vector3(6.0, 0.0, 6.0)) > 0.01:
		m_failures.append("Floor translate did not move the far corner")
	floor_node.queue_free()
