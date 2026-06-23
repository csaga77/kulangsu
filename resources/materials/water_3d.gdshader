shader_type spatial;

// Low-poly 3D terrain water surface (WaterMesh in low_poly_terrain_3d.gd).
//
// Keeps the calm "painted postcard" read while adding gentle life:
//  - base color comes from the per-cell vertex colors built on the CPU
//    (deep/base/shoreline/highlight blend), so the low-poly look is preserved;
//  - a soft shimmer scrolls across the surface (animated albedo);
//  - the shading normal is perturbed by two crossing waves so the directional
//    sun produces a slow-moving specular glint.
//
// The mesh geometry stays perfectly flat at water_height. Animation lives only
// in the shading normal and albedo, never in VERTEX. That avoids clipping the
// stacked surface-layer / shoreline overlays and keeps any logic that reads the
// mesh height (placement queries, validation) valid.
//
// Left intentionally double-sided: the low-poly mesh pipeline force-orients
// every normal upward and does not maintain a consistent triangle winding, so
// backface culling cannot be enabled safely here. The upward shading normal
// below keeps both faces lit identically.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Additive shimmer tint (matches LowPolyArtStyle3D.water_highlight_color).
uniform vec4 highlight_color : source_color = vec4(0.86, 0.96, 0.98, 1.0);
uniform float highlight_strength : hint_range(0.0, 0.4) = 0.10;

// wave_frequency: spatial frequency of the animated surface waves.
// wave_strength : how far the shading normal tilts (visual wave "depth").
// wave_speed    : animation rate.
uniform float wave_frequency : hint_range(0.05, 4.0) = 0.48;
uniform float wave_strength : hint_range(0.0, 0.2) = 0.045;
uniform float wave_speed : hint_range(0.0, 3.0) = 1.0;

// Final alpha = vertex_color.a * water_opacity (single, explicit multiply).
uniform float water_opacity : hint_range(0.0, 1.0) = 0.62;

uniform float water_roughness : hint_range(0.0, 1.0) = 0.28;
uniform float water_specular : hint_range(0.0, 1.0) = 0.6;

varying vec3 v_world;

void vertex() {
	// World-space position drives animation so waves stay seamless across cells
	// regardless of per-cell mesh layout. Geometry is left untouched.
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * wave_speed;

	// Two crossing waves perturb the (otherwise straight-up) surface normal so
	// the sun's specular highlight slides across the surface. Amplified a little
	// so the moving glint is readable from the far orthographic camera.
	float dx = cos(v_world.x * wave_frequency + t) * wave_strength * 4.0;
	float dz = cos(v_world.z * wave_frequency * 1.3 - t * 0.8) * wave_strength * 4.0;
	vec3 world_normal = normalize(vec3(-dx, 1.0, -dz));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	vec3 base = COLOR.rgb;

	// Large, slow swell drifts brightness across the whole surface. This is the
	// most legible motion at map scale and reads even under the gloss overlay.
	float swell = sin(v_world.x * 0.16 + v_world.z * 0.12 - t * 1.1) * 0.5 + 0.5;

	// Finer sparkle adds moving bright crests on top of the swell.
	float sparkle = sin(v_world.x * wave_frequency * 1.7 + t * 1.3)
		* sin(v_world.z * wave_frequency * 1.1 - t);
	sparkle = smoothstep(0.35, 1.0, sparkle);

	ALBEDO = base * mix(0.88, 1.14, swell) + highlight_color.rgb * sparkle * highlight_strength;

	ROUGHNESS = water_roughness;
	SPECULAR = water_specular;
	METALLIC = 0.0;
	ALPHA = clamp(COLOR.a * water_opacity, 0.0, 1.0);
}
