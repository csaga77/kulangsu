shader_type canvas_item;

// 0.0 = fade starts at top, 1.0 = fade starts at bottom
uniform float fade_start = 0.0;
// 0.0 = fully transparent, 1.0 = fully opaque
uniform float fade_end   = 1.0;

//sprite size: 64 x 64 pixels, sprite texture size 13 x 54 sprites
uniform vec2 tile_texture_size = vec2(13, 54);

void fragment() {
	// Interpolated per-pixel local Y
	float local_y = fract(UV.y * tile_texture_size.y);

	// Example: fade bottom 20 pixels
	float t = smoothstep(fade_start, fade_end, local_y);
	COLOR.a *= 1.0 - t;
}