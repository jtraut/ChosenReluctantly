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
## BD3b-B: a buff's triggers went live (a buff with a `triggers` list was applied or refreshed) and `expires_at` is the relay clock time they stop.
## `source` is the buff's origin ("card:<id>"). ux shows a cue while a buff's triggers are live.
signal buff_triggers_started(source: String, expires_at: float)
## A buff's triggers stopped. `reason` is "expired", "reset" (the relay was reset: run, room or arena load) or "cleared" (the manager left the tree).
signal buff_triggers_ended(source: String, reason: String)
## A buff's trigger fired (ran its effects). `trigger_index` is its place in the buff's `triggers` list.
signal buff_trigger_fired(source: String, trigger_index: int, event_id: String)

## BD3b-B buff triggers: a buff effect's `triggers` list (relic trigger format) lives in a manager hosted by the caster (buff_host(), created on
## first use, so a run with no relics needs none). Each is live only while its buff lasts: they carry the buff's expiry on the relay clock and
## are dropped on expiry, when the relay resets (a run, room or arena loads) and when the host leaves the tree (room exit). They match, queue and
## run exactly as relic triggers do (origin guard, internal cooldown, chain depth), with the effects stamped "relic:buff_<card id>". Recasting the
## same buff refreshes its expiry and keeps one set of triggers (and the cooldowns), so a recast never doubles a nova.
const BUFF_HOST_NAME := "BuffTriggers"
const BUFF_HOST_META := &"buff_trigger_host"
const BUFF_ORIGIN_ID_PREFIX := "buff_"
## A dash shorter than this (metres) leaves no line.
const MIN_PATH_LENGTH := 0.1

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
var _reset_connected: bool = false
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
		_triggers.append(_compile_trigger(relic_id, ORIGIN_PREFIX + relic_id, i, spec))
		_listen(String(spec["event"]))
	return true


## One compiled trigger: {relic_id, origin, index, event, filter, at, cooldown, effects, next_ready, matches, buff, dead}. `relic_id` is the owner's id
## (for a buff trigger the buff's key, with `buff` true, `source` and `expires_at` added); `origin` is what its effects are stamped with.
func _compile_trigger(owner_id: String, origin: String, index: int, spec: Dictionary) -> Dictionary:
	return {
		"relic_id": owner_id, "origin": origin, "index": index, "event": String(spec["event"]), "filter": spec.get("filter", {}), "at": String(spec.get("at", RelicSchema.AT_PLAYER)),
		"cooldown": float(spec.get("internal_cooldown", 0.0)), "effects": spec["effects"], "next_ready": -1.0, "matches": 0, "buff": false, "dead": false,
	}


## Removes a relic: takes its modifiers off the player and stops its triggers (the relay connection stays only while
## another trigger needs that event). False when it was not held.
func remove_relic(relic_id: String) -> bool:
	if not _relic_ids.has(relic_id):
		return false
	_relic_ids.erase(relic_id)
	var relic: Dictionary = _catalog.get(relic_id, {})
	_remove_relic_modifiers(relic)
	_triggers = _triggers.filter(func(t: Dictionary) -> bool: return bool(t["buff"]) or String(t["relic_id"]) != relic_id)
	_unlisten_unused()
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
	_end_all_buff_triggers("cleared")
	_pending.clear()
	_disconnect_all()
	_disconnect_reset()


func _clear() -> void:
	for relic_id: String in _relic_ids.duplicate():
		remove_relic(relic_id)
	_end_all_buff_triggers("cleared")
	_triggers.clear()
	_pending.clear()
	_disconnect_all()


func _unlisten_unused() -> void:
	for event_id: String in _connected.keys():
		if not _triggers.any(func(t: Dictionary) -> bool: return String(t["event"]) == event_id):
			_unlisten(event_id)


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
## slot_type, card_id, tags, attack_id, shape, room_type, path_start (dash_ended: where the dash began; `position` is where it ended)}. Keys an event does not have are absent.
func _handler_for(event_id: String) -> Callable:
	match event_id:
		"hit_landed":
			return func(target: Node, amount: float, damage_type: String, kind: StringName, origin: String, position: Vector3) -> void:
				handle_event({"event": event_id, "target": target, "amount": amount, "damage_type": damage_type, "kind": String(kind), "origin": origin, "position": position, "tags": _origin_tags(origin), "slot_type": _origin_slot_type(origin)})
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
			return func(start: Vector3, end: Vector3, card_id: String) -> void:
				handle_event({"event": event_id, "card_id": card_id, "position": end, "path_start": start, "origin": ""})
		"dash_passed_through":
			return func(card_id: String, _count: int, position: Vector3) -> void:
				handle_event({"event": event_id, "card_id": card_id, "position": position, "origin": ""})
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


## The slot type of the card behind a "card:<id>" origin (the `slot_type` filter of hit_landed), else "".
static func _origin_slot_type(origin: String) -> String:
	if origin.begins_with("card:"):
		return String(CardDatabase.get_card(origin.substr(5)).get("slot_type", ""))
	return ""


