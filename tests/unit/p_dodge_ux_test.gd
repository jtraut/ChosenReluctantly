class_name PDodgeUxTest
extends GdUnitTestSuite
## P-dodge ux: the dodge pip indicator (pip count per class, the recharging pip, the 0-charge state, layout at the
## supported sizes) and the boss bar's STAGGERED state (4c).

const MAIN_PATH := "res://scenes/main/Main.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const SIZES: Array[Vector2] = [Vector2(1024, 600), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]


func before_test() -> void:
	Juice.hit_stop_enabled = false


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0
	BossConfig.reset_cache()


func _spawn_main(character: String) -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = character
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	main.player.health.damage_immune = true
	return main


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _idle(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func test_pip_fill_is_ready_then_recharging_then_empty() -> void:
	# 3 max, 1 ready, the second pip 40% back.
	assert_float(DodgePips.pip_fill(0, 1, 3, true, 0.4)).is_equal(1.0)
	assert_float(DodgePips.pip_fill(1, 1, 3, true, 0.4)).is_equal_approx(0.4, 0.0001)
	assert_float(DodgePips.pip_fill(2, 1, 3, true, 0.4)).is_equal(0.0)
	assert_float(DodgePips.pip_fill(3, 1, 3, true, 0.4)).override_failure_message("a pip past the maximum").is_equal(0.0)
	# Full: every pip full, no partial one.
	for i in range(3):
		assert_float(DodgePips.pip_fill(i, 3, 3, false, 1.0)).is_equal(1.0)
	# Progress is clamped.
	assert_float(DodgePips.pip_fill(0, 0, 2, true, 7.0)).is_equal(1.0)


func test_status_word_at_zero_charges_and_no_pips() -> void:
	var cfg := UiConfig.hud()
	assert_str(DodgePips.status_word(2, 3, cfg)).is_empty()
	assert_str(DodgePips.status_word(0, 3, cfg)).is_equal(String(cfg["dodge_empty_word"]))
	assert_str(DodgePips.status_word(0, 0, cfg)).is_equal(String(cfg["dodge_none_word"]))
	assert_str(String(cfg["dodge_empty_word"])).is_not_empty()


func test_rogue_shows_three_pips_and_wizard_two() -> void:
	var rogue := _spawn_main("rogue")
	await _idle(3)
	assert_int(rogue.hud.dodge_pips.pip_count()).is_equal(3)
	assert_int(rogue.hud.dodge_pips.ready_count()).is_equal(3)
	assert_str(rogue.hud.dodge_pips.word()).is_empty()
	var wizard := _spawn_main("wizard")
	await _idle(3)
	assert_int(wizard.hud.dodge_pips.pip_count()).is_equal(2)
	assert_int(wizard.hud.dodge_pips.ready_count()).is_equal(2)


func test_pips_follow_spending_and_the_zero_state() -> void:
	var main := _spawn_main("rogue")
	await _idle(3)
	var player := main.player
	assert_bool(player.dodge_charges.try_spend(3)).is_true()
	await _idle(2)
	assert_int(main.hud.dodge_pips.ready_count()).is_equal(2)
	assert_int(main.hud.dodge_pips.pip_count()).is_equal(3)
	player.dodge_charges.try_spend(3)
	player.dodge_charges.try_spend(3)
	await _idle(2)
	assert_int(main.hud.dodge_pips.ready_count()).is_equal(0)
	assert_str(main.hud.dodge_pips.word()).is_equal("EMPTY")
	player.stat_modifiers.add_modifier("dodge_charges", "test", StatModifiers.ADDITIVE, -9.0)
	await _idle(3)
	assert_int(main.hud.dodge_pips.pip_count()).override_failure_message("0 charges draws no pips").is_equal(0)
	assert_str(main.hud.dodge_pips.word()).is_equal("NO DODGE")
	player.stat_modifiers.remove_modifier("dodge_charges", "test")
	player.stat_modifiers.add_modifier("dodge_charges", "test", StatModifiers.ADDITIVE, 9.0)
	await _idle(3)
	assert_int(main.hud.dodge_pips.pip_count()).override_failure_message("clamped to 4").is_equal(4)


func test_dodge_row_fits_the_safe_area_and_clears_the_other_meters_at_every_size() -> void:
	var cfg := UiConfig.hud()
	for vp: Vector2 in SIZES:
		var r := HudLayout.dodge_rect(vp, cfg)
		var heavy: Rect2 = HudLayout.attack_meter_rects(vp, cfg)[&"heavy"]
		var s := HudLayout.ui_scale(vp, cfg)
		assert_bool(HudLayout.safe_area(vp, cfg).encloses(r)).override_failure_message("dodge row outside the safe area at %s" % vp).is_true()
		assert_bool(r.position.y >= heavy.end.y).override_failure_message("dodge row overlaps the RMB meter at %s" % vp).is_true()
		var need := float(cfg["dodge_label_width"]) * s + DodgePips.pips_width(4, float(cfg["dodge_pip_width"]) * s, float(cfg["dodge_pip_gap"]) * s)
		assert_bool(need <= r.size.x).override_failure_message("4 pips do not fit at %s" % vp).is_true()
		# Text stays readable: font px = meter_font_size * scale; the 1024x600 floor is about 10 px.
		assert_bool(float(cfg["meter_font_size"]) * s >= 9.5).is_true()


# ---- Boss bar stagger ----

func _boss(main: Main) -> Boss:
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -10.0)
	boss.target = main.player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	return boss


