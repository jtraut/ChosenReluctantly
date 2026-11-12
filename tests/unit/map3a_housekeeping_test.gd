class_name Map3aHousekeepingTest
extends GdUnitTestSuite
## MAP3 sitting A, step 4: the MAP2 fold-ins. `--run-node` / `--run-gold` / `--merchant` refusals (MapLaunch.resolve_run_args), Merchant.items() at the relic
## cap with nothing to give up, and Liquidate Assets refreshing on every purchase.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func before_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false  # GamePause.reset() forgets its flag but not the tree; a class pick left open by a test must not leak a paused tree


# ---- launch flags ----

func _resolve(args: Array) -> Dictionary:
	return MapLaunch.resolve_run_args(PackedStringArray(args))


func test_good_run_node_and_run_gold_values_resolve() -> void:
	var result: Dictionary = _resolve(["--run-node=33", "--run-gold=200", "--merchant"])
	assert_array(result["errors"]).is_empty()
	assert_int(int(result["node"])).is_equal(33)
	assert_int(int(result["gold"])).is_equal(200)
	var none: Dictionary = _resolve(["--run-seed=7"])
	assert_array(none["errors"]).is_empty()
	assert_int(int(none["node"])).is_equal(-1)
	assert_int(int(none["gold"])).is_equal(-1)
	assert_int(int(_resolve(["--run-node=0"])["node"])).is_equal(0)


func test_bad_run_node_and_run_gold_values_are_refused() -> void:
	for flag: String in ["--run-node", "--run-gold"]:
		for bad: String in [flag, flag + "=", flag + "=abc", flag + "=-3", flag + "=1.5", flag + "=3x", flag + "= "]:
			var result: Dictionary = _resolve([bad])
			assert_array(result["errors"]).override_failure_message("'%s' was accepted" % bad).is_not_empty()
			assert_int(int(result["node"])).is_equal(-1)
			assert_int(int(result["gold"])).is_equal(-1)
		assert_array(_resolve(["%s=1" % flag, "%s=2" % flag])["errors"]).override_failure_message(flag + " twice").is_not_empty()


func test_merchant_flag_takes_no_value_and_may_not_repeat() -> void:
	assert_array(_resolve(["--merchant"])["errors"]).is_empty()
	assert_array(_resolve(["--merchant=on"])["errors"]).is_not_empty()
	assert_array(_resolve(["--merchant=", "--run-seed=1"])["errors"]).is_not_empty()
	assert_array(_resolve(["--merchant", "--merchant"])["errors"]).is_not_empty()
	assert_array(_resolve(["--merchants"])["errors"]).is_empty()  # a different flag, not ours to judge


func test_one_bad_flag_clears_the_good_one() -> void:
	var result: Dictionary = _resolve(["--run-node=33", "--run-gold=oops"])
	assert_array(result["errors"]).is_not_empty()
	assert_int(int(result["node"])).is_equal(-1)


# ---- Merchant.items() at the cap ----

func _boss_relic() -> Dictionary:
	return {"id": "test_boss_relic", "name": "Test Boss", "pool": "neutral", "rarity": "boss", "sources": ["mini_boss"], "keywords": [],
			"modifiers": [], "triggers": [], "rule_text": "x", "flavor_text": "y"}


func test_items_marks_a_relic_unbuyable_at_the_cap_when_nothing_can_be_given_up() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var relics: Dictionary = ctx["relics"]
	relics["max_owned"] = 1
	relics["catalog"] = (relics["catalog"] as Array) + [_boss_relic()]
	(relics["by_id"] as Dictionary)["test_boss_relic"] = _boss_relic()
	var state: RunState = RunState.new_run(11, CharacterDatabase.starting_deck("rogue"), 3)
	state.gold = 1000
	state.relics = ["test_boss_relic"] as Array[String]
	Merchant.open_visit(state, 5, ctx)
	var seen: int = 0
	for item: Dictionary in Merchant.items(state, ctx):
		if String(item["kind"]) != Merchant.KIND_RELIC:
			continue
		seen += 1
		assert_bool(bool(item["can_buy"])).is_false()
		assert_str(String(item["reason"])).is_equal("none_giveable")
		assert_bool(bool(item["needs_giveup"])).is_false()
	assert_int(seen).is_greater(0)
	# the same refusal buy_relic gives
	var first_relic: String = String((state.merchant_visit["relics"] as Array)[0])
	assert_str(String(Merchant.buy_relic(state, first_relic, ctx)["reason"])).is_equal("none_giveable")
	# with a relic that can be given up the item is buyable and asks for the swap
	state.relics = ["heavy_sigh"] as Array[String]
	for item: Dictionary in Merchant.items(state, ctx):
		if String(item["kind"]) == Merchant.KIND_RELIC and String(item["reason"]).is_empty():
			assert_bool(bool(item["needs_giveup"])).is_true()


# ---- Liquidate Assets ----

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func test_liquidate_assets_refreshes_after_a_card_purchase_not_only_a_relic_purchase() -> void:
	var state: RunState = null
	for seed_value in range(1, 200):
		var map: Dictionary = MapGenerator.generate(seed_value)
		if map.is_empty():
			continue
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) == "merchant" and state == null:
				var trail: Array[int] = [int(entry["id"])]
				while int(MapGraph.node(map, trail[0])["room"]) > 1:
					trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
				state = RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
				state.map = map
				state.path = trail
				state.room_index = trail.size() - 1
		if state != null:
			break
	state.gold = 500
	state.relics = ["liquidate_assets"] as Array[String]
	RunSession.current = state
	var main: Main = _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	assert_bool(controller.merchant_open()).is_true()
	assert_float(main.player.stat_modifiers.apply("damage_mult", 1.0)).is_equal_approx(1.0, 0.00001)
	var bought: int = 0
	for item: Dictionary in (controller.merchant_view()["items"] as Array):
		if String(item["kind"]) == "card" and bool(item["can_buy"]) and bought < 2:
			assert_bool(bool(controller.buy_card(String(item["id"]))["ok"])).is_true()
			bought += 1
	assert_int(bought).is_equal(2)
	assert_int(state.gold_spent_merchant).is_equal(2 * int((RunConfig.get_config()["merchant"]["card_prices"] as Dictionary)["common"]))
	# 110 gold spent on cards alone is 2% (1% per 50, MAP3b card price 55 each): live at once, with no relic bought
	assert_float(main.player.stat_modifiers.apply("damage_mult", 1.0)).is_equal_approx(1.0 + 0.01 * float(state.gold_spent_merchant / 50), 0.00001)
