shader_type spatial;
// Draws the player's silhouette only where scene geometry nearer the camera hides it.
// See PlayerOcclusionCue.gd. No depth test (we do our own, against the depth texture), no depth write.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix;

uniform vec4 cue_color : source_color = vec4(0.56, 0.82, 1.0, 0.75);
uniform float depth_bias = 0.05;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

void fragment() {
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	// View space looks down -Z: a larger z is nearer the camera. Occluded = something is nearer
	// than this body surface by more than the bias (the body's own depth is in the buffer too,
	// so a visible body matches itself and draws nothing).
	float occluded = step(depth_bias, scene_view.z - VERTEX.z);
	// A little brighter at the silhouette edge so the shape reads as an outline, not a blob.
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = cue_color.rgb;
	ALPHA = cue_color.a * occluded * mix(0.6, 1.0, rim);
}
