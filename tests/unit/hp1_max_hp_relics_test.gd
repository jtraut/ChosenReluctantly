class_name Hp1MaxHpRelicsTest
extends GdUnitTestSuite
## HP1 (D55 = B): the two max HP relics, wellness_pack (flat +4) and performance_review (+1 per elite room cleared after owning it).
## Pure logic over RunState and RunMaxHp, plus the schema rules.

const FLAT := "wellness_pack"
const PER_ELITE := "performance_review"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func before_test() -> void:
	RelicDatabase.load_all()


func _state(hp: float = 30.0, max_hp: float = 30.0) -> RunState:
	var state: RunState = RunState.new_run(11, ["x"] as Array[String], 3)
	state.hp = hp
	state.max_hp = max_hp
	return state


# --- data and schema ---------------------------------------------------------------------------

func test_both_relics_are_valid_tier1_neutral_with_the_three_sources() -> void:
	for id: String in [FLAT, PER_ELITE]:
		var relic: Dictionary = RelicDatabase.get_relic(id)
		assert_bool(relic.is_empty()).is_false()
		assert_array(RelicSchema.validate(relic, id)).is_empty()
		assert_str(String(relic["rarity"])).is_equal("tier1")
		assert_str(String(relic["pool"])).is_equal("neutral")
		assert_array(relic["sources"]).contains_exactly_in_any_order(["elite", "relic_room", "merchant"])
		assert_int(String(relic["name"]).length()).is_less(26)
	assert_float(RunMaxHp.flat_amount(RelicDatabase.get_relic(FLAT))).is_equal(4.0)


func test_the_schema_rejects_bad_max_hp_data() -> void:
	var relic: Dictionary = RelicDatabase.get_relic(FLAT).duplicate(true)
	(relic["modifiers"] as Array)[0]["modifier_type"] = "multiplicative"
	assert_array(RelicSchema.validate(relic, FLAT)).is_not_empty()
	relic = RelicDatabase.get_relic(FLAT).duplicate(true)
	(relic["modifiers"] as Array)[0]["value"] = 2.5
	assert_array(RelicSchema.validate(relic, FLAT)).is_not_empty()
	relic = RelicDatabase.get_relic(PER_ELITE).duplicate(true)
	relic["triggers"][0]["effects"][0]["params"]["amount"] = 0
	assert_array(RelicSchema.validate(relic, PER_ELITE)).is_not_empty()
	relic = RelicDatabase.get_relic(PER_ELITE).duplicate(true)
	relic["triggers"][0]["event"] = "enemy_killed"
	relic["triggers"][0]["filter"] = {}
	assert_array(RelicSchema.validate(relic, PER_ELITE)).is_not_empty()  # only room_cleared applies it
	var buff_errors: Array[String] = EffectTemplates.validate_params("buff", {"stat": "damage_mult", "modifier_type": "multiplicative", "value": 0.1, "duration": 5.0,
			"triggers": [RelicDatabase.get_relic(PER_ELITE)["triggers"][0]]})
	assert_array(buff_errors).is_not_empty()  # a card buff cannot carry it


func test_a_card_cannot_use_the_gain_max_hp_effect() -> void:
	var errors: Array[String] = []
	CardSchema._validate_effect({"template": "gain_max_hp", "params": {"amount": 1}}, 0, errors)
	assert_array(errors).is_not_empty()
	assert_array(RelicSchema.validate_trigger(RelicDatabase.get_relic(PER_ELITE)["triggers"][0], 0)).is_empty()


# --- the flat relic ------------------------------------------------------------------------------

func test_the_flat_relic_adds_max_hp_and_heals_by_the_same_amount() -> void:
	var state: RunState = _state(20.0, 30.0)
	assert_bool(state.add_relic(FLAT)).is_true()
	assert_float(state.max_hp).is_equal(34.0)
	assert_float(state.hp).is_equal(24.0)
	assert_float(float(state.relic_max_hp[FLAT])).is_equal(4.0)


func test_a_duplicate_pick_does_not_stack() -> void:
	var state: RunState = _state()
	state.add_relic(FLAT)
	assert_bool(state.add_relic(FLAT)).is_false()
	assert_float(state.max_hp).is_equal(34.0)


func test_losing_the_flat_relic_takes_the_boost_away_and_clamps_hp() -> void:
	var state: RunState = _state()
	state.add_relic(FLAT)
	assert_float(state.hp).is_equal(34.0)
	state.give_up_relic(FLAT)
	assert_float(state.max_hp).is_equal(30.0)
	assert_float(state.hp).is_equal(30.0)  # clamped to the new max
	assert_bool(state.relic_max_hp.has(FLAT)).is_false()
	var hurt: RunState = _state(12.0, 30.0)
	hurt.add_relic(FLAT)
	hurt.give_up_relic(FLAT)
	assert_float(hurt.hp).is_equal(16.0)  # the heal-on-gain stays; only the clamp applies


