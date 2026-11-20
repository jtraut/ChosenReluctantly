class_name Ux1bTest
extends GdUnitTestSuite
## UX1b: the single-option map beat (MapScreen), the act heal line's value (ActText), the damage-number merge and boss-bar clamp fixes, the first-time
## status name (StatusStackLabel) and the class colours against the enemy colours.

const SCREEN_SCENE := "res://scenes/ui/MapScreen.tscn"


func after_test() -> void:
	GamePause.reset()
	get_tree().paused = false
	Juice.reset()
	StatusStackLabel.reset_intros()


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


## A hand-made pick: `reachable_count` nodes in room 2, all reachable.
func _pick_data(reachable_count: int) -> Dictionary:
	var nodes: Array = []
	var infos: Array[Dictionary] = []
	var reachable: Array[int] = []
	for i in range(reachable_count):
		nodes.append({"id": i, "room": 2, "column": i, "type": "combat", "wave_id": ""})
		infos.append({"id": i, "room": 2, "column": i, "type": "combat", "type_name": "Combat", "wave_id": "", "chest": "", "chest_name": "", "hover": "Room",
			"gold_low": 0, "gold_high": 0, "reachable": true, "taken": false, "current": false})
		reachable.append(i)
	return {"map": {"nodes": nodes, "edges": []}, "path": [], "reachable": reachable, "nodes": infos, "gold": 0, "gold_earned": 0}


func _spawn(enabled: bool) -> MapScreen:
	var screen: MapScreen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	add_child(screen)
	auto_free(screen)
	await _frames(1)
	screen.beat_enabled = enabled
	return screen


func _key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_X
	event.physical_keycode = KEY_X
	event.pressed = true
	return event


# ---- the beat ----

func test_single_reachable_id_is_the_only_node_or_minus_one() -> void:
	var one: Array[Dictionary] = [{"id": 4, "reachable": true}, {"id": 5, "reachable": false}]
	var two: Array[Dictionary] = [{"id": 4, "reachable": true}, {"id": 5, "reachable": true}]
	var none: Array[Dictionary] = [{"id": 4, "reachable": false}]
	assert_int(MapScreen.single_reachable_id(one)).is_equal(4)
	assert_int(MapScreen.single_reachable_id(two)).is_equal(-1)
	assert_int(MapScreen.single_reachable_id(none)).is_equal(-1)


func test_the_beat_clock_counts_down_holds_while_held_and_never_goes_below_zero() -> void:
	assert_float(MapScreen.beat_step(1.0, 0.25, false)).is_equal_approx(0.75, 0.0001)
	assert_float(MapScreen.beat_step(1.0, 0.25, true)).is_equal(1.0)  # paused, or the act screen is up
	assert_float(MapScreen.beat_step(0.1, 0.5, false)).is_equal(0.0)
	assert_float(MapScreen.beat_step(-1.0, 0.5, false)).is_equal(-1.0)  # no beat running


func test_the_beat_is_about_a_second_and_read_from_data() -> void:
	assert_float(float(UiConfig.map_screen()["auto_advance_seconds"])).is_between(0.5, 2.0)


func test_a_single_option_pick_waits_the_beat_then_picks_it() -> void:
	var screen: MapScreen = await _spawn(true)
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))
	screen.disarm()
	assert_bool(screen.beat_running()).is_true()
	assert_int(screen.beat_target()).is_equal(0)
	assert_bool(screen.is_open()).is_true()  # the whole map stays up during the beat
	screen._process(0.4)
	assert_array(chosen).is_empty()  # not yet
	screen._process(0.7)
	assert_array(chosen).is_equal([0] as Array[int])
	assert_bool(screen.beat_running()).is_false()


func test_a_key_press_skips_the_wait() -> void:
	var screen: MapScreen = await _spawn(true)
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))
	screen.disarm()
	screen._input(_key_event())
	assert_array(chosen).is_equal([0] as Array[int])
	screen._process(5.0)
	assert_int(chosen.size()).is_equal(1)  # picked once, not again when the clock would have run out


func test_a_press_before_the_arm_delay_does_not_skip() -> void:
	var screen: MapScreen = await _spawn(true)
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))  # armed only after run_ui.prompt_option_arm_delay: the Enter that closed the last screen must not pick
	assert_bool(screen.skip_beat()).is_false()
	assert_array(chosen).is_empty()
	assert_bool(screen.beat_running()).is_true()


