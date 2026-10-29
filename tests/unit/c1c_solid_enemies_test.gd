class_name C1cSolidEnemiesTest
extends GdUnitTestSuite
## C1-c: data/player.json body.collide_with_enemies. true (shipped default) = player and enemy bodies
## block each other; false = bodies pass through each other exactly as before C1-c.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func after_test() -> void:
	PlayerConfig.reload()
	Enemy.set_player_body_suppressed(false)
	Juice.reset()
	Engine.time_scale = 1.0


func _set_flag(value: bool) -> void:
	var config: Dictionary = PlayerConfig.load_from(PlayerConfig.PATH)
	(config["body"] as Dictionary)["collide_with_enemies"] = value
	PlayerConfig._cache = config


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _enemy_at(main: Main, position: Vector3, chase: bool = false) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	if chase:
		enemy.target = main.player
	main.add_child(enemy)
	enemy.global_position = position
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


# --- data ----------------------------------------------------------------------------------

func test_shipped_data_has_the_flag_on_and_is_valid() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PlayerConfig.PATH))
	assert_array(PlayerConfig.validate(parsed)).is_empty()
	assert_bool(bool(parsed["body"]["collide_with_enemies"])).is_true()
	assert_bool(PlayerConfig.collide_with_enemies()).is_true()


func test_validation_of_the_body_block() -> void:
	var good: Dictionary = {"dodge": {"speed": 20.0, "duration": 0.25, "cooldown": 0.8, "block_ticks_after_pause": 2}}
	assert_array(PlayerConfig.validate(good)).override_failure_message("no body block = defaults").is_empty()
	for value: Variant in [true, false]:
		var ok: Dictionary = good.duplicate(true)
		ok["body"] = {"collide_with_enemies": value}
		assert_array(PlayerConfig.validate(ok)).is_empty()
	for bad: Variant in [{"collide_with_enemies": 1}, {"collide_with_enemies": "true"}, {"collide_with_enemies": null},
			{}, {"collide_with_enemies": true, "extra": 1}, {"nope": true}, "body", 3]:
		var broken: Dictionary = good.duplicate(true)
		broken["body"] = bad
		assert_array(PlayerConfig.validate(broken)).override_failure_message("accepted %s" % str(bad)).is_not_empty()


func test_a_missing_body_block_loads_as_the_default_true() -> void:
	assert_bool(bool((PlayerConfig.DEFAULTS["body"] as Dictionary)["collide_with_enemies"])).is_true()


# --- masks -----------------------------------------------------------------------------------

func test_flag_true_gives_both_bodies_the_others_layer() -> void:
	_set_flag(true)
	var main := _spawn_main()
	var enemy := _enemy_at(main, main.player.global_position + Vector3(0, 0, -6))
	await _frames(1)
	assert_int(main.player.collision_mask).is_equal(CollisionLayers.WORLD | CollisionLayers.ENEMY_BODY)
	assert_int(enemy.collision_mask).is_equal(CollisionLayers.WORLD | CollisionLayers.ENEMY_BODY | CollisionLayers.PLAYER_BODY)


func test_flag_false_keeps_the_pre_c1c_masks() -> void:
	_set_flag(false)
	var main := _spawn_main()
	var enemy := _enemy_at(main, main.player.global_position + Vector3(0, 0, -6))
	await _frames(1)
	assert_int(main.player.collision_mask).is_equal(CollisionLayers.WORLD)
	assert_int(enemy.collision_mask).is_equal(CollisionLayers.WORLD | CollisionLayers.ENEMY_BODY)


# --- behaviour ---------------------------------------------------------------------------------

func _walk_into_enemy(flag: bool, dodge: bool) -> float:
	_set_flag(flag)
	var main := _spawn_main()
	var player := main.player
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 2.0)
	await _frames(2)
	var start := player.global_position
	player.start_forced_move(facing, 15.0, 0.4, dodge)
	await _frames(40)
	var travelled := (player.global_position - start).dot(facing)
	return travelled


## One world per test: a second Main spawned in the same test starts with its player displaced onto
## the first world's leftovers, which makes the numbers meaningless.
func test_solid_enemies_stop_the_player() -> void:
	var walked: float = await _walk_into_enemy(true, false)
	assert_float(walked).override_failure_message("a solid enemy stops the player short (walked %.2f)" % walked).is_less(1.3)


func test_the_dodge_does_not_pass_through_solid_enemies() -> void:
	var dodged: float = await _walk_into_enemy(true, true)
	assert_float(dodged).override_failure_message("the dodge is blocked too (travelled %.2f)" % dodged).is_less(1.3)


