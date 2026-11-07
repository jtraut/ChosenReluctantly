class_name RunNodes
extends RefCounted
## The map half of a run's flow (MAP1-B). Pure and static over a RunState and the same context Dictionary RunChoices uses (its "nodes" entry,
## see `shipped_context`), so the pick-next-node choice, gold rolls, chest odds and the hover texts are testable without a scene.
##
## A run is a "map run" when its RunState holds a map (`active`). Without one nothing in here is used and the run is the straight run it was.
##
## Position: `state.path` holds the node ids taken, the last one being the room the player is in (`state.room_index` is that node's room - 1).
## An empty path with room_index 0 is the start: the player has not picked a room-1 node yet. The pick-next-node choice
## (`RunState.PENDING_NODE`) lists the nodes reachable from the current one (or the room-1 nodes at the start). Picking one appends it to `path`.
##
## Option ids: "node:<id>" (kind "node"). Each node option carries the keys of `node_info` (except `id`, which stays the option id; the node id is
## `node_id`) on top of the usual option keys.

const OPTION_NODE := "node"
## The act a straight run is in (chest rows and tier odds count from it); a map run reads `state.act`.
const FIRST_ACT := 1


## The map part of a RunChoices context from the shipped data.
static func shipped_context() -> Dictionary:
	var run: Dictionary = RunConfig.get_config()
	return {
		"ui": (RunConfig.ui().get("map", {}) as Dictionary),
		"gold": (run.get("gold", {}) as Dictionary),
		"chests": MapConfig.chests(),
		"tier_weights": (RelicConfig.block().get("tier_weights", {}) as Dictionary),
		"offer_count": RelicConfig.offer_count(),
		"offer_size": RunConfig.offer_size(),
		"heal_percent": roundi(RunConfig.rest_heal_fraction() * 100.0),
		"type_names": (RunConfig.ui().get("type_names", {}) as Dictionary),
	}


static func active(state: RunState) -> bool:
	return state != null and not state.map.is_empty()


## The node the player is in, or {} at the start (before the first pick).
static func current_node(state: RunState) -> Dictionary:
	if not active(state) or state.path.is_empty():
		return {}
	return MapGraph.node(state.map, state.path[state.path.size() - 1])


## The ids the player may pick now: the room-1 nodes at the start, else the edges out of the current node. Lowest column first.
static func reachable_ids(state: RunState) -> Array[int]:
	if not active(state):
		return [] as Array[int]
	if state.path.is_empty():
		return MapGraph.start_ids(state.map)
	return MapGraph.next_ids(state.map, state.path[state.path.size() - 1])


## True when the path and room index agree: one node per room played so far, or the empty start. A damaged save fails this.
static func consistent(state: RunState) -> bool:
	if not active(state):
		return state.path.is_empty()
	if state.path.is_empty():
		return state.room_index == 0 and state.pending == RunState.PENDING_NODE
	if state.path.size() != state.room_index + 1:
		return false
	return int(MapGraph.node(state.map, state.path[state.path.size() - 1]).get("room", 0)) == state.room_index + 1


# --- gold ---------------------------------------------------------------------------------------

## The gold range [low, high] a node type pays when its fight is won; [0, 0] for a type that pays nothing.
static func gold_range(node_type: String, gold_config: Dictionary) -> Array[int]:
	var range_value: Variant = gold_config.get(node_type)
	if typeof(range_value) != TYPE_ARRAY or (range_value as Array).size() != 2:
		return [0, 0] as Array[int]
	return [int((range_value as Array)[0]), int((range_value as Array)[1])] as Array[int]


## The gold of one node, rolled from the run seed and the node id (the same seed and node always pay the same, whatever order the run took).
## `run_seed` should be the act's seed (`RunState.current_act_seed`), so two acts' nodes with the same id pay differently; `scale` is the act's gold multiplier.
static func roll_gold(run_seed: int, node_id: int, node_type: String, gold_config: Dictionary, scale: float = 1.0) -> int:
	var bounds: Array[int] = gold_range(node_type, gold_config)
	if bounds[1] <= 0:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = ((run_seed & RunState.SEED_LIMIT) * 6151 + node_id * 104729 + 0x60D) & RunState.SEED_LIMIT
	var rolled: int = rng.randi_range(bounds[0], bounds[1])
	return rolled if is_equal_approx(scale, 1.0) else roundi(float(rolled) * scale)


