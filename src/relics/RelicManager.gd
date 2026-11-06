class_name RelicManager
extends Node
## Holds the run's relics for one room (a child of the run, not an autoload; BUILD_DEPTH 4.3). It does two things:
##   - applies each relic's `modifiers` to the player's StatModifiers (permanent for the room, ids "relic:<id>:<n>"), and
##   - connects each relic's `triggers` to the CombatEvents relay: when an event matches a trigger's filter and the
##     trigger is off cooldown, the trigger's effects run through EffectTemplates with origin "relic:<id>".
##
## Each room is a fresh scene (a new player), so the run creates a manager per room from RunState.relics and calls
## apply_modifiers(); re-applying is harmless because the same id replaces the old entry.
##
## Inert without relics: it connects to nothing, has no _process, and costs nothing per frame.
##
## Effects never run inside the event that caused them. A hit often arrives in a physics callback (a projectile's
## area_entered), where the engine refuses to add an Area3D or change a collision flag ("Function blocked during in/out
## signal"). So a matching trigger is queued and its effects run at the end of the frame (call_deferred), in order.
## `flush()` runs the queue at once (tests, or a caller that is already outside a callback). The chain depth travels with the
## queued job, so the guard below does not depend on the effects running synchronously.
##
## Recursion guard (BUILD_DEPTH 4.3): an event whose origin is a relic ("relic:<id>") is ignored by a trigger unless its
## filter says "allow_relic_origin": true, and relic triggers never nest deeper than MAX_CHAIN_DEPTH (1) levels. So a
## relic that applies Burn plus a relic that explodes when Burn ends cannot loop: the status remembers it came from a relic.

## A relic trigger fired. `trigger_index` is its place in the relic's `triggers` array. ux flashes the relic's chip on this.
signal relic_triggered(relic_id: String, trigger_index: int, event_id: String)

## How many relic-triggered effects may be on the stack when another relic trigger fires (0 = only top-level ones).
const MAX_CHAIN_DEPTH := 1
const ORIGIN_PREFIX := "relic:"

## Runs a trigger's effects: Callable(trigger: Dictionary, event: Dictionary). The default runs them through
## EffectTemplates; a test swaps it to count firings without a scene.
var effect_runner: Callable = _run_effects

var _player: Node3D = null
var _spawn_parent: Node = null
var _rng: RandomNumberGenerator = null
var _relay: CombatEventsRelay = null
var _catalog: Dictionary = {}
var _relic_ids: Array[String] = []
## Compiled triggers: {relic_id, index, event, filter, at, cooldown, effects, next_ready, matches}.
var _triggers: Array[Dictionary] = []
## event id -> the Callable connected to the relay's signal.
var _connected: Dictionary = {}
## The chain level of the job whose effects are running now (0 = none). A trigger matched meanwhile is level _depth + 1.
var _depth: int = 0
## Run-long numbers a scaled modifier reads (`per_run_stat`, MAP2-B): {stat id: value}. RunController sets them from the RunState.
var _run_stats: Dictionary = {}
var _fired_total: int = 0
## Matched triggers waiting to run: {trigger, event, level}.
var _pending: Array[Dictionary] = []
var _flush_scheduled: bool = false


## Wires the manager to the room: the player (its StatModifiers and position), the node effects are spawned under, the
## seeded RNG effects roll chances on, and the relay. `catalog` maps relic id -> relic dictionary; empty = the shipped
## data/relics. Call before add_relic / load_relics.
func configure(player: Node3D, spawn_parent: Node, rng: RandomNumberGenerator, relay: CombatEventsRelay = null, catalog: Dictionary = {}) -> void:
	_player = player
	_spawn_parent = spawn_parent
	_rng = rng
	_relay = relay if relay != null else CombatLink.events()
	_catalog = catalog
	if _catalog.is_empty():
		for relic: Dictionary in RelicDatabase.all_relics():
			_catalog[String(relic["id"])] = relic


## Replaces the held relics with `ids` (unknown ids are skipped with an error), applying modifiers and connecting triggers.
func load_relics(ids: Array[String]) -> void:
	_clear()
	for id: String in ids:
		add_relic(id)


## Adds one relic: applies its modifiers now and starts listening for its triggers. False when unknown or already held.
func add_relic(relic_id: String) -> bool:
	if _relic_ids.has(relic_id):
		return false
	if not _catalog.has(relic_id):
		push_error("RelicManager: unknown relic '%s'" % relic_id)
		return false
	_relic_ids.append(relic_id)
	var relic: Dictionary = _catalog[relic_id]
	_apply_relic_modifiers(relic)
	var triggers: Array = relic.get("triggers", [])
	for i in range(triggers.size()):
		var spec: Dictionary = triggers[i]
		_triggers.append({
			"relic_id": relic_id, "index": i, "event": String(spec["event"]), "filter": spec.get("filter", {}), "at": String(spec.get("at", RelicSchema.AT_PLAYER)),
			"cooldown": float(spec.get("internal_cooldown", 0.0)), "effects": spec["effects"], "next_ready": -1.0, "matches": 0,
		})
		_listen(String(spec["event"]))
	return true


