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
## BD2: the relics of the run in progress (name, rule, flavour), and the ones given up. Built in code, only in a run.
var relic_section: VBoxContainer = null
var relic_header: Label = null
var relic_scroll: ScrollContainer = null
var relic_list: VBoxContainer = null
var relic_given_up_label: Label = null
## MAP1: a solid plate behind the panel in a run (the room stays visible around it, never through it), the row holding Resume and Map, and the
## Map button that opens the view-only map.
var plate: PanelContainer = null
var buttons_row: HBoxContainer = null
var map_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_options()
	_build_save_note()
	_build_relic_section()
	_build_plate_and_buttons()
	_apply_config()
	resume_button.pressed.connect(close)
	map_button.pressed.connect(open_map)
	Settings.changed.connect(_on_setting_changed)
	get_viewport().size_changed.connect(_apply_config)
	InputBindings.bindings_changed.connect(_apply_config)


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
	refresh_relics()
	map_button.visible = _map_available()
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


## The run's map screen (a sibling in a map run), or null.
func _map_screen() -> MapScreen:
	var host: Node = get_parent()
	return host.get_node_or_null("MapScreen") as MapScreen if host != null else null


func _map_available() -> bool:
	var screen: MapScreen = _map_screen()
	return screen != null and screen.can_view()


## Opens the view-only map over this screen. Closing it (Esc, Enter or Back) comes back here with the focus on the Map button.
func open_map() -> bool:
	var screen: MapScreen = _map_screen()
	if screen == null or not visible or not screen.open_view():
		return false
	if not screen.view_closed.is_connected(_on_map_closed):
		screen.view_closed.connect(_on_map_closed, CONNECT_ONE_SHOT)
	return true


func _on_map_closed() -> void:
	if visible:
		map_button.grab_focus()


func _build_plate_and_buttons() -> void:
	var center: Control = $Root/Center
	plate = PanelContainer.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(plate)
	column.reparent(plate, false)
	buttons_row = HBoxContainer.new()
	buttons_row.name = "Buttons"
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(buttons_row)
	column.move_child(buttons_row, resume_button.get_index())
	resume_button.reparent(buttons_row, false)
	map_button = Button.new()
	map_button.name = "Map"
	map_button.visible = false
	buttons_row.add_child(map_button)
	resume_button.focus_neighbor_right = resume_button.get_path_to(map_button)
	map_button.focus_neighbor_left = map_button.get_path_to(resume_button)
	map_button.focus_neighbor_right = map_button.get_path_to(map_button)
	resume_button.focus_neighbor_left = resume_button.get_path_to(resume_button)


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


func _build_relic_section() -> void:
	relic_section = VBoxContainer.new()
	relic_section.name = "RelicSection"
	relic_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_section.visible = false
	column.add_child(relic_section)
	column.move_child(relic_section, resume_button.get_index())
	relic_header = Label.new()
	relic_header.name = "Header"
	relic_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_section.add_child(relic_header)
	relic_scroll = ScrollContainer.new()
	relic_scroll.name = "Scroll"
	relic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	relic_scroll.follow_focus = true
	relic_scroll.focus_mode = Control.FOCUS_ALL  # arrow keys scroll a long list once it has focus
	relic_scroll.gui_input.connect(_on_relic_scroll_input)
	relic_section.add_child(relic_scroll)
	relic_list = VBoxContainer.new()
	relic_list.name = "List"
	relic_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_scroll.add_child(relic_list)
	relic_given_up_label = Label.new()
	relic_given_up_label.name = "GivenUp"
	relic_given_up_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relic_given_up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_section.add_child(relic_given_up_label)


## The run in progress, or null (the arena and the class pick have none).
func _run() -> RunController:
	var host: Node = get_parent()
	return host.get_node_or_null("RunController") as RunController if host != null else null


