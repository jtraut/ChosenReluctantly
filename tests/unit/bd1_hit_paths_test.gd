class_name Bd1HitPathsTest
extends GdUnitTestSuite
## BD1-A items 3 (target_has_status in every hit path) and 6 (aoe anchor "caster"). Real Main scene and enemies.
## "Marked" targets carry Regeneration, a status that deals no damage, so no damage-over-time noise reaches the checks.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const MARK := {"type": "target_has_status", "status_id": "regeneration"}


func before_test() -> void:
	BodyFlag.set_collide(false)


func after_test() -> void:
	BodyFlag.reset()
	Juice.reset()
	Engine.time_scale = 1.0


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func _caster(main: Main) -> TestCaster:
	var caster := TestCaster.new()
	main.add_child(caster)
	caster.global_position = main.player.global_position + Vector3(8.0, 0.0, 0.0)
	return caster


func _enemy(main: Main, caster: Node3D, forward: float, sideways: float = 0.0) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = caster.global_position + Vector3(sideways, 0.0, -forward)
	return enemy


func _mark(enemy: Enemy) -> void:
	enemy.status_manager.apply_status("regeneration", StatusDatabase.get_status("regeneration"), 30.0)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _context(main: Main, caster: TestCaster) -> EffectContext:
	var context := EffectContext.new(caster, main, "player")
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 7
	return context


func _lost(enemy: Enemy) -> float:
	return enemy.health.get_max_health() - enemy.health.current_health


func test_cone_hits_only_targets_that_meet_the_condition_and_last_hits_is_filtered() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var marked := _enemy(main, caster, 1.5, -0.3)
	var plain := _enemy(main, caster, 1.5, 0.3)
	_mark(marked)
	await _frames(3)
	var context := _context(main, caster)
	EffectTemplates.execute("cone", {"damage": 4.0, "damage_type": "physical", "range": 3.0, "half_angle_degrees": 60.0}, context, MARK)
	assert_float(_lost(marked)).is_equal_approx(4.0, 0.001)
	assert_float(_lost(plain)).is_equal(0.0)
	assert_int(context.last_hits.size()).is_equal(1)
	# Unconditioned, the same cone hits both (the old path is untouched).
	EffectTemplates.execute("cone", {"damage": 1.0, "damage_type": "physical", "range": 3.0, "half_angle_degrees": 60.0}, _context(main, caster))
	assert_float(_lost(plain)).is_equal_approx(1.0, 0.001)


func test_aoe_hits_only_targets_that_meet_the_condition() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var marked := _enemy(main, caster, 1.0, -0.4)
	var plain := _enemy(main, caster, 1.0, 0.4)
	_mark(marked)
	await _frames(3)
	var context := _context(main, caster)
	EffectTemplates.execute("aoe", {"damage": 5.0, "damage_type": "physical", "radius": 3.0}, context, MARK)
	assert_float(_lost(marked)).is_equal_approx(5.0, 0.001)
	assert_float(_lost(plain)).is_equal(0.0)
	assert_int(context.last_hits.size()).is_equal(1)


func test_a_conditional_effect_gates_a_following_apply_status_through_last_hits() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var marked := _enemy(main, caster, 1.0, -0.4)
	var plain := _enemy(main, caster, 1.0, 0.4)
	_mark(marked)
	await _frames(3)
	var context := _context(main, caster)
	EffectTemplates.execute("aoe", {"damage": 1.0, "damage_type": "physical", "radius": 3.0}, context, MARK)
	EffectTemplates.execute("apply_status", {"status_id": "bleed", "duration": 3.0}, context)
	assert_bool(marked.status_manager.has_status("bleed")).is_true()
	assert_bool(plain.status_manager.has_status("bleed")).is_false()


func test_apply_status_itself_can_carry_a_target_condition() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var marked := _enemy(main, caster, 1.0, -0.4)
	var plain := _enemy(main, caster, 1.0, 0.4)
	_mark(marked)
	await _frames(3)
	var context := _context(main, caster)
	EffectTemplates.execute("aoe", {"damage": 1.0, "damage_type": "physical", "radius": 3.0}, context)
	EffectTemplates.execute("apply_status", {"status_id": "bleed", "duration": 3.0}, context, MARK)
	assert_bool(marked.status_manager.has_status("bleed")).is_true()
	assert_bool(plain.status_manager.has_status("bleed")).is_false()


