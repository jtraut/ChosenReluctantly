class_name Map4b1Test
extends GdUnitTestSuite
## MAP4 sitting B1: the event engine. Every event and relic here is a fixture (tests/fixtures/events, or built in the test); no event ships yet and the
## `event` node weight in data/map.json is 0, so shipped runs are unchanged. Covers the schema, the loader, the seeded draw, requirements, the six outcomes
## B1 runs, the reserved event-only relic slot, the cap-20 step, the generated lines, the save round trip and its repair, the bot policy and map
## generation with a non-zero event weight.

const FIXTURES := "res://tests/fixtures/events"
const BAD_FIXTURES := "res://tests/fixtures/events_bad"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const SAVE_PATH := "user://tests/map4b1_save.json"


func before_test() -> void:
	RunSession.clear()
	RunSession.forced_event = ""
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()
	assert_array(EventDatabase.load_all(FIXTURES)).is_empty()


func after_test() -> void:
	EventDatabase.load_all()  # a fixture folder must not leak into later suites
	RunSession.clear()
	RunSession.forced_event = ""
	RunSession.relic_cap = 0
	RunSave.reset()
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


# --- helpers ---------------------------------------------------------------------------------------

func _relic(id: String, tier: String, sources: Array, pool: String = "neutral") -> Dictionary:
	return {"id": id, "name": id.capitalize(), "pool": pool, "rarity": tier, "sources": sources, "rule_text": "rule of " + id, "flavor_text": "", "keywords": [], "modifiers": []}


func _catalog() -> Array:
	var list: Array = []
	for letter: String in ["a", "b", "c", "d"]:
		list.append(_relic("n1" + letter, "tier1", ["elite", "relic_room", "merchant"]))
		list.append(_relic("n2" + letter, "tier2", ["elite", "relic_room", "merchant"]))
	for letter: String in ["a", "b", "c"]:
		list.append(_relic("n3" + letter, "tier3", ["elite", "relic_room", "merchant"]))
	list.append(_relic("ev1", "tier2", ["event"]))
	list.append(_relic("ev2", "tier1", ["event"]))
	list.append(_relic("ev3", "tier3", ["event"]))
	list.append(_relic("boss1", "boss", ["mini_boss"]))
	list.append(_relic("boss2", "boss", ["mini_boss"]))
	return list


## The shipped context with fixture relics (and the fixture events already loaded by before_test).
func _ctx(catalog: Array = []) -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var relics: Dictionary = ctx["relics"]
	var use: Array = catalog if not catalog.is_empty() else _catalog()
	relics["catalog"] = use
	var by_id: Dictionary = {}
	for relic: Variant in use:
		by_id[String((relic as Dictionary)["id"])] = relic
	relics["by_id"] = by_id
	return ctx


func _state(act: int = 1, run_seed: int = 11, room: int = 3) -> RunState:
	var state: RunState = RunState.new_run(run_seed, ["x"] as Array[String], 3)
	state.act = act
	state.room_index = room
	state.hp = 30.0
	state.max_hp = 30.0
	state.gold = 50
	return state


func _open(state: RunState, ctx: Dictionary, event_id: String) -> void:
	RunSession.forced_event = event_id
	assert_str(EventEngine.open_for_room(state, ctx)).is_equal(RunState.PENDING_EVENT)
	assert_str(state.event_id).is_equal(event_id)


## An event made on the spot with `outcomes` as its first choice (and a leave choice), opened on `state`.
func _adhoc(state: RunState, ctx: Dictionary, outcomes: Array, requires: Variant = null) -> void:
	var first: Dictionary = {"label": "Do it", "outcomes": outcomes}
	if requires != null:
		first["requires"] = requires
	var event: Dictionary = {"id": "adhoc", "name": "Adhoc", "flavor": "Made in a test.", "acts": [1, 2, 3],
			"choices": [first, {"label": "Leave", "outcomes": []}]}
	(ctx["events"]["catalog"] as Dictionary)["adhoc"] = event
	state.event_id = "adhoc"
	state.pending = RunState.PENDING_EVENT


func _pick(state: RunState, ctx: Dictionary, index: int = 0) -> Dictionary:
	return RunChoices.apply(state, "%s:%d" % [EventEngine.OPTION_CHOICE, index], ctx)


func _tier_of(relic_id: String) -> String:
	for relic: Variant in _catalog():
		if String((relic as Dictionary)["id"]) == relic_id:
			return String((relic as Dictionary)["rarity"])
	return ""


func _valid_event() -> Dictionary:
	return {"id": "ok", "name": "Ok", "flavor": "Fine.", "acts": [1], "choices": [
		{"label": "A", "outcomes": [{"type": "gain_gold", "amount": 5}]}, {"label": "B", "outcomes": []}]}


# --- the schema ------------------------------------------------------------------------------------

func test_the_fixture_events_are_valid_and_loaded() -> void:
	assert_array(EventDatabase.ids()).is_equal(["fx_act2", "fx_act3", "fx_paid", "fx_pay"])
	assert_bool(EventDatabase.has_event("fx_pay")).is_true()
	assert_str(String(EventDatabase.get_event("fx_pay")["name"])).is_equal("Fixture: The Toll")
	assert_array(EventSchema.validate(_valid_event(), "ok")).is_empty()


func test_the_schema_wants_two_or_three_choices() -> void:
	var one: Dictionary = _valid_event()
	one["choices"] = [{"label": "A", "outcomes": []}]
	assert_bool(EventSchema.validate(one).any(func(e: String) -> bool: return e.contains("2 to 3"))).is_true()
	var four: Dictionary = _valid_event()
	four["choices"] = [{"label": "A", "outcomes": []}, {"label": "B", "outcomes": []}, {"label": "C", "outcomes": []}, {"label": "D", "outcomes": []}]
	assert_bool(EventSchema.validate(four).any(func(e: String) -> bool: return e.contains("2 to 3"))).is_true()
	var three: Dictionary = _valid_event()
	three["choices"] = [{"label": "A", "outcomes": []}, {"label": "B", "outcomes": []}, {"label": "C", "outcomes": []}]
	assert_array(EventSchema.validate(three)).is_empty()


func test_the_schema_wants_one_choice_with_no_requirement() -> void:
	var event: Dictionary = _valid_event()
	event["choices"] = [
		{"label": "A", "requires": {"gold_at_least": 5}, "outcomes": []},
		{"label": "B", "requires": {"has_curse": true}, "outcomes": []}]
	assert_bool(EventSchema.validate(event).any(func(e: String) -> bool: return e.contains("no 'requires'"))).is_true()


func test_the_schema_rejects_an_unknown_outcome_and_a_nested_chance() -> void:
	var event: Dictionary = _valid_event()
	(event["choices"] as Array)[0]["outcomes"] = [{"type": "summon_dragon"}]
	assert_bool(EventSchema.validate(event).any(func(e: String) -> bool: return e.contains("summon_dragon"))).is_true()
	var nested: Dictionary = _valid_event()
	(nested["choices"] as Array)[0]["outcomes"] = [{"type": "chance", "p": 0.5, "win": [{"type": "chance", "p": 0.5, "win": [], "lose": []}], "lose": []}]
	assert_bool(EventSchema.validate(nested).any(func(e: String) -> bool: return e.contains("nested"))).is_true()