## Removes a relic: takes its modifiers off the player and stops its triggers (the relay connection stays only while
## another trigger needs that event). False when it was not held.
func remove_relic(relic_id: String) -> bool:
	if not _relic_ids.has(relic_id):
		return false
	_relic_ids.erase(relic_id)
	var relic: Dictionary = _catalog.get(relic_id, {})
	_remove_relic_modifiers(relic)
	_triggers = _triggers.filter(func(t: Dictionary) -> bool: return String(t["relic_id"]) != relic_id)
	for event_id: String in _connected.keys():
		if not _triggers.any(func(t: Dictionary) -> bool: return String(t["event"]) == event_id):
			_unlisten(event_id)
	return true


## Sets the run stats scaled modifiers read (for example gold_spent_merchant) and re-applies the held relics' modifiers, so a value that
## changed (a purchase) takes effect at once.
func set_run_stats(stats: Dictionary) -> void:
	_run_stats = stats.duplicate()
	apply_modifiers()


## Applies every held relic's modifiers to the player (room start). Safe to call again: ids replace themselves.
func apply_modifiers() -> void:
	for relic_id: String in _relic_ids:
		_apply_relic_modifiers(_catalog[relic_id])


func relic_ids() -> Array[String]:
	return _relic_ids.duplicate()


func has_relic(relic_id: String) -> bool:
	return _relic_ids.has(relic_id)


## How many relay events this manager is listening to (0 with no triggers).
func listening_count() -> int:
	return _connected.size()


## How many trigger firings have run so far (all relics). Queued ones count once they have run.
func fired_total() -> int:
	return _fired_total


## Runs every queued trigger now, oldest first (including any that running them queues). Normally it runs by itself at the
## end of the frame; call it to run them at once.
func flush() -> void:
	_flush_scheduled = false
	while not _pending.is_empty():
		var job: Dictionary = _pending.pop_front()
		_execute(job)


func _exit_tree() -> void:
	_pending.clear()
	_disconnect_all()


func _clear() -> void:
	for relic_id: String in _relic_ids.duplicate():
		remove_relic(relic_id)
	_triggers.clear()
	_pending.clear()
	_disconnect_all()


# --- modifiers ---------------------------------------------------------------------------------

func _modifier_id(relic_id: String, index: int) -> String:
	return "%s%s:%d" % [ORIGIN_PREFIX, relic_id, index]


func _player_modifiers() -> StatModifiers:
	if _player == null or not is_instance_valid(_player):
		return null
	var stack: Variant = _player.get(&"stat_modifiers")
	return stack as StatModifiers if stack is StatModifiers else null


func _apply_relic_modifiers(relic: Dictionary) -> void:
	var mods := _player_modifiers()
	var list: Array = relic.get("modifiers", [])
	if list.is_empty():
		return
	if mods == null:
		push_error("RelicManager: relic '%s' has modifiers but the player has no stat_modifiers" % String(relic.get("id", "")))
		return
	for i in range(list.size()):
		var entry: Dictionary = list[i]
		mods.add_modifier(String(entry["stat"]), _modifier_id(String(relic["id"]), i), String(entry["modifier_type"]), scaled_value(entry, _run_stats))


## A modifier's value for the run so far: `value`, or `value` x floor(run stat / per) when it names a `per_run_stat` (+1% per 50 gold spent).
static func scaled_value(entry: Dictionary, run_stats: Dictionary) -> float:
	var value: float = float(entry["value"])
	if not entry.has("per_run_stat"):
		return value
	return value * float(floori(float(run_stats.get(String(entry["per_run_stat"]), 0)) / float(maxi(int(entry["per"]), 1))))


func _remove_relic_modifiers(relic: Dictionary) -> void:
	var mods := _player_modifiers()
	if mods == null:
		return
	var list: Array = relic.get("modifiers", [])
	for i in range(list.size()):
		mods.remove_modifier(String((list[i] as Dictionary)["stat"]), _modifier_id(String(relic["id"]), i))


# --- relay connections -------------------------------------------------------------------------

