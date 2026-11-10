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


# --- Relic text ---

func test_every_relic_has_a_short_rule_text_that_fits_a_tile() -> void:
	for id: String in RelicDatabase.ids():
		var rule: String = String(RelicDatabase.get_relic(id).get("rule_text", ""))
		assert_str(rule).override_failure_message("%s has no rule_text" % id).is_not_empty()
		assert_int(rule.length()).override_failure_message("%s rule_text is %d characters" % [id, rule.length()]).is_less_equal(110)


func test_spite_knuckles_text_says_bleed() -> void:
	var rule: String = String(RelicDatabase.get_relic("spite_knuckles")["rule_text"])
	assert_str(rule).contains("Bleeding")
	assert_str(rule).not_contains("Burning")


# --- Excuse Me's preview ---

func test_excuse_me_previews_its_bleed_sweep_not_just_the_lane() -> void:
	var parts: Array[Dictionary] = CastPreviewShapes.parts_for_card(CardDatabase.get_card("rogue_excuse_me"), {})
	assert_int(parts.size()).is_equal(1)
	var part: Dictionary = parts[0]
	assert_str(String(part["shape"])).is_equal(CastPreviewShapes.DASH_PATH)
	assert_bool(bool(part.get("cosmetic_width", false))).is_false()  # a real hit area, not a decorative lane
	assert_float(float(part["half_width"])).is_equal_approx(VfxSizing.dash_path_half_width(0.9), 0.0001)
	assert_float(float(part["size"])).is_equal_approx(VfxSizing.dash_path_length(4.0, 0.9), 0.0001)


func test_a_plain_dash_keeps_its_cosmetic_lane() -> void:
	var card: Dictionary = {"effects": [{"template": "dash", "params": {"distance": 3.0, "speed": 14.0}}]}
	var parts: Array[Dictionary] = CastPreviewShapes.parts_for_card(card, {})
	assert_bool(bool(parts[0].get("cosmetic_width", false))).is_true()


# --- Mini-boss bar ---

func test_the_mini_boss_title_uses_the_act_then_the_plain_name_then_a_fallback() -> void:
	assert_str(MiniBossBar.title_for({"name_format": "Act %d Mini-boss", "display_name": "Mini-boss"}, 2)).is_equal("Act 2 Mini-boss")
	assert_str(MiniBossBar.title_for({"display_name": "The Overdue Golem"}, 2)).is_equal("The Overdue Golem")
	assert_str(MiniBossBar.title_for({}, 1)).is_equal("Mini-boss")
	assert_str(MiniBossBar.title_for({"name_format": "no placeholder"}, 1)).is_equal("Mini-boss")


func test_only_a_live_mini_boss_tier_enemy_gets_the_bar() -> void:
	assert_bool(MiniBossBar.is_candidate("mini_boss", false)).is_true()
	assert_bool(MiniBossBar.is_candidate("mini_boss", true)).is_false()
	assert_bool(MiniBossBar.is_candidate("elite", false)).is_false()
	assert_bool(MiniBossBar.is_candidate("normal", false)).is_false()


func test_the_shipped_mini_boss_tier_has_a_name_and_a_marker_bigger_than_the_boss() -> void:
	var tier: Dictionary = RunConfig.tier("mini_boss")
	assert_str(MiniBossBar.title_for(tier, 1)).is_equal("Act 1 Mini-boss")
	assert_float(float(tier["marker_size"])).is_greater_equal(float(RunConfig.tier("boss")["marker_size"]))


func test_the_bar_shows_for_a_mini_boss_and_hides_when_it_dies() -> void:
	var world: Node = WorldRef.get_world(get_tree())
	if world == null:
		world = Node3D.new()
		add_child(world)
		auto_free(world)
		WorldRef.register(world)
	var bar := MiniBossBar.new()
	add_child(bar)
	auto_free(bar)
	await get_tree().process_frame
	assert_bool(bar.visible).is_false()
	assert_float(bar.occupied_bottom()).is_equal(0.0)
	var enemy: Enemy = (load("res://scenes/enemies/FireResistantGolem.tscn") as PackedScene).instantiate()
	world.add_child(enemy)
	await get_tree().process_frame
	enemy.apply_tier("mini_boss", RunConfig.tier("mini_boss"))
	await get_tree().create_timer(0.5).timeout
	assert_bool(bar.visible).is_true()
	assert_str(bar.title_text()).is_equal("Act 1 Mini-boss")
	assert_float(bar.occupied_bottom()).is_greater(0.0)
	enemy.health.take_damage(1.0e9)
	for i in range(3):  # a hit-stop makes the next frame's delta tiny, so give the bar a few frames to notice
		await get_tree().process_frame
	assert_bool(bar.visible).is_false()
	WorldRef.unregister(world)


# --- Act screen: the D45 heal and low HP ---

func test_the_heal_line_shows_the_healed_amount_and_nothing_when_zero() -> void:
	assert_str(ActText.heal_line({"healed": 9.0})).is_equal("You recover 9 HP. Rests are on the map.")
	assert_str(ActText.heal_line({"healed": 8.6})).is_equal("You recover 9 HP. Rests are on the map.")
	assert_str(ActText.heal_line({"healed": 0.0})).is_empty()  # a resumed act
	assert_str(ActText.heal_line({})).is_empty()


func test_low_hp_is_at_or_under_the_data_fraction_and_adds_a_word() -> void:
	var fraction: float = float(RunConfig.ui()["act"]["low_hp_fraction"])
	assert_bool(ActText.is_low_hp({"hp": 30.0 * fraction, "max_hp": 30.0})).is_true()
	assert_bool(ActText.is_low_hp({"hp": 30.0 * fraction + 1.0, "max_hp": 30.0})).is_false()
	assert_bool(ActText.is_low_hp({"hp": 5.0, "max_hp": 0.0})).is_false()
	assert_str(ActText.summary_line({"line": "HP 4 of 30", "hp": 4.0, "max_hp": 30.0})).is_equal("Low HP: HP 4 of 30")
	assert_str(ActText.summary_line({"line": "HP 29 of 30", "hp": 29.0, "max_hp": 30.0})).is_equal("HP 29 of 30")


func test_the_act_screen_shows_the_heal_line_only_when_something_healed_and_goes_red_when_low() -> void:
	var screen := ActScreen.new()
	add_child(screen)
	auto_free(screen)
	await get_tree().process_frame
	screen.show_act({"title": "Act 2", "line": "HP 4 of 30", "hp": 4.0, "max_hp": 30.0, "healed": 6.0})
	assert_bool(screen.heal_label.visible).is_true()
	assert_str(screen.line_label.text).starts_with("Low HP")
	assert_that(screen.line_label.get_theme_color("font_color")).is_equal(Color.html(String(RunConfig.ui()["act"]["low_hp_color"])))
	screen.show_act({"title": "Act 2", "line": "HP 29 of 30", "hp": 29.0, "max_hp": 30.0, "healed": 0.0})
	assert_bool(screen.heal_label.visible).is_false()
	assert_str(screen.line_label.text).is_equal("HP 29 of 30")
