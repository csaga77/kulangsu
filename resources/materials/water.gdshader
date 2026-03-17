shader_type canvas_item;

// Godot 4 screen read
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Tileable noise recommended
uniform sampler2D noise_texture : filter_linear, repeat_enable;

// Controls
uniform vec2  speed         = vec2(0.5, 0.2);   // noise scrolling
uniform float distortion    = 0.010;            // screen refraction strength
uniform vec4  water_tint    : source_color = vec4(0.86, 0.93, 1.0, 1.0);
uniform vec4  deep_tint     : source_color = vec4(0.72, 0.86, 0.97, 1.0);
uniform vec4  highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float water_opacity = 0.68;
uniform float tint_strength = 0.32;
uniform float edge_softness = 0.045;
uniform float color_motion_strength = 0.09;
uniform float highlight_strength = 0.12;
uniform float highlight_threshold = 0.78;
uniform float refraction_mix = 0.22;
uniform float surface_wave_strength = 0.08;
uniform float surface_wave_scale = 1.6;

// Vertex bob (optional)
uniform float vertex_bob_amp  = 0.0;
uniform float vertex_bob_freq = 2.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (vertex_bob_amp > 0.0) {
		VERTEX.y += sin(TIME * vertex_bob_freq) * vertex_bob_amp;
	}
}

void fragment() {
	vec4 water = texture(TEXTURE, UV);
	if (water.a <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// Visibility comes from the tile texture alpha first; wave tint and refraction are layered on top.
		vec2 world_uv = world_pos * surface_wave_scale;
		float wave_a = texture(noise_texture, world_uv + speed * TIME).r;
		float wave_b = texture(noise_texture, world_uv * 1.8 - speed.yx * TIME * 0.55 + vec2(13.1, 5.7)).r;
		float ripple = texture(noise_texture, world_uv * 2.9 + speed * TIME * 0.38 + vec2(-7.2, 9.4)).r;
		float long_wave = sin(world_pos.x * 0.026 + world_pos.y * 0.052 - TIME * 0.82) * 0.5 + 0.5;
		float cross_wave = sin(world_pos.x * -0.018 + world_pos.y * 0.041 + TIME * 0.57) * 0.5 + 0.5;
		vec2 flow = vec2(
			(wave_a - 0.5) + (long_wave - 0.5) * 0.75,
			(wave_b - 0.5) + (cross_wave - 0.5) * 0.55 + (ripple - 0.5) * 0.25
		);

		vec4 refracted = texture(SCREEN_TEXTURE, SCREEN_UV + flow * distortion * water.a);

		float depth_mix = clamp(0.24 + wave_b * 0.40 + water.b * 0.22, 0.0, 1.0);
		vec3 tint = mix(water_tint.rgb, deep_tint.rgb, depth_mix);
		float body_wave = mix(long_wave, wave_a, 0.55);
		float wave_lift = mix(1.0 - surface_wave_strength, 1.0 + surface_wave_strength, body_wave);
		float color_motion = mix(cross_wave, ripple, 0.5);
		vec3 moving_tint = mix(tint * (1.0 - color_motion_strength), tint * (1.0 + color_motion_strength), color_motion);
		float tile_detail = dot(water.rgb, vec3(0.333333));
		vec3 body_rgb = moving_tint * wave_lift * mix(0.98, 1.08, tile_detail);
		vec3 refracted_rgb = mix(refracted.rgb, body_rgb, 0.10 + tint_strength * 0.14);

		float highlight_seed = max(mix(long_wave, wave_a, 0.45), mix(cross_wave, ripple, 0.5));
		float highlight_mask = smoothstep(highlight_threshold, 1.0, highlight_seed) * water.a;

		vec3 rgb = mix(refracted_rgb, body_rgb, refraction_mix);
		rgb += highlight_color.rgb * highlight_mask * highlight_strength;

		COLOR = vec4(rgb, water.a * water_opacity);
	}
}
