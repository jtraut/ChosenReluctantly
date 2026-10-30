class_name M3cQaTest
extends GdUnitTestSuite
## Milestone 3c qa (independent of gameplay-dev's and ux-designer's suites): the boss's HP floor against big hits and
## damage over time, resistance to every element, more bad-data fixtures, the room clear and the death beat with adds
## alive, the volley's drawn lane against its real shots, every shipped card's effect line, real-key input on the
## Continue / New run prompt, and RunState.from_dict against bad `pending` values.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const BOSS_ID := "boss_guardian"


func before_test() -> void:
	Juice.hit_stop_enabled = false
	RunSession.clear()


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0
	RunSession.clear()
	RunSession.full_deck = false
	BossConfig.reset_cache()


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _boss(main: Main, distance: float = 8.0) -> Boss:
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -distance)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.health.base_armor = 0.0  # phase and HP-bar tests count raw HP; armor has its own tests (a1_armor_test.gd)
	return boss


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH)) as Dictionary


func _transition_frames() -> int:
	var duration: float = float((BossConfig.boss(BOSS_ID)["transition"] as Dictionary)["duration"])
	return int((duration + 0.25) * float(Engine.physics_ticks_per_second))


# ---- HP floor: one big hit or a stream of DoT ticks can never skip a phase ----

func test_qa_huge_hits_and_dot_ticks_walk_the_boss_through_every_phase_once() -> void:
	var main := _spawn_main()
	main.player.health.damage_immune = true
	var boss := _boss(main, 14.0)
	boss._attack_cooldown_remaining = 99.0
	await _frames(2)
	var entered: Array[int] = []
	boss.transition_started.connect(func(index: int, _duration: float) -> void: entered.append(index))
	var max_hp: float = boss.health.max_health
	# Phase 1 -> 2 with a 9999 physical hit.
	boss.health.take_damage(9999.0, "physical")
	assert_float(boss.health.current_health).is_equal_approx(max_hp * 0.66, 0.01)
	assert_bool(boss.is_transitioning()).is_true()
	assert_bool(boss.health.damage_immune).is_true()
	# Anything during the roar bounces off, a heavy hit and a DoT tick alike.
	boss.health.take_damage(9999.0, "physical")
	boss.health.take_damage(50.0, "fire", Vector3.ZERO, null, Health.KIND_DOT)
	assert_float(boss.health.current_health).is_equal_approx(max_hp * 0.66, 0.01)
	await _frames(_transition_frames())
	assert_int(boss.phase_index).is_equal(1)
	assert_bool(boss.health.damage_immune).is_false()
	# Phase 2 -> 3 by a long stream of fire DoT ticks (halved by the resistance): never below the floor on any tick.
	var floor_hp: float = max_hp * 0.33
	var ticks: int = 0
	while not boss.is_transitioning() and ticks < 400:
		boss.health.take_damage(3.0, "fire", Vector3.ZERO, null, Health.KIND_DOT)
		ticks += 1
		assert_float(boss.health.current_health).override_failure_message("DoT tick %d took the boss under the phase 3 floor" % ticks).is_greater_equal(floor_hp - 0.01)
	assert_bool(boss.is_transitioning()).override_failure_message("DoT never started the second transition").is_true()
	assert_float(boss.health.current_health).is_equal_approx(floor_hp, 0.01)
	await _frames(_transition_frames())
	assert_int(boss.phase_index).is_equal(2)
	assert_float(boss.health.hp_floor).is_equal(0.0)
	# The last phase can die, and a single huge hit kills it outright.
	boss.health.take_damage(9999.0, "fire")
	assert_bool(boss.is_defeated()).is_true()
	assert_array(entered).is_equal([1, 2] as Array[int])


func test_qa_a_hit_exactly_to_the_threshold_and_a_hit_of_one_over_both_hold_the_floor() -> void:
	var main := _spawn_main()
	main.player.health.damage_immune = true
	var boss := _boss(main, 14.0)
	boss._attack_cooldown_remaining = 99.0
	await _frames(2)
	var max_hp: float = boss.health.max_health
	var floor_hp: float = max_hp * 0.66
	# Exactly down to the threshold (physical is unresisted): the transition starts, HP is the floor, nothing is skipped.
	boss.health.take_damage(max_hp - floor_hp, "physical")
	assert_bool(boss.is_transitioning()).is_true()
	assert_float(boss.health.current_health).is_equal_approx(floor_hp, 0.001)
	await _frames(_transition_frames())
	assert_int(boss.phase_index).is_equal(1)
	# One point over the next threshold in one hit still stops on it.
	boss.health.take_damage(boss.health.current_health - max_hp * 0.33 + 1.0, "physical")
	assert_float(boss.health.current_health).is_equal_approx(max_hp * 0.33, 0.001)
	assert_bool(boss.is_transitioning()).is_true()


