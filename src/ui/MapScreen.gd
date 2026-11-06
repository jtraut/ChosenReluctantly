class_name MapScreen
extends CanvasLayer
## The map screen (MAP1 ux, MAP.md section 7). Two uses of one screen:
##   - PICK: the run asks for the next node (RunController.choice_requested with choice "node"). Reachable nodes can take focus and a pick.
##   - VIEW: opened from the pause screen's Map button. Nothing can be picked; every node can be looked at; Esc, Enter or Back closes it.
##
## Layout (all sizes data/ui.json `map_screen`, words data/run.json `ui.map`): title and gold on top, the map (one column per room, left
## to right), the hover/focus line, the legend, and a one-line key. It is built in code and has to fit 1024x600 without scrolling.
##
## Keys: arrows and Enter only (the fixed menu keys, D26 = A). No new bindings. Focus starts on the least surprising reachable node
## (MapLayout.default_focus) and its text is already on screen, and presses are ignored for the first `prompt_option_arm_delay` seconds, so a
## mashed Enter or Space from the fight cannot pick a room.
##
## Gating copies RunPromptScreen: while the game is paused the pick is held and shown on resume; a dead player or Game Over drops it.

enum Mode { HIDDEN, PICK, VIEW }

## A node was picked in PICK mode (after the run accepted it).
signal node_chosen(node_id: int)
## The VIEW screen closed.
signal view_closed()

var root: Control = null
var backdrop: ColorRect = null
var column: VBoxContainer = null
var title_label: Label = null
var line_label: Label = null
var gold_badge: GoldBadge = null
var earned_label: Label = null
var canvas: MapCanvas = null
var hover_label: Label = null
var legend_flow: HFlowContainer = null
var legend_note: Label = null
var hint_label: Label = null
var back_button: Button = null

var _controller: RunController = null
var _mode: Mode = Mode.HIDDEN
var _data: Dictionary = {}
## A pick that arrived (or was hidden) while the game was paused or another screen was up: shown on resume.
var _pick_pending: bool = false
var _armed_at_msec: int = 0
var _arm_generation: int = 0
var _hovered: int = -1
var _last_focus: int = -1
var _scale: float = 1.0
## The layer the PICK screen uses (same as the other run prompts); VIEW goes above the pause screen.
var _pick_layer: int = 9


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pick_layer = layer
	visible = false
	_build()
	get_viewport().size_changed.connect(_apply_style)
	GamePause.paused_changed.connect(_on_pause_changed)
	_controller = get_parent().get_node_or_null("RunController") as RunController
	if _controller != null:
		_controller.choice_requested.connect(_on_choice_requested)


func _exit_tree() -> void:
	if GamePause.paused_changed.is_connected(_on_pause_changed):
		GamePause.paused_changed.disconnect(_on_pause_changed)


# --- state ----------------------------------------------------------------------------------------

func is_open() -> bool:
	return visible


func mode() -> Mode:
	return _mode


func is_view_only() -> bool:
	return _mode == Mode.VIEW


## True while a node pick is waiting (shown or held back by a pause).
func pick_pending() -> bool:
	return _pick_pending


## Seconds-free test hook: presses are accepted from now on.
func disarm() -> void:
	_armed_at_msec = 0


func is_armed() -> bool:
	return Time.get_ticks_msec() >= _armed_at_msec


## What the screen shows now, as given: {map, path, reachable, nodes, gold, gold_earned}.
func data() -> Dictionary:
	return _data


# --- opening ----------------------------------------------------------------------------------------

func _on_choice_requested(model: Dictionary) -> void:
	if String(model.get("choice", "")) != RunNodes.OPTION_NODE:
		return
	show_pick(_data_from_model(model))


## The pick-next-node model as screen data.
func _data_from_model(model: Dictionary) -> Dictionary:
	var earned: int = int(_controller.last_summary().get("gold", 0)) if _controller != null else 0
	return {
		"map": model.get("map", {}), "path": model.get("path", []), "reachable": model.get("reachable", []), "nodes": model.get("nodes", []),
		"gold": int(model.get("gold", 0)), "gold_earned": earned,
	}


