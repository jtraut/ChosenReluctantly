class_name Sim2a2Test
extends GdUnitTestSuite
## SIM2a-2: the formulated bot's route (FormulatedRoute), merchant and removal choices (FormulatedShop) and the dispatcher (FormulatedBot).
## Pure logic over hand-built maps, option lists and run states; no scene.

const BURN_DECK: Array[String] = ["fire_ember_whatever", "fire_fine_burn_then", "fire_kindling", "fire_blaze_and_bail", "fire_scorched_earth", "rogue_quick_slash", "neutral_deep_sigh"]
const WEAK_DECK: Array[String] = ["rogue_quick_slash", "neutral_deep_sigh", "rogue_nap_time"]


func before_test() -> void:
	FormulatedBot.off = {}


func after_test() -> void:
	FormulatedBot.off = {}


## Room 1 (node 1), then one node per type at room 2 (ids 2 combat, 3 rest, 4 elite, 5 merchant, 6 relic_room), then the boss (7). The pick is at node 1.
func _map() -> Dictionary:
	var nodes: Array = [{"id": 1, "room": 1, "column": 0, "type": "combat", "wave_id": "w"}]
	var types: Array[String] = ["combat", "rest", "elite", "merchant", "relic_room"]
	var edges: Array = []
	for i: int in range(types.size()):
		nodes.append({"id": 2 + i, "room": 2, "column": i, "type": types[i], "wave_id": "w"})
		edges.append([1, 2 + i])
		edges.append([2 + i, 7])
	nodes.append({"id": 7, "room": 3, "column": 0, "type": "boss", "wave_id": "w"})
	return {"nodes": nodes, "edges": edges}


func _pick(hp: float, gold: int, deck: Array[String]) -> int:
	return FormulatedRoute.pick(_map(), [1] as Array[int], hp, gold, deck)


func test_low_hp_takes_the_rest() -> void:
	assert_int(_pick(0.3, 0, BURN_DECK)).is_equal(3)
	assert_int(_pick(0.3, 500, BURN_DECK)).is_equal(3)  # rest outranks the merchant


func test_a_strong_deck_at_good_hp_takes_the_elite() -> void:
	assert_float(FormulatedRoute.build_share(BURN_DECK)).is_greater_equal(float(FormulatedRoute.THRESHOLDS["ELITE_MIN_BUILD"]))
	assert_int(_pick(1.0, 0, BURN_DECK)).is_equal(4)


func test_a_weak_deck_or_low_hp_avoids_the_elite_and_grows() -> void:
	assert_float(FormulatedRoute.build_share(WEAK_DECK)).is_less(float(FormulatedRoute.THRESHOLDS["ELITE_MIN_BUILD"]))
	assert_int(_pick(1.0, 0, WEAK_DECK)).is_equal(6)  # the relic room: the most growth, no elite
	assert_int(_pick(0.6, 0, BURN_DECK)).is_equal(6)  # strong deck but HP under the elite bar


func test_gold_for_something_takes_the_merchant() -> void:
	assert_int(_pick(1.0, int(FormulatedRoute.THRESHOLDS["MERCHANT_MIN_GOLD"]), WEAK_DECK)).is_equal(5)
	assert_int(_pick(1.0, int(FormulatedRoute.THRESHOLDS["MERCHANT_MIN_GOLD"]) - 1, WEAK_DECK)).is_equal(6)


func test_the_route_is_deterministic_and_follows_the_walked_prefix() -> void:
	assert_int(_pick(0.4, 90, BURN_DECK)).is_equal(_pick(0.4, 90, BURN_DECK))
	# A prefix that matches no path gives -1; the last pick (node 7 from room 2) is the boss.
	assert_int(FormulatedRoute.pick(_map(), [1, 2] as Array[int], 1.0, 0, WEAK_DECK)).is_equal(7)
	assert_int(FormulatedRoute.pick(_map(), [9] as Array[int], 1.0, 0, WEAK_DECK)).is_equal(-1)


