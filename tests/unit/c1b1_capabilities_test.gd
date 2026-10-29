class_name C1b1CapabilitiesTest
extends GdUnitTestSuite
## C1-b1: apply_status chance, multi-hit (hits / hit_interval), Bleed, Regeneration, lifesteal
## (the damage_dealt event) and the feel rules for DoT ticks and follow-up hits.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func before_test() -> void:
	BodyFlag.set_collide(false)  # these tests park enemies on the player; solid bodies have c1c_solid_enemies_test


func after_test() -> void:
	BodyFlag.reset()
	Juice.reset()
	Engine.time_scale = 1.0


# --- helpers ------------------------------------------------------------------------------

func _health(max_hp: float, resistances: Dictionary = {}) -> Health:
	var health: Health = auto_free(Health.new())
	health.max_health = max_hp
	health.current_health = max_hp
	health.resistances = resistances
	return health


func _manager(health: Health) -> StatusEffectManager:
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	return manager


func _status(status_id: String) -> Dictionary:
	return StatusDatabase.get_status(status_id)


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


## A target-less (stationary) enemy `forward` metres ahead of the caster (-Z).
func _enemy(main: Main, caster: Node3D, forward: float) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = caster.global_position + Vector3(0.0, 0.0, -forward)
	return enemy


func _caster(main: Main) -> TestCaster:
	var caster := TestCaster.new()
	main.add_child(caster)
	caster.global_position = main.player.global_position + Vector3(8.0, 0.0, 0.0)
	return caster


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _cone_params(extra: Dictionary = {}) -> Dictionary:
	var params: Dictionary = {"damage": 2.0, "damage_type": "physical", "range": 3.0, "half_angle_degrees": 60.0}
	params.merge(extra, true)
	return params


func _context(main: Main, caster: TestCaster) -> EffectContext:
	var context := EffectContext.new(caster, main, "player")
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 7
	return context


func _kinds(caster: TestCaster) -> Array:
	var kinds: Array = []
	for entry: Array in caster.dealt:
		kinds.append(entry[1])
	return kinds


# --- shipped statuses --------------------------------------------------------------------

func test_new_statuses_are_valid_data() -> void:
	for status_id: String in ["bleed", "regeneration", "leech"]:
		assert_bool(StatusDatabase.has_status(status_id)).override_failure_message(status_id).is_true()
	assert_str(String(_status("bleed")["damage_type"])).is_equal("physical")
	assert_str(String(_status("regeneration")["effect_type"])).is_equal("heal_over_time")
	assert_str(String(_status("leech")["effect_type"])).is_equal("lifesteal")


func test_status_validation_fails_loud_on_bad_new_fields() -> void:
	var bad_regen := {"display_name": "R", "effect_type": "heal_over_time", "heal_per_tick": 0.0, "tick_interval": 1.0}
	assert_array(StatusDatabase.validate_entry(bad_regen)).is_not_empty()
	var bad_leech := {"display_name": "L", "effect_type": "lifesteal", "fraction": 1.5, "max_heal_per_hit": 2.0}
	assert_array(StatusDatabase.validate_entry(bad_leech)).is_not_empty()
	var missing_cap := {"display_name": "L", "effect_type": "lifesteal", "fraction": 0.3}
	assert_array(StatusDatabase.validate_entry(missing_cap)).is_not_empty()
	var good := {"display_name": "L", "effect_type": "lifesteal", "fraction": 0.3, "max_heal_per_hit": 2.0}
	assert_array(StatusDatabase.validate_entry(good)).is_empty()


# --- Bleed ---------------------------------------------------------------------------------

func test_bleed_ignores_elemental_resistance_and_resistance_cap() -> void:
	var target := _health(50.0, {"fire": 0.5, "physical": 0.5})
	var manager := _manager(target)
	manager.apply_status("bleed", _status("bleed"), 3.0)
	manager._process(float(_status("bleed")["tick_interval"]))
	assert_float(target.current_health).is_equal_approx(50.0 - float(_status("bleed")["damage_per_tick"]), 0.001)