## The map as it is now, from the run (for the pause screen's view).
func data_from_controller() -> Dictionary:
	if _controller == null or not _controller.map_on():
		return {}
	var infos: Array[Dictionary] = _controller.node_infos()
	return {
		"map": _controller.map(), "path": _controller.taken_path(), "reachable": _controller.reachable_nodes(), "nodes": infos,
		"gold": _controller.gold(), "gold_earned": 0,
	}


## True when the run is in a state that can show a map (a map run).
func can_view() -> bool:
	return _controller != null and _controller.map_on()


## Opens the pick. Held while paused (shown on resume); dropped for a dead player or Game Over.
func show_pick(screen_data: Dictionary) -> void:
	if _blocked_by_game_over():
		_pick_pending = false
		return
	_data = screen_data
	_pick_pending = true
	if GamePause.is_paused() and _mode != Mode.VIEW:
		_hide_now()
		return
	if _mode == Mode.VIEW:
		return  # the view is up over the pause screen; the pick appears on resume
	_open(Mode.PICK)


## Opens the view-only map (the pause screen's Map button). False when there is no map to show.
func open_view() -> bool:
	var screen_data: Dictionary = data_from_controller()
	if screen_data.is_empty():
		return false
	return open_view_with(screen_data)


## Opens the view-only map for given data (tests, or a host without a controller).
func open_view_with(screen_data: Dictionary) -> bool:
	if _mode == Mode.VIEW or (screen_data.get("map", {}) as Dictionary).is_empty():
		return false
	_data = screen_data
	_open(Mode.VIEW)
	return true


func close_view() -> bool:
	if _mode != Mode.VIEW:
		return false
	_hide_now()
	view_closed.emit()
	if _pick_pending and not GamePause.is_paused():
		_resume_pick()
	return true


func _open(new_mode: Mode) -> void:
	_mode = new_mode
	layer = int(UiConfig.map_screen()["view_layer"]) if new_mode == Mode.VIEW else _pick_layer
	_hovered = -1
	_fill()
	visible = true
	var delay: float = float(UiConfig.run_ui().get("prompt_option_arm_delay", 0.4))
	_armed_at_msec = Time.get_ticks_msec() + (roundi(delay * 1000.0) if new_mode == Mode.PICK else 0)
	if new_mode == Mode.PICK:
		_dim_until_armed(delay)
	_focus_start()


func _hide_now() -> void:
	visible = false
	_mode = Mode.HIDDEN
	_arm_generation += 1


## The pick comes back after a pause (or after the view closed): rebuilt from the held data.
func _resume_pick() -> void:
	if not _pick_pending or _blocked_by_game_over():
		return
	if _controller != null and not _controller.has_choice():
		_pick_pending = false  # answered while it was hidden
		return
	_open(Mode.PICK)


func _on_pause_changed(is_paused: bool) -> void:
	if is_paused:
		if _mode == Mode.PICK:
			_hide_now()  # the pause screen has its own look; the pick returns on resume
		return
	if _mode == Mode.VIEW:
		_hide_now()
		view_closed.emit()
	if _pick_pending:
		_resume_pick()


func _blocked_by_game_over() -> bool:
	var main := get_parent() as Main
	if main == null:
		return false
	return main.is_game_over() or (main.player != null and main.player.is_dead())


# --- building ----------------------------------------------------------------------------------------

func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # swallows clicks so the world never sees them
	add_child(root)
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	column = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.name = "Titles"
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(titles)
	title_label = Label.new()
	title_label.name = "Title"
	titles.add_child(title_label)
	line_label = Label.new()
	line_label.name = "Line"
	titles.add_child(line_label)
	gold_badge = GoldBadge.new()
	gold_badge.name = "Gold"
	gold_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(gold_badge)
	earned_label = Label.new()
	earned_label.name = "Earned"
	earned_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(earned_label)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.pressed.connect(close_view)
	header.add_child(back_button)
	canvas = MapCanvas.new()
	canvas.name = "Canvas"
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(100.0, 100.0)
	column.add_child(canvas)
	canvas.node_pressed.connect(_on_node_pressed)
	canvas.node_hovered.connect(_on_node_hovered)
	canvas.node_unhovered.connect(_on_node_unhovered)
	canvas.node_focused.connect(_on_node_focused)
	hover_label = Label.new()
	hover_label.name = "Hover"
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hover_label.clip_text = true
	column.add_child(hover_label)
	legend_flow = HFlowContainer.new()
	legend_flow.name = "Legend"
	legend_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(legend_flow)
	legend_note = Label.new()
	legend_note.name = "LegendNote"
	legend_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend_note)
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint_label)


