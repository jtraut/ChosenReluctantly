class_name Map2aMerchantTest
extends GdUnitTestSuite
## MAP2-A: the merchant model (stock, prices, buying, removal, reroll hook), the run.json `merchant` and `relics.prices` blocks, and the
## RunState fields. No scene: everything runs on the pure model and fixture catalogs.


func before_test() -> void:
	RelicDatabase.load_all()


func _ctx(cap: int = 20, free_rerolls: int = 0) -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	(ctx["merchant"] as Dictionary)["free_rerolls"] = free_rerolls
	return ctx


## A relic dictionary for a fixture catalog.
func _relic(id: String, rarity: String, sources: Array, pool: String = "neutral") -> Dictionary:
	return {"id": id, "name": id, "pool": pool, "rarity": rarity, "sources": sources, "keywords": [], "modifiers": [], "triggers": [], "rule_text": "x", "flavor_text": "y"}


## The shipped context with `extra` relics added to the catalog.
func _ctx_with(extra: Array[Dictionary], cap: int = 20, free_rerolls: int = 0) -> Dictionary:
	var ctx: Dictionary = _ctx(cap, free_rerolls)
	var relics: Dictionary = ctx["relics"]
	var catalog: Array = (relics["catalog"] as Array).duplicate()
	for relic: Dictionary in extra:
		catalog.append(relic)
		(relics["by_id"] as Dictionary)[String(relic["id"])] = relic
	relics["catalog"] = catalog
	return ctx


func _state(seed_value: int = 11, gold: int = 500) -> RunState:
	var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
	state.gold = gold
	return state


## A state holding every card of the Rogue's pools (the starter blocks every removal).
func _full_state(seed_value: int = 11, gold: int = 500) -> RunState:
	var state := _state(seed_value, gold)
	state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools("rogue"))
	return state


# --- data ----------------------------------------------------------------------------------------

func test_shipped_data_has_the_merchant_block_and_the_relic_prices() -> void:
	var merchant: Dictionary = RunConfig.get_config()["merchant"]
	assert_int(int(merchant["card_price"])).is_equal(40)
	assert_int(int(merchant["removal_base"])).is_equal(50)
	assert_int(int(merchant["removal_step"])).is_equal(25)
	assert_int(int(merchant["relic_stock"])).is_equal(3)
	assert_int(int(merchant["card_stock"])).is_equal(3)
	assert_array(MerchantConfig.validate_block(merchant)).is_empty()
	assert_int(RelicConfig.price_for_tier("tier1")).is_equal(60)
	assert_int(RelicConfig.price_for_tier("tier2")).is_equal(90)
	assert_int(RelicConfig.price_for_tier("tier3")).is_equal(130)
	assert_int(RelicConfig.price_for_tier("boss")).is_equal(-1)


func test_merchant_block_is_validated() -> void:
	var good: Dictionary = RunConfig.get_config()["merchant"]
	for key: String in MerchantConfig.KEYS:
		var missing: Dictionary = good.duplicate()
		missing.erase(key)
		assert_bool(" ".join(MerchantConfig.validate_block(missing)).contains(key)).override_failure_message("missing %s accepted" % key).is_true()
	for bad: Array in [["card_price", 0], ["card_price", "forty"], ["removal_base", -1], ["removal_step", 1.5], ["relic_stock", 0], ["relic_stock", 10], ["card_stock", -1], ["shop_only_slots", 4], ["bogus", 1]]:
		var broken: Dictionary = good.duplicate()
		broken[bad[0]] = bad[1]
		assert_array(MerchantConfig.validate_block(broken)).override_failure_message("%s = %s accepted" % [bad[0], str(bad[1])]).is_not_empty()
	assert_array(MerchantConfig.validate_block("nope")).is_not_empty()


func test_relic_prices_are_validated_and_the_boss_tier_is_never_priced() -> void:
	assert_array(RelicConfig.validate_prices({"tier1": 60, "tier2": 90, "tier3": 130})).is_empty()
	for bad: Variant in [{"tier1": 60, "tier2": 90}, {"tier1": 0, "tier2": 90, "tier3": 130}, {"tier1": 60, "tier2": "x", "tier3": 130}, {"tier1": 60, "tier2": 90, "tier3": 130, "boss": 200}, [], 5]:
		assert_array(RelicConfig.validate_prices(bad)).override_failure_message("%s accepted" % str(bad)).is_not_empty()
	# the whole relics block still validates with and without the prices
	var block: Dictionary = (RunConfig.get_config()["relics"] as Dictionary).duplicate(true)
	assert_array(RelicConfig.validate_block(block)).is_empty()
	block.erase("prices")
	assert_array(RelicConfig.validate_block(block)).is_empty()


