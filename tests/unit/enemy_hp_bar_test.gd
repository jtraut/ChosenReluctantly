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


# ---- QA additions ----

func _spawn_scene(path: String) -> Node3D:
	var scene: PackedScene = load(path)
	var node: Node3D = auto_free(scene.instantiate())
	add_child(node)
	return node


func test_every_enemy_scene_has_a_bar_bound_to_its_health() -> void:
	for path: String in [
		"res://scenes/enemies/MeleeChaser.tscn",
		"res://scenes/enemies/RangedShooter.tscn",
		"res://scenes/enemies/FireResistantGolem.tscn",
		"res://scenes/debug/TrainingDummy.tscn",
	]:
		var enemy := _spawn_scene(path)
		await get_tree().process_frame
		var bar: EnemyHpBar = enemy.get_node_or_null("EnemyHpBar")
		assert_object(bar).is_not_null()
		var health: Health = enemy.get_node("Health")
		assert_bool(bar.visible).is_true()
		health.take_damage(1.0)
		assert_float(bar._fill).is_equal_approx(fill_expected(health), 0.0001)


func fill_expected(health: Health) -> float:
	return health.get_current_health() / health.get_max_health()


func test_golem_has_resistance_tint_and_dummy_does_not() -> void:
	var golem := _spawn_scene("res://scenes/enemies/FireResistantGolem.tscn")
	var dummy := _spawn_scene("res://scenes/debug/TrainingDummy.tscn")
	await get_tree().process_frame
	var golem_tint: Color = (golem.get_node("EnemyHpBar") as EnemyHpBar).get_instance_shader_parameter("resist_tint")
	var dummy_tint: Color = (dummy.get_node("EnemyHpBar") as EnemyHpBar).get_instance_shader_parameter("resist_tint")
	assert_float(golem_tint.a).is_equal(1.0)
	assert_float(dummy_tint.a).is_equal(0.0)


func test_fill_ratio_extremes() -> void:
	assert_float(EnemyHpBar.fill_ratio(1.0e30, 1.0)).is_equal(1.0)
	assert_float(EnemyHpBar.fill_ratio(5.0, -3.0)).is_equal(0.0)
	assert_float(EnemyHpBar.fill_ratio(NAN, 10.0)).is_equal(0.0)
	assert_float(EnemyHpBar.fill_ratio(0.0, 0.0)).is_equal(0.0)


func test_overheal_clamps_and_heal_snaps_ghost_up() -> void:
	var dummy := _spawn_dummy()
	await get_tree().process_frame
	var bar: EnemyHpBar = dummy.get_node("EnemyHpBar")
	var health: Health = dummy.get_node("Health")
	health.take_damage(10.0)
	assert_float(bar._ghost).is_equal(1.0)
	health.heal(1000.0)
	assert_float(bar._fill).is_equal(1.0)
	assert_float(bar._ghost).is_equal(1.0)
	assert_bool(bar.is_processing()).is_false()
	# Heal that does not reach the ghost must not restart the delay or lose state.
	health.take_damage(10.0)
	health.heal(2.0)
	assert_float(bar._fill).is_equal_approx(0.84, 0.0001)
	assert_float(bar._ghost).is_greater_equal(bar._fill)


func test_ghost_drains_then_stops_processing() -> void:
	var dummy := _spawn_dummy()
	await get_tree().process_frame
	var bar: EnemyHpBar = dummy.get_node("EnemyHpBar")
	var health: Health = dummy.get_node("Health")
	health.take_damage(10.0)
	assert_bool(bar.is_processing()).is_true()
	bar._process(10.0)
	bar._process(10.0)
	assert_float(bar._ghost).is_equal(bar._fill)
	assert_bool(bar.is_processing()).is_false()


func test_burn_tick_updates_bar() -> void:
	var dummy := _spawn_dummy()
	await get_tree().process_frame
	var bar: EnemyHpBar = dummy.get_node("EnemyHpBar")
	var status: StatusEffectManager = dummy.get_node("StatusEffectManager")
	status.apply_status("burn", {"damage_per_tick": 5.0, "damage_type": "fire", "tick_interval": 1.0}, 3.0)
	status._process(1.0)
	assert_float(bar._fill).is_less(1.0)
	assert_bool(bar.get_instance_shader_parameter("status_flags") == Color(1.0, 0.0, 0.0, 0.0)).is_true()
	status._process(5.0)
	assert_bool(bar.get_instance_shader_parameter("status_flags") == Color(0.0, 0.0, 0.0, 0.0)).is_true()


func test_after_damage_mode_hidden_until_first_damage() -> void:
	await get_tree().process_frame
	var original: Variant = EnemyHpBar._shared_config.get("visibility_mode")
	EnemyHpBar._shared_config["visibility_mode"] = "after_damage"
	var dummy := _spawn_dummy()
	await get_tree().process_frame
	var bar: EnemyHpBar = dummy.get_node("EnemyHpBar")
	var health: Health = dummy.get_node("Health")
	var was_visible_before: bool = bar.visible
	health.take_damage(1.0)
	var visible_after: bool = bar.visible
	health.take_damage(1000.0)
	var visible_dead: bool = bar.visible
	EnemyHpBar._shared_config["visibility_mode"] = original
	assert_bool(was_visible_before).is_false()
	assert_bool(visible_after).is_true()
	assert_bool(visible_dead).is_false()


func test_spawn_and_free_same_frame_is_safe() -> void:
	var scene: PackedScene = load("res://scenes/enemies/MeleeChaser.tscn")
	var enemy: Node3D = scene.instantiate()
	add_child(enemy)
	enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(enemy)).is_false()


func test_free_while_ghost_draining_is_safe() -> void:
	var scene: PackedScene = load("res://scenes/enemies/MeleeChaser.tscn")
	var enemy: Node3D = scene.instantiate()
	add_child(enemy)
	await get_tree().process_frame
	var health: Health = enemy.get_node("Health")
	var bar: EnemyHpBar = enemy.get_node("EnemyHpBar")
	health.take_damage(1.0)
	assert_bool(bar.is_processing()).is_true()
	enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(enemy)).is_false()


func test_bar_without_health_sibling_does_not_error() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	var bar: EnemyHpBar = load("res://scenes/ui/EnemyHpBar.tscn").instantiate()
	holder.add_child(bar)
	add_child(holder)
	await get_tree().process_frame
	assert_bool(is_instance_valid(bar)).is_true()
