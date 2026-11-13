class_name Map4dTest
extends GdUnitTestSuite
## MAP4 sitting D: the shipped content (8 events, 3 curse cards, 6 event-only and 4 sacrifice relics), the three-act event weight, the relic route's event
## tie-break and the multi_act.types override. BUILD_DEPTH 13.3 to 13.7.

const EVENT_IDS: Array[String] = ["broken_vending_machine", "complacency_trap", "exit_interview", "internal_audit", "loyalty_pledge", "performance_altar",
		"supply_closet", "sympathetic_coworker"]
const CURSES: Dictionary = {"curse_property_damage": "attack_single", "curse_reply_all_storm": "attack_aoe", "curse_mandatory_training": "utility"}
const EVENT_ONLY: Array[String] = ["gravediggers_spade", "unpaid_intern", "golden_handcuffs", "off_the_books", "bleeding_edge", "open_plan_office"]
const SACRIFICE: Dictionary = {"hostile_takeover": 2, "golden_parachute": 1, "asset_stripping": 1, "brain_drain": 1}


func before_test() -> void:
	EventDatabase.load_all()
	CardDatabase.load_all()
	RelicDatabase.load_all()
	MapConfig.reset_cache()


func _collect(outcomes: Array, into: Array[String]) -> void:
	for outcome: Variant in outcomes:
		var entry: Dictionary = outcome
		into.append(String(entry["type"]))
		if String(entry["type"]) == "chance":
			_collect(entry["win"] as Array, into)
			_collect(entry["lose"] as Array, into)


# --- events ----------------------------------------------------------------------------------------

func test_the_eight_events_are_shipped_valid_and_as_written() -> void:
	assert_array(EventDatabase.problems()).is_empty()
	var ids: Array[String] = EventDatabase.ids()
	ids.sort()
	assert_array(ids).is_equal(EVENT_IDS)
	assert_float(float(EventDatabase.get_event("loyalty_pledge")["weight"])).is_equal(0.5)
	for id: String in EVENT_IDS:
		if id != "loyalty_pledge":
			assert_bool((EventDatabase.get_event(id) as Dictionary).has("weight")).is_false()  # the default weight 1
	assert_array(EventDatabase.get_event("supply_closet")["acts"]).is_equal([2.0, 3.0])
	assert_array(EventDatabase.get_event("internal_audit")["acts"]).is_equal([2.0, 3.0])
	for id: String in ["exit_interview", "broken_vending_machine", "performance_altar", "complacency_trap", "sympathetic_coworker", "loyalty_pledge"]:
		assert_array(EventDatabase.get_event(id)["acts"]).is_equal([1.0, 2.0, 3.0])


func test_every_event_has_a_free_choice_and_every_outcome_and_requirement_is_used() -> void:
	var outcome_types: Array[String] = []
	var requirement_types: Array[String] = []
	for id: String in EventDatabase.ids():
		var free: bool = false
		for choice: Variant in (EventDatabase.get_event(id)["choices"] as Array):
			var entry: Dictionary = choice
			if not entry.has("requires"):
				free = true
			else:
				requirement_types.append(String((entry["requires"] as Dictionary).keys()[0]))
			_collect(entry["outcomes"] as Array, outcome_types)
		assert_bool(free).override_failure_message("%s has no choice without a requirement" % id).is_true()
	for outcome: String in EventSchema.OUTCOMES:
		assert_bool(outcome_types.has(outcome)).override_failure_message("no shipped event uses the outcome %s" % outcome).is_true()
	for requirement: String in EventSchema.REQUIREMENTS:
		assert_bool(requirement_types.has(requirement)).override_failure_message("no shipped event uses the requirement %s" % requirement).is_true()


