extends Node
class_name Health
## Generic health/damage component. Attach to any Node3D that can take damage.
## Two mitigation channels (GDD section 7): elemental damage goes through the per-element resistance table;
## non-elemental damage (the data-defined set in data/armor.json: physical, neutral) goes through armor. Neither
## channel touches the other's damage. This is the single choke point for both.

signal damaged(amount: float, damage_type: String, knockback: Vector3)
signal healed(amount: float)
signal health_changed(current: float, maximum: float)
signal died()

## How a damage event is delivered, so feel code can treat them differently:
## "hit" is a direct hit (full hit-stop and shake), "echo" is hit 2..N of a multi-hit
## (number and flash only), "dot" is a status tick (number only).
const KIND_HIT := &"hit"
const KIND_ECHO := &"echo"
const KIND_DOT := &"dot"

## Which channel reduced the last damage event (valid in `damaged` handlers, like last_kind): "armor", "resistance",
## or "none" (nothing was removed). ux styles damage numbers from it.
const CHANNEL_NONE := &"none"
const CHANNEL_ARMOR := &"armor"
const CHANNEL_RESISTANCE := &"resistance"

@export var max_health: float = 20.0
## element name ("fire", "water", ...) -> resistance fraction [0, resistance_cap]
@export var resistances: Dictionary = {}
@export var resistance_cap: float = 0.5
## Base armor points (default 0). The effective value reads the `armor` stat through `stat_modifiers` when one is set
## (the player's own stack), so gear and passives can raise it later.
@export var base_armor: float = 0.0
var stat_modifiers: StatModifiers = null

## HP the damage cannot take it below (default 0 = none). The boss raises it to the next phase threshold, so one big
## hit stops there and the transition runs instead of skipping the phase (or killing it before its last one).
var hp_floor: float = 0.0
var current_health: float = 0.0
## While true, take_damage does nothing. The run system sets it when a room is cleared, so an arrow still in
## the air or a status tick cannot kill a player who already won the room.
var damage_immune: bool = false
var _is_dead: bool = false
## Kind of the damage event being delivered right now. Valid inside `damaged` handlers
## (the signal signature stays fixed; handlers read this instead).
var last_kind: StringName = KIND_HIT
var last_channel: StringName = CHANNEL_NONE
## Fraction of the raw hit the last event removed (0 to the cap), and the raw amount before mitigation.
var last_reduction: float = 0.0
var last_raw_amount: float = 0.0


func _ready() -> void:
	current_health = max_health


## `source` is whoever dealt it (may be null or freed). If it has a `damage_dealt`
## signal it is emitted once per event with the HP actually removed (overkill is not
## counted), so lifesteal and similar listeners cover every damage source.
func take_damage(amount: float, damage_type: String = "physical", knockback: Vector3 = Vector3.ZERO, source: Node = null, kind: StringName = KIND_HIT) -> void:
	if _is_dead or damage_immune or amount <= 0.0:
		return
	var channel: StringName = CHANNEL_NONE
	var final_amount: float = amount
	if ArmorConfig.is_non_elemental(damage_type):
		var reduction: float = CombatMath.armor_reduction(get_armor() - _attacker_penetration(source), ArmorConfig.k(), ArmorConfig.reduction_cap())
		final_amount = amount * (1.0 - reduction)
		if reduction > 0.0:
			channel = CHANNEL_ARMOR
	else:
		var resistance_fraction: float = resistances.get(damage_type, 0.0)
		final_amount = CombatMath.apply_resistance(amount, damage_type, resistance_fraction, resistance_cap)
		if final_amount < amount:
			channel = CHANNEL_RESISTANCE
	if final_amount <= 0.0:
		return
	var lowest: float = minf(hp_floor, current_health)
	var removed: float = minf(final_amount, current_health - lowest)
	current_health = maxf(current_health - final_amount, lowest)
	if removed <= 0.0:
		return  # held at the floor: nothing was taken
	last_kind = kind
	last_channel = channel
	last_raw_amount = amount
	last_reduction = 1.0 - final_amount / amount
	damaged.emit(final_amount, damage_type, knockback)
	health_changed.emit(current_health, max_health)
	if source != null and is_instance_valid(source) and source.has_signal(&"damage_dealt"):
		source.emit_signal(&"damage_dealt", get_parent(), removed, damage_type, kind)
	if current_health <= 0.0 and not _is_dead:
		_is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)


func get_current_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


## Change max HP at runtime (buffs, passives). Clamps current HP and emits
## health_changed so bars update.
func set_max_health(new_max: float) -> void:
	max_health = maxf(new_max, 1.0)
	current_health = minf(current_health, max_health)
	health_changed.emit(current_health, max_health)


## Effective armor now: base through the `armor` stat modifiers, never below 0.
func get_armor() -> float:
	var value: float = base_armor
	if stat_modifiers != null:
		value = stat_modifiers.apply(ArmorConfig.ARMOR_STAT, base_armor)
	return maxf(value, 0.0)


## Fraction of non-elemental damage armor removes right now (against an attacker with no penetration).
func get_armor_reduction() -> float:
	return CombatMath.armor_reduction(get_armor(), ArmorConfig.k(), ArmorConfig.reduction_cap())


## The attacker's flat armor penetration, from its `stat_modifiers` stack (anything without one has 0).
static func _attacker_penetration(source: Node) -> float:
	if source == null or not is_instance_valid(source):
		return 0.0
	var mods: Variant = source.get(&"stat_modifiers")
	if mods is StatModifiers:
		return maxf((mods as StatModifiers).apply(ArmorConfig.PENETRATION_STAT, 0.0), 0.0)
	return 0.0


func get_resistance(element: String) -> float:
	return clampf(resistances.get(element, 0.0), 0.0, resistance_cap)


func is_dead() -> bool:
	return _is_dead
