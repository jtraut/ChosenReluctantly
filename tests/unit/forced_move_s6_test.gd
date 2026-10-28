class_name ForcedMoveS6Test
extends GdUnitTestSuite
## S6-2: a forced move (dodge roll, dash card) ends at its data distance at any physics rate, stops
## without coasting, and the dodge's i-frames and cooldown are unchanged.

var _main: Main = null


func after_test() -> void:
	Engine.physics_ticks_per_second = 60
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null


func _spawn() -> Player:
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.player.camera = null
	await get_tree().physics_frame
	return _main.player


func _travel(speed: float, duration: float, ticks: int) -> Array[float]:
	Engine.physics_ticks_per_second = ticks
	var player := await _spawn()
	var start := player.global_position
	var facing := player.get_aim_direction()
	player.start_forced_move(facing, speed, duration, false)
	while player._forced_move_time_remaining > 0.0:
		await get_tree().physics_frame
	await get_tree().physics_frame
	var driven := (player.global_position - start).dot(facing)
	for i in range(ticks):
		await get_tree().physics_frame
	var rest := (player.global_position - start).dot(facing)
	return [driven, rest]


func test_distance_is_speed_times_duration_at_any_physics_rate_and_does_not_coast() -> void:
	for ticks: int in [30, 60, 120]:
		var result := await _travel(15.0, 4.0 / 15.0, ticks)
		assert_float(result[0]).override_failure_message("%d tps: driven %.3f" % [ticks, result[0]]).is_equal_approx(4.0, 0.02)
		assert_float(result[1]).override_failure_message("%d tps: rest %.3f" % [ticks, result[1]]).is_equal_approx(4.0, 0.02)
		get_tree().current_scene = null
		_main.free()
		_main = null


func test_dodge_invulnerability_lasts_its_duration_and_cooldown_is_unchanged() -> void:
	var player := await _spawn()
	assert_float(player.dodge_duration).is_equal(0.25)
	assert_float(player.dodge_cooldown).is_equal(0.8)
	player.start_forced_move(player.get_aim_direction(), player.dodge_speed, player.dodge_duration, true)
	assert_bool(player.hurtbox.collision_layer == 0).is_true()
	var ticks := 0
	while player._forced_move_time_remaining > 0.0 and ticks < 100:
		await get_tree().physics_frame
		ticks += 1
	# 0.25 s at 60 Hz is 15 ticks (16 when the float lands just over).
	assert_int(ticks).is_between(15, 16)
	assert_bool(player.hurtbox.collision_layer == 0).is_false()
