class_name Slice5QaTest
extends GdUnitTestSuite
## qa for Polish 1 Slice 5 (waves, enemy readability, HP bars), review of 3af4538..642b1ee.
## Each test names what it guards. Tests marked PIN record a current, known-wrong behaviour so a
## fix has to update them on purpose (see docs/reviews/2026-10-28-polish1-slice5-qa.md).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const SHOOTER_PATH := "res://scenes/enemies/RangedShooter.tscn"
const GOLEM_PATH := "res://scenes/enemies/FireResistantGolem.tscn"
const KNOWN: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem"]
const ALL_MODES: Array[String] = ["always_alive", "after_damage", "hidden_at_full", "elite_boss_always"]

var _root_main: Main = null


func before_test() -> void:
	CardDatabase.load_all()


func after_test() -> void:
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _stun_def() -> Dictionary:
	return (StatusDatabase.get_status("stun") as Dictionary).duplicate(true)


## Main as a child of the tree root and the current scene (enemy shots and damage numbers are added
## under current_scene, which is null under the test runner). The spawner is switched off.
func _spawn_root_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	return main


func _enemy(main: Main, path: String, pos: Vector3) -> Enemy:
	var enemy: Enemy = (load(path) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = pos
	enemy.target = main.player
	return enemy


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


# =====================================================================================
# 1. Spawner cap and wave staging from data
# =====================================================================================

## Random valid tables and a random player (kills at random), 120 seeds: alive never exceeds the
## cap, at most one spawn per step, and nothing queued ever vanishes.
func test_fuzz_cap_never_exceeded_and_nothing_dropped() -> void:
	var rng := RandomNumberGenerator.new()
	var stage_total: int = 0
	for seed_value in range(120):
		rng.seed = seed_value
		var cap: int = rng.randi_range(6, 15)
		var stages: Array = []
		for s in range(rng.randi_range(1, 4)):
			var spawns: Array = []
			var budget: int = cap
			for e in range(rng.randi_range(1, 3)):
				if budget <= 0:
					break
				var count: int = rng.randi_range(1, mini(budget, 6))
				budget -= count
				spawns.append({"enemy": KNOWN[rng.randi_range(0, 2)], "count": count})
			var stage: Dictionary = {"delay": rng.randf_range(0.0, 6.0), "spawns": spawns}
			if rng.randf() < 0.6:
				stage["until_alive_at_most"] = rng.randi_range(0, cap)
			stages.append(stage)
		var cfg: Dictionary = _cfg({"max_alive": cap, "stages": stages, "loop_from_stage": rng.randi_range(0, stages.size() - 1),
				"first_wave_delay": rng.randf_range(0.0, 5.0), "spawn_gap": rng.randf_range(0.0, 1.0)})
		assert_array(WaveConfig.validate(cfg, KNOWN)).override_failure_message("fuzz config %d invalid" % seed_value).is_empty()
		var plan := WavePlan.new(cfg, rng)
		var alive: int = 0
		var spawned: int = 0
		var worst_alive: int = 0
		var worst_step: int = 0
		var broke_conservation: bool = false
		for tick in range(3000):  # 2.5 minutes at 20 Hz
			var before_pending: int = plan.pending_count()
			var out: Array[String] = plan.step(0.05, alive)
			worst_step = maxi(worst_step, out.size())
			for _id in out:
				alive += 1
				spawned += 1
			worst_alive = maxi(worst_alive, alive)
			# Pending only grows when a stage opens, and a spawn removes exactly one.
			if plan.pending_count() + out.size() < before_pending:
				broke_conservation = true
			if rng.randf() < 0.04 and alive > 0:
				alive -= 1
		stage_total += plan.stages_started()
		assert_int(worst_alive).override_failure_message("seed %d: alive %d over cap %d" % [seed_value, worst_alive, cap]).is_less_equal(cap)
		assert_int(worst_step).override_failure_message("seed %d: more than one spawn in a step" % seed_value).is_less_equal(1)
		assert_bool(broke_conservation).override_failure_message("seed %d: queued enemies vanished" % seed_value).is_false()
		assert_int(spawned + plan.pending_count()).is_greater(0)
	assert_int(stage_total).is_greater(120)  # the fuzz really opened stages, not just sat at a gate


func test_blocked_queue_keeps_the_exact_stage_composition_in_data_order() -> void:
	# Cap 6, a 6-enemy stage, 5 already alive: only one fits, the other five wait and come out as listed.
	var stage: Dictionary = {"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 2}, {"enemy": "ranged_shooter", "count": 3}, {"enemy": "fire_resistant_golem", "count": 1}]}
	var cfg: Dictionary = _cfg({"max_alive": 6, "first_wave_delay": 0.0, "stages": [stage], "loop_from_stage": 0})
	var plan := WavePlan.new(cfg, RandomNumberGenerator.new())
	var alive: int = 5
	var out_ids: Array[String] = []
	for i in range(100):
		for id in plan.step(0.1, alive):
			alive += 1
			out_ids.append(id)
	assert_int(out_ids.size()).is_equal(1)  # blocked by the cap
	assert_int(plan.pending_count()).is_equal(5)  # queued, not dropped
	alive = 0
	for i in range(300):
		for id in plan.step(0.1, alive):
			alive += 1
			out_ids.append(id)
		if out_ids.size() >= 6:
			break
	var counts: Dictionary = {}
	for id in out_ids.slice(0, 6):
		counts[id] = int(counts.get(id, 0)) + 1
	assert_dict(counts).is_equal({"melee_chaser": 2, "ranged_shooter": 3, "fire_resistant_golem": 1})


func test_stage_content_follows_the_data_not_the_code() -> void:
	# Same code, two tables: the spawned ids are exactly what each table says.
	for enemy_id in KNOWN:
		var cfg: Dictionary = _cfg({"first_wave_delay": 0.0, "stages": [{"delay": 0.0, "spawns": [{"enemy": enemy_id, "count": 3}]}], "loop_from_stage": 0, "max_alive": 6})
		var plan := WavePlan.new(cfg, RandomNumberGenerator.new())
		var ids: Array[String] = []
		for i in range(60):
			ids.append_array(plan.step(0.1, ids.size()))
		assert_array(ids.slice(0, 3)).is_equal([enemy_id, enemy_id, enemy_id])


func test_shipped_table_first_stages_match_waves_json() -> void:
	var cfg: Dictionary = WaveConfig.get_config()
	var plan := WavePlan.new(cfg, RandomNumberGenerator.new())
	var alive: int = 0
	var seen: Array[String] = []
	var t: float = 0.0
	# Player kills everything instantly: the first three stage openings must be stages 0, 1, 2 of the file.
	while plan.stages_started() < 3 or plan.pending_count() > 0:
		t += 0.05
		assert_float(t).override_failure_message("waves never progressed").is_less(120.0)
		var out: Array[String] = plan.step(0.05, alive)
		seen.append_array(out)
		alive = 0
	var expected: Array[String] = []
	for stage_index in range(3):
		for entry: Dictionary in (cfg["stages"][stage_index]["spawns"] as Array):
			for i in range(int(entry["count"])):
				expected.append(String(entry["enemy"]))
	var a: Array[String] = seen.duplicate()
	a.sort()
	expected.sort()
	assert_array(a).is_equal(expected)
	assert_int(plan.stages_started()).is_equal(3)


func test_shipped_table_reaches_the_cap_but_never_passes_it_with_a_slow_player() -> void:
	var cfg: Dictionary = WaveConfig.get_config()
	var cap: int = int(cfg["max_alive"])
	var plan := WavePlan.new(cfg, RandomNumberGenerator.new())
	var alive: int = 0
	var peak: int = 0
	for tick in range(20 * 600):  # 10 minutes at 20 Hz, one kill per 2.5 s
		for _id in plan.step(0.05, alive):
			alive += 1
		peak = maxi(peak, alive)
		assert_int(alive).is_less_equal(cap)
		if tick % 50 == 0 and alive > 0:
			alive -= 1
	assert_int(peak).is_between(6, cap)


func test_waves_json_bad_values_fail_loudly_extra_cases() -> void:
	var bad_cases: Array[Dictionary] = [
		_cfg({"spawn_attack_grace": -0.1}), _cfg({"spawn_attack_grace": "1.5"}), _cfg({"spawn_gap": -0.5}),
		_cfg({"first_wave_delay": "soon"}), _cfg({"arena_half_extent": 0.0}), _cfg({"arena_half_extent": null}),
		_cfg({"spawn_distance_min": 0.0}), _cfg({"spawn_distance_max": 100.0}), _cfg({"max_alive": null}), _cfg({"max_alive": 0}),
		_cfg({"loop_from_stage": 1.5}), _cfg({"loop_from_stage": "1"}), _cfg({"loop_from_stage": null}),
		_cfg({"stages": [{"spawns": [{"enemy": "melee_chaser", "count": 1}]}]}),  # no delay
		_cfg({"stages": [{"delay": 0.0}]}),  # no spawns
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 31}]}], "max_alive": 15}),
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1.5}]}]}),
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"enemy": 7, "count": 1}]}]}),
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"count": 1}]}]}),
		_cfg({"stages": [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser"}]}]}),
		_cfg({"stages": [{"delay": 0.0, "spawns": ["melee_chaser"]}]}),
		_cfg({"stages": [{"delay": 700.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]}),
		_cfg({"stages": [{"delay": 0.0, "until_alive_at_most": -1, "spawns": [{"enemy": "melee_chaser", "count": 1}]}], "loop_from_stage": 0}),
		_cfg({"stages": [{"delay": 0.0, "until_alive_at_most": "3", "spawns": [{"enemy": "melee_chaser", "count": 1}]}], "loop_from_stage": 0}),
		_cfg({"stages": ["not a stage"], "loop_from_stage": 0}),
	]
	for bad in bad_cases:
		assert_array(WaveConfig.validate(bad, KNOWN)).override_failure_message("should reject %s" % str(bad)).is_not_empty()
	# An empty config reports problems and does not crash.
	assert_array(WaveConfig.validate({}, KNOWN)).is_not_empty()


func test_arena_half_extent_is_checked_against_the_walls() -> void:
	# S5-3 (was a PIN): arena_half_extent may not pass the wall's inner face minus a clearance.
	assert_array(WaveConfig.validate(_cfg({"arena_half_extent": 60.0}), KNOWN)).is_not_empty()
	assert_array(WaveConfig.validate(_cfg({"arena_half_extent": 19.6}), KNOWN)).is_not_empty()
	assert_array(WaveConfig.validate(_cfg({"arena_half_extent": 19.5}), KNOWN)).is_empty()
	assert_float(float(WaveConfig.get_config()["arena_half_extent"])).is_less_equal(WaveConfig.WALL_INNER_HALF_EXTENT - WaveConfig.WALL_CLEARANCE)


func test_wall_constant_matches_the_real_walls_in_main_tscn() -> void:
	var main: Node = auto_free((load("res://scenes/main/Main.tscn") as PackedScene).instantiate())
	for wall_name: String in ["WallN", "WallS", "WallW", "WallE"]:
		var wall: CollisionShape3D = main.get_node("ArenaWalls/" + wall_name)
		var box: BoxShape3D = wall.shape
		var centre: float = maxf(absf(wall.position.x), absf(wall.position.z))
		var half_thickness: float = minf(box.size.x, box.size.z) * 0.5
		assert_float(centre - half_thickness).override_failure_message("%s inner face moved; update WaveConfig.WALL_INNER_HALF_EXTENT" % wall_name).is_equal_approx(WaveConfig.WALL_INNER_HALF_EXTENT, 0.001)


func test_enemies_json_scene_bad_values() -> void:
	var good: Dictionary = {"rank": "normal", "scene": "res://scenes/enemies/MeleeChaser.tscn"}
	assert_array(EnemyConfig.validate_enemies({"a": good})).is_empty()
	for bad_scene: Variant in [null, 7, "", "MeleeChaser.tscn", "res://scenes/enemies/Nope.tscn", "user://x.tscn", ["a"]]:
		var entry: Dictionary = good.duplicate()
		entry["scene"] = bad_scene
		assert_array(EnemyConfig.validate_enemies({"a": entry})).override_failure_message("scene %s should be rejected" % str(bad_scene)).is_not_empty()
	assert_array(EnemyConfig.validate_enemies({"a": {"rank": "normal"}})).is_not_empty()
	# Unknown id never silently returns a scene (and says so loudly).
	var holder: Array[String] = []
	var assertion := await assert_error(func() -> void: holder.append(EnemyConfig.scene_path_for("nope_enemy")))
	assertion.is_push_error("EnemyConfig: enemy id 'nope_enemy' has no scene in data/enemies.json 'enemies'")
	assert_array(holder).is_equal([""])


# =====================================================================================
# 2. Spawn ring, spawn grace, walls
# =====================================================================================

func test_spawn_ring_stays_inside_the_walls_and_away_from_the_player() -> void:
	var main := _spawn_root_main()
	await _frames(2)
	var spawner: EnemySpawner = main.enemy_spawner
	spawner.set_seed(11)
	var limit: float = float(spawner.plan.config["arena_half_extent"])
	var min_dist: float = float(spawner.plan.config["spawn_distance_min"])
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3(19, 0, 19), Vector3(-19, 0, 19), Vector3(19, 0, -19), Vector3(-19, 0, -19),
			Vector3(19, 0, 0), Vector3(0, 0, -19), Vector3(5, 0, -17)]
	var worst: float = 1000.0
	var under_min: int = 0
	var samples: int = 0
	for spot in spots:
		main.player.global_position = spot
		for i in range(1500):
			var p: Vector3 = spawner._random_spawn_position()
			samples += 1
			assert_bool(absf(p.x) <= limit + 0.0001 and absf(p.z) <= limit + 0.0001).override_failure_message("spawn %s outside the arena (player at %s)" % [str(p), str(spot)]).is_true()
			assert_bool(is_finite(p.x) and is_finite(p.z)).is_true()
			var d: float = Vector2(p.x - spot.x, p.z - spot.z).length()
			worst = minf(worst, d)
			if d < min_dist - 0.001:
				under_min += 1
	# Informational: how many corner spawns fell short of spawn_distance_min (grace covers them).
	print("QA 5: %d of %d ring spawns were closer than spawn_distance_min (closest %.2f m)" % [under_min, samples, worst])
	assert_int(under_min).is_equal(0)


func test_corner_spawn_keeps_the_minimum_distance_from_the_player() -> void:
	# S5-4 (was a PIN): with the player in an arena corner the ring is mostly clamped away, so the spawner
	# falls back to a sweep of angles. Every spawn is now at least spawn_distance_min from the player.
	var main := _spawn_root_main()
	await _frames(2)
	var spawner: EnemySpawner = main.enemy_spawner
	spawner.set_seed(11)
	var min_dist: float = float(spawner.plan.config["spawn_distance_min"])
	var worst: float = 1000.0
	for spot in [Vector3(19, 0, 19), Vector3(-19, 0, 19), Vector3(19, 0, -19), Vector3(-19, 0, -19), Vector3(19.5, 0, 0), Vector3(0, 0, -19.5)]:
		main.player.global_position = spot
		for i in range(1500):
			var p: Vector3 = spawner._random_spawn_position()
			worst = minf(worst, Vector2(p.x - spot.x, p.z - spot.z).length())
	print("QA 5: closest spawn with the player in a corner: %.2f m" % worst)
	assert_float(worst).is_greater_equal(min_dist - 0.001)


func test_spawn_grace_no_attack_starts_or_lands_for_1_5_seconds() -> void:
	var main := _spawn_root_main()
	main.player.set_physics_process(false)
	main.player.global_position = Vector3.ZERO
	await _frames(2)
	var chaser := _enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -1.0))  # already inside its attack range
	var shooter := _enemy(main, SHOOTER_PATH, Vector3(3.0, 0.0, 0.0))  # already inside its preferred range 7
	var grace: float = float(WaveConfig.get_config()["spawn_attack_grace"])
	chaser.begin_spawn_grace(grace)
	shooter.begin_spawn_grace(grace)
	var projectiles := [0]
	main.child_entered_tree.connect(func(node: Node) -> void:
		if node is Projectile:
			projectiles[0] += 1)
	var hp_start: float = main.player.health.current_health
	for i in range(int(grace * 60.0) - 3):  # 87 ticks = 1.45 s
		await _frames(1)
		assert_float(chaser._telegraph_remaining).override_failure_message("chaser began a wind-up inside the grace (tick %d)" % i).is_equal(0.0)
		assert_float(shooter._telegraph_remaining).override_failure_message("shooter began a wind-up inside the grace (tick %d)" % i).is_equal(0.0)
	assert_float(main.player.health.current_health).is_equal(hp_start)
	assert_int(projectiles[0]).is_equal(0)
	# After the grace the same enemies do attack (the grace is not a permanent disable).
	await _frames(30)
	assert_bool(chaser._telegraph_remaining > 0.0 or main.player.health.current_health < hp_start).override_failure_message("chaser never attacked after the grace").is_true()


