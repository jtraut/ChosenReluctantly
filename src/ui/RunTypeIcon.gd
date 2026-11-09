class_name RunTypeIcon
extends Control
## Draws a RunIcons shape for a room type: a flat fill with a dark outline. Set `shape` and `color`, then
## it redraws. Ignores the mouse.

var shape: String = RunIcons.SHAPE_CIRCLE:
	set(value):
		shape = value
		queue_redraw()
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
## MAP3 ux: draws the merchant's coin (a ring and a dot) inside the shape, exactly as the map node does, so the legend matches the map.
var coin: bool = false:
	set(value):
		coin = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5
	var pts := RunIcons.polygon(shape, radius)
	if pts.size() < 3:
		return
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + size * 0.5)
	draw_colored_polygon(moved, color)
	var outline := moved.duplicate()
	outline.append(moved[0])
	draw_polyline(outline, Color(0.05, 0.03, 0.04, 1.0), maxf(radius * 0.14, 1.0), true)
	if coin:
		var coin_colour := Color(0.1, 0.06, 0.04, 1.0)
		draw_arc(size * 0.5, radius * 0.45, 0.0, TAU, 20, coin_colour, maxf(radius * 0.14, 2.0), true)
		draw_circle(size * 0.5, radius * 0.16, coin_colour)
