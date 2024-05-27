shader_type spatial;

render_mode wireframe, unshaded;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_width : hint_range(0.0, 1.0) = 0.2;
uniform float speed : hint_range(0.0, 10.0) = 1.0;
uniform float min_radius;
uniform float max_radius;
uniform float blur_distance;

float growing_circle(vec2 uv) {
	// Calculate the UV coordinate of the current pixel
	vec2 center = vec2(0.5, 0.5);
    float time = TIME * speed;

    // Calculate the current radius
    float radius = min_radius + mod(time, (max_radius - min_radius));

    // Calculate the distance from the current fragment to the center
    float dist = distance(uv, center);

    // Calculate the alpha value using smoothstep for a blurred edge
    float edge0 = radius - (line_width / 2.0) - blur_distance;
    float edge1 = radius - (line_width / 2.0);
    float edge2 = radius + (line_width / 2.0);
    float edge3 = radius + (line_width / 2.0) + blur_distance;

    return smoothstep(edge0, edge1, dist) - smoothstep(edge2, edge3, dist);
}

void vertex() {
	float alpha = growing_circle(UV);

	VERTEX = vec3(VERTEX.x, VERTEX.y, VERTEX.z + alpha);
}

void fragment() {
    float alpha = growing_circle(UV);

    // Set the color with the computed alpha value
    vec4 color = line_color;
    color.a *= alpha;

    // Output the final color if alpha is greater than a threshold
    if (color.a > 0.01) {
        ALBEDO = color.rgb;
		ALPHA = color.a;
    } else {
        discard;
    }
}