func _texts() -> Dictionary:
	return RunConfig.ui().get("map", {})


## Fills every part from `_data` and the current mode.
func _fill() -> void:
	var texts: Dictionary = _texts()
	var view: bool = _mode == Mode.VIEW
	title_label.text = String(texts.get("view_title" if view else "title", ""))
	var line: String = String(texts.get("view_line", "")) if view else (String(texts.get("start_hint", "")) if (_data.get("path", []) as Array).is_empty() else String(texts.get("line", "")))
	line_label.text = line
	gold_badge.set_total(int(_data.get("gold", 0)))
	var earned: int = int(_data.get("gold_earned", 0))
	earned_label.text = String(texts.get("gold_earned", "+%d")) % earned if (earned > 0 and not view) else ""
	earned_label.visible = earned_label.text != ""
	back_button.visible = view
	back_button.text = String(texts.get("back_label", "Back"))
	hint_label.text = String(texts.get("view_hint" if view else "pick_hint", ""))
	_apply_style()
	canvas.setup(_data, UiConfig.map_screen(), _scale, view)
	_build_legend()
	_wire_focus()
	_refresh_hover()


## Sizes, fonts and colours from data for the current window.
func _apply_style() -> void:
	if root == null:
		return
	var cfg: Dictionary = UiConfig.map_screen()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_scale = vp.y / maxf(float(cfg["reference_height"]), 1.0)
	var min_px: float = float(cfg["min_font_px"])
	backdrop.color = Color.html(String(cfg["backdrop_color"]))
	var margin: float = float(cfg["margin"]) * _scale
	var margin_box := root.get_node("Margin") as MarginContainer
	for side: String in ["left", "right", "top", "bottom"]:
		margin_box.add_theme_constant_override("margin_" + side, roundi(margin))
	column.add_theme_constant_override("separation", roundi(6.0 * _scale))
	_font(title_label, "title_font_size", cfg, Color.html(String(cfg["title_color"])), min_px)
	_font(line_label, "line_font_size", cfg, Color.html(String(cfg["hint_color"])), min_px)
	_font(earned_label, "gold_font_size", cfg, Color.html(String(cfg["gold_color"])), min_px)
	_font(hover_label, "hover_font_size", cfg, Color.html(String(cfg["text_color"])), min_px)
	_font(legend_note, "hint_font_size", cfg, Color.html(String(cfg["hint_color"])), min_px)
	_font(hint_label, "hint_font_size", cfg, Color.html(String(cfg["hint_color"])), min_px)
	var hover_px: int = MapLayout.font_px(float(cfg["hover_font_size"]), _scale, min_px)
	hover_label.custom_minimum_size.y = float(hover_px) * 1.3 * float(cfg["hover_lines"])
	var gold_px: int = MapLayout.font_px(float(cfg["gold_font_size"]), _scale, min_px)
	gold_badge.configure(gold_px, 1.6, 20.0 * _scale, Color.html(String(cfg["gold_color"])), Color.html("#ffffff"), false)
	gold_badge.custom_minimum_size = Vector2(float(gold_px) * 6.5, float(gold_px) * 1.5)
	var button_min: Array = cfg["button_min_size"]
	back_button.custom_minimum_size = Vector2(float(button_min[0]), float(button_min[1])) * _scale
	back_button.add_theme_font_size_override("font_size", MapLayout.font_px(float(cfg["button_font_size"]), _scale, min_px))
	_style_back_button(cfg)
	if canvas != null and not _data.is_empty() and visible:
		var keep: int = focused_node_id()  # a resize rebuilds the nodes; the focus must survive it
		canvas.setup(_data, cfg, _scale, _mode == Mode.VIEW)
		_build_legend()
		_wire_focus()
		if keep >= 0 and canvas.button_for(keep) != null:
			canvas.button_for(keep).grab_focus()


