shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform bool keep_original_aspect = true;

uniform mat3 roll_rot = mat3(
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0)
);

uniform float rim_darkening : hint_range(0.0, 2.0) = 0.65;
uniform float highlight_power : hint_range(1.0, 128.0) = 32.0;
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.9;
uniform vec2 light_dir = vec2(-0.5, -0.8);

uniform float refraction_strength : hint_range(0.0, 0.25) = 0.08;
uniform float refraction_power : hint_range(0.5, 6.0) = 2.2;

uniform float fresnel_strength : hint_range(0.0, 2.0) = 0.9;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;

uniform float ball_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;

	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	if (keep_original_aspect) {
		p.x *= aspect;
	}

	float d = length(p);

	vec4 out_col = vec4(0.0);

	if (d < radius) {
		float rr = radius * radius;
		float z = sqrt(max(rr - d * d, 0.0));

		vec3 P = vec3(p.x, p.y, z);

		vec3 Pr = roll_rot * P;

		vec2 lookup = Pr.xy;
		if (keep_original_aspect) {
			lookup.x /= aspect;
		}
		vec2 new_uv = lookup * 0.5 + 0.5;

		vec4 tex = texture(TEXTURE, new_uv);

		vec3 n_geo = normalize(P);

		float t = clamp(d / max(radius, 0.00001), 0.0, 1.0);
		float k = pow(t, refraction_power);

		vec2 refract_uv = SCREEN_UV + n_geo.xy * (refraction_strength * k);
		vec4 bg = texture(SCREEN_TEXTURE, refract_uv);

		vec2 ld2 = normalize(light_dir);
		vec3 l = normalize(vec3(ld2.x, ld2.y, 0.6));

		float ndotl = max(dot(n_geo, l), 0.0);

		float rim = pow(1.0 - (z / max(radius, 0.00001)), 1.5);
		float rim_mul = 1.0 - rim_darkening * rim;

		vec3 vdir = vec3(0.0, 0.0, 1.0);
		vec3 h = normalize(l + vdir);
		float spec = pow(max(dot(n_geo, h), 0.0), highlight_power) * highlight_strength;

		float fresnel = pow(1.0 - max(dot(n_geo, vdir), 0.0), fresnel_power) * fresnel_strength;

		vec3 base_col = tex.rgb;
		base_col *= (0.6 + 0.6 * ndotl);
		base_col *= rim_mul;

		float feather = 0.01;
		float alpha_edge = smoothstep(radius, radius - feather, d);

		float a = tex.a * alpha_edge * ball_opacity;

		vec3 mixed = mix(bg.rgb, base_col, a);

		float spec_mask = alpha_edge * (0.35 + 0.65 * (1.0 - t));
		mixed += vec3(spec) * spec_mask;
		mixed += vec3(fresnel) * alpha_edge;

		out_col = vec4(mixed, 1.0);
	}

	COLOR = out_col;
}