func test_a_start_without_hp_keeps_the_boost_until_the_run_sets_its_hp() -> void:
	var state: RunState = RunState.new_run(11, ["x"] as Array[String], 3)
	assert_bool(state.has_hp()).is_false()
	state.add_relic(FLAT)
	assert_bool(state.has_hp()).is_false()
	assert_float(RunMaxHp.pending_total(state)).is_equal(4.0)


# --- the per-elite relic -------------------------------------------------------------------------

func test_the_per_elite_relic_counts_elite_clears_after_owning_it() -> void:
	var state: RunState = _state()
	assert_dict(RunMaxHp.on_room_cleared(state, "elite")).is_empty()  # not owned yet: nothing, and never retroactive
	state.add_relic(PER_ELITE)
	assert_float(state.max_hp).is_equal(30.0)  # taking it gives nothing by itself
	var gained: Dictionary = RunMaxHp.on_room_cleared(state, "elite")
	assert_float(float(gained[PER_ELITE])).is_equal(1.0)
	assert_float(state.max_hp).is_equal(31.0)
	assert_float(state.hp).is_equal(31.0)
	RunMaxHp.on_room_cleared(state, "elite")
	assert_float(state.max_hp).is_equal(32.0)
	assert_float(float(state.relic_max_hp[PER_ELITE])).is_equal(2.0)


func test_other_room_types_and_mini_bosses_do_not_count() -> void:
	var state: RunState = _state()
	state.add_relic(PER_ELITE)
	for room_type: String in ["combat", "mini_boss", "boss", "rest", "relic_room", "merchant", "event"]:
		assert_dict(RunMaxHp.on_room_cleared(state, room_type)).is_empty()
	assert_float(state.max_hp).is_equal(30.0)


func test_losing_the_per_elite_relic_removes_everything_it_gave() -> void:
	var state: RunState = _state()
	state.add_relic(PER_ELITE)
	for i in range(3):
		RunMaxHp.on_room_cleared(state, "elite")
	assert_float(state.max_hp).is_equal(33.0)
	state.give_up_relic(PER_ELITE)
	assert_float(state.max_hp).is_equal(30.0)
	assert_float(state.hp).is_equal(30.0)


func test_both_relics_together_and_the_order_of_loss_does_not_matter() -> void:
	var state: RunState = _state()
	state.add_relic(FLAT)
	state.add_relic(PER_ELITE)
	RunMaxHp.on_room_cleared(state, "elite")
	assert_float(state.max_hp).is_equal(35.0)
	state.give_up_relic(FLAT)
	assert_float(state.max_hp).is_equal(31.0)
	state.give_up_relic(PER_ELITE)
	assert_float(state.max_hp).is_equal(30.0)


func test_losing_a_relic_never_cuts_below_the_floor_or_raises_max_hp() -> void:
	var state: RunState = _state(10.0, 12.0)
	state.add_relic(FLAT)  # 16 / 14
	state.max_hp = 11.0  # an event cut it meanwhile
	state.hp = 11.0
	state.give_up_relic(FLAT)
	assert_float(state.max_hp).is_equal(10.0)  # events.min_max_hp
	assert_float(state.hp).is_equal(10.0)
	var at_floor: RunState = _state(4.0, 10.0)
	at_floor.relic_max_hp[FLAT] = 4.0
	at_floor.relics.append(FLAT)
	at_floor.give_up_relic(FLAT)
	assert_float(at_floor.max_hp).is_equal(10.0)
	assert_float(at_floor.hp).is_equal(4.0)


func test_lose_max_hp_still_respects_the_floor_with_a_relic_held() -> void:
	var state: RunState = _state(12.0, 12.0)
	state.add_relic(FLAT)  # 16
	var ctx: Dictionary = {"events": {"min_max_hp": 10}}
	var result: Dictionary = {}
	EventEngine._run(state, ctx, [{"type": "lose_max_hp", "fraction": 0.9}], result)
	assert_float(state.max_hp).is_equal(10.0)
	assert_float(state.hp).is_equal(10.0)


# --- save and resume -----------------------------------------------------------------------------

