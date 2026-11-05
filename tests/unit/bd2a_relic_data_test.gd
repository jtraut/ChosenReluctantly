class_name Bd2aRelicDataTest
extends GdUnitTestSuite
## BD2-A items 3 to 6: the relic validator and loader, the run.json relics block, the RunState lists (the save round trip
## is to_dict / from_dict) and the pure offer function with the swap-at-cap helper.

const VALID_DIR := "res://tests/fixtures/relics_valid"
const BAD_JSON_DIR := "res://tests/fixtures/relics_bad_json"
const BAD_ID_DIR := "res://tests/fixtures/relics_bad_id"


func after_test() -> void:
	RelicDatabase.load_all()  # a fixture directory must not leak into later suites


## A known-good relic to break one field at a time.
func _good() -> Dictionary:
	return {
		"id": "good_relic", "name": "Good", "pool": "fire", "rarity": "tier1", "sources": ["elite", "relic_room"], "keywords": ["Burn"],
		"modifiers": [{"stat": "move_speed", "modifier_type": "additive", "value": 0.5}],
		"triggers": [{
			"event": "status_ended", "filter": {"status_id": "burn", "reason": ["expired", "owner_died"], "target_team": "enemy"}, "at": "event_position",
			"internal_cooldown": 0.5, "effects": [{"template": "aoe", "params": {"damage": 4, "damage_type": "fire", "radius": 2.0}}],
		}],
		"flavor_text": "ok",
	}


func _problems(relic: Dictionary) -> Array[String]:
	return RelicSchema.validate(relic, String(relic.get("id", "")))


func _with(key: String, value: Variant) -> Dictionary:
	var relic := _good()
	relic[key] = value
	return relic


func _trigger_with(key: String, value: Variant) -> Dictionary:
	var relic := _good()
	(relic["triggers"][0] as Dictionary)[key] = value
	return relic


func _has_problem(problems: Array[String], fragment: String) -> bool:
	for problem: String in problems:
		if problem.contains(fragment):
			return true
	return false


# --- the validator -----------------------------------------------------------------------------

func test_a_good_relic_passes() -> void:
	assert_array(_problems(_good())).is_empty()


func test_the_id_must_match_the_file_name() -> void:
	assert_bool(_has_problem(RelicSchema.validate(_good(), "other_name"), "file name")).is_true()
	assert_array(_problems(_with("id", ""))).is_not_empty()
	assert_array(_problems(_with("name", ""))).is_not_empty()
	assert_array(_problems(_with("flavor_text", 5))).is_not_empty()


func test_unknown_keys_are_rejected_including_curse() -> void:
	assert_bool(_has_problem(_problems(_with("curse", null)), "unknown key 'curse'")).is_true()
	assert_bool(_has_problem(_problems(_with("typo", 1)), "unknown key 'typo'")).is_true()
	assert_bool(_has_problem(_problems(_trigger_with("extra", 1)), "unknown key 'extra'")).is_true()


func test_a_relic_that_is_not_an_object_is_rejected() -> void:
	assert_array(RelicSchema.validate([1, 2], "x")).is_not_empty()
	assert_array(RelicSchema.validate("text", "x")).is_not_empty()


func test_pool_must_be_a_known_pool() -> void:
	assert_array(_problems(_with("pool", "lightning"))).is_not_empty()
	for pool: String in ["rogue", "wizard", "fire", "neutral"]:
		assert_array(_problems(_with("pool", pool))).is_empty()


func test_rarity_must_be_one_of_the_four_tiers() -> void:
	assert_array(_problems(_with("rarity", "common"))).is_not_empty()
	for rarity: String in ["tier1", "tier2", "tier3"]:
		assert_array(_problems(_with("rarity", rarity))).is_empty()


func test_boss_rarity_is_only_valid_with_the_mini_boss_source() -> void:
	var boss := _with("rarity", "boss")
	boss["sources"] = ["mini_boss"]
	assert_array(_problems(boss)).is_empty()
	boss["sources"] = ["mini_boss", "elite"]
	assert_bool(_has_problem(_problems(boss), "boss-rarity")).is_true()
	boss["sources"] = ["merchant"]
	assert_bool(_has_problem(_problems(boss), "boss-rarity")).is_true()