func test_fill_route_runs_to_the_boss_on_the_lowest_columns() -> void:
	assert_array(FormulatedRoute.fill_route(_map(), [1, 4] as Array[int])).is_equal([1, 4, 7])


# ---- the shop ----

func _state(deck: Array[String], gold: int, relics: Array[String] = []) -> RunState:
	var state := RunState.new_run(1, deck, 3)
	state.gold = gold
	state.relics = relics
	return state


func _shop(cards: Array[String]) -> Array:
	var options: Array = []
	for card_id: String in cards:
		options.append({"id": "buy_card:" + card_id, "kind": "buy_card", "card_id": card_id, "enabled": true, "price": 55})
	options.append({"id": "buy_removal", "kind": "buy_removal", "enabled": true, "price": 50})
	options.append({"id": "merchant_leave", "kind": "back", "enabled": true})
	return options


func _big_burn_deck() -> Array[String]:
	var out: Array[String] = []
	for _i: int in range(3):
		out.append_array(BURN_DECK)
	return out


func test_the_shop_buys_the_top_scoring_card_it_can_afford() -> void:
	var state: RunState = _state(BURN_DECK, 200)
	var options: Array = _shop(["rogue_exsanguinate", "fire_slow_burn"])
	assert_str(FormulatedShop.shop_choice(options, state, 7)).is_equal("buy_card:fire_slow_burn")
	# The card it cannot afford is not an option the model enables: with it disabled the other one is taken.
	(options[1] as Dictionary)["enabled"] = false
	assert_str(FormulatedShop.shop_choice(options, state, 7)).is_not_equal("buy_card:fire_slow_burn")


func test_the_shop_leaves_when_nothing_clears_its_bar() -> void:
	var state: RunState = _state(WEAK_DECK, 0)
	var options: Array = [{"id": "buy_card:rogue_exsanguinate", "kind": "buy_card", "card_id": "rogue_exsanguinate", "enabled": false}, {"id": "merchant_leave", "kind": "back", "enabled": true}]
	assert_str(FormulatedShop.shop_choice(options, state, 3)).is_equal("merchant_leave")


func test_the_shop_removes_a_card_from_a_bloated_deck_but_not_a_small_one() -> void:
	var big: RunState = _state(_big_burn_deck(), 200)
	assert_str(FormulatedShop.shop_choice([{"id": "buy_removal", "kind": "buy_removal", "enabled": true}, {"id": "merchant_leave", "kind": "back", "enabled": true}], big, 7)).is_equal("buy_removal")
	var small: RunState = _state(BURN_DECK, 200)
	assert_str(FormulatedShop.shop_choice([{"id": "buy_removal", "kind": "buy_removal", "enabled": true}, {"id": "merchant_leave", "kind": "back", "enabled": true}], small, 7)).is_equal("merchant_leave")


func test_the_removal_list_takes_the_lowest_scoring_card() -> void:
	var deck: Array[String] = _big_burn_deck()
	deck.append("rogue_exsanguinate")  # a Bleed payoff nothing in a Burn deck can meet: the lowest score
	var state: RunState = _state(deck, 200)
	var options: Array = []
	for card_id: String in ["fire_kindling", "rogue_exsanguinate", "fire_ember_whatever"]:
		options.append({"id": "remove:" + card_id, "kind": "remove", "card_id": card_id, "enabled": true, "curse": false, "count": 1})
	options.append({"id": "back", "kind": "back"})
	assert_str(FormulatedShop.removal_choice(options, state)).is_equal("remove:rogue_exsanguinate")
	(options[1] as Dictionary)["enabled"] = false  # a card the rules block is not taken
	assert_str(FormulatedShop.removal_choice(options, state)).is_not_equal("remove:rogue_exsanguinate")
	options.insert(0, {"id": "remove:curse_x", "kind": "remove", "card_id": "fire_kindling", "enabled": true, "curse": true, "count": 1})
	assert_str(FormulatedShop.removal_choice(options, state)).is_equal("remove:curse_x")  # a curse first


