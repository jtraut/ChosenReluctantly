class_name LoadoutEditorScreen
extends CanvasLayer
## The loadout editor (3d sitting E). Opened from the start screen's "Edit or create a loadout" row, over a `LoadoutDraft`; all rules and saving are the draft's, the checker's
## and the store's, so this file only draws them. Layout: slot tabs on top (which of the 5 loadouts to edit), the collection grouped by slot on the left (each card has an
## availability badge and its copies), and on the right the name, the starter relic, the live counts, the plan and the checker's reasons. Save, Delete and Back sit in a footer.
##
## Pure model (unit-tested, no scene): `badge_for`, `tiles_for`, `chips_for`, `tabs_for`, `plan_lines_for`.
## Keys: Up and Down move through cards, Enter adds, Delete / Minus / right-click removes, Left and Right change panel, Ctrl+S saves (not in the hint text: key hints stay out of data), Esc goes back. Words are data (run.json ui.loadout_editor).
## Leaving with unsaved edits, switching slot with unsaved edits and deleting all ask once ("press again"): the second request goes through.

signal closed()

const KIND_STARTER: String = "starter"
const KIND_REWARD: String = "reward"
const KIND_LOCKED: String = "locked"
const DISCARD_BACK: String = "back"
const DELETE_ASK: String = "delete"

var character_id: String = ""
var draft: LoadoutDraft = null

var _store: LoadoutStore = null
var _texts: Dictionary = {}
var _cfg: Dictionary = {}
var _s: float = 1.0
var _groups: Array[Dictionary] = []
var _baseline: Dictionary = {}
var _ask: String = ""
var _status: String = ""
var _relic_options: Array[Dictionary] = []
var _effect_ctx: Dictionary = {}

var _root: Control = null
var _tab_buttons: Array[ChoiceButton] = []
var _card_rows: Dictionary = {}  # card id -> CardRow
var _group_headers: Dictionary = {}  # slot type -> Label
var _group_marks: Dictionary = {}  # slot type -> RunTypeIcon
var _name_edit: LineEdit = null
var _name_count: Label = null
var _relic_buttons: Array[ChoiceButton] = []
var _relic_detail: Label = null
var _chips_box: HFlowContainer = null
var _plan_box: VBoxContainer = null
var _problems_box: VBoxContainer = null
var _collection_scroll: ScrollContainer = null
var _detail_name: Label = null
var _detail_text: Label = null
var _status_label: Label = null
var _save_button: Button = null
var _delete_button: Button = null
var _back_button: Button = null
var _dirty_tag: Label = null


func setup(for_character: String, store: LoadoutStore) -> void:
	character_id = for_character
	_store = store


# ---- the model (pure) ----

## The badge of a card: {kind, text}. "Starter", "Reward", or "Locked: <condition>" ("TBD" when the card names none).
static func badge_for(card: Dictionary, texts: Dictionary) -> Dictionary:
	var availability: String = String(card.get("availability", ""))
	if availability == CardSchema.AVAILABILITY_STARTER:
		return {"kind": KIND_STARTER, "text": String(texts.get("badge_starter", "Starter"))}
	if availability == CardSchema.AVAILABILITY_REWARD:
		return {"kind": KIND_REWARD, "text": String(texts.get("badge_reward", "Reward"))}
	var unlock: String = String(card.get("unlock", "")).strip_edges()
	if unlock.is_empty():
		unlock = CardSchema.UNLOCK_TBD
	return {"kind": KIND_LOCKED, "text": String(texts.get("badge_locked", "Locked: %s")) % unlock}


