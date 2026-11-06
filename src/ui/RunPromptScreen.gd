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
## An option button was activated (mouse, Enter or its number key): the option's `id`. In a run the screen also
## passes it to RunController.choose; a test or another host can listen to this alone.
signal option_chosen(option_id: String)

@onready var root: Control = $Root
@onready var backdrop: ColorRect = $Root/Backdrop
@onready var panel: PanelContainer = $Root/Center/Panel
@onready var column: VBoxContainer = $Root/Center/Panel/Column
@onready var icon: RunTypeIcon = $Root/Center/Panel/Column/Header/Icon
@onready var title_label: Label = $Root/Center/Panel/Column/Header/Title
@onready var subtitle_label: Label = $Root/Center/Panel/Column/Subtitle
@onready var line_label: Label = $Root/Center/Panel/Column/Line
@onready var stats: GridContainer = $Root/Center/Panel/Column/Stats
@onready var scroll: ScrollContainer = $Root/Center/Panel/Column/Scroll
@onready var options_box: GridContainer = $Root/Center/Panel/Column/Scroll/Options
@onready var footer_box: HBoxContainer = $Root/Center/Panel/Column/Footer
@onready var button: Button = $Root/Center/Panel/Column/Action
@onready var keys_label: Label = $Root/Center/Panel/Column/Keys
@onready var next_icon: RunTypeIcon = $Root/Center/Panel/Column/NextRow/NextIcon
@onready var hint_label: Label = $Root/Center/Panel/Column/NextRow/Hint
## BD2: the relic being taken, shown above the give-one-up list (built in code, hidden otherwise).
var incoming_plate: PanelContainer = null

var _controller: RunController = null
var _pending: Dictionary = {}
## The option dicts of the open choice, and one button per option (same order).
var _options: Array[Dictionary] = []
var _option_buttons: Array[Button] = []
## How the open options are laid out: "row" (cards side by side), "grid" (a removal list, one column per slot),
## "cells" (BD2: the give-one-up relic list, wrapping rows that scroll), "actions" (a short row of wide choices). Number keys pick nothing in any of them (PL3): arrows and Tab move the highlight.
var _layout: String = "row"
var _scroll_on: bool = false
var _last_focus: int = -1
var _arm_generation: int = 0
var _shown: Dictionary = {}
var _auto_chosen: int = 0
## Real time (ms ticks) before which option presses are ignored: the panel opens right after a fight, while
## the player is still mashing the card keys (Space is Movement) and LMB. Length: data/ui.json run_ui.prompt_option_arm_delay.
var _armed_at_msec: int = 0
var _fit_scale: float = 1.0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps the focus restore alive across a pause; nothing here ticks
	_build_incoming_plate()
	_apply_style()
	get_viewport().size_changed.connect(_apply_style)
	panel.minimum_size_changed.connect(_fit_panel)
	($Root/Center as Container).sort_children.connect(_apply_fit_scale)  # the cards settle a pass after they are added
	button.pressed.connect(_on_pressed)
	GamePause.paused_changed.connect(_on_pause_changed)
	_controller = get_parent().get_node_or_null("RunController") as RunController
	if _controller == null:
		return
	if kind == "win":
		_controller.run_won.connect(_show_win)
	else:
		_controller.room_cleared.connect(_show_cleared)
		_controller.choice_requested.connect(show_choice)


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
		"line": _cleared_line(room_type, healed, text),
		"rows": RunPromptRows.cleared_rows(summary, text),
		"button": String(text["button"]),
		"hint": _next_hint(String(text.get("hint", ""))),
		"icon_shape": RunIcons.shape_for(room_type),
		"icon_color": RunIcons.color_for(room_type, UiConfig.run_ui(), tiers),
	})


func _cleared_line(room_type: String, healed: float, text: Dictionary) -> String:
	if room_type != "rest":
		return ""
	return (String(text["rest_line"]) % roundi(healed)) if healed > 0.0 else String(text["rest_full_line"])


## Copies of each card in the run's deck (card id -> count); {} outside a run. Read-only, for "You own N".
func _owned_counts() -> Dictionary:
	var counts: Dictionary = {}
	var state: RunState = _controller.state() if _controller != null else null
	if state != null:
		for card_id: String in state.deck:
			counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts


## The type id of the room after this one ("" after the last), for the shape beside the "Next:" line.
func _next_room_type() -> String:
	var state: RunState = _controller.state() if _controller != null else null
	if state == null:
		return ""
	var rooms: Array[Dictionary] = _controller.rooms()
	var next_index: int = state.room_index + 1
	return String(rooms[next_index]["type"]) if next_index < rooms.size() else ""


## "Next: Room N of M - Type" above the usual hint text (no next room after the last).
func _next_hint(hint: String) -> String:
	var next_line: String = _controller.next_room_line() if _controller != null else ""
	if next_line == "":
		return hint
	return next_line if hint == "" else next_line + "\n" + hint


## Opens a choice (RunController.choice_requested): the model's options become buttons in `options_box`.
## Placeholder look; ux restyles it. See RunChoices for the option dict.
func show_choice(model: Dictionary) -> void:
	var room_type: String = String(model.get("room_type", ""))
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	show_content({
		"title": String(model.get("title", "")),
		"subtitle": "%s  -  %s" % [String(model.get("room_label", "")), String(model.get("room_type_name", ""))],
		"line": String(model.get("line", "")),
		"options": model.get("options", []),
		"rejects_remaining": int(model.get("rejects_remaining", 0)),
		"rejects_max": int(model.get("rejects_max", 0)),
		"owned": _owned_counts(),
		"relic": _relic_content(model),
		"rows": _locked_relic_rows(model),
		"hint": String(model.get("next_line", "")),
		"icon_shape": RunIcons.shape_for(room_type),
		"icon_color": RunIcons.color_for(room_type, UiConfig.run_ui(), tiers),
	})


## The relic parts of a choice model (BD2): {} for anything that is not a relic choice, else the give-up step's incoming relic.
func _relic_content(model: Dictionary) -> Dictionary:
	if not model.has("relic_choice"):
		return {}
	return {"choice": String(model["relic_choice"]), "incoming": model.get("incoming", {})}


## Owned relics that cannot be given up (boss tier), as label/value rows above the give-up list, so they are visible but are not options.
func _locked_relic_rows(model: Dictionary) -> Array:
	var rows: Array = []
	if String(model.get("relic_choice", "")) != "giveup":
		return rows
	var names: PackedStringArray = PackedStringArray()
	for shown: Variant in (model.get("relics_owned", []) as Array):
		var relic: Dictionary = shown
		if not bool(relic.get("giveable", true)):
			names.append("%s (%s)" % [String(relic.get("name", "")), String(relic.get("tier_name", ""))])
	if not names.is_empty():
		var texts: Dictionary = RunConfig.ui().get("relic", {})
		rows.append({"label": String(texts.get("locked_label", "")), "value": ", ".join(names)})
	return rows


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
	_shown = content
	_fill(content)
	visible = true
	var delay: float = float(UiConfig.run_ui().get("prompt_option_arm_delay", 0.4))
	_armed_at_msec = Time.get_ticks_msec() + roundi(delay * 1000.0)
	_fit_panel()
	_dim_until_armed(delay)
	if _options.is_empty():
		button.grab_focus()
	else:
		_last_focus = _default_focus()
		_focus_option(_last_focus)
		_debug_auto_choose()


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
		call_deferred("_restore_focus")  # the pause screen took focus; give it back


## Debug launch arg `--run-auto-choose=<option id>[,<id>...]` (after `--`): picks those option ids in turn as the
## choices open, once each, so a screenshot can reach the removal list. Ignored without the arg.
func _debug_auto_choose() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--run-auto-choose="):
			continue
		var ids: PackedStringArray = arg.get_slice("=", 1).split(",")
		var used: int = _auto_chosen
		if used >= ids.size():
			return
		_auto_chosen += 1
		await get_tree().create_timer(0.1, true, false, true).timeout
		disarm()
		_on_option_pressed(ids[used])
		return


## Gives the focus back to the option that had it (else the first enabled one), or to the action button.
func _restore_focus() -> void:
	if not visible:
		return
	if _options.is_empty():
		button.grab_focus()
		return
	var index: int = _last_focus if (_last_focus >= 0 and _last_focus < _option_buttons.size() and not _option_buttons[_last_focus].disabled) else _default_focus()
	_focus_option(index)