func _listen(event_id: String) -> void:
	if _connected.has(event_id):
		return
	if _relay == null:
		push_error("RelicManager: no CombatEvents relay; relic triggers for '%s' will not fire" % event_id)
		return
	var handler: Callable = _handler_for(event_id)
	_connected[event_id] = handler
	Signal(_relay, event_id).connect(handler)


func _unlisten(event_id: String) -> void:
	var handler: Callable = _connected[event_id]
	_connected.erase(event_id)
	if _relay != null and is_instance_valid(_relay):
		var relay_signal := Signal(_relay, event_id)
		if relay_signal.is_connected(handler):
			relay_signal.disconnect(handler)


func _disconnect_all() -> void:
	for event_id: String in _connected.keys():
		_unlisten(event_id)


## One handler per event: it turns the signal's arguments into the normalized event dictionary `handle_event` matches
## against: {event, origin, target, position (Vector3 or null), amount, damage_type, kind, statuses, status_id, reason,
## slot_type, card_id, tags, attack_id, shape, room_type}. Keys an event does not have are absent.
func _handler_for(event_id: String) -> Callable:
	match event_id:
		"hit_landed":
			return func(target: Node, amount: float, damage_type: String, kind: StringName, origin: String, position: Vector3) -> void:
				handle_event({"event": event_id, "target": target, "amount": amount, "damage_type": damage_type, "kind": String(kind), "origin": origin, "position": position, "tags": _origin_tags(origin)})
		"enemy_killed":
			return func(target: Node, position: Vector3, origin: String, statuses: Array[String]) -> void:
				handle_event({"event": event_id, "target": target, "position": position, "origin": origin, "statuses": statuses})
		"status_applied":
			return func(target: Node, status_id: String, _stacks: int, _source: Node, origin: String, position: Vector3) -> void:
				handle_event({"event": event_id, "target": target, "status_id": status_id, "origin": origin, "position": position})
		"status_ended":
			return func(target: Node, status_id: String, reason: String, _source: Node, origin: String, position: Vector3) -> void:
				handle_event({"event": event_id, "target": target, "status_id": status_id, "reason": reason, "origin": origin, "position": position})
		"card_cast":
			return func(slot_type: String, card_id: String, tags: Array[String]) -> void:
				handle_event({"event": event_id, "slot_type": slot_type, "card_id": card_id, "tags": tags, "origin": ""})
		"attack_fired":
			return func(attack_id: String, aim_point: Vector3) -> void:
				handle_event({"event": event_id, "attack_id": attack_id, "position": aim_point, "origin": ""})
		"dash_ended":
			return func(_start: Vector3, end: Vector3, card_id: String) -> void:
				handle_event({"event": event_id, "card_id": card_id, "position": end, "origin": ""})
		"player_damaged":
			return func(amount: float, origin: String) -> void:
				handle_event({"event": event_id, "amount": amount, "origin": origin})
		"zone_started", "zone_ended":
			return func(_zone_id: int, shape: String, position: Vector3) -> void:
				handle_event({"event": event_id, "shape": shape, "position": position, "origin": ""})
		"room_started", "room_cleared":
			return func(_index: int, room_type: String) -> void:
				handle_event({"event": event_id, "room_type": room_type, "origin": ""})
	push_error("RelicManager: no handler for event '%s'" % event_id)
	return Callable()


## The tags of the card behind a "card:<id>" origin (the `tag` filter of hit_landed), else none.
static func _origin_tags(origin: String) -> Array[String]:
	if origin.begins_with("card:"):
		return CardDatabase.tags_for(origin.substr(5))
	return [] as Array[String]


# --- matching and firing -----------------------------------------------------------------------

## Offers one normalized event to every trigger (see _handler_for for the keys). Public so tests can drive it without a relay.
func handle_event(event: Dictionary) -> void:
	if _triggers.is_empty() or _depth > MAX_CHAIN_DEPTH:
		return
	var event_id: String = String(event["event"])
	var origin: String = String(event.get("origin", ""))
	# Copy: a trigger's effects can add or remove relics (and so change the list) while we walk it.
	for trigger: Dictionary in _triggers.duplicate():
		if String(trigger["event"]) != event_id:
			continue
		var filter: Dictionary = trigger["filter"]
		if origin.begins_with(ORIGIN_PREFIX) and not bool(filter.get("allow_relic_origin", false)):
			continue  # the recursion guard: a relic's own work does not trigger relics
		if not _matches(filter, event):
			continue
		trigger["matches"] = int(trigger["matches"]) + 1
		var nth: int = int(filter.get("every_nth", 0))
		if nth > 1 and int(trigger["matches"]) % nth != 0:
			continue
		var now: float = _now()
		if now < float(trigger["next_ready"]):
			continue
		trigger["next_ready"] = now + float(trigger["cooldown"])
		_pending.append({"trigger": trigger, "event": event, "level": _depth + 1})
		if not _flush_scheduled:
			_flush_scheduled = true
			flush.call_deferred()