func test_the_estimate_prices_match_the_relic_prices_and_the_stock_size() -> void:
	var prices: Array = MapConfig.get_config()["estimate"]["merchant_prices"]
	var relic_prices: Array[int] = []
	for value: Variant in (RelicConfig.block()["prices"] as Dictionary).values():
		relic_prices.append(int(value))
	assert_int(prices.size()).is_equal(int(MerchantConfig.block()["relic_stock"]))
	for price: Variant in prices:
		assert_bool(relic_prices.has(int(price))).override_failure_message("estimate price %s is not a tier price" % str(price)).is_true()


func test_the_merchant_ships_off() -> void:
	assert_float(float(MapConfig.get_config()["types"]["merchant"]["weight"])).is_equal(0.0)
	assert_array(MapConfig.get_config()["path_rules"]["relic_route"]).contains_exactly([5.0, 7.0])


# --- stock ---------------------------------------------------------------------------------------

func test_the_shipped_stock_is_three_relics_and_three_cards_without_duplicates() -> void:
	var ctx: Dictionary = _ctx()
	for seed_value in range(1, 40):
		var state: RunState = _state(seed_value)
		var visit: Dictionary = Merchant.open_visit(state, 20, ctx)
		var relics: Array = visit["relics"]
		var cards: Array = visit["cards"]
		assert_int(relics.size()).is_equal(3)
		assert_int(cards.size()).is_equal(3)
		assert_int(_unique(relics)).is_equal(3)
		assert_int(_unique(cards)).is_equal(3)
		for relic_id: String in relics:
			var tier: String = String(((ctx["relics"]["by_id"] as Dictionary)[relic_id] as Dictionary)["rarity"])
			assert_bool(["tier1", "tier2", "tier3"].has(tier)).is_true()  # the boss tier is never sold
			assert_int(Merchant.relic_price(relic_id, ctx)).is_greater(0)


func _unique(items: Array) -> int:
	var seen: Dictionary = {}
	for item: Variant in items:
		seen[item] = true
	return seen.size()


func test_stock_is_deterministic_per_seed_and_node_and_differs_between_them() -> void:
	var ctx: Dictionary = _ctx()
	var a: Dictionary = Merchant.open_visit(_state(5), 20, ctx).duplicate(true)
	var b: Dictionary = Merchant.open_visit(_state(5), 20, ctx).duplicate(true)
	assert_dict(a).is_equal(b)
	var differs: bool = false
	for seed_value in range(1, 12):
		if str(Merchant.open_visit(_state(seed_value), 20, ctx)) != str(Merchant.open_visit(_state(seed_value), 24, ctx)):
			differs = true
	assert_bool(differs).override_failure_message("the node id does not change the stock").is_true()


func test_stock_never_holds_an_owned_or_given_up_relic() -> void:
	var ctx: Dictionary = _ctx()
	for seed_value in range(1, 40):
		var state: RunState = _state(seed_value)
		state.relics = ["pyre_insurance", "heavy_sigh"] as Array[String]
		state.relics_given_up = ["spite_knuckles"] as Array[String]
		var relics: Array = Merchant.open_visit(state, 20, ctx)["relics"]
		for banned: String in ["pyre_insurance", "heavy_sigh", "spite_knuckles"]:
			assert_bool(relics.has(banned)).override_failure_message("seed %d stocked %s" % [seed_value, banned]).is_false()


func test_the_third_slot_holds_a_shop_only_relic_when_one_is_eligible() -> void:
	var shop_only: Array[Dictionary] = [_relic("t_shop_a", "tier1", ["merchant"]), _relic("t_shop_b", "tier2", ["merchant"])]
	var ctx: Dictionary = _ctx_with(shop_only)
	for seed_value in range(1, 40):
		var relics: Array = Merchant.open_visit(_state(seed_value), 20, ctx)["relics"]
		assert_int(relics.size()).is_equal(3)
		assert_int(_unique(relics)).is_equal(3)
		assert_bool(["t_shop_a", "t_shop_b"].has(String(relics[2]))).override_failure_message("seed %d third slot %s" % [seed_value, str(relics)]).is_true()
	# a shop-only relic the player owns is not stocked: the slot falls back to a normal merchant relic
	var state: RunState = _state(3)
	state.relics = ["t_shop_a", "t_shop_b"] as Array[String]
	var fallback: Array = Merchant.open_visit(state, 20, ctx)["relics"]
	assert_int(fallback.size()).is_equal(3)
	assert_bool(fallback.has("t_shop_a") or fallback.has("t_shop_b")).is_false()


