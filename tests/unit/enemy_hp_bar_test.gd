class_name EnemyHpBarTest
extends GdUnitTestSuite


func test_fill_ratio_clamps_and_handles_zero_max() -> void:
	assert_float(EnemyHpBar.fill_ratio(10.0, 20.0)).is_equal(0.5)
	assert_float(EnemyHpBar.fill_ratio(-5.0, 20.0)).is_equal(0.0)
	assert_float(EnemyHpBar.fill_ratio(30.0, 20.0)).is_equal(1.0)
	assert_float(EnemyHpBar.fill_ratio(5.0, 0.0)).is_equal(0.0)


func test_should_show_rules() -> void:
	assert_bool(EnemyHpBar.should_show("always_alive", false, false)).is_true()
	assert_bool(EnemyHpBar.should_show("always_alive", true, true)).is_false()
	assert_bool(EnemyHpBar.should_show("after_damage", false, false)).is_false()
	assert_bool(EnemyHpBar.should_show("after_damage", false, true)).is_true()
	assert_bool(EnemyHpBar.should_show("bogus", false, false)).is_true()


func test_ghost_step_holds_then_drains_and_never_undershoots() -> void:
	assert_float(EnemyHpBar.ghost_step(1.0, 0.5, 0.2, 0.1, 1.0)).is_equal(1.0)
	assert_float(EnemyHpBar.ghost_step(1.0, 0.5, 0.0, 0.1, 1.0)).is_equal_approx(0.9, 0.0001)
	assert_float(EnemyHpBar.ghost_step(0.52, 0.5, 0.0, 0.1, 1.0)).is_equal(0.5)
	assert_float(EnemyHpBar.ghost_step(0.3, 0.5, 0.0, 0.1, 1.0)).is_equal(0.5)


func test_resistance_helpers() -> void:
	assert_float(EnemyHpBar.max_resistance({})).is_equal(0.0)
	assert_float(EnemyHpBar.max_resistance({"fire": 0.5, "water": 0.2})).is_equal(0.5)
	assert_str(EnemyHpBar.dominant_resistance({"fire": 0.2, "water": 0.4})).is_equal("water")
	assert_str(EnemyHpBar.dominant_resistance({"fire": 0.0})).is_equal("")


func test_config_merge_fills_missing_keys() -> void:
	var merged := UiConfig.merge_with_defaults(UiConfig.DEFAULT_HP_BARS, {"visibility_mode": "after_damage", "colors": {"fill": "#ffffff"}})
	assert_str(merged["visibility_mode"]).is_equal("after_damage")
	assert_str(merged["colors"]["fill"]).is_equal("#ffffff")
	assert_str(merged["colors"]["back"]).is_equal(UiConfig.DEFAULT_HP_BARS["colors"]["back"])
	assert_str(UiConfig.hp_bars()["visibility_mode"]).is_equal("always_alive")


func _spawn_dummy() -> Node3D:
	var scene: PackedScene = load("res://scenes/debug/TrainingDummy.tscn")
	var dummy: Node3D = auto_free(scene.instantiate())
	add_child(dummy)
	return dummy


func test_bar_follows_health_and_hides_on_death() -> void:
	var dummy := _spawn_dummy()
	await get_tree().process_frame
	var bar: EnemyHpBar = dummy.get_node("EnemyHpBar")
	var health: Health = dummy.get_node("Health")
	assert_bool(bar.visible).is_true()
	health.take_damage(10.0)
	assert_float(bar._fill).is_equal_approx(0.8, 0.0001)
	assert_bool(bar.is_processing()).is_true()
	health.heal(5.0)
	assert_float(bar._fill).is_equal_approx(0.9, 0.0001)
	health.take_damage(1000.0)
	assert_float(bar._fill).is_equal(0.0)
	assert_bool(bar.visible).is_false()


func test_bar_burn_pip_and_freed_enemy_is_safe() -> void:
	var dummy := _spawn_dummy()
	await get_tree().process_frame
	var health: Health = dummy.get_node("Health")
	var status: StatusEffectManager = dummy.get_node("StatusEffectManager")
	status.apply_status("burn", StatusDatabase.get_status("burn"), 3.0)
	health.take_damage(1.0)
	assert_bool(dummy.get_node("EnemyHpBar").get_instance_shader_parameter("status_flags") == Color(1.0, 0.0, 0.0, 0.0)).is_true()
	dummy.queue_free()
	await get_tree().process_frame
	assert_bool(is_instance_valid(dummy)).is_false()
