class_name LoadoutEditorScreen
extends CanvasLayer
## PLACEHOLDER loadout editor (3d sitting C; ux-designer replaces it in sitting E). A bare screen over a LoadoutDraft: pick a loadout slot, add and remove cards, name it, pick a
## starter relic, save. Saving is blocked while the draft breaks a rule, and the reasons (the checker's own messages) show live. All logic is LoadoutDraft's; this only draws it,
## so ux's editor calls the same methods (`add_card`, `remove_card`, `slot_counts`, `size_text`, `problems`, `save`, `collection_by_slot`, `starter_relic_options`).

signal closed()

var character_id: String = ""
var draft: LoadoutDraft = null

var _store: LoadoutStore = null
var _slot_pick: OptionButton = null
var _name_edit: LineEdit = null
var _relic_pick: OptionButton = null
var _collection_list: ItemList = null
var _mine_list: ItemList = null
var _counts_label: Label = null
var _problems_label: Label = null
var _save_button: Button = null
var _delete_button: Button = null
var _relic_ids: Array[String] = []


func setup(for_character: String, store: LoadoutStore) -> void:
	character_id = for_character
	_store = store


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load_slot(_first_slot())
	_refresh()


func _first_slot() -> int:
	var usable: Array[int] = _store.usable_indices(character_id)
	var free: Array[int] = _store.free_indices(character_id)
	return free[0] if not free.is_empty() else (usable[0] if not usable.is_empty() else 0)


## Switches to a slot: a usable loadout is loaded, an empty or flagged slot starts from the preset deck.
func load_slot(index: int) -> void:
	_load_slot(index)
	_slot_pick.select(index)
	_refresh()


func _load_slot(index: int) -> void:
	var entry: Dictionary = _store.entry(character_id, index)
	draft = LoadoutDraft.from_entry(character_id, index, entry) if not entry.is_empty() else LoadoutDraft.from_preset(character_id, index)
	if entry.is_empty():
		draft.loadout_name = "Loadout %d" % (index + 1)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.05, 0.05, 0.08, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	root.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_slot_pick = OptionButton.new()
	for i in range(_store.slot_count()):
		var existing: Dictionary = _store.entry(character_id, i)
		_slot_pick.add_item("Loadout %d: %s" % [i + 1, String(existing["name"]) if not existing.is_empty() else ("(skipped)" if _store.is_flagged(character_id, i) else "(empty)")])
	_slot_pick.item_selected.connect(load_slot)
	top.add_child(_slot_pick)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name"
	_name_edit.max_length = LoadoutRules.name_max_length()
	_name_edit.custom_minimum_size = Vector2(220.0, 0.0)
	_name_edit.text_changed.connect(_on_name_changed)
	top.add_child(_name_edit)
	_relic_pick = OptionButton.new()
	_relic_pick.add_item("No starter relic")
	_relic_ids = [""]
	for option: Dictionary in LoadoutDraft.create(character_id, 0).starter_relic_options():
		_relic_pick.add_item("%s: %s" % [String(option["name"]), String(option["rule_text"])])
		_relic_ids.append(String(option["id"]))
	_relic_pick.item_selected.connect(_on_relic_selected)
	top.add_child(_relic_pick)
	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(lists)
	_collection_list = ItemList.new()
	_collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_list.item_activated.connect(_on_collection_activated)
	lists.add_child(_collection_list)
	_mine_list = ItemList.new()
	_mine_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mine_list.item_activated.connect(_on_mine_activated)
	lists.add_child(_mine_list)
	_counts_label = Label.new()
	column.add_child(_counts_label)
	_problems_label = Label.new()
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problems_label.modulate = Color(1.0, 0.6, 0.5)
	column.add_child(_problems_label)
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.pressed.connect(save)
	bottom.add_child(_save_button)
	_delete_button = Button.new()
	_delete_button.text = "Delete"
	_delete_button.pressed.connect(delete_current)
	bottom.add_child(_delete_button)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	bottom.add_child(back)
	var hint := Label.new()
	hint.text = "Enter or double-click a card in the collection adds it (a starter card to the deck, other cards to the plan); in the loadout list it removes one."
	column.add_child(hint)


