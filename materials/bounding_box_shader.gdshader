shader_type spatial;

render_mode wireframe, unshaded;

uniform vec4 diffuse_color: source_color = vec4(0.87, 0.67, 0.37, 1.0);

void fragment() {
    ALBEDO = diffuse_color.rgb;
	ALPHA = diffuse_color.a;
}