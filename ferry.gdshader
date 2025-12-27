shader_type canvas_item;

//uniform sampler2D overlay_tex: repeat_enable, filter_nearest;
uniform float scale = 0.006944444; // calculated by 1/texture size e.g. 1/144
uniform vec2 trans_rect_pos  = vec2(0, 0);
uniform vec2 trans_rect_size = vec2(0, 0);
varying vec2 world_position;

void vertex() {
	// calculate the world position for use in the fragment shader
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 pos = world_position - trans_rect_pos;
	if (trans_rect_size != vec2(0.0, 0.0) && pos.x >= 0.0 && pos.y >= 0.0 && pos.x < trans_rect_size.x && pos.y < trans_rect_size.y) {
		COLOR.a = min(COLOR.a, 0.5);
	}
	// only apply overlay_tex on the fully red parts of the original tiles
	//float mix_amount = floor(COLOR.r);
	
	// sample the overlay_tex using worldPos
	//vec4 overlay_color = texture(overlay_tex, world_position * scale);
	
	// combine original color and overlay color together
	//COLOR = mix(COLOR, overlay_color, mix_amount);
}