class_name MapGenerator
extends RefCounted
## Builds a run's branching map from the run seed (MAP.md section 3). Pure and deterministic: the same seed, map config
## (data/map.json) and run config (data/run.json, for the wave lists) always give the same map.
##
## 1. Grid walks: `walks` random walks from room 1 to the room before the boss; every step goes to the same or a neighbouring column and
##    never to one whose edge would cross an existing edge between the same two rooms. The union of the walks is the grid, and every
##    last-grid-room node leads to the boss. The first two walks start in different columns.
## 2. Shape rules on the grid (2-4 nodes a room, `min_branching`, ...). A bad grid is redrawn at once and costs no attempt (new types cannot fix it).
## 3. Types: `fixed` rooms first, then a weighted pick per node inside each type's room window, a `no_repeat` type never repeating along an edge.
## 4. Path rules on every path (MapRules). A failed draw redraws the types; after 10 failed type draws the grid is redrawn too.
##    The one rng keeps running, so the result stays deterministic. After `max_attempts` it gives up with a loud error and no map.
## 5. Fight nodes get a `wave_id` from the lists that allow their room, avoiding the wave of the fight(s) just before them along the
##    edges (looking through rooms with no fight) when another fits. This runs once, after the types are final.
##
## Node ids are `(room - 1) * columns + column`; the boss sits in the middle column (`columns / 2`).

const TYPE_DRAWS_PER_GRID := 10
## A grid that breaks a shape rule is redrawn at once without spending an attempt (no types or paths are involved, so it is cheap).
## Plain random walks meet the shape rules only some of the time; this bounds the redraws so unreachable data still fails loudly.
const MAX_GRID_DRAWS := 5000
const SEED_MIX := 40503
const SEED_SALT := 0x3AB5
const CHEST_SEED_MIX := 69069
const CHEST_SEED_SALT := 0x7C4E5


## The map for `seed_value`, or {} (after a push_error) when no valid map turned up in `max_attempts`.
## `cfg` defaults to data/map.json and `run_config` to data/run.json.
static func generate(seed_value: int, cfg: Dictionary = {}, run_config: Dictionary = {}) -> Dictionary:
	var result: Dictionary = build(seed_value, cfg, run_config)
	if not bool(result["ok"]):
		push_error(String(result["error"]))
		return {}
	return result["map"]


## Like `generate` but never pushes an error: {ok, map, attempts, error}. `attempts` counts type draws (the unit `max_attempts` limits).
static func build(seed_value: int, cfg: Dictionary = {}, run_config: Dictionary = {}) -> Dictionary:
	var config: Dictionary = cfg if not cfg.is_empty() else MapConfig.get_config()
	var run: Dictionary = run_config if not run_config.is_empty() else RunConfig.get_config()
	if config.is_empty():
		return {"ok": false, "map": {}, "attempts": 0, "error": "MapGenerator: the map config is missing or invalid: " + "; ".join(MapConfig.load_problems())}
	var rng := RandomNumberGenerator.new()
	rng.seed = ((seed_value & RunState.SEED_LIMIT) * SEED_MIX + SEED_SALT) & RunState.SEED_LIMIT
	var max_attempts: int = int(config["max_attempts"])
	var attempts: int = 0
	var grid: Dictionary = {}
	var type_draws: int = 0
	var last_problem: String = ""
	while attempts < max_attempts:
		if grid.is_empty():
			grid = _draw_valid_grid(rng, config)
			if grid.is_empty():
				return {"ok": false, "map": {}, "attempts": attempts, "error": "MapGenerator: no grid met the shape rules in %d walks-draws for seed %d (columns, walks and min_branching in data/map.json may be unreachable together)" % [MAX_GRID_DRAWS, seed_value]}
			type_draws = 0
		attempts += 1
		var map: Dictionary = _assign_types(grid, rng, config)
		var problems: Array[String] = MapRules.path_problems(map, config) if not map.is_empty() else ["a node had no type to draw"] as Array[String]
		if problems.is_empty():
			_assign_waves(map, rng, run)
			_assign_chests(map, seed_value, config)
			return {"ok": true, "map": map, "attempts": attempts, "error": ""}
		last_problem = problems[0]
		type_draws += 1
		if type_draws >= TYPE_DRAWS_PER_GRID:
			grid = {}
	return {"ok": false, "map": {}, "attempts": attempts, "error": "MapGenerator: no valid map for seed %d in %d attempts (last problem: %s)" % [seed_value, max_attempts, last_problem]}


## The node id for a grid cell.
static func node_id(room: int, column: int, columns: int) -> int:
	return (room - 1) * columns + column