func test_arena_walls_hold_a_forced_move_and_a_huge_knockback() -> void:
	var main := _spawn_root_main()
	await _frames(3)
	var player := main.player
	player.global_position = Vector3(17.0, 0.2, 0.0)
	player.start_forced_move(Vector3.RIGHT, 80.0, 1.0, true)  # far beyond the dodge's 14 m/s
	var chaser := _enemy(main, CHASER_PATH, Vector3(-17.0, 0.2, 3.0))
	chaser.target = null
	chaser._knockback_velocity = Vector3(-120.0, 0.0, 0.0)
	var shooter := _enemy(main, SHOOTER_PATH, Vector3(10.0, 0.2, -17.0))
	shooter.target = null
	shooter._knockback_velocity = Vector3(0.0, 0.0, -120.0)
	for i in range(90):
		await _frames(1)
		for body: Node3D in [player, chaser, shooter]:
			assert_bool(absf(body.global_position.x) < 20.0 and absf(body.global_position.z) < 20.0).override_failure_message("%s escaped the arena to %s on tick %d" % [body.name, str(body.global_position), i]).is_true()
			assert_float(body.global_position.y).is_greater(-1.0)  # not fallen into the void
	assert_float(player.global_position.x).is_greater(17.5)  # it really did push against the east wall


