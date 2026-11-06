class_name Bd2bFlowTest
extends GdUnitTestSuite
## BD2-B: the relic run flow. Elite and relic-room offers, the straight run's relic room (placement over many seeds), the
## give-one-up swap at a low cap (including cancel), no owned or given-up relic offered, an offer with fewer than 3 or no
## eligible relics, the RunState round trip with relics, relics.enabled false (today's run exactly), the display data, and one
## scene-level pass through the real RunController.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const SHIPPED: Array[String] = ["heavy_sigh", "lingering_embers", "pyre_insurance", "second_wind_unwillingly", "smoldering_grudge", "spite_knuckles"]


func before_test() -> void:
	RunSession.map_override = 0  # MAP1: this suite is about the straight run
	RunSession.clear()
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.map_override = -1
	RunSession.clear()
	RunSession.start_relics = []
	RunSession.forced_relic_offer = []
	RunSession.relic_cap = 0
	RunConfig.reset_cache()
	Juice.reset()
	GamePause.reset()


func _ctx(cap: int = 20, enabled: bool = true, character: String = "rogue") -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools(character))
	(ctx["relics"] as Dictionary)["enabled"] = enabled
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	return ctx


func _state(seed_value: int = 5, room_index: int = 3) -> RunState:
	var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
	state.room_index = room_index
	return state


func _config_with_relics(enabled: bool) -> Dictionary:
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	(config["relics"] as Dictionary)["enabled"] = enabled
	return config


# --- the relic room: placement -------------------------------------------------------------------

func test_the_relic_room_lands_in_its_window_never_next_to_the_rest_room_or_the_elite() -> void:
	var config: Dictionary = _config_with_relics(true)
	var window: Dictionary = config["relics"]["relic_room"]
	var seen_indices: Dictionary = {}
	for seed_value in range(1, 501):
		var rooms: Array[Dictionary] = RunGenerator.generate(seed_value, config)
		assert_int(rooms.size()).is_equal(10)
		var relic_rooms: Array[int] = []
		for room: Dictionary in rooms:
			if String(room["type"]) == "relic_room":
				relic_rooms.append(int(room["index"]))
				assert_str(String(room["wave_id"])).is_empty()
		assert_array(relic_rooms).override_failure_message("seed %d needs exactly one relic room" % seed_value).has_size(1)
		var at: int = relic_rooms[0]
		seen_indices[at] = true
		assert_bool(at >= int(window["first"]) and at <= int(window["last"])).override_failure_message("seed %d: relic room at %d" % [seed_value, at]).is_true()
		for neighbour in [at - 1, at + 1]:
			assert_bool(["rest", "elite", "relic_room"].has(String(rooms[neighbour]["type"]))).override_failure_message("seed %d: relic room %d next to %s" % [seed_value, at, rooms[neighbour]["type"]]).is_false()
		assert_str(String(rooms[0]["type"])).is_equal("combat")
		assert_str(String(rooms[9]["type"])).is_equal("boss")
	assert_bool(seen_indices.size() >= 4).override_failure_message("the relic room should land in several places, got %s" % str(seen_indices.keys())).is_true()


func test_the_relic_room_never_leaves_the_same_wave_list_twice_in_a_row_around_it() -> void:
	# The generator's rule: a fight room avoids the previous fight room's wave list (rest and relic rooms are skipped) when another fits.
	var config: Dictionary = _config_with_relics(true)
	for seed_value in range(1, 600):
		var rooms: Array[Dictionary] = RunGenerator.generate(seed_value, config)
		var last_wave: String = ""
		for room: Dictionary in rooms:
			if String(room["type"]) == "rest" or String(room["type"]) == "relic_room":
				continue
			var options: Array = RunConfig.variants_for(int(room["index"]), (config["rooms"] as Dictionary)[room["type"]])
			var others: Array = options.filter(func(v: Dictionary) -> bool: return String(v["id"]) != last_wave)
			if not others.is_empty():
				assert_str(String(room["wave_id"])).override_failure_message("seed %d room %d repeats '%s' although %d other list(s) fit" % [seed_value, int(room["index"]) + 1, last_wave, others.size()]).is_not_equal(last_wave)
			last_wave = String(room["wave_id"])


