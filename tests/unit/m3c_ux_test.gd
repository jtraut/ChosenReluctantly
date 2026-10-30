class_name M3cUxTest
extends GdUnitTestSuite
## Milestone 3c UX: the boss HP bar (layout, tick maths, resistance wording, live state through a phase change, the
## roar and the death), and the 3b follow-ups (slot contents on offers, the locked-removal reason, plain effect
## lines with units, the Reject title, the Continue button's arm delay and Space).

const MAIN_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]


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


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _boss(main: Main) -> Boss:
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -8.0)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	boss.health.base_armor = 0.0  # the HP-bar tests count raw HP; armor has its own tests (a1_armor_test.gd)
	return boss


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)


# ---- Layout ----

func test_boss_bar_clears_every_other_hud_piece_at_all_resolutions() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var rect := HudLayout.boss_bar_rect(vp, cfg)
		assert_bool(HudLayout.safe_area(vp, cfg).encloses(rect)).override_failure_message("inside safe area at %s" % vp).is_true()
		assert_bool(rect.intersects(HudLayout.room_indicator_rect(vp, cfg))).override_failure_message("room indicator at %s" % vp).is_false()
		assert_bool(rect.intersects(HudLayout.health_rect(vp, cfg))).override_failure_message("health at %s" % vp).is_false()
		assert_bool(rect.intersects(HudLayout.slot_bar_rect(vp, cfg, 5))).override_failure_message("slots at %s" % vp).is_false()
		var meters := HudLayout.attack_meter_rects(vp, cfg)
		for key: StringName in meters:
			assert_bool(rect.intersects(meters[key])).override_failure_message("meter %s at %s" % [key, vp]).is_false()
		# A real margin, not touching edges, from the nearest neighbour on each side.
		var gap: float = 8.0 * HudLayout.ui_scale(vp, cfg)
		assert_float(rect.position.x - (meters[&"heavy"] as Rect2).end.x).is_greater_equal(gap)
		assert_float(HudLayout.room_indicator_rect(vp, cfg).position.x - rect.end.x).is_greater_equal(gap)
		assert_float(HudLayout.slot_bar_rect(vp, cfg, 5).position.y - rect.end.y).is_greater_equal(gap)


func test_the_f3_overlay_starts_under_the_boss_bar_and_the_meters() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var top: float = HudLayout.debug_overlay_top(vp, cfg)
		assert_float(top).is_greater(HudLayout.boss_bar_rect(vp, cfg).end.y)
		assert_float(top).is_greater((HudLayout.attack_meter_rects(vp, cfg)[&"heavy"] as Rect2).end.y - 1.0)
	assert_float(HudLayout.debug_overlay_top(Vector2(1280, 720), cfg)).is_greater_equal(120.0)


func test_the_boss_block_is_tall_enough_for_its_rows() -> void:
	var hud := UiConfig.hud()
	var bar := UiConfig.boss_bar()
	var rows: float = 0.0
	for key: String in ["name_height", "meter_height", "info_height", "attack_height"]:
		rows += float(bar[key])
	rows += 3.0 * float(bar["row_gap"])
	assert_float(float((hud["boss_bar_size"] as Array)[1])).is_greater_equal(rows)


# ---- Bar maths and words ----

func test_tick_and_fill_edge_use_the_same_x() -> void:
	for frame: float in [2.0, 4.0, 8.0]:
		assert_float(BossMeter.edge_x(0.0, 20.0, 400.0, frame)).is_equal(22.0 if frame == 2.0 else 20.0 + frame)
		assert_float(BossMeter.edge_x(1.0, 20.0, 400.0, frame)).is_equal(420.0 - frame)
		# The tick for a threshold and the fill edge of HP parked on it are the same call, so the same pixel.
		var meter := BossMeter.new()
		auto_free(meter)
		meter.size = Vector2(440.0, 26.0)
		meter.pip = 20.0
		meter.border = frame
		meter.resist_border = frame
		var bar := meter.bar_rect()
		for threshold: float in [0.66, 0.33]:
			assert_float(BossMeter.edge_x(threshold, bar.position.x, bar.size.x, frame)).is_equal(BossMeter.edge_x(threshold, bar.position.x, bar.size.x, meter._frame_width()))
		assert_float(BossMeter.edge_x(0.66, 20.0, 400.0, frame)).is_greater(BossMeter.edge_x(0.33, 20.0, 400.0, frame))
	assert_float(BossMeter.edge_x(-1.0, 0.0, 100.0, 2.0)).is_equal(2.0)
	assert_float(BossMeter.edge_x(2.0, 0.0, 100.0, 2.0)).is_equal(98.0)


