class_name D47PrunedTest
extends GdUnitTestSuite
## D47 = B (GDD 9, "Pruned cards stay gone"): a card removed from the deck (rest room, merchant) is never offered again that run, in card offers or the
## merchant's stock. Saved in RunState.removed_cards; an old save without the key reads as empty; dry pools give a short or empty offer.

const PATH := "user://tests/d47_run_save.json"


func before_test() -> void:
	RunSession.acts_override = 1
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.acts_override = 0
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()


func _ctx() -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools("rogue"))


func _full_state(seed_value: int) -> RunState:
	var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3, "rogue")
	state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools("rogue"))
	state.deck.append_array(RunConfig.cards_in_pools(CharacterDatabase.pools("rogue")))  # two copies of each, so any one can go
	state.hp = 20.0
	state.max_hp = 30.0
	state.room_index = 3
	return state


func _offers_over_seeds(removed_id: String, use_removed: bool, count: int) -> int:
	var ctx: Dictionary = _ctx()
	var hits: int = 0
	for run_seed in range(1, 1 + count):
		var state: RunState = _full_state(run_seed)
		if use_removed:
			state.record_removal(removed_id)
		state.room_index = run_seed % 9
		RunChoices.open_for_room(state, "combat", false, ctx)
		hits += 1 if state.offer.has(removed_id) else 0
	return hits


func test_a_card_removed_at_a_rest_is_never_offered_again() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _full_state(11)
	var target: String = state.deck[0]
	state.pending = RunState.PENDING_REST
	assert_bool(bool(RunChoices.apply(state, "remove_menu", ctx)["ok"])).is_true()
	assert_bool(bool(RunChoices.apply(state, "remove:" + target, ctx)["ok"])).is_true()
	assert_array(state.removed_cards).contains_exactly([target])
	# Control: unmarked (and still owned, 2 copies) it turns up over these seeds; marked, it never does.
	assert_int(_offers_over_seeds(target, false, 400)).is_greater(0)
	assert_int(_offers_over_seeds(target, true, 400)).is_equal(0)


func test_a_card_removed_at_the_merchant_is_not_in_its_stock() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _full_state(21)
	state.gold = 1000
	assert_str(RunChoices.open_for_room(state, "merchant", false, ctx)).is_equal(RunState.PENDING_MERCHANT)
	var target: String = state.deck[3]
	var bought: Dictionary = Merchant.buy_removal(state, target, ctx)
	assert_bool(bool(bought["ok"])).is_true()
	assert_array(state.removed_cards).contains_exactly([target])
	# A copy already on the shelf went when it was removed; every later stock (120 nodes, 2 rerolls) leaves it out.
	assert_bool((state.merchant_visit["cards"] as Array).has(target)).is_false()
	var seen_without: int = 0
	var seen_with: int = 0
	for node_id in range(1, 121):
		for reroll in range(2):
			var fresh: Dictionary = Merchant.draw_stock(state, node_id, reroll, ctx, [] as Array[String], [] as Array[String])
			seen_with += 1 if (fresh["cards"] as Array).has(target) else 0
			var plain: RunState = _full_state(21)
			var control: Dictionary = Merchant.draw_stock(plain, node_id, reroll, ctx, [] as Array[String], [] as Array[String])
			seen_without += 1 if (control["cards"] as Array).has(target) else 0
	assert_int(seen_without).is_greater(0)
	assert_int(seen_with).is_equal(0)


func test_removed_cards_round_trip_through_the_dict_and_are_not_duplicated() -> void:
	var state: RunState = _full_state(5)
	state.record_removal(state.deck[0])
	state.record_removal(state.deck[0])
	state.record_removal(state.deck[1])
	assert_int(state.removed_cards.size()).is_equal(2)
	var back: RunState = RunState.from_json(state.to_json())
	assert_array(back.removed_cards).is_equal(state.removed_cards)
	assert_bool(state.equals(back)).is_true()


func _map_state(seed_value: int) -> RunState:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(seed_value)
	var ctx: Dictionary = _ctx()
	RunNodes.apply(state, "node:%d" % RunNodes.reachable_ids(state)[0], ctx)
	state.hp = 20.0
	state.max_hp = 30.0
	state.record_room({"index": state.room_index, "type": "combat", "wave_id": "combat_intro"}, 20.0, 12.0)
	RunNodes.open(state)
	return state


