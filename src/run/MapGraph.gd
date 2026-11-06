class_name MapGraph
extends RefCounted
## Pure helpers over an in-memory map (MAP.md section 6): {nodes: [{id, room, column, type, wave_id}], edges: [[from_id, to_id]]}.
## Node ids are whole numbers, unique, `(room - 1) * columns + column` as the generator builds them. Rooms count from 1 (the boss is the
## last room). Nothing here touches a scene, so the map screen, the run flow, the bots and the tests all read a map the same way.
##
## The API MAP1-B and the map screen use: `node`, `nodes_in_room`, `next_ids` (the choices from a node, lowest column first),
## `start_ids`, `boss_id`, `all_paths`, `first_route`, `normalize` (a map from a save or a JSON round trip, int-cast and checked).

const SYMBOLS: Dictionary = {
	"combat": "C", "elite": "E", "relic_room": "R*", "rest": "Rs", "merchant": "M",
	"mini_boss": "MB", "curse_room": "Cu", "buff_room": "Bu", "boss": "BOSS",
}


## The node with this id, or {} when there is none.
static func node(map: Dictionary, id: int) -> Dictionary:
	for entry: Variant in (map.get("nodes", []) as Array):
		if int((entry as Dictionary)["id"]) == id:
			return entry
	return {}


## The nodes of one room, lowest column first.
static func nodes_in_room(map: Dictionary, room: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Variant in (map.get("nodes", []) as Array):
		if int((entry as Dictionary)["room"]) == room:
			found.append(entry)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["column"]) < int(b["column"]))
	return found


## The ids you can go to from `id`, lowest column first (the `first` route takes the first of these).
static func next_ids(map: Dictionary, id: int) -> Array[int]:
	return adjacency(map).get(id, [] as Array[int])


## The ids with an edge into `id`, lowest column first.
static func prev_ids(map: Dictionary, id: int) -> Array[int]:
	var found: Array[int] = []
	for edge: Variant in (map.get("edges", []) as Array):
		if int((edge as Array)[1]) == id:
			found.append(int((edge as Array)[0]))
	return _by_column(map, found)


