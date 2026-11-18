class_name StartScreen
extends CanvasLayer
## The start screen (3d sitting D). From run 2 on, before a run: start with the preset deck, a saved loadout, or edit or create a loadout. It is a list of rows
## (`rows_for`, pure and unit-tested, built from `LoadoutChoices.start_choices`): the preset, each usable loadout (name, card count, plan size, starter relic), each skipped
## loadout (not selectable, with the checker's reason), and "Edit or create a loadout". The last used row is preselected and tagged "Last used", so one Enter starts a run.
## Keyboard (Up and Down, Enter) and mouse (hover moves the highlight, click starts) both work. The highlight is a thick outline plus an arrow, never colour alone.
## It pauses the game through GamePause like the class pick, opens after the class pick resolves (also in the scene a class change rebuilds), and never opens in headless
## runs, scripts, scenarios or any launch with a loadout or debug deck forced. Its one action is `RunController.confirm_start_choice(slot)`. Words are data (run.json ui.start_screen).

signal opened()
## A start choice was confirmed (the slot, LoadoutStore.PRESET for the preset).
signal confirmed(slot: int)

const ROW_PRESET: String = "preset"
const ROW_LOADOUT: String = "loadout"
const ROW_FLAGGED: String = "flagged"
const ROW_EDIT: String = "edit"

## Tests: true/false forces the "real game" part of the decision; null = decide from how the game was launched.
static var enabled_override: Variant = null

var _controller: RunController = null
var _choices: Dictionary = {}
var _armed_at_msec: int = 0
var _paused_here: bool = false
var _confirming: bool = false
var _hidden_hud: CanvasLayer = null
var _editor: LoadoutEditorScreen = null
var _root: Control = null
var _center: CenterContainer = null
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _rows_box: VBoxContainer = null
var _buttons: Array[Button] = []
var _rows: Array[Dictionary] = []
var _scale: float = 1.0


static func reset() -> void:
	enabled_override = null


## Whether the screen should open for this run state: a real interactive game, and `LoadoutSession.start_screen_wanted` (run 2 or later, a fresh run start, nothing forced).
static func should_open(state: RunState) -> bool:
	if enabled_override != null:
		return bool(enabled_override) and LoadoutSession.start_screen_wanted(state)
	if DisplayServer.get_name() == "headless" or not ClassPickScreen.interactive() or (ClassPickScreen.enabled_override != null and not bool(ClassPickScreen.enabled_override)):
		return false  # a capture or tool that turned the class pick off wants no prompt over its shot
	if RunSession.character_forced and LoadoutSession.faked_runs < 0 and not LoadoutSession.profile_path_named:
		return false  # `--class=` skips the class pick and its start screen too, unless the launch asked for run 2 itself (`--runs-finished=`, `--profile-path=`)
	return LoadoutSession.start_screen_wanted(state)


