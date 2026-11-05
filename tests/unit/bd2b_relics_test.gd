class_name Bd2bRelicsTest
extends GdUnitTestSuite
## BD2-B: the shipped relics (data/relics) and the generic stats and the new effect they need. Each relic's rule is checked
## through the real RelicManager, the real relay and the real effect templates on a Main scene, never by reading its JSON.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const SHIPPED: Array[String] = ["heavy_sigh", "lingering_embers", "pyre_insurance", "second_wind_unwillingly", "smoldering_grudge", "spite_knuckles"]


func before_test() -> void:
	BodyFlag.set_collide(false)
	CombatEvents.reset()
	RelicDatabase.load_all()


func after_test() -> void:
	BodyFlag.reset()
	CombatEvents.reset()
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _manager(main: Main, ids: Array[String]) -> RelicManager:
	var manager := RelicManager.new()
	main.add_child(manager)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	manager.configure(main.player, main, rng, CombatEvents)
	manager.load_relics(ids)
	return manager


func _target(main: Main, hp: float = 100.0, at: Vector3 = Vector3.ZERO) -> RelayTarget:
	var target := RelayTarget.new("enemy", hp)
	main.add_child(target)
	target.global_position = at
	return target


func _burn(target: RelayTarget, origin: String = "card:x") -> void:
	target.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 30.0, null, origin)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _hit(target: RelayTarget, main: Main, origin: String, kind: StringName = Health.KIND_HIT, amount: float = 1.0, damage_type: String = "physical") -> void:
	target.hurtbox.receive_damage(amount, damage_type, Vector3.ZERO, main.player, kind, origin)


# --- the data -----------------------------------------------------------------------------------

func test_the_shipped_relics_load_clean_and_follow_the_brief() -> void:
	assert_array(RelicDatabase.problems()).is_empty()
	assert_array(RelicDatabase.ids()).is_equal(SHIPPED)
	for relic: Dictionary in RelicDatabase.all_relics():
		assert_bool(["tier1", "tier2"].has(String(relic["rarity"]))).is_true()
		assert_str(String(relic["rule_text"])).is_not_empty()
		assert_bool((relic["sources"] as Array).has("elite") and (relic["sources"] as Array).has("relic_room")).is_true()
		assert_bool(not (relic["sources"] as Array).has("boss")).is_true()


func test_the_wizard_cannot_find_the_rogue_relic_and_both_classes_see_the_rest() -> void:
	var rogue: Array[String] = CharacterDatabase.pools("rogue")
	var wizard: Array[String] = CharacterDatabase.pools("wizard")
	var weights: Dictionary = RelicConfig.tier_weights_for_act(1)
	var rng := RandomNumberGenerator.new()
	var empty: Array[String] = []
	var tiers: Array[String] = ["tier1", "tier2"]
	var rogue_all: Array[String] = RelicOffer.offer("elite", 20, rng, weights, empty, empty, rogue, RelicDatabase.all_relics(), tiers)
	var wizard_all: Array[String] = RelicOffer.offer("elite", 20, rng, weights, empty, empty, wizard, RelicDatabase.all_relics(), tiers)
	assert_int(rogue_all.size()).is_equal(6)
	assert_bool(rogue_all.has("spite_knuckles")).is_true()
	assert_int(wizard_all.size()).is_equal(5)
	assert_bool(wizard_all.has("spite_knuckles")).is_false()


# --- Pyre Insurance ------------------------------------------------------------------------------

func test_pyre_insurance_explodes_a_burn_that_expires_and_one_that_ends_with_the_owner() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["pyre_insurance"] as Array[String])
	var burning := _target(main, 100.0, Vector3(0, 0, -5))
	var neighbour := _target(main, 100.0, Vector3(1, 0, -5))
	var far := _target(main, 100.0, Vector3(9, 0, -5))
	await _frames(2)  # let the physics server learn where the targets are
	burning.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 1.0, null, "card:x")
	burning.status_manager._process(1.5)  # the burn runs out
	manager.flush()
	assert_float(neighbour.health.current_health).is_equal_approx(96.0, 0.001)  # 4 fire
	assert_float(far.health.current_health).is_equal(100.0)
	# ...and when the burning enemy dies
	var doomed := _target(main, 3.0, Vector3(0, 0, 5))
	var next_to_doomed := _target(main, 100.0, Vector3(1, 0, 5))
	await _frames(2)  # let the physics server learn where the targets are
	_burn(doomed)
	_hit(doomed, main, "light", Health.KIND_HIT, 50.0)
	manager.flush()
	assert_float(next_to_doomed.health.current_health).is_equal_approx(96.0, 0.001)


