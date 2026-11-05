class_name Bd2UxTest
extends GdUnitTestSuite
## BD2 ux: the HUD relic row (layout at every supported size, many relics, the trigger flash that must not strobe), the relic
## offer and give-one-up screens (layout, keyboard, cancel) and the pause list.

const HUD_SCENE := "res://scenes/ui/Hud.tscn"
const SIZES: Array[Vector2] = [Vector2(1024, 600), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]


func after_test() -> void:
	Juice.reset()
	SlotSynergyView.reset_cache()


func _ids(count: int) -> Array[String]:
	var ids: Array[String] = []
	for i in range(count):
		ids.append("relic_%d" % i)
	return ids


# --- RelicFlash: pure ---

func test_a_trigger_lights_the_chip_at_once_and_it_fades_after_the_hold() -> void:
	var state: Dictionary = RelicFlash.trigger(RelicFlash.fresh(), 0.5, 1.5)
	assert_float(float(state["level"])).is_equal(1.0)
	state = RelicFlash.step(state, 0.4, 0.4)
	assert_float(float(state["level"])).is_equal(1.0)  # still inside the hold
	state = RelicFlash.step(state, 0.2, 0.4)  # hold runs out
	state = RelicFlash.step(state, 0.2, 0.4)
	assert_float(float(state["level"])).is_equal_approx(0.5, 0.001)
	state = RelicFlash.step(state, 1.0, 0.4)
	assert_float(float(state["level"])).is_equal(0.0)
	assert_bool(RelicFlash.is_active(state)).is_false()


func test_a_relic_firing_every_frame_stays_lit_and_counts_the_burst() -> void:
	var state: Dictionary = RelicFlash.fresh()
	var dim_frames: int = 0
	for i in range(120):
		state = RelicFlash.trigger(state, 0.5, 1.5)
		state = RelicFlash.step(state, 1.0 / 60.0, 0.4)
		if float(state["level"]) < 1.0:
			dim_frames += 1
	assert_int(dim_frames).override_failure_message("the chip dipped while the relic kept firing").is_equal(0)
	assert_int(int(state["count"])).is_equal(120)
	assert_str(RelicFlash.count_text(state)).is_equal("x120")


func test_the_burst_counter_resets_after_the_window() -> void:
	var state: Dictionary = RelicFlash.trigger(RelicFlash.fresh(), 0.5, 1.5)
	state = RelicFlash.trigger(state, 0.5, 1.5)
	assert_str(RelicFlash.count_text(state)).is_equal("x2")
	for i in range(30):  # 3 s
		state = RelicFlash.step(state, 0.1, 0.4)
	assert_int(int(state["count"])).is_equal(0)
	state = RelicFlash.trigger(state, 0.5, 1.5)
	assert_str(RelicFlash.count_text(state)).is_equal("")  # one trigger needs no number


func test_chip_marks_come_from_the_name_and_ignore_brackets() -> void:
	assert_str(RelicFlash.initials("Pyre Insurance")).is_equal("PI")
	assert_str(RelicFlash.initials("Second Wind (Unwillingly)")).is_equal("SW")  # the bracket is ignored
	assert_str(RelicFlash.initials("Heavy Sigh")).is_equal("HS")
	assert_str(RelicFlash.initials("")).is_equal("?")


# --- HudLayout: the relic row ---

func test_relic_row_has_no_height_when_empty_and_wraps_at_the_health_width() -> void:
	var cfg: Dictionary = UiConfig.hud()
	for size: Vector2 in SIZES:
		var empty: Rect2 = HudLayout.relic_row_rect(size, cfg, 0)
		assert_float(empty.size.y).is_equal(0.0)
		var full: Rect2 = HudLayout.relic_row_rect(size, cfg, 20)
		var health: Rect2 = HudLayout.health_rect(size, cfg)
		assert_float(full.size.x).is_equal_approx(health.size.x, 0.01)
		assert_float(full.position.x).is_equal_approx(health.position.x, 0.01)
		var dodge: Rect2 = HudLayout.dodge_rect(size, cfg)
		assert_bool(full.position.y >= dodge.end.y).override_failure_message("the row overlaps the dodge pips at %s" % size).is_true()
		assert_bool(HudLayout.safe_area(size, cfg).encloses(full)).override_failure_message("20 relics leave the safe area at %s" % size).is_true()
		var slots: Rect2 = HudLayout.slot_bar_rect(size, cfg, 5)
		assert_bool(full.end.y < slots.position.y).override_failure_message("20 relics reach the slot bar at %s" % size).is_true()


