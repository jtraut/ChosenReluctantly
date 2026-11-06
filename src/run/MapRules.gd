class_name MapRules
extends RefCounted
## The map's rules (MAP.md sections 3 and 4.1) as pure checks over an in-memory map and a validated data/map.json config.
## `shape_problems` looks only at the node/edge layout (the grid), `type_problems` at the node types, `path_problems` at every
## start-to-boss path by depth-first enumeration, and `check` runs all three. `relic_estimate` is the section 4.1 estimate for one
## path. The generator and the 1000-seed sweep both call these, so the rules live in one place.

const MIN_NODES_PER_ROOM := 2
const MAX_NODES_PER_ROOM := 4


## Accumulates the extremes over every path of one `evaluate` walk.
class Extremes:
	extends RefCounted
	var paths: int = 0
	var min_fights: int = 1000000
	var max_elite_like: int = 0
	var max_merchants: int = 0
	var max_rest: int = 0
	var min_rest: int = 1000000
	var best_relics: int = -1
	var worst_relics: int = 1000000


## Every problem with the map under `cfg` (empty = the map obeys every rule).
static func check(map: Dictionary, cfg: Dictionary) -> Array[String]:
	var problems: Array[String] = shape_problems(map, cfg)
	if problems.is_empty():
		problems.append_array(type_problems(map, cfg))
		problems.append_array(path_problems(map, cfg))
	return problems


