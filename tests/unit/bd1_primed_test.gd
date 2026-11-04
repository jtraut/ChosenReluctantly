class_name Bd1PrimedTest
extends GdUnitTestSuite
## BD1-A items 4 and 5: primed buffs (consume_on_cast, charges, slot_cooldown_skip), buff validation, and the
## status_damage_mult stat read by damage-over-time ticks.

const FIXTURES := "res://tests/fixtures/bd1_cards"


class StatCaster extends TestCaster:
	var stat_modifiers := StatModifiers.new()


func after_test() -> void:
	CardDatabase.load_all()
	CombatEvents.reset()


func _no_tags() -> Array[String]:
	return [] as Array[String]


# --- StatModifiers (pure) -------------------------------------------------------------------

func test_a_primed_modifier_applies_until_its_charges_run_out() -> void:
	var mods := StatModifiers.new()
	mods.add_primed_modifier("slot_cooldown_skip.attack_single", "p", StatModifiers.ADDITIVE, 1.0, "attack_single", 2, 3.0)
	assert_float(mods.apply("slot_cooldown_skip.attack_single", 0.0)).is_equal(1.0)
	assert_int(mods.consume_for_cast("attack_single", _no_tags())).is_equal(1)
	assert_float(mods.apply("slot_cooldown_skip.attack_single", 0.0)).is_equal(1.0)  # one charge left
	assert_int(mods.primed_state()[0]["charges"]).is_equal(1)
	assert_int(mods.consume_for_cast("attack_single", _no_tags())).is_equal(1)
	assert_float(mods.apply("slot_cooldown_skip.attack_single", 0.0)).is_equal(0.0)
	assert_array(mods.primed_state()).is_empty()
	assert_int(mods.consume_for_cast("attack_single", _no_tags())).is_equal(0)


func test_consume_can_be_limited_to_a_snapshot_so_a_new_buff_survives() -> void:
	var mods := StatModifiers.new()
	mods.add_primed_modifier("move_speed", "old", StatModifiers.ADDITIVE, 1.0, "utility", 1, 3.0)
	var snapshot := mods.primed_ids()
	mods.add_primed_modifier("move_speed", "new", StatModifiers.ADDITIVE, 1.0, "utility", 1, 3.0)  # applied by the cast itself
	assert_int(mods.consume_for_cast("utility", _no_tags(), snapshot)).is_equal(1)
	assert_int(mods.primed_state().size()).is_equal(1)
	assert_float(mods.apply("move_speed", 0.0)).is_equal(1.0)  # "new" is still there


func test_a_non_matching_cast_does_not_use_a_charge() -> void:
	var mods := StatModifiers.new()
	mods.add_primed_modifier("move_speed", "p", StatModifiers.MULTIPLICATIVE, 0.5, "attack_single", 1, 3.0)
	assert_int(mods.consume_for_cast("utility", ["Burn"] as Array[String])).is_equal(0)
	assert_int(mods.primed_state().size()).is_equal(1)


func test_consume_on_can_be_a_tag() -> void:
	var mods := StatModifiers.new()
	mods.add_primed_modifier("move_speed", "p", StatModifiers.MULTIPLICATIVE, 0.5, "Burn", 1, 3.0)
	assert_int(mods.consume_for_cast("attack_aoe", ["Area", "Burn"] as Array[String])).is_equal(1)
	assert_array(mods.primed_state()).is_empty()


func test_a_cooldown_skip_only_goes_to_its_own_slot() -> void:
	var mods := StatModifiers.new()
	mods.add_primed_modifier("slot_cooldown_skip.attack_single", "p", StatModifiers.ADDITIVE, 1.0, "Melee", 1, 3.0)
	# A Melee card in another slot must not eat the attack_single skip.
	assert_int(mods.consume_for_cast("attack_aoe", ["Melee"] as Array[String])).is_equal(0)
	assert_int(mods.consume_for_cast("attack_single", ["Melee"] as Array[String])).is_equal(1)