func test_a_relic_that_is_also_sold_elsewhere_is_not_shop_only() -> void:
	assert_bool(Merchant.is_shop_only(_relic("x", "tier1", ["merchant"]))).is_true()
	assert_bool(Merchant.is_shop_only(_relic("x", "tier1", ["elite", "merchant"]))).is_false()
	assert_bool(Merchant.is_shop_only(_relic("x", "tier1", ["elite"]))).is_false()
	assert_bool(Merchant.is_shop_only("nope")).is_false()


func test_boss_tier_and_other_source_relics_are_never_sold() -> void:
	var extra: Array[Dictionary] = [_relic("t_boss", "boss", ["merchant"]), _relic("t_elite_only", "tier1", ["elite"])]
	var ctx: Dictionary = _ctx_with(extra)
	for seed_value in range(1, 40):
		var relics: Array = Merchant.open_visit(_state(seed_value), 20, ctx)["relics"]
		assert_bool(relics.has("t_boss") or relics.has("t_elite_only")).is_false()
	assert_int(Merchant.relic_price("t_boss", ctx)).is_equal(-1)


func test_open_visit_keeps_the_stock_of_an_open_visit_at_the_same_node() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(9)
	var first: Dictionary = Merchant.open_visit(state, 20, ctx).duplicate(true)
	state.relics = ["pyre_insurance"] as Array[String]  # would change a fresh draw
	assert_dict(Merchant.open_visit(state, 20, ctx)).is_equal(first)
	Merchant.close_visit(state)
	assert_bool(Merchant.has_visit(state)).is_false()


# --- buying --------------------------------------------------------------------------------------

func test_buying_several_things_in_any_order_never_takes_gold_below_zero() -> void:
	var ctx: Dictionary = _ctx()
	for order in range(3):
		var state: RunState = _full_state(7, 400)
		var visit: Dictionary = Merchant.open_visit(state, 20, ctx)
		var relic_id: String = String(visit["relics"][0])
		var card_id: String = String(visit["cards"][0])
		var gold_before: int = state.gold
		var spent: int = 0
		var steps: Array = [["relic", relic_id], ["card", card_id], ["removal", state.deck[0]]]
		steps = steps.slice(order) + steps.slice(0, order)  # three rotations
		for step: Array in steps:
			var result: Dictionary = {}
			match String(step[0]):
				"relic": result = Merchant.buy_relic(state, String(step[1]), ctx)
				"card": result = Merchant.buy_card(state, String(step[1]), ctx)
				"removal": result = Merchant.buy_removal(state, String(step[1]), ctx)
			assert_bool(bool(result["ok"])).override_failure_message("%s: %s" % [str(step), str(result)]).is_true()
			spent += int(result["price"])
			assert_int(state.gold).is_greater_equal(0)
		assert_int(state.gold).is_equal(gold_before - spent)
		assert_int(state.gold_spent_merchant).is_equal(spent)
		assert_bool(state.relics.has(relic_id)).is_true()
		assert_int(state.merchant_removals).is_equal(1)


func test_a_purchase_the_player_cannot_afford_changes_nothing() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _full_state(7, 39)
	var visit: Dictionary = Merchant.open_visit(state, 20, ctx)
	var deck_size: int = state.deck.size()
	var card_result: Dictionary = Merchant.buy_card(state, String(visit["cards"][0]), ctx)
	assert_bool(bool(card_result["ok"])).is_false()
	assert_str(String(card_result["reason"])).is_equal("too_expensive")
	assert_str(String(Merchant.buy_removal(state, state.deck[0], ctx)["reason"])).is_equal("too_expensive")
	state.gold = 59
	var relic_result: Dictionary = Merchant.buy_relic(state, String(visit["relics"][0]), ctx)
	assert_str(String(relic_result["reason"])).is_equal("too_expensive")
	assert_int(state.gold).is_equal(59)
	assert_int(state.deck.size()).is_equal(deck_size)
	assert_int(state.relics.size()).is_equal(0)
	assert_int(state.gold_spent_merchant).is_equal(0)


