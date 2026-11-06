class_name MapNodeButton
extends Button
## One node on the map screen (MAP1 ux): a button that draws its room-type shape (RunIcons), so it takes the mouse, the arrow keys and
## Enter like any button. State is drawn three ways at once, never colour alone: the taken path has a gold outline, the current node a solid
## double ring, a node you can pick now a dashed white ring and its name underneath, and later nodes are dimmed. A relic stage grows with its
## chest size and shows 1 to 3 dots inside. A focused node gets corner brackets.
##
## It owns no logic: the map screen decides what a press does.

var info: Dictionary = {}
var radius: float = 18.0
var shape_color: Color = Color.WHITE
var _cfg: Dictionary = {}
var _label_px: int = 14
var _tag: String = ""


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)


## Sets what to draw. `cfg` is UiConfig.map_screen(), `radius` the base-shape radius (already scaled for the chest), `tag` the name drawn
## under a pickable node, `label_px` its size.
func setup(node_info: Dictionary, node_radius: float, color: Color, cfg: Dictionary, tag: String, label_px: int) -> void:
	info = node_info
	radius = node_radius
	shape_color = color
	_cfg = cfg
	_tag = tag
	_label_px = label_px
	queue_redraw()


func node_id() -> int:
	return int(info.get("id", -1))


func state() -> String:
	return MapLayout.node_state(info)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
		queue_redraw()


func _draw() -> void:
	if info.is_empty():
		return
	var centre: Vector2 = size * 0.5
	var node_state: String = state()
	var alpha: float = float(_cfg.get("dim_alpha", 0.5)) if node_state == MapLayout.STATE_FUTURE else 1.0
	var fill := Color(shape_color, alpha)
	var dark := Color(0.05, 0.03, 0.04, alpha)
	var pts: PackedVector2Array = RunIcons.polygon(RunIcons.shape_for(String(info.get("type", ""))), radius)
	var moved := PackedVector2Array()
	for p: Vector2 in pts:
		moved.append(p + centre)
	draw_colored_polygon(moved, fill)
	var outline := moved.duplicate()
	outline.append(moved[0])
	var ring_w: float = maxf(float(_cfg.get("ring_width", 4)) * _unit(), 2.0)
	if node_state == MapLayout.STATE_TAKEN or node_state == MapLayout.STATE_CURRENT:
		draw_polyline(outline, Color.html(String(_cfg.get("path_color", "#ffd7a8"))), maxf(ring_w * 0.8, 2.0), true)
	else:
		draw_polyline(outline, dark, maxf(radius * 0.14, 1.5), true)
	_draw_pips(centre, alpha)
	if String(info.get("type", "")) == "merchant":
		# A coin in the square: the merchant is where gold goes, and it must read at a glance even when it is dimmed.
		var coin := Color(0.1, 0.06, 0.04, alpha)
		draw_arc(centre, radius * 0.45, 0.0, TAU, 20, coin, maxf(radius * 0.14, 2.0), true)
		draw_circle(centre, radius * 0.16, coin)
	match node_state:
		MapLayout.STATE_CURRENT:
			var gold := Color.html(String(_cfg.get("current_color", "#ffd7a8")))
			draw_arc(centre, radius * 1.32, 0.0, TAU, 40, gold, ring_w, true)
			draw_arc(centre, radius * 1.32 + ring_w * 1.7, 0.0, TAU, 40, Color(gold, 0.7), maxf(ring_w * 0.5, 1.5), true)
		MapLayout.STATE_REACHABLE:
			var white := Color.html(String(_cfg.get("reach_color", "#ffffff")))
			var dashes: int = 14
			for i in range(dashes):
				var from_a: float = TAU * float(i) / float(dashes)
				draw_arc(centre, radius * 1.34, from_a, from_a + TAU / float(dashes) * 0.62, 6, white, ring_w * 0.85, true)
			if _tag != "":
				_draw_tag(centre)
	if has_focus():
		_draw_brackets(centre)


## The radius of a chest pip for a node of `radius`: big enough to count at 1024x600 on the smallest chest.
static func pip_radius(node_radius: float) -> float:
	return maxf(node_radius * 0.2, 2.6)


func _draw_pips(centre: Vector2, alpha: float) -> void:
	var count: int = MapLayout.pip_count(String(info.get("chest", "")))
	if count <= 0:
		return
	var pip_r: float = pip_radius(radius)
	var color := Color(Color.html(String(_cfg.get("pip_color", "#1a1218"))), alpha)
	var offsets: Array[Vector2] = []
	match count:
		1:
			offsets = [Vector2.ZERO]
		2:
			offsets = [Vector2(-radius * 0.28, 0.0), Vector2(radius * 0.28, 0.0)]
		_:
			offsets = [Vector2(0.0, -radius * 0.26), Vector2(-radius * 0.3, radius * 0.2), Vector2(radius * 0.3, radius * 0.2)]
	for offset: Vector2 in offsets:
		draw_circle(centre + offset, pip_r, color)


func _draw_tag(centre: Vector2) -> void:
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_px)
	var base := Vector2(centre.x - text_size.x * 0.5, centre.y + radius * 1.34 + text_size.y * 0.9 + 4.0)
	draw_string_outline(font, base, _tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_px, 5, Color(0.05, 0.03, 0.04, 0.95))
	draw_string(font, base, _tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _label_px, Color.html(String(_cfg.get("text_color", "#e8dfe3"))))


func _draw_brackets(centre: Vector2) -> void:
	var half: float = radius * 1.62
	var arm: float = half * 0.55
	var width: float = maxf(3.0 * _unit(), 2.0)
	var color := Color.html(String(_cfg.get("focus_color", "#ffffff")))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := centre + Vector2(half * sx, half * sy)
			draw_line(corner, corner + Vector2(-arm * sx, 0.0), color, width)
			draw_line(corner, corner + Vector2(0.0, -arm * sy), color, width)


## Pixels per authored pixel, from the owner's scale (set by the canvas through the `unit` meta).
func _unit() -> float:
	return float(get_meta(&"unit", 1.0))
