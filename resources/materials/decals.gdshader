shader_type canvas_item;

// Godot 4 screen read
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec4 blocked_color : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform float tolerance = 0.05;

void fragment() {
	// Current sprite pixel (already includes TEXTURE * modulate)
	vec4 src = COLOR;

	// Pixel already on screen underneath
	vec4 under = texture(SCREEN_TEXTURE, SCREEN_UV);

	// Compare underlying pixel to blocked color
	float dist_rgb = distance(under.rgb, blocked_color.rgb);
	bool blocked = dist_rgb <= tolerance;

	// Default: invisible
	vec4 out_col = vec4(0.0);

	// Draw only if source has alpha and underlying pixel is NOT blocked
	if (src.a > 0.001 && !blocked) {
		out_col = src;
	}

	COLOR = out_col;
}