func test_twenty_relics_take_a_few_rows_not_one_long_one() -> void:
	var cfg: Dictionary = UiConfig.hud()
	var size := Vector2(1280, 720)
	var one: Rect2 = HudLayout.relic_row_rect(size, cfg, 1)
	var twenty: Rect2 = HudLayout.relic_row_rect(size, cfg, 20)
	assert_float(twenty.size.y).is_greater(one.size.y)
	assert_float(twenty.size.y).is_less(one.size.y * 5.0)


func test_the_relic_row_does_not_widen_the_left_column_the_boss_bar_is_measured_from() -> void:
	var cfg: Dictionary = UiConfig.hud()
	for size: Vector2 in SIZES:
		var full: Rect2 = HudLayout.relic_row_rect(size, cfg, 20)
		var meters: Rect2 = HudLayout.attack_meter_rects(size, cfg)[&"heavy"]
		assert_bool(full.end.x <= meters.end.x + 0.01).is_true()


# --- the row on a live HUD ---

func _hud(size: Vector2i) -> Hud:
	var window := get_window()
	window.size = size
	var hud: Hud = auto_free(load(HUD_SCENE).instantiate())
	add_child(hud)
	return hud


func test_the_hud_row_shows_chips_that_fit_at_every_size_with_twenty_relics() -> void:
	var hud: Hud = _hud(Vector2i(1024, 600))
	var ids: Array[String] = _ids(20)
	hud.relic_row.set_relics(ids)
	for size: Vector2 in SIZES:
		hud.relic_row.configure(UiConfig.hud(), HudLayout.ui_scale(size, UiConfig.hud()))
		var rr: Rect2 = HudLayout.relic_row_rect(size, UiConfig.hud(), 20)
		hud.relic_row.size = rr.size
		for i in range(20):
			var chip: Rect2 = hud.relic_row.chip_rect(i)
			assert_bool(Rect2(Vector2.ZERO, rr.size).encloses(chip)).override_failure_message("chip %d outside the row at %s" % [i, size]).is_true()
			assert_float(chip.size.x).is_greater_equal(20.0)  # the 2-letter mark stays legible at the smallest size
		assert_int(hud.relic_row.chip_font_px()).is_greater_equal(10)


func test_the_hud_row_resizes_with_the_relic_count_and_flashes_only_held_relics() -> void:
	var hud: Hud = _hud(Vector2i(1280, 720))
	assert_int(hud.relic_row.entries().size()).is_equal(0)
	var held: Array[String] = ["pyre_insurance", "heavy_sigh"]
	hud.relic_row.set_relics(held)
	assert_int(hud.relic_row.entries().size()).is_equal(2)
	assert_float(hud.relic_row.size.y).is_greater(0.0)
	hud.relic_row.on_trigger("pyre_insurance", 0, "status_ended")
	assert_float(float(hud.relic_row.flash_state("pyre_insurance")["level"])).is_equal(1.0)
	assert_float(float(hud.relic_row.flash_state("heavy_sigh")["level"])).is_equal(0.0)
	hud.relic_row.on_trigger("not_held", 0, "x")
	assert_float(float(hud.relic_row.flash_state("not_held")["level"])).is_equal(0.0)
	# Losing a relic (a swap) drops its chip and its flash.
	hud.relic_row.set_relics(["heavy_sigh"] as Array[String])
	assert_int(hud.relic_row.entries().size()).is_equal(1)
	assert_float(float(hud.relic_row.flash_state("pyre_insurance")["level"])).is_equal(0.0)


func test_chip_colour_is_the_pool_frame_colour_and_a_missing_relic_still_gets_a_chip() -> void:
	var entry: Dictionary = RelicRow.entry_for("pyre_insurance")
	assert_object(entry["color"]).is_equal(PoolDatabase.frame_color_for_pool("fire"))
	assert_str(String(entry["mark"])).is_equal("PI")
	var ghost: Dictionary = RelicRow.entry_for("gone_relic")
	assert_str(String(ghost["name"])).is_equal("gone_relic")


# --- the relic offer and give-one-up screens ---