func test_bleed_refreshes_instead_of_stacking_and_keeps_tick_phase() -> void:
	var target := _health(50.0)
	var manager := _manager(target)
	var tick: float = float(_status("bleed")["tick_interval"])
	manager.apply_status("bleed", _status("bleed"), 1.0)
	manager._process(tick * 0.6)
	manager.apply_status("bleed", _status("bleed"), 2.0)
	assert_int(manager.active_status_ids().size()).is_equal(1)
	manager._process(tick * 0.5)  # the phase kept from the first application: one tick lands now
	assert_float(target.current_health).is_equal_approx(50.0 - float(_status("bleed")["damage_per_tick"]), 0.001)


# --- Regeneration --------------------------------------------------------------------------

func test_regeneration_heals_per_tick_and_stops_at_full_and_when_dead() -> void:
	var health := _health(10.0)
	health.current_health = 5.0
	var manager := _manager(health)
	var def := _status("regeneration")
	manager.apply_status("regeneration", def, 10.0)
	manager._process(float(def["tick_interval"]))
	assert_float(health.current_health).is_equal_approx(5.0 + float(def["heal_per_tick"]), 0.001)
	var heals: Array[float] = []
	health.healed.connect(func(amount: float) -> void: heals.append(amount))
	health.current_health = 10.0
	manager._process(float(def["tick_interval"]))
	assert_array(heals).is_empty()  # full health: no heal event, no popup
	health.take_damage(50.0)
	manager._process(float(def["tick_interval"]))
	assert_bool(health.is_dead()).is_true()
	assert_array(heals).is_empty()


# --- lifesteal and the damage_dealt event -------------------------------------------------

func test_lifesteal_returns_a_fraction_capped_per_hit() -> void:
	var caster: TestCaster = auto_free(TestCaster.new())
	caster.health.current_health = 10.0
	var def := _status("leech")
	caster.status_manager.apply_status("leech", def, 5.0)
	var target := _health(100.0)
	target.take_damage(4.0, "physical", Vector3.ZERO, caster)
	assert_float(caster.health.current_health).is_equal_approx(10.0 + 4.0 * float(def["fraction"]), 0.001)
	var before: float = caster.health.current_health
	target.take_damage(50.0, "physical", Vector3.ZERO, caster)
	assert_float(caster.health.current_health - before).is_equal_approx(float(def["max_heal_per_hit"]), 0.001)


func test_lifesteal_counts_hp_actually_removed_not_overkill() -> void:
	var caster: TestCaster = auto_free(TestCaster.new())
	caster.health.current_health = 10.0
	caster.status_manager.apply_status("leech", _status("leech"), 5.0)
	var target := _health(100.0)
	target.current_health = 2.0
	target.take_damage(50.0, "physical", Vector3.ZERO, caster)
	assert_float(float(caster.dealt[0][0])).is_equal_approx(2.0, 0.001)
	assert_float(caster.health.current_health).is_equal_approx(10.0 + 2.0 * float(_status("leech")["fraction"]), 0.001)


func test_lifesteal_uses_resisted_damage() -> void:
	var caster: TestCaster = auto_free(TestCaster.new())
	var target := _health(100.0, {"fire": 0.5})
	target.take_damage(10.0, "fire", Vector3.ZERO, caster)
	assert_float(float(caster.dealt[0][0])).is_equal_approx(5.0, 0.001)


func test_dot_ticks_are_credited_to_the_applier_and_feed_lifesteal() -> void:
	var caster: TestCaster = auto_free(TestCaster.new())
	caster.health.current_health = 10.0
	caster.status_manager.apply_status("leech", _status("leech"), 5.0)
	var target := _health(50.0)
	var manager := _manager(target)
	manager.apply_status("bleed", _status("bleed"), 3.0, caster)
	manager._process(float(_status("bleed")["tick_interval"]))
	assert_int(caster.dealt.size()).is_equal(1)
	assert_array(_kinds(caster)).is_equal([Health.KIND_DOT])
	assert_float(caster.health.current_health).is_greater(10.0)


