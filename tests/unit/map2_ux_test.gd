class_name Map2UxTest
extends GdUnitTestSuite
## MAP2 ux: the merchant panel (shop tiles, price tags, reasons, focus after a purchase, the give-one-up cost line), the shop layout fitting 1024x600, and
## the MAP1 carry-overs that live in ui scripts and ui data. Pure helpers are tested without a scene; the panel is opened in a SubViewport.

const SCREEN_PATH := "res://scenes/ui/RunPromptScreen.tscn"
const SIZES: Array[Vector2] = [Vector2(1024, 600), Vector2(1280, 720), Vector2(1920, 1080)]


func before_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()
	assert_bool(MerchantSwitch.apply()).is_true()


func after_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.relic_cap = 0
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	GamePause.reset()


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func _ctx() -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools("rogue"))


## A rogue standing on a merchant node with `gold`, the shop open.
func _shop(gold: int, relics: Array[String] = []) -> RunState:
	var state: RunState = null
	for seed_value in range(1, 200):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) != "merchant":
				continue
			var trail: Array[int] = [int(entry["id"])]
			while int(MapGraph.node(map, trail[0])["room"]) > 1:
				trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
			state = RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			break
		if state != null:
			break
	assert_object(state).is_not_null()
	state.gold = gold
	for relic_id: String in relics:
		state.add_relic(relic_id)
	RunChoices.open_for_room(state, "merchant", false, _ctx())
	return state


func _model(state: RunState) -> Dictionary:
	var model: Dictionary = RunChoices.model(state, _ctx(), "merchant")
	model["room_type"] = "merchant"
	model["room_label"] = "Room 9 of 10"
	model["room_type_name"] = "Merchant"
	return model


func _open(size: Vector2, model: Dictionary) -> RunPromptScreen:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	add_child(viewport)
	auto_free(viewport)
	var screen: RunPromptScreen = (load(SCREEN_PATH) as PackedScene).instantiate()
	viewport.add_child(screen)
	await _frames(2)
	screen.show_choice(model)
	await _frames(4)
	return screen


func _buttons(screen: RunPromptScreen) -> Array[RunOptionCard]:
	var out: Array[RunOptionCard] = []
	for button: Button in screen._option_buttons:
		out.append(button as RunOptionCard)
	return out


# --- pure helpers ----------------------------------------------------------------------------------

func test_shop_kinds_get_the_shop_layout_and_tiles_and_the_removal_list_keeps_its_grid() -> void:
	for kind in ["buy_relic", "buy_card", "buy_removal", "reroll"]:
		assert_str(RunPromptScreen.layout_for([{"kind": kind}, {"kind": "back"}])).is_equal("shop")
		assert_int(RunPromptScreen.look_for(kind)).is_equal(RunOptionCard.Look.SHOP)
	assert_str(RunPromptScreen.layout_for([{"kind": "remove", "card_id": "x"}, {"kind": "back"}])).is_equal("grid")
	assert_str(RunPromptScreen.layout_for([{"kind": "giveup"}, {"kind": "back"}])).is_equal("cells")
	assert_str(RunPromptScreen.shop_row_of("buy_relic")).is_equal("relic")
	assert_str(RunPromptScreen.shop_row_of("buy_card")).is_equal("card")
	assert_str(RunPromptScreen.shop_row_of("reroll")).is_equal("service")


