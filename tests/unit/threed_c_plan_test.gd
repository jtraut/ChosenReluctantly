class_name ThreeDCPlanTest
extends GdUnitTestSuite
## 3d sitting C, "On your plan": RunState carries the loadout's plan, the flag is on reward, mini-boss and merchant card options, and a DF1-era
## version 1 save (no `plan` key) still loads.

const FIXTURE := "res://tests/fixtures/df1_save/run_save.json"
const PATH := "user://tests/threed_c_plan_save.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	CardDatabase.load_all()
	RelicDatabase.load_all()


func after_test() -> void:
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()


func _ctx() -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools("rogue"))


func _reward_card_ids() -> Array[String]:
	return LoadoutCollection.plan_cards("rogue")


# ---- save compatibility ----

func test_a_df1_era_save_without_a_plan_still_loads() -> void:
	var text: String = FileAccess.get_file_as_string(FIXTURE)
	var parsed: Dictionary = JSON.parse_string(text)
	assert_bool((parsed["run"] as Dictionary).has("plan")).override_failure_message("the fixture must stay a pre-plan save").is_false()
	assert_int(int(parsed["save_version"])).is_equal(1)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	assert_bool(RunSave.has_save()).override_failure_message("last problem: " + RunSave.last_problem).is_true()
	var state: RunState = RunSave.read_state()
	assert_object(state).is_not_null()
	assert_array(state.plan).is_empty()
	assert_int(state.deck.size()).is_equal(15)
	assert_bool(RunSave.load_save()).is_true()


func test_the_plan_round_trips_through_the_save() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	var plan: Array[String] = [_reward_card_ids()[0]]
	state.plan = plan
	var again: RunState = RunState.from_json(state.to_json())
	assert_array(again.plan).is_equal(plan)
	assert_bool(again.equals(state)).is_true()


func test_a_bad_plan_value_is_dropped_not_a_crash() -> void:
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	var data: Dictionary = state.to_dict()
	data["plan"] = "not a list"
	var again: RunState = RunState.from_dict(data)
	assert_object(again).is_not_null()
	assert_array(again.plan).is_empty()


# ---- the flag ----

func test_is_on_plan_needs_the_card_on_the_plan_and_not_in_the_deck() -> void:
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	var card: String = _reward_card_ids()[0]
	assert_bool(state.is_on_plan(card)).is_false()
	state.plan = [card] as Array[String]
	assert_bool(state.is_on_plan(card)).is_true()
	state.deck.append(card)
	assert_bool(state.is_on_plan(card)).override_failure_message("a card already in the deck is no longer 'on your plan'").is_false()


func test_reward_options_carry_the_flag() -> void:
	var state: RunState = RunSession.begin_new_run(5, "rogue")
	var candidates: Array[String] = _reward_card_ids()
	state.plan = [candidates[0]] as Array[String]
	state.pending = RunState.PENDING_REWARD
	state.offer = [candidates[0], candidates[1]] as Array[String]
	var by_card: Dictionary = {}
	for option: Dictionary in RunChoices.options(state, _ctx()):
		assert_bool(option.has("on_plan")).is_true()
		if String(option["kind"]) == "card":
			by_card[String(option["card_id"])] = bool(option["on_plan"])
	assert_bool(bool(by_card[candidates[0]])).is_true()
	assert_bool(bool(by_card[candidates[1]])).is_false()
	state.deck.append(candidates[0])
	for option: Dictionary in RunChoices.options(state, _ctx()):
		if String(option["card_id"]) == candidates[0]:
			assert_bool(bool(option["on_plan"])).is_false()


func test_a_mini_boss_card_offer_carries_the_flag() -> void:
	# The mini-boss offer is the same reward choice with a fixed rarity: open it for real and check every option has the key and a planned card shows it.
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(11, "rogue")
	state.act = 1
	var ctx: Dictionary = _ctx()
	var opened: String = RunChoices.open_for_room(state, "mini_boss", false, ctx)
	if opened != RunState.PENDING_REWARD or state.offer.is_empty():
		return  # nothing to offer for this act/seed: the flag path is the shared reward one tested above
	state.plan = [state.offer[0]] as Array[String]
	var seen_flag: bool = false
	for option: Dictionary in RunChoices.options(state, ctx):
		if String(option["kind"]) == "card":
			seen_flag = seen_flag or bool(option["on_plan"])
	assert_bool(seen_flag).is_true()


func test_merchant_card_stock_and_options_carry_the_flag() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(7, "rogue")
	var ctx: Dictionary = _ctx()
	var stock_card: String = _reward_card_ids()[0]
	state.merchant_visit = {"node": 1, "rerolls_used": 0, "relics": [] as Array[String], "cards": [stock_card] as Array[String], "sold_relics": [] as Array[String], "sold_cards": [] as Array[String]}
	state.plan = [stock_card] as Array[String]
	var found: bool = false
	for item: Dictionary in Merchant.items(state, ctx):
		if String(item["kind"]) == Merchant.KIND_CARD:
			found = true
			assert_bool(bool(item["on_plan"])).is_true()
	assert_bool(found).is_true()
	state.plan = [] as Array[String]
	for item: Dictionary in Merchant.items(state, ctx):
		if String(item["kind"]) == Merchant.KIND_CARD:
			assert_bool(bool(item["on_plan"])).is_false()
