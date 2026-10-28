class_name Slice5dQaTest
extends GdUnitTestSuite
## qa for Polish 1 step 5d (separation steering, enemy stats in data, dummy out of Main).
## See docs/reviews/2026-10-28-polish1-5d-qa.md. Tests marked PIN record a known-wrong behaviour.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const SHOOTER_PATH := "res://scenes/enemies/RangedShooter.tscn"
const GOLEM_PATH := "res://scenes/enemies/FireResistantGolem.tscn"

var _main: Main = null


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null
	Juice.reset()


func _make_main() -> Main:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.player.process_mode = Node.PROCESS_MODE_DISABLED
	return _main


func _enemy(path: String, pos: Vector3) -> Enemy:
	var e: Enemy = (load(path) as PackedScene).instantiate()
	_main.add_child(e)
	e.global_position = pos
	e.target = _main.player
	return e


# --- Roster hygiene ------------------------------------------------------------------------------

func test_roster_has_no_stale_or_freed_entries_after_free_queue_free_and_scene_free() -> void:
	var baseline: int = Enemy._roster.size()
	_make_main()
	var made: Array[Enemy] = []
	for i in range(8):
		made.append(_enemy(CHASER_PATH, Vector3(float(i), 0.0, 5.0)))
	assert_int(Enemy._roster.size()).is_equal(baseline + 8)
	made[0].free()
	made[1].queue_free()
	await get_tree().process_frame
	assert_int(Enemy._roster.size()).is_equal(baseline + 6)
	get_tree().current_scene = null
	_main.free()
	_main = null
	assert_int(Enemy._roster.size()).is_equal(baseline)
	for entry in Enemy._roster:
		assert_bool(is_instance_valid(entry) and entry.is_inside_tree()).is_true()


func test_roster_has_no_duplicates_after_many_spawn_free_cycles() -> void:
	var baseline: int = Enemy._roster.size()
	for cycle in range(5):
		_make_main()
		for i in range(12):
			_enemy(CHASER_PATH, Vector3(float(i) - 6.0, 0.0, 6.0))
		get_tree().current_scene = null
		_main.free()
		_main = null
	assert_int(Enemy._roster.size()).is_equal(baseline)


## PIN (follow-up): _ready runs once, so an enemy taken out of the tree and put back is erased from the
## roster by _exit_tree and never re-added. Nothing in src/ reparents enemies today, so this is latent.
func test_pin_reparented_enemy_drops_out_of_roster() -> void:
	_make_main()
	var e := _enemy(CHASER_PATH, Vector3(3.0, 0.0, 3.0))
	assert_bool(Enemy._roster.has(e)).is_true()
	_main.remove_child(e)
	_main.add_child(e)
	assert_bool(Enemy._roster.has(e)).is_false()  # PIN: should be true once fixed (re-add on _enter_tree)


# --- Speed clamp ---------------------------------------------------------------------------------

## S5d-1 (found by qa; also makes separation_5d_test::test_steering_never_exceeds_own_move_speed red when
## the whole suite runs, because instance ids change which way each enemy swirls). An enemy that is in range
## and waiting out its cooldown adds `slide * move_speed * strength` with no clamp (strength 1.5 in data),
## so a crowded chaser reaches 5 to 7.5 m/s against a move_speed of 4. Fails before the fix.
func test_crowd_around_the_player_never_exceeds_move_speed_on_any_frame() -> void:
	for seed_value in [4242, 2]:
		_make_main()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var list: Array[Enemy] = []
		for i in range(12):
			var a := rng.randf_range(0.0, TAU)
			var e := _enemy(CHASER_PATH, _main.player.global_position + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(6.0, 9.0))
			e.attack_damage = 0.0
			list.append(e)
		var worst: float = 0.0
		for f in range(400):
			await get_tree().physics_frame
			for e in list:
				worst = maxf(worst, Vector2(e.velocity.x, e.velocity.z).length())
		assert_float(worst).is_less_equal(4.0 + 0.01)
		get_tree().current_scene = null
		_main.free()
		_main = null
		await get_tree().process_frame


# --- Walls, jitter, soft lock --------------------------------------------------------------------

func test_crowd_in_a_corner_stays_inside_the_arena_and_finite() -> void:
	_make_main()
	_main.player.global_position = Vector3(18.0, 0.0, 18.0)
	var list: Array[Enemy] = []
	for i in range(12):
		var e := _enemy(CHASER_PATH if i % 3 != 2 else GOLEM_PATH, Vector3(10.0 + float(i % 4), 0.0, 10.0 + float(i / 4)))
		e.begin_spawn_grace(99.0)
		list.append(e)
	for f in range(600):
		await get_tree().physics_frame
	for e in list:
		var p := e.global_position
		assert_bool(is_finite(p.x) and is_finite(p.y) and is_finite(p.z)).is_true()
		assert_float(absf(p.x)).is_less_equal(19.6)
		assert_float(absf(p.z)).is_less_equal(19.6)
		assert_float(p.y).is_greater(-1.0)


