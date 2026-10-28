class_name Slice1QaTest
extends GdUnitTestSuite
## qa additions for Slice 1: the scenario-only kill hook must not exist in normal play,
## and the HUD HP value is labelled. (The real reload path is exercised by
## tools/run_reload_cycle.ps1, because reloading the scene inside gdUnit would reload the runner.)

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func after_test() -> void:
	Juice.reset()


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func test_plain_main_has_no_scenario_node_so_kill_hook_cannot_fire() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	for child in main.get_children():
		assert_bool(child is Scenario).is_false()
	# Even with time passing, a healthy player stays alive.
	for i in range(30):
		await get_tree().process_frame
	assert_bool(main.player.is_dead()).is_false()
	assert_bool(main.is_game_over()).is_false()


func test_kill_player_at_only_appears_in_scenario_data() -> void:
	var def := Scenario.load_def("hp_bars")
	assert_bool(def.has("kill_player_at")).is_false()
	assert_bool(Scenario.load_def("game_over").has("kill_player_at")).is_true()


func test_hud_hp_value_is_labelled() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var found := false
	for label in main.hud.find_children("*", "Label", true, false):
		if (label as Label).text.begins_with("HP "):
			found = true
	assert_bool(found).is_true()


func test_dead_player_burn_tick_does_not_change_health_or_redie() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	var deaths: Array[int] = []
	player.player_died.connect(func() -> void: deaths.append(1))
	player.health.take_damage(player.health.get_max_health(), "physical")
	player.health.take_damage(50.0, "fire")
	assert_float(player.health.current_health).is_equal(0.0)
	assert_array(deaths).has_size(1)


func test_game_over_ready_fires_exactly_once_after_two_lethal_hits() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var fired: Array[int] = []
	main.game_over_ready.connect(func() -> void: fired.append(1))
	main.player.health.take_damage(1000.0, "physical")
	main.player.health.take_damage(1000.0, "physical")
	var deadline := Time.get_ticks_msec() + 4000
	while fired.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_array(fired).has_size(1)
	assert_bool(main.is_game_over()).is_true()
