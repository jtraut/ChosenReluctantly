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


func test_pressure_knobs_validate() -> void:
	assert_array(EnemyConfig.validate_pressure({"speed_scale": 1.0, "attack_rate_scale": 1.0})).is_empty()
	assert_array(EnemyConfig.validate_pressure({"speed_scale": 1.25, "attack_rate_scale": 1})).is_empty()
	var bad_cases: Array = [null, {}, {"speed_scale": 1.0}, {"speed_scale": 0.0, "attack_rate_scale": 1.0},
		{"speed_scale": 1.0, "attack_rate_scale": 9.0}, {"speed_scale": "fast", "attack_rate_scale": 1.0},
		{"speed_scale": 1.0, "attack_rate_scale": 1.0, "tier": 2}]
	for bad: Variant in bad_cases:
		assert_array(EnemyConfig.validate_pressure(bad)).override_failure_message("should reject %s" % str(bad)).is_not_empty()


func test_pressure_knobs_are_read_from_data() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemyConfig.PATH))
	assert_float(EnemyConfig.speed_scale()).is_equal(float(parsed["pressure"]["speed_scale"]))
	assert_float(EnemyConfig.attack_rate_scale()).is_equal(float(parsed["pressure"]["attack_rate_scale"]))


## H1: with the shipped knobs, no normal or elite enemy walks faster than the player (Player.move_speed).
func test_no_scaled_enemy_outruns_the_player_walk() -> void:
	var player: Player = Player.new()
	var walk: float = player.move_speed
	player.free()
	for id: String in EnemyConfig.enemy_ids():
		if EnemyConfig.rank_for(id) == "boss":
			continue
		var speed: float = float(EnemyConfig.stats_for(id)["move_speed"]) * EnemyConfig.speed_scale()
		assert_float(speed).override_failure_message("%s at %s m/s outruns the player's %s" % [id, speed, walk]).is_less(walk)
