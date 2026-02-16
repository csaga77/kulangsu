shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform bool keep_original_aspect = true;

/*
roll_axis_uv:
- A 2D axis in UV plane (XY) that the sphere rotates around.
- Example: if the ball moves to the right, a good roll axis is (0, 1) (rotate around +Y).
- If you have velocity v, common choice is axis = normalize(vec2(-v.y, v.x)) (perpendicular).
*/
uniform vec2 roll_axis_uv = vec2(0.0, 1.0);
uniform float roll_angle : hint_range(0.0, 6.2) = 0.0;

uniform float rim_darkening  : hint_range(0.0, 2.0) = 0.65;
uniform float highlight_power : hint_range(1.0, 128.0) = 32.0;
uniform float highlight_strength : hint_range(0.0, 2.0) = 0.9;
uniform vec2 light_dir = vec2(-0.5, -0.8);

vec3 rotate_around_axis(vec3 v, vec3 axis, float angle) {
	// Rodrigues' rotation formula
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void fragment() {
	// Centered coords in [-1, 1]
	vec2 p = UV * 2.0 - 1.0;

	// Keep circle visually circular for non-square textures
	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x; // w/h
	if (keep_original_aspect) {
		p.x *= aspect;
	}

	float d = length(p);

	if (d >= radius) {
		COLOR = vec4(0.0);
	} else {
		// Sphere surface point
		float rr = radius * radius;
		float z = sqrt(max(rr - d * d, 0.0));
		vec3 P = vec3(p.x, p.y, z);

		// Roll axis in XY plane
		vec2 a2 = roll_axis_uv;
		float a_len = length(a2);
		// avoid divide-by-zero
		if (a_len < 0.00001) {
			a2 = vec2(0.0, 1.0);
			a_len = 1.0;
		}
		a2 /= a_len;

		vec3 A = normalize(vec3(a2.x, a2.y, 0.0));

		// Rotate the surface point around the in-plane axis
		vec3 Pr = rotate_around_axis(P, A, roll_angle);

		// Use rotated XY as lookup coords
		vec2 lookup = Pr.xy;

		// Undo aspect correction for sampling space
		if (keep_original_aspect) {
			lookup.x /= aspect;
		}

		vec2 new_uv = lookup * 0.5 + 0.5;
		vec4 tex = texture(TEXTURE, new_uv);

		// Lighting (optional but helps sell "marble")
		vec3 n = normalize(P); // normal from original surface point

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

		// Soft edge
		float feather = 0.01;
		float alpha = smoothstep(radius, radius - feather, d);

		COLOR = vec4(col, tex.a * alpha);
	}
}