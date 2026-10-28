class_name AttackControllerTest
extends GdUnitTestSuite
## Pure timing logic for light/heavy attacks (no scene) plus attacks.json validation.

var _fired: Array[StringName] = []
var _target_present: bool = true


func _light_def() -> Dictionary:
	return (AttackDatabase.get_attack("light") as Dictionary).duplicate()


func _heavy_def() -> Dictionary:
	return (AttackDatabase.get_attack("heavy") as Dictionary).duplicate()


func _make(light: Dictionary, heavy: Dictionary, mods: StatModifiers = null) -> AttackController:
	var modifiers := mods if mods != null else StatModifiers.new()
	var controller := AttackController.new({&"light": light, &"heavy": heavy}, modifiers)
	_fired.clear()
	controller.attack_fired.connect(func(attack_id: StringName) -> void: _fired.append(attack_id))
	return controller


func _has_target(_attack_id: StringName) -> bool:
	return _target_present


func _tick(controller: AttackController, delta: float, manual: Dictionary = {}, can_act: bool = true) -> void:
	controller.tick(delta, can_act, manual, _has_target)


func before_test() -> void:
	_target_present = true


func test_shipped_data_is_valid() -> void:
	assert_array(AttackDatabase.validate_table({
		"light": _light_def(), "heavy": _heavy_def()})).is_empty()
	assert_bool(bool(_light_def()["auto"])).is_true()
	assert_bool(bool(_heavy_def()["auto"])).is_false()


func test_light_auto_fires_on_interval_with_target() -> void:
	var controller := _make(_light_def(), _heavy_def())
	var interval := controller.get_interval(&"light")
	_tick(controller, 0.016)
	assert_array(_fired).is_equal([&"light"])
	# Not again until the interval has elapsed.
	_tick(controller, interval - 0.1)
	assert_array(_fired).has_size(1)
	_tick(controller, 0.2)
	assert_array(_fired).has_size(2)


func test_interval_resolves_through_stat_modifiers() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("attack_interval.light", "haste", StatModifiers.MULTIPLICATIVE, -0.5)
	var controller := _make(_light_def(), _heavy_def(), mods)
	assert_float(controller.get_interval(&"light")).is_equal_approx(float(_light_def()["interval"]) * 0.5, 0.0001)
	_tick(controller, 0.016)
	_fired.clear()
	_tick(controller, controller.get_interval(&"light") + 0.01)
	assert_array(_fired).has_size(1)
	# Heavy uses its own stat name.
	mods.add_modifier("attack_cooldown.heavy", "slow", StatModifiers.ADDITIVE, 1.0)
	assert_float(controller.get_interval(&"heavy")).is_equal_approx(float(_heavy_def()["interval"]) + 1.0, 0.0001)


func test_interval_is_floored() -> void:
	var mods := StatModifiers.new()
	mods.add_modifier("attack_interval.light", "silly", StatModifiers.ADDITIVE, -100.0)
	var controller := _make(_light_def(), _heavy_def(), mods)
	assert_float(controller.get_interval(&"light")).is_equal(AttackController.MIN_INTERVAL)


func test_no_auto_fire_without_target() -> void:
	_target_present = false
	var controller := _make(_light_def(), _heavy_def())
	_tick(controller, 5.0)
	assert_array(_fired).is_empty()
	# Stays ready and swings the moment a target appears.
	assert_bool(controller.is_ready(&"light")).is_true()
	_target_present = true
	_tick(controller, 0.016)
	assert_array(_fired).is_equal([&"light"])


func test_manual_click_fires_without_target_and_restarts_timer() -> void:
	_target_present = false
	var controller := _make(_light_def(), _heavy_def())
	_tick(controller, 0.016, {&"light": true})
	assert_array(_fired).is_equal([&"light"])
	assert_float(controller.get_progress(&"light")).is_less(0.1)