func _write_run(run_data: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": RunSave.SAVE_VERSION, "run": run_data}))
	file.close()


func test_the_removed_list_survives_the_save_file() -> void:
	var state: RunState = _map_state(7)
	state.record_removal(state.deck[0])
	assert_bool(RunSave.write(state)).is_true()
	RunSession.clear()
	assert_bool(RunSave.load_save()).is_true()
	assert_array(RunSession.current.removed_cards).contains_exactly([state.deck[0]])
	assert_bool(state.equals(RunSession.current)).is_true()


func test_an_old_save_without_the_key_loads_with_no_removed_cards() -> void:
	var state: RunState = _map_state(8)
	var run_data: Dictionary = state.to_dict()
	run_data.erase("removed_cards")
	_write_run(run_data)
	assert_bool(RunSave.has_save()).is_true()
	assert_bool(RunSave.load_save()).is_true()
	assert_array(RunSession.current.removed_cards).is_empty()


func test_a_bad_removed_cards_field_makes_the_save_unusable() -> void:
	var state: RunState = _map_state(9)
	for bad: Variant in ["rogue_lunge", [3], [""], ["no_such_card_xyz"]]:
		var run_data: Dictionary = state.to_dict()
		run_data["removed_cards"] = bad
		_write_run(run_data)
		assert_bool(RunSave.read_state() == null).override_failure_message("accepted removed_cards = %s" % str(bad)).is_true()
		assert_str(RunSave.last_problem).is_not_empty()


func test_dry_pools_give_a_short_offer_and_then_no_reward_screen() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _full_state(31)
	var all_ids: Array[String] = []
	for card: Variant in (ctx["cards"] as Array):
		if (ctx["pools"] as Array).has(String((card as Dictionary).get("pool", ""))):
			all_ids.append(String((card as Dictionary)["id"]))
	# MAP3b B: act 1 offers only common cards, so the two that are left must be common ones (commons first).
	all_ids.sort_custom(func(a: String, b: String) -> bool: return (CardSchema.rarity_of(CardDatabase.get_card(a)) == "common") and (CardSchema.rarity_of(CardDatabase.get_card(b)) != "common"))
	# Two cards left in the pools: the offer is those two, never more and never a removed one.
	state.removed_cards = all_ids.slice(2)
	RunChoices.open_for_room(state, "combat", false, ctx)
	assert_int(state.offer.size()).is_equal(2)
	for id: String in state.offer:
		assert_bool(state.removed_cards.has(id)).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
	# Nothing left: no reward screen at all (the same path as any empty offer), and the run is not stuck.
	state.removed_cards = all_ids.duplicate()
	assert_str(RunChoices.open_for_room(state, "combat", false, ctx)).is_equal(RunState.PENDING_NONE)
	assert_array(state.offer).is_empty()
	# A merchant with nothing to stock still opens, with no cards on the shelf.
	state.gold = 100
	assert_str(RunChoices.open_for_room(state, "merchant", false, ctx)).is_equal(RunState.PENDING_MERCHANT)
	assert_array(state.merchant_visit["cards"] as Array).is_empty()


func test_the_relic_rooms_card_offer_fallback_also_leaves_out_removed_cards() -> void:
	# An elite with no relic left to offer gives its card offer instead (RunRelics -> RunChoices.open_for_room): that offer obeys D47 too.
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["catalog"] = []
	var state: RunState = _full_state(41)
	var target: String = state.deck[0]
	state.record_removal(target)
	for run_seed in range(1, 120):
		state.seed_value = run_seed
		RunRelics.open_for_room(state, "elite", false, ctx)
		assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
		assert_bool(state.offer.has(target)).is_false()
	var all_ids: Array[String] = []
	for card: Variant in (ctx["cards"] as Array):
		if (ctx["pools"] as Array).has(String((card as Dictionary).get("pool", ""))):
			all_ids.append(String((card as Dictionary)["id"]))
	state.removed_cards = all_ids
	assert_str(RunRelics.open_for_room(state, "elite", false, ctx)).is_equal(RunState.PENDING_NONE)