func test_price_tags_say_price_short_sold_or_free_in_words_and_numbers() -> void:
	var texts: Dictionary = RunConfig.ui()["merchant"]
	var buyable: Dictionary = {"kind": "buy_relic", "price": 30, "sold": false, "enabled": true, "reason_code": ""}
	assert_dict(RunOptionCard.shop_price_state(buyable, 200, texts)).is_equal({"text": "30 gold", "mode": "price"})
	var short: Dictionary = {"kind": "buy_card", "price": 40, "sold": false, "enabled": false, "reason_code": "too_expensive", "reason": "Not enough gold"}
	assert_str(String(RunOptionCard.shop_price_state(short, 25, texts)["mode"])).is_equal("short")
	assert_str(RunOptionCard.shop_reason_line(short, 25, texts)).is_equal("Need 15 more gold")
	var sold: Dictionary = {"kind": "buy_relic", "price": 30, "sold": true, "enabled": false, "reason_code": "sold", "reason": "Sold"}
	assert_dict(RunOptionCard.shop_price_state(sold, 200, texts)).is_equal({"text": "Sold", "mode": "sold"})
	assert_str(RunOptionCard.shop_reason_line(sold, 200, texts)).is_empty()  # the tag says it
	var none: Dictionary = {"kind": "buy_removal", "price": 50, "sold": false, "enabled": false, "reason_code": "none_removable", "reason": "Every card is needed to meet the deck minimums"}
	assert_str(RunOptionCard.shop_reason_line(none, 200, texts)).is_equal("No card can go: deck minimums")
	assert_str(RunOptionCard.shop_reason_line(buyable, 200, texts)).is_empty()
	var reroll: Dictionary = {"kind": "reroll", "price": 0, "sold": false, "enabled": true, "reason_code": ""}
	assert_dict(RunOptionCard.shop_price_state(reroll, 0, texts)).is_equal({"text": "Free", "mode": "free"})


func test_the_highlight_stays_put_after_a_purchase_and_moves_on_when_its_tile_is_sold() -> void:
	var ids: Array[String] = ["buy_relic:a", "buy_relic:b", "buy_card:c", "merchant_remove_menu", "merchant_leave"]
	var all_on: Array[bool] = [true, true, true, true, true]
	# bought nothing here (a different tile was bought): the same option keeps it
	assert_int(RunPromptScreen.focus_after_refill(ids, 2, ids, all_on, "shop", "shop")).is_equal(2)
	# the tile that had it is sold now (disabled): the nearest usable one gets it
	var sold_b: Array[bool] = [true, false, true, true, true]
	assert_int(RunPromptScreen.focus_after_refill(ids, 1, ids, sold_b, "shop", "shop")).is_equal(2)  # the next one, not the previous
	var sold_ab: Array[bool] = [false, false, true, true, true]
	assert_int(RunPromptScreen.focus_after_refill(ids, 1, ids, sold_ab, "shop", "shop")).is_equal(2)
	# back from the removal list: the entry that opened it
	assert_int(RunPromptScreen.focus_after_refill(["x", "merchant_back"], 0, ids, all_on, "remove", "shop")).is_equal(3)
	assert_int(RunPromptScreen.focus_after_refill([], -1, ids, all_on, "swap", "shop")).is_equal(0)


func test_a_swap_step_says_what_the_relic_costs_and_that_cancel_is_free() -> void:
	var model: Dictionary = {"merchant_screen": "swap", "line": "You hold 3 relics.", "incoming": {"relic_id": "r1"},
		"merchant": {"items": [{"kind": "relic", "id": "r1", "price": 45}]}}
	var line: String = RunPromptScreen.merchant_line(model)
	assert_str(line).contains("45 gold")
	assert_str(line).contains("Cancel charges nothing")
	assert_str(RunPromptScreen.merchant_line({"merchant_screen": "shop", "line": "x"})).is_empty()
	assert_str(RunPromptScreen.merchant_line({"line": "Pick a card."})).is_equal("Pick a card.")


# --- the panel -------------------------------------------------------------------------------------

