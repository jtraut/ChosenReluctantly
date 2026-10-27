class_name StatModifiersTest
extends GdUnitTestSuite


func test_no_modifiers_returns_base_value() -> void:
	var mods := StatModifiers.new()
	assert_float(mods.apply("slot_cooldown.attack_single", 2.0)).is_equal_approx(2.0, 0.001)


func test_additive_modifiers_sum() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("slot_cooldown.attack_single", "passive_a", StatModifiers.ADDITIVE, -0.2)
	mods.add_modifier("slot_cooldown.attack_single", "passive_b", StatModifiers.ADDITIVE, -0.3)
	assert_float(mods.apply("slot_cooldown.attack_single", 2.0)).is_equal_approx(1.5, 0.001)


func test_multiplicative_modifiers_combine_as_one_factor() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("slot_cooldown.attack_single", "passive_a", StatModifiers.MULTIPLICATIVE, 0.5)
	mods.add_modifier("slot_cooldown.attack_single", "passive_b", StatModifiers.MULTIPLICATIVE, -0.2)
	# base(2.0) * (1.0 + 0.5 - 0.2) = 2.0 * 1.3
	assert_float(mods.apply("slot_cooldown.attack_single", 2.0)).is_equal_approx(2.6, 0.001)


func test_additive_applies_before_multiplicative() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("slot_cooldown.attack_single", "flat", StatModifiers.ADDITIVE, 1.0)
	mods.add_modifier("slot_cooldown.attack_single", "percent", StatModifiers.MULTIPLICATIVE, 0.5)
	# (2.0 + 1.0) * 1.5 = 4.5
	assert_float(mods.apply("slot_cooldown.attack_single", 2.0)).is_equal_approx(4.5, 0.001)


func test_replacing_a_modifier_by_id_does_not_duplicate() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("slot_cooldown.attack_single", "passive_a", StatModifiers.ADDITIVE, -0.2)
	mods.add_modifier("slot_cooldown.attack_single", "passive_a", StatModifiers.ADDITIVE, -0.9)
	assert_float(mods.apply("slot_cooldown.attack_single", 2.0)).is_equal_approx(1.1, 0.001)


func test_removing_a_modifier_reverts_the_stat() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("slot_cooldown.attack_single", "passive_a", StatModifiers.ADDITIVE, -0.5)
	mods.remove_modifier("slot_cooldown.attack_single", "passive_a")
	assert_float(mods.apply("slot_cooldown.attack_single", 2.0)).is_equal_approx(2.0, 0.001)


func test_modifiers_on_different_stats_do_not_interact() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("slot_cooldown.attack_single", "passive_a", StatModifiers.ADDITIVE, -0.5)
	assert_float(mods.apply("slot_cooldown.movement", 2.0)).is_equal_approx(2.0, 0.001)
