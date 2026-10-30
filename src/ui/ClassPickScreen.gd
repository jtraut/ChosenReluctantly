class_name ClassPickScreen
extends CanvasLayer
## The class pick screen (W1a): a run starts with a choice of character, last pick preselected so Enter starts. It lives in
## scenes/main/RunMain.tscn next to the RunController it talks to.
##
## How it holds the room: it opens over the freshly built room and pauses the game through GamePause, so nothing moves, no
## wave timer runs and no card can be cast until a pick is confirmed (a paused overlay, not a delayed room start). A confirm of
## the class already in play just closes it and resumes. A different class makes RunController.confirm_class_pick restart the
## run as that class (same seed and room) in a fresh scene; the overlay stays up until the old scene is replaced and the fresh
## scene does not open it again (`_confirmed_run`), so it never flashes twice.
##
## When it opens (`should_open`): in a real windowed game, at the start of every run (run 1, Try again, New run), unless the
## launch fixed the class (`--class` or a `--deck` preset: RunSession.character_forced) so tools and scripted launches never
## stall. Headless runs, `-s` scripts and the arena or scenarios never open it. `--show-class-pick` forces it on for a capture,
## even with `--class` (which then is the preselection).
##
## Input: keys 1..N and the arrow keys move the one highlight (never confirm), Enter or a click confirms, Space is swallowed
## (it is the dodge key, so a mashed Space never starts a run). Presses are ignored for `run_ui.prompt_option_arm_delay`
## seconds after opening, like the reward screen. Words and sizes: data/ui.json `class_pick`.

signal opened()
## The overlay closed because a pick was confirmed (and, for a different class, the run is restarting as it).
signal confirmed(character_id: String)

## Launch arg (after `--`): open the screen even when `--class` fixed the class (captures).
const ARG_SHOW := "--show-class-pick"

## Tests: true/false forces the "real game" part of the decision; null = decide from how the game was launched.
static var enabled_override: Variant = null
## The run whose pick was confirmed; the scene that replaces the old one for it does not ask again.
static var _confirmed_run: RunState = null

var _controller: RunController = null
var _cards: Array[ClassPickCard] = []
var _armed_at_msec: int = 0
var _arm_generation: int = 0
var _fit_scale: float = 1.0
var _paused_here: bool = false
var _confirming: bool = false
var _last_focus: int = 0

var _root: Control = null
var _backdrop: ColorRect = null
var _center: CenterContainer = null
var _panel: PanelContainer = null
var _column: VBoxContainer = null
var _title_label: Label = null
var _line_label: Label = null
var _row: HBoxContainer = null
var _start_label: Label = null
var _keys_label: Label = null


## Test hook and tools: forget the override and the remembered run.
static func reset() -> void:
	enabled_override = null
	_confirmed_run = null


static func _show_arg() -> bool:
	return OS.get_cmdline_user_args().has(ARG_SHOW)


## True when this launch is a real interactive game (a window, not a script or a headless run).
static func interactive() -> bool:
	if enabled_override != null:
		return bool(enabled_override)
	if DisplayServer.get_name() == "headless":
		return false
	var args: PackedStringArray = OS.get_cmdline_args()
	return not (args.has("-s") or args.has("--script"))


## Whether the screen should open for this run state (pure over the statics; the whole decision in one place).
static func should_open(state: RunState) -> bool:
	if state == null or state == _confirmed_run:
		return false
	if RunSession.character_forced and not _show_arg():
		return false
	if not _show_arg() and not interactive():
		return false
	if enabled_override != null and not bool(enabled_override):
		return false
	return state.history.is_empty() and not state.has_pending() and not state.is_over()


func _ready() -> void:
	visible = false
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_on_resized)
	_open_when_wired.call_deferred()


func _exit_tree() -> void:
	if _paused_here and not _confirming:
		_paused_here = false
		GamePause.resume()


## The scene is fully wired one frame later (Main._ready runs after its children's, and builds the run controller).
func _open_when_wired() -> void:
	var main := get_parent() as Main
	if main == null:
		return  # hosted by something else (a test): `open()` is called by the host
	if main.run_controller == null:
		queue_free()  # the endless arena or a scenario on RunMain: no run, no pick
		return
	_controller = main.run_controller
	if should_open(_controller.state()):
		open()