func test_the_schema_checks_every_param() -> void:
	var bad: Array = [
		{"type": "lose_hp", "fraction": 1.5}, {"type": "lose_hp", "fraction": 0}, {"type": "lose_hp"}, {"type": "lose_max_hp", "fraction": 0.95},
		{"type": "heal", "fraction": "lots"}, {"type": "gain_gold", "amount": 0}, {"type": "gain_gold", "amount": 2.5}, {"type": "lose_gold", "amount": -3},
		{"type": "gain_relic", "tier": 4}, {"type": "gain_relic", "tier": "later"}, {"type": "gain_relic", "tier": 1, "count": 9}, {"type": "gain_relic", "tier": 1, "skip": "no"},
		{"type": "gain_relic", "tier": 1, "color": "red"}, {"type": "chance", "p": 1.0, "win": [], "lose": []}, {"type": "chance", "p": 0.5, "win": []},
		{"type": "stat_mod", "stat": "x", "modifier_type": "sideways", "value": 1}, {"type": "merchant_discount", "fraction": 0},
		{"type": "sacrifice_relic", "select": "random"}, {"type": "start_fight", "tier": "boss"}]
	for outcome: Dictionary in bad:
		var event: Dictionary = _valid_event()
		(event["choices"] as Array)[0]["outcomes"] = [outcome]
		assert_array(EventSchema.validate(event)).override_failure_message("accepted %s" % str(outcome)).is_not_empty()


func test_the_schema_checks_the_top_level_and_the_requirements() -> void:
	for patch: Dictionary in [{"acts": []}, {"acts": [0]}, {"acts": [1, 1]}, {"weight": 0}, {"weight": -1}, {"name": ""}, {"flavor": 3}, {"extra": 1}, {"id": "bad id"}]:
		var event: Dictionary = _valid_event()
		for key: Variant in patch.keys():
			event[key] = patch[key]
		assert_array(EventSchema.validate(event)).override_failure_message("accepted %s" % str(patch)).is_not_empty()
	for requires: Dictionary in [{"gold_at_least": 0}, {"gold_at_least": 5, "has_curse": true}, {"flies": true}, {"has_curse": false}, {"owns_relic": {"min_tier": 3, "max_tier": 1}}, {"owns_relic": {"rank": 1}}]:
		var event: Dictionary = _valid_event()
		(event["choices"] as Array)[0]["requires"] = requires
		assert_array(EventSchema.validate(event)).override_failure_message("accepted %s" % str(requires)).is_not_empty()
	assert_array(EventSchema.validate({}, "x")).is_not_empty()
	assert_array(EventSchema.validate("not a dictionary")).is_not_empty()


func test_the_schema_knows_all_fourteen_outcomes_and_three_requirements() -> void:
	var samples: Array = [
		{"type": "lose_hp", "fraction": 0.2}, {"type": "lose_max_hp", "fraction": 0.1}, {"type": "heal", "fraction": 0.25}, {"type": "gain_gold", "amount": 50},
		{"type": "lose_gold", "amount": 40}, {"type": "gain_relic", "tier": "sacrificed_plus_one", "count": 3, "skip": false}, {"type": "gain_curse"},
		{"type": "gain_curse", "id": "property_damage"}, {"type": "remove_curse"}, {"type": "remove_card"}, {"type": "sacrifice_relic", "select": "highest", "min_tier": 1, "max_tier": 3},
		{"type": "start_fight", "tier": "elite"}, {"type": "chance", "p": 0.5, "win": [{"type": "gain_gold", "amount": 5}], "lose": []},
		{"type": "stat_mod", "stat": "move_speed", "modifier_type": "multiplicative", "value": 1.05}, {"type": "merchant_discount", "fraction": 0.5}]
	var names: Array[String] = []
	for sample: Dictionary in samples:
		names.append(String(sample["type"]))
		assert_array(EventSchema.validate_outcome(sample)).override_failure_message(str(sample)).is_empty()
	for outcome_name: String in EventSchema.OUTCOMES:
		assert_bool(names.has(outcome_name)).override_failure_message(outcome_name).is_true()
	assert_int(EventSchema.OUTCOMES.size()).is_equal(14)
	for requires: Dictionary in [{"gold_at_least": 40}, {"has_curse": true}, {"owns_relic": {"min_tier": 1}}, {"owns_relic": {}}]:
		var event: Dictionary = _valid_event()
		(event["choices"] as Array)[0]["requires"] = requires
		assert_array(EventSchema.validate(event)).override_failure_message(str(requires)).is_empty()


# --- the loader ------------------------------------------------------------------------------------

func test_a_missing_or_empty_events_folder_means_no_events() -> void:
	assert_array(EventDatabase.load_all("res://tests/fixtures/events_does_not_exist")).is_empty()
	assert_bool(EventDatabase.is_empty()).is_true()
	assert_array(EventDatabase.load_all()).is_empty()  # no problems: MAP4-D ships the 8 events of BUILD_DEPTH 13.3 in data/events
	assert_bool(EventDatabase.is_empty()).is_false()
	assert_int(EventDatabase.ids().size()).is_equal(8)


func test_the_loader_reports_bad_files_and_keeps_going() -> void:
	var problems: Array[String] = EventDatabase.load_all(BAD_FIXTURES)
	assert_int(problems.size()).is_equal(2)
	assert_bool(problems.any(func(p: String) -> bool: return p.contains("not_json.json") and p.contains("not valid JSON"))).is_true()
	assert_bool(problems.any(func(p: String) -> bool: return p.contains("fx_broken.json") and p.contains("2 to 3"))).is_true()
	assert_bool(EventDatabase.is_empty()).is_true()


# --- the node swap ---------------------------------------------------------------------------------

