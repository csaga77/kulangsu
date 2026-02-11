shader_type canvas_item;

uniform vec4 color_top   : source_color = vec4(1.0, 1.0, 0.0, 1.0); // color to replace
uniform sampler2D texture_top : source_color, repeat_enable, filter_nearest;

uniform vec4 color_front : source_color = vec4(1.0, 0.0, 1.0, 1.0); // color to replace
uniform sampler2D texture_front : source_color, repeat_enable, filter_nearest;

uniform vec4 color_left  : source_color = vec4(0.0, 1.0, 0.0, 1.0); // color to replace
uniform sampler2D texture_left : source_color, repeat_enable, filter_nearest;

uniform float tolerance = 0.02; // color match tolerance
uniform vec2 tiles_set_size = vec2(60, 8);

void fragment() {
	// Default: keep original
	vec4 out_col = COLOR;
	// If color matches (within tolerance), replace it
	if (out_col == color_top) {
		vec4 repl = texture(texture_top, fract(UV * tiles_set_size) * 0.5);
		out_col = vec4(repl.rgb, COLOR.a * repl.a);
	}  else if (out_col == color_front) {
		vec4 repl = texture(texture_front, fract(UV * tiles_set_size) * 0.5 + vec2(0.5, 0.5));
		out_col = vec4(repl.rgb, COLOR.a * repl.a);
	} else if (out_col == color_left) {
		vec4 repl = texture(texture_left, fract(UV * tiles_set_size) * 0.5 + vec2(0.0, 0.5));
		out_col = vec4(repl.rgb, COLOR.a * repl.a);
	}

	COLOR = out_col;
}