## The rows the screen draws, in order, as plain data (tests, and the drawing code). Each: {kind, slot (PRESET, a loadout slot, or NO_SLOT for rows that start nothing),
## title, detail, selectable, last_used}. `choices` is LoadoutChoices.start_choices; `texts` is run.json ui.start_screen. Flagged rows carry the checker's reason as detail.
## Exactly one selectable row has last_used when `last_used` names it; the edit row is never last used.
static func rows_for(choices: Dictionary, texts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var last_used: int = int(choices.get("last_used", LoadoutStore.PRESET))
	var preset: Dictionary = choices["preset"]
	rows.append({"kind": ROW_PRESET, "slot": LoadoutStore.PRESET, "title": String(preset["name"]), "detail": String(texts.get("deck_cards", "%d cards")) % int(preset["deck_size"]),
			"selectable": true, "last_used": last_used == LoadoutStore.PRESET})
	for loadout: Dictionary in (choices["loadouts"] as Array):
		var parts: PackedStringArray = PackedStringArray([String(texts.get("deck_cards", "%d cards")) % int(loadout["deck_size"])])
		if int(loadout["plan_size"]) > 0:
			parts.append(String(texts.get("plan_cards", "Plan: %d cards")) % int(loadout["plan_size"]))
		if not String(loadout["starter_relic"]).is_empty():
			parts.append(String(texts.get("relic", "Relic: %s")) % String(loadout["starter_relic_name"]))
		var slot: int = int(loadout["slot"])
		rows.append({"kind": ROW_LOADOUT, "slot": slot, "title": String(texts.get("slot_title", "%d. %s")) % [slot + 1, String(loadout["name"])], "detail": ", ".join(parts),
				"selectable": true, "last_used": last_used == slot})
	for skipped: Dictionary in (choices["flagged"] as Array):
		rows.append({"kind": ROW_FLAGGED, "slot": LoadoutArgs.NO_SLOT, "title": String(texts.get("flagged_title", "Loadout %d: can't start")) % (int(skipped["slot"]) + 1),
				"detail": String(skipped["message"]), "selectable": false, "last_used": false})
	rows.append({"kind": ROW_EDIT, "slot": LoadoutArgs.NO_SLOT, "title": String(texts.get("edit_title", "Edit or create a loadout")), "detail": String(texts.get("edit_detail", "")),
			"selectable": true, "last_used": false})
	return rows


## File-level notes to print under the list: every message of the model that is not a skipped-loadout line (those have their own flagged row), such as "loadouts ignored:
## the file version is 2" or a rule problem in data/loadouts.json. Pure.
static func notes_for(choices: Dictionary) -> Array[String]:
	var covered := RegEx.create_from_string("^\\S+ loadout \\d+( '.*')? skipped: ")
	var out: Array[String] = []
	for message: Variant in (choices.get("messages", []) as Array):
		if covered.search(String(message)) == null:
			out.append(String(message))
	return out


func _ready() -> void:
	visible = false
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_open_when_wired.call_deferred()


func _exit_tree() -> void:
	_restore_hud()
	if _paused_here and not _confirming:
		_paused_here = false
		GamePause.resume()


func _open_when_wired() -> void:
	var main := get_parent() as Main
	if main == null or main.run_controller == null:
		queue_free()
		return
	_controller = main.run_controller
	var pick := main.get_node_or_null("ClassPickScreen") as ClassPickScreen
	if pick != null and pick.is_open():
		pick.confirmed.connect(_on_pick_confirmed, CONNECT_ONE_SHOT)  # the start screen follows the class pick
		return
	if should_open(_controller.state()):
		open()


func _on_pick_confirmed(_character_id: String) -> void:
	# A different class rebuilds the run in a fresh scene, which opens its own start screen; only the same class carries on here.
	if _controller == null or RunSession.current != _controller.state():
		return
	_open_after_pick.call_deferred()


func _open_after_pick() -> void:
	if _controller != null and should_open(_controller.state()):
		open()


func open() -> void:
	if _controller == null:
		return
	_confirming = false
	_choices = LoadoutChoices.start_choices(_controller.character_id())
	_rebuild()
	visible = true
	_hide_hud()
	_paused_here = GamePause.pause()
	var delay: float = float(UiConfig.run_ui().get("prompt_option_arm_delay", 0.4))
	_armed_at_msec = Time.get_ticks_msec() + roundi(delay * 1000.0)
	_focus_last_used()
	opened.emit()


func is_open() -> bool:
	return visible


func options_armed() -> bool:
	return Time.get_ticks_msec() >= _armed_at_msec


## Skips the arm delay (tests and scripted input).
func disarm() -> void:
	_armed_at_msec = 0


## The model the screen is showing (LoadoutChoices.start_choices).
func choices() -> Dictionary:
	return _choices


## The rows the screen is showing (`rows_for`).
func rows() -> Array[Dictionary]:
	return _rows


## Confirms a choice: LoadoutStore.PRESET or a usable loadout slot. Ignored before the arm delay and while confirming.
func choose(slot: int) -> void:
	if not visible or _confirming or not options_armed() or _controller == null:
		return
	if not _controller.confirm_start_choice(slot):
		return
	confirmed.emit(slot)
	if slot == LoadoutStore.PRESET:
		close()
	else:
		_confirming = true  # the run is rebuilt as a fresh scene (deferred); stay up and dim until it replaces this one


func close() -> void:
	visible = false
	_restore_hud()
	if _paused_here:
		_paused_here = false
		GamePause.resume()


## Opens the bare editor over this screen. When it closes the choices are rebuilt, so a saved loadout shows at once.
func open_editor() -> void:
	if _editor != null or _controller == null or not options_armed():
		return
	_editor = LoadoutEditorScreen.new()
	_editor.setup(_controller.character_id(), LoadoutSession.store())
	_editor.closed.connect(_on_editor_closed)
	add_child(_editor)


func _on_editor_closed() -> void:
	_editor = null
	_choices = LoadoutChoices.start_choices(_controller.character_id())
	_rebuild()
	_focus_last_used()


func _input(event: InputEvent) -> void:
	if not visible or _editor != null:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and (key.keycode == KEY_SPACE or _confirming):
		get_viewport().set_input_as_handled()  # Space is the Movement card key: it must never start a run


func _hide_hud() -> void:
	var main := get_parent() as Main
	if main == null or main.hud == null or _hidden_hud != null or not main.hud.visible:
		return
	_hidden_hud = main.hud
	_hidden_hud.visible = false


func _restore_hud() -> void:
	if _hidden_hud != null and is_instance_valid(_hidden_hud):
		_hidden_hud.visible = true
	_hidden_hud = null


# ---- building ----

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color.html(String(UiConfig.run_ui()["prompt_backdrop_color"]))
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_center)