func test_the_event_node_replaces_curse_and_buff_rooms_and_ships_on_for_three_acts() -> void:
	var types: Dictionary = MapConfig.get_config()["types"]
	assert_bool(types.has("curse_room")).is_false()
	assert_bool(types.has("buff_room")).is_false()
	assert_float(float((types["event"] as Dictionary)["weight"])).is_equal(0.0)  # MAP4-D: the one-act run stays without events (its path rules cannot fill a map that holds them)
	assert_float(float((MapConfig.for_act(MapConfig.get_config(), 1, 3)["types"]["event"] as Dictionary)["weight"])).is_greater(0.0)  # and the three-act run has them
	assert_float(float((types["mini_boss"] as Dictionary)["weight"])).is_equal(0.0)  # in-act mini-bosses stay deferred
	assert_array((types["event"] as Dictionary)["rooms"]).is_equal([3.0, 9.0])
	assert_bool(bool((types["event"] as Dictionary)["no_repeat"])).is_true()
	assert_bool(MapConfig.NODE_TYPES.has("event")).is_true()
	assert_bool(MapConfig.FIGHT_TYPES.has("event")).is_false()  # a non-fight: it counts against min_fights like a rest
	assert_bool(MapConfig.RELIC_TYPES.has("event")).is_false()  # the relic estimate counts an event as 0
	var names: Dictionary = RunConfig.ui()["type_names"]
	assert_str(String(names["event"])).is_equal("Event")
	assert_bool(names.has("curse_room")).is_false()
	assert_bool(RunConfig.ui()["map"]["hover"].has("event")).is_true()
	assert_bool(RelicSchema.SOURCES.has("curse_room") and RelicSchema.SOURCES.has("buff_room")).is_true()  # still valid relic source ids
	assert_str(RunIcons.shape_for("event")).is_not_equal(RunIcons.shape_for("combat"))
	assert_int(int(RunConfig.get_config()["events"]["min_max_hp"])).is_equal(10)


func test_a_map_with_events_switched_on_stays_valid_over_a_seed_sweep() -> void:
	var cfg: Dictionary = MapConfig.get_config().duplicate(true)
	(cfg["types"]["event"] as Dictionary)["weight"] = 12
	var with_events: int = 0
	for act_number in range(1, 4):
		for seed_value in range(1, 31):
			var built: Dictionary = MapGenerator.build(seed_value, cfg, {}, act_number, 3)
			assert_bool(bool(built["ok"])).override_failure_message("seed %d act %d: %s" % [seed_value, act_number, str(built["error"])]).is_true()
			var map: Dictionary = built["map"]
			var rules: Dictionary = MapConfig.for_act(cfg, act_number, 3)
			assert_array(MapRules.check(map, rules)).override_failure_message("seed %d act %d" % [seed_value, act_number]).is_empty()
			var has_event: bool = false
			for entry: Dictionary in (map["nodes"] as Array):
				if String(entry["type"]) != "event":
					continue
				has_event = true
				assert_bool(int(entry["room"]) >= 3 and int(entry["room"]) <= 9).is_true()
				assert_str(String(entry["wave_id"])).is_empty()  # no fight, no wave
				for next_id: int in MapGraph.next_ids(map, int(entry["id"])):
					assert_str(String(MapGraph.node(map, next_id)["type"])).override_failure_message("two events in a row").is_not_equal("event")
			with_events += 1 if has_event else 0
	assert_int(with_events).is_greater(20)


func test_the_shipped_three_act_map_makes_event_nodes_in_rooms_3_to_9_and_the_one_act_map_none() -> void:
	var events: int = 0
	for seed_value in range(1, 40):
		var map: Dictionary = (MapGenerator.build(seed_value, MapConfig.get_config(), {}, 1, 3)["map"] as Dictionary)
		for entry: Dictionary in (MapGenerator.generate(seed_value)["nodes"] as Array):
			assert_str(String(entry["type"])).is_not_equal("event")  # the one-act run has none
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) == "event":
				events += 1
				assert_int(int(entry["room"])).is_between(3, 9)
	assert_int(events).is_greater(10)  # MAP4-D: events ship on


# --- the draw --------------------------------------------------------------------------------------

func test_the_draw_filters_by_act() -> void:
	var ctx: Dictionary = _ctx()
	assert_array(EventEngine.eligible_ids(_state(1), ctx)).is_equal(["fx_paid", "fx_pay"])
	assert_array(EventEngine.eligible_ids(_state(2), ctx)).is_equal(["fx_act2", "fx_pay"])
	assert_array(EventEngine.eligible_ids(_state(3), ctx)).is_equal(["fx_act3", "fx_pay"])
	for seed_value in range(1, 25):
		var state: RunState = _state(3, seed_value)
		assert_bool(["fx_act3", "fx_pay"].has(EventEngine.draw(state, ctx))).is_true()


func test_the_draw_is_deterministic_for_a_seed_and_a_room() -> void:
	var ctx: Dictionary = _ctx()
	var seen_ids: Array[String] = []
	for seed_value in range(1, 21):
		var one: String = EventEngine.draw(_state(2, seed_value, 4), ctx)
		var two: String = EventEngine.draw(_state(2, seed_value, 4), ctx)
		assert_str(two).is_equal(one)
		if not seen_ids.has(one):
			seen_ids.append(one)
	assert_int(seen_ids.size()).is_equal(2)  # and the seed does matter


func test_no_event_repeats_until_every_eligible_one_was_seen() -> void:
	var ctx: Dictionary = _ctx()
	for seed_value in range(1, 21):
		var state: RunState = _state(1, seed_value, 3)
		var first: String = EventEngine.draw(state, ctx)
		state.room_index = 5
		var second: String = EventEngine.draw(state, ctx)
		assert_str(second).override_failure_message("seed %d repeated %s" % [seed_value, first]).is_not_equal(first)
		assert_array(state.events_seen).is_equal([first, second] if first != second else [first])
		state.room_index = 7
		var third: String = EventEngine.draw(state, ctx)  # all seen: repeats are allowed again
		assert_bool(["fx_paid", "fx_pay"].has(third)).is_true()


func test_seen_events_of_another_act_do_not_block_this_acts_draw() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1, 5, 3)
	state.events_seen = ["fx_paid", "fx_pay"] as Array[String]
	state.act = 2
	assert_str(EventEngine.draw(state, ctx)).is_equal("fx_act2")  # fx_pay was seen, fx_act2 was not


func test_the_draw_uses_the_event_weight() -> void:
	var ctx: Dictionary = _ctx()
	var heavy: int = 0
	for seed_value in range(1, 401):
		if EventEngine.draw(_state(2, seed_value, 4), ctx) == "fx_act2":
			heavy += 1
	assert_int(heavy).override_failure_message("fx_act2 (weight 3 of 4) came up %d of 400 times" % heavy).is_between(260, 340)


func test_a_forced_event_is_drawn_once_whatever_the_act() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1)
	RunSession.forced_event = "fx_act3"
	assert_str(EventEngine.draw(state, ctx)).is_equal("fx_act3")
	assert_str(RunSession.forced_event).is_empty()
	assert_str(EventEngine.draw(state, ctx)).is_not_equal("fx_act3")


func test_no_eligible_event_ends_the_room_with_no_choice() -> void:
	var ctx: Dictionary = _ctx()
	(ctx["events"] as Dictionary)["catalog"] = {}
	var state: RunState = _state()
	assert_str(EventEngine.open_for_room(state, ctx)).is_equal(RunState.PENDING_NONE)
	assert_str(state.event_id).is_empty()
	assert_bool(state.has_pending()).is_false()


