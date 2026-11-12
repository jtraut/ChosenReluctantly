class_name Mb1bTest
extends GdUnitTestSuite
## MB1 sitting B: the boss attack `chain` field (validator, timing, drops), the `blink` attack kind (landing marker, clamp, never on the
## player, threat functions), the act 2 duelist "The Corporate Raider" (numbers from MAP.md 11.3, damage totals, fairness walk-out),
## `rooms.mini_boss_act2`, the scenarios, and that an act 2 mini-boss death ends the act and never the run.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const DUELIST_PATH := "res://scenes/enemies/BossDuelist.tscn"
const DUELIST_ID := "boss_duelist"
const SAVE_PATH := "user://tests/mb1b_run_save.json"
const STEP := 1.0 / 60.0


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


func _errors(config: Dictionary) -> Array[String]:
	return BossConfig.validate(config, _known())


func _duelist_def(config: Dictionary) -> Dictionary:
	return (config["bosses"] as Dictionary)[DUELIST_ID]


func _has_error(errors: Array[String], needle: String) -> bool:
	for line: String in errors:
		if line.contains(needle):
			return true
	return false


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


func _duelist(main: Main, distance: float = 6.0) -> Boss:
	var boss: Boss = (load(DUELIST_PATH) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -distance)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.health.base_armor = 0.0
	return boss


## A duelist with its brain frozen, so a test steps the clock itself with `_tick`.
func _frozen(main: Main, distance: float = 6.0) -> Boss:
	var boss: Boss = _duelist(main, distance)
	boss.set_physics_process(false)
	return boss


