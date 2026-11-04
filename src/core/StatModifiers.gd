class_name StatModifiers
extends RefCounted
## Generic additive/multiplicative modifier stack, keyed by stat name (e.g.
## "slot_cooldown.attack_single"). Passives/equipment push a modifier under an
## id and pop it by that same id later; nothing here knows or cares who the
## caller is. A multiplicative value is a fractional change (0.2 == +20%,
## -0.1 == -10%), stacking additively with other multiplicative modifiers on
## the same stat before being applied as one combined factor.

class Modifier:
	var id: String
	var modifier_type: String
	var value: float
	## Primed modifiers (BD1): the stat it sits on, the cast it is used up by (a slot type id or a tag; "" = not
	## primed), how many matching casts it survives, and seconds left (-1 = never expires by time).
	var stat: String = ""
	var consume_on: String = ""
	var charges: int = 0
	var time_left: float = -1.0
	## Seconds the prime lasted when it was applied (-1 = no time limit), for a "time left" bar.
	var duration: float = -1.0

	func _init(p_id: String, p_modifier_type: String, p_value: float) -> void:
		id = p_id
		modifier_type = p_modifier_type
		value = p_value


const ADDITIVE := "additive"
const MULTIPLICATIVE := "multiplicative"

## Stat that a primed modifier of a slot's cooldown sits on: "slot_cooldown_skip.<slot_type>" > 0 makes the next
## cast of that slot start no cooldown (CardSlot clamps it to its minimum).
const COOLDOWN_SKIP_PREFIX := "slot_cooldown_skip."

var _modifiers_by_stat: Dictionary = {}
## The primed modifiers (those with consume_on), also present in _modifiers_by_stat. Usually empty.
var _primed: Array[Modifier] = []


func add_modifier(stat_name: String, modifier_id: String, modifier_type: String, value: float) -> void:
	var list: Array = _modifiers_by_stat.get(stat_name, [])
	for i in range(list.size()):
		var existing: Modifier = list[i]
		if existing.id == modifier_id:
			list.remove_at(i)
			break
	list.append(Modifier.new(modifier_id, modifier_type, value))
	_modifiers_by_stat[stat_name] = list


func remove_modifier(stat_name: String, modifier_id: String) -> void:
	for i in range(_primed.size()):
		if _primed[i].stat == stat_name and _primed[i].id == modifier_id:
			_primed.remove_at(i)
			break
	if not _modifiers_by_stat.has(stat_name):
		return
	var list: Array = _modifiers_by_stat[stat_name]
	for i in range(list.size()):
		var existing: Modifier = list[i]
		if existing.id == modifier_id:
			list.remove_at(i)
			return


## A primed modifier: like add_modifier, but it is used up by casts. It is removed after `charges` casts that
## match `consume_on` (a slot type id or a tag; a "slot_cooldown_skip.<slot>" stat also needs that slot), or after
## `duration` seconds of advance() time, whichever comes first. Same id replaces the old one.
func add_primed_modifier(stat_name: String, modifier_id: String, modifier_type: String, value: float, consume_on: String, charges: int, duration: float) -> void:
	remove_modifier(stat_name, modifier_id)
	add_modifier(stat_name, modifier_id, modifier_type, value)
	var list: Array = _modifiers_by_stat[stat_name]
	var added: Modifier = list[list.size() - 1]
	added.stat = stat_name
	added.consume_on = consume_on
	added.charges = maxi(charges, 1)
	added.time_left = duration
	added.duration = duration
	_primed.append(added)


## Ids of the primed modifiers alive now (a snapshot to hand to consume_for_cast).
func primed_ids() -> Array[String]:
	var ids: Array[String] = []
	for modifier: Modifier in _primed:
		ids.append(modifier.id)
	return ids


## Called once per cast. Every primed modifier whose consume_on matches loses one charge and is removed at zero.
## `only_ids` (from primed_ids(), taken BEFORE the cast's effects ran) limits it to buffs that already existed, so
## a card's own new buff is not used up by its own cast, and a buff stays active while the cast that uses it
## resolves. Null = every primed modifier. Returns how many were hit.
func consume_for_cast(slot_type: String, tags: Array[String], only_ids: Variant = null) -> int:
	if _primed.is_empty():
		return 0
	var used: int = 0
	var spent: Array[Modifier] = []
	for modifier: Modifier in _primed:
		if only_ids != null and not (only_ids as Array).has(modifier.id):
			continue
		if not matches_cast(modifier.stat, modifier.consume_on, slot_type, tags):
			continue
		used += 1
		modifier.charges -= 1
		if modifier.charges <= 0:
			spent.append(modifier)
	for modifier: Modifier in spent:
		remove_modifier(modifier.stat, modifier.id)
	return used


## True when a cast of `slot_type` carrying `tags` would use up a primed modifier on `stat` that is consumed by
## `consume_on` (a slot type id or a tag). A "slot_cooldown_skip.<slot>" stat also needs that slot. The one rule
## consume_for_cast and the HUD's primed marker (SlotSynergy) share, so they cannot drift apart.
static func matches_cast(stat: String, consume_on: String, slot_type: String, tags: Array[String]) -> bool:
	if consume_on != slot_type and not tags.has(consume_on):
		return false
	if stat.begins_with(COOLDOWN_SKIP_PREFIX) and stat.substr(COOLDOWN_SKIP_PREFIX.length()) != slot_type:
		return false
	return true


## Ages primed modifiers (the card controller calls it every frame) and removes those that ran out of time.
func advance(delta: float) -> void:
	if _primed.is_empty():
		return
	var expired: Array[Modifier] = []
	for modifier: Modifier in _primed:
		if modifier.time_left < 0.0:
			continue
		modifier.time_left -= delta
		if modifier.time_left <= 0.0:
			expired.append(modifier)
	for modifier: Modifier in expired:
		remove_modifier(modifier.stat, modifier.id)


## What ux needs to show primed state: [{stat, consume_on, charges, time_left, duration}] (-1 = no time limit).
func primed_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for modifier: Modifier in _primed:
		result.append({"stat": modifier.stat, "consume_on": modifier.consume_on, "charges": modifier.charges, "time_left": modifier.time_left, "duration": modifier.duration})
	return result


## True when a modifier on `stat_name` exists (any kind).
func has_modifier(stat_name: String) -> bool:
	return _modifiers_by_stat.has(stat_name) and not (_modifiers_by_stat[stat_name] as Array).is_empty()


## Applies every modifier registered for `stat_name` to `base_value`: all
## additive modifiers sum first, then every multiplicative modifier is
## combined into one factor, and the factor is applied to (base + additive).
func apply(stat_name: String, base_value: float) -> float:
	if not _modifiers_by_stat.has(stat_name):
		return base_value
	var additive_sum := 0.0
	var multiplicative_factor := 1.0
	for modifier: Modifier in (_modifiers_by_stat[stat_name] as Array):
		if modifier.modifier_type == ADDITIVE:
			additive_sum += modifier.value
		else:
			multiplicative_factor += modifier.value
	return (base_value + additive_sum) * multiplicative_factor