## The room-1 node ids, lowest column first: where a run may begin.
static func start_ids(map: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for entry: Dictionary in nodes_in_room(map, 1):
		ids.append(int(entry["id"]))
	return ids


## The boss node id, or -1 when the map has none.
static func boss_id(map: Dictionary) -> int:
	for entry: Variant in (map.get("nodes", []) as Array):
		if String((entry as Dictionary)["type"]) == MapConfig.BOSS:
			return int((entry as Dictionary)["id"])
	return -1


## Every id -> the ids it leads to, lowest column first. Built once per call: loops should keep the result.
static func adjacency(map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for edge: Variant in (map.get("edges", []) as Array):
		var from_id: int = int((edge as Array)[0])
		if not out.has(from_id):
			out[from_id] = [] as Array[int]
		(out[from_id] as Array[int]).append(int((edge as Array)[1]))
	for from_id: Variant in out.keys():
		out[from_id] = _by_column(map, out[from_id])
	return out


## Every path from a room-1 node to the boss, as node-id lists. At most 3^(rooms-2); the generator checks the rules on all of them.
static func all_paths(map: Dictionary) -> Array[Array]:
	var paths: Array[Array] = []
	var next: Dictionary = adjacency(map)
	var boss: int = boss_id(map)
	for start: int in start_ids(map):
		_walk(next, boss, start, [start] as Array[int], paths)
	return paths


static func _walk(next: Dictionary, boss: int, id: int, trail: Array[int], paths: Array[Array]) -> void:
	if id == boss:
		paths.append(trail.duplicate())
		return
	for following: int in (next.get(id, []) as Array[int]):
		trail.append(following)
		_walk(next, boss, following, trail, paths)
		trail.pop_back()


## The `first` route (the default for bots and `--run-room=N`): the lowest-column start, then the lowest-column choice every step.
static func first_route(map: Dictionary) -> Array[int]:
	var route: Array[int] = []
	var starts: Array[int] = start_ids(map)
	if starts.is_empty():
		return route
	var next: Dictionary = adjacency(map)
	var boss: int = boss_id(map)
	var id: int = starts[0]
	route.append(id)
	while id != boss:
		var options: Array[int] = next.get(id, [] as Array[int])
		if options.is_empty():
			break
		id = options[0]
		route.append(id)
	return route


static func _by_column(map: Dictionary, ids: Array[int]) -> Array[int]:
	var sorted_ids: Array[int] = ids.duplicate()
	var columns: Dictionary = {}
	for entry: Variant in (map.get("nodes", []) as Array):
		columns[int((entry as Dictionary)["id"])] = int((entry as Dictionary)["column"])
	sorted_ids.sort_custom(func(a: int, b: int) -> bool: return int(columns.get(a, 0)) < int(columns.get(b, 0)) or (int(columns.get(a, 0)) == int(columns.get(b, 0)) and a < b))
	return sorted_ids


## True when edge (a to b) and edge (c to d), both between the same two rooms, cross (MAP.md section 3.1). Shared ends do not cross.
static func edges_cross(a: int, b: int, c: int, d: int) -> bool:
	return (a < c and b > d) or (a > c and b < d)


## True when any two edges between the same two rooms cross.
static func has_crossing(map: Dictionary) -> bool:
	var column_of: Dictionary = {}
	var room_of: Dictionary = {}
	for entry: Variant in (map.get("nodes", []) as Array):
		column_of[int((entry as Dictionary)["id"])] = int((entry as Dictionary)["column"])
		room_of[int((entry as Dictionary)["id"])] = int((entry as Dictionary)["room"])
	var edges: Array = map.get("edges", [])
	for i in range(edges.size()):
		for j in range(i + 1, edges.size()):
			var e: Array = edges[i]
			var f: Array = edges[j]
			if room_of.get(int(e[0]), -1) != room_of.get(int(f[0]), -2):
				continue
			if edges_cross(int(column_of[int(e[0])]), int(column_of[int(e[1])]), int(column_of[int(f[0])]), int(column_of[int(f[1])])):
				return true
	return false


## A map from saved or JSON-round-tripped data: every number cast to int and the structure checked. Returns {} when `value` is
## not a well-formed map (an empty map `{}` is "no map" and also returns {}); `problems` (when given) collects what was wrong.
static func normalize(value: Variant, problems: Array[String] = []) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		problems.append("map must be an object")
		return {}
	var source: Dictionary = value
	if source.is_empty():
		return {}
	if typeof(source.get("nodes")) != TYPE_ARRAY or typeof(source.get("edges")) != TYPE_ARRAY or (source["nodes"] as Array).is_empty():
		problems.append("map needs a non-empty 'nodes' array and an 'edges' array")
		return {}
	var nodes: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry: Variant in (source["nodes"] as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			problems.append("map node must be an object")
			return {}
		var e: Dictionary = entry
		for key: String in ["id", "room", "column"]:
			if not _whole(e.get(key)):
				problems.append("map node '%s' must be a whole number" % key)
				return {}
		if typeof(e.get("type")) != TYPE_STRING or (not MapConfig.NODE_TYPES.has(String(e["type"])) and String(e["type"]) != MapConfig.BOSS):
			problems.append("map node has an unknown type %s" % str(e.get("type")))
			return {}
		if typeof(e.get("wave_id")) != TYPE_STRING:
			problems.append("map node 'wave_id' must be a string")
			return {}
		var id: int = int(e["id"])
		if seen.has(id) or int(e["room"]) < 1 or int(e["column"]) < 0:
			problems.append("map node %d is a duplicate or has a bad room or column" % id)
			return {}
		seen[id] = true
		nodes.append({"id": id, "room": int(e["room"]), "column": int(e["column"]), "type": String(e["type"]), "wave_id": String(e["wave_id"])})
	var edges: Array = []
	for edge: Variant in (source["edges"] as Array):
		if typeof(edge) != TYPE_ARRAY or (edge as Array).size() != 2 or not _whole((edge as Array)[0]) or not _whole((edge as Array)[1]):
			problems.append("map edge must be [from_id, to_id]")
			return {}
		if not seen.has(int((edge as Array)[0])) or not seen.has(int((edge as Array)[1])):
			problems.append("map edge names a node that does not exist")
			return {}
		edges.append([int((edge as Array)[0]), int((edge as Array)[1])])
	return {"nodes": nodes, "edges": edges}


static func _whole(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) < 1.0e9


## The map as text: one line per room with its nodes by column ("." for an empty cell), then each room's edges as column pairs.
static func to_text(map: Dictionary, columns: int = 4) -> String:
	var lines: PackedStringArray = []
	var rooms: int = 0
	for entry: Variant in (map.get("nodes", []) as Array):
		rooms = maxi(rooms, int((entry as Dictionary)["room"]))
	var column_of: Dictionary = {}
	for entry: Variant in (map.get("nodes", []) as Array):
		column_of[int((entry as Dictionary)["id"])] = int((entry as Dictionary)["column"])
	for room in range(1, rooms + 1):
		var cells: Array[String] = []
		for column in range(columns):
			var symbol: String = "."
			for entry: Dictionary in nodes_in_room(map, room):
				if int(entry["column"]) == column:
					symbol = String(SYMBOLS.get(String(entry["type"]), "?"))
			cells.append(symbol.rpad(5))
		var links: Array[String] = []
		for edge: Variant in (map.get("edges", []) as Array):
			if int(node(map, int((edge as Array)[0])).get("room", 0)) == room:
				links.append("%d>%d" % [int(column_of[int((edge as Array)[0])]), int(column_of[int((edge as Array)[1])])])
		var waves: Array[String] = []
		for entry: Dictionary in nodes_in_room(map, room):
			if not String(entry["wave_id"]).is_empty():
				waves.append("%d:%s" % [int(entry["column"]), String(entry["wave_id"])])
		lines.append("room %2d  %s  edges %s  waves %s" % [room, "".join(cells), " ".join(links), " ".join(waves)])
	return "\n".join(lines)