func test_a_pick_made_another_way_cancels_the_beat() -> void:
	var screen: MapScreen = await _spawn(true)
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))
	screen.disarm()
	screen._on_node_pressed(0)  # the player's own click or Enter on the node
	assert_bool(screen.beat_running()).is_false()
	screen._process(5.0)
	assert_int(chosen.size()).is_equal(1)


func test_several_options_start_no_beat() -> void:
	var screen: MapScreen = await _spawn(true)
	screen.show_pick(_pick_data(2))
	assert_bool(screen.beat_running()).is_false()
	screen.disarm()
	screen._process(5.0)
	assert_bool(screen.pick_pending()).is_true()


func test_pausing_holds_the_beat() -> void:
	var screen: MapScreen = await _spawn(true)
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))
	screen.disarm()
	screen._process(0.5)
	var left: float = screen.beat_seconds_left()
	assert_bool(GamePause.pause()).is_true()
	screen._process(5.0)
	assert_float(screen.beat_seconds_left()).is_equal(left)  # held, not restarted and not run down
	assert_array(chosen).is_empty()
	GamePause.resume()
	assert_bool(screen.beat_running()).is_true()


func test_the_bot_and_test_runner_path_has_no_beat() -> void:
	# The bots (tools/wave_sim.gd) and the test runner host the game as a script that replaces the SceneTree, so the session is not a person's.
	assert_bool(MapScreen.human_session()).is_false()
	var screen: MapScreen = await _spawn(MapScreen.human_session())
	assert_bool(screen.beat_enabled).is_false()
	screen.show_pick(_pick_data(1))
	assert_bool(screen.beat_running()).is_false()
	screen.disarm()
	screen._process(5.0)
	assert_bool(screen.pick_pending()).is_true()  # nothing picked for the bot: it answers through the controller itself


# ---- the act heal line ----

func test_the_heal_line_shows_the_applied_heal_and_the_percent_from_the_summary() -> void:
	assert_str(ActText.heal_line({"healed": 9.0, "heal_fraction": 0.3})).is_equal("+9 HP (act heal 30%)")
	assert_str(ActText.heal_line({"healed": 4.0, "heal_fraction": 0.25})).is_equal("+4 HP (act heal 25%)")


func test_the_heal_percent_falls_back_to_the_data_value() -> void:
	var expected: String = "+6 HP (act heal %d%%)" % roundi(RunConfig.act_start_heal() * 100.0)
	assert_str(ActText.heal_line({"healed": 6.0})).is_equal(expected)


func test_the_heal_line_is_hidden_at_full_hp() -> void:
	assert_str(ActText.heal_line({"healed": 0.0, "heal_fraction": 0.3})).is_empty()
	assert_str(ActText.heal_line({})).is_empty()


