class_name Bd2QaTest
extends GdUnitTestSuite
## qa's independent checks for BD2 (relics): a property run of the whole relic choice flow at low caps, relic-room placement
## over thousands of seeds, validator mutation tests on the shipped relics, and RunState round-trip fuzz. These are written
## against BUILD_DEPTH 4 and the brief, not against the dev tests.

const BOSS_FIXTURE := "res://tests/fixtures/relics_valid/test_boss.json"


func before_test() -> void:
	RunSession.clear()
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.clear()
	RunConfig.reset_cache()
	RelicDatabase.load_all()


func _ctx(cap: int, character: String = "rogue", with_boss_fixture: bool = false) -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools(character))
	(ctx["relics"] as Dictionary)["enabled"] = true
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	if with_boss_fixture:
		var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOSS_FIXTURE))
		(ctx["relics"]["catalog"] as Array).append(boss)
		(ctx["relics"]["by_id"] as Dictionary)["test_boss"] = boss
	return ctx


# --- the relic choice flow as a property run -----------------------------------------------------

## Plays the elite/relic-room choice with random decisions (take, skip, give up which, cancel) over many seeds and caps and
## checks the invariants after every step: never more than the cap, no duplicates, owned and given-up disjoint, an offer
## never holds an owned or given-up relic, a boss relic is never given up, and the state survives a dict round trip.
func test_the_relic_choice_flow_keeps_its_invariants_at_low_caps_over_many_seeds() -> void:
	var failures: Array[String] = []
	var steps: int = 0
	var swaps: int = 0
	var cancels: int = 0
	var skips: int = 0
	var fallbacks: int = 0
	var refusals: int = 0
	for cap: int in [1, 2, 3]:
		for character: String in ["rogue", "wizard"]:
			var ctx: Dictionary = _ctx(cap, character, true)
			for seed_value in range(1, 121):
				var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck(character), 3, character)
				state.add_relic("test_boss")  # a boss relic that can never be given up
				var chooser := RandomNumberGenerator.new()
				chooser.seed = seed_value * 31 + cap
				for room in range(1, 9):
					state.room_index = room
					var room_type: String = "elite" if room % 2 == 0 else "relic_room"
					var pending: String = RunRelics.open_for_room(state, room_type, false, ctx)
					if pending != RunState.PENDING_RELIC:
						fallbacks += 1
						if pending != RunState.PENDING_REWARD:
							failures.append("seed %d cap %d room %d: a source with nothing to offer must give a card offer, got '%s'" % [seed_value, cap, room, pending])
						RunChoices.close(state)
						continue
					for relic_id: String in state.offer:
						if state.relics.has(relic_id) or state.relics_given_up.has(relic_id):
							failures.append("seed %d cap %d room %d offered %s which is owned or given up" % [seed_value, cap, room, relic_id])
					var guard: int = 0
					while state.pending == RunState.PENDING_RELIC or state.pending == RunState.PENDING_RELIC_SWAP:
						guard += 1
						if guard >= 20:
							failures.append("choice never closes (seed %d cap %d)" % [seed_value, cap])
							break
						var options: Array[Dictionary] = RunRelics.options(state, ctx)
						var pick: Dictionary = options[chooser.randi_range(0, options.size() - 1)]
						var owned_before: Array[String] = state.relics.duplicate()
						var given_before: Array[String] = state.relics_given_up.duplicate()
						var pending_before: String = state.pending
						var result: Dictionary = RunRelics.apply(state, String(pick["id"]), ctx)
						steps += 1
						var where: String = "seed %d cap %d room %d" % [seed_value, cap, room]
						if not bool(result["ok"]):
							# Allowed only for taking a relic at the cap when nothing can be given up (only the boss relic is held).
							var refused_ok: bool = String(pick["kind"]) == RunRelics.OPTION_RELIC and RunRelics.needs_swap(state, ctx) and RunRelics.giveable_ids(state, ctx).is_empty()
							if not refused_ok or state.pending != pending_before or state.relics != owned_before or state.relics_given_up != given_before:
								failures.append("%s: refused pick '%s' (%s) without the 'nothing to give up' case or changed state" % [where, pick["id"], result.get("reason", "")])
							refusals += 1
							if refusals % 3 == 0:
								# The player can still skip: take the skip so the loop ends.
								RunRelics.apply(state, RunRelics.OPTION_SKIP, ctx)
							continue
						match String(result["kind"]):
							"relic_swap":
								swaps += 1
								if String(result["gave_up"]) == "test_boss" or not state.relics_given_up.has(String(result["gave_up"])) or state.relics.has(String(result["gave_up"])):
									failures.append("%s: bad swap %s" % [where, result])
							"relic_cancel":
								cancels += 1
								if state.relics != owned_before:
									failures.append("%s: cancel changed the relics" % where)
							"relic_skip":
								skips += 1
								if state.relics != owned_before:
									failures.append("%s: skip changed the relics" % where)
						if state.relics.size() > maxi(cap, 1):
							failures.append("%s: %d relics" % [where, state.relics.size()])
						var seen: Dictionary = {}
						for relic_id: String in state.relics:
							if seen.has(relic_id):
								failures.append("%s: duplicate %s" % [where, relic_id])
							seen[relic_id] = true
							if state.relics_given_up.has(relic_id):
								failures.append("%s: %s is both owned and given up" % [where, relic_id])
						if not state.relics.has("test_boss"):
							failures.append("%s: the boss relic was lost" % where)
						var copy: RunState = RunState.from_dict(JSON.parse_string(state.to_json()))
						if copy == null or not state.equals(copy):
							failures.append("%s: round trip changed the state (pending %s)" % [where, state.pending])
	assert_array(failures.slice(0, 10)).override_failure_message("%d invariant failures" % failures.size()).is_empty()
	print("[bd2 qa] relic flow property run: steps=%d swaps=%d cancels=%d skips=%d refusals=%d fallbacks=%d" % [steps, swaps, cancels, skips, refusals, fallbacks])
	assert_int(steps).is_greater(1000)
	assert_int(swaps).is_greater(0)
	assert_int(cancels).is_greater(0)
	assert_int(skips).is_greater(0)
	assert_int(fallbacks).is_greater(0)  # the pool runs dry at caps 2 and 3: the offer falls back to cards


