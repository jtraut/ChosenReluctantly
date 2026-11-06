class_name MapLayout
extends RefCounted
## Pure geometry and navigation for the map screen (MAP1 ux). Nothing here touches a scene, so the layout, the focus order and the
## default focus are unit-tested at every window size. Input is the map screen's data: {map, path, reachable, nodes: [node_info], gold}.
##
## The grid: one column of the screen per room (left to right), one lane per map column (top to bottom). A node sits at the centre of its
## cell, so a lane keeps its place from room to room and the lines between nodes stay short and straight.

## Legend order: the types a map can hold, then the boss.
const TYPE_ORDER: Array[String] = ["combat", "elite", "relic_room", "rest", "merchant", "mini_boss", "curse_room", "buff_room", "boss"]

const STATE_CURRENT := "current"
const STATE_TAKEN := "taken"
const STATE_REACHABLE := "reachable"
const STATE_FUTURE := "future"


## {rooms, lanes} of a map: the last room number and the highest lane + 1 (at least 1 each).
static func dimensions(map: Dictionary) -> Vector2i:
	var rooms: int = 1
	var lanes: int = 1
	for entry: Variant in (map.get("nodes", []) as Array):
		var node: Dictionary = entry
		rooms = maxi(rooms, int(node["room"]))
		lanes = maxi(lanes, int(node["column"]) + 1)
	return Vector2i(rooms, lanes)


## The size of one cell when `area` holds the whole grid.
static func cell_size(area: Rect2, dims: Vector2i) -> Vector2:
	return Vector2(area.size.x / float(maxi(dims.x, 1)), area.size.y / float(maxi(dims.y, 1)))


## The centre of the cell for a node in `room` (1-based) and `lane` (0-based).
static func center(area: Rect2, dims: Vector2i, room: int, lane: int) -> Vector2:
	var cell: Vector2 = cell_size(area, dims)
	return area.position + Vector2((float(room) - 0.5) * cell.x, (float(lane) + 0.5) * cell.y)


## The base node radius: a share of the smaller cell side, never above `max_radius` (pixels). The largest chest grows past this by its
## chest scale, so the share keeps that inside the cell.
static func node_radius(area: Rect2, dims: Vector2i, cell_share: float, max_radius: float) -> float:
	var cell: Vector2 = cell_size(area, dims)
	return minf(minf(cell.x, cell.y) * cell_share, max_radius)


## The radius of one node: a relic stage grows with its chest size (small < medium < large), anything else is the base.
static func radius_for(info: Dictionary, base: float, chest_scale: Dictionary) -> float:
	var chest: String = String(info.get("chest", ""))
	if chest == "":
		return base
	return base * float(chest_scale.get(chest, 1.0))


## How many pips a chest shows inside its hexagon (small 1, medium 2, large 3), so the size never rests on size alone. 0 for no chest.
static func pip_count(chest: String) -> int:
	match chest:
		"small":
			return 1
		"medium":
			return 2
		"large":
			return 3
	return 0


## The look state of a node: current (ring), taken (on the path), reachable (can be picked now) or future.
static func node_state(info: Dictionary) -> String:
	if bool(info.get("current", false)):
		return STATE_CURRENT
	if bool(info.get("taken", false)):
		return STATE_TAKEN
	if bool(info.get("reachable", false)):
		return STATE_REACHABLE
	return STATE_FUTURE


## The types to list in the legend: every type the map holds, in TYPE_ORDER (types not in TYPE_ORDER follow, sorted).
static func legend_types(map: Dictionary) -> Array[String]:
	var present: Dictionary = {}
	for entry: Variant in (map.get("nodes", []) as Array):
		present[String((entry as Dictionary)["type"])] = true
	var out: Array[String] = []
	for type_id: String in TYPE_ORDER:
		if present.has(type_id):
			out.append(type_id)
	var extra: Array[String] = []
	for key: Variant in present.keys():
		if not TYPE_ORDER.has(String(key)):
			extra.append(String(key))
	extra.sort()
	out.append_array(extra)
	return out


## True when the only room the player can pick next is the boss (room 9 on to room 10): there is no choice left, so the screen says so.
static func boss_only(infos: Array[Dictionary]) -> bool:
	var reachable: int = 0
	var boss: bool = false
	for info: Dictionary in infos:
		if bool(info.get("reachable", false)):
			reachable += 1
			boss = String(info.get("type", "")) == "boss"
	return reachable == 1 and boss