func test_flag_false_walks_through_exactly_as_before() -> void:
	var walked: float = await _walk_into_enemy(false, false)
	assert_float(walked).is_equal_approx(6.0, 0.1)


func test_flag_false_dodge_goes_through_exactly_as_before() -> void:
	var dodged: float = await _walk_into_enemy(false, true)
	assert_float(dodged).is_equal_approx(6.0, 0.1)


func test_pass_through_lets_the_player_through_a_solid_enemy_with_no_fixture() -> void:
	_set_flag(true)
	var main := _spawn_main()
	var player := main.player
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 2.0)
	await _frames(2)
	var start := player.global_position
	player.grant_pass_through(1.0)
	player.start_forced_move(facing, 15.0, 0.4)
	await _frames(40)
	assert_float((player.global_position - start).dot(facing)).is_equal_approx(6.0, 0.1)
	await _frames(70)
	assert_bool(player.is_pass_through()).is_false()
	assert_int(player.collision_mask & CollisionLayers.ENEMY_BODY).is_equal(CollisionLayers.ENEMY_BODY)


## Crowd of chasers on a player standing in the corner: nothing may push the player out of the arena,
## and no NaN. Run for both flag values and for a player who also keeps driving into the walls.
func _crowd_in_corner(flag: bool, walk_into_wall: bool) -> void:
	_set_flag(flag)
	var main := _spawn_main()
	var player := main.player
	var rect := player.get_arena_rect()
	var corner := Vector3(rect.position.x + 1.0, 0.0, rect.position.y + 1.0)
	player.global_position = corner
	for i in range(6):
		_enemy_at(main, corner + Vector3(1.5 + 0.2 * i, 0.0, 1.5 + 0.7 * i), true)
	for i in range(240):
		if walk_into_wall:
			player.start_forced_move(Vector3(-1, 0, -1).normalized(), 6.0, 0.05)
		await _frames(1)
		var p := player.global_position
		assert_bool(is_nan(p.x) or is_nan(p.z) or is_nan(p.y)).is_false()
		assert_bool(rect.grow(0.05).has_point(Vector2(p.x, p.z))).override_failure_message("player left the arena at frame %d: %s" % [i, str(p)]).is_true()
		assert_float(p.y).is_between(-0.5, 1.0)


func test_a_crowd_cannot_shove_the_player_through_the_walls_flag_true() -> void:
	await _crowd_in_corner(true, false)


func test_a_crowd_and_a_player_driving_into_the_walls_stay_inside_flag_true() -> void:
	await _crowd_in_corner(true, true)


func test_a_crowd_cannot_shove_the_player_through_the_walls_flag_false() -> void:
	await _crowd_in_corner(false, false)


func test_pass_through_ending_inside_a_crowd_in_the_corner_keeps_the_player_in_the_arena() -> void:
	_set_flag(true)
	var main := _spawn_main()
	var player := main.player
	var rect := player.get_arena_rect()
	var corner := Vector3(rect.position.x + 1.0, 0.0, rect.position.y + 1.0)
	player.global_position = corner
	player.grant_pass_through(0.3)
	for i in range(3):
		_enemy_at(main, corner + Vector3(0.3 * i, 0.0, 0.3), true)  # all overlapping the player
	await _frames(60)  # the buff ends at frame ~18 with everyone inside everyone
	assert_bool(player.is_pass_through()).is_false()
	for i in range(120):
		await _frames(1)
		var p := player.global_position
		assert_bool(rect.grow(0.05).has_point(Vector2(p.x, p.z))).override_failure_message("left the arena at frame %d: %s" % [i, str(p)]).is_true()
		assert_bool(is_nan(p.x) or is_nan(p.z)).is_false()


func test_separation_steering_still_spreads_a_crowd_that_chases_a_solid_player() -> void:
	_set_flag(true)
	var main := _spawn_main()
	var player := main.player
	var enemies: Array[Enemy] = []
	for i in range(5):
		enemies.append(_enemy_at(main, player.global_position + Vector3(-6.0 + 3.0 * i, 0.0, -8.0), true))
	await _frames(300)
	var worst := INF
	for i in range(enemies.size()):
		for j in range(i + 1, enemies.size()):
			worst = minf(worst, enemies[i].global_position.distance_to(enemies[j].global_position))
	assert_float(worst).override_failure_message("closest pair %.2f m" % worst).is_greater(0.8)
