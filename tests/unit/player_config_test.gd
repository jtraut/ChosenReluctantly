class_name PlayerConfigTest
extends GdUnitTestSuite
## data/player.json: dodge values come from data (D8 = C: 20 m/s x 0.25 s = 5.0 m).

var _main: Main = null


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null
	PlayerConfig.reload()


func test_shipped_data_is_valid_and_dodge_travels_5_metres() -> void:
	assert_array(PlayerConfig.validate(JSON.parse_string(FileAccess.get_file_as_string(PlayerConfig.PATH)))).is_empty()
	var dodge: Dictionary = PlayerConfig.dodge()
	assert_float(float(dodge["speed"])).is_equal(20.0)
	assert_float(float(dodge["duration"])).is_equal(0.25)
	assert_float(float(dodge["cooldown"])).is_equal(0.8)
	assert_int(int(dodge["block_ticks_after_pause"])).is_equal(2)
	assert_float(float(dodge["speed"]) * float(dodge["duration"])).is_equal_approx(5.0, 0.0001)


func test_player_takes_dodge_values_from_data_and_travels_the_data_distance() -> void:
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	var player: Player = _main.player
	player.camera = null
	var dodge: Dictionary = PlayerConfig.dodge()
	assert_float(player.dodge_speed).is_equal(float(dodge["speed"]))
	assert_float(player.dodge_duration).is_equal(float(dodge["duration"]))
	assert_float(player.dodge_cooldown).is_equal(float(dodge["cooldown"]))
	assert_int(player.dodge_block_ticks_after_pause).is_equal(int(dodge["block_ticks_after_pause"]))
	await get_tree().physics_frame
	var start := player.global_position
	var facing := player.get_aim_direction()
	player.start_forced_move(facing, player.dodge_speed, player.dodge_duration, true)
	for i in range(60):
		await get_tree().physics_frame
	var rest := (player.global_position - start).dot(facing)
	assert_float(rest).override_failure_message("dodge travelled %.3f m" % rest).is_equal_approx(float(dodge["speed"]) * float(dodge["duration"]), 0.05)


func test_validation_rejects_bad_dodge_data() -> void:
	var good: Dictionary = {"dodge": {"speed": 20.0, "duration": 0.25, "cooldown": 0.8, "block_ticks_after_pause": 2}}
	assert_array(PlayerConfig.validate(good)).is_empty()
	assert_array(PlayerConfig.validate("nope")).is_not_empty()
	assert_array(PlayerConfig.validate({})).is_not_empty()
	for bad: Dictionary in [
		{"speed": 0.0}, {"speed": -3.0}, {"speed": "fast"}, {"duration": 0.0}, {"duration": 99.0},
		{"cooldown": -0.1}, {"block_ticks_after_pause": 1.5}, {"block_ticks_after_pause": -1}, {"extra_key": 1.0},
	]:
		var copy: Dictionary = good.duplicate(true)
		(copy["dodge"] as Dictionary).merge(bad, true)
		assert_array(PlayerConfig.validate(copy)).override_failure_message("accepted %s" % str(bad)).is_not_empty()
	var missing: Dictionary = good.duplicate(true)
	(missing["dodge"] as Dictionary).erase("cooldown")
	assert_array(PlayerConfig.validate(missing)).is_not_empty()