func _font(label: Label, key: String, cfg: Dictionary, color: Color, min_px: float) -> void:
	label.add_theme_font_size_override("font_size", MapLayout.font_px(float(cfg[key]), _scale, min_px))
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)


func _style_back_button(cfg: Dictionary) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color.html("#1c1218")
		box.border_color = Color.html(String(cfg["text_color"]))
		var width: int = maxi(1, roundi(2.0 * _scale))
		box.set_border_width_all(width * 2 if state == "focus" else width)
		if state == "focus":
			box.draw_center = false
		box.set_content_margin_all(8.0 * _scale)
		back_button.add_theme_stylebox_override(state, box)


## One entry per node type on this map (a shape and its name), then the dots note if a relic stage is there and the ring key.
func _build_legend() -> void:
	for child in legend_flow.get_children():
		legend_flow.remove_child(child)
		child.queue_free()
	var cfg: Dictionary = UiConfig.map_screen()
	var min_px: float = float(cfg["min_font_px"])
	var texts: Dictionary = _texts()
	var names: Dictionary = RunConfig.ui().get("type_names", {})
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	var icon_px: float = float(cfg["legend_icon_size"]) * _scale
	legend_flow.add_theme_constant_override("h_separation", roundi(16.0 * _scale))
	legend_flow.add_theme_constant_override("v_separation", roundi(2.0 * _scale))
	var map: Dictionary = _data.get("map", {})
	for type_id: String in MapLayout.legend_types(map):
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", roundi(5.0 * _scale))
		item.set_meta(&"type", type_id)
		var icon := RunTypeIcon.new()
		icon.shape = RunIcons.shape_for(type_id)
		icon.color = RunIcons.color_for(type_id, UiConfig.run_ui(), tiers)
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		var label := Label.new()
		label.text = String(names.get(type_id, type_id))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", MapLayout.font_px(float(cfg["legend_font_size"]), _scale, min_px))
		label.add_theme_color_override("font_color", Color.html(String(cfg["text_color"])))
		item.add_child(label)
		legend_flow.add_child(item)
	var note: PackedStringArray = PackedStringArray()
	note.append(String(texts.get("legend_states", "")))
	if not MapLayout.legend_chests(_info_list()).is_empty():
		note.append(String(texts.get("legend_chest", "")))
	legend_note.text = "  ".join(PackedStringArray(Array(note).filter(func(t: String) -> bool: return t != "")))


func _info_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in (_data.get("nodes", []) as Array):
		out.append(entry)
	return out


# --- focus and input --------------------------------------------------------------------------------

## Explicit neighbours among the focusable nodes (see MapLayout.neighbors), so an arrow key never jumps to a dimmed node or the legend.
func _wire_focus() -> void:
	var focusable: Array[int] = []
	for id: int in canvas.buttons().keys():
		if canvas.button_for(id).focus_mode == Control.FOCUS_ALL:
			focusable.append(id)
	var links: Dictionary = MapLayout.neighbors(_info_list(), focusable)
	for id: int in links.keys():
		var button: MapNodeButton = canvas.button_for(id)
		var around: Dictionary = links[id]
		button.focus_neighbor_top = _path_to(button, int(around["up"]), button)
		button.focus_neighbor_bottom = _path_to(button, int(around["down"]), button)
		button.focus_neighbor_left = _path_to(button, int(around["left"]), button)
		button.focus_neighbor_right = _path_to(button, int(around["right"]), button)
		button.focus_next = button.focus_neighbor_bottom
		button.focus_previous = button.focus_neighbor_top
	back_button.focus_neighbor_top = back_button.get_path_to(back_button)
	if _mode == Mode.VIEW and not focusable.is_empty():
		back_button.focus_neighbor_bottom = back_button.get_path_to(canvas.button_for(focusable[0]))
		back_button.focus_neighbor_left = back_button.get_path_to(back_button)
		back_button.focus_neighbor_right = back_button.get_path_to(back_button)


