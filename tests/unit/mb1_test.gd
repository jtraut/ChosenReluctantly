class_name Mb1Test
extends GdUnitTestSuite
## MB1 sitting A: the mini-boss marker in bosses.json, the act tint, the aoe `count` / `scatter` fields (hit once, threat functions,
## telegraph visuals, validator), the act 1 brute "Head of Facilities", its fairness numbers, the scenario, and that a mini-boss death
## ends the room and the act but never the run.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const BRUTE_PATH := "res://scenes/enemies/BossBrute.tscn"
const GUARDIAN_PATH := "res://scenes/enemies/BossGuardian.tscn"
const BRUTE_ID := "boss_brute"
const GUARDIAN_ID := "boss_guardian"
const SAVE_PATH := "user://tests/mb1_run_save.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = SAVE_PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	BossConfig.reset_cache()
	BossStagger.disable()
	Juice.hit_stop_enabled = false
	RelicDatabase.load_all()


func after_test() -> void:
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	Juice.hit_stop_enabled = true
	Juice.reset()
	Engine.time_scale = 1.0
	BossConfig.reset_cache()
	RunConfig.reset_cache()
	GamePause.reset()
	get_tree().paused = false


func _config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH)) as Dictionary


func _known() -> Array[String]:
	return EnemyConfig.enemy_ids()


func _mutated(mutator: Callable) -> Dictionary:
	var config: Dictionary = _config()
	mutator.call(config)
	return config


func _same(a: Color, b: Color) -> void:
	assert_bool(a.is_equal_approx(b)).override_failure_message("%s is not %s" % [str(a), str(b)]).is_true()


func _differs(a: Color, b: Color) -> void:
	assert_bool(a.is_equal_approx(b)).override_failure_message("%s should differ from %s" % [str(a), str(b)]).is_false()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _boss(main: Main, scene_path: String, distance: float = 8.0) -> Boss:
	var boss: Boss = (load(scene_path) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -distance)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.health.base_armor = 0.0
	return boss


## Starts a real wind-up of `attack_id` with the brain frozen, so the test controls the clock.
func _wind_up(boss: Boss, attack_id: String) -> void:
	boss.set_physics_process(false)
	boss._begin_windup(attack_id)


# ---- the mini-boss marker ----

func test_the_shipped_data_is_valid_and_the_brute_is_a_mini_boss() -> void:
	assert_array(BossConfig.validate(_config(), _known())).is_empty()
	assert_array(BossConfig.load_problems()).is_empty()
	assert_bool(BossConfig.has_boss(BRUTE_ID)).is_true()
	assert_bool(BossConfig.is_mini_boss(BRUTE_ID)).is_true()
	assert_bool(BossConfig.is_mini_boss(GUARDIAN_ID)).is_false()
	assert_str(EnemyConfig.rank_for(BRUTE_ID)).is_equal("elite")
	assert_str(EnemyConfig.scene_path_for(BRUTE_ID)).is_equal(BRUTE_PATH)
	assert_array(EnemyConfig.validate(JSON.parse_string(FileAccess.get_file_as_string(EnemyConfig.PATH)))).is_empty()


func test_the_marker_is_validated() -> void:
	var bad: Dictionary = _mutated(func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["mini_boss"] = "yes")
	assert_array(BossConfig.validate(bad, _known())).is_not_empty()
	var no_marker: Dictionary = _mutated(func(c: Dictionary) -> void: (c["bosses"][BRUTE_ID] as Dictionary).erase("mini_boss"))
	assert_array(BossConfig.validate(no_marker, _known())).is_empty()  # optional: absent means the final boss kind


func test_a_mini_boss_takes_its_own_tier_rank_and_death_beat_from_data() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH)
	var guardian := _boss(main, GUARDIAN_PATH, 12.0)
	await _frames(2)
	assert_bool(brute.is_mini_boss()).is_true()
	assert_str(brute.tier).is_equal("mini_boss")
	assert_str(brute.status_manager.rank).is_equal("elite")
	assert_bool(guardian.is_mini_boss()).is_false()
	assert_str(guardian.tier).is_equal("boss")
	assert_str(guardian.status_manager.rank).is_equal("boss")
	var death: Dictionary = BossConfig.boss(BRUTE_ID)["death"]
	assert_float(float(death["beat_seconds"])).is_equal(1.0)
	assert_float(float(BossConfig.boss(GUARDIAN_ID)["death"]["beat_seconds"])).is_equal(1.6)
	brute.health.take_damage(brute.health.max_health * 100.0, "physical")
	assert_float(brute._death_total).is_equal(0.0)  # held at the first threshold (a phase boss), not dead yet
	brute.debug_set_phase(2)
	brute.health.take_damage(brute.health.max_health * 100.0, "physical")
	await _frames(1)
	assert_bool(brute.is_defeated()).is_true()
	assert_float(brute._death_total).is_equal(1.0)