func _label(text: String, font_px: int, color: Color, wrap_width: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", color)
	if wrap_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = wrap_width
	return label


func _rebuild() -> void:
	if _panel != null:
		_center.remove_child(_panel)
		_panel.queue_free()
	_buttons.clear()
	var cfg: Dictionary = UiConfig.run_ui()
	var texts: Dictionary = RunConfig.ui().get("start_screen", {})
	var viewport_h: float = get_viewport().get_visible_rect().size.y
	_scale = GameOverScreen.ui_scale(viewport_h, float(cfg["reference_height"]))
	var s: float = _scale
	var pad: float = float(cfg["prompt_panel_padding"]) * s
	var width: float = 600.0 * s
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(cfg["prompt_panel_color"]))
	style.border_color = Color.html(String(cfg["prompt_panel_border_color"]))
	style.set_border_width_all(maxi(roundi(2.0 * s), 1))
	style.set_corner_radius_all(roundi(6.0 * s))
	style.set_content_margin_all(pad)
	_panel.add_theme_stylebox_override("panel", style)
	_center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8.0 * s))
	_panel.add_child(column)
	var title := _label(String(texts.get("title", "Start a run")), roundi(float(cfg["prompt_title_font_size"]) * s * 0.8), Color.html(String(cfg["prompt_title_color"])), width)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := _label(String(texts.get("subtitle", "%s")) % String(_choices["character_name"]), roundi(float(cfg["prompt_subtitle_font_size"]) * s), Color.html(String(cfg["prompt_text_color"])), width)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	var ring := StyleBoxEmpty.new()
	ring.set_content_margin_all(float(RunOptionCard.focus_ring_width(cfg, s)))  # the focus outline sits outside the row: leave room so the scroll box does not clip it
	_scroll.add_theme_stylebox_override("panel", ring)
	column.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", roundi(8.0 * s))
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows_box)
	_rows = rows_for(_choices, texts)
	for row: Dictionary in _rows:
		if bool(row["selectable"]):
			_add_row_button(row, cfg, texts, width)
		else:
			_rows_box.add_child(_flagged_row(row, cfg, width))
	var problems: Array = _choices.get("rule_problems", [])
	if not problems.is_empty():
		var message := _label("\n".join(PackedStringArray(problems)), roundi(float(cfg["option_small_font_size"]) * s), Color.html(String(cfg["option_warn_color"])), width)
		column.add_child(message)
	var hint := _label(String(texts.get("hint", "")), roundi(float(cfg["prompt_hint_font_size"]) * s), Color.html(String(cfg["option_flavor_color"])), width)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
	_rows_box.minimum_size_changed.connect(_fit_scroll)
	_fit_scroll.call_deferred()