func test_the_boosts_survive_a_save_and_resume_and_an_old_save_loads_empty() -> void:
	var state: RunState = _state()
	state.add_relic(FLAT)
	state.add_relic(PER_ELITE)
	RunMaxHp.on_room_cleared(state, "elite")
	var back: RunState = RunState.from_json(state.to_json())
	assert_object(back).is_not_null()
	assert_float(back.max_hp).is_equal(35.0)
	assert_float(float(back.relic_max_hp[FLAT])).is_equal(4.0)
	assert_float(float(back.relic_max_hp[PER_ELITE])).is_equal(1.0)
	assert_bool(back.equals(state)).is_true()
	# Resumed mid-count: the next elite continues the count, and losing the relic removes all of it.
	RunMaxHp.on_room_cleared(back, "elite")
	assert_float(float(back.relic_max_hp[PER_ELITE])).is_equal(2.0)
	back.give_up_relic(PER_ELITE)
	assert_float(back.max_hp).is_equal(34.0)
	var old: Dictionary = state.to_dict()
	old.erase("relic_max_hp")
	var loaded: RunState = RunState.from_dict(old)
	assert_object(loaded).is_not_null()
	assert_dict(loaded.relic_max_hp).is_empty()


func test_a_save_naming_a_relic_that_is_not_held_is_refused() -> void:
	var state: RunState = _state()
	state.add_relic(FLAT)
	var data: Dictionary = state.to_dict()
	data["relic_max_hp"] = {PER_ELITE: 1}
	assert_object(RunState.from_dict(data)).is_null()


# --- through the real controller (the live player and the HUD numbers) ---------------------------

func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


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
	await _frames()


func test_a_cleared_elite_room_raises_the_live_players_max_hp_and_the_hud_reads_it() -> void:
	RunSession.map_override = 0
	RunSession.clear()
	var found_seed: int = -1
	var found_room: int = -1
	for seed_value in range(1, 200):
		for room: Dictionary in RunGenerator.generate(seed_value, RunConfig.get_config()):
			if found_seed < 0 and String(room["type"]) == "elite":
				found_seed = seed_value
				found_room = int(room["index"])
	var state: RunState = RunSession.begin_new_run(found_seed)
	state.room_index = found_room
	state.hp = 25.0
	state.max_hp = 30.0
	state.add_relic(PER_ELITE)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(1)
	assert_float(main.player.health.max_health).is_equal(30.0)
	var triggers: Array[String] = []
	main.run_controller.relic_triggered.connect(func(relic_id: String, _i: int, _e: String) -> void: triggers.append(relic_id))
	await _win_room(main)
	assert_float(state.max_hp).is_equal(31.0)
	assert_float(main.player.health.max_health).is_equal(31.0)
	assert_float(main.player.health.current_health).is_equal(26.0)
	assert_float(state.hp).is_equal(26.0)
	await _frames(2)
	assert_array(triggers).is_equal([PER_ELITE])  # one pulse: the manager's own trigger fire, not a second signal
	assert_float(main.hud.health_bar.max_value).is_equal(31.0)
	assert_str(main.hud.health_label.text).is_equal("HP 26 / 31")
	RunSession.map_override = -1
	RunSession.clear()
	Juice.reset()
	GamePause.reset()


func test_taking_and_losing_the_flat_relic_moves_the_live_players_max_hp() -> void:
	RunSession.map_override = 0
	RunSession.clear()
	var state: RunState = RunSession.begin_new_run(5)
	state.hp = 20.0
	state.max_hp = 30.0
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(1)
	state.add_relic(FLAT)
	main.run_controller._sync_relics()
	assert_float(main.player.health.max_health).is_equal(34.0)
	assert_float(main.player.health.current_health).is_equal(24.0)
	state.give_up_relic(FLAT)
	main.run_controller._sync_relics()
	assert_float(main.player.health.max_health).is_equal(30.0)
	assert_float(main.player.health.current_health).is_equal(24.0)
	RunSession.map_override = -1
	RunSession.clear()
	Juice.reset()
	GamePause.reset()


func test_a_debug_start_with_the_flat_relic_begins_at_the_class_base_plus_four() -> void:
	RunSession.map_override = 0
	RunSession.clear()
	RunSession.start_relics = [FLAT] as Array[String]
	var state: RunState = RunSession.begin_new_run(5)
	assert_bool(state.has_hp()).is_false()
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(1)
	var base: float = CharacterDatabase.max_hp(state.character_id)
	assert_float(state.max_hp).is_equal(base + 4.0)
	assert_float(state.hp).is_equal(base + 4.0)
	assert_float(main.player.health.max_health).is_equal(base + 4.0)
	assert_float(main.player.health.current_health).is_equal(base + 4.0)
	RunSession.start_relics = []
	RunSession.map_override = -1
	RunSession.clear()
	Juice.reset()
	GamePause.reset()
