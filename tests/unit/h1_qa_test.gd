extends GdUnitTestSuite
## H1 qa: the pressure knobs reach elites and boss adds, never the boss's own phases, and bad data fails loudly.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const SPEED_IDS: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem"]


func before_test() -> void:
	BossConfig.reset_cache()
	BossStagger.disable()
	Juice.hit_stop_enabled = false
	Juice.reset()


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()
	Engine.time_scale = 1.0
	BossConfig.reset_cache()


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	return main


func test_elites_get_the_same_scaled_speed_and_cooldown_as_normals() -> void:
	var main := _spawn_main()
	for id: String in SPEED_IDS:
		var base: Dictionary = EnemyConfig.stats_for(id)
		var elite: Enemy = (load(EnemyConfig.scene_path_for(id)) as PackedScene).instantiate()
		elite.position = Vector3(0, 0, -8.0)
		main.add_child(elite)
		elite.apply_tier("elite", RunConfig.tier("elite"))
		assert_float(elite.move_speed).is_equal_approx(float(base["move_speed"]) * EnemyConfig.speed_scale(), 0.0001)
		assert_float(elite.attack_cooldown).is_equal_approx(float(base["attack_cooldown"]) / EnemyConfig.attack_rate_scale(), 0.0001)
		assert_float(elite.telegraph_duration).override_failure_message("%s telegraph must stay as authored" % id).is_equal(float(base["telegraph_duration"]))
		assert_float(elite.move_speed).override_failure_message("%s elite outruns the walk" % id).is_less(6.0)


func test_boss_adds_are_scaled_and_the_boss_walks_at_its_phase_speed() -> void:
	var main := _spawn_main()
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.global_position = main.player.global_position + Vector3(0, 0, -12.0)
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.target = main.player
	boss._summon("melee_chaser", 2)
	assert_int(boss.live_adds()).is_equal(2)
	for add: Enemy in boss._adds:
		assert_float(add.move_speed).is_equal_approx(4.0 * EnemyConfig.speed_scale(), 0.0001)
	# The boss itself: its horizontal speed is the phase 1 value in data/bosses.json, whatever the knob is.
	var phase_speed: float = float((BossConfig.boss("boss_guardian")["phases"] as Array)[0]["move_speed"])
	boss.begin_spawn_grace(0.0)
	var peak: float = 0.0
	for _i in range(40):
		await get_tree().physics_frame
		peak = maxf(peak, Vector2(boss.velocity.x, boss.velocity.z).length())
	assert_float(peak).override_failure_message("boss speed %s vs phase %s" % [peak, phase_speed]).is_less_equal(phase_speed + 0.01)
	assert_float(peak).is_greater(0.5)


func test_pressure_validation_edges_fail_loudly() -> void:
	var edge_ok: Array = [{"speed_scale": 0.25, "attack_rate_scale": 4.0}, {"speed_scale": 4, "attack_rate_scale": 1}]
	for ok: Dictionary in edge_ok:
		assert_array(EnemyConfig.validate_pressure(ok)).override_failure_message("should accept %s" % str(ok)).is_empty()
	var bad: Array = [{"speed_scale": 0.24, "attack_rate_scale": 1.0}, {"speed_scale": 1.0, "attack_rate_scale": 4.01},
		{"speed_scale": -1.0, "attack_rate_scale": 1.0}, {"speed_scale": NAN, "attack_rate_scale": 1.0},
		{"speed_scale": null, "attack_rate_scale": 1.0}, {"speed_scale": true, "attack_rate_scale": 1.0}, "fast", 3, []]
	for b: Variant in bad:
		var errors: Array[String] = EnemyConfig.validate_pressure(b)
		assert_array(errors).override_failure_message("should reject %s" % str(b)).is_not_empty()
		for line: String in errors:
			assert_str(line).contains("pressure")
	# A whole config missing the block is rejected by validate() with the same message.
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EnemyConfig.PATH))
	parsed.erase("pressure")
	assert_array(EnemyConfig.validate(parsed)).is_not_empty()


func test_shipped_pressure_values_match_the_h1_decision() -> void:
	assert_float(EnemyConfig.speed_scale()).is_equal(1.25)
	assert_float(EnemyConfig.attack_rate_scale()).is_equal(1.0)