func test_a_stun_is_reduced_on_the_mini_boss_like_an_elite() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH)
	await _frames(1)
	assert_str(brute.status_manager.rank).is_equal("elite")


func test_final_hp_is_max_health_times_the_acts_hp_with_no_tier_on_top() -> void:
	var spawns: Array = ((RunConfig.variant_by_id(RunConfig.get_config(), "mini_boss", "mini_boss_act1")["stages"] as Array)[0] as Dictionary)["spawns"]
	assert_int(spawns.size()).is_equal(1)
	assert_str(String((spawns[0] as Dictionary)["enemy"])).is_equal(BRUTE_ID)
	assert_bool((spawns[0] as Dictionary).has("tier")).is_false()  # so tiers.mini_boss (x3.5) is not applied on top
	assert_bool(RunConfig.tier("mini_boss").is_empty()).is_false()  # kept for MAP4
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH)
	await _frames(1)
	var base: float = float(BossConfig.boss(BRUTE_ID)["max_health"])
	assert_float(brute.health.max_health).is_equal(base)
	brute.apply_act_scale(float(RunConfig.act_scale(2)["hp"]), 1.0)
	assert_float(brute.health.max_health).is_equal_approx(base * 1.1, 0.001)
	brute.apply_act_scale(float(RunConfig.act_scale(1)["hp"]), 1.0)  # act 1 is x1: 170 final
	assert_float(brute.health.max_health).is_equal_approx(base * 1.1, 0.001)  # (a scale of 1 changes nothing)


func test_the_act_one_mini_boss_room_has_no_second_stage_and_act_two_is_untouched() -> void:
	var config: Dictionary = RunConfig.get_config()
	var act1: Dictionary = RunConfig.variant_by_id(config, "mini_boss", "mini_boss_act1")
	assert_int((act1["stages"] as Array).size()).is_equal(1)
	var act2: Dictionary = RunConfig.variant_by_id(config, "mini_boss", "mini_boss_act2")
	assert_int((act2["stages"] as Array).size()).is_equal(2)
	assert_str(String((((act2["stages"] as Array)[0] as Dictionary)["spawns"] as Array)[0]["enemy"])).is_equal("fire_resistant_golem")


# ---- the brute's numbers (MAP.md 11.2) ----

func test_the_brute_matches_the_design_note() -> void:
	var def: Dictionary = BossConfig.boss(BRUTE_ID)
	assert_str(String(def["display_name"])).is_equal("Head of Facilities")
	assert_float(float(def["max_health"])).is_equal(170.0)
	assert_float(float(def["body_radius"])).is_equal(1.3)
	assert_float(float(def["knockback_taken"])).is_equal(0.0)
	assert_int(int(def["max_adds_alive"])).is_equal(3)
	var attacks: Dictionary = def["attacks"]
	assert_array(attacks.keys()).contains_exactly_in_any_order(["mop_sweep", "wet_floor", "forklift"])
	var sweep: Dictionary = attacks["mop_sweep"]
	assert_str(String(sweep["kind"])).is_equal("cone")
	assert_float(float(sweep["windup"])).is_equal(1.0)
	assert_float(float(sweep["damage"])).is_equal(7.0)
	assert_float(float(sweep["range"])).is_equal(3.6)
	assert_float(float(sweep["half_angle_degrees"])).is_equal(90.0)
	assert_float(float(sweep["knockback"])).is_equal(8.0)
	var wet: Dictionary = attacks["wet_floor"]
	assert_str(String(wet["kind"])).is_equal("aoe")
	assert_float(float(wet["windup"])).is_equal(1.1)
	assert_float(float(wet["damage"])).is_equal(6.0)
	assert_float(float(wet["radius"])).is_equal(2.0)
	assert_int(BossConfig.aoe_count(wet)).is_equal(3)
	assert_float(BossConfig.aoe_scatter(wet)).is_equal(3.0)
	assert_float(float(wet["knockback"])).is_equal(4.0)
	var fork: Dictionary = attacks["forklift"]
	assert_str(String(fork["kind"])).is_equal("charge")
	assert_float(float(fork["windup"])).is_equal(1.1)
	assert_float(float(fork["damage"])).is_equal(8.0)
	assert_float(float(fork["distance"])).is_equal(10.0)
	assert_float(float(fork["speed"])).is_equal(13.0)
	assert_float(float(fork["hit_radius"])).is_equal(1.3)
	assert_float(float(fork["knockback"])).is_equal(12.0)
	var phases: Array = def["phases"]
	assert_int(phases.size()).is_equal(3)
	assert_array(BossRules.thresholds(phases)).is_equal([0.6, 0.3])
	var speeds: Array = []
	var gaps: Array = []
	for phase: Dictionary in phases:
		speeds.append(float(phase["move_speed"]))
		gaps.append(float(phase["attack_gap"]))
	assert_array(speeds).is_equal([2.2, 2.5, 2.8])
	assert_array(gaps).is_equal([1.6, 1.3, 1.1])
	assert_float(float((phases[2] as Dictionary)["windup_scale"])).is_equal(0.9)
	assert_bool((phases[0] as Dictionary).has("summon")).is_false()
	for index in [1, 2]:
		var summon: Dictionary = (phases[index] as Dictionary)["summon"]
		assert_str(String(summon["enemy"])).is_equal("melee_chaser")
		assert_int(int(summon["count"])).is_equal(2)


