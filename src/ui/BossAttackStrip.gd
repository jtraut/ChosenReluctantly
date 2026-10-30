class_name BossAttackStrip
extends Control
## The boss attack line (3c): a warning triangle, the attack's label and a thin strip that drains as the wind-up
## runs out, so the player reads both what is coming and how long they have. Hidden between attacks.

var progress_left: float = 0.0
var colors: Dictionary = {}
var warn_color: Color = Color("#ffb08a")
var ui_scale: float = 1.0
var label: Label = null
## The STAGGERED cue: the strip and icons take the stagger colour and the icon is a burst, not the warning triangle.
var stagger: bool = false
var stagger_color: Color = Color("#bfe6ff")


func _draw() -> void:
	if label == null or not label.visible:
		return  # nothing is winding up: an idle strip would be a stray line
	var back: Color = Color.html(String(colors.get("back", "#1c1218")))
	var h: float = maxf(4.0 * ui_scale, 3.0)
	var strip := Rect2(0.0, size.y - h, size.x, h)
	draw_rect(strip, back)
	var tint: Color = stagger_color if stagger else warn_color
	draw_rect(Rect2(strip.position, Vector2(strip.size.x * clampf(progress_left, 0.0, 1.0), h)), tint)
	if label != null and label.visible:
		var font: Font = label.get_theme_font("font")
		var fs: int = label.get_theme_font_size("font_size")
		var text_w: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r: float = (size.y - h) * 0.5
		var c := Vector2((size.x - text_w) * 0.5 - r * 1.8, (size.y - h) * 0.5)
		var outline := Color(0.05, 0.03, 0.04)
		if stagger:
			# A four-point burst on both sides of the word ("it is open"), a different shape from the warning triangle.
			var t: float = r * 0.38
			for cx: float in [c.x, (size.x + text_w) * 0.5 + r * 1.8]:
				var o := Vector2(cx, c.y)
				var star := PackedVector2Array([o + Vector2(0.0, -r), o + Vector2(t, -t), o + Vector2(r, 0.0), o + Vector2(t, t),
					o + Vector2(0.0, r), o + Vector2(-t, t), o + Vector2(-r, 0.0), o + Vector2(-t, -t)])
				draw_colored_polygon(star, tint)
				star.append(star[0])
				draw_polyline(star, outline, 1.0, true)
		else:
			var tri := PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r * 1.05, r * 0.85), c + Vector2(-r * 1.05, r * 0.85)])
			draw_colored_polygon(tri, tint)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), outline, 1.0, true)