func test_the_shop_fits_without_clipping_at_small_and_common_sizes() -> void:
	for size in SIZES:
		var state: RunState = _shop(200, ["request_for_quotation"])
		var screen: RunPromptScreen = await _open(size, _model(state))
		var label: String = "%dx%d" % [int(size.x), int(size.y)]
		var buttons: Array[RunOptionCard] = _buttons(screen)
		assert_int(buttons.size()).override_failure_message("%s: %d options" % [label, buttons.size()]).is_greater_equal(8)
		assert_str(screen._layout).is_equal("shop")
		assert_bool(screen.scroll.get_v_scroll_bar().visible).override_failure_message("%s: the shop scrolls" % label).is_false()
		assert_float(screen.fit_factor()).is_greater_equal(0.8)
		for button in buttons:
			var rect: Rect2 = button.get_global_rect()
			assert_float(rect.position.x).override_failure_message("%s: %s left of the window" % [label, button.option["id"]]).is_greater_equal(-0.5)
			assert_float(rect.end.x).override_failure_message("%s: %s right of the window" % [label, button.option["id"]]).is_less_equal(size.x + 0.5)
			assert_float(rect.position.y).override_failure_message("%s: %s above the window" % [label, button.option["id"]]).is_greater_equal(-0.5)
			assert_float(rect.end.y).override_failure_message("%s: %s below the window (%s)" % [label, button.option["id"], rect]).is_less_equal(size.y + 0.5)
		var panel_rect: Rect2 = screen.panel.get_global_transform() * Rect2(Vector2.ZERO, screen.panel.size)
		assert_float(panel_rect.position.y).is_greater_equal(screen._band_end() - 0.5)
		assert_float(panel_rect.end.y).is_less_equal(size.y + 0.5)
		# Leave, Remove a card and the reroll are footer options (always on screen); the price tags are drawn and the gold badge shows
		assert_int(screen.footer_box.get_child_count()).is_equal(3)
		assert_bool(screen.gold_badge.visible).is_true()
		assert_int(screen.gold_badge.total()).is_equal(200)


func test_a_longer_shop_scrolls_and_every_tile_stays_reachable() -> void:
	var state: RunState = _shop(200, ["request_for_quotation"])
	var visit: Dictionary = state.merchant_visit
	var relics: Array = visit["relics"]
	var cards: Array = visit["cards"]
	var by_id: Dictionary = RunConfig.get_config()
	assert_array(relics).has_size(3)
	# Stress: a fourth relic and a fourth card (a shop-expanding relic does this one day).
	var spare_relic: String = ""
	for relic: Variant in RelicDatabase.all_relics():
		var id: String = String((relic as Dictionary)["id"])
		if not relics.has(id) and not state.has_relic(id) and Merchant.relic_price(id, _ctx()) > 0:
			spare_relic = id
			break
	var spare_card: String = ""
	for card: Variant in (_ctx()["cards"] as Array):
		var id: String = String((card as Dictionary)["id"])
		if not cards.has(id):
			spare_card = id
			break
	relics.append(spare_relic)
	cards.append(spare_card)
	assert_bool(by_id.is_empty()).is_false()
	var screen: RunPromptScreen = await _open(Vector2(1024, 600), _model(state))
	assert_bool(screen.scroll.get_v_scroll_bar().visible).is_true()  # four rows do not fit 1024x600
	assert_int(screen.scroll.vertical_scroll_mode).is_equal(ScrollContainer.SCROLL_MODE_AUTO)
	assert_bool(screen.scroll.follow_focus).is_true()  # the keyboard brings a clipped tile into view
	var panel_rect: Rect2 = screen.panel.get_global_transform() * Rect2(Vector2.ZERO, screen.panel.size)
	assert_float(panel_rect.end.y).is_less_equal(600.5)
	# The footer (services and Leave) stays on screen however long the stock is.
	for child: Control in screen.footer_box.get_children():
		assert_float(child.get_global_rect().end.y).is_less_equal(600.5)
	# The tiles sit left of the scroll bar, not under it.
	var bar_left: float = screen.scroll.get_v_scroll_bar().get_global_rect().position.x
	for button in _buttons(screen):
		if button.get_parent() == screen.options_box:
			assert_float(button.get_global_rect().end.x).is_less_equal(bar_left + 0.5)


