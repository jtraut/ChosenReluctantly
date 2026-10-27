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

	func _init(p_id: String, p_modifier_type: String, p_value: float) -> void:
		id = p_id
		modifier_type = p_modifier_type
		value = p_value


const ADDITIVE := "additive"
const MULTIPLICATIVE := "multiplicative"

var _modifiers_by_stat: Dictionary = {}


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
	if not _modifiers_by_stat.has(stat_name):
		return
	var list: Array = _modifiers_by_stat[stat_name]
	for i in range(list.size()):
		var existing: Modifier = list[i]
		if existing.id == modifier_id:
			list.remove_at(i)
			return


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
