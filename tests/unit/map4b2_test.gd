class_name Map4b2Test
extends GdUnitTestSuite
## MAP4 sitting B2: the rest of the event outcomes (start_fight, chance, stat_mod, merchant_discount, sacrifice_relic), the owns_relic requirement, the
## sacrificed_plus_one tier, and sacrifice_cost relics from every source (the offer filter, the multi-give-up step, the merchant). Every event and relic here is a
## fixture (tests/fixtures/events_b2, or built in the test); nothing ships with these yet and the `event` weight is 0, so shipped runs are unchanged.

const FIXTURES := "res://tests/fixtures/events_b2"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const SAVE_PATH := "user://tests/map4b2_save.json"
const TIER_WEIGHTS: Dictionary = {"tier1": 1.0, "tier2": 1.0, "tier3": 1.0}


func before_test() -> void:
	RunSession.clear()
	RunSession.forced_event = ""
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()
	assert_array(EventDatabase.load_all(FIXTURES)).is_empty()
	DirAccess.make_dir_recursive_absolute("user://tests")


func after_test() -> void:
	EventDatabase.load_all()  # a fixture folder must not leak into later suites
	RelicDatabase.load_all()  # nor an injected relic
	RunSession.clear()
	RunSession.forced_event = ""
	RunSave.delete_save()
	RunSave.reset()
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


# --- helpers ---------------------------------------------------------------------------------------

func _relic(id: String, tier: String, sources: Array, cost: int = 0) -> Dictionary:
	var relic: Dictionary = {"id": id, "name": id.capitalize(), "pool": "neutral", "rarity": tier, "sources": sources, "rule_text": "rule of " + id, "flavor_text": "", "keywords": [], "modifiers": []}
	if cost > 0:
		relic["sacrifice_cost"] = cost
	return relic


func _catalog() -> Array:
	var list: Array = []
	var normal: Array = ["elite", "relic_room", "merchant"]
	for letter: String in ["a", "b", "c", "d"]:
		list.append(_relic("n1" + letter, "tier1", normal))
		list.append(_relic("n2" + letter, "tier2", normal))
	for letter: String in ["a", "b", "c", "d"]:
		list.append(_relic("n3" + letter, "tier3", normal))
	list.append(_relic("sac1", "tier3", normal, 1))  # asks for one relic
	list.append(_relic("sac2", "tier3", normal, 2))  # asks for two
	list.append(_relic("boss1", "boss", ["mini_boss"]))
	return list


## The shipped context with the fixture relic catalog and a Rogue's pools (the merchant draws its cards from them).
func _ctx() -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var relics: Dictionary = ctx["relics"]
	relics["catalog"] = _catalog()
	var by_id: Dictionary = {}
	for relic: Variant in _catalog():
		by_id[String((relic as Dictionary)["id"])] = relic
	relics["by_id"] = by_id
	return ctx


func _state(act: int = 3, run_seed: int = 11, room: int = 3) -> RunState:
	var state: RunState = RunState.new_run(run_seed, CharacterDatabase.starting_deck("rogue"), 3, "rogue")
	state.act = act
	state.room_index = room
	state.hp = 30.0
	state.max_hp = 30.0
	state.gold = 500
	return state


func _hold(state: RunState, ids: Array) -> void:
	for id: Variant in ids:
		state.relics.append(String(id))


## An event made on the spot with `outcomes` as its first choice (and a leave choice), opened on `state`.
func _adhoc(state: RunState, ctx: Dictionary, outcomes: Array, requires: Variant = null) -> void:
	var first: Dictionary = {"label": "Do it", "outcomes": outcomes}
	if requires != null:
		first["requires"] = requires
	var event: Dictionary = {"id": "adhoc", "name": "Adhoc", "flavor": "Made in a test.", "acts": [1, 2, 3], "choices": [first, {"label": "Leave", "outcomes": []}]}
	(ctx["events"]["catalog"] as Dictionary)["adhoc"] = event
	state.event_id = "adhoc"
	state.pending = RunState.PENDING_EVENT


func _pick(state: RunState, ctx: Dictionary, index: int = 0) -> Dictionary:
	return RunChoices.apply(state, "%s:%d" % [EventEngine.OPTION_CHOICE, index], ctx)


func _ids_of(options: Array) -> Array[String]:
	var ids: Array[String] = []
	for option: Variant in options:
		ids.append(String((option as Dictionary)["id"]))
	return ids


func _tier_of(relic_id: String) -> String:
	for relic: Variant in _catalog():
		if String((relic as Dictionary)["id"]) == relic_id:
			return String((relic as Dictionary)["rarity"])
	return ""


func _option(options: Array, option_id: String) -> Dictionary:
	for option: Variant in options:
		if String((option as Dictionary)["id"]) == option_id:
			return option as Dictionary
	return {}


const SACRIFICE_PICK: Dictionary = {"type": "sacrifice_relic", "select": "pick", "min_tier": 1, "max_tier": 2}
const PLUS_ONE: Dictionary = {"type": "gain_relic", "tier": "sacrificed_plus_one", "count": 3, "skip": false}


# --- chance ----------------------------------------------------------------------------------------

func _gamble(state: RunState, ctx: Dictionary) -> Dictionary:
	_adhoc(state, ctx, [{"type": "chance", "p": 0.5, "win": [{"type": "gain_gold", "amount": 40}], "lose": [{"type": "lose_hp", "fraction": 0.2}]}, {"type": "gain_gold", "amount": 1}])
	return _pick(state, ctx)


func test_chance_is_seeded_so_the_same_run_state_rolls_the_same_and_both_branches_happen() -> void:
	var wins: int = 0
	var losses: int = 0
	for run_seed in range(1, 41):
		var ctx: Dictionary = _ctx()
		var state: RunState = _state(1, run_seed)
		var result: Dictionary = _gamble(state, ctx)
		var won: bool = state.gold == 541  # 500 + 40 + the 1 gold after the chance
		assert_bool(bool(((result["chance_rolls"] as Array)[0] as Dictionary)["won"])).is_equal(won)
		if won:
			wins += 1
		else:
			losses += 1
			assert_float(state.hp).is_equal(24.0)  # lose 20% of 30
			assert_int(state.gold).is_equal(501)  # the outcome after the chance still ran
		var again_ctx: Dictionary = _ctx()
		var again: RunState = _state(1, run_seed)
		_gamble(again, again_ctx)
		assert_bool(again.equals(state) or again.choice_log.size() == state.choice_log.size()).is_true()
		assert_int(again.gold).is_equal(state.gold)  # a reload and a second confirm can't reroll it
	assert_int(wins).is_greater(5)
	assert_int(losses).is_greater(5)