# --- matching and firing -----------------------------------------------------------------------

## Offers one normalized event to every trigger (see _handler_for for the keys). Public so tests can drive it without a relay.
func handle_event(event: Dictionary) -> void:
	var base_depth: int = maxi(_depth, CombatEventsRelay.chain_depth)
	if _triggers.is_empty() or base_depth > MAX_CHAIN_DEPTH:
		return
	_expire_buff_triggers()
	var event_id: String = String(event["event"])
	var origin: String = String(event.get("origin", ""))
	# Copy: a trigger's effects can add or remove relics (and so change the list) while we walk it.
	for trigger: Dictionary in _triggers.duplicate():
		if String(trigger["event"]) != event_id:
			continue
		if bool(trigger["dead"]):
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
		_pending.append({"trigger": trigger, "event": event, "level": base_depth + 1})
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


## The event's target node, or null when it has none or was freed since the event (a killing blow frees the enemy before a deferred trigger runs;
## casting a freed object to Node is a script error, so check validity on the Variant first).
static func _live_target(event: Dictionary) -> Node:
	var raw: Variant = event.get("target")
	if raw == null or not is_instance_valid(raw):
		return null
	return raw as Node


func _now() -> float:
	return _relay.now() if _relay != null and is_instance_valid(_relay) else 0.0


func _execute(job: Dictionary) -> void:
	var trigger: Dictionary = job["trigger"]
	var is_buff: bool = bool(trigger["buff"])
	if bool(trigger["dead"]) or (not is_buff and not _relic_ids.has(String(trigger["relic_id"]))):
		return  # given up (or its buff ended) while it waited
	var outer: int = _depth
	var outer_ambient: int = CombatEventsRelay.chain_depth
	_depth = int(job["level"])
	CombatEventsRelay.chain_depth = _depth
	_fired_total += 1
	effect_runner.call(trigger, job["event"])
	_depth = outer
	CombatEventsRelay.chain_depth = outer_ambient
	if is_buff:
		buff_trigger_fired.emit(String(trigger["source"]), int(trigger["index"]), String(trigger["event"]))
	else:
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
				if not _as_strings(wanted).has(CombatEventsRelay.team_of(_live_target(event))):
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
	var target := _live_target(event)
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
	context.origin = String(trigger["origin"])
	context.chain_depth = _depth
	context.rng = _rng
	if "card_slots" in _player and _player.card_slots != null:
		context.deck_card_ids = _player.card_slots.owned_card_ids()
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
	var path_start: Variant = event.get("path_start") if at == RelicSchema.AT_EVENT_PATH else null
	if place:
		context.aim_point = where
	if at == RelicSchema.AT_EVENT_TARGET:
		var target := _live_target(event)
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
		if path_start is Vector3 and where is Vector3 and String(effect.get("template", "")) == "zone":
			params = _along_path(params, path_start, where)
			if params.is_empty():
				continue  # a dash that did not move leaves no line
		if String(effect.get("template", "")) == "projectile" and not params.has("direction") and _player.has_method("get_shot_direction"):
			# MAP3b: a relic's bolt follows the aim (the reticle), not the body, which trails the mouse by a few frames.
			params = params.duplicate()
			params["direction"] = _player.call("get_shot_direction")
		EffectTemplates.execute(String(effect.get("template", "")), params, context, effect.get("condition", {}), effect.get("scale", {}))


## A line zone's params laid along the path from `start` to `end` (BD3b-B): `length` becomes the path's length, and the code-only `center` (the midpoint)
## and `cast_dir` (across the path, because a line zone's long side runs across its cast direction) place it, bypassing the caster-relative placement.
## Empty when the path is too short to be a line.
static func _along_path(params: Dictionary, start: Vector3, end: Vector3) -> Dictionary:
	var along := Vector3(end.x - start.x, 0.0, end.z - start.z)
	if along.length() < MIN_PATH_LENGTH:
		return {}
	var out: Dictionary = params.duplicate()
	out["length"] = minf(along.length(), EffectTemplates.MAX_ZONE_LINE_LENGTH)
	out["center"] = Vector3((start.x + end.x) * 0.5, end.y, (start.z + end.z) * 0.5)
	var direction: Vector3 = along.normalized()
	out["cast_dir"] = Vector3(direction.z, 0.0, -direction.x)
	return out


# --- buff triggers (BD3b-B) ----------------------------------------------------------------------

