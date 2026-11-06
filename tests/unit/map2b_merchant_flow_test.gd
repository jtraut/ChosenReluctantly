class_name Map2bMerchantFlowTest
extends GdUnitTestSuite
## MAP2-B: the merchant node in the run flow. The merchant ships OFF, so every test here turns it on for the process (MerchantSwitch.apply) and
## restores the shipped config afterwards. The model is checked through RunChoices / RunMerchant; one pass goes through the real RunController.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func before_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()
	assert_bool(MerchantSwitch.apply()).is_true()


func after_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.relic_cap = 0
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()


func _ctx(character: String = "rogue") -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools(character))


## A map state standing on the first merchant node found from `first_seed` up, with gold to spend and the shop open.
func _shop(first_seed: int = 1, gold: int = 600, ctx: Dictionary = {}) -> RunState:
	var use: Dictionary = ctx if not ctx.is_empty() else _ctx()
	var state: RunState = _state_on_merchant(first_seed)
	assert_object(state).is_not_null()
	state.gold = gold
	assert_str(RunChoices.open_for_room(state, "merchant", false, use)).is_equal(RunState.PENDING_MERCHANT)
	return state


func _state_on_merchant(first_seed: int = 1) -> RunState:
	for seed_value in range(first_seed, first_seed + 200):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) != "merchant":
				continue
			var trail: Array[int] = [int(entry["id"])]
			while int(MapGraph.node(map, trail[0])["room"]) > 1:
				trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
			var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			return state
	return null


func _option(model: Dictionary, prefix: String) -> Dictionary:
	for option: Dictionary in (model["options"] as Array):
		if String(option["id"]).begins_with(prefix):
			return option
	return {}


func _options_of_kind(model: Dictionary, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for option: Dictionary in (model["options"] as Array):
		if String(option["kind"]) == kind:
			out.append(option)
	return out


# --- the switch ------------------------------------------------------------------------------------

func test_the_switch_turns_the_merchant_on_for_the_process_only_and_the_shipped_data_is_all_off_or_all_on() -> void:
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	var shipped_on: bool = MerchantSwitch.shipped_is_on()
	assert_array(MerchantSwitch.shipped_problems()).is_empty()  # never half flipped
	assert_float(float(MapConfig.get_config()["types"]["merchant"]["weight"])).is_equal(8.0 if shipped_on else 0.0)
	assert_array(MapConfig.get_config()["path_rules"]["relic_route"]).is_equal([6.0, 8.0] if shipped_on else [5.0, 7.0])
	assert_bool(MerchantSwitch.apply()).is_true()
	assert_float(float(MapConfig.get_config()["types"]["merchant"]["weight"])).is_equal(8.0)
	assert_int(int(MapConfig.get_config()["path_rules"]["max_merchants"])).is_equal(1)
	assert_array(MapConfig.get_config()["path_rules"]["relic_route"]).is_equal([6.0, 8.0])
	assert_bool(MerchantSwitch.apply()).is_true()  # twice is harmless
	assert_array(MapConfig.get_config()["path_rules"]["relic_route"]).is_equal([6.0, 8.0])
	MapConfig.reset_cache()  # the shipped file again
	assert_float(float(MapConfig.get_config()["types"]["merchant"]["weight"])).is_equal(8.0 if shipped_on else 0.0)
	# the patch's values are the ones in the file: prices and estimate move together
	var patch: Dictionary = MerchantSwitch.patch()
	var prices: Dictionary = patch["run"]["relics"]["prices"]
	var estimate: Array = patch["map"]["estimate"]["merchant_prices"]
	assert_array(estimate).is_equal([float(prices["tier1"]), float(prices["tier1"]), float(prices["tier2"])])


func test_a_broken_patch_changes_nothing_and_says_so() -> void:
	assert_array(MerchantSwitch.patch_problems("nope")).is_not_empty()
	assert_array(MerchantSwitch.patch_problems({"map": {}, "run": {}, "extra": 1})).is_not_empty()
	assert_array(MerchantSwitch.patch_problems({"map": {}})).is_not_empty()
	assert_array(MerchantSwitch.patch_problems({"map": {}, "run": {}})).is_empty()
	var merged: Dictionary = MerchantSwitch.merged({"a": {"b": 1, "c": [1, 2]}, "d": 4}, {"a": {"c": [9]}, "e": 5})
	assert_dict(merged).is_equal({"a": {"b": 1, "c": [9]}, "d": 4, "e": 5})
	# a patch that breaks a map rule (a relic window above the room count) is refused by the validator
	var base: Dictionary = MapConfig.get_config().duplicate(true)
	var bad: Dictionary = MerchantSwitch.merged(base, {"path_rules": {"relic_route": [8, 5]}})
	assert_array(MapConfig.validate(bad)).is_not_empty()


func test_with_the_merchant_on_maps_hold_at_most_one_merchant_per_path_and_some_seeds_have_one() -> void:
	var with_merchant: int = 0
	for seed_value in range(1, 41):
		var map: Dictionary = MapGenerator.generate(seed_value)
		assert_bool(map.is_empty()).is_false()
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) == "merchant":
				with_merchant += 1
				assert_str(String(entry["wave_id"])).is_empty()  # no fight
				break
	assert_int(with_merchant).is_greater(10)


