class_name Bd3aQaTest
extends GdUnitTestSuite
## BD3a qa review: behaviour checks the feature suites only covered by reading data.
##  1. Pyre Insurance really stays silent on a Burn detonate (the engine test only reads the relic's reason list).
##  2. The real act_start_heal -> act_summary -> ActScreen wiring (ux's captures used made-up summaries): a finished act shows the heal line,
##     a run resumed from a save in the middle of the act shows none.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PATH := "user://tests/bd3a_qa_run_save.json"


func before_test() -> void:
	BodyFlag.set_collide(false)
	CombatEvents.reset()
	RelicDatabase.load_all()
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0


func after_test() -> void:
	BodyFlag.reset()
	CombatEvents.reset()
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false
	Engine.time_scale = 1.0


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


# ---- 1. Pyre Insurance and detonated, through the real manager -------------------------------------

func _arena_with_pyre(burning_hp: float = 100.0) -> Dictionary:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	var manager := RelicManager.new()
	main.add_child(manager)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	manager.configure(main.player, main, rng, CombatEvents)
	manager.load_relics(["pyre_insurance"] as Array[String])
	var fired: Array[int] = [0]
	manager.relic_triggered.connect(func(_id: String, _index: int, _event: String) -> void: fired[0] += 1)
	var burning := RelayTarget.new("enemy", burning_hp)
	main.add_child(burning)
	burning.global_position = Vector3(8.0, 0.0, 8.0)
	var neighbour := RelayTarget.new("enemy", 100.0)
	main.add_child(neighbour)
	neighbour.global_position = Vector3(8.5, 0.0, 8.0)
	burning.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 30.0, null, "card:x")
	return {"main": main, "burning": burning, "neighbour": neighbour, "fired": fired}


func test_a_burn_detonate_does_not_set_off_pyre_insurance() -> void:
	var rig: Dictionary = _arena_with_pyre(1.0e6)  # tough enough to survive the burst, so Burn is removed by the detonate itself, not by a death
	var burning: RelayTarget = rig["burning"]
	var neighbour: RelayTarget = rig["neighbour"]
	var fired: Array[int] = rig["fired"]
	await _frames()
	burning.status_manager.detonate_status("burn", 2.0, null, "card:rogue_open_a_vein")
	await _frames()
	# The detonate really happened (Burn is gone, the target lost HP), so "nothing fired" is not an artefact of a no-op.
	assert_bool(burning.status_manager.has_status("burn")).override_failure_message("the detonate did not remove Burn").is_false()
	assert_float(burning.health.current_health).override_failure_message("the detonate dealt no damage").is_less(1.0e6)
	assert_int(fired[0]).override_failure_message("Pyre Insurance fired on a detonated Burn").is_equal(0)
	assert_float(neighbour.health.current_health).override_failure_message("the neighbour was hurt by a chained explosion").is_equal(100.0)


func test_control_the_same_rig_does_explode_when_the_burning_enemy_dies() -> void:
	# Without this, the test above would pass for a rig where nothing could ever fire.
	var rig: Dictionary = _arena_with_pyre()
	var burning: RelayTarget = rig["burning"]
	var neighbour: RelayTarget = rig["neighbour"]
	var fired: Array[int] = rig["fired"]
	await _frames()
	burning.health.take_damage(1000.0)
	await _frames(3)
	assert_int(fired[0]).is_greater(0)
	assert_float(neighbour.health.current_health).is_less(100.0)


# ---- 2. The act screen through the real wiring --------------------------------------------------------

func _spawn_run() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _win_room(main: Main) -> void:
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


func _finish_act_one_at(hp: float) -> Main:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(9)
	state.hp = hp
	state.max_hp = 30.0
	var main: Main = _spawn_run()
	await _frames()
	await _win_room(main)
	main.run_controller.pick_relic(state.offer[0])
	main.run_controller.choose("skip")
	await _frames(2)
	return main


func test_the_real_path_shows_the_heal_line_on_the_act_screen() -> void:
	var main: Main = await _finish_act_one_at(10.0)
	var act_screen: ActScreen = main.get_node("ActScreen") as ActScreen
	assert_bool(act_screen.is_open()).is_true()
	assert_bool(act_screen.heal_label.visible).is_true()
	assert_str(act_screen.heal_label.text).is_equal("You recover 9 HP. Rests are on the map.")
	assert_str(act_screen.line_label.text).contains("19 of 30")
	assert_bool(act_screen.line_label.text.contains("Low HP")).is_false()  # 19 of 30 is above half


