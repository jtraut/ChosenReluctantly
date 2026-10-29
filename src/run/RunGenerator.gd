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
	return rooms


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
