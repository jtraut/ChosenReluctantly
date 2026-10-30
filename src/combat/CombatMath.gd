class_name CombatMath
extends RefCounted
## Pure, stateless combat math. Kept separate from Health/Hurtbox so it can be
## unit-tested without a running scene tree.

## Elemental resistance reduces elemental damage only; non-elemental damage (the data set in
## data/armor.json: physical, neutral) ignores
## resistance and is mitigated by armor instead (GDD §7). `resistance_fraction` is clamped to `cap`
## (default 0.5, the GDD's normal-enemy cap) before being applied.
static func apply_resistance(amount: float, damage_type: String, resistance_fraction: float, cap: float = 0.5) -> float:
	if amount <= 0.0:
		return 0.0
	if ArmorConfig.is_non_elemental(damage_type):
		return amount
	var clamped := clampf(resistance_fraction, 0.0, cap)
	return amount * (1.0 - clamped)


## Armor reduction fraction: armor / (armor + k), clamped to [0, cap]. Armor below 0 counts as 0, so the result is
## never negative and never reaches 1 (GDD section 7, Armor).
static func armor_reduction(armor: float, k: float, cap: float = 0.5) -> float:
	var a: float = maxf(armor, 0.0)
	if a <= 0.0 or k <= 0.0:
		return 0.0
	return minf(a / (a + k), cap)


## Damage after armor. Penetration is flat, subtracted from armor before the formula, and floors the result at 0.
static func apply_armor(amount: float, armor: float, penetration: float, k: float, cap: float = 0.5) -> float:
	if amount <= 0.0:
		return 0.0
	return amount * (1.0 - armor_reduction(armor - maxf(penetration, 0.0), k, cap))
