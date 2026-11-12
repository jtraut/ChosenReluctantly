class_name Mb1UxTest
extends GdUnitTestSuite
## MB1 ux: the mini-boss bar's subtitle and its act, the chain cue on the attack line, the blink marker, the boss wedge's thick backed edge, the
## compact multi-disc telegraph, the stack-label stagger, the Open a Vein cue, the doubled-HP fix and the detonate word's clamp offset.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const DUELIST_PATH := "res://scenes/enemies/BossDuelist.tscn"
const GUARDIAN_PATH := "res://scenes/enemies/BossGuardian.tscn"
const DUELIST_ID := "boss_duelist"


func before_test() -> void:
	RunSession.clear()
	RunConfig.reset_cache()
	BossConfig.reset_cache()
	BossStagger.disable()
	Juice.hit_stop_enabled = false


func after_test() -> void:
	# A boss death plays a slow-mo beat: leave the clock and the juice state as the next suite expects them.
	Juice.hit_stop_enabled = true
	Juice.reset()
	Engine.time_scale = 1.0
	RunSession.clear()
	RunConfig.reset_cache()
	BossConfig.reset_cache()


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	return main


func _boss(main: Main, path: String) -> Boss:
	var boss: Boss = (load(path) as PackedScene).instantiate()
	boss.position = main.player.global_position + Vector3(0.0, 0.0, -8.0)
	boss.target = main.player
	boss.set_physics_process(false)
	main.add_child(boss)
	auto_free(boss)
	return boss


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


# ---- chain cue (pure) ----

func test_chain_step_numbers_both_links_of_the_shipped_combos_and_ignores_single_attacks() -> void:
	var attacks: Dictionary = BossConfig.boss(DUELIST_ID)["attacks"]
	assert_that(BossHpBar.chain_step(attacks, "leveraged_dash")).is_equal(Vector2i(1, 2))
	assert_that(BossHpBar.chain_step(attacks, "leveraged_dash_2")).is_equal(Vector2i(2, 2))
	assert_that(BossHpBar.chain_step(attacks, "golden_parachute")).is_equal(Vector2i(1, 2))
	assert_that(BossHpBar.chain_step(attacks, "backstab")).is_equal(Vector2i(2, 2))
	assert_that(BossHpBar.chain_step(attacks, "hostile_takeover")).is_equal(Vector2i.ZERO)
	assert_that(BossHpBar.chain_step(attacks, "no_such_attack")).is_equal(Vector2i.ZERO)


func test_attack_line_adds_the_step_from_the_data_format_and_leaves_plain_labels_alone() -> void:
	var attacks: Dictionary = BossConfig.boss(DUELIST_ID)["attacks"]
	var format: String = String(UiConfig.boss_bar()["chain_format"])
	assert_str(BossHpBar.attack_line(attacks, "leveraged_dash", "Leveraged dash", format)).is_equal("Leveraged dash (1/2)")
	assert_str(BossHpBar.attack_line(attacks, "leveraged_dash_2", "Leveraged dash", format)).is_equal("Leveraged dash (2/2)")
	assert_str(BossHpBar.attack_line(attacks, "hostile_takeover", "Hostile takeover", format)).is_equal("Hostile takeover")
	assert_str(BossHpBar.attack_line(attacks, "leveraged_dash", "", format)).is_empty()


func test_a_three_link_chain_counts_to_three_and_a_cycle_does_not_hang() -> void:
	var three: Dictionary = {"a": {"chain": "b"}, "b": {"chain": "c"}, "c": {}}
	assert_that(BossHpBar.chain_step(three, "a")).is_equal(Vector2i(1, 3))
	assert_that(BossHpBar.chain_step(three, "b")).is_equal(Vector2i(2, 3))
	assert_that(BossHpBar.chain_step(three, "c")).is_equal(Vector2i(3, 3))
	var cycle: Dictionary = {"a": {"chain": "b"}, "b": {"chain": "a"}}
	BossHpBar.chain_step(cycle, "a")  # the validator forbids a cycle; the bar must still return
	assert_bool(true).is_true()


# ---- subtitle and act (pure) ----