func test_the_shop_is_deterministic() -> void:
	var state: RunState = _state(_big_burn_deck(), 300)
	var options: Array = _shop(["fire_slow_burn", "rogue_exsanguinate", "fire_kindling"])
	assert_str(FormulatedShop.shop_choice(options, state, 7)).is_equal(FormulatedShop.shop_choice(options, state, 7))


# ---- the dispatcher ----

func test_only_the_formulated_profile_answers_every_other_profile_falls_through() -> void:
	var state: RunState = _state(BURN_DECK, 200)
	var reward: Array = [{"id": "pick:fire_slow_burn", "kind": "card", "card_id": "fire_slow_burn", "enabled": true}, {"id": "skip", "kind": "skip", "enabled": true}]
	for profile: String in ["", "plan", "report"]:
		for choice: String in [RunState.PENDING_REWARD, RunState.PENDING_RELIC, RunState.PENDING_RELIC_SWAP, RunState.PENDING_MERCHANT, RunState.PENDING_MERCHANT_REMOVE, RunState.PENDING_NODE]:
			assert_str(FormulatedBot.choose(profile, true, choice, reward, state, 7)).is_equal("")
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_REWARD, reward, state, 7)).is_equal(DraftPolicy.reward_choice(reward, state.deck, 7))
	assert_str(FormulatedBot.choose("formulated", false, RunState.PENDING_NODE, [], state, 7)).is_equal("")  # -Route first keeps the first route


func test_the_per_run_report_names_the_dominant_self_status() -> void:
	var charge_deck: Array[String] = ["wizard_footnotes", "wizard_literature_review", "fire_kindling"]
	var summary: Dictionary = DraftPolicy.deck_summary(charge_deck)
	assert_str(String(summary["self_status"])).is_equal("charge")
	assert_float(float(summary["self_share"])).is_greater(0.5)
	assert_str(String(DraftPolicy.deck_summary(WEAK_DECK)["self_status"])).is_not_equal("charge")


# ---- SIM2a-3 attribution switches ----

func test_the_off_switches_hand_the_shop_and_removals_back() -> void:
	var state: RunState = _state(BURN_DECK, 200)
	var shop: Array = [{"id": "merchant_leave", "kind": "back", "enabled": true}]
	var removals: Array = [{"id": "remove:fire_kindling", "kind": "remove", "card_id": "fire_kindling", "enabled": true}, {"id": "back", "kind": "back", "enabled": true}]
	FormulatedBot.off = {}
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_MERCHANT, shop, state, 7)).is_equal("merchant_leave")
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_REST_REMOVE, removals, state, 7)).is_not_equal("")
	FormulatedBot.off = {"shop": true}
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_MERCHANT, shop, state, 7)).is_equal("")
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_MERCHANT_REMOVE, removals, state, 7)).is_equal("")
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_REST_REMOVE, removals, state, 7)).is_not_equal("")  # shop off leaves rests alone
	FormulatedBot.off = {"removal": true}
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_REST_REMOVE, removals, state, 7)).is_equal("")
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_EVENT_REMOVE, removals, state, 7)).is_equal("")
	var with_removal: Array = [{"id": "buy_removal", "kind": "buy_removal", "enabled": true}, {"id": "merchant_leave", "kind": "back", "enabled": true}]
	var big: Array[String] = []
	for i: int in range(20):
		big.append("rogue_nap_time")
	state.deck = big
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_MERCHANT, with_removal, state, 7)).is_equal("merchant_leave")
	FormulatedBot.off = {}
	assert_str(FormulatedBot.choose("formulated", true, RunState.PENDING_MERCHANT, with_removal, state, 7)).is_equal("buy_removal")

