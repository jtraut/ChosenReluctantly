extends GdUnitTestSuite
## qa delta review of f0cb109 (A1 readability fix): the new ui.json hud keys the boss bar layout reads.


func test_the_boss_bar_stack_keys_exist_and_are_sane_in_ui_json() -> void:
	var hud: Dictionary = UiConfig.hud()
	for key: String in ["boss_bar_gap", "boss_bar_stack_below", "boss_bar_stack_extra"]:
		assert_bool(hud.has(key)).override_failure_message("data/ui.json hud is missing %s" % key).is_true()
		var value: Variant = hud.get(key)
		assert_bool(value is float or value is int).override_failure_message("%s must be a number" % key).is_true()
		assert_float(float(value)).override_failure_message("%s must be > 0" % key).is_greater(0.0)
	# The stack threshold must be below the authored width, or the bar would stack even when it fits.
	assert_float(float(hud["boss_bar_stack_below"])).is_less(float((hud["boss_bar_size"] as Array)[0]))


func test_the_hp_bar_pip_scale_is_authored_and_valid() -> void:
	var bars: Dictionary = UiConfig.hp_bars()
	assert_array(UiConfig.validate_hp_bars(bars)).is_empty()
	assert_float(float(bars["pip_scale"])).is_greater_equal(1.0)
	var bad: Dictionary = bars.duplicate(true)
	bad.erase("pip_scale")
	assert_bool(UiConfig.validate_hp_bars(bad).any(func(p: String) -> bool: return p.contains("pip_scale"))).is_true()