func test_every_documented_source_is_accepted_and_others_are_not() -> void:
	for source: String in ["elite", "relic_room", "merchant", "mini_boss", "curse_room", "buff_room", "boss", "starter", "event", "altar"]:
		assert_array(_problems(_with("sources", [source]))).is_empty()
	assert_array(_problems(_with("sources", ["chest"]))).is_not_empty()  # chests are a relic_room size, not a source
	assert_array(_problems(_with("sources", []))).is_not_empty()
	assert_array(_problems(_with("sources", ["elite", "elite"]))).is_not_empty()
	assert_array(_problems(_with("sources", "elite"))).is_not_empty()


func test_sacrifice_cost_is_an_optional_whole_number_one_or_two() -> void:
	assert_array(_problems(_with("sacrifice_cost", 1))).is_empty()
	assert_array(_problems(_with("sacrifice_cost", 2))).is_empty()
	for bad: Variant in [0, 3, 1.5, "1", -1]:
		assert_array(_problems(_with("sacrifice_cost", bad))).is_not_empty()


func test_keywords_must_be_known_tags() -> void:
	assert_array(_problems(_with("keywords", ["Burn", "Area"]))).is_empty()
	assert_array(_problems(_with("keywords", ["Nonsense"]))).is_not_empty()
	assert_array(_problems(_with("keywords", ["Burn", "Burn"]))).is_not_empty()
	assert_array(_problems(_with("keywords", "Burn"))).is_not_empty()


func test_a_relic_needs_a_modifier_or_a_trigger() -> void:
	var empty := _good()
	empty["modifiers"] = []
	empty["triggers"] = []
	assert_bool(_has_problem(_problems(empty), "at least one modifier or trigger")).is_true()
	empty.erase("modifiers")
	empty.erase("triggers")
	assert_array(_problems(empty)).is_not_empty()


func test_modifiers_are_checked() -> void:
	var cases: Array = [
		[{"stat": "", "modifier_type": "additive", "value": 1.0}],
		[{"stat": "move_speed", "modifier_type": "sideways", "value": 1.0}],
		[{"stat": "move_speed", "modifier_type": "additive", "value": "big"}],
		[{"stat": "move_speed", "modifier_type": "additive", "value": 1.0, "duration": 5.0}],  # a relic modifier has no duration
		["not an object"],
	]
	for bad: Array in cases:
		assert_array(_problems(_with("modifiers", bad))).is_not_empty()
	assert_array(_problems(_with("modifiers", "nope"))).is_not_empty()


func test_a_status_damage_mult_modifier_has_the_floor() -> void:
	var low := [{"stat": "status_damage_mult.burn", "modifier_type": "multiplicative", "value": -1.0}]
	assert_bool(_has_problem(_problems(_with("modifiers", low)), "status_damage_mult.burn")).is_true()
	var ok := [{"stat": "status_damage_mult.burn", "modifier_type": "multiplicative", "value": 0.25}]
	assert_array(_problems(_with("modifiers", ok))).is_empty()


func test_the_event_must_be_known() -> void:
	assert_array(_problems(_trigger_with("event", "something_happened"))).is_not_empty()
	for event_id: String in RelicSchema.event_ids():
		var relic := _good()
		var trigger: Dictionary = relic["triggers"][0]
		trigger["event"] = event_id
		trigger["filter"] = {}
		trigger["at"] = "player"
		assert_array(_problems(relic)).override_failure_message("event %s" % event_id).is_empty()