## One fixed physics step of the boss's own brain.
func _tick(boss: Boss, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var dt: float = minf(STEP, left)
		boss._physics_process(dt)
		left -= dt


# ---- the chain validator ----

func test_the_shipped_data_with_the_duelist_is_valid() -> void:
	assert_array(BossConfig.load_problems()).is_empty()
	assert_array(_errors(_config())).is_empty()
	assert_bool(BossConfig.is_mini_boss(DUELIST_ID)).is_true()
	assert_str(BossConfig.chain_of(BossConfig.boss(DUELIST_ID)["attacks"]["leveraged_dash"])).is_equal("leveraged_dash_2")
	assert_str(BossConfig.chain_of(BossConfig.boss(DUELIST_ID)["attacks"]["golden_parachute"])).is_equal("backstab")
	assert_str(BossConfig.chain_of(BossConfig.boss(DUELIST_ID)["attacks"]["hostile_takeover"])).is_equal("")


func test_a_chain_to_an_unknown_attack_is_refused() -> void:
	var config: Dictionary = _config()
	_duelist_def(config)["attacks"]["hostile_takeover"]["chain"] = "nope"
	assert_bool(_has_error(_errors(config), "unknown attack id 'nope'")).is_true()


func test_a_chain_must_be_a_non_empty_string() -> void:
	var config: Dictionary = _config()
	_duelist_def(config)["attacks"]["hostile_takeover"]["chain"] = 7
	assert_bool(_has_error(_errors(config), "chain must be an attack id")).is_true()
	config = _config()
	_duelist_def(config)["attacks"]["hostile_takeover"]["chain"] = ""
	assert_bool(_has_error(_errors(config), "chain must be an attack id")).is_true()


func test_a_chain_that_loops_is_refused() -> void:
	# a -> b -> a
	var config: Dictionary = _config()
	_duelist_def(config)["attacks"]["leveraged_dash_2"]["chain"] = "leveraged_dash"
	assert_bool(_has_error(_errors(config), "no cycles")).is_true()
	# a -> a
	config = _config()
	_duelist_def(config)["attacks"]["hostile_takeover"]["chain"] = "hostile_takeover"
	assert_bool(_has_error(_errors(config), "no cycles")).is_true()


func test_a_chain_longer_than_two_attacks_is_refused() -> void:
	var config: Dictionary = _config()
	_duelist_def(config)["attacks"]["leveraged_dash_2"]["chain"] = "backstab"  # dash -> dash_2 -> backstab: three attacks
	var errors: Array[String] = _errors(config)
	assert_bool(_has_error(errors, "3 attacks long (at most 2)")).is_true()
	assert_bool(_has_error(errors, "no cycles")).is_false()


func test_a_chained_attack_may_not_hold_a_phase_weight() -> void:
	var config: Dictionary = _config()
	var phase: Dictionary = (_duelist_def(config)["phases"] as Array)[0]
	(phase["attacks"] as Array).append({"id": "backstab", "weight": 1})
	assert_bool(_has_error(_errors(config), "'backstab' is chained from another attack, so it has no phase weight")).is_true()
	# A weight of 0 is no weight.
	config = _config()
	phase = (_duelist_def(config)["phases"] as Array)[0]
	(phase["attacks"] as Array).append({"id": "backstab", "weight": 0})
	assert_array(_errors(config)).is_empty()


func test_every_link_of_a_chain_keeps_the_minimum_telegraph_after_the_phase_scale() -> void:
	var config: Dictionary = _config()
	var def: Dictionary = _duelist_def(config)
	# The chain-only attacks are not in any phase list, so the plain per-phase check never sees them: a scale under 1 must still be caught.
	(def["phases"] as Array)[1]["windup_scale"] = 0.9
	for attack_id: String in ["hostile_takeover", "leveraged_dash", "golden_parachute"]:
		(def["attacks"] as Dictionary)[attack_id]["windup"] = 1.0  # the weighted attacks are fine at x0.9
	var errors: Array[String] = _errors(config)
	assert_bool(_has_error(errors, "chained attack 'leveraged_dash_2'")).is_true()
	assert_bool(_has_error(errors, "chained attack 'backstab'")).is_true()
	assert_bool(_has_error(errors, "under the 0.60 s minimum")).is_true()
	# Phase 0 (scale 1.0) stays fine: the error names phase 1 only.
	assert_bool(_has_error(errors, "phases[0]: chained")).is_false()


func test_a_chain_link_is_only_checked_in_the_phases_that_can_start_it() -> void:
	var config: Dictionary = _config()
	var def: Dictionary = _duelist_def(config)
	(def["phases"] as Array)[1]["windup_scale"] = 0.9
	for attack_id: String in ["hostile_takeover", "leveraged_dash"]:
		(def["attacks"] as Dictionary)[attack_id]["windup"] = 1.0
	# Phase 1 no longer picks the dash or the parachute: nothing chains there, so a short link is not reachable.
	(def["phases"] as Array)[1]["attacks"] = [{"id": "hostile_takeover", "weight": 1}, {"id": "hostile_takeover", "weight": 1}, {"id": "hostile_takeover", "weight": 1}]
	var errors: Array[String] = _errors(config)
	assert_bool(_has_error(errors, "phases[1]: chained")).is_false()


func test_only_attacks_a_phase_can_pick_count_towards_the_minimum_attack_count() -> void:
	var def: Dictionary = BossConfig.boss(DUELIST_ID)
	assert_int((def["attacks"] as Dictionary).size()).is_equal(5)
	assert_int(BossConfig.weighted_attack_ids(def).size()).is_equal(3)
	var config: Dictionary = _config()
	# Take the parachute out of both phases: five attacks in the table, only two of them startable.
	for phase: Dictionary in _duelist_def(config)["phases"]:
		var kept: Array = []
		for entry: Dictionary in phase["attacks"]:
			if String(entry["id"]) != "golden_parachute":
				kept.append(entry)
		phase["attacks"] = kept
	var errors: Array[String] = _errors(config)
	assert_bool(_has_error(errors, "needs at least 3 attacks it can start (it has 2")).is_true()
	# A weight of 0 does not count either.
	config = _config()
	for phase: Dictionary in _duelist_def(config)["phases"]:
		for entry: Dictionary in phase["attacks"]:
			if String(entry["id"]) == "golden_parachute":
				entry["weight"] = 0
	assert_bool(_has_error(_errors(config), "needs at least 3 attacks it can start")).is_true()


func test_the_blink_kind_is_validated() -> void:
	var config: Dictionary = _config()
	_duelist_def(config)["attacks"]["golden_parachute"]["damage"] = 3.0
	assert_bool(_has_error(_errors(config), "damage must be 0 for a blink")).is_true()
	config = _config()
	_duelist_def(config)["attacks"]["golden_parachute"]["knockback"] = 2.0
	assert_bool(_has_error(_errors(config), "knockback must be 0 for a blink")).is_true()
	config = _config()
	(_duelist_def(config)["attacks"]["golden_parachute"] as Dictionary).erase("behind")
	assert_bool(_has_error(_errors(config), "behind must be a number")).is_true()
	config = _config()
	_duelist_def(config)["attacks"]["golden_parachute"]["behind"] = 40.0
	assert_bool(_has_error(_errors(config), "behind must be between")).is_true()
	config = _config()
	_duelist_def(config)["attacks"]["golden_parachute"]["radius"] = 2.0
	assert_bool(_has_error(_errors(config), "unknown key 'radius' for a blink attack")).is_true()


# ---- the blink landing (pure) ----

func test_blink_lands_behind_the_player_on_the_far_side_from_the_boss() -> void:
	var spot: Vector3 = BossRules.blink_landing(Vector3(0.0, 0.0, -6.0), Vector3(0.0, 0.0, 0.0), 1.8, 18.0)
	assert_vector(spot).is_equal_approx(Vector3(0.0, 0.0, 1.8), Vector3(0.001, 0.001, 0.001))
	spot = BossRules.blink_landing(Vector3(-5.0, 0.0, 0.0), Vector3(3.0, 0.0, 4.0), 1.8, 18.0)
	var out_dir: Vector3 = (Vector3(3.0, 0.0, 4.0) - Vector3(-5.0, 0.0, 0.0)).normalized()
	assert_vector(spot).is_equal_approx(Vector3(3.0, 0.0, 4.0) + out_dir * 1.8, Vector3(0.001, 0.001, 0.001))


func test_blink_never_lands_outside_the_arena_or_on_the_player() -> void:
	var limit: float = 18.0
	var worst_gap: float = 99.0
	for bx in range(-18, 19, 6):
		for bz in range(-18, 19, 6):
			for px in range(-19, 20, 3):
				for pz in range(-19, 20, 3):
					var boss_pos := Vector3(float(bx), 0.0, float(bz))
					var player_pos := Vector3(float(px), 0.0, float(pz))
					if boss_pos.distance_to(player_pos) < 0.5:
						continue
					var spot: Vector3 = BossRules.blink_landing(boss_pos, player_pos, 1.8, limit)
					assert_bool(absf(spot.x) <= limit + 0.0001 and absf(spot.z) <= limit + 0.0001).override_failure_message("boss %s player %s landed at %s, outside the arena" % [str(boss_pos), str(player_pos), str(spot)]).is_true()
					var gap: float = Vector2(spot.x - player_pos.x, spot.z - player_pos.z).length()
					worst_gap = minf(worst_gap, gap)
					assert_bool(gap >= BossRules.BLINK_MIN_GAP - 0.0001).override_failure_message("boss %s player %s landed at %s, %.2f m from the player" % [str(boss_pos), str(player_pos), str(spot), gap]).is_true()
	assert_float(worst_gap).is_greater_equal(BossRules.BLINK_MIN_GAP - 0.0001)


func test_blink_against_a_wall_moves_toward_the_boss_instead() -> void:
	# The player stands against the east wall with the boss to the west: "behind" would be inside the wall.
	var spot: Vector3 = BossRules.blink_landing(Vector3(5.0, 0.0, 0.0), Vector3(18.0, 0.0, 0.0), 1.8, 18.0)
	assert_float(spot.x).is_less(18.0 - BossRules.BLINK_MIN_GAP + 0.001)  # on the boss's side
	assert_float(spot.x).is_greater(5.0)
	# A little room behind the player: the landing is clamped to the wall but still on the far side when it clears them.
	var near: Vector3 = BossRules.blink_landing(Vector3(5.0, 0.0, 0.0), Vector3(16.5, 0.0, 0.0), 1.8, 18.0)
	assert_float(near.x).is_equal_approx(18.0, 0.001)
	assert_float(near.x - 16.5).is_greater_equal(BossRules.BLINK_MIN_GAP)


func test_blink_marker_radius_is_bigger_than_the_body() -> void:
	assert_float(BossRules.blink_marker_radius(0.55)).is_greater(0.55)


# ---- chain timing ----

func test_a_chained_attack_starts_its_own_full_windup_the_moment_recovery_ends_with_no_gap() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	main.player.health.damage_immune = true
	var boss := _frozen(main, 6.0)
	await _frames(1)
	boss.debug_script_attacks(["leveraged_dash"] as Array[String])
	boss._attack_cooldown_remaining = 0.0
	var windups: Array[Dictionary] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, seconds: float) -> void: windups.append({"id": attack_id, "seconds": seconds}))
	var chase_between: bool = false
	var elapsed: float = 0.0
	var first_at: float = -1.0
	var second_at: float = -1.0
	var recovered_at: float = -1.0
	var phase_gap: float = float(((BossConfig.boss(DUELIST_ID)["phases"] as Array)[0] as Dictionary)["attack_gap"])
	for tick in range(60 * 6):
		boss._physics_process(STEP)
		elapsed += STEP
		if windups.size() == 1 and first_at < 0.0:
			first_at = elapsed
		if windups.size() >= 1 and second_at < 0.0 and boss.state_name() == "RECOVER":
			recovered_at = elapsed
		if windups.size() >= 1 and second_at < 0.0 and boss.state_name() == "CHASE":
			chase_between = true
		if windups.size() == 2:
			second_at = elapsed
			break
	assert_int(windups.size()).is_equal(2)
	assert_bool(chase_between).override_failure_message("the boss went back to chasing between the two links").is_false()
	assert_str(String(windups[0]["id"])).is_equal("leveraged_dash")
	assert_str(String(windups[1]["id"])).is_equal("leveraged_dash_2")
	# Each link has its own full wind-up: the second is not shortened by the first.
	assert_float(float(windups[0]["seconds"])).is_equal_approx(0.7, 0.0001)
	assert_float(float(windups[1]["seconds"])).is_equal_approx(0.6, 0.0001)
	# Time from the first telegraph to the second: wind-up 0.7 + the run + recover 0.3, never plus the 1.2 s attack gap.
	var run_time: float = 6.0 / 18.0
	var expected: float = 0.7 + run_time + 0.3
	assert_float(second_at - first_at).override_failure_message("links were %.2f s apart (expected about %.2f s)" % [second_at - first_at, expected]).is_less(expected + 0.25)
	assert_float(second_at - first_at).is_less(expected + phase_gap - 0.1)
	assert_bool(recovered_at > 0.0).is_true()


