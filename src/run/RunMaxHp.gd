class_name RunMaxHp
extends RefCounted
## HP1 (D55 = B): max HP relics. Pure functions over a RunState and the relic data, so they test without a scene.
##
## The run owns max HP (`RunState.max_hp`); a relic never changes it through the player's StatModifiers (that would compound every room).
## `RunState.relic_max_hp` holds each held relic's current contribution {relic_id: amount}, so losing a relic takes exactly its boost away.
##   - Flat: a relic modifier {stat: "max_hp", modifier_type: "additive", value: N} adds N when the relic is gained.
##   - Per elite: a trigger on `room_cleared` (room_type "elite") with a `gain_max_hp {amount}` effect adds `amount` each time such a room is
##     cleared while the relic is held (the clear that dropped the relic does not count: the offer opens after the event). Mini-bosses have
##     the room type "mini_boss", so the filter leaves them out.
## Gaining max HP also raises the current HP by the same amount. Losing a relic lowers max HP (never below the events' `min_max_hp` floor,
## and never raising it) and clamps the current HP into [1, max HP].

const STAT := "max_hp"
const EFFECT := "gain_max_hp"
const DEFAULT_FLOOR := 10.0


## The flat max HP a relic's data gives on gaining it (the sum of its `max_hp` modifiers).
static func flat_amount(relic: Dictionary) -> float:
	var total: float = 0.0
	for entry: Variant in (relic.get("modifiers", []) as Array):
		if typeof(entry) == TYPE_DICTIONARY and String((entry as Dictionary).get("stat", "")) == STAT:
			total += float((entry as Dictionary)["value"])
	return total


## What a held relic adds per matching room clear: {room_type: amount}-style list of {room_type, amount} for its gain_max_hp triggers.
static func clear_rules(relic: Dictionary) -> Array[Dictionary]:
	var rules: Array[Dictionary] = []
	for trigger: Variant in (relic.get("triggers", []) as Array):
		if typeof(trigger) != TYPE_DICTIONARY or String((trigger as Dictionary).get("event", "")) != "room_cleared":
			continue
		var room_filter: Variant = ((trigger as Dictionary).get("filter", {}) as Dictionary).get("room_type", "")
		for effect: Variant in ((trigger as Dictionary).get("effects", []) as Array):
			if typeof(effect) == TYPE_DICTIONARY and String((effect as Dictionary).get("template", "")) == EFFECT:
				rules.append({"room_type": room_filter, "amount": float(((effect as Dictionary).get("params", {}) as Dictionary).get("amount", 0.0))})
	return rules


static func _matches(room_filter: Variant, room_type: String) -> bool:
	if typeof(room_filter) == TYPE_ARRAY:
		return (room_filter as Array).has(room_type)
	return String(room_filter).is_empty() or String(room_filter) == room_type


## The floor max HP never goes below (data/run.json events.min_max_hp).
static func floor_hp() -> float:
	var events: Variant = RunConfig.get_config().get("events", {})
	if typeof(events) == TYPE_DICTIONARY:
		return float((events as Dictionary).get("min_max_hp", DEFAULT_FLOOR))
	return DEFAULT_FLOOR


## Raises max HP and current HP by `amount` for `relic_id`. Before the run has HP (a start with a debug relic) only the record is kept;
## RunController folds `pending_total` in when it sets the starting HP.
static func gain(state: RunState, relic_id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	state.relic_max_hp[relic_id] = float(state.relic_max_hp.get(relic_id, 0.0)) + amount
	if state.has_hp():
		state.max_hp += amount
		state.hp += amount


## Called by RunState.add_relic.
static func on_relic_gained(state: RunState, relic_id: String) -> void:
	var amount: float = flat_amount(RelicDatabase.get_relic(relic_id))
	if amount > 0.0:
		gain(state, relic_id, amount)


## Called by RunState.give_up_relic: takes the relic's whole boost off and clamps the HP.
static func on_relic_lost(state: RunState, relic_id: String) -> void:
	if not state.relic_max_hp.has(relic_id):
		return
	var amount: float = float(state.relic_max_hp[relic_id])
	state.relic_max_hp.erase(relic_id)
	if state.has_hp():
		state.max_hp = maxf(minf(state.max_hp, floor_hp()), state.max_hp - amount)
		state.hp = clampf(state.hp, 1.0, state.max_hp)


## A fight room of `room_type` was cleared: every held relic with a matching gain_max_hp rule adds its amount.
## Returns {relic_id: amount gained this clear} (empty when nothing matched).
static func on_room_cleared(state: RunState, room_type: String) -> Dictionary:
	var gained: Dictionary = {}
	for relic_id: String in state.relics:
		for rule: Dictionary in clear_rules(RelicDatabase.get_relic(relic_id)):
			if _matches(rule["room_type"], room_type):
				gain(state, relic_id, float(rule["amount"]))
				gained[relic_id] = float(gained.get(relic_id, 0.0)) + float(rule["amount"])
	return gained


## The boosts recorded while the run had no HP yet (the starting HP is the class's base plus this).
static func pending_total(state: RunState) -> float:
	var total: float = 0.0
	for amount: Variant in state.relic_max_hp.values():
		total += float(amount)
	return total
