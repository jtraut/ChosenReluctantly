class_name CombatMathTest
extends GdUnitTestSuite


func test_physical_damage_ignores_resistance() -> void:
	var result := CombatMath.apply_resistance(10.0, "physical", 0.9)
	assert_float(result).is_equal_approx(10.0, 0.001)


func test_elemental_damage_is_reduced_by_resistance() -> void:
	var result := CombatMath.apply_resistance(10.0, "fire", 0.3)
	assert_float(result).is_equal_approx(7.0, 0.001)


func test_resistance_is_capped() -> void:
	var result := CombatMath.apply_resistance(10.0, "fire", 0.9, 0.5)
	assert_float(result).is_equal_approx(5.0, 0.001)


func test_negative_resistance_is_clamped_to_zero() -> void:
	var result := CombatMath.apply_resistance(10.0, "fire", -0.5)
	assert_float(result).is_equal_approx(10.0, 0.001)


func test_zero_or_negative_amount_returns_zero() -> void:
	assert_float(CombatMath.apply_resistance(0.0, "fire", 0.2)).is_equal_approx(0.0, 0.001)
	assert_float(CombatMath.apply_resistance(-5.0, "fire", 0.2)).is_equal_approx(0.0, 0.001)
