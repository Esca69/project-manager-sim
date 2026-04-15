shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(outline_color.rgb, a * outline_color.a);
}
