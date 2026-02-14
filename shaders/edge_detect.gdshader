shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// Threshold in meters (linear depth)
uniform float edge_threshold : hint_range(0.1, 10.0) = 0.5;
uniform vec4 edge_color : source_color = vec4(1.0, 0.0, 1.0, 1.0); // Magenta

// Linearize depth function
float get_linear_depth(float depth, mat4 inv_proj_mat) {
	vec3 ndc = vec3(0.0, 0.0, depth) * 2.0 - 1.0;
	vec4 view = inv_proj_mat * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	// Center Depth
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	float depth_linear = get_linear_depth(depth_raw, INV_PROJECTION_MATRIX);
	
	// Adaptive parameters based on distance
	// Thickness: Start at 2.0px, drop to 0.5px at 1000m
	float thick_scale = mix(2.0, 0.5, clamp(depth_linear / 1000.0, 0.0, 1.0));
	
	// Threshold: Start at edge_threshold, increase significantly with distance
	// e.g. at 0m = threshold, at 500m = threshold * 50
	float adaptive_threshold = edge_threshold * (1.0 + depth_linear * 0.1);
	
	// Neighbor Depths with adaptive offset
	vec2 pixel_size = 1.0 / VIEWPORT_SIZE;
	vec2 offset = pixel_size * thick_scale;
	
	float d_up = get_linear_depth(texture(depth_texture, SCREEN_UV + vec2(0.0, -offset.y)).r, INV_PROJECTION_MATRIX);
	float d_down = get_linear_depth(texture(depth_texture, SCREEN_UV + vec2(0.0, offset.y)).r, INV_PROJECTION_MATRIX);
	float d_left = get_linear_depth(texture(depth_texture, SCREEN_UV + vec2(-offset.x, 0.0)).r, INV_PROJECTION_MATRIX);
	float d_right = get_linear_depth(texture(depth_texture, SCREEN_UV + vec2(offset.x, 0.0)).r, INV_PROJECTION_MATRIX);
	
	// Calculate Edge
	float diff = 0.0;
	diff += abs(depth_linear - d_up);
	diff += abs(depth_linear - d_down);
	diff += abs(depth_linear - d_left);
	diff += abs(depth_linear - d_right);
	
	vec4 original_color = texture(screen_texture, SCREEN_UV);
	
	if (diff > adaptive_threshold) {
		// Soften the alpha blending
		float alpha = clamp((diff - adaptive_threshold) * 0.5, 0.0, 1.0);
		ALBEDO = mix(original_color.rgb, edge_color.rgb, alpha);
	} else {
		ALBEDO = original_color.rgb;
	}
}
