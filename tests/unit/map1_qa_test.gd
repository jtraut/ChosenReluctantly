class_name Map1QaTest
extends GdUnitTestSuite
## qa's MAP1 review: independent property checks over the generator (own code, not MapRules or the dev's sweep, on different seeds), config
## fuzzing, validator failure paths, shipped-data pins, determinism (golden hash and across processes), node and gold flow, round trips,
## launch flags. Written without reading the dev's checkers' internals.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const SWEEP_FIRST := 5000
const SWEEP_COUNT := 1000
const FIGHTS: Array[String] = ["combat", "elite", "mini_boss", "boss"]


func before_test() -> void:
	RunSession.acts_override = 1  # MAP3-B: these tests pin the one-act run (it ends in the boss); the three-act flow is map3b_acts_test
	RunSession.clear()
	RunSession.map_override = -1
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.acts_override = 0
	RunSession.clear()
	RunSession.map_override = -1
	MapConfig.reset_cache()
	RunConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false  # GamePause.reset() forgets its flag but not the tree; a class pick left open by a test must not leak a paused tree


# ---- helpers ----

func _cfg() -> Dictionary:
	return (MapConfig.get_config() as Dictionary).duplicate(true)


func _shipped_json() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MapConfig.PATH))


## Independent checker. Returns the first problem found, or "". Uses only the raw nodes/edges lists and the config numbers.
func _check(map: Dictionary, cfg: Dictionary, run: Dictionary) -> String:
	var rooms: int = int(cfg["rooms"])
	var columns: int = int(cfg["columns"])
	var nodes: Array = map["nodes"]
	var edges: Array = map["edges"]
	var by_id: Dictionary = {}
	var per_room: Dictionary = {}
	for n: Dictionary in nodes:
		var id: int = int(n["id"])
		if by_id.has(id):
			return "duplicate id %d" % id
		by_id[id] = n
		var room: int = int(n["room"])
		var col: int = int(n["column"])
		if room < 1 or room > rooms or col < 0 or col >= columns:
			return "node %d off the grid (room %d col %d)" % [id, room, col]
		if id != (room - 1) * columns + col:
			return "node %d has the wrong id for room %d column %d" % [id, room, col]
		per_room[room] = int(per_room.get(room, 0)) + 1
		var type_id: String = String(n["type"])
		var is_fight: bool = FIGHTS.has(type_id)
		var wave: String = String(n["wave_id"])
		if is_fight != (wave != ""):
			return "node %d type %s wave '%s' (fights need a wave, others none)" % [id, type_id, wave]
		if is_fight and type_id != "boss":
			var ok_wave: bool = false
			for v: Dictionary in RunConfig.variants_for(room - 1, (run["rooms"] as Dictionary).get(type_id, [])):
				if String(v["id"]) == wave:
					ok_wave = true
			if not ok_wave:
				return "node %d wave %s not allowed for %s in room %d" % [id, wave, type_id, room]
		if n.has("chest") != (type_id == "relic_room"):
			return "node %d chest key mismatch" % id
		if type_id == "boss":
			if room != rooms:
				return "boss on room %d" % room
		else:
			var def: Variant = (cfg["types"] as Dictionary).get(type_id)
			var fixed: Variant = (cfg["fixed"] as Dictionary).get(str(room))
			if fixed != null:
				if String(fixed) != type_id:
					return "node %d room %d must be %s" % [id, room, String(fixed)]
			else:
				if def == null:
					return "node %d has type %s with no definition" % [id, type_id]
				var window: Array = (def as Dictionary)["rooms"]
				if room < int(window[0]) or room > int(window[1]):
					return "node %d %s outside window %s" % [id, type_id, str(window)]
				if float((def as Dictionary)["weight"]) <= 0.0:
					return "node %d drew a weight-0 type %s" % [id, type_id]
	if int(per_room.get(rooms, 0)) != 1:
		return "last room has %d nodes" % int(per_room.get(rooms, 0))
	for room in range(1, rooms):
		var count: int = int(per_room.get(room, 0))
		if count < 2 or count > 4:
			return "room %d has %d nodes" % [room, count]
	# edges
	var out: Dictionary = {}
	var into: Dictionary = {}
	var seen_edges: Dictionary = {}
	for e: Array in edges:
		var a: int = int(e[0])
		var b: int = int(e[1])
		if not by_id.has(a) or not by_id.has(b):
			return "edge %d>%d names a missing node" % [a, b]
		if seen_edges.has(a * 100000 + b):
			return "duplicate edge %d>%d" % [a, b]
		seen_edges[a * 100000 + b] = true
		var na: Dictionary = by_id[a]
		var nb: Dictionary = by_id[b]
		if int(nb["room"]) != int(na["room"]) + 1:
			return "edge %d>%d does not go to the next room" % [a, b]
		if String(nb["type"]) != "boss" and absi(int(nb["column"]) - int(na["column"])) > 1:
			return "edge %d>%d jumps more than one column" % [a, b]
		out[a] = int(out.get(a, 0)) + 1
		into[b] = int(into.get(b, 0)) + 1
	for i in range(edges.size()):
		for j in range(i + 1, edges.size()):
			var e1: Array = edges[i]
			var e2: Array = edges[j]
			if int((by_id[int(e1[0])] as Dictionary)["room"]) != int((by_id[int(e2[0])] as Dictionary)["room"]):
				continue
			var a1: int = int((by_id[int(e1[0])] as Dictionary)["column"])
			var b1: int = int((by_id[int(e1[1])] as Dictionary)["column"])
			var a2: int = int((by_id[int(e2[0])] as Dictionary)["column"])
			var b2: int = int((by_id[int(e2[1])] as Dictionary)["column"])
			if (a1 < a2 and b1 > b2) or (a1 > a2 and b1 < b2):
				return "edges %s and %s cross" % [str(e1), str(e2)]
	var branching: int = 0
	var counted: int = 0
	for id: int in by_id.keys():
		var n: Dictionary = by_id[id]
		var room: int = int(n["room"])
		if room < rooms:
			var degree: int = int(out.get(id, 0))
			if degree < 1 or degree > 3:
				return "node %d has %d outgoing edges" % [id, degree]
			if room == rooms - 1 and String((by_id[(edges.filter(func(x: Array) -> bool: return int(x[0]) == id)[0] as Array)[1]] as Dictionary)["type"]) != "boss":
				return "room %d node %d does not lead to the boss" % [room, id]
			if room <= rooms - 2:
				counted += 1
				if degree >= 2:
					branching += 1
		if room > 1 and int(into.get(id, 0)) < 1:
			return "node %d has no incoming edge" % id
	if float(branching) / float(counted) + 1e-9 < float((cfg["path_rules"] as Dictionary)["min_branching"]):
		return "branching %d/%d below the minimum" % [branching, counted]
	# reachability both ways (BFS)
	var forward: Dictionary = {}
	var frontier: Array[int] = []
	for id: int in by_id.keys():
		if int((by_id[id] as Dictionary)["room"]) == 1:
			frontier.append(id)
			forward[id] = true
	while not frontier.is_empty():
		var cur: int = frontier.pop_back()
		for e: Array in edges:
			if int(e[0]) == cur and not forward.has(int(e[1])):
				forward[int(e[1])] = true
				frontier.append(int(e[1]))
	if forward.size() != by_id.size():
		return "%d nodes unreachable from room 1" % (by_id.size() - forward.size())
	# paths
	var rules: Dictionary = cfg["path_rules"]
	var lo: int = int((rules["relic_route"] as Array)[0])
	var hi: int = int((rules["relic_route"] as Array)[1])
	var best: int = 0
	var worst: int = 999
	var adj: Dictionary = {}
	for e: Array in edges:
		if not adj.has(int(e[0])):
			adj[int(e[0])] = []
		(adj[int(e[0])] as Array).append(int(e[1]))
	var starts: Array = by_id.keys().filter(func(i: int) -> bool: return int((by_id[i] as Dictionary)["room"]) == 1)
	var stack: Array = []
	for s: int in starts:
		stack.append([s, 0, 0, 0, 0, 0, 1, 0.0])  # id, fights, elite, rest, merchants, relics, length, gold on arrival
	var path_count: int = 0
	while not stack.is_empty():
		var f: Array = stack.pop_back()
		var t: String = String((by_id[int(f[0])] as Dictionary)["type"])
		var fights: int = int(f[1]) + (1 if FIGHTS.has(t) else 0)
		var elite: int = int(f[2]) + (1 if (t == "elite" or t == "mini_boss") else 0)
		var rest: int = int(f[3]) + (1 if t == "rest" else 0)
		var merch: int = int(f[4]) + (1 if t == "merchant" else 0)
		var relics: int = int(f[5]) + (1 if (t == "elite" or t == "relic_room" or t == "mini_boss" or t == "curse_room" or t == "buff_room") else 0)
		if t == "merchant":
			# MAP2-B: this checker's own copy of the estimate. A merchant counts what the expected gold on arrival buys, cheapest slot first.
			var left: float = float(f[7])
			var slots: Array = (cfg["estimate"]["merchant_prices"] as Array).map(func(p: Variant) -> float: return float(p))
			slots.sort()
			for price: float in slots:
				if left + 0.000001 < price:
					break
				left -= price
				relics += 1
		var gold_here: float = float(f[7]) + float(((cfg["estimate"] as Dictionary)["gold_mean"] as Dictionary).get(t, 0.0))
		if t == "boss":
			path_count += 1
			if int(f[6]) != rooms:
				return "a path is %d rooms long" % int(f[6])
			if fights < int(rules["min_fights"]) or elite > int(rules["max_elite_like"]) or rest > int(rules["max_rest"]) or rest < int(rules["min_rest"]) or merch > int(rules["max_merchants"]):
				return "path rule broken: fights %d elite %d rest %d merchants %d" % [fights, elite, rest, merch]
			best = maxi(best, relics)
			worst = mini(worst, relics)
			continue
		for nxt: int in (adj.get(int(f[0]), []) as Array):
			if String((by_id[nxt] as Dictionary)["type"]) == t and t != "combat" and t != "boss":
				return "no_repeat broken on edge %d>%d (%s)" % [int(f[0]), nxt, t]
			stack.append([nxt, fights, elite, rest, merch, relics, int(f[6]) + 1, gold_here])
	if path_count == 0:
		return "no path reaches the boss"
	if best < lo or best > hi:
		return "best path scores %d, not in [%d, %d]" % [best, lo, hi]
	if worst > int(rules["ignore_route_max"]):
		return "worst path scores %d" % worst
	return ""