## The collection as the screen draws it. `groups` is LoadoutDraft.collection_by_slot (tests pass their own, for example one with a locked card). Each group:
## {slot_type, slot_name, count, required, ok, header, cards: [tile]}; each tile: {id, name, slot_type, rarity, badge_kind, badge_text, copies, max_copies, on_plan, to_plan,
## can_add, can_remove, action_text, flavor}. `to_plan` is true for reward and locked cards: they go on the plan, never in the deck.
static func tiles_for(draft_in: LoadoutDraft, groups: Array[Dictionary], texts: Dictionary) -> Array[Dictionary]:
	var counts: Dictionary = {}
	for entry: Dictionary in draft_in.slot_counts():
		counts[String(entry["slot_type"])] = entry
	var out: Array[Dictionary] = []
	var max_copies: int = LoadoutRules.max_copies()
	for group: Dictionary in groups:
		var slot_type: String = String(group["slot_type"])
		var count_entry: Dictionary = counts.get(slot_type, {})
		var count: int = int(count_entry.get("count", 0))
		var required: int = int(count_entry.get("required", 0))
		var tiles: Array[Dictionary] = []
		for card: Dictionary in (group["cards"] as Array):
			var card_id: String = String(card["id"])
			var badge: Dictionary = badge_for(card, texts)
			var to_plan: bool = String(badge["kind"]) != KIND_STARTER
			var copies: int = draft_in.copies(card_id)
			var on_plan: bool = draft_in.in_plan(card_id)
			var can_add: bool = (not on_plan) if to_plan else (copies < max_copies and draft_in.deck.size() < LoadoutRules.deck_max())
			var action: String = ""
			if to_plan:
				action = String(texts.get("on_plan", "On plan")) if on_plan else String(texts.get("add_plan", "Add to plan"))
			elif copies > 0:
				action = String(texts.get("copies", "x%d")) % copies
			tiles.append({"id": card_id, "name": String(card["name"]), "slot_type": slot_type, "rarity": String(card.get("rarity", "")), "badge_kind": badge["kind"], "badge_text": badge["text"],
					"copies": copies, "max_copies": max_copies, "on_plan": on_plan, "to_plan": to_plan, "can_add": can_add, "can_remove": copies > 0 or on_plan, "action_text": action,
					"flavor": String(card.get("flavor", ""))})
		out.append({"slot_type": slot_type, "slot_name": String(group["slot_name"]), "count": count, "required": required, "ok": count >= required,
				"header": String(texts.get("group_header", "%s  %d/%d")) % [String(group["slot_name"]), count, required], "cards": tiles})
	return out