## Twelve chasers (the shipped cap) on a still player: after settling, nobody oscillates (heading flips
## between consecutive frames) and, with grace off, at least 10 of the 12 start a wind-up within 12 s (a full ring around the player cannot hold all 12).
func test_cap_crowd_settles_without_jitter_and_everyone_gets_to_attack() -> void:
	_make_main()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var list: Array[Enemy] = []
	for i in range(12):
		var a := rng.randf_range(0.0, TAU)
		var e := _enemy(CHASER_PATH, _main.player.global_position + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(6.0, 9.0))
		e.attack_damage = 0.0  # keep the still player unflinching
		list.append(e)
	var started: Dictionary = {}
	var flips: int = 0
	var samples: int = 0
	var last_dir: Array[Vector2] = []
	last_dir.resize(12)
	for f in range(720):
		await get_tree().physics_frame
		for i in range(12):
			var e: Enemy = list[i]
			if e._telegraph_remaining > 0.0:
				started[i] = true
			if f > 420 and e._telegraph_remaining <= 0.0:
				var d := Vector2(e.velocity.x, e.velocity.z)
				if d.length() > 0.5 and last_dir[i].length() > 0.5:
					samples += 1
					if d.normalized().dot(last_dir[i].normalized()) < -0.5:
						flips += 1
				last_dir[i] = d
	assert_int(started.size()).is_greater_equal(10)
	assert_int(flips).is_less_equal(maxi(samples / 20, 3))


# --- Scenes reload and TrainingDummy ------------------------------------------------------------

func test_dummy_scene_still_instantiates_for_tests_and_main_stays_clean() -> void:
	_make_main()
	var dummy: Node = (load("res://scenes/debug/TrainingDummy.tscn") as PackedScene).instantiate()
	_main.add_child(dummy)
	auto_free(dummy)
	assert_object(dummy).is_not_null()
	assert_array(SceneSelfCheck.find_problems(_main)).is_empty()


# --- Stats in data -------------------------------------------------------------------------------

func test_golem_windup_is_still_0_7_and_every_enemy_scene_has_no_stat_exports_left() -> void:
	assert_float(float(EnemyConfig.stats_for("fire_resistant_golem")["telegraph_duration"])).is_equal(0.7)
	for path in [CHASER_PATH, SHOOTER_PATH, GOLEM_PATH]:
		var text: String = FileAccess.get_file_as_string(path)
		for key in ["move_speed =", "attack_range =", "attack_damage =", "attack_cooldown =", "telegraph_duration =", "preferred_range =", "projectile_speed ="]:
			assert_bool(text.contains(key)).is_false()


## S5d-2 (found by qa): validate_stats() exists but nothing calls it, so the shipped validator accepts a
## missing or bad stats block (and get_config then crashes on a missing one). Fails before the fix.
func test_s5d_2_whole_config_validate_rejects_missing_or_bad_stats() -> void:
	var stats: Dictionary = EnemyConfig.stats_for("melee_chaser").duplicate()
	var good_enemy: Dictionary = {"rank": "normal", "scene": CHASER_PATH, "stats": stats}
	assert_array(EnemyConfig.validate_enemies({"melee_chaser": good_enemy})).is_empty()
	var no_stats: Dictionary = {"rank": "normal", "scene": CHASER_PATH}
	assert_array(EnemyConfig.validate_enemies({"melee_chaser": no_stats})).is_not_empty()
	var nan_stats: Dictionary = stats.duplicate()
	nan_stats["move_speed"] = NAN
	assert_array(EnemyConfig.validate_enemies({"x": {"rank": "normal", "scene": CHASER_PATH, "stats": nan_stats}})).is_not_empty()
	var str_num: Dictionary = stats.duplicate()
	str_num["attack_damage"] = "5"
	assert_array(EnemyConfig.validate_enemies({"x": {"rank": "normal", "scene": CHASER_PATH, "stats": str_num}})).is_not_empty()
	var huge: Dictionary = stats.duplicate()
	huge["attack_cooldown"] = 1.0e9
	assert_array(EnemyConfig.validate_enemies({"x": {"rank": "normal", "scene": CHASER_PATH, "stats": huge}})).is_not_empty()
	var bad_sep: Dictionary = {"radius": 1.0, "strength": 1.0, "readable_spacing": 1.0, "near_player_radius": 4.0, "x": 1}
	assert_array(EnemyConfig.validate_separation(bad_sep)).is_not_empty()
	bad_sep.erase("x")
	bad_sep["radius"] = NAN
	assert_array(EnemyConfig.validate_separation(bad_sep)).is_not_empty()
