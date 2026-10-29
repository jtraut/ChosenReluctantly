class_name TierRules
extends RefCounted
## Elite and boss stats (GDD section 7). A tier is an existing enemy type with an HP multiplier, a resistance
## floor and a visible marker, all from data/run.json `tiers`. Pure maths here; `Enemy.apply_tier` applies it.


## Each element's resistance for a tiered enemy: max(the enemy's own value, floor), capped at `cap`.
## Resistance only ever applies to elemental damage (CombatMath), so physical is never touched.
static func resistance(own: float, floor_value: float, cap: float) -> float:
	return minf(maxf(own, floor_value), cap)


## The resistance table for `elements` given the enemy's own table.
static func resistances(own: Dictionary, elements: Array, floor_value: float, cap: float) -> Dictionary:
	var out: Dictionary = own.duplicate()
	for element: Variant in elements:
		out[String(element)] = resistance(float(own.get(String(element), 0.0)), floor_value, cap)
	return out


## Every element pool id (pools with kind "element" in data/pools.json).
static func element_ids() -> Array[String]:
	var ids: Array[String] = []
	for pool_id: Variant in PoolDatabase.known_ids():
		if String(PoolDatabase.get_definition(String(pool_id)).get("kind", "")) == "element":
			ids.append(String(pool_id))
	return ids


## Max HP after the multiplier.
static func scaled_health(base: float, multiplier: float) -> float:
	return base * multiplier