func test_player_dash_into_the_corner_does_not_leave_the_arena() -> void:
	var main := _spawn_root_main()
	await _frames(3)
	var player := main.player
	player.global_position = Vector3(18.5, 0.2, 18.5)
	for step in range(10):
		player.start_forced_move(Vector3(1, 0, 1).normalized(), 14.0, 0.25, true)
		await _frames(18)
	assert_bool(player.global_position.x < 20.0 and player.global_position.z < 20.0).is_true()


# =====================================================================================
# 3. N1: golem capsule hurtbox vs its box movement collider
# =====================================================================================

func test_golem_box_collider_never_keeps_a_player_melee_out_of_reach_at_a_corner() -> void:
	var golem: Enemy = auto_free((load(GOLEM_PATH) as PackedScene).instantiate())
	var body_box := (golem.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var capsule := (golem.get_node("Hurtbox/HurtboxShape") as CollisionShape3D)
	var hurt_radius: float = (capsule.shape as CapsuleShape3D).radius
	var low_center: float = capsule.position.y - ((capsule.shape as CapsuleShape3D).height * 0.5 - hurt_radius)
	var player: Player = auto_free((load("res://scenes/player/Player.tscn") as PackedScene).instantiate())
	var player_shape := (player.get_node("CollisionShape3D") as CollisionShape3D).shape
	var player_radius: float = (player_shape as CapsuleShape3D).radius if player_shape is CapsuleShape3D else 0.4
	# Worst case: the player pressed against the box CORNER (a point at half-diagonal from the centre).
	var half_diagonal: float = Vector2(body_box.size.x, body_box.size.z).length() * 0.5
	var centre_distance: float = half_diagonal + player_radius
	# The melee queries are spheres at floor level; a target centre is hit out to sqrt((q+R)^2 - dy^2).
	var smallest_melee: float = INF
	smallest_melee = float(AttackDatabase.get_attack("light")["range"])
	for card: Dictionary in CardDatabase.all_cards():
		for effect: Dictionary in card.get("effects", []):
			var params: Dictionary = effect.get("params", {})
			if String(effect.get("template", "")) == "cone":
				smallest_melee = minf(smallest_melee, float(params["range"]))
			elif String(effect.get("template", "")) == "aoe":
				smallest_melee = minf(smallest_melee, float(params["radius"]))
	var reach: float = sqrt((smallest_melee + hurt_radius) * (smallest_melee + hurt_radius) - low_center * low_center)
	assert_float(reach).override_failure_message("a corner-pressed player (%.2f m from the golem centre) is out of reach of the shortest melee (%.2f m reach)" % [centre_distance, reach]).is_greater(centre_distance)


# =====================================================================================
# 4. Enemy telegraphs are the real hit, and end when they should
# =====================================================================================

func test_melee_wedge_is_the_real_hit_edge_radially_and_angularly() -> void:
	var main := _spawn_root_main()
	main.player.set_physics_process(false)
	main.player.health.set_max_health(9999.0)
	main.player.health.heal(9999.0)
	await _frames(2)
	var chaser := _enemy(main, CHASER_PATH, Vector3(0.0, 0.0, 10.0))  # far from the player; faces -Z
	chaser.set_physics_process(false)
	chaser.global_position = Vector3(0.0, 0.0, 0.0)
	chaser.rotation = Vector3.ZERO
	chaser._start_telegraph()
	var wedge: AttackArcVisual = chaser._wedge
	assert_object(wedge).is_not_null()
	var reach: float = VfxSizing.lateral_reach_vs_player(chaser.attack_range)
	var half_angle: float = EnemyConfig.melee_half_angle_degrees()
	# The drawn fan reaches exactly `reach` straight ahead and `reach * sin(half)` to the side.
	var fan := AttackArcVisual.build_fan(reach, half_angle)
	assert_float(fan.get_aabb().size.z).is_equal_approx(reach, 0.01)
	assert_float(fan.get_aabb().size.x).is_equal_approx(2.0 * reach * sin(deg_to_rad(half_angle)), 0.01)
	var cases: Array = [  # [distance, angle degrees from forward, expect hit]
		[reach - 0.04, 0.0, true], [reach + 0.04, 0.0, false],
		[1.2, half_angle - 3.0, true], [1.2, half_angle + 3.0, false],
		[1.2, -(half_angle - 3.0), true], [1.2, -(half_angle + 3.0), false],
	]
	for c: Array in cases:
		var a: float = deg_to_rad(float(c[1]))
		main.player.global_position = Vector3(sin(a), 0.0, -cos(a)) * float(c[0])
		await _frames(2)
		var hp_before: float = main.player.health.current_health
		chaser._execute_attack()
		var hit: bool = main.player.health.current_health < hp_before
		assert_bool(hit).override_failure_message("distance %.2f angle %.1f: expected hit=%s (the wedge must not lie)" % [float(c[0]), float(c[1]), str(c[2])]).is_equal(bool(c[2]))
		chaser._attack_cooldown_remaining = 0.0


func test_ranged_lane_width_is_the_real_shot_hit_width() -> void:
	var main := _spawn_root_main()
	main.player.set_physics_process(false)
	main.player.health.set_max_health(9999.0)
	main.player.health.heal(9999.0)
	await _frames(2)
	var half_width: float = VfxSizing.lateral_reach_vs_player(EnemyConfig.projectile_hit_radius())
	for offset: Array in [[half_width - 0.04, true], [half_width + 0.04, false], [-(half_width - 0.04), true], [-(half_width + 0.04), false]]:
		var shooter := _enemy(main, SHOOTER_PATH, Vector3.ZERO)
		shooter.set_physics_process(false)
		shooter.rotation = Vector3.ZERO
		main.player.global_position = Vector3(float(offset[0]), 0.0, -4.0)
		await _frames(2)
		var hp_before: float = main.player.health.current_health
		shooter._execute_attack()  # fires along -Z from the shooter
		await _frames(60)
		var hit: bool = main.player.health.current_health < hp_before
		assert_bool(hit).override_failure_message("lateral offset %.2f (half width %.2f): expected hit=%s" % [float(offset[0]), half_width, str(offset[1])]).is_equal(bool(offset[1]))
		shooter.free()
		for child in main.get_children():
			if child is Projectile:
				child.free()


func test_wedge_and_lane_end_on_stun_player_death_and_enemy_death() -> void:
	var main := _spawn_root_main()
	main.player.health.set_max_health(9999.0)
	main.player.health.heal(9999.0)
	main.player.set_physics_process(false)
	await _frames(2)
	main.player.global_position = Vector3(0.0, 0.0, 0.0)
	# --- melee: stun ---
	var chaser := _enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -1.2))
	await _frames(2)
	chaser._attack_cooldown_remaining = 0.0
	await _frames(3)
	assert_float(chaser._telegraph_remaining).is_greater(0.0)
	assert_bool(chaser._wedge.visible).is_true()
	chaser.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_bool(chaser._wedge.visible).override_failure_message("wedge still drawn after a stun").is_false()
	chaser.free()
	# --- melee: player death ---
	var chaser2 := _enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -1.2))
	await _frames(2)
	chaser2._attack_cooldown_remaining = 0.0
	await _frames(3)
	assert_bool(chaser2._wedge.visible).is_true()
	main.player.health.take_damage(99999.0)
	await _frames(3)
	assert_bool(main.player.is_dead()).is_true()
	assert_bool(chaser2._wedge.visible).override_failure_message("wedge still drawn after the player died").is_false()
	assert_float(chaser2._telegraph_remaining).is_equal(0.0)
	chaser2.free()
	# --- ranged: stun, player death, enemy death ---
	main.player.health.heal(9999.0)
	for reason in ["stun", "player_death", "enemy_death"]:
		var main2 := _spawn_root_main_replacement(main)
		main = main2
		await _frames(2)
		main.player.set_physics_process(false)
		var shooter := _enemy(main, SHOOTER_PATH, Vector3(0.0, 0.0, -5.0))
		await _frames(2)
		shooter._attack_cooldown_remaining = 0.0
		await _frames(3)
		var lane: PooledEffect = shooter._shot_lane
		var lane_generation: int = lane.generation if lane != null else -1
		var pool := EffectPool.for_world(main)
		assert_object(lane).override_failure_message("no lane for %s" % reason).is_not_null()
		assert_bool(pool.is_running(lane, lane_generation)).is_true()
		match reason:
			"stun":
				shooter.status_manager.apply_status("stun", _stun_def(), 0.6)
			"player_death":
				main.player.health.take_damage(99999.0)
				await _frames(3)
			"enemy_death":
				shooter.health.take_damage(99999.0)
		# (is_running, not .active: the freed lane node is recycled at once for the stun stars.)
		assert_bool(pool.is_running(lane, lane_generation)).override_failure_message("lane still drawn after %s" % reason).is_false()