## The caster's host for buff triggers: a RelicManager child named "BuffTriggers" with no relics, found through the caster's meta or created now.
## `relay` lets a test give the host its own relay (the first call decides; later calls reuse it).
static func buff_host(caster: Node3D, spawn_parent: Node, rng: RandomNumberGenerator, relay: CombatEventsRelay = null) -> RelicManager:
	var found: Variant = caster.get_meta(BUFF_HOST_META) if caster.has_meta(BUFF_HOST_META) else null
	if found is RelicManager and is_instance_valid(found):
		var existing: RelicManager = found
		if rng != null:
			existing._rng = rng
		return existing
	var host := RelicManager.new()
	host.name = BUFF_HOST_NAME
	caster.add_child(host)
	host.configure(caster, spawn_parent, rng, relay, {"": {}})  # a non-empty catalog: the host holds no relics, so it never loads the shipped ones
	caster.set_meta(BUFF_HOST_META, host)
	return host


## Makes a buff's `triggers` live for `duration` seconds of relay time. `source` is the buff's origin ("card:<id>", or any non-empty text), which
## also keys it: applying the same source again refreshes the expiry and keeps the one set of triggers. Their effects are stamped
## "relic:buff_<id>", so the recursion guard treats them like a relic's.
func add_buff_triggers(source: String, triggers: Array, duration: float) -> void:
	if source.is_empty() or triggers.is_empty():
		return
	var expires_at: float = _now() + duration
	var existing: bool = false
	for trigger: Dictionary in _triggers:
		if bool(trigger["buff"]) and String(trigger["source"]) == source and not bool(trigger["dead"]):
			trigger["expires_at"] = expires_at
			existing = true
	if not existing:
		var origin: String = ORIGIN_PREFIX + BUFF_ORIGIN_ID_PREFIX + (source.substr(source.find(":") + 1) if source.contains(":") else source)
		for i in range(triggers.size()):
			var trigger: Dictionary = _compile_trigger(source, origin, i, triggers[i])
			trigger["buff"] = true
			trigger["source"] = source
			trigger["expires_at"] = expires_at
			_triggers.append(trigger)
			_listen(String(trigger["event"]))
	_connect_reset()
	buff_triggers_started.emit(source, expires_at)
	if is_inside_tree():
		get_tree().create_timer(duration, false).timeout.connect(_expire_source.bind(source, expires_at))


## True while the source's buff triggers are live.
func has_buff_triggers(source: String) -> bool:
	return _triggers.any(func(t: Dictionary) -> bool: return bool(t["buff"]) and String(t["source"]) == source and not bool(t["dead"]))


## Sources whose buff triggers are live now.
func live_buff_sources() -> Array[String]:
	var result: Array[String] = []
	for trigger: Dictionary in _triggers:
		if bool(trigger["buff"]) and not bool(trigger["dead"]) and not result.has(String(trigger["source"])):
			result.append(String(trigger["source"]))
	return result


## Ends one source's buff triggers now (reason as buff_triggers_ended).
func remove_buff_triggers(source: String, reason: String) -> void:
	var removed: bool = false
	for trigger: Dictionary in _triggers:
		if bool(trigger["buff"]) and String(trigger["source"]) == source and not bool(trigger["dead"]):
			trigger["dead"] = true
			removed = true
	if removed:
		_triggers = _triggers.filter(func(t: Dictionary) -> bool: return not bool(t["dead"]))
		_unlisten_unused()
		buff_triggers_ended.emit(source, reason)


## Drops every source's buff triggers now.
func clear_buff_triggers(reason: String = "cleared") -> void:
	_end_all_buff_triggers(reason)


func _end_all_buff_triggers(reason: String) -> void:
	for source: String in live_buff_sources():
		remove_buff_triggers(source, reason)


## Drops the sources whose expiry has passed on the relay clock. handle_event runs it first, so a trigger never matches after its buff ended.
func _expire_buff_triggers() -> void:
	var now: float = _now()
	for trigger: Dictionary in _triggers.duplicate():
		if bool(trigger["buff"]) and not bool(trigger["dead"]) and now >= float(trigger["expires_at"]):
			remove_buff_triggers(String(trigger["source"]), "expired")


## The timer end: only the application that set this expiry may end it (a refresh moved the expiry on, and has its own timer).
func _expire_source(source: String, expires_at: float) -> void:
	for trigger: Dictionary in _triggers:
		if bool(trigger["buff"]) and String(trigger["source"]) == source and is_equal_approx(float(trigger["expires_at"]), expires_at):
			remove_buff_triggers(source, "expired")
			return


func _connect_reset() -> void:
	if _reset_connected or _relay == null or not is_instance_valid(_relay):
		return
	_reset_connected = true
	_relay.reset_done.connect(_on_relay_reset)


func _disconnect_reset() -> void:
	if not _reset_connected:
		return
	_reset_connected = false
	if _relay != null and is_instance_valid(_relay) and _relay.reset_done.is_connected(_on_relay_reset):
		_relay.reset_done.disconnect(_on_relay_reset)


func _on_relay_reset() -> void:
	_end_all_buff_triggers("reset")
	_pending = _pending.filter(func(job: Dictionary) -> bool: return not bool((job["trigger"] as Dictionary)["dead"]))
