class_name Hp1QaTest
extends GdUnitTestSuite
## HP1 qa: gaps in the build's own suite. The merchant buy and the cap swap run through the real Merchant API; the elite counter is
## checked against the real generated room types (an elite counts, a mini-boss does not).

const FLAT := "wellness_pack"
const PER_ELITE := "performance_review"


func before_test() -> void:
	RelicDatabase.load_all()


func after() -> void:
	LoadoutSession.reset()


func _shop_state(relics_held: Array[String], stock: Array[String], cap: int) -> Array:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	var state: RunState = RunState.new_run(7, CharacterDatabase.starting_deck("rogue"), 3, "rogue")
	state.max_hp = 30.0
	state.hp = 20.0
	state.gold = 1000
	state.room_index = 4
	for id: String in relics_held:
		state.add_relic(id)
	assert_str(RunChoices.open_for_room(state, "merchant", false, ctx)).is_equal(RunState.PENDING_MERCHANT)
	(state.merchant_visit["relics"] as Array).clear()
	(state.merchant_visit["relics"] as Array).append_array(stock)
	return [state, ctx]


func test_a_merchant_buy_of_the_flat_relic_adds_max_hp_and_heals() -> void:
	var shop: Array = _shop_state([] as Array[String], [FLAT] as Array[String], 20)
	var state: RunState = shop[0]
	var result: Dictionary = Merchant.buy_relic(state, FLAT, shop[1])
	assert_bool(bool(result["ok"])).override_failure_message(str(result)).is_true()
	assert_float(state.max_hp).is_equal(34.0)
	assert_float(state.hp).is_equal(24.0)


func test_a_refused_merchant_buy_gives_no_max_hp() -> void:
	var shop: Array = _shop_state([] as Array[String], [FLAT] as Array[String], 20)
	var state: RunState = shop[0]
	state.gold = 0
	var result: Dictionary = Merchant.buy_relic(state, FLAT, shop[1])
	assert_bool(bool(result["ok"])).is_false()
	assert_float(state.max_hp).is_equal(30.0)
	assert_bool(state.relic_max_hp.is_empty()).is_true()


func test_a_cap_swap_through_the_merchant_moves_the_boost_to_the_new_relic() -> void:
	var shop: Array = _shop_state([FLAT] as Array[String], [PER_ELITE] as Array[String], 1)
	var state: RunState = shop[0]
	assert_float(state.max_hp).is_equal(34.0)
	var refused: Dictionary = Merchant.buy_relic(state, PER_ELITE, shop[1])
	assert_bool(bool(refused["ok"])).is_false()  # at the cap it asks for a give-up first
	assert_float(state.max_hp).is_equal(34.0)
	var swapped: Dictionary = Merchant.buy_relic(state, PER_ELITE, shop[1], FLAT)
	assert_bool(bool(swapped["ok"])).override_failure_message(str(swapped)).is_true()
	assert_float(state.max_hp).is_equal(30.0)  # the +4 left with the relic
	assert_float(state.hp).is_equal(24.0)  # 20 + the heal of 4, clamped to 30: the heal is kept, nothing is taken back
	assert_bool(state.relics_given_up.has(FLAT)).is_true()
	assert_float(RunMaxHp.pending_total(state)).is_equal(0.0)


func test_giving_up_a_loaded_per_elite_relic_through_the_cap_swap_removes_all_its_gains() -> void:
	var shop: Array = _shop_state([PER_ELITE] as Array[String], [FLAT] as Array[String], 1)
	var state: RunState = shop[0]
	for i in range(5):
		RunMaxHp.on_room_cleared(state, "elite")
	assert_float(state.max_hp).is_equal(35.0)
	var swapped: Dictionary = Merchant.buy_relic(state, FLAT, shop[1], PER_ELITE)
	assert_bool(bool(swapped["ok"])).override_failure_message(str(swapped)).is_true()
	assert_float(state.max_hp).is_equal(34.0)  # 30 base + the flat 4
	assert_bool(state.hp <= state.max_hp).is_true()


func test_the_room_type_names_the_run_uses_keep_elite_and_mini_boss_separate() -> void:
	assert_array(MapConfig.NODE_TYPES).contains(["elite", "mini_boss"])  # distinct node types, so room["type"] tells them apart
	assert_array(MapConfig.ELITE_LIKE_TYPES).contains(["elite", "mini_boss"])
	var rules: Array[Dictionary] = RunMaxHp.clear_rules(RelicDatabase.get_relic(PER_ELITE))
	assert_int(rules.size()).is_equal(1)
	assert_str(String(rules[0]["room_type"])).is_equal("elite")
	var state: RunState = RunState.new_run(3, ["x"] as Array[String], 3)
	state.max_hp = 30.0
	state.hp = 30.0
	state.add_relic(PER_ELITE)
	assert_dict(RunMaxHp.on_room_cleared(state, "mini_boss")).is_empty()
	assert_dict(RunMaxHp.on_room_cleared(state, "elite")).is_not_empty()


func test_losing_the_flat_relic_at_one_hp_keeps_hp_at_least_one() -> void:
	var state: RunState = RunState.new_run(3, ["x"] as Array[String], 3)
	state.max_hp = 30.0
	state.hp = 1.0
	state.add_relic(FLAT)
	state.give_up_relic(FLAT)
	assert_float(state.hp).is_equal(5.0)  # 1 + the heal of 4 stays; the clamp only trims above the new max
	assert_float(state.max_hp).is_equal(30.0)