func test_entering_an_event_node_opens_the_drawn_event_through_the_run_choices() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1, 7)
	assert_str(RunChoices.open_for_room(state, "event", false, ctx)).is_equal(RunState.PENDING_EVENT)
	assert_str(state.event_id).is_not_empty()
	assert_array(state.events_seen).is_equal([state.event_id])
	var model: Dictionary = RunChoices.model(state, ctx, "event")
	assert_str(String(model["choice"])).is_equal(RunState.PENDING_EVENT)
	assert_str(String(model["title"])).is_equal(String((ctx["events"]["catalog"][state.event_id] as Dictionary)["name"]))
	assert_str(String(model["line"])).is_not_empty()  # the flavour text
	assert_int((model["options"] as Array).size()).is_greater_equal(2)
	for option: Dictionary in (model["options"] as Array):
		assert_str(String(option["kind"])).is_equal("event_choice")
		assert_str(String(option["label"])).is_not_empty()
		assert_str(String(option["detail"])).is_not_empty()
	assert_str(RunRelics.open_for_room(_state(1, 7), "event", false, ctx)).is_equal(RunState.PENDING_EVENT)  # the relic path hands it on unchanged


# --- requirements and generated lines --------------------------------------------------------------

func test_gold_at_least_greys_a_choice_with_its_reason() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.gold = 10
	_open(state, ctx, "fx_pay")
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_bool(bool(options[0]["enabled"])).is_false()
	assert_str(String(options[0]["reason"])).is_equal("Needs 40 gold (you have 10)")
	assert_bool(bool(options[1]["enabled"])).is_true()
	var refused: Dictionary = _pick(state, ctx, 0)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(String(refused["reason"])).contains("40")
	assert_int(state.gold).is_equal(10)
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT)
	state.gold = 40
	assert_bool(bool(RunChoices.options(state, ctx)[0]["enabled"])).is_true()


func test_has_curse_reads_as_unmet_while_the_deck_holds_no_curse() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [], {"has_curse": true})
	var option: Dictionary = RunChoices.options(state, ctx)[0]
	assert_bool(bool(option["enabled"])).is_false()
	assert_str(String(option["reason"])).is_equal("You have no curse")


func test_cost_and_gain_lines_are_generated_from_the_outcomes_with_the_characters_hp() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_open(state, ctx, "fx_pay")
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_array(options[0]["lines"]).is_equal(["Lose 40 gold", "Heal 8 HP"])  # 25% of 30 HP, rounded
	assert_array(options[1]["lines"]).is_equal(["Lose 6 HP", "Gain a relic (pick 1 of 3)"])
	assert_array(options[2]["lines"]).is_equal(["Walk away. Nothing happens."])
	assert_str(String(options[1]["detail"])).is_equal("Lose 6 HP\nGain a relic (pick 1 of 3)")
	state.max_hp = 45.0
	assert_array(RunChoices.options(state, ctx)[1]["lines"]).is_equal(["Lose 9 HP", "Gain a relic (pick 1 of 3)"])  # 20% of 45
	assert_array(options[0]["outcome_types"]).is_equal(["lose_gold", "heal"])
	assert_bool(bool(options[0]["has_requires"])).is_true()
	assert_bool(bool(options[1]["has_requires"])).is_false()
	var paid: RunState = _state()
	_open(paid, ctx, "fx_paid")
	assert_array(RunChoices.options(paid, ctx)[0]["lines"]).is_equal(["Gain a tier 2 relic (pick 1 of 3) (no skip)", "Lose 3 HP"])
	var act3: RunState = _state(3)
	_open(act3, ctx, "fx_act3")
	assert_array(RunChoices.options(act3, ctx)[0]["lines"]).is_equal(["Gain a relic at the next act's odds (pick 1 of 3)"])
	var act2: RunState = _state(2)
	_open(act2, ctx, "fx_act2")
	assert_array(RunChoices.options(act2, ctx)[0]["lines"]).is_equal(["Gain 30 gold", "Lose 3 max HP"])


# --- the outcomes ----------------------------------------------------------------------------------

func test_lose_hp_takes_a_fraction_of_max_hp_and_never_the_last_hit_point() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "lose_hp", "fraction": 0.2}])
	var result: Dictionary = _pick(state, ctx)
	assert_bool(bool(result["ok"]) and bool(result["finished"])).is_true()
	assert_bool(bool(result["event_state_changed"])).is_true()
	assert_float(state.hp).is_equal(24.0)
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_str(state.event_id).is_empty()
	var low: RunState = _state()
	low.hp = 3.0
	_adhoc(low, ctx, [{"type": "lose_hp", "fraction": 0.5}])
	_pick(low, ctx)
	assert_float(low.hp).is_equal(1.0)
	var one: RunState = _state()
	one.hp = 1.0
	_adhoc(one, ctx, [{"type": "lose_hp", "fraction": 0.5}])
	_pick(one, ctx)
	assert_float(one.hp).is_equal(1.0)


func test_lose_max_hp_has_a_floor_and_clamps_current_hp() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "lose_max_hp", "fraction": 0.1}])
	_pick(state, ctx)
	assert_float(state.max_hp).is_equal(27.0)
	assert_float(state.hp).is_equal(27.0)  # clamped to the new max
	var hurt: RunState = _state()
	hurt.hp = 10.0
	_adhoc(hurt, ctx, [{"type": "lose_max_hp", "fraction": 0.1}])
	_pick(hurt, ctx)
	assert_float(hurt.hp).is_equal(10.0)  # below the new max: untouched
	var small: RunState = _state()
	small.max_hp = 12.0
	small.hp = 12.0
	_adhoc(small, ctx, [{"type": "lose_max_hp", "fraction": 0.5}])
	_pick(small, ctx)
	assert_float(small.max_hp).is_equal(10.0)  # events.min_max_hp
	assert_float(small.hp).is_equal(10.0)
	var floor_hit: RunState = _state()
	floor_hit.max_hp = 10.0
	floor_hit.hp = 4.0
	_adhoc(floor_hit, ctx, [{"type": "lose_max_hp", "fraction": 0.3}])
	_pick(floor_hit, ctx)
	assert_float(floor_hit.max_hp).is_equal(10.0)  # already at the floor: never raised, never cut
	assert_float(floor_hit.hp).is_equal(4.0)


func test_heal_and_the_gold_outcomes() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.hp = 10.0
	_adhoc(state, ctx, [{"type": "heal", "fraction": 0.25}, {"type": "gain_gold", "amount": 15}, {"type": "lose_gold", "amount": 5}])
	var result: Dictionary = _pick(state, ctx)
	assert_bool(bool(result["finished"])).is_true()
	assert_float(state.hp).is_equal(18.0)  # +8 (25% of 30 rounded)
	assert_int(state.gold).is_equal(60)
	var full: RunState = _state()
	_adhoc(full, ctx, [{"type": "heal", "fraction": 0.5}])
	_pick(full, ctx)
	assert_float(full.hp).is_equal(30.0)  # capped at max
	var poor: RunState = _state()
	poor.gold = 30
	_adhoc(poor, ctx, [{"type": "lose_gold", "amount": 50}])
	_pick(poor, ctx)
	assert_int(poor.gold).is_equal(0)  # clamps at 0 and takes what there was


