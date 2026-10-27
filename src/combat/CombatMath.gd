class_name CombatMath
extends RefCounted
## Pure, stateless combat math. Kept separate from Health/Hurtbox so it can be
## unit-tested without a running scene tree.

## Elemental resistance reduces elemental damage only; physical damage ignores
## resistance entirely (GDD §7). `resistance_fraction` is clamped to `cap`
## (default 0.5, the GDD's normal-enemy cap) before being applied.
static func apply_resistance(amount: float, damage_type: String, resistance_fraction: float, cap: float = 0.5) -> float:
	if amount <= 0.0:
		return 0.0
	if damage_type == "physical":
		return amount
	var clamped := clampf(resistance_fraction, 0.0, cap)
	return amount * (1.0 - clamped)