func test_the_shipped_boss_thresholds_land_on_the_floor_fractions() -> void:
	# The bar draws ticks from phase_thresholds(); HP is parked on hp_floor = threshold * max.
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	var thresholds: Array[float] = boss.phase_thresholds()
	assert_int(thresholds.size()).is_equal(boss.phase_count() - 1)
	var max_hp: float = boss.health.max_health
	for i in range(thresholds.size()):
		var floor_hp: float = BossRules.floor_hp(BossConfig.boss(boss.enemy_id)["phases"], i + 1, max_hp)
		assert_float(floor_hp / max_hp).is_equal_approx(thresholds[i], 0.0001)


func test_phase_text_and_crossed_count() -> void:
	var cfg := UiConfig.boss_bar()
	assert_str(BossHpBar.phase_text(String(cfg["phase_format"]), 1, 3, "Getting into it")).is_equal("Phase 2 of 3: Getting into it")
	var thresholds: Array[float] = [0.66, 0.33]
	assert_int(BossHpBar.crossed_count(0, thresholds)).is_equal(0)
	assert_int(BossHpBar.crossed_count(1, thresholds)).is_equal(1)
	assert_int(BossHpBar.crossed_count(2, thresholds)).is_equal(2)
	assert_int(BossHpBar.crossed_count(9, thresholds)).is_equal(2)


func test_resistance_tint_and_words_for_equal_and_unequal_resistance() -> void:
	var bars := UiConfig.hp_bars()
	var neutral := Color.html(String(bars["default_resistance_tint"]))
	var even: Dictionary = {"fire": 0.5, "water": 0.5}
	assert_bool(BossHpBar.resists_uniformly(even)).is_true()
	assert_bool(BossHpBar.resist_tint(even, bars).is_equal_approx(Color(neutral.r, neutral.g, neutral.b, 1.0))).is_true()
	assert_bool(BossHpBar.resist_tint({"fire": 0.5}, bars).is_equal_approx(Color(neutral.r, neutral.g, neutral.b, 1.0))).is_true()
	var uneven: Dictionary = {"fire": 0.5, "water": 0.25}
	var fire_tint := Color.html(String(bars["resistance_tints"]["fire"]))
	assert_bool(BossHpBar.resists_uniformly(uneven)).is_false()
	assert_bool(BossHpBar.resist_tint(uneven, bars).is_equal_approx(Color(fire_tint.r, fire_tint.g, fire_tint.b, 1.0))).is_true()
	assert_float(BossHpBar.resist_tint({}, bars).a).is_equal(0.0)
	assert_float(BossHpBar.resist_tint({"fire": 0.0}, bars).a).is_equal(0.0)
	var cfg := UiConfig.boss_bar()
	assert_str(BossHpBar.resist_text(even, cfg)).is_equal("Resists all elements 50%")
	assert_str(BossHpBar.resist_text(uneven, cfg)).is_equal("Resists some elements (up to 50%)")
	assert_str(BossHpBar.resist_text({}, cfg)).is_empty()
	# The shared enemy-bar helper is untouched: it still picks the first strongest key.
	assert_str(EnemyHpBar.dominant_resistance(even)).is_equal("fire")


# ---- The live bar ----