## Replaces the current root Main with a fresh one (so a dead player from the previous round does not leak in).
func _spawn_root_main_replacement(old: Main) -> Main:
	if is_instance_valid(old):
		get_tree().current_scene = null
		old.free()
	_root_main = null
	return _spawn_root_main()


func _cancel_rings(pool: EffectPool) -> int:
	var found: int = 0
	for child in pool.get_children():
		var effect := child as PooledEffect
		if effect != null and effect.active and is_equal_approx(effect.base_size, VfxConfig.marker("windup_cancel_size")) and is_equal_approx(effect.duration, VfxConfig.marker("windup_cancel_duration")):
			found += 1
	return found


func test_stun_cancel_ring_only_when_a_windup_was_live() -> void:
	var main := _spawn_root_main()
	main.player.set_physics_process(false)
	await _frames(2)
	var pool := EffectPool.for_world(main)
	# Idle enemy (in grace, so no wind-up): a stun must not show a "cancelled" ring.
	var idle := _enemy(main, CHASER_PATH, Vector3(1.2, 0.0, 0.0))
	idle.begin_spawn_grace(5.0)
	await _frames(3)
	assert_float(idle._telegraph_remaining).is_equal(0.0)
	idle.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(_cancel_rings(pool)).override_failure_message("a cancel ring appeared though nothing was cancelled").is_equal(0)
	# A live wind-up: exactly one ring.
	var live := _enemy(main, CHASER_PATH, Vector3(-1.2, 0.0, 0.0))
	await _frames(2)
	live._attack_cooldown_remaining = 0.0
	await _frames(3)
	assert_float(live._telegraph_remaining).is_greater(0.0)
	live.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(_cancel_rings(pool)).override_failure_message("no cancel ring after stunning a live wind-up").is_equal(1)
	# A refresh of the same stun does not ring again.
	live.status_manager.apply_status("stun", _stun_def(), 0.6)
	assert_int(_cancel_rings(pool)).is_equal(1)