func test_the_second_link_is_re_aimed_at_where_the_player_is_when_it_starts() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	main.player.health.damage_immune = true
	var boss := _frozen(main, 6.0)
	await _frames(1)
	boss.debug_script_attacks(["leveraged_dash"] as Array[String])
	boss._attack_cooldown_remaining = 0.0
	var started: Array[String] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, _seconds: float) -> void: started.append(attack_id))
	var first_dir: Vector3 = Vector3.ZERO
	var moved: bool = false
	for tick in range(60 * 6):
		boss._physics_process(STEP)
		if started.size() == 1 and first_dir == Vector3.ZERO:
			first_dir = boss._lock_dir
		if started.size() == 1 and boss.state_name() == "RECOVER" and not moved:
			main.player.global_position = Vector3(boss.global_position.x + 4.0, 0.0, boss.global_position.z + 0.5)  # off to the side
			moved = true
		if started.size() == 2:
			break
	assert_int(started.size()).is_equal(2)
	var to_player: Vector3 = main.player.global_position - boss.global_position
	to_player.y = 0.0
	assert_float(boss._lock_dir.dot(to_player.normalized())).override_failure_message("the second dash was not re-aimed").is_greater(0.99)
	assert_float(boss._lock_dir.dot(first_dir)).is_less(0.5)  # and it is not the first dash's lane


func _chain_scene(first: String) -> Dictionary:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	main.player.health.damage_immune = true
	var boss := _frozen(main, 5.0)
	boss.debug_script_attacks([first] as Array[String])
	boss._attack_cooldown_remaining = 0.0
	return {"main": main, "boss": boss}


## Steps `boss` until it is in RECOVER of the first link of a chain (or gives up).
func _until_recover(boss: Boss) -> bool:
	for tick in range(60 * 5):
		boss._physics_process(STEP)
		if boss.state_name() == "RECOVER":
			return true
	return false


