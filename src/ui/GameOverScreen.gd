extends CanvasLayer
class_name GameOverScreen
## Game Over overlay. Hidden until Main.game_over_ready; draws above the HUD
## (layer 10) and its full-screen root swallows mouse input so clicks never
## reach the world. Text and sizes come from data/ui.json `game_over`.

## Emitted when "Try again" is activated, just before Main.restart_arena().
signal retry_requested()

@onready var root: Control = $Root
@onready var backdrop: ColorRect = $Root/Backdrop
@onready var title_label: Label = $Root/Center/Column/Title
@onready var line_label: Label = $Root/Center/Column/Line
@onready var try_again: Button = $Root/Center/Column/TryAgain
@onready var hint_label: Label = $Root/Center/Column/Hint

var _main: Node = null


func _ready() -> void:
	visible = false
	_apply_config()
	try_again.pressed.connect(_on_try_again_pressed)
	get_viewport().size_changed.connect(_apply_config)
	if _main == null:
		# Main owns this screen, so its parent is the Main to bind to (works in a SubViewport and while a scene
		# swap is under way, where current_scene is null or stale). WorldRef covers a screen added elsewhere.
		var host: Node = get_parent()
		bind(host if host != null and host.has_signal("game_over_ready") else WorldRef.get_world(get_tree()))
	elif _already_over():
		show_screen()


## Connects to a Main-like node (needs `game_over_ready`, `is_game_over()`,
## `restart_arena()`). Safe to call with null or an unrelated node.
func bind(main: Node) -> void:
	if main == null or not main.has_signal("game_over_ready"):
		return
	_main = main
	if not main.is_connected("game_over_ready", show_screen):
		main.connect("game_over_ready", show_screen)
	if is_node_ready() and _already_over():
		show_screen()


func _already_over() -> bool:
	return _main != null and _main.has_method("is_game_over") and bool(_main.call("is_game_over"))


func show_screen() -> void:
	if not is_node_ready():
		return
	line_label.text = String(UiConfig.game_over()["line"]) + run_line()
	visible = true
	try_again.grab_focus()


## In a run: a newline and "Reached room X of Y." (text from data/run.json ui.lose.run_line). Empty in the endless arena.
func run_line() -> String:
	var controller: Node = _main.get_node_or_null("RunController") if _main != null else null
	if controller == null or not controller.has_method("room_number"):
		return ""
	var template: String = String(RunConfig.ui().get("lose", {}).get("run_line", ""))
	if template == "":
		return ""
	return "
" + template % [int(controller.call("room_number")), int(controller.call("room_total"))]


## Pixel scale for a viewport height, relative to the config's reference height.
static func ui_scale(viewport_height: float, reference_height: float) -> float:
	if reference_height <= 0.0 or viewport_height <= 0.0:
		return 1.0
	return viewport_height / reference_height


func _apply_config() -> void:
	var cfg := UiConfig.game_over()
	var s := ui_scale(get_viewport().get_visible_rect().size.y, float(cfg["reference_height"]))
	title_label.text = cfg["title"]
	line_label.text = String(cfg["line"]) + run_line()
	try_again.text = cfg["button"]
	hint_label.text = cfg["hint"]
	_set_font(title_label, int(cfg["title_font_size"]), s)
	_set_font(line_label, int(cfg["line_font_size"]), s)
	_set_font(hint_label, int(cfg["hint_font_size"]), s)
	_set_font(try_again, int(cfg["button_font_size"]), s)
	var min_size: Array = cfg["button_min_size"]
	try_again.custom_minimum_size = Vector2(float(min_size[0]), float(min_size[1])) * s
	backdrop.color = Color.html(cfg["backdrop_color"])
	title_label.add_theme_color_override("font_color", Color.html(cfg["title_color"]))
	line_label.add_theme_color_override("font_color", Color.html(cfg["line_color"]))
	hint_label.add_theme_color_override("font_color", Color.html(cfg["line_color"]))
	(try_again.get_parent() as Control).add_theme_constant_override("separation", roundi(24.0 * s))


func _set_font(control: Control, base_size: int, s: float) -> void:
	control.add_theme_font_size_override("font_size", roundi(float(base_size) * s))


func _on_try_again_pressed() -> void:
	retry_requested.emit()
	if _main != null and _main.has_method("restart_arena"):
		_main.call("restart_arena")
