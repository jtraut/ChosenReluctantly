class_name Bd3aUxTest
extends GdUnitTestSuite
## BD3a ux: stack counts over enemies, the detonate cue, and (further down) the new cards' text, the capped "In slot" list
## and the mini-boss / act screen carry-overs.


func after_test() -> void:
	Juice.reset()


# --- Stack counts ---

func test_a_count_reads_name_and_stacks_and_marks_the_cap() -> void:
	var cfg: Dictionary = UiConfig.status_stacks()
	assert_str(StatusStackLabel.line_text("Bleed", 3, 5, cfg)).is_equal("Bleed x3")
	assert_str(StatusStackLabel.line_text("Bleed", 5, 5, cfg)).is_equal("Bleed x5 MAX")


func test_a_status_that_does_not_stack_shows_no_count() -> void:
	var cfg: Dictionary = UiConfig.status_stacks()
	assert_bool(StatusStackLabel.shows(1, cfg)).is_false()
	assert_bool(StatusStackLabel.shows(2, cfg)).is_true()
	assert_str(StatusStackLabel.compose([{"id": "burn", "name": "Burn", "stacks": 1, "max": 1}], cfg)).is_equal("")


func test_two_stacking_statuses_each_get_a_line_in_a_fixed_order() -> void:
	var cfg: Dictionary = UiConfig.status_stacks()
	var text: String = StatusStackLabel.compose([
		{"id": "bleed", "name": "Bleed", "stacks": 3, "max": 5},
		{"id": "burn", "name": "Burn", "stacks": 2, "max": 3},
		{"id": "stun", "name": "Stun", "stacks": 1, "max": 1},
	], cfg)
	assert_str(text).is_equal("Bleed x3\nBurn x2")


func test_the_detonate_word_uses_the_status_name() -> void:
	assert_str(StatusStackLabel.detonate_word("Bleed", UiConfig.status_stacks())).is_equal("Bleed burst")


func test_shipped_status_stack_config_is_valid() -> void:
	assert_array(UiConfig.validate_status_stacks(UiConfig.status_stacks())).is_empty()
	var broken: Dictionary = UiConfig.DEFAULT_STATUS_STACKS.duplicate()
	broken["count_format"] = "no placeholder"
	assert_array(UiConfig.validate_status_stacks(broken)).is_not_empty()


# --- Detonate number ---

func test_an_emphasized_number_is_larger_and_marked_and_a_later_merge_keeps_it() -> void:
	var number := DamageNumber.new()
	number.configure(UiConfig.damage_numbers())
	number.show_amount(12.0, "physical", Color.WHITE, true)
	var normal_scale: float = number.scale.x
	number.emphasize(1.9, "!")
	assert_bool(number.is_emphasized()).is_true()
	assert_float(number.scale.x).is_greater(normal_scale)
	assert_str(number.text).is_equal("12!")
	number.merge_hit(3.0, true)
	assert_str(number.text).is_equal("15!")
	assert_float(number.scale.x).is_equal_approx(1.9, 0.001)
	number.free()