func test_every_windup_times_the_phase_scale_is_at_least_the_minimum_telegraph() -> void:
	var minimum: float = float(BossConfig.rules()["min_telegraph"])
	assert_float(minimum).is_greater_equal(0.6)
	for boss_id: String in BossConfig.boss_ids():
		var def: Dictionary = BossConfig.boss(boss_id)
		for phase: Dictionary in def["phases"]:
			for entry: Dictionary in phase["attacks"]:
				var attack: Dictionary = (def["attacks"] as Dictionary)[String(entry["id"])]
				var effective: float = BossRules.windup(attack, phase)
				assert_float(effective).override_failure_message("%s %s in %s telegraphs %.2f s" % [boss_id, entry["id"], phase["name"], effective]).is_greater_equal(0.6 - 0.0001)


func test_the_brute_has_at_least_three_attacks_it_can_start_on_its_own() -> void:
	var def: Dictionary = BossConfig.boss(BRUTE_ID)
	var minimum: int = int(BossConfig.rules()["min_attacks"])
	assert_int(minimum).is_greater_equal(3)
	assert_int((def["attacks"] as Dictionary).size()).is_greater_equal(minimum)
	for phase: Dictionary in def["phases"]:
		var startable: Array[String] = []
		for distance in range(0, 19):
			for entry: Dictionary in BossRules.eligible(phase, def["attacks"], float(distance)):
				if not startable.has(String(entry["id"])):
					startable.append(String(entry["id"]))
		assert_int(startable.size()).override_failure_message("%s: only %s can start" % [phase["name"], str(startable)]).is_greater_equal(3)


func test_the_brute_is_slower_than_the_player_and_adds_stay_under_the_cap() -> void:
	var def: Dictionary = BossConfig.boss(BRUTE_ID)
	for phase: Dictionary in def["phases"]:
		assert_float(float(phase["move_speed"])).is_less(6.0)
	assert_int(int(def["max_adds_alive"])).is_less_equal(int(BossConfig.rules()["max_adds_cap"]))
	var max_alive: int = int(WaveConfig.get_config()["max_alive"])
	assert_int(1 + int(def["max_adds_alive"])).is_less_equal(max_alive / 2)


func test_the_brute_walks_the_whole_wet_floor_cast_out_before_it_lands() -> void:
	# Fairness by simulation, from every spot: the shortest way out of the union of all three discs, at walk speed, beats the
	# shortest wind-up the brute can have (phase 3, x0.9).
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH, 30.0)
	await _frames(1)
	brute.global_position = Vector3.ZERO
	var walk: float = main.player.move_speed
	var windup: float = BossRules.windup(BossConfig.boss(BRUTE_ID)["attacks"]["wet_floor"], (BossConfig.boss(BRUTE_ID)["phases"] as Array)[2])
	for seed_value in range(1, 7):
		brute._rng.seed = seed_value
		main.player.global_position = Vector3(float(seed_value) - 3.0, 0.0, -2.0 + float(seed_value % 3))
		_wind_up(brute, "wet_floor")
		var worst: float = 0.0
		for x in range(-24, 25):
			for z in range(-24, 25):
				var point := Vector3(float(x) * 0.4, 0.0, float(z) * 0.4)
				if not brute.in_threat(point):
					continue
				var dir: Vector3 = brute.escape_direction(point)
				var t: float = 0.0
				var probe: Vector3 = point
				while brute.in_threat(probe) and t < 5.0:
					t += 0.02
					probe = point + dir * walk * t
				worst = maxf(worst, t)
		assert_float(worst).override_failure_message("seed %d: worst escape %.2f s against a %.2f s telegraph" % [seed_value, worst, windup]).is_less(windup)
		brute._cancel_attack()