func test_a_cap_of_one_holding_only_a_boss_relic_cannot_start_a_swap_and_says_why() -> void:
	var ctx: Dictionary = _ctx(1, "rogue", true)
	var state := RunState.new_run(3, CharacterDatabase.starting_deck("rogue"), 3)
	state.add_relic("test_boss")
	state.pending = RunState.PENDING_RELIC
	state.offer = ["pyre_insurance"] as Array[String]
	var result: Dictionary = RunRelics.apply(state, "relic:pyre_insurance", ctx)
	assert_bool(bool(result["ok"])).is_false()
	assert_str(String(result["reason"])).is_not_empty()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_array(state.relics).is_equal(["test_boss"] as Array[String])


# --- relic room placement ------------------------------------------------------------------------

func test_relic_room_placement_over_3000_seeds_obeys_the_window_and_spacing() -> void:
	var config: Dictionary = RunConfig.get_config()
	var window: Dictionary = (config["relics"] as Dictionary)["relic_room"]
	assert_int(int(window["first"])).is_equal(2)  # on-screen room 3
	assert_int(int(window["last"])).is_equal(8)  # on-screen room 9
	var at: Dictionary = {}
	for seed_value in range(1, 3001):
		var rooms: Array[Dictionary] = RunGenerator.generate(seed_value, config)
		assert_int(rooms.size()).is_equal(10)
		assert_str(String(rooms[0]["type"])).is_equal("combat")
		assert_str(String(rooms[9]["type"])).is_equal("boss")
		var counts: Dictionary = {}
		for room: Dictionary in rooms:
			counts[room["type"]] = int(counts.get(room["type"], 0)) + 1
		assert_int(int(counts.get("relic_room", 0))).override_failure_message("seed %d" % seed_value).is_equal(1)
		assert_int(int(counts.get("combat", 0))).is_equal(6)
		assert_int(int(counts.get("elite", 0))).is_equal(1)
		assert_int(int(counts.get("rest", 0))).is_equal(1)
		for i in range(10):
			if String(rooms[i]["type"]) != "relic_room":
				continue
			at[i] = int(at.get(i, 0)) + 1
			assert_int(i).is_between(2, 8)
			for neighbour in [i - 1, i + 1]:
				var neighbour_type: String = String(rooms[neighbour]["type"])
				assert_bool(neighbour_type == "rest" or neighbour_type == "elite").override_failure_message("seed %d: relic room %d beside %s" % [seed_value, i + 1, neighbour_type]).is_false()
			assert_str(String(rooms[i]["wave_id"])).is_empty()
		# determinism
		if seed_value % 500 == 0:
			assert_array(RunGenerator.generate(seed_value, config)).is_equal(rooms)
	print("[bd2 qa] relic room 0-based index (on-screen room = index + 1) -> seeds out of 3000: ", at)
	assert_int(at.size()).is_greater(3)  # it is not stuck on one or two rooms


