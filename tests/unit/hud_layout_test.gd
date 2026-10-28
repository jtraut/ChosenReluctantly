class_name HudLayoutTest
extends GdUnitTestSuite
## Slice 2: HUD text fit, fixed slot layout, safe margins, name-length warning.

const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]
const FIXTURE_NAME: String = "The Extremely Long And Overly Descriptive Name Of A Card Nobody Asked For"


func _font() -> Font:
	return ThemeDB.fallback_font


func _label_text_fits(text: String, base_key: String, min_key: String, lines_key: String, width_override: float = -1.0) -> Dictionary:
	var cfg := UiConfig.hud()
	var slot: Array = cfg["slot_size"]
	var width := (width_override if width_override > 0.0 else float(slot[0])) - float(cfg["fit_padding"])
	return TextFit.fit(text, _font(), width, int(cfg[lines_key]), int(cfg[base_key]), int(cfg[min_key]))


func test_fixture_is_about_sixty_plus_characters() -> void:
	assert_int(FIXTURE_NAME.length()).is_greater_equal(60)


func test_long_fixture_name_does_not_overflow_slot() -> void:
	var cfg := UiConfig.hud()
	var r := _label_text_fits(FIXTURE_NAME, "name_font_size", "name_min_font_size", "name_max_lines")
	assert_bool(r["fits"]).is_true()
	assert_bool(r["truncated"]).is_true()
	assert_int(r["lines"]).is_less_equal(int(cfg["name_max_lines"]))
	assert_int(r["font_size"]).is_equal(int(cfg["name_min_font_size"]))
	assert_str(r["text"]).ends_with(TextFit.ELLIPSIS)
	# Height check: the lines must fit the fixed row.
	assert_float(r["lines"] * _font().get_height(r["font_size"])).is_less_equal(float(cfg["name_height"]))


func test_long_fixture_preview_does_not_overflow_slot() -> void:
	var cfg := UiConfig.hud()
	var r := _label_text_fits("Next: " + FIXTURE_NAME, "preview_font_size", "preview_min_font_size", "preview_max_lines")
	assert_bool(r["fits"]).is_true()
	assert_int(r["lines"]).is_less_equal(int(cfg["preview_max_lines"]))
	assert_float(r["lines"] * _font().get_height(r["font_size"])).is_less_equal(float(cfg["preview_height"]))


func test_short_name_keeps_base_size_and_text() -> void:
	var r := _label_text_fits("Nap Time", "name_font_size", "name_min_font_size", "name_max_lines")
	assert_str(r["text"]).is_equal("Nap Time")
	assert_int(r["font_size"]).is_equal(int(UiConfig.hud()["name_font_size"]))
	assert_bool(r["truncated"]).is_false()


func test_shrinks_before_truncating() -> void:
	# Find a width where base size needs 3 lines but a smaller size fits in 2.
	var text := "Healing Potion (Lukewarm) Deluxe"
	var cfg := UiConfig.hud()
	var base := int(cfg["name_font_size"])
	var width := 60.0
	while TextFit.line_count(text, _font(), base, width) > 2:
		width += 2.0
		assert_float(width).is_less(400.0)
	width -= 2.0
	var r := TextFit.fit(text, _font(), width, 2, base, int(cfg["name_min_font_size"]))
	if TextFit.line_count(text, _font(), base, width) > 2 and TextFit.line_count(text, _font(), int(cfg["name_min_font_size"]), width) <= 2:
		assert_bool(r["truncated"]).is_false()
		assert_int(r["font_size"]).is_less(base)


func test_every_real_card_name_and_flavor_fits_at_min_font() -> void:
	var cfg := UiConfig.hud()
	var slot: Array = cfg["slot_size"]
	var pad := float(cfg["fit_padding"])
	var problems: Array[String] = []
	for card in CardDatabase.all_cards():
		var card_name := str((card as Dictionary).get("name", ""))
		var name_lines := TextFit.line_count(card_name, _font(), int(cfg["name_min_font_size"]), float(slot[0]) - pad)
		if name_lines > int(cfg["name_max_lines"]):
			problems.append("%s: name needs %d lines at min font" % [card.get("id"), name_lines])
		var preview_lines := TextFit.line_count("Next: " + card_name, _font(), int(cfg["preview_min_font_size"]), float(slot[0]) - pad)
		if preview_lines > int(cfg["preview_max_lines"]):
			problems.append("%s: Next preview needs %d lines at min font" % [card.get("id"), preview_lines])
		var flavor_lines := TextFit.line_count(str((card as Dictionary).get("flavor_text", "")), _font(), int(cfg["flavor_min_font_size"]), float(cfg["flavor_box_width"]))
		if flavor_lines > int(cfg["flavor_max_lines"]):
			problems.append("%s: flavor needs %d lines at min font" % [card.get("id"), flavor_lines])
		if not CardSchema.warnings(card as Dictionary).is_empty():
			problems.append("%s: name over %d characters" % [card.get("id"), int(cfg["name_warn_length"])])
	assert_array(CardDatabase.all_cards()).is_not_empty()
	assert_array(problems).is_empty()