## The cards (or the Continue / New run button) look a little dim until the arm delay has passed, so a press that
## does nothing is not a mystery.
func _dim_until_armed(delay: float) -> void:
	_arm_generation += 1
	var generation: int = _arm_generation
	var dimmed: float = 0.55
	for dimmable: Control in [options_box, footer_box, button]:
		dimmable.modulate.a = dimmed
	if delay <= 0.0:
		for dimmable: Control in [options_box, footer_box, button]:
			dimmable.modulate.a = 1.0
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	if generation == _arm_generation:
		for dimmable: Control in [options_box, footer_box, button]:
			dimmable.modulate.a = 1.0


func _fill(content: Dictionary) -> void:
	title_label.text = String(content.get("title", ""))
	var subtitle: String = String(content.get("subtitle", ""))
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	var line: String = String(content.get("line", ""))
	line_label.text = line
	line_label.visible = line != ""
	button.text = String(content.get("button", ""))
	_fill_options(content.get("options", []), content)
	_fill_incoming_plate(content.get("relic", {}))
	button.visible = _options.is_empty()
	if not _options.is_empty():
		subtitle_label.visible = false  # the room indicator at the top already says it; the cards need the height
	var hint: String = String(content.get("hint", ""))
	hint_label.text = hint
	hint_label.visible = hint != ""
	var next_type: String = _next_room_type()
	if _layout == "cells" and _scrolls():
		hint_label.visible = false  # a long give-up list needs the height; the Next line is not needed to pick a relic
	next_icon.visible = hint_label.visible and next_type != "" and _controller != null and hint.contains(_controller.next_room_line())
	if next_icon.visible:
		next_icon.shape = RunIcons.shape_for(next_type)
		next_icon.color = RunIcons.color_for(next_type, UiConfig.run_ui(), RunConfig.get_config().get("tiers", {}))
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


## How a list of options is laid out: "grid" (a removal list, one column per slot), "row" (reward cards side by
## side) or "actions" (a short row of wide choices). Decided from the option kinds, so any host gets a sane layout.
static func layout_for(options: Array) -> String:
	var has_card: bool = false
	for option: Variant in options:
		var d: Dictionary = option
		if String(d.get("kind", "")) == "remove" and String(d.get("card_id", "")) != "":
			return "grid"  # a list of cards to pick from; the rest menu's "Remove a card" has no card_id
		if String(d.get("kind", "")) == "giveup":
			return "cells"  # BD2: the relics that can be given up, a wrapping list
		has_card = has_card or String(d.get("kind", "")) == "card" or String(d.get("kind", "")) == "relic"
	return "row" if has_card else "actions"


static func look_for(kind: String) -> RunOptionCard.Look:
	match kind:
		"card":
			return RunOptionCard.Look.CARD
		"skip":
			return RunOptionCard.Look.REJECT
		"remove":
			return RunOptionCard.Look.CELL
		"back":
			return RunOptionCard.Look.BACK
		"relic":
			return RunOptionCard.Look.RELIC
		"relic_skip":
			return RunOptionCard.Look.SKIP_FREE
		"giveup":
			return RunOptionCard.Look.RELIC_CELL
	return RunOptionCard.Look.ACTION