func test_jump_to_node_lays_the_path_back_to_room_one_and_refuses_a_missing_node() -> void:
	var state: RunState = _state_on_merchant(1)
	var node: int = state.path[state.path.size() - 1]
	var fresh := RunState.new_run(state.seed_value, CharacterDatabase.starting_deck("rogue"), 3)
	fresh.map = state.map
	assert_bool(fresh.jump_to_node(node)).is_true()
	assert_array(fresh.path).is_equal(state.path)
	assert_int(fresh.room_index).is_equal(state.room_index)
	assert_str(fresh.pending).is_equal(RunState.PENDING_NONE)
	assert_bool(RunNodes.consistent(fresh)).is_true()
	assert_bool(fresh.jump_to_node(99999)).is_false()
	assert_bool(RunState.new_run(1, CharacterDatabase.starting_deck("rogue"), 3).jump_to_node(0)).is_false()  # a straight run has no nodes


# --- opening the shop ------------------------------------------------------------------------------

func test_a_merchant_node_opens_the_shop_with_stock_prices_gold_and_the_leave_option() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _shop(1, 600, ctx)
	var node: int = state.path[state.path.size() - 1]
	assert_int(int(state.merchant_visit["node"])).is_equal(node)
	assert_int(RunNodes.roll_gold(state.seed_value, node, "merchant", RunConfig.gold())).is_equal(0)  # nothing is earned here
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	assert_str(String(model["choice"])).is_equal(RunState.PENDING_MERCHANT)
	assert_str(String(model["title"])).is_equal("Merchant")
	assert_bool(String(model["line"]).contains("600")).is_true()
	var view: Dictionary = model["merchant"]
	assert_bool(bool(view["open"])).is_true()
	assert_int(int(view["gold"])).is_equal(600)
	assert_int((view["items"] as Array).size()).is_equal(7)  # 3 relics, 3 cards, the removal entry
	assert_int(_options_of_kind(model, "buy_relic").size()).is_equal(3)
	assert_int(_options_of_kind(model, "buy_card").size()).is_equal(3)
	assert_int(_options_of_kind(model, "buy_removal").size()).is_equal(1)
	assert_dict(_option(model, "merchant_leave")).is_not_empty()
	assert_str(String(_option(model, "merchant_leave")["kind"])).is_equal("back")  # the run screen keeps a "back" option in its always-visible footer
	assert_int(_options_of_kind(model, "reroll").size()).is_equal(0)  # no relic grants a reroll yet
	for option: Dictionary in _options_of_kind(model, "buy_relic"):
		assert_int(int(option["price"])).is_between(RelicConfig.price_for_tier("tier1"), RelicConfig.price_for_tier("tier2"))
		assert_bool(bool(option["enabled"])).is_true()
		assert_str(String(option["detail"])).is_not_empty()
		assert_bool(RunChoices.KINDS.has(String(option["kind"]))).is_true()
	for item: Dictionary in (view["items"] as Array):
		for key: String in ["kind", "id", "name", "price", "sold", "can_buy", "reason", "reason_text", "needs_giveup"]:
			assert_bool(item.has(key)).override_failure_message("item lacks %s" % key).is_true()
	# one stock per seed and node: the same state opened again shows the same shop
	var again: RunState = _state_on_merchant(1)
	again.gold = 600
	RunChoices.open_for_room(again, "merchant", false, _ctx())
	assert_dict(again.merchant_visit).is_equal(state.merchant_visit)