## The list takes the height it needs, up to 58% of the screen; past that it scrolls (the focused row is followed).
func _fit_scroll() -> void:
	if _scroll == null or _rows_box == null or not is_instance_valid(_rows_box):
		return
	var limit: float = get_viewport().get_visible_rect().size.y * 0.58
	var ring: float = 2.0 * float(RunOptionCard.focus_ring_width(UiConfig.run_ui(), _scale))
	_scroll.custom_minimum_size.y = minf(_rows_box.get_combined_minimum_size().y + ring, limit)


func _add_row_button(row: Dictionary, cfg: Dictionary, texts: Dictionary, width: float) -> void:
	var button := StartRow.new()
	button.setup(row, cfg, texts, width, _scale)
	if int(row["slot"]) != LoadoutArgs.NO_SLOT:
		button.set_meta("slot", int(row["slot"]))
		button.pressed.connect(choose.bind(int(row["slot"])))
	else:
		button.pressed.connect(open_editor)
	_rows_box.add_child(button)
	_buttons.append(button)


## A skipped loadout: not a button and not focusable; an X, what is wrong and why, in the warning colour.
func _flagged_row(row: Dictionary, cfg: Dictionary, width: float) -> Control:
	var s: float = _scale
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(cfg["option_disabled_color"]))
	style.border_color = Color.html(String(cfg["option_warn_color"]))
	style.set_border_width_all(maxi(roundi(1.5 * s), 1))
	style.set_corner_radius_all(roundi(6.0 * s))
	style.set_content_margin_all(float(cfg["option_pad"]) * s)
	panel.add_theme_stylebox_override("panel", style)
	var warn: Color = Color.html(String(cfg["option_warn_color"]))
	var small: int = roundi(float(cfg["option_small_font_size"]) * s)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(10.0 * s))
	panel.add_child(box)
	var mark := RunTypeIcon.new()
	mark.shape = RunIcons.SHAPE_X
	mark.color = warn
	mark.custom_minimum_size = Vector2.ONE * float(small) * 1.2
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_child(mark)
	var text := VBoxContainer.new()
	box.add_child(text)
	var text_width: float = width - 2.0 * float(cfg["option_pad"]) * s - float(small) * 2.4
	text.add_child(_label(String(row["title"]), roundi(float(cfg["option_body_font_size"]) * s), warn, text_width))
	text.add_child(_label(String(row["detail"]), small, Color.html(String(cfg["prompt_text_color"])), text_width))
	return panel


## The slots the buttons start, in order (tests).
func choice_slots() -> Array[int]:
	var out: Array[int] = []
	for button in _buttons:
		if button.has_meta("slot"):
			out.append(int(button.get_meta("slot")))
	return out


func _focus_last_used() -> void:
	var wanted: int = int(_choices.get("last_used", LoadoutStore.PRESET))
	for button in _buttons:
		if button.has_meta("slot") and int(button.get_meta("slot")) == wanted:
			button.grab_focus()
			return
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


## The slot that has the focus (tests); LoadoutArgs.NO_SLOT when none does.
func focused_slot() -> int:
	for button in _buttons:
		if button.has_focus() and button.has_meta("slot"):
			return int(button.get_meta("slot"))
	return LoadoutArgs.NO_SLOT


## The row buttons (tests and captures).
func row_buttons() -> Array[Button]:
	return _buttons


