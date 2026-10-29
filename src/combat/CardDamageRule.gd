class_name CardDamageRule
extends RefCounted
## The "cards beat the free attack" rule (GDD §3, DECISIONS 2026-10-28). Pure data
## math, no scene access, so tests can feed it fixtures.
##
## A damage card is any card whose slot_type is in DAMAGE_SLOT_TYPES. Each must:
##   (a) per-cast damage >= CAST_RATIO x the light hit, and
##   (b) single-target DPS while cycling, cast / (slot base cooldown + card
##       modifier), strictly above the light's auto DPS (light damage / interval).
## Per-cast damage = direct damage of every cone/aoe/projectile effect plus the
## zone damage over its whole life (damage x ticks), the path damage of a dash, plus the damage-over-time that lands in sustained use (x its chance, the expected value; direct damage x `hits`): whole ticks over
## min(status duration, card cycle time), no resistance. A recast refreshes a
## still-running Burn instead of stacking it, so ticks past the next cast are not
## extra. A card may opt out with a non-empty `rule_exception` string.
## Non-finite (NaN / INF) numbers are reported as problems.

const DAMAGE_SLOT_TYPES: Array[String] = ["attack_single", "attack_aoe"]
const DIRECT_TEMPLATES: Array[String] = ["cone", "aoe", "projectile"]
const CAST_RATIO := 1.5
const MIN_COOLDOWN := 0.05


static func is_damage_card(card: Dictionary) -> bool:
	return DAMAGE_SLOT_TYPES.has(String(card.get("slot_type", "")))


## Sustained damage of one cast. `statuses`: status id -> definition.
## `cycle_time`: seconds until the card is cast again (see `cycle_cooldown`).
static func cast_damage(card: Dictionary, statuses: Dictionary, cycle_time: float) -> float:
	var total := 0.0
	for effect: Dictionary in card.get("effects", []):
		var template := String(effect.get("template", ""))
		var params: Dictionary = effect.get("params", {})
		if DIRECT_TEMPLATES.has(template):
			# A multi-hit effect deals its damage `hits` times (default 1).
			total += float(params.get("damage", 0.0)) * float(params.get("hits", 1))
		elif template == "zone":
			# One target standing in it for its whole life: damage x ticks (status chance is not counted).
			total += float(params.get("damage", 0.0)) * float(ZoneShape.tick_count(float(params.get("duration", 0.0)), float(params.get("tick_interval", 0.0))))
		elif template == "dash" and params.has("damage"):
			total += float(params["damage"])  # each enemy on the path is hit once per dash
		elif template == "apply_status":
			# Expected value: DoT damage x chance (default 1). A status that re-applies every hit of a
			# multi-hit only adds one refresh's worth of ticks (a refresh never stacks).
			total += status_damage(statuses.get(String(params.get("status_id", "")), {}), minf(float(params.get("duration", 0.0)), cycle_time)) * float(params.get("chance", 1.0))
	return total


## Whole ticks that fit in `duration` times damage per tick (damage_over_time only).
## Callers pass min(status duration, cycle time).
static func status_damage(status_def: Dictionary, duration: float) -> float:
	if String(status_def.get("effect_type", "")) != "damage_over_time":
		return 0.0
	var tick_interval := float(status_def.get("tick_interval", 0.0))
	if tick_interval <= 0.0:
		return 0.0
	return floorf(duration / tick_interval + 0.000001) * float(status_def.get("damage_per_tick", 0.0))


static func _all_finite(values: Array) -> bool:
	for value: float in values:
		if is_nan(value) or is_inf(value):
			return false
	return true


static func _effects_finite(card: Dictionary) -> bool:
	for effect: Dictionary in card.get("effects", []):
		for value: Variant in (effect.get("params", {}) as Dictionary).values():
			if (typeof(value) == TYPE_FLOAT) and (is_nan(value) or is_inf(value)):
				return false
	return is_finite(float(card.get("cooldown_modifier", 0.0)))


static func cycle_cooldown(card: Dictionary, slot_base_cooldown: float) -> float:
	return maxf(slot_base_cooldown + float(card.get("cooldown_modifier", 0.0)), MIN_COOLDOWN)


## Problems for one card (empty = compliant, exempt, or not a damage card).
static func check_card(card: Dictionary, slot_base_cooldown: float, light: Dictionary, statuses: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not is_damage_card(card):
		return problems
	if typeof(card.get("rule_exception")) == TYPE_STRING and not String(card["rule_exception"]).strip_edges().is_empty():
		return problems
	var id := String(card.get("id", "?"))
	var light_damage := float(light["damage"])
	var light_dps := light_damage / float(light["interval"])
	var cycle := cycle_cooldown(card, slot_base_cooldown)
	var cast := cast_damage(card, statuses, cycle)
	var dps := cast / cycle
	if not _all_finite([cast, dps, cycle, light_damage, light_dps, slot_base_cooldown]) or not _effects_finite(card):
		problems.append("%s: a damage, duration or cooldown value is NaN or INF" % id)
		return problems
	if cast < CAST_RATIO * light_damage:
		problems.append("%s: cast damage %.2f is below %.1fx the light hit (%.2f)" % [id, cast, CAST_RATIO, CAST_RATIO * light_damage])
	if dps <= light_dps:
		problems.append("%s: cycling DPS %.2f does not beat auto light DPS %.2f" % [id, dps, light_dps])
	return problems


## `cards`: Array of card dictionaries. `slot_types`: id -> {base_cooldown}.
static func check_all(cards: Array, slot_types: Dictionary, light: Dictionary, statuses: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for card: Dictionary in cards:
		if not is_damage_card(card):
			continue
		var slot: Dictionary = slot_types.get(String(card["slot_type"]), {})
		problems.append_array(check_card(card, float(slot.get("base_cooldown", 0.0)), light, statuses))
	return problems


## The rule against the shipped data: loaded cards, slot_types.json, the light
## attack and statuses.json. Used by the boot check and the shipped-data test.
static func check_shipped() -> Array[String]:
	var slot_table := JsonDataTable.new("res://data/slot_types.json")
	var slot_types: Dictionary = {}
	for slot_id: String in slot_table.ids():
		slot_types[slot_id] = slot_table.get_entry(slot_id)
	var status_table := JsonDataTable.new("res://data/statuses.json")
	var statuses: Dictionary = {}
	for status_id: String in status_table.ids():
		statuses[status_id] = status_table.get_entry(status_id)
	return check_all(CardDatabase.all_cards(), slot_types, AttackDatabase.get_attack("light"), statuses)
