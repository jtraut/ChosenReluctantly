class_name Map3bUxTest
extends GdUnitTestSuite
## MAP3b ux: rarity marks on card tiles, the boss-relic offer, the Open a Vein glow, and the MB1 nits (slot names, stack labels vs damage numbers).

const HEIGHTS: Array[int] = [600, 720, 1080, 1440]


func after_test() -> void:
	Juice.reset()


func _tile(opt: Dictionary, look: RunOptionCard.Look, enabled: bool = true) -> RunOptionCard:
	var cfg: Dictionary = UiConfig.run_ui()
	var full: Dictionary = {"kind": "card", "label": "x", "detail": "d", "slot_type": "utility", "slot_name": "Utility", "enabled": enabled}
	full.merge(opt, true)
	var button := RunOptionCard.new()
	add_child(button)
	auto_free(button)
	button.setup(full, look, 268.0, cfg, 1.0, {"index": -1, "owned": 0, "texts": RunConfig.ui()["option"], "relic_texts": RunConfig.ui().get("relic", {})})
	return button


# --- rarity marks ---

func test_a_common_card_has_no_rarity_mark_and_a_rare_and_legendary_card_do() -> void:
	for pair: Array in [["common", false], ["rare", true], ["legendary", true]]:
		var tile: RunOptionCard = _tile({"card_id": "rogue_drive_by", "rarity": String(pair[0])}, RunOptionCard.Look.CARD)
		assert_bool(tile.rarity_tag != null).override_failure_message(String(pair[0])).is_equal(bool(pair[1]))


func test_the_mark_carries_the_word_from_data_and_the_legendary_one_has_two_shapes() -> void:
	var names: Dictionary = RunConfig.ui()["option"]["rarity_names"]
	for rarity: String in ["rare", "legendary"]:
		var tile: RunOptionCard = _tile({"card_id": "rogue_drive_by", "rarity": rarity}, RunOptionCard.Look.CARD)
		var labels: Array[String] = []
		var marks: int = 0
		for child: Node in tile.rarity_tag.get_child(0).get_children():
			if child is Label:
				labels.append((child as Label).text)
			elif child is RunTypeIcon:
				marks += 1
		assert_array(labels).is_equal([String(names[rarity])] as Array[String])
		assert_int(marks).is_equal(2 if rarity == "legendary" else 1)


func test_rarity_falls_back_to_the_card_data_when_the_option_has_none() -> void:
	assert_str(RunOptionCard.rarity_of_option({"card_id": "rogue_brawl_clause"})).is_equal("legendary")
	assert_str(RunOptionCard.rarity_of_option({"card_id": "rogue_drive_by"})).is_equal("common")
	assert_str(RunOptionCard.rarity_of_option({"rarity": "bogus"})).is_equal("common")


func test_marks_show_on_removal_cells_and_shop_cards_and_never_on_relics() -> void:
	assert_bool(_tile({"kind": "remove", "card_id": "rogue_brawl_clause", "rarity": "legendary", "count": 1}, RunOptionCard.Look.CELL).rarity_tag != null).is_true()
	var shop_opt: Dictionary = {"kind": "buy_card", "card_id": "rogue_arterial_spray", "rarity": "rare", "price": 85, "label": "x", "detail": "d", "slot_type": "utility", "slot_name": "Utility", "enabled": true}
	var shop := RunOptionCard.new()
	add_child(shop)
	auto_free(shop)
	shop.setup(shop_opt, RunOptionCard.Look.SHOP, 540.0, UiConfig.run_ui(), 1.0, {"index": -1, "texts": RunConfig.ui()["option"], "shop_texts": RunConfig.ui()["merchant"], "gold": 200})
	assert_bool(shop.rarity_tag != null).is_true()
	var relic: RunOptionCard = _tile({"kind": "relic", "relic_id": "x", "rarity": "legendary", "pool": "neutral", "pool_name": "Neutral", "tier_name": "Tier 1"}, RunOptionCard.Look.RELIC)
	assert_bool(relic.rarity_tag == null).is_true()


func test_a_legendary_frame_is_gold_and_keeps_the_family_colour_for_the_inner_line() -> void:
	var tile: RunOptionCard = _tile({"card_id": "rogue_brawl_clause", "rarity": "legendary"}, RunOptionCard.Look.CARD)
	var frame: StyleBoxFlat = tile.get_theme_stylebox("normal") as StyleBoxFlat
	assert_that(frame.border_color).is_equal(tile.rarity_color("legendary"))
	assert_that(tile.frame_color()).is_equal(PoolDatabase.frame_color_for_card("rogue_brawl_clause"))
	var common: RunOptionCard = _tile({"card_id": "rogue_drive_by", "rarity": "common"}, RunOptionCard.Look.CARD)
	assert_that((common.get_theme_stylebox("normal") as StyleBoxFlat).border_color).is_equal(common.frame_color())


func test_rarity_words_and_colours_are_in_data() -> void:
	var names: Dictionary = RunConfig.ui()["option"]["rarity_names"]
	assert_str(String(names["rare"])).is_not_empty()
	assert_str(String(names["legendary"])).is_not_empty()
	var cfg: Dictionary = UiConfig.run_ui()
	assert_bool(cfg.has("rarity_rare_color") and cfg.has("rarity_legendary_color") and cfg.has("relic_boss_color")).is_true()


# --- boss relic tile ---