# ---- aoe count and scatter ----

func test_the_aoe_fields_are_validated() -> void:
	var cases: Dictionary = {
		"count above the cap": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["wet_floor"]["count"] = 7,
		"count zero": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["wet_floor"]["count"] = 0,
		"count fractional": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["wet_floor"]["count"] = 2.5,
		"count as text": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["wet_floor"]["count"] = "3",
		"scatter negative": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["wet_floor"]["scatter"] = -1.0,
		"scatter huge": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["wet_floor"]["scatter"] = 99.0,
		"several discs without scatter": func(c: Dictionary) -> void: (c["bosses"][BRUTE_ID]["attacks"]["wet_floor"] as Dictionary).erase("scatter"),
		"several discs on the boss itself": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["wet_floor"]["place"] = "self",
		"count on a cone": func(c: Dictionary) -> void: c["bosses"][BRUTE_ID]["attacks"]["mop_sweep"]["count"] = 2,
	}
	for label: String in cases.keys():
		assert_array(BossConfig.validate(_mutated(cases[label] as Callable), _known())).override_failure_message("accepted: " + label).is_not_empty()
	var single: Dictionary = _mutated(func(c: Dictionary) -> void:
		(c["bosses"][BRUTE_ID]["attacks"]["wet_floor"] as Dictionary).erase("count")
		(c["bosses"][BRUTE_ID]["attacks"]["wet_floor"] as Dictionary).erase("scatter"))
	assert_array(BossConfig.validate(single, _known())).is_empty()  # both optional: absent is today's single disc
	assert_int(BossConfig.aoe_count({})).is_equal(1)
	assert_float(BossConfig.aoe_scatter({})).is_equal(0.0)


func test_the_guardians_slam_is_still_one_disc() -> void:
	var slam: Dictionary = BossConfig.boss(GUARDIAN_ID)["attacks"]["slam"]
	assert_int(BossConfig.aoe_count(slam)).is_equal(1)


func test_aoe_centers_put_one_on_the_target_and_the_rest_within_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var first := Vector3(2.0, 0.0, -1.0)
	for round_index in range(40):
		var centers: Array[Vector3] = BossRules.aoe_centers(first, 3, 3.0, rng, 18.0)
		assert_int(centers.size()).is_equal(3)
		assert_vector(centers[0]).is_equal(first)
		for index in [1, 2]:
			var away: float = Vector2(centers[index].x - first.x, centers[index].z - first.z).length()
			assert_float(away).is_less_equal(3.0 + 0.0001)
			assert_float(away).is_greater_equal(3.0 * 0.35 - 0.0001)


func test_aoe_centers_stay_inside_the_arena_and_repeat_for_a_seed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a: Array[Vector3] = BossRules.aoe_centers(Vector3(17.5, 0.0, 17.5), 4, 3.0, rng, 18.0)
	for center: Vector3 in a:
		assert_float(absf(center.x)).is_less_equal(18.0)
		assert_float(absf(center.z)).is_less_equal(18.0)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	assert_array(BossRules.aoe_centers(Vector3(17.5, 0.0, 17.5), 4, 3.0, rng2, 18.0)).is_equal(a)


func test_a_single_disc_never_draws_from_the_random_stream() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var before: int = rng.state
	var centers: Array[Vector3] = BossRules.aoe_centers(Vector3(1.0, 0.0, 2.0), 1, 0.0, rng, 18.0)
	assert_int(centers.size()).is_equal(1)
	assert_int(rng.state).is_equal(before)  # so the guardian's slam keeps its seeded fights exactly