func test_a_sold_item_cannot_be_bought_twice_and_an_unstocked_one_cannot_be_bought() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(7, 900)
	var visit: Dictionary = Merchant.open_visit(state, 20, ctx)
	var relic_id: String = String(visit["relics"][0])
	assert_bool(bool(Merchant.buy_relic(state, relic_id, ctx)["ok"])).is_true()
	assert_str(String(Merchant.buy_relic(state, relic_id, ctx)["reason"])).is_equal("sold")
	var card_id: String = String(visit["cards"][0])
	assert_bool(bool(Merchant.buy_card(state, card_id, ctx)["ok"])).is_true()
	assert_str(String(Merchant.buy_card(state, card_id, ctx)["reason"])).is_equal("sold")
	assert_str(String(Merchant.buy_relic(state, "not_a_relic", ctx)["reason"])).is_equal("not_in_stock")
	Merchant.close_visit(state)
	assert_str(String(Merchant.buy_card(state, card_id, ctx)["reason"])).is_equal("no_visit")


func test_a_stocked_relic_the_data_no_longer_has_is_not_buyable() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(7, 900)
	Merchant.open_visit(state, 20, ctx)
	(state.merchant_visit["relics"] as Array).append("gone_relic")
	var result: Dictionary = Merchant.buy_relic(state, "gone_relic", ctx)
	assert_bool(bool(result["ok"])).is_false()
	assert_str(String(result["reason"])).is_equal("unknown_relic")
	assert_int(state.gold).is_equal(900)


func test_a_relic_at_the_cap_needs_a_give_up_and_charges_nothing_until_it_gets_one() -> void:
	var ctx: Dictionary = _ctx(2)
	var state: RunState = _state(7, 900)
	state.relics = ["pyre_insurance", "heavy_sigh"] as Array[String]
	var visit: Dictionary = Merchant.open_visit(state, 20, ctx)
	var relic_id: String = String(visit["relics"][0])
	var asked: Dictionary = Merchant.buy_relic(state, relic_id, ctx)
	assert_bool(bool(asked["ok"])).is_false()
	assert_bool(bool(asked["needs_giveup"])).is_true()
	assert_str(String(asked["reason"])).is_equal("needs_giveup")
	assert_array(asked["giveable"]).contains_exactly(["pyre_insurance", "heavy_sigh"])
	assert_int(state.gold).is_equal(900)
	assert_bool((state.merchant_visit["sold_relics"] as Array).is_empty()).is_true()
	assert_str(String(Merchant.buy_relic(state, relic_id, ctx, "spite_knuckles")["reason"])).is_equal("bad_giveup")  # not held
	var swapped: Dictionary = Merchant.buy_relic(state, relic_id, ctx, "heavy_sigh")
	assert_bool(bool(swapped["ok"])).is_true()
	assert_str(String(swapped["gave_up"])).is_equal("heavy_sigh")
	assert_array(state.relics).contains_exactly(["pyre_insurance", relic_id])
	assert_array(state.relics_given_up).contains_exactly(["heavy_sigh"])
	assert_int(state.gold).is_equal(900 - int(swapped["price"]))
	assert_bool((ctx["relics"] as Dictionary)["max_owned"] == 2).is_true()


func test_at_the_cap_a_boss_relic_cannot_be_given_up_and_none_giveable_refuses() -> void:
	var boss: Dictionary = _relic("t_boss", "boss", ["mini_boss"])
	var ctx: Dictionary = _ctx_with([boss] as Array[Dictionary], 1)
	var state: RunState = _state(7, 900)
	state.relics = ["t_boss"] as Array[String]
	var visit: Dictionary = Merchant.open_visit(state, 20, ctx)
	var result: Dictionary = Merchant.buy_relic(state, String(visit["relics"][0]), ctx)
	assert_str(String(result["reason"])).is_equal("none_giveable")
	assert_bool(bool(result["needs_giveup"])).is_false()
	assert_int(state.gold).is_equal(900)


func test_an_unaffordable_relic_at_the_cap_does_not_ask_for_a_give_up() -> void:
	var ctx: Dictionary = _ctx(1)
	var state: RunState = _state(7, 10)
	state.relics = ["pyre_insurance"] as Array[String]
	var visit: Dictionary = Merchant.open_visit(state, 20, ctx)
	assert_str(String(Merchant.buy_relic(state, String(visit["relics"][0]), ctx)["reason"])).is_equal("too_expensive")