## The live counts as chips: the deck size first, then every slot ("Movement 4/3"), then any slot group the deck rules define. Each: {label, ok}.
static func chips_for(draft_in: LoadoutDraft, texts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var size: int = draft_in.deck.size()
	out.append({"label": String(texts.get("deck_size", "Deck: %d cards (%d to %d)")) % [size, LoadoutRules.deck_min(), LoadoutRules.deck_max()],
			"ok": size >= LoadoutRules.deck_min() and size <= LoadoutRules.deck_max()})
	var check: DeckCheck = LoadoutCheck.deck_check(draft_in.deck)
	for entry: Dictionary in check.slots:
		out.append({"label": "%s %d/%d" % [String(entry["display_name"]), int(entry["count"]), int(entry["required"])], "ok": int(entry["short"]) <= 0})
	for entry: Dictionary in check.groups:
		out.append({"label": String(texts.get("group_chip", "%s group %d/%d")) % [String(entry["name"]), int(entry["count"]), int(entry["required"])], "ok": int(entry["short"]) <= 0})
	return out


## The slot tabs: [{slot, title, state}] with state "saved", "empty" or "flagged".
static func tabs_for(store: LoadoutStore, for_character: String, texts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(store.slot_count()):
		var entry: Dictionary = store.entry(for_character, i)
		var state: String = "saved"
		var label: String = String(entry.get("name", ""))
		if entry.is_empty():
			state = "flagged" if store.is_flagged(for_character, i) else "empty"
			label = String(texts.get("slot_skipped", "Can't start")) if state == "flagged" else String(texts.get("slot_empty", "Empty"))
		out.append({"slot": i, "title": String(texts.get("slot_title", "%d. %s")) % [i + 1, label], "state": state})
	return out


## The plan as names, in plan order: [{id, name, slot_name, badge_text}].
static func plan_lines_for(draft_in: LoadoutDraft, texts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names: Dictionary = DeckRules.slot_names_from_database()
	for card_id: String in draft_in.plan:
		var card: Dictionary = CardDatabase.get_card(card_id)
		var info: Dictionary = {"availability": LoadoutCollection.availability(card_id), "unlock": CardSchema.unlock_text_of(card)}
		out.append({"id": card_id, "name": String(card.get("name", card_id)), "slot_name": String(names.get(String(card.get("slot_type", "")), "")), "badge_text": String(badge_for(info, texts)["text"])})
	return out


# ---- lifecycle ----

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_texts = RunConfig.ui().get("loadout_editor", {})
	_cfg = UiConfig.run_ui()
	_s = GameOverScreen.ui_scale(get_viewport().get_visible_rect().size.y, float(_cfg["reference_height"]))
	_groups = LoadoutDraft.collection_by_slot(character_id)
	_relic_options = LoadoutDraft.create(character_id, 0).starter_relic_options()
	_effect_ctx = _make_effect_context()
	_build()
	_load_slot(_first_slot())
	_refresh()
	_focus_first_card.call_deferred()


func _first_slot() -> int:
	var usable: Array[int] = _store.usable_indices(character_id)
	var free: Array[int] = _store.free_indices(character_id)
	return free[0] if not free.is_empty() else (usable[0] if not usable.is_empty() else 0)


## Switches to a slot: a usable loadout is loaded, an empty or skipped slot starts from the class's preset deck. Drops unsaved edits; `request_slot` asks first.
func load_slot(index: int) -> void:
	_load_slot(index)
	_ask = ""
	_status = ""
	_refresh()


func _load_slot(index: int) -> void:
	var entry: Dictionary = _store.entry(character_id, index)
	draft = LoadoutDraft.from_entry(character_id, index, entry) if not entry.is_empty() else LoadoutDraft.from_preset(character_id, index)
	if entry.is_empty():
		draft.loadout_name = String(_texts.get("default_name", "Loadout %d")) % (index + 1)
	_baseline = draft.entry()


func _make_effect_context() -> Dictionary:
	var by_id: Dictionary = {}
	var slot_base: Dictionary = {}
	for slot_type: String in SlotTypeDatabase.known_ids():
		slot_base[slot_type] = float(SlotTypeDatabase.get_definition(slot_type).get("base_cooldown", 1.0))
	var statuses: Dictionary = {}
	for group: Dictionary in _groups:
		for card: Dictionary in (group["cards"] as Array):
			var data: Dictionary = CardDatabase.get_card(String(card["id"]))
			by_id[String(card["id"])] = data
			for status_id: String in CardSummary.status_ids(data):
				statuses[status_id] = StatusDatabase.get_status(status_id)
	return {"by_id": by_id, "slot_base": slot_base, "statuses": statuses, "slot_names": DeckRules.slot_names_from_database(), "ui": RunConfig.ui()}


func _focus_first_card() -> void:
	if _card_rows.is_empty() or not is_inside_tree():
		return
	for group: Dictionary in _groups:
		var cards: Array = group["cards"]
		if not cards.is_empty():
			(_card_rows[String(cards[0]["id"])] as Control).grab_focus()
			return


# ---- editing (also the test and script API) ----

## Adds a card (the draft decides deck or plan); returns "" or the refusal, which shows in the status line, never in the checker's reasons.
func add(card_id: String) -> String:
	var refusal: String = draft.add_card(card_id)
	_ask = ""
	_status = refusal
	_refresh()
	return refusal


func remove(card_id: String) -> String:
	var refusal: String = draft.remove_card(card_id)
	_ask = ""
	_status = ""
	_refresh()
	return refusal


func set_loadout_name(text: String) -> void:
	draft.loadout_name = text
	_ask = ""
	_status = ""
	if _name_edit != null and _name_edit.text != text:
		_name_edit.text = text
	_refresh_checks()


## Picks the starter relic by id, "" for none.
func select_relic(relic_id: String) -> void:
	draft.starter_relic = relic_id
	_ask = ""
	_status = ""
	_refresh()


## Saves the draft; blocked (returns the reasons) while a rule is broken. On success the tabs are rebuilt.
func save() -> Array[String]:
	var problems: Array[String] = draft.save(_store)
	_ask = ""
	if problems.is_empty():
		_baseline = draft.entry()
		_status = String(_texts.get("saved_line", "Saved."))
	else:
		_status = ""
	_refresh()
	return problems


## Deletes the current slot's loadout (immediately; `request_delete` asks first).
func delete_current() -> void:
	_store.delete_entry(character_id, draft.slot)
	_load_slot(draft.slot)
	_ask = ""
	_status = String(_texts.get("deleted_line", "Deleted."))
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()


func is_dirty() -> bool:
	return draft != null and draft.entry() != _baseline


## True when the action may go ahead now: nothing to lose, or it was asked twice in a row. Otherwise it arms and shows the warning.
func _confirmed(key: String, warning_key: String) -> bool:
	if key != DELETE_ASK and not is_dirty():
		return true
	if _ask == key:
		return true
	_ask = key
	_status = String(_texts.get(warning_key, ""))
	_refresh_status()
	return false


func request_slot(index: int) -> void:
	if index == draft.slot:
		return
	if _confirmed("slot:%d" % index, "discard_warning"):
		load_slot(index)
		_focus_first_card()


func request_close() -> void:
	if _confirmed(DISCARD_BACK, "discard_warning"):
		close()


func request_delete() -> void:
	if _delete_button.disabled:
		return
	if _confirmed(DELETE_ASK, "delete_warning"):
		delete_current()


# ---- reading it back (tests and captures) ----

func tiles() -> Array[Dictionary]:
	return tiles_for(draft, _groups, _texts)


func chips() -> Array[Dictionary]:
	return chips_for(draft, _texts)


func status_text() -> String:
	return _status


## The checker's reasons as shown in the problems panel (empty when the draft can be saved).
func shown_problems() -> Array[String]:
	return draft.problems()


func card_row(card_id: String) -> Button:
	return _card_rows.get(card_id) as Button


func card_ids() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _card_rows.keys():
		out.append(String(id))
	return out


func save_button() -> Button:
	return _save_button


func delete_button() -> Button:
	return _delete_button


func back_button() -> Button:
	return _back_button


func tab_buttons() -> Array[ChoiceButton]:
	return _tab_buttons


func relic_buttons() -> Array[ChoiceButton]:
	return _relic_buttons


func name_edit() -> LineEdit:
	return _name_edit


func focused_card_id() -> String:
	for id: Variant in _card_rows.keys():
		if (_card_rows[id] as Control).has_focus():
			return String(id)
	return ""


# ---- input ----

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		request_close()
	elif key.keycode == KEY_S and key.ctrl_pressed:
		get_viewport().set_input_as_handled()
		if not _save_button.disabled:
			save()


# ---- building ----

func _color(name: String) -> Color:
	return Color.html(String(_cfg[name]))


func _px(name: String) -> int:
	return roundi(float(_cfg[name]) * _s)


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


func _box(bg: Color, border: Color, border_width: float, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(maxi(roundi(border_width * _s), 1))
	style.set_corner_radius_all(roundi(6.0 * _s))
	style.set_content_margin_all(margin * _s)
	return style


func _panel(inner: Control, margin: float = 8.0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(_color("option_disabled_color"), _color("option_card_border_color"), 1.5, margin))
	panel.add_child(inner)
	return panel


func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.03, 0.05, 1.0)  # opaque: the run's HUD must not show through
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(14.0 * _s))
	_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(8.0 * _s))
	margin.add_child(column)
	column.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi(10.0 * _s))
	column.add_child(body)
	var left: Control = _build_collection()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 3.0
	body.add_child(left)
	var right: Control = _build_side()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 2.0
	body.add_child(right)
	column.add_child(_build_footer())


