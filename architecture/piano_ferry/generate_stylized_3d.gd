extends SceneTree

const Building3DScript = preload(
	"res://addons/low_poly_building_editor/building_3d.gd"
)
const BuildingFactoryScript = preload(
	"res://addons/low_poly_building_editor/building_factory.gd"
)
const BuildingSpecCompilerScript = preload(
	"res://addons/low_poly_building_editor/building_spec_compiler.gd"
)
const BuildingThumbnailRendererScript = preload(
	"res://addons/low_poly_building_editor/building_thumbnail_renderer.gd"
)
const Roof3DScript = preload(
	"res://addons/low_poly_building_editor/roofs/roof_3d.gd"
)

const SPEC_PATH := (
	"res://architecture/piano_ferry/piano_ferry_building_spec.json"
)
const OUTPUT_SCENE := (
	"res://architecture/piano_ferry/piano_ferry_stylized_3d.tscn"
)
const OUTPUT_REPORT := (
	"res://architecture/piano_ferry/piano_ferry_generation_report.json"
)
const OUTPUT_PREVIEW := (
	"res://architecture/piano_ferry/piano_ferry_preview.png"
)

const CANOPY_COLOR := Color("#e4e2dc")


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	var load_result := BuildingSpecCompilerScript.load_json_spec(SPEC_PATH)
	var spec_errors: Array = load_result.get("errors", [])
	if !spec_errors.is_empty():
		_finish_with_errors(spec_errors)
		return

	var compile_result := BuildingSpecCompilerScript.compile(
		load_result.get("spec")
	)
	var compile_errors: Array = compile_result.get("errors", [])
	var building := compile_result.get("building") as Building3DScript
	if building == null or !compile_errors.is_empty():
		_finish_with_errors(compile_errors)
		return

	_apply_reference_roof(building)
	var resolved: Dictionary = compile_result.get("resolved", {}).duplicate(true)
	resolved["node_count"] = _count_authored_nodes(building)
	resolved["reference_canopy"] = {
		"style": "dome",
		"footprint": [2.0, 0.45, 18.5, 8.55],
		"eave_height": 4.42,
		"angle_degrees": 18.0,
	}
	resolved["structural_signature"] = hash(resolved)

	var save_error := BuildingSpecCompilerScript.save_building(
		building,
		OUTPUT_SCENE
	)
	if save_error != OK:
		building.free()
		_finish_with_errors([
			"Could not save Piano Ferry scene (error %d)." % save_error,
		])
		return

	var preview_rendered := false
	if DisplayServer.get_name() != "headless":
		var renderer := (
			BuildingThumbnailRendererScript.new()
			as BuildingThumbnailRendererScript
		)
		var render_result: Dictionary = await renderer.render_building(
			building,
			resolved,
			OUTPUT_PREVIEW,
			Vector2i(1200, 675)
		)
		preview_rendered = bool(render_result.get("ok", false))
		if !preview_rendered:
			push_error(String(render_result.get("error", "Preview render failed.")))
		renderer.dispose()

	var report := {
		"ok": true,
		"output": OUTPUT_SCENE,
		"preview": OUTPUT_PREVIEW if preview_rendered else "",
		"resolved": resolved,
		"errors": [],
		"warnings": [],
	}
	var report_error := _write_report(report)
	print(JSON.stringify(report, "\t"))
	building.free()
	quit(0 if report_error == OK else 1)


func _apply_reference_roof(building: Building3DScript) -> void:
	for child in building.get_children():
		if child is Roof3DScript:
			child.name = "FlatTerminalRoof"
			break

	var canopy := BuildingFactoryScript.create_roof_node(
		building,
		Vector3(2.0, 4.42, 0.45),
		Vector3(18.5, 4.42, 8.55),
		"dome",
		18.0,
		0.22,
		0.42,
		CANOPY_COLOR
	)
	canopy.name = "ArchedEntranceCanopy"
	building.add_child(canopy)
	canopy.owner = building
	building.set_meta("building_api", "low_poly_building_editor")
	building.set_meta(
		"design_source",
		"user-provided Piano Ferry reference photo"
	)
	building.set_meta(
		"design_notes",
		"Long flat terminal wing with a raised low-poly arched entrance canopy."
	)
	building.refresh_building_geometry_clips()


func _count_authored_nodes(root: Node) -> int:
	var count := 1
	for child in root.get_children():
		if child.owner == root:
			count += _count_authored_descendants(child, root)
	return count


func _count_authored_descendants(node: Node, scene_owner: Node) -> int:
	var count := 1
	for child in node.get_children():
		if child.owner == scene_owner:
			count += _count_authored_descendants(child, scene_owner)
	return count


func _write_report(report: Dictionary) -> Error:
	var file := FileAccess.open(OUTPUT_REPORT, FileAccess.WRITE)
	if file == null:
		var open_error := FileAccess.get_open_error()
		push_error("Could not write Piano Ferry report (error %d)." % open_error)
		return open_error
	file.store_string(JSON.stringify(report, "\t") + "\n")
	return OK


func _finish_with_errors(errors: Array) -> void:
	var report := {
		"ok": false,
		"output": OUTPUT_SCENE,
		"preview": "",
		"resolved": {},
		"errors": errors,
		"warnings": [],
	}
	_write_report(report)
	print(JSON.stringify(report, "\t"))
	for error in errors:
		push_error(String(error))
	quit(1)