func test_outcomes_run_in_list_order_and_wait_for_the_relic_offer() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "gain_gold", "amount": 10}, {"type": "gain_relic", "tier": "act"}, {"type": "lose_gold", "amount": 5}, {"type": "lose_hp", "fraction": 0.1}])
	var opened: Dictionary = _pick(state, ctx)
	assert_bool(bool(opened["ok"])).is_true()
	assert_bool(bool(opened["finished"])).is_false()  # the relic offer is open
	assert_int(state.gold).is_equal(60)  # before the relic: applied
	assert_float(state.hp).is_equal(30.0)  # after the relic: waiting
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT)
	assert_int(state.event_queue.size()).is_equal(2)
	var done: Dictionary = RunChoices.apply(state, RunRelics.OPTION_SKIP, ctx)
	assert_bool(bool(done["ok"]) and bool(done["finished"])).is_true()
	assert_int(state.gold).is_equal(55)
	assert_float(state.hp).is_equal(27.0)
	assert_bool(bool(done["event_state_changed"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_str(state.offer_rarity).is_empty()
	assert_bool(state.event_queue.is_empty() and state.event_id.is_empty()).is_true()


func test_two_relic_offers_in_one_event_open_one_after_the_other() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "gain_relic", "tier": "act"}, {"type": "gain_gold", "amount": 7}, {"type": "gain_relic", "tier": "act"}])
	_pick(state, ctx)
	var first_offer: Array[String] = state.offer.duplicate()
	var picked: String = first_offer[0]
	var step: Dictionary = RunChoices.apply(state, "relic:" + picked, ctx)
	assert_bool(bool(step["finished"])).is_false()  # the second offer is open
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_int(state.gold).is_equal(57)
	assert_bool(state.offer.has(picked)).is_false()  # never offered again, it is owned now
	var last: Dictionary = RunChoices.apply(state, RunRelics.OPTION_SKIP, ctx)
	assert_bool(bool(last["finished"])).is_true()
	assert_array(state.relics).is_equal([picked])


func test_a_gain_curse_with_the_shipped_curses_adds_one_and_the_event_goes_on() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "gain_curse"}, {"type": "gain_gold", "amount": 5}])  # MAP4-D shipped the three curse cards
	var result: Dictionary = _pick(state, ctx)
	assert_bool(bool(result["finished"])).is_true()
	assert_int(state.gold).is_equal(55)
	assert_int(RunChoices.curse_ids(state, ctx).size()).is_equal(1)


func test_a_relic_offer_with_nothing_to_offer_is_skipped_and_the_event_goes_on() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	for relic: Variant in _catalog():
		state.relics.append(String((relic as Dictionary)["id"]))
	(ctx["relics"] as Dictionary)["max_owned"] = 99
	_adhoc(state, ctx, [{"type": "gain_relic", "tier": "act"}, {"type": "gain_gold", "amount": 9}])
	var result: Dictionary = _pick(state, ctx)
	assert_bool(bool(result["finished"])).is_true()
	assert_int(state.gold).is_equal(59)
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)


# --- relic offers ----------------------------------------------------------------------------------

func test_one_of_three_slots_is_reserved_for_an_event_only_relic() -> void:
	var ctx: Dictionary = _ctx()
	for seed_value in range(1, 41):
		var state: RunState = _state(1, seed_value)
		_adhoc(state, ctx, [{"type": "gain_relic", "tier": "act"}])
		_pick(state, ctx)
		assert_int(state.offer.size()).is_equal(3)
		var event_only: int = 0
		for relic_id: String in state.offer:
			if relic_id.begins_with("ev"):
				event_only += 1
		assert_int(event_only).override_failure_message("seed %d offered %s" % [seed_value, str(state.offer)]).is_equal(1)
		assert_bool(state.offer.has("boss1")).is_false()


func test_with_no_event_only_relic_left_all_three_slots_are_normal() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.relics = ["ev1", "ev2", "ev3"] as Array[String]
	_adhoc(state, ctx, [{"type": "gain_relic", "tier": "act"}])
	_pick(state, ctx)
	assert_int(state.offer.size()).is_equal(3)
	for relic_id: String in state.offer:
		assert_bool(relic_id.begins_with("n")).is_true()


func test_the_act_tier_mode_follows_the_act_and_next_act_follows_the_next_row() -> void:
	var ctx: Dictionary = _ctx()
	var tier3_in_act: int = 0
	var tier3_next: int = 0
	for seed_value in range(1, 61):
		var state: RunState = _state(1, seed_value)
		for relic_id: String in EventEngine.offer_ids(state, ctx, {"type": "gain_relic", "tier": "act"}):
			tier3_in_act += 1 if _tier_of(relic_id) == "tier3" else 0
		for relic_id: String in EventEngine.offer_ids(state, ctx, {"type": "gain_relic", "tier": "next_act"}):
			tier3_next += 1 if _tier_of(relic_id) == "tier3" else 0
	assert_int(tier3_in_act).is_equal(0)  # act 1's row has tier 3 at weight 0
	assert_int(tier3_next).is_greater(0)  # act 2's row does not
	var relics: Dictionary = ctx["relics"]
	assert_dict(RunRelics.weights_for(_state(3), relics, 1)).is_equal(RunRelics.weights_for(_state(3), relics, 0))  # act 3 has no act 4: it uses its own row
	assert_dict(RunRelics.weights_for(_state(1), relics, 1)).is_equal(RelicConfig.tier_weights_for_act(2))


func test_a_fixed_tier_offers_only_that_tier_and_falls_down_when_empty() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	for relic_id: String in EventEngine.offer_ids(state, ctx, {"type": "gain_relic", "tier": 3}):
		assert_str(_tier_of(relic_id)).is_equal("tier3")
	assert_int(EventEngine.offer_ids(state, ctx, {"type": "gain_relic", "tier": 3}).size()).is_equal(3)  # 3 normal + the reserved one is tier 3 too, count stays 3
	state.relics = ["n3a", "n3b", "n3c", "ev3"] as Array[String]
	var fallen: Array[String] = EventEngine.offer_ids(state, ctx, {"type": "gain_relic", "tier": 3})
	assert_bool(fallen.is_empty()).is_false()
	for relic_id: String in fallen:
		assert_str(_tier_of(relic_id)).is_equal("tier2")
	state.relics.append_array(["n2a", "n2b", "n2c", "n2d", "ev1"] as Array[String])
	for relic_id: String in EventEngine.offer_ids(state, ctx, {"type": "gain_relic", "tier": 3}):
		assert_str(_tier_of(relic_id)).is_equal("tier1")