## Rebuilds the relic list from the run: one entry per owned relic (name and tier, rule, flavour), the count, and a line for relics
## given up. Hidden outside a run. Texts: data/run.json ui.relic; look: data/ui.json settings_screen relic_*.
func refresh_relics() -> void:
	var controller: RunController = _run()
	relic_section.visible = controller != null
	if controller == null:
		column.add_theme_constant_override("separation", roundi(24.0 * GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(UiConfig.settings_screen()["reference_height"]))))
		_style_plate(UiConfig.settings_screen(), 1.0)
		return
	var cfg := UiConfig.settings_screen()
	var s := GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(cfg["reference_height"]))
	column.add_theme_constant_override("separation", roundi(float(cfg["run_separation"]) * s))  # tighter in a run: the relic list needs the height
	_style_plate(cfg, s)
	var texts: Dictionary = RunConfig.ui().get("relic", {})
	var owned: Array[Dictionary] = controller.owned_relics()
	var swap: Dictionary = controller.relic_swap_state()
	for child in relic_list.get_children():
		relic_list.remove_child(child)
		child.queue_free()
	var head_text: String = String(texts.get("owned_title", ""))
	if not owned.is_empty():
		head_text += "  (" + String(texts.get("pause_count", "%d of %d")) % [owned.size(), int(swap["max_owned"])] + ")"
	relic_header.text = head_text
	var line_color := Color.html(String(cfg["line_color"]))
	var rule_px: int = roundi(float(cfg["relic_rule_font_size"]) * s)
	relic_list.add_theme_constant_override("separation", roundi(6.0 * s))
	if owned.is_empty():
		relic_list.add_child(_relic_text(String(texts.get("pause_empty", texts.get("none_owned", ""))), rule_px, line_color, true))
	var width: float = float(cfg["relic_list_width"]) * s
	for shown: Dictionary in owned:
		relic_list.add_child(_relic_entry(shown, cfg, s, true, width))
	# The flavour lines go first when the list does not fit above the slots: rules matter, jokes can wait (they stay on the offer screens).
	if not owned.is_empty() and relic_list.get_combined_minimum_size().y > maxf(_relic_room_px(cfg, s), float(cfg["relic_list_min_height"]) * s):
		for child in relic_list.get_children():
			relic_list.remove_child(child)
			child.queue_free()
		for shown: Dictionary in owned:
			relic_list.add_child(_relic_entry(shown, cfg, s, false, width))
	var given_up: Array[Dictionary] = controller.given_up_relics()
	relic_given_up_label.visible = not given_up.is_empty()
	if not given_up.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for shown: Dictionary in given_up:
			names.append(String(shown["name"]))
		relic_given_up_label.text = "%s: %s" % [String(texts.get("pause_given_up", "")), ", ".join(names)]
	_style_relic_section(cfg, s)
	relic_section.update_minimum_size()
	_keep_clear_of_slots()


## The height the relic list may take: what is left above the slot bar after the other rows of the panel and the plate's padding.
func _relic_room_px(cfg: Dictionary, s: float) -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bar: Rect2 = HudLayout.slot_bar_rect(vp, UiConfig.hud(), CardSlotController.SLOT_TYPE_ORDER.size())
	relic_scroll.custom_minimum_size.y = 0.0
	var others: float = column.get_combined_minimum_size().y
	return bar.position.y - float(cfg["plate_margin"]) * s - 2.0 * float(cfg["plate_padding"]) * s - 2.0 * float(cfg["option_border_width"]) * s - others


## In a run the taller panel (with the relic list) is centred above the slot bar instead of the whole window, so Resume never sits on
## the five slots. Outside a run the layout is as it was.
func _keep_clear_of_slots() -> void:
	var center: Control = $Root/Center
	if not relic_section.visible:
		center.offset_bottom = 0.0
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bar: Rect2 = HudLayout.slot_bar_rect(vp, UiConfig.hud(), CardSlotController.SLOT_TYPE_ORDER.size())
	center.offset_bottom = -(vp.y - bar.position.y)


## Up and Down scroll the focused relic list a few lines at a time. At either end the key is left alone, so focus moves on
## (Down from the end of the list reaches Resume). Mouse wheel scrolling is the ScrollContainer's own.
func _on_relic_scroll_input(event: InputEvent) -> void:
	var up: bool = event.is_action_pressed(&"ui_up", true)
	var down: bool = event.is_action_pressed(&"ui_down", true)
	if not (up or down):
		return
	var step: int = roundi(float(UiConfig.settings_screen()["relic_scroll_step"]) * GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(UiConfig.settings_screen()["reference_height"])))
	var limit: int = int(relic_scroll.get_v_scroll_bar().max_value - relic_scroll.get_v_scroll_bar().page)
	var target: int = clampi(relic_scroll.scroll_vertical + (step if down else -step), 0, maxi(limit, 0))
	if target == relic_scroll.scroll_vertical:
		return
	relic_scroll.scroll_vertical = target
	relic_scroll.accept_event()


