class_name Map4uxTest
extends GdUnitTestSuite
## MAP4 ux: the coloured event lines (EventEngine.line_parts, RunOptionCard.event_line_bbcode), the "?" icon, the "Fight time" label.

func before_test() -> void:
	EventDatabase.load_all()
	CardDatabase.load_all()
	RelicDatabase.load_all()
	RunConfig.reset_cache()


func _state() -> RunState:
	var state: RunState = RunState.new_run(11, ["x"] as Array[String], 3)
	state.max_hp = 30.0
	state.hp = 30.0
	return state


func _joined(parts: Dictionary) -> String:
	var text: String = ""
	for segment: Dictionary in (parts["segments"] as Array[Dictionary]):
		text += String(segment["text"])
	return text


# --- the parts match the text ----------------------------------------------------------------------

func test_the_parts_of_every_shipped_choice_read_exactly_like_its_lines() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var state: RunState = _state()
	var header: String = String(RunConfig.ui()["event"]["after_fight_header"])
	for event_id: String in EventDatabase.ids():
		for choice: Variant in (EventDatabase.get_event(event_id)["choices"] as Array):
			var outcomes: Array = (choice as Dictionary)["outcomes"]
			var lines: Array[String] = EventEngine.lines_for(outcomes, state, ctx)
			var parts: Array[Dictionary] = EventEngine.line_parts(outcomes, state, ctx)
			assert_int(parts.size()).override_failure_message("%s: line count" % event_id).is_equal(lines.size())
			for i in range(lines.size()):
				var prefix: String = (header + " ") if bool(parts[i]["conditional"]) else ""
				assert_str(prefix + _joined(parts[i])).override_failure_message("%s line %d" % [event_id, i]).is_equal(lines[i])


func test_a_fight_marks_the_lines_after_it_as_conditional_and_is_a_risk() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var outcomes: Array = [{"type": "start_fight", "tier": "elite"}, {"type": "gain_gold", "amount": 40}, {"type": "lose_hp", "fraction": 0.2}]
	var parts: Array[Dictionary] = EventEngine.line_parts(outcomes, _state(), ctx)
	assert_array([parts[0]["kind"], parts[1]["kind"], parts[2]["kind"]]).is_equal(["risk", "gain", "cost"])
	assert_array([parts[0]["conditional"], parts[1]["conditional"], parts[2]["conditional"]]).is_equal([false, true, true])


func test_the_kind_comes_from_the_outcome_not_the_words() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var kinds: Dictionary = {
		"lose_hp": "cost", "lose_max_hp": "cost", "lose_gold": "cost", "gain_curse": "cost", "sacrifice_relic": "cost",
		"heal": "gain", "gain_gold": "gain", "gain_relic": "gain", "remove_curse": "gain", "remove_card": "gain", "merchant_discount": "gain",
		"start_fight": "risk"}
	for type_id: String in kinds:
		assert_str(EventEngine.outcome_kind({"type": type_id}, ctx)).override_failure_message(type_id).is_equal(String(kinds[type_id]))


func test_a_stat_mod_is_a_gain_when_it_moves_the_stat_the_good_way() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var faster: Dictionary = {"type": "stat_mod", "stat": "slot_cooldown.recovery", "modifier_type": "multiplicative", "value": -0.2}
	var slower: Dictionary = {"type": "stat_mod", "stat": "slot_cooldown.recovery", "modifier_type": "multiplicative", "value": 0.2}
	var quicker: Dictionary = {"type": "stat_mod", "stat": "move_speed", "modifier_type": "multiplicative", "value": 0.05}
	var weaker: Dictionary = {"type": "stat_mod", "stat": "damage_mult", "modifier_type": "multiplicative", "value": -0.1}
	assert_str(EventEngine.outcome_kind(faster, ctx)).is_equal("gain")
	assert_str(EventEngine.outcome_kind(slower, ctx)).is_equal("cost")
	assert_str(EventEngine.outcome_kind(quicker, ctx)).is_equal("gain")
	assert_str(EventEngine.outcome_kind(weaker, ctx)).is_equal("cost")


