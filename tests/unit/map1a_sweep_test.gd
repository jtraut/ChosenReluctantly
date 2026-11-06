class_name Map1aSweepTest
extends GdUnitTestSuite
## MAP1-A item 5: the 1000-seed sweep. The shipped data must give a valid map for every seed, every rule must hold on every path
## (counted here by this test's own code, not by MapRules), no two edges may cross, every node must be reachable from room 1 and
## reach the boss, and the same seed must give the same map twice. Runtime is reported by tools/map_print.gd --sweep=1000.

const SEEDS := 1000


func test_thousand_seeds_obey_every_rule() -> void:
	var cfg: Dictionary = MapConfig.get_config()
	var rules: Dictionary = cfg["path_rules"]
	var estimate: Dictionary = cfg["estimate"]
	var failures: Array[String] = []
	var worst_attempts: int = 0
	var route: Array = rules["relic_route"]
	for seed_value in range(1, SEEDS + 1):
		var result: Dictionary = MapGenerator.build(seed_value, cfg)
		if not bool(result["ok"]):
			failures.append("seed %d: %s" % [seed_value, String(result["error"])])
			continue
		worst_attempts = maxi(worst_attempts, int(result["attempts"]))
		var map: Dictionary = result["map"]
		var problem: String = _check_map(map, cfg, rules, estimate, route)
		if not problem.is_empty():
			failures.append("seed %d: %s" % [seed_value, problem])
	assert_array(failures).override_failure_message("sweep failures:\n" + "\n".join(failures.slice(0, 10))).is_empty()
	assert_int(worst_attempts).override_failure_message("worst case %d of %d attempts leaves too little headroom" % [worst_attempts, int(cfg["max_attempts"])]).is_less(floori(float(cfg["max_attempts"]) * 0.8))