func test_the_event_numbers_match_the_design() -> void:
	var exit: Dictionary = EventDatabase.get_event("exit_interview")
	assert_float(float(exit["choices"][0]["outcomes"][0]["fraction"])).is_equal(0.2)
	assert_int(int(exit["choices"][1]["outcomes"][2]["amount"])).is_equal(40)
	assert_str(String(exit["choices"][1]["outcomes"][1]["tier"])).is_equal("next_act")
	var vending: Dictionary = EventDatabase.get_event("broken_vending_machine")
	assert_int(int(vending["choices"][0]["requires"]["gold_at_least"])).is_equal(40)
	assert_float(float(vending["choices"][0]["outcomes"][1]["p"])).is_equal(0.5)
	assert_float(float(vending["choices"][1]["outcomes"][0]["fraction"])).is_equal(0.1)
	var closet: Dictionary = EventDatabase.get_event("supply_closet")
	assert_int(int(closet["choices"][0]["outcomes"][0]["tier"])).is_equal(3)
	assert_bool(bool(closet["choices"][0]["outcomes"][0]["skip"])).is_false()
	assert_float(float(closet["choices"][1]["outcomes"][1]["fraction"])).is_equal(1.0)
	var trap: Dictionary = EventDatabase.get_event("complacency_trap")
	assert_int((trap["choices"] as Array).size()).is_equal(2)  # no leave: the second choice is free
	assert_float(float(trap["choices"][0]["outcomes"][1]["value"])).is_equal(-0.2)
	assert_float(float(trap["choices"][1]["outcomes"][0]["value"])).is_equal(0.05)
	assert_int(int(EventDatabase.get_event("loyalty_pledge")["choices"][0]["outcomes"][0]["amount"])).is_equal(50)
	assert_float(float(EventDatabase.get_event("sympathetic_coworker")["choices"][2]["outcomes"][0]["fraction"])).is_equal(0.25)
	assert_int(int(EventDatabase.get_event("internal_audit")["choices"][1]["outcomes"][0]["amount"])).is_equal(30)


# --- curses ----------------------------------------------------------------------------------------

func test_the_three_curses_are_shipped_with_their_fixed_slots() -> void:
	for id: String in CURSES.keys():
		var card: Dictionary = CardDatabase.get_card(id)
		assert_bool(CardSchema.is_curse(card)).override_failure_message(id).is_true()
		assert_str(String(card["slot_type"])).is_equal(String(CURSES[id]))
		assert_str(String(card["pool"])).is_equal("neutral")
	assert_array(CardDatabase.get_card("curse_property_damage")["effects"]).is_empty()
	assert_float(float(CardDatabase.get_card("curse_property_damage")["cooldown_modifier"])).is_equal(2.0)
	var storm: Dictionary = (CardDatabase.get_card("curse_reply_all_storm")["effects"] as Array)[0]["params"]
	assert_float(float(storm["value"])).is_equal(-0.3)
	assert_float(float(storm["duration"])).is_equal(3.0)
	var module: Dictionary = (CardDatabase.get_card("curse_mandatory_training")["effects"] as Array)[0]["params"]
	assert_str(String(module["stat"])).is_equal("slot_cooldown.movement")
	assert_float(float(module["value"])).is_equal(3.0)
	assert_float(float(module["duration"])).is_equal(8.0)


func test_no_curse_is_in_a_pool_filled_deck_or_a_card_offer_pool() -> void:
	for character_id: String in ["rogue", "wizard"]:
		for id: String in RunConfig.cards_in_pools(CharacterDatabase.pools(character_id)):
			assert_bool(CURSES.has(id)).override_failure_message("%s is in %s's pool list" % [id, character_id]).is_false()


# --- relics ----------------------------------------------------------------------------------------

func test_the_event_only_and_sacrifice_relics_are_shipped_as_written() -> void:
	assert_array(RelicDatabase.problems()).is_empty()
	for id: String in EVENT_ONLY:
		var relic: Dictionary = RelicDatabase.get_relic(id)
		assert_array(relic["sources"]).override_failure_message(id).is_equal(["event"])
		assert_bool(relic.has("sacrifice_cost")).is_false()
	assert_str(String(RelicDatabase.get_relic("bleeding_edge")["pool"])).is_equal("rogue")
	assert_str(String(RelicDatabase.get_relic("open_plan_office")["pool"])).is_equal("wizard")
	assert_str(String(RelicDatabase.get_relic("off_the_books")["rarity"])).is_equal("tier3")
	assert_str(String(RelicDatabase.get_relic("unpaid_intern")["rarity"])).is_equal("tier1")
	for id: String in SACRIFICE.keys():
		var relic: Dictionary = RelicDatabase.get_relic(id)
		assert_int(int(relic["sacrifice_cost"])).override_failure_message(id).is_equal(int(SACRIFICE[id]))
		assert_str(String(relic["rarity"])).is_equal("tier3")
		assert_array(relic["sources"]).is_equal(["elite", "relic_room", "merchant"])
	assert_int((RelicDatabase.get_relic("golden_parachute")["modifiers"] as Array).size()).is_equal(5)  # every slot's cooldown, one modifier each