func _build_header() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(4.0 * _s))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", roundi(12.0 * _s))
	box.add_child(top)
	top.add_child(_label(String(_texts.get("title", "Loadouts")), _px("option_title_font_size"), _color("prompt_title_color")))
	var subtitle: String = String(_texts.get("subtitle", "Editing for %s")) % CharacterDatabase.display_name(character_id)
	top.add_child(_label(subtitle, _px("option_body_font_size"), _color("prompt_text_color")))
	_dirty_tag = _label(String(_texts.get("unsaved_tag", "Unsaved changes")), _px("option_body_font_size"), _color("option_warn_color"))
	_dirty_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dirty_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_dirty_tag)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", roundi(6.0 * _s))
	box.add_child(tabs)
	for tab: Dictionary in tabs_for(_store, character_id, _texts):
		var button := ChoiceButton.new()
		button.setup(String(tab["title"]), _cfg, _s)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(request_slot.bind(int(tab["slot"])))
		tabs.add_child(button)
		_tab_buttons.append(button)
	return box


func _build_collection() -> Control:
	_collection_scroll = ScrollContainer.new()
	_collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_collection_scroll.follow_focus = true
	_collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", roundi(3.0 * _s))
	_collection_scroll.add_child(inner)
	var ring := StyleBoxEmpty.new()
	ring.set_content_margin_all(float(RunOptionCard.focus_ring_width(_cfg, _s)))
	_collection_scroll.add_theme_stylebox_override("panel", ring)
	var small: int = _px("option_small_font_size")
	for group: Dictionary in _groups:
		var slot_type: String = String(group["slot_type"])
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", roundi(6.0 * _s))
		var mark := RunTypeIcon.new()
		mark.custom_minimum_size = Vector2.ONE * float(_px("option_body_font_size")) * 0.9
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(mark)
		var header := _label("", _px("option_body_font_size"), _color("prompt_title_color"))
		head.add_child(header)
		var head_box := MarginContainer.new()
		head_box.add_theme_constant_override("margin_top", roundi(6.0 * _s))
		head_box.add_child(head)
		inner.add_child(head_box)
		_group_headers[slot_type] = header
		_group_marks[slot_type] = mark
		for card: Dictionary in (group["cards"] as Array):
			var row := CardRow.new()
			row.setup(String(card["name"]), _cfg, _s)
			row.pressed.connect(_on_row_pressed.bind(String(card["id"])))
			row.remove_requested.connect(remove.bind(String(card["id"])))
			row.focus_entered.connect(_show_detail.bind(String(card["id"])))
			row.mouse_entered.connect(_show_detail.bind(String(card["id"])))  # a mouse user reads a card without adding it; hover never moves the focus
			inner.add_child(row)
			_card_rows[String(card["id"])] = row
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(6.0 * _s))
	column.add_child(_collection_scroll)
	_detail_name = _label("", _px("option_body_font_size"), Color.html("#ffffff"))
	_detail_text = _label("", small, _color("prompt_text_color"), 300.0 * _s)
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail := VBoxContainer.new()
	detail.add_child(_detail_name)
	detail.add_child(_detail_text)
	column.add_child(_panel(detail, 6.0))
	return column