func test_the_controller_clamps_the_heal_to_max_hp() -> void:
	var main: Main = (load("res://scenes/main/RunMain.tscn") as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(2)
	var controller: RunController = main.run_controller
	var state: RunState = controller.state()
	state.hp = state.max_hp - 2.0  # 2 short of full: a 30% heal must show +2, not +9
	controller._apply_act_start_heal()
	var summary: Dictionary = controller.act_summary()
	assert_float(float(summary["healed"])).is_equal_approx(2.0, 0.001)
	assert_str(ActText.heal_line(summary)).is_equal("+2 HP (act heal %d%%)" % roundi(RunConfig.act_start_heal() * 100.0))
	state.hp = state.max_hp
	controller._apply_act_start_heal()
	assert_str(ActText.heal_line(controller.act_summary())).is_empty()


# ---- damage numbers ----

func test_an_armored_hit_merges_whatever_its_damage_type() -> void:
	assert_str(DamageNumber.key_for("physical", DamageNumber.STYLE_ARMOR)).is_equal(DamageNumber.key_for("fire", DamageNumber.STYLE_ARMOR))
	assert_str(DamageNumber.key_for("physical", DamageNumber.STYLE_NONE)).is_not_equal(DamageNumber.key_for("fire", DamageNumber.STYLE_NONE))
	assert_str(DamageNumber.key_for("fire", DamageNumber.STYLE_RESIST)).is_not_equal(DamageNumber.key_for("water", DamageNumber.STYLE_RESIST))


func test_a_number_keeps_its_spawn_point_as_the_merge_anchor() -> void:
	var number := DamageNumber.new()
	number.configure(UiConfig.damage_numbers())
	number.position = Vector3(3.0, 2.9, 4.0)
	number.show_amount(5.0, "physical", Color.WHITE, false)
	number.position = Vector3(9.0, 9.0, 9.0)  # the boss-bar clamp moves the label; the hit's place on the ground stays
	assert_vector(number.merge_anchor()).is_equal(Vector3(3.0, 2.9, 4.0))
	number.free()


func test_a_pinned_number_drifts_down_with_age_so_hits_do_not_stack() -> void:
	assert_float(DamageNumber.clamped_drift_px(0.0, 96.0, 1.0)).is_equal(0.0)
	assert_float(DamageNumber.clamped_drift_px(0.5, 96.0, 1.0)).is_equal_approx(48.0, 0.001)
	assert_float(DamageNumber.clamped_drift_px(2.0, 96.0, 1.5)).is_equal_approx(144.0, 0.001)  # life clamps at 1, the screen scale applies
	assert_float(float(UiConfig.damage_numbers()["boss_clamp_drift_px"])).is_greater(0.0)


func test_numbers_spawn_above_the_enemy_bar() -> void:
	var cfg: Dictionary = UiConfig.damage_numbers()
	var hp: Dictionary = UiConfig.hp_bars()
	var bar_top: float = float(hp["y_offset"]) + float(hp["height"]) * float(hp["pip_scale"]) * 0.5
	assert_float(float(cfg["spawn_height"])).is_greater(bar_top)


# ---- the first-time status name ----

func test_a_status_is_named_once_over_the_first_enemy_that_shows_it() -> void:
	var cfg: Dictionary = UiConfig.status_stacks()
	var entries: Array = [{"id": "bleed", "name": "Bleed", "stacks": 1, "max": 5}]
	assert_bool(StatusStackLabel.needs_intro({}, "bleed", cfg)).is_true()
	assert_bool(StatusStackLabel.needs_intro({"bleed": true}, "bleed", cfg)).is_false()
	assert_str(StatusStackLabel.compose_with_intro(entries, cfg, ["bleed"] as Array[String])).is_equal("Bleed")
	assert_str(StatusStackLabel.compose_with_intro(entries, cfg, [] as Array[String])).is_equal("")
	entries[0]["stacks"] = 3
	assert_str(StatusStackLabel.compose_with_intro(entries, cfg, ["bleed"] as Array[String])).is_equal("Bleed x3")  # a stack count already names it


# ---- the class colours ----

func _enemy_colors() -> Dictionary:
	var out: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("albedo_color = Color\\(([^)]*)\\)")
	for file: String in DirAccess.get_files_at("res://scenes/enemies"):
		if not file.ends_with(".tscn"):
			continue
		var text: String = FileAccess.get_file_as_string("res://scenes/enemies/" + file)
		for line: String in text.split("\n"):
			if line.begins_with("albedo_color"):
				var found: RegExMatch = regex.search(line)
				if found != null:
					var parts: PackedStringArray = found.get_string(1).split(",")
					out[file] = Color(float(parts[0]), float(parts[1]), float(parts[2]))
	return out


## Every colour an enemy body can show: its resting colour, that colour pulled toward the stun tint, and the wind-up flash.
func _enemy_body_colors() -> Dictionary:
	var out: Dictionary = {}
	var stun: Dictionary = StatusDatabase.body_tint("stun")
	var stun_color: Color = stun.get("color", Enemy.DEFAULT_STUN_TINT)
	var amount: float = float(stun.get("amount", Enemy.DEFAULT_STUN_TINT_AMOUNT))
	var base: Dictionary = _enemy_colors()
	for file: String in base:
		out[file] = base[file]
		out[file + " (stunned)"] = (base[file] as Color).lerp(stun_color, amount)
	out["telegraph flash"] = Enemy.TELEGRAPH_COLOR
	return out


func test_every_class_colour_is_distinct_from_every_enemy_colour_including_stun_and_wind_up_tints() -> void:
	var enemies: Dictionary = _enemy_body_colors()
	assert_int(enemies.size()).is_greater_equal(11)
	for character_id: String in CharacterDatabase.ids():
		var mine: Color = CharacterDatabase.body_color(character_id)
		for label: String in enemies:
			var theirs: Color = enemies[label]
			var gap: float = Vector3(mine.r - theirs.r, mine.g - theirs.g, mine.b - theirs.b).length()
			assert_float(gap).override_failure_message("%s is too close to %s (%.2f)" % [character_id, label, gap]).is_greater(0.45)


func test_the_two_classes_differ_from_each_other() -> void:
	var a: Color = CharacterDatabase.body_color("rogue")
	var b: Color = CharacterDatabase.body_color("wizard")
	assert_float(Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()).is_greater(0.45)
