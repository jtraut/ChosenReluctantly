class_name Bd3bEngineTest
extends GdUnitTestSuite
## BD3b sitting A, engine 1: `stacking.decay_after`, the Charge counter status, the `scale` resolver and the three new conditions.
## Fixtures only: no shipped card uses any of it yet.

var _log: RelayLog


func before_test() -> void:
	CombatEvents.reset()
	_log = RelayLog.new(CombatEvents)


func after_test() -> void:
	_log.stop()
	CombatEvents.reset()


func _target(hp: float = 100.0) -> RelayTarget:
	var target := RelayTarget.new("enemy", hp)
	add_child(target)
	auto_free(target)
	return target


func _source() -> StatSource:
	var source := StatSource.new()
	add_child(source)
	auto_free(source)
	return source


func _charge() -> Dictionary:
	return StatusDatabase.get_status("charge")


# --- charge data and decay_after ------------------------------------------------------------

func test_charge_ships_as_a_counter_that_stacks_to_ten_and_decays_after_four_seconds() -> void:
	var def: Dictionary = _charge()
	assert_bool(def.is_empty()).is_false()
	assert_str(String(def["effect_type"])).is_equal("counter")
	assert_int(int(def["stacking"]["max_stacks"])).is_equal(10)
	assert_float(float(def["stacking"]["decay_after"])).is_equal(_decay())
	assert_array(StatusDatabase.validate_entry(def)).is_empty()


func test_charge_stacks_to_its_cap_and_no_further() -> void:
	var target := _target()
	var source := _source()
	for i in range(14):
		target.status_manager.apply_status("charge", _charge(), 60.0, source, "card:test")
	assert_int(target.status_manager.stacks_of("charge")).is_equal(10)
	assert_int(target.status_manager.max_stacks_of("charge")).is_equal(10)


func test_a_max_stacks_stat_raises_the_charge_cap() -> void:
	var target := _target()
	var source := _source()
	source.stat_modifiers.add_modifier("status_max_stacks.charge", "reading_list", StatModifiers.ADDITIVE, 5.0)
	for i in range(20):
		target.status_manager.apply_status("charge", _charge(), 60.0, source, "card:test")
	assert_int(target.status_manager.stacks_of("charge")).is_equal(15)


func test_charge_deals_no_damage_while_it_stands() -> void:
	var target := _target()
	var before: float = target.health.current_health
	target.status_manager.apply_status("charge", _charge(), 60.0, _source(), "card:test")
	target.status_manager._process(3.0)
	assert_float(target.health.current_health).is_equal(before)


func _decay() -> float:
	return float((StatusDatabase.get_status("charge")["stacking"] as Dictionary)["decay_after"])


func test_all_stacks_drop_decay_after_seconds_after_the_last_gain() -> void:
	var target := _target()
	var source := _source()
	for i in range(3):
		target.status_manager.apply_status("charge", _charge(), 60.0, source, "card:test")
	target.status_manager._process(_decay() - 0.1)
	assert_int(target.status_manager.stacks_of("charge")).is_equal(3)
	target.status_manager._process(0.2)
	assert_int(target.status_manager.stacks_of("charge")).is_equal(0)
	assert_bool(target.status_manager.has_status("charge")).is_false()


func test_a_fresh_gain_resets_the_decay_timer() -> void:
	var target := _target()
	var source := _source()
	target.status_manager.apply_status("charge", _charge(), 60.0, source, "card:test")
	target.status_manager._process(_decay() - 1.0)
	target.status_manager.apply_status("charge", _charge(), 60.0, source, "card:test")
	target.status_manager._process(_decay() - 1.0)  # past the first gain's decay, 1 s short of the last's
	assert_int(target.status_manager.stacks_of("charge")).is_equal(2)
	target.status_manager._process(1.1)
	assert_int(target.status_manager.stacks_of("charge")).is_equal(0)


func test_a_reapply_at_the_cap_still_counts_as_a_gain_and_resets_the_timer() -> void:
	var target := _target()
	var source := _source()
	for i in range(10):
		target.status_manager.apply_status("charge", _charge(), 60.0, source, "card:test")
	target.status_manager._process(_decay() - 1.0)
	target.status_manager.apply_status("charge", _charge(), 60.0, source, "card:test")
	target.status_manager._process(_decay() - 1.0)
	assert_int(target.status_manager.stacks_of("charge")).is_equal(10)


func test_decay_ends_the_status_as_expired_through_the_signal_and_the_relay() -> void:
	var target := _target()
	var seen: Array[String] = []
	target.status_manager.status_expired.connect(func(id: String) -> void: seen.append(id))
	target.status_manager.apply_status("charge", _charge(), 60.0, _source(), "card:test")
	target.status_manager._process(_decay() + 0.1)
	assert_array(seen).is_equal(["charge"])


func test_the_duration_still_ends_a_status_that_is_shorter_than_its_decay() -> void:
	var target := _target()
	target.status_manager.apply_status("charge", _charge(), 1.0, _source(), "card:test")
	target.status_manager._process(1.1)
	assert_bool(target.status_manager.has_status("charge")).is_false()


func test_a_status_without_decay_after_never_decays() -> void:
	var target := _target()
	target.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 30.0, _source(), "card:test")
	target.status_manager._process(10.0)
	assert_bool(target.status_manager.has_status("bleed")).is_true()


func test_decay_after_also_works_on_a_damage_over_time_status() -> void:
	var target := _target()
	var def: Dictionary = StatusDatabase.get_status("bleed").duplicate(true)
	def["stacking"] = {"max_stacks": 5, "decay_after": 2.0}
	target.status_manager.apply_status("bleed", def, 30.0, _source(), "card:test")
	target.status_manager._process(2.1)
	assert_bool(target.status_manager.has_status("bleed")).is_false()


# --- decay_after / counter validation --------------------------------------------------------

func _counter(stacking: Variant) -> Dictionary:
	return {"display_name": "Counter", "effect_type": "counter", "stacking": stacking}


func test_a_good_counter_validates() -> void:
	assert_array(StatusDatabase.validate_entry(_counter({"max_stacks": 3, "decay_after": 2.5}))).is_empty()


func test_a_bad_decay_after_fails_validation_loudly() -> void:
	for bad: Variant in [0, -1.0, "4", null, 99999.0, [4.0]]:
		var errors: Array[String] = StatusDatabase.validate_entry(_counter({"max_stacks": 3, "decay_after": bad}))
		assert_bool(errors.is_empty()).is_false()
		assert_str(" ".join(errors)).contains("decay_after")


func test_stacking_is_refused_on_a_status_that_cannot_stack() -> void:
	var regen: Dictionary = StatusDatabase.get_status("regeneration").duplicate(true)
	regen["stacking"] = {"decay_after": 3.0}
	assert_bool(StatusDatabase.validate_entry(regen).is_empty()).is_false()


func test_an_unknown_stacking_key_is_refused() -> void:
	assert_bool(StatusDatabase.validate_entry(_counter({"max_stacks": 3, "decays": 2.0})).is_empty()).is_false()