func test_a_freed_applier_does_not_break_the_tick() -> void:
	var caster := TestCaster.new()
	var target := _health(50.0)
	var manager := _manager(target)
	manager.apply_status("bleed", _status("bleed"), 3.0, caster)
	caster.free()
	manager._process(float(_status("bleed")["tick_interval"]))
	assert_float(target.current_health).is_less(50.0)


func test_lifesteal_ends_when_the_status_expires() -> void:
	var caster: TestCaster = auto_free(TestCaster.new())
	caster.health.current_health = 10.0
	caster.status_manager.apply_status("leech", _status("leech"), 1.0)
	caster.status_manager._process(1.5)
	var target := _health(50.0)
	target.take_damage(5.0, "physical", Vector3.ZERO, caster)
	assert_float(caster.health.current_health).is_equal_approx(10.0, 0.001)


func test_a_source_without_the_signal_is_ignored() -> void:
	var other: Node = auto_free(Node.new())
	var target := _health(50.0)
	target.take_damage(5.0, "physical", Vector3.ZERO, other)
	assert_float(target.current_health).is_equal_approx(45.0, 0.001)


func test_lifesteal_at_full_hp_emits_no_heal_event() -> void:
	var caster: TestCaster = auto_free(TestCaster.new())
	caster.status_manager.apply_status("leech", _status("leech"), 5.0)
	var heals: Array[float] = []
	caster.health.healed.connect(func(amount: float) -> void: heals.append(amount))
	_health(50.0).take_damage(5.0, "physical", Vector3.ZERO, caster)
	assert_array(heals).is_empty()


func test_real_player_is_wired_for_status_rolls_and_lifesteal() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player: Player = main.player
	assert_object(player.card_slots.status_rng).is_same(player.status_rng)
	player.camera = null
	player.rotation = Vector3.ZERO
	player.health.current_health = 10.0
	player.status_manager.apply_status("leech", _status("leech"), 10.0)
	var dealt: Array[float] = []
	player.damage_dealt.connect(func(_t: Node, amount: float, _ty: String, _k: StringName) -> void: dealt.append(amount))
	var enemy := _enemy(main, player, 1.2)
	await _frames(8)
	assert_array(dealt).is_not_empty()  # the basic attack reports through damage_dealt
	assert_float(enemy.health.current_health).is_less(enemy.health.get_max_health())
	assert_float(player.health.current_health).is_greater(10.0)


# --- chance on apply_status ---------------------------------------------------------------

func _targets(count: int) -> Array[Hurtbox]:
	var list: Array[Hurtbox] = []
	for i in range(count):
		var health := _health(20.0)
		var hurtbox: Hurtbox = auto_free(Hurtbox.new())
		hurtbox.health = health
		hurtbox.status_manager = _manager(health)
		list.append(hurtbox)
	return list


func _landed(targets: Array[Hurtbox]) -> Array:
	var result: Array = []
	for hurtbox: Hurtbox in targets:
		result.append(hurtbox.status_manager.has_status("bleed"))
	return result


func _apply_bleed(targets: Array[Hurtbox], chance: Variant, rng: RandomNumberGenerator) -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var context := EffectContext.new(caster, caster)
	context.rng = rng
	context.last_hits = targets
	var params: Dictionary = {"status_id": "bleed", "duration": 2.0}
	if chance != null:
		params["chance"] = chance
	EffectTemplates.execute("apply_status", params, context)


func test_chance_zero_never_and_one_always_and_neither_draws_from_the_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var state_before: int = rng.state
	var none := _targets(5)
	_apply_bleed(none, 0.0, rng)
	assert_array(_landed(none)).is_equal([false, false, false, false, false])
	var all := _targets(5)
	_apply_bleed(all, 1.0, rng)
	var omitted := _targets(5)
	_apply_bleed(omitted, null, rng)
	assert_array(_landed(all)).is_equal([true, true, true, true, true])
	assert_array(_landed(omitted)).is_equal([true, true, true, true, true])
	assert_int(rng.state).is_equal(state_before)


func test_partial_chance_is_repeatable_with_the_same_seed() -> void:
	var outcomes: Array = []
	for run in range(2):
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var targets := _targets(40)
		_apply_bleed(targets, 0.5, rng)
		outcomes.append(_landed(targets))
	assert_array(outcomes[1]).is_equal(outcomes[0])
	var landed: int = (outcomes[0] as Array).count(true)
	assert_int(landed).is_between(5, 35)  # neither all nor none: it really rolls