func test_a_stun_in_the_middle_of_a_chain_drops_the_rest_of_it() -> void:
	var scene: Dictionary = _chain_scene("golden_parachute")
	var boss: Boss = scene["boss"]
	await _frames(1)
	var started: Array[String] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, _seconds: float) -> void: started.append(attack_id))
	assert_bool(_until_recover(boss)).is_true()  # the blink has landed; the backstab is next
	boss.status_manager.apply_status("stun", (StatusDatabase.get_status("stun") as Dictionary).duplicate(true), 5.0)
	assert_bool(boss.is_stunned()).is_true()
	for tick in range(60 * 3):
		boss._physics_process(STEP)
	assert_array(started).is_equal(["golden_parachute"])  # the backstab never started
	assert_bool(boss.state_name() == "WINDUP").is_false()


func test_a_phase_transition_in_the_middle_of_a_chain_drops_the_rest_of_it() -> void:
	var scene: Dictionary = _chain_scene("leveraged_dash")
	var boss: Boss = scene["boss"]
	await _frames(1)
	var started: Array[String] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, _seconds: float) -> void: started.append(attack_id))
	assert_bool(_until_recover(boss)).is_true()
	boss.debug_script_attacks([] as Array[String])
	boss.health.take_damage(boss.health.current_health - boss.health.hp_floor, "physical")  # to the phase threshold
	assert_bool(boss.state_name() == "STAGGER" or boss.state_name() == "TRANSITION").override_failure_message("state %s" % boss.state_name()).is_true()
	for tick in range(60 * 3):
		boss._physics_process(STEP)
	assert_bool(started.has("leveraged_dash_2")).override_failure_message("the dash's second link started after a phase change").is_false()


func test_death_in_the_middle_of_a_chain_drops_the_rest_of_it() -> void:
	var scene: Dictionary = _chain_scene("leveraged_dash")
	var boss: Boss = scene["boss"]
	await _frames(1)
	var started: Array[String] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, _seconds: float) -> void: started.append(attack_id))
	assert_bool(_until_recover(boss)).is_true()
	boss.debug_set_phase(1)
	boss.health.take_damage(boss.health.max_health * 100.0, "physical")
	assert_bool(boss.is_defeated()).is_true()
	for tick in range(30):
		boss._physics_process(STEP)
	assert_array(started).is_equal(["leveraged_dash"])


# ---- blink in the scene ----

func test_the_blink_marker_is_locked_at_wind_up_start_and_shown_the_whole_wind_up() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3(2.0, 0.0, 0.0)
	var boss := _frozen(main, 6.0)
	await _frames(1)
	boss._begin_windup("golden_parachute")
	assert_float(boss.telegraph_total()).is_equal_approx(0.7, 0.0001)
	var expected: Vector3 = BossRules.blink_landing(boss.global_position, Vector3(2.0, 0.0, 0.0), 1.8, Boss.ARENA_LIMIT)
	assert_vector(boss.blink_target()).is_equal_approx(expected, Vector3(0.001, 0.001, 0.001))
	# 1.8 m past the player, on the far side from the boss (the boss stands north of the player, so behind is south).
	assert_float(boss.blink_target().z).is_greater(1.7)
	assert_int(boss._tele_parts.size()).is_greater_equal(3)
	var locked: Vector3 = boss.blink_target()
	# The player runs off: the marker does not follow.
	main.player.global_position = Vector3(-8.0, 0.0, 6.0)
	for step in range(30):
		boss._tick_windup(0.02)  # 0.6 of the 0.7 s
		assert_vector(boss.blink_target()).is_equal(locked)
		# The marker parts are still running on every frame of the wind-up.
		for index in range(boss._tele_parts.size()):
			assert_bool(boss._tele_pool.is_running(boss._tele_parts[index], boss._tele_gens[index])).override_failure_message("marker part %d stopped at step %d" % [index, step]).is_true()
	assert_str(boss.state_name()).is_equal("WINDUP")
	boss._cancel_attack()
	assert_int(boss._tele_parts.size()).is_equal(0)  # cancelled: no marker left on the floor
	assert_vector(boss.blink_target()).is_equal(Vector3(boss.global_position.x, 0.0, boss.global_position.z))


func test_the_blink_teleports_to_the_marker_hurts_nobody_and_hands_on_to_the_backstab() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3(0.0, 0.0, 0.0)
	main.player.health.base_armor = 0.0
	var boss := _frozen(main, 6.0)
	await _frames(1)
	boss.debug_script_attacks(["golden_parachute"] as Array[String])
	boss._attack_cooldown_remaining = 0.0
	var hp: float = main.player.health.current_health
	var started: Array[Dictionary] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, seconds: float) -> void: started.append({"id": attack_id, "seconds": seconds}))
	var landed: Array[Dictionary] = []
	boss.attack_landed.connect(func(attack_id: String, hit: bool) -> void: landed.append({"id": attack_id, "hit": hit}))
	for tick in range(5):
		boss._physics_process(STEP)
	assert_str(boss.state_name()).is_equal("WINDUP")
	var marker: Vector3 = boss.blink_target()
	# Nothing the blink does is a threat, anywhere, at any time.
	assert_float(boss.threat_reach()).is_equal(0.0)
	for x in range(-10, 11):
		for z in range(-10, 11):
			var point := Vector3(float(x), 0.0, float(z))
			assert_bool(boss.in_threat(point)).is_false()
			assert_vector(boss.escape_direction(point)).is_equal(Vector3.ZERO)
	# The player steps off (out of the marker) and the wind-up runs out.
	main.player.global_position = Vector3(-5.0, 0.0, 0.0)
	_tick(boss, 0.75)
	assert_vector(Vector3(boss.global_position.x, 0.0, boss.global_position.z)).is_equal_approx(marker, Vector3(0.01, 0.01, 0.01))
	assert_float(main.player.health.current_health).is_equal(hp)
	assert_bool(bool(landed[0]["hit"])).is_false()
	assert_str(String(landed[0]["id"])).is_equal("golden_parachute")
	assert_str(boss.state_name()).is_equal("RECOVER")
	# Recovery over: the backstab's own full wind-up starts, aimed at the player.
	_tick(boss, 0.2)
	assert_str(boss.state_name()).is_equal("WINDUP")
	assert_int(started.size()).is_equal(2)
	assert_str(String(started[1]["id"])).is_equal("backstab")
	assert_float(float(started[1]["seconds"])).is_equal_approx(0.6, 0.0001)
	var to_player: Vector3 = main.player.global_position - boss.global_position
	to_player.y = 0.0
	assert_float(boss._lock_dir.dot(to_player.normalized())).is_greater(0.99)