func _build_side() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var ring := StyleBoxEmpty.new()
	ring.set_content_margin_all(float(RunOptionCard.focus_ring_width(_cfg, _s)))
	scroll.add_theme_stylebox_override("panel", ring)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", roundi(8.0 * _s))
	scroll.add_child(column)
	var body_px: int = _px("option_body_font_size")
	var small: int = _px("option_small_font_size")
	var muted: Color = _color("option_flavor_color")
	# the problems come first: they are what stops a save
	_problems_box = VBoxContainer.new()
	_problems_box.add_theme_constant_override("separation", roundi(3.0 * _s))
	column.add_child(_panel(_problems_box))
	# name
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", roundi(8.0 * _s))
	name_row.add_child(_label(String(_texts.get("name_label", "Name")), body_px, _color("prompt_text_color")))
	_name_edit = LineEdit.new()
	_name_edit.max_length = LoadoutRules.name_max_length()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", body_px)
	_name_edit.text_changed.connect(set_loadout_name)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _focus_first_card())
	name_row.add_child(_name_edit)
	_name_count = _label("", small, muted)
	name_row.add_child(_name_count)
	column.add_child(name_row)
	# starter relic
	column.add_child(_label(String(_texts.get("relic_label", "Starter relic")), body_px, _color("prompt_text_color")))
	var relics := VBoxContainer.new()  # stacked, so a relic's whole name fits
	relics.add_theme_constant_override("separation", roundi(4.0 * _s))
	column.add_child(relics)
	var none_button := ChoiceButton.new()
	none_button.setup(String(_texts.get("relic_none", "No relic")), _cfg, _s)
	none_button.pressed.connect(select_relic.bind(""))
	none_button.set_meta("relic", "")
	relics.add_child(none_button)
	_relic_buttons.append(none_button)
	for option: Dictionary in _relic_options:
		var button := ChoiceButton.new()
		button.setup(String(option["name"]), _cfg, _s)
		button.pressed.connect(select_relic.bind(String(option["id"])))
		button.set_meta("relic", String(option["id"]))
		relics.add_child(button)
		_relic_buttons.append(button)
	_relic_detail = _label("", small, muted, 240.0 * _s)
	_relic_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_relic_detail)
	# counts
	column.add_child(_label(String(_texts.get("counts_title", "")), small, muted, 240.0 * _s))
	_chips_box = HFlowContainer.new()
	_chips_box.add_theme_constant_override("h_separation", roundi(6.0 * _s))
	_chips_box.add_theme_constant_override("v_separation", roundi(6.0 * _s))
	column.add_child(_chips_box)
	# plan
	_plan_box = VBoxContainer.new()
	_plan_box.add_theme_constant_override("separation", roundi(2.0 * _s))
	column.add_child(_panel(_plan_box))
	return scroll


func _build_footer() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(4.0 * _s))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(8.0 * _s))
	box.add_child(row)
	_status_label = _label("", _px("option_body_font_size"), _color("option_warn_color"))
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	row.add_child(_status_label)
	_save_button = _footer_button(String(_texts.get("save", "Save")), save)
	row.add_child(_save_button)
	_delete_button = _footer_button(String(_texts.get("delete", "Delete")), request_delete)
	row.add_child(_delete_button)
	_back_button = _footer_button(String(_texts.get("back", "Back")), request_close)
	row.add_child(_back_button)
	var hint := _label(String(_texts.get("hint", "")), _px("prompt_hint_font_size"), _color("option_flavor_color"))
	hint.clip_text = true
	box.add_child(hint)
	return box


