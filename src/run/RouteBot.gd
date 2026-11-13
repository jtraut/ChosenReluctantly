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
			return _best(map, func(path: Array) -> Array[int]:
				var events: int = 0  # MAP4-D: among equal relic estimates, a relic route takes the path with more events (E1-E4 can pay a relic; the estimate counts an event as 0)
				for id: Variant in path:
					if String(MapGraph.node(map, int(id)).get("type", "")) == "event":
						events += 1
				return [MapRules.relic_estimate(map, path, cfg), events] as Array[int])
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


## The bot's answer to an event choice (MAP4-B1, BUILD_DEPTH 13.1). Pure over the choice model's options (each carries `outcome_types`, `has_requires` and `enabled`),
## the route policy and the HP fraction, and it draws no random numbers.
##   relic   the first available choice with a `gain_relic` while HP is at least `EVENT_RELIC_MIN_HP` (50%), otherwise a choice with no cost.
##   safe    a choice with no `lose_hp`, `lose_max_hp`, `gain_curse` or `start_fight`.
##   first   the first available choice. `random` (not in 13.1) plays like `first`, and so does no policy at all.
## A choice with no cost can always be found because the no-`requires` choice exists; if that choice has a cost, the bot takes it. "" when nothing can be taken.
const EVENT_RELIC_MIN_HP := 0.5
const EVENT_COSTS: Array[String] = ["lose_hp", "lose_max_hp", "lose_gold", "gain_curse", "start_fight", "sacrifice_relic"]
const EVENT_SAFE_BLOCKS: Array[String] = ["lose_hp", "lose_max_hp", "gain_curse", "start_fight"]


static func event_choice(options: Array, policy: String, hp_fraction: float) -> String:
	var available: Array[Dictionary] = []
	for option: Variant in options:
		if bool((option as Dictionary).get("enabled", false)):
			available.append(option as Dictionary)
	if available.is_empty():
		return ""
	match policy:
		"relic":
			if hp_fraction >= EVENT_RELIC_MIN_HP:
				for option: Dictionary in available:
					if (option.get("outcome_types", []) as Array).has("gain_relic"):
						return String(option["id"])
			return _event_without(available, EVENT_COSTS)
		"safe":
			return _event_without(available, EVENT_SAFE_BLOCKS)
	return String(available[0]["id"])


## The bot's pick for an event's give-up step (`event_sacrifice`): the lowest-tier relic on offer, the first of equal tiers (so it gives up what hurts least). `options` are the
## model's options; "" when none can be taken. Pure, no random draws.
static func sacrifice_choice(options: Array) -> String:
	var best: String = ""
	var best_tier: int = 1 << 30
	for option: Variant in options:
		var entry: Dictionary = option
		if not bool(entry.get("enabled", false)):
			continue
		var tier: int = EventEngine.tier_of({"rarity": String(entry.get("tier", ""))})
		if best == "" or tier < best_tier:
			best = String(entry["id"])
			best_tier = tier
	return best


## The bot's pick for any removal list (an event's `remove_card` / `remove_curse` step, the rest list, the merchant's list): a curse first, otherwise the card with spare copies,
## otherwise the first card it may remove. `options` are the model's options of kind "remove" (enabled ones only); "" when none can be taken. Pure, no random draws.
static func removal_choice(options: Array) -> String:
	var spare: String = ""
	var any: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) != "remove" or not bool(entry.get("enabled", false)):
			continue
		if bool(entry.get("curse", false)):
			return String(entry["id"])
		if any == "":
			any = String(entry["id"])
		if spare == "" and int(entry.get("count", 0)) > 1:
			spare = String(entry["id"])
	return spare if spare != "" else any


## The first available choice whose outcomes hold none of `blocked`; else the choice with no `requires`; else the first available one.
static func _event_without(available: Array[Dictionary], blocked: Array[String]) -> String:
	for option: Dictionary in available:
		var clean: bool = true
		for type_id: Variant in (option.get("outcome_types", []) as Array):
			if blocked.has(String(type_id)):
				clean = false
		if clean:
			return String(option["id"])
	for option: Dictionary in available:
		if not bool(option.get("has_requires", false)):
			return String(option["id"])
	return String(available[0]["id"])


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
