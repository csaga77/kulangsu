shader_type canvas_item;

uniform bool is_top_visible = true;
uniform vec4 color_top   : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform sampler2D texture_top   : source_color, repeat_enable, filter_nearest;

uniform bool is_front_visible = true;
uniform vec4 color_front : source_color = vec4(1.0, 0.0, 1.0, 1.0);
uniform sampler2D texture_front : source_color, repeat_enable, filter_nearest;

uniform bool is_left_visible = true;
uniform vec4 color_left  : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform sampler2D texture_left  : source_color, repeat_enable, filter_nearest;

// source tile size is tile map raw tile size (64 x 64)
uniform float source_tile_size = 64.0;
//uniform float texture_scale = 1.0;

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 px_src = floor(UV * texture_size) + vec2(0.5);
	vec2 pp_uv = px_src / texture_size;
	// Pixel-perfect source sample
	vec4 src   = texture(TEXTURE, pp_uv);
	vec4 out_col = vec4(0.0, 0.0, 0.0, 0.0);
	if (src.a > 0.0) {
		vec2 px_tile = mod(px_src, source_tile_size);
		//for 32 x 32 material
		vec2 base_uv = mod(px_tile / source_tile_size, 0.5);
		//for 64 x 64 material
		//vec2 base_uv = (px_tile / source_tile_size) * 0.5;
		if (src.rgb == color_top.rgb) {
			if (is_top_visible) {
				vec4 repl = texture(texture_top, base_uv);
				out_col = vec4(repl.rgb, src.a * repl.a);
			} 
		} else if (src.rgb == color_front.rgb) {
			if (is_front_visible) {
				vec4 repl = texture(texture_front, base_uv + vec2(0.5, 0.5));
				out_col = vec4(repl.rgb, src.a * repl.a);
			}
		} else if (src.rgb == color_left.rgb) {
			vec4 repl = texture(texture_left, base_uv + vec2(0.0, 0.5));
			if (is_left_visible) {
				out_col = vec4(repl.rgb, src.a * repl.a);
			}
		} else {
			out_col = src;
		}
	}

	COLOR = out_col;
}