func test_the_reasons_a_disabled_item_gives_are_codes_with_words() -> void:
	var ctx: Dictionary = _ctx()
	var poor: int = RelicConfig.price_for_tier("tier1") - 1  # one gold short of the cheapest relic
	var state: RunState = _shop(1, poor, ctx)
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	for option: Dictionary in _options_of_kind(model, "buy_relic"):
		assert_bool(bool(option["enabled"])).is_false()
		assert_str(String(option["reason_code"])).is_equal("too_expensive")
		assert_str(String(option["reason"])).is_equal("Not enough gold")
	var refused: Dictionary = RunChoices.apply(state, String(_options_of_kind(model, "buy_relic")[0]["id"]), ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(String(refused["reason_code"])).is_equal("too_expensive")
	assert_int(state.gold).is_equal(poor)  # a refusal changes nothing
	state.gold = Merchant.card_price(ctx) + 5
	var card: Dictionary = RunChoices.apply(state, String(_options_of_kind(model, "buy_card")[0]["id"]), ctx)
	assert_bool(bool(card["ok"])).is_true()  # the card price, and 5 over
	assert_int(state.gold).is_equal(5)


func test_the_removal_entry_says_why_when_no_card_can_be_removed() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _shop(1, 600, ctx)
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	var removal: Dictionary = _options_of_kind(model, "buy_removal")[0]
	assert_bool(RunChoices.removable_card_ids(state, ctx).is_empty()).is_true()  # the starter deck: every card is needed for a slot minimum
	assert_bool(bool(removal["enabled"])).is_false()
	assert_str(String(removal["reason_code"])).is_equal("none_removable")
	assert_str(String(removal["reason"])).is_equal("Every card is needed to meet the deck minimums")
	assert_str(String((model["merchant"]["removal"] as Dictionary)["reason"])).is_equal("none_removable")
	assert_bool(bool((model["merchant"]["removal"] as Dictionary)["can_buy"])).is_false()
	var refused: Dictionary = RunChoices.apply(state, RunMerchant.OPTION_REMOVE_MENU, ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(String(refused["reason_code"])).is_equal("none_removable")
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	# the per-card list still carries each card's own reason
	for entry: Dictionary in (model["merchant"]["removal"]["entries"] as Array):
		assert_str(String(entry["reason"])).is_equal("removal_blocked")
		assert_array(entry["problems"]).is_not_empty()
		assert_str(String(entry["reason_text"])).is_not_empty()


func test_a_removal_goes_through_the_list_charges_the_price_and_raises_the_next_one() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _shop(1, 600, ctx)
	state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools("rogue"))  # a full deck: spare cards
	var removable: Array[String] = RunChoices.removable_card_ids(state, ctx)
	assert_array(removable).is_not_empty()
	assert_bool(bool(RunChoices.apply(state, RunMerchant.OPTION_REMOVE_MENU, ctx)["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_REMOVE)
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	assert_str(String(model["merchant_screen"])).is_equal("remove")
	assert_str(String(model["line"])).is_equal("Removing a card costs 50 gold. Greyed cards would break a deck minimum.")
	var first: Dictionary = _option(model, "merchant_remove:" + removable[0])
	assert_bool(bool(first["enabled"])).is_true()
	assert_int(int(first["price"])).is_equal(50)
	var blocked: Array[String] = []
	for option: Dictionary in _options_of_kind(model, "remove"):
		if not bool(option["enabled"]):
			blocked.append(String(option["card_id"]))
			assert_str(String(option["reason_code"])).is_equal("removal_blocked")
			assert_str(String(option["reason"])).is_not_empty()
	if not blocked.is_empty():
		var refused: Dictionary = RunChoices.apply(state, "merchant_remove:" + blocked[0], ctx)
		assert_bool(bool(refused["ok"])).is_false()
		assert_str(String(refused["reason_code"])).is_equal("removal_blocked")
	var deck_before: int = state.deck.size()
	var done: Dictionary = RunChoices.apply(state, "merchant_remove:" + removable[0], ctx)
	assert_bool(bool(done["ok"])).is_true()
	assert_str(String(done["kind"])).is_equal("merchant_remove")
	assert_int(state.deck.size()).is_equal(deck_before - 1)
	assert_int(state.gold).is_equal(550)
	assert_int(state.merchant_removals).is_equal(1)
	assert_int(state.gold_spent_merchant).is_equal(50)
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)  # back to the shop: buy more
	var view: Dictionary = RunChoices.model(state, ctx, "merchant")["merchant"]
	assert_int(int((view["removal"] as Dictionary)["price"])).is_equal(75)


func test_back_leaves_the_removal_list_and_leave_closes_the_visit_and_the_choice() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _shop(1, 600, ctx)
	state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools("rogue"))
	RunChoices.apply(state, RunMerchant.OPTION_REMOVE_MENU, ctx)
	assert_bool(bool(RunChoices.apply(state, RunMerchant.OPTION_BACK, ctx)["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	assert_bool(bool(RunChoices.apply(state, RunMerchant.OPTION_BACK, ctx)["ok"])).is_false()  # Back means nothing in the shop
	var left: Dictionary = RunChoices.apply(state, RunMerchant.OPTION_LEAVE, ctx)
	assert_bool(bool(left["ok"])).is_true()
	assert_bool(bool(left["finished"])).is_true()
	assert_str(String(left["kind"])).is_equal("merchant_leave")
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_bool(state.merchant_visit.is_empty()).is_true()
	assert_bool(bool(RunChoices.apply(state, RunMerchant.OPTION_LEAVE, ctx)["ok"])).is_false()  # nothing is open any more


# --- buying: several in one visit, never below zero, the cap ---------------------------------------

func test_several_things_can_be_bought_in_one_visit_and_gold_never_goes_below_zero() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _shop(1, 250, ctx)
	var spent: int = 0
	for step in range(10):
		var model: Dictionary = RunChoices.model(state, ctx, "merchant")
		var pick: Dictionary = {}
		for option: Dictionary in (model["options"] as Array):
			if (String(option["kind"]) == "buy_relic" or String(option["kind"]) == "buy_card") and bool(option["enabled"]):
				pick = option
				break
		if pick.is_empty():
			break
		var before: int = state.gold
		var result: Dictionary = RunChoices.apply(state, String(pick["id"]), ctx)
		assert_bool(bool(result["ok"])).is_true()
		assert_int(state.gold).is_equal(before - int(pick["price"]))
		assert_int(state.gold).is_greater_equal(0)
		spent += int(pick["price"])
	assert_int(state.gold_spent_merchant).is_equal(spent)
	assert_int(state.gold + spent).is_equal(250)
	assert_int(spent).is_greater(100)  # more than one item went
	# a sold item shows as sold and cannot be bought twice
	var model_after: Dictionary = RunChoices.model(state, ctx, "merchant")
	var sold: int = 0
	for item: Dictionary in (model_after["merchant"]["items"] as Array):
		if bool(item["sold"]):
			sold += 1
			assert_bool(bool(item["can_buy"])).is_false()
			assert_str(String(item["reason"])).is_equal("sold")
	assert_int(sold).is_greater(1)


func test_a_relic_bought_at_the_cap_asks_which_to_give_up_and_cancel_charges_nothing() -> void:
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["max_owned"] = 1
	var state: RunState = _shop(1, 600, ctx)
	state.relics = ["pyre_insurance"] as Array[String]
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	var target: Dictionary = {}
	for option: Dictionary in _options_of_kind(model, "buy_relic"):
		if bool(option["enabled"]) and String(option["relic_id"]) != "pyre_insurance":
			target = option
			break
	assert_bool(bool(target["needs_swap"])).is_true()
	var opened: Dictionary = RunChoices.apply(state, String(target["id"]), ctx)
	assert_bool(bool(opened["ok"])).is_true()
	assert_str(String(opened["kind"])).is_equal("merchant_swap_open")
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
	assert_str(state.relic_incoming).is_equal(String(target["relic_id"]))
	assert_int(state.gold).is_equal(600)
	var swap_model: Dictionary = RunChoices.model(state, ctx, "merchant")
	assert_str(String(swap_model["merchant_screen"])).is_equal("swap")
	assert_str(String(swap_model["relic_choice"])).is_equal("giveup")
	assert_str(String((swap_model["incoming"] as Dictionary)["relic_id"])).is_equal(String(target["relic_id"]))
	assert_int(_options_of_kind(swap_model, "giveup").size()).is_equal(1)
	# cancel: nothing changes
	assert_bool(bool(RunChoices.apply(state, RunMerchant.OPTION_CANCEL, ctx)["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	assert_array(state.relics).is_equal(["pyre_insurance"])
	assert_int(state.gold).is_equal(600)
	# do it for real
	RunChoices.apply(state, String(target["id"]), ctx)
	var done: Dictionary = RunChoices.apply(state, "merchant_giveup:pyre_insurance", ctx)
	assert_bool(bool(done["ok"])).is_true()
	assert_str(String(done["kind"])).is_equal("merchant_relic")
	assert_str(String(done["gave_up"])).is_equal("pyre_insurance")
	assert_array(state.relics).is_equal([String(target["relic_id"])])
	assert_array(state.relics_given_up).is_equal(["pyre_insurance"])
	assert_int(state.gold).is_equal(600 - int(target["price"]))
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)  # still shopping
	# the rest of the stock still works at the cap
	var next_model: Dictionary = RunChoices.model(state, ctx, "merchant")
	assert_bool(bool(_option(next_model, "buy_card:")["enabled"])).is_true()


func test_the_stock_never_offers_an_owned_or_given_up_relic_and_a_bought_one_is_not_offered_again() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _shop(1, 900, ctx)
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	var ids: Array[String] = []
	for option: Dictionary in _options_of_kind(model, "buy_relic"):
		ids.append(String(option["relic_id"]))
	assert_int(ids.size()).is_equal(3)
	assert_int(ids.size()).is_equal(Array(ids).filter(func(a: String) -> bool: return ids.count(a) == 1).size())  # no duplicates
	RunChoices.apply(state, "buy_relic:" + ids[0], ctx)
	assert_bool(state.has_relic(ids[0])).is_true()
	var again: Dictionary = RunChoices.apply(state, "buy_relic:" + ids[0], ctx)
	assert_bool(bool(again["ok"])).is_false()
	assert_str(String(again["reason_code"])).is_equal("sold")


# --- Request for Quotation (the free reroll) -------------------------------------------------------

func test_free_rerolls_come_from_the_owned_relics_and_work_in_the_visit_that_buys_the_relic() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state_on_merchant(1)
	state.gold = 600
	assert_int(RunMerchant.free_rerolls(state, ctx)).is_equal(0)
	state.relics = ["request_for_quotation"] as Array[String]
	assert_int(RunMerchant.free_rerolls(state, ctx)).is_equal(1)
	state.relics = []
	# the relic is in this shop: buy it, and the reroll is there at once
	RunChoices.open_for_room(state, "merchant", false, ctx)
	var visit: Dictionary = state.merchant_visit
	(visit["relics"] as Array)[2] = "request_for_quotation"
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	assert_int(_options_of_kind(model, "reroll").size()).is_equal(0)
	var bought: Dictionary = RunChoices.apply(state, "buy_relic:request_for_quotation", ctx)
	assert_bool(bool(bought["ok"])).is_true()
	assert_int(int(ctx["merchant"]["free_rerolls"])).is_equal(1)
	var after: Dictionary = RunChoices.model(state, ctx, "merchant")
	var reroll: Dictionary = _options_of_kind(after, "reroll")[0]
	assert_bool(bool(reroll["enabled"])).is_true()
	assert_int(int((after["merchant"]["rerolls"] as Dictionary)["left"])).is_equal(1)
	var stock_before: Array = (state.merchant_visit["relics"] as Array).duplicate()
	var rolled: Dictionary = RunChoices.apply(state, RunMerchant.OPTION_REROLL, ctx)
	assert_bool(bool(rolled["ok"])).is_true()
	assert_array(state.merchant_visit["relics"]).is_not_equal(stock_before)
	assert_bool((state.merchant_visit["relics"] as Array).has("request_for_quotation")).is_true()  # the sold one stays shown as sold
	assert_bool((state.merchant_visit["sold_relics"] as Array).has("request_for_quotation")).is_true()
	# once per visit
	var second: Dictionary = RunChoices.apply(state, RunMerchant.OPTION_REROLL, ctx)
	assert_bool(bool(second["ok"])).is_false()
	assert_str(String(second["reason_code"])).is_equal("no_rerolls")
	var last: Dictionary = _options_of_kind(RunChoices.model(state, ctx, "merchant"), "reroll")[0]
	assert_bool(bool(last["enabled"])).is_false()
	assert_str(String(last["reason_code"])).is_equal("no_rerolls")
	# a new visit (a new node) starts with the reroll again
	var fresh: RunState = _state_on_merchant(1)
	fresh.relics = ["request_for_quotation"] as Array[String]
	RunChoices.open_for_room(fresh, "merchant", false, ctx)
	assert_int(int(RunChoices.model(fresh, ctx, "merchant")["merchant"]["rerolls"]["left"])).is_equal(1)


# --- save and restore mid-merchant -----------------------------------------------------------------

func _round_trip(state: RunState) -> RunState:
	var copy: RunState = RunState.from_dict(JSON.parse_string(state.to_json()))
	assert_object(copy).is_not_null()
	return copy


func test_a_save_taken_in_the_shop_the_removal_list_or_the_swap_restores_the_same_screen_and_stock() -> void:
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["max_owned"] = 1
	var state: RunState = _shop(1, 600, ctx)
	state.relics = ["pyre_insurance"] as Array[String]
	state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools("rogue"))
	var model: Dictionary = RunChoices.model(state, ctx, "merchant")
	RunChoices.apply(state, String(_options_of_kind(model, "buy_card")[0]["id"]), ctx)  # something bought: gold, sold items, deck
	var copy: RunState = _round_trip(state)
	assert_bool(state.equals(copy)).is_true()
	assert_str(copy.pending).is_equal(RunState.PENDING_MERCHANT)
	assert_dict(copy.merchant_visit).is_equal(state.merchant_visit)
	assert_int(copy.gold).is_equal(state.gold)
	assert_dict(RunChoices.model(copy, ctx, "merchant")["merchant"]).is_equal(RunChoices.model(state, ctx, "merchant")["merchant"])
	# the removal list
	RunChoices.apply(state, RunMerchant.OPTION_REMOVE_MENU, ctx)
	var in_list: RunState = _round_trip(state)
	assert_str(in_list.pending).is_equal(RunState.PENDING_MERCHANT_REMOVE)
	assert_bool(state.equals(in_list)).is_true()
	RunChoices.apply(state, RunMerchant.OPTION_BACK, ctx)
	# the swap
	var relic_option: Dictionary = {}
	for option: Dictionary in _options_of_kind(RunChoices.model(state, ctx, "merchant"), "buy_relic"):
		if bool(option["enabled"]):
			relic_option = option
			break
	RunChoices.apply(state, String(relic_option["id"]), ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
	var in_swap: RunState = _round_trip(state)
	assert_str(in_swap.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
	assert_str(in_swap.relic_incoming).is_equal(state.relic_incoming)
	assert_bool(state.equals(in_swap)).is_true()
	# finishing the purchase on the restored copy works like on the original
	var done: Dictionary = RunChoices.apply(in_swap, "merchant_giveup:pyre_insurance", ctx)
	assert_bool(bool(done["ok"])).is_true()
	assert_array(in_swap.relics).is_equal([String(relic_option["relic_id"])])


func test_a_merchant_choice_with_no_visit_or_a_bad_swap_is_dropped_on_load_not_trusted() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _shop(1, 600, ctx)
	var data: Dictionary = JSON.parse_string(state.to_json())
	data["merchant_visit"] = {}  # the visit is gone but the shop is "open"
	var dropped: RunState = RunState.from_dict(data)
	assert_object(dropped).is_not_null()
	assert_str(dropped.pending).is_equal(RunState.PENDING_NODE)  # a map run reopens the pick-next-node choice
	var swap_data: Dictionary = JSON.parse_string(state.to_json())
	swap_data["pending"] = RunState.PENDING_MERCHANT_SWAP
	swap_data["relic_incoming"] = "not_in_this_shop"
	var bad_swap: RunState = RunState.from_dict(swap_data)
	assert_str(bad_swap.pending).is_equal(RunState.PENDING_NODE)
	assert_bool(bad_swap.merchant_visit.is_empty()).is_true()


# --- the bot ---------------------------------------------------------------------------------------

func test_the_bot_buys_relics_first_on_a_relic_route_and_a_removal_then_a_card_on_a_safe_one() -> void:
	var ctx: Dictionary = _ctx()
	var relic_state: RunState = _shop(1, 600, ctx)
	var picks: Array[String] = []
	for step in range(12):
		var model: Dictionary = RunChoices.model(relic_state, ctx, "merchant")
		var id: String = MerchantPolicy.choose(String(model["choice"]), model["options"], relic_state, "relic")
		var result: Dictionary = RunChoices.apply(relic_state, id, ctx)
		assert_bool(bool(result["ok"])).override_failure_message("%s: %s" % [id, str(result.get("reason", ""))]).is_true()
		picks.append(String(result["kind"]))
		if bool(result["finished"]):
			break
	assert_array(picks).contains(["merchant_relic"])
	assert_str(picks[0]).is_equal("merchant_relic")
	assert_str(picks[picks.size() - 1]).is_equal("merchant_leave")
	assert_int(relic_state.relics.size()).is_greater(1)
	var safe_state: RunState = _shop(1, 600, ctx)
	safe_state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools("rogue"))
	var safe_kinds: Array[String] = []
	for step in range(12):
		var safe_model: Dictionary = RunChoices.model(safe_state, ctx, "merchant")
		var safe_id: String = MerchantPolicy.choose(String(safe_model["choice"]), safe_model["options"], safe_state, "safe")
		var safe_result: Dictionary = RunChoices.apply(safe_state, safe_id, ctx)
		assert_bool(bool(safe_result["ok"])).is_true()
		if String(safe_result["kind"]) != "merchant_menu" and String(safe_result["kind"]) != "merchant_back":
			safe_kinds.append(String(safe_result["kind"]))
		if bool(safe_result["finished"]):
			break
	assert_array(safe_kinds).is_equal(["merchant_remove", "merchant_card", "merchant_leave"])
	assert_int(safe_state.relics.size()).is_equal(0)


# --- through the real controller -------------------------------------------------------------------

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func test_the_controller_opens_the_shop_on_a_merchant_node_buys_and_leaves_to_the_map() -> void:
	var state: RunState = _state_on_merchant(1)
	state.gold = 400
	RunSession.current = state
	var main := _spawn()
	var models: Array[Dictionary] = []
	main.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	var golds: Array[int] = []
	main.run_controller.gold_changed.connect(func(total: int, delta: int) -> void: golds.append(total * 1000 + (delta + 500)))
	await _frames()
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("merchant")
	assert_int(main.enemy_spawner.alive_count()).is_equal(0)  # no fight
	assert_bool(controller.is_cleared()).is_true()
	assert_bool(controller.merchant_open()).is_true()
	assert_int(models.size()).is_equal(1)
	assert_str(String(models[0]["choice"])).is_equal(RunState.PENDING_MERCHANT)
	var view: Dictionary = controller.merchant_view()
	assert_int(int(view["gold"])).is_equal(400)
	# buy a relic: gold drops, the relic is held and live in this room's manager
	var relic_item: Dictionary = {}
	for item: Dictionary in (view["items"] as Array):
		if String(item["kind"]) == "relic" and bool(item["can_buy"]):
			relic_item = item
			break
	var bought: Dictionary = controller.buy_relic(String(relic_item["id"]))
	assert_bool(bool(bought["ok"])).is_true()
	assert_int(state.gold).is_equal(400 - int(relic_item["price"]))
	assert_array(golds).is_equal([state.gold * 1000 + (500 - int(relic_item["price"]))])
	assert_bool(state.has_relic(String(relic_item["id"]))).is_true()
	assert_object(controller.relic_manager()).is_not_null()
	assert_bool(controller.relic_manager().has_relic(String(relic_item["id"]))).is_true()
	assert_bool(controller.merchant_open()).is_true()
	assert_int(models.size()).is_equal(2)  # the panel was told to refresh
	# the refusal path through the controller changes nothing
	var refused: Dictionary = controller.buy_relic("not_in_the_shop")
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(String(refused["reason_code"])).is_equal("not_in_stock")
	# leave: the visit closes and the pick-next-node choice opens
	var path_before: Array[int] = state.path.duplicate()
	var left: Dictionary = controller.leave_merchant()
	assert_bool(bool(left["ok"])).is_true()
	assert_bool(state.merchant_visit.is_empty()).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_array(state.path).is_equal(path_before)
	assert_bool(controller.merchant_open()).is_false()
	assert_array(controller.reachable_nodes()).is_equal(MapGraph.next_ids(state.map, path_before[path_before.size() - 1]))


func test_a_reload_in_the_shop_reopens_the_same_stock_with_no_second_visit() -> void:
	var state: RunState = _state_on_merchant(1)
	state.gold = 400
	RunSession.current = state
	var first := _spawn()
	await _frames()
	var stock: Dictionary = state.merchant_visit.duplicate(true)
	var card_id: String = String(first.run_controller.merchant_view()["items"][3]["id"])
	assert_bool(bool(first.run_controller.buy_card(card_id)["ok"])).is_true()
	var saved: String = state.to_json()
	first.queue_free()
	await _frames()
	var restored: RunState = RunState.from_json(saved)
	RunSession.current = restored
	var second := _spawn()
	var models: Array[Dictionary] = []
	second.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _frames()
	assert_str(restored.pending).is_equal(RunState.PENDING_MERCHANT)
	assert_array(restored.merchant_visit["relics"]).is_equal(stock["relics"])
	assert_array(restored.merchant_visit["cards"]).is_equal(stock["cards"])
	assert_array(restored.merchant_visit["sold_cards"]).is_equal([card_id])
	assert_int(restored.gold).is_equal(360)
	assert_int(restored.history.size()).is_equal(state.history.size())  # the merchant room was recorded once, not again
	assert_bool(second.run_controller.merchant_open()).is_true()
	assert_int(models.size()).is_equal(1)  # the reopened choice was announced
