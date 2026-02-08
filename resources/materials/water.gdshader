shader_type canvas_item;

// Godot 4 screen read
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Tileable noise recommended
uniform sampler2D noise_texture : filter_nearest, repeat_enable;

// Controls
uniform vec2  speed         = vec2(0.5, 0.2);   // noise scrolling
uniform float distortion    = 0.010;            // screen refraction strength
uniform vec2  wave_ab       = vec2(0.02, 0.02); // wobble strength in iso (a,b) space (top-anchored)

// Vertex bob (optional)
uniform float vertex_bob_amp  = 0.0;
uniform float vertex_bob_freq = 2.0;

uniform vec2 tile_texture_size = vec2(0.1, 0.03125);

// --- 64x32 iso mapping (TOP-ANCHORED) ---
// Origin ab(0,0) at top of diamond: UV(0.5, 0.0) => pixel (32,0)
// a-axis: down-right  ( +32, +16 )
// b-axis: down-left   ( -32, +16 )
vec2 uv_to_iso_ab(vec2 uv) {
	vec2 p = uv * vec2(64.0, 32.0);
	vec2 d = p - vec2(32.0, 0.0); // top of diamond

	float a = ( d.x / 64.0) + ( d.y / 32.0);
	float b = (-d.x / 64.0) + ( d.y / 32.0);
	return vec2(a, b);
}

vec2 iso_ab_to_uv(vec2 ab) {
	float a = ab.x;
	float b = ab.y;

	return vec2(
		0.5 + 0.5 * (a - b),
		0.5 * (a + b)
	);
}

// Hard diamond mask in the SAME ab-space:
// inside if a>=0, b>=0, a+b<=1
float iso_diamond_mask_64x32(vec2 uv) {
	vec2 ab = uv_to_iso_ab(uv);
	if (ab.x < 0.0) return 0.0;
	if (ab.y < 0.0) return 0.0;
	if (ab.x > 1.0) return 0.0;
	if (ab.y > 1.0) return 0.0;
	return 1.0;
}

void vertex() {
	if (vertex_bob_amp > 0.0) {
		VERTEX.y += sin(TIME * vertex_bob_freq) * vertex_bob_amp;
	}
}

void fragment() {
	// Default output: transparent
	vec4 out_col = vec4(0.0);

	// Base alpha (keeps tiles perfectly connected)
	float base_a = texture(TEXTURE, UV).a;

	// Diamond mask
	float m = iso_diamond_mask_64x32(UV);

	// Only shade inside diamond and where base texture is visible
	if (m > 0.0) {
		// Noise scroll
		vec2 n_uv = UV + speed * TIME;
		vec2 n = texture(noise_texture, n_uv).rg * 2.0 - 1.0;

		// Warp in iso (a,b) space to guarantee we stay inside the diamond
		vec2 sub_uv_origin = floor(UV / tile_texture_size) * tile_texture_size;
		vec2 sub_uv = (UV - vec2(0.4, 0.5)) / tile_texture_size;
		vec2 ab = uv_to_iso_ab(sub_uv);
		ab += n * wave_ab * m;
		ab = fract(ab);
		// Convert back to UV for sampling
		vec2 uv_warp = sub_uv_origin + iso_ab_to_uv(ab) * tile_texture_size;

		// Sample water tile texture
		vec4 water = texture(TEXTURE, uv_warp);
		if (UV.x > 0.6) {
			water = vec4(1.0, 0.0, 0.0, 1.0);
		}

		// Refract screen behind the water (only inside diamond)
		vec4 refracted = texture(SCREEN_TEXTURE, SCREEN_UV + n * distortion * m);

		// Combine: water texture modulates refracted screen (keeps tile art highlights)
		vec3 rgb = refracted.rgb * water.rgb;

		out_col = vec4(rgb, base_a);
	}

	COLOR = out_col;
}