func _footer_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", _px("option_body_font_size"))
	button.custom_minimum_size = Vector2(96.0 * _s, 0.0)
	var focus: StyleBoxFlat = _box(_color("option_card_hover_color"), _color("option_focus_color"), float(_cfg["option_focus_width"]), 6.0)
	button.add_theme_stylebox_override("normal", _box(_color("option_card_color"), _color("option_card_border_color"), 1.5, 6.0))
	button.add_theme_stylebox_override("hover", _box(_color("option_card_hover_color"), _color("option_card_border_color"), 1.5, 6.0))
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	button.add_theme_stylebox_override("disabled", _box(_color("option_disabled_color"), _color("option_disabled_color"), 1.0, 6.0))
	button.add_theme_color_override("font_disabled_color", _color("option_disabled_text_color"))
	button.pressed.connect(callback)
	return button


# ---- refreshing ----

func _on_row_pressed(card_id: String) -> void:
	add(card_id)


func _refresh() -> void:
	if _name_edit == null or draft == null:
		return
	if _name_edit.text != draft.loadout_name:
		_name_edit.text = draft.loadout_name
	for tile_group: Dictionary in tiles():
		var slot_type: String = String(tile_group["slot_type"])
		(_group_headers[slot_type] as Label).text = String(tile_group["header"])
		var mark := _group_marks[slot_type] as RunTypeIcon
		mark.shape = RunIcons.SHAPE_CHECK if bool(tile_group["ok"]) else RunIcons.SHAPE_X
		mark.color = _color("option_accent_color") if bool(tile_group["ok"]) else _color("option_warn_color")
		for tile: Dictionary in (tile_group["cards"] as Array):
			(_card_rows[String(tile["id"])] as CardRow).show_tile(tile)
	var tabs: Array[Dictionary] = tabs_for(_store, character_id, _texts)
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].set_title(String(tabs[i]["title"]))
		_tab_buttons[i].set_selected(i == draft.slot)
	for button in _relic_buttons:
		button.set_selected(String(button.get_meta("relic")) == draft.starter_relic)
	_refresh_checks()


func _refresh_checks() -> void:
	_name_count.text = String(_texts.get("name_count", "%d/%d")) % [draft.loadout_name.length(), LoadoutRules.name_max_length()]
	_relic_detail.text = String(_texts.get("relic_none_detail", ""))
	for option: Dictionary in _relic_options:
		if String(option["id"]) == draft.starter_relic:
			_relic_detail.text = String(option["rule_text"])
	_fill_chips()
	_fill_plan()
	var problems: Array[String] = draft.problems()
	_fill_problems(problems)
	_save_button.disabled = not problems.is_empty()
	_delete_button.disabled = _store.entry(character_id, draft.slot).is_empty() and not _store.is_flagged(character_id, draft.slot)
	_dirty_tag.visible = is_dirty()
	_refresh_status()


func _refresh_status() -> void:
	if _status_label != null:
		_status_label.text = _status


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _fill_chips() -> void:
	_clear(_chips_box)
	var small: int = _px("option_small_font_size")
	for chip: Dictionary in chips():
		var ok: bool = bool(chip["ok"])
		var tint: Color = _color("option_accent_color") if ok else _color("option_warn_color")
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", _box(Color(0.0, 0.0, 0.0, 0.0), tint, 1.5, 3.0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", roundi(4.0 * _s))
		pill.add_child(row)
		var mark := RunTypeIcon.new()
		mark.shape = RunIcons.SHAPE_CHECK if ok else RunIcons.SHAPE_X
		mark.color = tint
		mark.custom_minimum_size = Vector2.ONE * float(small) * 0.9
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		row.add_child(_label(String(chip["label"]), small, _color("prompt_text_color")))
		_chips_box.add_child(pill)


func _fill_plan() -> void:
	_clear(_plan_box)
	var small: int = _px("option_small_font_size")
	var lines: Array[Dictionary] = plan_lines_for(draft, _texts)
	_plan_box.add_child(_label(String(_texts.get("plan_title", "Plan: %d")) % lines.size(), _px("option_body_font_size"), _color("prompt_title_color")))
	if lines.is_empty():
		_plan_box.add_child(_label(String(_texts.get("plan_empty", "")), small, _color("option_flavor_color"), 240.0 * _s))
	for line: Dictionary in lines:
		_plan_box.add_child(_label("%s  (%s, %s)" % [String(line["name"]), String(line["slot_name"]), String(line["badge_text"])], small, _color("prompt_text_color"), 240.0 * _s))


