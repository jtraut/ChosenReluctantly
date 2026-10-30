class_name BossSpawnPl2Test
extends GdUnitTestSuite
## PL2 item 1: the boss starts fully on screen (data/bosses.json `spawn`).

const KNOWN_ENEMIES: Array[String] = ["chaser", "shooter"]


func _spawn_def() -> Dictionary:
	return BossConfig.boss("boss_guardian")["spawn"]


func test_screen_box_math_matches_the_iso_camera() -> void:
	assert_bool(EnemySpawner.screen_box_contains(Vector3.ZERO, 1.0, 1.0)).is_true()
	# Straight "up the screen" on the ground is (-1, 0, -1)/sqrt 2: 10 m of depth is 5.77 m up the screen.
	assert_bool(EnemySpawner.screen_box_contains(Vector3(-7.07, 0, -7.07), 1.0, 6.0)).is_true()
	assert_bool(EnemySpawner.screen_box_contains(Vector3(-7.07, 0, -7.07), 1.0, 5.0)).is_false()
	# Screen-right is (1, 0, -1)/sqrt 2.
	assert_bool(EnemySpawner.screen_box_contains(Vector3(7.07, 0, -7.07), 10.5, 1.0)).is_true()
	assert_bool(EnemySpawner.screen_box_contains(Vector3(7.07, 0, -7.07), 9.0, 1.0)).is_false()


func test_boss_always_spawns_inside_the_box_and_clear_of_the_player() -> void:
	var spawn: Dictionary = _spawn_def()
	var target: Node3D = auto_free(Node3D.new())
	add_child(target)
	var spawner: EnemySpawner = auto_free(EnemySpawner.new())
	add_child(spawner)
	spawner.target = target
	spawner.plan = WavePlan.new(WaveConfig.get_config())
	for seed_value in range(60):
		spawner.set_seed(seed_value)
		for corner: Vector3 in [Vector3.ZERO, Vector3(15.0, 0.0, 15.0), Vector3(-15.0, 0.0, -15.0)]:
			target.global_position = corner
			var pos: Vector3 = spawner._boss_spawn_position(spawn)
			assert_bool(EnemySpawner.screen_box_contains(pos - corner, float(spawn["screen_half_width"]), float(spawn["screen_half_height"]))) \
				.override_failure_message("seed %d at %s: %s outside the box" % [seed_value, corner, pos]).is_true()
			assert_float(Vector2(pos.x - corner.x, pos.z - corner.z).length()).is_greater_equal(float(spawn["distance_min"]) - 0.001)


func test_spawn_block_validation() -> void:
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH))
	assert_array(BossConfig.validate(shipped, KNOWN_ENEMIES)).is_empty()
	var inverted := shipped.duplicate(true)
	inverted["bosses"]["boss_guardian"]["spawn"]["distance_max"] = 3.0
	assert_array(BossConfig.validate(inverted, KNOWN_ENEMIES)).is_not_empty()
	var partial := shipped.duplicate(true)
	(partial["bosses"]["boss_guardian"]["spawn"] as Dictionary).erase("screen_half_height")
	assert_array(BossConfig.validate(partial, KNOWN_ENEMIES)).is_not_empty()
	var absent := shipped.duplicate(true)
	(absent["bosses"]["boss_guardian"] as Dictionary).erase("spawn")
	assert_array(BossConfig.validate(absent, KNOWN_ENEMIES)).is_empty()