func test_the_subtitle_is_the_tier_wording_for_a_mini_boss_and_empty_for_the_final_boss() -> void:
	var tier: Dictionary = RunConfig.tier("mini_boss")
	assert_str(BossHpBar.subtitle_text(true, 1, tier)).is_equal("Act 1 Mini-boss")
	assert_str(BossHpBar.subtitle_text(true, 2, tier)).is_equal("Act 2 Mini-boss")
	assert_str(BossHpBar.subtitle_text(false, 3, tier)).is_empty()


func test_act_of_reads_what_the_arena_was_tinted_as_and_falls_back() -> void:
	var arena := Node3D.new()
	auto_free(arena)
	assert_int(ActTint.act_of(arena)).is_equal(1)
	assert_int(ActTint.act_of(arena, 3)).is_equal(3)
	assert_int(ActTint.act_of(null, 2)).is_equal(2)
	ActTint.apply(arena, 2)  # no Floor or Sun: logs, but the act is still recorded first
	assert_int(ActTint.act_of(arena)).is_equal(2)


# ---- the bar in a scene ----

func test_the_bar_says_which_act_a_mini_boss_belongs_to_and_the_block_grows_for_it() -> void:
	var main := _spawn_main()
	ActTint.apply(main, 2)
	var bar := main.get_node("BossHpBar") as BossHpBar
	var boss := _boss(main, DUELIST_PATH)
	await _frames(3)
	assert_bool(bar.is_showing()).is_true()
	assert_str(bar._subtitle_label.text).is_equal("Act 2 Mini-boss")
	assert_bool(bar._subtitle_label.visible).is_true()
	var with_subtitle: float = bar._root.size.y
	# A later change of act (the Act 2 screen opens while this bar fades out) must not rewrite it.
	ActTint.apply(main, 3)
	assert_str(bar._subtitle_label.text).is_equal("Act 2 Mini-boss")
	# The final boss has no subtitle and a shorter block.
	boss.health.take_damage(1.0e9)
	await _frames(2)
	bar._hide_now()
	var guardian := _boss(main, GUARDIAN_PATH)
	await _frames(3)
	assert_object(bar.current_boss()).is_same(guardian)
	assert_bool(bar._subtitle_label.visible).is_false()
	assert_float(bar._root.size.y).is_less(with_subtitle)
	assert_float(bar.occupied_bottom()).is_greater(0.0)


func test_a_mid_wind_up_bind_shows_the_chain_step() -> void:
	var main := _spawn_main()
	var bar := main.get_node("BossHpBar") as BossHpBar
	var boss := _boss(main, DUELIST_PATH)
	await _frames(2)
	boss._begin_windup("leveraged_dash_2")
	assert_str(bar.attack_line_text()).is_equal("Leveraged dash (2/2)")
	boss._begin_windup("hostile_takeover")
	assert_str(bar.attack_line_text()).is_equal("Hostile takeover")


func test_the_unused_mini_boss_bar_reads_its_act_when_it_binds_not_when_it_redraws() -> void:
	var world: Node = WorldRef.get_world(get_tree())
	if world == null:
		world = Node3D.new()
		add_child(world)
		auto_free(world)
		WorldRef.register(world)
	ActTint.apply(world, 1)
	var bar := MiniBossBar.new()
	add_child(bar)
	auto_free(bar)
	await get_tree().process_frame
	var enemy: Enemy = (load("res://scenes/enemies/FireResistantGolem.tscn") as PackedScene).instantiate()
	world.add_child(enemy)
	await get_tree().process_frame
	enemy.apply_tier("mini_boss", RunConfig.tier("mini_boss"))
	await get_tree().create_timer(0.5).timeout
	assert_str(bar.title_text()).is_equal("Act 1 Mini-boss")
	ActTint.apply(world, 2)  # the next act's arena loads while this bar is still up
	bar._apply_layout()
	assert_str(bar.title_text()).is_equal("Act 1 Mini-boss")
	WorldRef.unregister(world)


# ---- telegraph visuals ----

