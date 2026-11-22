class_name Sim2a4QaTest
extends GdUnitTestSuite
## qa (SIM2a-4): strengthens the removal-pick test. The rule must be the only reason a starter is not picked: the same offer, deck and state give "remove:<starter>"
## with no starters known and "back" with the starters known. Card ids are read from data, never named.


func before_test() -> void:
	FormulatedBot.off = {}


func after_test() -> void:
	FormulatedBot.off = {}


func _non_starter_of_slot(slot: String, start: Array[String]) -> String:
	for card: Dictionary in CardDatabase.all_cards():
		var card_id: String = String(card.get("id", ""))
		if String(card.get("slot_type", "")) == slot and not start.has(card_id) and not CardSchema.is_curse(card):
			return card_id
	return ""


func test_the_starter_guard_alone_turns_a_removal_into_back() -> void:
	var cases: int = 0
	for character: String in ["rogue", "wizard"]:
		var start: Array[String] = CharacterDatabase.starting_deck(character)
		var tested: Dictionary = {}
		for starter: String in start:
			if tested.has(starter):
				continue
			tested[starter] = true
			var slot: String = String(CardDatabase.get_card(starter).get("slot_type", ""))
			var other: String = _non_starter_of_slot(slot, start)
			if other == "":
				continue
			var deck: Array[String] = start.duplicate()
			deck.append(other)  # the slot has a second card, so only the starter rule can stop the removal
			var state := RunState.new_run(1, deck, 3)
			state.deck = deck.duplicate()
			var options: Array = [{"id": "remove:" + starter, "kind": "remove", "card_id": starter, "enabled": true, "curse": false, "count": 1}, {"id": "back", "kind": "back"}]
			if deck.count(starter) > start.count(starter):
				continue
			assert_bool(FormulatedShop.is_last_of_slot(starter, deck)).is_false()
			assert_str(FormulatedShop.removal_choice(options, state)).is_equal("remove:" + starter)
			assert_str(FormulatedShop.removal_choice(options, state, start)).is_equal("back")
			assert_array(FormulatedShop.lowest_card([starter] as Array[String], start)).is_equal(["", INF])
			cases += 1
	assert_int(cases).is_greater(0)


func test_an_extra_copy_of_a_starter_can_go() -> void:
	var start: Array[String] = CharacterDatabase.starting_deck("wizard")
	var starter: String = start[0]
	var deck: Array[String] = start.duplicate()
	deck.append(starter)
	var state := RunState.new_run(1, deck, 3)
	state.deck = deck.duplicate()
	var options: Array = [{"id": "remove:" + starter, "kind": "remove", "card_id": starter, "enabled": true, "curse": false, "count": 1}, {"id": "back", "kind": "back"}]
	assert_str(FormulatedShop.removal_choice(options, state, start)).is_equal("remove:" + starter)