# --- chests -------------------------------------------------------------------------------------

## The chest size of a node ("small" when the node has none, e.g. a map made without `chests`).
static func chest_of(node: Dictionary) -> String:
	return String(node.get("chest", "small"))


## The relic tier weights {tier1, tier2, tier3} a chest of `size_id` offers from: the act's row (small), the next act's row (medium) or a fixed
## row (large), then every tier below `min_tier` zeroed (so a large chest never offers tier 1). {} when the config has no such size or row.
static func chest_weights(size_id: String, act: int, chests: Dictionary, tier_weights: Dictionary) -> Dictionary:
	var entry: Variant = chests.get(size_id)
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var rule: Dictionary = entry
	var row_act: int = int(rule["act"]) if rule.has("act") else act + int(rule.get("act_offset", 0))
	var row: Dictionary = RelicConfig.tier_weights_for_act(row_act, tier_weights)
	if row.is_empty():
		return {}
	var result: Dictionary = row.duplicate()
	var min_tier: int = int(rule.get("min_tier", 1))
	for tier_index in range(RelicConfig.TIER_KEYS.size()):
		if tier_index + 1 < min_tier:
			result[RelicConfig.TIER_KEYS[tier_index]] = 0.0
	return result


## The tier weights the current relic room offers from, or {} when the run is not on a map / the room is not a relic stage (the caller keeps its
## own weights). The straight run counts as act 1.
static func weights_for_current_room(state: RunState, ctx: Dictionary) -> Dictionary:
	var node: Dictionary = current_node(state)
	if node.is_empty() or String(node["type"]) != RunConfig.RELIC_ROOM:
		return {}
	var nodes: Dictionary = ctx.get("nodes", {})
	return chest_weights(chest_of(node), state.act, nodes.get("chests", {}), nodes.get("tier_weights", {}))


# --- display ------------------------------------------------------------------------------------

## One node as the map screen draws it: {id, room, column, type, type_name, wave_id, chest, chest_name, hover, gold_low, gold_high,
## reachable, taken, current}. `chest` is "" for any node that is not a relic stage. `hover` is the data text (ui.map.hover) with its {tokens} filled.
static func node_info(state: RunState, node_id: int, ctx: Dictionary) -> Dictionary:
	var node: Dictionary = MapGraph.node(state.map, node_id)
	if node.is_empty():
		return {}
	var nodes: Dictionary = ctx.get("nodes", {})
	var ui: Dictionary = nodes.get("ui", {})
	var type_id: String = String(node["type"])
	var chest: String = chest_of(node) if type_id == RunConfig.RELIC_ROOM else ""
	var gold: Array[int] = gold_range(type_id, nodes.get("gold", {}))
	var gold_scale: float = float(RunConfig.act_scale(state.act)["gold"]) if RunConfig.is_valid() else 1.0
	if not is_equal_approx(gold_scale, 1.0):
		gold = [roundi(float(gold[0]) * gold_scale), roundi(float(gold[1]) * gold_scale)] as Array[int]
	var gold_text: String = "0" if gold[1] <= 0 else (str(gold[0]) if gold[0] == gold[1] else "%d-%d" % [gold[0], gold[1]])
	var chest_name: String = String((ui.get("chest_names", {}) as Dictionary).get(chest, chest)) if chest != "" else ""
	var hover: String = String((ui.get("hover", {}) as Dictionary).get(type_id, ""))
	hover = hover.replace("{gold}", gold_text).replace("{cards}", str(int(nodes.get("offer_size", 3)))).replace("{relics}", str(int(nodes.get("offer_count", 3))))
	hover = hover.replace("{heal}", str(int(nodes.get("heal_percent", 30)))).replace("{chest}", chest_name)
	if chest != "":
		hover += String((ui.get("chest_notes", {}) as Dictionary).get(chest, ""))
	var reachable: bool = state.pending == RunState.PENDING_NODE and reachable_ids(state).has(node_id)
	return {
		"id": node_id, "room": int(node["room"]), "column": int(node["column"]), "type": type_id,
		"type_name": String((nodes.get("type_names", {}) as Dictionary).get(type_id, type_id)),
		"wave_id": String(node["wave_id"]), "chest": chest, "chest_name": chest_name, "hover": hover,
		"gold_low": gold[0], "gold_high": gold[1],
		"reachable": reachable, "taken": state.path.has(node_id),
		"current": not state.path.is_empty() and state.path[state.path.size() - 1] == node_id,
	}


