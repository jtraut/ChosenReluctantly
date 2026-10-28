class_name Pause6aTest
extends GdUnitTestSuite
## Slice 6a: the pause API (GamePause) and how it keeps Juice's time scale, hit-stop and
## the death slow-mo honest. Settings are injected so the real user file is untouched.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"

var _original_store: SettingsStore = null
var _root_main: Main = null


func before_test() -> void:
	CardDatabase.load_all()
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, "user://tests/never_written_settings.cfg"))


func after_test() -> void:
	GamePause.resume()
	GamePause.reset()
	get_tree().paused = false
	Settings.use_store(_original_store)
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()
	TestInput.release(&"slot_1")


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


## Real seconds, counted by a timer that keeps running while paused and ignores time scale.
func _real_wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	main.player.card_slots.spawn_parent = main
	main.player.camera = null
	return main


func test_pause_and_resume_flip_the_tree_and_signal_once_each() -> void:
	var seen: Array[bool] = []
	GamePause.paused_changed.connect(func(is_paused: bool) -> void: seen.append(is_paused))
	assert_bool(GamePause.is_paused()).is_false()
	assert_bool(GamePause.pause()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(GamePause.is_paused()).is_true()
	assert_bool(GamePause.pause()).is_false()
	assert_bool(GamePause.resume()).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(GamePause.resume()).is_false()
	assert_array(seen).is_equal([true, false])
	assert_bool(GamePause.toggle()).is_true()
	assert_bool(GamePause.toggle()).is_false()


func test_pausing_without_a_hit_stop_leaves_time_at_one() -> void:
	GamePause.pause()
	assert_float(Engine.time_scale).is_equal(1.0)
	GamePause.resume()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool(Juice.is_time_frozen()).is_false()


func test_pause_during_hit_stop_shows_normal_time_and_resume_restores_the_rest() -> void:
	Juice.hit_stop(0.8, 0.1)
	assert_float(Engine.time_scale).is_equal_approx(0.1, 0.0001)
	GamePause.pause()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool(Juice.is_time_frozen()).is_true()
	await _real_wait(0.5)  # a long pause must not eat the hit-stop
	assert_float(Engine.time_scale).is_equal(1.0)
	GamePause.resume()
	assert_float(Engine.time_scale).is_equal_approx(0.1, 0.0001)
	var left_msec: int = Juice._hitstop_resume_msec - Time.get_ticks_msec()
	assert_int(left_msec).is_between(600, 800)  # ~0.8 s were left when pausing
	await _real_wait(1.0)
	assert_float(Engine.time_scale).is_equal(1.0)  # and it still ends by itself


func test_a_hit_stop_requested_while_paused_is_ignored() -> void:
	GamePause.pause()
	Juice.hit_stop(0.5, 0.05)
	assert_float(Engine.time_scale).is_equal(1.0)
	GamePause.resume()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_a_hit_stop_that_ended_during_the_pause_does_not_come_back() -> void:
	Juice.hit_stop(0.05, 0.1)
	await _real_wait(0.1)  # let it end on its own first
	GamePause.pause()
	GamePause.resume()
	assert_float(Engine.time_scale).is_equal(1.0)


func test_reset_clears_a_frozen_state() -> void:
	Juice.hit_stop(0.8, 0.1)
	GamePause.pause()
	Juice.reset()
	assert_bool(Juice.is_time_frozen()).is_false()
	GamePause.reset()
	get_tree().paused = false
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool(GamePause.is_paused()).is_false()


func test_pause_during_the_death_slow_mo_holds_game_over_and_restores_the_beat() -> void:
	var main := _main()
	await _frames(2)
	var announced: Array[bool] = []
	main.game_over_ready.connect(func() -> void: announced.append(true))
	var player := main.player
	player.health.take_damage(player.health.get_max_health() * 2.0)
	var beat := UiConfig.death_beat()
	assert_float(Engine.time_scale).is_equal_approx(float(beat["slow_mo_scale"]), 0.0001)
	GamePause.pause()
	assert_float(Engine.time_scale).is_equal(1.0)
	await _real_wait(float(beat["slow_mo_duration"]) + 0.5)
	assert_array(announced).is_empty()  # Game Over must not appear over the pause screen
	assert_bool(main.is_game_over()).is_false()
	GamePause.resume()
	assert_float(Engine.time_scale).is_equal_approx(float(beat["slow_mo_scale"]), 0.0001)
	await _real_wait(float(beat["slow_mo_duration"]) + 0.5)
	assert_array(announced).has_size(1)
	assert_float(Engine.time_scale).is_equal(1.0)


func test_pausing_cancels_a_held_card_preview_and_it_needs_a_fresh_press() -> void:
	var main := _main()
	await _frames(2)
	var player := main.player
	var casts: Array[String] = []
	player.card_slots.card_cast.connect(func(slot_type: String, _card: String) -> void: casts.append(slot_type))
	TestInput.press(&"slot_1")
	await _frames(2)
	assert_bool(player.cast_input.is_previewing()).is_true()
	GamePause.pause()
	assert_bool(player.cast_input.is_previewing()).is_false()
	assert_bool(player.get_preview_state()["active"]).is_false()
	TestInput.release(&"slot_1")  # lost to the pause in real play; harmless either way
	GamePause.resume()
	TestInput.release(&"slot_1")
	await _frames(3)
	assert_array(casts).is_empty()
	TestInput.press(&"slot_1")
	await _frames(2)
	assert_bool(player.cast_input.is_previewing()).is_true()


func test_pause_is_refused_once_game_over_is_up() -> void:
	var main := _main()
	await _frames(2)
	main.player.health.take_damage(main.player.health.get_max_health() * 2.0)
	await _real_wait(float(UiConfig.death_beat()["slow_mo_duration"]) + 0.5)
	assert_bool(main.is_game_over()).is_true()
	assert_bool(GamePause.pause()).is_false()
	assert_bool(get_tree().paused).is_false()