# ---- generator ----

func test_independent_sweep_of_a_thousand_other_seeds() -> void:
	var cfg: Dictionary = MapConfig.get_config()
	var run: Dictionary = RunConfig.get_config()
	var failures: Array[String] = []
	var type_count: Dictionary = {}
	var worst: int = 0
	for s in range(SWEEP_FIRST, SWEEP_FIRST + SWEEP_COUNT):
		var result: Dictionary = MapGenerator.build(s, cfg, run)
		if not bool(result["ok"]):
			failures.append("seed %d failed: %s" % [s, String(result["error"])])
			continue
		worst = maxi(worst, int(result["attempts"]))
		var problem: String = _check(result["map"], cfg, run)
		if problem != "":
			failures.append("seed %d: %s" % [s, problem])
		for n: Dictionary in result["map"]["nodes"]:
			type_count[String(n["type"])] = int(type_count.get(String(n["type"]), 0)) + 1
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 8))).is_empty()
	assert_int(worst).is_less(int(cfg["max_attempts"]))
	# weight-0 types never show up in shipped data
	for t: String in ["mini_boss", "curse_room", "buff_room"]:
		assert_int(int(type_count.get(t, 0))).is_equal(0)
	if MerchantSwitch.shipped_is_on():  # MAP2-B: with the merchant switched on it must show up; off it must not
		assert_int(int(type_count.get("merchant", 0))).is_greater(0)
	else:
		assert_int(int(type_count.get("merchant", 0))).is_equal(0)
	# every shipped type appears across the sweep (a type that never appears is dead data)
	for t: String in ["combat", "elite", "relic_room", "rest", "boss"]:
		assert_int(int(type_count.get(t, 0))).is_greater(0)
	# chest sizes all occur
	var sizes: Dictionary = {}
	for s in range(SWEEP_FIRST, SWEEP_FIRST + 200):
		for n: Dictionary in MapGenerator.generate(s)["nodes"]:
			if n.has("chest"):
				sizes[String(n["chest"])] = true
	assert_array(sizes.keys()).contains_exactly_in_any_order(["small", "medium", "large"])