func _refresh() -> void:
	if _name_edit == null or draft == null:
		return
	_name_edit.text = draft.loadout_name
	_relic_pick.select(maxi(_relic_ids.find(draft.starter_relic), 0))
	_collection_list.clear()
	for group: Dictionary in LoadoutDraft.collection_by_slot(character_id):
		for card: Dictionary in (group["cards"] as Array):
			var availability: String = String(card["availability"])
			var badge: String = "Starter" if availability == CardSchema.AVAILABILITY_STARTER else ("Reward" if availability == CardSchema.AVAILABILITY_REWARD else "Locked: " + String(card["unlock"]))
			var line: String = "%s | %s [%s]" % [String(group["slot_name"]), String(card["name"]), badge]
			if draft.copies(String(card["id"])) > 0:
				line += " x%d" % draft.copies(String(card["id"]))
			elif draft.in_plan(String(card["id"])):
				line += " (on plan)"
			var index: int = _collection_list.add_item(line)
			_collection_list.set_item_metadata(index, String(card["id"]))
	_refresh_mine()
	_refresh_checks()


func _refresh_mine() -> void:
	_mine_list.clear()
	var seen: Array[String] = []
	for card_id: String in draft.deck:
		if seen.has(card_id):
			continue
		seen.append(card_id)
		var index: int = _mine_list.add_item("%s x%d" % [String(CardDatabase.get_card(card_id).get("name", card_id)), draft.copies(card_id)])
		_mine_list.set_item_metadata(index, card_id)
	for card_id: String in draft.plan:
		var index: int = _mine_list.add_item("Plan: %s" % String(CardDatabase.get_card(card_id).get("name", card_id)))
		_mine_list.set_item_metadata(index, card_id)


func _refresh_checks() -> void:
	var parts: Array[String] = [draft.size_text()]
	for entry: Dictionary in draft.slot_counts():
		parts.append("%s %d/%d" % [String(entry["display_name"]), int(entry["count"]), int(entry["required"])])
	_counts_label.text = "  |  ".join(PackedStringArray(parts))
	var problems: Array[String] = draft.problems()
	_problems_label.text = "\n".join(PackedStringArray(problems))
	_save_button.disabled = not problems.is_empty()
	_delete_button.disabled = _store.entry(character_id, draft.slot).is_empty() and not _store.is_flagged(character_id, draft.slot)


func _on_name_changed(text: String) -> void:
	draft.loadout_name = text
	_refresh_checks()


func _on_relic_selected(index: int) -> void:
	draft.starter_relic = _relic_ids[index]
	_refresh_checks()


func _on_collection_activated(index: int) -> void:
	add(String(_collection_list.get_item_metadata(index)))


func _on_mine_activated(index: int) -> void:
	remove(String(_mine_list.get_item_metadata(index)))


## Adds a card (the draft decides deck or plan); returns "" or the refusal, which also shows in the problems line.
func add(card_id: String) -> String:
	var refusal: String = draft.add_card(card_id)
	_refresh()
	if not refusal.is_empty():
		_problems_label.text = refusal
	return refusal


func remove(card_id: String) -> String:
	var refusal: String = draft.remove_card(card_id)
	_refresh()
	return refusal


## Saves the draft; blocked (returns the reasons) while a rule is broken. On success the list of slots is rebuilt.
func save() -> Array[String]:
	var problems: Array[String] = draft.save(_store)
	if problems.is_empty():
		_slot_pick.set_item_text(draft.slot, "Loadout %d: %s" % [draft.slot + 1, draft.loadout_name.strip_edges()])
	else:
		_problems_label.text = "\n".join(PackedStringArray(problems))
	_refresh_checks()
	return problems


func delete_current() -> void:
	_store.delete_entry(character_id, draft.slot)
	_slot_pick.set_item_text(draft.slot, "Loadout %d: (empty)" % (draft.slot + 1))
	_load_slot(draft.slot)
	_refresh()


func close() -> void:
	closed.emit()
	queue_free()