# ---- Resistance ----

func test_qa_the_boss_resists_every_element_by_half_and_physical_goes_through_armor_not_resistance() -> void:
	var main := _spawn_main()
	main.player.health.damage_immune = true
	var boss := _boss(main, 14.0)
	boss._attack_cooldown_remaining = 99.0
	await _frames(2)
	var elements: Array[String] = TierRules.element_ids()
	assert_int(elements.size()).is_greater_equal(1)
	for element: String in elements:
		var before: float = boss.health.current_health
		boss.health.take_damage(10.0, element)
		assert_float(before - boss.health.current_health).override_failure_message("%s: boss did not take exactly half" % element).is_equal_approx(5.0, 0.001)
	var before_physical: float = boss.health.current_health
	boss.health.base_armor = float(BossConfig.boss(BOSS_ID)["armor"])  # the helper zeroes it; physical is halved by armor, not resistance
	boss.health.take_damage(10.0, "physical")
	assert_float(before_physical - boss.health.current_health).is_equal_approx(5.0, 0.001)
	# The shipped number is exactly the GDD's cap, so nothing can stack past it.
	assert_float(boss.health.resistance_cap).is_equal(0.5)
	for element: String in elements:
		assert_float(float(boss.health.resistances.get(element, -1.0))).is_equal(0.5)
	assert_bool(boss.health.resistances.has("physical") and float(boss.health.resistances["physical"]) > 0.0).is_false()


# ---- More bad data ----

func test_qa_more_bad_boss_data_is_refused() -> void:
	var known: Array[String] = EnemyConfig.enemy_ids()
	var cases: Dictionary = {
		"zero windup": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["smash"]["windup"] = 0.0,
		"negative damage": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["smash"]["damage"] = -5.0,
		"zero hp": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["max_health"] = 0.0,
		"negative hp": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["max_health"] = -280.0,
		"charge speed zero": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["charge"]["speed"] = 0.0,
		"volley count zero": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["volley"]["count"] = 0,
		"volley count fractional": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["attacks"]["volley"]["count"] = 2.5,
		"transition zero": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["transition"]["duration"] = 0.0,
		"transition missing": func(c: Dictionary) -> void: c["bosses"][BOSS_ID].erase("transition"),
		"death missing": func(c: Dictionary) -> void: c["bosses"][BOSS_ID].erase("death"),
		"phases missing": func(c: Dictionary) -> void: c["bosses"][BOSS_ID].erase("phases"),
		"attacks missing": func(c: Dictionary) -> void: c["bosses"][BOSS_ID].erase("attacks"),
		"duplicate threshold": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][2]["enters_at"] = 0.66,
		"threshold over 1": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][1]["enters_at"] = 1.5,
		"negative windup scale": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][1]["windup_scale"] = -1.0,
		"empty phase attacks": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][2]["attacks"] = [],
		"summon count zero": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][1]["summon"]["count"] = 0,
		"adds alive over the rules cap": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["max_adds_alive"] = 7,
		"adds cap rule above 10": func(c: Dictionary) -> void: c["rules"]["max_adds_cap"] = 11,
		"min attacks rule below 3": func(c: Dictionary) -> void: c["rules"]["min_attacks"] = 2,
		"max transition rule above 1.5": func(c: Dictionary) -> void: c["rules"]["max_transition"] = 3.0,
		"rules missing": func(c: Dictionary) -> void: c.erase("rules"),
		"slow-mo scale zero": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["death"]["slow_mo_scale"] = 0.0,
		"body radius zero": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["body_radius"] = 0.0,
		"empty display name": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["display_name"] = "  ",
		"phase is a number": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][1] = 4,
		"weight negative": func(c: Dictionary) -> void: c["bosses"][BOSS_ID]["phases"][0]["attacks"][0]["weight"] = -1,
	}
	for label: String in cases.keys():
		var config: Dictionary = _config()
		(cases[label] as Callable).call(config)
		assert_array(BossConfig.validate(config, known)).override_failure_message("accepted bad boss data: " + label).is_not_empty()
	# The unmodified file is valid, and the messages name the fault (loud, not just non-empty).
	assert_array(BossConfig.validate(_config(), known)).is_empty()
	var broken: Dictionary = _config()
	broken["bosses"][BOSS_ID]["attacks"]["smash"]["windup"] = 0.3
	var messages: String = "; ".join(BossConfig.validate(broken, known))
	assert_str(messages).contains("smash").contains("windup")


# ---- The room clear and the death beat with adds alive ----