func _fill_options(options: Array, content: Dictionary = {}) -> void:
	for box: Container in [options_box, footer_box]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_options.clear()
	_option_buttons.clear()
	_last_focus = -1
	keys_label.visible = false
	scroll.visible = not options.is_empty()
	footer_box.visible = false
	if options.is_empty():
		return
	_layout = layout_for(options)
	_scroll_on = _layout == "grid" or (_layout == "cells" and options.size() > int(UiConfig.run_ui().get("relic_cells_scroll_above", 6)))
	# Only the removal grid (and a long give-one-up list) may scroll; an offer (cards, reject, rest choices) always shows whole and the panel scales.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if _scrolls() else ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cfg := UiConfig.run_ui()
	var s := _scale(cfg)
	# The ScrollContainer clips its children, and the family-card focus ring sits outside the card: pad it so the ring
	# is not cut off (the notch at the left and top edges, PL2).
	var ring := StyleBoxEmpty.new()
	ring.set_content_margin_all(float(RunOptionCard.focus_ring_width(cfg, s)))
	scroll.add_theme_stylebox_override("panel", ring)
	var texts: Dictionary = RunConfig.ui().get("option", {})
	var owned: Dictionary = content.get("owned", {})
	_layout = layout_for(options)
	var gap: int = roundi(float(cfg["option_gap"]) * s)
	options_box.add_theme_constant_override("h_separation", gap)
	options_box.add_theme_constant_override("v_separation", gap)
	footer_box.add_theme_constant_override("separation", gap)
	var numbered: int = 0
	for i in range(options.size()):
		var option: Dictionary = options[i]
		_options.append(option)
		var kind: String = String(option.get("kind", ""))
		var look: RunOptionCard.Look = look_for(kind)
		if look == RunOptionCard.Look.CELL and String(option.get("card_id", "")) == "":
			look = RunOptionCard.Look.ACTION  # the rest menu's "Remove a card" is a choice, not a list cell
		var width: float = float(cfg["option_card_width"])
		match look:
			RunOptionCard.Look.REJECT:
				width = float(cfg["option_reject_width"])
			RunOptionCard.Look.ACTION:
				width = float(cfg["option_action_width"])
			RunOptionCard.Look.CELL:
				width = float(cfg["option_cell_width"])
			RunOptionCard.Look.BACK:
				width = 200.0
			RunOptionCard.Look.RELIC:
				width = float(cfg["option_card_width"])
			RunOptionCard.Look.SKIP_FREE:
				width = float(cfg["option_reject_width"])
			RunOptionCard.Look.RELIC_CELL:
				width = float(cfg.get("relic_cell_width", cfg["option_cell_width"]))
		var index: int = -1  # no number badge on an option any more
		if _layout != "grid" and kind != "back":
			numbered += 1
		var card := RunOptionCard.new()
		card.setup(option, look, width, cfg, s, {
			"index": index, "texts": texts, "relic_texts": RunConfig.ui().get("relic", {}),
			"owned": int(owned.get(String(option.get("card_id", "")), 0)) if kind == "card" else 0,
			"rejects_remaining": int(content.get("rejects_remaining", 0)),
			"rejects_max": int(content.get("rejects_max", 0)),
		})
		var option_id: String = String(option.get("id", ""))
		card.pressed.connect(_on_option_pressed.bind(option_id))
		card.focus_entered.connect(func() -> void: _last_focus = i)
		_option_buttons.append(card)
	var in_footer: Array[int] = []
	for i in range(_option_buttons.size()):
		if String(_options[i].get("kind", "")) == "back":
			footer_box.add_child(_option_buttons[i])
			in_footer.append(i)
	footer_box.visible = not in_footer.is_empty()
	if _layout == "grid":
		_place_grid(cfg, s, texts)
	elif _layout == "cells":
		options_box.columns = clampi(_option_buttons.size() - in_footer.size(), 1, int(cfg.get("relic_cell_columns", 4)))
		for i in range(_option_buttons.size()):
			if not in_footer.has(i):
				options_box.add_child(_option_buttons[i])
	else:
		options_box.columns = maxi(numbered, 1)
		for i in range(_option_buttons.size()):
			if not in_footer.has(i):
				options_box.add_child(_option_buttons[i])
	var hint_key: String = "remove_list_hint" if _layout == "grid" else "list_hint"
	var hint_count: int = CardSlotController.SLOT_TYPE_ORDER.size() if _layout == "grid" else numbered
	keys_label.text = String(texts.get(hint_key, ""))
	keys_label.visible = keys_label.text != "" and hint_count > 1


## The removal list: one column per HUD slot (same order and keys as the bottom bar), a header per column, cards
## stacked under it. Empty cells are spacers so the grid stays aligned.
## True when the open list scrolls inside the panel: the removal grid, and a long give-one-up list (a short one just shrinks the panel).
func _scrolls() -> bool:
	return _scroll_on


## The relic being taken, above the give-one-up list: a compact plate (hexagon, "Taking: Name", tier and pool, rule text), so the
## list below keeps the height. Built once; `_fill_incoming_plate` fills it.
func _build_incoming_plate() -> void:
	incoming_plate = PanelContainer.new()
	incoming_plate.name = "IncomingPlate"
	incoming_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming_plate.visible = false
	column.add_child(incoming_plate)
	column.move_child(incoming_plate, scroll.get_index())
	var body := VBoxContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming_plate.add_child(body)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	var hex := RunTypeIcon.new()
	hex.name = "Hex"
	hex.shape = RunIcons.SHAPE_HEX
	head.add_child(hex)
	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	var rule := Label.new()
	rule.name = "Rule"
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(rule)


