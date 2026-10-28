class_name PlayerDeathTest
extends GdUnitTestSuite
## Player death: idempotence, blocked actions, enemy/spawner stand-down, restart prep.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func after_test() -> void:
	Juice.reset()


func test_dies_at_exactly_zero() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	var deaths: Array[int] = []
	player.player_died.connect(func() -> void: deaths.append(1))
	player.health.take_damage(player.health.get_max_health())
	assert_float(player.health.current_health).is_equal(0.0)
	assert_bool(player.is_dead()).is_true()
	assert_bool(player.can_act()).is_false()
	assert_array(deaths).has_size(1)


func test_dies_when_overkilled() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	main.player.health.take_damage(main.player.health.get_max_health() * 5.0)
	assert_float(main.player.health.current_health).is_equal(0.0)
	assert_bool(main.player.is_dead()).is_true()


func test_two_hits_same_frame_one_death() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	var deaths: Array[int] = []
	player.player_died.connect(func() -> void: deaths.append(1))
	var lethal := player.health.get_max_health()
	player.health.take_damage(lethal)
	player.health.take_damage(lethal)
	assert_array(deaths).has_size(1)


func test_hit_plus_burn_tick_same_frame_one_death() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	var deaths: Array[int] = []
	player.player_died.connect(func() -> void: deaths.append(1))
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = player.health
	manager.apply_status("burn", {"damage_per_tick": 999.0, "damage_type": "fire", "tick_interval": 0.5}, 2.0)
	player.health.take_damage(999.0)
	manager._process(0.5)
	assert_array(deaths).has_size(1)


func test_actions_blocked_after_death() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	player.health.take_damage(999.0)
	var start := player.global_position
	# Dodge/dash requests are refused once dead.
	player.start_forced_move(Vector3.RIGHT, 14.0, 0.25, true)
	assert_float(player._forced_move_time_remaining).is_equal(0.0)
	# Held input cannot move or act: simulate pressed actions, run physics.
	Input.action_press("move_forward")
	Input.action_press("attack_basic")
	Input.action_press("dodge")
	Input.action_press("slot_1")
	var cooldown_before := player._attack_cooldown_remaining
	for i in range(5):
		player._physics_process(0.016)
	Input.action_release("move_forward")
	Input.action_release("attack_basic")
	Input.action_release("dodge")
	Input.action_release("slot_1")
	assert_float(player._attack_cooldown_remaining).is_equal(cooldown_before)
	assert_float(player._dodge_cooldown_remaining).is_equal(0.0)
	assert_float(player.global_position.distance_to(start)).is_less(0.05)
	# Dead player cannot be damaged (Health guard) and is not targetable.
	assert_bool(player.hurtbox.collision_layer == 0).is_true()


func test_enemy_stops_targeting_dead_player() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var enemy: Enemy = auto_free((load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate())
	enemy.target = main.player
	main.add_child(enemy)
	await get_tree().process_frame
	assert_bool(enemy._has_live_target()).is_true()
	main.player.health.take_damage(999.0)
	assert_bool(enemy._has_live_target()).is_false()
	enemy._telegraph_remaining = 0.3
	enemy._physics_process(0.016)
	assert_float(enemy._telegraph_remaining).is_equal(0.0)
	assert_float(Vector2(enemy.velocity.x, enemy.velocity.z).length()).is_less(0.01)


func test_spawner_stops_after_death() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var spawner: EnemySpawner = auto_free(EnemySpawner.new())
	spawner.target = main.player
	spawner.enemy_scenes = [load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene]
	spawner._wave_timer = 0.0
	main.player.health.take_damage(999.0)
	spawner._process(1.0)
	assert_float(spawner._wave_timer).is_equal(0.0)


func test_game_over_announced_once_after_beat() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var announced: Array[int] = []
	main.game_over_ready.connect(func() -> void: announced.append(1))
	main.player.health.take_damage(999.0)
	main.player.health.take_damage(999.0)
	assert_array(announced).is_empty()
	await await_millis(1600)
	assert_array(announced).has_size(1)
	assert_bool(main.is_game_over()).is_true()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_restart_prep_resets_time_scale() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	Juice.slow_mo(5.0, 0.25)
	assert_float(Engine.time_scale).is_equal(0.25)
	main._prepare_for_restart()
	assert_float(Engine.time_scale).is_equal(1.0)
	await get_tree().process_frame
	assert_float(Engine.time_scale).is_equal(1.0)


func test_death_beat_config_validation() -> void:
	assert_array(UiConfig.validate_death_beat(UiConfig.death_beat())).is_empty()
	assert_array(UiConfig.validate_death_beat({"slow_mo_scale": 0.0, "slow_mo_duration": 1.0, "collapse_duration": 1.0})).is_not_empty()
	assert_array(UiConfig.validate_death_beat({"slow_mo_scale": 2.0, "slow_mo_duration": 1.0, "collapse_duration": 1.0})).is_not_empty()
	assert_array(UiConfig.validate_death_beat({"slow_mo_scale": 0.5})).is_not_empty()


## Stand-in for restart cycles (a real reload can't run inside the test
## runner): build, kill, and free Main five times; orphan nodes must not grow.
func test_repeated_death_and_teardown_does_not_leak_nodes() -> void:
	var baseline := -1
	for i in range(5):
		var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
		(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
		add_child(main)
		await get_tree().process_frame
		main.player.health.take_damage(999.0)
		main._prepare_for_restart()
		remove_child(main)
		main.free()
		await get_tree().process_frame
		await get_tree().process_frame
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		if i == 0:
			baseline = orphans
		assert_int(orphans).is_less_equal(baseline)
	assert_float(Engine.time_scale).is_equal(1.0)