func test_filter_keys_and_values_are_checked_per_event() -> void:
	assert_bool(_has_problem(_problems(_trigger_with("filter", {"slot_type": "utility"})), "unknown key 'slot_type'")).is_true()  # not a status_ended key
	assert_array(_problems(_trigger_with("filter", {"status_id": "no_such_status"}))).is_not_empty()
	assert_array(_problems(_trigger_with("filter", {"reason": "vanished"}))).is_not_empty()
	assert_array(_problems(_trigger_with("filter", {"target_team": "ally"}))).is_not_empty()
	assert_array(_problems(_trigger_with("filter", {"origin": "moon"}))).is_not_empty()
	assert_array(_problems(_trigger_with("filter", {"origin": ["card:*", "light", "relic:some_id", "status:burn", "enemy", "heavy"]}))).is_empty()
	assert_array(_problems(_trigger_with("filter", {"every_nth": 1}))).is_not_empty()
	assert_array(_problems(_trigger_with("filter", {"every_nth": 4}))).is_empty()
	assert_array(_problems(_trigger_with("filter", {"allow_relic_origin": "yes"}))).is_not_empty()
	assert_array(_problems(_trigger_with("filter", "not an object"))).is_not_empty()
	var cast := _trigger_with("event", "card_cast")
	(cast["triggers"][0] as Dictionary)["filter"] = {"slot_type": "no_slot"}
	(cast["triggers"][0] as Dictionary)["at"] = "player"
	assert_array(_problems(cast)).is_not_empty()
	(cast["triggers"][0] as Dictionary)["filter"] = {"slot_type": "utility", "tag": "Burn", "allow_relic_origin": true}
	assert_bool(_has_problem(_problems(cast), "no origin")).is_true()  # card_cast carries no origin


func test_at_must_make_sense_for_the_event() -> void:
	assert_array(_problems(_trigger_with("at", "nowhere"))).is_not_empty()
	var relic := _trigger_with("event", "room_started")
	(relic["triggers"][0] as Dictionary)["filter"] = {}
	(relic["triggers"][0] as Dictionary)["at"] = "event_position"
	assert_bool(_has_problem(_problems(relic), "no position")).is_true()
	(relic["triggers"][0] as Dictionary)["event"] = "dash_ended"
	(relic["triggers"][0] as Dictionary)["at"] = "event_target"
	assert_bool(_has_problem(_problems(relic), "no target")).is_true()


func test_internal_cooldown_and_effects_are_checked() -> void:
	assert_array(_problems(_trigger_with("internal_cooldown", -1.0))).is_not_empty()
	assert_array(_problems(_trigger_with("internal_cooldown", "soon"))).is_not_empty()
	assert_array(_problems(_trigger_with("effects", []))).is_not_empty()
	assert_array(_problems(_trigger_with("effects", [{"template": "fireball", "params": {}}]))).is_not_empty()
	assert_array(_problems(_trigger_with("effects", [{"template": "aoe", "params": {"damage": 1}}]))).is_not_empty()  # missing params
	assert_array(_problems(_trigger_with("effects", [{"template": "apply_status", "params": {"status_id": "nope", "duration": 1.0}}]))).is_not_empty()


# --- the loader --------------------------------------------------------------------------------

func test_the_valid_fixture_directory_loads_every_relic() -> void:
	var problems := RelicDatabase.load_all(VALID_DIR)
	assert_array(problems).is_empty()
	assert_array(RelicDatabase.ids()).is_equal(["test_boss", "test_chain", "test_grudge", "test_pyre", "test_spite", "test_wizard"])
	assert_bool(RelicDatabase.has_relic("test_pyre")).is_true()
	assert_str(RelicDatabase.get_relic("test_pyre")["name"]).is_equal("Test Pyre")
	assert_bool(RelicDatabase.get_relic("nope").is_empty()).is_true()


func test_the_shipped_directory_is_valid_and_may_be_empty() -> void:
	assert_array(RelicDatabase.load_all()).is_empty()
	# BD2-A ships no relic files; BD2-B adds seven. Either way nothing is invalid.
	assert_int(RelicDatabase.ids().size()).is_equal(RelicDatabase.all_relics().size())


func test_a_missing_or_empty_directory_is_fine_and_means_no_relics() -> void:
	assert_array(RelicDatabase.load_all("res://tests/fixtures/relics_does_not_exist")).is_empty()
	assert_bool(RelicDatabase.is_empty()).is_true()
	DirAccess.make_dir_recursive_absolute("user://bd2a_empty_relics")
	assert_array(RelicDatabase.load_all("user://bd2a_empty_relics")).is_empty()
	assert_bool(RelicDatabase.is_empty()).is_true()
	assert_array(RelicDatabase.all_relics()).is_empty()


