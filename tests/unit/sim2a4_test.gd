class_name Sim2a4Test
extends GdUnitTestSuite
## SIM2a-4: the formulated removal guards (last card of a slot type is never removed; starters valued on their own terms), the -FormulatedOff parse, and the run-line route/off label.
## Slot types are read from card data here, never named.


func before_test() -> void:
	FormulatedBot.off = {}


func after_test() -> void:
	FormulatedBot.off = {}


func _slot(card_id: String) -> String:
	return String(CardDatabase.get_card(card_id).get("slot_type", ""))


## [deck, lone_id]: the wizard starting deck with every card of one slot type that has a single copy kept, or a built deck when none does.
func _deck_with_a_lone_slot() -> Array:
	var start: Array[String] = CharacterDatabase.starting_deck("wizard")
	var per_slot: Dictionary = {}
	for card_id: String in start:
		per_slot[_slot(card_id)] = int(per_slot.get(_slot(card_id), 0)) + 1
	var lone_slot: String = ""
	for slot: String in per_slot:
		if int(per_slot[slot]) == 1:
			lone_slot = slot
			break
	if lone_slot != "":
		for card_id: String in start:
			if _slot(card_id) == lone_slot:
				return [start.duplicate(), card_id]
	# No singleton slot in the starter deck: drop all but one card of the least common slot.
	var least: String = ""
	for slot: String in per_slot:
		if least == "" or int(per_slot[slot]) < int(per_slot[least]):
			least = slot
	var deck: Array[String] = []
	var lone: String = ""
	for card_id: String in start:
		if _slot(card_id) == least:
			if lone != "":
				continue
			lone = card_id
		deck.append(card_id)
	return [deck, lone]


func _state(deck: Array[String]) -> RunState:
	var state := RunState.new_run(1, deck, 3)
	state.deck = deck.duplicate()
	state.gold = 200
	return state


func _remove_option(card_id: String) -> Dictionary:
	return {"id": "remove:" + card_id, "kind": "remove", "card_id": card_id, "enabled": true, "curse": false, "count": 1}


func test_the_last_card_of_a_slot_type_is_never_removed() -> void:
	var made: Array = _deck_with_a_lone_slot()
	var deck: Array[String] = made[0]
	var lone: String = String(made[1])
	assert_bool(FormulatedShop.is_last_of_slot(lone, deck)).is_true()
	assert_str(String(FormulatedShop.lowest_card(deck)[0])).is_not_equal(lone)
	# The list offers only the lone card: the bot backs out instead.
	var options: Array = [_remove_option(lone), {"id": "back", "kind": "back"}]
	assert_str(FormulatedShop.removal_choice(options, _state(deck))).is_equal("back")
	# A second card of that slot lifts the guard for that slot.
	var more: Array[String] = deck.duplicate()
	more.append(lone)
	assert_bool(FormulatedShop.is_last_of_slot(lone, more)).is_false()


func test_a_curse_is_never_guarded() -> void:
	var made: Array = _deck_with_a_lone_slot()
	var deck: Array[String] = made[0]
	var options: Array = [{"id": "remove:curse_x", "kind": "remove", "card_id": String(made[1]), "enabled": true, "curse": true, "count": 1}, {"id": "back", "kind": "back"}]
	assert_str(FormulatedShop.removal_choice(options, _state(deck))).is_equal("remove:curse_x")


func test_the_merchant_removal_margin_skips_a_guarded_deck() -> void:
	# A deck of one card per slot type: nothing may go, so the merchant removal is never bought however big the deck bar is.
	var one_each: Array[String] = []
	var seen: Dictionary = {}
	for card_id: String in CharacterDatabase.starting_deck("wizard"):
		if not seen.has(_slot(card_id)):
			seen[_slot(card_id)] = true
			one_each.append(card_id)
	assert_float(float(FormulatedShop.lowest_card(one_each)[1])).is_equal(INF)
	assert_str(String(FormulatedShop.lowest_card(one_each)[0])).is_equal("")


func test_a_starter_is_valued_on_its_own_terms() -> void:
	# For every starter the value with the starting deck passed is never below the value without it.
	for character: String in ["rogue", "wizard"]:
		var start: Array[String] = CharacterDatabase.starting_deck(character)
		for card_id: String in start:
			assert_float(FormulatedShop.card_value(card_id, start, start)).is_greater_equal(FormulatedShop.card_value(card_id, start))
	# A starter dropped into a deck of another build is scored at least as well as with no starters known.
	var foreign: Array[String] = CharacterDatabase.starting_deck("rogue")
	var starters: Array[String] = CharacterDatabase.starting_deck("wizard")
	for card_id: String in starters:
		assert_float(FormulatedShop.card_value(card_id, foreign, starters)).is_greater_equal(FormulatedShop.card_value(card_id, foreign))


func test_the_removal_code_names_no_card_ids() -> void:
	var text: String = FileAccess.get_file_as_string("res://src/debug/FormulatedShop.gd")
	var regex := RegEx.new()
	regex.compile("\"(rogue|wizard|fire|neutral|water)_[a-z_]+\"")
	assert_object(regex.search(text)).is_null()


func test_the_formulated_off_parse_rejects_an_unknown_part() -> void:
	assert_str(String(FormulatedBot.parse_off("shop,removal")["error"])).is_equal("")
	assert_dict(FormulatedBot.parse_off("shop,removal")["off"] as Dictionary).has_size(2)
	assert_str(String(FormulatedBot.parse_off("shop,route")["error"])).is_not_empty()
	assert_dict(FormulatedBot.parse_off("route")["off"] as Dictionary).is_empty()
	assert_str(String(FormulatedBot.parse_off("")["error"])).is_not_empty()  # an empty part is not a switch name


func test_the_off_label_is_stable() -> void:
	assert_str(FormulatedBot.off_label()).is_equal("none")
	FormulatedBot.off = {"shop": true, "removal": true}
	assert_str(FormulatedBot.off_label()).is_equal("removal+shop")
