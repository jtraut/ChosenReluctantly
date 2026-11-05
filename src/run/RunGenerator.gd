class_name RunGenerator
extends RefCounted
## Builds a run's room sequence from a seed and the run config (data/run.json). Pure and deterministic:
## the same seed and config always give the same list. Each room is {index, type, wave_id}; `wave_id` is ""
## for a rest room. Rules (all data): the boss is last, `placement.first_room` is index 0, elite and rest rooms
## land at seeded positions inside their `placement.ranges`, every other slot is a combat room. A fight
## room's wave list is picked among the lists that allow its index, avoiding the previous fight room's list
## when another is available.


static func generate(seed_value: int, config: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var composition: Dictionary = config["composition"]
	var total: int = 0
	for room_type: String in RunConfig.ROOM_TYPES:
		total += int(composition.get(room_type, 0))
	var types: Array[String] = []
	types.resize(total)
	types[total - 1] = "boss"
	var remaining: Dictionary = {"elite": int(composition.get("elite", 0)), "rest": int(composition.get("rest", 0))}
	var first_room: String = String(config["placement"]["first_room"])
	types[0] = first_room
	if remaining.has(first_room):
		remaining[first_room] = maxi(int(remaining[first_room]) - 1, 0)
	var ranges: Dictionary = config["placement"]["ranges"]
	# Place the scarcest type first (the narrowest window), so a tight window cannot be starved by a wide one.
	var order: Array[String] = ["elite", "rest"]
	order.sort_custom(func(a: String, b: String) -> bool: return _window_size(ranges, a) < _window_size(ranges, b))
	for room_type: String in order:
		var count: int = int(remaining[room_type])
		if count <= 0:
			continue
		var window: Array = ranges[room_type]
		var candidates: Array[int] = []
		for index in range(int(window[0]), int(window[1]) + 1):
			if index > 0 and index < total - 1 and types[index] == "":
				candidates.append(index)
		_shuffle(candidates, rng)
		for i in range(mini(count, candidates.size())):
			types[candidates[i]] = room_type
	for index in range(total):
		if types[index] == "":
			types[index] = "combat"
	var rooms: Array[Dictionary] = []
	var last_wave: String = ""
	for index in range(total):
		var room_type: String = types[index]
		var wave_id: String = ""
		if RunConfig.FIGHT_TYPES.has(room_type):
			var options: Array = RunConfig.variants_for(index, (config["rooms"] as Dictionary).get(room_type, []))
			var fresh: Array = options.filter(func(v: Dictionary) -> bool: return String(v["id"]) != last_wave)
			var pool: Array = fresh if not fresh.is_empty() else options
			if not pool.is_empty():
				wave_id = String((pool[rng.randi_range(0, pool.size() - 1)] as Dictionary)["id"])
			last_wave = wave_id
		rooms.append({"index": index, "type": room_type, "wave_id": wave_id})
	_place_relic_rooms(rooms, seed_value, config)
	return rooms


## BD2-B: when relics are on, turns `count` combat rooms into relic rooms (no fight, a relic offer) inside [first, last] and never next
## to the rest room, the elite or another relic room. It runs AFTER the rooms are laid out, with its own seeded stream, so the
## room count, every other room's type and every wave list is exactly what a run without relics gets. (The converted room keeps
## its place in the wave-list rotation, so nothing after it shifts.) With relics off, or no `relics` block, nothing happens.
static func _place_relic_rooms(rooms: Array[Dictionary], seed_value: int, config: Dictionary) -> void:
	var settings: Dictionary = RelicConfig.relic_room_settings(config)
	if settings.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value * 2654435 + 0x5E11C) & RunState.SEED_LIMIT
	for placed in range(int(settings["count"])):
		var candidates: Array[int] = relic_room_candidates(rooms, int(settings["first"]), int(settings["last"]))
		if candidates.is_empty():
			push_error("RunGenerator: no combat room is free for relic room %d of %d (window %d to %d); the run has none" % [placed + 1, int(settings["count"]), int(settings["first"]), int(settings["last"])])
			return
		var index: int = candidates[rng.randi_range(0, candidates.size() - 1)]
		rooms[index] = {"index": index, "type": RunConfig.RELIC_ROOM, "wave_id": ""}


## The room indices a relic room may take: combat rooms in [first, last] (never the first or the last room) that are not next to
## a rest, elite or relic room. (Next to the boss is allowed.)
static func relic_room_candidates(rooms: Array[Dictionary], first: int, last: int) -> Array[int]:
	var found: Array[int] = []
	for index in range(maxi(first, 1), mini(last, rooms.size() - 2) + 1):
		if String(rooms[index]["type"]) != "combat":
			continue
		var next_to_special: bool = false
		for neighbour in [index - 1, index + 1]:
			if neighbour >= 0 and neighbour < rooms.size() and ["rest", "elite", RunConfig.RELIC_ROOM].has(String(rooms[neighbour]["type"])):
				next_to_special = true
		if not next_to_special:
			found.append(index)
	return found


static func _window_size(ranges: Dictionary, room_type: String) -> int:
	var window: Variant = ranges.get(room_type)
	if typeof(window) != TYPE_ARRAY:
		return 0
	return int((window as Array)[1]) - int((window as Array)[0]) + 1


static func _shuffle(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = values[i]
		values[i] = values[j]
		values[j] = swap