func _fill_problems(problems: Array[String]) -> void:
	_clear(_problems_box)
	var ok: bool = problems.is_empty()
	var tint: Color = _color("option_accent_color") if ok else _color("option_warn_color")
	var body_px: int = _px("option_body_font_size")
	var small: int = _px("option_small_font_size")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", roundi(6.0 * _s))
	var mark := RunTypeIcon.new()
	mark.shape = RunIcons.SHAPE_CHECK if ok else RunIcons.SHAPE_X
	mark.color = tint
	mark.custom_minimum_size = Vector2.ONE * float(body_px) * 0.9
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	head.add_child(_label(String(_texts.get("ok_line", "Ready to save.")) if ok else String(_texts.get("problems_title", "Can't save yet")), body_px, tint))
	_problems_box.add_child(head)
	for problem: String in problems:
		_problems_box.add_child(_label(problem, small, _color("prompt_text_color"), 240.0 * _s))


func _show_detail(card_id: String) -> void:
	var tile: Dictionary = {}
	for tile_group: Dictionary in tiles():
		for candidate: Dictionary in (tile_group["cards"] as Array):
			if String(candidate["id"]) == card_id:
				tile = candidate
	if tile.is_empty():
		return
	var option: Dictionary = RunChoices.card_option(card_id, "card", card_id, _effect_ctx)
	_detail_name.text = "%s  -  %s" % [String(tile["name"]), String(tile["badge_text"])]
	var parts: Array[String] = []
	if not String(option["detail"]).is_empty():
		parts.append(String(option["detail"]))
	if not String(tile["flavor"]).is_empty():
		parts.append(String(tile["flavor"]))
	_detail_text.text = "\n".join(PackedStringArray(parts))


# ---- parts ----

## A button with a check mark that shows when it is the selected one (the slot tabs and the relic pick). Selected is shape and thick outline, never colour alone.
class ChoiceButton extends Button:
	var mark: Control = null
	var title_label: Label = null
	var _cfg: Dictionary = {}
	var _s: float = 1.0
	var _selected: bool = false

	func setup(title: String, cfg: Dictionary, s: float) -> void:
		_cfg = cfg
		_s = s
		focus_mode = Control.FOCUS_ALL
		var font_px: int = roundi(float(cfg["option_body_font_size"]) * s)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", roundi(5.0 * s))
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var pad: float = 6.0 * s
		row.offset_left = pad
		row.offset_right = -pad
		row.offset_top = 2.0 * s
		row.offset_bottom = -2.0 * s
		add_child(row)
		mark = RunTypeIcon.new()
		mark.shape = RunIcons.SHAPE_CHECK
		mark.color = Color.html(String(cfg["option_accent_color"]))
		mark.custom_minimum_size = Vector2.ONE * float(font_px) * 0.9
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.modulate.a = 0.0
		row.add_child(mark)
		title_label = Label.new()
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.clip_text = true
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.add_theme_font_size_override("font_size", font_px)
		row.add_child(title_label)
		set_title(title)
		custom_minimum_size.y = float(font_px) * 1.5 + 4.0 * s
		_apply_styles()

	func set_title(title: String) -> void:
		title_label.text = title
		tooltip_text = title

	func set_selected(value: bool) -> void:
		_selected = value
		mark.modulate.a = 1.0 if value else 0.0
		_apply_styles()

	func _apply_styles() -> void:
		var width: float = maxf(1.5 * _s, 1.0)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.html(String(_cfg["option_card_color"]))
		normal.border_color = Color.html(String(_cfg["option_accent_color"])) if _selected else Color.html(String(_cfg["option_card_border_color"]))
		normal.set_border_width_all(roundi(width * 1.5) if _selected else roundi(width))
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