func test_the_offer_is_deterministic_and_two_offers_in_an_event_differ_by_step() -> void:
	var ctx: Dictionary = _ctx()
	var one: Array[String] = EventEngine.offer_ids(_state(1, 9), ctx, {"type": "gain_relic", "tier": "act"})
	var two: Array[String] = EventEngine.offer_ids(_state(1, 9), ctx, {"type": "gain_relic", "tier": "act"})
	assert_array(one).is_equal(two)
	var differs: bool = false
	for seed_value in range(1, 20):
		if EventEngine.offer_ids(_state(1, seed_value), ctx, {"type": "gain_relic", "tier": "act"}, 0) != EventEngine.offer_ids(_state(1, seed_value), ctx, {"type": "gain_relic", "tier": "act"}, 1):
			differs = true
	assert_bool(differs).is_true()


func test_skip_defaults_to_true_and_false_means_no_skip_option() -> void:
	var ctx: Dictionary = _ctx()
	var skippable: RunState = _state()
	_adhoc(skippable, ctx, [{"type": "gain_relic", "tier": "act"}])
	_pick(skippable, ctx)
	var kinds: Array[String] = []
	for option: Dictionary in RunChoices.options(skippable, ctx):
		kinds.append(String(option["kind"]))
	assert_bool(kinds.has("relic_skip")).is_true()
	var paid: RunState = _state()
	_open(paid, ctx, "fx_paid")
	_pick(paid, ctx)
	assert_str(paid.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)
	for option: Dictionary in RunChoices.options(paid, ctx):
		assert_str(String(option["kind"])).is_equal("relic")
	var model: Dictionary = RunChoices.model(paid, ctx, "event")
	assert_str(String(model["title"])).is_equal("Take your pick")
	assert_str(String(model["line"])).is_equal("Pick one. You have already paid for it.")
	assert_bool(bool(model["event_offer"])).is_true()
	var picked: Dictionary = RunChoices.apply(paid, "relic:" + paid.offer[0], ctx)
	assert_bool(bool(picked["finished"])).is_true()
	assert_float(paid.hp).is_equal(27.0)  # fx_paid's lose_hp ran after the pick
	assert_int(paid.relics.size()).is_equal(1)
	assert_str(paid.offer_rarity).is_empty()


func test_a_no_skip_event_offer_gets_a_way_out_when_nothing_can_be_taken() -> void:
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["max_owned"] = 2
	var state: RunState = _state()
	state.relics = ["boss1", "boss2"] as Array[String]  # at the cap with only boss relics, which cannot be given up
	_open(state, ctx, "fx_paid")
	_pick(state, ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	var kinds: Array[String] = []
	for option: Dictionary in RunChoices.options(state, ctx):
		kinds.append(String(option["kind"]))
	assert_bool(kinds.has("relic_skip")).is_true()  # the screen can always close


func test_the_cap_step_works_inside_an_event_and_cancel_keeps_the_offer() -> void:
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["max_owned"] = 2
	var state: RunState = _state()
	state.relics = ["n1a", "n1b"] as Array[String]
	_adhoc(state, ctx, [{"type": "gain_relic", "tier": "act", "skip": false}, {"type": "gain_gold", "amount": 11}])
	_pick(state, ctx)
	var wanted: String = state.offer[0]
	var swap: Dictionary = RunChoices.apply(state, "relic:" + wanted, ctx)
	assert_str(String(swap["kind"])).is_equal("relic_swap_open")
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	assert_bool(EventEngine.is_event_offer(state)).is_true()
	var cancelled: Dictionary = RunChoices.apply(state, RunRelics.OPTION_CANCEL, ctx)
	assert_str(String(cancelled["kind"])).is_equal("relic_cancel")
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)  # still the paid offer
	assert_int(state.event_queue.size()).is_equal(1)
	RunChoices.apply(state, "relic:" + wanted, ctx)
	var done: Dictionary = RunChoices.apply(state, "giveup:n1a", ctx)
	assert_bool(bool(done["ok"]) and bool(done["finished"])).is_true()
	assert_array(state.relics).is_equal(["n1b", wanted])
	assert_array(state.relics_given_up).is_equal(["n1a"])
	assert_int(state.gold).is_equal(61)
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)


# --- save and resume -------------------------------------------------------------------------------

func _round_trip(state: RunState) -> RunState:
	return RunState.from_json(state.to_json())


func test_the_drawn_event_survives_a_save_round_trip() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state(1, 21)
	_open(state, ctx, "fx_pay")
	var back: RunState = _round_trip(state)
	assert_object(back).is_not_null()
	assert_str(back.pending).is_equal(RunState.PENDING_EVENT)
	assert_str(back.event_id).is_equal("fx_pay")
	assert_array(back.events_seen).is_equal(["fx_pay"])
	assert_bool(back.equals(state)).is_true()
	assert_array(RunChoices.options(back, ctx)).is_equal(RunChoices.options(state, ctx))  # the same screen


func test_a_pending_event_relic_offer_and_its_waiting_outcomes_round_trip() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_open(state, ctx, "fx_paid")
	_pick(state, ctx)
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)
	var back: RunState = _round_trip(state)
	assert_object(back).is_not_null()
	assert_str(back.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(back.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)  # not reset to a normal offer
	assert_array(back.offer).is_equal(state.offer)
	assert_int(back.event_queue.size()).is_equal(1)
	assert_str(String(back.event_queue[0]["type"])).is_equal("lose_hp")
	assert_bool(back.equals(state)).is_true()
	var done: Dictionary = RunChoices.apply(back, "relic:" + back.offer[0], ctx)  # and it finishes the same way
	assert_bool(bool(done["finished"])).is_true()
	assert_float(back.hp).is_equal(27.0)
	var swapped: RunState = _state()
	(ctx["relics"] as Dictionary)["max_owned"] = 1
	var real_relic: String = RelicDatabase.ids()[0]  # a saved state may only hold relics the data has
	swapped.relics = [real_relic] as Array[String]
	_open(swapped, ctx, "fx_paid")
	_pick(swapped, ctx)
	RunChoices.apply(swapped, "relic:" + swapped.offer[0], ctx)
	assert_str(swapped.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	var swap_back: RunState = _round_trip(swapped)
	assert_object(swap_back).is_not_null()
	assert_str(swap_back.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	assert_str(swap_back.offer_rarity).is_equal(RunState.OFFER_EVENT_NOSKIP)
	assert_bool(swap_back.equals(swapped)).is_true()


func test_whole_number_params_survive_the_json_round_trip_as_ints() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "gain_relic", "tier": 2, "count": 3.0}, {"type": "gain_gold", "amount": 12.0}])
	_pick(state, ctx)
	assert_int(typeof(state.event_queue[0]["amount"])).is_equal(TYPE_INT)
	assert_bool(_round_trip(state).equals(state)).is_true()