# --- multi-hit -----------------------------------------------------------------------------

func test_default_cone_is_one_hit() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _enemy(main, caster, 1.5)
	await _frames(3)
	EffectTemplates.execute("cone", _cone_params(), _context(main, caster))
	await get_tree().create_timer(0.4).timeout
	assert_array(_kinds(caster)).is_equal([Health.KIND_HIT])
	assert_float(enemy.health.current_health).is_equal_approx(enemy.health.get_max_health() - 2.0, 0.001)


func test_multi_hit_cone_hits_each_interval_first_is_a_hit_the_rest_echoes() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _enemy(main, caster, 1.5)
	await _frames(3)
	EffectTemplates.execute("cone", _cone_params({"hits": 3, "hit_interval": 0.1}), _context(main, caster))
	assert_int(caster.dealt.size()).is_equal(1)
	await get_tree().create_timer(0.6).timeout
	assert_array(_kinds(caster)).is_equal([Health.KIND_HIT, Health.KIND_ECHO, Health.KIND_ECHO])
	assert_float(enemy.health.current_health).is_equal_approx(enemy.health.get_max_health() - 6.0, 0.001)


func test_multi_hit_aoe_repeats() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _enemy(main, caster, 1.5)
	await _frames(3)
	EffectTemplates.execute("aoe", {"damage": 1.0, "damage_type": "physical", "radius": 3.0, "hits": 2, "hit_interval": 0.1}, _context(main, caster))
	await get_tree().create_timer(0.5).timeout
	assert_float(enemy.health.current_health).is_equal_approx(enemy.health.get_max_health() - 2.0, 0.001)


func test_multi_hit_projectile_fires_that_many_shots() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _enemy(main, caster, 4.0)
	await _frames(3)
	var params: Dictionary = {"damage": 1.0, "damage_type": "physical", "speed": 20.0, "max_range": 10.0, "hit_radius": 0.4, "hits": 3, "hit_interval": 0.1}
	EffectTemplates.execute("projectile", params, _context(main, caster))
	await get_tree().create_timer(1.0).timeout
	assert_float(enemy.health.current_health).is_equal_approx(enemy.health.get_max_health() - 3.0, 0.001)
	assert_array(_kinds(caster)).is_equal([Health.KIND_HIT, Health.KIND_ECHO, Health.KIND_ECHO])


func test_follow_up_hits_stop_when_the_caster_is_freed() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _enemy(main, caster, 1.5)
	await _frames(3)
	EffectTemplates.execute("cone", _cone_params({"hits": 3, "hit_interval": 0.15}), _context(main, caster))
	caster.queue_free()
	await get_tree().create_timer(0.6).timeout
	assert_float(enemy.health.current_health).is_equal_approx(enemy.health.get_max_health() - 2.0, 0.001)


func test_follow_up_hits_stop_when_the_caster_dies() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _enemy(main, caster, 1.5)
	await _frames(3)
	EffectTemplates.execute("cone", _cone_params({"hits": 3, "hit_interval": 0.15}), _context(main, caster))
	caster.health.take_damage(1000.0)
	await get_tree().create_timer(0.6).timeout
	assert_float(enemy.health.current_health).is_equal_approx(enemy.health.get_max_health() - 2.0, 0.001)


func test_status_with_the_same_timing_rolls_once_per_hit() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _enemy(main, caster, 1.5)
	await _frames(3)
	var context := _context(main, caster)
	var timing: Dictionary = {"hits": 3, "hit_interval": 0.1}
	EffectTemplates.execute("cone", _cone_params(timing), context)
	var status_params: Dictionary = {"status_id": "bleed", "duration": 2.0, "chance": 0.5}
	status_params.merge(timing)
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	probe.seed = 7
	# Replay the expected draws: one roll per hit (the enemy is hit every time).
	var expected_states: Array[int] = []
	for i in range(3):
		probe.randf()
		expected_states.append(probe.state)
	EffectTemplates.execute("apply_status", status_params, context)
	await get_tree().create_timer(0.5).timeout
	assert_int(context.rng.state).is_equal(expected_states[2])
	assert_float(enemy.health.current_health).is_less(enemy.health.get_max_health())