func test_with_relics_disabled_the_run_has_no_relic_room_and_the_original_composition() -> void:
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	(config["relics"] as Dictionary)["enabled"] = false
	for seed_value in range(1, 400):
		var rooms: Array[Dictionary] = RunGenerator.generate(seed_value, config)
		var counts: Dictionary = {}
		for room: Dictionary in rooms:
			counts[room["type"]] = int(counts.get(room["type"], 0)) + 1
		assert_dict(counts).is_equal({"combat": 7, "elite": 1, "rest": 1, "boss": 1})


# --- validator mutation tests ---------------------------------------------------------------------

const REQUIRED_KEYS: Array[String] = ["id", "name", "pool", "rarity", "sources", "rule_text", "flavor_text"]


func test_each_shipped_relic_fails_validation_loudly_when_a_required_key_goes_missing() -> void:
	for relic_id in RelicDatabase.ids():
		var original: Dictionary = RelicDatabase.get_relic(relic_id)
		assert_array(RelicSchema.validate(original, relic_id)).is_empty()
		for key in REQUIRED_KEYS:
			var broken: Dictionary = original.duplicate(true)
			broken.erase(key)
			var problems: Array[String] = RelicSchema.validate(broken, relic_id)
			assert_array(problems).override_failure_message("%s without '%s' validated" % [relic_id, key]).is_not_empty()
			assert_bool(" ".join(problems).contains(key)).override_failure_message("%s without '%s': message does not name it: %s" % [relic_id, key, problems]).is_true()


func test_garbage_values_in_any_top_level_key_never_crash_and_mostly_fail() -> void:
	var garbage: Array = [null, 7, -1, 1.5e30, true, "", "zz_unknown", [], {}, [1, 2], {"a": 1}, "x\ny"]
	var accepted: Array[String] = []
	for relic_id in RelicDatabase.ids():
		var original: Dictionary = RelicDatabase.get_relic(relic_id)
		for key: String in RelicSchema.TOP_KEYS:
			for value: Variant in garbage:
				if typeof(value) == TYPE_STRING and ["name", "rule_text", "flavor_text"].has(key):
					continue  # any string is legal free text
				var broken: Dictionary = original.duplicate(true)
				broken[key] = value
				var problems: Array[String] = RelicSchema.validate(broken, relic_id)  # must not throw
				if problems.is_empty():
					accepted.append("%s.%s=%s" % [relic_id, key, str(value)])
	print("[bd2 qa] garbage accepted by the relic validator: ", accepted)
	# Allowed: an empty list where the other list or an optional key still makes the relic legal.
	for entry in accepted:
		var parts: PackedStringArray = entry.split(".", true, 1)
		var key_and_value: String = parts[1]
		assert_bool(key_and_value.begins_with("keywords=[]") or key_and_value.begins_with("modifiers=[]") or key_and_value.begins_with("triggers=[]")).override_failure_message("validator accepted garbage: " + entry).is_true()