const SCREEN_PATH := "res://scenes/ui/RunPromptScreen.tscn"


func before_test() -> void:
	RunSession.clear()


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func _ctx(cap: int = 20) -> Dictionary:
	var ctx := RunChoices.shipped_context(["rogue", "fire", "neutral"])
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	return ctx


## The model of an open relic offer (`held` already owned, `offered` on the table) or its give-one-up step.
func _model(held: Array[String], offered: Array[String], cap: int, swapping: String = "") -> Dictionary:
	var ctx := _ctx(cap)
	var state := RunSession.begin_new_run(3)
	state.relics = held.duplicate()
	state.offer = offered.duplicate()
	state.pending = RunState.PENDING_RELIC
	if swapping != "":
		state.pending = RunState.PENDING_RELIC_SWAP
		state.relic_incoming = swapping
	var model: Dictionary = RunChoices.model(state, ctx, "elite")
	model["room_type"] = "elite"
	model["room_label"] = "Room 4 of 10"
	model["room_type_name"] = "Elite"
	model["next_line"] = "Next: Room 5 of 10 - Combat"
	return model


func _open_model(size: Vector2, model: Dictionary) -> RunPromptScreen:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	add_child(viewport)
	auto_free(viewport)
	var screen: RunPromptScreen = (load(SCREEN_PATH) as PackedScene).instantiate()
	viewport.add_child(screen)
	await _frames(2)
	screen.show_choice(model)
	await _frames(4)
	screen.disarm()
	return screen


func _assert_panel_inside(screen: RunPromptScreen, size: Vector2, label: String) -> void:
	var rect: Rect2 = screen.panel.get_global_transform() * Rect2(Vector2.ZERO, screen.panel.size)
	assert_float(rect.position.x).override_failure_message("%s: panel left %s" % [label, rect]).is_greater_equal(-0.5)
	assert_float(rect.end.x).override_failure_message("%s: panel right %s" % [label, rect]).is_less_equal(size.x + 0.5)
	assert_float(rect.position.y).override_failure_message("%s: panel top %s" % [label, rect]).is_greater_equal(screen._band_end() - 0.5)
	assert_float(rect.end.y).override_failure_message("%s: panel bottom %s" % [label, rect]).is_less_equal(size.y + 0.5)


func test_relic_options_get_their_own_looks_and_layouts() -> void:
	assert_int(RunPromptScreen.look_for("relic")).is_equal(RunOptionCard.Look.RELIC)
	assert_int(RunPromptScreen.look_for("relic_skip")).is_equal(RunOptionCard.Look.SKIP_FREE)
	assert_int(RunPromptScreen.look_for("giveup")).is_equal(RunOptionCard.Look.RELIC_CELL)
	assert_str(RunPromptScreen.layout_for([{"kind": "relic"}, {"kind": "relic_skip"}])).is_equal("row")
	assert_str(RunPromptScreen.layout_for([{"kind": "giveup"}, {"kind": "back"}])).is_equal("cells")
	assert_str(RunPromptScreen.layout_for([{"kind": "card"}, {"kind": "skip"}])).is_equal("row")  # unchanged


func test_a_relic_offer_fits_without_scrolling_at_every_size() -> void:
	for size: Vector2 in SIZES:
		var screen: RunPromptScreen = await _open_model(size, _model([], ["pyre_insurance", "smoldering_grudge", "heavy_sigh"], 20))
		assert_int(screen.scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_DISABLED)
		assert_float(screen.scroll.size.y).is_greater_equal(screen.options_box.get_combined_minimum_size().y - 0.5)
		_assert_panel_inside(screen, size, "offer %s" % size)
		assert_float(screen.fit_factor()).override_failure_message("offer shrunk to %s at %s" % [screen.fit_factor(), size]).is_greater_equal(0.7)
		for card: Control in screen.options_box.get_children():
			assert_float(card.size.y).is_greater_equal(card.get_combined_minimum_size().y - 0.5)


