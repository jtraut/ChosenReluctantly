class_name Bd3bUxTest
extends GdUnitTestSuite
## BD3b-ux: the Charge counter and Spiteful Ward cue (StatusReadout), the scale text on a slot, the new condition lines, "Swap: free", the pool-tag chip
## decision and Liquidate Assets' current value. Values are read from data; a test that needs a number takes it from the same data.

const WARD_CARD := "wizard_spiteful_ward"
const WARD_SOURCE := "card:wizard_spiteful_ward"

var _spy_fired: Array[String] = []


func before_test() -> void:
	CombatEvents.reset()
	_spy_fired = []


func after_test() -> void:
	BodyFlag.reset()
	CombatEvents.reset()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame  # the HUD polls in _process


## The real Main with a Wizard (the HUD is the real one).
func _main() -> Main:
	BodyFlag.set_collide(false)
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = "wizard"
	add_child(main)
	auto_free(main)
	main.player.camera = null
	return main


# --- StatusReadout: pure rules ---

func test_decay_fraction_is_the_time_left_over_the_window_and_minus_one_without_a_window() -> void:
	assert_float(StatusReadout.decay_fraction(2.0, 4.0)).is_equal_approx(0.5, 0.0001)
	assert_float(StatusReadout.decay_fraction(9.0, 4.0)).is_equal(1.0)
	assert_float(StatusReadout.decay_fraction(-1.0, 4.0)).is_equal(0.0)
	assert_float(StatusReadout.decay_fraction(2.0, 0.0)).is_equal(-1.0)


func test_counter_label_reads_stacks_over_cap_and_adds_the_max_word_at_the_cap() -> void:
	var texts: Dictionary = RunConfig.ui()["status_readout"]
	assert_str(StatusReadout.counter_label({"name": "Charge", "stacks": 6, "max": 10}, texts)).is_equal("Charge 6/10")
	assert_str(StatusReadout.counter_label({"name": "Charge", "stacks": 10, "max": 10}, texts)).is_equal("Charge 10/10" + String(texts["max_suffix"]))
	assert_str(StatusReadout.counter_label({"name": "Charge", "stacks": 10, "max": 15}, texts)).is_equal("Charge 10/15")


func test_trigger_fraction_and_seconds_text() -> void:
	var texts: Dictionary = RunConfig.ui()["status_readout"]
	assert_float(StatusReadout.trigger_fraction(1.0, 4.0)).is_equal_approx(0.25, 0.0001)
	assert_float(StatusReadout.trigger_fraction(5.0, 4.0)).is_equal(1.0)
	assert_float(StatusReadout.trigger_fraction(1.0, -1.0)).is_equal(1.0)  # an unknown life is a full bar
	assert_str(StatusReadout.seconds_text(3.25, texts)).is_equal("3.2 s" if String("%.1f" % 3.25) == "3.2" else "3.3 s")
	assert_str(StatusReadout.seconds_text(-1.0, texts)).is_equal("0.0 s")


func test_source_name_is_the_card_name_and_never_a_hard_coded_string() -> void:
	var texts: Dictionary = RunConfig.ui()["status_readout"]
	assert_str(StatusReadout.source_name(WARD_SOURCE, texts)).is_equal(String(CardDatabase.get_card(WARD_CARD)["name"]))
	assert_str(StatusReadout.source_name("", texts)).is_equal(String(texts["trigger_fallback"]))
	assert_str(StatusReadout.source_name("card:no_such_card", texts)).is_equal("no_such_card")


func test_visible_rows_put_counters_first_and_cut_at_the_row_budget() -> void:
	var counters: Array[Dictionary] = [{"id": "a"}, {"id": "b"}]
	var triggers: Array[Dictionary] = [{"source": "x"}]
	var rows: Array[Dictionary] = StatusReadout.visible_rows(counters, triggers, 2)
	assert_int(rows.size()).is_equal(2)
	assert_str(String(rows[0]["kind"])).is_equal("counter")
	assert_str(String(rows[1]["kind"])).is_equal("counter")
	var more: Array[Dictionary] = StatusReadout.visible_rows(([{"id": "a"}] as Array[Dictionary]), triggers, 2)
	assert_str(String(more[1]["kind"])).is_equal("trigger")
	assert_int(StatusReadout.visible_rows(counters, triggers, 0).size()).is_equal(0)