## The matches counted so far this room for the relic's every-Nth trigger (0 when it has none or is not held). Display and tests; the
## HUD shows it as "matches mod N / N" (see RelicProgress).
func trigger_progress(relic_id: String) -> int:
	for trigger: Dictionary in _triggers:
		if String(trigger["relic_id"]) == relic_id and int((trigger["filter"] as Dictionary).get("every_nth", 0)) > 1:
			return int(trigger["matches"])
	return 0


func _now() -> float:
	return _relay.now() if _relay != null and is_instance_valid(_relay) else 0.0


func _execute(job: Dictionary) -> void:
	var trigger: Dictionary = job["trigger"]
	if not _relic_ids.has(String(trigger["relic_id"])):
		return  # given up while it waited
	var outer: int = _depth
	_depth = int(job["level"])
	_fired_total += 1
	effect_runner.call(trigger, job["event"])
	_depth = outer
	relic_triggered.emit(String(trigger["relic_id"]), int(trigger["index"]), String(trigger["event"]))


func _matches(filter: Dictionary, event: Dictionary) -> bool:
	for key: Variant in filter.keys():
		var wanted: Variant = filter[key]
		match String(key):
			"origin":
				var origin: String = String(event.get("origin", ""))
				var hit: bool = false
				for pattern: String in _as_strings(wanted):
					if RelicSchema.origin_matches(pattern, origin):
						hit = true
						break
				if not hit:
					return false
			"damage_type", "status_id", "reason", "slot_type", "card_id", "attack_id", "shape", "room_type", "kind":
				if not _as_strings(wanted).has(String(event.get(key, ""))):
					return false
			"target_team":
				if not _as_strings(wanted).has(CombatEventsRelay.team_of(event.get("target") as Node)):
					return false
			"target_has_status":
				if not _any_status(_as_strings(wanted), event):
					return false
			"tag":
				var tags: Array = event.get("tags", [])
				if not _as_strings(wanted).any(func(tag: String) -> bool: return tags.has(tag)):
					return false
			"min_amount":
				if float(event.get("amount", 0.0)) < float(wanted):
					return false
			# allow_relic_origin and every_nth are handled by handle_event.
	return true


func _any_status(wanted: Array[String], event: Dictionary) -> bool:
	if event.has("statuses"):
		var held: Array = event["statuses"]
		return wanted.any(func(id: String) -> bool: return held.has(id))
	var target := event.get("target") as Node
	if target == null or not is_instance_valid(target):
		return false
	var manager := target.get_node_or_null("StatusEffectManager") as StatusEffectManager
	if manager == null:
		return false
	return wanted.any(func(id: String) -> bool: return manager.has_status(id))


static func _as_strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for item: Variant in (value as Array):
			result.append(String(item))
	else:
		result.append(String(value))
	return result


## The default runner: the trigger's effects through EffectTemplates, from the player, stamped "relic:<id>". `at` chooses
## where: the player (default), the event's position, or the event's target (which also becomes the hit set, so an
## apply_status first in the list lands on it).
func _run_effects(trigger: Dictionary, event: Dictionary) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var context := EffectContext.new(_player, _spawn_parent if _spawn_parent != null else _player.get_parent(), "player")
	context.origin = ORIGIN_PREFIX + String(trigger["relic_id"])
	context.rng = _rng
	if _relay != null and is_instance_valid(_relay):
		context.cast_history = _relay.history
		context.now = _relay.now()
	if _player.has_method("get_aim_point"):
		context.aim_point = _player.call("get_aim_point")
	if _player.has_method("get_arena_rect"):
		context.arena = _player.call("get_arena_rect")
	var at: String = String(trigger["at"])
	var where: Variant = event.get("position")
	var place: bool = at != RelicSchema.AT_PLAYER and where is Vector3
	if place:
		context.aim_point = where
	if at == RelicSchema.AT_EVENT_TARGET:
		var target := event.get("target") as Node
		if target != null and is_instance_valid(target):
			var box := target.get_node_or_null("Hurtbox") as Hurtbox
			if box != null:
				var seeded: Array[Hurtbox] = [box]
				context.last_hits = seeded
	for effect: Dictionary in trigger["effects"]:
		var params: Dictionary = effect.get("params", {})
		if place and String(effect.get("template", "")) == "aoe" and not params.has("center"):
			params = params.duplicate()
			params["center"] = where
		EffectTemplates.execute(String(effect.get("template", "")), params, context, effect.get("condition", {}))
