class_name ActScreen
extends CanvasLayer
## The act transition screen (MAP3 ux): "Act 2", one line of where the run stands (HP, gold, relics), a dry line, and a Continue button.
## It opens on RunController.act_started, which fires in the same call as the next act's map pick, so the map screen holds its pick back while this
## screen is up (MapScreen asks `is_open`) and opens it on `closed`.
##
## The room behind is not paused (the fight is over, the player is alive), so, like the map pick, the keys that belong to the fight must not
## reach it: the slot keys, the swaps and Space are swallowed, and Enter (or a click on Continue) is the only way out. Presses are ignored for
## `run_ui.prompt_option_arm_delay` seconds after opening, so the Enter that closed the mini-boss's card offer cannot also close this.
## Words: data/run.json `ui.act` (title and summary come from RunController.act_summary); sizes and colours reuse the run prompt's (ui.json run_ui).
## Layer 12: above the map pick (11) and the gold badge (10), below the pause screen (20).

## The screen closed (Continue). MapScreen opens its held pick on this.
signal closed()

var root: Control = null
var backdrop: ColorRect = null
var panel: PanelContainer = null
var column: VBoxContainer = null
var title_label: Label = null
var line_label: Label = null
var heal_label: Label = null
var flavor_label: Label = null
var button: Button = null
var hint_label: Label = null

var _summary: Dictionary = {}
var _armed_at_msec: int = 0
var _arm_generation: int = 0
var _controller: RunController = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	visible = false
	_build()
	get_viewport().size_changed.connect(_apply_style)
	_controller = get_parent().get_node_or_null("RunController") as RunController
	if _controller != null:
		_controller.act_started.connect(_on_act_started)


func is_open() -> bool:
	return visible


## What the screen shows now: the act summary as given ({} when closed).
func summary() -> Dictionary:
	return _summary


func is_armed() -> bool:
	return Time.get_ticks_msec() >= _armed_at_msec


## Test hook: presses are accepted from now on.
func disarm() -> void:
	_armed_at_msec = 0


func _on_act_started(_act: int, summary_in: Dictionary) -> void:
	show_act(summary_in)


## Opens the screen for an act summary (RunController.act_summary: title, line, ...).
func show_act(summary_in: Dictionary) -> void:
	_summary = summary_in
	var texts: Dictionary = RunConfig.ui().get("act", {})
	title_label.text = String(summary_in.get("title", ""))
	line_label.text = ActText.summary_line(summary_in)
	heal_label.text = ActText.heal_line(summary_in)
	heal_label.visible = heal_label.text != ""
	flavor_label.text = String(texts.get("flavor", ""))
	flavor_label.visible = flavor_label.text != ""
	button.text = String(texts.get("button", "Continue"))
	hint_label.text = String(texts.get("hint", ""))
	_apply_style()
	visible = true
	var delay: float = float(UiConfig.run_ui().get("prompt_option_arm_delay", 0.4))
	_armed_at_msec = Time.get_ticks_msec() + roundi(delay * 1000.0)
	_dim_until_armed(delay)
	button.grab_focus()


## Closes the screen (Continue). Ignored before the arm delay has passed. True when it closed.
func dismiss() -> bool:
	if not visible or not is_armed():
		return false
	visible = false
	_summary = {}
	_arm_generation += 1
	closed.emit()
	return true


func _input(event: InputEvent) -> void:
	if not visible or GamePause.is_paused():
		return  # the pause screen has its own keys; this screen is still here when it closes
	var key := event as InputEventKey
	if key == null:
		return
	var slot_action: bool = RunPromptScreen.swallows_slot_action(key)
	if not key.pressed:
		if slot_action or key.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()  # a key held as the screen opened must not cast on release
		return
	if slot_action or key.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()  # never reaches the map pick under this screen
		if not key.echo:
			dismiss()


func _on_pressed() -> void:
	dismiss()


# ---- building ----

func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # swallows clicks so the world never sees them
	add_child(root)
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	title_label = _make_label("Title")
	line_label = _make_label("Line")
	heal_label = _make_label("Heal")
	flavor_label = _make_label("Flavor")
	column.add_child(title_label)
	column.add_child(line_label)
	column.add_child(heal_label)
	column.add_child(flavor_label)
	button = Button.new()
	button.name = "Continue"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_pressed)
	column.add_child(button)
	hint_label = _make_label("Hint")
	column.add_child(hint_label)
	_apply_style()


func _make_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _apply_style() -> void:
	if root == null:
		return
	var cfg := UiConfig.run_ui()
	var s: float = GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(cfg["reference_height"]))
	backdrop.color = Color.html(String(cfg["prompt_backdrop_color"]))
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(cfg["prompt_panel_color"]))
	style.border_color = Color.html(String(cfg["prompt_panel_border_color"]))
	style.set_border_width_all(maxi(roundi(2.0 * s), 1))
	style.set_corner_radius_all(roundi(8.0 * s))
	style.set_content_margin_all(float(cfg["prompt_panel_padding"]) * 1.4 * s)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = float(cfg["prompt_panel_min_width"]) * s
	column.add_theme_constant_override("separation", roundi(14.0 * s))
	var text_color := Color.html(String(cfg["prompt_text_color"]))
	title_label.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_title_font_size"]) * 1.2 * s))
	title_label.add_theme_color_override("font_color", Color.html(String(cfg["prompt_title_color"])))
	line_label.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_subtitle_font_size"]) * 1.1 * s))
	# Low HP reads red (and says "Low HP" in words, ActText.summary_line).
	var low: bool = ActText.is_low_hp(_summary)
	line_label.add_theme_color_override("font_color", Color.html(String(RunConfig.ui().get("act", {}).get("low_hp_color", "#ff6b6b"))) if low else text_color)
	heal_label.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_subtitle_font_size"]) * s))
	heal_label.add_theme_color_override("font_color", text_color)
	flavor_label.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_subtitle_font_size"]) * s))
	flavor_label.add_theme_color_override("font_color", text_color.darkened(0.15))
	hint_label.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_subtitle_font_size"]) * 0.85 * s))
	hint_label.add_theme_color_override("font_color", text_color.darkened(0.15))
	var min_size: Array = cfg["prompt_button_min_size"]
	button.custom_minimum_size = Vector2(float(min_size[0]), float(min_size[1])) * s
	button.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_button_font_size"]) * s))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color.html("#1c1218")
		box.border_color = Color.html(String(cfg["option_focus_color"])) if state == "focus" else Color.html(String(cfg["prompt_panel_border_color"]))
		box.set_border_width_all(maxi(roundi((4.0 if state == "focus" else 2.0) * s), 1))
		box.set_corner_radius_all(roundi(6.0 * s))
		box.set_content_margin_all(8.0 * s)
		button.add_theme_stylebox_override(state, box)


## The button looks a little dim until the arm delay has passed, so a press that does nothing is not a mystery.
func _dim_until_armed(delay: float) -> void:
	_arm_generation += 1
	var generation: int = _arm_generation
	button.modulate.a = 0.55 if delay > 0.0 else 1.0
	if delay <= 0.0:
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	if generation == _arm_generation and button != null:
		button.modulate.a = 1.0