func test_a_chance_line_keeps_its_percentage_and_colours_each_branch() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var chance: Dictionary = {"type": "chance", "p": 0.4, "win": [{"type": "gain_gold", "amount": 30}], "lose": [{"type": "lose_hp", "fraction": 0.1}]}
	var parts: Array[Dictionary] = EventEngine.line_parts([chance], _state(), ctx)
	assert_int(parts.size()).is_equal(1)
	var segments: Array[Dictionary] = parts[0]["segments"]
	assert_str(String(segments[0]["text"])).is_equal("40%: ")
	assert_str(String(segments[0]["kind"])).is_equal("chance")
	var kinds: Array[String] = []
	for segment: Dictionary in segments:
		kinds.append(String(segment["kind"]))
	assert_bool(kinds.has("gain") and kinds.has("cost")).is_true()


func test_a_choice_with_no_outcomes_is_one_neutral_leave_line() -> void:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var parts: Array[Dictionary] = EventEngine.line_parts([], _state(), ctx)
	assert_int(parts.size()).is_equal(1)
	assert_str(String(parts[0]["kind"])).is_equal("neutral")


# --- drawing ---------------------------------------------------------------------------------------

func test_the_line_text_has_a_glyph_for_its_kind_so_colour_is_never_the_only_cue() -> void:
	var cfg: Dictionary = UiConfig.run_ui()
	var glyphs: Dictionary = RunConfig.ui()["event"]["glyphs"]
	var cost: String = RunOptionCard.event_line_bbcode({"kind": "cost", "segments": [{"text": "Lose 6 HP", "kind": "cost"}]}, glyphs, cfg, Color.WHITE, true)
	var gain: String = RunOptionCard.event_line_bbcode({"kind": "gain", "segments": [{"text": "Gain 4 gold", "kind": "gain"}]}, glyphs, cfg, Color.WHITE, true)
	assert_str(cost).contains("[b]-[/b]").contains(String(cfg["event_cost_color"]).trim_prefix("#"))
	assert_str(gain).contains("[b]+[/b]").contains(String(cfg["event_gain_color"]).trim_prefix("#"))
	assert_str(cost).is_not_equal(gain)


func test_a_greyed_line_loses_its_colours_but_keeps_its_words_and_glyph() -> void:
	var cfg: Dictionary = UiConfig.run_ui()
	var glyphs: Dictionary = RunConfig.ui()["event"]["glyphs"]
	var text: String = RunOptionCard.event_line_bbcode({"kind": "gain", "segments": [{"text": "Gain 4 gold", "kind": "gain"}]}, glyphs, cfg, Color.WHITE, false)
	assert_str(text).contains("Gain 4 gold").contains("[b]+[/b]")
	assert_str(text).not_contains(String(cfg["event_gain_color"]).trim_prefix("#"))


func test_a_bracket_in_event_text_cannot_open_a_tag() -> void:
	var text: String = RunOptionCard.event_line_bbcode({"kind": "neutral", "segments": [{"text": "[b]x", "kind": "neutral"}]}, {}, UiConfig.run_ui(), Color.WHITE, true)
	assert_str(text).contains("[lb]b]x")


func test_the_end_of_run_and_room_cleared_time_rows_say_fight_time() -> void:
	var ui: Dictionary = RunConfig.ui()
	assert_str(String(ui["room_cleared"]["stat_time"])).is_equal("Fight time")
	assert_str(String(ui["win"]["stat_time"])).is_equal("Fight time")


func test_the_event_node_is_a_bubble_with_its_own_shape() -> void:
	assert_str(RunIcons.shape_for("event")).is_equal(RunIcons.SHAPE_BUBBLE)
	for type_id: String in ["combat", "elite", "rest", "boss", "relic_room", "merchant", "mini_boss"]:
		assert_str(RunIcons.shape_for(type_id)).is_not_equal(RunIcons.SHAPE_BUBBLE)
	var pts: PackedVector2Array = RunIcons.polygon(RunIcons.SHAPE_BUBBLE, 10.0)
	assert_int(pts.size()).is_greater_equal(16)
	for p: Vector2 in pts:
		assert_float(p.length()).is_less_equal(10.0 * 1.4)