func test_a_relic_offer_card_says_relic_and_cannot_pass_for_a_card() -> void:
	var screen: RunPromptScreen = await _open_model(Vector2(1280, 720), _model([], ["pyre_insurance", "smoldering_grudge", "heavy_sigh"], 20))
	var cards: Array[RunOptionCard] = []
	for child: Node in screen.options_box.get_children():
		cards.append(child as RunOptionCard)
	assert_int(cards.size()).is_equal(4)
	for i in range(3):
		assert_int(cards[i].look).is_equal(RunOptionCard.Look.RELIC)
		assert_object(cards[i].relic_band).is_not_null()  # the filled "Relic" band
		assert_object(cards[i].slot_chip).is_null()  # no slot key chip: a card has one
		var texts: Array[String] = []
		for label: Node in cards[i].relic_band.find_children("*", "Label", true, false):
			texts.append((label as Label).text)
		assert_array(texts).contains([String(RunConfig.ui()["relic"]["label"])])
		assert_str(String(cards[i].option["rule_text"])).is_not_empty()
		assert_str(String(cards[i].option["flavor"])).is_not_empty()
		assert_object(cards[i].flavor_label).is_not_null()
		assert_object(cards[i].detail_label).is_not_null()
	assert_object(cards[0].frame_color()).is_equal(PoolDatabase.frame_color_for_pool("fire"))
	assert_object(cards[2].frame_color()).is_equal(PoolDatabase.frame_color_for_pool("neutral"))
	assert_object(cards[0].cap_note_label).is_null()  # not at the cap


func test_skip_is_free_it_is_not_the_reject_tile() -> void:
	var screen: RunPromptScreen = await _open_model(Vector2(1280, 720), _model([], ["pyre_insurance"], 20))
	var skip: RunOptionCard = screen.options_box.get_child(screen.options_box.get_child_count() - 1) as RunOptionCard
	assert_int(skip.look).is_equal(RunOptionCard.Look.SKIP_FREE)
	assert_object(skip.free_tag).is_not_null()
	assert_str(skip.title_label.text).is_equal(String(RunConfig.ui()["relic"]["skip_label"]))
	assert_str(skip.detail_label.text).contains("does not use a reject")
	assert_bool(skip._pips == null).is_true()  # a reject draws pips; a free skip must not


func test_taking_a_relic_at_the_cap_warns_on_the_card() -> void:
	var screen: RunPromptScreen = await _open_model(Vector2(1280, 720), _model(["heavy_sigh", "pyre_insurance"], ["lingering_embers", "smoldering_grudge"], 2))
	var first: RunOptionCard = screen.options_box.get_child(0) as RunOptionCard
	assert_object(first.cap_note_label).is_not_null()