func test_the_checker_catches_each_deliberate_break() -> void:
	# guards the checker: a checker that cannot fail proves nothing
	var cfg: Dictionary = MapConfig.get_config()
	var run: Dictionary = RunConfig.get_config()
	var good: Dictionary = MapGenerator.generate(7)
	assert_str(_check(good, cfg, run)).is_empty()
	var m1: Dictionary = good.duplicate(true)
	(m1["edges"] as Array).append([(m1["edges"] as Array)[0][0], 99])
	assert_str(_check(m1, cfg, run)).is_not_empty()
	var m2: Dictionary = good.duplicate(true)
	var changed: bool = false
	for n: Dictionary in m2["nodes"]:
		if not changed and String(n["type"]) == "combat" and int(n["room"]) >= 3:
			n["type"] = "elite"
			n["wave_id"] = ""
			changed = true
	assert_bool(changed).is_true()
	assert_str(_check(m2, cfg, run)).is_not_empty()
	var m3: Dictionary = good.duplicate(true)
	(m3["edges"] as Array).pop_back()
	assert_str(_check(m3, cfg, run)).is_not_empty()
	var m4: Dictionary = good.duplicate(true)
	for n: Dictionary in m4["nodes"]:
		if int(n["room"]) == 5:
			n["wave_id"] = "no_such_list"
	assert_str(_check(m4, cfg, run)).is_not_empty()


func test_golden_maps_pin_determinism_across_runs_and_versions() -> void:
	# Pins today's output for seeds 1..40 as a regression guard (not independent proof of correctness; the separate-process test below is the
	# cross-process evidence). If this changes the generator's stream changed: that breaks saved runs and every seeded baseline.
	var text: String = ""
	for s in range(1, 41):
		text += JSON.stringify(MapGenerator.generate(s), "", true) + "\n"
	var again: String = ""
	for s in range(1, 41):
		again += JSON.stringify(MapGenerator.generate(s), "", true) + "\n"
	assert_str(text).is_equal(again)
	# Two pins, one per state of the merchant switch (MAP2-B): the shipped data is either fully off or fully on (map2b_merchant_flow_test checks that).
	assert_int(text.hash()).is_equal(GOLDEN_HASH_MERCHANT_ON if MerchantSwitch.shipped_is_on() else GOLDEN_HASH)


const GOLDEN_HASH := 2713285137  # MAP2-A: min_rest 1 + rest weight 25 + max_attempts 1000 + 40 type draws per grid (was 1128919566)
const GOLDEN_HASH_MERCHANT_ON := 1726783216  # MAP2-B: the same seeds with data/merchant_on.json applied (merchant weight 8, relic_route [6, 8], estimate prices 30/30/45)


func test_a_separate_process_prints_the_same_maps() -> void:
	var exe: String = OS.get_executable_path()
	var project: String = ProjectSettings.globalize_path("res://")
	for s in [3, 11, 777]:
		var output: Array = []
		var code: int = OS.execute(exe, ["--headless", "--path", project, "-s", "res://tools/map_print.gd", "--", "--seed=%d" % s, "--acts=1"], output, true)
		assert_int(code).is_equal(0)
		var printed: String = "\n".join(output)
		var map: Dictionary = MapGenerator.generate(s)
		for line: String in MapGraph.to_text(map, int(MapConfig.get_config()["columns"])).split("\n"):
			assert_bool(printed.contains(line.strip_edges())).override_failure_message("seed %d: line '%s' not in the other process's output" % [s, line]).is_true()


func test_the_generator_survives_other_valid_configs() -> void:
	# Different shapes of data must give a map that passes the checker or fail with a message, never crash or hang.
	var base: Dictionary = _cfg()
	var run: Dictionary = RunConfig.get_config()
	var variants: Array[Dictionary] = []
	for change: Dictionary in [{"columns": 3}, {"columns": 5}, {"walks": 3}, {"walks": 6}, {"rooms": 8, "fixed": {"1": "combat", "2": "combat", "8": "boss"}}]:
		var v: Dictionary = base.duplicate(true)
		v["max_attempts"] = 60
		for key: String in change:
			v[key] = change[key]
		if change.has("rooms"):
			for t: String in (v["types"] as Dictionary):
				var w: Array = ((v["types"] as Dictionary)[t] as Dictionary)["rooms"]
				w[1] = mini(int(w[1]), 7)
				w[0] = mini(int(w[0]), int(w[1]))
			((v["path_rules"] as Dictionary)["relic_route"] as Array)[0] = 3
			((v["path_rules"] as Dictionary)["relic_route"] as Array)[1] = 6
		variants.append(v)
	var ok_count: int = 0
	for v: Dictionary in variants:
		assert_array(MapConfig.validate(v)).override_failure_message("variant invalid: %s" % str(MapConfig.validate(v))).is_empty()
		for s in range(1, 9):
			var result: Dictionary = MapGenerator.build(s, v, run)
			if bool(result["ok"]):
				ok_count += 1
				assert_str(_check(result["map"], v, run)).is_empty()
			else:
				assert_str(String(result["error"])).contains("MapGenerator")
	assert_int(ok_count).is_greater(0)


# ---- validator ----

