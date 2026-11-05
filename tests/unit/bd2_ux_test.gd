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