## One card of the collection: name, badge (a shape and the words), and on the right its copies (x2) or its plan state, plus a remove mark for the mouse.
## Enter or a click adds; Delete, Minus, Backspace or a right click removes. Hover does not move the focus, so a scrolled list never jumps under the mouse.
class CardRow extends Button:
	signal remove_requested()

	var tile: Dictionary = {}
	var name_label_text: String = ""
	var name_label: Label = null
	var action_label: Label = null
	var badge: PanelContainer = null
	var badge_icon: RunTypeIcon = null
	var badge_label: Label = null
	var minus: Button = null
	var _cfg: Dictionary = {}
	var _s: float = 1.0

	func setup(title: String, cfg: Dictionary, s: float) -> void:
		name_label_text = title
		_cfg = cfg
		_s = s
		focus_mode = Control.FOCUS_ALL
		var body_px: int = roundi(float(cfg["option_body_font_size"]) * s)
		var small_px: int = roundi(float(cfg["option_small_font_size"]) * s)
		custom_minimum_size.y = float(body_px) * 1.5 + 6.0 * s
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", roundi(8.0 * s))
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8.0 * s
		row.offset_right = -6.0 * s
		row.offset_top = 2.0 * s
		row.offset_bottom = -2.0 * s
		add_child(row)
		name_label = Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", body_px)
		name_label.add_theme_color_override("font_color", Color.html("#ffffff"))
		row.add_child(name_label)
		badge = PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var badge_row := HBoxContainer.new()
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_row.add_theme_constant_override("separation", roundi(4.0 * s))
		badge.add_child(badge_row)
		badge_icon = RunTypeIcon.new()
		badge_icon.custom_minimum_size = Vector2.ONE * float(small_px) * 0.9
		badge_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge_row.add_child(badge_icon)
		badge_label = Label.new()
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_label.add_theme_font_size_override("font_size", small_px)
		badge_row.add_child(badge_label)
		row.add_child(badge)
		action_label = Label.new()
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		action_label.custom_minimum_size.x = float(small_px) * 5.2
		action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		action_label.add_theme_font_size_override("font_size", small_px)
		row.add_child(action_label)
		minus = Button.new()
		minus.text = "-"
		minus.focus_mode = Control.FOCUS_NONE
		minus.custom_minimum_size = Vector2(float(body_px) * 1.4, 0.0)
		minus.add_theme_font_size_override("font_size", body_px)
		minus.pressed.connect(func() -> void: remove_requested.emit())
		row.add_child(minus)
		_apply_styles()
		gui_input.connect(_on_gui_input)
		name_label.text = name_label_text

	func show_tile(new_tile: Dictionary) -> void:
		tile = new_tile
		name_label.text = String(tile["name"])
		var kind: String = String(tile["badge_kind"])
		var accent: Color = Color.html(String(_cfg["option_accent_color"]))
		var gold: Color = Color.html(String(_cfg["option_focus_color"]))
		var muted: Color = Color.html(String(_cfg["option_disabled_text_color"]))
		var quiet: Color = Color.html(String(_cfg["option_flavor_color"]))  # Starter is the plain case: neutral and a circle. Green with a check is kept for "On your plan" (sitting D)
		var tint: Color = quiet if kind == LoadoutEditorScreen.KIND_STARTER else (gold if kind == LoadoutEditorScreen.KIND_REWARD else muted)
		badge_icon.shape = RunIcons.SHAPE_CIRCLE if kind == LoadoutEditorScreen.KIND_STARTER else (RunIcons.SHAPE_STAR if kind == LoadoutEditorScreen.KIND_REWARD else RunIcons.SHAPE_SQUARE)
		badge_icon.color = tint
		badge_label.text = String(tile["badge_text"])
		badge_label.add_theme_color_override("font_color", tint)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style.border_color = tint
		style.set_border_width_all(maxi(roundi(1.5 * _s), 1))
		style.set_corner_radius_all(roundi(9.0 * _s))
		style.content_margin_left = 6.0 * _s
		style.content_margin_right = 7.0 * _s
		style.content_margin_top = 1.0 * _s
		style.content_margin_bottom = 1.0 * _s
		badge.add_theme_stylebox_override("panel", style)
		action_label.text = String(tile["action_text"])
		var held: bool = int(tile["copies"]) > 0 or bool(tile["on_plan"])
		action_label.add_theme_color_override("font_color", accent if held else Color.html(String(_cfg["option_flavor_color"])))
		minus.modulate.a = 1.0 if bool(tile["can_remove"]) else 0.0  # keeps its room, so the badges line up
		minus.mouse_filter = Control.MOUSE_FILTER_STOP if bool(tile["can_remove"]) else Control.MOUSE_FILTER_IGNORE
		tooltip_text = String(tile["name"])

	func _on_gui_input(event: InputEvent) -> void:
		var mouse := event as InputEventMouseButton
		if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			remove_requested.emit()
			return
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo and (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE or key.keycode == KEY_MINUS or key.keycode == KEY_KP_SUBTRACT):
			accept_event()
			remove_requested.emit()

	func _apply_styles() -> void:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color.html(String(_cfg["option_card_color"]))
		normal.border_color = Color.html(String(_cfg["option_card_border_color"]))
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(roundi(5.0 * _s))
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