func test_card_removal_goes_through_the_deck_guard_and_the_price_rises_each_time() -> void:
	var ctx: Dictionary = _ctx()
	var starter: RunState = _state(7, 900)
	Merchant.open_visit(starter, 20, ctx)
	var blocked: Dictionary = Merchant.buy_removal(starter, starter.deck[0], ctx)
	assert_str(String(blocked["reason"])).is_equal("removal_blocked")  # the plain starter holds exactly the minimum in every slot
	assert_int(starter.gold).is_equal(900)
	assert_int(starter.merchant_removals).is_equal(0)
	var state: RunState = _full_state(7, 900)
	Merchant.open_visit(state, 20, ctx)
	assert_int(Merchant.removal_price(state, ctx)).is_equal(50)
	var paid: Array[int] = []
	for i in range(3):
		var card_id: String = ""
		for candidate: String in RunChoices.removable_card_ids(state, ctx):
			card_id = candidate
			break
		assert_str(card_id).is_not_empty()
		var deck_before: int = state.deck.size()
		var result: Dictionary = Merchant.buy_removal(state, card_id, ctx)
		assert_bool(bool(result["ok"])).override_failure_message(str(result)).is_true()
		assert_int(state.deck.size()).is_equal(deck_before - 1)
		paid.append(int(result["price"]))
	assert_array(paid).is_equal([50, 75, 100])
	assert_int(state.merchant_removals).is_equal(3)
	assert_int(state.gold).is_equal(900 - 225)
	assert_int(Merchant.removal_price(state, ctx)).is_equal(125)
	assert_str(String(Merchant.buy_removal(state, "not_in_the_deck", ctx)["reason"])).is_equal("not_in_deck")


func test_items_lists_prices_and_the_reason_an_item_cannot_be_bought() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(7, 45)
	Merchant.open_visit(state, 20, ctx)
	var items: Array[Dictionary] = Merchant.items(state, ctx)
	assert_int(items.size()).is_equal(7)  # 3 relics, 3 cards, removal
	for item: Dictionary in items:
		match String(item["kind"]):
			"relic": assert_str(String(item["reason"])).is_equal("too_expensive")
			"card":
				assert_int(int(item["price"])).is_equal(40)
				assert_bool(bool(item["can_buy"])).is_true()
			"removal": assert_str(String(item["reason"])).is_equal("too_expensive")


# --- the reroll hook -----------------------------------------------------------------------------

func test_without_a_free_reroll_the_hook_refuses() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(7)
	Merchant.open_visit(state, 20, ctx)
	assert_int(Merchant.rerolls_left(state, ctx)).is_equal(0)
	assert_str(String(Merchant.reroll(state, ctx)["reason"])).is_equal("no_rerolls")


func test_a_free_reroll_redraws_the_unsold_slots_deterministically_and_only_once() -> void:
	var ctx: Dictionary = _ctx(20, 1)
	var run_a: RunState = _state(7, 900)
	var run_b: RunState = _state(7, 900)
	for state: RunState in [run_a, run_b]:
		Merchant.open_visit(state, 20, ctx)
		var visit: Dictionary = state.merchant_visit
		assert_bool(bool(Merchant.buy_relic(state, String(visit["relics"][0]), ctx)["ok"])).is_true()
		assert_bool(bool(Merchant.buy_card(state, String(visit["cards"][1]), ctx)["ok"])).is_true()
	var before: Dictionary = run_a.merchant_visit.duplicate(true)
	assert_int(Merchant.rerolls_left(run_a, ctx)).is_equal(1)
	assert_bool(bool(Merchant.reroll(run_a, ctx)["ok"])).is_true()
	assert_bool(bool(Merchant.reroll(run_b, ctx)["ok"])).is_true()
	assert_dict(run_a.merchant_visit).is_equal(run_b.merchant_visit)  # seeded
	var after: Dictionary = run_a.merchant_visit
	assert_int(int(after["rerolls_used"])).is_equal(1)
	assert_str(String(after["relics"][0])).is_equal(String(before["relics"][0]))  # the sold slots stay
	assert_str(String(after["cards"][1])).is_equal(String(before["cards"][1]))
	assert_int((after["relics"] as Array).size()).is_equal(3)
	assert_int(_unique(after["relics"])).is_equal(3)
	assert_int(_unique(after["cards"])).is_equal(3)
	assert_bool(str(after["relics"]) != str(before["relics"]) or str(after["cards"]) != str(before["cards"])).is_true()
	assert_array(after["sold_relics"]).is_equal(before["sold_relics"])
	for relic_id: String in after["relics"]:
		assert_int(run_a.relics.count(relic_id)).is_less_equal(1)
	assert_int(Merchant.rerolls_left(run_a, ctx)).is_equal(0)
	assert_str(String(Merchant.reroll(run_a, ctx)["reason"])).is_equal("no_rerolls")