func test_a_too_expensive_item_is_greyed_with_the_gold_it_lacks_and_a_sold_one_keeps_its_place() -> void:
	var state: RunState = _shop(35)
	var model: Dictionary = _model(state)
	var screen: RunPromptScreen = await _open(Vector2(1280, 720), model)
	var tiles: Array[RunOptionCard] = _buttons(screen)
	var found_short: bool = false
	for tile in tiles:
		if String(tile.option.get("kind", "")) == "buy_card":
			assert_bool(tile.disabled).is_true()  # 40 gold against 35
			assert_str(tile.reason_label.text).is_equal("Need 5 more gold")
			assert_str(String(tile.option["reason_code"])).is_equal("too_expensive")
			found_short = true
	assert_bool(found_short).is_true()
	# Buying a relic (30) leaves 5 gold: the tile is sold, stays in the grid, and the badge follows the gold.
	var relic_option: Dictionary = {}
	for option: Dictionary in (model["options"] as Array):
		if String(option["kind"]) == "buy_relic" and bool(option["enabled"]):
			relic_option = option
			break
	assert_dict(relic_option).is_not_empty()
	var cell_count: int = screen.options_box.get_child_count()
	var before_gold: int = state.gold
	var result: Dictionary = RunChoices.apply(state, String(relic_option["id"]), _ctx())
	assert_bool(bool(result["ok"])).is_true()
	assert_int(state.gold).is_less(before_gold)
	var screen2: RunPromptScreen = await _open(Vector2(1280, 720), _model(state))
	assert_int(screen2.options_box.get_child_count()).is_equal(cell_count)
	assert_int(screen2.gold_badge.total()).is_equal(state.gold)
	var sold_tiles: int = 0
	for tile in _buttons(screen2):
		if bool(tile.option.get("sold", false)):
			sold_tiles += 1
			assert_bool(tile.disabled).is_true()
			assert_str(tile.price_tag.get_child(0).get_child(0).text if tile.price_tag.get_child(0).get_child_count() == 1 else "").is_equal("Sold")
	assert_int(sold_tiles).is_equal(1)


func test_shop_only_relics_are_marked_and_others_are_not() -> void:
	var state: RunState = _shop(600)
	var screen: RunPromptScreen = await _open(Vector2(1280, 720), _model(state))
	var marked: int = 0
	for tile in _buttons(screen):
		if String(tile.option.get("kind", "")) != "buy_relic":
			assert_object(tile.shop_only_tag).is_null()
			continue
		var data: Dictionary = RelicDatabase.get_relic(String(tile.option["relic_id"]))
		assert_bool(tile.shop_only_tag != null).is_equal(Merchant.is_shop_only(data))
		marked += 1 if tile.shop_only_tag != null else 0
	assert_int(marked).is_less_equal(RunConfig.get_config()["merchant"]["shop_only_slots"] as int)


func test_a_reroll_tile_shows_only_when_rerolls_are_granted() -> void:
	var plain: RunPromptScreen = await _open(Vector2(1280, 720), _model(_shop(200)))
	for tile in _buttons(plain):
		assert_str(String(tile.option.get("kind", ""))).is_not_equal("reroll")
	var granted: RunPromptScreen = await _open(Vector2(1280, 720), _model(_shop(200, ["request_for_quotation"])))
	var rerolls: int = 0
	for tile in _buttons(granted):
		if String(tile.option.get("kind", "")) == "reroll":
			rerolls += 1
			assert_bool(tile.disabled).is_false()
	assert_int(rerolls).is_equal(1)


