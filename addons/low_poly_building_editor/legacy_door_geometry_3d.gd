extends RefCounted


static func build(
	opening: Node,
	panel_count: int,
	panel_depth: float,
	panel_color: Color
) -> void:
	var spans: Array = opening.call(&"_leaf_spans", panel_count)
	for index in range(spans.size()):
		var rect: Rect2 = spans[index]
		var part_name: String = opening.call(&"_leaf_part_name", "DoorPanel", index, spans.size())
		opening.call(
			&"_add_box",
			part_name,
			Vector3(rect.size.x, rect.size.y, panel_depth),
			opening.call(&"_rect_center", rect),
			panel_color
		)