func test_enemy_projectile_never_shown_to_the_player_as_a_player_shot() -> void:
	# Team tint: the enemy shot's colour must differ from the player's colour for every damage type in the pools.
	for damage_type in ["physical", "fire"]:
		var p: Color = ElementVisuals.visual_for_team(damage_type, "player")["color"]
		var e: Color = ElementVisuals.visual_for_team(damage_type, "enemy")["color"]
		assert_bool(p == e).override_failure_message("%s: enemy shot looks exactly like the player's" % damage_type).is_false()
		assert_bool(p == ElementVisuals.color_for_damage_type(damage_type)).override_failure_message("the player must never be tinted").is_true()


# =====================================================================================
# 5. HP bar modes
# =====================================================================================

## An oracle written independently of EnemyHpBar.should_show.
func _expected_visible(mode: String, dead: bool, damaged: bool, fill: float, rank_name: String) -> bool:
	if dead:
		return false
	match mode:
		"after_damage":
			return damaged
		"hidden_at_full":
			return fill < 1.0
		"elite_boss_always":
			return damaged or rank_name != "normal"  # EnemyConfig.RANKS only allows normal, elite, boss
		_:
			return true  # always_alive and any unknown mode


func test_bar_truth_table_fill_rank_mode_exhaustive_with_unknown_mode() -> void:
	var modes: Array[String] = ALL_MODES.duplicate()
	modes.append_array(["", "bogus", "ALWAYS_ALIVE", "after damage"])
	var count: int = 0
	for mode in modes:
		for dead in [false, true]:
			for damaged in [false, true]:
				for fill in [0.0, 0.001, 0.5, 0.999, 1.0]:
					for rank_name in ["normal", "elite", "boss", "weird"]:
						var got: bool = EnemyHpBar.should_show(mode, dead, damaged, fill, rank_name)
						var want: bool = _expected_visible(mode, dead, damaged, fill, rank_name)
						assert_bool(got).override_failure_message("mode=%s dead=%s damaged=%s fill=%s rank=%s" % [mode, dead, damaged, fill, rank_name]).is_equal(want)
						count += 1
	assert_int(count).is_equal(8 * 2 * 2 * 5 * 4)