func test_cancelling_the_swap_charges_nothing_and_the_step_names_the_price() -> void:
	RunSession.relic_cap = 2
	var state: RunState = _shop(200, ["pyre_insurance", "heavy_sigh"])
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools("rogue"))
	var gold_before: int = state.gold
	var buy: Dictionary = {}
	for option: Dictionary in RunChoices.options(state, ctx):
		if String(option["kind"]) == "buy_relic" and bool(option["enabled"]):
			buy = option
			break
	assert_dict(buy).is_not_empty()
	assert_bool(bool(buy["needs_swap"])).is_true()
	var result: Dictionary = RunChoices.apply(state, String(buy["id"]), ctx)
	assert_str(String(result["kind"])).is_equal("merchant_swap_open")
	assert_int(state.gold).is_equal(gold_before)  # opening the step charges nothing
	var model: Dictionary = _model(state)
	assert_str(String(model["merchant_screen"])).is_equal("swap")
	var screen: RunPromptScreen = await _open(Vector2(1024, 600), model)
	assert_str(screen.line_label.text).contains("gold")
	assert_str(screen.line_label.text).contains("Cancel charges nothing")
	var cancel: Dictionary = RunChoices.apply(state, "merchant_cancel", ctx)
	assert_bool(bool(cancel["ok"])).is_true()
	assert_int(state.gold).is_equal(gold_before)
	assert_array(state.relics).has_size(2)


func test_a_purchase_refill_keeps_the_screen_armed_and_the_highlight() -> void:
	var state: RunState = _shop(300)
	var screen: RunPromptScreen = await _open(Vector2(1280, 720), _model(state))
	screen.disarm()
	var tiles: Array[RunOptionCard] = _buttons(screen)
	tiles[1].grab_focus()
	await _frames(1)
	assert_int(screen._last_focus).is_equal(1)
	# buy the card at index 3 (a different tile), then the screen refills with the new model
	var bought: Dictionary = RunChoices.apply(state, String(screen._options[3]["id"]), _ctx())
	assert_bool(bool(bought["ok"])).is_true()
	screen.show_choice(_model(state))
	await _frames(2)
	assert_bool(screen.options_armed()).is_true()  # no new arm delay between purchases
	assert_float(screen.options_box.modulate.a).is_equal(1.0)
	assert_int(screen._last_focus).is_equal(1)
	assert_bool(screen._option_buttons[1].has_focus()).is_true()


# --- MAP1 carry-overs ------------------------------------------------------------------------------

func _map_screen(data: Dictionary) -> MapScreen:
	var screen: MapScreen = (load("res://scenes/ui/MapScreen.tscn") as PackedScene).instantiate()
	add_child(screen)
	auto_free(screen)
	await _frames(1)
	screen.show_pick(data)
	await _frames(2)
	return screen


func _info(id: int, type_id: String, reachable: bool, taken: bool = false) -> Dictionary:
	return {"id": id, "room": 9, "column": id, "type": type_id, "type_name": type_id, "wave_id": "", "chest": "", "chest_name": "", "hover": "x",
		"gold_low": 0, "gold_high": 0, "reachable": reachable, "taken": taken, "current": false}


func test_a_relic_room_title_says_its_chest_size_and_other_titles_are_left_alone() -> void:
	assert_str(RunPromptScreen.chest_title("Relic room", "small")).is_equal("Relic room (small chest)")
	assert_str(RunPromptScreen.chest_title("Relic room", "large")).is_equal("Relic room (large chest)")
	assert_str(RunPromptScreen.chest_title("Relic room", "")).is_equal("Relic room")
	assert_str(RunPromptScreen.chest_title("Relic room", "gigantic")).is_equal("Relic room")


func test_the_pick_that_leaves_only_the_boss_reads_face_the_boss() -> void:
	var only_boss: Array[Dictionary] = [_info(1, "combat", false, true), _info(2, "boss", true)]
	assert_bool(MapLayout.boss_only(only_boss)).is_true()
	var two: Array[Dictionary] = [_info(1, "combat", true), _info(2, "boss", true)]
	assert_bool(MapLayout.boss_only(two)).is_false()
	var one_other: Array[Dictionary] = [_info(1, "combat", true), _info(2, "boss", false)]
	assert_bool(MapLayout.boss_only(one_other)).is_false()
	var data: Dictionary = {"map": {"nodes": [{"id": 1, "room": 9, "column": 0, "type": "combat", "wave_id": ""}, {"id": 2, "room": 10, "column": 0, "type": "boss", "wave_id": ""}], "edges": [[1, 2]]},
		"path": [1], "reachable": [2], "nodes": [_info(1, "combat", false, true), _info(2, "boss", true)], "gold": 10, "gold_earned": 0}
	var screen: MapScreen = await _map_screen(data)
	assert_str(screen.title_label.text).is_equal("Face the boss")
	assert_str(screen.line_label.text).not_contains("Spend")