func _relic_text(text: String, px: int, color: Color, wrap: bool, min_width: float = 10.0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = min_width
	return label


## One owned relic: a bar in its pool colour, "Name (Tier 1, Fire)", the rule, the flavour line.
func _relic_entry(shown: Dictionary, cfg: Dictionary, s: float, with_flavor: bool = true, list_width: float = 0.0) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", roundi(8.0 * s))
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = PoolDatabase.frame_color_for_pool(String(shown.get("pool", "")))
	bar.custom_minimum_size = Vector2(maxf(4.0 * s, 3.0), 0.0)
	row.add_child(bar)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	var name_px: int = roundi(float(cfg["relic_name_font_size"]) * s)
	var rule_px: int = roundi(float(cfg["relic_rule_font_size"]) * s)
	var line_color := Color.html(String(cfg["line_color"]))
	var title: String = "%s  (%s, %s)" % [String(shown.get("name", "")), String(shown.get("tier_name", "")), String(shown.get("pool_name", ""))]
	body.add_child(_relic_text(title, name_px, Color.html("#ffffff"), false))
	var text_width: float = maxf(list_width - maxf(4.0 * s, 3.0) - 8.0 * s, 10.0)  # the bar and the gap are beside the text
	body.add_child(_relic_text(String(shown.get("rule_text", "")), rule_px, line_color, true, text_width))
	if with_flavor:
		body.add_child(_relic_text(String(shown.get("flavor", "")), rule_px, Color.html(String(cfg["relic_flavor_color"])), true, text_width))
	return row


func _style_relic_section(cfg: Dictionary, s: float) -> void:
	var width: float = float(cfg["relic_list_width"]) * s
	relic_header.add_theme_font_size_override("font_size", roundi(float(cfg["relic_header_font_size"]) * s))
	relic_header.add_theme_color_override("font_color", Color.html(String(cfg["title_color"])))
	relic_given_up_label.add_theme_font_size_override("font_size", roundi(float(cfg["relic_rule_font_size"]) * s))
	relic_given_up_label.add_theme_color_override("font_color", Color.html(String(cfg["relic_flavor_color"])))
	relic_given_up_label.custom_minimum_size.x = width
	relic_list.custom_minimum_size.x = width
	# The list is as tall as its entries, up to the data ceiling and up to the room left above the slot bar; beyond that it scrolls. (BD2 playtest:
	# a fixed 150 px showed 2 of 3 relics in a short box while there was room for more.)
	var wanted: float = relic_list.get_combined_minimum_size().y
	var height: float = minf(wanted, float(cfg["relic_list_max_height"]) * s)
	height = minf(height, maxf(_relic_room_px(cfg, s), float(cfg["relic_list_min_height"]) * s))
	relic_scroll.custom_minimum_size = Vector2(width + 14.0 * s, height)
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color.html(String(cfg["option_border"]))
	box.set_border_width_all(maxi(1, roundi(2.0 * s)))
	relic_scroll.add_theme_stylebox_override("focus", box)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == _setting_key:
		_sync_from_settings()


func _apply_config() -> void:
	var cfg := UiConfig.settings_screen()
	var s := GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(cfg["reference_height"]))
	title_label.text = cfg["title"]
	line_label.text = cfg["line"]
	resume_button.text = cfg["resume"]
	hint_label.text = String(cfg["hint"]) % InputLabels.for_action(&"pause")
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
	map_button.text = String(RunConfig.ui().get("map", {}).get("button_label", "Map"))
	_set_font(map_button, int(cfg["button_font_size"]), s)
	map_button.custom_minimum_size = Vector2(float(min_size[0]) * 0.55, float(min_size[1])) * s
	buttons_row.add_theme_constant_override("separation", roundi(16.0 * s))
	_frame_button(map_button, cfg, s)
	_style_plate(cfg, s)
	var option_min: Array = cfg["option_min_size"]
	for button: Button in option_buttons.values():
		_set_font(button, int(cfg["option_font_size"]), s)
		button.custom_minimum_size = Vector2(float(option_min[0]), float(option_min[1])) * s
	_style_options(cfg, s)
	if relic_section != null and relic_section.visible:
		refresh_relics()
	backdrop.color = Color.html(cfg["backdrop_color"])
	if relic_section == null or not relic_section.visible:
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


## A framed button like the option toggles, so Map reads as a button next to Resume (a heavier frame while focused).
func _frame_button(button: Button, cfg: Dictionary, s: float) -> void:
	var border_width: int = maxi(1, roundi(2.0 * s))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color.html(cfg["option_bg"])
		box.border_color = Color.html(cfg["option_border"])
		box.set_border_width_all(border_width * 2 if state == "focus" else border_width)
		if state == "focus":
			box.draw_center = false
		box.set_content_margin_all(8.0 * s)
		button.add_theme_stylebox_override(state, box)


## A run's pause panel sits on a solid plate so the room does not show through the relic list; outside a run there is no plate.
func _style_plate(cfg: Dictionary, s: float) -> void:
	if plate == null:
		return
	var in_run: bool = relic_section != null and relic_section.visible
	var box := StyleBoxFlat.new()
	if in_run:
		box.bg_color = Color.html(String(cfg["plate_color"]))
		box.border_color = Color.html(String(cfg["option_border"]))
		box.set_border_width_all(maxi(1, roundi(2.0 * s)))
		box.set_corner_radius_all(roundi(8.0 * s))
		box.set_content_margin_all(float(cfg["plate_padding"]) * s)
	else:
		box.draw_center = false
	plate.add_theme_stylebox_override("panel", box)


func _set_font(control: Control, base_size: int, s: float) -> void:
	control.add_theme_font_size_override("font_size", roundi(float(base_size) * s))