func test_pyre_insurance_also_pops_a_burn_a_relic_lit() -> void:
	# allow_relic_origin is on in the data on purpose: Spite Knuckles lights fires, Pyre Insurance pops them.
	var main := _spawn_main()
	var manager := _manager(main, ["pyre_insurance"] as Array[String])
	var lit := _target(main, 100.0, Vector3(0, 0, -5))
	var neighbour := _target(main, 100.0, Vector3(1, 0, -5))
	await _frames(2)  # let the physics server learn where the targets are
	_burn(lit, "relic:spite_knuckles")
	lit.status_manager._process(40.0)
	manager.flush()
	assert_float(neighbour.health.current_health).is_equal_approx(96.0, 0.001)


# --- Smoldering Grudge -------------------------------------------------------------------------

func test_smoldering_grudge_adds_a_quarter_to_card_hits_on_burning_enemies_only() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["smoldering_grudge"] as Array[String])
	var burning := _target(main, 1000.0, Vector3(0, 0, -5))
	var plain := _target(main, 1000.0, Vector3(3, 0, -5))
	_burn(burning)
	_hit(burning, main, "card:fire_x", Health.KIND_HIT, 10.0, "fire")
	_hit(plain, main, "card:fire_x", Health.KIND_HIT, 10.0, "fire")
	assert_float(1000.0 - burning.health.current_health).is_equal_approx(12.5, 0.001)
	assert_float(1000.0 - plain.health.current_health).is_equal_approx(10.0, 0.001)
	# a light attack, a status tick and a relic's own damage are not card hits
	var before: float = burning.health.current_health
	_hit(burning, main, "light", Health.KIND_HIT, 10.0, "fire")
	_hit(burning, main, "status:burn", Health.KIND_DOT, 10.0, "fire")
	_hit(burning, main, "relic:heavy_sigh", Health.KIND_HIT, 10.0, "fire")
	assert_float(before - burning.health.current_health).is_equal_approx(30.0, 0.001)
	# a zone tick of a card counts (origin card:*)
	before = burning.health.current_health
	_hit(burning, main, "card:fire_wall", Health.KIND_DOT, 2.0, "fire")
	assert_float(before - burning.health.current_health).is_equal_approx(2.5, 0.001)
	# giving the relic up takes it back
	manager.remove_relic("smoldering_grudge")
	before = burning.health.current_health
	_hit(burning, main, "card:fire_x", Health.KIND_HIT, 10.0, "fire")
	assert_float(before - burning.health.current_health).is_equal_approx(10.0, 0.001)


func test_the_vs_status_stat_works_for_any_status_and_without_a_source_nothing_changes() -> void:
	var main := _spawn_main()
	main.player.stat_modifiers.add_modifier("card_damage_mult_vs_status.bleed", "t", StatModifiers.MULTIPLICATIVE, 1.0)
	var bleeding := _target(main, 1000.0)
	bleeding.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 30.0, null, "card:x")
	_hit(bleeding, main, "card:x", Health.KIND_HIT, 10.0, "fire")
	assert_float(1000.0 - bleeding.health.current_health).is_equal_approx(20.0, 0.001)
	var bare := _target(main, 1000.0)
	_burn(bare)
	_hit(bare, main, "card:x", Health.KIND_HIT, 10.0, "fire")
	assert_float(1000.0 - bare.health.current_health).is_equal_approx(10.0, 0.001)
	bleeding.hurtbox.receive_damage(10.0, "fire", Vector3.ZERO, null, Health.KIND_HIT, "card:x")  # no source at all
	assert_float(1000.0 - bleeding.health.current_health).is_equal_approx(30.0, 0.001)


# --- Lingering Embers --------------------------------------------------------------------------

func _fire_wall(status_chance: float) -> Dictionary:
	return {"shape": "circle", "radius": 2.0, "duration": 4.0, "tick_interval": 1.0, "damage": 1.0, "damage_type": "fire", "max_range": 6.0,
			"status_id": "burn", "status_duration": 3.0, "status_chance": status_chance}


