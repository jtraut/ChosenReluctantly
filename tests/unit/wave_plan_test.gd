class_name WavePlanTest
extends GdUnitTestSuite
## Slice 5a: data/waves.json validation, wave staging, the alive cap, spawn grace.

const KNOWN: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem"]


func _cfg(overrides: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = {
		"max_alive": 6, "first_wave_delay": 2.0, "spawn_attack_grace": 1.0, "spawn_gap": 0.5,
		"spawn_distance_min": 9.0, "spawn_distance_max": 13.0, "arena_half_extent": 19.0, "loop_from_stage": 1,
		"stages": [
			{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 3}]},
			{"delay": 5.0, "until_alive_at_most": 2, "spawns": [{"enemy": "ranged_shooter", "count": 2}]},
		],
	}
	cfg.merge(overrides, true)
	return cfg


## Runs the plan at 20 ticks per second with a fixed alive count, returns [time, id] spawn events.
func _run(plan: WavePlan, seconds: float, alive_of: Callable) -> Array:
	var events: Array = []
	var t: float = 0.0
	var alive: int = 0
	while t < seconds:
		t += 0.05
		for id: String in plan.step(0.05, alive):
			events.append([t, id])
			alive += 1
		alive = int(alive_of.call(t, alive))
	return events


func test_shipped_file_validates() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WaveConfig.PATH))
	assert_array(WaveConfig.validate(parsed, EnemyConfig.enemy_ids())).is_empty()
	assert_int(WaveConfig.max_alive()).is_between(6, 15)


func test_bad_data_is_rejected() -> void:
	var bad_cases: Array[Dictionary] = [
		_cfg({"max_alive": 5}), _cfg({"max_alive": 16}), _cfg({"max_alive": 8.5}), _cfg({"max_alive": "x"}),
		_cfg({"first_wave_delay": -1.0}), _cfg({"spawn_gap": null}),
		_cfg({"spawn_distance_min": 14.0}),
		_cfg({"loop_from_stage": 2}), _cfg({"loop_from_stage": -1}),
		_cfg({"stages": []}), _cfg({"stages": 3}),
		_cfg({"stages": [{"delay": 0.0, "spawns": []}]}),
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"enemy": "nope", "count": 1}]}]}),
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 0}]}]}),
		_cfg({"stages": [{"delay": -2.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]}),
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 7}]}], "loop_from_stage": 0}),
		_cfg({"stages": [{"delay": 0.0, "until_alive_at_most": 99, "spawns": [{"enemy": "melee_chaser", "count": 1}]}], "loop_from_stage": 0}),
	]
	for bad in bad_cases:
		assert_array(WaveConfig.validate(bad, KNOWN)).override_failure_message("should reject %s" % str(bad)).is_not_empty()
	assert_array(WaveConfig.validate(_cfg(), KNOWN)).is_empty()


func test_enemies_json_names_a_real_scene_for_every_id() -> void:
	for id in EnemyConfig.enemy_ids():
		var path := EnemyConfig.scene_path_for(id)
		assert_bool(ResourceLoader.exists(path)).is_true()
		var inst: Enemy = (load(path) as PackedScene).instantiate()
		assert_str(inst.enemy_id).is_equal(id)
		inst.free()


func test_first_wave_waits_for_first_wave_delay() -> void:
	var plan := WavePlan.new(_cfg(), RandomNumberGenerator.new())
	var events := _run(plan, 5.0, func(_t: float, a: int) -> int: return a)
	assert_int(events.size()).is_greater(0)
	assert_float(float(events[0][0])).is_greater_equal(2.0)
	assert_float(float(events[0][0])).is_less(2.2)


func test_spawns_are_spaced_by_spawn_gap() -> void:
	var plan := WavePlan.new(_cfg(), RandomNumberGenerator.new())
	var events := _run(plan, 5.0, func(_t: float, a: int) -> int: return a)
	for i in range(1, 3):
		assert_float(float(events[i][0]) - float(events[i - 1][0])).is_greater_equal(0.45)


func test_stage_two_waits_for_delay_and_for_few_enemies_alive() -> void:
	var plan := WavePlan.new(_cfg(), RandomNumberGenerator.new())
	# Nothing ever dies: stage 1 (needs <= 2 alive) must never open, only stage 0's 3 spawn.
	var events := _run(plan, 60.0, func(_t: float, a: int) -> int: return a)
	assert_int(events.size()).is_equal(3)
	# Everything dies at 10 s: stage 1 opens at once (its 5 s delay has long passed).
	var plan2 := WavePlan.new(_cfg(), RandomNumberGenerator.new())
	var events2 := _run(plan2, 14.0, func(t: float, a: int) -> int: return 0 if t >= 10.0 and t < 10.1 else a)
	assert_int(events2.size()).is_equal(5)
	assert_float(float(events2[3][0])).is_greater_equal(10.0)
	assert_str(String(events2[3][1])).is_equal("ranged_shooter")