func test_the_upside_and_cost_split_takes_the_last_sentence_or_the_data_cost() -> void:
	var parts: Dictionary = RunOptionCard.split_upside_cost("You deal 25% more damage. You can no longer swap a dead card.")
	assert_str(String(parts["upside"])).is_equal("You deal 25% more damage.")
	assert_str(String(parts["cost"])).is_equal("You can no longer swap a dead card.")
	var decimals: Dictionary = RunOptionCard.split_upside_cost("Each card cast takes 0.5 s off every slot. Light and heavy attacks deal half damage.")
	assert_str(String(decimals["upside"])).is_equal("Each card cast takes 0.5 s off every slot.")
	assert_str(String(RunOptionCard.split_upside_cost("One sentence only.")["cost"])).is_empty()
	var given: Dictionary = RunOptionCard.split_upside_cost("Two. Sentences.", "Own cost.")
	assert_str(String(given["upside"])).is_equal("Two. Sentences.")
	assert_str(String(given["cost"])).is_equal("Own cost.")


func test_every_boss_relic_has_an_upside_and_a_cost_line() -> void:
	var seen: int = 0
	for relic: Dictionary in RelicDatabase.all_relics():
		if String(relic.get("rarity", "")) != "boss":
			continue
		seen += 1
		var parts: Dictionary = RunOptionCard.split_upside_cost(String(relic.get("rule_text", "")))
		assert_str(String(parts["cost"])).override_failure_message(String(relic.get("id", ""))).is_not_empty()
		assert_str(String(parts["upside"])).override_failure_message(String(relic.get("id", ""))).is_not_empty()
	assert_int(seen).is_greater(0)


func test_a_boss_relic_tile_shows_the_cost_line_and_a_normal_relic_does_not() -> void:
	var boss: RunOptionCard = _tile({"kind": "relic", "relic_id": "b", "label": "B", "detail": "Good thing. Bad thing.", "boss": true, "pool": "neutral", "pool_name": "Neutral", "tier_name": "Boss", "keywords": []}, RunOptionCard.Look.RELIC)
	assert_bool(boss.cost_label != null).is_true()
	assert_str(boss.cost_label.text).contains("Bad thing.")
	assert_str(boss.detail_label.text).is_equal("Good thing.")
	var plain: RunOptionCard = _tile({"kind": "relic", "relic_id": "p", "label": "P", "detail": "Good thing. Bad thing.", "boss": false, "pool": "neutral", "pool_name": "Neutral", "tier_name": "Tier 1", "keywords": []}, RunOptionCard.Look.RELIC)
	assert_bool(plain.cost_label == null).is_true()
	assert_str(plain.detail_label.text).contains("Bad thing.")


func test_the_boss_offer_strings_are_in_data() -> void:
	var ui: Dictionary = RunConfig.ui()["relic"]
	assert_str(String(ui.get("boss_title", ""))).is_not_empty()
	assert_str(String(ui.get("boss_line", ""))).is_not_empty()
	assert_str(String(ui.get("cost_format", ""))).contains("%s")


# --- Open a Vein glow ---

func test_the_detonate_glow_needs_the_threshold_and_a_detonate_card() -> void:
	assert_bool(SlotCues.detonate_live({"detonate_status": "bleed", "detonate_stacks": 2}, 2)).is_true()
	assert_bool(SlotCues.detonate_live({"detonate_status": "bleed", "detonate_stacks": 1}, 2)).is_false()
	assert_bool(SlotCues.detonate_live({"detonate_status": "", "detonate_stacks": 5}, 2)).is_false()
	assert_bool(SlotCues.detonate_live({}, 2)).is_false()
	assert_bool(SlotCues.detonate_live({"detonate_status": "bleed", "detonate_stacks": 5}, 0)).is_false()


func test_the_detonate_threshold_is_data() -> void:
	assert_int(int(UiConfig.hud().get("detonate_live_stacks", 0))).is_greater(1)


# --- MB1 nit: slot card names ---

func test_every_card_name_fits_its_slot_name_label_at_every_size() -> void:
	var cfg: Dictionary = UiConfig.hud()
	var widget: CardSlotWidget = (load("res://scenes/ui/CardSlotWidget.tscn") as PackedScene).instantiate()
	add_child(widget)
	auto_free(widget)
	await get_tree().process_frame
	var bad: Array[String] = []
	for height: int in HEIGHTS:
		var s: float = HudLayout.ui_scale(Vector2(height * 16.0 / 9.0, float(height)), cfg)
		widget.apply_layout(cfg, s)
		for card: Dictionary in CardDatabase.all_cards():
			widget._name_text = ""
			widget._set_name(String(card.get("name", "")))
			await get_tree().process_frame
			var label: Label = widget.name_label
			var lines: int = label.get_line_count()
			var font_px: int = label.get_theme_font_size("font_size")
			var needed: float = float(lines) * label.get_theme_font("font").get_height(font_px)
			# A single unbroken line must also be narrower than the label's inside (its margins are fit_padding / 2 each side), or clip_text cuts it.
			var inside: float = label.size.x - float(cfg["fit_padding"]) * s
			var widest: float = 0.0
			for line_text: String in label.text.split("
"):
				widest = maxf(widest, label.get_theme_font("font").get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x)
			if lines == 1 and widest > inside + 0.5:
				bad.append("%s @%d: one line %.1f wide in %.1f" % [String(card.get("id", "")), height, widest, inside])
			if lines > label.max_lines_visible or needed > label.size.y + 0.5 or label.text.ends_with(TextFit.ELLIPSIS):
				bad.append("%s @%d: lines %d, needs %.1f of %.1f, text '%s'" % [String(card.get("id", "")), height, lines, needed, label.size.y, label.text])
	assert_array(bad).override_failure_message("\n".join(bad)).is_empty()