func test_the_bar_follows_the_boss_through_a_phase_change_and_hides_on_death() -> void:
	var main := _spawn_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	assert_bool(bar.is_showing()).is_false()  # no boss yet: nothing on screen
	var boss := _boss(main)
	await _frames(3)
	assert_bool(bar.is_showing()).is_true()
	assert_object(bar.current_boss()).is_same(boss)
	assert_str(bar._name_label.text).is_equal(boss.display_name())
	assert_str(bar._phase_label.text).contains("Phase 1 of 3")
	assert_str(bar._resist_label.text).is_equal("Resists all elements 50%")
	assert_float(bar._meter.fill).is_equal(1.0)
	# A hit moves the fill at once and the ghost trails behind.
	boss.health.take_damage(20.0, "physical")
	assert_float(bar._meter.fill).is_less(1.0)
	assert_float(bar._meter.ghost).is_greater(bar._meter.fill)
	# Crossing the first threshold: invulnerable look and words, then the new phase.
	boss.health.take_damage(boss.health.max_health * 0.8, "physical")
	assert_bool(bar._meter.invulnerable).is_true()
	assert_str(bar._phase_label.text).is_equal(String(UiConfig.boss_bar()["invulnerable_text"]))
	assert_int(bar._meter.crossed).is_equal(1)
	var duration: float = float((BossConfig.boss(boss.enemy_id)["transition"] as Dictionary)["duration"])
	for i in range(int((duration + 0.3) * float(Engine.physics_ticks_per_second))):
		await get_tree().physics_frame
	assert_bool(bar._meter.invulnerable).is_false()
	assert_str(bar._phase_label.text).contains("Phase 2 of 3")
	# The kill hides it (after its short fade).
	boss.health.take_damage(boss.health.max_health * 0.4, "physical")
	await _frames(1)
	for i in range(int((duration + 0.3) * float(Engine.physics_ticks_per_second))):
		await get_tree().physics_frame
	boss.health.take_damage(boss.health.max_health, "physical")
	assert_bool(boss.is_defeated()).is_true()
	await TestClock.wait_real(get_tree(), 0.7)
	assert_bool(bar.is_showing()).is_false()


func test_the_attack_label_shows_while_winding_up_and_clears_at_the_landing() -> void:
	var main := _spawn_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	var boss := _boss(main)
	boss.debug_script_attacks(["smash"] as Array[String])
	boss.target = main.player
	main.player.global_position = boss.global_position + Vector3(0.0, 0.0, 2.0)
	await _frames(2)
	var label: String = String(((BossConfig.boss(boss.enemy_id)["attacks"] as Dictionary)["smash"] as Dictionary)["label"])
	var seen: bool = false
	for i in range(int(6.0 * float(Engine.physics_ticks_per_second))):
		await get_tree().physics_frame
		if boss.telegraph_left() > 0.0:
			seen = true
			assert_str(bar._attack_label.text).is_equal(label)
			assert_bool(bar._attack_label.visible).is_true()
			break
	assert_bool(seen).is_true()
	for i in range(int(2.0 * float(Engine.physics_ticks_per_second))):
		await get_tree().physics_frame
		if boss.telegraph_left() <= 0.0:
			break
	await _frames(2)
	assert_bool(bar._attack_label.visible).is_false()


func test_the_bar_hides_when_the_player_dies_and_with_no_boss_in_the_scene() -> void:
	var main := _spawn_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	_boss(main)
	await _frames(3)
	assert_bool(bar.is_showing()).is_true()
	main.player.health.take_damage(100000.0, "physical")
	await TestClock.wait_real(get_tree(), 0.7)
	assert_bool(bar.is_showing()).is_false()
	# The endless arena's ordinary rank-boss enemies are not Boss nodes: no bar for them.
	main.queue_free()
	await _frames(3)
	var arena := _spawn_main()
	arena.player.camera = null
	var chaser: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	arena.add_child(chaser)
	chaser.status_manager.rank = "boss"
	var arena_bar := arena.get_node("BossHpBar") as BossHpBar
	await _frames(3)
	assert_bool(arena_bar.is_showing()).is_false()


func test_binding_mid_transition_reads_the_live_state() -> void:
	var main := _spawn_main()
	var boss := _boss(main)
	await _frames(2)
	boss.health.take_damage(boss.health.max_health * 0.8, "physical")
	assert_bool(boss.is_transitioning()).is_true()
	# A bar that appears now (a reload mid-roar) must start in the invulnerable state, not wait for a signal.
	var late := (load("res://scenes/ui/BossHpBar.tscn") as PackedScene).instantiate() as BossHpBar
	main.add_child(late)
	await _frames(3)
	assert_bool(late.is_showing()).is_true()
	assert_bool(late._meter.invulnerable).is_true()
	assert_int(late._meter.crossed).is_equal(1)


# ---- Offer cards: what is in the slot now ----

func test_slot_now_text() -> void:
	var fmt: String = String(RunConfig.ui()["option"]["slot_now"])
	assert_str(RunOptionCard.slot_now_text(1, ["A", "B", "C"], fmt)).is_equal("Slot 1 now: A / B / C")
	assert_str(RunOptionCard.slot_now_text(4, ["A"], fmt)).is_equal("Slot 4 now: A")
	assert_str(RunOptionCard.slot_now_text(2, [], fmt)).is_empty()
	assert_str(RunOptionCard.slot_now_text(0, ["A"], fmt)).is_empty()