func _fill_incoming_plate(relic: Dictionary) -> void:
	var incoming: Dictionary = relic.get("incoming", {}) if String(relic.get("choice", "")) == "giveup" else {}
	incoming_plate.visible = not incoming.is_empty()
	if incoming.is_empty():
		return
	var cfg := UiConfig.run_ui()
	var s := _scale(cfg)
	var texts: Dictionary = RunConfig.ui().get("relic", {})
	var accent := Color.html(String(cfg.get("relic_accent_color", "#c9a2ff")))
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(cfg["option_card_color"]))
	style.border_color = accent
	style.set_border_width_all(maxi(roundi(2.0 * s), 2))
	style.set_content_margin_all(8.0 * s)
	incoming_plate.add_theme_stylebox_override("panel", style)
	var small: int = roundi(float(cfg["option_small_font_size"]) * s)
	var body_size: int = roundi(float(cfg["option_body_font_size"]) * s)
	var hex: RunTypeIcon = incoming_plate.get_node("Body/Head/Hex")
	hex.color = accent
	hex.custom_minimum_size = Vector2.ONE * float(body_size) * 1.2
	(incoming_plate.get_node("Body/Head") as HBoxContainer).add_theme_constant_override("separation", roundi(8.0 * s))
	var title: Label = incoming_plate.get_node("Body/Head/Title")
	title.text = String(texts.get("taking_format", "%s")) % [String(incoming.get("name", "")), String(incoming.get("tier_name", "")), String(incoming.get("pool_name", ""))]
	title.add_theme_font_size_override("font_size", body_size)
	title.add_theme_color_override("font_color", Color.html("#ffffff"))
	var rule: Label = incoming_plate.get_node("Body/Rule")
	rule.text = String(incoming.get("rule_text", ""))
	rule.custom_minimum_size.x = float(cfg["prompt_panel_min_width"]) * s - 2.0 * float(cfg["prompt_panel_padding"]) * s - 16.0 * s
	rule.add_theme_font_size_override("font_size", small)
	rule.add_theme_color_override("font_color", Color.html(String(cfg["prompt_text_color"])))


func _place_grid(cfg: Dictionary, s: float, texts: Dictionary) -> void:
	var slot_types: Array[String] = []
	var by_slot: Dictionary = {}
	for i in range(_options.size()):
		if String(_options[i].get("kind", "")) == "back":
			continue
		var slot_type: String = String(_options[i].get("slot_type", ""))
		if not by_slot.has(slot_type):
			by_slot[slot_type] = []
			slot_types.append(slot_type)
		(by_slot[slot_type] as Array).append(i)
	slot_types.sort_custom(func(a: String, b: String) -> bool:
		var ka: int = RunOptionCard.slot_key_for(a)
		var kb: int = RunOptionCard.slot_key_for(b)
		return (ka if ka > 0 else 99) < (kb if kb > 0 else 99))
	options_box.columns = maxi(slot_types.size(), 1)
	var cell_w: float = float(cfg["option_cell_width"]) * s
	for slot_type: String in slot_types:
		var first: Dictionary = _options[(by_slot[slot_type] as Array)[0]]
		var key: int = RunOptionCard.slot_key_for(slot_type)
		var head := Label.new()
		head.text = (String(texts.get("slot_label", "%s (%s)")) % [InputLabels.slot_name(slot_type), InputLabels.slot_key(slot_type)]) if key > 0 else String(first.get("slot_name", ""))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size.x = cell_w
		head.add_theme_font_size_override("font_size", roundi(float(cfg["option_small_font_size"]) * s))
		head.add_theme_color_override("font_color", Color.html(String(cfg["prompt_title_color"])))
		options_box.add_child(head)
	var rows: int = 0
	for slot_type: String in slot_types:
		rows = maxi(rows, (by_slot[slot_type] as Array).size())
	for r in range(rows):
		for slot_type: String in slot_types:
			var list: Array = by_slot[slot_type]
			if r < list.size():
				options_box.add_child(_option_buttons[list[r]])
			else:
				var spacer := Control.new()
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				spacer.custom_minimum_size = Vector2(cell_w, 0.0)
				options_box.add_child(spacer)