func test_with_relics_off_the_run_is_exactly_what_it_was_and_with_them_on_only_one_combat_room_changes() -> void:
	var off: Dictionary = _config_with_relics(false)
	var plain: Dictionary = RunConfig.get_config().duplicate(true)
	plain.erase("relics")  # an old config with no relics block at all
	var on: Dictionary = _config_with_relics(true)
	for seed_value in range(1, 200):
		var rooms_off: Array[Dictionary] = RunGenerator.generate(seed_value, off)
		assert_array(rooms_off).is_equal(RunGenerator.generate(seed_value, plain))
		var rooms_on: Array[Dictionary] = RunGenerator.generate(seed_value, on)
		var converted: int = 0
		for i in range(rooms_off.size()):
			if rooms_on[i] != rooms_off[i]:
				if String(rooms_on[i]["type"]) == "relic_room":
					converted += 1
					assert_str(String(rooms_off[i]["type"])).is_equal("combat")
				else:
					# the only other change allowed: the fight room right after the relic room drew a different wave list
					assert_str(String(rooms_on[i - 1]["type"])).is_equal("relic_room")
					assert_str(String(rooms_on[i]["type"])).is_equal(String(rooms_off[i]["type"]))
					assert_str(String(rooms_on[i]["wave_id"])).is_not_equal(String(rooms_off[i]["wave_id"]))
		assert_int(converted).is_equal(1)
		assert_array(rooms_on).is_equal(RunGenerator.generate(seed_value, on))  # seeded


func test_a_config_with_no_free_combat_room_logs_it_and_makes_no_relic_room() -> void:
	var config: Dictionary = _config_with_relics(true)
	(config["relics"]["relic_room"] as Dictionary)["first"] = 8
	(config["relics"]["relic_room"] as Dictionary)["last"] = 8
	config["placement"]["ranges"]["elite"] = [7, 7]  # the elite sits next to the only slot allowed
	var rooms: Array[Dictionary] = RunGenerator.generate(3, config)
	assert_bool(rooms.any(func(r: Dictionary) -> bool: return String(r["type"]) == "relic_room")).is_false()
	assert_int(rooms.size()).is_equal(10)
	assert_bool(RunConfig.validate(config, EnemyConfig.enemy_ids(), [] as Array[String]).is_empty()).is_true()


func test_the_relics_block_validates_the_relic_room() -> void:
	var good: Dictionary = (RunConfig.get_config()["relics"] as Dictionary).duplicate(true)
	assert_array(RelicConfig.validate_block(good)).is_empty()
	var missing: Dictionary = good.duplicate(true)
	missing.erase("relic_room")
	assert_array(RelicConfig.validate_block(missing)).is_not_empty()
	var backwards: Dictionary = good.duplicate(true)
	backwards["relic_room"] = {"count": 1, "first": 6, "last": 3}
	assert_array(RelicConfig.validate_block(backwards)).is_not_empty()
	var first_room: Dictionary = good.duplicate(true)
	first_room["relic_room"] = {"count": 1, "first": 0, "last": 3}
	assert_array(RelicConfig.validate_block(first_room)).is_not_empty()


# --- offers --------------------------------------------------------------------------------------

