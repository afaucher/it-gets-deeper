shader_type spatial;
render_mode unshaded, cull_disabled;

// Controls the distance at which the color fades to black (or far_color)
uniform float depth_range : hint_range(1.0, 500.0) = 50.0;
uniform float intensity_scale : hint_range(0.1, 10.0) = 1.0;

// Colors for near and far
uniform vec3 near_color : source_color = vec3(1.0, 1.0, 1.0); // White
uniform vec3 far_color : source_color = vec3(0.0, 0.0, 0.0); // Black

varying float view_depth;

void vertex() {
	// In Godot 4, VERTEX is in View Space in the vertex shader (local to camera).
	// Z is negative forward.
	view_depth = -VERTEX.z;
}

void fragment() {
	float dist_factor = clamp(view_depth / depth_range, 0.0, 1.0);
	
	// Apply power to adjust the "brightness curve"
	float brightness = pow(1.0 - dist_factor, intensity_scale);
	
	vec3 final_color = mix(far_color, near_color, brightness);
	
	ALBEDO = final_color;
}
