extends CanvasLayer
class_name RunPromptScreen
## Generic run prompt panel (Milestone 3a): an icon and title, a subtitle, a flavour line, label/value rows, an
## `options_box` and one focused action button. The "Room cleared / Continue" screen and the run-won screen are
## two instances (`kind`). 3b hosts its reward options by filling `options_box` (buttons) and calling
## `show_content` with its own rows; nothing in here knows a card.
##
## Its root swallows mouse input so clicks never reach the world. Styling and sizes come from data/ui.json
## `run_ui` (scaled by viewport height like Game Over), words from data/run.json `ui`.
## It never opens over the pause screen or Game Over: while paused the content is held and shown on resume,
## and once the player is dead or Game Over is up it is dropped.

## "cleared": shown on RunController.room_cleared, button = continue. "win": shown on run_won, button = new run.
@export var kind: String = "cleared"

signal confirmed()

@onready var root: Control = $Root
@onready var backdrop: ColorRect = $Root/Backdrop
@onready var panel: PanelContainer = $Root/Center/Panel
@onready var column: VBoxContainer = $Root/Center/Panel/Column
@onready var icon: RunTypeIcon = $Root/Center/Panel/Column/Header/Icon
@onready var title_label: Label = $Root/Center/Panel/Column/Header/Title
@onready var subtitle_label: Label = $Root/Center/Panel/Column/Subtitle
@onready var line_label: Label = $Root/Center/Panel/Column/Line
@onready var stats: GridContainer = $Root/Center/Panel/Column/Stats
@onready var options_box: VBoxContainer = $Root/Center/Panel/Column/Options
@onready var button: Button = $Root/Center/Panel/Column/Action
@onready var hint_label: Label = $Root/Center/Panel/Column/Hint

var _controller: RunController = null
var _pending: Dictionary = {}


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps the focus restore alive across a pause; nothing here ticks
	_apply_style()
	get_viewport().size_changed.connect(_apply_style)
	button.pressed.connect(_on_pressed)
	GamePause.paused_changed.connect(_on_pause_changed)
	_controller = get_parent().get_node_or_null("RunController") as RunController
	if _controller == null:
		return
	if kind == "win":
		_controller.run_won.connect(_show_win)
	else:
		_controller.room_cleared.connect(_show_cleared)


func _exit_tree() -> void:
	if GamePause.paused_changed.is_connected(_on_pause_changed):
		GamePause.paused_changed.disconnect(_on_pause_changed)


func _show_cleared(summary: Dictionary) -> void:
	var text: Dictionary = RunConfig.ui()["room_cleared"]
	var room_type: String = String(summary.get("type", ""))
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	var healed: float = float(summary.get("healed", 0.0))
	show_content({
		"title": String(text["title"]),
		"subtitle": "%s  -  %s" % [_controller.room_label(), _controller.room_type_name(room_type)],
		"line": (String(text["rest_line"]) % roundi(healed)) if healed > 0.0 else "",
		"rows": RunPromptRows.cleared_rows(summary, text),
		"button": String(text["button"]),
		"hint": String(text.get("hint", "")),
		"icon_shape": RunIcons.shape_for(room_type),
		"icon_color": RunIcons.color_for(room_type, UiConfig.run_ui(), tiers),
	})


func _show_win() -> void:
	var text: Dictionary = RunConfig.ui()["win"]
	var state: RunState = _controller.state()
	var history: Array = state.history if state != null else []
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	show_content({
		"title": String(text["title"]),
		"subtitle": "",
		"line": String(text["line"]),
		"rows": RunPromptRows.win_rows(history, _controller.room_total(), _controller.last_summary(), text),
		"button": String(text["button"]),
		"hint": String(text.get("hint", "")),
		"icon_shape": RunIcons.shape_for("boss"),
		"icon_color": RunIcons.color_for("boss", UiConfig.run_ui(), tiers),
	})


## Fills the panel and opens it. `content`: title, subtitle, line, rows [{label, value}], button, hint,
## icon_shape, icon_color (all optional). Held until resume if the game is paused; dropped if the run is over
## for the player (dead or Game Over).
func show_content(content: Dictionary) -> void:
	if _blocked_by_game_over():
		_pending = {}
		return
	if GamePause.is_paused():
		_pending = content
		return
	_pending = {}
	_fill(content)
	visible = true
	button.grab_focus()


func is_open() -> bool:
	return visible


func _blocked_by_game_over() -> bool:
	var main := get_parent() as Main
	if main == null:
		return false
	return main.is_game_over() or (main.player != null and main.player.is_dead())