func test_disc_containing_finds_the_first_disc() -> void:
	var centers: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0)]
	assert_int(BossRules.disc_containing(centers, 2.0, Vector3(-1.0, 0.0, 0.0))).is_equal(0)
	assert_int(BossRules.disc_containing(centers, 2.0, Vector3(1.5, 0.0, 0.0))).is_equal(0)  # in both: the first
	assert_int(BossRules.disc_containing(centers, 2.0, Vector3(4.5, 0.0, 0.0))).is_equal(1)
	assert_int(BossRules.disc_containing(centers, 2.0, Vector3(9.0, 0.0, 0.0))).is_equal(-1)


func test_a_wet_floor_wind_up_telegraphs_every_disc_at_once_and_locks_them() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH, 8.0)
	main.player.global_position = Vector3(2.0, 0.0, 3.0)
	await _frames(1)
	_wind_up(brute, "wet_floor")
	assert_int(brute._aoe_locked.size()).is_equal(3)
	assert_vector(brute._aoe_locked[0]).is_equal(Vector3(2.0, 0.0, 3.0))  # one on the target
	var locked: Array[Vector3] = brute._aoe_locked.duplicate()
	var parts_now: int = brute._tele_parts.size()
	assert_int(parts_now).is_greater_equal(3)
	assert_int(parts_now % 3).is_equal(0)  # the same set of rings and discs for each of the three
	# The player walking away does not move the discs: they are locked for the whole wind-up.
	main.player.global_position = Vector3(-9.0, 0.0, 9.0)
	for step in range(5):
		brute._tick_windup(0.1)
	assert_array(brute._aoe_locked).is_equal(locked)
	assert_float(brute.telegraph_total()).is_equal(1.1)
	brute._cancel_attack()
	assert_int(brute._aoe_locked.size()).is_equal(0)
	assert_int(brute._tele_parts.size()).is_equal(0)


func test_the_discs_come_from_the_seeded_boss_stream() -> void:
	var main := _spawn_main()
	var first := _boss(main, BRUTE_PATH)
	var second := _boss(main, BRUTE_PATH, 9.0)
	await _frames(1)
	main.player.global_position = Vector3.ZERO
	first.set_seed(123)
	second.set_seed(123)
	_wind_up(first, "wet_floor")
	_wind_up(second, "wet_floor")
	assert_array(first._aoe_locked).is_equal(second._aoe_locked)
	first.set_seed(124)
	first._cancel_attack()
	_wind_up(first, "wet_floor")
	assert_array(first._aoe_locked).is_not_equal(second._aoe_locked)


func test_in_threat_is_the_union_of_the_discs_and_reach_covers_the_farthest() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH)
	await _frames(1)
	brute.global_position = Vector3(0.0, 0.0, -8.0)
	main.player.global_position = Vector3.ZERO
	brute.set_seed(31)
	_wind_up(brute, "wet_floor")
	var reach: float = BossRules.aoe_reach(brute._attack)
	for center: Vector3 in brute._aoe_locked:
		assert_bool(brute.in_threat(center)).is_true()
		assert_bool(brute.in_threat(center + Vector3(reach - 0.05, 0.0, 0.0))).is_true()
		assert_float(brute.threat_reach()).is_greater_equal(Vector2(center.x - brute.global_position.x, center.z - brute.global_position.z).length() + reach - 0.0001)
	assert_bool(brute.in_threat(Vector3(30.0, 0.0, 30.0))).is_false()
	# Nothing outside every disc is in threat; escape_direction is zero there and leaves the union from inside.
	var found: int = 0
	for x in range(-24, 25, 2):
		for z in range(-24, 25, 2):
			var point := Vector3(float(x) * 0.5, 0.0, float(z) * 0.5)
			if BossRules.disc_containing(brute._aoe_locked, reach, point) < 0:
				assert_bool(brute.in_threat(point)).is_false()
				assert_vector(brute.escape_direction(point)).is_equal(Vector3.ZERO)
				continue
			found += 1
			assert_bool(brute.in_threat(point)).is_true()
			var dir: Vector3 = brute.escape_direction(point)
			assert_float(dir.length()).is_equal_approx(1.0, 0.001)
			var out: bool = false
			for step in range(1, 61):
				if not brute.in_threat(point + dir * float(step) * 0.25):
					out = true
					break
			assert_bool(out).override_failure_message("no way out from %s" % str(point)).is_true()
	assert_int(found).is_greater(0)
	# The sim bot's dodge reads the state, not the kind: nothing is threatened once the attack is over.
	brute._cancel_attack()
	assert_bool(brute.in_threat(brute._lock_point)).is_false()
	assert_float(brute.threat_reach()).is_equal(0.0)