## True once the short arm delay after opening has passed (options ignore presses before that).
func options_armed() -> bool:
	return Time.get_ticks_msec() >= _armed_at_msec


## Skips the arm delay (tests and scripted input).
func disarm() -> void:
	_armed_at_msec = 0


## Where the highlight starts: Cancel in the give-one-up step (a reflexive Enter must not give a relic away), else the first enabled option.
func _default_focus() -> int:
	if _layout == "cells":
		for i in range(_options.size()):
			if String(_options[i].get("kind", "")) == "back" and bool(_options[i].get("enabled", true)):
				return i
	return _first_enabled()


func _first_enabled() -> int:
	for i in range(_options.size()):
		if bool(_options[i].get("enabled", true)):
			return i
	return 0


func _focus_option(index: int) -> void:
	if index >= 0 and index < _option_buttons.size() and not _option_buttons[index].disabled:
		_option_buttons[index].grab_focus()


## Number keys do nothing here (PL3 removed the digit shortcuts; Enter or a click confirms the highlighted option) and are swallowed while options are
## open. The panel does not pause the tree, so Player._unhandled_input would still see the slot keys (Q, E, 1, 2, R
## today) and their Shift swaps: any event matching a `slot_N` or `dead_card_swap_N` action is swallowed here too, by
## action and not by key, so it follows rebinding. Space is swallowed as well: it is the
## Movement card key (slot_4 by default), the player is mashing it as the panel opens, and a focused button would otherwise confirm on it.
## Accidental picks are also held off by the short arm delay after opening (`options_armed`). Does nothing while paused.
func _input(event: InputEvent) -> void:
	if not visible or GamePause.is_paused():
		return
	var key := event as InputEventKey
	if key == null:
		return
	var slot_action: bool = swallows_slot_action(key)
	if not key.pressed:
		# Releases too: with cast-on-release a slot key held as the panel opened would cast when let go.
		if slot_action:
			get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_SPACE:
		# Never confirms anything here (a focused Button would take it as ui_accept), with options or with the lone
		# Continue / New run button: the player is mashing Space (Movement) as the panel opens.
		get_viewport().set_input_as_handled()
		return
	if _options.is_empty():
		if slot_action:
			get_viewport().set_input_as_handled()
		return
	# Number keys do nothing here (director 2026-11-02: mouse, arrows and Enter pick). Slot actions are still held back
	# so a card key pressed mid-menu never casts.
	if slot_action:
		get_viewport().set_input_as_handled()


## True when the event is a slot cast or a dead-card swap (any binding of slot_1..5 / dead_card_swap_1..5, modifiers
## ignored so Shift+Q is held back from Q's slot as well).
static func swallows_slot_action(event: InputEvent) -> bool:
	for action: StringName in Player.USE_ACTIONS:
		if event.is_action(action):
			return true
	for action: StringName in Player.SWAP_ACTIONS:
		if event.is_action(action):
			return true
	return false


func _on_option_pressed(option_id: String) -> void:
	if not visible or GamePause.is_paused() or not options_armed():
		return
	option_chosen.emit(option_id)
	if _controller == null:
		return
	var result: Dictionary = _controller.choose(option_id)
	# A finished choice closes the panel, unless the run now asks something else (a map run's pick-next-node choice follows a reward, MAP1-B:
	# `choice_requested` has already refilled the panel for it).
	if bool(result.get("ok", false)) and bool(result.get("finished", false)) and not _controller.has_choice():
		visible = false


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
	column.add_theme_constant_override("separation", roundi(12.0 * s))
	stats.add_theme_constant_override("h_separation", roundi(40.0 * s))
	stats.add_theme_constant_override("v_separation", roundi(6.0 * s))
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
	_font(keys_label, "prompt_hint_font_size", s, cfg)
	keys_label.add_theme_color_override("font_color", text_color)
	keys_label.custom_minimum_size = Vector2(width - 2.0 * pad, 0.0)
	var next_px: float = float(cfg["indicator_icon_size"]) * s
	next_icon.custom_minimum_size = Vector2(next_px, next_px)
	(next_icon.get_parent() as HBoxContainer).add_theme_constant_override("separation", roundi(8.0 * s))
	if visible and not _shown.is_empty():
		_fill(_shown)  # resized while open: rebuild at the new scale, keep the highlight
		_fit_panel()
		_restore_focus()
	_font(button, "prompt_button_font_size", s, cfg)
	var min_size: Array = cfg["prompt_button_min_size"]
	button.custom_minimum_size = Vector2(float(min_size[0]), float(min_size[1])) * s
	for child in stats.get_children():
		var label := child as Label
		if label != null:
			label.add_theme_font_size_override("font_size", roundi(float(cfg["prompt_stat_font_size"]) * s))