func test_a_damaged_event_save_is_repaired_without_a_crash() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_open(state, ctx, "fx_pay")
	var data: Dictionary = state.to_dict()
	# an event the data no longer has: the choice is dropped
	var unknown: Dictionary = data.duplicate(true)
	unknown["event_id"] = "no_such_event"
	var dropped: RunState = RunState.from_dict(unknown)
	assert_object(dropped).is_not_null()
	assert_str(dropped.pending).is_equal(RunState.PENDING_NONE)
	assert_str(dropped.event_id).is_empty()
	# wrong types
	var typed: Dictionary = data.duplicate(true)
	typed["event_id"] = 7
	typed["events_seen"] = "fx_pay"
	typed["event_queue"] = {"a": 1}
	var repaired: RunState = RunState.from_dict(typed)
	assert_object(repaired).is_not_null()
	assert_str(repaired.pending).is_equal(RunState.PENDING_NONE)  # pending 'event' with no id: dropped
	assert_array(repaired.events_seen).is_empty()
	assert_bool(repaired.event_queue.is_empty()).is_true()
	# a bad outcome in the queue drops the whole queue
	var bad_queue: Dictionary = data.duplicate(true)
	bad_queue["pending"] = RunState.PENDING_RELIC
	bad_queue["offer"] = ["n1a"]
	bad_queue["offer_rarity"] = RunState.OFFER_EVENT
	bad_queue["event_queue"] = [{"type": "lose_hp", "fraction": 9}]
	var no_queue: RunState = RunState.from_dict(bad_queue)
	assert_object(no_queue).is_not_null()
	assert_bool(no_queue.event_queue.is_empty()).is_true()
	assert_str(no_queue.pending).is_equal(RunState.PENDING_RELIC)
	# a queue with no event offer to wait for
	var stray: Dictionary = data.duplicate(true)
	stray["event_queue"] = [{"type": "gain_gold", "amount": 5}]
	assert_bool(RunState.from_dict(stray).event_queue.is_empty()).is_true()
	# an event offer marker on a card reward is reset
	var wrong_marker: Dictionary = data.duplicate(true)
	wrong_marker["pending"] = RunState.PENDING_REWARD
	wrong_marker["offer"] = ["x"]
	wrong_marker["offer_rarity"] = RunState.OFFER_EVENT
	assert_str(RunState.from_dict(wrong_marker).offer_rarity).is_empty()
	# an old save has none of the keys
	var old: Dictionary = data.duplicate(true)
	old["pending"] = RunState.PENDING_NONE
	for key: String in ["event_id", "events_seen", "event_queue"]:
		old.erase(key)
	var old_state: RunState = RunState.from_dict(old)
	assert_object(old_state).is_not_null()
	assert_str(old_state.event_id).is_empty()


func test_an_event_choice_is_a_save_boundary_and_continue_gives_the_same_screen() -> void:
	var ctx: Dictionary = _ctx()
	RunSave.reset()
	RunSave.path = SAVE_PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	var state: RunState = RunSession.begin_new_run(31, "rogue")
	state.jump_to_room(4)
	state.hp = 30.0
	state.max_hp = 30.0
	assert_bool(RunSave.is_boundary(state)).is_true()
	_open(state, ctx, "fx_paid")
	assert_bool(RunSave.is_boundary(state)).is_true()  # the choice screen
	assert_bool(RunSave.autosave(state)).is_true()
	_pick(state, ctx)  # pay: the no-skip relic offer opens
	assert_bool(RunSave.is_boundary(state)).is_true()  # the paid offer is a boundary too: quitting cannot refund the choice
	assert_bool(RunSave.autosave(state)).is_true()
	var back: RunState = RunSave.read_state()
	assert_object(back).is_not_null()
	assert_bool(back.equals(state)).is_true()
	var reward: RunState = RunSession.begin_new_run(32, "rogue")
	reward.jump_to_room(4)
	reward.pending = RunState.PENDING_REWARD
	assert_bool(RunSave.is_boundary(reward)).is_false()  # the other choices stay as they were
	RunSave.delete_save()


func test_the_event_flag_is_a_debug_flag_that_never_saves() -> void:
	assert_bool(RunSave.args_suppress(PackedStringArray(["--event=fx_pay"]))).is_true()


# --- the bot ---------------------------------------------------------------------------------------

func _options_of(event_id: String, state: RunState = null) -> Array:
	var ctx: Dictionary = _ctx()
	var use: RunState = state if state != null else _state()
	_open(use, ctx, event_id)
	return RunChoices.options(use, ctx)


func test_the_relic_bot_takes_the_relic_choice_while_healthy_else_a_free_one() -> void:
	var options: Array = _options_of("fx_pay")
	assert_str(RouteBot.event_choice(options, "relic", 1.0)).is_equal("event_choice:1")
	assert_str(RouteBot.event_choice(options, "relic", 0.5)).is_equal("event_choice:1")
	assert_str(RouteBot.event_choice(options, "relic", 0.49)).is_equal("event_choice:2")  # no cost: leave
	var paid: Array = _options_of("fx_paid")
	assert_str(RouteBot.event_choice(paid, "relic", 0.9)).is_equal("event_choice:0")


func test_the_safe_bot_avoids_hp_loss_curses_and_fights() -> void:
	var rich: Array = _options_of("fx_pay")
	assert_str(RouteBot.event_choice(rich, "safe", 1.0)).is_equal("event_choice:0")  # pay gold, heal: no HP cost
	var state: RunState = _state()
	state.gold = 5
	var poor: Array = _options_of("fx_pay", state)
	assert_str(RouteBot.event_choice(poor, "safe", 1.0)).is_equal("event_choice:2")
	var costly: Array = [
		{"id": "event_choice:0", "enabled": true, "outcome_types": ["lose_hp"], "has_requires": false},
		{"id": "event_choice:1", "enabled": true, "outcome_types": ["start_fight"], "has_requires": true}]
	assert_str(RouteBot.event_choice(costly, "safe", 1.0)).is_equal("event_choice:0")  # every choice costs: the free-to-enter one
	assert_str(RouteBot.event_choice(costly, "relic", 0.2)).is_equal("event_choice:0")


func test_the_first_bot_and_the_other_policies_take_the_first_available_choice() -> void:
	var state: RunState = _state()
	state.gold = 5
	var options: Array = _options_of("fx_pay", state)
	assert_str(RouteBot.event_choice(options, "first", 1.0)).is_equal("event_choice:1")  # choice 0 is greyed
	assert_str(RouteBot.event_choice(options, "random", 1.0)).is_equal("event_choice:1")
	assert_str(RouteBot.event_choice(options, "", 1.0)).is_equal("event_choice:1")
	assert_str(RouteBot.event_choice([], "first", 1.0)).is_empty()
	assert_str(RouteBot.event_choice([{"id": "a", "enabled": false}], "first", 1.0)).is_empty()


func test_chance_branches_count_as_outcome_types_for_the_bot() -> void:
	var types: Array[String] = EventEngine.outcome_types([{"type": "chance", "p": 0.5, "win": [{"type": "gain_relic", "tier": 2}], "lose": [{"type": "lose_hp", "fraction": 0.1}]}])
	assert_array(types).contains_exactly(["chance", "gain_relic", "lose_hp"])


# --- through the real controller -------------------------------------------------------------------

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


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
			var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			return state
	return null


