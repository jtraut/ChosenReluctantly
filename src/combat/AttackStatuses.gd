class_name AttackStatuses
extends RefCounted
## Statuses a player attack puts on the enemies it hits.
##
## Two sources, both data:
## - the attack's "on_hit_statuses" (class flavor, e.g. Stun on the Rogue heavy):
##   [{status_id, chance (default 1), duration (default: the status's base_duration)}]
## - the character's ELEMENT status (Burn for Fire, from data/pools.json "status"):
##   chance = element base_chance x the attack's "status_chance_multiplier", clamped
##   to 0..1, lasting the attack's "element_status_duration". Light's multiplier is 0.
##
## Rolls take an injected RandomNumberGenerator so tests are deterministic; a
## chance of 0 never rolls and a chance of 1 always applies without rolling.


## Element chance for an attack, or 0.0 if the element has no status.
static func element_chance(element_id: String, status_chance_multiplier: float) -> float:
	var status: Dictionary = element_status(element_id)
	if status.is_empty():
		return 0.0
	return clampf(float(status["base_chance"]) * status_chance_multiplier, 0.0, 1.0)


## {status_id, base_chance} for an element pool, or {} (none / not an element).
static func element_status(element_id: String) -> Dictionary:
	if element_id.is_empty() or not PoolDatabase.has(element_id):
		return {}
	var status: Variant = PoolDatabase.get_definition(element_id).get("status")
	return status if typeof(status) == TYPE_DICTIONARY else {}


static func roll(rng: RandomNumberGenerator, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return rng.randf() < chance


## Applies the attack's statuses to each living hurtbox in `hits`. Returns what
## landed as [{hurtbox, status_id}] (an immune stun still counts as "landed" here;
## the status manager is what refuses it).
static func apply_on_hit(attack_def: Dictionary, element_id: String, hits: Array[Hurtbox], rng: RandomNumberGenerator, source: Node = null) -> Array[Dictionary]:
	var landed: Array[Dictionary] = []
	var multiplier: float = float(attack_def.get("status_chance_multiplier", 0.0))
	var element: Dictionary = element_status(element_id)
	var element_chance_value: float = element_chance(element_id, multiplier)
	for hurtbox: Hurtbox in hits:
		if not is_instance_valid(hurtbox) or hurtbox.status_manager == null:
			continue
		if hurtbox.health != null and hurtbox.health.is_dead():
			continue
		for item: Variant in attack_def.get("on_hit_statuses", []):
			var entry: Dictionary = item
			var status_id: String = String(entry["status_id"])
			var status_def: Dictionary = StatusDatabase.get_status(status_id)
			if status_def.is_empty() or not roll(rng, float(entry.get("chance", 1.0))):
				continue
			var duration: float = float(entry.get("duration", status_def.get("base_duration", 0.0)))
			hurtbox.status_manager.apply_status(status_id, status_def, duration, source)
			landed.append({"hurtbox": hurtbox, "status_id": status_id})
		if not element.is_empty() and roll(rng, element_chance_value):
			var element_status_id: String = String(element["status_id"])
			hurtbox.status_manager.apply_status(element_status_id, StatusDatabase.get_status(element_status_id), float(attack_def.get("element_status_duration", 0.0)), source)
			landed.append({"hurtbox": hurtbox, "status_id": element_status_id})
	return landed
