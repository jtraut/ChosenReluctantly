class_name Bd3bUxSlotTest
extends GdUnitTestSuite
## BD3b-ux, the HUD slot side: the scale value in the slot text, the condition lines (three existing conditions plus has_bonus_armor and the cast_within
## count variant), the pill priority and "Swap: free". Strings and numbers come from the same data the UI reads.


func before_test() -> void:
	CombatEvents.reset()


func after_test() -> void:
	BodyFlag.reset()
	CombatEvents.reset()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame  # the HUD polls in _process


func _main() -> Main:
	BodyFlag.set_collide(false)
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = "wizard"
	add_child(main)
	auto_free(main)
	main.player.camera = null
	return main


func _first_scale(card: Dictionary) -> Dictionary:
	for effect: Variant in (card["effects"] as Array):
		if (effect as Dictionary).has("scale"):
			return (effect as Dictionary)["scale"]
	return {}


# --- scale values in the slot text ---

func test_a_spender_slot_reads_its_per_charge_value_and_now_from_data() -> void:
	var card: Dictionary = CardDatabase.get_card("wizard_thesis_defense")
	var scale: Dictionary = _first_scale(card)
	var texts: Dictionary = RunConfig.ui()["slot_condition"]
	var words: Dictionary = RunConfig.ui()["effect"]["scale"]
	var charges: int = 6
	var scaled: Array[Dictionary] = [{"param": "damage", "base": 7.0, "bonus": float(scale["per"]) * charges, "value": 0.0, "count": charges}]
	var lines: Array[String] = ConditionCue.scale_candidates(card, scaled, texts, words)
	var per: String = str(int(scale["per"]))
	var now: String = str(int(float(scale["per"]) * charges))
	assert_str(lines[0]).is_equal("+%s per Charge, now +%s" % [per, now])  # the brief's form, from the data's own per
	assert_bool(lines[0].contains("uses up")).override_failure_message("the consume clause stays on the card text").is_false()
	assert_str(lines[lines.size() - 1]).is_equal("Now +%s" % now)
	assert_bool(lines.has("+%s/Charge: +%s" % [per, now])).is_true()


func test_the_live_number_is_the_capped_one_for_a_deck_scaled_card() -> void:
	var card: Dictionary = CardDatabase.get_card("wizard_citation_needed")
	var scale: Dictionary = _first_scale(card)
	assert_bool(scale.has("max")).is_true()
	var deck: Array[String] = []
	for i in range(int(scale["max"]) * 4):
		deck.append("wizard_bolt_volley")  # well past the cap, all Projectile cards
	var scaled: Array[Dictionary] = EffectScale.preview_values(card, null, deck)
	var lines: Array[String] = ConditionCue.scale_candidates(card, scaled, RunConfig.ui()["slot_condition"], RunConfig.ui()["effect"]["scale"])
	var capped: float = float(scale["per"]) * float(scale["max"])
	assert_float(float(scaled[0]["bonus"])).is_equal_approx(capped, 0.0001)
	assert_bool(lines[0].ends_with("now +%s" % ConditionCue._number(capped))).override_failure_message(lines[0]).is_true()
	assert_bool(lines[0].contains("up to")).override_failure_message("the cap is in the long form").is_true()


func test_a_card_without_scale_has_no_scale_pill() -> void:
	var card: Dictionary = CardDatabase.get_card("wizard_bolt_volley")
	assert_int(ConditionCue.scale_candidates(card, [], RunConfig.ui()["slot_condition"], RunConfig.ui()["effect"]["scale"]).size()).is_equal(0)


func test_the_hud_slot_follows_the_live_charge_count() -> void:
	var main: Main = _main()
	var player: Player = main.player
	await _frames(3)
	var deck: Array[String] = player.card_slots.owned_card_ids()
	deck.append("wizard_thesis_defense")
	player.card_slots.set_deck(deck)
	assert_bool(player.card_slots.reveal_first("wizard_thesis_defense")).is_true()
	var per: int = int(_first_scale(CardDatabase.get_card("wizard_thesis_defense"))["per"])
	var widget: CardSlotWidget = main.hud.slot_widgets[0]
	await _frames(2)
	assert_str(widget.scale_candidates()[0]).contains("now +0")
	var def: Dictionary = StatusDatabase.get_status("charge")
	for i in range(4):
		player.hurtbox.status_manager.apply_status("charge", def, 4.0, player)
	await _frames(2)
	assert_str(widget.scale_candidates()[0]).contains("now +%d" % (per * 4))
	BodyFlag.reset()


# --- condition lines ---