func test_the_controller_opens_the_event_pays_its_cost_on_the_live_player_and_moves_on() -> void:
	var state: RunState = _state_on_event(1)
	assert_object(state).is_not_null()
	state.gold = 60
	RunSession.current = state
	RunSession.forced_event = "fx_pay"
	var main := _spawn()
	var models: Array[Dictionary] = []
	main.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	var golds: Array[int] = []
	main.run_controller.gold_changed.connect(func(total: int, _delta: int) -> void: golds.append(total))
	await _frames()
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("event")
	assert_int(main.enemy_spawner.alive_count()).is_equal(0)  # no fight
	assert_bool(controller.is_cleared()).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT)
	assert_str(state.event_id).is_equal("fx_pay")
	var max_hp: float = main.player.health.max_health
	assert_float(state.max_hp).is_equal(max_hp)
	# "Pay up": lose 40 gold, heal 25% of max HP
	main.player.health.current_health = 10.0
	state.hp = 10.0
	var result: Dictionary = controller.choose("event_choice:0")
	assert_bool(bool(result["ok"]) and bool(result["finished"])).is_true()
	assert_int(state.gold).is_equal(20)
	assert_array(golds).is_equal([20])
	var healed: float = minf(10.0 + float(EventEngine.hp_amount(0.25, max_hp)), max_hp)
	assert_float(main.player.health.current_health).is_equal(healed)  # the live player has the healed HP
	assert_float(state.hp).is_equal(healed)  # and the state kept it (the controller no longer overwrites it from stale Health)
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)  # on to the map
	assert_str(state.event_id).is_empty()


func test_a_reload_on_the_event_choice_shows_the_same_event() -> void:
	var state: RunState = _state_on_event(1)
	RunSession.current = state
	RunSession.forced_event = "fx_pay"
	var first := _spawn()
	await _frames()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT)
	var saved: String = state.to_json()
	first.queue_free()
	await _frames()
	var restored: RunState = RunState.from_json(saved)
	RunSession.current = restored
	var second := _spawn()
	var models: Array[Dictionary] = []
	second.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _frames()
	assert_str(restored.pending).is_equal(RunState.PENDING_EVENT)
	assert_str(restored.event_id).is_equal("fx_pay")
	assert_int(models.size()).is_equal(1)  # the reopened choice was announced
	assert_str(String(models[0]["title"])).is_equal("Fixture: The Toll")
	assert_int(restored.history.size()).is_equal(state.history.size())  # the event room was recorded once, not again


func _kinds_of(model: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for option: Dictionary in (model["options"] as Array):
		kinds.append(String(option["kind"]))
	return kinds


func test_the_controller_runs_an_event_into_a_paid_relic_offer_and_then_the_outcomes_after_it() -> void:
	var state: RunState = _state_on_event(1)
	RunSession.current = state
	RunSession.forced_event = "fx_paid"
	var main := _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	var max_hp: float = main.player.health.max_health
	assert_str(state.event_id).is_equal("fx_paid")
	var opened: Dictionary = controller.choose("event_choice:0")
	assert_bool(bool(opened["ok"])).is_true()
	assert_bool(bool(opened["finished"])).is_false()  # the paid relic offer is open
	assert_float(main.player.health.current_health).is_equal(max_hp)  # the lose_hp after the relic has not run
	var model: Dictionary = controller.current_choice()
	assert_str(String(model["title"])).is_equal("Take your pick")
	assert_bool(bool(model["event_offer"])).is_true()
	assert_bool(_kinds_of(model).has("relic_skip")).is_false()  # no skip: the player has paid
	assert_bool(controller.has_choice()).is_true()
	var relic_id: String = state.offer[0]
	var picked: Dictionary = controller.pick_relic(relic_id)
	assert_bool(bool(picked["ok"]) and bool(picked["finished"])).is_true()
	assert_array(state.relics).is_equal([relic_id])
	assert_object(controller.relic_manager()).is_not_null()
	assert_bool(controller.relic_manager().has_relic(relic_id)).is_true()  # live at once
	var expected: float = max_hp - float(EventEngine.hp_amount(0.1, max_hp))
	assert_float(main.player.health.current_health).is_equal(expected)  # fx_paid's lose_hp ran after the pick, on the live player
	assert_float(state.hp).is_equal(expected)
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_str(state.event_id).is_empty()
	assert_bool(state.event_queue.is_empty()).is_true()


func test_a_reload_on_a_paid_event_offer_reopens_it_with_no_skip_and_the_bill_still_to_come() -> void:
	var state: RunState = _state_on_event(1)
	RunSession.current = state
	RunSession.forced_event = "fx_paid"
	var first := _spawn()
	await _frames()
	first.run_controller.choose("event_choice:0")
	var offered: Array[String] = state.offer.duplicate()
	var saved: String = state.to_json()
	first.queue_free()
	await _frames()
	var restored: RunState = RunState.from_json(saved)
	assert_object(restored).is_not_null()
	RunSession.current = restored
	var second := _spawn()
	var models: Array[Dictionary] = []
	second.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _frames()
	assert_str(restored.pending).is_equal(RunState.PENDING_RELIC)
	assert_array(restored.offer).is_equal(offered)
	assert_int(models.size()).is_equal(1)
	assert_bool(_kinds_of(models[0]).has("relic_skip")).is_false()
	assert_str(String(models[0]["title"])).is_equal("Take your pick")
	var max_hp: float = second.player.health.max_health
	second.run_controller.pick_relic(offered[0])
	assert_float(second.player.health.current_health).is_equal(max_hp - float(EventEngine.hp_amount(0.1, max_hp)))


func test_the_event_text_in_run_json_is_validated_when_present() -> void:
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	assert_array(RunConfig.validate(config, EnemyConfig.enemy_ids(), [])).is_empty()
	var renamed: Dictionary = config.duplicate(true)
	((renamed["ui"] as Dictionary)["event"]["lines"] as Dictionary).erase("lose_hp")
	assert_bool(RunConfig.validate(renamed, EnemyConfig.enemy_ids(), []).any(func(e: String) -> bool: return e.contains("ui.event.lines.lose_hp"))).is_true()
	var wrong_format: Dictionary = config.duplicate(true)
	((wrong_format["ui"] as Dictionary)["event"]["lines"] as Dictionary)["lose_hp"] = "Lose some HP"
	assert_bool(RunConfig.validate(wrong_format, EnemyConfig.enemy_ids(), []).any(func(e: String) -> bool: return e.contains("lose_hp"))).is_true()
	var no_floor: Dictionary = config.duplicate(true)
	(no_floor["events"] as Dictionary)["min_max_hp"] = 0
	assert_bool(RunConfig.validate(no_floor, EnemyConfig.enemy_ids(), []).any(func(e: String) -> bool: return e.contains("min_max_hp"))).is_true()
	var without: Dictionary = config.duplicate(true)
	without.erase("events")
	(without["ui"] as Dictionary).erase("event")
	assert_array(RunConfig.validate(without, EnemyConfig.enemy_ids(), [])).is_empty()  # both are optional (a config without them plays with the defaults)