func test_projectile_only_damages_a_target_that_meets_the_condition() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var marked := _enemy(main, caster, 4.0)
	var plain := _enemy(main, caster, 4.0, 3.0)
	_mark(marked)
	await _frames(3)
	var params: Dictionary = {"damage": 3.0, "damage_type": "physical", "speed": 20.0, "max_range": 10.0, "hit_radius": 0.4}
	EffectTemplates.execute("projectile", params, _context(main, caster), MARK)
	await get_tree().create_timer(0.6).timeout
	assert_float(_lost(marked)).is_equal_approx(3.0, 0.001)
	# A shot at an unmarked target is spent and deals nothing.
	caster.global_position += Vector3(3.0, 0.0, 0.0)
	EffectTemplates.execute("projectile", params, _context(main, caster), MARK)
	await get_tree().create_timer(0.6).timeout
	assert_float(_lost(plain)).is_equal(0.0)


func test_zone_ticks_only_hit_targets_that_meet_the_condition() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var marked := _enemy(main, caster, 3.0, -0.4)
	var plain := _enemy(main, caster, 3.0, 0.4)
	_mark(marked)
	await _frames(3)
	var context := _context(main, caster)
	context.aim_point = caster.global_position + Vector3(0.0, 0.0, -3.0)
	var params: Dictionary = {"shape": "circle", "radius": 2.0, "duration": 2.0, "tick_interval": 1.0, "damage": 2.0, "damage_type": "physical", "max_range": 6.0}
	EffectTemplates.execute("zone", params, context, MARK)  # the first tick runs at placement
	assert_float(_lost(marked)).is_equal_approx(2.0, 0.001)
	assert_float(_lost(plain)).is_equal(0.0)


func test_a_target_without_a_status_manager_never_meets_a_status_condition() -> void:
	var hurtbox: Hurtbox = auto_free(Hurtbox.new())
	assert_bool(EffectCondition.target_ok(MARK, hurtbox)).is_false()


# --- aoe anchor ---------------------------------------------------------------------------------

func test_a_delayed_aoe_anchored_to_the_caster_hits_where_the_caster_stood() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var start := caster.global_position
	var left_behind := _enemy(main, caster, 0.5)
	await _frames(3)
	var params: Dictionary = {"damage": 6.0, "damage_type": "fire", "radius": 2.0, "delay": 0.3, "anchor": "caster"}
	EffectTemplates.execute("aoe", params, _context(main, caster))
	caster.global_position = start + Vector3(30.0, 0.0, 0.0)  # blinks away before the blast lands
	await get_tree().create_timer(0.8).timeout
	assert_float(_lost(left_behind)).is_equal_approx(6.0, 0.001)


func test_a_delayed_aoe_without_anchor_follows_the_caster_as_before() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var start := caster.global_position
	var left_behind := _enemy(main, caster, 0.5)
	await _frames(3)
	EffectTemplates.execute("aoe", {"damage": 6.0, "damage_type": "fire", "radius": 2.0, "delay": 0.3}, _context(main, caster))
	caster.global_position = start + Vector3(30.0, 0.0, 0.0)
	await get_tree().create_timer(0.8).timeout
	assert_float(_lost(left_behind)).is_equal(0.0)


func test_anchor_validation() -> void:
	var base: Dictionary = {"damage": 6, "damage_type": "fire", "radius": 2.0}
	assert_array(EffectTemplates.validate_params("aoe", _merged(base, {"anchor": "caster"}))).is_empty()
	assert_array(EffectTemplates.validate_params("aoe", _merged(base, {"anchor": "caster", "delay": 0.6}))).is_empty()
	assert_array(EffectTemplates.validate_params("aoe", _merged(base, {"anchor": "aim"}))).is_not_empty()
	assert_array(EffectTemplates.validate_params("aoe", _merged(base, {"anchor": 3}))).is_not_empty()
	assert_array(EffectTemplates.validate_params("aoe", _merged(base, {"anchor": "caster", "max_range": 5.0}))).is_not_empty()


func _merged(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate()
	out.merge(b, true)
	return out