func test_boss_bar_shows_staggered_then_hands_over_to_invulnerable() -> void:
	var main := _spawn_main("rogue")
	var boss := _boss(main)
	await _frames(3)
	var bar := main.get_node("BossHpBar") as BossHpBar
	var cfg := UiConfig.boss_bar()
	assert_bool(bar.is_showing()).is_true()
	assert_int(bar.crossed_notches()).is_equal(0)
	# An attack telegraph is up when the threshold lands.
	bar._on_attack_telegraphed("x", "Some Attack", 1.0)
	assert_str(bar.attack_line_text()).is_equal("Some Attack")
	boss.health.take_damage(9999.0, "physical")
	assert_bool(boss.is_staggered()).is_true()
	assert_bool(bar.is_staggered_shown()).is_true()
	assert_str(bar.attack_line_text()).override_failure_message("the old telegraph label lingers").is_equal(String(cfg["stagger_text"]))
	assert_int(bar.crossed_notches()).override_failure_message("the notch is not marked crossed on stagger start").is_equal(1)
	assert_str(bar.info_line_text()).is_equal(String(cfg["stagger_hint_text"]))
	# A telegraph signal during the stagger must not replace the cue.
	bar._on_attack_telegraphed("x", "Late Attack", 1.0)
	assert_str(bar.attack_line_text()).is_equal(String(cfg["stagger_text"]))
	await _frames(int(ceil((BossConfig.stagger_seconds(BossConfig.boss(boss.enemy_id)) + 0.15) * 60.0)))
	assert_bool(boss.is_transitioning()).is_true()
	assert_bool(bar.is_staggered_shown()).is_false()
	assert_str(bar.info_line_text()).is_equal(String(cfg["invulnerable_text"]))
	assert_str(bar.attack_line_text()).is_empty()
	assert_int(bar.crossed_notches()).is_equal(1)


## H2: the pip row (and its key column) is hidden while the dodge switch is off, and back when it is on. No "?" ever shows.
func test_pips_hidden_with_the_switch_off_and_shown_with_it_on() -> void:
	var off := _spawn_main("rogue")
	await _idle(3)
	assert_bool(PlayerConfig.dodge_enabled()).override_failure_message("shipped data has the dodge off").is_false()
	assert_bool(off.hud.dodge_pips.visible).is_false()
	DodgeSwitch.enable()
	await _idle(3)
	assert_bool(off.hud.dodge_pips.visible).is_true()
	assert_str(InputLabels.for_action(&"dodge")).override_failure_message("the on state shows a real key, not '?'").is_not_equal("?")
	DodgeSwitch.reset()
	await _idle(3)
	assert_bool(off.hud.dodge_pips.visible).is_false()