func test_a_player_standing_on_the_marker_when_the_boss_lands_is_not_landed_on() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	var boss := _frozen(main, 6.0)
	await _frames(1)
	boss._begin_windup("golden_parachute")
	var marker: Vector3 = boss.blink_target()
	main.player.global_position = marker  # walks onto the marker
	_tick(boss, 0.75)
	var gap: float = Vector2(boss.global_position.x - marker.x, boss.global_position.z - marker.z).length()
	assert_float(gap).is_greater_equal(BossRules.BLINK_MIN_GAP - 0.001)
	# And it moved toward its own side, not to the far side of the player.
	assert_float(boss.global_position.z).is_less(marker.z)


func test_a_blink_clamps_to_the_arena_when_the_player_is_at_the_wall() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3(0.0, 0.0, 18.5)  # right at the south wall
	var boss := _frozen(main, 8.0)
	await _frames(1)
	boss._begin_windup("golden_parachute")
	var marker: Vector3 = boss.blink_target()
	assert_float(absf(marker.z)).is_less_equal(Boss.ARENA_LIMIT + 0.0001)
	assert_float(Vector2(marker.x - 0.0, marker.z - 18.5).length()).is_greater_equal(BossRules.BLINK_MIN_GAP - 0.0001)
	_tick(boss, 0.75)
	assert_float(absf(boss.global_position.z)).is_less_equal(Boss.ARENA_LIMIT + 0.0001)


# ---- threat functions for chained links ----

func test_each_chained_link_is_a_threat_the_bot_can_see_while_it_winds_up() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	var boss := _frozen(main, 2.0)
	await _frames(1)
	for link: String in ["backstab", "leveraged_dash_2"]:
		boss._begin_windup(link)
		assert_float(boss.threat_reach()).override_failure_message("%s has no threat reach" % link).is_greater(0.0)
		assert_bool(boss.in_threat(main.player.global_position)).override_failure_message("%s does not threaten the player it is aimed at" % link).is_true()
		assert_float(boss.escape_direction(main.player.global_position).length()).is_greater(0.9)
		boss._cancel_attack()


func test_the_duelist_walks_every_attack_out_before_it_lands() -> void:
	# Fairness by simulation, from every spot, for every attack of the duelist including the chained links and the blink: the shortest way out at
	# walk speed beats the shortest wind-up it can have (0.6 s).
	var main := _spawn_main()
	var boss := _frozen(main, 30.0)
	await _frames(1)
	boss.global_position = Vector3.ZERO
	main.player.global_position = Vector3(1.5, 0.0, 2.0)
	var walk: float = main.player.move_speed
	var def: Dictionary = BossConfig.boss(DUELIST_ID)
	var phases: Array = def["phases"]
	for attack_id: String in (def["attacks"] as Dictionary).keys():
		for phase_index in range(phases.size()):
			boss.phase_index = phase_index
			var windup: float = BossRules.windup((def["attacks"] as Dictionary)[attack_id], phases[phase_index])
			boss._begin_windup(attack_id)
			var worst: float = 0.0
			var any_threat: bool = false
			for x in range(-20, 21):
				for z in range(-20, 21):
					var point := Vector3(float(x) * 0.3, 0.0, float(z) * 0.3)
					if not boss.in_threat(point):
						continue
					any_threat = true
					var dir: Vector3 = boss.escape_direction(point)
					var t: float = 0.0
					var probe: Vector3 = point
					while boss.in_threat(probe) and t < 5.0:
						t += 0.02
						probe = point + dir * walk * t
					worst = maxf(worst, t)
			var is_blink: bool = String((def["attacks"] as Dictionary)[attack_id]["kind"]) == "blink"
			assert_bool(any_threat).override_failure_message("%s: threat is %s" % [attack_id, str(any_threat)]).is_equal(not is_blink)
			assert_float(worst).override_failure_message("%s in phase %d: worst escape %.2f s against a %.2f s telegraph" % [attack_id, phase_index, worst, windup]).is_less(windup)
			boss._cancel_attack()
	boss.phase_index = 0


func test_the_fairness_formula_passes_every_duelist_attack_in_every_phase() -> void:
	var def: Dictionary = BossConfig.boss(DUELIST_ID)
	for phase: Dictionary in def["phases"]:
		for attack_id: String in (def["attacks"] as Dictionary).keys():
			var attack: Dictionary = (def["attacks"] as Dictionary)[attack_id]
			var result: Dictionary = BossRules.escape(attack, BossRules.windup(attack, phase), 6.0, 4.0, 0.0, 1.0)
			assert_bool(bool(result["ok"])).override_failure_message("%s: %s" % [attack_id, str(result)]).is_true()
			assert_bool(bool(result["walk_ok"])).override_failure_message("%s needs the dodge: %s" % [attack_id, str(result)]).is_true()