func test_manual_click_mid_timer_resets_auto_timer() -> void:
	var controller := _make(_light_def(), _heavy_def())
	_tick(controller, 0.016)
	_fired.clear()
	var interval := controller.get_interval(&"light")
	_tick(controller, interval * 0.7)
	_tick(controller, 0.016, {&"light": true})
	assert_array(_fired).has_size(1)
	# Without the reset the auto swing would land here (0.7 + 0.4 > 1.0).
	_tick(controller, interval * 0.4)
	assert_array(_fired).has_size(1)
	_tick(controller, interval * 0.7)
	assert_array(_fired).has_size(2)


func test_click_on_same_tick_as_auto_fires_once() -> void:
	var controller := _make(_light_def(), _heavy_def())
	# Light is ready and a target exists: auto and the click both qualify.
	_tick(controller, 0.016, {&"light": true})
	assert_array(_fired).is_equal([&"light"])


func test_manual_spam_respects_min_gap() -> void:
	_target_present = false
	var controller := _make(_light_def(), _heavy_def())
	var gap := controller.get_manual_min_gap(&"light")
	_tick(controller, 0.016, {&"light": true})
	_tick(controller, gap * 0.5, {&"light": true})
	assert_array(_fired).has_size(1)
	_tick(controller, gap * 0.6, {&"light": true})
	assert_array(_fired).has_size(2)


func test_nothing_fires_while_cannot_act() -> void:
	var controller := _make(_light_def(), _heavy_def())
	_tick(controller, 5.0, {&"light": true, &"heavy": true}, false)
	assert_array(_fired).is_empty()


func test_heavy_wind_up_then_fire_then_cooldown() -> void:
	var controller := _make(_light_def(), _heavy_def())
	_target_present = false
	var wind_up := float(_heavy_def()["wind_up"])
	_tick(controller, 0.016, {&"heavy": true})
	assert_bool(controller.is_winding_up(&"heavy")).is_true()
	assert_array(_fired).is_empty()
	_tick(controller, wind_up * 0.5)
	assert_array(_fired).is_empty()
	_tick(controller, wind_up * 0.6)
	assert_array(_fired).is_equal([&"heavy"])
	assert_bool(controller.is_winding_up(&"heavy")).is_false()
	# Cooldown respected: another click does nothing.
	_tick(controller, 0.1, {&"heavy": true})
	assert_bool(controller.is_winding_up(&"heavy")).is_false()
	assert_array(_fired).has_size(1)
	# After the full cooldown a click starts a new wind-up.
	_tick(controller, controller.get_interval(&"heavy"))
	assert_bool(controller.is_ready(&"heavy")).is_true()
	_tick(controller, 0.016, {&"heavy": true})
	assert_bool(controller.is_winding_up(&"heavy")).is_true()


func test_light_blocked_during_heavy_wind_up() -> void:
	var controller := _make(_light_def(), _heavy_def())
	_tick(controller, 0.016, {&"heavy": true})
	_fired.clear()
	_tick(controller, 0.1, {&"light": true})
	assert_array(_fired).is_empty()


func test_wind_up_cancelled_on_cannot_act() -> void:
	var controller := _make(_light_def(), _heavy_def())
	var cancelled: Array[StringName] = []
	controller.attack_cancelled.connect(func(attack_id: StringName) -> void: cancelled.append(attack_id))
	_tick(controller, 0.016, {&"heavy": true})
	assert_bool(controller.is_winding_up(&"heavy")).is_true()
	_tick(controller, 0.016, {}, false)
	assert_array(cancelled).is_equal([&"heavy"])
	_tick(controller, 2.0, {}, false)
	assert_array(_fired.filter(func(attack_id: StringName) -> bool: return attack_id == &"heavy")).is_empty()


func test_heavy_auto_flag_in_data_is_the_only_change() -> void:
	var heavy := _heavy_def()
	var controller := _make(_light_def(), heavy)
	_tick(controller, 0.016)
	assert_bool(controller.is_winding_up(&"heavy")).is_false()
	heavy["auto"] = true
	var auto_controller := _make(_light_def(), heavy)
	_tick(auto_controller, 0.016)
	assert_bool(auto_controller.is_winding_up(&"heavy")).is_true()
	_tick(auto_controller, float(heavy["wind_up"]) + 0.01)
	assert_array(_fired.filter(func(attack_id: StringName) -> bool: return attack_id == &"heavy")).has_size(1)
	# And it obeys the same target rule.
	_target_present = false
	var idle := _make(_light_def(), heavy)
	_tick(idle, 3.0)
	assert_array(_fired).is_empty()


