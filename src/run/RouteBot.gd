class_name RouteBot
extends RefCounted
## Route policies for the run sim (MAP1-B, MAP.md section 8): a bot picks its whole route through a map up front. Pure over a map, the map config
## and a seed, so the policies are testable without a scene.
##
##   first   the lowest column at every step (the baseline for hashes and `--run-room=N`): MapGraph.first_route.
##   relic   the path with the highest MapRules.relic_estimate (ties go to the lowest columns).
##   safe    the path with the fewest elite-like nodes, then the most rest nodes (ties go to the lowest columns).
##   random  a seeded random choice at every step, starting from a random room-1 node.
##
## "Ties go to the lowest columns" means the first of the paths in MapGraph.all_paths order, which lists lowest columns first.

const POLICIES: Array[String] = ["first", "relic", "safe", "random"]


static func is_policy(name: String) -> bool:
	return POLICIES.has(name)


## The route (node ids, room 1 to the boss) the policy takes through `map`. `seed_value` only matters for "random". [] when the map has no route.
static func plan(map: Dictionary, policy: String, cfg: Dictionary, seed_value: int = 0) -> Array[int]:
	match policy:
		"first":
			return MapGraph.first_route(map)
		"relic":
			return _best(map, func(path: Array) -> Array[int]: return [MapRules.relic_estimate(map, path, cfg)] as Array[int])
		"safe":
			return _best(map, func(path: Array) -> Array[int]:
				var elite_like: int = 0
				var rest: int = 0
				for id: Variant in path:
					var type_id: String = String(MapGraph.node(map, int(id)).get("type", ""))
					if MapConfig.ELITE_LIKE_TYPES.has(type_id):
						elite_like += 1
					elif type_id == "rest":
						rest += 1
				return [-elite_like, rest] as Array[int])
		"random":
			return _random(map, seed_value)
	push_error("RouteBot: unknown route policy '%s' (valid: %s)" % [policy, ", ".join(POLICIES)])
	return [] as Array[int]


## The path whose score (a list compared from the first entry) is highest; the first of equal paths wins.
static func _best(map: Dictionary, score_of: Callable) -> Array[int]:
	var best: Array[int] = []
	var best_score: Array[int] = []
	for path: Array in MapGraph.all_paths(map):
		var score: Array[int] = score_of.call(path)
		if best.is_empty() or _greater(score, best_score):
			best_score = score
			best = []
			for id: Variant in path:
				best.append(int(id))
	return best


static func _greater(a: Array[int], b: Array[int]) -> bool:
	for i in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


static func _random(map: Dictionary, seed_value: int) -> Array[int]:
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value * 40503 + 0x2B7) & RunState.SEED_LIMIT
	var route: Array[int] = []
	var starts: Array[int] = MapGraph.start_ids(map)
	if starts.is_empty():
		return route
	var next: Dictionary = MapGraph.adjacency(map)
	var boss: int = MapGraph.boss_id(map)
	var id: int = starts[rng.randi_range(0, starts.size() - 1)]
	route.append(id)
	while id != boss:
		var options: Array[int] = next.get(id, [] as Array[int])
		if options.is_empty():
			break
		id = options[rng.randi_range(0, options.size() - 1)]
		route.append(id)
	return route


## What a route is worth reporting: {fights, elites, relic_nodes, rest, chests: [sizes in order]}. Counts the boss as a fight.
static func summary(map: Dictionary, route: Array[int]) -> Dictionary:
	var fights: int = 0
	var elites: int = 0
	var relic_nodes: int = 0
	var rest: int = 0
	var chests: Array[String] = []
	for id: int in route:
		var node: Dictionary = MapGraph.node(map, id)
		var type_id: String = String(node.get("type", ""))
		if MapConfig.FIGHT_TYPES.has(type_id):
			fights += 1
		if MapConfig.ELITE_LIKE_TYPES.has(type_id):
			elites += 1
		if type_id == "relic_room":
			relic_nodes += 1
			chests.append(RunNodes.chest_of(node))
		if type_id == "rest":
			rest += 1
	return {"fights": fights, "elites": elites, "relic_nodes": relic_nodes, "rest": rest, "chests": chests}