## Opens the screen and holds the game. `preselect` is a character id ("" = RunSession's chosen class).
func open(preselect: String = "") -> void:
	if _controller == null:
		var main := get_parent() as Main
		_controller = main.run_controller if main != null else null
	_confirming = false
	_rebuild_cards()
	visible = true
	_paused_here = GamePause.pause()
	var delay: float = float(UiConfig.run_ui().get("prompt_option_arm_delay", 0.4))
	_armed_at_msec = Time.get_ticks_msec() + roundi(delay * 1000.0)
	_dim_until_armed(delay)
	var wanted: String = preselect if preselect != "" else CharacterPick.preselected()
	_last_focus = maxi(_index_of(wanted), 0)
	_focus(_last_focus)
	opened.emit()


func is_open() -> bool:
	return visible


## True once the short arm delay after opening has passed (presses before that are ignored).
func options_armed() -> bool:
	return Time.get_ticks_msec() >= _armed_at_msec


## Skips the arm delay (tests and scripted input).
func disarm() -> void:
	_armed_at_msec = 0


## The character ids on the screen, in order.
func character_ids() -> Array[String]:
	var ids: Array[String] = []
	for card in _cards:
		ids.append(card.character_id)
	return ids


## The highlighted character id ("" when nothing is).
func highlighted_id() -> String:
	for card in _cards:
		if card.has_focus():
			return card.character_id
	return _cards[_last_focus].character_id if _last_focus >= 0 and _last_focus < _cards.size() else ""


func card_for(character_id: String) -> ClassPickCard:
	var index: int = _index_of(character_id)
	return _cards[index] if index >= 0 else null


## The panel's natural size and the shrink applied to fit the window (tests and captures).
func panel_min_size() -> Vector2:
	return _panel.get_combined_minimum_size()


func fit_factor() -> float:
	return _panel.scale.x


## The panel's on-screen rectangle after the fit scale, in viewport pixels.
func panel_screen_rect() -> Rect2:
	var scaled: Vector2 = _panel.size * _panel.scale
	return Rect2(_panel.global_position + (_panel.size - scaled) * 0.5, scaled)


## Confirms a class: the highlighted one when `character_id` is "". Ignored before the arm delay and once confirming.
func confirm(character_id: String = "") -> void:
	if not visible or _confirming or not options_armed() or _controller == null:
		return
	var picked: String = character_id if character_id != "" else highlighted_id()
	if picked == "":
		return
	var restarts: bool = picked != _controller.character_id()
	if not _controller.confirm_class_pick(picked):
		return
	_confirmed_run = RunSession.current
	confirmed.emit(picked)
	if restarts:
		# The run restarts as this class in a fresh scene (deferred). Stay up and stay dim until that scene replaces this one.
		_confirming = true
		for card in _cards:
			card.disabled = true
		return
	close()


## Hides the screen and lets the game run again.
func close() -> void:
	visible = false
	if _paused_here:
		_paused_here = false
		GamePause.resume()


func _index_of(character_id: String) -> int:
	for i in range(_cards.size()):
		if _cards[i].character_id == character_id:
			return i
	return -1


func _focus(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_last_focus = index
	_cards[index].grab_focus()
	_update_start_line(index)


func _update_start_line(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return
	_start_label.text = String(UiConfig.class_pick()["start_format"]) % String(_cards[index].entry["display_name"])


func _step(delta: int) -> void:
	if _cards.is_empty():
		return
	_focus(posmod(_last_focus + delta, _cards.size()))


## Number keys and arrows move the highlight and are swallowed (nothing behind the screen may react); Space is swallowed
## and never confirms; Enter reaches the focused card as the usual accept. Runs under the pause: the screen is the pauser.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		return
	if _confirming:
		get_viewport().set_input_as_handled()
		return
	var number: int = key.keycode - KEY_1
	if number < 0 or number > 8:
		number = key.keycode - KEY_KP_1
	if number >= 0 and number <= 8:
		if not key.echo and number < _cards.size():
			_focus(number)
		get_viewport().set_input_as_handled()
		return
	match key.keycode:
		KEY_LEFT, KEY_UP:
			if not key.echo:
				_step(-1)
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_DOWN:
			if not key.echo:
				_step(1)
			get_viewport().set_input_as_handled()


# ---- building ----

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # swallows clicks so they never reach the world
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_backdrop = ColorRect.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_backdrop)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_panel)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_column)
	_title_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	_column.add_child(_title_label)
	_line_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_line_label)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(_row)
	_start_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	_column.add_child(_start_label)
	_keys_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER)
	_keys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_keys_label)
	_panel.minimum_size_changed.connect(_fit)
	_center.sort_children.connect(_apply_fit_scale)  # a container resets its child's scale on every sort
	_apply_style()


func _make_label(alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = alignment
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _scale() -> float:
	return GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(UiConfig.run_ui()["reference_height"]))