func _check_map(map: Dictionary, cfg: Dictionary, rules: Dictionary, estimate: Dictionary, route: Array) -> String:
	var nodes: Array = map["nodes"]
	var rooms: int = int(cfg["rooms"])
	var by_id: Dictionary = {}
	var per_room: Dictionary = {}
	for node: Dictionary in nodes:
		by_id[int(node["id"])] = node
		per_room[int(node["room"])] = int(per_room.get(int(node["room"]), 0)) + 1
		var type_id: String = String(node["type"])
		var room: int = int(node["room"])
		var fixed: Variant = (cfg["fixed"] as Dictionary).get(str(room))
		if fixed != null:
			if type_id != String(fixed):
				return "room %d should be %s, is %s" % [room, str(fixed), type_id]
		else:
			var window: Array = cfg["types"][type_id]["rooms"]
			if room < int(window[0]) or room > int(window[1]):
				return "%s on room %d is outside its window" % [type_id, room]
			if float(cfg["types"][type_id]["weight"]) <= 0.0:
				return "%s has weight 0 but was placed" % type_id
	for room in range(1, rooms):
		if int(per_room.get(room, 0)) < 2 or int(per_room.get(room, 0)) > 4:
			return "room %d has %d nodes" % [room, int(per_room.get(room, 0))]
	if int(per_room.get(rooms, 0)) != 1:
		return "the last room does not hold exactly one node"
	# Edges: neighbouring rooms, no crossings, no_repeat.
	var edges: Array = map["edges"]
	var out_degree: Dictionary = {}
	var into: Dictionary = {}
	for edge: Array in edges:
		var a: Dictionary = by_id[int(edge[0])]
		var b: Dictionary = by_id[int(edge[1])]
		if int(b["room"]) != int(a["room"]) + 1:
			return "edge skips a room"
		out_degree[int(edge[0])] = int(out_degree.get(int(edge[0]), 0)) + 1
		into[int(edge[1])] = true
		if String(a["type"]) == String(b["type"]) and bool((cfg["types"] as Dictionary).get(String(a["type"]), {}).get("no_repeat", false)):
			return "%s repeats along an edge" % String(a["type"])
	for i in range(edges.size()):
		for j in range(i + 1, edges.size()):
			var a1: Dictionary = by_id[int(edges[i][0])]
			var a2: Dictionary = by_id[int(edges[j][0])]
			if int(a1["room"]) != int(a2["room"]):
				continue
			var c1: int = int(a1["column"])
			var d1: int = int((by_id[int(edges[i][1])] as Dictionary)["column"])
			var c2: int = int(a2["column"])
			var d2: int = int((by_id[int(edges[j][1])] as Dictionary)["column"])
			if (c1 < c2 and d1 > d2) or (c1 > c2 and d1 < d2):
				return "edges cross"
	# Reachability both ways.
	for node: Dictionary in nodes:
		var id: int = int(node["id"])
		if int(node["room"]) < rooms and not out_degree.has(id):
			return "node %d has no outgoing edge" % id
		if int(node["room"]) > 1 and not into.has(id):
			return "node %d has no incoming edge" % id
	var reach: Dictionary = {}
	var frontier: Array[int] = []
	for node: Dictionary in nodes:
		if int(node["room"]) == 1:
			frontier.append(int(node["id"]))
			reach[int(node["id"])] = true
	while not frontier.is_empty():
		var current: int = frontier.pop_back()
		for edge: Array in edges:
			if int(edge[0]) == current and not reach.has(int(edge[1])):
				reach[int(edge[1])] = true
				frontier.append(int(edge[1]))
	if reach.size() != nodes.size():
		return "only %d of %d nodes are reachable from room 1" % [reach.size(), nodes.size()]
	# Branching: nodes in rooms 1..rooms-2 with 2+ choices.
	var branching: int = 0
	var counted: int = 0
	for node: Dictionary in nodes:
		if int(node["room"]) <= rooms - 2:
			counted += 1
			if int(out_degree.get(int(node["id"]), 0)) >= 2:
				branching += 1
	if float(branching) < float(rules["min_branching"]) * float(counted) - 0.000001:
		return "branching %d of %d" % [branching, counted]
	# Every path, counted here.
	var paths: Array[Array] = MapGraph.all_paths(map)
	if paths.is_empty():
		return "no paths"
	var best: int = -1
	var worst: int = 1000
	for path: Array in paths:
		if path.size() != rooms:
			return "a path has %d rooms" % path.size()
		var fights: int = 0
		var elite_like: int = 0
		var merchants: int = 0
		var rest: int = 0
		var relics: int = 0
		var gold: float = 0.0
		for id: Variant in path:
			var type_id: String = String((by_id[int(id)] as Dictionary)["type"])
			if type_id in ["combat", "elite", "mini_boss", "boss"]:
				fights += 1
			if type_id in ["elite", "mini_boss"]:
				elite_like += 1
			if type_id == "rest":
				rest += 1
			if type_id == "merchant":
				merchants += 1
				var spare: float = gold
				for price: float in [60.0, 60.0, 90.0]:  # the estimate's merchant_prices, cheapest first (written out so this checker stays independent)
					if spare >= price:
						spare -= price
						relics += 1
			elif type_id in ["elite", "relic_room", "mini_boss", "curse_room", "buff_room"]:
				relics += 1
			gold += float((estimate["gold_mean"] as Dictionary).get(type_id, 0.0))
		if fights < int(rules["min_fights"]):
			return "a path has %d fights" % fights
		if elite_like > int(rules["max_elite_like"]):
			return "a path has %d elite-like nodes" % elite_like
		if merchants > int(rules["max_merchants"]):
			return "a path has %d merchants" % merchants
		if rest < int(rules["min_rest"]):
			return "a path has %d rests (min_rest %d)" % [rest, int(rules["min_rest"])]
		if rest > int(rules["max_rest"]):
			return "a path has %d rests" % rest
		best = maxi(best, relics)
		worst = mini(worst, relics)
	if best < int(route[0]) or best > int(route[1]):
		return "best path estimate %d outside %s" % [best, str(route)]
	if worst > int(rules["ignore_route_max"]):
		return "worst path estimate %d above %d" % [worst, int(rules["ignore_route_max"])]
	return ""


func test_the_sweep_is_deterministic() -> void:
	for seed_value in range(1, 101):
		var a: Dictionary = MapGenerator.build(seed_value)
		var b: Dictionary = MapGenerator.build(seed_value)
		assert_str(JSON.stringify(a)).override_failure_message("seed %d differs between two runs" % seed_value).is_equal(JSON.stringify(b))


func test_the_rules_module_agrees_with_the_independent_check_on_a_sample() -> void:
	var cfg: Dictionary = MapConfig.get_config()
	for seed_value in range(1, 51):
		assert_array(MapRules.check(MapGenerator.generate(seed_value), cfg)).override_failure_message("seed %d" % seed_value).is_empty()
