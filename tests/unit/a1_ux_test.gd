class_name A1UxTest
extends GdUnitTestSuite
## A1 Part 2 (ux): armor readability. The boss bar's deferred bind (the freed-boss error), the boss and elite bar
## cues, the armor and resisted damage-number styles, the "never 0" display rule, and the F3 defense lines.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func before_test() -> void:
	Juice.hit_stop_enabled = false
	Juice.reset()


func after_test() -> void:
	Juice.hit_stop_enabled = true
	Juice.reset()
	Engine.time_scale = 1.0


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


# ---- Boss bar: the deferred bind ----

func test_a_stale_or_freed_boss_id_never_binds() -> void:
	var main := _spawn_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	bar._try_bind_id(0)  # not an instance id at all
	bar._try_bind_id(-5)
	assert_object(bar.current_boss()).is_null()
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	main.add_child(boss)
	var id: int = boss.get_instance_id()
	boss.free()
	bar._try_bind_id(id)  # freed: the id no longer resolves
	assert_object(bar.current_boss()).is_null()
	assert_bool(bar.is_showing()).is_false()


func test_a_boss_added_and_freed_in_the_same_frame_leaves_the_bar_unbound() -> void:
	# The bug: node_added deferred the Node itself; a boss freed before the flush failed the typed argument
	# conversion ("Cannot convert argument 1 from Object to Object"). The id path must survive it.
	var main := _spawn_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	main.add_child(boss)
	boss.free()
	await _frames(2)
	assert_object(bar.current_boss()).is_null()
	assert_bool(bar.is_showing()).is_false()
	# And a real boss after that still binds.
	var real: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	real.target = main.player
	main.add_child(real)
	await _frames(3)
	assert_object(bar.current_boss()).is_same(real)


# ---- Boss bar: armor next to resistance ----

func test_defense_text_puts_armor_before_resistance_in_the_same_line() -> void:
	var cfg := UiConfig.boss_bar()
	var all_fifty: Dictionary = {"fire": 0.5, "water": 0.5}
	assert_str(BossHpBar.defense_text(0.5, all_fifty, cfg)).is_equal("Armor 50%  ·  Resists all elements 50%")
	assert_str(BossHpBar.defense_text(0.0, all_fifty, cfg)).is_equal("Resists all elements 50%")
	assert_str(BossHpBar.defense_text(0.25, {}, cfg)).is_equal("Armor 25%")
	assert_str(BossHpBar.defense_text(0.0, {}, cfg)).is_empty()
	assert_float(BossHpBar.armor_tint(0.0, cfg).a).is_equal(0.0)
	assert_float(BossHpBar.armor_tint(0.5, cfg).a).is_equal(1.0)