func test_a_chance_branch_runs_ahead_of_what_follows_and_a_relic_offer_in_it_parks_the_rest() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	var branch: Array = [{"type": "gain_relic", "tier": 1, "count": 3, "skip": false}]
	_adhoc(state, ctx, [{"type": "chance", "p": 0.5, "win": branch, "lose": branch}, {"type": "gain_gold", "amount": 9}])
	var opened: Dictionary = _pick(state, ctx)
	assert_bool(bool(opened["finished"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_int(state.event_queue.size()).is_equal(1)  # the gold waits behind the branch's offer
	assert_int(state.gold).is_equal(500)
	var done: Dictionary = RunChoices.apply(state, "relic:" + state.offer[0], ctx)
	assert_bool(bool(done["finished"])).is_true()
	assert_int(state.gold).is_equal(509)


func test_the_schema_wants_a_chance_between_0_and_1_with_two_lists_and_no_nesting() -> void:
	var bad_p: Array[String] = EventSchema.validate_outcome({"type": "chance", "p": 1.0, "win": [], "lose": []})
	assert_bool(bad_p.any(func(e: String) -> bool: return e.contains("'p'"))).is_true()
	var nested: Array[String] = EventSchema.validate_outcome({"type": "chance", "p": 0.5, "win": [{"type": "chance", "p": 0.5, "win": [], "lose": []}], "lose": []})
	assert_bool(nested.any(func(e: String) -> bool: return e.contains("nested"))).is_true()
	assert_array(EventSchema.validate_outcome({"type": "chance", "p": 0.5, "win": [], "lose": []})).is_empty()


# --- stat_mod and merchant_discount ----------------------------------------------------------------

func test_stat_mod_keeps_a_permanent_run_modifier_and_it_survives_a_save() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_adhoc(state, ctx, [{"type": "stat_mod", "stat": "move_speed", "modifier_type": "multiplicative", "value": 0.05}, {"type": "stat_mod", "stat": "armor", "modifier_type": "additive", "value": 2}])
	var result: Dictionary = _pick(state, ctx)
	assert_bool(bool(result["finished"]) and bool(result["run_mods_changed"])).is_true()
	assert_array(state.run_mods).is_equal([
		{"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.05},
		{"stat": "armor", "modifier_type": "additive", "value": 2.0}])
	var back: RunState = RunState.from_json(state.to_json())
	assert_bool(back.equals(state)).is_true()
	assert_array(back.run_mods).is_equal(state.run_mods)


func test_a_damaged_run_modifier_list_is_repaired_without_a_crash() -> void:
	var state: RunState = _state(1)
	var data: Dictionary = state.to_dict()
	data["run_mods"] = [{"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.1}, {"stat": "", "modifier_type": "additive", "value": 1}, {"stat": "x", "modifier_type": "weird", "value": 1},
			{"stat": "y", "modifier_type": "additive", "value": "a lot"}, 7]
	assert_array(RunState.from_dict(data).run_mods).is_equal([{"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.1}])
	data["run_mods"] = "nope"
	assert_array(RunState.from_dict(data).run_mods).is_empty()
	data.erase("run_mods")
	assert_array(RunState.from_dict(data).run_mods).is_empty()  # an old save


func test_merchant_discount_keeps_the_larger_and_never_stacks() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_adhoc(state, ctx, [{"type": "merchant_discount", "fraction": 0.3}, {"type": "merchant_discount", "fraction": 0.5}, {"type": "merchant_discount", "fraction": 0.2}])
	_pick(state, ctx)
	assert_float(state.merchant_discount).is_equal_approx(0.5, 0.0001)
	var again: RunState = _state(1)
	again.merchant_discount = 0.6
	_adhoc(again, ctx, [{"type": "merchant_discount", "fraction": 0.4}])
	_pick(again, ctx)
	assert_float(again.merchant_discount).is_equal_approx(0.6, 0.0001)


func test_the_discount_is_taken_by_the_next_visit_only_and_the_shop_shows_and_charges_the_discounted_price() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	state.merchant_discount = 0.5
	Merchant.open_visit(state, 5, ctx)
	assert_float(state.merchant_discount).is_equal(0.0)  # used up by that visit
	assert_float(float(state.merchant_visit["discount"])).is_equal_approx(0.5, 0.0001)
	var seen_relic: bool = false
	var seen_card: bool = false
	for item: Dictionary in Merchant.items(state, ctx):
		match String(item["kind"]):
			Merchant.KIND_RELIC:
				seen_relic = true
				assert_int(int(item["base_price"])).is_equal(Merchant.relic_price(String(item["id"]), ctx))
				assert_int(int(item["price"])).is_equal(maxi(roundi(float(item["base_price"]) * 0.5), 1))
			Merchant.KIND_CARD:
				seen_card = true
				assert_int(int(item["price"])).is_equal(maxi(roundi(float(item["base_price"]) * 0.5), 1))
			Merchant.KIND_REMOVAL:
				assert_int(int(item["price"])).is_equal(int(item["base_price"]))  # removal is never discounted
				assert_int(int(item["price"])).is_equal(Merchant.removal_price(state, ctx))
	assert_bool(seen_relic and seen_card).is_true()
	# the model's option label and the charge agree
	state.pending = RunState.PENDING_MERCHANT
	var relic_id: String = String((state.merchant_visit["relics"] as Array)[0])
	var option: Dictionary = _option(RunMerchant.options(state, ctx), "buy_relic:" + relic_id)
	var price: int = int(option["price"])
	assert_str(String(option["label"])).contains("%d gold" % price)
	var gold_before: int = state.gold
	var bought: Dictionary = RunMerchant.apply(state, "buy_relic:" + relic_id, ctx)
	assert_bool(bool(bought["ok"])).is_true()
	assert_int(gold_before - state.gold).is_equal(price)
	# the next visit is full price
	Merchant.close_visit(state)
	Merchant.open_visit(state, 6, ctx)
	assert_bool(state.merchant_visit.has("discount")).is_false()
	assert_float(Merchant.discount_of(state)).is_equal(0.0)


func test_a_visit_with_a_discount_round_trips_and_a_bad_discount_is_dropped() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	state.merchant_discount = 0.4
	state.pending = RunState.PENDING_MERCHANT
	Merchant.open_visit(state, 5, ctx)
	var back: RunState = RunState.from_json(state.to_json())
	assert_bool(back.equals(state)).is_true()
	assert_float(Merchant.discount_of(back)).is_equal_approx(0.4, 0.0001)
	var data: Dictionary = state.to_dict()
	(data["merchant_visit"] as Dictionary)["discount"] = 7.0
	assert_bool(RunState.from_dict(data).merchant_visit.has("discount")).is_false()
	data["merchant_discount"] = -1.0
	assert_float(RunState.from_dict(data).merchant_discount).is_equal(0.0)
	state.merchant_discount = 0.25
	assert_float(RunState.from_json(state.to_json()).merchant_discount).is_equal_approx(0.25, 0.0001)


# --- sacrifice_relic, owns_relic, sacrificed_plus_one ----------------------------------------------

func test_a_sacrifice_pick_opens_a_step_with_only_the_relics_in_the_tier_range() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_hold(state, ["n1a", "n2a", "n3a", "boss1"])
	_adhoc(state, ctx, [SACRIFICE_PICK, PLUS_ONE])
	var opened: Dictionary = _pick(state, ctx)
	assert_bool(bool(opened["finished"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	assert_str(String(state.event_queue[0]["type"])).is_equal("sacrifice_relic")
	var model: Dictionary = RunChoices.model(state, ctx)
	assert_array(_ids_of(model["options"])).is_equal(["event_sacrifice:n1a", "event_sacrifice:n2a"])  # not the tier 3 relic, not the boss relic
	assert_str(String(model["title"])).is_equal("Give up a relic")
	assert_array(state.relics).is_equal(["n1a", "n2a", "n3a", "boss1"])  # nothing is lost until the pick


func test_giving_a_relic_up_for_an_event_sends_it_away_for_good_and_opens_the_next_tier_up() -> void:
	for case: Array in [["n1a", "tier2"], ["n2a", "tier3"]]:
		var ctx: Dictionary = _ctx()
		var state: RunState = _state(1)
		_hold(state, ["n1a", "n2a", "n3a"])
		_adhoc(state, ctx, [SACRIFICE_PICK, PLUS_ONE])
		_pick(state, ctx)
		var result: Dictionary = RunChoices.apply(state, "event_sacrifice:" + String(case[0]), ctx)
		assert_bool(bool(result["ok"]) and bool(result["relics_changed"])).is_true()
		assert_bool(state.relics.has(String(case[0]))).is_false()
		assert_bool(state.relics_given_up.has(String(case[0]))).is_true()
		assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
		assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)
		assert_int(state.offer.size()).is_equal(3)
		for relic_id: String in state.offer:
			assert_str(_tier_of(relic_id)).is_equal(String(case[1]))
			assert_bool(relic_id != String(case[0])).is_true()
		var kinds: Array[String] = []
		for option: Dictionary in RunChoices.options(state, ctx):
			kinds.append(String(option["kind"]))
		assert_bool(kinds.has("relic_skip")).is_false()  # you paid


func test_the_plus_one_tier_is_capped_at_three_and_an_offer_for_nothing_given_up_is_skipped() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_hold(state, ["n3a", "n1a"])
	_adhoc(state, ctx, [{"type": "sacrifice_relic", "select": "pick"}, PLUS_ONE])
	_pick(state, ctx)
	RunChoices.apply(state, "event_sacrifice:n3a", ctx)
	for relic_id: String in state.offer:
		assert_str(_tier_of(relic_id)).is_equal("tier3")  # 3 + 1 capped
	# nothing sacrificed (the only relic is a boss relic): the offer that matches it never opens, and the event ends
	var empty_ctx: Dictionary = _ctx()
	var bare: RunState = _state(1)
	_hold(bare, ["boss1"])
	_adhoc(bare, empty_ctx, [SACRIFICE_PICK, PLUS_ONE, {"type": "gain_gold", "amount": 3}])
	var result: Dictionary = _pick(bare, empty_ctx)
	assert_bool(bool(result["finished"])).is_true()
	assert_str(bare.pending).is_equal(RunState.PENDING_NONE)
	assert_int(bare.gold).is_equal(503)
	assert_array(bare.relics).is_equal(["boss1"])


func test_highest_gives_up_the_top_tier_at_once_unless_the_player_must_pick_among_ties() -> void:
	var ctx: Dictionary = _ctx()
	var single: RunState = _state(1)
	_hold(single, ["n1a", "n2a", "n3a"])
	_adhoc(single, ctx, [{"type": "sacrifice_relic", "select": "highest"}, PLUS_ONE])
	var result: Dictionary = _pick(single, ctx)
	assert_bool(bool(result["relics_changed"])).is_true()
	assert_array(single.relics).is_equal(["n1a", "n2a"])  # the tier 3 relic went, no step
	assert_array(result["gave_up_all"]).is_equal(["n3a"])
	assert_str(single.pending).is_equal(RunState.PENDING_RELIC)  # on to the offer
	var ties: RunState = _state(1)
	_hold(ties, ["n1a", "n2a", "n2b"])
	_adhoc(ties, ctx, [{"type": "sacrifice_relic", "select": "highest"}, PLUS_ONE])
	_pick(ties, ctx)
	assert_str(ties.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	assert_array(_ids_of(RunChoices.options(ties, ctx))).is_equal(["event_sacrifice:n2a", "event_sacrifice:n2b"])
	var refused: Dictionary = RunChoices.apply(ties, "event_sacrifice:n1a", ctx)  # not among the ties
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(ties.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)


func test_owns_relic_greys_a_choice_until_you_hold_a_non_boss_relic_in_the_range() -> void:
	var ctx: Dictionary = _ctx()
	var requires: Dictionary = {"owns_relic": {"min_tier": 1, "max_tier": 2}}
	var bare: RunState = _state(1)
	_hold(bare, ["boss1", "n3a"])  # a boss relic never counts, nor a tier outside the range
	_adhoc(bare, ctx, [SACRIFICE_PICK], requires)
	var option: Dictionary = _option(RunChoices.options(bare, ctx), "event_choice:0")
	assert_bool(bool(option["enabled"])).is_false()
	assert_str(String(option["reason"])).is_equal("Needs a tier 1-2 relic you can give up")
	assert_bool(bool(_pick(bare, ctx)["ok"])).is_false()  # a greyed choice changes nothing
	assert_str(bare.pending).is_equal(RunState.PENDING_EVENT)
	var holder: RunState = _state(1)
	_hold(holder, ["n2c"])
	_adhoc(holder, ctx, [SACRIFICE_PICK], requires)
	assert_bool(bool(_option(RunChoices.options(holder, ctx), "event_choice:0")["enabled"])).is_true()


func test_the_schema_knows_the_tier_modes_and_the_sacrifice_params() -> void:
	assert_array(EventSchema.validate_outcome(PLUS_ONE)).is_empty()
	assert_array(EventSchema.validate_outcome(SACRIFICE_PICK)).is_empty()
	assert_bool(EventSchema.validate_outcome({"type": "sacrifice_relic", "select": "random"}).is_empty()).is_false()
	assert_bool(EventSchema.validate_outcome({"type": "sacrifice_relic", "select": "pick", "min_tier": 3, "max_tier": 1}).is_empty()).is_false()
	assert_array(EventSchema.validate_outcome({"type": "stat_mod", "stat": "move_speed", "modifier_type": "multiplicative", "value": 0.05})).is_empty()
	assert_bool(EventSchema.validate_outcome({"type": "stat_mod", "stat": "move_speed", "modifier_type": "percent", "value": 0.05}).is_empty()).is_false()
	assert_array(EventSchema.validate_outcome({"type": "merchant_discount", "fraction": 0.5})).is_empty()
	assert_array(EventSchema.validate_outcome({"type": "start_fight", "tier": "elite"})).is_empty()


# --- start_fight (the engine; the scene part is below) ----------------------------------------------

func test_start_fight_pays_what_comes_before_it_and_parks_what_comes_after() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_adhoc(state, ctx, [{"type": "lose_hp", "fraction": 0.1}, {"type": "start_fight", "tier": "elite"}, {"type": "gain_gold", "amount": 25}, {"type": "gain_relic", "tier": 2, "count": 3, "skip": false}])
	var result: Dictionary = _pick(state, ctx)
	assert_bool(bool(result["ok"]) and bool(result["start_fight"])).is_true()
	assert_bool(bool(result["finished"])).is_false()
	assert_float(state.hp).is_equal(27.0)  # paid on confirm
	assert_int(state.gold).is_equal(500)  # the reward waits for the win
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_str(String(state.event_fight["tier"])).is_equal("elite")
	assert_int(state.event_queue.size()).is_equal(2)
	assert_str(state.event_id).is_empty()
	# the fight is won: only the event's listed rewards, then its offer
	var won: Dictionary = EventEngine.fight_won(state, ctx)
	assert_str(String(won["kind"])).is_equal("event_fight_won")
	assert_int(state.gold).is_equal(525)
	assert_bool(state.event_fight.is_empty()).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)
	assert_bool(bool(won["finished"])).is_false()
	var done: Dictionary = RunChoices.apply(state, "relic:" + state.offer[0], ctx)
	assert_bool(bool(done["finished"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)


func test_a_fight_with_nothing_after_it_ends_the_event_when_won() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_adhoc(state, ctx, [{"type": "start_fight", "tier": "elite"}])
	_pick(state, ctx)
	assert_bool(state.event_fight.is_empty()).is_false()
	var won: Dictionary = EventEngine.fight_won(state, ctx)
	assert_bool(bool(won["finished"])).is_true()
	assert_bool(state.event_fight.is_empty()).is_true()
	assert_int(state.gold).is_equal(500)  # no elite room's gold


func test_the_event_fight_picks_an_elite_wave_of_the_act_from_the_seed() -> void:
	var config: Dictionary = RunConfig.get_config()
	for act in [1, 2, 3]:
		for room in range(2, 9):
			var state: RunState = _state(act, 5, room)
			var wave: String = EventEngine.pick_fight_wave(state, config)
			assert_bool(wave.is_empty()).is_false()
			assert_bool(RunConfig.variant_by_id(config, "elite", wave).is_empty()).is_false()
			assert_str(EventEngine.pick_fight_wave(state, config)).is_equal(wave)  # seeded: the same node always fights the same wave
	assert_str(EventEngine.pick_fight_wave(_state(1), {"rooms": {"elite": []}})).is_empty()


# --- sacrifice_cost: the offer filter ---------------------------------------------------------------

func _sacrifice_ids(ids: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for id: String in ids:
		if id.begins_with("sac"):
			found.append(id)
	return found


func test_eligible_leaves_out_a_sacrifice_relic_while_you_hold_fewer_than_its_cost() -> void:
	var catalog: Array = _catalog()
	var pools: Array[String] = ["neutral"]
	var none: Array[String] = []
	for count in [0, 1, 2]:
		var found: Array[String] = []
		for relic: Dictionary in RelicOffer.eligible("elite", TIER_WEIGHTS, none, none, pools, catalog, RelicOffer.DEFAULT_RARITIES, count):
			found.append(String(relic["id"]))
		assert_bool(found.has("sac1")).is_equal(count >= 1)
		assert_bool(found.has("sac2")).is_equal(count >= 2)
	var unchecked: Array[String] = []  # -1 (the default) is "not checked": the old behaviour
	for relic: Dictionary in RelicOffer.eligible("elite", TIER_WEIGHTS, none, none, pools, catalog):
		unchecked.append(String(relic["id"]))
	assert_bool(unchecked.has("sac2")).is_true()


func test_no_source_offers_a_sacrifice_relic_you_cannot_pay_for() -> void:
	var ctx: Dictionary = _ctx()
	for run_seed in range(1, 31):
		var poor: RunState = _state(3, run_seed)
		_hold(poor, ["n1a"])  # one relic to give: sac1 may show, sac2 never
		RunRelics.open_for_room(poor, "elite", false, ctx)
		assert_bool(poor.offer.has("sac2")).is_false()
		var relic_room: RunState = _state(3, run_seed)
		_hold(relic_room, ["n1a"])
		RunRelics.open_for_room(relic_room, "relic_room", false, ctx)
		assert_bool(relic_room.offer.has("sac2")).is_false()
		var shop: Dictionary = Merchant.draw_stock(poor, 5, 0, ctx, [] as Array[String], [] as Array[String])
		assert_bool((shop["relics"] as Array).has("sac2")).is_false()
		var broke: RunState = _state(3, run_seed)  # holds nothing: neither
		var empty_shop: Dictionary = Merchant.draw_stock(broke, 5, 0, ctx, [] as Array[String], [] as Array[String])
		assert_array(_sacrifice_ids(_strings(empty_shop["relics"]))).is_empty()
		var event_offer: Array[String] = EventEngine.offer_ids(broke, ctx, {"type": "gain_relic", "tier": 3})
		assert_array(_sacrifice_ids(event_offer)).is_empty()
		var mini: RunState = _state(3, run_seed)
		RunRelics.open_for_room(mini, "mini_boss", false, ctx)
		assert_array(_sacrifice_ids(mini.offer)).is_empty()
	var seen: bool = false
	for run_seed in range(1, 60):
		var rich: RunState = _state(3, run_seed)
		_hold(rich, ["n1a", "n1b"])
		RunRelics.open_for_room(rich, "elite", false, ctx)
		seen = seen or rich.offer.has("sac2") or rich.offer.has("sac1")
	assert_bool(seen).is_true()  # able to pay: they do turn up


func _strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in (value as Array):
		out.append(String(item))
	return out


# --- sacrifice_cost: taking one at an offer ----------------------------------------------------------

func _offer_state(held: Array, offered: Array, cap: int = 20) -> Array:
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	var state: RunState = _state(3)
	_hold(state, held)
	state.pending = RunState.PENDING_RELIC
	state.offer = _strings(offered)
	return [state, ctx]


func test_taking_a_cost_two_relic_picks_both_first_and_confirms_once() -> void:
	var made: Array = _offer_state(["n1a", "n1b", "n2a", "boss1"], ["sac2", "n3a", "n3b"])
	var state: RunState = made[0]
	var ctx: Dictionary = made[1]
	var open: Dictionary = RunChoices.apply(state, "relic:sac2", ctx)
	assert_str(String(open["kind"])).is_equal("relic_swap_open")
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	var model: Dictionary = RunChoices.model(state, ctx)
	assert_str(String(model["title"])).is_equal("Give up relics")
	assert_int(int(model["sacrifice_cost"])).is_equal(2)
	var ids: Array[String] = _ids_of(model["options"])
	assert_array(ids).is_equal(["giveup:n1a", "giveup:n1b", "giveup:n2a", "giveup_confirm", "giveup_cancel"])  # no boss relic
	assert_bool(bool(_option(model["options"], "giveup_confirm")["enabled"])).is_false()
	var early: Dictionary = RunChoices.apply(state, "giveup_confirm", ctx)  # confirm before the picks are in
	assert_bool(bool(early["ok"])).is_false()
	assert_array(state.relics).is_equal(["n1a", "n1b", "n2a", "boss1"])
	var one: Dictionary = RunChoices.apply(state, "giveup:n1a", ctx)
	assert_bool(bool(one["ok"]) and not bool(one["finished"])).is_true()
	assert_array(state.sacrifice_picks).is_equal(["n1a"])
	assert_array(state.relics).is_equal(["n1a", "n1b", "n2a", "boss1"])  # picking gives nothing up
	RunChoices.apply(state, "giveup:n1a", ctx)  # picking it again unpicks it
	assert_array(state.sacrifice_picks).is_empty()
	RunChoices.apply(state, "giveup:n1a", ctx)
	RunChoices.apply(state, "giveup:n2a", ctx)
	var full: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_bool(bool(_option(full, "giveup_confirm")["enabled"])).is_true()
	assert_bool(bool(_option(full, "giveup:n1b")["enabled"])).is_false()  # enough picked
	assert_bool(bool(RunChoices.apply(state, "giveup:n1b", ctx)["ok"])).is_false()
	var done: Dictionary = RunChoices.apply(state, "giveup_confirm", ctx)
	assert_bool(bool(done["ok"]) and bool(done["finished"])).is_true()
	assert_str(String(done["kind"])).is_equal("relic_swap")
	assert_array(done["gave_up_all"]).is_equal(["n1a", "n2a"])
	assert_array(state.relics).is_equal(["n1b", "boss1", "sac2"])
	assert_array(state.relics_given_up).is_equal(["n1a", "n2a"])  # they never come back
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_bool(state.sacrifice_picks.is_empty() and state.relic_incoming.is_empty()).is_true()


func test_cancel_at_any_point_cancels_the_whole_take_and_loses_nothing() -> void:
	for picked_first: bool in [false, true]:
		var made: Array = _offer_state(["n1a", "n1b", "n2a"], ["sac2", "n3a"])
		var state: RunState = made[0]
		var ctx: Dictionary = made[1]
		RunChoices.apply(state, "relic:sac2", ctx)
		if picked_first:
			RunChoices.apply(state, "giveup:n1a", ctx)
		var result: Dictionary = RunChoices.apply(state, "giveup_cancel", ctx)
		assert_bool(bool(result["ok"])).is_true()
		assert_str(String(result["kind"])).is_equal("relic_cancel")
		assert_array(state.relics).is_equal(["n1a", "n1b", "n2a"])
		assert_array(state.relics_given_up).is_empty()
		assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
		assert_array(state.offer).is_equal(["sac2", "n3a"])
		assert_array(state.sacrifice_picks).is_empty()
		assert_str(state.relic_incoming).is_empty()


func test_a_sacrifice_relic_you_cannot_pay_for_is_greyed_in_a_forced_offer() -> void:
	var made: Array = _offer_state(["n1a"], ["sac2", "n3a"])
	var state: RunState = made[0]
	var ctx: Dictionary = made[1]
	var option: Dictionary = _option(RunChoices.options(state, ctx), "relic:sac2")
	assert_bool(bool(option["enabled"])).is_false()
	assert_str(String(option["reason"])).is_equal("Needs 2 relics you can give up")
	assert_int(int(option["sacrifice_cost"])).is_equal(2)
	assert_bool(bool(RunChoices.apply(state, "relic:sac2", ctx)["ok"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)


func test_the_cap_is_checked_after_the_sacrifice() -> void:
	# cost 1 at the cap: one give-up total (the cost frees the slot), the count stays at the cap
	var one: Array = _offer_state(["n1a", "n1b", "n2a"], ["sac1"], 3)
	var state: RunState = one[0]
	var ctx: Dictionary = one[1]
	RunChoices.apply(state, "relic:sac1", ctx)
	RunChoices.apply(state, "giveup:n1a", ctx)
	var done: Dictionary = RunChoices.apply(state, "giveup_confirm", ctx)
	assert_bool(bool(done["finished"])).is_true()
	assert_int(state.relics.size()).is_equal(3)
	assert_bool(state.relics.has("sac1")).is_true()
	# cost 2 at the cap: the count goes down by one
	var two: Array = _offer_state(["n1a", "n1b", "n2a"], ["sac2"], 3)
	var lower: RunState = two[0]
	var lower_ctx: Dictionary = two[1]
	RunChoices.apply(lower, "relic:sac2", lower_ctx)
	RunChoices.apply(lower, "giveup:n1a", lower_ctx)
	RunChoices.apply(lower, "giveup:n1b", lower_ctx)
	RunChoices.apply(lower, "giveup_confirm", lower_ctx)
	assert_int(lower.relics.size()).is_equal(2)
	# an ordinary relic at the cap is still the plain one-step swap
	var plain: Array = _offer_state(["n1a", "n1b", "n2a"], ["n3a"], 3)
	var swap_state: RunState = plain[0]
	var swap_ctx: Dictionary = plain[1]
	RunChoices.apply(swap_state, "relic:n3a", swap_ctx)
	var swapped: Dictionary = RunChoices.apply(swap_state, "giveup:n1a", swap_ctx)
	assert_bool(bool(swapped["finished"])).is_true()
	assert_array(swap_state.relics).is_equal(["n1b", "n2a", "n3a"])


func test_the_bot_policy_picks_then_confirms_and_cancels_when_it_cannot() -> void:
	var made: Array = _offer_state(["n1a", "n1b", "n2a"], ["sac2"])
	var state: RunState = made[0]
	var ctx: Dictionary = made[1]
	RunChoices.apply(state, "relic:sac2", ctx)
	var steps: Array[String] = []
	for i in range(4):
		var choice: String = RelicPolicy.giveup_choice(RunChoices.options(state, ctx))
		steps.append(choice)
		assert_bool(bool(RunChoices.apply(state, choice, ctx)["ok"])).is_true()
		if state.pending != RunState.PENDING_RELIC_SWAP:
			break
	assert_array(steps).is_equal(["giveup:n1a", "giveup:n1b", "giveup_confirm"])
	assert_array(state.relics).is_equal(["n2a", "sac2"])
	var plain: Array[Dictionary] = [{"id": "giveup:x", "kind": "giveup", "enabled": true}, {"id": "giveup_cancel", "kind": "back", "enabled": true}]
	assert_str(RelicPolicy.giveup_choice(plain)).is_equal("giveup:x")  # the plain cap swap is unchanged
	var stuck: Array[Dictionary] = [{"id": "giveup:x", "kind": "giveup", "enabled": false}, {"id": "giveup_cancel", "kind": "back", "enabled": true}]
	assert_str(RelicPolicy.giveup_choice(stuck)).is_equal("giveup_cancel")
	var picks: Array[Dictionary] = [{"id": "event_sacrifice:b", "kind": "giveup", "enabled": true, "tier": "tier2"}, {"id": "event_sacrifice:a", "kind": "giveup", "enabled": true, "tier": "tier1"},
			{"id": "event_sacrifice:c", "kind": "giveup", "enabled": true, "tier": "tier1"}]
	assert_str(RouteBot.sacrifice_choice(picks)).is_equal("event_sacrifice:a")  # the lowest tier, the first of ties
	assert_str(RouteBot.sacrifice_choice([])).is_empty()


# --- sacrifice_cost at the merchant ------------------------------------------------------------------

func _shop_state(held: Array, stocked: Array, gold: int) -> Array:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(3)
	_hold(state, held)
	state.gold = gold
	state.merchant_visit = {"node": 5, "relics": _strings(stocked), "cards": [] as Array[String], "sold_relics": [] as Array[String], "sold_cards": [] as Array[String], "rerolls_used": 0}
	state.pending = RunState.PENDING_MERCHANT
	return [state, ctx]


func test_buying_a_sacrifice_relic_charges_on_confirm_and_cancel_charges_nothing() -> void:
	var made: Array = _shop_state(["n1a", "n1b", "n2a"], ["sac2", "n1c"], 400)
	var state: RunState = made[0]
	var ctx: Dictionary = made[1]
	var price: int = Merchant.relic_price("sac2", ctx)
	var shop_option: Dictionary = _option(RunMerchant.options(state, ctx), "buy_relic:sac2")
	assert_bool(bool(shop_option["enabled"])).is_true()
	assert_int(int(shop_option["sacrifice_cost"])).is_equal(2)
	assert_bool(bool(shop_option["needs_swap"])).is_true()
	var opened: Dictionary = RunMerchant.apply(state, "buy_relic:sac2", ctx)
	assert_str(String(opened["kind"])).is_equal("merchant_swap_open")
	assert_int(state.gold).is_equal(400)  # nothing charged yet
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
	assert_array(_ids_of(RunMerchant.options(state, ctx))).is_equal(["merchant_giveup:n1a", "merchant_giveup:n1b", "merchant_giveup:n2a", "merchant_giveup_confirm", "merchant_cancel"])
	RunMerchant.apply(state, "merchant_giveup:n1a", ctx)
	var cancelled: Dictionary = RunMerchant.apply(state, "merchant_cancel", ctx)
	assert_bool(bool(cancelled["ok"])).is_true()
	assert_int(state.gold).is_equal(400)
	assert_array(state.relics).is_equal(["n1a", "n1b", "n2a"])
	assert_array(state.sacrifice_picks).is_empty()
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	RunMerchant.apply(state, "buy_relic:sac2", ctx)
	RunMerchant.apply(state, "merchant_giveup:n1a", ctx)
	assert_bool(bool(RunMerchant.apply(state, "merchant_giveup_confirm", ctx)["ok"])).is_false()  # one pick short
	assert_int(state.gold).is_equal(400)
	RunMerchant.apply(state, "merchant_giveup:n2a", ctx)
	var bought: Dictionary = RunMerchant.apply(state, "merchant_giveup_confirm", ctx)
	assert_bool(bool(bought["ok"])).is_true()
	assert_int(state.gold).is_equal(400 - price)  # charged on the confirm
	assert_int(state.gold_spent_merchant).is_equal(price)
	assert_array(state.relics).is_equal(["n1b", "sac2"])
	assert_array(state.relics_given_up).is_equal(["n1a", "n2a"])
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	assert_bool(state.sacrifice_picks.is_empty() and state.relic_incoming.is_empty()).is_true()


func test_a_sacrifice_relic_at_the_shop_needs_the_gold_first_and_enough_to_give_up() -> void:
	var poor: Array = _shop_state(["n1a", "n1b"], ["sac2"], 10)
	var state: RunState = poor[0]
	var ctx: Dictionary = poor[1]
	var refused: Dictionary = RunMerchant.apply(state, "buy_relic:sac2", ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(String(refused["reason_code"])).is_equal("too_expensive")
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)  # no step opened for something you cannot afford
	var short: Array = _shop_state(["n1a"], ["sac2"], 400)
	var short_state: RunState = short[0]
	var item: Dictionary = {}
	for entry: Dictionary in Merchant.items(short_state, short[1]):
		if String(entry["id"]) == "sac2":
			item = entry
	assert_bool(bool(item["can_buy"])).is_false()
	assert_str(String(item["reason"])).is_equal("none_giveable")
	assert_bool(bool(RunMerchant.apply(short_state, "buy_relic:sac2", short[1])["ok"])).is_false()


func test_the_discount_applies_to_a_sacrifice_relic_and_the_confirm_charges_the_shown_price() -> void:
	var made: Array = _shop_state(["n1a"], ["sac1"], 400)
	var state: RunState = made[0]
	var ctx: Dictionary = made[1]
	state.merchant_visit["discount"] = 0.5
	var expected: int = Merchant.discounted(Merchant.relic_price("sac1", ctx), 0.5)
	RunMerchant.apply(state, "buy_relic:sac1", ctx)
	RunMerchant.apply(state, "merchant_giveup:n1a", ctx)
	var confirm: Dictionary = _option(RunMerchant.options(state, ctx), "merchant_giveup_confirm")
	assert_int(int(confirm["price"])).is_equal(expected)
	RunMerchant.apply(state, "merchant_giveup_confirm", ctx)
	assert_int(400 - state.gold).is_equal(expected)


# --- saving and loading every new state --------------------------------------------------------------

## A shipped, non-boss relic of tier 1 and 2 (state.relics must exist in the real database for a round trip).
func _real_relics() -> Array[String]:
	return ["asap_notice", "heavy_sigh"]


func _inject_sacrifice_relic() -> void:
	RelicDatabase.load_all()
	var relic: Dictionary = _relic("fx_sac2", "tier3", ["elite"], 2)
	relic["modifiers"] = [{"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.1}]
	RelicDatabase._relics["fx_sac2"] = relic


func test_the_give_up_picks_round_trip_and_a_bad_pick_list_is_dropped() -> void:
	_inject_sacrifice_relic()
	var state: RunState = _state(1)
	state.relics = _real_relics()
	state.pending = RunState.PENDING_RELIC_SWAP
	state.offer = ["fx_sac2"] as Array[String]
	state.relic_incoming = "fx_sac2"
	state.sacrifice_picks = ["asap_notice"] as Array[String]
	var back: RunState = RunState.from_json(state.to_json())
	assert_bool(back.equals(state)).is_true()
	assert_array(back.sacrifice_picks).is_equal(["asap_notice"])
	var data: Dictionary = state.to_dict()
	data["sacrifice_picks"] = ["asap_notice", "heavy_sigh", "muscle_memory"]  # more than the cost, and one not held
	assert_array(RunState.from_dict(data).sacrifice_picks).is_empty()
	data["sacrifice_picks"] = "x"
	assert_array(RunState.from_dict(data).sacrifice_picks).is_empty()
	var plain: RunState = _state(1)  # picks with no step open are dropped
	var stray: Dictionary = plain.to_dict()
	stray["sacrifice_picks"] = ["asap_notice"]
	assert_array(RunState.from_dict(stray).sacrifice_picks).is_empty()


func test_a_pending_event_sacrifice_round_trips_with_its_waiting_outcomes() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	state.relics = _real_relics()
	(ctx["relics"] as Dictionary)["catalog"] = RelicDatabase.all_relics()
	var by_id: Dictionary = {}
	for relic: Dictionary in RelicDatabase.all_relics():
		by_id[String(relic["id"])] = relic
	(ctx["relics"] as Dictionary)["by_id"] = by_id
	_adhoc(state, ctx, [SACRIFICE_PICK, PLUS_ONE, {"type": "gain_gold", "amount": 7}])
	_pick(state, ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	var back: RunState = RunState.from_json(state.to_json())
	assert_bool(back.equals(state)).is_true()
	assert_str(back.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	assert_int(back.event_queue.size()).is_equal(3)
	assert_bool(typeof(back.event_queue[0]["min_tier"]) == TYPE_INT).is_true()  # whole numbers stay whole across JSON
	# the sacrifice step needs its outcome at the head of the queue and something to give up
	var headless: Dictionary = state.to_dict()
	headless["event_queue"] = []
	var repaired: RunState = RunState.from_dict(headless)
	assert_str(repaired.pending).is_equal(RunState.PENDING_NONE)
	var empty_handed: Dictionary = state.to_dict()
	empty_handed["relics"] = []
	assert_str(RunState.from_dict(empty_handed).pending).is_equal(RunState.PENDING_NONE)
	# the tier a sacrifice made is saved too
	back.sacrificed_tier = 2
	assert_int(RunState.from_json(back.to_json()).sacrificed_tier).is_equal(2)
	var bad: Dictionary = back.to_dict()
	bad["sacrificed_tier"] = 9
	assert_int(RunState.from_dict(bad).sacrificed_tier).is_equal(0)


func test_a_pending_fight_round_trips_and_a_bad_fight_is_dropped() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_adhoc(state, ctx, [{"type": "start_fight", "tier": "elite"}, {"type": "gain_gold", "amount": 25}, {"type": "gain_relic", "tier": 2, "count": 3, "skip": false}])
	_pick(state, ctx)
	state.event_fight["wave_id"] = "elite_a"
	var back: RunState = RunState.from_json(state.to_json())
	assert_bool(back.equals(state)).is_true()
	assert_str(String(back.event_fight["wave_id"])).is_equal("elite_a")
	assert_int(back.event_queue.size()).is_equal(2)
	assert_str(back.pending).is_equal(RunState.PENDING_NONE)
	var no_fight: Dictionary = state.to_dict()
	no_fight["event_fight"] = {}
	assert_array(RunState.from_dict(no_fight).event_queue).is_empty()  # waiting outcomes with nothing to wait for are dropped
	var wrong_tier: Dictionary = state.to_dict()
	wrong_tier["event_fight"] = {"tier": "boss", "wave_id": "x"}
	assert_bool(RunState.from_dict(wrong_tier).event_fight.is_empty()).is_true()
	wrong_tier["event_fight"] = "fight"
	assert_bool(RunState.from_dict(wrong_tier).event_fight.is_empty()).is_true()
	var old: Dictionary = state.to_dict()
	for key: String in ["event_fight", "run_mods", "merchant_discount", "sacrifice_picks", "sacrificed_tier"]:
		old.erase(key)
	var loaded: RunState = RunState.from_dict(old)  # an old save has none of the B2 keys
	assert_bool(loaded.event_fight.is_empty() and loaded.run_mods.is_empty() and loaded.sacrifice_picks.is_empty()).is_true()
	assert_float(loaded.merchant_discount).is_equal(0.0)
	assert_int(loaded.sacrificed_tier).is_equal(0)


func test_every_new_pending_state_is_a_save_boundary_and_the_others_stay_unsaved() -> void:
	var sacrifice: RunState = _state(1)
	sacrifice.pending = RunState.PENDING_EVENT_SACRIFICE
	assert_bool(RunSave.choice_is_savable(sacrifice)).is_true()
	var fight: RunState = _state(1)
	fight.event_fight = {"tier": "elite", "wave_id": "x"}
	assert_bool(RunSave.choice_is_savable(fight)).is_true()  # the start of an event fight
	var event_swap: RunState = _state(1)
	event_swap.pending = RunState.PENDING_RELIC_SWAP
	event_swap.offer_rarity = RunState.OFFER_EVENT_NOSKIP
	event_swap.offer = ["a"] as Array[String]
	event_swap.relic_incoming = "a"
	assert_bool(RunSave.choice_is_savable(event_swap)).is_true()  # a sacrifice relic taken at an event's offer
	var elite_swap: RunState = _state(1)
	elite_swap.pending = RunState.PENDING_RELIC_SWAP
	assert_bool(RunSave.choice_is_savable(elite_swap)).is_false()
	var shop_swap: RunState = _state(1)
	shop_swap.pending = RunState.PENDING_MERCHANT_SWAP
	assert_bool(RunSave.choice_is_savable(shop_swap)).is_false()


# --- generated lines ----------------------------------------------------------------------------------

func _lines(state: RunState, ctx: Dictionary, outcomes: Array) -> Array[String]:
	var normalized: Array = []
	for outcome: Variant in outcomes:
		normalized.append(EventSchema.normalize_outcome(outcome as Dictionary))
	return EventEngine.lines_for(normalized, state, ctx)


func test_every_b2_outcome_has_a_generated_line() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	assert_array(_lines(state, ctx, [{"type": "stat_mod", "stat": "move_speed", "modifier_type": "multiplicative", "value": 0.05}])).is_equal(["Move speed +5% for this run"])
	assert_array(_lines(state, ctx, [{"type": "stat_mod", "stat": "slot_cooldown.recovery", "modifier_type": "multiplicative", "value": -0.2}])).is_equal(["Recovery cooldown -20% for this run"])
	assert_array(_lines(state, ctx, [{"type": "stat_mod", "stat": "armor", "modifier_type": "additive", "value": 2}])).is_equal(["Armor +2 for this run"])
	assert_array(_lines(state, ctx, [{"type": "stat_mod", "stat": "mystery_stat", "modifier_type": "additive", "value": 1}])).is_equal(["mystery_stat +1 for this run"])  # no name: the id shows
	assert_array(_lines(state, ctx, [{"type": "merchant_discount", "fraction": 0.5}])).is_equal(["50% off at the next merchant, only if one is ahead on your route"])
	assert_array(_lines(state, ctx, [{"type": "chance", "p": 0.5, "win": [{"type": "gain_gold", "amount": 40}], "lose": [{"type": "lose_hp", "fraction": 0.2}]}])).is_equal(["50%: gain 40 gold, otherwise lose 6 HP"])
	assert_array(_lines(state, ctx, [SACRIFICE_PICK])).is_equal(["Give up a tier 1-2 relic you pick"])
	assert_array(_lines(state, ctx, [{"type": "sacrifice_relic", "select": "highest", "min_tier": 1, "max_tier": 1}])).is_equal(["Give up your highest-tier relic (tier 1 only)"])
	assert_array(_lines(state, ctx, [{"type": "sacrifice_relic", "select": "pick"}])).is_equal(["Give up a relic you pick"])
	assert_array(_lines(state, ctx, [{"type": "sacrifice_relic", "select": "highest"}])).is_equal(["Give up your highest-tier relic"])
	assert_array(_lines(state, ctx, [PLUS_ONE])).is_equal(["Gain a relic one tier above the one you gave up (pick 1 of 3) (no skip)"])


func test_what_follows_a_fight_reads_as_only_if_you_win() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	var lines: Array[String] = _lines(state, ctx, [{"type": "lose_hp", "fraction": 0.1}, {"type": "start_fight", "tier": "elite"}, {"type": "gain_gold", "amount": 25},
			{"type": "gain_relic", "tier": 2, "count": 3, "skip": false}])
	assert_array(lines).is_equal(["Lose 3 HP", "Fight an elite", "If you win: Gain 25 gold", "If you win: Gain a tier 2 relic (pick 1 of 3) (no skip)"])


func test_the_event_option_lists_the_new_outcome_types_for_the_bot() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	_adhoc(state, ctx, [{"type": "start_fight", "tier": "elite"}, {"type": "chance", "p": 0.5, "win": [SACRIFICE_PICK], "lose": []}])
	var option: Dictionary = _option(RunChoices.options(state, ctx), "event_choice:0")
	assert_array(option["outcome_types"]).contains_exactly(["start_fight", "chance", "sacrifice_relic"])
	var costly: Array[Dictionary] = [{"id": "event_choice:0", "enabled": true, "outcome_types": ["start_fight", "gain_relic"], "has_requires": false},
			{"id": "event_choice:1", "enabled": true, "outcome_types": ["sacrifice_relic"], "has_requires": true}, {"id": "event_choice:2", "enabled": true, "outcome_types": [], "has_requires": false}]
	assert_str(RouteBot.event_choice(costly, "relic", 1.0)).is_equal("event_choice:0")  # the relic route still goes for a relic at good HP
	assert_str(RouteBot.event_choice(costly, "relic", 0.3)).is_equal("event_choice:2")
	assert_str(RouteBot.event_choice(costly, "safe", 1.0)).is_equal("event_choice:1")  # no HP loss, curse or fight (a sacrifice is not in the safe block list)


# --- through the real controller ----------------------------------------------------------------------

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func _latest_main(except_id: int) -> Main:
	var found: Main = null
	for child in get_children():
		if child is Main and child.get_instance_id() != except_id and not child.is_queued_for_deletion():
			found = child as Main
	return found


func _win_room(main: Main) -> void:
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	main.enemy_spawner.configure_room(table, 1)
	main.enemy_spawner._process(1.0)
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await _frames(2)


## A map run standing on the first event node found (the shipped map makes none, so the map is drawn with the event weight on).
func _state_on_event(first_seed: int = 1) -> RunState:
	var cfg: Dictionary = MapConfig.get_config().duplicate(true)
	(cfg["types"]["event"] as Dictionary)["weight"] = 12
	for seed_value in range(first_seed, first_seed + 200):
		var map: Dictionary = MapGenerator.generate(seed_value, cfg)
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) != "event":
				continue
			var trail: Array[int] = [int(entry["id"])]
			while int(MapGraph.node(map, trail[0])["room"]) > 1:
				trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
			var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3, "rogue")
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			state.gold = 100
			return state
	return null


func _enable_saves() -> void:
	RunSave.reset()
	RunSave.path = SAVE_PATH
	RunSave.persist_override = true
	RunSave.delete_save()


func test_an_event_fight_is_a_fresh_elite_room_that_pays_only_the_events_rewards() -> void:
	_enable_saves()
	var state: RunState = _state_on_event(1)
	assert_object(state).is_not_null()
	RunSession.current = state
	RunSession.forced_event = "fx_fight"
	var main := _spawn()
	await _frames()
	var main_id: int = main.get_instance_id()
	var controller: RunController = main.run_controller
	assert_str(state.event_id).is_equal("fx_fight")
	var history_before: int = state.history.size()
	var max_hp: float = main.player.health.max_health
	var result: Dictionary = controller.choose("event_choice:0")
	assert_bool(bool(result["ok"])).is_true()
	assert_bool(controller.event_fight_active()).is_true()
	assert_bool(String(state.event_fight["wave_id"]).is_empty()).is_false()
	assert_float(state.hp).is_equal(max_hp - float(EventEngine.hp_amount(0.1, max_hp)))  # the cost was paid on confirm
	assert_int(state.gold).is_equal(100)
	# the save written at the fight's start already holds the paid cost and the waiting rewards
	var saved: RunState = RunSave.read_state()
	assert_object(saved).is_not_null()
	assert_bool(saved.equals(state)).is_true()
	assert_int(saved.event_queue.size()).is_equal(2)
	await _frames()
	var fight: Main = _latest_main(main_id)
	assert_object(fight).is_not_null()
	var fight_controller: RunController = fight.run_controller
	assert_bool(fight_controller.event_fight_active()).is_true()
	assert_bool(fight_controller.is_cleared()).is_false()  # a real fight, not an instant event room
	assert_float(fight.player.health.current_health).is_equal(state.hp)
	var golds: Array[int] = []
	fight_controller.gold_changed.connect(func(total: int, _delta: int) -> void: golds.append(total))
	await _win_room(fight)
	assert_bool(fight_controller.is_cleared()).is_true()
	assert_bool(state.event_fight.is_empty()).is_true()
	assert_int(state.gold).is_equal(125)  # the event's 25, no elite room gold
	assert_array(golds).is_equal([125])
	assert_int(state.history.size()).is_equal(history_before)  # the room was recorded once, when the event opened
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)
	var picked: Dictionary = fight_controller.pick_relic(state.offer[0])
	assert_bool(bool(picked["ok"]) and bool(picked["finished"])).is_true()
	assert_int(state.relics.size()).is_equal(1)
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_bool(state.event_queue.is_empty()).is_true()


func test_quitting_mid_fight_restarts_the_fight_with_the_costs_still_paid() -> void:
	_enable_saves()
	var state: RunState = _state_on_event(1)
	RunSession.current = state
	RunSession.forced_event = "fx_fight"
	var main := _spawn()
	await _frames()
	var main_id: int = main.get_instance_id()
	main.run_controller.choose("event_choice:0")
	await _frames()
	var fight: Main = _latest_main(main_id)
	assert_object(fight).is_not_null()
	var hp_after_cost: float = state.hp
	var fight_id: int = fight.get_instance_id()
	RunSession.clear()  # quit
	fight.queue_free()
	await _frames()
	assert_bool(RunSave.load_save()).is_true()
	var resumed: RunState = RunSession.current
	assert_bool(resumed.event_fight.is_empty()).is_false()
	assert_float(resumed.hp).is_equal(hp_after_cost)  # Continue does not refund the cost
	assert_int(resumed.event_queue.size()).is_equal(2)
	var again: Main = _spawn()
	await _frames()
	assert_bool(again.run_controller.event_fight_active()).is_true()
	assert_bool(again.run_controller.is_cleared()).is_false()
	assert_int(again.run_controller.state().history.size()).is_equal(resumed.history.size())
	assert_str(String(resumed.event_fight["wave_id"])).is_equal(String(state.event_fight["wave_id"]))  # the same wave
	await _win_room(again)
	assert_int(resumed.gold).is_equal(125)
	assert_str(resumed.pending).is_equal(RunState.PENDING_RELIC)
	assert_int(fight_id).is_not_equal(again.get_instance_id())


func test_losing_an_event_fight_ends_the_run_and_deletes_the_save() -> void:
	_enable_saves()
	var state: RunState = _state_on_event(1)
	RunSession.current = state
	RunSession.forced_event = "fx_fight"
	var main := _spawn()
	await _frames()
	var main_id: int = main.get_instance_id()
	main.run_controller.choose("event_choice:0")
	await _frames()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()
	var fight: Main = _latest_main(main_id)
	fight.run_controller._on_player_died()
	assert_str(state.outcome).is_equal("lost")
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_false()
	assert_int(state.gold).is_equal(100)  # the reward never came


func test_stat_mod_reaches_the_live_player_now_and_in_the_next_room() -> void:
	var state: RunState = _state_on_event(1)
	RunSession.current = state
	RunSession.forced_event = "fx_perk"
	var main := _spawn()
	await _frames()
	var main_id: int = main.get_instance_id()
	var base: float = main.player.stat_modifiers.apply("move_speed", 10.0)
	assert_float(base).is_equal(10.0)
	var result: Dictionary = main.run_controller.choose("event_choice:0")
	assert_bool(bool(result["ok"])).is_true()
	assert_float(main.player.stat_modifiers.apply("move_speed", 10.0)).is_equal_approx(10.5, 0.0001)
	assert_float(state.merchant_discount).is_equal_approx(0.5, 0.0001)
	assert_array(state.run_mods).is_equal([{"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.05}])
	# the next room is a fresh scene: the modifier comes back from the RunState, with no relic held
	var next_node: int = main.run_controller.reachable_nodes()[0] if not main.run_controller.reachable_nodes().is_empty() else -1
	assert_int(next_node).is_not_equal(-1)
	main.run_controller.pick_node(next_node)
	await _frames()
	var room: Main = _latest_main(main_id)
	assert_object(room).is_not_null()
	assert_object(room.run_controller.relic_manager()).is_null()
	assert_float(room.player.stat_modifiers.apply("move_speed", 10.0)).is_equal_approx(10.5, 0.0001)


func test_an_event_sacrifice_through_the_controller_syncs_the_live_relics() -> void:
	var state: RunState = _state_on_event(1)
	state.relics = _real_relics()
	RunSession.current = state
	RunSession.forced_event = "fx_altar"
	var main := _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	assert_object(controller.relic_manager()).is_not_null()
	assert_bool(controller.relic_manager().has_relic("asap_notice")).is_true()
	var opened: Dictionary = controller.choose("event_choice:0")
	assert_bool(bool(opened["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	assert_bool(controller.has_choice()).is_true()
	var gave: Dictionary = controller.choose("event_sacrifice:asap_notice")
	assert_bool(bool(gave["ok"])).is_true()
	assert_bool(controller.relic_manager().has_relic("asap_notice")).is_false()  # gone from the live room at once
	assert_bool(state.relics_given_up.has("asap_notice")).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)  # tier 1 given up: a tier 2 offer, no skip
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)


## 3d qa: the in-memory profile (LoadoutSession) counts finished runs process-wide; leave it clean so the next suite starts as run 1.
func after() -> void:
	LoadoutSession.reset()
	StartScreen.reset()