func _on_pause_changed(is_paused: bool) -> void:
	if is_paused:
		return
	if not _pending.is_empty():
		show_content(_pending)
	elif visible:
		button.call_deferred("grab_focus")  # the pause screen took focus; give it back to the button


func _fill(content: Dictionary) -> void:
	title_label.text = String(content.get("title", ""))
	var subtitle: String = String(content.get("subtitle", ""))
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	var line: String = String(content.get("line", ""))
	line_label.text = line
	line_label.visible = line != ""
	button.text = String(content.get("button", ""))
	var hint: String = String(content.get("hint", ""))
	hint_label.text = hint
	hint_label.visible = hint != ""
	var shape: String = String(content.get("icon_shape", ""))
	icon.visible = shape != ""
	if shape != "":
		icon.shape = shape
		icon.color = content.get("icon_color", Color.WHITE)
	for child in stats.get_children():
		stats.remove_child(child)
		child.queue_free()
	var rows: Array = content.get("rows", [])
	for row: Dictionary in rows:
		_add_stat(String(row.get("label", "")), String(row.get("value", "")))


func _add_stat(label_text: String, value_text: String) -> void:
	var cfg := UiConfig.run_ui()
	var s := _scale(cfg)
	var size: int = roundi(float(cfg["prompt_stat_font_size"]) * s)
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", size)
	name_label.add_theme_color_override("font_color", Color.html(String(cfg["prompt_text_color"])))
	var value_label := Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", size)
	value_label.add_theme_color_override("font_color", Color.html(String(cfg["prompt_value_color"])))
	stats.add_child(name_label)
	stats.add_child(value_label)


func _scale(cfg: Dictionary) -> float:
	return GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(cfg["reference_height"]))


func _apply_style() -> void:
	if not is_node_ready():
		return
	var cfg := UiConfig.run_ui()
	var s := _scale(cfg)
	backdrop.color = Color.html(String(cfg["prompt_backdrop_color"]))
	var pad: float = float(cfg["prompt_panel_padding"]) * s
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(cfg["prompt_panel_color"]))
	style.border_color = Color.html(String(cfg["prompt_panel_border_color"]))
	style.set_border_width_all(maxi(roundi(2.0 * s), 1))
	style.set_corner_radius_all(roundi(8.0 * s))
	style.set_content_margin_all(pad)
	panel.add_theme_stylebox_override("panel", style)
	var width: float = float(cfg["prompt_panel_min_width"]) * s
	panel.custom_minimum_size = Vector2(width, 0.0)
	line_label.custom_minimum_size = Vector2(width - 2.0 * pad, 0.0)
	column.add_theme_constant_override("separation", roundi(16.0 * s))
	stats.add_theme_constant_override("h_separation", roundi(40.0 * s))
	stats.add_theme_constant_override("v_separation", roundi(6.0 * s))
	options_box.add_theme_constant_override("separation", roundi(10.0 * s))
	var icon_px: float = float(cfg["prompt_icon_size"]) * s
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	(icon.get_parent() as HBoxContainer).add_theme_constant_override("separation", roundi(16.0 * s))
	var text_color := Color.html(String(cfg["prompt_text_color"]))
	_font(title_label, "prompt_title_font_size", s, cfg)
	title_label.add_theme_color_override("font_color", Color.html(String(cfg["prompt_title_color"])))
	_font(subtitle_label, "prompt_subtitle_font_size", s, cfg)
	subtitle_label.add_theme_color_override("font_color", text_color)
	_font(line_label, "prompt_subtitle_font_size", s, cfg)
	line_label.add_theme_color_override("font_color", text_color)
	_font(hint_label, "prompt_hint_font_size", s, cfg)
	hint_label.add_theme_color_override("font_color", text_color)
	_font(button, "prompt_button_font_size", s, cfg)
	var min_size: Array = cfg["prompt_button_min_size"]
	button.custom_minimum_size = Vector2(float(min_size[0]), float(min_size[1])) * s
	for child in stats.get_children():
		var label := child as Label
		if label != null:
			label.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_stat_font_size"]) * s))


func _font(control: Control, key: String, s: float, cfg: Dictionary) -> void:
	control.add_theme_font_size_override("font_size", roundi(float(cfg[key]) * s))


func _on_pressed() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()
	if _controller == null:
		return
	if kind == "win":
		(get_parent() as Main).restart_arena()  # a new run with a new seed
	else:
		_controller.continue_to_next_room()