func test_a_primed_modifier_expires_by_time() -> void:
	var mods := StatModifiers.new()
	mods.add_primed_modifier("move_speed", "p", StatModifiers.ADDITIVE, 1.0, "utility", 1, 3.0)
	mods.advance(2.9)
	assert_float(float(mods.primed_state()[0]["time_left"])).is_equal_approx(0.1, 0.0001)
	assert_float(mods.apply("move_speed", 0.0)).is_equal(1.0)
	mods.advance(0.2)
	assert_array(mods.primed_state()).is_empty()
	assert_float(mods.apply("move_speed", 0.0)).is_equal(0.0)
	assert_bool(mods.has_modifier("move_speed")).is_false()


func test_the_same_id_replaces_a_primed_modifier_and_remove_clears_tracking() -> void:
	var mods := StatModifiers.new()
	mods.add_primed_modifier("move_speed", "p", StatModifiers.ADDITIVE, 1.0, "utility", 1, 3.0)
	mods.add_primed_modifier("move_speed", "p", StatModifiers.ADDITIVE, 2.0, "utility", 1, 3.0)
	assert_int(mods.primed_state().size()).is_equal(1)
	assert_float(mods.apply("move_speed", 0.0)).is_equal(2.0)
	mods.remove_modifier("move_speed", "p")
	assert_array(mods.primed_state()).is_empty()


# --- buff validation ------------------------------------------------------------------------