func _inject_everywhere(node: Variant, path: String, found: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		found.append(node)
		for k: Variant in (node as Dictionary).keys():
			_inject_everywhere((node as Dictionary)[k], path + "." + str(k), found)


func test_an_unknown_key_is_rejected_in_every_object_of_the_config() -> void:
	var count: int = 0
	var probe: Array = []
	_inject_everywhere(_cfg(), "map", probe)
	for index in range(probe.size()):
		var c: Dictionary = _cfg()
		var holders: Array = []
		_inject_everywhere(c, "map", holders)
		var holder: Dictionary = holders[index]
		holder["zz_unknown"] = 1
		var errors: Array[String] = MapConfig.validate(c)
		assert_bool(not errors.is_empty()).override_failure_message("object #%d accepted an unknown key" % index).is_true()
		count += 1
	assert_int(count).is_greater(10)


func test_every_leaf_survives_hostile_values_without_a_crash_and_the_accepted_ones_still_generate() -> void:
	var run: Dictionary = RunConfig.get_config()
	var hostile: Array = [null, "x", -1, 0, 1000000000, 1.5, [], {}, true, [1], [5, 2], [0, 99]]
	var leaves: Array[Array] = []  # [path of keys]
	_leaf_paths(_cfg(), [], leaves)
	var accepted: int = 0
	var rejected: int = 0
	for p: Array in leaves:
		for h: Variant in hostile:
			var c: Dictionary = _cfg()
			var cursor: Variant = c
			for i in range(p.size() - 1):
				cursor = (cursor as Dictionary)[p[i]] if typeof(cursor) == TYPE_DICTIONARY else (cursor as Array)[int(p[i])]
			if typeof(cursor) == TYPE_DICTIONARY:
				(cursor as Dictionary)[p[p.size() - 1]] = h
			else:
				(cursor as Array)[int(p[p.size() - 1])] = h
			var errors: Array[String] = MapConfig.validate(c)
			if errors.is_empty():
				accepted += 1
				c["max_attempts"] = 20
				if p == ["types", "combat", "weight"]:
					continue  # validator accepts it, the generator then script-errors: carry-over test below (MapGenerator.gd:59)
				var result: Dictionary = MapGenerator.build(1, c, run)  # must not crash or hang
				assert_bool(result.has("ok")).is_true()
				if bool(result["ok"]):
					assert_str(_check(result["map"], c, run)).override_failure_message("accepted mutation %s=%s generated a map that breaks a rule" % [str(p), str(h)]).is_empty()
			else:
				rejected += 1
				for e: String in errors:
					assert_str(e).is_not_empty()
	assert_int(accepted + rejected).is_greater(100)


func _leaf_paths(node: Variant, prefix: Array, out: Array[Array]) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		for k: Variant in (node as Dictionary).keys():
			_leaf_paths((node as Dictionary)[k], prefix + [k], out)
	elif typeof(node) == TYPE_ARRAY:
		for i in range((node as Array).size()):
			_leaf_paths((node as Array)[i], prefix + [i], out)
	else:
		out.append(prefix)


func test_missing_keys_each_fail_with_a_message_that_names_them() -> void:
	for key: String in MapConfig.TOP_KEYS:
		var c: Dictionary = _cfg()
		c.erase(key)
		var errors: Array[String] = MapConfig.validate(c)
		assert_bool(not errors.is_empty()).override_failure_message("missing %s accepted" % key).is_true()
		assert_bool("; ".join(errors).contains(key)).override_failure_message("missing %s not named: %s" % [key, str(errors)]).is_true()


func test_bad_windows_and_fixed_rooms_are_named() -> void:
	for bad: Array in [[4, 3], [0, 5], [3, 11], ["a", 5], [3], [3, 4, 5], [3.5, 5]]:
		var c: Dictionary = _cfg()
		((c["types"] as Dictionary)["rest"] as Dictionary)["rooms"] = bad
		var errors: Array[String] = MapConfig.validate(c)
		assert_bool("; ".join(errors).contains("rest")).override_failure_message("window %s: %s" % [str(bad), str(errors)]).is_true()
	var c2: Dictionary = _cfg()
	(c2["fixed"] as Dictionary).erase("10")
	assert_bool(not MapConfig.validate(c2).is_empty()).is_true()
	var c3: Dictionary = _cfg()
	(c3["fixed"] as Dictionary)["9"] = "boss"
	assert_bool(not MapConfig.validate(c3).is_empty()).is_true()


func _write_user(name: String, text: String) -> String:
	var path: String = "user://" + name
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path


func test_a_corrupt_map_file_fails_loudly_with_no_config() -> void:
	var shipped: String = FileAccess.get_file_as_string(MapConfig.PATH)
	var cases: Dictionary = {
		"empty": "",
		"garbage": "this is not json",
		"truncated": shipped.substr(0, shipped.length() / 2),
		"array_root": "[1, 2, 3]",
		"trailing_comma": shipped.replace("\"estimate\"", "\"estimate\",\"x\"").replace("}\n}", "},\n}"),
		"wrong_type_rooms": shipped.replace("\"rooms\": 10,", "\"rooms\": \"ten\","),
		"unknown_top_key": shipped.replace("\"enabled\": true,", "\"enabled\": true, \"bogus\": 1,"),
		"enabled_string": shipped.replace("\"enabled\": true", "\"enabled\": \"yes\""),
	}
	for case_name: String in cases:
		var path: String = _write_user("qa_map_%s.json" % case_name, cases[case_name])
		var result: Dictionary = MapConfig.load_from(path)
		assert_dict(result["config"]).override_failure_message("%s loaded a config" % case_name).is_empty()
		assert_bool(not (result["problems"] as Array).is_empty()).override_failure_message("%s gave no reason" % case_name).is_true()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var missing: Dictionary = MapConfig.load_from("user://qa_map_does_not_exist.json")
	assert_dict(missing["config"]).is_empty()
	assert_bool(not (missing["problems"] as Array).is_empty()).is_true()


# ---- accepted data pins ----

func test_the_shipped_data_matches_the_accepted_changes() -> void:
	var c: Dictionary = _shipped_json()
	assert_bool(bool(c["enabled"])).is_true()
	assert_float(float((c["path_rules"] as Dictionary)["min_branching"])).is_equal(0.4)
	var merchant_on: bool = MerchantSwitch.shipped_is_on()  # MAP2-B: the data ships either fully off or fully on; both states are pinned
	assert_array(((c["path_rules"] as Dictionary)["relic_route"] as Array).map(func(v: Variant) -> int: return int(v))).is_equal([6, 8] if merchant_on else [5, 7])
	var t: Dictionary = c["types"]
	assert_int(int((t["combat"] as Dictionary)["weight"])).is_equal(40)
	assert_int(int((t["elite"] as Dictionary)["weight"])).is_equal(16)
	assert_int(int((t["relic_room"] as Dictionary)["weight"])).is_equal(14)
	assert_int(int((t["rest"] as Dictionary)["weight"])).is_equal(25)  # MAP2-A: was 10, raised so every path can hold a rest (D40)
	assert_array(((t["relic_room"] as Dictionary)["rooms"] as Array).map(func(v: Variant) -> int: return int(v))).is_equal([3, 8])
	for zero: String in ["mini_boss", "curse_room", "buff_room"]:
		assert_int(int((t[zero] as Dictionary)["weight"])).is_equal(0)
	assert_int(int((t["merchant"] as Dictionary)["weight"])).is_equal(8 if merchant_on else 0)
	var ch: Dictionary = c["chests"]
	assert_int(int((ch["small"] as Dictionary)["weight"])).is_equal(50)
	assert_int(int((ch["medium"] as Dictionary)["weight"])).is_equal(35)
	assert_int(int((ch["large"] as Dictionary)["weight"])).is_equal(15)
	assert_int(int((ch["large"] as Dictionary)["min_tier"])).is_equal(1)
	assert_int(int(c["rooms"])).is_equal(10)
	# run.json: the relic-room stopgap is gone, gold ranges as documented
	var run: Dictionary = RunConfig.get_config()
	assert_array(((run["gold"] as Dictionary)["combat"] as Array).map(func(v: Variant) -> int: return int(v))).is_equal([24, 36])
	assert_array(((run["gold"] as Dictionary)["elite"] as Array).map(func(v: Variant) -> int: return int(v))).is_equal([60, 80])
	assert_bool((run["rooms"] as Dictionary).has("relic_room")).override_failure_message("the rooms.relic_room stopgap is still in run.json").is_false()


func test_chest_tier_rows_follow_the_shipped_data() -> void:
	var run: Dictionary = RunConfig.get_config()
	var tw: Dictionary = (run["relics"] as Dictionary)["tier_weights"]
	var ch: Dictionary = MapConfig.chests()
	var small: Dictionary = RunNodes.chest_weights("small", 1, ch, tw)
	var medium: Dictionary = RunNodes.chest_weights("medium", 1, ch, tw)
	var large: Dictionary = RunNodes.chest_weights("large", 1, ch, tw)
	assert_float(float(small["tier1"])).is_equal(80.0)
	assert_float(float(small["tier2"])).is_equal(20.0)
	assert_float(float(medium["tier2"])).is_equal(70.0)
	assert_float(float(large["tier3"])).is_equal(70.0)
	assert_float(float(large["tier1"])).is_equal(5.0)  # min_tier 1: nothing zeroed
	assert_dict(RunNodes.chest_weights("huge", 1, ch, tw)).is_empty()
	# a min_tier 2 and 3 zero the lower tiers
	var strict: Dictionary = ch.duplicate(true)
	(strict["large"] as Dictionary)["min_tier"] = 3
	var row: Dictionary = RunNodes.chest_weights("large", 1, strict, tw)
	assert_float(float(row["tier1"])).is_equal(0.0)
	assert_float(float(row["tier2"])).is_equal(0.0)
	assert_float(float(row["tier3"])).is_equal(70.0)


# ---- gold ----

func test_gold_is_deterministic_in_range_order_free_and_zero_for_non_paying_types() -> void:
	var g: Dictionary = RunConfig.gold()
	for s in range(1, 60):
		for id in [0, 5, 9, 33]:
			var a: int = RunNodes.roll_gold(s, id, "combat", g)
			assert_int(a).is_equal(RunNodes.roll_gold(s, id, "combat", g))
			assert_int(a).is_between(24, 36)
			assert_int(RunNodes.roll_gold(s, id, "elite", g)).is_between(60, 80)
			for zero: String in ["boss", "rest", "relic_room", "merchant", "nonsense", ""]:
				assert_int(RunNodes.roll_gold(s, id, zero, g)).is_equal(0)
	# the spread covers the range (not a constant)
	var seen: Dictionary = {}
	for s in range(1, 200):
		seen[RunNodes.roll_gold(s, 4, "combat", g)] = true
	assert_int(seen.size()).is_greater(4)
	# bad gold data pays 0 rather than crashing
	assert_int(RunNodes.roll_gold(1, 1, "combat", {"combat": "lots"})).is_equal(0)
	assert_int(RunNodes.roll_gold(1, 1, "combat", {"combat": [5]})).is_equal(0)
	assert_int(RunNodes.roll_gold(1, 1, "combat", {})).is_equal(0)
	# negative seed and huge seed stay in range
	assert_int(RunNodes.roll_gold(-5, 1, "combat", g)).is_between(24, 36)
	assert_int(RunNodes.roll_gold(RunState.SEED_LIMIT * 3, 1, "combat", g)).is_between(24, 36)


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


## Spawns one tiny enemy room and returns the enemies (qa's own copy of the helper idea).
func _tiny_room(main: Main) -> Array[Enemy]:
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	main.enemy_spawner.configure_room(table, 1)
	main.enemy_spawner._process(1.0)
	var found: Array[Enemy] = []
	for child in main.get_children():
		if child is Enemy:
			found.append(child as Enemy)
	return found


func _kill_all(enemies: Array[Enemy]) -> void:
	for e: Enemy in enemies:
		e.health.take_damage(100000.0)


func _mains_alive() -> int:
	var n: int = 0
	for child in get_children():
		if child is Main and not child.is_queued_for_deletion():
			n += 1
	return n


func _latest_main(except_ids: Array[int]) -> Main:
	var found: Main = null
	for child in get_children():
		if child is Main and not except_ids.has(child.get_instance_id()) and not child.is_queued_for_deletion():
			found = child as Main
	return found


## Starts a map run, picks the first room-1 node, and returns the spawned room-1 Main (after its frames).
func _into_room_one(seed_value: int) -> Main:
	RunSession.map_override = 1
	RunSession.begin_new_run(seed_value)
	var start: Main = _spawn()
	var start_id: int = start.get_instance_id()
	await _frames(3)
	var picked: Dictionary = start.run_controller.pick_node(start.run_controller.reachable_nodes()[0])
	assert_bool(bool(picked["ok"])).is_true()
	await _frames(3)
	var room: Main = _latest_main([start_id])
	assert_object(room).is_not_null()
	return room


func test_a_won_fight_pays_once_and_a_reload_mid_reward_reopens_the_offer_without_paying_again() -> void:
	var room: Main = await _into_room_one(21)
	var state: RunState = RunSession.current
	var controller: RunController = room.run_controller
	var node_id: int = controller.current_node_id()
	var pays: Array[int] = []
	controller.gold_changed.connect(func(_t: int, d: int) -> void: pays.append(d))
	_kill_all(_tiny_room(room))
	await _frames(4)
	var expected: int = RunNodes.roll_gold(state.seed_value, node_id, "combat", RunConfig.gold())
	assert_int(state.gold).is_equal(expected)
	assert_array(pays).is_equal([expected])
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
	# reload: save to JSON, restore, build a fresh scene on the restored state
	var offer_before: Array[String] = state.offer.duplicate()
	var restored: RunState = RunState.from_json(state.to_json())
	assert_bool(restored.equals(state)).is_true()
	RunSession.current = restored
	var reloaded: Main = _spawn()
	var again: Array[int] = []
	reloaded.run_controller.gold_changed.connect(func(_t: int, d: int) -> void: again.append(d))
	await _frames(4)
	assert_int(restored.gold).is_equal(expected)
	assert_array(again).is_empty()
	assert_str(restored.pending).is_equal(RunState.PENDING_REWARD)
	assert_array(restored.offer).is_equal(offer_before)
	assert_int(reloaded.enemy_spawner.alive_count()).is_equal(0)  # the cleared room is not fought again


func test_pick_spam_on_the_map_moves_exactly_one_room_and_a_pick_cannot_skip_a_pending_reward() -> void:
	var room: Main = await _into_room_one(31)
	var state: RunState = RunSession.current
	var controller: RunController = room.run_controller
	var here: int = controller.current_node_id()
	_kill_all(_tiny_room(room))
	await _frames(4)
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
	var next_ids: Array[int] = MapGraph.next_ids(state.map, here)
	# a node pick while a reward is open must be refused and change nothing
	var snapshot: String = state.to_json()
	for id in next_ids:
		assert_bool(bool(controller.pick_node(id)["ok"])).override_failure_message("a node pick skipped the open reward").is_false()
	assert_str(state.to_json()).is_equal(snapshot)
	assert_array(state.path).has_size(1)
	# take the reward, then spam picks (the same node, then the others)
	controller.choose("skip")
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	var old_id: int = room.get_instance_id()
	var accepted: int = 0
	for spam_round in range(3):
		for id in next_ids:
			if bool(controller.pick_node(id)["ok"]):
				accepted += 1
	assert_int(accepted).is_equal(1)
	await _frames(4)
	assert_array(state.path).has_size(2)
	assert_int(state.room_index).is_equal(1)
	var next: Main = _latest_main([old_id])
	assert_object(next).is_not_null()
	assert_int(next.run_controller.room_number()).is_equal(2)
	# a pick on the fresh room's controller before it has any choice open is refused too
	assert_bool(bool(next.run_controller.pick_node(MapGraph.next_ids(state.map, state.path[1])[0])["ok"])).is_false()


func test_dying_in_the_frame_of_the_last_kill_on_a_map_is_a_loss_and_pays_no_gold() -> void:
	for player_first in [true, false]:
		RunSession.clear()
		var room: Main = await _into_room_one(42)
		var state: RunState = RunSession.current
		var enemies: Array[Enemy] = _tiny_room(room)
		var lost: Array[int] = []
		var cleared: Array[int] = []
		room.run_controller.run_lost.connect(func() -> void: lost.append(1))
		room.run_controller.room_cleared.connect(func(_s: Dictionary) -> void: cleared.append(1))
		if player_first:
			room.player.health.take_damage(100000.0)
			_kill_all(enemies)
		else:
			_kill_all(enemies)
			room.player.health.take_damage(100000.0)
		await _frames(4)
		assert_array(lost).override_failure_message("player_first=%s: no loss" % str(player_first)).has_size(1)
		assert_array(cleared).is_empty()
		assert_str(state.outcome).is_equal("lost")
		assert_int(state.gold).override_failure_message("a lost room paid gold").is_equal(0)


func test_nine_map_rooms_of_picks_reach_the_boss_leave_no_scenes_behind_and_pay_gold() -> void:
	var room: Main = await _into_room_one(77)
	var state: RunState = RunSession.current
	var seen_ids: Array[int] = []
	for step in range(9):
		var controller: RunController = room.run_controller
		var type_id: String = controller.room_type()
		if type_id != "relic_room" and type_id != "rest":
			_kill_all(_tiny_room(room))
		await _frames(4)
		# whatever the node opened (reward, relic offer, rest menu), take the cheap way out
		var guard: int = 0
		while state.has_pending() and state.pending != RunState.PENDING_NODE and guard < 4:
			if state.pending == RunState.PENDING_REWARD:
				var picked_card: bool = false
				for o: Dictionary in (controller.current_choice()["options"] as Array):
					if String(o.get("kind", "")) == "card" and bool(o.get("enabled", false)):
						controller.choose(String(o["id"]))
						picked_card = true
						break
				if not picked_card:
					controller.choose("skip")
			elif state.pending == RunState.PENDING_RELIC:
				controller.skip_relic_offer()
			else:
				var options: Array = controller.current_choice()["options"]
				for o: Dictionary in options:
					if bool(o.get("enabled", false)):
						controller.choose(String(o["id"]))
						break
			guard += 1
			await _frames(2)
		assert_str(state.pending).override_failure_message("step %d (%s) did not reach the node pick; pending %s" % [step, type_id, state.pending]).is_equal(RunState.PENDING_NODE)
		var old: int = room.get_instance_id()
		seen_ids.append(old)
		var pick: int = controller.reachable_nodes()[0]
		assert_bool(bool(controller.pick_node(pick)["ok"])).is_true()
		await _frames(4)
		room = _latest_main(seen_ids)
		assert_object(room).is_not_null()
		assert_int(room.run_controller.room_number()).is_equal(step + 2)
	assert_str(room.run_controller.room_type()).is_equal("boss")
	assert_int(state.gold).is_greater(0)
	var alive: int = 0
	for id in seen_ids:
		if is_instance_valid(instance_from_id(id)) and not (instance_from_id(id) as Node).is_queued_for_deletion():
			alive += 1
	assert_int(alive).override_failure_message("%d old rooms are still alive" % alive).is_less_equal(1)


func test_run_room_pays_nothing_for_skipped_rooms_and_follows_the_first_route() -> void:
	RunSession.map_override = 1
	for target in [1, 5, 9, 10]:
		var state: RunState = RunSession.begin_new_run(40 + target)
		var route: Array[int] = MapGraph.first_route(state.map)
		state.jump_to_room(target - 1)
		assert_int(state.gold).is_equal(0)
		assert_int(state.room_index).is_equal(target - 1)
		assert_array(state.path).is_equal(route.slice(0, target))
		assert_bool(RunNodes.consistent(state)).is_true()
		assert_bool(RunState.from_json(state.to_json()).equals(state)).is_true()
	# past the end clamps to the boss
	var s2: RunState = RunSession.begin_new_run(3)
	s2.jump_to_room(99)
	assert_int(s2.room_index).is_equal(9)
	assert_int(int(RunNodes.current_node(s2)["room"])).is_equal(10)
	assert_str(String(RunNodes.current_node(s2)["type"])).is_equal("boss")


# ---- node handling and round trips ----

func _ctx() -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools("rogue"))