func test_qa_adds_alive_at_the_kill_do_not_hold_the_room_and_the_player_survives_the_beat() -> void:
	RunSession.begin_new_run(42)
	RunSession.current.room_index = RunGenerator.generate(RunSession.current.seed_value, RunConfig.get_config()).size() - 1
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	main.enemy_spawner._process(3.0)
	var boss: Boss = null
	for child in main.get_children():
		if child is Boss:
			boss = child as Boss
	assert_object(boss).is_not_null()
	if boss == null:
		return
	await _frames(3)
	boss.health.take_damage(9999.0, "physical")
	await _frames(_transition_frames())
	assert_int(boss.live_adds()).is_equal(2)
	assert_bool(main.enemy_spawner.room_cleared()).override_failure_message("room must not be clear while the boss lives").is_false()
	boss._def["death"]["beat_seconds"] = 0.5
	boss.health.hp_floor = 0.0
	boss.health.take_damage(99999.0, "physical")
	assert_bool(boss.is_defeated()).is_true()
	assert_int(boss.live_adds()).override_failure_message("adds must die with the boss").is_equal(0)
	# The player cannot lose during the beat, even to a huge hit or a leftover projectile's damage.
	var hp_before: float = main.player.health.current_health
	main.player.health.take_damage(99999.0, "physical")
	assert_bool(main.player.is_dead()).is_false()
	assert_float(main.player.health.current_health).is_equal(hp_before)
	assert_bool(main.run_controller.is_cleared()).override_failure_message("won before the beat finished").is_false()
	var won: bool = false
	for i in range(240):
		await get_tree().process_frame
		if main.run_controller.is_cleared():
			won = true
			break
	assert_bool(won).override_failure_message("the room never cleared after the boss body went").is_true()
	assert_str(RunSession.current.outcome).is_equal("won")
	assert_bool(main.is_game_over()).is_false()


# ---- Volley: the drawn lane is where the shots hit ----

func _volley_hits(main: Main, boss: Boss, offset: Vector3) -> bool:
	boss.set_physics_process(false)
	boss._attack_id = "volley"
	boss._attack = boss._attacks["volley"]
	boss._lock_dir = Vector3(0.0, 0.0, -1.0)
	boss.global_transform.basis = Basis.looking_at(boss._lock_dir, Vector3.UP)
	boss._state = Boss.State.WINDUP
	main.player.health.damage_immune = false
	main.player.health.current_health = main.player.health.max_health
	main.player._knockback_velocity = Vector3.ZERO
	main.player.global_position = boss.global_position + offset
	await _frames(2)
	boss._land_attack()
	var elapsed: int = 0
	while elapsed < 120:
		await get_tree().physics_frame
		elapsed += 1
		if main.player.health.current_health < main.player.health.max_health:
			break
	var hit: bool = main.player.health.current_health < main.player.health.max_health
	for node in get_tree().get_nodes_in_group("projectiles"):
		node.queue_free()
	await _frames(2)
	return hit


func test_qa_the_volley_lane_edge_matches_the_drawn_width_at_range() -> void:
	var main := _spawn_main()
	var boss := _boss(main, 40.0)
	await _frames(1)
	boss.global_position = Vector3(0.0, 0.0, 12.0)
	var attack: Dictionary = (BossConfig.boss(BOSS_ID)["attacks"] as Dictionary)["volley"]
	var angles: Array[float] = BossRules.volley_angles(int(attack["count"]), float(attack["spread_degrees"]))
	var outer: float = deg_to_rad(angles[angles.size() - 1])
	var half: float = BossRules.volley_half_width(attack)
	# On the outermost lane, 8 m out, measured sideways from the lane's centre line, pushed away from the fan.
	var dist: float = 8.0
	var dir := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, outer)
	var side := Vector3(dir.z, 0.0, -dir.x)  # perpendicular, pointing away from the fan's middle
	if side.dot(Vector3(1.0, 0.0, 0.0)) * sign(outer) < 0.0:
		side = -side
	var centre: Vector3 = dir * dist
	var inside: bool = await _volley_hits(main, boss, centre + side * (half - 0.08))
	var outside: bool = await _volley_hits(main, boss, centre + side * (half + 0.12))
	assert_bool(inside).override_failure_message("just inside the drawn lane edge must be hit").is_true()
	assert_bool(outside).override_failure_message("just outside the drawn lane edge must be safe").is_false()


# ---- Effect lines ----