# --- the choice ---------------------------------------------------------------------------------

## Opens the pick-next-node choice (nothing else may be pending). Returns the pending value.
static func open(state: RunState) -> String:
	state.offer = []
	state.relic_incoming = ""
	state.pending = RunState.PENDING_NODE
	return state.pending


# --- acts ---------------------------------------------------------------------------------------

## True when the run is on a map and its current act is not the last: the act-end node is a mini-boss and clearing it moves the run to the next act.
static func has_next_act(state: RunState) -> bool:
	return active(state) and state.act < state.acts_total


## True when `state` is standing on its act's last node (the mini-boss, or the boss in the last act).
static func at_act_end(state: RunState) -> bool:
	var node: Dictionary = current_node(state)
	return not node.is_empty() and int(node["room"]) == state.rooms_per_act()


## Moves a run to the next act: the finished act's map and path go to `past_acts`, the next act's map is generated (from the run seed and the act
## number), and the run opens on the pick of a room-1 node. HP, gold, deck, relics and rejects stay as they are. False (nothing changes, a loud error)
## when there is no next act or its map cannot be made. `cfg` and `run_config` default to the shipped data.
static func advance_act(state: RunState, cfg: Dictionary = {}, run_config: Dictionary = {}) -> bool:
	if not has_next_act(state):
		push_error("RunNodes.advance_act: the run is not on a map with another act")
		return false
	var next_map: Dictionary = MapGenerator.generate(state.seed_value, cfg, run_config, state.act + 1, state.acts_total)
	if next_map.is_empty():
		return false  # MapGenerator has said why
	state.past_acts.append({"map": state.map, "path": state.path.duplicate()})
	state.act += 1
	state.map = next_map
	state.path = []
	state.room_index = 0
	state.merchant_visit = {}
	open(state)
	return true


static func title_and_line(ctx: Dictionary) -> Dictionary:
	var ui: Dictionary = (ctx.get("nodes", {}) as Dictionary).get("ui", {})
	return {"title": String(ui.get("title", "")), "line": String(ui.get("line", ""))}


## The reachable nodes as options: label = the type name (plus the chest size of a relic stage), detail = the hover text.
static func options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for node_id: int in reachable_ids(state):
		var shown: Dictionary = node_info(state, node_id, ctx)
		var option: Dictionary = RunChoices.blank_option("%s:%d" % [OPTION_NODE, node_id], OPTION_NODE)
		option["label"] = String(shown["type_name"]) if String(shown["chest_name"]).is_empty() else "%s (%s)" % [String(shown["type_name"]), String(shown["chest_name"]).to_lower()]
		option["detail"] = String(shown["hover"])
		for key: Variant in shown.keys():
			if String(key) != "id":  # the option's own `id` is the string "node:<id>"; the node id is `node_id`
				option[key] = shown[key]
		option["node_id"] = node_id
		out.append(option)
	return out


## Model extras for the node choice: the whole map and every node's info, for the map screen.
static func model_extras(state: RunState, ctx: Dictionary) -> Dictionary:
	var infos: Array[Dictionary] = []
	for entry: Variant in (state.map["nodes"] as Array):
		infos.append(node_info(state, int((entry as Dictionary)["id"]), ctx))
	return {"map": state.map, "path": state.path.duplicate(), "reachable": reachable_ids(state), "nodes": infos, "gold": state.gold}


## Takes a node: appends it to the path and closes the choice. Same result dict as RunChoices.apply (`kind` "node", `node_id` added).
static func apply(state: RunState, option_id: String, ctx: Dictionary) -> Dictionary:
	var result: Dictionary = RunChoices.blank_result()
	var picked: int = -1
	if option_id.begins_with(OPTION_NODE + ":") and option_id.substr(OPTION_NODE.length() + 1).is_valid_int():
		picked = option_id.substr(OPTION_NODE.length() + 1).to_int()
	if picked < 0 or not reachable_ids(state).has(picked):
		result["reason"] = "no such option '%s' in the %s choice" % [option_id, state.pending]
		return result
	state.path.append(picked)
	state.room_index = state.path.size() - 1  # one node per room: the pick moves the run into the next room
	RunChoices.close(state)
	result["kind"] = OPTION_NODE
	result["node_id"] = picked
	result["finished"] = true
	result["ok"] = true
	return result