func test_alive_cap_never_exceeded_and_blocked_spawns_wait() -> void:
	var cfg := _cfg({"max_alive": 6, "stages": [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 6}]}], "loop_from_stage": 0})
	var plan := WavePlan.new(cfg, RandomNumberGenerator.new())
	var alive: int = 4
	var spawned: int = 0
	for i in range(400):
		for _id in plan.step(0.05, alive):
			alive += 1
			spawned += 1
		assert_int(alive).is_less_equal(6)
	assert_int(spawned).is_equal(2)  # blocked at the cap, not dropped, not over it
	assert_int(plan.pending_count()).is_greater(0)
	alive = 0
	for i in range(100):
		for _id in plan.step(0.05, alive):
			alive += 1
			spawned += 1
		assert_int(alive).is_less_equal(6)
	assert_int(spawned).is_equal(8)  # the queued four came out once there was room, then the looped stage refilled the cap


func test_loop_returns_to_loop_from_stage() -> void:
	var plan := WavePlan.new(_cfg(), RandomNumberGenerator.new())
	var events := _run(plan, 80.0, func(_t: float, _a: int) -> int: return 0)
	assert_int(plan.stages_started()).is_greater(3)
	assert_int(plan.next_stage_index()).is_between(0, 1)
	var ids: Array[String] = []
	for e in events:
		ids.append(String(e[1]))
	assert_array(ids.slice(0, 3)).is_equal(["melee_chaser", "melee_chaser", "melee_chaser"])
	assert_bool(ids.slice(3).has("melee_chaser")).is_false()  # stage 0 never replays after the loop


func test_same_seed_same_order() -> void:
	var cfg := _cfg({"max_alive": 12, "stages": [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 4}, {"enemy": "ranged_shooter", "count": 4}]}], "loop_from_stage": 0})
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 77
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 77
	var a := _run(WavePlan.new(cfg, rng_a), 8.0, func(_t: float, x: int) -> int: return x)
	var b := _run(WavePlan.new(cfg, rng_b), 8.0, func(_t: float, x: int) -> int: return x)
	assert_array(a).is_equal(b)


func test_spawner_applies_grace_and_respects_cap_in_scene() -> void:
	var main: Main = auto_free((load("res://scenes/main/Main.tscn") as PackedScene).instantiate())
	add_child(main)
	await get_tree().process_frame
	var spawner: EnemySpawner = main.enemy_spawner
	spawner.set_seed(5)
	assert_int(spawner.alive_count()).is_equal(0)
	spawner.plan = WavePlan.new(_cfg({"first_wave_delay": 0.0}), RandomNumberGenerator.new())
	var spawned: Array[Enemy] = []
	spawner.enemy_spawned.connect(func(e: Enemy, _n: int) -> void: spawned.append(e))
	for i in range(30):
		spawner._process(0.1)
	assert_int(spawned.size()).is_equal(3)
	assert_int(spawner.alive_count()).is_equal(3)
	for e in spawned:
		assert_float(e._attack_cooldown_remaining).is_greater_equal(0.9)
		var d := Vector2(e.global_position.x - main.player.global_position.x, e.global_position.z - main.player.global_position.z).length()
		assert_float(d).is_greater_equal(8.9)
		assert_float(absf(e.global_position.x)).is_less_equal(19.01)
		e.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(spawner.alive_count()).is_equal(0)


func test_enemy_entry_needs_a_real_scene() -> void:
	assert_array(EnemyConfig.validate_enemies({"a": {"rank": "normal"}})).is_not_empty()
	assert_array(EnemyConfig.validate_enemies({"a": {"rank": "normal", "scene": "res://nope.tscn"}})).is_not_empty()


func test_step_one_matches_step_and_returns_empty_when_nothing_spawns() -> void:
	# S5-6: the per-frame call returns one id or "" (no array); step() is the same thing as a list.
	var a := WavePlan.new(_cfg(), _rng(5))
	var b := WavePlan.new(_cfg(), _rng(5))
	var alive_a: int = 0
	var alive_b: int = 0
	for i in range(2000):
		var one: String = a.step_one(0.05, alive_a)
		var many: Array[String] = b.step(0.05, alive_b)
		assert_int(many.size()).is_equal(0 if one == "" else 1)
		if one != "":
			assert_str(many[0]).is_equal(one)
			alive_a += 1
			alive_b += 1
		if i % 40 == 0:
			alive_a = maxi(alive_a - 2, 0)
			alive_b = maxi(alive_b - 2, 0)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