func test_every_step_of_a_full_walk_round_trips_including_the_open_pick() -> void:
	RunSession.map_override = 1
	for seed_value in [1, 2, 3, 17, 4242]:
		var state: RunState = RunSession.begin_new_run(seed_value)
		var ctx: Dictionary = {"nodes": RunNodes.shipped_context()}
		var steps: int = 0
		while steps < 12:
			# at an open pick
			assert_str(state.pending).is_equal(RunState.PENDING_NODE)
			var back: RunState = RunState.from_json(state.to_json())
			assert_bool(back.equals(state)).override_failure_message("seed %d step %d: round trip differs at the open pick" % [seed_value, steps]).is_true()
			assert_str(back.pending).is_equal(RunState.PENDING_NODE)
			var ids: Array[int] = RunNodes.reachable_ids(back)
			assert_array(ids).is_equal(RunNodes.reachable_ids(state))
			assert_bool(not ids.is_empty()).is_true()
			var options: Array[Dictionary] = RunNodes.options(state, ctx)
			assert_int(options.size()).is_equal(ids.size())
			# a hostile option id changes nothing
			for bad in ["node:-1", "node:abc", "node:", "card:1", "node:99999", ""]:
				var before: String = state.to_json()
				assert_bool(bool(RunNodes.apply(state, bad, ctx)["ok"])).is_false()
				assert_str(state.to_json()).is_equal(before)
			# an id from another room is refused too
			var wrong: int = MapGraph.boss_id(state.map)
			if not ids.has(wrong):
				assert_bool(bool(RunNodes.apply(state, "node:%d" % wrong, ctx)["ok"])).is_false()
			var pick: int = ids[steps % ids.size()]
			assert_bool(bool(RunNodes.apply(state, "node:%d" % pick, ctx)["ok"])).is_true()
			assert_bool(RunNodes.consistent(state)).is_true()
			assert_int(state.room_index).is_equal(steps)
			steps += 1
			if String(RunNodes.current_node(state)["type"]) == "boss":
				break
			RunNodes.open(state)
		assert_int(steps).is_equal(10)
		assert_bool(RunNodes.reachable_ids(state).is_empty()).is_true()  # the boss leads nowhere


