class_name EnemyStats5dTest
extends GdUnitTestSuite
## 5d item 3: per-type combat stats live in data/enemies.json. OLD holds the values the scene exports
## had before the move (frozen here on purpose); a spawned enemy of each type must still have them.

const OLD: Dictionary = {
	"melee_chaser": {"move_speed": 4.0, "is_ranged": false, "attack_range": 1.5, "preferred_range": 6.0, "attack_damage": 5.0, "attack_damage_type": "physical", "attack_cooldown": 1.2, "telegraph_duration": 0.45, "projectile_speed": 10.0, "projectile_max_range": 20.0},
	"ranged_shooter": {"move_speed": 3.0, "is_ranged": true, "attack_range": 1.6, "preferred_range": 7.0, "attack_damage": 4.0, "attack_damage_type": "physical", "attack_cooldown": 1.6, "telegraph_duration": 0.45, "projectile_speed": 9.0, "projectile_max_range": 18.0},
	"fire_resistant_golem": {"move_speed": 2.0, "is_ranged": false, "attack_range": 2.0, "preferred_range": 6.0, "attack_damage": 9.0, "attack_damage_type": "physical", "attack_cooldown": 1.8, "telegraph_duration": 0.7, "projectile_speed": 10.0, "projectile_max_range": 20.0},
}


func test_data_stats_equal_the_old_scene_values() -> void:
	for id: String in OLD.keys():
		var stats: Dictionary = EnemyConfig.stats_for(id)
		var old: Dictionary = OLD[id]
		assert_int(stats.size()).is_equal(old.size())
		for key: String in old.keys():
			assert_that(stats[key]).is_equal(old[key])


func test_spawned_enemies_carry_the_data_stats() -> void:
	for id: String in OLD.keys():
		var enemy: Enemy = (load(EnemyConfig.scene_path_for(id)) as PackedScene).instantiate()
		add_child(enemy)
		auto_free(enemy)
		var old: Dictionary = OLD[id]
		assert_float(enemy.move_speed).is_equal(float(old["move_speed"]))
		assert_bool(enemy.is_ranged).is_equal(bool(old["is_ranged"]))
		assert_float(enemy.attack_range).is_equal(float(old["attack_range"]))
		assert_float(enemy.preferred_range).is_equal(float(old["preferred_range"]))
		assert_float(enemy.attack_damage).is_equal(float(old["attack_damage"]))
		assert_str(enemy.attack_damage_type).is_equal(String(old["attack_damage_type"]))
		assert_float(enemy.attack_cooldown).is_equal(float(old["attack_cooldown"]))
		assert_float(enemy.telegraph_duration).is_equal(float(old["telegraph_duration"]))
		assert_float(enemy.projectile_speed).is_equal(float(old["projectile_speed"]))
		assert_float(enemy.projectile_max_range).is_equal(float(old["projectile_max_range"]))


func test_stats_validation_rejects_bad_blocks() -> void:
	var good: Dictionary = (OLD["melee_chaser"] as Dictionary).duplicate()
	assert_array(EnemyConfig.validate_stats("x", good)).is_empty()
	assert_array(EnemyConfig.validate_stats("x", null)).is_not_empty()
	var missing := good.duplicate()
	missing.erase("attack_damage")
	assert_array(EnemyConfig.validate_stats("x", missing)).is_not_empty()
	var negative := good.duplicate()
	negative["move_speed"] = -1.0
	assert_array(EnemyConfig.validate_stats("x", negative)).is_not_empty()
	var wrong_type := good.duplicate()
	wrong_type["is_ranged"] = "yes"
	assert_array(EnemyConfig.validate_stats("x", wrong_type)).is_not_empty()
	var typo := good.duplicate()
	typo["atack_range"] = 1.0
	assert_array(EnemyConfig.validate_stats("x", typo)).is_not_empty()
	var empty_type := good.duplicate()
	empty_type["attack_damage_type"] = ""
	assert_array(EnemyConfig.validate_stats("x", empty_type)).is_not_empty()
