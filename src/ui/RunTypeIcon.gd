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