func test_a_corrupt_file_fails_loudly_and_is_skipped() -> void:
	var problems := RelicDatabase.load_all(BAD_JSON_DIR)
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("test_broken.json").contains("not valid JSON")
	assert_bool(RelicDatabase.is_empty()).is_true()


func test_an_id_that_does_not_match_the_file_name_is_rejected_by_the_loader() -> void:
	var problems := RelicDatabase.load_all(BAD_ID_DIR)
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("wrong_name.json").contains("file name")
	assert_bool(RelicDatabase.has_relic("some_other_id")).is_false()


# --- the run.json relics block -----------------------------------------------------------------

func test_the_shipped_relics_block_is_valid_and_has_the_agreed_values() -> void:
	assert_array(RelicConfig.validate_block(RunConfig.get_config().get("relics"))).is_empty()
	assert_bool(RelicConfig.enabled()).is_true()
	assert_int(RelicConfig.max_owned()).is_equal(20)
	assert_int(RelicConfig.offer_count()).is_equal(3)
	var act1 := RelicConfig.tier_weights_for_act(1)
	assert_float(act1["tier1"]).is_equal(80.0)
	assert_float(act1["tier2"]).is_equal(20.0)
	assert_float(act1["tier3"]).is_equal(0.0)
	assert_float(RelicConfig.tier_weights_for_act(2)["tier2"]).is_equal(70.0)
	assert_float(RelicConfig.tier_weights_for_act(3)["tier3"]).is_equal(70.0)
	assert_float(RelicConfig.tier_weights_for_act(7)["tier3"]).is_equal(70.0)  # beyond the last row: the last row
	assert_bool(RunConfig.is_valid()).is_true()


func _block() -> Dictionary:
	return (RunConfig.get_config()["relics"] as Dictionary).duplicate(true)


func test_the_relics_block_is_validated() -> void:
	var cases: Array[Dictionary] = []
	var b := _block(); b.erase("enabled"); cases.append(b)
	b = _block(); b["enabled"] = "yes"; cases.append(b)
	b = _block(); b["max_owned"] = 0; cases.append(b)
	b = _block(); b["max_owned"] = 2.5; cases.append(b)
	b = _block(); b["offer_count"] = 0; cases.append(b)
	b = _block(); b["tier_weights"] = {}; cases.append(b)
	b = _block(); (b["tier_weights"] as Dictionary).erase("1"); cases.append(b)
	b = _block(); (b["tier_weights"] as Dictionary)["1"] = {"tier1": 0, "tier2": 0, "tier3": 0}; cases.append(b)
	b = _block(); (b["tier_weights"] as Dictionary)["1"] = {"tier1": -5, "tier2": 20, "tier3": 0}; cases.append(b)
	b = _block(); (b["tier_weights"] as Dictionary)["1"] = {"tier1": 80, "tier2": 20}; cases.append(b)
	b = _block(); (b["tier_weights"] as Dictionary)["1"] = {"tier1": 80, "tier2": 20, "tier3": 0, "boss": 5}; cases.append(b)
	b = _block(); (b["tier_weights"] as Dictionary)["zero"] = {"tier1": 1, "tier2": 1, "tier3": 1}; cases.append(b)
	b = _block(); b["surprise"] = 1; cases.append(b)
	for bad: Dictionary in cases:
		assert_array(RelicConfig.validate_block(bad)).override_failure_message("should be invalid: %s" % str(bad)).is_not_empty()
	assert_array(RelicConfig.validate_block("nope")).is_not_empty()
	assert_array(RelicConfig.validate_block(null)).is_not_empty()


func test_run_config_rejects_a_config_without_a_valid_relics_block() -> void:
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	var cards: Array[String] = []
	assert_array(RunConfig.validate(config, [], cards)).is_empty()
	config.erase("relics")
	assert_array(RunConfig.validate(config, [], cards)).is_not_empty()


# --- RunState: the save round trip -------------------------------------------------------------

func _state() -> RunState:
	return RunState.new_run(7, ["rogue_quick_slash"] as Array[String], 3)