func test_keyboard_reaches_every_relic_option_and_enter_picks_the_focused_one() -> void:
	var screen: RunPromptScreen = await _open_model(Vector2(1280, 720), _model([], ["pyre_insurance", "smoldering_grudge", "heavy_sigh"], 20))
	var picked: Array[String] = []
	screen.option_chosen.connect(func(id: String) -> void: picked.append(id))
	var buttons: Array[Control] = []
	for child: Node in screen.options_box.get_children():
		buttons.append(child as Control)
	for button: Control in buttons:
		assert_int(button.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool(buttons[0].has_focus()).is_true()  # the first relic starts highlighted
	var viewport: Viewport = screen.get_viewport()
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	viewport.push_input(right)
	await _frames(2)
	assert_bool(buttons[1].has_focus()).is_true()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	viewport.push_input(enter)
	var enter_up := InputEventKey.new()
	enter_up.keycode = KEY_ENTER
	enter_up.pressed = false
	viewport.push_input(enter_up)  # a button confirms on release
	await _frames(2)
	assert_array(picked).is_equal(["relic:smoldering_grudge"] as Array[String])
	buttons[3].grab_focus()  # and Skip takes focus too
	assert_bool(buttons[3].has_focus()).is_true()


func test_the_give_up_step_shows_the_incoming_relic_the_giveable_ones_and_a_cancel() -> void:
	var model: Dictionary = _model(["pyre_insurance", "heavy_sigh"], ["lingering_embers"], 2, "lingering_embers")
	var screen: RunPromptScreen = await _open_model(Vector2(1280, 720), model)
	assert_bool(screen.incoming_plate.visible).is_true()
	assert_str((screen.incoming_plate.get_node("Body/Head/Title") as Label).text).contains("Lingering Embers")
	assert_str((screen.incoming_plate.get_node("Body/Rule") as Label).text).is_not_empty()
	var ids: Array[String] = []
	var picked: Array[String] = []
	screen.option_chosen.connect(func(id: String) -> void: picked.append(id))
	for option: Dictionary in screen._options:
		ids.append(String(option["id"]))
	assert_array(ids).is_equal(["giveup:pyre_insurance", "giveup:heavy_sigh", "giveup_cancel"] as Array[String])
	var cancel: Button = screen.footer_box.get_child(0) as Button
	assert_int(cancel.focus_mode).is_equal(Control.FOCUS_ALL)
	cancel.pressed.emit()
	assert_array(picked).is_equal(["giveup_cancel"] as Array[String])


func test_cancel_keeps_everything_and_returns_to_the_offer() -> void:
	var ctx := _ctx(2)
	var state := RunSession.begin_new_run(3)
	state.relics = ["heavy_sigh", "pyre_insurance"] as Array[String]
	state.offer = ["lingering_embers", "smoldering_grudge"] as Array[String]
	state.pending = RunState.PENDING_RELIC
	var opened: Dictionary = RunRelics.apply(state, "relic:lingering_embers", ctx)
	assert_str(String(opened["kind"])).is_equal("relic_swap_open")
	var model: Dictionary = RunChoices.model(state, ctx, "elite")
	assert_str(String(model["relic_choice"])).is_equal("giveup")
	var cancelled: Dictionary = RunRelics.apply(state, "giveup_cancel", ctx)
	assert_str(String(cancelled["kind"])).is_equal("relic_cancel")
	assert_array(state.relics).is_equal(["heavy_sigh", "pyre_insurance"] as Array[String])
	assert_array(state.offer).is_equal(["lingering_embers", "smoldering_grudge"] as Array[String])
	assert_str(String(RunChoices.model(state, ctx, "elite")["relic_choice"])).is_equal("offer")


func test_a_boss_relic_is_listed_as_locked_and_is_not_an_option() -> void:
	var model: Dictionary = _model(["pyre_insurance", "heavy_sigh"], ["lingering_embers"], 2, "lingering_embers")
	var owned: Array = model["relics_owned"]
	(owned[0] as Dictionary)["giveable"] = false
	(owned[0] as Dictionary)["tier_name"] = "Boss"
	var options: Array = model["options"]
	options.remove_at(0)  # what RunRelics does: a boss relic never becomes a giveup option
	var screen: RunPromptScreen = await _open_model(Vector2(1280, 720), model)
	assert_int(screen._options.size()).is_equal(2)  # one giveable and Cancel
	assert_int(screen.stats.get_child_count()).is_equal(2)  # label and value
	assert_str((screen.stats.get_child(1) as Label).text).contains("Pyre Insurance")
	assert_str((screen.stats.get_child(0) as Label).text).is_equal(String(RunConfig.ui()["relic"]["locked_label"]))


func test_a_full_house_of_twenty_giveable_relics_scrolls_and_stays_inside_the_window() -> void:
	var base: Dictionary = _model(["pyre_insurance", "heavy_sigh"], ["lingering_embers"], 2, "lingering_embers")
	var template: Dictionary = (base["options"] as Array)[0]
	var options: Array[Dictionary] = []
	for i in range(20):
		var option: Dictionary = template.duplicate(true)
		option["id"] = "giveup:fake_%d" % i
		option["label"] = "Relic number %d" % i
		options.append(option)
	var cancel: Dictionary = ((base["options"] as Array)[(base["options"] as Array).size() - 1] as Dictionary).duplicate(true)
	options.append(cancel)
	base["options"] = options
	for size: Vector2 in SIZES:
		var screen: RunPromptScreen = await _open_model(size, base.duplicate(true))
		assert_int(screen.scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)
		_assert_panel_inside(screen, size, "20 relics %s" % size)
		assert_float(screen.scroll.size.y).override_failure_message("the list has no room at %s" % size).is_greater_equal(100.0 * screen.fit_factor())
		assert_bool(screen.footer_box.visible).is_true()  # Cancel is always on screen
		var cancel_rect: Rect2 = screen.footer_box.get_global_transform() * Rect2(Vector2.ZERO, screen.footer_box.size)
		assert_float(cancel_rect.end.y).is_less_equal(size.y + 0.5)
		var last: Control = screen.options_box.get_child(19) as Control
		last.grab_focus()  # the 20th relic is reachable: focusing it scrolls it into view
		await _frames(3)
		assert_bool(last.has_focus()).is_true()
