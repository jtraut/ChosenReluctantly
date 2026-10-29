class_name M3bUxTest
extends GdUnitTestSuite
## Milestone 3b UX: the choice screen. Layout choice, digit targets, the readable buff line, the option card
## content (slot cue, owned count, reason), Space and pause handling, and that the panel fits 1280x720 for a
## long removal list.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func after_test() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	Juice.reset()
	GamePause.reset()


func _opt(kind: String, slot_type: String = "", enabled: bool = true, card_id: String = "x") -> Dictionary:
	return {"id": kind + slot_type, "kind": kind, "slot_type": slot_type, "enabled": enabled, "card_id": card_id if kind != "back" else ""}


func _full_opt(id: String, kind: String) -> Dictionary:
	return {"id": id, "kind": kind, "label": id.to_upper(), "detail": "", "flavor": "", "card_id": "", "slot_type": "", "slot_name": "", "count": 0, "enabled": true, "reason": "", "costs_reject": false, "opens_list": false, "amount": 0.0}


func test_buff_effect_line_is_readable_and_data_driven() -> void:
	var text: Dictionary = {"slot_cooldown": "%s cooldown %s s", "for": "for %s s", "slot_names": {"attack_single": "Attack: Single"}}
	var params: Dictionary = {"stat": "slot_cooldown.attack_single", "modifier_type": "additive", "value": -0.5, "duration": 6.0}
	assert_str(CardSummary.buff_text(params, text)).is_equal("Attack: Single cooldown -0.5 s for 6.0 s")
	assert_str(CardSummary.buff_text({"stat": "move_speed", "value": 0.2, "duration": 4.0}, text)).is_equal("Move Speed +0.2 for 4.0 s")
	assert_str(CardSummary.buff_text({"stat": "slot_cooldown.odd_slot", "value": -1.0, "duration": 2.0})).contains("Odd Slot")
	var ctx: Dictionary = RunChoices.shipped_context([])
	for card: Dictionary in CardDatabase.all_cards():
		assert_str(String(RunChoices.card_option("card:x", "card", String(card["id"]), ctx)["detail"])).not_contains("slot_cooldown.")


func test_layout_and_digit_targets() -> void:
	var rest: Array = [_opt("heal", "", true, ""), _opt("remove", "", true, "")]
	assert_str(RunPromptScreen.layout_for(rest)).is_equal("actions")
	var reward: Array = [_opt("card", "utility"), _opt("card", "movement"), _opt("skip", "", true, "")]
	assert_str(RunPromptScreen.layout_for(reward)).is_equal("row")
	assert_int(RunPromptScreen.digit_target(reward, "row", 1)).is_equal(1)
	assert_int(RunPromptScreen.digit_target(reward, "row", 3)).is_equal(-1)
	var removal: Array = [_opt("remove", "attack_single"), _opt("remove", "utility", false), _opt("remove", "utility"), _opt("back")]
	assert_str(RunPromptScreen.layout_for(removal)).is_equal("grid")
	assert_int(RunPromptScreen.digit_target(removal, "grid", 2)).is_equal(2)  # key 3: the first enabled Utility card
	assert_int(RunPromptScreen.digit_target(removal, "grid", 3)).is_equal(-1)  # no Movement column
	assert_int(RunPromptScreen.digit_target(removal, "row", 3)).is_equal(-1)  # Back never takes a digit


func test_slot_key_matches_the_hud_order() -> void:
	for i in range(CardSlotController.SLOT_TYPE_ORDER.size()):
		assert_int(RunOptionCard.slot_key_for(CardSlotController.SLOT_TYPE_ORDER[i])).is_equal(i + 1)
	assert_int(RunOptionCard.slot_key_for("nope")).is_equal(0)
	assert_str(RunOptionCard.owned_text(2, "You own %d")).is_equal("You own 2")
	assert_str(RunOptionCard.owned_text(0, "You own %d")).is_equal("")