## A node path to the button of `target_id`, or to `fallback` itself when there is none (the key then stays put).
func _path_to(from: Control, target_id: int, fallback: Control) -> NodePath:
	var target: Control = canvas.button_for(target_id) if target_id >= 0 else null
	return from.get_path_to(target if target != null else fallback)


## The node id the focus starts on: in PICK the default (least surprising reachable node); in VIEW the Back button.
func default_focus_id() -> int:
	if _mode == Mode.VIEW:
		return -1
	return MapLayout.default_focus(_info_list(), UiConfig.map_screen()["default_focus_order"])


func _focus_start() -> void:
	if _mode == Mode.VIEW:
		back_button.grab_focus()
		_refresh_hover()
		return
	var id: int = default_focus_id()
	if id >= 0:
		_last_focus = id
		canvas.button_for(id).grab_focus()
	_refresh_hover()


## The node id with the keyboard focus, or -1.
func focused_node_id() -> int:
	for id: int in canvas.buttons().keys():
		if canvas.button_for(id).has_focus():
			return id
	return -1


func _on_node_pressed(node_id: int) -> void:
	if _mode != Mode.PICK or not is_armed():
		return
	var info: Dictionary = _info_of(node_id)
	if info.is_empty() or not bool(info.get("reachable", false)):
		return
	if _controller == null:
		node_chosen.emit(node_id)
		return
	var result: Dictionary = _controller.pick_node(node_id)
	if not bool(result.get("ok", false)):
		return
	_pick_pending = false
	if _mode == Mode.PICK:
		_hide_now()
	node_chosen.emit(node_id)


func _info_of(node_id: int) -> Dictionary:
	for info: Dictionary in _info_list():
		if int(info["id"]) == node_id:
			return info
	return {}


func _on_node_hovered(node_id: int) -> void:
	_hovered = node_id
	_refresh_hover()


func _on_node_unhovered(node_id: int) -> void:
	if _hovered == node_id:
		_hovered = -1
	_refresh_hover()


func _on_node_focused(node_id: int) -> void:
	_last_focus = node_id
	_refresh_hover()


## The node whose text shows: the one under the mouse, else the one with the focus.
func hover_target() -> int:
	return _hovered if _hovered >= 0 else focused_node_id()


func _refresh_hover() -> void:
	hover_label.text = hover_text(hover_target())


## "Room 5  -  Elite: a relic, 30-40 gold" plus a note for the current, taken or unreachable nodes. Empty when no node is aimed at.
func hover_text(node_id: int) -> String:
	if node_id < 0:
		return ""
	var info: Dictionary = _info_of(node_id)
	if info.is_empty():
		return ""
	var texts: Dictionary = _texts()
	var text: String = String(texts.get("room_format", "%d %s")) % [int(info["room"]), String(info.get("hover", ""))]
	match MapLayout.node_state(info):
		MapLayout.STATE_CURRENT:
			text += "  " + String(texts.get("current_note", ""))
		MapLayout.STATE_TAKEN:
			text += "  " + String(texts.get("taken_note", ""))
		MapLayout.STATE_FUTURE:
			text += "  " + String(texts.get("future_note", ""))
	return text


func _input(event: InputEvent) -> void:
	if _mode != Mode.VIEW:
		return
	if event.is_action_pressed(&"pause", false) or event.is_action_pressed(&"ui_cancel", false):
		close_view()
		get_viewport().set_input_as_handled()


## The node buttons look a little dim until the arm delay has passed, so a press that does nothing is not a mystery.
func _dim_until_armed(delay: float) -> void:
	_arm_generation += 1
	var generation: int = _arm_generation
	canvas.modulate.a = 0.55 if delay > 0.0 else 1.0
	if delay <= 0.0:
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	if generation == _arm_generation and canvas != null:
		canvas.modulate.a = 1.0