func test_invalid_visibility_mode_falls_back_loudly_to_always_alive() -> void:
	var table: Dictionary = UiConfig._table._cache
	var original: Variant = (table["hp_bars"] as Dictionary).get("visibility_mode")
	(table["hp_bars"] as Dictionary)["visibility_mode"] = "sometimes"
	var holder: Array[Dictionary] = []
	var assertion := await assert_error(func() -> void: holder.append(UiConfig.hp_bars()))
	assertion.is_push_error("data/ui.json hp_bars invalid: visibility_mode must be one of %s" % str(EnemyHpBar.MODES))
	(table["hp_bars"] as Dictionary)["visibility_mode"] = original
	assert_array(holder).has_size(1)
	assert_str(String(holder[0]["visibility_mode"])).is_equal("always_alive")


func test_bar_reads_the_owner_rank_live() -> void:
	var main := _spawn_root_main()
	main.player.set_physics_process(false)
	await _frames(2)
	var original: Variant = EnemyHpBar._shared_config.get("visibility_mode")
	EnemyHpBar._shared_config["visibility_mode"] = "elite_boss_always"
	var chaser := _enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -8.0))
	await _frames(3)
	var bar: EnemyHpBar = chaser.get_node("EnemyHpBar")
	var shown_as_normal: bool = bar.visible
	chaser.status_manager.rank = "boss"  # changed after _ready, as a scenario does
	var rank_now: String = bar.rank()
	chaser.health.take_damage(1.0)  # any health event re-evaluates visibility
	var shown_after: bool = bar.visible
	EnemyHpBar._shared_config["visibility_mode"] = original
	assert_bool(shown_as_normal).is_false()
	assert_str(rank_now).is_equal("boss")
	assert_bool(shown_after).is_true()


func test_dead_enemy_bar_is_hidden_in_every_mode() -> void:
	var main := _spawn_root_main()
	main.player.set_physics_process(false)
	await _frames(2)
	var original: Variant = EnemyHpBar._shared_config.get("visibility_mode")
	for mode in ALL_MODES:
		EnemyHpBar._shared_config["visibility_mode"] = mode
		var golem := _enemy(main, GOLEM_PATH, Vector3(0.0, 0.0, -9.0))
		await _frames(2)
		var bar: EnemyHpBar = golem.get_node("EnemyHpBar")
		golem.health.take_damage(99999.0)
		assert_bool(bar.visible).override_failure_message("dead enemy bar visible in %s" % mode).is_false()
		golem.free()
	EnemyHpBar._shared_config["visibility_mode"] = original