func test_the_fairness_formula_counts_the_scatter() -> void:
	var def: Dictionary = BossConfig.boss(BRUTE_ID)
	var wet: Dictionary = def["attacks"]["wet_floor"]
	var one_disc: Dictionary = wet.duplicate()
	one_disc.erase("count")
	one_disc.erase("scatter")
	var many: Dictionary = BossRules.escape(wet, 0.99, 6.0, 4.0, 1.0, 1.0)
	var single: Dictionary = BossRules.escape(one_disc, 0.99, 6.0, 4.0, 1.0, 1.0)
	assert_float(float(many["required"])).is_equal_approx(float(single["required"]) + 3.0, 0.0001)
	assert_bool(bool(many["ok"])).is_true()  # walking out still beats the shortest wind-up


func _player_health_after(main: Main, land: Callable) -> float:
	main.player.health.damage_immune = false
	main.player.health.current_health = main.player.health.max_health
	main.player._knockback_velocity = Vector3.ZERO
	await _frames(2)
	land.call()
	return main.player.health.current_health


func test_a_player_inside_two_overlapping_discs_is_hit_once_per_cast() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH)
	await _frames(1)
	main.player.global_position = Vector3.ZERO
	_wind_up(brute, "wet_floor")
	# Three discs, every one of them on the player.
	brute._aoe_locked = [Vector3.ZERO, Vector3(0.5, 0.0, 0.0), Vector3(-0.5, 0.0, 0.3)]
	var damage: float = float(brute._attack["damage"])
	main.player.health.base_armor = 0.0
	var hp_before: float = main.player.health.max_health
	var after: float = await _player_health_after(main, func() -> void: brute._land_attack())
	assert_float(hp_before - after).override_failure_message("took %.2f from one cast, one hit is %.2f" % [hp_before - after, damage]).is_equal_approx(damage, 0.01)


func test_a_player_in_only_one_disc_is_hit_and_one_in_none_is_not() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH)
	await _frames(1)
	main.player.global_position = Vector3(0.0, 0.0, 0.0)
	_wind_up(brute, "wet_floor")
	main.player.health.base_armor = 0.0
	var damage: float = float(brute._attack["damage"])
	var far := Vector3(10.0, 0.0, 10.0)
	brute._aoe_locked = [far, far + Vector3(2.0, 0.0, 0.0), Vector3(0.2, 0.0, 0.0)]  # the player stands in the third disc only
	var hp_before: float = main.player.health.max_health
	var after: float = await _player_health_after(main, func() -> void: brute._land_attack())
	assert_float(hp_before - after).is_equal_approx(damage, 0.01)
	brute._begin_windup("wet_floor")
	brute._aoe_locked = [far, far + Vector3(2.0, 0.0, 0.0), far + Vector3(-2.0, 0.0, 0.0)]
	var missed: float = await _player_health_after(main, func() -> void: brute._land_attack())
	assert_float(missed).is_equal(main.player.health.max_health)


func test_the_cast_clears_its_discs_and_recovers() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH)
	await _frames(1)
	main.player.global_position = Vector3.ZERO
	_wind_up(brute, "wet_floor")
	brute._land_attack()
	assert_int(brute._aoe_locked.size()).is_equal(0)
	assert_str(brute.state_name()).is_equal("RECOVER")


func test_the_scripted_brute_throws_each_of_its_attacks_and_survives_a_full_cycle() -> void:
	var main := _spawn_main()
	var brute := _boss(main, BRUTE_PATH, 3.0)
	main.player.health.damage_immune = true
	await _frames(1)
	var ids: Array[String] = ["mop_sweep", "wet_floor", "forklift"]
	brute.debug_script_attacks(ids)
	brute._attack_cooldown_remaining = 0.0
	var landed: Array[String] = []
	brute.attack_landed.connect(func(attack_id: String, _hit: bool) -> void: landed.append(attack_id))
	var done: bool = false
	for frame in range(60 * 14):
		await get_tree().physics_frame
		if landed.size() >= 3:
			done = true
			break
	assert_bool(done).override_failure_message("landed only %s" % str(landed)).is_true()
	assert_array(landed).contains_exactly_in_any_order(ids)


# ---- a mini-boss death ends the room, never the run ----