## True when a merchant node is still ahead (on the map and not walked): the gold line only helps then.
static func merchant_ahead(infos: Array[Dictionary]) -> bool:
	for info: Dictionary in infos:
		if String(info.get("type", "")) == "merchant" and not bool(info.get("taken", false)):
			return true
	return false


## The chest sizes the map holds, small to large.
static func legend_chests(infos: Array[Dictionary]) -> Array[String]:
	var present: Dictionary = {}
	for info: Dictionary in infos:
		if String(info.get("chest", "")) != "":
			present[String(info["chest"])] = true
	var out: Array[String] = []
	for size_id: String in ["small", "medium", "large"]:
		if present.has(size_id):
			out.append(size_id)
	return out


## The node the focus starts on when the map opens to pick: the reachable node whose type comes first in `order` (the least surprising
## kind: a plain fight, then rest, ...), the lowest lane on a tie. -1 when nothing is reachable. A reflexive Enter lands on this one.
static func default_focus(infos: Array[Dictionary], order: Array) -> int:
	var best_id: int = -1
	var best_rank: int = 1 << 30
	var best_lane: int = 1 << 30
	for info: Dictionary in infos:
		if not bool(info.get("reachable", false)):
			continue
		var rank: int = order.find(String(info["type"]))
		if rank < 0:
			rank = order.size()
		var lane: int = int(info["column"])
		if rank < best_rank or (rank == best_rank and lane < best_lane):
			best_id = int(info["id"])
			best_rank = rank
			best_lane = lane
	return best_id


## Focus neighbours among `focusable_ids`: {id: {up, down, left, right}} (ids, -1 for none). Up and down go to the next node in the same
## room (lane order). Left and right go to the nearest focusable room on that side, picking the node nearest in lane. When every focusable
## node is in one room (the pick screen: the nodes you can reach are all in the next room) left and right act like up and down, so any arrow
## key moves and the focus wraps from the last node to the first.
static func neighbors(infos: Array[Dictionary], focusable_ids: Array[int]) -> Dictionary:
	var by_room: Dictionary = {}
	for info: Dictionary in infos:
		if focusable_ids.has(int(info["id"])):
			var room: int = int(info["room"])
			if not by_room.has(room):
				by_room[room] = [] as Array[Dictionary]
			(by_room[room] as Array[Dictionary]).append(info)
	for room_key: Variant in by_room.keys():
		(by_room[room_key] as Array[Dictionary]).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["column"]) < int(b["column"]))
	var rooms: Array = by_room.keys()
	rooms.sort()
	var single_room: bool = rooms.size() == 1
	var result: Dictionary = {}
	for room_key: Variant in rooms:
		var column_nodes: Array[Dictionary] = by_room[room_key]
		for i in range(column_nodes.size()):
			var info: Dictionary = column_nodes[i]
			var up: int = int(column_nodes[i - 1]["id"]) if i > 0 else -1
			var down: int = int(column_nodes[i + 1]["id"]) if i + 1 < column_nodes.size() else -1
			if single_room and column_nodes.size() > 1:
				up = int(column_nodes[(i - 1 + column_nodes.size()) % column_nodes.size()]["id"])
				down = int(column_nodes[(i + 1) % column_nodes.size()]["id"])
			var left: int = up if single_room else _nearest_in_room(by_room, rooms, int(room_key), -1, int(info["column"]))
			var right: int = down if single_room else _nearest_in_room(by_room, rooms, int(room_key), 1, int(info["column"]))
			result[int(info["id"])] = {"up": up, "down": down, "left": left, "right": right}
	return result


static func _nearest_in_room(by_room: Dictionary, rooms: Array, room: int, direction: int, lane: int) -> int:
	var index: int = rooms.find(room) + direction
	if index < 0 or index >= rooms.size():
		return -1
	var best_id: int = -1
	var best_gap: int = 1 << 30
	for info: Dictionary in (by_room[rooms[index]] as Array[Dictionary]):
		var gap: int = absi(int(info["column"]) - lane)
		if gap < best_gap:
			best_gap = gap
			best_id = int(info["id"])
	return best_id


## The font size for map text: the authored size scaled with the window, never under the readable minimum.
static func font_px(base: float, scale_factor: float, min_px: float) -> int:
	return maxi(roundi(base * scale_factor), roundi(min_px))