# --- curses ----------------------------------------------------------------------------------------

func _removal_model(left: int, curses: int) -> Dictionary:
	return {"cleanses_left": left, "curse_count": curses, "options": [{"kind": "remove", "card_id": "x"}]}


func test_the_cleanse_counter_shows_only_when_a_cap_applies_and_a_curse_is_held() -> void:
	assert_str(RunPromptScreen.with_cleanses("Pick.", _removal_model(-1, 2))).is_equal("Pick.")  # no limit: hidden
	assert_str(RunPromptScreen.with_cleanses("Pick.", _removal_model(2, 0))).is_equal("Pick.")  # no curse held: nothing to count
	assert_str(RunPromptScreen.with_cleanses("Pick.", _removal_model(2, 1))).contains("2")
	assert_str(RunPromptScreen.with_cleanses("Pick.", _removal_model(0, 1))).contains("0")
	var not_a_list: Dictionary = {"cleanses_left": 2, "curse_count": 1, "options": [{"kind": "heal"}, {"kind": "remove", "card_id": ""}]}
	assert_str(RunPromptScreen.with_cleanses("Rest.", not_a_list)).is_equal("Rest.")


func test_a_curse_chip_is_its_own_chip_with_the_data_word() -> void:
	var word: String = String(UiConfig.hud()["curse_chip_text"])
	assert_str(word).is_not_empty()
	var parts: Dictionary = ChipRow.texts_for([word])
	assert_array(parts["texts"]).is_equal([word])
	assert_array(parts["curse"]).is_equal([true])
	assert_array(parts["flags"]).is_equal([false])  # not a keyword
	assert_array(ChipRow.texts_for(["Burn"])["curse"]).is_equal([false])


func test_a_curse_option_gets_a_band_the_curse_frame_and_a_line_even_with_no_effect() -> void:
	var cfg: Dictionary = UiConfig.run_ui()
	var texts: Dictionary = RunConfig.ui()["option"]
	var card := RunOptionCard.new()
	add_child(card)
	card.setup({"id": "remove:c", "kind": "remove", "card_id": "curse_property_damage", "label": "Property Damage", "detail": "", "curse": true, "enabled": true},
			RunOptionCard.Look.CELL, 214.0, cfg, 1.0, {"texts": texts})
	assert_object(card.curse_band).is_not_null()
	assert_object(card.detail_label).is_not_null()
	assert_str(card.detail_label.text).is_equal(String(texts["curse_no_effect"]))
	assert_bool(card.frame_color().is_equal_approx(Color.html(String(cfg["curse_frame_color"])))).is_true()
	var plain := RunOptionCard.new()
	add_child(plain)
	plain.setup({"id": "remove:d", "kind": "remove", "card_id": "neutral_deep_sigh", "label": "Deep Sigh", "detail": "Buff.", "curse": false, "enabled": true},
			RunOptionCard.Look.CELL, 214.0, cfg, 1.0, {"texts": texts})
	assert_object(plain.curse_band).is_null()
	card.queue_free()
	plain.queue_free()


# --- relics, the shop ------------------------------------------------------------------------------

func test_a_sacrifice_relic_cost_reads_give_up_n_relics() -> void:
	var texts: Dictionary = RunConfig.ui()["relic"]
	assert_str(RunOptionCard.sacrifice_cost_text(0, texts)).is_empty()
	assert_str(RunOptionCard.sacrifice_cost_text(1, texts)).is_equal("Give up 1 relic")
	assert_str(RunOptionCard.sacrifice_cost_text(2, texts)).is_equal("Give up 2 relics")


