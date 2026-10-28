class_name EnemyConfigTest
extends GdUnitTestSuite
## data/enemies.json: enemy attack shapes (S4-2). Values are unchanged from the old hardcodes.


func test_shipped_values_are_the_old_hardcodes() -> void:
	assert_float(EnemyConfig.projectile_hit_radius()).is_equal(0.3)
	assert_float(EnemyConfig.melee_half_angle_degrees()).is_equal(60.0)


func test_shipped_file_validates() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EnemyConfig.PATH))
	assert_array(EnemyConfig.validate(parsed)).is_empty()


func test_bad_data_is_rejected_with_a_message() -> void:
	var bad_cases: Array[Dictionary] = [
		{},
		{"attack_shapes": 3},
		{"attack_shapes": {"melee_half_angle_degrees": 60.0}},
		{"attack_shapes": {"projectile_hit_radius": 0.3}},
		{"attack_shapes": {"projectile_hit_radius": "big", "melee_half_angle_degrees": 60.0}},
		{"attack_shapes": {"projectile_hit_radius": 0.0, "melee_half_angle_degrees": 60.0}},
		{"attack_shapes": {"projectile_hit_radius": -1.0, "melee_half_angle_degrees": 60.0}},
		{"attack_shapes": {"projectile_hit_radius": 0.3, "melee_half_angle_degrees": 200.0}},
		{"attack_shapes": {"projectile_hit_radius": 0.3, "melee_half_angle_degrees": null}},
	]
	for bad in bad_cases:
		assert_array(EnemyConfig.validate(bad)).override_failure_message("should reject %s" % str(bad)).is_not_empty()