func test_hp_bar_block_validates_every_key() -> void:
	# S5-2 (was a PIN): every key of DEFAULT_HP_BARS is checked, so a typo fails loud.
	assert_array(UiConfig.validate_hp_bars(UiConfig.DEFAULT_HP_BARS.duplicate(true))).is_empty()
	var bad_values: Dictionary = {
		"visibility_mode": ["nope", 3, null],
		"width": [0.0, -1.0, "x", null],
		"height": [0.0, -0.1, "x", null],
		"ghost_drain_per_sec": [0.0, "x"],
		"border": [-0.1, "x"],
		"resist_border": [-0.1, "x"],
		"y_offset": [-1.0, "x"],
		"ghost_delay": [-0.1, "x"],
		"render_priority": ["x", 10.5, 127, -128, null],
		"ghost_enabled": ["yes", 1],
		"burn_status_id": ["", 4],
		"default_resistance_tint": ["zzz", 5],
		"colors": ["x", {"fill": "#e2483f"}, {"fill": "nope", "ghost": "#fff", "back": "#fff", "frame": "#fff", "burn": "#fff"}],
		"resistance_tints": ["x", {"fire": "nope"}],
	}
	for key: String in bad_values:
		for bad: Variant in bad_values[key]:
			var block: Dictionary = UiConfig.DEFAULT_HP_BARS.duplicate(true)
			block[key] = bad
			assert_array(UiConfig.validate_hp_bars(block)).override_failure_message("%s = %s should be rejected" % [key, str(bad)]).is_not_empty()
	# Every key of the defaults is covered above (a new default key without a check would slip through).
	for key: String in UiConfig.DEFAULT_HP_BARS:
		assert_bool(bad_values.has(key)).override_failure_message("add a bad-value case for hp_bars.%s" % key).is_true()
	var edge: Dictionary = UiConfig.DEFAULT_HP_BARS.duplicate(true)
	edge["render_priority"] = 126
	assert_array(UiConfig.validate_hp_bars(edge)).is_empty()
	edge["render_priority"] = -127
	assert_array(UiConfig.validate_hp_bars(edge)).is_empty()


# =====================================================================================
# 6. Render order and damage numbers
# =====================================================================================

func test_render_priority_order_numbers_above_bars_and_immune_above_numbers() -> void:
	var cfg: Dictionary = UiConfig.damage_numbers()
	var bars: Dictionary = UiConfig.hp_bars()
	assert_int(int(cfg["render_priority"])).is_greater(int(bars["render_priority"]))
	var number: DamageNumber = auto_free(DamageNumber.new())
	add_child(number)
	number.configure(cfg)
	number.show_amount(5.0, "physical", Color.WHITE, false)
	var word: DamageNumber = auto_free(DamageNumber.new())
	add_child(word)
	word.configure(cfg)
	word.show_text("IMMUNE", Color.WHITE, 1.0)
	assert_int(word.render_priority).is_greater(number.render_priority)
	assert_int(number.render_priority).is_greater(int(bars["render_priority"]))
	assert_int(word.outline_render_priority).is_less(word.render_priority)
	assert_int(word.outline_render_priority).is_greater_equal(number.render_priority)  # the word's outline is not under a number's text
	# And the engine's valid range (-128..127) is respected so nothing is silently clamped.
	assert_int(word.render_priority).is_between(-128, 127)