func test_qa_no_effect_line_carries_a_card_id_a_stat_id_or_a_format_leftover() -> void:
	var ctx := RunChoices.shipped_context([])
	var card_ids: Array[String] = []
	for card: Dictionary in CardDatabase.all_cards():
		card_ids.append(String(card["id"]))
	var banned: Array[String] = ["slot_cooldown", "attack_single", "attack_aoe", "apply_status", "pass_through", "status_id", "damage_type",
			"modifier_type", "true", "false", "null", "nan", "inf", "%d", "%s", "{", "}", "[", "]", "  ", "..", " ,", ".0 ", "x1 "]
	var seen: Array[String] = []
	for card: Dictionary in CardDatabase.all_cards():
		var option: Dictionary = RunChoices.card_option("card:x", "card", String(card["id"]), ctx)
		var line: String = String(option["detail"])
		seen.append("%s => %s" % [card["id"], line])
		assert_str(line).override_failure_message("%s: empty line" % card["id"]).is_not_empty()
		assert_str(line.strip_edges()).override_failure_message("%s: stray whitespace in '%s'" % [card["id"], line]).is_equal(line)
		for id: String in card_ids:
			assert_str(line).override_failure_message("%s: card id %s in '%s'" % [card["id"], id, line]).not_contains(id)
		var lowered: String = line.to_lower()
		for word: String in banned:
			assert_bool(lowered.contains(word)).override_failure_message("%s: '%s' in '%s'" % [card["id"], word, line]).is_false()
		assert_bool(line.contains("_")).override_failure_message("%s: underscore in '%s'" % [card["id"], line]).is_false()
		assert_bool(line.ends_with(" s")).override_failure_message("%s: should end with a cooldown in s: '%s'" % [card["id"], line]).is_true()
		# Every number is followed by something that says what it is.
		var regex := RegEx.new()
		regex.compile("\\d+(\\.\\d+)?")
		var units: Array[String] = [" s", " m", " HP", "%", " fire", " physical", " water", " damage", " hits"]
		for found in regex.search_all(line):
			var after: String = line.substr(found.get_end(), 10)
			var has_unit: bool = false
			for unit: String in units:
				if after.begins_with(unit):
					has_unit = true
			assert_bool(has_unit).override_failure_message("%s: bare number '%s' in '%s'" % [card["id"], found.get_string(), line]).is_true()
	print("QA EFFECT LINES\n" + "\n".join(seen))


# ---- Space and Enter on the Continue / New run prompt, real key events ----

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


func test_qa_continue_ignores_space_and_enter_until_armed_and_space_after_but_not_enter() -> void:
	for kind: String in ["room", "win"]:
		var prompt := (load("res://scenes/ui/RunPromptScreen.tscn") as PackedScene).instantiate() as RunPromptScreen
		prompt.kind = kind
		add_child(prompt)
		auto_free(prompt)
		await get_tree().process_frame
		prompt.show_content({"title": "t", "rows": [], "button": "Go", "hint": "Enter to go"})
		var confirmed: Array[bool] = []
		prompt.confirmed.connect(func() -> void: confirmed.append(true))
		assert_bool(prompt.options_armed()).is_false()
		for code: Key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_key(code)
			await get_tree().process_frame
		prompt.button.pressed.emit()
		assert_array(confirmed).override_failure_message("%s confirmed inside the arm delay" % kind).is_empty()
		await TestClock.wait_real(get_tree(), 0.6)
		assert_bool(prompt.options_armed()).is_true()
		for i in range(4):
			_key(KEY_SPACE)
			await get_tree().process_frame
		assert_array(confirmed).override_failure_message("%s: Space confirmed after arming" % kind).is_empty()
		assert_bool(prompt.visible).is_true()
		prompt.button.pressed.emit()
		assert_array(confirmed).override_failure_message("%s: armed press did not confirm" % kind).has_size(1)


# ---- RunState.from_dict ----

func test_qa_from_dict_survives_a_hostile_pending_and_offer() -> void:
	var base: Dictionary = {"seed": 5, "room_index": 1, "hp": 20.0, "max_hp": 30.0, "deck": ["a"], "rejects_remaining": 3, "history": []}
	for pending: Variant in ["bogus", "REWARD", "reward\n", 7, null, [], {}, "rest_remove ", "rest;remove"]:
		var data: Dictionary = base.duplicate(true)
		data["pending"] = pending
		data["offer"] = ["x", "y", "z"]
		var state := RunState.from_dict(data)
		assert_object(state).is_not_null()
		if state == null:
			continue
		assert_bool(state.has_pending()).override_failure_message("pending %s kept open" % str(pending)).is_false()
		assert_array(state.offer).override_failure_message("offer survived a dropped pending (%s)" % str(pending)).is_empty()
	# The round trip of a valid pending is exact.
	var ok: Dictionary = base.duplicate(true)
	ok["pending"] = RunState.PENDING_REWARD
	ok["offer"] = ["a", "b", "c"]
	var again := RunState.from_dict(RunState.from_dict(ok).to_dict())
	assert_str(again.pending).is_equal(RunState.PENDING_REWARD)
	assert_array(again.offer).is_equal(["a", "b", "c"])
