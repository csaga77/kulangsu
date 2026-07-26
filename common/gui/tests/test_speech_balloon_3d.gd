extends Node

const SPEECH_BALLOON_3D := preload("res://common/gui/speech_balloon_3d.gd")

var m_failures: Array[String] = []


func _ready() -> void:
	var balloon := SPEECH_BALLOON_3D.new() as Node3D
	add_child(balloon)
	await get_tree().process_frame
	balloon.show_line(
		"A Po told me the courtyard basin caught the lantern light because you "
		+ "rinsed it before festival week. The extra cup still hurts, but the "
		+ "house has one warm answer ready beside it."
	)
	await get_tree().process_frame

	var label := balloon.get("m_label") as Label3D
	_assert_true(label != null, "Speech balloon creates its Label3D")
	if label != null:
		var text_bounds := label.get_aabb()
		_assert_true(
			label.width >= 1400.0,
			"Speech balloon retains a readable dialogue wrap width"
		)
		_assert_true(
			text_bounds.size.x >= 10.0,
			"Speech balloon dialogue occupies a useful horizontal world span"
		)
		_assert_true(
			text_bounds.size.y <= 2.5,
			"Spring Festival dialogue no longer collapses into a vertical column"
		)

	if m_failures.is_empty():
		print("PASS: 3D speech balloon readability")
	else:
		for failure in m_failures:
			push_error(failure)
		push_error(
			"3D speech balloon readability failed with %d issue(s)."
			% m_failures.size()
		)
	await get_tree().process_frame
	get_tree().quit(0 if m_failures.is_empty() else 1)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	m_failures.append("%s." % label)