func test_base_fonts_fit_fixed_row_heights() -> void:
	var cfg := UiConfig.hud()
	assert_float(2.0 * _font().get_height(int(cfg["name_font_size"]))).is_less_equal(float(cfg["name_height"]))
	assert_float(2.0 * _font().get_height(int(cfg["preview_font_size"]))).is_less_equal(float(cfg["preview_height"]))
	var rows := float(cfg["key_height"]) + float(cfg["name_height"]) + float(cfg["bar_height"]) + float(cfg["preview_height"]) + 3.0 * float(cfg["slot_row_separation"])
	assert_float(rows).is_less_equal(float((cfg["slot_size"] as Array)[1]))


func test_scaled_fonts_fit_scaled_row_heights() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var s := HudLayout.ui_scale(vp, cfg)
		for pair in [["name_font_size", "name_height", 2.0], ["preview_font_size", "preview_height", 2.0], ["key_font_size", "key_height", 1.0]]:
			var px := roundi(float(cfg[pair[0]]) * s)
			assert_float(float(pair[2]) * _font().get_height(px)).override_failure_message("%s at %s" % [pair[0], vp]).is_less_equal(roundf(float(cfg[pair[1]]) * s))


func test_layout_rects_inside_safe_area_at_all_resolutions() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var safe := HudLayout.safe_area(vp, cfg)
		var bar := HudLayout.slot_bar_rect(vp, cfg, 5)
		var hp := HudLayout.health_rect(vp, cfg)
		assert_bool(safe.encloses(bar)).override_failure_message("slot bar %s outside %s at %s" % [bar, safe, vp]).is_true()
		assert_bool(safe.encloses(hp)).override_failure_message("health %s outside %s at %s" % [hp, safe, vp]).is_true()
		assert_float(bar.get_center().x).is_equal_approx(vp.x * 0.5, 0.01)
		assert_bool(bar.intersects(hp)).is_false()


func test_real_hud_nodes_inside_viewport_with_margin_and_aligned() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var sub := SubViewport.new()
		sub.size = Vector2i(vp)
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(sub)
		auto_free(sub)
		var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
		sub.add_child(hud)
		await get_tree().process_frame
		await get_tree().process_frame
		var safe := HudLayout.safe_area(vp, cfg)
		var expected := HudLayout.slot_size(vp, cfg)
		var top := hud.slot_widgets[0].get_global_rect().position.y
		for i in range(hud.slot_widgets.size()):
			var rect := hud.slot_widgets[i].get_global_rect()
			assert_bool(safe.grow(0.5).encloses(rect)).override_failure_message("slot %d %s outside %s at %s" % [i, rect, safe, vp]).is_true()
			assert_vector(rect.size).is_equal_approx(expected, Vector2(0.5, 0.5))
			assert_float(rect.position.y).is_equal_approx(top, 0.01)
		var panel := (hud.get_node("Root/HealthPanel") as Control).get_global_rect()
		assert_bool(safe.grow(0.5).encloses(panel)).override_failure_message("health %s outside %s at %s" % [panel, safe, vp]).is_true()
		hud.queue_free()
		sub.queue_free()


func test_widget_rows_do_not_move_with_a_long_name() -> void:
	var cfg := UiConfig.hud()
	var widget: CardSlotWidget = (load("res://scenes/ui/CardSlotWidget.tscn") as PackedScene).instantiate()
	add_child(widget)
	auto_free(widget)
	widget.apply_layout(cfg, 1.0)
	widget.set_key_hint("1")
	await get_tree().process_frame
	var bar_y := widget.cooldown_bar.position.y
	var preview_y := widget.preview_label.position.y
	var size_before := widget.size
	widget._set_name(FIXTURE_NAME)
	widget._set_preview("Next: " + FIXTURE_NAME)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(widget.cooldown_bar.position.y).is_equal(bar_y)
	assert_float(widget.preview_label.position.y).is_equal(preview_y)
	assert_vector(widget.size).is_equal(size_before)
	assert_float(widget.name_label.size.y).is_equal_approx(float(cfg["name_height"]), 0.01)


func test_name_over_limit_warns_but_still_validates() -> void:
	var card := {
		"id": "test_long_name",
		"name": FIXTURE_NAME,
		"slot_type": "attack_single",
		"pool": "rogue",
		"cooldown_modifier": 0.0,
		"flavor_text": "x",
		"effects": [{"template": "cone", "params": {"damage": 6, "damage_type": "physical", "range": 2.0, "half_angle_degrees": 45}}],
	}
	assert_array(CardSchema.validate(card)).is_empty()
	assert_array(CardSchema.warnings(card)).has_size(1)
	card["name"] = "x".repeat(25)
	assert_array(CardSchema.warnings(card)).is_empty()
	card["name"] = "x".repeat(26)
	assert_array(CardSchema.warnings(card)).has_size(1)
	assert_array(CardSchema.validate(card)).is_empty()
