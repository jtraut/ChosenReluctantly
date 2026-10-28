class_name HealthSignalsTest
extends GdUnitTestSuite


func _make_health(max_hp: float) -> Health:
	var health: Health = auto_free(Health.new())
	health.max_health = max_hp
	health.current_health = max_hp
	return health


func test_health_changed_fires_on_damage_heal_and_max_change() -> void:
	var health := _make_health(20.0)
	var log: Array[float] = []
	health.health_changed.connect(func(cur: float, _mx: float) -> void: log.append(cur))
	health.take_damage(5.0)
	health.heal(2.0)
	health.set_max_health(10.0)
	assert_array(log).is_equal([15.0, 17.0, 10.0])
	assert_float(health.get_max_health()).is_equal(10.0)
	assert_float(health.get_current_health()).is_equal(10.0)


func test_burn_tick_emits_health_changed_and_status_signals() -> void:
	var health := _make_health(20.0)
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	var changes: Array[float] = []
	var events: Array[String] = []
	health.health_changed.connect(func(cur: float, _mx: float) -> void: changes.append(cur))
	manager.status_applied.connect(func(id: String) -> void: events.append("on:" + id))
	manager.status_expired.connect(func(id: String) -> void: events.append("off:" + id))
	manager.apply_status("burn", {"damage_per_tick": 2.0, "damage_type": "fire", "tick_interval": 1.0}, 1.0)
	manager._process(1.0)
	assert_array(changes).is_equal([18.0])
	assert_array(events).is_equal(["on:burn", "off:burn"])


func test_get_resistance_is_capped() -> void:
	var health := _make_health(20.0)
	health.resistances = {"fire": 0.9}
	assert_float(health.get_resistance("fire")).is_equal(0.5)
	assert_float(health.get_resistance("water")).is_equal(0.0)