# ---- the duelist's numbers (MAP.md 11.3) ----

func test_the_duelist_matches_the_design_note() -> void:
	var def: Dictionary = BossConfig.boss(DUELIST_ID)
	assert_str(String(def["display_name"])).is_equal("The Corporate Raider")
	assert_bool(bool(def["mini_boss"])).is_true()
	assert_float(float(def["max_health"])).is_equal(120.0)  # MAP3b: the MB1 tuning default, was 90
	assert_float(float(def["armor"])).is_equal(10.0)
	assert_float(float(def["knockback_taken"])).is_equal(0.5)
	assert_float(float(def["body_radius"])).is_equal(0.55)
	assert_int(int(def["max_adds_alive"])).is_equal(0)
	var attacks: Dictionary = def["attacks"]
	var takeover: Dictionary = attacks["hostile_takeover"]
	assert_str(String(takeover["kind"])).is_equal("cone")
	assert_float(float(takeover["windup"])).is_equal(0.6)
	assert_float(float(takeover["recover"])).is_equal(0.35)
	assert_float(float(takeover["damage"])).is_equal(9.0)
	assert_float(float(takeover["range"])).is_equal(2.6)
	assert_float(float(takeover["half_angle_degrees"])).is_equal(50.0)
	assert_float(float(takeover["knockback"])).is_equal(6.0)
	for id: String in ["leveraged_dash", "leveraged_dash_2"]:
		var dash: Dictionary = attacks[id]
		assert_str(String(dash["kind"])).is_equal("charge")
		assert_float(float(dash["damage"])).is_equal(5.0)
		assert_float(float(dash["distance"])).is_equal(6.0)
		assert_float(float(dash["speed"])).is_equal(18.0)
		assert_float(float(dash["hit_radius"])).is_equal(0.6)
	assert_float(float(attacks["leveraged_dash"]["windup"])).is_equal(0.7)
	assert_float(float(attacks["leveraged_dash_2"]["windup"])).is_equal(0.6)
	var parachute: Dictionary = attacks["golden_parachute"]
	assert_str(String(parachute["kind"])).is_equal("blink")
	assert_float(float(parachute["windup"])).is_equal(0.7)
	assert_float(float(parachute["damage"])).is_equal(0.0)
	assert_float(float(parachute["behind"])).is_equal(1.8)
	var backstab: Dictionary = attacks["backstab"]
	assert_float(float(backstab["windup"])).is_equal(0.6)
	assert_float(float(backstab["damage"])).is_equal(7.0)
	assert_float(float(backstab["range"])).is_equal(2.4)
	assert_float(float(backstab["half_angle_degrees"])).is_equal(60.0)
	var phases: Array = def["phases"]
	assert_int(phases.size()).is_equal(2)
	assert_float(float((phases[0] as Dictionary)["move_speed"])).is_equal(5.0)
	assert_float(float((phases[0] as Dictionary)["attack_gap"])).is_equal(1.2)
	assert_float(float((phases[1] as Dictionary)["enters_at"])).is_equal(0.5)
	assert_float(float((phases[1] as Dictionary)["move_speed"])).is_equal(5.6)
	assert_float(float((phases[1] as Dictionary)["attack_gap"])).is_equal(0.9)
	for phase: Dictionary in phases:
		assert_float(float(phase["windup_scale"])).is_equal(1.0)
		assert_bool(phase.has("summon")).override_failure_message("a duel has no adds").is_false()
	assert_array(_weights(phases[0])).is_equal([3.0, 2.0, 1.0])
	assert_array(_weights(phases[1])).is_equal([2.0, 2.0, 2.0])
	# Just under the player's 6.0, so you can kite it but only just.
	for phase: Dictionary in phases:
		assert_float(float(phase["move_speed"])).is_less(6.0)