func test_the_real_path_marks_low_hp_after_the_heal() -> void:
	var main: Main = await _finish_act_one_at(2.0)  # 2 + 9 = 11 of 30, at or under half
	var act_screen: ActScreen = main.get_node("ActScreen") as ActScreen
	assert_bool(act_screen.is_open()).is_true()
	assert_str(act_screen.heal_label.text).is_equal("You recover 9 HP. Rests are on the map.")
	assert_str(act_screen.line_label.text).contains("Low HP").contains("11 of 30")


func test_with_the_heal_off_the_real_act_screen_has_no_heal_line() -> void:
	(RunConfig.get_config()["acts"] as Dictionary)["start_heal"] = 0.0
	var main: Main = await _finish_act_one_at(10.0)
	var act_screen: ActScreen = main.get_node("ActScreen") as ActScreen
	assert_bool(act_screen.is_open()).is_true()
	assert_bool(act_screen.heal_label.visible).is_false()
	assert_str(act_screen.line_label.text).contains("10 of 30")


func test_a_run_resumed_from_the_act_two_save_shows_no_heal_line_and_no_act_screen() -> void:
	var first: Main = await _finish_act_one_at(10.0)
	assert_float(RunSave.read_state().hp).is_equal_approx(19.0, 0.001)  # the heal is already in the save
	RunSession.clear()
	first.queue_free()
	await _frames()
	assert_bool(RunSave.load_save()).is_true()
	var resumed: Main = _spawn_run()
	await _frames(3)
	var summary: Dictionary = resumed.run_controller.act_summary()
	assert_float(float(summary["healed"])).is_equal(0.0)
	assert_float(float(summary["hp"])).is_equal_approx(19.0, 0.001)
	var act_screen: ActScreen = resumed.get_node("ActScreen") as ActScreen
	assert_bool(act_screen.is_open()).override_failure_message("the act screen opened on a resumed act").is_false()
	assert_bool(act_screen.heal_label.is_visible_in_tree()).is_false()  # the label's own flag is true until show_act runs; what counts is that nothing is drawn
	assert_str(act_screen.heal_label.text).is_empty()
	assert_float(RunSave.read_state().hp).override_failure_message("a resume healed the run a second time").is_equal_approx(19.0, 0.001)


# ---- 3. Regression probe: an enemy freed before its HP bar's deferred stack label is added leaks that label ----
# Found in the BD3a review: aa02650 (EnemyHpBar._ready creates a StatusStackLabel and adds it with call_deferred). When the enemy is freed in the
# same frame, the deferred call to the freed bar never runs and the new Label3D is never added or freed. slice5d_qa_test (61 orphans) and
# slice6_qa_test (10) show it in the full suite as exit 101. Skipped until gameplay-dev/ux fix it; un-skip with the fix.

func test_an_enemy_freed_in_its_spawn_frame_leaves_no_orphan_node() -> void:
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in range(20):
		var enemy: Node = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
		add_child(enemy)
		enemy.free()  # freed before the deferred queue runs
	await _frames(3)
	var after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_int(after - before).override_failure_message("%d orphan nodes left by 20 enemies freed in their spawn frame" % (after - before)).is_equal(0)


# ---- 4. Regression probe: physical-rogue still carries a Fire card the rules no longer need ----
# t_decks_qa_test computes the fewest Fire cards the rules need from the pools (0 since Cutting Corners and The Knife Drawer gave the Rogue 4
# non-Fire Attack: AoE cards) but no longer compares the preset with it, and the preset still holds Fine Burn Then and says "because the deck rules
# need it". This is that comparison. Un-skipped when gameplay-dev dropped the card.

func test_physical_rogue_holds_no_more_fire_cards_than_the_rules_need() -> void:
	var spare: Dictionary = {}
	for card_id: String in RunConfig.cards_in_pools(["rogue", "neutral"]):
		var slot: String = String(CardDatabase.get_card(card_id).get("slot_type", ""))
		spare[slot] = int(spare.get(slot, 0)) + 1
	var needed_fire: int = 0
	for slot: String in spare:
		needed_fire += maxi(0, 3 - int(spare[slot]))
	var preset: Dictionary = (DebugDecks.read_dir()["presets"] as Dictionary)["physical-rogue"]
	var fire_in_starter: int = int(DebugDecks.pool_counts(preset["starter"]).get("fire", 0))
	assert_int(fire_in_starter).is_equal(needed_fire)