func _buff(extra: Dictionary) -> Array[String]:
	var params: Dictionary = {"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.2, "duration": 3.0}
	params.merge(extra, true)
	return EffectTemplates.validate_params("buff", params)


func test_buff_primed_params_validate() -> void:
	assert_array(_buff({})).is_empty()
	assert_array(_buff({"consume_on_cast": "attack_single"})).is_empty()
	assert_array(_buff({"consume_on_cast": "Dash", "charges": 2})).is_empty()
	assert_array(_buff({"consume_on_cast": "bogus"})).is_not_empty()
	assert_array(_buff({"consume_on_cast": 3})).is_not_empty()
	assert_array(_buff({"charges": 2})).is_not_empty()  # charges needs consume_on_cast
	for bad: Variant in [0, -1, 1.5, 21, "2", null]:
		assert_array(_buff({"consume_on_cast": "attack_single", "charges": bad})).is_not_empty()


func test_cooldown_skip_buff_must_be_additive_positive_and_name_a_slot() -> void:
	var good: Dictionary = {"stat": "slot_cooldown_skip.attack_single", "modifier_type": "additive", "value": 1}
	assert_array(_buff(good)).is_empty()
	assert_array(_buff({"stat": "slot_cooldown_skip.attack_single", "modifier_type": "multiplicative", "value": 1})).is_not_empty()
	assert_array(_buff({"stat": "slot_cooldown_skip.attack_single", "modifier_type": "additive", "value": 0})).is_not_empty()
	assert_array(_buff({"stat": "slot_cooldown_skip.nonsense", "modifier_type": "additive", "value": 1})).is_not_empty()


# --- through a controller --------------------------------------------------------------------

func _controller(caster: StatCaster, deck: Array[String]) -> CardSlotController:
	CardDatabase.load_all(FIXTURES)
	CombatEvents.reset()
	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", caster.stat_modifiers, owned)
	controller.set_deck(deck)
	return controller


func test_the_primed_next_cast_has_no_cooldown_and_only_that_one() -> void:
	var caster: StatCaster = auto_free(StatCaster.new())
	var controller := _controller(caster, ["bd1_prime_move", "bd1_payoff_single"] as Array[String])
	var single := controller.get_slot("attack_single")
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(single.cooldown_remaining).is_equal(1.0)  # unprimed: the slot's normal cooldown
	controller.advance(1.0)
	assert_bool(controller.try_use("movement")).is_true()
	assert_int(caster.stat_modifiers.primed_state().size()).is_equal(1)
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(single.cooldown_remaining).is_equal(CardSlot.MIN_COOLDOWN)  # primed: no cooldown
	assert_array(caster.stat_modifiers.primed_state()).is_empty()
	controller.advance(0.1)
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(single.cooldown_remaining).is_equal(1.0)  # the charge is gone


func test_the_priming_cast_does_not_use_up_its_own_charge() -> void:
	var caster: StatCaster = auto_free(StatCaster.new())
	var controller := _controller(caster, ["bd1_prime_self"] as Array[String])
	var slot := controller.get_slot("attack_aoe")
	assert_bool(controller.try_use("attack_aoe")).is_true()
	assert_float(slot.cooldown_remaining).is_equal(2.5)  # its own buff did not shorten its own cooldown
	assert_int(caster.stat_modifiers.primed_state().size()).is_equal(1)  # and was not consumed by it
	controller.advance(2.5)
	assert_bool(controller.try_use("attack_aoe")).is_true()
	assert_float(slot.cooldown_remaining).is_equal(CardSlot.MIN_COOLDOWN)  # the NEXT cast got it


func test_a_primed_buff_expires_through_the_controller_clock() -> void:
	var caster: StatCaster = auto_free(StatCaster.new())
	var controller := _controller(caster, ["bd1_prime_move", "bd1_payoff_single"] as Array[String])
	controller.try_use("movement")
	controller.advance(3.1)
	assert_array(caster.stat_modifiers.primed_state()).is_empty()
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(controller.get_slot("attack_single").cooldown_remaining).is_equal(1.0)


# --- status_damage_mult ------------------------------------------------------------------------

func _burning_target(source: Node) -> Dictionary:
	var health: Health = auto_free(Health.new())
	health.max_health = 100.0
	health.current_health = 100.0
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	manager.apply_status("burn", StatusDatabase.get_status("burn"), 10.0, source)
	return {"health": health, "manager": manager}


func test_burn_ticks_read_the_appliers_status_damage_mult() -> void:
	var caster: StatCaster = auto_free(StatCaster.new())
	var target := _burning_target(caster)
	var health: Health = target["health"]
	(target["manager"] as StatusEffectManager)._process(1.0)
	assert_float(health.current_health).is_equal_approx(98.0, 0.001)  # no stat: the data tick (2)
	caster.stat_modifiers.add_modifier("status_damage_mult.burn", "kindling", StatModifiers.MULTIPLICATIVE, 0.5)
	(target["manager"] as StatusEffectManager)._process(1.0)
	assert_float(health.current_health).is_equal_approx(95.0, 0.001)  # +50%: 3
	caster.stat_modifiers.remove_modifier("status_damage_mult.burn", "kindling")
	(target["manager"] as StatusEffectManager)._process(1.0)
	assert_float(health.current_health).is_equal_approx(93.0, 0.001)


func test_the_mult_is_per_status_and_only_for_the_applier() -> void:
	var caster: StatCaster = auto_free(StatCaster.new())
	var other: StatCaster = auto_free(StatCaster.new())
	caster.stat_modifiers.add_modifier("status_damage_mult.bleed", "m", StatModifiers.MULTIPLICATIVE, 1.0)
	var burn_target := _burning_target(caster)  # a bleed buff does not touch burn
	(burn_target["manager"] as StatusEffectManager)._process(1.0)
	assert_float((burn_target["health"] as Health).current_health).is_equal_approx(98.0, 0.001)
	other.stat_modifiers.add_modifier("status_damage_mult.burn", "m", StatModifiers.MULTIPLICATIVE, 1.0)
	var theirs := _burning_target(caster)  # applied by caster, so other's stat is irrelevant
	(theirs["manager"] as StatusEffectManager)._process(1.0)
	assert_float((theirs["health"] as Health).current_health).is_equal_approx(98.0, 0.001)


func test_a_missing_applier_or_one_without_stats_ticks_normally() -> void:
	var target := _burning_target(null)
	(target["manager"] as StatusEffectManager)._process(1.0)
	assert_float((target["health"] as Health).current_health).is_equal_approx(98.0, 0.001)
	var plain: Node3D = auto_free(Node3D.new())
	var target2 := _burning_target(plain)
	(target2["manager"] as StatusEffectManager)._process(1.0)
	assert_float((target2["health"] as Health).current_health).is_equal_approx(98.0, 0.001)
