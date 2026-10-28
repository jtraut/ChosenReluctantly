shader_type spatial;
// Enemy HP bar: one billboarded quad per enemy, one shared material.
// The camera is orthographic, so a fixed world size is a fixed on-screen size.
// Per-bar state is driven by instance uniforms (no per-bar material).
// Depth-tested (Slice 5a): a bar is hidden by a model standing in front of it
// instead of being drawn over unrelated enemies. The quad is opaque (discard, no blend).
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform vec2 total_size = vec2(1.5, 0.15); // world units, whole quad
uniform float bar_width = 1.1;
uniform float pip_width = 0.19;
uniform float border = 0.02;
uniform float resist_border = 0.04;
uniform vec4 fill_color : source_color = vec4(0.89, 0.28, 0.25, 1.0);
uniform vec4 ghost_color : source_color = vec4(1.0, 0.84, 0.66, 1.0);
uniform vec4 back_color : source_color = vec4(0.11, 0.07, 0.09, 1.0);
uniform vec4 frame_color : source_color = vec4(0.05, 0.03, 0.04, 1.0);
uniform vec4 burn_color : source_color = vec4(1.0, 0.6, 0.12, 1.0);

instance uniform float fill = 1.0;
instance uniform vec4 status_flags = vec4(0.0); // x = burning
instance uniform float ghost = 1.0;
// rgb = resistance tint, a > 0.5 means "resistant" (thicker frame + diamond pip).
instance uniform vec4 resist_tint = vec4(0.0);

void vertex() {
	// Cylindrical-free full billboard: keep model translation, face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * total_size;
	float h = total_size.y;
	bool resistant = resist_tint.a > 0.5;
	vec4 col = vec4(0.0);
	bool inside = false;

	float bar_x0 = pip_width;
	float bar_x1 = pip_width + bar_width;

	if (p.x >= bar_x0 && p.x <= bar_x1) {
		inside = true;
		float b = resistant ? resist_border : border;
		vec4 frame = resistant ? vec4(resist_tint.rgb, 1.0) : frame_color;
		float ix = p.x - bar_x0;
		if (ix < b || ix > bar_width - b || p.y < b || p.y > h - b) {
			col = frame;
		} else {
			float t = (ix - b) / (bar_width - 2.0 * b);
			if (t <= fill) {
				col = fill_color;
			} else if (t <= ghost) {
				col = ghost_color;
			} else {
				col = back_color;
			}
		}
	} else if (p.x < bar_x0 && resistant) {
		// Left pip: diamond in the resistance tint, dark outline.
		vec2 d = abs(p - vec2(pip_width * 0.5, h * 0.5));
		float m = d.x + d.y;
		if (m < h * 0.5) {
			inside = true;
			col = m < h * 0.32 ? vec4(resist_tint.rgb, 1.0) : frame_color;
		}
	} else if (p.x > bar_x1 && status_flags.x > 0.5) {
		// Right pip: upward flame triangle.
		float u = (p.x - bar_x1) / pip_width;
		float v = p.y / h;
		float half_w = clamp((v - 0.05) / 0.9, 0.0, 1.0) * 0.45;
		float du = abs(u - 0.5);
		if (v > 0.05 && v < 0.95 && du < half_w + 0.06) {
			inside = true;
			col = du < half_w - 0.04 && v < 0.88 ? burn_color : frame_color;
		}
	}

	if (!inside) {
		discard;
	}
	ALBEDO = col.rgb;
	ALPHA = 1.0;
}