func test_relics_and_given_up_survive_a_dict_and_a_json_round_trip_in_order() -> void:
	var state := _state()
	state.add_relic("c_relic")
	state.add_relic("a_relic")
	state.add_relic("b_relic")
	assert_bool(state.give_up_relic("a_relic")).is_true()
	assert_array(state.relics).is_equal(["c_relic", "b_relic"])
	assert_array(state.relics_given_up).is_equal(["a_relic"])
	var back: RunState = RunState.from_dict(state.to_dict())
	assert_array(back.relics).is_equal(["c_relic", "b_relic"])
	assert_array(back.relics_given_up).is_equal(["a_relic"])
	assert_bool(state.equals(back)).is_true()
	var through_json: RunState = RunState.from_json(state.to_json())
	assert_array(through_json.relics).is_equal(["c_relic", "b_relic"])
	assert_array(through_json.relics_given_up).is_equal(["a_relic"])
	assert_bool(state.equals(through_json)).is_true()


func test_equals_notices_a_different_relic_list() -> void:
	var a := _state()
	var b := _state()
	assert_bool(a.equals(b)).is_true()
	a.add_relic("x")
	assert_bool(a.equals(b)).is_false()
	b.add_relic("x")
	b.give_up_relic("x")
	assert_bool(a.equals(b)).is_false()


func test_an_old_dict_without_the_relic_keys_loads_as_empty() -> void:
	var old: Dictionary = _state().to_dict()
	old.erase("relics")
	old.erase("relics_given_up")
	var loaded: RunState = RunState.from_dict(old)
	assert_object(loaded).is_not_null()
	assert_array(loaded.relics).is_empty()
	assert_array(loaded.relics_given_up).is_empty()


func test_a_fresh_run_holds_no_relics_and_adding_twice_is_refused() -> void:
	var state := _state()
	assert_array(state.relics).is_empty()
	assert_bool(state.add_relic("x")).is_true()
	assert_bool(state.add_relic("x")).is_false()
	assert_bool(state.has_relic("x")).is_true()
	assert_bool(state.give_up_relic("nope")).is_false()
	assert_array(state.relics).is_equal(["x"])


func test_bad_relic_lists_in_a_saved_dict_are_dropped_not_trusted() -> void:
	var data: Dictionary = _state().to_dict()
	data["relics"] = ["ok", 5, "", "ok", "also_ok"]
	data["relics_given_up"] = "not a list"
	var loaded: RunState = RunState.from_dict(data)
	assert_array(loaded.relics).is_equal(["ok", "also_ok"])
	assert_array(loaded.relics_given_up).is_empty()


# --- the offer function ------------------------------------------------------------------------

func _relic(id: String, pool: String, rarity: String, sources: Array) -> Dictionary:
	return {"id": id, "pool": pool, "rarity": rarity, "sources": sources}


func _catalog() -> Array:
	return [
		_relic("t1_fire", "fire", "tier1", ["elite", "relic_room"]),
		_relic("t1_rogue", "rogue", "tier1", ["elite"]),
		_relic("t1_neutral", "neutral", "tier1", ["elite", "merchant"]),
		_relic("t2_fire", "fire", "tier2", ["elite"]),
		_relic("t2_wizard", "wizard", "tier2", ["elite"]),
		_relic("t3_neutral", "neutral", "tier3", ["elite"]),
		_relic("boss_a", "neutral", "boss", ["mini_boss"]),
		_relic("boss_b", "fire", "boss", ["mini_boss"]),
	]


func _weights_act1() -> Dictionary:
	return {"tier1": 80.0, "tier2": 20.0, "tier3": 0.0}


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _rogue_pools() -> Array[String]:
	return ["rogue", "fire", "neutral"] as Array[String]


func _none() -> Array[String]:
	return [] as Array[String]