static func boss_column(columns: int) -> int:
	return floori(columns / 2.0)


# ---- 1. grid ----

## The next grid that meets the shape rules, or {} after MAX_GRID_DRAWS tries.
static func _draw_valid_grid(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	for _draw in range(MAX_GRID_DRAWS):
		var grid: Dictionary = _draw_grid(rng, cfg)
		if not grid.is_empty() and MapRules.shape_problems(grid, cfg).is_empty():
			return grid
	return {}


## The walks' union as a map with empty types, or {} when a walk found no free step.
static func _draw_grid(rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var rooms: int = int(cfg["rooms"])
	var columns: int = int(cfg["columns"])
	var last_grid_room: int = rooms - 1
	var cells: Dictionary = {}  # id -> [room, column]
	var edge_keys: Dictionary = {}  # "from,to" -> true
	var edges_by_room: Dictionary = {}  # room -> Array of [from_column, to_column]
	var first_start: int = -1
	for walk in range(int(cfg["walks"])):
		var column: int = rng.randi_range(0, columns - 1)
		if walk == 1:
			# The second walk starts in a different column: draw among the others.
			column = rng.randi_range(0, columns - 2)
			if column >= first_start:
				column += 1
		if walk == 0:
			first_start = column
		cells[node_id(1, column, columns)] = [1, column]
		for room in range(1, last_grid_room):
			var options: Array[int] = []
			for step in [-1, 0, 1]:
				var target: int = column + int(step)
				if target < 0 or target >= columns:
					continue
				var crosses: bool = false
				for existing: Variant in (edges_by_room.get(room, []) as Array):
					if MapGraph.edges_cross(int((existing as Array)[0]), int((existing as Array)[1]), column, target):
						crosses = true
						break
				if not crosses:
					options.append(target)
			if options.is_empty():
				return {}
			var chosen: int = options[rng.randi_range(0, options.size() - 1)]
			var from_id: int = node_id(room, column, columns)
			var to_id: int = node_id(room + 1, chosen, columns)
			var key: String = "%d,%d" % [from_id, to_id]
			if not edge_keys.has(key):
				edge_keys[key] = true
				if not edges_by_room.has(room):
					edges_by_room[room] = []
				(edges_by_room[room] as Array).append([column, chosen])
			cells[to_id] = [room + 1, chosen]
			column = chosen
	var ids: Array = cells.keys()
	ids.sort()
	var nodes: Array[Dictionary] = []
	var edges: Array = []
	for id: Variant in ids:
		var cell: Array = cells[id]
		nodes.append({"id": int(id), "room": int(cell[0]), "column": int(cell[1]), "type": "", "wave_id": ""})
	var edge_list: Array = edge_keys.keys()
	edge_list.sort_custom(func(a: String, b: String) -> bool:
		var pa: PackedStringArray = a.split(",")
		var pb: PackedStringArray = b.split(",")
		return int(pa[0]) < int(pb[0]) or (int(pa[0]) == int(pb[0]) and int(pa[1]) < int(pb[1])))
	for key: Variant in edge_list:
		var parts: PackedStringArray = String(key).split(",")
		edges.append([int(parts[0]), int(parts[1])])
	var boss: int = node_id(rooms, boss_column(columns), columns)
	nodes.append({"id": boss, "room": rooms, "column": boss_column(columns), "type": "", "wave_id": ""})
	for entry: Dictionary in nodes:
		if int(entry["room"]) == last_grid_room:
			edges.append([int(entry["id"]), boss])
	return {"nodes": nodes, "edges": edges}


# ---- 2. types ----

## A copy of `grid` with every node typed, or {} when some node has no type left to draw.
static func _assign_types(grid: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary) -> Dictionary:
	var map: Dictionary = (grid as Dictionary).duplicate(true)
	var fixed: Dictionary = cfg["fixed"]
	var types: Dictionary = cfg["types"]
	var type_ids: Array = types.keys()
	type_ids.sort()
	var type_of: Dictionary = {}
	var preds: Dictionary = {}
	for edge: Variant in (map["edges"] as Array):
		if not preds.has(int((edge as Array)[1])):
			preds[int((edge as Array)[1])] = [] as Array[int]
		(preds[int((edge as Array)[1])] as Array[int]).append(int((edge as Array)[0]))
	# Nodes are stored by room then column, so every predecessor is typed before the node itself.
	for entry: Variant in (map["nodes"] as Array):
		var node: Dictionary = entry
		var room: int = int(node["room"])
		var type_id: String = ""
		if fixed.has(str(room)):
			type_id = String(fixed[str(room)])
		else:
			type_id = _pick_type(rng, types, type_ids, room, preds.get(int(node["id"]), [] as Array[int]), type_of)
			if type_id.is_empty():
				return {}
		node["type"] = type_id
		type_of[int(node["id"])] = type_id
	return map


static func _pick_type(rng: RandomNumberGenerator, types: Dictionary, type_ids: Array, room: int, pred_ids: Array[int], type_of: Dictionary) -> String:
	var choices: Array[String] = []
	var total: float = 0.0
	for type_id: Variant in type_ids:
		var entry: Dictionary = types[type_id]
		var weight: float = float(entry["weight"])
		var window: Array = entry["rooms"]
		if weight <= 0.0 or room < int(window[0]) or room > int(window[1]):
			continue
		if bool(entry.get("no_repeat", false)) and pred_ids.any(func(p: int) -> bool: return String(type_of.get(p, "")) == String(type_id)):
			continue
		choices.append(String(type_id))
		total += weight
	if choices.is_empty():
		return ""
	var roll: float = rng.randf() * total
	for type_id: String in choices:
		roll -= float((types[type_id] as Dictionary)["weight"])
		if roll < 0.0:
			return type_id
	return choices[choices.size() - 1]


# ---- 5. wave lists ----

## Gives every fight node a wave id. `last_waves[id]` is the wave ids of the fights just before a node along its edges (a node with no
## fight passes its predecessors' on), so a node avoids repeating them when another list fits.
static func _assign_waves(map: Dictionary, rng: RandomNumberGenerator, run_config: Dictionary) -> void:
	var rooms_config: Dictionary = run_config.get("rooms", {})
	var preds: Dictionary = {}
	for edge: Variant in (map["edges"] as Array):
		if not preds.has(int((edge as Array)[1])):
			preds[int((edge as Array)[1])] = [] as Array[int]
		(preds[int((edge as Array)[1])] as Array[int]).append(int((edge as Array)[0]))
	var last_waves: Dictionary = {}  # id -> Array[String], what a node hands on
	for entry: Variant in (map["nodes"] as Array):
		var node: Dictionary = entry
		var id: int = int(node["id"])
		var before: Array[String] = []
		for pred: int in (preds.get(id, []) as Array[int]):
			for wave: String in (last_waves.get(pred, []) as Array[String]):
				if not before.has(wave):
					before.append(wave)
		var type_id: String = String(node["type"])
		var wave_id: String = ""
		if MapConfig.FIGHT_TYPES.has(type_id):
			var options: Array = RunConfig.variants_for(int(node["room"]) - 1, rooms_config.get(type_id, []))
			var fresh: Array = options.filter(func(v: Dictionary) -> bool: return not before.has(String(v["id"])))
			var pool: Array = fresh if not fresh.is_empty() else options
			if not pool.is_empty():
				wave_id = String((pool[rng.randi_range(0, pool.size() - 1)] as Dictionary)["id"])
		node["wave_id"] = wave_id
		last_waves[id] = [wave_id] as Array[String] if not wave_id.is_empty() else before


# ---- 6. chest sizes (MAP1-B) ----

## Gives every relic stage a chest size (MAP.md section 4.7 / BUILD_DEPTH 4.7 row 4), weighted by `chests` in the map config. Runs last, with its
## own stream per node (seeded from the run seed and the node id), so it draws nothing from the generator's rng: layout, types and wave ids are
## exactly what a map without chests gets, and one node's size does not depend on the others. A config without `chests` leaves the map alone.
static func _assign_chests(map: Dictionary, seed_value: int, config: Dictionary) -> void:
	var chests: Dictionary = MapConfig.chests(config)
	if chests.is_empty():
		return
	for entry: Variant in (map["nodes"] as Array):
		var node: Dictionary = entry
		if String(node["type"]) == "relic_room":
			node["chest"] = roll_chest(seed_value, int(node["id"]), chests)


## One node's chest size: a weighted pick from `chests` with a stream seeded from the run seed and the node id.
static func roll_chest(seed_value: int, node_id: int, chests: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = ((seed_value & RunState.SEED_LIMIT) * CHEST_SEED_MIX + node_id * 7919 + CHEST_SEED_SALT) & RunState.SEED_LIMIT
	var total: float = 0.0
	for size_id: String in MapConfig.CHEST_SIZES:
		total += float((chests[size_id] as Dictionary)["weight"])
	var roll: float = rng.randf() * total
	for size_id: String in MapConfig.CHEST_SIZES:
		roll -= float((chests[size_id] as Dictionary)["weight"])
		if roll < 0.0:
			return size_id
	return MapConfig.CHEST_SIZES[MapConfig.CHEST_SIZES.size() - 1]