func _apply_style() -> void:
	var cfg: Dictionary = UiConfig.class_pick()
	var run_cfg: Dictionary = UiConfig.run_ui()
	var s: float = _scale()
	_backdrop.color = Color.html(String(run_cfg["prompt_backdrop_color"]))
	var pad: float = float(cfg["panel_padding"]) * s
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(run_cfg["prompt_panel_color"]))
	style.border_color = Color.html(String(run_cfg["prompt_panel_border_color"]))
	style.set_border_width_all(maxi(roundi(2.0 * s), 1))
	style.set_corner_radius_all(roundi(8.0 * s))
	style.set_content_margin_all(pad)
	_panel.add_theme_stylebox_override("panel", style)
	_column.add_theme_constant_override("separation", roundi(14.0 * s))
	_row.add_theme_constant_override("separation", roundi(float(cfg["card_gap"]) * s))
	var text_color := Color.html(String(run_cfg["prompt_text_color"]))
	_title_label.text = String(cfg["title"])
	_title_label.add_theme_font_size_override("font_size", roundi(float(cfg["title_font_size"]) * s))
	_title_label.add_theme_color_override("font_color", Color.html(String(run_cfg["prompt_title_color"])))
	_line_label.text = String(cfg["line"])
	_line_label.add_theme_font_size_override("font_size", roundi(float(cfg["line_font_size"]) * s))
	_line_label.add_theme_color_override("font_color", text_color)
	_start_label.add_theme_font_size_override("font_size", roundi(float(cfg["name_font_size"]) * 0.8 * s))
	_start_label.add_theme_color_override("font_color", Color.html(String(run_cfg["option_focus_color"])))
	_keys_label.text = String(cfg["keys_hint"])
	_keys_label.add_theme_font_size_override("font_size", roundi(float(cfg["small_font_size"]) * s))
	_keys_label.add_theme_color_override("font_color", text_color)


func _rebuild_cards() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_cards.clear()
	var cfg: Dictionary = UiConfig.class_pick()
	var run_cfg: Dictionary = UiConfig.run_ui()
	var s: float = _scale()
	var styles: Dictionary = cfg["attack_styles"]
	var entries: Array[Dictionary] = CharacterDatabase.list()
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var shape: String = String(AttackDatabase.get_light(CharacterDatabase.light_variant(String(entry["id"]))).get("shape", ""))
		var card := ClassPickCard.new()
		card.setup(entry, i, String(styles.get(shape, cfg["attack_style_unknown"])), shape, cfg, run_cfg, s)
		var id: String = String(entry["id"])
		card.pressed.connect(confirm.bind(id))
		card.focus_entered.connect(_on_card_focused.bind(i))
		_row.add_child(card)
		_cards.append(card)
	# The wrapped lines are as wide as the cards together, so the panel is exactly as wide as the row.
	var row_width: float = float(entries.size()) * float(cfg["card_width"]) * s + float(maxi(entries.size() - 1, 0)) * float(cfg["card_gap"]) * s
	_line_label.custom_minimum_size.x = row_width
	_keys_label.custom_minimum_size.x = row_width
	_fit()


func _on_card_focused(index: int) -> void:
	_last_focus = index
	_update_start_line(index)


func _on_resized() -> void:
	if not is_node_ready():
		return
	_apply_style()
	if visible:
		var keep: int = _last_focus
		var was_confirming: bool = _confirming
		_rebuild_cards()
		_confirming = was_confirming
		for card in _cards:
			card.disabled = was_confirming
		if not was_confirming:
			_focus(keep)


## The cards look a little dim until the arm delay has passed, so a press that does nothing is not a mystery.
func _dim_until_armed(delay: float) -> void:
	_arm_generation += 1
	var generation: int = _arm_generation
	_row.modulate.a = 0.55 if delay > 0.0 else 1.0
	if delay <= 0.0:
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	if generation == _arm_generation:
		_row.modulate.a = 1.0


## Keeps the whole panel on screen: laid out for 720p, scaled by height, and shrunk (down to class_pick.min_fit_scale) when
## the window is smaller than that. Never scrolls.
func _fit() -> void:
	if _panel == null:
		return
	var cfg: Dictionary = UiConfig.class_pick()
	_panel.scale = Vector2.ONE  # measure at natural size
	var needed: Vector2 = _panel.get_combined_minimum_size()
	var avail: Vector2 = get_viewport().get_visible_rect().size * float(cfg["fit_margin"])
	_fit_scale = clampf(minf(avail.y / maxf(needed.y, 1.0), avail.x / maxf(needed.x, 1.0)), float(cfg["min_fit_scale"]), 1.0)
	_apply_fit_scale()


func _apply_fit_scale() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(_fit_scale, _fit_scale)
