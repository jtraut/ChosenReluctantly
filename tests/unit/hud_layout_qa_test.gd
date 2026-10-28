class_name HudLayoutQaTest
extends GdUnitTestSuite
## qa additions for Slice 2: end-to-end label measurement on the real HUD at the
## three target resolutions, and a non-vacuous shrink-before-truncate check.

const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]
const FIXTURE_NAME: String = "The Extremely Long And Overly Descriptive Name Of A Card Nobody Asked For"


func test_real_hud_long_name_stays_inside_label_at_all_resolutions() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var sub := SubViewport.new()
		sub.size = Vector2i(vp)
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(sub)
		var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
		sub.add_child(hud)
		await get_tree().process_frame
		var w: CardSlotWidget = hud.slot_widgets[0]
		var before_bar := w.cooldown_bar.get_global_rect()
		var before_prev_y := w.preview_label.get_global_rect().position.y
		w._set_name(FIXTURE_NAME)
		w._set_preview("Next: " + FIXTURE_NAME)
		await get_tree().process_frame
		await get_tree().process_frame
		var s := HudLayout.ui_scale(vp, cfg)
		for label: Label in [w.name_label, w.preview_label]:
			var fs := label.get_theme_font_size("font_size")
			var lines := TextFit.line_count(label.text, label.get_theme_font("font"), fs, label.size.x - float(cfg["fit_padding"]) * s)
			assert_int(lines).override_failure_message("%s lines at %s" % [label.name, vp]).is_less_equal(2)
			assert_float(lines * label.get_theme_font("font").get_height(fs)).override_failure_message("%s height at %s" % [label.name, vp]).is_less_equal(label.size.y + 0.5)
			assert_bool(label.text.ends_with(TextFit.ELLIPSIS)).is_true()
		assert_bool(w.cooldown_bar.get_global_rect().is_equal_approx(before_bar)).is_true()
		assert_float(w.preview_label.get_global_rect().position.y).is_equal_approx(before_prev_y, 0.01)
		# Truncated name is a prefix of the real one.
		assert_bool(FIXTURE_NAME.begins_with(w.name_label.text.trim_suffix(TextFit.ELLIPSIS))).is_true()
		sub.queue_free()


func test_shrink_happens_before_truncation_unconditional() -> void:
	var f: Font = ThemeDB.fallback_font
	# Pick text/width found by search so the case always exists (fails loudly if not).
	var text := "Healing Potion Lukewarm Deluxe"
	var found := false
	var width := 40.0
	while width < 300.0:
		if TextFit.line_count(text, f, 15, width) > 2 and TextFit.line_count(text, f, 11, width) <= 2:
			found = true
			break
		width += 1.0
	assert_bool(found).override_failure_message("no width where shrink alone suffices").is_true()
	var r := TextFit.fit(text, f, width, 2, 15, 11)
	assert_bool(r["truncated"]).is_false()
	assert_int(r["font_size"]).is_less(15)
	assert_str(r["text"]).is_equal(text)


func test_ellipsis_last_resort_only_below_min_size_fit() -> void:
	var f: Font = ThemeDB.fallback_font
	var r := TextFit.fit(FIXTURE_NAME, f, 148.0, 2, 15, 11)
	assert_int(TextFit.line_count(FIXTURE_NAME, f, 11, 148.0)).is_greater(2)
	assert_bool(r["truncated"]).is_true()
	assert_int(r["font_size"]).is_equal(11)