func _spawn_run() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func test_killing_the_mini_boss_ends_the_room_and_opens_the_act_end_choices_but_not_the_run() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(9)  # act 1's mini-boss
	var main: Main = _spawn_run()
	await _frames(3)
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("mini_boss")
	var won: Array[bool] = [false]
	controller.run_won.connect(func() -> void: won[0] = true)
	var cleared: Array[bool] = [false]
	controller.choice_requested.connect(func(_model: Dictionary) -> void: cleared[0] = true)
	main.enemy_spawner._process(3.0)  # past the first wave delay: the brute spawns
	var brute: Boss = null
	for child in main.get_children():
		if child is Boss:
			brute = child as Boss
	assert_object(brute).is_not_null()
	assert_str(brute.enemy_id).is_equal(BRUTE_ID)
	assert_bool(brute.is_mini_boss()).is_true()
	assert_float(brute.health.max_health).is_equal_approx(170.0 * float(RunConfig.act_scale(1)["hp"]), 0.001)
	brute.debug_set_phase(2)
	brute.health.take_damage(brute.health.max_health * 100.0, "physical")
	assert_bool(brute.is_defeated()).is_true()
	var waited: int = 0
	while is_instance_valid(brute) and waited < 60 * 6:  # the 1.0 s death beat, then the body goes
		await get_tree().physics_frame
		waited += 1
	await _frames(4)
	assert_bool(cleared[0]).override_failure_message("the room did not end").is_true()
	assert_bool(won[0]).override_failure_message("a mini-boss death won the run").is_false()
	assert_str(state.outcome).is_not_equal("won")
	assert_int(state.act).is_equal(1)
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)  # the mini-boss reward, as MAP3 pays it
	# Finishing the choices opens act 2: the act ended, the run did not.
	var seen_acts: Array[int] = []
	controller.act_started.connect(func(act_number: int, _summary: Dictionary) -> void: seen_acts.append(act_number))
	controller.pick_relic(state.offer[0])
	controller.choose("skip")
	assert_array(seen_acts).is_equal([2])
	assert_bool(won[0]).is_false()


func test_the_final_boss_room_still_wins_the_run_by_node_type() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(33)
	state.jump_to_room(29)
	var main: Main = _spawn_run()
	await _frames(3)
	var won: Array[bool] = [false]
	main.run_controller.run_won.connect(func() -> void: won[0] = true)
	main.run_controller._finish_room(0.0)
	assert_bool(won[0]).is_true()


# ---- act tint ----

func test_the_shipped_tints_validate_and_read_back_per_act() -> void:
	assert_array(RunConfig.validate(RunConfig.get_config(), _known(), [])).is_empty()
	for act_number in [1, 2, 3]:
		var tint: Dictionary = RunConfig.act_tint(act_number)
		assert_bool(tint.has("floor") and tint.has("light")).override_failure_message("act %d has no tint" % act_number).is_true()
	assert_dict(RunConfig.act_tint(9)).is_empty()
	# Act 2 is cooler (more blue than red), act 3 warmer (more red than blue) than act 1.
	var a1: Color = RunConfig.act_tint(1)["floor"]
	var a2: Color = RunConfig.act_tint(2)["floor"]
	var a3: Color = RunConfig.act_tint(3)["floor"]
	assert_float(a2.b - a2.r).is_greater(a1.b - a1.r)
	assert_float(a3.r - a3.b).is_greater(a1.r - a1.b)
	# Readability: a subtle shift. No act's floor strays far from act 1's, and the light stays bright.
	for other: Color in [a2, a3]:
		assert_float(absf(other.get_luminance() - a1.get_luminance())).is_less(0.12)
	for act_number in [1, 2, 3]:
		assert_float((RunConfig.act_tint(act_number)["light"] as Color).get_luminance()).is_greater(0.8)


func test_act_one_is_todays_look() -> void:
	var main := _spawn_main()
	var scene_floor: Color = ((main.get_node("Floor") as CSGBox3D).material as StandardMaterial3D).albedo_color
	var tint: Color = RunConfig.act_tint(1)["floor"]
	assert_float(absf(scene_floor.r - tint.r) + absf(scene_floor.g - tint.g) + absf(scene_floor.b - tint.b)).is_less(0.02)
	_same((main.get_node("Sun") as DirectionalLight3D).light_color, Color.WHITE)
	_same(RunConfig.act_tint(1)["light"], Color.WHITE)


