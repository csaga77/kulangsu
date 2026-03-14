class_name UIStyle
extends RefCounted

static func build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.11, 0.14, 0.92)
	style.border_color = Color(0.84, 0.78, 0.64, 0.55)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	return style


static func build_title_gradient() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.04, 0.09, 0.13, 1.0),
		Color(0.10, 0.17, 0.18, 1.0),
		Color(0.22, 0.30, 0.24, 1.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
