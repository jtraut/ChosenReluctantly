class_name Df1UxTest
extends GdUnitTestSuite
## DF1 ux: the MAP4 readability carry-overs (curse swap hint, curse wording, merchant-ahead wording, sacrifice relic text, one Bleed label per cast,
## the sacrifice give-up step's first focus).


func test_a_curse_slot_hint_names_the_swap_key() -> void:
	var texts: Dictionary = RunConfig.ui()["slot_condition"]
	var curse: Dictionary = CardDatabase.get_card("curse_property_damage")
	assert_str(ConditionCue.curse_swap_text(curse, texts, "Shift+E")).is_equal("Shift+E swaps")
	assert_str(ConditionCue.curse_swap_text(CardDatabase.get_card("rogue_drive_by"), texts, "Shift+E")).is_equal("")
	assert_str(ConditionCue.curse_swap_text(curse, {}, "Shift+E")).is_equal("")


func test_the_curse_hint_carries_the_penalty_read_from_data() -> void:
	var texts: Dictionary = RunConfig.ui()["slot_condition"]
	var curse: Dictionary = CardDatabase.get_card("curse_property_damage")
	assert_str(ConditionCue.curse_swap_text(curse, texts, "Shift+E", 2.0)).is_equal("Shift+E swaps (2 s)")
	assert_str(ConditionCue.curse_swap_text(curse, texts, "Shift+E", 1.5)).is_equal("Shift+E swaps (1.5 s)")
	assert_str(ConditionCue.curse_swap_text(curse, texts, "Shift+E", -1.0)).is_equal("Shift+E swaps")
	assert_str(ConditionCue.curse_swap_text(CardDatabase.get_card("rogue_drive_by"), texts, "Shift+E", 2.0)).is_equal("")


func test_the_slot_widget_shows_the_hint_only_for_a_curse() -> void:
	var slot_ids: Array[String] = ["curse_property_damage", "rogue_drive_by"]
	var widget: CardSlotWidget = auto_free(CardSlotWidget.new())
	widget._refresh_condition_short(slot_ids[0])
	var seconds: String = String.num(RunConfig.curse_swap_penalty(), 2).trim_suffix("0").trim_suffix(".0").trim_suffix(".")
	assert_str(widget.condition_short()).is_equal("%s swaps (%s s)" % [InputLabels.slot_swap_key("attack_single"), seconds])
	widget._refresh_condition_short(slot_ids[1])
	assert_str(widget.condition_short()).not_contains("swaps")


func test_curse_event_lines_say_what_a_curse_is() -> void:
	var lines: Dictionary = RunConfig.ui()["event"]["lines"]
	assert_str(String(lines["gain_curse_random"])).contains("dud card")
	assert_str(String(lines["gain_curse"])).contains("dud card")
	assert_str(String(RunConfig.ui()["event"]["remove_curse_line"])).contains("swap past it")


func test_the_merchant_discount_line_says_a_merchant_must_be_ahead() -> void:
	assert_str(String(RunConfig.ui()["event"]["lines"]["merchant_discount"])).contains("only if one is ahead")


func test_sacrifice_relic_rule_text_does_not_repeat_the_cost() -> void:
	for relic_id: String in ["hostile_takeover", "asset_stripping", "brain_drain", "golden_parachute"]:
		var data: Dictionary = RelicDatabase.get_relic(relic_id)
		assert_bool(data.is_empty()).is_false()
		assert_str(String(data["rule_text"])).not_contains("Give up")
		assert_int(int(data["sacrifice_cost"])).is_greater(0)  # the cost itself is untouched (it is on the Cost line)


func test_the_detonate_word_shows_once_per_cast() -> void:
	assert_bool(Juice.should_show_detonate_word("", -1, "Bleed detonated", 1000, 0.3)).is_true()
	assert_bool(Juice.should_show_detonate_word("Bleed detonated", 1000, "Bleed detonated", 1000, 0.3)).is_false()  # the same cast
	assert_bool(Juice.should_show_detonate_word("Bleed detonated", 1000, "Bleed detonated", 1250, 0.3)).is_false()
	assert_bool(Juice.should_show_detonate_word("Bleed detonated", 1000, "Bleed detonated", 1300, 0.3)).is_true()  # the next cast
	assert_bool(Juice.should_show_detonate_word("Bleed detonated", 1000, "Burn detonated", 1000, 0.3)).is_true()  # another status
	assert_bool(Juice.should_show_detonate_word("Bleed detonated", 1000, "Bleed detonated", 1000, 0.0)).is_true()  # window off
	assert_float(float(UiConfig.status_stacks()["detonate_word_window"])).is_greater(0.0)


func test_the_sacrifice_step_starts_on_the_first_relic_and_the_plain_swap_on_cancel() -> void:
	var relic_a: Dictionary = {"id": "giveup:a", "kind": "giveup", "enabled": true}
	var relic_b: Dictionary = {"id": "giveup:b", "kind": "giveup", "enabled": true}
	var confirm: Dictionary = {"id": "confirm", "kind": "giveup_confirm", "enabled": false}
	var cancel: Dictionary = {"id": "cancel", "kind": "back", "enabled": true}
	var sacrifice: Array[Dictionary] = [relic_a, relic_b, confirm, cancel]
	assert_int(RunPromptScreen.default_focus_index(sacrifice, "cells")).is_equal(0)
	var plain: Array[Dictionary] = [relic_a, relic_b, cancel]
	assert_int(RunPromptScreen.default_focus_index(plain, "cells")).is_equal(2)  # a reflexive Enter must not give a relic away (BD2)
	var cards: Array[Dictionary] = [{"id": "x", "kind": "card", "enabled": false}, {"id": "y", "kind": "card", "enabled": true}]
	assert_int(RunPromptScreen.default_focus_index(cards, "list")).is_equal(1)


func test_juice_reset_clears_the_detonate_word_memory() -> void:
	Juice._last_detonate_word = "Bleed detonated"
	Juice._last_detonate_msec = 1000
	Juice.reset()
	assert_str(Juice._last_detonate_word).is_empty()
	assert_int(Juice._last_detonate_msec).is_equal(-1)


func test_the_starter_relic_is_named_in_words_at_run_start() -> void:
	var row: RelicRow = auto_free(RelicRow.new())
	row.configure(UiConfig.hud(), 1.0)
	var relic_id: String = RelicDatabase.ids()[0]
	row.set_relics([relic_id] as Array[String])
	row.show_start_tag()
	assert_str(row.tag_text()).is_equal(String(RunConfig.ui()["relic"]["start_tag"]) % String(RelicDatabase.get_relic(relic_id)["name"]))
	assert_float(row.tag_time_left()).is_equal(float(UiConfig.hud()["relic_start_hold"]))
	assert_float(row.tag_time_left()).is_greater(float(UiConfig.hud()["relic_name_hold"]))
