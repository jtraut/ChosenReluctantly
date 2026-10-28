extends CanvasLayer
class_name SettingsScreen
## The pause / settings screen (Slice 6b). Esc (the `pause` action) pauses the game through
## GamePause and opens this; Esc or Resume closes it. It holds one toggle per setting listed
## in SETTING_KEYS, built from the Settings definitions (labels and options are data, never
## typed here), and every change is saved at once. It darkens the world and swallows mouse
## input. It refuses to open over Game Over (GamePause.pause() says no).
##
## process_mode is ALWAYS (set in the scene) so it keeps taking input under a paused tree.
## Look and text: data/ui.json `settings_screen`.

## Emitted after the screen opens / closes.
signal opened()
signal closed()

## Settings shown, in order. Only enum settings are supported (that is all there is).
const SETTING_KEYS: Array[String] = [Settings.CAST_TRIGGER]

@onready var root: Control = $Root
@onready var backdrop: ColorRect = $Root/Backdrop
@onready var column: VBoxContainer = $Root/Center/Column
@onready var title_label: Label = $Root/Center/Column/Title
@onready var line_label: Label = $Root/Center/Column/Line
@onready var option_label: Label = $Root/Center/Column/Row/OptionLabel
@onready var options_box: HBoxContainer = $Root/Center/Column/Row/Options
@onready var resume_button: Button = $Root/Center/Column/Resume
@onready var hint_label: Label = $Root/Center/Column/Hint

## option value -> its toggle button, for the one setting on screen.
var option_buttons: Dictionary = {}
var _setting_key: String = SETTING_KEYS[0]
var _group := ButtonGroup.new()
## Shown under the hint only after a failed Settings.save(); hidden otherwise. Built in code so the
## scene file stays as it was. Text and colour: data/ui.json `settings_screen` save_failed*.
var save_note_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_options()
	_build_save_note()
	_apply_config()
	resume_button.pressed.connect(close)
	Settings.changed.connect(_on_setting_changed)
	get_viewport().size_changed.connect(_apply_config)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_setting_changed):
		Settings.changed.disconnect(_on_setting_changed)


func is_open() -> bool:
	return visible


## Pauses and shows the screen. False (and nothing changes) when it is already open or the
## pause is refused (Game Over is up).
func open() -> bool:
	if visible or not GamePause.pause():
		return false
	visible = true
	save_note_label.visible = false
	_sync_from_settings()
	resume_button.grab_focus()
	opened.emit()
	return true


## Hides the screen and resumes. False if it was not open.
func close() -> bool:
	if not visible:
		return false
	visible = false
	GamePause.resume()
	closed.emit()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause", false):
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func _build_options() -> void:
	var definition := Settings.get_definition(_setting_key)
	option_label.text = String(definition.get("label", _setting_key)) + ":"
	var labels: Dictionary = definition.get("option_labels", {})
	var previous: Button = null
	for option: Variant in definition.get("options", []):
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = _group
		button.focus_mode = Control.FOCUS_ALL
		button.set_meta(&"label", String(labels.get(option, option)))
		button.toggled.connect(_on_option_toggled.bind(option))
		options_box.add_child(button)
		option_buttons[option] = button
		if previous != null:
			previous.focus_neighbor_right = previous.get_path_to(button)
			button.focus_neighbor_left = button.get_path_to(previous)
		previous = button
	_sync_from_settings()


## Marks the button of the stored value. No signals, so showing the screen never saves.
func _sync_from_settings() -> void:
	var cfg := UiConfig.settings_screen()
	var current: Variant = Settings.get_value(_setting_key)
	for option: Variant in option_buttons:
		var button: Button = option_buttons[option]
		var selected: bool = option == current
		button.set_pressed_no_signal(selected)
		var marker: String = cfg["selected_marker"] if selected else cfg["unselected_marker"]
		button.text = marker + String(button.get_meta(&"label"))


func _on_option_toggled(pressed: bool, option: Variant) -> void:
	if not pressed:
		return
	if Settings.set_value(_setting_key, option):
		var saved := Settings.save()
		save_note_label.visible = not saved
		if not saved:
			# The choice holds for this session only; say so, loudly in the log and on the screen.
			push_error("Settings: could not save '%s' to the settings file; the choice will not survive a restart" % _setting_key)
	_sync_from_settings()


func _build_save_note() -> void:
	save_note_label = Label.new()
	save_note_label.name = "SaveNote"
	save_note_label.visible = false
	save_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(save_note_label)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == _setting_key:
		_sync_from_settings()


func _apply_config() -> void:
	var cfg := UiConfig.settings_screen()
	var s := GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(cfg["reference_height"]))
	title_label.text = cfg["title"]
	line_label.text = cfg["line"]
	resume_button.text = cfg["resume"]
	hint_label.text = cfg["hint"]
	save_note_label.text = cfg["save_failed"]
	save_note_label.add_theme_color_override("font_color", Color.html(cfg["save_failed_color"]))
	_set_font(save_note_label, int(cfg["hint_font_size"]), s)
	for label: Label in [title_label, line_label, option_label, hint_label]:
		label.add_theme_color_override("font_color", Color.html(cfg["line_color"]))
	title_label.add_theme_color_override("font_color", Color.html(cfg["title_color"]))
	_set_font(title_label, int(cfg["title_font_size"]), s)
	_set_font(line_label, int(cfg["line_font_size"]), s)
	_set_font(option_label, int(cfg["label_font_size"]), s)
	_set_font(hint_label, int(cfg["hint_font_size"]), s)
	_set_font(resume_button, int(cfg["button_font_size"]), s)
	var min_size: Array = cfg["button_min_size"]
	resume_button.custom_minimum_size = Vector2(float(min_size[0]), float(min_size[1])) * s
	var option_min: Array = cfg["option_min_size"]
	for button: Button in option_buttons.values():
		_set_font(button, int(cfg["option_font_size"]), s)
		button.custom_minimum_size = Vector2(float(option_min[0]), float(option_min[1])) * s
	_style_options(cfg, s)
	backdrop.color = Color.html(cfg["backdrop_color"])
	column.add_theme_constant_override("separation", roundi(24.0 * s))


## Every option gets a visible frame (selected ones a lighter fill as well as the (x) marker), so
## the choices read as buttons and the selection never depends on colour alone.
func _style_options(cfg: Dictionary, s: float) -> void:
	var border_width: int = maxi(1, roundi(2.0 * s))
	for button: Button in option_buttons.values():
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var box := StyleBoxFlat.new()
			var selected: bool = state == "pressed" or state == "hover_pressed"
			box.bg_color = Color.html(cfg["option_selected_bg"] if selected else cfg["option_bg"])
			box.border_color = Color.html(cfg["option_border"])
			var widths: int = border_width * 2 if (state == "focus" or selected) else border_width
			box.set_border_width_all(widths)
			if state == "focus":
				box.draw_center = false
			box.set_content_margin_all(8.0 * s)
			button.add_theme_stylebox_override(state, box)


func _set_font(control: Control, base_size: int, s: float) -> void:
	control.add_theme_font_size_override("font_size", roundi(float(base_size) * s))
