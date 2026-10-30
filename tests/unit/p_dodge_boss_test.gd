class_name PDodgeBossTest
extends GdUnitTestSuite
## P-dodge 4c (D16): at each phase threshold the boss staggers (interrupting its attack, vulnerable) before the roar.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const BOSS_ID := "boss_guardian"


func before_test() -> void:
	Juice.hit_stop_enabled = false


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0
	BossConfig.reset_cache()


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	main.player.health.damage_immune = true
	return main


func _boss(main: Main) -> Boss:
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -10.0)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.health.base_armor = 0.0
	boss._attack_cooldown_remaining = 99.0
	return boss


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _seconds_to_frames(seconds: float) -> int:
	return int(ceil(seconds * float(Engine.physics_ticks_per_second)))


func _stagger() -> float:
	return BossConfig.stagger_seconds(BossConfig.boss(BOSS_ID))


func _roar() -> float:
	return float((BossConfig.boss(BOSS_ID)["transition"] as Dictionary)["duration"])


func _config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH)) as Dictionary


# ---- Data ----

func test_shipped_stagger_is_valid_and_the_whole_transition_fits_the_cap() -> void:
	assert_float(_stagger()).is_equal(0.8)
	var rules: Dictionary = BossConfig.get_config()["rules"]
	assert_float(_stagger() + _roar()).is_less_equal(float(rules["max_transition"]))
	assert_array(BossConfig.validate(_config(), ["melee_chaser", "ranged_shooter", "fire_resistant_golem", "boss_guardian"])).is_empty()


func test_stagger_validation() -> void:
	var known: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem", "boss_guardian"]
	var plain: Dictionary = _config()
	(plain["bosses"][BOSS_ID]["transition"] as Dictionary).erase("stagger")
	assert_array(BossConfig.validate(plain, known)).override_failure_message("stagger is optional").is_empty()
	assert_float(BossConfig.stagger_seconds(plain["bosses"][BOSS_ID])).is_equal(BossConfig.DEFAULT_STAGGER)
	for bad: Variant in [-0.1, 3.5, "long", null, true]:
		var config: Dictionary = _config()
		config["bosses"][BOSS_ID]["transition"]["stagger"] = bad
		assert_array(BossConfig.validate(config, known)).override_failure_message("accepted stagger %s" % str(bad)).is_not_empty()
	var too_long: Dictionary = _config()
	too_long["bosses"][BOSS_ID]["transition"]["stagger"] = 1.0
	too_long["bosses"][BOSS_ID]["transition"]["duration"] = 1.2
	assert_array(BossConfig.validate(too_long, known)).override_failure_message("stagger + duration over the cap").is_not_empty()
	var zero: Dictionary = _config()
	zero["bosses"][BOSS_ID]["transition"]["stagger"] = 0.0
	assert_array(BossConfig.validate(zero, known)).is_empty()


# ---- Behaviour ----

func test_a_threshold_hit_staggers_the_boss_and_it_is_not_immune_while_staggered() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	var order: Array[String] = []
	boss.transition_started.connect(func(_i: int, total: float) -> void: order.append("transition_started %.2f" % total))
	boss.stagger_started.connect(func(_i: int, _d: float) -> void: order.append("stagger_started"))
	boss.stagger_ended.connect(func(_i: int) -> void: order.append("stagger_ended"))
	boss.transition_ended.connect(func(_i: int) -> void: order.append("transition_ended"))
	var max_hp: float = boss.health.max_health
	boss.health.take_damage(9999.0, "physical")
	assert_bool(boss.is_staggered()).is_true()
	assert_bool(boss.is_transitioning()).override_failure_message("is_transitioning is the roar only (ux: the bar shows Invulnerable for it)").is_false()
	assert_str(boss.state_name()).is_equal("STAGGER")
	assert_bool(boss.health.damage_immune).override_failure_message("immune during the stagger").is_false()
	assert_float(boss.health.current_health).is_equal_approx(max_hp * 0.66, 0.01)
	await _frames(_seconds_to_frames(_stagger() + 0.1))
	assert_bool(boss.is_staggered()).is_false()
	assert_bool(boss.is_transitioning()).is_true()
	assert_bool(boss.health.damage_immune).override_failure_message("the roar is immune").is_true()
	await _frames(_seconds_to_frames(_roar() + 0.1))
	assert_int(boss.phase_index).is_equal(1)
	assert_bool(boss.is_transitioning()).is_false()
	assert_array(order).is_equal(["stagger_started", "stagger_ended", "transition_started %.2f" % _roar(), "transition_ended"])