func test_a_damaged_save_drops_the_map_loudly_not_the_run() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(9)
	var route: Array[int] = MapGraph.first_route(state.map)
	state.path = route.slice(0, 4)
	state.room_index = 3
	state.pending = RunState.PENDING_NONE
	var good: Dictionary = state.to_dict()
	assert_bool(RunState.from_dict(good).equals(state)).is_true()
	var damage: Array[Callable] = [
		func(d: Dictionary) -> void: d["room_index"] = 7,
		func(d: Dictionary) -> void: d["path"] = [route[0], route[0]],
		func(d: Dictionary) -> void: d["path"] = [99999],
		func(d: Dictionary) -> void: d["path"] = "nope",
		func(d: Dictionary) -> void: d["map"] = {"nodes": [], "edges": []},
		func(d: Dictionary) -> void: d["map"] = "garbage",
		func(d: Dictionary) -> void: ((d["map"] as Dictionary)["nodes"] as Array).pop_back(),
		func(d: Dictionary) -> void: d["gold"] = -50,
		func(d: Dictionary) -> void: d["gold"] = "lots",
	]
	for i in range(damage.size()):
		var d: Dictionary = (JSON.parse_string(JSON.stringify(good)) as Dictionary)
		damage[i].call(d)
		var loaded: RunState = RunState.from_dict(d)
		assert_object(loaded).override_failure_message("damage %d crashed the load" % i).is_not_null()
		assert_bool(RunNodes.consistent(loaded)).override_failure_message("damage %d loaded an inconsistent map run" % i).is_true()
		if i <= 6:  # a damaged map or path: the map is dropped, the run goes on as a straight run
			assert_bool(loaded.map.is_empty()).override_failure_message("damage %d kept a map" % i).is_true()
			assert_array(loaded.path).override_failure_message("damage %d kept a path" % i).is_empty()
			assert_bool(loaded.pending == RunState.PENDING_NODE).override_failure_message("damage %d left a node pick with no map (soft lock)" % i).is_false()
		else:  # a bad number only: the map stays and the run loads
			assert_bool(loaded.map.is_empty()).is_false()