func test_every_condition_type_has_a_short_slot_line_and_a_card_text_line() -> void:
	var texts: Dictionary = RunConfig.ui()["slot_condition"]
	var summary_text: Dictionary = SlotSynergy.default_text()
	var cases: Array[Dictionary] = [
		{"type": "self_stacks_at_least", "status_id": "charge", "count": 5},
		{"type": "deck_count_at_least", "tag": "Projectile", "count": 8},
		{"type": "hp_below", "fraction": 0.5},
		{"type": "has_bonus_armor"},
		{"type": "cast_within", "tag": "Fire", "seconds": 4.0, "count": 3},
		{"type": "cast_within", "slot_type": "attack_aoe", "seconds": 4.0, "count": 2},
	]
	for condition: Dictionary in cases:
		var card: Dictionary = {"effects": [{"template": "aoe", "params": {"damage": 5.0}, "condition": condition}]}
		assert_str(ConditionCue.short_text(card, texts)).override_failure_message("no slot line for %s" % condition).is_not_empty()
		assert_str(CardSummary.condition_text(condition, summary_text)).override_failure_message("no card line for %s" % condition).is_not_empty()
	assert_str(_short(cases[0], texts)).is_equal(String(texts["self_stacks_at_least"]) % [5, "Charge"])
	assert_str(_short(cases[1], texts)).is_equal(String(texts["deck_count_at_least"]) % [8, "Projectile"])
	assert_str(_short(cases[2], texts)).is_equal(String(texts["hp_below"]) % "50")
	assert_str(_short(cases[3], texts)).is_equal(String(texts["has_bonus_armor"]))
	assert_str(_short(cases[4], texts)).is_equal(String(texts["cast_within_tag_count"]) % [3, "Fire"])


func _short(condition: Dictionary, texts: Dictionary) -> String:
	return ConditionCue.short_text({"effects": [{"template": "aoe", "params": {}, "condition": condition}]}, texts)


func test_one_cast_keeps_the_old_wording_and_a_count_of_two_or_more_gets_its_own() -> void:
	var texts: Dictionary = RunConfig.ui()["slot_condition"]
	var plain: Dictionary = {"type": "cast_within", "tag": "Fire", "seconds": 4.0}
	assert_str(_short(plain, texts)).is_equal(String(texts["cast_within_tag"]) % "Fire")
	assert_str(_short({"type": "cast_within", "tag": "Fire", "seconds": 4.0, "count": 1}, texts)).is_equal(_short(plain, texts))
	var words: Dictionary = SlotSynergy.default_text()
	assert_str(CardSummary.condition_text(plain, words)).is_equal(String(words["condition"]["cast_within_tag"]) % ["Fire", "4"])
	assert_str(CardSummary.condition_text({"type": "cast_within", "tag": "Fire", "seconds": 4.0, "count": 3}, words)).contains("3")


func test_a_bonus_armor_condition_lights_the_slot_only_when_the_view_says_so() -> void:
	var card: Dictionary = {"effects": [{"template": "aoe", "params": {}, "condition": {"type": "has_bonus_armor"}}]}
	var effect: Dictionary = (card["effects"] as Array)[0]
	assert_bool(SlotSynergy.condition_live(effect, card, {})).is_false()
	assert_bool(SlotSynergy.condition_live(effect, card, {"has_bonus_armor": true})).is_true()


func test_the_pill_priority_is_curse_then_scale_then_reason_then_free_and_the_limit_cuts_the_end() -> void:
	var scale: Array[String] = ["long", "short"]
	var all: Array[Dictionary] = ConditionCue.pill_lines("curse", scale, "reason", "free", 9)
	var kinds: Array[String] = []
	for line: Dictionary in all:
		kinds.append(String(line["kind"]))
	assert_array(kinds).is_equal(["curse", "scale", "condition", "free"])
	assert_array(all[1]["alternatives"]).is_equal(["short"])
	assert_int(ConditionCue.pill_lines("curse", scale, "reason", "free", 2).size()).is_equal(2)
	assert_str(String(ConditionCue.pill_lines("", [] as Array[String], "reason", "free", 1)[0]["kind"])).is_equal("condition")
	assert_int(ConditionCue.pill_lines("", [] as Array[String], "", "", 2).size()).is_equal(0)
	assert_int(ConditionCue.pill_lines("curse", scale, "", "", 0).size()).is_equal(0)


# --- Swap: free ---

