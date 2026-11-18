class_name Df1QaTest
extends GdUnitTestSuite
## DF1 qa. Gaps found in sitting A's coverage: (1) a curse cast still uses up a primed buff, (2) an act-change map failure ends the run
## with the player ALIVE, so the Game Over screen (driven only by Main.player_died) must still be shown, (3) --event / --merchant room conversion.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PATH := "user://tests/df1_qa_run_save.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RelicDatabase.load_all()


func after_test() -> void:
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RunSession.forced_event = ""
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func test_a_curse_cast_still_uses_up_a_primed_buff() -> void:
	var stats := StatModifiers.new()
	var caster: Node3D = auto_free(Node3D.new())
	add_child(caster)
	var controller := CardSlotController.new(caster, caster, "player", stats, ["rogue_bad_influence"] as Array[String])
	controller.set_deck(["curse_mandatory_training", "curse_mandatory_training"] as Array[String])
	stats.add_primed_modifier("damage_dealt", "qa_prime", StatModifiers.ADDITIVE, 0.5, "utility", 1, 30.0)
	assert_array(stats.primed_ids()).contains_exactly(["qa_prime"])
	assert_str(controller.get_slot("utility").current_card_id).is_equal("curse_mandatory_training")
	assert_bool(controller.try_use("utility")).is_true()
	assert_array(stats.primed_ids()).override_failure_message("a curse cast must still use up a primed buff").is_empty()


func test_an_act_change_map_failure_shows_the_game_over_screen_with_the_player_alive() -> void:
	var tight: Dictionary = MapConfig.get_config().duplicate(true)
	tight["max_attempts"] = 1
	var run_seed: int = -1
	for candidate in range(1, 200):
		var probe: RunState = RunSession.begin_new_run(candidate, "rogue")
		if not bool(MapGenerator.build(probe.seed_value, tight, {}, 2, probe.acts_total)["ok"]):
			run_seed = candidate
			break
	assert_int(run_seed).is_greater(0)
	RunSession.clear()
	var state: RunState = RunSession.begin_new_run(run_seed, "rogue")
	state.jump_to_room(9)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames()
	var controller: RunController = main.run_controller
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	main.enemy_spawner.configure_room(table, 1)
	main.enemy_spawner._process(1.0)
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await _frames(2)
	controller.pick_relic(state.offer[0])
	MapConfig.get_config()["max_attempts"] = 1
	controller.choose("skip")
	assert_str(state.outcome).is_equal("lost")
	assert_bool(main.player.is_dead()).is_false()
	await _frames(4)
	await get_tree().create_timer(2.0, true, false, true).timeout
	var screen: Node = main.get_node_or_null("GameOverScreen")
	assert_object(screen).is_not_null()
	var shown: bool = main.is_game_over() or (screen is CanvasItem and (screen as CanvasItem).visible)
	assert_bool(shown).override_failure_message("run lost on an act-change map failure, but no Game Over screen is shown: the player sees nothing (soft lock)").is_true()


## 3d qa: the in-memory profile (LoadoutSession) counts finished runs process-wide; leave it clean so the next suite starts as run 1.
func after() -> void:
	LoadoutSession.reset()
	StartScreen.reset()
