class_name MapCanvas
extends Control
## The drawing surface of the map screen (MAP1 ux): the room numbers along the top, the lines between nodes, and one MapNodeButton per node.
## Pure view: `setup` takes the screen's data ({map, path, reachable, nodes}) and builds; nothing here decides what a press does, it
## re-emits the buttons' signals with the node id.
##
## Lines: the path taken is bright and thick, the lines from the current node to the nodes you can pick are white, the rest are dim but
## readable. Node centres come from MapLayout so the layout is testable without a scene.

signal node_pressed(node_id: int)
signal node_hovered(node_id: int)
signal node_unhovered(node_id: int)
signal node_focused(node_id: int)

var _data: Dictionary = {}
var _cfg: Dictionary = {}
var _unit: float = 1.0
var _view_only: bool = false
var _buttons: Dictionary = {}
var _centres: Dictionary = {}
var _infos: Dictionary = {}
var _dims: Vector2i = Vector2i(1, 1)
var _grid: Rect2 = Rect2()
var _base_radius: float = 16.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


## Builds the nodes. `unit` is pixels per authored pixel. In view-only mode every node can take focus (so the arrows can look around);
## when picking only the nodes you can pick can.
func setup(data: Dictionary, cfg: Dictionary, unit: float, view_only: bool) -> void:
	_data = data
	_cfg = cfg
	_unit = unit
	_view_only = view_only
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_infos.clear()
	var map: Dictionary = data.get("map", {})
	_dims = MapLayout.dimensions(map)
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	var run_ui: Dictionary = UiConfig.run_ui()
	var names: Dictionary = RunConfig.ui().get("type_names", {})
	for entry: Variant in (data.get("nodes", []) as Array):
		var info: Dictionary = entry
		var id: int = int(info["id"])
		_infos[id] = info
		var button := MapNodeButton.new()
		button.name = "Node%d" % id
		button.set_meta(&"unit", unit)
		button.focus_mode = Control.FOCUS_ALL if (view_only or bool(info.get("reachable", false))) else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(button)
		var type_id: String = String(info["type"])
		var tag: String = String(names.get(type_id, type_id))
		if String(info.get("chest_name", "")) != "":
			tag = "%s (%s)" % [tag, String(info["chest_name"]).to_lower()]
		button.set_meta(&"tag", tag)
		button.set_meta(&"color", RunIcons.color_for(type_id, run_ui, tiers))
		button.pressed.connect(func() -> void: node_pressed.emit(id))
		button.mouse_entered.connect(func() -> void: node_hovered.emit(id))
		button.mouse_exited.connect(func() -> void: node_unhovered.emit(id))
		button.focus_entered.connect(func() -> void: node_focused.emit(id))
		_buttons[id] = button
	relayout()


func button_for(node_id: int) -> MapNodeButton:
	return _buttons.get(node_id) as MapNodeButton


func buttons() -> Dictionary:
	return _buttons


func centre_of(node_id: int) -> Vector2:
	return _centres.get(node_id, Vector2.ZERO)


func base_radius() -> float:
	return _base_radius


## The rectangle (in this control's coordinates) the grid of nodes uses: the canvas minus the room-number strip on top.
func grid_rect() -> Rect2:
	return _grid


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _data.is_empty():
		relayout()


## Positions every node from the current size. Called on resize and after setup.
func relayout() -> void:
	if _data.is_empty():
		return
	var strip: float = float(MapLayout.font_px(float(_cfg["room_font_size"]), _unit, float(_cfg["min_font_px"]))) + 10.0 * _unit
	_grid = Rect2(Vector2(0.0, strip), Vector2(size.x, maxf(size.y - strip, 1.0)))
	_base_radius = MapLayout.node_radius(_grid, _dims, float(_cfg["node_radius_cell"]), float(_cfg["node_radius_max"]) * _unit)
	var label_px: int = MapLayout.font_px(float(_cfg["node_label_font_size"]), _unit, float(_cfg["min_font_px"]))
	_centres.clear()
	for id: int in _buttons.keys():
		var info: Dictionary = _infos[id]
		var centre: Vector2 = MapLayout.center(_grid, _dims, int(info["room"]), int(info["column"]))
		_centres[id] = centre
		var node_radius: float = MapLayout.radius_for(info, _base_radius, _cfg.get("chest_scale", {}))
		var button: MapNodeButton = _buttons[id]
		var side: float = maxf(node_radius * 3.3, 36.0 * _unit)
		button.position = centre - Vector2(side, side) * 0.5
		button.size = Vector2(side, side)
		button.setup(info, node_radius, button.get_meta(&"color"), _cfg, String(button.get_meta(&"tag")) if String(MapLayout.node_state(info)) == MapLayout.STATE_REACHABLE else "", label_px)
	queue_redraw()


func _draw() -> void:
	if _data.is_empty():
		return
	var font: Font = get_theme_default_font()
	var room_px: int = MapLayout.font_px(float(_cfg["room_font_size"]), _unit, float(_cfg["min_font_px"]))
	var room_color := Color.html(String(_cfg["room_color"]))
	var cell: Vector2 = MapLayout.cell_size(_grid, _dims)
	for room in range(1, _dims.x + 1):
		var text: String = str(ActText.run_room(room, int(_data.get("act", 1)), int(_data.get("run_room_total", 0)), int(_data.get("acts_total", 1))))  # act 2 reads 11..20, as the HUD does
		var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, room_px)
		var x: float = (float(room) - 0.5) * cell.x - text_size.x * 0.5
		draw_string(font, Vector2(x, float(room_px) + 2.0 * _unit), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, room_px, room_color)
	var path: Array = _data.get("path", [])
	var current: int = int(path[path.size() - 1]) if not path.is_empty() else -1
	var dim := Color.html(String(_cfg["edge_color"]))
	var path_color := Color.html(String(_cfg["path_color"]))
	var reach_color := Color.html(String(_cfg["reach_color"]))
	var edges: Array = (_data.get("map", {}) as Dictionary).get("edges", [])
	# Three passes so a bright line is never covered by a dim one: dim, reachable, then the taken path on top.
	for pass_index in range(3):
		for edge: Variant in edges:
			var from_id: int = int((edge as Array)[0])
			var to_id: int = int((edge as Array)[1])
			if not _centres.has(from_id) or not _centres.has(to_id):
				continue
			var kind: int = _edge_kind(from_id, to_id, path, current)
			if kind != pass_index:
				continue
			var width: float = float(_cfg["edge_width"]) * _unit
			var color: Color = dim
			if kind == 1:
				color = reach_color
				width = float(_cfg["reach_edge_width"]) * _unit
			elif kind == 2:
				color = path_color
				width = float(_cfg["path_edge_width"]) * _unit
			var a: Vector2 = _centres[from_id]
			var b: Vector2 = _centres[to_id]
			var direction: Vector2 = (b - a).normalized()
			draw_line(a + direction * _base_radius * 0.9, b - direction * _base_radius * 0.9, color, maxf(width, 1.0), true)


## 0 = a plain line, 1 = from the current node to a node you can pick now, 2 = a step of the taken path.
func _edge_kind(from_id: int, to_id: int, path: Array, current: int) -> int:
	var at: int = path.find(from_id)
	if at >= 0 and at + 1 < path.size() and int(path[at + 1]) == to_id:
		return 2
	if from_id == current and bool((_infos.get(to_id, {}) as Dictionary).get("reachable", false)):
		return 1
	return 0
