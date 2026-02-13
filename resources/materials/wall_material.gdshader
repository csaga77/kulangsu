shader_type canvas_item;

uniform sampler2D texture_shade       : source_color, filter_nearest;
uniform sampler2D texture_footer_mask : source_color, filter_nearest;
uniform sampler2D texture_sides       : source_color, filter_nearest;
uniform sampler2D texture_footer      : source_color, filter_nearest;

uniform bool is_top_visible = true;
uniform vec4 top_side_mask : source_color = vec4(1.0, 1.0, 0.0, 1.0);

uniform bool is_south_east_visible = true;
uniform vec4 south_east_side_mask : source_color = vec4(1.0, 0.0, 1.0, 1.0);

uniform bool is_south_west_visible = true;
uniform vec4 south_west_side_mask : source_color = vec4(0.0, 1.0, 0.0, 1.0);

uniform bool is_south_visible = true;
uniform vec4 south_side_mask : source_color = vec4(0.0, 1.0, 1.0, 1.0);

uniform bool is_north_east_visible = true;
uniform vec4 north_east_side_mask : source_color = vec4(1.0, 0.5, 0.0, 1.0);

uniform bool is_north_west_visible = true;
uniform vec4 north_west_side_mask : source_color = vec4(0.0, 0.5, 1.0, 1.0);

uniform bool is_footer_visible = false;

uniform float color_eps = 0.02;
uniform float shade_strength = 0.7;
uniform bool passthrough_unmatched = false;

bool match_color(vec3 a, vec3 b) {
	return all(lessThanEqual(abs(a - b), vec3(color_eps)));
}

void fragment() {

	vec2 src_size = vec2(textureSize(TEXTURE, 0));
	vec2 px_src   = floor(UV * src_size) + vec2(0.5);
	vec2 pp_uv    = px_src / src_size;

	vec4 src = texture(TEXTURE, pp_uv);
	vec4 out_col = vec4(0.0);

	if (src.a > 0.01) {

		vec2 sides_size = vec2(textureSize(texture_sides, 0));
		vec2 quad_px    = floor(sides_size * 0.5);

		vec2 px_q = mod(px_src, quad_px);

		// UV inside 2x2 atlas (0..0.5)
		vec2 base_uv = px_q / sides_size;

		// Full UV for footer
		vec2 base_uv_full = base_uv * 2.0;

		float footer_a = 0.0;
		if (is_footer_visible) {
			footer_a = texture(texture_footer_mask, pp_uv).a;
		}

		if (match_color(src.rgb, top_side_mask.rgb)) {

			if (is_top_visible) {
				vec4 repl = texture(texture_sides, base_uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			}

		} else if (match_color(src.rgb, south_east_side_mask.rgb)) {

			if (is_south_east_visible) {
				vec2 uv = base_uv + vec2(0.5, 0.5);
				vec4 repl = (footer_a > 0.0)
					? texture(texture_footer, base_uv_full)
					: texture(texture_sides, uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			}

		} else if (match_color(src.rgb, south_west_side_mask.rgb)) {

			if (is_south_west_visible) {
				vec2 uv = base_uv + vec2(0.0, 0.5);
				vec4 repl = (footer_a > 0.0)
					? texture(texture_footer, base_uv_full)
					: texture(texture_sides, uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			}

		} else if (match_color(src.rgb, south_side_mask.rgb)) {

			if (is_south_visible) {
				vec2 uv = base_uv + vec2(0.5, 0.0);
				vec4 repl = (footer_a > 0.0)
					? texture(texture_footer, base_uv_full)
					: texture(texture_sides, uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			}

		} else if (match_color(src.rgb, north_east_side_mask.rgb)) {

			if (is_north_east_visible) {
				vec2 uv = base_uv + vec2(0.0, 0.5); // adjust if atlas layout differs
				vec4 repl = (footer_a > 0.0)
					? texture(texture_footer, base_uv_full)
					: texture(texture_sides, uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			}

		} else if (match_color(src.rgb, north_west_side_mask.rgb)) {

			if (is_north_west_visible) {
				vec2 uv = base_uv + vec2(0.5, 0.5); // adjust if atlas layout differs
				vec4 repl = (footer_a > 0.0)
					? texture(texture_footer, base_uv_full)
					: texture(texture_sides, uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			}

		} else if (passthrough_unmatched) {
			out_col = src;
		}

		// Shade multiply
		vec4 shade = texture(texture_shade, pp_uv);
		if (out_col.a > 0.01 && shade.a > 0.01 && shade_strength > 0.0) {
			out_col.rgb *= mix(vec3(1.0), shade.rgb, clamp(shade_strength * shade.a, 0.0, 1.0));
		}

		out_col.a *= COLOR.a;
	}

	COLOR = out_col;
}