# --- RunState ------------------------------------------------------------------------------------

func test_run_state_round_trips_the_merchant_fields_and_a_mid_visit_stock() -> void:
	var ctx: Dictionary = _ctx(20, 1)
	var state: RunState = _full_state(7, 900)
	Merchant.open_visit(state, 20, ctx)
	var visit: Dictionary = state.merchant_visit
	Merchant.buy_relic(state, String(visit["relics"][1]), ctx)
	Merchant.buy_card(state, String(visit["cards"][0]), ctx)
	Merchant.buy_removal(state, RunChoices.removable_card_ids(state, ctx)[0], ctx)
	Merchant.reroll(state, ctx)
	var restored: RunState = RunState.from_json(state.to_json())
	assert_object(restored).is_not_null()
	assert_bool(state.equals(restored)).override_failure_message("state != restored\n%s\n%s" % [state.to_json(), restored.to_json()]).is_true()
	assert_dict(restored.merchant_visit).is_equal(state.merchant_visit)
	assert_int(restored.merchant_removals).is_equal(1)
	assert_int(restored.gold_spent_merchant).is_equal(state.gold_spent_merchant)
	assert_int(typeof(restored.merchant_visit["node"])).is_equal(TYPE_INT)
	assert_int(typeof(restored.merchant_visit["rerolls_used"])).is_equal(TYPE_INT)
	# reopening the visit after the restore keeps the same stock
	assert_dict(Merchant.open_visit(restored, 20, ctx)).is_equal(state.merchant_visit)


func test_equals_sees_each_merchant_field() -> void:
	var ctx: Dictionary = _ctx()
	var a: RunState = _state(7)
	var b: RunState = RunState.from_json(a.to_json())
	assert_bool(a.equals(b)).is_true()
	b.merchant_removals = 1
	assert_bool(a.equals(b)).is_false()
	b = RunState.from_json(a.to_json())
	b.gold_spent_merchant = 5
	assert_bool(a.equals(b)).is_false()
	b = RunState.from_json(a.to_json())
	Merchant.open_visit(b, 20, ctx)
	assert_bool(a.equals(b)).is_false()


func test_an_old_save_without_merchant_fields_loads_with_defaults() -> void:
	var data: Dictionary = _state(7).to_dict()
	for key: String in ["merchant_removals", "gold_spent_merchant", "merchant_visit"]:
		data.erase(key)
	var state: RunState = RunState.from_dict(data)
	assert_object(state).is_not_null()
	assert_int(state.merchant_removals).is_equal(0)
	assert_int(state.gold_spent_merchant).is_equal(0)
	assert_bool(state.merchant_visit.is_empty()).is_true()


func test_a_malformed_visit_is_dropped_and_bad_numbers_fall_back_to_zero() -> void:
	var good: Dictionary = {"node": 20, "relics": ["heavy_sigh"], "cards": ["a"], "sold_relics": [], "sold_cards": [], "rerolls_used": 0}
	var broken_cases: Array = [
		"not an object", {"node": 20}, {"node": 20, "relics": "x", "cards": [], "sold_relics": [], "sold_cards": [], "rerolls_used": 0},
		{"node": 20, "relics": [5], "cards": [], "sold_relics": [], "sold_cards": [], "rerolls_used": 0},
		{"node": "x", "relics": [], "cards": [], "sold_relics": [], "sold_cards": [], "rerolls_used": 0},
	]
	for bad: Variant in broken_cases:
		var data: Dictionary = _state(7).to_dict()
		data["merchant_visit"] = bad
		var state: RunState = RunState.from_dict(data)
		assert_object(state).is_not_null()
		assert_bool(state.merchant_visit.is_empty()).override_failure_message("kept %s" % str(bad)).is_true()
	var data2: Dictionary = _state(7).to_dict()
	data2["merchant_visit"] = good
	data2["merchant_removals"] = -3
	data2["gold_spent_merchant"] = "lots"
	var loaded: RunState = RunState.from_dict(data2)
	assert_int(loaded.merchant_removals).is_equal(0)
	assert_int(loaded.gold_spent_merchant).is_equal(0)
	assert_bool(loaded.merchant_visit.is_empty()).is_false()