func test_carryover_a_negative_gold_in_a_save_is_refused() -> void:
	var state: RunState = RunSession.begin_new_run(9)
	var d: Dictionary = (JSON.parse_string(JSON.stringify(state.to_dict())) as Dictionary)
	d["gold"] = -50
	assert_int(RunState.from_dict(d).gold).is_greater_equal(0)


func test_carryover_a_damaged_map_with_an_open_node_pick_does_not_leave_a_straight_run_holding_the_pick() -> void:
	RunSession.map_override = 1
	var fresh: RunState = RunSession.begin_new_run(9)
	assert_str(fresh.pending).is_equal(RunState.PENDING_NODE)
	var cases: Dictionary = {
		"map {}": func(d: Dictionary) -> void: d["map"] = {},
		"map erased": func(d: Dictionary) -> void: d.erase("map"),
		"map array": func(d: Dictionary) -> void: d["map"] = [1, 2],
		"map nodes string": func(d: Dictionary) -> void: d["map"] = {"nodes": "x", "edges": []},
		"map edge to nowhere": func(d: Dictionary) -> void: ((d["map"] as Dictionary)["edges"] as Array).append([0, 12345]),
		"path [1]": func(d: Dictionary) -> void: d["path"] = [1],
		"room_index 4": func(d: Dictionary) -> void: d["room_index"] = 4,
	}
	var bad: Array[String] = []
	for name: String in cases:
		var dd: Dictionary = (JSON.parse_string(JSON.stringify(fresh.to_dict())) as Dictionary)
		(cases[name] as Callable).call(dd)
		var loaded: RunState = RunState.from_dict(dd)
		if loaded == null:
			continue
		if loaded.map.is_empty() and loaded.pending == RunState.PENDING_NODE:
			bad.append(name)
	assert_array(bad).override_failure_message("straight run left holding a node pick for: %s" % str(bad)).is_empty()