func test_the_status_space_is_reserved_so_the_relic_row_sits_under_it_at_every_size() -> void:
	var cfg: Dictionary = UiConfig.hud()
	for size: Vector2 in [Vector2(1024, 600), Vector2(1280, 720), Vector2(1600, 900), Vector2(2560, 1440)]:
		var status: Rect2 = HudLayout.status_rect(size, cfg)
		var dodge: Rect2 = HudLayout.dodge_rect(size, cfg)
		var relics: Rect2 = HudLayout.relic_row_rect(size, cfg, 20)
		var slots: Rect2 = HudLayout.slot_bar_rect(size, cfg, 5)
		assert_bool(status.position.y >= dodge.end.y).override_failure_message("status overlaps the dodge row at %s" % size).is_true()
		assert_bool(relics.position.y >= status.end.y).override_failure_message("relic row overlaps the status rows at %s" % size).is_true()
		assert_bool(relics.end.y < slots.position.y).override_failure_message("20 relics reach the slots at %s" % size).is_true()
		assert_bool(HudLayout.safe_area(size, cfg).encloses(status)).is_true()
		assert_float(status.size.y).is_greater_equal(float(cfg["status_rows"]) * (float(cfg["status_min_font_px"]) + 4.0))


# --- StatusReadout: on the real player ---

func test_the_counter_row_follows_the_players_stacks_and_the_cap_the_status_manager_reports() -> void:
	var main: Main = _main()
	await _frames(3)
	var readout: StatusReadout = main.hud.status_readout
	assert_int(readout.counters().size()).is_equal(0)
	var def: Dictionary = StatusDatabase.get_status("charge")
	for i in range(3):
		main.player.hurtbox.status_manager.apply_status("charge", def, 4.0, main.player)
	await _frames(2)
	var row: Dictionary = readout.counters()[0]
	assert_str(String(row["id"])).is_equal("charge")
	assert_int(int(row["stacks"])).is_equal(3)
	assert_int(int(row["max"])).is_equal(int(def["stacking"]["max_stacks"]))
	assert_float(float(row["decay_fraction"])).is_between(0.0, 1.0)
	# A relic that raises the cap (Reading List: `status_max_stacks.charge`) moves the shown cap too.
	main.player.stat_modifiers.add_modifier("status_max_stacks.charge", "test_reading_list", "additive", 5.0)
	await _frames(2)
	assert_int(int(readout.counters()[0]["max"])).is_equal(int(def["stacking"]["max_stacks"]) + 5)
	main.player.stat_modifiers.remove_modifier("status_max_stacks.charge", "test_reading_list")


func test_only_counter_statuses_get_a_counter_row() -> void:
	var main: Main = _main()
	await _frames(3)
	main.player.hurtbox.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 3.0, main.player)
	await _frames(2)
	assert_int(main.hud.status_readout.counters().size()).is_equal(0)


func test_the_ward_row_goes_live_with_the_buff_fires_with_a_flash_and_leaves_when_it_ends() -> void:
	var main: Main = _main()
	var player: Player = main.player
	await _frames(3)
	var readout: StatusReadout = main.hud.status_readout
	readout.trigger_fired.connect(func(source: String, _label: String) -> void: _spy_fired.append(source))
	var deck: Array[String] = [WARD_CARD]
	deck.append_array(player.card_slots.owned_card_ids())
	player.card_slots.set_deck(deck)
	assert_bool(player.card_slots.reveal_first(WARD_CARD)).is_true()
	assert_bool(player.card_slots.try_use("utility")).is_true()
	await _frames(3)
	assert_bool(readout.triggers().has(WARD_SOURCE)).override_failure_message("the live ward has a row").is_true()
	var rows: Array[Dictionary] = readout.rows()
	assert_int(rows.size()).is_equal(1)
	assert_str(String(rows[0]["kind"])).is_equal("trigger")
	assert_str(String(rows[0]["name"])).is_equal(String(CardDatabase.get_card(WARD_CARD)["name"]))
	assert_float(float(rows[0]["time_left"])).is_greater(0.0)
	assert_float(float(rows[0]["fraction"])).is_between(0.0, 1.0)
	# A hit fires the nova: the flash lights, the count starts, the signal goes out once.
	var host: RelicManager = player.get_node(RelicManager.BUFF_HOST_NAME)
	player.hurtbox.receive_damage(5.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "enemy")
	host.flush()
	assert_int(_spy_fired.size()).is_equal(1)
	assert_str(_spy_fired[0]).is_equal(WARD_SOURCE)
	assert_bool(RelicFlash.is_active((readout.triggers()[WARD_SOURCE] as Dictionary)["flash"])).is_true()
	host.remove_buff_triggers(WARD_SOURCE, "cleared")
	await _frames(2)
	assert_int(readout.rows().size()).is_equal(0)
	BodyFlag.reset()


func test_the_floating_cue_takes_a_named_cue_without_a_held_relic() -> void:
	var main: Main = _main()
	await _frames(2)
	main.hud.relic_cues.on_named_cue(WARD_SOURCE, "Spiteful Ward")
	main.hud.relic_cues.on_named_cue(WARD_SOURCE, "Spiteful Ward")
	assert_int(main.hud.relic_cues.cues().size()).is_equal(1)  # a burst merges into one cue
	assert_int(int(main.hud.relic_cues.cues()[0]["count"])).is_equal(2)
