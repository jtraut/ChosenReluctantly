class_name H3UxTest
extends GdUnitTestSuite
## H3 (ux-designer): the Fan of regrets lane look (dim to bright across the wind-up, capped length) and the one-pip dodge row.


func test_volley_lane_ramps_up_and_is_capped() -> void:
	assert_float(VfxConfig.marker("boss_volley_lane_alpha_end")).is_greater(VfxConfig.marker("boss_volley_lane_alpha_start"))
	assert_float(VfxConfig.marker("boss_volley_lane_alpha_start")).is_greater(0.0)
	var root := Node3D.new()
	add_child(root)
	var pool: EffectPool = EffectPool.for_world(root)
	var lane: PooledEffect = TemplateVfx.enemy_shot_lane(pool, Vector3.ZERO, Vector3.FORWARD, 16.0, 0.35, Color.WHITE, 0.75, true, true)
	assert_object(lane).is_not_null()
	assert_float(lane.alpha_from).is_equal(VfxConfig.marker("boss_volley_lane_alpha_start"))
	assert_float(lane.alpha_to).is_equal(VfxConfig.marker("boss_volley_lane_alpha_end"))
	assert_float(lane.strip_length).is_less_equal(VfxConfig.marker("boss_volley_lane_max_length"))
	# A normal enemy shot is unchanged: it starts at its lane alpha and fades, at full length.
	var plain: PooledEffect = TemplateVfx.enemy_shot_lane(pool, Vector3.ZERO, Vector3.FORWARD, 10.0, 0.35, Color.WHITE, 0.5, false)
	assert_float(plain.alpha_to).is_equal(0.0)
	assert_float(plain.strip_length).is_greater(10.0)


func test_single_pip_ready_vs_recharging() -> void:
	assert_float(DodgePips.pip_fill(0, 1, 1, false, 1.0)).is_equal(1.0)
	assert_float(DodgePips.pip_fill(0, 0, 1, true, 0.4)).is_equal(0.4)
	var cfg: Dictionary = UiConfig.hud()
	assert_str(DodgePips.status_word(1, 1, cfg)).is_equal("")
	assert_str(DodgePips.status_word(0, 1, cfg)).is_not_equal("")