func test_carryover_a_config_the_validator_accepts_but_cannot_fill_fails_with_a_message_not_a_script_error() -> void:
	var c: Dictionary = _cfg()
	((c["types"] as Dictionary)["combat"] as Dictionary)["weight"] = 0
	assert_array(MapConfig.validate(c)).is_empty()  # the validator lets it through
	var result: Dictionary = MapGenerator.build(1, c, RunConfig.get_config())
	assert_bool(bool(result.get("ok", true))).is_false()
	assert_str(String(result.get("error", ""))).contains("MapGenerator")


# ---- launch flags ----

func test_map_flags_refuse_every_odd_combination() -> void:
	var ok_cases: Dictionary = {"": -1, "--map": 1, "--no-map": 0}
	for k: String in ok_cases:
		var args: PackedStringArray = PackedStringArray([k]) if k != "" else PackedStringArray()
		var r: Dictionary = MapLaunch.resolve(args)
		assert_array(r["errors"]).is_empty()
		assert_int(int(r["override"])).is_equal(int(ok_cases[k]))
	for bad: Array in [["--map", "--no-map"], ["--map", "--map"], ["--no-map", "--no-map"], ["--map=1"], ["--map=false"], ["--no-map=1"], ["--map", "--no-map", "--map"], ["--map=", "--no-map"]]:
		var r2: Dictionary = MapLaunch.resolve(PackedStringArray(bad))
		assert_bool(not (r2["errors"] as Array).is_empty()).override_failure_message("%s was accepted" % str(bad)).is_true()
		assert_int(int(r2["override"])).is_equal(-1)
	# unrelated args are ignored, and look-alikes are not mistaken for the flags
	var r3: Dictionary = MapLaunch.resolve(PackedStringArray(["--map-seed=3", "--mapper", "--run-seed=1"]))
	assert_array(r3["errors"]).is_empty()
	assert_int(int(r3["override"])).is_equal(-1)


func test_the_override_decides_new_runs_whatever_the_data_says() -> void:
	RunSession.map_override = 0
	var off: RunState = RunSession.begin_new_run(5)
	assert_bool(off.map.is_empty()).is_true()
	assert_str(off.pending).is_equal(RunState.PENDING_NONE)
	RunSession.map_override = 1
	var on: RunState = RunSession.begin_new_run(5)
	assert_bool(on.map.is_empty()).is_false()
	assert_str(on.pending).is_equal(RunState.PENDING_NODE)
	RunSession.map_override = -1
	assert_bool(RunSession.begin_new_run(5).map.is_empty()).is_false()  # the shipped switch is on


func test_the_straight_run_is_unchanged_by_the_map_code() -> void:
	# the straight run for a seed must be the same as RunGenerator alone says, with no map, gold or path in its save
	RunSession.map_override = 0
	var state: RunState = RunSession.begin_new_run(42)
	var rooms: Array[Dictionary] = RunGenerator.generate(42, RunConfig.get_config())
	assert_int(rooms.size()).is_equal(10)
	assert_bool(state.map.is_empty()).is_true()
	assert_array(state.path).is_empty()
	assert_int(state.gold).is_equal(0)
	assert_bool(RunNodes.consistent(state)).is_true()
	var d: Dictionary = state.to_dict()
	assert_bool(RunState.from_dict(d).equals(state)).is_true()
	assert_str(String(rooms[9]["type"])).is_equal("boss")