func test_an_offer_card_lists_the_slot_contents_from_the_model() -> void:
	var ctx := RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var state := RunSession.begin_new_run(3)
	state.offer = RewardOffer.generate(state.seed_value, 1, state.deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
	state.pending = RunState.PENDING_REWARD
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	var cfg := UiConfig.run_ui()
	for option: Dictionary in options:
		if String(option["kind"]) != "card":
			continue
		assert_array(option["slot_contents"] as Array).is_not_empty()
		var card := RunOptionCard.new()
		card.setup(option, RunOptionCard.Look.CARD, float(cfg["option_card_width"]), cfg, 1.0, {"index": 0, "texts": RunConfig.ui()["option"], "owned": 0})
		auto_free(card)
		assert_object(card.slot_now_label).is_not_null()
		var key: int = RunOptionCard.slot_key_for(String(option["slot_type"]))
		assert_str(card.slot_now_label.text).starts_with("Slot %d now: " % key)
		for card_name: String in option["slot_contents"]:
			assert_str(card.slot_now_label.text).contains(card_name)


# ---- The locked removal says what to do ----

func test_a_locked_removal_says_what_to_get_first() -> void:
	var ctx := RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var state := RunSession.begin_new_run(3)
	state.pending = RunState.PENDING_REST_REMOVE
	var locked: int = 0
	for option: Dictionary in RunChoices.options(state, ctx):
		if String(option["kind"]) != "remove" or bool(option["enabled"]):
			continue
		locked += 1
		var reason: String = String(option["reason"])
		assert_str(reason).starts_with("Get another ").contains(String(option["slot_name"])).contains("minimum 3 different")
		assert_str(reason).not_contains("unique").not_contains("deck has")
	assert_int(locked).is_greater(0)
	# The wording is data: a changed template changes the reason, and nothing in code names a slot.
	var ctx2: Dictionary = ctx.duplicate(true)
	(ctx2["ui"]["rest"] as Dictionary)["remove_locked"] = "Nope: %s needs %d."
	for option: Dictionary in RunChoices.options(state, ctx2):
		if String(option["kind"]) == "remove" and not bool(option["enabled"]):
			assert_str(String(option["reason"])).starts_with("Nope: ")
			break


# ---- Plain effect lines ----

func test_every_shipped_card_has_a_plain_effect_line() -> void:
	var ctx := RunChoices.shipped_context([])
	var raw: Array[String] = ["apply_status", "pass_through", "slot_cooldown", "damage_type", "status_id", "_"]
	for card: Dictionary in CardDatabase.all_cards():
		var line: String = String(RunChoices.card_option("card:x", "card", String(card["id"]), ctx)["detail"])
		assert_str(line).override_failure_message("%s: empty effect line" % card["id"]).is_not_empty()
		for word: String in raw:
			assert_str(line).override_failure_message("%s: '%s' in '%s'" % [card["id"], word, line]).not_contains(word)
		assert_str(line).override_failure_message("%s: no unit-less decimals like '6.0': '%s'" % [card["id"], line]).not_contains(".0 ")
		assert_str(line).contains("Cooldown ")


func test_effect_wording_carries_units() -> void:
	var ctx := RunChoices.shipped_context([])
	var text: Dictionary = (ctx["ui"]["effect"] as Dictionary).duplicate()
	text["statuses"] = ctx["statuses"]
	text["slot_names"] = ctx["slot_names"]
	assert_str(CardSummary.effect_line({"effects": [{"template": "dash", "params": {"distance": 6.5}}]}, -1.0, text)).is_equal("Dash 6.5 m")
	assert_str(CardSummary.effect_line({"effects": [{"template": "dash", "params": {"distance": 4.5, "direction_mode": "away_from_aim", "damage": 8, "damage_type": "physical"}}]}, -1.0, text)).is_equal("Dash 4.5 m away from your aim, 8 physical damage")
	assert_str(CardSummary.effect_line({"effects": [{"template": "apply_status", "params": {"status_id": "leech", "duration": 7.0}}]}, -1.0, text)).is_equal("Leech 40% for 7 s")
	assert_str(CardSummary.effect_line({"effects": [{"template": "apply_status", "params": {"status_id": "burn", "duration": 5.0}}]}, -1.0, text)).is_equal("Burn 2 damage/s for 5 s")
	assert_str(CardSummary.effect_line({"effects": [{"template": "apply_status", "params": {"status_id": "regeneration", "duration": 7.0}}]}, -1.0, text)).is_equal("Regeneration 2 HP/s for 7 s")
	assert_str(CardSummary.effect_line({"effects": [{"template": "cone", "params": {"damage": 2.0, "hits": 4, "damage_type": "physical"}}]}, 3.3, text)).is_equal("2 physical damage x 4 hits (cone). Cooldown 3.3 s")
	assert_str(CardSummary.effect_line({"effects": [{"template": "heal", "params": {"amount": 8}}]}, -1.0, text)).is_equal("Heal 8 HP")
	assert_str(CardSummary.effect_line({"effects": [{"template": "pass_through", "params": {"duration": 2.5}}]}, -1.0, text)).is_equal("Walk through enemies for 2.5 s")
	# An unknown status (no data given) still reads as words, never a raw id.
	assert_str(CardSummary.effect_line({"effects": [{"template": "apply_status", "params": {"status_id": "odd_thing", "duration": 3.0}}]}, -1.0)).is_equal("Odd Thing for 3 s")


# ---- The Reject tile title ----

func test_the_reject_title_stays_on_one_line_inside_its_tile() -> void:
	var cfg := UiConfig.run_ui()
	for scale: float in [1.0, 1.5, 2.0]:
		var option: Dictionary = {"id": "skip", "kind": "skip", "label": String(RunConfig.ui()["reward"]["skip_label"]), "detail": "Spends one reject. Rejects left: 3 of 3", "flavor": "", "card_id": "", "slot_type": "", "slot_name": "", "count": 0, "enabled": true, "reason": "", "costs_reject": true, "opens_list": false, "amount": 0.0}
		var card := RunOptionCard.new()
		card.setup(option, RunOptionCard.Look.REJECT, float(cfg["option_reject_width"]), cfg, scale, {"index": 3, "texts": RunConfig.ui()["option"], "rejects_remaining": 3, "rejects_max": 3})
		auto_free(card)
		add_child(card)
		await _frames(2)
		assert_int(card.title_label.autowrap_mode).is_equal(TextServer.AUTOWRAP_OFF)
		var font := card.title_label.get_theme_font("font")
		var size: int = card.title_label.get_theme_font_size("font_size")
		var width: float = font.get_string_size(card.title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		assert_float(width).is_less_equal(card.title_label.custom_minimum_size.x + 0.5)
		assert_int(card.title_label.get_line_count()).is_equal(1)


# ---- Continue / New run: arm delay and Space ----

func test_the_continue_button_ignores_presses_until_armed_and_never_takes_space() -> void:
	RunSession.begin_new_run(42)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(1)
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	prompt.show_content({"title": "t", "rows": [], "button": "Continue"})
	assert_bool(prompt.options_armed()).is_false()
	assert_float(prompt.button.modulate.a).is_less(1.0)  # dim while it ignores presses
	var confirmed: Array[bool] = []
	prompt.confirmed.connect(func() -> void: confirmed.append(true))
	prompt.button.pressed.emit()
	assert_array(confirmed).is_empty()  # an early press (a held Enter, a click) does nothing
	assert_bool(prompt.visible).is_true()
	await TestClock.wait_real(get_tree(), 0.6)
	assert_bool(prompt.options_armed()).is_true()
	assert_float(prompt.button.modulate.a).is_equal(1.0)
	# Space is swallowed even once armed: a focused button would otherwise take it as ui_accept.
	for i in range(3):
		_key(KEY_SPACE)
		await get_tree().process_frame
	assert_array(confirmed).is_empty()
	assert_bool(prompt.visible).is_true()
	prompt.button.pressed.emit()
	assert_array(confirmed).has_size(1)


func test_the_hints_no_longer_offer_space() -> void:
	var ui: Dictionary = RunConfig.ui()
	for key: String in ["room_cleared", "win"]:
		assert_str(String((ui[key] as Dictionary)["hint"])).not_contains("Space")
		assert_str(String((ui[key] as Dictionary)["hint"])).contains("Enter")