func test_bar_shader_is_opaque_so_no_alpha_sorting_against_numbers() -> void:
	var source := FileAccess.get_file_as_string("res://assets/shaders/enemy_hp_bar.gdshader")
	for line in source.split("
"):
		var code: String = line.split("//")[0]
		assert_bool(code.contains("ALPHA")).override_failure_message("a bar that writes ALPHA leaves the opaque pass: %s" % line).is_false()
	assert_bool(source.contains("blend_")).is_false()
	assert_bool(source.contains("depth_test_disabled")).is_false()


func test_damage_number_merge_cap_reset_and_no_mixing() -> void:
	var main := _spawn_root_main()
	await _frames(1)
	var spot := Vector3(2.0, 0.0, 2.0)
	Juice.spawn_damage_number(spot, 3.0, "physical")
	Juice.spawn_damage_number(spot + Vector3(0.3, 0.0, 0.0), 4.0, "physical")  # merges
	Juice.spawn_damage_number(spot, 5.0, "fire")  # same place, different type: must NOT merge
	assert_int(Juice._live_numbers.size()).is_equal(2)
	var texts: Array[String] = []
	for n in Juice._live_numbers:
		texts.append(n.text)
	texts.sort()
	assert_array(texts).is_equal(["5", "7"])
	# A killing blow merged into a young number is still counted in the total.
	Juice.spawn_damage_number(spot, 1000.0, "physical")
	var seven: DamageNumber = Juice._live_numbers[Juice._live_numbers.size() - 1]  # a merge moves it to the back (S5-5)
	assert_str(seven.text).is_equal("1007")
	# The cap: 100 far-apart hits leave at most max_alive numbers, in the tree and in the list.
	var cap: int = int(UiConfig.damage_numbers()["max_alive"])
	for i in range(100):
		Juice.spawn_damage_number(Vector3(float(i) * 3.0, 0.0, 0.0), 2.0, "physical")
		assert_int(Juice._live_numbers.size()).is_less_equal(cap)
	await get_tree().process_frame
	var in_tree: int = 0
	for child in main.get_children():
		if child is DamageNumber and not child.is_queued_for_deletion():
			in_tree += 1
	assert_int(in_tree).is_less_equal(cap)
	# reset() clears the list.
	Juice.reset()
	assert_int(Juice._live_numbers.size()).is_equal(0)


func test_cap_eviction_never_frees_a_number_that_just_took_a_killing_blow() -> void:
	# S5-5 (was a PIN): a merge moves the number to the back of the eviction order, so at the cap the
	# number that just took a big hit survives and the oldest untouched one is freed instead.
	var main := _spawn_root_main()
	await _frames(1)
	var cap: int = int(UiConfig.damage_numbers()["max_alive"])
	for i in range(cap):
		Juice.spawn_damage_number(Vector3(float(i) * 3.0, 0.0, 0.0), 2.0, "physical")
	assert_int(Juice._live_numbers.size()).is_equal(cap)
	var oldest: DamageNumber = Juice._live_numbers[0]
	var second: DamageNumber = Juice._live_numbers[1]
	Juice.spawn_damage_number(Vector3(0.0, 0.0, 0.0), 999.0, "physical")  # merges into the oldest
	assert_str(oldest.text).is_equal("1001")
	Juice.spawn_damage_number(Vector3(0.0, 0.0, 40.0), 1.0, "physical")  # one more, far away: evicts
	assert_bool(oldest.is_queued_for_deletion()).is_false()
	assert_bool(second.is_queued_for_deletion()).is_true()
	assert_int(Juice._live_numbers.size()).is_equal(cap)
	assert_object(main).is_not_null()


func test_damage_number_edge_values_do_not_error() -> void:
	var main := _spawn_root_main()
	await _frames(1)
	for amount in [0.0, 0.0001, -5.0, 1.0e6, 1.0e12]:
		Juice.spawn_damage_number(Vector3(7.0, 0.0, float(Juice._live_numbers.size()) * 3.0), amount, "physical")
	assert_int(Juice._live_numbers.size()).is_equal(5)
	assert_str((Juice._live_numbers[3] as DamageNumber).text).is_equal("1000000")
	assert_str((Juice._live_numbers[4] as DamageNumber).text).is_equal("1000000000000")
	assert_object(main).is_not_null()


func test_damage_number_list_survives_expiry_and_a_long_run_without_leaking() -> void:
	var main := _spawn_root_main()
	await _frames(1)
	# 3000 hits over simulated time: numbers expire (forced), the list is pruned of freed nodes, nothing accumulates.
	var peak: int = 0
	for i in range(3000):
		Juice.spawn_damage_number(Vector3(float(i % 7) * 2.0, 0.0, float(i % 5) * 2.0), 3.0, "physical" if i % 2 == 0 else "fire")
		for n in Juice._live_numbers:
			if is_instance_valid(n):
				n._process(0.2)  # fast-forward the life of every number
		peak = maxi(peak, Juice._live_numbers.size())
		if i % 20 == 0:
			await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(peak).is_less_equal(int(UiConfig.damage_numbers()["max_alive"]))
	var alive_nodes: int = 0
	for child in main.get_children():
		if child is DamageNumber and not child.is_queued_for_deletion():
			alive_nodes += 1
	assert_int(alive_nodes).is_less_equal(int(UiConfig.damage_numbers()["max_alive"]))


# =====================================================================================
# 7. Data validation: ui.json, vfx.json, scenarios
# =====================================================================================

func test_damage_numbers_bad_values_each_key() -> void:
	for key: String in UiConfig.DEFAULT_DAMAGE_NUMBERS:
		var bad: Dictionary = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
		for value: Variant in ["x", null, -1, 0, NAN]:
			bad[key] = value
			assert_array(UiConfig.validate_damage_numbers(bad)).override_failure_message("%s = %s should be rejected" % [key, str(value)]).is_not_empty()
	var missing: Dictionary = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	missing.erase("merge_radius")
	assert_array(UiConfig.validate_damage_numbers(missing)).is_not_empty()


func test_vfx_new_keys_reject_bad_values() -> void:
	for key in VfxConfig.MARKER_KEYS:
		for value: Variant in ["x", null, -1.0, 0.0, NAN]:
			var bad: Dictionary = VfxConfig.DEFAULTS.duplicate(true)
			bad[key] = value
			assert_array(VfxConfig.validate(bad)).override_failure_message("%s = %s should be rejected" % [key, str(value)]).is_not_empty()
		if key.ends_with("_alpha"):
			var big: Dictionary = VfxConfig.DEFAULTS.duplicate(true)
			big[key] = 1.01
			assert_array(VfxConfig.validate(big)).override_failure_message("%s above 1 should be rejected" % key).is_not_empty()
	for key in ["player_hurtbox_reach_radius", "player_hurtbox_low_center_height"]:
		var bad: Dictionary = VfxConfig.DEFAULTS.duplicate(true)
		bad[key] = "x"
		assert_array(VfxConfig.validate(bad)).is_not_empty()
		bad[key] = -0.5
		assert_array(VfxConfig.validate(bad)).is_not_empty()
	var tints: Dictionary = VfxConfig.DEFAULTS.duplicate(true)
	(tints["team_tints"] as Dictionary)["enemy"]["element_mix"] = -0.1
	assert_array(VfxConfig.validate(tints)).is_not_empty()
	assert_array(VfxConfig.validate(VfxConfig.DEFAULTS)).is_empty()


func test_new_scenario_flags_reject_bad_values_and_all_shipped_scenarios_validate() -> void:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenarios.json"))
	for scenario_id in parsed.keys():
		assert_array(ScenarioSchema.validate(String(scenario_id), parsed[scenario_id])).override_failure_message("scenario %s" % scenario_id).is_empty()
	for id in ["waves", "bar_modes", "pointy_shot", "stun_cancel"]:
		assert_bool(parsed.has(id)).override_failure_message("scenario %s missing" % id).is_true()
	for bad in [{"dense_waves": 1}, {"dense_waves": "yes"}, {"wave_seed": -1}, {"wave_seed": 1.5}, {"wave_seed": "a"}]:
		assert_array(ScenarioSchema.validate("s", bad)).override_failure_message("should reject %s" % str(bad)).is_not_empty()


# =====================================================================================
# 8. Tools still work (regression: 5b broke tools/bot_sim.gd, and run_bot_sim.ps1 still said OK)
# =====================================================================================

## tools/bot_sim.gd runs as `-s` (a SceneTree script) where autoloads such as Juice do not resolve at compile
## time. Any new static dependency from UiConfig/CardSchema into a class that names an autoload breaks it
## (5b: UiConfig.validate_hp_bars -> EnemyHpBar.MODES -> Enemy -> Juice). The unit-test runner has the
## autoloads, so only a child process catches this.
func test_old_bot_sim_script_compiles_and_runs_without_script_errors() -> void:
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tools/bot_sim.gd", "--", "--rooms=2"]
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "
".join(PackedStringArray(output))
	var bad: Array[String] = []
	for line in text.split("
"):
		if line.contains("SCRIPT ERROR") or line.begins_with("ERROR:"):
			bad.append(line)
	assert_array(bad).override_failure_message("bot_sim.gd printed script errors (first: %s)" % (bad[0] if not bad.is_empty() else "")).is_empty()
	assert_int(code).is_equal(0)
	assert_bool(text.contains("Bot-sim OK")).is_true()
