class_name BossMeter
extends Control
## The boss HP meter (3c): fill, ghost trail, back and frame in the enemy bar's colours; a notch and a line at each
## phase threshold; the resistance frame and diamond pip as the enemy bars draw them; and the "invulnerable" look
## (diagonal stripes over the fill, a thick bright frame) for the roar. Pure drawing: BossHpBar feeds it state.
## Layout (pixels, scaled by the caller): the top `notch_h` px hold the threshold notches, the bar is below them,
## `pip` px of room on each side (the left one holds the diamond).

var fill: float = 1.0
var ghost: float = 1.0
## Threshold fractions of max HP (0..1), descending, e.g. [0.66, 0.33].
var thresholds: Array[float] = []
## How many thresholds are already passed (their notch and line are drawn dim and hollow).
var crossed: int = 0
var invulnerable: bool = false
var invuln_phase: float = 0.0
## Resistance tint with alpha > 0.5 = resistant (thicker frame + diamond), like the enemy bars.
var resist_tint: Color = Color(0.0, 0.0, 0.0, 0.0)
var colors: Dictionary = {}
var notch_h: float = 6.0
var pip: float = 18.0
var border: float = 2.0
var resist_border: float = 4.0
var ui_scale: float = 1.0
var style: Dictionary = {}


## Screen x of a fraction of max HP along the bar: the fill edge and a threshold tick use this one function, so a
## tick sits exactly on the fill edge when HP is parked on the threshold. `x0`/`width` are the bar's outer span.
static func edge_x(ratio: float, x0: float, width: float, frame: float) -> float:
	return x0 + frame + clampf(ratio, 0.0, 1.0) * (width - 2.0 * frame)


func bar_rect() -> Rect2:
	return Rect2(pip, notch_h, maxf(size.x - 2.0 * pip, 1.0), maxf(size.y - notch_h, 1.0))


func _frame_width() -> float:
	return resist_border if resist_tint.a > 0.5 else border


func _draw() -> void:
	var bar := bar_rect()
	var frame_w: float = _frame_width()
	var back: Color = Color.html(String(colors.get("back", "#1c1218")))
	var frame_dark: Color = Color.html(String(colors.get("frame", "#0d080b")))
	var frame_color: Color = frame_dark
	if resist_tint.a > 0.5:
		frame_color = Color(resist_tint.r, resist_tint.g, resist_tint.b, 1.0)
	if invulnerable:
		frame_color = Color.html(String(style.get("invuln_color", "#fff3c4")))
	draw_rect(bar, frame_color)
	var inner := Rect2(bar.position + Vector2(frame_w, frame_w), bar.size - Vector2(frame_w, frame_w) * 2.0)
	draw_rect(inner, back)
	var x_fill: float = edge_x(fill, bar.position.x, bar.size.x, frame_w)
	var x_ghost: float = edge_x(ghost, bar.position.x, bar.size.x, frame_w)
	if x_ghost > x_fill:
		draw_rect(Rect2(x_fill, inner.position.y, x_ghost - x_fill, inner.size.y), Color.html(String(colors.get("ghost", "#ffd7a8"))))
	if x_fill > inner.position.x:
		draw_rect(Rect2(inner.position.x, inner.position.y, x_fill - inner.position.x, inner.size.y), Color.html(String(colors.get("fill", "#e2483f"))))
	if invulnerable:
		_draw_stripes(inner)
	_draw_thresholds(bar, frame_w, inner)
	if resist_tint.a > 0.5:
		_draw_diamond(bar)


func _draw_stripes(inner: Rect2) -> void:
	var stripe: Color = Color.html(String(style.get("invuln_stripe_color", "#fff3c4")))
	stripe.a = 0.35 + 0.25 * (0.5 + 0.5 * sin(invuln_phase * TAU))
	var step: float = maxf(12.0 * ui_scale, 6.0)
	var w: float = maxf(4.0 * ui_scale, 2.0)
	var x: float = inner.position.x - inner.size.y
	while x < inner.end.x:
		# A diagonal band, clipped to the inner rectangle by clamping its corners.
		var a := Vector2(x, inner.end.y)
		var b := Vector2(x + inner.size.y, inner.position.y)
		var pts := PackedVector2Array([a, b, b + Vector2(w, 0.0), a + Vector2(w, 0.0)])
		var clipped := PackedVector2Array()
		for p in pts:
			clipped.append(Vector2(clampf(p.x, inner.position.x, inner.end.x), p.y))
		if Geometry2D.triangulate_polygon(clipped).size() >= 3:
			draw_colored_polygon(clipped, stripe)
		x += step


func _draw_thresholds(bar: Rect2, frame_w: float, inner: Rect2) -> void:
	var ticks: Array = style.get("ticks", ["#f4ece8", "#8d8089"])
	var live: Color = Color.html(String(ticks[0]))
	var dim: Color = Color.html(String(ticks[1]))
	var dark: Color = Color.html(String(colors.get("frame", "#0d080b")))
	var half: float = maxf(notch_h * 0.9, 3.0)
	for i in range(thresholds.size()):
		var x: float = edge_x(thresholds[i], bar.position.x, bar.size.x, frame_w)
		var passed: bool = i < crossed
		var color: Color = dim if passed else live
		# Line through the bar: dark under-stroke, then the light line (a 1-2 px line alone vanishes on the red fill).
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), dark, maxf(4.0 * ui_scale, 3.0))
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), color, maxf(2.0 * ui_scale, 1.5))
		# Notch above the bar: a downward triangle, solid while ahead, an outline once passed.
		var tri := PackedVector2Array([Vector2(x - half, 0.0), Vector2(x + half, 0.0), Vector2(x, notch_h + 1.0)])
		if passed:
			var closed := PackedVector2Array([tri[0], tri[1], tri[2], tri[0]])
			draw_polyline(closed, color, maxf(1.5 * ui_scale, 1.0), true)
		else:
			draw_colored_polygon(tri, color)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), dark, 1.0, true)


func _draw_diamond(bar: Rect2) -> void:
	var h: float = bar.size.y
	var c := Vector2(pip * 0.5, bar.position.y + h * 0.5)
	var dark: Color = Color.html(String(colors.get("frame", "#0d080b")))
	var r: float = minf(h * 0.5, pip * 0.5 + 1.0)
	_diamond(c, r, dark)
	_diamond(c, r * 0.64, Color(resist_tint.r, resist_tint.g, resist_tint.b, 1.0))


func _diamond(c: Vector2, r: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0), c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), color)