func test_an_offer_only_holds_relics_of_the_runs_pools_the_source_and_not_owned_or_given_up() -> void:
	var owned: Array[String] = ["t1_neutral"]
	var given_up: Array[String] = ["t2_fire"]
	var eligible := RelicOffer.eligible("elite", _weights_act1(), owned, given_up, _rogue_pools(), _catalog())
	var ids: Array[String] = []
	for relic: Dictionary in eligible:
		ids.append(String(relic["id"]))
	# t1_fire, t1_rogue (pools ok); t1_neutral owned; t2_fire given up; t2_wizard wrong pool; t3 weight 0 in act 1; boss excluded
	assert_array(ids).is_equal(["t1_fire", "t1_rogue"])
	assert_array(RelicOffer.eligible("merchant", _weights_act1(), _none(), _none(), _rogue_pools(), _catalog()).map(func(r: Dictionary) -> String: return r["id"])).is_equal(["t1_neutral"])
	assert_array(RelicOffer.eligible("relic_room", _weights_act1(), _none(), _none(), _rogue_pools(), _catalog()).map(func(r: Dictionary) -> String: return r["id"])).is_equal(["t1_fire"])


func test_an_offer_never_includes_owned_or_given_up_relics_over_many_seeds() -> void:
	var owned: Array[String] = ["t1_fire"]
	var given_up: Array[String] = ["t1_rogue"]
	for seed_value in range(1, 60):
		var picks := RelicOffer.offer("elite", 3, _rng(seed_value), {"tier1": 50.0, "tier2": 50.0, "tier3": 50.0}, owned, given_up, _rogue_pools(), _catalog())
		assert_bool(picks.has("t1_fire") or picks.has("t1_rogue")).is_false()
		assert_int(picks.size()).is_equal(3)
		assert_int(picks.size()).is_equal(_unique(picks).size())  # no duplicates inside one offer


func _unique(ids: Array[String]) -> Array[String]:
	var seen: Array[String] = []
	for id: String in ids:
		if not seen.has(id):
			seen.append(id)
	return seen


func test_an_offer_is_deterministic_for_a_seed_and_ignores_catalog_order() -> void:
	var weights := {"tier1": 50.0, "tier2": 30.0, "tier3": 20.0}
	var first := RelicOffer.offer("elite", 3, _rng(42), weights, _none(), _none(), _rogue_pools(), _catalog())
	var again := RelicOffer.offer("elite", 3, _rng(42), weights, _none(), _none(), _rogue_pools(), _catalog())
	var reversed := _catalog()
	reversed.reverse()
	var shuffled := RelicOffer.offer("elite", 3, _rng(42), weights, _none(), _none(), _rogue_pools(), reversed)
	assert_array(again).is_equal(first)
	assert_array(shuffled).is_equal(first)
	var differs := false
	for seed_value in range(1, 40):
		if RelicOffer.offer("elite", 3, _rng(seed_value), weights, _none(), _none(), _rogue_pools(), _catalog()) != first:
			differs = true
	assert_bool(differs).override_failure_message("the offer never changes with the seed").is_true()


func test_a_tier_with_weight_zero_is_never_offered() -> void:
	for seed_value in range(1, 50):
		var picks := RelicOffer.offer("elite", 3, _rng(seed_value), _weights_act1(), _none(), _none(), _rogue_pools(), _catalog())
		assert_bool(picks.has("t3_neutral")).is_false()
	# with act 3's weights it can be
	var found := false
	for seed_value in range(1, 50):
		if RelicOffer.offer("elite", 3, _rng(seed_value), {"tier1": 5.0, "tier2": 25.0, "tier3": 70.0}, _none(), _none(), _rogue_pools(), _catalog()).has("t3_neutral"):
			found = true
	assert_bool(found).is_true()


func test_tier_weights_shape_how_often_a_tier_comes_first() -> void:
	var catalog: Array = [_relic("a", "neutral", "tier1", ["elite"]), _relic("b", "neutral", "tier2", ["elite"])]
	var a_first := 0
	var pools: Array[String] = ["neutral"]
	for seed_value in range(1, 401):
		if RelicOffer.offer("elite", 1, _rng(seed_value), {"tier1": 80.0, "tier2": 20.0, "tier3": 0.0}, _none(), _none(), pools, catalog)[0] == "a":
			a_first += 1
	# 80% expected; a wide band keeps this stable
	assert_int(a_first).is_between(280, 360)


