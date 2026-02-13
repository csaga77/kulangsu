shader_type canvas_item;

uniform sampler2D texture_shade       : source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_footer_mask : source_color, repeat_enable, filter_nearest;

uniform bool is_top_visible = true;
uniform vec4 color_top   : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform sampler2D texture_top   : source_color, repeat_enable, filter_nearest;

uniform bool is_south_east_visible = true;
uniform vec4 color_south_east : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform sampler2D texture_south_east : source_color, repeat_enable, filter_nearest;

uniform bool is_south_west_visible = true;
uniform vec4 color_south_west  : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform sampler2D texture_south_west  : source_color, repeat_enable, filter_nearest;

uniform bool is_south_visible = true;
uniform vec4 color_south : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform sampler2D texture_south : source_color, repeat_enable, filter_nearest;

uniform bool is_footer_visible = false;
uniform sampler2D texture_footer : source_color, repeat_enable, filter_nearest;
// source tile size is tile map raw tile size (64 x 64)
const float source_tile_size = 64.0;


void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 px_src = floor(UV * texture_size) + vec2(0.5);
	vec2 pp_uv = px_src / texture_size;

	vec4 src = textureLod(TEXTURE, pp_uv, 0);
	vec4 out_col = vec4(0.0);
	
	float footer_start = source_tile_size;
	
	if (src.a > 0.0) {
		//Shade image is in the same texture
		vec4 footer_mask = vec4(0.0, 0.0, 0.0, 0.0);
		if (is_footer_visible) {
			footer_mask = textureLod(texture_footer_mask, pp_uv, 0);
		}

		vec2 px_tile = mod(px_src, source_tile_size);

		// for 32x32 material atlas (2x2 layout)
		vec2 base_uv = mod(px_tile / source_tile_size, 0.5);

		if (src.rgb == color_top.rgb) {
			if (is_top_visible) {
				vec4 repl = texture(texture_top, base_uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			}

		} else if (src.rgb == color_south_east.rgb) {

			if (is_south_east_visible) {
				if (footer_mask.a > 0.0) {
					vec4 repl = texture(texture_footer, base_uv + vec2(0.5, 0.5));
					out_col = vec4(repl.rgb, src.a * repl.a);
				} else {
					vec4 repl = texture(texture_south_east, base_uv + vec2(0.5, 0.5));
					out_col = vec4(repl.rgb, src.a * repl.a);
				}
			}

		} else if (src.rgb == color_south_west.rgb) {
			if (is_south_west_visible) {
				if (footer_mask.a > 0.0) {
					vec4 repl = texture(texture_footer, base_uv + vec2(0.0, 0.5));
					out_col = vec4(repl.rgb, src.a * repl.a);
				} else {
					vec4 repl = texture(texture_south_west, base_uv + vec2(0.0, 0.5));
					out_col = vec4(repl.rgb, src.a * repl.a);
				}
			}

		} else if (src.rgb == color_south.rgb) {
			if (is_south_visible) {
				if (footer_mask.a > 0.0) {
					vec4 repl = texture(texture_footer, base_uv + vec2(0.5, 0.0));
					out_col = vec4(repl.rgb, src.a * repl.a);
				} else {
					vec4 repl = texture(texture_south, base_uv + vec2(0.5, 0.0));
					out_col = vec4(repl.rgb, src.a * repl.a);
				}
			}
		} else {
			out_col = src;
		}
		
		//Shade image is in the same texture
		vec4 shade = texture(texture_shade, pp_uv);
		if (out_col.a > 0.0 && shade.a > 0.0) {
			out_col.rgb = mix(out_col.rgb, shade.rgb, 0.7);
		}
	}

	COLOR = out_col;
}