func test_an_elite_room_offers_three_relics_instead_of_cards_and_a_combat_room_still_offers_cards() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	assert_str(RunRelics.open_for_room(state, "elite", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_int(state.offer.size()).is_equal(3)
	for relic_id: String in state.offer:
		assert_bool(SHIPPED.has(relic_id)).is_true()
	assert_bool(state.relics.is_empty() and state.deck.size() == 15).is_true()
	var combat: RunState = _state()
	assert_str(RunRelics.open_for_room(combat, "combat", false, ctx)).is_equal(RunState.PENDING_REWARD)
	for card_id: String in combat.offer:
		assert_bool(CardDatabase.has_card(card_id)).is_true()
	var rest: RunState = _state()
	assert_str(RunRelics.open_for_room(rest, "rest", false, ctx)).is_equal(RunState.PENDING_REST)  # D30 = A: no relics at rest
	var last: RunState = _state()
	assert_str(RunRelics.open_for_room(last, "elite", true, ctx)).is_equal(RunState.PENDING_NONE)


func test_the_relic_room_offers_relics_and_the_same_seed_gives_the_same_offer() -> void:
	var ctx: Dictionary = _ctx()
	var a: RunState = _state(9, 4)
	var b: RunState = _state(9, 4)
	assert_str(RunRelics.open_for_room(a, "relic_room", false, ctx)).is_equal(RunState.PENDING_RELIC)
	RunRelics.open_for_room(b, "relic_room", false, ctx)
	assert_array(a.offer).is_equal(b.offer)
	var other: RunState = _state(10, 4)
	var differs: bool = false
	for seed_value in range(10, 40):
		var c: RunState = _state(seed_value, 4)
		RunRelics.open_for_room(c, "relic_room", false, ctx)
		differs = differs or c.offer != a.offer
	assert_bool(differs).is_true()
	assert_object(other).is_not_null()


func test_with_relics_off_an_elite_gives_its_card_offer_as_before() -> void:
	var off: Dictionary = _ctx(20, false)
	var state: RunState = _state()
	assert_str(RunRelics.open_for_room(state, "elite", false, off)).is_equal(RunState.PENDING_REWARD)
	var legacy: RunState = _state()
	RunChoices.open_for_room(legacy, "elite", false, off)
	assert_array(state.offer).is_equal(legacy.offer)
	# a context with no relics entry at all (the old tests' contexts) behaves the same
	var bare: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	bare.erase("relics")
	var third: RunState = _state()
	assert_str(RunRelics.open_for_room(third, "elite", false, bare)).is_equal(RunState.PENDING_REWARD)
	assert_array(third.offer).is_equal(legacy.offer)


func test_an_offer_never_holds_an_owned_or_given_up_relic_and_a_short_offer_shows_what_is_left() -> void:
	var ctx: Dictionary = _ctx()
	for seed_value in range(1, 60):
		var state: RunState = _state(seed_value, 4)
		state.relics = ["pyre_insurance", "heavy_sigh"] as Array[String]
		state.relics_given_up = ["spite_knuckles"] as Array[String]
		RunRelics.open_for_room(state, "elite", false, ctx)
		assert_int(state.offer.size()).is_equal(3)  # 6 relics, 3 gone, 3 left
		for relic_id: String in state.offer:
			assert_bool(["pyre_insurance", "heavy_sigh", "spite_knuckles"].has(relic_id)).is_false()
	var few: RunState = _state(3, 4)
	few.relics = ["pyre_insurance", "heavy_sigh", "lingering_embers"] as Array[String]
	few.relics_given_up = ["spite_knuckles", "smoldering_grudge"] as Array[String]
	assert_str(RunRelics.open_for_room(few, "relic_room", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_array(few.offer).is_equal(["second_wind_unwillingly"])
	var wizard: Dictionary = _ctx(20, true, "wizard")
	var wizard_state: RunState = _state(3, 4)
	wizard_state.relics = ["pyre_insurance", "heavy_sigh"] as Array[String]
	RunRelics.open_for_room(wizard_state, "elite", false, wizard)
	assert_bool(wizard_state.offer.has("spite_knuckles")).is_false()  # a rogue pool relic


func test_with_no_eligible_relic_the_elite_and_the_relic_room_give_a_card_offer() -> void:
	var ctx: Dictionary = _ctx()
	for source: String in ["elite", "relic_room"]:
		var state: RunState = _state(4, 4)
		state.relics = ["pyre_insurance", "heavy_sigh", "lingering_embers", "second_wind_unwillingly"] as Array[String]
		state.relics_given_up = ["spite_knuckles", "smoldering_grudge"] as Array[String]
		assert_str(RunRelics.open_for_room(state, source, false, ctx)).override_failure_message(source).is_equal(RunState.PENDING_REWARD)
		assert_int(state.offer.size()).is_equal(RunConfig.offer_size())
		assert_str(state.relic_incoming).is_empty()


# --- picking, skipping, the swap -----------------------------------------------------------------

func _open_elite(ctx: Dictionary, held: Array[String] = []) -> RunState:
	var state: RunState = _state(6, 4)
	state.relics = held.duplicate()
	RunRelics.open_for_room(state, "elite", false, ctx)
	return state


func test_picking_a_relic_adds_it_and_closes_the_choice_and_skipping_is_free() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _open_elite(ctx)
	var first: String = state.offer[0]
	var rejects: int = state.rejects_remaining
	var result: Dictionary = RunChoices.apply(state, "relic:" + first, ctx)
	assert_bool(bool(result["ok"])).is_true()
	assert_str(String(result["kind"])).is_equal("relic_pick")
	assert_str(String(result["relic_id"])).is_equal(first)
	assert_bool(bool(result["finished"])).is_true()
	assert_array(state.relics).is_equal([first])
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_array(state.offer).is_empty()
	assert_int(state.rejects_remaining).is_equal(rejects)
	assert_str(String(state.choice_log[state.choice_log.size() - 1]["kind"])).is_equal("relic")
	var skipping: RunState = _open_elite(ctx)
	var skipped: Dictionary = RunChoices.apply(skipping, "relic_skip", ctx)
	assert_bool(bool(skipped["finished"])).is_true()
	assert_array(skipping.relics).is_empty()
	assert_int(skipping.rejects_remaining).is_equal(rejects)  # a skip is not a card reject
	assert_bool(RunChoices.apply(skipping, "relic:" + first, ctx)["ok"]).is_false()  # the choice is closed


func test_at_the_cap_taking_a_relic_first_asks_which_to_give_up_and_cancel_keeps_everything() -> void:
	var ctx: Dictionary = _ctx(2)
	var held: Array[String] = ["pyre_insurance", "heavy_sigh"]
	var state: RunState = _open_elite(ctx, held)
	var offer_before: Array[String] = state.offer.duplicate()
	var wanted: String = state.offer[0]
	var opened: Dictionary = RunChoices.apply(state, "relic:" + wanted, ctx)
	assert_bool(bool(opened["ok"])).is_true()
	assert_bool(bool(opened["finished"])).is_false()
	assert_str(String(opened["kind"])).is_equal("relic_swap_open")
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	assert_str(state.relic_incoming).is_equal(wanted)
	assert_array(state.relics).is_equal(held)  # nothing has changed yet
	var model: Dictionary = RunChoices.model(state, ctx, "elite")
	assert_str(String(model["relic_choice"])).is_equal("giveup")
	assert_str(String(model["incoming"]["relic_id"])).is_equal(wanted)
	assert_int((model["giveable"] as Array).size()).is_equal(2)
	assert_str(String((model["options"] as Array)[0]["kind"])).is_equal("giveup")
	assert_str(String((model["options"] as Array)[2]["kind"])).is_equal("back")
	# cancel: the offer is back as it was, and nothing was given up
	var cancelled: Dictionary = RunChoices.apply(state, "giveup_cancel", ctx)
	assert_bool(bool(cancelled["ok"])).is_true()
	assert_bool(bool(cancelled["finished"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.relic_incoming).is_empty()
	assert_array(state.offer).is_equal(offer_before)
	assert_array(state.relics).is_equal(held)
	assert_array(state.relics_given_up).is_empty()
	# do it for real
	RunChoices.apply(state, "relic:" + wanted, ctx)
	var done: Dictionary = RunChoices.apply(state, "giveup:pyre_insurance", ctx)
	assert_bool(bool(done["finished"])).is_true()
	assert_str(String(done["kind"])).is_equal("relic_swap")
	assert_str(String(done["gave_up"])).is_equal("pyre_insurance")
	assert_array(state.relics).is_equal(["heavy_sigh", wanted])
	assert_array(state.relics_given_up).is_equal(["pyre_insurance"])
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	# a relic given up is never offered again
	for seed_value in range(1, 40):
		var later: RunState = _state(seed_value, 5)
		later.relics = state.relics.duplicate()
		later.relics_given_up = state.relics_given_up.duplicate()
		RunRelics.open_for_room(later, "relic_room", false, ctx)
		assert_bool(later.offer.has("pyre_insurance")).is_false()


func test_a_skip_at_the_cap_needs_no_swap_and_a_giveup_you_do_not_hold_is_refused() -> void:
	var ctx: Dictionary = _ctx(1)
	var state: RunState = _open_elite(ctx, ["pyre_insurance"] as Array[String])
	assert_bool(bool(RunChoices.apply(state, "relic_skip", ctx)["finished"])).is_true()
	assert_array(state.relics).is_equal(["pyre_insurance"])
	var swapping: RunState = _open_elite(ctx, ["pyre_insurance"] as Array[String])
	RunChoices.apply(swapping, "relic:" + swapping.offer[0], ctx)
	assert_bool(bool(RunChoices.apply(swapping, "giveup:heavy_sigh", ctx)["ok"])).is_false()
	assert_str(swapping.pending).is_equal(RunState.PENDING_RELIC_SWAP)


func test_boss_tier_relics_are_not_in_the_give_up_list() -> void:
	var ctx: Dictionary = _ctx(2)
	var boss_relic: Dictionary = {"id": "test_boss_relic", "name": "Test Boss", "pool": "neutral", "rarity": "boss", "sources": ["mini_boss"], "keywords": [],
			"modifiers": [], "triggers": [], "rule_text": "x", "flavor_text": "y"}
	(ctx["relics"] as Dictionary)["catalog"] = (ctx["relics"]["catalog"] as Array) + [boss_relic]
	(ctx["relics"]["by_id"] as Dictionary)["test_boss_relic"] = boss_relic
	var state: RunState = _open_elite(ctx, ["test_boss_relic", "pyre_insurance"] as Array[String])
	RunChoices.apply(state, "relic:" + state.offer[0], ctx)
	var model: Dictionary = RunChoices.model(state, ctx, "elite")
	var ids: Array[String] = []
	for entry: Dictionary in model["giveable"]:
		ids.append(String(entry["relic_id"]))
	assert_array(ids).is_equal(["pyre_insurance"])
	assert_bool(bool(RunChoices.apply(state, "giveup:test_boss_relic", ctx)["ok"])).is_false()


func test_the_relic_options_carry_everything_the_screen_draws() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _open_elite(ctx)
	var model: Dictionary = RunChoices.model(state, ctx, "elite")
	assert_str(String(model["choice"])).is_equal(RunState.PENDING_RELIC)
	assert_str(String(model["title"])).is_not_empty()
	assert_str(String(model["relic_choice"])).is_equal("offer")
	var options: Array = model["options"]
	assert_int(options.size()).is_equal(4)  # 3 relics and the skip
	for i in range(3):
		var option: Dictionary = options[i]
		assert_str(String(option["kind"])).is_equal("relic")
		for key: String in ["relic_id", "name", "tier", "tier_name", "pool", "pool_name", "rule_text", "flavor", "keywords", "label", "detail", "needs_swap"]:
			assert_bool(option.has(key)).override_failure_message("option has no '%s'" % key).is_true()
		assert_str(String(option["rule_text"])).is_not_empty()
		assert_str(String(option["label"])).is_equal(String(option["name"]))
		assert_bool(["Tier 1", "Tier 2"].has(String(option["tier_name"]))).is_true()
		assert_bool(["Fire", "Neutral", "Rogue"].has(String(option["pool_name"]))).is_true()
		assert_bool(RunChoices.KINDS.has(String(option["kind"]))).is_true()
	assert_str(String(options[3]["kind"])).is_equal("relic_skip")
	assert_bool(bool(options[3]["costs_reject"])).is_false()
	var room_model: Dictionary = RunChoices.model(state, ctx, "relic_room")
	assert_str(String(room_model["title"])).is_not_equal(String(model["title"]))


# --- the save round trip -------------------------------------------------------------------------

func test_run_state_round_trips_relics_a_pending_offer_and_a_pending_swap() -> void:
	var ctx: Dictionary = _ctx(2)
	var state: RunState = _open_elite(ctx, ["pyre_insurance", "heavy_sigh"] as Array[String])
	state.relics_given_up = ["spite_knuckles"] as Array[String]
	var offered: RunState = RunState.from_json(state.to_json())
	assert_bool(offered.equals(state)).is_true()
	assert_str(offered.pending).is_equal(RunState.PENDING_RELIC)
	assert_array(offered.offer).is_equal(state.offer)
	assert_array(offered.relics).is_equal(["pyre_insurance", "heavy_sigh"])
	assert_array(offered.relics_given_up).is_equal(["spite_knuckles"])
	RunChoices.apply(state, "relic:" + state.offer[1], ctx)
	var swapping: RunState = RunState.from_json(state.to_json())
	assert_bool(swapping.equals(state)).is_true()
	assert_str(swapping.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	assert_str(swapping.relic_incoming).is_equal(state.offer[1])
	# a reloaded swap can be cancelled or finished like the live one
	assert_bool(bool(RunChoices.apply(swapping, "giveup_cancel", ctx)["ok"])).is_true()
	assert_str(swapping.pending).is_equal(RunState.PENDING_RELIC)


func test_a_saved_relic_choice_that_cannot_be_shown_is_dropped_not_stuck() -> void:
	var state: RunState = _state(5, 4)
	state.record_room({"index": 4, "type": "elite", "wave_id": "elite_brutes"}, 20.0, 30.0)
	var data: Dictionary = state.to_dict()
	data["pending"] = RunState.PENDING_RELIC
	data["offer"] = []
	var empty_offer: RunState = RunState.from_dict(data)
	assert_str(empty_offer.pending).is_equal(RunState.PENDING_NONE)
	assert_int(empty_offer.room_index).is_equal(5)  # the won room is not replayed
	data["pending"] = RunState.PENDING_RELIC_SWAP
	data["offer"] = ["pyre_insurance"]
	data["relic_incoming"] = "heavy_sigh"  # not in the offer
	assert_str(RunState.from_dict(data).pending).is_equal(RunState.PENDING_NONE)
	data["relic_incoming"] = 7
	assert_str(RunState.from_dict(data).pending).is_equal(RunState.PENDING_NONE)
	var old: Dictionary = _state().to_dict()
	old.erase("relic_incoming")
	assert_str(RunState.from_dict(old).relic_incoming).is_empty()


# --- the launch flags ----------------------------------------------------------------------------

func test_the_relic_flags_parse_plus_and_commas_and_refuse_bad_ids() -> void:
	assert_array(RelicArgs.parse_ids("pyre_insurance+heavy_sigh,spite_knuckles")).is_equal(["pyre_insurance", "heavy_sigh", "spite_knuckles"])
	assert_array(RelicArgs.id_problems("--relics", ["pyre_insurance", "heavy_sigh"] as Array[String], 0)).is_empty()
	assert_array(RelicArgs.id_problems("--relics", [] as Array[String], 0)).is_not_empty()
	assert_array(RelicArgs.id_problems("--relics", ["nope"] as Array[String], 0)).is_not_empty()
	assert_array(RelicArgs.id_problems("--relics", ["heavy_sigh", "heavy_sigh"] as Array[String], 0)).is_not_empty()
	assert_array(RelicArgs.id_problems("--relic-offer", SHIPPED, 3)).is_not_empty()


func test_a_forced_relic_offer_replaces_the_first_offer_only() -> void:
	var ctx: Dictionary = _ctx()
	RunSession.forced_relic_offer = ["heavy_sigh", "spite_knuckles"] as Array[String]
	var first: RunState = _state()
	RunRelics.open_for_room(first, "elite", false, ctx)
	assert_array(first.offer).is_equal(["heavy_sigh", "spite_knuckles"])
	assert_array(RunSession.forced_relic_offer).is_empty()
	var second: RunState = _state()
	RunRelics.open_for_room(second, "elite", false, ctx)
	assert_int(second.offer.size()).is_equal(3)


func test_start_relics_and_the_cap_override_reach_a_new_run() -> void:
	RunSession.start_relics = ["pyre_insurance", "heavy_sigh"] as Array[String]
	RunSession.relic_cap = 2
	var state: RunState = RunSession.begin_new_run(11)
	assert_array(state.relics).is_equal(["pyre_insurance", "heavy_sigh"])
	assert_int(RunRelics.max_owned(RunChoices.shipped_context(CharacterDatabase.pools("rogue")))).is_equal(2)
	RunSession.start_relics = []
	RunSession.relic_cap = 0
	assert_array(RunSession.begin_new_run(11).relics).is_empty()


# --- through the real controller -----------------------------------------------------------------

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


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
	await _frames()


func _seed_with(room_type: String) -> Array[int]:
	for seed_value in range(1, 200):
		var rooms: Array[Dictionary] = RunGenerator.generate(seed_value, RunConfig.get_config())
		for room: Dictionary in rooms:
			if String(room["type"]) == room_type:
				return [seed_value, int(room["index"])]
	return [-1, -1]


func test_clearing_an_elite_room_opens_the_relic_offer_and_taking_one_makes_it_live() -> void:
	var found: Array[int] = _seed_with("elite")
	var state := RunSession.begin_new_run(found[0])
	state.room_index = found[1]
	var main := _spawn()
	await _frames(1)
	var controller: RunController = main.run_controller
	assert_object(controller.relic_manager()).is_null()
	var models: Array[Dictionary] = []
	controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	var changes: Array = []
	controller.relics_changed.connect(func(ids: Array[String]) -> void: changes.append(ids))
	await _win_room(main)
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_int(models.size()).is_equal(1)
	assert_str(String(models[0]["choice"])).is_equal("relic")
	assert_str(String(models[0]["room_type"])).is_equal("elite")
	assert_int(controller.relic_offer().size()).is_equal(3)
	assert_bool(controller.relic_swap_state()["active"]).is_false()
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	assert_bool(screen.is_open()).is_true()
	assert_int(screen.options_box.get_child_count()).is_equal(4)
	var wanted: String = String(controller.relic_offer()[1]["relic_id"])
	var result: Dictionary = controller.pick_relic(wanted)
	assert_bool(bool(result["ok"])).is_true()
	assert_array(state.relics).is_equal([wanted])
	assert_array(changes).has_size(1)
	assert_str(String(controller.owned_relics()[0]["relic_id"])).is_equal(wanted)
	var manager := controller.relic_manager()
	assert_object(manager).is_not_null()  # created when the first relic arrived
	assert_array(manager.relic_ids()).is_equal([wanted])
	assert_array(controller.given_up_relics()).is_empty()
	# the next room is loaded as a fresh scene that holds the relic from RunState
	await _frames(3)
	var next_main: Main = null
	for child in get_children():
		if child is Main and child != main and not child.is_queued_for_deletion():
			next_main = child as Main
	assert_object(next_main).is_not_null()
	assert_array(next_main.run_controller.relic_manager().relic_ids()).is_equal([wanted])


func test_the_relic_room_has_no_fight_and_opens_its_offer_at_once() -> void:
	var found: Array[int] = _seed_with("relic_room")
	var state := RunSession.begin_new_run(found[0])
	state.room_index = found[1]
	var main := _spawn()
	var models: Array[Dictionary] = []
	main.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _frames(3)
	assert_str(main.run_controller.room_type()).is_equal("relic_room")
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_int(main.enemy_spawner.alive_count()).is_equal(0)
	assert_int(models.size()).is_equal(1)
	assert_str(String(models[0]["room_type_name"])).is_equal("Relics")
	assert_str(String(models[0]["title"])).is_equal(String(RunConfig.ui()["relic"]["room_title"]))
	assert_str(String(main.run_controller.next_room_line())).starts_with("Next: Room")
	# skipping carries on to the next room with nothing taken
	main.run_controller.skip_relic_offer()
	await _frames(3)
	assert_array(state.relics).is_empty()
	assert_int(state.room_index).is_equal(found[1] + 1)


func test_the_swap_at_a_low_cap_through_the_controller_and_a_reload_mid_swap() -> void:
	RunSession.relic_cap = 1
	RunSession.start_relics = ["pyre_insurance"] as Array[String]
	var found: Array[int] = _seed_with("relic_room")
	var state := RunSession.begin_new_run(found[0])
	state.room_index = found[1]
	var main := _spawn()
	await _frames(3)
	var controller: RunController = main.run_controller
	assert_array(controller.relic_manager().relic_ids()).is_equal(["pyre_insurance"])
	var wanted: String = String(controller.relic_offer()[0]["relic_id"])
	var opened: Dictionary = controller.pick_relic(wanted)
	assert_str(String(opened["kind"])).is_equal("relic_swap_open")
	var swap: Dictionary = controller.relic_swap_state()
	assert_bool(swap["active"]).is_true()
	assert_str(String(swap["incoming"]["relic_id"])).is_equal(wanted)
	assert_int((swap["giveable"] as Array).size()).is_equal(1)
	assert_int(int(swap["max_owned"])).is_equal(1)
	assert_int(int(swap["owned_count"])).is_equal(1)
	assert_str(String(controller.current_choice()["relic_choice"])).is_equal("giveup")
	# a reload mid-swap reopens the same step (the run state is what survives)
	var restored: RunState = RunState.from_json(state.to_json())
	assert_str(restored.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	# cancel keeps everything
	controller.cancel_relic_swap()
	assert_array(state.relics).is_equal(["pyre_insurance"])
	assert_bool(controller.relic_swap_state()["active"]).is_false()
	assert_array(controller.relic_manager().relic_ids()).is_equal(["pyre_insurance"])
	controller.pick_relic(wanted)
	var gave: Dictionary = controller.give_up_relic("pyre_insurance")
	assert_bool(bool(gave["ok"])).is_true()
	assert_array(state.relics).is_equal([wanted])
	assert_array(state.relics_given_up).is_equal(["pyre_insurance"])
	assert_array(controller.relic_manager().relic_ids()).is_equal([wanted])
	assert_str(String(controller.given_up_relics()[0]["relic_id"])).is_equal("pyre_insurance")


func test_relic_triggers_are_forwarded_by_the_controller() -> void:
	RunSession.start_relics = ["second_wind_unwillingly"] as Array[String]
	var state := RunSession.begin_new_run(7)
	assert_array(state.relics).is_equal(["second_wind_unwillingly"])
	var main := _spawn()
	await _frames(1)
	var fired: Array[String] = []
	main.run_controller.relic_triggered.connect(func(relic_id: String, _index: int, event_id: String) -> void: fired.append("%s %s" % [relic_id, event_id]))
	var target := RelayTarget.new("enemy", 1.0)
	main.add_child(target)
	target.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 30.0, null, "card:x")
	target.hurtbox.receive_damage(5.0, "physical", Vector3.ZERO, main.player, Health.KIND_HIT, "light")
	main.run_controller.relic_manager().flush()
	assert_array(fired).is_equal(["second_wind_unwillingly enemy_killed"])


func test_with_relics_off_a_run_has_no_relic_room_no_manager_and_cards_after_the_elite() -> void:
	var config: Dictionary = RunConfig.get_config()
	(config["relics"] as Dictionary)["enabled"] = false  # the cached shipped config, restored by reset_cache in after_test
	RunSession.start_relics = ["pyre_insurance"] as Array[String]
	var found: Array[int] = _seed_with("elite")
	var state := RunSession.begin_new_run(found[0])
	state.room_index = found[1]
	var main := _spawn()
	await _frames(1)
	assert_object(main.run_controller.relic_manager()).is_null()  # relics.enabled false turns the whole feature off
	assert_bool(main.run_controller.rooms().any(func(r: Dictionary) -> bool: return String(r["type"]) == "relic_room")).is_false()
	await _win_room(main)
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
