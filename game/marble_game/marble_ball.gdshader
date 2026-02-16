shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform bool keep_original_aspect = true;

uniform vec2 roll_axis_uv = vec2(0.0, 1.0);
uniform float roll_angle : hint_range(0.0, 6.2) = 0.0;

uniform float rim_darkening : hint_range(0.0, 2.0) = 0.65;
uniform float highlight_power : hint_range(1.0, 128.0) = 32.0;
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.9;
uniform vec2 light_dir = vec2(-0.5, -0.8);

uniform float refraction_strength : hint_range(0.0, 0.12) = 0.05;
uniform float refraction_surface_mix : hint_range(0.0, 2.0) = 0.75;

uniform float refraction_radial_power : hint_range(0.1, 6.0) = 1.3;
uniform float ior : hint_range(1.0, 2.5) = 1.45;

vec3 rotate_around_axis(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;

	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	if (keep_original_aspect) {
		p.x *= aspect;
	}

	float d = length(p);

	if (d >= radius) {
		COLOR = vec4(0.0);
	} else {
		float rr = radius * radius;
		float z = sqrt(max(rr - d * d, 0.0));
		vec3 P = vec3(p.x, p.y, z);

		vec2 a2 = roll_axis_uv;
		float a_len = length(a2);
		if (a_len < 0.00001) {
			a2 = vec2(0.0, 1.0);
			a_len = 1.0;
		}
		a2 /= a_len;

		vec3 A = normalize(vec3(a2.x, a2.y, 0.0));

		vec3 Pr = rotate_around_axis(P, A, roll_angle);

		vec2 lookup = Pr.xy;
		if (keep_original_aspect) {
			lookup.x /= aspect;
		}

		vec2 new_uv = lookup * 0.5 + 0.5;
		vec4 tex = texture(TEXTURE, new_uv);

		vec3 n = normalize(P);

		vec2 ld2 = normalize(light_dir);
		vec3 l = normalize(vec3(ld2.x, ld2.y, 0.6));

		float ndotl = max(dot(n, l), 0.0);

		float rim = pow(1.0 - (z / radius), 1.5);
		float rim_mul = 1.0 - rim_darkening * rim;

		vec3 vdir = vec3(0.0, 0.0, 1.0);
		vec3 h = normalize(l + vdir);
		float spec = pow(max(dot(n, h), 0.0), highlight_power) * highlight_strength;

		vec3 col = tex.rgb;
		col *= (0.6 + 0.6 * ndotl);
		col *= rim_mul;
		col += vec3(spec);

		float feather = 0.01;
		float edge_alpha = smoothstep(radius, radius - feather, d);
		float alpha = edge_alpha * tex.a;

		float dist01 = clamp(d / max(radius, 0.0001), 0.0, 1.0);
		float radial = pow(dist01, refraction_radial_power);
		float ref_weight = radial * edge_alpha;

		vec3 refr_delta = vec3(0.0);

		if (ref_weight > 0.00001) {
			vec3 V = vec3(0.0, 0.0, 1.0);

			float eta = 1.0 / max(ior, 0.0001);
			vec3 T = refract(V, n, eta);

			vec2 screen_dir = T.xy;

			if (keep_original_aspect) {
				screen_dir.x /= max(aspect, 0.0001);
			}

			float edge_boost = 0.35 + 0.65 * (1.0 - (z / radius));

			vec2 uv0 = SCREEN_UV;
			vec2 uv1 = uv0 + screen_dir * (refraction_strength * ref_weight * edge_boost);

			vec3 bg0 = texture(SCREEN_TEXTURE, uv0).rgb;
			vec3 bg1 = texture(SCREEN_TEXTURE, uv1).rgb;

			refr_delta = (bg1 - bg0) * refraction_surface_mix;
		}

		vec3 out_rgb = col + refr_delta;
		COLOR = vec4(out_rgb, alpha);
	}
}