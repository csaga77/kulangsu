shader_type spatial;

// Animated low-poly 3D water surface (WaterMesh / WaterShorelineMesh /
// WaterSurfaceLayerMesh in low_poly_terrain_3d.gd).
//
// Real wave geometry: the surface is displaced vertically every frame from a
// sum-of-sines height field, and the shading normal is rebuilt analytically
// from the wave slope so lighting follows the crests. All three water layers
// run this same shader (driven by identical world-space waves) so they rise and
// fall together instead of clipping.
//
// The displacement happens in the vertex stage only — the *stored/baked* mesh
// stays flat at water_height. So height-based placement queries
// (get_world_water_surface_height, etc.) and the mesh-height validation keep
// working against the flat baked geometry while the visible surface waves.
//
// Assumes the terrain root has no rotation/scale (generated mesh children are
// axis-aligned at the terrain origin), so a vertical VERTEX.y offset equals a
// vertical world offset.
//
// Left double-sided: the low-poly mesh pipeline force-orients normals upward and
// does not maintain a consistent triangle winding, so backface culling is unsafe
// here. The analytic normal below keeps both faces lit identically.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Per-layer color source. The body passes use_vertex_color = true (deep/base/
// shoreline blend baked into vertex colors); the foam and gloss overlays pass a
// flat base_color instead.
uniform bool use_vertex_color = true;
uniform vec4 base_color : source_color = vec4(0.30, 0.55, 0.75, 0.50);
uniform float water_opacity : hint_range(0.0, 1.0) = 0.62;

// Wave shaping.
//   wave_depth     : vertical amplitude in world units (literal wave height).
//   wave_frequency : spatial frequency scale (higher = shorter wavelength).
//   wave_speed     : animation rate.
uniform float wave_depth : hint_range(0.0, 1.0) = 0.35;
uniform float wave_frequency : hint_range(0.05, 4.0) = 0.9;
uniform float wave_speed : hint_range(0.0, 4.0) = 1.5;

// Wind, set live from LowPolyTerrain3D.set_wind() (which weather can drive).
//   wind_dir      : horizontal (XZ) direction the waves travel.
//   wind_strength : 0 = near-calm ripple, 1 = full choppy seas. Scales
//                   amplitude, speed, and choppiness on top of the base tuning.
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.5;

// Foam/crest brightening on steep wave faces.
uniform vec4 highlight_color : source_color = vec4(0.86, 0.96, 0.98, 1.0);
uniform float highlight_strength : hint_range(0.0, 0.6) = 0.22;

uniform float water_roughness : hint_range(0.0, 1.0) = 0.22;
uniform float water_specular : hint_range(0.0, 1.0) = 0.6;

varying vec3 v_world_normal;

vec2 rotate2(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Returns (height, dH/dx, dH/dz) for world-space position p at time t.
// Three crossing waves fan out around the wind direction; wind_strength scales
// amplitude, speed, and high-frequency choppiness on top of the base tuning.
vec3 wave_field(vec2 p, float t) {
	vec2 wd = normalize(wind_dir + vec2(1e-5, 0.0));
	vec2 d1 = wd;
	vec2 d2 = rotate2(wd, 0.6);
	vec2 d3 = rotate2(wd, -0.9);

	float amp = wave_depth * mix(0.15, 1.0, wind_strength);
	float spd = wave_speed * mix(0.4, 1.0, wind_strength);

	float k1 = 0.55 * wave_frequency;
	float k2 = 0.90 * wave_frequency;
	float k3 = 1.50 * wave_frequency * mix(0.8, 1.3, wind_strength);

	float a1 = amp;
	float a2 = amp * 0.55;
	float a3 = amp * mix(0.15, 0.5, wind_strength);

	float p1 = dot(p, d1) * k1 + t * spd;
	float p2 = dot(p, d2) * k2 + t * spd * 1.3;
	float p3 = dot(p, d3) * k3 + t * spd * 1.7;

	float h = a1 * sin(p1) + a2 * sin(p2) + a3 * sin(p3);
	float dhdx = a1 * cos(p1) * k1 * d1.x + a2 * cos(p2) * k2 * d2.x + a3 * cos(p3) * k3 * d3.x;
	float dhdz = a1 * cos(p1) * k1 * d1.y + a2 * cos(p2) * k2 * d2.y + a3 * cos(p3) * k3 * d3.y;
	return vec3(h, dhdx, dhdz);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 field = wave_field(world.xz, TIME);
	VERTEX.y += field.x;
	v_world_normal = normalize(vec3(-field.y, 1.0, -field.z));
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(v_world_normal, 0.0)).xyz);

	vec3 col = use_vertex_color ? COLOR.rgb : base_color.rgb;
	float alpha = use_vertex_color ? COLOR.a : base_color.a;

	// Brighten steep wave faces (where the normal tilts away from straight up)
	// to read as foamy crests.
	float steep = pow(clamp(1.0 - v_world_normal.y, 0.0, 1.0), 1.5);
	col += highlight_color.rgb * steep * highlight_strength;

	ALBEDO = col;
	ROUGHNESS = water_roughness;
	SPECULAR = water_specular;
	METALLIC = 0.0;
	ALPHA = clamp(alpha * water_opacity, 0.0, 1.0);
}