func test_no_new_relic_triggers_on_room_events() -> void:
	var ids: Array[String] = EVENT_ONLY.duplicate()
	for sacrifice_id: String in SACRIFICE.keys():
		ids.append(sacrifice_id)
	for id: String in ids:
		for trigger: Variant in (RelicDatabase.get_relic(id)["triggers"] as Array):
			var event: String = String((trigger as Dictionary)["event"])
			assert_bool(["room_started", "room_cleared"].has(event)).override_failure_message("%s triggers on %s (an event fight re-fires room_started)" % [id, event]).is_false()


func test_the_gravediggers_spade_switches_the_dig_on() -> void:
	var state := RunState.new()
	state.relics.append("gravediggers_spade")
	assert_bool(RunChoices.dig_enabled(state, RunChoices.shipped_context(["neutral"]))).is_true()


# --- the map ---------------------------------------------------------------------------------------

func test_the_event_weight_is_for_the_three_act_run_only() -> void:
	var base: Dictionary = MapConfig.get_config()
	assert_array(MapConfig.validate(base)).is_empty()
	assert_float(float(base["types"]["event"]["weight"])).is_equal(0.0)
	assert_float(float(MapConfig.for_act(base, 1, 1)["types"]["event"]["weight"])).is_equal(0.0)
	for act_number in range(1, 4):
		assert_float(float(MapConfig.for_act(base, act_number, 3)["types"]["event"]["weight"])).is_equal(28.0)
	assert_float(float(base["types"]["event"]["weight"])).is_equal(0.0)  # for_act copies: the file's value is untouched


func test_multi_act_types_are_validated() -> void:
	for bad: Variant in [5, {"event": 3}, {"nope": {"weight": 1}}, {"event": {"weight": -1}}, {"event": {"weight": "x"}}, {"event": {"weight": 1, "rooms": [1, 2]}}]:
		var cfg: Dictionary = MapConfig.get_config().duplicate(true)
		(cfg["multi_act"] as Dictionary)["types"] = bad
		assert_array(MapConfig.validate(cfg)).override_failure_message(str(bad)).is_not_empty()


func test_three_act_maps_hold_events_on_every_act_and_pass_the_rules() -> void:
	var base: Dictionary = MapConfig.get_config()
	var with_events: int = 0
	for act_number in range(1, 4):
		for seed_value in range(1, 41):
			var built: Dictionary = MapGenerator.build(seed_value, base, {}, act_number, 3)
			assert_bool(bool(built["ok"])).override_failure_message("seed %d act %d: %s" % [seed_value, act_number, str(built["error"])]).is_true()
			assert_array(MapRules.check(built["map"], MapConfig.for_act(base, act_number, 3))).is_empty()
			for entry: Dictionary in ((built["map"] as Dictionary)["nodes"] as Array):
				if String(entry["type"]) == "event":
					with_events += 1
					break
	assert_int(with_events).is_greater(60)  # most of the 120 act maps


# --- the relic route's tie-break -------------------------------------------------------------------

func test_the_relic_route_takes_the_event_path_when_the_relic_estimate_ties() -> void:
	# two paths, 0 -> 1 -> {2 combat | 3 event} -> 4: the same relic estimate, so the event path wins; the first path wins without it
	var cfg: Dictionary = MapConfig.get_config()
	var map: Dictionary = {"nodes": [
		{"id": 0, "room": 1, "column": 0, "type": "combat", "wave_id": ""},
		{"id": 1, "room": 2, "column": 0, "type": "combat", "wave_id": ""},
		{"id": 2, "room": 3, "column": 0, "type": "combat", "wave_id": ""},
		{"id": 3, "room": 3, "column": 1, "type": "event", "wave_id": ""},
		{"id": 4, "room": 4, "column": 0, "type": "boss", "wave_id": ""}],
		"edges": [[0, 1], [1, 2], [1, 3], [2, 4], [3, 4]]}
	assert_array(RouteBot.plan(map, "relic", cfg, 1)).is_equal([0, 1, 3, 4])
	assert_array(RouteBot.plan(map, "first", cfg, 1)).is_equal([0, 1, 2, 4])
	map["nodes"][3]["type"] = "combat"
	assert_array(RouteBot.plan(map, "relic", cfg, 1)).is_equal([0, 1, 2, 4])  # no event: the first of equal paths, as before
	map["nodes"][2]["type"] = "relic_room"
	assert_array(RouteBot.plan(map, "relic", cfg, 1)).is_equal([0, 1, 2, 4])  # a relic stage still beats an event
	map["nodes"][3]["type"] = "event"
	assert_array(RouteBot.plan(map, "relic", cfg, 1)).is_equal([0, 1, 2, 4])