func test_a_boss_wedge_has_a_thicker_edge_and_a_dark_band_and_the_players_arc_keeps_the_thin_one() -> void:
	var boss_wedge := AttackArcVisual.new()
	add_child(boss_wedge)
	auto_free(boss_wedge)
	boss_wedge.setup(2.4, 60.0, Color.RED, AttackArcVisual.BOSS_EDGE_THICKNESS, true)
	assert_bool(boss_wedge.has_backing()).is_true()
	assert_float(boss_wedge.edge_thickness()).is_equal(AttackArcVisual.BOSS_EDGE_THICKNESS)
	assert_float(AttackArcVisual.BOSS_EDGE_THICKNESS).is_greater(AttackArcVisual.EDGE_THICKNESS * 2.0 - 0.001)
	var plain := AttackArcVisual.new()
	add_child(plain)
	auto_free(plain)
	plain.setup(2.4, 60.0, Color.RED)
	assert_bool(plain.has_backing()).is_false()
	assert_float(plain.edge_thickness()).is_equal(AttackArcVisual.EDGE_THICKNESS)
	# Nothing is drawn past the true reach: the band sits inside it (the side strips' outer corners poke out by under 4 cm, thickness squared over 2 x reach).
	var outline: ArrayMesh = AttackArcVisual.build_outline(2.4, 60.0, AttackArcVisual.BOSS_EDGE_THICKNESS * AttackArcVisual.BACKING_THICKNESS_SCALE)
	var arrays: Array = outline.surface_get_arrays(0)
	for vertex: Vector3 in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		assert_float(vertex.length()).is_less_equal(2.4 + 0.05)
	boss_wedge.show_windup(0.5)
	assert_bool(boss_wedge.visible).is_true()
	boss_wedge.hide_now()
	assert_bool(boss_wedge.visible).is_false()


func test_the_blink_marker_has_no_damage_style_fill_and_converges() -> void:
	var pool := EffectPool.new()
	add_child(pool)
	auto_free(pool)
	var radius: float = BossRules.blink_marker_radius(0.55)
	var parts: Array[PooledEffect] = TemplateVfx.blink_marker(pool, Vector3.ZERO, Vector3(0.0, 0.0, 4.0), radius, Boss.blink_color(), 0.7)
	assert_int(parts.size()).is_greater_equal(4)
	for part: PooledEffect in parts:
		var is_damage_fill: bool = part.mesh == EffectPool.disc_mesh() and is_equal_approx(part.base_size, radius)
		assert_bool(is_damage_fill).override_failure_message("the blink marker must not draw the filled aoe disc").is_false()
	# One ring starts wider than the landing ring and closes onto it as the wind-up is driven.
	var closing: PooledEffect = null
	for part: PooledEffect in parts:
		if part.scale_from > 1.5 and part.mesh == EffectPool.ring_mesh():
			closing = part
	assert_object(closing).is_not_null()
	closing.set_progress(0.0)
	var wide: float = closing.scale.x
	closing.set_progress(1.0)
	assert_float(closing.scale.x).is_less(wide)
	assert_float(closing.scale.x).is_equal_approx(radius, 0.001)
	# The blink colour is not the damage telegraph colour.
	var damage: Color = ElementVisuals.visual_for_team("physical", "enemy")["color"]
	assert_bool(Boss.blink_color().is_equal_approx(damage)).is_false()


func test_a_multi_disc_telegraph_draws_one_edge_per_disc() -> void:
	var pool := EffectPool.new()
	add_child(pool)
	auto_free(pool)
	var full: Array[PooledEffect] = TemplateVfx.aoe_telegraph(pool, Vector3.ZERO, 2.0, Color.RED, true)
	var compact: Array[PooledEffect] = TemplateVfx.aoe_telegraph(pool, Vector3.ZERO, 2.0, Color.RED, true, true)
	assert_int(compact.size()).is_equal(2)  # the fill and one edge
	assert_int(full.size()).is_greater(compact.size())


# ---- stack labels, the Open a Vein cue, the low-HP line, the detonate word ----

