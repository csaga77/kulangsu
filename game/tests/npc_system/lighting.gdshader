shader_type canvas_item;
render_mode blend_add;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Set to the same RGB as your CanvasModulate color
uniform vec3 canvas_modulate_color : source_color = vec3(1.0, 1.0, 1.0);

uniform vec3  light_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float intensity  = 1.0;
uniform float gamma_mask = 1.0;

void fragment() {
	// Background already drawn (and typically already modulated)
	vec3 bg = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;

	// Mask from sprite brightness (dark -> transparent, white -> strong)
	vec3 mask_rgb = texture(TEXTURE, UV).rgb;
	float mask = dot(mask_rgb, vec3(0.299, 0.587, 0.114));
	mask = pow(mask, gamma_mask);

	// Light in 0..1 range (treat as “how much to brighten”)
	vec3 light = clamp(light_color * (mask * intensity), vec3(0.0), vec3(1.0));

	// Screen blend (looks less grey than pure add)
	vec3 screened = vec3(1.0) - (vec3(1.0) - bg) * (vec3(1.0) - light);

	// Additive contribution needed to reach screened result
	vec3 delta = max(screened - bg, vec3(0.0));

	// Compensate for CanvasModulate multiplying this sprite later
	vec3 cm = max(canvas_modulate_color, vec3(0.001));
	delta /= cm;

	// Output only the additive delta (blend_add will add it)
	COLOR = vec4(delta, 1.0);
}