func test_the_cost_comes_from_the_option_or_the_relics_data() -> void:
	RelicDatabase.load_all()
	assert_int(RunOptionCard.sacrifice_cost_of({"sacrifice_cost": 2})).is_equal(2)
	assert_int(RunOptionCard.sacrifice_cost_of({"relic_id": "hostile_takeover"})).is_equal(2)  # a shop tile has no `sacrifice_cost` key
	assert_int(RunOptionCard.sacrifice_cost_of({"relic_id": "heavy_sigh"})).is_equal(0)
	assert_int(RunOptionCard.sacrifice_cost_of({})).is_equal(0)


func test_a_sacrifice_offer_tile_shows_its_cost_and_a_picked_cell_says_picked() -> void:
	var cfg: Dictionary = UiConfig.run_ui()
	var relic_texts: Dictionary = RunConfig.ui()["relic"]
	var tile := RunOptionCard.new()
	add_child(tile)
	tile.setup({"id": "relic:x", "kind": "relic", "label": "X", "detail": "Rule.", "sacrifice_cost": 2, "enabled": true, "pool": "neutral", "tier_name": "Tier 3"},
			RunOptionCard.Look.RELIC, 268.0, cfg, 1.0, {"relic_texts": relic_texts, "texts": RunConfig.ui()["option"]})
	assert_object(tile.sacrifice_label).is_not_null()
	assert_str(tile.sacrifice_label.text).contains("Give up 2 relics")
	var cell := RunOptionCard.new()
	add_child(cell)
	cell.setup({"id": "giveup:x", "kind": "giveup", "label": "X", "detail": "Rule.", "selected": true, "enabled": true, "pool": "neutral", "tier_name": "Tier 1"},
			RunOptionCard.Look.RELIC_CELL, 290.0, cfg, 1.0, {"relic_texts": relic_texts, "texts": RunConfig.ui()["option"]})
	assert_object(cell.picked_label).is_not_null()
	assert_str(cell.picked_label.text).is_equal("Picked")
	assert_str(cell.hint_label.text).is_equal(String(relic_texts["unpick_hint"]))
	var plain := RunOptionCard.new()
	add_child(plain)
	plain.setup({"id": "giveup:y", "kind": "giveup", "label": "Y", "detail": "Rule.", "enabled": true, "pool": "neutral", "tier_name": "Tier 1"},
			RunOptionCard.Look.RELIC_CELL, 290.0, cfg, 1.0, {"relic_texts": relic_texts, "texts": RunConfig.ui()["option"]})
	assert_object(plain.picked_label).is_null()  # the plain cap swap has no toggle
	assert_str(plain.hint_label.text).is_equal(String(relic_texts["giveup_hint"]))
	for node: Node in [tile, cell, plain]:
		node.queue_free()


func test_the_confirm_of_a_give_up_step_sits_in_the_footer_with_cancel() -> void:
	assert_str(RunPromptScreen.layout_for([{"kind": "giveup"}, {"kind": "giveup_confirm"}, {"kind": "back"}])).is_equal("cells")


func test_a_discounted_shop_price_keeps_the_old_one_to_strike_through() -> void:
	var texts: Dictionary = RunConfig.ui()["merchant"]
	var cut: Dictionary = RunOptionCard.shop_price_state({"kind": "buy_relic", "price": 60, "base_price": 80, "enabled": true}, 200, texts)
	assert_str(String(cut["was_text"])).is_equal("80 gold")
	assert_str(String(cut["text"])).is_equal("60 gold")
	var plain: Dictionary = RunOptionCard.shop_price_state({"kind": "buy_relic", "price": 80, "base_price": 80, "enabled": true}, 200, texts)
	assert_str(String(plain["was_text"])).is_empty()
	var no_base: Dictionary = RunOptionCard.shop_price_state({"kind": "buy_card", "price": 41, "enabled": true}, 200, texts)
	assert_str(String(no_base["was_text"])).is_empty()


func test_the_check_shape_stays_in_its_circle() -> void:
	for p: Vector2 in RunIcons.polygon(RunIcons.SHAPE_CHECK, 10.0):
		assert_float(p.length()).is_less_equal(10.0 * 1.2)