func _card(opt: Dictionary, look: RunOptionCard.Look, extra: Dictionary = {}) -> RunOptionCard:
	var card := RunOptionCard.new()
	add_child(card)
	auto_free(card)
	extra["texts"] = RunConfig.ui().get("option", {})
	card.setup(opt, look, 268.0, UiConfig.run_ui(), 1.0, extra)
	return card


func test_option_card_shows_slot_owned_and_reason() -> void:
	var opt: Dictionary = _full_opt("card:a", "card")
	opt.merge({"label": "Name", "detail": "9 damage", "flavor": "Flavor.", "card_id": "a", "slot_type": "utility", "slot_name": "Utility"}, true)
	var card := _card(opt, RunOptionCard.Look.CARD, {"index": 0, "owned": 2})
	assert_object(card.slot_chip).is_not_null()
	assert_str(card.owned_label.text).is_equal("You own 2")
	assert_str(card.flavor_label.text).is_equal("Flavor.")
	assert_bool(card.disabled).is_false()
	opt["enabled"] = false
	opt["reason"] = "No."
	var off := _card(opt, RunOptionCard.Look.CARD, {"index": 1})
	assert_bool(off.disabled).is_true()
	assert_str(off.reason_label.text).is_equal("Unavailable: No.")
	assert_object(off.owned_label).is_null()


func test_reject_tile_carries_its_cost() -> void:
	var opt: Dictionary = _full_opt("skip", "skip")
	opt.merge({"label": "Reject the offer", "detail": "Spends one reject. Rejects left: 0 of 3", "enabled": false, "reason": "No rejects left. Pick a card."}, true)
	var card := _card(opt, RunOptionCard.Look.REJECT, {"index": 3, "rejects_remaining": 0, "rejects_max": 3})
	assert_bool(card.disabled).is_true()
	assert_str(card.detail_label.text).contains("Rejects left: 0 of 3")
	assert_str(card.reason_label.text).contains("No rejects left")


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func _model(options: Array, choice: String) -> Dictionary:
	return {"choice": choice, "title": "t", "line": "l", "options": options, "rejects_remaining": 3, "rejects_max": 3, "room_type": "combat", "room_label": "", "room_type_name": "", "next_line": ""}


func test_space_never_confirms_and_focus_returns_after_pause() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	screen.show_choice(_model([_full_opt("a", "heal"), _full_opt("b", "heal")], "rest"))
	await _frames(2)
	screen.disarm()
	var picked: Array[String] = []
	screen.option_chosen.connect(func(id: String) -> void: picked.append(id))
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	screen._input(space)
	assert_array(picked).is_empty()
	var two := InputEventKey.new()
	two.keycode = KEY_2
	two.pressed = true
	screen._input(two)
	assert_bool((screen.options_box.get_child(1) as Button).has_focus()).is_true()
	GamePause.pause()
	GamePause.resume()
	await _frames(3)
	assert_bool((screen.options_box.get_child(1) as Button).has_focus()).is_true()


func test_panel_fits_720p_for_a_full_deck_removal_list() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await _frames(1)
	var screen := main.get_node("RoomClearedScreen") as RunPromptScreen
	var viewport_h: float = screen.get_viewport().get_visible_rect().size.y
	var ctx: Dictionary = RunChoices.shipped_context(main.player.owned_pools)
	var state := RunState.new()
	for card: Dictionary in CardDatabase.all_cards():
		state.deck.append(String(card["id"]))
	state.pending = RunState.PENDING_REST_REMOVE
	var model: Dictionary = RunChoices.model(state, ctx)
	model.merge({"room_type": "rest", "room_label": "", "room_type_name": "", "next_line": ""})
	screen.show_choice(model)
	await _frames(4)
	assert_str(RunPromptScreen.layout_for(model["options"])).is_equal("grid")
	assert_float(screen.panel_min_size().y * screen.fit_factor()).is_less(viewport_h)
