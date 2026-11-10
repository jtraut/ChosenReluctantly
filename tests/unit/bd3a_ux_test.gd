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


# --- Card text ---

func _card_line(card_id: String) -> String:
	var ctx := RunChoices.shipped_context(["rogue", "fire", "neutral"])
	return String(RunChoices.card_option("x", "card", card_id, ctx)["detail"])


func test_paper_cuts_says_each_hit_applies_bleed() -> void:
	assert_str(_card_line("rogue_paper_cuts")).contains("each hit applies Bleed")


func test_open_a_vein_names_the_detonation() -> void:
	assert_str(_card_line("rogue_open_a_vein")).contains("Detonate Bleed: 200% of its remaining damage at once")


func test_a_single_apply_status_still_reads_plainly() -> void:
	var text: Dictionary = {"statuses": {"bleed": StatusDatabase.get_status("bleed")}}
	var card: Dictionary = {"effects": [{"template": "apply_status", "params": {"status_id": "bleed", "duration": 3.0}}]}
	assert_str(CardSummary.effect_line(card, -1.0, text)).is_equal("Bleed 2 damage/s for 3 s")


func test_every_new_rogue_card_has_text_and_tags() -> void:
	for id: String in ["rogue_open_a_vein", "rogue_paper_cuts", "rogue_bad_influence", "rogue_warm_up", "rogue_cut_corners", "rogue_knife_drawer", "rogue_excuse_me", "rogue_blood_money"]:
		assert_str(_card_line(id)).override_failure_message("%s has no effect line" % id).is_not_empty()
		assert_array(CardTags.all_tags(CardDatabase.get_card(id))).override_failure_message("%s has no tags" % id).is_not_empty()


func test_the_section_9a_names_are_back() -> void:
	assert_str(String(CardDatabase.get_card("rogue_cut_corners")["name"])).is_equal("Cutting Corners")
	assert_str(String(CardDatabase.get_card("rogue_knife_drawer")["name"])).is_equal("The Knife Drawer")


# --- The capped "In slot" list ---

func test_the_in_slot_list_is_capped_with_a_more_count() -> void:
	var fmt: String = "In slot: %s"
	var names: Array = ["A", "B", "C", "D", "E"]
	assert_str(RunOptionCard.slot_now_text("attack_single", names, fmt, 3, "+%d more")).is_equal("In slot: A / B / C +2 more")
	assert_str(RunOptionCard.slot_now_text("attack_single", ["A", "B", "C"], fmt, 3, "+%d more")).is_equal("In slot: A / B / C")
	assert_str(RunOptionCard.slot_now_text("attack_single", names, fmt)).is_equal("In slot: A / B / C / D / E")  # no cap given = old behaviour


func test_the_shipped_cap_is_set_and_a_big_pool_does_not_grow_the_line() -> void:
	var texts: Dictionary = RunConfig.ui()["option"]
	var cap: int = int(texts["slot_now_max"])
	assert_int(cap).is_greater_equal(1)
	var many: Array = []
	for i in range(40):
		many.append("Card %d" % i)
	var few: String = RunOptionCard.slot_now_text("attack_single", many.slice(0, cap + 1), String(texts["slot_now"]), cap, String(texts["slot_now_more"]))
	var lots: String = RunOptionCard.slot_now_text("attack_single", many, String(texts["slot_now"]), cap, String(texts["slot_now_more"]))
	assert_int(lots.length()).is_less_equal(few.length() + 2)