## Keeps the whole panel on screen: the layout is sized for 720p and scaled by height, and a long removal list can
## still be taller than the screen, so the panel shrinks (down to run_ui.option_min_fit_scale) rather than clip.
func _fit_panel() -> void:
	var cfg := UiConfig.run_ui()
	panel.scale = Vector2.ONE  # measure at natural size
	var floor_scale: float = float(cfg["option_min_fit_scale"])
	if scroll.visible and _scrolls():
		# The removal grid scrolls when it would not fit: give the scroll area what the rest of the panel leaves.
		var rest_h: float = panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
		var room: float = _avail_height(cfg) - rest_h
		var content_h: float = options_box.get_combined_minimum_size().y + scroll.get_theme_stylebox("panel").get_minimum_size().y
		var wanted: float = minf(content_h, maxf(room, 120.0 * _scale(cfg)))
		if not is_equal_approx(scroll.custom_minimum_size.y, wanted):
			scroll.custom_minimum_size.y = wanted
	elif scroll.visible:
		# An offer never scrolls: the area is exactly as tall as its content and the whole panel shrinks to fit.
		var whole_h: float = options_box.get_combined_minimum_size().y + scroll.get_theme_stylebox("panel").get_minimum_size().y
		if not is_equal_approx(scroll.custom_minimum_size.y, whole_h):
			scroll.custom_minimum_size.y = whole_h
		floor_scale = float(cfg["offer_min_fit_scale"])
	var needed: Vector2 = panel.get_combined_minimum_size()
	var avail: Vector2 = get_viewport().get_visible_rect().size * float(cfg["option_fit_margin"])
	avail.y = _avail_height(cfg)
	var factor: float = clampf(minf(avail.y / maxf(needed.y, 1.0), avail.x / maxf(needed.x, 1.0)), floor_scale, 1.0)
	_fit_scale = factor
	_apply_fit_scale()


## A container resets its child's scale to 1 every time it sorts (after a size change), which silently undid the
## fit and let the panel overflow the window. So the fit is kept here and re-applied after every sort.
func _apply_fit_scale() -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(_fit_scale, _fit_scale)


## Height the panel may use. The panel is centred in the area under the top HUD band (health panel and meters), so
## its top edge never covers the HP label or the meters at any resolution; the band is only given up, not mirrored
## at the bottom, so the cards keep their height.
func _avail_height(cfg: Dictionary) -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var band: float = _band_end()
	($Root/Center as Control).offset_top = band
	return (vp.y - band) * float(cfg["option_fit_margin"])


func _band_end() -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var hud_cfg := UiConfig.hud()
	var meters: Dictionary = HudLayout.attack_meter_rects(vp, hud_cfg)
	return (meters[&"heavy"] as Rect2).end.y + HudLayout.ui_scale(vp, hud_cfg) * float(hud_cfg["meter_top_gap"])


## The panel's natural size (tests and screenshots); `fit_factor` is the shrink applied to it.
func panel_min_size() -> Vector2:
	return panel.get_combined_minimum_size()


func fit_factor() -> float:
	return panel.scale.x


func _font(control: Control, key: String, s: float, cfg: Dictionary) -> void:
	control.add_theme_font_size_override("font_size", roundi(float(cfg[key]) * s))


func _on_pressed() -> void:
	if not visible or not options_armed():
		return
	visible = false
	confirmed.emit()
	if _controller == null:
		return
	if kind == "win":
		(get_parent() as Main).restart_arena()  # a new run with a new seed
	else:
		_controller.continue_to_next_room()