func test_the_boss_bar_shows_armor_text_and_a_shield_pip_and_the_line_fits() -> void:
	var main := _spawn_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.target = main.player
	main.add_child(boss)
	await _frames(3)
	assert_str(bar._resist_label.text).is_equal("Armor 50%  ·  Resists all elements 50%")
	assert_float(bar._meter.armor_tint.a).is_equal(1.0)
	# The longest wording ("some elements") must still fit its label at the smallest font, at every size.
	var cfg := UiConfig.boss_bar()
	var longest: String = BossHpBar.defense_text(0.5, {"fire": 0.5, "water": 0.1}, cfg, ["fire", "water"] as Array[String])
	for vp: Vector2 in [Vector2(1024, 600), Vector2(1024, 768), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		var s: float = HudLayout.ui_scale(vp, UiConfig.hud())
		var bar_w: float = HudLayout.boss_bar_rect(vp, UiConfig.hud()).size.x
		var share: float = 1.0 if HudLayout.boss_bar_stacked(vp, UiConfig.hud()) else (1.0 - float(cfg["phase_width_fraction"]))
		var width: float = bar_w * share - (40.0 if share == 1.0 else 20.0) * s
		var size: int = roundi(float(cfg["info_min_font_size"]) * s)
		var text_w: float = bar._resist_label.get_theme_font("font").get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		assert_float(text_w).is_less(width)
	# The shipped line at the normal size fits without shrinking at the reference size.
	var normal_w: float = bar._resist_label.get_theme_font("font").get_string_size("Armor 50%  ·  Resists all elements 50%", HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(cfg["info_font_size"])).x
	assert_float(normal_w).is_less(560.0 * (1.0 - float(cfg["phase_width_fraction"])) - 20.0)


func test_the_shield_polygon_is_convex_and_distinct_from_the_diamond() -> void:
	var shield := BossMeter.shield_polygon(Vector2(10.0, 10.0), 8.0)
	assert_int(shield.size()).is_equal(5)  # a diamond has 4 points
	assert_int(Geometry2D.triangulate_polygon(shield).size()).is_equal(9)  # 3 triangles: a valid simple polygon


# ---- Elite bar ----

func test_an_elite_bar_gets_the_shield_and_a_normal_enemy_does_not() -> void:
	assert_bool(EnemyHpBar.shows_armor(0.0)).is_false()
	assert_bool(EnemyHpBar.shows_armor(0.25)).is_true()
	var main := _spawn_main()
	var normal: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(normal)
	var elite: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(elite)
	await _frames(2)
	elite.apply_tier("elite", RunConfig.tier("elite"))
	await _frames(2)
	var normal_bar := normal.get_node("EnemyHpBar") as EnemyHpBar
	var elite_bar := elite.get_node("EnemyHpBar") as EnemyHpBar
	assert_bool(normal_bar._armor_shown).is_false()
	assert_bool(elite_bar._armor_shown).is_true()  # the instance uniform itself is not readable in a headless run


func test_the_hp_bar_config_requires_a_hex_armor_tint() -> void:
	var block: Dictionary = UiConfig.hp_bars().duplicate(true)
	assert_array(UiConfig.validate_hp_bars(block)).is_empty()
	block["armor_tint"] = "nope"
	assert_array(UiConfig.validate_hp_bars(block)).is_not_empty()


# ---- Damage numbers ----

func test_display_amount_never_shows_zero_for_a_real_hit() -> void:
	assert_str(DamageNumber.display_amount(12.4)).is_equal("12")
	assert_str(DamageNumber.display_amount(1.0)).is_equal("1")
	assert_str(DamageNumber.display_amount(0.5)).is_equal("0.5")
	assert_str(DamageNumber.display_amount(0.3)).is_equal("0.3")
	assert_str(DamageNumber.display_amount(0.04)).is_equal("0.1")  # floor: a real hit is never "0.0"
	assert_str(DamageNumber.display_amount(0.97)).is_equal("1")  # would round to "1.0"
	assert_str(DamageNumber.display_amount(0.0)).is_equal("0")  # not a hit
	# A merged DoT: ticks of 0.5 fold into whole numbers as they add up.
	var number: DamageNumber = auto_free(DamageNumber.new())
	add_child(number)
	number.configure(UiConfig.damage_numbers())
	number.show_amount(0.5, "physical", Color.WHITE, false)
	assert_str(number.text).is_equal("0.5")
	number.merge_hit(0.5, false)
	assert_str(number.text).is_equal("1")


func test_style_follows_channel_and_the_data_threshold() -> void:
	var cfg := UiConfig.damage_numbers()
	assert_array(UiConfig.validate_damage_numbers(cfg)).is_empty()
	var threshold: float = float(cfg["armor_min_reduction"])
	assert_str(String(DamageNumber.style_for(Health.CHANNEL_ARMOR, 0.25, cfg))).is_equal("armor")
	assert_str(String(DamageNumber.style_for(Health.CHANNEL_ARMOR, threshold, cfg))).is_equal("armor")
	assert_str(String(DamageNumber.style_for(Health.CHANNEL_ARMOR, threshold - 0.01, cfg))).is_empty()  # barely noticeable: plain
	assert_str(String(DamageNumber.style_for(Health.CHANNEL_RESISTANCE, 0.5, cfg))).is_equal("resist")
	assert_str(String(DamageNumber.style_for(Health.CHANNEL_RESISTANCE, 0.02, cfg))).is_empty()
	assert_str(String(DamageNumber.style_for(Health.CHANNEL_NONE, 0.9, cfg))).is_empty()


func test_armor_and_resisted_numbers_differ_by_shape_not_only_colour() -> void:
	var cfg := UiConfig.damage_numbers()
	var armor: Dictionary = DamageNumber.brackets_for(DamageNumber.STYLE_ARMOR, cfg)
	var resist: Dictionary = DamageNumber.brackets_for(DamageNumber.STYLE_RESIST, cfg)
	assert_bool(armor != resist).is_true()
	assert_str(String(armor["open"])).is_not_empty()
	assert_str(String(resist["open"])).is_not_empty()
	assert_str(String(DamageNumber.brackets_for(DamageNumber.STYLE_NONE, cfg)["open"])).is_empty()
	# Muted: not the plain type colour.
	assert_bool(DamageNumber.styled_color(DamageNumber.STYLE_ARMOR, "physical", cfg).is_equal_approx(DamageNumber.color_for("physical", float(cfg["color_lighten"])))).is_false()
	assert_bool(DamageNumber.styled_color(DamageNumber.STYLE_RESIST, "fire", cfg).is_equal_approx(DamageNumber.color_for("fire", float(cfg["color_lighten"])))).is_false()
	assert_bool(DamageNumber.styled_color(DamageNumber.STYLE_NONE, "fire", cfg).is_equal_approx(DamageNumber.color_for("fire", float(cfg["color_lighten"])))).is_true()


func test_a_styled_number_shows_its_brackets_and_is_smaller() -> void:
	var cfg := UiConfig.damage_numbers()
	var number: DamageNumber = auto_free(DamageNumber.new())
	add_child(number)
	number.configure(cfg)
	number.show_amount(9.0, "physical", Color.WHITE, false, "", DamageNumber.STYLE_ARMOR, DamageNumber.brackets_for(DamageNumber.STYLE_ARMOR, cfg))
	assert_str(number.text).is_equal("[9]")
	assert_float(number.scale.x).is_less(1.0)
	number.merge_hit(3.0, false)
	assert_str(number.text).is_equal("[12]")
	var resisted: DamageNumber = auto_free(DamageNumber.new())
	add_child(resisted)
	resisted.configure(cfg)
	resisted.show_amount(5.0, "fire", Color.WHITE, false, "", DamageNumber.STYLE_RESIST, DamageNumber.brackets_for(DamageNumber.STYLE_RESIST, cfg))
	assert_str(resisted.text).is_equal("<5>")


func test_the_validator_rejects_bad_style_data() -> void:
	var bad: Dictionary = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad["armor_open"] = ""
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()
	bad = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad["armor_min_reduction"] = 1.5
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()
	bad = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad["armor_min_reduction"] = 0.0
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()
	bad = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad["armor_color"] = "nope"
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()


func test_an_armored_hit_does_not_merge_into_a_plain_number() -> void:
	var main := _spawn_main()
	var spot := Vector3(3.0, 0.0, 3.0)
	Juice.spawn_damage_number(spot, 8.0, "physical")
	Juice.spawn_damage_number(spot, 6.0, "physical", null, "", Health.CHANNEL_ARMOR, 0.25)
	assert_int(Juice._live_numbers.size()).is_equal(2)
	# A second armored hit does merge into the armored one.
	Juice.spawn_damage_number(spot, 3.0, "physical", null, "", Health.CHANNEL_ARMOR, 0.25)
	assert_int(Juice._live_numbers.size()).is_equal(2)
	var texts: Array[String] = []
	for live: DamageNumber in Juice._live_numbers:
		texts.append(live.text)
	assert_array(texts).contains_exactly_in_any_order(["8", "[9]"])
	assert_object(main).is_not_null()


func test_a_real_armored_hit_on_an_elite_reaches_the_number_with_the_channel() -> void:
	var main := _spawn_main()
	var elite: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(elite)
	await _frames(2)
	elite.apply_tier("elite", RunConfig.tier("elite"))
	elite.health.take_damage(20.0, "physical")
	assert_float(elite.health.last_reduction).is_greater(0.2)
	var found: bool = false
	for live: DamageNumber in Juice._live_numbers:
		if live.style == DamageNumber.STYLE_ARMOR:
			found = true
	assert_bool(found).is_true()


# ---- F3 overlay ----

func test_pick_target_prefers_the_cursor_then_the_nearest() -> void:
	var positions: Array[Vector3] = [Vector3(0, 0, -2), Vector3(6, 0, 0), Vector3(6, 0, 1)]
	var under: Dictionary = DebugOverlay.pick_target(Vector3(6.2, 0, 0.9), Vector3.ZERO, positions, 1.6)
	assert_int(int(under["index"])).is_equal(2)
	assert_str(String(under["mode"])).is_equal("cursor")
	var far: Dictionary = DebugOverlay.pick_target(Vector3(-9, 0, 9), Vector3.ZERO, positions, 1.6)
	assert_int(int(far["index"])).is_equal(0)  # nothing near the cursor: the nearest to the player
	assert_str(String(far["mode"])).is_equal("nearest")
	var none_aim: Dictionary = DebugOverlay.pick_target(null, Vector3.ZERO, positions, 1.6)
	assert_int(int(none_aim["index"])).is_equal(0)
	assert_int(int(DebugOverlay.pick_target(null, Vector3.ZERO, [] as Array[Vector3], 1.6)["index"])).is_equal(-1)


func test_the_defense_lines_name_armor_and_resistance() -> void:
	var both: Array[String] = ["fire", "water"]
	assert_str(DebugOverlay.resist_summary({"fire": 0.5, "water": 0.5}, both)).is_equal("Resist: all elements 50%")
	assert_str(DebugOverlay.resist_summary({"fire": 0.5, "water": 0.1}, both)).is_equal("Resist: fire 50%, water 10%")
	assert_str(DebugOverlay.resist_summary({"fire": 0.5}, both)).is_equal("Resist: fire 50%")  # N1: a fire-only table is not "all" once water exists
	assert_str(DebugOverlay.resist_summary({"fire": 0.0}, both)).is_equal("Resist: none")
	assert_str(DebugOverlay.target_line("cursor", "boss_guardian", "boss", 50.0, 0.5, {"fire": 0.5})).is_equal("Under cursor: boss_guardian (boss)  Armor 50 (50%)  Resist: all elements 50%")
	assert_str(DebugOverlay.target_line("nearest", "melee_chaser", "", 0.0, 0.0, {})).is_equal("Nearest: melee_chaser  Armor 0 (0%)  Resist: none")
	assert_str(DebugOverlay.player_line(0.0, 0.0)).is_equal("Player: Armor 0 (0%)")
