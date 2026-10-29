class_name OfferFitResizeTest
extends GdUnitTestSuite
## Director feedback 2026-10-29: a reward offer (3 cards plus the Reject tile) never scrolls and never clips, at any
## window size down to about 1024x600. Only the rest-room removal grid may scroll.

const SCREEN_PATH := "res://scenes/ui/RunPromptScreen.tscn"
const _UNUSED_SIZES: Array[Vector2] = [Vector2(1024, 600), Vector2(1152, 648), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]


func before_test() -> void:
	RunSession.clear()


func after_test() -> void:
	RunSession.clear()


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


## The offer model for the three shipped cards with the longest text, in a deck holding every card (longest "Slot N now").
func _worst_case_options(longest: bool) -> Array[Dictionary]:
	var ctx := RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var state := RunSession.begin_new_run(3)
	var ranked: Array[Dictionary] = []
	for card: Variant in ctx["cards"]:
		var option: Dictionary = RunChoices.card_option("x", "card", String((card as Dictionary)["id"]), ctx)
		option["weight"] = String(option["label"]).length() + String(option["detail"]).length() + String(option["flavor"]).length()
		ranked.append(option)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["weight"]) > int(b["weight"]))
	var ids: Array[String] = []
	for i in range(3):
		ids.append(String(ranked[i]["card_id"]))
	if longest:
		for card: Variant in ctx["cards"]:
			state.deck.append(String((card as Dictionary)["id"]))
		state.offer = ids
	else:
		state.offer = RewardOffer.generate(state.seed_value, 1, state.deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
	state.pending = RunState.PENDING_REWARD
	return RunChoices.options(state, ctx)


func _open(size: Vector2, options: Array[Dictionary]) -> RunPromptScreen:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	add_child(viewport)
	auto_free(viewport)
	var screen: RunPromptScreen = (load(SCREEN_PATH) as PackedScene).instantiate()
	viewport.add_child(screen)
	await _frames(2)
	screen.show_choice({"room_type": "combat", "title": "Room cleared", "room_label": "Room 1 of 8", "room_type_name": "Combat",
		"line": "Pick a card, or reject the offer.", "options": options, "rejects_remaining": 3, "rejects_max": 3, "next_line": "Next: Room 2 of 8 - Combat"})
	await _frames(4)
	screen.set_meta("vp", viewport)
	return screen


func _check_fits(screen: RunPromptScreen, size: Vector2, label: String) -> void:
	assert_int(screen.scroll.vertical_scroll_mode).override_failure_message("%s: scrolling is on" % label).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
	assert_bool(screen.scroll.get_v_scroll_bar().visible).override_failure_message("%s: a scrollbar shows" % label).is_false()
	assert_bool(screen.scroll.get_h_scroll_bar().visible).override_failure_message("%s: a horizontal scrollbar shows" % label).is_false()
	# The scroll area holds the whole options block, so nothing is clipped inside it.
	assert_float(screen.scroll.size.y).override_failure_message("%s: options clipped" % label).is_greater_equal(screen.options_box.get_combined_minimum_size().y - 0.5)
	# Every card is tall enough for its own content.
	for card: Control in screen.options_box.get_children():
		assert_float(card.size.y).is_greater_equal(card.get_combined_minimum_size().y - 0.5)
	# The scaled panel lies fully inside the window and under the HUD band.
	var rect: Rect2 = screen.panel.get_global_transform() * Rect2(Vector2.ZERO, screen.panel.size)
	assert_float(rect.position.x).override_failure_message("%s: panel left %s" % [label, rect]).is_greater_equal(-0.5)
	assert_float(rect.end.x).override_failure_message("%s: panel right %s" % [label, rect]).is_less_equal(size.x + 0.5)
	assert_float(rect.position.y).override_failure_message("%s: panel top %s" % [label, rect]).is_greater_equal(screen._band_end() - 0.5)
	assert_float(rect.end.y).override_failure_message("%s: panel bottom %s" % [label, rect]).is_less_equal(size.y + 0.5)
	# It is not shrunk into unreadable text: the fit stays at or above the floor for offers.
	assert_float(screen.fit_factor()).is_greater_equal(0.7)



## QA 2026-10-29 (fix pass 741c624..b7a6a01): the director's bug only showed after the window changed size, because
## the CenterContainer re-sorts and used to reset the panel scale. Resize a live, already-open offer and re-check.
func test_a_live_resize_keeps_the_offer_fitting_without_scroll() -> void:
	var screen: RunPromptScreen = await _open(Vector2(1920, 1080), _worst_case_options(true))
	var viewport := screen.get_meta("vp") as SubViewport
	for size in [Vector2(1150, 680), Vector2(1024, 600), Vector2(1280, 720), Vector2(1152, 648), Vector2(1024, 600), Vector2(1920, 1080), Vector2(1150, 680)]:
		viewport.size = Vector2i(size)
		await _frames(4)
		_check_fits(screen, size, "live resize to %s" % size)
