shader_type canvas_item;

uniform sampler2D player_texture;
uniform vec4 player_texture_region = vec4(0.0, 0.0, 0.0, 0.0);
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
		if (player_texture_region.z > 0.0) {
			vec2 uv = pos / trans_rect_size;
			uv = player_texture_region.xy + player_texture_region.zw * uv;
			vec4 c = texture(player_texture, uv);
			if (c.a > 0.5) {
				COLOR.a = min(COLOR.a, 0.1);
			}
		} else {
			COLOR.a = min(COLOR.a, 0.1);
		}
	}
}