func _zone_context(main: Main) -> EffectContext:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var context := EffectContext.new(main.player, main, "player")
	context.rng = rng
	context.arena = main.player.get_arena_rect()
	context.aim_point = Vector3(0, 0, -4)
	return context


func test_lingering_embers_lengthens_zones_and_makes_their_status_certain() -> void:
	var main := _spawn_main()
	var context := _zone_context(main)
	var zones := ZoneManager.for_world(main)
	var victim := _target(main, 1000.0, Vector3(0, 0, -4))
	await _frames(2)
	EffectTemplates.execute("zone", _fire_wall(0.0), context)
	assert_float(float(zones.live_zones()[0]["duration"])).is_equal(4.0)
	assert_bool(victim.status_manager.has_status("burn")).is_false()  # chance 0 on the card
	zones.clear()
	_manager(main, ["lingering_embers"] as Array[String])
	EffectTemplates.execute("zone", _fire_wall(0.0), context)
	assert_float(float(zones.live_zones()[0]["duration"])).is_equal_approx(6.0, 0.0001)
	assert_bool(victim.status_manager.has_status("burn")).is_true()
	# a zone with no status gains none
	zones.clear()
	var plain: Dictionary = _fire_wall(1.0)
	plain.erase("status_id")
	plain.erase("status_duration")
	plain.erase("status_chance")
	var calm := _target(main, 1000.0, Vector3(1, 0, -4))
	await _frames(2)
	EffectTemplates.execute("zone", plain, context)
	assert_bool(calm.status_manager.has_status("burn")).is_false()


func test_zone_duration_never_passes_the_zone_cap() -> void:
	var main := _spawn_main()
	main.player.stat_modifiers.add_modifier(EffectTemplates.ZONE_DURATION_MULT_STAT, "t", StatModifiers.MULTIPLICATIVE, 9.0)
	var params: Dictionary = _fire_wall(0.0)
	params["duration"] = 20.0
	EffectTemplates.execute("zone", params, _zone_context(main))
	assert_float(float(ZoneManager.for_world(main).live_zones()[0]["duration"])).is_equal(EffectTemplates.MAX_ZONE_DURATION)


# --- Second Wind (Unwillingly) -----------------------------------------------------------------

func test_second_wind_takes_a_second_off_movement_for_a_burning_or_bleeding_kill_only() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["second_wind_unwillingly"] as Array[String])
	var movement: CardSlot = main.player.card_slots.get_slot("movement")
	movement.cooldown_remaining = 3.0
	var plain := _target(main, 1.0)
	_hit(plain, main, "light", Health.KIND_HIT, 5.0)
	manager.flush()
	assert_float(movement.cooldown_remaining).is_equal(3.0)
	var burning := _target(main, 1.0)
	_burn(burning)
	_hit(burning, main, "light", Health.KIND_HIT, 5.0)
	manager.flush()
	assert_float(movement.cooldown_remaining).is_equal_approx(2.0, 0.0001)
	var bleeding := _target(main, 1.0)
	bleeding.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 30.0, null, "card:x")
	_hit(bleeding, main, "light", Health.KIND_HIT, 5.0)
	manager.flush()
	assert_float(movement.cooldown_remaining).is_equal_approx(1.0, 0.0001)
	# never below ready, and other slots are untouched
	var other: CardSlot = main.player.card_slots.get_slot("utility")
	other.cooldown_remaining = 2.0
	for i in range(3):
		var more := _target(main, 1.0)
		_burn(more)
		_hit(more, main, "light", Health.KIND_HIT, 5.0)
		manager.flush()
	assert_float(movement.cooldown_remaining).is_equal(0.0)
	assert_float(other.cooldown_remaining).is_equal(2.0)


func test_reduce_cooldown_validates_like_any_template() -> void:
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"slot_type": "movement", "seconds": 1.0})).is_empty()
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"slot_type": "nope", "seconds": 1.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"slot_type": "movement", "seconds": 0.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"slot_type": "movement", "seconds": 1.0, "extra": 1})).is_not_empty()
	assert_bool(EffectTemplates.is_known_template("reduce_cooldown")).is_true()
	assert_array(EffectTemplates.required_params("reduce_cooldown")).is_equal(["slot_type", "seconds"])