## Layout rules: 2-4 nodes in each room before the boss, one boss, every node has an outgoing edge and is reachable from room 1,
## edges join neighbouring columns of neighbouring rooms, none cross, and `min_branching` of the nodes in rooms 1 to rooms-2 offer 2+ choices.
static func shape_problems(map: Dictionary, cfg: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var rooms: int = int(cfg["rooms"])
	var nodes: Array = map.get("nodes", [])
	var count_by_room: Dictionary = {}
	var room_of: Dictionary = {}
	var column_of: Dictionary = {}
	for entry: Variant in nodes:
		var n: Dictionary = entry
		var room: int = int(n["room"])
		count_by_room[room] = int(count_by_room.get(room, 0)) + 1
		room_of[int(n["id"])] = room
		column_of[int(n["id"])] = int(n["column"])
		if room < 1 or room > rooms or int(n["column"]) < 0 or int(n["column"]) >= int(cfg["columns"]):
			problems.append("node %d is outside the grid (room %d, column %d)" % [int(n["id"]), room, int(n["column"])])
	for room in range(1, rooms):
		var n: int = int(count_by_room.get(room, 0))
		if n < MIN_NODES_PER_ROOM or n > MAX_NODES_PER_ROOM:
			problems.append("room %d has %d nodes (needs %d to %d)" % [room, n, MIN_NODES_PER_ROOM, MAX_NODES_PER_ROOM])
	if int(count_by_room.get(rooms, 0)) != 1:
		problems.append("the last room must hold exactly one node (the boss), found %d" % int(count_by_room.get(rooms, 0)))
	if not problems.is_empty():
		return problems
	var next: Dictionary = MapGraph.adjacency(map)
	var has_incoming: Dictionary = {}
	for edge: Variant in (map.get("edges", []) as Array):
		var a: int = int((edge as Array)[0])
		var b: int = int((edge as Array)[1])
		has_incoming[b] = true
		if int(room_of.get(b, -1)) != int(room_of.get(a, -5)) + 1:
			problems.append("edge %d to %d does not join neighbouring rooms" % [a, b])
		elif int(room_of[b]) < rooms and absi(int(column_of[a]) - int(column_of[b])) > 1:
			problems.append("edge %d to %d jumps more than one column" % [a, b])
	if MapGraph.has_crossing(map):
		problems.append("two edges cross")
	var branching: int = 0
	var counted: int = 0
	for entry: Variant in nodes:
		var id: int = int((entry as Dictionary)["id"])
		var room: int = int(room_of[id])
		if room < rooms and (next.get(id, []) as Array).is_empty():
			problems.append("node %d (room %d) has no outgoing edge" % [id, room])
		if room > 1 and not has_incoming.has(id):
			problems.append("node %d (room %d) cannot be reached from room 1" % [id, room])
		if room <= rooms - 2:
			counted += 1
			if (next.get(id, []) as Array).size() >= 2:
				branching += 1
	if counted > 0 and float(branching) / float(counted) < float(cfg["path_rules"]["min_branching"]) - 0.000001:
		problems.append("only %d of %d nodes in rooms 1 to %d offer a choice (min_branching %s)" % [branching, counted, rooms - 2, str(cfg["path_rules"]["min_branching"])])
	return problems


## Type rules: fixed rooms hold their fixed type, every other node a type listed in map.json whose room window holds its room, and a
## `no_repeat` type never follows itself along an edge. (A weight of 0 is not checked: data may switch a type off after a map was made.)
static func type_problems(map: Dictionary, cfg: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var type_of: Dictionary = {}
	for entry: Variant in (map.get("nodes", []) as Array):
		var n: Dictionary = entry
		var type_id: String = String(n["type"])
		var room: int = int(n["room"])
		type_of[int(n["id"])] = type_id
		var fixed: Variant = (cfg["fixed"] as Dictionary).get(str(room))
		if fixed != null:
			if type_id != String(fixed):
				problems.append("node %d (room %d) is %s, but room %d is fixed to %s" % [int(n["id"]), room, type_id, room, String(fixed)])
			continue
		var entry_cfg: Variant = (cfg["types"] as Dictionary).get(type_id)
		if entry_cfg == null:
			problems.append("node %d has type %s, which map.json does not list" % [int(n["id"]), type_id])
			continue
		var window: Array = (entry_cfg as Dictionary)["rooms"]
		if room < int(window[0]) or room > int(window[1]):
			problems.append("node %d: %s is outside its rooms window [%d, %d] (room %d)" % [int(n["id"]), type_id, int(window[0]), int(window[1]), room])
	for edge: Variant in (map.get("edges", []) as Array):
		var from_type: String = String(type_of.get(int((edge as Array)[0]), ""))
		if from_type == String(type_of.get(int((edge as Array)[1]), "-")):
			var entry_cfg: Variant = (cfg["types"] as Dictionary).get(from_type)
			if entry_cfg != null and bool((entry_cfg as Dictionary).get("no_repeat", false)):
				problems.append("%s follows %s along edge %d to %d (no_repeat)" % [from_type, from_type, int((edge as Array)[0]), int((edge as Array)[1])])
	return problems


## Path rules (MAP.md section 3.3) over every path: min_fights, max_elite_like, max_merchants, min_rest (D40: a rest on every route), max_rest, the best path's relic estimate
## inside `relic_route` and the worst path's at most `ignore_route_max`.
static func path_problems(map: Dictionary, cfg: Dictionary) -> Array[String]:
	var stats: Extremes = evaluate(map, cfg)
	var rules: Dictionary = cfg["path_rules"]
	var problems: Array[String] = []
	if stats.paths == 0:
		problems.append("the map has no path from room 1 to the boss")
		return problems
	if stats.min_fights < int(rules["min_fights"]):
		problems.append("a path has only %d fights (min_fights %d)" % [stats.min_fights, int(rules["min_fights"])])
	if stats.max_elite_like > int(rules["max_elite_like"]):
		problems.append("a path has %d elite-like nodes (max_elite_like %d)" % [stats.max_elite_like, int(rules["max_elite_like"])])
	if stats.max_merchants > int(rules["max_merchants"]):
		problems.append("a path has %d merchants (max_merchants %d)" % [stats.max_merchants, int(rules["max_merchants"])])
	if rules.has("min_rest") and stats.min_rest < int(rules["min_rest"]):
		problems.append("a path has only %d rest nodes (min_rest %d)" % [stats.min_rest, int(rules["min_rest"])])
	if stats.max_rest > int(rules["max_rest"]):
		problems.append("a path has %d rest nodes (max_rest %d)" % [stats.max_rest, int(rules["max_rest"])])
	var route: Array = rules["relic_route"]
	if stats.best_relics < int(route[0]) or stats.best_relics > int(route[1]):
		problems.append("the best path's relic estimate is %d (relic_route [%d, %d])" % [stats.best_relics, int(route[0]), int(route[1])])
	if stats.worst_relics > int(rules["ignore_route_max"]):
		problems.append("the worst path's relic estimate is %d (ignore_route_max %d)" % [stats.worst_relics, int(rules["ignore_route_max"])])
	return problems


## The fewest rest nodes on any start-to-boss path, in one pass over the nodes (room by room), not a walk of every path.
static func min_rest_over_paths(map: Dictionary) -> int:
	var nodes: Array = (map.get("nodes", []) as Array).duplicate()
	nodes.sort_custom(func(a: Variant, b: Variant) -> bool: return int((a as Dictionary)["room"]) < int((b as Dictionary)["room"]))
	var preds: Dictionary = {}
	for edge: Variant in (map.get("edges", []) as Array):
		var to_id: int = int((edge as Array)[1])
		if not preds.has(to_id):
			preds[to_id] = [] as Array[int]
		(preds[to_id] as Array[int]).append(int((edge as Array)[0]))
	var fewest: Dictionary = {}  # node id -> fewest rests on any path into and including it
	var boss: int = MapGraph.boss_id(map)
	for entry: Variant in nodes:
		var id: int = int((entry as Dictionary)["id"])
		var here: int = 1 if String((entry as Dictionary)["type"]) == "rest" else 0
		var best: int = 0
		if preds.has(id):
			best = 1000000
			for from_id: int in (preds[id] as Array[int]):
				best = mini(best, int(fewest.get(from_id, 1000000)))
		fewest[id] = best + here
	return int(fewest.get(boss, 0))


## The extremes over every start-to-boss path (depth-first). Counts, not path lists, so it does not allocate per path.
static func evaluate(map: Dictionary, cfg: Dictionary) -> Extremes:
	var stats := Extremes.new()
	var type_of: Dictionary = {}
	for entry: Variant in (map.get("nodes", []) as Array):
		type_of[int((entry as Dictionary)["id"])] = String((entry as Dictionary)["type"])
	var next: Dictionary = MapGraph.adjacency(map)
	var boss: int = MapGraph.boss_id(map)
	for start: int in MapGraph.start_ids(map):
		_descend(start, boss, type_of, next, cfg["estimate"], stats, 0, 0, 0, 0, 0, 0.0)
	return stats


static func _descend(id: int, boss: int, type_of: Dictionary, next: Dictionary, estimate: Dictionary, stats: Extremes,
		fights: int, elite_like: int, merchants: int, rest: int, relics: int, gold: float) -> void:
	var type_id: String = String(type_of[id])
	if MapConfig.FIGHT_TYPES.has(type_id):
		fights += 1
	if MapConfig.ELITE_LIKE_TYPES.has(type_id):
		elite_like += 1
	if type_id == "rest":
		rest += 1
	if type_id == "merchant":
		merchants += 1
		relics += merchant_relics(gold, estimate)
	elif MapConfig.RELIC_TYPES.has(type_id):
		relics += 1
	gold += float((estimate["gold_mean"] as Dictionary).get(type_id, 0.0))
	if id == boss:
		stats.paths += 1
		stats.min_fights = mini(stats.min_fights, fights)
		stats.max_elite_like = maxi(stats.max_elite_like, elite_like)
		stats.max_merchants = maxi(stats.max_merchants, merchants)
		stats.max_rest = maxi(stats.max_rest, rest)
		stats.min_rest = mini(stats.min_rest, rest)
		stats.best_relics = maxi(stats.best_relics, relics)
		stats.worst_relics = mini(stats.worst_relics, relics)
		return
	for following: int in (next.get(id, []) as Array[int]):
		_descend(following, boss, type_of, next, estimate, stats, fights, elite_like, merchants, rest, relics, gold)


## Relics a merchant visit counts for on arrival with `gold` (MAP.md section 4.1, MAP2-A): the cheapest slots first, as many as `gold` pays
## for (`estimate.merchant_prices`: 2 normal slots at the tier 1 price, 1 shop-only slot at the tier 2 price).
static func merchant_relics(gold: float, estimate: Dictionary) -> int:
	var prices: Array = (estimate["merchant_prices"] as Array).duplicate()
	prices.sort()
	var left: float = gold
	var bought: int = 0
	for price: Variant in prices:
		if left + 0.000001 < float(price):
			break
		left -= float(price)
		bought += 1
	return bought


## The section 4.1 relic estimate for one path (a list of node ids): relic nodes count 1, a merchant counts what the expected gold
## on arrival buys. Expected gold is the mean income of the nodes before it; nothing is assumed spent.
static func relic_estimate(map: Dictionary, path: Array, cfg: Dictionary) -> int:
	var relics: int = 0
	var gold: float = 0.0
	var estimate: Dictionary = cfg["estimate"]
	for id: Variant in path:
		var type_id: String = String(MapGraph.node(map, int(id)).get("type", ""))
		if type_id == "merchant":
			relics += merchant_relics(gold, estimate)
		elif MapConfig.RELIC_TYPES.has(type_id):
			relics += 1
		gold += float((estimate["gold_mean"] as Dictionary).get(type_id, 0.0))
	return relics


## One path's counts {fights, elite_like, merchants, rest, relics}, for the print tool and tests.
static func path_stats(map: Dictionary, path: Array, cfg: Dictionary) -> Dictionary:
	var stats: Dictionary = {"fights": 0, "elite_like": 0, "merchants": 0, "rest": 0, "relics": relic_estimate(map, path, cfg)}
	for id: Variant in path:
		var type_id: String = String(MapGraph.node(map, int(id)).get("type", ""))
		if MapConfig.FIGHT_TYPES.has(type_id):
			stats["fights"] = int(stats["fights"]) + 1
		if MapConfig.ELITE_LIKE_TYPES.has(type_id):
			stats["elite_like"] = int(stats["elite_like"]) + 1
		if type_id == "merchant":
			stats["merchants"] = int(stats["merchants"]) + 1
		if type_id == "rest":
			stats["rest"] = int(stats["rest"]) + 1
	return stats