func test_reserved_sources_and_sacrifice_cost_validate_as_the_brief_says() -> void:
	var original: Dictionary = RelicDatabase.get_relic("pyre_insurance")
	for source in ["starter", "event", "altar"]:
		var relic: Dictionary = original.duplicate(true)
		relic["sources"] = [source]
		assert_array(RelicSchema.validate(relic, "pyre_insurance")).override_failure_message(source).is_empty()
	for cost: Variant in [1, 2]:
		var relic: Dictionary = original.duplicate(true)
		relic["sacrifice_cost"] = cost
		assert_array(RelicSchema.validate(relic, "pyre_insurance")).is_empty()
	for cost: Variant in [0, 3, -1, 1.5, "2", null, true]:
		var relic: Dictionary = original.duplicate(true)
		relic["sacrifice_cost"] = cost
		assert_array(RelicSchema.validate(relic, "pyre_insurance")).override_failure_message("sacrifice_cost=%s accepted" % str(cost)).is_not_empty()
	var bad_source: Dictionary = original.duplicate(true)
	bad_source["sources"] = ["shop"]
	assert_array(RelicSchema.validate(bad_source, "pyre_insurance")).is_not_empty()
	var boss_with_elite: Dictionary = original.duplicate(true)
	boss_with_elite["rarity"] = "boss"
	assert_array(RelicSchema.validate(boss_with_elite, "pyre_insurance")).is_not_empty()  # boss tier needs exactly mini_boss


# --- RunState fuzz ------------------------------------------------------------------------------

func test_run_state_from_dict_survives_wrongly_typed_relic_fields() -> void:
	var base: Dictionary = RunState.new_run(9, CharacterDatabase.starting_deck("rogue"), 3).to_dict()
	var garbage: Array = [null, 7, "pyre_insurance", {}, {"a": 1}, [1, 2, null], [["x"]], ["nope_not_a_relic"], ["pyre_insurance", "pyre_insurance"], -1.5, true]
	var keys: Array = []
	for key: Variant in (RunState.new_run(9, CharacterDatabase.starting_deck("rogue"), 3).to_dict() as Dictionary).keys():
		if str(key).contains("relic") or str(key) in ["pending", "offer"]:
			keys.append(str(key))
	assert_array(keys).is_not_empty()
	for key: String in keys:
		for value: Variant in garbage:
			# Known and already on the roadmap (3d item 6a): from_dict crashes on `String(entry)` when an `offer` entry is null, an
			# array or an object (RunState.gd line 151, shared with the card reward offer). Not skipped for the other keys.
			if key == "offer" and typeof(value) == TYPE_ARRAY and (value as Array).any(func(x: Variant) -> bool: return typeof(x) == TYPE_ARRAY or typeof(x) == TYPE_DICTIONARY or typeof(x) == TYPE_NIL):
				continue
			var data: Dictionary = base.duplicate(true)
			data[key] = value
			var state: RunState = RunState.from_dict(data)
			if state == null:
				continue  # a refusal is allowed; a crash is not
			var seen: Dictionary = {}
			for relic_id: String in state.relics:
				assert_bool(seen.has(relic_id)).override_failure_message("%s=%s left a duplicate" % [key, str(value)]).is_false()
				seen[relic_id] = true
			if state.pending == RunState.PENDING_RELIC or state.pending == RunState.PENDING_RELIC_SWAP:
				assert_bool(state.has_relic_choice()).is_true()
			# And it can be saved again.
			assert_that(state.to_dict()).is_not_null()