func test_progress_reports_ready_fraction() -> void:
	var controller := _make(_light_def(), _heavy_def())
	assert_float(controller.get_progress(&"light")).is_equal(1.0)
	_tick(controller, 0.016, {&"light": true})
	_target_present = false
	_tick(controller, controller.get_interval(&"light") * 0.5)
	assert_float(controller.get_progress(&"light")).is_equal_approx(0.5, 0.05)
	assert_float(controller.get_progress(&"nonexistent")).is_equal(0.0)


func test_ready_signal_fires_when_cooldown_ends() -> void:
	var controller := _make(_light_def(), _heavy_def())
	_target_present = false
	var ready_ids: Array[StringName] = []
	controller.attack_ready.connect(func(attack_id: StringName) -> void: ready_ids.append(attack_id))
	_tick(controller, 0.016, {&"light": true})
	_tick(controller, controller.get_interval(&"light") + 0.01)
	assert_array(ready_ids).is_equal([&"light"])


func test_validation_rejects_bad_entries() -> void:
	var good := _light_def()
	var cases: Array[Dictionary] = []
	for key: String in ["auto", "stat", "interval", "damage", "range", "half_angle_degrees", "wind_up", "knockback", "color"]:
		var missing := good.duplicate()
		missing.erase(key)
		cases.append(missing)
	var bad_values: Dictionary = {
		"auto": "yes", "interval": 0.0, "damage": -1.0, "range": 0.0,
		"half_angle_degrees": 200.0, "wind_up": -0.1, "knockback": -1.0,
		"hit_stop_scale": 0.0, "color": "not a color", "stat": "", "interval_nan": 0,
	}
	for key: String in bad_values.keys():
		if key == "interval_nan":
			continue
		var bad := good.duplicate()
		bad[key] = bad_values[key]
		cases.append(bad)
	var nan_case := good.duplicate()
	nan_case["damage"] = NAN
	cases.append(nan_case)
	for entry in cases:
		assert_array(AttackDatabase.validate_entry(entry)).is_not_empty()
	assert_array(AttackDatabase.validate_entry(good)).is_empty()


func test_validation_requires_light_and_heavy() -> void:
	assert_array(AttackDatabase.validate_table({"light": _light_def()})).is_not_empty()
	assert_array(AttackDatabase.validate_table({"light": _light_def(), "heavy": "oops"})).is_not_empty()


func test_click_gap_is_interval_over_ratio() -> void:
	var controller := _make(_light_def(), _heavy_def())
	assert_float(float(_light_def()["manual_click_max_rate_ratio"])).is_equal(1.5)
	assert_float(controller.get_manual_min_gap(&"light")).is_equal_approx(0.4, 0.0001)


func test_heavy_ratio_zero_means_click_only_when_ready() -> void:
	var controller := _make(_light_def(), _heavy_def())
	assert_float(controller.get_manual_min_gap(&"heavy")).is_equal_approx(controller.get_interval(&"heavy"), 0.0001)


func _spam_count(controller: AttackController, seconds: float) -> int:
	_target_present = false
	var step := 0.01
	var elapsed := 0.0
	while elapsed < seconds:
		_tick(controller, step, {&"light": true})
		elapsed += step
	return _fired.size()


func test_spam_click_never_exceeds_ratio_times_auto_rate() -> void:
	var light := _light_def()
	var ratio := float(light["manual_click_max_rate_ratio"])
	for cut: float in [0.0, -0.5, -0.75]:
		var mods := StatModifiers.new()
		mods.add_modifier("attack_interval.light", "haste", StatModifiers.MULTIPLICATIVE, cut)
		var controller := _make(light, _heavy_def(), mods)
		var seconds := 20.0
		var clicks := _spam_count(controller, seconds)
		var auto_rate := 1.0 / controller.get_interval(&"light")
		assert_float(float(clicks) / seconds).is_less_equal(auto_rate * ratio + 0.05)
		assert_float(float(clicks) / seconds).is_greater(auto_rate * 1.2)