func test_stagger_interrupts_a_wound_up_attack_and_it_never_lands() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	boss.debug_script_attacks(["slam"] as Array[String])
	boss._attack_cooldown_remaining = 0.0
	boss.global_position = main.player.global_position + Vector3(0.0, 0.0, -4.0)
	var landed: Array[String] = []
	boss.attack_landed.connect(func(id: String, _hit: bool) -> void: landed.append(id))
	var ticks: int = 0
	while boss.state_name() != "WINDUP" and ticks < 400:
		await _frames(1)
		ticks += 1
	assert_str(boss.state_name()).override_failure_message("the boss never wound up").is_equal("WINDUP")
	await _frames(10)
	boss.health.take_damage(9999.0, "physical")
	assert_bool(boss.is_staggered()).is_true()
	assert_str(boss.current_attack_id()).override_failure_message("the attack was not dropped").is_equal("")
	await _frames(_seconds_to_frames(_stagger() + _roar() + 1.5))
	assert_bool(landed.has("slam") and landed.size() == 1 and boss.phase_index == 0).override_failure_message("the interrupted slam landed: %s" % str(landed)).is_false()
	assert_int(boss.phase_index).is_equal(1)


func test_player_damage_during_the_stagger_counts_and_is_not_eaten_by_the_floor() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	var max_hp: float = boss.health.max_health
	boss.health.take_damage(9999.0, "physical")  # held at the 66% floor, stagger begins
	var at_threshold: float = boss.health.current_health
	assert_float(at_threshold).is_equal_approx(max_hp * 0.66, 0.01)
	await _frames(10)
	boss.health.take_damage(10.0, "physical")
	assert_float(boss.health.current_health).override_failure_message("a hit during the stagger was eaten by the floor").is_equal_approx(at_threshold - 10.0, 0.01)
	assert_bool(boss.is_staggered()).override_failure_message("a hit must not restart or end the stagger").is_true()
	# During the roar the boss is immune again.
	await _frames(_seconds_to_frames(_stagger()))
	var before_roar_hit: float = boss.health.current_health
	boss.health.take_damage(10.0, "physical")
	assert_float(boss.health.current_health).is_equal(before_roar_hit)


func test_a_huge_hit_during_the_stagger_stops_at_the_next_threshold_and_starts_that_transition_after() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	var max_hp: float = boss.health.max_health
	boss.health.take_damage(9999.0, "physical")
	await _frames(5)
	boss.health.take_damage(9999.0, "physical")
	assert_float(boss.health.current_health).override_failure_message("held at the 33% floor").is_equal_approx(max_hp * 0.33, 0.01)
	assert_int(boss.phase_index).is_equal(0)
	await _frames(_seconds_to_frames(_stagger() + _roar() + 0.1))
	assert_int(boss.phase_index).is_equal(1)
	assert_bool(boss.is_staggered()).override_failure_message("the boss is already at the next threshold: it staggers again").is_true()
	await _frames(_seconds_to_frames(_stagger() + _roar() + 0.1))
	assert_int(boss.phase_index).is_equal(2)
	assert_bool(boss.is_transitioning()).is_false()
	assert_float(boss.health.hp_floor).is_equal(0.0)


func test_the_whole_transition_takes_stagger_plus_roar() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	boss.health.take_damage(9999.0, "physical")
	var frames: int = 0
	while (boss.is_staggered() or boss.is_transitioning()) and frames < 600:
		await _frames(1)
		frames += 1
	var seconds: float = float(frames) / float(Engine.physics_ticks_per_second)
	assert_float(seconds).is_equal_approx(_stagger() + _roar(), 0.1)
	assert_float(seconds).is_less_equal(float(BossConfig.get_config()["rules"]["max_transition"]) + 0.1)


func test_the_reel_is_visible_and_clears() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	boss.health.take_damage(9999.0, "physical")
	var deepest: float = 0.0
	for i in range(_seconds_to_frames(_stagger())):
		await _frames(1)
		deepest = minf(deepest, boss.body_mesh.rotation.x)
	assert_float(deepest).override_failure_message("no tilt during the stagger").is_less(-0.1)
	await _frames(3)
	assert_float(boss.body_mesh.rotation.x).is_equal(0.0)


func test_zero_stagger_goes_straight_to_the_roar() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	boss._def["transition"]["stagger"] = 0.0
	boss.health.take_damage(9999.0, "physical")
	assert_bool(boss.is_staggered()).is_false()
	assert_bool(boss.is_transitioning()).is_true()
	assert_bool(boss.health.damage_immune).is_true()


func test_dying_during_the_stagger_is_safe() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	boss.health.take_damage(9999.0, "physical")
	boss.debug_set_phase(2)  # last phase (floor 0) so the next hit can kill it
	boss._state = Boss.State.STAGGER
	boss._stagger_left = 5.0
	boss.health.take_damage(9999.0, "fire")
	assert_bool(boss.is_defeated()).is_true()
	await _frames(3)
	assert_float(boss.body_mesh.rotation.x).is_equal(0.0)
