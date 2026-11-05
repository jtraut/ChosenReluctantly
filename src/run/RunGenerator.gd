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
		_keep_wave_variety(rooms, index, config, rng)


## The generator never gives two fight rooms in a row the same wave list when another fits (rest rooms are skipped). Taking room `index`
## out can leave the fight room before it and the one after it with the same list; then the later one draws again from the lists
## that fit its position, avoiding both neighbours' lists. Only that one room can change, and only in a run with a relic room.
static func _keep_wave_variety(rooms: Array[Dictionary], index: int, config: Dictionary, rng: RandomNumberGenerator) -> void:
	var after: int = index + 1
	if index < 1 or after >= rooms.size() - 1:
		return  # the boss follows (its list is its own), or there is nothing around
	var before_wave: String = String(rooms[index - 1]["wave_id"])
	if String(rooms[after]["wave_id"]) != before_wave or before_wave.is_empty():
		return
	var following_wave: String = ""
	for later in range(after + 1, rooms.size()):
		if RunConfig.FIGHT_TYPES.has(String(rooms[later]["type"])):
			following_wave = String(rooms[later]["wave_id"])
			break
	var type_id: String = String(rooms[after]["type"])
	var options: Array = RunConfig.variants_for(after, (config["rooms"] as Dictionary).get(type_id, [])).filter(
			func(v: Dictionary) -> bool: return String(v["id"]) != before_wave and String(v["id"]) != following_wave)
	if not options.is_empty():
		rooms[after]["wave_id"] = String((options[rng.randi_range(0, options.size() - 1)] as Dictionary)["id"])


## The room indices a relic room may take: combat rooms in [first, last] (never the first or the last room) that are not next to
## a rest, elite or relic room. (Next to the boss is allowed.) The two fight rooms around it must also hold different wave lists, so
## taking the room out never leaves the same wave list twice in a row (the generator's own rule, which skips non-fight rooms); when no
## room satisfies that the unfiltered list is returned.
static func relic_room_candidates(rooms: Array[Dictionary], first: int, last: int) -> Array[int]:
	var found: Array[int] = []
	var varied: Array[int] = []
	for index in range(maxi(first, 1), mini(last, rooms.size() - 2) + 1):
		if String(rooms[index]["type"]) != "combat":
			continue
		var next_to_special: bool = false
		for neighbour in [index - 1, index + 1]:
			if neighbour >= 0 and neighbour < rooms.size() and ["rest", "elite", RunConfig.RELIC_ROOM].has(String(rooms[neighbour]["type"])):
				next_to_special = true
		if next_to_special:
			continue
		found.append(index)
		if String(rooms[index - 1]["wave_id"]) != String(rooms[index + 1]["wave_id"]):
			varied.append(index)
	return varied if not varied.is_empty() else found


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
