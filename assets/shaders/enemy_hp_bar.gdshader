shader_type spatial;
// Enemy HP bar: one billboarded quad per enemy, one shared material.
// The camera is orthographic, so a fixed world size is a fixed on-screen size.
// Per-bar state is driven by instance uniforms (no per-bar material).
// Depth-tested (Slice 5a): a bar is hidden by a model standing in front of it
// instead of being drawn over unrelated enemies. The quad is opaque (discard, no blend).
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec2 total_size = vec2(1.5, 0.15); // world units, whole quad
uniform float bar_width = 1.1;
uniform float bar_height = 0.15; // the bar itself; the quad is taller (pip_scale) so the pips can be bigger than the bar, bar centred
uniform float pip_width = 0.19;
uniform float left_pad = 0.38; // two pip slots left of the bar: [shield][diamond]; the right side mirrors the width
uniform float border = 0.02;
uniform float resist_border = 0.04;
uniform vec4 fill_color : source_color = vec4(0.89, 0.28, 0.25, 1.0);
uniform vec4 ghost_color : source_color = vec4(1.0, 0.84, 0.66, 1.0);
uniform vec4 back_color : source_color = vec4(0.11, 0.07, 0.09, 1.0);
uniform vec4 frame_color : source_color = vec4(0.05, 0.03, 0.04, 1.0);
uniform vec4 burn_color : source_color = vec4(1.0, 0.6, 0.12, 1.0);
uniform vec4 bleed_color : source_color = vec4(0.88, 0.07, 0.25, 1.0);

instance uniform float fill = 1.0;
instance uniform vec4 status_flags = vec4(0.0); // x = burning, y = bleeding
instance uniform float ghost = 1.0;
// rgb = resistance tint, a > 0.5 means "resistant" (thicker frame + diamond pip).
instance uniform vec4 resist_tint = vec4(0.0);
// rgb = armor tint, a > 0.5 means "armored" (a shield pip left of the diamond slot).
instance uniform vec4 armor_tint = vec4(0.0);

void vertex() {
	// Cylindrical-free full billboard: keep model translation, face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * total_size;
	float h = total_size.y; // pip glyph height (the full quad)
	float bar_y0 = (total_size.y - bar_height) * 0.5;
	float by = p.y - bar_y0; // y inside the bar
	bool resistant = resist_tint.a > 0.5;
	bool armored = armor_tint.a > 0.5;
	vec4 col = vec4(0.0);
	bool inside = false;

	float bar_x0 = left_pad;
	float bar_x1 = left_pad + bar_width;

	if (p.x >= bar_x0 && p.x <= bar_x1) {
		inside = by >= 0.0 && by <= bar_height;
		float b = resistant ? resist_border : border;
		vec4 frame = resistant ? vec4(resist_tint.rgb, 1.0) : frame_color;
		float ix = p.x - bar_x0;
		if (ix < b || ix > bar_width - b || by < b || by > bar_height - b) {
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
	} else if (p.x < pip_width && armored) {
		// Outer left pip: a shield (flat top, pointed bottom) in the armor tint, dark outline. Different shape from
		// the resistance diamond, so the two never rely on colour.
		vec2 q = (p - vec2(pip_width * 0.5, h * 0.5)) / (h * 0.5);
		float outer = min(0.85, 1.0 - q.y);
		if (q.y > -1.0 && q.y < 1.0 && abs(q.x) < outer) {
			inside = true;
			float inner_r = 0.6;
			vec2 qi = vec2(q.x, q.y - 0.12) / inner_r;
			float inner_w = min(0.85, 1.0 - qi.y);
			bool in_inner = qi.y > -1.0 && qi.y < 1.0 && abs(qi.x) < inner_w;
			col = in_inner ? vec4(armor_tint.rgb, 1.0) : frame_color;
		}
	} else if (p.x >= pip_width && p.x < bar_x0 && resistant) {
		// Inner left pip: diamond in the resistance tint, dark outline.
		vec2 d = abs(p - vec2(pip_width * 1.5, h * 0.5));
		float m = d.x + d.y;
		if (m < h * 0.5) {
			inside = true;
			col = m < h * 0.32 ? vec4(resist_tint.rgb, 1.0) : frame_color;
		}
	} else if (p.x > bar_x1 && p.x <= bar_x1 + pip_width && (status_flags.x > 0.5 || status_flags.y > 0.5)) {
		// Right pip: one slot for both statuses. Burn = upward flame triangle. Bleed = downward drop triangle
		// (the opposite point), so the two differ by shape as well as colour. With both on, they alternate.
		bool burning = status_flags.x > 0.5;
		bool bleeding = status_flags.y > 0.5;
		bool show_bleed = bleeding && (!burning || fract(TIME / 1.6) > 0.5);
		float u = (p.x - bar_x1) / pip_width;
		float v = p.y / h;
		if (show_bleed) {
			v = 1.0 - v;
		}
		float half_w = clamp((v - 0.05) / 0.9, 0.0, 1.0) * 0.45;
		float du = abs(u - 0.5);
		if (v > 0.05 && v < 0.95 && du < half_w + 0.06) {
			inside = true;
			col = du < half_w - 0.04 && v < 0.88 ? (show_bleed ? bleed_color : burn_color) : frame_color;
		}
	}

	if (!inside) {
		discard;
	}
	ALBEDO = col.rgb;
	// No ALPHA write on purpose: that keeps the bar in the opaque pass, which tests and writes depth.
}