func test_fewer_eligible_than_asked_returns_fewer_and_none_returns_empty() -> void:
	var picks := RelicOffer.offer("relic_room", 3, _rng(1), _weights_act1(), _none(), _none(), _rogue_pools(), _catalog())
	assert_array(picks).is_equal(["t1_fire"])
	assert_array(RelicOffer.offer("starter", 3, _rng(1), _weights_act1(), _none(), _none(), _rogue_pools(), _catalog())).is_empty()
	assert_array(RelicOffer.offer("elite", 0, _rng(1), _weights_act1(), _none(), _none(), _rogue_pools(), _catalog())).is_empty()
	assert_array(RelicOffer.offer("elite", 3, _rng(1), _weights_act1(), _none(), _none(), _rogue_pools(), [])).is_empty()
	var everything: Array[String] = ["t1_fire", "t1_rogue", "t1_neutral", "t2_fire"]
	assert_array(RelicOffer.offer("elite", 3, _rng(1), _weights_act1(), everything, _none(), _rogue_pools(), _catalog())).is_empty()


func test_the_mini_boss_offer_asks_for_the_boss_rarity_and_draws_uniformly() -> void:
	var boss_only: Array[String] = ["boss"]
	var counts: Dictionary = {"boss_a": 0, "boss_b": 0}
	for seed_value in range(1, 201):
		var picks := RelicOffer.offer("mini_boss", 1, _rng(seed_value), _weights_act1(), _none(), _none(), _rogue_pools(), _catalog(), boss_only)
		counts[picks[0]] = int(counts[picks[0]]) + 1
	assert_int(counts["boss_a"]).is_between(70, 130)
	assert_int(counts["boss_b"]).is_between(70, 130)
	# boss relics are not offered by default, even for the source that lists them
	var default_offer := RelicOffer.offer("mini_boss", 3, _rng(1), _weights_act1(), _none(), _none(), _rogue_pools(), _catalog())
	assert_bool(default_offer.has("boss_a") or default_offer.has("boss_b")).is_false()


func test_for_run_uses_the_character_pools_and_the_run_state() -> void:
	RelicDatabase.load_all(VALID_DIR)
	var state := RunState.new_run(3, ["rogue_quick_slash"] as Array[String], 3, "rogue")
	var rogue_ids := RelicOffer.for_run("elite", 5, _rng(5), 3, state)
	assert_bool(rogue_ids.has("test_wizard")).is_false()  # the wizard pool is not the Rogue's
	assert_bool(rogue_ids.has("test_pyre")).is_true()  # act 3 weights leave tier1 and tier3 both possible, five asked
	state.add_relic("test_pyre")
	state.give_up_relic("test_pyre")
	assert_bool(RelicOffer.for_run("elite", 5, _rng(5), 3, state).has("test_pyre")).is_false()
	var wizard_state := RunState.new_run(3, ["wizard_ember"] as Array[String], 3, "wizard")
	assert_bool(RelicOffer.for_run("elite", 6, _rng(5), 3, wizard_state).has("test_wizard")).is_true()


# --- the swap at the cap -----------------------------------------------------------------------

func test_boss_tier_relics_cannot_be_given_up() -> void:
	assert_bool(RelicOffer.can_give_up(_relic("a", "neutral", "tier3", ["elite"]))).is_true()
	assert_bool(RelicOffer.can_give_up(_relic("b", "neutral", "boss", ["mini_boss"]))).is_false()


func test_needs_swap_and_giveable_and_can_take_at_a_low_cap() -> void:
	assert_bool(RelicOffer.needs_swap(1, 2)).is_false()
	assert_bool(RelicOffer.needs_swap(2, 2)).is_true()
	var owned: Array[String] = ["boss_a", "t1_fire", "gone_from_data"]
	assert_array(RelicOffer.giveable(owned, _catalog())).is_equal(["t1_fire", "gone_from_data"])
	assert_bool(RelicOffer.can_take(owned, 3, _catalog())).is_true()
	var only_boss: Array[String] = ["boss_a", "boss_b"]
	assert_bool(RelicOffer.can_take(only_boss, 2, _catalog())).is_false()  # full of boss relics: nothing to give up
	assert_bool(RelicOffer.can_take(only_boss, 3, _catalog())).is_true()  # still room
