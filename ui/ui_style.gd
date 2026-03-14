class_name UIStyle
extends RefCounted

static func build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.10, 0.13, 0.92)
	style.border_color = Color(0.80, 0.74, 0.61, 0.58)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.01, 0.02, 0.03, 0.34)
	style.shadow_size = 10
	style.anti_aliasing = true
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


static func build_hero_panel_style() -> StyleBoxFlat:
	var style := build_panel_style()
	style.bg_color = Color(0.05, 0.09, 0.12, 0.78)
	style.border_color = Color(0.88, 0.82, 0.68, 0.34)
	style.shadow_color = Color(0.01, 0.03, 0.04, 0.38)
	style.shadow_size = 18
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style


static func build_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.78, 0.61, 0.12)
	style.border_color = Color(0.91, 0.84, 0.71, 0.24)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 16.0
	style.content_margin_top = 8.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 8.0
	style.anti_aliasing = true
	return style


static func build_menu_button_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.shadow_color = Color(0.01, 0.03, 0.04, 0.28)
	style.shadow_size = 8
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	style.anti_aliasing = true
	return style