## One selectable row: an arrow that shows on the highlighted row, the title, the detail line, and a "Last used" pill. Hover moves the highlight here (like the option cards).
class StartRow extends Button:
	var arrow: RunTypeIcon = null
	var last_used_tag: PanelContainer = null
	var title_label: Label = null
	var detail_label: Label = null
	var _inner: HBoxContainer = null
	var _pad: float = 0.0
	var _cfg: Dictionary = {}
	var _s: float = 1.0

	func setup(row: Dictionary, cfg: Dictionary, texts: Dictionary, width: float, s: float) -> void:
		_cfg = cfg
		_s = s
		_pad = float(cfg["option_pad"]) * s
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		text = ""
		custom_minimum_size.x = width
		var title_px: int = roundi(float(cfg["option_title_font_size"]) * s)
		var small_px: int = roundi(float(cfg["option_small_font_size"]) * s)
		_apply_styles()
		_inner = HBoxContainer.new()
		_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inner.add_theme_constant_override("separation", roundi(10.0 * s))
		add_child(_inner)
		_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_inner.offset_left = _pad
		_inner.offset_top = _pad
		_inner.offset_right = -_pad
		_inner.offset_bottom = -_pad
		arrow = RunTypeIcon.new()
		arrow.shape = RunIcons.SHAPE_PLUS if String(row["kind"]) == StartScreen.ROW_EDIT else RunIcons.SHAPE_ARROW
		arrow.color = Color.html(String(cfg["option_focus_color"]))
		arrow.custom_minimum_size = Vector2.ONE * float(title_px) * 0.9
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		arrow.modulate.a = 1.0 if String(row["kind"]) == StartScreen.ROW_EDIT else 0.0
		_inner.add_child(arrow)
		var text_box := VBoxContainer.new()
		text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_inner.add_child(text_box)
		var tag_room: float = float(small_px) * 6.5 if bool(row["last_used"]) else 0.0
		var text_width: float = width - 2.0 * _pad - float(title_px) * 0.9 - 10.0 * s - tag_room
		title_label = _make_label(String(row["title"]), title_px, Color.html("#ffffff"), text_width)
		text_box.add_child(title_label)
		if String(row["detail"]) != "":
			detail_label = _make_label(String(row["detail"]), small_px, Color.html(String(cfg["prompt_text_color"])), text_width)
			text_box.add_child(detail_label)
		if bool(row["last_used"]):
			last_used_tag = _pill(String(texts.get("last_used", "Last used")), small_px)
			last_used_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_inner.add_child(last_used_tag)
		_inner.minimum_size_changed.connect(update_minimum_size)
		focus_entered.connect(_on_focus_changed.bind(true))
		focus_exited.connect(_on_focus_changed.bind(false))
		mouse_entered.connect(_on_hover)
		update_minimum_size()

	func _get_minimum_size() -> Vector2:
		if _inner == null:
			return Vector2.ZERO
		var inner_min: Vector2 = _inner.get_combined_minimum_size()
		return Vector2(inner_min.x + 2.0 * _pad, inner_min.y + 2.0 * _pad)

	func _make_label(label_text: String, font_px: int, color: Color, wrap_width: float) -> Label:
		var label := Label.new()
		label.text = label_text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", font_px)
		label.add_theme_color_override("font_color", color)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = wrap_width
		return label

	## The "Last used" pill: an accent outline with a check mark and the words.
	func _pill(word: String, font_px: int) -> PanelContainer:
		var accent: Color = Color.html(String(_cfg["option_accent_color"]))
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style.border_color = accent
		style.set_border_width_all(maxi(roundi(1.5 * _s), 1))
		style.set_corner_radius_all(roundi(9.0 * _s))
		style.content_margin_left = 7.0 * _s
		style.content_margin_right = 8.0 * _s
		style.content_margin_top = 1.0 * _s
		style.content_margin_bottom = 1.0 * _s
		pill.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", roundi(4.0 * _s))
		pill.add_child(row)
		var mark := RunTypeIcon.new()
		mark.shape = RunIcons.SHAPE_CHECK
		mark.color = accent
		mark.custom_minimum_size = Vector2.ONE * float(font_px) * 0.9
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		row.add_child(_make_label(word, font_px, accent, 0.0))
		return pill

	func _apply_styles() -> void:
		var border: float = maxi(roundi(float(_cfg["option_frame_width"]) * _s), 1)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.html(String(_cfg["option_card_color"]))
		normal.border_color = Color.html(String(_cfg["option_card_border_color"]))
		normal.set_border_width_all(roundi(border * 0.5) + 1)
		normal.set_corner_radius_all(roundi(6.0 * _s))
		var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color.html(String(_cfg["option_card_hover_color"]))
		var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
		focus.border_color = Color.html(String(_cfg["option_focus_color"]))
		focus.set_border_width_all(maxi(roundi(float(_cfg["option_focus_width"]) * _s), 2))
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", focus)
		add_theme_stylebox_override("focus", focus)
		add_theme_stylebox_override("hover_pressed", focus)

	func _on_hover() -> void:
		if not disabled and not has_focus():
			grab_focus()

	func _on_focus_changed(focused: bool) -> void:
		if arrow != null and arrow.shape != RunIcons.SHAPE_PLUS:
			arrow.modulate.a = 1.0 if focused else 0.0
