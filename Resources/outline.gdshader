shader_type canvas_item;

uniform bool outline_enabled = false;
uniform vec4 outline_color: source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width: hint_range(0.0, 10.0) = 2.0;
uniform float alpha_threshold: hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (outline_enabled && color.a < alpha_threshold) {
		vec2 size = outline_width * TEXTURE_PIXEL_SIZE;

		float alpha = 0.0;
		alpha = max(alpha, texture(TEXTURE, UV + vec2(size.x, 0.0)).a);
		alpha = max(alpha, texture(TEXTURE, UV - vec2(size.x, 0.0)).a);
		alpha = max(alpha, texture(TEXTURE, UV + vec2(0.0, size.y)).a);
		alpha = max(alpha, texture(TEXTURE, UV - vec2(0.0, size.y)).a);
		alpha = max(alpha, texture(TEXTURE, UV + vec2(size.x, size.y)).a);
		alpha = max(alpha, texture(TEXTURE, UV - vec2(size.x, size.y)).a);
		alpha = max(alpha, texture(TEXTURE, UV + vec2(size.x, -size.y)).a);
		alpha = max(alpha, texture(TEXTURE, UV + vec2(-size.x, size.y)).a);

		if (alpha > alpha_threshold) {
			COLOR = outline_color;
			return;
		}
	}

	COLOR = color;
}
