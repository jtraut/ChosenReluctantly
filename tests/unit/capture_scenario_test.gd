class_name CaptureScenarioTest
extends GdUnitTestSuite
## Arg parsing for screenshot tooling and the hp_bars scenario state (no rendering).


func test_parse_no_args_means_nothing_enabled() -> void:
	var cfg := CaptureArgs.parse(PackedStringArray())
	assert_array(cfg["times"]).is_empty()
	assert_str(cfg["scenario"]).is_empty()


func test_parse_after_list_out_and_scenario() -> void:
	var cfg := CaptureArgs.parse(PackedStringArray(["--screenshot-after=1.5,3", "--screenshot-out=C:/x/a.png", "--scenario=hp_bars"]))
	assert_array(cfg["times"]).contains_exactly([1.5, 3.0])
	assert_str(cfg["out"]).is_equal("C:/x/a.png")
	assert_str(cfg["scenario"]).is_equal("hp_bars")


func test_parse_count_and_interval() -> void:
	var cfg := CaptureArgs.parse(PackedStringArray(["--screenshot-count=3", "--screenshot-interval=2"]))
	assert_array(cfg["times"]).contains_exactly([2.0, 4.0, 6.0])


func test_parse_ignores_garbage_times() -> void:
	var cfg := CaptureArgs.parse(PackedStringArray(["--screenshot-after=abc,-1,2"]))
	assert_array(cfg["times"]).contains_exactly([2.0])


func test_output_path_single_and_multiple() -> void:
	assert_str(CaptureArgs.output_path("a/b.png", 0, 1)).is_equal("a/b.png")
	assert_str(CaptureArgs.output_path("a/b.png", 1, 3)).is_equal("a/b_1.png")
	assert_str(CaptureArgs.output_path("a/dir", 0, 1)).is_equal("a/dir/shot.png")


func test_hp_bars_scenario_state() -> void:
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	var scenario := Scenario.setup(main, "hp_bars")
	assert_object(scenario).is_not_null()
	var enemies := scenario.enemies()
	assert_int(enemies.size()).is_equal(9)
	assert_float(enemies[0].health.get_current_health()).is_equal(enemies[0].health.get_max_health())
	assert_float(enemies[4].health.get_current_health()).is_less(enemies[4].health.get_max_health() * 0.3)
	var burn: StatusEffectManager = enemies[1].get_node("StatusEffectManager")
	assert_bool(burn.has_status("burn")).is_true()
	var no_burn: StatusEffectManager = enemies[0].get_node("StatusEffectManager")
	assert_bool(no_burn.has_status("burn")).is_false()
	assert_float(main.player.health.get_max_health()).is_greater(1000.0)