func _weights(phase: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in phase["attacks"]:
		out.append(float(entry["weight"]))
	return out


func test_the_duelist_armor_and_resistance_pass_the_parity_validator() -> void:
	var def: Dictionary = BossConfig.boss(DUELIST_ID)
	assert_array(ArmorConfig.parity_errors("duelist", float(def["armor"]), float(def["resistance"]), ArmorConfig.k(), ArmorConfig.PARITY_TOLERANCE)).is_empty()
	# 10 armor with the note's 0.3 resistance does not pass, which is why the shipped pair is armor 10 / resistance 0.17.
	assert_array(ArmorConfig.parity_errors("duelist", 10.0, 0.3, ArmorConfig.k(), ArmorConfig.PARITY_TOLERANCE)).is_not_empty()
	assert_float(float(def["resistance"])).is_less(0.3)  # still the fragile one: the brute has 22 / 0.3


## The damage of one full sequence started by `attack_id`: its own damage plus every chained link's.
func _sequence_damage(def: Dictionary, attack_id: String) -> float:
	var total: float = 0.0
	var id: String = attack_id
	var guard: int = 0
	while id != "" and guard < 4:
		total += float(((def["attacks"] as Dictionary)[id] as Dictionary)["damage"])
		id = BossConfig.chain_of((def["attacks"] as Dictionary)[id])
		guard += 1
	return total


func test_no_one_duelist_sequence_does_more_than_ten_and_three_in_a_row_stay_under_the_note() -> void:
	var def: Dictionary = BossConfig.boss(DUELIST_ID)
	var scale: float = float(RunConfig.act_scale(2)["damage"])
	assert_float(scale).is_equal(1.0)  # the table is written at act 2's x1.0
	var totals: Array[float] = []
	for attack_id: String in BossConfig.weighted_attack_ids(def):
		var total: float = _sequence_damage(def, attack_id) * scale
		totals.append(total)
		assert_float(total).override_failure_message("%s does %.1f in one sequence" % [attack_id, total]).is_less_equal(10.0)
	totals.sort()
	assert_array(totals).is_equal([7.0, 9.0, 10.0])  # parachute + backstab, slash, combo
	# The table: two in a row at most 20, three in a row at most 29 (combo, combo, slash).
	var worst: Array[float] = [totals[2], totals[2], totals[1]]
	assert_float(worst[0] + worst[1]).is_less_equal(20.0)
	assert_float(worst[0] + worst[1] + worst[2]).is_less_equal(29.0)
	var wizard: float = CharacterDatabase.max_hp("wizard")
	var rogue: float = CharacterDatabase.max_hp("rogue")
	assert_float(worst[0]).is_less(wizard)  # one sequence never kills a full-HP Wizard
	assert_float(worst[0] + worst[1]).is_less(wizard)  # nor two
	assert_float(worst[0] + worst[1] + worst[2]).is_less(rogue)  # three leave a full-HP Rogue on 1
	assert_float(worst[0] + worst[1] + worst[2]).is_greater_equal(wizard)  # and kill the Wizard: the duel is dangerous


func test_a_real_combo_does_ten_to_a_player_who_stands_in_it() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	main.player.health.base_armor = 0.0
	var boss := _frozen(main, 4.0)
	await _frames(1)
	main.player.health.damage_immune = false
	var hp: float = main.player.health.current_health
	boss.debug_script_attacks(["leveraged_dash"] as Array[String])
	boss._attack_cooldown_remaining = 0.0
	# The player never moves: the boss runs through them twice. Step with real physics frames.
	boss.set_physics_process(true)
	var started: Array[String] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, _seconds: float) -> void: started.append(attack_id))
	for frame in range(60 * 5):
		await get_tree().physics_frame
		main.player.global_position = Vector3.ZERO
		if started.size() == 2 and boss.state_name() == "RECOVER":
			break
	assert_float(hp - main.player.health.current_health).override_failure_message("the combo did %.1f" % (hp - main.player.health.current_health)).is_less_equal(10.0 + 0.001)
	assert_float(hp - main.player.health.current_health).is_greater(0.0)


# ---- the duelist's scene ----

