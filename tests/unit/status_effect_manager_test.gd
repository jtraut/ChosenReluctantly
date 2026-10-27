class_name StatusEffectManagerTest
extends GdUnitTestSuite


func _make_health(max_hp: float) -> Health:
	var health: Health = auto_free(Health.new())
	health.max_health = max_hp
	health.current_health = max_hp
	return health


func _make_manager(health: Health) -> StatusEffectManager:
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	return manager


func _burn_def() -> Dictionary:
	return {
		"effect_type": "damage_over_time",
		"damage_per_tick": 2.0,
		"damage_type": "fire",
		"tick_interval": 1.0,
	}


func test_tick_deals_damage_at_the_interval() -> void:
	var health := _make_health(50.0)
	var manager := _make_manager(health)
	manager.apply_status("burn", _burn_def(), 3.0)

	manager._process(0.5)
	assert_float(health.current_health).is_equal_approx(50.0, 0.001)

	manager._process(0.5)
	assert_float(health.current_health).is_equal_approx(48.0, 0.001)


func test_status_expires_after_its_duration() -> void:
	var health := _make_health(50.0)
	var manager := _make_manager(health)
	manager.apply_status("burn", _burn_def(), 1.5)

	manager._process(1.0)
	assert_bool(manager.has_status("burn")).is_true()
	manager._process(1.0)
	assert_bool(manager.has_status("burn")).is_false()


func test_reapplying_refreshes_duration_without_stacking() -> void:
	var health := _make_health(50.0)
	var manager := _make_manager(health)
	manager.apply_status("burn", _burn_def(), 1.0)
	manager.apply_status("burn", _burn_def(), 5.0)

	assert_int(manager.active_status_ids().size()).is_equal(1)
	manager._process(1.0)
	assert_bool(manager.has_status("burn")).is_true()