func test_the_upper_stack_label_rises_just_enough_to_clear_the_one_below() -> void:
	# Two texts 1.0 wide and 0.36 high, 0.1 m apart on screen: the upper one rises by the shortfall plus the pad.
	assert_float(StatusStackLabel.lift_over(0.3, 0.1, 1.0, 0.36, 0.06)).is_equal_approx(0.36 + 0.06 - 0.1, 0.0001)
	assert_float(StatusStackLabel.lift_over(0.3, 0.5, 1.0, 0.36, 0.06)).is_equal(0.0)  # already clear
	assert_float(StatusStackLabel.lift_over(1.2, 0.1, 1.0, 0.36, 0.06)).is_equal(0.0)  # side by side
	assert_float(StatusStackLabel.lift_over(0.0, -0.1, 1.0, 0.36, 0.06)).is_equal(0.0)  # the lower label never moves
	var cfg: Dictionary = UiConfig.status_stacks()
	assert_float(float(cfg["overlap_pad"])).is_greater_equal(0.0)
	assert_float(float(cfg["lift_speed"])).is_greater(0.0)


func test_a_label_text_size_grows_with_its_longest_line_and_its_line_count() -> void:
	var one: Vector2 = StatusStackLabel.text_size("Bleed x5 MAX", 40, 0.009)
	var two: Vector2 = StatusStackLabel.text_size("Bleed x5 MAX
Burn x2", 40, 0.009)
	assert_float(two.y).is_greater(one.y * 1.9)
	assert_float(two.x).is_equal_approx(one.x, 0.0001)
	assert_float(one.y).is_between(0.3, 0.6)  # about a text line high at the shipped size


func test_two_overlapping_stack_labels_separate_in_a_scene() -> void:
	var main := _spawn_main()
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = Vector3(0.0, 12.0, 12.0)
	cam.look_at(Vector3.ZERO)
	cam.make_current()
	var labels: Array[StatusStackLabel] = []
	for offset: Vector3 in [Vector3(0.0, 0.0, -0.4), Vector3(0.6, 0.0, 0.2)]:
		var host := Node3D.new()
		main.add_child(host)
		host.global_position = offset
		var manager := StatusEffectManager.new()
		host.add_child(manager)
		var label := StatusStackLabel.new()
		host.add_child(label)
		label.setup(manager)
		label.text = "Bleed x5 MAX"
		label.visible = true
		label.set_process(true)
		labels.append(label)
	await _frames(40)
	var lifts: Array[float] = [labels[0].current_lift(), labels[1].current_lift()]
	assert_float(maxf(lifts[0], lifts[1])).is_greater(0.0)
	assert_float(minf(lifts[0], lifts[1])).is_equal(0.0)  # only one rises: the one higher on screen


func test_open_a_vein_says_it_wants_stacks_and_a_plain_attack_says_nothing() -> void:
	var texts: Dictionary = RunConfig.ui().get("slot_condition", {})
	assert_str(ConditionCue.short_text(CardDatabase.get_card("rogue_open_a_vein"), texts)).is_equal("Wants Bleed stacks")
	assert_str(ConditionCue.short_text(CardDatabase.get_card("rogue_quick_slash"), texts)).is_empty()
	# Words only: the card still has no condition, so no LIVE glow and no change to the bot's plan.
	assert_bool(SlotSynergy.conditional_effects(CardDatabase.get_card("rogue_open_a_vein")).is_empty()).is_true()
	assert_str(ConditionCue.detonate_short({"effects": []}, texts)).is_empty()
	assert_str(ConditionCue.detonate_short({}, texts)).is_empty()


func test_the_low_hp_line_does_not_say_hp_twice() -> void:
	var line: String = ActText.summary_line({"line": "HP 4 of 30, 0 gold, relics: 1", "hp": 4.0, "max_hp": 30.0})
	assert_str(line).starts_with("Running low")
	assert_int(line.to_lower().count("hp")).is_equal(1)


func test_the_detonate_word_has_a_clamp_offset_and_a_damage_number_carries_it() -> void:
	assert_float(float(UiConfig.status_stacks()["detonate_word_clamp_extra"])).is_greater(0.0)
	var number := DamageNumber.new()
	auto_free(number)
	assert_float(number.clamp_extra_px).is_equal(0.0)  # an ordinary number is clamped exactly as before