func test_the_map_says_where_gold_goes_only_while_a_merchant_is_still_ahead_and_there_is_gold() -> void:
	var ahead: Array[Dictionary] = [_info(1, "combat", true), _info(2, "merchant", false)]
	assert_bool(MapLayout.merchant_ahead(ahead)).is_true()
	var behind: Array[Dictionary] = [_info(1, "combat", true), _info(2, "merchant", false, true)]
	assert_bool(MapLayout.merchant_ahead(behind)).is_false()
	var none: Array[Dictionary] = [_info(1, "combat", true)]
	assert_bool(MapLayout.merchant_ahead(none)).is_false()
	var map: Dictionary = {"nodes": [{"id": 1, "room": 2, "column": 0, "type": "combat", "wave_id": ""}, {"id": 2, "room": 3, "column": 0, "type": "merchant", "wave_id": ""}, {"id": 3, "room": 3, "column": 1, "type": "combat", "wave_id": ""}], "edges": [[1, 2], [1, 3]]}
	var data: Dictionary = {"map": map, "path": [0], "reachable": [1], "nodes": ahead, "gold": 25, "gold_earned": 0}
	var rich: MapScreen = await _map_screen(data)
	assert_str(rich.line_label.text).contains(String(RunConfig.ui()["map"]["spend_line"]))
	data["gold"] = 0
	var broke: MapScreen = await _map_screen(data)
	assert_str(broke.line_label.text).not_contains(String(RunConfig.ui()["map"]["spend_line"]))


func test_the_merchant_has_a_hover_text_that_says_what_it_sells_and_a_legend_entry() -> void:
	var hover: String = String(RunConfig.ui()["map"]["hover"]["merchant"])
	assert_str(hover).contains("relics")
	assert_str(hover).contains("cards")
	assert_str(hover).contains("removal")
	assert_array(MapLayout.legend_types({"nodes": [{"type": "combat"}, {"type": "merchant"}]})).contains(["merchant"])
	assert_str(RunIcons.shape_for("merchant")).is_equal(RunIcons.SHAPE_SQUARE)


func test_the_legend_text_the_chest_dots_and_the_every_nth_pips_are_big_enough_at_1024_by_600() -> void:
	var s: float = 600.0 / 720.0
	var cfg: Dictionary = UiConfig.map_screen()
	assert_int(MapLayout.font_px(float(cfg["legend_font_size"]), s, float(cfg["min_font_px"]))).is_greater_equal(15)
	assert_int(MapLayout.font_px(float(cfg["hint_font_size"]), s, float(cfg["min_font_px"]))).is_greater_equal(14)
	# the smallest chest is 0.8 of a node: its dot must still be about 5 px across or more
	var base_radius: float = float(cfg["node_radius_max"]) * s
	var small_chest: float = base_radius * float(cfg["chest_scale"]["small"])
	assert_float(MapNodeButton.pip_radius(small_chest) * 2.0).is_greater_equal(5.0)
	assert_float(RelicRow.pip_height(s)).is_greater_equal(6.0)
	assert_float(RelicRow.pip_height(1.0)).is_greater_equal(RelicRow.pip_height(s))


func test_the_relic_skip_line_no_longer_leaves_rejects_alone() -> void:
	var line: String = String(RunConfig.ui()["relic"]["skip_detail"])
	assert_str(line).not_contains("alone")
	assert_str(line).contains("card rejects")