func test_swap_free_text_needs_a_penalty_that_is_zero_with_the_modifiers_and_not_without() -> void:
	var texts: Dictionary = RunConfig.ui()["slot_condition"]
	var card: Dictionary = CardDatabase.get_card("wizard_bolt_volley")
	var curse: Dictionary = CardDatabase.get_card("curse_mandatory_training")
	assert_str(ConditionCue.swap_free_text(card, texts, 0.0, 1.0)).is_equal(String(texts["swap_free"]))
	assert_str(ConditionCue.swap_free_text(card, texts, 1.0, 1.0)).is_empty()
	assert_str(ConditionCue.swap_free_text(card, texts, 0.0, 0.0)).is_empty()  # free anyway: nothing to announce
	assert_str(ConditionCue.swap_free_text(card, texts, -1.0, -1.0)).is_empty()
	assert_str(ConditionCue.swap_free_text(curse, texts, 0.0, 2.0)).is_empty()  # a curse has its own line
	assert_str(ConditionCue.curse_swap_text(curse, texts, "Shift+F", 0.0)).is_equal(String(texts["curse_swap_free"]) % "Shift+F")
	assert_str(ConditionCue.curse_swap_text(curse, texts, "Shift+F", 2.0)).is_equal(String(texts["curse_swap_timed"]) % ["Shift+F", "2"])


func test_a_covered_slot_says_swap_free_and_a_covered_curse_says_its_swap_is_free() -> void:
	var main: Main = _main()
	var player: Player = main.player
	await _frames(3)
	var deck: Array[String] = player.card_slots.owned_card_ids()
	deck.append("curse_mandatory_training")
	player.card_slots.set_deck(deck)
	var utility: CardSlot = player.card_slots.get_slot("utility")
	var texts: Dictionary = RunConfig.ui()["slot_condition"]
	var widget: CardSlotWidget = main.hud.slot_widgets[2]  # Utility
	assert_bool(player.card_slots.reveal_first("curse_mandatory_training")).is_true()
	widget.update_from_slot(utility, player.stat_modifiers)
	assert_str(widget.swap_free_line()).is_empty()
	assert_str(widget.condition_short()).contains(" s)")  # timed, as before the relic
	# Filing Cabinet's stat (swap_penalty_mult.utility -1): the slot itself says the swap costs 0, and the widget reads that.
	player.stat_modifiers.add_modifier("swap_penalty_mult.utility", "test_filing_cabinet", "multiplicative", -1.0)
	assert_float(utility.current_swap_penalty(player.stat_modifiers)).is_equal(0.0)
	assert_float(utility.current_swap_penalty(null)).is_greater(0.0)
	widget.update_from_slot(utility, player.stat_modifiers)
	assert_str(widget.condition_short()).is_equal(String(texts["curse_swap_free"]) % InputLabels.slot_swap_key("utility"))
	# An ordinary card in the same slot reads "Swap: free" instead.
	var ordinary: Array[String] = []
	for id: String in player.card_slots.owned_card_ids():
		if id != "curse_mandatory_training":
			ordinary.append(id)
	player.card_slots.set_deck(ordinary)
	widget.update_from_slot(player.card_slots.get_slot("utility"), player.stat_modifiers)
	assert_str(widget.swap_free_line()).is_equal(String(texts["swap_free"]))
	# A slot the relic does not cover says nothing.
	var attack_widget: CardSlotWidget = main.hud.slot_widgets[0]
	attack_widget.update_from_slot(player.card_slots.get_slot("attack_single"), player.stat_modifiers)
	assert_str(attack_widget.swap_free_line()).is_empty()
	BodyFlag.reset()


# --- UX1a: the swap pills give way on a ready card and while swaps are locked ---

func test_ux1a_swap_free_hides_on_a_ready_card_and_both_swap_lines_hide_while_swaps_are_locked() -> void:
	var scale: Array[String] = ["long"]
	var cooling: Array[Dictionary] = ConditionCue.pill_lines("", scale, "reason", "free", 9, false, false)
	assert_array(cooling.map(func(line: Dictionary) -> String: return String(line["kind"]))).is_equal(["scale", "condition", "free"])
	var ready: Array[Dictionary] = ConditionCue.pill_lines("", scale, "reason", "free", 9, true, false)
	assert_array(ready.map(func(line: Dictionary) -> String: return String(line["kind"]))).is_equal(["scale", "condition"])
	var curse_ready: Array[Dictionary] = ConditionCue.pill_lines("curse", scale, "", "", 9, true, false)
	assert_str(String(curse_ready[0]["kind"])).is_equal("curse")  # a ready curse still says it can be swapped
	var locked: Array[Dictionary] = ConditionCue.pill_lines("curse", scale, "reason", "free", 9, false, true)
	assert_array(locked.map(func(line: Dictionary) -> String: return String(line["kind"]))).is_equal(["scale", "condition"])