# --- schema --------------------------------------------------------------------------------

func _card_with(template: String, params: Dictionary) -> Dictionary:
	return {"id": "t", "name": "T", "flavor_text": "", "slot_type": "utility", "pool": "neutral", "cooldown_modifier": 0.0,
			"effects": [{"template": template, "params": params}]}


func test_schema_accepts_valid_new_fields_and_rejects_bad_ones() -> void:
	var ok := _cone_params({"hits": 3, "hit_interval": 0.2})
	assert_array(CardSchema.validate(_card_with("cone", ok))).is_empty()
	var cases: Array[Array] = [
		["cone", _cone_params({"hits": 0, "hit_interval": 0.2})],
		["cone", _cone_params({"hits": 2.5, "hit_interval": 0.2})],
		["cone", _cone_params({"hits": 21, "hit_interval": 0.2})],
		["cone", _cone_params({"hits": "3", "hit_interval": 0.2})],
		["cone", _cone_params({"hits": 3})],
		["cone", _cone_params({"hits": 3, "hit_interval": 0.0})],
		["cone", _cone_params({"hits": 3, "hit_interval": -1.0})],
		["cone", _cone_params({"hits": 3, "hit_interval": 99.0})],
		["cone", _cone_params({"chance": 0.5})],
		["heal", {"amount": 1.0, "hits": 2, "hit_interval": 0.1}],
		["apply_status", {"status_id": "bleed", "duration": 2.0, "chance": 1.5}],
		["apply_status", {"status_id": "bleed", "duration": 2.0, "chance": -0.1}],
		["apply_status", {"status_id": "bleed", "duration": 2.0, "chance": "half"}],
		["apply_status", {"status_id": "no_such_status", "duration": 2.0}],
		["apply_status", {"status_id": "bleed", "duration": 2.0, "target": "everyone"}],
	]
	for case: Array in cases:
		var problems := CardSchema.validate(_card_with(String(case[0]), case[1]))
		assert_array(problems).override_failure_message("should be rejected: %s" % str(case)).is_not_empty()
	var good_status := {"status_id": "bleed", "duration": 2.0, "chance": 0.25, "hits": 2, "hit_interval": 0.3, "target": "last_hits"}
	assert_array(CardSchema.validate(_card_with("apply_status", good_status))).is_empty()


# --- feel ----------------------------------------------------------------------------------

func test_dot_ticks_and_echo_hits_never_hit_stop_but_a_direct_hit_does() -> void:
	Juice.hit_stop_enabled = true
	Juice.on_hit_landed(Vector3.ZERO, 1.0, "physical", Health.KIND_DOT)
	assert_float(Engine.time_scale).is_equal(1.0)
	Juice.on_hit_landed(Vector3.ZERO, 1.0, "physical", Health.KIND_ECHO)
	assert_float(Engine.time_scale).is_equal(1.0)
	Juice.on_hit_landed(Vector3.ZERO, 1.0, "physical", Health.KIND_HIT)
	assert_float(Engine.time_scale).is_less(1.0)


# --- damage rule ---------------------------------------------------------------------------

func test_card_damage_rule_multiplies_by_hits_and_weights_dot_by_chance() -> void:
	var statuses: Dictionary = {"bleed": _status("bleed")}
	var card: Dictionary = {"slot_type": "attack_single", "effects": [
		{"template": "cone", "params": _cone_params({"damage": 2.0, "hits": 3, "hit_interval": 0.1})},
		{"template": "apply_status", "params": {"status_id": "bleed", "duration": 2.0, "chance": 0.5}},
	]}
	var bleed: Dictionary = statuses["bleed"]
	var ticks: float = floorf(2.0 / float(bleed["tick_interval"]) + 0.000001) * float(bleed["damage_per_tick"])
	assert_float(CardDamageRule.cast_damage(card, statuses, 5.0)).is_equal_approx(6.0 + ticks * 0.5, 0.001)