func test_the_tint_is_validated() -> void:
	var cases: Dictionary = {
		"tint is not an object": func(c: Dictionary) -> void: c["acts"]["2"]["tint"] = "#ffffff",
		"floor missing": func(c: Dictionary) -> void: (c["acts"]["2"]["tint"] as Dictionary).erase("floor"),
		"light missing": func(c: Dictionary) -> void: (c["acts"]["2"]["tint"] as Dictionary).erase("light"),
		"floor is not a colour": func(c: Dictionary) -> void: c["acts"]["2"]["tint"]["floor"] = "blue-grey",
		"light is a number": func(c: Dictionary) -> void: c["acts"]["3"]["tint"]["light"] = 5,
		"unknown tint key": func(c: Dictionary) -> void: c["acts"]["3"]["tint"]["fog"] = "#ffffff",
	}
	for label: String in cases.keys():
		var config: Dictionary = RunConfig.get_config().duplicate(true)
		(cases[label] as Callable).call(config)
		assert_array(RunConfig.validate(config, _known(), [])).override_failure_message("accepted: " + label).is_not_empty()
	var without: Dictionary = RunConfig.get_config().duplicate(true)
	(without["acts"]["2"] as Dictionary).erase("tint")
	assert_array(RunConfig.validate(without, _known(), [])).is_empty()  # optional per act
	assert_dict(RunConfig.act_scale(2)).contains_keys(["hp", "damage", "gold"])


func test_apply_tints_the_floor_and_sun_without_leaking_into_the_next_arena() -> void:
	var main := _spawn_main()
	assert_bool(ActTint.apply(main, 3)).is_true()
	var want: Dictionary = RunConfig.act_tint(3)
	_same(((main.get_node("Floor") as CSGBox3D).material as StandardMaterial3D).albedo_color, want["floor"])
	_same((main.get_node("Sun") as DirectionalLight3D).light_color, want["light"])
	var next := _spawn_main()  # a fresh arena of the same scene still starts as the scene made it
	var fresh: Color = ((next.get_node("Floor") as CSGBox3D).material as StandardMaterial3D).albedo_color
	_differs(fresh, want["floor"])


func test_apply_is_loud_about_a_world_without_a_floor_or_sun() -> void:
	var bare := Node3D.new()
	add_child(bare)
	auto_free(bare)
	assert_bool(ActTint.apply(bare, 2)).is_false()
	assert_bool(ActTint.apply(bare, 9)).is_true()  # an act with no tint asks nothing of the world


func test_a_run_room_loads_with_its_acts_tint() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(9)
	var main: Main = _spawn_run()
	await _frames(3)
	_same(((main.get_node("Floor") as CSGBox3D).material as StandardMaterial3D).albedo_color, RunConfig.act_tint(1)["floor"])
	state.jump_to_room(19)
	var act2: Main = _spawn_run()
	await _frames(3)
	assert_int(act2.run_controller.current_act()).is_equal(2)
	_same(((act2.get_node("Floor") as CSGBox3D).material as StandardMaterial3D).albedo_color, RunConfig.act_tint(2)["floor"])
	_same((act2.get_node("Sun") as DirectionalLight3D).light_color, RunConfig.act_tint(2)["light"])


# ---- the scenario ----

func test_the_mini_boss_act1_scenario_is_valid_and_builds_the_room() -> void:
	assert_bool(Scenario.has_scenario("mini_boss_act1")).is_true()
	assert_array(ScenarioSchema.validate("mini_boss_act1", Scenario.raw_def("mini_boss_act1"))).is_empty()
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	var scenario: Scenario = Scenario.setup(main, "mini_boss_act1")
	assert_object(scenario).is_not_null()
	await _frames(2)
	var found: Array[Enemy] = scenario.enemies()
	assert_int(found.size()).is_equal(1)
	assert_bool(found[0] is Boss and (found[0] as Boss).is_mini_boss()).is_true()
	assert_float(found[0].health.max_health).is_equal(170.0)
	assert_float(main.player.health.get_max_health()).is_equal(CharacterDatabase.max_hp("rogue"))
	assert_float(main.player.health.current_health).is_equal(main.player.health.get_max_health())
	assert_int(main.player.card_slots.owned_card_ids().size()).is_equal(CharacterDatabase.starting_deck("rogue").size())


func test_the_scenario_schema_rejects_bad_new_flags() -> void:
	assert_array(ScenarioSchema.validate("x", {"act": 0})).is_not_empty()
	assert_array(ScenarioSchema.validate("x", {"natural_hp": "yes"})).is_not_empty()
	assert_array(ScenarioSchema.validate("x", {"standard_deck": 1})).is_not_empty()