func test_the_duelist_scene_is_a_thin_capsule_with_a_bright_tie_on_its_front() -> void:
	var main := _spawn_main()
	var boss := _duelist(main)
	await _frames(1)
	assert_str(boss.enemy_id).is_equal(DUELIST_ID)
	assert_float(boss.body_radius).is_equal(0.55)
	assert_bool(boss.is_mini_boss()).is_true()
	assert_str(boss.tier).is_equal("mini_boss")
	assert_float(boss.health.max_health).is_equal(120.0)
	var shape: CapsuleShape3D = (boss.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	assert_object(shape).is_not_null()
	assert_float(shape.radius).is_less_equal(0.5)  # about the player's size, not the Guardian's
	var tie: MeshInstance3D = boss.get_node("BodyMesh/Tie") as MeshInstance3D
	assert_object(tie).is_not_null()
	assert_float(tie.position.z).is_less(0.0)  # on the front: the boss faces -Z
	var suit: Color = ((boss.get_node("BodyMesh") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	var stripe: Color = (tie.material_override as StandardMaterial3D).albedo_color
	assert_float(suit.get_luminance()).is_less(0.25)  # a dark suit
	assert_float(stripe.get_luminance()).is_greater(suit.get_luminance() + 0.2)  # a bright tie against it


func test_the_duelist_is_stunnable_and_takes_a_little_knockback() -> void:
	var main := _spawn_main()
	var boss := _duelist(main)
	await _frames(1)
	boss.status_manager.apply_status("stun", (StatusDatabase.get_status("stun") as Dictionary).duplicate(true), 2.0)
	assert_bool(boss.is_stunned()).is_true()
	assert_float(float(BossConfig.boss(DUELIST_ID)["knockback_taken"])).is_equal(0.5)


func test_the_duelist_chases_until_it_picks_an_attack_and_never_summons() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	main.player.health.damage_immune = true
	var boss := _duelist(main, 8.0)
	await _frames(1)
	boss.debug_set_phase(1)
	assert_str(boss.phase_name()).is_equal("Aggressive restructuring")
	assert_int(boss.live_adds()).is_equal(0)
	boss.begin_spawn_grace(0.0)
	var seen: Array[String] = []
	boss.attack_telegraphed.connect(func(attack_id: String, _label: String, _seconds: float) -> void: seen.append(attack_id))
	for frame in range(60 * 14):
		await get_tree().physics_frame
		main.player.health.current_health = main.player.health.max_health
	assert_int(seen.size()).is_greater_equal(4)
	assert_int(boss.live_adds()).is_equal(0)
	for id: String in seen:
		assert_bool((BossConfig.boss(DUELIST_ID)["attacks"] as Dictionary).has(id)).is_true()


# ---- rooms, scenarios and the run ----

func test_the_act_two_mini_boss_room_spawns_the_duelist_alone() -> void:
	var room: Dictionary = RunConfig.variant_by_id(RunConfig.get_config(), "mini_boss", "mini_boss_act2")
	assert_int((room["stages"] as Array).size()).is_equal(1)
	var spawns: Array = ((room["stages"] as Array)[0] as Dictionary)["spawns"]
	assert_int(spawns.size()).is_equal(1)
	assert_str(String((spawns[0] as Dictionary)["enemy"])).is_equal(DUELIST_ID)
	assert_array(room["acts"]).is_equal([2.0])
	assert_array(RunConfig.validate(RunConfig.get_config(), _known(), [])).is_empty()


func test_the_mini_boss_act2_scenario_is_valid_and_builds_the_room_with_act_two_scaling_and_tint() -> void:
	for id: String in ["mini_boss_act2", "mini_boss_blink", "mini_boss_dash_combo"]:
		assert_bool(Scenario.has_scenario(id)).is_true()
		assert_array(ScenarioSchema.validate(id, Scenario.raw_def(id))).is_empty()
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	var scenario: Scenario = Scenario.setup(main, "mini_boss_act2")
	assert_object(scenario).is_not_null()
	await _frames(2)
	var found: Array[Enemy] = scenario.enemies()
	assert_int(found.size()).is_equal(1)
	assert_bool(found[0] is Boss and (found[0] as Boss).is_mini_boss()).is_true()
	assert_str(found[0].enemy_id).is_equal(DUELIST_ID)
	assert_float(found[0].health.max_health).is_equal_approx(120.0 * float(RunConfig.act_scale(2)["hp"]), 0.001)
	assert_float(main.player.health.current_health).is_equal(main.player.health.get_max_health())
	assert_float(main.player.health.get_max_health()).is_equal(CharacterDatabase.max_hp("rogue"))
	var floor_color: Color = ((main.get_node("Floor") as CSGBox3D).material as StandardMaterial3D).albedo_color
	assert_bool(floor_color.is_equal_approx(RunConfig.act_tint(2)["floor"])).is_true()


func _spawn_run() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func test_killing_the_act_two_mini_boss_ends_the_act_and_never_the_run() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(19)  # act 2's mini-boss (room 20)
	var main: Main = _spawn_run()
	await _frames(3)
	var controller: RunController = main.run_controller
	assert_str(controller.room_type()).is_equal("mini_boss")
	assert_int(state.act).is_equal(2)
	var won: Array[bool] = [false]
	controller.run_won.connect(func() -> void: won[0] = true)
	var cleared: Array[bool] = [false]
	controller.choice_requested.connect(func(_model: Dictionary) -> void: cleared[0] = true)
	main.enemy_spawner._process(3.0)  # past the first wave delay: the duelist spawns
	var boss: Boss = null
	for child in main.get_children():
		if child is Boss:
			boss = child as Boss
	assert_object(boss).is_not_null()
	assert_str(boss.enemy_id).is_equal(DUELIST_ID)
	assert_float(boss.health.max_health).is_equal_approx(120.0 * float(RunConfig.act_scale(2)["hp"]), 0.001)
	boss.debug_set_phase(1)
	boss.health.take_damage(boss.health.max_health * 100.0, "physical")
	assert_bool(boss.is_defeated()).is_true()
	var waited: int = 0
	while is_instance_valid(boss) and waited < 60 * 6:
		await get_tree().physics_frame
		waited += 1
	await _frames(4)
	assert_bool(cleared[0]).override_failure_message("the room did not end").is_true()
	assert_bool(won[0]).override_failure_message("a mini-boss death won the run").is_false()
	assert_str(state.outcome).is_not_equal("won")
	assert_int(state.act).is_equal(2)
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	var seen_acts: Array[int] = []
	controller.act_started.connect(func(act_number: int, _summary: Dictionary) -> void: seen_acts.append(act_number))
	controller.pick_relic(state.offer[0])
	controller.choose("skip")
	assert_array(seen_acts).is_equal([3])
	assert_bool(won[0]).is_false()


# ---- knockback and a locked lane ----

func test_a_hit_during_a_dash_wind_up_does_not_push_the_boss_off_its_drawn_lane() -> void:
	# The duelist is the first boss that takes knockback (0.5). The charge lane and its telegraph are anchored at the wind-up's start, so a push
	# during the wind-up would put the real dash off the drawn lane (and the sim bot would dodge the wrong strip).
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	main.player.health.damage_immune = true
	var boss := _frozen(main, 6.0)
	await _frames(1)
	var start: Vector3 = Vector3(boss.global_position.x, 0.0, boss.global_position.z)
	boss._begin_windup("leveraged_dash")
	assert_vector(boss._charge_start).is_equal(start)
	boss._on_damaged(1.0, "physical", Vector3(10.0, 0.0, 0.0))
	for tick in range(int(0.65 / STEP)):
		boss._physics_process(STEP)
	assert_str(boss.state_name()).is_equal("WINDUP")
	assert_float(Vector2(boss.global_position.x - start.x, boss.global_position.z - start.z).length()).override_failure_message("the boss slid %.2f m during its wind-up" % Vector2(boss.global_position.x - start.x, boss.global_position.z - start.z).length()).is_less(0.01)
	boss._cancel_attack()
	# A hit while it chases or recovers still shoves it a little: that is what knockback_taken 0.5 is for.
	var before: Vector3 = boss.global_position
	boss._on_damaged(1.0, "physical", Vector3(10.0, 0.0, 0.0))
	for tick in range(6):
		boss._physics_process(STEP)
	assert_float(boss.global_position.x - before.x).is_greater(0.05)


func test_a_push_left_over_from_recovering_is_cleared_when_the_next_wind_up_starts() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	var boss := _frozen(main, 6.0)
	await _frames(1)
	boss._on_damaged(1.0, "physical", Vector3(10.0, 0.0, 0.0))
	assert_float(boss._knockback_velocity.length()).is_greater(0.0)
	boss._begin_windup("leveraged_dash")
	assert_float(boss._knockback_velocity.length()).is_equal(0.0)