# --- Spite Knuckles ----------------------------------------------------------------------------

func test_spite_knuckles_burns_the_target_on_every_fourth_light_hit() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["spite_knuckles"] as Array[String])
	var victim := _target(main, 1000.0)
	var other := _target(main, 1000.0, Vector3(5, 0, 5))
	for i in range(1, 9):
		_hit(victim, main, "light")
		manager.flush()
		assert_bool(victim.status_manager.has_status("burn")).override_failure_message("after light hit %d" % i).is_equal(i == 4 or i == 8)
		if i == 4:
			victim.status_manager.consume_status("burn")  # put it out, so the 8th must light it again
	assert_bool(victim.status_manager.has_status("burn")).is_true()  # the 8th lit it again
	# heavy attacks and card hits do not count toward the four
	for i in range(6):
		_hit(other, main, "heavy" if i % 2 == 0 else "card:x")
		manager.flush()
	assert_bool(other.status_manager.has_status("burn")).is_false()


func test_a_burn_spite_knuckles_lit_is_popped_by_pyre_insurance() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["spite_knuckles", "pyre_insurance"] as Array[String])
	var victim := _target(main, 1000.0, Vector3(0, 0, -5))
	var neighbour := _target(main, 1000.0, Vector3(1, 0, -5))
	await _frames(2)  # let the physics server learn where the targets are
	for i in range(4):
		_hit(victim, main, "light")
		manager.flush()
	assert_bool(victim.status_manager.has_status("burn")).is_true()
	victim.status_manager._process(10.0)
	manager.flush()
	assert_float(neighbour.health.current_health).is_equal_approx(996.0, 0.001)


# --- Heavy Sigh --------------------------------------------------------------------------------

func test_heavy_sigh_explodes_a_heavy_hit_on_a_burning_enemy_once() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["heavy_sigh"] as Array[String])
	var burning := _target(main, 1000.0, Vector3(0, 0, -5))
	var also_burning := _target(main, 1000.0, Vector3(1, 0, -5))
	var plain := _target(main, 1000.0, Vector3(0, 0, 5))
	var plain_neighbour := _target(main, 1000.0, Vector3(1, 0, 5))
	await _frames(2)  # let the physics server learn where the targets are
	_burn(burning)
	_burn(also_burning)
	# a heavy hit on an enemy that is not burning does nothing
	_hit(plain, main, "heavy")
	manager.flush()
	assert_float(plain_neighbour.health.current_health).is_equal(1000.0)
	# a light hit on a burning one does nothing
	_hit(burning, main, "light")
	manager.flush()
	assert_int(manager.fired_total()).is_equal(0)
	# a heavy swing that lands on two burning enemies explodes once (the internal cooldown)
	_hit(burning, main, "heavy")
	_hit(also_burning, main, "heavy")
	manager.flush()
	assert_int(manager.fired_total()).is_equal(1)
	assert_float(also_burning.health.current_health).is_less(1000.0 - 1.0 - 5.9)


# --- the generic stats' validation ---------------------------------------------------------------

func test_the_factor_stats_refuse_a_change_that_zeroes_them_and_the_chance_stat_must_be_additive() -> void:
	for stat: String in ["zone_duration_mult", "card_damage_mult_vs_status.burn", "status_damage_mult.burn"]:
		assert_array(EffectTemplates.validate_params("buff", {"stat": stat, "modifier_type": "multiplicative", "value": -1.0, "duration": 1.0})).is_not_empty()
		assert_array(EffectTemplates.validate_params("buff", {"stat": stat, "modifier_type": "multiplicative", "value": -0.5, "duration": 1.0})).is_empty()
	assert_array(EffectTemplates.validate_params("buff", {"stat": "zone_status_chance", "modifier_type": "multiplicative", "value": 1.0, "duration": 1.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("buff", {"stat": "zone_status_chance", "modifier_type": "additive", "value": 1.0, "duration": 1.0})).is_empty()
	assert_array(EffectTemplates.validate_params("buff", {"stat": "card_damage_mult_vs_status.nope", "modifier_type": "multiplicative", "value": 0.2, "duration": 1.0})).is_not_empty()
